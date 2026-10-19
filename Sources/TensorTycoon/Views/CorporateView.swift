import Charts
import SwiftUI

// MARK: - 3.5: Corporate — statements, capital, subsidiaries and tax

enum CorporateTab: String, CaseIterable, Identifiable {
    case statements = "Statements"
    case capital = "Capital"
    case subsidiaries = "Subsidiaries"
    case tax = "Tax"
    var id: String { rawValue }
}

enum CorpStyle {
    static func rating(_ notch: Int) -> Color {
        switch notch {
        case ..<0: .secondary
        case 0...2: .green
        case 3: .teal
        case 4...5: .orange
        default: .red
        }
    }

    static func signed(_ v: Double) -> String { v < 0 ? "−\(Fmt.money(-v))" : Fmt.money(v) }

    static func multiple(_ v: Double?) -> String { v.map { "\(Fmt.trim($0, 1))×" } ?? "—" }
}

struct CorporateView: View {
    @Environment(GameStore.self) private var store
    @State private var tab: CorporateTab = .statements

    var body: some View {
        let s = store.game
        let m = Corporate.metrics(s)
        let live = s.corp.subs.filter(\.separate)
        Page(title: "Corporate",
             subtitle: "The company as a group: the monthly books, debt and its covenants, your credit rating, the cap table, taxes, and the subsidiaries you start, buy, sell down, list, spin off or fold back in.", screen: .corporate) {
            ScreenHint(.corporate)
            KPIRow {
                StatTile(title: "Credit rating", value: Corporate.ratingName(s.corp.notch >= 0 ? s.corp.notch : (m.debt > 0 ? m.notch : -1)),
                         detail: m.debt > 0 ? "Score \(Int(m.score)) · spread +\(Fmt.trim(Corporate.spreads[max(0, s.corp.notch >= 0 ? s.corp.notch : m.notch)], 2)) pts" : "Rated once you borrow",
                         symbol: "checkmark.seal.fill", tint: CorpStyle.rating(s.corp.notch >= 0 ? s.corp.notch : m.notch))
                StatTile(title: "Net debt", value: CorpStyle.signed(m.netDebt), detail: "Debt ÷ EBITDA \(CorpStyle.multiple(m.leverage)) · cover \(CorpStyle.multiple(m.coverage))",
                         symbol: "creditcard.fill", tint: m.netDebt > 0 ? .orange : .green)
                StatTile(title: "EBITDA", value: CorpStyle.signed(m.ebitda), detail: "Last 12 months (annualised while younger)", symbol: "chart.bar.doc.horizontal.fill", tint: m.ebitda >= 0 ? Theme.good : Theme.bad)
                StatTile(title: "Subsidiaries", value: "\(live.count)", detail: live.isEmpty ? "Start or buy one" : "Your stakes: \(Fmt.money(Corporate.stakesValue(s)))",
                         symbol: "square.stack.3d.up.fill", tint: .indigo)
            }
            SectionTabs(selection: $tab, options: CorporateTab.allCases)
            switch tab {
            case .statements: StatementsSection(state: s)
            case .capital: CapitalSection(state: s)
            case .subsidiaries: SubsidiariesSection(state: s)
            case .tax: TaxSection(state: s)
            }
        }
    }
}

// MARK: - Statements

private struct StatementsSection: View {
    let state: GameState
    @State private var months = 4

    var body: some View {
        let s = state
        let rows = Array(Corporate.statements(s, count: months).reversed())
        VStack(alignment: .leading, spacing: 16) {
            if rows.isEmpty {
                Card {
                    EmptyStateView(symbol: "doc.text", title: "No statements yet", message: "The first statements appear when your first month closes.", compact: true)
                }
            } else {
                HStack {
                    Text("Months shown").font(.caption).foregroundStyle(.secondary)
                    Picker("Months", selection: $months) {
                        Text("3").tag(3)
                        Text("4").tag(4)
                        Text("6").tag(6)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .labelsHidden()
                    Spacer()
                }
                Card {
                    CardHeader("Income statement", symbol: "doc.text.fill", subtitle: "Subsidiaries you control are consolidated; licence fees they pay you are eliminated.")
                    StatementGrid(rows: rows, lines: [
                        ("Revenue", { $0.revenue }, true),
                        ("  of which folded-in divisions", { $0.groupRevenue }, false),
                        ("  of which government contracts (lumpy)", { $0.contracts }, false),
                        ("Compute (rent, power, chips)", { -$0.computeCosts }, false),
                        ("People", { -$0.peopleCosts }, false),
                        ("Everything else", { -$0.otherCosts }, false),
                        ("EBITDA", { $0.ebitda }, true),
                        ("Depreciation (no cash)", { -$0.depreciation }, false),
                        ("EBIT", { $0.ebit }, true),
                        ("Interest on cash and one-offs", { $0.interestIncome + $0.oneOff }, false),
                        ("Gains and losses on disposals", { $0.assetGains }, false),
                        ("Interest on debt", { -$0.interest }, false),
                        ("Tax", { -$0.taxes }, false),
                        ("Net income (the company)", { $0.netCompany }, true),
                        ("Subsidiaries' revenue", { $0.subRevenue }, false),
                        ("Subsidiaries' costs and tax", { -($0.subCosts + $0.subTax) }, false),
                        ("Licence fees eliminated", { -$0.intercompany }, false),
                        ("Outside holders' share", { -$0.minority }, false),
                        ("Share of associates", { $0.associates }, false),
                        ("Consolidated net income", { $0.consolidatedNet }, true),
                        ("Consolidated revenue", { $0.consolidatedRevenue }, false),
                    ])
                }
                CardGrid(minWidth: 340, maxColumns: 2) {
                    Card {
                        CardHeader("Balance sheet", symbol: "scalemass.fill", subtitle: "Hardware and datacenters at book value (cost less depreciation), stakes at market. Fabs, power plants and labs aren't carried here.")
                        if rows.contains(where: { $0.balance != nil }) {
                            StatementGrid(rows: rows, lines: [
                                ("Cash", { $0.balance?.cash ?? 0 }, false),
                                ("Cloud credits", { $0.balance?.credits ?? 0 }, false),
                                ("Hardware", { $0.balance?.hardware ?? 0 }, false),
                                ("Datacenters", { $0.balance?.sites ?? 0 }, false),
                                ("Investments", { $0.balance?.investments ?? 0 }, false),
                                ("Subsidiaries' cash", { $0.balance?.subsCash ?? 0 }, false),
                                ("Your share of their value beyond cash", { $0.balance?.subsValue ?? 0 }, false),
                                ("Total assets", { $0.assets }, true),
                                ("Debt", { -$0.liabilities }, false),
                                ("Outside holders in subsidiaries", { -($0.balance?.minorityInterest ?? 0) }, false),
                                ("Equity", { $0.equity }, true),
                            ])
                        } else {
                            Text("The balance sheet is kept from the next month close on.").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    Card {
                        CardHeader("Cash flow", symbol: "arrow.left.arrow.right.circle.fill", subtitle: "Built from the month's own entries. The last line is anything they leave unexplained: it should be nothing.")
                        StatementGrid(rows: rows, lines: [
                            ("Operating (net income, depreciation added back)", { $0.operating }, true),
                            ("Capex", { -$0.capex }, false),
                            ("Assets sold", { $0.flows[.assetSales] ?? 0 }, false),
                            ("Subsidiaries", { $0.flows[.subsidiaries] ?? 0 }, false),
                            ("Stakes and acquisitions", { ($0.flows[.stakes] ?? 0) + ($0.flows[.acquisitions] ?? 0) }, false),
                            ("Investing", { $0.investing }, true),
                            ("Equity raised", { $0.flows[.equity] ?? 0 }, false),
                            ("Debt drawn", { $0.flows[.borrowing] ?? 0 }, false),
                            ("Debt repaid", { $0.flows[.repayments] ?? 0 }, false),
                            ("Dividends and buybacks", { ($0.flows[.dividends] ?? 0) + ($0.flows[.buybacks] ?? 0) }, false),
                            ("Financing", { $0.financing }, true),
                            ("Change in cash", { $0.cashChange }, true),
                            ("Unexplained", { $0.residual ?? 0 }, false),
                        ])
                    }
                }
            }
            RunwayCard(state: s)
        }
    }
}

private struct StatementGrid: View {
    let rows: [Corporate.Statement]
    let lines: [(String, (Corporate.Statement) -> Double, Bool)]

    var body: some View {
        Grid(alignment: .trailing, horizontalSpacing: 18, verticalSpacing: 5) {
            GridRow {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(rows) { r in Text(r.month.gameMonth).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
            }
            ForEach(lines.indices, id: \.self) { i in
                let line = lines[i]
                GridRow {
                    Text(line.0).font(line.2 ? .callout.weight(.semibold) : .callout).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(rows) { r in
                        let v = line.1(r)
                        Text(abs(v) < 0.5 ? "—" : CorpStyle.signed(v))
                            .font(line.2 ? .callout.weight(.semibold).monospacedDigit() : .callout.monospacedDigit())
                            .foregroundStyle(line.2 ? (v >= 0 ? Color.primary : Color.red) : (v < 0 ? Color.secondary : Color.primary))
                    }
                }
            }
        }
    }
}

private struct RunwayCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let cases = Corporate.scenarios(s)
        Card {
            CardHeader("Runway scenarios", symbol: "hourglass", subtitle: "Cash over the next two years, with your debt payments and dividends. Revenue trends from the last three months.")
            if cases.isEmpty {
                Text("Scenarios appear after your first month closes.").font(.callout).foregroundStyle(.secondary)
            } else {
                let points = cases.flatMap { c in c.cash.indices.map { (c.name, $0 + 1, c.cash[$0]) } }
                Chart(points.indices, id: \.self) { i in
                    LineMark(x: .value("Month", points[i].1), y: .value("Cash", points[i].2))
                        .foregroundStyle(by: .value("Scenario", points[i].0))
                }
                .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
                .frame(height: 200)
                ForEach(cases) { c in
                    HStack(alignment: .firstTextBaseline) {
                        Text(c.name).font(.callout.weight(.semibold)).frame(width: 44, alignment: .leading)
                        Text(c.detail).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if let z = c.zeroMonth {
                            Pill("Out of cash in \(z) months", tone: z <= 6 ? .bad : .warning)
                        } else {
                            Pill("\(Fmt.money(c.cash.last ?? 0)) in 2 years", tone: .good)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Capital

private struct CapitalSection: View {
    let state: GameState

    var body: some View {
        let s = state
        VStack(alignment: .leading, spacing: 16) {
            CardGrid(minWidth: 340, maxColumns: 2) {
                RatingCard(state: s)
                CapTableCard(state: s)
            }
            CorpDebtCard(state: s)
            PayoutsCard(state: s)
        }
    }
}

private struct RatingCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let m = Corporate.metrics(s)
        let notch = s.corp.notch >= 0 ? s.corp.notch : m.notch
        Card {
            CardHeader("Credit rating", symbol: "checkmark.seal.fill", subtitle: "Moves with leverage, interest cover, size, liquidity and — while you lose money — runway. The same score sets your credit score on the Finance page, so both always read the same letter. It prices new debt, and term loans re-price with it.")
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(s.corp.notch >= 0 || m.debt > 0 ? Corporate.ratingName(notch) : "—")
                    .font(TypeRamp.display)
                    .foregroundStyle(CorpStyle.rating(notch))
                VStack(alignment: .leading, spacing: 2) {
                    Text(Corporate.investmentGrade(notch) ? "Investment grade" : "Speculative grade").font(.callout.weight(.semibold))
                    Text("Score \(Int(m.score))/100 · spread over the policy rate +\(Fmt.trim(Corporate.spreads[max(0, notch)], 2)) pts").font(.caption).foregroundStyle(.secondary)
                }
            }
            Meter(value: m.score / 100, tint: CorpStyle.rating(notch))
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
                GridRow { Text("Debt").foregroundStyle(.secondary); Text(Fmt.money(m.debt)).monospacedDigit() }
                GridRow { Text("EBITDA (annualised)").foregroundStyle(.secondary); Text(CorpStyle.signed(m.ebitda)).monospacedDigit() }
                GridRow { Text("Debt ÷ EBITDA").foregroundStyle(.secondary); Text(CorpStyle.multiple(m.leverage)).monospacedDigit() }
                GridRow { Text("EBITDA ÷ interest").foregroundStyle(.secondary); Text(CorpStyle.multiple(m.coverage)).monospacedDigit() }
                GridRow { Text("Interest a year").foregroundStyle(.secondary); Text(Fmt.money(m.interest)).monospacedDigit() }
                GridRow { Text("Interest paid so far").foregroundStyle(.secondary); Text(Fmt.money(s.corp.interestPaid)).monospacedDigit() }
                GridRow { Text("Credit score (same scale)").foregroundStyle(.secondary); Text("\(Int(s.creditScore)) · \(Corporate.ratingName(Corporate.notch(forCreditScore: s.creditScore)))").monospacedDigit() }
            }
            .font(.callout)
        }
    }
}

private struct CapTableCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let notes = s.corp.debts.filter { $0.kind == .convertible && $0.conversionPrice > 0 }
        let noteShares = notes.reduce(0) { $0 + $1.balance / $1.conversionPrice }
        let total = s.totalShares
        let diluted = total + noteShares
        var rows: [(String, Double)] = [("You (\(s.founderName))", s.founderShares), ("Employee pool", s.employeePoolShares)]
        var holders: [String: Double] = [:]
        for h in s.holdings { holders[h.name, default: 0] += h.shares }
        rows += holders.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        if s.publicShares > 0 { rows.append(("Public float", s.publicShares)) }
        return Card {
            CardHeader("Cap table", symbol: "chart.pie.fill", subtitle: "\(Fmt.count(total)) shares\(noteShares > 0 ? " · \(Fmt.count(diluted)) fully diluted" : "") · \(Fmt.price(Corporate.pricePerShare(s))) a share")
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Holder").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Shares").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Owns").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Fully diluted").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                ForEach(rows.prefix(12), id: \.0) { r in
                    GridRow {
                        Text(r.0).lineLimit(1)
                        Text(Fmt.count(r.1)).monospacedDigit()
                        Text(Fmt.pct(r.1 / max(1, total))).monospacedDigit()
                        Text(Fmt.pct(r.1 / max(1, diluted))).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                if noteShares > 0 {
                    GridRow {
                        Text("Convertible notes (if converted)").foregroundStyle(.secondary)
                        Text(Fmt.count(noteShares)).monospacedDigit().foregroundStyle(.secondary)
                        Text("—").foregroundStyle(.secondary)
                        Text(Fmt.pct(noteShares / max(1, diluted))).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout)
        }
    }
}

private struct CorpDebtCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var amounts: [CorpDebtKind: Double] = [:]

    /// Balance, coupon and term, plus what kind of debt it is: conversion price, the rating it's priced at, breaches so far.
    private func debtLine(_ d: CorpDebt) -> String {
        var t = "\(Fmt.money(d.balance)) of \(Fmt.money(d.principal)) · \(Fmt.trim(d.rate + d.penalty, 2))% · \(d.monthsLeft) months left"
        if d.kind == .convertible { t += " · converts at \(Fmt.price(d.conversionPrice))" }
        if d.kind == .termLoan { t += " · priced at \(Corporate.ratingName(d.notch))" }
        if d.breaches > 0 { t += " · \(d.breaches) covenant breach" + (d.breaches == 1 ? "" : "es") + " so far" }
        return t
    }

    var body: some View {
        let s = state
        let m = Corporate.metrics(s)
        Card {
            CardHeader("Corporate debt", symbol: "building.columns.fill",
                       subtitle: "Covenanted bank loans, convertible notes and green bonds. Bank, GPU-backed and venture loans are on the Finance page (\(Fmt.money(s.loans.reduce(0) { $0 + $1.balance })) owed).")
            ForEach(s.corp.debts) { d in
                let why = Corporate.breaches(d, s, m)
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: d.kind.symbol).foregroundStyle(.secondary).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(d.kind.title).font(.callout.weight(.semibold))
                            if !why.isEmpty { Pill("In breach", tone: .bad) }
                            if let w = d.waiverUntil, w > s.date { Pill(text: "Waiver to \(w.gameShort)", color: .orange) }
                            if d.penalty > 0 { Pill(text: "+\(Fmt.trim(d.penalty, 1)) pts penalty", color: .orange) }
                        }
                        Text(debtLine(d))
                            .font(.caption).foregroundStyle(.secondary)
                        if !why.isEmpty {
                            Text(why.joined(separator: "; ").capitalizedFirst).font(.caption).foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    if d.kind == .convertible {
                        Button("Convert") { store.act("Note converted") { $0.convertNote(d.id) } }
                            .disabled(Corporate.pricePerShare(s) < d.conversionPrice)
                    }
                    Button(d.kind == .greenBond ? "Call (102%)" : "Repay") { store.act("Debt repaid") { $0.repayCorporateDebt(d.id) } }
                }
            }
            if !s.corp.debts.isEmpty { Divider() }
            Text("Borrow").font(.caption.weight(.semibold))
            ForEach(Corporate.quotes(s), id: \.kind) { q in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(q.kind.title).font(.callout.weight(.semibold))
                        Text(q.reason).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text("Covenants: \(q.covenants)").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .frame(width: 380, alignment: .leading)
                    if q.available && q.max > 0 {
                        let amount = min(amounts[q.kind] ?? q.max / 2, q.max)
                        Slider(value: Binding(get: { amount }, set: { amounts[q.kind] = $0 }), in: min(q.max, 1e6)...q.max)
                            .accessibilityValue(Fmt.money(amount))
                        Text(Fmt.money(amount)).font(.callout.monospacedDigit()).frame(width: 80)
                        Text("\(Fmt.trim(q.rate, 2))% · \(q.term / 12) yrs").font(.caption).foregroundStyle(.secondary).frame(width: 90)
                        Button("Borrow") {
                            store.act("Funds received") { $0.borrowCorporate(q.kind, amount: amount) }
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

private struct PayoutsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var dividend = 0.0
    @State private var buyback = 0.0
    @State private var tender = 0.1

    var body: some View {
        let s = state
        Card {
            CardHeader("Shareholder returns and secondaries", symbol: "arrow.uturn.backward.circle.fill",
                       subtitle: s.isPublic ? "Dividends are paid at each quarter's close; your own shares earn their slice. Buybacks cancel shares and raise everyone's stake."
                                            : "Before the IPO, employees can sell part of their equity to new investors in a tender offer.")
            if s.isPublic {
                let profit = max(0, s.history.suffix(3).reduce(0) { $0 + $1.profit })
                let maxDividend = max(1e6, s.cash * 0.05)
                HStack {
                    Text("Quarterly dividend")
                    Slider(value: Binding(get: { min(dividend == 0 ? s.corp.dividendQuarterly : dividend, maxDividend) }, set: { dividend = $0 }), in: 0...maxDividend)
                    let q = min(dividend == 0 ? s.corp.dividendQuarterly : dividend, maxDividend)
                    Text("\(Fmt.money(q)) · \(Fmt.price(q / max(1, s.totalShares)))/share").font(.callout.monospacedDigit()).frame(width: 190)
                    Button(s.corp.dividendQuarterly > 0 ? "Change" : "Declare") { store.act("Dividend set") { $0.setDividend(quarterly: q) } }
                    if s.corp.dividendQuarterly > 0 { Button("Cancel") { store.act("Dividend cancelled") { $0.setDividend(quarterly: 0) } } }
                }
                Text("Now \(Fmt.money(s.corp.dividendQuarterly)) a quarter · last quarter's profit \(CorpStyle.signed(profit)) · paid so far \(Fmt.money(s.corp.dividendsPaid)). Skipped (and the stock punished) if cash falls below twice the payout.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                let room = s.buybackRoom * s.sharePrice * 1.02
                if let why = s.buybackBlocker {
                    Label(why, systemImage: "clock").font(.callout).foregroundStyle(.secondary)
                } else {
                    let top = max(1e6, min(room, s.cash * 0.8))
                    HStack {
                        Text("Buy back")
                        Slider(value: Binding(get: { min(buyback == 0 ? top / 4 : buyback, top) }, set: { buyback = $0 }), in: min(top, 1e6)...top)
                        let a = min(buyback == 0 ? top / 4 : buyback, top)
                        Text("\(Fmt.money(a)) ≈ \(Fmt.count(a / (s.sharePrice * 1.02))) shares").font(.callout.monospacedDigit()).frame(width: 190)
                        Button("Buy back") { store.act("Shares bought back") { $0.buyback(amount: a) } }
                    }
                    Text("At a 2% premium to \(Fmt.price(s.sharePrice)); at most 10% of the shares a year and one buyback a month. Spent so far \(Fmt.money(s.corp.buybacksSpent)).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if let why = s.tenderBlocker {
                Label(why, systemImage: "clock").font(.callout).foregroundStyle(.secondary)
            } else {
                let price = s.valuation / max(1, s.totalShares) * 0.9
                HStack {
                    Text("Tender offer")
                    Slider(value: $tender, in: 0.05...0.3, step: 0.01)
                    Text("\(Fmt.pct(tender, decimals: 0)) of the pool ≈ \(Fmt.money(s.employeePoolShares * tender * price))").font(.callout.monospacedDigit()).frame(width: 220)
                    Button("Run it") { store.act("Tender offer done") { $0.tenderOffer(fraction: tender) } }
                }
                Text("Employees sell at \(Fmt.price(price)) a share (10% under the mark). The company gets no cash; everyone's morale +8. Once a year.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Subsidiaries

private struct SubsidiariesSection: View {
    let state: GameState

    var body: some View {
        let s = state
        let live = s.corp.subs.filter(\.live)
        let gone = s.corp.subs.filter { !$0.live }
        VStack(alignment: .leading, spacing: 16) {
            if live.isEmpty {
                Card {
                    EmptyStateView(symbol: "square.stack.3d.up", title: "No subsidiaries yet",
                                   message: "Start one with your own cash, or buy a startup below. Each has its own P&L, CEO, people and valuation; you can sell part of it, list it, spin it off or fold it back in.",
                                   compact: true)
                }
            }
            ForEach(live) { sub in SubsidiaryCard(state: s, sub: sub) }
            CardGrid(minWidth: 340, maxColumns: 2) {
                StartSubsidiaryCard(state: s)
                TargetsCard(state: s)
            }
            if !gone.isEmpty {
                Card {
                    CardHeader("Former subsidiaries", symbol: "archivebox.fill")
                    ForEach(gone) { sub in
                        HStack {
                            Text(sub.name).font(.callout)
                            Pill(text: sub.status.title)
                            Spacer()
                            Text(sub.statusDate?.gameShort ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct SubsidiaryCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let sub: Subsidiary
    @State private var sell = 0.1
    @State private var inject = 0.0
    @State private var confirmSpin = false

    var body: some View {
        let s = state
        let j = Corporate.jurisdiction(sub.country)
        let last = sub.last
        let year = Array(sub.history.suffix(12))
        let risk = Corporate.auditRisk(sub, s)
        Card {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: sub.kind.symbol).foregroundStyle(.indigo)
                Text(sub.name).font(.headline)
                Pill(text: sub.kind.title, color: .indigo)
                Text("\(j.flag) \(j.name)").font(.caption).foregroundStyle(.secondary)
                if sub.isPublic { Pill("Listed", tone: .good) }
                if sub.status == .folded { Pill(text: "Folded in", color: .teal) }
                if sub.acquired { Pill(text: "Acquired", color: .purple) }
                if sub.separate && sub.cash < 0 { Pill("Out of cash", tone: .bad) }
                Spacer()
                Text("CEO \(sub.ceo) · skill \(Int(sub.ceoSkill))").font(.caption).foregroundStyle(.secondary)
            }
            KPIRow {
                StatTile(title: "Your stake", value: sub.separate ? Fmt.pct(sub.stake) : "100%", detail: sub.separate ? "Worth \(Fmt.money(sub.stake * sub.valuation))" : "A division now",
                         symbol: "chart.pie.fill", tint: .indigo)
                StatTile(title: "Revenue", value: "\(Fmt.money(last?.revenue ?? 0))/mo", detail: "\(sub.headcount) people", symbol: "dollarsign.circle.fill", tint: .green)
                StatTile(title: "Net income", value: CorpStyle.signed(last?.profit ?? 0), detail: "Fee to you \(Fmt.money(last?.license ?? 0)) · tax \(Fmt.money(last?.tax ?? 0))",
                         symbol: "chart.bar.fill", tint: (last?.profit ?? 0) >= 0 ? .green : .red)
                if sub.separate {
                    StatTile(title: "Valuation", value: Fmt.money(sub.valuation), detail: "Cash \(CorpStyle.signed(sub.cash))", symbol: "building.columns.fill", tint: .purple)
                }
            }
            if let effect = Corporate.effectLine(sub, s) {
                Label(effect, systemImage: sub.kind.symbol).font(.caption).foregroundStyle(.secondary)
            }
            if year.count >= 2 {
                Chart(year, id: \.month) { p in
                    LineMark(x: .value("Month", p.month, unit: .month), y: .value("Amount", p.revenue)).foregroundStyle(by: .value("Line", "Revenue"))
                    LineMark(x: .value("Month", p.month, unit: .month), y: .value("Amount", p.profit)).foregroundStyle(by: .value("Line", "Net income"))
                }
                .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
                .frame(height: 110)
            }
            HStack {
                Text("Strategy").frame(width: 90, alignment: .leading)
                Text("Cash").font(.caption).foregroundStyle(.secondary)
                Slider(value: Binding(get: { sub.strategy }, set: { v in store.mutate { $0.setSubsidiaryStrategy(sub.id, v) } }), in: 0...1)
                Text("Growth").font(.caption).foregroundStyle(.secondary)
            }
            Text(sub.strategy < 0.35 ? "Hires just behind revenue and spends little on marketing: profitable, slower." : (sub.strategy > 0.65 ? "Hires well ahead of revenue and spends on marketing: fast growth, losses." : "Balanced hiring and marketing."))
                .font(.caption).foregroundStyle(.secondary)
            if sub.separate {
                HStack {
                    Text("Licence fee").frame(width: 90, alignment: .leading)
                    Slider(value: Binding(get: { sub.transferRate }, set: { v in store.mutate { $0.setTransferRate(sub.id, (v * 100).rounded() / 100) } }), in: 0...0.5)
                    Text("\(Fmt.pct(sub.transferRate, decimals: 0)) of its revenue").font(.callout.monospacedDigit()).frame(width: 150)
                }
                Text("The transfer price for your models: higher moves profit to \(Corporate.jurisdiction(Corporate.homeID(s)).name) (\(Fmt.pct(Corporate.jurisdiction(Corporate.homeID(s)).tax, decimals: 0)) tax), lower leaves it in \(j.name) (\(Fmt.pct(j.tax, decimals: 0)))."
                     + (risk > 0 ? " Outside the \(Fmt.pct(Corporate.armsLength.lowerBound, decimals: 0))–\(Fmt.pct(Corporate.armsLength.upperBound, decimals: 0)) arm's-length range: about a \(Fmt.pct(risk, decimals: 0)) chance of an audit each month." : ""))
                    .font(.caption).foregroundStyle(risk > 0 ? .orange : .secondary)
                Divider()
                HStack(spacing: 10) {
                    let amount = inject > 0 ? inject : max(1e6, sub.revenue * 6)
                    Button("Put in \(Fmt.money(amount))") { store.act("Funds sent") { $0.injectSubsidiary(sub.id, amount: amount) } }
                    Button("Raise \(Fmt.money(sub.valuation * 0.2)) outside") { store.act("Round closed") { $0.raiseForSubsidiary(sub.id, amount: sub.valuation * 0.2) } }
                        .disabled(sub.revenue <= 0)
                    Button("New CEO") { store.act("CEO replaced") { $0.replaceSubsidiaryCEO(sub.id) } }
                    Spacer()
                    Button("Wind down") { store.act("Wound down") { $0.windDownSubsidiary(sub.id) } }
                }
                HStack(spacing: 10) {
                    Text("Sell")
                    Slider(value: $sell, in: 0.05...max(0.06, sub.stake), step: 0.05)
                        .frame(width: 160)
                    Text("\(Fmt.pct(min(sell, sub.stake), decimals: 0)) ≈ \(Fmt.money(min(sell, sub.stake) * sub.valuation * (sub.isPublic ? 0.97 : 0.85)))").font(.callout.monospacedDigit())
                    Button("Sell to investors") { store.act("Stake sold") { $0.sellSubsidiaryStake(sub.id, fraction: min(sell, sub.stake)) } }
                    Spacer()
                    let ipoWhy = s.subsidiaryIPOBlocker(sub)
                    Button("IPO") { store.act("Listed!") { $0.ipoSubsidiary(sub.id) } }
                        .disabled(ipoWhy != nil)
                        .help(ipoWhy ?? "Sell 20% new shares to the public.")
                    Button("Spin off") { confirmSpin = true }
                        .confirmationDialog("Spin off \(sub.name)?", isPresented: $confirmSpin, titleVisibility: .visible) {
                            Button("Give \(Fmt.money(sub.stake * sub.valuation)) of shares to your shareholders") { store.act("Spun off") { $0.spinOffSubsidiary(sub.id) } }
                        }
                    Button("Fold in (\(Fmt.money(s.foldInCost(sub))))") { store.act("Folded in") { $0.foldInSubsidiary(sub.id) } }
                }
                if !sub.holders.isEmpty {
                    Text("Other holders: " + sub.holders.sorted { $0.stake > $1.stake }.map { "\($0.name) \(Fmt.pct($0.stake))" }.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct StartSubsidiaryCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var kind: SubsidiaryKind = .consulting
    @State private var country = ""
    @State private var seedMultiple = 1.5

    var body: some View {
        let s = state
        let home = Corporate.homeID(s)
        let place = kind == .regional ? (country.isEmpty || country == home ? (Corporate.jurisdictions.first { $0.id != home }?.id ?? "uk") : country) : (country.isEmpty ? home : country)
        let minSeed = Corporate.minSeed(kind, s, country: place)
        let seed = (minSeed * seedMultiple / 100_000).rounded() * 100_000
        let why = s.subsidiaryBlocker(kind, country: place)
        Card {
            CardHeader("Start a subsidiary", symbol: "plus.square.on.square", subtitle: "Your cash, your models, its own CEO and books.")
            Picker("Business", selection: $kind) {
                ForEach(SubsidiaryKind.allCases) { k in Text(k.title).tag(k) }
            }
            Text(kind.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker("Incorporated in", selection: Binding(get: { place }, set: { country = $0 })) {
                ForEach(Corporate.jurisdictions) { j in Text("\(j.flag) \(j.name) · \(Fmt.pct(j.tax, decimals: 0)) tax").tag(j.id) }
            }
            HStack {
                Text("Seed")
                Slider(value: $seedMultiple, in: 1...4)
                Text(Fmt.money(seed)).font(.callout.monospacedDigit()).frame(width: 80)
            }
            Text("At least \(Fmt.money(minSeed)): 18 months of a \(kind.baseTeam)-person team plus set-up. Margin before people \(Fmt.pct(kind.grossMargin, decimals: 0)), valued at about \(Fmt.trim(kind.multiple, 1))× revenue when it grows 80% a year at break-even — faster growth and fatter margins raise that, losses lower it.")
                .font(.caption).foregroundStyle(.secondary)
            if let why { Label(why, systemImage: "info.circle").font(.caption).foregroundStyle(.orange) }
            Button("Start it") { store.act("Subsidiary started") { $0.startSubsidiary(kind, country: place, seed: seed) } }
                .buttonStyle(.borderedProminent)
                .disabled(why != nil || seed > s.cash)
        }
    }
}

private struct TargetsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let targets = Corporate.targets(s)
        Card {
            CardHeader("Startups for sale", symbol: "cart.fill", subtitle: "A new list each quarter. Buy one and it runs as your subsidiary under its own CEO.")
            if targets.isEmpty { Text("Nothing for sale this quarter.").font(.callout).foregroundStyle(.secondary) }
            ForEach(targets) { t in
                let j = Corporate.jurisdiction(t.country)
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: t.kind.symbol).foregroundStyle(.secondary).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(t.name) · \(t.kind.title)").font(.callout.weight(.semibold))
                        Text("\(j.flag) \(j.name) · \(Fmt.money(t.revenue))/mo revenue (+\(Fmt.pct(t.revenue / max(1, t.prevRevenue) - 1, decimals: 0)) in 3 months) · \(t.headcount) people · CEO \(t.ceo) (\(Int(t.ceoSkill)))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Buy for \(Fmt.money(t.price))") { store.act("Acquired") { $0.acquireSubsidiary(t.id) } }
                        .disabled(t.price > s.cash || s.subsidiaryBlocker(t.kind, country: t.country) != nil)
                }
            }
        }
    }
}

// MARK: - Tax

private struct TaxSection: View {
    let state: GameState

    var body: some View {
        let s = state
        let home = Corporate.jurisdiction(Corporate.homeID(s))
        let c = HQ.country(s)
        let year = Array(s.history.suffix(12))
        let taxes = year.reduce(0) { $0 + $1.taxes }
        let pre = year.reduce(0) { $0 + max(0, $1.profit + $1.taxes) }
        let subs = s.corp.subs.filter { $0.live }
        VStack(alignment: .leading, spacing: 16) {
            KPIRow {
                StatTile(title: "Home", value: "\(home.flag) \(Fmt.pct(HQ.taxRate(s), decimals: 1))", detail: "Corporate tax in \(home.name)", symbol: "building.columns.fill", tint: .blue)
                StatTile(title: "R&D credit", value: c.rdCredit > 0 ? Fmt.pct(c.rdCredit, decimals: 0) : "None", detail: c.rdCredit > 0 ? "\(c.rdRefundable ? "Refundable" : "Against tax") · \(Fmt.money(s.hq.rdCredits)) so far" : "No research credit at home",
                         symbol: "flask.fill", tint: .teal)
                StatTile(title: "Tax, last 12 months", value: CorpStyle.signed(taxes), detail: pre > 0 ? "Effective rate \(Fmt.pct(taxes / pre, decimals: 1))" : "No taxable profit", symbol: "percent", tint: .orange)
                StatTile(title: "Audits settled", value: Fmt.money(s.corp.auditsSettled), detail: "Transfer-pricing disputes", symbol: "doc.badge.gearshape.fill", tint: .red)
            }
            Card {
                CardHeader("Tax by month", symbol: "chart.bar.fill", subtitle: "Taxes on monthly profit after the R&D credit (negative when a refundable credit pays out).")
                if year.isEmpty {
                    Text("No closed months yet.").font(.callout).foregroundStyle(.secondary)
                } else {
                    Chart(year) { m in
                        BarMark(x: .value("Month", m.month, unit: .month), y: .value("Tax", m.taxes))
                            .foregroundStyle(m.taxes >= 0 ? Color.orange.gradient : Color.green.gradient)
                    }
                    .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
                    .frame(height: 160)
                }
            }
            Card {
                CardHeader("Subsidiaries and transfer pricing", symbol: "globe", subtitle: "Each pays tax where it's incorporated. Its licence fee to you is taxed at home: keep it in the \(Fmt.pct(Corporate.armsLength.lowerBound, decimals: 0))–\(Fmt.pct(Corporate.armsLength.upperBound, decimals: 0)) range or invite an audit.")
                if subs.isEmpty {
                    Text("No subsidiaries.").font(.callout).foregroundStyle(.secondary)
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
                        GridRow {
                            ForEach(["Subsidiary", "Where", "Rate", "Revenue (12 mo)", "Fee to you", "Its tax", "Fee rate", "Audit risk"], id: \.self) { h in
                                Text(h).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                        }
                        ForEach(subs) { sub in
                            let j = Corporate.jurisdiction(sub.country)
                            let h = sub.history.suffix(12)
                            let risk = Corporate.auditRisk(sub, s)
                            GridRow {
                                Text(sub.name).lineLimit(1)
                                Text("\(j.flag) \(j.name)")
                                Text(sub.status == .folded ? "home" : Fmt.pct(j.tax, decimals: 1)).monospacedDigit()
                                Text(Fmt.money(h.reduce(0) { $0 + $1.revenue })).monospacedDigit()
                                Text(Fmt.money(h.reduce(0) { $0 + $1.license })).monospacedDigit()
                                Text(Fmt.money(h.reduce(0) { $0 + $1.tax })).monospacedDigit()
                                Text(sub.separate ? Fmt.pct(sub.transferRate, decimals: 0) : "—").monospacedDigit()
                                    .foregroundStyle(Corporate.armsLength.contains(sub.transferRate) || !sub.separate ? Color.primary : Color.orange)
                                Text(risk > 0 ? "\(Fmt.pct(risk, decimals: 1))/mo" : "—").monospacedDigit().foregroundStyle(risk > 0 ? .orange : .secondary)
                            }
                        }
                    }
                    .font(.callout)
                }
            }
        }
    }
}

// MARK: - Dashboard card

struct CorporateCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let m = Corporate.metrics(s)
        let subs = s.corp.subs.filter(\.separate)
        let waiting = s.decisions.filter { $0.kind.hasPrefix("corp_") }.count
        let base = Corporate.scenarios(s).first
        Card {
            CardHeader(title: "Corporate", symbol: "building.2.crop.circle") {
                Button("Corporate") { store.open(.corporate) }.buttonStyle(.link)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rating").font(.caption).foregroundStyle(.secondary)
                    Text(s.corp.notch >= 0 ? Corporate.ratingName(s.corp.notch) : "—").font(.title3.weight(.semibold)).foregroundStyle(CorpStyle.rating(s.corp.notch))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Net debt").font(.caption).foregroundStyle(.secondary)
                    Text(CorpStyle.signed(m.netDebt)).font(.title3.weight(.semibold).monospacedDigit())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Runway (base)").font(.caption).foregroundStyle(.secondary)
                    Text(base.map { $0.zeroMonth.map { "\($0) months" } ?? "2+ years" } ?? "—").font(.title3.weight(.semibold))
                        .foregroundStyle((base?.zeroMonth ?? 99) <= 6 ? .red : .primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subsidiaries").font(.caption).foregroundStyle(.secondary)
                    Text(subs.isEmpty ? "None" : "\(subs.count) · \(Fmt.money(Corporate.stakesValue(s)))").font(.title3.weight(.semibold).monospacedDigit())
                }
                Spacer()
            }
            if waiting > 0 {
                Label("\(waiting) corporate decision\(waiting == 1 ? "" : "s") in your inbox", systemImage: "tray.full.fill").font(.callout).foregroundStyle(.orange)
            } else if let line = s.corp.log.first {
                Text(line).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}
