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
 * \file example_def.cpp
 * \brief 算子定义样例 - 严格遵循设计文档
 * 
 * 本文件展示了如何根据设计文档定义算子规格。
 * 关键要点：
 * 1. 输入输出张量定义必须与设计文档一致
 * 2. 数据类型支持范围必须与设计文档一致
 * 3. 属性定义必须与设计文档一致
 */

#include "register/op_def_registry.h"

namespace ops {

class Example : public OpDef {
public:
    explicit Example(const char* name) : OpDef(name)
    {
        // ==================== 输入张量定义 ====================
        // 根据设计文档规格约束定义
        
        // 输入1: x_ref_attn_map_source
        // 设计文档规格: [B, H, x_seqlens, t_seqlens]
        this->Input("x_ref_attn_map_source")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
        
        // 输入2: ref_target_mask
        // 设计文档规格: [t_seqlens]
        this->Input("ref_target_mask")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
        
        // ==================== 输出张量定义 ====================
        // 根据设计文档规格约束定义
        
        // 输出: output
        // 设计文档规格: [B, x_seqlens]
        this->Output("output")
            .ParamType(REQUIRED)
            .DataType({ge::DT_FLOAT16, ge::DT_FLOAT, ge::DT_BF16})
            .Format({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND})
            .UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND, ge::FORMAT_ND});
        
        // ==================== 属性定义 ====================
        // 根据设计文档定义算子属性
        
        // 属性: mode
        // 设计文档: 聚合模式，可选值为 "mean" 或 "max"，默认为 "mean"
        this->Attr("mode")
            .AttrType(OPTIONAL)
            .String("mean");
        
        // ==================== 芯片配置 ====================
        // 默认支持 ascend910b 和 ascend910_93
        this->AICore().AddConfig("ascend910b");
        this->AICore().AddConfig("ascend910_93");
    }
};

// 注册算子
OP_ADD(Example);

} // namespace ops
