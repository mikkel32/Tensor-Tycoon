import Foundation

// MARK: - The datacenter market (3.5)

/// Who is selling a datacenter.
enum DCSeller: String, Codable, CaseIterable, Sendable {
    case neocloud = "Neocloud"
    case hyperscaler = "Hyperscaler surplus"
    case distressed = "Distressed lab"
    case crypto = "Crypto miner"
    case developer = "Developer (powered shell)"

    var symbol: String {
        switch self {
        case .neocloud: "cloud.fill"
        case .hyperscaler: "building.columns.fill"
        case .distressed: "exclamationmark.triangle.fill"
        case .crypto: "bitcoinsign.circle.fill"
        case .developer: "hammer.fill"
        }
    }

    var blurb: String {
        switch self {
        case .neocloud: "A GPU cloud selling a finished, liquid-cooled hall to raise cash. Ready now."
        case .hyperscaler: "A hyperscaler offloading surplus capacity. Premium price, premium build, ready now."
        case .distressed: "A lab that ran out of money. Its campus goes cheap, as-is."
        case .crypto: "A bitcoin mine converting to AI: lots of cheap power, air-cooled halls that need a retrofit for liquid-cooled chips."
        case .developer: "A powered shell still being built: land, power and building, delivered on a date. Stakes available."
        }
    }
}

/// A datacenter or campus for sale.
struct DCListing: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var name: String
    var seller: DCSeller
    var sellerName: String
    var locationID: String
    var mw: Double
    var cooling: Cooling
    var pueGain: Double
    var price: Double
    /// Days until it's energised (0 = ready now).
    var readyDays: Int
    /// The smallest stake the seller will sell (1 = whole site only).
    var minStake: Double

    var location: Location { LocationCatalog.byID[locationID] ?? LocationCatalog.all[0] }
    var perMW: Double { price / max(mw, 0.001) }
    /// An illustrative photo: a powered shell still being built shows a construction site.
    var image: String { readyDays > 0 ? ImagePicker.pick(.construction, seed: name) : ImagePicker.sitePhoto(location: location.image, seed: name) }
}

/// What to build a site for.
enum CampusTemplate: String, CaseIterable, Identifiable, Sendable {
    case training = "Training campus"
    case inference = "Inference site"

    var id: String { rawValue }
    var symbol: String { self == .training ? "flame.fill" : "network" }
    var blurb: String {
        switch self {
        case .training: "Big, dense and cheap: liquid cooling, the cheapest power you can get, long leases. Latency doesn't matter."
        case .inference: "Near your users: smaller sites in well-connected regions, shorter leases, fast to stand up."
        }
    }
    /// Locations close to big user populations (low latency for inference).
    static let edgeLocations = ["nova", "oregon", "quebec", "arizona", "uae", "iceland"]
}

/// One way to add capacity, priced.
struct CapacityQuote: Identifiable, Hashable {
    enum Kind: String { case build = "Build", lease = "Lease", buy = "Buy" }
    var kind: Kind
    var locationID: String
    var mw: Double
    var power: PowerDeal = .grid
    var cooling: Cooling = .liquid
    var years: Int = 0
    var listingID: UUID? = nil
    var upfront: Double
    var monthly: Double
    var monthsToFirst: Double
    var monthsToFull: Double
    var sites: Int = 1
    var note: String

    var id: String { "\(kind.rawValue)-\(locationID)-\(power.rawValue)-\(listingID?.uuidString ?? "")" }
    var location: Location { LocationCatalog.byID[locationID] ?? LocationCatalog.all[0] }
}

enum DCMarket {
    static let tenants = ["Nimbus Cloud", "Stratus Compute", "Helios GPU Cloud", "Arcadia Hyperscale", "Lattice Neocloud", "Meridian Media",
                          "Cobalt Sovereign AI", "Northwind Search", "Quanta Robotics", "Bluefin Trading"]
    static let neoclouds = ["Nimbus Cloud", "Helios GPU Cloud", "Lattice Neocloud", "Vector Compute", "Sable GPU"]
    static let hyperscalers = ["Arcadia Hyperscale", "Northwind Cloud", "Atlas Web Services", "Cumulus Platforms"]
    static let miners = ["Hashwell Mining", "Blockfield Digital", "Gridcoin Partners", "Coldcore Mining"]
    static let developers = ["Prairie Power Parks", "Gigaland Development", "Desert Sun DC", "Keystone Campuses", "Falcon Infrastructure"]

    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("\(s.lifecycleSalt)|dc|\(key)") }
    static func pick<T>(_ list: [T], _ u: Double) -> T { list[min(list.count - 1, Int(u * Double(list.count)))] }

    /// Typical campus size on the market this year, in MW.
    static func typicalMW(_ y: Double) -> Double {
        interpolate([(2016, 6), (2020, 15), (2023, 50), (2025, 200), (2027, 600), (2030, 2_000), (2033, 5_000), (2036, 12_000)], at: y)
    }

    /// Existing capacity is worth more when building new is hard (a US moratorium only lifts prices on US soil).
    static func scarcity(_ s: GameState, location: String) -> Double {
        (s.lawsPassed.contains("dc_moratorium") && Region.of(location: location) == .us ? 1.25 : 1) * (1 + s.world.gridStress / 600) * clamp(s.market.hype, 0.85, 1.1)
    }

    /// Refresh the listings at the start of each month (hashed rolls: no draws on the game's random numbers).
    static func refresh(_ s: inout GameState) {
        let ym = s.date.ym
        let key = ym.year * 100 + ym.month
        guard s.dcListingsMonth != key else { return }
        s.dcListingsMonth = key
        // A few listings stay up for another month; the rest are sold to someone else.
        var keep = s.dcListings.enumerated().filter { roll(s, "\(key)|keep|\($0.offset)") < 0.35 }.map(\.element)
        if keep.count > 3 { keep = Array(keep.prefix(3)) }
        var out = keep
        let typical = typicalMW(s.year)
        let n = 6 - keep.count
        for i in 0..<max(0, n) {
            let k = "\(key)|\(i)"
            let u = roll(s, k + "|kind")
            var seller: DCSeller = u < 0.28 ? .neocloud : (u < 0.45 ? .hyperscaler : (u < 0.68 ? .crypto : .developer))
            if s.year < 2021 && seller == .crypto { seller = .neocloud }
            let locs: [String] = switch seller {
            case .crypto: ["texas", "iceland", "quebec", "texas", "iowa"]
            case .hyperscaler: ["nova", "iowa", "oregon", "arizona"]
            case .developer: ["texas", "uae", "arizona", "iowa", "texas"]
            default: LocationCatalog.all.map(\.id)
            }
            let loc = pick(locs, roll(s, k + "|loc"))
            let sizeMul: Double = switch seller {
            case .crypto: 0.5
            case .hyperscaler: 1.3
            case .developer: 2.0
            default: 0.8
            }
            let mw = niceMW(typical * sizeMul * exp((roll(s, k + "|size") - 0.5) * 2.4))
            let name: String = switch seller {
            case .neocloud: pick(neoclouds, roll(s, k + "|who"))
            case .hyperscaler: pick(hyperscalers, roll(s, k + "|who"))
            case .crypto: pick(miners, roll(s, k + "|who"))
            default: pick(developers, roll(s, k + "|who"))
            }
            out.append(listing(s, seller: seller, sellerName: name, locationID: loc, mw: mw, k: k))
        }
        // Labs in trouble sell their campuses.
        for c in s.competitors where c.distressMonths >= 2 && !c.acquired && !c.bankrupt && c.computeH100e > 0 {
            guard !out.contains(where: { $0.sellerName == c.def.name }), roll(s, "\(key)|distress|\(c.id)") < 0.5 else { continue }
            let mw = niceMW(clamp(c.computeH100e * 1.6 / 1000 * 0.3, 5, typical * 4))
            out.append(listing(s, seller: .distressed, sellerName: c.def.name, locationID: pick(["texas", "nova", "oregon", "iowa"], roll(s, "\(key)|dl|\(c.id)")),
                               mw: mw, k: "\(key)|d|\(c.id)"))
        }
        s.dcListings = out
    }

    static func niceMW(_ mw: Double) -> Double {
        let v = max(2, mw)
        let step: Double = v < 20 ? 1 : (v < 200 ? 5 : (v < 2_000 ? 50 : 500))
        return (v / step).rounded() * step
    }

    static func listing(_ s: GameState, seller: DCSeller, sellerName: String, locationID: String, mw: Double, k: String) -> DCListing {
        let liquid: Cooling = s.year >= 2023 ? .liquid : .air
        let (cooling, factor, pue, days): (Cooling, Double, Double, Int) = switch seller {
        case .neocloud: (liquid, 1.05, 0.02, 0)
        case .hyperscaler: (liquid, 1.15, 0.05, 0)
        case .distressed: (liquid, 0.62, 0.0, 0)
        case .crypto: (.air, 0.55, -0.05, 0)
        case .developer: (liquid, 0.92, 0.03, 120 + Int(roll(s, k + "|days") * 420))
        }
        let price = mw * Campus.capexPerMW(cooling, s) * factor * scarcity(s, location: locationID) * (0.92 + 0.16 * roll(s, k + "|px"))
        let place = (LocationCatalog.byID[locationID]?.name ?? locationID).split(separator: ",").first.map(String.init) ?? locationID
        let name: String = switch seller {
        case .crypto: "\(place) mine conversion"
        case .developer: "\(place) powered shell"
        case .distressed: "\(sellerName) \(place) campus"
        default: "\(sellerName) \(place)"
        }
        return DCListing(name: name, seller: seller, sellerName: sellerName, locationID: locationID, mw: mw, cooling: cooling, pueGain: pue,
                         price: price, readyDays: days, minStake: mw >= 500 ? 0.2 : 1)
    }

    // MARK: Leasing

    /// Wholesale colocation rent in $/kW-month: by region and year, cheaper for bigger blocks and longer terms.
    static func leaseRate(_ loc: Location, mw: Double, years: Int, cooling: Cooling, toOwn: Bool, _ s: GameState) -> Double {
        let era = interpolate([(2016, 0.85), (2020, 0.9), (2023, 1.0), (2025, 1.2), (2027, 1.3), (2030, 1.15), (2035, 0.95)], at: s.year)
        let size: Double = mw < 1 ? 1.15 : (mw <= 10 ? 1.0 : (mw <= 100 ? 0.92 : (mw <= 1_000 ? 0.85 : 0.8)))
        let term = interpolate([(1, 1.12), (2, 1.05), (3, 1.0), (5, 0.93), (7, 0.9), (10, 0.86), (15, 0.82)], at: Double(years))
        let cool = cooling == .air ? 1.0 : (cooling == .liquid ? 1.2 : 1.3)
        let here = s.sites.filter { $0.kind == .colo && $0.locationID == loc.id }.reduce(0) { $0 + $1.capacityKW + $1.rampKW } / 1000
        let tight = 1 + (here + mw) / max(1, loc.gridCap(s.year) * 4)
        let rules = s.lawsPassed.contains("dc_moratorium") && Region.of(location: loc.id) == .us ? 1.15 : 1
        return loc.coloFee * era * size * term * cool * tight * rules * (toOwn ? 1.25 : 1) * Science.coloFactor(s)   // energy discoveries, passed on
    }

    /// Days until a leased block is handed over: small cages next month, big blocks built to suit.
    static func leaseLeadDays(mw: Double, _ loc: Location, _ s: GameState) -> Int {
        let base: Double = mw <= 5 ? 30 : (mw <= 50 ? 60 : (mw <= 300 ? 150 : (mw <= 1_000 ? 300 : 300 + (mw - 1_000) / 1_000 * 120)))
        let slow = Policy.buildFactor(s, location: loc.id) * s.market.buildDelay * XenoScience.buildFactor(s) / Campus.speedup(s.year) / loc.buildSpeed
        return Int(mw <= 5 ? base : max(30, base * slow))
    }

    /// Largest block one provider will build for you in a region this year.
    static func maxLeaseMW(_ loc: Location, _ s: GameState) -> Double { max(50, loc.gridCap(s.year) * 3) }

    /// What a lease-to-own site costs to buy out today.
    static func buyoutPrice(_ site: Site, _ s: GameState) -> Double {
        guard site.isTermLease, site.leaseToOwn, let start = site.leaseStart, let end = site.leaseEnd else { return 0 }
        let total = max(1, Double(GameCalendar.daysBetween(start, end)))
        let left = clamp(Double(GameCalendar.daysBetween(s.date, end)) / total, 0, 1)
        return (site.capacityKW + site.rampKW) / 1000 * Campus.capexPerMW(site.cooling, s) * (0.15 + 0.75 * left)
    }

    /// What the rest of a term lease would cost to walk away from (half the rent left). 3.8: only space already handed
    /// over is committed (tranches still to come can be declined), and a rolled-over lease costs one month.
    static func exitFee(_ site: Site, _ s: GameState) -> Double {
        guard site.isTermLease, let end = site.leaseEnd else { return site.monthlyFee }
        if site.rolledOver { return site.leaseRate * site.capacityKW }
        let months = max(0, Double(GameCalendar.daysBetween(s.date, end)) / 30.4)
        return site.leaseRate * site.capacityKW * months * 0.5
    }

    /// 3.8: leases signed before deposits were tracked: record what they paid (a month of the full block) so it comes back.
    static func migrateDeposits(_ s: inout GameState) {
        guard !s.corp.fixes.contains("deposits38") else { return }
        s.corp.fixes.insert("deposits38")
        for i in s.sites.indices where s.sites[i].isTermLease && s.sites[i].deposit == 0 {
            s.sites[i].deposit = s.sites[i].leaseRate * (s.sites[i].capacityKW + s.sites[i].rampKW)
        }
    }

    /// Rent step the next tranche adds, a month.
    static func trancheRent(_ site: Site) -> Double { site.leaseRate * min(site.rampKW, site.rampStepKW) }

    /// 3.9: the term a sublet actually gets: no longer than the whole years left on your own lease (at least one).
    static func subleaseYears(_ site: Site, _ years: Int, _ s: GameState) -> Int {
        guard let end = site.leaseEnd else { return years }
        return min(years, max(1, GameCalendar.daysBetween(s.date, end) / 365))
    }

    /// Rent a tenant pays for `kw` of your space.
    static func subleaseRate(_ site: Site, kw: Double, years: Int, _ s: GameState) -> Double {
        let market = leaseRate(site.location, mw: kw / 1000, years: years, cooling: site.cooling, toOwn: false, s)
        return market * (site.kind == .colo ? 0.85 : 1.0)
    }

    static func waterLPerKWh(_ site: Site) -> Double {
        let climate: Double = switch site.locationID {
        case "arizona", "uae": 1.6
        case "texas": 1.3
        case "iceland": 0.3
        case "quebec": 0.5
        default: 1.0
        }
        return (site.cooling == .air ? 1.8 : (site.cooling == .liquid ? 0.45 : 0.12)) * climate
    }

    // MARK: Daily

    /// Lease hand-overs and ramps, rent, lease ends, sublease income, upgrades finishing.
    static func daily(_ s: inout GameState) {
        refresh(&s)
        s.subleaseRevenueToday = 0
        var income = 0.0
        var i = 0
        while i < s.sites.count {
            let site = s.sites[i]
            // Ramps: the next tranche of a leased block.
            if site.rampKW > 0, let next = site.nextRamp, next <= s.date {
                let add = min(site.rampKW, max(site.rampStepKW, 1))
                s.sites[i].capacityKW += add
                s.sites[i].rampKW -= add
                s.sites[i].nextRamp = s.sites[i].rampKW > 0 ? GameCalendar.addDays(s.date, 91) : nil
                Sim.news(&s, "\(site.name): +\(Fmt.watts(add * 1000)) handed over",
                         "Leased capacity is now \(Fmt.watts(s.sites[i].capacityKW * 1000))\(s.sites[i].rampKW > 0 ? "; \(Fmt.watts(s.sites[i].rampKW * 1000)) still to come" : "").",
                         .company, image: "dc_hall")
            }
            // Term-lease rent starts when space is handed over.
            if s.sites[i].isTermLease {
                s.sites[i].monthlyFee = s.sites[i].isReady(s.date) ? s.sites[i].leaseRate * s.sites[i].capacityKW : 0
                if let end = s.sites[i].leaseEnd, end <= s.date { endOfTerm(&s, i) }
            }
            // Upgrades.
            if let ready = s.sites[i].upgradeReady, ready <= s.date {
                if let to = s.sites[i].coolingTo {
                    s.sites[i].cooling = to
                    Sim.news(&s, "\(site.name) retrofitted", "Now \(to.rawValue.lowercased())-cooled: PUE \(Fmt.trim(s.sites[i].pue, 2)).", .company, image: to.image, good: true)
                } else {
                    s.sites[i].capacityKW += s.sites[i].upgradeKW
                    s.sites[i].generation += 1
                    s.sites[i].pueGain += 0.03
                    Sim.news(&s, "\(site.name): rack generation \(s.sites[i].generation + 1)",
                             "Denser racks and new electrical gear: +\(Fmt.watts(s.sites[i].upgradeKW * 1000)) of IT capacity on the same connection, PUE \(Fmt.trim(s.sites[i].pue, 2)).",
                             .company, image: "rack_rear", good: true)
                }
                s.sites[i].coolingTo = nil
                s.sites[i].upgradeReady = nil
                s.sites[i].upgradeKW = 0
            }
            // Subleases.
            if s.sites[i].subleasedKW > 0 {
                if s.sites[i].isReady(s.date) { income += s.sites[i].subleasedKW * s.sites[i].subleaseRate / 30.4 }
                if let end = s.sites[i].subleaseEnd, end <= s.date {
                    Sim.news(&s, "\(site.name): \(site.subleaseTenant) moves out", "\(Fmt.watts(site.subleasedKW * 1000)) is yours again.", .company)
                    s.sites[i].subleasedKW = 0
                    s.sites[i].subleaseRate = 0
                    s.sites[i].subleaseTenant = ""
                    s.sites[i].subleaseEnd = nil
                }
            }
            i += 1
        }
        if income > 0 {
            s.subleaseRevenueToday = income
            s.cash += income
            s.month.revCloud += income
            s.lifetimeRevenue += income
        }
    }

    /// A term lease ends: lease-to-own sites become yours, the rest roll over for a year at the market rate.
    static func endOfTerm(_ s: inout GameState, _ i: Int) {
        let site = s.sites[i]
        if site.leaseToOwn {
            s.sites[i].kind = .datacenter
            s.sites[i].capex = site.capacityKW / 1000 * Campus.capexPerMW(site.cooling, s) * 0.5
            s.sites[i].leaseRate = 0
            s.sites[i].monthlyFee = 0
            s.sites[i].leaseEnd = nil
            s.sites[i].leaseToOwn = false
            let back = s.sites[i].deposit
            s.cash += back
            s.sites[i].deposit = 0
            Sim.news(&s, "\(site.name) is yours", "The lease-to-own term is over: \(Fmt.watts(site.capacityKW * 1000)) in \(site.location.name) now belongs to you.\(back > 0 ? " Your \(Fmt.money(back)) deposit is back." : "")",
                     .company, image: "hyperscale_campus", important: true, good: true)
            return
        }
        let rate = leaseRate(site.location, mw: site.capacityKW / 1000, years: 1, cooling: site.cooling, toOwn: false, s)
        s.sites[i].leaseRate = rate
        s.sites[i].leaseStart = s.date
        s.sites[i].leaseEnd = GameCalendar.addMonths(s.date, 12)
        s.sites[i].rolledOver = true
        Sim.news(&s, "\(site.name): lease rolled over", "The term ended; it renews for a year at \(Fmt.money(rate))/kW-month (\(Fmt.money(rate * site.capacityKW))/month, was \(Fmt.money(site.leaseRate * site.capacityKW))). Leaving now costs one month's rent, and your \(Fmt.money(site.deposit)) deposit comes back when you do. End it from the Datacenters page.",
                 .company, important: true)
    }

    /// The quickest sensible lease for `mw` (the Chief of Staff's suggestion): cheapest rent plus waiting, 3-year term.
    static func quickLease(_ s: GameState, mw: Double) -> (locationID: String, rate: Double, days: Int)? {
        let cooling: Cooling = s.year >= 2023 ? .liquid : .air
        return LocationCatalog.all.filter { mw <= maxLeaseMW($0, s) }.map { loc in
            (loc.id, leaseRate(loc, mw: mw, years: 3, cooling: cooling, toOwn: false, s), leaseLeadDays(mw: mw, loc, s))
        }.min { $0.1 * (1 + Double($0.2) / 365) < $1.1 * (1 + Double($1.2) / 365) }
    }

    // MARK: Quotes

    /// The ways to add `mw` of capacity for `template`: the best build, the best lease and the best listing.
    static func quotes(_ s: GameState, mw: Double, template: CampusTemplate) -> [CapacityQuote] {
        var out: [CapacityQuote] = []
        let locs = template == .inference ? LocationCatalog.all.filter { CampusTemplate.edgeLocations.contains($0.id) } : LocationCatalog.all
        let cooling: Cooling = s.year >= 2023 ? (template == .training && s.bonuses.has(.immersion) ? .immersion : .liquid) : .air
        let years = template == .training ? 10 : 3
        // What a month of waiting is worth: about the rent on the same space.
        let waitCost = mw * 1000 * 160
        let grid = Power.gridMultiplier(s)
        // Build: every location and power source that can host it (split over up to four sites).
        var best: (CapacityQuote, Double)? = nil
        for loc in locs {
            for deal in PowerDeal.allCases where deal.available(s) {
                let cap = Campus.siteCapMW(loc, deal, s)
                guard cap >= 5 else { continue }
                let sites = Int((mw / cap).rounded(.up))
                guard sites <= 4 else { continue }
                let per = mw / Double(sites)
                let n = Campus.phases(mw: per)
                let first = s.buildMonths(mw: per / Double(n), loc: loc, power: deal)
                let full = first + Double(n - 1) * first * 0.35
                let capex = mw * Campus.capexPerMW(cooling, s, location: loc.id)   // 3.4 overhaul: home incentive, net
                let pue = cooling.basePUE + loc.pueDelta
                let powerMonth = mw * 1000 * 0.8 * pue * 24 * 30.4 * loc.powerPrice * deal.priceMultiplier * grid
                let score = capex + first * waitCost + (template == .training ? 60 : 36) * powerMonth
                let incentive = HQ.buildCost(s, location: loc.id) < 1 ? " Includes \(HQ.country(s).adjective) build incentives (−\(Fmt.pct(1 - HQ.buildCost(s, location: loc.id), decimals: 0)))." : ""
                let q = CapacityQuote(kind: .build, locationID: loc.id, mw: mw, power: deal, cooling: cooling, upfront: (mw / Double(sites)) / Double(n) * Campus.capexPerMW(cooling, s, location: loc.id) * Double(sites),
                                      monthly: powerMonth + capex * 0.015 / 12, monthsToFirst: first, monthsToFull: full, sites: sites,
                                      note: "\(sites > 1 ? "\(sites) campuses" : "One campus") on \(deal.rawValue.lowercased())\(n > 1 ? ", \(n) phases each" : ""). \(Fmt.money(capex)) in all; first phase paid now.\(incentive)")
                if best == nil || score < best!.1 { best = (q, score) }
            }
        }
        if let best { out.append(best.0) }
        // Lease: the cheapest region that can deliver it.
        var lease: (CapacityQuote, Double)? = nil
        for loc in locs where mw <= maxLeaseMW(loc, s) {
            let rate = leaseRate(loc, mw: mw, years: years, cooling: cooling, toOwn: false, s)
            let days = Double(leaseLeadDays(mw: mw, loc, s))
            let ramp = mw > 100
            let first = (ramp ? days * 0.6 : days) / 30.4
            let full = first + (ramp ? 9 : 0)
            let pue = cooling.basePUE + 0.07 + loc.pueDelta * 0.5
            let powerMonth = mw * 1000 * 0.8 * pue * 24 * 30.4 * loc.powerPrice * 1.1 * grid
            let monthly = rate * mw * 1000
            let score = (monthly + powerMonth) * 36 + first * waitCost
            // 3.9: signing takes a month's rent on the whole block as a deposit (leaseCapacity), so the quote says so.
            let q = CapacityQuote(kind: .lease, locationID: loc.id, mw: mw, cooling: cooling, years: years, upfront: monthly, monthly: monthly + powerMonth,
                                  monthsToFirst: first, monthsToFull: full,
                                  note: "\(years)-year wholesale lease at \(Fmt.money(rate))/kW-month\(ramp ? ", handed over in quarterly tranches" : ""). Up front is a refundable deposit (a month's rent on the whole block), returned when the lease ends. Rent starts on hand-over.")
            if lease == nil || score < lease!.1 { lease = (q, score) }
        }
        if let lease { out.append(lease.0) }
        // Buy: the listing closest in size, cheapest per MW.
        let listings = s.dcListings.filter { template == .training || CampusTemplate.edgeLocations.contains($0.locationID) }
        if let l = listings.filter({ $0.mw * $0.minStake <= mw * 1.5 }).min(by: { abs(log(max($0.mw, 1) / mw)) + $0.perMW / 3e7 < abs(log(max($1.mw, 1) / mw)) + $1.perMW / 3e7 }) {
            let share = clamp(mw / l.mw, l.minStake, 1)
            let pue = l.cooling.basePUE + l.location.pueDelta - l.pueGain
            let got = l.mw * share
            let powerMonth = got * 1000 * 0.8 * pue * 24 * 30.4 * l.location.powerPrice * grid
            out.append(CapacityQuote(kind: .buy, locationID: l.locationID, mw: got, cooling: l.cooling, listingID: l.id, upfront: l.price * share,
                                     monthly: powerMonth + l.price * share * 0.015 / 12, monthsToFirst: Double(l.readyDays) / 30.4, monthsToFull: Double(l.readyDays) / 30.4,
                                     note: "\(share < 1 ? "A \(Fmt.pct(share, decimals: 0)) stake in " : "")\(l.name) from \(l.sellerName) (\(l.seller.rawValue.lowercased())), \(Fmt.money(l.perMW))/MW."))
        }
        return out
    }
}

// MARK: - Player actions

extension GameState {
    /// Buy a datacenter from the market, whole or a stake in it.
    mutating func buyListing(_ id: UUID, share: Double = 1) -> String? {
        guard let li = dcListings.firstIndex(where: { $0.id == id }) else { return "That site has been sold." }
        let l = dcListings[li]
        let f = clamp(share, l.minStake, 1)
        let cost = l.price * f
        if cost > cash { return "That costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        cash -= cost
        month.capex += cost
        let kw = l.mw * f * 1000
        let ready = GameCalendar.addDays(date, l.readyDays)
        var site = Site(name: f < 1 ? "\(l.name) (\(Int((f * 100).rounded()))%)" : l.name, kind: .datacenter, locationID: l.locationID, capacityKW: kw,
                        cooling: l.cooling, powerDeal: .grid, opened: date, ready: ready, capex: cost, monthlyFee: 0)
        site.pueGain = l.pueGain
        site.stake = f < 1 ? f : 0
        site.partner = f < 1 ? l.sellerName : ""
        // It comes with its grid connection, whatever the usual limit for a new site here.
        site.gridExtraKW = max(0, kw - Campus.siteCapMW(l.location, .grid, self) * 1000)
        sites.append(site)
        dcListings.remove(at: li)
        Sim.news(&self, f < 1 ? "Bought \(Fmt.pct(f, decimals: 0)) of \(l.name)" : "Bought \(l.name)",
                 "\(Fmt.watts(kw * 1000)) in \(l.location.name) from \(l.sellerName) for \(Fmt.money(cost))\(l.readyDays > 0 ? ", energised \(ready.gameMonth)" : ", ready now")\(f < 1 ? ". \(l.sellerName) runs the site" : "").",
                 .company, image: l.location.image, important: true)
        return nil
    }

    /// Lease wholesale colocation by the megawatt: 1 MW to several GW, 1–15 years, optionally handed over in quarterly tranches,
    /// optionally lease-to-own.
    mutating func leaseCapacity(locationID: String, mw: Double, years: Int, cooling: Cooling = .liquid, ramp: Bool = true, toOwn: Bool = false, name: String = "") -> String? {
        guard let loc = LocationCatalog.byID[locationID] else { return "Pick a location." }
        if mw < 1 { return "Wholesale leases start at 1 MW. Rent a cage for less." }
        if !(1...15).contains(years) { return "Terms run from 1 to 15 years." }
        if cooling == .immersion && !bonuses.has(.immersion) { return "Research Immersion Cooling first." }
        if toOwn && years < 5 { return "Lease-to-own needs a term of at least 5 years." }
        let maxMW = DCMarket.maxLeaseMW(loc, self)
        if mw > maxMW + 0.01 { return "Providers in \(loc.name) can deliver at most \(Fmt.watts(maxMW * 1e6)) in one lease this year. Lease in another region too." }
        let rate = DCMarket.leaseRate(loc, mw: mw, years: years, cooling: cooling, toOwn: toOwn, self)
        let deposit = rate * mw * 1000   // a month's rent on the full block, held as security and returned when the lease ends
        if deposit > cash { return "The refundable deposit is a month's rent on the whole block, \(Fmt.money(deposit)); you have \(Fmt.money(cash))." }
        cash -= deposit   // 3.8: not an expense: it's the landlord's to hold and yours to get back
        let lead = DCMarket.leaseLeadDays(mw: mw, loc, self)
        let ramped = ramp && mw > 100
        let first = ramped ? mw * 0.25 : mw
        let ready = GameCalendar.addDays(date, ramped ? Int(Double(lead) * 0.6) : lead)
        let place = loc.name.split(separator: ",").first.map(String.init) ?? loc.name
        var site = Site(name: name.isEmpty ? "\(place) lease \(Fmt.watts(mw * 1e6))" : name, kind: .colo, locationID: locationID, capacityKW: first * 1000,
                        cooling: cooling, powerDeal: .grid, opened: date, ready: ready, capex: 0, monthlyFee: 0)
        site.leaseRate = rate
        site.leaseStart = ready
        site.leaseEnd = GameCalendar.addMonths(ready, years * 12)
        site.leaseToOwn = toOwn
        site.deposit = deposit
        if ramped {
            site.rampKW = (mw - first) * 1000
            site.rampStepKW = mw * 0.25 * 1000
            site.nextRamp = GameCalendar.addDays(ready, 91)
        }
        sites.append(site)
        Sim.news(&self, "Leased \(Fmt.watts(mw * 1e6)) in \(loc.name)",
                 "\(years)-year \(toOwn ? "lease-to-own" : "wholesale lease") at \(Fmt.money(rate))/kW-month (\(Fmt.money(rate * mw * 1000))/month at full size). First \(Fmt.watts(first * 1e6)) \(ready.gameMonth)\(ramped ? ", the rest in quarterly tranches you can defer or decline from the Datacenters page" : ""). \(Fmt.money(deposit)) refundable deposit held until the lease ends.",
                 .company, image: loc.image, illustrative: true)
        return nil
    }

    /// 3.8: push the next tranche of a leased block back a quarter (up to four times). Rent for it starts when it's handed over.
    mutating func deferTranche(_ id: UUID) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }), sites[i].rampKW > 0, let next = sites[i].nextRamp else { return "No tranche is waiting." }
        if sites[i].rampDeferrals >= 4 { return "The provider won't hold the space any longer: take it or decline it." }
        sites[i].nextRamp = GameCalendar.addDays(next, 91)
        sites[i].rampDeferrals += 1
        Sim.news(&self, "\(sites[i].name): next tranche deferred", "The next \(Fmt.watts(min(sites[i].rampKW, sites[i].rampStepKW) * 1000)) now arrives \(sites[i].nextRamp?.gameShort ?? "later").", .company)
        return nil
    }

    /// 3.8: give up the tranches still to come. The lease stays at what's been handed over (and so does its exit fee).
    mutating func declineTranches(_ id: UUID) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }), sites[i].rampKW > 0 else { return "No tranche is waiting." }
        let kw = sites[i].rampKW
        sites[i].rampKW = 0
        sites[i].rampStepKW = 0
        sites[i].nextRamp = nil
        Sim.news(&self, "\(sites[i].name): remaining tranches declined", "\(Fmt.watts(kw * 1000)) won't be handed over; rent stays on the \(Fmt.watts(sites[i].capacityKW * 1000)) you have.", .company)
        return nil
    }

    /// Buy a lease-to-own site before the term is up.
    mutating func buyOutLease(_ id: UUID) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        guard sites[i].isTermLease, sites[i].leaseToOwn else { return "Only lease-to-own sites can be bought out." }
        let price = DCMarket.buyoutPrice(sites[i], self)
        if price > cash { return "The buyout costs \(Fmt.money(price))." }
        cash -= price
        month.capex += price
        cash += sites[i].deposit   // 3.8: the deposit is handed back at the buyout
        sites[i].deposit = 0
        sites[i].capacityKW += sites[i].rampKW
        sites[i].rampKW = 0
        sites[i].nextRamp = nil
        DCMarket.endOfTerm(&self, i)
        sites[i].capex = price
        return nil
    }

    /// Rent `kw` of a site's free capacity to another company for `years`.
    mutating func sublease(_ id: UUID, kw: Double, years: Int) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let site = sites[i]
        guard site.kind == .colo || site.kind == .datacenter else { return "You can't sublet your home base." }
        if !site.isReady(date) { return "Wait until it's online." }
        if site.subleasedKW > 0 { return "\(site.subleaseTenant) already rents space here. End that first." }
        if kw < 100 { return "Tenants take at least 100 kW." }
        let free = site.capacityKW - Economy.siteLoadKW(self, id)
        if kw > free + 0.01 { return "Only \(Fmt.watts(max(0, free) * 1000)) is free here." }
        let term = DCMarket.subleaseYears(site, years, self)
        let rate = DCMarket.subleaseRate(site, kw: kw, years: term, self)
        sites[i].subleasedKW = kw
        sites[i].subleaseRate = rate
        sites[i].subleaseTenant = DCMarket.pick(DCMarket.tenants, DCMarket.roll(self, "tenant|\(id)|\(date.ym.year)-\(date.ym.month)"))
        sites[i].subleaseEnd = GameCalendar.addMonths(date, term * 12)
        Sim.news(&self, "\(site.name): \(Fmt.watts(kw * 1000)) sublet to \(sites[i].subleaseTenant)",
                 "\(term) year\(term == 1 ? "" : "s") at \(Fmt.money(rate))/kW-month: \(Fmt.money(rate * kw))/month. The tenant pays its own power.", .company, image: "dc_rows")
        return nil
    }

    /// Lease a whole empty campus to a hyperscaler: steady rent on a long term.
    mutating func leaseOutCampus(_ id: UUID, years: Int = 10) -> String? {
        guard let site = sites.first(where: { $0.id == id }) else { return "Not found." }
        if site.kind != .datacenter { return "Only campuses you own can be leased out whole." }
        if owned.contains(where: { $0.siteID == id }) || orders.contains(where: { $0.siteID == id }) { return "Move the chips out first." }
        if let e = sublease(id, kw: site.capacityKW, years: years) { return e }
        if let i = sites.firstIndex(where: { $0.id == id }) {
            sites[i].subleaseRate *= 1.05
            sites[i].subleaseTenant = DCMarket.pick(DCMarket.hyperscalers, DCMarket.roll(self, "hyper|\(id)"))
        }
        return nil
    }

    /// End a sublease early: three months' rent to the tenant.
    mutating func endSublease(_ id: UUID) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }), sites[i].subleasedKW > 0 else { return "Nothing is sublet here." }
        let fee = sites[i].subleasedKW * sites[i].subleaseRate * 3
        if fee > cash { return "Buying the tenant out costs \(Fmt.money(fee))." }
        cash -= fee
        month.costSites += fee
        Sim.news(&self, "\(sites[i].name): bought out \(sites[i].subleaseTenant)", "\(Fmt.money(fee)) to end the sublease early.", .company)
        sites[i].subleasedKW = 0
        sites[i].subleaseRate = 0
        sites[i].subleaseTenant = ""
        sites[i].subleaseEnd = nil
        return nil
    }

    /// Retrofit a campus to better cooling (air → liquid → immersion). Takes about four months; the site keeps running.
    mutating func upgradeCooling(_ id: UUID, to: Cooling) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let site = sites[i]
        guard site.kind == .datacenter else { return "Your landlord decides the cooling. Lease liquid-cooled space instead." }
        if !site.isReady(date) { return "Finish building it first." }
        if site.upgradeReady != nil { return "An upgrade is already under way." }
        let order: [Cooling] = [.air, .liquid, .immersion]
        if (order.firstIndex(of: to) ?? 0) <= (order.firstIndex(of: site.cooling) ?? 0) { return "It's already \(site.cooling.rawValue.lowercased())-cooled." }
        if to == .immersion && !bonuses.has(.immersion) { return "Research Immersion Cooling first." }
        let cost = Campus.coolingRetrofitCost(site, to: to, self)
        if cost > cash { return "The retrofit costs \(Fmt.money(cost))." }
        cash -= cost
        month.capex += cost
        sites[i].capex += cost
        sites[i].coolingTo = to
        sites[i].upgradeReady = GameCalendar.addDays(date, Int(120 / Campus.speedup(year)))
        Sim.news(&self, "Retrofitting \(site.name)", "\(to.rawValue) cooling for \(Fmt.money(cost)), done \(sites[i].upgradeReady!.gameMonth).", .company, image: to.image)
        return nil
    }

    /// Denser racks and newer electrical gear: +10% IT capacity on the same connection and a better PUE (three generations).
    mutating func upgradeGeneration(_ id: UUID) -> String? {
        guard let i = sites.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let site = sites[i]
        guard site.kind == .datacenter else { return "Only campuses you own can be re-racked." }
        if !site.isReady(date) { return "Finish building it first." }
        if site.upgradeReady != nil { return "An upgrade is already under way." }
        if site.generation >= 3 { return "It's already at the newest rack generation." }
        let cost = Campus.generationCost(site, self)
        if cost > cash { return "The upgrade costs \(Fmt.money(cost))." }
        cash -= cost
        month.capex += cost
        sites[i].capex += cost
        sites[i].upgradeKW = site.capacityKW * 0.1
        sites[i].upgradeReady = GameCalendar.addDays(date, Int(150 / Campus.speedup(year)))
        Sim.news(&self, "Re-racking \(site.name)", "+\(Fmt.watts(site.capacityKW * 100)) for \(Fmt.money(cost)), done \(sites[i].upgradeReady!.gameMonth).", .company, image: "rack_rear")
        return nil
    }

    /// Carry out a capacity quote.
    mutating func addCapacity(_ q: CapacityQuote, name: String = "") -> String? {
        switch q.kind {
        case .build:
            let per = q.mw / Double(max(1, q.sites))
            let place = q.location.name.split(separator: ",").first.map(String.init) ?? q.location.name
            for k in 0..<max(1, q.sites) {
                let n = name.isEmpty ? "\(place) \(q.sites > 1 ? "Campus \(k + 1)" : "Campus")" : (q.sites > 1 ? "\(name) \(k + 1)" : name)
                if let e = buildSite(kind: .datacenter, locationID: q.locationID, capacityKW: per * 1000, cooling: q.cooling, power: q.power, name: n) {
                    return k == 0 ? e : "Started \(k) of \(q.sites) campuses: \(e)"
                }
            }
            return nil
        case .lease:
            return leaseCapacity(locationID: q.locationID, mw: q.mw, years: q.years, cooling: q.cooling, ramp: true, toOwn: false, name: name)
        case .buy:
            guard let id = q.listingID, let l = dcListings.first(where: { $0.id == id }) else { return "That site has been sold." }
            return buyListing(id, share: q.mw / max(l.mw, 0.001))
        }
    }
}
