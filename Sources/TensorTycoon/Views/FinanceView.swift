import Charts
import SwiftUI

struct FinanceView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let debt = Economy.debt(s)
        let payments = s.loans.reduce(0) { $0 + $1.payment }
        let rows = Array(s.history.suffix(18).reversed())
        let creditNotch = Corporate.notch(forCreditScore: s.creditScore)
        Page(title: "Finance", subtitle: "Profit & loss, cash and debt, taxes, what you can book and the state of the markets. Interest rates follow the real Fed funds rate until late 2026, then drift.", screen: .finance) {
            ScreenHint(.finance)
            KPIRow(minWidth: 190) {
                StatTile(title: "Cash", value: Fmt.money(s.cash), detail: s.cloudCredits > 0 ? "+ \(Fmt.money(s.cloudCredits)) cloud credits" : nil, symbol: "banknote.fill",
                         tint: s.cash >= 0 ? Theme.good : Theme.bad)
                StatTile(title: "Debt", value: Fmt.money(debt), detail: "\(Fmt.money(payments))/mo payments", symbol: "creditcard.fill", tint: Theme.warning)
                StatTile(title: "Credit score", value: "\(Int(s.creditScore))", detail: "Reads as \(Corporate.ratingName(creditNotch)) · prices every loan",
                         symbol: "checkmark.seal.fill", tint: CorpStyle.rating(creditNotch))
                StatTile(title: "Policy rate", value: "\(Fmt.trim(Economy.fedRate(s), 2))%",
                         detail: Crises.rateAdd(s) > 0 ? "Rate shock: +\(Fmt.trim(Crises.rateAdd(s), 2)) pts" : "Base for loan pricing", symbol: "percent", tint: .purple)
                StatTile(title: "Hardware value", value: Fmt.money(Economy.hardwareValue(s)), detail: "Resale · book \(Fmt.money(Books.hardwareBook(s)))", symbol: "cpu", tint: .teal)
                StatTile(title: "Lifetime revenue", value: Fmt.money(s.lifetimeRevenue), detail: "\(Fmt.flops(s.lifetimeFLOPs)) FLOPs trained", symbol: "sum", tint: .teal)
                StatTile(title: "Interest on cash", value: "\(Fmt.trim(Treasury.yieldRate(s), 2))%", detail: "Idle cash sits in T-bills · \(Fmt.money(s.cash * Treasury.yieldRate(s) / 100 / 12))/mo", symbol: "building.columns", tint: .mint)
                StatTile(title: "Runway", value: runwayText(s),
                         detail: s.history.isEmpty ? "After your first month closes" : "At last month's cash burn", symbol: "hourglass",
                         tint: (Treasury.runwayMonths(s) ?? 99) < 6 ? Theme.bad : Theme.good, help: .runway)
            }

            CardGrid(minWidth: 340, maxColumns: 2) {
                Card {
                    CardHeader("Cash balance", symbol: "chart.xyaxis.line")
                    if s.history.count < 2 {
                        Text("Charts appear after a couple of months.").font(.callout).foregroundStyle(.secondary).frame(height: 200)
                    } else {
                        CashChart(history: Array(s.history.suffix(48)))
                            .equatable()
                            .frame(height: 200)
                    }
                }
                Card {
                    CardHeader("Monthly profit", symbol: "chart.bar.fill")
                    if s.history.isEmpty {
                        Text("No closed months yet.").font(.callout).foregroundStyle(.secondary).frame(height: 200)
                    } else {
                        ProfitChart(history: Array(s.history.suffix(36)))
                            .equatable()
                            .frame(height: 200)
                    }
                }
            }

            CardGrid(minWidth: 340, maxColumns: 2) {
                ProfitMoversCard(state: s)
                BookingCard(state: s)
            }

            Card {
                CardHeader("This month so far", symbol: "calendar", subtitle: "Depreciation and taxes are booked when the month closes.")
                let m = s.month
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 6) {
                    GridRow { Text("Revenue").bold(); Text(Fmt.money(m.revenue)).monospacedDigit().foregroundStyle(Theme.good); Text("Costs").bold(); Text(Fmt.money(m.opex + m.costInterest)).monospacedDigit().foregroundStyle(Theme.bad) }
                    GridRow { Text("  API").foregroundStyle(.secondary); Text(Fmt.money(m.revAPI)).monospacedDigit(); Text("  Cloud rentals").foregroundStyle(.secondary); Text(Fmt.money(m.costRent)).monospacedDigit() }
                    GridRow { Text("  Consumer").foregroundStyle(.secondary); Text(Fmt.money(m.revConsumer)).monospacedDigit(); Text("  Power").foregroundStyle(.secondary); Text(Fmt.money(m.costPower)).monospacedDigit() }
                    GridRow { Text("  Enterprise").foregroundStyle(.secondary); Text(Fmt.money(m.revEnterprise)).monospacedDigit(); Text("  Payroll").foregroundStyle(.secondary); Text(Fmt.money(m.costPayroll)).monospacedDigit() }
                    GridRow { Text("  Agents").foregroundStyle(.secondary); Text(Fmt.money(m.revAgents)).monospacedDigit(); Text("  Sites & offices").foregroundStyle(.secondary); Text(Fmt.money(m.costSites)).monospacedDigit() }
                    GridRow { Text("  Compute leasing").foregroundStyle(.secondary); Text(Fmt.money(m.revCloud)).monospacedDigit(); Text("  Data & marketing").foregroundStyle(.secondary); Text(Fmt.money(m.costData + m.costMarketing)).monospacedDigit() }
                    GridRow { Text("  Chip sales").foregroundStyle(.secondary); Text(Fmt.money(m.revChips)).monospacedDigit(); Text("  Chips made for sale").foregroundStyle(.secondary); Text(Fmt.money(m.costChips)).monospacedDigit() }
                    GridRow { Text("  Agent labor").foregroundStyle(.secondary); Text(Fmt.money(m.revLabor)).monospacedDigit(); Text("  Other / fines").foregroundStyle(.secondary); Text(Fmt.money(m.costOther)).monospacedDigit() }
                    GridRow { Text("  License royalties").foregroundStyle(.secondary); Text(Fmt.money(m.revLicensing)).monospacedDigit(); Text("  Interest on debt").foregroundStyle(.secondary); Text(Fmt.money(m.costInterest)).monospacedDigit() }
                    GridRow { Text("  Product lines").foregroundStyle(.secondary); Text(Fmt.money(m.revOther)).monospacedDigit(); Text("  Folded-in divisions").foregroundStyle(.secondary); Text(Fmt.money(m.costGroup)).monospacedDigit() }
                    GridRow { Text("  Government contracts").foregroundStyle(.secondary); Text(Fmt.money(m.revContracts)).monospacedDigit(); Text("  Divisions' revenue").foregroundStyle(.secondary); Text(Fmt.money(m.revGroup)).monospacedDigit() }
                    GridRow { Text("Interest on cash").foregroundStyle(.secondary); Text(Fmt.money(m.interestIncome)).monospacedDigit().foregroundStyle(Theme.good); Text("One-off income (license fees)").foregroundStyle(.secondary); Text(Fmt.money(m.oneOffIncome)).monospacedDigit().foregroundStyle(Theme.good) }
                    GridRow { Text("Capex (hardware, construction)").foregroundStyle(.secondary); Text(Fmt.money(m.capex)).monospacedDigit(); Text("Gains on disposals").foregroundStyle(.secondary); Text(Fmt.signedMoney(m.assetGains)).monospacedDigit() }
                }
                .font(.callout)
                Text("Government contract milestones are revenue, but they come in lumps: they're kept out of the run rate and the revenue multiple.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Card(padding: 0) {
                Table(rows) {
                    TableColumn("Month") { m in Text(m.month.gameMonth) }.width(80)
                    TableColumn("Revenue") { m in Text(Fmt.money(m.revenue)).monospacedDigit().foregroundStyle(Theme.good) }
                    TableColumn("Compute") { m in Text(Fmt.money(m.costRent + m.costPower)).monospacedDigit() }
                    TableColumn("People") { m in Text(Fmt.money(m.costPayroll)).monospacedDigit() }
                    TableColumn("Other opex") { m in Text(Fmt.money(m.costSites + m.costData + m.costMarketing + m.costOther + m.costChips + m.costGroup)).monospacedDigit() }
                    TableColumn("Depreciation") { m in Text(Fmt.money(m.costDepreciation)).monospacedDigit().foregroundStyle(.secondary) }
                    TableColumn("Interest + tax") { m in Text(Fmt.money(m.costInterest + m.taxes)).monospacedDigit() }
                    TableColumn("Capex") { m in Text(Fmt.money(m.capex)).monospacedDigit().foregroundStyle(.secondary) }
                    TableColumn("Profit") { m in Text(signedMoney(m.profit)).monospacedDigit().foregroundStyle(m.profit >= 0 ? Theme.good : Theme.bad) }
                    TableColumn("Cash") { m in Text(Fmt.money(m.cashEnd)).monospacedDigit() }
                }
                .frame(minHeight: 300)
            }

            CardGrid(minWidth: 340, maxColumns: 2) {
                MarketsCard(state: s)
                TaxCard(state: s)
            }

            LoansCard(state: s)
        }
    }

    private func runwayText(_ s: GameState) -> String {
        guard let m = Treasury.runwayMonths(s) else { return s.history.isEmpty ? "—" : "Cash-positive" }
        return m > 48 ? "4+ years" : "\(Fmt.trim(m, 1)) months"
    }
}

// MARK: - 3.8: why profit moved

/// The biggest line-by-line moves between the last two closed months, each with its recorded cause.
private struct ProfitMoversCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let h = state.history
        Card {
            CardHeader("Why profit moved", symbol: "arrow.left.arrow.right", subtitle: "Last month against the one before, line by line: the biggest movers and what the records say caused them.")
            if h.count < 2 {
                Text("Appears once two months have closed.").font(.callout).foregroundStyle(.secondary)
            } else {
                let cur = h[h.count - 1]
                let prev = h[h.count - 2]
                let movers = Briefing.profitMovers(prev: prev, cur: cur)
                let change = cur.profit - prev.profit
                SpecRow(label: "Profit \(prev.month.gameMonth) → \(cur.month.gameMonth)",
                        value: "\(Fmt.signedMoney(prev.profit)) → \(Fmt.signedMoney(cur.profit))", tone: Tone.sign(change))
                ForEach(movers.prefix(6)) { mv in
                    Button {
                        store.open(mv.screen)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: mv.delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(mv.delta >= 0 ? Theme.good : Theme.bad)
                                .accessibilityLabel(mv.delta >= 0 ? "Helped profit" : "Hurt profit")
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mv.name).font(.callout.weight(.semibold))
                                Text(mv.cause).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Text(Fmt.signedMoney(mv.delta)).font(TypeRamp.tableNumber).foregroundStyle(mv.delta >= 0 ? Theme.good : Theme.bad)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                if movers.count > 6 {
                    Text("\(movers.count - 6) smaller moves together: \(Fmt.signedMoney(movers.dropFirst(6).reduce(0) { $0 + $1.delta })).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 3.8: go-to-market capacity

/// What your go-to-market can book this month, what limits it and what went unbooked.
private struct BookingCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let cap = Commercial.capacity(s)
        let day = max(1, GameCalendar.components(s.date).day)
        let pace = s.month.commercialRevenue / Double(day) * 30.44
        let full = pace >= cap.cap * 0.97
        Card {
            CardHeader("What you can book", symbol: "person.badge.plus",
                       subtitle: "Customers take time to find you, integrate and be looked after. API, chat, agent seats and enterprise contracts are held to both limits; demand beyond them goes unbooked.")
            SpecRow(label: "Booked this month (monthly pace)", value: "\(Fmt.money(pace))/mo", tone: full ? .warning : .neutral)
            Meter(value: pace / max(1, cap.cap), tint: full ? Theme.warning : Theme.good)
                .accessibilityLabel("Share of what you can book")
            SpecRow(label: "Ramp: best recent month +\(Fmt.pct(cap.growth, decimals: 0))", value: "\(Fmt.money(cap.ramp))/mo", tone: cap.limit == .ramp ? .warning : .neutral)
            SpecRow(label: "Team: \(Fmt.trim(Commercial.teamUnits(s), 0)) people-equivalents", value: "\(Fmt.money(cap.team))/mo", tone: cap.limit == .team ? .warning : .neutral)
            if s.month.revUnbooked > 1 {
                SpecRow(label: unbookedLabel(s), value: Fmt.money(s.month.revUnbooked), tone: .warning)
            }
            if let last = s.history.last, let line = Commercial.explanation(last) {
                Text(line).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text(rules(s, cap))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func unbookedLabel(_ s: GameState) -> String {
        let why = Commercial.Limit(rawValue: s.month.bookingLimit)?.title ?? "your limits"
        return "Unbooked so far (held back by \(why))"
    }

    private func rules(_ s: GameState, _ cap: Commercial.Capacity) -> String {
        var t = "Bookings can grow \(Fmt.pct(cap.growth, decimals: 0)) a month at your size and the market's pace (50% while small, 35% at a tenth of the market, plus the market's own growth). "
        t += "Each employee can look after about \(Fmt.money(Commercial.monthlyMarket(s) * Commercial.perHeadShare)) a month of business "
        t += "and a salesperson six times that; the amount rises with the AI market."
        return t
    }
}

// MARK: - 3.8: markets and crises

/// The bubble meter, crises under way with what they do to you, and the last one that passed.
private struct MarketsCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let m = Crises.meter(s)
        let bubble = s.corp.cycle.bubble
        let live = s.corp.cycle.active.filter { $0.end > s.date }
        Card {
            CardHeader("Markets", symbol: "chart.line.uptrend.xyaxis", subtitle: "Corrections, credit crunches and rate shocks move multiples, rounds, loan pricing and demand until they pass.")
            HStack {
                Text("Bubble meter").font(.callout.weight(.semibold))
                Spacer()
                ToneLabel(text: "\(Int(bubble))/100", tone: Tone.risk(bubble, good: 35, warning: 65), font: .callout.weight(.semibold).monospacedDigit())
            }
            Meter(value: bubble / 100, tint: Tone.risk(bubble, good: 35, warning: 65).color)
                .accessibilityLabel("Bubble meter")
            Text(meterText(m, bubble))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            if live.isEmpty {
                Label("No crisis under way", systemImage: Tone.good.symbol).font(.callout).foregroundStyle(Theme.good)
            } else {
                ForEach(live) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Label(c.kind.title, systemImage: c.kind.symbol).font(.callout.weight(.semibold))
                            Spacer()
                            Pill("Until \(c.end.gameMonth)", tone: .warning)
                        }
                        Text(c.cause).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                SpecRow(label: "Revenue multiples", value: "\(Fmt.pct(Crises.multipleFactor(s), decimals: 0)) of normal", tone: Crises.multipleFactor(s) < 1 ? .bad : .neutral)
                SpecRow(label: "Equity rounds", value: "\(Fmt.pct(Crises.roundFactor(s), decimals: 0)) of normal size", tone: Crises.roundFactor(s) < 1 ? .bad : .neutral)
                SpecRow(label: "Extra loan spread", value: "+\(Fmt.trim(Crises.spreadAdd(s), 1)) pts", tone: Crises.spreadAdd(s) > 0 ? .bad : .neutral)
                if Crises.rateAdd(s) > 0 {
                    SpecRow(label: "Rate shock on the policy rate", value: "+\(Fmt.trim(Crises.rateAdd(s), 2)) pts", tone: .warning)
                }
            }
            if let last = s.corp.cycle.past.first {
                Text("Last: \(last.kind.title.lowercased()), \(last.start.gameMonth)–\(last.end.gameMonth).").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func meterText(_ m: Crises.Meter, _ bubble: Double) -> String {
        var t = "Hype above normal \(Int(m.hype)) · industry valuation multiple \(Int(m.multiple)) · years since the last correction \(Int(m.age)). "
        t += "After the real timeline ends, a correction starts with \(Fmt.pct(Crises.correctionOdds(bubble), decimals: 1)) odds a month at this reading."
        return t
    }
}

// MARK: - 3.8: tax

/// The home rate, losses carried forward, R&D credits and what you paid.
private struct TaxCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let c = HQ.country(s)
        let year = Array(s.history.suffix(12))
        let taxes = year.reduce(0) { $0 + $1.taxes }
        let pre = year.reduce(0) { $0 + $1.profit + $1.taxes }
        Card {
            CardHeader("Tax", symbol: "percent", subtitle: "Profit is taxed at home each month, after losses carried forward and R&D credits.")
            SpecRow(label: "Corporate tax at home", value: Fmt.pct(HQ.taxRate(s), decimals: 1))
            SpecRow(label: "Losses carried forward", value: Fmt.money(s.corp.lossPool), tone: s.corp.lossPool > 0 ? .good : .neutral)
            if c.rdCredit > 0 {
                SpecRow(label: "R&D credit", value: "\(Fmt.pct(c.rdCredit, decimals: 0)) of R&D payroll, \(c.rdRefundable ? "paid out in cash" : "set against tax")")
            }
            if s.corp.creditPool > 0 {
                SpecRow(label: "R&D credits waiting for tax to offset", value: Fmt.money(s.corp.creditPool), tone: .good)
            }
            SpecRow(label: "Tax, last 12 months", value: Fmt.signedMoney(-taxes))
            SpecRow(label: "Effective rate", value: pre > 0 ? Fmt.pct(taxes / pre, decimals: 1) : "No taxable profit")
            Text(explainer(c))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func explainer(_ c: HQCountry) -> String {
        var t = "A month that loses money adds its loss to the pool, and later profit is taxed only once the pool is used up — so a loss-making year isn't taxed on its few good months."
        if c.rdCredit > 0 && !c.rdRefundable { t += " R&D credits you can't use yet wait in their own pool for profitable months." }
        return t
    }
}

private struct LoansCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var amounts: [LoanKind: Double] = [:]

    private func loanLine(_ l: Loan) -> String {
        "\(Fmt.money(l.balance)) of \(Fmt.money(l.principal)) left · \(Fmt.trim(l.rate, 2))% · \(Fmt.money(l.payment))/mo · \(l.monthsLeft) months"
    }

    var body: some View {
        let s = state
        Card {
            CardHeader("Debt", symbol: "building.columns", subtitle: "Borrowing is cheaper than equity when rates are low — but you must make the payments. Each limit is net of what you already owe of that kind.")
            if !s.loans.isEmpty {
                ForEach(s.loans) { l in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(l.kind.rawValue).font(.callout.weight(.semibold))
                            Text(loanLine(l))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Repay now") { store.act("Loan repaid") { $0.repayLoan(l.id) } }
                    }
                }
                Divider()
            }
            Text("Available financing").font(.caption.weight(.semibold))
            ForEach(Economy.loanQuotes(s), id: \.kind) { q in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(q.kind.rawValue).font(.callout.weight(.semibold))
                        Text(q.reason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 330, alignment: .leading)
                    if q.available && q.max > 0 {
                        let amount = min(amounts[q.kind] ?? q.max / 2, q.max)
                        Slider(value: Binding(get: { amount }, set: { amounts[q.kind] = $0 }), in: min(q.max, 10_000)...q.max)
                            .accessibilityValue(Fmt.money(amount))
                        Text(Fmt.money(amount)).font(.callout.monospacedDigit()).frame(width: 80)
                        Text("\(Fmt.trim(q.rate, 2))% · \(q.term) mo").font(.caption).foregroundStyle(.secondary).frame(width: 100)
                        Button("Borrow") {
                            store.act("Loan funded") { $0.takeLoan(q.kind, amount: amount, months: q.term) }
                            amounts[q.kind] = nil
                        }
                    } else {
                        Spacer()
                        Text("Unavailable").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

/// Month-end cash; redraws only when a month closes.
struct CashChart: View, Equatable {
    let history: [MonthRecord]

    var body: some View {
        Chart(history) { m in
            AreaMark(x: .value("Month", m.month, unit: .month), y: .value("Cash", m.cashEnd))
                .foregroundStyle(LinearGradient(colors: [Theme.good.opacity(0.4), Theme.good.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Month", m.month, unit: .month), y: .value("Cash", m.cashEnd))
                .foregroundStyle(Theme.good)
                .interpolationMethod(.monotone)
        }
        .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
    }
}

/// Monthly profit; redraws only when a month closes.
struct ProfitChart: View, Equatable {
    let history: [MonthRecord]

    var body: some View {
        Chart(history) { m in
            BarMark(x: .value("Month", m.month, unit: .month), y: .value("Profit", m.profit))
                .foregroundStyle(m.profit >= 0 ? Theme.good.gradient : Theme.bad.gradient)
        }
        .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
    }
}
