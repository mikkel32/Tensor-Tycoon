# Tensor Tycoon expansion: implementation checklist

Tracks the "ultimate expansion" goal part by part. A box is ticked only when the work is merged, the engine
checks pass (`--forecast-check` identical, save fixtures load, playtests sane) and macOS CI compiles it.
"Seen on a Mac" is tracked separately: nothing here has been run in the app yet unless that column says so.

| Part | Area | Status | Seen on a Mac |
|---|---|---|---|
| 2 | Training: Model Lab workstation, pre-training review, launch sequence, command centre, interactive runs, milestones, results screen | Merged (Model Lab review, launch sequence, command centre, run ledger, results) | No |
| 3 | Deeper intelligence: domains (11 exist), model families, distillation, advanced techniques | Partly done (domains, milestones); families/distillation not started | No |
| 4 | Progression stages with new powers | Partly (founding kit merged: 39 cards, genius starts, RL lab, starter quests; late-game systems exist) | No |
| 5 | Countries: Romania, Italy, France, Denmark; premium selection; real effects; photos | Merged (12 cities, real economics, 13 licensed Commons photos with credits) | No |
| 6 | Advanced Projects: government contracts, classified facilities, programmes, secrecy | Merged (14 agencies, 23 programme templates, 4 contract types, clearances, secrecy choices) | No |
| 7 | Data economy: types, quality dimensions, licensing, processing, contamination | In progress (wave 2) | No |
| 8 | Science labs and experiments | In progress (wave 2; builds on XenoScience/moonshots) | No |
| 9 | Semiconductor industry (fab, yields, packaging, sales) | Alien fab line merged (pilot line, v2/v3 generations, yields, errata); full industry wave 3 | No |
| 10 | Autonomous agent organisations | In progress (wave 2; builds on swarms) | No |
| 11 | Smarter rivals | Largely done in 3.3 (strategies, lifecycle, books); specialisation response wave 2 | No |
| 12 | National economies and AI strategies | Partly (world model, regions); national strategies wave 2 | No |
| 13 | Subsidiaries | Not started (wave 3) | No |
| 14 | UI design system pass | Partly (Today dashboard, help); full pass wave 3 | No |
| 15–17 | Images: reuse + licensed new photos with credits | Countries' photos in wave 1; more in later waves | No |
| 18 | Discovery reports | In progress (wave 2, with science labs) | No |
| 19 | Launch strategies and reactions | Partly (launch styles exist); deepen in wave 2 | No |
| 20 | Corporate finance depth | Not started (wave 3) | No |
| 22 | Performance | Measured each merge (~1 s per 2033 game-year) | n/a |
| 23 | Save compatibility | Checked each merge with the 3.1 and 3.2 fixtures | n/a |
| 25 | Visual acceptance in the running app | Blocked: no macOS machine in this environment; needs the owner | — |

Also in wave 1 (owner's earlier request): founding kit and genius starts (merged), alien GPU pipeline fixes (merged: four ways it got stuck, fixed),
datacenter/GW market, buying and leasing (merged), conferences/competitions/scenarios (merged).

## Known blockers
- No Mac here: views are type-checked on Linux against SwiftUI stubs and compiled by macOS CI, but never rendered.
  Every UI item needs a look on a Mac before it's called finished.
