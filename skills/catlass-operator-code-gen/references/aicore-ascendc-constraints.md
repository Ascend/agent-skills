# AICore / AscendC 编程约束（Catlass 算子必遵）

本文档将 **AscendC/AICore 编程约束** 合入 Catlass 侧文档。Catlass 算子代码生成与设计必须遵守以下内容，不得在 Kernel 内违反。

---

## 1. 严正约束：AICore 与 Catlass 唯一实现

### 1.1 AICore 上标量计算极慢

- **禁止以 SIMT（单线程标量循环）视角编写算子代码**。
- 禁止在 Kernel 内手写逐元素标量循环（如 `for (i) for (j) out[i,j] = ...`）。
- AICore 架构与 GPU 不同，标量循环极慢，必须使用向量/块级接口。

### 1.2 仅使用 Catlass 提供的实现

- Kernel 中**只能**使用 Catlass 提供的 Block/Tile/Kernel 组合。
- **不得**自行实现：矩阵乘、逐元素加、逐元素乘、拷贝等计算逻辑。
- 可用组件示例：`BlockMmad`、`BasicMatmul`、`MatmulEpilogue`、`BlockEpilogue`、`TileElemWiseAdd`、`TileCopy` 等（以 catlass 仓内头文件为准）。

### 1.3 Catlass 中已有的 mmad/epilogue 实现

- 矩阵乘 + 偏置 / 加 D 等需求，应使用：
  - **Kernel**：`Gemm::Kernel::MatmulEpilogue`
  - **BlockEpilogue**：如 `EpilogueAtlasA2ElemWiseOneSource` + `TileElemWiseAdd` + `TileCopy`
- **参考实现**：
  - `catlass/examples/03_matmul_add/matmul_add.cpp`
  - `catlass/include/catlass/gemm/kernel/matmul_epilogue.hpp`
- 不得用自写标量或自写向量循环替代上述 Catlass 组件。

### 1.4 无现成组件时的处理

- 若设计文档要求的融合逻辑在 Catlass 中**无**现成组件：
  - 应先在**设计阶段**改为选用 Catlass 已有组件，或
  - 向用户说明需**扩展 Catlass 库**后再生成代码，不得在 Kernel 内自实现计算逻辑。

---

## 2. Kernel 头文件与编译顺序（与 03_matmul_add 一致）

- 在 ops 工程中编写 Kernel 时，**先包含 Catlass 头文件，再包含 CANN kernel_operator.h**，避免与 CANN 头中部分符号冲突（如 AIV 路径下的 half 向量运算）。
- 建议在文件最前定义：`#ifndef K_MAX_SHAPE_DIM` / `#define K_MAX_SHAPE_DIM 0` / `#endif`（与 `catlass/examples/03_matmul_add` 一致）。
- Catlass 头顺序可参考 03_matmul_add：`arch.hpp` → `catlass.hpp` → `block_epilogue.hpp` → `dispatch_policy` → `tile_copy.hpp` → `tile_elemwise_add.hpp` → `block_mmad.hpp` → `block_swizzle.hpp` → `gemm dispatch_policy` → `gemm_type.hpp` → `matmul_epilogue.hpp` → `layout.hpp`，然后再包含 `kernel_operator.h` 与工程 tiling 头。

---

## 3. 反模式（NEVER）

- 在 AICore Kernel 内**手写标量/逐元素循环**或**自实现矩阵乘、逐元素加**。
- 以 SIMT 方式在 Kernel 内写 `for (i) for (j) out[i,j] = ...` 或等价标量逻辑。
- 在未选用 Catlass 对应组件的情况下，自行实现与 Catlass 同功能的计算（如自写 C+D、自写 GELU 等）。

---

## 4. 参考资料（Catlass 仓内）

| 路径 | 说明 |
|------|------|
| catlass/examples/03_matmul_add/matmul_add.cpp | 矩阵乘 + 逐元素加（D = A*B + X）的**完整参考**：MatmulEpilogue、BlockEpilogue、Workspace、EpilogueParams、头文件顺序 |
| catlass/include/catlass/gemm/kernel/matmul_epilogue.hpp | MatmulEpilogue Kernel 定义；AIC/AIV 双路径、Workspace 与 EpilogueParams |
| catlass/include/catlass/epilogue/block/block_epilogue_elemwise_one_source.hpp | BlockEpilogue（单源逐元素）与 Params(ptrX, layoutX, ptrD, layoutD) |
| catlass/include/catlass/epilogue/tile/tile_elemwise_add.hpp | TileElemWiseAdd（AscendC::Add 向量加） |

以上约束与说明以 **Catlass 侧文档** 为准，供 catlass-operator-design 与 catlass-operator-code-gen 共同遵守；不依赖对 AscendC 相关 skill 的修改权限。
