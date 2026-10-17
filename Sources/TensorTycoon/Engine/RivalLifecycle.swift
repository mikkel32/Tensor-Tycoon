import Foundation

/// Something that happened to a rival lab, for the Rivals hub's history.
struct RivalEvent: Codable, Hashable, Identifiable {
    enum Kind: String, CaseIterable, Sendable {
        case founded, spinout, sovereign, acquired, merged, bankrupt, rescued, ipo, shutdown, raid, bought, blocked

        var label: String {
            switch self {
            case .founded: "Founded"
            case .spinout: "Spin-out"
            case .sovereign: "National lab"
            case .acquired: "Acquired"
            case .merged: "Merged"
            case .bankrupt: "Bankrupt"
            case .rescued: "Rescued"
            case .ipo: "IPO"
            case .shutdown: "Wound down"
            case .raid: "Talent raid"
            case .bought: "Bought by you"
            case .blocked: "Bid blocked"
            }
        }

        var symbol: String {
            switch self {
            case .founded: "sparkle"
            case .spinout: "arrow.triangle.branch"
            case .sovereign: "building.columns.fill"
            case .acquired: "building.2.crop.circle.fill"
            case .merged: "arrow.triangle.merge"
            case .bankrupt: "xmark.octagon.fill"
            case .rescued: "lifepreserver.fill"
            case .ipo: "chart.line.uptrend.xyaxis"
            case .shutdown: "power"
            case .raid: "person.2.badge.key.fill"
            case .bought: "signature"
            case .blocked: "hand.raised.fill"
            }
        }

        /// A new lab joined the field.
        var isFounding: Bool { self == .founded || self == .spinout || self == .sovereign }
        /// A lab left the field.
        var isExit: Bool { self == .acquired || self == .merged || self == .bankrupt || self == .shutdown || self == .bought }
    }

    var id = UUID()
    var date: Date
    /// Kind raw value.
    var kind: String
    /// The lab it happened to.
    var labID: String
    /// The other side: the buyer, the parent lab, the merger partner, "player", or empty.
    var otherID: String = ""
    var title: String
    var body: String
    var amount: Double = 0

    var eventKind: Kind? { Kind(rawValue: kind) }
}

/// A rival takeover waiting on your right of first refusal.
struct RivalDeal: Codable, Hashable, Identifiable {
    var id = UUID()
    var targetID: String
    var buyerID: String
    var price: Double
    var date: Date
    /// The inbox offer that lets you buy first (nil when you couldn't bid).
    var decisionID: UUID? = nil
}

/// The field changes after October 2026. Researchers leave big labs to found spin-outs — more often after layoffs,
/// a down round, a lost race or a takeover — governments fund national labs and investors back startups with a new idea.
/// Labs with deep pockets buy weaker ones (you get the first chance), strugglers merge and startups that never find
/// customers wind down. Every move is news and lands in the Rivals hub's history.
/// Rolls use hashed randomness keyed on the game, so none of this draws from the game's RNG.
enum RivalLifecycle {
    /// Most labs in business at once, so the field stays readable.
    static let maxLabs = 12

    // MARK: Hashed rolls

    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("\(s.lifecycleSalt)|\(key)") }

    static func monthIndex(_ s: GameState) -> Int { s.date.ym.year * 12 + s.date.ym.month }

    static func pick<T>(_ s: GameState, _ key: String, _ items: [T]) -> T {
        items[min(items.count - 1, Int(roll(s, key) * Double(items.count)))]
    }

    // MARK: Reading a lab

    /// How far the lab's best model trails the world frontier in capability (log-compute units; 0.05 is about a month
    /// of progress around 2029). Boards, customers and investors judge on this: as progress slows in the 2030s the
    /// same gap is more months, but no worse a product.
    static func gap(_ c: CompetitorState, _ s: GameState) -> Double {
        guard let best = c.models.map(\.c).max() else { return 10 }
        return max(0, Macro.frontier(s.year) - best)
    }

    /// Years since a lab founded during the game opened (nil for the founding eight).
    static func age(_ c: CompetitorState, _ s: GameState) -> Double? { c.spec.map { s.year - $0.founded.decimal } }

    static func labsInBusiness(_ s: GameState) -> [CompetitorState] {
        s.competitors.filter { $0.alive && s.year >= $0.def.founded.decimal }
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState, _ snap: MarketSnapshot) {
        guard s.year >= RivalHistory.end else { return }
        if s.lifecycleSalt.isEmpty { s.lifecycleSalt = String(s.rng.state, radix: 36) }
        moods(&s)
        settleDeals(&s)
        if !consolidate(&s) { found(&s) }
    }

    /// Turmoil fades; a lab far behind the leader keeps losing people.
    static func moods(_ s: inout GameState) {
        let rivalsBest = s.competitors.filter(\.alive).compactMap { $0.models.map(\.c).max() }.max() ?? -10
        let leader = max(rivalsBest, s.releasedModels.map(\.c).max() ?? -10)
        for i in s.competitors.indices {
            s.competitors[i].turmoil *= 0.85
            guard s.competitors[i].alive, let best = s.competitors[i].models.map(\.c).max() else { continue }
            if leader - best > 0.5 { s.competitors[i].turmoil += 0.06 }
        }
    }

    // MARK: Foundings

    static func found(_ s: inout GameState) {
        let y = s.year
        guard labsInBusiness(s).count < maxLabs else { return }
        // One new lab at a time: at least three months apart.
        if let last = s.rivalEvents.first(where: { $0.eventKind?.isFounding ?? false }), GameCalendar.daysBetween(last.date, s.date) < 90 { return }
        let m = monthIndex(s)
        if alumni(&s) { return }
        let parents = spinoutParents(s)
        let total = parents.reduce(0) { $0 + $1.weight }
        if total > 0, roll(s, "spinout|\(m)") < total {
            var left = roll(s, "spinout-who|\(m)") * total
            for p in parents {
                left -= p.weight
                if left <= 0 { spinout(&s, from: p.id); return }
            }
        }
        let national = s.customLabs.filter { $0.kind == .sovereign }.count
        let nationalOdds: Double
        switch national {
        case 0: nationalOdds = y >= 2027 ? 0.04 : 0
        case 1: nationalOdds = y >= 2029 ? 0.012 : 0
        case 2: nationalOdds = y >= 2031 ? 0.008 : 0
        default: nationalOdds = 0
        }
        if roll(s, "national|\(m)") < nationalOdds {
            nationalLab(&s)
            return
        }
        let mood = RivalEconomy.inCorrection(s) ? 0.2 : clamp(s.market.hype / 1.3, 0.3, 1.6)
        if y >= 2027, roll(s, "startup|\(m)") < 0.014 * mood { startup(&s) }
    }

    /// Labs whose people might leave to found something, with monthly odds: big rich labs lose a few founders a year,
    /// labs in turmoil many more, and a lab that was just bought or went under leaves a whole team looking.
    static func spinoutParents(_ s: GameState) -> [(id: String, weight: Double)] {
        let y = s.year
        let scale = Macro.frontierValuation(y)
        var out: [(id: String, weight: Double)] = []
        for c in s.competitors where y >= c.def.founded.decimal {
            if c.alive {
                guard !c.models.isEmpty, c.headcount >= 200, (age(c, s) ?? 9) >= 3 else { continue }
                out.append((c.id, 0.0025 + 0.003 * min(1, c.valuation / scale) + 0.035 * c.turmoil))
            } else if let gone = c.exitDate, GameCalendar.daysBetween(gone, s.date) < 365, c.headcount >= 40, !c.models.isEmpty {
                out.append((c.id, 0.03 * c.turmoil))
            }
        }
        return out
    }

    /// The headline StrategyEvents writes when a star leaves to found a startup (shared, so the two can't drift apart).
    static let alumniSuffix = " leaves to found a startup"

    /// Your star who left to found a startup ("Wish them well") may really do it.
    static func alumni(_ s: inout GameState) -> Bool {
        let cutoff = GameCalendar.addDays(s.date, -45)
        let suffix = alumniSuffix
        for n in s.news.prefix(150) where n.date >= cutoff && n.category == .company && n.title.hasSuffix(suffix) {
            let origin = n.id.uuidString
            guard !s.customLabs.contains(where: { $0.origin == origin }), roll(s, "alumni|\(origin)") < 0.6 else { continue }
            alumniLab(&s, founder: String(n.title.dropLast(suffix.count)), origin: origin)
            return true
        }
        return false
    }

    // MARK: Founding a lab

    struct Thesis {
        let id: String
        /// What the lab is building, as a phrase ("agent-native models that run whole jobs").
        let line: String
        let signature: String
        var reasoning = 0.0, agent = 0.0, chat = 0.0, lang = 0.0, longctx = 0.0, vis = 0.0, safety = 0.0
        var code = 0.0
        var efficiency = 0.0
        var open = false
        /// How close to the frontier the idea can take it once established.
        var reach = 0.0
        var plays: [RivalPlay: Double] = [:]
    }

    static let theses: [Thesis] = [
        Thesis(id: "agents", line: "agent-native models that run whole jobs", signature: "Long-horizon agent RL on real software",
               agent: 0.14, code: 0.08, plays: [.agents: 0.9, .enterprise: 0.6]),
        Thesis(id: "reasoning", line: "reasoning models trained with search", signature: "Search-and-verify reasoning at scale",
               reasoning: 0.08, reach: 0.05, plays: [.race: 0.9, .talentRaid: 0.6]),
        Thesis(id: "efficient", line: "small models that punch far above their weight", signature: "Distillation and sparse experts at a tenth of the cost",
               efficiency: 0.3, reach: -0.1, plays: [.efficiency: 0.9, .priceWar: 0.8]),
        Thesis(id: "open", line: "frontier-grade open weights", signature: "Open weights and open training recipes",
               open: true, reach: -0.1, plays: [.openGambit: 1.0, .talentRaid: 0.5]),
        Thesis(id: "memory", line: "assistants with lifelong memory", signature: "Persistent memory and million-token context",
               chat: 0.08, longctx: 0.2, plays: [.consumer: 0.9, .agents: 0.5]),
        Thesis(id: "world", line: "multimodal world models", signature: "Video-native world models",
               lang: 0.05, vis: 0.2, plays: [.consumer: 0.6, .race: 0.6]),
        Thesis(id: "safety", line: "interpretable, verifiably safer AI", signature: "Interpretability-first training",
               reasoning: 0.04, safety: 12, plays: [.lobby: 0.7, .enterprise: 0.7]),
        Thesis(id: "science", line: "AI that runs its own experiments", signature: "Models trained in the lab, not just on the web",
               reasoning: 0.06, code: 0.04, plays: [.enterprise: 0.6, .race: 0.5]),
    ]

    static let roots = ["Northstar", "Parallax", "Corvid", "Basalt", "Quorum", "Ostara", "Axiom", "Reverie", "Lodestar", "Solstice",
                        "Verity", "Oriel", "Calyx", "Glyph", "Isotope", "Nautilus", "Pallas", "Strand", "Wyvern", "Arbor", "Ferrous",
                        "Tangent", "Orrery", "Sigil", "Kairos", "Aether", "Noether", "Halyard", "Cascade", "Fulcrum", "Ridgeline",
                        "Saltire", "Tern", "Pinion", "Marrow", "Thalassa"]

    static let palette: [UInt32] = [0xE91E63, 0x00ACC1, 0xFFB300, 0x7CB342, 0x5E35B1, 0x26A69A, 0xC2185B, 0x8D6E63, 0x3949AB,
                                    0xF9A825, 0x00897B, 0xAD1457, 0x6D4C41, 0x43A047, 0x039BE5, 0x9E9D24]

    static let symbols = ["sparkle", "atom", "circle.hexagongrid.fill", "hexagon.fill", "rhombus.fill", "triangle.fill", "seal.fill",
                          "moon.stars.fill", "bolt.fill", "wand.and.stars", "scope", "waveform", "diamond.fill", "staroflife.fill",
                          "tornado", "drop.fill", "cube.fill", "sparkles", "aqi.medium", "point.3.connected.trianglepath.dotted"]

    static let cities = ["San Francisco", "New York", "London", "Paris", "Zurich", "Toronto", "Tel Aviv", "Seattle", "Boston", "Berlin",
                         "Tokyo", "Singapore", "Austin", "Montréal"]

    static let nations: [(name: String, hq: String, backer: String, symbol: String, site: String)] = [
        ("Oasis National AI", "Abu Dhabi", "a Gulf sovereign wealth fund", "sun.horizon.fill", "a desert campus outside Abu Dhabi"),
        ("Lyra AI Institute", "Paris & Berlin", "a European public–private consortium", "globe.europe.africa.fill", "Europe's public supercomputers"),
        ("Deccan AI Mission", "Bengaluru", "India's national AI mission", "globe.asia.australia.fill", "a national GPU cloud in Hyderabad"),
        ("Kasumi AI", "Tokyo", "a Japanese industrial consortium", "cloud.fog.fill", "a cluster in Hokkaido"),
        ("Hanbit National AI", "Seoul", "a Korean conglomerate consortium", "sparkles", "a national AI data centre in Gwangju"),
        ("Najd Compute", "Riyadh", "a Gulf state's investment fund", "building.columns.fill", "a gigawatt campus near Riyadh"),
        ("Laurentian AI", "Montréal", "a Canadian public compute programme", "snowflake", "hydro-powered clusters in Québec"),
        ("Straits AI Institute", "Singapore", "a Southeast Asian sovereign fund", "network", "rented capacity in Johor"),
    ]

    static let teams = ["post-training", "reasoning RL", "pre-training", "the agents team", "inference", "multimodal research",
                        "safety research", "the data team"]

    /// A spec with the parts every new lab shares; the caller fills in the ramp and the story.
    static func baseSpec(_ s: GameState, kind: CustomLabSpec.Kind, key: String, thesis: Thesis) -> CustomLabSpec {
        let used = Set(s.competitors.map(\.def.name))
        let usedColors = Set(labsInBusiness(s).map(\.def.color))
        let usedSymbols = Set(labsInBusiness(s).map(\.def.symbol))
        let start = Int(roll(s, key + "root") * Double(roots.count))
        var root = roots[start % roots.count]
        let suffix = kind == .startup ? pick(s, key + "suffix", ["Intelligence", "AI", "Systems", "Labs"]) : pick(s, key + "suffix", ["Labs", "AI", "Research"])
        for k in 0..<roots.count {
            let r = roots[(start + k) % roots.count]
            if !used.contains(where: { $0.hasPrefix(r) }) { root = r; break }
        }
        let c0 = Int(roll(s, key + "color") * Double(palette.count))
        let color = (0..<palette.count).map { palette[(c0 + $0) % palette.count] }.first { !usedColors.contains($0) } ?? palette[c0 % palette.count]
        let s0 = Int(roll(s, key + "symbol") * Double(symbols.count))
        let symbol = (0..<symbols.count).map { symbols[($0 + s0) % symbols.count] }.first { !usedSymbols.contains($0) } ?? symbols[s0 % symbols.count]
        let first = NameBank.first[Int(roll(s, key + "ceo1") * Double(NameBank.first.count)) % NameBank.first.count]
        let last = NameBank.last[Int(roll(s, key + "ceo2") * Double(NameBank.last.count)) % NameBank.last.count]
        let hash = String(UInt64(roll(s, key + "id") * 1_679_616), radix: 36)
        let now = s.date.ym
        let firstModel = now.adding(months: kind == .sovereign ? 11 + Int(roll(s, key + "first") * 4) : 7 + Int(roll(s, key + "first") * 4))
        var spec = CustomLabSpec(
            id: "lab-\(root.lowercased())-\(hash)", kind: kind, name: "\(root) \(suffix)", color: color, symbol: symbol,
            archetype: thesis.line.prefix(1).uppercased() + thesis.line.dropFirst(), hq: pick(s, key + "hq", cities), ceo: "\(first) \(last)",
            founded: now, firstModel: firstModel, rampYears: [], rampOffsets: [],
            cadenceMonths: 5 + roll(s, key + "cadence") * 3, priceMult: thesis.open ? 0.2 : (thesis.efficiency > 0.2 ? 0.4 : 0.9 + roll(s, key + "price") * 0.3),
            tps: thesis.efficiency > 0.2 ? 150 : 70 + roll(s, key + "tps") * 40, brand: 18 + roll(s, key + "brand") * 10,
            openWeights: thesis.open, codeBonus: 0.02 + thesis.code, computeShare: 0.02 + roll(s, key + "share") * 0.02,
            prefix: "\(root)-", nextVersion: 1, chatProduct: root)
        spec.thesis = thesis.line
        spec.signature = thesis.signature
        spec.reasoning = thesis.reasoning
        spec.agent = thesis.agent
        spec.chat = thesis.chat
        spec.lang = thesis.lang
        spec.longctx = thesis.longctx
        spec.vis = thesis.vis
        spec.safety = thesis.safety
        spec.efficiency = thesis.efficiency
        spec.culture = 0.6
        spec.site = "rented capacity near \(spec.hq)"
        var plays: [String: Double] = [:]
        let base: [RivalPlay: Double] = kind == .startup
            ? [.race: 0.4, .agents: 0.5, .enterprise: 0.5, .talentRaid: 0.3, .efficiency: 0.5, .alliance: 0.7, .consumer: 0.4, .priceWar: 0.3, .openGambit: 0.3, .lobby: 0.1]
            : [.race: 0.6, .agents: 0.5, .enterprise: 0.4, .talentRaid: 0.5, .efficiency: 0.3, .alliance: 0.6, .consumer: 0.3, .priceWar: 0.2, .openGambit: 0.2, .lobby: 0.2]
        for (play, v) in base { plays[play.rawValue] = max(v, thesis.plays[play] ?? 0) }
        spec.personality = plays
        return spec
    }

    static func pickThesis(_ s: GameState, _ key: String, avoidOpen: Bool = false) -> Thesis {
        let pool = avoidOpen ? theses.filter { !$0.open } : theses
        return pick(s, key + "thesis", pool)
    }

    /// Ramp anchors: well behind at founding, `first` at its first model, `mature` two and a half years in.
    static func ramp(_ spec: inout CustomLabSpec, first: Double, mature: Double) {
        let f = spec.founded.decimal
        let fm = max(f + 0.3, spec.firstModel.decimal)
        spec.rampYears = [f, fm, f + 2.5, f + 6]
        spec.rampOffsets = [first - 0.3, first, mature, mature + 0.02]
    }

    /// Investors' appetite right now (0.6–1.5).
    static func appetite(_ s: GameState) -> Double { RivalEconomy.inCorrection(s) ? 0.6 : clamp(s.market.hype / 1.3, 0.6, 1.5) }

    static func spinout(_ s: inout GameState, from parentID: String) {
        guard let pi = s.competitors.firstIndex(where: { $0.id == parentID }) else { return }
        let parent = s.competitors[pi]
        let y = s.year
        let key = "lab\(s.customLabs.count)"
        let thesis = pickThesis(s, key)
        let pgap = clamp((parent.models.map(\.c).max() ?? Macro.frontier(y) - 0.6) - Macro.frontier(y), -0.8, 0.1)
        var spec = baseSpec(s, kind: .spinout, key: key, thesis: thesis)
        spec.parentID = parent.id
        spec.parentName = parent.def.name
        spec.archetype = "Spin-out of \(parent.def.name): \(thesis.line)"
        if walledOff(parent) {
            // Export controls follow the company, not its people: they set up where the chips and customers are.
            spec.hq = "Singapore"
        } else if roll(s, key + "home") < 0.6 {
            spec.hq = String(parent.def.hq.split(separator: "&").first ?? "").trimmingCharacters(in: .whitespaces)
        }
        spec.site = "rented capacity near \(spec.hq)"
        spec.openWeights = spec.openWeights || (parent.def.openWeights && roll(s, key + "open") < 0.5)
        spec.computeShare = (0.03 + roll(s, key + "share") * 0.02) * (thesis.efficiency > 0.2 ? 0.6 : 1)
        // The founders bring their old lab's habits.
        let theirs = RivalStrategy.personality(parent.id)
        for (play, v) in theirs { spec.personality[play.rawValue] = ((spec.personality[play.rawValue] ?? 0) + v) / 2 }
        // The team's talent; how close it really gets depends on the compute it can pay for (RivalIntel.sizeRun).
        ramp(&spec, first: clamp(pgap - 0.3 + (roll(s, key + "o1") - 0.5) * 0.2, -0.9, -0.15) + thesis.reach * 0.5,
             mature: clamp(pgap - 0.08 + (roll(s, key + "o2") - 0.5) * 0.15 + thesis.reach, -0.5, 0.05))
        let post = Macro.frontierValuation(y) * (0.006 + 0.008 * roll(s, key + "post")) * appetite(s)
        let raised = post * (0.2 + 0.1 * roll(s, key + "raise"))
        let lead = pick(s, key + "lead", NameBank.investors)
        let team = pick(s, key + "team", teams)
        let techs = (s.rivalTech[parent.id] ?? []).filter { ResearchCatalog.byID[$0] != nil }
        let carried = techs.isEmpty ? [] : [pick(s, key + "tech", techs)]
        // The people who leave are missed.
        s.competitors[pi].headcount = max(10, Int(Double(parent.headcount) * 0.98))
        s.competitors[pi].brand = max(0, parent.brand - 1)
        s.competitors[pi].turmoil *= 0.5
        if var p = s.competitors[pi].project, p.procedural {
            p.cAdjust -= 0.01
            s.competitors[pi].project = p
        }
        let why = parent.alive ? (parent.turmoil > 0.4 ? " \(parent.def.name) has been losing people since \(turmoilReason(parent, s))." : "")
            : " \(parent.def.name)'s team scattered after it \(parent.bankrupt ? "went under" : "was sold")."
        let body = "\(spec.ceo), who led \(team) at \(parent.def.name), is building \(thesis.line) with a group of former colleagues.\(why) "
            + "\(lead) led a \(Fmt.money(raised)) seed round at \(Fmt.money(post)). First model expected around \(spec.firstModel.label)."
        launch(&s, spec, cash: raised, post: post, lead: lead, round: "Seed round", staff: 25 + Int(roll(s, key + "staff") * 40), techs: carried,
               event: .spinout, title: "Former \(parent.def.name) researchers found \(spec.name)", body: body)
    }

    static func turmoilReason(_ c: CompetitorState, _ s: GameState) -> String {
        if c.distressMonths > 0 { return "its money troubles began" }
        if RivalStrategy.play(c) == .efficiency { return "its cost cuts" }
        if c.rounds.last?.label == "Down round" { return "its down round" }
        return "it fell behind the leaders"
    }

    static func alumniLab(_ s: inout GameState, founder: String, origin: String) {
        let y = s.year
        let key = "lab\(s.customLabs.count)"
        let thesis = pickThesis(s, key)
        let mine = s.releasedModels.map(\.c).max() ?? Macro.frontier(y) - 0.6
        let gap = clamp(mine - Macro.frontier(y), -0.8, 0.1)
        var spec = baseSpec(s, kind: .spinout, key: key, thesis: thesis)
        spec.parentID = "player"
        spec.parentName = s.companyName
        spec.ceo = founder
        spec.origin = origin
        spec.archetype = "Spin-out of \(s.companyName): \(thesis.line)"
        spec.computeShare = (0.025 + roll(s, key + "share") * 0.02) * (thesis.efficiency > 0.2 ? 0.6 : 1)
        ramp(&spec, first: clamp(gap - 0.35 + thesis.reach * 0.5, -0.9, -0.2), mature: clamp(gap - 0.12 + thesis.reach, -0.5, 0.03))
        let post = Macro.frontierValuation(y) * (0.004 + 0.006 * roll(s, key + "post")) * appetite(s)
        let raised = post * 0.25
        let lead = pick(s, key + "lead", NameBank.investors)
        // They know how your secret work is done.
        let yours = s.exoticOwned.filter { s.researched.contains($0) }
        let carried = yours.isEmpty ? [] : [pick(s, key + "tech", yours)]
        let known = carried.first.flatMap { ResearchCatalog.byID[$0]?.name }
        let body = "\(founder), who left \(s.companyName), raised \(Fmt.money(raised)) at \(Fmt.money(post)) from \(lead) to build \(thesis.line). "
            + (known.map { "They know how your \($0) works. " } ?? "") + "First model expected around \(spec.firstModel.label)."
        launch(&s, spec, cash: raised, post: post, lead: lead, round: "Seed round", staff: 20 + Int(roll(s, key + "staff") * 25), techs: carried,
               event: .spinout, title: "\(founder) founds \(spec.name)", body: body)
    }

    static func startup(_ s: inout GameState) {
        let y = s.year
        let key = "lab\(s.customLabs.count)"
        let thesis = pickThesis(s, key)
        var spec = baseSpec(s, kind: .startup, key: key, thesis: thesis)
        spec.computeShare = (0.015 + roll(s, key + "share") * 0.015) * (thesis.efficiency > 0.2 ? 0.6 : 1)
        ramp(&spec, first: -0.65 + (roll(s, key + "o1") - 0.5) * 0.2, mature: -0.3 + thesis.reach + (roll(s, key + "o2") - 0.5) * 0.15)
        let post = Macro.frontierValuation(y) * (0.003 + 0.004 * roll(s, key + "post")) * appetite(s)
        let raised = post * (0.2 + 0.1 * roll(s, key + "raise"))
        let lead = pick(s, key + "lead", NameBank.investors)
        let unowned = ResearchCatalog.exotic.map(\.id).filter { id in !s.exoticOwned.contains(id) && !s.rivalTech.values.contains { $0.contains(id) } }
        let carried = unowned.isEmpty || roll(s, key + "hasTech") < 0.5 ? [] : [pick(s, key + "tech", unowned)]
        let body = "Founded by \(spec.ceo) to build \(thesis.line). \(lead) led a \(Fmt.money(raised)) round at \(Fmt.money(post)). "
            + "First model expected around \(spec.firstModel.label)."
        launch(&s, spec, cash: raised, post: post, lead: lead, round: "Seed round", staff: 15 + Int(roll(s, key + "staff") * 25), techs: carried,
               event: .founded, title: "\(spec.name) launches with \(Fmt.money(raised))", body: body)
    }

    static func nationalLab(_ s: inout GameState) {
        let y = s.year
        let usedNames = Set(s.customLabs.map(\.name))
        let options = nations.filter { !usedNames.contains($0.name) }
        guard !options.isEmpty else { return }
        let key = "lab\(s.customLabs.count)"
        let n = pick(s, key + "nation", options)
        var thesis = pickThesis(s, key, avoidOpen: false)
        if thesis.id == "efficient" { thesis = theses[0] }
        var spec = baseSpec(s, kind: .sovereign, key: key, thesis: thesis)
        spec.name = n.name
        spec.hq = n.hq
        spec.symbol = n.symbol
        spec.backer = n.backer
        spec.site = n.site
        spec.prefix = "\(n.name.split(separator: " ").first ?? "Nation")-"
        spec.chatProduct = String(n.name.split(separator: " ").first ?? "Nation")
        spec.archetype = "National lab backed by \(n.backer)"
        spec.thesis = "sovereign models in local languages for government and industry"
        spec.signature = "Sovereign data and local languages"
        spec.lang = max(spec.lang, 0.2)
        spec.safety = max(spec.safety, 5)
        spec.openWeights = roll(s, key + "open") < 0.5
        spec.priceMult = spec.openWeights ? 0.25 : 0.6
        spec.cadenceMonths = 8 + roll(s, key + "cadence") * 2
        spec.computeShare = 0.02 + roll(s, key + "share") * 0.015
        spec.culture = 1.2
        spec.brand = 25
        spec.efficiency = 0
        spec.stateBudget = Macro.frontierValuation(y) * (0.0004 + 0.0004 * roll(s, key + "budget"))
        spec.personality = ["lobby": 0.6, "enterprise": 0.8, "openGambit": spec.openWeights ? 0.8 : 0.4, "efficiency": 0.5, "race": 0.4,
                            "consumer": 0.4, "alliance": 0.1, "priceWar": 0.3, "agents": 0.4, "talentRaid": 0.5]
        spec.bills = ["nairr", "transparency"]
        ramp(&spec, first: -0.7 + (roll(s, key + "o1") - 0.5) * 0.15, mature: -0.35 + (roll(s, key + "o2") - 0.5) * 0.15)
        let body = "\(n.backer.prefix(1).uppercased() + n.backer.dropFirst()) is putting \(Fmt.money(spec.stateBudget * 12)) a year into a national lab in \(n.hq): "
            + "\(spec.thesis), led by \(spec.ceo). It trains on \(n.site). First model expected around \(spec.firstModel.label)."
        launch(&s, spec, cash: 0, post: Macro.frontierValuation(y) * 0.01, lead: n.backer, round: "State funding",
               staff: 120 + Int(roll(s, key + "staff") * 130), techs: [], event: .sovereign, title: "\(n.name) launches in \(n.hq)", body: body)
    }

    /// Put a new lab on the board: register it, open its books, plan its first run and tell the world.
    static func launch(_ s: inout GameState, _ spec: CustomLabSpec, cash: Double, post: Double, lead: String, round: String, staff: Int,
                       techs: [String], event: RivalEvent.Kind, title: String, body: String) {
        CompetitorCatalog.register([spec])
        s.customLabs.append(spec)
        let y = s.year
        var st = CompetitorState(id: spec.id, nextRelease: GameCalendar.addDays(spec.firstModel.date, 14), brand: spec.brand)
        st.econReady = true
        st.cash = cash
        st.totalRaised = cash
        st.valuation = post
        st.headcount = staff
        let unit = RivalEconomy.costPerH100eMonth(y)
        if spec.kind == .sovereign {
            st.rounds = [RivalRound(date: s.date, label: round, amount: spec.stateBudget * 12, postMoney: 0, lead: lead, kind: .strategic)]
            st.computePlan = spec.stateBudget / unit * 0.5
        } else {
            st.rounds = [RivalRound(date: s.date, label: round, amount: cash, postMoney: post, lead: lead, kind: .equity)]
            st.computePlan = cash / 20 / unit * 0.6
        }
        st.computeH100e = st.computePlan
        s.competitors.append(st)
        if let i = s.competitors.indices.last {
            s.competitors[i].fundingFactor = RivalEconomy.fundingFactor(st.computePlan, s.competitors[i], s)
        }
        if !techs.isEmpty { s.rivalTech[spec.id] = techs }
        Sim.news(&s, title, body, .competitor, image: spec.kind == .sovereign ? "hyperscale_campus" : "sf_skyline", important: true)
        record(&s, event, lab: spec.id, other: spec.parentID, title: title, body: body, amount: spec.kind == .sovereign ? spec.stateBudget * 12 : cash)
        if spec.kind != .sovereign, let i = s.competitors.indices.last { RivalEconomy.offerStake(&s, i, amount: cash, post: post) }
    }

    // MARK: Consolidation

    /// Takeovers, mergers and wind-downs. At most one a month; returns whether something happened.
    @discardableResult
    static func consolidate(_ s: inout GameState) -> Bool {
        let m = monthIndex(s)
        let weakOnes = s.competitors.indices.filter { weak(s, $0) }
        // A crowded field consolidates faster: customers, investors and researchers spread too thin, and the giants
        // start buying healthy smaller labs too.
        let count = labsInBusiness(s).count
        let crowd = 1 + Double(max(0, count - 9)) * 0.4
        let targets = count >= maxLabs - 1 ? s.competitors.indices.filter { weak(s, $0) || small(s, $0) } : weakOnes
        // A lab with deep pockets buys a weaker or smaller one (an acqui-hire if it's a young lab nobody uses).
        for t in targets {
            let c = s.competitors[t]
            // The further behind, the keener its board is to sell (a founding lab has a brand and customers to fall
            // back on, so it holds out longer).
            let farBehind = gap(c, s) > (c.spec == nil ? 1.2 : 0.9)
            var odds = (acquihire(s, t) || farBehind ? 0.03 : 0.006) * crowd
            if c.isPublic { odds *= 0.3 }
            guard roll(s, "takeover|\(c.id)|\(m)") < odds else { continue }
            let price = max(2e8, c.valuation) * (1.1 + 0.25 * roll(s, "premium|\(c.id)|\(m)"))
            guard let b = buyer(s, for: t, price: price) else { continue }
            // Paris guards its national champion: half the bids for Sirocco are blocked.
            if c.id == "sirocco", roll(s, "veto|\(c.id)|\(m)") < 0.5 {
                let bidder = s.competitors[b].def.name
                let body = "The French government blocked \(bidder)'s \(Fmt.money(price)) bid for \(c.def.name), citing European AI sovereignty. "
                    + "The lab stays independent — for now."
                Sim.news(&s, "France blocks \(bidder)'s bid for \(c.def.name)", body, .competitor)
                record(&s, .blocked, lab: c.id, other: s.competitors[b].id, title: "\(bidder)'s bid blocked by France", body: body, amount: price)
                return true
            }
            propose(&s, buyer: b, target: t, price: price)
            return true
        }
        // Two strugglers of similar size merge to survive.
        let privateWeak = weakOnes.filter { !s.competitors[$0].isPublic && !acquihire(s, $0) }
        for a in privateWeak {
            for b in privateWeak where b > a {
                let va = max(1, s.competitors[a].valuation), vb = max(1, s.competitors[b].valuation)
                guard max(va, vb) / min(va, vb) < 2.5, roll(s, "merge|\(s.competitors[a].id)|\(s.competitors[b].id)|\(m)") < 0.004 * crowd else { continue }
                merge(&s, va >= vb ? a : b, va >= vb ? b : a)
                return true
            }
        }
        // Labs nobody uses close when investors stop answering: young ones that never took off, or old ones left far
        // behind. (Fundraising runs first, so a lab still under nine months of runway here couldn't raise this month.)
        for i in s.competitors.indices {
            let c = s.competitors[i]
            guard c.alive, !c.models.isEmpty, !c.isPublic, RivalEconomy.parent(c, s) == nil,
                  c.revenueRun < Macro.marketSize(s.year) * 0.003, (RivalEconomy.runwayMonths(c) ?? 99) < 9 else { continue }
            // New labs get three years to find their feet; the founding eight wind down only when left about two years
            // behind.
            let failed = c.spec != nil ? (age(c, s) ?? 0) > 3 && gap(c, s) > 0.75 : gap(c, s) > 1.2
            guard failed, roll(s, "winddown|\(c.id)|\(m)") < (c.spec != nil ? 0.12 : 0.04) else { continue }
            windDown(&s, i)
            return true
        }
        return false
    }

    /// Dragon Lake sits behind export controls and national-security reviews on both sides: no rival may buy it or
    /// merge with it, and it can't buy them.
    static func walledOff(_ c: CompetitorState) -> Bool { c.id == "dragonlake" }

    /// Behind, tiny or short of money — and not already in trouble (distressed labs go through the fire sale instead).
    static func weak(_ s: GameState, _ i: Int) -> Bool {
        let c = s.competitors[i]
        guard c.alive, !c.models.isEmpty, !walledOff(c), RivalEconomy.parent(c, s) == nil, c.distressMonths == 0,
              !s.pendingDeals.contains(where: { $0.targetID == c.id }), (age(c, s) ?? 9) >= 1.5 else { return false }
        let behind = gap(c, s)
        let tiny = c.revenueRun < Macro.marketSize(s.year) * 0.006
        let short = (RivalEconomy.runwayMonths(c) ?? 99) < 10
        return behind > 0.45 || (tiny && behind > 0.2) || short
    }

    /// A private lab a giant could swallow: worth less than a sixth of the most valuable lab, past its first year and a
    /// half, and free to sell.
    static func small(_ s: GameState, _ i: Int) -> Bool {
        let c = s.competitors[i]
        guard c.alive, !c.models.isEmpty, !c.isPublic, !walledOff(c), RivalEconomy.parent(c, s) == nil, c.distressMonths == 0,
              !s.pendingDeals.contains(where: { $0.targetID == c.id }), (age(c, s) ?? 9) >= 1.5 else { return false }
        let biggest = labsInBusiness(s).map(\.valuation).max() ?? 0
        return c.valuation < biggest / 6
    }

    /// A young lab with almost no customers: worth more for its people than its products.
    static func acquihire(_ s: GameState, _ i: Int) -> Bool {
        let c = s.competitors[i]
        guard let a = age(c, s), a >= 2 else { return false }
        return c.revenueRun < Macro.marketSize(s.year) * 0.004
    }

    /// The lab most likely to buy `t` at `price`: big enough, with the money, not still digesting its last deal,
    /// and not one regulators would stop.
    static func buyer(_ s: GameState, for t: Int, price: Double) -> Int? {
        let target = s.competitors[t]
        guard !walledOff(target) else { return nil }
        var best: (index: Int, score: Double)? = nil
        for (j, c) in s.competitors.enumerated() where j != t && c.alive && !c.models.isEmpty && c.distressMonths == 0 {
            if (age(c, s) ?? 9) < 3 || RivalEconomy.isStateLab(c) || walledOff(c) { continue }
            guard c.valuation >= max(price, target.valuation) * 3 else { continue }
            guard RivalEconomy.parent(c, s) != nil || c.isPublic || c.cash >= price * 0.5 else { continue }
            if s.rivalEvents.contains(where: { $0.otherID == c.id && ($0.kind == "acquired" || $0.kind == "merged") && GameCalendar.daysBetween($0.date, s.date) < 540 }) { continue }
            if c.apiShare + target.apiShare > 0.33 || c.consumerShare + target.consumerShare > 0.33 { continue }
            let p = RivalStrategy.personality(c.id)
            let racer: Double = p[.race] ?? 0
            let raider: Double = p[.talentRaid] ?? 0
            let racing: Double = RivalStrategy.play(c) == .race ? 0.5 : 0
            let hunger = 1 + racer * 0.5 + raider * 0.5 + racing
            let luck = 0.7 + 0.6 * roll(s, "buyer|\(c.id)|\(target.id)|\(monthIndex(s))")
            let score = c.valuation * hunger * luck
            if best == nil || score > best!.score { best = (j, score) }
        }
        return best?.index
    }

    /// A rival wants to buy `t`. If you could do the deal yourself, its board offers it to you first (an inbox offer);
    /// the rival's deal closes once you pass or the offer lapses.
    static func propose(_ s: inout GameState, buyer b: Int, target t: Int, price: Double) {
        let target = s.competitors[t]
        let buyer = s.competitors[b]
        let bid = price * 1.05
        guard canBid(s, t, price: bid) else {
            takeover(&s, buyer: b, target: t, price: price, distressed: false)
            return
        }
        let haul = Acquisitions.haul(target, s)
        let risk = Int(Acquisitions.antitrustRisk(target, s) * 100)
        Events.addDecision(&s, kind: "merger_offer", title: "\(buyer.def.name) wants to buy \(target.def.name) — you can bid first",
                           body: "\(target.def.name)'s board has an offer of \(Fmt.money(price)) from \(buyer.def.name), but will sell to you for \(Fmt.money(bid)), half in stock. "
                               + "You'd get \(haul.techs.count) secret technique\(haul.techs.count == 1 ? "" : "s"), \(haul.researchers) researchers, \(Fmt.int(haul.chips)) chips and its users (\(risk)% risk regulators block it). "
                               + "Pass, and \(buyer.def.name) gets all of that instead.",
                           image: "nvidia_hq",
                           options: [DecisionOption(label: "Buy \(target.def.name)", detail: "\(Fmt.money(bid * 0.5)) cash + \(Fmt.money(bid * 0.5)) in new shares."),
                                     DecisionOption(label: "Let \(buyer.def.name) have it", detail: "\(buyer.def.name) gets its people, compute and techniques.")],
                           amount: bid, ref: target.id)
        s.pendingDeals.append(RivalDeal(targetID: target.id, buyerID: buyer.id, price: price, date: s.date, decisionID: s.decisions.last?.id))
        Sim.news(&s, "\(buyer.def.name) in talks to buy \(target.def.name)", "A deal worth about \(Fmt.money(price)) is close. \(target.def.name)'s board has offered you the first chance.",
                 .competitor)
    }

    static func canBid(_ s: GameState, _ t: Int, price: Double) -> Bool {
        let c = s.competitors[t]
        guard s.gameOver == nil, s.decisions.count < 3, !s.decisions.contains(where: { $0.kind == "merger_offer" }),
              Acquisitions.blocker(c, s) == nil else { return false }
        return s.cash >= price * 0.5
    }

    /// Close the deals you passed on (or let lapse).
    static func settleDeals(_ s: inout GameState) {
        guard !s.pendingDeals.isEmpty else { return }
        let deals = s.pendingDeals
        s.pendingDeals = []
        var waiting: [RivalDeal] = []
        for d in deals {
            if let id = d.decisionID, s.decisions.contains(where: { $0.id == id }) {
                waiting.append(d)
                continue
            }
            guard let t = s.competitors.firstIndex(where: { $0.id == d.targetID }), s.competitors[t].alive,
                  let b = s.competitors.firstIndex(where: { $0.id == d.buyerID }), s.competitors[b].alive else { continue }
            takeover(&s, buyer: b, target: t, price: d.price, distressed: false)
        }
        s.pendingDeals += waiting
    }

    /// `b` buys `t` for `price`.
    static func takeover(_ s: inout GameState, buyer b: Int, target t: Int, price: Double, distressed: Bool) {
        let target = s.competitors[t]
        let buyer = s.competitors[b]
        let known = (s.rivalTech[buyer.id] ?? []).count
        absorb(&s, into: b, from: t, price: price, paid: true)
        let techs = (s.rivalTech[buyer.id] ?? []).count - known
        let paid = payout(&s, t, price)
        close(&s, t, by: buyer.id, note: "Acquired by \(buyer.def.name) for \(Fmt.money(price))")
        let body = "\(buyer.def.name) \(distressed ? "picks up the struggling lab" : "buys its smaller rival") for \(Fmt.money(price)): \(Fmt.int(Int(Double(target.headcount) * 0.6))) staff, "
            + "\(Fmt.count(target.computeH100e)) H100e of compute\(techs > 0 ? " and \(techs) secret technique\(techs == 1 ? "" : "s")" : ""). "
            + "Expect \(buyer.def.name)'s next model to benefit.\(paid > 0 ? " Your stake pays \(Fmt.money(paid))." : "")"
        Sim.news(&s, "\(buyer.def.name) buys \(target.def.name)", body, .competitor, image: "nvidia_hq", important: true)
        record(&s, .acquired, lab: target.id, other: buyer.id, title: "Bought by \(buyer.def.name)", body: body, amount: price)
    }

    /// `b` takes over `t`'s compute contracts, most of its staff, its brand and its techniques.
    static func absorb(_ s: inout GameState, into b: Int, from t: Int, price: Double, paid: Bool) {
        let target = s.competitors[t]
        let buyerID = s.competitors[b].id
        let compute = (target.computePlan > 0 ? target.computePlan : target.computeH100e) * 0.8
        s.competitors[b].computePlan = max(s.competitors[b].computePlan, s.competitors[b].computeH100e) + compute
        s.competitors[b].computeH100e += compute
        s.competitors[b].headcount += Int(Double(target.headcount) * 0.6)
        s.competitors[b].brand = min(100, s.competitors[b].brand + target.brand * 0.15)
        s.competitors[b].turmoil += 0.1
        // A technique comes along only if the people who know it stay (about three in five do).
        var known = s.rivalTech[buyerID] ?? []
        for tech in s.rivalTech[target.id] ?? [] where !known.contains(tech) && roll(s, "keeps|\(buyerID)|\(target.id)|\(tech)") < 0.6 {
            known.append(tech)
        }
        if !known.isEmpty { s.rivalTech[buyerID] = known }
        if RivalEconomy.parent(s.competitors[b], s) == nil {
            // Half a takeover (all of a merger) is paid in new shares: the buyer is worth more, and anyone holding a
            // stake in it, you included, owns a smaller slice of it.
            let stock = paid ? price * 0.5 : target.valuation * 0.8
            s.competitors[b].cash += max(0, target.cash) - (paid ? price * 0.5 : 0)
            s.competitors[b].valuation += stock
            RivalEconomy.dilute(&s, b, amount: stock, post: s.competitors[b].valuation)
        }
        // Their people know their recipes: the buyer's next run gets a little better.
        if var p = s.competitors[b].project, p.procedural {
            p.cAdjust += 0.02
            s.competitors[b].project = p
        }
    }

    static func merge(_ s: inout GameState, _ a: Int, _ b: Int) {
        let survivor = s.competitors[a]
        let other = s.competitors[b]
        absorb(&s, into: a, from: b, price: 0, paid: false)
        let paid = payout(&s, b, other.valuation)
        close(&s, b, by: survivor.id, note: "Merged into \(survivor.def.name)")
        s.competitors[a].headcount = Int(Double(s.competitors[a].headcount) * 0.9)
        let body = "Neither could keep up alone. The combined lab keeps the \(survivor.def.name) name, \(Fmt.money(max(0, s.competitors[a].cash))) in cash and "
            + "\(Fmt.count(s.competitors[a].computeH100e)) H100e of compute; about one in ten jobs goes.\(paid > 0 ? " Your stake in \(other.def.name) is bought out for \(Fmt.money(paid))." : "")"
        Sim.news(&s, "\(survivor.def.name) and \(other.def.name) merge", body, .competitor, image: "stock_exchange", important: true)
        record(&s, .merged, lab: other.id, other: survivor.id, title: "Merged into \(survivor.def.name)", body: body, amount: other.valuation)
    }

    static func windDown(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        let paid = payout(&s, i, max(0, c.cash) * 0.6)
        close(&s, i, by: "", note: "Wound down \(s.date.gameShort)")
        let body = "\(c.def.name) couldn't keep up: its best model trails the frontier by over a year and too few customers pay for it. "
            + "It returns what's left of its cash to investors; its researchers are on the market.\(paid > 0 ? " Your stake gets \(Fmt.money(paid)) back." : "")"
        Sim.news(&s, "\(c.def.name) winds down", body, .competitor, important: true)
        record(&s, .shutdown, lab: c.id, title: "Wound down", body: body)
    }

    /// Your stake in a lab leaving the market pays its share of `value` (nothing when it's bankrupt).
    @discardableResult
    static func payout(_ s: inout GameState, _ t: Int, _ value: Double) -> Double {
        let id = s.competitors[t].id
        guard let stake = s.rivalStakes[id], stake > 0 else { return 0 }
        let cost = s.rivalStakeCost[id] ?? 0
        let paid = stake * max(0, value)
        s.cash += paid
        s.month.oneOffIncome += paid - cost
        s.rivalStakes[id] = nil
        s.rivalStakeCost[id] = nil
        return paid
    }

    /// Take a lab off the market.
    static func close(_ s: inout GameState, _ t: Int, by buyer: String, note: String, bankrupt: Bool = false) {
        let id = s.competitors[t].id
        s.competitors[t].acquired = true
        s.competitors[t].bankrupt = bankrupt
        s.competitors[t].exitNote = note
        s.competitors[t].acquiredBy = buyer
        s.competitors[t].exitDate = s.date
        s.competitors[t].turmoil = max(s.competitors[t].turmoil, 1)
        s.competitors[t].project = nil
        s.competitors[t].play = ""
        s.pendingDeals.removeAll { $0.targetID == id }
    }

    // MARK: History

    static func record(_ s: inout GameState, _ kind: RivalEvent.Kind, lab: String, other: String = "", title: String, body: String, amount: Double = 0) {
        s.rivalEvents.insert(RivalEvent(date: s.date, kind: kind.rawValue, labID: lab, otherID: other, title: title, body: body, amount: amount), at: 0)
        if s.rivalEvents.count > 150 { s.rivalEvents.removeLast(s.rivalEvents.count - 150) }
    }

    /// Display name of a lab ID, "player" or an outside buyer.
    static func name(_ id: String, _ s: GameState) -> String {
        if id == "player" { return s.companyName }
        if id.isEmpty { return "" }
        return CompetitorCatalog.def(id).name
    }
}

// MARK: - What the Rivals hub shows

/// One lab (or you) in the Rivals hub's field table.
struct RivalStanding: Identifiable {
    /// Lab ID, or "player".
    var id: String
    var name: String
    var color: UInt32
    var symbol: String
    var isPlayer: Bool
    /// "Spin-out", "National lab", "Startup" for labs founded during the game; empty for the founding eight.
    var kind: String
    /// Founded within the last year.
    var isNew: Bool
    var flagship: String
    /// Best released model on today's Intelligence Index.
    var index: Double
    /// Change in that over the last twelve months (nil without a year of models).
    var momentum: Double?
    /// How far its best model trails the best in the world, in months of frontier progress.
    var monthsBehind: Double
    var valuation: Double
    var revenue: Double
    var compute: Double
    var play: RivalPlay?
    var status: String
}

/// One line in the Rivals hub's feeds.
struct RivalFeedItem: Identifiable {
    enum Tone: Sendable { case good, bad, neutral, warning }
    var id: String
    var date: Date
    var labID: String
    var symbol: String
    var title: String
    var detail: String
    var tone: Tone = .neutral
}

extension RivalLifecycle {
    /// Every lab in business and you, best model first. `board` is the store's cached leaderboard, `revenue` and
    /// `compute` are yours (also cached), so this does no simulation work.
    static func standings(_ s: GameState, board: [Leaderboard.Entry], revenue: Double, compute: Double) -> [RivalStanding] {
        var best: [String: Leaderboard.Entry] = [:]
        for e in board where e.released {
            if let b = best[e.labID], b.index >= e.index { continue }
            best[e.labID] = e
        }
        let topC = board.filter(\.released).map(\.c).max() ?? Macro.frontier(s.year)
        let perMonth = RivalStrategy.frontierPerMonth(s.year)
        let yearAgo = GameCalendar.addMonths(s.date, -12)
        var out: [RivalStanding] = []
        for c in labsInBusiness(s) {
            let def = c.def
            let e = best[c.id]
            let then = c.models.filter { $0.date <= yearAgo }.map(\.index).max()
            let spec = c.spec
            out.append(RivalStanding(
                id: c.id, name: def.name, color: def.color, symbol: def.symbol, isPlayer: false, kind: spec?.kind.label ?? "",
                isNew: spec.map { s.year - $0.founded.decimal < 1 } ?? false, flagship: e?.model ?? "—", index: e?.index ?? 0,
                momentum: e.flatMap { cur in then.map { cur.index - $0 } }, monthsBehind: e.map { max(0, topC - $0.c) / perMonth } ?? 99,
                valuation: c.valuation, revenue: c.revenueRun, compute: c.computeH100e, play: RivalStrategy.play(c), status: RivalEconomy.status(c, s)))
        }
        let mine = best["player"]
        let mineThen = s.models.filter { $0.released && ($0.releaseDate ?? $0.created) <= yearAgo }.map(\.index).max()
        out.append(RivalStanding(
            id: "player", name: s.companyName, color: 0, symbol: s.logoSymbol, isPlayer: true, kind: "", isNew: false,
            flagship: mine?.model ?? "—", index: mine?.index ?? 0, momentum: mine.flatMap { cur in mineThen.map { cur.index - $0 } },
            monthsBehind: mine.map { max(0, topC - $0.c) / perMonth } ?? 99, valuation: s.valuation, revenue: revenue, compute: compute,
            play: nil, status: s.isPublic ? "Public" : "You"))
        return out.sorted { $0.index > $1.index }
    }

    /// What the labs did lately, newest first: foundings, takeovers and failures, releases, rounds of $1B or more (any
    /// round for a young lab), new strategies and raids on you. Pass `lab` for one lab's own story; `eventsOnly` keeps
    /// just the foundings, takeovers, listings and failures (no raids).
    static func feed(_ s: GameState, since: Date, lab: String? = nil, limit: Int = 12, eventsOnly: Bool = false) -> [RivalFeedItem] {
        var out: [RivalFeedItem] = []
        let mine = s.releasedModels.map(\.index).max() ?? 0
        for e in s.rivalEvents where e.date >= since && (lab == nil || e.labID == lab || e.otherID == lab) && !(eventsOnly && e.kind == "raid") {
            let kind = e.eventKind
            let tone: RivalFeedItem.Tone
            switch kind {
            case .bought: tone = .good
            case .raid: tone = .bad
            case .acquired, .merged: tone = e.otherID == "player" ? .good : .warning
            default: tone = .neutral
            }
            let who = name(e.labID, s)
            out.append(RivalFeedItem(id: e.id.uuidString, date: e.date, labID: e.labID, symbol: kind?.symbol ?? "circle.fill",
                                     title: lab == e.labID ? e.title : "\(who): \(e.title)", detail: e.body, tone: tone))
        }
        for c in s.competitors where !eventsOnly && (lab == nil || c.id == lab) {
            let n = c.def.name
            let young = c.spec.map { s.year - $0.founded.decimal < 3 } ?? false
            for m in c.models where m.date >= since {
                out.append(RivalFeedItem(id: m.id.uuidString, date: m.date, labID: c.id, symbol: "shippingbox.fill",
                                         title: lab == nil ? "\(n) released \(m.name)" : "Released \(m.name)",
                                         detail: "Intelligence Index \(Fmt.score(m.index))\(m.open ? ", open weights" : ""). API \(Fmt.price(m.price))/M tokens.",
                                         tone: mine > 0 && m.index > mine ? .bad : .neutral))
            }
            for m in c.openModels where m.date >= since {
                out.append(RivalFeedItem(id: m.id.uuidString, date: m.date, labID: c.id, symbol: "lock.open.fill",
                                         title: lab == nil ? "\(n) open-sourced \(m.name)" : "Open-sourced \(m.name)",
                                         detail: "Free weights at index \(Fmt.score(m.index)) pull API prices down.", tone: .warning))
            }
            for r in c.rounds where r.date >= since && r.amount > 0 && (r.amount >= 1e9 || young || lab != nil) && r.kind != .ipo {
                out.append(RivalFeedItem(id: r.id.uuidString, date: r.date, labID: c.id, symbol: "banknote.fill",
                                         title: lab == nil ? "\(n) raised \(Fmt.money(r.amount))" : "\(r.label): \(Fmt.money(r.amount))",
                                         detail: "\(r.label) led by \(r.lead)\(r.postMoney > 0 ? " at \(Fmt.money(r.postMoney))" : "").", tone: .neutral))
            }
            if let since2 = c.playSince, since2 >= since, let play = RivalStrategy.play(c) {
                out.append(RivalFeedItem(id: "\(c.id)-play-\(Int(since2.timeIntervalSince1970))", date: since2, labID: c.id, symbol: play.symbol,
                                         title: lab == nil ? "\(n): \(play.title.lowercased())" : play.title,
                                         detail: c.playReason, tone: play.threat >= 2 ? .bad : .neutral))
            }
        }
        return Array(out.sorted { $0.date > $1.date }.prefix(limit))
    }

    /// Each lab's best Intelligence Index over time (step series from its releases), for the momentum chart.
    static func trajectories(_ s: GameState, labs: [String], since: Date) -> [(id: Int, lab: String, date: Date, index: Double)] {
        var out: [(id: Int, lab: String, date: Date, index: Double)] = []
        for id in labs {
            guard let c = s.competitors.first(where: { $0.id == id }) else { continue }
            var best = 0.0
            var started = false
            for m in c.models.sorted(by: { $0.date < $1.date }) {
                if m.date >= since && !started {
                    // Start the line at the left edge with what the lab had before.
                    if best > 0 { out.append((out.count, c.def.name, since, best)) }
                    started = true
                }
                best = max(best, m.index)
                if m.date >= since { out.append((out.count, c.def.name, m.date, best)) }
            }
            if best > 0 {
                if !started { out.append((out.count, c.def.name, since, best)) }
                out.append((out.count, c.def.name, s.date, best))
            }
        }
        return out
    }
}
