import Foundation

/// Selling compute two ways: merchant chip sales (your custom and alien silicon, made for other companies) and
/// leasing idle accelerators to the market like a neocloud.
enum ChipBusiness {
    // MARK: Market

    /// Annual spend on AI accelerators across the industry.
    static func acceleratorSpend(_ y: Double) -> Double {
        interpolateLog([(2016.5, 3e9), (2018, 6e9), (2020, 1.2e10), (2022, 2e10), (2023, 5e10), (2024, 1.2e11),
                        (2025, 2e11), (2026, 3e11), (2028, 5e11), (2030, 8e11), (2035, 1.5e12)], at: y, extrapolate: true)
    }

    /// Street price of a part, without the discounts your own deals get you.
    static func listPrice(_ a: Accelerator, _ s: GameState) -> Double {
        guard let base = a.price else { return 30_000 }
        if a.vendor == .custom { return base }
        let age = Economy.ageYears(a, s)
        let dep = max(age > 1.5 ? pow(0.83, age - 1.5) : 1, 0.22)
        return base * dep * s.market.hardwarePrice
    }

    static func shippedTotal(_ s: GameState) -> Double { s.chipLines.reduce(0) { $0 + $1.shipped } }

    /// Buyers trust vendors whose software stack has shipped at volume — the CUDA moat works against you at first.
    static func reputation(_ s: GameState) -> Double {
        clamp(0.05 + 0.15 * log10(1 + shippedTotal(s) / 50_000), 0.05, 1)
    }

    /// Performance per dollar vs today's best NVIDIA/AMD part.
    static func valueRatio(chip: Accelerator, price: Double, _ s: GameState) -> Double {
        let ref = Silicon.reference(s)
        let refPrice = listPrice(ref, s)
        return (chip.best / max(price, 1)) / (ref.best / max(refPrice, 1))
    }

    static func marketShare(value v: Double, reputation rep: Double) -> Double {
        let a = 0.3 * pow(max(v, 0.01), 1.4) * rep / 0.5
        return 0.35 * a / (1 + a)
    }

    /// Units per day buyers would take at `price`.
    static func demand(chip: Accelerator, price: Double, sellToRivals: Bool, _ s: GameState) -> Double {
        let spendDay = acceleratorSpend(s.year) * clamp(s.market.hype / 1.3, 0.6, 1.6) / 365
        let share = marketShare(value: valueRatio(chip: chip, price: price, s), reputation: reputation(s))
        return spendDay * (sellToRivals ? 1 : 0.5) * share / max(price, 1) * max(0.3, 1 + s.traits.chipSales)
    }

    static func defaultPrice(_ chip: Accelerator, alien: Bool, _ s: GameState) -> Double {
        let ref = Silicon.reference(s)
        let p = listPrice(ref, s) * chip.best / max(ref.best, 1) * (alien ? 0.5 : 0.85)
        return max((chip.price ?? 1_000) * 1.2, (p / 100).rounded() * 100)
    }

    /// Foundry capacity reservation per chip-a-month: tooling, CoWoS slots and HBM prepayments.
    static func capacityCost(_ chip: Accelerator, units: Double, _ s: GameState) -> Double {
        units * (listPrice(Silicon.reference(s), s) * 0.5 + (chip.price ?? 10_000) * 2) + 2e7
    }

    static func isAlien(_ chipID: String, _ s: GameState) -> Bool {
        s.customChips.first { $0.id == chipID }?.alien ?? false
    }

    static func ensureLine(_ s: inout GameState, chipID: String) {
        if let i = s.chipLines.firstIndex(where: { $0.chipID == chipID }) {
            s.chipLines[i].active = true
            return
        }
        guard let chip = HardwareCatalog.get(chipID) else { return }
        s.chipLines.append(ChipLine(chipID: chipID, price: defaultPrice(chip, alien: isAlien(chipID, s), s),
                                    sellToRivals: (s.exclusiveSupplyUntil ?? .distantPast) <= s.date))
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        leases(&s)
        guard !s.chipLines.isEmpty else { return }
        let h100 = HardwareCatalog.h100
        for i in s.chipLines.indices {
            if let ready = s.chipLines[i].pendingReady, ready <= s.date {
                s.chipLines[i].capacityMonth += s.chipLines[i].pendingCapacity
                let name = HardwareCatalog.get(s.chipLines[i].chipID)?.name ?? "your chip"
                Sim.news(&s, "Foundry capacity online: \(name)", "Now \(Fmt.count(s.chipLines[i].capacityMonth)) chips a month for customers.",
                         .hardware, image: "wafer", good: true)
                s.chipLines[i].pendingCapacity = 0
                s.chipLines[i].pendingReady = nil
            }
            s.chipLines[i].unitsToday = 0
            s.chipLines[i].demandToday = 0
            let line = s.chipLines[i]
            guard line.active, let chip = HardwareCatalog.get(line.chipID), let unitCost = chip.price else { continue }
            // 3.9: an exclusive-supply promise keeps every chip of this line away from rival labs.
            let toRivals = line.sellToRivals && Semis.exclusiveUntil(s) == nil
            let want = demand(chip: chip, price: line.price, sellToRivals: toRivals, s)
            let cap = min(want, AlienFab.isAlienChip(line.chipID) ? AlienFab.merchantPerLine(s) : line.capacityMonth / 30.4)
            s.chipLines[i].demandToday = want
            guard cap > 0 else { continue }
            let perUnitH100e = chip.bf16 / h100.bf16
            // Each buyer takes its share; a rival lab only what its cash can carry, and it pays from that cash.
            var units = 0.0, resold = 0.0
            for (id, w) in BigPlayerCatalog.buyers(s, includeRivals: toRivals) {
                var u = cap * w
                if let ci = s.competitors.firstIndex(where: { $0.id == id }) {
                    u = min(u, Semis.rivalBudgetDay(s, id) / max(1, line.price))
                    guard u > 0 else { continue }
                    s.competitors[ci].cash -= u * line.price
                    s.competitors[ci].armedH100e += u * perUnitH100e
                } else {
                    // Clouds resell a share of what they buy to the labs anyway (not during an exclusive deal).
                    if toRivals { resold += u * 0.3 }
                }
                s.chipLines[i].buyerUnits[id, default: 0] += u
                units += u
            }
            s.chipLines[i].unitsToday = units
            guard units > 0 else { continue }
            let revenue = units * line.price
            let cogs = units * unitCost
            s.cash += revenue - cogs
            s.month.revChips += revenue
            s.month.costChips += cogs
            s.lifetimeRevenue += revenue
            s.chipLines[i].shipped += units
            s.chipLines[i].revenue += revenue
            s.chipLines[i].profit += revenue - cogs
            if resold > 0 {
                // The rivals pay the clouds for those chips (the clouds already paid you).
                let rivals = BigPlayerCatalog.buyers(s, includeRivals: true).filter { BigPlayerCatalog.isRival($0.id) }
                let total = rivals.reduce(0) { $0 + $1.weight }
                for r in rivals where total > 0 {
                    guard let ci = s.competitors.firstIndex(where: { $0.id == r.id }) else { continue }
                    let u = min(resold * r.weight / total, Semis.rivalBudgetDay(s, r.id) / max(1, line.price))
                    guard u > 0 else { continue }
                    s.competitors[ci].cash -= u * line.price
                    s.competitors[ci].armedH100e += u * perUnitH100e
                }
            }
        }
        if s.chipLines.reduce(0, { $0 + $1.revenue }) >= 1e9 { Achievements.unlock(&s, "merchant") }
    }

    // MARK: Leasing

    /// What the market pays per chip-hour for an accelerator (before your platform's occupancy and fees).
    static func listRate(_ a: Accelerator, _ s: GameState) -> Double {
        if let base = a.rent {
            let age = max(0, Economy.ageYears(a, s))
            return max(a.rentFloor, base * pow(0.78, age)) * s.market.rentPrice
        }
        let h = HardwareCatalog.h100
        guard a.id != h.id, h.rent != nil else { return 1 }
        // Unknown silicon rents at a discount until customers trust its software stack.
        return listRate(h, s) * pow(max(a.best, 1) / h.best, 0.9) * 0.75
    }

    /// Share of leased capacity that's actually rented on a given day.
    static func occupancy(_ s: GameState, leasedH100e: Double) -> Double {
        let market = CompetitorCatalog.industryCompute(s.year) * 0.25
        let share = leasedH100e / max(1, market)
        return clamp(0.82 * min(1.1, s.market.hype / 1.3) / (1 + share * 4), 0.3, 0.95)
    }

    static let platformFee = 0.12

    static func leasedH100e(_ s: GameState) -> Double {
        s.leases.sorted { $0.key < $1.key }.reduce(0) { acc, kv in acc + Double(kv.value) * (HardwareCatalog.get(kv.key)?.bf16 ?? 0) / HardwareCatalog.h100.bf16 }   // 3.7: fixed order
    }

    /// Daily income from leasing `count` more (or the current) chips of a type.
    static func leaseIncomePerDay(_ a: Accelerator, count: Int, _ s: GameState) -> Double {
        let extra = Double(count) * a.bf16 / HardwareCatalog.h100.bf16
        let occ = occupancy(s, leasedH100e: leasedH100e(s) + extra)
        return Double(count) * listRate(a, s) * 24 * occ * (1 - platformFee)
    }

    static func leases(_ s: inout GameState) {
        s.leaseRevenueToday = 0
        guard !s.leases.isEmpty else { return }
        let occ = occupancy(s, leasedH100e: leasedH100e(s))
        let committed = RivalEconomy.committedH100e(s)   // 3.8: chips a rival has rented in full under a compute commitment
        var revenue = 0.0
        var chips = 0
        for (id, n) in s.leases.sorted(by: { $0.key < $1.key }) where n > 0 {   // 3.7: fixed order (float sums)
            guard let a = HardwareCatalog.get(id) else { continue }
            let full = min(Double(n), (committed[id] ?? 0) / RivalEconomy.h100e(a))
            revenue += ((Double(n) - full) * occ + full) * listRate(a, s) * 24 * (1 - platformFee)
            chips += n
        }
        s.leaseRevenueToday = revenue
        s.cash += revenue
        s.month.revCloud += revenue
        s.lifetimeRevenue += revenue
        if chips >= 10_000 { Achievements.unlock(&s, "landlord") }
    }
}

// MARK: - Player actions

extension GameState {
    mutating func openChipLine(_ chipID: String) -> String? {
        guard customChips.contains(where: { $0.id == chipID }), HardwareCatalog.get(chipID) != nil else { return "Only chips you designed can be sold." }
        if Semis.isSemiChip(chipID) { return "Sell this chip from the Semiconductors page (Sales)." }
        // 3.9: selling a chip means making it — wafers, packaging and HBM on the Semiconductors page. Chips from the old
        // at-cost programmes stay yours to buy; lines already open keep their capacity.
        if !ChipBusiness.isAlien(chipID, self) && !chipLines.contains(where: { $0.chipID == chipID }) {
            return "This chip came from a partner programme that builds only for you. To sell chips, design one on the Semiconductors page and make it there."
        }
        if let ai = alienArchs.firstIndex(where: { $0.chipID == chipID }), alienArchs[ai].policy != .sellChips {
            alienArchs[ai].policy = .sellChips
            alienArchs[ai].offers = []
        }
        ChipBusiness.ensureLine(&self, chipID: chipID)
        Sim.news(&self, "\(HardwareCatalog.get(chipID)?.name ?? "Your chip") is for sale",
                 "Reserve foundry capacity to start shipping. Hyperscalers, sovereign funds and rival labs are listening.", .hardware, image: "wafer")
        return nil
    }

    mutating func setChipLine(_ chipID: String, price: Double? = nil, active: Bool? = nil, sellToRivals: Bool? = nil) -> String? {
        guard let i = chipLines.firstIndex(where: { $0.chipID == chipID }) else { return "Not found." }
        if let price {
            let floor = HardwareCatalog.get(chipID)?.price ?? 0
            if price < floor { return "That's below your production cost of \(Fmt.money(floor))." }
            chipLines[i].price = price
        }
        if let active {
            if active, let ai = alienArchs.firstIndex(where: { $0.chipID == chipID }), alienArchs[ai].policy != .sellChips {
                alienArchs[ai].policy = .sellChips
                alienArchs[ai].offers = []
            }
            chipLines[i].active = active
        }
        if let sellToRivals {
            if sellToRivals, let until = Semis.exclusiveUntil(self) { return "You promised exclusive supply until \(until.gameShort)." }
            chipLines[i].sellToRivals = sellToRivals
        }
        return nil
    }

    /// Alien chips come off your own alien fab line (3.5): expanding it serves sales and your own orders. 3.9: other
    /// lines (from the old partner programmes) keep the capacity they have — new capacity for your own chips is wafers,
    /// packaging and HBM booked on the Semiconductors page, not one payment.
    mutating func addFabCapacity(_ chipID: String, units: Double) -> String? {
        guard let i = chipLines.firstIndex(where: { $0.chipID == chipID }), HardwareCatalog.get(chipID) != nil else { return "Open a sales line first." }
        if AlienFab.isAlienChip(chipID) { return expandAlienFab(units: units) }
        return "New capacity for your own chips is booked as wafers, packaging and HBM on the Semiconductors page. This line keeps the \(Fmt.count(chipLines[i].capacityMonth)) a month it has."
    }

    /// Lease `chips` owned accelerators of a type to the market (0 recalls them).
    mutating func setLease(_ accelID: String, chips: Int) -> String? {
        guard let a = HardwareCatalog.get(accelID) else { return "Unknown hardware." }
        let pool = Economy.pool(self, accelID)
        let current = leases[accelID] ?? 0
        let free = (pool?.free ?? 0) + current
        let owned = pool?.owned ?? 0
        if chips < 0 { return "Pick a number of chips." }
        if chips > owned { return "You can only lease chips you own (\(Fmt.int(owned)) \(a.name))." }
        if chips > free { return "Only \(Fmt.int(free)) \(a.name) are idle. Free some up first." }
        leases[accelID] = chips > 0 ? chips : nil
        return nil
    }
}
