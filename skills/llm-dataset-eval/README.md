# llm-dataset-eval

模型级数据集精度测评 Skill。

## 设计边界

已有 Ascend 仓 Skill：

- `ascendc-operator-precision-eval`：单算子数值精度。
- `triton-operator-precision-eval`：Triton 算子与 Torch reference 对齐。

本 Skill：

- GSM8K / MMLU / HumanEval / IFEval 等模型级任务。
- SWE-bench patch resolution。
- OpenAI-compatible server / local model 的 benchmark 编排。
- Output Health：重复、循环复读、截断、最大输出命中、空/过短/malformed、输出长度分布。
- 精度关联：重复样本 vs 正常样本、截断样本 vs 完整样本的 accuracy gap。
- 可选 LLM-as-a-Judge：correctness / relevance / completeness / clarity / instruction-following。

## 目录

```text
llm-dataset-eval/
├── SKILL.md
├── README.md
├── scripts/
│   ├── run_eval.py
│   ├── output_health.py
│   ├── quality_judge.py
│   ├── validate_predictions.py
│   └── render_report.py
├── references/
│   ├── benchmark-guide.md
│   ├── output-health.md
│   └── report-schema.md
├── examples/
│   ├── gsm8k_local_chat.json
│   └── swebench_lite.json
└── tests/
    └── test_parsers.py
```

## 运行

```bash
python scripts/run_eval.py --config examples/gsm8k_local_chat.json
```

### Output Health 核心指标

| 指标 | 含义 |
|---|---|
| `repetition_rate` | 存在明显重复的样本比例 |
| `severe_repetition_rate` | 严重重复/连续句循环比例 |
| `truncation_rate` | 命中输出上限或疑似未完成的比例 |
| `output_cap_hit_rate` | `finish_reason=length` 或接近 max tokens 的比例 |
| `output_tokens_p50/p95` | 输出长度分布 |
| `empty/malformed/very_short_rate` | 输出异常率 |
| `repetition_accuracy_gap_pp` | 正常样本 accuracy 与重复样本 accuracy 的百分点差 |
| `truncation_accuracy_gap_pp` | 完整样本 accuracy 与截断样本 accuracy 的百分点差 |
| `judge avg_overall` | 可选语义质量评分，1~5 |

核心思想是：**不要只回答“模型答对没有”，还要回答“模型是怎么答的、输出是否健康、异常输出是否集中导致精度下降”。**
