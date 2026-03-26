# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a C++/CMake framework for developing custom AI operators targeting Huawei Ascend AI processors (CANN - Compute Architecture for Neural Networks). Operators can run on AI Core (NPU) or AI CPU, with most running on AI Core by default.

## Build Commands

```bash
# Build operator package for specific SoC (default: ascend910b)
bash build.sh --pkg --soc=ascend910b --vendor_name=custom --ops=add_example -j16

# Build all operators in ops-math package
bash build.sh --pkg --soc=ascend910b

# Build with static library
bash build.sh --pkg --static --soc=ascend910b

# Build kernel only (no host code)
bash build.sh --opkernel --soc=ascend910b --ops=add_example

# Run unit tests
bash build.sh -u --ophost --opapi --opkernel

# Generate new operator template
bash build.sh --genop=<operator_name> math

# Debug build
bash build.sh --debug --soc=ascend910b
```

**Key build options:**
- `--soc`: Target NPU (ascend910b, ascend910_93, ascend950, ascend310p, ascend310b, ascend630, ascend610lite)
- `--ops`: Specific operators to compile
- `-j`: Parallel build threads
- `-O`: Optimization level (O0-O3)
- `--pkg`: Create installable package

## Architecture

```
User Application
       ↓
aclnn API (op_api/)
       ↓
Host Layer (op_host/)
   ├── Operator Definition (def.cpp) - registers operator with framework
   ├── Shape Inference (infershape.cpp) - computes output shapes
   └── Tiling (tiling.cpp) - partitions work for parallel NPU execution
       ↓
AI Core Kernel (op_kernel/) [Ascend C implementation]
       ↓
Ascend NPU
```

**Operator Directory Structure:**
```
<operator_name>/
├── op_host/          # Host-side: operator definition, tiling, shape inference
├── op_kernel/        # AI Core kernel (Ascend C) - device-side computation
└── examples/         # Usage examples (aclnn, graph mode)
```

**Key Concepts:**
- **Tiling**: Partitioning tensors for parallel computation across AI cores
- **Tiling Keys**: Different strategies for different input shapes/scenarios
- **UB (Unified Buffer)**: On-chip memory for data transfer

## Code Style

- C++17 standard
- Format with clang-format using Google style (120 column limit)
- Configuration in `.clang-format`

## Environment

Required environment variables:
- `ASCEND_HOME_PATH`: CANN toolkit installation path
- `ASCEND_OPP_PATH`: Operator package path

Required CANN packages (version >=8.5): runtime, opbase, ascend-devkit, ge-executor, bisheng-compiler, tbe-tik, asc-tools

## Documentation

Documentation is in Chinese under `docs/zh/`:
- `docs/zh/develop/aicore_develop_guide.md` - AI Core operator development guide
- `docs/zh/develop/aicpu_develop_guide.md` - AI CPU operator development guide
- `docs/zh/invocation/quick_op_invocation.md` - Operator invocation guide
- `docs/zh/debug/op_debug_prof.md` - Debugging and profiling
- `docs/zh/context/build.md` - Build parameter reference
