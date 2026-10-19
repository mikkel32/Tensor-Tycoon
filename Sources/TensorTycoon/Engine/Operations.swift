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
        if s.opsLog.count > 60 { s.opsLog.removeLast(s.opsLog.count - 60) }
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
            // Serve on the hardware it already uses, else the pool with the most idle chips.
            let pools = Economy.pools(s)
            let accelID = m.deployments.max(by: { $0.chips < $1.chips })?.accelID
                ?? pools.filter { $0.free > 0 }.max(by: { Double($0.free) * $0.accel.best < Double($1.free) * $1.accel.best })?.accel.id
            guard let accelID, let (per, k) = perChip(m, accelID, b), let pool = pools.first(where: { $0.accel.id == accelID }) else { continue }
            let current = m.deployments.first { $0.accelID == accelID }?.chips ?? 0
            // 3.5: a family tier on sale with no servers yet gets one replica, so it can start winning traffic.
            let seed = demand <= 0 && m.deployments.isEmpty && m.api && Families.tier(of: m.id, s) != nil
            let wanted = demand > 0 ? Int((demand / aim / per / Double(k)).rounded(.up)) * k : (seed ? k : 0)
            let keepFree = Int(Double(pool.total) * reserve)
            if wanted > current {
                var room = max(0, pool.free - keepFree)
                // Serving your own users beats renting chips to strangers: take leased chips back first, but only
                // what buys whole replicas (a recall it can't use would sit idle and get leased out again).
                let leased = s.leases[accelID] ?? 0
                if room < wanted - current && leased > 0 {
                    let usable = min(wanted - current, room + leased) / k * k
                    let back = max(0, usable - room)
                    if back > 0, s.setLease(accelID, chips: leased - back) == nil {
                        room += back
                        log(&s, "Recalled \(Fmt.int(back)) leased \(pool.accel.name) to serve \(m.name).")
                    }
                }
                var add = min(wanted - current, room) / k * k
                // Still short: rent cloud chips within the budget, when serving pays for them.
                if wanted - current - add >= k {
                    add += rentForServing(&s, m, accelID: accelID, chips: wanted - current - add, perChip: per * aim, k: k)
                }
                guard add > 0 else { continue }
                if s.deploy(m.id, accelID: accelID, chips: current + add) == nil {
                    log(&s, "Capacity: +\(Fmt.int(add)) \(pool.accel.name) to \(m.name) (demand \(Fmt.count(demand)) tokens/day).")
                }
            } else if Double(wanted) < Double(current) * 0.6 && current - wanted >= k {
                // Give back what it no longer needs (keep one replica while it still has demand).
                let keep = demand > 0 ? max(k, wanted) : 0
                if s.deploy(m.id, accelID: accelID, chips: keep) == nil {
                    log(&s, "Capacity: freed \(Fmt.int(current - keep)) \(pool.accel.name) from \(m.name) (demand fell).")
                }
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
        log(&s, "Rented \(Fmt.int(n)) \(a.name) on demand for \(m.name): \(Fmt.money(monthly * Double(n)))/month "
            + "(\(Fmt.money(spent + monthly * Double(n))) of your \(Fmt.money(s.ops.rentBudget)) cloud budget).")
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
                log(&s, "Launched \(m.name) (index \(Fmt.score(m.index))) and moved your products onto it.")
            }
        }
        // Retire released models nobody uses any more (not the two best, nothing that powers a product or a contract).
        let keep = Set(s.models.filter { $0.released && !$0.retired }.sorted { $0.index > $1.index }.prefix(2).map(\.id))
        let used = Set([s.chatModelID, s.agentModelID].compactMap { $0 } + s.deals.filter(\.active).compactMap(\.modelID) + Families.protected(s))
        for m in s.models where m.released && !m.retired && !keep.contains(m.id) && !used.contains(m.id) && m.demandTokensDay < 1e6
            && GameCalendar.daysBetween(m.releaseDate ?? m.created, s.date) > 90 {
            s.retire(m.id)
            log(&s, "Retired \(m.name): almost no traffic left; its chips are free again.")
        }
    }

    // MARK: Cloud and leasing

    static func autoRenew(_ s: inout GameState) {
        let today = s.date
        for i in s.rentals.indices {
            let r = s.rentals[i]
            guard let end = r.end, let months = r.term.months, GameCalendar.daysBetween(today, end) <= 2,
                  let rate = Economy.rentQuote(HardwareCatalog.get(r.accelID) ?? HardwareCatalog.h100, s) else { continue }
            s.rentals[i].end = GameCalendar.addMonths(end, months)
            s.rentals[i].hourly = rate * r.term.discount
            let name = HardwareCatalog.get(r.accelID)?.name ?? r.accelID
            log(&s, "Renewed \(Fmt.int(r.count))× \(name) (\(r.term.rawValue.lowercased())) at \(Fmt.price(rate * r.term.discount))/hr.")
        }
    }

    static func leaseIdle(_ s: inout GameState) {
        for pool in Economy.pools(s) where pool.owned > 0 {
            let keepFree = Int(Double(pool.total) * s.ops.reserveShare)
            let idle = pool.free - keepFree
            let current = s.leases[pool.accel.id] ?? 0
            if idle >= 64 {
                let n = min(pool.owned, current + idle)
                if s.setLease(pool.accel.id, chips: n) == nil {
                    log(&s, "Leased \(Fmt.int(idle)) idle \(pool.accel.name) to the market.")
                }
            } else if pool.free < keepFree / 2 && current > 0 {
                // Your own work needs them back.
                let back = min(current, keepFree - pool.free)
                if back > 0, s.setLease(pool.accel.id, chips: current - back) == nil {
                    log(&s, "Recalled \(Fmt.int(back)) leased \(pool.accel.name) for your own work.")
                }
            }
        }
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
            let pool = s.candidates.filter { $0.role == role && $0.salary / 12 <= budget }
            let pick = precision >= 0.9 ? pool.max(by: { $0.skill / $0.salary < $1.skill / $1.salary }) : pool.first
            guard let c = pick, s.hire(c.id) == nil else { continue }
            budget -= c.salary / 12
            log(&s, "Hired \(c.name), \(role.title.lowercased()) (\(Fmt.money(c.salary))/yr).")
        }
        if s.employees.count >= Economy.officeCapacity(s) - 1, s.officeLevel + 1 < Economy.officeLevels.count {
            let next = Economy.officeLevels[s.officeLevel + 1]
            if next.monthly * 3 < s.cash * 0.05, s.upgradeOffice() == nil {
                log(&s, "Moved into a bigger office: \(next.name).")
            }
        }
    }

    static func autoRaises(_ s: inout GameState) {
        let y = s.year
        var given = 0
        for e in s.employees where e.salary < Macro.salary(e.role, y) * 0.85 && given < max(1, s.employees.count / 4) {
            s.giveRaise(e.id)
            given += 1
        }
        if given > 0 { log(&s, "Raised pay for \(given) \(given == 1 ? "person" : "people") who had fallen behind the market.") }
    }

    // MARK: Enterprise

    static func autoLeads(_ s: inout GameState) {
        for d in s.deals where !d.active {
            guard let m = s.models.filter({ $0.released && !$0.retired && $0.index + 0.01 >= d.minIndex }).max(by: { $0.index < $1.index }),
                  s.safetyScore >= d.minSafety else { continue }
            if s.acceptDeal(d.id, modelID: m.id) == nil {
                log(&s, "Signed \(d.client): \(Fmt.money(d.monthly))/month on \(m.name).")
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
        if m.deployments.isEmpty {
            let previous = models.filter { $0.id != id && $0.released && !$0.retired }.max { $0.index < $1.index }
            let accelID = runs.first { $0.modelID == id }?.design.accelID ?? previous?.deployments.first?.accelID ?? Economy.pools(self).max { $0.free < $1.free }?.accel.id
            if let accelID, let a = HardwareCatalog.get(accelID) {
                let k = Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b)
                let free = Economy.freeChips(self, accelID)
                let goal = max(k, previous?.deployments.reduce(0) { $0 + $1.chips } ?? k * 4)
                let n = min(free, goal) / k * k
                if n > 0 { _ = deploy(id, accelID: accelID, chips: n) }
            }
        }
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

    mutating func setChatModel(_ id: UUID?) { chatModelID = id }
    mutating func setAgentModel(_ id: UUID?) { agentModelID = id }
}
