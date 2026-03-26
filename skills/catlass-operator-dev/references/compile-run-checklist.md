# Catlass 算子：编译与运行执行清单（Agent 必须执行）

**原则**：完成代码生成后，Agent **必须主动执行** 本清单中的命令，直至**编译通过**；若有 NPU/运行环境则**继续执行运行**并报出结果。不得仅生成代码或文档后结束。

## 适用工程

- **用户工作区独立工程**：`<USER_OP_PROJECT>`，例如 `catlass_ops/MatmulNtAdd/`。
- 工程内含：`CMakeLists.txt`、`op_host/`、`op_kernel/`、`*.json`，且 CMake 支持 `CATLASS_INCLUDE_DIR`（含 `../../catlass` 或 `./catlass`）。

## 环境前置

| 检查项 | 命令/说明 |
|--------|-----------|
| CANN | `echo $ASCEND_HOME_PATH` 非空；若空则提示用户设置，并**仍尝试**用常见路径（如 `/usr/local/Ascend`）执行一次 |
| Catlass 头文件 | 工程根或 `../../catlass/include/catlass/catlass.hpp` 存在；若不存在则先 `git clone https://gitcode.com/cann/catlass.git catlass`（在工程根）或创建 `ln -s ../../catlass catlass` |
| NPU_MODEL | 未设置时 CMake 默认 Ascend910B1；可传 `-DNPU_MODEL=...` |

## CMake 工程要求（生成/迁移时必满足）

1. **run 包与 sample 依赖**：不要分两次指定 target 分别编译 run 再编译 sample，否则会因 sample 依赖 run 而再次触发 gen，导致向 `op_kernel/CMakeLists.txt` 重复 append。
   - **做法**：使用 **单一 build target** 一次编完。工程中应提供「一键 target」依赖 sample（sample 已依赖 run_package），例如 `matmul_nt_add_all`（`add_custom_target(<op>_all DEPENDS <op>_sample)`），Agent 与用户只执行：`cmake --build . --target <op>_all` 或 `cmake --build . --target <op>_sample`。
   - **gen 只执行一次**：msopgen 生成与拷贝、向 `op_kernel/CMakeLists.txt` 追加 `add_ops_compile_options` 必须**只执行一次**。做法：用 `add_custom_command(OUTPUT stamp_file ...)` + stamp 依赖的 `add_custom_target`，run_package 依赖该 target；追加前用 `grep -q 'add_ops_compile_options' ... || echo ... >> ...` 避免重复写入。
2. **sample 依赖 Catlass 头文件**：samples 中若包含 `golden.hpp`、`helper.hpp` 等（来自 catlass `examples/common`），它们会 include `catlass/` 下头文件。**必须**在 sample 的 `target_include_directories` 中同时加入 **`${CATLASS_INCLUDE_DIR}`** 与 **`${CATLASS_ROOT}/examples/common`**，否则编译 sample 会报找不到 catlass 头文件。

## 步骤 1：配置与一次性编译（必须执行）

在 **<USER_OP_PROJECT>** 目录下执行（路径替换为实际工程根）：

```bash
cd <USER_OP_PROJECT>
export ASCEND_HOME_PATH=${ASCEND_HOME_PATH:-/usr/local/Ascend/ascend-toolkit/latest}
rm -rf build
mkdir -p build && cd build
cmake .. -DNPU_MODEL=Ascend910B1
cmake --build . --target <op>_all
```

- **推荐**：`<op>_all` 为工程中「一键构建」target（依赖 sample，sample 依赖 run_package），例如 MatmulNtAdd 为 `matmul_nt_add_all`。若无 `_all`，则用 `cmake --build . --target <op>_sample`（会先构建 run_package 再构建 sample；工程 CMake 须已按上文用 stamp 与 grep 避免重复 append）。
- **禁止**：先 `--target <op>_run_package` 再 `--target <op>_sample` 的分开编译，除非 CMake 已保证 gen 只执行一次且追加 idempotent。
- **若 cmake 或 build 失败**：根据 **ascendc-operator-compile-debug** 诊断修复后重试；若报缺少 catlass 头文件，检查 sample 的 `target_include_directories` 是否含 `CATLASS_INCLUDE_DIR` 与 `examples/common`。
- **成功标志**：生成 `build/msopgen/build_out/custom_opp_*.run` 与 sample 可执行文件（如 `build/matmul_nt_add_sample`）。

## 步骤 2：安装 run 包并运行样例（有 NPU 时执行）

```bash
cd <USER_OP_PROJECT>/build/msopgen/build_out
chmod +x ./custom_opp_*.run
./custom_opp_*.run
export LD_LIBRARY_PATH=$ASCEND_HOME_PATH/opp/vendors/customize/op_api/lib/:${LD_LIBRARY_PATH}
cd <USER_OP_PROJECT>/build
./matmul_nt_add_sample 256 256 256 0
```

- 若无 NPU 或运行报错（如设备不可用）：在流程总结中说明「编译已通过，运行未执行/失败：原因…」，并给出用户后续手动运行命令。

## 步骤 3：结果汇报

- **编译成功**：明确写出「算子包与样例已编译通过」，并给出生成的 run 包路径、样例可执行文件路径。
- **运行成功**：写出「样例运行通过，Compare success（或等价输出）」。
- **运行未执行/失败**：写出原因及用户可自行执行的完整命令。

## 环境缺失时的汇报

- 若 **cmake** 报错「未找到 msopgen」或「请设置 ASCEND_HOME_PATH」：说明当前环境未安装 CANN 或未设置 `ASCEND_HOME_PATH`，**流程已按 skill 执行完毕**；在总结中写明「编译未通过：需安装 CANN 并设置 ASCEND_HOME_PATH 后，在工程根执行下方命令」，并给出完整命令（步骤 1～2）供用户在本机执行。
- 若 **编译通过但无 NPU**：说明「算子包与样例已编译通过；运行未执行（无 NPU/设备）」，并给出用户在有 NPU 时的运行命令。

## 步骤 4：精度验证交付（提供 aclnn example 即可）

**AscendC 精度验证方说明**：**只要提供 aclnn example，即可进行精度测试**。本流程的精度相关**交付物**为可编译、可运行的 aclnn 调用示例（`ops/<op_name>/examples/test_aclnn_<op_name>.cpp`），**不要求** Agent 在本地执行 ct single/dual 或自建 Python 比对、生成精度报告。

- **Agent 责任**：确保 codegen 已生成 `test_aclnn_<op_name>.cpp`，且通过 compile-debug 与 `build.sh --run_example` 验证该示例可编译、可运行；将该示例作为交付物供精度团队使用。
- **精度团队**：在获得该 aclnn example 后，由精度团队执行完整精度测试（如 ct single/dual、.npy 标杆等）；可参考 **ascendc-operator-precision-eval**（`skills/ascendc-operator-precision-eval/SKILL.md`）了解标准与流程。
- **精度不通过时**：必须按主 Skill **catlass-operator-dev** 中「精度不通过时的分析与修复」执行：阅读 op_kernel/op_host 源码与设计文档、分析原因，调用 **catlass-operator-code-gen** / **catlass-operator-design**（或 ascendc-operator-design）修复，再重新编译与精度测试；不得仅汇报 FAIL 即结束。
- **禁止**：在未实际执行完整精度流程时声称已完成精度验证或编造精度报告。

## ops-project 风格工程的运行方式

- 若工程为 **ops-project**（根目录有 `build.sh`、`ops/`，aclnn 由 build 自动生成）：
  1. **调用示例**：算子须有 `ops/<op_name>/examples/test_aclnn_<op_name>.cpp`（codegen 阶段必须生成），该文件仅负责**调用**已由工程自动生成的 aclnn 接口，不生成 aclnn 本身。
  2. **编译安装**：在工程根目录执行 `bash build.sh --pkg --ops=<op_name> --vendor_name=custom [--soc=ascend910b]`，安装算子包。
  3. **运行测试**：进入 **build 目录** 执行 `bash build.sh --run_example <op_name> eager cust --vendor_name=custom`；脚本会查找 `*/<op_name>/examples/test_aclnn_*.cpp` 并编译、运行。若无该调用示例文件，则无法跑通测试。

## 与 catlass 仓内示例的区别

- 若工程在 **catlass 仓库内** `examples/advanced/<op>/`：使用 `bash scripts/build.sh <op>`（在 catlass 根目录），输出在 `output/`。
- 本清单针对 **用户工作区** 的独立工程（ops-project 或等价结构）；**精度验证交付**以提供可运行的 aclnn example 为准，实际精度测试由精度团队在获得该示例后进行（见 ascendc-operator-precision-eval）。
