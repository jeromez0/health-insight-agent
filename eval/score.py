"""
Score the runs.json outputs:
- grounding density: count of specific values (numeric+unit) and dates referenced
- cross-domain rate: insights that integrate 2+ of {nutrition, training, recovery}
- generic-claim rate: insights with no specific number/date anchor
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
data = json.loads((ROOT / "results" / "runs.json").read_text())

# domain keyword lexicons
NUTRITION_TERMS = re.compile(r"\b(calor(ie|ic)|protein|carb|fat|fiber|sodium|potassium|sat(urated)? fat|macro|nutrition|kcal|mg|tdee|deficit|surplus)\b", re.I)
TRAINING_TERMS  = re.compile(r"\b(bench|squat|pull[- ]?up|workout|train(ing)?|lift|set|rep|push|pull|lower|rest day|volume|deload|progress)\b", re.I)
RECOVERY_TERMS  = re.compile(r"\b(hrv|readiness|body battery|resting hr|heart rate|recover(y|ed)|sleep|step|garmin)\b", re.I)

# specific-value patterns
NUMBER_UNIT = re.compile(r"\b\d+(?:\.\d+)?\s*(?:cal|calories|kcal|g|mg|lbs|lb|ms|%|bpm|hr|hrs|hour|hours|step|steps)\b", re.I)
DATE = re.compile(r"\b(?:January|February|March|April|May|June|July|August|September|October|November|December|Apr|Mar|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2}\b|\b2026-04-\d{2}\b", re.I)
NAKED_NUMBER = re.compile(r"\b\d{2,4}\b")  # multi-digit number, often a referenced metric


def split_insights(text: str) -> list[str]:
    """Split numbered list into individual insight strings."""
    # match leading "1." "2." etc.
    parts = re.split(r"\n(?=\d+[\.\)]\s)", text.strip())
    # also handle the first one not having a leading newline
    if parts and not re.match(r"\d+[\.\)]\s", parts[0]):
        parts = parts[1:] if len(parts) > 1 else parts
    return [p.strip() for p in parts if p.strip()]


def score_insight(insight: str) -> dict:
    domains = {
        "nutrition": bool(NUTRITION_TERMS.search(insight)),
        "training": bool(TRAINING_TERMS.search(insight)),
        "recovery": bool(RECOVERY_TERMS.search(insight)),
    }
    domain_count = sum(domains.values())
    n_values = len(NUMBER_UNIT.findall(insight))
    n_dates = len(DATE.findall(insight))
    n_naked_numbers = len(NAKED_NUMBER.findall(insight))
    grounded = (n_values + n_dates) >= 2  # ≥2 specific anchors = grounded
    return {
        "domains": domains,
        "domain_count": domain_count,
        "cross_domain": domain_count >= 2,
        "n_values": n_values,
        "n_dates": n_dates,
        "n_naked_numbers": n_naked_numbers,
        "grounded": grounded,
    }


def score_run(text: str) -> dict:
    insights = split_insights(text)
    if not insights:
        return {"n_insights": 0}
    scored = [score_insight(i) for i in insights]
    return {
        "n_insights": len(insights),
        "n_grounded": sum(s["grounded"] for s in scored),
        "n_cross_domain": sum(s["cross_domain"] for s in scored),
        "grounding_rate": sum(s["grounded"] for s in scored) / len(scored),
        "cross_domain_rate": sum(s["cross_domain"] for s in scored) / len(scored),
        "mean_values_per_insight": sum(s["n_values"] for s in scored) / len(scored),
        "mean_dates_per_insight": sum(s["n_dates"] for s in scored) / len(scored),
        "mean_naked_numbers_per_insight": sum(s["n_naked_numbers"] for s in scored) / len(scored),
    }


def aggregate(runs: list[dict]) -> dict:
    keys = ["n_insights", "grounding_rate", "cross_domain_rate", "mean_values_per_insight", "mean_dates_per_insight", "mean_naked_numbers_per_insight"]
    out = {}
    for k in keys:
        vals = [r["scores"][k] for r in runs if "scores" in r]
        out[k] = sum(vals) / len(vals) if vals else 0
    return out


for mode in ("single_shot", "multi_agent"):
    for r in data[mode]:
        r["scores"] = score_run(r["text"])

(ROOT / "results" / "scored.json").write_text(json.dumps(data, indent=2))


print("=== GROUNDING & CROSS-DOMAIN SCORES ===")
for mode in ("single_shot", "multi_agent"):
    agg = aggregate(data[mode])
    print(f"\n{mode}:")
    print(f"  mean insights per run:    {agg['n_insights']:.2f}")
    print(f"  grounding rate:           {agg['grounding_rate']:.2%}")
    print(f"  cross-domain rate:        {agg['cross_domain_rate']:.2%}")
    print(f"  mean values/insight:      {agg['mean_values_per_insight']:.2f}")
    print(f"  mean dates/insight:       {agg['mean_dates_per_insight']:.2f}")
    print(f"  mean numbers/insight:     {agg['mean_naked_numbers_per_insight']:.2f}")

# also print per-run for variance
print("\n=== PER-RUN BREAKDOWN ===")
for mode in ("single_shot", "multi_agent"):
    print(f"\n{mode}:")
    for i, r in enumerate(data[mode], 1):
        s = r["scores"]
        print(f"  run {i}: n={s['n_insights']}, ground={s['grounding_rate']:.0%}, cross={s['cross_domain_rate']:.0%}, vals/ins={s['mean_values_per_insight']:.1f}")
