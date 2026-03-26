# Troubleshooting

## 重要约束

**禁止修改以下目录的文件**：
- `cmake/` - 构建配置
- `csrc/utils/` - 工具函数

编译报错时，只允许修改生成的代码（`csrc/aclnn/`、`csrc/ops/`、`csrc/ops.h`、`csrc/register.cpp`、`csrc/CMakeLists.txt`）。

---

## 常见编译错误

| 错误类型 | 可能原因 | 修复方法 |
|---------|---------|---------|
| `undeclared identifier` | 缺少头文件或函数声明 | 检查 `#include` 和 `ops.h` 声明 |
| `no matching function` | 参数类型不匹配 | 检查 ACLNN API 参数顺序和类型 |
| `linker error` | 源文件未加入编译 | 检查 `CMakeLists.txt` 的 `OP_SRCS` |
| `redefinition` | 重复定义 | 检查是否有重复的函数定义 |

---

## 常见问题与解决

### 1. 编译错误：找不到 ACLNN 函数

**原因**: ACLNN API 名称拼写错误或该 API 不存在于当前 CANN 版本。

**解决**:
- 检查 ACLNN API 名称是否正确（注意大小写）
- 确认 CANN 版本支持该 API

### 2. 运行时错误：tensor 不在 NPU 上

**解决**: 在调用前将 tensor 移到 NPU：
```python
x = x.npu()  # 或 x.to('npu')
```

### 3. 输出形状不正确

**解决**:
- 检查 `output_size` 计算逻辑
- 参考 PyTorch 原生实现的输出形状计算

### 4. 精度问题

**解决**:
- 检查数据类型是否匹配（float16 vs float32）
- 确认 ACLNN API 的精度特性

---

## 编译失败处理流程

**最多尝试 3 次**：

```
尝试 1:
  1. 分析编译错误信息
  2. 定位错误位置（文件名:行号）
  3. 修复代码
  4. 重新运行 ./build.sh
  5. 检查 output/ 目录下是否生成 whl 文件

尝试 2 (如果尝试 1 仍失败):
  1. 重新分析错误
  2. 检查是否遗漏了必要的头文件或声明
  3. 修复代码
  4. 重新运行 ./build.sh
  5. 检查 output/ 目录下是否生成 whl 文件

尝试 3 (如果尝试 2 仍失败):
  1. 深入分析错误根因
  2. 检查 CMakeLists.txt 配置
  3. 修复代码
  4. 重新运行 ./build.sh
  5. 检查 output/ 目录下是否生成 whl 文件
```

**3 次失败后仍不通过**: 向用户报告详细错误信息，说明已尝试的修复，请求用户协助。
