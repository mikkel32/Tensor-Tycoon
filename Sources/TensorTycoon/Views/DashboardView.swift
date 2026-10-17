import Charts
import SwiftUI

struct DashboardView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let d = store.derived
        let rr = d.runRate
        let last = s.history.last
        let burn = (last?.profit ?? 0)
        let released = d.board.filter(\.released)
        let mine = d.board.filter(\.isPlayer)
        let best = mine.max { $0.index < $1.index }
        let rank = best.map { Leaderboard.labRank(index: $0.index, board: released, gone: Leaderboard.goneLabs(s)) }

        Page(title: "Dashboard", subtitle: "\(s.companyName) · day \(GameCalendar.daysBetween(s.startDate, s.date) + 1)") {
            HeroBanner(image: heroImage(s), height: 170) {
                HStack(alignment: .bottom) {
                    CompanyLogo(symbol: s.logoSymbol, color: Theme.logoColor(s.logoColor), size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(s.companyName).font(.system(size: 30, weight: .bold))
                            PhotoPill(text: s.doctrine.title, symbol: s.doctrine.symbol)
                        }
                        Text("\(Economy.officeLevels[min(s.officeLevel, 5)].name) · \(s.employees.count + 1) people · \(Fmt.int(d.totalChips)) accelerators · \(Fmt.count(d.h100e)) H100-equivalents")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Your net worth").font(.caption).opacity(0.8)
                        Text(Fmt.money(s.founderNetWorth)).font(.title2.weight(.bold).monospacedDigit())
                        Text("\(Fmt.pct(s.founderStake)) of \(Fmt.money(s.valuation))\(s.founderCash > 0 ? " + \(Fmt.money(s.founderCash)) cashed out" : "")").font(.caption).opacity(0.8)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                StatTile(title: "Cash", value: Fmt.money(s.cash), detail: runway(s, burn: burn), symbol: "banknote.fill", tint: s.cash >= 0 ? .green : .red)
                StatTile(title: "Revenue run-rate", value: Fmt.money(rr), detail: "This month \(Fmt.money(s.month.revenue))", symbol: "chart.line.uptrend.xyaxis", tint: .blue,
                         trend: trend(s))
                StatTile(title: "Last month P&L", value: signedMoney(burn), detail: last.map { "Revenue \(Fmt.money($0.revenue))" } ?? "First month", symbol: "plus.forwardslash.minus",
                         tint: burn >= 0 ? .green : .orange)
                StatTile(title: "Valuation", value: Fmt.money(s.valuation), detail: s.isPublic ? "Public · \(Fmt.price(s.sharePrice))/share" : "Private", symbol: "building.columns.fill", tint: .purple)
                StatTile(title: "Chat users", value: Fmt.count(s.consumerUsers), detail: "\(Fmt.count(s.paidUsers)) paying", symbol: "person.2.fill", tint: .pink)
                StatTile(title: "API tokens / day", value: Fmt.count(s.models.reduce(0) { $0 + $1.servedTokensDay }), detail: "Reliability \(Fmt.pct(s.reliability, decimals: 0))", symbol: "bolt.horizontal.fill", tint: .teal)
                StatTile(title: "Best model", value: best.map { "\(Fmt.score($0.index))" } ?? "—", detail: best.map { "\($0.model) · #\(rank ?? 0) worldwide · capability \(Int($0.capability.rounded()))\($0.released ? "" : " (unreleased)")" } ?? "Train one in the Model Lab", symbol: "trophy.fill", tint: .orange)
                StatTile(title: "Agent seats", value: Fmt.count(s.agentSeats), detail: s.agentModelID == nil ? "Launch in Market" : "\(Fmt.pct(s.agentShare, decimals: 1)) share · \(Fmt.money(s.agentPrice))/seat", symbol: "person.badge.key.fill", tint: .indigo)
                if !s.swarms.isEmpty {
                    StatTile(title: "Agent swarms", value: Fmt.count(s.swarms.filter { !$0.paused }.reduce(0) { $0 + $1.active }),
                             detail: "\(Fmt.count(s.swarmRPToday)) RP/day · \(Fmt.money(s.laborToday * 30.4))/mo labor", symbol: "person.3.sequence.fill", tint: .purple)
                }
                if !s.leases.isEmpty || !s.chipLines.isEmpty {
                    StatTile(title: "Compute sales", value: "\(Fmt.money((s.leaseRevenueToday + s.chipLines.reduce(0) { $0 + $1.unitsToday * $1.price }) * 365))/yr",
                             detail: "Leasing + chip sales", symbol: "shippingbox.fill", tint: .green)
                }
                StatTile(title: "Treasury yield", value: "\(Fmt.trim(Treasury.yieldRate(s), 2))%", detail: "\(Fmt.money(s.month.interestIncome)) interest this month", symbol: "percent", tint: .mint)
            }

            ChiefOfStaffCard(items: d.advice)

            if let b = s.briefings.first, GameCalendar.daysBetween(b.month, s.date) <= 62 {
                BriefingCard(briefing: b)
            }

            HStack(alignment: .top, spacing: 16) {
                Card {
                    CardHeader("Revenue vs. costs", symbol: "chart.bar.fill", subtitle: "Monthly")
                    RevenueChart(history: Array(s.history.suffix(24)) + [s.month], week: RevenueChart.week(s.date))
                        .equatable()
                        .frame(height: 220)
                }
                Card {
                    CardHeader("Frontier race", symbol: "flag.checkered", subtitle: "Best capability over time (100 = GPT-4; +10 is ten times the effective compute)")
                    FrontierChart(points: FrontierChart.points(s))
                        .equatable()
                        .frame(height: 220)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    GettingStarted(state: s, chips: d.totalChips)
                    ActiveRunsCard(state: s)
                    if !s.rsiRuns.filter({ $0.status != .halted }).isEmpty { RSIStatusCard(runs: s.rsiRuns.filter { $0.status != .halted }) }
                    if !s.swarms.isEmpty || s.xenoInsight > 0 || !s.alienArchs.isEmpty { SwarmStatusCard(state: s) }
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 16) {
                    RivalWatchMiniCard(state: s)
                    TopModelsCard(board: Array(released.sorted { $0.index > $1.index }.prefix(6)))
                    BenchmarkRaceCard(set: d.indexSet, released: released, mine: mine)
                    LatestNewsCard(news: Array(s.news.prefix(6)))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func heroImage(_ s: GameState) -> String {
        if let dc = s.sites.filter({ $0.kind == .datacenter && $0.isReady(s.date) }).max(by: { $0.capacityKW < $1.capacityKW }) { return dc.location.image }
        if s.sites.contains(where: { $0.kind == .colo }) { return "dc_corridor" }
        return Economy.officeLevels[min(s.officeLevel, 5)].image
    }

    private func runway(_ s: GameState, burn: Double) -> String {
        guard burn < 0 else { return "Cash-flow positive" }
        let months = s.cash / -burn
        return months > 48 ? "Runway 4+ years" : "Runway \(Fmt.trim(max(0, months), 1)) months"
    }

    private func trend(_ s: GameState) -> Double? {
        guard s.history.count >= 2 else { return nil }
        return s.history[s.history.count - 1].revenue - s.history[s.history.count - 2].revenue
    }
}

struct BenchmarkRaceCard: View {
    @Environment(GameStore.self) private var store
    let set: [Benchmark]
    let released: [Leaderboard.Entry]
    let mine: [Leaderboard.Entry]

    var body: some View {
        Card {
            CardHeader(title: "Benchmark race", symbol: "flame.fill") {
                Button("All benchmarks") { store.open(.benchmarks) }.buttonStyle(.link)
            }
            Text("The benchmarks in the Intelligence Index now. The red tick is the saturation line: once two labs pass it, the benchmark rotates out as soon as a successor is ready.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(set.prefix(6)) { b in
                let retiring = store.game.benchSaturated[b.id] != nil
                let sota = released.map { $0.score(b) }.max() ?? 0
                let you = mine.map { $0.score(b) }.max()
                HStack(spacing: 8) {
                    Text(b.name).font(.caption.weight(.medium)).frame(width: 150, alignment: .leading).lineLimit(1)
                        .help(retiring ? "Saturated: leaves the index when a successor is ready." : b.about)
                    ZStack(alignment: .leading) {
                        Meter(value: sota / 100, tint: retiring ? .green : .orange, height: 7)
                        if let you { Meter(value: you / 100, tint: .accentColor, height: 3).padding(.top, 9) }
                        GeometryReader { g in
                            Rectangle().fill(.red.opacity(0.75)).frame(width: 2, height: 12).offset(x: g.size.width * b.saturation / 100 - 1, y: -2)
                        }
                    }
                    .frame(height: 12)
                    Text(Fmt.score(sota)).font(.caption.monospacedDigit()).frame(width: 34, alignment: .trailing)
                }
            }
        }
    }
}

struct RSIStatusCard: View {
    @Environment(GameStore.self) private var store
    let runs: [RSIRun]

    var body: some View {
        Card {
            CardHeader(title: "Self-improvement", symbol: "arrow.triangle.2.circlepath") {
                Button("Lab") { store.open(.rsi) }.buttonStyle(.link)
            }
            ForEach(runs) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(r.name).font(.callout.weight(.semibold))
                        Pill(text: "g\(r.generation)", color: .purple)
                        Spacer()
                        let a = r.alignmentMeasured
                        Label("\(Int(a))", systemImage: "shield.lefthalf.filled").font(.caption)
                            .foregroundStyle(a >= 70 ? .green : (a >= 45 ? .yellow : .red))
                    }
                    Meter(value: r.genProgress, tint: .purple, height: 6)
                }
            }
        }
    }
}

/// Prioritised to-do list: what needs your attention right now.
struct ChiefOfStaffCard: View {
    @Environment(GameStore.self) private var store
    let items: [AdvisorItem]
    @State private var expanded = false

    var body: some View {
        let fixable = items.filter { $0.fix != nil }.count
        Card {
            CardHeader(title: "Chief of Staff", symbol: "person.crop.circle.badge.checkmark",
                       subtitle: items.isEmpty ? "Nothing needs you right now."
                           : "\(items.count) thing\(items.count == 1 ? "" : "s") need\(items.count == 1 ? "s" : "") you · \(fixable) with a one-click fix") {
                HStack(spacing: 12) {
                    Button("Delegates") { store.open(.operations) }.buttonStyle(.link)
                    if items.count > 4 {
                        Button(expanded ? "Show less" : "Show all \(items.count)") { expanded.toggle() }.buttonStyle(.link)
                    }
                }
            }
            if !items.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 10)], spacing: 8) {
                    ForEach(expanded ? items : Array(items.prefix(4))) { item in
                        AdviceRow(item: item)
                    }
                }
            }
        }
    }
}

struct AdviceRow: View {
    @Environment(GameStore.self) private var store
    let item: AdvisorItem

    var body: some View {
        let tint = color(item.level)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.symbol)
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.callout.weight(.semibold)).lineLimit(1)
                Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 10) {
                    if item.fix != nil {
                        Button(item.fixLabel.isEmpty ? "Fix it" : item.fixLabel) { store.applyFix(item) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(tint)
                    }
                    Button("Open \(item.screen.title)") { store.open(item.screen) }
                        .buttonStyle(.link)
                        .font(.caption)
                    Spacer(minLength: 0)
                    Menu {
                        Button("Hide for a week") { store.snooze(item, days: 7) }
                        Button("Hide for a month") { store.snooze(item, days: 30) }
                        Button("Hide for a year") { store.snooze(item, days: 365) }
                    } label: {
                        Image(systemName: "bell.slash")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Hide this for a while")
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 10))
    }

    private func color(_ l: AdvisorItem.Level) -> Color {
        switch l {
        case .urgent: .red
        case .warning: .orange
        case .info: .blue
        }
    }
}

struct SwarmStatusCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader(title: "Agent swarms", symbol: "person.3.sequence.fill") {
                Button("Swarms") { store.open(.swarms) }.buttonStyle(.link)
            }
            ForEach(s.swarms) { sw in
                HStack {
                    Image(systemName: sw.mission.symbol).foregroundStyle(.secondary).frame(width: 18)
                    Text(sw.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text("\(Fmt.count(sw.active)) agents").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    let a = sw.alignmentMeasured
                    Label("\(Int(a))", systemImage: "shield.lefthalf.filled").font(.caption)
                        .foregroundStyle(a >= 70 ? .green : (a >= 45 ? .yellow : .red))
                }
            }
            if s.xenoInsightToday > 0 || s.xenoInsight > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Alien architecture #\(s.alienArchs.count + 1): \(Fmt.pct(s.xenoInsight / Xeno.insightNeeded(s), decimals: 0))").font(.caption.weight(.semibold))
                    Meter(value: s.xenoInsight / Xeno.insightNeeded(s), tint: .purple, height: 6)
                }
            }
        }
    }
}

/// Redraws when a month closes or a new game week starts, not on every tick: Charts layout is expensive.
struct RevenueChart: View, Equatable {
    let history: [MonthRecord]
    /// The game week this snapshot of the current month was taken in.
    let week: Int

    static func week(_ date: Date) -> Int { Int(date.timeIntervalSince1970 / 86_400) / 7 }

    static func == (a: RevenueChart, b: RevenueChart) -> Bool {
        a.week == b.week && a.history.count == b.history.count && a.history.first?.month == b.history.first?.month
            && a.history.last?.month == b.history.last?.month
    }

    struct Bar: Identifiable {
        var id: String { "\(month.timeIntervalSince1970)-\(kind)" }
        let month: Date
        let kind: String
        let value: Double
    }

    var body: some View {
        let bars = history.flatMap { m -> [Bar] in
            [Bar(month: m.month, kind: "API", value: m.revAPI),
             Bar(month: m.month, kind: "Consumer", value: m.revConsumer),
             Bar(month: m.month, kind: "Enterprise", value: m.revEnterprise + m.revOther),
             Bar(month: m.month, kind: "Agents", value: m.revAgents),
             Bar(month: m.month, kind: "Compute & chips", value: m.revCloud + m.revChips),
             Bar(month: m.month, kind: "Labor & licensing", value: m.revLabor + m.revLicensing)]
        }
        if history.allSatisfy({ $0.revenue == 0 && $0.opex == 0 }) {
            EmptyStateView(symbol: "chart.bar", title: "No numbers yet", message: "Revenue and costs appear here as months close.")
        } else {
            Chart {
                ForEach(bars) { b in
                    BarMark(x: .value("Month", b.month, unit: .month), y: .value("Revenue", b.value))
                        .foregroundStyle(by: .value("Segment", b.kind))
                }
                ForEach(history) { m in
                    LineMark(x: .value("Month", m.month, unit: .month), y: .value("Costs", m.opex + m.costInterest))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .interpolationMethod(.monotone)
                }
            }
            .chartForegroundStyleScale(["API": Color.teal, "Consumer": Color.pink, "Enterprise": Color.indigo, "Agents": Color.orange,
                                        "Compute & chips": Color.green, "Labor & licensing": Color.purple])
            .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
            .chartLegend(position: .bottom, alignment: .leading)
        }
    }
}

struct FrontierChart: View, Equatable {
    struct Point: Identifiable, Equatable {
        let id: Int
        let date: Date
        let lab: String
        let value: Double
    }
    let points: [Point]

    var body: some View {
        Chart(points) { p in
            LineMark(x: .value("Date", p.date), y: .value("Capability", p.value))
                .foregroundStyle(by: .value("Lab", p.lab))
                .interpolationMethod(.stepEnd)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartLegend(position: .bottom, alignment: .leading)
    }

    /// Each lab's best capability so far (a scale that doesn't re-base when benchmarks rotate), top three rival labs
    /// plus you.
    static func points(_ s: GameState) -> [Point] {
        let from = GameCalendar.addMonths(s.startDate, -18)
        // The "now" end of each line moves weekly, so the chart only redraws when something changes.
        let latest = (s.competitors.flatMap { $0.models.map(\.date) } + s.models.map(\.created)).max() ?? s.startDate
        let weekStart = GameCalendar.addDays(s.date, -(Int(s.date.timeIntervalSince1970 / 86_400) % 7))
        let now = max(latest, weekStart)
        var pts: [Point] = []
        func add(_ d: Date, _ lab: String, _ v: Double) { pts.append(Point(id: pts.count, date: d, lab: lab, value: v)) }
        func rivalCap(_ c: CompetitorState, _ m: CompetitorModel) -> Double {
            BenchmarkCatalog.capability(Leaderboard.profile(m, def: c.def, boost: Competitors.boost(s, c.id, at: m.date.decimalYear)))
        }
        let labs = s.competitors.filter { !$0.models.isEmpty }
            .sorted { ($0.models.map(\.c).max() ?? 0) > ($1.models.map(\.c).max() ?? 0) }.prefix(3)
        for comp in labs {
            var best = -Double.infinity
            for m in comp.models.sorted(by: { $0.date < $1.date }) {
                best = max(best, rivalCap(comp, m))
                if m.date >= from { add(m.date, comp.def.name, best) }
            }
            if best.isFinite { add(now, comp.def.name, best) }
        }
        var best = -Double.infinity
        for m in s.models.sorted(by: { $0.created < $1.created }) where m.released || !m.preview {
            best = max(best, BenchmarkCatalog.capability(Leaderboard.profile(m)))
            add(m.created, s.companyName, best)
        }
        if best.isFinite { add(now, s.companyName, best) }
        return pts
    }
}

struct GettingStarted: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let chips: Int

    var body: some View {
        let steps = EraGuide.steps(state)
        let remaining = steps.filter { !$0.done }
        if !remaining.isEmpty {
            Card {
                CardHeader(title: "Next steps", symbol: "checklist", subtitle: "\(steps.count - remaining.count) of \(steps.count) done") {
                    Button("Era briefing") { store.showEraIntro = true }.buttonStyle(.link)
                }
                ForEach(steps) { step in
                    Button {
                        store.open(step.screen)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.done ? .green : .secondary)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.title).font(.callout.weight(.semibold)).strikethrough(step.done)
                                Text(step.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ActiveRunsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let runs = state.runs.filter { $0.status == .running || $0.status == .postTraining || $0.status == .paused }
        Card {
            CardHeader(title: "Training runs", symbol: "chart.line.downtrend.xyaxis") {
                Button("Model Lab") { store.open(.lab) }.buttonStyle(.link)
            }
            if runs.isEmpty {
                Text("No runs in progress.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(runs) { run in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(run.design.name).font(.callout.weight(.semibold))
                        Pill(text: run.status.rawValue, color: run.status == .paused ? .orange : .blue)
                        Spacer()
                        Text(run.status == .postTraining ? Fmt.pct(run.postTrainFlops > 0 ? run.postTrainDone / run.postTrainFlops : 0, decimals: 0) : Fmt.pct(run.progress, decimals: 0))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Meter(value: run.status == .postTraining ? (run.postTrainFlops > 0 ? run.postTrainDone / run.postTrainFlops : 0) : run.progress,
                          tint: run.status == .postTraining ? .purple : .blue)
                }
            }
        }
    }
}

/// The top labs by flagship (one row per lab, so one lab's back catalogue can't fill it), plus you if you're further down.
/// Labs are ranked from the store's full board; `board` (the top released models) just says whether there's anything to show.
struct TopModelsCard: View {
    @Environment(GameStore.self) private var store
    let board: [Leaderboard.Entry]

    var body: some View {
        let labs = board.isEmpty ? [] : Leaderboard.labs(store.derived.board.filter(\.released), state: store.game)
            .filter { $0.rank > 0 }.sorted { $0.rank < $1.rank }
        let top = labs.contains { $0.isPlayer && $0.rank > 6 } ? Array(labs.prefix(5)) + labs.filter(\.isPlayer) : Array(labs.prefix(6))
        Card {
            CardHeader(title: "World leaderboard", symbol: "trophy") {
                Button("All") { store.open(.leaderboard) }.buttonStyle(.link)
            }
            ForEach(top) { r in
                HStack {
                    Text(verbatim: "\(r.rank)").font(.caption.monospacedDigit().weight(.bold)).frame(width: 18).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(r.lab).font(.callout.weight(r.isPlayer ? .bold : .regular))
                        Text(verbatim: "\(r.flagship.model) · capability \(Int(r.flagship.capability.rounded()))").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Fmt.score(r.flagship.index)).font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(r.isPlayer ? Color.accentColor : .primary)
                }
            }
        }
    }
}

struct LatestNewsCard: View {
    @Environment(GameStore.self) private var store
    let news: [NewsItem]

    var body: some View {
        Card {
            CardHeader(title: "Latest news", symbol: "newspaper") {
                Button("All") { store.open(.news) }.buttonStyle(.link)
            }
            ForEach(news) { n in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: n.category.symbol)
                        .foregroundStyle(Theme.categoryColor(n.category))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(n.title).font(.callout.weight(.medium)).lineLimit(2)
                        Text(n.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}
