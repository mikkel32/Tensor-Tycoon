import Foundation

// MARK: - 3.5: headquarters countries
//
// Where the company is incorporated and where its people work. The United States / San Francisco is the default and
// is neutral by construction: every multiplier is exactly 1 and every bonus 0, so a US game plays exactly as before.
//
// The European numbers are documented approximations, rounded and simplified for the game. Statutory values (tax
// rates, R&D schemes and their caps, employer contributions) are real 2024 rules and are shown as facts on the
// selection screen; everything else (pay and talent multipliers, office factors, grant odds, build incentives, policy
// character) is a game estimate calibrated against the sources below. Sources (2023–2025 data):
//  [TAX]   OECD Corporate Tax Statistics 2024, Table "Statutory corporate income tax rates"; Tax Foundation,
//          "Corporate Tax Rates around the World, 2024". RO 16% profit tax (Fiscal Code, Law 227/2015), plus from 2024
//          a 1% minimum turnover tax for companies with more than €50M of turnover (Law 296/2023); IT 24% IRES + 3.9%
//          IRAP; FR 25% + 3.3% social contribution on the excess (≈25.8%); DK 22%. The US 21% is the federal rate only:
//          state corporate taxes (≈4–5 points on average) are not modelled.
//  [RD]    OECD R&D Tax Incentives database 2024 and the national rules. FR Crédit d'Impôt Recherche: 30% of eligible
//          R&D spend up to €100M a year and 5% above, paid in cash at once to SMEs and young innovative companies,
//          otherwise set against tax and refunded after three years. IT R&D tax credit: 10% (2023–2031), at most €5M a
//          year, used by offsetting taxes and social contributions (F24). DK: an enhanced R&D deduction (≈5–7% of spend
//          in tax value) plus the "skattekredit", the tax value (22%) of R&D-driven losses paid in cash for up to DKK 25M
//          of losses a year. RO: a 50% extra deduction of eligible R&D costs (≈8% in tax value), usable only against
//          profit. The game counts research and engineering payroll with on-costs as eligible spend. The US Section 41
//          credit is already inside the game's default economics, so the US has none here.
//  [PAY]   Levels.fyi End of Year Pay Reports 2023/2024 (ML/AI engineer total compensation by city); Glassdoor and
//          national salary surveys (ANIS Romania, Eurostat Structure of Earnings Survey 2022). Game salaries model
//          frontier-lab pay in San Francisco; the European multipliers are what a lab competing for global ML talent
//          pays there, which in Romania and Italy is about twice the typical local market rate (game estimate).
//  [ONCOST] Employer social contributions on gross pay: FR ≈ 40–45%, IT ≈ 30%, RO 2.25% (since the 2018 shift to
//          employees), DK ≈ 1–2% (ATP, AES), US ≈ 7.65% FICA + benefits. Expressed relative to the US.
//  [RENT]  Cushman & Wakefield / JLL / CBRE office MarketBeats 2024 (prime rents): SF ≈ $70/sq ft/yr (≈ €700/m²);
//          Paris CBD ≈ €1,000–1,200/m², La Défense ≈ €550, Lyon ≈ €340, Grenoble ≈ €200; Milan Porta Nuova ≈ €720,
//          Rome EUR/centre ≈ €550, Turin ≈ €240; Bucharest ≈ €21/m²/month, Cluj ≈ €15; Copenhagen ≈ DKK 2,300/m²/yr
//          (≈ €310), Aarhus ≈ DKK 1,650, Odense ≈ DKK 1,250, Aalborg ≈ DKK 1,150. Office multipliers include fit-out
//          and services, so they compress the rent spread (game-simplified).
//  [POWER] Eurostat nrg_pc_205 (non-household electricity, bands IF–IG for large consumers, 2024-S2, excluding VAT and
//          recoverable taxes) and EIA Electric Power Monthly 2024 (US industrial ≈ $0.08/kWh). Contract prices: EDF's
//          ARENH (€42/MWh, 2011–2025) and the long-term nuclear allocation contracts replacing it (≈ €60–70/MWh); Nordic
//          wind PPAs (≈ €35–45/MWh in 2024); Italian solar PPAs (≈ €60–70/MWh); Romanian hydro sold forward by
//          Hidroelectrica. Romania's price is the least certain number here: the 2022–2025 price caps and the 2024
//          wholesale spike moved large-consumer prices a lot from year to year.
//  [TALENT] OECD.AI "AI talent" indicators; Stanford AI Index 2024 (AI talent concentration); Eurostat ICT specialists
//          (isoc_sks_itspt). Pool and hiring multipliers are game-simplified relative sizes, not head counts.
//  [VC]    Atomico "State of European Tech 2024"; Dealroom country reports 2024. Depth = how well early rounds price
//          without leaning on US funds; international capital is always available.
//  [GRANTS] Horizon Europe / EIC Accelerator (grants up to €2.5M), EuroHPC access calls and its AI Factories (first
//          seven selected in December 2024), France 2030 (October 2021: AI clusters, Bpifrance deeptech), the Jean Zay
//          supercomputer (2020), Italy's Industry 4.0 competence centres (2018) and the Leonardo EuroHPC machine (late
//          2022), Innovation Fund Denmark, Denmark's national AI supercomputer Gefion (October 2024), Romania's recovery
//          plan (PNRR, digital calls from 2022). In-game names are fictionalised and amounts game-simplified; each
//          programme starts when the real one did.
//  [POLICY] Each country's policy against its region's is a game estimate from its record: France 2030 and the
//          sovereign-AI push; Italy's data-protection authority (it blocked ChatGPT for a month in 2023) and gas-indexed
//          power; Denmark's wind grid and Gefion; Romania's smaller national budget, which leans on EU funds.

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
    /// When the real programme it stands for started (decimal year): it isn't offered before then. [GRANTS]
    var from: Double = 2016
    /// The real programme, for the selection screen ("EuroHPC AI Factories, from December 2024").
    var real: String = ""
}

/// How an R&D tax relief really pays out [RD].
enum RDScheme: String, Sendable {
    /// No separate relief (the US: inside the baseline economics).
    case none
    /// Only against profit; unused relief carries forward (Romania's extra deduction).
    case againstProfit
    /// Set against taxes and employer social contributions, so it pays while you make losses (Italy).
    case payrollOffset
    /// Against profit; while you make losses, the tax value of R&D losses is paid in cash up to a cap (Denmark).
    case lossRefund
    /// Paid in cash at once to small firms; larger firms set it against tax and get the rest over three years (France).
    case refundable

    /// One honest line for the selection screen.
    var explain: String {
        switch self {
        case .none: "No separate relief: the US R&D credit is already part of the baseline costs."
        case .againstProfit: "Used against profits; carried forward while you make losses."
        case .payrollOffset: "Set against taxes and employer contributions, so it pays even while you make losses (capped each year)."
        case .lossRefund: "Used against profits; while you make losses, the state pays the tax value of R&D losses in cash (capped each year)."
        case .refundable: "Paid in cash at once while you're a small company (under 250 staff); after that it's set against tax and the rest refunded over about three years."
        }
    }

    var short: String {
        switch self {
        case .none: "None"
        case .againstProfit: "Against profit"
        case .payrollOffset: "Offsets payroll taxes"
        case .lossRefund: "Against profit · loss refund"
        case .refundable: "Refundable"
        }
    }

    /// Whether it puts cash in your hands while you make losses.
    var paysWhileLossMaking: Bool { self == .payrollOffset || self == .lossRefund || self == .refundable }
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
    /// R&D relief as a share of eligible R&D spend (the rate up to any cap). [RD]
    let rdCredit: Double
    /// Whether any credit beyond the month's tax bill is paid out in cash (kept for older views; see `rdScheme`).
    let rdRefundable: Bool
    /// Pay for ML talent relative to San Francisco (frontier-lab pay). [PAY]
    let salary: Double
    /// Employer on-costs relative to the US (+0.35 = 35% more payroll cost on top of salaries). [ONCOST]
    let employerCost: Double
    /// How strongly local early-stage investors price rounds (1 = Silicon Valley). Fades as you grow. [VC]
    let investorDepth: Double

    // People
    /// Candidate pool relative to San Francisco while you're small; fades as you become well known. [TALENT]
    let talentPool: Double
    /// How readily big foreign labs poach your people (1 = SF baseline).
    let brainDrain: Double
    let specialties: [Role]

    // Infrastructure
    /// Industrial electricity, $/kWh (shown for comparison; datacenters use the location's price). [POWER]
    let power: Double
    /// The LocationCatalog site your garage and home datacenters sit in.
    let homeLocation: String
    /// Datacenter construction cost at home relative to the default: local incentives and contractors (game estimate),
    /// taken off when each phase is built (not on campuses you buy).
    let buildCost: Double

    // Government
    /// Standing with your home region's government at the start (points above the region's usual bias).
    let homeStanding: Double
    /// Standing with the US government (non-US labs start a little further from Washington).
    let usStanding: Double
    /// Chance per month of a grant or compute allocation offer, before spacing, era and national policy.
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

    // 3.4 overhaul
    /// How the R&D relief really pays out [RD].
    var rdScheme: RDScheme = .none
    /// Eligible R&D spend a year at the full rate (0: no cap); beyond it the rate is `rdAbove` (France's CIR).
    var rdCapYear: Double = 0
    var rdAbove: Double = 0
    /// The most credit a year (Italy: €5M); 0 = no cap.
    var rdCreditCapYear: Double = 0
    /// The most paid out in cash a year (Denmark's tax credit for R&D losses); 0 = no cap.
    var rdRefundCapYear: Double = 0
    /// Employer social contributions as a share of gross pay, absolute [ONCOST] (Italy's credit offsets them).
    var socialContributions: Double = 0.0765
    /// Where national policy sits against the region's, NationLever order [POLICY]. Empty: the country is its region.
    var character: [Double] = []
    /// Why, for each dial that differs (NationLever order, "" where it doesn't).
    var characterWhy: [String] = []
    /// Its tier under the US AI Diffusion Rule of January 2025 (1: the US and close allies, 2: most other countries).
    var diffusionTier: Int = 1

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
        cons: ["The highest salaries anywhere", "Bay Area office rents", "Every rival is hiring from the same pool", "US federal rules (compute reporting, licences, permitting) apply to you wherever you build"],
        strategies: ["Raise big and early; out-spend rivals on compute", "Hire stars before the 2025 talent wars"],
        sources: "Baseline (the game's original economics). Tax: 21% federal rate; state corporate taxes are not modelled.")

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
            talentPool: 0.7, brainDrain: 1.35, specialties: [.mlEngineer, .infra], power: 0.125, homeLocation: "ro_bucharest", buildCost: 0.82,
            homeStanding: 9, usStanding: -2, grantRate: 0.07, contractAffinity: 0.5,
            programmes: [
                HQProgramme(kind: .grant, name: "EU frontier research grant", pitch: "A Horizon-style European grant for breakthrough AI research, matched by a national co-financing line.", base: 2_500_000,
                            real: "Horizon 2020 / Horizon Europe (EIC)"),
                HQProgramme(kind: .grant, name: "National Recovery digital call", pitch: "Recovery-plan money for digital transformation projects, administered from Bucharest.", base: 1_500_000,
                            from: 2022.0, real: "Romania's PNRR digital calls, from 2022"),
                HQProgramme(kind: .compute, name: "EuroHPC AI Factory allocation", pitch: "Free GPU hours on a European public supercomputer, for a startup with a credible training plan.", base: 600_000,
                            from: 2025.0, real: "EuroHPC AI Factories access calls, from 2025"),
                HQProgramme(kind: .contract, name: "e-government modernisation", pitch: "The government wants Romanian-language assistants for public services and tax administration.", base: 0),
            ],
            affinities: [HQAffinity(product: "operator", relief: 4, pull: 1.15, partner: "Romania's shared-services and BPO centres")],
            pros: ["Frontier-lab pay about a third of San Francisco's; tiny employer contributions", "16% profit tax and the cheapest offices in this list", "Strong software and infrastructure engineers", "Cheapest place to build a datacenter at home; hydro power contracts"],
            cons: ["Smallest talent pool while you're unknown: fewer candidates each month", "Foreign labs poach aggressively", "Thin local VC: early rounds price lower until you're big", "Smaller grants and a small home market (national contracts are worth less)", "R&D relief only counts against profit", "From 2024, at least 1% of turnover in tax once revenue passes €50M a year", "A Tier 2 country under the 2025 US chip rule while it stood"],
            strategies: ["Run lean: a cheap, large engineering team stretches your seed money furthest", "Pay your best people above local rates to stop poaching", "Use EuroHPC compute grants instead of renting early", "Open a satellite office in a deep talent pool once you're growing"],
            sources: "Tax: Fiscal Code (Law 227/2015); minimum turnover tax Law 296/2023. R&D: 50% extra deduction (Fiscal Code art. 20). Pay: Levels.fyi, ANIS salary surveys. Rent: Cushman & Wakefield Bucharest/Cluj office MarketBeat 2024. Power: Eurostat nrg_pc_205, 2024-S2, large-consumer bands (the least certain value: prices swung under the 2022–2025 caps).",
            rdScheme: .againstProfit, socialContributions: 0.0225,
            character: [-12, -10, 0, -3, -3, -5, 3],
            characterWhy: ["a smaller national budget that leans on EU funds", "a small state customer", "", "lighter enforcement", "", "fewer fast-track visas", "hydro and nuclear power"],
            diffusionTier: 2),
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
                HQProgramme(kind: .grant, name: "EU frontier research grant", pitch: "A Horizon-style European grant for breakthrough AI research.", base: 2_500_000,
                            real: "Horizon 2020 / Horizon Europe (EIC)"),
                HQProgramme(kind: .grant, name: "Industry 4.0 competence-centre call", pitch: "Co-funding for AI pilots with manufacturers through a national competence centre.", base: 3_000_000,
                            from: 2018.5, real: "Italy's Industry 4.0 competence centres, from 2018"),
                HQProgramme(kind: .compute, name: "EuroHPC allocation on the Italian supercomputer", pitch: "Free GPU hours on the Italian EuroHPC supercomputer for an AI startup.", base: 900_000,
                            from: 2023.0, real: "EuroHPC access on Leonardo (Bologna), from 2023"),
                HQProgramme(kind: .contract, name: "public administration AI", pitch: "Ministries want Italian-language assistants for courts, health and tax administration.", base: 0),
            ],
            affinities: [HQAffinity(product: "robotics", relief: 6, pull: 1.25, partner: "Italian machine-tool and robotics makers")],
            pros: ["Frontier-lab pay well under half of San Francisco's", "Industrial partners: robotics products unlock sooner and sell better", "R&D credit that offsets payroll taxes, so it pays while you make losses", "Strong engineering universities (Politecnico di Milano, Torino)", "Solar power contracts for a Milan datacenter"],
            cons: ["≈27.9% tax (IRES + IRAP) and high employer contributions", "Some of Europe's most expensive electricity and a long grid queue", "Smaller VC market than Paris or London", "A strict data-protection authority"],
            strategies: ["Pick Turin and steer research toward embodied models for an early Robotics Brain", "Milan for investors and enterprise sales", "Rome for public-sector and defence contracts"],
            sources: "Tax: IRES 24% + IRAP 3.9% (OECD 2024). R&D: credito d'imposta R&S 10%, €5M cap (Law 160/2019 as amended). Pay: Levels.fyi, Eurostat SES. Rent: CBRE/JLL Milan & Rome 2024. Power: Eurostat nrg_pc_205, 2024-S2 (PUN-indexed).",
            rdScheme: .payrollOffset, rdCreditCapYear: 5_400_000, socialContributions: 0.30,
            character: [0, 5, 0, 8, 3, -8, -10],
            characterWhy: ["", "state-owned groups as customers", "", "a strict data-protection authority", "a national AI law", "slow work-permit quotas", "gas-indexed power and slow permits"],
            diffusionTier: 1),
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
            overview: "France wants a national AI champion and pays for it: a research tax credit that refunds a large slice of research spending, public supercomputer time and sovereign contracts. Paris has the deepest pool of AI researchers on the continent and EDF sells long-term nuclear power, but employer contributions push the true cost of every hire up by a third.",
            corporateTax: 0.258, rdCredit: 0.30, rdRefundable: true, salary: 0.55, employerCost: 0.35, investorDepth: 0.94,
            talentPool: 0.9, brainDrain: 1.1, specialties: [.researcher, .mlEngineer], power: 0.105, homeLocation: "fr_rhone", buildCost: 0.90,
            homeStanding: 12, usStanding: -3, grantRate: 0.10, contractAffinity: 1.0,
            programmes: [
                HQProgramme(kind: .grant, name: "EU frontier research grant", pitch: "A Horizon-style European grant for breakthrough AI research.", base: 2_500_000,
                            real: "Horizon 2020 / Horizon Europe (EIC)"),
                HQProgramme(kind: .grant, name: "Compute 2030 AI-cluster call", pitch: "National investment-plan money for AI champions that train in France.", base: 6_000_000,
                            from: 2021.8, real: "France 2030 (October 2021) AI calls"),
                HQProgramme(kind: .compute, name: "national public supercomputer allocation", pitch: "Free GPU hours on France's public research supercomputer.", base: 1_200_000,
                            from: 2020.0, real: "GENCI's Jean Zay, from 2020"),
                HQProgramme(kind: .contract, name: "sovereign AI for the state", pitch: "Ministries want a French model hosted in France for administration and defence.", base: 0),
            ],
            affinities: [HQAffinity(product: "government", relief: 6, pull: 1.3, partner: "the French state and defence primes")],
            pros: ["Biggest AI research pool in continental Europe", "Research tax credit (CIR): 30% of R&D spend up to €100M a year, cash while you're small", "Most grants and public compute; sovereign contracts at home", "Long-term nuclear power contracts for datacenters"],
            cons: ["Employer contributions add ≈35% on top of salaries", "≈25.8% corporate tax", "Paris rents are close to San Francisco's", "The CIR drops to 5% above €100M of R&D spend a year"],
            strategies: ["Lean on research: the CIR makes researchers cheaper than they look", "Build your first campus on a nuclear contract in the Rhône valley", "Grenoble if you plan to design your own chips"],
            sources: "Tax: 25% + 3.3% CSB (OECD 2024). CIR: Code général des impôts art. 244 quater B (30% to €100M, 5% above). Pay: Levels.fyi Paris. Rent: Cushman & Wakefield Paris 2024. Power: Eurostat nrg_pc_205, 2024-S2; EDF ARENH and its long-term nuclear allocation contracts.",
            rdScheme: .refundable, rdCapYear: 108_000_000, rdAbove: 0.05, socialContributions: 0.42,
            character: [12, 15, 0, 0, -5, 3, 8],
            characterWhy: ["France 2030 and national AI clusters", "a sovereign-AI push for the state and defence", "", "", "lobbied for lighter rules on general-purpose models", "the French Tech Visa", "nuclear power and fast-tracked datacenter sites"],
            diffusionTier: 1),
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
            overview: "A small, high-trust, high-wage economy that runs largely on wind. Danish datacenters get cheap wind contracts and free cooling, Odense's robotics cluster and Copenhagen's life-science industry are natural partners, and employer contributions are among the lowest in Europe. The catch: a small talent pool until your name carries abroad.",
            corporateTax: 0.22, rdCredit: 0.07, rdRefundable: true, salary: 0.62, employerCost: -0.06, investorDepth: 0.9,
            talentPool: 0.65, brainDrain: 0.85, specialties: [.researcher, .data], power: 0.085, homeLocation: "dk_jutland", buildCost: 0.93,
            homeStanding: 10, usStanding: -2, grantRate: 0.08, contractAffinity: 0.6,
            programmes: [
                HQProgramme(kind: .grant, name: "EU frontier research grant", pitch: "A Horizon-style European grant for breakthrough AI research.", base: 2_500_000,
                            real: "Horizon 2020 / Horizon Europe (EIC)"),
                HQProgramme(kind: .grant, name: "national innovation fund grand-solutions grant", pitch: "Co-funding for an ambitious research partnership with Danish universities.", base: 4_000_000,
                            real: "Innovation Fund Denmark Grand Solutions"),
                HQProgramme(kind: .compute, name: "national AI supercomputer allocation", pitch: "GPU time on Denmark's national AI supercomputer, funded by a life-science foundation.", base: 1_000_000,
                            from: 2024.8, real: "Gefion (Danish Centre for AI Innovation), from October 2024"),
                HQProgramme(kind: .contract, name: "Danish public sector AI", pitch: "Municipalities and the health service want a Danish-language assistant.", base: 0),
            ],
            affinities: [HQAffinity(product: "health", relief: 4, pull: 1.15, partner: "Danish hospitals and pharma")],
            pros: ["Cheap wind contracts and free cooling for datacenters", "Lowest employer contributions in this list; 22% tax", "Robotics (Odense) and life-science (Copenhagen) partners", "Talent is happy to stay: less poaching than in San Francisco", "R&D losses partly refunded in cash"],
            cons: ["Smallest talent pool per city", "Salaries well above the rest of Europe", "Small home market and government: national contracts are worth less"],
            strategies: ["Build datacenters at home: wind PPAs and the coldest air in this list", "Odense for an early Robotics Brain; Copenhagen for Discovery and Healthcare", "Grow the team slowly and keep it; open a satellite office when you outgrow the pool"],
            sources: "Tax: 22% selskabsskat (OECD 2024). R&D: enhanced deduction and skattekredit (Ligningsloven §8B, §8X). Pay: Levels.fyi Copenhagen. Rent: Sadolin & Albæk / Colliers Denmark 2024. Power: Nord Pool DK1, Eurostat nrg_pc_205 2024-S2.",
            rdScheme: .lossRefund, rdRefundCapYear: 800_000, socialContributions: 0.02,
            character: [5, -5, 0, 3, 2, -2, 12],
            characterWhy: ["foundation-funded national compute", "a small state customer", "", "", "", "a restrictive immigration policy", "wind power and fast grid connections"],
            diffusionTier: 1),
    ]

    static let byID: [String: HQCountry] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func get(_ id: String) -> HQCountry { byID[id] ?? us }

    /// The country a datacenter location is in (nil: none of the headquarters countries).
    static func country(ofLocation id: String) -> HQCountry? {
        all.first { $0.id != "us" && $0.homeLocation == id }
    }
}

// MARK: - European datacenter locations (3.5)
//
// Kept in their own block so other location changes merge cleanly. Grid prices are 2024-S2 large-consumer rates
// [POWER]; the cheaper long-term contracts (wind, nuclear, hydro, solar) are signed separately on the Datacenters page.
// Mapped to the EU region in `Region.locations`.
extension LocationCatalog {
    static let european: [Location] = [
        Location(id: "dk_jutland", name: "Fredericia, Denmark", region: "Nordics", powerPrice: 0.078, pueDelta: -0.07, buildSpeed: 0.9,
                 gridCapMW: 700, coloFee: 165, image: "dc_foulum",
                 blurb: "Wind-powered Jutland: wind PPAs, cold air and waste heat sold to the district-heating grid. Hyperscalers already build here.",
                 photoShowsPlace: true),
        Location(id: "fr_rhone", name: "Rhône Valley, France", region: "France", powerPrice: 0.082, pueDelta: -0.02, buildSpeed: 0.85,
                 gridCapMW: 1_500, coloFee: 160, image: "loc_rhone",
                 blurb: "Next to the Rhône's nuclear plants: EDF sells long-term nuclear contracts here and the grid was built for heavy industry.",
                 photoShowsPlace: true),
        Location(id: "it_milan", name: "Milan, Italy", region: "Italy", powerPrice: 0.140, pueDelta: 0.03, buildSpeed: 0.75,
                 gridCapMW: 700, coloFee: 175, image: "hq_milan",
                 blurb: "Italy's datacenter hub with great connectivity to southern Europe, but gas-indexed power is expensive, solar contracts help and the grid queue is long.",
                 photoShowsPlace: true),
        Location(id: "ro_bucharest", name: "Bucharest, Romania", region: "Romania", powerPrice: 0.105, pueDelta: 0.02, buildSpeed: 1.05,
                 gridCapMW: 400, coloFee: 105, image: "hq_bucharest",
                 blurb: "Cheap land and labour, quick construction and a hydro-and-nuclear grid with hydro contracts on offer. A smaller grid and hot summers.",
                 photoShowsPlace: true),
    ]
}

// MARK: - Previews (selection screen and harness)

extension HQCountry {
    /// Frontier-lab pay for ordinary hires in a city relative to San Francisco.
    func pay(_ city: HQCity) -> Double { id == "us" ? 1 : salary * city.salary }

    /// What a hire really costs per San Francisco salary dollar, with employer on-costs (before any R&D relief, which
    /// depends on profits and caps: see `rdScheme`).
    func netPayrollFactor(_ city: HQCity) -> Double { pay(city) * (1 + employerCost) }

    /// Candidates on the market at once with a small, unknown team (San Francisco: 8).
    func candidates(_ city: HQCity) -> Int { id == "us" ? 8 : max(4, Int((8 * talentPool * city.talent).rounded())) }

    /// Pay for hires who relocate from abroad: the international rate, halfway to San Francisco's.
    func relocationPay(_ city: HQCity) -> Double { id == "us" ? 1 : (1 + pay(city)) / 2 }

    var location: Location? { LocationCatalog.byID[homeLocation] }

    /// Share of the world AI market buying here (national contracts scale with it).
    var homeMarket: Double { Corporate.marketWeights[id] ?? 0.02 }

    /// A first year with the two founders plus six ordinary hires and the startup office, at the era's prices: payroll
    /// with on-costs, rent, and what the R&D relief would be worth (cash only under schemes that pay while loss-making).
    func yearOne(_ city: HQCity, year y: Double) -> (payroll: Double, office: Double, rdRelief: Double) {
        let roles: [(Role, Double)] = [(.researcher, 0.8), (.mlEngineer, 0.8), (.researcher, 1), (.researcher, 1), (.mlEngineer, 1),
                                       (.mlEngineer, 1), (.infra, 1), (.data, 1)]
        let gross = roles.reduce(0.0) { $0 + Macro.salary($1.0, y) * $1.1 } * pay(city)
        let payroll = gross * (1 + employerCost)
        let office = Economy.officeLevels[1].monthly * (id == "us" ? 1 : city.office) * 12
        var relief = payroll * rdCredit
        switch rdScheme {
        case .none, .againstProfit: relief = 0
        case .payrollOffset: relief = min(relief, rdCreditCapYear > 0 ? rdCreditCapYear : relief)
        case .lossRefund: relief = min(payroll * 0.22, rdRefundCapYear > 0 ? rdRefundCapYear : payroll)
        case .refundable: break
        }
        return (payroll, office, relief)
    }

    /// Grant and compute-allocation offers a year you can expect at `y`, from the same rules the game uses: a monthly
    /// chance (`grantRate`, moved by national policy) once three months have passed since the last offer, and only while
    /// a programme exists. Years with a partnership or contract offer have fewer.
    func expectedGrantsPerYear(_ y: Double, policy: Double = 1) -> Double {
        guard programmes.contains(where: { $0.kind != .contract && y >= $0.from }) else { return 0 }
        let p = min(0.9, grantRate * policy)
        guard p > 0 else { return 0 }
        return 12 / (3 + 1 / p)
    }

    /// Grant offers a year for a new company founded at `y`: the same rules, with national research funding where a new
    /// game starts it (the region's dial at that date plus this country's character).
    func expectedGrantsAtStart(_ y: Double) -> Double {
        let region = Nations.baseline(self.region, y)
        let subsidy = (region.indices.contains(NationLever.subsidy.index) ? region[NationLever.subsidy.index] : 50)
            + (character.indices.contains(NationLever.subsidy.index) ? character[NationLever.subsidy.index] * Nations.salience(y) : 0)
        return expectedGrantsPerYear(y, policy: 0.6 + 0.8 * clamp(subsidy, 0, 100) / 100)
    }

    var regionLabel: String { region == .eu ? "EU · AI Act" : region.short }
}
