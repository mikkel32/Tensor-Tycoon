import Foundation

/// Headless "sensible human" playtest bot.
///
///   TensorTycoon --playtest <era> <seeds e.g. 1,2,3> <years> [table|full|quiet] [flags]
///   TensorTycoon --playtest probe          (Model Lab estimate vs. actual progress on big clusters)
///
/// flags (comma-separated, optional): cautious (20% of cash per run, current-gen chips only, slow hiring, no research
/// compute, no growth rounds), norent (never rents: garage GPUs only), hard / easy (difficulty), noresearchcompute,
/// autorollback, noquick.
///
/// Output: a monthly table (every 3rd month unless mode is `full`), an event log, every training run (plan vs actual
/// days, forecast vs actual capability), a summary of pacing metrics, and `CSV,` rows for offline aggregation.
///
/// The bot plays like a reasonable (not optimal) player: one ~80-day training run at a time on rented chips sized with the
/// Model Lab's own auto-size rule, releases every model that beats its last one (API + chat + agents), scales inference to
/// demand, keeps the research director on, hires toward a balanced team, raises when runway is short, signs enterprise deals
/// it qualifies for, adopts culture perks, buys data licences when rich, upgrades weight security when warned, and resolves
/// every decision the way a cautious player would. It logs one row per month and summarises pacing problems at the end.
enum PlaytestHarness {
    static func main(_ a: [String]) {
        if a.first == "probe" { PTPlay.probe(); return }
        let era = a.count > 0 ? a[0] : "2022"
        let seeds = (a.count > 1 ? a[1] : "1,2,3").split(separator: ",").compactMap { UInt64($0) }
        let years = a.count > 2 ? (Double(a[2]) ?? 7) : 7
        let mode = a.count > 3 ? a[3] : "table"
        let flags = Set((a.count > 4 ? a[4] : "").split(separator: ",").map(String.init))
        var all: [PTSummary] = []
        for seed in seeds { all.append(PTPlay.play(era: era, seed: seed, years: years, mode: mode, flags: flags)) }
        PTPlay.aggregate(all, era: era)
    }
}

// MARK: - Records

struct PTRun {
    var name: String
    var start: Date
    var end: Date? = nil
    var accel: String
    var chips: Int
    var paramsB: Double
    var activeB: Double
    var tokensT: Double
    var forecastC: Double
    var estDays: Double
    var estCost: Double
    var planDays: Double = .nan
    var frontierAtStart: Double
    var c: Double = .nan
    var index: Double = .nan
    var rank: Int = 0
    var frontierAtEnd: Double = .nan
    var released = false
}

struct PTRow {
    var label = ""
    var year = 0.0
    var cash = 0.0
    var revenue = 0.0
    var profit = 0.0
    var opProfit = 0.0
    var runRate = 0.0
    var valuation = 0.0
    var chips = 0
    var h100e = 0.0
    var bestC = -10.0
    var bestIdx = 0.0
    var gap = -10.0
    var frontier = 0.0
    var topIdx = 0.0
    var topName = ""
    var rank = 0
    var users = 0.0
    var employees = 0
    var researched = 0
    var rp = 0.0
    var decisions = 0
    var kinds: [String: Int] = [:]
    var worldNews = 0
    var important = 0
    var actions = 0
    var events: [String] = []
    var stake = 0.0
    var training = "-"
    var apiShare = 0.0
    var marketShare = 0.0
    var brand = 0.0
    var board = 0.0
    var idleDays = 0
    var fleet = ""
}

struct PTSummary {
    var era = ""
    var seed: UInt64 = 0
    var months = 0
    var gameOver: String? = nil
    var firstRun: Int? = nil
    var firstModel: Int? = nil
    var firstRevenue: Int? = nil
    var firstMillionMonth: Int? = nil
    var firstProfit: Int? = nil
    var firstTop10: Int? = nil
    var firstTop3: Int? = nil
    var firstNo1: Int? = nil
    var monthsNo1 = 0
    var minCash = Double.infinity
    var minCashLabel = ""
    var daysNegative = 0
    var raises = 0
    var raised = 0.0
    var decisionsTotal = 0
    var decisionMax = 0
    var decisionMaxLabel = ""
    var kinds: [String: Int] = [:]
    var newsAvg = 0.0
    var newsMax = 0
    var importantAvg = 0.0
    var quietMonths = 0
    var longestQuiet = 0
    var longestQuietFrom = ""
    var runs: [PTRun] = []
    var anomalies: [String] = []
    var end = PTRow()
    var acqOffers = 0
    var acqBest = 0.0
    var researchPerYear = 0.0
    var idleRentFrac = 0.0
    var rentalCapHits = 0
    var stalledDays = 0
    var waitDays = 0
    var lowballs = 0
    var lowGoodputSkips = 0
    var cancelledStalls = 0
    var ceilingDays = 0
    var notes: [String] = []
    var maxValJump = 0.0
    var maxValDrop = 0.0
    var maxChips = 0
    var maxChipsWhat = ""
    var actionsAvg = 0.0
    var idleAvg = 0.0
}

struct PTBot {
    var runN = 0
    var lastHire = Date.distantPast
    var lastResearchCompute = Date.distantPast
    var actions = 0
    var events: [String] = []
    var runs: [PTRun] = []
    var quickName: String? = nil
    var acqOffers = 0
    var acqBest = 0.0
    var rentalCapHits = 0
    var stalledDays = 0
    var waitDays = 0
    var flags: Set<String> = []
    var log: [String] = []
    var lowballs = 0
    var noRaiseUntil = Date.distantPast
    var lowGoodputSkips = 0
    var cancelledStalls = 0
    var progressMark: [UUID: (Date, Double)] = [:]
    var nextPlan = Date.distantPast
    var ceilingDays = 0
    var notes: [String] = []
}

// MARK: - The player

enum PTPlay {
    static let trainDays = 80.0

    static func d(_ a: Date, _ b: Date) -> Int { GameCalendar.daysBetween(a, b) }
    static func m(_ v: Double) -> String { Fmt.money(v) }
    static func isLive(_ r: TrainingRun) -> Bool { r.status == .running || r.status == .postTraining || r.status == .paused }
    static func rented(_ s: GameState, _ id: String) -> Int { s.rentals.filter { $0.accelID == id }.reduce(0) { $0 + $1.count } }

    // MARK: Game loop

    static func play(era: String, seed: UInt64, years: Double, mode: String, flags: Set<String>) -> PTSummary {
        let diff: Difficulty = flags.contains("hard") ? .hard : (flags.contains("easy") ? .easy : .normal)
        var s = NewGame.create(NewGameSettings(companyName: "Playtest Labs", founderName: "Pat", eraID: era, difficulty: diff), seed: seed)
        var bot = PTBot()
        bot.flags = flags
        cautiousFlag = flags.contains("cautious")
        let start = s.date
        let totalDays = Int(years * 365.25)
        var rows: [PTRow] = []
        var kinds: [String: Int] = [:]
        var worldNews = 0, important = 0, idle = 0
        var anomalies: [String: String] = [:]
        var seen = Set<UUID>()
        var sum = PTSummary()
        sum.era = era
        sum.seed = seed
        var idleChipDays = 0.0, rentedChipDays = 0.0
        let researched0 = s.researched.count

        if mode != "quiet" {
            print("\n================ \(era) era · seed \(seed) · \(Int(years)) years ================")
            let top = Leaderboard.entries(s, includeUnreleased: false).max { $0.index < $1.index }
            print("Start \(s.date.gameShort): cash \(m(s.cash)), \(s.owned.first.map { "\($0.count)× \($0.accelID)" } ?? "no chips"), \(s.employees.count) staff, "
                  + "world #1 \(top.map { "\($0.model) idx \(Fmt.score($0.index))" } ?? "NONE (empty leaderboard)"), frontier c \(Fmt.trim(Macro.frontier(s.year), 2))")
        }

        act(&s, &bot)
        for _ in 0..<totalDays {
            let month = s.date.ym
            let newsBefore = s.unreadNews
            let actionsBefore = bot.actions
            Sim.advanceDay(&s)
            if s.date.ym != month {
                rows.append(row(s, &bot, label: month.label, kinds: kinds, worldNews: worldNews, important: important, idle: idle))
                kinds = [:]; worldNews = 0; important = 0; idle = 0
            }
            let n = max(0, s.unreadNews - newsBefore)
            worldNews += n
            important += s.news.prefix(min(n, s.news.count)).filter(\.important).count
            var decided = 0
            for dd in s.decisions where !seen.contains(dd.id) {
                seen.insert(dd.id)
                kinds[dd.kind, default: 0] += 1
                decided += 1
            }
            resolve(&s, &bot)
            if s.gameOver != nil { break }
            act(&s, &bot)
            if bot.actions == actionsBefore && decided == 0 { idle += 1 }
            for p in Economy.pools(s) where p.rented > 0 {
                rentedChipDays += Double(p.rented)
                idleChipDays += Double(min(p.free, p.rented))
            }
            check(s, &anomalies)
            if s.cash < 0 { sum.daysNegative += 1 }
            if !s.runs.contains(where: { isLive($0) && $0.kind == .full }) { bot.waitDays += 1 }
            let day = d(start, s.date)
            if sum.firstRevenue == nil && s.lifetimeRevenue > 1 { sum.firstRevenue = day }
            if sum.firstRun == nil && !s.runs.isEmpty { sum.firstRun = day }
            if sum.firstModel == nil && !s.models.isEmpty { sum.firstModel = day }
        }
        if s.gameOver != nil {
            rows.append(row(s, &bot, label: s.date.ym.label + "*", kinds: kinds, worldNews: worldNews, important: important, idle: idle))
        }

        // Summary
        sum.months = rows.count
        sum.gameOver = s.gameOver
        sum.runs = bot.runs
        sum.anomalies = anomalies.sorted { $0.key < $1.key }.map { "\($0.key) (first \($0.value))" }
        sum.end = rows.last ?? PTRow()
        sum.acqOffers = bot.acqOffers
        sum.acqBest = bot.acqBest
        sum.rentalCapHits = bot.rentalCapHits
        sum.stalledDays = bot.stalledDays
        sum.waitDays = bot.waitDays
        sum.lowballs = bot.lowballs
        sum.lowGoodputSkips = bot.lowGoodputSkips
        sum.cancelledStalls = bot.cancelledStalls
        sum.ceilingDays = bot.ceilingDays
        sum.notes = bot.notes
        for i in rows.indices.dropFirst() where rows[i - 1].valuation > 0 {
            let r = rows[i].valuation / rows[i - 1].valuation
            sum.maxValJump = max(sum.maxValJump, r)
            sum.maxValDrop = max(sum.maxValDrop, 1 - r)
        }
        if let r = rows.max(by: { $0.chips < $1.chips }) { sum.maxChips = r.chips; sum.maxChipsWhat = "\(r.label): \(r.fleet)" }
        sum.actionsAvg = rows.isEmpty ? 0 : Double(rows.reduce(0) { $0 + $1.actions }) / Double(rows.count)
        sum.idleAvg = rows.isEmpty ? 0 : Double(rows.reduce(0) { $0 + $1.idleDays }) / Double(rows.count)
        sum.idleRentFrac = rentedChipDays > 0 ? idleChipDays / rentedChipDays : 0
        sum.researchPerYear = Double(s.researched.count - researched0) / max(0.1, Double(d(start, s.date)) / 365)
        sum.raises = s.rounds.count - 1
        sum.raised = s.rounds.dropFirst().reduce(0) { $0 + $1.amount }
        var quietRun = 0, quietFrom = ""
        for (i, r) in rows.enumerated() {
            let monthDay = Int(Double(i + 1) * 30.44)
            if r.cash < sum.minCash { sum.minCash = r.cash; sum.minCashLabel = r.label }
            if sum.firstMillionMonth == nil && r.revenue >= 1e6 { sum.firstMillionMonth = monthDay }
            if sum.firstProfit == nil && r.opProfit > 0 && r.revenue > 0 { sum.firstProfit = monthDay }
            if r.rank > 0 && r.rank <= 10 && sum.firstTop10 == nil { sum.firstTop10 = monthDay }
            if r.rank > 0 && r.rank <= 3 && sum.firstTop3 == nil { sum.firstTop3 = monthDay }
            if r.rank == 1 { if sum.firstNo1 == nil { sum.firstNo1 = monthDay }; sum.monthsNo1 += 1 }
            sum.decisionsTotal += r.decisions
            if r.decisions > sum.decisionMax { sum.decisionMax = r.decisions; sum.decisionMaxLabel = r.label }
            for (k, v) in r.kinds { sum.kinds[k, default: 0] += v }
            sum.newsMax = max(sum.newsMax, r.worldNews)
            let quiet = r.decisions == 0 && r.events.isEmpty
            if quiet {
                sum.quietMonths += 1
                if quietRun == 0 { quietFrom = r.label }
                quietRun += 1
                if quietRun > sum.longestQuiet { sum.longestQuiet = quietRun; sum.longestQuietFrom = quietFrom }
            } else { quietRun = 0 }
        }
        sum.newsAvg = rows.isEmpty ? 0 : Double(rows.reduce(0) { $0 + $1.worldNews }) / Double(rows.count)
        sum.importantAvg = rows.isEmpty ? 0 : Double(rows.reduce(0) { $0 + $1.important }) / Double(rows.count)

        if mode != "quiet" { printGame(rows, sum, bot, s, mode: mode) }
        return sum
    }

    // MARK: Monthly row

    static func row(_ s: GameState, _ bot: inout PTBot, label: String, kinds: [String: Int], worldNews: Int, important: Int, idle: Int) -> PTRow {
        var r = PTRow()
        r.label = label
        r.year = s.year
        let h = s.history.last
        r.cash = h?.cashEnd ?? s.cash
        r.revenue = h?.revenue ?? 0
        r.profit = h?.profit ?? 0
        r.opProfit = (h?.revenue ?? 0) - (h?.opex ?? 0)
        r.runRate = Economy.runRate(s)
        r.valuation = s.valuation
        r.chips = Economy.totalChips(s)
        r.h100e = Economy.h100e(s)
        r.frontier = Macro.frontier(s.year)
        let set = Leaderboard.indexSet(s)
        let board = Leaderboard.entries(s, set: set, includeUnreleased: false)
        if let top = board.filter({ !$0.isPlayer }).max(by: { $0.index < $1.index }) {
            r.topIdx = top.index
            r.topName = "\(top.model) (\(top.lab))"
        }
        if let me = board.filter(\.isPlayer).max(by: { $0.index < $1.index }) {
            r.bestIdx = me.index
            r.bestC = me.c
            r.gap = me.c - r.frontier
            r.rank = board.filter { !$0.isPlayer && $0.index > me.index }.count + 1
        }
        r.users = s.consumerUsers
        r.employees = s.employees.count
        r.researched = s.researched.count
        r.rp = s.rpToday
        r.decisions = kinds.values.reduce(0, +)
        r.kinds = kinds
        r.worldNews = worldNews
        r.important = important
        r.actions = bot.actions
        r.events = bot.events
        r.stake = s.founderStake
        r.apiShare = s.apiShareNow
        r.marketShare = (h?.revenue ?? 0) * 12 / max(1, Macro.marketSize(s.year))
        r.brand = s.brand
        r.board = s.boardConfidence
        r.idleDays = idle
        r.fleet = Economy.pools(s).sorted { $0.total > $1.total }.prefix(2).map { "\($0.total)× \($0.accel.id) (train \($0.training), serve \($0.inference), research \($0.research))" }.joined(separator: ", ")
        if let run = s.runs.last(where: { isLive($0) && $0.kind == .full }) {
            r.training = "\(run.design.name) \(Int(run.progress * 100))%\(run.status == .paused ? " PAUSED" : "")"
        }
        bot.actions = 0
        bot.events = []
        return r
    }

    // MARK: Decisions

    static func choice(_ dd: Decision, _ s: GameState) -> Int {
        switch dd.kind {
        case "loss_spike": return 0                           // roll back, safest
        case "train_bug": return 1                            // hot-fix and keep going
        case "contamination": return 0
        case "data_mix": return s.year >= 2024 ? 0 : 1
        case "fault_storm": return 0
        case "sycophancy", "reward_hack": return 0
        case "jailbreak": return 0
        case "lawsuit": return s.cash > dd.amount * 2 ? 0 : 1
        case "defense": return 0
        case "acquisition": return 1                          // stay independent (keep playing)
        case "poach": return s.cash > dd.amount * 4 ? 0 : 1
        case "partner_offer":
            let parts = dd.ref.split(separator: "|")
            guard parts.count == 2, parts[1] == "0", let id = PartnerID(rawValue: String(parts[0])), let def = PartnerCatalog.byID[id] else { return 2 }
            let t = PartnerCatalog.terms(def, exclusive: false, years: 4, state: s)
            let spend = s.rentals.filter { r in HardwareCatalog.get(r.accelID).map { def.vendors.contains($0.vendor) } ?? false }
                .reduce(0.0) { $0 + $1.hourly * 24 * 365 * Double($1.count) }
            return spend > t.annualCommit * 1.2 ? 0 : 2
        case "policy_bill": return 2
        case "rival_round": return 2
        case "fire_sale", "merger_offer", "exclusive_supply": return 1
        case "victory": return 0
        case "board_ouster": return 0
        case "spinoff": return 0
        case "sovereign_deal": return 0
        case "distill_campaign", "eval_escape", "insider_caught": return 0
        case "talent_raid": return s.cash > dd.amount * 4 ? 0 : 1
        case "swarm_audit": return s.cash > dd.amount * 4 ? 0 : 1
        default: return 0
        }
    }

    static func resolve(_ s: inout GameState, _ bot: inout PTBot) {
        var guardN = 0
        while let dd = s.decisions.first, guardN < 20 {
            guardN += 1
            if dd.kind == "acquisition" {
                bot.acqOffers += 1
                bot.acqBest = max(bot.acqBest, dd.amount)
            }
            if ["victory", "board_ouster", "merger_offer", "fire_sale"].contains(dd.kind) || (dd.kind == "acquisition" && bot.acqOffers == 1) {
                bot.notes.append("\(s.date.gameShort): \(dd.title)\(dd.amount > 0 ? " (\(m(dd.amount)))" : "")")
            }
            let o = min(choice(dd, s), dd.options.count - 1)
            s.resolveDecision(dd.id, option: max(0, o))
            if s.decisions.first?.id == dd.id { s.decisions.removeFirst() }   // never loop on a stuck decision
        }
    }

    // MARK: Actions

    static func act(_ s: inout GameState, _ bot: inout PTBot) {
        let b = s.bonuses
        releaseFinished(&s, &bot, b)
        manageInference(&s, &bot, b)
        planTraining(&s, &bot, b)
        cancelIdle(&s)
        funding(&s, &bot)
        deals(&s)
        let day = GameCalendar.components(s.date).day
        if day == 2 {
            hiring(&s, &bot)
            perks(&s)
            data(&s, b)
            security(&s, &bot)
            researchCompute(&s, &bot)
        }
    }

    /// Make sure `n` chips of `id` are free, renting on demand if needed. Returns the free count afterwards.
    @discardableResult
    static func ensureFree(_ s: inout GameState, _ bot: inout PTBot, _ id: String, _ n: Int) -> Int {
        let free = Economy.freeChips(s, id)
        guard free < n, !bot.flags.contains("norent"), let a = HardwareCatalog.get(id), Economy.canRent(a, s), Partners.blocker(a, s) == nil else { return free }
        let room = Economy.rentalLimit(a, s) - rented(s, id)
        let add = min(n - free, room)
        if add < n - free { bot.rentalCapHits += 1 }
        guard add > 0 else { return free }
        if s.rentHardware(id, count: add, term: .onDemand) == nil { return free + add }
        return Economy.freeChips(s, id)
    }

    /// Hand back on-demand rentals that sit completely idle.
    static func cancelIdle(_ s: inout GameState) {
        for p in Economy.pools(s) where p.free > 0 && p.rented > 0 {
            var free = p.free
            let rs = s.rentals.filter { $0.accelID == p.accel.id && $0.term == .onDemand }.sorted { $0.count > $1.count }
            for r in rs where r.count <= free {
                if s.cancelRental(r.id) == nil { free -= r.count }
            }
        }
    }

    // MARK: Training

    /// The Model Lab's auto-size rule (ModelLabView LabMath.size): GPT-3-style sizing before Chinchilla research.
    static func size(_ design: inout ModelDesign, flops: Double, overtrain: Double, accel a: Accelerator, bonuses b: ResearchBonuses) {
        var active: Double
        if b.researched.contains("chinchilla") {
            active = ForecastEngine.optimalParamsB(flops: flops) / sqrt(overtrain)
        } else {
            active = sqrt(flops / (6 * 2 * overtrain)) / 1e9
        }
        let memCap = a.weightStreaming ? 1e9 : (b.has(.sharding) ? Double(design.chips) * a.memoryGB / 17.6
            : (b.has(.modelParallel) ? Double(min(design.chips, a.scaleUp)) * a.memoryGB / 17.6 : a.memoryGB / 17.6))
        let total = clamp(min(active / design.activeFraction, memCap * 0.9), 0.05, 20_000)
        design.paramsB = total
        active = total * design.activeFraction
        design.tokensT = clamp(flops / (6 * max(active, 0.001) * 1e9) / 1e12, 0.0005, 150)
    }

    /// The Model Lab's "best recipe" with everything researched switched on.
    static func design(_ s: GameState, _ a: Accelerator, chips: Int, days: Double, name: String, b: ResearchBonuses) -> ModelDesign {
        var d = ModelDesign()
        d.name = name
        d.accelID = a.id
        d.chips = chips
        d.precision = (b.has(.fp8Training) && a.fp8 > 0) ? .fp8 : .bf16
        d.instruct = b.has(.chat)
        d.rlhf = b.has(.rlhf)
        d.useDPO = b.has(.dpo)
        d.reasoning = b.has(.reasoning)
        d.rlLevel = b.has(.extremeRL) ? .heavy : .standard
        d.toolUse = b.has(.toolUse)
        d.agentRL = b.has(.agents) && d.toolUse
        d.vision = b.has(.vision)
        d.contextK = b.has(.context128k) ? 128 : (b.has(.context32k) ? 32 : 8)
        d.optimizer = b.has(.muon) ? .muon : (b.has(.shampoo) ? .shampoo : .adamw)
        d.attention = b.has(.mla) ? .mla : (b.has(.gqa) ? .gqa : .mha)
        d.mtp = b.has(.mtp)
        d.anneal = b.has(.curriculum)
        d.schedule = b.has(.wsd) ? .wsd : .cosine
        d.syntheticShare = b.has(.syntheticData) ? 0.2 : 0
        d.safetyTraining = s.year >= 2023
        if b.has(.moe) { d.activeFraction = b.has(.fineMoE) ? 1.0 / 32 : 1.0 / 16 }
        let post = Physics.postTrainFLOPs(d, pretrain: 1e24, bonuses: b) / 1e24
        let mfu = Physics.mfu(accel: a, chips: chips, state: s, bonuses: b)
        let g = Physics.goodput(chips: chips, state: s, bonuses: b)
        let perDay = Double(chips) * a.trainTFLOPS(d.precision) * 1e12 * mfu * g * 86_400
        // Sized with the engine's Model Lab rule (parameter/token caps). Mid-training shift mirrors the old popup answer.
        d.mixShift = b.has(.curriculum) ? (s.year >= 2024 ? .code : .stem) : .keep
        LabMath.size(&d, flops: perDay * days / (1 + post), overtrain: d.isMoE ? 2 : 1, accel: a, state: s)
        return d
    }

    /// Money a sensible player would put into the next run: 40% of cash, keeping six months of net burn in reserve.
    static var cautiousFlag = false

    static func trainingBudget(_ s: GameState) -> Double {
        let rr = Economy.runRate(s)
        let payroll = Economy.payrollYear(s) / 12
        let office = Economy.officeLevels[min(s.officeLevel, Economy.officeLevels.count - 1)].monthly
        let data = Economy.dataMonthlyCost(s)
        let rent = s.rentals.reduce(0.0) { $0 + $1.hourly * 24 * 30.4 * Double($1.count) }
        let net = rr / 12 - payroll - office - data - rent - s.marketingBudget
        let reserve = max(0, -net) * 6 + 300_000
        return min(s.cash * (cautiousFlag ? 0.2 : 0.4), s.cash - reserve)
    }

    static func planTraining(_ s: inout GameState, _ bot: inout PTBot, _ b: ResearchBonuses) {
        // Day one: a quick model on the garage GPUs, like the Model Lab's "Quick" recipe (but on all four cards).
        if bot.runN == 0 && !bot.flags.contains("noquick"), let starter = s.owned.first {
            if let a = HardwareCatalog.get(starter.accelID) {
                bot.runN += 1
                let dz = design(s, a, chips: starter.count, days: 14, name: "Garage-1", b: b)
                if s.startTraining(dz) == nil {
                    bot.quickName = dz.name
                    record(&s, &bot, dz, b, planDays: 14)
                }
            }
        }
        let live = s.runs.filter { isLive($0) && $0.kind == .full && $0.design.name != bot.quickName }
        guard live.isEmpty else {
            if live.contains(where: { $0.status == .paused }) { bot.stalledDays += 1 }
            // A player watching the progress bar cancels a run that hasn't moved in a month.
            for r in live where r.status == .running {
                let p = r.progress
                if let (at, prog) = bot.progressMark[r.id] {
                    if d(at, s.date) >= 30 {
                        if p - prog < 0.01 {
                            _ = s.setRunStatus(r.id, .cancelled)
                            bot.events.append("CANCELLED stalled \(r.design.name) at \(Int(p * 100))% (\(r.design.chips)× \(r.design.accelID), +\(Fmt.trim((p - prog) * 100, 2))% in 30 days)")
                            bot.cancelledStalls += 1
                            if let i = bot.runs.lastIndex(where: { $0.name == r.design.name }) { bot.runs[i].end = s.date }
                        }
                        bot.progressMark[r.id] = (s.date, p)
                    }
                } else {
                    bot.progressMark[r.id] = (s.date, p)
                }
            }
            return
        }
        let budget = trainingBudget(s)
        guard budget > 20_000, s.date >= bot.nextPlan else { return }
        var best: (d: ModelDesign, a: Accelerator, c: Double, cost: Double, days: Double)? = nil
        let owned = Set(s.owned.map(\.accelID))
        for a in HardwareCatalog.all where (a.cls == .datacenter || a.cls == .tpu || owned.contains(a.id)) && (Economy.canRent(a, s) || owned.contains(a.id)) && Partners.blocker(a, s) == nil {
            guard let rate = Economy.rent(a, s) ?? (owned.contains(a.id) ? 0.01 : nil), rate > 0 else { continue }
            if bot.flags.contains("cautious") && Economy.ageYears(a, s) > 3 { continue }   // a cautious player rents current-generation parts
            let free = Economy.freeChips(s, a.id)
            let room = bot.flags.contains("norent") ? 0 : max(0, Economy.rentalLimit(a, s) - rented(s, a.id))
            let perChipDay = rate * 24
            let affordable = Int(budget / (perChipDay * trainDays))
            var n = min(free + room, max(free, affordable))
            guard n >= 1 else { continue }
            // The Model Lab shows "MFU · goodput"; nobody sensible starts a run it says will make progress <60% of the time,
            // so shrink the cluster until it looks healthy.
            var found: (ModelDesign, Physics.Estimate)? = nil
            for _ in 0..<14 where n >= 1 {
                let dz = design(s, a, chips: n, days: trainDays, name: "x", b: b)
                guard Physics.trainingMemory(dz, accel: a, bonuses: b).ok, let est = Physics.estimate(dz, state: s) else { break }
                if est.goodput >= 0.6 && est.days < 150 { found = (dz, est); break }
                bot.lowGoodputSkips += 1
                n = Int(Double(n) * 0.6)
            }
            guard let (dz, est) = found else { continue }
            let cost = perChipDay * Double(max(0, n - free)) * est.days
            let c = est.forecast.c
            if best == nil || c > best!.c + 0.01 || (abs(c - best!.c) <= 0.01 && cost < best!.cost) {
                best = (dz, a, c, cost, est.days)
            }
        }
        guard let pick = best else { bot.nextPlan = GameCalendar.addDays(s.date, 7); return }
        let bestC = s.models.filter { !$0.retired || $0.released }.map(\.c).max() ?? -10
        guard pick.c > bestC + 0.15 else {
            // Nothing in the store beats what we already have: look again next week.
            bot.nextPlan = GameCalendar.addDays(s.date, 7)
            bot.ceilingDays += 7
            return
        }
        let have = ensureFree(&s, &bot, pick.a.id, pick.d.chips)
        guard have >= 1 else { return }
        bot.runN += 1
        let name = "PT-\(bot.runN)"
        let dz = design(s, pick.a, chips: min(have, pick.d.chips), days: trainDays, name: name, b: b)
        if let err = s.startTraining(dz, lr: .standard, checkpointEvery: 0.1, autoRollback: bot.flags.contains("autorollback")) {
            bot.log.append("\(s.date.gameShort) start error: \(err)")
            return
        }
        record(&s, &bot, dz, b, planDays: pick.days)
    }

    static func record(_ s: inout GameState, _ bot: inout PTBot, _ dz: ModelDesign, _ b: ResearchBonuses, planDays: Double) {
        let est = Physics.estimate(dz, state: s)
        var r = PTRun(name: dz.name, start: s.date, accel: dz.accelID, chips: dz.chips, paramsB: dz.paramsB, activeB: dz.activeParamsB,
                      tokensT: dz.tokensT, forecastC: est?.forecast.c ?? .nan, estDays: est?.days ?? .nan, estCost: est?.totalCost ?? .nan,
                      frontierAtStart: Macro.frontier(s.year))
        r.planDays = planDays
        bot.runs.append(r)
        bot.actions += 1
        bot.events.append("start \(dz.name) (\(dz.chips)× \(dz.accelID), \(Fmt.params(dz.paramsB)), fc c \(Fmt.trim(r.forecastC, 2)), ~\(Int(r.estDays))d, \(m(r.estCost)))")
    }

    // MARK: Releases & serving

    static func bestInferenceAccel(_ s: GameState, _ md: AIModel, _ b: ResearchBonuses) -> Accelerator? {
        var best: (Accelerator, Double)? = nil
        for a in HardwareCatalog.all where (a.cls == .datacenter || a.cls == .tpu) && Economy.canRent(a, s) && Partners.blocker(a, s) == nil {
            guard let rate = Economy.rent(a, s), rate > 0 else { continue }
            let k = Physics.chipsPerReplica(md, accel: a, precision: md.servingPrecision, bonuses: b)
            guard k <= max(8, Economy.rentalLimit(a, s) / 4) else { continue }
            let cap = Physics.capacity(md, deployment: Deployment(accelID: a.id, chips: k), bonuses: b)
            guard cap > 0 else { continue }
            let costPerToken = rate * Double(k) / cap
            if best == nil || costPerToken < best!.1 { best = (a, costPerToken) }
        }
        return best?.0
    }

    static func releaseFinished(_ s: inout GameState, _ bot: inout PTBot, _ b: ResearchBonuses) {
        let fresh = s.models.filter { !$0.released && !$0.retired && !$0.preview }
        guard !fresh.isEmpty else { return }
        for md in fresh {
            let bestReleased = s.releasedModels.map(\.c).max() ?? -10
            let rank = Leaderboard.rank(of: md.id, in: s)
            if let i = bot.runs.lastIndex(where: { $0.name == md.name && $0.end == nil }) {
                bot.runs[i].end = s.date
                bot.runs[i].c = md.c
                bot.runs[i].index = md.index
                bot.runs[i].rank = rank
                bot.runs[i].frontierAtEnd = Macro.frontier(s.year)
                bot.runs[i].released = md.c > bestReleased + 0.02
            }
            guard md.c > bestReleased + 0.02 else {
                s.retire(md.id)
                bot.events.append("shelved \(md.name) (c \(Fmt.trim(md.c, 2)) ≤ released \(Fmt.trim(bestReleased, 2)))")
                continue
            }
            _ = s.release(md.id, api: true, openWeights: false)
            bot.actions += 1
            let prevChat = s.models.first { $0.id == s.chatModelID }
            if md.design.instruct || s.chatModelID == nil { s.chatModelID = md.id }
            if b.has(.toolUse) && md.design.toolUse { s.agentModelID = md.id }
            for i in s.deals.indices where s.deals[i].active { s.deals[i].modelID = md.id }
            // First deployment: enough for what the old flagship was serving, at least one replica.
            let expected = max(prevChat?.demandTokensDay ?? 0, s.releasedModels.filter { $0.id != md.id }.map(\.demandTokensDay).max() ?? 0)
            if let a = bestInferenceAccel(s, md, b) {
                let k = Physics.chipsPerReplica(md, accel: a, precision: md.servingPrecision, bonuses: b)
                let capK = Physics.capacity(md, deployment: Deployment(accelID: a.id, chips: k), bonuses: b)
                let want = max(k, Int(ceil(expected * 1.3 / max(capK, 1))) * k)
                let have = ensureFree(&s, &bot, a.id, want)
                let n = (min(want, have) / k) * k
                if n > 0 { _ = s.deploy(md.id, accelID: a.id, chips: n) }
            }
            bot.events.append("release \(md.name) c \(Fmt.trim(md.c, 2)) (frontier \(Fmt.trim(Macro.frontier(s.year), 2))) idx \(Fmt.score(md.index)) #\(rank)")
        }
        // Keep the two best released models live (plus whatever runs chat/agents); retire the rest to free chips.
        let live = s.releasedModels.sorted { $0.c > $1.c }
        for md in live.dropFirst(2) where md.id != s.chatModelID && md.id != s.agentModelID {
            s.retire(md.id)
        }
    }

    static func manageInference(_ s: inout GameState, _ bot: inout PTBot, _ b: ResearchBonuses) {
        for md in s.models where md.released && !md.retired {
            let main = md.deployments.max { $0.chips < $1.chips }
            guard let id = main?.accelID ?? bestInferenceAccel(s, md, b)?.id, let a = HardwareCatalog.get(id) else { continue }
            let k = Physics.chipsPerReplica(md, accel: a, precision: md.servingPrecision, bonuses: b)
            let capK = Physics.capacity(md, deployment: Deployment(accelID: id, chips: k), bonuses: b)
            guard capK > 0 else { continue }
            let cur = md.deployments.first { $0.accelID == id }?.chips ?? 0
            let demand = md.demandTokensDay
            let cap = md.capacityTokensDay
            var target = max(k, Int(ceil(demand * 1.35 / capK)) * k)
            let grow = cur == 0 || demand > cap * 0.85
            let shrink = Double(target) < Double(cur) * 0.5
            guard grow || shrink else { continue }
            if target > cur {
                let free = ensureFree(&s, &bot, id, target - cur)
                target = min(target, cur + (free / k) * k)
            }
            if target != cur && target > 0 { _ = s.deploy(md.id, accelID: id, chips: target) }
        }
    }

    // MARK: Business

    static func funding(_ s: inout GameState, _ bot: inout PTBot) {
        let burn = max(0, -(s.history.last?.profit ?? 0))
        let runway = burn > 0 ? s.cash / burn : 99
        let desperate = runway < 4 || s.cash < 1e6
        if !s.raiseOffers.isEmpty {
            let expiring = s.raiseOffers.contains { d(s.date, $0.expires) <= 2 }
            if s.raiseOffers.count >= 2 || expiring || s.cash < 0, let best = s.raiseOffers.max(by: { $0.amount < $1.amount }) {
                // A sensible founder won't sell 15% at a fraction of what the company is worth unless the lights are going out.
                if !desperate && best.preMoney < 0.5 * s.valuation {
                    bot.lowballs += 1
                    bot.events.append("declined lowball \(m(best.amount)) at \(m(best.preMoney)) pre (valuation \(m(s.valuation)))")
                    s.cancelRaise()
                    bot.noRaiseUntil = GameCalendar.addDays(s.date, 120)
                } else if s.acceptOffer(best.id) == nil {
                    bot.actions += 1
                    bot.events.append("raised \(m(best.amount)) at \(m(best.preMoney + best.amount)) post (\(best.roundName), \(Fmt.pct(best.amount / (best.preMoney + best.amount), decimals: 0)) for \(Fmt.pct(best.preMoney / max(1, s.valuation), decimals: 0)) of valuation)")
                }
            }
            return
        }
        guard !s.raising, !s.isPublic, s.date >= bot.noRaiseUntil else { return }
        var why: String? = nil
        if runway < 9 { why = "runway \(Fmt.trim(runway, 1)) mo" }
        if s.cash < 1.5e6 { why = "cash \(m(s.cash))" }
        if !bot.flags.contains("cautious"), let last = s.rounds.last, d(last.date, s.date) > 365, s.valuation > (last.preMoney + last.amount) * 3 { why = "valuation up" }
        guard let reason = why else { return }
        if s.startRaise(fraction: 0.15) == nil {
            bot.actions += 1
            bot.events.append("pitching (\(reason))")
        }
    }

    static func deals(_ s: inout GameState) {
        guard let best = s.releasedModels.max(by: { $0.index < $1.index }) else { return }
        for dl in s.deals where !dl.active && best.index + 0.01 >= dl.minIndex && s.safetyScore >= dl.minSafety {
            _ = s.acceptDeal(dl.id, modelID: best.id)
        }
    }

    static let roleMix: [(Role, Double)] = [(.researcher, 0.40), (.mlEngineer, 0.25), (.infra, 0.10), (.data, 0.10), (.sales, 0.10), (.safety, 0.05)]

    static func hiring(_ s: inout GameState, _ bot: inout PTBot) {
        // Office first.
        if s.employees.count >= Economy.officeCapacity(s) - 1, s.officeLevel + 1 < Economy.officeLevels.count {
            let next = Economy.officeLevels[s.officeLevel + 1]
            if next.monthly * 3 < s.cash * 0.05 && next.monthly < max(s.cash / 40, Economy.runRate(s) / 12 * 0.1) {
                if s.upgradeOffice() == nil { bot.actions += 1; bot.events.append("office → \(next.name)") }
            }
        }
        var hired: [String] = []
        let maxHires = bot.flags.contains("cautious") ? 1 : max(2, s.employees.count / 4)
        for _ in 0..<maxHires {
            guard s.employees.count < Economy.officeCapacity(s) else { break }
            let payroll = Economy.payrollYear(s)
            let allowance = max(0.25 * s.cash, 0.35 * Economy.runRate(s))
            let n = Double(s.employees.count + 1)
            var role = Role.researcher, deficit = -Double.infinity
            for (r, f) in roleMix {
                let have = Double(s.employees.filter { $0.role == r }.count)
                if f * n - have > deficit { deficit = f * n - have; role = r }
            }
            let pool = s.candidates.filter { $0.role == role && payroll + $0.salary <= allowance && $0.salary * 0.15 < s.cash * 0.02 }
            guard let c = pool.max(by: { $0.skill / pow($0.salary, 0.5) < $1.skill / pow($1.salary, 0.5) }) else { break }
            if s.hire(c.id) == nil { hired.append("\(c.role.rawValue) \(Int(c.skill))") }
        }
        if !hired.isEmpty {
            bot.actions += 1
            bot.events.append("hired \(hired.count)")
        }
    }

    static let perkOrder = ["r1", "c1", "p1", "r2", "p2", "c2", "f1", "r3", "p3", "c3", "r4", "p4", "c4", "f2", "f3", "f4", "s1", "s2", "s3", "s4"]

    static func perks(_ s: inout GameState) {
        for id in perkOrder where !s.perks.contains(id) {
            guard let p = CultureCatalog.byID[id], p.cost <= s.culturePoints else { continue }
            _ = s.adoptPerk(id)
        }
    }

    static func data(_ s: inout GameState, _ b: ResearchBonuses) {
        let rr = Economy.runRate(s)
        func add(_ id: String) {
            guard !s.dataSources.contains(id), let src = DataCatalog.byID[id], s.year >= src.available else { return }
            _ = s.toggleData(id)
        }
        if b.has(.rlhf) && (s.cash > 3e7 || rr > 1.2e7) { add("human_feedback") }
        if rr > 2e8 { for id in ["forum_license", "code_license", "science_license", "news_license"] { add(id) } }
        if s.cash > 4e8 { add("books_license") }
        if rr > 1e9 { add("expert_data") }
    }

    static func security(_ s: inout GameState, _ bot: inout PTBot) {
        guard SecurityOps.attractiveness(s) >= 1.0, s.security < .sl3, s.securityTarget <= s.security.rawValue,
              let next = SecurityLevel(rawValue: s.security.rawValue + 1), SecurityOps.upgradeCost(next, s) < s.cash * 0.05 else { return }
        if s.upgradeSecurity() == nil { bot.actions += 1; bot.events.append("security → \(next.title)") }
    }

    /// Garage GPUs go to the research lab once the quick model is done; later, rent a little research compute
    /// (about 3% of run-rate) — the Research page's "research compute" slider.
    static func researchCompute(_ s: inout GameState, _ bot: inout PTBot) {
        for p in Economy.pools(s) where p.owned > 0 && p.free > 0 && p.rented == 0 && !bot.flags.contains("norent") {
            s.researchChips[p.accel.id, default: 0] += p.free
        }
        guard !bot.flags.contains("noresearchcompute"), !bot.flags.contains("cautious"), !bot.flags.contains("norent") else { return }
        let rr = Economy.runRate(s)
        guard rr > 5e6 else { return }
        // Cheapest bf16 per dollar.
        var best: (Accelerator, Double)? = nil
        for a in HardwareCatalog.all where (a.cls == .datacenter || a.cls == .tpu) && Economy.canRent(a, s) && Partners.blocker(a, s) == nil {
            guard let rate = Economy.rent(a, s), rate > 0 else { continue }
            let v = a.bf16 / rate
            if best == nil || v > best!.1 { best = (a, v) }
        }
        guard let (a, _) = best, let rate = Economy.rent(a, s) else { return }
        let budgetChips = Int(rr * 0.03 / (rate * 24 * 365))
        let pfFor10 = pow(10.0 / 4, 1 / 0.45)                        // computeRP = 10 → research ×2
        let want = min(budgetChips, Int(ceil(pfFor10 * 1000 / a.bf16)))
        let current = s.researchChips.filter { HardwareCatalog.get($0.key).map { $0.cls == .datacenter || $0.cls == .tpu } ?? false }.values.reduce(0, +)
        guard want > current + max(1, current / 5) else { return }
        // Move research to the new chip type.
        for (id, _) in s.researchChips where id != a.id && (HardwareCatalog.get(id).map { $0.cls == .datacenter || $0.cls == .tpu } ?? false) {
            s.researchChips[id] = 0
        }
        let have = ensureFree(&s, &bot, a.id, want)
        s.researchChips[a.id] = min(want, have)
        bot.actions += 1
        bot.events.append("research compute \(min(want, have))× \(a.id)")
    }

    // MARK: Probe: Model Lab estimate vs. what actually happens on big clusters

    static func probe() {
        print("== Estimate vs actual progress on big clusters (60 days, decisions auto-resolved) ==")
        print("year   chip        chips    est goodput  est days  actual %/60d  expected %/60d  ratio")
        for (era, y, mo, accel) in [("2017", 2019, 6, "v100_32"), ("2017", 2021, 6, "a100_40"), ("2022", 2023, 6, "h100_sxm"), ("2022", 2024, 9, "h100_sxm"), ("2022", 2026, 6, "gb200")] {
            var base = NewGame.create(NewGameSettings(companyName: "Probe", founderName: "Bot", eraID: era, difficulty: .normal), seed: 9)
            base.date = GameCalendar.date(y, mo, 1)
            base.researched = Set(ResearchCatalog.core.filter { $0.year <= base.year && $0.category != .frontier }.map(\.id))
            base.cash = 1e13
            base.valuation = 1e13
            base.decisions = []
            guard let a = HardwareCatalog.get(accel), Economy.canRent(a, base) else { print("  \(accel) not rentable in \(y)"); continue }
            for chips in [2_000, 10_000, 30_000, 100_000, 300_000] {
                var s = base
                var bot = PTBot()
                guard s.rentHardware(accel, count: chips, term: .onDemand) == nil else { print("  rent failed"); continue }
                let dz = design(s, a, chips: chips, days: 80, name: "Probe", b: s.bonuses)
                guard let est = Physics.estimate(dz, state: s) else { continue }
                if let e = s.startTraining(dz) { print("  start: \(e)"); continue }
                for _ in 0..<60 {
                    Sim.advanceDay(&s)
                    resolve(&s, &bot)
                    s.gameOver = nil
                }
                let r = s.runs.last!
                let got = r.status == .postTraining || r.status == .done ? 1.0 : r.progress
                let expect = min(1, 60 / est.days * (1 + est.postFlops / est.flops))
                print(String(format: "%d  %-10@ %8d  %10.1f%%  %8.0f  %11.1f%%  %13.1f%%  %5.2f", y, accel as NSString, chips, est.goodput * 100, est.days,
                             got * 100, expect * 100, got / max(1e-9, expect)))
            }
        }
    }

    // MARK: Sanity checks

    static func check(_ s: GameState, _ out: inout [String: String]) {
        func flag(_ what: String) { if out[what] == nil { out[what] = s.date.gameShort } }
        if !s.cash.isFinite { flag("cash not finite") }
        if !s.valuation.isFinite || s.valuation < 0 { flag("valuation invalid") }
        if !s.brand.isFinite || s.brand < 0 || s.brand > 100 { flag("brand out of range") }
        if !s.reliability.isFinite || s.reliability < 0 || s.reliability > 1 { flag("reliability out of range") }
        if !s.consumerUsers.isFinite || s.consumerUsers < 0 { flag("users invalid") }
        if s.paidUsers > s.consumerUsers + 1 { flag("paid users > users") }
        if s.consumerUsers > 8.5e9 { flag("users > world population") }
        if !s.rpToday.isFinite || s.rpToday < 0 { flag("RP invalid") }
        if !s.safetyScore.isFinite || !s.boardConfidence.isFinite { flag("safety/board invalid") }
        if !s.market.hype.isFinite || s.market.hype <= 0 { flag("hype invalid") }
        if s.cloudCredits < -1 { flag("negative cloud credits") }
        if s.owned.contains(where: { $0.count < 0 }) || s.rentals.contains(where: { $0.count <= 0 }) { flag("negative chip counts") }
        for md in s.models {
            if !md.c.isFinite || !md.index.isFinite { flag("model c/index NaN") }
            if md.index > 100 || md.index < 0 { flag("model index outside 0–100") }
            if !md.apiPrice.isFinite || md.apiPrice <= 0 { flag("API price invalid") }
            if !md.revenueDay.isFinite || md.revenueDay < 0 || !md.demandTokensDay.isFinite { flag("model revenue/demand invalid") }
            if md.released && md.apiPrice < 0.0015 { flag("API price at floor ($0.001/M)") }
        }
        for c in s.competitors {
            if !c.valuation.isFinite || c.valuation < 0 { flag("rival valuation invalid (\(c.id))") }
            if !c.cash.isFinite { flag("rival cash NaN (\(c.id))") }
            if c.models.contains(where: { !$0.c.isFinite || !$0.index.isFinite }) { flag("rival model NaN (\(c.id))") }
        }
        for e in s.employees where !e.morale.isFinite || !e.salary.isFinite || e.salary <= 0 { flag("employee invalid"); break }
        for r in s.runs where !r.flopsDone.isFinite || r.flopsDone < 0 { flag("run flops invalid"); break }
        if s.isPublic && (!s.sharePrice.isFinite || s.sharePrice <= 0) { flag("share price invalid") }
        if let h = s.history.last, h.revenue * 12 > Macro.marketSize(s.year) * 1.5 { flag("player revenue > 1.5× whole AI market") }
        if s.valuation > 1e14 { flag("valuation > $100T") }
    }

    // MARK: Output

    static func printGame(_ rows: [PTRow], _ sum: PTSummary, _ bot: PTBot, _ s: GameState, mode: String) {
        print("month     cash      rev/mo    profit/mo  val       chips  bestC  gap   idx  #  top-rival idx  users   staff res  RP/d  dec news imp idle training")
        for (i, r) in rows.enumerated() where mode == "full" || i % 3 == 0 || i == rows.count - 1 || !r.events.isEmpty && mode == "events" {
            let line = String(format: "%-9@ %-9@ %-9@ %-10@ %-9@ %6d %5.2f %5.2f %4.1f %2d %-14@ %-7@ %4d %4d %5.1f %3d %4d %3d %3d %@",
                              r.label as NSString, m(r.cash) as NSString, m(r.revenue) as NSString, m(r.profit) as NSString, m(r.valuation) as NSString,
                              r.chips, r.bestC, r.gap, r.bestIdx, r.rank, String(format: "%.1f", r.topIdx) as NSString,
                              Fmt.count(r.users) as NSString, r.employees, r.researched, r.rp, r.decisions, r.worldNews, r.important, r.idleDays, r.training as NSString)
            print(line)
        }
        for r in rows {
            print(String(format: "CSV,%@,%@,%d,%.4f,%.6g,%.6g,%.6g,%.6g,%.6g,%d,%.3f,%.3f,%.2f,%d,%.2f,%.6g,%d,%d,%.2f,%d,%d,%d,%d,%d,%.4f,%.4f,%.1f,%.1f",
                         sum.era as NSString, String(sum.seed) as NSString, rows.firstIndex { $0.label == r.label } ?? 0, r.year, r.cash, r.revenue, r.opProfit, r.runRate, r.valuation,
                         r.chips, r.bestC, r.gap, r.bestIdx, r.rank, r.topIdx, r.users, r.employees, r.researched, r.rp, r.decisions, r.worldNews, r.important,
                         r.actions, r.idleDays, r.apiShare, r.marketShare, r.brand, r.board))
        }
        print("\nEvents:")
        for r in rows where !r.events.isEmpty || r.decisions > 0 {
            let k = r.kinds.sorted { $0.value > $1.value }.map { "\($0.key)×\($0.value)" }.joined(separator: " ")
            print("  \(r.label): \(r.events.joined(separator: "; "))\(k.isEmpty ? "" : " | decisions: \(k)")")
        }
        print("\nRuns:")
        for r in sum.runs {
            let dur = r.end.map { d(r.start, $0) } ?? -1
            print(String(format: "  %-9@ %@ %5d× %-12@ %8@ (%@ act) %7@ tok · fc c %5.2f → c %5.2f (%+.2f) · front %5.2f→%5.2f · idx %4.1f #%d · %3dd (plan %3.0fd, after start %3.0fd) · est %@ %@",
                         r.name as NSString, r.start.gameShort as NSString, r.chips, r.accel as NSString, Fmt.params(r.paramsB) as NSString,
                         Fmt.params(r.activeB) as NSString, Fmt.tokens(r.tokensT) as NSString, r.forecastC, r.c, r.c - r.forecastC,
                         r.frontierAtStart, r.frontierAtEnd, r.index, r.rank, dur, r.planDays, r.estDays, m(r.estCost) as NSString,
                         r.end != nil && !r.released ? "(shelved)" : (r.end == nil ? "(still training)" : "")))
        }
        if !bot.log.isEmpty { print("Bot log: " + bot.log.prefix(8).joined(separator: " | ")) }
        printSummary(sum)
    }

    static func ds(_ v: Int?) -> String { v.map { "\($0)d (\(Fmt.trim(Double($0) / 30.44, 1)) mo)" } ?? "never" }

    static func printSummary(_ sum: PTSummary) {
        print("\nSummary \(sum.era)/\(sum.seed): \(sum.months) months\(sum.gameOver.map { " · GAME OVER: \($0)" } ?? "")")
        print("  first run day \(sum.firstRun.map(String.init) ?? "-") · first model \(ds(sum.firstModel)) · first revenue \(ds(sum.firstRevenue)) · first $1M month \(ds(sum.firstMillionMonth)) · first profitable month \(ds(sum.firstProfit))")
        print("  rank: top-10 \(ds(sum.firstTop10)) · top-3 \(ds(sum.firstTop3)) · #1 \(ds(sum.firstNo1)) · months at #1: \(sum.monthsNo1)")
        print("  min cash \(m(sum.minCash)) (\(sum.minCashLabel)) · days cash<0: \(sum.daysNegative) · raises \(sum.raises) for \(m(sum.raised)) · lowball term sheets declined \(sum.lowballs) · acquisition offers \(sum.acqOffers) (best \(m(sum.acqBest)))")
        print("  bot actions/mo \(Fmt.trim(sum.actionsAvg, 1)) · days/mo with nothing to do \(Fmt.trim(sum.idleAvg, 1)) · candidate designs skipped for goodput<60%: \(sum.lowGoodputSkips) · stalled runs cancelled: \(sum.cancelledStalls) · days waiting because nothing beats current model: \(sum.ceilingDays)")
        print("  valuation month-on-month: max jump ×\(Fmt.trim(sum.maxValJump, 1)), max drop \(Fmt.pct(sum.maxValDrop, decimals: 0)) · peak fleet \(sum.maxChips) chips (\(sum.maxChipsWhat))")
        for n in sum.notes.prefix(12) { print("  note: \(n)") }
        let top = sum.kinds.sorted { $0.value > $1.value }.prefix(10).map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        print("  decisions: \(sum.decisionsTotal) (\(Fmt.trim(Double(sum.decisionsTotal) / Double(max(1, sum.months)), 2))/mo, max \(sum.decisionMax) in \(sum.decisionMaxLabel)) · \(top)")
        print("  world news/mo avg \(Fmt.trim(sum.newsAvg, 1)) max \(sum.newsMax) · important/mo \(Fmt.trim(sum.importantAvg, 1)) · quiet months \(sum.quietMonths) (longest streak \(sum.longestQuiet) from \(sum.longestQuietFrom))")
        print("  research/yr \(Fmt.trim(sum.researchPerYear, 1)) · idle share of rented chip-days \(Fmt.pct(sum.idleRentFrac)) · rental-cap hits \(sum.rentalCapHits) · days with no main run \(sum.waitDays) · paused-run days \(sum.stalledDays)")
        let e = sum.end
        print("  end: cash \(m(e.cash)) rev/mo \(m(e.revenue)) val \(m(e.valuation)) chips \(e.chips) gap \(Fmt.trim(e.gap, 2)) rank #\(e.rank) users \(Fmt.count(e.users)) staff \(e.employees) stake \(Fmt.pct(e.stake)) API share \(Fmt.pct(e.apiShare)) of-market \(Fmt.pct(e.marketShare))")
        if !sum.anomalies.isEmpty { print("  ANOMALIES: " + sum.anomalies.joined(separator: "; ")) }
    }

    static func aggregate(_ all: [PTSummary], era: String) {
        guard all.count > 1 else { return }
        print("\n================ \(era) aggregate over \(all.count) seeds ================")
        func avg(_ xs: [Int?]) -> String {
            let v = xs.compactMap { $0 }
            return v.isEmpty ? "never" : "\(Fmt.trim(Double(v.reduce(0, +)) / Double(v.count) / 30.44, 1)) mo (\(v.count)/\(xs.count))"
        }
        print("  first revenue \(avg(all.map(\.firstRevenue))) · first $1M month \(avg(all.map(\.firstMillionMonth))) · first profit \(avg(all.map(\.firstProfit)))")
        print("  top-10 \(avg(all.map(\.firstTop10))) · top-3 \(avg(all.map(\.firstTop3))) · #1 \(avg(all.map(\.firstNo1))) · months at #1 \(all.map(\.monthsNo1))")
        print("  decisions/mo \(all.map { Fmt.trim(Double($0.decisionsTotal) / Double(max(1, $0.months)), 2) }) · max/mo \(all.map(\.decisionMax)) · quiet months \(all.map(\.quietMonths)) · game over \(all.map { $0.gameOver == nil ? "no" : "YES" })")
        var kinds: [String: Int] = [:]
        for s in all { for (k, v) in s.kinds { kinds[k, default: 0] += v } }
        print("  decision kinds: " + kinds.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
        print("  end valuations \(all.map { m($0.end.valuation) }) · end rev/mo \(all.map { m($0.end.revenue) }) · end rank \(all.map(\.end.rank))")
    }
}
