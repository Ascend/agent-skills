# Parameter Type Mapping

## PyTorch → ACLNN Type Mapping

| PyTorch Type | ACLNN Type | ConvertType |
|-------------|-----------|-------------|
| `at::Tensor` | `aclTensor*` | `ConvertType(tensor)` |
| `at::Scalar` | `aclScalar*` | `ConvertType(scalar)` |
| `at::IntArrayRef` | `aclIntArray*` | `ConvertType(array)` |
| `at::ArrayRef<bool>` | `aclBoolArray*` | `ConvertType(array)` |
| `double/int64_t/bool` | 原始类型 | 直接传递 |
| `c10::optional<T>` | 对应 ACL 指针或 nullptr | `ConvertType(opt)` |

## Schema 与 C++ 类型对应关系

| Schema 类型 | C++ 函数签名类型 |
|------------|-----------------|
| `int` | `int64_t` |
| `float` | `double` |
| `bool` | `bool` |
| `str` | `c10::string_view` 或 `std::string` |

## Schema 语法

- `Tensor` - 张量类型
- `int`, `int[]`, `int[3]` - 整数/数组
- `float`, `float[]` - 浮点数/数组
- `bool` - 布尔值
- `str` - 字符串
- `Scalar` - 标量（可以是 int 或 float）
- `int?` / `Tensor?` - 可选参数
- `Tensor(a!)` - inplace 输出参数

---

## Common Code Patterns

### 创建输出 Tensor

```cpp
// 方式 1: 同类型同尺寸
at::Tensor out = at::empty_like(input);

// 方式 2: 使用 NPU 格式（推荐用于 ACLNN）
at::Tensor out = at_npu::native::empty_with_format(
    output_size,
    input.options(),
    at_npu::native::get_npu_format(input)
);

// 方式 3: 指定类型
at::Tensor out = at::empty(input.sizes(), input.options().dtype(at::kFloat));

// 方式 4: 指定形状
at::Tensor out = at::empty({batch, channels, height, width}, input.options());
```

### 可选参数处理

```cpp
// 带默认值的可选参数
int64_t dim_value = dim.has_value() ? dim.value() : -1;

// 空数组处理
if (stride.empty()) {
    // 使用默认值
}
```

---

## 输出 Shape 推导

### 常见 Shape 推导模式

```cpp
// 1. 与输入相同形状
c10::SmallVector<int64_t, 8> output_size = input.sizes();

// 2. 指定维度 reduce（如 sum, mean）
c10::SmallVector<int64_t, 8> output_size;
for (int64_t i = 0; i < input.dim(); ++i) {
    if (keepdim) {
        output_size.push_back(dims.contains(i) ? 1 : input.size(i));
    } else if (!dims.contains(i)) {
        output_size.push_back(input.size(i));
    }
}

// 3. Pooling 类输出尺寸计算
int64_t output_h = (input_h + 2 * padding - kernel_size) / stride + 1;

// 4. 广播后的形状
c10::SmallVector<int64_t, 8> output_size = at::infer_size(a.sizes(), b.sizes());

// 5. 矩阵乘法输出形状
// [B, M, K] x [B, K, N] -> [B, M, N]
c10::SmallVector<int64_t, 8> output_size;
for (int64_t i = 0; i < a.dim() - 2; ++i) {
    output_size.push_back(a.size(i));  // batch dims
}
output_size.push_back(a.size(-2));     // M
output_size.push_back(b.size(-1));     // N
```

### Shape 推导辅助函数

```cpp
// 示例: avg_pool3d 输出尺寸计算
c10::SmallVector<int64_t, 3> avg_pool3d_output_size(
    const at::Tensor &self,
    c10::IntArrayRef kernel_size,
    c10::IntArrayRef stride,
    c10::IntArrayRef padding,
    bool ceil_mode)
{
    int64_t d = (self.size(-3) + 2 * padding[0] - kernel_size[0]) / stride[0] + 1;
    int64_t h = (self.size(-2) + 2 * padding[1] - kernel_size[1]) / stride[1] + 1;
    int64_t w = (self.size(-1) + 2 * padding[2] - kernel_size[2]) / stride[2] + 1;

    c10::SmallVector<int64_t, 3> output_size;
    if (self.dim() == 4) {
        output_size = {self.size(0), d, h, w};
    } else {
        output_size = {self.size(0), self.size(1), d, h, w};
    }
    return output_size;
}
```

---

## 输出类型推导

### 常见类型推导模式

```cpp
// 1. 与输入相同类型
at::TensorOptions options = self.options();

// 2. 指定输出类型
at::TensorOptions options = self.options().dtype(at::kFloat);

// 3. 根据条件选择类型
at::ScalarType dtype = self.scalar_type();
if (dtype == at::kHalf) {
    dtype = at::kFloat;  // 某些算子需要提升精度
}
at::TensorOptions options = self.options().dtype(dtype);

// 4. 类型提升（promotion）
at::ScalarType result_type = at::promote_types(a.scalar_type(), b.scalar_type());
at::TensorOptions options = self.options().dtype(result_type);

// 5. 索引操作返回 int64/bool
at::TensorOptions options = self.options().dtype(at::kLong);  // argmax
at::TensorOptions options = self.options().dtype(at::kBool);  // mask
```

### 类型推导与 Tensor 创建

```cpp
// 完整示例: 结合 shape 和 type 推导创建输出 tensor
at::Tensor my_op(const at::Tensor &self, int64_t dim, bool keepdim) {
    // 1. 推导 shape
    c10::SmallVector<int64_t, 8> output_size;
    for (int64_t i = 0; i < self.dim(); ++i) {
        if (keepdim) {
            output_size.push_back(i == dim ? 1 : self.size(i));
        } else if (i != dim) {
            output_size.push_back(self.size(i));
        }
    }

    // 2. 推导 type（保持与输入一致）
    at::TensorOptions options = self.options();

    // 3. 创建输出 tensor
    at::Tensor result = at_npu::native::empty_with_format(
        output_size,
        options,
        at_npu::native::get_npu_format(self)
    );

    return result;
}
```

### 常见算子的类型推导规则

| 算子类型 | 输出类型 | 说明 |
|---------|---------|------|
| 元素运算 (add, mul) | 输入类型 | 保持不变 |
| Reduce (sum, mean) | 输入类型 | 可能需要类型提升 |
| Reduce (argmax, argmin) | int64 | 索引类型 |
| 比较 (eq, gt, lt) | bool | 布尔 mask |
| Softmax | 输入类型 | 保持不变 |
| MatMul | 类型提升 | 广播后提升 |

### 输入验证

```cpp
// 设备检查
TORCH_CHECK(self.device().type() == c10::DeviceType::PrivateUse1,
            "Input tensor must be on NPU device");

// 类型检查
TORCH_CHECK(self.scalar_type() == at::ScalarType::Half ||
            self.scalar_type() == at::ScalarType::Float,
            "Input tensor must be half or float type, got ",
            self.scalar_type());

// 维度检查
TORCH_CHECK(self.dim() == 4 || self.dim() == 5,
            "Input tensor must be 4D or 5D, got ", self.dim(), "D");

// 尺寸检查
TORCH_CHECK(kernel_size.size() == 3,
            "kernel_size must have 3 elements, got ", kernel_size.size());
```
