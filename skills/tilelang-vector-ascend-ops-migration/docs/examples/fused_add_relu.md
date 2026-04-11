# 迁移之前的GPU算子

```python
import torch
import tilelang
import tilelang.language as T

@tilelang.jit(target="cuda")
def fused_add_relu(M, N):
    """
    Fused Add + ReLU: y = max(x1 + x2, 0)
    """
    @T.prim_func
    def main(
        X1: T.Tensor((M, N), "float16"),
        X2: T.Tensor((M, N), "float16"),
        Y: T.Tensor((M, N), "float16"),
    ):
        with T.Kernel((M, N), threads=256) as (bx, by, tx):
            idx = bx * N + by
            if idx < M * N:
                x1 = T.cast(X1[bx, by], "float32")
                x2 = T.cast(X2[bx, by], "float32")
                y = T.max(x1 + x2, 0.0)
                Y[bx, by] = T.cast(y, "float16")

    return main

def test_fused_add_relu():
    M, N = 2048, 4096

    X1 = torch.randn(M, N, dtype=torch.float16, device="cuda")
    X2 = torch.randn(M, N, dtype=torch.float16, device="cuda")
    Y_tl = torch.empty(M, N, dtype=torch.float16, device="cuda")

    kernel = fused_add_relu(M, N)
    kernel(X1, X2, Y_tl)

    Y_ref = torch.relu(X1.float() + X2.float()).half()

    max_diff = torch.max(torch.abs(Y_tl - Y_ref)).item()
    print(f"Fused Add+ReLU Max diff: {max_diff}")

    if max_diff < 1e-3:
        print("✅ Fused Add+ReLU Validation Passed")
    else:
        print("❌ Fused Add+ReLU Validation Failed")

if __name__ == "__main__":
    test_fused_add_relu()

```



# 迁移之后的NPU算子



```python
import os
import torch
import tilelang
import tilelang.language as T

os.environ['TILELANG_ASCEND_MODE'] = 'Developer'

@tilelang.jit(target="npuir")
def fused_add_relu_npu(M, N, block_M: int = 64, block_N: int = 64):
    """
    NPU implementation of Fused Add + ReLU: y = max(x1 + x2, 0)
    """
    @T.prim_func
    def main(
        X1: T.Tensor((M, N), "float16"),
        X2: T.Tensor((M, N), "float16"),
        Y: T.Tensor((M, N), "float16"),
    ):
        with T.Kernel(T.ceildiv(M, block_M) * T.ceildiv(N, block_N), is_npu=True) as (cid, _):
            grid_y = T.ceildiv(N, block_N)
            bx = cid // grid_y
            by = cid % grid_y

            x1_ub = T.alloc_shared((block_M, block_N), "float16")
            x2_ub = T.alloc_shared((block_M, block_N), "float16")
            x1_fp32 = T.alloc_shared((block_M, block_N), "float32")
            x2_fp32 = T.alloc_shared((block_M, block_N), "float32")
            y_ub = T.alloc_shared((block_M, block_N), "float32")

            T.copy(X1[bx * block_M : (bx + 1) * block_M, by * block_N : (by + 1) * block_N], x1_ub)
            T.copy(X2[bx * block_M : (bx + 1) * block_M, by * block_N : (by + 1) * block_N], x2_ub)

            T.vcast(x1_ub, x1_fp32)
            T.vcast(x2_ub, x2_fp32)

            T.vadd(x1_fp32, x2_fp32, y_ub)
            T.vrelu(y_ub, y_ub)

            T.vcast(y_ub, x1_ub)
            T.copy(x1_ub, Y[bx * block_M : (bx + 1) * block_M, by * block_N : (by + 1) * block_N])

    return main

def test_fused_add_relu_npu():
    M, N = 2048, 4096

    X1 = torch.randn(M, N, dtype=torch.float16, device="npu").contiguous()
    X2 = torch.randn(M, N, dtype=torch.float16, device="npu").contiguous()
    Y_npu = torch.empty(M, N, dtype=torch.float16, device="npu")

    kernel = fused_add_relu_npu(M, N)
    kernel(X1, X2, Y_npu)

    Y_ref = torch.relu(X1.float() + X2.float()).half()

    max_diff = torch.max(torch.abs(Y_npu - Y_ref)).item()
    print(f"Fused Add+ReLU Max difference: {max_diff}")

    if max_diff < 1e-3:
        print("✅ Validation Passed!")
    else:
        print("❌ Validation Failed.")

if __name__ == "__main__":
    test_fused_add_relu_npu()

```



