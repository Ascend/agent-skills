# Agent-Skills 代码仓设计文档

## 项目概述

### 项目定位

昇腾（Ascend） Agent Skills：将昇腾软件栈专家经验与能力模块化、可复用，使能用户、开发者。

在 AI 智能体（Agent）上下文中，技能（Skills）是为扩展 Agent 能力而设计的模块化功能单元。每个 Skill 封装了指令、元数据及可选资源（如可执行脚本、模板），当 Agent（比如 OpenClaw、OpenCode 等）通过意图识别匹配到相关上下文时，自动调用对应的 Skill。

Ascend Agent-Skills 是一个基于开源 Agent 能力提供 Skills 参考的核心仓库，专注于 **Agent Skills for Ascend** 的开发与管理，旨在促进昇腾专家 Skills 的协同开发和创新。

### 核心目标

- 为开发者提供 Agent Skills 参考
- 促进 Agent Skills 的协同开发、共享和创新

### 为什么使用 Agent Skills？

[Agent Skills](https://agentskills.io/home) 是基于文件系统的可复用资源，旨在为 Agent 有效注入特定领域的专业知识和能力 —— 包括工作流、上下文环境和最佳实践，从而将通用型 Agent 转化为专家型 Agent。与一次性对话的提示词（Prompts）不同，Skills 支持按需加载，避免在多轮对话中重复提供相同指示。

核心优势：

- 赋予 Agent 专精能力：为特定领域任务定制稳定的 Agent 工作流，实现领域泛化。
- 减少重复工作：一次创建，多平台复用（OpenClaw、OpenCode、CodeBuddy、TRAE 等）。
- 组合能力：通过整合多个 Skills 构建复杂工作流程。

### 目标用户

- 昇腾社区开发者
- 场景化应用开发者
- 内外部合作伙伴

### SKILL 命名规范

- `SKILL.md` 文件必须严格命名为 `SKILL.md`（区分大小写），不接受任何变体（如 `SKILL.MD`、`skill.md`）。  
- SKILL 文件夹命名必须使用**烤串命名法（kebab-case）**，例如 `ascend-inference-repos-copilot`。  
  - ✅ 正确示例：`ascend-inference-repos-copilot`  
  - ❌ 错误示例：`Ascend Inference Repos Copilot` （含空格）
  - ❌ 错误示例：`ascend_inference_repos_copilot` （使用下划线）
  - ❌ 错误示例：`AscendInferenceReposCopilot` （使用大写）

**文档存放**：SKILL 文件夹内不能包含 `README.md`。所有文档内容内化于 `SKILL.md` 中，或存放于 `references/` 目录下。

## 项目架构设计

### 整体架构

```
agent-skills/
├── skills/                         # 技能核心目录（扁平化结构）
│   ├── skill-name-1/               # 技能 1
│   ├── skill-name-2/               # 技能 2
│   └──── skill-name-n/             # 技能 N
├── docs/                           # 文档目录
│   ├── design/                     # 设计文档
│   ├── guides/                     # 开发指南
│   └── examples/                   # 示例文档
├── tests/                          # 测试目录
│   ├── test-data/                  # 测试数据集
│   ├── validators/                 # 验证脚本
│   └── expected-results/           # 预期结果
├── scripts/                        # 脚本工具
│   └── validate_skills.py          # 技能验证脚本
├── template/                       # 技能模板
│   └── SKILL.md                    # 标准技能模板
├── README.md                       # 项目说明文档
├── AGENTS.md                       # AI 编程助手指南
└── .gitignore                      # Git 忽略配置
```

## SKILL 索引目录

>目前共收录 **42** 个 SKILL。
> 分类共 **7** 大类，便于按需快速定位。

| # | 分类名称 | 包含 SKILL 数 | 简述 |
|---|---------|:---:|------|
| A |[AscendC 算子开发](#a-AscendC-算子开发)    |         9 | 覆盖 AscendC 算子从工程初始化、方案设计、Host/Tiling/Kernel 代码生成，到编译调试、精度验证、框架适配与文档生成的完整开发链路。 |
| B | [Catlass 算子开发](#b-Catlass-算子开发)    |         5 | 面向 Catlass 算子的设计、环境导入、代码生成、端到端开发与性能调优，适合 Catlass 算子实现与优化场景。                   |
| C | [Triton 算子开发](#c-Triton-算子开发)      |         9 | 覆盖 Triton 算子需求分析、环境配置、代码生成、代码审查、性能评估、性能优化、精度验证与文档生成等全流程能力。                    |
| D | [迁移适配与性能优化](#d-迁移适配与性能优化) |         4 | 聚焦 GPU 到昇腾 NPU 的迁移适配、Triton Vector 类算子优化，以及 Profiling 异常分析与性能瓶颈定位。            |
| E | [环境搭建与设备管理](#e-环境搭建与设备管理)  |         4 | 提供 Ascend 开发环境搭建、CANN 安装、npu-smi 设备管理与 HCCL 通信测试等基础设施能力。                      |
| F | [推理生态与工程辅助](#f-推理生态与工程辅助)      |         4 | 面向模型推理部署与工程辅助，涵盖模型转换、昇腾推理生态问答、vLLM-ascend FAQ 生成与 Skill 安全审计。                 |
| G | [自动化测试与覆盖率](#g-自动化测试与覆盖率)       |         7 | 聚焦测试生成、pytest/unittest 编写、覆盖率分析、代码理解与 MindSpeed-LLM 测试执行，提升测试质量与自动化水平。        |

---

### A AscendC 算子开发

| 相对路径 | 功能说明 | 分类 |
|---------|---------|------|
| skills/ascendc-operator-project-init | 初始化 AscendC 算子工程脚手架（目录结构、模板文件）。新建算子项目时使用 | AscendC 算子开发 |
| skills/ascendc-operator-design | 设计 AscendC 算子实现方案并生成设计文档（Tiling 策略、Kernel 策略）。规划算子实现方案时使用 | AscendC 算子开发 |
| skills/ascendc-operator-tiling-code-gen | 生成 Host 侧代码（op_def、tiling、infershape）。完成设计文档后生成 Host 侧代码时使用 | AscendC 算子开发 |
| skills/ascendc-operator-kernel-code-gen | 生成 AI Core Kernel 代码（算子核心计算逻辑）。完成 Tiling 代码后生成 Kernel 实现时使用 | AscendC 算子开发 |
| skills/ascendc-operator-compile-debug | 编译、部署和测试 AscendC 算子。代码生成完成后进行编译调试与验证时使用 | AscendC 算子开发 |
| skills/ascendc-operator-doc-gen | 生成 README 和 aclnn API 接口文档。算子开发完成后补充配套文档时使用 | AscendC 算子开发 |
| skills/ascendc-operator-frame-adapter-torch | 将 ACLNN/AscendC 算子集成到 PyTorch 框架。需要在 PyTorch 中调用自定义昇腾算子时使用 | AscendC 算子开发 |
| skills/ascendc-operator-precision-eval | AscendC 算子精度验证（与标准实现比对）。验证算子计算结果正确性时使用 | AscendC 算子开发 |
| skills/ascendc-operator-dev | AscendC 算子端到端开发编排器（从需求收集到精度验证的完整工作流）。需要完整算子开发流程时使用 | AscendC 算子开发 |

### B Catlass 算子开发

| 相对路径 | 功能说明 | 分类 |
|---------|---------|------|
| skills/catlass-operator-design | 将 Catlass 算子需求转化为设计文档。规划 Catlass 算子实现方案时使用 | Catlass 算子开发 |
| skills/catlass-module-import | 克隆 Catlass 库并配置 CMake 编译环境。首次使用 Catlass 进行环境搭建时使用 | Catlass 算子开发 |
| skills/catlass-operator-code-gen | 根据设计文档生成 Catlass 算子代码。完成设计后自动生成实现代码时使用 | Catlass 算子开发 |
| skills/catlass-operator-dev | Catlass 算子端到端开发编排器。需要完整的 Catlass 算子开发流程时使用 | Catlass 算子开发 |
| skills/catlass-operator-performance-optim | Catlass 算子性能调优指导。优化 Catlass 算子执行效率时使用 | Catlass 算子开发 |

### C Triton 算子开发

| 相对路径 | 功能说明 | 分类 |
|---------|---------|------|
| skills/triton-operator-design | 生成 Triton 算子需求文档。启动 Triton 算子开发前进行需求分析时使用 | Triton 算子开发 |
| skills/triton-operator-code-gen | 生成 Ascend NPU Triton kernel 代码。完成需求分析后自动生成算子代码时使用 | Triton 算子开发 |
| skills/triton-operator-code-review | Triton 算子静态代码检查（质量、规范、潜在问题）。代码提交前进行审查时使用 | Triton 算子开发 |
| skills/triton-operator-dev | Triton 算子端到端开发编排器。需要完整的 Triton 算子开发流程时使用 | Triton 算子开发 |
| skills/triton-operator-env-config | 校验并构建 Triton 开发环境（CANN、Python、torch、triton-ascend 依赖）。算子开发前环境检查时使用 | Triton 算子开发 |
| skills/triton-operator-doc-gen | 生成 Triton 算子标准化接口文档（参数说明、调用示例、约束条件）。算子开发完成后编写接口文档时使用 | Triton 算子开发 |
| skills/triton-operator-performance-eval | 使用 msprof/msprof op 评估 Triton 算子性能（瓶颈类型、硬件利用率）。分析性能瓶颈与生成评估报告时使用 | Triton 算子开发 |
| skills/triton-operator-performance-optim | 优化 Ascend NPU 上 Triton 算子性能（UB 规划、多 Token 并行、MTE/Vector 流水等）。算子性能需提升时使用 | Triton 算子开发 |
| skills/triton-operator-precision-eval | 通过与 Torch 实现比对验证 Triton 算子精度，生成精度报告。验证算子计算正确性时使用 | Triton 算子开发 |

### D 迁移适配与性能优化

| 相对路径 | 功能说明 | 分类 |
|---------|---------|------|
| skills/simple-vector-triton-gpu-to-npu | 将简单 Vector 类 Triton 算子从 GPU 迁移到昇腾 NPU（代码转换、精度验证）。GPU→NPU 算子迁移时使用 | 迁移适配与性能优化 |
| skills/npu-adapter-reviewer | GPU 代码到昇腾 NPU 的全面适配审查专家（堵点识别、适配脚本、验证方案）。GPU→NPU 代码仓库迁移审查时使用 | 迁移适配与性能优化 |
| skills/vector-triton-ascend-ops-optimizer | 昇腾 NPU 上 Vector 类 Triton 算子深度性能优化（UB 容量规划、mask 优化等）。单算子性能需极致调优时使用 | 迁移适配与性能优化 |
| skills/ascend-profiling-anomaly | 分析 Ascend NPU profiling 数据，发现隐藏性能异常并逆向工程模型架构。NPU 性能诊断与瓶颈定位时使用 | 迁移适配与性能优化 |

### E 环境搭建与设备管理

| 相对路径 | 功能说明 | 分类 |
|---------|---------|------|
| skills/ascend-docker | 创建 Ascend NPU 开发用 Docker 容器（设备映射、卷挂载、多模式支持）。搭建容器化 NPU 开发环境时使用 | 环境搭建与设备管理 |
| skills/cann-installer | 昇腾 NPU CANN 安装指导（驱动检查、toolkit 安装、环境变量配置）。安装或配置 CANN 开发环境时使用 | 环境搭建与设备管理 |
| skills/npu-smi | Huawei Ascend NPU npu-smi 命令参考（设备查询、配置、固件升级、虚拟化）。查询设备状态或管理 NPU 硬件时使用 | 环境搭建与设备管理 |
| skills/hccl-test | HCCL 集合通信性能测试（AllReduce、AllGather 等，含多机预检）。分布式训练场景下测试通信带宽与功能时使用 | 环境搭建与设备管理 |

### F 推理生态与工程辅助

| 相对路径 | 功能说明 | 分类 |
|---------|---------|------|
| skills/atc-model-converter | PT→ONNX→OM 模型转换与端到端推理适配工具链（含精度对比与 README 生成）。在昇腾 NPU 上部署推理模型时使用 | 推理生态与工程辅助 |
| skills/ascend-inference-repos-copilot | 昇腾推理生态开源仓库智能问答专家（vLLM、MindIE-LLM/SD/Motor/Turbo、msModelSlim）。咨询推理框架用法、部署、调试等技术问题时使用 | 推理生态与工程辅助 |
| skills/vLLM-ascend_FAQ_Generator | 自动处理 vLLM-ascend 已关闭 Issue 并生成结构化 Debug FAQ。构建 vLLM-ascend 故障排查知识库时使用 | 推理生态与工程辅助 |
| skills/skill-auditor | AI Agent 技能与 Prompt 安全审计器（权限、注入、供应链、数据泄露六步审查）。部署新 Skill 前进行安全评估时使用 | 推理生态与工程辅助 |

### G 自动化测试与覆盖率

| 相对路径 | 功能说明 | 分类 |
|---------|---------|------|
| skills/mindspeed-llm-auto-ut-skills/skills/analyse-coverage | 分析测试覆盖率盲区并生成覆盖率分析报告。评估测试质量、识别未覆盖代码时使用 | 自动化测试与覆盖率 |
| skills/mindspeed-llm-auto-ut-skills/skills/code-comprehension | 多尺度代码理解与摘要（函数→类→模块→系统级）。快速掌握陌生代码库结构与逻辑时使用 | 自动化测试与覆盖率 |
| skills/mindspeed-llm-auto-ut-skills/skills/coverage | Coverage.py 工具参考与测试覆盖率模式。使用 coverage 工具时查阅用法与最佳实践 | 自动化测试与覆盖率 |
| skills/mindspeed-llm-auto-ut-skills/skills/generate-unit-test | 为函数和类生成高质量单元测试（正常路径、边界条件、异常场景）。快速生成可纳入 CI 的测试代码时使用 | 自动化测试与覆盖率 |
| skills/mindspeed-llm-auto-ut-skills/skills/pytest-writer | 专业 pytest 测试用例编写助手（fixtures、参数化、断言技巧）。编写或优化 pytest 风格测试用例时使用 | 自动化测试与覆盖率 |
| skills/mindspeed-llm-auto-ut-skills/skills/run-mindspeed-llm-test | 在 Docker 中执行 MindSpeed-LLM 项目测试用例。运行单元测试或覆盖率扫描时使用 | 自动化测试与覆盖率 |
| skills/mindspeed-llm-auto-ut-skills/skills/unittest-writer | Python unittest 框架测试用例编写助手（setUp/tearDown、断言、组织模式）。编写或优化 unittest 风格测试用例时使用 | 自动化测试与覆盖率 |

---

## 免责声明

1. 本仓库中的 Agent Skills 内容、代码、配置及示例仅供**技术参考和学习使用**，不代表其适用于任何生产环境、商业场景或关键业务系统。
2. 开发者在使用本仓库内容时，应自行评估其安全性、兼容性和适用性。作者及贡献者不对因使用本仓库内容导致的任何直接或间接损失承担责任，包括但不限于数据丢失、系统故障、业务中断、经济损失等。
3. 本仓库内容可能涉及第三方依赖或接口调用示例，相关权限及合规性需由开发者自行核实。作者及贡献者不承担与第三方服务相关的任何责任。
4. 本仓库中的 Agent Skills 示例仅为功能演示，不保证其完整性、准确性、时效性。作者及贡献者有权随时修改或删除内容，无需另行通知。
5. 除非另有明确约定，本仓库所有内容均基于开源协议发布，不提供任何形式的技术支持、维护承诺或担保。