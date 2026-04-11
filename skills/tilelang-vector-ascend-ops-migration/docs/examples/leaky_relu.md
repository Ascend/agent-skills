# 迁移之前的GPU算子

```python
import torch
import tilelang
import tilelang.language as T

@tilelang.jit(target="cuda")
def leaky_relu(M, N, alpha=0.01):
    """
    Leaky ReLU: y = max(x, alpha * x)
    """
    @T.prim_func
    def main(
        X: T.Tensor((M, N), "float16"),
        Y: T.Tensor((M, N), "float16"),
    ):
        with T.Kernel((M, N), threads=256) as (bx, by, tx):
            idx = bx * N + by
            if idx < M * N:
                x = T.cast(X[bx, by], "float32")
                y = T.max(x, alpha * x)
                Y[bx, by] = T.cast(y, "float16")

    return main

def test_leaky_relu():
    M, N = 2048, 4096
    alpha = 0.01

    X = torch.randn(M, N, dtype=torch.float16, device="cuda")
    Y_tl = torch.empty(M, N, dtype=torch.float16, device="cuda")

    kernel = leaky_relu(M, N, alpha)
    kernel(X, Y_tl)

    Y_ref = torch.nn.functional.leaky_relu(X.float(), alpha).half()

    max_diff = torch.max(torch.abs(Y_tl - Y_ref)).item()
    print(f"Leaky ReLU Max diff: {max_diff}")

    if max_diff < 1e-3:
        print("✅ Leaky ReLU Validation Passed")
    else:
        print("❌ Leaky ReLU Validation Failed")

if __name__ == "__main__":
    test_leaky_relu()

```



# 迁移之后的NPU算子

```python
import os
import torch
import tilelang
import tilelang.language as T

os.environ['TILELANG_ASCEND_MODE'] = 'Developer'

FP16 = "float16"
FP32 = "float32"

@tilelang.jit(target="npuir")
def leaky_relu_npu(M, N, alpha=0.01, block_M=64, block_N=64):
    """
    Leaky ReLU: y = max(x, alpha * x)
    NPU implementation using block-based processing
    """
    @T.prim_func
    def main(
        X: T.Tensor((M, N), FP16),
        Y: T.Tensor((M, N), FP16),
    ):
        with T.Kernel(T.ceildiv(M, block_M) * T.ceildiv(N, block_N), is_npu=True) as (cid, _):
            grid_y = T.ceildiv(N, block_N)
            bx = cid // grid_y
            by = cid % grid_y

            # Allocate buffers for the block
            x_ub = T.alloc_shared((block_M, block_N), FP16)
            x_fp32 = T.alloc_shared((block_M, block_N), FP32)
            alpha_ub = T.alloc_shared((block_M, block_N), FP32)
            alpha_x_fp32 = T.alloc_shared((block_M, block_N), FP32)
            y_fp32 = T.alloc_shared((block_M, block_N), FP32)
            y_ub = T.alloc_shared((block_M, block_N), FP16)

            # Load block from global memory
            T.copy(X[bx * block_M : (bx + 1) * block_M,
                     by * block_N : (by + 1) * block_N], x_ub)

            # Convert to FP32 for computation
            T.vcast(x_ub, x_fp32)

            # Broadcast alpha to a tensor
            alpha_scalar = T.cast(alpha, FP32)
            T.vbrc(alpha_scalar, alpha_ub)

            # Compute alpha * x
            T.vmul(x_fp32, alpha_ub, alpha_x_fp32)

            # Compute max(x, alpha * x)
            T.vmax(x_fp32, alpha_x_fp32, y_fp32)

            # Convert back to FP16
            T.vcast(y_fp32, y_ub)

            # Store result back to global memory
            T.copy(y_ub, Y[bx * block_M : (bx + 1) * block_M,
                            by * block_N : (by + 1) * block_N])

    return main

def test_leaky_relu_npu():
    M, N = 2048, 4096
    alpha = 0.01

    X = torch.randn(M, N, dtype=torch.float16, device="npu").contiguous()
    Y_npu = torch.empty(M, N, dtype=torch.float16, device="npu")

    kernel = leaky_relu_npu(M, N, alpha)
    kernel(X, Y_npu)

    Y_ref = torch.nn.functional.leaky_relu(X.float(), alpha).half()

    max_diff = torch.max(torch.abs(Y_npu - Y_ref)).item()
    print(f"Leaky ReLU Max difference: {max_diff}")

    if max_diff < 1e-3:
        print("✅ Leaky ReLU Validation Passed!")
    else:
        print("❌ Leaky ReLU Validation Failed.")

if __name__ == "__main__":
    test_leaky_relu_npu()

```

