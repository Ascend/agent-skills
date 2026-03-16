# Agent-Skills 代码仓设计文档

## 项目概述

### 项目定位
agent-skills 是昇腾（Ascend）社区用于AI辅助研发的核心管理仓库，专注于AI Agent技能的开发和管理，促进AI Agent技能的协同开发和创新。

### 核心目标
- 为内外部开发者提供 Agent skills
- 建立Ascend社区通用的skill能力
- 促进技能的协同开发、共享和创新

### 目标用户
- 昇腾社区开发者
- 场景化应用开发者
- 内外部合作伙伴

## 项目架构设计

### 整体架构
```
agent-skills/
├── skills/                    # 技能核心目录（扁平化结构）
│   ├── skill-name-1/         # 技能1
│   ├── skill-name-2/         # 技能能2
│   └──── skill-name-n/       # 技能能n
├── docs/                     # 文档目录
│   ├── design/               # 设计文档
│   ├── guides/               # 开发指南
│   └── examples/             # 示例文档
├── tests/                    # 测试目录
│   ├── test-data/          # 测试数据集
│   ├── validators/         # 验证脚本
│   └── expected-results/   # 预期结果
├── scripts/                  # 脚本工具
│   └── validate_skills.py    # 技能验证脚本
├── template/                 # 技能模板
│   └── SKILL.md             # 标准技能模板
├── README.md                 # 项目说明文档
├── AGENTS.md                 # AI编程助手指南
└── .gitignore               # Git 忽略配置
```
