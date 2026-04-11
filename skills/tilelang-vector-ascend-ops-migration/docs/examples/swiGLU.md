# 迁移之前的GPU代码

```python
import torch
import tilelang
import tilelang.language as T

# ---------------------------------------------------------
# 1. 定义 TileLang 算子：Fused SwiGLU
# ---------------------------------------------------------
@tilelang.jit
def fused_swiglu(M, N, block_M=128, block_N=128)
    
    计算公式 Y = Swish(X1)  X2 = (X1  (1 + exp(-X1)))  X2
    输入 X shape [M, 2N]
    输出 Y shape [M, N]
    
    @T.prim_func
    def main(
        X T.Buffer((M, 2  N), float16),
        Y T.Buffer((M, N), float16),
    )
        # 计算 Grid 大小
        grid_x = (M + block_M - 1)  block_M
        grid_y = (N + block_N - 1)  block_N
        
        # 启动 Kernel，映射 Grid 和 Block (threads)
        with T.Kernel(grid_x, grid_y, threads=128) as (bx, by)
            
            # 在 Local Memory (寄存器) 中分配 Fragment
            x_frag = T.alloc_fragment((block_M, 2  block_N), float16)
            y_frag = T.alloc_fragment((block_M, block_N), float16)
            
            # 将数据从 Global Memory 批量 Load 到 Fragment 中
            T.copy(X[bx  block_M  (bx + 1)  block_M, 
                     by  2  block_N  (by + 1)  2  block_N], x_frag)
            
            # T.Parallel 展开为纯 Vector 计算逻辑，由 CUDA 线程并行执行
            for i, j in T.Parallel(block_M, block_N)
                # 1. 切片与精度转换 (FP16 - FP32 防止溢出)
                x1 = T.cast(x_frag[i, j], float32)
                x2 = T.cast(x_frag[i, j + block_N], float32)
                
                # 2. 核心数学运算 Swish(x1)
                # sigmoid(x) = 1.0  (1.0 + exp(-x))
                sigmoid_x1 = 1.0  (1.0 + T.exp(-x1))
                swish_x1 = x1  sigmoid_x1
                
                # 3. 门控乘法
                y_val = swish_x1  x2
                
                # 4. 精度转回 FP16 并存入 Output Fragment
                y_frag[i, j] = T.cast(y_val, float16)
                
            # 将计算结果写回 Global Memory
            T.copy(y_frag, Y[bx  block_M  (bx + 1)  block_M, 
                             by  block_N  (by + 1)  block_N])
            
    return main

# ---------------------------------------------------------
# 2. 运行与验证
# ---------------------------------------------------------
def test_swiglu()
    # 模拟一个 LLM 常见规模的 Tensor
    M, N = 4096, 4096 
    
    # 初始化输入和输出
    print(fAllocating Tensors on GPU (M={M}, N={N})...)
    X = torch.randn(M, 2  N, dtype=torch.float16, device=cuda)
    Y_tl = torch.empty(M, N, dtype=torch.float16, device=cuda)
    
    # 编译并获取 JIT Kernel
    print(Compiling TileLang Kernel...)
    kernel = fused_swiglu(M, N)
    
    # 运行 TileLang 算子
    print(Running TileLang Kernel...)
    kernel(X, Y_tl)
    
    # 使用 PyTorch 原生算子作为 Baseline 进行对比验证
    print(Running PyTorch Baseline for validation...)
    X32 = X.float() # 转至 FP32 保证 Baseline 精度
    X1, X2 = X32.chunk(2, dim=-1)
    Y_ref = (X1  torch.sigmoid(X1))  X2
    Y_ref = Y_ref.half()
    
    # 计算误差
    max_diff = torch.max(torch.abs(Y_tl - Y_ref)).item()
    print(fMax difference between TileLang and PyTorch {max_diff})
    
    if max_diff  1e-3
        print(✅ Validation Passed! The TileLang pure vector operator works correctly.)
    else
        print(❌ Validation Failed.)

if __name__ == __main__
    test_swiglu()
```





# 迁移之后的NPU代码

```python
import os
import torch
import tilelang
import tilelang.language as T

os.environ['TILELANG_ASCEND_MODE'] = 'Developer'

FP16 = "float16"
FP32 = "float32"

# ---------------------------------------------------------
# 1. 定义 TileLang NPU 算子：Fused SwiGLU
# ---------------------------------------------------------
@tilelang.jit(target="npuir")
def fused_swiglu_npu(M, N, block_M=64, block_N=64):
    """
    计算公式: Y = Swish(X1) * X2 = (X1 / (1 + exp(-X1))) * X2
    输入 X shape: [M, 2N]
    输出 Y shape: [M, N]

    NPU优化：使用向量化指令，减小block_size以满足UB内存限制
    """
    @T.prim_func
    def main(
        X: T.Tensor((M, 2 * N), FP16),
        Y: T.Tensor((M, N), FP16),
    ):
        # 计算 Grid 大小（必须在 prim_func 外部可见）
        with T.Kernel(T.ceildiv(M, block_M) * T.ceildiv(N, block_N), is_npu=True) as (cid, _):
            grid_y = T.ceildiv(N, block_N)
            bx = cid // grid_y
            by = cid % grid_y

            # 在 UB 中分配内存（减小block_size以满足96KB限制）
            x1_ub = T.alloc_shared((block_M, block_N), FP16)  # 8KB
            x2_ub = T.alloc_shared((block_M, block_N), FP16)  # 8KB
            x1_fp32 = T.alloc_shared((block_M, block_N), FP32) # 16KB
            x2_fp32 = T.alloc_shared((block_M, block_N), FP32) # 16KB
            y_ub = T.alloc_shared((block_M, block_N), FP32)   # 16KB
            y_fp16 = T.alloc_shared((block_M, block_N), FP16) # 8KB
            # 总计: 72KB < 85KB ✓

            # 从 Global Memory 加载数据到 UB
            T.copy(X[bx * block_M : (bx + 1) * block_M,
                     by * block_N : (by + 1) * block_N], x1_ub)
            T.copy(X[bx * block_M : (bx + 1) * block_M,
                     (N + by * block_N) : (N + (by + 1) * block_N)], x2_ub)

            # 使用向量化指令计算 Swish(x1) * x2
            # 1. 转换 x1, x2 为 FP32
            T.vcast(x1_ub, x1_fp32)
            T.vcast(x2_ub, x2_fp32)

            # 2. 计算 sigmoid(x1)
            T.vsigmoid(x1_fp32, y_ub)

            # 3. 计算 swish(x1) = x1 * sigmoid(x1)
            T.vmul(x1_fp32, y_ub, y_ub)

            # 4. 计算 y = swish(x1) * x2
            T.vmul(y_ub, x2_fp32, y_ub)

            # 5. 转换回 FP16
            T.vcast(y_ub, y_fp16)

            # 写回 Global Memory
            T.copy(y_fp16, Y[bx * block_M : (bx + 1) * block_M,
                             by * block_N : (by + 1) * block_N])

    return main


# ---------------------------------------------------------
# 2. 运行与验证
# ---------------------------------------------------------
def test_swiglu_npu():
    M, N = 512, 512

    print(f"Allocating Tensors on NPU (M={M}, N={N})...")
    X = torch.randn(M, 2 * N, dtype=torch.float16, device="npu").contiguous()
    Y_tl = torch.empty(M, N, dtype=torch.float16, device="npu")

    print("Compiling TileLang NPU Kernel...")
    kernel = fused_swiglu_npu(M, N)

    print("Running TileLang NPU Kernel...")
    kernel(X, Y_tl)

    print("Running PyTorch Baseline for validation...")
    X32 = X.float()
    X1, X2 = X32.chunk(2, dim=-1)
    Y_ref = (X1 * torch.sigmoid(X1)) * X2
    Y_ref = Y_ref.half()

    max_diff = torch.max(torch.abs(Y_tl - Y_ref)).item()
    print(f"Max difference: {max_diff}")

    if max_diff < 1e-3:
        print("✅ Validation Passed!")
    else:
        print("❌ Validation Failed.")


if __name__ == "__main__":
    test_swiglu_npu()

```



