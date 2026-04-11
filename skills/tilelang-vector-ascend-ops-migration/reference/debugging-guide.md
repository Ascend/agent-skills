# NPU算子调试指南

## 概述

本文档提供NPU算子开发中的调试方法，帮助快速定位编译失败、精度问题和运行时错误。

## 常见问题分类

| 问题类型 | 具体表现 | 推荐调试方法 |
|---------|---------|-------------|
| **精度问题** | 算子编译成功但结果与参考实现存在差异 | T.print打印调试 |
| **编译失败** | 算子编译失败，未生成预期的IR | 编译调试 |
| **运行时失败** | 算子编译成功但未生成.o文件，进程终止 | 运行时调试 |

## 编译流程概览

```
[Python Tilelang] → [TVM IR] → [MLIR] → [NPU可执行文件.o] → [计算结果]
```

| 编译阶段 | 输入 | 输出 | 工具/组件 |
|---------|------|------|----------|
| Python Kernel编译 | Tilelang_kernel.py | TVM IR | TVM编译器 |
| Codegen阶段 | TVM IR | MLIR | JIT + Tilelang Codegen |
| AscendNPUIR编译 | MLIR | .o文件 | JIT + bishengir-compile |

## 调试方法

### 1. T.print 打印调试（精度问题）

用于打印中间计算结果，定位精度错误的具体步骤。

**用法：**
```python
T.print(obj, msg, hex)
# obj: 要打印的变量（var或buffer）
# msg: 可选的提示信息
# hex: 是否以16进制打印（默认false）
```

**示例：**
```python
T.reduce(A, row_sum, dims=1, reduce_mode="sum", size=[4, 4], clear=True)
T.reduce(A, row_sum_2, dims=1, reduce_mode="sum", size=[4, 8], clear=True)
T.print(row_sum, "row_sum result:")
T.print(row_sum_2, "row_sum_2 result:")
```

### 2. TVM IR 层调试（编译失败）

**检查要点：**
- Op操作数据类型、大小是否正确
- Op功能是否生效（如T.Parallel是否被向量化）
- Op是否被正确映射

**调试方法：**
在 `tilelang/language/customize_npuir.py` 中找到对应op的定义，使用pdb调试：

```python
def npuir_add(A, B, C):
    return AscendBinaryOp("add", A, B, C).buildTirCall()

class AscendBinaryOp(object):
    def buildTirCall(self):
        import pdb
        pdb.set_trace()  # 插入断点
        src0 = _to_region(self.__src0, "r", _get_extent(self.__src0))
        src1 = _to_region(self.__src1, "r", _get_extent(self.__src1))
        # 检查参数类型和值
```

### 3. MLIR 层调试（codegen问题）

如果TVM IR成功生成但没有生成MLIR，或报错信息不完整：

**方法1：使用bishengir-opt检查MLIR**
```bash
bishengir-opt debug.mlir
```

**方法2：在codegen代码中插入调试语句**
在 `tilelang-ascend/src/target/codegen_npuir_dev.cc` 中：

```cpp
void CodeGenTileLangNPUIRDEV::VreduceCodegen(const CallNode *op) {
  Value src = GetVarValue(npuirop.src);
  // 插入debug语句
  llvm::dbgs() << "[DEBUG] VreduceCodegen, src=" << src.getType() << "\n";
}
```

修改后需要重新编译：
```bash
cd tilelang-ascend/build
make
```

### 4. AscendNPUIR PASS 调试（.o文件生成失败）

**打印完整Pass：**

1. 在 `install_npuir.sh` 中添加 `--enable-ir-print` 编译选项
2. 重新编译bishengir
3. 运行以下命令打印全量Pass：

```bash
bishengir-compile tilelang_debug.mlir \
  --enable-auto-multi-buffer=True \
  --enable-auto-bind-sub-block=True \
  --enable-hfusion-compile=true \
  --enable-hivm-compile=true \
  -o test.o \
  --mlir-print-ir-before-all \
  --mlir-print-ir-after-all \
  --mlir-disable-threading \
  >compile.log 2>&1
```

4. 在日志中搜索 "fail" 定位失败的pass

**常见问题：UB overflow**
```
error: UB overflow, requires 1579008 bits while 1572864 bits available!
```

解决方法：减小block大小，降低单次循环的内存占用。

### 5. GDB 调试（core dump）

当出现 `Segmentation fault (core dumped)` 时：

```bash
gdb --args python your_script.py
(gdb) r  # 运行程序
# 程序崩溃后会显示具体位置
```

## 性能优化编译选项

在 `jit_npu.py` 中的 `compile_option_list` 可配置：

```python
_compile_option_list = [
    "--enable-auto-multi-buffer=false",  # 自动multi-buffer
    "--limit-auto-multi-buffer-only-for-local-buffer=false",  # 核间流水
    "--enable-auto-bind-sub-block=true",  # C:V 1:2分核
    "--enable-triton-kernel-compile=true",
    "--enable-hivm-compile=true",
]
```

## 总结

- **精度问题** → T.print打印中间结果
- **编译问题** → 分层定位（TVM IR → MLIR → .o），使用pdb/gdb调试
- **运行时失败** → 检查内存越界、UB overflow
- **性能优化** → 调整编译选项
