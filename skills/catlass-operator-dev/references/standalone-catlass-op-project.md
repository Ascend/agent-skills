# Catlass 算子：用户工作目录独立工程（可单独编译）

## 原则

| 要求 | 说明 |
|------|------|
| **交付位置** | 算子源码与构建入口必须在**用户指定的工作目录**（如 `~/my_ops/MatmulNtAdd/`），**不得**仅以 `catlass/examples/advanced/<op>/` 为唯一交付物。 |
| **可选验证路径** | 允许先在 **catlass 仓内** `examples/advanced` 调通，再 **整目录迁移** 到用户工程；迁移后用户工程应 **不依赖** 修改 catlass 官方 `examples/CMakeLists.txt`。 |
| **依赖 catlass** | 用户工程根下 **`./catlass`**（`git clone`）或环境变量 **`CATLASS_ROOT` / `CATLASS_INCLUDE_DIR`** 指向已安装头路径。 |

## 推荐目录结构

```
<USER_WORKSPACE>/<OpProject>/          # 例: /home/me/ops/CatlassMatmulNtAdd
├── README.md                          # 依赖、编译、安装 run 包、aclnn 调用
├── CMakeLists.txt                     # 独立 CMake：msopgen + Catlass 头路径
├── catlass_<OpName>.json              # msopgen 算子描述
├── op_host/
│   ├── catlass_<OpName>.cpp
│   └── catlass_<OpName>_tiling.h
├── op_kernel/
│   └── catlass_<OpName>.cpp
└── samples/                           # 可选
    └── <op>_aclnn.cpp                 # 依赖 msopgen 生成的 aclnn_*.h
```

## 与用户协作（Agent 必做）

1. **显式确认路径**：询问或使用用户当前 **Cursor 工作区根** 下的子目录，例如 `{workspace}/catlass_ops/<OpName>/`。  
2. **生成文件**：所有 `op_host`、`op_kernel`、`json`、`CMakeLists.txt`、`README.md` 写入上述路径。  
3. **克隆 catlass**：在用户工程根执行 `git clone https://gitcode.com/cann/catlass.git catlass`（勿覆盖已有工程文件）。  
4. **CMake 要点**：`op_kernel` 需 `-I${CATLASS_INCLUDE_DIR}` 与 `-DCATLASS_ARCH=2201`（与 catlass advanced 示例一致）；`CATLASS_INCLUDE_DIR` 默认为 `${CMAKE_CURRENT_SOURCE_DIR}/catlass/include`。

## 独立 CMakeLists 最小片段

在**用户工程**的 `CMakeLists.txt` 开头保证能找到 Catlass：

```cmake
cmake_minimum_required(VERSION 3.16)
project(CatlassCustomOp LANGUAGES CXX)

if(NOT DEFINED CATLASS_INCLUDE_DIR)
  set(CATLASS_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/catlass/include" CACHE PATH "Catlass headers")
endif()
if(NOT EXISTS "${CATLASS_INCLUDE_DIR}/catlass/catlass.hpp")
  message(FATAL_ERROR "Catlass 头文件未找到。请在工程根执行: git clone https://gitcode.com/cann/catlass.git catlass")
endif()

if(NOT DEFINED NPU_MODEL OR NPU_MODEL STREQUAL "")
  set(NPU_MODEL "Ascend910B1" CACHE STRING "msopgen -c ai_core-<NPU_MODEL>")
endif()
```

- **msopgen gen 只执行一次**：用 `add_custom_command(OUTPUT stamp_file ...)` 生成 msopgen 并拷贝 op 文件，再 `add_custom_target(gen DEPENDS stamp_file)`；向 `op_kernel/CMakeLists.txt` 追加 `add_ops_compile_options` 时用 `grep -q 'add_ops_compile_options' ... || echo '...' >> ...` 避免重复 append（否则先编 run 再编 sample 会重复执行 gen 导致重复行）。
- **sample 头文件**：sample 若使用 `golden.hpp`/`helper.hpp`（来自 catlass `examples/common`），必须为 sample 的 `target_include_directories` 增加 **`${CATLASS_INCLUDE_DIR}`** 与 **`${CATLASS_ROOT}/examples/common`**，否则编译 sample 会报找不到 catlass 头文件。
- **一键构建**：提供 `add_custom_target(<op>_all DEPENDS <op>_sample)`，推荐只执行 `cmake --build . --target <op>_all`，避免分两次编 run 与 sample 触发重复 gen。

## 编译命令（用户工程）

```bash
cd <USER_WORKSPACE>/<OpProject>
test -d catlass/include || git clone https://gitcode.com/cann/catlass.git catlass
mkdir -p build && cd build
cmake .. -DNPU_MODEL=Ascend910B1
cmake --build . --target <op>_all
```

- 使用 **单一 target `<op>_all`**（依赖 sample，sample 依赖 run_package），一次编出 run 包与 sample；不要分两次 `--target run_package` 与 `--target sample`，以免重复触发 gen 导致 `op_kernel/CMakeLists.txt` 重复 append。

## 从 catlass 仓内迁移到用户目录

```bash
# 已在 catlass/examples/advanced/MyOp 调通后
rsync -a --exclude=build --exclude=msopgen \
  catlass/examples/advanced/MyOp/  /path/to/user/MyOp/
cd /path/to/user/MyOp && rm -f ../../examples/CMakeLists.txt  # 勿依赖上级 add_subdirectory
# 在用户 MyOp 根补齐独立 CMakeLists、README，并设置 CATLASS_INCLUDE_DIR
```

## 与子 Skill 对应关系

| Skill | 在本流程中的职责 |
|-------|------------------|
| **ascendc-operator-project-msopgen-init** | 若用户要 **纯 msopgen 空壳** 再填 kernel，可用；Catlass 算子通常直接用 **json + op_host/op_kernel** 即可。 |
| **catlass-module-import** | 在 **OPS_PROJECT_ROOT** 下拉取 **`./catlass`**，并给工程内 `op_kernel` CMake 打 Catlass 头文件补丁。 |
| **catlass-operator-code-gen** | 输出写入 **USER_OP_PROJECT**（`ops/<算子名>/`）；含 `examples/test_aclnn_<op>.cpp`。 |
| **ascendc-operator-compile-debug** | 在用户工程 `build/` 下编译、部署、运行。 |
