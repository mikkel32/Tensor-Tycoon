import Foundation

// MARK: - 3.9: the founding government contract — schemes by country, era and size

/// The real-world award schemes a new AI lab can win first, matched to its headquarters and size. Agencies come from the
/// Advanced Projects catalogue (fictional analogues); the schemes are generic (SBIR, seedlings, innovation-fund grants,
/// EU accelerator grants, other-transaction prototypes, defence-fund research actions). Amounts are in that year's
/// dollars, sized to what the real programmes paid: SBIR Phase I was $150K in 2017 and $314K in 2024; an EU
/// accelerator grant is up to €2.5M at 70%; a defence-fund research action runs to €100M+.
enum FoundingCatalog {
    struct Topic: Sendable {
        let year: Double
        let agency: String
        let title: String
        let objective: String
    }

    struct Phase: Sendable {
        let name: String
        let terms: FoundingTerms
        /// (year, dollars) anchors for the standard award.
        let budget: [(Double, Double)]
        let months: Int
        var indirect: Double = 0
        var fee: Double = 0
        var funding: Double = 1
        var advance: Double = 0
        var retention: Double = 0
        let plan: [FCMilestoneKind]
        /// For a lab with no model yet: the model bar sits this far below the frontier at its due date.
        let gap: Double
        /// For a lab with models: the bar sits this far above its best.
        let lift: Double
    }

    struct Scheme: Sendable {
        let id: String
        let countries: [String]
        let tiers: [Int]
        let programme: String
        let short: String
        /// Contract numbers: "C" (contract), "G" (grant) or "OT" (other transaction).
        let instrument: String
        let phases: [Phase]
        let topics: [Topic]
        /// Award size by company tier (0 startup, 1 growth, 2 major).
        var tierScale: [Double] = [1, 1, 1]
        let blurb: String
    }

    static let eu = ["dk", "fr", "it", "ro"]

    static let schemes: [Scheme] = [
        Scheme(id: "us_sbir", countries: ["us"], tiers: [0], programme: "Small Business Innovation Research", short: "SBIR", instrument: "C",
               phases: [
                   Phase(name: "Phase I feasibility", terms: .fixedPrice,
                         budget: [(2016, 150_000), (2019.5, 225_000), (2022, 275_000), (2024.5, 314_000), (2030, 400_000)], months: 8,
                         plan: [.kickoff, .staffing, .model, .final], gap: 2.6, lift: 0.25),
                   Phase(name: "Phase II prototype", terms: .costPlus,
                         budget: [(2016, 1_000_000), (2019.5, 1_500_000), (2022, 1_840_000), (2024.5, 2_100_000), (2030, 2_700_000)], months: 24,
                         indirect: 0.45, fee: 0.07, plan: [.kickoff, .research, .model, .release, .safety, .report, .final], gap: 1.6, lift: 0.6),
               ],
               topics: [
                   Topic(year: 2016, agency: "oadr", title: "Explainable recommendations for intelligence analysts",
                         objective: "Show that a learned model can rank sensor reports for an analyst and explain each ranking in plain language."),
                   Topic(year: 2016, agency: "feso", title: "Learned load forecasting for regional grids",
                         objective: "Forecast hourly demand on a regional grid a week ahead, better than the utility's statistical model."),
                   Topic(year: 2017, agency: "nhri", title: "De-identification of clinical notes",
                         objective: "Strip personal details from free-text clinical notes reliably enough for research release."),
                   Topic(year: 2019, agency: "oadr", title: "Predictive maintenance from fleet sensor logs",
                         objective: "Predict component failures on a vehicle fleet from maintenance logs and sensor data, weeks ahead."),
                   Topic(year: 2020, agency: "ncra", title: "Automated triage of vulnerability reports",
                         objective: "Read incoming vulnerability reports, deduplicate them and rank them by real-world exploitability."),
                   Topic(year: 2021, agency: "feso", title: "Machine-learning screening of battery materials",
                         objective: "Screen candidate electrolyte materials with a learned model before any are made in a lab."),
                   Topic(year: 2023, agency: "oadr", title: "Language models for after-action report triage",
                         objective: "Summarise and cross-reference after-action reports so lessons reach units in days, not months."),
                   Topic(year: 2023.5, agency: "nhri", title: "Grounded summaries of clinical-trial literature",
                         objective: "Answer clinicians' questions from the trial literature with every claim cited to its source."),
                   Topic(year: 2025, agency: "ncra", title: "Autonomous patching of memory-safety bugs",
                         objective: "Find, fix and test memory-safety bugs in open-source infrastructure code, with a human approving each patch."),
                   Topic(year: 2025.5, agency: "oadr", title: "Red-teaming agents for mission software",
                         objective: "Agents that probe mission software for failures under supervision, and write up what they find."),
               ],
               blurb: "The federal set-aside for small firms: a fixed-price Phase I to prove feasibility, then a cost-plus Phase II prototype for the firms that deliver."),
        Scheme(id: "us_seedling", countries: ["us"], tiers: [1], programme: "OADR exploratory seedling", short: "Seedling", instrument: "C",
               phases: [
                   Phase(name: "Base period", terms: .costPlus,
                         budget: [(2016, 1_000_000), (2020, 1_500_000), (2023, 2_500_000), (2026, 4_000_000), (2030, 6_000_000)], months: 12,
                         indirect: 0.5, fee: 0.08, plan: [.kickoff, .research, .model, .report, .final], gap: 1.6, lift: 0.35),
                   Phase(name: "Option period", terms: .costPlus,
                         budget: [(2016, 2_500_000), (2020, 4_000_000), (2023, 6_000_000), (2026, 10_000_000), (2030, 15_000_000)], months: 18,
                         indirect: 0.5, fee: 0.08, plan: [.kickoff, .staffing, .model, .safety, .paper, .final], gap: 1.0, lift: 0.6),
               ],
               topics: [
                   Topic(year: 2016, agency: "oadr", title: "Explainable decision aids",
                         objective: "Explain why a learned model made each recommendation, well enough that an operator can tell when to distrust it."),
                   Topic(year: 2018, agency: "oadr", title: "Machine common sense",
                         objective: "Measure and improve how a model handles everyday physical and social situations it was never trained on."),
                   Topic(year: 2020, agency: "oadr", title: "AI for contested logistics",
                         objective: "Re-plan supply routes in minutes when links are cut, with a planner approving every change."),
                   Topic(year: 2022.5, agency: "oadr", title: "Assured autonomy for uncrewed systems",
                         objective: "Give autonomy software evidence of safe behaviour that a certifier can check."),
                   Topic(year: 2024, agency: "oadr", title: "AI cyber reasoning systems",
                         objective: "Find and fix vulnerabilities in critical open-source code without human hints, in a scored challenge."),
                   Topic(year: 2025.5, agency: "oadr", title: "Assurance of agentic AI",
                         objective: "Methods to bound what an AI agent can do, test it before deployment and audit it after."),
               ],
               blurb: "A defence research agency pays for a short, risky look at an idea before it commits a full programme: a cost-plus base period with a priced option."),
        Scheme(id: "us_ota", countries: ["us"], tiers: [2], programme: "Other Transaction prototype agreement", short: "OT prototype", instrument: "OT",
               phases: [
                   Phase(name: "Prototype", terms: .fixedPrice,
                         budget: [(2016, 20_000_000), (2020, 40_000_000), (2024, 100_000_000), (2025.5, 200_000_000), (2030, 400_000_000)], months: 24,
                         plan: [.kickoff, .staffing, .model, .safety, .release, .final], gap: 0.6, lift: 0.4),
               ],
               topics: [
                   Topic(year: 2016, agency: "oadr", title: "Decision support for joint planning",
                         objective: "Prototype a planning assistant that drafts courses of action and checks them against doctrine."),
                   Topic(year: 2022, agency: "oadr", title: "Frontier models for national-security workflows",
                         objective: "Prototype frontier AI on government networks for analysis, planning and software work, with strict access controls."),
                   Topic(year: 2025, agency: "oadr", title: "Agentic workflows for the defence enterprise",
                         objective: "Prototype AI agents for logistics, finance and software across the department, under human authority."),
               ],
               blurb: "A fast, flexible prototype agreement outside the procurement rules, paid on milestones; a success can roll straight into a production award."),
        Scheme(id: "dk_booster", countries: ["dk"], tiers: [0], programme: "DFGI innovation booster", short: "Booster", instrument: "G",
               phases: [
                   Phase(name: "Innovation booster", terms: .grant,
                         budget: [(2016, 350_000), (2022, 500_000), (2026, 700_000), (2030, 850_000)], months: 12,
                         indirect: 0.25, funding: 0.6, advance: 0.3, retention: 0.1, plan: [.kickoff, .research, .model, .final], gap: 2.6, lift: 0.25),
                   Phase(name: "Grand-solutions partnership", terms: .grant,
                         budget: [(2016, 2_500_000), (2022, 4_000_000), (2026, 5_500_000), (2030, 7_000_000)], months: 36,
                         indirect: 0.25, funding: 0.75, advance: 0.25, retention: 0.1, plan: [.kickoff, .staffing, .research, .paper, .model, .report, .final], gap: 1.4, lift: 0.6),
               ],
               topics: [
                   Topic(year: 2016, agency: "dfgi", title: "Forecasting offshore wind output",
                         objective: "Forecast a wind farm's output a day ahead from weather models, accurately enough to bid it into the power market."),
                   Topic(year: 2019, agency: "dfgi", title: "Learned control for district heating",
                         objective: "Run a district-heating network with a learned controller that cuts losses without leaving anyone cold."),
                   Topic(year: 2022, agency: "dfgi", title: "Grid-balancing agents for a wind-heavy grid",
                         objective: "Agents that schedule batteries, heat pumps and electrolysers to absorb wind surpluses, with operators in charge."),
                   Topic(year: 2025, agency: "dfgi", title: "A Danish-language assistant for energy planning",
                         objective: "Help municipal planners read grid studies and permits in Danish, with every answer sourced."),
               ],
               blurb: "A national innovation fund backs a small, fast project and co-funds most of it; a good result opens a three-year partnership with the universities."),
        Scheme(id: "dk_grand", countries: ["dk"], tiers: [1], programme: "DFGI grand-solutions partnership", short: "Grand solutions", instrument: "G",
               phases: [
                   Phase(name: "Grand-solutions partnership", terms: .grant,
                         budget: [(2016, 2_500_000), (2022, 4_000_000), (2026, 5_500_000), (2030, 7_000_000)], months: 36,
                         indirect: 0.25, funding: 0.75, advance: 0.25, retention: 0.1, plan: [.kickoff, .staffing, .research, .paper, .model, .report, .final], gap: 1.4, lift: 0.5),
               ],
               topics: [
                   Topic(year: 2016, agency: "dfgi", title: "AI for a fossil-free power system",
                         objective: "With two universities and a grid operator, build the forecasting and control models a fossil-free Danish grid needs."),
                   Topic(year: 2021, agency: "dfgi", title: "Learned digital twins of the grid",
                         objective: "A learned twin of the transmission grid that runs contingency studies in seconds instead of hours."),
                   Topic(year: 2024.5, agency: "dfgi", title: "Foundation models for energy systems",
                         objective: "Train and openly evaluate models that read, plan and simulate energy systems, with Danish partners."),
               ],
               blurb: "A three-year research partnership with Danish universities and industry, co-funded by the national innovation fund."),
        Scheme(id: "eu_accelerator", countries: eu, tiers: [0, 1], programme: "EFRC accelerator grant", short: "Accelerator", instrument: "G",
               phases: [
                   Phase(name: "Accelerator grant", terms: .grant,
                         budget: [(2016, 1_500_000), (2021, 2_500_000), (2026, 2_900_000), (2030, 3_300_000)], months: 24,
                         indirect: 0.25, funding: 0.7, advance: 0.4, retention: 0.05, plan: [.kickoff, .research, .model, .paper, .report, .final], gap: 2.2, lift: 0.4),
               ],
               topics: [
                   Topic(year: 2016, agency: "efrc", title: "Data-efficient language understanding for European languages",
                         objective: "Models that understand smaller European languages from a fraction of the data English needs."),
                   Topic(year: 2020, agency: "efrc", title: "Trustworthy machine learning for public services",
                         objective: "Show that a learned model can make public-service decisions that are explainable and contestable."),
                   Topic(year: 2023, agency: "efrc", title: "Open multilingual foundation models",
                         objective: "Train an openly documented model that works in all the Union's official languages."),
                   Topic(year: 2025, agency: "efrc", title: "Energy-efficient training and inference",
                         objective: "Cut the energy a capable model needs to train and serve, and publish the method."),
               ],
               tierScale: [0.6, 1, 1],
               blurb: "The EU's grant for start-ups with breakthrough technology: 70% of the costs, an advance at signature and the balance after the final report."),
        Scheme(id: "fr_dual", countries: ["fr"], tiers: [0, 1], programme: "DGPA dual-use innovation support", short: "Dual-use", instrument: "C",
               phases: [
                   Phase(name: "Dual-use innovation project", terms: .fixedPrice,
                         budget: [(2016, 450_000), (2022, 700_000), (2026, 900_000), (2030, 1_100_000)], months: 18,
                         plan: [.kickoff, .staffing, .research, .model, .release, .final], gap: 2.4, lift: 0.3),
                   Phase(name: "Defence demonstrator", terms: .costPlus,
                         budget: [(2016, 2_500_000), (2022, 3_500_000), (2026, 5_000_000), (2030, 6_500_000)], months: 24,
                         indirect: 0.4, fee: 0.06, plan: [.kickoff, .model, .safety, .release, .report, .final], gap: 1.4, lift: 0.6),
               ],
               topics: [
                   Topic(year: 2016, agency: "dgpa", title: "Speech recognition for noisy radio traffic",
                         objective: "Transcribe French military radio traffic through noise and jargon, on a laptop in the field."),
                   Topic(year: 2019, agency: "dgpa", title: "Change detection in satellite imagery",
                         objective: "Flag what changed between two satellite passes over a site, with few false alarms."),
                   Topic(year: 2022.5, agency: "dgpa", title: "A maintenance assistant for technical manuals",
                         objective: "Answer technicians' questions from thousands of pages of French technical manuals, citing the page."),
                   Topic(year: 2025, agency: "dgpa", title: "A sovereign agent for secure messaging",
                         objective: "An assistant that runs on accredited French infrastructure and drafts, sorts and summarises protected messages."),
               ],
               tierScale: [1, 3, 1],
               blurb: "The defence procurement agency co-funds innovations with civil and military uses, paid on milestones; the best become demonstrators."),
        Scheme(id: "it_competence", countries: ["it"], tiers: [0, 1], programme: "CNCI competence-centre innovation call", short: "Competence centre", instrument: "G",
               phases: [
                   Phase(name: "Innovation project", terms: .grant,
                         budget: [(2016, 300_000), (2022, 450_000), (2026, 600_000), (2030, 750_000)], months: 18,
                         indirect: 0.15, funding: 0.5, advance: 0.2, retention: 0.1, plan: [.kickoff, .research, .model, .release, .final], gap: 2.6, lift: 0.25),
                   Phase(name: "Industrial research and experimental development", terms: .grant,
                         budget: [(2016, 1_800_000), (2022, 2_700_000), (2026, 3_600_000), (2030, 4_500_000)], months: 30,
                         indirect: 0.15, funding: 0.5, advance: 0.2, retention: 0.1, plan: [.kickoff, .staffing, .research, .model, .paper, .report, .final], gap: 1.6, lift: 0.6),
               ],
               topics: [
                   Topic(year: 2016, agency: "cnci", title: "Visual inspection for machine-tool lines",
                         objective: "Spot defects on machined parts from line cameras, with fewer misses than the human inspectors."),
                   Topic(year: 2019, agency: "cnci", title: "Predictive maintenance for packaging lines",
                         objective: "Predict stoppages on packaging machines from their sensor data, a shift ahead."),
                   Topic(year: 2022.5, agency: "cnci", title: "An Italian-language assistant for factory documentation",
                         objective: "Answer operators' questions from Italian work instructions and maintenance records, on the shop floor."),
                   Topic(year: 2025, agency: "cnci", title: "Agentic production planning",
                         objective: "Agents that re-plan a plant's production when orders or supplies change, with planners approving."),
               ],
               tierScale: [1, 3, 1],
               blurb: "A national competence centre co-funds half of an AI project with manufacturers, paid in instalments as the work is approved."),
        Scheme(id: "ro_cyber", countries: ["ro"], tiers: [0, 1], programme: "ANSD national cyber-research project", short: "Cyber research", instrument: "G",
               phases: [
                   Phase(name: "Research project", terms: .grant,
                         budget: [(2016, 200_000), (2021, 450_000), (2026, 600_000), (2030, 750_000)], months: 18,
                         indirect: 0.25, funding: 0.8, advance: 0.3, retention: 0.1, plan: [.kickoff, .staffing, .research, .model, .final], gap: 2.6, lift: 0.25),
                   Phase(name: "National cyber-range pilot", terms: .fixedPrice,
                         budget: [(2016, 1_000_000), (2021, 2_200_000), (2026, 3_000_000), (2030, 3_800_000)], months: 24,
                         plan: [.kickoff, .model, .safety, .release, .final], gap: 1.6, lift: 0.6),
               ],
               topics: [
                   Topic(year: 2016, agency: "ansd", title: "Malware triage for the national CERT",
                         objective: "Sort and cluster the malware samples the national CERT receives each day, so analysts see the new ones first."),
                   Topic(year: 2019, agency: "ansd", title: "Romanian-language phishing detection",
                         objective: "Catch phishing written in Romanian across government mail, without flooding staff with false alarms."),
                   Topic(year: 2022.5, agency: "ansd", title: "An assistant for incident responders",
                         objective: "Help responders read logs and draft containment steps during an incident, with every step explained."),
                   Topic(year: 2025, agency: "ansd", title: "A post-quantum migration assistant",
                         objective: "Find where state systems use vulnerable cryptography and draft the migration, system by system."),
               ],
               tierScale: [1, 3, 1],
               blurb: "Romania's digital-security authority funds research for the state's cyber defence with recovery-plan money; a success becomes a pilot on the national cyber range."),
        Scheme(id: "eu_defence", countries: eu, tiers: [2], programme: "EDIF defence research action", short: "Research action", instrument: "G",
               phases: [
                   Phase(name: "Research action", terms: .grant,
                         budget: [(2016, 20_000_000), (2021, 40_000_000), (2024, 90_000_000), (2027, 140_000_000), (2030, 180_000_000)], months: 36,
                         indirect: 0.25, funding: 1.0, advance: 0.4, retention: 0.1, plan: [.kickoff, .staffing, .research, .model, .safety, .report, .final], gap: 0.8, lift: 0.4),
               ],
               topics: [
                   Topic(year: 2016, agency: "edif", title: "Multi-domain situational awareness",
                         objective: "Fuse radar, imagery and reports from several member states into one picture, in real time."),
                   Topic(year: 2021, agency: "edif", title: "A European language model for coalition command",
                         objective: "A model that works across the coalition's languages on accredited European infrastructure."),
                   Topic(year: 2025, agency: "edif", title: "Sovereign AI for European defence",
                         objective: "Train, accredit and evaluate a frontier-class model for European defence, run entirely on European soil."),
               ],
               blurb: "The Union's defence fund pays the full cost of collaborative research actions; results feed member states' procurement."),
        Scheme(id: "fr_defence", countries: ["fr"], tiers: [2], programme: "DGPA sovereign AI prototype", short: "Sovereign prototype", instrument: "C",
               phases: [
                   Phase(name: "Prototype", terms: .fixedPrice,
                         budget: [(2016, 15_000_000), (2021, 30_000_000), (2024, 70_000_000), (2027, 120_000_000), (2030, 160_000_000)], months: 24,
                         plan: [.kickoff, .staffing, .model, .safety, .release, .final], gap: 0.6, lift: 0.4),
               ],
               topics: [
                   Topic(year: 2016, agency: "dgpa", title: "Decision support for the operations centre",
                         objective: "Prototype a planning aid for the joint operations centre that runs on accredited French hardware."),
                   Topic(year: 2023, agency: "dgpa", title: "A sovereign defence model",
                         objective: "Prototype a frontier-class model for the armed forces, trained and run entirely in France."),
               ],
               blurb: "The defence procurement agency buys a sovereign prototype on milestones, with a production contract for a success."),
    ]

    static let byID: [String: Scheme] = Dictionary(uniqueKeysWithValues: schemes.map { ($0.id, $0) })
}
