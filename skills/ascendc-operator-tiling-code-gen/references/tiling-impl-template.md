# Tiling实现文件模板指南

## 核心原则

**CRITICAL - 设计文档是代码生成的唯一依据，必须100%遵守**

所有tiling实现必须严格遵循设计文档中的：
1. 核间切分策略
2. UB空间分配
3. 硬件约束
4. 计算精度要求

## 文件结构

### 头文件结构

```cpp
/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software...
 */

/*!
 * \file {op_name}_tiling.h
 * \brief {OpName} Tiling Data Definition
 */

#ifndef OPS_BUILT_IN_OP_TILING_RUNTIME_{OP_NAME}_TILING_H
#define OPS_BUILT_IN_OP_TILING_RUNTIME_{OP_NAME}_TILING_H

#include "register/tilingdata_base.h"
#include "log/log.h"
#include "util/math_util.h"
#include "register/op_impl_registry.h"
#include "op_host/tiling_templates_registry.h"
#include "platform/platform_ascendc.h"
#include "op_common/op_host/util/platform_util.h"

namespace optiling {

// 常量定义
constexpr uint16_t MAX_CORE_CONT = 50;

// 数据类型标识（根据设计文档）
constexpr uint64_t DATA_TYPE_FLOAT16 = 1;
constexpr uint64_t DATA_TYPE_FLOAT = 2;
constexpr uint64_t DATA_TYPE_BF16 = 3;

// 模式标识（根据设计文档）
// 例如：constexpr uint64_t MODE_MEAN = 0;
//       constexpr uint64_t MODE_MAX = 1;

// CompileInfo结构
struct {OpName}CompileInfo {
    uint32_t coreNum = 0;
    uint64_t ubSize = 0;
};

// TilingData结构（根据设计文档定义字段）
BEGIN_TILING_DATA_DEF({OpName}TilingData)
    // 基础信息
    TILING_DATA_FIELD_DEF(int64_t, dataType);
    TILING_DATA_FIELD_DEF(int64_t, needCoreNum);
    
    // 维度信息（从设计文档提取）
    TILING_DATA_FIELD_DEF(int64_t, batchSize);
    TILING_DATA_FIELD_DEF(int64_t, headNum);
    TILING_DATA_FIELD_DEF(int64_t, xSeqLen);
    TILING_DATA_FIELD_DEF(int64_t, refSeqLen);
    
    // 切分信息
    TILING_DATA_FIELD_DEF(int64_t, totalBatches);
    TILING_DATA_FIELD_DEF(int64_t, batchPerCore);
    TILING_DATA_FIELD_DEF(int64_t, headPerCore);
    TILING_DATA_FIELD_DEF(int64_t, xSeqLenPerLoop);
    TILING_DATA_FIELD_DEF(int64_t, tmpBufSize);
    
    // 核间切分数组
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchStart);
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchEnd);
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, headStart);
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, headEnd);
END_TILING_DATA_DEF;

REGISTER_TILING_DATA_CLASS({OpName}, {OpName}TilingData)

} // namespace optiling
#endif
```

### 实现文件结构

```cpp
/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software...
 */

/*!
 * \file {op_name}_tiling.cpp
 * \brief {OpName} Tiling Implementation
 */

#include "{op_name}_tiling.h"

namespace optiling {

// 常量定义（根据设计文档）
constexpr uint8_t BYTE_LEN_4 = 4;
constexpr uint8_t BYTE_LEN_2 = 2;
constexpr int32_t BLOCK = 32;  // 32字节对齐
constexpr uint64_t RESERVED_LENGTH = 320;
constexpr uint32_t COMMON_TILING_KEY = 1000;

// Tiling类定义
class {OpName}Tiling
{
public:
    explicit {OpName}Tiling(gert::TilingContext* context) : tilingContext(context) {}
    ge::graphStatus RunBigKernelTiling();

private:
    // 私有方法声明
    ge::graphStatus ParseInputAttrs();
    ge::graphStatus ValidateParams();
    void GetNeedCoreNum(uint32_t coreNumPlatform);
    void CalculateUBStrategy(uint64_t ubSizePlatform);
    void GetWorkSpace();
    uint64_t GetDataTypeVal();
    uint8_t GetDataTypeSize();
    void FillTilingData();
    
    template <typename T1, typename T2>
    inline auto CeilA2B(T1 a, T2 b) -> T1;

private:
    // 成员变量
    {OpName}TilingData tilingData;
    gert::TilingContext* tilingContext = nullptr;
    ge::DataType dataType = ge::DT_UNDEFINED;
    
    // 维度变量（从设计文档提取）
    int64_t batchSize = 1;
    int64_t headNum = 1;
    int64_t xSeqLen = 1;
    int64_t refSeqLen = 1;
    int64_t totalBatches = 1;
    
    // 切分变量
    int64_t batchPerCore = 1;
    int64_t headPerCore = 1;
    int64_t xSeqLenPerLoop = 1;
    int64_t tmpBufSize = 0;
    
    // 核间切分数组
    int32_t batchStart[MAX_CORE_CONT] = {0};
    int32_t batchEnd[MAX_CORE_CONT] = {0};
    int32_t headStart[MAX_CORE_CONT] = {0};
    int32_t headEnd[MAX_CORE_CONT] = {0};
    
    uint8_t dataTypeSize = 2;
    uint32_t needCoreNum = 0;
};

// 方法实现...

} // namespace optiling
```

## 核心方法实现

### ParseInputAttrs - 解析输入属性

```cpp
ge::graphStatus {OpName}Tiling::ParseInputAttrs()
{
    // Step 1: 获取输入shape
    const gert::StorageShape* inputShape = tilingContext->GetInputShape(0);
    OP_CHECK_NULL_WITH_CONTEXT(tilingContext, inputShape);
    
    // Step 2: 检查输入维度（根据设计文档要求）
    const gert::Shape& dims = inputShape->GetStorageShape();
    if (dims.GetDimNum() != 4) {  // 根据设计文档调整
        OP_LOGE(tilingContext->GetNodeName(), 
                "Input must be 4D, got %zu dims", 
                dims.GetDimNum());
        return ge::GRAPH_FAILED;
    }
    
    // Step 3: 提取shape信息（根据设计文档）
    batchSize = dims.GetDim(0);
    headNum = dims.GetDim(1);
    xSeqLen = dims.GetDim(2);
    refSeqLen = dims.GetDim(3);
    
    totalBatches = batchSize * headNum;
    
    // Step 4: 获取数据类型
    auto inputDesc = tilingContext->GetInputDesc(0);
    OP_CHECK_NULL_WITH_CONTEXT(tilingContext, inputDesc);
    dataType = inputDesc->GetDataType();
    dataTypeSize = GetDataTypeSize();
    
    // Step 5: 获取属性（根据设计文档）
    const char* modeStr = tilingContext->GetAttrs()->GetAttrPointer<char>(0);
    if (modeStr != nullptr) {
        if (strcmp(modeStr, "mean") == 0) {
            mode = MODE_MEAN;
        } else if (strcmp(modeStr, "max") == 0) {
            mode = MODE_MAX;
        } else {
            OP_LOGE(tilingContext->GetNodeName(), 
                    "Unsupported mode: %s", modeStr);
            return ge::GRAPH_FAILED;
        }
    }
    
    return ge::GRAPH_SUCCESS;
}
```

### ValidateParams - 参数校验

```cpp
ge::graphStatus {OpName}Tiling::ValidateParams()
{
    // 校验shape有效性（根据设计文档约束）
    if (batchSize <= 0 || headNum <= 0 || xSeqLen <= 0 || refSeqLen <= 0) {
        OP_LOGE(tilingContext->GetNodeName(), 
                "Invalid shape: B=%ld, H=%ld, xSeqLen=%ld, refSeqLen=%ld", 
                batchSize, headNum, xSeqLen, refSeqLen);
        return ge::GRAPH_FAILED;
    }
    
    // 校验数据类型（根据设计文档支持范围）
    if (dataType != ge::DT_FLOAT16 && 
        dataType != ge::DT_FLOAT && 
        dataType != ge::DT_BF16) {
        OP_LOGE(tilingContext->GetNodeName(), 
                "Unsupported data type: %d", 
                static_cast<int>(dataType));
        return ge::GRAPH_FAILED;
    }
    
    return ge::GRAPH_SUCCESS;
}
```

### GetNeedCoreNum - 核间切分（严格按设计文档）

**CRITICAL - 必须严格按照设计文档的切分策略实现：**

```cpp
void {OpName}Tiling::GetNeedCoreNum(uint32_t coreNumPlatform)
{
    // 根据设计文档判断使用哪种切分策略
    // 设计文档示例："大 Batch (B ≥ num_cores)：优先按 Batch 维度切分"
    //               "小 Batch (B < num_cores)：结合 Head 维度进行二维切分"
    
    if (batchSize >= static_cast<int64_t>(coreNumPlatform)) {
        // 大Batch场景：按Batch维度切分
        batchPerCore = CeilA2B(batchSize, coreNumPlatform);
        needCoreNum = CeilA2B(batchSize, batchPerCore);
        needCoreNum = std::min(needCoreNum, static_cast<uint32_t>(MAX_CORE_CONT));
        headPerCore = headNum;
        
        for (int64_t coreIndex = 0; coreIndex < static_cast<int64_t>(needCoreNum); coreIndex++) {
            batchStart[coreIndex] = coreIndex * batchPerCore;
            batchEnd[coreIndex] = std::min((coreIndex + 1) * batchPerCore, batchSize);
            headStart[coreIndex] = 0;
            headEnd[coreIndex] = headNum;
        }
    } else {
        // 小Batch场景：Batch × Head 二维切分
        // 使用设计文档中的公式：core_idx = (b_idx * H + h_idx) % num_cores
        needCoreNum = std::min(static_cast<uint32_t>(totalBatches), coreNumPlatform);
        needCoreNum = std::min(needCoreNum, static_cast<uint32_t>(MAX_CORE_CONT));
        
        int64_t averageBatches = CeilA2B(totalBatches, needCoreNum);
        
        for (int64_t coreIndex = 0; coreIndex < static_cast<int64_t>(needCoreNum); coreIndex++) {
            int64_t globalStart = coreIndex * averageBatches;
            int64_t globalEnd = std::min((coreIndex + 1) * averageBatches, totalBatches);
            
            batchStart[coreIndex] = globalStart / headNum;
            headStart[coreIndex] = globalStart % headNum;
            
            batchEnd[coreIndex] = globalEnd / headNum;
            headEnd[coreIndex] = globalEnd % headNum;
        }
        
        batchPerCore = CeilA2B(batchSize, 1);
        headPerCore = CeilA2B(headNum, 1);
    }
}
```

### CalculateUBStrategy - UB空间计算（严格按设计文档）

**CRITICAL - 必须严格按照设计文档的UB空间分配计算：**

```cpp
void {OpName}Tiling::CalculateUBStrategy(uint64_t ubSizePlatform)
{
    // 设计文档中的UB空间分配
    // 示例来自设计文档4.1.2：
    // | 缓冲区名称                | 大小计算                                      |
    // |--------------------------|---------------------------------------------|
    // | x_ref_attn_map_source    | size_per_element * x_seqlens_per_loop * t_seqlens |
    // | ref_target_mask          | size_per_element * t_seqlens                |
    // | x_ref_attnmap            | size_per_element * x_seqlens_per_loop * t_seqlens |
    // | x_ref_attnmap_sum        | size_per_element * x_seqlens_per_loop       |
    // | ref_mask_sum             | size_per_element * x_seqlens_per_loop       |
    // | x_ref_attnmap_norm       | size_per_element * x_seqlens_per_loop       |
    // | x_ref_attnmap_permuted   | size_per_element * x_seqlens_per_loop * H_per_core |
    // | output                   | size_per_element * x_seqlens_per_loop       |
    
    uint64_t availableUB = ubSizePlatform - RESERVED_LENGTH;
    
    // 逐项计算设计文档中指定的缓冲区大小
    int64_t inputAttnSize = xSeqLen * refSeqLen * dataTypeSize;
    int64_t maskSize = refSeqLen * dataTypeSize;
    
    // FP16/BF16输入需升精度到FP32计算
    // 来自设计文档3.3："FP16/BF16 输入需升精度到 FP32 计算"
    int64_t weightedAttnSize = xSeqLen * refSeqLen * BYTE_LEN_4;
    int64_t sumResultSize = xSeqLen * BYTE_LEN_4;
    int64_t maskSumSize = xSeqLen * BYTE_LEN_4;
    int64_t normResultSize = xSeqLen * BYTE_LEN_4;
    
    // 维度置换后的注意力图
    int64_t permutedSize = xSeqLen * headPerCore * BYTE_LEN_4;
    
    int64_t outputSize = xSeqLen * dataTypeSize;
    
    // 32字节对齐
    // 来自设计文档3.3："UB 缓冲区必须按 32 字节对齐"
    int64_t alignPadding = BLOCK;
    
    int64_t totalPerXSeqLen = inputAttnSize + maskSize + weightedAttnSize + 
                              sumResultSize + maskSumSize + normResultSize + 
                              permutedSize + outputSize + alignPadding;
    
    if (totalPerXSeqLen > 0) {
        xSeqLenPerLoop = availableUB / totalPerXSeqLen;
        xSeqLenPerLoop = std::max(xSeqLenPerLoop, static_cast<int64_t>(1));
        xSeqLenPerLoop = std::min(xSeqLenPerLoop, xSeqLen);
    } else {
        xSeqLenPerLoop = xSeqLen;
    }
    
    // 确保对齐
    int64_t blockSizeAlign = BLOCK / dataTypeSize;
    xSeqLenPerLoop = CeilA2B(xSeqLenPerLoop, blockSizeAlign) * blockSizeAlign;
    xSeqLenPerLoop = std::min(xSeqLenPerLoop, xSeqLen);
    
    tmpBufSize = totalPerXSeqLen * xSeqLenPerLoop;
    tmpBufSize = CeilA2B(tmpBufSize, 16) * 16;
}
```

### FillTilingData - 填充Tiling数据

```cpp
void {OpName}Tiling::FillTilingData()
{
    // 设置所有字段
    tilingData.set_dataType(GetDataTypeVal());
    tilingData.set_needCoreNum(needCoreNum);
    tilingData.set_batchSize(batchSize);
    tilingData.set_headNum(headNum);
    tilingData.set_xSeqLen(xSeqLen);
    tilingData.set_refSeqLen(refSeqLen);
    tilingData.set_totalBatches(totalBatches);
    tilingData.set_batchPerCore(batchPerCore);
    tilingData.set_headPerCore(headPerCore);
    tilingData.set_xSeqLenPerLoop(xSeqLenPerLoop);
    tilingData.set_tmpBufSize(tmpBufSize);
    tilingData.set_batchStart(batchStart);
    tilingData.set_batchEnd(batchEnd);
    tilingData.set_headStart(headStart);
    tilingData.set_headEnd(headEnd);
    
    // 设置block维度和tiling key
    tilingContext->SetBlockDim(needCoreNum);
    tilingContext->SetTilingKey(COMMON_TILING_KEY);
    
    // 保存到context
    tilingData.SaveToBuffer(
        tilingContext->GetRawTilingData()->GetData(),
        tilingContext->GetRawTilingData()->GetCapacity()
    );
    tilingContext->GetRawTilingData()->SetDataSize(tilingData.GetDataSize());
}
```

### TilingPrepare - 平台信息获取

```cpp
static ge::graphStatus TilingPrepare4{OpName}(gert::TilingParseContext* context)
{
    auto compileInfo = context->GetCompiledInfo<{OpName}CompileInfo>();
    OP_CHECK_NULL_WITH_CONTEXT(context, compileInfo);
    
    auto platformInfo = context->GetPlatformInfo();
    auto ascendcPlatform = platform_ascendc::PlatformAscendC(platformInfo);
    
    uint64_t ubSize;
    ascendcPlatform.GetCoreMemSize(platform_ascendc::CoreMemType::UB, ubSize);
    
    compileInfo->coreNum = ascendcPlatform.GetCoreNumAiv();
    compileInfo->ubSize = ubSize;

    // 验证硬件信息有效性
    OP_CHECK_IF(
        compileInfo->coreNum <= 0,
        OP_LOGE(context->GetNodeName(), 
                "GetHardwareInfo Failed, vectorCoreNum: %u", 
                compileInfo->coreNum),
        return ge::GRAPH_FAILED);
    
    OP_CHECK_IF(
        compileInfo->ubSize <= 0,
        OP_LOGE(context->GetNodeName(), 
                "GetHardwareInfo Failed, ubSize: %lu", 
                compileInfo->ubSize),
        return ge::GRAPH_FAILED);
    
    return ge::GRAPH_SUCCESS;
}
```

## 辅助函数

### 数据类型转换

```cpp
uint64_t {OpName}Tiling::GetDataTypeVal()
{
    switch (dataType) {
        case ge::DT_FLOAT:
            return DATA_TYPE_FLOAT;
        case ge::DT_FLOAT16:
            return DATA_TYPE_FLOAT16;
        case ge::DT_BF16:
            return DATA_TYPE_BF16;
        default:
            return 0;
    }
}

uint8_t {OpName}Tiling::GetDataTypeSize()
{
    switch (dataType) {
        case ge::DT_FLOAT:
            return BYTE_LEN_4;
        case ge::DT_FLOAT16:
        case ge::DT_BF16:
            return BYTE_LEN_2;
        default:
            return BYTE_LEN_4;
    }
}
```

### 向上取整

```cpp
template <typename T1, typename T2>
inline auto {OpName}Tiling::CeilA2B(T1 a, T2 b) -> T1
{
    if (b != 0) {
        return (a + b - 1) / b;
    }
    return a;
}
```

## 主入口函数

```cpp
ge::graphStatus {OpName}Tiling::RunBigKernelTiling()
{
    // Step 1: 解析输入参数
    ge::graphStatus status = ParseInputAttrs();
    if (status != ge::GRAPH_SUCCESS) {
        return status;
    }

    // Step 2: 验证参数有效性
    status = ValidateParams();
    if (status != ge::GRAPH_SUCCESS) {
        return status;
    }

    // Step 3: 获取编译信息
    auto compileInfo = reinterpret_cast<const {OpName}CompileInfo*>(
        tilingContext->GetCompileInfo());
    OP_CHECK_NULL_WITH_CONTEXT(tilingContext, compileInfo);

    uint32_t coreNumPlatform = compileInfo->coreNum;
    uint64_t ubSizePlatform = compileInfo->ubSize;

    // Step 4: 计算核间切分（严格按设计文档）
    GetNeedCoreNum(coreNumPlatform);

    // Step 5: 计算UB空间（严格按设计文档）
    CalculateUBStrategy(ubSizePlatform);

    // Step 6: 设置workspace
    GetWorkSpace();

    // Step 7: 填充Tiling数据
    FillTilingData();
    
    return ge::GRAPH_SUCCESS;
}

static ge::graphStatus Tiling4{OpName}(gert::TilingContext* context)
{
    {OpName}Tiling tilingObject(context);
    return tilingObject.RunBigKernelTiling();
}

IMPL_OP_OPTILING({OpName})
    .Tiling(Tiling4{OpName})
    .TilingParse<{OpName}CompileInfo>(TilingPrepare4{OpName});

} // namespace optiling
```

## 设计文档一致性检查清单

**CRITICAL - 生成代码后必须进行以下检查：**

### 核间切分检查
- [ ] 是否正确判断大Batch/小Batch场景？
- [ ] 大Batch场景是否按Batch维度切分？
- [ ] 小Batch场景是否实现二维切分？
- [ ] 切分公式是否与设计文档一致？

### UB空间分配检查
- [ ] 所有缓冲区是否都已计算？
- [ ] 中间计算是否升精度到FP32？
- [ ] 是否正确处理32字节对齐？
- [ ] permutedSize是否包含H_per_core？

### 硬件约束检查
- [ ] 是否从平台获取UB大小？
- [ ] 是否从平台获取核心数？
- [ ] 是否验证硬件信息有效性？

### 边缘情况处理
- [ ] 核心数大于batch数时的处理？
- [ ] UB空间不足时的处理？
- [ ] 数据类型不支持时的处理？

## 常见错误

### 错误1: 忽略设计文档的切分策略

```cpp
// 错误：简单均分，未按设计文档策略
void GetNeedCoreNum(uint32_t coreNumPlatform)
{
    needCoreNum = std::min(totalBatches, coreNumPlatform);
    // 缺少大Batch/小Batch判断
}

// 正确：按设计文档策略实现
void GetNeedCoreNum(uint32_t coreNumPlatform)
{
    if (batchSize >= coreNumPlatform) {
        // 大Batch策略
    } else {
        // 小Batch策略
    }
}
```

### 错误2: 忽略UB缓冲区

```cpp
// 错误：缺少ref_mask_sum缓冲区
int64_t totalSize = inputSize + outputSize;

// 正确：包含所有设计文档指定的缓冲区
int64_t totalSize = inputAttnSize + maskSize + weightedAttnSize + 
                    sumResultSize + maskSumSize + normResultSize + 
                    permutedSize + outputSize + alignPadding;
```

### 错误3: 忽略精度转换

```cpp
// 错误：中间计算使用输入精度
int64_t sumResultSize = xSeqLen * dataTypeSize;

// 正确：FP16/BF16输入升精度到FP32
int64_t sumResultSize = xSeqLen * BYTE_LEN_4;  // FP32
```
