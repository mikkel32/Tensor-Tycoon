import SwiftUI

/// The business behind the labs: revenue, burn, funding rounds, IPOs and failures — and your stakes in rivals.
struct IndustryView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let live = s.competitors.filter { !$0.acquired && s.year >= $0.def.founded.decimal }
        let rivalRevenue = live.reduce(0) { $0 + $1.revenueRun }
        let yourRevenue = store.derived.runRate
        let valuations = live.reduce(0) { $0 + $1.valuation } + s.valuation
        let multiple = s.industryMultiple
        Page(title: "AI Industry", subtitle: "The money behind the models: revenue, compute bills, cash, funding rounds, IPOs and failures. Until October 2026 the rival labs raise the real rounds of the labs they're modelled on; after that, money follows the best models and the customers.") {
            HeroBanner(image: "stock_exchange", height: 150) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The AI economy").font(.title.weight(.bold))
                        Text("\(Fmt.money(rivalRevenue + yourRevenue)) a year in lab revenue · \(Fmt.money(valuations)) in valuations")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Bubble meter").font(.caption).opacity(0.8)
                        Text(Self.mood(s)).font(.system(size: 26, weight: .bold))
                    }
                }
            }
            HStack(spacing: 12) {
                StatTile(title: "Your share of lab revenue", value: Fmt.pct(yourRevenue / max(1, rivalRevenue + yourRevenue)),
                         detail: "\(Fmt.money(yourRevenue)) of \(Fmt.money(rivalRevenue + yourRevenue))", symbol: "chart.pie.fill", tint: .indigo)
                StatTile(title: "Valuation ÷ revenue", value: multiple > 0 ? "\(Int(multiple))×" : "—",
                         detail: "Independent labs with real revenue", symbol: "gauge.with.dots.needle.67percent", tint: multiple > 30 ? .orange : .teal)
                StatTile(title: "Investor mood", value: Fmt.trim(s.market.hype, 2),
                         detail: RivalEconomy.inCorrection(s) ? "Correction under way" : "AI hype index", symbol: "flame.fill",
                         tint: RivalEconomy.inCorrection(s) ? .red : .orange)
                StatTile(title: "Your stakes in rivals", value: Fmt.money(RivalEconomy.stakesValue(s)),
                         detail: "\(s.rivalStakes.count) lab\(s.rivalStakes.count == 1 ? "" : "s")", symbol: "briefcase.fill", tint: .green)
            }
            LabFinancesCard(state: s, yourRevenue: yourRevenue)
            HStack(alignment: .top, spacing: 16) {
                FundingFeedCard(state: s)
                StakesCard(state: s)
                    .frame(width: 440)
            }
            Text("Calibrated on real figures: rounds from 2019–2026, compute costs of about $1,000–1,500 per H100-equivalent a month, and multiples of 20–40× revenue that shrink as labs grow. When the money runs out, labs are sold, rescued at a discount or go bankrupt.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func mood(_ s: GameState) -> String {
        if RivalEconomy.inCorrection(s) { return "Correction" }
        let m = s.industryMultiple
        let h = s.market.hype
        if m > 35 || h > 1.6 { return "Bubble" }
        if m > 25 || h > 1.35 { return "Frothy" }
        if h < 0.9 { return "Gloomy" }
        return "Calm"
    }
}

// MARK: - The labs' books

private struct LabFinancesCard: View {
    let state: GameState
    let yourRevenue: Double

    var body: some View {
        let s = state
        let labs = s.competitors.filter { s.year >= $0.def.founded.decimal }
            .sorted { ($0.acquired ? 0 : 1, $0.revenueRun) > ($1.acquired ? 0 : 1, $1.revenueRun) }
        Card {
            CardHeader("The labs' books", symbol: "building.columns.fill", subtitle: "Annualised revenue, what investors pay for it, and how long the cash lasts")
            HStack(spacing: 8) {
                Text("Lab").frame(maxWidth: .infinity, alignment: .leading)
                Text("Revenue").frame(width: 90, alignment: .trailing)
                Text("Growth").frame(width: 64, alignment: .trailing)
                Text("Valuation").frame(width: 90, alignment: .trailing)
                Text("Multiple").frame(width: 64, alignment: .trailing)
                Text("Cash").frame(width: 84, alignment: .trailing)
                Text("Runway").frame(width: 70, alignment: .trailing)
                Text("Compute").frame(width: 80, alignment: .trailing)
                Text("Staff").frame(width: 60, alignment: .trailing)
                Text("Status").frame(width: 130, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            YourRow(state: s, revenue: yourRevenue)
            ForEach(labs) { c in LabRow(comp: c, state: s) }
        }
    }
}

private struct YourRow: View {
    let state: GameState
    let revenue: Double

    var body: some View {
        let s = state
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                CompanyLogo(symbol: s.logoSymbol, color: Theme.logoColor(s.logoColor), size: 20)
                Text("\(s.companyName) (you)").font(.callout.weight(.semibold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Fmt.money(revenue)).frame(width: 90, alignment: .trailing)
            Text("").frame(width: 64)
            Text(Fmt.money(s.valuation)).frame(width: 90, alignment: .trailing)
            Text(revenue > 1e6 ? "\(Int(s.valuation / revenue))×" : "—").frame(width: 64, alignment: .trailing)
            Text(Fmt.money(s.cash)).frame(width: 84, alignment: .trailing)
            Text(Treasury.runwayMonths(s).map { "\(Int($0)) mo" } ?? "∞").frame(width: 70, alignment: .trailing)
            Text(Fmt.count(store_h100e(s))).frame(width: 80, alignment: .trailing)
            Text("\(s.employees.count)").frame(width: 60, alignment: .trailing)
            Pill(text: s.isPublic ? "Public" : "You", color: .indigo).frame(width: 130, alignment: .trailing)
        }
        .font(.callout.monospacedDigit())
        .padding(.vertical, 4)
        .background(Color.indigo.opacity(0.08), in: .rect(cornerRadius: 6))
    }

    /// Your fleet in H100-equivalents (BF16 throughput).
    private func store_h100e(_ s: GameState) -> Double {
        s.owned.reduce(0.0) { acc, b in acc + Double(b.count) * (HardwareCatalog.get(b.accelID)?.bf16 ?? 0) / HardwareCatalog.h100.bf16 }
    }
}

private struct LabRow: View {
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let c = comp
        let s = state
        let status = RivalEconomy.status(c, s)
        let parent = RivalEconomy.parent(c, s) != nil
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(Theme.competitorColor(c.def.color)).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.def.name).font(.callout.weight(.semibold)).lineLimit(1)
                    if !c.exitNote.isEmpty {
                        Text(c.exitNote).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    } else if let r = c.lastRound {
                        Text("Last: \(r.label), \(r.date.gameShort)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(c.acquired ? "—" : Fmt.money(c.revenueRun)).frame(width: 90, alignment: .trailing)
            Text(RivalEconomy.growth(c).map { "\($0 >= 1 ? "+" : "−")\(Int(abs($0 - 1) * 100))%" } ?? "—")
                .foregroundStyle((RivalEconomy.growth(c) ?? 1) >= 1 ? Color.green : .red)
                .frame(width: 64, alignment: .trailing)
            Text(c.acquired ? "—" : Fmt.money(c.valuation)).frame(width: 90, alignment: .trailing)
            Text(!c.acquired && c.revenueRun > 1e6 ? "\(Int(c.valuation / c.revenueRun))×" : "—").frame(width: 64, alignment: .trailing)
            Text(parent || c.acquired ? "—" : Fmt.money(c.cash)).frame(width: 84, alignment: .trailing)
            Text(parent ? "Parent" : (c.acquired ? "—" : (RivalEconomy.runwayMonths(c).map { "\(Int($0)) mo" } ?? "∞")))
                .foregroundStyle((RivalEconomy.runwayMonths(c) ?? 99) < 9 && !parent && !c.acquired ? Color.orange : .primary)
                .frame(width: 70, alignment: .trailing)
            Text(c.acquired ? "—" : Fmt.count(c.computeH100e)).frame(width: 80, alignment: .trailing)
            Text(c.acquired ? "—" : "\(c.headcount)").frame(width: 60, alignment: .trailing)
            Pill(text: status, color: Self.color(status)).frame(width: 130, alignment: .trailing)
        }
        .font(.callout.monospacedDigit())
        .opacity(c.acquired ? 0.6 : 1)
        .help(c.acquired ? c.exitNote : "\(c.def.archetype). Compute bill \(Fmt.money(c.computeCostMonth))/month; total raised \(Fmt.money(c.totalRaised)).")
    }

    static func color(_ status: String) -> Color {
        switch status {
        case "Bankrupt": .red
        case "Acquired": .secondary
        case "Distressed": .orange
        case "Public": .blue
        case "Funded by parent": .purple
        case "Burning cash": .yellow
        default: .green
        }
    }
}

// MARK: - Funding rounds

private struct FeedItem: Identifiable {
    let id: UUID
    let lab: String
    let color: UInt32
    let round: RivalRound
}

private struct FundingFeedCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let since = GameCalendar.addDays(s.date, -365 * 3)
        let items = s.competitors.flatMap { c in
            c.rounds.filter { $0.date >= since }.map { FeedItem(id: $0.id, lab: c.def.name, color: c.def.color, round: $0) }
        }
        .sorted { $0.round.date > $1.round.date }
        .prefix(16)
        Card {
            CardHeader("Funding rounds", symbol: "banknote.fill", subtitle: "The last three years of raises, tenders, IPOs and rescues")
            if items.isEmpty {
                Text("No rounds yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(items)) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Theme.competitorColor(item.color)).frame(width: 8, height: 8).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(item.lab) · \(item.round.label)").font(.callout.weight(.semibold))
                        Text(Self.detail(item.round)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.round.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                }
            }
        }
    }

    static func detail(_ r: RivalRound) -> String {
        var parts: [String] = []
        if r.amount > 0 { parts.append(Fmt.money(r.amount)) }
        if r.postMoney > 0 { parts.append("at \(Fmt.money(r.postMoney))") }
        parts.append(r.kind == .ipo ? "on the public markets" : "led by \(r.lead)")
        return parts.joined(separator: " ")
    }
}

// MARK: - Your stakes

private struct StakesCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("Your stakes in rivals", symbol: "briefcase.fill", subtitle: "When a lab raises money, big players get offered a slice of the round")
            if s.rivalStakes.isEmpty {
                Text("You don't own any of your rivals. Once you're worth a billion dollars, labs that raise will offer you a slice — and if you sell compute, a big cheque comes with a deal to buy it.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(s.rivalStakes.keys.sorted(), id: \.self) { id in
                let c = s.competitors.first { $0.id == id }
                let value = RivalEconomy.stakeValue(s, id)
                let cost = s.rivalStakeCost[id] ?? 0
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(c?.def.name ?? id) · \(Fmt.pct(s.rivalStakes[id] ?? 0))").font(.callout.weight(.semibold))
                        Text("Cost \(Fmt.money(cost)) · now \(Fmt.money(value)) (\(value >= cost ? "+" : "−")\(Int(abs(value / max(1, cost) - 1) * 100))%)")
                            .font(.caption).foregroundStyle(value >= cost ? Color.green : .red)
                    }
                    Spacer()
                    Button(c?.isPublic == true ? "Sell" : "Sell (−15%)") { store.act("Stake sold") { $0.sellRivalStake(id) } }
                        .controlSize(.small)
                        .help(c?.isPublic == true ? "Sell at the market price." : "Private shares sell at a 15% discount on the secondary market.")
                }
            }
            if !s.computeCommitments.isEmpty {
                Divider()
                Text("Compute they've committed to buy from you").font(.caption.weight(.semibold))
                ForEach(s.computeCommitments) { d in
                    HStack {
                        Text(d.labName).font(.callout)
                        Spacer()
                        Text("\(Fmt.money(d.monthly))/mo · \(d.monthsLeft) mo left").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
