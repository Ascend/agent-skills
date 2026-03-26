# 算子定义文件(def)模板指南

## 文件结构

```cpp
/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software...
 */

/*!
 * \file {op_name}_def.cpp
 * \brief {OpName} Operator Definition
 */

#include "register/op_def_registry.h"

namespace ops {

class {OpName} : public OpDef {
public:
    explicit {OpName}(const char* name) : OpDef(name)
    {
        // 输入张量定义
        // 输出张量定义
        // 属性定义
        // 芯片配置
    }
};

OP_ADD({OpName});
} // namespace ops
```

## 输入张量定义

### 必需输入

```cpp
this->Input("x")
    .ParamType(REQUIRED)
    .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
    .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
    .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
```

### 可选输入

```cpp
this->OptionalInput("beta")
    .ParamType(OPTIONAL)
    .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
    .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
    .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
```

### 多输入定义

```cpp
// 输入1
this->Input("x1")
    .ParamType(REQUIRED)
    .DataType({ge::DT_FLOAT16, ge::DT_FLOAT})
    .Format({ge::FORMAT_ND, ge::FORMAT_ND})
    .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND});

// 输入2
this->Input("x2")
    .ParamType(REQUIRED)
    .DataType({ge::DT_FLOAT16, ge::DT_FLOAT})
    .Format({ge::FORMAT_ND, ge::FORMAT_ND})
    .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND});
```

## 输出张量定义

```cpp
this->Output("y")
    .ParamType(REQUIRED)
    .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
    .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
    .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
```

## 属性定义

### 浮点属性

```cpp
this->Attr("epsilon")
    .AttrType(ge::AttrType::FLOAT)
    .DefaultValue(1e-6f);
```

### 整型属性

```cpp
this->Attr("axis")
    .AttrType(ge::attr::INT)
    .DefaultValue(-1);
```

### 布尔属性

```cpp
this->Attr("keep_dims")
    .AttrType(ge::attr::BOOL)
    .DefaultValue(false);
```

### 列表属性

```cpp
this->Attr("axes")
    .AttrType(ge::attr::LIST_INT)
    .DefaultValue({});
```

## 芯片配置

### 标准配置（推荐）

```cpp
// 默认只配置910b和910_93
this->AICore().AddConfig("ascend910b");
this->AICore().AddConfig("ascend910_93");
```

### 多平台配置

```cpp
// 主配置
this->AICore().AddConfig("ascend910b");
this->AICore().AddConfig("ascend910_93");

// 其他平台配置（如需要）
OpAICoreConfig config_other = GetOtherPlatformConfig();
this->AICore().AddConfig("other_platform", config_other);
```

### 平台特定配置

```cpp
private:
    OpAICoreConfig GetOtherPlatformConfig() const
    {
        OpAICoreConfig config;
        config.DynamicCompileStaticFlag(true)
            .DynamicFormatFlag(true)
            .DynamicRankSupportFlag(true)
            .DynamicShapeSupportFlag(true)
            .NeedCheckSupportFlag(false)
            .PrecisionReduceFlag(true);
        
        // 配置输入输出
        config.Input("x")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND});
        
        config.Output("y")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND});
        
        return config;
    }
```

## 数据类型映射

### 常用数据类型组合

| 算子类型 | 支持的数据类型 |
|---------|---------------|
| 归一化类 | `ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16` |
| 归约类 | `ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16` |
| 逐元素类 | `ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16, ge::DT_INT32` |
| 矩阵运算 | `ge::DT_FLOAT16, ge::DT_BF16` |

### 格式选择

| 场景 | 推荐格式 |
|------|---------|
| 通用场景 | `ge::FORMAT_ND` |
| 图像处理 | `ge::FORMAT_NCHW, ge::FORMAT_NHWC` |
| 矩阵运算 | `ge::FORMAT_ND, ge::FORMAT_FRACTAL_NZ` |

## 完整模板示例

### 单输入单输出算子

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
 * \file relu_def.cpp
 * \brief ReLU Operator Definition
 */

#include "register/op_def_registry.h"

namespace ops {

class Relu : public OpDef {
public:
    explicit Relu(const char* name) : OpDef(name)
    {
        this->Input("x")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
        
        this->Output("y")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});

        this->AICore().AddConfig("ascend910b");
        this->AICore().AddConfig("ascend910_93");
    }
};

OP_ADD(Relu);
} // namespace ops
```

### 多输入带属性算子

```cpp
/**
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This program is free software...
 */

/*!
 * \file rmsnorm_def.cpp
 * \brief RMSNorm Operator Definition
 */

#include "register/op_def_registry.h"

namespace ops {

class RmsNorm : public OpDef {
public:
    explicit RmsNorm(const char* name) : OpDef(name)
    {
        this->Input("x")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
        
        this->Input("gamma")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
        
        this->OptionalInput("beta")
            .ParamType(OPTIONAL)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
        
        this->Output("y")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});

        this->Attr("epsilon")
            .AttrType(ge::AttrType::FLOAT)
            .DefaultValue(1e-6f);

        this->AICore().AddConfig("ascend910b");
        this->AICore().AddConfig("ascend910_93");
    }
};

OP_ADD(RmsNorm);
} // namespace ops
```

## 常见错误

### 错误1: 数据类型列表长度不匹配

```cpp
// 错误：DataType和Format列表长度不一致
.DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
.Format({ge::FORMAT_ND, ge::FORMAT_ND})  // 缺少一个

// 正确：长度一致
.DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
.Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
```

### 错误2: 忘记注册算子

```cpp
class MyOp : public OpDef {
    // ...
};

// 错误：忘记添加OP_ADD
// OP_ADD(MyOp);  // 必须添加

// 正确
OP_ADD(MyOp);
```

### 错误3: 可选输入使用错误方法

```cpp
// 错误：可选输入使用Input
this->Input("beta")  // 应该用OptionalInput

// 正确
this->OptionalInput("beta")
```

## 检查清单

- [ ] 输入张量定义完整（名称、类型、格式）
- [ ] 输出张量定义完整
- [ ] DataType和Format列表长度一致
- [ ] 可选输入使用OptionalInput
- [ ] 属性定义包含默认值
- [ ] 芯片配置正确（默认910b和910_93）
- [ ] 添加了OP_ADD注册
- [ ] 文件头注释完整
