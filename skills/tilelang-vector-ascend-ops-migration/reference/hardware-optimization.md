# NPU硬件特性与性能优化

## NPU硬件架构

### 片上缓存层次

昇腾NPU的AI Core包含两级关键缓存：

| 缓存类型 | 所属单元 | 容量 | 用途 |
|---------|---------|------|------|
| **统一缓冲区（UB）** | Vector核私有 | 192KB | 向量运算的临时存储 |
| **一级缓存（L1）** | Cube核私有 | 512KB（A2系列） | 矩阵运算的临时存储 |
| **全局内存（GM）** | 共享 | 32GB+ | 主存储，延迟高 |

### 物理核数限制

- **Cube核**：约20~24个（A2系列）
- **Vector核**：Cube核数量的2倍
- 超出物理核数的逻辑内核会被串行调度

## 核心优化原则

### 1. Tiling策略：最大化分块尺寸

**原则：** 在缓存不超限的前提下，尽可能增大分块尺寸。

**好处：**
- 提高数据复用率
- 减少循环迭代次数
- 增加计算密度，隐藏内存延迟

**示例（矩阵乘法）：**
```python
# 单个kernel需要加载：
# A分块: block_M × block_K
# B分块: block_K × block_N
# 总内存 = (block_M × block_K + block_K × block_N) × dtype_bytes < L1容量
```

### 2. 数据对齐要求

NPU加载指令要求数据地址按**32字节**对齐。

**对齐规则：**
- `float16`：最后一维必须是**16的倍数**
- `float32`：最后一维必须是**8的倍数**
- `int8`：最后一维必须是**32的倍数**

**不对齐的后果：**
- 编译器自动填充，浪费缓存和带宽
- 极端情况（如尾轴为1）性能急剧下降

**示例：**
```python
# ✅ 对齐良好
block_M = 64  # 16的倍数
block_N = 64  # 16的倍数
block_K = 32  # 16的倍数

# ❌ 对齐不佳
block_K = 15  # 会被填充到16，浪费6.7%
```

### 3. 存算并行与流水线深度

NPU支持数据搬运与计算重叠，通过 `T.Pipelined` 实现。

**流水线效率要求：**
- 循环迭代次数至少为 **4~6次**
- 迭代次数过少（2~3次）流水线无法充分填满
- 流水线会额外占用片上缓存（乒乓缓冲）

**示例：**
```python
# K维分块迭代次数
num_iterations = T.ceildiv(K, block_K)

# ✅ 良好：K=1024, block_K=128 → 8次迭代
# ⚠️ 不佳：K=256, block_K=128 → 2次迭代
```

### 4. 分核策略优化

#### 场景1：中等数据规模

**策略：** 调整分块大小，使内核总数接近物理核数的整数倍。

```python
# 物理核数：24
# 目标：启动24、48、72等内核数

# 调整block_M和block_N使得：
num_kernels = T.ceildiv(M, block_M) * T.ceildiv(N, block_N)
# num_kernels ≈ 24的倍数
```

**避免负载不均：**
- 启动21个内核 → 其中1个物理核执行2倍任务
- 启动24个内核 → 负载均衡

#### 场景2：大规模数据

**策略：** 固定启动物理核数，每个核内串行处理多个逻辑块。

```python
@tilelang.jit(out_idx=[-1], target="npuir")
def matmul(M, N, K, block_M, block_N, block_K, dtype="float16"):
    num_physical_kernels = 24
    num_logical_kernels = T.ceildiv(M, block_M) * T.ceildiv(N, block_N)

    @T.prim_func
    def gemm(A: T.Tensor((M, K), dtype),
             B: T.Tensor((K, N), dtype),
             C: T.Tensor((M, N), dtype)):
        # 固定启动24个物理核
        with T.Kernel(num_physical_kernels, is_npu=True) as (kernel_id, _):
            # 每个物理核负责的逻辑任务数
            num_tasks = T.ceildiv(num_logical_kernels - kernel_id, num_physical_kernels)

            # 核内串行处理多个逻辑块
            for task_id in T.serial(num_tasks):
                cid = task_id * num_physical_kernels + kernel_id
                by = cid // T.ceildiv(N, block_N)
                bx = cid % T.ceildiv(N, block_N)

                # 处理当前逻辑块
                # ... (正常的kernel逻辑)

    return gemm
```

**优势：**
- 避免核启动风暴
- 摊薄核启动开销
- 显著提升大规模问题性能

## UB内存限制检查

### 硬约束

单个Kernel内所有 `T.alloc_shared()` 和 `T.alloc_fragment()` 的总和必须 **< 96KB**（建议 < 85KB）。

### 内存计算公式

```python
# FP16: 2 bytes, FP32: 4 bytes, INT32: 4 bytes
total_bytes = sum(shape[0] * shape[1] * dtype_bytes for each allocation)
```

### 示例

```python
# ✅ 安全（约48KB）
q_shared = T.alloc_shared([64, 128], "float16")    # 16KB
k_shared = T.alloc_shared([64, 128], "float16")    # 16KB
acc_ub = T.alloc_shared([64, 64], "float32")       # 16KB

# ❌ 超限（256KB）
q_shared = T.alloc_shared([512, 128], "float16")   # 128KB
k_shared = T.alloc_shared([512, 128], "float16")   # 128KB
```

### 超限解决方案

1. 减小block_size
2. 分块处理
3. 复用buffer

## 优化检查清单

- [ ] 分块尺寸满足对齐要求（FP16需16倍数）
- [ ] UB总内存 < 85KB
- [ ] 流水线迭代次数 ≥ 4~6次
- [ ] 分核数量接近物理核数的整数倍
- [ ] 大规模数据使用核内串行策略
- [ ] 所有输入tensor调用 `.contiguous()`
