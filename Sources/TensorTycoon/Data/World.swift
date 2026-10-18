import Foundation

// MARK: - Sites & locations

enum SiteKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case garage = "Garage"
    case office = "Office Server Room"
    case colo = "Colocation Cage"
    case datacenter = "Owned Datacenter"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .garage: "house.fill"
        case .office: "building.2.fill"
        case .colo: "server.rack"
        case .datacenter: "building.columns.fill"
        }
    }

    var image: String {
        switch self {
        case .garage: "garage"
        case .office: "server_room"
        case .colo: "dc_corridor"
        case .datacenter: "hyperscale_campus"
        }
    }
}

enum Cooling: String, Codable, CaseIterable, Identifiable, Sendable {
    case air = "Air"
    case liquid = "Direct-to-chip liquid"
    case immersion = "Immersion"

    var id: String { rawValue }

    var basePUE: Double {
        switch self {
        case .air: 1.35
        case .liquid: 1.15
        case .immersion: 1.06
        }
    }

    var capexPerMW: Double {
        switch self {
        case .air: 10_000_000
        case .liquid: 13_000_000
        case .immersion: 14_000_000
        }
    }

    var image: String {
        switch self {
        case .air: "chiller"
        case .liquid: "rack_rear"
        case .immersion: "immersion"
        }
    }

    var supportsLiquidChips: Bool { self != .air }
}

enum PowerDeal: String, Codable, CaseIterable, Identifiable, Sendable {
    case grid = "Grid"
    case solar = "Solar PPA"
    case wind = "Wind PPA"
    case gas = "On-site gas turbines"
    case nuclear = "Nuclear PPA"
    case smr = "Small modular reactors"
    case fusion = "Fusion power"

    var id: String { rawValue }

    var priceMultiplier: Double {
        switch self {
        case .grid: 1.0
        case .solar: 0.86
        case .wind: 0.88
        case .gas: 1.12
        case .nuclear: 1.05
        case .smr: 1.08
        case .fusion: 0.55
        }
    }

    var green: Double {
        switch self {
        case .grid: 0.4
        case .solar, .wind, .nuclear, .smr, .fusion: 1.0
        case .gas: 0.0
        }
    }

    var availableFrom: Double {
        switch self {
        case .nuclear: 2024.7
        case .smr: 2030.0
        case .fusion: 2034.5
        default: 2010
        }
    }

    /// Whether this deal is open to you (the Superconducting Grid mega-project brings fusion forward).
    func available(_ s: GameState) -> Bool {
        if self == .fusion && XenoScience.megaDone(s, "supergrid") && s.year >= 2029 { return true }
        if self == .fusion { return s.year >= availableFrom - Science.fusionPullIn(s) }   // 3.6: fusion-control discoveries
        return s.year >= availableFrom
    }

    var image: String {
        switch self {
        case .grid: "substation"
        case .solar: "solar_farm"
        case .wind: "substation"
        case .gas: "generator"
        case .nuclear: "nuclear"
        case .smr: "nuclear"
        case .fusion: "substation"
        }
    }

    var blurb: String {
        switch self {
        case .grid: "Utility power at the local industrial rate."
        case .solar: "Long-term solar contract: cheaper and green, but you still need the grid at night."
        case .wind: "Wind power purchase agreement: cheap, green, a little less predictable."
        case .gas: "Behind-the-meter turbines: build faster without waiting for the grid, pricier and dirty."
        case .nuclear: "24/7 carbon-free power from a restarted or uprated reactor. Great for your brand."
        case .smr: "A fleet of factory-built reactors on your own land: tens of gigawatts with no grid queue."
        case .fusion: "Commercial fusion plants feeding the campus directly: cheap, clean and practically unlimited."
        }
    }

    /// The most one site can draw on this kind of power, before the location's grid comes into it.
    var siteCapMW: Double {
        switch self {
        case .grid, .solar, .wind: 0
        case .gas: 10_000
        case .nuclear: 3_000
        case .smr: 25_000
        case .fusion: 100_000
        }
    }
}

struct Location: Identifiable, Sendable {
    let id: String
    let name: String
    let region: String
    let powerPrice: Double   // $/kWh industrial
    let pueDelta: Double
    let buildSpeed: Double   // >1 = faster
    let gridCapMW: Double
    let coloFee: Double      // $/kW-month for space + cooling
    let image: String
    let blurb: String

    /// Grid capacity for one site in year `y`: utilities keep building transmission as AI demand grows.
    func gridCap(_ y: Double) -> Double {
        gridCapMW * interpolate([(2016, 0.6), (2024, 1.0), (2027, 1.3), (2030, 2.0), (2035, 4.0)], at: y)
    }
}

enum LocationCatalog {
    static let all: [Location] = core + european   // 3.5: European locations live in Countries.swift
    static let core: [Location] = [
        Location(id: "nova", name: "Ashburn, Virginia", region: "US East", powerPrice: 0.085, pueDelta: 0.0, buildSpeed: 0.8,
                 gridCapMW: 1_200, coloFee: 185, image: "dc_corridor",
                 blurb: "Data Center Alley — the densest datacenter market on Earth. Great connectivity, long grid queues."),
        Location(id: "texas", name: "Abilene, Texas", region: "US South", powerPrice: 0.060, pueDelta: 0.03, buildSpeed: 1.25,
                 gridCapMW: 5_000, coloFee: 140, image: "dc_construction",
                 blurb: "Cheap ERCOT power, fast permits and endless land. Home of gigawatt campuses. Watch for summer price spikes."),
        Location(id: "iowa", name: "Council Bluffs, Iowa", region: "US Midwest", powerPrice: 0.068, pueDelta: -0.01, buildSpeed: 1.0,
                 gridCapMW: 2_000, coloFee: 130, image: "hyperscale_campus",
                 blurb: "Wind-heavy grid, cool winters and hyperscaler neighbours."),
        Location(id: "oregon", name: "The Dalles, Oregon", region: "US West", powerPrice: 0.055, pueDelta: -0.03, buildSpeed: 0.9,
                 gridCapMW: 1_000, coloFee: 150, image: "substation",
                 blurb: "Columbia River hydropower: cheap, clean and constrained."),
        Location(id: "arizona", name: "Phoenix, Arizona", region: "US Southwest", powerPrice: 0.075, pueDelta: 0.08, buildSpeed: 1.1,
                 gridCapMW: 3_000, coloFee: 150, image: "dc_rows",
                 blurb: "Lots of land and solar, but 45 °C summers punish air cooling."),
        Location(id: "quebec", name: "Montréal, Québec", region: "Canada", powerPrice: 0.045, pueDelta: -0.06, buildSpeed: 0.8,
                 gridCapMW: 800, coloFee: 140, image: "dc_hall",
                 blurb: "Some of the cheapest hydro power in the world and free cooling most of the year."),
        Location(id: "iceland", name: "Reykjanes, Iceland", region: "Nordics", powerPrice: 0.040, pueDelta: -0.10, buildSpeed: 0.7,
                 gridCapMW: 300, coloFee: 160, image: "supercomputer",
                 blurb: "Geothermal power and arctic air. Small grid, far from users."),
        Location(id: "uae", name: "Abu Dhabi, UAE", region: "Middle East", powerPrice: 0.050, pueDelta: 0.10, buildSpeed: 1.35,
                 gridCapMW: 5_000, coloFee: 150, image: "gpu_cluster",
                 blurb: "Sovereign money, cheap gas power and very fast construction — if you can handle the heat."),
    ]

    static let byID: [String: Location] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

// MARK: - Training data

struct DataSource: Identifiable, Sendable {
    let id: String
    let name: String
    let available: Double
    let upfront: Double
    let monthly: Double
    let quality: Double
    let code: Double
    let reasoning: Double
    let arena: Double
    let legalRisk: Double
    let free: Bool
    let blurb: String

    func tokensT(_ y: Double) -> Double {
        switch id {
        case "web": return interpolate([(2016, 1.2), (2018, 2.0), (2020, 4.0), (2022, 8.0), (2023, 12), (2025, 20), (2027, 28), (2030, 35)], at: y)
        case "code_open": return interpolate([(2016, 0.15), (2020, 0.4), (2023, 1.0), (2026, 1.6), (2030, 2.5)], at: y)
        case "wiki": return 0.03
        case "papers": return 0.12
        case "shadow_books": return 0.25
        case "books_license": return 0.15
        case "news_license": return 0.06
        case "forum_license": return 0.5
        case "code_license": return 0.12
        case "science_license": return 0.1
        case "video_license": return 0.8
        default: return 0
        }
    }
}

enum DataCatalog {
    static let all: [DataSource] = [
        DataSource(id: "web", name: "Common Crawl web corpus", available: 2010, upfront: 0, monthly: 0,
                   quality: 0, code: 0, reasoning: 0, arena: 0, legalRisk: 0.02, free: true,
                   blurb: "Petabytes of scraped web pages. Free, noisy, and the backbone of every LLM."),
        DataSource(id: "wiki", name: "Wikipedia & reference works", available: 2010, upfront: 0, monthly: 0,
                   quality: 0.02, code: 0, reasoning: 0.01, arena: 0, legalRisk: 0, free: true,
                   blurb: "Small but dense, high-quality factual text."),
        DataSource(id: "code_open", name: "Permissively-licensed code", available: 2016, upfront: 0, monthly: 0,
                   quality: 0.01, code: 0.08, reasoning: 0.02, arena: 0, legalRisk: 0.01, free: true,
                   blurb: "MIT/Apache-licensed GitHub repositories, deduplicated."),
        DataSource(id: "papers", name: "Open-access papers (arXiv, PubMed)", available: 2016, upfront: 0, monthly: 0,
                   quality: 0.02, code: 0, reasoning: 0.04, arena: 0, legalRisk: 0, free: true,
                   blurb: "Scientific writing and LaTeX math."),
        DataSource(id: "shadow_books", name: "Shadow-library books (pirated)", available: 2010, upfront: 0, monthly: 0,
                   quality: 0.07, code: 0, reasoning: 0.02, arena: 5, legalRisk: 0.55, free: true,
                   blurb: "Millions of pirated books. High quality, free... and in 2025 one lab paid a record $1.5B settlement over exactly this."),
        DataSource(id: "books_license", name: "Licensed book catalogue", available: 2023.8, upfront: 40_000_000, monthly: 0,
                   quality: 0.06, code: 0, reasoning: 0.02, arena: 5, legalRisk: 0, free: false,
                   blurb: "Buy and scan print books legally, or license from publishers."),
        DataSource(id: "news_license", name: "News publisher licences", available: 2023.5, upfront: 0, monthly: 2_000_000,
                   quality: 0.02, code: 0, reasoning: 0, arena: 10, legalRisk: 0, free: false,
                   blurb: "Archive and real-time access deals with major publishers."),
        DataSource(id: "forum_license", name: "Forum & Q&A data licence", available: 2024.1, upfront: 0, monthly: 5_000_000,
                   quality: 0.03, code: 0.02, reasoning: 0, arena: 15, legalRisk: 0, free: false,
                   blurb: "Conversational data from a giant discussion site (like the 2024 $60M/yr deals)."),
        DataSource(id: "code_license", name: "Proprietary code & Q&A licence", available: 2024.0, upfront: 0, monthly: 1_200_000,
                   quality: 0.01, code: 0.07, reasoning: 0.01, arena: 0, legalRisk: 0, free: false,
                   blurb: "Licensed developer Q&A and enterprise code corpora."),
        DataSource(id: "science_license", name: "Scientific publisher deal", available: 2024.0, upfront: 0, monthly: 2_000_000,
                   quality: 0.02, code: 0, reasoning: 0.07, arena: 0, legalRisk: 0, free: false,
                   blurb: "Paywalled journals and textbooks from academic publishers."),
        DataSource(id: "human_feedback", name: "Human preference labelling", available: 2019.0, upfront: 0, monthly: 600_000,
                   quality: 0, code: 0, reasoning: 0, arena: 25, legalRisk: 0, free: false,
                   blurb: "A labelling vendor ranks model outputs for RLHF. Quality post-training needs this."),
        DataSource(id: "expert_data", name: "Expert reasoning data (PhD annotators)", available: 2024.3, upfront: 0, monthly: 8_000_000,
                   quality: 0.02, code: 0.06, reasoning: 0.12, arena: 5, legalRisk: 0, free: false,
                   blurb: "Doctors, mathematicians and engineers writing worked solutions at $100+/hour."),
        DataSource(id: "video_license", name: "Licensed video corpus", available: 2024.0, upfront: 0, monthly: 2_500_000,
                   quality: 0.01, code: 0, reasoning: 0, arena: 5, legalRisk: 0, free: false,
                   blurb: "Stock footage and creator licensing for multimodal and video models."),
    ]

    static let byID: [String: DataSource] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}

// MARK: - Competitors (fictional labs inspired by real archetypes)

struct CompetitorDef: Identifiable, Sendable {
    let id: String
    let name: String
    let color: UInt32
    let symbol: String
    let archetype: String
    let founded: YM
    let firstModel: YM
    let hq: String
    let ceo: String
    let offsets: [(Double, Double)]
    let cadenceMonths: Double
    let priceMult: Double
    let tps: Double
    let brand: Double
    let openWeights: Bool
    let codeBonus: Double
    let computeShare: Double
    let releases: [(YM, String)]
    let prefix: String
    let nextVersion: Double
    let chatProduct: String

    func offset(_ y: Double) -> Double { interpolate(offsets, at: y) }
}

enum CompetitorCatalog {
    /// Models that existed before the labs' first frontier language models — translation and research models
    /// from 2016–18 — so an early game opens on a real leaderboard. They aren't releases: no lab's schedule moves.
    /// `delta` is capability relative to the world frontier on that date.
    static let incumbents: [(lab: String, date: YM, name: String, delta: Double, open: Bool)] = [
        ("deepgrove", YM(2016, 9), "Grove NMT", -0.5, false),
        ("prometheus", YM(2017, 4), "PRM Sentiment", -0.7, true),
        ("openweights", YM(2017, 5), "OW ConvS2S", -0.45, true),
        ("deepgrove", YM(2017, 6), "Grove Transformer", -0.15, true),
        ("openweights", YM(2018, 2), "OW ELMo", -0.35, true),
    ]

    static let all: [CompetitorDef] = [
        CompetitorDef(id: "prometheus", name: "Prometheus Labs", color: 0x10A37F, symbol: "flame.fill",
                      archetype: "Consumer giant", founded: YM(2015, 12), firstModel: YM(2018, 6), hq: "San Francisco",
                      ceo: "Morgan Vale",
                      offsets: [(2016, 0.0), (2023.5, 0.0), (2024.5, -0.04), (2030, -0.05)],
                      cadenceMonths: 6, priceMult: 1.0, tps: 85, brand: 70, openWeights: false, codeBonus: 0.0,
                      computeShare: 0.30,
                      releases: [(YM(2018, 6), "PRM-1"), (YM(2019, 2), "PRM-2"), (YM(2020, 6), "PRM-3"), (YM(2022, 3), "PRM-3.5"), (YM(2022, 11), "PRM-3.5 Chat"),
                                 (YM(2023, 3), "PRM-4"), (YM(2023, 11), "PRM-4 Turbo"), (YM(2024, 5), "PRM-4o"), (YM(2024, 9), "PRM-o1"),
                                 (YM(2025, 2), "PRM-4.5"), (YM(2025, 4), "PRM-o3"), (YM(2025, 8), "PRM-5"), (YM(2025, 11), "PRM-5.1"),
                                 (YM(2026, 3), "PRM-5.4"), (YM(2026, 6), "PRM-5.5"), (YM(2026, 9), "PRM-5.6")],
                      prefix: "PRM-", nextVersion: 6.0, chatProduct: "Spark"),
        CompetitorDef(id: "deepgrove", name: "DeepGrove", color: 0x4285F4, symbol: "leaf.fill",
                      archetype: "Big-tech lab with its own TPUs", founded: YM(2010, 9), firstModel: YM(2018, 10), hq: "London & Mountain View",
                      ceo: "Priya Okonkwo",
                      offsets: [(2016, -0.25), (2022.2, -0.05), (2023.2, -0.3), (2024.2, -0.12), (2025.3, 0.0), (2030, 0.02)],
                      cadenceMonths: 7, priceMult: 0.85, tps: 110, brand: 65, openWeights: false, codeBonus: 0.0,
                      computeShare: 0.35,
                      releases: [(YM(2018, 10), "Grove-BERT"), (YM(2019, 10), "Grove-T5"), (YM(2021, 12), "Grove LM"), (YM(2022, 4), "Grove PaLM"),
                                 (YM(2023, 5), "Grove PaLM 2"), (YM(2023, 12), "Sequoia 1.0 Ultra"), (YM(2024, 2), "Sequoia 1.5"),
                                 (YM(2024, 12), "Sequoia 2.0"), (YM(2025, 3), "Sequoia 2.5"), (YM(2025, 11), "Sequoia 3"),
                                 (YM(2026, 2), "Sequoia 3.1"), (YM(2026, 8), "Sequoia 3.5")],
                      prefix: "Sequoia ", nextVersion: 4.0, chatProduct: "Grove"),
        CompetitorDef(id: "halcyon", name: "Halcyon AI", color: 0xD97757, symbol: "sun.max.fill",
                      archetype: "Safety-first, enterprise & coding", founded: YM(2021, 1), firstModel: YM(2023, 3), hq: "San Francisco",
                      ceo: "Elena Marsh",
                      offsets: [(2021, -0.6), (2023.2, -0.35), (2024.2, -0.06), (2025.0, 0.0), (2026.0, 0.03), (2030, 0.0)],
                      cadenceMonths: 5, priceMult: 1.1, tps: 70, brand: 45, openWeights: false, codeBonus: 0.18,
                      computeShare: 0.18,
                      releases: [(YM(2023, 3), "Aria 1"), (YM(2023, 7), "Aria 2"), (YM(2024, 3), "Aria 3 Opus"), (YM(2024, 6), "Aria 3.5"),
                                 (YM(2025, 2), "Aria 3.7"), (YM(2025, 5), "Aria 4"), (YM(2025, 9), "Aria 4.5"), (YM(2025, 11), "Aria 4.5 Opus"),
                                 (YM(2026, 2), "Aria 4.6"), (YM(2026, 5), "Aria 5"), (YM(2026, 9), "Aria 5.1")],
                      prefix: "Aria ", nextVersion: 5.5, chatProduct: "Aria"),
        CompetitorDef(id: "xenon", name: "Xenon AI", color: 0x8E8E93, symbol: "xmark.seal.fill",
                      archetype: "Builds giant clusters at record speed", founded: YM(2023, 7), firstModel: YM(2023, 11), hq: "Austin",
                      ceo: "Rex Calder",
                      offsets: [(2023.5, -1.0), (2024.0, -0.6), (2025.1, -0.12), (2025.6, -0.05), (2030, -0.08)],
                      cadenceMonths: 5, priceMult: 0.9, tps: 80, brand: 40, openWeights: false, codeBonus: 0.0,
                      computeShare: 0.20,
                      releases: [(YM(2023, 11), "Xenon-1"), (YM(2024, 8), "Xenon-2"), (YM(2025, 2), "Xenon-3"), (YM(2025, 7), "Xenon-4"),
                                 (YM(2025, 11), "Xenon-4.1"), (YM(2026, 4), "Xenon-5")],
                      prefix: "Xenon-", nextVersion: 5.5, chatProduct: "Xenon"),
        CompetitorDef(id: "openweights", name: "OpenWeights Collective", color: 0x0866FF, symbol: "lock.open.fill",
                      archetype: "Social-media giant giving models away", founded: YM(2013, 12), firstModel: YM(2023, 2), hq: "Menlo Park",
                      ceo: "Jordan Pike",
                      offsets: [(2017, -1.0), (2023.1, -0.8), (2023.5, -0.6), (2024.5, -0.33), (2025.3, -0.55), (2026.0, -0.45), (2030, -0.4)],
                      cadenceMonths: 8, priceMult: 0.15, tps: 120, brand: 50, openWeights: true, codeBonus: 0.0,
                      computeShare: 0.25,
                      releases: [(YM(2023, 2), "Llamina"), (YM(2023, 7), "Llamina 2"), (YM(2024, 4), "Llamina 3"), (YM(2024, 7), "Llamina 3.1 405B"),
                                 (YM(2024, 12), "Llamina 3.3"), (YM(2025, 4), "Llamina 4"), (YM(2026, 4), "Llamina 5")],
                      prefix: "Llamina ", nextVersion: 5.5, chatProduct: "Llamina Chat"),
        CompetitorDef(id: "dragonlake", name: "Dragon Lake AI", color: 0x4D6BFE, symbol: "water.waves",
                      archetype: "Ultra-efficient open models from Hangzhou", founded: YM(2023, 5), firstModel: YM(2023, 11), hq: "Hangzhou",
                      ceo: "Zhou Lan",
                      offsets: [(2023.3, -1.2), (2024.0, -0.8), (2024.9, -0.4), (2025.1, -0.28), (2026, -0.3), (2030, -0.3)],
                      cadenceMonths: 6, priceMult: 0.12, tps: 35, brand: 25, openWeights: true, codeBonus: 0.05,
                      computeShare: 0.04,
                      releases: [(YM(2023, 11), "DL-LLM"), (YM(2024, 5), "DL-V2"), (YM(2024, 12), "DL-V3"), (YM(2025, 1), "DL-R1"),
                                 (YM(2025, 8), "DL-V3.1"), (YM(2025, 12), "DL-V3.2"), (YM(2026, 4), "DL-V4")],
                      prefix: "DL-V", nextVersion: 4.5, chatProduct: "Dragon Lake"),
        CompetitorDef(id: "sirocco", name: "Sirocco AI", color: 0xFA520F, symbol: "wind",
                      archetype: "European efficient-model champion", founded: YM(2023, 4), firstModel: YM(2023, 9), hq: "Paris",
                      ceo: "Camille Durand",
                      offsets: [(2023.3, -1.4), (2024.0, -0.9), (2025.0, -0.7), (2030, -0.6)],
                      cadenceMonths: 6, priceMult: 0.5, tps: 90, brand: 25, openWeights: true, codeBonus: 0.04,
                      computeShare: 0.03,
                      releases: [(YM(2023, 9), "Sirocco 7B"), (YM(2023, 12), "Sirocco 8x7B"), (YM(2024, 2), "Sirocco Large"), (YM(2024, 7), "Sirocco Large 2"),
                                 (YM(2025, 5), "Sirocco Medium 3"), (YM(2025, 12), "Sirocco Large 3"), (YM(2026, 6), "Sirocco 4")],
                      prefix: "Sirocco ", nextVersion: 4.5, chatProduct: "Le Vent"),
        CompetitorDef(id: "aletheia", name: "Aletheia Labs", color: 0xB388FF, symbol: "infinity.circle.fill",
                      archetype: "Secretive straight-shot superintelligence lab", founded: YM(2024, 6), firstModel: YM(2027, 6), hq: "Palo Alto & Tel Aviv",
                      ceo: "Tomas Reyes",
                      offsets: [(2024.5, -0.3), (2027.4, 0.05), (2030, 0.12)],
                      cadenceMonths: 9, priceMult: 1.3, tps: 60, brand: 35, openWeights: false, codeBonus: 0.1,
                      computeShare: 0.05,
                      releases: [(YM(2027, 6), "Aletheia-1")],
                      prefix: "Aletheia-", nextVersion: 2, chatProduct: "Aletheia"),
    ]

    /// The eight founding labs by ID.
    static let fixedByID: [String: CompetitorDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Every lab by ID — the founding eight and the labs founded during the game — so `CompetitorCatalog.byID[id]`
    /// resolves new entrants too.
    static var byID: Directory { Directory() }

    struct Directory {
        subscript(id: String) -> CompetitorDef? { CompetitorCatalog.lookup(id) }
    }

    // MARK: Labs founded during the game

    /// Labs founded during the game, registered from the save (on load and new game) and when they're founded.
    /// Registration only adds or replaces: IDs carry a per-game hash, so labs from another game never collide.
    nonisolated(unsafe) private static var customDefs: [String: CompetitorDef] = [:]
    nonisolated(unsafe) private static var customSpecs: [String: CustomLabSpec] = [:]
    private static let registryLock = NSLock()

    static func register(_ specs: [CustomLabSpec]) {
        guard !specs.isEmpty else { return }
        registryLock.lock()
        defer { registryLock.unlock() }
        for spec in specs {
            customSpecs[spec.id] = spec
            customDefs[spec.id] = spec.def
        }
    }

    /// The definition behind a lab ID: the founding eight first, then labs founded in the game.
    static func lookup(_ id: String) -> CompetitorDef? {
        if let d = fixedByID[id] { return d }
        registryLock.lock()
        defer { registryLock.unlock() }
        return customDefs[id]
    }

    /// Like `lookup`, but never fails: an unknown ID (a save from a newer build) gets a neutral placeholder.
    static func def(_ id: String) -> CompetitorDef { lookup(id) ?? placeholder(id) }

    /// The saved spec of a lab founded during the game (nil for the founding eight).
    static func spec(_ id: String) -> CustomLabSpec? {
        guard fixedByID[id] == nil else { return nil }
        registryLock.lock()
        defer { registryLock.unlock() }
        return customSpecs[id]
    }

    static func placeholder(_ id: String) -> CompetitorDef {
        CompetitorDef(id: id, name: id, color: 0x9E9E9E, symbol: "questionmark.circle.fill", archetype: "Unknown lab", founded: YM(2016, 1),
                      firstModel: YM(2016, 1), hq: "—", ceo: "—", offsets: [(2016, -1.0)], cadenceMonths: 8, priceMult: 1, tps: 60, brand: 10,
                      openWeights: false, codeBonus: 0, computeShare: 0.01, releases: [], prefix: "\(id)-", nextVersion: 1, chatProduct: id)
    }

    /// Total "H100-equivalent" compute of a frontier-scale industry over time.
    static func industryCompute(_ y: Double) -> Double {
        interpolateLog([(2016.5, 2_000), (2020, 30_000), (2023, 300_000), (2024, 1_000_000), (2025, 3_000_000),
                        (2026, 8_000_000), (2028, 30_000_000), (2030, 80_000_000)], at: y, extrapolate: true)
    }
}

/// A lab founded during the game — a spin-out, a national lab or a startup. Saved with the game and registered with
/// `CompetitorCatalog`, so `CompetitorState.def` resolves it like one of the founding eight.
struct CustomLabSpec: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case spinout, sovereign, startup

        var label: String {
            switch self {
            case .spinout: "Spin-out"
            case .sovereign: "National lab"
            case .startup: "Startup"
            }
        }
    }

    var id: String
    var kind: Kind
    var name: String
    var color: UInt32
    var symbol: String
    var archetype: String
    var hq: String
    var ceo: String
    var founded: YM
    var firstModel: YM
    /// Capability ramp: offset from the world frontier at each year (log10 effective compute).
    var rampYears: [Double]
    var rampOffsets: [Double]
    var cadenceMonths: Double
    var priceMult: Double
    var tps: Double
    var brand: Double
    var openWeights: Bool
    var codeBonus: Double
    /// Share of industry compute the lab is built to run once it's established.
    var computeShare: Double
    var prefix: String
    var nextVersion: Double
    var chatProduct: String
    /// The lab its founders came from ("player" for yours, empty for none).
    @D var parentID: String = ""
    @D var parentName: String = ""
    /// Lead investor, or the state behind a national lab.
    @D var backer: String = ""
    /// The founding idea, in a few words.
    @D var thesis: String = ""
    @D var signature: String = ""
    /// RivalPlay raw value → how naturally the lab runs that play (0–1).
    @D var personality: [String: Double] = [:]
    @D var bills: [String] = []
    @D var reasoning: Double = 0
    @D var agent: Double = 0
    @D var chat: Double = 0
    @D var lang: Double = 0
    @D var longctx: Double = 0
    @D var vis: Double = 0
    @D var safety: Double = 0
    @D var noAudio: Bool = false
    /// Effective-compute edge from its methods (log10): how much less raw compute it needs per unit of capability.
    @D var efficiency: Double = 0
    /// A national lab's monthly state budget when it was founded (it grows every year).
    @D var stateBudget: Double = 0
    /// Headcount multiplier: below 1 for lean labs.
    @D var culture: Double = 0
    /// What caused it (e.g. the news item about your researcher leaving), so it's founded once.
    @D var origin: String = ""
    /// Where it trains, for the rumour mill.
    @D var site: String = ""

    var def: CompetitorDef {
        CompetitorDef(id: id, name: name, color: color, symbol: symbol, archetype: archetype, founded: founded, firstModel: firstModel,
                      hq: hq, ceo: ceo, offsets: Array(zip(rampYears, rampOffsets)), cadenceMonths: cadenceMonths, priceMult: priceMult,
                      tps: tps, brand: brand, openWeights: openWeights, codeBonus: codeBonus, computeShare: computeShare, releases: [],
                      prefix: prefix, nextVersion: nextVersion, chatProduct: chatProduct)
    }

    var trait: LabTrait {
        LabTrait(signature: signature, reasoning: reasoning, agent: agent, chat: chat, lang: lang, longctx: longctx, vis: vis,
                 safety: safety, audio: !noAudio)
    }

    var leanness: Double { culture > 0 ? culture : 1 }
}

// MARK: - Names

enum NameBank {
    static let first = ["Ava", "Noah", "Mei", "Arjun", "Sofia", "Kenji", "Amara", "Lucas", "Priya", "Mateo", "Yuki", "Fatima",
                        "Elias", "Chloe", "Omar", "Ingrid", "Ravi", "Hana", "Diego", "Zara", "Tomás", "Lena", "Kwame", "Aisha",
                        "Jonas", "Mila", "Wei", "Nadia", "Felix", "Aaliyah", "Sven", "Leila", "Hugo", "Ana", "Daniel", "Freya",
                        "Ibrahim", "Sakura", "Mikkel", "Isabel", "Tariq", "Nora", "Chen", "Ruth", "Emeka", "Jun", "Clara", "Pavel",
                        "Ayesha", "Theo", "Lior", "Rosa", "Magnus", "Esi", "Dmitri", "Linnea", "Kai", "Anaya", "Bruno", "Ines"]
    static let last = ["Chen", "Okafor", "Nakamura", "Patel", "Rossi", "Andersen", "Kim", "Silva", "Müller", "Haddad", "Ivanova",
                       "Nguyen", "Garcia", "Mensah", "Larsen", "Kowalski", "Sato", "Banerjee", "O'Brien", "Novak", "Fischer",
                       "Rahman", "Dubois", "Jensen", "Park", "Costa", "Hughes", "Moreau", "Tanaka", "Ali", "Schmidt", "Kaur",
                       "Petrov", "Lindqvist", "Adeyemi", "Zhang", "Murphy", "Castillo", "Weber", "Hoffmann", "Yilmaz", "Abe",
                       "Søndergaard", "Varga", "Ortiz", "Friedman", "Mbeki", "Lopez", "Sharma", "Svensson"]

    static let clients = ["Northwind Bank", "Helix Pharma", "Atlas Insurance", "Pioneer Retail", "Blue Harbor Shipping",
                          "Meridian Legal", "Quantum Telecom", "Summit Airlines", "Cobalt Energy", "Vertex Robotics",
                          "Lumen Media", "Orchid Health", "Granite Public Services", "Polaris Automotive", "Evergreen Foods",
                          "Silverline Securities", "Aurora Education", "Redwood Manufacturing", "Tidewater Utilities",
                          "Harborview City Council", "Crescent Capital", "Nimbus Games", "Sable Semiconductors", "Ironclad Logistics",
                          "Beacon Hospitals", "Starling Payments", "Juniper Biotech", "Waypoint Travel", "Foundry Software",
                          "Alpine Reinsurance", "Coral Hotels", "Monarch Consulting", "Prism Advertising", "Oakridge University",
                          "Keystone Defense Systems", "Halo Customer Care", "Riverbend County", "Zenith Accounting"]

    static let investors = ["Andromeda Ventures", "Sequel Capital", "Lightpath Partners", "Kestrel Growth", "Benchmark Hill",
                            "Orbit Fund", "Founders Forge", "Greylock Harbor", "Vision Mega Fund", "Falcon Sovereign Fund",
                            "Nimbus Cloud (strategic)", "Tidal Wave Capital", "Index Peak", "Thrive Northern", "General Atlas"]
}
