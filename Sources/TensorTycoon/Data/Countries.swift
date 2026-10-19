import Foundation

// MARK: - 3.5: headquarters countries
//
// Where the company is incorporated and where its people work. The United States / San Francisco is the default and
// is neutral by construction: every multiplier is exactly 1 and every bonus 0, so a US game plays exactly as before.
//
// The European numbers are documented approximations, rounded and simplified for the game. Sources (2023–2025 data):
//  [TAX]   OECD Corporate Tax Statistics 2024, Table "Statutory corporate income tax rates"; Tax Foundation,
//          "Corporate Tax Rates around the World, 2024". RO 16% profit tax (Fiscal Code, Law 227/2015);
//          IT 24% IRES + 3.9% IRAP; FR 25% + 3.3% social contribution on the excess (≈25.8%); DK 22%.
//  [RD]    OECD R&D Tax Incentives database 2024 (implied tax-subsidy rates). FR Crédit d'Impôt Recherche 30% of R&D
//          spend, refundable for young innovative firms; IT R&D tax credit 10–20%; DK enhanced 120–130% R&D deduction
//          (≈5–7% of spend in tax value) with a refundable "tax credit for losses"; RO 50% extra R&D deduction (≈8%).
//          The US Section 41 credit is already inside the game's default economics, so the US has none here.
//  [PAY]   Levels.fyi End of Year Pay Reports 2023/2024 (ML/AI engineer total compensation by city); Glassdoor and
//          national salary surveys (ANIS Romania, Eurostat Structure of Earnings Survey 2022). Game salaries model
//          frontier-lab pay in San Francisco; European multipliers compare like-for-like senior ML pay.
//  [ONCOST] Employer social contributions on gross pay: FR ≈ 40–45%, IT ≈ 30%, RO 2.25% (since the 2018 shift to
//          employees), DK ≈ 1–2% (ATP, AES), US ≈ 7.65% FICA + benefits. Expressed relative to the US.
//  [RENT]  Cushman & Wakefield / JLL / CBRE office MarketBeats 2024 (prime rents): SF ≈ $70/sq ft/yr (≈ €700/m²);
//          Paris CBD ≈ €1,000–1,200/m², La Défense ≈ €550, Lyon ≈ €340, Grenoble ≈ €200; Milan Porta Nuova ≈ €720,
//          Rome EUR/centre ≈ €550, Turin ≈ €240; Bucharest ≈ €21/m²/month, Cluj ≈ €15; Copenhagen ≈ DKK 2,300/m²/yr
//          (≈ €310), Aarhus ≈ DKK 1,650, Odense ≈ DKK 1,250, Aalborg ≈ DKK 1,150. Office multipliers include fit-out
//          and services, so they compress the rent spread (game-simplified).
//  [POWER] Eurostat nrg_pc_205 (non-household electricity, large-consumer bands, 2024-S2) and EIA Electric Power
//          Monthly (US industrial ≈ $0.08/kWh). Datacenter locations assume long-term contracts: French nuclear
//          allocation contracts, Danish wind PPAs (Nord Pool DK1/DK2), Italian PUN-indexed supply, Romanian hydro/nuclear.
//  [TALENT] OECD.AI "AI talent" indicators; Stanford AI Index 2024 (AI talent concentration); Eurostat ICT specialists
//          (isoc_sks_itspt). Pool and hiring multipliers are game-simplified relative sizes, not head counts.
//  [VC]    Atomico "State of European Tech 2024"; Dealroom country reports 2024. Depth = how well early rounds price
//          without leaning on US funds; international capital is always available.
//  [GRANTS] Horizon Europe / EIC Accelerator (grants up to €2.5M), EuroHPC "AI Factories" compute access calls,
//          France 2030 (AI clusters, Bpifrance deeptech), Italy PNRR research calls and Industry 4.0 competence
//          centres, Innovation Fund Denmark, Denmark's national AI supercomputer (Gefion, 2024), Romania's PNRR
//          digital calls. In-game programme names are fictionalised and amounts game-simplified.

/// A city you can put the company's headquarters in.
struct HQCity: Identifiable, Sendable {
    let id: String
    let name: String
    /// Photo key (Resources/Images), credited in ImageCredits.
    let image: String
    let blurb: String
    /// Pay for the same talent, relative to the country's level. [PAY]
    let salary: Double
    /// Office cost relative to San Francisco (absolute, not relative to the country). [RENT]
    let office: Double
    /// Candidate pool relative to the country's. [TALENT]
    let talent: Double
    /// Roles the local ecosystem produces more of (and slightly stronger).
    let specialties: [Role]
    /// What the local cluster is known for, in a few words.
    let cluster: String
    /// Product lines the local industry gives you a head start in (on top of the country's).
    var affinities: [HQAffinity] = []
}

/// A head start in a product line from local industry: the domain bars drop by `relief` points and the product draws
/// `pull` times the customers (local buyers and partners).
struct HQAffinity: Sendable, Hashable {
    let product: String
    let relief: Double
    let pull: Double
    /// Who the partners are, for the partnership offer.
    let partner: String
}

/// A grant, compute allocation or contract programme that can show up in the inbox.
struct HQProgramme: Sendable {
    enum Kind: Sendable { case grant, compute, contract }
    let kind: Kind
    /// Fictionalised in-game name.
    let name: String
    /// What it funds, for the inbox card.
    let pitch: String
    /// Base award in 2022 dollars (grants and compute); contracts scale with the business.
    let base: Double
}

struct HQCountry: Identifiable, Sendable {
    let id: String
    let name: String
    let flag: String
    /// Short adjective ("French"), for news.
    let adjective: String
    /// The rule-making region this country belongs to (WorldState / Stakeholders).
    let region: Region
    let cities: [HQCity]
    let tagline: String
    let overview: String

    // Money
    /// Statutory corporate income tax on monthly profit. [TAX]
    let corporateTax: Double
    /// Share of research payroll returned as an R&D tax credit each month. [RD]
    let rdCredit: Double
    /// Whether any credit beyond the month's tax bill is paid out in cash (as France's CIR is for young firms).
    let rdRefundable: Bool
    /// Pay for ML talent relative to San Francisco. [PAY]
    let salary: Double
    /// Employer on-costs relative to the US (+0.35 = 35% more payroll cost on top of salaries). [ONCOST]
    let employerCost: Double
    /// How strongly local early-stage investors price rounds (1 = Silicon Valley). Fades as you grow. [VC]
    let investorDepth: Double

    // People
    /// Candidate pool relative to San Francisco. [TALENT]
    let talentPool: Double
    /// How readily big foreign labs poach your people (1 = SF baseline).
    let brainDrain: Double
    let specialties: [Role]

    // Infrastructure
    /// Industrial electricity, $/kWh (shown for comparison; datacenters use the location's price). [POWER]
    let power: Double
    /// The LocationCatalog site your garage and home datacenters sit in.
    let homeLocation: String
    /// Datacenter capex at home relative to the default: local incentives and contractors.
    let buildCost: Double

    // Government
    /// Standing with your home region's government at the start (points above the region's usual bias).
    let homeStanding: Double
    /// Standing with the US government (non-US labs start a little further from Washington).
    let usStanding: Double
    /// Chance per month of a grant or compute allocation offer (before era and size checks).
    let grantRate: Double
    /// How keen the home government is to buy from a national champion (contract offers per year, roughly).
    let contractAffinity: Double
    let programmes: [HQProgramme]
    let affinities: [HQAffinity]

    // For the selection screen
    let pros: [String]
    let cons: [String]
    let strategies: [String]
    let sources: String

    func city(_ id: String) -> HQCity { cities.first { $0.id == id } ?? cities[0] }
}

enum CountryCatalog {
    static let us = HQCountry(
        id: "us", name: "United States", flag: "🇺🇸", adjective: "American", region: .us,
        cities: [HQCity(id: "sf", name: "San Francisco", image: "sf_skyline",
                        blurb: "The centre of the AI world: every frontier lab, every big fund and the deepest talent pool on Earth — at Bay Area prices.",
                        salary: 1, office: 1, talent: 1, specialties: [], cluster: "Frontier labs, venture capital, big tech")],
        tagline: "The default. Deepest capital and talent, highest costs.",
        overview: "Silicon Valley money and talent, US rules. The game's baseline: everything else is measured against it.",
        corporateTax: 0.21, rdCredit: 0, rdRefundable: false, salary: 1, employerCost: 0, investorDepth: 1,
        talentPool: 1, brainDrain: 1, specialties: [], power: 0.085, homeLocation: "nova", buildCost: 1,
        homeStanding: 0, usStanding: 0, grantRate: 0, contractAffinity: 0, programmes: [], affinities: [],
        pros: ["Deepest venture capital market in the world", "Largest pool of frontier AI talent", "Fast-moving, light-touch federal rules (for now)"],
        cons: ["The highest salaries anywhere", "Bay Area office rents", "Every rival is hiring from the same pool"],
        strategies: ["Raise big and early; out-spend rivals on compute", "Hire stars before the 2025 talent wars"],
        sources: "Baseline (the game's original economics).")

    static let all: [HQCountry] = [
        us,
        HQCountry(
            id: "ro", name: "Romania", flag: "🇷🇴", adjective: "Romanian", region: .eu,
            cities: [
                HQCity(id: "bucharest", name: "Bucharest", image: "hq_bucharest",
                       blurb: "The capital and Romania's biggest tech market: global engineering centres, a fast-growing startup scene and some of Europe's fastest fibre.",
                       salary: 1.0, office: 0.34, talent: 1.0, specialties: [.mlEngineer, .infra],
                       cluster: "Software engineering centres, cybersecurity, fintech"),
                HQCity(id: "cluj", name: "Cluj-Napoca", image: "hq_cluj",
                       blurb: "Transylvania's university city and Romania's best-known tech hub: a big IT cluster, Babeș-Bolyai and the Technical University, and lower costs than Bucharest.",
                       salary: 0.94, office: 0.28, talent: 0.8, specialties: [.mlEngineer, .data],
                       cluster: "Cluj IT cluster, university research, product startups",
                       affinities: [HQAffinity(product: "tutor", relief: 3, pull: 1.1, partner: "Cluj's universities and edtech startups")]),
            ],
            tagline: "Lowest costs in the EU, strong engineers, a thin local VC market.",
            overview: "Romania's engineers built software for half of Europe's banks and carmakers. Salaries and rents are a fraction of San Francisco's and the profit tax is the EU's lowest tier. Capital is thinner at home, so early rounds lean on foreign funds, and big labs abroad are always recruiting your best people.",
            corporateTax: 0.16, rdCredit: 0.08, rdRefundable: false, salary: 0.34, employerCost: -0.05, investorDepth: 0.82,
            talentPool: 0.7, brainDrain: 1.35, specialties: [.mlEngineer, .infra], power: 0.110, homeLocation: "ro_bucharest", buildCost: 0.82,
            homeStanding: 9, usStanding: -2, grantRate: 0.07, contractAffinity: 0.5,
            programmes: [
                HQProgramme(kind: .grant, name: "EU frontier research grant", pitch: "A Horizon-style European grant for breakthrough AI research, matched by a national co-financing line.", base: 2_500_000),
                HQProgramme(kind: .grant, name: "National Recovery digital call", pitch: "Recovery-plan money for digital transformation projects, administered from Bucharest.", base: 1_500_000),
                HQProgramme(kind: .compute, name: "EuroHPC AI Factory allocation", pitch: "Free GPU hours on a European public supercomputer, for a startup with a credible training plan.", base: 600_000),
                HQProgramme(kind: .contract, name: "e-government modernisation", pitch: "The government wants Romanian-language assistants for public services and tax administration.", base: 0),
            ],
            affinities: [HQAffinity(product: "operator", relief: 4, pull: 1.15, partner: "Romania's shared-services and BPO centres")],
            pros: ["Salaries about a third of San Francisco's; tiny employer contributions", "16% profit tax and the cheapest offices in this list", "Strong software and infrastructure engineers", "Cheapest place to build a datacenter at home"],
            cons: ["Smallest talent pool: fewer candidates each month", "Foreign labs poach aggressively", "Thin local VC: early rounds price lower until you're big", "Smaller grants and a small home market"],
            strategies: ["Run lean: a cheap, large engineering team stretches your seed money furthest", "Pay your best people above local rates to stop poaching", "Use EuroHPC compute grants instead of renting early"],
            sources: "Tax: Fiscal Code (Law 227/2015). Pay: Levels.fyi, ANIS salary surveys. Rent: Cushman & Wakefield Bucharest/Cluj office MarketBeat 2024. Power: Eurostat nrg_pc_205."),
        HQCountry(
            id: "it", name: "Italy", flag: "🇮🇹", adjective: "Italian", region: .eu,
            cities: [
                HQCity(id: "milan", name: "Milan", image: "hq_milan",
                       blurb: "Italy's business capital: Porta Nuova's towers, the stock exchange, Politecnico di Milano and Bocconi, and most of the country's venture money.",
                       salary: 1.06, office: 0.80, talent: 1.0, specialties: [.mlEngineer, .sales],
                       cluster: "Finance, design, Politecnico and Bocconi, most Italian VC"),
                HQCity(id: "rome", name: "Rome", image: "hq_rome",
                       blurb: "The seat of government and of Italy's big state-owned companies; Sapienza's large AI groups and the public administration as a customer.",
                       salary: 0.97, office: 0.66, talent: 0.85, specialties: [.researcher, .safety],
                       cluster: "Government, defence and aerospace, Sapienza University",
                       affinities: [HQAffinity(product: "government", relief: 4, pull: 1.2, partner: "Italy's ministries and state-owned groups")]),
                HQCity(id: "turin", name: "Turin", image: "hq_turin",
                       blurb: "Italy's industrial heartland: carmakers, aerospace and automation suppliers, Politecnico di Torino and a national AI institute.",
                       salary: 0.92, office: 0.40, talent: 0.75, specialties: [.mlEngineer, .infra],
                       cluster: "Automotive, aerospace, industrial automation",
                       affinities: [HQAffinity(product: "robotics", relief: 4, pull: 1.15, partner: "Turin's automotive and automation suppliers")]),
            ],
            tagline: "Manufacturing and robotics partners, moderate costs, higher taxes.",
            overview: "Europe's second-largest manufacturer, with machine-tool, robotics and automation companies across the north. Engineers cost well under half of Bay Area pay, but taxes and employer contributions are high and energy is among Europe's dearest. Industrial partners give robotics products a head start.",
            corporateTax: 0.279, rdCredit: 0.10, rdRefundable: false, salary: 0.42, employerCost: 0.22, investorDepth: 0.86,
            talentPool: 0.8, brainDrain: 1.25, specialties: [.mlEngineer, .data], power: 0.150, homeLocation: "it_milan", buildCost: 0.95,
            homeStanding: 9, usStanding: -2, grantRate: 0.07, contractAffinity: 0.6,
            programmes: [
                HQProgramme(kind: .grant, name: "EU frontier research grant", pitch: "A Horizon-style European grant for breakthrough AI research.", base: 2_500_000),
                HQProgramme(kind: .grant, name: "Industry 4.0 competence-centre call", pitch: "Co-funding for AI pilots with manufacturers through a national competence centre.", base: 3_000_000),
                HQProgramme(kind: .compute, name: "EuroHPC AI Factory allocation", pitch: "Free GPU hours on the Italian EuroHPC supercomputer for an AI startup.", base: 900_000),
                HQProgramme(kind: .contract, name: "public administration AI", pitch: "Ministries want Italian-language assistants for courts, health and tax administration.", base: 0),
            ],
            affinities: [HQAffinity(product: "robotics", relief: 6, pull: 1.25, partner: "Italian machine-tool and robotics makers")],
            pros: ["Salaries well under half of San Francisco's", "Industrial partners: robotics products unlock sooner and sell better", "R&D tax credit on research payroll", "Strong engineering universities (Politecnico di Milano, Torino)"],
            cons: ["≈27.9% tax (IRES + IRAP) and high employer contributions", "Some of Europe's most expensive electricity", "Smaller VC market than Paris or London"],
            strategies: ["Pick Turin and steer research toward embodied models for an early Robotics Brain", "Milan for investors and enterprise sales", "Rome for public-sector and defence contracts"],
            sources: "Tax: IRES 24% + IRAP 3.9% (OECD 2024). Pay: Levels.fyi, Eurostat SES. Rent: CBRE/JLL Milan & Rome 2024. Power: Eurostat nrg_pc_205 (PUN-indexed)."),
        HQCountry(
            id: "fr", name: "France", flag: "🇫🇷", adjective: "French", region: .eu,
            cities: [
                HQCity(id: "paris", name: "Paris", image: "hq_paris",
                       blurb: "Continental Europe's AI capital: big-lab research centres, a fast-growing crop of AI startups, grandes écoles and INRIA, and Europe's deepest VC outside London.",
                       salary: 1.08, office: 0.92, talent: 1.0, specialties: [.researcher, .mlEngineer],
                       cluster: "AI labs, grandes écoles, Station F, VC"),
                HQCity(id: "lyon", name: "Lyon", image: "hq_lyon",
                       blurb: "France's second economy: biotech and vaccine makers, chemicals, gaming studios and a strong engineering school network — at half of Paris's rents.",
                       salary: 0.9, office: 0.48, talent: 0.7, specialties: [.data, .mlEngineer],
                       cluster: "Biotech and health, chemicals, games",
                       affinities: [HQAffinity(product: "health", relief: 4, pull: 1.15, partner: "Lyon's biotech and hospital groups")]),
                HQCity(id: "grenoble", name: "Grenoble", image: "hq_grenoble",
                       blurb: "France's chip valley under the Alps: semiconductor fabs and design centres, a national electronics research lab and a big university campus.",
                       salary: 0.88, office: 0.36, talent: 0.6, specialties: [.chipDesigner, .infra],
                       cluster: "Semiconductors, micro-electronics research, physics"),
            ],
            tagline: "Sovereign-AI champion: public compute, big grants, high payroll taxes.",
            overview: "France wants a national AI champion and pays for it: generous research tax credits, public supercomputer time and sovereign contracts. Paris has the deepest pool of AI researchers on the continent and cheap, low-carbon nuclear power, but employer contributions push the true cost of every hire up by a third.",
            corporateTax: 0.258, rdCredit: 0.22, rdRefundable: true, salary: 0.55, employerCost: 0.35, investorDepth: 0.94,
            talentPool: 0.9, brainDrain: 1.1, specialties: [.researcher, .mlEngineer], power: 0.085, homeLocation: "fr_rhone", buildCost: 0.90,
            homeStanding: 12, usStanding: -3, grantRate: 0.10, contractAffinity: 1.0,
            programmes: [
                HQProgramme(kind: .grant, name: "EU frontier research grant", pitch: "A Horizon-style European grant for breakthrough AI research.", base: 2_500_000),
                HQProgramme(kind: .grant, name: "Compute 2030 AI-cluster call", pitch: "National investment-plan money for AI champions that train in France.", base: 6_000_000),
                HQProgramme(kind: .compute, name: "national public supercomputer allocation", pitch: "Free GPU hours on France's public research supercomputer.", base: 1_200_000),
                HQProgramme(kind: .contract, name: "sovereign AI for the state", pitch: "Ministries want a French model hosted in France for administration and defence.", base: 0),
            ],
            affinities: [HQAffinity(product: "government", relief: 6, pull: 1.3, partner: "the French state and defence primes")],
            pros: ["Biggest AI research pool in continental Europe", "Research tax credit (CIR) refunds a slice of research payroll", "Most grants and public compute; sovereign contracts at home", "Cheap low-carbon nuclear power for datacenters"],
            cons: ["Employer contributions add ≈35% on top of salaries", "≈25.8% corporate tax", "Paris rents are close to San Francisco's"],
            strategies: ["Lean on research: the CIR makes researchers cheaper than they look", "Build your first campus on nuclear power in the Rhône valley", "Grenoble if you plan to design your own chips"],
            sources: "Tax: 25% + 3.3% CSB (OECD 2024). CIR: OECD R&D tax incentives 2024. Pay: Levels.fyi Paris. Rent: Cushman & Wakefield Paris 2024. Power: Eurostat; EDF long-term nuclear contracts."),
        HQCountry(
            id: "dk", name: "Denmark", flag: "🇩🇰", adjective: "Danish", region: .eu,
            cities: [
                HQCity(id: "copenhagen", name: "Copenhagen", image: "hq_copenhagen",
                       blurb: "A rich, English-speaking capital with Europe's life-science giants on its doorstep, a national AI supercomputer and some of the world's cleanest power.",
                       salary: 1.05, office: 0.52, talent: 1.0, specialties: [.researcher, .data],
                       cluster: "Life sciences and pharma, design, cleantech",
                       affinities: [HQAffinity(product: "science", relief: 5, pull: 1.2, partner: "Copenhagen's life-science companies")]),
                HQCity(id: "aarhus", name: "Aarhus", image: "hq_aarhus",
                       blurb: "Denmark's second city: a big university, wind-turbine makers and agritech, with lower costs than the capital.",
                       salary: 0.95, office: 0.40, talent: 0.7, specialties: [.mlEngineer, .infra],
                       cluster: "University, wind energy, agritech"),
                HQCity(id: "odense", name: "Odense", image: "hq_odense",
                       blurb: "Home of one of Europe's densest robotics clusters: collaborative-robot makers, drone companies and a university robotics institute.",
                       salary: 0.92, office: 0.34, talent: 0.55, specialties: [.mlEngineer, .infra],
                       cluster: "Collaborative robots, drones, automation",
                       affinities: [HQAffinity(product: "robotics", relief: 6, pull: 1.25, partner: "Odense's robotics cluster")]),
                HQCity(id: "aalborg", name: "Aalborg", image: "hq_aalborg",
                       blurb: "North Jutland's university city, strong in wireless, energy systems and engineering, with Denmark's lowest office costs.",
                       salary: 0.9, office: 0.32, talent: 0.5, specialties: [.infra, .safety],
                       cluster: "Wireless and telecom research, energy systems"),
            ],
            tagline: "Green power, robotics and life sciences, a small but strong talent pool.",
            overview: "A small, high-trust, high-wage economy that runs largely on wind. Danish datacenters get cheap renewable power and free cooling, Odense's robotics cluster and Copenhagen's life-science industry are natural partners, and employer contributions are among the lowest in Europe. The catch: a small talent pool.",
            corporateTax: 0.22, rdCredit: 0.07, rdRefundable: true, salary: 0.62, employerCost: -0.06, investorDepth: 0.9,
            talentPool: 0.65, brainDrain: 1.05, specialties: [.researcher, .data], power: 0.080, homeLocation: "dk_jutland", buildCost: 0.93,
            homeStanding: 10, usStanding: -2, grantRate: 0.08, contractAffinity: 0.6,
            programmes: [
                HQProgramme(kind: .grant, name: "EU frontier research grant", pitch: "A Horizon-style European grant for breakthrough AI research.", base: 2_500_000),
                HQProgramme(kind: .grant, name: "national innovation fund grand-solutions grant", pitch: "Co-funding for an ambitious research partnership with Danish universities.", base: 4_000_000),
                HQProgramme(kind: .compute, name: "national AI supercomputer allocation", pitch: "GPU time on Denmark's national AI supercomputer, funded by a life-science foundation.", base: 1_000_000),
                HQProgramme(kind: .contract, name: "Danish public sector AI", pitch: "Municipalities and the health service want a Danish-language assistant.", base: 0),
            ],
            affinities: [HQAffinity(product: "health", relief: 4, pull: 1.15, partner: "Danish hospitals and pharma")],
            pros: ["Cheap wind power and free cooling for datacenters", "Lowest employer contributions in this list; 22% tax", "Robotics (Odense) and life-science (Copenhagen) partners", "Talent is happy to stay: low poaching"],
            cons: ["Smallest talent pool per city", "Salaries well above the rest of Europe", "Small home market and government"],
            strategies: ["Build datacenters at home: wind PPAs and the coldest air in this list", "Odense for an early Robotics Brain; Copenhagen for Discovery and Healthcare", "Grow the team slowly and keep it"],
            sources: "Tax: 22% selskabsskat (OECD 2024). Pay: Levels.fyi Copenhagen. Rent: Sadolin & Albæk / Colliers Denmark 2024. Power: Nord Pool DK1, Eurostat nrg_pc_205."),
    ]

    static let byID: [String: HQCountry] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func get(_ id: String) -> HQCountry { byID[id] ?? us }
}

// MARK: - European datacenter locations (3.5)
//
// Kept in their own block so other location changes merge cleanly. Power prices assume long-term contracts [POWER].
// Mapped to the EU region in `Region.locations`.
extension LocationCatalog {
    static let european: [Location] = [
        Location(id: "dk_jutland", name: "Fredericia, Denmark", region: "Nordics", powerPrice: 0.072, pueDelta: -0.07, buildSpeed: 0.9,
                 gridCapMW: 700, coloFee: 165, image: "dc_foulum",
                 blurb: "Wind-powered Jutland: renewable PPAs, cold air and waste heat sold to the district-heating grid. Hyperscalers already build here.",
                 photoShowsPlace: true),
        Location(id: "fr_rhone", name: "Rhône Valley, France", region: "France", powerPrice: 0.068, pueDelta: -0.02, buildSpeed: 0.85,
                 gridCapMW: 1_500, coloFee: 160, image: "loc_rhone",
                 blurb: "Next to the Rhône's nuclear plants: low-carbon baseload on long-term contracts and a grid built for heavy industry.",
                 photoShowsPlace: true),
        Location(id: "it_milan", name: "Milan, Italy", region: "Italy", powerPrice: 0.140, pueDelta: 0.03, buildSpeed: 0.75,
                 gridCapMW: 700, coloFee: 175, image: "hq_milan",
                 blurb: "Italy's datacenter hub with great connectivity to southern Europe, but gas-indexed power is expensive and permits are slow.",
                 photoShowsPlace: true),
        Location(id: "ro_bucharest", name: "Bucharest, Romania", region: "Romania", powerPrice: 0.098, pueDelta: 0.02, buildSpeed: 1.05,
                 gridCapMW: 400, coloFee: 105, image: "hq_bucharest",
                 blurb: "Cheap land and labour, quick construction and a hydro-and-nuclear grid. A smaller grid and hot summers.",
                 photoShowsPlace: true),
    ]
}

// MARK: - Previews (selection screen and harness)

extension HQCountry {
    /// Pay for ordinary hires in a city relative to San Francisco.
    func pay(_ city: HQCity) -> Double { id == "us" ? 1 : salary * city.salary }

    /// What a research hire really costs per San Francisco salary dollar, after employer on-costs and the R&D credit.
    func netPayrollFactor(_ city: HQCity) -> Double { pay(city) * (1 + employerCost) * (1 - rdCredit) }

    /// Candidates on the market at once with a small team (San Francisco: 8).
    func candidates(_ city: HQCity) -> Int { id == "us" ? 8 : max(4, Int((8 * talentPool * city.talent).rounded())) }

    var location: Location? { LocationCatalog.byID[homeLocation] }

    /// A first year with the two founders plus six ordinary hires and the startup office, at the era's prices.
    func yearOne(_ city: HQCity, year y: Double) -> (payroll: Double, office: Double) {
        let roles: [(Role, Double)] = [(.researcher, 0.8), (.mlEngineer, 0.8), (.researcher, 1), (.researcher, 1), (.mlEngineer, 1),
                                       (.mlEngineer, 1), (.infra, 1), (.data, 1)]
        let gross = roles.reduce(0.0) { $0 + Macro.salary($1.0, y) * $1.1 } * pay(city)
        let office = Economy.officeLevels[1].monthly * (id == "us" ? 1 : city.office) * 12
        return (gross * (1 + employerCost) * (1 - rdCredit), office)
    }

    var regionLabel: String { region == .eu ? "EU · AI Act" : region.short }
}
