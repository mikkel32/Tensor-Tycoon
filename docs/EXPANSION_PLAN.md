# Tensor Tycoon expansion: implementation checklist

Tracks the "ultimate expansion" goal part by part. A box is ticked only when the work is merged, the engine
checks pass (`--forecast-check` identical, save fixtures load, playtests sane) and macOS CI compiles it.
"Seen on a Mac" is tracked separately: nothing here has been run in the app yet unless that column says so.

| Part | Area | Status | Seen on a Mac |
|---|---|---|---|
| 2 | Training: Model Lab workstation, pre-training review, launch sequence, command centre, interactive runs, milestones, results screen | Merged (Model Lab review, launch sequence, command centre, run ledger, results) | No |
| 3 | Deeper intelligence: domains (11 exist), model families, distillation, advanced techniques | Merged (domains, milestones; model families with Core/Spark/Mote tiers, distillation, 7 post-training passes, versioned releases, tier routing) | No |
| 4 | Progression stages with new powers | Merged (founding kit: 39 cards, genius starts, RL lab, starter quests; company stages Garage → Civilisational with explicit criteria and a power at each) | No |
| 5 | Countries: Romania, Italy, France, Denmark; premium selection; real effects; photos | Merged (12 cities, real economics, 13 licensed Commons photos with credits) | No |
| 6 | Advanced Projects: government contracts, classified facilities, programmes, secrecy | Merged (14 agencies, 23 programme templates, 4 contract types, clearances, secrecy choices) | No |
| 7 | Data economy: types, quality dimensions, licensing, processing, contamination | Merged (17 data types, 11 quality dimensions, market, pipeline, annotation, synthetic data, auctions, Model Lab data plan) | No |
| 8 | Science labs and experiments | Merged (8 lab kinds in 13 cities, 41 projects in 12 fields, 10 failing stages, discoveries that move real numbers, IP portfolio, rival science, 6 licensed photos) | No |
| 9 | Semiconductor industry (fab, yields, packaging, sales) | Merged (alien fab line; full industry: design teams, nodes to A10-class, 4 foundries, own fabs, packaging and HBM bottlenecks, yields and binning, supply shocks, sales incl. to rivals) | No |
| 10 | Autonomous agent organisations | Merged (14 organisation kinds, teams and supervisors, verification, scaling with overhead, real cross-system effects) | No |
| 11 | Smarter rivals | Merged (3.3 strategies, lifecycle, books; now specialisations chosen with a lag and explained, lagged answers to your launches) | No |
| 12 | National economies and AI strategies | Merged (7 regions with 7 strategy dials reviewed each January with reasons, regional economies, explained effects on your costs, hiring and demand) | No |
| 13 | Subsidiaries | Merged (7 kinds, own CEO and P&L, sell stakes, list, spin off, fold in, transfer-price audits) | No |
| 14 | UI design system pass | Partly (Today dashboard, help); full pass wave 3 | No |
| 15–17 | Images: reuse + licensed new photos with credits | Countries' photos in wave 1; more in later waves | No |
| 18 | Discovery reports | Merged (significance, commercial value, impact, competitor response, five choices) | No |
| 19 | Launch strategies and reactions | Merged (8 strategies × pricing × safety posture, explained effects, launch-day report with quotes and verdict, lagged rival answers) | No |
| 20 | Corporate finance depth | Merged (term loans with LTM covenants, convertibles, green bonds, credit rating, dividends, buybacks, tender offers, three statements, runway scenarios, tax view) | No |
| 22 | Performance | Measured each merge (a 7-year 2026 game simulates in about 15 s with bot overhead) | n/a |
| 24 | Determinism | Merged: same seed gives the same game (`--determinism` in CI; playtests are exact) | n/a |
| 23 | Save compatibility | Checked each merge with the 3.1 and 3.2 fixtures | n/a |
| 25 | Visual acceptance in the running app | Blocked: no macOS machine in this environment; needs the owner | — |

Also in wave 1 (owner's earlier request): founding kit and genius starts (merged), alien GPU pipeline fixes (merged: four ways it got stuck, fixed),
datacenter/GW market, buying and leasing (merged), conferences/competitions/scenarios (merged).

## Known blockers
- No Mac here: views are type-checked on Linux against SwiftUI stubs and compiled by macOS CI, but never rendered.
  Every UI item needs a look on a Mac before it's called finished.
