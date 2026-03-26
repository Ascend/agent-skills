---
name: ascendc-operator-frame-adapter-torch
description: 将华为昇腾 ACLNN/AscendC 算子接入 PyTorch。TRIGGER when: (1) 关键词：ACLNN、AscendC、CANN、torch_npu、NPU、昇腾、Ascend、华为 AI 处理器；(2) 任务：算子适配/接入/封装/绑定/注册到 PyTorch、为 ACLNN/AscendC kernel 创建 torch 接口、将 CANN 算子暴露给 Python；(3) 代码特征：aclnnXxxGetWorkspaceSize、EXEC_NPU_CMD、op_kernel/op_host 目录、TORCH_LIBRARY_IMPL。
---

# Ascend 算子 PyTorch 框架接入

将华为昇腾 ACLNN 接口或自定义 AscendC 算子接入 PyTorch 框架。

**模板工程**: `templates/ascend-kernel/`

## 支持的算子类型

| 类型 | 说明 | 需要用户提供 |
|------|------|-------------|
| **ACLNN API** | CANN 预构建接口 | ACLNN 函数签名或文档 |
| **自定义 Kernel** | 用户编写的 AscendC kernel | op_kernel/op_host 代码 |

## 输入格式

- ACLNN 接口文档 URL
- ACLNN 函数签名（如 `aclnnStatus aclnnXxxGetWorkspaceSize(...)`）
- 自定义 kernel/tiling 代码
- 自然语言描述（如"我需要一个 NPU 上的 softmax 算子"）
- PyTorch 函数名（如"帮我接入 torch.nn.functional.softmax"）

---

## 工作流程

### 步骤 1: 分析用户需求并规划 torch 接口

解析用户输入，**必须向用户展示并确认完整规划**：

```
=== 算子信息 ===
算子名称: <op_name>
算子类型: aclnn / custom_kernel

输入参数:
  - self: Tensor (ACL_TENSOR) - 输入张量
  - dim: IntArrayRef (ACL_INTARRAY) - 计算维度

输出参数:
  - out: Tensor (ACL_TENSOR) - 输出张量

=== Torch 接口 ===
函数名: <op_name>
schema: <op_name>(Tensor self, int dim=-1) -> Tensor
C++ 签名: at::Tensor <op_name>(const at::Tensor &self, int64_t dim = -1)

请确认以上算子信息和接口定义是否正确？
```

**规划要点**：
1. **算子名称** (op_name) - snake_case 格式
2. **算子类型** (aclnn / custom_kernel)
3. **ACL 参数列表** - 完整的输入/输出参数及类型映射
4. **schema 定义** - torch 接口函数签名（参数类型、默认值、返回值）
5. **C++ 函数签名** - 对应的实现函数参数类型
6. **输出类型** - 根据规则确定输出 dtype

### 步骤 2: 检查并初始化模板工程

检查当前目录下是否存在 `ascend-kernel/` 或 `csrc/` 目录。

**如果不存在**，拷贝模板：
```bash
cp -r <skill_dir>/templates/ascend-kernel ./ascend-kernel
```

确认目录结构：
```
./ascend-kernel/
├── CMakeLists.txt
├── build.sh
├── cmake/
├── csrc/
│   ├── CMakeLists.txt
│   ├── ops.h
│   ├── register.cpp
│   ├── aclnn/
│   ├── ops/
│   └── utils/
└── python/
```

### 步骤 3: 生成适配代码文件

**重要**: 生成代码前，先阅读模板工程中对应模板文件。

#### 3.1 ACLNN 算子

**参考**: `templates/ascend-kernel/csrc/aclnn/avg_pool3d.cpp`

生成文件: `csrc/aclnn/<op_name>.cpp`

```cpp
#include "torch_aclnn_helper.h"

namespace ascend_kernel {

// 1. 如果需要计算输出尺寸，添加辅助函数
c10::SmallVector<int64_t, N> <op_name>_output_size(const at::Tensor &self, ...)
{
    TORCH_CHECK(条件检查, "错误信息");
    return {dim1, dim2, ...};
}

// 2. 主函数
at::Tensor <op_name>(<pytorch_params>)
{
    auto output_size = <op_name>_output_size(...);
    at::Tensor result = at_npu::native::empty_with_format(
        output_size, self.options(), at_npu::native::get_npu_format(self)
    );
    EXEC_NPU_CMD(aclnn<OpName>, <params...>, result);
    return result;
}

}  // namespace ascend_kernel
```

**关键点**：
- 使用 `at_npu::native::empty_with_format` 创建输出 tensor
- `EXEC_NPU_CMD` 的第一个参数是 ACLNN API 名称（不含 GetWorkspaceSize 后缀），**其余参数必须传左值或左值引用，禁止传右值**（如临时对象、字面量）
- 参数顺序必须与 ACLNN API 签名一致
- **输出 shape 推导**: 需要根据输入参数计算输出 tensor 的形状

**输出类型推导规则**（按优先级）：
1. 用户明确指定 → 使用指定类型
2. 根据算子语义确定 → 如 argmax 返回 int64，比较类返回 bool
3. 无法确定 → 在 torch 接口中添加 `dtype` 参数，默认值为用户指定或与输入相同

```cpp
// 无法确定类型时，添加 dtype 参数
at::Tensor <op_name>(const at::Tensor &self, ..., c10::optional<at::ScalarType> dtype = c10::nullopt)
{
    at::ScalarType out_dtype = dtype.value_or(self.scalar_type());
    at::Tensor result = at_npu::native::empty_with_format(
        output_size, self.options().dtype(out_dtype), at_npu::native::get_npu_format(self)
    );
    // ...
}
```

**Shape 和类型推导详见**: [type-mapping.md](references/type-mapping.md)

#### 3.2 自定义 Kernel 算子

**参考**: `templates/ascend-kernel/csrc/ops/helloworld/op_host/helloworld.cpp`

生成文件: `csrc/ops/<op_name>/op_host/<op_name>.cpp`

```cpp
#include "torch_kernel_helper.h"
#include "aclrtlaunch_<op_name>.h"

namespace ascend_kernel {

at::Tensor <op_name>(const at::Tensor &x, ...)
{
    at::Tensor z = at::empty_like(x);
    uint32_t totalLength = 1;
    for (uint32_t size : x.sizes()) {
        totalLength *= size;
    }
    uint32_t blockDim = 8;
    EXEC_KERNEL_CMD(<op_name>, blockDim, x, ..., z, totalLength);
    return z;
}

}  // namespace ascend_kernel
```

**注意**: op_kernel 代码由用户提供，不自动生成。

### 步骤 4: 注册算子接口

#### 4.1 更新函数声明
在 `csrc/ops.h` 中添加函数声明：

```cpp
// <op_name>
at::Tensor <op_name>(<pytorch_params>);
```

#### 4.2 更新 `csrc/register.cpp`

```cpp
// 在 TORCH_LIBRARY_FRAGMENT(npu, m) 中添加
m.def("<op_name>(<schema>) -> <return_type>");
// schema 示例: m.def("my_op(Tensor self, int dim=-1) -> Tensor");

// 在 TORCH_LIBRARY_IMPL(npu, PrivateUse1, m) 中添加
m.impl("<op_name>", TORCH_FN(ascend_kernel::<op_name>));
```

### 步骤 5: 更新构建配置

更新 `csrc/CMakeLists.txt`

**ACLNN 算子**：在 `FILE(GLOB OP_SRCS ...)` 中添加：
```cmake
${PROJECT_OP_SRC_BASE}/aclnn/<op_name>.cpp
```

**自定义 Kernel 算子**：
```cmake
# Host 代码
${PROJECT_OP_SRC_BASE}/ops/<op_name>/op_host/<op_name>.cpp

# Kernel 编译（添加到 ascendc_library）
${PROJECT_OP_SRC_BASE}/ops/<op_name>/op_kernel/kernel_<op_name>.cpp
```


### 步骤 6: 编译验证

**必须执行编译验证**：

```bash
cd ./ascend-kernel
./build.sh
```

**编译成功判断**：
```bash
ls ./output/ascend_kernel*.whl
```

如果存在 `ascend_kernel-<version>-<python>-<platform>.whl` 文件，则编译成功。

**编译失败处理**：最多尝试 3 次修复。详见 [troubleshooting.md](references/troubleshooting.md)。

### 步骤 7: 生成测试用例

**必须生成测试用例**: 在 `tests/` 目录下创建 `test_<op_name>.py`

测试用例模板详见 [unit-test-template.md](references/unit-test-template.md)。

### 步骤 8: 功能测试

**必须执行功能测试**，验证算子是否可运行：

```bash
cd ./ascend-kernel
python tests/test_<op_name>.py
```

**测试通过标准**: 程序正常退出。

**测试失败处理**：最多尝试 3 次修复，流程同编译失败处理。

### 步骤 9: 精度测试（可选）

如需验证数值精度，执行 pytest 测试：

```bash
cd ./ascend-kernel
pytest tests/test_<op_name>.py -v
```

**任务完成**: 功能测试通过后，任务完成。

---

## 参考资料

- **类型映射和代码模式**: [type-mapping.md](references/type-mapping.md)
- **完整示例**: [examples.md](references/examples.md)
- **问题排查**: [troubleshooting.md](references/troubleshooting.md)
- **单元测试模板**: [unit-test-template.md](references/unit-test-template.md)

---

## 注意事项

1. **一对一映射原则**: 除非用户特别要求，否则每个 ACLNN 接口或算子只对应一个 torch 接口
2. **禁止修改基础文件**: `cmake/` 和 `csrc/utils/` 目录下的文件禁止修改，编译报错时只允许修改生成的代码
3. **命名规范**: 算子名 `snake_case`，ACLNN 函数 `PascalCase`
4. **内存管理**: `EXEC_NPU_CMD` 自动管理 workspace 内存
5. **设备检查**: 确保输入 tensor 在 NPU 设备上
6. **格式一致性**: 使用 `at_npu::native::get_npu_format()` 保持格式一致
