/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software, you can redistribute it and/or modify it under the terms and conditions of
 * CANN Open Software License Agreement Version 2.0 (the "License").
 * Please refer to the License for details. You may not use this file except in compliance with the License.
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
 * See LICENSE in the root of the software repository for the full text of the License.
 */

#ifndef LEVEL2_BASE_H_MATH
#define LEVEL2_BASE_H_MATH

#include <stdio.h>
#include "op_api/op_api_def.h"
#include "op_api/aclnn_check.h"
#include "aclnn/aclnn_base.h"

#ifdef __cplusplus
extern "C" {
#endif

namespace op {
// 检查1个输入和1个输出是否是空指针
[[maybe_unused]] static bool CheckNotNull2Tensor(const aclTensor* t0, const aclTensor* t1)
{
    OP_CHECK_NULL(t0, return false);
    OP_CHECK_NULL(t1, return false);

    return true;
}

[[maybe_unused]] static bool CheckNotNull3Tensor(const aclTensor* t0, const aclTensor* t1, const aclTensor* t2)
{
    // 检查输入是否是空指针
    OP_CHECK_NULL(t0, return false);
    OP_CHECK_NULL(t1, return false);
    // 检查输入是否是空指针
    OP_CHECK_NULL(t2, return false);

    return true;
}

// 检查3个输入和1个输出是否是空指针
[[maybe_unused]] static bool CheckNotNull4Tensor(
    const aclTensor* t0, const aclTensor* t1, const aclTensor* t2, const aclTensor* t3)
{
    // 检查输入是否是空指针
    OP_CHECK_NULL(t0, return false);
    OP_CHECK_NULL(t1, return false);
    OP_CHECK_NULL(t2, return false);
    // 检查输入是否是空指针
    OP_CHECK_NULL(t3, return false);

    return true;
}

/**
 * 1. 1个输入1个输出
 * 2. 输入输出的shape必须一致
 * 3. 输入的维度必须小于等于8
 */
[[maybe_unused]] static bool CheckSameShape1In1Out(const aclTensor* self, const aclTensor* out)
{
    // self和out的shape必须一致
    OP_CHECK_SHAPE_NOT_EQUAL(self, out, return false);
    // self的维度必须小于等于8
    OP_CHECK_MAX_DIM(self, MAX_SUPPORT_DIMS_NUMS, return false);

    return true;
}

[[maybe_unused]] static bool CheckShapeCumMinMax(
    const aclTensor* self, const aclTensor* valuesOut, const aclTensor* indicesOut)
{
    // 所有输入的维度都不能超过8
    OP_CHECK_MAX_DIM(self, MAX_SUPPORT_DIMS_NUMS, return false);

    // self和valuesOut、indicesOut的shape必须一致
    OP_CHECK_SHAPE_NOT_EQUAL(self, valuesOut, return false);
    OP_CHECK_SHAPE_NOT_EQUAL(self, indicesOut, return false);
    return true;
}

// 检查1个输入和1个输出的数据类型是否在算子的支持列表内
[[maybe_unused]] static bool CheckDtypeValid1In1Out(
    const aclTensor* self, const aclTensor* out, const std::initializer_list<op::DataType>& dtypeSupportList,
    const std::initializer_list<op::DataType>& dtypeOutList)
{
    OP_CHECK_DTYPE_NOT_SUPPORT(self, dtypeSupportList, return false);
    // 检查输出的数据类型是否在算子的支持列表内
    OP_CHECK_DTYPE_NOT_SUPPORT(out, dtypeOutList, return false);

    return true;
}

/**
 * l1: ASCEND910B 或者 ASCEND910_93芯片，该算子支持的数据类型列表
 * l2: 其他芯片，该算子支持的数据类型列表
 */
[[maybe_unused]] static const std::initializer_list<DataType>& GetDtypeSupportListV1(
    const std::initializer_list<op::DataType>& l1, const std::initializer_list<op::DataType>& l2)
{
    if (GetCurrentPlatformInfo().GetCurNpuArch() == NpuArch::DAV_2201) {
        return l1;
    } else {
        return l2;
    }
}

/**
 * l1: ASCEND910B ~ ASCEND910E芯片，该算子支持的数据类型列表
 * l2: 其他芯片，该算子支持的数据类型列表
 */
[[maybe_unused]] static const std::initializer_list<DataType>& GetDtypeSupportListV2(
    const std::initializer_list<op::DataType>& l1, const std::initializer_list<op::DataType>& l2)
{
    auto curArch = GetCurrentPlatformInfo().GetCurNpuArch();
    if(curArch == NpuArch::DAV_2201 || IsRegBase(curArch)) {
        return l1;
    } else {
        return l2;
    }
}

[[maybe_unused]] static const std::initializer_list<op::DataType> GetDtypeSupportListV3(
    const std::initializer_list<op::DataType>& l1, const std::initializer_list<op::DataType>& l2)
{
    auto curArch = GetCurrentPlatformInfo().GetCurNpuArch();
    switch (curArch) {
        case NpuArch::DAV_2201:
        case NpuArch::DAV_3510: {
            return l1;
        }
        case NpuArch::DAV_1001: {
            return l2;
        }
        default: {
            // 如果既不是1971也不是1980，先暂且默认当做1971处理
            return l1;
        }
    }
}
} // namespace op
#ifdef __cplusplus
}
#endif
#endif // LEVEL2_BASE_H_MATH