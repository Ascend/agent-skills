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
 * \file add_custom.cpp
 * \brief AddCustom operator kernel implementation
 */

#include "add_custom.h"

enum class AddCustomTilingKey : uint32_t
{
    TILING_KEY_CUSTOM_FLOAT16 = 0,
    TILING_KEY_CUSTOM_FLOAT32 = 1,
    TILING_KEY_CUSTOM_INT32 = 2,
};

template <uint32_t schMode>
__global__ __aicore__ void add_custom(GM_ADDR x, GM_ADDR y, GM_ADDR z, GM_ADDR workspace, GM_ADDR tiling)
{
    REGISTER_TILING_DEFAULT(AddCustomTilingData);
    GET_TILING_DATA_WITH_STRUCT(AddCustomTilingData, tilingData, tiling);
    
    if constexpr (schMode == static_cast<uint32_t>(AddCustomTilingKey::TILING_KEY_CUSTOM_FLOAT16)) {
        NsAddCustom::AddCustom<half> op; // 算子kernel实例获取
        op.Init(x, y, z, &tilingData);   // 算子kernel实例初始化
        op.Process();                    // 算子kernel实例执行
    } else if constexpr (schMode == static_cast<uint32_t>(AddCustomTilingKey::TILING_KEY_CUSTOM_FLOAT32)) {
        NsAddCustom::AddCustom<float> op; // 算子kernel实例获取
        op.Init(x, y, z, &tilingData);    // 算子kernel实例初始化
        op.Process();                     // 算子kernel实例执行
    } else if constexpr (schMode == static_cast<uint32_t>(AddCustomTilingKey::TILING_KEY_CUSTOM_INT32)) {
        NsAddCustom::AddCustom<int32_t> op; // 算子kernel实例获取
        op.Init(x, y, z, &tilingData);       // 算子kernel实例初始化
        op.Process();                        // 算子kernel实例执行
    }
}