# Catlass 算子设计文档（模板与示例）

本文档同时作为**设计文档撰写规范**与 **MatmulGelu 示例**。生成任意 Catlass 算子设计文档时须遵循下列约定：

- **第 2 节「核心组件结构」为必写**：必须显式列出并说明用到的 **Kernel**、**Block**（BlockMmad、BlockEpilogue、BlockScheduler）、**Tile**（如 L1TileShape、L0TileShape、Epilogue 中的 Tile 级组件）、**Epilogue**（Tile 级与 Block 级组件）等。可参考 catlass 仓库文档或本 skill 的 `matmul-templates.md`、`epilogue-components.md` 进行总结。
- **AICore/AscendC 约束**：设计文档中的实现方案**只能使用 Catlass 提供的 Kernel/Block/Tile/Epilogue**，不得出现「在 Kernel 内自写标量/向量循环」的实现。详见 [aicore-ascendc-constraints.md](aicore-ascendc-constraints.md)。
- **无现成样例时**：在「模板支持情况」中说明缺口，并给出**基于现有样例/模板的变通方案**（如基于 00_basic_matmul 增加某 Epilogue、或改用 SplitK 模板等）。

---

## 1. 概述

本文档描述了 Catlass 库中 MatmulGelu 算子的设计与实现，重点关注 `MatmulKernel` 的模板组装结构。该算子实现了矩阵乘法（Matmul）与激活函数（GELU）的融合计算，利用 Ascend 平台的硬件特性实现高效计算。

### 1.1 输入输出信息表

| 变量名 | 类型 | Shape | 描述 |
|-------|------|-------|------|
| `deviceA` | `half` | `(m, k)` | 输入矩阵A |
| `deviceB` | `half` | `(k, n)` | 输入矩阵B |
| `deviceD` | `half` | `(m, n)` | 输出矩阵，包含矩阵乘法结果和GELU激活函数应用 |

## 2. 核心组件结构

### 2.1 架构与硬件适配

```cpp
// Define ArchTag
using ArchTag = Arch::AtlasA2;
```

- **ArchTag**: 指定硬件架构为 AtlasA2，确保所有组件都针对该架构进行优化
- **作用**: 作为所有模板组件的基础参数，影响指令选择、内存布局和性能优化策略

### 2.2 块级 MMAD 设计

```cpp
// Block level, define BlockMmad
constexpr bool enableUnitFlag = true;
using MmadDispatchPolicy = Gemm::MmadAtlasA2Pingpong<enableUnitFlag>;
using L1TileShape = GemmShape<128, 256, 256>;
using L0TileShape = GemmShape<128, 256, 64>;
using AType = Gemm::GemmType<half, LayoutA>;
using BType = Gemm::GemmType<half, LayoutB>;
using CType = Gemm::GemmType<float, LayoutC>;
using BlockMmad = Gemm::Block::BlockMmad<MmadDispatchPolicy, L1TileShape, L0TileShape, AType, BType, CType>;
```

#### 关键组件说明：

| 组件 | 类型 | 作用 | 配置 |
|------|------|------|------|
| `MmadDispatchPolicy` | 调度策略 | 控制 MMAD 指令的执行方式 | `Gemm::MmadAtlasA2Pingpong<enableUnitFlag>` |
| `L1TileShape` | 数据形状 | L1 缓存中的分块形状 | `GemmShape<128, 256, 256>` |
| `L0TileShape` | 数据形状 | L0 缓存中的分块形状 | `GemmShape<128, 256, 64>` |
| `AType`/`BType`/`CType` | 数据类型 | 定义矩阵 A/B/C 的数据类型和布局 | `Gemm::GemmType<数据类型, 布局>` |
| `BlockMmad` | 块计算单元 | 执行块级矩阵乘法计算 | 组合以上所有参数 |

#### 设计思路：
- **分块策略**: 采用两级分块（L1/L0）充分利用不同层级缓存
- **数据类型转换**: 输入为 `half` 类型，中间计算为 `float` 类型以提高精度
- **调度优化**: 使用 `Pingpong` 调度策略隐藏内存访问延迟

### 2.3 尾处理（Epilogue）设计

```cpp
constexpr uint32_t computeLength = 16384; // 64 * 128 * 2B
using TileElemWiseEpilogue = Epilogue::Tile::TileElemWiseGelu<ArchTag, CType, computeLength>;
using EpilogueTileCopy = Epilogue::Tile::TileCopy<
    ArchTag,
    CType, // CopyGmtoUbC
    DType  // CopyUbtoGmD
    >;
using BlockEpilogue = 
    Epilogue::Block::BlockEpilogue<EpilogueDispatchPolicy, CType, DType, TileElemWiseEpilogue, EpilogueTileCopy>;
```

#### 关键组件说明：

| 组件 | 类型 | 作用 | 配置 |
|------|------|------|------|
| `TileElemWiseEpilogue` | 计算单元 | 在 Tile 级别执行 GELU 激活函数 | `Epilogue::Tile::TileElemWiseGelu` |
| `EpilogueTileCopy` | 数据传输 | 处理数据在全局内存和统一缓冲区之间的复制 | `Epilogue::Tile::TileCopy` |
| `BlockEpilogue` | 块处理单元 | 协调块级别的尾处理流程 | 组合以上所有参数 |

#### 设计思路：
- **融合计算**: 将 GELU 激活函数与矩阵乘法结果处理融合，减少内存访问
- **计算长度优化**: 根据硬件特性设置最佳计算长度（16384字节）
- **数据类型转换**: 支持从 `float`（中间结果）到 `half`（最终输出）的转换

### 2.4 块调度器设计

```cpp
if (m > n) {
    // Define BlockScheduler
    // Swizzle offset is 3 and direction is 0.
    using BlockScheduler = typename Gemm::Block::GemmIdentityBlockSwizzle<3, 0>;
    // Kernel level
    using MatmulKernel = Gemm::Kernel::MatmulActivation<BlockMmad, BlockEpilogue, BlockScheduler>;
    // ...
} else {
    // Define BlockScheduler
    // Swizzle offset is 3 and direction is 1.
    using BlockScheduler = typename Gemm::Block::GemmIdentityBlockSwizzle<3, 1>;
    // Kernel level
    using MatmulKernel = Gemm::Kernel::MatmulActivation<BlockMmad, BlockEpilogue, BlockScheduler>;
    // ...
}
```

#### 关键组件说明：

| 组件 | 类型 | 作用 | 配置 |
|------|------|------|------|
| `BlockScheduler` | 调度器 | 控制块级任务的调度方式 | `Gemm::Block::GemmIdentityBlockSwizzle<offset, direction>` |
| `MatmulKernel` | 核心算子 | 组合所有组件形成完整的矩阵乘法+激活函数算子 | `Gemm::Kernel::MatmulActivation<>` |

#### 设计思路：
- **动态调度**: 根据矩阵尺寸（m > n 或 m ≤ n）选择不同的调度方向
- **偏移优化**: 使用固定偏移值（3）优化缓存命中率
- **灵活性**: 通过模板参数组合不同的 BlockMmad、BlockEpilogue 和 BlockScheduler

## 3. 模板组装流程

### 3.1 组件依赖关系

```
MatmulKernel
├── BlockMmad
│   ├── MmadDispatchPolicy
│   ├── L1TileShape
│   ├── L0TileShape
│   └── AType/BType/CType
├── BlockEpilogue
│   ├── EpilogueDispatchPolicy
│   ├── TileElemWiseEpilogue (GELU)
│   └── EpilogueTileCopy
└── BlockScheduler
```

### 3.2 组装步骤

1. **架构选择**: 确定目标硬件架构 `ArchTag`
2. **数据类型定义**: 定义输入输出数据类型和布局
3. **块级计算配置**: 配置 `BlockMmad` 相关参数
4. **尾处理配置**: 配置 `BlockEpilogue` 实现 GELU 激活函数
5. **调度策略选择**: 根据矩阵尺寸选择合适的 `BlockScheduler`
6. **最终组装**: 将所有组件组合到 `MatmulKernel` 中

## 4. 性能优化设计

### 4.1 内存优化
- **多级缓存利用**: 合理设置 L1/L0 分块大小，最大化缓存利用率
- **数据类型转换**: 输入输出使用 `half` 类型减少内存带宽压力，中间计算使用 `float` 类型保证精度

### 4.2 计算优化
- **指令级并行**: 利用 Ascend 平台的 MMAD 指令实现高效矩阵乘法
- **融合计算**: 将 GELU 激活函数与矩阵乘法融合，减少中间结果存储
- **调度策略**: 根据矩阵尺寸动态选择调度方向，优化计算资源利用

### 4.3 硬件特性利用
- **FFTS 加速**: 使用 FFTS 硬件加速 GELU 函数计算
- **Cube 核心**: 充分利用 Ascend 平台的 Cube 核心进行矩阵计算

## 5. 接口与使用

### 5.1 参数传递

```cpp
typename MatmulKernel::Arguments arguments{
    options.problemShape, sizeof(float), deviceA, deviceB, deviceD};
```

### 5.2 执行方式

```cpp
using MatmulAdapter = Gemm::Device::DeviceGemm<MatmulKernel>;
MatmulAdapter matmulOp;
RunAdapter(matmulOp, arguments, stream, aicCoreNum, fftsAddr);
```

## 6. 扩展性考虑

- **架构扩展**: 通过修改 `ArchTag` 可以适配不同的 Ascend 架构
- **激活函数扩展**: 替换 `TileElemWiseGelu` 可以实现其他激活函数的融合
- **分块大小调整**: 根据不同的问题规模调整 L1/L0 分块大小以获得最佳性能
- **调度策略扩展**: 实现不同的 `BlockScheduler` 可以优化不同场景下的性能

## 7. 总结

MatmulGelu 算子的设计采用了高度模块化的模板组装方式，通过组合不同的功能组件实现了矩阵乘法与 GELU 激活函数的高效融合计算。这种设计具有良好的可扩展性和性能优化空间，可以根据不同的硬件架构和应用场景进行灵活配置和优化。