---
name: catlass-operator-design
description: 将用户基于CATLASS开发算子的需求转变为具体的设计文档
---

# CATLASS 算子设计

## 核心工作流

```
需求分析 → 阅读 catlass 仓库 → 组件选型（含 Epilogue：现成 / 自定义）→ 输出设计文档
```

## 0. 前置条件与约束

### 前置条件

| 检查项 | 说明 |
|--------|------|
| catlass 仓库 | 须在 **OPS_PROJECT_ROOT** 下可访问 `catlass/`（含 `include/`、`examples/`）。缺失时按 **catlass-operator-dev** 步骤 2 在工程根克隆；设计前至少能打开 `examples/` 与选型相关头文件 |
| 必读参考 | 生成设计文档前，**必须**阅读以下文件（位于本 skill 的 `references/`） |

### 必读参考

| 文件 | 用途 |
|------|------|
| [references/design-document.md](references/design-document.md) | 设计文档模板——用选型表格描述组件，不写代码 |
| [references/matmul-templates.md](references/matmul-templates.md) | 模板清单、选型指南与 DispatchPolicy 速查 |
| [references/epilogue-components.md](references/epilogue-components.md) | Epilogue 组件分类与组合模式 |
| [references/custom-epilogue.md](references/custom-epilogue.md) | **无现成 Tile 时**：先检索再设计自定义 Epilogue 的契约（不写代码） |
| catlass/docs/3_API/gemm_api.md | Gemm API 分层模型与组件对照表，理解 Kernel/Block/Tile/Basic 各层关系 |

**选型与变通时须结合 catlass 仓库中的 examples 与 include 代码**。

### 工程目录术语

与 catlass 系列 skill 统一：**OPS_PROJECT_ROOT** = 含 `build.sh`、`ops/` 的工程根；**USER_OP_PROJECT** = `ops/<算子名>/`，其中 **`<算子名>` 须含 `catlass`**。设计文档须写明交付路径 **USER_OP_PROJECT**（或用户指定路径）。

### 选型与适配原则

- 从 catlass **example** 和 **include** 中确定要用的模板，但**不是**把 example 整份粘贴到算子工程，而是**选择性**确定 tiling 与 kernel 部分，**适配**到算子工程结构。
- 大部分算子工程基于 msopgen 小工程，example 中的 Host 调用代码需要改写为工程中的 op_host/op_kernel 分离结构。
- 设计阶段只产出**选型决策**（哪个模板、哪些组件、什么 TilingKey），代码由 code-gen 生成。

### 算子命名（强制）

- **`op_name`（snake_case）必须包含子串 `catlass`**，例如：`catlass_matmul_add`、`catlass_fused_gemm_bias`、`catlass_batched_gemm_gelu`。推荐前缀形式 `catlass_` + 语义后缀。
- **禁止**单独使用易与框架或其它厂商算子冲突的短名（如 `matmul_add`、`matmul`、`gemm_add` 等无 `catlass` 标识的名字），否则 OPP 中已存在的同名 `aclnn_*.h` / 符号会导致编译链接错误或与错误 API 签名匹配。
- **OpDef / 类名（CamelCase）** 与目录名一致映射，如 `CatlassMatmulAdd`、`ops/catlass_matmul_add/`。
- 若用户坚持使用非 `catlass` 名称：**必须**在设计文档与对话中明确拒绝并给出带 `catlass` 的命名方案后再进入组件选型；不得按冲突名定稿设计。

### NEVER / ALWAYS

**NEVER**:
- ❌ 使用不含 `catlass` 的算子名定稿设计
- ❌ 把 example 整份照抄到设计或后续代码中
- ❌ 设计文档中写大量代码块（应用选型表格代替）
- ❌ 在信息不足时臆测需求

**ALWAYS**:
- ✅ 算子名含 `catlass`，目录名与类名一致映射
- ✅ 条件不明则追问，以问答确认需求与设计要点
- ✅ 设计前存在 catlass 仓库并阅读其文档与代码
- ✅ 设计文档用**选型表格**描述组件（不写代码），明确：算子名、参考 example、Kernel/Block/Tile/Epilogue、TilingKey 分支、Workspace
- ✅ 若 Epilogue 非 catlass 现成 Tile：先按 [custom-epilogue.md](references/custom-epilogue.md) 定契约，再交给 code-gen

## 1. 需求输入

用户可能**直接说出需求**，也可能**不说**。执行本 skill 时：**若认为信息不足，则继续追问**，直到足以产出设计文档。

需确认的信息：`op_name`（须含 catlass）、功能要点、I/O 与 dtype、布局、目标 SoC、参考 example（如有）、约束条件。

输出为设计文档（`design_<op_name>.md`）。

## 2. 需求分析

- 确定 **`op_name`：须含 `catlass`**（见上文「算子命名」）；不满足则先与用户对齐命名再往下写。
- 提取：算子功能、数学公式、I/O、dtype、布局、目标 SoC、约束
- 使用术语：GM、UB、L1、Tiling、M/N/K、SplitK（见 [references/design-document.md](references/design-document.md)）

## 3. 阅读 catlass 并选型

- **阅读** catlass 仓库：`examples/`、`include/` 下的文档与代码，**领略**开发形式与模板种类（如 00_basic_matmul、Matmul+GELU、Matmul+Add 等）。
- 在 `examples/` 中按功能找**相似示例**，在设计文档中写明：选中的 example 路径、选型理由。
- 若无完全匹配：基于 [references/matmul-templates.md](references/matmul-templates.md) 与仓库中现有样例，说明**变通方案**（如基于某 example 增加 Epilogue、改用 SplitK 等）。
- **Epilogue**：在 [epilogue-components.md](references/epilogue-components.md) 与 `catlass/include/catlass/epilogue/tile/` 中检索；**无**现成 Tile 时按 [custom-epilogue.md](references/custom-epilogue.md) 先写设计契约，**不**直接进 codegen。

## 4. 组件选型

选型结果用**概念表格**记录在设计文档中，不写代码。按 [references/epilogue-components.md](references/epilogue-components.md) 选后处理组件，按 [references/matmul-templates.md](references/matmul-templates.md) 选 BlockMmad/DispatchPolicy/BlockScheduler。

设计文档须**显式写出**选型表格：ArchTag、BlockMmad（L1/L0 TileShape、数据类型）、BlockEpilogue（各环节 Tile/Block 组件）、BlockScheduler、Kernel 类型，便于 `catlass-operator-code-gen` 按表格实例化模板。

## 5. 输出设计文档

### 5.1 文档章节要求

与 [references/design-document.md](references/design-document.md) 对齐。设计文档用**用户层概念**描述选型，**不写可编译代码**：

1. **概述**：功能、场景、数学公式
2. **输入输出信息表**：变量名、数据类型、Shape、布局、描述
3. **核心组件选型（必写）**：用选型表格描述各层组件（见下），不写代码
   - 硬件与架构：目标芯片
   - BlockMmad：DispatchPolicy、L1/L0TileShape、AType/BType/CType
   - BlockEpilogue：后处理流水线各环节的 Tile/Block 组件，无后处理则写 `void`；若含**自定义 Tile**，见 [custom-epilogue.md](references/custom-epilogue.md) 与 [design-document.md](references/design-document.md) §3.3.1
   - BlockScheduler：调度器类型与参数
   - Kernel：Kernel 类型及其组装关系
4. **参考 Example 与模板选型**：选中的 example、选型理由；无完全匹配时写变通方案
5. **TilingKey 分支设计**：各 key 对应的条件（dtype/转置/调度策略）和 Kernel 分支内容
6. **Workspace**：大小计算逻辑来源
7. **接口与使用**：aclnn 接口、Host Tiling 流程、Kernel 入口概念
8. **扩展性**：可替换的组件
9. **实现方案纲要**：Host 侧（Tiling/InferShape/OpDef）与 Kernel 侧（GET_TILING_DATA/TILING_KEY_IS 分支）要点，引导 code-gen

### 5.2 输出格式

设计文档须为独立 Markdown 文件，结构与上述章节一致，命名建议 `design_<op_name>.md`，存放于 **USER_OP_PROJECT** 或用户指定路径。设计阶段不产出可编译代码，只输出结构化文档供下游使用。

## 6. 质量验证

### 设计文档检查清单

- [ ] 算子名含 `catlass`，snake_case 目录名与 CamelCase 类名一致
- [ ] 含完整的输入输出信息表（变量名、数据类型、Shape、布局、描述）
- [ ] 核心组件选型已明确：ArchTag、BlockMmad、BlockEpilogue、BlockScheduler、Kernel（选型表格，非代码）
- [ ] 若自定义 Epilogue：已按 [custom-epilogue.md](references/custom-epilogue.md) 写明契约（或已确认仅用 catlass 现成 Tile）
- [ ] 参考 example 已写明，选型理由清晰
- [ ] 无完全匹配时写明了变通方案
- [ ] TilingKey 分支设计已列出（条件 + 分支内容）
- [ ] 实现方案纲要包含 Host 与 Kernel 要点
- [ ] 交付路径 USER_OP_PROJECT 已明确

### 下游衔接

- 设计文档完成后，交由 **catlass-operator-code-gen** 生成 op_host、op_kernel、test_aclnn 代码
- 编译部署衔接 **ascendc-operator-compile-debug**（catlass 算子统一使用该 skill）
- 精度验证衔接 **ascendc-operator-precision-eval**
- 如需接入 PyTorch，衔接 **ascendc-operator-frame-adapter-torch**

## 参考资料

| 文件 | 用途 |
|------|------|
| [references/design-document.md](references/design-document.md) | 设计文档模板与章节规范 |
| [references/matmul-templates.md](references/matmul-templates.md) | 模板清单与选型指南 |
| [references/epilogue-components.md](references/epilogue-components.md) | Epilogue 组件分类与选型 |
| [references/custom-epilogue.md](references/custom-epilogue.md) | 自定义 Tile Epilogue 的设计契约 |
| catlass/examples/ | 开发形式与多种模板参考 |
| catlass/docs/3_API/gemm_api.md | Gemm API 分层模型、组件对照表、三层嵌套循环伪代码 |
| catlass/docs/2_Design/01_kernel_design/03_dispatch_policies.md | DispatchPolicy 参数详解（STAGES、ENABLE_UINT_FLAG 等） |
| catlass/docs/2_Design/01_kernel_design/02_swizzle.md | Swizzle 策略图解与选择规则（M>=N / M<N 方向选择） |
