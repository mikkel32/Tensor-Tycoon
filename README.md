# Tensor Tycoon

A macOS (SwiftUI, macOS 26+) business simulator: found an AI lab, buy GPUs or rent TPUs, train models,
win benchmarks, sell tokens, subscriptions and agent seats, raise money and race eight rival labs, all the
way to recursive self-improvement — then run million-agent swarms, discover alien architectures and decide
whether to keep them, sell the chips or license the blueprint.

## Download

Get the latest **Tensor-Tycoon-x.y.zip** from the [Releases page](https://github.com/mikkel32/Tensor-Tycoon/releases/latest),
unzip it and drag **Tensor Tycoon** into Applications. Requires macOS 26 or later; runs on Apple silicon and Intel.
After that, the app keeps itself up to date (see below).

The app is ad-hoc signed, not notarized, so macOS blocks the first launch. Open it once, then go to
**System Settings → Privacy & Security** and click **Open Anyway**. Or run:

```bash
xattr -dr com.apple.quarantine "/Applications/Tensor Tycoon.app"
```

## Updates

From 3.1 on, Tensor Tycoon updates itself from this repository's Releases. It checks at launch and every six hours,
or right away with **Tensor Tycoon → Check for Updates…**. New versions download in the background and are verified
before anything is installed:

- the file size and the SHA-256 checksum GitHub publishes for the download,
- an Ed25519 signature from the Tensor Tycoon release key, bound to the version number so an older build can't be
  passed off as a newer one,
- the app inside: same bundle identifier, the advertised version, your macOS version and your Mac's processor, and
  an intact code signature.

**Install & Relaunch** saves your game, backs up every save to `Saves/Backups`, swaps the new app into place and
reopens your company where you left off, then shows what's new. If you choose **Later**, a downloaded update installs
when you quit. You can skip a version or turn off automatic checks and downloads in the update window.

## Releasing a new version

```bash
Scripts/release.sh 3.2 notes.md     # or leave out notes.md to generate notes from commits
```

The script builds a universal app, signs the zip with the key stored in your login Keychain as
"Tensor Tycoon update signing key", checks the signature against the key the app trusts
(`UpdateConfig.publicKeys` in `Sources/TensorTycoon/App/Updater.swift`), then tags, pushes and creates the GitHub
release. Every installed copy offers it within six hours. Keep a backup of the signing key (for example in a password
manager): without it, new releases can't be signed for existing installs.

## Build from source

```bash
./build_app.sh                      # builds build/Tensor Tycoon.app (release, ad-hoc signed)
UNIVERSAL=1 ./build_app.sh          # same, for both Apple silicon and Intel
open "build/Tensor Tycoon.app"
```

Or open `Package.swift` in Xcode and press Run. `swift run TensorTycoon --simulate 2022` prints a
headless balance report: benchmark calibration, a scripted playthrough, the benchmark lifecycle, an RSI
test and a custom-silicon test (including a year of selling the chip). `swift run TensorTycoon --ventures 2026` checks
agent swarms, alien architectures, chip sales, licensing, compute leasing and the money systems from a frontier lab
in that year. `swift run TensorTycoon --strategy 2022` prints what each doctrine and founder background changes, three
years of board goals, and rival acquisitions. `swift run TensorTycoon --forecast-check` replays real training runs (GPT-3,
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
- **Traits**: found your lab on one of nine doctrines (Scaling Maximalists, Safety First, Open Science, Product
  Studio, Efficiency Hackers, Silicon Natives, Agent Pioneers, Superintelligence Moonshot or Generalists) and pick a
  founder background (star researcher, ex-hardware executive, serial founder, big-tech veteran, policy insider, dropout
  hacker). Each has real upsides and costs. Culture points — from achievements, board goals and anniversaries — buy
  perks in a 24-perk culture tree across research, compute, product, finance, safety and agents.
- **The board**: three rotating goals at a time (revenue, frontier models, leaderboard rank, users, valuation,
  profitability, compute, safety, research, agents, compute sales) pay milestone tranches, culture points and board
  confidence. Confidence moves round pricing; let it collapse while investors control the board and they may replace
  you as CEO.
- **Acquisitions**: buy a rival lab with cash and stock at a control premium. Survive the antitrust review and you
  inherit its secret techniques, top researchers, a datacenter of chips, its users and its flagship model. Rivals may
  also come to you asking to be bought.
- **Strategic events**: exclusive-supply offers for your chips, regulators auditing your swarms, star researchers who
  want to found their own lab, sovereign AI contracts and talent raids.
- **Weight security & policy**: protect your weights with RAND's security levels SL1–SL5. Each level stops a more
  capable attacker (opportunistic hackers, cybercrime groups and insiders, state-backed units, top-priority nation-state
  operations) and costs more to build, run and work behind. Attackers come for your weights in proportion to how close
  you are to the frontier: leaks put free copies on the internet, state theft hands a rival your model. Better
  containment also makes escaping models and swarms less likely to get out. Lobbying builds political capital; AI
  bills (frontier transparency, federal preemption, chip security, training copyright, datacenter permitting, compute
  licensing, liability, a national research resource, agent registries) arrive as decisions, you pick a side, and the
  laws that pass change the game.
- **Talent traits**: star hires arrive with a trait (Visionary, Kernel Wizard, Firefighter, Data Curator, Rainmaker, Red
  Teamer, Tape-out Veteran, Mentor, Loyal, Workhorse or a Brilliant Diva who upsets the team); after a year, promote a
  skilled veteran into the trait you choose.
- **Victory paths**: five ways to win — Aligned Superintelligence, Trillion-Dollar Empire, Market Dominance, Guardian
  of the Transition and Alien Tech Mastery. Reach one to retire as a legend or keep playing; every game ends with a
  legacy score. From 2028 rival labs can find alien architectures of their own, so the race is real.
- **Launch styles**: release a model with a blog post, a keynote (more brand and hype, costs money), a benchmark blitz
  (great if you're #1, embarrassing if you're not top 3) or a staged rollout to trusted testers (safer, quieter).
- **Chief of Staff**: a prioritised to-do list on the dashboard — runway, idle chips, stale prices, over-capacity
  models, drifting swarms, expiring offers, board deadlines.
- **Agent swarms**: spin up 10 to 50 million copies of one of your models on your own inference chips and give them a
  mission — automated research, alien-architecture search, training operations (higher MFU, fewer loss spikes, faster
  recovery from failures, more silent bugs caught), chip design (faster tape-outs, better silicon), alignment research
  (safety score, slower drift everywhere) or a digital workforce rented to companies per worker-day. Each agent burns
  tens of millions of tokens a day, so chips set the size of the swarm; output is pooled per mission and grows
  sub-linearly with agents. Agent quality follows the model's agentic skill: about a tenth of a human researcher for an
  early-2026 frontier agent, several by 2030. Big, autonomous, under-watched swarms drift out of alignment: collusion,
  sandbagging, data mishaps with clients, and escapes onto public clouds.
- **Alien architectures**: enough insight from swarms (or a self-improvement run on Architecture search) yields a
  design no human would find — a model architecture worth roughly ×2–×5 training compute and a chip with several times
  the throughput of the best GPU at a few percent of its production cost, which humans only partly understand (models
  built on it lose safety). Tape out the chip, then choose: **keep it exclusive** (build it for yourself at cost; investors
  price in the moat), **sell the chips** (huge margins, but every chip a rival lab buys — directly or through a cloud —
  makes its models stronger, and running thousands of them teaches them the architecture) or **license the blueprint**
  (billions upfront plus royalties from hyperscalers, sovereign funds and rival labs, who integrate it within six months).
- **Selling compute**: lease idle owned accelerators to the market like a neocloud (market rental rates, occupancy that
  falls as you flood the market, a platform fee), or run merchant chip lines for your custom and alien silicon: set the
  price against the best NVIDIA/AMD part, reserve foundry capacity, build a vendor reputation (the CUDA moat works against
  newcomers), and choose whether rival labs may buy.
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
  Published techniques cost half. Newer items cover the agent era: multi-agent orchestration, long-horizon agent RL,
  automated experiment pipelines, agent sandboxes, swarm governance, circuit tracing, confidential computing for weights,
  and — once you hold an alien architecture — xeno-interpretability and xeno-compilers.
- **Unique breakthroughs**: 24 rare techniques (diffusion LMs, latent reasoning, recurrent depth, test-time training,
  ternary networks…) are dealt out at the start of each game: a few for you and two for every rival lab, each with real
  trade-offs and wider outcome swings. Rivals' secret tech shows up in their models once deployed; headhunt their
  researchers to learn it. A publication policy decides whether your own breakthroughs leak to everyone.
- **Finance**: equity rounds, strategic investors with cloud credits, IPO and a live stock, bank/GPU-backed/venture
  loans priced off the real Fed funds rate, credit score, taxes, bankruptcy and acquisition offers. Idle cash earns
  T-bill interest, API prices can track the market automatically, hardware revenue is valued at hardware multiples,
  one-off license fees don't inflate the run-rate, and founders can sell part of their stake (secondaries or into the
  public market) to build a personal net worth.
- **World**: four start eras (2017, 2020, 2022, 2026), real dated industry events, eight fictional rival labs, each
  with a signature strength.

## Credits

Photos are freely licensed images from Wikimedia Commons (authors and licenses on the in-app
"Credits & Sources" page and in `Sources/TensorTycoon/Data/ImageCredits.swift`). Chips without a free photo use a
clearly labelled representative one. Rival labs, CEOs, clients and investors are fictional; hardware, benchmarks
and macro data are real.
