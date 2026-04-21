# MindSpeed-MM FSDP2 迁移技能集

将开源模型端到端迁移至 [MindSpeed-MM](https://gitcode.com/Ascend/MindSpeed-MM) FSDP2 框架的模块化技能集合。

## 整体架构

```
mindspeed-fsdp2-migration-main          # 总控：编排端到端流程
├── mindspeed-fsdp2-model-migration     # 模型侧：注册、加载签名、前向兼容
├── mindspeed-fsdp2-data-migration      # 数据侧：数据集插件、collate、预处理
├── mindspeed-fsdp2-config-migration    # 配置侧：YAML 映射、字段分层、注册关联
└── mindspeed-fsdp2-verification        # 验证：功能门禁、可靠性门禁、分布式 E2E
```

## 技能职责

### mindspeed-fsdp2-migration-main（总控）
负责统筹完整迁移流程：
- 执行 K0 知识储备门禁（读文档、扫代码）
- 调度 model / data / config / verification 四个子技能
- 收集各阶段交付物，产出最终迁移报告

**入口**：`mindspeed-fsdp2-migration-main/SKILL.md`

### mindspeed-fsdp2-model-migration（模型侧）
将源模型适配到 MindSpeed-MM FSDP2 注册契约：
- `@model_register.register("<model_id>")` 注册
- `from_pretrained` / `_from_config` 加载签名兼容
- 特殊 token 处理与 embedding 兼容
- 前向路径 `.loss` 返回

**入口**：`mindspeed-fsdp2-model-migration/SKILL.md`

### mindspeed-fsdp2-data-migration（数据侧）
将源数据集适配到 MindSpeed-MM FSDP2 数据插件结构：
- `@data_register.register("<dataset_type>")` 注册
- `__getitem__` 与 `collate_fn` 实现
- 预处理复用与字段映射
- 多模态字段（`pixel_values`、`image_flags`）保留

**入口**：`mindspeed-fsdp2-data-migration/SKILL.md`

### mindspeed-fsdp2-config-migration（配置侧）
将源训练配置映射到 MindSpeed-MM FSDP2 YAML：
- `model_id` / `dataset_type` / `training.plugin` 三元关联
- strict / extra 字段分层（防止 dataclass schema 报错）
- FSDP2 并行配置（`fsdp_plan.apply_modules`）
- 必填字段完整性检查

**入口**：`mindspeed-fsdp2-config-migration/SKILL.md`

### mindspeed-fsdp2-verification（验证）
执行迁移产物的功能与可靠性验收：
- 功能门禁：模型/数据/配置注册链路 + 分布式 E2E
- 可靠性门禁：schema、签名、路径类型兼容性
- 失败归因：映射到具体责任技能并给出修复建议

**入口**：`mindspeed-fsdp2-verification/SKILL.md`

## 交付产物清单

| 产物                          | 用途                    |
| --------------------------- | --------------------- |
| **迁移代码/配置/脚本**              | 目标仓中的实际可运行改动          |
| `verification_report.md`    | 功能门禁与可靠性门禁的正式验收结论     |
| `evidence.json`             | 命令输出、日志、验证证据的结构化存储    |
| `migration_report.md`       | 最终迁移报告（含过程、结论、建议）     |
| `risk_register.yaml`        | 已知风险、限制条件和待处理事项       |


## 迁移流程

```
1. K0 知识储备（必读文档、扫目录、产架构链路文档）
       ↓
2. 前置校验（路径存在性、入口有效性）
       ↓
3. 模型迁移 → mindspeed-fsdp2-model-migration
       ↓
4. 数据迁移 → mindspeed-fsdp2-data-migration
       ↓
5. 配置迁移 → mindspeed-fsdp2-config-migration
       ↓
6. 合并产物 → mindspeed-fsdp2-verification
       ↓
7. 分布式 E2E 验证（至少一次成功）
       ↓
8. 最终迁移报告
```

## 产物交付契约

每个子技能完成后必须产出：
- `*_checklist.md` — 通过/失败状态清单
- `*_report.md` — 映射/兼容性分析报告
- `changeset_manifest.yaml` — 改动清单

验证阶段必须产出：
- `verification_report.md` — 验收报告
- `evidence.json` — 命令输出证据
- `failed_cases.md` — 失败归因（如有）

## 禁止行为

- 跳过 K0 知识储备直接实施
- 未完成前置校验开始代码改动
- 无命令证据宣称"已通过"
- 绕过 `constraints.editable_paths` 修改核心框架
- 失败原因写成"可能/大概"而不给复现证据

---

## Prompt 示例

以下是一个完整的迁移任务 prompt：

```
请使用 mindspeed-fsdp2-migration-main 执行 Model_xxx -> MindSpeed-MM FSDP2 迁移，并以可运行验证为目标，我的 conda 环境是 conda_env。

输入：

- source_repo_path: /path/to/source_repo
- target_repo_path: /path/to/MindSpeed-MM

- model_identity:
  - name: model_id
  - modality: vlm

- source_entrypoints:
  - train: /path/to/train_entry.py
  - dataset: /path/to/dataset_entry.py
  - model: /path/to/model_dir

- runtime_assets:
  - model_path: /path/to/model_weights
  - dataset_path: /path/to/train.jsonl
  - image_root: /path/to/images

- constraints:
  - editable_paths:
    - examples/fsdp2
    - mindspeed_mm/fsdp/models
    - mindspeed_mm/fsdp/data
  - no_core_modification: true
  - reuse_first: true

- acceptance:
  - functional: true
  - reliability: true
  - distributed_e2e_run_once: true

执行要求：

1) 将 runtime_assets 映射到 YAML（model_path、dataset、必要的图像根路径字段）
2) 显式验证路径存在性与可读性
3) 输出 changeset_manifest、compatibility_matrix、verification_evidence、risk_register、next_actions
4) 无证据不允许宣称通过
```
