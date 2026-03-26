# InferShape文件模板指南

## 文件结构

```cpp
/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software...
 */

/*!
 * \file {op_name}_infershape.cpp
 * \brief {OpName} InferShape Implementation
 */

#include "register/op_impl_registry.h"
#include "register/op_registry.h"

namespace ops {

class {OpName}InferShape : public OpInferShape {
public:
    ge::graphStatus InferShape(gert::InferShapeContext* context) override
    {
        // 参数校验
        // 形状推导
        // 输出设置
    }
};

OP_INFERSHAPE_REG({OpName}, {OpName}InferShape);

} // namespace ops
```

## 参数校验模式

### 输入数量校验

```cpp
// 检查输入数量
int64_t inputNum = context->GetInputNum();
if (inputNum < 2 || inputNum > 3) {
    OP_LOGE(context->GetNodeName(), 
            "Invalid input number: %ld, expected 2 or 3", 
            inputNum);
    return ge::GRAPH_FAILED;
}
```

### Shape获取与校验

```cpp
// 获取输入shape
auto xShape = context->GetInputShape(0);
if (xShape == nullptr) {
    OP_LOGE(context->GetNodeName(), "GetInputShape failed for input 0");
    return ge::GRAPH_FAILED;
}

// 检查维度
int32_t xRank = xShape->GetStorageShape().GetDimNum();
if (xRank < 2) {
    OP_LOGE(context->GetNodeName(), 
            "Input rank must be at least 2, got %d", 
            xRank);
    return ge::GRAPH_FAILED;
}

// 检查维度大小
for (int32_t i = 0; i < xRank; i++) {
    int64_t dimSize = xShape->GetOriginShape().GetDim(i);
    if (dimSize <= 0) {
        OP_LOGE(context->GetNodeName(), 
                "Invalid dim size at axis %d: %ld", 
                i, dimSize);
        return ge::GRAPH_FAILED;
    }
}
```

### 数据类型校验

```cpp
// 获取数据类型
auto xDesc = context->GetInputDesc(0);
if (xDesc == nullptr) {
    OP_LOGE(context->GetNodeName(), "GetInputDesc failed for input 0");
    return ge::GRAPH_FAILED;
}
ge::DataType xDtype = xDesc->GetDataType();

// 检查数据类型
if (xDtype != ge::DT_FLOAT16 && 
    xDtype != ge::DT_FLOAT && 
    xDtype != ge::DT_BF16) {
    OP_LOGE(context->GetNodeName(), 
            "Unsupported data type: %d", 
            xDtype);
    return ge::GRAPH_FAILED;
}
```

### 多输入一致性校验

```cpp
// 检查两个输入的数据类型一致
auto x1Desc = context->GetInputDesc(0);
auto x2Desc = context->GetInputDesc(1);
if (x1Desc->GetDataType() != x2Desc->GetDataType()) {
    OP_LOGE(context->GetNodeName(), 
            "Input data types must match: %d vs %d",
            x1Desc->GetDataType(), x2Desc->GetDataType());
    return ge::GRAPH_FAILED;
}
```

### Shape匹配校验

```cpp
// 检查gamma/beta与输入最后一维匹配
int64_t normDimSize = xShape->GetOriginShape().GetDim(xRank - 1);

auto gammaShape = context->GetInputShape(1);
if (gammaShape == nullptr) {
    OP_LOGE(context->GetNodeName(), "GetInputShape failed for gamma");
    return ge::GRAPH_FAILED;
}

int64_t gammaSize = gammaShape->GetOriginShape().GetDim(0);
if (gammaSize != normDimSize) {
    OP_LOGE(context->GetNodeName(), 
            "Gamma size (%ld) must match normalization dimension size (%ld)", 
            gammaSize, normDimSize);
    return ge::GRAPH_FAILED;
}
```

### 属性校验

```cpp
// 获取并校验属性
auto attrList = context->GetAttrList();
if (attrList != nullptr) {
    auto epsilonAttr = attrList->GetAttr("epsilon");
    if (epsilonAttr != nullptr) {
        float epsilon = epsilonAttr->GetFloat();
        if (epsilon <= 0.0f) {
            OP_LOGE(context->GetNodeName(), 
                    "Epsilon must be positive, got %f", 
                    epsilon);
            return ge::GRAPH_FAILED;
        }
    }
}
```

## 输出Shape设置

### 直接复制输入Shape

```cpp
// 输出shape与输入相同
context->SetOutputShape(0, xShape);
```

### 构造新Shape

```cpp
// 构造新的shape
gert::Shape outputShape;
outputShape.SetOriginShape(xShape->GetOriginShape());
outputShape.SetStorageShape(xShape->GetStorageShape());
context->SetOutputShape(0, &outputShape);
```

### 归约后Shape

```cpp
// 归约操作后的shape
int32_t axis = -1;  // 从属性获取
bool keepDims = false;

auto attrList = context->GetAttrList();
if (attrList != nullptr) {
    auto axisAttr = attrList->GetAttr("axis");
    if (axisAttr != nullptr) {
        axis = axisAttr->GetInt();
    }
    auto keepDimsAttr = attrList->GetAttr("keep_dims");
    if (keepDimsAttr != nullptr) {
        keepDims = keepDimsAttr->GetBool();
    }
}

// 处理负数axis
if (axis < 0) {
    axis = xRank + axis;
}

// 构造输出shape
gert::Shape outputShape;
for (int32_t i = 0; i < xRank; i++) {
    if (i == axis) {
        if (keepDims) {
            outputShape.AppendDim(1);
        }
    } else {
        outputShape.AppendDim(xShape->GetOriginShape().GetDim(i));
    }
}
context->SetOutputShape(0, &outputShape);
```

## 完整模板示例

### 归一化类算子

```cpp
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
 * \file rmsnorm_infershape.cpp
 * \brief RMSNorm InferShape Implementation
 */

#include "register/op_impl_registry.h"
#include "register/op_registry.h"

namespace ops {

class RmsNormInferShape : public OpInferShape {
public:
    ge::graphStatus InferShape(gert::InferShapeContext* context) override
    {
        // Step 1: 检查输入数量
        int64_t inputNum = context->GetInputNum();
        if (inputNum < 2 || inputNum > 3) {
            OP_LOGE(context->GetNodeName(), 
                    "Invalid input number: %ld, expected 2 or 3", 
                    inputNum);
            return ge::GRAPH_FAILED;
        }

        // Step 2: 获取并校验输入x
        auto xShape = context->GetInputShape(0);
        if (xShape == nullptr) {
            OP_LOGE(context->GetNodeName(), "GetInputShape failed for input 0");
            return ge::GRAPH_FAILED;
        }

        int32_t xRank = xShape->GetStorageShape().GetDimNum();
        if (xRank < 2) {
            OP_LOGE(context->GetNodeName(), 
                    "Input rank must be at least 2, got %d", 
                    xRank);
            return ge::GRAPH_FAILED;
        }

        // Step 3: 获取并校验gamma
        auto gammaShape = context->GetInputShape(1);
        if (gammaShape == nullptr) {
            OP_LOGE(context->GetNodeName(), "GetInputShape failed for gamma");
            return ge::GRAPH_FAILED;
        }

        int32_t gammaRank = gammaShape->GetStorageShape().GetDimNum();
        if (gammaRank != 1) {
            OP_LOGE(context->GetNodeName(), 
                    "Gamma rank must be 1, got %d", 
                    gammaRank);
            return ge::GRAPH_FAILED;
        }

        // Step 4: 检查gamma与输入最后一维匹配
        int64_t normDimSize = xShape->GetOriginShape().GetDim(xRank - 1);
        int64_t gammaSize = gammaShape->GetOriginShape().GetDim(0);
        if (gammaSize != normDimSize) {
            OP_LOGE(context->GetNodeName(), 
                    "Gamma size (%ld) must match normalization dimension size (%ld)", 
                    gammaSize, normDimSize);
            return ge::GRAPH_FAILED;
        }

        // Step 5: 检查beta（如果存在）
        if (inputNum == 3) {
            auto betaShape = context->GetInputShape(2);
            if (betaShape == nullptr) {
                OP_LOGE(context->GetNodeName(), "GetInputShape failed for beta");
                return ge::GRAPH_FAILED;
            }
            int32_t betaRank = betaShape->GetStorageShape().GetDimNum();
            if (betaRank != 1) {
                OP_LOGE(context->GetNodeName(), 
                        "Beta rank must be 1, got %d", 
                        betaRank);
                return ge::GRAPH_FAILED;
            }
            int64_t betaSize = betaShape->GetOriginShape().GetDim(0);
            if (betaSize != normDimSize) {
                OP_LOGE(context->GetNodeName(), 
                        "Beta size (%ld) must match normalization dimension size (%ld)", 
                        betaSize, normDimSize);
                return ge::GRAPH_FAILED;
            }
        }

        // Step 6: 检查epsilon属性
        auto attrList = context->GetAttrList();
        if (attrList != nullptr) {
            auto epsilonAttr = attrList->GetAttr("epsilon");
            if (epsilonAttr != nullptr) {
                float epsilon = epsilonAttr->GetFloat();
                if (epsilon <= 0.0f) {
                    OP_LOGE(context->GetNodeName(), 
                            "Epsilon must be positive, got %f", 
                            epsilon);
                    return ge::GRAPH_FAILED;
                }
            }
        }

        // Step 7: 设置输出shape
        context->SetOutputShape(0, xShape);

        return ge::GRAPH_SUCCESS;
    }
};

OP_INFERSHAPE_REG(RmsNorm, RmsNormInferShape);

} // namespace ops
```

### 逐元素算子

```cpp
class ElementwiseInferShape : public OpInferShape {
public:
    ge::graphStatus InferShape(gert::InferShapeContext* context) override
    {
        // 检查输入数量
        int64_t inputNum = context->GetInputNum();
        if (inputNum != 2) {
            OP_LOGE(context->GetNodeName(), 
                    "Expected 2 inputs, got %ld", 
                    inputNum);
            return ge::GRAPH_FAILED;
        }

        // 获取两个输入的shape
        auto x1Shape = context->GetInputShape(0);
        auto x2Shape = context->GetInputShape(1);
        if (x1Shape == nullptr || x2Shape == nullptr) {
            OP_LOGE(context->GetNodeName(), "GetInputShape failed");
            return ge::GRAPH_FAILED;
        }

        // 检查数据类型一致
        auto x1Desc = context->GetInputDesc(0);
        auto x2Desc = context->GetInputDesc(1);
        if (x1Desc->GetDataType() != x2Desc->GetDataType()) {
            OP_LOGE(context->GetNodeName(), 
                    "Input data types must match");
            return ge::GRAPH_FAILED;
        }

        // 广播检查（简化版）
        int32_t x1Rank = x1Shape->GetStorageShape().GetDimNum();
        int32_t x2Rank = x2Shape->GetStorageShape().GetDimNum();
        int32_t maxRank = std::max(x1Rank, x2Rank);

        // 输出shape取较大者
        if (x1Rank >= x2Rank) {
            context->SetOutputShape(0, x1Shape);
        } else {
            context->SetOutputShape(0, x2Shape);
        }

        return ge::GRAPH_SUCCESS;
    }
};
```

## 校验函数封装

```cpp
// 通用校验辅助函数
namespace {

ge::graphStatus ValidateTensorShape(
    gert::InferShapeContext* context,
    int32_t inputIdx,
    int32_t minRank,
    int32_t maxRank)
{
    auto shape = context->GetInputShape(inputIdx);
    if (shape == nullptr) {
        OP_LOGE(context->GetNodeName(), 
                "GetInputShape failed for input %d", 
                inputIdx);
        return ge::GRAPH_FAILED;
    }

    int32_t rank = shape->GetStorageShape().GetDimNum();
    if (rank < minRank || rank > maxRank) {
        OP_LOGE(context->GetNodeName(), 
                "Input %d rank %d out of range [%d, %d]",
                inputIdx, rank, minRank, maxRank);
        return ge::GRAPH_FAILED;
    }

    return ge::GRAPH_SUCCESS;
}

ge::graphStatus ValidateDataType(
    gert::InferShapeContext* context,
    int32_t inputIdx,
    const std::vector<ge::DataType>& supportedTypes)
{
    auto desc = context->GetInputDesc(inputIdx);
    if (desc == nullptr) {
        OP_LOGE(context->GetNodeName(), 
                "GetInputDesc failed for input %d", 
                inputIdx);
        return ge::GRAPH_FAILED;
    }

    ge::DataType dtype = desc->GetDataType();
    for (auto supported : supportedTypes) {
        if (dtype == supported) {
            return ge::GRAPH_SUCCESS;
        }
    }

    OP_LOGE(context->GetNodeName(), 
            "Unsupported data type %d for input %d", 
            dtype, inputIdx);
    return ge::GRAPH_FAILED;
}

} // anonymous namespace
```

## 检查清单

- [ ] 输入数量校验
- [ ] 输入shape非空检查
- [ ] 输入维度范围校验
- [ ] 数据类型校验
- [ ] 多输入一致性校验
- [ ] 特殊约束校验（如shape匹配）
- [ ] 属性有效性校验
- [ ] 输出shape正确设置
- [ ] 错误日志包含具体信息
- [ ] 注册OP_INFERSHAPE_REG
