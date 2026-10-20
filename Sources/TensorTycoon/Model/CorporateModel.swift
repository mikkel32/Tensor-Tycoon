import Foundation

// MARK: - 3.5: corporate — subsidiaries, corporate debt, ratings, shareholder returns and the books (Corporate)

/// The kinds of business a subsidiary can be. Each has its own market, margins, people costs and valuation multiple.
enum SubsidiaryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case robotics, bio, chipDesign, consumerApps, consulting, cloud, regional
    // 3.8: each also works on your own business (Corporate.powerFactor, attackFactor, bidBoost)
    case energy, securitySoftware, govResearch
    var id: String { rawValue }

    var title: String {
        switch self {
        case .robotics: "Robotics"
        case .bio: "Drug discovery"
        case .chipDesign: "Chip design"
        case .consumerApps: "Consumer apps"
        case .consulting: "Enterprise consulting"
        case .cloud: "Cloud arm"
        case .regional: "Regional entity"
        case .energy: "Energy developer"
        case .securitySoftware: "Security software"
        case .govResearch: "Government research"
        }
    }

    var symbol: String {
        switch self {
        case .robotics: "gearshape.2.fill"
        case .bio: "cross.vial.fill"
        case .chipDesign: "memorychip.fill"
        case .consumerApps: "apps.iphone"
        case .consulting: "briefcase.fill"
        case .cloud: "cloud.fill"
        case .regional: "globe.europe.africa.fill"
        case .energy: "bolt.fill"
        case .securitySoftware: "lock.shield.fill"
        case .govResearch: "building.columns.fill"
        }
    }

    var blurb: String {
        switch self {
        case .robotics: "Puts your models in arms, carts and humanoids. Hardware margins and long sales cycles, but a huge market later on."
        case .bio: "Licenses your models into drug discovery: milestone payments from pharma partners. High margins, slower growth."
        case .chipDesign: "Designs accelerators and IP blocks for other companies. Expensive engineers, good margins once it has customers."
        case .consumerApps: "Builds apps on top of your models: writing, photos, tutoring, companions. Fast growth, fickle users."
        case .consulting: "Deploys AI inside big companies. People-heavy and low-multiple, but profitable early — and it brings you enterprise leads."
        case .cloud: "Rents GPUs to everyone else. Thin margins and big revenue; valued like infrastructure, not software."
        case .regional: "Sells your models in another country under local management. Pays you a licence fee — where profit lands decides the tax."
        case .energy: "Builds solar, wind and storage and sells the power under long contracts — including to your own datacenters, below the grid price. Capital-heavy, thin margins."
        case .securitySoftware: "Sells AI-native security: threat detection, code audits, red-teaming. What it builds also hardens your own stack, so attacks that get past your defences succeed less often."
        case .govResearch: "A separate research arm that does applied work for public agencies. Its people and record raise your odds on government programmes in its region."
        }
    }

    /// First year you can start or buy one.
    var minYear: Double {
        switch self {
        case .robotics, .consulting, .cloud, .regional, .energy, .govResearch: 2016
        case .bio, .chipDesign, .securitySoftware: 2018
        case .consumerApps: 2019
        }
    }

    /// Annual market the subsidiary sells into (USD), worldwide.
    func market(_ y: Double) -> Double {
        let pts: [(Double, Double)]
        switch self {
        case .robotics: pts = [(2016, 2e9), (2022, 8e9), (2026, 3e10), (2030, 1.5e11), (2036, 6e11)]
        case .bio: pts = [(2016, 5e8), (2022, 2e9), (2026, 8e9), (2030, 4e10), (2036, 1.2e11)]
        case .chipDesign: pts = [(2016, 1e9), (2022, 5e9), (2026, 3e10), (2030, 8e10), (2036, 2e11)]
        case .consumerApps: pts = [(2016, 1e9), (2022, 5e9), (2026, 6e10), (2030, 2e11), (2036, 5e11)]
        case .consulting: pts = [(2016, 5e9), (2022, 2e10), (2026, 1e11), (2030, 3e11), (2036, 6e11)]
        case .cloud: pts = [(2016, 2e9), (2022, 1e10), (2026, 8e10), (2030, 2.5e11), (2036, 6e11)]
        case .regional: pts = [(2016, 1.5e7), (2022.5, 7e8), (2024.5, 1.2e10), (2026.5, 1.5e11), (2030.5, 1.1e12), (2036, 2.8e12)]
        case .energy: pts = [(2016, 3e9), (2022, 1e10), (2026, 6e10), (2030, 2e11), (2036, 5e11)]
        case .securitySoftware: pts = [(2016, 5e8), (2022, 3e9), (2026, 2e10), (2030, 8e10), (2036, 2e11)]
        case .govResearch: pts = [(2016, 1e9), (2022, 4e9), (2026, 1.5e10), (2030, 5e10), (2036, 1.2e11)]
        }
        return interpolateLog(pts, at: y, extrapolate: true)
    }

    /// The most of its market one subsidiary can win.
    var maxShare: Double {
        switch self {
        case .regional: 0.05   // of the world AI market: the country's slice, scaled by the jurisdiction's weight
        case .cloud, .consulting, .govResearch: 0.12
        case .energy: 0.08
        default: 0.2
        }
    }

    /// Revenue per employee per year at 2022 prices.
    var revenuePerHead: Double {
        switch self {
        case .robotics: 650_000
        case .bio: 700_000
        case .chipDesign: 900_000
        case .consumerApps: 1_500_000
        case .consulting: 450_000
        case .cloud: 3_000_000
        case .regional: 1_200_000
        case .energy: 2_500_000
        case .securitySoftware: 600_000
        case .govResearch: 400_000
        }
    }

    /// Fully loaded pay per employee per year at 2022 prices (before local salary levels).
    var payPerHead: Double {
        switch self {
        case .robotics: 260_000
        case .bio: 240_000
        case .chipDesign: 300_000
        case .consumerApps: 200_000
        case .consulting: 200_000
        case .cloud: 250_000
        case .regional: 180_000
        case .energy: 220_000
        case .securitySoftware: 260_000
        case .govResearch: 230_000
        }
    }

    /// The role whose market pay sets how this business's salaries move with the years.
    var payRole: Role {
        switch self {
        case .robotics, .consumerApps: .mlEngineer
        case .bio: .data
        case .chipDesign: .chipDesigner
        case .consulting, .regional: .sales
        case .cloud, .energy, .securitySoftware: .infra
        case .govResearch: .researcher
        }
    }

    /// Gross margin before people costs (what's left after compute, hardware, materials).
    var grossMargin: Double {
        switch self {
        case .robotics: 0.70
        case .bio: 0.80
        case .chipDesign: 0.70
        case .consumerApps: 0.60
        case .consulting: 0.90
        case .cloud: 0.45
        case .regional: 0.80
        case .energy: 0.35
        case .securitySoftware: 0.80
        case .govResearch: 0.85
        }
    }

    /// Monthly growth at a middle strategy with a frontier model and an average CEO.
    var growth: Double {
        switch self {
        case .consumerApps: 0.08
        case .robotics, .cloud, .regional, .securitySoftware: 0.06
        case .govResearch: 0.04
        default: 0.05
        }
    }

    /// How much the subsidiary's results depend on how good your models are (0–1).
    var modelDependence: Double {
        switch self {
        case .consumerApps, .regional: 0.9
        case .robotics, .bio: 0.6
        case .consulting, .securitySoftware, .govResearch: 0.5
        case .chipDesign, .cloud, .energy: 0.2
        }
    }

    /// EV / revenue multiple at a 25× AI-lab market (scaled with the era's multiples).
    var multiple: Double {
        switch self {
        case .robotics: 7
        case .bio: 9
        case .chipDesign: 8
        case .consumerApps: 6
        case .consulting: 2.5
        case .cloud: 4
        case .regional: 6
        case .energy: 3.5
        case .securitySoftware: 9
        case .govResearch: 3
        }
    }

    /// People a new subsidiary starts with.
    var baseTeam: Int {
        switch self {
        case .robotics: 25
        case .bio: 20
        case .chipDesign: 30
        case .consumerApps: 15
        case .consulting: 20
        case .cloud: 15
        case .regional: 12
        case .energy: 20
        case .securitySoftware: 20
        case .govResearch: 25
        }
    }

    /// Up-front spend beyond people (labs, robots, tape-outs, a first GPU cluster), at 2022 prices.
    var setupCost: Double {
        switch self {
        case .robotics: 2e7
        case .bio: 8e6
        case .chipDesign: 3e7
        case .consumerApps: 2e6
        case .consulting: 1e6
        case .cloud: 5e7
        case .regional: 3e6
        case .energy: 6e7
        case .securitySoftware: 5e6
        case .govResearch: 4e6
        }
    }

    /// Licence fee a new subsidiary pays you for your models, as a share of its revenue.
    var defaultTransfer: Double {
        switch self {
        case .cloud, .chipDesign, .energy: 0.05
        case .regional: 0.25
        case .govResearch: 0.10
        default: 0.15
        }
    }

    /// Name suffixes for subsidiaries you start, and names for startups you can buy.
    var suffix: String {
        switch self {
        case .robotics: "Robotics"
        case .bio: "Bio"
        case .chipDesign: "Silicon"
        case .consumerApps: "Apps"
        case .consulting: "Consulting"
        case .cloud: "Cloud"
        case .regional: ""
        case .energy: "Energy"
        case .securitySoftware: "Security"
        case .govResearch: "Public Research"
        }
    }

    var startupNames: [String] {
        switch self {
        case .robotics: ["Servo Foundry", "Kinetic Forge", "Gripworks", "Stride Dynamics", "Torque & Reason", "Ambulate Labs"]
        case .bio: ["Helix Atlas", "Fold Therapeutics", "Ligand Loop", "Cellwise", "Protean Bio", "Assay Mind"]
        case .chipDesign: ["Systolic Semi", "Tensorwave Silicon", "Lattice Arc", "Photon Mesh", "Gatewright", "Dataflow Devices"]
        case .consumerApps: ["Pocket Muse", "Quillful", "Studybird", "Snapsense", "Hearthbot", "Lumen Notes"]
        case .consulting: ["Northgate Applied AI", "Ledgerline Advisory", "Keystone Automation", "Pillar Partners", "Rubric & Co", "Bridgewise"]
        case .cloud: ["Coreweft", "Racklight", "Kilowatt Cloud", "Spotfleet", "Hyperrack", "Tensor Harbor"]
        case .regional: ["Atlas Local", "Meridian AI", "Northstar Data", "Harbor Intelligence", "Crossroads AI", "Lantern Systems"]
        case .energy: ["Gridline Power", "Voltaic Fields", "Baseload Partners", "Kestrel Renewables", "Amp & Anchor", "Northwind Storage"]
        case .securitySoftware: ["Bastion Logic", "Redline Labs", "Sentinel Mesh", "Vaultline", "Watchtower AI", "Canary Systems"]
        case .govResearch: ["Civic Compute", "Meridian Applied Research", "Statecraft Labs", "Pillar Federal", "Agora Research", "Commonwealth AI"]
        }
    }
}

/// Where a subsidiary is incorporated: its tax, pay levels and (for a regional entity) the size of its market.
struct Jurisdiction: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let flag: String
    let tax: Double
    let salary: Double
    let employerCost: Double
    /// Share of the world AI market this country buys (regional entities sell into it).
    let market: Double
}

enum SubStatus: String, Codable, Sendable, DefaultValue {
    case active, folded, spunOff, sold, closed
    static var defaultValue: SubStatus { .active }

    var title: String {
        switch self {
        case .active: "Active"
        case .folded: "Folded in"
        case .spunOff: "Spun off"
        case .sold: "Sold"
        case .closed: "Wound down"
        }
    }
}

/// One month of a subsidiary's results.
struct SubMonth: Codable, Hashable {
    var month: Date
    var revenue: Double
    /// Costs before the licence fee and tax.
    var costs: Double
    var license: Double
    var tax: Double
    var cash: Double
    var headcount: Int
    var valuation: Double
    var profit: Double { revenue - costs - license - tax }
}

/// Someone else who owns part of a subsidiary.
struct SubHolder: Codable, Hashable {
    var name: String
    var stake: Double
}

struct Subsidiary: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var kind: SubsidiaryKind
    /// Jurisdiction ID (Corporate.jurisdictions).
    var country: String
    var founded: Date
    var ceo: String
    /// 0–100.
    var ceoSkill: Double
    /// Your share of it (0–1). The rest belongs to `holders`.
    var stake: Double = 1
    @D var holders: [SubHolder] = []
    /// What you've put in, net of what you've taken out (for gains on sales).
    @D var basis: Double = 0
    @D var cash: Double = 0
    @D var headcount: Int = 0
    /// 0 = run for cash, 1 = all-out growth.
    var strategy: Double = 0.5
    /// Licence fee for your models, as a share of its revenue (the transfer price).
    var transferRate: Double = 0.15
    /// Last month's revenue.
    @D var revenue: Double = 0
    @D var valuation: Double = 0
    @D var isPublic: Bool = false
    @D var listed: Date? = nil
    @D var status: SubStatus = .active
    @D var statusDate: Date? = nil
    @D var acquired: Bool = false
    @D var history: [SubMonth] = []
    /// One month's revenue hit after a CEO change.
    @D var shake: Double = 0

    var live: Bool { status == .active || status == .folded }
    var separate: Bool { status == .active }
    var last: SubMonth? { history.last }
}

enum CorpDebtKind: String, Codable, CaseIterable, Identifiable, Sendable {
    // 3.8: stable code names. Saves from before wrote the display names, which `init(from:)` still reads.
    case termLoan, convertible, greenBond
    var id: String { rawValue }

    var title: String {
        switch self {
        case .termLoan: "Covenanted term loan"
        case .convertible: "Convertible note"
        case .greenBond: "Green bond"
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        if let k = CorpDebtKind(rawValue: raw) {
            self = k
        } else if let k = CorpDebtKind.allCases.first(where: { $0.title == raw }) {
            self = k
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unknown corporate debt kind \(raw)")
        }
    }

    var symbol: String {
        switch self {
        case .termLoan: "building.columns.fill"
        case .convertible: "arrow.triangle.swap"
        case .greenBond: "leaf.fill"
        }
    }
}

struct CorpDebt: Codable, Identifiable, Hashable {
    var id = StableID.next()
    var kind: CorpDebtKind
    var principal: Double
    var balance: Double
    /// Coupon, percent a year.
    var rate: Double
    var termMonths: Int
    var monthsLeft: Int
    var taken: Date
    /// Covenants (0 = none): debt ÷ EBITDA at most, EBITDA ÷ interest at least, cash at least.
    @D var maxLeverage: Double = 0
    @D var minCoverage: Double = 0
    @D var minCash: Double = 0
    /// Convertible notes: price per share they convert at.
    @D var conversionPrice: Double = 0
    /// Covenants aren't tested until this date (a waiver).
    @D var waiverUntil: Date? = nil
    /// Extra interest after a breach (percentage points).
    @D var penalty: Double = 0
    /// Covenant breaches so far (shown with the debt; lenders remember).
    @D var breaches: Int = 0
    /// 3.8: months in a row the covenants held; six clean ones lift a penalty rate.
    @D var cleanMonths: Int = 0
    /// The rating notch its coupon is priced at: the notch when it was taken, moved each time a term loan re-prices.
    @D var notch: Int = 0

    var amortizing: Bool { kind == .termLoan }
    var covenanted: Bool { maxLeverage > 0 || minCoverage > 0 || minCash > 0 }
}

/// What moved this month that the month record doesn't keep (for the cash-flow statement).
struct CorpFlow: Codable, Hashable, DefaultValue {
    static var defaultValue: CorpFlow { CorpFlow() }
    @D var dividends: Double = 0
    @D var buybacks: Double = 0
    /// Cash you put into subsidiaries (start-ups, injections, buy-outs, acquisitions).
    @D var subInvested: Double = 0
    /// Cash from selling subsidiary stakes.
    @D var subProceeds: Double = 0
    @D var debtIn: Double = 0
    @D var debtRepaid: Double = 0
    /// Notes that turned into shares (debt that left without cash).
    @D var converted: Double = 0
}

/// Month-end snapshot of the balance sheet and the flows behind the cash-flow statement.
struct CorpMonth: Codable, Hashable, Identifiable {
    var id: Date { month }
    var month: Date
    @D var cash: Double = 0
    @D var credits: Double = 0
    /// Owned accelerators (book value: cost less depreciation, plus chips paid for and still in transit).
    @D var hardware: Double = 0
    /// Datacenters at book value (cost less depreciation).
    @D var sites: Double = 0
    /// Rival-lab stakes, and subsidiaries you don't control, at market value.
    @D var investments: Double = 0
    /// Subsidiaries you control (over 50%): their cash, consolidated.
    @D var subsCash: Double = 0
    /// Your share of what the subsidiaries you control are worth beyond their cash (so a stake that crosses 50% keeps
    /// its value on the books instead of jumping between market value and cash).
    @D var subsValue: Double = 0
    /// The outside shareholders' part of the subsidiaries you control.
    @D var minorityInterest: Double = 0
    @D var debt: Double = 0
    @D var equityRaised: Double = 0
    @D var flow: CorpFlow = CorpFlow()
    @D var capex: Double = 0
    /// Subsidiaries you control: revenue, costs (before the licence fee), tax and licence fees paid to you.
    @D var subRevenue: Double = 0
    @D var subCosts: Double = 0
    @D var subTax: Double = 0
    @D var intercompany: Double = 0
    /// The outside shareholders' part of those subsidiaries' net income.
    @D var minority: Double = 0
    /// Your share of the net income of subsidiaries you don't control.
    @D var associates: Double = 0
    /// Rating notch at month end (nil, or −1 in older saves, when not rated).
    @D var rating: Int? = nil

    /// The rating notch, or −1 when the company wasn't rated that month.
    var notch: Int { (rating ?? -1) >= 0 ? rating! : -1 }
}

/// Your company group: subsidiaries, corporate debt, the credit rating, dividends and buybacks, and the books.
struct CorporateState: Codable, DefaultValue {
    static var defaultValue: CorporateState { CorporateState() }
    @D var subs: [Subsidiary] = []
    @D var debts: [CorpDebt] = []
    /// 3.8: one-time save fixes already applied (covenant cycle, lease deposits).
    @D var fixes: Set<String> = []
    /// Rating notch (Corporate.ratings index; nil, or −1 in older saves, = not rated yet). Read and write `notch`.
    @D var rating: Int? = nil
    /// Quarterly dividend, in total.
    @D var dividendQuarterly: Double = 0
    @D var lastBuyback: Date? = nil
    /// Shares bought back in the last couple of years.
    @D var buybacks: [ShareIssue] = []
    @D var lastTender: Date? = nil
    @D var flow: CorpFlow = CorpFlow()
    @D var months: [CorpMonth] = []
    @D var counter: Int = 0
    /// Acquisition targets already bought (or passed over for good).
    @D var bought: Set<String> = []
    /// Set the first time you use any of it: until then the monthly pass only takes a snapshot.
    @D var engaged: Bool = false
    @D var dividendsPaid: Double = 0
    @D var buybacksSpent: Double = 0
    @D var interestPaid: Double = 0
    @D var auditsSettled: Double = 0
    /// What happened, newest first.
    @D var log: [String] = []
    // 3.8: the books
    /// Tax losses carried forward: a loss-making month adds to it, later profit is taxed only once it's used up.
    @D var lossPool: Double = 0
    /// Site ID → depreciation charged so far on a datacenter's shell (straight line over 20 years).
    @D var siteDepreciation: [String: Double] = [:]
    /// The last time raising the dividend moved the share price (once a quarter).
    @D var lastDividendBump: Date? = nil
    /// The economy's cycle: crises under way and the bubble meter (Crises).
    @D var cycle: CycleState = CycleState()
    /// Demand (a day's revenue) your go-to-market couldn't book today (Commercial.reach); 0 when it took everything.
    @D var unbookedToday: Double = 0

    /// The rating notch (Corporate.ratings index), or −1 when not rated yet.
    var notch: Int {
        get { (rating ?? -1) >= 0 ? rating! : -1 }
        set { rating = newValue >= 0 ? newValue : nil }
    }
}

// MARK: - 3.8: the economy's cycle (Crises)

enum CrisisKind: String, Codable, CaseIterable, Sendable {
    /// AI valuations break after a run of froth: multiples and marks fall, rounds shrink, hype (and demand) drops.
    case correction
    /// Lenders pull back: spreads widen, banks and bond buyers stop quoting all but the strongest credits.
    case crunch
    /// The policy rate jumps: debt costs more, cash earns more, long-dated growth is worth less.
    case rateShock

    var title: String {
        switch self {
        case .correction: "AI-bubble correction"
        case .crunch: "Credit crunch"
        case .rateShock: "Rate shock"
        }
    }

    var symbol: String {
        switch self {
        case .correction: "chart.line.downtrend.xyaxis"
        case .crunch: "lock.fill"
        case .rateShock: "percent"
        }
    }
}

/// One crisis: when it started and ends, how hard it hit (0–1) and why it happened.
struct Crisis: Codable, Hashable, Identifiable {
    var id = StableID.next()
    var kind: CrisisKind
    var start: Date
    var end: Date
    /// 0–1: scales every effect.
    var severity: Double
    /// What set it off, in a sentence.
    var cause: String
    /// Scripted from real history (2020, 2022) rather than rolled.
    @D var historical: Bool = false
}

/// The economy's cycle: crises under way, the ones that have passed and the bubble meter.
struct CycleState: Codable, Hashable, DefaultValue {
    static var defaultValue: CycleState { CycleState() }
    @D var active: [Crisis] = []
    /// Crises that have ended, newest first.
    @D var past: [Crisis] = []
    /// 0–100: how frothy AI valuations are (Crises.bubble), updated each month.
    @D var bubble: Double = 0
    /// Historical crises already played (so a reload never replays them).
    @D var scripted: Set<String> = []
}
