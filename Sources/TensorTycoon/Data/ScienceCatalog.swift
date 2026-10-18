import Foundation

// MARK: - 3.6: science labs — the catalog
//
// Laboratories you build and staff, the fields they work in, the projects a lab can take on, and the ten stages every
// project goes through. Money is in 2026 dollars and scales with the era (Science.eraScale).
//
// Grounded vs speculative: every project says which it is. Grounded projects are things labs (often AI labs) really did
// or are doing, with the reference in `basis`; their effects are modest. Speculative projects are late-game, nobody has
// done them yet, their odds are lower, their dead ends likelier and their payoffs bigger.

/// A kind of laboratory.
enum LabKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case materials, robotics, computing, electronics, autolab, biology, energy, semiconductor

    var id: String { rawValue }
}

/// A research field your labs can work in.
enum SciField: String, Codable, CaseIterable, Identifiable, Sendable {
    case batteries, energy, fusion, materials, mathematics, robotics, software, medical, automation, quantum, semiconductors, aerospace

    var id: String { rawValue }
}

/// What a discovery does to the rest of the game, by kind (Science reads these; see `Science.effectLines`).
enum SciEffect: String, Codable, Sendable {
    /// Cheaper battery storage for your campuses, and a slightly lower power bill (peak shaving).
    case storage
    /// A lower datacenter power bill.
    case power
    /// Commercial fusion power available earlier.
    case fusion
    /// Better, faster custom-chip programmes (the chip-design bonus).
    case chips
    /// Mathematics and reasoning know-how for your models.
    case reasoning
    /// Robotics know-how; the Robotics Brain product line opens sooner and sells better.
    case robotics
    /// Cheaper serving: more inference throughput per chip, fewer thinking tokens.
    case serving
    /// Science know-how; Healthcare and Discovery Service products open sooner and sell better.
    case medical
    /// Factory and lab automation: robotics and operator products sell better, your labs run faster.
    case automation
    /// Quantum computing: maths and science know-how and faster research.
    case quantum
    /// Aerospace: government and defence business opens sooner and sells better.
    case aerospace
    /// A room-temperature superconductor: power and chips at once (speculative).
    case superconductor
}

/// The ten stages of a research project. Computational fields (mathematics, software) run the same pipeline with
/// different names for the physical stages and skip manufacturing.
enum SciStage: Int, Codable, CaseIterable, Identifiable, Sendable {
    case hypothesis, simulation, design, testing, measurement, reproduction, prototype, validation, manufacturing, commercialisation

    var id: Int { rawValue }

    /// What the stage leans on: models and compute, the bench, or the market.
    enum Kind: Sendable { case computational, physical, market }
}

struct LabDef: Identifiable, Sendable {
    let kind: LabKind
    let name: String
    let symbol: String
    /// Photo key (Resources/Images), credited in ImageCredits.
    let image: String
    let blurb: String
    /// Build cost in 2026 dollars.
    let capex: Double
    /// Projects it can run at once at equipment level 1.
    let capacity: Int
    /// Days from breaking ground to the first experiment.
    let buildDays: Int
    /// Fields it's built for (better odds) and fields it can also take on (worse odds).
    let primary: [SciField]
    let secondary: [SciField]
    /// What its scientists are called.
    let staffTitle: String

    var id: String { kind.rawValue }

    func runs(_ f: SciField) -> Bool { primary.contains(f) || secondary.contains(f) }
}

struct FieldDef: Identifiable, Sendable {
    let field: SciField
    let name: String
    let symbol: String
    /// The capability domains your models bring to it.
    let mix: [(CapDomain, Double)]
    let effect: SciEffect
    /// Runs the computational pipeline (no wet bench, no factory).
    let computational: Bool
    /// The product line a spin-out feeds ("" = none).
    let product: String
    /// The moonshots a result here can feed.
    let moonshots: [String]
    let blurb: String

    var id: String { field.rawValue }
}

struct SciProjectDef: Identifiable, Sendable {
    let id: String
    let field: SciField
    let name: String
    let pitch: String
    /// First year a lab can take it on.
    let year: Double
    /// Taken off every stage's odds (0 easy … 0.3 very hard).
    let difficulty: Double
    /// Effect size when fully commercialised (1 = a typical result).
    let size: Double
    let speculative: Bool
    /// Why it's grounded (the real result it follows) or why it's speculative.
    let basis: String
    /// The discovery's headline if it works.
    let headline: String
}

struct StageDef: Sendable {
    let stage: SciStage
    let name: String
    /// The name in computational fields.
    let compName: String
    let kind: SciStage.Kind
    /// Days of work at full speed.
    let days: Double
    /// Chance the stage passes for an average lab, before skill, equipment, models, agents and compute.
    let odds: Double
    /// Share of failures that are dead ends rather than reruns.
    let deadShare: Double
    /// Materials, equipment time and services for one attempt (2026 dollars, physical fields).
    let cost: Double
    let blurb: String
}

/// A city you can put a laboratory in (an HQ city; its photo is the city's).
struct LabSite: Identifiable, Sendable {
    let id: String
    let country: String
    /// Skill points local hires bring per lab kind.
    let strengths: [LabKind: Double]
    let note: String
}

enum ScienceCatalog {
    // MARK: Labs

    static let labs: [LabDef] = [
        LabDef(kind: .materials, name: "Materials Science Lab", symbol: "cube.transparent.fill", image: "lab_materials",
               blurb: "Furnaces, glove boxes, X-ray diffraction and an electron microscope: make new compounds and find out what they really are.",
               capex: 14e6, capacity: 2, buildDays: 150, primary: [.materials, .batteries], secondary: [.semiconductors, .energy, .aerospace, .quantum],
               staffTitle: "materials scientists"),
        LabDef(kind: .robotics, name: "Robotics Lab", symbol: "gearshape.2.fill", image: "lab_robotics",
               blurb: "Arms, hands, mobile bases and a motion-capture floor, where your models learn to touch the world.",
               capex: 12e6, capacity: 2, buildDays: 120, primary: [.robotics, .automation], secondary: [.aerospace],
               staffTitle: "roboticists"),
        LabDef(kind: .computing, name: "Scientific Computing Centre", symbol: "cpu.fill", image: "supercomputer",
               blurb: "A dedicated HPC cluster and the people who write simulation codes: maths, software, plasma physics and molecular modelling.",
               capex: 18e6, capacity: 3, buildDays: 120, primary: [.mathematics, .software, .fusion], secondary: [.materials, .medical, .quantum, .batteries, .energy],
               staffTitle: "computational scientists"),
        LabDef(kind: .electronics, name: "Electronics Lab", symbol: "waveform.path.ecg", image: "lab_electronics",
               blurb: "Oscilloscopes, probe stations, RF chambers and cryostats: circuits, power electronics and qubits.",
               capex: 8e6, capacity: 2, buildDays: 90, primary: [.quantum, .energy, .aerospace], secondary: [.semiconductors, .automation, .robotics],
               staffTitle: "electrical engineers"),
        LabDef(kind: .autolab, name: "Automated Experiment Facility", symbol: "flask.fill", image: "lab_automation",
               blurb: "A self-driving lab: robots run the experiments your models design, around the clock. Bench stages run 30% faster here.",
               capex: 22e6, capacity: 3, buildDays: 180, primary: [.materials, .batteries, .medical], secondary: [.automation, .robotics],
               staffTitle: "automation scientists"),
        LabDef(kind: .biology, name: "Biology Lab", symbol: "allergens.fill", image: "lab_biology",
               blurb: "BSL-2 wet labs, sequencers and assay robots: proteins, cells and the first steps toward medicines.",
               capex: 15e6, capacity: 2, buildDays: 150, primary: [.medical], secondary: [.materials],
               staffTitle: "biologists"),
        LabDef(kind: .energy, name: "Energy Research Lab", symbol: "bolt.fill", image: "lab_energy",
               blurb: "Battery cyclers, power-electronics test beds and grid simulators — and a seat on a fusion experiment's control team.",
               capex: 20e6, capacity: 2, buildDays: 180, primary: [.batteries, .energy, .fusion], secondary: [.materials],
               staffTitle: "energy researchers"),
        LabDef(kind: .semiconductor, name: "Semiconductor Engineering Lab", symbol: "memorychip.fill", image: "wafer",
               blurb: "A small cleanroom with lithography, etch and metrology: test structures and packaging, not volume production.",
               capex: 45e6, capacity: 2, buildDays: 270, primary: [.semiconductors], secondary: [.quantum, .materials],
               staffTitle: "process engineers"),
    ]

    static let labByKind: [LabKind: LabDef] = Dictionary(uniqueKeysWithValues: labs.map { ($0.kind, $0) })
    static func lab(_ k: LabKind) -> LabDef { labByKind[k]! }

    // MARK: Fields

    static let fields: [FieldDef] = [
        FieldDef(field: .batteries, name: "Advanced batteries", symbol: "battery.100percent.bolt",
                 mix: [(.science, 0.6), (.reasoning, 0.2), (.math, 0.2)], effect: .storage, computational: false, product: "",
                 moonshots: ["battery_chem"], blurb: "Cheaper, denser, safer cells. For you: cheaper storage at your campuses."),
        FieldDef(field: .energy, name: "Energy systems", symbol: "bolt.circle.fill",
                 mix: [(.science, 0.4), (.math, 0.3), (.reasoning, 0.3)], effect: .power, computational: false, product: "",
                 moonshots: ["climate_twin"], blurb: "Power conversion, cooling and dispatch. For you: a lower power bill."),
        FieldDef(field: .fusion, name: "Fusion control", symbol: "sun.max.fill",
                 mix: [(.science, 0.4), (.math, 0.3), (.agents, 0.3)], effect: .fusion, computational: true, product: "",
                 moonshots: ["fusion_control"], blurb: "Models that hold a plasma in place. For you: fusion power sooner."),
        FieldDef(field: .materials, name: "Materials discovery", symbol: "cube.transparent.fill",
                 mix: [(.science, 0.6), (.math, 0.2), (.reasoning, 0.2)], effect: .chips, computational: false, product: "science",
                 moonshots: ["superconductor"], blurb: "New compounds for chips, cooling and power. For you: better custom silicon."),
        FieldDef(field: .mathematics, name: "Mathematics", symbol: "function",
                 mix: [(.math, 0.7), (.reasoning, 0.3)], effect: .reasoning, computational: true, product: "",
                 moonshots: ["millennium_proof"], blurb: "New algorithms and proofs. For you: stronger maths and reasoning in your models."),
        FieldDef(field: .robotics, name: "Robotics", symbol: "gearshape.2.fill",
                 mix: [(.robotics, 0.6), (.vision, 0.2), (.agents, 0.2)], effect: .robotics, computational: false, product: "robotics",
                 moonshots: ["home_robot"], blurb: "Hands, legs and policies that transfer. For you: the Robotics Brain sooner and better."),
        FieldDef(field: .software, name: "Scientific software", symbol: "chevron.left.forwardslash.chevron.right",
                 mix: [(.coding, 0.6), (.math, 0.2), (.reasoning, 0.2)], effect: .serving, computational: true, product: "",
                 moonshots: ["verified_internet"], blurb: "Kernels, decoders and compilers. For you: cheaper inference."),
        FieldDef(field: .medical, name: "Medical research", symbol: "cross.case.fill",
                 mix: [(.science, 0.6), (.knowledge, 0.3), (.reasoning, 0.1)], effect: .medical, computational: false, product: "health",
                 moonshots: ["flu_vaccine", "antibiotics", "alzheimers", "whole_cell", "aging"],
                 blurb: "Proteins, antibiotics and diagnostics. For you: healthcare and discovery products sooner and better."),
        FieldDef(field: .automation, name: "Industrial automation", symbol: "building.2.crop.circle.fill",
                 mix: [(.robotics, 0.4), (.agents, 0.4), (.vision, 0.2)], effect: .automation, computational: false, product: "operator",
                 moonshots: ["home_robot"], blurb: "Inspection, self-driving labs and factory robots. For you: faster labs and better operator products."),
        FieldDef(field: .quantum, name: "Quantum computing", symbol: "atom",
                 mix: [(.science, 0.4), (.math, 0.4), (.coding, 0.2)], effect: .quantum, computational: false, product: "",
                 moonshots: ["whole_cell"], blurb: "Error correction and qubits. For you: maths and science know-how, faster research."),
        FieldDef(field: .semiconductors, name: "Advanced semiconductors", symbol: "memorychip.fill",
                 mix: [(.science, 0.4), (.coding, 0.3), (.math, 0.3)], effect: .chips, computational: false, product: "",
                 moonshots: ["superconductor"], blurb: "Floorplans, power delivery and optics. For you: better custom silicon."),
        FieldDef(field: .aerospace, name: "Aerospace", symbol: "airplane",
                 mix: [(.robotics, 0.3), (.science, 0.3), (.agents, 0.4)], effect: .aerospace, computational: false, product: "government",
                 moonshots: [], blurb: "Flight control and space hardware. For you: government and defence business."),
    ]

    static let fieldByID: [SciField: FieldDef] = Dictionary(uniqueKeysWithValues: fields.map { ($0.field, $0) })
    static func field(_ f: SciField) -> FieldDef { fieldByID[f]! }

    // MARK: Projects

    static let projects: [SciProjectDef] = [
        // Advanced batteries
        SciProjectDef(id: "sodium_ion", field: .batteries, name: "Sodium-ion grid cells", pitch: "Swap lithium for sodium in stationary storage: cheaper, no cobalt, good enough density for a campus.",
                      year: 2016, difficulty: 0.05, size: 0.8, speculative: false,
                      basis: "Grounded: CATL and others brought sodium-ion cells to market in 2021–2023.", headline: "Sodium-ion cells that cycle like lithium"),
        SciProjectDef(id: "ai_electrolyte", field: .batteries, name: "AI-screened electrolyte additives", pitch: "Let a model screen thousands of additives in simulation, then test the best twenty on the bench.",
                      year: 2022, difficulty: 0.1, size: 1, speculative: false,
                      basis: "Grounded: ML-guided electrolyte screening (e.g. Microsoft/PNNL, 2024) found new candidates far faster than by hand.", headline: "An electrolyte additive that doubles cycle life"),
        SciProjectDef(id: "solid_state", field: .batteries, name: "Solid-state electrolyte", pitch: "A ceramic electrolyte that doesn't burn and lets a lithium-metal anode in.",
                      year: 2020, difficulty: 0.18, size: 1.3, speculative: false,
                      basis: "Grounded: QuantumScape and Toyota showed solid-state cells; manufacturing at scale is the open problem.", headline: "A solid electrolyte that survives a thousand cycles"),
        SciProjectDef(id: "lithium_metal", field: .batteries, name: "Dendrite-free lithium-metal anode", pitch: "Stop lithium growing needles through the separator, and density jumps by half.",
                      year: 2026, difficulty: 0.25, size: 1.5, speculative: true,
                      basis: "Speculative: many lab demonstrations, no long-life commercial cell yet.", headline: "Lithium-metal anodes without dendrites"),
        // Energy systems
        SciProjectDef(id: "grid_dispatch", field: .energy, name: "Learned grid dispatch", pitch: "Forecast your campuses' load and the grid's prices, and shift work to cheap hours.",
                      year: 2016, difficulty: 0.05, size: 0.8, speculative: false,
                      basis: "Grounded: DeepMind cut Google's datacenter cooling energy by up to 40% with ML control (2016).", headline: "A dispatcher that buys power at the right hour"),
        SciProjectDef(id: "sic_power", field: .energy, name: "Silicon-carbide power conversion", pitch: "Wide-bandgap converters from the substation to the rack: fewer conversion losses.",
                      year: 2018, difficulty: 0.12, size: 1, speculative: false,
                      basis: "Grounded: SiC and GaN power stages and 800 V DC rack power were adopted by datacenters in the 2020s.", headline: "Rack power delivery at 98.5% efficiency"),
        SciProjectDef(id: "heat_reuse", field: .energy, name: "Two-phase cooling and heat reuse", pitch: "Boil the heat away at the chip and sell it to the district heating network.",
                      year: 2021, difficulty: 0.15, size: 1.1, speculative: false,
                      basis: "Grounded: Nordic datacenters feed district heating; two-phase immersion was piloted by hyperscalers.", headline: "Cooling that pays for itself"),
        // Fusion control
        SciProjectDef(id: "plasma_rl", field: .fusion, name: "Reinforcement-learned plasma shaping", pitch: "Train a controller in simulation that holds a tokamak plasma in shapes humans can't.",
                      year: 2021, difficulty: 0.12, size: 1, speculative: false,
                      basis: "Grounded: DeepMind and EPFL controlled TCV plasma shapes with deep RL (Nature, 2022).", headline: "A learned controller holds a plasma for the full shot"),
        SciProjectDef(id: "tearing_avoid", field: .fusion, name: "Tearing-instability avoidance", pitch: "Predict a tearing instability 300 ms ahead and steer around it.",
                      year: 2024, difficulty: 0.2, size: 1.2, speculative: false,
                      basis: "Grounded: Princeton/DIII-D avoided tearing instabilities with an RL controller (Nature, 2024).", headline: "Disruptions predicted and avoided in real time"),
        SciProjectDef(id: "burning_plasma", field: .fusion, name: "Burning-plasma control stack", pitch: "The full control system for a net-energy plant: magnets, fuelling, heating and exhaust.",
                      year: 2029, difficulty: 0.32, size: 1.8, speculative: true,
                      basis: "Speculative: no plant has sustained a burning plasma yet.", headline: "A control stack for a net-energy fusion plant"),
        // Materials discovery
        SciProjectDef(id: "crystal_screen", field: .materials, name: "Graph-network crystal screening", pitch: "Predict which of millions of hypothetical crystals are stable, then make the best.",
                      year: 2022, difficulty: 0.08, size: 0.8, speculative: false,
                      basis: "Grounded: DeepMind's GNoME predicted 2.2M new crystals; Berkeley's A-Lab synthesised dozens (Nature, 2023).", headline: "Hundreds of new stable compounds, a few of them useful"),
        SciProjectDef(id: "low_k", field: .materials, name: "AI-designed low-k dielectric", pitch: "An insulator between chip wires that cuts capacitance without cracking.",
                      year: 2023, difficulty: 0.18, size: 1.1, speculative: false,
                      basis: "Grounded: interconnect dielectrics are an active industrial research area; ML-guided searches are routine.", headline: "A tougher low-k dielectric for interconnects"),
        SciProjectDef(id: "thermal_interface", field: .materials, name: "Diamond thermal interface", pitch: "Pull heat out of the hottest chips through a thin diamond layer.",
                      year: 2025, difficulty: 0.2, size: 1.2, speculative: false,
                      basis: "Grounded: diamond heat spreaders are being developed for AI accelerators (2024–2025).", headline: "Chips run 15 °C cooler"),
        SciProjectDef(id: "rt_superconductor", field: .materials, name: "Room-temperature superconductor", pitch: "Zero resistance without cryogenics. Every claim so far has collapsed.",
                      year: 2030, difficulty: 0.42, size: 2.2, speculative: true,
                      basis: "Speculative: LK-99 (2023) and earlier claims did not reproduce.", headline: "A superconductor at room temperature"),
        // Mathematics
        SciProjectDef(id: "matmul", field: .mathematics, name: "Faster matrix-multiplication algorithms", pitch: "Search for multiplication schemes that need fewer products.",
                      year: 2021, difficulty: 0.08, size: 0.8, speculative: false,
                      basis: "Grounded: AlphaTensor (Nature, 2022) and AlphaEvolve (2025) found faster schemes.", headline: "A faster way to multiply small matrices"),
        SciProjectDef(id: "olympiad_prover", field: .mathematics, name: "Formal olympiad prover", pitch: "A system that writes machine-checked proofs of olympiad problems.",
                      year: 2023, difficulty: 0.15, size: 1, speculative: false,
                      basis: "Grounded: AlphaProof reached IMO silver in Lean (2024); gold-level natural-language proofs followed in 2025.", headline: "Machine-checked proofs at olympiad level"),
        SciProjectDef(id: "open_conjecture", field: .mathematics, name: "Settle an open conjecture", pitch: "Point the models at a decades-old combinatorics problem and let them search.",
                      year: 2025, difficulty: 0.28, size: 1.4, speculative: false,
                      basis: "Grounded: FunSearch improved the cap-set bound (Nature, 2023); AI-assisted results kept coming.", headline: "A decades-old conjecture settled"),
        SciProjectDef(id: "new_theory", field: .mathematics, name: "A new branch of mathematics", pitch: "Not a proof: a framework human mathematicians adopt.",
                      year: 2031, difficulty: 0.4, size: 2, speculative: true,
                      basis: "Speculative: no AI system has founded a field.", headline: "A new mathematical theory, adopted by the field"),
        // Robotics
        SciProjectDef(id: "dexterous_hand", field: .robotics, name: "Dexterous in-hand manipulation", pitch: "A five-finger hand that turns objects the way people do.",
                      year: 2018, difficulty: 0.15, size: 0.9, speculative: false,
                      basis: "Grounded: OpenAI's Dactyl solved a Rubik's cube one-handed (2019).", headline: "A robot hand with human dexterity on the bench"),
        SciProjectDef(id: "sim2real", field: .robotics, name: "Sim-to-real locomotion", pitch: "Train walking in simulation; it works on the first real robot.",
                      year: 2019, difficulty: 0.1, size: 0.8, speculative: false,
                      basis: "Grounded: legged robots trained purely in simulation transferred to hardware (ETH Zurich, 2019–2020).", headline: "Policies that walk out of the simulator"),
        SciProjectDef(id: "generalist_policy", field: .robotics, name: "Cross-embodiment generalist policy", pitch: "One model that drives arms, grippers and mobile bases from many makers.",
                      year: 2024, difficulty: 0.2, size: 1.2, speculative: false,
                      basis: "Grounded: Open X-Embodiment / RT-X (2023) and π0 (2024) showed cross-robot transfer.", headline: "One policy, twenty robot bodies"),
        SciProjectDef(id: "humanoid_picking", field: .robotics, name: "Humanoid picking at human speed", pitch: "A humanoid that works a warehouse shift as fast as a person.",
                      year: 2027, difficulty: 0.3, size: 1.6, speculative: true,
                      basis: "Speculative: humanoid pilots ran in 2024–2025 well below human throughput.", headline: "A humanoid that keeps up with the night shift"),
        // Scientific software
        SciProjectDef(id: "kernel_autotune", field: .software, name: "Autotuned inference kernels", pitch: "Let the models write and search GPU kernels for your serving stack.",
                      year: 2017, difficulty: 0.06, size: 0.8, speculative: false,
                      basis: "Grounded: learned kernel search and AI-written CUDA kernels beat hand-tuned code (2018–2025).", headline: "Serving kernels 20% faster than vendor libraries"),
        SciProjectDef(id: "spec_decoding", field: .software, name: "Speculative decoding", pitch: "A small model drafts, the big one verifies: same answers, fewer passes.",
                      year: 2022, difficulty: 0.1, size: 1, speculative: false,
                      basis: "Grounded: speculative decoding (Leviathan et al., Chen et al., 2022–2023) is standard practice.", headline: "Lossless 2× faster decoding"),
        SciProjectDef(id: "sparse_attention", field: .software, name: "Hardware-aware sparse attention", pitch: "Attend to what matters, in a layout the chip likes.",
                      year: 2024, difficulty: 0.16, size: 1.2, speculative: false,
                      basis: "Grounded: native sparse attention and FlashAttention-style kernels (2022–2025).", headline: "Long contexts at a fraction of the cost"),
        // Medical research
        SciProjectDef(id: "antibiotic_screen", field: .medical, name: "Deep-learning antibiotic screen", pitch: "Screen a hundred million molecules for ones that kill resistant bacteria.",
                      year: 2019, difficulty: 0.15, size: 0.9, speculative: false,
                      basis: "Grounded: MIT found halicin (2020) and abaucin (2023) with deep-learning screens.", headline: "A new antibiotic candidate against resistant bacteria"),
        SciProjectDef(id: "protein_binders", field: .medical, name: "De novo protein binders", pitch: "Design proteins from scratch that grab a disease target.",
                      year: 2021, difficulty: 0.15, size: 1, speculative: false,
                      basis: "Grounded: RFdiffusion and AlphaProteo designed working binders (2023–2024).", headline: "Designed proteins that bind on the first try"),
        SciProjectDef(id: "pathology_fm", field: .medical, name: "Validated pathology model", pitch: "A model that reads biopsy slides, validated in hospitals.",
                      year: 2023, difficulty: 0.1, size: 0.9, speculative: false,
                      basis: "Grounded: pathology foundation models (2023–2024) matched specialists on many tasks.", headline: "A pathology model hospitals trust"),
        SciProjectDef(id: "virtual_cell", field: .medical, name: "Predictive virtual cell", pitch: "Simulate how a cell responds to a drug before anyone runs the assay.",
                      year: 2029, difficulty: 0.35, size: 1.7, speculative: true,
                      basis: "Speculative: 'virtual cell' models were proposed in 2024 and are far from predictive.", headline: "A virtual cell that predicts drug responses"),
        // Industrial automation
        SciProjectDef(id: "visual_inspection", field: .automation, name: "Visual defect inspection", pitch: "Cameras and a model on every production line, catching defects people miss.",
                      year: 2016, difficulty: 0.05, size: 0.7, speculative: false,
                      basis: "Grounded: deep-learning inspection is standard in electronics and automotive plants.", headline: "Inspection that catches 99.9% of defects"),
        SciProjectDef(id: "self_driving_lab", field: .automation, name: "Closed-loop self-driving lab", pitch: "Models plan experiments, robots run them, results feed the next plan.",
                      year: 2021, difficulty: 0.15, size: 1, speculative: false,
                      basis: "Grounded: Berkeley's A-Lab and Liverpool's mobile robot chemist ran closed-loop campaigns (2020–2023).", headline: "A lab that runs itself for a month"),
        SciProjectDef(id: "dark_factory", field: .automation, name: "Lights-out assembly line", pitch: "A line that changes over to a new product without a human touching it.",
                      year: 2027, difficulty: 0.3, size: 1.4, speculative: true,
                      basis: "Speculative: 'dark factories' exist for narrow products, not flexible lines.", headline: "A factory line that retools itself"),
        // Quantum computing
        SciProjectDef(id: "qec_decoder", field: .quantum, name: "Neural error-correction decoder", pitch: "Decode surface-code syndromes faster and better than the textbook algorithms.",
                      year: 2023, difficulty: 0.18, size: 1, speculative: false,
                      basis: "Grounded: AlphaQubit (Nature, 2024) beat standard decoders on Sycamore data.", headline: "A decoder that beats the textbook"),
        SciProjectDef(id: "logical_qubit", field: .quantum, name: "Below-threshold logical qubit", pitch: "A logical qubit whose errors fall as you add physical qubits.",
                      year: 2025, difficulty: 0.3, size: 1.2, speculative: false,
                      basis: "Grounded: Google's Willow showed below-threshold error correction (Nature, 2024).", headline: "A logical qubit below threshold"),
        SciProjectDef(id: "quantum_chemistry", field: .quantum, name: "Useful quantum advantage in chemistry", pitch: "A catalyst simulation no classical computer can do, done on qubits.",
                      year: 2031, difficulty: 0.45, size: 2, speculative: true,
                      basis: "Speculative: no useful quantum advantage has been shown yet.", headline: "Quantum advantage on a real chemistry problem"),
        // Advanced semiconductors
        SciProjectDef(id: "rl_floorplan", field: .semiconductors, name: "Reinforcement-learned floorplanning", pitch: "Place a chip's blocks in hours instead of weeks.",
                      year: 2020, difficulty: 0.1, size: 0.8, speculative: false,
                      basis: "Grounded: AlphaChip floorplans shipped in Google TPUs (Nature, 2021).", headline: "Floorplans in hours, better than the experts'"),
        SciProjectDef(id: "backside_power", field: .semiconductors, name: "Backside power delivery", pitch: "Move the power wires under the transistors and free up the top for signals.",
                      year: 2023, difficulty: 0.25, size: 1.2, speculative: false,
                      basis: "Grounded: Intel PowerVia (2024) and TSMC's A16 bring backside power to production.", headline: "Backside power on your test chips"),
        SciProjectDef(id: "co_packaged_optics", field: .semiconductors, name: "Co-packaged optics", pitch: "Put the lasers next to the chip and cut interconnect power by two thirds.",
                      year: 2024, difficulty: 0.25, size: 1.3, speculative: false,
                      basis: "Grounded: co-packaged optical switches were announced for 2025–2026.", headline: "Optical I/O on the package"),
        SciProjectDef(id: "two_d_transistor", field: .semiconductors, name: "2D-material transistors", pitch: "Atom-thin channels for the generation after silicon runs out.",
                      year: 2031, difficulty: 0.45, size: 2, speculative: true,
                      basis: "Speculative: 2D-channel transistors are a research roadmap item, not a product.", headline: "A working 2D-channel logic process"),
        // Aerospace
        SciProjectDef(id: "verified_flight", field: .aerospace, name: "Verified autonomous flight control", pitch: "A learned flight controller with a proof it stays inside its envelope.",
                      year: 2019, difficulty: 0.15, size: 0.9, speculative: false,
                      basis: "Grounded: AI pilots flew the X-62A VISTA (2022–2024); runtime assurance is how it's certified.", headline: "A learned autopilot regulators can certify"),
        SciProjectDef(id: "orbital_compute", field: .aerospace, name: "Radiation-tolerant orbital compute", pitch: "AI accelerators that survive years in orbit.",
                      year: 2027, difficulty: 0.32, size: 1.4, speculative: true,
                      basis: "Speculative: orbital datacenters were proposed in 2024–2025; nothing at scale flies.", headline: "Accelerators that survive in orbit"),
    ]

    static let projectByID: [String: SciProjectDef] = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })

    // MARK: Stages

    static let stages: [StageDef] = [
        StageDef(stage: .hypothesis, name: "Hypothesis", compName: "Hypothesis", kind: .computational, days: 18, odds: 0.86, deadShare: 0.3, cost: 60_000,
                 blurb: "Literature, first-principles estimates and a model's brainstorm. Most bad ideas die here, cheaply."),
        StageDef(stage: .simulation, name: "Simulation", compName: "Numerical exploration", kind: .computational, days: 30, odds: 0.76, deadShare: 0.12, cost: 150_000,
                 blurb: "Compute does the first experiments: DFT, molecular dynamics, plasma codes, physics sims."),
        StageDef(stage: .design, name: "Experiment design", compName: "Method design", kind: .computational, days: 18, odds: 0.82, deadShare: 0.05, cost: 90_000,
                 blurb: "Pick the experiments with the most information per dollar."),
        StageDef(stage: .testing, name: "Physical testing", compName: "Formal verification", kind: .physical, days: 45, odds: 0.62, deadShare: 0.18, cost: 600_000,
                 blurb: "Make it and test it. Samples break, instruments drift, reality disagrees."),
        StageDef(stage: .measurement, name: "Measurement", compName: "Benchmarking", kind: .computational, days: 20, odds: 0.78, deadShare: 0.06, cost: 200_000,
                 blurb: "Characterise the result properly: error bars, controls, the boring part that matters."),
        StageDef(stage: .reproduction, name: "Reproduction", compName: "Independent reproduction", kind: .physical, days: 40, odds: 0.58, deadShare: 0.28, cost: 500_000,
                 blurb: "A second team does it again from the write-up. Plenty of famous results die here."),
        StageDef(stage: .prototype, name: "Prototype", compName: "Reference implementation", kind: .physical, days: 60, odds: 0.62, deadShare: 0.1, cost: 1_200_000,
                 blurb: "Turn the result into something that does a job."),
        StageDef(stage: .validation, name: "Engineering validation", compName: "Production hardening", kind: .physical, days: 50, odds: 0.62, deadShare: 0.15, cost: 800_000,
                 blurb: "Does it survive heat, vibration, ageing, bad inputs and a year of use?"),
        StageDef(stage: .manufacturing, name: "Manufacturing feasibility", compName: "Deployment at scale", kind: .physical, days: 60, odds: 0.52, deadShare: 0.4, cost: 2_000_000,
                 blurb: "Can it be made at volume, at a price, with yield? Promising science often dies here."),
        StageDef(stage: .commercialisation, name: "Commercialisation", compName: "Rollout", kind: .market, days: 45, odds: 0.72, deadShare: 0.1, cost: 1_000_000,
                 blurb: "Suppliers, customers, certification. Then it's real."),
    ]

    static func stage(_ st: SciStage) -> StageDef { stages[st.rawValue] }

    // MARK: Sites

    static let sites: [LabSite] = [
        LabSite(id: "sf", country: "us", strengths: [.computing: 6, .biology: 4, .robotics: 3, .semiconductor: 2], note: "Bay Area universities, biotech and every AI lab"),
        LabSite(id: "paris", country: "fr", strengths: [.computing: 6, .materials: 2, .biology: 2], note: "INRIA, the grandes écoles and France's best mathematicians"),
        LabSite(id: "grenoble", country: "fr", strengths: [.semiconductor: 8, .electronics: 6, .materials: 4], note: "France's chip valley and its national electronics lab"),
        LabSite(id: "lyon", country: "fr", strengths: [.biology: 7, .autolab: 3, .materials: 2], note: "Biotech, vaccine makers and chemicals"),
        LabSite(id: "turin", country: "it", strengths: [.robotics: 5, .electronics: 3, .autolab: 2], note: "Automotive, aerospace and automation suppliers"),
        LabSite(id: "milan", country: "it", strengths: [.materials: 4, .autolab: 2, .energy: 2], note: "Politecnico di Milano and Italy's materials industry"),
        LabSite(id: "rome", country: "it", strengths: [.electronics: 2, .energy: 3], note: "National research institutes, aerospace and fusion research"),
        LabSite(id: "copenhagen", country: "dk", strengths: [.biology: 6, .energy: 3, .computing: 2], note: "Life-science giants and a national AI supercomputer"),
        LabSite(id: "aarhus", country: "dk", strengths: [.energy: 6, .materials: 2], note: "Wind-turbine makers and a big university"),
        LabSite(id: "odense", country: "dk", strengths: [.robotics: 8, .autolab: 3], note: "One of Europe's densest robotics clusters"),
        LabSite(id: "aalborg", country: "dk", strengths: [.energy: 4, .electronics: 4], note: "Wireless and energy-systems research"),
        LabSite(id: "bucharest", country: "ro", strengths: [.computing: 3, .electronics: 2], note: "Engineering centres and fast fibre, at low cost"),
        LabSite(id: "cluj", country: "ro", strengths: [.computing: 3, .biology: 1], note: "University research at the lowest cost in the EU"),
    ]

    static let siteByID: [String: LabSite] = Dictionary(uniqueKeysWithValues: sites.map { ($0.id, $0) })

    // MARK: Rival science

    /// Rival labs that run science programmes: (lab, how active, fields they favour, what they call their science arm).
    static let rivalLabs: [(lab: String, appetite: Double, fields: [SciField], arm: String)] = [
        ("deepgrove", 1.0, [.materials, .fusion, .mathematics, .medical, .quantum, .robotics], "DeepGrove Science"),
        ("aletheia", 0.8, [.mathematics, .medical, .materials], "Aletheia Discovery"),
        ("xenon", 0.6, [.robotics, .energy, .aerospace, .batteries], "Xenon Applied Physics"),
        ("dragonlake", 0.5, [.mathematics, .software, .semiconductors, .batteries], "Dragon Lake Institute"),
        ("prometheus", 0.4, [.software, .medical, .robotics], "Prometheus for Science"),
        ("openweights", 0.3, [.software, .robotics], "OpenWeights Research"),
        ("halcyon", 0.25, [.medical, .software], "Halcyon Science"),
    ]
}
