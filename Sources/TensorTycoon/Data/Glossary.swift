import Foundation

/// The game's vocabulary in plain language. The Help screen's glossary, the "?" buttons next to labels and ⌘K all read it.
/// Numbers quoted here are the ones the simulation uses; change them together with the engine.
enum GlossaryTerm: String, CaseIterable, Identifiable, Sendable {
    // The race
    case intelligenceIndex, capability, effectiveCompute, saturation, rank, taskHorizon, arenaElo, domains, milestones
    // Training
    case forecast, scalingLadder, mfu, goodput, opsCoverage, checkpoint, lossSpike, postTraining, moe, distillation, precision
    // Compute and serving
    case h100e, chipsPerReplica, servingCapacity, reservedCloud, leasing, cloudCredits
    // Money
    case runRate, burn, runway, valuation, termSheet, dilution, netWorth
    // Products and customers
    case sla, brand, openWeights, priceWar, productLines
    // Running the company
    case chiefOfStaff, inbox, standingAnswers, delegates, cloudBudget, alerts, briefing, rewind, board, researchPoints, signatureSecret
    // Rivals
    case forecastBand, leapfrog, codeRed, marketCorrection, pulse
    // Safety and the frontier
    case safetyThresholds, securityLevels, politicalCapital, rsi, swarms, alignmentDrift, alienTech
    // The world
    case stakeholders, publicMood, regulation, consequences

    var id: String { rawValue }
}

enum GlossaryCategory: String, CaseIterable, Identifiable, Sendable {
    case race = "The race"
    case training = "Training"
    case compute = "Compute & serving"
    case money = "Money"
    case business = "Products & customers"
    case company = "Running the company"
    case rivals = "Rivals"
    case frontier = "Safety & the frontier"
    case world = "The world"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .race: "trophy.fill"
        case .training: "chart.line.downtrend.xyaxis"
        case .compute: "cpu.fill"
        case .money: "dollarsign.circle.fill"
        case .business: "chart.pie.fill"
        case .company: "gearshape.2.fill"
        case .rivals: "flag.2.crossed.fill"
        case .frontier: "exclamationmark.shield.fill"
        case .world: "globe.americas.fill"
        }
    }
}

struct GlossaryEntry: Sendable {
    let title: String
    let category: GlossaryCategory
    /// What it is, in a sentence or two.
    let definition: String
    /// How it works in the game and what moves it.
    let detail: String
    /// Where you see it.
    let screen: Screen?
    /// Other words players search for.
    let aliases: [String]
}

extension GlossaryTerm {
    var title: String { entry.title }
    var definition: String { entry.definition }
    var detail: String { entry.detail }
    var screen: Screen? { entry.screen }
    var category: GlossaryCategory { entry.category }

    var entry: GlossaryEntry {
        switch self {
        // MARK: The race
        case .intelligenceIndex:
            GlossaryEntry(title: "Intelligence Index", category: .race,
                          definition: "A model's average score on the ten benchmarks in the index today. About 50 is level with the field; higher is ahead.",
                          detail: "The set changes as tests saturate: once two labs pass a benchmark's saturation line, it rotates out when a harder successor is ready, and the newcomer phases in over eight weeks. So the same model's index drifts down slowly as the bar rises. To compare models across years, use capability.",
                          screen: .leaderboard, aliases: ["index", "score", "benchmark average"])
        case .capability:
            GlossaryEntry(title: "Capability", category: .race,
                          definition: "A fixed yardstick for how capable a model is: GPT-4 (2023) is 100, and every +10 means ten times the effective compute.",
                          detail: "It averages the eight skills the index tests and never re-bases or saturates, so a model reads the same in 2019 and in 2035. A gap of 5 points is about 3× the effective compute, 10 points is 10×. Closing a gap takes a bigger run, a better recipe or stronger post-training.",
                          screen: .leaderboard, aliases: ["capability points", "gap to #1", "fixed scale"])
        case .effectiveCompute:
            GlossaryEntry(title: "Effective compute", category: .race,
                          definition: "Training compute adjusted for everything that makes it go further: better architectures, optimizers, data and post-training.",
                          detail: "Two runs with the same FLOPs can differ several-fold in effective compute. Capability is measured in it, and the Model Lab's forecast lists each of its drivers as an effective-compute multiplier. Research raises them.",
                          screen: .lab, aliases: ["algorithmic gains", "compute multiplier", "FLOPs"])
        case .saturation:
            GlossaryEntry(title: "Benchmark saturation", category: .race,
                          definition: "A benchmark is saturated once models from two different labs pass its saturation line (the red tick): it no longer tells the best models apart.",
                          detail: "It leaves the Intelligence Index as soon as a successor is ready. Successors are pitched at the field, so the best models start around 10% on them.",
                          screen: .benchmarks, aliases: ["saturated", "successor benchmark", "retired benchmark"])
        case .rank:
            GlossaryEntry(title: "Rank (#N)", category: .race,
                          definition: "Your place among labs still in the race, by each lab's best released model on the Intelligence Index.",
                          detail: "Labs that were bought or went bankrupt don't count, and only released models do: a better model you haven't shipped shows as \"ready to ship\". The dashboard, the news and the monthly briefing all use this rank.",
                          screen: .leaderboard, aliases: ["place", "position", "#1", "leader"])
        case .taskHorizon:
            GlossaryEntry(title: "Task horizon", category: .race,
                          definition: "How long a task, measured in human working time, a model completes half the time on its own, in the style of METR's measurements.",
                          detail: "It grows with agentic skill. It decides how useful a model is as an agent product and how much one agent in a swarm is worth.",
                          screen: .leaderboard, aliases: ["horizon", "METR", "agent horizon"])
        case .arenaElo:
            GlossaryEntry(title: "LMArena Elo", category: .race,
                          definition: "A chat-preference rating in the style of LMArena: people compare two answers and pick the one they like.",
                          detail: "It follows capability but also rewards chat skill and style, so a friendlier model can out-rate a smarter one.",
                          screen: .leaderboard, aliases: ["elo", "arena", "chat rating"])

        // MARK: Training
        case .forecast:
            GlossaryEntry(title: "Forecast", category: .training,
                          definition: "The Model Lab's prediction of a design's Intelligence Index before you train it, with an 80% interval: four times out of five the result lands inside it.",
                          detail: "It comes from scaling laws plus the techniques you've researched, so it needs Neural Scaling Laws research. Untested techniques and runs far bigger than your largest widen it; a scaling ladder halves it. The loss curve reveals the truth as the run goes.",
                          screen: .lab, aliases: ["prediction", "80% interval", "scaling laws", "tier"])
        case .scalingLadder:
            GlossaryEntry(title: "Scaling ladder", category: .training,
                          definition: "Five small proxy runs, at up to 2% of a planned run's compute, that test the recipe before the real thing.",
                          detail: "It halves the forecast's uncertainty, tunes hyperparameters and catches most silent bugs. The Model Lab offers it once you've researched Predictable Scaling.",
                          screen: .lab, aliases: ["proxy runs", "ladder"])
        case .mfu:
            GlossaryEntry(title: "MFU (model FLOPs utilization)", category: .training,
                          definition: "The share of your chips' peak speed a training run actually spends on the model's math. Large runs usually reach 30–45%.",
                          detail: "It depends on the chip, on having enough ML engineers (up to 4 points), on research and on training-ops agents. It falls as a cluster grows past a chip's fast interconnect domain.",
                          screen: .lab, aliases: ["utilization", "model flops utilization"])
        case .goodput:
            GlossaryEntry(title: "Goodput", category: .training,
                          definition: "The share of wall-clock time a training run makes progress. Hardware failures, the restarts after them and slow nodes eat the rest.",
                          detail: "Faults grow with cluster size (Meta saw 419 interruptions in 54 days on 16,384 GPUs), so very large runs lose the most time. Below 60% the Model Lab warns you; below 30% it won't start the run. Infra engineers (about one per 600 chips of your biggest run), research and training-ops agents watching the run raise it.",
                          screen: .training, aliases: ["uptime", "failures", "interruptions"])
        case .opsCoverage:
            GlossaryEntry(title: "Ops coverage", category: .training,
                          definition: "The share of a training run's chips watched by training-ops agents. Watched nodes are drained before they crash and restart in seconds.",
                          detail: "Past about 100,000 chips a run without agents barely moves. Point a training-ops swarm at a run (Assign agents on its run card), or run one that watches every run.",
                          screen: .training, aliases: ["ops agents", "training ops"])
        case .checkpoint:
            GlossaryEntry(title: "Checkpoint", category: .training,
                          definition: "A saved copy of a run's weights, taken every few percent of training.",
                          detail: "Roll back to one after a loss spike, or fork one to ship an early preview model while training continues. Saving more often costs a little speed.",
                          screen: .training, aliases: ["preview", "fork", "rollback"])
        case .lossSpike:
            GlossaryEntry(title: "Loss spike", category: .training,
                          definition: "A sudden jump in training loss when a run turns unstable.",
                          detail: "Roll back to a checkpoint (safe, costs time) or push through (risky). Aggressive learning rates spike more often; auto-rollback answers spikes for you.",
                          screen: .training, aliases: ["instability", "divergence", "learning rate"])
        case .postTraining:
            GlossaryEntry(title: "Post-training", category: .training,
                          definition: "Everything after pre-training: instruction tuning, RLHF or DPO, tool and agent RL, reasoning RL and safety training.",
                          detail: "Each stage has its own compute budget and its own surprises (reward hacking, sycophancy). Reasoning RL is set as a share of pre-training compute, from Light (1%) to Extreme (60%). Post-training adds capability without a bigger pre-training run.",
                          screen: .lab, aliases: ["RL", "RLHF", "reasoning", "fine-tuning", "SFT"])
        case .moe:
            GlossaryEntry(title: "Mixture of experts (MoE)", category: .training,
                          definition: "A model where each token uses only a fraction of the parameters, the active ones. It trains like a smaller model but knows like a bigger one.",
                          detail: "Training compute follows the active parameters; serving memory follows all of them, so MoE models need more chips per replica.",
                          screen: .lab, aliases: ["experts", "sparse", "active parameters"])
        case .distillation:
            GlossaryEntry(title: "Distillation", category: .training,
                          definition: "Training a smaller model (the student) on a bigger model's outputs (the teacher). It gets close to the teacher for a fraction of the compute.",
                          detail: "In the Model Lab you can distill from your own models. Rivals distill your API too: they copy part of a lead they've watched for a quarter, and some run campaigns through thousands of fake accounts. Distillation-defence research cuts what they get.",
                          screen: .lab, aliases: ["student", "teacher", "distill"])
        case .precision:
            GlossaryEntry(title: "Precision (BF16, FP8, FP4)", category: .training,
                          definition: "The number format used for the math. Each step down roughly doubles throughput and halves memory, at a small cost in quality.",
                          detail: "FP8 training and lower-precision serving need research. Serving at FP8 costs a little capability; 4-bit costs more but fits a model on far fewer chips.",
                          screen: .models, aliases: ["BF16", "FP8", "FP4", "quantization", "INT8"])

        // MARK: Compute and serving
        case .h100e:
            GlossaryEntry(title: "H100-equivalents (H100e)", category: .compute,
                          definition: "Compute counted in H100s: each chip counts as its dense BF16 speed divided by an H100's.",
                          detail: "It lets you compare fleets of mixed hardware, yours and the rivals' clusters in Rival Watch.",
                          screen: .compute, aliases: ["H100e", "equivalents", "fleet size"])
        case .chipsPerReplica:
            GlossaryEntry(title: "Chips per replica", category: .compute,
                          definition: "How many accelerators one copy of a model needs to serve: its weights at the serving precision plus room for the KV cache, divided by each chip's memory.",
                          detail: "Serving capacity comes in whole replicas, so chips beyond a multiple of this sit unused. Lower serving precision, chips with more memory and KV-cache research all cut it.",
                          screen: .models, aliases: ["replica", "KV cache", "deployment"])
        case .servingCapacity:
            GlossaryEntry(title: "Serving capacity", category: .compute,
                          definition: "How many tokens a day a model's deployed chips can produce.",
                          detail: "When demand passes capacity you turn users away: they churn, reliability falls and enterprise contracts breach their SLAs. The capacity delegate adds and frees chips to keep up.",
                          screen: .models, aliases: ["capacity", "demand", "over capacity", "inference"])
        case .reservedCloud:
            GlossaryEntry(title: "Reserved vs on-demand", category: .compute,
                          definition: "Cloud chips rent by the hour on demand, or reserved for one year (32% off) or three years (52% off).",
                          detail: "A reservation is paid to the end: breaking it costs half of what's left. When it ends, the chips leave your fleet and whatever runs on them is cut back, unless you or the renewals delegate renew it.",
                          screen: .hardware, aliases: ["rent", "rental", "reservation", "cloud"])
        case .leasing:
            GlossaryEntry(title: "Leasing idle chips", category: .compute,
                          definition: "Renting your own idle accelerators to other companies, like a cloud provider.",
                          detail: "You earn market rental rates minus a platform fee, and occupancy falls if you flood the market. The leasing delegate leases what sits idle beyond the share you keep free and recalls chips when you need them.",
                          screen: .chipSales, aliases: ["lease", "neocloud"])
        case .cloudCredits:
            GlossaryEntry(title: "Cloud credits", category: .compute,
                          definition: "Prepaid cloud spend that strategic investors and partners pay in place of cash. Rentals are paid from credits first, then from cash.",
                          detail: "Credits only pay for cloud rentals; they don't count as cash for anything else.",
                          screen: .finance, aliases: ["credits"])

        // MARK: Money
        case .runRate:
            GlossaryEntry(title: "Run-rate", category: .money,
                          definition: "Revenue at its current pace for a whole year.",
                          detail: "In the first nine days of a month it's last month × 12; after that it blends in this month's pace. Investors value you on it.",
                          screen: .finance, aliases: ["annual revenue", "ARR", "revenue"])
        case .burn:
            GlossaryEntry(title: "Burn", category: .money,
                          definition: "How much cash you lose in a month: costs minus revenue.",
                          detail: "Last month's burn sets your runway. Compute rent, payroll and power are usually the big lines.",
                          screen: .finance, aliases: ["burn rate", "loss", "spending"])
        case .runway:
            GlossaryEntry(title: "Runway", category: .money,
                          definition: "How many months your cash lasts at last month's burn: cash divided by last month's loss.",
                          detail: "Under four months the Chief of Staff tells you to raise, because rounds take weeks. If cash stays below zero for 60 days you go bankrupt.",
                          screen: .finance, aliases: ["months of cash", "bankruptcy"])
        case .valuation:
            GlossaryEntry(title: "Valuation (private mark)", category: .money,
                          definition: "What the company is worth on paper. Investors price it on revenue and growth, how close your best model is to the frontier, brand and market hype, your team and your hardware.",
                          detail: "A private mark moves halfway toward its new level each month, and it doesn't fall below the last round's post-money written down 30% a year (never below 40% of it). Once you're public it's the share price times the shares. It sets the price of new rounds and your net worth.",
                          screen: .funding, aliases: ["mark", "pre-money", "post-money", "market cap"])
        case .termSheet:
            GlossaryEntry(title: "Term sheet", category: .money,
                          definition: "An investor's offer while you raise: an amount at a pre-money valuation, sometimes partly paid as cloud credits.",
                          detail: "Offers arrive over the weeks after you start raising and expire after 14 days. Accept one to close the round.",
                          screen: .funding, aliases: ["offer", "round", "fundraise", "raise"])
        case .dilution:
            GlossaryEntry(title: "Dilution", category: .money,
                          definition: "The share of the company new investors get: the amount raised divided by (pre-money valuation + amount).",
                          detail: "Every round shrinks your stake. Below 50% you no longer control the board, and a board that loses faith in you can replace you.",
                          screen: .funding, aliases: ["stake", "equity", "cap table", "control"])
        case .netWorth:
            GlossaryEntry(title: "Net worth", category: .money,
                          definition: "Your own wealth: your stake at today's valuation plus whatever you've cashed out after tax.",
                          detail: "Founder share sales add to it but cost the company nothing; selling more than 10% at once spooks the press.",
                          screen: .funding, aliases: ["founder", "wealth", "cash out"])

        // MARK: Products and customers
        case .sla:
            GlossaryEntry(title: "SLA (service-level agreement)", category: .business,
                          definition: "An enterprise contract's promise of capacity: each day its model serves less than 95% of the client's traffic counts as a breach.",
                          detail: "More than six breaches in a month and the client cancels at month end (brand −4). The count resets every month. Give the model more serving chips, or let the capacity delegate do it.",
                          screen: .market, aliases: ["enterprise", "contract", "breach"])
        case .brand:
            GlossaryEntry(title: "Brand", category: .business,
                          definition: "How well known and trusted your lab is, from 0 to 100. It drives chat users, API demand and enterprise leads.",
                          detail: "It drifts toward what your models and reach deserve. Marketing, sales staff, big launches and leading the race add to it; unsafe releases, scandals and outages take it away.",
                          screen: .market, aliases: ["reputation", "marketing"])
        case .openWeights:
            GlossaryEntry(title: "Open weights", category: .business,
                          definition: "Publishing a model's weights for anyone to download and run.",
                          detail: "Near-frontier weights are big news and lift your brand, but rivals can build on them. When rivals publish free weights, API prices fall. You can fine-tune other labs' open models in the Model Lab.",
                          screen: .models, aliases: ["open source", "open-weights"])
        case .priceWar:
            GlossaryEntry(title: "Price war", category: .business,
                          definition: "A rival cutting API prices to win share. It drags the going rate down for everyone.",
                          detail: "Auto-pricing follows the market for you; the other answer is a clearly better model.",
                          screen: .rivals, aliases: ["price cut", "auto-pricing"])

        // MARK: Running the company
        case .chiefOfStaff:
            GlossaryEntry(title: "Chief of Staff", category: .company,
                          definition: "A prioritised list of things that need you, most with a one-click fix. It's the top of the dashboard's Needs you list.",
                          detail: "Hide an item for a week, a month or a year with the bell if you've decided to live with it.",
                          screen: .dashboard, aliases: ["needs you", "to-do", "advice", "fix"])
        case .inbox:
            GlossaryEntry(title: "Inbox", category: .company,
                          definition: "Where offers that can wait sit instead of stopping the clock: rival funding rounds, partner offers, new bills, sovereign deals, researchers asking to join.",
                          detail: "Each waits three weeks (bills 30 days), then resolves with the answer marked \"If you don't answer\". Decisions that can't wait, like incidents, lawsuits or a stalled board, always pause the game.",
                          screen: .dashboard, aliases: ["decisions", "offers", "deadline"])
        case .standingAnswers:
            GlossaryEntry(title: "Standing answers", category: .company,
                          definition: "Decisions the game answers for you. Tick \"Always answer this way\" on a decision that repeats and the same answer is used from then on.",
                          detail: "Talent raids, loss spikes, partner offers and new bills are among the ones you can automate. See or forget them on Operations.",
                          screen: .operations, aliases: ["always answer", "automatic answers"])
        case .delegates:
            GlossaryEntry(title: "Delegates", category: .company,
                          definition: "Chores you hand to your COO: serving capacity, the next training run, launches, cloud renewals, leasing idle chips, hiring, pay and enterprise leads.",
                          detail: "They run on your best model. Scripts act once a week; better models act more often (a frontier agent every day) and get closer to the right call. Everything they do shows in the delegates' log.",
                          screen: .operations, aliases: ["COO", "automation", "autoscale", "ops"])
        case .cloudBudget:
            GlossaryEntry(title: "Cloud budget", category: .company,
                          definition: "How much on-demand cloud rent a month the capacity delegate may take on when your own chips can't carry demand.",
                          detail: "It only rents when a chip earns at least 30% more than its rent, and gives those chips back first when demand falls.",
                          screen: .operations, aliases: ["rent budget", "autoscale"])
        case .alerts:
            GlossaryEntry(title: "Alerts and pauses", category: .company,
                          definition: "Banners for things that need you. You choose which kinds also stop the clock.",
                          detail: "A problem that keeps coming back stops the clock once, then stays a banner. Change what pauses the game on Operations or from the bell in the toolbar.",
                          screen: .operations, aliases: ["banner", "pause", "notifications"])
        case .briefing:
            GlossaryEntry(title: "Monthly briefing", category: .company,
                          definition: "A report on the 1st of each month: what moved revenue and why, what rivals did, the risks ahead and what to do.",
                          detail: "The latest is on the dashboard under Since last month; the last twelve are kept.",
                          screen: .dashboard, aliases: ["report", "summary", "since last month"])
        case .rewind:
            GlossaryEntry(title: "Rewind", category: .company,
                          definition: "Going back to an autosave. One is made at the start of every quarter and the last eight are kept.",
                          detail: "Rewinding replaces the game in progress: everything since that autosave is lost.",
                          screen: .operations, aliases: ["autosave", "undo", "load"])
        case .board:
            GlossaryEntry(title: "Board goals and confidence", category: .company,
                          definition: "The board sets three goals at a time, each with a deadline. Hitting one pays a milestone tranche, culture points and board confidence.",
                          detail: "Confidence moves how investors price your rounds. If it collapses while investors control the board, they can replace you as CEO.",
                          screen: .strategy, aliases: ["board", "goals", "objectives", "confidence", "culture points"])
        case .researchPoints:
            GlossaryEntry(title: "Research points (RP)", category: .company,
                          definition: "What research costs. Researchers produce RP every day and compute multiplies their output.",
                          detail: "Leftover points roll into the next project and idle research feeds your signature programme, so none are wasted. The research director keeps the queue full under the focus you pick.",
                          screen: .research, aliases: ["RP", "research", "director"])
        case .signatureSecret:
            GlossaryEntry(title: "Signature secret", category: .company,
                          definition: "A research programme only your lab has, live from the first day.",
                          detail: "Pour research into it to climb five levels; levels 3 and 5 unlock capstone abilities.",
                          screen: .research, aliases: ["signature", "secret"])

        // MARK: Rivals
        case .forecastBand:
            GlossaryEntry(title: "Rival Watch forecast band", category: .rivals,
                          definition: "The rumour mill's estimate of a rival's next model: a launch window and an Intelligence Index forecast with an 80% band.",
                          detail: "Both narrow as the launch nears and as your intel improves: a paid intel budget, your own model reading the signals, staff from labs you bought and intelligence swarms. The track record shows how often the band was right.",
                          screen: .rivalWatch, aliases: ["rumour", "rumor", "intel", "launch window"])
        case .leapfrog:
            GlossaryEntry(title: "Leapfrog", category: .rivals,
                          definition: "Passing a rival's best model, or the whole field, with a new release.",
                          detail: "Leapfrog a lab whose next model is already in post-training and it may call a code red. Big labs that have watched you hold #1 for six months start betting runs on passing you back, so a lead rarely holds by itself.",
                          screen: .rivalWatch, aliases: ["pass", "overtake", "lead"])
        case .codeRed:
            GlossaryEntry(title: "Code red", category: .rivals,
                          definition: "A rival's answer when you ship a better model while its own is in post-training: it rushes its model out up to four weeks early and a little weaker, or holds it back three to six weeks to train it harder.",
                          detail: "Ship a better model in the two weeks before a rival's launch and you own the news cycle (brand +2).",
                          screen: .rivalWatch, aliases: ["rush", "hold back"])
        case .marketCorrection:
            GlossaryEntry(title: "Market correction", category: .rivals,
                          definition: "A downturn after the AI market overheats: valuations fall, but GPUs and cloud capacity get cheaper.",
                          detail: "Weak labs can run out of money in one, and their researchers and compute come up for sale.",
                          screen: .industry, aliases: ["bubble", "downturn", "crash"])

        // MARK: Safety and the frontier
        case .safetyThresholds:
            GlossaryEntry(title: "Safety thresholds", category: .frontier,
                          definition: "Dangerous-capability levels modelled on real frontier-safety policies: early warning, High (ASL-3-class) and Critical (ASL-4-class).",
                          detail: "A model past High needs a safety score of 62 to ship with safeguards (Critical: 78). Safeguards cost a little serving throughput; shipping below the bar costs brand and invites misuse incidents and regulators. Safety training, RLHF, a safety team and safety research raise model safety.",
                          screen: .benchmarks, aliases: ["ASL", "dangerous capabilities", "safeguards", "safety score"])
        case .securityLevels:
            GlossaryEntry(title: "Security levels (SL1–SL5)", category: .frontier,
                          definition: "How well your model weights are protected, after RAND's framework: each level stops a more capable attacker, from a lone amateur to a nation-state operation.",
                          detail: "The closer you are to the frontier, the more attackers come for your weights. Higher levels take months to build, cost more to run and slow research a little.",
                          screen: .security, aliases: ["SL3", "weights security", "theft", "RAND"])
        case .domains:
            GlossaryEntry(title: "Capability domains", category: .race,
                          definition: "A model's ability in eleven areas — knowledge, reasoning, mathematics, science, coding, agents, long memory, vision, voice, social and robotics — each on the Capability yardstick (100 is the frontier of early 2023; +10 is ten times the effective compute).",
                          detail: "Your scores come from the model's training and skills, its design (vision, audio, video) and research that targets a domain. Rivals get their lab's specialities and most of what the field has published. Domains decide milestones and which product lines open.",
                          screen: .models, aliases: ["domains", "skills", "radar", "areas"])
        case .milestones:
            GlossaryEntry(title: "AI milestones", category: .race,
                          definition: "45 firsts, from beating people at reading comprehension to household robots and Nobel-calibre discoveries. The first released model of any lab to clear one gets the credit, the headlines and a little brand.",
                          detail: "Each needs scores in one or more domains. Up to 2026 they're set to land on their real dates; later ones are forecasts that a fast race can beat. Milestones reached before your game began are credited to the labs that got there.",
                          screen: .milestones, aliases: ["firsts", "milestone race"])
        case .productLines:
            GlossaryEntry(title: "Product lines", category: .business,
                          definition: "Products beyond chat, API, agents and contracts — voice assistant, computer-use operator, video studio, discovery service, healthcare, tutoring, robotics brains, government and defence — each opened by domain scores on your best released model plus one research project.",
                          detail: "Launching costs about four months of upkeep. Your share of each market follows your product's quality against rivals' products, your brand, how many customers you already reach and whether you serve the demand you have.",
                          screen: .products, aliases: ["products", "voice", "video", "robotics", "healthcare", "tutor"])
        case .pulse:
            GlossaryEntry(title: "The Pulse and buzz", category: .rivals,
                          definition: "The industry's chatter: short posts from lab chiefs, researchers, analysts, reporters, officials, critics and anonymous accounts reacting to launches, rounds, rumours, votes and leaks. Buzz is how much a lab is talked about (attention, 0–100) and how kindly (tone), over the last 60 days.",
                          detail: "The people are a cast of named characters with careers: they get poached, found startups, take over labs, retire, join governments or turn critic, and their history is on the Pulse's People tab and on lab profiles. The chatter is colour: it doesn't change the numbers.",
                          screen: .pulse, aliases: ["buzz", "chatter", "people", "cast", "posts", "who's who"])
        case .stakeholders:
            GlossaryEntry(title: "Your standing", category: .world,
                          definition: "How five groups see you, 0–100: the public, researchers, developers, investors (the board's confidence) and governments in seven regions. Each drifts toward where your record puts it.",
                          detail: "Launches, open weights, published research, leaks, layoffs, price changes, outages, bill stances and deals move them, and each move is listed with its date. In return, public trust moves chat demand and developer goodwill moves API demand by up to 6%, researchers' respect shifts candidates' skill by up to 3 points, and governments decide how many sovereign deals come your way.",
                          screen: .world, aliases: ["stakeholders", "trust", "reputation", "goodwill", "standing"])
        case .publicMood:
            GlossaryEntry(title: "Public mood and safety concern", category: .world,
                          definition: "How people feel about AI, and how worried they are about it. Both move every month.",
                          detail: "Useful AI, jobs created and cheap prices lift the mood; job losses and incidents (escapes, leaks, misuse) sour it. Safety concern jumps with incidents and fades slowly. High concern slows adoption and pushes regulators to act.",
                          screen: .world, aliases: ["sentiment", "concern", "opinion", "mood"])
        case .regulation:
            GlossaryEntry(title: "Rules by region", category: .world,
                          definition: "How strict AI rules are in the US, EU, UK, China, the Gulf, India and Japan & Korea, 0–100. They follow real laws up to 2026, then move with incidents, public mood, lobbying and the bills that pass.",
                          detail: "Strict rules slow adoption in that region, and a major incident there can bring emergency rules or an inquiry into the lab responsible. Your standing with each government is shown next to its rules.",
                          screen: .world, aliases: ["regulation", "regulators", "law", "regions", "rules"])
        case .consequences:
            GlossaryEntry(title: "Consequences", category: .world,
                          definition: "Things the world does because of where it stands, not by chance: regulators answering incidents, protests and strikes over jobs, grid emergencies, hearings on very capable AI, partnerships when trust is high.",
                          detail: "At most five a year and at least 60 days apart. None of them stops the clock: they arrive as news and banners, and the few that ask you something wait in the inbox.",
                          screen: .world, aliases: ["protests", "strikes", "robot tax", "hearings", "summons", "grid emergency"])
        case .politicalCapital:
            GlossaryEntry(title: "Political capital", category: .frontier,
                          definition: "Your influence in policy, built mostly by a monthly lobbying budget. It fades about 5% a month, so it needs steady lobbying.",
                          detail: "It makes the side you take on a bill more likely to win and cuts fines. Taking or switching sides spends a little, and before 2028 the top security level needs a government partnership worth 40 of it.",
                          screen: .security, aliases: ["lobbying", "bills", "policy"])
        case .rsi:
            GlossaryEntry(title: "Recursive self-improvement (RSI)", category: .frontier,
                          definition: "Letting a model improve its own training, generation after generation, on chips you assign. Gains compound, up to a ceiling.",
                          detail: "Alignment drifts out of sight as it goes, faster with more autonomy and less oversight. Checkpoints let you promote a generation to a new model, roll back or run a deep audit.",
                          screen: .rsi, aliases: ["self-improvement", "generations", "autonomy", "oversight"])
        case .swarms:
            GlossaryEntry(title: "AI organisations & agent swarms", category: .frontier,
                          definition: "Teams of copies of your models, from ten to a billion agents on your inference chips, organised around one objective: software, architecture research, scientific discovery, chips, training or infrastructure operations, security, robotics, finance, experiments, alignment, intelligence, alien-tech search or paid work.",
                          detail: "Each agent burns tens of millions of tokens a day, so chips set the size of a team. Output grows slower than the number of agents (and coordination overhead grows with size); supervisor teams, verification and a tools budget win some of it back. An agent is worth more the smarter its model, and more again when the model is strong in the domains the work needs. More autonomy is faster but drifts out of alignment faster.",
                          screen: .swarms, aliases: ["agents", "swarm", "missions", "workforce", "organisation", "organization", "supervisors", "verification"])
        case .alignmentDrift:
            GlossaryEntry(title: "Alignment drift", category: .frontier,
                          definition: "Swarms and self-improvement runs slowly slide out of alignment (0–100), faster with more autonomy, less oversight, bigger swarms and alien architectures.",
                          detail: "What you see is a measured estimate; a deep audit gives a near-exact reading. Safety staff, safety research and alignment swarms slow it. Below about 30, collusion and escapes become likely.",
                          screen: .swarms, aliases: ["alignment", "audit", "oversight"])
        case .alienTech:
            GlossaryEntry(title: "Alien tech", category: .frontier,
                          definition: "Designs your agents find where no human would look: architectures, chips, optimizers and more, which people only partly understand.",
                          detail: "Study them to make them legible, then keep them exclusive, sell the chips or license the blueprint.",
                          screen: .xeno, aliases: ["xeno", "alien architecture"])
        }
    }
}

enum Glossary {
    /// Words a question wraps around the term ("what is MFU?").
    static let fillerWords: Set<String> = ["what", "whats", "is", "are", "a", "an", "the", "does", "do", "mean", "means", "meaning", "define", "of", "how"]

    /// Lowercased words, split on anything but letters, digits and "#".
    static func words(_ text: String) -> [String] {
        text.lowercased().split { !($0.isLetter || $0.isNumber || $0 == "#") }.map(String.init)
    }

    /// Terms where every word of the query starts a word of the title, aliases or text: names that start with the
    /// query first, then names that contain it, then names that contain each word, then the rest. An empty query
    /// returns every term.
    static func search(_ query: String) -> [GlossaryTerm] {
        let all = words(query)
        let meaningful = all.filter { !fillerWords.contains($0) }
        let qs = meaningful.isEmpty ? all : meaningful
        guard !qs.isEmpty else { return GlossaryTerm.allCases }
        let phrase = qs.joined(separator: " ")
        var hits: [(term: GlossaryTerm, rank: Int)] = []
        for t in GlossaryTerm.allCases {
            let e = t.entry
            let names = ([e.title] + e.aliases).map { words($0).joined(separator: " ") }
            let text = words(([e.title] + e.aliases + [e.definition, e.detail]).joined(separator: " "))
            guard qs.allSatisfy({ w in text.contains { $0.hasPrefix(w) } }) else { continue }
            let rank: Int
            if names.contains(where: { $0.hasPrefix(phrase) }) {
                rank = 0
            } else if names.contains(where: { $0.contains(phrase) }) {
                rank = 1
            } else if qs.allSatisfy({ w in names.contains { $0.contains(w) } }) {
                rank = 2
            } else {
                rank = 3
            }
            hits.append((t, rank))
        }
        return hits.sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.term.title < $1.term.title }.map { $0.term }
    }

    static func terms(in category: GlossaryCategory) -> [GlossaryTerm] {
        GlossaryTerm.allCases.filter { $0.category == category }
    }
}

// MARK: - First-visit hints

/// First-visit hints: what a screen is for and the first useful thing to do there, shown until the player dismisses them.
enum ScreenGuide {
    struct Hint: Sendable {
        let title: String
        let text: String
        let firstStep: String
        /// A glossary term the hint links to.
        let term: GlossaryTerm?
    }

    static func hint(for screen: Screen) -> Hint? {
        switch screen {
        case .dashboard:
            Hint(title: "Today", text: "Your daily view: what needs you, what's coming up and how the race stands. Most items under Needs you have a one-click fix.",
                      firstStep: "Start with the top item under Needs you, then look at Coming up.", term: .chiefOfStaff)
        case .lab:
            Hint(title: "Model Lab", text: "Design a training run. Every choice moves the forecast on the right: the Intelligence Index you'd likely get, how sure that is, the cost and how long it takes.",
                      firstStep: "Pick a recipe card at the top, check the forecast and the cost, then press Start training.", term: .forecast)
        case .training:
            Hint(title: "Training Runs", text: "Your runs in progress. The loss curve shows how training compares with the forecast, and incidents such as loss spikes ask you to decide. A finished run's model goes to Models & Serving.",
                      firstStep: "If a run is slower than planned, look at its goodput and ops coverage.", term: .goodput)
        case .models:
            Hint(title: "Models & Serving", text: "Release finished models, give them serving chips and set API prices. A released model without chips can't take any traffic.",
                      firstStep: "Release your best model, then deploy chips to it, or let the capacity delegate do it.", term: .servingCapacity)
        case .families:   // 3.5: model families
            Hint(title: "Model Families", text: "A lineup instead of one flagship: distil cheaper tiers from your best model, upgrade models with post-training passes, and let each tier serve the traffic it's priced for.",
                      firstStep: "Distil a Spark tier from your flagship, then route the chat app's free users to it.", term: .servingCapacity)
        case .leaderboard:
            Hint(title: "Leaderboard", text: "The race, lab by lab, ranked by each lab's best model on the Intelligence Index. Capability is a fixed yardstick you can compare across years.",
                      firstStep: "Click a lab to see all its models. The gap to #1 tells you how much more compute you'd need.", term: .capability)
        case .rivals:
            Hint(title: "Rivals", text: "Who leads (Overview), what each lab is and does (Labs), what they're about to ship (Watch) and the money behind it all (Industry).",
                      firstStep: "Open Watch to see launches that could pass your best model.", term: .forecastBand)
        case .research:
            Hint(title: "Research", text: "Researchers produce research points. Spend them on techniques that make training, serving and products better; leftover points carry over.",
                      firstStep: "Queue a few techniques, or turn on the research director to keep the queue full.", term: .researchPoints)
        case .team:
            Hint(title: "Team", text: "Researchers speed up research, ML engineers raise training efficiency, infra engineers keep big clusters running and sales staff bring in enterprise deals.",
                      firstStep: "Hire from the candidates. People paid well below the market get poached.", term: nil)
        case .hardware:
            Hint(title: "Hardware Store", text: "Real accelerators with real specs. Rent cloud chips by the hour, reserve them for a discount, or buy chips for a site you own.",
                      firstStep: "Rent a few chips to start training. Buy once you know you'll keep them busy.", term: .reservedCloud)
        case .compute:
            Hint(title: "Compute Fleet", text: "Every chip you own or rent and what it's doing: training, serving, research, swarms, leased out or idle.",
                      firstStep: "Idle chips still cost money: train, serve or lease them out.", term: .h100e)
        case .market:
            Hint(title: "Market & Products", text: "Where revenue comes from: the API, a chat app, agent seats and enterprise contracts.",
                      firstStep: "Launch a chat app once you have an instruction-tuned model, and review enterprise leads before they expire.", term: .sla)
        case .funding:
            Hint(title: "Funding & Equity", text: "Sell part of the company to pay for compute. Every round dilutes your stake, so raise while your valuation is strong and before cash runs short.",
                      firstStep: "Start a round with several months of runway left: term sheets take a few weeks to arrive.", term: .dilution)
        case .finance:
            Hint(title: "Finance", text: "Profit and loss, cash, debt and runway, month by month.",
                      firstStep: "Keep an eye on runway. Under four months, start raising or cut costs.", term: .runway)
        case .corporate:
            Hint(title: "Corporate", text: "Your company as a group: monthly statements, corporate debt and its covenants, your credit rating, the cap table, taxes, and subsidiaries you start, buy, sell down, list, spin off or fold back in.",
                      firstStep: "Check the runway scenarios on Statements, then try a small subsidiary on the Subsidiaries tab.", term: .runway)
        case .operations:
            Hint(title: "Operations", text: "Hand recurring chores to delegates that run on your best model, choose which alerts stop the clock, and rewind a bad call.",
                      firstStep: "Turn on the serving-capacity and launch delegates first.", term: .delegates)
        case .semiconductors:
            Hint(title: "Semiconductors", text: "Make your own accelerators: a design team designs a chip for a process node and tapes it out, then wafers, advanced packaging and HBM turn into chips you keep or sell. Every number shows where it comes from.",
                      firstStep: "Hire a design team on the Design tab, then start a design on a node a foundry already offers.", term: nil)
        case .progression:   // 3.7: company stages and launches
            Hint(title: "Progression", text: "How big a company you've become — Garage to Civilisational — and what it takes to grow: capability, revenue, compute and headcount. Each promotion unlocks a power. Below it, every launch you've made and its report.",
                      firstStep: "Look at the criterion furthest from its bar: that's what holds your next promotion back.", term: nil)
        default:
            nil
        }
    }

    /// Screens that have a first-visit hint.
    static var screens: [Screen] { Screen.allCases.filter { hint(for: $0) != nil } }
}
