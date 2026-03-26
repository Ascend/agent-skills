---
name: catlass-operator-code-gen
description: 根据设计文档在现成 ops 工程中生成 Catlass 算子的 op_host、op_kernel 与 aclnn 调用示例（examples/test_aclnn_算子名.cpp）。从 catlass example/include 选型 tiling 与 kernel 并适配到 USER_OP_PROJECT，不整份粘贴 example；使用 TilingKey 与 TILING_KEY_IS；不运行 msopgen。Use when 已有设计文档、要在现有工程中新增 Catlass 算子、或用户要求生成 op_host/op_kernel/算子目录。需 catlass 时先 catlass-module-import。条件不明则追问。
---

# Catlass 算子代码生成

## 概述

读取设计文档，在现成工程的等价位置生成 op_host、op_kernel 源码、可调用接口（`examples/test_aclnn_<op_name>.cpp`）及算子目录 CMake；不执行 msopgen。必须在 codegen 阶段生成可运行接口，便于后续 ascendc-operator-compile-debug 与精度验证。工程目录术语与 Catlass 系列统一：**OPS_PROJECT_ROOT** = 工程根，**USER_OP_PROJECT** = `ops/<算子名>/`。详见 catlass-operator-dev 的 `references/project-directory-terms.md`。

---

## 严正约束：AICore 与 Catlass 唯一实现

**完整说明见本 skill 参考文档**：[references/aicore-ascendc-constraints.md](references/aicore-ascendc-constraints.md)（AICore/AscendC 编程约束已合入 Catlass 侧，不依赖对 AscendC skill 的修改）。

- **AICore 上标量计算极慢**：不得以 SIMT（单线程标量循环）视角编写算子代码；禁止在 Kernel 内手写逐元素标量循环（如 for(i) for(j) out[i,j]=...）。
- **仅使用 Catlass 提供的实现**：Kernel 中**只能**使用 Catlass 提供的 Block/Tile/Kernel 组合（如 `BlockMmad`、`BasicMatmul`、`MatmulEpilogue`、`BlockEpilogue`、`TileElemWiseAdd` 等），**不得**自行实现矩阵乘、逐元素加、拷贝等计算逻辑。
- **Catlass 中有完整的 mmad/epilogue 实现**：例如矩阵乘加偏置/加 D 等需求，应使用 `Gemm::Kernel::MatmulEpilogue` + `Epilogue::Block::BlockEpilogue`（如 `EpilogueAtlasA2ElemWiseOneSource` + `TileElemWiseAdd` + `TileCopy`），参考 `catlass/examples/03_matmul_add`；不得用自写标量或自写向量循环替代。
- 若设计文档要求的融合逻辑在 Catlass 中无现成组件，应先在设计阶段改为选用 Catlass 已有组件，或向用户说明需扩展 Catlass 库后再生成代码。

---

## 何时使用

- 已有 **catlass-operator-design** 产出的设计文档（或等价需求文档）
- 需要在**现有 ops 工程**中新增一个 Catlass 算子
- 用户要求生成 op_host、op_kernel 及算子目录结构

## 工程目录术语

与 catlass 系列 skill 统一：**OPS_PROJECT_ROOT** = 工程根，**USER_OP_PROJECT** = `ops/<算子名>/`。代码生成写入 **USER_OP_PROJECT**（或用户指定路径）。编译与调试使用 **ascendc-operator-compile-debug**。详见 catlass-operator-dev 的 `references/project-directory-terms.md`。

## 前置条件

| 检查项 | 说明 |
|--------|------|
| 设计文档 | 含算子名、I/O、dtype、转置等行为、参考 example、Kernel/Block/Epilogue 组件 |
| 工程结构 | 存在可放置算子的目录（见下节「交付路径」） |
| Catlass 头文件 | 算子编译需能 include catlass；若工程根尚无 catlass，先执行 **catlass-module-import**，再在算子目录的 CMake 中增加对 catlass include 的引用 |

执行时若**条件不明则追问**用户（需求、工程路径、参考 example 等）。

---

## 交付路径（等价位置）

- **常规场景**：在**与现有算子同级**的目录下创建新算子文件夹。例如工程为 `ops/` 下多算子结构，则生成到 `ops/<算子名>/`，算子名使用 **snake_case**（如 `matmul_add`）。
- **特殊工程**：若工作区并非上述结构（例如无 `ops/`、或算子不在 `ops/` 下），**先在 skill 内预留判断**；若无法确定「等价位置」，则**向用户确认**：「算子目录应放在哪一层、与哪个现有算子同级？」再按用户指定路径生成。
- **不运行 msopgen**：当前场景为在现成工程中工作；json 仅用于 msopgen 从零生成极简工程，此处不需要生成 json 或执行 msopgen。
- **可调用接口**：**必须**在算子目录下生成 `examples/test_aclnn_<op_name>.cpp`（与工程内现有算子样例路径一致，如 `ops/segsum/examples/test_aclnn_segsum.cpp`），使算子具备可运行、可出数的接口，供后续编译运行与精度验证使用。

---

## 命名与风格

| 对象 | 规范 |
|------|------|
| **算子目录/文件夹** | snake_case，如 `matmul_add` |
| **代码（类名、函数、变量）** | camelCase |
| **aclnn 接口名** | 由框架/opbuild 根据 OpDef 自动生成，保持与工程一致即可 |

---

## 代码生成原则

- **从 example/include 确定使用的模板**，但**不是**把 example 整份粘贴到工程，而是**选择性**确定 **tiling** 与 **kernel** 部分，**适配**到算子工程（大部分为 msopgen 小工程）。
- 可参考 **00_basic_matmul** 与 **advanced/basic_matmul_aclnn** 之间的规律：example 的写法 → 工程化、按工程结构拆写、写到 ops/<算子名>/ 下。
- **把代码写到工程里**，不是把 example 当最终结果粘贴；用户说「参考 basic_matmul_aclnn」时，是参考其 Tiling/Kernel 用法与结构，在工程中写出适配后的 op_host/op_kernel，**不要**直接把该 example 当作交付物。

## 代码参考与文件拆分

### 参考来源

- **Catlass 接入与 Kernel 写法**：参考 `catlass/examples/advanced/basic_matmul_aclnn` 的 op_host / op_kernel 实现（Tiling 数据结构、调用 Catlass BlockMmad/Kernel 的方式、GET_TILING_DATA 等），**按上述原则适配到本算子目录**。
- **目录与文件组织、OpDef 风格**：参考现成工程中 **ops** 下的算子（如 `ops/segsum`、`ops/catlass_example`），按**功能拆文件**，而非单文件合写。

### op_host 建议拆分

| 文件 | 职责 |
|------|------|
| `*_tiling.h` | Tiling 数据结构：`BEGIN_TILING_DATA_DEF` / `TILING_DATA_FIELD_DEF` / `REGISTER_TILING_DATA_CLASS` |
| `*_tiling.cpp` | Tiling 入口：解析输入 shape/dtype/attr，计算 TilingKey 并 `SetTilingKey`，填充 tiling 数据并 `SaveToBuffer` |
| `*_def.cpp` | OpDef 注册：Input/Output、DataType、Format、InferShape/InferDataType、SetTiling、AddConfig 等 |
| `*_infershape.cpp` | 若与 def 分离：InferShape / InferDataType 实现（也可合并在 def 中，视工程现有习惯而定） |

### op_kernel

- 使用 `GET_TILING_DATA` 取 tiling；根据 **TilingKey** 用 **`TILING_KEY_IS(key)`** 分支，每个 key 对应一种 dtype/转置等组合，调用对应 Catlass 模板实例，避免单 kernel 二进制过大、利于缓存。
- Kernel 内不写死 dtype/trans，均由 Host 设置的 TilingKey 区分。
- **禁止**在 Kernel 内手写标量/逐元素计算；**仅**使用 Catlass 提供的 Kernel/Block/Tile（如 `BasicMatmul`、`MatmulEpilogue`、`BlockEpilogue`、`TileElemWiseAdd` 等），参考 `catlass/examples/03_matmul_add`、`catlass/include/catlass/gemm/kernel/matmul_epilogue.hpp`。

### 可调用接口（必选交付）

- **aclnn 接口来源**：**aclnn 接口由工程/build 自动生成**（根据 OpDef、op_host 等），生成物在 build 的 autogen 或安装后的 op_api/include 中（如 `aclnn_<op_name>.h`、`aclnnop/aclnn_<op_name>.h`）。Codegen **不**生成 aclnn 本身，只生成**调用示例**，使算子能被编译、安装后通过官方流程跑起来。
- **路径**：`ops/<算子名>/examples/test_aclnn_<算子名>.cpp`（与工程内其他算子样例一致，如 `ops/segsum/examples/test_aclnn_segsum.cpp`）。
- **作用**：提供可执行调用示例，通过**已由工程自动生成的 aclnn 接口**调用本算子，使 **build.sh --run_example &lt;op&gt; eager cust** 能找到该文件并编译、运行，从而得到真实算子输出，便于 **ascendc-operator-compile-debug**（Catlass 算子统一使用该 skill）与 **ascendc-operator-precision-eval**（如将输出导出为 test_data.npy）。
- **内容要求**：
  1. ACL 初始化（aclInit、aclrtSetDevice、aclrtCreateStream）。
  2. 按 OpDef 的 Input/Output 创建 aclTensor（形状、dtype 与算子定义一致）；至少一组可运行的小规模输入（如 M/N/K 或 shape 常量）。
  3. 两段式调用：先 `aclnn<OpName>GetWorkspaceSize(...)` 获取 workspace 与 executor，再 `aclnn<OpName>(workspace, workspaceSize, executor, stream)` 执行。
  4. 同步（aclrtSynchronizeStream）后将输出从 device 拷回 host，并打印或写文件；**建议**支持将输出写入文件，便于与 precision_eval 的 golden 做 ct single/dual。
- **头文件**：include 工程提供的 aclnn 头文件（如 `aclnnop/aclnn_<op_name>.h`，与同工程 ops/segsum 等保持一致）；该头与 aclnn 实现由 build/安装包提供，无需在 codegen 中生成。
- **如何运行测试**：先编译并安装算子包（如 `bash build.sh --pkg --ops=<op_name> --vendor_name=custom --soc=ascend910b`），再在 **build 目录**下执行 `bash build.sh --run_example <op_name> eager cust --vendor_name=custom`；脚本会查找 `*/<op_name>/examples/test_aclnn_*.cpp` 并编译、运行。若未生成该调用示例，则无法跑通 --run_example，也无法用真实算子输出做精度验证。
- **CMake**：在 ops-project 等工程中，examples 通常**不**由算子子目录的 CMakeLists 管理，而是由根目录 build.sh 的 --run_example 逻辑直接 g++ 编译上述 .cpp；因此 codegen 只需生成 test_aclnn_<op_name>.cpp 即可。若工程约定需算子级 examples/CMakeLists.txt，则按该工程约定补充。

---

## TilingKey 设计

- **无通用规范**，由本 skill 根据设计文档自行设定；**建议编码可读**（如常量命名、注释说明含义）。
- **Host**：在 Tiling 函数中根据 dtype、transA、transB 等计算 key，调用 `context->SetTilingKey(key)`。
- **Kernel**：仅通过 `TILING_KEY_IS(key1)`, `TILING_KEY_IS(key2)` … 分支；编译时各 key 分编到不同 kernel 二进制。

---

## Catlass 头文件与依赖

- 算子目录下编译 op_kernel 时需能 `#include <catlass/...>`。
- 若工程根目录尚未有 catlass：先执行 **catlass-module-import** 在工程根引入 `catlass/`；再在**本算子目录**的 CMake 中增加对 catlass include 的引用（如 `target_include_directories(… PRIVATE ${CATLASS_DIR}/include)` 或工程内已有变量）。
- 具体变量名（如 `CATLASS_DIR`）以当前工程 CMake 约定为准。

---

## 生成流程（步骤摘要）

1. **确认交付路径**：判定工程结构，得到算子目录（如 `ops/matmul_add`）；若无法判定则询问用户。
2. **分析设计文档**：提取算子名、I/O、dtype、转置等、参考 example、Kernel/Block/Epilogue、Workspace 等。
3. **匹配 catlass example**：按设计文档中的参考 example 或模板，确定可复用的 Kernel/Block 组合与调用方式。
4. **生成 op_host**：按功能拆分为 tiling.h、tiling.cpp、def.cpp（及可选 infershape.cpp）；实现 TilingKey 计算与 SetTilingKey、Tiling 数据、InferShape、InferDataType、OpDef。
5. **生成 op_kernel**：实现 GET_TILING_DATA 与 TILING_KEY_IS 分支，各分支内调用设计文档中确定的 Catlass 模板。
6. **生成可调用接口**：在算子目录下生成 `examples/test_aclnn_<op_name>.cpp`（**调用示例**）。aclnn 接口由工程自动生成，本步只写调用该接口的示例：include 工程 aclnn 头（如 `aclnnop/aclnn_<op_name>.h`）、两段式调用（GetWorkspaceSize + 执行）、输入/输出 tensor 创建、结果拷回 host；建议支持将输出写入文件以便精度验证。运行方式：先 pkg 安装算子包，再在 build 目录执行 `build.sh --run_example <op_name> eager cust`。
7. **算子目录 CMake**：确保本算子被工程收录（如 `add_subdirectory` 或已有 GLOB），且 op_kernel 编译选项包含 catlass include 路径；若 examples 由本算子 CMake 管理，则 add_subdirectory(examples) 或等效纳入 test_aclnn 可执行文件。
8. **编译与排错**：按工程既有方式编译该算子（含样例），失败则根据报错修复生成代码或 CMake。

---

## Do（必须）

- **条件不明则追问**：需求、工程路径、参考 example 等不明时追问用户，不臆测。
- 从 example/include 选型 tiling 与 kernel 并**适配**到 **USER_OP_PROJECT**；必须生成 `examples/test_aclnn_<op_name>.cpp`。
- 编译与调试使用 **ascendc-operator-compile-debug**。

## Don't（禁止）

- 在「现成工程中新增算子」场景下运行 msopgen 或依赖 msopgen 生成当前算子目录。
- 仅生成到 catlass 仓内（如 `catlass/examples/advanced/`）而不在 **USER_OP_PROJECT** 留下算子目录；把 example 整份粘贴当交付物。
- Kernel 内用运行时 if 区分所有 dtype/转置，而不使用 TilingKey + TILING_KEY_IS 分支。
- 仅生成 op_host/op_kernel 而不生成可调用接口（examples/test_aclnn_<op_name>.cpp）。
- 误以为 codegen 需“生成 aclnn 接口”：aclnn 由工程/build 根据 OpDef 自动生成，codegen 只生成**调用**该接口的示例。
- 在 AICore Kernel 内手写标量/逐元素循环或自实现矩阵乘、逐元素加等；须使用 Catlass 提供的 Kernel/Block/Tile 组合。
- 使用已废弃的 **catlass-operator-compile-debug**（改用 ascendc-operator-compile-debug）。

---

## 参考资料

| 文档/目录 | 内容 |
|-----------|------|
| **[references/aicore-ascendc-constraints.md](references/aicore-ascendc-constraints.md)** | **AICore/AscendC 编程约束（合入 Catlass 侧）**：标量禁止、仅用 Catlass 实现、头文件顺序、03_matmul_add 参考、反模式 |
| catlass/examples/advanced/basic_matmul_aclnn | Catlass Kernel 调用、Tiling 数据结构、GET_TILING_DATA、TILING_KEY_IS |
| **catlass/examples/03_matmul_add**、**catlass/include/catlass/gemm/kernel/matmul_epilogue.hpp** | 矩阵乘+逐元素加（C+D）**仅用 Catlass 实现**：MatmulEpilogue + BlockEpilogue（EpilogueAtlasA2ElemWiseOneSource + TileElemWiseAdd + TileCopy）、Workspace 与 EpilogueParams |
| ops/segsum、ops/catlass_example | 目录结构、按功能拆分的 op_host、OpDef、CMake；**ops/segsum/examples/test_aclnn_segsum.cpp** 为可调用接口参考 |
| **ascendc-operator-compile-debug** | Catlass 算子编译/运行统一使用该 skill；aclnn 样例结构、两段式调用；build.sh --pkg 后 build.sh --run_example \<op\> eager cust |
| catlass-operator-design 产出 | 设计文档结构与必写组件 |
| catlass-module-import | 工程根引入 catlass 时调用 |
