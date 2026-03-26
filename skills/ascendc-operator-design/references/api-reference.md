# Ascend C++ 类库 API 参考

本文档提供 Ascend C 常用 API 的参考信息。详细 API 文档请参阅昇腾官方文档。

## 目录

1. [基础数据结构](#基础数据结构)
2. [基础API](#基础api)
3. [高阶API](#高阶api)
4. [Utils API](#utils-api)
5. [API使用注意事项](#api使用注意事项)

---

## 基础数据结构

### GlobalTensor

表示全局内存中的张量，用于访问 GM 中的数据。

```cpp
GlobalTensor<T> gm_tensor;
gm_tensor.SetGlobalBuffer((__gm__ T*)addr, size);
```

### LocalTensor

表示本地内存中的张量，用于访问 AI Core 内部存储中的数据。

```cpp
LocalTensor<T> local_tensor(size);
```

---

## 基础API

### 标量计算API

- `ScalarGetCountOfValue` - 获取值的计数
- `ScalarCast` - 标量类型转换
- `ScalarCountLeadingZero` - 计算前导零数量

### 矢量计算API

**基础算术**：
- `Add`, `Sub`, `Mul`, `Div` - 四则运算
- `Abs`, `Sqrt`, `Exp`, `Log` - 数学函数

**逻辑计算**：
- `Not`, `And`, `Or` - 逻辑运算
- `Compare` - 比较运算

**复合计算**：
- `Axpy` - Y = A*X + Y
- `FusedMulAdd` - 融合乘加
- `AddRelu` - 加法+ReLU融合

**归约计算**：
- `WholeReduceSum` - 全局求和
- `BlockReduceMax` - 块内最大值
- `PairReduceSum` - 配对求和

**类型转换**：
- `Cast` - 数据类型转换

### 矩阵计算API

- `Mmad` - 矩阵乘累加
- `MmadWithSparse` - 稀疏矩阵乘
- `SetHF32Mode` - HF32 模式设置

### 数据搬运API

- `DataCopy` - 基础数据搬运
- `DataCopyPad` - 带填充的数据搬运
- `LoadGM2Local` - 从 GM 加载到 Local Memory
- `StoreLocal2GM` - 从 Local Memory 存储到 GM

---

## 高阶API

高阶 API 实现常用的计算算法，通常调用多种基础 API 实现，提高开发效率并保证跨硬件版本的兼容性。

- `Matmul` - 矩阵乘法
- `Softmax` - Softmax 计算
- `LayerNorm` - 层归一化
- 更多高阶 API 请参考官方文档

---

## Utils API

### C++ 标准库支持

- 容器、算法、类型特性等

### 平台信息获取

- `GetDeviceInfo` - 获取设备信息
- `GetCoreNum` - 获取核心数量

### 运行时编译

- `RuntimeCompile` - 运行时编译支持

### 日志输出

- `LogInfo` - 信息日志
- `LogError` - 错误日志

---

## API 使用注意事项

1. **数据类型支持**：不同 API 支持的数据类型可能不同，使用前请查阅文档
2. **参数顺序**：严格按照 API 定义的参数顺序传递参数
3. **内存对齐**：确保输入输出数据按硬件要求对齐（通常为 32 字节）
4. **性能优化**：优先使用高阶 API 和融合算子 API，减少内核启动次数
5. **错误处理**：检查 API 返回值，及时处理错误情况
6. **API 真实性验证**：不是标准 Ascend C API，请勿在实际实现中使用

---

## 常用 API 示例

### 矢量计算示例

```cpp
// 执行 a + b -> c
LocalTensor<float> a(1024);
LocalTensor<float> b(1024);
LocalTensor<float> c(1024);
Add(c, a, b, 1024);

// 执行 a * b + c -> d
LocalTensor<float> d(1024);
FusedMulAdd(d, a, b, c, 1024);
```

### 归约计算示例

```cpp
// 对张量进行求和归约
LocalTensor<float> input(1024);
LocalTensor<float> sum_result(1);
ReduceSum(sum_result, input, {0}); // 对第 0 维求和

// 对张量进行最大值归约
LocalTensor<float> max_result(1);
ReduceMax(max_result, input, {0}); // 对第 0 维求最大值
```

### 数据搬运示例

```cpp
// 从 GM 加载数据到 Local Memory
GlobalTensor<float> gm_input(1024);
LocalTensor<float> local_input(1024);
DataCopy(local_input, gm_input, 1024);

// 从 Local Memory 存储数据到 GM
GlobalTensor<float> gm_output(1024);
LocalTensor<float> local_output(1024);
DataCopy(gm_output, local_output, 1024);

// 使用 DataCopy 的 stride 参数实现高效转置
// 实现形状 [H, W] → [W, H] 的转置
LocalTensor<float> input(H, W);
LocalTensor<float> output(W, H);
DataCopyParams params;
params.blockCount = H * W;  // 总元素数
params.blockLen = sizeof(float);  // 每个元素的字节数
params.srcStride = W * sizeof(float);  // 源数据步长（跨行）
params.dstStride = H * sizeof(float);  // 目标数据步长（跨列）
DataCopy(output, input, params);
```

### 矩阵计算示例

```cpp
// 执行矩阵乘法：C = A * B
LocalTensor<float> A(baseM, baseK);
LocalTensor<float> B(baseK, baseN);
LocalTensor<float> C(baseM, baseN);
Mmad(C, A, B, baseM, baseN, baseK, 1.0f, 0.0f);
```
