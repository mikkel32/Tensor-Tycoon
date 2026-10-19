import Foundation

/// Datacenter campuses at gigawatt scale: how big one site can get on each kind of power, phased construction
/// (big campuses come online a phase at a time, each phase paid for as it starts), selling sites and moving chips.
enum Campus {
    /// Largest site at `loc` on `deal` power this year, in MW (at most 100 GW).
    static func siteCapMW(_ loc: Location, _ deal: PowerDeal, _ s: GameState) -> Double {
        var grid = loc.gridCap(s.year)
        if deal == .solar || deal == .wind { grid *= 1.5 }
        if XenoScience.megaDone(s, "supergrid") { grid *= 2 }
        return min(100_000, max(grid, deal.siteCapMW))
    }

    /// The most a colocation provider leases to one tenant in one place.
    static let coloCapMW = 500.0

    /// 3.5: the most this site can grow to: its power source's limit, plus grid capacity won in the interconnection queue,
    /// on-site generation and a little peak-shaving from batteries.
    static func siteLimitMW(_ site: Site, _ deal: PowerDeal? = nil, _ s: GameState) -> Double {
        let d = deal ?? site.powerDeal
        // Power sources that are their own ceiling (gas, reactors, fusion) already assume you build the plant.
        let connection = siteCapMW(site.location, d.siteCapMW > 0 ? .grid : d, s) + site.gridExtraKW / 1000 + site.onsiteKW / 1000
        return min(100_000, max(siteCapMW(site.location, d, s), connection) + site.batteryMWh / 4 * 0.1)
    }

    /// 3.5: retrofitting `site` to better cooling.
    static func coolingRetrofitCost(_ site: Site, to: Cooling, _ s: GameState) -> Double {
        let mw = site.capacityKW / 1000
        return mw * (max(0, to.capexPerMW - site.cooling.capexPerMW) + 2_000_000) * (s.year > 2024 ? 1.15 : 1)
    }

    /// 3.5: the next rack generation at `site`.
    static func generationCost(_ site: Site, _ s: GameState) -> Double {
        site.capacityKW / 1000 * 2_000_000 * (1 + 0.5 * Double(site.generation))
    }

    /// 3.5: each phase of a campus still to finish: (kW, cost, start, ready, building now).
    static func schedule(_ site: Site, _ s: GameState) -> [(kw: Double, cost: Double, start: Date, ready: Date, building: Bool)] {
        guard site.kind == .datacenter else { return [] }
        var out: [(kw: Double, cost: Double, start: Date, ready: Date, building: Bool)] = []
        var cursor = s.date
        if !site.isReady(s.date) {
            out.append((site.capacityKW, 0, site.opened, site.ready, true))
            cursor = site.ready
        }
        if site.expanding > 0, let r = site.expansionReady {
            out.append((site.expanding, 0, s.date, r, true))
            cursor = max(cursor, r)
        }
        var left = site.plannedKW
        while left > 0.5 && out.count < 12 {
            let kw = min(left, max(site.phaseKW, 1_000))
            let months = s.buildMonths(mw: kw / 1000, loc: site.location, power: site.powerDeal) * 0.35
            let ready = GameCalendar.addDays(cursor, max(30, Int(months * 30.4)))
            out.append((kw, kw / 1000 * capexPerMW(site.cooling, s, location: site.locationID), cursor, ready, false))
            cursor = ready
            left -= kw
        }
        return out
    }

    /// Construction cost per MW: shell, substation, cooling (chips not included).
    static func capexPerMW(_ c: Cooling, _ s: GameState) -> Double {
        c.capexPerMW * (s.year > 2024 ? 1.15 : 1)
    }

    /// What building a MW costs you at `location`: less at home where your country's incentives apply (3.4 overhaul:
    /// taken off each phase as it's paid for; campuses you buy, retrofits and on-site plants pay full price).
    static func capexPerMW(_ c: Cooling, _ s: GameState, location: String) -> Double {
        capexPerMW(c, s) * HQ.buildCost(s, location: location)
    }

    /// One phase up to 400 MW; bigger campuses are split into up to eight phases.
    static func phases(mw: Double) -> Int { mw <= 400 ? 1 : min(8, Int((mw / 1_000).rounded(.up)) + 1) }

    /// Builders get faster as prefab halls, robots and AI-run project management arrive.
    static func speedup(_ y: Double) -> Double { interpolate([(2024, 1.0), (2028, 1.3), (2030, 1.7), (2035, 3.0)], at: y) }

    /// What a buyer pays for a site (more in a hot market).
    static func salePrice(_ site: Site, _ s: GameState) -> Double {
        guard site.kind == .datacenter else { return 0 }
        let built = site.isReady(s.date) ? 0.7 : 0.45
        return site.capex * built * clamp(s.market.hype, 0.7, 1.3)
    }

    /// Trucking, re-racking and burn-in per chip.
    static func moveCostPerChip(_ a: Accelerator) -> Double { 150 + 0.01 * (a.price ?? 20_000) }

    /// Capacity of a site including phases being built and planned, in kW.
    static func plannedTotalKW(_ site: Site) -> Double { site.capacityKW + site.expanding + site.plannedKW }

    /// Starts the next phase of a phased campus, if it has one waiting and you can pay for it.
    /// Later phases go faster than the first: the site is permitted, connected and the crews are on site.
    static func startNextPhase(_ s: inout GameState, _ i: Int, factor: Double = 0.35) {
        let site = s.sites[i]
        guard site.kind == .datacenter, site.plannedKW > 0, site.expanding == 0, site.isReady(s.date) else { return }
        let kw = min(site.plannedKW, max(site.phaseKW, 1_000))
        let capex = kw / 1000 * capexPerMW(site.cooling, s, location: site.locationID)
        guard capex <= s.cash else {
            if !site.phaseBlocked {
                s.sites[i].phaseBlocked = true
                Sim.news(&s, "\(site.name): next phase waits for cash",
                         "The next \(Fmt.watts(kw * 1000)) phase costs \(Fmt.money(capex)). Construction resumes as soon as you can pay.",
                         .company, important: true, good: false)
            }
            return
        }
        s.cash -= capex
        s.month.capex += capex
        s.sites[i].capex += capex
        HQ.noteIncentive(&s, gross: kw / 1000 * capexPerMW(site.cooling, s), net: capex)
        s.sites[i].plannedKW -= kw
        s.sites[i].expanding = kw
        s.sites[i].phaseBlocked = false
        let months = s.buildMonths(mw: kw / 1000, loc: site.location, power: site.powerDeal) * factor
        s.sites[i].expansionReady = GameCalendar.addDays(s.date, max(30, Int(months * 30.4)))
    }

    /// Daily: finish phases that are done and start the next ones.
    static func daily(_ s: inout GameState) {
        DCMarket.daily(&s)   // 3.5: listings, leases, subleases, upgrades
        Power.daily(&s)      // 3.5: power contracts
        for i in s.sites.indices where s.sites[i].kind == .datacenter && s.sites[i].plannedKW > 0 && s.sites[i].expanding == 0 {
            startNextPhase(&s, i)
        }
        let total = s.sites.filter { $0.isReady(s.date) }.reduce(0) { $0 + $1.capacityKW }
        if total >= 100_000_000 { Achievements.unlock(&s, "hundred_gw") }
    }

    /// The most chips of `a` you could order for `site` right now: allocation, cash and free power.
    static func maxOrder(_ a: Accelerator, site: Site, _ s: GameState) -> Int {
        guard let unit = Economy.price(a, s), unit > 0 else { return 0 }
        let freeKW = max(0, site.capacityKW - Economy.siteLoadKW(s, site.id))
        var n = min(Double(Economy.allocationLimit(a, s)), max(0, s.cash) / unit, freeKW / max(0.001, Economy.chipKW(a)))
        n = max(0, n.rounded(.down))
        let step = max(1, a.minOrder)
        return Int(n) / step * step
    }
}

// MARK: - Player actions

extension GameState {
    /// Stop building the phases of a campus that haven't started yet (nothing is charged for them).
    mutating func cancelPlannedPhases(_ id: UUID) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if sites[i].plannedKW <= 0 { return "No phases are waiting." }
        let kw = sites[i].plannedKW
        sites[i].plannedKW = 0
        sites[i].phaseBlocked = false
        Sim.news(&self, "\(sites[i].name): remaining phases cancelled", "\(Fmt.watts(kw * 1000)) of planned capacity won't be built.", .company)
        return nil
    }

    /// Sell a datacenter to a hyperscaler or end a colocation lease. The site must be empty.
    mutating func sellSite(_ id: UUID) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let site = sites[i]
        if site.kind == .garage || site.kind == .office { return "You can't sell your home base." }
        let housed = owned.filter { $0.siteID == id }.reduce(0) { $0 + $1.count }
        if housed > 0 { return "Move or sell the \(Fmt.int(housed)) chips housed here first." }
        if orders.contains(where: { $0.siteID == id }) { return "Hardware is on its way to this site. Let it arrive, then move it." }
        if site.subleasedKW > 0 && site.kind == .colo { return "\(site.subleaseTenant) rents space here until \(site.subleaseEnd?.gameShort ?? "later"). End the sublease first." }
        if site.kind == .colo {
            let penalty = site.isTermLease ? DCMarket.exitFee(site, self) : site.monthlyFee
            if penalty > cash { return site.isTermLease ? "Ending the lease early costs half the rent left, \(Fmt.money(penalty))." : "Ending the lease early costs a month's fee (\(Fmt.money(penalty)))." }
            cash -= penalty
            month.costSites += penalty
            sites.remove(at: i)
            Sim.news(&self, "Lease ended: \(site.name)", "\(Fmt.watts(site.capacityKW * 1000)) handed back. Early-exit fee: \(Fmt.money(penalty)).", .company)
            return nil
        }
        let price = Campus.salePrice(site, self)
        cash += price
        sites.remove(at: i)
        powerContracts.removeAll { $0.siteID == id }
        Sim.news(&self, "Sold \(site.name)", "A hyperscaler bought the \(Fmt.watts(Campus.plannedTotalKW(site) * 1000)) campus for \(Fmt.money(price)) (\(Fmt.money(site.capex)) invested).",
                 .company, image: "hyperscale_campus", important: true)
        return nil
    }

    /// Truck chips to another site. Chips leaving the live fleet for a site still being built must be idle.
    mutating func moveHardware(batchID: UUID, count: Int, to siteID: UUID) -> String? {
        guard let bi = owned.firstIndex(where: { $0.id == batchID }), let a = HardwareCatalog.get(owned[bi].accelID) else { return "Not found." }
        guard let dest = sites.first(where: { $0.id == siteID }) else { return "Pick a site." }
        let batch = owned[bi]
        if batch.siteID == siteID { return "Those chips are already there." }
        let n = min(count, batch.count)
        if n <= 0 { return "Move at least one chip." }
        if a.tdpW > dest.maxChipTDP { return "\(dest.name) can't power or cool \(Int(a.tdpW)) W parts." }
        if a.liquid && !dest.cooling.supportsLiquidChips { return "\(a.name) needs liquid cooling; \(dest.name) is air-cooled." }
        let needKW = Economy.chipKW(a) * Double(n)
        let freeKW = dest.capacityKW - Economy.siteLoadKW(self, siteID)
        if needKW > freeKW + 0.01 { return "Not enough power at \(dest.name): needs \(Fmt.watts(needKW * 1000)), \(Fmt.watts(max(0, freeKW) * 1000)) free." }
        let fromReady = sites.first { $0.id == batch.siteID }?.isReady(date) ?? false
        if fromReady && !dest.isReady(date) {
            let free = Economy.pool(self, a.id)?.free ?? 0
            if n > free { return "Only \(Fmt.int(free)) of these chips are idle. \(dest.name) isn't online yet, so busy chips can't go there." }
        }
        let cost = Double(n) * Campus.moveCostPerChip(a)
        if cost > cash { return "Moving them costs \(Fmt.money(cost))." }
        cash -= cost
        month.costOther += cost
        owned[bi].count -= n
        if let j = owned.firstIndex(where: { $0.siteID == siteID && $0.accelID == a.id && $0.purchased == batch.purchased && $0.unitCost == batch.unitCost }) {
            owned[j].count += n
        } else {
            owned.append(OwnedBatch(accelID: a.id, count: n, siteID: siteID, purchased: batch.purchased, unitCost: batch.unitCost))
        }
        owned.removeAll { $0.count <= 0 }
        let from = sites.first { $0.id == batch.siteID }?.name ?? "storage"
        Sim.news(&self, "Moved \(Fmt.int(n))× \(a.name)", "From \(from) to \(dest.name). Logistics: \(Fmt.money(cost)).", .company, image: a.image,
                 illustrative: a.photoIsStandIn)
        return nil
    }
}
