import Foundation

// MARK: - 3.5: semiconductors — the industry's reference data (process nodes, foundries, suppliers, fab sites, customers)

/// A manufacturing process. Costs are for a 300 mm wafer and a full mask set, in the year the node opens; later wafers get
/// cheaper as the node matures.
struct ProcessNode: Identifiable, Sendable {
    let id: String
    let name: String
    /// When the first foundry opens it to customers (risk production).
    let launch: Double
    let waferPrice: Double
    /// One full mask set plus the first wafer lots: the tape-out bill.
    let maskCost: Double
    /// Design months for a 300-engineer team at standard verification (architecture to tape-out).
    let designMonths: Double
    /// EDA licences and bought-in IP (SerDes, HBM PHY, …) per month of design.
    let ipMonth: Double
    /// Days from tape-out to first chips back.
    let fabDays: Double
    /// Defect density (defects/cm²) the node settles at once mature.
    let d0: Double
    /// Logic density vs 7 nm.
    let density: Double
    /// Power per unit of compute vs 7 nm.
    let power: Double
    /// Chance first silicon needs a respin (lean team, first try, before experience and verification).
    let respin: Double
    /// Building your own fab: dollars per wafer-a-month of capacity, MW and m³ of water a day per 1,000 wafers a month.
    let fabPerWafer: Double
    let fabMW: Double
    let fabWater: Double
    /// 3.9: dense BF16 TFLOPS per mm² of logic the best GPU maker's design on this node reaches (architecture 1.0):
    /// what a chip taped out here can do, whenever it ships. Each node's tensor cores, low-precision formats and
    /// clocks come with it, so it rises much faster than density.
    let tfmm: Double

    var short: String { name.components(separatedBy: " ").first ?? name }
}

/// A die configuration: one monolithic die, or chiplets on a big interposer.
struct DieOption: Identifiable, Sendable {
    let id: String
    let name: String
    /// Area of one die (mm²) and dies per chip.
    let area: Double
    let dies: Int
    /// Packaging slots one chip uses (bigger interposers take more of the line).
    let slots: Double
    /// Compute lost to die-to-die links.
    let overhead: Double
    let from: Double
    let blurb: String

    var siliconArea: Double { area * Double(dies) * (1 - overhead) }
}

struct Foundry: Identifiable, Sendable {
    let id: String
    let name: String
    let region: Region
    let place: String
    /// Years after a node's launch before this foundry offers it.
    let lag: Double
    let priceFactor: Double
    /// Defect density vs the node's best.
    let d0Factor: Double
    /// Your possible share of its capacity at a node (relative).
    let capFactor: Double
    let leadDays: Double
    /// Earthquake exposure (0–1).
    let quake: Double
    let blurb: String
}

struct Supplier: Identifiable, Sendable {
    let id: String
    let name: String
    /// "pack" or "hbm".
    let kind: String
    let region: Region
    let priceFactor: Double
    let capFactor: Double
    /// Packaging: share of chips that survive assembly. HBM: share of stacks that pass.
    let yield: Double
    let from: Double
    let leadDays: Double
    let blurb: String
}

struct FabSite: Identifiable, Sendable {
    let id: String
    let name: String
    let region: Region
    /// $/kWh industrial power.
    let power: Double
    /// Water stress (0–1): droughts hit fabs here.
    let water: Double
    let quake: Double
    /// Share of the build paid by government incentives.
    let subsidy: Double
    /// Construction time multiplier (>1 slower).
    let buildFactor: Double
    let blurb: String
}

struct ChipCustomer: Identifiable, Sendable {
    let id: String
    let name: String
    /// "cloud", "sovereign" or "enterprise".
    let kind: String
    let region: Region
    let weight: Double
}

enum SemiCatalog {
    static let nodes: [ProcessNode] = [
        ProcessNode(id: "n16", name: "16 nm FinFET", launch: 2015.5, waferPrice: 6_000, maskCost: 8e6, designMonths: 14, ipMonth: 0.8e6, fabDays: 70,
                    d0: 0.07, density: 0.35, power: 2.2, respin: 0.22, fabPerWafer: 250_000, fabMW: 3, fabWater: 700, tfmm: 0.12),
        ProcessNode(id: "n7", name: "7 nm FinFET", launch: 2018.5, waferPrice: 9_500, maskCost: 25e6, designMonths: 16, ipMonth: 1.8e6, fabDays: 80,
                    d0: 0.08, density: 1.0, power: 1.0, respin: 0.26, fabPerWafer: 400_000, fabMW: 4, fabWater: 800, tfmm: 0.38),
        ProcessNode(id: "n5", name: "5 nm FinFET", launch: 2020.6, waferPrice: 16_000, maskCost: 40e6, designMonths: 18, ipMonth: 3e6, fabDays: 90,
                    d0: 0.08, density: 1.8, power: 0.75, respin: 0.3, fabPerWafer: 500_000, fabMW: 5, fabWater: 850, tfmm: 1.4),
        ProcessNode(id: "n3", name: "3 nm FinFET", launch: 2022.9, waferPrice: 20_000, maskCost: 60e6, designMonths: 20, ipMonth: 4.5e6, fabDays: 100,
                    d0: 0.09, density: 2.9, power: 0.6, respin: 0.34, fabPerWafer: 600_000, fabMW: 6, fabWater: 900, tfmm: 4.5),
        ProcessNode(id: "n2", name: "2 nm gate-all-around", launch: 2025.8, waferPrice: 30_000, maskCost: 90e6, designMonths: 22, ipMonth: 6e6, fabDays: 110,
                    d0: 0.1, density: 3.9, power: 0.5, respin: 0.38, fabPerWafer: 750_000, fabMW: 7, fabWater: 950, tfmm: 7.5),
        ProcessNode(id: "a16", name: "A16-class (1.6 nm, backside power)", launch: 2026.9, waferPrice: 40_000, maskCost: 120e6, designMonths: 24, ipMonth: 8e6, fabDays: 115,
                    d0: 0.11, density: 4.6, power: 0.42, respin: 0.42, fabPerWafer: 900_000, fabMW: 8, fabWater: 1_000, tfmm: 11),
        ProcessNode(id: "a14", name: "A14-class (1.4 nm)", launch: 2028.6, waferPrice: 50_000, maskCost: 160e6, designMonths: 26, ipMonth: 10e6, fabDays: 120,
                    d0: 0.12, density: 6.0, power: 0.36, respin: 0.45, fabPerWafer: 1_100_000, fabMW: 9, fabWater: 1_050, tfmm: 20),
        ProcessNode(id: "a10", name: "A10-class (1 nm)", launch: 2031.0, waferPrice: 65_000, maskCost: 220e6, designMonths: 28, ipMonth: 13e6, fabDays: 125,
                    d0: 0.13, density: 8.0, power: 0.3, respin: 0.48, fabPerWafer: 1_400_000, fabMW: 10, fabWater: 1_100, tfmm: 37),
    ]
    static let nodeByID: [String: ProcessNode] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    static func node(_ id: String) -> ProcessNode { nodeByID[id] ?? nodes[1] }

    static let dies: [DieOption] = [
        DieOption(id: "mid", name: "Mid-size die (450 mm²)", area: 450, dies: 1, slots: 1, overhead: 0, from: 2015,
                  blurb: "Cheap and high-yielding; modest performance. A sensible first chip."),
        DieOption(id: "large", name: "Large die (650 mm²)", area: 650, dies: 1, slots: 1, overhead: 0, from: 2015,
                  blurb: "More compute per chip, noticeably worse yields on a young node."),
        DieOption(id: "reticle", name: "Reticle-limit die (820 mm²)", area: 820, dies: 1, slots: 1.1, overhead: 0, from: 2015,
                  blurb: "As big as a lithography scanner can print. Every defect lands on something expensive."),
        DieOption(id: "dual", name: "Two chiplets (2 × 650 mm²)", area: 650, dies: 2, slots: 1.6, overhead: 0.08, from: 2021,
                  blurb: "Two dies stitched on one interposer: big-chip performance with mid-chip yields, but it eats packaging capacity."),
        DieOption(id: "quad", name: "Four chiplets (4 × 450 mm²)", area: 450, dies: 4, slots: 2.4, overhead: 0.12, from: 2025,
                  blurb: "A rack-scale part on one package. Yields stay good; packaging becomes the whole game."),
    ]
    static let dieByID: [String: DieOption] = Dictionary(uniqueKeysWithValues: dies.map { ($0.id, $0) })
    static func die(_ id: String) -> DieOption { dieByID[id] ?? dies[0] }

    static let stackChoices = [4, 6, 8, 12]

    static let foundries: [Foundry] = [
        Foundry(id: "fsw", name: "Formosa Silicon Works", region: .japanKorea, place: "Hsinchu, Taiwan", lag: 0, priceFactor: 1.0, d0Factor: 1.0, capFactor: 1.0,
                leadDays: 150, quake: 0.8, blurb: "The leading edge. Best yields, first to every node — and everyone wants its wafers."),
        Foundry(id: "hanseong", name: "Hanseong Foundry", region: .japanKorea, place: "Pyeongtaek, Korea", lag: 0.6, priceFactor: 0.88, d0Factor: 1.35, capFactor: 1.3,
                leadDays: 100, quake: 0.15, blurb: "Close behind on nodes and keen for customers: cheaper wafers and room to grow, weaker yields."),
        Foundry(id: "columbia", name: "Columbia Fab Alliance", region: .us, place: "Phoenix, Arizona", lag: 1.5, priceFactor: 1.25, d0Factor: 1.15, capFactor: 0.7,
                leadDays: 120, quake: 0.05, blurb: "Onshore capacity. Pricier and a node behind, but safe from earthquakes and strait politics."),
        Foundry(id: "pearl", name: "Pearl River Semiconductor", region: .china, place: "Shanghai, China", lag: 3.2, priceFactor: 0.7, d0Factor: 1.6, capFactor: 1.6,
                leadDays: 75, quake: 0.05, blurb: "Cheap, plentiful and well behind the frontier. Export rules can freeze it overnight."),
    ]
    static let foundryByID: [String: Foundry] = Dictionary(uniqueKeysWithValues: foundries.map { ($0.id, $0) })

    static let suppliers: [Supplier] = [
        Supplier(id: "fsw_pack", name: "Formosa Advanced Packaging", kind: "pack", region: .japanKorea, priceFactor: 1.0, capFactor: 1.0, yield: 0.98, from: 2015, leadDays: 120,
                 blurb: "The foundry's own 2.5D interposer lines (the CoWoS-class kind). Best assembly yield, longest queue."),
        Supplier(id: "pacific_pack", name: "Pacific Assembly & Test", kind: "pack", region: .japanKorea, priceFactor: 0.8, capFactor: 1.4, yield: 0.95, from: 2020, leadDays: 90,
                 blurb: "An outsourced assembly house that learned interposers late. Cheaper, more capacity, a few more scrapped packages."),
        Supplier(id: "columbia_pack", name: "Columbia Packaging", kind: "pack", region: .us, priceFactor: 1.2, capFactor: 0.8, yield: 0.97, from: 2025, leadDays: 110,
                 blurb: "Onshore advanced packaging next to the Arizona fabs."),
        Supplier(id: "hanseong_mem", name: "Hanseong Memory", kind: "hbm", region: .japanKorea, priceFactor: 1.05, capFactor: 1.0, yield: 0.99, from: 2015, leadDays: 120,
                 blurb: "The HBM leader: first to every generation, sold out a year ahead."),
        Supplier(id: "kumgang_mem", name: "Kumgang Memory", kind: "hbm", region: .japanKorea, priceFactor: 0.97, capFactor: 0.9, yield: 0.95, from: 2016, leadDays: 100,
                 blurb: "Huge DRAM capacity, patchier HBM qualification."),
        Supplier(id: "snake_mem", name: "Snake River Memory", kind: "hbm", region: .us, priceFactor: 1.0, capFactor: 0.5, yield: 0.97, from: 2020, leadDays: 110,
                 blurb: "The American memory maker: smaller HBM volumes, steady quality."),
    ]
    static let supplierByID: [String: Supplier] = Dictionary(uniqueKeysWithValues: suppliers.map { ($0.id, $0) })

    static let sites: [FabSite] = [
        FabSite(id: "phoenix", name: "Phoenix, Arizona", region: .us, power: 0.075, water: 0.8, quake: 0.05, subsidy: 0.25, buildFactor: 1.1,
                blurb: "Cheap land, onshoring grants and a desert's worth of water worries."),
        FabSite(id: "ohio", name: "Columbus, Ohio", region: .us, power: 0.08, water: 0.2, quake: 0.02, subsidy: 0.2, buildFactor: 1.2,
                blurb: "Plenty of water and grid; building a leading-edge ecosystem from scratch is slow."),
        FabSite(id: "dresden", name: "Dresden, Saxony", region: .eu, power: 0.14, water: 0.2, quake: 0.02, subsidy: 0.35, buildFactor: 1.15,
                blurb: "Europe's chip valley: generous subsidies, expensive power."),
        FabSite(id: "kumamoto", name: "Kumamoto, Japan", region: .japanKorea, power: 0.15, water: 0.1, quake: 0.5, subsidy: 0.4, buildFactor: 0.85,
                blurb: "Fast construction, deep subsidies and spring water — on an earthquake fault."),
        FabSite(id: "tainan", name: "Tainan, Taiwan", region: .japanKorea, power: 0.09, water: 0.6, quake: 0.8, subsidy: 0.05, buildFactor: 0.8,
                blurb: "The world's best fab workforce and supply base. Droughts and earthquakes come with it."),
        FabSite(id: "pyeongtaek", name: "Pyeongtaek, Korea", region: .japanKorea, power: 0.1, water: 0.4, quake: 0.1, subsidy: 0.1, buildFactor: 0.9,
                blurb: "A memory-and-logic cluster with fast builders."),
    ]
    static let siteByID: [String: FabSite] = Dictionary(uniqueKeysWithValues: sites.map { ($0.id, $0) })

    static let fabSizes: [Double] = [10_000, 20_000, 40_000, 80_000]
    static let packLineSizes: [Double] = [5_000, 10_000, 20_000]

    static let customers: [ChipCustomer] = [
        ChipCustomer(id: "nimbus", name: "Nimbus Cloud", kind: "cloud", region: .us, weight: 0.22),
        ChipCustomer(id: "stratus", name: "Stratus Compute", kind: "cloud", region: .us, weight: 0.17),
        ChipCustomer(id: "atlas", name: "Atlas Neocloud", kind: "cloud", region: .us, weight: 0.11),
        ChipCustomer(id: "northwind", name: "Northwind Telecom", kind: "cloud", region: .eu, weight: 0.07),
        ChipCustomer(id: "meridian", name: "Meridian Sovereign AI", kind: "sovereign", region: .gulf, weight: 0.08),
        ChipCustomer(id: "kestrel", name: "Kestrel National Compute", kind: "sovereign", region: .india, weight: 0.05),
        ChipCustomer(id: "nordlys", name: "Nordlys AI Commons", kind: "sovereign", region: .eu, weight: 0.04),
        ChipCustomer(id: "jade", name: "Jade Harbor Cloud", kind: "cloud", region: .china, weight: 0.08),
        ChipCustomer(id: "helios", name: "Helios Robotics", kind: "enterprise", region: .us, weight: 0.08),
        ChipCustomer(id: "quill", name: "Quill Systems", kind: "enterprise", region: .japanKorea, weight: 0.05),
    ]
    static let customerByID: [String: ChipCustomer] = Dictionary(uniqueKeysWithValues: customers.map { ($0.id, $0) })

    static let codenames = ["Basalt", "Cinder", "Drift", "Fathom", "Gale", "Halo", "Iris", "Kite", "Loom", "Mosaic", "Nebula", "Onyx", "Prism", "Quartz", "Rook", "Sable"]
    static let binNames = ["Ultra", "Standard", "Lite"]
}
