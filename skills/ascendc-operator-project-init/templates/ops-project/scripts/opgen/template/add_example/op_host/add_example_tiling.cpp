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
 * \file add_example_tiling.cpp
 * \brief
 */

#include "log/log.h"
#include "util/math_util.h"
#include "op_host/tiling_util.h"
#include "op_host/tiling_templates_registry.h"

#include "add_example_tiling.h"

namespace optiling {

struct AddExampleCompileInfo {};

constexpr int32_t TILING_KEY_EXAMPLE_FLOAT = 0;
constexpr int32_t TILING_KEY_EXAMPLE_INT32 = 1,

// tiling 分发入口
static ge::graphStatus AddExampleTilingFunc(gert::TilingContext* context)
{
}

static ge::graphStatus TilingParseForAddExample([[maybe_unused]] gert::TilingParseContext* context)
{   
    // AscendC 算子可以直接返回SUCCESS提升性能，硬件信息可在运行时获取
    return ge::GRAPH_SUCCESS;
}

// tiling注册入口.
IMPL_OP_OPTILING(AddExample).Tiling(AddExampleTilingFunc).TilingParse<AddExampleCompileInfo>(TilingParseForAddExample);
} // namespace optiling
