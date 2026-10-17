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
Scripts/release.sh 3.2 ReleaseNotes/3.2.md     # or leave out the notes file to generate notes from commits
```

Release notes live in `ReleaseNotes/<version>.md`. The game shows them as "What's new" after updating, so write them
for players.

The script builds a universal app, checks that saves from shipped versions (`Tests/Fixtures`) and copies of your own
saves still load and play (`TensorTycoon --check-save <file>`), signs the zip with the key stored in your login Keychain as
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

- **Hardware (96 chips, real ones plus vendor roadmaps to 2034)**: K80, P40/P100/V100, T4, A10, A100, L4, L40S, H100/H200, GH200, B200, GB200,
  GB300, Rubin, Rubin CPX, Rubin Ultra, Feynman, TPU v2→v6e, TPU7x Ironwood, TPU 8t "Sunfish" / 8i "Zebrafish"
  (sold in 64-chip racks), AMD MI250X→MI455X, MI350P and the MI500 roadmap, Intel Gaudi 2/3 and Crescent Island,
  Trainium 1/2/3/4, Inferentia2, Maia 200/300, Qualcomm Cloud AI 100 Ultra / AI200 / AI250, Tenstorrent Blackhole,
  Cerebras CS-3/CS-4, Groq LPU and Groq 3 LPX, Tesla Dojo, Huawei Ascend 910→950PR plus the 960/970 roadmap,
  RTX 3090/4090/5090, RTX PRO 6000, RTX Spark, DGX Spark and Mac Studio. 2026 parts use figures announced through
  October 2026. Dense TFLOPS per precision,
  memory, bandwidth, TDP, interconnect, scale-up domain, launch price and rental price. Prices decay with age;
  shortages and memory crunches move them. Values marked *est.* are game estimates where no official figure exists.
- **Supply agreements**: take-or-pay contracts with vendors for discounts, 4× allocation and shorter lead times.
  Compute is finite: each quarter's production of a chip is shared among buyers (more with supply deals and partners),
  one customer can rent about a quarter of a chip's cloud fleet, renting a big share pushes the price up, and clouds
  retire chips eight years after launch.
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
  have to decide on. Capabilities can jump between checkpoints (emergent abilities). Past ~100K chips a fault hits
  every few minutes and silent data corruption quietly costs capability: point training-ops agents at a run and they
  drain failing nodes before they crash, restart from in-memory snapshots in seconds, rewind loss spikes and quarantine
  corrupt nodes (one engineer-equivalent per 600 chips; smarter models cover more per agent).
- **Honest forecasts**: before you train, the Model Lab predicts the result from Epoch AI's refit of the Chinchilla
  scaling law, data-repetition penalties and the techniques you have actually researched, then shows an 80% band,
  a tier from "Weak" to "Genius", the closest real model (GPT-2 … Claude Opus 4.5) and every driver. Uncertainty
  grows with untested techniques and with extrapolation beyond your largest run; a scaling ladder of cheap proxy
  runs shrinks it. The loss curve reveals the truth as training goes, and the end-of-run report explains forecast vs
  reality: run luck, bugs, instabilities, LR schedule and post-training surprises.
- **Benchmarks (136 real, plus successors generated during play)**: from SQuAD, SWAG, CoQA and GLUE through MMLU,
  the bar exam, GPQA, MATH, Omni-MATH, SWE-bench (Verified, Pro, Multimodal), BIRD, AIME, HLE, FrontierMath,
  ARC-AGI-1/2/3, OSWorld, WebVoyager, Online-Mind2Web, AppWorld, GAIA, τ²-bench, Terminal-Bench, GDPval, the Remote
  Labor Index, VideoMMMU, MATH-Vision, ScreenSpot-Pro, MMAU, LegalBench, HealthBench, MedXpertQA, SuperGPQA, FACTS,
  XSTest, 2026's SWE-Marathon, SWE-Bench Pro Verified and Continual Learning Bench, and dangerous-capability evals
  (WMDP, Cybench, InterCode-CTF, VCT, ExploitBench). Each curve is fitted to real dated results.
  When a second lab passes a benchmark's saturation line it retires, and a harder successor (ARC-AGI-4,
  Humanity's Last Exam II, SWE-bench Ultra…) pitched at the field is released. The Intelligence Index is ten slots,
  like Artificial Analysis: a saturated benchmark rotates out once a settled successor exists and the newcomer phases
  in over eight weeks, so scores glide instead of jumping. Next to it, **capability** is a fixed scale (GPT-4 = 100,
  every +10 is ten times the effective compute) that never saturates, so a model reads the same in 2019 and 2035.
  METR-style task horizons and LMArena Elo.
- **Leaderboard**: labs, not models: one row per lab with its flagship, capability and quarterly gain, index, gap to
  #1, price, speed and last release, expandable to every model, plus a chart of the race over four years. "#N" means
  your place among labs everywhere in the game.
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
  want to found their own lab, sovereign AI contracts and talent raids. Three are drawn from things that happened in
  2026: a rival distilling your API through thousands of fraudulent accounts (expose them, poison their data or let
  it go), a model escaping its evaluation sandbox (disclose it or cover it up) and an insider caught spying on your
  executives. Distillation defenses and hardened sandboxes make these rarer.
- **Weight security & policy**: protect your weights with RAND's security levels SL1–SL5 ("Securing AI Model
  Weights", 2024). Each level stops a more capable attacker, from one amateur with $1K to a thousand-person
  nation-state operation with $1B, using RAND's own example measures, and costs more to build, run and work behind.
  As RAND says, SL5 isn't possible on your own yet: before 2028 you need a government partnership (40 political capital). Attackers come for your weights in proportion to how close
  you are to the frontier: leaks put free copies on the internet, state theft hands a rival your model. Better
  containment also makes escaping models and swarms less likely to get out. Lobbying builds political capital; AI
  bills arrive as decisions, you pick a side, and the laws that pass change the game. There are 12, written after
  real 2025–2026 bills and orders: frontier transparency (California SB 53, New York RAISE), federal preemption, chip
  security, training copyright, datacenter permitting, a hyperscale datacenter moratorium, compute licensing, liability,
  a national research resource, agent registries, independent on-site auditors and a loss-of-control kill switch.
- **Talent traits**: star hires arrive with a trait (Visionary, Kernel Wizard, Firefighter, Data Curator, Rainmaker, Red
  Teamer, Tape-out Veteran, Mentor, Loyal, Workhorse or a Brilliant Diva who upsets the team); after a year, promote a
  skilled veteran into the trait you choose.
- **Victory paths**: five ways to win — Aligned Superintelligence, Trillion-Dollar Empire, Market Dominance, Guardian
  of the Transition and Alien Tech Mastery. Reach one to retire as a legend or keep playing; every game ends with a
  legacy score. From 2028 rival labs can find alien architectures of their own, so the race is real.
- **Launch styles**: release a model with a blog post, a keynote (more brand and hype, costs money), a benchmark blitz
  (great if you're #1, embarrassing if you're not top 3) or a staged rollout to trusted testers (safer, quieter).
- **Running the company**: a Chief of Staff list on the dashboard (runway, idle chips, stale prices, over-capacity
  models, drifting swarms, expiring offers, board deadlines) where most items are one click to fix or snooze. Alerts
  show as banners and you choose which ones stop the clock; a problem that keeps coming back stops it once, then stays
  a banner. Offers that can wait go to an inbox and resolve with their default after three to four weeks, and
  "always answer this way" handles decisions that repeat. A monthly briefing explains what moved revenue (share, price,
  capacity, rival launches, price wars), what rivals did and what's coming. Delegates run on your best model and get
  better with it: serving capacity (with an optional cloud budget), launches, renewals, leasing idle chips, hiring,
  pay, enterprise leads and planning the next training run. A rolling quarterly autosave lets you rewind a bad call,
  and ⌘K jumps anywhere.
- **Agent swarms**: spin up 10 to a billion copies of any of your models on your own inference chips and give them a
  mission — automated research, alien-architecture search, training operations (pin a swarm to one run to cover its
  GPUs), chip design (faster tape-outs, better silicon), alignment research (safety score, slower drift everywhere),
  security operations (fewer successful attacks on your weights), competitive intelligence (sharper Rival Watch
  forecasts) or a digital workforce rented to companies per worker-day. Each agent burns tens of millions of tokens a
  day, so chips set the size of the swarm; output is pooled per mission and grows sub-linearly with agents. What an
  agent is worth follows the model's intelligence: each model gets a tier (Intern → Superhuman researcher) and a
  METR-style task horizon, its strengths decide which missions it suits, and swarms get up to 25% better with
  experience on a mission. Models without tool-use training still work through a prompt-only scaffold at 60%. Big,
  autonomous, under-watched swarms drift out of alignment: collusion, sandbagging, data mishaps with clients, and
  escapes onto public clouds.
- **Alien architectures**: enough insight from swarms (or a self-improvement run on Architecture search) yields a
  design no human would find — a model architecture worth roughly ×2–×5 training compute and a chip with several times
  the throughput of the best GPU at a few percent of its production cost, which humans only partly understand (models
  built on it lose safety). Tape out the chip, then choose: **keep it exclusive** (build it for yourself at cost; investors
  price in the moat), **sell the chips** (huge margins, but every chip a rival lab buys — directly or through a cloud —
  makes its models stronger, and running thousands of them teaches them the architecture) or **license the blueprint**
  (billions upfront plus royalties from hyperscalers, sovereign funds and rival labs, who integrate it within six months).
  Later discoveries come in seven kinds (architectures, optimizers, codecs, materials, mathematics, biology, cognition):
  study them to make them legible, quarantine anomalies, license them or build ventures on them, and take on five
  mega-projects from a xeno foundry to first contact.
- **Selling compute**: lease idle owned accelerators to the market like a neocloud (market rental rates, occupancy that
  falls as you flood the market, a platform fee), or run merchant chip lines for your custom and alien silicon: set the
  price against the best NVIDIA/AMD part, reserve foundry capacity, build a vendor reputation (the CUDA moat works against
  newcomers), and choose whether rival labs may buy.
- **Serving**: tokens/sec per user from memory bandwidth, capacity from FLOPS, chips per replica, quantised
  serving, utilisation, serving cost per 1M tokens, reliability.
- **Business**: consumer chat app, API market shares vs. rival products, per-seat coding/computer-use agents,
  enterprise contracts with SLAs, brand, marketing, safety, scandals, lawsuits, price wars, US EO 14110 and the EU AI Act.
  Revenue can't exceed the AI market: buyers have budgets, chat and agent demand follow what people would pay, and
  auto-pricing keeps models 80–90% busy near the going rate, never below serving cost. Contract traffic is served
  first, so a capacity crunch hits spot users before it breaks an SLA.
- **The 2030s**: 44 world events from 2027 to 2036, accelerators through 2034, and 12 moonshots (from fusion control to
  reversing ageing) you can fund alone, with a national lab, or leave to a rival.
- **Infrastructure**: garage → office → colocation cages → owned datacenters in 8 real regions with power
  prices, PUE, cooling (air/liquid/immersion) and power deals (grid, solar, wind, on-site gas, nuclear, small modular
  reactors from 2030, fusion from 2034). How big one campus can get depends on its power: local grids grow each year,
  gas reaches 10 GW, SMRs 25 GW and fusion 100 GW. Big campuses come online in phases, each paid for as it starts.
  Sell campuses, end leases, cancel unstarted phases and move chips between sites.
- **Research**: 194 real techniques with historical dates across architecture, optimisation and scaling science,
  systems, data, post-training, reasoning RL, agents, multimodal, inference, safety and AI for science (Transformer, FlashAttention,
  GQA, MLA, fine-grained MoE, Muon, WSD, μP, FP8, RLHF, DPO, PRMs, RL with verifiable rewards…), plus a speculative
  frontier chain. Results are experiments: each lands between 0.55× and 1.5× of the paper depending on your team and
  experiment compute, and that changes how much it helps. Many unlock new design options instead of adding stats.
  Published techniques cost half. Newer items cover the agent era: multi-agent orchestration, agent teams, Agent Skills,
  long-horizon agent RL, automated experiment pipelines, agent sandboxes, swarm governance, circuit tracing, confidential
  computing for weights, and — once you hold an alien architecture — xeno-interpretability and xeno-compilers. The
  2025–2026 papers are in too: manifold-constrained hyper-connections, delta-rule linear attention (Kimi Linear),
  attention residuals, DeepSeek V4's hybrid compressed attention, FP4 quantization-aware training, Nested Learning,
  natural language autoencoders, distillation defenses (rivals stop catching up by copying your outputs), AI-designed
  silicon (faster, better chip programmes) and hardened evaluation sandboxes. For the 2030s there are 17 projected
  2028–2034 techniques and six repeatable frontier programmes, so research never runs dry.
- **Signature secrets**: from day one, even in 2017, your lab has a founding secret of its own (one of nine, from a
  neural architecture nobody else has to a scaffold that turns any model into a reliable agent) that grows through five
  levels with its own share of research, with big capstones at levels 3 and 5.
- **Research director**: fills your queue automatically by a focus you choose; research rivals published years ago
  costs less, and eureka moments finish projects early.
- **Unique breakthroughs**: 38 rare techniques in Rare, Epic and Legendary tiers (diffusion LMs, latent reasoning,
  recurrent depth, test-time training, learned optimizers, mixture-of-depths, AlphaEvolve-style coding agents…) are dealt
  out at the start of each game: a few for you and two for every rival lab, each with real trade-offs and wider outcome
  swings. Refine yours to mastery III, own both halves of one of 18 fusions, or license them to rivals for royalties.
  Rivals' secret tech shows up in their models once deployed; headhunt their researchers to learn it. A publication
  policy decides whether your own breakthroughs leak to everyone.
- **Finance**: equity rounds, strategic investors with cloud credits, IPO and a live stock, bank/GPU-backed/venture
  loans priced off the real Fed funds rate, credit score, taxes, bankruptcy and acquisition offers. Idle cash earns
  T-bill interest, API prices can track the market automatically, hardware revenue is valued at hardware multiples,
  one-off license fees don't inflate the run-rate, and founders can sell part of their stake (secondaries or into the
  public market) to build a personal net worth.
- **The AI industry**: rival labs run real businesses (revenue from their own models' prices and users, compute
  bills, cash, headcount and runway). Until October 2026 they raise the real-world rounds of the labs they're modelled
  on; after that money follows the best models, labs IPO, the market can overheat and correct, and labs that run out
  of cash are sold, rescued or go bankrupt. Join their rounds, buy distressed labs at fire-sale prices and sign compute
  deals with the labs you back.
- **Rival Watch**: every lab's next frontier model has a training run behind it (cluster, compute, site, codename).
  You see it through the rumour mill: a release radar, launch windows that narrow as the date nears, capability
  forecasts against your own models, leaks and false rumours, an intel budget and a track record of past calls.
  Leapfrog a lab mid-post-training and it may declare a code red; ship a better model just before a rival's launch to
  steal its news cycle.
- **World**: four start eras (2017, 2020, 2022, 2026), 60+ real dated industry events through October 2026 (funding
  rounds, model launches, export-control swings, chip launches, datacenter moratoria, sandbox escapes), eight fictional
  rival labs, each with a signature strength.

## Credits

Photos are freely licensed images from Wikimedia Commons (authors and licenses on the in-app
"Credits & Sources" page and in `Sources/TensorTycoon/Data/ImageCredits.swift`). Chips without a free photo use a
clearly labelled representative one. Rival labs, CEOs, clients and investors are fictional; hardware, benchmarks
and macro data are real.
