---
name: catlass-operator-design
description: 将 Catlass 算子需求转化为完整设计文档。输入需求（自然语言或结构化），输出含 Kernel、Block、Tile、Epilogue 等组件的设计文档。设计前须存在 catlass 并阅读其文档与示例；若无则先调用 catlass-module-import。Use when 用户要开发 Catlass 算子、需要从需求到设计文档、或提到「样例设计」。条件不明则追问。
---

# Catlass 算子设计

## 概述

输入用户需求（自然语言或结构化），输出完整、可被 catlass-operator-code-gen 直接使用的设计文档。设计须基于对 catlass 仓库的阅读与理解，以问答方式确认需求，文档中须明确 Kernel、Block、Tile、Epilogue 等组件选型与组装。

## 何时使用

- 用户要开发 Catlass 算子，需要从需求到设计文档
- 用户口述或提供需求（自然语言或结构化）
- 需在设计文档中明确 Kernel、Block、Tile、Epilogue 等组件选型与组装
- 用户提到「样例设计」时，按本 skill 同一流程处理

---

## 前置条件：catlass 仓库

- **必须**在设计中基于 catlass 仓库：没仓库无法编译，用户迟早要拉下来；阅读其文档与代码，领略**开发形式**与**多种模板**，据此选型与变通；**阅读 ≠ 照抄**。
- 若工作区内**不存在**可访问的 catlass 目录（即 **OPS_PROJECT_ROOT**/catlass/，含 `include/`、`examples/`）：
  - **先调用 catlass-module-import** 引入 catlass，再继续设计。
- 设计文档中须写明：参考的 example/模板路径、选型理由、以及无完全匹配时的变通方案。

## 选型与适配原则（设计指导 code-gen）

- 从 **example** 和 **include** 中确定要用的模板，但**不是**把 example 的代码整份粘贴到算子工程，而是**选择性**确定 **tiling** 与 **kernel** 部分，**适配**到算子工程。
- 大部分算子工程基于 msopgen 小工程；可参考 **00_basic_matmul** 与 **advanced/basic_matmul_aclnn** 之间的对应规律（example → 工程化、按工程结构拆写）。
- **把代码写到工程里**，不是把某个 example 当最终结果粘贴进去；用户说「参考 basic_matmul_aclnn」时，是参考其用法与结构，再在工程中写出适配后的 op_host/op_kernel，而非直接以该 example 为交付物。

---

## 必读参考（生成设计文档前）

- **MANDATORY**：[references/requirements.md](references/requirements.md) — 需求格式与示例
- **MANDATORY**：[references/design-document.md](references/design-document.md) — 设计文档结构与**必须包含的 Kernel/Block/Tile/Epilogue 说明**
- **MANDATORY**：[references/matmul-templates.md](references/matmul-templates.md) — 模板清单、选型与变通
- **MANDATORY**：[references/epilogue-components.md](references/epilogue-components.md) — Epilogue 组件选型
- **MANDATORY**：[references/aicore-ascendc-constraints.md](references/aicore-ascendc-constraints.md) — AICore/AscendC 约束（仅用 Catlass 组件，禁止自写标量/向量循环）

以上位于本 skill 的 `references/`；**选型与变通时须结合 catlass 仓库中的 examples 与 include 代码**。

---

## 需求输入与追问

- 用户可能**直接说出需求**，也可能**不说**。执行本 skill 时：**若认为信息不足，则继续追问**，直到足以产出设计文档。
| 形式 | 说明 |
|------|------|
| 自然语言 | 口述算子名、功能、I/O、dtype、目标芯片；Agent 整理后写设计文档 |
| 结构化需求 | 符合 `requirements.md` 的章节 |

输出均为同一套设计文档结构。

---

## 设计流程

### 1. 需求分析

- 提取：算子功能、数学公式、I/O、dtype、布局、目标 SoC、约束
- 使用术语：GM、UB、L1、Tiling、M/N/K、SplitK（见 [references/design-document.md](references/design-document.md)）

### 2. 阅读 catlass 并选型

- **阅读** catlass 仓库：`examples/`、`include/` 下的文档与代码，**领略**开发形式与模板种类（如 00_basic_matmul、Matmul+GELU、Matmul+Add 等）。
- 在 `examples/` 中按功能找**相似示例**，在设计文档中写明：选中的 example 路径、选型理由。
- 若无完全匹配：基于 [references/matmul-templates.md](references/matmul-templates.md) 与仓库中现有样例，说明**变通方案**（如基于某 example 增加 Epilogue、改用 SplitK 等）。

### 3. 组件选型与文档输出

- Epilogue：按 [references/epilogue-components.md](references/epilogue-components.md) 选 Tile/Block 组件（如 GELU、Add、TileCopy、BlockEpilogue 等）。
- BlockMmad、DispatchPolicy、BlockScheduler：按 [references/matmul-templates.md](references/matmul-templates.md) 与仓库代码确定。
- 文档须**显式写出**：ArchTag、BlockMmad（L1/L0 TileShape、AType/BType/CType）、BlockEpilogue（Tile/Block 组件）、BlockScheduler、Kernel 类型，便于 `catlass-operator-code-gen` 使用。

---

## 设计文档必须包含的章节

与 [references/design-document.md](references/design-document.md) 对齐，**必须包含 Kernel、Block、Tile、Epilogue 等组件说明**：

1. **概述**：功能、场景、数学公式、变量说明
2. **输入输出信息表**：变量名、类型、Shape、描述
3. **核心组件结构**（必写）：ArchTag、BlockMmad、BlockEpilogue、BlockScheduler、Kernel；可结合 catlass 仓与 references 总结
4. **模板组装流程**：从 include/examples 或模板清单的选取与组合；无现成样例时写「基于某样例的修改步骤」
5. **性能与 Tiling 考虑**：静态 Tiling、TileShape、DispatchPolicy（简要）
6. **接口与使用**：与 aclnn/AscendC 算子注册、Tiling、workspace 的对应
7. **扩展性**：dtype/布局/芯片扩展点
8. **模板支持情况**：无完全匹配时写**缺口**与**变通方案**
9. **实现方案纲要**：Host（Tiling、InferShape、InferDataType、注册）与 Kernel（模板实例化、入口）要点；指导 `catlass-operator-code-gen`，不要求完整可编译代码

---

## 工程目录术语

与 catlass 系列 skill 统一：**OPS_PROJECT_ROOT** = 含 `build.sh`、`ops/` 的工程根；**USER_OP_PROJECT** = `ops/<算子名>/`。设计文档须写明交付路径 **USER_OP_PROJECT**（或用户指定路径）。详见 catlass-operator-dev 的 `references/project-directory-terms.md`。

## Do（必须）

- **条件不明则追问**：信息不足则继续追问，以问答确认需求与设计要点，不臆测。
- 设计前必须存在 catlass 仓库并阅读其文档与代码（领略开发形式与多种模板，非照抄）；若无则先调用 **catlass-module-import**。
- 设计文档明确：算子名、参考 example/模板、Kernel/Block/Tile/Epilogue、Epilogue/workspace、**USER_OP_PROJECT**。

## Don't（禁止）

- 把 example 整份照抄到设计或后续代码中；须选型 tiling 与 kernel 并适配到 **USER_OP_PROJECT**。
- 在设计或实现中使用 Catlass 未提供的自写标量/向量循环（见 aicore-ascendc-constraints）。

## 注意事项

- 设计文档是 **catlass-operator-code-gen** 的直接输入。
