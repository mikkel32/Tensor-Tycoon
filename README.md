# Tensor Tycoon

A macOS (SwiftUI, macOS 26+) business simulator: found an AI lab, buy GPUs or rent TPUs, train models,
win benchmarks, sell tokens, subscriptions and agent seats, raise money and race eight rival labs, all the
way to recursive self-improvement.

## Download

Get **Tensor-Tycoon-3.0.zip** from the [Releases page](https://github.com/mikkel32/Tensor-Tycoon/releases/latest),
unzip it and drag **Tensor Tycoon** into Applications. Requires macOS 26 or later.

The app is ad-hoc signed, not notarized, so macOS blocks the first launch. Open it once, then go to
**System Settings → Privacy & Security** and click **Open Anyway**. Or run:

```bash
xattr -dr com.apple.quarantine "/Applications/Tensor Tycoon.app"
```

## Build from source

```bash
./build_app.sh                      # builds build/Tensor Tycoon.app (release, ad-hoc signed)
UNIVERSAL=1 ./build_app.sh          # same, for both Apple silicon and Intel
open "build/Tensor Tycoon.app"
```

Or open `Package.swift` in Xcode and press Run. `swift run TensorTycoon --simulate 2022` prints a
headless balance report: benchmark calibration, a scripted playthrough, the benchmark lifecycle, an RSI
test and a custom-silicon test. `swift run TensorTycoon --forecast-check` replays real training runs (GPT-3,
Chinchilla, LLaMA, GPT-4, Llama 3, DeepSeek-V3, Kimi K2, Grok 4…) through the forecast engine and prints the error.

Saves live in `~/Library/Application Support/TensorTycoon/Saves` (autosave every month, ⌘S to save).
Speed: ⌘⇧P play/pause, ⌘1–⌘5 speeds (1.5 to 90 days per second), ⌘→ one day.

## What's simulated

- **Hardware (60+ real chips)**: K80, P40/P100/V100, T4, A10, A100, L4, L40S, H100/H200, GH200, B200, GB200,
  GB300, Rubin, Rubin CPX, Rubin Ultra, Feynman, TPU v2→v6e, TPU7x Ironwood, TPU 8t "Sunfish" / 8i "Zebrafish"
  (sold in 64-chip racks), AMD MI250X→MI455X, Intel Gaudi 2/3 and Crescent Island, Trainium 1/2/3, Inferentia2,
  Maia 200, Qualcomm Cloud AI 100 Ultra / AI200 / AI250, Tenstorrent Blackhole, Cerebras CS-3, Groq LPU,
  Tesla Dojo, Huawei Ascend, RTX 3090/4090/5090, RTX PRO 6000, DGX Spark and Mac Studio. Dense TFLOPS per precision,
  memory, bandwidth, TDP, interconnect, scale-up domain, launch price and rental price. Prices decay with age;
  shortages and memory crunches move them. Values marked *est.* are game estimates where no official figure exists.
- **Supply agreements**: take-or-pay contracts with vendors for discounts, 4× allocation and shorter lead times.
- **Compute partners**: strategic deals with NVIDIA, Google Cloud, AWS, Microsoft Azure, AMD and Oracle, modelled on the
  real 2025 deals (NVIDIA–OpenAI, Anthropic–Google TPUs, Amazon–Anthropic/Rainier, Microsoft–NVIDIA–Anthropic, AMD–OpenAI
  warrants). Exclusive deals pay more equity investment, bigger discounts and months-early access to new chips, but lock
  you to that vendor's hardware; preferred deals pay less without the lock. Take-or-pay spending commitments and
  break-up penalties.
- **Custom silicon**: run your own TPU-style program with Broadcom, Marvell, MediaTek or an in-house team:
  architecture → RTL → tape-out → bring-up (with respin risk) → volume. The chip shows up in the store, sold at cost.
- **Training**: FLOPs = 6 × active params × tokens; MFU, scale-out losses, memory limits (ZeRO/FSDP, LoRA-style
  fine-tunes), FP8/FP4 training and live loss curves. Design choices are real ones: attention (MHA/GQA/MLA), mixer
  (Transformer, hybrid SSM, diffusion LM), MoE sparsity, multi-token prediction, AdamW/Muon/Shampoo, cosine vs WSD
  schedules, annealing, data mixture and synthetic share, and how much compute goes to RL. Hardware fails at the rate
  Meta measured on Llama 3 (419 interruptions in 54 days on 16K GPUs), and every failure costs cluster-hours.
  Post-training runs as real stages (SFT → RLHF/DPO → multimodal → tool/agentic RL → reasoning RL → safety), each
  with its own surprises: loss spikes, silent data bugs, contamination, reward hacking, sycophancy and fault storms you
  have to decide on. Capabilities can jump between checkpoints (emergent abilities).
- **Honest forecasts**: before you train, the Model Lab predicts the result from Epoch AI's refit of the Chinchilla
  scaling law, data-repetition penalties and the techniques you have actually researched, then shows an 80% band,
  a tier from "Weak" to "Genius", the closest real model (GPT-2 … Claude Opus 4.5) and every driver. Uncertainty
  grows with untested techniques and with extrapolation beyond your largest run; a scaling ladder of cheap proxy
  runs shrinks it. The loss curve reveals the truth as training goes, and the end-of-run report explains forecast vs
  reality: run luck, bugs, instabilities, LR schedule and post-training surprises.
- **Benchmarks (132 real, plus successors generated during play)**: from SQuAD, SWAG, CoQA and GLUE through MMLU,
  the bar exam, GPQA, MATH, Omni-MATH, SWE-bench (Verified, Pro, Multimodal), BIRD, AIME, HLE, FrontierMath,
  ARC-AGI-1/2/3, OSWorld, WebVoyager, Online-Mind2Web, AppWorld, GAIA, τ²-bench, Terminal-Bench, GDPval, the Remote
  Labor Index, VideoMMMU, MATH-Vision, ScreenSpot-Pro, MMAU, LegalBench, HealthBench, MedXpertQA, SuperGPQA, FACTS,
  XSTest and dangerous-capability evals (WMDP, Cybench, InterCode-CTF, VCT). Each curve is fitted to real dated results.
  When the best model passes a benchmark's saturation line it retires, and a harder successor (ARC-AGI-4,
  Humanity's Last Exam II, SWE-bench Ultra…) is released. The Intelligence Index averages 10 live benchmarks spread
  from hardest to nearly saturated, like Artificial Analysis. METR-style task horizons and LMArena Elo.
- **Frontier safety thresholds**: modelled on Anthropic's RSP, OpenAI's Preparedness Framework and Google DeepMind's
  Frontier Safety Framework. Models that cross the High (ASL-3-class) or Critical line need a high enough safety score
  to ship with safeguards; releasing without them costs brand and invites misuse incidents.
- **Recursive self-improvement**: research the frontier chain, then let a model improve itself generation by
  generation (capabilities, automated research or inference efficiency). Autonomy and oversight trade speed for
  safety; alignment drifts, reward hacking inflates evals, and incidents can end the game. Checkpoints can be
  promoted to models, rolled back or deep-audited.
- **Serving**: tokens/sec per user from memory bandwidth, capacity from FLOPS, chips per replica, quantised
  serving, utilisation, serving cost per 1M tokens, reliability.
- **Business**: consumer chat app, API market shares vs. rival products, per-seat coding/computer-use agents,
  enterprise contracts with SLAs, brand, marketing, safety, scandals, lawsuits, price wars, US EO 14110 and the EU AI Act.
- **Infrastructure**: garage → office → colocation cages → owned datacenters in 8 real regions with power
  prices, PUE, cooling (air/liquid/immersion) and power deals (solar, wind, gas, nuclear).
- **Research**: 110 real techniques with historical dates across architecture, optimisation and scaling science,
  systems, data, post-training, reasoning RL, agents, multimodal, inference and safety (Transformer, FlashAttention,
  GQA, MLA, fine-grained MoE, Muon, WSD, μP, FP8, RLHF, DPO, PRMs, RL with verifiable rewards…), plus a speculative
  frontier chain. Results are experiments: each lands between 0.55× and 1.5× of the paper depending on your team and
  experiment compute, and that changes how much it helps. Many unlock new design options instead of adding stats.
  Published techniques cost half.
- **Unique breakthroughs**: 24 rare techniques (diffusion LMs, latent reasoning, recurrent depth, test-time training,
  ternary networks…) are dealt out at the start of each game: a few for you and two for every rival lab, each with real
  trade-offs and wider outcome swings. Rivals' secret tech shows up in their models once deployed; headhunt their
  researchers to learn it. A publication policy decides whether your own breakthroughs leak to everyone.
- **Finance**: equity rounds, strategic investors with cloud credits, IPO and a live stock, bank/GPU-backed/venture
  loans priced off the real Fed funds rate, credit score, taxes, bankruptcy and acquisition offers.
- **World**: four start eras (2017, 2020, 2022, 2026), real dated industry events, eight fictional rival labs, each
  with a signature strength.

## Credits

Photos are freely licensed images from Wikimedia Commons (authors and licenses on the in-app
"Credits & Sources" page and in `Sources/TensorTycoon/Data/ImageCredits.swift`). Chips without a free photo use a
clearly labelled representative one. Rival labs, CEOs, clients and investors are fictional; hardware, benchmarks
and macro data are real.
