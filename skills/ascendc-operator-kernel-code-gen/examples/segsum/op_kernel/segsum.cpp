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
 * \file segsum.cpp
 * \brief
 */

#include "segsum.h"

using namespace Segsum;

extern "C" __global__ __aicore__ void segsum(GM_ADDR x, GM_ADDR y, GM_ADDR workspace, GM_ADDR tiling)
{
    GET_TILING_DATA(tilingData, tiling);
    const SegsumTilingData* __restrict tiling_data = &tilingData;

    GM_ADDR userWS = GetUserWorkspace(workspace);
    if (userWS == nullptr) {
        return;
    }
    if constexpr (std::is_same_v<DTYPE_X, half>) {
        if (TILING_KEY_IS(1000)) {
            SegsumND<half, 0> op;
            op.Init(x, y, userWS, &tilingData);
            op.Process();
        } else if (TILING_KEY_IS(1001)) {
            SegsumND<half, 1> op;
            op.Init(x, y, userWS, &tilingData);
            op.Process();
        } else {
            return;
        }
    } else if constexpr (std::is_same_v<DTYPE_X, float>) {
        if (TILING_KEY_IS(1000)) {
            SegsumND<float, 0> op;
            op.Init(x, y, userWS, &tilingData);
            op.Process();
        } else if (TILING_KEY_IS(1001)) {
            SegsumND<float, 1> op;
            op.Init(x, y, userWS, &tilingData);
            op.Process();
        } else {
            return;
        }
#if !(defined(__NPU_ARCH__) && (__NPU_ARCH__ == 3003 || __NPU_ARCH__ == 3113))
    } else if constexpr (std::is_same_v<DTYPE_X, bfloat16_t>) {
        if (TILING_KEY_IS(1000)) {
            SegsumND<bfloat16_t, 0> op;
            op.Init(x, y, userWS, &tilingData);
            op.Process();
        } else if (TILING_KEY_IS(1001)) {
            SegsumND<bfloat16_t, 1> op;
            op.Init(x, y, userWS, &tilingData);
            op.Process();
        } else {
            return;
        }
#endif
    }
}