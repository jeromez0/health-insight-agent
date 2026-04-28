# Health Insight Agent — Slide Deck

> 8 slides. Speaker notes are in `speaker_notes.md`. Total target presentation time: 6-7 minutes.

---

## Slide 1: Title

**Health Insight Agent**

A Multi-Agent LLM Architecture for Personal Longitudinal Health Data Interpretation

Jerome Zhang · MSAI High-Risk Project · Spring 2026

---

## Slide 2: The Problem

### Personal Health Data Is Fragmented

- **Wearables** capture biometrics (HRV, sleep, body battery)
- **Food apps** track nutrition (macros, micros)
- **Training journals** log resistance work
- ...but no system unifies them into actionable insights

### Existing LLM approaches use single-shot prompting

- Dump everything into one prompt
- Ask the LLM to figure it out
- Generic, ungrounded outputs
- Hidden cross-domain disagreements

---

## Slide 3: Research Question

> *Does a multi-agent LLM architecture produce more grounded, domain-specific health insights than single-shot LLM prompting on identical longitudinal personal health data?*

### Approach

Build both. Compare side-by-side. Measure what differs.

---

## Slide 4: Method — Architecture

```
                    7-Day Personal Health Data
              (Macros + Workouts + Garmin biometrics)
                              │
       ┌──────────────────────┼──────────────────────┐
       ▼                      ▼                      ▼
  ┌────────┐           ┌──────────┐          ┌──────────┐
  │Nutrition│           │ Training │          │ Recovery │       Stage 1
  │  Agent  │           │  Agent   │          │  Agent   │     (parallel)
  └────┬────┘           └─────┬────┘          └─────┬────┘
       │                      │                     │
       └──────────────────────┼─────────────────────┘
                              ▼
                      ┌──────────────┐
                      │ Orchestrator │                          Stage 2
                      │    Agent     │
                      └──────┬───────┘
                             ▼
                    3-5 Cross-Domain Insights
```

- **Single-shot mode:** 1 LLM call. All data. Direct prompt → output.
- **Multi-agent mode:** 4 LLM calls. 3 specialists in parallel + 1 orchestrator.

---

## Slide 5: Implementation

- **Platform:** Native iOS app (SwiftUI, iOS 17+)
- **LLM:** GPT-4o-mini via OpenAI Chat Completions API
- **Networking:** pure URLSession, no SDK
- **Data:** 7 days of real self-tracked data (Apr 19-25, 2026)
- **Domains:** macros (food log) + workouts (split + main lift) + Garmin (HRV, body battery, training readiness)

[INCLUDE 1 SCREENSHOT OF THE APP HERE — recommend the segmented control + insights card]

---

## Slide 6: Results

n=5 generations per mode, identical 7-day dataset, GPT-4o-mini, temp 0.4.

| Metric | Single-Shot | Multi-Agent |
|---|---|---|
| Grounding rate | **100%** | **100%** |
| Cross-domain integration rate | 76% (range 40-100%) | **100%** (no variance) |
| Total tokens (mean) | 1352 | 3603 (**2.66×**) |
| Wall-clock latency (mean) | 9.80s | 13.90s (**1.42×**) |
| LLM calls / generation | 1 | 4 |

### Headline finding

Both architectures hit 100% grounding (no hallucinated values). Multi-agent's win is **consistency on cross-domain integration** — it never dropped below 100%, while single-shot had one run at 40%. Cost: 2.66× tokens, 1.42× latency.

---

## Slide 7: Future Directions

- **Scale up:** evaluate on public datasets (LifeSnaps, MyHeart Counts) across many users
- **Clinical validation:** pair LLM outputs with clinician annotation for correctness, not just grounding
- **Adaptive routing:** dynamically choose which specialists to invoke based on user query
- **On-device inference:** swap GPT-4o-mini for Apple's Foundation Models framework — privacy-preserving deployment
- **Persistent memory:** cross-session insight tracking ("did you act on last week's recommendation?")

---

## Slide 8: Thank You

**Jerome Zhang** · MSAI High-Risk Project · Spring 2026

Code & report: https://github.com/jeromez0/health-insight-agent

Questions?
