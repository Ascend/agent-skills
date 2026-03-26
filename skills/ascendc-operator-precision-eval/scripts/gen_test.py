import numpy as np
import os

def gen_dual_data():
    # 1. 设置保存路径: test/data/
    base_dir = os.path.dirname(__file__)
    data_dir = os.path.join(base_dir, "data")
    os.makedirs(data_dir, exist_ok=True)
    
    print(f">>> 开始生成数据，保存目录: {data_dir}")

    # 2. 基础配置
    shape = (64, 64)
    np.random.seed(42)

    # ------------------------------------------------
    # A. 生成 Golden (真值)
    # ------------------------------------------------
    # 模拟 float32 范围的数据
    golden = np.random.uniform(-1, 1, shape).astype(np.float32)
    
    # ------------------------------------------------
    # B. 生成 Bench (标杆) - 模拟基准误差
    # ------------------------------------------------
    # 假设标杆算子有 1e-4 级别的精度损失 (RMSE约等于1e-4)
    bench_noise = np.random.normal(0, 1e-4, shape).astype(np.float32)
    bench = golden + bench_noise

    # ------------------------------------------------
    # C. 生成 Test_Pass (预期通过)
    # ------------------------------------------------
    # 待测算子的误差与标杆相当 (Ratio ≈ 1.0)
    test_pass_noise = np.random.normal(0, 1e-4, shape).astype(np.float32)
    test_pass = golden + test_pass_noise

    # ------------------------------------------------
    # D. 生成 Test_Fail (预期失败)
    # ------------------------------------------------
    # 待测算子误差是标杆的 10 倍 (Ratio ≈ 10.0 > 默认阈值)
    test_fail_noise = np.random.normal(0, 100e-4, shape).astype(np.float32)
    test_fail = golden.copy()
    test_fail[16:32,32:64] += test_fail_noise[16:32,32:64]

    # 3. 保存文件
    np.save(os.path.join(data_dir, "golden.npy"), golden)
    np.save(os.path.join(data_dir, "bench.npy"), bench)
    np.save(os.path.join(data_dir, "test_pass.npy"), test_pass)
    np.save(os.path.join(data_dir, "test_fail.npy"), test_fail)

    print(">>> 数据生成完毕:")
    print(f"    1. {os.path.join(data_dir, 'golden.npy')} (真值)")
    print(f"    2. {os.path.join(data_dir, 'bench.npy')}  (标杆 - 基准误差)")
    print(f"    3. {os.path.join(data_dir, 'test_pass.npy')} (待测 - 精度正常)")
    print(f"    4. {os.path.join(data_dir, 'test_fail.npy')} (待测 - 精度劣化)")

if __name__ == "__main__":
    gen_dual_data()