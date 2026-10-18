import Foundation

// MARK: - 3.4: products that capabilities unlock

/// A product line beyond chat, API, agents and enterprise contracts. It opens when your best released model crosses
/// its domain thresholds and you've done the research that makes it shippable.
struct ProductDef: Identifiable, Sendable {
    let id: String
    let name: String
    let symbol: String
    /// What it is, for the buyer.
    let pitch: String
    /// How it earns.
    let earns: String
    /// Domain bars your best released model must clear.
    let needs: [(CapDomain, Double)]
    /// The research item that makes it shippable (its card says "Opens a product line").
    let research: String
    /// What makes one lab's product better than another's.
    let mix: [(CapDomain, Double)]
    /// Annual spend on this kind of product worldwide, by year, before market hype.
    let market: [(Double, Double)]
    /// Team, compliance and go-to-market per month at 2026 prices.
    let upkeep: Double
    /// Share of revenue spent on the compute that serves it.
    let serving: Double
    /// How much of the market stays with specialists (as a weight against one lab product at the frontier).
    let specialists: Double
    /// How keen each founding lab is to sell one (others use their plays).
    let appetite: [String: Double]
    /// The rival product's name after the lab's product brand.
    let suffix: String
}

/// One of your product lines.
struct ProductLine: Codable, Hashable, Identifiable {
    var id: String
    var launched: Date
    /// Share of the market it holds today, and where it's heading.
    var share: Double = 0
    var target: Double = 0
    /// Quality on the capability scale (its domain mix on your best released models).
    var quality: Double = 0
    var revenueMonth: Double = 0
    var costMonth: Double = 0
    var lastRevenue: Double = 0
    var lastCost: Double = 0
    var lifetime: Double = 0
}

/// A rival lab's competing product.
struct RivalProduct: Codable, Hashable, Identifiable {
    var id: String { "\(lab)|\(product)" }
    var lab: String
    var product: String
    var launched: Date
    var share: Double = 0
    var target: Double = 0
    var quality: Double = 0
}

enum ProductLines {
    static let catalog: [ProductDef] = [
        ProductDef(id: "voice", name: "Voice Assistant", symbol: "waveform.circle.fill",
                   pitch: "A voice you can talk to like a person: on phones, in cars and answering call-centre lines.",
                   earns: "Consumer subscriptions plus per-minute fees from call centres.",
                   needs: [(.voice, 112), (.social, 110)], research: "full_duplex_voice", mix: [(.voice, 0.6), (.social, 0.4)],
                   market: [(2024.4, 1.1e8), (2025.0, 3.1e8), (2026.0, 1.1e9), (2027.0, 2.6e9), (2028.0, 4.7e9), (2030.0, 9.8e9), (2035.0, 2.1e10)],
                   upkeep: 1.5e6, serving: 0.35, specialists: 3,
                   appetite: ["prometheus": 1, "deepgrove": 0.8, "xenon": 0.7, "sirocco": 0.4, "halcyon": 0.3], suffix: "Voice"),
        ProductDef(id: "operator", name: "Computer-Use Operator", symbol: "macwindow.on.rectangle",
                   pitch: "Agents that work through any app on screen: invoices, claims, data entry, procurement.",
                   earns: "Per completed task, billed to back offices.",
                   needs: [(.agents, 116), (.vision, 115)], research: "gui_grounding", mix: [(.agents, 0.65), (.vision, 0.35)],
                   market: [(2025.0, 8.2e7), (2026.0, 6.3e8), (2027.0, 2.1e9), (2028.0, 4.2e9), (2030.0, 9.8e9), (2035.0, 2.6e10)],
                   upkeep: 2e6, serving: 0.4, specialists: 3,
                   appetite: ["prometheus": 0.9, "halcyon": 0.9, "deepgrove": 0.6, "xenon": 0.4], suffix: "Operator"),
        ProductDef(id: "video", name: "Video Studio", symbol: "film.stack.fill",
                   pitch: "Generated footage, ads and animation for studios, agencies and creators.",
                   earns: "Per generated minute, with studio licences for big customers.",
                   needs: [(.vision, 112)], research: "video_dit", mix: [(.vision, 1)],
                   market: [(2024.9, 1.1e8), (2026.0, 6.3e8), (2027.0, 1.4e9), (2028.0, 2.3e9), (2030.0, 4.7e9), (2035.0, 1.3e10)],
                   upkeep: 2e6, serving: 0.45, specialists: 3,
                   appetite: ["prometheus": 0.8, "deepgrove": 1, "xenon": 0.6, "dragonlake": 0.6], suffix: "Studio"),
        ProductDef(id: "science", name: "Discovery Service", symbol: "testtube.2",
                   pitch: "Drug, protein and materials discovery run for pharma and industry partners.",
                   earns: "Research fees plus milestone payments when a discovery advances.",
                   needs: [(.science, 135), (.reasoning, 128)], research: "lab_automation", mix: [(.science, 0.6), (.math, 0.2), (.reasoning, 0.2)],
                   market: [(2025.7, 1.1e8), (2026.0, 2.1e8), (2027.0, 7.5e8), (2028.0, 1.6e9), (2030.0, 4.7e9), (2035.0, 1.6e10)],
                   upkeep: 3e6, serving: 0.3, specialists: 4,
                   appetite: ["deepgrove": 1, "aletheia": 0.8, "prometheus": 0.5, "halcyon": 0.4], suffix: "Discovery"),
        ProductDef(id: "health", name: "Healthcare Assistant", symbol: "stethoscope.circle.fill",
                   pitch: "Clinical notes, triage and second opinions inside hospitals and clinics.",
                   earns: "Per-clinician licences sold to hospital systems.",
                   needs: [(.science, 100), (.knowledge, 98)], research: "clinical_grounding", mix: [(.science, 0.45), (.knowledge, 0.35), (.social, 0.2)],
                   market: [(2023.5, 5.2e7), (2025.0, 3.1e8), (2026.0, 6.8e8), (2028.0, 2.1e9), (2030.0, 5.2e9), (2035.0, 1.4e10)],
                   upkeep: 2.5e6, serving: 0.3, specialists: 5,
                   appetite: ["deepgrove": 0.8, "halcyon": 0.8, "prometheus": 0.6, "sirocco": 0.3], suffix: "Health"),
        ProductDef(id: "tutor", name: "Personal Tutor", symbol: "graduationcap.circle.fill",
                   pitch: "A patient tutor for every student, from times tables to medical school.",
                   earns: "Family subscriptions and school-district licences.",
                   needs: [(.social, 108), (.knowledge, 104)], research: "pedagogy", mix: [(.social, 0.4), (.knowledge, 0.3), (.math, 0.3)],
                   market: [(2024.4, 5.2e7), (2025.0, 1.6e8), (2026.0, 4.2e8), (2028.0, 1.4e9), (2030.0, 2.9e9), (2035.0, 6.3e9)],
                   upkeep: 1.2e6, serving: 0.35, specialists: 4,
                   appetite: ["prometheus": 0.8, "deepgrove": 0.7, "dragonlake": 0.6, "sirocco": 0.4, "halcyon": 0.3], suffix: "Tutor"),
        ProductDef(id: "robotics", name: "Robotics Brain", symbol: "gearshape.2.fill",
                   pitch: "The model that drives other companies' robots: arms, humanoids and home robots.",
                   earns: "A licence fee per robot running it, paid by robot makers.",
                   needs: [(.robotics, 104), (.vision, 128)], research: "embodied_fm", mix: [(.robotics, 0.8), (.vision, 0.2)],
                   market: [(2025.0, 2.6e7), (2026.0, 1.1e8), (2027.0, 3.1e8), (2028.0, 9.8e8), (2030.0, 3.7e9), (2032.0, 8.2e9), (2035.0, 2.3e10)],
                   upkeep: 2.5e6, serving: 0.2, specialists: 3,
                   appetite: ["deepgrove": 1, "xenon": 0.9, "openweights": 0.5, "prometheus": 0.4], suffix: "Robotics"),
        ProductDef(id: "government", name: "Government & Defence", symbol: "building.columns.circle.fill",
                   pitch: "Models on classified networks for analysts, logistics and cyber defence.",
                   earns: "Multi-year agency contracts.",
                   needs: [(.agents, 106), (.knowledge, 104)], research: "sovereign_deploy", mix: [(.agents, 0.4), (.coding, 0.3), (.knowledge, 0.3)],
                   market: [(2024.5, 1.6e8), (2025.0, 3.7e8), (2026.0, 7.5e8), (2028.0, 2.1e9), (2030.0, 4.2e9), (2035.0, 1.1e10)],
                   upkeep: 3e6, serving: 0.25, specialists: 5,
                   appetite: ["halcyon": 0.8, "prometheus": 0.7, "xenon": 0.6, "sirocco": 0.6, "openweights": 0.4], suffix: "Gov"),
    ]

    static let byID: [String: ProductDef] = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

    static func name(_ id: String) -> String { byID[id]?.name ?? id }

    // MARK: Market

    /// Annual spend on a product line worldwide today (it follows market hype and difficulty like the core market).
    static func marketSize(_ p: ProductDef, _ s: GameState) -> Double {
        guard let first = p.market.first, s.year >= first.0 - 0.25 else { return 0 }
        return interpolateLog(p.market, at: s.year, extrapolate: true) * s.market.hype * s.difficulty.demandMultiplier
    }

    /// Team and compliance cost of a line per month (grows with salaries).
    static func upkeep(_ p: ProductDef, _ y: Double) -> Double {
        p.upkeep * interpolate([(2018, 0.2), (2022, 0.45), (2024, 0.7), (2026, 1.0), (2028, 1.5), (2030, 2.0), (2035, 3.0)], at: y, extrapolate: false)
    }

    /// One-off cost to launch: integration, certification and a sales team.
    static func launchCost(_ p: ProductDef, _ y: Double) -> Double { 4 * upkeep(p, y) }

    /// Quality of a lab's product: its domain mix on the lab's best released scores.
    static func quality(_ p: ProductDef, _ v: DomainScores?) -> Double { v?.mix(p.mix) ?? 0 }

    /// Whether you can launch it, and if not, why.
    static func status(_ p: ProductDef, _ s: GameState) -> (ok: Bool, missing: [String]) {
        var missing: [String] = []
        if !s.researched.contains(p.research) {
            missing.append("Research \(ResearchCatalog.byID[p.research]?.name ?? p.research)")
        }
        let best = s.labDomains["player"]
        for (d, t) in p.needs where (best?[d] ?? 0) < t - HQ.productRelief(p, s) {   // 3.5: local partners
            missing.append("\(d.label) \(Int(t)) (best released: \(best.map { Int($0[d].rounded()) }.map(String.init) ?? "—"))")
        }
        return (missing.isEmpty, missing)
    }

    static func rivalProductName(_ p: ProductDef, lab: String) -> String {
        "\(CompetitorCatalog.def(lab).chatProduct) \(p.suffix)"
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        if GameCalendar.components(s.date).day == 1 { monthly(&s) }
        guard !s.productLines.isEmpty else { return }
        let y = s.year
        var revenue = 0.0, cost = 0.0
        for i in s.productLines.indices {
            guard let p = byID[s.productLines[i].id] else { continue }
            // Customers sign up over months: about half the gap to the target share closes each month.
            s.productLines[i].share += (s.productLines[i].target - s.productLines[i].share) * 0.022
            let r = s.productLines[i].share * marketSize(p, s) / 365
            let c = r * p.serving + upkeep(p, y) / 30.4
            s.productLines[i].revenueMonth += r
            s.productLines[i].costMonth += c
            s.productLines[i].lifetime += r
            revenue += r
            cost += c
        }
        // Booked as "other" revenue and costs, so valuation, taxes and the briefing count it.
        s.month.revOther += revenue
        s.month.costOther += cost
        s.cash += revenue - cost
        s.lifetimeRevenue += revenue
    }

    /// First of the month: quality and target shares for every entrant, rival launches, and unlock news for you.
    static func monthly(_ s: inout GameState) {
        for i in s.productLines.indices {
            s.productLines[i].lastRevenue = s.productLines[i].revenueMonth
            s.productLines[i].lastCost = s.productLines[i].costMonth
            s.productLines[i].revenueMonth = 0
            s.productLines[i].costMonth = 0
        }
        rivalLaunches(&s, announce: true)
        updateShares(&s)
        announceUnlocks(&s)
    }

    /// Distribution: a lab sells new products first to the API, chat and agent customers it already has
    /// (√ of its share of them against a typical frontier lab's, 0.4–1.6).
    static func reach(api: Double, consumer: Double, agents: Double) -> Double {
        clamp((0.5 * api + 0.3 * consumer + 0.2 * agents) / reachReference, 0.16, 2.5).squareRoot()
    }

    static let reachReference = 0.12

    static func playerReach(_ s: GameState) -> Double { reach(api: s.apiShareNow, consumer: s.consumerShare, agents: s.agentShare) }

    /// Your pull beyond quality and brand: reach, times the share of demand your fleet actually serves (product lines run
    /// on the same serving fleet, so an overloaded fleet loses product customers just like API ones).
    static func playerPull(_ s: GameState) -> Double { playerReach(s) * s.reliability }

    /// Target shares: attraction from quality (relative to the best entrant), brand and reach, against the specialists.
    /// Rivals' adoption takes its monthly step unless `stepRivals` is false (a launch mid-month).
    static func updateShares(_ s: inout GameState, stepRivals: Bool = true) {
        let aliveLabs = Set(s.competitors.filter(\.alive).map(\.id))
        s.rivalProducts.removeAll { !aliveLabs.contains($0.lab) }
        let myPull = playerPull(s)
        for p in catalog {
            var entrants: [(key: String, q: Double, brand: Double, reach: Double)] = []
            if s.productLines.contains(where: { $0.id == p.id }) {
                entrants.append(("player", quality(p, s.labDomains["player"]), s.brand, myPull * HQ.productPull(p, s)))
            }
            for r in s.rivalProducts where r.product == p.id {
                guard let c = s.competitors.first(where: { $0.id == r.lab }) else { continue }
                entrants.append((r.lab, quality(p, s.labDomains[r.lab]), c.brand, reach(api: c.apiShare, consumer: c.consumerShare, agents: c.agentShare)))
            }
            guard !entrants.isEmpty else { continue }
            let top = entrants.map(\.q).max() ?? 0
            let attraction = entrants.map { exp(0.15 * ($0.q - top)) * pow(max($0.brand, 3) / 50, 0.6) * $0.reach }
            let total = attraction.reduce(0, +) + p.specialists
            for (k, e) in entrants.enumerated() {
                let target = attraction[k] / total
                if e.key == "player" {
                    if let i = s.productLines.firstIndex(where: { $0.id == p.id }) {
                        s.productLines[i].target = target
                        s.productLines[i].quality = e.q
                    }
                } else if let i = s.rivalProducts.firstIndex(where: { $0.lab == e.key && $0.product == p.id }) {
                    s.rivalProducts[i].target = target
                    s.rivalProducts[i].quality = e.q
                    // Rivals' adoption moves monthly (the same pace as yours day by day).
                    if stepRivals { s.rivalProducts[i].share += (target - s.rivalProducts[i].share) * 0.5 }
                }
            }
        }
    }

    /// How keen a lab is to sell a product: the founding labs by character, founded labs by the plays they favour,
    /// and everyone more so when the play it's running points that way.
    static func appetite(_ p: ProductDef, _ c: CompetitorState) -> Double {
        let consumerProduct = p.id == "voice" || p.id == "tutor" || p.id == "video"
        var base: Double
        if let a = p.appetite[c.id] {
            base = a
        } else if let spec = c.spec {
            let consumer = spec.personality[RivalPlay.consumer.rawValue] ?? 0.3
            let enterprise = spec.personality[RivalPlay.enterprise.rawValue] ?? 0.3
            base = consumerProduct ? 0.4 * consumer : (p.id == "government" && spec.kind == .sovereign ? 0.9 : 0.4 * enterprise)
        } else {
            base = 0.15
        }
        switch RivalPlay(rawValue: c.play) {
        case .consumer where consumerProduct: base *= 1.5
        case .enterprise where !consumerProduct: base *= 1.5
        case .agents where p.id == "operator": base *= 1.5
        case .efficiency: base *= 0.5
        default: break
        }
        return min(1, base)
    }

    /// Rivals whose best model clears a product's bars (and whose field has the research) launch it after a lag that
    /// depends on how keen they are (hashed per lab and month, so it never touches the game's random numbers).
    static func rivalLaunches(_ s: inout GameState, announce: Bool) {
        let y = s.year
        let ym = s.date.ym
        for p in catalog {
            guard let research = ResearchCatalog.byID[p.research], y >= research.year + 0.1 else { continue }
            for c in s.competitors where c.alive && !c.models.isEmpty {
                guard !s.rivalProducts.contains(where: { $0.lab == c.id && $0.product == p.id }),
                      let v = s.labDomains[c.id], p.needs.allSatisfy({ v[$0.0] >= $0.1 }) else { continue }
                let keen = appetite(p, c)
                guard keen > 0, RivalIntel.unit("products|\(s.lifecycleSalt)|\(c.id)|\(p.id)|\(ym.year)-\(ym.month)") < 0.3 * keen else { continue }
                s.rivalProducts.append(RivalProduct(lab: c.id, product: p.id, launched: s.date, quality: quality(p, v)))
                if announce {
                    let first = !s.rivalProducts.contains { $0.product == p.id && $0.lab != c.id } && !s.productLines.contains { $0.id == p.id }
                    Sim.news(&s, "\(c.def.name) launches \(rivalProductName(p, lab: c.id))",
                             "\(p.pitch) \(first ? "It's the first lab product of its kind." : "It joins \(competitors(s, p, except: c.id)) in the market.")",
                             .competitor, image: nil, important: first, good: nil)
                }
            }
        }
    }

    private static func competitors(_ s: GameState, _ p: ProductDef, except lab: String) -> String {
        var names = s.rivalProducts.filter { $0.product == p.id && $0.lab != lab }.compactMap { r in
            s.competitors.first { $0.id == r.lab }?.def.name
        }
        if s.productLines.contains(where: { $0.id == p.id }) { names.insert(s.companyName, at: 0) }
        return names.isEmpty ? "specialist startups" : names.prefix(3).joined(separator: ", ")
    }

    /// Tell you once when a product line opens up.
    static func announceUnlocks(_ s: inout GameState) {
        for p in catalog where !s.productsAnnounced.contains(p.id) && !s.productLines.contains(where: { $0.id == p.id }) {
            guard status(p, s).ok else { continue }
            s.productsAnnounced.insert(p.id)
            Sim.news(&s, "New product line available: \(p.name)",
                     "Your models are now good enough to sell it. \(p.pitch) Market today: \(Fmt.money(marketSize(p, s)))/year. Launch it on the Product Lines page.",
                     .market, image: nil, important: true, good: true)
            Alerts.raise(&s, .milestone, key: "product|\(p.id)", title: "You can launch \(p.name)",
                         body: "\(p.pitch) Launch costs \(Fmt.money(launchCost(p, s.year))).", screen: .products, cooldown: 0)
        }
    }

    /// New games and older saves: rivals that already sell a product line have it from the start.
    static func bootstrap(_ s: inout GameState) {
        let y = s.year
        for p in catalog {
            guard let research = ResearchCatalog.byID[p.research], y >= research.year + 0.1 else { continue }
            for c in s.competitors where c.alive && !c.models.isEmpty {
                guard !s.rivalProducts.contains(where: { $0.lab == c.id && $0.product == p.id }),
                      let v = s.labDomains[c.id], p.needs.allSatisfy({ v[$0.0] >= $0.1 }) else { continue }
                let keen = appetite(p, c)
                guard keen > 0, RivalIntel.unit("products|start|\(c.id)|\(p.id)") < 0.8 * keen else { continue }
                s.rivalProducts.append(RivalProduct(lab: c.id, product: p.id, launched: s.date, quality: quality(p, v)))
            }
        }
        updateShares(&s)
        for i in s.rivalProducts.indices { s.rivalProducts[i].share = s.rivalProducts[i].target }
        // What you could already launch isn't news on day one.
        for p in catalog where status(p, s).ok { s.productsAnnounced.insert(p.id) }
    }

    // MARK: For views

    /// A rival lab's product lines with an estimate of what each earns a month.
    static func rivalLines(_ s: GameState, lab: String) -> [(def: ProductDef, product: RivalProduct, monthly: Double)] {
        s.rivalProducts.filter { $0.lab == lab }.compactMap { r in
            guard let p = byID[r.product] else { return nil }
            return (p, r, r.share * marketSize(p, s) / 12)
        }
    }

    /// What your product lines earned and cost last month.
    static func lastMonth(_ s: GameState) -> (revenue: Double, cost: Double) {
        s.productLines.reduce((0, 0)) { ($0.0 + $1.lastRevenue, $0.1 + $1.lastCost) }
    }

    /// Products a set of scores would clear the bars for (research aside).
    static func clears(_ v: DomainScores) -> [ProductDef] {
        catalog.filter { p in p.needs.allSatisfy { v[$0.0] >= $0.1 } }
    }
}

// MARK: - Actions

extension GameState {
    /// Launch a product line. Returns an error message, or nil on success.
    mutating func launchProduct(_ id: String) -> String? {
        guard let p = ProductLines.byID[id] else { return "Unknown product." }
        guard !productLines.contains(where: { $0.id == id }) else { return "\(p.name) is already on sale." }
        let st = ProductLines.status(p, self)
        guard st.ok else { return "Not yet: \(st.missing.joined(separator: "; "))." }
        let cost = ProductLines.launchCost(p, year)
        guard cash >= cost else { return "Launching \(p.name) costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        cash -= cost
        month.costOther += cost
        productsAnnounced.insert(id)
        productLines.append(ProductLine(id: id, launched: date))
        ProductLines.updateShares(&self, stepRivals: false)
        Sim.news(&self, "\(companyName) launches \(p.name)",
                 "\(p.pitch) \(p.earns) Customers sign up over the coming months.", .company, image: nil, important: true, good: true)
        return nil
    }

    /// Close a product line (its customers move to rivals and specialists).
    mutating func closeProduct(_ id: String) {
        guard let i = productLines.firstIndex(where: { $0.id == id }) else { return }
        productLines.remove(at: i)
        Sim.news(&self, "\(companyName) closes \(ProductLines.name(id))", "Customers move to rivals and specialists.", .company, image: nil, good: false)
    }
}
