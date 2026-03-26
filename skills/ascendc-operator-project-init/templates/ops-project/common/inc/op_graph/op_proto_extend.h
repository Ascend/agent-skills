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
 * \file op_proto_extend.h
 * \brief
 */
#ifndef OPS_OP_PROTO_EXTEND_H_
#define OPS_OP_PROTO_EXTEND_H_

#include "graph/operator_reg.h"
#include "graph/types.h"

namespace ge {
/**
*@brief Inserts a dimension of 1 into a tensor's shape. Only the tensor shape is changed, without changing the data. \n

*@par Inputs:
*@li x: A tensor.
*@li axis: The dimension index at which to expand. \n

*@par Outputs:
*y: A tensor with the same data as input, with an additional dimension inserted at the index specified by axis. \n

*@par Third-party framework compatibility
*Compatible with the TensorFlow operator ExpandDims.
*/
REG_OP(ExpandDims)
    .INPUT(x, TensorType::ALL())
    .INPUT(axis, TensorType({DT_INT32, DT_INT64}))
    .OUTPUT(y, TensorType::ALL())
    .OP_END_FACTORY_REG(ExpandDims)

/**
*@brief Return a tensor with the same shape and contents as input. \n

*@par Inputs:
*x: A tensor. Must be one of the following types: float32、float16、int8、
int16、uint16、uint8、int32、int64、uint32、uint64、bool、double、string、bfloat16. \n

*@par Outputs:
*y: A tensor with the same shape、data type and contents as input. \n

*@par Third-party framework compatibility
*Compatible with the TensorFlow operator Identity.
*/
REG_OP(Identity)
    .INPUT(x, TensorType::ALL())
    .OUTPUT(y, TensorType::ALL())
    .OP_END_FACTORY_REG(Identity)

/**
* @brief Draws binary random numbers (0 or 1) from a Bernoulli distribution.The input tensor
* should be a tensor containing probabilities p (a value in the range [0, 1]) to be used for
* drawing the binary random number, where an output of 1 is produced with ptobability p and
* an output of 0 is produced with probability (1-p). \n

* @par Inputs:
include:
* @li x: All values in input have to be in the range:[0, 1].
* @li seed: If seed is set to be -1, and offset is set to be 0, the random number
* generator is seeded by a random seed. Otherwise, it is seeded by the given seed.
* @li offset: To avoid seed collision. \n

* @par Attributes:
* @li dtype: The data type for the elements of the output tensor. if not specifed,
* we will use the data type of the input tensor. \n

* @par Outputs:
* y: The returned output tensor only has values 0 or 1, same shape as input tensor. \n

* @par Third-party framework compatibility
* Compatible with the Onnx operator Bernoulli
*/
REG_OP(StatelessBernoulliV2)
    .INPUT(x, TensorType({DT_FLOAT16, DT_FLOAT, DT_DOUBLE}))
    .INPUT(seed, TensorType({DT_INT64}))
    .INPUT(offset, TensorType({DT_INT64}))
    .OUTPUT(y, TensorType({DT_INT8, DT_UINT8, DT_INT16, DT_UINT16, DT_INT32, DT_UINT32,
        DT_INT64, DT_UINT64, DT_BOOL, DT_FLOAT16, DT_FLOAT, DT_DOUBLE, DT_BF16}))
    .ATTR(dtype, Type, DT_UNDEFINED)
    .OP_END_FACTORY_REG(StatelessBernoulliV2)

/**
*@brief Element-wise computes the bitwise left-shift of x and y . \n

*@par Inputs:
*Input "x" is a k-dimensional tensor. Inputs "num_lower" and "num_upper"
are 0D scalars.
* @li x: A Tensor. Must be one of the following types: int8, int16, int32,
int64, uint8, uint16, uint32, uint64.
* @li y: A Tensor. Has the same type as "x".  \n

*@par Outputs:
* z: A Tensor. Has the same type as "x".  \n

*@attention Constraints:
*Unique runs on the Ascend AI CPU, which delivers poor performance.  \n

*@par Third-party framework compatibility
*Compatible with the TensorFlow operator LeftShift.
*/

REG_OP(LeftShift)
    .INPUT(x, TensorType({DT_INT8, DT_INT16, DT_INT32, DT_INT64, \
           DT_UINT8, DT_UINT16, DT_UINT32, DT_UINT64}))
    .INPUT(y, TensorType({DT_INT8, DT_INT16, DT_INT32, DT_INT64, \
           DT_UINT8, DT_UINT16, DT_UINT32, DT_UINT64}))
    .OUTPUT(z, TensorType({DT_INT8, DT_INT16, DT_INT32, DT_INT64, \
            DT_UINT8, DT_UINT16, DT_UINT32, DT_UINT64}))
    .OP_END_FACTORY_REG(LeftShift)

/**
*@brief Computes a 2D Correlation given 4D "x" and "filter" tensors.
*
*@par Inputs:
* @li filter: A 4D tensor of filters.
* @li x: A 4D tensor of input images, batch number must equal to batch
* number of "filter", and channel must equal to channel of "filter".
*
*@par Attributes:
* @li groups: set correlation mode, must be 1 or channel.
*
*@par Outputs:
*y: A Tensor. Has the same type as "x".

*@par Third-party framework compatibility
* Compatible with caffe correlation custom operator.
*/
REG_OP(Correlation)
    .INPUT(filter, TensorType({DT_FLOAT16, DT_INT8}))
    .INPUT(x, TensorType({DT_FLOAT16, DT_INT8}))
    .OUTPUT(y, TensorType({DT_FLOAT16, DT_INT32}))
    .ATTR(groups, Int, 1)
    .OP_END_FACTORY_REG(Correlation)

/**
* @brief Returns a one-hot tensor. The locations represented by index in "x" take value "on_value",
*         while all other locations take value "off_value" .

* @par Inputs:
* Three inputs, including:
* @li x: A Tensor of indices. Must be one of the following types: uint8, int32.
* @li on_value: A scalar. The value to fill in output when indices[j] = i,
*     Must be one of the following types: float16, float32, int32, int8, uint8.
* @li off_value: A scalar. The value to fill in output when indices[j] != i,
*     Has the same type as "on_value" . \n

* @par Attributes:
* @li depth: An required int to specify the depth of the one hot dimension.
* @li axis: An int. The axis to fill. Defaults to "-1" . \n

* @par Outputs:
* y: A Tensor. Has the same type as "on_value" . \n

* @par Third-party framework compatibility:
* Compatible with the TensorFlow operator OneHot.
*
* @par Restrictions:
* Warning: THIS FUNCTION IS DEPRECATED. Please use OneHot instead.
*/
REG_OP(OneHotD)
    .INPUT(x, TensorType({DT_UINT8, DT_INT32}))
    .INPUT(on_value, TensorType({DT_FLOAT16, DT_FLOAT, DT_INT32, DT_UINT8,
                                 DT_INT8}))
    .INPUT(off_value, TensorType({DT_FLOAT16, DT_FLOAT, DT_INT32, DT_UINT8,
                                  DT_INT8}))
    .OUTPUT(y, TensorType({DT_FLOAT16, DT_FLOAT, DT_INT32, DT_UINT8, DT_INT8}))
    .REQUIRED_ATTR(depth, Int)
    .ATTR(axis, Int, -1)
    .OP_END_FACTORY_REG(OneHotD)

/**
*@brief Returns the shape of a tensor. \n

*@par Inputs:
*x: A tensor. Must be one of the following types: float32、float16、int8、
int16、uint16、uint8、int32、int64、uint32、uint64、bool、double、string、bfloat16. \n

*@par Attributes:
*dtype: An optional int32 or int64. The output data type. Defaults to int32. \n

*@par Outputs:
*y: A tensor. The shape of the input tensor. \n

*@par Third-party framework compatibility
*Compatible with the TensorFlow operator Size.
*/
REG_OP(Shape)
    .INPUT(x, TensorType::ALL())
    .OUTPUT(y, TensorType({DT_INT32, DT_INT64}))
    .ATTR(dtype, Int, DT_INT32)
    .OP_END_FACTORY_REG(Shape)

/**
* @brief Returns a batched diagonal tensor with given batched diagonal values .

* @par Inputs:
* Five inputs, including:
* @li diagonal: Rank `r`, where `r >= 1`. \n

* @li k:
* Diagonal offset(s). Positive value means superdiagonal, 0 refers to the main
* diagonal, and negative value means subdiagonals. `k` can be a single integer
* (for a single diagonal) or a pair of integers specifying the low and high ends
* of a matrix band. `k[0]` must not be larger than `k[1]`. \n

* @li num_rows:
* The number of rows of the output matrix. If it is not provided, the op assumes
* the output matrix is a square matrix and infers the matrix size from k and the
* innermost dimension of `diagonal`. \n

* @li num_cols: An NCHW, NHWC, or ND Tensor.
* The number of columns of the output matrix. If it is not provided, the op
* assumes the output matrix is a square matrix and infers the matrix size from
* k and the innermost dimension of `diagonal`. \n

* @li padding_value: The number to fill the area outside the specified diagonal band with. \n

* @par Outputs:
* output: Has rank `r+1` when `k` is an integer or `k[0] == k[1]`, rank `r` otherwise . \n

* @par Third-party framework compatibility
* Compatible with the TensorFlow operator ScatterUpdate.
*/
REG_OP(MatrixDiagV2)
    .INPUT(diagonal, TensorType::BasicType())
    .INPUT(k, TensorType({DT_INT32}))
    .INPUT(num_rows, TensorType({DT_INT32}))
    .INPUT(num_cols, TensorType({DT_INT32}))
    .INPUT(padding_value, TensorType::BasicType())
    .OUTPUT(output, TensorType::BasicType())
    .OP_END_FACTORY_REG(MatrixDiagV2)

/**
*@brief Add tensor with value.

*@par Inputs:
*One input, including: \n
* x: A ND Tensor. Must be one of the following types:int32,int16, float16, float32, bfloat16. \n

*@par Attributes:
*value: A scale. Must be float. \n

*@par Outputs:
*y: A ND Tensor. Has the same dtype and shape as "x1". \n

*@par Third-party framework compatibility:
* Compatible with the PyTorch operator adds.
*@attention Constraints:
* For parameters of the float32 type, there is no precision loss. For INT32 and INT64 parameters,
* precision loss occurs when the parameter value exceeds 2^24. it is recommended to use Add.
*/
 REG_OP(Adds)
     .INPUT(x, TensorType({DT_FLOAT, DT_INT16, DT_INT32, DT_FLOAT16, DT_BF16}))
     .OUTPUT(y, TensorType({DT_FLOAT, DT_INT16, DT_INT32, DT_FLOAT16, DT_BF16}))
     .REQUIRED_ATTR(value,Float)
     .OP_END_FACTORY_REG(Adds)

/**
*@brief Draws samples from a multinomial distribution .

*@par Inputs:
*Inputs include:
* @li logits: A Tensor. Must be one of the following types: float16, float, double.
2-D Tensor with shape [batch_size, num_classes].
* @li num_samples: A Tensor of type int32. 0-D. Number of independent samples to draw for each row slice . \n

*@par Attributes:
*@li output_dtype: An optional type from: int32, int64. Defaults to int64.
*@li seed: An optional int. Defaults to 0.
*@li seed2: An optional int. Defaults to 0 . \n

*@par Outputs:
*y_indices: A Tensor of type output_dtype . \n

*@attention Constraints:
*The implementation for Multinomial on Ascend uses AICPU, with bad performance.

*@par Third-party framework compatibility
*@li compatible with tensorflow Multinomial operator.
*/
REG_OP(Multinomial)
    .INPUT(logits, TensorType({DT_FLOAT16, DT_FLOAT, DT_DOUBLE}))
    .INPUT(num_samples, TensorType({DT_INT32}))
    .OUTPUT(y, TensorType({DT_INT32, DT_INT64}))
    .ATTR(dtype, Type, DT_INT64)
    .ATTR(seed, Int, 0)
    .ATTR(seed2, Int, 0)
    .OP_END_FACTORY_REG(Multinomial)

/**
* @brief Concatenates a list of "N" tensors along "concat_dim". 
        All input of the PhonyConcat are allocated with the same memory block. 
        GE calculates the memory offset of each input, 
        and the custom operators before write the memory by offset.
* Warning: This operator is used only to identify that the GE allocates continuous memory and does not perform any calculation.

* @par Inputs:
* Dynamic input: A list of input tensors. Has the same type and format as "x" .
* @li x:An ND Tensor.
* Must be one of the following types: float16, float32, int32, int8, int16,
  int64, uint8, uint16, uint32, uint64, bool, bfloat16.

* @par Attributes:
* @li concat_dim: A required list of int32. Specifies the dimensions along which to concat. No default value.
* @li N: A required list of int32. Specifies the number of concat tensors. No default value .
* @li keep_input_offset: A optional Bool. Specifies whether calculate the memory offset of input tensors. Default True .

* @par Outputs:
* @li y:One output.

* @attention Constraints:
* @li "concat_dim" is in the range [-len(x.shape), (x.shape)-1] .
* @li "N" is greater than or equals to 1.

* @par Third-party framework support
* Support ONNX  framework.
*/
REG_OP(PhonyConcat)
    .DYNAMIC_INPUT(x, TensorType::ALL())
    .OUTPUT(y, TensorType::ALL())
    .REQUIRED_ATTR(concat_dim, ListInt)
    .REQUIRED_ATTR(N, ListInt)
    .ATTR(keep_input_offset, Bool, true)
    .OP_END_FACTORY_REG(PhonyConcat)

/**
* @brief Splits a tensor along dimension "split_dim" into "num_split" smaller tensors. 
        All outputs of the PhonySplit are allocated with the same memory block. 
        GE calculates the memory offset of each output, 
        and the custom operators next read the memory by offset.
* Warning: This operator is used only to identify that the GE allocates continuous memory and does not perform any calculation.

* @par Inputs:
* One input:
* @li x:An ND Tensor.
* Must be one of the following types: float16, float32, int32, int8, int16,
  int64, uint8, uint16, uint32, uint64, bool, bfloat16.

* @par Attributes:
* @li split_dim: A required int32. Specifies the dimension along which to split. No default value.
* @li num_split: A required int32. Specifies the number of output tensors. No default value .
* @li keep_output_offset: A optional Bool. Specifies whether calculate the memory offset of outpute tensors. Default True .

* @par Outputs:
* @li y:Dynamic output. A list of output tensors. Has the same type and format as "x" .

* @attention Constraints:
* @li "num_split" is greater than or equals to 1.
* @li "num_split" is divisible by the size of dimension "split_dim".
* @li "split_dim" is in the range [-len(x.shape), (x.shape)-1] .

* @par Third-party framework support
* Support ONNX  framework.
*/
REG_OP(PhonySplit)
    .INPUT(x, TensorType::ALL())
    .DYNAMIC_OUTPUT(y, TensorType::ALL())
    .REQUIRED_ATTR(split_dim, ListInt)
    .REQUIRED_ATTR(num_split, ListInt)
    .ATTR(keep_output_offset, Bool, true)
    .OP_END_FACTORY_REG(PhonySplit)

/**
*@brief Outputs random integers from a uniform distribution. \n

*@par Inputs:
*Inputs include:
* @li shape: A Tensor. Must be one of the following types: int32, int64. The shape of the output tensor.
* @li min: A Tensor. Must be one of the following types: int32, int64. 0-D.
* @li max: A Tensor. Must have the same type as min. 0-D . \n

*@par Attributes:
*@li seed: An optional int. Defaults to 0. If either seed or seed2 are set to be non-zero, 
the random number generator is seeded by the given seed. Otherwise, it is seeded by a random seed.
*@li seed2: An optional int. Defaults to 0 . A second seed to avoid seed collision. \n

*@par Outputs:
*y: A Tensor. Has the same type as min. \n

*@attention Constraints:
*The implementation for RandomUniformInt on Ascend uses AICPU, with bad performance.

*@par Third-party framework compatibility
*@li compatible with tensorflow RandomUniformInt operator.
*/
REG_OP(RandomUniformInt)
    .INPUT(shape, TensorType({DT_INT32, DT_INT64}))
    .INPUT(min, TensorType({DT_INT32, DT_INT64}))
    .INPUT(max, TensorType({DT_INT32, DT_INT64}))
    .OUTPUT(y, TensorType({DT_INT32, DT_INT64}))
    .ATTR(seed, Int, 0)
    .ATTR(seed2, Int, 0)
    .OP_END_FACTORY_REG(RandomUniformInt)

/**
*@brief Outputs random values from a uniform distribution. \n

*@par Inputs:
*Inputs include:
*shape: A Tensor. Must be one of the following types: int32, int64. The shape of the output tensor. \n

*@par Attributes:
*@li dtype: A type from: float16, float32, double, bfloat16. The type of the output.
*@li seed: An optional int. Defaults to 0. If either seed or seed2 are set to be non-zero, 
the random number generator is seeded by the given seed. Otherwise, it is seeded by a random seed.
*@li seed2: An optional int. Defaults to 0 . A second seed to avoid seed collision. \n

*@par Outputs:
*y: A Tensor of type float32, float16, double, bfloat16. \n

*@attention Constraints:
*The implementation for RandomUniform on Ascend uses AICPU, with bad performance.

*@par Third-party framework compatibility
*@li compatible with tensorflow RandomUniform operator.
*/
REG_OP(RandomUniform)
    .INPUT(shape, TensorType({DT_INT32, DT_INT64}))
    .OUTPUT(y, TensorType({DT_FLOAT16, DT_FLOAT, DT_DOUBLE, DT_BF16}))
    .REQUIRED_ATTR(dtype, Type)
    .ATTR(seed, Int, 0)
    .ATTR(seed2, Int, 0)
    .OP_END_FACTORY_REG(RandomUniform)

/**
* @brief Returns the lower or upper triangular part of a matrix (2-D tensor) or batch of matrices input \n

*@par Inputs:
* @li x: A tensor, which supports 2-8 dimensions or be empty. Must be one of the following types:
* float16, bfloat16, float32, double, int32, uint8, int16, int8, int64,
* qint8, quint8, qint32, quint16, qint16, uint16, uint32, uint64, bool. \n

* @li k: An optional input tensor indicates the diagonal to consider. Must be int32 or int64 type. If no input,
* will be considerer as 0.

* @par Attributes:
* upper: An attribute indicates which part of the triangular matrix to be returned. Must be int32 type.
* If upper is 1, returns the upper triangular matrix, 
* else if upper is 0, returns the lower triangular matrix. Default is 0. \n

* @par Outputs:
* y: A tensor. Has the same type and shape as "x" . \n

*/
REG_OP(Trilu)
    .INPUT(x, "T")
    .OPTIONAL_INPUT(k, "T_K")
    .ATTR(upper, Int, 0)
    .OUTPUT(y, "T")
    .DATATYPE(T, TensorType({DT_FLOAT16, DT_BF16, DT_FLOAT, DT_DOUBLE, DT_INT32, DT_UINT8, DT_INT16,
                          DT_INT8, DT_INT64, DT_QINT8, DT_QUINT8, DT_QINT32, DT_QUINT16, DT_QINT16,
                          DT_UINT16, DT_UINT32, DT_UINT64, DT_BOOL}))
    .DATATYPE(T_K, TensorType({DT_INT32, DT_INT64}))
    .OP_END_FACTORY_REG(Trilu)

/**
*@brief Outputs random values from a normal distribution. \n

*@par Inputs:
*Inputs include:
*shape: A Tensor. Must be one of the following types: int32, int64. The shape of the output tensor. \n

*@par Attributes:
*@li dtype: A type from: float16, float32, double, bfloat16. The type of the output.
*@li seed: An optional int. Defaults to 0. If either seed or seed2 are set to be non-zero, 
the random number generator is seeded by the given seed. Otherwise, it is seeded by a random seed.
*@li seed2: An optional int. Defaults to 0 . A second seed to avoid seed collision. \n

*@par Outputs:
*y: A Tensor of type float32, float16, double, bfloat16. \n

*@attention Constraints:
*The implementation for RandomStandardNormal on Ascend uses AICPU, with bad performance.

*@par Third-party framework compatibility
*@li compatible with tensorflow RandomStandardNormal operator.
*/
REG_OP(RandomStandardNormal)
    .INPUT(shape, TensorType({DT_INT32, DT_INT64}))
    .OUTPUT(y, TensorType({DT_FLOAT16, DT_FLOAT, DT_DOUBLE, DT_BF16}))
    .REQUIRED_ATTR(dtype, Type)
    .ATTR(seed, Int, 0)
    .ATTR(seed2, Int, 0)
    .OP_END_FACTORY_REG(RandomStandardNormal)

}  // namespace ge

#endif