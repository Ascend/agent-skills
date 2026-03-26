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
 * \file aclnn_check.h
 * \brief
 */

#ifndef MATH_COMMON_ACLNN_CHECK_H
#define MATH_COMMON_ACLNN_CHECK_H

#include <set>
#include "opdev/platform.h"
#include "aclnn_kernels/common/op_error_check.h"
#include "opdev/tensor_view_utils.h"

#define OP_CONCAT(a, b) a##b

#define GET_ARGS_COUNT(...) GET_ARGS_COUNT_IMP(__VA_ARGS__, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0)

#define GET_ARGS_COUNT_IMP(_1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, N, ...) N

#define CHECK_NOT_NULL_IMPL_1(param1) OP_CHECK_NULL(param1, return ACLNN_ERR_PARAM_NULLPTR)

#define CHECK_NOT_NULL_IMPL_2(param1, param2)              \
    OP_CHECK_NULL(param1, return ACLNN_ERR_PARAM_NULLPTR); \
    CHECK_NOT_NULL_IMPL_1(param2)

#define CHECK_NOT_NULL_IMPL_3(param1, param2, param3)      \
    OP_CHECK_NULL(param1, return ACLNN_ERR_PARAM_NULLPTR); \
    CHECK_NOT_NULL_IMPL_2(param2, param3)

#define CHECK_NOT_NULL_IMPL_4(param1, param2, param3, param4) \
    OP_CHECK_NULL(param1, return ACLNN_ERR_PARAM_NULLPTR);    \
    CHECK_NOT_NULL_IMPL_3(param2, param3, param4)

#define CHECK_NOT_NULL_IMPL_5(param1, param2, param3, param4, param5) \
    OP_CHECK_NULL(param1, return ACLNN_ERR_PARAM_NULLPTR);            \
    CHECK_NOT_NULL_IMPL_4(param2, param3, param4, param5)

#define CHECK_NOT_NULL_IMPL_6(param1, param2, param3, param4, param5, param6) \
    OP_CHECK_NULL(param1, return ACLNN_ERR_PARAM_NULLPTR);                    \
    CHECK_NOT_NULL_IMPL_5(param2, param3, param4, param5, param6)

#define CHECK_NOT_NULL_IMPL_7(param1, param2, param3, param4, param5, param6, param7) \
    OP_CHECK_NULL(param1, return ACLNN_ERR_PARAM_NULLPTR);                            \
    CHECK_NOT_NULL_IMPL_6(param2, param3, param4, param5, param6, param7)

#define CHECK_NOT_NULL_IMPL_8(param1, param2, param3, param4, param5, param6, param7, param8) \
    OP_CHECK_NULL(param1, return ACLNN_ERR_PARAM_NULLPTR);                                    \
    CHECK_NOT_NULL_IMPL_7(param2, param3, param4, param5, param6, param7, param8)

#define CHECK_NOT_NULL_IMPL(count, ...) OP_CONCAT(CHECK_NOT_NULL_IMPL_, count)(__VA_ARGS__)

#define CHECK_NOT_NULL(...) CHECK_NOT_NULL_IMPL(GET_ARGS_COUNT(__VA_ARGS__), __VA_ARGS__)

#define CHECK_SHAPE_IMPL_2(param1, param2)                                    \
    OP_CHECK_SHAPE_NOT_EQUAL(param1, param2, return ACLNN_ERR_PARAM_INVALID); \
    OP_CHECK_MAX_DIM(param1, MAX_SUPPORT_DIMS_NUMS, return ACLNN_ERR_PARAM_INVALID)

#define CHECK_SHAPE_IMPL_3(param1, param2, param3)                            \
    OP_CHECK_SHAPE_NOT_EQUAL(param1, param2, return ACLNN_ERR_PARAM_INVALID); \
    CHECK_SHAPE_IMPL_2(param2, param3)

#define CHECK_SHAPE_IMPL_4(param1, param2, param3, param4)                    \
    OP_CHECK_SHAPE_NOT_EQUAL(param1, param2, return ACLNN_ERR_PARAM_INVALID); \
    CHECK_SHAPE_IMPL_3(param2, param3, param4)

#define CHECK_SHAPE_IMPL_5(param1, param2, param3, param4, param5)            \
    OP_CHECK_SHAPE_NOT_EQUAL(param1, param2, return ACLNN_ERR_PARAM_INVALID); \
    CHECK_SHAPE_IMPL_4(param2, param3, param4, param5)

#define CHECK_SHAPE_IMPL_6(param1, param2, param3, param4, param5, param6)    \
    OP_CHECK_SHAPE_NOT_EQUAL(param1, param2, return ACLNN_ERR_PARAM_INVALID); \
    CHECK_SHAPE_IMPL_5(param2, param3, param4, param5, param6)

#define CHECK_SHAPE_IMPL_7(param1, param2, param3, param4, param5, param6, param7) \
    OP_CHECK_SHAPE_NOT_EQUAL(param1, param2, return ACLNN_ERR_PARAM_INVALID);      \
    CHECK_SHAPE_IMPL_6(param2, param3, param4, param5, param6, param7)

#define CHECK_SHAPE_IMPL_8(param1, param2, param3, param4, param5, param6, param7, param8) \
    OP_CHECK_SHAPE_NOT_EQUAL(param1, param2, return ACLNN_ERR_PARAM_INVALID);              \
    CHECK_SHAPE_IMPL_7(param2, param3, param4, param5, param6, param7, param8)

#define CHECK_SHAPE_ALL_EQUAL_IMPL(count, ...) OP_CONCAT(CHECK_SHAPE_IMPL_, count)(__VA_ARGS__)

#define CHECK_SHAPE_ALL_EQUAL(...) CHECK_SHAPE_ALL_EQUAL_IMPL(GET_ARGS_COUNT(__VA_ARGS__), __VA_ARGS__)

namespace op {
// 检查1个输入和1个输出的数据类型是否在算子的支持列表内
[[maybe_unused]] static bool CheckDtypeWithEachList(
    const aclTensor* self, const aclTensor* out, const std::initializer_list<op::DataType>& dtypeSelfList,
    const std::initializer_list<op::DataType>& dtypeOutList)
{
    OP_CHECK_DTYPE_NOT_SUPPORT(self, dtypeSelfList, return false);
    // 检查输出的数据类型是否在算子的支持列表内
    OP_CHECK_DTYPE_NOT_SUPPORT(out, dtypeOutList, return false);

    return true;
}

[[maybe_unused]] static bool CheckDtypeWithSameList(
    const aclTensor* self, const aclTensor* out, const std::initializer_list<op::DataType>& dtypeSelfList)
{
    OP_CHECK_DTYPE_NOT_SUPPORT(self, dtypeSelfList, return false);
    // 检查输出的数据类型是否在算子的支持列表内
    OP_CHECK_DTYPE_NOT_SUPPORT(out, dtypeSelfList, return false);

    return true;
}

[[maybe_unused]] static bool CheckShapeAndScalarSame(const aclTensor* t0, const aclTensor* t1)
{
    auto const& t0Shape = t0->GetViewShape();
    auto const& t1Shape = t1->GetViewShape();
    if (t0Shape == t1Shape) {
        return true;
    }
    if (t0Shape.GetShapeSize() == 1 && t1Shape.GetShapeSize() == 1) {
        return true;
    }
    OP_LOGE(
        ACLNN_ERR_PARAM_INVALID, "The tensor's shape[%s] is not equal with shape[%s].",
        op::ToString(t0Shape).GetString(), op::ToString(t1Shape).GetString());
    return false;
}

// 判断Tensor是否只是silce和stride_silce场景
inline bool IsReduceNonContiguousSupport(const aclTensor* x, const aclIntArray* dims)
{
    constexpr int MAX_DIM_SUPPORT = 4;
    constexpr int MIN_DIM_SUPPORT = 1;
    if (!op::Validate(x)) { // 校验偏移是否越界
        OP_LOGE(ACL_ERROR_INVALID_PARAM, "INvalid input tensor: %s", x->ToString().GetString());
        return false;
    }

    auto viewShape = x->GetViewShape();
    auto viewStrides = x->GetViewStrides();

    if (viewShape.GetDimNum() > MAX_DIM_SUPPORT || viewShape.GetDimNum() < MIN_DIM_SUPPORT) { // 不支持大于4维和标量
        OP_LOGD(" NonContiguous only Support 1<=dim<=4, but the current dimnum is %d", viewShape.GetDimNum());
        return false;
    }
    bool allReduceAxisIsDimOne{true};
    uint64_t size = 0;
    aclGetIntArraySize(dims, &size);
    if (size == 0) {    // 空dim按allReudce处理
 	    for (size_t i = 0; i < viewShape.GetDimNum(); i++) {
 	        if (viewShape.GetDim(i) != 1) {
 	            allReduceAxisIsDimOne = false;
 	            break;
 	        }
 	    }
 	} else {
 	    for (size_t i = 0; i < size; i++) {
 	        int64_t dim = (*dims)[i];
 	        if (dim < 0) {
 	            dim = dim + viewShape.GetDimNum();
 	        }
 	        if (viewShape.GetDim(dim) != 1) {
 	            allReduceAxisIsDimOne = false;
 	            break;
 	        }
 	    }
 	}
    if (allReduceAxisIsDimOne) {    // 不支持非连续的纯搬运
        OP_LOGD("NonContiguous not Support tensorMoving");
        return false;
    }
    if (viewStrides[viewShape.GetDimNum() - 1] <= 0) {
        OP_LOGD("NonContiguous not Support strides <= 0");
        return false;
    }
    for (int i = viewShape.GetDimNum() - 1; i > 0; i--) {
        if ((viewShape[i] - 1) * viewStrides[i] >= viewStrides[i - 1]) {
            OP_LOGD("as_stride,transpose NonContiguous not Support");
            return false; // 不支持as_stride,transpose
        }
    }
    return true;
}

static inline bool IsRegBase(NpuArch arch)
{
    const static std::set<NpuArch> regbaseArch = {NpuArch::DAV_3510};
    return regbaseArch.find(arch) != regbaseArch.end();
}

static inline bool IsRegBase()
{
    const static std::set<NpuArch> regbaseArch = {NpuArch::DAV_3510};
    auto curArch = GetCurrentPlatformInfo().GetCurNpuArch();
    return regbaseArch.find(curArch) != regbaseArch.end();
}

} // namespace op
#endif
