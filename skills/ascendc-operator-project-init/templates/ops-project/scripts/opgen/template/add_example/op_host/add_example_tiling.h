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
 * \file add_example_tiling.h
 * \brief
 */

#ifndef OPS_BUILT_IN_OP_TILING_RUNTIME_ADD_EXAMPLE_TILING_H
#define OPS_BUILT_IN_OP_TILING_RUNTIME_ADD_EXAMPLE_TILING_H

#include "register/tilingdata_base.h"

namespace optiling {

BEGIN_TILING_DATA_DEF(AddExampleTilingData)
  TILING_DATA_FIELD_DEF(int64_t, totalLength);
  TILING_DATA_FIELD_DEF(int64_t, tileNum);
  // 扩展其他tilling参数
END_TILING_DATA_DEF;

REGISTER_TILING_DATA_CLASS(AddExample, AddExampleTilingData)
} // namespace optiling
#endif