# 迁移之前的GPU算子

```python
import torch
import tilelang
import tilelang.language as T

@tilelang.jit(target="cuda")
def softmax(M, N):
    """
    Softmax: y = exp(x - max(x)) / sum(exp(x - max(x)))
    """
    @T.prim_func
    def main(
        X: T.Tensor((M, N), "float16"),
        Y: T.Tensor((M, N), "float16"),
    ):
        with T.Kernel(M, threads=256) as (bx, tx):
            row_max = T.alloc_shared((1,), "float32")
            row_sum = T.alloc_shared((1,), "float32")

            if tx == 0:
                row_max[0] = -1e9

            T.syncthreads()

            # 找最大值
            for j in range(tx, N, 256):
                val = T.cast(X[bx, j], "float32")
                T.atomic_max(row_max[0], val)

            T.syncthreads()

            if tx == 0:
                row_sum[0] = 0.0

            T.syncthreads()

            max_val = row_max[0]

            # 计算exp和sum
            for j in range(tx, N, 256):
                val = T.cast(X[bx, j], "float32")
                exp_val = T.exp(val - max_val)
                T.atomic_add(row_sum[0], exp_val)

            T.syncthreads()

            sum_val = row_sum[0]

            # 归一化
            for j in range(tx, N, 256):
                val = T.cast(X[bx, j], "float32")
                exp_val = T.exp(val - max_val)
                y_val = exp_val / sum_val
                Y[bx, j] = T.cast(y_val, "float16")

    return main

def test_softmax():
    M, N = 512, 1024

    X = torch.randn(M, N, dtype=torch.float16, device="cuda")
    Y_tl = torch.empty(M, N, dtype=torch.float16, device="cuda")

    kernel = softmax(M, N)
    kernel(X, Y_tl)

    Y_ref = torch.nn.functional.softmax(X.float(), dim=-1).half()

    max_diff = torch.max(torch.abs(Y_tl - Y_ref)).item()
    print(f"Softmax Max diff: {max_diff}")

    if max_diff < 1e-2:
        print("✅ Softmax Validation Passed")
    else:
        print("❌ Softmax Validation Failed")

if __name__ == "__main__":
    test_softmax()

```

# 迁移之后的NPU算子

```python
import os
import torch
import tilelang
import tilelang.language as T

os.environ['TILELANG_ASCEND_MODE'] = 'Developer'

@tilelang.jit(target="npuir")
def softmax_npu(M, N):
    """
    Softmax: y = exp(x - max(x)) / sum(exp(x - max(x)))
    NPU implementation using block-based processing
    """
    @T.prim_func
    def main(
        X: T.Tensor((M, N), "float16"),
        Y: T.Tensor((M, N), "float16"),
    ):
        with T.Kernel(M, is_npu=True) as (cid, _):
            # 每个 core 处理一行
            bx = cid

            # 分配 UB 内存
            x_ub = T.alloc_shared((1, N), "float16")
            x_fp32 = T.alloc_shared((1, N), "float32")
            max_ub = T.alloc_shared((1, 1), "float32")
            sum_ub = T.alloc_shared((1, 1), "float32")
            exp_ub = T.alloc_shared((1, N), "float32")
            y_ub = T.alloc_shared((1, N), "float16")

            # 加载数据
            T.copy(X[bx : bx + 1, 0 : N], x_ub)

            # 转换为 FP32
            T.vcast(x_ub, x_fp32)

            # 找最大值
            T.reduce_max(x_fp32, max_ub, dim=-1)

            # 广播 max_val
            max_brc = T.alloc_shared((1, N), "float32")
            max_scalar = max_ub[0, 0]
            T.vbrc(max_scalar, max_brc)

            # 计算 x - max
            T.vsub(x_fp32, max_brc, exp_ub)

            # 计算 exp(x - max)
            T.vexp(exp_ub, exp_ub)

            # 求和
            T.reduce_sum(exp_ub, sum_ub, dim=-1, clear=True)

            # 广播 sum_val
            sum_brc = T.alloc_shared((1, N), "float32")
            sum_scalar = sum_ub[0, 0]
            T.vbrc(sum_scalar, sum_brc)

            # 归一化: exp / sum
            T.vdiv(exp_ub, sum_brc, exp_ub)

            # 转换回 FP16
            T.vcast(exp_ub, y_ub)

            # 写回结果
            T.copy(y_ub, Y[bx : bx + 1, 0 : N])

    return main

def test_softmax_npu():
    M, N = 512, 1024

    X = torch.randn(M, N, dtype=torch.float16, device="npu").contiguous()
    Y_npu = torch.empty(M, N, dtype=torch.float16, device="npu")

    kernel = softmax_npu(M, N)
    kernel(X, Y_npu)

    Y_ref = torch.nn.functional.softmax(X.float(), dim=-1).half()

    max_diff = torch.max(torch.abs(Y_npu - Y_ref)).item()
    print(f"Max difference: {max_diff}")

    if max_diff < 1e-3:
        print("✅ Validation Passed!")
    else:
        print("❌ Validation Failed.")

if __name__ == "__main__":
    test_softmax_npu()

```

