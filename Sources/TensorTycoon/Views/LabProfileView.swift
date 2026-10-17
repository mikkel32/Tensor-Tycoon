import Charts
import SwiftUI

/// One lab, everything about it: its flagship and model history, its strategy and the reasons behind it, its books,
/// compute and people, its products, its dealings with you, its next model and its history.
struct LabProfileView: View {
    @Environment(GameStore.self) private var store
    let labID: String
    let open: (String) -> Void
    let close: () -> Void

    var body: some View {
        let s = store.game
        if let c = s.competitors.first(where: { $0.id == labID }) {
            VStack(alignment: .leading, spacing: 16) {
                LabProfileHeader(comp: c, state: s, open: open)
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        LabModelsCard(comp: c, state: s)
                        LabStrategyCard(comp: c, state: s)
                        LabProductsCard(comp: c, state: s)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        LabBusinessCard(comp: c, state: s)
                        LabRelationsCard(comp: c, state: s)
                        LabNextCard(comp: c, row: store.derived.watch.first { $0.id == labID }, open: open)
                    }
                    .frame(width: 440)
                }
                LabHistoryCard(comp: c, state: s, open: open)
            }
        } else {
            Card {
                EmptyStateView(symbol: "questionmark.circle", title: "Lab not found", message: "It may belong to another game.",
                               actionTitle: "All labs", action: close)
            }
        }
    }
}

// MARK: - Header

private struct LabProfileHeader: View {
    let comp: CompetitorState
    let state: GameState
    let open: (String) -> Void
    @State private var showAcquire = false

    var body: some View {
        let d = comp.def
        let status = RivalEconomy.status(comp, state)
        Card {
            HStack(alignment: .top, spacing: 14) {
                CompanyLogo(symbol: d.symbol, color: Theme.competitorColor(d.color), size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(d.name).font(.title.weight(.bold))
                        Pill(text: status, color: RivalsStyle.statusColor(status))
                        if let spec = comp.spec { Pill(text: spec.kind.label, color: .secondary) }
                    }
                    Text(d.archetype).font(.callout).foregroundStyle(.secondary)
                    Text("\(d.hq) · CEO \(d.ceo) · founded \(d.founded.label)").font(.caption).foregroundStyle(.secondary)
                    LabLineage(comp: comp, state: state, open: open)
                }
                Spacer()
                if comp.alive {
                    Button("Acquire…") { showAcquire = true }
                        .help("Price, payment mix, antitrust risk and what you'd inherit")
                }
            }
        }
        .popover(isPresented: $showAcquire) { AcquirePanel(comp: comp, state: state) }
    }
}

/// Where the lab came from, who backs it, who bought it and whom it bought.
private struct LabLineage: View {
    let comp: CompetitorState
    let state: GameState
    let open: (String) -> Void

    var body: some View {
        let s = state
        let bought = s.rivalEvents.filter { $0.otherID == comp.id && ($0.kind == "acquired" || $0.kind == "merged") }
        VStack(alignment: .leading, spacing: 3) {
            if let spec = comp.spec {
                if !spec.parentID.isEmpty {
                    link("Founded by people from \(spec.parentName)", symbol: "arrow.triangle.branch", target: spec.parentID == "player" ? nil : spec.parentID)
                }
                if !spec.backer.isEmpty {
                    Label("Backed by \(spec.backer)", systemImage: "building.columns.fill").font(.caption)
                }
                Label("Building \(spec.thesis)", systemImage: "lightbulb.fill").font(.caption)
            } else if let parent = RivalEconomy.parent(comp, s) {
                Label("Funded by \(parent)", systemImage: "building.2.fill").font(.caption)
            }
            if !comp.exitNote.isEmpty {
                link(comp.exitNote, symbol: "archivebox.fill", target: comp.acquiredBy.isEmpty || comp.acquiredBy == "player" ? nil : comp.acquiredBy)
            }
            if !bought.isEmpty {
                Text("Bought: " + bought.map { "\(RivalLifecycle.name($0.labID, s)) (\($0.date.gameMonth))" }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func link(_ text: String, symbol: String, target: String?) -> some View {
        if let target {
            Button {
                open(target)
            } label: {
                Label(text, systemImage: symbol).font(.caption)
            }
            .buttonStyle(.link)
        } else {
            Label(text, systemImage: symbol).font(.caption)
        }
    }
}

// MARK: - Models

private struct LabModelsCard: View {
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let models = comp.models.sorted { $0.date > $1.date }
        let extra = comp.openModels.isEmpty ? "" : " and \(comp.openModels.count) open-weights side release\(comp.openModels.count == 1 ? "" : "s")"
        Card {
            CardHeader("Flagship & models", symbol: "shippingbox.fill", subtitle: "\(models.count) release\(models.count == 1 ? "" : "s")\(extra)")
            flagship
            if comp.models.count > 1 {
                LabIndexChart(comp: comp, mine: state.releasedModels.map(\.index).max() ?? 0)
            }
            ForEach(models.prefix(8)) { m in
                HStack {
                    Text(m.name).font(.callout)
                    if m.open { Pill(text: "Open", color: .teal) }
                    Spacer()
                    Text(m.date.gameMonth).font(.caption).foregroundStyle(.secondary)
                    Text(Fmt.score(m.index)).font(.callout.monospacedDigit()).frame(width: 44, alignment: .trailing)
                }
            }
            if models.count > 8 {
                Text("…and \(models.count - 8) earlier").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var flagship: some View {
        if let m = comp.latest {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.name).font(.title3.weight(.bold))
                    Text("Released \(m.date.gameMonth) · \(m.open ? "open weights" : "closed weights")\(m.reasoning ? " · reasoning" : "") · \(Fmt.price(m.price * (1 - comp.priceCut)))/M tokens")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Fmt.score(m.index)).font(.title.weight(.bold).monospacedDigit())
            }
        } else {
            Text("No model yet: its first is due around \(comp.def.firstModel.label).").font(.callout).foregroundStyle(.secondary)
        }
    }
}

private struct LabIndexChart: View {
    let comp: CompetitorState
    let mine: Double

    var body: some View {
        let color = Theme.competitorColor(comp.def.color)
        Chart {
            ForEach(comp.models) { m in
                LineMark(x: .value("Date", m.date), y: .value("Index", m.index))
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", m.date), y: .value("Index", m.index))
                    .foregroundStyle(color)
                    .symbolSize(18)
            }
            if mine > 0 {
                RuleMark(y: .value("Your best", mine))
                    .foregroundStyle(Color.indigo)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Your best \(Fmt.score(mine))").font(.caption2).foregroundStyle(.indigo)
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .frame(height: 140)
    }
}

// MARK: - Strategy

private struct LabStrategyCard: View {
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let trait = Competitors.trait(comp.id)
        let leanings = RivalStrategy.personality(comp.id).sorted { $0.value > $1.value }.prefix(3).map { $0.key.title.lowercased() }
        Card {
            CardHeader("Strategy", symbol: "brain.head.profile", subtitle: "What it's doing, why, and what it tends to do")
            current
            if !leanings.isEmpty {
                SpecRow(label: "Leans toward", value: leanings.joined(separator: ", "))
            }
            if !trait.signature.isEmpty {
                Label("Signature: \(trait.signature)", systemImage: "seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.competitorColor(comp.def.color))
            }
            LabTechList(comp: comp, state: state)
            if !comp.playLog.isEmpty {
                Divider()
                Text("Past moves").font(.caption.weight(.semibold))
                ForEach(Array(comp.playLog.prefix(6).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var current: some View {
        if let play = RivalStrategy.play(comp) {
            VStack(alignment: .leading, spacing: 3) {
                Label("\(play.title)\(comp.playSince.map { " since \($0.gameMonth)" } ?? "")", systemImage: play.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(play.threat >= 2 ? .red : (play.threat == 1 ? .orange : .primary))
                Text("Why: \(comp.playReason)").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Effect: \(play.effect)").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(comp.alive ? "No strategy yet: labs pick one once they have a model and a market to fight over." : "Out of the race.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

/// The lab's secret techniques: deployed, or still in development.
private struct LabTechList: View {
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let s = state
        let techs = (s.rivalTech[comp.id] ?? []).compactMap { ResearchCatalog.byID[$0] }.filter { $0.year <= s.year + 1 }
        if !techs.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Secret techniques").font(.caption.weight(.semibold))
                ForEach(techs) { item in
                    let live = item.year <= s.year + 0.3
                    HStack(spacing: 6) {
                        Image(systemName: "atom").foregroundStyle(live ? .purple : .secondary)
                        Text(item.name).font(.caption)
                        Pill(text: live ? "Deployed" : "In development", color: live ? .purple : .secondary)
                        if s.exoticOwned.contains(item.id) { Pill(text: "You know it too", color: .indigo) }
                    }
                    .help(item.blurb)
                }
            }
        }
    }
}

// MARK: - Business

private struct LabBusinessCard: View {
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let c = comp
        let backed = RivalEconomy.parent(c, state) != nil
        Card {
            CardHeader("Money, compute & people", symbol: "building.columns.fill", subtitle: backed ? "Its backer pays the bills its revenue doesn't" : "Revenue and investors pay for everything")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), alignment: .leading, spacing: 10) {
                ForEach(Self.figures(c, state)) { f in LabMini(label: f.label, value: f.value) }
            }
            if c.revenueHistory.count > 2 {
                LabRevenueChart(history: c.revenueHistory, today: state.date, color: Theme.competitorColor(c.def.color))
            }
            LabRounds(comp: c)
        }
    }

    struct Figure: Identifiable {
        var id: String { label }
        let label: String
        let value: String
    }

    /// The lab's books in a dozen figures (formatted here, so the view stays simple).
    static func figures(_ c: CompetitorState, _ s: GameState) -> [Figure] {
        let backed = RivalEconomy.parent(c, s) != nil
        let field = RivalLifecycle.labsInBusiness(s).reduce(0) { $0 + $1.computeH100e }
        let monthly = c.revenueHistory.last ?? 0
        var growth = "—"
        if let g = RivalEconomy.growth(c) { growth = (g >= 1 ? "+" : "−") + "\(Int(abs(g - 1) * 100))%" }
        var runway = "—"
        if !backed { runway = RivalEconomy.runwayMonths(c).map { "\(Int($0)) mo" } ?? "Profitable" }
        return [
            Figure(label: "Revenue / yr", value: Fmt.money(c.revenueRun)),
            Figure(label: "Growth (yoy)", value: growth),
            Figure(label: "Valuation", value: Fmt.money(c.valuation)),
            Figure(label: "× revenue", value: c.revenueRun > 1e6 ? "\(Int(c.valuation / c.revenueRun))×" : "—"),
            Figure(label: "Cash", value: backed ? "Backer" : Fmt.money(c.cash)),
            Figure(label: "Runway", value: runway),
            Figure(label: "Compute", value: "\(Fmt.count(c.computeH100e)) H100e"),
            Figure(label: "Share of rivals' compute", value: field > 0 ? Fmt.pct(c.computeH100e / field, decimals: 1) : "—"),
            Figure(label: "Compute bill / mo", value: Fmt.money(c.computeCostMonth)),
            Figure(label: "Staff", value: Fmt.int(c.headcount)),
            Figure(label: "Revenue per head", value: c.headcount > 0 ? Fmt.money(c.revenueRun / Double(c.headcount)) : "—"),
            Figure(label: "Compute ÷ revenue", value: monthly > 0 ? "\(Int(c.computeCostMonth / monthly * 100))%" : "—"),
        ]
    }
}

private struct RevenuePoint: Identifiable {
    let id: Int
    let date: Date
    let value: Double
}

private struct LabRevenueChart: View {
    let history: [Double]
    let today: Date
    let color: Color

    var body: some View {
        let n = history.count
        let points = history.enumerated().map { k, v in RevenuePoint(id: k, date: GameCalendar.addMonths(today, k - n + 1), value: v * 12) }
        Chart(points) { p in
            AreaMark(x: .value("Month", p.date), y: .value("Revenue run-rate", p.value))
                .foregroundStyle(color.opacity(0.25))
            LineMark(x: .value("Month", p.date), y: .value("Revenue run-rate", p.value))
                .foregroundStyle(color)
        }
        .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
        .frame(height: 90)
    }
}

private struct LabRounds: View {
    let comp: CompetitorState

    var body: some View {
        let rounds = Array(comp.rounds.reversed().prefix(5))
        if !rounds.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("Funding (raised \(Fmt.money(comp.totalRaised)) in all)").font(.caption.weight(.semibold))
                ForEach(rounds) { r in
                    HStack {
                        Text(r.label).font(.caption)
                        Spacer()
                        Text("\(r.amount > 0 ? Fmt.money(r.amount) : "—")\(r.postMoney > 0 ? " at \(Fmt.money(r.postMoney))" : "") · \(r.date.gameMonth)")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Products

private struct LabProductsCard: View {
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let c = comp
        let d = c.def
        Card {
            CardHeader("Products", symbol: "square.grid.2x2.fill", subtitle: "Where its revenue comes from")
            if let m = c.latest {
                SpecRow(label: "API: \(m.name)", value: "\(Fmt.price(m.price * (1 - c.priceCut)))/M · \(Int(m.tps)) tok/s · \(Fmt.pct(c.apiShare)) share")
                SpecRow(label: "Chat app: \(d.chatProduct)", value: "\(Fmt.pct(c.consumerShare)) of users")
                SpecRow(label: "Agents: \(d.chatProduct) Agent", value: c.agentShare > 0 ? "\(Fmt.pct(c.agentShare)) of seats" : "Not offered")
                if let o = c.openModels.last {
                    SpecRow(label: "Open weights: \(o.name)", value: "free · index \(Fmt.score(o.index))")
                }
                if c.priceCut > 0.01 {
                    Label("Price war: API prices cut \(Fmt.pct(c.priceCut, decimals: 0))", systemImage: "tag.slash.fill").font(.caption).foregroundStyle(.red)
                } else if c.priceCut < -0.01 {
                    Label("Prices raised \(Fmt.pct(-c.priceCut, decimals: 0)) to stretch its cash", systemImage: "tag.fill").font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text("Nothing on sale yet.").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - You and them

private struct LabRelationsCard: View {
    @Environment(GameStore.self) private var store
    let comp: CompetitorState
    let state: GameState
    @State private var confirmHeadhunt = false

    var body: some View {
        let s = state
        let id = comp.id
        let name = comp.def.name
        let raids = s.rivalEvents.filter { $0.kind == "raid" && $0.labID == id }
        let mentions = Array(s.news.filter { ($0.category == .company || $0.category == .policy) && $0.title.contains(name) }.prefix(4))
        Card {
            CardHeader("You and \(name)", symbol: "person.2.fill", subtitle: "Stakes, deals, raids, lawsuits and what you could do")
            LabStakeRow(comp: comp, state: s)
            LabDealsList(comp: comp, state: s)
            if !raids.isEmpty {
                Label("Raided your research team \(raids.count == 1 ? "once" : "\(raids.count) times"), last \(raids[0].date.gameMonth)", systemImage: "person.2.badge.key.fill")
                    .font(.caption).foregroundStyle(.red)
            }
            if let stolen = s.stolenC[id] {
                Label("Runs on weights it stole or distilled from you (capability \(Fmt.trim(stolen, 2)))", systemImage: "lock.open.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            if !mentions.isEmpty {
                Divider()
                ForEach(mentions) { n in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(n.title).font(.caption.weight(.semibold))
                        Text("\(n.date.gameShort) · \(n.body)").font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            if comp.alive { headhunt }
        }
    }

    @ViewBuilder
    private var headhunt: some View {
        let s = state
        let targets = s.headhuntTargets(comp.id)
        if let tech = targets.first.flatMap({ ResearchCatalog.byID[$0] }) {
            Divider()
            HStack {
                Text("Someone there knows \(tech.name). Odds \(Int(s.headhuntChance(comp.id) * 100))%, \(Fmt.money(s.headhuntFee)) either way.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Headhunt…") { confirmHeadhunt = true }
                    .controlSize(.small)
                    .disabled(s.headhuntReadyOn != nil || s.cash < s.headhuntFee)
            }
            .confirmationDialog("Headhunt from \(comp.def.name)?", isPresented: $confirmHeadhunt) {
                Button("Make the offer (\(Fmt.money(s.headhuntFee)))") {
                    let id = comp.id
                    store.act("Offer made") { $0.headhunt(id) }
                }
            }
        }
    }
}

private struct LabStakeRow: View {
    @Environment(GameStore.self) private var store
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let s = state
        let id = comp.id
        if let f = s.rivalStakes[id], f > 0 {
            let value = RivalEconomy.stakeValue(s, id)
            let cost = s.rivalStakeCost[id] ?? 0
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("You own \(Fmt.pct(f)) worth \(Fmt.money(value))").font(.callout.weight(.semibold))
                    Text("Cost \(Fmt.money(cost)) · \(value >= cost ? "+" : "−")\(Int(abs(value / max(1, cost) - 1) * 100))%")
                        .font(.caption).foregroundStyle(value >= cost ? Color.green : .red)
                }
                Spacer()
                Button(comp.isPublic ? "Sell" : "Sell (−15%)") { store.act("Stake sold") { $0.sellRivalStake(id) } }
                    .controlSize(.small)
            }
        } else {
            Text(s.valuation >= 1e9 ? "No stake. When it raises money, you may be offered a slice of the round." : "No stake. Labs offer slices of their rounds to players worth $1B or more.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Compute it buys from you, techniques it licensed, chips of yours it runs.
private struct LabDealsList: View {
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let s = state
        let id = comp.id
        let deals = s.computeCommitments.filter { $0.labID == id }
        let licenses = s.exoticLicenses.filter { $0.buyerID == id }
        let alien = s.alienArchs.filter { a in a.licenses.contains { $0.buyerID == id } }
        let armed = Xeno.rivalC(s, id, at: s.date)
        ForEach(deals) { d in
            Label("Buys \(Fmt.money(d.monthly))/month of your compute · \(d.monthsLeft) months left", systemImage: "server.rack").font(.caption)
        }
        ForEach(licenses) { l in
            Label("Licensed your \(ResearchCatalog.byID[l.techID]?.name ?? "technique") · \(Fmt.money(l.royaltyMonthly))/month", systemImage: "doc.text.fill").font(.caption)
        }
        ForEach(alien) { a in
            Label("Licensed your alien architecture \(a.name)", systemImage: "atom").font(.caption)
        }
        if armed > 0.005 {
            Label("Your chips and licences add +\(Fmt.trim(armed, 2)) to its models", systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
        }
    }
}

// MARK: - Next model

private struct LabNextCard: View {
    let comp: CompetitorState
    let row: RivalIntel.Row?
    let open: (String) -> Void

    var body: some View {
        Card {
            CardHeader("Next model", symbol: "binoculars.fill", subtitle: "What the rumour mill says")
            if let r = row {
                let o = r.outlook
                let p = r.project
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.headline)
                        Text("\(o.trainingKnown ? "codename \(p.codename) · " : "")\(o.phase.rawValue)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Fmt.score(o.index)).font(.title2.weight(.bold).monospacedDigit())
                        Text("\(Fmt.score(o.indexLow))–\(Fmt.score(o.indexHigh))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Pill(text: RivalIntel.windowText(o), color: .indigo, symbol: "calendar")
                    Pill(text: r.threat.rawValue, color: RivalWatchView.threatColor(r.threat), symbol: RivalWatchView.threatSymbol(r.threat))
                    if p.rushed { Pill(text: "Rushed", color: .red) }
                    if p.delays > 0 { Pill(text: "Delayed", color: .orange) }
                }
                if o.trainingKnown {
                    Text("Training on about \(Fmt.count(p.chips)) H100e at \(p.site): \(Fmt.flops(p.flops)) FLOPs of pre-training.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(comp.alive ? "No run in sight yet." : "It won't ship again.").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - History

private struct LabHistoryCard: View {
    let comp: CompetitorState
    let state: GameState
    let open: (String) -> Void
    @State private var showAll = false

    var body: some View {
        let items = RivalLifecycle.feed(state, since: .distantPast, lab: comp.id, limit: 200)
        let shown = showAll ? items : Array(items.prefix(10))
        Card {
            CardHeader(title: "History", symbol: "clock.arrow.circlepath", subtitle: "Releases, rounds, strategies, takeovers and raids, newest first") {
                if items.count > 10 {
                    Button(showAll ? "Show less" : "Show all \(items.count)") { showAll.toggle() }.buttonStyle(.link)
                }
            }
            ForEach(shown) { item in
                RivalFeedRow(item: item, open: item.labID == comp.id ? nil : Optional(open))
            }
            Label("Founded \(comp.def.founded.label) in \(comp.def.hq)", systemImage: "flag.fill").font(.caption).foregroundStyle(.secondary)
        }
    }
}
