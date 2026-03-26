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
 * \file stub_ops.h
 * \brief
 */

#ifndef MATH_COMMON_STUB_OPS_H
#define MATH_COMMON_STUB_OPS_H

#include "graph/operator_reg.h"
#include "graph/operator.h"

namespace ge {
/**
*@brief Input data for other operators. \n

*@par Inputs:
*x: A tensor. \n

*@par Attributes:
*index: Index of the input tensor.The data type must be int32 or int64.
Assume that net has three data nodes, one should be set 0, another should
be set 1, and the left should be set 2. \n

*@par Outputs:
*y: A tensor. \n

*@par Third-party framework compatibility
*Compatible with the Caffe operator Data.
*/
REG_OP(Data)
    .INPUT(x, TensorType::ALL())
    .OUTPUT(y, TensorType::ALL())
    .ATTR(index, Int, 0)
    .OP_END_FACTORY_REG(Data)

/**
*@brief Creates a constant tensor from a tensor-like object. This operator is used for inference.
Operator Const has the same definition as operator Constant. \n

*@par Attributes:
*value: Required. The value and type of the resulting tensor, and no restrictions on type. \n

*@par Outputs:
*y: A constant tensor. \n

*@par Third-party framework compatibility
*Compatible with the TensorFlow operator Const.
*/
REG_OP(Const)
    .OUTPUT(y, TensorType::ALL())
    .ATTR(value, Tensor, Tensor())
    .OP_END_FACTORY_REG(Const)

}  // namespace ge

#endif  // MATH_COMMON_STUB_OPS_H
