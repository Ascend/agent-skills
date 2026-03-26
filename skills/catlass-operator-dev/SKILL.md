---
name: catlass-operator-dev
description: 编排 Catlass 算子端到端开发工作流。顺序：project-init、catlass-module-import、设计、代码生成、编译调试、精度验证（ascendc-operator-precision-eval）、可选文档。交付物为可独立编译的算子工程与可运行的 aclnn 示例。Use when 用户要开发新 Catlass 算子、实现算子、创建算子或需要完整流程引导。条件不明则追问。
---

# Catlass 算子端到端开发

## 概述

编排 Catlass 算子的完整开发流程：初始化工程 → 引入 catlass → 设计 → 代码生成 → 编译/运行 → 精度验证 → 可选文档。交付物在用户工作目录下、可独立编译的算子工程；编译与调试统一使用 **ascendc-operator-compile-debug**。

## 何时使用

- 用户要开发新 Catlass 算子、实现算子、创建算子或需要从零到可运行/可验证的完整流程引导
- 用户希望按固定顺序执行：工程初始化 → 引入 catlass → 设计 → 代码生成 → 编译与精度验证

## 工程目录术语（统一）

Catlass 系列 skill 统一使用以下术语，详见 [references/project-directory-terms.md](references/project-directory-terms.md)：

- **OPS_PROJECT_ROOT**：含 `build.sh`、`ops/` 的工程根目录；catlass 克隆到此处，即 `<OPS_PROJECT_ROOT>/catlass/`。
- **USER_OP_PROJECT**：单个算子目录 `<OPS_PROJECT_ROOT>/ops/<算子名>/`，设计/代码生成/编译的交付与操作对象。

## Do（必须）

- **条件不明则追问**：用户可能直接说出需求也可能不说；若信息不足则继续追问，不臆测。
- 交付物在 **USER_OP_PROJECT**（可独立编译的算子工程）；步骤 2 在 **OPS_PROJECT_ROOT** 执行 clone 与 CMake 补丁。
- 代码生成统一使用 **catlass-operator-code-gen**（已废弃 catlass-example-to-kernel）。
- 编译、部署、运行使用 **ascendc-operator-compile-debug**。
- 精度验证使用 **ascendc-operator-precision-eval**；若实在无法继续（无 NPU、无 ct、无法获得标杆数据等），向用户说明**具体原因**并**停止后续工作**，不编造报告。

## Don't（禁止）

- 仅提及“请使用 project-init / module-import”而不**实际按两 Skill 的步骤执行**。
- 在未完成步骤 1 的情况下在任意目录执行步骤 2。
- 在 `ops/<算子名>/` 下克隆 catlass（必须在 **OPS_PROJECT_ROOT** 下）；使用 `git clone ... .` 覆盖当前目录。
- 仅把实现放在 `catlass/examples/advanced/` 而不在 **USER_OP_PROJECT** 落地。
- 使用已废弃的 **catlass-example-to-kernel** 或 **catlass-operator-compile-debug**。
- 精度验证：在未实际执行完整精度流程时声称已完成或编造报告；精度 FAIL 时仅汇报而不分析、不调用 code-gen/design 修复即结束。

## 技能概览与调用顺序

| 顺序 | 子 Skill | 职责 |
|------|----------|------|
| 1 | **ascendc-operator-project-init** | 初始化 AscendC 算子工程（opgen 生成 `ops/<op_name>/`） |
| 2 | **catlass-module-import** | 在**算子工程根目录**下引入 catlass（克隆到 `<工程根>/catlass/` + CMake 引入头文件） |
| 3 | **catlass-operator-design** | 需求 → 设计文档 |
| 4 | **catlass-operator-code-gen**  | 设计  → 在用户工程内生成算子实际代码 |
| 5 | **ascendc-operator-compile-debug** | 在用户工程内编译、部署与测试 |
| 6 | **ascendc-operator-precision-eval** | **精度验证**：按该 skill 执行；若实在无法继续则向用户说明具体原因并停止后续工作 |
| 7 | **ascendc-operator-doc-gen** | README / aclnn 接口文档（可选） |

## 流程总览

```
  步骤 1：调用 ascendc-operator-project-init
          → 得到 ops-project 根目录及 ops/<op_name>/
              │
              ▼
  步骤 2：在工程根目录调用 catlass-module-import
          → 工作目录 = <OPS_PROJECT_ROOT>/（含 build.sh、ops/）
          → 克隆 catlass 到 <OPS_PROJECT_ROOT>/catlass/、补丁 CMake
              │
              ▼
  catlass-operator-design → 设计文档
              │
              ▼
  catlass-operator-code-gen → 写入 <USER_OP_PROJECT>/{op_host,op_kernel,...}
              │
              ▼
  ascendc-operator-compile-debug → 编译、部署、运行、报结果
              │
              ▼
  ascendc-operator-precision-eval → 精度验证（准备 golden、运行 aclnn 示例得输出、ct single/dual、报告）
              │
              ├─ 若精度 FAIL → 阅读源码与文档、分析原因、调用 code-gen/design 修复 → 重新编译与精度测试
              │
              ▼
  ascendc-operator-doc-gen（可选）
```

---

## 步骤 1：调用 ascendc-operator-project-init 初始化算子工程

**目标**：在用户工作区得到完整的 AscendC 算子工程（opgen 结构），以便后续在该工程内引入 catlass。

**做法**：Agent **必须按 ascendc-operator-project-init 的完整流程执行**，而不是只“提及”该 Skill。具体包括：

1. **按 ascendc-operator-project-init 的步骤执行**  
   - 检查当前目录是否为算子工程（`build.sh`、`CMakeLists.txt`、`ops/` 或 `examples/`）。  
   - 若非算子工程：从该 Skill 的 `templates/ops-project` 复制模板到当前目录或用户指定位置。  
   - 收集并确认：算子名称 `op_name`（snake_case）、算子类型 `op_type`（固定 `ops`）、输出路径（固定 `./`）。  
   - 调用 opgen：  
     `python3 scripts/opgen/opgen_standalone.py --op_type ops --op_name <op_name> --output_path ./`  
   - 验证生成结果：确认存在 `./ops/<op_name>/`，且其下含 `op_host/`、`op_kernel/`、`CMakeLists.txt`、`examples/` 等。

2. **确定工程目录**  
   - **OPS_PROJECT_ROOT** = 当前含 `build.sh`、`ops/` 的根目录；步骤 2（clone catlass）须在此目录执行。  
   - **USER_OP_PROJECT** = `<OPS_PROJECT_ROOT>/ops/<op_name>/`；步骤 3、4 的设计与代码生成针对此目录（除非用户指定其他路径）。

**检查点**：  
- 已存在 `./ops/<op_name>/CMakeLists.txt`、`op_host/`、`op_kernel/`。  
- 已向用户展示目录结构及“下一步：在算子目录内引入 catlass”。

---

## 步骤 2：在工程根目录调用 catlass-module-import 引入 catlass

**目标**：在**算子工程根目录**（`<OPS_PROJECT_ROOT>`）下引入 catlass 库（克隆到工程根并配置 CMake），使所有 Catlass 算子可引用同一份 catlass 头文件。

**约定**：catlass **必须**克隆在**算子工程根目录**下，即 `<OPS_PROJECT_ROOT>/catlass/`。**禁止**在算子子目录 `ops/<op_name>/` 下克隆。

**做法**：Agent **必须按 catlass-module-import 的约定执行**，且工作目录为**步骤 1 的算子工程根目录 `<OPS_PROJECT_ROOT>`**（即包含 `build.sh`、`ops/` 的目录，而非 `ops/<op_name>/`）。

1. **切换工作目录**  
   - `cd <OPS_PROJECT_ROOT>`  
   - 确保当前目录含 `build.sh`、`ops/`，与 `ops/<op_name>/` 同级（不要进入 `ops/<op_name>/`）。

2. **按 catlass-module-import 执行**  
   - 若已存在 `./catlass` 且含 `include/`：**跳过克隆**，仅做 CMake 补丁。  
   - 否则：`git clone https://gitcode.com/cann/catlass.git catlass`（在工程根下得到 `./catlass/`；**禁止**在 `ops/<op_name>/` 下 clone；**禁止** `git clone … .` 覆盖当前目录）。  
   - 在工程根或对应 CMake 中，将 `CATLASS_DIR` 设为**工程根下的 catlass**（如 `${CMAKE_SOURCE_DIR}/catlass`），并为 kernel 编译增加 `-I${CATLASS_DIR}/include` 或 `ascendc_include_directories(${CATLASS_DIR}/include)`。  
   - 若存在含 ASC 的 `project(...)`，按 catlass-module-import 说明增加  
     `include_directories($<$<COMPILE_LANGUAGE:ASC>:${CATLASS_DIR}/include>)`。  
   - 参考 catlass 的 README.md，补充所需其他配置（若有）。

3. **验证**  
   - `test -d catlass/include && test -f catlass/include/catlass/catlass.hpp`（在工程根下执行）。

**检查点**：  
- `<OPS_PROJECT_ROOT>/catlass/` 已存在且可访问头文件。  
- 工程内 kernel 编译已包含 catlass 的 include 路径（`CATLASS_DIR` 指向工程根下的 `catlass`），后续各算子 Kernel 可 `#include` catlass。

---

## 阶段 3～7 简述

- **阶段 3**：**catlass-operator-design** — 输入需求，输出设计文档。  
- **阶段 4**：**catlass-operator-code-gen** — 默认输出根目录 = **USER_OP_PROJECT**；**必须**生成可调用接口 `examples/test_aclnn_<op_name>.cpp`，供编译运行与精度验证使用。  
- **阶段 5**：**ascendc-operator-compile-debug** — 在用户工程内执行完整编译与（若有 NPU）部署、运行，并汇报结果。  
- **阶段 6**：**ascendc-operator-precision-eval** — 按该 skill 执行精度验证。若**实在无法继续**（无 NPU、无 ct 工具、无法获得标杆数据等），向用户说明**具体原因**并**停止后续工作**。精度不通过时：阅读源码与文档、分析原因，调用 **catlass-operator-code-gen** / **catlass-operator-design** 修复后重新编译与精度测试。  
- **阶段 7**：**ascendc-operator-doc-gen** — 基于用户工程生成 README / aclnn 文档（可选）。

---

## 步骤 6：使用 ascendc-operator-precision-eval 进行精度验证

**目标**：按 **ascendc-operator-precision-eval** 的流程执行精度验证（准备标杆数据、运行 aclnn 示例得到算子输出、ct single/dual、生成报告）。

**前置**：codegen 已生成 `test_aclnn_<op_name>.cpp`，compile-debug 已确保可编译、可运行（`build.sh --run_example <op_name> eager cust` 能跑通）。

**做法**：

- **调用 ascendc-operator-precision-eval**：按该 skill 执行——准备 golden、运行 aclnn 示例得到算子输出、ct single/dual、生成报告。
- 若**实在无法继续**（如无 NPU、无 ct 工具、无法获得标杆数据等）：向用户明确说明**具体原因**，并**停止后续工作**；不编造精度报告、不声称已完成精度验证。

**检查点**：  
- 具备条件时：已按 ascendc-operator-precision-eval 执行并得到精度结论（PASS/FAIL）与报告。  
- 无法继续时：已向用户说明具体原因并停止。

### 精度不通过时的分析与修复（必须执行）

当用户或本流程已执行完整精度测试（如 `run_precision_full.sh` 或精度团队反馈）且结果为 **FAIL** 时，Agent **必须**按以下步骤处理，不得搁置或仅汇报“精度不通过”即结束。

1. **阅读源码与文档**  
   - 阅读当前算子的 **op_kernel** 源码（`ops/<op_name>/op_kernel/*.cpp`、`*_tiling_key.h` 等），核对是否实现设计文档中的算法与 Epilogue（如仅实现 A\*B 未加 D 会导致 MatmulAdd 类算子精度失败）。  
   - 阅读 **op_host** 中 Tiling、InferShape、InferDataType、属性传递，确认与 kernel 侧数据布局、dtype、TilingKey 一致。  
   - 阅读 **设计文档**（算子目录或工程内的设计 doc）、**catlass 文档**（如 Block/Tile/Epilogue 用法、参考 example），以及 **ascendc-operator-design** / **catlass-operator-design** 中与当前算子相关的约束。

2. **分析原因**  
   - 根据精度报告（MERE/MARE、ERR_COUNT 等）与源码对照，归纳可能原因：算法遗漏（如缺 Epilogue 加项）、布局或 stride 错误、dtype/转换问题、Tiling 与 kernel 分块不一致、Host 与 Kernel 对 TilingKey 或属性的解释不一致等。  
   - 给出简短结论（例如：“Kernel 仅实现 C=A\*B，未实现 C+D，需增加 Epilogue 或后处理加 D”）。

3. **调用相关 Skill 修复**  
   - 若问题在 **Kernel/Epilogue 或 Host 与 Kernel 接口**：按 **catlass-operator-code-gen** 的规范修改 `op_kernel`/`op_host` 源码（参考设计文档与 catlass 示例），必要时先查阅 **catlass-operator-design** 确认 Epilogue/Block 选型。  
   - 若问题在 **设计本身**（组件选型、Tiling 策略、Epilogue 定义）：调用 **catlass-operator-design** 更新设计文档，再按 **catlass-operator-code-gen** 落地代码。  
   - 若涉及 **AscendC 层算法或 Tiling 规范**：可参考 **ascendc-operator-design**。  
   - 修改后必须再次执行 **ascendc-operator-compile-debug** 确保编译、运行通过，再重新跑精度测试并依据结果迭代或向用户汇报。

**检查点**：  
- 已阅读算子 kernel/host 源码与设计文档并写出原因分析。  
- 已调用上述至少一个子 Skill 进行修复并完成编译/运行验证；若无法在本轮修复完成，需明确说明剩余问题与建议下一步。

## 参考资料

- [project-directory-terms.md](references/project-directory-terms.md)：工程目录术语（OPS_PROJECT_ROOT / USER_OP_PROJECT）  
- [standalone-catlass-op-project.md](references/standalone-catlass-op-project.md)：独立工程布局与 CMake 片段  
- [compile-run-checklist.md](references/compile-run-checklist.md)：编译、运行与精度验证清单  
- [subskill-deps.md](references/subskill-deps.md)：子 Skill 依赖说明  
- **ascendc-operator-project-init**、**catlass-module-import**、**ascendc-operator-compile-debug**、**ascendc-operator-precision-eval**
