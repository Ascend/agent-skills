# AscendC 数据搬运 API 参考

## 基础数据搬运 (DataCopy)

### 连续搬运

```cpp
// GM -> UB (VECIN)
AscendC::DataCopy(dstLocal, srcGlobal, count);

// UB -> UB
AscendC::DataCopy(dstLocal, srcLocal, count);

// UB (VECOUT) -> GM
AscendC::DataCopy(dstGlobal, srcLocal, count);
```

**参数**：
- `count`: 元素个数，`count * sizeof(T)` 需32字节对齐

### 非连续搬运 (DataCopyParams)

```cpp
AscendC::DataCopyParams params;
params.blockCount = 1;   // 连续数据块个数 [1, 4095]
params.blockLen = 8;     // 每块长度，单位DataBlock(32B) [1, 65535]
params.srcGap = 0;       // 源相邻块间隔，单位DataBlock(32B)
params.dstGap = 0;       // 目的相邻块间隔，单位DataBlock(32B)

AscendC::DataCopy(dstLocal, srcGlobal, params);
```

**示意图**：
```
blockCount=2, blockLen=8, srcGap=0, dstGap=1
源: [====8块====][====8块====]
目的: [====8块====][gap][====8块====]
```

## 切片数据搬运 (SliceInfo)

```cpp
AscendC::SliceInfo srcSliceInfo[] = {{16, 70, 7, 3, 87}, {0, 2, 1, 1, 3}};
AscendC::SliceInfo dstSliceInfo[] = {{0, 47, 0, 3, 48}, {0, 1, 0, 1, 2}};
uint32_t dimValue = 2;

AscendC::DataCopy(dstLocal, srcGlobal, dstSliceInfo, srcSliceInfo, dimValue);
```

**SliceInfo 结构**：
| 参数 | 含义 |
|------|------|
| startIndex | 切片起始位置 |
| endIndex | 切片终止位置 |
| stride | 相邻切片间隔（元素个数） |
| burstLen | 每片数据长度，单位DataBlock(32B)，dimValue>1时必须为1 |
| shapeValue | 当前维度原始长度 |

## 非对齐搬运 (DataCopyPad)

```cpp
// GM -> UB，支持非32字节对齐
AscendC::DataCopyExtParams copyParams{1, 20 * sizeof(half), 0, 0, 0};
AscendC::DataCopyPadExtParams<half> padParams{true, 0, 2, 0};  // isPad, leftPad, rightPad, padValue
AscendC::DataCopyPad(dstLocal, srcGlobal, copyParams, padParams);

// UB -> GM
AscendC::DataCopyPad(dstGlobal, srcLocal, copyParams);
```

**DataCopyExtParams**：
| 参数 | 含义 | 单位 |
|------|------|------|
| blockCount | 连续数据块个数 | - |
| blockLen | 每块长度 | **字节** |
| srcStride | 源相邻块间隔 | GM:字节, UB:DataBlock |
| dstStride | 目的相邻块间隔 | GM:字节, UB:DataBlock |

**DataCopyPadExtParams**：
| 参数 | 含义 |
|------|------|
| isPad | 是否填充自定义值 |
| leftPadding | 左侧填充元素个数（≤32字节） |
| rightPadding | 右侧填充元素个数（≤32字节） |
| padValue | 填充值 |

## UB内部拷贝 (Copy)

```cpp
// VECIN/VECCALC/VECOUT 之间的拷贝
AscendC::Copy(dstLocal, srcLocal, mask, repeatTime, {dstStride, srcStride, dstRepStride, srcRepStride});
```

**CopyRepeatParams**：
| 参数 | 含义 |
|------|------|
| dstStride/srcStride | 同一迭代内DataBlock步长 |
| dstRepeatSize/srcRepeatSize | 相邻迭代间步长 |

```cpp
// 示例：连续拷贝512个int16_t
uint64_t mask = 128;
AscendC::Copy(dstLocal, srcLocal, mask, 4, {1, 1, 8, 8});
```

## 增强数据搬运 (DataCopyEnhancedParams)

```cpp
AscendC::DataCopyParams intriParams;
AscendC::DataCopyEnhancedParams enhancedParams;
enhancedParams.blockMode = BlockMode::BLOCK_MODE_MATRIX;  // 或 BLOCK_MODE_VECTOR
AscendC::DataCopy(dstLocal, srcLocal, intriParams, enhancedParams);
```

**blockMode 模式**：
| 模式 | 传输单位 | 适用通路 |
|------|----------|----------|
| BLOCK_MODE_MATRIX | 16×16 cube | CO1 -> CO2 |
| BLOCK_MODE_VECTOR | 1×16 cube | CO1 -> CO2 |
| BLOCK_MODE_NORMAL | 32B | 通用通路 |

**量化模式 (deqScale)**：
| 模式 | 说明 |
|------|------|
| DEQ | int32 -> half，使用deqValue |
| DEQ8 | int32 -> int8/uint8 |
| DEQ16 | int32 -> half/int16 |
| VDEQ/VDEQ8/VDEQ16 | 使用deqTensorAddr参数向量 |

## 数据通路速查

| 通路 | 源 | 目的 | 说明 |
|------|----|----|------|
| GM -> UB | GlobalTensor | LocalTensor(VECIN) | CopyIn阶段 |
| UB -> GM | LocalTensor(VECOUT) | GlobalTensor | CopyOut阶段 |
| UB -> UB | LocalTensor | LocalTensor | Compute阶段 |
| UB -> L1 | LocalTensor | LocalTensor(A1/B1/TSCM) | 大数据缓存 |
| CO1 -> CO2 | LocalTensor(CO1) | LocalTensor(CO2) | 矩阵计算结果 |

## 地址对齐要求

| 位置 | 对齐要求 |
|------|----------|
| UB (VECIN/VECOUT) | 32字节 |
| L1 Buffer | 32字节 |
| GM | 按数据类型大小对齐 |
| C2 | 64字节 |
| C2PIPE2GM | 128字节 |

## 常用代码模式

### CopyIn (GM -> UB)

```cpp
__aicore__ inline void CopyIn()
{
    LocalTensor<half> srcLocal = inQueueSrc.AllocTensor<half>();
    DataCopy(srcLocal, srcGlobal, tileLength);
    inQueueSrc.EnQue(srcLocal);
}
```

### CopyOut (UB -> GM)

```cpp
__aicore__ inline void CopyOut()
{
    LocalTensor<half> dstLocal = outQueueDst.DeQue<half>();
    DataCopy(dstGlobal, dstLocal, tileLength);
    outQueueDst.FreeTensor(dstLocal);
}
```

### 非连续搬运示例

```cpp
// 搬运2个数据块，每块256字节，源间隔0，目的间隔32字节
DataCopyParams params;
params.blockCount = 2;
params.blockLen = 8;     // 8 * 32B = 256B
params.srcGap = 0;
params.dstGap = 1;       // 1 * 32B = 32B间隔

DataCopy(dstLocal, srcGlobal, params);
```
