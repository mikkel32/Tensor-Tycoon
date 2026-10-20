# Tensor Tycoon expansion: implementation checklist

Tracks the "ultimate expansion" goal part by part. A part is marked **Done** only when its work is merged, the engine
checks below pass on the merged tree, and macOS CI compiles it. "Seen on a Mac" is tracked separately: nothing here has
been run in the app yet (this environment has no Mac), so every UI item still needs a look before it's called finished.

**Evidence** names the check that exercises the part. Engine checks run on Linux (`Scripts/linux_build.sh`, then
`.build/linux/tt <flag>`) and in macOS CI:

| Check | What it covers |
|---|---|
| `--scenarios all` | The eight playthroughs A–H of goal part 26 (each a list of named checks) |
| `--determinism` | Same seed, same game: three eras plus games with every bot system on; save, load and play on |
| `--check-save <file>` | The 3.1, 3.2 and 3.3 fixture saves load, migrate and play 90 days |
| `--forecast-check` | Real training runs through the forecast engine (must match the committed baseline) |
| `--finance-check` | 85 checks: books, valuation, debt, payouts, tax, crises, stages |
| `--data-check` | Data economy and science rules, scripted (frozen plans, synthetic bounds, licences, unlocks, the 2D node) |
| `--intelligence` | Domains, families, launches, markets, rivals (41 checks) |
| `--photo-check` | Every photo credited; stand-in photos labelled |
| `--calendar-check` | The integer calendar matches Foundation's from 1990 to 2100 |
| `Scripts/linux/uistubs/typecheck.sh` | Every view type-checks against SwiftUI stubs (macOS CI compiles them for real) |

| Part | Area | Status | Evidence | Seen on a Mac |
|---|---|---|---|---|
| 2 | Training: Model Lab, review, launch sequence, command centre, interventions, milestones, results | Done: MoE expert pools, memory plans, hot spares, QAT and evaluation stages; telemetry-driven cluster map; diagnose / investigate / red-team / end early / extend; frozen data plans; landmark firsts; commissioned evaluations | Scenario E (42 checks), `--data-check` | No |
| 3 | Deeper intelligence, model families, distillation | Done: 16 domains, know-how snapshots, specialists as family members, one distillation rule for the Lab and families, reasoning effort | `--intelligence`, Scenario H | No |
| 4 | Progression stages with new powers | Done: stages gate term loans, subsidiaries, classified work, chip teams, fabs, institutes, large organisations, late moonshots | `--finance-check`, Scenarios F, G | No |
| 5 | Romania, Italy, France, Denmark: real effects, premium selection | Done: real R&D relief schemes, loss carry-forward, satellite offices instead of a talent cap, build incentives, scoped US law, European power contracts, national partnerships and contracts, recessions; estimates badged as such on screen | Scenarios A–D (pass on 17 seed offsets) | No |
| 6 | Advanced Projects: government and classified research | Done: seconded staff, mobilisation planner, facility power and siting, agency budgets, rival programmes, trust, clearance upkeep | Scenario F (53 checks), determinism row | No |
| 7 | Data economy | Done: bounded synthetic data, fresh RLHF labels, licence terms, renewals, runs frozen at launch | `--data-check` | No |
| 8 | Science labs and experiments | Done: unlocks (fusion, quantum chemistry, lossless power, 2D node), publishing spreads to rivals, royalties, company timeline | `--data-check`, Scenarios D, H | No |
| 9 | Semiconductors | Done: silicon-derived specs, layouts and interconnects, compiler maturity, honest sales, deposits, ports, a 2D-channel node from science | Scenario G (77 checks), `--data-check` | No |
| 10 | Autonomous agent organisations | Done: pooling, supervisors, scaling exponent, compounding errors, activity tiers, objectives | Scenario G, Scenario H | No |
| 11 | Intelligent rivals | Done: specialisations change their models, pivots, two new kinds, coherent rival books | `--intelligence` | No |
| 12 | National economies and AI strategies | Done: regional recessions, national partnerships, power contracts, scoped law | Scenarios A–D | No |
| 13 | Subsidiaries | Done: three new kinds with effects on the parent; stage-based slots | `--finance-check`, Scenario H | No |
| 14 | UI quality | Partly: design system, VoiceOver for training sliders and charts, reduced animations; needs a full visual pass on a Mac | Type-check only | No |
| 15–17 | Images and licensing | Done: licences verified, stand-ins labelled, 23 new photos, credits screen and CREDITS.txt; gaps where no free photo exists are listed in the credits work | `--photo-check`, `Scripts/check_images.sh` | No |
| 18 | Discovery reports | Done (including unique AI breakthroughs) | `--data-check` | No |
| 19 | Launch strategies and reactions | Done: 10 strategies, pricing stances hold, reactions scale with rank and loudness | `--intelligence`, Scenario E | No |
| 20 | Corporate finance | Done: reconciled books, depreciation, valuation with cash and debt, loss carry-forward, booking ramp, crises | `--finance-check`, every scenario's "books reconcile" | No |
| 21 | Architecture | Engine systems stay in their own files and hook into each other through small named functions | Code review | n/a |
| 22 | Performance | A seven-year game with every system on simulates in about 25 s with the bot on this Linux build (≈3.5 s per year, Scenario H checks < 15 s) | Scenario H | n/a |
| 23 | Save compatibility | All new fields default safely; fixtures from 3.1, 3.2 and 3.3 load and play | `--check-save` | n/a |
| 24–25 | Testing | The checks above run on every CI build | CI | n/a |
| 26 | Scenarios A–H | All eight implemented and passing (A 20, B 16, C 15, D 15, E 42, F 53, G 77, H 25 checks) | `--scenarios all` | n/a |
| 25 | Visual acceptance in the running app | Blocked: no macOS machine in this environment; needs the owner | — | — |

## Known balance notes (from the seven-year playtest sweep)
- Every era, headquarters and system mix played seven years without a game over or an anomaly, and every month's
  books reconciled to the cent. Scenario H's numbers are identical on Linux and macOS (cross-platform determinism).
- Starting in 2017 is easy: the bot holds #1 for about 70 of 84 months (unchanged from 3.3). Historical rivals ship
  few models in those years; closing the gap would mean rewriting history or retuning early training.
- A chip business with a large own fleet can turn idle chips into heavy research compute (diminishing returns apply).
  It's a legitimate lever, flagged for review.
- Licensing a unique AI breakthrough can be worth billions; the bot keeps them, so this is untested in playtests.

## Known blockers
- No Mac here: views are type-checked on Linux against SwiftUI stubs and compiled by macOS CI, but never rendered.
  Every UI item needs a look on a Mac before it's called finished.
