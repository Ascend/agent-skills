# 迁移之前的GPU算子代码

```python
import torch
import tilelang
import tilelang.language as T

# ---------------------------------------------------------
# 1. 定义 TileLang 算子：Fused Q-K RoPE (CUDA 版本)
# ---------------------------------------------------------
@tilelang.jit(target="cuda")
def fused_qk_rope(batch_size, seq_len, num_q_heads, num_k_heads, head_dim):
    """
    对 Query 和 Key 同时进行旋转位置编码 (RoPE)。
    纯 Vector 计算，利用 CUDA 的 Grid/Block 映射完美实现并行。
    """
    # 每一根线程处理一个维度的前后两半，所以线程数只需要 head_dim 的一半
    half_d = head_dim // 2
    
    # Grid 大小：处理 Q 和 K 的所有 Token 和 Head
    # 我们用一个 3D Grid 来映射 Batch, SeqLen, 和 Max(Q_Heads, K_Heads)
    max_heads = max(num_q_heads, num_k_heads)
    
    @T.prim_func
    def main(
        Q: T.Tensor((batch_size, seq_len, num_q_heads, head_dim), "float16"),
        K: T.Tensor((batch_size, seq_len, num_k_heads, head_dim), "float16"),
        Cos: T.Tensor((seq_len, head_dim), "float16"),
        Sin: T.Tensor((seq_len, head_dim), "float16"),
        Out_Q: T.Tensor((batch_size, seq_len, num_q_heads, head_dim), "float16"),
        Out_K: T.Tensor((batch_size, seq_len, num_k_heads, head_dim), "float16"),
    ):
        # 启动 Kernel，分配 3D 线程块
        # blocks 映射为 (batch_size, seq_len, max_heads)
        # threads 映射为 head_dim // 2
        with T.Kernel((batch_size, seq_len, max_heads), threads=half_d) as (bx, by, bz, tx):
            b = bx   # batch 索引
            s = by   # seq_len 索引
            h = bz   # head 索引
            d = tx   # 维度索引 (0 到 half_d - 1)

            # ---------------------------------------------
            # 1. 处理 Query (如果当前 head 索引在 Q 的范围内)
            # ---------------------------------------------
            if h < num_q_heads:
                # 优雅的多维索引，CUDA 后端完美支持，无需手动算 1D 偏移
                q1 = T.cast(Q[b, s, h, d], "float32")
                q2 = T.cast(Q[b, s, h, d + half_d], "float32")

                c1 = T.cast(Cos[s, d], "float32")
                s1 = T.cast(Sin[s, d], "float32")
                c2 = T.cast(Cos[s, d + half_d], "float32")
                s2 = T.cast(Sin[s, d + half_d], "float32")

                # 交叉相乘与加减
                out_q1 = q1 * c1 - q2 * s1
                out_q2 = q2 * c2 + q1 * s2

                # 写回 Global Memory
                Out_Q[b, s, h, d] = T.cast(out_q1, "float16")
                Out_Q[b, s, h, d + half_d] = T.cast(out_q2, "float16")

            # ---------------------------------------------
            # 2. 处理 Key (如果当前 head 索引在 K 的范围内)
            # ---------------------------------------------
            # 支持 MQA/GQA 架构（K 的头数可能比 Q 少）
            if h < num_k_heads:
                k1 = T.cast(K[b, s, h, d], "float32")
                k2 = T.cast(K[b, s, h, d + half_d], "float32")

                # 复用 Cos 和 Sin（因为同一个 token 对应的缓存是一样的）
                c1_k = T.cast(Cos[s, d], "float32")
                s1_k = T.cast(Sin[s, d], "float32")
                c2_k = T.cast(Cos[s, d + half_d], "float32")
                s2_k = T.cast(Sin[s, d + half_d], "float32")

                out_k1 = k1 * c1_k - k2 * s1_k
                out_k2 = k2 * c2_k + k1 * s2_k

                Out_K[b, s, h, d] = T.cast(out_k1, "float16")
                Out_K[b, s, h, d + half_d] = T.cast(out_k2, "float16")

    return main

# ---------------------------------------------------------
# 2. 运行与验证
# ---------------------------------------------------------
def test_rope():
    # 模拟 LLM 常见规模 (支持 GQA，Query 32 个头，Key 8 个头)
    B, S, H_q, H_k, D = 4, 1024, 32, 8, 128

    print(f"Allocating Tensors on GPU (Batch={B}, Seq={S}, HeadDim={D})...")
    Q = torch.randn(B, S, H_q, D, dtype=torch.float16, device="cuda")
    K = torch.randn(B, S, H_k, D, dtype=torch.float16, device="cuda")
    
    # Cos 和 Sin 通常在 CPU 生成后转入 GPU
    Cos = torch.randn(S, D, dtype=torch.float16, device="cuda")
    Sin = torch.randn(S, D, dtype=torch.float16, device="cuda")

    Out_Q_tl = torch.empty_like(Q)
    Out_K_tl = torch.empty_like(K)

    print("Compiling TileLang Kernel for CUDA...")
    kernel = fused_qk_rope(B, S, H_q, H_k, D)

    print("Running TileLang Kernel...")
    kernel(Q, K, Cos, Sin, Out_Q_tl, Out_K_tl)

    print("Running PyTorch Baseline for validation...")
    def pytorch_rope(x, cos, sin):
        x_fp32 = x.float()
        cos_fp32 = cos.float().unsqueeze(0).unsqueeze(2)  # [1, S, 1, D]
        sin_fp32 = sin.float().unsqueeze(0).unsqueeze(2)
        
        half_d = D // 2
        x1, x2 = x_fp32[..., :half_d], x_fp32[..., half_d:]
        
        out1 = x1 * cos_fp32[..., :half_d] - x2 * sin_fp32[..., :half_d]
        out2 = x2 * cos_fp32[..., half_d:] + x1 * sin_fp32[..., half_d:]
        
        return torch.cat([out1, out2], dim=-1).half()

    Out_Q_ref = pytorch_rope(Q, Cos, Sin)
    Out_K_ref = pytorch_rope(K, Cos, Sin)

    # 验证 Query
    q_max_diff = torch.max(torch.abs(Out_Q_tl - Out_Q_ref)).item()
    k_max_diff = torch.max(torch.abs(Out_K_tl - Out_K_ref)).item()
    
    print("\nDetailed Accuracy Check:")
    print(f"  Q Max Absolute Error: {q_max_diff:.6f}")
    print(f"  K Max Absolute Error: {k_max_diff:.6f}")

    if q_max_diff < 1e-3 and k_max_diff < 1e-3:
        print("✅ Validation Passed! The TileLang CUDA RoPE operator works flawlessly.")
    else:
        print("❌ Validation Failed.")

if __name__ == "__main__":
    test_rope()
```



# 迁移之后的NPU算子代码

```python
import os
import torch
import tilelang
import tilelang.language as T

os.environ['TILELANG_ASCEND_MODE'] = 'Developer'

FP16 = "float16"
FP32 = "float32"

# ---------------------------------------------------------
# 1. 定义 TileLang NPU 算子：Fused Q-K RoPE
# ---------------------------------------------------------
@tilelang.jit(target="npuir")
def fused_qk_rope_npu(batch_size, seq_len, num_q_heads, num_k_heads, head_dim, block_size=16):
    """
    对 Query 和 Key 同时进行旋转位置编码 (RoPE)。
    NPU 版本：使用向量化指令，展平为 1D Grid。
    """
    half_d = head_dim // 2

    @T.prim_func
    def main(
        Q: T.Tensor((batch_size, seq_len, num_q_heads, head_dim), FP16),
        K: T.Tensor((batch_size, seq_len, num_k_heads, head_dim), FP16),
        Cos: T.Tensor((seq_len, head_dim), FP16),
        Sin: T.Tensor((seq_len, head_dim), FP16),
        Out_Q: T.Tensor((batch_size, seq_len, num_q_heads, head_dim), FP16),
        Out_K: T.Tensor((batch_size, seq_len, num_k_heads, head_dim), FP16),
    ):
        # 直接在 Kernel 参数中计算 grid 大小
        with T.Kernel(batch_size * seq_len, is_npu=True) as (cid, _):
            # 解码 token 索引
            b = cid // seq_len
            s = cid % seq_len

            # 分配 UB 内存
            cos_ub = T.alloc_shared((head_dim,), FP16)
            sin_ub = T.alloc_shared((head_dim,), FP16)
            q_ub = T.alloc_shared((head_dim,), FP16)
            k_ub = T.alloc_shared((head_dim,), FP16)
            # 总计: 4 * 128 * 2 = 1KB << 85KB ✓

            # 加载 Cos 和 Sin
            T.copy(Cos[s, 0], cos_ub, size=[head_dim])
            T.copy(Sin[s, 0], sin_ub, size=[head_dim])

            # 处理所有 Q heads
            for h in T.serial(num_q_heads):
                T.copy(Q[b, s, h, 0], q_ub, size=[head_dim])

                # RoPE 计算：使用 T.Parallel 进行向量化
                for d in T.Parallel(half_d):
                    q1 = T.cast(q_ub[d], FP32)
                    q2 = T.cast(q_ub[d + half_d], FP32)
                    c1 = T.cast(cos_ub[d], FP32)
                    s1 = T.cast(sin_ub[d], FP32)
                    c2 = T.cast(cos_ub[d + half_d], FP32)
                    s2 = T.cast(sin_ub[d + half_d], FP32)

                    out_q1 = q1 * c1 - q2 * s1
                    out_q2 = q2 * c2 + q1 * s2

                    q_ub[d] = T.cast(out_q1, FP16)
                    q_ub[d + half_d] = T.cast(out_q2, FP16)

                T.copy(q_ub, Out_Q[b, s, h, 0], size=[head_dim])

            # 处理所有 K heads
            for h in T.serial(num_k_heads):
                T.copy(K[b, s, h, 0], k_ub, size=[head_dim])

                # RoPE 计算
                for d in T.Parallel(half_d):
                    k1 = T.cast(k_ub[d], FP32)
                    k2 = T.cast(k_ub[d + half_d], FP32)
                    c1 = T.cast(cos_ub[d], FP32)
                    s1 = T.cast(sin_ub[d], FP32)
                    c2 = T.cast(cos_ub[d + half_d], FP32)
                    s2 = T.cast(sin_ub[d + half_d], FP32)

                    out_k1 = k1 * c1 - k2 * s1
                    out_k2 = k2 * c2 + k1 * s2

                    k_ub[d] = T.cast(out_k1, FP16)
                    k_ub[d + half_d] = T.cast(out_k2, FP16)

                T.copy(k_ub, Out_K[b, s, h, 0], size=[head_dim])

    return main


# ---------------------------------------------------------
# 2. 运行与验证
# ---------------------------------------------------------
def test_rope_npu():
    B, S, H_q, H_k, D = 2, 128, 8, 4, 128

    print(f"Allocating Tensors on NPU (Batch={B}, Seq={S}, HeadDim={D})...")
    Q = torch.randn(B, S, H_q, D, dtype=torch.float16, device="npu").contiguous()
    K = torch.randn(B, S, H_k, D, dtype=torch.float16, device="npu").contiguous()
    Cos = torch.randn(S, D, dtype=torch.float16, device="npu").contiguous()
    Sin = torch.randn(S, D, dtype=torch.float16, device="npu").contiguous()

    Out_Q_tl = torch.empty_like(Q)
    Out_K_tl = torch.empty_like(K)

    print("Compiling TileLang NPU Kernel...")
    kernel = fused_qk_rope_npu(B, S, H_q, H_k, D)

    print("Running TileLang NPU Kernel...")
    kernel(Q, K, Cos, Sin, Out_Q_tl, Out_K_tl)

    print("Running PyTorch Baseline for validation...")
    def pytorch_rope(x, cos, sin):
        x_fp32 = x.float()
        cos_fp32 = cos.float().unsqueeze(0).unsqueeze(2)
        sin_fp32 = sin.float().unsqueeze(0).unsqueeze(2)

        half_d = D // 2
        x1, x2 = x_fp32[..., :half_d], x_fp32[..., half_d:]

        out1 = x1 * cos_fp32[..., :half_d] - x2 * sin_fp32[..., :half_d]
        out2 = x2 * cos_fp32[..., half_d:] + x1 * sin_fp32[..., half_d:]

        return torch.cat([out1, out2], dim=-1).half()

    Out_Q_ref = pytorch_rope(Q, Cos, Sin)
    Out_K_ref = pytorch_rope(K, Cos, Sin)

    q_max_diff = torch.max(torch.abs(Out_Q_tl - Out_Q_ref)).item()
    k_max_diff = torch.max(torch.abs(Out_K_tl - Out_K_ref)).item()

    print(f"Q Max Error: {q_max_diff:.6f}")
    print(f"K Max Error: {k_max_diff:.6f}")

    if q_max_diff < 1e-3 and k_max_diff < 1e-3:
        print("✅ Validation Passed!")
    else:
        print("❌ Validation Failed.")


if __name__ == "__main__":
    test_rope_npu()


```



