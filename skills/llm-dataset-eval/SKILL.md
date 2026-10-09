---
name: llm-dataset-eval
description: >-
  模型级数据集精度评测 Skill。面向 vLLM-Ascend、MindIE 或其他 OpenAI-compatible 服务，以及
  HuggingFace 本地模型，统一编排 lm-evaluation-harness 和 SWE-bench，完成 GSM8K/MMLU/
  HumanEval 等标准 benchmark 以及 SWE-bench Lite/Verified/full 评测；负责环境预检、smoke test、
  正式测评、结果解析、门限判定和 Markdown/JSON 报告。触发词：数据集精度、GSM8K、MMLU、HumanEval、
  SWE-bench、accuracy benchmark、模型精度回归。
metadata:
  short-description: 模型级 benchmark accuracy evaluation with reproducible gates.
  category: Model Evaluation
  version: 0.1.0
  outputs: accuracy_report.json, accuracy_report.md
  backends: lm-eval, swebench, openai-compatible-judge
  capabilities: benchmark-accuracy, output-health, quality-judge
---

# LLM 数据集精度评测

## 1. 定位

本 Skill 解决的是**模型/服务级行为精度**，不是单个 AscendC/Triton 算子的数值误差校验。

适用场景：

- 新模型 day0 适配后，需要快速判断“模型功能正确 + benchmark 精度没有明显退化”。
- RC / release 前需要重新跑 GSM8K、MMLU、HumanEval 等标准任务。
- 模型服务已经启动，希望直接通过 OpenAI-compatible API 进行 benchmark。
- 需要验证 SWE-bench patch 的 resolved rate。
- 需要把 benchmark 结果沉淀为结构化输入，交给 `llm-eval-regression-gate` 做回归门禁。

## 2. 输入契约

配置采用 JSON，核心字段：

```json
{
  "model_name": "Qwen3-32B",
  "backend": "local-chat-completions",
  "model_args": {
    "model": "Qwen3-32B",
    "base_url": "http://127.0.0.1:8000/v1/chat/completions"
  },
  "benchmarks": [
    {"name": "gsm8k", "shots": 0, "limit": 50}
  ],
  "gates": {
    "accuracy_min": 0.70,
    "max_error_rate": 0.01
  },
  "output_dir": "./results/gsm8k"
}
```

SWE-bench 配置通过 `backend=swebench` 使用 `predictions_path`；prediction 文件必须包含 `instance_id`、`model_patch`、`model_name_or_path`。

## 3. 强制工作流

```text
LOAD_CONFIG
   ↓
PREFLIGHT
   ├─ Python / lm-eval / swebench 是否存在
   ├─ API 服务是否可访问（API backend）
   └─ prediction 文件是否合法（SWE-bench）
   ↓
SMOKE_TEST
   └─ 用 limit=1 验证请求、模板和输出格式
   ↓
FULL_EVALUATION
   ├─ lm-eval
   └─ swebench
   ↓
PARSE BENCHMARK RESULT
   ├─ 主指标
   ├─ samples / errors
   └─ raw result
   ↓
OUTPUT_HEALTH
   ├─ repetition / loop
   ├─ truncation / cap hit
   ├─ output length distribution
   ├─ empty / malformed / very short
   └─ accuracy by repeated / clean / truncated / complete
   ↓
OPTIONAL QUALITY_JUDGE
   └─ correctness / relevance / completeness / clarity / instruction-following
   ↓
GATE
   ├─ accuracy threshold
   ├─ infrastructure/error threshold
   └─ output-health / judge threshold（按配置启用）
   ↓
REPORT
   ├─ accuracy_report.json
   ├─ accuracy_report.md
   └─ output_health.json
```

## 4. lm-eval 策略

### 4.1 服务模型

OpenAI-compatible 服务优先使用：

```bash
lm-eval run \
  --model local-chat-completions \
  --model_args model=<MODEL>,base_url=http://<HOST>:<PORT>/v1/chat/completions \
  --tasks gsm8k \
  --apply_chat_template
```

`local-completions` 适合 completions 协议；聊天模型/聊天服务使用 `local-chat-completions`。若模型是 reasoning model，可通过配置传递 `enable_thinking` / `think_end_token`，但必须确认服务实际返回了结束 thinking block 的内容。

### 4.2 本地 HuggingFace 模型

允许使用 lm-eval `hf` / `vllm` backend，但 Skill 只负责编排，不假设模型必须是某个框架。

### 4.3 常用任务

| Benchmark | lm-eval task | 典型主指标 | 备注 |
|---|---|---|---|
| GSM8K | `gsm8k` | `exact_match` | 数学推理；答案抽取容易受输出格式影响 |
| MMLU | `mmlu_*` | `acc` | 注意 subject / 任务拆分 |
| HumanEval | `humaneval` | pass@k | 需要生成代码并执行测试 |
| IFEval | `ifeval` | instruction-following metrics | 可作为通用行为评测补充 |

Skill 不把上述任务硬编码为唯一选择；`benchmarks` 列表允许用户传入任何安装的 lm-eval task。

## 5. GSM8K 专项规则

GSM8K 常用于 day0 sanity 和 release regression。Skill 需要：

1. 先 smoke test 1~2 样本，确认 endpoint、chat template 和模型名正确。
2. 正式测评时固定 temperature（推荐 0）和随机种子；不同模型需要不同 generation setting 时必须写入结果。
3. 记录 `num_fewshot`、task version、lm-eval 版本和模型服务版本。
4. 记录 raw samples 路径；当 exact match 异常时可以回溯原始回答。
5. 不把 HTTP 500、timeout、model load failure 计入“模型答错”；单独记录 `error_rate`。
6. 必须保留 `--log_samples` 生成的原始样本，用于 Output Health 分析。

### 5.1 Output Health 运行方式

默认开启：

```bash
python scripts/run_eval.py --config examples/gsm8k_local_chat_output_health.json
```

单独分析已经存在的 raw samples：

```bash
python scripts/output_health.py samples.jsonl --benchmark gsm8k --max-tokens 512 --output output_health.json
```

### 5.2 可选语义质量 Judge

当 `quality_judge.enabled=true` 时，Skill 会调用一个 OpenAI-compatible judge 服务，对每个样本按 5 个维度打 1~5 分。该能力是可选的，因为它会引入额外模型、网络和评分方差。

```bash
python scripts/quality_judge.py samples.jsonl \
  --endpoint http://127.0.0.1:9000/v1/chat/completions \
  --model judge-model \
  --limit 100 \
  --output judge_report.json
```

Judge 结果只用于“回答质量”维度，不替代 benchmark 官方 accuracy。

## 6. SWE-bench 专项规则

SWE-bench 与 GSM8K 不同，它不是直接比较一个标量 answer，而是：

```text
issue + repo + base_commit
      ↓
model prediction patch
      ↓
Docker isolated environment
      ↓
apply patch
      ↓
run tests
      ↓
resolved / unresolved / error / incomplete
```

因此 Skill 不负责生成 patch，只负责**预测结果校验 + evaluation harness 编排 + resolved rate 汇总**。

建议首先跑 Lite，再逐步扩大到 Verified / full。

## 7. 输出健康度与精度关联

**这是本 Skill 的模型级新增核心能力。** Benchmark 的 accuracy 只回答“最终答案是否正确”，不能发现模型已经进入异常生成状态。每次启用 `output_health.enabled=true` 时，必须尝试从 lm-eval `--log_samples` 产物中读取原始样本，计算：

- 重复率：`repetition_rate`、`severe_repetition_rate`
- 截断率：`truncation_rate`、`output_cap_hit_rate`
- 输出长度：平均/p50/p95 output tokens、平均字符数
- 异常率：`empty_rate`、`malformed_rate`、`very_short_rate`
- 结构质量：`avg_heuristic_quality_score`
- 关联指标：`accuracy_repetition_samples`、`accuracy_clean_samples`、`repetition_accuracy_gap_pp`、`accuracy_truncated_samples`、`accuracy_complete_samples`、`truncation_accuracy_gap_pp`

### 重复和精度的解释原则

如果发现 `repetition_accuracy_gap_pp > 0`，只能表述为“重复样本与更低的 accuracy 同时出现”，不能表述为已经证明重复导致精度下降。需要结合 raw sample、generation config、服务日志和不同输入分桶继续定位。

详细口径见 [`references/output-health.md`](references/output-health.md)。

## 8. 错误分类

所有失败必须分类：

| 类型 | 例子 | 是否算 benchmark 错误 |
|---|---|---|
| `CONFIG_ERROR` | JSON 缺字段 | 否 |
| `DEPENDENCY_ERROR` | lm-eval 不存在 | 否 |
| `SERVICE_ERROR` | HTTP 500/timeout | 否，计入 infra error |
| `BENCHMARK_ERROR` | task config / harness 失败 | 否 |
| `MODEL_FAILURE` | 模型输出格式不满足任务要求 | 是 |
| `BENCHMARK_FAILURE` | SWE-bench patch 未解决 issue | 是 |

禁止把 `SERVICE_ERROR` 直接映射成 accuracy=0。

## 9. 报告契约

JSON 必须至少包含：

```text
metadata
  model_name
  backend
  benchmark_tool_version
  timestamp
benchmarks[]
  name
  metric
  value
  evaluated_samples
  error_count
  error_rate
  status
  command
  raw_result_path
summary
  passed
  failed_benchmarks
  reasons[]
```

Markdown 报告必须包含：

1. 环境与模型信息
2. benchmark 汇总表
3. 每个 benchmark 的主指标
4. error rate / failed samples
5. gate 结果
6. Output Health 汇总（重复、截断、长度、空/异常输出、质量）
7. 重复/截断样本与 accuracy 的关联分析
8. raw result / raw samples 路径
9. gate 结果与可操作的下一步建议

## 10. 反模式

- ❌ endpoint 无响应却继续跑全量 benchmark。
- ❌ 没有 raw result 就声称“精度通过”。
- ❌ 服务错误当成模型错误。
- ❌ 只跑 1 个 sample 就拿结果做 release 结论。
- ❌ SWE-bench 没有 Docker/预测文件校验就直接启动全量。
- ❌ 使用未经记录的 generation 参数比较两个版本。
- ❌ benchmark 名称相同但 task version / subject / few-shot 完全不同仍直接比较。

## 11. 完成定义

Skill 只有同时满足以下条件才可以输出 `PASS`：

- 所有请求的 benchmark 均执行完成，或者明确记录了跳过原因。
- 每个 benchmark 都有结构化主指标。
- 错误数量和错误率可追溯。
- gate 规则被实际执行。
- JSON 与 Markdown 报告均生成。
- 对于失败场景，报告中明确是 accuracy failure、service failure 还是 benchmark configuration failure。

## 12. 典型命令

### GSM8K

```bash
python scripts/run_eval.py --config examples/gsm8k_local_chat.json
```

### SWE-bench

```bash
python scripts/run_eval.py --config examples/swebench_lite.json
```

### 调试单个 benchmark

```bash
python scripts/run_eval.py --config examples/gsm8k_local_chat.json --only gsm8k
```

## 13. 参考资料加载策略

- `references/benchmark-guide.md`：任务选择、结果解析和推荐 gate。
- `references/report-schema.md`：JSON schema 和 Markdown 字段解释。
- 需要修改 benchmark 执行命令时优先查官方工具文档，不在本 Skill 内复制工具实现。
## 14. 自动化集成建议

在 CI 中建议拆成三个 job：`preflight`、`benchmark`、`publish`。

```text
preflight
  ├─ config validation
  ├─ dependency detection
  └─ API smoke
       ↓ pass
benchmark
  ├─ GSM8K / MMLU / HumanEval
  └─ SWE-bench
       ↓
publish
  ├─ accuracy_report.json
  └─ accuracy_report.md
```

不要让 `publish` 重新计算指标；它应该只渲染已有 JSON。对于异常输出分析，也应保留 `output_health.json`，避免 CI 发布阶段重新遍历 raw samples。

## 15. Reasoning model 注意事项

对于带 thinking 的模型，必须同时记录：`enable_thinking`、`think_end_token`、chat template、generation 参数。只有在服务返回内容包含约定 delimiter 时，才能认为 thinking-output stripping 成功。

## 16. 结果审计

每次结果至少能追溯到：

```text
model artifact
engine/framework version
hardware
benchmark tool version
task / dataset version
few-shot
generation config
command
raw result
```

缺少其中任一关键项时，允许报告结果，但应标注 `reproducibility=incomplete`。
