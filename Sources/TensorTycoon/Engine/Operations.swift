import Foundation

/// The delegates you hand the chores to. Each one runs a recurring job — serving capacity, launches, renewals,
/// leasing, hiring, pay, enterprise leads — and is only as good as the model running it: an early model runs
/// coarse scripts once a week, a frontier agent manages the company every day and barely misses.
struct OpsPolicy: Codable, Hashable {
    /// Keep every live model's serving capacity in line with its demand.
    @D var autoscale: Bool = false
    /// Utilisation the capacity delegate aims for (0 = 0.8).
    @D var targetUtil: Double = 0
    /// Share of each chip pool kept free for training and research (0 = 0.15).
    @D var reserve: Double = 0
    /// Release finished models that beat your best, move products and contracts onto them, retire dead models.
    @D var autoLaunch: Bool = false
    /// Renew reserved cloud capacity before it ends.
    @D var autoRenew: Bool = false
    /// Lease idle owned chips to the market.
    @D var leaseIdle: Bool = false
    /// Hire to fill staffing gaps within a monthly budget.
    @D var autoHire: Bool = false
    /// New payroll the hiring delegate may add per month (0 = automatic).
    @D var hireBudget: Double = 0
    /// Keep pay near the market so people don't leave.
    @D var autoRaises: Bool = false
    /// Accept enterprise leads you can serve.
    @D var autoLeads: Bool = false
    /// Plan and start the next frontier run on idle chips when it would beat your best model.
    @D var autoTrain: Bool = false
    /// Monthly cloud rent the capacity delegate may take on when your own chips can't carry demand (0 = never rents).
    @D var rentBudget: Double = 0
    /// The on-demand rentals the capacity delegate took out: it only ever gives back its own.
    @D var delegateRentals: Set<UUID> = []

    /// 3.9: where idle chips go first: 0 = research (up to the cap that still helps), then lease; 1 = lease only.
    @D var idleFirst: Int = 0
    /// 3.9: chip types whose lease you set by hand on Chip sales: the leasing delegate stops leasing more of them.
    @D var handLeased: Set<String> = []
    /// 3.9: what each delegate has done: actions taken and dollars it committed (rent, payroll a year, deals signed a month).
    @D var tally: [String: Int] = [:]
    @D var moved: [String: Double] = [:]

    /// 3.9: the safe set. Nothing here spends cash on its own (hiring and cloud rent stay your call).
    static var recommended: OpsPolicy {
        var o = OpsPolicy()
        o.autoscale = true; o.autoLaunch = true; o.autoRenew = true; o.leaseIdle = true
        o.autoRaises = true; o.autoLeads = true; o.autoTrain = true
        return o
    }

    var target: Double { targetUtil > 0 ? targetUtil : 0.8 }
    var reserveShare: Double { reserve > 0 ? reserve : 0.15 }
    var anyOn: Bool { autoscale || autoLaunch || autoRenew || leaseIdle || autoHire || autoRaises || autoLeads || autoTrain }
}

extension OpsPolicy: DefaultValue {
    static var defaultValue: OpsPolicy { OpsPolicy() }
}

enum Operations {
    struct Competence {
        var model: String?
        var tier: String
        /// Acts every this many days.
        var everyDays: Int
        /// 0.6 (scripts) … 1 (frontier agent): how close to the right answer it gets.
        var precision: Double
        var summary: String
    }

    /// Your delegates run on your best model. Better models act more often and more precisely.
    static func competence(_ s: GameState) -> Competence {
        guard let m = s.models.filter({ !$0.retired }).max(by: { Swarms.quality($0, s) < Swarms.quality($1, s) }) else {
            return Competence(model: nil, tier: "Scripts", everyDays: 7, precision: 0.6,
                              summary: "Simple scripts you wrote yourself: they act once a week and play it safe.")
        }
        let q = Swarms.quality(m, s)
        switch q {
        case ..<0.02:
            return Competence(model: m.name, tier: "Scripts", everyDays: 7, precision: 0.6,
                              summary: "\(m.name) can't run a company yet, so your scripts do: once a week, cautiously.")
        case ..<0.2:
            return Competence(model: m.name, tier: Swarms.tier(q), everyDays: 3, precision: 0.8,
                              summary: "\(m.name) runs the chores every few days and sometimes leaves capacity on the table.")
        case ..<0.6:
            return Competence(model: m.name, tier: Swarms.tier(q), everyDays: 2, precision: 0.9,
                              summary: "\(m.name) runs operations every other day, close to how a good ops team would.")
        default:
            return Competence(model: m.name, tier: Swarms.tier(q), everyDays: 1, precision: 1,
                              summary: "\(m.name) runs operations every day and barely misses.")
        }
    }

    static func log(_ s: inout GameState, _ text: String) {
        s.opsLog.insert("\(s.date.gameShort) · \(text)", at: 0)
        if s.opsLog.count > 150 { s.opsLog.removeLast(s.opsLog.count - 150) }
    }

    /// 3.9: a logged action that counts toward the delegate's tally and the money it moved.
    static func note(_ s: inout GameState, _ who: String, _ text: String, money: Double = 0) {
        s.ops.tally[who, default: 0] += 1
        s.ops.moved[who, default: 0] += money
        log(&s, text)
    }

    /// Runs right after the daily rebalance, before training and serving.
    static func daily(_ s: inout GameState, _ b: ResearchBonuses) {
        guard s.ops.anyOn else { return }
        let comp = competence(s)
        let day = Int(s.date.timeIntervalSince1970 / 86_400)
        guard day % comp.everyDays == 0 else { return }
        if s.ops.autoLaunch { autoLaunch(&s) }
        if s.ops.autoscale {
            autoscale(&s, b, precision: comp.precision)
            freeTrainingChips(&s, b)
            releaseRentals(&s)
        }
        // Training before leasing: your next model gets first call on idle chips.
        if s.ops.autoTrain { autoTrain(&s, precision: comp.precision) }
        if s.ops.autoRenew { autoRenew(&s) }
        if s.ops.leaseIdle { leaseIdle(&s) }
        if s.ops.autoLeads { autoLeads(&s) }
        // People: weekly is plenty.
        if day % 7 == 0 {
            if s.ops.autoHire { autoHire(&s, precision: comp.precision) }
            if s.ops.autoRaises { autoRaises(&s) }
        }
    }

    // MARK: Capacity

    /// Tokens per day one chip of `accelID` serves for model `m`, and the replica size.
    static func perChip(_ m: AIModel, _ accelID: String, _ b: ResearchBonuses) -> (Double, Int)? {
        guard let a = HardwareCatalog.get(accelID) else { return nil }
        let k = Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b)
        let cap = Physics.capacity(m, deployment: Deployment(accelID: accelID, chips: k), bonuses: b)
        guard cap > 0 else { return nil }
        return (cap / Double(k), k)
    }

    static func autoscale(_ s: inout GameState, _ b: ResearchBonuses, precision: Double) {
        let target = s.ops.target
        let reserve = s.ops.reserveShare
        // Scripts under-provision a little; a frontier agent hits the target.
        let aim = target / (1 - (1 - precision) * 0.25)
        let order = s.models.indices.filter { s.models[$0].released && !s.models[$0].retired }
            .sorted { s.models[$0].demandTokensDay > s.models[$1].demandTokensDay }
        for i in order {
            let m = s.models[i]
            let demand = m.demandTokensDay
            // 3.8: capacity can come from several pools. Hardware the model already uses first, then the fastest
            // chips it fits on; when one pool runs out of room the rest spills onto the next.
            let used = Set(m.deployments.map(\.accelID))
            var cands: [(id: String, per: Double, k: Int)] = []
            for p in Economy.pools(s) {
                if let (per, k) = perChip(m, p.accel.id, b), p.free > 0 || used.contains(p.accel.id) { cands.append((p.accel.id, per, k)) }
            }
            // 3.9: among new pools, prefer chips that serve well for what they'd train (keep the best training chips
            // free for the next run); ties go to the fastest.
            cands.sort { x, y in
                if used.contains(x.id) != used.contains(y.id) { return used.contains(x.id) }
                let rx = x.per / trainValue(x.id), ry = y.per / trainValue(y.id)
                return abs(rx - ry) > 1e-9 * max(rx, ry) ? rx > ry : x.per > y.per
            }
            guard !cands.isEmpty else { continue }
            let cap = m.deployments.reduce(0) { $0 + Physics.capacity(m, deployment: $1, bonuses: b) }
            let need = demand > 0 ? demand / aim : 0
            // 3.5: a family tier on sale with no servers yet gets one replica, so it can start winning traffic.
            let seed = demand <= 0 && m.deployments.isEmpty && m.api && Families.tier(of: m.id, s) != nil
            var remaining = seed ? 1 : need - cap
            if remaining > 0 {
                for c in cands where remaining > 0 {
                    guard let pool = Economy.pool(s, c.id) else { continue }
                    let current = s.models[i].deployments.first { $0.accelID == c.id }?.chips ?? 0
                    let wantedAdd = seed ? c.k : Int((remaining / c.per / Double(c.k)).rounded(.up)) * c.k
                    // 3.9: guard-rail — below 80% of demand served, users matter more than the free share, and
                    // chips parked on research come back before anyone is turned away.
                    let starving = demand > 0 && cap < demand * 0.8
                    let keepFree = starving ? 0 : Int(Double(pool.total) * reserve)
                    var room = max(0, pool.free - keepFree)
                    if starving, room < wantedAdd, let onResearch = s.researchChips[c.id], onResearch > 0 {
                        let back = min(onResearch, wantedAdd - room)
                        s.researchChips[c.id] = onResearch - back > 0 ? onResearch - back : nil
                        room += back
                        note(&s, "autoscale", "Took \(Fmt.int(back)) \(pool.accel.name) off research: \(m.name) was serving under 80% of its demand.")
                    }
                    // Serving your own users beats renting chips to strangers: take leased chips back first, but only
                    // what buys whole replicas (a recall it can't use would sit idle and get leased out again).
                    let leased = s.leases[c.id] ?? 0
                    if room < wantedAdd && leased > 0 {
                        let usable = min(wantedAdd, room + leased) / c.k * c.k
                        let back = max(0, usable - room)
                        if back > 0, s.setLease(c.id, chips: leased - back) == nil {
                            room += back
                            note(&s, "autoscale", "Recalled \(Fmt.int(back)) leased \(pool.accel.name) to serve \(m.name).")
                        }
                    }
                    let add = min(wantedAdd, room) / c.k * c.k
                    guard add > 0, s.deploy(m.id, accelID: c.id, chips: current + add) == nil else { continue }
                    remaining -= Double(add) * c.per
                    note(&s, "autoscale", "Capacity: +\(Fmt.int(add)) \(pool.accel.name) to \(m.name) (demand \(Fmt.count(demand)) tokens/day).")
                }
                // Still short after every pool: rent cloud chips within the budget, when serving pays for them.
                if !seed, remaining > 0, let c = cands.first, remaining / c.per >= Double(c.k) {
                    let chips = Int((remaining / c.per / Double(c.k)).rounded(.up)) * c.k
                    let n = rentForServing(&s, m, accelID: c.id, chips: chips, perChip: c.per * aim, k: c.k)
                    let cur = s.models[i].deployments.first { $0.accelID == c.id }?.chips ?? 0
                    if n > 0, s.deploy(m.id, accelID: c.id, chips: cur + n) == nil {
                        log(&s, "Capacity: +\(Fmt.int(n)) rented to \(m.name).")
                    }
                }
            } else if need < cap * 0.6 {
                // Give back what it no longer needs, the best training chips first (3.9; was slowest first) so the
                // next run gets them (keep one replica while it still has demand).
                var surplus = cap - need
                for d in s.models[i].deployments.sorted(by: { trainValue($0.accelID) > trainValue($1.accelID) }) {
                    guard let (per, k) = perChip(m, d.accelID, b), surplus > 0 else { continue }
                    var drop = min(d.chips, Int(surplus / per / Double(k))  * k)
                    if demand > 0 && drop >= s.models[i].deployments.reduce(0, { $0 + $1.chips }) { drop = max(0, drop - k) }
                    guard drop >= k else { continue }
                    if s.deploy(m.id, accelID: d.accelID, chips: d.chips - drop) == nil {
                        surplus -= Double(drop) * per
                        log(&s, "Capacity: freed \(Fmt.int(drop)) \(HardwareCatalog.get(d.accelID)?.name ?? d.accelID) from \(m.name) (demand fell).")
                    }
                }
            }
        }
    }

    /// 3.9: a chip's training worth: BF16 TFLOPS at its base MFU.
    static func trainValue(_ accelID: String) -> Double {
        guard let a = HardwareCatalog.get(accelID) else { return 1e-9 }
        return max(1e-9, a.trainTFLOPS(.bf16) * a.baseMFU)
    }

    /// 3.9: the fleet's best training chips (the type with the highest per-chip training worth among types you own
    /// at least 1,000 of) shouldn't sit on serving when other chips can carry the same load. Moves serving capacity
    /// off them onto free chips of other types, replica for replica, without lowering capacity.
    static func freeTrainingChips(_ s: inout GameState, _ b: ResearchBonuses) {
        let pools = Economy.pools(s)
        guard let best = pools.filter({ $0.owned >= 1_000 && $0.accel.supportsTraining(.bf16) }).max(by: { trainValue($0.accel.id) < trainValue($1.accel.id) }) else { return }
        // Idle chips above the reserve, plus chips leased out (deploy recalls them).
        var free: [String: Int] = Dictionary(uniqueKeysWithValues: pools.map {
            ($0.accel.id, max(0, $0.free - Int(Double($0.total) * s.ops.reserveShare)) + (s.leases[$0.accel.id] ?? 0))
        })
        for i in s.models.indices where s.models[i].released && !s.models[i].retired {
            let m = s.models[i]
            guard let onBest = m.deployments.first(where: { $0.accelID == best.accel.id }), let (perBest, kBest) = perChip(m, best.accel.id, b) else { continue }
            var toMove = Double(onBest.chips) * perBest   // capacity to rehome, tokens/day
            var moved = 0
            let others = pools.filter { $0.accel.id != best.accel.id && trainValue($0.accel.id) < trainValue(best.accel.id) }
                .compactMap { p in perChip(m, p.accel.id, b).map { (p.accel.id, $0.0, $0.1) } }
                .sorted { $0.1 / trainValue($0.0) > $1.1 / trainValue($1.0) }
            for (id, per, k) in others where toMove > 0 {
                let n = min(free[id] ?? 0, Int((toMove / per).rounded(.up))) / k * k
                guard n > 0 else { continue }
                // Whole replicas off the best chips, never more capacity than the new chips bring.
                let back = min(onBest.chips - moved, Int(Double(n) * per / perBest) / kBest * kBest)
                guard back > 0 else { continue }
                let cur = s.models[i].deployments.first { $0.accelID == id }?.chips ?? 0
                guard s.deploy(m.id, accelID: id, chips: cur + n) == nil else { continue }
                free[id, default: 0] -= n
                moved += back
                toMove -= Double(back) * perBest
            }
            if moved > 0, s.deploy(m.id, accelID: best.accel.id, chips: onBest.chips - moved) == nil {
                log(&s, "Capacity: moved \(m.name) off \(Fmt.int(moved)) \(best.accel.name) onto other chips, keeping them free for training.")
            }
        }
    }

    /// Rent on-demand cloud chips for a model the fleet can't serve, within the monthly budget and only when what a chip
    /// earns at the model's price beats its rent by 30%. Returns the chips added to the pool.
    static func rentForServing(_ s: inout GameState, _ m: AIModel, accelID: String, chips: Int, perChip: Double, k: Int) -> Int {
        guard s.ops.rentBudget > 0, let a = HardwareCatalog.get(accelID), Economy.canRent(a, s), Partners.blocker(a, s) == nil,
              let rate = Economy.rentQuote(a, s) else { return 0 }
        let monthly = rate * 24 * 30.4
        let price = m.api && m.apiPrice > 0 ? m.apiPrice : Treasury.targetPrice(m, s)
        guard perChip * price / 1e6 * 30.4 > monthly * 1.3 else { return 0 }
        s.ops.delegateRentals.formIntersection(Set(s.rentals.map(\.id)))
        let mine = s.rentals.filter { s.ops.delegateRentals.contains($0.id) }
        let spent = mine.reduce(0) { $0 + $1.hourly * 24 * 30.4 * Double($1.count) }
        let existing = s.rentals.filter { $0.accelID == accelID }.reduce(0) { $0 + $1.count }
        let n = min(chips, Int(max(0, s.ops.rentBudget - spent) / monthly), max(0, Economy.rentalLimit(a, s) - existing)) / k * k
        guard n > 0, rate * 24 * Double(n) <= s.cash + s.cloudCredits else { return 0 }
        if let j = s.rentals.firstIndex(where: { $0.accelID == accelID && $0.term == .onDemand && s.ops.delegateRentals.contains($0.id) }) {
            let old = s.rentals[j].count
            s.rentals[j].hourly = (s.rentals[j].hourly * Double(old) + rate * Double(n)) / Double(old + n)
            s.rentals[j].count = old + n
        } else {
            guard s.rentHardware(accelID, count: n, term: .onDemand) == nil, let r = s.rentals.last else { return 0 }
            s.ops.delegateRentals.insert(r.id)
        }
        note(&s, "autoscale", "Rented \(Fmt.int(n)) \(a.name) on demand for \(m.name): \(Fmt.money(monthly * Double(n)))/month "
            + "(\(Fmt.money(spent + monthly * Double(n))) of your \(Fmt.money(s.ops.rentBudget)) cloud budget).", money: monthly * Double(n))
        return n
    }

    /// Give the delegate's own cloud chips back first when they sit idle: they cost rent, owned chips don't.
    static func releaseRentals(_ s: inout GameState) {
        s.ops.delegateRentals.formIntersection(Set(s.rentals.map(\.id)))
        for id in Array(s.ops.delegateRentals) {
            guard let j = s.rentals.firstIndex(where: { $0.id == id }), let pool = Economy.pool(s, s.rentals[j].accelID) else { continue }
            let spare = pool.free - Int(Double(pool.total) * s.ops.reserveShare)
            guard spare > 0 else { continue }
            let n = min(s.rentals[j].count, spare)
            let name = HardwareCatalog.get(s.rentals[j].accelID)?.name ?? s.rentals[j].accelID
            if n == s.rentals[j].count {
                s.rentals.remove(at: j)
                s.ops.delegateRentals.remove(id)
            } else {
                s.rentals[j].count -= n
            }
            log(&s, "Returned \(Fmt.int(n)) rented \(name) to the cloud: demand no longer needs them.")
        }
    }

    // MARK: Launches and model lifecycle

    static func autoLaunch(_ s: inout GameState) {
        let bestReleased = s.models.filter { $0.released && !$0.retired }.map(\.index).max() ?? -1
        if let m = s.models.filter({ !$0.released && !$0.retired && !$0.preview }).max(by: { $0.index < $1.index }), m.index > bestReleased + 0.5 {
            if s.launch(m.id, by: "delegate") == nil {
                note(&s, "launch", "Launched \(m.name) (index \(Fmt.score(m.index))) and moved your products onto it.")
            }
        }
        // Retire released models nobody uses any more (not the two best, nothing that powers a product or a contract).
        let keep = Set(s.models.filter { $0.released && !$0.retired }.sorted { $0.index > $1.index }.prefix(2).map(\.id))
        let used = Set([s.chatModelID, s.agentModelID].compactMap { $0 } + s.deals.filter(\.active).compactMap(\.modelID) + Families.protected(s))
        for m in s.models where m.released && !m.retired && !keep.contains(m.id) && !used.contains(m.id) && m.demandTokensDay < 1e6
            && GameCalendar.daysBetween(m.releaseDate ?? m.created, s.date) > 90 {
            s.retire(m.id)
            note(&s, "launch", "Retired \(m.name): almost no traffic left; its chips are free again.")
        }
    }

    // MARK: Cloud and leasing

    static func autoRenew(_ s: inout GameState) {
        let today = s.date
        // 3.9: look far enough ahead to catch the lapse between two visits (scripts only look in every 7 days).
        let ahead = max(2, competence(s).everyDays + 1)
        for i in s.rentals.indices {
            let r = s.rentals[i]
            guard let end = r.end, let months = r.term.months, GameCalendar.daysBetween(today, end) <= ahead,
                  let rate = Economy.rentQuote(HardwareCatalog.get(r.accelID) ?? HardwareCatalog.h100, s, renewing: r.count) else { continue }
            let name = HardwareCatalog.get(r.accelID)?.name ?? r.accelID
            // 3.9: only keep what earns its rent: a rental whose chips mostly sit idle past the free share is left to lapse.
            if let pool = Economy.pool(s, r.accelID), pool.free - Int(Double(pool.total) * s.ops.reserveShare) >= r.count, !s.ops.delegateRentals.contains(r.id) {
                let msg = "Let \(Fmt.int(r.count))× \(name) rental lapse: \(Fmt.int(pool.free)) of your \(Fmt.int(pool.total)) \(name) sit idle, so it isn't needed."
                if !s.opsLog.prefix(40).contains(where: { $0.hasSuffix(msg) }) { note(&s, "renew", msg) }   // visits repeat until it ends
                continue
            }
            s.rentals[i].end = GameCalendar.addMonths(end, months)
            s.rentals[i].hourly = rate * r.term.discount
            note(&s, "renew", "Renewed \(Fmt.int(r.count))× \(name) (\(r.term.rawValue.lowercased())) at \(Fmt.price(rate * r.term.discount))/hr; it is in use.",
                 money: rate * r.term.discount * 24 * 30.4 * Double(r.count))
        }
    }

    /// 3.9: the idle-compute delegate. Serving shortfalls are autoscale's job and run first; what is still idle beyond the
    /// free share goes to research (while it still speeds research up), then out on lease, so chips never sit for weeks.
    /// Your own work gets leased chips back through `recallLeased` and autoscale, so none of this blocks it.
    static func leaseIdle(_ s: inout GameState) {
        // Chips autoscale could not place yet (whole replicas only) stay free for serving: parking them on research
        // would just get them pulled back tomorrow.
        let underServed = s.models.contains { $0.released && !$0.retired && $0.demandTokensDay > 0 && $0.capacityTokensDay < $0.demandTokensDay * 0.9 }
        for pool in Economy.pools(s) where pool.owned > 0 {
            let id = pool.accel.id
            let keepFree = Int(Double(pool.total) * s.ops.reserveShare)
            var idle = pool.free - keepFree
            let current = s.leases[id] ?? 0
            // Research first, unless the player wants lease only: it costs nothing and is taken back for training.
            if idle > 0, s.ops.idleFirst == 0, !underServed, pool.accel.bf16 > 0 {
                let needPF = Sim.researchComputeCapPF - Sim.researchPF(s.researchChips)
                let take = min(idle, Int((max(0, needPF) * 1000 / pool.accel.bf16).rounded(.up)))
                if take > 0 {
                    s.researchChips[id, default: 0] += take
                    idle -= take
                    note(&s, "idle", "Put \(Fmt.int(take)) idle \(pool.accel.name) on research: nothing else needed them and research is below its useful size.")
                }
            }
            // 3.9: a small fleet leases from 8 chips, not 64 (a lab with 100 chips never leased anything before).
            let minLease = max(8, min(64, pool.owned / 10))
            // 3.9: a lease you set (or recalled) by hand stays as you left it; the delegate only takes chips back.
            if idle >= minLease && !s.ops.handLeased.contains(id) {
                let n = min(pool.owned, current + idle)
                if s.setLease(id, chips: n) == nil {
                    note(&s, "idle", "Leased \(Fmt.int(idle)) idle \(pool.accel.name) to the market: no serving shortfall, research is full.")
                }
            } else if pool.free < keepFree / 2 && current > 0 {
                // Your own work needs them back.
                let back = min(current, keepFree - pool.free)
                if back > 0, s.setLease(id, chips: current - back) == nil {
                    note(&s, "idle", "Recalled \(Fmt.int(back)) leased \(pool.accel.name) for your own work.")
                }
            }
        }
    }

    /// 3.9: what each delegate will do next, in plain words: the line the Operations screen shows under each switch.
    static func nextUp(_ s: GameState) -> [String: String] {
        var out: [String: String] = [:]
        let c = competence(s)
        let day = Int(s.date.timeIntervalSince1970 / 86_400)
        let wait = (c.everyDays - day % c.everyDays) % c.everyDays
        let when = wait == 0 ? "today" : wait == 1 ? "tomorrow" : "in \(wait) days"
        let pools = Economy.pools(s)
        let b = s.bonuses
        if s.ops.autoscale {
            let live = s.models.filter { $0.released && !$0.retired && $0.demandTokensDay > 0 }
            let short = live.filter { $0.demandTokensDay > $0.capacityTokensDay * 1.0 }
            out["autoscale"] = short.isEmpty ? "Every live model is covered; checks again \(when)."
                : "\(short.map(\.name).joined(separator: ", ")) \(short.count == 1 ? "is" : "are") short of capacity; adds chips \(when)."
            _ = b
        }
        if s.ops.leaseIdle {
            let idle = pools.reduce(0) { $0 + max(0, $1.free - Int(Double($1.total) * s.ops.reserveShare)) }
            out["leaseIdle"] = idle > 0 ? "\(Fmt.int(idle)) chips are idle beyond the free share; routes them \(when) (\(s.ops.idleFirst == 0 ? "research, then lease" : "lease"))."
                : "No spare chips beyond the free share."
        }
        if s.ops.autoRenew {
            let soon = s.rentals.filter { r in r.end.map { GameCalendar.daysBetween(s.date, $0) <= 14 } ?? false }
            out["autoRenew"] = soon.isEmpty ? "No rental ends in the next two weeks."
                : "\(soon.count) rental\(soon.count == 1 ? "" : "s") end within two weeks; in-use ones renew, idle ones lapse."
        }
        if s.ops.autoLaunch {
            let ready = s.models.filter { !$0.released && !$0.retired && !$0.preview }.count
            out["autoLaunch"] = ready > 0 ? "\(ready) finished model\(ready == 1 ? "" : "s") waiting; ships one only if it beats your best." : "Nothing finished and waiting."
        }
        if s.ops.autoHire {
            let want = staffing(s)
            let gaps = Role.allCases.reduce(0) { acc, r in acc + max(0, (want[r] ?? 0) - s.employees.filter { $0.role == r }.count) }
            out["autoHire"] = gaps > 0 ? "\(gaps) open role\(gaps == 1 ? "" : "s") to fill at the next weekly review." : "Staffing matches your size."
        }
        if s.ops.autoRaises {
            let n = s.employees.filter { $0.salary < Macro.salary($0.role, s.year) * 0.85 }.count
            out["autoRaises"] = n > 0 ? "\(n) \(n == 1 ? "person is" : "people are") paid well under market; raises at the next weekly review." : "Everyone is paid near the market."
        }
        if s.ops.autoLeads {
            let n = s.deals.filter { !$0.active }.count
            out["autoLeads"] = n > 0 ? "\(n) open lead\(n == 1 ? "" : "s"); signs the ones your best model and safety record can serve." : "No open leads."
        }
        return out
    }

    // MARK: People

    /// How many people of each role the company should have now.
    static func staffing(_ s: GameState) -> [Role: Int] {
        let maxRun = s.runs.filter { $0.status == .running || $0.status == .postTraining }.map(\.design.chips).max() ?? 0
        let chips = Economy.totalChips(s)
        let rr = Economy.runRate(s)
        var want: [Role: Int] = [:]
        want[.mlEngineer] = min(60, Int((0.5 + Double(max(maxRun, chips / 4)) / 1_500).rounded(.up)))
        want[.infra] = min(80, Int((Double(maxRun) / 600).rounded(.up)))
        want[.researcher] = min(60, 3 + Int(log2(1 + max(s.valuation, 1) / 1e8) * 3))
        want[.safety] = max(1, (want[.researcher] ?? 0) / 6)
        want[.data] = max(1, (want[.researcher] ?? 0) / 8)
        want[.sales] = rr > 1e7 ? min(40, 1 + Int(rr / 5e7)) : 0
        return want
    }

    static func autoHire(_ s: inout GameState, precision: Double) {
        var budget = s.ops.hireBudget > 0 ? s.ops.hireBudget : max(150_000, Economy.runRate(s) * 0.03) / 12
        let want = staffing(s)
        for role in Role.allCases {
            let have = s.employees.filter { $0.role == role }.count
            guard have < (want[role] ?? 0), s.employees.count < Economy.officeCapacity(s) else { continue }
            // A smart COO picks the best candidate; scripts take the first that fits.
            let pool = s.candidates.filter { $0.role == role && $0.salary / 12 <= budget && HQ.hasSeat(s, $0) }
            let pick = precision >= 0.9 ? pool.max(by: { $0.skill / $0.salary < $1.skill / $1.salary }) : pool.first
            guard let c = pick, s.hire(c.id) == nil else { continue }
            budget -= c.salary / 12
            note(&s, "hire", "Hired \(c.name), \(role.title.lowercased()) (\(Fmt.money(c.salary))/yr): the team was below the size your runs, fleet and revenue call for.", money: c.salary / 12)
        }
        // Headquarters fills up first (satellites have their own desks); local rent, not San Francisco's (3.4 overhaul).
        if HQ.staffCount(s, office: "") >= Economy.office(s, s.officeLevel).capacity - 1, s.officeLevel + 1 < Economy.officeLevels.count {
            let next = Economy.office(s, s.officeLevel + 1)
            if next.monthly * 3 < s.cash * 0.05, s.upgradeOffice() == nil {
                log(&s, "Moved into a bigger office: \(next.name).")
            }
        }
    }

    static func autoRaises(_ s: inout GameState) {
        let y = s.year
        var given = 0
        for e in s.employees where e.salary < Macro.salary(e.role, y) * 0.85 && given < max(1, s.employees.count / 4) {
            // 3.9: one 15% step can leave a big gap open (and the same people were raised every week); close it to 90%.
            var steps = 0
            while steps < 3, (s.employees.first { $0.id == e.id }?.salary ?? .infinity) < Macro.salary(e.role, y) * 0.9 { s.giveRaise(e.id); steps += 1 }
            given += 1
        }
        if given > 0 { note(&s, "raises", "Raised pay for \(given) \(given == 1 ? "person" : "people") who had fallen behind the market.", money: 0) }
    }

    // MARK: Enterprise

    static func autoLeads(_ s: inout GameState) {
        for d in s.deals where !d.active {
            guard let m = s.models.filter({ $0.released && !$0.retired && $0.index + 0.01 >= d.minIndex }).max(by: { $0.index < $1.index }),
                  s.safetyScore >= d.minSafety else { continue }
            if s.acceptDeal(d.id, modelID: m.id) == nil {
                note(&s, "leads", "Signed \(d.client): \(Fmt.money(d.monthly))/month on \(m.name).", money: d.monthly)
            }
        }
    }
}

// MARK: - Player actions

extension GameState {
    /// Change the delegates' settings.
    mutating func updateOps(_ change: (inout OpsPolicy) -> Void) {
        change(&ops)
    }

    /// Ship a finished model properly: release it with an API, give it servers, and move your chat app, agent
    /// product and contracts onto it when it's better than what they run on.
    mutating func launch(_ id: UUID, plan: LaunchPlan? = nil, by: String = "") -> String? {
        guard let i = models.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if !models[i].released, let e = release(id, api: true, openWeights: false, plan: plan ?? Launches.delegatePlan(self), by: by) { return e }
        let m = models[i]
        let b = bonuses
        // Servers: on its training hardware if there are idle chips, as many as the model it replaces had.
        if m.deployments.isEmpty { provisionServers(id) }
        func better(than other: UUID?) -> Bool {
            guard let other, let o = models.first(where: { $0.id == other && !$0.retired }) else { return true }
            return m.index > o.index
        }
        if m.design.instruct && better(than: chatModelID) { chatModelID = id }
        if agentModelID != nil && m.design.toolUse && better(than: agentModelID) { agentModelID = id }
        for d in deals.indices where deals[d].active && deals[d].modelID != id && m.index + 0.01 >= deals[d].minIndex
            && better(than: deals[d].modelID) {
            deals[d].modelID = id
        }
        return nil
    }

    /// Tokens a day your products were last asked for: the biggest of what any model (retired or not) was asked for,
    /// the last day a live model was, and what today's users and seats would use.
    func lastKnownDemand() -> Double {
        let y = year
        let now = consumerUsers * Macro.tokensPerUserDay(y) + agentSeats * Macro.tokensPerSeatDay(y)
        return max(models.map { max($0.demandTokensDay, $0.servedTokensDay) }.max() ?? 0, lastLiveDemand, now)
    }

    /// Give a released model servers: as much capacity as the model it replaces had; with no live model before it,
    /// sized from the last known demand. Starts on its training hardware, then the fastest pools with room. Says what
    /// share of demand the servers cover when it had to guess. Returns the chips deployed.
    @discardableResult
    mutating func provisionServers(_ id: UUID) -> Int {
        guard let m = models.first(where: { $0.id == id }) else { return 0 }
        let b = bonuses
        let previous = models.filter { $0.id != id && $0.released && !$0.retired }.max { $0.index < $1.index }
        let demand = lastKnownDemand()
        let sized = previous == nil && demand > 0
        // Where: the previous model's hardware, then chips that serve well for what they'd train (3.9: the training
        // hardware no longer goes first, so the next run keeps the best training chips).
        var order: [String] = []
        if let p = previous?.deployments.first?.accelID { order.append(p) }
        let pools = Economy.pools(self)
        let fastest = pools.filter { $0.free > 0 }.compactMap { p in Operations.perChip(m, p.accel.id, b).map { (p.accel.id, $0.0) } }
            .sorted { $0.1 / Operations.trainValue($0.0) > $1.1 / Operations.trainValue($1.0) }.map(\.0)
        for a in fastest where !order.contains(a) { order.append(a) }
        guard !order.isEmpty else { return 0 }
        // How much: tokens a day of capacity.
        let prevCap = previous.map { p in p.deployments.reduce(0.0) { $0 + Physics.capacity(p, deployment: $1, bonuses: b) } } ?? 0
        var goalChips = 0
        if let a = HardwareCatalog.get(order[0]) { goalChips = Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b) * 4 }
        var remaining = sized ? demand / 0.8 : (prevCap > 0 ? prevCap : -1)
        var placed = 0, capacity = 0.0
        for accelID in order {
            guard let a = HardwareCatalog.get(accelID), let (per, k) = Operations.perChip(m, accelID, b) else { continue }
            let want = remaining > 0 ? Int((remaining / per / Double(k)).rounded(.up)) * k : max(k, goalChips / max(1, k) * k)
            let n = min(Economy.freeChips(self, accelID), max(k, want)) / k * k
            guard n > 0, deploy(id, accelID: accelID, chips: n + (models.first { $0.id == id }?.deployments.first { $0.accelID == accelID }?.chips ?? 0)) == nil else { continue }
            placed += n
            capacity += Double(n) * per
            if remaining > 0 { remaining -= Double(n) * per; if remaining <= 0 { break } } else { break }
            _ = a
        }
        if sized {
            let covered = demand > 0 ? min(1, capacity / demand) : 0
            Sim.news(&self, "\(m.name) is serving again",
                     placed > 0 ? "\(Fmt.int(placed)) chips cover \(Int(covered * 100))% of the \(Fmt.count(demand)) tokens a day your products last asked for."
                                  + (covered < 0.95 ? " Free more chips, rent some, or turn on the capacity delegate to serve the rest." : "")
                                : "There are no free chips it fits on, so chat, agents and the API stay down. Free some up on Compute.",
                     .company, important: true, good: placed > 0)
        }
        return placed
    }

    mutating func setChatModel(_ id: UUID?) { chatModelID = id }
    mutating func setAgentModel(_ id: UUID?) { agentModelID = id }
}
