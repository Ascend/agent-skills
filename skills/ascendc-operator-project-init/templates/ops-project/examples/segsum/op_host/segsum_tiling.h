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
 * \file segsum_tiling.h
 * \brief
 */

#ifndef OPS_BUILT_IN_OP_TILING_RUNTIME_SEGSUM_TILING_H
#define OPS_BUILT_IN_OP_TILING_RUNTIME_SEGSUM_TILING_H

#include "register/tilingdata_base.h"
#include "log/log.h"
#include "util/math_util.h"
#include "register/op_impl_registry.h"
#include "op_host/tiling_templates_registry.h"
#include "platform/platform_ascendc.h"
#include "op_common/op_host/util/platform_util.h"

namespace optiling {

constexpr uint16_t MAX_CORE_CONT = 50;

struct SegsumCompileInfo {
    uint32_t coreNum = 0;
    uint64_t ubSize = 0;
};

BEGIN_TILING_DATA_DEF(SegsumTilingData)

TILING_DATA_FIELD_DEF(int64_t, dataType);
TILING_DATA_FIELD_DEF(int64_t, needCoreNum);
TILING_DATA_FIELD_DEF(int64_t, batches);
TILING_DATA_FIELD_DEF(int64_t, tailDimSize);
TILING_DATA_FIELD_DEF(int64_t, slideSize);

TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchStart);
TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchEnd);
END_TILING_DATA_DEF;

REGISTER_TILING_DATA_CLASS(Segsum, SegsumTilingData)
} // namespace optiling
#endif