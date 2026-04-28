# Health Insight Agent — Speaker Notes

Companion to `slides.pptx`. Target presentation time: 6-7 minutes.

---

## Slide 1: Title

Hi, I'm Jerome. This project investigates whether decomposing LLM-based health data interpretation across multiple specialist agents produces better insights than asking one LLM to do everything in one shot.

---

## Slide 2: The Problem

Anyone who tracks their health knows this fragmentation. Three separate apps, three separate "insights" pages, none of them cross-referencing each other. LLMs can interpret data, but the dominant approach is to dump everything into one prompt — which I argue produces weak results.

---

## Slide 3: Research Question

One sentence. Multi-agent versus single-shot, on identical data, evaluated for grounding and specificity.

---

## Slide 4: Method — Architecture

Each Stage 1 specialist sees only its own domain — the nutrition agent doesn't see Garmin data, etc. The orchestrator gets all three summaries plus raw data for cross-referencing. This is the testable hypothesis: domain-specific reasoning before integration produces more grounded outputs.

---

## Slide 5: Implementation

Native iOS, not a notebook. The app exposes both modes with a segmented control toggle. Same input data, same UI, two architectures swappable in real time.

---

## Slide 6: Results

This was actually the surprise of the project. I expected multi-agent to win on grounding, but both hit 100% — the LLM is good at citing specific numbers when prompted to.

Where multi-agent actually helped was reliability on the cross-domain framing. Single-shot is unreliable — sometimes it gives you 5 isolated single-domain observations, sometimes it integrates beautifully. Multi-agent always integrates because the orchestrator prompt forces it to.

---

## Slide 7: Future Directions

Two big limitations of this work — N=1 dataset, and no clinical ground truth. The natural extensions address both. The on-device direction is interesting because it makes this kind of system actually shippable as a consumer product.

---

## Slide 8: Thank You

Happy to take questions. Thanks for watching.
