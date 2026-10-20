import SwiftUI

/// 3.9: where the money comes from and where it goes, as one list with each line's share, for a month so far,
/// the last closed month, or the last three on average.
struct MoneyFlowCard: View {
    let state: GameState
    @State private var span = 1

    private struct Line: Identifiable {
        var id: String { name }
        var name: String
        var amount: Double
        var note: String
    }

    /// The months being shown, averaged to a month.
    private var months: [MonthRecord] {
        switch span {
        case 0: [state.month]
        case 1: state.history.suffix(1).map { $0 }
        default: Array(state.history.suffix(3))
        }
    }

    private func sum(_ f: (MonthRecord) -> Double) -> Double {
        let ms = months
        return ms.isEmpty ? 0 : ms.reduce(0) { $0 + f($1) } / Double(ms.count)
    }

    var body: some View {
        let s = state
        let revenue: [Line] = [
            Line(name: "Chat subscriptions", amount: sum(\.revConsumer), note: "Paying users × price. Free users earn nothing but still use chips."),
            Line(name: "Agent seats", amount: sum(\.revAgents), note: "Seats × seat price."),
            Line(name: "API", amount: sum(\.revAPI), note: "Tokens served × your per-token price."),
            Line(name: "Enterprise contracts", amount: sum(\.revEnterprise), note: "Signed contracts, capped by the enterprise budget your rivals share."),
            Line(name: "Compute leasing", amount: sum(\.revCloud), note: "Chips you rent out."),
            Line(name: "Chip sales", amount: sum(\.revChips), note: "Accelerators you sold."),
            Line(name: "Product lines & other", amount: sum { $0.revOther + $0.revLicensing + $0.revLabor + $0.revGroup }, note: "Other products, licences, agent labour, subsidiaries."),
            // 3.9: the income the Finance P&L counts that this list used to leave out.
            Line(name: "Government contracts", amount: sum(\.revContracts), note: "Programme milestones, reimbursements and settlements: lumpy, so not in the run rate."),
            Line(name: "Interest on cash", amount: sum(\.interestIncome), note: "Idle cash in T-bills."),
            Line(name: "Board tranches & one-offs", amount: sum(\.oneOffIncome), note: "Board-goal tranches, up-front licence fees, grants and gains on stakes you sold."),
        ].filter { $0.amount > 0 }
        let cost: [Line] = [
            Line(name: "Cloud rentals", amount: sum(\.costRent), note: "Rented chips, hour by hour."),
            Line(name: "Power", amount: sum(\.costPower), note: "Electricity for your own chips."),
            Line(name: "Datacenters & offices", amount: sum(\.costSites), note: "Site fees, office rent, datacenter upkeep."),
            Line(name: "People", amount: sum(\.costPayroll), note: "Salaries of your staff."),
            Line(name: "Data & marketing", amount: sum { $0.costData + $0.costMarketing }, note: "Licensed data and your marketing budget."),
            Line(name: "Chip design programmes", amount: sum(\.costChipDesign), note: "Your own accelerators: an investment that pays back when they ship."),
            Line(name: "Agent organisations", amount: sum(\.costAgentOrgs), note: "Compute and pay for your agent organisations."),
            Line(name: "Chips made for sale", amount: sum(\.costChips), note: "Cost of goods for chips you sell."),
            Line(name: "Other: projects, lobbying, fines", amount: sum { $0.costOther + $0.costGroup }, note: "Launch costs, advanced projects, lobbying, security and legal bills, fines."),
            Line(name: "Interest on debt", amount: sum(\.costInterest), note: "Loans and bonds."),
            Line(name: "Taxes", amount: sum(\.taxes), note: "On positive monthly profit."),
        ].filter { $0.amount > 0 }
        let rev = revenue.reduce(0) { $0 + $1.amount }
        let out = cost.reduce(0) { $0 + $1.amount }
        let capex = sum(\.capex)
        Card {
            CardHeader("Where the money goes", symbol: "arrow.left.arrow.right", subtitle: "Every dollar in and out, per month, with each line's share.")
            Picker("", selection: $span) {
                Text("This month so far").tag(0)
                Text("Last month").tag(1)
                Text("Last 3 months").tag(2)
            }
            .pickerStyle(.segmented).labelsHidden()
            if months.isEmpty {
                Text("No closed months yet.").font(.callout).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 24) {
                    column("Money in", total: rev, lines: revenue, tint: .green)
                    column("Money out", total: out, lines: cost, tint: .red)
                }
                Divider()
                SpecRow(label: "Operating result", value: signed(rev - out), tone: rev >= out ? .good : .bad)
                if capex > 0 { SpecRow(label: "Plus hardware & construction (capex, not in the result)", value: Fmt.money(capex)) }
                let users = sum(\.users), paid = sum(\.paidUsers)
                if users > 0 {
                    Text("Per weekly chat user: \(Fmt.price(sum(\.revConsumer) / users))/month in subscriptions · \(Fmt.pct(paid / users)) of users pay · \(Fmt.money(out / users))/month of total costs.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if s.lostAPIMonth + sum(\.revConsumer) * s.lostChatFrac + sum(\.revAgents) * s.lostAgentFrac > rev * 0.03 {
                    Label("Chips ran short: about \(Fmt.money(s.lostAPIMonth + sum(\.revConsumer) * s.lostChatFrac + sum(\.revAgents) * s.lostAgentFrac))/month of paid requests went unserved. See Price lab on the Market page.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    private func signed(_ v: Double) -> String { (v >= 0 ? "+" : "−") + Fmt.money(abs(v)) }

    private func column(_ title: String, total: Double, lines: [Line], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.callout.weight(.semibold))
                Spacer()
                Text(Fmt.money(total)).font(.callout.weight(.semibold).monospacedDigit()).foregroundStyle(tint)
            }
            ForEach(lines.sorted { $0.amount > $1.amount }) { l in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(l.name).font(.callout)
                        Spacer()
                        Text(Fmt.money(l.amount)).font(.callout.monospacedDigit())
                        Text(Fmt.pct(l.amount / max(total, 1), decimals: 0)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                    }
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 2).fill(tint.opacity(0.55)).frame(width: max(2, g.size.width * min(1, l.amount / max(total, 1))), height: 4)
                    }
                    .frame(height: 4)
                }
                .help(l.note)
            }
            if lines.isEmpty { Text("Nothing yet.").font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
