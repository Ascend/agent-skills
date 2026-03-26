/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software, you can redistribute it and/or modify it under the terms and conditions of
 * CANN Open Software License Agreement Version 2.0 (the "License").
 * Please refer to the License for details. You may not use this file except in compliance with the License.
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
 * See LICENSE in the root of the software repository for the full text of the License.
 */

/*!
 * \file example_tiling.cpp
 * \brief Tiling实现样例 - 严格遵循设计文档
 * 
 * 本文件展示了如何根据设计文档实现Tiling逻辑。
 * 关键要点：
 * 1. 核间切分策略必须严格按照设计文档实现
 * 2. UB空间分配必须严格按照设计文档计算
 * 3. 参数校验必须完整
 */

#include "example_tiling.h"

namespace optiling {

// ==================== 常量定义 ====================
constexpr uint8_t BYTE_LEN_4 = 4;           // FP32字节数
constexpr uint8_t BYTE_LEN_2 = 2;           // FP16/BF16字节数
constexpr int32_t BLOCK = 32;               // 32字节对齐
constexpr uint64_t RESERVED_LENGTH = 320;   // 预留空间
constexpr uint32_t COMMON_TILING_KEY = 1000;

// ==================== Tiling类定义 ====================
class ExampleTiling {
public:
    explicit ExampleTiling(gert::TilingContext* context) : tilingContext(context) {}
    ge::graphStatus RunBigKernelTiling();

private:
    // ---------- 私有方法声明 ----------
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
    // ---------- 成员变量 ----------
    ExampleTilingData tilingData;
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
    int64_t mode = MODE_MEAN;
    
    // 核间切分数组
    int32_t batchStart[MAX_CORE_CONT] = {0};
    int32_t batchEnd[MAX_CORE_CONT] = {0};
    int32_t headStart[MAX_CORE_CONT] = {0};
    int32_t headEnd[MAX_CORE_CONT] = {0};
    
    uint8_t dataTypeSize = 2;
    uint32_t needCoreNum = 0;
};

// ==================== ParseInputAttrs实现 ====================
// 解析输入参数，必须与设计文档规格一致
ge::graphStatus ExampleTiling::ParseInputAttrs()
{
    // Step 1: 获取输入shape
    const gert::StorageShape* attnShape = tilingContext->GetInputShape(0);
    const gert::StorageShape* maskShape = tilingContext->GetInputShape(1);
    
    OP_CHECK_NULL_WITH_CONTEXT(tilingContext, attnShape);
    OP_CHECK_NULL_WITH_CONTEXT(tilingContext, maskShape);
    
    // Step 2: 检查输入维度（根据设计文档要求）
    const gert::Shape& attnDims = attnShape->GetStorageShape();
    const gert::Shape& maskDims = maskShape->GetStorageShape();
    
    if (attnDims.GetDimNum() != 4) {
        OP_LOGE(tilingContext->GetNodeName(), 
                "Input x_ref_attn_map_source must be 4D, got %zu dims", 
                attnDims.GetDimNum());
        return ge::GRAPH_FAILED;
    }
    
    if (maskDims.GetDimNum() != 1) {
        OP_LOGE(tilingContext->GetNodeName(), 
                "Input ref_target_mask must be 1D, got %zu dims", 
                maskDims.GetDimNum());
        return ge::GRAPH_FAILED;
    }
    
    // Step 3: 提取shape信息（根据设计文档）
    batchSize = attnDims.GetDim(0);
    headNum = attnDims.GetDim(1);
    xSeqLen = attnDims.GetDim(2);
    refSeqLen = attnDims.GetDim(3);
    
    // Step 4: 校验维度一致性
    int64_t maskSeqLen = maskDims.GetDim(0);
    if (maskSeqLen != refSeqLen) {
        OP_LOGE(tilingContext->GetNodeName(), 
                "ref_target_mask length (%ld) must match x_ref_attn_map_source last dim (%ld)", 
                maskSeqLen, refSeqLen);
        return ge::GRAPH_FAILED;
    }
    
    totalBatches = batchSize * headNum;
    
    // Step 5: 获取数据类型
    auto inputDesc = tilingContext->GetInputDesc(0);
    OP_CHECK_NULL_WITH_CONTEXT(tilingContext, inputDesc);
    dataType = inputDesc->GetDataType();
    dataTypeSize = GetDataTypeSize();
    
    // Step 6: 获取属性（根据设计文档）
    const char* modeStr = tilingContext->GetAttrs()->GetAttrPointer<char>(0);
    if (modeStr != nullptr) {
        if (strcmp(modeStr, "mean") == 0) {
            mode = MODE_MEAN;
        } else if (strcmp(modeStr, "max") == 0) {
            mode = MODE_MAX;
        } else {
            OP_LOGE(tilingContext->GetNodeName(), 
                    "Unsupported mode: %s, only 'mean' or 'max' allowed", modeStr);
            return ge::GRAPH_FAILED;
        }
    } else {
        mode = MODE_MEAN;  // 默认值
    }
    
    return ge::GRAPH_SUCCESS;
}

// ==================== ValidateParams实现 ====================
// 参数校验，确保符合设计文档约束
ge::graphStatus ExampleTiling::ValidateParams()
{
    // 校验shape有效性
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
                "Unsupported data type: %d", static_cast<int>(dataType));
        return ge::GRAPH_FAILED;
    }
    
    return ge::GRAPH_SUCCESS;
}

// ==================== GetNeedCoreNum实现 ====================
// 核间切分策略 - CRITICAL: 必须严格按照设计文档实现
// 
// 设计文档要求：
// - 大 Batch (B ≥ num_cores)：优先按 Batch 维度切分
// - 小 Batch (B < num_cores)：结合 Head 维度进行二维切分
// - 公式：core_idx = (b_idx * H + h_idx) % num_cores
void ExampleTiling::GetNeedCoreNum(uint32_t coreNumPlatform)
{
    if (batchSize >= static_cast<int64_t>(coreNumPlatform)) {
        // ========== 大Batch场景：按Batch维度切分 ==========
        // 来自设计文档："大 Batch (B ≥ num_cores)：优先按 Batch 维度切分"
        batchPerCore = CeilA2B(batchSize, coreNumPlatform);
        needCoreNum = CeilA2B(batchSize, batchPerCore);
        needCoreNum = std::min(needCoreNum, static_cast<uint32_t>(MAX_CORE_CONT));
        headPerCore = headNum;  // 每个核心处理完整的Head维度
        
        for (int64_t coreIndex = 0; coreIndex < static_cast<int64_t>(needCoreNum); coreIndex++) {
            batchStart[coreIndex] = coreIndex * batchPerCore;
            batchEnd[coreIndex] = std::min((coreIndex + 1) * batchPerCore, batchSize);
            headStart[coreIndex] = 0;
            headEnd[coreIndex] = headNum;
        }
    } else {
        // ========== 小Batch场景：Batch × Head 二维切分 ==========
        // 来自设计文档："小 Batch (B < num_cores)：结合 Head 维度进行二维切分"
        // 公式：core_idx = (b_idx * H + h_idx) % num_cores
        needCoreNum = std::min(static_cast<uint32_t>(totalBatches), coreNumPlatform);
        needCoreNum = std::min(needCoreNum, static_cast<uint32_t>(MAX_CORE_CONT));
        
        int64_t averageBatches = CeilA2B(totalBatches, needCoreNum);
        
        for (int64_t coreIndex = 0; coreIndex < static_cast<int64_t>(needCoreNum); coreIndex++) {
            int64_t globalStart = coreIndex * averageBatches;
            int64_t globalEnd = std::min((coreIndex + 1) * averageBatches, totalBatches);
            
            // 使用设计文档中的公式转换
            batchStart[coreIndex] = globalStart / headNum;
            headStart[coreIndex] = globalStart % headNum;
            
            batchEnd[coreIndex] = globalEnd / headNum;
            headEnd[coreIndex] = globalEnd % headNum;
            
            // 处理边界情况
            if (headEnd[coreIndex] == 0 && batchEnd[coreIndex] > batchStart[coreIndex]) {
                batchEnd[coreIndex]--;
                headEnd[coreIndex] = headNum;
            }
        }
        
        batchPerCore = CeilA2B(batchSize, 1);
        headPerCore = CeilA2B(headNum, 1);
    }
}

// ==================== CalculateUBStrategy实现 ====================
// UB空间计算 - CRITICAL: 必须严格按照设计文档实现
//
// 设计文档UB空间分配表：
// | 缓冲区名称              | 大小计算                                      |
// |------------------------|---------------------------------------------|
// | x_ref_attn_map_source  | size_per_element * x_seqlens_per_loop * t_seqlens |
// | ref_target_mask        | size_per_element * t_seqlens                |
// | x_ref_attnmap          | size_per_element * x_seqlens_per_loop * t_seqlens (FP32) |
// | x_ref_attnmap_sum      | size_per_element * x_seqlens_per_loop (FP32) |
// | ref_mask_sum           | size_per_element * x_seqlens_per_loop (FP32) |
// | x_ref_attnmap_norm     | size_per_element * x_seqlens_per_loop (FP32) |
// | x_ref_attnmap_permuted | size_per_element * x_seqlens_per_loop * H_per_core (FP32) |
// | output                 | size_per_element * x_seqlens_per_loop       |
void ExampleTiling::CalculateUBStrategy(uint64_t ubSizePlatform)
{
    uint64_t availableUB = ubSizePlatform - RESERVED_LENGTH;
    
    // ========== 逐项计算设计文档中指定的缓冲区大小 ==========
    
    // 输入缓冲区
    int64_t inputAttnSize = xSeqLen * refSeqLen * dataTypeSize;
    int64_t maskSize = refSeqLen * dataTypeSize;
    
    // 中间计算缓冲区 - FP16/BF16输入需升精度到FP32计算
    // 来自设计文档3.3："FP16/BF16 输入需升精度到 FP32 计算"
    int64_t weightedAttnSize = xSeqLen * refSeqLen * BYTE_LEN_4;  // FP32
    int64_t sumResultSize = xSeqLen * BYTE_LEN_4;                 // FP32
    int64_t maskSumSize = xSeqLen * BYTE_LEN_4;                   // FP32
    int64_t normResultSize = xSeqLen * BYTE_LEN_4;                // FP32
    
    // 维度置换后的注意力图
    // 来自设计文档："x_ref_attnmap_permuted: size_per_element * x_seqlens_per_loop * H_per_core"
    int64_t permutedSize = xSeqLen * headPerCore * BYTE_LEN_4;    // FP32
    
    // 输出缓冲区
    int64_t outputSize = xSeqLen * dataTypeSize;
    
    // 32字节对齐
    // 来自设计文档3.3："UB 缓冲区必须按 32 字节对齐"
    int64_t alignPadding = BLOCK;
    
    // 计算总空间
    int64_t totalPerXSeqLen = inputAttnSize + maskSize + weightedAttnSize + 
                              sumResultSize + maskSumSize + normResultSize + 
                              permutedSize + outputSize + alignPadding;
    
    // 计算核内循环次数
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
    
    // 计算临时空间大小
    tmpBufSize = totalPerXSeqLen * xSeqLenPerLoop;
    tmpBufSize = CeilA2B(tmpBufSize, 16) * 16;
}

// ==================== GetWorkSpace实现 ====================
void ExampleTiling::GetWorkSpace()
{
    size_t* workspaces = tilingContext->GetWorkspaceSizes(1);
    workspaces[0] = tmpBufSize;
}

// ==================== 辅助函数实现 ====================
uint64_t ExampleTiling::GetDataTypeVal()
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

uint8_t ExampleTiling::GetDataTypeSize()
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

template <typename T1, typename T2>
inline auto ExampleTiling::CeilA2B(T1 a, T2 b) -> T1
{
    if (b != 0) {
        return (a + b - 1) / b;
    }
    return a;
}

// ==================== FillTilingData实现 ====================
void ExampleTiling::FillTilingData()
{
    // 设置所有字段
    tilingData.set_dataType(GetDataTypeVal());
    tilingData.set_mode(mode);
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
        tilingContext->GetRawTilingData()->GetCapacity());
    tilingContext->GetRawTilingData()->SetDataSize(tilingData.GetDataSize());
}

// ==================== 主入口函数实现 ====================
ge::graphStatus ExampleTiling::RunBigKernelTiling()
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
    auto compileInfo = reinterpret_cast<const ExampleCompileInfo*>(
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

// ==================== 注册函数 ====================
static ge::graphStatus Tiling4Example(gert::TilingContext* context)
{
    ExampleTiling tilingObject(context);
    return tilingObject.RunBigKernelTiling();
}

static ge::graphStatus TilingPrepare4Example(gert::TilingParseContext* context)
{
    auto compileInfo = context->GetCompiledInfo<ExampleCompileInfo>();
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
                "GetHardwareInfo Failed, vectorCoreNum: %u", compileInfo->coreNum),
        return ge::GRAPH_FAILED);
    
    OP_CHECK_IF(
        compileInfo->ubSize <= 0,
        OP_LOGE(context->GetNodeName(), 
                "GetHardwareInfo Failed, ubSize: %lu", compileInfo->ubSize),
        return ge::GRAPH_FAILED);
    
    return ge::GRAPH_SUCCESS;
}

IMPL_OP_OPTILING(Example)
    .Tiling(Tiling4Example)
    .TilingParse<ExampleCompileInfo>(TilingPrepare4Example);

} // namespace optiling
