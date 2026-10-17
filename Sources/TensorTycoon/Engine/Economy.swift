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
    }

    static func rent(_ a: Accelerator, _ s: GameState) -> Double? {
        guard let base = a.rent else { return nil }
        let age = max(0, ageYears(a, s))
        let decayed = max(a.rentFloor, base * pow(0.78, age))
        let mult = a.cls == .consumer ? (s.market.consumerGPUPrice + s.market.rentPrice) / 2 : s.market.rentPrice
        return decayed * mult * (1 - dealDiscount(a, s)) * (1 - Partners.discount(a, s)) * (1 - s.traits.hardware)
            * (s.lawsPassed.contains("nairr") ? 0.95 : 1)
    }

    static func resaleValue(_ a: Accelerator, _ s: GameState, unitCost: Double, purchased: Date) -> Double {
        let years = Double(GameCalendar.daysBetween(purchased, s.date)) / 365
        let market = price(a, s) ?? (a.price ?? unitCost) * max(0.15, pow(0.78, ageYears(a, s)))
        let wear = max(0.3, 1 - 0.1 * years)
        return min(unitCost, market) * 0.85 * wear
    }

    static func leadTimeDays(_ a: Accelerator, _ s: GameState) -> Int {
        if a.cls == .consumer || a.cls == .workstation { return 4 }
        if a.vendor == .custom { return 45 }
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

    /// Chips of this type in the world's rentable cloud fleet today.
    static func cloudSupply(_ a: Accelerator, _ s: GameState) -> Double {
        let y = s.year
        let mine = fleetWeight(a) * fleetLife(a, y)
        guard mine > 0 else { return 0 }
        let total = HardwareCatalog.all.reduce(0.0) { $0 + ($1.rentable ? fleetWeight($1) * fleetLife($1, y) : 0) }
        return worldFleet(y) * mine / max(total, 1e-9) * HardwareCatalog.h100.bf16 / max(a.bf16, 1)
    }

    /// Chips of this type the world's fabs ship per quarter (the fleet roughly doubles every year).
    static func quarterlyProduction(_ a: Accelerator, _ s: GameState) -> Double {
        let y = s.year
        let mine = fleetWeight(a) * productionLife(a, y)
        guard mine > 0 else { return 0 }
        let total = HardwareCatalog.all.reduce(0.0) { $0 + ($1.purchasable ? fleetWeight($1) * productionLife($1, y) : 0) }
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
        if a.vendor == .custom { return 20_000_000 }
        let cutoff = GameCalendar.addDays(s.date, -90)
        let recent = s.orders.filter { $0.accelID == a.id && $0.ordered > cutoff }.reduce(0) { $0 + $1.count }
            + s.orderLog.filter { $0.accelID == a.id && $0.ordered > cutoff }.reduce(0) { $0 + $1.count }
        let cap = quarterlyProduction(a, s) * allocationShare(a, s)
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
    static func rentedShare(_ a: Accelerator, _ s: GameState) -> Double {
        let mine = Double(s.rentals.filter { $0.accelID == a.id }.reduce(0) { $0 + $1.count })
        return mine / max(1, cloudSupply(a, s))
    }

    /// What a new rental costs: the market rate, plus 2% for every 1% of the world's supply you already hold.
    static func rentQuote(_ a: Accelerator, _ s: GameState) -> Double? {
        rent(a, s).map { $0 * (1 + 2 * rentedShare(a, s)) }
    }

    /// Server overhead included (CPU, NICs, fans).
    static func chipKW(_ a: Accelerator) -> Double { a.tdpW * 1.25 / 1000 }

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
        }
        for i in s.models.indices where !s.models[i].retired {
            for d in s.models[i].deployments { inference[d.accelID, default: 0] += d.chips }
        }
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
        return out.sorted { $0.accel.best * Double($0.total) > $1.accel.best * Double($1.total) }
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

    /// Effective $/day for `count` chips: rental rate if the company rents them, otherwise power + 4-year amortisation.
    static func chipDailyCost(_ a: Accelerator, count: Int, state s: GameState) -> Double {
        if let r = s.rentals.first(where: { $0.accelID == a.id }) {
            return r.hourly * 24 * Double(count)
        }
        let unit = price(a, s) ?? (a.price ?? 0)
        let amort = unit / (4 * 365)
        let site = s.sites.first { $0.kind != .garage } ?? s.sites.first
        let power = chipKW(a) * (site?.pue ?? 1.4) * 24 * (site?.powerPrice ?? 0.1)
        if a.purchasable || s.owned.contains(where: { $0.accelID == a.id }) {
            return (amort + power) * Double(count)
        }
        return (rent(a, s) ?? 0) * 24 * Double(count)
    }

    static func siteLoadKW(_ s: GameState, _ siteID: UUID) -> Double {
        s.owned.filter { $0.siteID == siteID }.reduce(0) { acc, b in
            acc + (HardwareCatalog.get(b.accelID).map(chipKW) ?? 0) * Double(b.count)
        } + s.orders.filter { $0.siteID == siteID }.reduce(0) { acc, o in
            acc + (HardwareCatalog.get(o.accelID).map(chipKW) ?? 0) * Double(o.count)
        }
    }

    static func hardwareValue(_ s: GameState) -> Double {
        s.owned.reduce(0) { acc, b in
            guard let a = HardwareCatalog.get(b.accelID) else { return acc }
            return acc + resaleValue(a, s, unitCost: b.unitCost, purchased: b.purchased) * Double(b.count)
        }
    }

    static func siteValue(_ s: GameState) -> Double {
        s.sites.filter { $0.kind == .datacenter }.reduce(0) { $0 + $1.capex * 0.8 }
    }

    static func debt(_ s: GameState) -> Double { s.loans.reduce(0) { $0 + $1.balance } }

    static func payrollYear(_ s: GameState) -> Double { s.employees.reduce(0) { $0 + $1.salary } * max(0.5, 1 + s.traits.payroll) }

    static let officeLevels: [(name: String, capacity: Int, monthly: Double, image: String)] = [
        ("Garage", 6, 0, "garage"),
        ("Startup office", 25, 30_000, "garage"),
        ("Floor in SF", 120, 180_000, "sf_skyline"),
        ("HQ building", 600, 1_200_000, "sf_skyline"),
        ("Corporate campus", 3_000, 6_000_000, "nvidia_hq"),
        ("Mega campus", 15_000, 25_000_000, "nvidia_hq"),
    ]

    static func officeCapacity(_ s: GameState) -> Int { officeLevels[min(s.officeLevel, officeLevels.count - 1)].capacity }

    static func dataMonthlyCost(_ s: GameState) -> Double {
        s.dataSources.compactMap { DataCatalog.byID[$0] }.reduce(0) { $0 + $1.monthly }
    }

    // MARK: Revenue & valuation

    static func runRate(_ s: GameState) -> Double {
        let daysIn = max(1, GameCalendar.components(s.date).day)
        let current = s.month.revenue / Double(daysIn) * 365
        if let last = s.history.last {
            let lastRate = last.revenue * 12
            return daysIn < 10 ? lastRate : (current * 0.6 + lastRate * 0.4)
        }
        return current
    }

    static func valuation(_ s: GameState) -> Double {
        if s.isPublic { return s.sharePrice * s.totalShares }
        let y = s.year
        // Chip sales and leased compute earn hardware multiples, not software ones.
        let rr = max(0, runRate(s) - 0.6 * hardwareRunRate(s))
        var growth = 0.0
        if s.history.count >= 7 {
            let now = s.history.last!.revenue
            let then = s.history[s.history.count - 7].revenue
            if then > 0 { growth = clamp(pow(now / then, 2) - 1, 0, 4) }
        }
        let revVal = rr * Macro.revenueMultiple(y) * (1 + growth * 0.25)
        let best = s.models.map { $0.released ? $0.c : $0.c - 0.15 }.max() ?? -5
        let gap = best - Macro.frontier(y)
        let age = Double(GameCalendar.daysBetween(s.startDate, s.date)) / 365
        let maturity = clamp(0.3 + age * 0.3, 0.3, 1.0)
        let hypeVal = 0.55 * Macro.frontierValuation(y) * exp(2.4 * min(gap, 0.5)) * (s.market.hype / 1.3)
            * pow(max(5, s.brand) / 60, 0.4) * maturity
        let talent = s.employees.reduce(0.0) { $0 + ($1.role == .researcher ? $1.skill * 40_000 : $1.skill * 10_000) } * (y > 2023 ? 3 : 1)
        let seed = Macro.seedValuation(y) * min(1.5, 0.6 + Double(s.employees.count) * 0.1)
        let assets = max(0, hardwareValue(s) + siteValue(s) - debt(s))
        return max(max(revVal, hypeVal, seed, talent) + assets * 0.6 + Xeno.moatValue(s) + RivalEconomy.stakesValue(s) * 0.9, roundFloor(s))
    }

    /// The last round's post-money, written down 30% a year (to at most 40% off): a private mark rarely falls faster.
    static func roundFloor(_ s: GameState) -> Double {
        guard let r = s.rounds.last else { return 0 }
        let years = Double(GameCalendar.daysBetween(r.date, s.date)) / 365
        return (r.preMoney + r.amount) * max(0.4, 1 - 0.3 * years)
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

    static func fedRate(_ s: GameState) -> Double {
        Macro.historicalRate(s.year) ?? s.market.interestRate
    }

    static func creditSpread(_ s: GameState) -> Double {
        clamp((760 - s.creditScore) / 40, 1.0, 12.0)
    }

    struct LoanQuote {
        var kind: LoanKind
        var max: Double
        var rate: Double
        var term: Int
        var available: Bool
        var reason: String
    }

    static func loanQuotes(_ s: GameState) -> [LoanQuote] {
        let fed = max(0.25, fedRate(s) - s.traits.loanRate)
        let spread = creditSpread(s)
        let rr = runRate(s)
        let hw = hardwareValue(s)
        let gpuDebt = s.loans.filter { $0.kind == .gpuBacked }.reduce(0) { $0 + $1.balance }
        let lastRound = s.rounds.last
        var out: [LoanQuote] = []
        let ff = s.loans.contains { $0.kind == .friends } || s.rounds.count > 1
        out.append(LoanQuote(kind: .friends, max: ff ? 0 : 250_000, rate: 2, term: 36, available: !ff,
                             reason: ff ? "Only once, before your Series A." : "Family money. Low rate, high awkwardness."))
        let bankMax = rr >= 1_000_000 ? rr * 1.5 : 0
        out.append(LoanQuote(kind: .bank, max: bankMax, rate: fed + spread, term: 60, available: bankMax > 0,
                             reason: bankMax > 0 ? "Up to 1.5x annual revenue." : "Banks want at least $1M of annual revenue."))
        let gpuMax = max(0, hw * 0.65 - gpuDebt)
        out.append(LoanQuote(kind: .gpuBacked, max: gpuMax, rate: fed + 6.5 + max(0, spread - 3) * 0.5, term: 48, available: gpuMax > 100_000,
                             reason: gpuMax > 100_000 ? "Secured by your hardware (65% loan-to-value). Default and they take the GPUs."
                                                       : "Buy hardware first — lenders take GPUs as collateral."))
        var vdMax = 0.0
        if let r = lastRound, GameCalendar.daysBetween(r.date, s.date) < 540 { vdMax = r.amount * 0.35 }
        out.append(LoanQuote(kind: .venture, max: vdMax, rate: fed + 4.5, term: 36, available: vdMax > 0,
                             reason: vdMax > 0 ? "Up to 35% of your last round. Includes small warrants." : "Needs an equity round in the last 18 months."))
        let bondMax = (s.isPublic || s.valuation > 20e9) ? s.valuation * 0.15 : 0
        out.append(LoanQuote(kind: .bond, max: bondMax, rate: fed + spread * 0.6 + 0.8, term: 120, available: bondMax > 0,
                             reason: bondMax > 0 ? "Investment-grade style debt for large companies." : "Needs a $20B valuation or a public listing."))
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
