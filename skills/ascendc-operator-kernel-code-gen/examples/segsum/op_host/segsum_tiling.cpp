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
 * \file segsum_tiling.cpp
 * \brief
 */
#include "segsum_tiling.h"

namespace optiling {

constexpr uint64_t WORK_SPACE_SIZE = 32 * 1024 * 1024;

constexpr uint8_t BYTE_LEN_4 = 4;
constexpr uint8_t BYTE_LEN_2 = 2;
constexpr int32_t BLOCK = 32;
constexpr uint64_t DATE_TYPE_FLOAT16 = 1;
constexpr uint64_t DATE_TYPE_FLOAT = 2;
constexpr uint64_t DATE_TYPE_BF16 = 3;
constexpr uint64_t RESERVED_LENGTH = 320;
constexpr uint32_t COMMON_TILING_KEY = 1000;
constexpr uint32_t SMALL_SIZE_TILING_KEY = 1001;
constexpr uint32_t TENSOR_NUM = 4;

class SegsumTiling
{
public:
    explicit SegsumTiling(gert::TilingContext* context) : tilingContext(context){};
    ge::graphStatus RunBigKernelTiling();

private:
    ge::graphStatus ParseInputAttrs();
    void GetWorkSpace(uint32_t needCoreNum);
    void GetNeedCoreNum(uint32_t coreNumPlatform);
    void GetTilingKey(uint64_t ubSizePlatform);
    uint8_t GetDataTypeVal();
    uint8_t GetDataTypeSize();
    void FillTilingData();

    template <typename T1, typename T2>
    inline auto CeilA2B(T1 a, T2 b) -> T1;

private:
    int64_t slideSize = 0;
    SegsumTilingData tilingData;
    gert::TilingContext* tilingContext = nullptr;
    ge::DataType dataType = ge::DT_UNDEFINED;
    gert::Shape inputShape;

    uint16_t dataTypeSize = 4;
    int64_t batches = 1;
    int64_t tailDimSize = 1;
    int32_t batchStart[MAX_CORE_CONT] = {0};
    int32_t batchEnd[MAX_CORE_CONT] = {0};
    int32_t blockSize = 8;
    uint32_t needCoreNum = 0;
    uint32_t tilingKey = 1000;
};
ge::graphStatus SegsumTiling::ParseInputAttrs()
{
    auto srcInputShape = tilingContext->GetInputShape(0);
    int32_t input_dim = srcInputShape->GetStorageShape().GetDimNum();
    inputShape = srcInputShape->GetOriginShape();
    for (int8_t i = 0; i < input_dim - 1; i++) {
        batches *= inputShape.GetDim(i);
    }
    tailDimSize = inputShape.GetDim(input_dim - 1);
    auto temp = tilingContext->GetInputDesc(0);
    dataType = temp->GetDataType();
    blockSize = BLOCK / dataTypeSize;
    return ge::GRAPH_SUCCESS;
}

ge::graphStatus SegsumTiling::RunBigKernelTiling()
{
    ParseInputAttrs();
    size_t* workspaces = tilingContext->GetWorkspaceSizes(1);
    workspaces[0] = WORK_SPACE_SIZE;
    auto compileInfo = reinterpret_cast<const SegsumCompileInfo*>(tilingContext->GetCompileInfo());
    uint32_t coreNumPlatform = compileInfo->coreNum;
    uint64_t ubSizePlatform = compileInfo->ubSize;
    GetNeedCoreNum(coreNumPlatform);
    GetTilingKey(ubSizePlatform);
    FillTilingData();
    return ge::GRAPH_SUCCESS;
}

void SegsumTiling::GetTilingKey(uint64_t ubSizePlatform)
{
    int64_t eachTensorSize = (ubSizePlatform - RESERVED_LENGTH) / TENSOR_NUM;
    int64_t maxSlideSizeUnalign = eachTensorSize / dataTypeSize;
    int64_t maxSlideSizeBlock = maxSlideSizeUnalign / blockSize;
    int64_t maxSlideSize = maxSlideSizeBlock * blockSize;
    if (tailDimSize <= maxSlideSize) {
        tilingKey = SMALL_SIZE_TILING_KEY;
    } else {
        tilingKey = COMMON_TILING_KEY;
    }
    int32_t blockSizeReal = BLOCK / GetDataTypeSize();
    int64_t tailDimSizeAlign = CeilA2B(tailDimSize, blockSizeReal) * blockSizeReal;
    slideSize = std::min(batchEnd[0] * tailDimSizeAlign, maxSlideSize);
}

void SegsumTiling::GetNeedCoreNum(uint32_t coreNumPlatform)
{
    int64_t averageBatches = CeilA2B(batches, coreNumPlatform);
    needCoreNum = CeilA2B(batches, averageBatches);
    for (int64_t coreIndex = 0; coreIndex < needCoreNum; coreIndex++) {
        batchStart[coreIndex] = coreIndex * averageBatches;
        batchEnd[coreIndex] = std::min((coreIndex + 1) * averageBatches, batches);
    }
}

uint8_t SegsumTiling::GetDataTypeVal()
{
    switch (dataType) {
        case ge::DT_FLOAT:
            return DATE_TYPE_FLOAT;
        case ge::DT_FLOAT16:
            return DATE_TYPE_FLOAT16;
        case ge::DT_BF16:
            return DATE_TYPE_BF16;
        default:
            return 0;
    }
}

uint8_t SegsumTiling::GetDataTypeSize()
{
    switch (dataType) {
        case ge::DT_FLOAT:
            return BYTE_LEN_4;
        case ge::DT_FLOAT16:
            return BYTE_LEN_2;
        case ge::DT_BF16:
            return BYTE_LEN_2;
        default:
            return BYTE_LEN_4;
    }
}

template <typename T1, typename T2>
inline auto SegsumTiling::CeilA2B(T1 a, T2 b) -> T1
{
    if (b != 0) {
        return (a + b - 1) / b;
    } else {
        return a;
    }
}

void SegsumTiling::FillTilingData()
{
    tilingData.set_batches(batches);
    tilingData.set_tailDimSize(tailDimSize);
    tilingData.set_batchStart(batchStart);
    tilingData.set_batchEnd(batchEnd);
    tilingData.set_dataType(GetDataTypeVal());
    tilingData.set_needCoreNum(needCoreNum);
    tilingData.set_slideSize(slideSize);

    tilingContext->SetBlockDim(needCoreNum);
    tilingContext->SetTilingKey(tilingKey);

    tilingData.SaveToBuffer(
        tilingContext->GetRawTilingData()->GetData(), tilingContext->GetRawTilingData()->GetCapacity());
    tilingContext->GetRawTilingData()->SetDataSize(tilingData.GetDataSize());
}

static ge::graphStatus Tiling4Segsum(gert::TilingContext* context)
{
    SegsumTiling tilingObject(context);
    return tilingObject.RunBigKernelTiling();
}

static ge::graphStatus TilingPrepare4Segsum(gert::TilingParseContext* context)
{
    auto compileInfo = context->GetCompiledInfo<SegsumCompileInfo>();
    OP_CHECK_NULL_WITH_CONTEXT(context, compileInfo);
    auto platformInfo = context->GetPlatformInfo();
    auto ascendcPlatform = platform_ascendc::PlatformAscendC(platformInfo);
    uint64_t ubSize;
    ascendcPlatform.GetCoreMemSize(platform_ascendc::CoreMemType::UB, ubSize);
    compileInfo->coreNum = ascendcPlatform.GetCoreNumAiv();
    compileInfo->ubSize = ubSize;

    OP_CHECK_IF(
        compileInfo->coreNum <= 0,
        OP_LOGE(
            context->GetNodeName(), "Segsum GetHardwareInfo Failed, vectorCoreNum: %u", compileInfo->coreNum),
        return ge::GRAPH_FAILED);
    OP_CHECK_IF(
        compileInfo->ubSize <= 0,
        OP_LOGE(
            context->GetNodeName(), "Segsum GetHardwareInfo Failed, ubSize: %lu", compileInfo->ubSize),
        return ge::GRAPH_FAILED);
    return ge::GRAPH_SUCCESS;
}

IMPL_OP_OPTILING(Segsum).Tiling(Tiling4Segsum).TilingParse<SegsumCompileInfo>(TilingPrepare4Segsum);
} // namespace optiling