import Foundation

// MARK: - 3.5: fun systems — the calendar, the challenges, the scenarios, their trophies and their chatter

/// A research conference on the yearly calendar (fictional venues).
struct VenueDef: Identifiable, Sendable {
    let id: String
    let name: String
    let short: String
    let month: Int
    let day: Int
    let city: String
    /// First year it runs.
    let opens: Int
    let blurb: String
    /// Research categories it likes best (a paper on one of them is stronger here).
    let likes: [ResearchCategory]

    /// A conference-hall photo for this (fictional) venue; the same one every year.
    var image: String { ImagePicker.pick(.events, seed: id) }
}

/// A public challenge, decided once a year on its date.
struct ContestDef: Identifiable, Sendable {
    let id: String
    let name: String
    let domain: CapDomain
    let month: Int
    let day: Int
    let opens: Int
    /// Prize for the winner, and the one-off grand prize for beating the bar.
    let purse: Double
    let grandPrize: Double
    /// Domain score the grand prize asks for, and how far it rises each time it's claimed.
    let bar: Double
    let barStep: Double
    let task: String
    let grandGoal: String
    let symbol: String

    /// A photo for this (fictional) challenge: robots for the robotics one, a stage for the rest.
    var image: String { ImagePicker.pick(domain == .robotics ? .robotics : .events, seed: id) }
}

/// A curated challenge-mode start.
struct ScenarioDef: Identifiable, Sendable {
    let id: String
    let title: String
    let tagline: String
    let story: String
    let goal: String
    let lose: String
    let era: String
    let doctrine: LabDoctrine
    let background: FounderBackground
    var difficulty: Difficulty = .normal
    var location = "nova"
    /// Starting cash multiplier on top of the era's.
    var cash = 1.0
    let deadline: Date
    let symbol: String
    let image: String
    /// Rough difficulty for the picker, 1–3.
    let stars: Int
}

enum FunCatalog {
    // MARK: Conferences

    static let venues: [VenueDef] = [
        VenueDef(id: "repsummit", name: "Representation Learning Summit", short: "RepSummit", month: 5, day: 4, city: "Lisbon", opens: 2013,
                 blurb: "Spring's big deep-learning venue. Open reviews, so everyone reads what the reviewers really thought.",
                 likes: [.architecture, .optimization]),
        VenueDef(id: "pixelcon", name: "Pixelcon: Vision & Pattern Week", short: "Pixelcon", month: 6, day: 17, city: "Seattle", opens: 1985,
                 blurb: "Ten thousand people, one poster hall and every robot demo that almost works.",
                 likes: [.multimodal, .systems]),
        VenueDef(id: "gradient", name: "Gradient: International Forum on Machine Learning", short: "Gradient", month: 7, day: 16, city: "Vienna", opens: 1990,
                 blurb: "The theorists' favourite. Proofs in the appendix, opinions in the hallway.",
                 likes: [.optimization, .reasoning, .data]),
        VenueDef(id: "guardrails", name: "Guardrails Colloquium on AI Safety", short: "Guardrails", month: 10, day: 7, city: "Oxford", opens: 2019,
                 blurb: "Small, serious and growing fast. Labs send their safety teams; regulators sit in the back row.",
                 likes: [.safety, .postTraining]),
        VenueDef(id: "meridian", name: "Meridian Conference on Neural Computation", short: "Meridian", month: 12, day: 9, city: "Vancouver", opens: 1987,
                 blurb: "The big one. Twenty thousand attendees, a hundred parties and the keynote everyone quotes for a year.",
                 likes: [.architecture, .reasoning, .agents, .inference]),
    ]

    static let venueByID: [String: VenueDef] = Dictionary(uniqueKeysWithValues: venues.map { ($0.id, $0) })

    /// Paper titles: "{n}" is the topic.
    static let titlePatterns = [
        "{n} at Scale", "On the Surprising Effectiveness of {n}", "Rethinking {n}", "{n}: Simple, Fast and Hard to Beat",
        "Inside {n}", "{n}: (Almost) All You Need", "Taming {n}", "A Closer Look at {n}", "{n} Without the Tears",
        "Scaling Laws for {n}", "The Case for {n}", "{n}, Revisited", "Less Is More: {n}", "Towards Reliable {n}",
    ]

    /// What rival labs write about.
    static let rivalTopics = [
        "Sparse Attention", "Reward Models", "Synthetic Data", "Long-Context Retrieval", "Test-Time Compute", "Tool Use",
        "World Models", "Mechanistic Interpretability", "Speculative Decoding", "Self-Play", "Process Supervision",
        "Low-Precision Training", "Mixture-of-Experts Routing", "Memory Layers", "Curriculum Learning", "Model Merging",
        "Preference Optimisation", "Video Tokenisers", "Robot Foundation Models", "Agentic Evaluation",
    ]

    // MARK: Challenges

    static let contests: [ContestDef] = [
        ContestDef(id: "turing", name: "Turing Showdown", domain: .social, month: 3, day: 14, opens: 2021, purse: 100_000, grandPrize: 1_000_000,
                   bar: 170, barStep: 40, task: "A live debate against a human champion, judged by an audience that doesn't know which side is the machine.",
                   grandGoal: "Win the audience vote by a landslide", symbol: "person.2.wave.2.fill"),
        ContestDef(id: "euler", name: "Euler Medal", domain: .math, month: 7, day: 18, opens: 2019, purse: 200_000, grandPrize: 1_500_000,
                   bar: 160, barStep: 40, task: "This year's olympiad paper under exam rules, with the proofs marked by the same graders as the students.",
                   grandGoal: "Score a perfect paper", symbol: "function"),
        ContestDef(id: "codeolympiad", name: "Open Code Olympiad", domain: .coding, month: 8, day: 21, opens: 2018, purse: 150_000, grandPrize: 1_000_000,
                   bar: 158, barStep: 40, task: "Six hours, ten problems and a judge that doesn't care how confident the code sounds.",
                   grandGoal: "Outscore every human finalist", symbol: "chevron.left.forwardslash.chevron.right"),
        ContestDef(id: "longhaul", name: "Long Haul", domain: .agents, month: 9, day: 24, opens: 2024, purse: 250_000, grandPrize: 2_000_000,
                   bar: 190, barStep: 40, task: "Run a small online shop for 30 days on a $1,000 float with no human help.",
                   grandGoal: "Turn the float into $100,000", symbol: "figure.walk.motion"),
        ContestDef(id: "kitchen", name: "Kitchen Robot Challenge", domain: .robotics, month: 11, day: 5, opens: 2024, purse: 250_000, grandPrize: 3_000_000,
                   bar: 175, barStep: 40, task: "Make breakfast in a stranger's kitchen: find the eggs, work the stove, wash up.",
                   grandGoal: "Cook a breakfast the judges would pay for", symbol: "frying.pan.fill"),
        ContestDef(id: "abstraction", name: "Abstraction Prize", domain: .reasoning, month: 12, day: 2, opens: 2019, purse: 300_000, grandPrize: 2_500_000,
                   bar: 185, barStep: 40, task: "Grid puzzles no model has seen, each solvable by a curious ten-year-old.",
                   grandGoal: "Beat the average human on the private set", symbol: "square.grid.3x3.fill"),
        ContestDef(id: "discovery", name: "Discovery Cup", domain: .science, month: 2, day: 20, opens: 2025, purse: 500_000, grandPrize: 5_000_000,
                   bar: 200, barStep: 40, task: "Propose an experiment, run it in a robot lab and report a real finding.",
                   grandGoal: "Make a finding a top journal would publish", symbol: "atom"),
    ]

    static let contestByID: [String: ContestDef] = Dictionary(uniqueKeysWithValues: contests.map { ($0.id, $0) })

    // MARK: Scenarios

    static let scenarios: [ScenarioDef] = [
        ScenarioDef(id: "garage_gpt", title: "Garage to GPT Moment", tagline: "Beat history to the chatbot boom.",
                    story: "June 2020. Four GPUs, a whiteboard and a hunch that people want to talk to a model. History says the consumer AI boom starts in November 2022. Start it first.",
                    goal: "Launch the chatbot that ignites the consumer AI boom before November 2022.",
                    lose: "Someone else's chatbot starts the boom first, or November 2022 arrives.",
                    era: "2020", doctrine: .product, background: .hacker, deadline: GameCalendar.date(2022, 10, 31),
                    symbol: "bubble.left.and.bubble.right.fill", image: "garage", stars: 2),
        ScenarioDef(id: "speedrun", title: "Speedrun: Transformer to #1", tagline: "From the attention paper to the top of the board.",
                    story: "July 2017. The Transformer paper is a month old and nobody has heard of you. The clock is running: how fast can you build the best model in the world, and keep it there for a year?",
                    goal: "Hold #1 on the Intelligence Index for twelve months in a row. The sooner, the higher the score.",
                    lose: "Still not #1 at the end of 2029.",
                    era: "2017", doctrine: .scaling, background: .researcher, deadline: GameCalendar.date(2029, 12, 31),
                    symbol: "stopwatch.fill", image: "p100_die", stars: 3),
        ScenarioDef(id: "safety_frontier", title: "Safety First to the Frontier", tagline: "Lead the field without cutting corners.",
                    story: "September 2022. You left a big lab because it moved too fast. Now prove a careful lab can still build the best model in the world.",
                    goal: "Hold #1 on the Intelligence Index for six months in a row with a safety score of 75 or more.",
                    lose: "A model's weights get stolen, or the end of 2027 arrives first.",
                    era: "2022", doctrine: .safety, background: .researcher, deadline: GameCalendar.date(2027, 12, 31),
                    symbol: "checkmark.shield.fill", image: "server_room", stars: 2),
        ScenarioDef(id: "open_insurgent", title: "Open-Weights Insurgent", tagline: "Give it all away and still win.",
                    story: "September 2022. The big labs keep their weights locked up. You think the world should have them. Publish everything and take a top-three spot anyway.",
                    goal: "Release an open-weights model that ranks in the world's top three labs.",
                    lose: "You switch to a Secretive publication policy, or the end of 2025 arrives first.",
                    era: "2022", doctrine: .open, background: .hacker, deadline: GameCalendar.date(2025, 12, 31),
                    symbol: "lock.open.fill", image: "gpu_cluster", stars: 2),
        ScenarioDef(id: "bootstrapped", title: "Bootstrapped", tagline: "No investors. No excuses.",
                    story: "September 2022. Your seed money is all the outside money you will ever take. Customers pay for everything else.",
                    goal: "Reach $10B of annualised revenue without raising another round.",
                    lose: "You raise a funding round or go public, or the end of 2027 arrives first.",
                    era: "2022", doctrine: .product, background: .serialFounder, deadline: GameCalendar.date(2027, 12, 31),
                    symbol: "dollarsign.circle.fill", image: "rtx_3090", stars: 3),
        ScenarioDef(id: "crash", title: "Survive the 2027 Crash", tagline: "The bubble bursts in spring. Be standing when it's over.",
                    story: "October 2026. Valuations are at forty times revenue and everyone is building gigawatts on credit. In April 2027 it all comes down. Your job: still be here, and be worth a lot more.",
                    goal: "Stay solvent and be worth $500B on 1 January 2029.",
                    lose: "Bankruptcy, or a valuation under $500B on 1 January 2029.",
                    era: "2026", doctrine: .efficiency, background: .serialFounder, deadline: GameCalendar.date(2029, 1, 1),
                    symbol: "chart.line.downtrend.xyaxis", image: "stock_exchange", stars: 2),
        ScenarioDef(id: "sovereign", title: "A Lab for a Small Nation", tagline: "A national fund, a cold island and big ambitions.",
                    story: "October 2026. A small country's sovereign fund hands you three times the usual budget and one condition: build the best model in the world, and keep its weights at home.",
                    goal: "Hold #1 on the Intelligence Index for three months in a row.",
                    lose: "A model's weights are stolen, or the end of 2029 arrives first.",
                    era: "2026", doctrine: .balanced, background: .policy, location: "iceland", cash: 3, deadline: GameCalendar.date(2029, 12, 31),
                    symbol: "flag.fill", image: "dc_hall", stars: 2),
        ScenarioDef(id: "alien_race", title: "The Alien Signal Race", tagline: "Find a design no human wrote, before anyone else does.",
                    story: "October 2026. Whispers say agent swarms are turning up architectures nobody designed. Be the first lab to find one.",
                    goal: "Discover an alien architecture before any rival lab does.",
                    lose: "A rival unveils one first, or the end of 2033 arrives.",
                    era: "2026", doctrine: .moonshot, background: .researcher, deadline: GameCalendar.date(2033, 12, 31),
                    symbol: "atom", image: "wafer_closeup", stars: 3),
    ]

    static let scenarioByID: [String: ScenarioDef] = Dictionary(uniqueKeysWithValues: scenarios.map { ($0.id, $0) })

    // MARK: Achievements

    static let achievements: [Achievement] = [
        Achievement(id: "paper_accepted", title: "Peer Reviewed", detail: "Get a paper accepted at a conference.", symbol: "doc.text.magnifyingglass"),
        Achievement(id: "best_paper", title: "Best Paper", detail: "Win a best-paper award.", symbol: "rosette"),
        Achievement(id: "keynote", title: "Keynote Speaker", detail: "Give the keynote at Meridian.", symbol: "mic.fill"),
        Achievement(id: "contest_win", title: "Champion", detail: "Win a public AI challenge.", symbol: "trophy.circle.fill"),
        Achievement(id: "grand_prize", title: "Grand Prize", detail: "Claim a challenge's grand prize by beating its bar.", symbol: "medal.star.fill"),
        Achievement(id: "hat_trick", title: "Hat Trick", detail: "Win three different challenges in one year.", symbol: "3.circle.fill"),
        Achievement(id: "hack_hit", title: "Friday Night Magic", detail: "Have a hackathon turn into a hit.", symbol: "party.popper.fill"),
        Achievement(id: "scenario_win", title: "Challenge Accepted", detail: "Win a challenge-mode scenario.", symbol: "flag.checkered"),
    ]

    // MARK: The Pulse

    static let pulse: [String: [String]] = [
        "p.fun.best.you": [
            "academic|Best paper at {venue} goes to {you} for \"{title}\". Deserved. The ablations alone are worth the read.",
            "bench|Read the {you} paper twice. The result holds up. Annoyingly well.",
            "you+|We won best paper at {venue}. The team slept under their desks for this one. Proud doesn't cover it.",
            "joker|{you} won best paper at {venue} and the poster session afterwards turned into a mosh pit.",
            "rival-|Congratulations to {you} on the {venue} award. We'll see you at the next one.",
            "booster|\"{title}\" just won best paper at {venue}. Read it before your competitors do.",
            "insider|Hearing three labs tried to hire the {you} first author within an hour of the {venue} award.",
        ],
        "p.fun.best.lab": [
            "academic|{lab} takes best paper at {venue} for \"{title}\". A clean idea, carefully tested.",
            "staff+|Still can't believe it: best paper at {venue}. Thank you to everyone at {lab}.",
            "joker|{lab} won best paper at {venue}. Everyone else won the free tote bag.",
            "skeptic-|Best paper at {venue} to {lab}. Wake me when it reproduces outside their cluster.",
            "bench|\"{title}\" from {lab} is the {venue} best paper. Code is up, which is more than most.",
        ],
        "p.fun.oral.you": [
            "you+|Gave our oral at {venue} today: \"{title}\". Standing room only. Slides are up.",
            "academic|The {you} oral at {venue} was the most useful twenty minutes of the week.",
            "dev|Watched the {you} talk at {venue} on the stream. Trying the trick from slide 14 tonight.",
        ],
        "p.fun.rejected": [
            "joker|Reviewer 2 has rejected the {you} paper at {venue} for \"lack of novelty\" and \"too much novelty\".",
            "you-|Our {venue} paper got rejected. Reviewer 2, if you're reading this: we did run the baseline.",
            "skeptic|{you} didn't get into {venue} this year. Maybe write papers instead of press releases.",
        ],
        "p.fun.keynote": [
            "reporter|{founder} of {you} gave the Meridian keynote to a hall of twenty thousand. The live demo worked. Mostly.",
            "joker|{founder} at the Meridian keynote: \"one more thing\". The entire hall reached for their laptops.",
            "skeptic-|Meridian keynote by {founder}: forty minutes, one benchmark chart, zero error bars.",
            "booster+|Watch the {founder} keynote from Meridian. That's what the next five years look like.",
            "you+|{founder} just closed out Meridian. Hiring table has a queue round the block.",
        ],
        "p.fun.conf": [
            "joker|{venue} week: the poster hall smells of coffee and ambition, and someone has brought a robot dog again.",
            "academic|Three takeaways from {venue}: everyone has scaling plots, nobody has error bars, the coffee ran out by ten.",
            "insider|More recruiting at the {venue} parties than in the sessions. One lab hired a bar.",
            "bench|Half of {venue} this year is evaluation papers. Good. We needed this.",
            "dev|Back from {venue}. Best talk was in a corridor, not on the programme.",
        ],
        "p.fun.win.you": [
            "you+|We won {contest}! {model} took first place. The prize money goes to the team party.",
            "bench|{you} wins {contest} with {model}. I checked the logs: no tricks, just better.",
            "joker|{model} won {contest} and has already asked what the next challenge is. Calm down.",
            "rival-|Congrats to {you} on {contest}. Rematch next year.",
            "reporter|{contest}: first place goes to {you} and {model}.",
        ],
        "p.fun.win.lab": [
            "lead+|{model} won {contest}. Proud of the team that built it.",
            "bench|{contest} to {lab} and {model}. Margins were tight at the top.",
            "joker|{lab} won {contest}. Their press team had the graphics ready a week early.",
            "skeptic|{contest} winner: {lab}. Test-set leakage audit when?",
        ],
        "p.fun.grand": [
            "reporter|It happened: {model} from {labname} has claimed the {contest} grand prize. {grand}.",
            "academic|{contest} grand prize claimed by {model}. I bet my students this was five years off. I owe them dinner.",
            "worried|The bar for {contest} fell today. Every bar we set falls. Maybe set them somewhere else.",
            "joker|{contest} organisers, an hour after {model} claimed the grand prize: \"introducing {contest} 2\".",
            "booster|{model} just did the thing people said machines couldn't do. {contest} grand prize. Remember this day.",
        ],
        "p.fun.hack": [
            "dev+|The demo {you} posted from their hackathon is the most fun I've had with a model all year.",
            "joker|{you} held a hackathon and now my feed is only their demo. Fine. It's good.",
            "you+|Hackathon week result: {demo}. Built in five days, on pizza.",
            "booster|{you} built {demo} in a hackathon week. Imagine what a quarter looks like.",
        ],
        "p.fun.scenario": [
            "reporter|{you} did what nobody thought it could: {goal}",
            "joker|{you} in the founding deck: \"{goal}\" Everyone laughed. Nobody's laughing.",
            "booster+|Remember when people said {you} couldn't do it? {goal} Done.",
        ],
    ]
}
