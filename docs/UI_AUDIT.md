# UI audit and design system

Part 14 of the expansion goal: one consistent, premium UI across the ~60 views. This file records what the audit
found, the tokens and components that now exist, and what changed on each screen. It is a Views-only pass: no engine,
model, data or saved-state changes.

## 1. What the audit found

Screens were added in parallel by different authors, and `Views/Components.swift` only offered `Card`, `CardHeader`,
`Page`, `StatTile`, `Pill`, `Meter`, `SpecRow`, `EmptyStateView` and a few photo pieces. Everything else was
re-invented locally. The recurring differences:

| Area | What varied |
| --- | --- |
| Page headers | Title and subtitle only. No screen symbol, and no "?" on most screens: 19 screens had a first-visit hint, the rest had nothing once it was dismissed. Subtitles ran the full 1500pt width on wide windows. |
| KPI rows | 15 screens put 4–6 `StatTile`s in an `HStack`, which squeezed the tiles at 1100pt. 12 others used `LazyVGrid(.adaptive(190…230))`, which left empty slots on wide windows. |
| Card grids | Fixed `[.flexible, .flexible]` pairs (Advanced Projects, Agencies, Product Lines) that never wrap, next to `.adaptive(440)` grids elsewhere. |
| Compact stats | Ten private copies of the same "label over value" box: `LineStat`, `OrgStat`, `XenoStat` (identical), `RSIStat`, `LiveStat` (identical), `MiniStat`, `Metric`, `PlannerStat`, `WorldJobFigure`, `ReportStat`, with paddings of 8–10 and radii of 8–12. |
| Stage strips | Four timelines: `StageTimeline` (Advanced Projects), `StageStrip` (Science), `StageTimeline` (Training), `StageLadder` (Progression). The first two used colour alone for done / current / failed. |
| Odds | Win odds, failure odds and pass chances shown as green/orange text with no bar and no word. |
| Section tabs | Seven page-level segmented pickers with different labels (`""` vs `"Section"`) and widths (none, 360, 440, 520). |
| Type | Hero numbers at 22, 26, 30, 34, 40 and 46pt. |
| Inset panels | 29 inset backgrounds at `.quaternary` 0.3–0.5 or `.secondary` 0.06, radii 8/10/12. |
| Colour | Meaning by colour alone in: odds text, alignment dots (RSI checkpoints), alignment numbers (dashboard), the Nations "effects on you" values, Semiconductors event dots, status pills ("Paused", "In breach", "Out of cash", "Rushed", "Delayed"). Country selection and founding-kit choices used `Color.white.opacity(…)` fills and strokes, which only work on a dark background. |
| Number formatting | Three signed-money styles: `signedMoney` ("-$1M" with a hyphen), `CorpStyle.signed` and `AdvancedProjects.signed` ("−$1M" with a minus). Tables were already mostly monospaced. |
| Empty states | Six page-level `EmptyStateView`s floated on the page background while the rest sat in a `Card`; Corporate used plain grey text. |
| Dashboard | ~20 cards in two unlabelled columns: needs, money, programmes and the race interleaved, so nothing was scannable. Era steps were computed twice per redraw. |

## 2. Tokens (Views/DesignSystem.swift)

- **Spacing** `Theme.Space`: xxs 2 · xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32. Semantic: `Theme.gap` 16 (between cards),
  `Theme.sectionGap` 28, `Theme.cardPadding` 16, `Theme.pagePadding` 24, `Theme.pageMaxWidth` 1500,
  `Theme.readableWidth` 860 (long text).
- **Radii** `Theme.Radius`: chip 6 · control 8 · inset 10 · tile 14 · card 16 · hero 20 (`Theme.corner` = card).
- **Type ramp** `TypeRamp`: pageTitle, sectionTitle, cardTitle, body, caption, micro, label, display (40pt verdict),
  bannerMetric (30pt hero-banner number), heroMetric, metric (KPI tile), metricSmall, tableNumber, captionNumber. All
  number styles use monospaced digits.
- **Semantic colours**: `Theme.good / bad / warning / info / neutral / accent` (system colours, so light and dark mode
  both work), `Theme.insetFill` and `Theme.hairline` (primary-based, replacing white/black at low opacity).
- **Tone** (`good, bad, warning, info, neutral, accent`): a colour, a symbol and a word for each, plus helpers
  `Tone.sign`, `Tone.level` (higher is better) and `Tone.risk` (lower is better). Anything that carries meaning by
  colour should go through a tone.
- **Grids**: `Theme.columns(min:)`, `Theme.tileColumns`, `Theme.cardColumns`, `Theme.compactCardColumns`.
- **Formatting** (extends the existing `Fmt`): `Fmt.signedMoney` ("+$1.2M" / "−$450K" with a true minus),
  `Fmt.signedPct`, `Fmt.signed`, `Fmt.odds` ("62%"). `signedMoney(_:)` now calls `Fmt.signedMoney`.
- **Screen help**: `Screen.helpTerm`, the glossary term behind each screen's "?".

## 3. Components (Views/Components.swift)

Upgraded rather than duplicated:

- `Page(title:subtitle:screen:)` — with `screen`, the header shows the screen's symbol on the accent gradient and a
  **"?"** (`ScreenHelpButton`) that explains the screen (its first-visit hint text, the first step, its key glossary
  term, "Show this screen's hint again" and a link to Help & Glossary). Every screen now passes its `screen`.
- `Card`, `CardHeader` (title marked as an accessibility header), `cardStyle()` — on tokens.
- `StatTile` — tokens, an optional `help:` "?" (replaces `.helpBadge` overlays on tiles), VoiceOver labels on the trend arrow.
- `SpecRow` (alias `KeyValueRow`) — monospaced values, optional `tone:` (colour + symbol) and `help:`.
- `Pill(_:tone:)` — status pills carry the tone's symbol.
- `EmptyStateView(compact:)` — a smaller variant for use inside cards.
- `Meter` — exposes its value to VoiceOver.

New, where repetition existed:

- `SectionHeader` — page-level group heading with a hairline (the dashboard sections).
- `EqualColumns` (a `Layout`), `KPIRow`, `CardGrid` — equal-width columns: as many as fit at a minimum width, never
  more than there are items, so four tiles span a wide window and wrap 2×2 at 1100pt with no empty slots.
- `MetricTile(.boxed / .tinted / .plain)` — the one compact stat; the ten local copies now delegate to it.
- `OddsBar` — a probability as bar + percentage + word ("likely", "long shot") + symbol; `risk:` flips it for failure odds.
- `StageStrip` + `StageStep` — a pipeline with done / under way / upcoming / failed / blocked, each with a symbol.
- `SectionTabs` — the screen-level segmented switcher.
- `ChartCard` — header + chart at a fixed height + caption.
- `ToneLabel`, `LegendItem`, `AlignmentBadge` (dashboard file; alignment with a level-dependent shield symbol).

## 4. Per screen

New screens first.

| Screen | What differed | What changed |
| --- | --- | --- |
| Dashboard | ~20 cards in two unlabelled columns; era steps computed twice | Four sections — **Needs you** (needs, next steps, founding kit · coming up, briefing), **The race** (race chart, leaderboard, benchmark race · stage, milestones, Rival Watch, Pulse, news), **Business** (revenue, business at a glance, corporate · world, nations, semiconductors), **Programmes** (runs, families, self-improvement, AI organisations · advanced projects, science, events). Each has a header with a live one-line summary. Conditional cards keep their conditions (now named `hasFamilies`, `hasOrgs`… computed once). `EraGuide.steps` computed once and passed to `GettingStarted`. Headline tiles in a `KPIRow`; revenue chart in a `ChartCard`; race legend uses `LegendItem`; alignment numbers use `AlignmentBadge`; paused runs get a warning pill. |
| Advanced Projects | HStack KPIs, fixed 2-col grids, colour-only odds and schedule, bare empty states | `KPIRow`, `SectionTabs`, adaptive grids (solicitations, agencies), `CardGrid` for facilities, `OddsBar` for win odds (card and proposal) and trial-failure odds, shared `StageStrip` for programme stages, `ToneLabel` for schedule and denied clearances, toned P&L / margin / record rows, empty states in cards, VoiceOver labels on requirement and milestone checks. |
| Corporate | HStack KPIs, ad-hoc tabs, grey-text empty states, colour-only runway pills | `KPIRow` (header, tax, subsidiary), `SectionTabs`, `CardGrid` for balance/cash-flow and rating/cap-table and start/targets pairs, compact `EmptyStateView`s, toned runway and status pills, `TypeRamp.display` rating. |
| Semiconductors | Ad-hoc tabs, colour-only event dots | `SectionTabs`, tone symbols on event lines, `KPIRow`. |
| Science | Local `StageStrip` (colour only), HStack KPIs | `ScienceStageStrip` maps onto the shared `StageStrip` (reruns as notes, stage blurbs as tooltips), `KPIRow`, "Lab less suited" warning pill. |
| Families | "Paused" colour-only pill | Toned pill; page "?". |
| Nations | Colour-only "effects on you", bare empty state | Values carry a ✓/! symbol and VoiceOver label; `CardGrid`s; empty state in a card. |
| Progression | Criteria meters colour-only on the dashboard card | ✓ on met criteria, VoiceOver labels, tile radius token. |
| Launch views | Inset panel radius 8 | Inset token. (Effects already used ▲/▼ symbols.) |
| AI Organisations (Swarm) | Private `OrgStat`, fixed 6/5-column stat grids | `MetricTile`; `EqualColumns` stat strips that wrap; banner number on the ramp. |
| Training Data | Unlabelled picker, HStack KPIs | `SectionTabs`, `KPIRow`, "Contamination"/"Active" toned pills. |
| Datacenters | Picker at 520pt, HStack KPIs, legend in one HStack | `SectionTabs` (with the Build button), `KPIRow`s, `GWBar` legend wraps with `LegendItem`, inset token, "Online" toned. |
| Country selection | White-at-low-opacity fills and strokes | `Theme.insetFill` / `Theme.hairline`. |
| Run review / run report | Private `ReportStat`, 40pt verdict | `MetricTile`, `TypeRamp.display`, inset token. |
| Events | HStack KPIs | `KPIRow`, `CardGrid` for papers/contests, "Won" toned. Calendar + fixed-width hackathon column kept. |
| Founding kit | White-at-low-opacity fills | `Theme.insetFill`. |
| Model Lab | 46pt forecast, private `PlannerStat`, bare empty state | `TypeRamp.display`, `MetricTile`, empty state in a card. |
| Training Runs | Private `LiveStat`, 6-column stat grid, 34pt progress | `MetricTile`, wrapping `EqualColumns`, `TypeRamp.bannerMetric`, inset tokens. |
| Rivals hub | Picker at 440pt | `SectionTabs`; `KPIRow` field tiles; banner number on the ramp. |
| Rival Watch / Industry / Leaderboard / Market / Milestones / Research / Benchmarks | Main column + fixed side column in `HStack`s; adaptive or HStack KPI rows | Side-column layouts kept as they were (deliberate fixed widths). KPI rows → `KPIRow`; other pairs → `CardGrid`; Market's `MiniStat`, Models' `Metric` → `MetricTile`; banner numbers on the ramp. |
| Pulse | Picker at 360pt | `SectionTabs`. |
| World | Bare empty state, adaptive KPI grid, private `WorldJobFigure` | Empty state in a card, `KPIRow`, `CardGrid`s, `MetricTile`. |
| Compute | `.helpBadge` overlay on a tile, legend in one HStack | `StatTile(help:)`, wrapping legend via `LegendItem`, `KPIRow`, `CardGrid`. |
| Finance / Funding | `.helpBadge` overlays | `StatTile(help:)` on both; Finance KPIs in a `KPIRow` and its chart pair in a `CardGrid` (Funding keeps its fixed side column). |
| Strategy / Security / Xeno / RSI / Chip Sales / Silicon | Varying hero numbers, private stat boxes, colour-only RSI alignment dot | Banner numbers on the ramp, `MetricTile`, `AlignmentBadge`, `CardGrid` / `EqualColumns`, inset tokens. |
| Product Lines | Fixed 2-col grid | `Theme.cardColumns`, `KPIRow`. |
| All screens | No screen symbol or persistent help | `Page(…, screen:)` header with symbol and "?". |

Not changed on purpose: the main menu and update views (dark-only, photo-backed), photo overlays (white on a dark
scrim is correct there), vendor/lab/category colours (identity, not meaning), and the main-plus-side-column layouts.

## 5. Rules of thumb for new screens

1. `Page(title:subtitle:screen:)`, then `ScreenHint(screen)` if the screen has a hint.
2. Headline numbers: `KPIRow { StatTile(…) }`. Numbers inside cards: `MetricTile` or `SpecRow`.
3. Two or three cards side by side: `CardGrid`. Lists of cards: `LazyVGrid(columns: Theme.cardColumns)`.
4. Section switchers: `SectionTabs(selection:options:)`.
5. Probabilities: `OddsBar`. Pipelines: `StageStrip`. Charts: `ChartCard`.
6. Good/bad/warning: a `Tone` (`Pill(_:tone:)`, `ToneLabel`, `SpecRow(tone:)`), never a bare `.green`/`.red`.
7. Fills and strokes: `Theme.insetFill`, `Theme.hairline`, `.background.secondary` — never white or black at low opacity
   outside photo overlays.
8. Empty states: `EmptyStateView` inside a `Card` at page level, `compact: true` inside a card.
