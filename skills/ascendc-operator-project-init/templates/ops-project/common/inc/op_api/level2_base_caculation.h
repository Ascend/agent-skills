/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software, you can redistribute it and/or modify it under the terms and conditions of
 * CANN Open Software License Agreement Version 2.0 (the "License").
 * Please refer to the License for details. You may not use this file except in compliance with the License.
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
 * See LICENSE in the root of the software repository for the full text of the License.
 */

#ifndef LEVEL2_BASE_CALCULATION_H_
#define LEVEL2_BASE_CALCULATION_H_

#include <bitset>
#include "op_api/op_api_def.h"
#include "aclnn/aclnn_base.h"
#include "opdev/shape_utils.h"
#include "conversion/fill/op_api/fill.h"
#include "aclnn_kernels/reshape.h"
#include "level2_base.h"

#ifdef __cplusplus
extern "C" {
#endif

namespace op {
[[maybe_unused]] static FVector<int64_t> FillScalarGetShapeValue(aclTensor* out)
{
    FVector<int64_t> shape;
    size_t dimNum = out->GetViewShape().GetDimNum();
    for (size_t idx = 0; idx < dimNum; idx++) {
        int64_t tmpVal = out->GetViewShape().GetDim(idx);
        shape.push_back(tmpVal);
    }
    return shape;
}

[[maybe_unused]] static aclnnStatus CheckFillScalarShapeStdAndVar(aclTensor* out, float val, aclOpExecutor* executor)
{
    FVector<int64_t> shape = FillScalarGetShapeValue(out);
    auto dims = executor->ConvertToTensor(shape.data(), shape.size(), op::DataType::DT_INT64);
    CHECK_RET(dims != nullptr, ACLNN_ERR_INNER_NULLPTR);
    auto shapeArray = executor->AllocIntArray(shape.data(), shape.size());
    CHECK_RET(shapeArray != nullptr, ACLNN_ERR_INNER_NULLPTR);

    FVector<float> valVector = {val};
    auto valTensor = executor->ConvertToTensor(valVector.data(), valVector.size(), out->GetDataType());
    CHECK_RET(valTensor != nullptr, ACLNN_ERR_INNER_NULLPTR);
    auto fillOut = l0op::Fill(dims, valTensor, shapeArray, executor);
    CHECK_RET(fillOut != nullptr, ACLNN_ERR_INNER_NULLPTR);
    auto viewCopyResult = l0op::ViewCopy(fillOut, out, executor);
    CHECK_RET(viewCopyResult != nullptr, ACLNN_ERR_INNER_NULLPTR);
    return ACLNN_SUCCESS;
}

[[maybe_unused]] static inline uint64_t GetPosDimWithStd(int64_t dim, int64_t selfdimNum)
{
    if (selfdimNum <= 0) {
        selfdimNum = 1;
    }
    return dim >= 0 ? dim : dim + selfdimNum;
}

[[maybe_unused]] static int64_t CalcShapeProdStdAndVarMean(const aclTensor* self, const aclIntArray* dim)
{
    auto selfViewShape = self->GetViewShape();
    int64_t shapeProd = 1;
    if (selfViewShape.GetDimNum() != 0) {
        // dim为all reduce
        if (dim->Size() == 0) {
            for (size_t i = 0; i < selfViewShape.GetDimNum(); i++) {
                shapeProd *= selfViewShape.GetDim(i);
            }
        } else {
            for (size_t i = 0; i < dim->Size(); i++) {
                shapeProd *= selfViewShape.GetDim(dim->operator[](i));
            }
        }
    }
    return shapeProd;
}

[[maybe_unused]] static aclIntArray* CalcDimWithVar(const aclTensor* self, aclOpExecutor* executor)
{
    FVector<int64_t> dimVector;
    auto selfViewShape = self->GetViewShape();
    size_t selfDimNum = selfViewShape.GetDimNum();
    for (size_t i = 0; i < selfDimNum; i++) {
        dimVector.push_back(static_cast<int64_t>(i));
    }
    return executor->AllocIntArray(dimVector.data(), dimVector.size());
}

[[maybe_unused]] static op::Shape ReduceShapeGetWithVar(const aclTensor* self, const aclIntArray* dim, bool keepdim)
{
    auto selfShape = self->GetViewShape();
    int64_t selfDimNum = selfShape.GetDimNum();
    bool reduceArray[MAX_SUPPORT_DIMS_NUMS] = {false, false, false, false, false, false, false, false};
    int64_t axis;

    op::Shape reduceShape;
    reduceShape.SetDimNum(0);
    if (dim != nullptr && dim->Size() != 0) {
        for (int64_t i = 0; i < static_cast<int64_t>(dim->Size()); i++) {
            axis = dim->operator[](i);
            if (axis < 0) {
                axis = axis + selfDimNum;
            }
            reduceArray[axis] = true;
        }
        for (int64_t i = 0; i < selfDimNum; i++) {
            if (!reduceArray[i]) {
                reduceShape.AppendDim(selfShape.GetDim(i));
            } else if (keepdim) {
                reduceShape.AppendDim(1);
            }
        }
    } else if (keepdim) {
        for (int64_t i = 0; i < selfDimNum; i++) {
            reduceShape.AppendDim(1);
        }
    }
    return reduceShape;
}

} // namespace op
#ifdef __cplusplus
}
#endif
#endif // LEVEL2_BASE_CALCULATION_H_