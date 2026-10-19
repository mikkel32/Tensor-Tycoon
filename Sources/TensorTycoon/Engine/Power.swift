import Foundation

// MARK: - Power contracts (3.5)

/// What kind of power deal: a purchase agreement for power delivered over the grid, generation built on a site,
/// batteries, or a place in the grid-interconnection queue.
enum PowerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case solar = "Solar PPA"
    case wind = "Wind PPA"
    case hydro = "Hydro PPA"
    case geothermal = "Geothermal PPA"
    case nuclearRestart = "Nuclear restart PPA"
    case gasTurbines = "On-site gas turbines"
    case smr = "Small modular reactors"
    case fusion = "Fusion plant"
    case battery = "Battery storage"
    case interconnect = "Grid interconnection"

    var id: String { rawValue }

    /// Built on (or connected to) one of your sites, rather than bought over the grid.
    var onSite: Bool { [.gasTurbines, .smr, .fusion, .battery, .interconnect].contains(self) }
    /// Sold as energy: covers your sites' draw at the contract price.
    var suppliesEnergy: Bool { self != .battery && self != .interconnect }

    var symbol: String {
        switch self {
        case .solar: "sun.max.fill"
        case .wind: "wind"
        case .hydro: "drop.fill"
        case .geothermal: "flame.fill"
        case .nuclearRestart, .smr: "atom"
        case .gasTurbines: "fuelpump.fill"
        case .fusion: "sparkles"
        case .battery: "battery.100percent.bolt"
        case .interconnect: "point.3.connected.trianglepath.dotted"
        }
    }

    var image: String {
        switch self {
        case .solar: "solar_farm"
        case .wind: "power_wind"
        case .hydro: "power_hydro"
        case .geothermal: "power_geothermal"
        case .nuclearRestart: "power_nuclear2"
        case .smr: "nuclear"
        case .gasTurbines: "power_gas"
        case .fusion: "power_fusion"
        case .battery: "power_battery"
        case .interconnect: "power_lines"
        }
    }

    var green: Bool { self != .gasTurbines && self != .interconnect && self != .battery }

    var availableFrom: Double {
        switch self {
        case .nuclearRestart: 2024.7
        case .smr: 2030
        case .fusion: 2034.5
        case .battery: 2017
        default: 2010
        }
    }

    func available(_ s: GameState) -> Bool {
        if self == .fusion && XenoScience.megaDone(s, "supergrid") && s.year >= 2029 { return true }
        if self == .fusion { return s.year >= availableFrom - Science.fusionPullIn(s) - Progression.fusionPullIn(s) }   // 3.6: fusion-control discoveries; 3.7: Civilisational stage
        return s.year >= availableFrom
    }

    /// Where this kind of power can be had (on-site kinds work anywhere you have a campus).
    var locations: [String]? {
        switch self {
        case .solar: ["texas", "arizona", "uae", "nova", "iowa"]
        case .wind: ["texas", "iowa", "oregon", "quebec"]
        case .hydro: ["quebec", "oregon", "iceland"]
        case .geothermal: ["iceland", "oregon", "arizona"]
        case .nuclearRestart: ["nova", "iowa", "arizona", "texas"]
        default: nil
        }
    }

    /// Average output as a share of nameplate (contracts are sized in average, firm-equivalent megawatts).
    var capacityFactor: Double {
        switch self {
        case .solar: 0.25
        case .wind: 0.38
        case .hydro: 0.55
        case .geothermal: 0.9
        case .nuclearRestart: 0.92
        case .gasTurbines: 0.9
        case .smr: 0.93
        case .fusion: 0.9
        case .battery, .interconnect: 1
        }
    }

    /// Energy price in $/MWh in year `y`.
    func priceMWh(_ y: Double) -> Double {
        switch self {
        case .solar: interpolate([(2016, 62), (2020, 38), (2023, 52), (2026, 55), (2030, 40), (2035, 30)], at: y)
        case .wind: interpolate([(2016, 52), (2020, 38), (2023, 58), (2026, 62), (2030, 48), (2035, 40)], at: y)
        case .hydro: interpolate([(2016, 45), (2025, 52), (2035, 48)], at: y)
        case .geothermal: interpolate([(2016, 95), (2025, 88), (2030, 65), (2035, 48)], at: y)
        case .nuclearRestart: interpolate([(2024, 105), (2028, 95), (2035, 85)], at: y)
        case .gasTurbines: interpolate([(2016, 45), (2022, 70), (2024, 52), (2028, 60), (2035, 58)], at: y)
        case .smr: interpolate([(2030, 92), (2033, 70), (2036, 55), (2040, 45)], at: y)
        case .fusion: interpolate([(2034, 55), (2037, 30), (2040, 18)], at: y)
        case .battery, .interconnect: 0
        }
    }

    /// Construction cost per MW (on-site kinds; batteries per MW of 4-hour storage; interconnection: network upgrades and deposits).
    func capexPerMW(_ y: Double) -> Double {
        switch self {
        case .gasTurbines: interpolate([(2016, 900_000), (2023, 1_100_000), (2025, 2_000_000), (2027, 2_400_000), (2030, 1_700_000)], at: y)
        case .smr: interpolate([(2030, 9_000_000), (2033, 6_500_000), (2036, 4_500_000)], at: y)
        case .fusion: interpolate([(2029, 9_000_000), (2034.5, 6_000_000), (2038, 3_000_000)], at: y)
        case .battery: 4 * interpolate([(2017, 500_000), (2020, 350_000), (2024, 220_000), (2030, 130_000), (2035, 90_000)], at: y)
        case .interconnect: 250_000
        default: 0
        }
    }

    /// Months from signing to first power, before the queue, permits and the year's build speed.
    func leadMonths(_ y: Double) -> Double {
        switch self {
        case .solar: 18
        case .wind: 24
        case .hydro: 9
        case .geothermal: 36
        case .nuclearRestart: 36
        case .gasTurbines: interpolate([(2016, 12), (2024, 15), (2026, 30), (2029, 18)], at: y)   // the turbine backlog
        case .smr: 36
        case .fusion: 30
        case .battery: 8
        case .interconnect: 0
        }
    }

    /// Largest single contract.
    func maxMW(_ s: GameState, _ loc: Location) -> Double {
        switch self {
        case .solar, .wind: loc.gridCap(s.year) * 1.5
        case .hydro, .geothermal: loc.gridCap(s.year) * 0.5
        case .nuclearRestart: 1_200
        case .gasTurbines: 10_000
        case .smr: 25_000
        case .fusion: 100_000
        case .battery: 5_000
        case .interconnect: loc.gridCap(s.year) * 1.5
        }
    }

    var blurb: String {
        switch self {
        case .solar: "Cheap daytime power from a new solar farm, contracted for 15–20 years. Sized here in average megawatts (about 4× nameplate)."
        case .wind: "Wind farm output under a long contract. Cheap and green; less predictable than baseload."
        case .hydro: "Existing dams, sold under contract. Clean, cheap and scarce."
        case .geothermal: "Round-the-clock heat power. Enhanced geothermal gets much cheaper in the 2030s."
        case .nuclearRestart: "Bring a retired reactor back, or uprate a running one: 24/7 carbon-free baseload. Only a few are left."
        case .gasTurbines: "Behind-the-meter turbines on your campus: no grid queue, raises the site's ceiling. Turbine backlogs ran long in 2025–28."
        case .smr: "A fleet of factory-built reactors on your land: tens of gigawatts of clean baseload with no grid queue."
        case .fusion: "A commercial fusion plant feeding the campus directly: cheap, clean and practically unlimited."
        case .battery: "Four-hour batteries: shave peaks, ride out grid emergencies and squeeze more out of a connection."
        case .interconnect: "Join the utility's queue for a bigger grid connection. Waits run from months to years by region."
        }
    }
}

/// One power deal you've signed.
struct PowerContract: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var kind: PowerKind
    var locationID: String
    /// The site it's built on or connected to (on-site kinds).
    var siteID: UUID? = nil
    /// Average (firm-equivalent) megawatts; batteries: MW of 4-hour storage.
    var mw: Double
    var priceMWh: Double
    var capex: Double = 0
    var signed: Date
    var online: Date
    var end: Date? = nil
    /// Its capacity has been added to the site (on-site kinds).
    var live = false

    var location: Location { LocationCatalog.byID[locationID] ?? LocationCatalog.all[0] }
    func isOnline(_ d: Date) -> Bool { d >= online }
}

/// A company-wide view of power: what's online, used, building, contracted and queued.
struct PowerSummary {
    var onlineKW = 0.0
    var chipKW = 0.0
    var subleasedKW = 0.0
    var buildingKW = 0.0
    var plannedKW = 0.0
    var leasePendingKW = 0.0
    var ppaOnlineMW = 0.0
    var ppaPendingMW = 0.0
    var onsiteOnlineMW = 0.0
    var onsitePendingMW = 0.0
    var queuedMW = 0.0
    var batteryMW = 0.0
    var ownedKW = 0.0
    var leasedKW = 0.0
    var facilityMW = 0.0

    var usedKW: Double { chipKW + subleasedKW }
    var freeKW: Double { max(0, onlineKW - usedKW) }
    var pipelineKW: Double { buildingKW + plannedKW + leasePendingKW }
}

enum Power {
    /// Grid power for datacenters gets dearer once AI strains the grids (none below a stress of 30, +40% at 100).
    /// Purchase agreements and on-site generation are the hedge.
    static func gridMultiplier(_ s: GameState) -> Double { 1 + 0.4 * max(0, s.world.gridStress - 30) / 70 * AdvancedProjects.gridFactor(s) }   // grid programmes

    static func summary(_ s: GameState) -> PowerSummary {
        var p = PowerSummary()
        for site in s.sites {
            let ready = site.isReady(s.date)
            if ready {
                p.onlineKW += site.capacityKW
                p.facilityMW += Economy.siteLoadKW(s, site.id) * site.pue / 1000
                if site.kind == .colo { p.leasedKW += site.capacityKW } else if site.kind == .datacenter { p.ownedKW += site.capacityKW }
            } else if site.kind == .colo {
                p.leasePendingKW += site.capacityKW
            } else {
                p.buildingKW += site.capacityKW
            }
            p.subleasedKW += site.subleasedKW
            p.buildingKW += site.expanding + site.upgradeKW
            p.plannedKW += site.plannedKW
            p.leasePendingKW += site.rampKW
        }
        p.chipKW = s.sites.reduce(0) { $0 + Economy.siteLoadKW(s, $1.id) } - p.subleasedKW
        for c in s.powerContracts {
            let on = c.isOnline(s.date)
            switch c.kind {
            case .interconnect: if !on { p.queuedMW += c.mw }
            case .battery: if on { p.batteryMW += c.mw }
            case .gasTurbines, .smr, .fusion: if on { p.onsiteOnlineMW += c.mw } else { p.onsitePendingMW += c.mw }
            default: if on { p.ppaOnlineMW += c.mw } else { p.ppaPendingMW += c.mw }
            }
        }
        return p
    }

    /// Months you'd wait in the interconnection queue for `mw` more grid power at `loc`.
    static func queueMonths(_ loc: Location, mw: Double, _ s: GameState) -> Double {
        let base: Double = switch loc.id {
        case "nova": 48
        case "oregon": 40
        case "iowa", "arizona": 30
        case "quebec": 26
        case "texas": 20
        case "iceland": 18
        default: 12
        }
        let era = interpolate([(2016, 0.35), (2020, 0.5), (2023, 0.8), (2025, 1.0), (2028, 1.1), (2031, 0.85), (2035, 0.6)], at: s.year)
        let size = 0.8 + 0.4 * min(1, mw / max(1, loc.gridCap(s.year)))
        let stress = 1 + s.world.gridStress / 150
        let rules = Policy.buildFactor(s) * XenoScience.buildFactor(s)
        return max(3, base * era * size * stress * rules)
    }

    /// Months from signing to first power.
    static func leadMonths(_ kind: PowerKind, _ loc: Location, mw: Double, _ s: GameState) -> Double {
        if kind == .interconnect { return queueMonths(loc, mw: mw, s) }
        var m = kind.leadMonths(s.year) * Policy.buildFactor(s)
        if kind.onSite { m = m / loc.buildSpeed / max(1, Campus.speedup(s.year) * 0.8) }
        if kind == .solar || kind == .wind { m *= 0.8 + 0.4 * min(1, mw / max(1, loc.gridCap(s.year))) }
        return max(3, m)
    }

    /// Restarted reactors are scarce: about this much exists to contract in the whole game.
    static func nuclearRestartLeftMW(_ s: GameState) -> Double {
        let pool = interpolate([(2024.7, 3_000), (2027, 6_000), (2030, 9_000)], at: s.year)
        return max(0, pool - s.powerContracts.filter { $0.kind == .nuclearRestart }.reduce(0) { $0 + $1.mw })
    }

    /// Quote for a contract: (upfront, $/MWh, months to first power, error).
    static func quote(_ kind: PowerKind, locationID: String, siteID: UUID?, mw: Double, _ s: GameState) -> (upfront: Double, priceMWh: Double, months: Double, error: String?) {
        guard let loc = LocationCatalog.byID[locationID] else { return (0, 0, 0, "Pick a location.") }
        let upfront = kind.capexPerMW(s.year) * mw * (kind == .battery ? Science.storageCapexFactor(s) : 1)   // 3.6: battery discoveries
        let price = kind.priceMWh(s.year) * (kind == .gasTurbines && loc.id == "uae" ? 0.8 : 1)
        let months = leadMonths(kind, loc, mw: mw, s)
        if !kind.available(s) { return (upfront, price, months, "\(kind.rawValue) isn't available until \(Int(kind.availableFrom)).") }
        if mw < 1 { return (upfront, price, months, "Contracts start at 1 MW.") }
        if let locs = kind.locations, !locs.contains(locationID) { return (upfront, price, months, "\(kind.rawValue) isn't on offer in \(loc.name).") }
        if kind.onSite && siteID == nil { return (upfront, price, months, "Pick the campus to build it on.") }
        if mw > kind.maxMW(s, loc) + 0.01 { return (upfront, price, months, "The largest \(kind.rawValue.lowercased()) deal here is \(Fmt.watts(kind.maxMW(s, loc) * 1e6)).") }
        if kind == .nuclearRestart && mw > nuclearRestartLeftMW(s) + 0.01 {
            return (upfront, price, months, "Only \(Fmt.watts(nuclearRestartLeftMW(s) * 1e6)) of restartable reactors are left to contract.")
        }
        if upfront > s.cash { return (upfront, price, months, "That costs \(Fmt.money(upfront)) up front; you have \(Fmt.money(s.cash)).") }
        return (upfront, price, months, nil)
    }

    // MARK: Daily

    /// Bring finished contracts online, end expired ones and settle the energy the contracts supplied.
    static func daily(_ s: inout GameState) {
        guard !s.powerContracts.isEmpty else { return }
        for i in s.powerContracts.indices where !s.powerContracts[i].live && s.powerContracts[i].isOnline(s.date) {
            s.powerContracts[i].live = true
            let c = s.powerContracts[i]
            if let sid = c.siteID, let si = s.sites.firstIndex(where: { $0.id == sid }) {
                switch c.kind {
                case .interconnect: s.sites[si].gridExtraKW += c.mw * 1000
                case .battery: s.sites[si].batteryMWh += c.mw * 4
                case .gasTurbines, .smr, .fusion: s.sites[si].onsiteKW += c.mw * 1000
                default: break
                }
            }
            let place = c.siteID.flatMap { id in s.sites.first { $0.id == id }?.name } ?? c.location.name
            Sim.news(&s, "\(c.kind.rawValue) online: \(Fmt.watts(c.mw * 1e6))",
                     c.kind == .interconnect ? "\(place) can now draw \(Fmt.watts(c.mw * 1e6)) more from the grid." : "\(place) has \(Fmt.watts(c.mw * 1e6)) of new \(c.kind.green ? "clean " : "")power\(c.kind.suppliesEnergy ? " at \(Fmt.money(c.priceMWh))/MWh" : "").",
                     .company, image: c.kind.image, good: true)
        }
        let today = s.date
        for c in s.powerContracts where (c.end.map { $0 <= today } ?? false) {
            Sim.news(&s, "Power contract ended: \(c.kind.rawValue.lowercased())", "\(Fmt.watts(c.mw * 1e6)) in \(c.location.name). Those sites buy from the grid again unless you sign a new deal.", .company)
        }
        s.powerContracts.removeAll { c in c.end.map { $0 <= today } ?? false }
        settle(&s)
    }

    /// Energy from contracts replaces grid power at the contract price: on-site generation serves its own site first,
    /// purchase agreements the sites in their region. Unused contracted energy is sold back at a discount (take-or-pay).
    static func settle(_ s: inout GameState) {
        let live = s.powerContracts.filter { $0.kind.suppliesEnergy && $0.isOnline(s.date) }
        guard !live.isEmpty else { return }
        let pools = Economy.pools(s)
        var util: [String: Double] = [:]
        for p in pools where p.total > 0 { util[p.accel.id] = Double(p.allocated) / Double(p.total) }
        // Facility draw (kW) and its grid price at each ready site.
        var draw: [UUID: Double] = [:]
        for b in s.owned {
            guard let a = HardwareCatalog.get(b.accelID), let site = s.sites.first(where: { $0.id == b.siteID }), site.isReady(s.date),
                  site.kind == .datacenter || site.kind == .colo else { continue }
            draw[site.id, default: 0] += Economy.chipKW(a) * Double(b.count) * (0.3 + 0.65 * (util[a.id] ?? 0)) * site.pue
        }
        var delta = 0.0   // positive = saving
        let grid = gridMultiplier(s)
        // On-site generation.
        for c in live where c.siteID != nil {
            guard let sid = c.siteID, let site = s.sites.first(where: { $0.id == sid }) else { continue }
            let used = min(draw[sid] ?? 0, c.mw * 1000)
            draw[sid] = (draw[sid] ?? 0) - used
            delta += used * 24 * (site.powerPrice * grid - c.priceMWh / 1000)
        }
        // Regional purchase agreements.
        for c in live where c.siteID == nil {
            var left = c.mw * 1000
            for site in s.sites where site.locationID == c.locationID && (draw[site.id] ?? 0) > 0 && left > 0 {
                let used = min(left, draw[site.id] ?? 0)
                draw[site.id] = (draw[site.id] ?? 0) - used
                left -= used
                delta += used * 24 * (site.powerPrice * grid - c.priceMWh / 1000)
            }
            // Take-or-pay: the rest is sold into the market at 70% of the local wholesale price.
            delta += left * 24 * (c.location.powerPrice * grid * 0.7 - c.priceMWh / 1000)
        }
        delta *= max(0.5, 1 - s.traits.power) * XenoScience.powerFactor(s) * Science.powerFactor(s) * AdvancedProjects.powerFactor(s)   // 3.6: energy discoveries; cooling programmes
        s.cash += delta
        s.month.costPower -= delta
    }

    /// Share of a site's load that rides out a grid emergency: on-site generation fully, batteries and regional
    /// purchase agreements in part.
    static func backupShare(_ s: GameState, _ site: Site, loadKW: Double) -> Double {
        guard loadKW > 0 else { return 0 }
        let ppa = s.powerContracts.filter { $0.siteID == nil && $0.locationID == site.locationID && $0.isOnline(s.date) && $0.kind.suppliesEnergy }
            .reduce(0) { $0 + $1.mw * 1000 }
        return clamp((site.onsiteKW + site.batteryMWh / 4 * 1000 * 0.5 + ppa * 0.3) / loadKW, 0, 1)
    }

    // MARK: Advice

    /// Your datacenter power is nearly all spoken for and little more is coming: (share used, suggested MW).
    static func powerBound(_ s: GameState) -> (used: Double, suggestMW: Double)? {
        let dcs = s.sites.filter { $0.kind == .colo || $0.kind == .datacenter }
        let online = dcs.filter { $0.isReady(s.date) }.reduce(0) { $0 + $1.capacityKW }
        guard online >= 500 else { return nil }
        let used = dcs.filter { $0.isReady(s.date) }.reduce(0) { $0 + Economy.siteLoadKW(s, $1.id) }
        let p = summary(s)
        guard used / online > 0.9, p.pipelineKW < online * 0.25 else { return nil }
        let mw = max(1, online / 1000 * 0.5)
        let nice = mw < 10 ? mw.rounded(.up) : (mw < 100 ? (mw / 10).rounded(.up) * 10 : (mw / 100).rounded(.up) * 100)
        return (used / online, nice)
    }
}

// MARK: - Player actions

extension GameState {
    /// Sign a power deal: a purchase agreement in a region, generation or batteries on a site, or a place in the grid queue.
    mutating func signPower(_ kind: PowerKind, locationID: String, siteID: UUID? = nil, mw: Double, years: Int = 15) -> String? {
        var loc = locationID
        if let siteID {
            guard let site = sites.first(where: { $0.id == siteID }) else { return "Pick a site." }
            if site.kind != .datacenter { return "Generation and grid upgrades go on campuses you own." }
            loc = site.locationID
        }
        let q = Power.quote(kind, locationID: loc, siteID: kind.onSite ? siteID : nil, mw: mw, self)
        if let e = q.error { return e }
        cash -= q.upfront
        month.capex += q.upfront
        let online = GameCalendar.addDays(date, Int(q.months * 30.4))
        let end: Date? = kind.onSite ? nil : GameCalendar.addMonths(online, max(1, years) * 12)
        powerContracts.append(PowerContract(kind: kind, locationID: loc, siteID: kind.onSite ? siteID : nil, mw: mw, priceMWh: q.priceMWh, capex: q.upfront,
                                            signed: date, online: online, end: end))
        if let siteID, kind.onSite, let i = sites.firstIndex(where: { $0.id == siteID }) { sites[i].capex += q.upfront }
        if kind.green && mw >= 50 { brand = min(100, brand + (mw >= 1_000 ? 2 : 1)) }
        let where_ = siteID.flatMap { id in sites.first { $0.id == id }?.name } ?? LocationCatalog.byID[loc]?.name ?? loc
        Sim.news(&self, "Signed: \(Fmt.watts(mw * 1e6)) \(kind.rawValue.lowercased())",
                 "\(where_). \(q.upfront > 0 ? "\(Fmt.money(q.upfront)) up front. " : "")\(kind.suppliesEnergy ? "\(Fmt.money(q.priceMWh))/MWh. " : "")First power \(online.gameMonth).",
                 .company, image: kind.image)
        return nil
    }

    /// Walk away from a contract that hasn't delivered yet (deposits and construction spent are lost).
    mutating func cancelPower(_ id: UUID) -> String? {
        guard let i = powerContracts.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let c = powerContracts[i]
        if c.isOnline(date) && c.kind.onSite { return "It's built. It stays with the site." }
        if c.isOnline(date) {
            // Breaking a running purchase agreement: a year of the contract's value.
            let fee = c.mw * 1000 * 24 * 365 * c.priceMWh / 1000 * 0.25
            if fee > cash { return "Breaking it costs \(Fmt.money(fee))." }
            cash -= fee
            month.costPower += fee
        }
        powerContracts.remove(at: i)
        Sim.news(&self, "Cancelled: \(c.kind.rawValue.lowercased())", "\(Fmt.watts(c.mw * 1e6)) in \(c.location.name).", .company)
        return nil
    }
}
