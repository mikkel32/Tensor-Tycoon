import Foundation

/// 3.4: a grand challenge a frontier lab can take on from 2028 — science and engineering problems that turn idle
/// cash and research into royalties, reputation, political goodwill and permanent research effects.
struct MoonshotDef: Identifiable, Sendable {
    let id: String
    let name: String
    let field: String
    let symbol: String
    let image: String?
    /// Earliest year anyone offers it.
    let year: Double
    /// Research your lab needs before backers will talk to you.
    let prereq: String
    let months: Int
    /// Up-front cost as a share of a frontier lab's valuation (at least $2B).
    let costShare: Double
    /// Share of your research points it takes while it runs.
    let researchShare: Double
    /// Odds for a lab at the frontier that puts in the planned research.
    let baseChance: Double
    /// Safety score the backers expect (0 = none). Below it the odds drop.
    let minSafety: Double
    /// Yearly royalties after success, as a share of the whole AI market.
    let royaltyShare: Double
    let brand: Double
    let political: Double
    /// Permanent research effects on success (a quarter of them if it fails).
    let effects: [ResearchEffect]
    let blurb: String
    /// What success brings, in a sentence (completes "If it works: …").
    let reward: String
}

enum MoonshotCatalog {
    static let all: [MoonshotDef] = [
        MoonshotDef(id: "fusion_control", name: "Fusion Plasma Control", field: "Energy", symbol: "sun.max.fill", image: "power_fusion",
                    year: 2028.3, prereq: "world_models", months: 18, costShare: 0.004, researchShare: 0.10, baseChance: 0.65,
                    minSafety: 0, royaltyShare: 0.0025, brand: 6, political: 10,
                    effects: [.enterpriseDemand(0.08), .forecast(0.05)],
                    blurb: "A fusion consortium wants an AI that keeps a burning plasma stable for hours rather than seconds: reinforcement learning on a digital twin of the reactor, then on the real machine.",
                    reward: "royalties from every plant that runs your controller, political goodwill and a wave of energy-sector customers."),
        MoonshotDef(id: "climate_twin", name: "Planetary Climate Twin", field: "Climate", symbol: "globe.europe.africa.fill", image: "solar_farm",
                    year: 2028.6, prereq: "graphcast", months: 18, costShare: 0.003, researchShare: 0.08, baseChance: 0.75,
                    minSafety: 0, royaltyShare: 0.002, brand: 6, political: 15,
                    effects: [.forecast(0.1), .enterpriseDemand(0.04)],
                    blurb: "Governments want a kilometre-scale simulation of the whole Earth system that runs faster than real time, to plan for floods, droughts and heat.",
                    reward: "government subscriptions, a lot of political capital and sharper forecasting for your own scaling science."),
        MoonshotDef(id: "flu_vaccine", name: "Universal Flu Vaccine", field: "Medicine", symbol: "cross.vial.fill", image: "lab_biology",
                    year: 2028.9, prereq: "alphafold", months: 24, costShare: 0.005, researchShare: 0.12, baseChance: 0.6,
                    minSafety: 65, royaltyShare: 0.004, brand: 10, political: 6,
                    effects: [.safety(3), .consumerDemand(0.03)],
                    blurb: "Design one antigen that protects against every strain of flu, with AI-guided protein design and a global trial network ready to test it. Backers expect strong biosafety.",
                    reward: "royalties from a vaccine the whole world buys every year, and a big boost to your reputation."),
        MoonshotDef(id: "millennium_proof", name: "A Millennium Prize Problem", field: "Mathematics", symbol: "function", image: "wafer_closeup",
                    year: 2029.4, prereq: "verified_reasoning", months: 12, costShare: 0.0015, researchShare: 0.18, baseChance: 0.45,
                    minSafety: 0, royaltyShare: 0, brand: 18, political: 4,
                    effects: [.skill(.reasoning, 0.06), .rp(0.08)],
                    blurb: "Point your strongest reasoning models at one of mathematics' great open problems, with every step checked by a proof assistant.",
                    reward: "almost no money, but enormous prestige, sharper reasoning models and researchers queuing to work for you."),
        MoonshotDef(id: "superconductor", name: "Room-Temperature Superconductor", field: "Materials", symbol: "bolt.horizontal.circle.fill", image: "lab_physics",
                    year: 2029.6, prereq: "materials_ai", months: 30, costShare: 0.008, researchShare: 0.15, baseChance: 0.35,
                    minSafety: 0, royaltyShare: 0.006, brand: 15, political: 6,
                    effects: [.scaleOut(0.15), .chipDesign(0.25), .tps(0.1)],
                    blurb: "A long shot: screen millions of candidate materials with AI, synthesise the best in robotic labs and find a superconductor that works without cryogenics.",
                    reward: "the most valuable patent portfolio in history, lossless interconnects for your clusters and better chips."),
        MoonshotDef(id: "battery_chem", name: "Grid-Scale Battery Chemistry", field: "Energy", symbol: "battery.100percent.bolt", image: "power_battery",
                    year: 2030.1, prereq: "materials_ai", months: 24, costShare: 0.005, researchShare: 0.12, baseChance: 0.55,
                    minSafety: 0, royaltyShare: 0.004, brand: 8, political: 6,
                    effects: [.enterpriseDemand(0.06)],
                    blurb: "Find a cheap, safe battery chemistry made from abundant elements that can store a day of solar power for a whole city.",
                    reward: "royalties from every grid battery built for a decade and a flood of industrial customers."),
        MoonshotDef(id: "alzheimers", name: "Alzheimer's Breakthrough", field: "Medicine", symbol: "brain.head.profile", image: nil,
                    year: 2030.5, prereq: "ai_scientist", months: 36, costShare: 0.012, researchShare: 0.15, baseChance: 0.4,
                    minSafety: 70, royaltyShare: 0.01, brand: 20, political: 6,
                    effects: [.safety(2), .consumerDemand(0.05)],
                    blurb: "Model the disease end to end — proteins, cells and circuits — then design and trial a treatment that stops it.",
                    reward: "a blockbuster medicine paying royalties for a decade, and the biggest reputation boost money can't buy."),
        MoonshotDef(id: "home_robot", name: "General-Purpose Home Robot", field: "Robotics", symbol: "figure.walk", image: "robot_humanoid",
                    year: 2030.9, prereq: "robot_fm", months: 24, costShare: 0.010, researchShare: 0.12, baseChance: 0.55,
                    minSafety: 0, royaltyShare: 0.008, brand: 12, political: 2,
                    effects: [.consumerDemand(0.1), .skill(.agent, 0.04), .skill(.vis, 0.04)],
                    blurb: "A robot that can cook, clean and care in any home, running your models. Manufacturing partners are ready if the brain works.",
                    reward: "a cut of every robot sold, millions of new consumers on your platform and better agents."),
        MoonshotDef(id: "antibiotics", name: "New Classes of Antibiotics", field: "Medicine", symbol: "pills.fill", image: "lab_chemistry",
                    year: 2031.3, prereq: "alphafold", months: 20, costShare: 0.004, researchShare: 0.10, baseChance: 0.6,
                    minSafety: 65, royaltyShare: 0.003, brand: 10, political: 8,
                    effects: [.safety(2)],
                    blurb: "Drug-resistant infections kill millions a year. Design molecules bacteria have never met and can't easily evolve around.",
                    reward: "steady royalties, public-health goodwill and political capital."),
        MoonshotDef(id: "verified_internet", name: "A Formally Verified Internet Core", field: "Security", symbol: "lock.shield.fill", image: "network",
                    year: 2031.8, prereq: "verified_reasoning", months: 24, costShare: 0.005, researchShare: 0.12, baseChance: 0.6,
                    minSafety: 0, royaltyShare: 0.002, brand: 8, political: 12,
                    effects: [.securityCost(0.3), .safety(3)],
                    blurb: "Rewrite the routers, kernels and cryptographic libraries the world runs on, with machine-checked proofs that they have no exploitable bugs.",
                    reward: "government contracts, political goodwill and much cheaper security for your own weights."),
        MoonshotDef(id: "whole_cell", name: "Whole-Cell Simulation", field: "Biology", symbol: "allergens.fill", image: "supercomputer",
                    year: 2032.4, prereq: "ai_scientist", months: 30, costShare: 0.009, researchShare: 0.15, baseChance: 0.45,
                    minSafety: 60, royaltyShare: 0.005, brand: 12, political: 4,
                    effects: [.rp(0.12), .skill(.reasoning, 0.03)],
                    blurb: "Simulate a living human cell molecule by molecule, accurately enough to test drugs in silico before anyone takes them.",
                    reward: "licences to every drug company and a scientific engine that speeds up your own research."),
        MoonshotDef(id: "aging", name: "Reversing Cellular Aging", field: "Medicine", symbol: "hourglass", image: nil,
                    year: 2033.5, prereq: "ai_scientist", months: 36, costShare: 0.015, researchShare: 0.18, baseChance: 0.35,
                    minSafety: 75, royaltyShare: 0.012, brand: 25, political: 6,
                    effects: [.safety(2), .consumerDemand(0.06)],
                    blurb: "The hardest target in biology: therapies that safely rejuvenate aged cells. The AI does the biology; the trials still take years.",
                    reward: "the largest royalty stream of any moonshot and a legacy that outlasts the company."),
    ]

    static let byID: [String: MoonshotDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
