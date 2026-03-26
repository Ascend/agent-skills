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
 * \file example_tiling.h
 * \brief Tiling数据结构定义样例 - 严格遵循设计文档
 * 
 * 本文件展示了如何根据设计文档定义TilingData结构。
 * 关键要点：
 * 1. 字段必须与设计文档中的切分策略一致
 * 2. 数组字段用于核间切分
 * 3. 字节对齐要求：8字节类型优先
 */

#ifndef OPS_BUILT_IN_OP_TILING_RUNTIME_EXAMPLE_TILING_H
#define OPS_BUILT_IN_OP_TILING_RUNTIME_EXAMPLE_TILING_H

#include "register/tilingdata_base.h"
#include "log/log.h"
#include "util/math_util.h"
#include "register/op_impl_registry.h"
#include "op_host/tiling_templates_registry.h"
#include "platform/platform_ascendc.h"
#include "op_common/op_host/util/platform_util.h"

namespace optiling {

// ==================== 常量定义 ====================
// 最大核心数限制
constexpr uint16_t MAX_CORE_CONT = 50;

// 数据类型标识（根据设计文档定义）
constexpr uint64_t DATA_TYPE_FLOAT16 = 1;
constexpr uint64_t DATA_TYPE_FLOAT = 2;
constexpr uint64_t DATA_TYPE_BF16 = 3;

// 模式标识（根据设计文档定义）
constexpr uint64_t MODE_MEAN = 0;
constexpr uint64_t MODE_MAX = 1;

// ==================== CompileInfo结构 ====================
// 编译时信息，从平台获取
struct ExampleCompileInfo {
    uint32_t coreNum = 0;   // 平台核心数
    uint64_t ubSize = 0;    // 平台UB大小
};

// ==================== TilingData结构 ====================
// 运行时Tiling数据，根据设计文档定义
BEGIN_TILING_DATA_DEF(ExampleTilingData)
    // ---------- 基础信息字段 ----------
    TILING_DATA_FIELD_DEF(int64_t, dataType);       // 数据类型标识
    TILING_DATA_FIELD_DEF(int64_t, mode);           // 聚合模式
    TILING_DATA_FIELD_DEF(int64_t, needCoreNum);    // 需要的核心数
    
    // ---------- 维度信息字段（从设计文档提取）----------
    TILING_DATA_FIELD_DEF(int64_t, batchSize);      // Batch维度大小
    TILING_DATA_FIELD_DEF(int64_t, headNum);        // Head维度大小
    TILING_DATA_FIELD_DEF(int64_t, xSeqLen);        // x序列长度
    TILING_DATA_FIELD_DEF(int64_t, refSeqLen);      // 参考序列长度
    TILING_DATA_FIELD_DEF(int64_t, totalBatches);   // 总批次 (B * H)
    
    // ---------- 切分信息字段（根据设计文档切分策略）----------
    TILING_DATA_FIELD_DEF(int64_t, batchPerCore);   // 每核处理的Batch数
    TILING_DATA_FIELD_DEF(int64_t, headPerCore);    // 每核处理的Head数
    TILING_DATA_FIELD_DEF(int64_t, xSeqLenPerLoop); // 核内循环的序列长度
    TILING_DATA_FIELD_DEF(int64_t, tmpBufSize);     // 临时空间大小
    
    // ---------- 核间切分数组字段 ----------
    // 用于记录每个核心处理的Batch范围
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchStart);
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, batchEnd);
    // 用于记录每个核心处理的Head范围
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, headStart);
    TILING_DATA_FIELD_DEF_ARR(int32_t, MAX_CORE_CONT, headEnd);
END_TILING_DATA_DEF;

REGISTER_TILING_DATA_CLASS(Example, ExampleTilingData)

} // namespace optiling
#endif
