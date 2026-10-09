# accuracy_report.json schema

```text
{
  "metadata": {
    "model_name": string,
    "backend": string,
    "timestamp": string,
    "config": string
  },
  "preflight": [string],
  "benchmarks": [
    {
      "name": string,
      "metric": string|null,
      "value": number|null,
      "evaluated_samples": integer|null,
      "error_count": integer|null,
      "error_rate": number|null,
      "status": "passed"|"failed"|"skipped",
      "command": [string],
      "raw_result_path": string|null,
      "log_path": string|null,
      "error_type": string|null,
      "error_message": string|null,
      "output_health": {
        "status": string,
        "sample_file": string|null,
        "summary": {
          "repetition_rate": number|null,
          "severe_repetition_rate": number|null,
          "truncation_rate": number|null,
          "output_cap_hit_rate": number|null,
          "empty_rate": number|null,
          "malformed_rate": number|null,
          "very_short_rate": number|null,
          "output_tokens_avg": number|null,
          "output_tokens_p50": number|null,
          "output_tokens_p95": number|null,
          "avg_heuristic_quality_score": number|null,
          "accuracy_repetition_samples": number|null,
          "accuracy_clean_samples": number|null,
          "repetition_accuracy_gap_pp": number|null,
          "accuracy_truncated_samples": number|null,
          "accuracy_complete_samples": number|null,
          "truncation_accuracy_gap_pp": number|null
        },
        "judge": object|null
      }|null
    }
  ],
  "summary": {
    "passed": boolean,
    "failed_benchmarks": [string],
    "reasons": [string]
  }
}
```

消费者必须优先使用 `status` 和 `error_type` 判断是否可比较，不要把 `null` 当作 0。
