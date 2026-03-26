# Unit Test Template

## 单元测试位置

`tests/` 目录

## 现有测试

- `tests/test_avg_pool3d.py` - avg_pool3d 算子单元测试

## 运行单元测试

```bash
# 进入 ascend-kernel 目录
cd ./ascend-kernel

# 方式 1: 使用 pytest 运行完整测试（推荐，包含精度校验）
pip install pytest
pytest tests/test_avg_pool3d.py -v

# 方式 2: 直接运行 Python 脚本（简单测试，仅检查可运行性）
python tests/test_avg_pool3d.py
```

## 测试层次

| 测试方式 | 说明 | 精度校验 |
|---------|------|---------|
| pytest | 完整测试套件，参数化测试 | 是 |
| 直接运行 | 简单测试，仅检查算子是否可运行 | 否 |

---

## 新算子单元测试模板

在 `tests/` 目录下创建 `test_<op_name>.py`：

```python
#!/usr/bin/env python3
"""Unit tests for <op_name> NPU operator."""

import torch
import torch_npu
import pytest

# Load the ascend_kernel library
import ascend_kernel


def is_npu_available():
    """Check if NPU is available."""
    try:
        return torch.npu.is_available()
    except:
        return False


@pytest.fixture(scope="module")
def device():
    """Fixture to provide NPU device."""
    if not is_npu_available():
        pytest.skip("NPU not available")
    return torch.device("npu:0")


class Test<OpName>:
    """Test cases for <op_name> operator (with accuracy validation)."""

    def test_basic_forward(self, device):
        """Test basic forward pass with accuracy validation."""
        x = torch.randn(2, 3, 8, 8, dtype=torch.float32, device=device)

        # NPU result
        npu_result = torch.ops.npu.<op_name>(x, ...)

        # CPU reference result
        x_cpu = x.cpu()
        cpu_result = torch.nn.functional.<pytorch_func>(x_cpu, ...)

        # Compare
        assert npu_result.shape == cpu_result.shape
        assert torch.allclose(npu_result.cpu(), cpu_result, rtol=1e-4, atol=1e-4)


def run_simple_test():
    """Run a simple test without pytest framework.

    This test only checks if the operator can run successfully,
    without verifying numerical accuracy.
    """
    if not is_npu_available():
        print("NPU not available, skipping test")
        return False

    device = torch.device("npu:0")
    print(f"Running simple test on {device}...")

    try:
        # Create input tensor
        x = torch.randn(2, 3, 8, 8, dtype=torch.float32, device=device)
        print(f"Input shape: {x.shape}")

        # Run operator
        result = torch.ops.npu.<op_name>(x, ...)
        print(f"Output shape: {result.shape}")

        print("Test PASSED! Operator runs successfully.")
        return True

    except Exception as e:
        print(f"Test FAILED with error: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    # Run simple test if executed directly
    success = run_simple_test()
    exit(0 if success else 1)
```

## 测试原则

1. pytest 测试：与 PyTorch 原生实现对比验证精度
2. 简单测试（run_simple_test）：仅检查算子是否可运行，程序正常退出即通过
3. 测试不同的输入形状和数据类型
4. 验证输出形状是否符合预期
