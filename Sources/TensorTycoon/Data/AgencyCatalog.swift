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
    ]

    static let byID: [String: AgencyDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static let templates: [ProgrammeTemplate] = [
        // Seedlings: small first contracts any capable lab can win (Phase I style).
        ProgrammeTemplate(id: "seedling", title: "Seedling feasibility study", agencies: all.map(\.id), year: 2016,
                          objective: "Show in six months that a modern model can do a narrowly defined task the agency cares about, and report what a full programme would take.",
                          domains: [.reasoning, .knowledge], gap: 28, research: [], types: [.grant, .fixedPrice], ip: [.licence, .shared], classification: 0,
                          size: 0.002, months: 6, staff: [(.researcher, 0.7), (.mlEngineer, 0.3)], computeShare: 0.25, risk: 0.12, basis: .bestValue,
                          effects: [.rp(0.01)], unlock: nil, discovery: nil, field: nil, image: "server_room",
                          reward: "a past-performance record with the agency and a small research boost"),
        ProgrammeTemplate(id: "logistics", title: "Autonomous logistics planning", agencies: ["oadr", "edif"], year: 2019,
                          objective: "Plan and re-plan supply movements for thousands of units under disruption, with a human approving every plan.",
                          domains: [.reasoning, .agents], gap: 14, research: ["rag"], types: [.fixedPrice, .costPlus], ip: [.government, .licence], classification: 2,
                          size: 0.05, months: 24, staff: [(.researcher, 0.4), (.mlEngineer, 0.4), (.infra, 0.2)], computeShare: 0.3, risk: 0.22, basis: .bestValue,
                          effects: [.domain(.agents, 0.06), .enterpriseDemand(0.04)], unlock: "tool_use", discovery: "long-horizon planning under uncertainty", field: nil,
                          image: "dc_rows", reward: "better agents and enterprise planning customers"),
        ProgrammeTemplate(id: "translation", title: "Multilingual intelligence triage", agencies: ["iaro"], year: 2018,
                          objective: "Triage foreign-language reporting in forty languages, flagging what an analyst must read today.",
                          domains: [.knowledge, .reasoning], gap: 12, research: ["multilingual"], types: [.costPlus, .fixedPrice], ip: [.government], classification: 3,
                          size: 0.06, months: 20, staff: [(.researcher, 0.4), (.data, 0.3), (.mlEngineer, 0.3)], computeShare: 0.35, risk: 0.18, basis: .technical,
                          effects: [.skill(.lang, 0.06), .domain(.knowledge, 0.04)], unlock: nil, discovery: "low-resource language transfer", field: nil,
                          image: "network", reward: "stronger multilingual models"),
        ProgrammeTemplate(id: "imagery", title: "Overhead imagery analysis", agencies: ["iaro", "naoa"], year: 2020.5,
                          objective: "Find, count and describe objects in satellite and aerial imagery across a continent, every day.",
                          domains: [.vision, .knowledge], gap: 12, research: ["vit"], types: [.costPlus, .fixedPrice], ip: [.government, .licence], classification: 2,
                          size: 0.05, months: 18, staff: [(.researcher, 0.4), (.mlEngineer, 0.3), (.data, 0.3)], computeShare: 0.35, risk: 0.18, basis: .technical,
                          effects: [.domain(.vision, 0.07)], unlock: nil, discovery: "self-supervised remote sensing", field: "Climate",
                          image: "supercomputer", reward: "better vision models and Earth-observation know-how"),
        ProgrammeTemplate(id: "vulns", title: "Automated vulnerability discovery", agencies: ["ncra", "fsi"], year: 2021.5,
                          objective: "Find and patch exploitable bugs in open-source code the country runs on, before attackers do.",
                          domains: [.coding, .agents], gap: 12, research: ["code_data"], types: [.fixedPrice, .prize], ip: [.licence, .shared], classification: 1,
                          size: 0.06, months: 15, staff: [(.researcher, 0.3), (.mlEngineer, 0.4), (.safety, 0.3)], computeShare: 0.3, risk: 0.2, basis: .bestValue,
                          effects: [.securityCost(0.12), .domain(.coding, 0.05)], unlock: "vuln_discovery", discovery: nil, field: "Security",
                          image: "rack_rear", reward: "cheaper weight security and better coding models"),
        ProgrammeTemplate(id: "cyberdefense", title: "Critical-infrastructure cyber defence", agencies: ["ncra", "oadr"], year: 2024.5,
                          objective: "Agents that watch grid, water and hospital networks and contain intrusions in minutes, with operators in the loop.",
                          domains: [.coding, .agents, .reasoning], gap: 10, research: ["tool_use"], types: [.costPlus, .fixedPrice], ip: [.government, .shared], classification: 1,
                          size: 0.07, months: 24, staff: [(.mlEngineer, 0.4), (.safety, 0.3), (.infra, 0.3)], computeShare: 0.3, risk: 0.24, basis: .bestValue,
                          effects: [.securityCost(0.15), .safety(2)], unlock: "cyber_defense", discovery: nil, field: "Security",
                          image: "substation", reward: "cheaper security, a better safety record and goodwill"),
        ProgrammeTemplate(id: "fusionsim", title: "Plasma and materials simulation", agencies: ["feso", "efrc", "paia"], year: 2019.5,
                          objective: "Learned surrogates that run plasma and materials simulations a thousand times faster at useful accuracy.",
                          domains: [.science, .math], gap: 14, research: [], types: [.grant, .costPlus], ip: [.licence, .shared], classification: 0,
                          size: 0.04, months: 24, staff: [(.researcher, 0.6), (.infra, 0.2), (.mlEngineer, 0.2)], computeShare: 0.45, risk: 0.2, basis: .technical,
                          effects: [.rp(0.03), .domain(.science, 0.05)], unlock: nil, discovery: nil, field: "Energy",
                          image: "nuclear", reward: "faster research and better science models"),
        ProgrammeTemplate(id: "stewardship", title: "Stewardship surrogate models", agencies: ["meridian"], year: 2021,
                          objective: "Replace weeks of exascale simulation with verified learned surrogates for the stockpile stewardship mission.",
                          domains: [.science, .math, .coding], gap: 12, research: ["mixed_precision"], types: [.costPlus], ip: [.government], classification: 2,
                          size: 0.08, months: 30, staff: [(.researcher, 0.5), (.infra, 0.3), (.mlEngineer, 0.2)], computeShare: 0.5, risk: 0.22, basis: .technical,
                          effects: [.scaleOut(0.08), .mfu(0.02)], unlock: nil, discovery: "verified physics surrogates at exascale", field: "Energy",
                          image: "supercomputer", reward: "better scale-out on big clusters"),
        ProgrammeTemplate(id: "codemod", title: "Exascale code modernisation", agencies: ["feso", "meridian"], year: 2022.5,
                          objective: "Port and verify millions of lines of legacy scientific Fortran onto modern accelerators.",
                          domains: [.coding, .reasoning], gap: 14, research: ["code_data"], types: [.fixedPrice, .costPlus], ip: [.shared, .licence], classification: 0,
                          size: 0.04, months: 18, staff: [(.mlEngineer, 0.5), (.researcher, 0.3), (.infra, 0.2)], computeShare: 0.3, risk: 0.16, basis: .lowestPrice,
                          effects: [.mfu(0.02), .domain(.coding, 0.04)], unlock: "kernel_compilers", discovery: nil, field: nil,
                          image: "server_room", reward: "faster kernels and better coding models"),
        ProgrammeTemplate(id: "rover", title: "Autonomous rover navigation", agencies: ["naoa", "paia", "ukaia"], year: 2020,
                          objective: "Drive a planetary rover kilometres a day with no human in the loop, through terrain nobody has mapped.",
                          domains: [.robotics, .vision, .agents], gap: 14, research: ["sim_to_real"], types: [.grant, .fixedPrice], ip: [.licence, .shared], classification: 0,
                          size: 0.05, months: 24, staff: [(.researcher, 0.5), (.mlEngineer, 0.3), (.infra, 0.2)], computeShare: 0.3, risk: 0.26, basis: .technical,
                          effects: [.domain(.robotics, 0.08), .domain(.vision, 0.03)], unlock: nil, discovery: nil, field: "Robotics",
                          image: "solar_farm", reward: "better robotics and vision"),
        ProgrammeTemplate(id: "missionplan", title: "Mission-planning copilot", agencies: ["naoa", "oadr"], year: 2023.5,
                          objective: "A copilot that drafts, checks and explains complex mission plans for crews and operators.",
                          domains: [.reasoning, .agents, .knowledge], gap: 12, research: ["cot"], types: [.fixedPrice, .costPlus], ip: [.licence, .government], classification: 1,
                          size: 0.04, months: 18, staff: [(.researcher, 0.4), (.mlEngineer, 0.4), (.safety, 0.2)], computeShare: 0.3, risk: 0.18, basis: .bestValue,
                          effects: [.domain(.reasoning, 0.04), .enterpriseDemand(0.03)], unlock: nil, discovery: nil, field: nil,
                          image: "network", reward: "reasoning gains and enterprise customers"),
        ProgrammeTemplate(id: "countermeasures", title: "Pathogen countermeasure design", agencies: ["nhri", "efrc"], year: 2021,
                          objective: "Design candidate antibodies and antivirals against a panel of threat pathogens, with biosafety review at every step.",
                          domains: [.science, .knowledge], gap: 12, research: ["alphafold"], types: [.grant, .costPlus], ip: [.licence, .shared], classification: 1,
                          size: 0.05, months: 24, staff: [(.researcher, 0.5), (.safety, 0.3), (.data, 0.2)], computeShare: 0.35, risk: 0.24, basis: .technical,
                          effects: [.safety(2), .domain(.science, 0.05)], unlock: "protein_design", discovery: nil, field: "Medicine",
                          image: "wafer_closeup", reward: "a better safety record and science models"),
        ProgrammeTemplate(id: "clinical", title: "Clinical decision support trial", agencies: ["nhri", "gsta"], year: 2023.3,
                          objective: "Run an AI assistant through a supervised multi-hospital trial and prove it improves outcomes.",
                          domains: [.knowledge, .science, .social], gap: 12, research: ["rlhf"], types: [.costPlus, .grant], ip: [.licence, .shared], classification: 0,
                          size: 0.05, months: 24, staff: [(.researcher, 0.3), (.safety, 0.3), (.mlEngineer, 0.2), (.data, 0.2)], computeShare: 0.2, risk: 0.2, basis: .bestValue,
                          effects: [.domain(.knowledge, 0.04), .consumerDemand(0.03)], unlock: "clinical_grounding", discovery: nil, field: "Medicine",
                          image: "server_room", reward: "medical know-how and consumer trust"),
        ProgrammeTemplate(id: "mathprize", title: "Open mathematics challenge", agencies: ["efrc", "ukaia"], year: 2022,
                          objective: "Solve a published list of open problems with machine-checked proofs. First complete entry takes the purse.",
                          domains: [.math, .reasoning], gap: 8, research: ["cot"], types: [.prize], ip: [.shared], classification: 0,
                          size: 0.08, months: 15, staff: [(.researcher, 0.8), (.mlEngineer, 0.2)], computeShare: 0.45, risk: 0.3, basis: .technical,
                          effects: [.domain(.math, 0.08), .skill(.reasoning, 0.03)], unlock: nil, discovery: nil, field: "Mathematics",
                          image: "wafer_closeup", reward: "prestige and better mathematics"),
        ProgrammeTemplate(id: "trustworthy", title: "Trustworthy AI research grant", agencies: ["efrc", "fsi", "ukaia"], year: 2023,
                          objective: "Advance interpretability and oversight methods and publish the results openly.",
                          domains: [.reasoning, .knowledge], gap: 14, research: ["red_teaming"], types: [.grant], ip: [.shared], classification: 0,
                          size: 0.03, months: 18, staff: [(.safety, 0.6), (.researcher, 0.4)], computeShare: 0.25, risk: 0.15, basis: .technical,
                          effects: [.safety(3), .agentSafety(0.05)], unlock: "interpretability", discovery: nil, field: nil,
                          image: "network", reward: "a better safety record and researchers' respect"),
        ProgrammeTemplate(id: "sovereignllm", title: "Sovereign defence language model", agencies: ["edif", "oadr"], year: 2024,
                          objective: "Train and accredit a model that runs entirely on government hardware and never touches the public internet.",
                          domains: [.knowledge, .reasoning, .coding], gap: 10, research: ["instruction_tuning"], types: [.fixedPrice, .costPlus], ip: [.government], classification: 2,
                          size: 0.08, months: 24, staff: [(.mlEngineer, 0.4), (.researcher, 0.3), (.infra, 0.3)], computeShare: 0.5, risk: 0.2, basis: .bestValue,
                          effects: [.securityCost(0.1), .enterpriseDemand(0.03)], unlock: "sovereign_deploy", discovery: "air-gapped training at scale", field: nil,
                          image: "dc_hall", reward: "air-gapped deployment know-how and regulated-industry customers"),
        ProgrammeTemplate(id: "dexterity", title: "Robot dexterity grand prize", agencies: ["ukaia", "paia"], year: 2024.5,
                          objective: "A robot hand that can assemble an unseen device from a parts bin, judged live.",
                          domains: [.robotics, .vision], gap: 6, research: ["sim_to_real"], types: [.prize], ip: [.licence], classification: 0,
                          size: 0.10, months: 18, staff: [(.researcher, 0.5), (.mlEngineer, 0.3), (.infra, 0.2)], computeShare: 0.35, risk: 0.32, basis: .technical,
                          effects: [.domain(.robotics, 0.1)], unlock: nil, discovery: nil, field: "Robotics",
                          image: "gpu_cluster", reward: "a prize purse and much better robotics"),
        ProgrammeTemplate(id: "evalsuite", title: "Frontier model evaluation suite", agencies: ["fsi", "ncra"], year: 2023.8,
                          objective: "Build the government's dangerous-capability evaluations — cyber, bio, autonomy — and run them on frontier models under controlled access.",
                          domains: [.reasoning, .agents, .coding], gap: 8, research: ["red_teaming"], types: [.costPlus], ip: [.government, .shared], classification: 1,
                          size: 0.06, months: 15, staff: [(.safety, 0.6), (.researcher, 0.2), (.mlEngineer, 0.2)], computeShare: 0.3, risk: 0.14, basis: .technical,
                          effects: [.safety(3), .contaminationGuard(0.1)], unlock: "evals_rsp", discovery: nil, field: nil,
                          image: "rack_rear", reward: "a strong safety record and regulators' trust"),
        ProgrammeTemplate(id: "arabicllm", title: "National Arabic language model", agencies: ["gsta"], year: 2023,
                          objective: "A national model fluent in Arabic dialects, trained and served inside the country.",
                          domains: [.knowledge, .social], gap: 12, research: ["multilingual"], types: [.costPlus, .fixedPrice], ip: [.licence, .shared], classification: 0,
                          size: 0.06, months: 18, staff: [(.mlEngineer, 0.4), (.data, 0.3), (.researcher, 0.3)], computeShare: 0.5, risk: 0.15, basis: .bestValue,
                          effects: [.skill(.lang, 0.05), .consumerDemand(0.03)], unlock: nil, discovery: nil, field: nil,
                          image: "hyperscale_campus", reward: "multilingual gains and new consumers"),
        ProgrammeTemplate(id: "factory", title: "Factory automation pilot", agencies: ["paia"], year: 2025,
                          objective: "Run three production lines with robot foundation models for a year, with uptime guarantees.",
                          domains: [.robotics, .vision, .agents], gap: 10, research: ["embodied_fm"], types: [.fixedPrice, .costPlus], ip: [.licence, .shared], classification: 0,
                          size: 0.08, months: 24, staff: [(.mlEngineer, 0.4), (.researcher, 0.3), (.infra, 0.3)], computeShare: 0.3, risk: 0.24, basis: .bestValue,
                          effects: [.domain(.robotics, 0.08), .enterpriseDemand(0.05)], unlock: nil, discovery: nil, field: "Robotics",
                          image: "dc_construction", reward: "robotics know-how and industrial customers"),
        ProgrammeTemplate(id: "publicservices", title: "Twenty-two-language public services assistant", agencies: ["ndma"], year: 2024,
                          objective: "A voice assistant for government services in every scheduled language, on cheap phones.",
                          domains: [.knowledge, .voice, .social], gap: 14, research: ["multilingual"], types: [.fixedPrice], ip: [.licence, .shared], classification: 0,
                          size: 0.08, months: 18, staff: [(.mlEngineer, 0.4), (.data, 0.4), (.researcher, 0.2)], computeShare: 0.35, risk: 0.16, basis: .lowestPrice,
                          effects: [.skill(.lang, 0.04), .apiDemand(0.03)], unlock: nil, discovery: nil, field: nil,
                          image: "sf_skyline", reward: "multilingual and voice gains, more API customers"),
        ProgrammeTemplate(id: "unmanned", title: "Collaborative autonomy for unmanned systems", agencies: ["oadr"], year: 2026.5,
                          objective: "Teams of autonomous vehicles that share a plan, adapt when one is lost and always keep a human commander in control.",
                          domains: [.agents, .robotics, .reasoning], gap: 6, research: ["multi_agent"], types: [.costPlus, .fixedPrice], ip: [.government], classification: 3,
                          size: 0.10, months: 30, staff: [(.researcher, 0.4), (.mlEngineer, 0.3), (.safety, 0.3)], computeShare: 0.35, risk: 0.28, basis: .technical,
                          effects: [.domain(.agents, 0.08), .coordination(0.03)], unlock: nil, discovery: "decentralised multi-agent coordination", field: "Robotics",
                          image: "dc_corridor", reward: "much better agent coordination"),
        ProgrammeTemplate(id: "enclave", title: "Secure compute enclave pilot", agencies: ["iaro", "edif"], year: 2025,
                          objective: "Prove that frontier models can run on classified networks with hardware-enforced isolation and auditable access.",
                          domains: [.coding, .agents], gap: 10, research: ["confidential_computing"], types: [.costPlus], ip: [.government, .shared], classification: 3,
                          size: 0.06, months: 18, staff: [(.infra, 0.5), (.mlEngineer, 0.3), (.safety, 0.2)], computeShare: 0.45, risk: 0.18, basis: .technical,
                          effects: [.securityCost(0.2)], unlock: nil, discovery: "hardware-enforced model isolation", field: "Security",
                          image: "rack_rear", reward: "much cheaper weight security"),
        ProgrammeTemplate(id: "climatesim", title: "Kilometre-scale climate emulator", agencies: ["feso", "efrc", "naoa"], year: 2024,
                          objective: "An emulator of the Earth system at kilometre scale, fast enough to run thousands of scenarios.",
                          domains: [.science, .math, .vision], gap: 10, research: ["graphcast"], types: [.grant, .costPlus], ip: [.shared, .licence], classification: 0,
                          size: 0.05, months: 24, staff: [(.researcher, 0.6), (.infra, 0.2), (.data, 0.2)], computeShare: 0.5, risk: 0.2, basis: .technical,
                          effects: [.forecast(0.05), .domain(.science, 0.04)], unlock: nil, discovery: nil, field: "Climate",
                          image: "solar_farm", reward: "sharper forecasting and science models"),
    ]

    static let templateByID: [String: ProgrammeTemplate] = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
}
