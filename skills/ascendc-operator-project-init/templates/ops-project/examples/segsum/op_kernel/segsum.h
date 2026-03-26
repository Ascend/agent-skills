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
 * \file segsum.h
 * \brief
 */

#ifndef SEGSUM
#define SEGSUM

#include <type_traits>
#include "kernel_operator.h"

#ifndef INFINITY
#define INFINITY (__builtin_inff())
#endif

namespace Segsum {
using namespace AscendC;
constexpr int32_t NO_BUFFER_NUM = 1;

constexpr float INF_FLOAT = -INFINITY;
template <typename T, int32_t MODE>
class SegsumND
{
public:
    TPipe pipe;

    __aicore__ inline SegsumND(){};
    __aicore__ inline void Init(GM_ADDR input, GM_ADDR output, GM_ADDR workspace, const SegsumTilingData* tilingData);
    __aicore__ inline void Process();

private:
    template <typename T1, typename T2>
    __aicore__ inline T1 CeilA2B(T1 a, T2 b)
    {
        if (b == 0) {
            return a;
        }
        return (a + b - 1) / b;
    };
    template <typename T1>
    __aicore__ inline T1 Min(T1 a, T1 b)
    {
        return a < b ? a : b;
    };
    __aicore__ inline int64_t getProcessedNum(int64_t rowIdx, int64_t colIdx, int64_t dataIdx, int64_t diagonal)
    {
        if (rowIdx < colIdx) {
            return -1;
        } else if (rowIdx == colIdx) {
            return dataIdx % slideSize + diagonal;
        } else {
            return slideSize;
        }
    }

    __aicore__ inline void ParseTilingData(const SegsumTilingData* tilingData);
    __aicore__ inline void ComputeBase();
    __aicore__ inline void ComputeBatches();
    __aicore__ inline void Compute(int64_t batchIdx, int64_t colIdx);
    __aicore__ inline void CopyInBatch(int64_t offset, int64_t batchesEachCopy, uint32_t calSize);
    __aicore__ inline void CopyOutBatch(int64_t offset, int64_t batchesEachCopy, int64_t calNum, uint32_t calSize);
    __aicore__ inline void processY(
        int64_t outProcessedNum, int64_t calCount, LocalTensor<float> currentRow, int64_t batchesEachCopy,
        int64_t blockNumData);
    __aicore__ inline void processCurrent(
        int64_t dataIdx, LocalTensor<float> currentRow, LocalTensor<T> xTensor, int64_t batchesEachCopy,
        int64_t blockNumData);

private:
    TBuf<QuePosition::VECCALC> lastQueue;
    TBuf<QuePosition::VECCALC> currentQueue;
    TBuf<QuePosition::VECCALC> castQueue;
    TQue<QuePosition::VECIN, NO_BUFFER_NUM> inQueue;
    TQue<QuePosition::VECOUT, NO_BUFFER_NUM> outQueue;

    GlobalTensor<T> inTensorsGM;
    GlobalTensor<T> outTensorsGM;

    int64_t blockIdx = 0;
    int64_t batchStart = 0;
    int64_t batchEnd = 0;
    int64_t needCoreNum = 0;
    int64_t slideSize = 0;

    int64_t tailDimSize = 0;
    int64_t calCount = 0;
    int64_t blockSize = 8;
};

template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::Init(
    GM_ADDR input, GM_ADDR output, GM_ADDR workspace, const SegsumTilingData* tilingData)
{
    blockIdx = GetBlockIdx();
    ParseTilingData(tilingData);
    pipe.InitBuffer(inQueue, NO_BUFFER_NUM, slideSize * sizeof(T));
    pipe.InitBuffer(outQueue, NO_BUFFER_NUM, slideSize * sizeof(T));
    pipe.InitBuffer(lastQueue, slideSize * sizeof(float));
    pipe.InitBuffer(currentQueue, slideSize * sizeof(float));
    if constexpr (std::is_same<T, bfloat16_t>::value || std::is_same<T, half>::value) {
        pipe.InitBuffer(castQueue, slideSize * sizeof(float));
    }

    inTensorsGM.SetGlobalBuffer((__gm__ T*)input);
    outTensorsGM.SetGlobalBuffer((__gm__ T*)output);
};

template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::Process()
{
    if (blockIdx >= needCoreNum) {
        return;
    }
#if !(defined(__NPU_ARCH__) && (__NPU_ARCH__ == 3003 || __NPU_ARCH__ == 3113))
    if ASCEND_IS_AIV {
#endif
        if constexpr (MODE == 0) {
            ComputeBase();
        } else {
            ComputeBatches();
        }
#if !(defined(__NPU_ARCH__) && (__NPU_ARCH__ == 3003 || __NPU_ARCH__ == 3113))
    }
#endif
}

template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::ComputeBase()
{
    LocalTensor<T> lastRow = lastQueue.Get<T>();
    LocalTensor<T> currentRow = currentQueue.Get<T>();
    for (int64_t batchIdx = batchStart; batchIdx < batchEnd; batchIdx++) {
        for (int64_t colIdx = 0; colIdx < tailDimSize; colIdx += slideSize) {
            Compute(batchIdx, colIdx);
        }
    }
}

template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::Compute(int64_t batchIdx, int64_t colIdx)
{
    LocalTensor<float> lastRow = lastQueue.Get<float>();
    LocalTensor<float> currentRow = currentQueue.Get<float>();

    Duplicate(lastRow, static_cast<float>(0), slideSize);
    for (int64_t rowIdx = 0; rowIdx < tailDimSize; rowIdx += slideSize) {
        int64_t loopCount = Min(slideSize, tailDimSize - rowIdx);
        calCount = Min(slideSize, tailDimSize - colIdx);
        int64_t blockNumData = CeilA2B(calCount, blockSize) * blockSize;

        int64_t inOffset = batchIdx * tailDimSize + rowIdx;
        CopyInBatch(inOffset, 1, calCount * sizeof(T));
        LocalTensor<T> xTensor = inQueue.DeQue<T>();
        for (int64_t dataIdx = rowIdx; dataIdx < rowIdx + loopCount; dataIdx++) {
            int64_t currentProcessedNum = getProcessedNum(rowIdx, colIdx, dataIdx, 0);

            if (currentProcessedNum >= 0) {
                Duplicate(currentRow, static_cast<float>(0), slideSize);
            }
            if (currentProcessedNum > 0) {
                if constexpr (std::is_same<T, bfloat16_t>::value) {
                    Duplicate(currentRow, ToFloat(xTensor.GetValue(dataIdx - rowIdx)), currentProcessedNum);
                } else {
                    Duplicate(currentRow, static_cast<float>(xTensor.GetValue(dataIdx - rowIdx)), currentProcessedNum);
                }
                PipeBarrier<PIPE_V>();
                Add(currentRow, currentRow, lastRow, currentProcessedNum);
                PipeBarrier<PIPE_V>();
            }

            int64_t outProcessedNum = getProcessedNum(rowIdx, colIdx, dataIdx, 1);
            processY(outProcessedNum, calCount, currentRow, 1, 0);

            int64_t outOffset = batchIdx * tailDimSize * tailDimSize + dataIdx * tailDimSize + colIdx;
            CopyOutBatch(outOffset, 1, 0, calCount * sizeof(T));

            DataCopy(lastRow, currentRow, blockNumData);
        }
        inQueue.FreeTensor(xTensor);
    }
}

template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::processY(
    int64_t outProcessedNum, int64_t calCount, LocalTensor<float> currentRow, int64_t batchesEachCopy,
    int64_t blockNumData)
{
    if constexpr (std::is_same<T, bfloat16_t>::value || std::is_same<T, half>::value) {
        LocalTensor<T> yTensor = outQueue.AllocTensor<T>();
        LocalTensor<float> castRow = castQueue.Get<float>();
        Duplicate(castRow, INF_FLOAT, calCount);
        PipeBarrier<PIPE_ALL>();
        if (outProcessedNum > 0) {
            for (int64_t i = 0; i < batchesEachCopy; i++) {
                Adds(castRow[i * blockNumData], currentRow[i * blockNumData], static_cast<float>(0), outProcessedNum);
                PipeBarrier<PIPE_ALL>();
            }
        }
        Exp(castRow, castRow, calCount);
        PipeBarrier<PIPE_ALL>();
        Cast(yTensor, castRow, RoundMode::CAST_ROUND, calCount);
        PipeBarrier<PIPE_V>();
        outQueue.EnQue(yTensor);
    } else if constexpr (std::is_same<T, float>::value) {
        LocalTensor<float> yTensor = outQueue.AllocTensor<float>();
        Duplicate(yTensor, INF_FLOAT, calCount);
        PipeBarrier<PIPE_V>();
        if (outProcessedNum > 0) {
            for (int64_t i = 0; i < batchesEachCopy; i++) {
                Adds(yTensor[i * blockNumData], currentRow[i * blockNumData], static_cast<T>(0), outProcessedNum);
                PipeBarrier<PIPE_V>();
            }
        }
        Exp(yTensor, yTensor, calCount);
        PipeBarrier<PIPE_V>();
        outQueue.EnQue(yTensor);
    }
}

template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::processCurrent(
    int64_t dataIdx, LocalTensor<float> currentRow, LocalTensor<T> xTensor, int64_t batchesEachCopy,
    int64_t blockNumData)
{
    if constexpr (std::is_same<T, bfloat16_t>::value) {
        for (int64_t i = 0; i < batchesEachCopy; i++) {
            Duplicate(currentRow[i * blockNumData], ToFloat(xTensor.GetValue(dataIdx + i * blockNumData)), dataIdx);
            PipeBarrier<PIPE_V>();
        }
    } else {
        for (int64_t i = 0; i < batchesEachCopy; i++) {
            Duplicate(
                currentRow[i * blockNumData], static_cast<float>(xTensor.GetValue(dataIdx + i * blockNumData)),
                dataIdx);
            PipeBarrier<PIPE_V>();
        }
    }
}

template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::ComputeBatches()
{
    LocalTensor<float> lastRow = lastQueue.Get<float>();
    LocalTensor<float> currentRow = currentQueue.Get<float>();
    uint32_t calSize = calCount * sizeof(T);
    int64_t blockNumData = CeilA2B(calCount, blockSize) * blockSize;
    int64_t batchNum = slideSize / blockNumData;
    int64_t totalBlockNumData = blockNumData * batchNum;
    for (int64_t batchIdx = batchStart; batchIdx < batchEnd; batchIdx += batchNum) {
        int64_t batchesEachCopy = Min(batchEnd - batchIdx, batchNum);
        int64_t inOffset = batchIdx * tailDimSize;
        CopyInBatch(inOffset, batchesEachCopy, calSize);
        LocalTensor<T> xTensor = inQueue.DeQue<T>();

        Duplicate(lastRow, static_cast<float>(0), totalBlockNumData);
        PipeBarrier<PIPE_ALL>();
        for (int64_t dataIdx = 0; dataIdx < calCount; dataIdx++) {
            Duplicate(currentRow, static_cast<float>(0), blockNumData * batchesEachCopy);
            PipeBarrier<PIPE_ALL>();
            if (dataIdx > 0) {
                processCurrent(dataIdx, currentRow, xTensor, batchesEachCopy, blockNumData);
            }
            Add(currentRow, currentRow, lastRow, totalBlockNumData);
            PipeBarrier<PIPE_V>();

            processY(dataIdx + 1, totalBlockNumData, currentRow, batchesEachCopy, blockNumData);

            int64_t outOffset = batchIdx * tailDimSize * tailDimSize + dataIdx * calCount;
            CopyOutBatch(outOffset, batchesEachCopy, calCount, calSize);

            DataCopy(lastRow, currentRow, totalBlockNumData);
            PipeBarrier<PIPE_ALL>();
        }
        inQueue.FreeTensor(xTensor);
    }
}

template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::CopyInBatch(int64_t offset, int64_t batchesEachCopy, uint32_t calSize)
{
    LocalTensor<T> xTensor = inQueue.AllocTensor<T>();
    DataCopyExtParams copyParams{static_cast<uint16_t>(batchesEachCopy), calSize, 0, 0, 0};
    DataCopyPadExtParams<T> padParams{false, 0, 0, 0};
    DataCopyPad(xTensor, inTensorsGM[offset], copyParams, padParams);
    inQueue.EnQue(xTensor);
}
template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::CopyOutBatch(
    int64_t offset, int64_t batchesEachCopy, int64_t calNum, uint32_t calSize)
{
    LocalTensor<T> yTensor = outQueue.DeQue<T>();
    DataCopyExtParams copyParams{
        static_cast<uint16_t>(batchesEachCopy), calSize, 0, static_cast<uint32_t>((calNum - 1) * calNum * sizeof(T)),
        0};
    DataCopyPad(outTensorsGM[offset], yTensor, copyParams);
    outQueue.FreeTensor(yTensor);
}

template <typename T, int32_t MODE>
__aicore__ inline void SegsumND<T, MODE>::ParseTilingData(const SegsumTilingData* tilingData)
{
    slideSize = tilingData->slideSize;
    tailDimSize = tilingData->tailDimSize;
    calCount = tailDimSize;
    needCoreNum = tilingData->needCoreNum;
    batchStart = tilingData->batchStart[blockIdx];
    batchEnd = tilingData->batchEnd[blockIdx];
    blockSize = 32 / sizeof(T);
}
} // namespace Segsum
#endif