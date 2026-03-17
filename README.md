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

## 免责声明

1. 本仓库中的 Agent Skills 内容、代码、配置及示例仅供**技术参考和学习使用**，不代表其适用于任何生产环境、商业场景或关键业务系统。
2. 开发者在使用本仓库内容时，应自行评估其安全性、兼容性和适用性。作者及贡献者不对因使用本仓库内容导致的任何直接或间接损失承担责任，包括但不限于数据丢失、系统故障、业务中断、经济损失等。
3. 本仓库内容可能涉及第三方依赖或接口调用示例，相关权限及合规性需由开发者自行核实。作者及贡献者不承担与第三方服务相关的任何责任。
4. 本仓库中的 Agent Skills 示例仅为功能演示，不保证其完整性、准确性、时效性。作者及贡献者有权随时修改或删除内容，无需另行通知。
5. 除非另有明确约定，本仓库所有内容均基于开源协议发布，不提供任何形式的技术支持、维护承诺或担保。