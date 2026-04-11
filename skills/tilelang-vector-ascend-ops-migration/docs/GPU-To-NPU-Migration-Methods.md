# GPU-To-NPU-Migration-Methods

## 概述

本文档基于TileLang算子的实际迁移案例，结合华为昇腾NPU的硬件架构特性，系统总结了从GPU（CUDA）到NPU的迁移方法、关键差异、硬件约束和最佳实践。

**对比分析案例：**
- `tilelang_indexer_fwd.py` vs `index_fwd_dev.py`（前向传播算子）
- `tilelang_indexer_bwd.py` vs `index_bwd_dev.py`（反向传播算子）

**适用场景：**
- TileLang算子从CUDA平台迁移到昇腾NPU平台
- 需要理解NPU硬件约束的开发者
- 追求NPU性能优化的工程师

---

## 一、NPU硬件架构与核心约束

### 1.1 DaVinci架构三大引擎

昇腾NPU的核心计算由三大引擎协同完成：

| 引擎 | 功能 | 特点 |
|------|------|------|
| **Scalar** | 标量计算和控制流 | 处理逻辑判断、循环控制 |
| **MTE** | 内存搬运引擎 | 负责数据在GM、UB、Cube之间的搬运 |
| **Vector/Cube** | 向量/矩阵计算 | Vector处理逐元素操作，Cube处理矩阵乘法 |

### 1.2 统一缓冲区（UB/L1）硬约束

#### 内存映射规则
在当前的npuir后端中，TileLang的内存分配有统一映射：
- `T.alloc_shared()` → 自动映射到Unified Buffer (UB)、L1
- `T.alloc_fragment()` → **同样**映射到Unified Buffer (UB)、L1
- **注意**: 两者没有物理区别，均会自动映射

#### 容量限制（910B芯片）

| 指标 | 数值 | 说明 |
|------|------|------|
| **UB总容量** | 192 KB | 硬件物理容量 |
| **Double Buffering** | 必须开启 | 硬件默认需求，用于掩盖访存延迟 |
| **硬约束上限** | 96 KB | 单Kernel内所有Shared+Fragment总和**严禁超过** |
| **建议安全值** | 85 KB | 预留临时变量空间，避免溢出 |

**内存计算示例：**
```python
# ❌ 危险：可能超过96KB限制
q_shared = T.alloc_shared([512, 128], "float16")      # 128 KB
k_shared = T.alloc_shared([512, 128], "float16")      # 128 KB
# 总计：256 KB > 96 KB ❌

# ✅ 安全：控制在85KB以内
q_shared = T.alloc_shared([64, 128], "float16")       # 16 KB
k_shared = T.alloc_shared([64, 128], "float16")       # 16 KB
acc_ub = T.alloc_shared([64, 64], "float32")          # 16 KB
# 总计：48 KB < 85 KB ✅
```

### 1.3 数据对齐与连续性要求

#### 内存连续性
**强制要求**：传入的PyTorch/MindSpore Tensor必须连续
```python
# ❌ 错误：非连续Tensor会导致严重性能劣化
q = q.transpose(0, 1)  # 可能产生非连续内存
kernel(q, ...)

# ✅ 正确：确保内存连续
q = q.transpose(0, 1).contiguous()
kernel(q, ...)
```

#### 32 Bytes对齐要求
MTE数据搬运指令以32 Bytes为基础块，设计block_size或head_dim时必须满足对齐：

| 数据类型 | 单元素字节数 | 建议维度倍数 |
|----------|-------------|-------------|
| FP16/BF16 | 2 Bytes | 16的倍数（32字节对齐） |
| FP32 | 4 Bytes | 8的倍数（32字节对齐） |
| INT32 | 4 Bytes | 8的倍数（32字节对齐） |

```python
# ❌ 错误：未对齐
head_dim = 127  # 127 * 2 = 254 Bytes，不是32的倍数

# ✅ 正确：对齐
head_dim = 128  # 128 * 2 = 256 Bytes，是32的倍数 ✅
block_size = 64 # 64 * 2 = 128 Bytes，是32的倍数 ✅
```

---

## 二、TileLang API昇腾适配指南

### 2.1 基础声明约束

#### Target指定
```python
# GPU版本（默认CUDA）
@tilelang.jit(
    pass_configs={
        tilelang.PassConfigKey.TL_ENABLE_FAST_MATH: True,
    },
)
def kernel_func(...):
    ...

# NPU版本（必须显式声明）
os.environ['TILELANG_ASCEND_MODE'] = 'Developer'  # 必须设置

@tilelang.jit(target="npuir")
def kernel_func(...):
    ...
```

#### 动态Shape处理
```python
# ❌ GPU版本：使用T.dynamic
seq_len = T.dynamic("seq_len")

# ✅ NPU版本：必须使用T.symbolic
seq_len = T.symbolic("seq_len")
```

#### Kernel声明差异
```python
# GPU版本
with T.Kernel(T.ceildiv(seq_len, block_Q), threads=512) as bx:
    tx = T.thread_binding(0, 512, thread="threadIdx.x")

# NPU版本
with T.Kernel(num_q_blocks, is_npu=True) as (cid, _):
    # cid: core ID, NPU内部管理线程
```

### 2.2 内存清零与初始化

#### 禁用T.fill
```python
# ❌ 错误：NPU不支持T.fill
T.fill(tensor, 0.0)
```

#### 推荐方案1：使用T.clear
```python
# ✅ 推荐：使用专门的清零接口
dw_acc_ub = T.alloc_shared([num_heads, 1], "float32")
T.clear(dw_acc_ub)
```

#### 推荐方案2：使用T.vbrc（向量广播）
```python
# ❌ 错误：严禁直接传入字面量浮点数
T.vbrc(0.0, dw_acc_ub)

# ✅ 正确：先定义变量再广播
zero = 0.0
T.vbrc(zero, dw_acc_ub)
```

### 2.3 并行与规约（Parallel & Reduce）

#### T.Parallel约束（高频踩坑点）

##### 严禁全局内存直达
```python
# ❌ 错误：直接操作GM Tensor
for i in T.Parallel(128):
    output[i] = input[i] + 1  # input/output是GM Tensor

# ✅ 正确：必须使用UB Buffer
input_ub = T.alloc_shared([128], "float16")
output_ub = T.alloc_shared([128], "float16")
T.copy(input[0], input_ub)
for i in T.Parallel(128):
    output_ub[i] = input_ub[i] + 1
T.copy(output_ub, output[0])
```

##### 严禁索引变换
```python
# ❌ 错误：不支持任何索引偏移运算
for i in T.Parallel(128):
    C[i] = A[i+1]  # 不支持 +, -, * 等索引运算

# ✅ 正确：使用纯净索引
for i in T.Parallel(127):
    C[i] = A[i+1]  # 调整循环范围
```

##### 标量操作白名单
T.Parallel循环体内仅支持以下操作：
- 数学运算：`+`, `-`, `*`, `/`
- 激活函数：`T.exp`, `T.sigmoid`
- 比较操作：`==`, `<`, `>`, `<=`, `>=`, `!=`
- 广播操作：`T.vbrc`
- 向量选择：`T.vselect`

##### 极值函数替换
```python
# ❌ 错误：T.Parallel内不支持T.max/T.min
for i in T.Parallel(128):
    output[i] = T.max(input[i], 0)

# ✅ 正确：使用向量指令T.vmax/T.vmin
for i in T.Parallel(128):
    output_ub[i] = T.vmax(input_ub[i], 0)
```

##### 条件分支限制
```python
# ❌ 错误：不支持使用循环变量作为判断条件
for i, j in T.Parallel(64, 64):
    if i > j:  # 使用循环变量会报错
        output[i, j] = 1

# ✅ 正确：使用T.vselect或掩码乘法
for i, j in T.Parallel(64, 64):
    mask = (i > j)
    output[i, j] = T.vselect(mask, 1, 0)
```

#### Reduce降维限制
NPU的`T.reduce_sum`行为与社区版存在差异：
- 必须严格检查输入与输出Tensor的Rank（维度数）是否匹配
- 建议显式指定reduce维度

```python
# GPU版本
T.reduce_sum(s_reshaped, logits, dim=-1, clear=True)

# NPU版本（更明确）
for i in T.serial(block_Q):
    T.reduce_sum(
        acc_ub[i * heads : (i + 1) * heads, :],
        out_ub[i : i + 1, :],
        dim=0,
        clear=True
    )
```

### 2.4 数据类型差异

| 数据类型 | GPU版本 | NPU版本 |
|----------|---------|---------|
| **浮点类型** | `T.bfloat16`, `T.float32` | `"float16"`, `"float32"` |
| **整数类型** | `T.int32` | `"int32"` |

```python
# GPU版本
dtype = T.bfloat16
accum_dtype = T.float32
index_dtype = T.int32

# NPU版本
dtype = "float16"        # bfloat16可能需要转换为float16
accum_dtype = "float32"
index_dtype = "int32"
```

---

## 三、计算逻辑优化与API映射

### 3.1 矩阵乘法（GEMM）

| 参数 | GPU版本 | NPU版本 |
|------|---------|---------|
| **函数名** | `T.gemm()` | `T.gemm()` |
| **初始化** | `clear_accum=True/False` | `initC=True/False` |
| **转置标记** | `transpose_A/B=True` | `a_transpose/b_transpose=True` |
| **策略** | `policy=T.GemmWarpPolicy.FullCol` | 无显式策略 |

**代码对比：**
```python
# GPU版本
T.gemm(
    index_k_shared,
    index_q_shared,
    s,
    transpose_B=True,
    clear_accum=True,
    policy=T.GemmWarpPolicy.FullCol,
)

# NPU版本
T.gemm(q_shared, k_shared, acc_s, initC=True, b_transpose=True)
```

### 3.2 激活函数与元素操作

#### 向量化指令优先
```python
# GPU版本（循环并行）
for bn_i, bq_i, h_i in T.Parallel(block_N, block_Q, heads):
    s_reshaped[bn_i, bq_i, h_i] = T.max(s_reshaped[bn_i, bq_i, h_i], 0) * weights[bq_i, h_i]

# NPU版本（向量化）
T.copy(acc_s, acc_ub)
T.vrelu(acc_ub, acc_ub)         # 向量化ReLU
T.vmul(acc_ub, w_shared, acc_ub) # 向量化乘法
```

#### 掩码实现技巧
```python
# NPU版本：使用数学技巧实现条件判断
# 将条件判断转换为数学运算
T.vmul(logits_ub, 100000000.0, mask_ub)
T.vmin(mask_ub, 1.0, mask_ub)  # 大于0的变为1，否则为0
T.vmul(m_grad_ub, mask_ub, m_grad_ub)
```

### 3.3 原子操作

```python
# GPU版本（自动推断大小）
for i, j in T.Parallel(block_I, dim):
    if indices_shared[i] > -1 and indices_shared[i] < seq_len:
        T.atomic_add(dIndexK[indices_shared[i], j], d_index_k_frag[i, j])

# NPU版本（显式指定大小）
for j in T.serial(block_top_k):
    target_k_idx = idx_shared[j]
    T.atomic_add(dIndexK[target_k_idx, 0], dk_temp_ub[j, 0], [head_dim])
```

**迁移要点：**
- NPU的原子操作需要显式指定数据大小（`[head_dim]`）
- GPU使用`if`条件判断，NPU通常在预计算时处理边界

---

## 四、已知BUG与避坑策略

由于NPU IR编译器仍在快速迭代，部分特定指令组合会触发底层编译器Bug，开发时需要尽量绕行。

### ❌ 坑1：矩阵乘（Cube）搭配Gather访存导致崩溃

**现象：**
在循环内从Global Memory根据索引Gather数据到Shared Memory后，直接喂给`T.gemm`进行Cube运算，会导致编译报错或非法指令。

**错误示例：**
```python
for i in T.serial(num_blocks):
    idx = indices[i]
    T.copy(GlobalMemory[idx, 0], shared_mem)  # Gather
    T.gemm(shared_mem, ..., output, ...)     # 直接使用Gather结果 → 崩溃
```

**绕过策略：**
分离逻辑。尽量在进入Kernel前通过PyTorch/外部算子完成离散数据的Gather，保证传入Kernel的Tensor是内存连续的，再进行Gemm。

```python
# ✅ 正确：在CPU端预完成Gather
indices = indices.cpu()
gathered_data = original_tensor[indices]  # PyTorch完成Gather
kernel(gathered_data.contiguous(), ...)  # 传入连续Tensor
```

### ❌ 坑2：矩阵计算（Cube）与向量比较（Vector）串联导致卡死

**现象：**
`T.gemm`计算结果存入Fragment/Shared后，立刻对其使用`T.vcmp`和`T.vselect`（如实现ReLU），算子会直接卡死。纯Vector算子不卡。这是典型的Cube/Vector同步栅栏（Barrier）丢失导致的死锁。

**错误示例：**
```python
T.gemm(A, B, C, ...)
T.vcmp(C, 0, mask)      # Cube后立即Vector操作
T.vselect(mask, C, 0, D)  # → 卡死
```

**绕过策略：**
1. 使用基础的`T.vrelu`或`T.vmax`替代`T.vcmp+T.vselect`的组合
2. 或在Gemm后强行加一个极小开销的标量操作来打破调度器的错误融合

```python
# ✅ 方案1：使用T.vrelu
T.gemm(A, B, C, ...)
T.vrelu(C, C)  # 直接使用向量化ReLU

# ✅ 方案2：添加标量操作打破融合
T.gemm(A, B, C, ...)
dummy = T.alloc_var("float32")
dummy = 0.0  # 标量操作
T.vcmp(C, 0, mask)
```

### ❌ 坑3：标量广播（mul）+ Reshape报错

**现象：**
对Tensor进行`T.vmul`（带标量广播机制）后，紧接着使用`T.npuir_reshape`，会触发SSA Inplace相关的编译崩溃。

**错误示例：**
```python
T.vmul(A, 2.0, B)  # 标量广播
T.npuir_reshape(B, [new_shape])  # → 崩溃
```

**绕过策略：**
算子实现时彻底规避`T.reshape`，通过多维指针的Offset计算直接实现逻辑上的Reshape。
**注意：**
没有使用标量广播时可以正常使用reshape
```python
# ✅ 正确：使用偏移量计算
# 不用reshape，直接用偏移量访问
for i in T.serial(block_size):
    for j in T.serial(head_dim):
        offset = i * original_dim + j
        output[i, j] = input[offset]
```

### ❌ 坑4：多核T.atomic_add报错/数据异常

**现象：**
当Block/Core数量开到32或更大时，多个Core对Global Memory的同一个位置进行原子累加会报错或数据错误。

**原因：**
Workspace覆盖导致的。

**绕过策略：**
1. 在Python环境变量中注释或删除`TILELANG_ASCEND_WORKSPACE_SIZE`，让系统走默认调度逻辑
2. 尽量在L1/UB中完成内部Reduce，最后只做一次全局的Atomic Add

```python
# ❌ 错误：环境变量设置
os.environ['TILELANG_ASCEND_WORKSPACE_SIZE'] = '1073741824'  # 可能导致覆盖

# ✅ 正确：注释或删除环境变量
# os.environ['TILELANG_ASCEND_WORKSPACE_SIZE'] = '1073741824'

# ✅ 策略：UB内聚合Reduce
# 先在UB内完成聚合
for i in T.serial(block_top_k):
    T.reduce_sum(local_buffer[i], ub_accum, dim=0)
# 最后只做一次全局Atomic Add
T.atomic_add(global_output, ub_accum, [size])
```

### ❌ 坑5：CV分核Bug

**现象：**
NPU编译器在某些情况下需要显式操作来触发优化。

**解决方案：**
```python
# 添加无意义的add操作触发优化
T.vadd(k_shared, T.cast(0.0, dtype), k_shared)
```

---

## 五、内存管理与数据流优化

### 5.1 内存分配策略对比

#### GPU版本（动态计算）
```python
# tilelang_indexer_fwd.py
with T.Kernel(T.ceildiv(seq_len, block_Q), threads=threads) as bx:
    # 动态计算cu_k_s_min和cu_k_e_max
    cu_k_s_min = T.alloc_var(index_dtype)
    cu_k_e_max = T.alloc_var(index_dtype)
    cu_k_s_min = 2147483647
    cu_k_e_max = -2147483648

    for bq_i in T.serial(block_Q):
        cu_k_s_min = T.min(cu_k_s_min, T.min(CuSeqLenKS[seq_len_i + bq_i], seq_len_kv))
```

#### NPU版本（预计算元数据）
```python
# index_fwd_dev.py
def prepare_metadata(ks, ke, seq_len, block_Q, block_N, device):
    """CPU端预计算每一行对应的Key Block范围"""
    metadata = torch.zeros((num_q_blocks, 2), dtype=torch.int32, device="cpu")
    for i in range(num_q_blocks):
        min_k_s = curr_ks.min().item()
        max_k_e = curr_ke.max().item()
        metadata[i, 0] = start_k_blk
        metadata[i, 1] = max(0, end_k_blk - start_k_blk)
    return metadata.to(device), num_q_blocks

# Kernel中使用元数据
start_block_k = Metadata[cid, 0]
num_blocks_k = Metadata[cid, 1]
```

**优化经验：**
- **GPU**: 依赖动态计算，在Kernel内实时确定数据范围
- **NPU**: 将计算逻辑移至CPU端预计算，减少Kernel内分支判断
- **好处**: 降低Kernel复杂度，提高NPU执行效率

### 5.2 共享内存使用差异

| 特性 | GPU版本 | NPU版本 |
|------|---------|---------|
| **分配方式** | `T.alloc_shared()` | `T.alloc_shared()` |
| **数据布局** | 多维重塑 | 保持扁平化布局 |
| **同步机制** | `T.sync_threads()` | 显式同步 + 零初始化 |

**NPU特殊处理：**
```python
# NPU需要显式清零
dw_acc_ub = T.alloc_shared([num_heads, 1], accum_dtype)
T.clear(dw_acc_ub)

# NPU的add操作修复bug
T.vadd(k_shared, T.cast(0.0, dtype), k_shared)  # cv分核bug修复
```

---

## 六、数据预处理与后处理

### 6.1 前向传播：掩码处理

#### GPU版本（两阶段处理）
```python
# 阶段1: 计算所有logits
tl_indexer_fwd_kernel(q, kv, logits, weights, cu_seqlen_ks, cu_seqlen_ke)

# 阶段2: 单独Kernel清理无效区域
if clean_logits:
    clean_logits_kernel(logits, cu_seqlen_ks, cu_seqlen_ke)
```

#### NPU版本（内联处理）
```python
# 在计算过程中直接设置无效区域为-inf
for i in T.serial(block_Q):
    s_idx = s_start + i
    if s_idx < seq_len:
        ks_val = CuSeqLenKS[s_idx]
        ke_val = CuSeqLenKE[s_idx]
        for j in T.serial(block_N):
            k_idx = curr_k_offset + j
            if k_idx < ks_val or k_idx >= ke_val:
                out_ub[i, j] = -T.infinity(accum_dtype)
```

**优化经验：**
- **GPU**: 分离计算和清理，利于流水线优化
- **NPU**: 合并到主Kernel，减少启动开销
- **内存初始化**: NPU输出buffer预先填充`-inf`

### 6.2 反向传播：Gather操作

#### GPU版本（条件加载）
```python
for i, j in T.Parallel(block_I, dim):
    index_k_shared[i, j] = T.if_then_else(
        indices_shared[i] > -1 and indices_shared[i] < seq_len,
        IndexK[indices_shared[i], j],
        0
    )
```

#### NPU版本（循环加载）
```python
T.copy(Indices[batch_idx, offset], idx_shared, size=[block_top_k])
for j in T.serial(block_top_k):
    curr_k_idx = idx_shared[j]
    T.copy(IndexK[curr_k_idx, 0], k_shared[j, 0], size=[head_dim])
```

**迁移要点：**
- NPU使用显式循环加载，避免条件分支
- 边界检查在预计算阶段完成

---

## 七、性能优化建议

### 7.1 数据布局优化

| 优化点 | GPU | NPU |
|--------|-----|-----|
| **内存访问** | Coalesced访问 | 连续块访问 |
| **数据预取** | 自动预取 | 手动预取 |
| **Shared Memory** | Bank冲突优化 | 避免bank冲突 |

### 7.2 Kernel融合

- **GPU**: 适合小Kernel融合
- **NPU**: 减少Kernel启动次数，尽可能合并操作

### 7.3 预计算策略

- **GPU**: 动态计算，适应性强
- **NPU**: CPU端预计算元数据，减少Kernel复杂度

### 7.4 内存分配优化

```python
# ✅ 优化：合理规划UB内存使用
# 计算总内存占用
q_shared = T.alloc_shared([block_Q * heads, index_dim], "float16")  # block_Q*heads*index_dim*2 Bytes
k_shared = T.alloc_shared([block_N, index_dim], "float16")           # block_N*index_dim*2 Bytes
acc_ub = T.alloc_shared([block_Q * heads, block_N], "float32")       # block_Q*heads*block_N*4 Bytes

# 确保总和 < 85 KB
total_bytes = block_Q * heads * index_dim * 2 + block_N * index_dim * 2 + block_Q * heads * block_N * 4
assert total_bytes < 85 * 1024, "UB内存超出安全限制"
```

---

## 八、迁移检查清单

### 8.1 环境配置检查

- [ ] 设置环境变量 `TILELANG_ASCEND_MODE='Developer'`
- [ ] 添加 `target="npuir"` 到 `@tilelang.jit` 装饰器
- [ ] 检查并注释 `TILELANG_ASCEND_WORKSPACE_SIZE` 环境变量（如有）
- [ ] 修改Kernel声明为 `with T.Kernel(..., is_npu=True)`

### 8.2 数据类型检查

- [ ] 将 `T.bfloat16` 改为 `"float16"`（如需要）
- [ ] 将 `T.float32` 改为 `"float32"`
- [ ] 将 `T.int32` 改为 `"int32"`
- [ ] 将 `T.dynamic(...)` 改为 `T.symbolic(...)`

### 8.3 内存约束检查

- [ ] 计算所有`T.alloc_shared()`和`T.alloc_fragment()`的总内存
- [ ] 确保总内存 < 96 KB（硬约束）
- [ ] 建议总内存 < 85 KB（安全值）
- [ ] 检查block_size和head_dim是否满足32 Bytes对齐
- [ ] 确保所有输入Tensor调用`.contiguous()`

### 8.4 内存操作检查

- [ ] 将所有`T.fill(tensor, 0)`替换为`T.clear(tensor)`
- [ ] 检查`T.vbrc()`是否使用了字面量，改为变量
- [ ] 添加必要的`T.clear()`初始化
- [ ] 检查`T.atomic_add()`是否需要显式大小参数
- [ ] 避免在`T.Parallel`内直接操作GM Tensor

### 8.5 计算逻辑检查

- [ ] 替换`T.gemm()`参数名（`clear_accum` → `initC`）
- [ ] 替换转置参数（`transpose_A` → `a_transpose`）
- [ ] 将`T.Parallel`内的`T.max`/`T.min`替换为`T.vmax`/`T.vmin`
- [ ] 使用向量化指令替代循环并行
- [ ] 检查掩码逻辑是否需要数学转换
- [ ] 避免`T.Parallel`内的索引变换（如`A[i+1]`）
- [ ] 检查`T.Parallel`内的条件判断，使用`T.vselect`替代

### 8.6 已知BUG规避检查

- [ ] 避免Cube（GEMM）后立即使用Vector（vcmp+vselect）
- [ ] 避免在循环内Gather后直接GEMM
- [ ] 避免标量广播后立即Reshape
- [ ] 检查多核Atomic Add是否需要调整
- [ ] 必要时添加CV分核Bug修复代码

### 8.7 性能优化检查

- [ ] 评估是否需要预计算元数据
- [ ] 检查是否可以合并Kernel
- [ ] 验证内存访问模式是否最优
- [ ] 使用NPU性能分析工具定位瓶颈

---

## 九、核心差异总结

| 维度 | GPU | NPU |
|------|-----|-----|
| **编程模型** | 动态灵活 | 静态优化 |
| **并行策略** | 多维度并行（T.Parallel） | 向量化优先，T.Parallel受限 |
| **内存管理** | 动态计算 | 预计算元数据 |
| **内存限制** | 相对宽松 | 严格（UB < 96KB） |
| **指令集** | CUDA指令 | DaVinci向量/矩阵指令 |
| **数据类型** | 类型对象（T.bfloat16） | 字符串（"float16"） |
| **调试难度** | 相对简单 | 需要NPU特定知识 |
| **编译器成熟度** | 成熟稳定 | 快速迭代，存在已知BUG |

---

## 十、迁移关键点与最佳实践

### 10.1 迁移关键点

1. **环境配置**：正确设置NPU目标平台和开发模式
2. **类型转换**：使用字符串形式的数据类型
3. **内存约束**：严格遵守UB内存限制（<96KB）
4. **数据对齐**：确保32 Bytes对齐和内存连续性
5. **内存优化**：预计算元数据，减少Kernel内分支
6. **计算优化**：使用向量化指令，避免条件分支
7. **API适配**：严格遵守TileLang NPU API映射规则
8. **BUG规避**：绕过已知编译器BUG

### 10.2 最佳实践

1. **渐进式迁移**：
   - 先迁移核心逻辑，保证正确性
   - 再进行性能优化
   - 逐步调整参数和算法

2. **充分测试**：
   - 使用参考实现验证正确性
   - 进行边界测试和压力测试
   - 对比GPU和NPU的数值精度

3. **性能分析**：
   - 使用NPU性能分析工具定位瓶颈
   - 分析内存访问模式
   - 优化数据布局和计算流程

4. **文档记录**：
   - 记录迁移过程中的问题和解决方案
   - 整理性能优化经验
   - 建立团队知识库

5. **代码审查**：
   - 重点检查内存分配和T.Parallel使用
   - 验证是否规避了已知BUG
   - 确保符合NPU硬件约束

### 10.3 常见错误模式

| 错误模式 | 症状 | 解决方案 |
|----------|------|----------|
| UB内存溢出 | 编译报错或运行时崩溃 | 减小block_size或使用更少buffer |
| 数据未对齐 | 性能严重劣化 | 调整维度为16/8的倍数 |
| T.Parallel使用GM | 编译报错 | 先copy到UB再操作 |
| Cube后Vector操作 | 程序卡死 | 使用T.vrelu或添加标量操作 |
| Gather后GEMM | 编译失败 | 在CPU端预完成Gather |
| 标量广播+Reshape | 编译崩溃 | 使用偏移量计算替代Reshape |

---

## 十一、参考资源

### 官方文档
- TileLang官方文档：https://github.com/tile-ai/tilelang
- 华为昇腾NPU开发指南
- CANN开发工具链文档

### 相关资源
- CUDA编程最佳实践
- Triton GPU到NPU迁移参考
- DaVinci架构白皮书

### 社区资源
- 昇腾开发者社区
- TileLang GitHub Issues
- 相关技术博客和论文

---

## 附录A：快速迁移模板

```python
# NPU TileLang算子模板
import os
import torch
import tilelang
import tilelang.language as T

# 环境配置
os.environ['TILELANG_ASCEND_MODE'] = 'Developer'

# 数据类型定义
FP16 = "float16"
FP32 = "float32"
INT32 = "int32"

@tilelang.jit(target="npuir")
def npu_kernel(
    param1: int,
    param2: int,
    block_size: int = 64,
):
    # 参数定义
    seq_len = T.symbolic("seq_len")
    dtype = FP16
    accum_dtype = FP32

    @T.prim_func
    def kernel_impl(
        Input: T.Tensor([seq_len, param1], dtype),
        Output: T.Tensor([seq_len, param2], accum_dtype),
    ):
        # 计算block数量
        num_blocks = T.ceildiv(seq_len, block_size)

        with T.Kernel(num_blocks, is_npu=True) as (cid, _):
            # 1. 内存分配（注意UB限制）
            input_ub = T.alloc_shared([block_size, param1], dtype)
            output_ub = T.alloc_shared([block_size, param2], accum_dtype)

            # 2. 加载数据
            start_idx = cid * block_size
            T.copy(Input[start_idx, 0], input_ub, size=[block_size, param1])

            # 3. 计算逻辑（使用向量化指令）
            T.vmul(input_ub, 2.0, output_ub)  # 示例：向量化乘法

            # 4. 写回结果
            if start_idx < seq_len:
                T.copy(output_ub, Output[start_idx, 0], size=[block_size, param2])

    return kernel_impl

# 使用示例
def wrapper(input_tensor):
    seq_len, param1 = input_tensor.shape
    param2 = param1  # 示例参数

    # 确保内存连续
    input_tensor = input_tensor.contiguous()

    # 初始化输出
    output_tensor = torch.empty([seq_len, param2],
                                device=input_tensor.device,
                                dtype=torch.float32)

    # 调用kernel
    kernel = npu_kernel(param1, param2)
    kernel(input_tensor, output_tensor)

    return output_tensor
```

---

## 附录B：内存计算工具

```python
def calculate_ub_memory(allocations):
    """
    计算UB内存占用

    allocations: list of tuples (shape, dtype)
    dtype: "float16" | "float32" | "int32"
    """
    dtype_bytes = {
        "float16": 2,
        "float32": 4,
        "int32": 4,
    }

    total_bytes = 0
    details = []

    for shape, dtype in allocations:
        size = 1
        for dim in shape:
            size *= dim
        bytes_used = size * dtype_bytes[dtype]
        total_bytes += bytes_used
        details.append({
            "shape": shape,
            "dtype": dtype,
            "size": size,
            "bytes": bytes_used,
            "kb": bytes_used / 1024
        })

    print("UB内存分配详情：")
    for detail in details:
        print(f"  Shape: {detail['shape']}, Dtype: {detail['dtype']}, "
              f"Size: {detail['size']}, Bytes: {detail['bytes']}, "
              f"KB: {detail['kb']:.2f}")

    print(f"\n总计: {total_bytes} Bytes ({total_bytes/1024:.2f} KB)")
    print(f"硬约束: 96 KB")
    print(f"建议值: 85 KB")

    if total_bytes > 96 * 1024:
        print("❌ 超过硬约束！")
    elif total_bytes > 85 * 1024:
        print("⚠️  超过建议值，可能存在风险")
    else:
        print("✅ 在安全范围内")

    return total_bytes

# 使用示例
allocations = [
    ([64, 128], "float16"),
    ([64, 128], "float16"),
    ([64, 64], "float32"),
]
calculate_ub_memory(allocations)
```

---

**文档版本：** 2.0
**最后更新：** 2026-03-23
**作者：** 基于实际迁移经验 + 硬件约束文档整合
**适用平台：** 华为昇腾910B NPU + TileLang npuir后端
