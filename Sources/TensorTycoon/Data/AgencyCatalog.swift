import Foundation

// MARK: - 3.5: Advanced Projects — agencies and the programmes they buy

/// What kind of government body an agency is (drives its classification habits and how its budget reacts to the world).
enum AgencyKind: String, Sendable {
    case defence, intelligence, cyber, energy, nationalLab, space, health, research, safety, sovereign, industry, digital

    var label: String {
        switch self {
        case .defence: "Defence research"
        case .intelligence: "Intelligence research"
        case .cyber: "Cyber security"
        case .energy: "Energy & science"
        case .nationalLab: "National laboratory"
        case .space: "Space agency"
        case .health: "Health research"
        case .research: "Research council"
        case .safety: "AI safety institute"
        case .sovereign: "Sovereign technology fund"
        case .industry: "Industrial policy"
        case .digital: "Digital public services"
        }
    }

    /// How strongly its budget follows public safety concern (defence and safety bodies get more when people worry).
    var concernSensitivity: Double {
        switch self {
        case .defence, .intelligence, .cyber, .safety: 0.5
        case .health: 0.2
        default: 0
        }
    }

    /// How strongly its budget follows how strict the region's AI rules are (rule-makers fund evaluation and assurance).
    var rulesSensitivity: Double {
        switch self {
        case .safety: 0.8
        case .research, .health, .digital: 0.2
        default: 0
        }
    }
}

/// A fictional government agency that posts AI contracts. Names are invented; they are analogues, not the real bodies.
struct AgencyDef: Identifiable, Sendable {
    let id: String
    let name: String
    let short: String
    let region: Region
    let kind: AgencyKind
    let symbol: String
    /// Annual AI-programme budget in units of `AdvancedProjects.budgetScale` (1 ≈ a large US research agency).
    let budget: Double
    let blurb: String
    /// A national agency's country (HQ country code); empty for a region-wide body. Its Secret and Top Secret work is
    /// open only to labs headquartered in that country, and home labs get a preference in evaluation.
    var country: String = ""
    /// The national-strategy dial its budget follows on top of the sovereign-AI programme (none: sovereign only).
    var lever: NationLever? = nil

    /// "France" for a national agency, else the region.
    var homeName: String { country.isEmpty ? region.title : CountryCatalog.get(country).name }
    var homeShort: String { country.isEmpty ? region.short : CountryCatalog.get(country).name }
}

/// How a proposal is scored.
enum EvaluationBasis: String, Codable, Sendable {
    case bestValue, technical, lowestPrice

    var label: String {
        switch self {
        case .bestValue: "Best value (technical, price and record)"
        case .technical: "Technical merit first"
        case .lowestPrice: "Lowest price, technically acceptable"
        }
    }

    /// Weights on technical score, price score and past performance.
    var weights: (tech: Double, price: Double, past: Double) {
        switch self {
        case .bestValue: (1.0, 0.8, 0.5)
        case .technical: (1.4, 0.35, 0.6)
        case .lowestPrice: (0.45, 1.6, 0.3)
        }
    }
}

/// A kind of programme an agency buys. Solicitations are drawn from these and sized to the agency's budget and the year.
struct ProgrammeTemplate: Identifiable, Sendable {
    let id: String
    let title: String
    let agencies: [String]
    let year: Double
    let objective: String
    /// Domain mix the work leans on: thresholds are set on these domains, and progress depends on your margin over them.
    let domains: [CapDomain]
    /// How far below the state of the art (domain points) the bar sits: big for seedlings, small for frontier work.
    let gap: Double
    let research: [String]
    let types: [ContractType]
    let ip: [IPTerms]
    /// 0 unclassified, 1 controlled (CUI), 2 Secret, 3 Top Secret/SCI.
    let classification: Int
    /// Share of the agency's annual AI budget a typical award takes.
    let size: Double
    let months: Int
    /// Staff mix (role, weight): cleared staff counts are split this way.
    let staff: [(Role, Double)]
    /// Compute as a share of the estimated cost (the rest is people, materials and test).
    let computeShare: Double
    /// Base odds that an experiment, prototype or test campaign fails and needs rework.
    let risk: Double
    let basis: EvaluationBasis
    /// Permanent research effects a finished programme can carry (at full strength when you can use it commercially).
    let effects: [ResearchEffect]
    /// A research item it hands you for free when it completes (credited and put first in your queue).
    let unlock: String?
    /// A discovery commercial labs would want — classified programmes raise a secrecy decision about it.
    let discovery: String?
    /// The moonshot field it helps (adds research to a running moonshot of that field).
    let field: String?
    let image: String
    /// What it leaves behind, in a phrase.
    let reward: String
    /// The programme topic (the research areas agencies buy: secure communications, advanced cooling …).
    var topic: String = ""
    /// Lasting effects on your other systems (power bill, chip yields, grid costs, government demand, public trust).
    var legacy: [ProgrammeLegacy] = []
    /// A facility the work needs (one bay, bench or enclave accredited at the programme's level, CUI at least).
    var facility: FacilityKind? = nil
    /// The science field its discoveries belong to (they lift your science labs' momentum there once cleared).
    var sciField: SciField? = nil
}

/// What a finished programme leaves in the rest of the company, beyond research effects. Each is scaled by how much of
/// the result you may use (`Programme.effectScale`), the strongest result per programme kind counts, and totals are capped.
enum ProgrammeLegacy: Sendable {
    /// Share off your datacenter power bill (better cooling: lower PUE).
    case powerBill(Double)
    /// Share off defect density at foundries and your own fabs (better yields).
    case defects(Double)
    /// Share off the board power of your inference-focused custom chips.
    case edgeChips(Double)
    /// Share of the grid-stress premium on datacenter power you no longer pay.
    case gridRelief(Double)
    /// Extra pull for the Government & Defence product line (sovereign and agency buyers).
    case governmentPull(Double)
    /// Points of public trust.
    case publicTrust(Double)

    /// Legacies you keep when a result is retained for internal use only (no products, no publicity).
    var internalUse: Bool {
        switch self {
        case .powerBill, .defects, .edgeChips, .gridRelief: true
        case .governmentPull, .publicTrust: false
        }
    }

    func describe(_ scale: Double = 1) -> String {
        func pct(_ v: Double) -> String { "\(Fmt.trim(v * scale * 100, 1))%" }
        switch self {
        case .powerBill(let v): return "datacenter power bill −\(pct(v)) (better cooling)"
        case .defects(let v): return "chip defect density −\(pct(v)) at foundries and your fabs"
        case .edgeChips(let v): return "inference-chip board power −\(pct(v))"
        case .gridRelief(let v): return "grid-stress power premium −\(pct(v))"
        case .governmentPull(let v): return "Government & Defence line pull +\(pct(v))"
        case .publicTrust(let v): return "public trust +\(Fmt.trim(v * scale, 1))"
        }
    }
}

enum AgencyCatalog {
    static let all: [AgencyDef] = [
        AgencyDef(id: "oadr", name: "Office of Advanced Defense Research", short: "OADR", region: .us, kind: .defence, symbol: "shield.lefthalf.filled",
                  budget: 1.0, blurb: "The defence department's high-risk research arm: autonomy, logistics and decision support, much of it classified."),
        AgencyDef(id: "iaro", name: "Intelligence Advanced Research Office", short: "IARO", region: .us, kind: .intelligence, symbol: "eye.trianglebadge.exclamationmark",
                  budget: 0.6, blurb: "Funds research for the intelligence community: language, imagery and analysis tools, nearly always behind a clearance."),
        AgencyDef(id: "ncra", name: "National Cyber Resilience Agency", short: "NCRA", region: .us, kind: .cyber, symbol: "lock.shield.fill",
                  budget: 0.35, blurb: "Protects civilian networks and critical infrastructure; buys vulnerability discovery and automated defence."),
        AgencyDef(id: "feso", name: "Federal Energy Science Office", short: "FESO", region: .us, kind: .energy, symbol: "bolt.fill",
                  budget: 0.7, blurb: "Runs the national science user facilities and pays for AI that speeds up energy, materials and climate research."),
        AgencyDef(id: "meridian", name: "Meridian National Laboratory", short: "Meridian", region: .us, kind: .nationalLab, symbol: "atom",
                  budget: 0.45, blurb: "A government-owned laboratory with exascale machines and a stewardship mission; some of its work is Secret."),
        AgencyDef(id: "naoa", name: "National Aeronautics & Orbital Agency", short: "NAOA", region: .us, kind: .space, symbol: "globe.americas.fill",
                  budget: 0.4, blurb: "Space and aeronautics: autonomous rovers, mission planning and Earth observation."),
        AgencyDef(id: "nhri", name: "National Health Research Institutes", short: "NHRI", region: .us, kind: .health, symbol: "cross.case.fill",
                  budget: 0.55, blurb: "Medical research and biodefence: protein design, clinical decision support, countermeasures."),
        AgencyDef(id: "efrc", name: "European Frontier Research Council", short: "EFRC", region: .eu, kind: .research, symbol: "star.circle.fill",
                  budget: 0.4, blurb: "Grants and prizes for open science across the EU. Pays less, but you keep what you discover."),
        AgencyDef(id: "edif", name: "European Defence Innovation Fund", short: "EDIF", region: .eu, kind: .defence, symbol: "shield.fill",
                  budget: 0.35, blurb: "Pools member states' defence research money. Classified work goes to European labs only."),
        AgencyDef(id: "ukaia", name: "UK Advanced Invention Agency", short: "UKAIA", region: .uk, kind: .research, symbol: "lightbulb.max.fill",
                  budget: 0.15, blurb: "Small, fast and fond of prize challenges and moonshot grants."),
        AgencyDef(id: "fsi", name: "Frontier Safety Institute", short: "FSI", region: .uk, kind: .safety, symbol: "checkmark.shield.fill",
                  budget: 0.12, blurb: "Commissions evaluations of frontier models — dangerous capabilities, cyber and autonomy — under controlled access."),
        AgencyDef(id: "gsta", name: "Gulf Sovereign Technology Authority", short: "GSTA", region: .gulf, kind: .sovereign, symbol: "building.columns.fill",
                  budget: 0.5, blurb: "Deep pockets and a national-champion agenda: sovereign language models and government services."),
        AgencyDef(id: "paia", name: "Pacific Advanced Industry Agency", short: "PAIA", region: .japanKorea, kind: .industry, symbol: "gearshape.2.fill",
                  budget: 0.3, blurb: "Japanese and Korean industrial policy: factory robotics, chips and an ageing workforce."),
        AgencyDef(id: "ndma", name: "National Digital Mission Authority", short: "NDMA", region: .india, kind: .digital, symbol: "person.3.fill",
                  budget: 0.2, blurb: "Public digital infrastructure for a billion people in two dozen languages. Price matters."),
        // European and national agencies: an EU headquarters has its own defence, space, science and digital buyers.
        AgencyDef(id: "ceri", name: "Council for European Research Infrastructures", short: "CERI", region: .eu, kind: .research, symbol: "building.2.fill",
                  budget: 0.3, blurb: "Funds the continent's shared supercomputers, light sources and test beds, and the AI that runs them. Grants, mostly open.",
                  lever: .subsidy),
        AgencyDef(id: "esca", name: "European Secure Connectivity Agency", short: "ESCA", region: .eu, kind: .space, symbol: "antenna.radiowaves.left.and.right",
                  budget: 0.25, blurb: "Builds the Union's own secure satellite constellation and the ground systems around it. Secret work goes to European labs.",
                  lever: .sovereign),
        AgencyDef(id: "dgpa", name: "Direction Générale des Programmes Avancés", short: "DGPA", region: .eu, kind: .defence, symbol: "shield.lefthalf.filled",
                  budget: 0.3, blurb: "France's defence procurement and innovation directorate: autonomy, secure communications and sovereign models, much of it classified.",
                  country: "fr", lever: .sovereign),
        AgencyDef(id: "cneo", name: "Centre National d'Études Orbitales", short: "CNEO", region: .eu, kind: .space, symbol: "globe.europe.africa.fill",
                  budget: 0.2, blurb: "The French space agency: launchers, Earth observation and the constellations the armed forces depend on.",
                  country: "fr", lever: .subsidy),
        AgencyDef(id: "cra", name: "Commissariat aux Recherches Avancées", short: "CRA", region: .eu, kind: .nationalLab, symbol: "atom",
                  budget: 0.25, blurb: "A national laboratory for energy, materials and microelectronics, with clean rooms, reactors and a stewardship mission.",
                  country: "fr", lever: .energy),
        AgencyDef(id: "aoi", name: "Agenzia Orbitale Italiana", short: "AOI", region: .eu, kind: .space, symbol: "sparkles",
                  budget: 0.15, blurb: "Italy's space agency: Earth observation, satellite communications and civil protection from orbit.",
                  country: "it", lever: .subsidy),
        AgencyDef(id: "cnci", name: "Centro Nazionale di Competenza Industriale", short: "CNCI", region: .eu, kind: .industry, symbol: "gearshape.2.fill",
                  budget: 0.15, blurb: "Italian industrial policy: robots, machine tools and semiconductor lines, co-funded with manufacturers.",
                  country: "it", lever: .subsidy),
        AgencyDef(id: "dfgi", name: "Danish Fund for Green Innovation", short: "DFGI", region: .eu, kind: .energy, symbol: "wind",
                  budget: 0.15, blurb: "Pays for the energy transition: grids, wind, district cooling and the AI that keeps them balanced.",
                  country: "dk", lever: .energy),
        AgencyDef(id: "ansd", name: "Autoritatea Națională pentru Securitate Digitală", short: "ANSD", region: .eu, kind: .cyber, symbol: "lock.shield.fill",
                  budget: 0.12, blurb: "Romania's digital-security authority: cyber defence for the state, post-quantum migration and a national cyber range.",
                  country: "ro", lever: .sovereign),
    ]

    static let byID: [String: AgencyDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static let templates: [ProgrammeTemplate] = [
        // Seedlings: small first contracts any capable lab can win (Phase I style).
        ProgrammeTemplate(id: "seedling", title: "Seedling feasibility study", agencies: all.map(\.id), year: 2016,
                          objective: "Show in six months that a modern model can do a narrowly defined task the agency cares about, and report what a full programme would take.",
                          domains: [.reasoning, .knowledge], gap: 28, research: [], types: [.grant, .fixedPrice], ip: [.licence, .shared], classification: 0,
                          size: 0.002, months: 6, staff: [(.researcher, 0.7), (.mlEngineer, 0.3)], computeShare: 0.25, risk: 0.12, basis: .bestValue,
                          effects: [.rp(0.01)], unlock: nil, discovery: nil, field: nil, image: "server_room",
                          reward: "a past-performance record with the agency and a small research boost", topic: "Feasibility study"),
        ProgrammeTemplate(id: "logistics", title: "Autonomous logistics planning", agencies: ["oadr", "edif", "dgpa"], year: 2019,
                          objective: "Plan and re-plan supply movements for thousands of units under disruption, with a human approving every plan.",
                          domains: [.reasoning, .agents], gap: 14, research: ["rag"], types: [.fixedPrice, .costPlus], ip: [.government, .licence], classification: 2,
                          size: 0.05, months: 24, staff: [(.researcher, 0.4), (.mlEngineer, 0.4), (.infra, 0.2)], computeShare: 0.3, risk: 0.22, basis: .bestValue,
                          effects: [.domain(.agents, 0.06), .enterpriseDemand(0.04)], unlock: "tool_use", discovery: "long-horizon planning under uncertainty", field: nil,
                          image: "dc_rows", reward: "better agents and enterprise planning customers", topic: "Defence autonomy"),
        ProgrammeTemplate(id: "translation", title: "Multilingual intelligence triage", agencies: ["iaro"], year: 2018,
                          objective: "Triage foreign-language reporting in forty languages, flagging what an analyst must read today.",
                          domains: [.knowledge, .reasoning], gap: 12, research: ["multilingual"], types: [.costPlus, .fixedPrice], ip: [.government], classification: 3,
                          size: 0.06, months: 20, staff: [(.researcher, 0.4), (.data, 0.3), (.mlEngineer, 0.3)], computeShare: 0.35, risk: 0.18, basis: .technical,
                          effects: [.skill(.lang, 0.06), .domain(.knowledge, 0.04)], unlock: nil, discovery: "low-resource language transfer", field: nil,
                          image: "network", reward: "stronger multilingual models", topic: "Language intelligence"),
        ProgrammeTemplate(id: "imagery", title: "Overhead imagery analysis", agencies: ["iaro", "naoa", "cneo", "esca"], year: 2020.5,
                          objective: "Find, count and describe objects in satellite and aerial imagery across a continent, every day.",
                          domains: [.vision, .knowledge], gap: 12, research: ["vit"], types: [.costPlus, .fixedPrice], ip: [.government, .licence], classification: 2,
                          size: 0.05, months: 18, staff: [(.researcher, 0.4), (.mlEngineer, 0.3), (.data, 0.3)], computeShare: 0.35, risk: 0.18, basis: .technical,
                          effects: [.domain(.vision, 0.07)], unlock: nil, discovery: "self-supervised remote sensing", field: "Climate",
                          image: "supercomputer", reward: "better vision models and Earth-observation know-how", topic: "Environmental observation"),
        ProgrammeTemplate(id: "vulns", title: "Automated vulnerability discovery", agencies: ["ncra", "fsi", "ansd"], year: 2021.5,
                          objective: "Find and patch exploitable bugs in open-source code the country runs on, before attackers do.",
                          domains: [.coding, .agents], gap: 12, research: ["code_data"], types: [.fixedPrice, .prize], ip: [.licence, .shared], classification: 1,
                          size: 0.06, months: 15, staff: [(.researcher, 0.3), (.mlEngineer, 0.4), (.safety, 0.3)], computeShare: 0.3, risk: 0.2, basis: .bestValue,
                          effects: [.securityCost(0.12), .domain(.coding, 0.05)], unlock: "vuln_discovery", discovery: nil, field: "Security",
                          image: "rack_rear", reward: "cheaper weight security and better coding models", topic: "Cyber defence"),
        ProgrammeTemplate(id: "cyberdefense", title: "Critical-infrastructure cyber defence", agencies: ["ncra", "oadr", "ansd"], year: 2024.5,
                          objective: "Agents that watch grid, water and hospital networks and contain intrusions in minutes, with operators in the loop.",
                          domains: [.coding, .agents, .reasoning], gap: 10, research: ["tool_use"], types: [.costPlus, .fixedPrice], ip: [.government, .shared], classification: 1,
                          size: 0.07, months: 24, staff: [(.mlEngineer, 0.4), (.safety, 0.3), (.infra, 0.3)], computeShare: 0.3, risk: 0.24, basis: .bestValue,
                          effects: [.securityCost(0.15), .safety(2)], unlock: "cyber_defense", discovery: nil, field: "Security",
                          image: "power_lines", reward: "cheaper security, a better safety record and goodwill", topic: "Cyber defence"),
        ProgrammeTemplate(id: "fusionsim", title: "Plasma and materials simulation", agencies: ["feso", "efrc", "paia", "cra", "ceri"], year: 2019.5,
                          objective: "Learned surrogates that run plasma and materials simulations a thousand times faster at useful accuracy.",
                          domains: [.science, .math], gap: 14, research: [], types: [.grant, .costPlus], ip: [.licence, .shared], classification: 0,
                          size: 0.04, months: 24, staff: [(.researcher, 0.6), (.infra, 0.2), (.mlEngineer, 0.2)], computeShare: 0.45, risk: 0.2, basis: .technical,
                          effects: [.rp(0.03), .domain(.science, 0.05)], unlock: nil, discovery: nil, field: "Energy",
                          image: "power_fusion", reward: "faster research and better science models", topic: "Scientific AI"),
        ProgrammeTemplate(id: "stewardship", title: "Stewardship surrogate models", agencies: ["meridian", "cra"], year: 2021,
                          objective: "Replace weeks of exascale simulation with verified learned surrogates for the stockpile stewardship mission.",
                          domains: [.science, .math, .coding], gap: 12, research: ["mixed_precision"], types: [.costPlus], ip: [.government], classification: 2,
                          size: 0.08, months: 30, staff: [(.researcher, 0.5), (.infra, 0.3), (.mlEngineer, 0.2)], computeShare: 0.5, risk: 0.22, basis: .technical,
                          effects: [.scaleOut(0.08), .mfu(0.02)], unlock: nil, discovery: "verified physics surrogates at exascale", field: "Energy",
                          image: "natlab_ornl", reward: "better scale-out on big clusters", topic: "Advanced computing"),
        ProgrammeTemplate(id: "codemod", title: "Exascale code modernisation", agencies: ["feso", "meridian", "ceri"], year: 2022.5,
                          objective: "Port and verify millions of lines of legacy scientific Fortran onto modern accelerators.",
                          domains: [.coding, .reasoning], gap: 14, research: ["code_data"], types: [.fixedPrice, .costPlus], ip: [.shared, .licence], classification: 0,
                          size: 0.04, months: 18, staff: [(.mlEngineer, 0.5), (.researcher, 0.3), (.infra, 0.2)], computeShare: 0.3, risk: 0.16, basis: .lowestPrice,
                          effects: [.mfu(0.02), .domain(.coding, 0.04)], unlock: "kernel_compilers", discovery: nil, field: nil,
                          image: "hpc_frontier", reward: "faster kernels and better coding models", topic: "Advanced computing"),
        ProgrammeTemplate(id: "rover", title: "Autonomous rover navigation", agencies: ["naoa", "paia", "ukaia", "cneo", "aoi"], year: 2020,
                          objective: "Drive a planetary rover kilometres a day with no human in the loop, through terrain nobody has mapped.",
                          domains: [.robotics, .vision, .agents], gap: 14, research: ["sim_to_real"], types: [.grant, .fixedPrice], ip: [.licence, .shared], classification: 0,
                          size: 0.05, months: 24, staff: [(.researcher, 0.5), (.mlEngineer, 0.3), (.infra, 0.2)], computeShare: 0.3, risk: 0.26, basis: .technical,
                          effects: [.domain(.robotics, 0.08), .domain(.vision, 0.03)], unlock: nil, discovery: nil, field: "Robotics",
                          image: "solar_farm", reward: "better robotics and vision", topic: "Aerospace"),
        ProgrammeTemplate(id: "missionplan", title: "Mission-planning copilot", agencies: ["naoa", "oadr", "cneo"], year: 2023.5,
                          objective: "A copilot that drafts, checks and explains complex mission plans for crews and operators.",
                          domains: [.reasoning, .agents, .knowledge], gap: 12, research: ["cot"], types: [.fixedPrice, .costPlus], ip: [.licence, .government], classification: 1,
                          size: 0.04, months: 18, staff: [(.researcher, 0.4), (.mlEngineer, 0.4), (.safety, 0.2)], computeShare: 0.3, risk: 0.18, basis: .bestValue,
                          effects: [.domain(.reasoning, 0.04), .enterpriseDemand(0.03)], unlock: nil, discovery: nil, field: nil,
                          image: "network", reward: "reasoning gains and enterprise customers", topic: "Aerospace"),
        ProgrammeTemplate(id: "countermeasures", title: "Pathogen countermeasure design", agencies: ["nhri", "efrc", "cra"], year: 2021,
                          objective: "Design candidate antibodies and antivirals against a panel of threat pathogens, with biosafety review at every step.",
                          domains: [.science, .knowledge], gap: 12, research: ["alphafold"], types: [.grant, .costPlus], ip: [.licence, .shared], classification: 1,
                          size: 0.05, months: 24, staff: [(.researcher, 0.5), (.safety, 0.3), (.data, 0.2)], computeShare: 0.35, risk: 0.24, basis: .technical,
                          effects: [.safety(2), .domain(.science, 0.05)], unlock: "protein_design", discovery: nil, field: "Medicine",
                          image: "lab_biology", reward: "a better safety record and science models", topic: "Scientific AI"),
        ProgrammeTemplate(id: "clinical", title: "Clinical decision support trial", agencies: ["nhri", "gsta"], year: 2023.3,
                          objective: "Run an AI assistant through a supervised multi-hospital trial and prove it improves outcomes.",
                          domains: [.knowledge, .science, .social], gap: 12, research: ["rlhf"], types: [.costPlus, .grant], ip: [.licence, .shared], classification: 0,
                          size: 0.05, months: 24, staff: [(.researcher, 0.3), (.safety, 0.3), (.mlEngineer, 0.2), (.data, 0.2)], computeShare: 0.2, risk: 0.2, basis: .bestValue,
                          effects: [.domain(.knowledge, 0.04), .consumerDemand(0.03)], unlock: "clinical_grounding", discovery: nil, field: "Medicine",
                          image: "server_room", reward: "medical know-how and consumer trust", topic: "Health"),
        ProgrammeTemplate(id: "mathprize", title: "Open mathematics challenge", agencies: ["efrc", "ukaia"], year: 2022,
                          objective: "Solve a published list of open problems with machine-checked proofs. First complete entry takes the purse.",
                          domains: [.math, .reasoning], gap: 8, research: ["cot"], types: [.prize], ip: [.shared], classification: 0,
                          size: 0.08, months: 15, staff: [(.researcher, 0.8), (.mlEngineer, 0.2)], computeShare: 0.45, risk: 0.3, basis: .technical,
                          effects: [.domain(.math, 0.08), .skill(.reasoning, 0.03)], unlock: nil, discovery: nil, field: "Mathematics",
                          image: "wafer_closeup", reward: "prestige and better mathematics", topic: "Scientific AI"),
        ProgrammeTemplate(id: "trustworthy", title: "Trustworthy AI research grant", agencies: ["efrc", "fsi", "ukaia", "ceri"], year: 2023,
                          objective: "Advance interpretability and oversight methods and publish the results openly.",
                          domains: [.reasoning, .knowledge], gap: 14, research: ["red_teaming"], types: [.grant], ip: [.shared], classification: 0,
                          size: 0.03, months: 18, staff: [(.safety, 0.6), (.researcher, 0.4)], computeShare: 0.25, risk: 0.15, basis: .technical,
                          effects: [.safety(3), .agentSafety(0.05)], unlock: "interpretability", discovery: nil, field: nil,
                          image: "network", reward: "a better safety record and researchers' respect", topic: "AI safety & evaluation"),
        ProgrammeTemplate(id: "sovereignllm", title: "Sovereign defence language model", agencies: ["edif", "oadr", "dgpa"], year: 2024,
                          objective: "Train and accredit a model that runs entirely on government hardware and never touches the public internet.",
                          domains: [.knowledge, .reasoning, .coding], gap: 10, research: ["instruction_tuning"], types: [.fixedPrice, .costPlus], ip: [.government], classification: 2,
                          size: 0.08, months: 24, staff: [(.mlEngineer, 0.4), (.researcher, 0.3), (.infra, 0.3)], computeShare: 0.5, risk: 0.2, basis: .bestValue,
                          effects: [.securityCost(0.1), .enterpriseDemand(0.03)], unlock: "sovereign_deploy", discovery: "air-gapped training at scale", field: nil,
                          image: "dc_hall", reward: "air-gapped deployment know-how and regulated-industry customers", topic: "Sovereign AI"),
        ProgrammeTemplate(id: "dexterity", title: "Robot dexterity grand prize", agencies: ["ukaia", "paia", "cnci"], year: 2024.5,
                          objective: "A robot hand that can assemble an unseen device from a parts bin, judged live.",
                          domains: [.robotics, .vision], gap: 6, research: ["sim_to_real"], types: [.prize], ip: [.licence], classification: 0,
                          size: 0.10, months: 18, staff: [(.researcher, 0.5), (.mlEngineer, 0.3), (.infra, 0.2)], computeShare: 0.35, risk: 0.32, basis: .technical,
                          effects: [.domain(.robotics, 0.1)], unlock: nil, discovery: nil, field: "Robotics",
                          image: "robot_humanoid", reward: "a prize purse and much better robotics", topic: "Industrial robotics"),
        ProgrammeTemplate(id: "evalsuite", title: "Frontier model evaluation suite", agencies: ["fsi", "ncra"], year: 2023.8,
                          objective: "Build the government's dangerous-capability evaluations — cyber, bio, autonomy — and run them on frontier models under controlled access.",
                          domains: [.reasoning, .agents, .coding], gap: 8, research: ["red_teaming"], types: [.costPlus], ip: [.government, .shared], classification: 1,
                          size: 0.06, months: 15, staff: [(.safety, 0.6), (.researcher, 0.2), (.mlEngineer, 0.2)], computeShare: 0.3, risk: 0.14, basis: .technical,
                          effects: [.safety(3), .contaminationGuard(0.1)], unlock: "evals_rsp", discovery: nil, field: nil,
                          image: "rack_rear", reward: "a strong safety record and regulators' trust", topic: "AI safety & evaluation"),
        ProgrammeTemplate(id: "arabicllm", title: "National Arabic language model", agencies: ["gsta"], year: 2023,
                          objective: "A national model fluent in Arabic dialects, trained and served inside the country.",
                          domains: [.knowledge, .social], gap: 12, research: ["multilingual"], types: [.costPlus, .fixedPrice], ip: [.licence, .shared], classification: 0,
                          size: 0.06, months: 18, staff: [(.mlEngineer, 0.4), (.data, 0.3), (.researcher, 0.3)], computeShare: 0.5, risk: 0.15, basis: .bestValue,
                          effects: [.skill(.lang, 0.05), .consumerDemand(0.03)], unlock: nil, discovery: nil, field: nil,
                          image: "hyperscale_campus", reward: "multilingual gains and new consumers", topic: "Sovereign AI"),
        ProgrammeTemplate(id: "factory", title: "Factory automation pilot", agencies: ["paia", "cnci"], year: 2025,
                          objective: "Run three production lines with robot foundation models for a year, with uptime guarantees.",
                          domains: [.robotics, .vision, .agents], gap: 10, research: ["embodied_fm"], types: [.fixedPrice, .costPlus], ip: [.licence, .shared], classification: 0,
                          size: 0.08, months: 24, staff: [(.mlEngineer, 0.4), (.researcher, 0.3), (.infra, 0.3)], computeShare: 0.3, risk: 0.24, basis: .bestValue,
                          effects: [.domain(.robotics, 0.08), .enterpriseDemand(0.05)], unlock: nil, discovery: nil, field: "Robotics",
                          image: "robot_factory", reward: "robotics know-how and industrial customers", topic: "Industrial robotics"),
        ProgrammeTemplate(id: "publicservices", title: "Twenty-two-language public services assistant", agencies: ["ndma"], year: 2024,
                          objective: "A voice assistant for government services in every scheduled language, on cheap phones.",
                          domains: [.knowledge, .voice, .social], gap: 14, research: ["multilingual"], types: [.fixedPrice], ip: [.licence, .shared], classification: 0,
                          size: 0.08, months: 18, staff: [(.mlEngineer, 0.4), (.data, 0.4), (.researcher, 0.2)], computeShare: 0.35, risk: 0.16, basis: .lowestPrice,
                          effects: [.skill(.lang, 0.04), .apiDemand(0.03)], unlock: nil, discovery: nil, field: nil,
                          image: "sf_skyline", reward: "multilingual and voice gains, more API customers", topic: "Digital public services"),
        ProgrammeTemplate(id: "unmanned", title: "Collaborative autonomy for unmanned systems", agencies: ["oadr"], year: 2026.5,
                          objective: "Teams of autonomous vehicles that share a plan, adapt when one is lost and always keep a human commander in control.",
                          domains: [.agents, .robotics, .reasoning], gap: 6, research: ["multi_agent"], types: [.costPlus, .fixedPrice], ip: [.government], classification: 3,
                          size: 0.10, months: 30, staff: [(.researcher, 0.4), (.mlEngineer, 0.3), (.safety, 0.3)], computeShare: 0.35, risk: 0.28, basis: .technical,
                          effects: [.domain(.agents, 0.08), .coordination(0.03)], unlock: nil, discovery: "decentralised multi-agent coordination", field: "Robotics",
                          image: "dc_corridor", reward: "much better agent coordination", topic: "Defence autonomy"),
        ProgrammeTemplate(id: "enclave", title: "Secure compute enclave pilot", agencies: ["iaro", "edif", "ansd"], year: 2025,
                          objective: "Prove that frontier models can run on classified networks with hardware-enforced isolation and auditable access.",
                          domains: [.coding, .agents], gap: 10, research: ["confidential_computing"], types: [.costPlus], ip: [.government, .shared], classification: 3,
                          size: 0.06, months: 18, staff: [(.infra, 0.5), (.mlEngineer, 0.3), (.safety, 0.2)], computeShare: 0.45, risk: 0.18, basis: .technical,
                          effects: [.securityCost(0.2)], unlock: nil, discovery: "hardware-enforced model isolation", field: "Security",
                          image: "rack_rear", reward: "much cheaper weight security", topic: "Secure distributed computing"),
        ProgrammeTemplate(id: "climatesim", title: "Kilometre-scale climate emulator", agencies: ["feso", "efrc", "naoa", "dfgi", "esca"], year: 2024,
                          objective: "An emulator of the Earth system at kilometre scale, fast enough to run thousands of scenarios.",
                          domains: [.science, .math, .vision], gap: 10, research: ["graphcast"], types: [.grant, .costPlus], ip: [.shared, .licence], classification: 0,
                          size: 0.05, months: 24, staff: [(.researcher, 0.6), (.infra, 0.2), (.data, 0.2)], computeShare: 0.5, risk: 0.2, basis: .technical,
                          effects: [.forecast(0.05), .domain(.science, 0.04)], unlock: nil, discovery: nil, field: "Climate",
                          image: "hpc_summit", reward: "sharper forecasting and science models", topic: "Environmental observation"),
        // Programme topics agencies buy beyond models: communications, cryptography, space, instruments, disaster response,
        // fabs, edge hardware, research infrastructure, cooling, grids, verified and high-reliability software.
        ProgrammeTemplate(id: "securecomms", title: "Secure tactical communications", agencies: ["oadr", "edif", "dgpa", "esca", "ansd"], year: 2020,
                          objective: "Radios and network software that keep units talking under jamming, choose routes themselves and never leak what they carry.",
                          domains: [.coding, .reasoning, .agents], gap: 12, research: [], types: [.costPlus, .fixedPrice], ip: [.government, .shared], classification: 2,
                          size: 0.05, months: 24, staff: [(.mlEngineer, 0.4), (.infra, 0.35), (.researcher, 0.25)], computeShare: 0.25, risk: 0.22, basis: .bestValue,
                          effects: [.securityCost(0.1), .enterpriseDemand(0.03)], unlock: nil, discovery: "adaptive low-probability-of-intercept links", field: "Security",
                          image: "fiber", reward: "cheaper security, regulated buyers and government demand", topic: "Secure communications",
                          legacy: [.governmentPull(0.06)], facility: .certified, sciField: .software),
        ProgrammeTemplate(id: "pqcrypto", title: "Quantum-resistant cryptography migration", agencies: ["ncra", "ansd", "edif", "cra", "fsi"], year: 2022,
                          objective: "Inventory every cryptographic dependency in the government's systems and migrate them to post-quantum algorithms without breaking anything.",
                          domains: [.coding, .math], gap: 12, research: ["code_data"], types: [.fixedPrice, .costPlus], ip: [.licence, .shared], classification: 1,
                          size: 0.04, months: 18, staff: [(.mlEngineer, 0.5), (.researcher, 0.3), (.safety, 0.2)], computeShare: 0.2, risk: 0.16, basis: .lowestPrice,
                          effects: [.securityCost(0.12), .distillGuard(0.05), .enterpriseDemand(0.03)], unlock: nil, discovery: nil, field: "Security",
                          image: "rack_rear", reward: "post-quantum key management: cheaper weight security and regulated buyers", topic: "Quantum-resistant cryptography",
                          facility: .certified, sciField: .quantum),
        ProgrammeTemplate(id: "satcomms", title: "Resilient satellite communications", agencies: ["esca", "naoa", "cneo", "aoi", "oadr"], year: 2021,
                          objective: "Software that routes traffic across a constellation of hundreds of satellites, reroutes around failures and attacks, and runs on board.",
                          domains: [.agents, .reasoning, .coding], gap: 12, research: [], types: [.costPlus, .fixedPrice], ip: [.government, .licence], classification: 2,
                          size: 0.06, months: 30, staff: [(.infra, 0.4), (.mlEngineer, 0.35), (.researcher, 0.25)], computeShare: 0.2, risk: 0.24, basis: .technical,
                          effects: [.domain(.agents, 0.03)], unlock: nil, discovery: "autonomous constellation routing", field: nil,
                          image: "network", reward: "sovereign and government buyers for your models", topic: "Satellite communications",
                          legacy: [.governmentPull(0.12)], facility: .engineering, sciField: .aerospace),
        ProgrammeTemplate(id: "instruments", title: "Self-driving scientific instruments", agencies: ["feso", "ceri", "cra", "meridian", "dfgi"], year: 2021,
                          objective: "Put models in charge of beamlines, microscopes and spectrometers: plan the next measurement, catch drift, flag the interesting.",
                          domains: [.science, .vision], gap: 12, research: ["vit"], types: [.grant, .costPlus], ip: [.licence, .shared], classification: 0,
                          size: 0.04, months: 20, staff: [(.researcher, 0.5), (.infra, 0.25), (.data, 0.25)], computeShare: 0.25, risk: 0.2, basis: .technical,
                          effects: [.domain(.science, 0.05), .rp(0.02)], unlock: nil, discovery: "autonomous measurement planning", field: "Materials",
                          image: "lab_physics", reward: "better science models and faster research", topic: "Scientific instrumentation",
                          facility: .engineering, sciField: .materials),
        ProgrammeTemplate(id: "disaster", title: "Disaster-response coordination", agencies: ["ndma", "esca", "aoi", "naoa", "paia", "dfgi"], year: 2021.5,
                          objective: "Map floods, fires and quake damage from satellite and drone imagery within hours, and route rescue teams and supplies.",
                          domains: [.vision, .agents, .reasoning], gap: 12, research: ["vit"], types: [.fixedPrice, .grant], ip: [.licence, .shared], classification: 0,
                          size: 0.04, months: 15, staff: [(.mlEngineer, 0.4), (.data, 0.3), (.researcher, 0.3)], computeShare: 0.3, risk: 0.16, basis: .bestValue,
                          effects: [.domain(.vision, 0.03), .forecast(0.03)], unlock: nil, discovery: nil, field: "Climate",
                          image: "solar_farm", reward: "public trust, sharper forecasting and vision", topic: "Disaster-response technology",
                          legacy: [.publicTrust(4)]),
        ProgrammeTemplate(id: "semimfg", title: "Fab process control and defect inspection", agencies: ["paia", "cra", "feso", "cnci"], year: 2021,
                          objective: "Models that read wafer inspection images and tool telemetry, find the root cause of defects and tune the line before yield drops.",
                          domains: [.vision, .science, .math], gap: 12, research: ["vit"], types: [.costPlus, .fixedPrice], ip: [.licence, .shared], classification: 1,
                          size: 0.06, months: 24, staff: [(.chipDesigner, 0.3), (.mlEngineer, 0.35), (.data, 0.2), (.researcher, 0.15)], computeShare: 0.25, risk: 0.22, basis: .technical,
                          effects: [.chipDesign(0.04)], unlock: nil, discovery: nil, field: "Materials",
                          image: "fab_cleanroom", reward: "lower defect density on every wafer you buy or make", topic: "Semiconductor manufacturing",
                          legacy: [.defects(0.12)], facility: .engineering, sciField: .semiconductors),
        ProgrammeTemplate(id: "edgeai", title: "Edge AI accelerator for field systems", agencies: ["oadr", "dgpa", "edif", "paia", "cnci"], year: 2022.6,
                          objective: "A low-power inference accelerator and its compiler for drones, vehicles and sensors that can't reach a datacenter.",
                          domains: [.coding, .vision, .agents], gap: 12, research: ["int8_serving"], types: [.fixedPrice, .costPlus], ip: [.licence, .shared], classification: 1,
                          size: 0.06, months: 24, staff: [(.chipDesigner, 0.35), (.mlEngineer, 0.35), (.infra, 0.3)], computeShare: 0.2, risk: 0.26, basis: .technical,
                          effects: [.chipDesign(0.05), .throughput(0.02)], unlock: nil, discovery: nil, field: nil,
                          image: "groq_lpu", reward: "leaner inference chips and faster chip design", topic: "Edge AI hardware",
                          legacy: [.edgeChips(0.1)], facility: .engineering, sciField: .semiconductors),
        ProgrammeTemplate(id: "researchcloud", title: "National research cloud", agencies: ["ceri", "feso", "efrc", "dfgi", "cra", "ukaia"], year: 2020.2,
                          objective: "Stand up and run a shared AI research cloud for universities: scheduling, data services and fair-share access for thousands of users.",
                          domains: [.coding, .science], gap: 14, research: ["sharding"], types: [.grant, .costPlus], ip: [.licence, .shared], classification: 0,
                          size: 0.05, months: 24, staff: [(.infra, 0.5), (.mlEngineer, 0.3), (.researcher, 0.2)], computeShare: 0.5, risk: 0.14, basis: .bestValue,
                          effects: [.rp(0.03), .scaleOut(0.03)], unlock: nil, discovery: nil, field: nil,
                          image: "dc_cern", reward: "faster research and better scale-out", topic: "Research infrastructure"),
        ProgrammeTemplate(id: "cooling", title: "Advanced cooling for dense compute", agencies: ["feso", "dfgi", "cra", "ceri", "paia"], year: 2021,
                          objective: "Design and prove liquid and immersion cooling that holds megawatt racks at a PUE near 1.05, with waste heat sold to the town.",
                          domains: [.science, .math], gap: 14, research: [], types: [.grant, .fixedPrice], ip: [.licence, .shared], classification: 0,
                          size: 0.04, months: 18, staff: [(.infra, 0.5), (.researcher, 0.3), (.mlEngineer, 0.2)], computeShare: 0.2, risk: 0.18, basis: .bestValue,
                          effects: [.mfu(0.01)], unlock: "immersion_cooling", discovery: nil, field: "Energy",
                          image: "immersion", reward: "a lower datacenter power bill (better PUE)", topic: "Advanced cooling",
                          legacy: [.powerBill(0.06)], facility: .engineering, sciField: .energy),
        ProgrammeTemplate(id: "gridai", title: "Grid-scale AI for transmission operators", agencies: ["feso", "dfgi", "cra", "gsta"], year: 2022.5,
                          objective: "Forecast load and renewables an hour ahead and re-dispatch a national grid in real time, with operators approving every action.",
                          domains: [.science, .agents, .reasoning], gap: 12, research: ["rag"], types: [.costPlus, .fixedPrice], ip: [.licence, .shared], classification: 1,
                          size: 0.05, months: 24, staff: [(.researcher, 0.4), (.mlEngineer, 0.35), (.infra, 0.25)], computeShare: 0.3, risk: 0.2, basis: .bestValue,
                          effects: [.forecast(0.02)], unlock: nil, discovery: nil, field: "Energy",
                          image: "power_substation_night", reward: "cheaper power when grids are strained", topic: "Energy infrastructure",
                          legacy: [.gridRelief(0.3), .powerBill(0.02)], sciField: .energy),
        ProgrammeTemplate(id: "verified", title: "Formally verified flight software", agencies: ["naoa", "oadr", "dgpa", "cneo", "aoi", "ukaia"], year: 2022.5,
                          objective: "Generate flight-control code together with machine-checked proofs that it meets its specification, and get it certified.",
                          domains: [.math, .coding, .reasoning], gap: 10, research: ["code_data"], types: [.fixedPrice, .costPlus], ip: [.licence, .shared], classification: 1,
                          size: 0.05, months: 24, staff: [(.researcher, 0.5), (.mlEngineer, 0.3), (.safety, 0.2)], computeShare: 0.3, risk: 0.24, basis: .technical,
                          effects: [.bugGuard(0.25), .stability(0.1), .domain(.math, 0.04)], unlock: nil, discovery: nil, field: "Mathematics",
                          image: "rack_rear", reward: "far fewer silent training bugs and loss spikes", topic: "Formal verification",
                          facility: .certified, sciField: .mathematics),
        ProgrammeTemplate(id: "highrel", title: "High-assurance control software", agencies: ["meridian", "cra", "ncra", "cnci", "dfgi"], year: 2021.5,
                          objective: "Rewrite the control software of reactors, substations and rail signalling to safety-critical standards, with every change traced and tested.",
                          domains: [.coding, .reasoning], gap: 12, research: ["code_data"], types: [.fixedPrice, .costPlus], ip: [.shared, .licence], classification: 1,
                          size: 0.04, months: 20, staff: [(.mlEngineer, 0.5), (.safety, 0.3), (.infra, 0.2)], computeShare: 0.2, risk: 0.18, basis: .lowestPrice,
                          effects: [.failureCost(0.15), .bugGuard(0.1), .domain(.coding, 0.03)], unlock: nil, discovery: nil, field: nil,
                          image: "power_nuclear2", reward: "less time lost to hardware failures and fewer training bugs", topic: "High-reliability software",
                          facility: .certified, sciField: .software),
        ProgrammeTemplate(id: "federated", title: "Federated training across sovereign enclaves", agencies: ["edif", "esca", "iaro", "gsta", "dgpa"], year: 2024.6,
                          objective: "Train one model across several governments' secure sites without any of them seeing the others' data or weights.",
                          domains: [.coding, .agents, .reasoning], gap: 10, research: ["diloco"], types: [.costPlus], ip: [.government, .shared], classification: 2,
                          size: 0.07, months: 24, staff: [(.infra, 0.45), (.mlEngineer, 0.35), (.researcher, 0.2)], computeShare: 0.45, risk: 0.22, basis: .technical,
                          effects: [.scaleOut(0.05), .securityCost(0.08)], unlock: nil, discovery: "verifiable multi-site training under secrecy", field: "Security",
                          image: "fiber", reward: "multi-site scale-out and cheaper security", topic: "Secure distributed computing",
                          facility: .certified, sciField: .software),
        ProgrammeTemplate(id: "materials", title: "Extreme-environment materials discovery", agencies: ["cra", "dgpa", "meridian", "oadr"], year: 2021,
                          objective: "Search millions of alloys and ceramics for ones that survive hypersonic flight and fusion walls, then make and test the best in a cleared lab.",
                          domains: [.science, .math], gap: 12, research: ["alphafold"], types: [.costPlus, .grant], ip: [.government, .shared], classification: 2,
                          size: 0.05, months: 26, staff: [(.researcher, 0.6), (.data, 0.2), (.infra, 0.2)], computeShare: 0.35, risk: 0.26, basis: .technical,
                          effects: [.chipDesign(0.03), .domain(.science, 0.04)], unlock: nil, discovery: "high-entropy alloys for extreme heat", field: "Materials",
                          image: "lab_materials", reward: "better chips and science models, slightly better yields", topic: "Advanced materials",
                          legacy: [.defects(0.04), .powerBill(0.02)], facility: .confidentialScience, sciField: .materials),
        ProgrammeTemplate(id: "aircraft", title: "Autonomous aircraft certification", agencies: ["cneo", "aoi", "naoa", "dgpa", "ukaia"], year: 2023.6,
                          objective: "Fly an uncrewed cargo aircraft through a full certification campaign: sense-and-avoid, contingency landing and an auditable decision log.",
                          domains: [.robotics, .vision, .reasoning], gap: 10, research: ["vla"], types: [.fixedPrice, .costPlus], ip: [.licence, .shared], classification: 1,
                          size: 0.06, months: 26, staff: [(.researcher, 0.35), (.mlEngineer, 0.35), (.safety, 0.3)], computeShare: 0.25, risk: 0.26, basis: .technical,
                          effects: [.domain(.robotics, 0.04), .domain(.vision, 0.02)], unlock: nil, discovery: nil, field: "Robotics",
                          image: "event_hall", reward: "robotics know-how and aerospace buyers", topic: "Aerospace",
                          legacy: [.governmentPull(0.06)], facility: .engineering, sciField: .aerospace),
        ProgrammeTemplate(id: "emissions", title: "Methane and emissions watch from orbit", agencies: ["esca", "cneo", "aoi", "efrc", "dfgi", "naoa"], year: 2022,
                          objective: "Find every large methane leak and emissions source on Earth from satellite spectra, weekly, and publish the data.",
                          domains: [.vision, .science], gap: 12, research: ["vit"], types: [.grant, .fixedPrice], ip: [.shared, .licence], classification: 0,
                          size: 0.04, months: 18, staff: [(.researcher, 0.45), (.data, 0.35), (.mlEngineer, 0.2)], computeShare: 0.3, risk: 0.16, basis: .technical,
                          effects: [.domain(.vision, 0.03), .forecast(0.03)], unlock: nil, discovery: nil, field: "Climate",
                          image: "power_wind", reward: "public trust, vision and forecasting", topic: "Environmental observation",
                          legacy: [.publicTrust(2)]),
        ProgrammeTemplate(id: "cyberrange", title: "National cyber range", agencies: ["ansd", "edif", "ncra", "dgpa"], year: 2023.5,
                          objective: "Build a cyber range that replicates the state's networks and run autonomous red and blue teams against it, around the clock.",
                          domains: [.coding, .agents], gap: 10, research: ["code_interpreter"], types: [.costPlus, .fixedPrice], ip: [.government, .shared], classification: 2,
                          size: 0.05, months: 20, staff: [(.mlEngineer, 0.4), (.safety, 0.35), (.infra, 0.25)], computeShare: 0.35, risk: 0.2, basis: .bestValue,
                          effects: [.securityCost(0.12), .safety(1)], unlock: nil, discovery: "autonomous red-team agents", field: "Security",
                          image: "dc_servers", reward: "cheaper security and a better safety record", topic: "Cyber defence",
                          facility: .certified, sciField: .software),
    ]

    static let templateByID: [String: ProgrammeTemplate] = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
}
