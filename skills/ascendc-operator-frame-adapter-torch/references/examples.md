# Complete Examples

## ACLNN Softmax 算子接入示例

**用户输入**:
```
帮我接入 aclnnSoftmax，函数签名是：
aclnnStatus aclnnSoftmaxGetWorkspaceSize(
    const aclTensor *self,
    int64_t dim,
    aclTensor *out,
    uint64_t *workspaceSize,
    aclOpExecutor **executor)
```

**生成的文件**:

### 1. `csrc/aclnn/softmax.cpp`

```cpp
#include "torch_aclnn_helper.h"

namespace ascend_kernel {

at::Tensor softmax(const at::Tensor &self, int64_t dim)
{
    // 计算有效的 dim 值
    int64_t dim_value = dim;
    if (dim_value < 0) {
        dim_value += self.dim();
    }
    TORCH_CHECK(dim_value >= 0 && dim_value < self.dim(),
                "dim must be in range [", -self.dim(), ", ", self.dim() - 1, "]");

    // 创建输出 tensor
    at::Tensor result = at_npu::native::empty_with_format(
        self.sizes(),
        self.options(),
        at_npu::native::get_npu_format(self)
    );

    // 调用 ACLNN API
    EXEC_NPU_CMD(aclnnSoftmax, self, dim_value, result);

    return result;
}

}  // namespace ascend_kernel
```

### 2. `csrc/ops.h` 添加

```cpp
at::Tensor softmax(const at::Tensor &self, int64_t dim);
```

### 3. `csrc/CMakeLists.txt` 添加

```cmake
${PROJECT_OP_SRC_BASE}/aclnn/softmax.cpp
```

### 4. `csrc/register.cpp` 添加

```cpp
m.def("softmax(Tensor self, int dim) -> Tensor");
m.impl("softmax", TORCH_FN(ascend_kernel::softmax));
```

---

## 自定义 Kernel 算子接入示例

**用户输入**:
```
我有一个自定义的 add_kernel 算子，op_kernel 代码如下：
[用户提供 kernel 代码]
```

**生成的文件**:

### 1. `csrc/ops/add/op_host/add.cpp`

```cpp
#include "torch_kernel_helper.h"
#include "aclrtlaunch_add.h"

namespace ascend_kernel {

at::Tensor add(const at::Tensor &x, const at::Tensor &y)
{
    // 创建输出 tensor
    at::Tensor z = at::empty_like(x);

    // 计算参数
    uint32_t totalLength = 1;
    for (uint32_t size : x.sizes()) {
        totalLength *= size;
    }
    uint32_t blockDim = 8;

    // 调用 kernel
    EXEC_KERNEL_CMD(add, blockDim, x, y, z, totalLength);

    return z;
}

}  // namespace ascend_kernel
```

### 2. `csrc/ops.h` 添加

```cpp
at::Tensor add(const at::Tensor &x, const at::Tensor &y);
```

### 3. `csrc/CMakeLists.txt` 添加

```cmake
# Host 代码
${PROJECT_OP_SRC_BASE}/ops/add/op_host/add.cpp

# Kernel 编译（添加到 ascendc_library）
${PROJECT_OP_SRC_BASE}/ops/add/op_kernel/kernel_add.cpp
```

### 4. `csrc/register.cpp` 添加

```cpp
m.def("add(Tensor x, Tensor y) -> Tensor");
m.impl("add", TORCH_FN(ascend_kernel::add));
```
