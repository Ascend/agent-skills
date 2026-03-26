/**
 * Copyright (c) 2026 Huawei Technologies Co., Ltd.
 * This program is free software, you can redistribute it and/or modify it under the terms and conditions of
 * CANN Open Software License Agreement Version 2.0 (the "License").
 * Please refer to the License for details. You may not use this file except in compliance with the License.
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
 * See LICENSE in the root of the software repository for the full text of the License.
 */

#include "register/op_impl_registry.h"
#include "log/log.h"

using namespace ge;
namespace ops {

static ge::graphStatus InferDataTypeForAddExample(gert::InferDataTypeContext* context)
{
    OP_LOGI("Begin InferDataTypeForAddExample");
    const ge::DataType x1DataType = context->GetInputDataType(0);
    context->SetOutputDataType(0, x1DataType);
    return ge::GRAPH_SUCCESS;
}

IMPL_OP(AddExample).InferDataType(InferDataTypeForAddExample);
} // namespace ops
