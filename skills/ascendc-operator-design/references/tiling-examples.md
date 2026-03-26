# 不同类型算子的 Tiling 实现参考

本文档提供了各种类型算子的 Tiling 实现参考，包括切分策略、计算方法和最佳实践。

## 1. 元素级算子（如 Add、Sub、Mul 等）

### 1.1 切分原则
按元素总数均匀分配到所有 AI Core，确保负载均衡。

### 1.2 计算方法
```
total_elements = shape[0] × shape[1] × ... × shape[N-1]
elements_per_core = ceil(total_elements / num_cores)
core_id 处理元素范围: [core_id × elements_per_core, (core_id+1) × elements_per_core)
```

### 1.3 适用场景
- 适用于所有维度大小的输入
- 特别适合高维小批量数据

## 2. 矩阵乘法算子（MatMul）

### 2.1 切分原则
优先切分 M 维度（输出行），其次切分 N 维度（输出列），K 维度不切分。

### 2.2 基于 baseM 和 baseN 的输出分块策略
```
// 步骤 1: 根据 baseM 和 baseN 计算输出 base 块
base_m_count = ceil(M / baseM)  // M 维度上的 base 块数
base_n_count = ceil(N / baseN)  // N 维度上的 base 块数
total_base_blocks = base_m_count × base_n_count  // 总 base 块数

// 步骤 2: 将 base 块均匀分配给各个核
blocks_per_core = ceil(total_base_blocks / num_cores)
```

### 2.3 设计要点
- 保持 K 维度连续，减少数据传输
- 合理选择 baseM 和 baseN 参数以充分利用 UB 空间

## 3. 归约类算子（如 ReduceSum、ReduceMax 等）

### 3.1 切分原则
先对每个 Core 进行局部归约，再进行全局归约，减少通信开销。

### 3.2 计算方法
```
步骤 1: 每个 Core 对其分配到的数据进行局部归约
        local_result[core_id] = reduce(x[start:end], axis)

步骤 2: 收集所有 Core 的局部结果

步骤 3: 对局部结果进行全局归约（通常在单个 Core 或 CPU 上完成）
        final_result = reduce([local_result[0], local_result[1], ...])
```

## 4. 归一化类算子：LayerNormV4

### 4.1 切分模式分类
- **SINGLE_READ**：单次读取模式，适用于特定通道数（1024/4096）和BF16数据类型
- **TRANSPOSE**：转置模式，优化内存访问模式
- **MERGE_N**：合并行模式，适用于列数量较小的场景
- **COMMON**：通用模式，支持各种输入规模

### 4.2 核间切分策略
```
// 核间切分核心逻辑
if (colSize <= coreNum) {
    nRow = 1;              // 每核处理1行
    numBlocks = colSize;   // 核心数等于列数
} else {
    nRow = rowMax / rowAlign;  // 根据UB空间计算每核处理的行数
    if (nRow > N_ROW_LIMIT) {
        nRow = N_ROW_LIMIT;    // 限制最大行数
    }
    numBlocks = coreNum;       // 使用所有可用核心
}
```

### 4.3 核内切分策略

#### 4.3.1 数据分块大小计算
```
// UB空间计算（以FP32为例）
rowMax = ((ubSizePlatForm - 8 * 32) / 4) / 2;
```

#### 4.3.2 循环处理量
```
// 主循环次数计算
blockCount = colSize / nRow;
tailNRow = colSize - blockCount * nRow;
loopCount = blockCount / numBlocks;
tailLoop = blockCount - loopCount * numBlocks;
```

### 4.4 数据类型支持
- 输入数据类型：FP16、BF16、FP32
- 参数数据类型：FP16、BF16、FP32
- 支持混合精度计算（如FP16输入，FP32计算）

### 4.5 LayerNormV4 优化策略
- 根据输入规模动态选择切分模式
- 优化UB空间利用，提高数据访问效率
- 采用混合精度计算，平衡精度和性能

## 5. 池化类算子（AdaptiveAvgPool3d、AvgPool3D）

### 5.1 AdaptiveAvgPool3d 核间切分策略
基于输出数量和可用核心数进行切分，每个核心负责计算部分输出结果。

### 5.2 AdaptiveAvgPool3d 三种核心分配情况
1. **输出数量 < 核心数**：每个核心处理 1 个输出，剩余核心空闲
2. **输出数量 % 核心数 == 0**：每个核心处理相同数量的输出
3. **其他情况**：前 formerNum 个核心处理 formerLength 个输出，剩余核心处理 tailLength 个输出

### 5.3 AdaptiveAvgPool3d 计算示例
```
formerNum = num_cores - (outputCount % num_cores)
formerLength = outputCount / num_cores
if outputCount % num_cores != 0:
    formerLength += 1
tailLength = outputCount / num_cores
```

### 5.4 AvgPool3D 切分策略
AvgPool3D 采用多种分核策略，根据输入规模和硬件约束动态选择最优切分模式：

#### 5.4.1 切分模式分类
- **SPLIT_C**：按通道维度切分，适用于输入通道数较多的场景
- **SPLIT_W**：按宽度维度切分，适用于宽度较大的输入
- **MULTI_W**：多组宽度切分，处理超大宽度输入
- **REDUCE_D**：深度方向归约切分，针对深度维度较大的场景
- **NORMAL**：常规切分模式，平衡各维度负载
- **BIG_KERNEL**：大核模式，优化大尺寸池化核场景

#### 5.4.2 核心分核策略
```
// 核心分核公式示例
core_idx = (b_idx * H + h_idx) % num_cores;
```
每个核心负责处理特定空间位置的输入数据，通过取模运算实现负载均衡。

#### 5.4.3 数据分块大小
- 输入数据分块大小：根据 UB 容量限制，通常设置为 32x32x32
- 输出数据分块大小：与输入分块对应，根据池化核大小调整
- 权重数据分块：1x1x1，适用于平均池化计算

#### 5.4.4 硬件约束考量
- **32字节对齐**：所有内存访问确保32字节对齐
- **UB空间限制**：输入输出数据分块大小不超过UB容量
- **计算单元利用率**：通过合理分核提高AI Core利用率
- **内存带宽优化**：合并内存访问减少带宽压力

## 6. 归一化类算子（如 RMSNorm）

### 6.1 核间切分策略
基于行维度切分，将需要归一化的行数据分配到多个 AI Core。

### 6.2 多种切分模式

#### 6.2.1 普通模式
- **适用场景**：UB 空间足够大，可以容纳所有列数据
- **优势**：计算简单，无需额外的分块处理

#### 6.2.2 列切分模式
- **适用场景**：列数量较大，无法一次性放入 UB
- **处理方式**：将列维度进行切分，逐块处理

#### 6.2.3 合并行模式
- **适用场景**：列数量较小
- **处理方式**：将多行数据合并处理，提高计算效率

### 6.3 设计要点
- 根据列维度大小选择合适的切分模式
- 确保归一化计算的数值稳定性

## 7. 激活类算子（如 GLU）

### 7.1 整体策略
GLU 算子采用**基于输入规模的动态切分策略**，根据输入形状分为三种模式：
- **SINGLESHAPE**：ny = 1 的情况
- **SMALLSHAPE**：ny ≤ commonBufSize (8KB) 的情况
- **BIGSHAPE**：ny > commonBufSize 的情况

### 7.2 核间切分
- **切分维度**：优先按 batch 维度 (x) 进行切分
- **计算公式**：
  ```cpp
  numPerCore = CeilDiv(tilingParam.x, tilingParam.coreNum);  // 每个核心处理的 batch 数
  realCoreNum = CeilDiv(tilingParam.x, numPerCore);          // 实际使用的核心数
  ```

### 7.3 核内切分

#### 7.3.1 小形状模式 (SINGLESHAPE/SMALLSHAPE)
- **分组处理**：
  ```cpp
  group = tilingParam.bufSize / splitSizeAlign;  // 根据 UB 空间确定分组数
  loopNum = numPerCore / group;                   // 每个核心的主循环次数
  nLastTailGroup = numPerCore % group;            // 主循环后的剩余分组数
  ```
- **尾处理**：
  ```cpp
  tailTotalNum = tilingParam.x - numPerCore * (realCoreNum - 1);
  tailLoopNum = tailTotalNum / group;
  lastTailGroup = tailTotalNum % group;
  ```

#### 7.3.2 大形状模式 (BIGSHAPE)
- **按 ny 维度切分**：
  ```cpp
  group = tilingParam.ny / tilingParam.bufSize;  // 按 UB 空间大小切分 ny
  tailNum = tilingParam.ny - group * tilingParam.bufSize;
  ```

### 7.4 数据类型支持
- 支持 FP16、BF16、FP32 三种数据类型
- 不同数据类型的块大小：
  - FP16: 16
  - BF16: 16
  - FP32: 8