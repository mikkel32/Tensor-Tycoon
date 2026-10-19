import Foundation

// MARK: - 3.5: semiconductors — saved state
//
// Your own merchant-grade accelerators: design teams, designs taped out at process nodes, wafer bookings at foundries,
// your own fabs, advanced-packaging and HBM contracts, supply shocks, big customer orders and what you sold to whom.
// Everything here is empty until you hire a design team or book capacity (Semis).

struct SemiState: Codable, Hashable, DefaultValue {
    static var defaultValue: SemiState { SemiState() }

    /// Keys the industry's hashed rolls to this game (set once, from the RNG's state, without drawing from it).
    @D var salt: String = ""
    /// You've hired a team or booked capacity: the industry sends news, shocks and orders from then on.
    @D var engaged: Bool = false
    @D var teams: [SemiTeam] = []
    @D var designs: [SemiDesign] = []
    @D var bookings: [WaferBooking] = []
    @D var fabs: [SemiFab] = []
    /// Advanced-packaging (2.5D interposer) and HBM supply contracts, and your own packaging lines.
    @D var supply: [SupplyContract] = []
    /// HBM stacks delivered but not yet put on a package.
    @D var hbmStock: Double = 0
    @D var shocks: [SupplyShock] = []
    @D var contracts: [ChipContract] = []
    /// Share of every chip you make that goes to your own stock (the rest is for customers).
    @D var keepShare: Double = 0.5
    /// Rival labs may buy your chips on the open market.
    @D var allowRivals: Bool = false
    /// Sovereign funds may buy (export rules permitting).
    @D var allowSovereigns: Bool = true
    /// What happened, newest first (capped).
    @D var log: [SemiEvent] = []
    /// This month's books, and the last 24 months.
    @D var month: SemiMonth = SemiMonth()
    @D var history: [SemiMonth] = []
    /// Lifetime chips sold to customers, and penalties that hurt your reputation as a supplier.
    @D var shipped: Double = 0
    @D var repHit: Double = 0
    /// Customer ID → chips bought, lifetime.
    @D var buyers: [String: Double] = [:]
    /// Foundry ID → wafers bought, lifetime (relationships raise how much they'll give you).
    @D var foundryWafers: [String: Double] = [:]
    @D var counter: Int = 0

    var isEmpty: Bool { teams.isEmpty && designs.isEmpty && bookings.isEmpty && fabs.isEmpty && supply.isEmpty }
}

/// A chip design team. Bigger teams design faster; every tape-out they finish makes the next one safer.
struct SemiTeam: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var name: String
    var engineers: Int
    /// Tape-outs this team has taken to production.
    @D var experience: Int = 0
    var hired: Date
}

enum SemiPhase: Int, Codable, CaseIterable {
    case architecture, rtl, physical, tapeout, bringup, production, retired

    var title: String {
        switch self {
        case .architecture: "Architecture"
        case .rtl: "RTL & verification"
        case .physical: "Physical design"
        case .tapeout: "Tape-out"
        case .bringup: "First silicon bring-up"
        case .production: "In production"
        case .retired: "Retired"
        }
    }

    var detail: String {
        switch self {
        case .architecture: "Deciding what the chip is: compute units, memory system, interconnect. Mostly people and simulators."
        case .rtl: "Writing the hardware description and verifying it. Most bugs are caught (or missed) here — verification depth sets your respin odds."
        case .physical: "Placing and routing billions of transistors, timing closure, power grids. EDA licences get expensive at new nodes."
        case .tapeout: "The mask set is made and the first wafers go through the fab. Masks are paid up front."
        case .bringup: "First chips are powered on and tested. This is where a respin is discovered — or not."
        case .production: "Qualified: wafers you book become chips."
        case .retired: "No longer made."
        }
    }
}

/// One chip design, from architecture to volume production.
struct SemiDesign: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var name: String
    var generation: Int
    var node: String
    var die: String
    var stacks: Int
    var focus: ChipFocus
    /// 0 lean, 1 standard, 2 thorough.
    var verification: Int
    var teamID: UUID?
    /// A port of an earlier design (faster and safer, a smaller step up).
    @D var derivedFrom: String = ""
    var started: Date
    var phaseRaw: Int = 0
    var phaseDaysLeft: Double = 0
    var phaseDays: Double = 0
    /// Days a phase is stuck waiting (no team, node not open yet).
    @D var waiting: String = ""
    @D var spent: Double = 0
    @D var respins: Int = 0
    @D var metalFixes: Int = 0
    /// Respin odds when bring-up started, and the roll that decided it (shown on the timeline).
    @D var respinOdds: Double = 0
    @D var lastRoll: Double = -1
    /// A respin decision is waiting in the inbox.
    @D var bugOpen: Bool = false
    /// Shipped with an erratum (performance cut).
    @D var erratum: Bool = false
    /// Architecture quality, locked in at tape-out.
    @D var arch: Double = 0
    /// Chip IDs for the three bins (Ultra, Standard, Lite) once qualified.
    @D var chipIDs: [String] = []
    @D var qualified: Date? = nil
    // Production
    /// Wafers started, lifetime (the product's own defect learning).
    @D var wafersDone: Double = 0
    /// Good dies waiting for packaging, by bin.
    @D var dieBank: [Double] = [0, 0, 0]
    /// Finished chips: reserved for your fleet, and for customers, by bin.
    @D var stockMine: [Double] = [0, 0, 0]
    @D var stockSale: [Double] = [0, 0, 0]
    /// List price per bin, and whether each bin is on sale.
    @D var prices: [Double] = [0, 0, 0]
    @D var onSale: [Bool] = [false, false, false]
    @D var made: [Double] = [0, 0, 0]
    /// Chips finished this month and last month, by bin (what customers' orders are sized from).
    @D var monthMade: [Double] = [0, 0, 0]
    @D var lastMade: [Double] = [0, 0, 0]
    @D var sold: [Double] = [0, 0, 0]
    @D var taken: [Double] = [0, 0, 0]
    @D var revenue: Double = 0
    /// Production spend attributed to this product (wafers, packaging, HBM), lifetime.
    @D var cost: Double = 0
    @D var timeline: [SemiEvent] = []

    var phase: SemiPhase { SemiPhase(rawValue: phaseRaw) ?? .architecture }
    var inProduction: Bool { phase == .production }
}

/// Wafer capacity booked at a foundry (take-or-pay).
struct WaferBooking: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var foundry: String
    var node: String
    var wafersMonth: Double
    /// Locked price per wafer.
    var price: Double
    var start: Date
    var end: Date
    /// The product these wafers go to.
    var designID: UUID?

    func active(_ d: Date) -> Bool { start <= d && d < end }
}

/// Your own fab.
struct SemiFab: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var name: String
    var site: String
    var node: String
    /// Wafer starts a month at full ramp.
    var wafersMonth: Double
    var buildCost: Double
    var started: Date
    var opens: Date
    /// Build cost still to pay (spread over construction).
    @D var unpaid: Double = 0
    @D var wafersDone: Double = 0
    var designID: UUID?
    /// Share of the fab's wafers that go to that product; the rest are sold to other chipmakers.
    @D var productShare: Double = 1
    /// Last month's wafers sold to other chipmakers (spare capacity).
    @D var foundryRevenue: Double = 0

    func open(_ d: Date) -> Bool { opens <= d }
}

/// Advanced packaging or HBM supply: a contract with a supplier, or your own packaging line.
struct SupplyContract: Codable, Identifiable, Hashable {
    var id = StableID.next()
    /// "pack" or "hbm".
    var kind: String
    var supplier: String
    /// Packaging slots or HBM stacks a month.
    var units: Double
    var price: Double
    var start: Date
    var end: Date
    /// Your own packaging line (no end; paid as built).
    @D var own: Bool = false
    @D var buildCost: Double = 0
    /// Your own line: build cost still to pay before it opens.
    @D var unpaid: Double = 0

    func active(_ d: Date) -> Bool { start <= d && (own || d < end) }
}

/// A world supply-chain event cutting capacity for a while.
struct SupplyShock: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var kind: String
    var title: String
    var body: String
    var start: Date
    var end: Date
    /// Capacity left (0–1) for wafers, packaging and HBM, and which foundry (or "" for everyone).
    var wafers: Double = 1
    var packaging: Double = 1
    var hbm: Double = 1
    var foundry: String = ""
    /// Own fabs at water-stressed sites.
    @D var drought: Double = 1
    /// You paid to re-route around it.
    @D var mitigated: Bool = false
    /// Export rules: sales to China blocked, Gulf halved.
    @D var export: Bool = false

    func active(_ d: Date) -> Bool { start <= d && d < end }
}

/// A big customer order you accepted: delivered from customer stock before spot sales.
struct ChipContract: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var customer: String
    var designID: UUID
    var bin: Int
    var units: Double
    @D var delivered: Double = 0
    var price: Double
    var signed: Date
    var deadline: Date
    /// Share of the undelivered value paid if it's late.
    var penalty: Double = 0.15
    @D var closed: Bool = false

    var remaining: Double { max(0, units - delivered) }
}

struct SemiEvent: Codable, Hashable {
    var date: Date
    var text: String
    /// 1 good, 0 neutral, −1 bad.
    var tone: Int = 0
}

/// One month of the semiconductor business.
struct SemiMonth: Codable, Hashable, DefaultValue {
    static var defaultValue: SemiMonth { SemiMonth() }

    @D var month: Date? = nil
    @D var wafers: Double = 0
    @D var goodDies: Double = 0
    @D var chips: Double = 0
    @D var sold: Double = 0
    @D var taken: Double = 0
    @D var toRivals: Double = 0
    @D var revenue: Double = 0
    @D var foundryRevenue: Double = 0
    @D var wafersCost: Double = 0
    @D var packCost: Double = 0
    @D var hbmCost: Double = 0
    @D var teamCost: Double = 0
    @D var designCost: Double = 0
    @D var fabCost: Double = 0
    @D var penalties: Double = 0
    /// Days this month output was held back by packaging slots, by HBM, or ran out of dies (wafers).
    @D var packDays: Int = 0
    @D var hbmDays: Int = 0
    @D var waferDays: Int = 0

    var costs: Double { wafersCost + packCost + hbmCost + teamCost + designCost + fabCost + penalties }

    /// What held output back most this month ("wafers", "packaging", "HBM" or "" when nothing is in production).
    var bottleneck: String {
        let m = max(packDays, hbmDays, waferDays)
        if m == 0 { return "" }
        if m == packDays { return "packaging" }
        if m == hbmDays { return "HBM" }
        return "wafers"
    }
}
