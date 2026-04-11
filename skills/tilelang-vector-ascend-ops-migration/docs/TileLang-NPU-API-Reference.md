# TileLang NPU API 参考文档

本文档总结了TileLang在昇腾NPU平台上支持的API，包括内存操作、数学操作、线性代数操作、归约操作、比较操作、条件操作、原子操作等。

## 目录

- [数据类型支持](#数据类型支持)
- [内存操作](#内存操作)
- [数学操作](#数学操作)
- [线性代数操作](#线性代数操作)
- [归约操作](#归约操作)
- [比较操作](#比较操作)
- [条件操作](#条件操作)
- [原子操作](#原子操作)
- [编译器提示操作](#编译器提示操作)
- [数据类型转换操作](#数据类型转换操作)
- [索引与元素操作](#索引与元素操作)
- [Shape操作](#shape操作)
- [创建操作](#创建操作)
- [同步管道操作](#同步管道操作)
- [排序操作](#排序操作)
- [逻辑操作](#逻辑操作)
- [调试操作](#调试操作)

---

## 数据类型支持

NPU平台支持的数据类型：

| 数据类型 | 字符串表示 | 支持情况 | 说明 |
|----------|-----------|---------|------|
| FP16 | `"float16"` | ✅ 支持 | 16位浮点数 |
| FP32 | `"float32"` | ✅ 支持 | 32位浮点数 |
| BF16 | `"float16"` | ⚠️ 需转换 | NPU可能不支持，建议转换为FP16 |
| INT32 | `"int32"` | ✅ 支持 | 32位整数 |
| INT8 | `"int8"` | ❌ 不支持 | 8位整数 |
| UINT8 | `"uint8"` | ❌ 不支持 | 无符号8位整数 |

**注意事项：**
- NPU主要支持FP16和FP32
- BF16在NPU上可能需要转换为FP16
- 必须使用字符串形式表示数据类型（如`"float16"`），不能使用TileLang类型对象（如`T.bfloat16`）

---

## 内存操作

### T.alloc_shared

**函数签名：**
```python
T.alloc_shared(shape, dtype)
```

**参数说明：**
- `shape`: 内存形状，整数元组，支持1D~2D（3D~5D有待充分验证）
- `dtype`: 数据类型，字符串形式（如`"float16"`）

**功能：**
申请shared memory内存，在Ascend中对应UB/L1上的内存。

**使用示例：**
```python
# 申请一个形状为(block_M, block_K)的FP16共享内存
A_shared = T.alloc_shared((block_M, block_K), "float16")

# 申请一个形状为(block_N,)的FP32共享内存
bias_shared = T.alloc_shared((block_N,), "float32")
```

**特殊限制：**
- 单个Kernel内所有Shared和Fragment内存总和严禁超过96KB
- 建议总内存控制在85KB以内

---

### T.alloc_ub / T.alloc_L1

**函数签名：**
```python
T.alloc_ub(shape, dtype)  # Expert mode
T.alloc_L1(shape, dtype)  # Expert mode
```

**功能：**
申请UB或L1内存（Expert模式）。

**说明：**
在当前的npuir后端中，`T.alloc_shared`、`T.alloc_ub`、`T.alloc_L1`和`T.alloc_fragment`全部映射到底层的Unified Buffer (UB)中，没有物理区别。

---

### T.alloc_fragment

**函数签名：**
```python
T.alloc_fragment(shape, dtype)
```

**功能：**
申请fragment内存，同样映射到UB。

**使用示例：**
```python
# 申请累加器fragment
C_local = T.alloc_fragment((block_M, block_N), "float32")
```

---

### T.copy

**函数签名：**
```python
T.copy(src, dst, size=None)
```

**参数说明：**
- `src`: 源tensor
- `dst`: 目标tensor
- `size`: 可选，指定拷贝的形状

**功能：**
在内存之间拷贝数据。

**使用示例：**
```python
# 从全局内存拷贝到共享内存
T.copy(A[by * block_M, k * block_K], A_shared)

# 带size参数的拷贝
T.copy(A[by * block_M, bx * block_N], A_shared, size=[block_M, block_N])
```

---

### T.clear

**函数签名：**
```python
T.clear(tensor)
```

**功能：**
清零tensor内存。

**使用示例：**
```python
dw_acc_ub = T.alloc_shared([num_heads, 1], "float32")
T.clear(dw_acc_ub)  # 清零
```

**注意事项：**
- NPU不支持`T.fill(tensor, 0)`，必须使用`T.clear(tensor)`

---

### T.atomic_add

**函数签名：**
```python
T.atomic_add(dst, src, size=None)
```

**参数说明：**
- `dst`: 目标tensor
- `src`: 源tensor或scalar
- `size`: 可选，指定原子操作的形状

**功能：**
原子加法操作。

**使用示例：**
```python
# 简单原子加
T.atomic_add(B[bx, by], A_VEC)

# 带size参数的原子加
T.atomic_add(B[bx, by], A_VEC, [tile_size_M, tile_size_N])
```

**注意事项：**
- NPU的原子操作需要显式指定数据大小（size参数）

---

## 数学操作

### T.vadd

**函数签名：**
```python
T.vadd(src0, src1, dst)
```

**功能：**
向量加法（逐元素相加）。

**使用示例：**
```python
T.vadd(A_shared, B_shared, C_shared)
```

---

### T.vsub

**函数签名：**
```python
T.vsub(src0, src1, dst)
```

**功能：**
向量减法（逐元素相减）。

**使用示例：**
```python
T.vsub(A_shared, B_shared, C_shared)
```

---

### T.vmul

**函数签名：**
```python
T.vmul(src0, src1, dst)
```

**功能：**
向量乘法（逐元素相乘）。

**使用示例：**
```python
T.vmul(A_shared, B_shared, C_shared)
```

---

### T.vdiv

**函数签名：**
```python
T.vdiv(src0, src1, dst)
```

**功能：**
向量除法（逐元素相除）。

**使用示例：**
```python
T.vdiv(A_shared, B_shared, C_shared)
```

---

### T.vrelu

**函数签名：**
```python
T.vrelu(src, dst)
```

**功能：**
ReLU激活函数（逐元素max(x, 0)）。

**使用示例：**
```python
T.vrelu(A_BUF, B_BUF)
```

**注意事项：**
- 推荐使用`T.vrelu`替代`T.vcmp`+`T.vselect`实现ReLU，避免Cube后Vector操作导致的卡死问题

---

### T.vexp

**函数签名：**
```python
T.vexp(src, dst)
```

**功能：**
指数函数（逐元素exp(x)）。

---

### T.vln

**函数签名：**
```python
T.vln(src, dst)
```

**功能：**
自然对数函数（逐元素ln(x)）。

---

### T.vsqrt

**函数签名：**
```python
T.vsqrt(src, dst)
```

**功能：**
平方根函数（逐元素sqrt(x)）。

---

### T.vsigmoid

**函数签名：**
```python
T.vsigmoid(src, dst)
```

**功能：**
Sigmoid激活函数。

---

### T.vtanh

**函数签名：**

```python
T.vtanh(src, dst)
```

**功能：**
Tanh激活函数。

---

### T.vsin / T.vcos

**函数签名：**
```python
T.vsin(src, dst)
T.vcos(src, dst)
```

**功能：**
正弦/余弦函数。

---

### T.vrsqrt

**函数签名：**
```python
T.vrsqrt(src, dst)
```

**功能：**
倒数平方根函数（逐元素1/sqrt(x)）。

---

### T.vrec

**函数签名：**
```python
T.vrec(src, dst)
```

**功能：**
倒数函数（逐元素1/x）。

---

### T.vpow

**函数签名：**
```python
T.vpow(src0, src1, dst)
```

**功能：**
幂函数（逐元素pow(src0, src1)）。

---

### T.vabs

**函数签名：**
```python
T.vabs(src, dst)
```

**功能：**
绝对值函数（逐元素abs(x)）。

---

### T.verf

**函数签名：**
```python
T.verf(src, dst)
```

**功能：**
误差函数（逐元素erf(x)）。

---

## 线性代数操作

### T.gemm

**函数签名：**
```python
T.gemm(src1, src2, dst, size=[], initC=False, a_transpose=False, b_transpose=False)
```

**参数说明：**
- `src1`: 输入tensor1（FP16）
- `src2`: 输入tensor2（FP16）
- `dst`: 输出tensor（FP32）
- `size`: 可选，指定矩阵形状
- `initC`: 是否对dst清零。`initC=True`表示`dst=src1@src2`；`initC=False`表示`dst=src1@src2+dst`
- `a_transpose`: 是否对src1进行转置
- `b_transpose`: 是否对src2进行转置

**功能：**
矩阵乘法运算。

**使用示例：**
```python
# 基本矩阵乘法
T.gemm(A_shared, B_shared, C_local, initC=True)

# 带转置的矩阵乘法
T.gemm(q_shared, k_shared, acc_s, initC=True, b_transpose=True)
```

**GPU到NPU参数映射：**
| GPU版本 | NPU版本 | 说明 |
|---------|---------|------|
| `clear_accum=True` | `initC=True` | 累加器初始化 |
| `clear_accum=False` | `initC=False` | 累加器累加 |
| `transpose_A=True` | `a_transpose=True` | A矩阵转置 |
| `transpose_B=True` | `b_transpose=True` | B矩阵转置 |
| `policy=...` | 无此参数 | NPU不支持显式策略 |

**注意事项：**
- Cube（GEMM）后立即使用Vector操作（如`T.vcmp`+`T.vselect`）会导致程序卡死
- 推荐使用`T.vrelu`替代`T.vcmp`+`T.vselect`实现ReLU

---

## 归约操作

### T.reduce_sum

**函数签名：**
```python
T.reduce_sum(buffer, out, dim=-1, clear=True)
```

**参数说明：**
- `buffer`: 输入tensor
- `out`: 输出tensor
- `dim`: 进行归约的维度，默认为-1（最后一个维度）
- `clear`: 是否在归约前清空输出tensor，默认为True。若为False，则在现有值上累加

**功能：**
在指定维度上进行求和归约。

**使用示例：**
```python
# 在最后一个维度上求和
T.reduce_sum(s_reshaped, logits, dim=-1, clear=True)

# 在第一维度上求和并累加
T.reduce_sum(acc_ub[i * heads : (i + 1) * heads, :], out_ub[i : i + 1, :], dim=0, clear=False)
```

---

### T.reduce_max

**函数签名：**
```python
T.reduce_max(buffer, out, dim=-1)
```

**功能：**
在指定维度上求最大值归约。

---

### T.reduce

**函数签名：**
```python
T.reduce(buffer, out, dim=-1, reduce_type="sum")
```

**功能：**
通用的归约操作。

---

## 比较操作

### T.vmax

**函数签名：**
```python
T.vmax(src0, src1, dst)
```

**功能：**
按向量元素取最大值。

**使用示例：**
```python
T.vmax(src0_ub, src1_ub, dst_ub)
```

**注意事项：**
- 在`T.Parallel`内，必须使用`T.vmax`替代`T.max`

---

### T.vmin

**函数签名：**
```python
T.vmin(src0, src1, dst)
```

**功能：**
按向量元素取最小值。

**使用示例：**
```python
T.vmin(src0_ub, src1_ub, dst_ub)
```

**注意事项：**
- 在`T.Parallel`内，必须使用`T.vmin`替代`T.min`

---

### T.vcmp

**函数签名：**
```python
T.vcmp(src0, src1, dst, cmp_op)
```

**参数说明：**
- `src0`: 输入tensor0
- `src1`: 输入tensor1
- `dst`: 输出tensor（bool类型）
- `cmp_op`: 比较操作符（"lt", "le", "gt", "ge", "eq", "ne"）

**功能：**
向量比较操作。

**使用示例：**
```python
T.vcmp(acc_A, acc_B, cond_ub, "ge")  # acc_A >= acc_B
```

**注意事项：**
- Cube（GEMM）后立即使用`T.vcmp`会导致程序卡死

---

### T.vclamp

**函数签名：**
```python
T.vclamp(src, min_val, max_val, dst)
```

**功能：**
将输入值限制在[min_val, max_val]范围内。

---

### T.min

**函数签名：**
```python
T.min(src0, src1)
```

**功能：**
标量最小值运算。

**注意事项：**
- 在`T.Parallel`内不支持，必须使用`T.vmin`

---

## 条件操作

### T.vselect

**函数签名：**
```python
T.vselect(Cond, A, B, Out)
```

**参数说明：**
- `Cond`: 条件Tensor（bool类型）
- `A`: 第一输入源，当条件为真时输出此对应位置的值
- `B`: 第二输入源，当条件为假时输出此对应位置的值
- `Out`: 输出Tensor

**功能：**
根据条件Tensor的布尔值，按元素从两个输入Tensor中选择值并输出。

**使用示例：**
```python
T.vselect(cond_ub, acc_A, acc_B, out_ub)
```

**注意事项：**
- Cube（GEMM）后立即使用`T.vselect`会导致程序卡死
- 在`T.Parallel`内，推荐使用`T.vselect`替代`T.if_then_else`

---

### T.if_then_else

**函数签名：**
```python
T.if_then_else(condition, true_value, false_value)
```

**功能：**
条件选择操作。

**注意事项：**
- 在`T.Parallel`内不支持直接使用循环变量作为判断条件（如`T.if_then_else(i>j, ...)`）

---

## 原子操作

### T.atomic_add

**函数签名：**
```python
T.atomic_add(dst, src, size=None)
```

**功能：**
原子加法操作。

**使用示例：**
```python
T.atomic_add(B[bx, by], A_VEC, [tile_size_M, tile_size_N])
```

**注意事项：**
- NPU的原子操作需要显式指定数据大小（size参数）
- 多Core对同一位置进行原子累加可能需要调整环境变量

---

### T.atomic_addx4

**函数签名：**
```python
T.atomic_addx4(dst, src, size=None)
```

**功能：**
4路并行原子加法操作。

---

## 编译器提示操作

### T.Kernel

**函数签名：**
```python
T.Kernel(blocks, threads=None, is_cpu=False, prelude=None, is_npu=False, pipeline=False)
```

**参数说明：**
- `blocks`: 网格各维度的extent，1~3维
- `threads`: 块内线程数（NPU内部管理）
- `is_cpu`: 是否为CPU kernel
- `prelude`: 在生成的内核代码前注入的C代码
- `is_npu`: 是否为NPU kernel
- `pipeline`: 流水线相关开关

**功能：**
定义内核启动域的上下文构造接口。

**使用示例：**
```python
# GPU版本
with T.Kernel(T.ceildiv(seq_len, block_Q), threads=512) as bx:
    ...

# NPU版本
with T.Kernel(num_q_blocks, is_npu=True) as (cid, _):
    ...
```

**NPU模式特殊限制：**
- 必须有且仅有1个block维度：`len(blocks) == 1`
- 返回的是前2个iter_var的变量（cid, vid），用于NPU的cube/vector索引

---

### T.Parallel

**函数签名：**
```python
T.Parallel(ub_0, ub_1, ..., ub_N)
```

**参数说明：**
- `ub_i`: 第i个循环的循环次数

**功能：**
实现并行语义，循环体内要求标量计算。

**使用示例：**
```python
for local_y, local_x in T.Parallel(block_M, block_N):
    C_local[local_y, local_x] = A_shared[local_y, local_x] + B_shared[local_y, local_x]
```

**支持的标量操作：**
- 数学运算：`+`, `-`, `*`, `/`
- 激活函数：`T.exp`, `T.sigmoid`
- 广播：`T.vbrc`
- 比较操作：`==`, `!=`, `<`, `<=`, `>`, `>=`
- 条件分支：`T.if_then_else`（不支持使用循环变量作为条件）

**特殊限制（高频踩坑点）：**
1. **严禁全局内存直达**：循环体内必须操作UB Buffer，不能直接操作GM Tensor
2. **严禁索引变换**：不支持任何索引偏移运算（如`A[i+1]`）
3. **极值函数替换**：使用`T.vmax`/`T.vmin`替代`T.max`/`T.min`
4. **条件分支限制**：不支持使用循环变量作为判断条件

---

### T.serial

**函数签名：**
```python
T.serial(n)
```

**功能：**
串行循环。

**使用示例：**
```python
for i in T.serial(block_Q):
    T.reduce_sum(...)
```

---

### T.Pipelined

**函数签名：**
```python
T.Pipelined(n, num_stages=2)
```

**功能：**
流水线循环，用于掩盖访存延迟。

**使用示例：**
```python
for k in T.Pipelined(T.ceildiv(K, block_K), num_stages=2):
    T.copy(A[by * block_M, k * block_K], A_shared)
    T.copy(B[k * block_K, bx * block_N], B_shared)
    T.gemm(A_shared, B_shared, C_local, initC=(k == 0))
```

---

## 数据类型转换操作

### T.vcast

**函数签名：**
```python
T.vcast(src, dst, round_mode='round')
```

**参数说明：**
- `src`: 源tensor
- `dst`: 目标tensor
- `round_mode`: 舍入模式（'round', 'floor', 'ceil'等）

**功能：**
数据类型转换。

**使用示例：**
```python
T.vcast(m_grad_ub, m_grad_f16_ub, round_mode='round')
```

---

### T.vbitcast

**函数签名：**
```python
T.vbitcast(src, dst)
```

**功能：**
比特级类型转换（不改变数据位，只改变解释方式）。

---

## 索引与元素操作

### T.gather

**函数签名：**
```python
T.gather(src, indices, dst)
```

**功能：**
根据索引从源tensor中收集数据。

**注意事项：**
- 在循环内Gather后直接GEMM会导致编译崩溃
- 建议在CPU端预完成Gather，确保传入Kernel的Tensor是连续的

---

### T.flip

**函数签名：**
```python
T.flip(src, dst, axis)
```

**功能：**
沿指定轴翻转tensor。

---

## Shape操作

### T.reshape

**函数签名：**
```python
T.reshape(src, dst, new_shape)
```

**功能：**
改变tensor的形状。

**注意事项：**
- 避免使用`T.reshape`，推荐使用偏移量计算实现逻辑上的reshape

---

### T.concat

**函数签名：**
```python
T.concat(inputs, dst, axis)
```

**功能：**
沿指定轴连接多个tensor。

---

### T.interleave

**函数签名：**
```python
T.interleave(src, dst)
```

**功能：**
交错排列tensor的元素。

---

### T.deinterleave

**函数签名：**
```python
T.deinterleave(src, dst)
```

**功能：**
解除交错排列。

---

### T.pad

**函数签名：**
```python
T.pad(src, dst, padding)
```

**功能：**
对tensor进行填充。

---

### T.vbrc

**函数签名：**
```python
T.vbrc(scalar, dst)
```

**功能：**
标量广播（将标量值广播到整个tensor）。

**使用示例：**
```python
zero = 0.0  # 必须先定义为变量
T.vbrc(zero, dw_acc_ub)  # 清零
```

**注意事项：**
- 严禁直接传入字面量浮点数（如`T.vbrc(0.0, dw_acc_ub)`）

---

### T.transpose

**函数签名：**
```python
T.transpose(src, dst, axes)
```

**功能：**
转置tensor。

---

## 创建操作

### T.arange

**函数签名：**
```python
T.arange(start, stop, step, dtype, dst)
```

**功能：**
创建等差数列。

---

### T.infinity

**函数签名：**
```python
T.infinity(dtype)
```

**功能：**
返回指定数据类型的无穷大值。

**使用示例：**
```python
neg_inf = -T.infinity("float32")
```

---

## 同步管道操作

### T.pipe_barrier

**函数签名：**
```python
T.pipe_barrier()
```

**功能：**
流水线屏障同步。

---

### T.set_flag

**函数签名：**
```python
T.set_flag(flag_id)
```

**功能：**
设置标志位。

---

### T.wait_flag

**函数签名：**
```python
T.wait_flag(flag_id)
```

**功能：**
等待标志位。

---

### T.sync_block_set

**函数签名：**
```python
T.sync_block_set(block_id)
```

**功能：**
同步块设置。

---

### T.sync_block_wait

**函数签名：**
```python
T.sync_block_wait(block_id)
```

**功能：**
同步块等待。

---

## 排序操作

### T.vcumsum

**函数签名：**
```python
T.vcumsum(src, dst)
```

**功能：**
向量累积求和。

---

## 逻辑操作

### T.vand

**函数签名：**
```python
T.vand(src0, src1, dst)
```

**功能：**
按位与运算。

---

### T.vor

**函数签名：**
```python
T.vor(src0, src1, dst)
```

**功能：**
按位或运算。

---

### T.vxor

**函数签名：**
```python
T.vxor(src0, src1, dst)
```

**功能：**
按位异或运算。

---

### T.vnot

**函数签名：**
```python
T.vnot(src, dst)
```

**功能：**
按位取反运算。

---

### T.vshl

**函数签名：**
```python
T.vshl(src, shift, dst)
```

**功能：**
左移运算。

---

### T.vshr

**函数签名：**
```python
T.vshr(src, shift, dst)
```

**功能：**
右移运算。

---

## 调试操作

### T.print

**函数签名：**
```python
T.print(*values)
```

**功能：**
打印调试信息。

---

## 内存操作（高级）

### T.alloc_L0C

**函数签名：**
```python
T.alloc_L0C(shape, dtype)
```

**功能：**
申请L0C内存（Expert模式）。

---

### T.load_nd2nz

**函数签名：**
```python
T.load_nd2nz(src, dst)
```

**功能：**
从ND格式加载到NZ格式。

---

### T.store_fixpipe

**函数签名：**
```python
T.store_fixpipe(src, dst)
```

**功能：**
固定流水线存储。

---

## 数学操作（高级）

### T.ceildiv

**函数签名：**
```python
T.ceildiv(a, b)
```

**功能：**
向上取整除法。

**使用示例：**
```python
num_blocks = T.ceildiv(seq_len, block_Q)
```

---

## 总结

### 核心API分类

1. **内存管理**：`T.alloc_shared`, `T.alloc_fragment`, `T.copy`, `T.clear`
2. **数学运算**：`T.vadd`, `T.vmul`, `T.vrelu`, `T.vexp`等
3. **矩阵运算**：`T.gemm`
4. **归约操作**：`T.reduce_sum`, `T.reduce_max`
5. **比较操作**：`T.vmax`, `T.vmin`, `T.vcmp`
6. **条件操作**：`T.vselect`, `T.if_then_else`
7. **原子操作**：`T.atomic_add`
8. **控制流**：`T.Kernel`, `T.Parallel`, `T.serial`, `T.Pipelined`

### GPU到NPU API映射要点

1. **数据类型**：类型对象 → 字符串（`T.bfloat16` → `"float16"`）
2. **动态Shape**：`T.dynamic` → `T.symbolic`
3. **GEMM参数**：`clear_accum` → `initC`，`transpose_A` → `a_transpose`
4. **极值函数**：`T.max`/`T.min` → `T.vmax`/`T.vmin`（在`T.Parallel`内）
5. **内存清零**：`T.fill` → `T.clear`
6. **Kernel声明**：添加`is_npu=True`参数

---

**文档版本：** 1.0
**最后更新：** 2026-03-23
**适用平台：** 华为昇腾910B NPU + TileLang npuir后端
