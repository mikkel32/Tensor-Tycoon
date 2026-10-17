import Charts
import SwiftUI

struct FinanceView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let debt = Economy.debt(s)
        let payments = s.loans.reduce(0) { $0 + $1.payment }
        let rows = Array(s.history.suffix(18).reversed())
        Page(title: "Finance", subtitle: "Profit & loss, cash and debt. Interest rates follow the real Fed funds rate until late 2026, then drift.") {
            ScreenHint(.finance)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                StatTile(title: "Cash", value: Fmt.money(s.cash), detail: s.cloudCredits > 0 ? "+ \(Fmt.money(s.cloudCredits)) cloud credits" : nil, symbol: "banknote.fill", tint: s.cash >= 0 ? .green : .red)
                StatTile(title: "Debt", value: Fmt.money(debt), detail: "\(Fmt.money(payments))/mo payments", symbol: "creditcard.fill", tint: .orange)
                StatTile(title: "Credit score", value: "\(Int(s.creditScore))", detail: rating(s.creditScore), symbol: "checkmark.seal.fill", tint: .blue)
                StatTile(title: "Fed funds rate", value: "\(Fmt.trim(Economy.fedRate(s), 2))%", detail: "Base for loan pricing", symbol: "percent", tint: .purple)
                StatTile(title: "Hardware value", value: Fmt.money(Economy.hardwareValue(s)), detail: "Resale, usable as collateral", symbol: "cpu", tint: .green)
                StatTile(title: "Lifetime revenue", value: Fmt.money(s.lifetimeRevenue), detail: "\(Fmt.flops(s.lifetimeFLOPs)) FLOPs trained", symbol: "sum", tint: .teal)
                StatTile(title: "Interest on cash", value: "\(Fmt.trim(Treasury.yieldRate(s), 2))%", detail: "Idle cash sits in T-bills · \(Fmt.money(s.cash * Treasury.yieldRate(s) / 100 / 12))/mo", symbol: "building.columns", tint: .mint)
                StatTile(title: "Runway", value: Treasury.runwayMonths(s).map { $0 > 48 ? "4+ years" : "\(Fmt.trim($0, 1)) months" } ?? (s.history.isEmpty ? "—" : "Profitable"),
                         detail: s.history.isEmpty ? "After your first month closes" : "At last month's burn", symbol: "hourglass", tint: (Treasury.runwayMonths(s) ?? 99) < 6 ? .red : .green)
                    .helpBadge(.runway)
            }

            HStack(alignment: .top, spacing: 16) {
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

            Card {
                CardHeader("This month so far", symbol: "calendar")
                let m = s.month
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 6) {
                    GridRow { Text("Revenue").bold(); Text(Fmt.money(m.revenue)).monospacedDigit().foregroundStyle(.green); Text("Costs").bold(); Text(Fmt.money(m.opex + m.costInterest)).monospacedDigit().foregroundStyle(.red) }
                    GridRow { Text("  API").foregroundStyle(.secondary); Text(Fmt.money(m.revAPI)).monospacedDigit(); Text("  Cloud rentals").foregroundStyle(.secondary); Text(Fmt.money(m.costRent)).monospacedDigit() }
                    GridRow { Text("  Consumer").foregroundStyle(.secondary); Text(Fmt.money(m.revConsumer)).monospacedDigit(); Text("  Power").foregroundStyle(.secondary); Text(Fmt.money(m.costPower)).monospacedDigit() }
                    GridRow { Text("  Enterprise").foregroundStyle(.secondary); Text(Fmt.money(m.revEnterprise)).monospacedDigit(); Text("  Payroll").foregroundStyle(.secondary); Text(Fmt.money(m.costPayroll)).monospacedDigit() }
                    GridRow { Text("  Agents").foregroundStyle(.secondary); Text(Fmt.money(m.revAgents)).monospacedDigit(); Text("  Sites & offices").foregroundStyle(.secondary); Text(Fmt.money(m.costSites)).monospacedDigit() }
                    GridRow { Text("  Compute leasing").foregroundStyle(.secondary); Text(Fmt.money(m.revCloud)).monospacedDigit(); Text("  Data & marketing").foregroundStyle(.secondary); Text(Fmt.money(m.costData + m.costMarketing)).monospacedDigit() }
                    GridRow { Text("  Chip sales").foregroundStyle(.secondary); Text(Fmt.money(m.revChips)).monospacedDigit(); Text("  Chips made for sale").foregroundStyle(.secondary); Text(Fmt.money(m.costChips)).monospacedDigit() }
                    GridRow { Text("  Agent labor").foregroundStyle(.secondary); Text(Fmt.money(m.revLabor)).monospacedDigit(); Text("  Other / fines").foregroundStyle(.secondary); Text(Fmt.money(m.costOther)).monospacedDigit() }
                    GridRow { Text("  License royalties").foregroundStyle(.secondary); Text(Fmt.money(m.revLicensing)).monospacedDigit(); Text("  Interest on debt").foregroundStyle(.secondary); Text(Fmt.money(m.costInterest)).monospacedDigit() }
                    GridRow { Text("Interest on cash").foregroundStyle(.secondary); Text(Fmt.money(m.interestIncome)).monospacedDigit().foregroundStyle(.green); Text("One-off income (license fees)").foregroundStyle(.secondary); Text(Fmt.money(m.oneOffIncome)).monospacedDigit().foregroundStyle(.green) }
                    GridRow { Text("Capex (hardware, construction)").foregroundStyle(.secondary); Text(Fmt.money(m.capex)).monospacedDigit(); Text(""); Text("") }
                }
                .font(.callout)
            }

            Card(padding: 0) {
                Table(rows) {
                    TableColumn("Month") { m in Text(m.month.gameMonth) }.width(80)
                    TableColumn("Revenue") { m in Text(Fmt.money(m.revenue)).monospacedDigit().foregroundStyle(.green) }
                    TableColumn("Compute") { m in Text(Fmt.money(m.costRent + m.costPower)).monospacedDigit() }
                    TableColumn("People") { m in Text(Fmt.money(m.costPayroll)).monospacedDigit() }
                    TableColumn("Other opex") { m in Text(Fmt.money(m.costSites + m.costData + m.costMarketing + m.costOther + m.costChips)).monospacedDigit() }
                    TableColumn("Interest + tax") { m in Text(Fmt.money(m.costInterest + m.taxes)).monospacedDigit() }
                    TableColumn("Capex") { m in Text(Fmt.money(m.capex)).monospacedDigit().foregroundStyle(.secondary) }
                    TableColumn("Profit") { m in Text(signedMoney(m.profit)).monospacedDigit().foregroundStyle(m.profit >= 0 ? .green : .red) }
                    TableColumn("Cash") { m in Text(Fmt.money(m.cashEnd)).monospacedDigit() }
                }
                .frame(minHeight: 300)
            }

            LoansCard(state: s)
        }
    }

    private func rating(_ score: Double) -> String {
        switch score {
        case 780...: "AAA-ish"
        case 720...: "A"
        case 660...: "BBB"
        case 600...: "BB"
        case 540...: "B"
        default: "CCC — distressed"
        }
    }
}

private struct LoansCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var amounts: [LoanKind: Double] = [:]

    var body: some View {
        let s = state
        Card {
            CardHeader("Debt", symbol: "building.columns", subtitle: "Borrowing is cheaper than equity when rates are low — but you must make the payments.")
            if !s.loans.isEmpty {
                ForEach(s.loans) { l in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(l.kind.rawValue).font(.callout.weight(.semibold))
                            Text("\(Fmt.money(l.balance)) of \(Fmt.money(l.principal)) left · \(Fmt.trim(l.rate, 2))% · \(Fmt.money(l.payment))/mo · \(l.monthsLeft) months")
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
                        Text(q.reason).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(width: 330, alignment: .leading)
                    if q.available && q.max > 0 {
                        let amount = amounts[q.kind] ?? q.max / 2
                        Slider(value: Binding(get: { amount }, set: { amounts[q.kind] = $0 }), in: min(q.max, 10_000)...q.max)
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
                .foregroundStyle(LinearGradient(colors: [.green.opacity(0.4), .green.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Month", m.month, unit: .month), y: .value("Cash", m.cashEnd))
                .foregroundStyle(.green)
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
                .foregroundStyle(m.profit >= 0 ? Color.green.gradient : Color.red.gradient)
        }
        .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
    }
}
