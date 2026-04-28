# Health Insight Agent

An iOS application implementing two LLM architectures (single-shot vs. multi-agent) for interpreting personal longitudinal health data spanning nutrition, training, and recovery. Built for the MSAI High-Risk Project, Spring 2026.

See `Report/report.docx` for the full writeup. See `Slides/slides.pptx` for the presentation deck.

## Structure

```
HealthAgent/        Xcode project — native iOS app (SwiftUI, iOS 17+)
eval/               Python harness for batch API runs and grounding scoring
Report/             ACM-formatted report (markdown source + docx export)
Slides/             Presentation deck + speaker notes
```

## Setup

### 1. OpenAI API key

Both the iOS app and the Python eval require an OpenAI API key. Copy `.env.example` to `.env` and fill in your key:

```bash
cp .env.example .env
# edit .env, set OPENAI_API_KEY=sk-...
```

The `.env` file is gitignored.

### 2. iOS app (HealthAgent/)

Open `HealthAgent/HealthAgent.xcodeproj` in Xcode 26+. The OpenAI key is read in this order:

1. `Info.plist` → `OPENAI_API_KEY` (if you wire it up via xcconfig)
2. Process environment variable `OPENAI_API_KEY`
3. Bundled file `openai_key.txt` in the app target (single-line plaintext, gitignored)

The simplest path: in Xcode, choose **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**, add `OPENAI_API_KEY` with your key value. Then build and run on iPhone simulator.

### 3. Python eval (eval/)

Requires `requests`. Install in a venv:

```bash
cd eval
python3 -m venv .venv
source .venv/bin/activate
pip install requests
```

Run the eval (5 single-shot + 5 multi-agent generations on the same 7-day mock dataset):

```bash
export OPENAI_API_KEY=sk-...    # or `source ../.env && export OPENAI_API_KEY`
python run_eval.py              # writes results/runs.json
python score.py                 # writes results/scored.json + prints aggregates
```

Approximate cost per full eval: 10 generations × ~2500 tokens average = ~$0.05 on gpt-4o-mini.

## Reproducing report results

The Table 1 numbers in the report come from the eval harness, not the iOS app. To reproduce:

```bash
cd eval && python run_eval.py && python score.py
```

Results are captured in `eval/results/scored.json`. The aggregates printed at the end of `score.py` populate Table 1 in the report.

## How the app works

- **Single-shot mode** sends one prompt with all 7 days of data → 1 LLM call.
- **Multi-agent mode** sends 3 parallel specialist prompts (Nutrition, Training, Recovery) → then 1 orchestrator prompt → 4 LLM calls total.
- Both modes display the resulting insights plus token count and latency.

## License

Code is provided for educational review only. Not a packaged product.
