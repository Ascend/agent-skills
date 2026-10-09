#!/usr/bin/env python3
"""Analyze model output health: repetition, truncation, length, completeness and optional correctness.

The module is benchmark-agnostic at its core and adds lightweight task-aware correctness for
GSM8K-like numeric QA when a target/reference answer is available. It deliberately avoids claiming
that heuristics are a semantic quality judge; an optional LLM judge can be used by the caller.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import statistics
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable

STOP_PUNCT = set("。！？!?;；:：.!?)]}】》”’\"'")
THINK_TAGS = ("<think>", "</think>", "<analysis>", "</analysis>")

@dataclass
class OutputHealth:
    sample_id: str
    text: str
    answer_text: str
    chars: int
    words: int
    approx_tokens: int
    actual_tokens: int | None
    finish_reason: str | None
    max_tokens: int | None
    hit_output_cap: bool
    trailing_incomplete: bool
    explicit_truncation: bool
    empty_output: bool
    sentence_count: int
    repeated_sentence_ratio: float
    repeated_ngram2_ratio: float
    repeated_ngram3_ratio: float
    repeated_ngram4_ratio: float
    max_repeated_sentence_run: int
    longest_repeated_block_chars: int
    repetition_score: float
    too_short: bool
    malformed: bool
    heuristic_quality_score: float
    correctness: bool | None
    anomaly_flags: list[str]


def _clean(text: Any) -> str:
    if text is None:
        return ""
    return str(text).replace("\r\n", "\n").strip()


def _flatten_response(value: Any) -> str:
    """Normalize common lm-eval response shapes into one answer string."""
    if value is None:
        return ""
    if isinstance(value, str):
        return _clean(value)
    if isinstance(value, (int, float, bool)):
        return str(value)
    if isinstance(value, list):
        # lm-eval can expose resps as [["candidate"]] or ["candidate"].
        current: Any = value
        while isinstance(current, list) and current:
            current = current[0]
        return _flatten_response(current)
    if isinstance(value, dict):
        for key in ("text", "content", "generated_text", "output", "answer"):
            if key in value:
                return _flatten_response(value[key])
    return _clean(value)


def _tokens(text: str) -> list[str]:
    # Mixed Chinese/English friendly tokenization for structural repetition analysis.
    return re.findall(r"[A-Za-z0-9_]+|[\u4e00-\u9fff]|[^\s]", text.lower())


def _sentences(text: str) -> list[str]:
    if not text.strip():
        return []
    pieces = re.split(r"(?<=[。！？!?\.!?])\s+|\n{2,}", text.strip())
    return [p.strip() for p in pieces if p.strip()]


def _ngram_repeat_ratio(text: str, n: int) -> float:
    toks = _tokens(text)
    if len(toks) < n:
        return 0.0
    grams = [tuple(toks[i:i + n]) for i in range(len(toks) - n + 1)]
    counts = Counter(grams)
    repeated = sum(c - 1 for c in counts.values() if c > 1)
    return repeated / len(grams)


def _sentence_metrics(text: str) -> tuple[float, int, int]:
    sents = _sentences(text)
    if not sents:
        return 0.0, 0, 0
    norm = [re.sub(r"\s+", " ", s).strip().lower() for s in sents]
    counts = Counter(norm)
    repeated = sum(c - 1 for c in counts.values() if c > 1)
    ratio = repeated / len(norm)
    max_run = 1
    cur = 1
    for i in range(1, len(norm)):
        if norm[i] == norm[i - 1]:
            cur += 1
            max_run = max(max_run, cur)
        else:
            cur = 1
    longest_block = 0
    for sent, count in counts.items():
        if count > 1:
            longest_block = max(longest_block, len(sent))
    return ratio, max_run, longest_block


def _extract_number(text: str) -> str | None:
    patterns = [
        r"####\s*(-?\d+(?:\.\d+)?)",
        r"\\boxed\{\s*(-?\d+(?:\.\d+)?)\s*\}",
        r"(?:final answer|answer|答案)\s*[:：]?\s*(-?\d+(?:\.\d+)?)\s*$",
    ]
    for pattern in patterns:
        matches = re.findall(pattern, text, flags=re.I | re.M)
        if matches:
            return matches[-1]
    nums = re.findall(r"-?\d+(?:\.\d+)?", text)
    return nums[-1] if nums else None


def infer_correctness(benchmark: str, answer_text: str, target: Any) -> bool | None:
    if target is None:
        return None
    target_s = _clean(target)
    pred_s = _clean(answer_text)
    if not target_s:
        return None
    task = benchmark.lower()
    if "gsm8k" in task or "math" in task:
        pred_num = _extract_number(pred_s)
        target_num = _extract_number(target_s)
        if pred_num is None or target_num is None:
            return False
        try:
            return math.isclose(float(pred_num), float(target_num), rel_tol=0.0, abs_tol=1e-9)
        except ValueError:
            return pred_num == target_num
    a = re.sub(r"\s+", " ", pred_s).strip().lower()
    b = re.sub(r"\s+", " ", target_s).strip().lower()
    return a == b


def _trailing_incomplete(text: str) -> bool:
    s = text.strip()
    if not s:
        return False
    if s.endswith(("\\", ",", "，", "、", "(", "（", "[", "【", ":", "：")):
        return True
    # Common Markdown/code delimiters left open at the end.
    if s.count("```") % 2 == 1 or s.count("$") % 2 == 1:
        return True
    if s.count("(") > s.count(")") or s.count("（") > s.count("）"):
        return True
    if len(s) < 24:
        return False
    last = s[-1]
    return last not in STOP_PUNCT and not s.endswith(("</think>", "</analysis>"))


def _malformed(text: str, benchmark: str) -> bool:
    s = text.strip()
    if not s:
        return True
    # Strong signal that generation is an API/template artifact rather than a valid answer.
    if s.startswith("{" ) and s.endswith("}") and "error" in s.lower():
        return True
    if any(marker in s.lower() for marker in ("internal server error", "context length exceeded")):
        return True
    if "gsm8k" in benchmark.lower() and len(_tokens(s)) < 2:
        return True
    return False


def _quality_score(text: str, repeated_ratio: float, trunc: bool, malformed: bool) -> float:
    """A structural quality score, not a semantic truth score.

    The score measures whether an answer is non-empty, reasonably complete and not visibly looping.
    Semantic quality should be supplied by an optional LLM judge when required.
    """
    if not text.strip() or malformed:
        return 0.0
    score = 1.0
    score -= min(0.50, repeated_ratio * 1.5)
    if trunc:
        score -= 0.35
    if len(_tokens(text)) < 8:
        score -= 0.10
    return max(0.0, min(1.0, score))


def analyze_sample(record: dict[str, Any], benchmark: str, max_tokens_default: int | None = None) -> OutputHealth:
    sample_id = str(record.get("id", record.get("sample_id", record.get("doc_id", "unknown"))))
    raw_output = (
        record.get("answer")
        or record.get("output")
        or record.get("prediction")
        or record.get("response")
        or record.get("resps")
        or record.get("filtered_resps")
    )
    answer_text = _flatten_response(raw_output)
    text = answer_text
    actual_tokens = record.get("completion_tokens")
    usage = record.get("usage")
    if actual_tokens is None and isinstance(usage, dict):
        actual_tokens = usage.get("completion_tokens")
    if actual_tokens is not None:
        try:
            actual_tokens = int(actual_tokens)
        except (TypeError, ValueError):
            actual_tokens = None
    finish_reason = record.get("finish_reason")
    if isinstance(record.get("finish_reason"), list):
        finish_reason = record["finish_reason"][0] if record["finish_reason"] else None
    max_tokens = record.get("max_tokens", max_tokens_default)
    try:
        max_tokens = int(max_tokens) if max_tokens is not None else None
    except (TypeError, ValueError):
        max_tokens = None
    sentence_ratio, max_run, repeated_block = _sentence_metrics(answer_text)
    r2 = _ngram_repeat_ratio(answer_text, 2)
    r3 = _ngram_repeat_ratio(answer_text, 3)
    r4 = _ngram_repeat_ratio(answer_text, 4)
    repetition = max(sentence_ratio, r3, min(1.0, r2 * 0.7), min(1.0, r4 * 1.15))
    hit_cap = (str(finish_reason).lower() == "length") or (
        actual_tokens is not None and max_tokens is not None and actual_tokens >= max_tokens * 0.98
    )
    trailing = _trailing_incomplete(answer_text)
    explicit = hit_cap or any(x in answer_text.lower()[-120:] for x in ("truncated", "截断", "token limit"))
    empty = not answer_text.strip()
    malformed = _malformed(answer_text, benchmark)
    target = record.get("target")
    if target is None and isinstance(record.get("doc"), dict):
        for key in ("answer", "target", "reference", "label"):
            if record["doc"].get(key) is not None:
                target = record["doc"][key]
                break
    correctness = infer_correctness(benchmark, answer_text, target)
    flags: list[str] = []
    if empty: flags.append("EMPTY_OUTPUT")
    if repetition >= 0.20: flags.append("SEVERE_REPETITION")
    elif repetition >= 0.10: flags.append("REPETITION")
    if max_run >= 3: flags.append("REPEATED_SENTENCE_LOOP")
    if hit_cap: flags.append("OUTPUT_CAP_HIT")
    if trailing: flags.append("TRAILING_INCOMPLETE")
    if explicit: flags.append("TRUNCATION_SUSPECTED")
    if malformed: flags.append("MALFORMED_OUTPUT")
    tokens_for_short = actual_tokens if actual_tokens is not None else len(_tokens(answer_text))
    too_short = tokens_for_short <= 4
    if too_short: flags.append("VERY_SHORT_OUTPUT")
    quality = _quality_score(answer_text, repetition, hit_cap or trailing, malformed)
    chars = len(answer_text)
    words = len(re.findall(r"\b\w+\b", answer_text, flags=re.UNICODE))
    approx_tokens = max(1, math.ceil(len(_tokens(answer_text)) * 1.08)) if answer_text else 0
    return OutputHealth(
        sample_id=sample_id,
        text=answer_text,
        answer_text=answer_text,
        chars=chars,
        words=words,
        approx_tokens=approx_tokens,
        actual_tokens=actual_tokens,
        finish_reason=str(finish_reason) if finish_reason is not None else None,
        max_tokens=max_tokens,
        hit_output_cap=hit_cap,
        trailing_incomplete=trailing,
        explicit_truncation=explicit,
        empty_output=empty,
        sentence_count=len(_sentences(answer_text)),
        repeated_sentence_ratio=sentence_ratio,
        repeated_ngram2_ratio=r2,
        repeated_ngram3_ratio=r3,
        repeated_ngram4_ratio=r4,
        max_repeated_sentence_run=max_run,
        longest_repeated_block_chars=repeated_block,
        repetition_score=repetition,
        too_short=too_short,
        malformed=malformed,
        heuristic_quality_score=quality,
        correctness=correctness,
        anomaly_flags=flags,
    )


def _iter_records(path: Path) -> Iterable[dict[str, Any]]:
    if path.suffix.lower() == ".jsonl":
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                obj = json.loads(line)
                if isinstance(obj, dict):
                    yield obj
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        for obj in data:
            if isinstance(obj, dict):
                yield obj
    elif isinstance(data, dict):
        for key in ("samples", "results", "data"):
            rows = data.get(key)
            if isinstance(rows, list):
                for obj in rows:
                    if isinstance(obj, dict):
                        yield obj
                return
        # One-record object fallback.
        yield data


def summarize(items: list[OutputHealth]) -> dict[str, Any]:
    if not items:
        return {"sample_count": 0}
    def pct(fn) -> float:
        return sum(1 for x in items if fn(x)) / len(items)
    token_values = [x.actual_tokens if x.actual_tokens is not None else x.approx_tokens for x in items]
    correct_known = [x.correctness for x in items if x.correctness is not None]
    repeated_correct = [x.correctness for x in items if x.repetition_score >= 0.10 and x.correctness is not None]
    clean_correct = [x.correctness for x in items if x.repetition_score < 0.10 and not x.explicit_truncation and x.correctness is not None]
    truncated_correct = [x.correctness for x in items if (x.explicit_truncation or x.trailing_incomplete) and x.correctness is not None]
    complete_correct = [x.correctness for x in items if not (x.explicit_truncation or x.trailing_incomplete) and x.correctness is not None]
    return {
        "sample_count": len(items),
        "empty_rate": pct(lambda x: x.empty_output),
        "malformed_rate": pct(lambda x: x.malformed),
        "repetition_rate": pct(lambda x: x.repetition_score >= 0.10),
        "severe_repetition_rate": pct(lambda x: x.repetition_score >= 0.20 or x.max_repeated_sentence_run >= 3),
        "truncation_rate": pct(lambda x: x.explicit_truncation or x.trailing_incomplete),
        "output_cap_hit_rate": pct(lambda x: x.hit_output_cap),
        "very_short_rate": pct(lambda x: x.too_short),
        "avg_repetition_score": statistics.mean(x.repetition_score for x in items),
        "avg_heuristic_quality_score": statistics.mean(x.heuristic_quality_score for x in items),
        "output_tokens_avg": statistics.mean(token_values),
        "output_tokens_p50": statistics.median(token_values),
        "output_tokens_p95": _percentile(token_values, 0.95),
        "output_chars_avg": statistics.mean(x.chars for x in items),
        "accuracy_known_samples": (sum(1 for x in correct_known if x) / len(correct_known)) if correct_known else None,
        "accuracy_repetition_samples": (sum(1 for x in repeated_correct if x) / len(repeated_correct)) if repeated_correct else None,
        "accuracy_clean_samples": (sum(1 for x in clean_correct if x) / len(clean_correct)) if clean_correct else None,
        "accuracy_truncated_samples": (sum(1 for x in truncated_correct if x) / len(truncated_correct)) if truncated_correct else None,
        "accuracy_complete_samples": (sum(1 for x in complete_correct if x) / len(complete_correct)) if complete_correct else None,
        "repetition_accuracy_gap_pp": ((sum(1 for x in clean_correct if x) / len(clean_correct)) - (sum(1 for x in repeated_correct if x) / len(repeated_correct))) * 100 if repeated_correct and clean_correct else None,
        "truncation_accuracy_gap_pp": ((sum(1 for x in complete_correct if x) / len(complete_correct)) - (sum(1 for x in truncated_correct if x) / len(truncated_correct))) * 100 if truncated_correct and complete_correct else None,
    }


def _percentile(values: list[float], q: float) -> float:
    if not values:
        return 0.0
    arr = sorted(values)
    index = (len(arr) - 1) * q
    lo = int(math.floor(index)); hi = int(math.ceil(index))
    if lo == hi:
        return arr[lo]
    return arr[lo] + (arr[hi] - arr[lo]) * (index - lo)


def analyze_file(path: Path, benchmark: str, max_tokens: int | None = None) -> dict[str, Any]:
    rows = [analyze_sample(row, benchmark, max_tokens) for row in _iter_records(path)]
    return {"benchmark": benchmark, "source": str(path), "samples": [asdict(x) for x in rows], "summary": summarize(rows)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("samples", type=Path)
    parser.add_argument("--benchmark", default="unknown")
    parser.add_argument("--max-tokens", type=int)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = analyze_file(args.samples, args.benchmark, args.max_tokens)
    payload = json.dumps(result, ensure_ascii=False, indent=2)
    print(payload)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# ---------------------------------------------------------------------------
# Report helpers used by the parent Skill.
# ---------------------------------------------------------------------------

def render_health_summary(health: dict[str, Any]) -> str:
    s = health.get("summary", {})
    if not s.get("sample_count"):
        return "No output-health samples were available."
    def f(name: str, digits: int = 2) -> str:
        value = s.get(name)
        if value is None:
            return "-"
        if name.endswith("rate"):
            return f"{value * 100:.{digits}f}%"
        return f"{value:.{digits}f}"
    lines = [
        f"samples={s['sample_count']}",
        f"repetition={f('repetition_rate')}",
        f"severe_repetition={f('severe_repetition_rate')}",
        f"truncation={f('truncation_rate')}",
        f"empty={f('empty_rate')}",
        f"cap_hit={f('output_cap_hit_rate')}",
        f"p50_output_tokens={f('output_tokens_p50')}",
        f"p95_output_tokens={f('output_tokens_p95')}",
        f"heuristic_quality={f('avg_heuristic_quality_score')}",
        f"accuracy(repeated)={f('accuracy_repetition_samples')}",
        f"accuracy(clean)={f('accuracy_clean_samples')}",
        f"repetition_accuracy_gap_pp={f('repetition_accuracy_gap_pp')}",
    ]
    return "; ".join(lines)
