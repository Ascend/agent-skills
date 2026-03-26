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
 * \file op_util.h
 * \brief
 */

#ifndef CANN_OPS_BUILT_IN_OP_UTIL_H_
#define CANN_OPS_BUILT_IN_OP_UTIL_H_

#include <sstream>
#include "exe_graph/runtime/shape.h"
#include "exe_graph/runtime/tensor.h"

namespace ops {

inline int64_t GetPartShapeSize(const gert::Shape& shape, size_t begin, size_t end)
{
    int64_t size = 1;
    for (size_t i = begin; i < end; i++) {
        size *= shape[i];
    }
    return size;
}

template <typename T1, typename T2>
inline bool IsDimValid(const T1 shape_size, const T2 dim_value)
{
    int64_t minimum_num = static_cast<int64_t>(shape_size) * (-1);
    int64_t maximum_num = static_cast<int64_t>(shape_size) - 1;

    return static_cast<int64_t>(dim_value) >= minimum_num && static_cast<int64_t>(dim_value) <= maximum_num;
}

/*
 * str cat util function
 * param[in] params need concat to string
 * return concatted string
 */
template <typename T>
inline std::string ConcatString(const T& arg)
{
    std::ostringstream oss;
    oss << arg;
    return oss.str();
}

template <typename T, typename... Ts>
inline std::string ConcatString(const T& arg, const Ts&... arg_left)
{
    std::ostringstream oss;
    oss << arg;
    oss << ConcatString(arg_left...);
    return oss.str();
}

inline std::string GetAttrValueErrMsg(
    const std::string& attr_name, const std::string& wrong_val, const std::string& correct_val)
{
    std::string msg =
        ConcatString("attr[", attr_name, "], has wrong value[", wrong_val, "], it should be ", correct_val);
    return msg;
}

template <typename T1, typename T2>
inline std::string GenInvalidDimMsg(const std::string dim_name, const T1 shape_size, const T2 dim_value)
{
    std::string wrong_val = ConcatString(static_cast<int64_t>(dim_value));
    // will be "[-rank, rank)"
    std::string neg_rank = ConcatString(static_cast<int64_t>(shape_size) * (-1));
    std::string expect_val = ConcatString("[", neg_rank, ", ", ConcatString(static_cast<int64_t>(shape_size)), ")");

    return GetAttrValueErrMsg(dim_name, wrong_val, expect_val);
}

template <typename T1, typename T2>
inline std::string GenInvalidDimMsg(
    const std::string dim_name, const size_t dim_idx, const T1 shape_size, const T2 dim_value)
{
    std::string invalid_dim_name = ConcatString(dim_name, "[", ConcatString(dim_idx), "]");

    return GenInvalidDimMsg(invalid_dim_name, shape_size, dim_value);
}

inline bool IsConstTensor(const gert::Tensor* input_tensor)
{
    if (input_tensor != nullptr) {
        if (input_tensor->GetAddr() == nullptr) {
            // empty tensor
            return input_tensor->GetShapeSize() == 0;
        }
        return true;
    }
    return false;
}

inline std::vector<int64_t> ToVector(const gert::Shape& shape)
{
    size_t shape_size = shape.GetDimNum();
    std::vector<int64_t> shape_vec(shape_size, 0);

    for (size_t i = 0; i < shape_size; i++) {
        shape_vec[i] = shape.GetDim(i);
    }
    return shape_vec;
}

template <typename T>
inline std::string ToStringWithSize(const T* value, size_t size)
{
    std::string r = "[";
    for (size_t i = 0; i < size; i++) {
        r = r + std::to_string(value[i]) + ", ";
    }
    r = r + "]";
    return r;
}
} // namespace ops
#endif // CANN_OPS_BUILT_IN_OP_UTIL_H_
