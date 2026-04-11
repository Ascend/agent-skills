# 迁移之前的GPU算子

```python
import torch
import tilelang
import tilelang.language as T

@tilelang.jit(target="cuda")
def elu(M, N, alpha=1.0):
    """
    ELU: y = x if x > 0 else alpha * (exp(x) - 1)
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
                if x > 0.0:
                    y = x
                else:
                    y = alpha * (T.exp(x) - 1.0)
                Y[bx, by] = T.cast(y, "float16")

    return main

def test_elu():
    M, N = 2048, 4096
    alpha = 1.0

    X = torch.randn(M, N, dtype=torch.float16, device="cuda")
    Y_tl = torch.empty(M, N, dtype=torch.float16, device="cuda")

    kernel = elu(M, N, alpha)
    kernel(X, Y_tl)

    Y_ref = torch.nn.functional.elu(X.float(), alpha).half()

    max_diff = torch.max(torch.abs(Y_tl - Y_ref)).item()
    print(f"ELU Max diff: {max_diff}")

    if max_diff < 1e-2:
        print("✅ ELU Validation Passed")
    else:
        print("❌ ELU Validation Failed")

if __name__ == "__main__":
    test_elu()

```



# 迁移之后的NPU算子

```python
import os
import torch
import tilelang
import tilelang.language as T

os.environ['TILELANG_ASCEND_MODE'] = 'Developer'

@tilelang.jit(target="npuir")
def elu_npu(M, N, block_M=64, block_N=64, alpha=1.0):
    """
    ELU: y = x if x > 0 else alpha * (exp(x) - 1)
    NPU implementation using block-based processing
    """
    @T.prim_func
    def main(
        X: T.Tensor((M, N), "float16"),
        Y: T.Tensor((M, N), "float16"),
    ):
        with T.Kernel(T.ceildiv(M, block_M) * T.ceildiv(N, block_N), is_npu=True) as (cid, _):
            grid_y = T.ceildiv(N, block_N)
            bx = cid // grid_y
            by = cid % grid_y

            # Allocate buffers (reuse buffers to save memory)
            x_ub = T.alloc_shared((block_M, block_N), "float16")
            x_fp32 = T.alloc_shared((block_M, block_N), "float32")
            temp_ub = T.alloc_shared((block_M, block_N), "float32")
            const_ub = T.alloc_shared((block_M, block_N), "float32")

            # Load input block
            T.copy(X[bx * block_M : (bx + 1) * block_M,
                     by * block_N : (by + 1) * block_N], x_ub)

            # Convert to FP32 for computation
            T.vcast(x_ub, x_fp32)

            # Compute exp(x)
            T.vexp(x_fp32, temp_ub)

            # Compute alpha * (exp(x) - 1)
            one_scalar = T.cast(1.0, "float32")
            T.vbrc(one_scalar, const_ub)
            T.vsub(temp_ub, const_ub, temp_ub)

            alpha_scalar = T.cast(alpha, "float32")
            T.vbrc(alpha_scalar, const_ub)
            T.vmul(const_ub, temp_ub, temp_ub)

            # Select: y = x if x > 0 else alpha * (exp(x) - 1)
            zero_scalar = T.cast(0.0, "float32")
            T.vbrc(zero_scalar, const_ub)
            mask_ub = T.alloc_shared((block_M, block_N), "bool")
            T.vcmp(x_fp32, const_ub, mask_ub, "gt")
            T.vselect(mask_ub, x_fp32, temp_ub, temp_ub)

            # Convert back to FP16 and store
            T.vcast(temp_ub, x_ub)
            T.copy(x_ub, Y[bx * block_M : (bx + 1) * block_M,
                           by * block_N : (by + 1) * block_N])

    return main

def test_elu_npu():
    M, N = 2048, 4096
    alpha = 1.0

    X = torch.randn(M, N, dtype=torch.float16, device="npu").contiguous()
    Y_npu = torch.empty(M, N, dtype=torch.float16, device="npu")

    kernel = elu_npu(M, N, alpha=alpha)
    kernel(X, Y_npu)

    Y_ref = torch.nn.functional.elu(X.float(), alpha).half()

    max_diff = torch.max(torch.abs(Y_npu - Y_ref)).item()
    print(f"Max difference: {max_diff}")

    if max_diff < 1e-3:
        print("✅ Validation Passed!")
    else:
        print("❌ Validation Failed.")

if __name__ == "__main__":
    test_elu_npu()

```

