import Foundation

/// Allocation of one accelerator type across the company.
struct ComputePool: Identifiable {
    var id: String { accel.id }
    let accel: Accelerator
    var owned = 0
    var rented = 0
    var training = 0
    var inference = 0
    var research = 0
    var rsi = 0
    var swarm = 0
    var leased = 0

    var total: Int { owned + rented }
    var allocated: Int { training + inference + research + rsi + swarm + leased }
    var free: Int { max(0, total - allocated) }
}

enum Economy {
    // MARK: Hardware market

    static func ageYears(_ a: Accelerator, _ s: GameState) -> Double { s.year - a.available.decimal }

    static func isAnnounced(_ a: Accelerator, _ s: GameState) -> Bool { a.announced <= s.date.ym }

    /// When this player can get the chip: partners with early access get it months ahead (never before announcement).
    static func availableFor(_ a: Accelerator, _ s: GameState) -> YM {
        let early = Partners.earlyMonths(a, s)
        guard early > 0 else { return a.available }
        return max(a.announced, a.available.adding(months: -early))
    }

    static func isEarlyAccess(_ a: Accelerator, _ s: GameState) -> Bool {
        a.available > s.date.ym && availableFor(a, s) <= s.date.ym
    }

    static func canBuy(_ a: Accelerator, _ s: GameState) -> Bool {
        guard a.purchasable, availableFor(a, s) <= s.date.ym else { return false }
        if let d = a.discontinued, d <= s.date.ym { return false }
        return true
    }

    static func canRent(_ a: Accelerator, _ s: GameState) -> Bool {
        guard a.rentable, availableFor(a, s) <= s.date.ym else { return false }
        if let d = a.discontinued, s.year > d.decimal + 3 { return false }
        // Clouds retire chips that have no end date eight years after launch.
        if a.discontinued == nil, a.cls != .consumer && a.cls != .workstation, s.year > a.available.decimal + 8 { return false }
        if a.vendor == .huawei && !s.market.exportControls && s.year < 2023 { return false }
        return true
    }

    static func dealDiscount(_ a: Accelerator, _ s: GameState) -> Double {
        s.supplyDeals.first { $0.vendor == a.vendor.rawValue }?.discount ?? 0
    }

    static func hasDeal(_ a: Accelerator, _ s: GameState) -> Bool {
        s.supplyDeals.contains { $0.vendor == a.vendor.rawValue }
    }

    static func price(_ a: Accelerator, _ s: GameState) -> Double? {
        guard let base = a.price else { return nil }
        if a.vendor == .custom { return base }
        let age = ageYears(a, s)
        var dep = age > 1.5 ? pow(1 - 0.17, age - 1.5) : 1
        dep = max(dep, 0.22)
        var mult = s.market.hardwarePrice
        if a.cls == .consumer { mult = s.market.consumerGPUPrice }
        if a.cls == .workstation { mult = (s.market.consumerGPUPrice + s.market.hardwarePrice) / 2 }
        return base * dep * mult * (1 - dealDiscount(a, s)) * (1 - Partners.discount(a, s)) * (1 - s.traits.hardware)
            * Nations.chipFactor(s)   // 3.7: subsidies at home, export controls aimed at you
    }

    static func rent(_ a: Accelerator, _ s: GameState) -> Double? {
        guard let base = a.rent else { return nil }
        let age = max(0, ageYears(a, s))
        let decayed = max(a.rentFloor, base * pow(0.78, age))
        let mult = a.cls == .consumer ? (s.market.consumerGPUPrice + s.market.rentPrice) / 2 : s.market.rentPrice
        return decayed * mult * (1 - dealDiscount(a, s)) * (1 - Partners.discount(a, s)) * (1 - s.traits.hardware)
            * (s.lawsPassed.contains("nairr") && HQ.region(s) == .us ? 0.95 : 1) * Nations.chipFactor(s)   // 3.7; 3.4 overhaul: the US research cloud serves US labs
            * Science.cloudFactor(s)   // providers pass on part of your energy discoveries' saving
    }

    static func resaleValue(_ a: Accelerator, _ s: GameState, unitCost: Double, purchased: Date) -> Double {
        let years = Double(GameCalendar.daysBetween(purchased, s.date)) / 365
        let market = (price(a, s) ?? (a.price ?? unitCost) * max(0.15, pow(0.78, ageYears(a, s)))) + Semis.siliconCost(a.id, s)   // 3.9: your own chips' silicon
        let wear = max(0.3, 1 - 0.1 * years)
        return min(unitCost, market) * 0.85 * wear
    }

    static func leadTimeDays(_ a: Accelerator, _ s: GameState) -> Int {
        if a.cls == .consumer || a.cls == .workstation { return 4 }
        if a.vendor == .custom { return AlienFab.isAlienChip(a.id) ? AlienFab.leadDays(s, count: 0) : (Semis.isSemiChip(a.id) ? Semis.shipDays : 45) }
        var d = s.market.leadTimeDays
        if hasDeal(a, s) { d *= 0.5 }
        if Partners.covering(a, s) != nil { d *= 0.6 }
        if ageYears(a, s) < 0.5 { d += 45 }
        if a.cls == .wafer { d += 60 }
        return Int(d * max(0.3, 1 - s.traits.leadTime))
    }

    // MARK: World chip supply

    /// The world's AI compute in H100-equivalents: the frontier labs' fleets plus the clouds that rent to everyone else.
    static func worldFleet(_ y: Double) -> Double { CompetitorCatalog.industryCompute(y) * 1.5 }

    /// Weight of a chip in the world's fleets (in compute, not units): NVIDIA dominates, TPUs come through one cloud,
    /// the rest are niche, and flagship training chips carry more of the world's compute than small inference cards.
    static func fleetWeight(_ a: Accelerator) -> Double {
        let family: Double
        switch a.cls {
        case .consumer, .workstation: return 0
        case .tpu: family = 0.6
        case .custom: family = 0.15
        case .wafer: family = 0.05
        case .datacenter: family = a.vendor == .nvidia ? 1 : (a.vendor == .amd ? 0.3 : 0.15)
        }
        return family * pow(max(a.bf16, 1) / HardwareCatalog.h100.bf16, 0.6)
    }

    /// How much of the installed base this chip is: it ramps up in its first year, runs at volume for two more,
    /// then clouds retire it (by 3 years after it's discontinued, or 8 years after launch).
    static func fleetLife(_ a: Accelerator, _ y: Double) -> Double {
        let age = y - a.available.decimal
        let end = a.discontinued.map { max(4, $0.decimal - a.available.decimal + 3) } ?? 8
        if age < 0 { return 0 }
        if age < 1 { return 0.25 + 0.75 * age }
        if age < 3 { return 1 }
        return max(0, 1 - (age - 3) / max(1, end - 3))
    }

    /// Where the chip's production line is: ramping for its first nine months, then winding down until it's discontinued.
    static func productionLife(_ a: Accelerator, _ y: Double) -> Double {
        let age = y - a.available.decimal
        let stop = a.discontinued.map { $0.decimal - a.available.decimal } ?? 4
        if age < -0.25 || age >= stop { return 0 }
        if age < 0.75 { return 0.4 + 0.8 * max(0, age) }
        return max(0.2, 1 - 0.8 * (age - 0.75) / max(1, stop - 0.75))
    }

    /// Sum of fleet weights over the catalogue (for normalising each chip's share). Cached per game day and
    /// catalogue size: the hardware store asks for every chip's supply on every redraw.
    nonisolated(unsafe) private static var totalsCache: (key: Int, cloud: Double, production: Double)?

    static func supplyTotals(_ y: Double) -> (cloud: Double, production: Double) {
        let key = Int(y * 365.25) &* 1_000 &+ HardwareCatalog.all.count
        if let c = totalsCache, c.key == key { return (c.cloud, c.production) }
        var cloud = 0.0, production = 0.0
        for b in HardwareCatalog.all {
            let w = fleetWeight(b)
            guard w > 0 else { continue }
            if b.rentable { cloud += w * fleetLife(b, y) }
            if b.purchasable { production += w * productionLife(b, y) }
        }
        totalsCache = (key, cloud, production)
        return (cloud, production)
    }

    /// Chips of this type in the world's rentable cloud fleet today.
    static func cloudSupply(_ a: Accelerator, _ s: GameState) -> Double {
        let y = s.year
        let mine = fleetWeight(a) * fleetLife(a, y)
        guard mine > 0 else { return 0 }
        let total = supplyTotals(y).cloud
        return worldFleet(y) * mine / max(total, 1e-9) * HardwareCatalog.h100.bf16 / max(a.bf16, 1)
    }

    /// Chips of this type the world's fabs ship per quarter (the fleet roughly doubles every year).
    static func quarterlyProduction(_ a: Accelerator, _ s: GameState) -> Double {
        let y = s.year
        let mine = fleetWeight(a) * productionLife(a, y)
        guard mine > 0 else { return 0 }
        let total = supplyTotals(y).production
        return worldFleet(y) * 0.3 * mine / max(total, 1e-9) * HardwareCatalog.h100.bf16 / max(a.bf16, 1)
    }

    /// Share of a chip's quarterly production one buyer can get; partners, supply deals and traits raise it.
    static func allocationShare(_ a: Accelerator, _ s: GameState) -> Double {
        let deal = (hasDeal(a, s) ? 1.6 : 1.0) * Partners.allocationMult(a, s) * (1 + s.traits.allocation)
        return min(0.6, 0.2 * deal)
    }

    /// Max chips you can order now: your share of the vendor's quarterly output, less what you ordered in the last 90 days.
    static func allocationLimit(_ a: Accelerator, _ s: GameState) -> Int {
        if a.cls == .consumer || a.cls == .workstation { return 2_000 }
        if a.vendor == .custom { return Semis.isSemiChip(a.id) ? Semis.available(a.id, s) : 20_000_000 }
        // 3.8: the window is at least the chip's lead time, so chips still in transit count against the allowance.
        let cutoff = GameCalendar.addDays(s.date, -max(90, leadTimeDays(a, s)))
        let recent = s.orders.filter { $0.accelID == a.id && $0.ordered > cutoff }.reduce(0) { $0 + $1.count }
            + s.orderLog.filter { $0.accelID == a.id && $0.ordered > cutoff }.reduce(0) { $0 + $1.count }
        let cap = quarterlyProduction(a, s) * allocationShare(a, s) * Nations.exportCapFactor(s)   // 3.4 overhaul: the 2025 diffusion rule's Tier 2
        return max(max(64, a.minOrder * 2), Int(cap) - recent)
    }

    /// Max chips of this type you can rent in total: a quarter of the world's cloud supply (more with partners
    /// and supply deals), and no more than two months of rent your cash and revenue can cover.
    static func rentalLimit(_ a: Accelerator, _ s: GameState) -> Int {
        if a.cls == .consumer || a.cls == .workstation { return 2_000 }
        let deal = (hasDeal(a, s) ? 1.4 : 1.0) * Partners.allocationMult(a, s) * (1 + s.traits.allocation)
        let supply = cloudSupply(a, s) * min(0.5, 0.25 * deal)
        let monthlyPerChip = (rent(a, s) ?? 1) * 24 * 30.4
        let credit = (max(0, s.cash) + s.cloudCredits + 2 * (s.history.last?.revenue ?? 0)) / max(1, 2 * monthlyPerChip)
        return Int(max(32, min(supply, credit, 20_000_000)))
    }

    /// Your share of the world's rentable supply of this chip.
    static func rentedShare(_ a: Accelerator, _ s: GameState, excluding: Int = 0) -> Double {
        let mine = max(0, Double(s.rentals.filter { $0.accelID == a.id }.reduce(0) { $0 + $1.count } - excluding))
        return mine / max(1, cloudSupply(a, s))
    }

    /// What a new rental costs: the market rate, plus 2% for every 1% of the world's supply you already hold.
    /// 3.8: a renewal (`renewing` = the chips being renewed) isn't new demand, so it isn't surcharged for your own holding.
    static func rentQuote(_ a: Accelerator, _ s: GameState, renewing: Int = 0) -> Double? {
        rent(a, s).map { $0 * (1 + 2 * rentedShare(a, s, excluding: renewing)) }
    }

    /// Server overhead included (CPU, NICs, fans).
    /// Alien chips (3.5) need far less around them: the swarm folded the host and network logic into the package.
    static func chipKW(_ a: Accelerator) -> Double { a.tdpW * (AlienFab.isAlienChip(a.id) ? 1.1 : 1.25) / 1000 }

    // MARK: Compute pools

    static func pools(_ s: GameState) -> [ComputePool] {
        var owned: [String: Int] = [:], rented: [String: Int] = [:], training: [String: Int] = [:]
        var inference: [String: Int] = [:], research: [String: Int] = [:], rsi: [String: Int] = [:]
        var swarm: [String: Int] = [:], leased: [String: Int] = [:]
        let readySites = Set(s.sites.lazy.filter { $0.isReady(s.date) }.map(\.id))
        for b in s.owned where readySites.contains(b.siteID) { owned[b.accelID, default: 0] += b.count }
        for r in s.rentals { rented[r.accelID, default: 0] += r.count }
        for i in s.runs.indices where s.runs[i].status == .running || s.runs[i].status == .postTraining {
            training[s.runs[i].design.accelID, default: 0] += s.runs[i].design.chips
            for h in s.runs[i].design.helpers { training[h.accelID, default: 0] += h.chips }   // 3.9: mixed-chip runs
        }
        for i in s.models.indices where !s.models[i].retired {
            for d in s.models[i].deployments { inference[d.accelID, default: 0] += d.chips }
        }
        for j in s.families.jobs where !j.paused { training[j.accelID, default: 0] += j.chips }   // 3.5: distillation and post-training
        for (id, n) in s.researchChips where n > 0 { research[id, default: 0] += n }
        for i in s.rsiRuns.indices where s.rsiRuns[i].status == .running { rsi[s.rsiRuns[i].accelID, default: 0] += s.rsiRuns[i].chips }
        for sw in s.swarms where !sw.paused { swarm[sw.accelID, default: 0] += sw.chips }
        for (id, n) in s.leases where n > 0 { leased[id, default: 0] += n }
        let ids = Set(owned.keys).union(rented.keys).union(training.keys).union(inference.keys).union(research.keys).union(rsi.keys)
            .union(swarm.keys).union(leased.keys)
        var out: [ComputePool] = []
        out.reserveCapacity(ids.count)
        for id in ids {
            guard let a = HardwareCatalog.get(id) else { continue }
            out.append(ComputePool(accel: a, owned: owned[id] ?? 0, rented: rented[id] ?? 0, training: training[id] ?? 0,
                                   inference: inference[id] ?? 0, research: research[id] ?? 0, rsi: rsi[id] ?? 0,
                                   swarm: swarm[id] ?? 0, leased: leased[id] ?? 0))
        }
        // 3.7: ties by chip ID, so the order never depends on the Set's (which changes from launch to launch).
        return out.sorted { a, b in
            let x = a.accel.best * Double(a.total), y = b.accel.best * Double(b.total)
            return x != y ? x > y : a.accel.id < b.accel.id
        }
    }

    /// Chips you own that sit at a site still under construction: they count for nothing until it opens.
    /// One entry per site and chip, soonest site first.
    static func waitingChips(_ s: GameState) -> [(site: Site, accelID: String, count: Int)] {
        var out: [(site: Site, accelID: String, count: Int)] = []
        for site in s.sites where !site.isReady(s.date) {
            var byChip: [String: Int] = [:]
            for b in s.owned where b.siteID == site.id { byChip[b.accelID, default: 0] += b.count }
            for (id, n) in byChip.sorted(by: { $0.key < $1.key }) where n > 0 { out.append((site, id, n)) }
        }
        return out.sorted { $0.site.ready < $1.site.ready }
    }

    static func pool(_ s: GameState, _ accelID: String) -> ComputePool? {
        pools(s).first { $0.accel.id == accelID }
    }

    static func freeChips(_ s: GameState, _ accelID: String) -> Int {
        pool(s, accelID)?.free ?? 0
    }

    static func totalChips(_ s: GameState) -> Int {
        s.owned.reduce(0) { $0 + $1.count } + s.rentals.reduce(0) { $0 + $1.count }
    }

    /// Aggregate compute in H100-equivalents (BF16 dense).
    static func h100e(_ s: GameState) -> Double {
        pools(s).reduce(0) { $0 + Double($1.total) * $1.accel.bf16 / HardwareCatalog.h100.bf16 }
    }

    // MARK: Costs

    /// Effective $/day for `count` chips: power + 4-year amortisation for chips you own, the rental rate for chips
    /// you rent. 3.9: a pool that mixes both is costed at its blend (a few rented chips used to price every owned chip
    /// of that type at the rental rate, which pushed the API price floor up several times).
    static func chipDailyCost(_ a: Accelerator, count: Int, state s: GameState) -> Double {
        let unit = (price(a, s) ?? (a.price ?? 0)) + Semis.siliconCost(a.id, s)   // 3.9: your own chips amortise their silicon too
        let amort = unit / (4 * 365)
        let site = s.sites.first { $0.kind != .garage } ?? s.sites.first
        let power = chipKW(a) * (site?.pue ?? 1.4) * 24 * (site?.powerPrice ?? 0.1)
        let rentals = s.rentals.filter { $0.accelID == a.id }
        let rented = rentals.reduce(0) { $0 + $1.count }
        if rented > 0 {
            let rentDay = rentals.reduce(0.0) { $0 + $1.hourly * 24 * Double($1.count) } / Double(rented)
            let owned = s.owned.filter { $0.accelID == a.id }.reduce(0) { $0 + $1.count }
            let share = Double(rented) / Double(rented + owned)
            return (share * rentDay + (1 - share) * (amort + power)) * Double(count)
        }
        if a.purchasable || s.owned.contains(where: { $0.accelID == a.id }) {
            return (amort + power) * Double(count)
        }
        return (rent(a, s) ?? 0) * 24 * Double(count)
    }

    /// What serving 1M tokens of this model costs you at full load (the "Serving cost / 1M" on the Models page):
    /// its chips' daily cost — rent, or power plus amortisation — over their daily token capacity.
    /// A model with no chips yet is costed on one replica of your most plentiful accelerator.
    /// What a model of this design would cost to serve per 1M tokens on its training hardware at full load
    /// (for the Model Lab: bigger models are smarter but cost more on every token you sell).
    static func servingCostPerM(design d: ModelDesign, _ s: GameState) -> Double? {
        guard let a = HardwareCatalog.get(d.accelID) else { return nil }
        let b = s.bonuses
        var m = AIModel(name: d.name, design: d, created: s.date, c: 0, reasoning: d.reasoning, reasoningBoost: 0, codeBoost: 0,
                        arenaBonus: 0, scores: [:], index: 0)
        m.servingPrecision = b.has(.int8Serving) ? .fp8 : .bf16
        // 3.4: costed the way the finished model will be served (its attention, decoding heads and mixer).
        m.archV2 = true
        m.efficiencyBoost = Physics.designEfficiency(d, bonuses: b)
        m.deployments = [Deployment(accelID: a.id, chips: Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b))]
        let cost = servingCostPerM(m, s, bonuses: b)
        return cost > 0 ? cost : nil
    }

    static func servingCostPerM(_ m: AIModel, _ s: GameState, bonuses: ResearchBonuses? = nil) -> Double {
        let b = bonuses ?? s.bonuses
        var cost = 0.0, cap = 0.0
        for d in m.deployments {
            guard let a = HardwareCatalog.get(d.accelID) else { continue }
            cost += chipDailyCost(a, count: d.chips, state: s)
            cap += Physics.capacity(m, deployment: d, bonuses: b)
        }
        if cap <= 0 {
            let a = pools(s).first?.accel ?? HardwareCatalog.h100
            let replica = Deployment(accelID: a.id, chips: Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b))
            cost = chipDailyCost(a, count: replica.chips, state: s)
            cap = Physics.capacity(m, deployment: replica, bonuses: b)
        }
        // 3.8: per 1M tokens sold; a reasoning model also generates its thinking tokens (Families.thinkingTokens).
        return cap > 0 ? cost / cap * 1e6 * Families.thinkingTokens(m, b) : 0
    }

    static func siteLoadKW(_ s: GameState, _ siteID: UUID) -> Double {
        let chips = s.owned.filter { $0.siteID == siteID }.reduce(0) { acc, b in
            acc + (HardwareCatalog.get(b.accelID).map(chipKW) ?? 0) * Double(b.count)
        } + s.orders.filter { $0.siteID == siteID }.reduce(0) { acc, o in
            acc + (HardwareCatalog.get(o.accelID).map(chipKW) ?? 0) * Double(o.count)
        }
        let sublet: Double = s.sites.first { $0.id == siteID }?.subleasedKW ?? 0   // 3.5: space rented to a tenant
        return chips + sublet + AdvancedProjects.siteFacilityKW(s, site: siteID)   // 3.8: cleared halls, restricted compute, programme spaces
    }

    static func hardwareValue(_ s: GameState) -> Double {
        s.owned.reduce(0) { acc, b in
            guard let a = HardwareCatalog.get(b.accelID) else { return acc }
            return acc + resaleValue(a, s, unitCost: b.unitCost, purchased: b.purchased) * Double(b.count)
        }
    }

    /// Datacenters at book value: what they cost less straight-line depreciation over 20 years (3.8; it was 80% of cost forever).
    static func siteValue(_ s: GameState) -> Double { Books.sitesBook(s) }

    static func debt(_ s: GameState) -> Double { s.loans.reduce(0) { $0 + $1.balance } + s.corp.debts.reduce(0) { $0 + $1.balance } }

    /// 3.4 overhaul: each office pays its own country's employer on-costs.
    static func payrollYear(_ s: GameState) -> Double {
        guard !s.hq.satellites.isEmpty else { return s.employees.reduce(0) { $0 + $1.salary } * max(0.5, 1 + s.traits.payroll) * HQ.payrollFactor(s) }
        return s.employees.reduce(0) { $0 + $1.salary * HQ.payrollFactor(s, office: $1.office) } * max(0.5, 1 + s.traits.payroll)
    }

    static let officeLevels: [(name: String, capacity: Int, monthly: Double, image: String)] = [
        ("Garage", 6, 0, "garage"),
        ("Startup office", 25, 30_000, "garage"),
        ("Floor in SF", 120, 180_000, "sf_skyline"),
        ("HQ building", 600, 1_200_000, "sf_skyline"),
        ("Corporate campus", 3_000, 6_000_000, "nvidia_hq"),
        ("Mega campus", 15_000, 25_000_000, "nvidia_hq"),
    ]

    /// Desks at headquarters plus every satellite office (3.4 overhaul).
    static func officeCapacity(_ s: GameState) -> Int { officeLevels[min(s.officeLevel, officeLevels.count - 1)].capacity + HQ.satelliteSeats(s) }

    static func dataMonthlyCost(_ s: GameState) -> Double {
        let catalog = s.dataSources.sorted().compactMap { DataCatalog.byID[$0] }.reduce(0) { $0 + $1.monthly }   // 3.7: fixed order
        let f = Nations.dataPriceFactor(s)   // 3.4 overhaul: data rules at home price licensed data
        return catalog + DataEconomy.monthlyCost(s) + (f == 1 ? 0 : (catalog + DataEconomy.licenceMonthly(s)) * (f - 1))   // 3.6: data economy
    }

    // MARK: Revenue & valuation

    /// Annualised recurring revenue: this month so far blended with last month. Programme milestone payments (3.8) are
    /// revenue but lumpy, so they never enter the run rate (or the multiple the valuation puts on it).
    static func runRate(_ s: GameState) -> Double {
        let daysIn = max(1, GameCalendar.components(s.date).day)
        let current = s.month.recurringRevenue / Double(daysIn) * 365
        if let last = s.history.last {
            let lastRate = last.recurringRevenue * 12
            return daysIn < 10 ? lastRate : (current * 0.6 + lastRate * 0.4)
        }
        return current
    }

    /// Annualised revenue of the divisions you folded back in (valued at their own kind's multiple, not the lab's).
    static func groupRunRate(_ s: GameState) -> Double {
        let daysIn = max(1, GameCalendar.components(s.date).day)
        let current = s.month.revGroup / Double(daysIn) * 365
        if let last = s.history.last {
            let lastRate = last.revGroup * 12
            return daysIn < 10 ? lastRate : (current * 0.6 + lastRate * 0.4)
        }
        return current
    }

    /// 3.8: what the company is worth to its shareholders, piece by piece. The business itself (enterprise value) is
    /// the best of four views — its revenue at the era's multiple, the hype around a frontier model, a credible team's
    /// seed price, its talent — plus hard assets at 60%, folded-in divisions at their own multiples and stakes in other
    /// companies at 90%. Then cash and 80% of cloud credits are added and all debt taken off: borrowing to sit on cash
    /// creates nothing, moving cash into a subsidiary loses the holding discount, and a buyback or dividend lowers it.
    struct Breakdown {
        var revenue: Double
        var hype: Double
        var seed: Double
        var talent: Double
        /// Hardware at resale and datacenters at book value, at 60%.
        var hardAssets: Double
        /// Divisions folded back in, at their kind's multiple.
        var divisions: Double
        /// Subsidiaries, rival-lab stakes and the licence fees subsidiaries pay you, at 90%; alien-tech moat.
        var stakes: Double
        var cash: Double
        /// Cloud credits at 80% (they only pay for rentals).
        var credits: Double
        var debt: Double
        /// The crisis discount on multiples (1 outside a crisis).
        var crisis: Double

        var operations: Double { max(revenue, hype, seed, talent) }
        var basis: String {
            switch operations {
            case revenue: "revenue"
            case hype: "a frontier model"
            case talent: "the team"
            default: "a seed-stage team"
            }
        }
        var enterprise: Double { operations + hardAssets + divisions + stakes }
        var equity: Double { max(0, enterprise + cash + credits - debt) }
    }

    static func breakdown(_ s: GameState) -> Breakdown {
        let y = s.year
        let crisis = Crises.multipleFactor(s)
        // Chip sales and leased compute earn hardware multiples, not software ones.
        // 3.8: licence fees from your subsidiaries are valued with them (`Corporate.feeValue`) and folded-in divisions at
        // their own multiples (`Corporate.divisionValue`), never at the lab's.
        let rr = max(0, runRate(s) - 0.6 * hardwareRunRate(s) - Corporate.feeRunRate(s) - groupRunRate(s))
        var growth = 0.0
        if s.history.count >= 7 {
            let now = s.history.last!.recurringRevenue
            let then = s.history[s.history.count - 7].recurringRevenue
            if then > 0 { growth = clamp(pow(now / then, 2) - 1, 0, 4) }
        }
        let momentum = Launches.valuationFactor(s)   // 3.8: what investors make of your recent rank changes
        let revVal = rr * Macro.revenueMultiple(y) * (1 + growth * 0.25) * crisis * momentum
        let best = s.models.map { $0.released ? $0.c : $0.c - 0.15 }.max() ?? -5
        let gap = best - Macro.frontier(y)
        let age = Double(GameCalendar.daysBetween(s.startDate, s.date)) / 365
        let maturity = clamp(0.3 + age * 0.3, 0.3, 1.0)
        let hypeVal = 0.55 * Macro.frontierValuation(y) * exp(2.4 * min(gap, 0.5)) * (s.market.hype / 1.3)
            * pow(max(5, s.brand) / 60, 0.4) * maturity * crisis * momentum
        let talent = s.employees.reduce(0.0) { $0 + ($1.role == .researcher ? $1.skill * 40_000 : $1.skill * 10_000) } * (y > 2023 ? 3 : 1)
        let seed = Macro.seedValuation(y) * min(1.5, 0.6 + Double(s.employees.count) * 0.1)
        let stakes = Xeno.moatValue(s) + RivalEconomy.stakesValue(s) * 0.9 + (Corporate.stakesValue(s) + Corporate.feeValue(s)) * 0.9   // 3.5: subsidiaries
        return Breakdown(revenue: revVal, hype: hypeVal, seed: seed, talent: talent,
                         hardAssets: 0.6 * (hardwareValue(s) + siteValue(s)), divisions: Corporate.divisionValue(s) * crisis, stakes: stakes,
                         cash: s.cash, credits: 0.8 * s.cloudCredits, debt: debt(s), crisis: crisis)
    }

    static func valuation(_ s: GameState) -> Double {
        if s.isPublic { return s.sharePrice * s.totalShares }
        return max(breakdown(s).equity, roundFloor(s))
    }

    /// The last round's post-money, written down 30% a year (to at most 40% off): a private mark rarely falls faster —
    /// except in a crisis, when down rounds price the whole market lower (3.8).
    static func roundFloor(_ s: GameState) -> Double {
        guard let r = s.rounds.last else { return 0 }
        let years = Double(GameCalendar.daysBetween(r.date, s.date)) / 365
        // Subsidiaries spun off to shareholders since that round took their value out of the company.
        let spun = s.corp.subs.filter { $0.status == .spunOff && ($0.statusDate ?? .distantPast) >= r.date }.reduce(0) { $0 + $1.stake * $1.valuation }
        return max(0, (r.preMoney + r.amount) * max(0.4, 1 - 0.3 * years) * Crises.multipleFactor(s) - spun)
    }

    /// 3.8: how far a private company's mark moves in a month between rounds: halfway (in log terms) toward its new
    /// level, but never more than +60% or −30%. Only a priced round (or an IPO) re-marks it further at once.
    static func smoothedMark(old: Double, new: Double, floor: Double) -> Double {
        guard old > 0, new > 0 else { return max(new, floor) }
        let step = clamp((old * new).squareRoot(), old * 0.7, old * 1.6)
        return max(step, floor)
    }

    /// Annualised revenue from selling chips and leasing compute.
    static func hardwareRunRate(_ s: GameState) -> Double {
        let daysIn = max(1, GameCalendar.components(s.date).day)
        let current = s.month.hardwareRevenue / Double(daysIn) * 365
        if let last = s.history.last {
            let lastRate = last.hardwareRevenue * 12
            return daysIn < 10 ? lastRate : (current * 0.6 + lastRate * 0.4)
        }
        return current
    }

    /// The policy rate: the real Fed funds rate until late 2026, then the drifting rate — plus a rate shock's extra points (3.8).
    static func fedRate(_ s: GameState) -> Double {
        (Macro.historicalRate(s.year) ?? s.market.interestRate) + Crises.rateAdd(s)
    }

    /// 3.8: the credit score and the corporate rating are one system. The rating's score (leverage, interest cover,
    /// size, liquidity and runway) drives the credit score, so both read the same letter, and every loan prices off
    /// that letter's spread (small borrowers pay a little more), plus a credit crunch's premium.
    static func creditSpread(_ s: GameState) -> Double {
        let notch = Corporate.notch(forCreditScore: s.creditScore)
        let small = runRate(s) < 1e8 ? 1.5 : (runRate(s) < 1e9 ? 0.5 : 0)
        return Corporate.spreads[notch] + small + Crises.spreadAdd(s)
    }

    struct LoanQuote {
        var kind: LoanKind
        var max: Double
        var rate: Double
        var term: Int
        var available: Bool
        var reason: String
    }

    /// What you still owe on loans of one kind.
    static func owed(_ s: GameState, _ kind: LoanKind) -> Double {
        s.loans.filter { $0.kind == kind }.reduce(0) { $0 + $1.balance }
    }

    /// Each limit is net of what you already owe of that kind (3.8), so a line can't be drawn twice.
    static func loanQuotes(_ s: GameState) -> [LoanQuote] {
        let fed = max(0.25, fedRate(s) - s.traits.loanRate)
        let spread = creditSpread(s)
        let rr = runRate(s)
        let hw = hardwareValue(s)
        let lastRound = s.rounds.last
        let crunch = Crises.crunchSeverity(s)
        let notch = Corporate.notch(forCreditScore: s.creditScore)
        var out: [LoanQuote] = []
        let ff = s.loans.contains { $0.kind == .friends } || s.rounds.count > 1
        out.append(LoanQuote(kind: .friends, max: ff ? 0 : 250_000, rate: 2, term: 36, available: !ff,
                             reason: ff ? "Only once, before your Series A." : "Family money. Low rate, high awkwardness."))
        let bankOwed = owed(s, .bank)
        var bankMax = rr >= 1_000_000 ? max(0, rr * 1.5 - bankOwed) : 0
        var bankWhy = rr < 1_000_000 ? "Banks want at least $1M of annual revenue."
            : (bankMax > 0 ? "Up to 1.5x annual revenue, less the \(Fmt.money(bankOwed)) you already owe the bank." : "You've drawn the whole line: 1.5x annual revenue (\(Fmt.money(bankOwed)) owed).")
        if crunch > 0 && notch > 2 && bankMax > 0 {
            bankMax = 0
            bankWhy = "Credit crunch: banks are only lending to A-rated borrowers or better (you're \(Corporate.ratingName(notch)))."
        }
        out.append(LoanQuote(kind: .bank, max: bankMax, rate: fed + spread, term: 60, available: bankMax > 0, reason: bankWhy))
        let ltv = crunch > 0 ? 0.45 : 0.65
        let gpuMax = max(0, hw * ltv - owed(s, .gpuBacked))
        out.append(LoanQuote(kind: .gpuBacked, max: gpuMax, rate: fed + 6.5 + max(0, spread - 3) * 0.5, term: 48, available: gpuMax > 100_000,
                             reason: gpuMax > 100_000 ? "Secured by your hardware (\(Int(ltv * 100))% loan-to-value\(crunch > 0 ? " in the crunch" : "")). Default and they take the GPUs."
                                                       : (hw > 0 ? "Your hardware already backs as much as lenders will take." : "Buy hardware first — lenders take GPUs as collateral.")))
        var vdMax = 0.0
        var vdWhy = "Needs an equity round in the last 18 months."
        if let r = lastRound, GameCalendar.daysBetween(r.date, s.date) < 540 {
            let ventureOwed = owed(s, .venture)
            vdMax = max(0, r.amount * 0.35 - ventureOwed)
            vdWhy = vdMax > 0 ? "Up to 35% of your last round, less the \(Fmt.money(ventureOwed)) already lent. Includes small warrants."
                              : "You've borrowed 35% of your last round already (\(Fmt.money(ventureOwed)) owed)."
            if crunch >= 0.5 {
                vdMax = 0
                vdWhy = "Credit crunch: venture lenders have stopped writing new loans."
            }
        }
        out.append(LoanQuote(kind: .venture, max: vdMax, rate: fed + 4.5 + Crises.spreadAdd(s), term: 36, available: vdMax > 0, reason: vdWhy))
        var bondMax = 0.0
        var bondWhy = "Needs a $20B valuation or a public listing."
        if s.isPublic || s.valuation > 20e9 {
            let bondOwed = owed(s, .bond)
            bondMax = max(0, s.valuation * 0.15 - bondOwed)
            bondWhy = bondMax > 0 ? "Investment-grade style debt for large companies: up to 15% of your value, less \(Fmt.money(bondOwed)) of bonds outstanding."
                                  : "Your bonds already come to 15% of your value (\(Fmt.money(bondOwed)))."
            if crunch > 0 && !Corporate.investmentGrade(notch) {
                bondMax = 0
                bondWhy = "Credit crunch: bond buyers want investment grade (BBB or better); you're \(Corporate.ratingName(notch))."
            }
        }
        out.append(LoanQuote(kind: .bond, max: bondMax, rate: fed + spread * 0.6 + 0.8, term: 120, available: bondMax > 0, reason: bondWhy))
        return out
    }

    static func monthlyPayment(principal: Double, annualRate: Double, months: Int) -> Double {
        let r = annualRate / 100 / 12
        guard r > 0 else { return principal / Double(months) }
        return principal * r / (1 - pow(1 + r, -Double(months)))
    }

    static func roundName(amount: Double, index: Int) -> String {
        switch amount {
        case ..<3e6: return "Seed"
        case ..<30e6: return "Series A"
        case ..<120e6: return "Series B"
        case ..<500e6: return "Series C"
        case ..<2e9: return "Series D"
        case ..<10e9: return "Growth round"
        default: return "Mega round"
        }
    }

    static func ipoEligible(_ s: GameState) -> (Bool, String) {
        if s.isPublic { return (false, "Already public.") }
        let age = Double(GameCalendar.daysBetween(s.startDate, s.date)) / 365
        if age < 2 { return (false, "Companies need at least 2 years of history to list.") }
        if s.valuation < 3e9 && runRate(s) < 3e8 { return (false, "Needs a $3B valuation or $300M revenue run-rate.") }
        return (true, "Bankers are ready. An IPO sells ~12% of the company to public investors.")
    }
}
