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
        let rank = best.map { e in released.filter { !$0.isPlayer && $0.index > e.index }.count + 1 }

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
                StatTile(title: "Best model", value: best.map { "\(Fmt.score($0.index))" } ?? "—", detail: best.map { "\($0.model) · #\(rank ?? 0) worldwide\($0.released ? "" : " (unreleased)")" } ?? "Train one in the Model Lab", symbol: "trophy.fill", tint: .orange)
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

            ChiefOfStaffCard(items: Advisor.items(s, pools: d.pools))

            HStack(alignment: .top, spacing: 16) {
                Card {
                    CardHeader("Revenue vs. costs", symbol: "chart.bar.fill", subtitle: "Monthly")
                    RevenueChart(history: Array(s.history.suffix(24)) + [s.month])
                        .frame(height: 220)
                }
                Card {
                    CardHeader("Frontier race", symbol: "flag.checkered", subtitle: "Best Intelligence Index over time (re-scored on today's benchmarks)")
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
            Text("The live benchmarks in the Intelligence Index. The red tick is where each one saturates and gets replaced by something harder.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(set.prefix(6)) { b in
                let sota = released.map { $0.score(b) }.max() ?? 0
                let you = mine.map { $0.score(b) }.max()
                HStack(spacing: 8) {
                    Text(b.name).font(.caption.weight(.medium)).frame(width: 150, alignment: .leading).lineLimit(1)
                    ZStack(alignment: .leading) {
                        Meter(value: sota / 100, tint: .orange, height: 7)
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
        Card {
            CardHeader(title: "Chief of Staff", symbol: "person.crop.circle.badge.checkmark",
                       subtitle: items.isEmpty ? "Nothing needs you right now." : "\(items.count) thing\(items.count == 1 ? "" : "s") need\(items.count == 1 ? "s" : "") your attention") {
                if items.count > 4 {
                    Button(expanded ? "Show less" : "Show all") { expanded.toggle() }.buttonStyle(.link)
                }
            }
            if !items.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 8) {
                    ForEach(expanded ? items : Array(items.prefix(4))) { item in
                        Button { store.open(item.screen) } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: item.symbol)
                                    .foregroundStyle(color(item.level))
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.callout.weight(.semibold)).lineLimit(1)
                                    Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(color(item.level).opacity(0.08), in: .rect(cornerRadius: 10))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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

struct RevenueChart: View {
    let history: [MonthRecord]

    struct Bar: Identifiable {
        let id = UUID()
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
        let index: Double
    }
    let points: [Point]

    var body: some View {
        Chart(points) { p in
            LineMark(x: .value("Date", p.date), y: .value("Index", p.index))
                .foregroundStyle(by: .value("Lab", p.lab))
                .interpolationMethod(.stepEnd)
        }
        .chartYScale(domain: 0...100)
        .chartLegend(position: .bottom, alignment: .leading)
    }

    static func points(_ s: GameState) -> [Point] {
        let from = GameCalendar.addMonths(s.startDate, -18)
        var pts: [Point] = []
        func add(_ d: Date, _ lab: String, _ v: Double) { pts.append(Point(id: pts.count, date: d, lab: lab, index: v)) }
        let labs = s.competitors.filter { !$0.models.isEmpty }
            .sorted { ($0.models.map(\.index).max() ?? 0) > ($1.models.map(\.index).max() ?? 0) }.prefix(3)
        for comp in labs {
            var best = 0.0
            for m in comp.models.sorted(by: { $0.date < $1.date }) {
                best = max(best, m.index)
                if m.date >= from { add(m.date, comp.def.name, best) }
            }
            add(s.date, comp.def.name, best)
        }
        var best = 0.0
        add(s.startDate, s.companyName, 0)
        for m in s.models.sorted(by: { $0.created < $1.created }) where m.released || !m.preview {
            best = max(best, m.index)
            add(m.created, s.companyName, best)
        }
        add(s.date, s.companyName, best)
        return pts
    }
}

struct GettingStarted: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let chips: Int

    var body: some View {
        let s = state
        let steps: [(String, String, Bool, Screen)] = [
            ("Queue research", "Pick breakthroughs to unlock better models.", !s.researchQueue.isEmpty || s.researched.count > 15, .research),
            ("Train your first model", "Design it in the Model Lab.", !s.runs.isEmpty, .lab),
            ("Release & deploy it", "Give it chips and set an API price.", s.models.contains { $0.released && !$0.deployments.isEmpty }, .models),
            ("Launch a chat app", "Pick the model that powers your consumer product.", s.chatModelID != nil, .market),
            ("Hire your team", "Researchers speed up R&D; infra keeps clusters alive.", s.employees.count >= 5, .team),
            ("Scale compute", "Rent cloud GPUs/TPUs or buy hardware for a datacenter.", chips > 64, .hardware),
            ("Raise money", "Sell equity or borrow to fund bigger runs.", s.rounds.count > 1 || !s.loans.isEmpty, .funding),
        ]
        let remaining = steps.filter { !$0.2 }
        if !remaining.isEmpty {
            Card {
                CardHeader("Next steps", symbol: "checklist", subtitle: "\(steps.count - remaining.count) of \(steps.count) done")
                ForEach(steps, id: \.0) { step in
                    Button {
                        store.open(step.3)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: step.2 ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.2 ? .green : .secondary)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.0).font(.callout.weight(.semibold)).strikethrough(step.2)
                                Text(step.1).font(.caption).foregroundStyle(.secondary)
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

struct TopModelsCard: View {
    @Environment(GameStore.self) private var store
    let board: [Leaderboard.Entry]

    var body: some View {
        Card {
            CardHeader(title: "World leaderboard", symbol: "trophy") {
                Button("All") { store.open(.leaderboard) }.buttonStyle(.link)
            }
            ForEach(Array(board.enumerated()), id: \.element.id) { i, e in
                HStack {
                    Text("\(i + 1)").font(.caption.monospacedDigit().weight(.bold)).frame(width: 18).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(e.model).font(.callout.weight(e.isPlayer ? .bold : .regular))
                        Text(e.lab).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Fmt.score(e.index)).font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(e.isPlayer ? Color.accentColor : .primary)
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
