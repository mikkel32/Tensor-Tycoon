import Foundation

// MARK: - 3.9: grand challenges (prize competitions) and the things a lab can open-source

/// A prize competition with real stakes. Each edition is announced, takes entries for a few weeks, publishes a halfway
/// leaderboard and is decided on its results day from the entrants' real capability (a weighted mix of capability
/// domains), the know-how behind them, their science and how hard they went. Organisations are fictional analogues.
struct ChallengeDef: Identifiable, Sendable {
    let id: String
    let name: String
    let short: String
    let organiser: String
    let symbol: String
    let image: String
    /// Capability domains the task tests, weighted.
    let mix: [(CapDomain, Double)]
    /// Research that helps, in score points (rivals pick it up a quarter after its real date).
    let knowhow: [(String, Double)]
    /// Your discoveries in these science fields add points, and a win lifts momentum in the first.
    var fields: [SciField] = []
    /// Owning one of these science labs adds points (a self-driving lab, a robot arena).
    var labs: [LabKind] = []
    /// Rivals that specialise here try harder.
    var focus: RivalFocus? = nil
    // Schedule
    /// First announcement (fractional year: the month matters), years between editions (0 = one-off) and the last
    /// edition year.
    let first: Double
    var cadence = 1
    var last = 2040
    /// Announcement to results, in months; the public leaderboard (and any milestone awards) comes at `checkpoint`.
    let months: Int
    var checkpointShare = 0.5
    // Stakes
    /// Prize money for 1st, 2nd and 3rd, and the one-off grand prize for clearing the bar (0 = none).
    let purse: [Double]
    var grandPrize: Double = 0
    /// The score that clears the grand prize bar (and anchors the metric).
    let bar: Double
    /// The challenge retires once its bar is cleared.
    var endsOnGrand = false
    /// Milestone awards at the checkpoint: each of the top `milestoneTop` teams gets `milestonePrize`.
    var milestonePrize: Double = 0
    var milestoneTop = 0
    // Entry
    /// Organisers turn away entries scoring below this.
    let minScore: Double
    var requires: String? = nil
    var minSafety: Double = 0
    /// Prize money only for entries released as open weights (others may enter as an exhibition).
    var openTrack = false
    /// Finalists must open-source their systems (they become a repo).
    var publishes = false
    /// What a standard entry costs (compute, staff time, kit); all-in is three times as much.
    let entryCost: Double
    // How results read
    let unit: String
    let metricAtBar: Double
    let metricSlope: Double
    let metricMin: Double
    let metricMax: Double
    var decimals = 0
    // Prestige for a win (a podium gets a third, the grand prize half again)
    let brand: Double
    let researchers: Double
    var publicTrust: Double = 1
    var political: Double = 0
    var regions: [String: Double] = [:]
    /// Strong outside teams (startups, universities): their names and how far from the best lab they start.
    var outside: [String] = ["A university consortium"]
    var outsideGap: Double = 10
    /// Who cleared the bar in our timeline, and when: games starting later find it already claimed.
    var historic: String = ""
    var historicYear: Double = 0
    let task: String
    let grandGoal: String
    let basis: String
    /// What a win brings, in a sentence (completes "Win it: …").
    let reward: String

    /// The metric a score reads as ("31/42 points", "GDT 88.4").
    func metric(_ score: Double, bar b: Double? = nil) -> Double {
        let x = metricAtBar + metricSlope * (score - (b ?? bar))
        // Past the bar, results crowd toward the ceiling instead of hitting it (GDT 95, 96.5, 97.2 … never 100).
        if x > metricAtBar && metricMax > metricAtBar {
            let room = metricMax - metricAtBar
            return metricAtBar + room * (1 - exp(-(x - metricAtBar) / (2 * room)))
        }
        return clamp(x, metricMin, metricMax)
    }

    func metricText(_ score: Double, bar b: Double? = nil) -> String {
        let v = metric(score, bar: b)
        let n = decimals == 0 ? Fmt.int(Int(v.rounded())) : Fmt.trim(v, decimals)
        return unit.hasPrefix("/") ? "\(n)\(unit)" : (unit.hasPrefix("GDT") ? "\(unit) \(n)" : "\(n) \(unit)")
    }

    var photo: String { ImagePicker.pick(image == "robotics" ? .robotics : (image == "events" ? .events : .science), seed: id) }
}

/// Something a lab can open-source besides model weights: a library, a dataset, a protocol.
struct OpenToolDef: Identifiable, Sendable {
    let id: String
    /// "{lab}" is your short company name.
    let name: String
    let what: String
    let symbol: String
    let year: Double
    var requires: String? = nil
    /// Stars it can reach at full quality in a mature developer world.
    let stars: Double
    /// Maintainers it needs (engineers' time, a monthly cost).
    let maintainers: Int
    /// Points it adds to your developer ecosystem and to how researchers and developers see you while maintained.
    let ecosystem: Double
    let researchers: Double
    let developers: Double
    /// What rivals gain in capability from it (log10 compute units; capped across tools) and the market's API price
    /// pressure it adds on release.
    var rivalC: Double = 0
    var pricePressure: Double = 0
    /// Safety scrutiny on release (negative calms it), and a one-off safety score change.
    var scrutiny: Double = 0
    var safety: Double = 0
    let upside: String
    let downside: String
}

enum ChallengeCatalog {
    static let all: [ChallengeDef] = [
        ChallengeDef(id: "fold", name: "FOLD: Blind Protein Structure Assessment", short: "FOLD", organiser: "the Structure Prediction Center (an academic consortium)",
                     symbol: "allergens.fill", image: "science",
                     mix: [(.science, 0.55), (.reasoning, 0.2), (.knowledge, 0.25)],
                     knowhow: [("alphafold", 10), ("protein_design", 4), ("ai_scientist", 3)],
                     fields: [.medical], labs: [.biology, .autolab], focus: .science,
                     first: 2018.25, cadence: 2, months: 8, purse: [0, 0, 0], grandPrize: 1_000_000, bar: 79, minScore: 35, entryCost: 1_500_000,
                     unit: "GDT", metricAtBar: 90, metricSlope: 1.0, metricMin: 25, metricMax: 99, decimals: 1,
                     brand: 4, researchers: 5, publicTrust: 1.5, outside: ["A university structural-biology group", "A protein-design institute"], outsideGap: 9,
                     historic: "deepgrove", historicYear: 2020.92,
                     task: "Predict the 3D shapes of about 100 proteins whose structures were solved in the lab this summer and kept secret until judging.",
                     grandGoal: "A median accuracy of 90 GDT: as good as the lab experiment",
                     basis: "Grounded: CASP has run every two years since 1994. In December 2020 AlphaFold 2 reached a median GDT of 92.4 and the organisers called the 50-year-old problem largely solved.",
                     reward: "no purse (a philanthropist's $1M sits on the 90 GDT bar), but the most-watched leaderboard in biology: researchers queue to join and medical science speeds up."),
        ChallengeDef(id: "weather", name: "Medium-Range Forecast Duel", short: "Forecast Duel", organiser: "the Continental Weather Centre and a reinsurance consortium",
                     symbol: "cloud.sun.rain.fill", image: "science",
                     mix: [(.science, 0.5), (.reasoning, 0.2), (.knowledge, 0.3)],
                     knowhow: [("graphcast", 10), ("deep_research", 2)],
                     fields: [.energy], focus: .science,
                     first: 2019.7, cadence: 1, months: 6, purse: [500_000, 200_000, 100_000], grandPrize: 2_000_000, bar: 99, minScore: 35, entryCost: 1_000_000,
                     unit: "% of targets beaten", metricAtBar: 90, metricSlope: 2.5, metricMin: 0, metricMax: 99,
                     brand: 2.5, researchers: 3, publicTrust: 2, political: 3, outside: ["A national weather service team", "A university climate lab"], outsideGap: 8,
                     historic: "deepgrove", historicYear: 2023.3,
                     task: "Ten-day global forecasts every day for a season, scored against what the weather actually did on 1,380 variables and lead times.",
                     grandGoal: "Beat the leading physics model on 90% of targets",
                     basis: "Grounded: in 2023 GraphCast beat the best operational forecast on 90% of 1,380 targets, and ran in under a minute on one chip instead of hours on a supercomputer.",
                     reward: "a modest purse from reinsurers, political goodwill and a reputation for science that saves lives."),
        ChallengeDef(id: "scrolls", name: "Ashen Scrolls Challenge", short: "Ashen Scrolls", organiser: "a patrons' fund and the university team that X-rayed the scrolls",
                     symbol: "scroll.fill", image: "science",
                     mix: [(.vision, 0.6), (.reasoning, 0.2), (.knowledge, 0.2)],
                     knowhow: [("vision", 3), ("native_multimodal", 3)],
                     first: 2023.2, cadence: 1, last: 2032, months: 10, purse: [100_000, 50_000, 25_000], grandPrize: 700_000, bar: 107, endsOnGrand: true,
                     minScore: 40, entryCost: 500_000,
                     unit: "characters read", metricAtBar: 560, metricSlope: 30, metricMin: 0, metricMax: 4_000,
                     brand: 5, researchers: 2, publicTrust: 3, outside: ["Three students with a gaming PC", "A papyrology lab", "A volunteer Discord team"], outsideGap: 3,
                     historic: "outside:Three students with a gaming PC", historicYear: 2024.1,
                     task: "Read the carbonised scrolls buried by Vesuvius in AD 79 from X-ray scans, without unrolling them: find the ink nobody can see.",
                     grandGoal: "Four passages of 140 characters, 85% legible",
                     basis: "Grounded: the Vesuvius Challenge (2023) paid a $700,000 grand prize in February 2024 to three students whose models read more than 2,000 characters of a lost Greek text.",
                     reward: "small money, enormous attention: the whole internet shares the first lines read in 2,000 years."),
        ChallengeDef(id: "gauss", name: "Gauss Prize for AI Mathematics", short: "Gauss Prize", organiser: "a quantitative trading firm's $10M prize fund",
                     symbol: "function", image: "events",
                     mix: [(.math, 0.7), (.reasoning, 0.3)],
                     knowhow: [("formal_math", 4), ("verified_reasoning", 4), ("co_mathematician", 3), ("reasoning_rl", 3)],
                     fields: [.mathematics],
                     first: 2023.88, cadence: 1, last: 2034, months: 8, purse: [1_000_000, 500_000, 250_000], grandPrize: 5_000_000, bar: 131, endsOnGrand: true,
                     minScore: 60, openTrack: true, entryCost: 2_000_000,
                     unit: "/42 points", metricAtBar: 35, metricSlope: 1.0, metricMin: 0, metricMax: 42,
                     brand: 3, researchers: 4, outside: ["A university maths-AI group", "A trading firm's research team"], outsideGap: 12,
                     task: "Sit this summer's olympiad paper under exam rules: six problems, nine hours, proofs marked by the same coordinators as the students'.",
                     grandGoal: "A gold-medal score (35 of 42) from a publicly released model",
                     basis: "Grounded: the AIMO fund ($10M, 2023) pays only for publicly shared models. In July 2025 two labs' closed models scored gold at the IMO; no open model had claimed the grand prize by then.",
                     reward: "progress prizes, a $5M grand prize for gold with open weights, and the mathematicians' respect."),
        ChallengeDef(id: "cyber", name: "Autonomous Cyber Defence Challenge", short: "Cyber Challenge", organiser: "the Office of Advanced Defense Research (OADR) with the National Cyber Resilience Agency",
                     symbol: "lock.shield.fill", image: "events",
                     mix: [(.coding, 0.55), (.agents, 0.25), (.reasoning, 0.2)],
                     knowhow: [("swe_agent", 3), ("vuln_discovery", 4), ("cyber_defense", 5)],
                     focus: .coding,
                     first: 2023.6, cadence: 3, last: 2035, months: 24, purse: [4_000_000, 3_000_000, 1_500_000], bar: 140,
                     milestonePrize: 2_000_000, milestoneTop: 7, minScore: 50, publishes: true, entryCost: 4_000_000,
                     unit: "% of planted bugs found and patched", metricAtBar: 80, metricSlope: 2, metricMin: 0, metricMax: 100,
                     brand: 2, researchers: 2, publicTrust: 1, political: 6, regions: ["us": 4, "uk": 1],
                     outside: ["A university security lab", "A cybersecurity startup", "A defence contractor's team"], outsideGap: 6,
                     task: "Build a system that finds and patches vulnerabilities in the open-source code the internet runs on, with no human help. Semifinal after a year, final after two.",
                     grandGoal: "Find and fix most of the planted bugs",
                     basis: "Grounded: DARPA's AI Cyber Challenge (2023–2025, $29.5M) paid $2M to each of seven finalists in 2024 and $4M to the winner in 2025; finalists open-sourced their systems.",
                     reward: "real money, a $2M semifinal award, political capital in Washington and a system you must open-source."),
        ChallengeDef(id: "robotics", name: "Disaster Response Robotics Challenge", short: "Robotics Challenge", organiser: "the Office of Advanced Defense Research (OADR)",
                     symbol: "figure.walk", image: "robotics",
                     mix: [(.robotics, 0.65), (.vision, 0.2), (.agents, 0.15)],
                     knowhow: [("vla", 5), ("robot_fm", 6), ("world_models", 3), ("world_model_planning", 2)],
                     fields: [.robotics, .automation], labs: [.robotics], focus: .robotics,
                     first: 2025.3, cadence: 3, months: 15, purse: [2_000_000, 1_000_000, 500_000], grandPrize: 3_000_000, bar: 160, minScore: 60, entryCost: 8_000_000,
                     unit: "/8 tasks", metricAtBar: 8, metricSlope: 0.15, metricMin: 0, metricMax: 8,
                     brand: 4, researchers: 3, publicTrust: 3, political: 3, regions: ["us": 2],
                     outside: ["A university robotics lab", "A humanoid-robot startup", "A defence robotics firm"], outsideGap: 5,
                     task: "Drive a utility vehicle to a wrecked plant, get out, open doors, turn valves, cut through a wall and climb stairs, over a radio link that keeps dropping.",
                     grandGoal: "All eight tasks in under an hour with no human stepping in",
                     basis: "Grounded: the DARPA Robotics Challenge (2015, $2M) set these eight tasks; the winner took 44 minutes and most robots fell over at least once.",
                     reward: "prize money, a robotics reputation customers notice and political goodwill."),
        ChallengeDef(id: "materials", name: "Grid Storage Materials Challenge", short: "Materials Challenge", organiser: "the Federal Energy Science Office (FESO)",
                     symbol: "battery.100percent.bolt", image: "science",
                     mix: [(.science, 0.55), (.reasoning, 0.2), (.agents, 0.25)],
                     knowhow: [("materials_ai", 8), ("lab_automation", 4), ("ai_scientist", 3)],
                     fields: [.batteries, .materials, .energy], labs: [.materials, .autolab, .energy], focus: .science,
                     first: 2024.4, cadence: 2, months: 18, purse: [5_000_000, 2_000_000, 1_000_000], grandPrize: 10_000_000, bar: 185, minScore: 70, entryCost: 6_000_000,
                     unit: "% of the target (best candidate)", metricAtBar: 100, metricSlope: 1.5, metricMin: 0, metricMax: 160,
                     brand: 3, researchers: 3, publicTrust: 1.5, political: 3,
                     outside: ["A national-lab materials team", "A battery startup", "A university chemistry department"], outsideGap: 6,
                     task: "Propose 100 new solid electrolytes; an independent national lab synthesises your top ten and runs them through conductivity and cycling tests.",
                     grandGoal: "A candidate that beats today's best conductor and survives 1,000 cycles",
                     basis: "Grounded: GNoME (2023) predicted 2.2 million stable crystals and a robotic lab made 41 new compounds in 17 days; chemists then disputed how new some were. Independent synthesis is the real test.",
                     reward: "a large purse, a $10M grand prize and a head start in energy science."),
        ChallengeDef(id: "horizon_carbon", name: "Horizon Prize for Carbon Removal", short: "Horizon Carbon", organiser: "the Horizon Prize Foundation",
                     symbol: "leaf.fill", image: "science",
                     mix: [(.science, 0.45), (.agents, 0.25), (.reasoning, 0.15), (.knowledge, 0.15)],
                     knowhow: [("materials_ai", 6), ("ai_scientist", 4), ("graphcast", 2)],
                     fields: [.energy, .materials], labs: [.energy, .materials, .autolab],
                     first: 2021.3, cadence: 0, last: 2021, months: 48, checkpointShare: 0.25, purse: [50_000_000, 15_000_000, 8_000_000], bar: 120,
                     milestonePrize: 1_000_000, milestoneTop: 15, minScore: 50, entryCost: 25_000_000,
                     unit: "t of CO₂ removed a year", metricAtBar: 1_000, metricSlope: 60, metricMin: 0, metricMax: 20_000,
                     brand: 8, researchers: 3, publicTrust: 5, political: 5, regions: ["eu": 3, "uk": 2],
                     outside: ["A rock-weathering startup", "A direct-air-capture company", "An ocean-alkalinity team", "A biochar cooperative"], outsideGap: 2,
                     task: "With a direct-air-capture partner, design the sorbents and run the plant: remove at least 1,000 tonnes of CO₂ a year and show a path to a gigatonne.",
                     grandGoal: "1,000 tonnes a year, verified, with a credible path to gigatonne scale",
                     basis: "Grounded: XPRIZE Carbon Removal ($100M, 2021–2025) gave $1M milestone awards to 15 teams in 2022 and $50M to the winner in April 2025.",
                     reward: "the biggest purse in the game, $1M milestone awards and a public that thinks AI might save the planet."),
        ChallengeDef(id: "horizon_health", name: "Horizon Prize for Healthspan", short: "Horizon Healthspan", organiser: "the Horizon Prize Foundation",
                     symbol: "heart.text.square.fill", image: "science",
                     mix: [(.science, 0.5), (.reasoning, 0.2), (.knowledge, 0.2), (.agents, 0.1)],
                     knowhow: [("alphafold", 3), ("protein_design", 4), ("ai_scientist", 5), ("lab_automation", 3), ("virtual_cell", 5)],
                     fields: [.medical], labs: [.biology, .autolab],
                     first: 2023.88, cadence: 0, last: 2023, months: 72, checkpointShare: 0.25, purse: [50_000_000, 20_000_000, 10_000_000], bar: 200,
                     milestonePrize: 250_000, milestoneTop: 40, minScore: 80, minSafety: 50, entryCost: 30_000_000,
                     unit: "years of function restored", metricAtBar: 10, metricSlope: 0.15, metricMin: 0, metricMax: 25, decimals: 1,
                     brand: 10, researchers: 5, publicTrust: 5, political: 3,
                     outside: ["A longevity biotech", "A university ageing institute", "A pharma spin-out", "A clinical-trials network"], outsideGap: 3,
                     task: "With clinical partners, design a therapy that restores muscle, brain and immune function in 65–80 year olds, proven in a one-year trial.",
                     grandGoal: "Ten years of lost function restored, in a real trial",
                     basis: "Grounded: XPRIZE Healthspan ($101M, 2023–2030) gave $250,000 milestone awards to 40 semifinalists in 2025; the finals run trials through 2030.",
                     reward: "a huge purse, milestone awards and the public's lasting gratitude, if the trial works."),
        ChallengeDef(id: "horizon_learning", name: "Horizon Prize for Universal Tutoring", short: "Horizon Learning", organiser: "the Horizon Prize Foundation and a development bank",
                     symbol: "graduationcap.fill", image: "events",
                     mix: [(.social, 0.35), (.knowledge, 0.25), (.reasoning, 0.2), (.voice, 0.1), (.multilingual, 0.1)],
                     knowhow: [("pedagogy", 6), ("character", 2), ("multilingual", 3), ("whisper", 2)],
                     focus: .consumer,
                     first: 2027.8, cadence: 0, last: 2027, months: 36, checkpointShare: 0.33, purse: [30_000_000, 10_000_000, 5_000_000], bar: 190,
                     milestonePrize: 1_000_000, milestoneTop: 10, minScore: 90, minSafety: 40, entryCost: 15_000_000,
                     unit: "× the learning gain", metricAtBar: 2, metricSlope: 0.02, metricMin: 0.5, metricMax: 4, decimals: 2,
                     brand: 8, researchers: 2, publicTrust: 6, political: 4, regions: ["india": 4, "eu": 1],
                     outside: ["An edtech non-profit", "A tablet-learning startup", "A teachers' cooperative"], outsideGap: 5,
                     task: "Tutor a million children in low-income countries in their own languages, on cheap phones, for 15 months; an independent trial measures what they learned.",
                     grandGoal: "Double the learning gains of the control group",
                     basis: "Grounded: the Global Learning XPRIZE ($15M, 2014–2019) ran a 15-month field trial with 2,700 children in Tanzania; this is the AI-tutor sequel the field keeps calling for.",
                     reward: "a large purse, $1M milestone awards and goodwill in every government that buys education."),
    ]

    static let byID: [String: ChallengeDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    // MARK: Open-source tools

    static let tools: [OpenToolDef] = [
        OpenToolDef(id: "train_lib", name: "{lab} Train", what: "Your distributed training library", symbol: "hammer.fill", year: 2017.0,
                    stars: 25_000, maintainers: 3, ecosystem: 4, researchers: 3, developers: 1, rivalC: 0.04,
                    upside: "Researchers learn on your stack and want to work where it was built.",
                    downside: "Rivals train faster on your code: they catch up a little."),
        OpenToolDef(id: "eval_harness", name: "{lab} Evals", what: "Your evaluation harness", symbol: "checklist", year: 2020.3,
                    stars: 9_000, maintainers: 2, ecosystem: 2, researchers: 3, developers: 1, scrutiny: -4, safety: 1,
                    upside: "Becomes the yardstick: researchers trust your numbers and regulators like shared tests.",
                    downside: "Rivals tune to your tests; a few maintainers' salaries."),
        OpenToolDef(id: "corpus", name: "{lab} Corpus", what: "An open pre-training dataset", symbol: "books.vertical.fill", year: 2020.9,
                    stars: 6_000, maintainers: 2, ecosystem: 3, researchers: 4, developers: 1, rivalC: 0.03, scrutiny: 6,
                    upside: "Every academic lab trains on it, and cites you.",
                    downside: "Rivals train on it too, and rights holders comb it for their work."),
        OpenToolDef(id: "inference", name: "{lab} Serve", what: "Your high-throughput inference engine", symbol: "bolt.horizontal.fill", year: 2023.4, requires: "flash_attention",
                    stars: 45_000, maintainers: 5, ecosystem: 10, researchers: 1, developers: 4, pricePressure: 0.02,
                    upside: "The default way to run open models: a big developer ecosystem on your formats.",
                    downside: "Everyone serves cheaper: API prices across the market fall."),
        OpenToolDef(id: "guard", name: "{lab} Guard", what: "An open safety classifier", symbol: "checkmark.shield.fill", year: 2023.9, requires: "constitutional",
                    stars: 5_000, maintainers: 2, ecosystem: 2, researchers: 2, developers: 1, scrutiny: -12, safety: 2,
                    upside: "Gives every open model a seatbelt: safety scrutiny eases and safety teams cheer.",
                    downside: "Jailbreakers study it too; maintainers to pay."),
        OpenToolDef(id: "interp", name: "{lab} Lens", what: "An interpretability toolkit", symbol: "eye.circle.fill", year: 2024.4, requires: "interpretability",
                    stars: 8_000, maintainers: 2, ecosystem: 1, researchers: 4, developers: 0, scrutiny: -6, safety: 2,
                    upside: "Safety researchers worldwide build on your methods; regulators notice.",
                    downside: "Little commercial value; shows rivals how you look inside models."),
        OpenToolDef(id: "agent_protocol", name: "{lab} Agent Protocol", what: "An open protocol for connecting agents to tools", symbol: "point.3.connected.trianglepath.dotted", year: 2024.9, requires: "tool_use",
                    stars: 60_000, maintainers: 6, ecosystem: 14, researchers: 1, developers: 6, rivalC: 0.02, scrutiny: 4,
                    upside: "If it becomes the standard, every tool speaks your language: the biggest ecosystem lift there is.",
                    downside: "Rivals' agents plug into it as well, and prompt-injection incidents land on your name."),
    ]

    static let toolByID: [String: OpenToolDef] = Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0) })
}
