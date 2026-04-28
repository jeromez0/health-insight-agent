# Health Insight Agent: A Multi-Agent LLM Architecture for Personal Longitudinal Health Data Interpretation

**Author:** Jerome Zhang
**Course:** MSAI High-Risk Project, Spring 2026
**Date:** April 27, 2026

---

## Abstract

Personal health data is increasingly captured across heterogeneous sources — wearables for biometrics, manual logs for nutrition, training apps for resistance work — but these silos rarely produce unified, actionable insights for the individual. Existing LLM-based health assistants typically take a *single-shot* approach: dump all data into one prompt and ask for an interpretation. This work investigates whether a **multi-agent LLM architecture** — specialist agents per data domain coordinated by an orchestrator — produces more grounded, domain-specific insights than single-shot prompting on identical data. **The high-risk choice in this project was to implement and evaluate the architectures inside a fully working native iOS application against the author's own self-tracked personal health data, rather than as a Jupyter notebook against a public benchmark.** This decision accepted three concrete risks: (1) the iOS engineering effort would crowd out research depth, (2) N=1 personal data has no ground truth and limits generalizability, and (3) running the eval through real API calls (rather than cached responses) made every iteration cost real money. We accepted these risks because the goal was to test whether a multi-agent personal health system could plausibly ship as a real consumer product, not just whether it produces a better number on a leaderboard. We implement both architectures in an iOS application using GPT-4o-mini, evaluate them on a 7-day longitudinal personal dataset spanning nutrition, training, and recovery signals, and report on grounding rate, cross-domain integration rate, and qualitative differences across the two modes. Our results show that both architectures achieve 100% grounding with no observed hallucinated values, but multi-agent eliminates the run-to-run variance in cross-domain integration that single-shot exhibits (multi-agent: 100% vs single-shot: 76%, with one single-shot run as low as 40%). This consistency comes at a cost of 2.66× tokens and 1.42× latency. The headline finding is not that multi-agent produces better individual insights, but that it produces *more reliable* cross-domain insights — a tradeoff that may be worth the cost for weekly or monthly summaries even if not for daily insights.

---

## 1. Introduction

The number of consumer health-tracking devices and applications has grown rapidly over the last decade, producing an unprecedented volume of personal longitudinal data: continuous heart rate variability (HRV) and stress signals from wearables, daily macronutrient and micronutrient logs from food-tracking apps, and granular per-set resistance training metrics from workout journals. Yet despite this abundance, individuals consistently report that the data feels *fragmented* — each application interprets its own narrow domain, and cross-domain insights ("you slept poorly all week, your protein intake dropped 25%, and your bench press regressed") rarely surface.

Large language models present an opportunity to unify these silos. Recent work has demonstrated that LLMs can interpret structured health data and produce naturalistic recommendations [1, 2]. However, the dominant approach in the literature and in deployed products is what we term **single-shot prompting**: the entire multi-domain data corpus is concatenated into a single prompt, and the LLM is asked to produce insights in one inference call.

We hypothesize that single-shot prompting on multi-domain personal health data has three structural weaknesses:

1. **Domain conflation.** A single prompt forces the LLM to allocate attention across heterogeneous data types simultaneously. Specialized reasoning that would be straightforward within a domain (e.g., evaluating macronutrient adequacy against established guidelines) becomes diluted by competition with adjacent domains (e.g., training volume analysis).
2. **Ungrounded inference.** Without explicit per-domain analysis steps, single-shot outputs frequently produce vague or generic claims that do not trace to specific data points in the input.
3. **Hidden disagreement.** When data across domains is in tension (e.g., training readiness is high but nutritional recovery is poor), single-shot prompting tends to surface the easier signal and elide the conflict.

We propose that a **multi-agent LLM architecture** — in which specialist agents process each domain in isolation before an orchestrator integrates their outputs — addresses these weaknesses by making each reasoning step explicit and inspectable. This work asks:

> *Does a multi-agent LLM architecture produce more grounded, domain-specific health insights than single-shot LLM prompting on identical longitudinal personal health data?*

To investigate this question, we built **Health Insight Agent**, an iOS application that implements both architectures over the same 7-day personal health dataset and exposes them as side-by-side comparable modes via a UI toggle. Our contributions are:

- **A novel application of multi-agent LLM orchestration to personal longitudinal health data.** Prior multi-agent work has focused largely on clinical decision support [3] or generic agentic task completion; we adapt it to the unique constraints of consumer self-tracking data.
- **An evaluation framework** for grounding rate and hallucination rate that is tractable to apply on small personal datasets without requiring clinical expert annotation.
- **An open implementation** in Swift/iOS using GPT-4o-mini, demonstrating that multi-agent personal health interpretation is feasible at consumer cost and latency profiles.

The remainder of this paper is organized as follows. Section 2 reviews related work. Section 3 details our methodology, including the agent architecture, evaluation protocol, and dataset. Section 4 presents results across single-shot and multi-agent modes. Section 5 concludes with limitations and future directions.

---

## 2. Related Work

We position this work within three threads of recent literature.

### 2.1 LLMs for Health Risk Prediction

The use of LLMs for health-domain prediction tasks has expanded rapidly. Cui et al. [1] explored ChatGPT's capabilities for cardiovascular risk prediction, demonstrating that prompted general-purpose LLMs can match or exceed traditional risk calculators on a variety of disease prediction tasks when given structured patient data. Their work, however, focuses on single-prediction tasks (yes/no risk classification) rather than open-ended longitudinal interpretation, and uses single-shot prompting throughout. Our work extends this direction by considering open-ended, multi-domain interpretation rather than discrete prediction, and by introducing architectural decomposition to the prompting strategy.

### 2.2 Multi-Agent LLM Systems

The rise of agentic LLM frameworks [2] has demonstrated that decomposing complex tasks across specialized agents can improve performance on planning and reasoning benchmarks. Hong et al. [2] showed that explicit role assignment among agents (e.g., planner, coder, tester) outperforms monolithic prompting on software engineering benchmarks. The application of this paradigm to *personal* (rather than clinical) health data is underexplored. Most agentic health work targets multi-physician collaboration simulations [3] or large-scale clinical record interpretation; consumer-grade self-tracking data — with its small sample sizes, heterogeneous schemas, and N=1 grounding constraints — has received comparatively little attention.

### 2.3 Explainable AI in Health

Su-In Lee's lab and others [4] have advanced the case for explainable AI in healthcare, with particular emphasis on tracing model claims back to underlying input features. Our grounding rate metric is methodologically aligned with this thread: we evaluate whether each claim produced by an LLM can be traced to a specific data point in the input. This is a coarser version of the SHAP-style attribution work in [4], but is tractable to compute on small personal datasets without requiring access to model internals (since GPT-4o-mini is closed-weight).

---

## 3. Methodology

### 3.1 Dataset

The evaluation dataset consists of **7 consecutive days of personal health data** (April 19–25, 2026) collected from the author's own self-tracking infrastructure. Three data domains are represented:

- **Nutrition (macros):** daily totals for calories, macronutrients (protein, carbohydrates, fat, saturated fat), and selected micronutrients (sodium, potassium, fiber, calcium, magnesium, iron, vitamins A/C/D). Source: manual food log with portion estimation.
- **Training (workouts):** per-day workout type (push / pull / lower / rest), main compound lift (bench press, weighted pull-ups, front squats), and load (sets × reps × weight in pounds). Source: manual training journal.
- **Recovery (Garmin):** resting heart rate, HRV (heart rate variability) percentage and absolute (ms), body battery range (low/high), training readiness score (0–100), readiness level (LOW / MODERATE / HIGH / PRIME), recovery time hours, and total step count. Source: Garmin Epix Pro wearable.

Some days exhibit partial data — for example, days without recorded workouts (rest days), or days with incomplete macro logs. Rather than impute missing values, we pass the data verbatim to both LLM modes so that the model's handling of incomplete data is part of what is being evaluated.

### 3.2 Single-Shot Architecture

In the single-shot architecture, the entire 7-day dataset across all three domains is concatenated into a single user prompt and submitted to GPT-4o-mini in one API call. The system prompt instructs the model to produce 3–5 actionable health insights for the week, drawing on cross-domain patterns where they exist. The full data payload for the week is approximately 2,500 tokens.

### 3.3 Multi-Agent Architecture

The multi-agent architecture decomposes the same task across four LLM calls, executed in two stages:

**Stage 1 (parallel specialist agents):**
- **Nutrition Agent** receives only the macros data and is instructed to produce a domain-specific summary including target adherence, notable patterns, and concerns.
- **Training Agent** receives only the workouts data and is instructed to summarize training volume, split rotation, progression on main lifts, and recovery considerations.
- **Recovery Agent** receives only the Garmin data and is instructed to interpret HRV trends, body battery patterns, sleep/stress signal proxies, and readiness scores.

Each specialist agent uses GPT-4o-mini with a focused system prompt that establishes its role and output format. Specialist outputs are kept concise (under 200 tokens each) to minimize orchestrator input bloat.

**Stage 2 (orchestrator agent):**
- The **Orchestrator Agent** receives the three specialist summaries plus a compact reference to the raw data. It is instructed to synthesize 3–5 cross-domain insights, with a specific directive to surface points where signals from different domains agree or disagree.

The architecture is illustrated in Figure 1.

```
┌─────────────────────────────────────────────────────────┐
│           7-Day Personal Health Data (raw)              │
│   Macros  │  Workouts  │  Garmin (HRV, body battery)    │
└─────────────────────────────────────────────────────────┘
       │                │                  │
       ▼                ▼                  ▼
┌────────────┐   ┌────────────┐    ┌────────────┐
│ Nutrition  │   │  Training  │    │  Recovery  │
│   Agent    │   │   Agent    │    │   Agent    │       Stage 1
└─────┬──────┘   └──────┬─────┘    └──────┬─────┘
      │                 │                 │
      └─────────────────┼─────────────────┘
                        │
                        ▼
              ┌──────────────────┐
              │   Orchestrator   │                       Stage 2
              │      Agent       │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │  3–5 Insights    │
              │  (cross-domain)  │
              └──────────────────┘
```
*Figure 1. Multi-agent architecture for cross-domain health interpretation. Stage 1 specialist agents process each domain in parallel; Stage 2 orchestrator synthesizes cross-domain insights.*

### 3.4 Implementation

Both modes are implemented in a SwiftUI iOS application targeting iOS 17+. The networking layer is a minimal `URLSession`-based client (no SDK dependency) calling the OpenAI Chat Completions API with model `gpt-4o-mini`. All four agent prompts are stored as static string constants in the application binary; mock health data for the 7 days is also in-binary, allowing the application to run fully offline for the data layer (only the LLM calls touch the network).

All source code, evaluation harness, scoring scripts, and per-run output JSONs are publicly available at <https://github.com/jeromez0/health-insight-agent>. Re-running the eval requires only an OpenAI API key and approximately \$0.05 of API credit per full 10-generation run.

The UI consists of a single screen with a segmented control to select the inference mode, a scrolling display of the 7-day health data, a "Generate Insights" button, and a results card showing the produced insights along with metadata (mode used, total LLM calls, total token usage, wall-clock latency).

### 3.5 Evaluation Protocol

For each architecture mode, we ran the insight generation **5 times** on the identical 7-day dataset (15 generations total: 5 single-shot × 1 mode + 5 multi-agent × 1 mode = 10). For each generated insight, we manually scored two metrics:

- **Grounding rate:** the fraction of claims in the insight that trace to specific data points in the input. A claim is *grounded* if it cites or implies a specific value, day, or trend that can be verified against the dataset.
- **Hallucination rate:** the fraction of claims that are *contradicted by* the data, or *not present in* the data.

A single insight typically contains 2–5 claims; we score each claim independently and then aggregate at the insight and run level. We also recorded total token usage and wall-clock latency for each run.

Given the small N and single-author scoring, we report results as descriptive statistics rather than inferential tests. The intent is to produce a meaningful qualitative and quantitative signal of whether multi-agent architecture *is* more grounded, not to publish a definitive answer.

---

## 4. Results

### 4.1 Quantitative Results

| Metric | Single-Shot (n=5) | Multi-Agent (n=5) |
|---|---|---|
| Insights per generation (mean) | 5.00 | 5.00 |
| Grounding rate (mean) | 100% | 100% |
| Cross-domain integration rate (mean) | 76% | 100% |
| Specific values per insight (mean) | 2.32 | 2.16 |
| Specific dates per insight (mean) | 1.88 | 1.72 |
| Total tokens (mean) | 1352 | 3603 |
| Wall-clock latency (mean, sec) | 9.80 | 13.90 |
| LLM calls per generation | 1 | 4 |

*Table 1. Aggregate results across n=5 generations per mode on identical 7-day dataset, GPT-4o-mini, temperature 0.4. An insight is "grounded" if it references at least two specific anchors (numeric value with unit or explicit date). An insight is "cross-domain" if it integrates ≥2 of {nutrition, training, recovery}.*

Both architectures produced 5 insights per generation reliably and achieved 100% grounding rate — every insight referenced at least two specific anchors from the data, and we observed no hallucinated values (e.g., no fabricated dates, no invented metric values). The two architectures differ on **cross-domain integration**: single-shot achieved 76% cross-domain rate with high run-to-run variance (one run dropped to 40%), while multi-agent maintained 100% cross-domain integration across all five runs. Per-insight density of specific values and dates was comparable across architectures, with single-shot slightly denser on raw count.

### 4.2 Qualitative Observations

Reading the outputs side by side surfaces three patterns that the aggregate metrics do not capture.

**Tension-framing in multi-agent outputs.** The orchestrator system prompt explicitly asks for points of agreement and disagreement across domains. This produces a recurring framing in multi-agent outputs — insights are titled "Tension Between Nutrition and Recovery" or "Training Load and Recovery Alignment" and the body of the insight is structured around contrast. Single-shot outputs are also cross-domain at 76% but the framing is more often correlational ("nutrition X corresponds to recovery Y") than tension-aware ("nutrition X looks adequate but recovery Y suggests otherwise"). For a personal health context where the goal is to surface actionable signal rather than confirm everything is fine, the tension framing is more useful.

To make this concrete, consider one insight from each mode produced on the same 7-day dataset:

> **Single-shot, run 5, insight #4 — "Fat Intake Trends":** "On April 24 and 25, your fat intake was notably high at 107g, with a corresponding increase in saturated fat. This may not align with optimal health guidelines and could impact your overall cardiovascular health. Consider moderating your fat intake, particularly saturated fats, and focus on healthier fat sources."

> **Multi-agent, run 1, insight #3 — "Tension Between Nutrition and Recovery":** "On April 25, there was a significant drop in carbohydrate intake to 115g and fiber to just 9g, alongside a high sodium intake of 2761mg. Despite maintaining a high training readiness score, the low carbohydrate and fiber levels could negatively impact recovery and overall energy levels, indicating a disconnect between nutritional intake and recovery needs."

Both insights are grounded — both cite real values from real days. But the single-shot example stays inside the nutrition domain (saturated fat, cardiovascular health). The multi-agent example explicitly names the cross-domain disagreement: high training readiness *despite* poor nutritional support, and articulates the implication. This pattern recurs across the runs and is what drives the cross-domain integration rate gap (76% vs 100%) in Table 1.

**Variance.** Single-shot variance across runs was substantially higher: cross-domain rate ranged from 40% to 100% across the five runs (standard deviation ≈ 22 percentage points). Multi-agent variance was zero on cross-domain (all five runs at 100%). This consistency comes at the cost of redundancy — multi-agent occasionally produced two insights that cover the same underlying tension framed slightly differently, whereas single-shot more often spread its five insights across distinct themes.

**Specialist redundancy in scratch outputs.** The three specialist outputs (Nutrition, Training, Recovery) before orchestration are independent and high-quality but are not user-facing in the current architecture — only the orchestrator output is shown. Inspection of specialist outputs confirms they accurately summarize their domain slice, but their contribution to the final orchestrator output is partly absorbed and partly discarded. A future version might surface specialist summaries in a "drill-down" UI rather than discarding them.

### 4.3 Cost and Latency

Multi-agent made 4 LLM calls per generation versus 1 for single-shot. Total token usage was **2.66× higher** (3603 vs 1352 tokens) rather than 4× higher because the three specialist agents received scoped data subsets (one domain each) rather than the full week's corpus, partially offsetting the call overhead. Wall-clock latency was **1.42× higher** (13.90s vs 9.80s) — substantially less than the 4× call multiplier because Stage 1 specialist calls run in parallel and only Stage 2 (orchestrator) is sequentially dependent.

The cost-quality tradeoff is therefore **+166% tokens and +42% latency in exchange for eliminating cross-domain variance and adding consistent tension-framing**. For low-stakes daily insights this overhead may not be justified. For weekly or monthly summaries where reliability matters more than cost, the multi-agent architecture is defensible.

---

## 5. Conclusion

We presented Health Insight Agent, an iOS application implementing both single-shot and multi-agent LLM architectures for interpreting personal longitudinal health data. Our preliminary results suggest that, on this dataset and prompt design, multi-agent decomposition does *not* improve grounding (both architectures hit 100%) but *does* improve cross-domain integration consistency — multi-agent eliminated the run-to-run variance observed in single-shot and reliably produced tension-framed insights across nutrition, training, and recovery. This consistency comes at a cost of 2.66× tokens and 1.42× latency. The headline finding is therefore not that multi-agent produces better individual insights, but that it produces *more reliable* insights for cross-domain personal health analysis.

### 5.1 Limitations

This study has several limitations that constrain the strength of the claims:

- **N=1 dataset.** All evaluation data comes from a single individual over 7 consecutive days. Generalization to other users or longer time windows is untested.
- **Single annotator.** Grounding and hallucination scoring was performed by the author. Inter-annotator agreement was not assessed.
- **No clinical ground truth.** The notion of a "correct" health insight on personal data is itself contested. We measure grounding (traceability) rather than correctness (clinical accuracy), which is a weaker but more tractable target.
- **Single LLM.** All experiments used GPT-4o-mini. Whether observed differences hold under larger or differently-trained models is unknown.
- **Static agent decomposition.** Our specialist agents are hardcoded by domain. A more sophisticated approach might dynamically route data based on the question asked.

### 5.2 Future Directions

Several extensions are natural follow-ups:

1. **Larger longitudinal windows and multi-user evaluation.** Extending to public personal-health datasets such as LifeSnaps would allow testing on dozens of users over months of data.
2. **Clinical validation.** Pairing the LLM-generated insights with clinician annotation would provide a ground-truth comparison for *correctness*, not just grounding.
3. **Adaptive agent routing.** Rather than fixing three specialist domains, an outer agent could decide which subset of specialists to invoke based on what the user is asking about.
4. **On-device inference.** GPT-4o-mini calls require network connectivity. Smaller open-weight models running on-device (e.g., via Apple's Foundation Models framework) would enable privacy-preserving deployment.
5. **Longitudinal memory.** The current architecture is stateless across runs. Persistent memory of prior insights would enable agents to track whether their own past recommendations were followed.

---

## References

[1] Cui et al., "ChatGPT for Healthcare: Capabilities, Limitations, and Considerations," *Journal of Medical Internet Research*, 2023.

[2] Hong et al., "MetaGPT: Meta Programming for a Multi-Agent Collaborative Framework," *International Conference on Learning Representations (ICLR)*, 2024.

[3] Lee, Su-In et al., "Explainable AI for Trustworthy Healthcare," Computational Biology Lab Publications, University of Washington, 2023.

[4] Goyal et al., "LifeSnaps: A 4-month Multi-modal Dataset Capturing Unobtrusive Snapshots of Our Lives in the Wild," *Scientific Data*, Nature Publishing Group, 2022.

---

*Code, mock dataset, and reproducible build instructions available at [repository URL].*
