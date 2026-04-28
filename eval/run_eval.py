"""
Direct API harness for the HealthInsightAgent eval.
Runs single-shot mode 5x and multi-agent mode 5x on the same 7-day mock dataset
that the iOS app uses, captures tokens/latency/text, and writes results to JSON.
"""

from __future__ import annotations

import json
import os
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests

API_KEY = os.environ.get("OPENAI_API_KEY", "")
if not API_KEY:
    raise SystemExit("Set OPENAI_API_KEY env var. See README.md.")
MODEL = "gpt-4o-mini"
ENDPOINT = "https://api.openai.com/v1/chat/completions"
N_RUNS = 5

OUT_DIR = Path(__file__).parent / "results"
OUT_DIR.mkdir(exist_ok=True)


# ---------- prompts (verbatim from AgentPrompts.swift) ----------

SINGLE_SHOT_SYSTEM = """You are a personal health analyst interpreting one week of self-tracking data spanning nutrition (daily macros), training (workouts), and recovery (Garmin biometrics).

Your task: produce 3 to 5 actionable health insights for this week. For each insight:
- Reference specific values, days, or trends in the data — do not make generic claims.
- When signals from different domains interact (e.g., nutrition affecting recovery), surface that connection explicitly.
- Keep each insight to 2-4 sentences.

Format your response as a numbered list of insights. Begin each insight with a short bold-able title, then the body. Do not include a preamble or summary outside the list."""

NUTRITION_AGENT_SYSTEM = """You are a NUTRITION SPECIALIST agent. You analyze one week of daily macro data (calories, protein/carbs/fat, fiber, sodium, micronutrients).

Produce a concise summary covering:
1. Caloric and macronutrient adherence patterns across the week.
2. Notable spikes, dips, or trends in any specific macro.
3. Concerns: low fiber days, sodium spikes, missing logs, etc.

Be specific — cite actual numbers and dates. Output 4-6 short bullets, no preamble. Keep total response under 200 tokens. Other specialists handle training and recovery — focus only on nutrition."""

TRAINING_AGENT_SYSTEM = """You are a TRAINING SPECIALIST agent. You analyze one week of workout data (split type, main lifts, volume).

Produce a concise summary covering:
1. Training frequency and split rotation across the week.
2. Progression on main compound lifts (e.g., did bench press load increase?).
3. Recovery distribution: rest day count and placement.

Be specific — cite actual lift loads and dates. Output 4-6 short bullets, no preamble. Keep total response under 200 tokens. Other specialists handle nutrition and recovery — focus only on training."""

RECOVERY_AGENT_SYSTEM = """You are a RECOVERY SPECIALIST agent. You analyze one week of Garmin biometric data (HRV, body battery, training readiness, resting heart rate, steps).

Produce a concise summary covering:
1. HRV trend across the week (improving, stable, declining, with specific values).
2. Body battery patterns and any days with notable depletion.
3. Training readiness scores and overall recovery quality assessment.

Be specific — cite actual numbers and dates. Output 4-6 short bullets, no preamble. Keep total response under 200 tokens. Other specialists handle nutrition and training — focus only on recovery."""

ORCHESTRATOR_SYSTEM = """You are the ORCHESTRATOR for a multi-agent personal health analysis system. Three specialist agents have analyzed one week of data — Nutrition, Training, and Recovery — and produced summaries. You also have access to the raw data for cross-referencing.

Your task: synthesize 3 to 5 cross-domain insights for this week. Specifically:
- Identify points where the three domains AGREE (e.g., "training load was high and recovery markers softened — consistent picture").
- Identify points where the three domains DISAGREE or show tension (e.g., "training readiness was high but nutrition was poor — the body has reserves the food intake isn't supporting").
- Reference specific values, days, or trends — do not make generic claims.
- Each insight should integrate at least two domains where possible.

Format as a numbered list of insights. Each insight: short bold-able title, then 2-4 sentences. Do not include a preamble or summary outside the list."""


# ---------- mock data (transcribed from MockData.swift) ----------

MACROS = [
    ("2026-04-19", None),
    ("2026-04-20", dict(cal=2050, p=145, c=180, f=75, sat=22, fib=28, na=2400, k=2800)),
    ("2026-04-21", dict(cal=2210, p=162, c=195, f=80, sat=25, fib=31, na=2200, k=3100)),
    ("2026-04-22", dict(cal=1850, p=130, c=160, f=70, sat=19, fib=24, na=1900, k=2500)),
    ("2026-04-23", dict(cal=1920, p=138, c=172, f=72, sat=20, fib=26, na=2100, k=2650)),
    ("2026-04-24", dict(cal=2110, p=123, c=175, f=107, sat=39, fib=32, na=1528, k=2635)),
    ("2026-04-25", dict(cal=1915, p=121, c=115, f=107, sat=43, fib=9,  na=2761, k=1485)),
]

WORKOUTS = [
    ("2026-04-19", "pull",  "Weighted Pull-ups", 4, 6, 25),
    ("2026-04-20", "push",  "Bench Press",       3, 8, 205),
    ("2026-04-21", "lower", "Front Squats",      3, 5, 205),
    ("2026-04-22", "rest",  None, None, None, None),
    ("2026-04-23", "rest",  None, None, None, None),
    ("2026-04-24", "rest",  None, None, None, None),
    ("2026-04-25", "push",  "Bench Press",       3, 5, 225),
]

GARMIN = [
    ("2026-04-19", 55, 36, 90,  46, 100, 2188, 85,  "HIGH",     1),
    ("2026-04-20", 57, 35, 80,  43, 48,  131,  72,  "MODERATE", 8),
    ("2026-04-21", 56, 37, 100, 37, 87,  3032, 100, "PRIME",    1),
    ("2026-04-22", 53, 37, 100, 44, 90,  599,  94,  "HIGH",     0),
    ("2026-04-23", 58, 38, 91,  46, 52,  128,  94,  "HIGH",     0),
    ("2026-04-24", 57, 40, 81,  15, 76,  2275, 91,  "HIGH",     1),
    ("2026-04-25", 56, 39, 85,  25, 80,  1850, 88,  "HIGH",     1),
]


def render_nutrition() -> str:
    lines = ["NUTRITION DATA — 7 DAYS (2026-04-19 to 2026-04-25)"]
    for date, m in MACROS:
        if m is None:
            lines.append(f"{date}: no log")
        else:
            lines.append(
                f"{date}: {m['cal']} cal · {m['p']}p / {m['c']}c / {m['f']}f · "
                f"sat fat {m['sat']}g · fiber {m['fib']}g · sodium {m['na']}mg · potassium {m['k']}mg"
            )
    return "\n".join(lines)


def render_training() -> str:
    lines = ["TRAINING DATA — 7 DAYS (2026-04-19 to 2026-04-25)"]
    for date, t, lift, sets, reps, w in WORKOUTS:
        if t == "rest":
            lines.append(f"{date}: rest day")
        else:
            lines.append(f"{date}: {t} — {lift} {w}lbs × {reps} × {sets}")
    return "\n".join(lines)


def render_recovery() -> str:
    lines = ["RECOVERY / GARMIN DATA — 7 DAYS (2026-04-19 to 2026-04-25)"]
    for date, rhr, hrv, hrvp, bbl, bbh, steps, tr, lvl, rec in GARMIN:
        lines.append(
            f"{date}: readiness {tr} ({lvl}) · HRV {hrv}ms / {hrvp}% · "
            f"resting HR {rhr} · body battery {bbl}→{bbh} · steps {steps} · recovery {rec}hr"
        )
    return "\n".join(lines)


def render_full_week() -> str:
    return (
        "PERSONAL HEALTH DATA — 7 DAYS (2026-04-19 to 2026-04-25)\n\n"
        f"=== NUTRITION (DAILY MACROS) ===\n{render_nutrition().split(chr(10), 1)[1]}\n\n"
        f"=== TRAINING (WORKOUTS) ===\n{render_training().split(chr(10), 1)[1]}\n\n"
        f"=== RECOVERY (GARMIN) ===\n{render_recovery().split(chr(10), 1)[1]}"
    )


# ---------- API ----------

def call(system: str, user: str, temperature: float = 0.4) -> tuple[str, int, int, float]:
    body = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": temperature,
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }
    t0 = time.time()
    r = requests.post(ENDPOINT, json=body, headers=headers, timeout=120)
    elapsed = time.time() - t0
    r.raise_for_status()
    j = r.json()
    text = j["choices"][0]["message"]["content"]
    pt = j["usage"]["prompt_tokens"]
    ct = j["usage"]["completion_tokens"]
    return text, pt, ct, elapsed


def run_single_shot() -> dict:
    user = "Here is the data:\n\n" + render_full_week()
    text, pt, ct, elapsed = call(SINGLE_SHOT_SYSTEM, user)
    return {
        "mode": "single_shot",
        "text": text,
        "input_tokens": pt,
        "output_tokens": ct,
        "total_tokens": pt + ct,
        "latency_sec": elapsed,
        "n_calls": 1,
    }


def run_multi_agent() -> dict:
    nutrition_user = "Here is the nutrition data:\n\n" + render_nutrition()
    training_user = "Here is the training data:\n\n" + render_training()
    recovery_user = "Here is the recovery data:\n\n" + render_recovery()

    t0 = time.time()
    with ThreadPoolExecutor(max_workers=3) as ex:
        f_n = ex.submit(call, NUTRITION_AGENT_SYSTEM, nutrition_user)
        f_t = ex.submit(call, TRAINING_AGENT_SYSTEM, training_user)
        f_r = ex.submit(call, RECOVERY_AGENT_SYSTEM, recovery_user)
        n_text, n_pt, n_ct, _ = f_n.result()
        t_text, t_pt, t_ct, _ = f_t.result()
        r_text, r_pt, r_ct, _ = f_r.result()
    stage1_elapsed = time.time() - t0

    orch_user = (
        "=== NUTRITION SPECIALIST SUMMARY ===\n" + n_text + "\n\n"
        "=== TRAINING SPECIALIST SUMMARY ===\n" + t_text + "\n\n"
        "=== RECOVERY SPECIALIST SUMMARY ===\n" + r_text + "\n\n"
        "=== RAW DATA (FOR CROSS-REFERENCE) ===\n" + render_full_week()
    )
    o_text, o_pt, o_ct, o_elapsed = call(ORCHESTRATOR_SYSTEM, orch_user)

    return {
        "mode": "multi_agent",
        "text": o_text,
        "specialist_outputs": {"nutrition": n_text, "training": t_text, "recovery": r_text},
        "input_tokens": n_pt + t_pt + r_pt + o_pt,
        "output_tokens": n_ct + t_ct + r_ct + o_ct,
        "total_tokens": n_pt + t_pt + r_pt + o_pt + n_ct + t_ct + r_ct + o_ct,
        "stage1_latency_sec": stage1_elapsed,
        "orchestrator_latency_sec": o_elapsed,
        "latency_sec": stage1_elapsed + o_elapsed,
        "n_calls": 4,
    }


def main() -> None:
    results = {"single_shot": [], "multi_agent": []}
    for i in range(N_RUNS):
        print(f"single_shot run {i+1}/{N_RUNS}...")
        results["single_shot"].append(run_single_shot())
    for i in range(N_RUNS):
        print(f"multi_agent run {i+1}/{N_RUNS}...")
        results["multi_agent"].append(run_multi_agent())

    out_path = OUT_DIR / "runs.json"
    out_path.write_text(json.dumps(results, indent=2))
    print(f"\nwrote {out_path}")

    def agg(runs: list[dict], key: str) -> float:
        vals = [r[key] for r in runs]
        return sum(vals) / len(vals)

    print("\n--- AGGREGATES ---")
    for mode in ("single_shot", "multi_agent"):
        runs = results[mode]
        print(f"{mode}:")
        print(f"  mean total_tokens: {agg(runs, 'total_tokens'):.0f}")
        print(f"  mean input_tokens: {agg(runs, 'input_tokens'):.0f}")
        print(f"  mean output_tokens: {agg(runs, 'output_tokens'):.0f}")
        print(f"  mean latency_sec:  {agg(runs, 'latency_sec'):.2f}")
        print(f"  n_calls per run:   {runs[0]['n_calls']}")


if __name__ == "__main__":
    main()
