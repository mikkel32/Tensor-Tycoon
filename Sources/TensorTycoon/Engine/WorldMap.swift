import Foundation

// MARK: - 3.9: the world map
//
// Everything the World Map screen draws, read live from the game: your headquarters, offices, campuses (sized by
// megawatts), power plants and fabs; rival labs and the training runs the rumour mill has located; foundries and
// suppliers; the agencies that buy advanced programmes; export-control zones; and the flows between them — chips on
// their way to your sites, money in from markets and agencies, money out to builders and chipmakers, power from
// plants. `monthly` remembers your expansion (the map's timeline) and announces each new continent you build on.
// Nothing here draws from the game's random numbers.

/// Filters on the map.
enum MapLayer: String, CaseIterable, Identifiable, Sendable {
    case yours, rivals, supply, government

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yours: "Yours"
        case .rivals: "Rivals"
        case .supply: "Supply chain"
        case .government: "Government"
        }
    }

    var symbol: String {
        switch self {
        case .yours: "star.fill"
        case .rivals: "flag.2.crossed.fill"
        case .supply: "shippingbox.fill"
        case .government: "building.columns.fill"
        }
    }
}

enum MapPinKind: String, Sendable {
    case hq, office, partner, campus, power, fab, alienFab, foundry, packaging, memory, rival, rivalRun, agency

    var label: String {
        switch self {
        case .hq: "Headquarters"
        case .office: "Office"
        case .partner: "National partnership"
        case .campus: "Datacenters"
        case .power: "Power deal"
        case .fab: "Your fab"
        case .alienFab: "Alien fab line"
        case .foundry: "Foundry"
        case .packaging: "Advanced packaging"
        case .memory: "HBM memory"
        case .rival: "Rival lab"
        case .rivalRun: "Rival training run"
        case .agency: "Agency"
        }
    }
}

/// What a pin or flow is coloured as (the view picks the colours).
enum MapTone: Hashable, Sendable {
    case mine, building, power, supply, alien, government, money, cost, rival(UInt32)
}

struct MapLine: Hashable, Sendable {
    let label: String
    let value: String
}

struct MapPin: Identifiable, Sendable {
    let id: String
    let kind: MapPinKind
    let layer: MapLayer
    let point: GeoPoint
    let title: String
    let subtitle: String
    var lines: [MapLine] = []
    var note: String = ""
    /// Your sites: megawatts planned. Everything else: a 0–1 weight against its peers.
    var size: Double = 0.3
    let tone: MapTone
    let symbol: String
    var screen: Screen? = nil
    /// A rival lab to open (its profile in the Rivals hub).
    var labID: String? = nil
    var since: Date? = nil
    /// You do business with it (a supplier you buy from, an agency you work for); drawn bright, the rest dim.
    var active = true
    var building = false
}

enum MapFlowKind: String, CaseIterable, Sendable {
    case chips, moneyIn, moneyOut, power, rivalRun

    var label: String {
        switch self {
        case .chips: "Chips on the way"
        case .moneyIn: "Money in"
        case .moneyOut: "Money out"
        case .power: "Power"
        case .rivalRun: "Rival training runs"
        }
    }
}

struct MapFlow: Identifiable, Sendable {
    let id: String
    let kind: MapFlowKind
    let layer: MapLayer
    let from: GeoPoint
    let to: GeoPoint
    let label: String
    /// Dollars a month, chips, megawatts or H100e, by kind.
    let value: Double
    var tone: MapTone
    /// 0–1 against the biggest flow of its kind (set once all are in).
    var weight: Double = 1
}

/// A region's export controls and who they're aimed at.
struct MapZone: Identifiable, Sendable {
    var id: String { region.rawValue }
    let region: Region
    let level: Double
    let stance: String
    let targets: [Region]
    let aim: String
    /// They raise what you pay for chips.
    let hitsYou: Bool
}

struct MapExposure: Identifiable, Sendable {
    let id: String
    let symbol: String
    let title: String
    let detail: String
    /// true good, false a risk, nil just so.
    let good: Bool?
}

struct MapFootprint: Sendable {
    var onlineMW = 0.0
    var buildingMW = 0.0
    var sites = 0
    var locations = 0
    var offices = 0
    var continents: [String] = []
    var chipsEnRoute = 0
    var revenueMonth = 0.0
    var rivalsTracked = 0
    /// Your sites at places the map has no coordinates for (a location added by a newer build).
    var unplaced = 0
}

struct MapSnapshot: Sendable {
    var pins: [MapPin] = []
    var flows: [MapFlow] = []
    var zones: [MapZone] = []
    var exposure: [MapExposure] = []
    var footprint = MapFootprint()
    var hq = GeoPoint(-122.42, 37.77)
}

enum WorldMap {
    // MARK: Snapshot

    static func snapshot(_ s: GameState) -> MapSnapshot {
        var m = MapSnapshot()
        let hq = hqPoint(s)
        m.hq = hq
        yours(s, &m)
        supply(s, &m)
        rivals(s, &m)
        government(s, &m)
        moneyIn(s, &m)
        m.zones = zones(s)
        m.exposure = exposure(s, m)
        // Weights: each flow against the biggest of its kind, square-rooted so small ones still show.
        for k in MapFlowKind.allCases {
            let top = m.flows.filter { $0.kind == k }.map(\.value).max() ?? 0
            guard top > 0 else { continue }
            for i in m.flows.indices where m.flows[i].kind == k { m.flows[i].weight = max(0.08, (m.flows[i].value / top).squareRoot()) }
        }
        return m
    }

    static func hqPoint(_ s: GameState) -> GeoPoint {
        WorldMapGeo.cities[s.hqCity] ?? WorldMapGeo.named(HQ.city(s).name) ?? WorldMapGeo.countryCapitals[s.hqCountry] ?? GeoPoint(-122.42, 37.77)
    }

    /// Where a datacenter location's pin sits.
    static func point(location id: String) -> GeoPoint? { WorldMapGeo.location(id) }

    /// A server room in the garage or the office is at headquarters, whatever grid it's billed on.
    private static func atHQ(_ site: Site) -> Bool { site.kind == .garage || site.kind == .office }

    private static func sitePoint(_ site: Site, _ s: GameState) -> GeoPoint? { atHQ(site) ? hqPoint(s) : point(location: site.locationID) }

    // MARK: Yours

    private static func yours(_ s: GameState, _ m: inout MapSnapshot) {
        let hq = m.hq
        let city = HQ.city(s)
        let country = HQ.country(s)
        let rooms = s.sites.filter(atHQ)
        let office = Economy.officeLevels[min(max(0, s.officeLevel), Economy.officeLevels.count - 1)]
        var hqLines = [MapLine(label: "Staff", value: "\(s.employees.count) of \(Economy.officeCapacity(s)) seats"),
                       MapLine(label: "Office", value: office.name.replacingOccurrences(of: "SF", with: city.name)),
                       MapLine(label: "Founded", value: s.startDate.gameMonth)]
        if !rooms.isEmpty { hqLines.append(MapLine(label: "Server room", value: Fmt.watts(rooms.reduce(0) { $0 + $1.capacityKW } * 1000))) }
        hqLines.append(MapLine(label: "Cash", value: Fmt.money(s.cash)))
        m.pins.append(MapPin(id: "hq", kind: .hq, layer: .yours, point: hq, title: s.companyName, subtitle: "Headquarters · \(city.name), \(country.name)",
                             lines: hqLines, note: city.cluster.isEmpty ? "" : "Known for \(city.cluster).", size: 1, tone: .mine, symbol: s.logoSymbol,
                             screen: .team, since: s.startDate))
        var continents: Set<String> = [WorldMapGeo.continent(hq)]

        for o in s.hq.satellites {
            let c = CountryCatalog.get(o.country)
            let cityDef = c.city(o.city)
            guard let p = WorldMapGeo.cities[o.city] ?? WorldMapGeo.named(cityDef.name) else { continue }
            continents.insert(WorldMapGeo.continent(p))
            m.footprint.offices += 1
            m.pins.append(MapPin(id: "office:\(o.id)", kind: .office, layer: .yours, point: p, title: "\(cityDef.name) office", subtitle: "\(c.flag) \(c.name) · \(o.seats) seats",
                                 lines: [MapLine(label: "Opened", value: o.opened.gameMonth), MapLine(label: "Hires", value: "Local pay, \(cityDef.cluster)")],
                                 size: min(1, Double(o.seats) / 200), tone: .mine, symbol: "building.2.fill", screen: .team, since: o.opened))
        }
        for p in s.hq.partners where p.active(s.date) {
            let c = CountryCatalog.get(p.country)
            let cityDef = c.city(p.city)
            guard let pt = WorldMapGeo.cities[p.city] ?? WorldMapGeo.named(cityDef.name) else { continue }
            m.pins.append(MapPin(id: "partner:\(p.id)", kind: .partner, layer: .yours, point: pt.offset(0.5, -0.4),
                                 title: p.kind == .computeCentre ? "National compute centre" : "University chair", subtitle: "\(cityDef.name), \(c.name)",
                                 lines: [MapLine(label: "Your stake", value: Fmt.money(p.cost)), MapLine(label: "Runs until", value: p.until.gameMonth)],
                                 note: p.kind.effect, size: 0.3, tone: .government, symbol: p.kind.symbol, screen: .team, since: p.signed))
        }

        // Datacenters, one pin per location.
        let rows = Campus.overview(s).filter { !atHQ($0.site) }
        let byLoc = Dictionary(grouping: rows, by: { $0.site.locationID })
        for loc in byLoc.keys.sorted() {
            let rs = byLoc[loc] ?? []
            guard let p = point(location: loc) else { m.footprint.unplaced += rs.count; continue }
            let online = rs.filter(\.ready).reduce(0) { $0 + $1.site.capacityKW } / 1000
            let planned = rs.reduce(0) { $0 + Campus.plannedTotalKW($1.site) } / 1000
            let building = rs.contains { !$0.ready || $0.site.expanding > 0 || $0.site.plannedKW > 0 }
            m.footprint.onlineMW += online
            m.footprint.buildingMW += max(0, planned - online)
            m.footprint.sites += rs.count
            m.footprint.locations += 1
            if online > 0 { continents.insert(WorldMapGeo.continent(p)) }
            var chips: [String: Int] = [:]
            for r in rs { for c in r.chips { chips[c.accelID, default: 0] += c.count } }
            var lines: [MapLine] = rs.sorted { $0.site.capacityKW > $1.site.capacityKW }.prefix(4).map { r in
                MapLine(label: r.site.name, value: "\(Fmt.watts(r.site.capacityKW * 1000)) \(r.ready ? "open" : "opens \(r.site.ready.gameShort)")"
                        + (r.site.expanding > 0 ? " · +\(Fmt.watts(r.site.expanding * 1000)) building" : "")
                        + (r.site.powerDeal == .grid ? "" : " · \(r.site.powerDeal.rawValue)"))
            }
            if rs.count > 4 { lines.append(MapLine(label: "", value: "and \(rs.count - 4) more")) }
            let top = chips.sorted { $0.value > $1.value }.prefix(3)
                .map { "\(Fmt.int($0.value))× \(HardwareCatalog.get($0.key)?.name ?? $0.key)" }
            if !top.isEmpty { lines.append(MapLine(label: "Chips", value: top.joined(separator: ", "))) }
            let waiting = rs.reduce(0) { $0 + $1.waiting }
            if waiting > 0 { lines.append(MapLine(label: "Waiting for space", value: Fmt.int(waiting))) }
            if let next = rs.flatMap(\.arrivals).min(by: { $0.date < $1.date }) { lines.append(MapLine(label: "Next arrival", value: "\(next.label) · \(next.date.gameShort)")) }
            let name = LocationCatalog.byID[loc]?.name ?? loc
            let sites = "\(rs.count) site\(rs.count == 1 ? "" : "s")"
            let opens = rs.map(\.site.ready).min() ?? s.date
            let sub = online > 0 ? "\(sites) · \(Fmt.watts(online * 1e6)) online" + (planned > online + 0.01 ? " · \(Fmt.watts(planned * 1e6)) planned" : "")
                                 : "\(sites) · \(Fmt.watts(planned * 1e6)) opening \(opens.gameMonth)"
            m.pins.append(MapPin(id: "site:\(loc)", kind: .campus, layer: .yours, point: p, title: name, subtitle: sub, lines: lines,
                                 note: LocationCatalog.byID[loc]?.blurb ?? "", size: max(planned, 0.01), tone: online > 0 ? .mine : .building,
                                 symbol: rs.contains { $0.site.kind == .datacenter } ? "building.columns.fill" : "server.rack", screen: .datacenters,
                                 since: rs.map(\.site.opened).min(), building: building))
        }

        // Power plants next to the campuses they feed.
        let deals = s.powerContracts.filter { $0.kind != .battery && $0.kind != .interconnect && ($0.end ?? .distantFuture) > s.date }
        let byDeal = Dictionary(grouping: deals, by: { "\($0.kind.rawValue)|\($0.locationID)" })
        for key in byDeal.keys.sorted() {
            guard let cs = byDeal[key], let first = cs.first, let site = point(location: first.locationID) else { continue }
            let mw = cs.reduce(0) { $0 + $1.mw }
            let online = cs.filter { $0.isOnline(s.date) }.reduce(0) { $0 + $1.mw }
            let price = cs.reduce(0) { $0 + $1.priceMWh * $1.mw } / max(1, mw)
            let plant = site.offset(plantOffset(first.kind).0, plantOffset(first.kind).1)
            let place = LocationCatalog.byID[first.locationID]?.name ?? first.locationID
            var lines = [MapLine(label: "Capacity", value: "\(Fmt.watts(mw * 1e6)) firm" + (online <= 0 ? " (not online yet)" : (online < mw ? " (\(Fmt.watts(online * 1e6)) online)" : ""))),
                         MapLine(label: "Price", value: "$\(Fmt.trim(price, 0))/MWh")]
            if let next = cs.filter({ !$0.isOnline(s.date) }).map(\.online).min() { lines.append(MapLine(label: "Online", value: next.gameMonth)) }
            if let end = cs.compactMap(\.end).max() { lines.append(MapLine(label: "Runs until", value: end.gameMonth)) }
            m.pins.append(MapPin(id: "power:\(key)", kind: .power, layer: .yours, point: plant, title: first.kind.rawValue,
                                 subtitle: "\(first.kind.onSite ? "On site at" : "Feeding") \(place)", lines: lines, note: first.kind.blurb,
                                 size: mw, tone: .power, symbol: first.kind.symbol, screen: .datacenters, since: cs.map(\.signed).min(), building: online < mw))
            m.flows.append(MapFlow(id: "power:\(key)", kind: .power, layer: .yours, from: plant, to: site,
                                   label: "\(first.kind.rawValue): \(Fmt.watts(mw * 1e6)) to \(place)", value: max(1, online), tone: .power))
        }

        // Your fabs and the alien line.
        for f in s.semi.fabs {
            guard let p = WorldMapGeo.semi[f.site] else { continue }
            let site = SemiCatalog.siteByID[f.site]
            let open = f.open(s.date)
            if open { continents.insert(WorldMapGeo.continent(p)) }
            m.pins.append(MapPin(id: "fab:\(f.id)", kind: .fab, layer: .yours, point: p.offset(0.35, 0.3), title: f.name,
                                 subtitle: "\(SemiCatalog.nodeByID[f.node]?.name ?? f.node) fab · \(site?.name ?? f.site)",
                                 lines: [MapLine(label: "Wafer starts", value: "\(Fmt.count(f.wafersMonth))/month"),
                                         MapLine(label: open ? "Open since" : "Opens", value: f.opens.gameMonth),
                                         MapLine(label: "Wafers made", value: Fmt.count(f.wafersDone))],
                                 note: site?.blurb ?? "", size: min(1, f.wafersMonth / 40_000), tone: open ? .mine : .building, symbol: "cpu.fill",
                                 screen: .semiconductors, since: f.started, building: !open))
        }
        if s.alienFab.exists {
            let p = alienFabPoint(s)
            var lines = [MapLine(label: "Output", value: "\(Fmt.count(s.alienFab.capacityMonth)) chips a month"),
                         MapLine(label: "Made so far", value: Fmt.count(s.alienFab.produced))]
            if s.alienFab.pendingCapacity > 0, let r = s.alienFab.pendingReady {
                lines.append(MapLine(label: "Expansion", value: "+\(Fmt.count(s.alienFab.pendingCapacity))/month from \(r.gameShort)"))
            }
            if s.alienFab.yieldLevel > 0 { lines.append(MapLine(label: "Yield discoveries", value: "\(s.alienFab.yieldLevel)")) }
            m.pins.append(MapPin(id: "alienfab", kind: .alienFab, layer: .yours, point: p, title: "Alien fab line", subtitle: "Sealed cleanroom · no export licence needed",
                                 lines: lines, note: "Merchant supply rules and export controls never touch this line.", size: 0.8, tone: .alien,
                                 symbol: "atom", screen: .xeno, since: s.alienFab.opened))
        }
        m.footprint.continents = continents.sorted()

        // Chips on the way: one flow per origin and destination.
        var chipFlows: [String: (from: GeoPoint, to: GeoPoint, count: Int, names: Set<String>, lands: Date, origin: String, cost: Double)] = [:]
        for o in s.orders {
            guard let site = s.sites.first(where: { $0.id == o.siteID }), let to = sitePoint(site, s) else { continue }
            let origin = chipOrigin(o.accelID, s)
            let left = max(0, o.count - (o.delivered ?? 0))
            guard left > 0 else { continue }
            let key = "\(origin.key)>\(atHQ(site) ? "hq" : site.locationID)"
            let name = HardwareCatalog.get(o.accelID)?.name ?? o.accelID
            var f = chipFlows[key] ?? (origin.point, to, 0, [], o.arrives, origin.name, 0)
            f.count += left
            f.names.insert(name)
            f.lands = min(f.lands, o.made != nil ? AlienFab.nextShipment(o, s) : o.arrives)
            f.cost += o.unitCost * Double(left)
            chipFlows[key] = f
            m.footprint.chipsEnRoute += left
        }
        for key in chipFlows.keys.sorted() {
            guard let f = chipFlows[key] else { continue }
            let what = f.names.count == 1 ? "\(Fmt.int(f.count))× \(f.names.first ?? "")" : "\(Fmt.int(f.count)) chips"
            m.flows.append(MapFlow(id: "chips:\(key)", kind: .chips, layer: .yours, from: f.from, to: f.to,
                                   label: "\(what) from \(f.origin) · next lands \(f.lands.gameShort)", value: Double(f.count), tone: .mine))
            if f.cost > 0 {
                m.flows.append(MapFlow(id: "pay:\(key)", kind: .moneyOut, layer: .yours, from: m.hq, to: f.from,
                                       label: "\(Fmt.money(f.cost)) of chips on order from \(f.origin)", value: f.cost / 6, tone: .cost))
            }
        }
        // Building work paid from headquarters.
        // Leases are built by the landlord; only campuses you own draw construction money.
        for site in s.sites where site.kind == .datacenter && (!site.isReady(s.date) || site.expanding > 0) {
            guard let to = point(location: site.locationID) else { continue }
            let months = max(1, Double(GameCalendar.daysBetween(site.opened, site.ready)) / 30.4)
            let value = site.isReady(s.date) ? site.expanding / 1000 * Campus.capexPerMW(site.cooling, s, location: site.locationID) / 8 : site.capex / months
            m.flows.append(MapFlow(id: "build:\(site.id)", kind: .moneyOut, layer: .yours, from: m.hq, to: to,
                                   label: "Building \(site.name): \(site.isReady(s.date) ? "+\(Fmt.watts(site.expanding * 1000))" : "opens \(site.ready.gameShort)")",
                                   value: value, tone: .cost))
        }
    }

    /// Where a plant sits next to its campus, by kind (degrees east, north), so several deals at one place don't stack.
    private static func plantOffset(_ k: PowerKind) -> (Double, Double) {
        switch k {
        case .solar: (-1.6, -1.1)
        case .wind: (-1.9, 1.2)
        case .hydro: (1.3, 1.7)
        case .geothermal: (0.9, -1.0)
        case .nuclearRestart: (2.1, 0.5)
        case .nuclearContract: (1.7, -0.7)
        case .gasTurbines: (0.8, -0.6)
        case .smr: (0.6, 0.8)
        case .fusion: (-0.8, 0.9)
        case .battery, .interconnect: (0.3, -0.3)
        }
    }

    /// The alien line sits beside your biggest open campus (or headquarters before you have one).
    static func alienFabPoint(_ s: GameState) -> GeoPoint {
        let big = s.sites.filter { !atHQ($0) }.max { $0.capacityKW < $1.capacityKW }
        return (big.flatMap { point(location: $0.locationID) } ?? hqPoint(s)).offset(1.4, -0.9)
    }

    /// Where a chip is made: your fab or foundry for your own silicon, the alien line, or the foundry that makes the
    /// vendor's chips (nearly every merchant accelerator comes out of Hsinchu; Huawei's out of Shanghai).
    static func chipOrigin(_ id: String, _ s: GameState) -> (key: String, name: String, point: GeoPoint) {
        if AlienFab.isAlienChip(id) { return ("alien", "your alien fab line", alienFabPoint(s)) }
        let a = HardwareCatalog.get(id)
        if a?.vendor == .custom || Semis.isSemiChip(id) {
            if let f = s.semi.fabs.first(where: { $0.open(s.date) }), let p = WorldMapGeo.semi[f.site] { return ("fab:\(f.id)", f.name, p.offset(0.35, 0.3)) }
            if let b = s.semi.bookings.first, let p = WorldMapGeo.semi[b.foundry] {
                return (b.foundry, SemiCatalog.foundryByID[b.foundry]?.name ?? b.foundry, p)
            }
        }
        let fid = a?.vendor == .huawei ? "pearl" : "fsw"
        return (fid, SemiCatalog.foundryByID[fid]?.name ?? fid, WorldMapGeo.semi[fid] ?? GeoPoint(120.97, 24.8))
    }

    // MARK: Supply chain

    private static func supply(_ s: GameState, _ m: inout MapSnapshot) {
        let origins = Set(s.orders.map { chipOrigin($0.accelID, s).key })
        let owned = Dictionary(grouping: s.owned, by: { chipOrigin($0.accelID, s).key }).mapValues { $0.reduce(0) { $0 + $1.count } }
        for f in SemiCatalog.foundries {
            guard let p = WorldMapGeo.semi[f.id] else { continue }
            let bookings = s.semi.bookings.filter { $0.foundry == f.id && $0.end > s.date }
            var lines = [MapLine(label: "Leading edge", value: f.lag < 0.1 ? "first with every node" : "\(Fmt.trim(f.lag, 1)) years behind")]
            if let n = owned[f.id], n > 0 { lines.append(MapLine(label: "Your chips made here", value: Fmt.int(n))) }
            if let w = s.semi.foundryWafers[f.id], w > 0 { lines.append(MapLine(label: "Your wafers so far", value: Fmt.count(w))) }
            if !bookings.isEmpty { lines.append(MapLine(label: "Bookings", value: "\(bookings.count) · \(Fmt.count(bookings.reduce(0) { $0 + $1.wafersMonth })) wafers/month")) }
            lines.append(MapLine(label: "Quake exposure", value: f.quake >= 0.6 ? "high" : (f.quake >= 0.25 ? "moderate" : "low")))
            m.pins.append(MapPin(id: "foundry:\(f.id)", kind: .foundry, layer: .supply, point: p, title: f.name, subtitle: "Foundry · \(f.place)",
                                 lines: lines, note: f.blurb + (f.id == "fsw" ? " Nearly every merchant AI accelerator starts here." : ""),
                                 size: min(1, 0.45 * f.capFactor), tone: .supply, symbol: "cpu", screen: .semiconductors,
                                 active: origins.contains(f.id) || !bookings.isEmpty || (owned[f.id] ?? 0) > 0 || f.id == "fsw"))
        }
        let contracts = Set(s.semi.supply.filter { $0.end > s.date }.map(\.supplier))
        for sup in SemiCatalog.suppliers where s.year >= sup.from {
            guard let p = WorldMapGeo.semi[sup.id] else { continue }
            let pack = sup.kind == "pack"
            m.pins.append(MapPin(id: "supplier:\(sup.id)", kind: pack ? .packaging : .memory, layer: .supply, point: p, title: sup.name,
                                 subtitle: pack ? "Advanced packaging · \(sup.region.title)" : "HBM memory · \(sup.region.title)",
                                 lines: [MapLine(label: pack ? "Assembly yield" : "Stacks that pass", value: Fmt.pct(sup.yield, decimals: 0)),
                                         MapLine(label: "Lead time", value: "\(Int(sup.leadDays)) days"),
                                         MapLine(label: "Your contract", value: contracts.contains(sup.id) ? "yes" : "none")],
                                 note: sup.blurb, size: min(1, 0.35 * sup.capFactor), tone: .supply, symbol: pack ? "square.stack.3d.up.fill" : "memorychip",
                                 screen: .semiconductors, active: contracts.contains(sup.id)))
        }
    }

    // MARK: Rivals

    private static func rivals(_ s: GameState, _ m: inout MapSnapshot) {
        let active = s.competitors.indices.filter { RivalIntel.isActive(s.competitors[$0], s) }
        let topCompute = active.map { s.competitors[$0].computeH100e }.max() ?? 1
        var topChips = 1.0
        for i in active { if let p = s.competitors[i].project { topChips = max(topChips, p.chips) } }
        for i in active {
            let c = s.competitors[i]
            let def = c.def
            guard let p = WorldMapGeo.named(def.hq) else { continue }
            m.footprint.rivalsTracked += 1
            var lines = [MapLine(label: "Compute", value: "\(Fmt.count(c.computeH100e)) H100e")]
            if c.valuation > 0 { lines.append(MapLine(label: "Valuation", value: Fmt.money(c.valuation))) }
            if let last = c.models.last { lines.append(MapLine(label: "Latest model", value: last.name)) }
            if c.apiShare > 0.005 { lines.append(MapLine(label: "API share", value: Fmt.pct(c.apiShare, decimals: 0))) }
            if c.headcount > 0 { lines.append(MapLine(label: "Staff", value: Fmt.int(c.headcount))) }
            m.pins.append(MapPin(id: "rival:\(def.id)", kind: .rival, layer: .rivals, point: p, title: def.name, subtitle: "\(def.archetype) · \(def.hq)",
                                 lines: lines, note: "", size: max(0.15, (c.computeH100e / max(1, topCompute)).squareRoot()), tone: .rival(def.color),
                                 symbol: def.symbol, screen: .competitors, labID: def.id, since: def.founded.date))
            // The run behind its next model, once the rumour mill knows where it trains.
            guard let proj = c.project, let o = RivalIntel.outlook(s, i), o.trainingKnown, o.phase != .planning,
                  let site = WorldMapGeo.trainingSite(proj.site) else { continue }
            let pre = RivalIntel.preProgress(proj, on: s.date)
            m.pins.append(MapPin(id: "run:\(def.id)", kind: .rivalRun, layer: .rivals, point: site, title: proj.name,
                                 subtitle: "\(def.name) · \(o.phase.rawValue)",
                                 lines: [MapLine(label: "Codename", value: proj.codename), MapLine(label: "Cluster", value: "\(Fmt.count(proj.chips)) H100e"),
                                         MapLine(label: "Site", value: proj.site), MapLine(label: "Pre-training", value: Fmt.pct(pre, decimals: 0)),
                                         MapLine(label: "Rumoured launch", value: RivalIntel.windowText(o))],
                                 size: max(0.2, (proj.chips / topChips).squareRoot()), tone: .rival(def.color), symbol: o.phase.symbol,
                                 screen: .rivalWatch, labID: def.id, since: proj.started))
            m.flows.append(MapFlow(id: "run:\(def.id)", kind: .rivalRun, layer: .rivals, from: p, to: site,
                                   label: "\(def.name) trains \(proj.name) on \(Fmt.count(proj.chips)) H100e", value: proj.chips, tone: .rival(def.color)))
        }
    }

    // MARK: Government

    private static func government(_ s: GameState, _ m: inout MapSnapshot) {
        let live = s.advanced.programmes.filter { $0.status == .active }
        let budgets = AgencyCatalog.all.map { AdvancedProjects.agencyBudget($0, s) }
        let top = budgets.max() ?? 1
        for (a, budget) in zip(AgencyCatalog.all, budgets) {
            let p = WorldMapGeo.agencies[a.id] ?? WorldMapGeo.countryCapitals[a.country] ?? WorldMapGeo.capital(a.region)
            let mine = live.filter { $0.sol.agency == a.id }
            var lines = [MapLine(label: "Type", value: a.kind.label), MapLine(label: "AI budget", value: "\(Fmt.money(budget))/year")]
            for prog in mine.prefix(3) {
                lines.append(MapLine(label: prog.sol.title, value: "\(prog.stage.title) · \(Fmt.money(prog.value))"))
            }
            m.pins.append(MapPin(id: "agency:\(a.id)", kind: .agency, layer: .government, point: p, title: a.name, subtitle: "\(a.short) · \(a.homeName)",
                                 lines: lines, note: a.blurb, size: max(0.15, (budget / max(1, top)).squareRoot()), tone: .government, symbol: a.symbol,
                                 screen: .advancedProjects, since: mine.map(\.awarded).min(), active: !mine.isEmpty))
            let monthly = mine.reduce(0) { $0 + $1.value / Double(max(1, $1.sol.months)) }
            if monthly > 0 {
                m.flows.append(MapFlow(id: "gov:\(a.id)", kind: .moneyIn, layer: .government, from: p, to: m.hq,
                                       label: "\(a.short): \(mine.count) programme\(mine.count == 1 ? "" : "s"), about \(Fmt.money(monthly))/month", value: monthly, tone: .money))
            }
        }
    }

    // MARK: Money in

    /// Revenue by where AI spending is: each region's share of world AI spend, more at home, much less in China while
    /// US export controls are high (a Western lab sells little there). An estimate: the books don't split revenue by region.
    static func revenueSplit(_ s: GameState) -> [(region: Region, share: Double)] {
        let home = HQ.region(s)
        let usExports = s.nations.ready ? s.nations.level(.us, .exports) : (s.market.exportControls ? 70 : 30)
        var w = Region.allCases.map { r -> (Region, Double) in
            var x = r.weight
            if r == home { x *= 1.5 }
            if r == .china && home != .china { x *= usExports >= 50 ? 0.15 : 0.6 }
            return (r, x)
        }
        let total = w.reduce(0) { $0 + $1.1 }
        w = w.map { ($0.0, $0.1 / max(1e-9, total)) }
        return w.map { (region: $0.0, share: $0.1) }
    }

    private static func moneyIn(_ s: GameState, _ m: inout MapSnapshot) {
        let rev = s.history.last?.revenue ?? 0
        m.footprint.revenueMonth = rev
        guard rev > 0 else { return }
        for (r, share) in revenueSplit(s) where share >= 0.03 {
            m.flows.append(MapFlow(id: "rev:\(r.rawValue)", kind: .moneyIn, layer: .yours, from: WorldMapGeo.marketHub(r), to: m.hq,
                                   label: "\(r.title): about \(Fmt.money(rev * share))/month", value: rev * share, tone: .money))
        }
    }

    // MARK: Export controls

    static func zones(_ s: GameState) -> [MapZone] {
        let home = HQ.region(s)
        return Region.allCases.map { r in
            let level = s.nations.ready ? s.nations.level(r, .exports) : (r == .us && s.market.exportControls ? 70 : (r == .us ? 30 : 20))
            var targets: [Region] = []
            var aim = "No controls aimed at anyone"
            var hits = false
            switch r {
            case .us:
                if level >= 40 { targets = [.china]; aim = "Advanced chips and model weights kept from China" + (level >= 65 ? "; licences for everyone else" : "") }
                hits = home == .china ? level > 40 : (home != .us && level > 65)
            case .eu, .uk, .japanKorea:
                if level >= 40 { targets = [.china]; aim = "Chipmaking tools kept from China" }
                hits = home == .china && level > 40
            case .china:
                if level >= 50 { targets = [.us, .eu, .japanKorea]; aim = "Critical minerals (gallium, germanium, rare earths) rationed abroad" }
                hits = home != .china && level > 50
            case .gulf, .india:
                break
            }
            let stance = s.nations.ready ? s.nations.strategy(r).stance : ""
            return MapZone(region: r, level: level, stance: stance, targets: targets, aim: aim, hitsYou: hits && !targets.isEmpty)
        }
    }

    // MARK: Exposure

    static func exposure(_ s: GameState, _ m: MapSnapshot) -> [MapExposure] {
        var out: [MapExposure] = []
        // Concentration: how much of your power sits in one place.
        var byLoc: [String: Double] = [:]
        for site in s.sites where !atHQ(site) && site.isReady(s.date) { byLoc[site.locationID, default: 0] += site.capacityKW / 1000 }
        let total = byLoc.values.reduce(0, +)
        if total >= 5, let top = byLoc.max(by: { $0.value < $1.value }) {
            let share = top.value / total
            let name = LocationCatalog.byID[top.key]?.name ?? top.key
            if byLoc.count == 1 {
                out.append(MapExposure(id: "conc", symbol: "scope", title: "All your compute is in \(name)",
                                       detail: "One heatwave, grid emergency or storm there hits every chip you own. A second location spreads the risk.", good: false))
            } else {
                out.append(MapExposure(id: "conc", symbol: "scope", title: "\(Fmt.pct(share, decimals: 0)) of your power is in \(name)",
                                       detail: "\(byLoc.count) locations in all." + (share >= 0.7 ? " Still concentrated: trouble there would hurt." : " Spread out enough that one bad week won't stop you."),
                                       good: share < 0.7))
            }
        }
        // Where your chips come from.
        var made: [String: Int] = [:]
        for b in s.owned { made[chipOrigin(b.accelID, s).key, default: 0] += b.count }
        for o in s.orders { made[chipOrigin(o.accelID, s).key, default: 0] += max(0, o.count - (o.delivered ?? 0)) }
        let chips = made.values.reduce(0, +)
        if chips > 0 {
            let taiwan = Double(made["fsw"] ?? 0) / Double(chips)
            if taiwan >= 0.5 {
                out.append(MapExposure(id: "taiwan", symbol: "exclamationmark.triangle.fill", title: "\(Fmt.pct(taiwan, decimals: 0)) of your chips come out of Hsinchu",
                                       detail: "Taiwan makes nearly every merchant accelerator. An earthquake, drought or blockade there would stop your deliveries; your own silicon or another foundry hedges it.",
                                       good: false))
            } else {
                out.append(MapExposure(id: "taiwan", symbol: "checkmark.seal.fill", title: "Your chip supply isn't tied to one foundry",
                                       detail: "Only \(Fmt.pct(taiwan, decimals: 0)) of your chips come from Hsinchu.", good: true))
            }
        }
        // Export rules on your chip bill.
        // Nations.chipFactor = home subsidies + export controls aimed at you; split them so the line says which.
        let f = Nations.chipFactor(s)
        let subsidy = s.nations.ready ? -0.08 * (Nations.homeLevel(s, .subsidy) - 45) / 60 : 0
        let export = f - 1 - subsidy
        let hitting = m.zones.filter(\.hitsYou).map { $0.region.short }
        let subsidyText = abs(subsidy) < 0.005 ? "" : (subsidy < 0 ? " Home subsidies take \(Fmt.pct(-subsidy, decimals: 0)) off." : " Thin home subsidies add \(Fmt.pct(subsidy, decimals: 0)).")
        if export > 0.005 {
            out.append(MapExposure(id: "export", symbol: "shippingbox.and.arrow.backward.fill", title: "Export controls add \(Fmt.pct(export, decimals: 0)) to your chip prices",
                                   detail: (hitting.isEmpty ? "Rules aimed at your home push up what you pay." : "Controls from \(hitting.joined(separator: ", ")) reach you.") + subsidyText, good: false))
        } else {
            out.append(MapExposure(id: "export", symbol: "shippingbox.fill", title: "No export control raises your chip prices",
                                   detail: (hitting.isEmpty ? "The controls in force are aimed elsewhere." : "Controls from \(hitting.joined(separator: ", ")) don't reach a lab your size yet.") + subsidyText,
                                   good: subsidy <= 0.005 ? true : nil))
        }
        // Power hedged with long-term deals.
        if total >= 5 {
            let hedged = s.powerContracts.filter { $0.kind.suppliesEnergy && $0.isOnline(s.date) && ($0.end ?? .distantFuture) > s.date }.reduce(0) { $0 + $1.mw }
            let share = min(1, hedged / total)
            out.append(MapExposure(id: "power", symbol: "bolt.fill", title: share > 0.01 ? "\(Fmt.pct(share, decimals: 0)) of your power is under long-term deals" : "All your power is bought from the grid",
                                   detail: share >= 0.5 ? "Grid price spikes barely touch you." : "Grid prices rise as AI strains the grid; purchase agreements and on-site plants lock in a price.",
                                   good: share >= 0.5 ? true : (s.world.gridStress >= 30 ? false : nil)))
        }
        // Rivals building next door.
        let mine = Set(s.sites.filter { !atHQ($0) }.compactMap { point(location: $0.locationID) }.map { "\(Int($0.lon.rounded())),\(Int($0.lat.rounded()))" })
        for p in m.pins where p.kind == .rivalRun && mine.contains("\(Int(p.point.lon.rounded())),\(Int(p.point.lat.rounded()))") {
            out.append(MapExposure(id: "near:\(p.id)", symbol: "binoculars.fill", title: "\(p.subtitle.components(separatedBy: " · ").first ?? "A rival") trains next door",
                                   detail: "\(p.title) is running near your campus: you're bidding for the same power, land and technicians.", good: nil))
        }
        return out
    }

    // MARK: Monthly: your expansion

    /// What you're on now: open campus locations, office cities, open fabs and the alien line, with where they are.
    private static func footprint(_ s: GameState) -> [(key: String, kind: String, text: String, point: GeoPoint)] {
        var out: [(key: String, kind: String, text: String, point: GeoPoint)] = []
        for site in s.sites.sorted(by: { $0.opened < $1.opened }) where !atHQ(site) && site.isReady(s.date) {
            guard let p = point(location: site.locationID), !out.contains(where: { $0.key == "loc:\(site.locationID)" }) else { continue }
            out.append(("loc:\(site.locationID)", "site", "First campus in \(LocationCatalog.byID[site.locationID]?.name ?? site.locationID): \(site.name)", p))
        }
        for o in s.hq.satellites {
            let c = CountryCatalog.get(o.country)
            let name = c.city(o.city).name
            guard let p = WorldMapGeo.cities[o.city] ?? WorldMapGeo.named(name), !out.contains(where: { $0.key == "office:\(o.city)" }) else { continue }
            out.append(("office:\(o.city)", "office", "Opened an office in \(name), \(c.name)", p))
        }
        for f in s.semi.fabs where f.open(s.date) {
            guard let p = WorldMapGeo.semi[f.site] else { continue }
            out.append(("fab:\(f.id)", "fab", "\(f.name) fab opened in \(SemiCatalog.siteByID[f.site]?.name ?? f.site)", p))
        }
        if s.alienFab.exists { out.append(("alien", "alien", "The alien fab line powered up", alienFabPoint(s))) }
        return out
    }

    static func monthly(_ s: inout GameState) {
        let now = footprint(s)
        let siteContinents = now.filter { $0.kind == "site" }.map { (continent: WorldMapGeo.continent($0.point), item: $0) }
        let officeContinents = Set(now.filter { $0.kind == "office" }.map { WorldMapGeo.continent($0.point) })
        guard s.worldMap.seeded else {
            // First month end in this save: record what's there quietly. Home counts as already "reached".
            s.worldMap.seeded = true
            s.worldMap.places = Set(now.map(\.key))
            s.worldMap.siteContinents = Set(siteContinents.map(\.continent)).union([WorldMapGeo.continent(hqPoint(s))])
            s.worldMap.officeContinents = officeContinents.union([WorldMapGeo.continent(hqPoint(s))])
            return
        }
        for item in now where !s.worldMap.places.contains(item.key) {
            s.worldMap.places.insert(item.key)
            log(&s, item.text, item.point, item.kind)
        }
        for (continent, item) in siteContinents where !s.worldMap.siteContinents.contains(continent) {
            s.worldMap.siteContinents.insert(continent)
            let all = s.worldMap.siteContinents.sorted()
            let name = LocationCatalog.byID[String(item.key.dropFirst(4))]?.name ?? "a new site"
            Sim.news(&s, "\(s.companyName) opens its first datacenter in \(continent)",
                     "Your site in \(name) is live. \(s.companyName) now runs compute on \(all.count) continent\(all.count == 1 ? "" : "s"): \(all.joined(separator: ", "))."
                     + (all.count >= 3 ? " A truly global lab: closer to users everywhere and harder for one grid or one government to stop." : ""),
                     .company, image: "hyperscale_campus", good: true)
            log(&s, "First datacenter in \(continent)", item.point, "continent")
        }
        s.worldMap.officeContinents.formUnion(officeContinents)
    }

    private static func log(_ s: inout GameState, _ text: String, _ p: GeoPoint, _ kind: String) {
        s.worldMap.log.insert(MapMilestone(date: s.date, text: text, lon: p.lon, lat: p.lat, kind: kind), at: 0)
        if s.worldMap.log.count > 60 { s.worldMap.log.removeLast(s.worldMap.log.count - 60) }
    }

    // MARK: Harness

    /// Replay actions that change the map the way a player would: `map:build:<location>:<MW>` (a campus, or a colo
    /// cage up to its cap with `:colo`), `map:office:<country>:<city>`, `map:power:<kind>:<location>:<MW>` (PowerKind
    /// case name). Returns false for anything else.
    static func harnessAction(_ s: inout GameState, _ t: String) -> Bool {
        let p = t.split(separator: ":").map(String.init)
        guard p.count >= 2, p[0] == "map" else { return false }
        switch p[1] {
        case "build" where p.count >= 4:
            let colo = p.count > 4 && p[4] == "colo"
            let name = "\(LocationCatalog.byID[p[2]]?.name.components(separatedBy: ",").first ?? p[2]) \(colo ? "cage" : "campus")"
            let why = s.buildSite(kind: colo ? .colo : .datacenter, locationID: p[2], capacityKW: (Double(p[3]) ?? 1) * 1000, cooling: .liquid, power: .grid, name: name)
            print("map build \(p[3]) MW at \(p[2]): \(why ?? "ok")")
        case "office" where p.count == 4:
            print("map office \(p[3]): \(s.openSatellite(country: p[2], city: p[3]) ?? "ok")")
        case "power" where p.count == 5:
            guard let kind = PowerKind.allCases.first(where: { "\($0)" == p[2] }) else { print("map power: unknown kind \(p[2])"); return true }
            print("map power \(kind.rawValue) \(p[4]) MW at \(p[3]): \(s.signPower(kind, locationID: p[3], mw: Double(p[4]) ?? 10) ?? "ok")")
        default:
            print("map: unknown \(t)")
        }
        return true
    }

    /// `--replay-save <save> <days> map`: what the map shows, in a few lines.
    static func report(_ s: GameState, full: Bool) -> [String] {
        let m = snapshot(s)
        var out: [String] = []
        let count = { (l: MapLayer) in m.pins.filter { $0.layer == l }.count }
        let flows = MapFlowKind.allCases.compactMap { k -> String? in
            let fs = m.flows.filter { $0.kind == k }
            guard !fs.isEmpty else { return nil }
            let total = fs.reduce(0) { $0 + $1.value }
            let v: String = switch k {
            case .chips: "\(Fmt.int(Int(total))) chips"
            case .moneyIn, .moneyOut: "\(Fmt.money(total))/mo"
            case .power: Fmt.watts(total * 1e6)
            case .rivalRun: "\(Fmt.count(total)) H100e"
            }
            return "\(k.label) \(fs.count) (\(v))"
        }
        let f = m.footprint
        out.append("MAP \(s.date.gameShort): pins yours \(count(.yours)) rivals \(count(.rivals)) supply \(count(.supply)) government \(count(.government))"
                   + " · flows: \(flows.isEmpty ? "none" : flows.joined(separator: ", "))")
        out.append("    footprint: \(Fmt.watts(f.onlineMW * 1e6)) online, \(Fmt.watts(f.buildingMW * 1e6)) building, \(f.sites) sites at \(f.locations) locations, \(f.offices) offices"
                   + " · continents: \(f.continents.joined(separator: ", ")) · chips en route \(Fmt.int(f.chipsEnRoute))" + (f.unplaced > 0 ? " · \(f.unplaced) unplaced" : ""))
        for e in m.exposure { out.append("    exposure[\(e.good.map { $0 ? "good" : "risk" } ?? "note")]: \(e.title) — \(e.detail)") }
        let zones = m.zones.filter { !$0.targets.isEmpty }.map { "\($0.region.short) \(Int($0.level.rounded()))→\($0.targets.map(\.short).joined(separator: "/"))\($0.hitsYou ? " (hits you)" : "")" }
        out.append("    export zones: \(zones.isEmpty ? "none" : zones.joined(separator: ", "))")
        if full {
            for p in m.pins where p.layer != .supply || p.active {
                out.append("    pin [\(p.kind.label)] \(p.title) — \(p.subtitle) @ \(Fmt.trim(p.point.lat, 1)),\(Fmt.trim(p.point.lon, 1))"
                           + (p.lines.isEmpty ? "" : " · " + p.lines.prefix(3).map { $0.label.isEmpty ? $0.value : "\($0.label): \($0.value)" }.joined(separator: "; ")))
            }
            for fl in m.flows { out.append("    flow [\(fl.kind.label)] \(fl.label) (weight \(Fmt.trim(fl.weight, 2)))") }
        }
        return out
    }
}
