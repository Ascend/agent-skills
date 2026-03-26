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
 * \file example_infershape.cpp
 * \brief 形状推导样例 - 严格遵循设计文档
 * 
 * 本文件展示了如何根据设计文档实现形状推导。
 * 关键要点：
 * 1. 输入维度校验必须与设计文档规格一致
 * 2. 输出shape推导必须与设计文档一致
 * 3. 数据类型一致性检查
 */

#include "register/op_impl_registry.h"
#include "log/log.h"

using namespace ge;

namespace ops {

// ==================== 索引常量定义 ====================
static constexpr int64_t IDX_X_REF_ATTN_MAP_SOURCE = 0;
static constexpr int64_t IDX_REF_TARGET_MASK = 1;
static constexpr int64_t IDX_OUTPUT = 0;

// ==================== InferShape实现 ====================
// 根据设计文档规格约束实现形状推导
static ge::graphStatus InferShapeExample(gert::InferShapeContext* context)
{
    OP_LOGD(context->GetNodeName(), "Begin to do InferShapeExample");
    
    // Step 1: 获取输入shape
    const gert::Shape* attnMapShape = context->GetInputShape(IDX_X_REF_ATTN_MAP_SOURCE);
    OP_CHECK_NULL_WITH_CONTEXT(context, attnMapShape);
    
    const gert::Shape* maskShape = context->GetInputShape(IDX_REF_TARGET_MASK);
    OP_CHECK_NULL_WITH_CONTEXT(context, maskShape);
    
    // Step 2: 检查输入维度（根据设计文档要求）
    // 设计文档规格:
    //   x_ref_attn_map_source: [B, H, x_seqlens, t_seqlens] - 4D
    //   ref_target_mask: [t_seqlens] - 1D
    
    size_t attnDimNum = attnMapShape->GetDimNum();
    size_t maskDimNum = maskShape->GetDimNum();
    
    if (attnDimNum != 4) {
        OP_LOGE(context->GetNodeName(), 
                "x_ref_attn_map_source must be 4D [B, H, x_seqlens, t_seqlens], got %zu dims", 
                attnDimNum);
        return GRAPH_FAILED;
    }
    
    if (maskDimNum != 1) {
        OP_LOGE(context->GetNodeName(), 
                "ref_target_mask must be 1D [t_seqlens], got %zu dims", 
                maskDimNum);
        return GRAPH_FAILED;
    }
    
    // Step 3: 校验维度一致性
    // 设计文档约束: ref_target_mask长度必须等于x_ref_attn_map_source的最后一维
    int64_t refSeqLen = attnMapShape->GetDim(3);
    int64_t maskSeqLen = maskShape->GetDim(0);
    
    if (refSeqLen != maskSeqLen) {
        OP_LOGE(context->GetNodeName(), 
                "ref_target_mask length (%ld) must match x_ref_attn_map_source last dim (%ld)", 
                maskSeqLen, refSeqLen);
        return GRAPH_FAILED;
    }
    
    // Step 4: 推导输出shape
    // 设计文档规格: output: [B, x_seqlens]
    gert::Shape* outputShape = context->GetOutputShape(IDX_OUTPUT);
    OP_CHECK_NULL_WITH_CONTEXT(context, outputShape);
    
    int64_t batchSize = attnMapShape->GetDim(0);
    int64_t xSeqLen = attnMapShape->GetDim(2);
    
    outputShape->SetDimNum(2);
    outputShape->SetDim(0, batchSize);
    outputShape->SetDim(1, xSeqLen);
    
    OP_LOGD(context->GetNodeName(), "End to do InferShapeExample");
    return GRAPH_SUCCESS;
}

// ==================== InferDataType实现 ====================
// 数据类型一致性检查
static ge::graphStatus InferDataTypeExample(gert::InferDataTypeContext* context)
{
    OP_LOGD(context->GetNodeName(), "Begin to do InferDataTypeExample");
    
    // 输出数据类型与输入一致
    ge::DataType inputDtype = context->GetInputDataType(IDX_X_REF_ATTN_MAP_SOURCE);
    context->SetOutputDataType(IDX_OUTPUT, inputDtype);
    
    OP_LOGD(context->GetNodeName(), "End to do InferDataTypeExample");
    return GRAPH_SUCCESS;
}

// ==================== 注册函数 ====================
IMPL_OP_INFERSHAPE(Example)
    .InferShape(InferShapeExample)
    .InferDataType(InferDataTypeExample);

} // namespace ops
