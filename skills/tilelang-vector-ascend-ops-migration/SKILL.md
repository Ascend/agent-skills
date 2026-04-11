# TileLang GPU到NPU算子迁移 Skill

## 技能概述

本skill用于指导TileLang算子从GPU（CUDA）平台迁移到华为昇腾NPU平台。通过分析GPU实现，自动生成对应的NPU实现代码。

## 适用场景

- 将`gpu/`目录下的TileLang算子迁移到`npu/`目录（或者说讲适配GPU的tilelang算子迁移为适配NPU的tilelang算子，如果用户没有说迁移到的算子放在哪里，就新建一个npu目录，放在npu目录下，并提示用户迁移算子的存放位置）
- 自动适配NPU硬件约束和API差异
- 生成可直接运行的NPU算子代码

## 📚 重要参考文档

**在迁移过程中，GPU 和 NPU 的 API 接口存在显著差异，强烈建议参考以下文档：**

### 核心文档

- **`docs/GPU-To-NPU-Migration-Methods.md`** - 详细迁移经验和案例

### 补充文档

- **`references/debugging-guide.md`** - NPU算子调试指南
  - 精度问题、编译失败、运行时错误的调试方法
  - TVM IR、MLIR层的调试技巧
  - T.print打印调试、GDB调试

- **`references/hardware-optimization.md`** - NPU硬件特性与性能优化
  - 片上缓存容量限制（UB 192KB，L1 512KB）
  - 数据对齐要求详解
  - 存算并行与流水线优化
  - 物理核数限制与分核策略

**使用建议：**

- 遇到不确定的 API 时，优先查阅 `TileLang-NPU-API-Reference.md`
- GPU 的某些 API 在 NPU 上可能不存在或名称不同（如 `T.vconv` → `T.vcast`）
- 向量化操作的参数顺序和类型要求可能不同
- 遇到调试问题时，参考 `debugging-guide.md`
- 进行性能优化时，参考 `hardware-optimization.md`

## ⚠️ 关键注意事项

**最常见错误1：使用逐元素处理而非分块处理**

这是 NPU 迁移中**最致命且最容易犯的错误**。NPU 的向量化架构要求使用分块处理，而不是逐元素处理。

```python
# ❌ 错误写法：逐元素处理（效率极低且容易出错）
@T.prim_func
def main(X: T.Tensor((M, N), "float16"), Y: T.Tensor((M, N), "float16")):
    with T.Kernel(M * N, is_npu=True) as (cid, _):
        idx = cid
        bx = idx // N
        by = idx % N

        # 为每个元素分配独立的 buffer（错误！）
        x_ub = T.alloc_shared((1,), "float16")
        y_ub = T.alloc_shared((1,), "float32")

        # 单个元素访问（错误！）
        T.copy(X[bx, by], x_ub)
        T.vsigmoid(x_ub, y_ub)
        T.copy(y_ub, Y[bx, by])

# ✅ 正确写法：分块处理
@T.prim_func
def main(X: T.Tensor((M, N), "float16"), Y: T.Tensor((M, N), "float16")):
    with T.Kernel(T.ceildiv(M, block_M) * T.ceildiv(N, block_N), is_npu=True) as (cid, _):
        grid_y = T.ceildiv(N, block_N)
        bx = cid // grid_y
        by = cid % grid_y

        # 为整个 block 分配 buffer
        x_ub = T.alloc_shared((block_M, block_N), "float16")
        y_ub = T.alloc_shared((block_M, block_N), "float32")

        # 使用切片访问整个 block
        T.copy(X[bx * block_M : (bx + 1) * block_M,
                 by * block_N : (by + 1) * block_N], x_ub)
        T.vsigmoid(x_ub, y_ub)
        T.copy(y_ub, Y[bx * block_M : (bx + 1) * block_M,
                       by * block_N : (by + 1) * block_N])
```

**为什么必须使用分块处理：**

1. NPU 的向量化指令设计用于处理较大的数据块（通常 64x64）
2. 逐元素处理无法发挥 NPU 的并行计算能力
3. 单元素 buffer 的内存访问效率极低
4. 可能导致运行时错误或结果不正确

**推荐的 block 大小：**

- 2D tensor：`block_M=64, block_N=64`
- 1D tensor：`block_size=256` 或 `block_size=512`

---

**最常见错误2：Grid 大小计算位置错误**

在迁移过程中，另一个**最容易犯且最高频的错误**是在 `@T.prim_func` 内部定义局部变量来计算 grid 大小。

```python
# ❌ 错误写法（会导致编译失败）
@T.prim_func
def main(...):
    num_blocks = M * N  # 局部变量
    with T.Kernel(num_blocks, is_npu=True):  # 编译时找不到 num_blocks！
        ...

# ✅ 正确写法
@T.prim_func
def main(...):
    with T.Kernel(M * N, is_npu=True):  # 直接使用参数计算
        ...
```

**原因：** `T.Kernel` 的 grid 参数在编译阶段求值，此时函数内部的局部变量还不存在。

**解决方案：** 始终在 `T.Kernel(...)` 参数中直接使用函数参数和 `T.ceildiv` 计算，不要使用任何局部变量。

---

**最常见错误3：使用不存在的标量运算 API**

NPU **不支持标量与向量直接运算的 API**（如 `T.vmuls`、`T.vadds` 等），必须先将标量广播为向量。

```python
# ❌ 错误写法：使用不存在的 T.vmuls
alpha_scalar = T.cast(0.01, "float32")
T.vmuls(x_fp32, alpha_scalar, result)  # API 不存在！

# ✅ 正确写法：先广播再向量运算
alpha_scalar = T.cast(0.01, "float32")
alpha_ub = T.alloc_shared((block_M, block_N), "float32")
T.vbrc(alpha_scalar, alpha_ub)  # 广播标量到向量
T.vmul(x_fp32, alpha_ub, result)  # 向量乘法
```

**关键点：**

1. NPU 只有向量运算 API：`T.vadd`、`T.vmul`、`T.vsub`、`T.vdiv`
2. 没有标量运算 API：`T.vadds`、`T.vmuls` 等都不存在
3. 必须使用 `T.vbrc(scalar, tensor)` 将标量广播成向量
4. 注意：`T.vbrc` 的第一个参数必须是变量，不能是字面量

---

**最常见错误4：T.vcmp 参数顺序错误**

NPU 的 `T.vcmp` API 需要**显式指定输出 buffer**，且参数顺序与 GPU 不同。

```python
# ❌ 错误写法：返回值方式（GPU 风格）
mask = T.vcmp(x_fp32, zero_ub, "GT")  # NPU 不支持！

# ❌ 错误写法：参数顺序错误
T.vcmp(x_fp32, zero_ub, "gt", mask_ub)  # 参数顺序错误！

# ✅ 正确写法：显式输出 buffer
mask_ub = T.alloc_shared((block_M, block_N), "bool")
T.vcmp(x_fp32, zero_ub, mask_ub, "gt")  # 正确顺序
T.vselect(mask_ub, true_val, false_val, result)
```

**关键点：**

1. `T.vcmp` 的正确签名：`T.vcmp(src0, src1, dst, cmp_op)`
2. 必须先分配 `"bool"` 类型的输出 buffer
3. 比较操作符用**小写字符串**：`"gt"`, `"lt"`, `"ge"`, `"le"`, `"eq"`, `"ne"`
4. 返回值是 `None`，结果存储在 `dst` 参数中

---

**最常见错误5：T.copy 用于广播操作**

NPU 的 `T.copy` **不支持形状不匹配的复制**，不能用于广播操作。必须使用 `T.vbrc` 进行标量广播。

```python
# ❌ 错误写法：使用 T.copy 广播
max_ub = T.alloc_shared((1, 1), "float32")  # 归约结果
T.reduce_max(x_fp32, max_ub, dim=-1)

max_brc = T.alloc_shared((1, N), "float32")
T.copy(max_ub, max_brc)  # ❌ 错误：形状不匹配 (1,1) → (1,N)

# ✅ 正确写法：提取标量后使用 T.vbrc 广播
max_ub = T.alloc_shared((1, 1), "float32")
T.reduce_max(x_fp32, max_ub, dim=-1)

max_brc = T.alloc_shared((1, N), "float32")
max_scalar = max_ub[0, 0]  # 提取标量值
T.vbrc(max_scalar, max_brc)  # 广播到向量
```

**关键点：**

1. `T.copy` 要求源和目标形状**完全一致**，不支持自动广播
2. 归约操作（`T.reduce_max`、`T.reduce_sum`）的结果通常需要广播回原始维度
3. 必须先通过索引（如 `[0, 0]`）提取标量值
4. 使用 `T.vbrc(scalar, tensor)` 将标量广播到整个 tensor
5. 这是 softmax、layernorm 等归约类算子的**必备操作模式**

---

**最常见错误6：分块处理时忽略边界检查**

这是 NPU 分块处理中**非常容易遗漏的问题**。当 tensor 维度不是 block 大小的整数倍时，最后一个 block 会访问越界内存，导致运行时崩溃。

```python
# ❌ 错误写法：忽略边界检查
@T.prim_func
def main(X: T.Tensor((M, N), "float16"), Y: T.Tensor((M, N), "float16")):
    with T.Kernel(T.ceildiv(M, block_M) * T.ceildiv(N, block_N), is_npu=True) as (cid, _):
        grid_y = T.ceildiv(N, block_N)
        bx = cid // grid_y
        by = cid % grid_y

        x_ub = T.alloc_shared((block_M, block_N), "float16")
        y_ub = T.alloc_shared((block_M, block_N), "float16")

        # 当 M 或 N 不是 64 的倍数时，最后一个 block 会越界！
        T.copy(X[bx * block_M : (bx + 1) * block_M, by * block_N : (by + 1) * block_N], x_ub)
        T.vrelu(x_ub, y_ub)
        T.copy(y_ub, Y[bx * block_M : (bx + 1) * block_M, by * block_N : (by + 1) * block_N])

# ✅ 正确写法：使用 size 参数处理边界
@T.prim_func
def main(X: T.Tensor((M, N), "float16"), Y: T.Tensor((M, N), "float16")):
    with T.Kernel(T.ceildiv(M, block_M) * T.ceildiv(N, block_N), is_npu=True) as (cid, _):
        grid_y = T.ceildiv(N, block_N)
        bx = cid // grid_y
        by = cid % grid_y

        row_start = bx * block_M
        col_start = by * block_N

        # 计算当前 block 的实际大小
        actual_M = T.min(block_M, M - row_start)
        actual_N = T.min(block_N, N - col_start)

        x_ub = T.alloc_shared((block_M, block_N), "float16")
        y_ub = T.alloc_shared((block_M, block_N), "float16")

        # 使用 size 参数指定实际拷贝大小
        T.copy(X[row_start, col_start], x_ub, size=[actual_M, actual_N])
        T.vrelu(x_ub, y_ub)
        T.copy(y_ub, Y[row_start, col_start], size=[actual_M, actual_N])
```

**关键点：**

1. **必须计算实际大小**：`actual_M = T.min(block_M, M - row_start)`
2. **使用 size 参数**：`T.copy(src, dst, size=[actual_M, actual_N])`
3. **不能使用切片语法配合 size**：`T.copy(X[start:end, ...], dst, size=[...])` 是错误的
4. **正确写法**：`T.copy(X[row_start, col_start], dst, size=[actual_M, actual_N])`

**错误现象：**

```
The write address of the MTE instruction is out of range
vector core exception
```

---

**最常见错误7：T.copy 切片语法与 size 参数冲突**

TileLang 不允许同时使用切片语法和 `size` 参数，这会导致编译错误。

```python
# ❌ 错误写法：切片语法 + size 参数
T.copy(X[row_start:row_end, col_start:col_end], x_ub, size=[actual_M, actual_N])
# 错误信息：T.copy: cannot use both slice syntax and the size parameter.

# ✅ 正确写法：起始位置索引 + size 参数
T.copy(X[row_start, col_start], x_ub, size=[actual_M, actual_N])
```

**记忆口诀：**

> 使用 `size` 参数时，源 tensor 只能用起始位置索引（`X[row, col]`），不能用切片语法（`X[start:end]`）。

---

**最常见错误8：测试数据超出实际模型范围**

这是一个**极易被忽视但影响重大的错误**。NPU的底层API经过针对性优化（如使用近似函数拟合），只在特定数值范围内保证精度。

```python
# ❌ 错误写法：生成超出实际范围的测试数据
def test_sigmoid_npu():
    # sigmoid在实际模型中输入通常在[-10, 10]范围
    X = torch.randn(M, N) * 100  # 生成[-300, 300]，超出实际范围！
    Y = sigmoid_npu(X)
    # 可能导致精度测试失败，但实际模型中不会出现这种输入

# ✅ 正确写法：符合实际模型场景的测试数据
def test_sigmoid_npu():
    # 分析实际模型中sigmoid的输入分布
    X = torch.randn(M, N) * 3  # 生成[-9, 9]范围，符合实际
    Y = sigmoid_npu(X)
```

**关键原则：**

1. **分析算子的实际使用场景**：查看算子在模型中的输入范围
2. **常见算子的典型范围**：
   - sigmoid/tanh：输入通常在 [-10, 10]
   - softmax：输入经过归一化，通常在 [-5, 5]
   - LayerNorm：归一化后输出在 [-3, 3]
   - 概率值：在 [0, 1] 范围
3. **不要随意放大测试范围**：即使测试通过，也可能掩盖实际问题
4. **参考PyTorch文档**：了解各算子的数值特性

**为什么这很重要：**

- NPU使用查找表、多项式拟合等优化技术
- 这些优化针对实际模型的数值分布设计
- 超出范围的测试可能失败，但不影响实际部署

---

## 必做清单

- **必须使用分块处理（Block-based Processing）**：NPU 算子必须采用分块处理方式，不能逐元素处理。每个 kernel 处理一个 block（如 64x64）的数据，使用切片访问内存。

- **必须处理边界情况（Boundary Handling）**：当 tensor 维度不是 block 大小的整数倍时，必须使用 `size` 参数处理边界。计算实际大小：`actual_M = T.min(block_M, M - row_start)`，并在 `T.copy` 中使用 `size=[actual_M, actual_N]`。

- **查阅 NPU API 文档确认所有 API 存在**：迁移前必须在 `./docs/TileLang-NPU-API-Reference.md` 中确认每个使用的 API 都存在。特别注意：

  - NPU 没有标量运算 API（`T.vmuls`、`T.vadds` 等不存在）
  - 需要标量运算时，必须用 `T.vbrc` 广播后再用向量 API
  - 类型转换用 `T.vcast` 而非 `T.vconv`
  - `T.vcmp` 必须显式分配 `"bool"` 类型的输出 buffer，参数顺序为 `T.vcmp(src0, src1, dst, cmp_op)`
  - `T.copy` 不支持形状不匹配的复制，归约结果广播必须用 `T.vbrc`

- **测试数据必须符合实际模型场景**：生成测试用例时，输入数据的范围必须符合实际模型中可能出现的情况。NPU的底层API经过针对性优化（如近似函数拟合），只在特定数值范围内保证精度。

  **关键原则：**

  - 分析算子在实际模型中的输入范围（如sigmoid输入通常在[-10, 10]，softmax输入经过归一化）
  - 不要生成超出实际范围的测试数据（如某些激活函数输入不会>1，就不要生成>1的测试值）
  - 参考PyTorch/模型文档了解各算子的典型输入分布

  **错误示例：**

  ```python
  # ❌ 错误：sigmoid在模型中输入通常有界，不会出现极大值
  X = torch.randn(M, N) * 100  # 生成[-300, 300]范围，不符合实际
  
  # ✅ 正确：符合实际模型中sigmoid的输入范围
  X = torch.randn(M, N) * 3    # 生成[-9, 9]范围，符合实际
  ```

- 拒绝迁移需要使用已经发现精度问题的 API 的算子

  如果需要使用这些API，要么想办法绕过去，用其他替代，如果不能替代就直接报告无法迁移

  - 拒绝使用的API

    暂空

## 迁移流程

### 第一步：分析GPU算子

当用户请求迁移某个算子时，首先读取GPU实现文件：

```
gpu/<算子名称>.py
```

分析以下关键信息：

1. 算子的输入输出tensor形状和数据类型
2. 核心计算逻辑（GEMM、归约、激活函数等）
3. 内存分配模式（shared memory、fragment）
4. 并行策略（T.Parallel、T.serial、T.Pipelined）
5. 动态shape定义

### 第二步：应用迁移规则

参考`docs/TileLang-NPU-API-Reference.md`和`docs/GPU-To-NPU-Migration-Methods.md`，应用以下核心迁移规则：

#### 2.1 环境和装饰器

**GPU版本：**

```python
import tilelang as tl
import tilelang.language as T

@tl.jit(pass_configs={...})
def kernel_impl(...):
```

**NPU版本：**

```python
import os
import tilelang
import tilelang.language as T

os.environ['TILELANG_ASCEND_MODE'] = 'Developer'

@tilelang.jit(target="npuir")
def kernel_impl(...):
```

#### 2.2 数据类型转换

| GPU                 | NPU                  |
| ------------------- | -------------------- |
| `T.bfloat16`        | `"float16"`          |
| `T.float32`         | `"float32"`          |
| `T.int32`           | `"int32"`            |
| `T.dynamic("name")` | `T.symbolic("name")` |

#### 2.3 Kernel声明

**GPU版本：**

```python
with T.Kernel(T.ceildiv(seq_len, block_Q), threads=512) as bx:
    tx = T.thread_binding(0, 512, thread="threadIdx.x")
```

**NPU版本：**

```python
with T.Kernel(num_blocks, is_npu=True) as (cid, _):
    # cid是core ID，NPU自动管理线程
```

#### 2.4 内存操作

| 操作       | GPU                      | NPU                              |
| ---------- | ------------------------ | -------------------------------- |
| 清零       | `T.fill(tensor, 0)`      | `T.clear(tensor)`                |
| GEMM初始化 | `clear_accum=True`       | `initC=True`                     |
| GEMM转置   | `transpose_A=True`       | `a_transpose=True`               |
| 原子操作   | `T.atomic_add(dst, src)` | `T.atomic_add(dst, src, [size])` |

#### 2.5 并行循环约束

在`T.Parallel`内：

- 必须操作UB buffer，不能直接访问全局内存
- 使用`T.vmax`/`T.vmin`替代`T.max`/`T.min`
- 避免索引运算（如`A[i+1]`）
- 使用`T.vselect`替代条件判断

#### 2.6 向量化优先

**GPU版本（循环）：**

```python
for i, j in T.Parallel(M, N):
    C[i, j] = T.max(A[i, j], 0) * B[i, j]
```

**NPU版本（向量化）：**

```python
T.copy(A, A_ub)
T.vrelu(A_ub, A_ub)
T.vmul(A_ub, B_ub, C_ub)
```

### 第三步：NPU硬件约束检查

> 💡 **详细优化指南**：本节提供基本的硬件约束检查要点。更深入的性能优化策略（包括Tiling策略、存算并行、分核优化等）请参考 [`references/hardware-optimization.md`](references/hardware-optimization.md)

#### 3.1 UB内存限制（关键约束）

**硬约束：** 单个Kernel内所有`T.alloc_shared()`和`T.alloc_fragment()`的总和必须 < 96KB
**建议值：** < 85KB（预留临时变量空间）

**内存计算公式：**

```python
# FP16: 2 bytes, FP32: 4 bytes, INT32: 4 bytes
total_bytes = sum(shape[0] * shape[1] * dtype_bytes for each allocation)
```

**示例：**

```python
# ✅ 安全（约48KB）
q_shared = T.alloc_shared([64, 128], "float16")    # 16KB
k_shared = T.alloc_shared([64, 128], "float16")    # 16KB
acc_ub = T.alloc_shared([64, 64], "float32")       # 16KB

# ❌ 超限（256KB）
q_shared = T.alloc_shared([512, 128], "float16")   # 128KB
k_shared = T.alloc_shared([512, 128], "float16")   # 128KB
```

如果内存超限，需要：

1. 减小block_size
2. 分块处理
3. 复用buffer

#### 3.2 数据对齐要求

- FP16/BF16：维度必须是16的倍数（32字节对齐）
- FP32/INT32：维度必须是8的倍数（32字节对齐）
- 所有输入tensor必须调用`.contiguous()`

#### 3.3 已知BUG规避

1. **Cube后Vector操作卡死**：`T.gemm()`后立即使用`T.vcmp`+`T.vselect`会卡死
   - 解决：使用`T.vrelu`替代

2. **Gather后GEMM崩溃**：循环内Gather数据后直接GEMM会编译失败
   - 解决：在CPU端预完成Gather操作

3. **CV分核Bug**：某些情况需要添加无意义操作触发优化
   - 解决：`T.vadd(k_shared, T.cast(0.0, dtype), k_shared)`

### 第四步：生成NPU代码

生成的NPU代码应包含以下结构：

```python
import os
import torch
import tilelang
import tilelang.language as T

os.environ['TILELANG_ASCEND_MODE'] = 'Developer'

FP16 = "float16"
FP32 = "float32"
INT32 = "int32"

@tilelang.jit(target="npuir")
def _kernel_impl(...):
    dtype = FP16
    accum_dtype = FP32

    # 使用T.symbolic定义动态shape
    seq_len = T.symbolic("seq_len")

    @T.prim_func
    def kernel(...):
        with T.Kernel(num_blocks, is_npu=True) as (cid, _):
            # 1. 内存分配
            # 2. 数据加载
            # 3. 计算逻辑
            # 4. 结果写回

    return kernel

def wrapper_function(...):
    # PyTorch接口封装
    kernel = _kernel_impl(...)
    kernel(...)
    return output

def run_test():
    # 测试代码，对比参考实现
    pass

if __name__ == "__main__":
    run_test()
```

### 第五步：验证和测试

> 💡 **调试指南**：如果测试失败或遇到编译/运行时错误，请参考 [`references/debugging-guide.md`](references/debugging-guide.md) 获取详细的调试方法。

生成代码后，执行以下命令测试：

:warning:调试之前，请先询问用户，tilelang-ascend相关环境是否配好

```bash
python3 <迁移的算子名称、路径>.py"
```

#### 测试代码要求

**必须包含以下内容：**

1. **计算误差**：使用 PyTorch 参考实现对比
2. **输出误差值**：打印最大绝对误差
3. **判断通过条件**：误差 < 1e-3
4. **明确输出结果**：打印 ✅ 或 ❌

**标准测试代码模板：**

```python
def test_xxx_npu():
    # 1. 准备输入数据
    X = torch.randn(..., dtype=torch.float16, device="npu").contiguous()
    Y_npu = torch.empty(..., dtype=torch.float16, device="npu")

    # 2. 运行 NPU kernel
    kernel = xxx_npu(...)
    kernel(X, Y_npu)

    # 3. 运行 PyTorch 参考实现
    Y_ref = pytorch_reference(X)

    # 4. 计算误差
    max_diff = torch.max(torch.abs(Y_npu - Y_ref)).item()
    print(f"Max difference: {max_diff}")

    # 5. 判断并输出结果（必须）
    if max_diff < 1e-3:
        print("✅ Validation Passed!")
    else:
        print("❌ Validation Failed.")

if __name__ == "__main__":
    test_xxx_npu()
```

**关键要求：**

- ✅ 必须输出 `Max difference: xxx`
- ✅ 必须输出 `✅ Validation Passed!` 或 `❌ Validation Failed.`
- ✅ 判断条件：`max_diff < 1e-3`
- ✅ 所有输入 tensor 必须调用 `.contiguous()`

## 迁移检查清单

执行迁移时，必须检查以下项目：

### 核心架构（最重要）

- [ ] **使用分块处理**：必须使用 `block_M`, `block_N` 参数，不能逐元素处理
- [ ] **Grid 大小计算**：使用 `T.ceildiv(M, block_M) * T.ceildiv(N, block_N)`
- [ ] **边界检查处理**：计算实际大小 `actual_M = T.min(block_M, M - row_start)`，使用 `size` 参数处理非整数倍边界
- [ ] **T.copy 语法正确**：使用 `T.copy(X[row_start, col_start], dst, size=[...])` 而非切片语法配合 size
- [ ] **Buffer 大小**：为整个 block 分配 buffer，如 `(block_M, block_N)` 而非 `(1,)`

### 环境配置

- [ ] 添加`os.environ['TILELANG_ASCEND_MODE'] = 'Developer'`
- [ ] 装饰器改为`@tilelang.jit(target="npuir")`
- [ ] Kernel声明添加`is_npu=True`

### 数据类型

- [ ] `T.bfloat16` → `"float16"`
- [ ] `T.float32` → `"float32"`
- [ ] `T.int32` → `"int32"`
- [ ] `T.dynamic` → `T.symbolic`

### 内存约束

- [ ] 计算UB总内存 < 96KB（建议 < 85KB）
- [ ] 检查维度对齐（FP16需16倍数，FP32需8倍数）
- [ ] 所有输入tensor调用`.contiguous()`

### API映射

- [ ] `T.fill(x, 0)` → `T.clear(x)`
- [ ] `clear_accum` → `initC`
- [ ] `transpose_A/B` → `a_transpose/b_transpose`
- [ ] `T.max/T.min` → `T.vmax/T.vmin`（在T.Parallel内）
- [ ] `T.atomic_add(dst, src)` → `T.atomic_add(dst, src, [size])`
- [ ] `T.vcmp` 使用正确参数顺序：`T.vcmp(src0, src1, dst, cmp_op)`，需先分配 `"bool"` 类型的 dst buffer

### BUG规避

- [ ] 避免Cube后立即Vector操作（使用T.vrelu）
- [ ] 避免循环内Gather后GEMM
- [ ] 必要时添加CV分核Bug修复

### 测试验证

- [ ] 生成测试代码对比参考实现
- [ ] 使用docker命令执行测试
- [ ] 验证数值精度（rtol=1e-3, atol=1e-3）

## 参考文档

迁移过程中请参考：

- `docs/TileLang-NPU-API-Reference.md` - NPU API简略文档（包含所有API但内容简略）
- `docs/GPU-To-NPU-Migration-Methods.md` - 详细迁移经验
- `docs/examples`下，每个python文件都是一个简单vector tilelang算子从GPU迁移到NPU的示例

## 常见迁移陷阱与解决方案

### 陷阱1：T.Buffer已废弃

**错误现象：**

```
DeprecationWarning: T.Buffer(...) is deprecated, use T.Tensor(...) instead
```

**解决方案：**

```python
# ❌ 错误
X: T.Buffer((M, N), "float16")

# ✅ 正确
X: T.Tensor((M, N), "float16")
```

### 陷阱2：向量操作类型必须匹配

**错误现象：**

```
error: 'hivm.hir.vmul' op requires the same element type for all operands
```

**原因：**
NPU的向量操作（`T.vmul`, `T.vadd`等）要求所有操作数类型完全一致，不能混用FP16和FP32。

**解决方案：**

```python
# ❌ 错误：混用FP16和FP32
x1_ub = T.alloc_shared((M, N), "float16")
y_ub = T.alloc_shared((M, N), "float32")
T.vmul(x1_ub, y_ub, y_ub)  # 类型不匹配！

# ✅ 正确：先转换类型
x1_ub = T.alloc_shared((M, N), "float16")
x1_fp32 = T.alloc_shared((M, N), "float32")
y_ub = T.alloc_shared((M, N), "float32")
T.vcast(x1_ub, x1_fp32)  # FP16 → FP32
T.vmul(x1_fp32, y_ub, y_ub)  # 类型一致
```

### 陷阱3：类型转换API错误

**错误现象：**

```
error: module 'tilelang.language' has no attribute 'vconv'
```

**原因：**
NPU不支持`T.vconv`，应使用`T.vcast`进行类型转换。

**解决方案：**

```python
# ❌ 错误
T.vconv(x_fp16, "none", x_fp32, 1.0)

# ✅ 正确
T.vcast(x_fp16, x_fp32)
```

### 陷阱4：Grid大小计算位置错误（高频错误）

**错误现象：**

```
ValueError: Failed to evaluate grid expression 'num_blocks': name 'num_blocks' is not defined
ValueError: Failed to evaluate grid expression 'total_tokens': name 'total_tokens' is not defined
```

**根本原因：**
TileLang 编译器在处理 `T.Kernel(grid_size, ...)` 时，会在**编译阶段**尝试解析 `grid_size` 表达式。此时 `@T.prim_func` 内部定义的局部变量尚未执行，因此无法被访问。

**技术细节：**

1. `T.Kernel` 的 grid 参数必须是**编译时可求值的表达式**
2. 只能使用函数参数（如 `M`, `N`, `batch_size`）和 TileLang 内置函数（如 `T.ceildiv`）
3. 不能使用 `@T.prim_func` 内部的任何局部变量

**解决方案：**

**方案1：2D Grid 展平**

```python
# ❌ 错误示例1
@T.prim_func
def main(...):
    grid_x = (M + block_M - 1) // block_M
    grid_y = (N + block_N - 1) // block_N
    num_blocks = grid_x * grid_y
    with T.Kernel(num_blocks, is_npu=True) as (cid, _):  # 编译时 num_blocks 不存在！
        ...

# ✅ 正确：直接在 Kernel 参数中计算
@T.prim_func
def main(...):
    with T.Kernel(T.ceildiv(M, block_M) * T.ceildiv(N, block_N), is_npu=True) as (cid, _):
        grid_y = T.ceildiv(N, block_N)
        bx = cid // grid_y
        by = cid % grid_y
        ...
```

**方案2：简单乘法**

```python
# ❌ 错误示例2
@T.prim_func
def main(...):
    total_tokens = batch_size * seq_len  # 局部变量
    with T.Kernel(total_tokens, is_npu=True) as (cid, _):  # 编译时 total_tokens 不存在！
        ...

# ✅ 正确：直接使用参数计算
@T.prim_func
def main(...):
    with T.Kernel(batch_size * seq_len, is_npu=True) as (cid, _):
        b = cid // seq_len
        s = cid % seq_len
        ...
```

**记忆口诀：**

> T.Kernel 的 grid 参数中，只能直接使用函数参数和 T.ceildiv，不能使用任何局部变量。

### 陷阱5：激活函数计算顺序

**问题：**
计算Swish等复合激活函数时，需要注意中间结果的复用。

**最佳实践：**

```python
# Swish(x1) * x2 = (x1 * sigmoid(x1)) * x2
T.vcast(x1_ub, x1_fp32)  # 转FP32
T.vcast(x2_ub, x2_fp32)
T.vsigmoid(x1_fp32, y_ub)  # sigmoid(x1) → y_ub
T.vmul(x1_fp32, y_ub, y_ub)  # x1 * sigmoid(x1) → y_ub
T.vmul(y_ub, x2_fp32, y_ub)  # swish(x1) * x2 → y_ub
T.vcast(y_ub, y_fp16)  # 转回FP16
```

### 陷阱6：分块边界越界（高频错误）

**错误现象：**

```
The write address of the MTE instruction is out of range
vector core exception
```

**原因：**
当 tensor 维度（M 或 N）不是 block 大小（如 64）的整数倍时，最后一个 block 的切片访问会超出 tensor 边界，导致内存越界错误。

**错误示例：**

```python
# ❌ 错误：当 M=100, block_M=64 时，第二个 block 会访问 [64:128]，超出边界
T.copy(X[bx * block_M : (bx + 1) * block_M, by * block_N : (by + 1) * block_N], x_ub)
```

**解决方案：**

```python
# ✅ 正确：计算实际大小并使用 size 参数
row_start = bx * block_M
col_start = by * block_N
actual_M = T.min(block_M, M - row_start)  # 第二个 block: min(64, 100-64) = 36
actual_N = T.min(block_N, N - col_start)

T.copy(X[row_start, col_start], x_ub, size=[actual_M, actual_N])
```

**关键点：**

1. GPU 逐元素处理天然避免越界，但 NPU 分块处理需要显式边界检查
2. 必须在 `T.copy` 中使用 `size` 参数限制实际访问范围
3. 注意：切片语法和 `size` 参数不能同时使用

### 陷阱7：T.copy 切片语法与 size 参数冲突

**错误现象：**

```
error: T.copy: cannot use both slice syntax and the size parameter.
```

**原因：**
TileLang 编译器不允许 `T.copy` 同时使用切片语法和 `size` 参数。

**错误示例：**

```python
# ❌ 错误：切片语法 + size 参数
T.copy(X[row_start:row_end, col_start:col_end], x_ub, size=[actual_M, actual_N])
```

**解决方案：**

```python
# ✅ 正确：使用起始位置索引 + size 参数
T.copy(X[row_start, col_start], x_ub, size=[actual_M, actual_N])
```

**记忆口诀：**

> 需要边界处理时，`T.copy` 用起始位置索引配合 `size` 参数，不用切片语法。

## 使用说明

当用户请求迁移算子时：

1. 读取`<gpu算子名称>.py`文件
2. 参考API文档和迁移经验应用转换规则
3. 生成`<npu算子名称>.py`文件
4. 提示用户执行测试命令验证（需要事先确保环境正常工作）

