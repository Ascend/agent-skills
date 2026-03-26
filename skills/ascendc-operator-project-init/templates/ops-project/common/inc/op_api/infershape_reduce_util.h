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
 * \file runtime_util.h
 * \brief
 */
#ifndef OPS_MATH_INFERSHAPE_REDUCE_UTIL_H
#define OPS_MATH_INFERSHAPE_REDUCE_UTIL_H

#include "exe_graph/runtime/infer_shape_context.h"
#include "op_common/op_host/util/shape_util.h"
#include "op_common/log/log.h"
#include "op_common/op_host/util/opbase_export.h"

namespace Ops {
namespace Base {

template <typename T>
ge::graphStatus ReduceDimsWithKeepDims(
    const gert::Shape *xShape, const T *axesDims, int32_t axesSize, gert::Shape *outputShape)
{
    T dimNum = xShape->GetDimNum();
    const bool isScalar = xShape->GetDimNum() == 0;
    dimNum = isScalar ? 1 : dimNum;
    *outputShape = *xShape;
    for (int32_t i = 0; i < axesSize; i++) {
        OP_CHECK_IF((!CheckAxisBounds<T, T>(dimNum, axesDims[i])),
            OP_LOGE("reduce", "axesDims is invalid"),
            return ge::GRAPH_FAILED);
        if (isScalar) {
            // no need to update output shape, when input is scalar
            continue;
        }
        T dim = axesDims[i] < 0 ? axesDims[i] + dimNum : axesDims[i];
        outputShape->SetDim(dim, 1);
    }
    OP_LOGD("ReduceDimsWithKeepDims", "after reduce output shape is %s.", ToString(*outputShape).c_str());
    return ge::GRAPH_SUCCESS;
}

template <typename T>
ge::graphStatus ReduceDimsWithoutKeepDims(
    const gert::Shape *xShape, const T *axesDims, int32_t axesSize, gert::Shape *outputShape)
{
    T dimNum = xShape->GetDimNum();
    outputShape->SetDimNum(0);
    for (T j = 0; j < dimNum; j++) {
        bool reduceFlag = false;
        for (int32_t i = 0; i < axesSize; i++) {
            OP_CHECK_IF((!CheckAxisBounds<T, T>(dimNum, axesDims[i])),
                OP_LOGE("reduce", "axesDims is invalid"),
                return ge::GRAPH_FAILED);
            T dim = axesDims[i] < 0 ? axesDims[i] + dimNum : axesDims[i];
            if (dim == j) {
                reduceFlag = true;
                break;
            }
        }
        if (!reduceFlag) {
            outputShape->AppendDim(xShape->GetDim(j));
        }
    }

    OP_LOGD("ReduceDimsWithoutKeepDims", "after reduce output shape is %s.", ToString(*outputShape).c_str());
    return ge::GRAPH_SUCCESS;
}

template <typename T>
ge::graphStatus ReduceDims(const gert::Shape *xShape, const gert::Tensor *axesTensor, int32_t axesSize,
    const bool keepDims, gert::Shape *outputShape)
{
    const T *axesDims = axesTensor->GetData<T>();
    if (keepDims) {
        return ReduceDimsWithKeepDims<T>(xShape, axesDims, axesSize, outputShape);
    }
    return ReduceDimsWithoutKeepDims<T>(xShape, axesDims, axesSize, outputShape);
}
// Do infershape for OP which is single-input single-output and in-shape equal out-shape.
OPBASE_API ge::graphStatus InferShape4Reduce(gert::InferShapeContext *context);
}  // namespace Base
} // namespace Ops

#endif  // OPS_MATH_INFERSHAPE_REDUCE_UTIL_H
