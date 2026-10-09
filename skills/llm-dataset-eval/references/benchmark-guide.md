# Benchmark Guide

## Metric policy

模型级 benchmark 结果比较前至少固定：模型权重/commit、框架版本、tokenizer、task version、few-shot、generation 参数、硬件数量和服务配置。

## GSM8K

建议默认：0-shot、temperature=0、固定 max generation。生产门禁更适合比较“相对基线变化”，而不是要求所有模型达到一个绝对常数。

## MMLU

把 subject 维度保留在 raw results 中。如果只保留一个总均值，后续无法定位是专业科目还是通识科目退化。

## HumanEval

主要观察 pass@1；由于代码执行具有随机性和环境依赖，建议记录 pass@k、sample count、执行错误和 timeout。

## SWE-bench

SWE-bench 的核心指标是 patch 是否使目标测试集通过。评测是在隔离环境中应用 patch 并运行测试，因此 Docker、镜像、repo/base commit 和 run-id 都应记录。

优先验证 gold patch：

```bash
swebench eval lite --gold -i sympy__sympy-20590 --run-id validate-gold
```

再运行模型预测。变更 prediction 后不要复用已有 run-id，以免命中缓存。

## 推荐层级

- Day0：GSM8K + 小规模 sanity benchmark。
- RC：GSM8K + MMLU + HumanEval/IFEval + SWE-bench Lite/Verified（按业务需要）。
- Release：固定任务集合的全量结果，并执行回归门禁。
