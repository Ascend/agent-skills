/**
 * This program is free software, you can redistribute it and/or modify it.
 * Copyright (c) 2025 Huawei Technologies Co., Ltd.
 * This file is a part of the CANN Open Software.
 * Licensed under CANN Open Software License Agreement Version 2.0 (the "License").
 * Please refer to the License for details. You may not use this file except in compliance with the License.
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE. See LICENSE in the root of
 * the software repository for the full text of the License.
 */

/*!
 * \file tiling_util.cpp
 * \brief
 */

#include "op_host/tiling_util.h"
#include "platform/platform_ascendc.h"
#include "platform/soc_spec.h"

namespace Ops {
namespace Math {
namespace OpTiling {
static const gert::Shape g_vec_1_shape = {1};

static bool IsRegbaseSocVersion(NpuArch npuArch)
{
    const static std::set<NpuArch> regbaseArch = {
        NpuArch::DAV_3510};

    return regbaseArch.find(npuArch) != regbaseArch.end();
}

bool IsRegbaseSocVersion(const gert::TilingParseContext* context)
{
    auto ascendcPlatform = platform_ascendc::PlatformAscendC(context->GetPlatformInfo());
    auto arch = ascendcPlatform.GetCurNpuArch();
    return IsRegbaseSocVersion(arch);
}

bool IsRegbaseSocVersion(const gert::TilingContext* context)
{
    auto ascendcPlatform = platform_ascendc::PlatformAscendC(context->GetPlatformInfo());
    auto arch = ascendcPlatform.GetCurNpuArch();
    return IsRegbaseSocVersion(arch);
}

const gert::Shape &EnsureNotScalar(const gert::Shape &inShape) {
  if (inShape.IsScalar()) {
    return g_vec_1_shape;
  }
  return inShape;
}
} // namespace OpTiling
} // namespace Math
} // namespace Ops
