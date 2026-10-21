import Foundation

// MARK: - 3.9: Government contract marketplace — buyers, competitions and budget calendars
//
// Small, unclassified public money a young lab can actually win: small-business innovation awards, prototype
// agreements, task orders on a multiple-award contract, compute allocations on public supercomputers, EU calls and
// national innovation grants. Agencies are fictional analogues (as in AgencyCatalog); sizes, windows, evaluation times
// and success rates follow the real programmes they stand in for (game estimates where the real figure varies).

/// Who may bid.
enum GovEligibility: Sendable {
    /// Labs headquartered in this country.
    case country(String)
    /// Labs headquartered in this region.
    case region(Region)
    /// Labs from the agency's region or an allied one (US, UK, EU, Japan/Korea).
    case allied
    /// Holders of a seat on the agency's multiple-award contract.
    case vehicle
}

/// What winning gives you.
enum GovPayout: Sendable {
    /// A programme Advanced Projects runs (staff, stages, milestone payments).
    case programme
    /// GPU hours on a public machine (cloud credits).
    case compute
    /// A seat on a multiple-award contract.
    case seat
}

/// A kind of competition.
struct GovKindDef: Sendable {
    let id: String
    /// Title by year (programme names changed: SME Instrument → EIC Accelerator, XSEDE-era allocations → the national research resource).
    let titles: [(Double, String)]
    let issuers: [String]
    let from: Double
    var until: Double = 9999
    let eligibility: GovEligibility
    /// Small companies only (US: under 500 staff; EU: under 250).
    var smallOnly: Int = 0
    /// Award size range by year (dollars): (year, low, high).
    let value: [(Double, Double, Double)]
    /// Bigger labs get bigger lots (prototype work and task orders, not statutory awards).
    var scalesWithLab = false
    let months: ClosedRange<Int>
    let baseRate: Double
    /// Days the solicitation is open, and from close to decision.
    let window: Int
    let evaluation: Int
    /// Bid-and-proposal cost at a standard effort (2019 dollars).
    let bp: Double
    /// Days to write it: light, standard, full.
    let days: [Int]
    let type: ContractType
    let ip: IPTerms
    let basis: EvaluationBasis
    let payout: GovPayout
    let template: String
    /// Postings per issuer per half-month (before budget-calendar effects).
    var rate: Double = 0.12
    /// Closes on fixed cut-off months instead of a rolling window.
    var cutoffs: [Int] = []
    /// Invite-only (follow-ons): never posted on the open market.
    var invite = false
    /// A "new start" that a continuing resolution holds up.
    var newStart = true
    /// Notices first: the agency publishes a sources-sought notice a few weeks before the solicitation.
    var notice = false
    /// Staff the work needs (role, count).
    let staff: [(Role, Int)]
    let blurb: String
    /// What the evaluators score, in the agency's words.
    let criteria: String
    /// How a loss can be challenged: "protest", "review" (EU evaluation review), "complaint" (national appeals board) or "".
    var challenge: String = "protest"

    func title(_ y: Double) -> String { titles.last(where: { $0.0 <= y })?.1 ?? titles[0].1 }
    func active(_ y: Double) -> Bool { y >= from && y < until }
}

enum GovMarketCatalog {
    // MARK: Agencies

    /// Buyers of small work that Advanced Projects doesn't list (it only looks these up by ID).
    static let agencies: [AgencyDef] = [
        AgencyDef(id: "nfse", name: "National Foundation for Science & Engineering", short: "NFSE", region: .us, kind: .research, symbol: "graduationcap.fill",
                  budget: 0.5, blurb: "Funds basic research and runs the small-business innovation programme for civilian science; from 2024 also the pilot national AI research resource."),
        AgencyDef(id: "dciu", name: "Defense Commercial Innovation Unit", short: "DCIU", region: .us, kind: .defence, symbol: "bolt.shield.fill",
                  budget: 0.25, blurb: "Buys commercial technology for the armed forces through fast prototype agreements: a five-page solution brief, a pitch, an award in about 60 days."),
        AgencyDef(id: "fasa", name: "Federal Acquisition Services Administration", short: "FASA", region: .us, kind: .digital, symbol: "doc.text.fill",
                  budget: 0.6, blurb: "Runs government-wide contract vehicles. Win a seat on its AI & data services contract and civilian agencies compete task orders among the holders only."),
        AgencyDef(id: "eiab", name: "European Innovation Accelerator Board", short: "EIAB", region: .eu, kind: .industry, symbol: "arrow.up.forward.circle.fill",
                  budget: 0.35, blurb: "Grants of up to €2.5M for start-ups and SMEs with breakthrough technology. Three stages and a jury interview; about one application in fifteen is funded."),
        AgencyDef(id: "ereo", name: "European Research Executive Office", short: "EREO", region: .eu, kind: .research, symbol: "eurosign.circle.fill",
                  budget: 0.6, blurb: "Runs the framework programme's collaborative calls: consortia of universities and companies, three-year projects, a fixed deadline and an evaluation five months later."),
        AgencyDef(id: "esu", name: "European Supercomputing Undertaking", short: "ESU", region: .eu, kind: .research, symbol: "cpu.fill",
                  budget: 0.3, blurb: "Allocates time on Europe's public supercomputers to researchers and, from 2025, to AI start-ups through its AI Factory access calls."),
        AgencyDef(id: "dnif", name: "Danish National Innovation Fund", short: "DNIF", region: .eu, kind: .research, symbol: "lightbulb.fill",
                  budget: 0.12, blurb: "Denmark's public innovation fund: small Booster grants decided within two months, and larger Grand Solutions consortia once a year.", country: "dk"),
        AgencyDef(id: "ddma", name: "Danish Defence Materiel Agency", short: "DDMA", region: .eu, kind: .defence, symbol: "shield.fill",
                  budget: 0.1, blurb: "Buys equipment and services for the Danish armed forces, and from 2023 runs a defence innovation programme for Danish start-ups.", country: "dk"),
        AgencyDef(id: "afi", name: "Agence Française pour l'Innovation", short: "AFI", region: .eu, kind: .industry, symbol: "sparkles",
                  budget: 0.3, blurb: "The French state's innovation bank: innovation contests, grants and repayable advances for start-ups.", country: "fr"),
        AgencyDef(id: "fnid", name: "Fondo Nazionale per l'Innovazione Digitale", short: "FNID", region: .eu, kind: .digital, symbol: "building.2.fill",
                  budget: 0.15, blurb: "Italy's digital innovation fund; from 2022 it also channels recovery-plan money into public-administration AI.", country: "it"),
        AgencyDef(id: "anfc", name: "Agenția Națională pentru Finanțarea Cercetării", short: "ANFC", region: .eu, kind: .research, symbol: "atom",
                  budget: 0.06, blurb: "Romania's research funding agency: national competitions for experimental-demonstrative projects. Small grants, slow evaluations.", country: "ro"),
    ]

    // MARK: Programme templates (how Advanced Projects runs a won award)

    static let templates: [ProgrammeTemplate] = [
        t("gm_sbir1", "Small-business innovation award, Phase I", "Show that the idea works on the agency's data in six to twelve months, and say what a Phase II would build.",
          months: 9, staff: [(.researcher, 0.6), (.mlEngineer, 0.4)], compute: 0.3, risk: 0.1, effects: [.rp(0.004)], image: "server_room",
          reward: "a past-performance record and an invitation to propose Phase II"),
        t("gm_sbir2", "Small-business innovation award, Phase II", "Build and test the prototype Phase I scoped, with the agency's users, over two years.",
          months: 24, staff: [(.mlEngineer, 0.5), (.researcher, 0.3), (.data, 0.2)], compute: 0.35, risk: 0.16, effects: [.rp(0.006), .enterpriseDemand(0.01)], image: "dc_rows",
          reward: "a fielded prototype, a stronger record and a path to production money"),
        t("gm_proto", "Prototype agreement", "Deliver a working prototype to a military unit under an other-transaction agreement: milestones, demos, no cost accounting.",
          months: 12, staff: [(.mlEngineer, 0.5), (.data, 0.25), (.infra, 0.25)], compute: 0.3, risk: 0.18, effects: [.enterpriseDemand(0.01)], image: "dc_rows",
          reward: "a defence customer and a shot at a sole-source production agreement"),
        t("gm_prod", "Follow-on production agreement", "Scale the prototype to the whole fleet: hardening, accreditation for unclassified networks, training and support.",
          months: 18, staff: [(.mlEngineer, 0.4), (.infra, 0.3), (.data, 0.15), (.sales, 0.15)], compute: 0.35, risk: 0.14, effects: [.enterpriseDemand(0.02)], image: "dc_hall",
          reward: "recurring government revenue and a reference customer"),
        t("gm_task", "Task order", "Deliver a defined piece of AI work for a civilian agency under the multiple-award contract's terms.",
          months: 9, staff: [(.mlEngineer, 0.5), (.data, 0.3), (.sales, 0.2)], compute: 0.25, risk: 0.12, effects: [.enterpriseDemand(0.008)], image: "server_room",
          reward: "billable work, a past-performance rating and the next order"),
        t("gm_eic", "Accelerator grant", "Take a breakthrough product from prototype to market readiness with EU grant money and its coaching.",
          months: 24, staff: [(.researcher, 0.4), (.mlEngineer, 0.4), (.sales, 0.2)], compute: 0.35, risk: 0.18, effects: [.rp(0.006), .enterpriseDemand(0.01)], image: "dc_rows",
          reward: "money you keep the rights to, and a European seal investors notice"),
        t("gm_horizon", "Collaborative research action", "Your work package in a three-year European consortium: research, open datasets, a pilot with public partners.",
          months: 36, staff: [(.researcher, 0.6), (.data, 0.4)], compute: 0.25, risk: 0.12, effects: [.rp(0.006)], image: "network",
          reward: "research, European partners and open results"),
        t("gm_grant", "National innovation grant", "A co-funded national project: build it, report on it, show the jobs and exports it brings.",
          months: 18, staff: [(.researcher, 0.5), (.mlEngineer, 0.5)], compute: 0.3, risk: 0.12, effects: [.rp(0.004)], image: "server_room",
          reward: "co-funding at home and standing with your government"),
    ]

    private static func t(_ id: String, _ title: String, _ objective: String, months: Int, staff: [(Role, Double)], compute: Double, risk: Double,
                          effects: [ResearchEffect], image: String, reward: String) -> ProgrammeTemplate {
        ProgrammeTemplate(id: id, title: title, agencies: [], year: 2016, objective: objective, domains: [], gap: 0, research: [], types: [.fixedPrice],
                          ip: [.licence], classification: 0, size: 0, months: months, staff: staff, computeShare: compute, risk: risk, basis: .bestValue,
                          effects: effects, unlock: nil, discovery: nil, field: nil, image: image, reward: reward, topic: "Small awards & grants")
    }

    // MARK: Competitions

    static let kinds: [GovKindDef] = [
        GovKindDef(id: "sbir1", titles: [(0, "Small-business innovation award, Phase I")], issuers: ["oadr", "nhri", "feso", "naoa", "ncra", "nfse"], from: 2016,
                   eligibility: .country("us"), smallOnly: 500, value: [(2016, 120_000, 150_000), (2019, 150_000, 225_000), (2023, 200_000, 275_000), (2030, 240_000, 330_000)],
                   months: 6...12, baseRate: 0.17, window: 30, evaluation: 90, bp: 14_000, days: [5, 12, 20], type: .fixedPrice, ip: .licence, basis: .technical,
                   payout: .programme, template: "gm_sbir1", rate: 0.11, newStart: false, notice: true, staff: [(.researcher, 1)],
                   blurb: "The set-aside every agency with an outside research budget must run. Small, fast, and the usual first government money for a start-up.",
                   criteria: "Technical merit and innovation, the team's qualifications, and the commercial potential."),
        GovKindDef(id: "sbir2", titles: [(0, "Small-business innovation award, Phase II")], issuers: [], from: 2016,
                   eligibility: .country("us"), smallOnly: 500, value: [(2016, 750_000, 1_000_000), (2019, 1_000_000, 1_500_000), (2023, 1_200_000, 1_850_000), (2030, 1_500_000, 2_300_000)],
                   months: 24...24, baseRate: 0.45, window: 45, evaluation: 120, bp: 35_000, days: [10, 20, 32], type: .fixedPrice, ip: .licence, basis: .technical,
                   payout: .programme, template: "gm_sbir2", invite: true, newStart: false, staff: [(.mlEngineer, 1), (.researcher, 1)],
                   blurb: "Invitation-only for Phase I performers: about half of invited Phase II proposals are funded.",
                   criteria: "Phase I results, technical merit, the team, and a credible plan to commercialise."),
        GovKindDef(id: "cso", titles: [(0, "Commercial solutions opening: prototype agreement")], issuers: ["dciu"], from: 2016,
                   eligibility: .allied, value: [(2016, 600_000, 2_500_000), (2022, 800_000, 4_000_000), (2030, 1_200_000, 6_000_000)], scalesWithLab: true,
                   months: 9...15, baseRate: 0.12, window: 21, evaluation: 60, bp: 18_000, days: [4, 9, 16], type: .fixedPrice, ip: .licence, basis: .bestValue,
                   payout: .programme, template: "gm_proto", rate: 0.22, staff: [(.mlEngineer, 2), (.data, 1)],
                   blurb: "A five-page solution brief, a pitch to the unit, and a prototype agreement in weeks rather than years. Allied companies may bid.",
                   criteria: "Relevance to the problem statement, technical maturity, and the company's viability."),
        GovKindDef(id: "prod", titles: [(0, "Follow-on production agreement")], issuers: [], from: 2016,
                   eligibility: .allied, value: [(2016, 2_500_000, 8_000_000), (2022, 3_500_000, 12_000_000), (2030, 5_000_000, 18_000_000)], scalesWithLab: true,
                   months: 18...18, baseRate: 0.7, window: 30, evaluation: 45, bp: 30_000, days: [6, 12, 20], type: .fixedPrice, ip: .licence, basis: .bestValue,
                   payout: .programme, template: "gm_prod", invite: true, staff: [(.mlEngineer, 2), (.infra, 1), (.data, 1), (.sales, 1)],
                   blurb: "A successful prototype can be followed by a sole-source production agreement without a new competition.",
                   criteria: "Prototype results, price reasonableness, and the plan to support the fleet."),
        GovKindDef(id: "onramp", titles: [(0, "On-ramp: AI & data services multiple-award contract")], issuers: ["fasa"], from: 2018,
                   eligibility: .country("us"), value: [(2016, 2_500, 2_500)], months: 60...60, baseRate: 0.4, window: 45, evaluation: 120, bp: 26_000,
                   days: [7, 14, 24], type: .fixedPrice, ip: .licence, basis: .technical, payout: .seat, template: "gm_task", rate: 0.05, cutoffs: [3, 9],
                   staff: [], blurb: "Win a seat and you can bid on task orders that only seat holders see. The guaranteed minimum is $2,500; the orders are the point.",
                   criteria: "Technical capability, relevant past performance (commercial projects count), and the labour-rate table."),
        GovKindDef(id: "task", titles: [(0, "Task order")], issuers: ["fasa"], from: 2018,
                   eligibility: .vehicle, value: [(2016, 300_000, 2_500_000), (2022, 400_000, 4_000_000), (2030, 600_000, 7_000_000)], scalesWithLab: true,
                   months: 6...18, baseRate: 0.3, window: 14, evaluation: 30, bp: 9_000, days: [3, 7, 12], type: .fixedPrice, ip: .government, basis: .bestValue,
                   payout: .programme, template: "gm_task", rate: 0.35, newStart: false, staff: [(.mlEngineer, 1), (.data, 1)],
                   blurb: "Competed among the seat holders only (fair opportunity): usually three or four bids, a decision in a month.",
                   criteria: "Technical approach, staffing plan, past performance on the vehicle, and price."),
        GovKindDef(id: "airr", titles: [(0, "Advanced computing allocation (open science)"), (2024, "National AI research resource allocation")], issuers: ["nfse", "feso"], from: 2016,
                   eligibility: .country("us"), value: [(2016, 40_000, 250_000), (2022, 80_000, 500_000), (2024, 150_000, 900_000), (2030, 300_000, 2_000_000)],
                   months: 12...12, baseRate: 0.45, window: 30, evaluation: 45, bp: 3_000, days: [2, 5, 9], type: .grant, ip: .shared, basis: .technical,
                   payout: .compute, template: "gm_grant", rate: 0.08, newStart: false, staff: [],
                   blurb: "GPU hours on public machines for open research. You publish what you learn.",
                   criteria: "Scientific merit, computational readiness (can you use the machine well), and open publication.", challenge: ""),
        GovKindDef(id: "hpc_eu", titles: [(0, "Tier-0 supercomputer project access call"), (2021, "EuroHPC access call"), (2025, "AI Factory access call for start-ups")], issuers: ["esu"], from: 2016,
                   eligibility: .region(.eu), value: [(2016, 60_000, 400_000), (2021, 120_000, 800_000), (2025, 250_000, 1_600_000), (2030, 500_000, 3_000_000)],
                   months: 12...12, baseRate: 0.4, window: 45, evaluation: 60, bp: 4_000, days: [2, 6, 10], type: .grant, ip: .shared, basis: .technical,
                   payout: .compute, template: "gm_grant", rate: 0.0, cutoffs: [2, 5, 9, 11], newStart: false, staff: [],
                   blurb: "Time on Europe's public supercomputers, free at the point of use, for work you publish.",
                   criteria: "Scientific and innovation merit, technical readiness, and the team's track record.", challenge: "review"),
        GovKindDef(id: "eic", titles: [(0, "SME Instrument, Phase 2"), (2021.2, "EIC Accelerator")], issuers: ["eiab"], from: 2016,
                   eligibility: .region(.eu), smallOnly: 250, value: [(2016, 600_000, 2_200_000), (2021, 700_000, 2_800_000), (2030, 900_000, 3_400_000)],
                   months: 18...24, baseRate: 0.065, window: 75, evaluation: 100, bp: 45_000, days: [10, 20, 34], type: .grant, ip: .licence, basis: .technical,
                   payout: .programme, template: "gm_eic", rate: 0.0, cutoffs: [1, 3, 6, 10], staff: [(.researcher, 1), (.mlEngineer, 1)],
                   blurb: "The EU's flagship start-up grant: written proposal, a full application and a jury interview in Brussels.",
                   criteria: "Excellence, impact and the level of risk, judged in writing and then by a jury.", challenge: "review"),
        GovKindDef(id: "horizon", titles: [(0, "Horizon 2020 research & innovation action"), (2021.4, "Horizon Europe research & innovation action")], issuers: ["ereo"], from: 2016,
                   eligibility: .region(.eu), value: [(2016, 300_000, 900_000), (2021, 350_000, 1_100_000), (2030, 450_000, 1_500_000)],
                   months: 36...36, baseRate: 0.14, window: 120, evaluation: 150, bp: 30_000, days: [10, 18, 30], type: .grant, ip: .shared, basis: .technical,
                   payout: .programme, template: "gm_horizon", rate: 0.0, cutoffs: [4, 9], staff: [(.researcher, 1)],
                   blurb: "Your share of a European consortium's three-year project. Fixed deadlines; the evaluation summary comes about five months later.",
                   criteria: "Excellence, impact and quality of implementation, each scored out of five (threshold 10 of 15).", challenge: "review"),
        GovKindDef(id: "dk_booster", titles: [(0, "InnoBooster grant")], issuers: ["dnif"], from: 2016,
                   eligibility: .country("dk"), smallOnly: 250, value: [(2016, 50_000, 450_000), (2022, 60_000, 700_000), (2030, 80_000, 900_000)],
                   months: 6...18, baseRate: 0.33, window: 50, evaluation: 60, bp: 7_000, days: [3, 7, 12], type: .grant, ip: .licence, basis: .bestValue,
                   payout: .programme, template: "gm_grant", rate: 0.2, newStart: false, staff: [(.researcher, 1)],
                   blurb: "Co-funds a third to two thirds of a small company's innovation project. Decided within about two months.",
                   criteria: "Innovation, market potential, and whether the team can carry it out.", challenge: "complaint"),
        GovKindDef(id: "dk_grand", titles: [(0, "Grand Solutions project")], issuers: ["dnif"], from: 2016,
                   eligibility: .country("dk"), value: [(2016, 700_000, 3_000_000), (2022, 900_000, 4_500_000), (2030, 1_200_000, 6_000_000)],
                   months: 30...42, baseRate: 0.12, window: 90, evaluation: 100, bp: 38_000, days: [12, 22, 35], type: .grant, ip: .shared, basis: .technical,
                   payout: .programme, template: "gm_horizon", rate: 0.0, cutoffs: [4], notice: true, staff: [(.researcher, 1), (.mlEngineer, 1)],
                   blurb: "Large Danish consortium projects with universities and industry; one call a year.",
                   criteria: "Excellence, impact for Denmark, and the consortium's ability to deliver.", challenge: "complaint"),
        GovKindDef(id: "dk_defence", titles: [(0, "Defence innovation call")], issuers: ["ddma"], from: 2022.8,
                   eligibility: .country("dk"), value: [(2022, 200_000, 1_200_000), (2030, 300_000, 2_000_000)], scalesWithLab: true,
                   months: 9...18, baseRate: 0.2, window: 40, evaluation: 75, bp: 12_000, days: [4, 9, 15], type: .fixedPrice, ip: .licence, basis: .bestValue,
                   payout: .programme, template: "gm_proto", rate: 0.12, staff: [(.mlEngineer, 1), (.data, 1)],
                   blurb: "Since 2023 Danish defence has bought from start-ups through short innovation calls.",
                   criteria: "Military relevance, maturity, and the company's security of supply.", challenge: "complaint"),
        GovKindDef(id: "fr_rapid", titles: [(0, "Dual-use innovation grant (RAPID-style)")], issuers: ["dgpa"], from: 2016,
                   eligibility: .country("fr"), smallOnly: 2000, value: [(2016, 300_000, 1_300_000), (2030, 450_000, 2_000_000)],
                   months: 12...30, baseRate: 0.3, window: 60, evaluation: 90, bp: 14_000, days: [4, 10, 17], type: .grant, ip: .licence, basis: .bestValue,
                   payout: .programme, template: "gm_grant", rate: 0.12, newStart: false, staff: [(.researcher, 1), (.mlEngineer, 1)],
                   blurb: "France's defence ministry co-funds dual-use innovation by SMEs and mid-size firms.",
                   criteria: "Dual-use potential, innovation, and the industrial plan.", challenge: "complaint"),
        GovKindDef(id: "fr_inov", titles: [(0, "i-Nov innovation contest")], issuers: ["afi"], from: 2017,
                   eligibility: .country("fr"), smallOnly: 250, value: [(2016, 500_000, 3_000_000), (2030, 700_000, 4_500_000)],
                   months: 18...36, baseRate: 0.15, window: 75, evaluation: 110, bp: 28_000, days: [8, 16, 26], type: .grant, ip: .licence, basis: .technical,
                   payout: .programme, template: "gm_grant", rate: 0.0, cutoffs: [3, 10], staff: [(.researcher, 1), (.mlEngineer, 1)],
                   blurb: "Waves of a national innovation contest run with the ministries; winners get grants and repayable advances.",
                   criteria: "Innovation, market and the team, then a jury hearing.", challenge: "complaint"),
        GovKindDef(id: "it_call", titles: [(0, "National digital innovation call"), (2022, "Recovery-plan call: AI for public administration")], issuers: ["fnid"], from: 2016,
                   eligibility: .country("it"), value: [(2016, 200_000, 1_200_000), (2022, 300_000, 2_200_000), (2026.6, 200_000, 1_400_000)],
                   months: 12...24, baseRate: 0.2, window: 60, evaluation: 120, bp: 15_000, days: [5, 11, 18], type: .grant, ip: .licence, basis: .bestValue,
                   payout: .programme, template: "gm_grant", rate: 0.12, staff: [(.mlEngineer, 1), (.data, 1)],
                   blurb: "Italian calls for digital public services; from 2022 the recovery plan's money made them much larger until it ends in 2026.",
                   criteria: "Quality of the proposal, impact on public services, and the budget.", challenge: "complaint"),
        GovKindDef(id: "ro_ped", titles: [(0, "Experimental-demonstrative project")], issuers: ["anfc"], from: 2016,
                   eligibility: .country("ro"), value: [(2016, 100_000, 140_000), (2022, 120_000, 230_000), (2030, 160_000, 320_000)],
                   months: 24...24, baseRate: 0.12, window: 60, evaluation: 150, bp: 5_000, days: [4, 9, 15], type: .grant, ip: .licence, basis: .technical,
                   payout: .programme, template: "gm_grant", rate: 0.0, cutoffs: [3, 10], staff: [(.researcher, 1)],
                   blurb: "A Romanian national competition for turning research into a demonstrator: small, slow to evaluate, prestigious at home.",
                   criteria: "Scientific quality, the demonstrator's relevance, and the team.", challenge: "complaint"),
        GovKindDef(id: "edf_sme", titles: [(0, "European defence fund call for SMEs")], issuers: ["edif"], from: 2021.5,
                   eligibility: .region(.eu), smallOnly: 250, value: [(2021, 500_000, 3_500_000), (2030, 700_000, 5_000_000)],
                   months: 18...30, baseRate: 0.16, window: 100, evaluation: 140, bp: 30_000, days: [8, 16, 28], type: .grant, ip: .shared, basis: .bestValue,
                   payout: .programme, template: "gm_proto", rate: 0.0, cutoffs: [11], staff: [(.mlEngineer, 2), (.data, 1)],
                   blurb: "The EU defence fund's SME call: unclassified research for European defence, open to European companies only.",
                   criteria: "Excellence, contribution to European defence, and implementation.", challenge: "review"),
    ]

    static let byKind: [String: GovKindDef] = Dictionary(uniqueKeysWithValues: kinds.map { ($0.id, $0) })
    static func kind(_ id: String) -> GovKindDef? { byKind[id] }

    /// Agency for a task order's customer (civilian agencies on the vehicle).
    static let customers = ["a federal benefits agency", "the national weather service", "a tax-collection agency", "a records and archives agency",
                            "a federal statistics bureau", "the patent office", "a public-health agency", "a federal housing agency"]

    // MARK: Topics

    /// What each buyer is asking for (titles of the opportunities it posts).
    static let topics: [String: [String]] = [
        "oadr": ["Machine-learning maintenance forecasting for transport aircraft", "Low-shot object recognition for small drones", "Natural-language search over technical manuals",
                 "Synthetic data for rare sensor events", "Automated triage of logistics bottlenecks"],
        "nhri": ["Clinical-note summarisation with privacy guarantees", "Early sepsis warning from hospital records", "Radiology report error detection", "Protein–ligand binding prediction"],
        "feso": ["Surrogate models for battery electrolyte screening", "AI-assisted beamline alignment", "Grid load forecasting with weather ensembles", "Fault detection in wind-farm sensor data"],
        "naoa": ["Onboard anomaly detection for small satellites", "Autonomous scheduling for ground stations", "Crater and hazard mapping from orbital imagery"],
        "ncra": ["Phishing-campaign clustering with language models", "Automated patch triage for municipal networks", "Log anomaly detection for water utilities"],
        "nfse": ["Robust learning from limited labelled data", "Efficient fine-tuning on commodity GPUs", "Evaluation methods for language-model reasoning", "Energy-efficient training schedules"],
        "dciu": ["Predictive maintenance for the ground-vehicle fleet", "Document understanding for contract backlogs", "Multilingual speech-to-text for coalition exercises",
                 "Computer vision for base perimeter monitoring", "Logistics demand forecasting for depots"],
        "fasa": ["Claims-document classification", "Call-centre assistant pilot", "Forecast post-processing", "Records-request triage", "Survey-response coding", "Fraud-pattern detection"],
        "eiab": ["A domain-specific language model for European industry", "Energy-efficient inference for edge devices", "AI quality inspection for small manufacturers",
                 "Multilingual customer-service agents for SMEs"],
        "ereo": ["Trustworthy AI for public administrations", "Large-scale multilingual language resources", "AI for climate-adaptation services", "Robotics and AI for agile production",
                 "Explainable AI for medical imaging"],
        "esu": ["Training a mid-size open language model", "Fine-tuning and evaluation at scale", "Scientific foundation model pre-training", "Benchmark and development access"],
        "dnif": ["AI for district-heating optimisation", "Language models for Danish public-sector documents", "Machine vision for food-processing quality control",
                 "Wind-turbine blade damage detection", "Speech recognition for Danish dialects"],
        "ddma": ["Arctic maritime surveillance analytics", "Predictive maintenance for naval vessels", "Drone detection from acoustic sensors"],
        "dgpa": ["Drone-swarm coordination", "Secure speech recognition for field units", "Satellite-image change detection"],
        "afi": ["AI for nuclear plant maintenance", "Generative design for aerospace parts", "French-language assistants for public services"],
        "fnid": ["AI for public-administration document flows", "AI for cultural-heritage digitisation", "Italian-language assistants for municipalities"],
        "anfc": ["Romanian-language speech recognition", "AI for agricultural yield forecasting", "Anomaly detection in the power grid"],
        "edif": ["Resilient sensor fusion", "AI-enabled cyber situational awareness", "Autonomous logistics for military mobility"],
    ]

    /// Who wins when you don't: plausible small competitors (fictional) by region.
    static let competitors: [Region: [String]] = [
        .us: ["Ridgeline Analytics", "Blue Mesa AI", "Calder Systems", "a university spin-out from Pittsburgh", "Kestrel Labs", "Arlington Data Works", "Sable Point Technologies",
              "a Boston robotics start-up", "Northfork Intelligence", "Granite Peak Software"],
        .eu: ["Nordvind Robotics", "Brightwater Analytics", "Lumen Dynamics", "a Delft university spin-out", "Helix Vision", "Aurora Sprachtechnik", "Tessel AI",
              "a consortium led by a Munich institute", "Baltic Data Lab", "Ostrava Systems"],
    ]

    // MARK: Anchor contracts (the founding offer)

    struct AnchorOffer: Sendable {
        let agency: String
        let title: String
        let scope: String
        let defence: Bool
        /// Annual value in 2019 dollars for a small lab.
        let annual: Double
        let options: Int
        let staff: [(Role, Int)]
        let payment: AnchorPayment
        let pitch: String
    }

    /// Two offers per home country: a civilian research agreement and a defence or security one.
    static func anchorOffers(_ country: String, region: Region) -> [AnchorOffer] {
        switch country {
        case "us":
            return [AnchorOffer(agency: "nfse", title: "Cooperative agreement: national AI research testbed partner", scope: "Run benchmark studies and open baselines on the foundation's testbed, and train two cohorts of university users.",
                                defence: false, annual: 600_000, options: 2, staff: [(.researcher, 1), (.mlEngineer, 1)], payment: .invoice,
                                pitch: "A programme officer liked your founders' papers. The foundation funds a base year to the end of the fiscal year and two option years, invoiced monthly."),
                    AnchorOffer(agency: "dciu", title: "Prototype agreement: predictive maintenance for the ground-vehicle fleet", scope: "Forecast part failures from maintenance logs at two depots; quarterly demos to the unit.",
                                defence: true, annual: 1_400_000, options: 1, staff: [(.mlEngineer, 2), (.data, 1)], payment: .invoice,
                                pitch: "An army maintenance unit has money left in this fiscal year and a problem your models fit. A base period and one option year, invoiced monthly.")]
        case "dk":
            return [AnchorOffer(agency: "dnif", title: "Grand Solutions partner: AI for wind-turbine fault forecasting", scope: "Build fault-forecasting models with a turbine maker and two universities; open datasets at the end.",
                                defence: false, annual: 500_000, options: 2, staff: [(.researcher, 1), (.data, 1)], payment: .tranche,
                                pitch: "A consortium lost its machine-learning partner a month before signature. Three years, co-funded, paid in instalments: pre-financing now, interim payments at each yearly report."),
                    AnchorOffer(agency: "ddma", title: "Framework agreement: Arctic maritime surveillance analytics", scope: "Fuse ship transponder, radar and satellite data to flag unusual traffic around Greenland.",
                                defence: true, annual: 900_000, options: 2, staff: [(.mlEngineer, 2), (.data, 1)], payment: .invoice,
                                pitch: "Denmark is spending more on Arctic surveillance. A framework agreement for this budget year, renewable twice, invoiced monthly.")]
        case "fr":
            return [AnchorOffer(agency: "afi", title: "France innovation programme: AI for industrial maintenance", scope: "Predictive maintenance for three mid-size manufacturers; a public report each year.",
                                defence: false, annual: 550_000, options: 2, staff: [(.researcher, 1), (.mlEngineer, 1)], payment: .tranche,
                                pitch: "The innovation bank wants a French AI lab in its industry programme: three years, paid in instalments."),
                    AnchorOffer(agency: "dgpa", title: "Dual-use agreement: secure speech recognition for field units", scope: "On-device French and English speech recognition that never leaves the radio.",
                                defence: true, annual: 1_000_000, options: 1, staff: [(.mlEngineer, 2), (.researcher, 1)], payment: .invoice,
                                pitch: "The armament directorate funds a base year and one option, invoiced monthly.")]
        case "it":
            return [AnchorOffer(agency: "fnid", title: "Public-administration AI project: document flows for regions", scope: "Classify and route the paperwork of two regional administrations; a public pilot.",
                                defence: false, annual: 500_000, options: 2, staff: [(.mlEngineer, 1), (.data, 1)], payment: .tranche,
                                pitch: "Recovery-plan money must be committed this year. Three years, paid in instalments."),
                    AnchorOffer(agency: "edif", title: "European defence project partner: resilient sensor fusion", scope: "The machine-learning work package of an Italian-led defence research project.",
                                defence: true, annual: 800_000, options: 2, staff: [(.mlEngineer, 2), (.data, 1)], payment: .tranche,
                                pitch: "A consortium needs a European AI partner for an unclassified work package: three years, paid in instalments.")]
        case "ro":
            return [AnchorOffer(agency: "anfc", title: "Complex frontier research project: Romanian-language models", scope: "Open Romanian speech and text models with two universities.",
                                defence: false, annual: 300_000, options: 2, staff: [(.researcher, 1), (.data, 1)], payment: .tranche,
                                pitch: "The research agency's flagship competition funds three years, paid in instalments."),
                    AnchorOffer(agency: "ansd", title: "National cyber-defence analytics framework", scope: "Detect intrusions in public-sector networks from flow logs and alerts.",
                                defence: true, annual: 600_000, options: 2, staff: [(.mlEngineer, 1), (.data, 1)], payment: .invoice,
                                pitch: "The national cyber authority signs a framework for this budget year, renewable twice, invoiced monthly.")]
        default:
            return region == .us ? anchorOffers("us", region: .us) : anchorOffers("dk", region: .eu).map { o in
                AnchorOffer(agency: o.agency == "dnif" ? "ereo" : "edif", title: o.title, scope: o.scope, defence: o.defence, annual: o.annual, options: o.options,
                            staff: o.staff, payment: .tranche, pitch: o.pitch)
            }
        }
    }

    // MARK: Budget calendars

    /// A US fiscal year's appropriations, as it happened (FY2017–FY2026). Later years are drawn per game (GovMarket.usYear).
    struct USYear: Sendable {
        let fy: Int
        /// When regular appropriations were enacted (the continuing resolution ends) — nil: enacted before 1 October.
        let enacted: Date?
        /// Bills enacted on time (their agencies skip the continuing resolution and any lapse).
        var early: Set<String> = []
        /// Bills enacted later than `enacted`, and when.
        var late: (Set<String>, Date)? = nil
        /// Lapses in appropriations (shutdowns): start, end (first day funded again), bills affected (empty = all not yet enacted).
        var lapses: [(Date, Date)] = []
        /// A full-year continuing resolution: funded at last year's level, no new starts for the rest of the year.
        var fullYearCR = false
    }

    private static func d(_ y: Int, _ m: Int, _ day: Int) -> Date { GameCalendar.date(y, m, day) }

    static let usHistory: [USYear] = [
        USYear(fy: 2017, enacted: d(2017, 5, 5)),
        USYear(fy: 2018, enacted: d(2018, 3, 23), lapses: [(d(2018, 1, 20), d(2018, 1, 23)), (d(2018, 2, 9), d(2018, 2, 10))]),
        USYear(fy: 2019, enacted: d(2019, 2, 15), early: ["defense", "health", "energy"], lapses: [(d(2018, 12, 22), d(2019, 1, 26))]),
        USYear(fy: 2020, enacted: d(2019, 12, 20)),
        USYear(fy: 2021, enacted: d(2020, 12, 27)),
        USYear(fy: 2022, enacted: d(2022, 3, 15)),
        USYear(fy: 2023, enacted: d(2022, 12, 29)),
        USYear(fy: 2024, enacted: d(2024, 3, 9), late: (["defense", "health", "homeland", "fsgg"], d(2024, 3, 23))),
        USYear(fy: 2025, enacted: d(2025, 3, 15), fullYearCR: true),
        USYear(fy: 2026, enacted: d(2026, 1, 30), lapses: [(d(2025, 10, 1), d(2025, 11, 13))]),
    ]

    /// The appropriations bill that funds a US agency.
    static func usBill(_ agency: String) -> String {
        switch agency {
        case "oadr", "dciu", "iaro": "defense"
        case "feso", "meridian": "energy"
        case "nhri": "health"
        case "nfse", "naoa": "cjs"
        case "ncra": "homeland"
        case "fasa": "fsgg"
        default: "cjs"
        }
    }

    /// Calendar-year budgets that started the year without an enacted budget (provisional appropriations): country, start, end.
    static let provisional: [(String, Date, Date)] = [
        ("ro", d(2021, 1, 1), d(2021, 2, 13)),   // the 2021 budget law came after the December 2020 election
        ("dk", d(2023, 1, 1), d(2023, 2, 24)),   // a provisional appropriation act after the November 2022 election (game estimate of the end date)
        ("fr", d(2025, 1, 1), d(2025, 2, 15)),   // the "loi spéciale" after the government fell in December 2024
        ("fr", d(2026, 1, 1), d(2026, 2, 20)),   // a second special law (game estimate of the end date)
    ]
}
