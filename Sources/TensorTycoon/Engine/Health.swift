import Foundation

/// 3.9: the dashboard's health strip. Five numbers that say whether the lab is working: are customers served, are your
/// chips busy, how long the cash lasts, is research fed, and what is about to cost more. Read-only, from state the game keeps.
enum Health {
    enum Tone { case good, watch, bad }

    struct Tile: Identifiable {
        var id: String
        var title: String
        var value: String
        var detail: String
        var tone: Tone
        var symbol: String
        var screen: Screen
    }

    static func tiles(_ s: GameState, pools: [ComputePool]) -> [Tile] {
        var out: [Tile] = []

        // Serving: share of demand your servers cover.
        let live = s.models.filter { $0.released && !$0.retired }
        let demand = live.reduce(0) { $0 + $1.demandTokensDay }
        if live.isEmpty && s.models.contains(where: \.released) {
            out.append(Tile(id: "serving", title: "Serving", value: "Nothing on sale", detail: "Every released model is retired, so nothing earns.",
                            tone: .bad, symbol: "cube.box.fill", screen: .models))
        } else if !live.isEmpty {
            let served = demand > 0 ? live.reduce(0) { $0 + min($1.capacityTokensDay, $1.demandTokensDay) } / demand : 1
            out.append(Tile(id: "serving", title: "Serving", value: demand > 0 ? Fmt.pct(served, decimals: 0) + " of demand" : "No demand yet",
                            detail: served < 0.95 ? "\(Fmt.count(demand * (1 - served))) tokens a day turned away." : "Every customer who asks is served.",
                            tone: served < 0.8 ? .bad : (served < 0.95 ? .watch : .good), symbol: "cube.box.fill", screen: .models))
        }

        // Compute: idle chips and what they could earn.
        let total = pools.reduce(0) { $0 + $1.total }
        if total > 0 {
            let reserve = s.ops.reserveShare
            let idle = pools.reduce(0) { $0 + max(0, $1.free - Int(Double($1.total) * reserve)) }
            let share = Double(idle) / Double(total)
            var detail = "of \(Fmt.int(total)) chips are doing nothing."
            if idle >= 64, let p = pools.filter({ $0.owned > 0 }).max(by: { $0.free < $1.free }) {
                let n = min(max(0, p.free - Int(Double(p.total) * reserve)), p.owned - (s.leases[p.accel.id] ?? 0))
                if n >= 64 { detail = "of \(Fmt.int(total)) chips idle; leasing \(Fmt.int(n)) would bring ~\(Fmt.money(ChipBusiness.leaseIncomePerDay(p.accel, count: n, s) * 30.4))/mo." }
            }
            out.append(Tile(id: "compute", title: "Compute", value: idle < 16 ? "All busy" : "\(Fmt.int(idle)) idle", detail: idle < 16 ? "\(Fmt.int(total)) chips at work or leased out." : detail,
                            tone: share > 0.25 ? .bad : (share > 0.05 ? .watch : .good), symbol: "cpu", screen: .compute))
        }

        // Cash: runway, and the debt that comes with it.
        let runway = Treasury.runwayMonths(s)
        let debt = Economy.debt(s)
        out.append(Tile(id: "cash", title: "Cash", value: Fmt.money(s.cash),
                        detail: Agenda.runwayText(s) + (debt > 0 ? " · debt \(Fmt.money(debt))" : ""),
                        tone: s.cash < 0 || (runway ?? 99) < 4 ? .bad : ((runway ?? 99) < 9 ? .watch : .good), symbol: "banknote.fill", screen: .finance))

        // Research: rate and how far compute is from the cap.
        if !s.researchQueue.isEmpty || s.autoResearch || s.rpToday > 0 {
            let chips = s.researchChips.values.reduce(0, +)
            let fed = min(1, Sim.researchPF(s.researchChips) / Sim.researchComputeCapPF)
            out.append(Tile(id: "research", title: "Research", value: "\(Fmt.trim(s.rpToday, 0)) RP/day",
                            detail: fed >= 0.9 ? "\(Fmt.int(chips)) chips on experiments: the full boost." : "\(Fmt.int(chips)) chips on experiments; \(Fmt.pct(fed, decimals: 0)) of the useful compute.",
                            tone: fed < 0.3 ? .bad : (fed < 0.9 ? .watch : .good), symbol: "lightbulb.fill", screen: .research))
        }

        // Costs on the way: leased-block rent still ramping, chips waiting for sites.
        let ramping = s.sites.filter { $0.isTermLease && $0.rampKW > 0 }
        let waiting = Economy.waitingChips(s).reduce(0) { $0 + $1.count }
        if !ramping.isEmpty {
            let now = ramping.reduce(0) { $0 + ($1.isReady(s.date) ? $1.leaseRate * $1.capacityKW : 0) }
            let full = ramping.reduce(0) { $0 + $1.leaseRate * ($1.capacityKW + $1.rampKW) }
            let lastRev = s.history.last?.revenue ?? 0
            out.append(Tile(id: "ahead", title: "Costs ahead", value: "Rent → \(Fmt.money(full))/mo",
                            detail: "\(Fmt.money(now))/mo today" + (waiting > 0 ? " · \(Fmt.int(waiting)) chips wait for a site" : "") + (lastRev > 0 ? " · \(Fmt.pct(full / lastRev, decimals: 0)) of last month's revenue" : ""),
                            tone: lastRev > 0 && full > lastRev * 0.5 ? .bad : (full > max(1, lastRev) * 0.25 ? .watch : .good), symbol: "chart.line.uptrend.xyaxis", screen: .datacenters))
        } else if waiting > 0 {
            out.append(Tile(id: "ahead", title: "Costs ahead", value: "\(Fmt.int(waiting)) chips waiting", detail: "They do no work until their datacenter opens.",
                            tone: .watch, symbol: "shippingbox.fill", screen: .datacenters))
        }
        return out
    }
}
