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
 * \file test_segsum.cpp
 * \brief
 */

#include <array>
#include <vector>
#include <iostream>
#include <string>
#include <cstdint>
#include "gtest/gtest.h"
#include "tikicpulib.h"
#include "../../../op_host/segsum_tiling.h"

extern "C" __global__ __aicore__ void segsum(GM_ADDR x, GM_ADDR y, GM_ADDR workspace, GM_ADDR tiling);

class segsum_test : public testing::Test
{
protected:
    static void SetUpTestCase()
    {
        std::cout << "segsum_test SetUp\n" << std::endl;
    }
    static void TearDownTestCase()
    {
        std::cout << "segsum_test TearDown\n" << std::endl;
    }
};

TEST_F(segsum_test, test_case_float_0)
{
    size_t inputByteSize = 2 * 4 * sizeof(float);
    size_t outputByteSize = 2 * 4 * 4 * sizeof(float);
    size_t tiling_data_size = sizeof(SegsumTilingData);
    size_t workspaceSize = 32 * 1024 * 1024;
    uint32_t numBlocks = 2;

    uint8_t* x = (uint8_t*)AscendC::GmAlloc(inputByteSize);
    uint8_t* y = (uint8_t*)AscendC::GmAlloc(outputByteSize);

    uint8_t* workspace = (uint8_t*)AscendC::GmAlloc(workspaceSize);
    uint8_t* tiling = (uint8_t*)AscendC::GmAlloc(tiling_data_size);

    SegsumTilingData* tilingDatafromBin = reinterpret_cast<SegsumTilingData*>(tiling);
    tilingDatafromBin->dataType = 2;
    tilingDatafromBin->needCoreNum = 2;
    tilingDatafromBin->batches = 2;
    tilingDatafromBin->tailDimSize = 2;
    tilingDatafromBin->slideSize = 8;

    tilingDatafromBin->batchStart[0] = 0;
    tilingDatafromBin->batchStart[1] = 1;
    tilingDatafromBin->batchEnd[0] = 1;
    tilingDatafromBin->batchEnd[1] = 2;

    ICPU_SET_TILING_KEY(1000);
    ICPU_RUN_KF(segsum, numBlocks, x, y, workspace, (uint8_t*)(tilingDatafromBin));

    AscendC::GmFree((void*)(x));
    AscendC::GmFree((void*)(y));
    AscendC::GmFree((void*)workspace);
    AscendC::GmFree((void*)tiling);
}

TEST_F(segsum_test, test_case_float_1)
{
    size_t inputByteSize = 2 * 2 * 3 * sizeof(float);
    size_t outputByteSize = 2 * 2 * 3 * 3 * sizeof(float);
    size_t tiling_data_size = sizeof(SegsumTilingData);
    size_t workspaceSize = 32 * 1024 * 1024;
    uint32_t numBlocks = 1;

    uint8_t* x = (uint8_t*)AscendC::GmAlloc(inputByteSize);
    uint8_t* y = (uint8_t*)AscendC::GmAlloc(outputByteSize);

    uint8_t* workspace = (uint8_t*)AscendC::GmAlloc(workspaceSize);
    uint8_t* tiling = (uint8_t*)AscendC::GmAlloc(tiling_data_size);

    SegsumTilingData* tilingDatafromBin = reinterpret_cast<SegsumTilingData*>(tiling);
    tilingDatafromBin->dataType = 2;
    tilingDatafromBin->needCoreNum = 1;
    tilingDatafromBin->batches = 4;
    tilingDatafromBin->tailDimSize = 3;
    tilingDatafromBin->slideSize = 32;

    tilingDatafromBin->batchStart[0] = 0;
    tilingDatafromBin->batchEnd[1] = 4;

    ICPU_SET_TILING_KEY(1001);
    ICPU_RUN_KF(segsum, numBlocks, x, y, workspace, (uint8_t*)(tilingDatafromBin));

    AscendC::GmFree((void*)(x));
    AscendC::GmFree((void*)(y));
    AscendC::GmFree((void*)workspace);
    AscendC::GmFree((void*)tiling);
}

TEST_F(segsum_test, test_case_float16_0)
{
    size_t inputByteSize = 8 * sizeof(half);
    size_t outputByteSize = 8 * 8 * sizeof(half);
    size_t tiling_data_size = sizeof(SegsumTilingData);
    size_t workspaceSize = 32 * 1024 * 1024;
    uint32_t numBlocks = 1;

    uint8_t* x = (uint8_t*)AscendC::GmAlloc(inputByteSize);
    uint8_t* y = (uint8_t*)AscendC::GmAlloc(outputByteSize);

    uint8_t* workspace = (uint8_t*)AscendC::GmAlloc(workspaceSize);
    uint8_t* tiling = (uint8_t*)AscendC::GmAlloc(tiling_data_size);

    SegsumTilingData* tilingDatafromBin = reinterpret_cast<SegsumTilingData*>(tiling);
    tilingDatafromBin->dataType = 1;
    tilingDatafromBin->needCoreNum = 1;
    tilingDatafromBin->batches = 1;
    tilingDatafromBin->tailDimSize = 2;
    tilingDatafromBin->slideSize = 8;

    tilingDatafromBin->batchStart[0] = 0;
    tilingDatafromBin->batchEnd[1] = 1;

    ICPU_SET_TILING_KEY(1000);
    ICPU_RUN_KF(segsum, numBlocks, x, y, workspace, (uint8_t*)(tilingDatafromBin));

    AscendC::GmFree((void*)(x));
    AscendC::GmFree((void*)(y));
    AscendC::GmFree((void*)workspace);
    AscendC::GmFree((void*)tiling);
}