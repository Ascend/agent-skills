# Ascend C 算子实现示例

本文档包含完整的算子实现示例，展示不同类型算子的设计模式和实现技巧。

## 目录

1. [池化类算子：AdaptiveAvgPool3d](#池化类算子adaptiveavgpool3d)
2. [池化类算子：AvgPool3D](#池化类算子avgpool3d)
3. [归一化类算子：RMSNorm](#归一化类算子rmsnorm)
4. [优化器类算子：ApplyAdamW V2](#优化器类算子applyadamw-v2)
5. [归一化类算子：LayerNormV4](#归一化类算子layernormv4)
6. [激活类算子：GLU](#激活类算子glu)

---

## 1. 池化类算子：AdaptiveAvgPool3d

3D 自适应平均池化算子，采用多模式设计，根据输入规模和硬件资源动态选择最优切分策略。

### 整体架构

**Kernel 入口与模式分发**：
```cpp
extern "C" __global__ __aicore__ void adaptive_avg_pool3d(GM_ADDR x, GM_ADDR y, GM_ADDR workspace, GM_ADDR tiling)
{
    GET_TILING_DATA(tilingData, tiling);
    if (TILING_KEY_IS(11)) {
        DISPATCH_OP_IMPL(KernelAdaptiveAvgPool3dSplitC, half, 1);
    } else if (TILING_KEY_IS(12)) {
        DISPATCH_OP_IMPL(KernelAdaptiveAvgPool3dSplitC, float, 1);
    } else if (TILING_KEY_IS(21)) {
        DISPATCH_OP_IMPL(KernelAdaptiveAvgPool3dSplitW, half, 1);
    } else if (TILING_KEY_IS(22)) {
        DISPATCH_OP_IMPL(KernelAdaptiveAvgPool3dSplitW, float, 1);
    } else if (TILING_KEY_IS(31)) {
        DISPATCH_OP_IMPL(KernelAdaptiveAvgPool3dMultiW, half, 1);
    } else if (TILING_KEY_IS(32)) {
        DISPATCH_OP_IMPL(KernelAdaptiveAvgPool3dMultiW, float, 1);
    }
}
```

### 三种实现模式

#### 通道切分模式（MODE_SPLIT_C）

**适用场景**：当 2 倍对齐后的通道数大于 UB 可用空间时

**核心思想**：按通道维度切分，每个核心处理一部分通道

**主要流程**：
1. 初始化输入输出缓冲区、队列和临时缓冲区
2. 遍历每个输出点
3. 计算当前输出点对应的输入区域索引
4. 按通道切分长度处理每个通道块

#### W 维度切分模式（MODE_SPLIT_W）

**适用场景**：当输入切分数小于最大窗口 W 长度时

**核心思想**：按 W 维度切分，每个核心处理 W 维度的一部分

#### 多窗口 W 处理模式（MODE_MULTI_W）

**适用场景**：当 UB 空间足够大，可以同时处理多个窗口 W 时

**核心思想**：同时处理多个窗口 W，提高计算效率

### 核心计算逻辑

**输入区域计算**：
```cpp
__aicore__ inline int64_t StartIndex(int64_t idx, int64_t osize, int64_t isize)
{
    return (idx / osize) * isize + ((idx % osize) * isize) / osize;
}

__aicore__ inline int64_t EndIndex(int64_t idx, int64_t osize, int64_t isize)
{
    return 1 + ((idx + 1) * isize - 1) / osize;
}
```

**平均值计算**：
```cpp
float factor = 1.0f / (static_cast<float>(index.dend - index.dstart) *
                       (index.hend - index.hstart) *
                       (index.wend - index.wstart));
Muls(sumBufLocal, sumBufLocal, factor, len);
```

---

## 2. 池化类算子：AvgPool3D

AvgPool3D 是 3D 平均池化算子，支持多种池化参数配置，采用多模式设计以适应不同输入规模和硬件环境。

### 模式分发机制
根据 TilingKey 和数据类型分发到不同实现路径：
- 支持 FP16、BF16、FP32 等数据类型
- 针对不同切分模式提供专用计算逻辑
- 动态选择最优计算路径

### 核心处理流程
```
// 核心处理伪代码
for each output element:
    initialize sum = 0
    for each kernel element:
        load input data from global memory
        accumulate to sum
    compute average by dividing sum by kernel size
    store result to global memory
```

### 核心计算逻辑

**输入区域计算**：
```cpp
// 计算当前输出位置对应的输入区域
int32_t dstart = input_d_idx * stride_d - pad_front;
int32_t dend = dstart + kernel_d;
int32_t hstart = input_h_idx * stride_h - pad_top;
int32_t hend = hstart + kernel_h;
int32_t wstart = input_w_idx * stride_w - pad_left;
int32_t wend = wstart + kernel_w;

// 边界处理
dstart = std::max(dstart, 0);
dend = std::min(dend, input_depth);
hstart = std::max(hstart, 0);
hend = std::min(hend, input_height);
wstart = std::max(wstart, 0);
wend = std::min(wend, input_width);
```

**平均值计算**：
```cpp
// 计算有效元素数量
int32_t valid_elements = (dend - dstart) * (hend - hstart) * (wend - wstart);
float factor = 1.0f / static_cast<float>(valid_elements);

// 计算求和并应用因子
Muls(outputLocal, sumBuffer, factor, num_elements);
```

### 循环计算量
- **单次循环处理**：32x32x32 输入块
- **每次计算包含**：32*32*32=32768 次加载操作
- **每次计算包含**：32*32*32=32768 次加法操作
- **每次计算包含**：32*32*32=32768 次除法操作

### 优化策略
- **数据预取**：利用预取技术隐藏内存访问延迟
- **双缓冲**：重叠计算和数据传输，提高资源利用率
- **循环展开**：针对池化核大小优化循环展开次数
- **动态分块**：根据输入尺寸自动调整分块大小

### 硬件约束考量
- **32字节对齐**：所有内存访问确保32字节对齐
- **UB空间限制**：输入输出数据分块大小不超过UB容量
- **计算单元利用率**：通过合理分核提高AI Core利用率
- **内存带宽优化**：合并内存访问减少带宽压力

---

## 3. 归一化类算子：RMSNorm

RMSNorm 归一化算子，采用多模式设计，根据输入规模和硬件资源动态选择最优切分策略。

### 整体架构

**Kernel 入口与模式分发**：
```cpp
extern "C" __global__ __aicore__ void rms_norm(GM_ADDR x, GM_ADDR gamma, GM_ADDR y, GM_ADDR rstd, GM_ADDR tiling)
{
    GET_TILING_DATA(tilingData, tiling);
    if (TILING_KEY_IS(11)) {
        DISPATCH_OP_IMPL(KernelRmsNorm, half, half, 1);
    } else if (TILING_KEY_IS(12)) {
        DISPATCH_OP_IMPL(KernelRmsNorm, half, float, 1);
    } else if (TILING_KEY_IS(21)) {
        DISPATCH_OP_IMPL(KernelRmsNorm, float, float, 1);
    } else if (TILING_KEY_IS(31)) {
        DISPATCH_OP_IMPL(KernelRmsNormSplitD, half, half, 1);
    } else if (TILING_KEY_IS(32)) {
        DISPATCH_OP_IMPL(KernelRmsNormSplitD, half, float, 1);
    } else if (TILING_KEY_IS(41)) {
        DISPATCH_OP_IMPL(KernelRmsNormSplitD, float, float, 1);
    } else if (TILING_KEY_IS(51)) {
        DISPATCH_OP_IMPL(KernelRmsNormMergeN, half, half, 1);
    } else if (TILING_KEY_IS(52)) {
        DISPATCH_OP_IMPL(KernelRmsNormMergeN, half, float, 1);
    } else if (TILING_KEY_IS(61)) {
        DISPATCH_OP_IMPL(KernelRmsNormMergeN, float, float, 1);
    }
}
```

### 三种实现模式

#### 普通模式（KernelRmsNorm）

**适用场景**：列数较少，UB 空间足够容纳所有列数据

**数据流程**：
```
GM(输入数据) → 局部内存 → FP32转换 → 平方计算 → 归约求和 → rstd计算 →
归一化 → 乘以gamma → 输出类型转换 → GM(输出数据)
```

#### 列切分模式（KernelRmsNormSplitD）

**适用场景**：列数较多，无法一次性放入 UB

**核心思想**：按列维度切分，每次处理一部分列数据

#### 合并行模式（KernelRmsNormMergeN）

**适用场景**：列数较小，适合合并多行处理

**核心思想**：将多行数据合并处理，提高计算效率

### 核心计算逻辑

**rstd 计算**：
```cpp
Muls(rstdLocal, rstdLocal, avg_factor, num);
Adds(rstdLocal, rstdLocal, epsilon, num);
Sqrt(rstdLocal, rstdLocal, num);
Duplicate(reduce_buf_local, 1.0f, num);
Div(rstdLocal, reduce_buf_local, rstdLocal, num);
```

**归一化与缩放**：
```cpp
if constexpr (is_same<T, float>::value) {
    Muls(sqx, xLocal, rstdValue, num);
    Mul(yLocal, sqx, gammaLocal, num);
} else {
    Cast(sqx, xLocal, RoundMode::CAST_NONE, num);
    Muls(sqx, sqx, rstdValue, num);
    Mul(sqx, sqx, gammaLocal, num);
    Cast(yLocal, sqx, RoundMode::CAST_NONE, num);
}
```

---

## 4. 优化器类算子：ApplyAdamW V2

AdamW 优化器算子，支持权重衰减、动量更新和自适应学习率调整。

### 整体架构

**Kernel 入口与模式分发**：
```cpp
extern "C" __global__ __aicore__ void ApplyAdamWV2(
    GM_ADDR var, GM_ADDR expAvg, GM_ADDR expAvgSq, GM_ADDR grad, GM_ADDR step, GM_ADDR maxGradNorm,
    GM_ADDR workspace, GM_ADDR tiling)
{
    GET_TILING_DATA(tilingData, tiling);
    int32_t dtype = tilingData->dtype;
    int32_t gradDtype = tilingData->gradDtype;
    int32_t stepDtype = tilingData->stepDtype;

    if (dtype == APPLY_ADAM_W_TPL_FP32) {
        if (gradDtype == APPLY_ADAM_W_TPL_FP32) {
            if (stepDtype == APPLY_ADAM_W_TPL_FP32) {
                DISPATCH_OP_IMPL(KernelApplyAdamWV2, float, float, float);
            } else {
                DISPATCH_OP_IMPL(KernelApplyAdamWV2, float, float, int64_t);
            }
        }
    }
}
```

---

## 5. 归一化类算子：LayerNormV4

LayerNormV4 算子实现了层归一化功能，支持多种数据类型和切分模式。

### 模式分发机制
根据 TilingKey 和数据类型分发到不同实现路径：
```cpp
if (TILING_KEY_IS(100)) {  // FP32输入，FP32参数
    INVOKE_LAYER_NORM_V4_SINGLE_READ_IMPL(float, float);
} else if (TILING_KEY_IS(110)) {  // FP16输入，FP32参数
    INVOKE_LAYER_NORM_V4_SINGLE_READ_IMPL(half, float);
} else if (TILING_KEY_IS(111)) {  // FP16输入，FP16参数
    INVOKE_LAYER_NORM_V4_SINGLE_READ_IMPL(half, half);
} // ... 其他模式
```

### 核心处理流程
```cpp
// 核心处理流程伪代码
void LayerNormV4SingleRead::Process() {
    // 计算当前核心处理的循环次数
    Count = loopCount;
    if (GetBlockIdx() < tailLoop) {
        Count += 1;
    }
    
    // 处理主数据块
    for (loopIdx = 0; loopIdx < Count; ++loopIdx) {
        currentBlockOffset = loopIdx * blockLength;
        currentParamOffset = loopIdx * nRow;
        ProcessBasicBlock(nRow, currentBlockOffset, currentParamOffset);
    }
    
    // 处理尾数据块
    if (tailNRow > 0 && GetBlockIdx() == (numBlocks - 1)) {
        currentBlockOffset = Count * blockLength;
        currentParamOffset = Count * nRow;
        ProcessBasicBlock(tailNRow, currentBlockOffset, currentParamOffset);
    }
}
```

### 单次 BasicBlock 处理
```cpp
// BasicBlock处理伪代码
void ProcessBasicBlock(uint32_t nRow, uint32_t currentBlockOffset, uint32_t currentParamOffset) {
    // 1. 数据加载：从GM加载输入数据到UB
    DataCopyPad(xLocal, xGm[currentBlockOffset], dataCopyParams, padParams);
    
    // 2. 类型转换：FP16/BF16转FP32
    if (sizeof(Tfm) == 2) {
        Cast(xLocal, xLocal.ReinterpretCast<Tfm>()[tileLength], RoundMode::CAST_NONE, tileLength);
    }
    
    // 3. 均值计算：逐行计算均值
    for (rowIdx = 0; rowIdx < nRow; ++rowIdx) {
        currentRowOffset = rowIdx * rowAlign;
        ReduceSum(yLocal[currentRowOffset], yLocal[currentRowOffset], yLocal[currentRowOffset], rowSize);
        meanValue = GetAccVal();
        meanLocal.SetValue(rowIdx, meanValue);
    }
    
    // 4. 方差计算：计算行方差
    Mul(xLocal, yLocal, yLocal, tileLength);
    Muls(xLocal, xLocal, coefficient, tileLength);
    
    // 5. 归一化：计算最终输出
    for (rowIdx = 0; rowIdx < nRow; ++rowIdx) {
        currentRowOffset = rowIdx * rowAlign;
        rstdValue = rstdLocal.GetValue(rowIdx);
        Muls(yLocal[currentRowOffset], yLocal[currentRowOffset], rstdValue, rowSize);
        
        // 应用gamma和beta参数
        if (!nullptrGamma) {
            Mul(yLocal[currentRowOffset], yLocal[currentRowOffset], gammaLocal, rowSize);
        }
        if (!nullptrBeta) {
            Adds(yLocal[currentRowOffset], yLocal[currentRowOffset], betaLocal, rowSize);
        }
    }
    
    // 6. 结果存储：将输出写回GM
    DataCopyPad(yGm[currentBlockOffset], yLocal.ReinterpretCast<Tfm>()[tileLength], dataCopyParams, padParams);
}
```

### 循环计算量
- **单次循环处理**：nRow × rowSize 个元素
- **内存访问**：
  - 输入：nRow × rowSize 次加载
  - 输出：nRow × rowSize 次存储
  - 参数：rowSize 次加载（gamma/beta）
- **计算操作**：
  - 加法：nRow × rowSize 次
  - 乘法：nRow × rowSize × 2 次
  - 除法/平方根：nRow 次

### 优化策略
- **UB空间最大化利用**：根据数据类型和输入规模动态调整分块大小
- **类型转换优化**：仅在需要时进行精度转换
- **内存访问优化**：连续访问内存，减少缓存缺失
- **并行计算**：充分利用AI Core的计算能力

---

## 6. 激活类算子：GLU

Gated Linear Unit (GLU) 激活函数算子，采用多模式设计，根据输入规模和硬件资源动态选择最优实现策略。

### 三种实现模式

#### 单形状模式（GluSingleShape）

**适用场景**：ny = 1 的特殊情况
**核心思想**：针对单一维度输入进行优化，简化处理流程

#### 小形状模式（GluSmallShape）

**适用场景**：ny ≤ 8KB，UB 空间足够容纳所有特征数据
**核心思想**：一次性将所有特征数据加载到 UB 进行处理，减少数据传输次数

#### 大形状模式（GluBigShape）

**适用场景**：ny > 8KB，UB 空间不足以容纳所有特征数据
**核心思想**：按特征维度切分，分批加载和处理数据

### 核心计算流程

1. **数据加载**：从 GM 加载输入数据到 UB
2. **数据切分**：将输入按 splitDim 维度分成两部分
3. **激活函数**：对第二部分应用 sigmoid 激活函数
4. **逐元素乘法**：将两部分相乘得到结果
5. **结果存储**：将计算结果从 UB 写回 GM

### 优化点

- **动态调度**：根据输入规模选择最优实现模式
- **UB 空间最大化利用**：根据数据类型动态调整缓冲区大小
- **负载均衡**：确保每个核心处理的计算量相对均衡
- **批量处理**：通过分组处理提高计算效率