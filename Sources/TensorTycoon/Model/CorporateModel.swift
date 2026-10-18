import Foundation

// MARK: - 3.5: corporate — subsidiaries, corporate debt, ratings, shareholder returns and the books (Corporate)

/// The kinds of business a subsidiary can be. Each has its own market, margins, people costs and valuation multiple.
enum SubsidiaryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case robotics, bio, chipDesign, consumerApps, consulting, cloud, regional
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
        }
    }

    /// First year you can start or buy one.
    var minYear: Double {
        switch self {
        case .robotics, .consulting, .cloud, .regional: 2016
        case .bio, .chipDesign: 2018
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
        }
        return interpolateLog(pts, at: y, extrapolate: true)
    }

    /// The most of its market one subsidiary can win.
    var maxShare: Double {
        switch self {
        case .regional: 0.05   // of the world AI market: the country's slice, scaled by the jurisdiction's weight
        case .cloud, .consulting: 0.12
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
        }
    }

    /// The role whose market pay sets how this business's salaries move with the years.
    var payRole: Role {
        switch self {
        case .robotics, .consumerApps: .mlEngineer
        case .bio: .data
        case .chipDesign: .chipDesigner
        case .consulting, .regional: .sales
        case .cloud: .infra
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
        }
    }

    /// Monthly growth at a middle strategy with a frontier model and an average CEO.
    var growth: Double {
        switch self {
        case .consumerApps: 0.08
        case .robotics, .cloud, .regional: 0.06
        default: 0.05
        }
    }

    /// How much the subsidiary's results depend on how good your models are (0–1).
    var modelDependence: Double {
        switch self {
        case .consumerApps, .regional: 0.9
        case .robotics, .bio: 0.6
        case .consulting: 0.5
        case .chipDesign, .cloud: 0.2
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
        }
    }

    /// Licence fee a new subsidiary pays you for your models, as a share of its revenue.
    var defaultTransfer: Double {
        switch self {
        case .cloud, .chipDesign: 0.05
        case .regional: 0.25
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

enum SubStatus: String, Codable, Sendable {
    case active, folded, spunOff, sold, closed

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
    var holders: [SubHolder] = []
    /// What you've put in, net of what you've taken out (for gains on sales).
    var basis: Double = 0
    var cash: Double = 0
    var headcount: Int = 0
    /// 0 = run for cash, 1 = all-out growth.
    var strategy: Double = 0.5
    /// Licence fee for your models, as a share of its revenue (the transfer price).
    var transferRate: Double = 0.15
    /// Last month's revenue.
    var revenue: Double = 0
    var valuation: Double = 0
    var isPublic = false
    var listed: Date? = nil
    var status: SubStatus = .active
    var statusDate: Date? = nil
    var acquired = false
    var history: [SubMonth] = []
    /// One month's revenue hit after a CEO change.
    var shake: Double = 0

    var live: Bool { status == .active || status == .folded }
    var separate: Bool { status == .active }
    var last: SubMonth? { history.last }
}

enum CorpDebtKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case termLoan = "Covenanted term loan"
    case convertible = "Convertible note"
    case greenBond = "Green bond"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .termLoan: "building.columns.fill"
        case .convertible: "arrow.triangle.swap"
        case .greenBond: "leaf.fill"
        }
    }
}

struct CorpDebt: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: CorpDebtKind
    var principal: Double
    var balance: Double
    /// Coupon, percent a year.
    var rate: Double
    var termMonths: Int
    var monthsLeft: Int
    var taken: Date
    /// Covenants (0 = none): debt ÷ EBITDA at most, EBITDA ÷ interest at least, cash at least.
    var maxLeverage: Double = 0
    var minCoverage: Double = 0
    var minCash: Double = 0
    /// Convertible notes: price per share they convert at.
    var conversionPrice: Double = 0
    /// Covenants aren't tested until this date (a waiver).
    var waiverUntil: Date? = nil
    /// Extra interest after a breach (percentage points).
    var penalty: Double = 0
    var breaches = 0
    /// Rating notch when it was taken (term loans re-price with the rating).
    var notch = 3

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
    var cash: Double = 0
    var credits: Double = 0
    var hardware: Double = 0
    var sites: Double = 0
    /// Rival-lab stakes, and subsidiaries you don't control, at market value.
    var investments: Double = 0
    /// Subsidiaries you control (over 50%): their cash, consolidated.
    var subsCash: Double = 0
    /// The outside shareholders' part of the subsidiaries you control.
    var minorityInterest: Double = 0
    var debt: Double = 0
    var equityRaised: Double = 0
    var flow = CorpFlow()
    var capex: Double = 0
    /// Subsidiaries you control: revenue, costs (before the licence fee), tax and licence fees paid to you.
    var subRevenue: Double = 0
    var subCosts: Double = 0
    var subTax: Double = 0
    var intercompany: Double = 0
    /// The outside shareholders' part of those subsidiaries' net income.
    var minority: Double = 0
    /// Your share of the net income of subsidiaries you don't control.
    var associates: Double = 0
    var rating: Int = -1
}

/// Your company group: subsidiaries, corporate debt, the credit rating, dividends and buybacks, and the books.
struct CorporateState: Codable, DefaultValue {
    static var defaultValue: CorporateState { CorporateState() }
    @D var subs: [Subsidiary] = []
    @D var debts: [CorpDebt] = []
    /// Rating notch (Corporate.ratings index; -1 = not rated yet).
    @D var rating: Int = -1
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
}
