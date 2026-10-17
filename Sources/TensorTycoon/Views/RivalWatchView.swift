import Charts
import SwiftUI

/// Rival Watch, the Rivals hub's Watch tab: who is training what, when it ships and how good it will be — as far as the
/// rumour mill can tell. Reads the store's cached rows (`derived.watch`).
struct RivalWatchTab: View {
    @Environment(GameStore.self) private var store
    let open: (String) -> Void

    var body: some View {
        let s = store.game
        let set = store.derived.indexSet
        let rows = store.derived.watch
        let mine = RivalIntel.playerBest(s, set: set)
        let next = RivalIntel.playerNext(s)
        let q = RivalIntel.quality(s)
        VStack(alignment: .leading, spacing: 18) {
            WatchHero(rows: rows, mine: mine)
            HStack(spacing: 12) {
                StatTile(title: "In pre-training", value: "\(rows.filter { $0.outlook.phase == .pretraining }.count) of \(rows.count) labs",
                         detail: "Burning compute right now", symbol: "flame.fill", tint: .orange)
                StatTile(title: "Next launch", value: rows.first?.project.name ?? "—",
                         detail: rows.first.map { "\($0.lab) · \(RivalIntel.windowText($0.outlook))" } ?? "Nothing rumoured",
                         symbol: "calendar.badge.clock", tint: .indigo)
                StatTile(title: "Threats", value: "\(rows.filter { $0.threat == .passYou }.count)",
                         detail: "Forecast above your best model", symbol: "exclamationmark.triangle.fill", tint: .red)
                StatTile(title: "Intel quality", value: Fmt.pct(q, decimals: 0), detail: RivalIntel.qualityLabel(q),
                         symbol: "binoculars.fill", tint: .teal)
            }
            ReleaseRadarCard(rows: rows, state: s)
            StrategyBoardCard(state: s, open: open)
            HStack(alignment: .top, spacing: 16) {
                ForecastChartCard(rows: rows, mine: mine, next: next, today: s.date)
                IntelDeskCard(state: s, rows: rows)
                    .frame(width: 380)
            }
            if rows.isEmpty {
                Card {
                    EmptyStateView(symbol: "binoculars", title: "No rival runs to watch",
                                   message: "Once the labs are founded and training, their next models show up here.")
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 430), spacing: 14)], spacing: 14) {
                    ForEach(rows) { r in RivalRunCard(row: r, state: s, open: open) }
                }
            }
            HStack(alignment: .top, spacing: 16) {
                RumorFeedCard(state: s)
                TrackRecordCard(state: s)
                    .frame(width: 380)
            }
            Text("Release windows and forecasts come from the rumour mill: leaks, supply-chain checks, power filings and job posts. They tighten as launches near. Leapfrog a lab whose model is in post-training and it may declare a code red: ship early and weaker, or hold back and train harder. Launch a better model in the two weeks before a rival's and you own the news cycle.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Kept for links and helpers: opens the Rivals hub on its Watch tab.
struct RivalWatchView: View {
    var body: some View { RivalsHubView(tab: .watch) }

    static func threatColor(_ t: RivalIntel.Threat) -> Color {
        switch t {
        case .passYou: .red
        case .close: .orange
        case .behind: .green
        case .unknown: .secondary
        }
    }

    static func threatSymbol(_ t: RivalIntel.Threat) -> String {
        switch t {
        case .passYou: "arrow.up.forward.circle.fill"
        case .close: "equal.circle.fill"
        case .behind: "arrow.down.forward.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

// MARK: - Hero

private struct WatchHero: View {
    let rows: [RivalIntel.Row]
    let mine: (name: String, index: Double)?

    var body: some View {
        let threat = rows.first { $0.threat == .passYou }
        let title = threat.map { "\($0.project.name) is coming" } ?? (rows.isEmpty ? "All quiet" : "Nobody is set to pass you")
        let line = heroLine(threat)
        HeroBanner(image: "hyperscale_campus", height: 150) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title.weight(.bold))
                    Text(line).font(.callout).opacity(0.9)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Your best").font(.caption).opacity(0.8)
                    Text(mine.map { Fmt.score($0.index) } ?? "—").font(.system(size: 26, weight: .bold))
                    Text(mine?.name ?? "No model yet").font(.caption).opacity(0.8)
                }
            }
        }
    }

    private func heroLine(_ threat: RivalIntel.Row?) -> String {
        if let t = threat {
            return "\(t.lab) · rumoured \(RivalIntel.windowText(t.outlook)) · forecast \(Fmt.score(t.outlook.index)) (\(Fmt.score(t.outlook.indexLow))–\(Fmt.score(t.outlook.indexHigh)))"
        }
        if let first = rows.first {
            return "Next up: \(first.project.name) from \(first.lab), \(RivalIntel.windowText(first.outlook))"
        }
        return "No rival runs to watch yet."
    }
}

// MARK: - Release radar

private struct LaneSpan {
    enum Style { case pretrain, posttrain, window, unknown, yours }
    var from: Double
    var to: Double
    var style: Style
    var help: String
}

private struct LaneMarker {
    var at: Double
    var symbol: String
    var help: String
}

private struct RadarTick: Identifiable {
    var id: Int
    var x: Double
    var label: String
}

private struct ReleaseRadarCard: View {
    let rows: [RivalIntel.Row]
    let state: GameState

    var body: some View {
        let s = state
        let start = GameCalendar.addMonths(s.date, -1)
        let end = GameCalendar.addMonths(s.date, 11)
        let total = Double(max(1, GameCalendar.daysBetween(start, end)))
        let frac = { (d: Date) -> Double in clamp(Double(GameCalendar.daysBetween(start, d)) / total, 0, 1) }
        let today = frac(s.date)
        Card {
            CardHeader("Release radar", symbol: "calendar.day.timeline.left",
                       subtitle: "Training runs and rumoured launch windows over the next 12 months")
            RadarAxis(ticks: Self.ticks(start: start, end: end, frac: frac))
            RadarLane(label: "\(s.companyName) (you)", sublabel: yourSublabel(s), color: Theme.logoColor(s.logoColor),
                      spans: yourSpans(s, frac: frac), markers: yourMarkers(s, frac: frac), today: today)
            ForEach(rows) { r in
                RadarLane(label: r.lab, sublabel: "\(r.project.name) · \(r.outlook.phase.rawValue)", color: Theme.competitorColor(r.color),
                          spans: spans(r, frac: frac), markers: markers(r, start: start, frac: frac), today: today)
            }
            HStack(spacing: 14) {
                Legend(text: "Pre-training", style: .pretrain)
                Legend(text: "Post-training", style: .posttrain)
                Legend(text: "Rumoured launch window", style: .window)
                Legend(text: "No intel on the run", style: .unknown)
                Label("Shipped", systemImage: "checkmark.seal.fill").font(.caption2).foregroundStyle(.secondary)
                Label("Today", systemImage: "line.diagonal").font(.caption2).foregroundStyle(.red)
            }
        }
    }

    static func ticks(start: Date, end: Date, frac: (Date) -> Double) -> [RadarTick] {
        var out: [RadarTick] = []
        let c = GameCalendar.components(start)
        var m = GameCalendar.date(c.year, c.month, 1)
        var i = 0
        while m <= end {
            if m >= start {
                let comps = GameCalendar.components(m)
                let label = comps.month == 1 ? "Jan \(comps.year)" : RivalIntel.dayMonth.string(from: m).components(separatedBy: " ").last ?? ""
                out.append(RadarTick(id: i, x: frac(m), label: label))
            }
            m = GameCalendar.addMonths(m, 1)
            i += 1
        }
        return out
    }

    private func spans(_ r: RivalIntel.Row, frac: (Date) -> Double) -> [LaneSpan] {
        let p = r.project
        let o = r.outlook
        var out: [LaneSpan] = []
        if o.trainingKnown {
            out.append(LaneSpan(from: frac(p.started), to: frac(p.preEnd), style: .pretrain,
                                help: "\(p.codename): pre-training on ~\(Fmt.count(p.chips)) H100e since \(p.started.gameShort)"))
            out.append(LaneSpan(from: frac(p.preEnd), to: frac(o.low), style: .posttrain, help: "Post-training, RL and safety testing"))
        } else {
            out.append(LaneSpan(from: frac(GameCalendar.addDays(o.low, -120)), to: frac(o.low), style: .unknown,
                                help: "Training is under way somewhere — no intel on the run yet"))
        }
        out.append(LaneSpan(from: frac(o.low), to: frac(o.high), style: .window,
                            help: "\(p.name): rumoured \(RivalIntel.windowText(o)) · forecast index \(Fmt.score(o.index))"))
        return out
    }

    private func markers(_ r: RivalIntel.Row, start: Date, frac: (Date) -> Double) -> [LaneMarker] {
        var out = [LaneMarker(at: frac(r.outlook.center), symbol: "circle.fill", help: "Most likely: \(r.outlook.center.gameShort)")]
        if let last = r.last, last.date >= start {
            out.append(LaneMarker(at: frac(last.date), symbol: "checkmark.seal.fill", help: "\(last.name) shipped \(last.date.gameShort)"))
        }
        return out
    }

    private func yourSublabel(_ s: GameState) -> String {
        if let n = RivalIntel.playerNext(s) {
            return n.date <= s.date ? "\(n.name) · ready to ship" : "\(n.name) · ~\(n.date.gameMonth)"
        }
        return "Nothing in training"
    }

    private func yourSpans(_ s: GameState, frac: (Date) -> Double) -> [LaneSpan] {
        var out: [LaneSpan] = []
        for run in s.runs where run.kind == .full && (run.status == .running || run.status == .postTraining || run.status == .paused) {
            let perDay = Training.dailyFlops(run, state: s) * 0.9
            guard perDay > 0 else { continue }
            let left = max(0, run.flopsTotal - run.flopsDone) + max(0, run.postTrainFlops - run.postTrainDone)
            let eta = GameCalendar.addDays(s.date, Int(min(2_000, left / perDay).rounded(.up)))
            out.append(LaneSpan(from: frac(run.started), to: frac(eta), style: .yours,
                                help: "\(run.design.name): \(Int(run.progress * 100))% of pre-training, done ~\(eta.gameShort)"))
        }
        return out
    }

    private func yourMarkers(_ s: GameState, frac: (Date) -> Double) -> [LaneMarker] {
        var out: [LaneMarker] = []
        let since = GameCalendar.addMonths(s.date, -1)
        for m in s.models where m.released {
            if let d = m.releaseDate, d >= since {
                out.append(LaneMarker(at: frac(d), symbol: "checkmark.seal.fill", help: "\(m.name) shipped \(d.gameShort)"))
            }
        }
        if s.models.contains(where: { !$0.released && !$0.retired && !$0.preview }) {
            out.append(LaneMarker(at: frac(s.date), symbol: "shippingbox.fill", help: "A finished model is waiting to ship"))
        }
        return out
    }
}

private struct RadarAxis: View {
    let ticks: [RadarTick]

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 170, height: 1)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(ticks) { t in
                        Text(t.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .offset(x: t.x * geo.size.width)
                    }
                }
            }
            .frame(height: 14)
        }
    }
}

private struct RadarLane: View {
    let label: String
    let sublabel: String
    let color: Color
    let spans: [LaneSpan]
    let markers: [LaneMarker]
    let today: Double

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.caption.weight(.semibold)).lineLimit(1)
                Text(sublabel).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 170, alignment: .leading)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary.opacity(0.5)).frame(height: 3)
                    ForEach(spans.indices, id: \.self) { k in
                        let sp = spans[k]
                        SpanShape(style: sp.style, color: color)
                            .frame(width: max(5, (sp.to - sp.from) * w), height: sp.style == .window ? 18 : 10)
                            .offset(x: sp.from * w)
                            .help(sp.help)
                    }
                    ForEach(markers.indices, id: \.self) { k in
                        let m = markers[k]
                        Image(systemName: m.symbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(color)
                            .offset(x: m.at * w - 5)
                            .help(m.help)
                    }
                    Rectangle().fill(Color.red.opacity(0.8)).frame(width: 1.5).offset(x: today * w)
                }
            }
            .frame(height: 26)
        }
    }
}

private struct SpanShape: View {
    let style: LaneSpan.Style
    let color: Color

    var body: some View {
        switch style {
        case .pretrain:
            Capsule().fill(color.gradient)
        case .posttrain:
            Capsule().fill(color.opacity(0.45))
        case .window:
            Capsule().fill(color.opacity(0.2))
                .overlay(Capsule().strokeBorder(color, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
        case .unknown:
            Capsule().strokeBorder(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        case .yours:
            Capsule().fill(color.gradient)
                .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1))
        }
    }
}

private struct Legend: View {
    let text: String
    let style: LaneSpan.Style

    var body: some View {
        HStack(spacing: 5) {
            SpanShape(style: style, color: .indigo).frame(width: 22, height: style == .window ? 12 : 8)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Strategies

/// What each lab is trying to do right now, and why.
private struct StrategyBoardCard: View {
    let state: GameState
    let open: (String) -> Void
    @State private var expanded: String?

    var body: some View {
        let s = state
        let labs = s.competitors.filter { RivalStrategy.isActive($0, s) && !$0.play.isEmpty }
        Card {
            CardHeader("What the labs are playing at", symbol: "brain.head.profile",
                       subtitle: "Every few months each lab reads its position — gap to the leader, share, cash, your lead — and picks a strategy")
            if labs.isEmpty {
                Text("Strategies start once there's a market to fight over (late 2022).").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(labs) { c in
                let play = RivalStrategy.play(c)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.competitorColor(c.def.color)).frame(width: 9, height: 9)
                        Button(c.def.name) { open(c.id) }
                            .buttonStyle(.plain)
                            .font(.callout.weight(.semibold))
                            .frame(width: 170, alignment: .leading)
                            .help("Open \(c.def.name)'s profile")
                        if let play {
                            Label(play.title, systemImage: play.symbol)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(play.threat >= 2 ? .red : (play.threat == 1 ? .orange : .secondary))
                        }
                        Spacer()
                        if let since = c.playSince { Text("since \(since.gameMonth)").font(.caption).foregroundStyle(.tertiary) }
                        Button(expanded == c.id ? "Hide history" : "History") { expanded = expanded == c.id ? nil : c.id }
                            .buttonStyle(.borderless).font(.caption)
                    }
                    Text("\(c.playReason)\(play.map { " \($0.effect)" } ?? "")").font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 17)
                    if expanded == c.id {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(c.playLog.enumerated()), id: \.offset) { _, line in
                                Text(line).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 17)
                    }
                }
                if c.id != labs.last?.id { Divider() }
            }
        }
    }
}

// MARK: - Forecast chart

private struct ForecastChartCard: View {
    let rows: [RivalIntel.Row]
    let mine: (name: String, index: Double)?
    let next: (name: String, date: Date, index: Double, low: Double, high: Double)?
    let today: Date

    var body: some View {
        let horizon = GameCalendar.addMonths(today, 12)
        let shown = rows.filter { $0.outlook.center <= horizon }
        Card {
            CardHeader(title: "Who leads when", symbol: "chart.dots.scatter",
                       subtitle: "Forecast Intelligence Index of each lab's next model at its likeliest launch date (80% band), against your models") { HelpButton(term: .forecastBand) }
            if shown.isEmpty && next == nil {
                Text("Nothing rumoured for the next 12 months.").font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(shown) { r in
                        RuleMark(x: .value("Launch", r.outlook.center), yStart: .value("Low", r.outlook.indexLow), yEnd: .value("High", r.outlook.indexHigh))
                            .foregroundStyle(Theme.competitorColor(r.color).opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 6, lineCap: .round))
                        PointMark(x: .value("Launch", r.outlook.center), y: .value("Index", r.outlook.index))
                            .foregroundStyle(Theme.competitorColor(r.color))
                            .symbolSize(70)
                            .annotation(position: .trailing, spacing: 4) {
                                Text(r.project.name).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            }
                    }
                    if let mine {
                        RuleMark(y: .value("Your best", mine.index))
                            .foregroundStyle(Color.indigo)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Your best: \(mine.name) \(Fmt.score(mine.index))").font(.caption2.weight(.semibold)).foregroundStyle(.indigo)
                            }
                    }
                    if let next, next.date <= horizon {
                        RuleMark(x: .value("Launch", next.date), yStart: .value("Low", next.low), yEnd: .value("High", next.high))
                            .foregroundStyle(Color.indigo.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 6, lineCap: .round))
                        PointMark(x: .value("Launch", next.date), y: .value("Index", next.index))
                            .foregroundStyle(Color.indigo)
                            .symbol(.diamond)
                            .symbolSize(110)
                            .annotation(position: .trailing, spacing: 4) {
                                Text("\(next.name) (yours)").font(.caption2.weight(.bold)).foregroundStyle(.indigo)
                            }
                    }
                }
                .chartXScale(domain: today...horizon)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxisLabel("Intelligence Index")
                .frame(height: 270)
            }
        }
    }
}

// MARK: - Intel desk

private struct IntelDeskCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let rows: [RivalIntel.Row]

    var body: some View {
        let s = state
        let q = RivalIntel.quality(s)
        let band = rows.isEmpty ? 0 : rows.map { ($0.outlook.indexHigh - $0.outlook.indexLow) / 2 }.reduce(0, +) / Double(rows.count)
        Card {
            CardHeader("Intel desk", symbol: "binoculars.fill", subtitle: "Analysts, supply-chain checks and your own model reading the signals")
            Picker("Monthly budget", selection: Binding(get: { s.intelBudget }, set: { v in store.mutate { $0.setIntelBudget(v) } })) {
                ForEach(RivalIntel.budgets, id: \.self) { b in
                    Text(b > 0 ? Fmt.money(b, decimals: 0) : "None").tag(b)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            HStack {
                Text("Intel quality").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Fmt.pct(q, decimals: 0)) · \(RivalIntel.qualityLabel(q))").font(.caption.weight(.semibold))
            }
            Meter(value: q, tint: .teal, height: 10)
            SpecRow(label: "Press and public filings", value: "+12%")
            SpecRow(label: "Paid intel (\(s.intelBudget > 0 ? "\(Fmt.money(s.intelBudget, decimals: 0))/mo" : "none"))", value: "+\(Fmt.pct(RivalIntel.budgetPart(s), decimals: 0))")
            SpecRow(label: "Your model as analyst", value: "+\(Fmt.pct(RivalIntel.osint(s), decimals: 0))")
            if !s.acquiredLabs.isEmpty {
                SpecRow(label: "Staff from acquired labs", value: "+\(Fmt.pct(min(0.08, Double(s.acquiredLabs.count) * 0.03), decimals: 0))")
            }
            Divider()
            SpecRow(label: "Launch dates, 60 days out", value: "± \(Int(RivalIntel.windowDays60(s).rounded())) days")
            SpecRow(label: "Capability forecasts now", value: rows.isEmpty ? "—" : "± \(Fmt.trim(band, 1)) index points")
            Text("Better intel brings leaked evals, earlier word of new training runs (cluster, compute, site) and fewer false rumours. A smarter model of yours reads the signals better too.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Run cards

private struct RivalRunCard: View {
    let row: RivalIntel.Row
    let state: GameState
    let open: (String) -> Void

    var body: some View {
        let s = state
        let p = row.project
        let o = row.outlook
        let color = Theme.competitorColor(row.color)
        let known = o.trainingKnown
        let pre = RivalIntel.preProgress(p, on: s.date)
        Card {
            HStack(alignment: .top, spacing: 12) {
                CompanyLogo(symbol: row.symbol, color: color, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.title3.weight(.bold))
                    Text("\(row.lab) · codename \(known ? p.codename : "unknown")").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Fmt.score(o.index)).font(.title.weight(.bold).monospacedDigit())
                    Text("\(Fmt.score(o.indexLow))–\(Fmt.score(o.indexHigh)) forecast").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Pill(text: o.phase.rawValue, color: color, symbol: o.phase.symbol)
                Pill(text: row.threat.rawValue, color: RivalWatchView.threatColor(row.threat), symbol: RivalWatchView.threatSymbol(row.threat))
                if p.delays > 0 { Pill(text: p.delays == 1 ? "Delayed" : "Delayed ×\(p.delays)", color: .orange, symbol: "clock.badge.exclamationmark") }
                if p.rushed { Pill(text: "Rushed", color: .red, symbol: "hare.fill") }
                if p.evalLeak != nil { Pill(text: "Evals leaked", color: .purple, symbol: "doc.text.magnifyingglass") }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Pre-training").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(known ? Fmt.pct(pre, decimals: 0) : "no intel").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                Meter(value: known ? pre : 0, tint: color)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .topLeading), count: 3), alignment: .leading, spacing: 10) {
                WatchMini(label: "Cluster", value: known ? "\(Fmt.count(p.chips)) H100e" : "unknown")
                WatchMini(label: "Pre-training compute", value: known ? "\(Fmt.flops(p.flops)) FLOP" : "unknown")
                WatchMini(label: "Rumoured launch", value: RivalIntel.windowText(o))
                WatchMini(label: "Site", value: known ? p.site : "unknown")
                WatchMini(label: "Training since", value: known ? p.started.gameMonth : "—")
                WatchMini(label: "vs your largest run", value: known && s.maxRunCompute > 0 ? "\(Fmt.trim(p.flops / s.maxRunCompute, p.flops > 10 * s.maxRunCompute ? 0 : 1))×" : "—")
            }
            if let play = row.play {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Strategy: \(play.title)", systemImage: play.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(play.threat >= 2 ? .red : (play.threat == 1 ? .orange : .secondary))
                    Text(row.playReason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
            }
            HStack {
                if let last = row.last {
                    Text("Last release: \(last.name), \(last.date.gameMonth) · index \(Fmt.score(last.index))")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
                Button("\(row.lab) profile") { open(row.id) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }
}

private struct WatchMini: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.callout.weight(.semibold).monospacedDigit()).lineLimit(2).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Rumour feed

private struct RumorFeedCard: View {
    let state: GameState
    @State private var lab = "all"

    var body: some View {
        let s = state
        let labs = s.competitors.filter { RivalIntel.isActive($0, s) }
        let items = Array(s.rumors.filter { lab == "all" || $0.labID == lab }.prefix(40))
        Card {
            CardHeader(title: "Rumour mill", symbol: "antenna.radiowaves.left.and.right",
                       subtitle: "Leaks, analyst notes and the occasional fabrication") {
                Picker("Lab", selection: $lab) {
                    Text("All labs").tag("all")
                    ForEach(labs) { c in Text(c.def.name).tag(c.id) }
                }
                .labelsHidden()
                .frame(width: 190)
            }
            if items.isEmpty {
                Text("No rumours yet. They start once a lab begins its next run.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(items) { r in
                RumorRow(rumor: r, state: s)
                if r.id != items.last?.id { Divider() }
            }
        }
    }
}

private struct RumorRow: View {
    let rumor: RivalRumor
    let state: GameState

    var body: some View {
        let r = rumor
        let comp = state.competitors.first { $0.id == r.labID }
        let color = comp.map { Theme.competitorColor($0.def.color) } ?? .secondary
        // A false rumour is exposed once the model ships (or two months pass).
        let exposed = r.wrong && ((comp?.releaseCount ?? 0) > r.count || GameCalendar.daysBetween(r.date, state.date) > 60)
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(r.title).font(.callout.weight(.semibold))
                    Spacer()
                    Text(r.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
                }
                Text(r.body).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Pill(text: r.reliability.rawValue, color: reliabilityColor(r.reliability))
                    if exposed { Pill(text: "Turned out false", color: .red, symbol: "xmark") }
                }
            }
        }
        .opacity(exposed ? 0.6 : 1)
    }

    private func reliabilityColor(_ r: RivalRumor.Reliability) -> Color {
        switch r {
        case .confirmed: .green
        case .credible: .blue
        case .speculative: .orange
        }
    }
}

// MARK: - Track record

private struct TrackRecordCard: View {
    let state: GameState

    var body: some View {
        let calls = state.watchRecord
        let hits = calls.filter(\.hit).count
        let n = Double(max(1, calls.count))
        let miss = calls.map { abs($0.actual - $0.forecast) }.reduce(0, +) / n
        let days = calls.map { Double(abs($0.dateError)) }.reduce(0, +) / n
        Card {
            CardHeader("Track record", symbol: "target", subtitle: "The rumour mill's call six weeks out vs what shipped")
            if calls.isEmpty {
                Text("No launches scored yet.").font(.callout).foregroundStyle(.secondary)
            } else {
                SpecRow(label: "Inside the 80% band", value: "\(hits) of \(calls.count)")
                SpecRow(label: "Average capability miss", value: "\(Fmt.trim(miss, 1)) points")
                SpecRow(label: "Average date miss", value: "\(Int(days.rounded())) days")
                Divider()
                ForEach(calls.prefix(10)) { c in
                    HStack(spacing: 8) {
                        Image(systemName: c.hit ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(c.hit ? .green : .orange)
                        Text(c.model).font(.caption.weight(.semibold)).lineLimit(1)
                        Spacer()
                        Text("called \(Fmt.score(c.forecast)) · got \(Fmt.score(c.actual))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Dashboard card

/// The next few rival launches, for the dashboard.
struct RivalWatchMiniCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let rows = Array(store.derived.watch.prefix(4))
        Card {
            CardHeader(title: "Rival Watch", symbol: "binoculars.fill", subtitle: "Next launches, as the rumour mill sees them") {
                Button("Open") { store.open(.rivalWatch) }.buttonStyle(.link)
            }
            if rows.isEmpty {
                Text("No rival runs to watch yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(rows) { r in
                HStack(spacing: 8) {
                    Circle().fill(Theme.competitorColor(r.color)).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(r.project.name).font(.callout.weight(.semibold)).lineLimit(1)
                        Text("\(r.lab) · \(r.outlook.phase.rawValue)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(RivalIntel.windowText(r.outlook)).font(.caption.monospacedDigit())
                        Text("~\(Fmt.score(r.outlook.index))").font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(RivalWatchView.threatColor(r.threat))
                    }
                }
            }
        }
    }
}
