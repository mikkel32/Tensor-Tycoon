import Foundation

/// The life of a training run: pre-training, hardware failures, loss spikes, forecast tracking,
/// silent bugs, mid-run decisions and staged post-training.
enum Training {
    /// Llama 3 405B: 419 unexpected interruptions in 54 days on 16,384 H100s.
    static let failuresPerChipDay = 419.0 / (54 * 16_384)

    // MARK: Stages

    static func stages(_ d: ModelDesign, pretrain: Double, bonuses b: ResearchBonuses) -> [RunStage] {
        var out: [RunStage] = []
        let annealing = d.anneal && b.has(.curriculum) && d.mode == .scratch
        let preName = d.mode == .scratch ? "Pre-training" : (d.mode == .finetune ? "Fine-tuning" : "Distillation")
        out.append(RunStage(name: preName, flops: pretrain * (annealing ? 0.92 : 1), isPre: true))
        if annealing { out.append(RunStage(name: d.schedule == .wsd ? "Decay & anneal" : "Annealing", flops: pretrain * 0.08, isPre: true)) }
        let base = d.mode == .scratch ? pretrain : max(pretrain, 1e21)
        let cut = 1 - b.postTrainCost
        func add(_ name: String, _ share: Double) {
            out.append(RunStage(name: name, flops: max(1e17, base * share), isPre: false))
        }
        add(d.instruct ? "SFT" : "Base-model evals", (d.instruct ? 0.004 : 0.002) * cut)
        if d.rlhf { add(d.useDPO ? "DPO" : "RLHF", 0.02 * (d.useDPO ? 0.4 : 1) * cut) }
        if d.vision || d.audio { add("Multimodal", 0.03 * cut) }
        if d.video { add("Video", 0.08 * cut) }
        if d.toolUse { add(d.agentRL && b.has(.agents) ? "Agentic RL" : "Tool use", (d.agentRL ? 0.06 : 0.02) * cut) }
        if d.reasoning && b.has(.reasoning) { add("Reasoning RL", d.effectiveRL.share * (1 - b.rlEfficiency)) }
        if d.safetyTraining { add("Safety & red-teaming", 0.01 * cut) }
        return out
    }

    static func currentStageName(_ run: TrainingRun) -> String {
        guard !run.stages.isEmpty else { return run.status == .postTraining ? "Post-training" : "Pre-training" }
        if run.status != .postTraining {
            let pre = run.stages.filter(\.isPre)
            if pre.count > 1, run.progress > pre[0].flops / max(run.flopsTotal, 1) { return pre[1].name }
            return pre.first?.name ?? "Pre-training"
        }
        return run.stages[min(run.stageIndex, run.stages.count - 1)].name
    }

    // MARK: Start

    /// Fills in the forecast and the hidden truth of a new run.
    static func prepare(_ run: inout TrainingRun, state s: inout GameState) {
        let b = s.bonuses
        let d = run.design
        let f = ForecastEngine.forecast(d, state: s, dataSources: Array(s.dataSources))
        let set = Leaderboard.indexSet(s)
        let band = ForecastEngine.indexBand(f, design: d, set: set)
        let released = Leaderboard.entries(s, set: set, includeUnreleased: false)
        let top = released.filter { !$0.isPlayer }.map(\.index).max() ?? 0
        run.forecast = RunForecast(c: f.c, sigma: f.sigma, index: band.mean, indexLow: band.low, indexHigh: band.high,
                                   tier: ForecastEngine.tier(index: band.mean, top: top),
                                   comparable: RealModels.closest(index: band.mean, set: set).map { "\($0.name) (\($0.lab), \($0.date.label))" } ?? "—",
                                   finalLoss: f.finalLoss)
        // Experiments (estimated under `toyCost`) run quietly: no incidents, so no silent bug either.
        if run.kind == .full, let est = Physics.estimate(d, state: s, lr: run.schedule, interval: run.interval) {
            run.toy = est.toy
            // 3.5: what the estimate promised, for the command centre and the results screen.
            run.plan = TrainingExperience.plan(run, est: est, expectedRank: Leaderboard.labRank(index: band.mean, board: released, gone: Leaderboard.goneLabs(s)), state: s)
        }
        run.epsilon = s.rng.gaussian() * f.sigma
        if s.rng.chance(f.bugRisk * (1 - 0.4 * s.swarmOps)) {
            let penalty = s.rng.range(0.08, 0.32)
            let onset = s.rng.range(0.08, 0.6)
            if !run.toy {
                run.bugPenalty = penalty
                run.bugOnset = onset
            }
        }
        run.revealSigma = f.sigma
        run.stages = stages(d, pretrain: run.flopsTotal, bonuses: b)
        run.postTrainFlops = run.stages.filter { !$0.isPre }.reduce(0) { $0 + $1.flops }
        runLogDirect(&run, s.date, "Forecast: index \(Fmt.score(band.mean)) (80%: \(Fmt.score(band.low))–\(Fmt.score(band.high))) — \(run.forecast?.tier ?? "").")
        TrainingExperience.launched(&s, run: run)
    }

    // MARK: Ops coverage

    static func isLive(_ r: TrainingRun) -> Bool { r.status == .running || r.status == .postTraining }

    /// Researcher-equivalents of training-ops agents watching this run: swarms pinned to it, plus its share
    /// (by chips) of the swarms that watch every run.
    static func opsAgents(_ s: GameState, _ run: TrainingRun) -> Double {
        var pinned = 0.0, shared = 0.0
        for sw in s.swarms where !sw.paused && sw.mission == .trainingOps {
            if let t = sw.targetRunID, s.runs.contains(where: { $0.id == t && isLive($0) }) {
                if t == run.id { pinned += sw.workforce }
            } else {
                shared += sw.workforce
            }
        }
        let total = s.runs.filter { isLive($0) && $0.kind == .full }.reduce(0) { $0 + $1.design.chips }
        return pinned + (total > 0 ? shared * Double(run.design.chips) / Double(total) : 0)
    }

    /// Coverage a new run of `chips` would get from the training-ops swarms that watch every run.
    static func plannedCoverage(_ s: GameState, chips: Int) -> Double {
        var shared = 0.0
        for sw in s.swarms where !sw.paused && sw.mission == .trainingOps {
            if let t = sw.targetRunID, s.runs.contains(where: { $0.id == t && isLive($0) }) { continue }
            shared += sw.workforce
        }
        let busy = s.runs.filter { isLive($0) && $0.kind == .full }.reduce(0) { $0 + $1.design.chips }
        let share = shared * Double(chips) / Double(max(1, busy + chips))
        return clamp(share / opsNeeded(chips: chips), 0, 1)
    }

    /// Engineer-equivalents a run needs for full coverage: one per 600 chips.
    static func opsNeeded(chips: Int) -> Double { max(0.5, Double(chips) / 600) }

    /// Share of a run's chips that agents watch (0–1).
    static func coverage(_ s: GameState, _ run: TrainingRun) -> Double {
        clamp(opsAgents(s, run) / opsNeeded(chips: run.design.chips), 0, 1)
    }

    /// What full coverage buys: failures predicted and drained before they crash the job, restarts from
    /// in-memory snapshots in seconds, silent corruption caught, stragglers evicted.
    struct OpsEffect {
        var prevented: Double
        var recovery: Double
        var sdcCaught: Double
        var stragglers: Double
        var spikes: Double
    }

    static func opsEffect(_ cov: Double, _ s: GameState) -> OpsEffect {
        OpsEffect(prevented: 0.75 * cov, recovery: 0.85 * cov,
                  sdcCaught: min(0.98, 0.3 + (s.researched.contains("sdc_detection") ? 0.2 : 0) + 0.6 * cov),
                  stragglers: 0.7 * cov, spikes: 0.4 * cov)
    }

    /// Silent data corruption: about 1.4% of hardware faults don't crash anything — they quietly poison gradients.
    static let sdcShare = 0.014
    /// Capability lost per corruption nobody catches (log10 effective compute).
    static let sdcPenalty = 0.0012

    // MARK: Goodput

    /// Expected share of a day that makes progress when the day's failures are drawn like `poisson(lambda)` and each
    /// costs `hours`: E[max(0, 1 − k·hours/24)]. Exact for the draws the daily simulation makes (Poisson up to λ = 25,
    /// a rounded normal above), so estimates and runs agree even when failures eat whole days. The old linear
    /// expectation (1 − λ·hours/24, floored at 1%) was too pessimistic near the cliff and far too optimistic past it.
    static func expectedUptime(lambda: Double, hours: Double) -> Double {
        guard lambda > 0, hours > 0 else { return 1 }
        let kMax = 24 / hours                                    // failures one day can absorb
        var sum = 0.0
        if lambda <= 25 {
            var p = exp(-lambda)
            var k = 0
            while Double(k) <= kMax && k < 200 {
                sum += p * (1 - Double(k) * hours / 24)
                k += 1
                p *= lambda / Double(k)
            }
        } else {
            let sd = lambda.squareRoot()
            func cdf(_ x: Double) -> Double { 0.5 * erfc(-x / 2.0.squareRoot()) }
            let lo = max(0, Int((lambda - 10 * sd).rounded(.down)))
            let hi = min(Int(kMax.rounded(.down)), Int((lambda + 10 * sd).rounded(.up)))
            guard lo <= hi else { return 0 }
            for k in lo...hi {
                let mass = cdf((Double(k) + 0.5 - lambda) / sd) - (k == 0 ? 0 : cdf((Double(k) - 0.5 - lambda) / sd))
                sum += mass * (1 - Double(k) * hours / 24)
            }
        }
        return clamp(sum, 0, 1)
    }

    /// Expected share of wall-clock time that makes progress on a run of `chips` with ops coverage `cov`: the
    /// failure expectation the daily step draws from, times straggler losses. It can be zero. `infra` overrides the
    /// infra team (for "if you hired…" advice).
    static func goodput(chips: Int, coverage cov: Double, state s: GameState, bonuses b: ResearchBonuses, infra: Double? = nil) -> Double {
        let e = opsEffect(cov, s)
        let lambda = Double(chips) * failuresPerChipDay * (1 - e.prevented)
        let hours = Physics.hoursLostPerFailure(state: s, bonuses: b, chips: chips, infra: infra) * (1 - e.recovery)
        let strag = 1 - (1 - Physics.stragglerFactor(chips: chips, bonuses: b)) * (1 - e.stragglers)
        return clamp(expectedUptime(lambda: lambda, hours: hours) * strag, 0, 0.998)
    }

    /// Below this expected goodput a run effectively never finishes (it only moves on the odd lucky day).
    static let stallGoodput = 0.01
    /// Below this expected goodput the Model Lab won't start a run: most of the money would buy restarts.
    static let goodputFloor = 0.3
    /// Below this the Model Lab warns, and auto-size shrinks the cluster to stay above it.
    static let goodputTarget = 0.6

    /// Largest cluster, up to `chips`, whose expected goodput stays at or above `target` with today's team, ops swarms
    /// and research, rounded down to two significant figures. `coverage` fixes the ops coverage (a running run);
    /// by default it's what unpinned training-ops swarms would give a new run of each size.
    static func healthyChips(_ chips: Int, target: Double, state s: GameState, bonuses b: ResearchBonuses, coverage: Double? = nil) -> Int {
        func g(_ n: Int) -> Double { goodput(chips: n, coverage: coverage ?? plannedCoverage(s, chips: n), state: s, bonuses: b) }
        guard chips > 1, g(chips) < target else { return chips }
        var lo = 1, hi = chips
        while hi - lo > 1 {
            let mid = lo + (hi - lo) / 2
            if g(mid) >= target { lo = mid } else { hi = mid }
        }
        let step = pow(10, floor(log10(Double(lo))) - 1)
        return max(1, Int((Double(lo) / step).rounded(.down) * step))
    }

    /// Your model that makes the best training-ops agent.
    static func bestOpsModel(_ s: GameState) -> AIModel? {
        s.models.filter { !$0.retired }.max { Swarms.quality($0, s, mission: .trainingOps) < Swarms.quality($1, s, mission: .trainingOps) }
    }

    /// Why a run this size loses its time to hardware failures, and what would fix it (each fix with the goodput it
    /// reaches). Nil when expected goodput is healthy (at or above `goodputTarget`).
    struct GoodputAdvice {
        var goodput: Double
        /// Below `goodputFloor`: the Model Lab won't start it.
        var blocked: Bool
        var headline: String
        var fixes: [String]
        /// Largest cluster that keeps goodput at `goodputTarget` as things stand.
        var healthyChips: Int
    }

    static func goodputAdvice(chips: Int, coverage cov: Double, running: Bool, state s: GameState, bonuses b: ResearchBonuses) -> GoodputAdvice? {
        let g = goodput(chips: chips, coverage: cov, state: s, bonuses: b)
        guard g < goodputTarget else { return nil }
        let e = opsEffect(cov, s)
        let lambda = Double(chips) * failuresPerChipDay * (1 - e.prevented)
        let hours = Physics.hoursLostPerFailure(state: s, bonuses: b, chips: chips) * (1 - e.recovery)
        let minutes = 1_440 / max(lambda, 1e-9)
        let every = minutes < 1 ? "\(max(1, Int((minutes * 60).rounded()))) seconds"
            : (minutes < 90 ? "\(Int(minutes.rounded())) minutes" : "\(Fmt.trim(minutes / 60, 1)) hours")
        let cause = "At \(Fmt.int(chips)) chips a hardware fault hits every \(every) and each costs \(Fmt.trim(hours, 2)) h to recover from"
        let headline = g < stallGoodput
            ? "\(cause): about \(Fmt.int(Int((lambda * hours).rounded()))) hours lost per day, so the run can't make progress."
            : "\(cause): failures and stragglers eat \(Fmt.pct(1 - g, decimals: 0)) of its time."
        var fixes: [String] = []
        // Ops agents: the way to make a 500K-chip run work.
        if cov < 0.95 {
            let full = goodput(chips: chips, coverage: 1, state: s, bonuses: b)
            if full - g > 0.03 {
                var line = running ? "Point training-ops agents at it (Assign agents on its run card)"
                                   : "Start a training-ops swarm that watches all runs (Agent Swarms) before you launch"
                line += ": full coverage gets it to \(Fmt.pct(full, decimals: 0))"
                if let m = bestOpsModel(s) {
                    let n = agentsForCoverage(m, chips: chips, s, b)
                    line += n >= Swarms.maxAgents ? ", but \(m.name) isn't capable enough to run ops yet" : " with about \(Fmt.int(n)) agents of \(m.name)"
                } else {
                    line += " (agents are copies of one of your models)"
                }
                fixes.append(line + ".")
            }
        }
        // Infra engineers: one per 600 chips of the biggest run.
        let need = opsNeeded(chips: Physics.staffedChips(s, planned: chips))
        let have = Physics.infraWeight(s)
        if have < need * 0.95 {
            let staffed = goodput(chips: chips, coverage: cov, state: s, bonuses: b, infra: need)
            if staffed - g > 0.02 {
                fixes.append("Hire infra engineers: a run this size wants about \(Fmt.int(Int(need.rounded(.up)))) (one per 600 chips) and you have \(Fmt.trim(have, 1)); fully staffed it reaches \(Fmt.pct(staffed, decimals: 0)).")
            }
        }
        // Fault-tolerance research (async checkpointing first).
        for (id, cut) in [("checkpointing", 0.70), ("elastic", 0.50), ("optical_switching", 0.10)] where !s.researched.contains(id) {
            guard let item = ResearchCatalog.byID[id] else { continue }
            var better = b
            better.failureKeep *= 1 - cut
            let gr = goodput(chips: chips, coverage: cov, state: s, bonuses: better)
            if gr - g > 0.02 {
                fixes.append("Research \(item.name) (−\(Int(cut * 100))% time lost per failure): \(Fmt.pct(gr, decimals: 0)).")
                break
            }
        }
        // Or simply fewer chips.
        let healthy = healthyChips(chips, target: goodputTarget, state: s, bonuses: b, coverage: running ? cov : nil)
        if healthy < chips {
            fixes.append(running ? "Shrink it to \(Fmt.int(healthy)) chips (Resize cluster) to get back above \(Fmt.pct(goodputTarget, decimals: 0))."
                                 : "Use at most \(Fmt.int(healthy)) chips to stay above \(Fmt.pct(goodputTarget, decimals: 0)).")
        }
        return GoodputAdvice(goodput: g, blocked: g < goodputFloor, headline: headline, fixes: fixes, healthyChips: healthy)
    }

    // MARK: Incidents

    /// Runs estimated under this at launch are experiments: hardware still fails and restarts, but nothing pops up
    /// mid-run (silent bugs, loss spikes, contamination audits, fault storms, sycophancy, reward hacking). The first
    /// garage run costs a few hundred dollars; the cheapest serious run of the 2017 era already costs six figures.
    static let toyCost = 50_000.0

    static func isToy(cost: Double) -> Bool { cost < toyCost }

    /// Expected days a run loses to incidents when each is answered the careful way. Part of every estimate, so plans
    /// aren't optimistic: loss spikes (the day plus, on average, half a checkpoint interval of pre-training; the
    /// rollback also switches to a conservative learning rate, a third of the spikes and 2% slower; ops agents catch
    /// spikes within minutes instead), fault storms (the day plus two days of raw throughput to swap nodes),
    /// contamination scrubs (a 5% rewind) and post-training stages redone after sycophancy or reward hacking.
    static func incidentDays(_ d: ModelDesign, pretrain pre: Double, perDay: Double, goodput g: Double, interval: Double, lr: LRSchedule,
                             coverage cov: Double, state s: GameState, bonuses b: ResearchBonuses) -> Double {
        guard perDay > 0, pre > 0 else { return 0 }
        let plan = stages(d, pretrain: pre, bonuses: b)
        let preDays = pre / perDay
        let totalDays = plan.reduce(0) { $0 + $1.flops } / perDay
        let ops = opsEffect(cov, s)
        let t = preDays * 0.97
        let r = spikeChance(d, lr: lr, state: s, bonuses: b) * (1 - ops.spikes) * t
        var days = 0.0
        if cov >= 0.5 {
            days += r * 0.02
        } else if r > 0 {
            var spikes = r, slow = 0.0
            if lr != .conservative {
                let first = 1 - exp(-r)
                spikes = first + 0.35 * (r - first)
                slow = 0.02 * t * (r - first) / r
            }
            days += spikes * (1 + interval / 2 * preDays) + slow
        }
        if d.chips >= 4_000 {
            // Two raw days of throughput, but never more than the progress made by then (storms strike uniformly).
            let swap = 2 / max(g, stallGoodput)
            let lost = swap < totalDays ? swap - swap * swap / (2 * totalDays) : totalDays / 2
            days += (1 - pow(1 - 0.0025 * (1 - 0.6 * cov), totalDays)) * (1 + lost)
        }
        days += (1 - pow(1 - 0.012 * b.contaminationKeep, 0.45 * preDays)) * 0.05 * preDays
        for st in plan where !st.isPre {
            if st.name == "RLHF" || st.name == "DPO" { days += sycophancyRisk(s) * st.flops / perDay }
            if st.name == "Reasoning RL" { days += rewardHackRisk(d, s) * st.flops / perDay }
        }
        return days
    }

    /// Chance that preference tuning produces a flatterer, for runs big enough to have incidents.
    static func sycophancyRisk(_ s: GameState) -> Double {
        s.signatureAt(.lodestar, 3) ? 0 : 0.15 * (s.researched.contains("anti_sycophancy") ? 0.2 : 1)
    }

    /// Chance that reasoning RL learns to game its graders. Heavier RL hacks more.
    static func rewardHackRisk(_ d: ModelDesign, _ s: GameState) -> Double {
        guard !s.signatureAt(.lodestar, 3) else { return 0 }
        let rl: Double
        switch d.effectiveRL {
        case .off, .light: rl = 0.6
        case .standard: rl = 1
        case .heavy: rl = 1.3
        case .extreme: rl = 1.6
        }
        return 0.16 * rl * (s.researched.contains("cot_monitoring") ? 0.35 : 1) * (s.researched.contains("verifiers") ? 0.7 : 1)
    }

    /// The post-training risks of a design and the research that prevents them, for the Model Lab.
    static func postTrainingRisks(_ d: ModelDesign, toy: Bool, state s: GameState) -> [String] {
        guard !toy else { return [] }
        let b = s.bonuses
        var out: [String] = []
        if d.rlhf && b.has(.rlhf) {
            let p = sycophancyRisk(s)
            if p > 0 {
                out.append("\(Int((p * 100).rounded()))% chance preference tuning makes it a flatterer"
                           + (s.researched.contains("anti_sycophancy") ? " (Anti-Sycophancy Training already cut it 5×)." : ". Anti-Sycophancy Training research cuts that 5×."))
            }
        }
        if d.reasoning && b.has(.reasoning) {
            let p = rewardHackRisk(d, s)
            if p > 0 {
                var missing: [String] = []
                if !s.researched.contains("cot_monitoring") { missing.append("Chain-of-Thought Monitoring (÷3)") }
                if !s.researched.contains("verifiers") { missing.append("Verifiable Environments at Scale (−30%)") }
                out.append("\(Int((p * 100).rounded()))% chance reasoning RL learns to game its graders"
                           + (missing.isEmpty ? "." : ". Research \(missing.joined(separator: " and ")) to cut it."))
            }
        }
        return out
    }

    /// Agents a swarm of model `m` needs for full coverage of `chips` (no oversight, semi-autonomous).
    static func agentsForCoverage(_ m: AIModel, chips: Int, _ s: GameState, _ b: ResearchBonuses) -> Int {
        let q = Swarms.quality(m, s, mission: .trainingOps)
        guard q > 0 else { return Swarms.maxAgents }
        let n = (pow(opsNeeded(chips: chips) / q, 1 / Swarms.coordination(b, s)) / Swarms.autonomyOutput[1]).rounded(.up)
        guard n.isFinite, n < Double(Swarms.maxAgents) else { return Swarms.maxAgents }
        return max(1, Int(n))
    }

    // MARK: Daily

    static func daily(_ s: inout GameState, _ b: ResearchBonuses) {
        for i in s.runs.indices where s.runs[i].status == .running || s.runs[i].status == .postTraining {
            let d = s.runs[i].design
            guard let accel = HardwareCatalog.get(d.accelID) else { continue }
            let schedule = s.runs[i].schedule
            let full = s.runs[i].kind == .full
            // Experiments get no mid-run incidents. Their dice are still rolled (at zero odds) to keep the rng stream.
            let quiet = s.runs[i].toy ? 0.0 : 1.0
            let cov = full ? coverage(s, s.runs[i]) : 0
            let ops = opsEffect(cov, s)
            var perDay = Double(d.chips) * accel.trainTFLOPS(d.precision) * 1e12 * Physics.runMFU(d, accel: accel, coverage: cov, state: s, bonuses: b)
                * 86_400 * schedule.speed
            let straggle = 1 - (1 - Physics.stragglerFactor(chips: d.chips, bonuses: b)) * (1 - ops.stragglers)
            let raw = perDay
            perDay *= Sim.checkpointOverhead(s.runs[i].interval) * straggle
            if full {
                TrainingExperience.ledgerDay(&s, i, accel: accel, coverage: cov, raw: raw, ckpt: Sim.checkpointOverhead(s.runs[i].interval), straggle: straggle)
            }
            if s.runs[i].kind == .proxy { perDay *= 0.33 }
            s.runs[i].cost += Economy.chipDailyCost(accel, count: d.chips, state: s)
            s.runs[i].opsCoverage = cov

            // Hardware failures (Llama 3 rates): each one costs the restart time plus work since the last save.
            // Ops agents drain failing nodes before they crash and restart the job from in-memory snapshots.
            // Estimates use the expectation of exactly this step (`goodput`), so plans and runs agree.
            var uptime = 1.0
            let lambda = Double(d.chips) * failuresPerChipDay * (1 - ops.prevented)
            if ops.prevented > 0 { s.runs[i].prevented += Double(d.chips) * failuresPerChipDay * ops.prevented }
            let k = poisson(lambda, &s.rng)
            let beforeFailures = perDay
            if k > 0 {
                let hours = Double(k) * Physics.hoursLostPerFailure(state: s, bonuses: b, chips: d.chips) * (1 - ops.recovery)
                s.runs[i].interruptions += k
                s.runs[i].failures += k
                s.runs[i].lostHours += hours
                perDay *= max(0, 1 - hours / 24)
                uptime = max(0, 1 - hours / 24)
                if hours >= 2 || (k > 0 && s.rng.chance(0.15)) {
                    let what = s.rng.pick(["GPU fell off the bus", "HBM uncorrectable ECC error", "NVLink/fabric link flap", "GPU SRAM fault",
                                           "host kernel panic", "optical transceiver failure", "straggler node evicted"])
                    runLog(&s, i, "\(k) interruption\(k == 1 ? "" : "s") (\(what)\(k > 1 ? " and more" : "")) — lost \(Fmt.trim(hours, 1)) h, auto-restarted from the last save.")
                }
            }
            if full { s.runs[i].ledger.failures += beforeFailures - perDay }
            // Silent data corruption: invisible, and at 100K+ chips it adds up. Agents and checksums catch most of it.
            let sdc = Double(d.chips) * failuresPerChipDay * sdcShare * uptime
            if d.chips >= 20_000 && s.runs[i].kind == .full && sdc > 0 {
                let before = Int(s.runs[i].sdcCaught)
                s.runs[i].sdcCaught += sdc * ops.sdcCaught
                s.runs[i].sdcMissed += sdc * (1 - ops.sdcCaught)
                s.runs[i].qualityPenalty += sdc * (1 - ops.sdcCaught) * sdcPenalty
                if cov > 0.2 && Int(s.runs[i].sdcCaught) / 10 > before / 10 {
                    runLog(&s, i, "Ops agents have quarantined \(Int(s.runs[i].sdcCaught)) nodes that were silently corrupting gradients.")
                }
            }
            if full { trackStall(&s, i, pace: uptime * straggle) }
            if full && d.chips >= 4_000 && !s.runs[i].decided.contains("fault_storm") && s.rng.chance(0.0025 * (1 - 0.6 * cov) * quiet) {
                faultStorm(&s, i)
                s.runs[i].ledger.incidents += perDay
                continue
            }

            if s.runs[i].status == .running {
                if full && s.runs[i].progress > 0.03 && s.rng.chance(spikeChance(s.runs[i], state: s, bonuses: b) * (1 - ops.spikes) * quiet) {
                    // With most of the run covered, agents catch the spike within steps and rewind a few minutes.
                    if cov >= 0.5 {
                        s.runs[i].spikes += 1
                        TrainingExperience.rewound(&s, i, min(s.runs[i].flopsDone, perDay * 0.02))
                        s.runs[i].flopsDone = max(0, s.runs[i].flopsDone - perDay * 0.02)
                        runLog(&s, i, "Loss spike caught by ops agents: rewound to a snapshot from minutes earlier and skipped the bad batch.")
                    } else if !awaiting(s, "loss_spike", i) {
                        lossSpike(&s, i)
                        s.runs[i].ledger.incidents += perDay
                        continue
                    }
                }
                s.runs[i].flopsDone += perDay
                if full { s.runs[i].ledger.useful += perDay }
                s.lifetimeFLOPs += perDay
                let frac = s.runs[i].progress
                recordLoss(&s, i, frac: frac)
                guard full else {
                    if s.runs[i].flopsDone >= s.runs[i].flopsTotal { finishLadder(&s, i) }
                    continue
                }
                midRunEvents(&s, i, frac: frac)
                if s.runs[i].status != .running { continue }
                let lastSaved = s.runs[i].saved.last?.fraction ?? 0
                if frac - lastSaved >= s.runs[i].interval - 1e-9 && frac < 1 {
                    saveCheckpoint(&s, i)
                }
                if s.runs[i].flopsDone >= s.runs[i].flopsTotal {
                    saveCheckpoint(&s, i)
                    s.runs[i].status = .postTraining
                    s.runs[i].stageIndex = s.runs[i].stages.firstIndex { !$0.isPre } ?? s.runs[i].stages.count
                    // The rest of the day goes into post-training rather than idling until tomorrow.
                    s.runs[i].stageDone = max(0, s.runs[i].flopsDone - s.runs[i].flopsTotal)
                    let post = s.runs[i].stages.filter { !$0.isPre }.map(\.name).joined(separator: " → ")
                    runLog(&s, i, "Pre-training complete after \(s.runs[i].interruptions) interruptions. Post-training: \(post).")
                    stageStarted(&s, i)
                    advanceStages(&s, i)
                }
            } else {
                s.runs[i].stageDone += perDay
                if full { s.runs[i].ledger.useful += perDay }
                s.lifetimeFLOPs += perDay
                advanceStages(&s, i)
            }
        }
    }

    /// Moves a post-training run through every stage its compute has finished, carrying leftover compute into the
    /// next stage (a cluster doesn't idle for the rest of the day when a short stage ends).
    static func advanceStages(_ s: inout GameState, _ i: Int) {
        while s.runs[i].status == .postTraining {
            guard s.runs[i].stageIndex < s.runs[i].stages.count else { finishRun(&s, i); break }
            let stage = s.runs[i].stages[s.runs[i].stageIndex]
            guard s.runs[i].stageDone >= stage.flops else { break }
            runLog(&s, i, "\(stage.name) done.")
            s.runs[i].stageIndex += 1
            s.runs[i].stageDone -= stage.flops
            if s.runs[i].stageIndex >= s.runs[i].stages.count {
                finishRun(&s, i)
            } else {
                stageStarted(&s, i)
            }
        }
        s.runs[i].postTrainDone = s.runs[i].stages.enumerated().filter { !$0.element.isPre && $0.offset < s.runs[i].stageIndex }
            .reduce(0) { $0 + $1.element.flops } + s.runs[i].stageDone
    }

    /// Whether an incident decision of `kind` about run `i` is still waiting for the player.
    static func awaiting(_ s: GameState, _ kind: String, _ i: Int) -> Bool {
        let ref = s.runs[i].id.uuidString
        return s.decisions.contains { $0.kind == kind && $0.ref == ref }
    }

    /// Counts days a run makes next to no progress (failures eating ≥95% of the day). After a week it raises an
    /// alert that says why and what fixes it, and again every 30 days while it stays stuck.
    static func trackStall(_ s: inout GameState, _ i: Int, pace: Double) {
        if pace < 0.05 {
            s.runs[i].stalledDays += 1
        } else if pace > 0.2 {
            s.runs[i].stalledDays = 0
        }
        let days = s.runs[i].stalledDays
        guard days >= 7, (days - 7) % 30 == 0 else { return }
        let run = s.runs[i]
        let advice = goodputAdvice(chips: run.design.chips, coverage: run.opsCoverage, running: true, state: s, bonuses: s.bonuses)
        let why = advice?.headline ?? "Hardware failures are eating whole days."
        let fixes = (advice?.fixes ?? []).prefix(3).joined(separator: " ")
        if days == 7 { runLog(&s, i, "No progress for a week. \(why)") }
        Alerts.raise(&s, .runPaused, key: "stall-\(run.id.uuidString)", title: "\(run.design.name) has made no progress in \(days) days",
                     body: "\(why) \(fixes)", screen: .training, critical: true, cooldown: 25)
    }

    static func dailyFlops(_ run: TrainingRun, state s: GameState) -> Double {
        guard let a = HardwareCatalog.get(run.design.accelID) else { return 0 }
        let b = s.bonuses
        return Double(run.design.chips) * a.trainTFLOPS(run.design.precision) * 1e12 * Physics.mfu(accel: a, chips: run.design.chips, state: s, bonuses: b) * 86_400
    }

    static func poisson(_ lambda: Double, _ rng: inout GameRNG) -> Int {
        guard lambda > 0 else { return 0 }
        if lambda > 25 { return max(0, Int((lambda + rng.gaussian() * sqrt(lambda)).rounded())) }
        let l = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= rng.range(0, 1)
        } while p > l && k < 200
        return k - 1
    }

    static func spikeChance(_ run: TrainingRun, state s: GameState, bonuses b: ResearchBonuses) -> Double {
        spikeChance(run.design, lr: run.schedule, state: s, bonuses: b)
    }

    /// Daily chance of a loss spike once pre-training is past 3%.
    static func spikeChance(_ d: ModelDesign, lr: LRSchedule, state s: GameState, bonuses b: ResearchBonuses) -> Double {
        let precision: Double = d.precision == .fp4 ? 2.2 : (d.precision == .fp8 ? 1.4 : 1)
        var arch = 1.0
        if d.optimizer == .muon { arch *= s.researched.contains("muon_clip") ? 0.9 : 1.8 }
        if d.isMoE { arch *= s.researched.contains("aux_free") ? 1.0 : 1.35 }
        if d.mixer == .diffusion { arch *= 1.2 }
        if d.mixer == .alien { arch *= 1.25 }
        arch *= (1 - 0.35 * s.swarmOps) * max(0.3, 1 - s.traits.spikes)
        let engineers = s.employees.filter { $0.role == .mlEngineer }.reduce(0.0) { $0 + $1.weight }
        let skill = min(0.5, engineers * 0.05)
        let scale = pow(Double(d.chips) / 256 + 1, 0.3) * pow(max(d.activeParamsB, 0.1) / 10, 0.12)
        return 0.0035 * scale * precision * arch * lr.spikeMult * (1 - skill) * max(0.1, 1 - b.stability)
    }

    // MARK: Loss curve & forecast tracking

    /// Deviation from forecast that the run has "earned" by fraction f (log10 effective compute).
    static func trueDeviation(_ run: TrainingRun, at f: Double) -> Double {
        var dev = run.epsilon * sqrt(max(0, f)) - run.qualityPenalty
        if !run.bugFound && f > run.bugOnset {
            dev -= run.bugPenalty * min(1, (f - run.bugOnset) / 0.15)
        }
        return dev
    }

    static func predictedLoss(_ run: TrainingRun, at f: Double) -> Double {
        let d = run.design
        let fc = run.forecast
        let gain = fc.map { $0.c - (log10(max(Physics.pretrainFLOPs(d), 1e12)) - 21) } ?? 0
        let raw = ForecastEngine.loss(paramsB: d.activeParamsB, tokensT: max(d.tokensT * f, d.tokensT * 0.002))
        return ForecastEngine.E + (raw - ForecastEngine.E) * pow(10, -ForecastEngine.gamma * gain)
    }

    static func recordLoss(_ s: inout GameState, _ i: Int, frac: Double) {
        let d = s.runs[i].design
        let seen = d.tokensT * frac
        guard s.runs[i].loss.isEmpty || seen - (s.runs[i].loss.last?.tokensT ?? 0) > d.tokensT / 90 else { return }
        let pred = predictedLoss(s.runs[i], at: frac)
        let dev = trueDeviation(s.runs[i], at: frac)
        let actualExcess = (pred - ForecastEngine.E) * pow(10, -ForecastEngine.gamma * dev)
        let noise = s.rng.gaussian() * 0.0035 * (0.4 + (pred - ForecastEngine.E))
        let loss = ForecastEngine.E + actualExcess + noise
        let gnorm = max(0.05, 0.35 + 0.6 * exp(-frac * 12) + s.rng.gaussian() * 0.05 + (frac > s.runs[i].bugOnset && !s.runs[i].bugFound ? 0.08 : 0))
        s.runs[i].loss.append(LossPoint(tokensT: seen, loss: loss, spike: false, pred: pred, gnorm: gnorm))
    }

    /// What evals and the loss curve imply about the final model (posterior over epsilon).
    static func observe(_ s: inout GameState, _ i: Int, frac f: Double) {
        let run = s.runs[i]
        let sigma = run.forecast?.sigma ?? 0.2
        let g = sqrt(max(f, 1e-3))
        let noiseSD = sigma * 0.7 * sqrt(max(0, 1 - f)) + 0.012
        let observed = trueDeviation(run, at: f) + run.qualityPenalty + s.rng.gaussian() * noiseSD
        // Gaussian prior N(0, σ²) on ε; observation y = ε·g + noise
        let post = (sigma * sigma * g) / (sigma * sigma * g * g + noiseSD * noiseSD)
        s.runs[i].revealMean = post * observed
        s.runs[i].revealSigma = sqrt((sigma * sigma * noiseSD * noiseSD) / (sigma * sigma * g * g + noiseSD * noiseSD))
    }

    static func projectedIndex(_ s: GameState, _ run: TrainingRun) -> (Double, Double, Double) {
        guard let fc = run.forecast else { return (0, 0, 0) }
        let f = ForecastEngine.forecast(run.design, state: s, dataSources: run.dataSnapshot)
        let set = Leaderboard.indexSet(s)
        let known = -run.qualityPenalty + run.schedule.qualityBonus - (run.bugFound ? run.bugPenalty * 0.25 : 0)
        let mean = fc.c + run.revealMean + known
        let extra = (run.dReasoning, run.dCode, run.dChat, run.dSafety, run.dLang)
        func idx(_ c: Double, _ k: String) -> Double {
            ForecastEngine.index(ForecastEngine.profile(f, design: run.design, key: k, c: c, extra: extra), set: set)
        }
        let sd = max(run.revealSigma, 0.01)
        return (idx(mean, "pm"), idx(mean - 1.28 * sd, "pl"), idx(mean + 1.28 * sd, "ph"))
    }

    // MARK: Checkpoints

    static func saveCheckpoint(_ s: inout GameState, _ i: Int) {
        let run = s.runs[i]
        let f = run.progress
        observe(&s, i, frac: f)
        var partial = run.design
        partial.tokensT = max(run.design.tokensT * f, 0.0001)
        partial.instruct = false
        partial.reasoning = false
        let fc = ForecastEngine.forecast(partial, state: s, dataSources: run.dataSnapshot)
        let c = fc.c + trueDeviation(s.runs[i], at: f) + run.schedule.qualityBonus * f
        let p = ForecastEngine.profile(fc, design: partial, key: "\(run.id.uuidString)-\(Int(f * 1000))", c: c)
        let set = Leaderboard.indexSet(s)
        let idx = BenchmarkCatalog.index(p, set: set)
        let proj = projectedIndex(s, s.runs[i])
        var cp = TrainCheckpoint(fraction: f, tokensT: run.design.tokensT * f, loss: run.loss.last?.loss ?? 0, c: c, index: idx,
                                 date: s.date, flopsDone: run.flopsDone)
        cp.projected = proj.0
        cp.projectedLow = proj.1
        cp.projectedHigh = proj.2
        s.runs[i].saved.append(cp)
        let ahead = s.runs[i].revealMean
        let trend = abs(ahead) < 0.02 ? "right on forecast" : (ahead > 0 ? "tracking ahead of forecast" : "tracking behind forecast")
        runLog(&s, i, "Checkpoint @ \(Int(f * 100))% — loss \(String(format: "%.3f", cp.loss)), \(trend). Projected index \(Fmt.score(proj.0)) (\(Fmt.score(proj.1))–\(Fmt.score(proj.2))).")
        emergence(&s, i, profile: p, set: s.benchmarks.filter { $0.isActive(s.date, saturated: s.benchSaturated) })
        // A silent bug can be caught once its signature shows up in evals.
        if run.bugPenalty > 0 && !run.bugFound && f > run.bugOnset + 0.04 && !s.runs[i].decided.contains("train_bug") {
            let engineers = s.employees.filter { $0.role == .mlEngineer }.reduce(0.0) { $0 + $1.weight }
            let p = clamp(0.3 * (1 + engineers / 4) * (1 + s.swarmOps) * (1 + run.opsCoverage) / max(0.3, s.bonuses.bugKeep), 0.15, 0.95)
            if s.rng.chance(p) { trainingBug(&s, i) }
        }
    }

    static func emergence(_ s: inout GameState, _ i: Int, profile p: ModelProfile, set: [Benchmark]) {
        let prev = s.runs[i].saved.dropLast().last
        guard let prev else { return }
        let prevP = ModelProfile(key: p.key + "-prev", c: prev.c, reasoning: p.reasoning, code: p.code, agent: p.agent, vision: p.vision,
                                 contextK: p.contextK, tuning: 0, chat: p.chat, safety: p.safety, lang: p.lang, longctx: p.longctx, vis: p.vis, audio: p.audio)
        for bm in set where !s.runs[i].emerged.contains(bm.id) && bm.kind.inIndex {
            let before = bm.score(prevP, noise: false), now = bm.score(p, noise: false)
            let range = bm.ceiling - bm.floor
            if before < bm.floor + 0.25 * range && now >= bm.floor + 0.5 * range {
                s.runs[i].emerged.insert(bm.id)
                runLog(&s, i, "Emergent ability: \(bm.name) jumped from \(bm.format(before)) to \(bm.format(now)) between checkpoints.")
                if s.runs[i].emerged.count <= 2 {
                    Sim.news(&s, "\(s.runs[i].design.name) just learned something new", "Between checkpoints, \(bm.name) jumped from \(bm.format(before)) to \(bm.format(now)). Capabilities don't always grow smoothly.",
                             .research, image: "supercomputer", good: true)
                }
                break
            }
        }
    }

    // MARK: Events

    static func lossSpike(_ s: inout GameState, _ i: Int) {
        s.runs[i].spikes += 1
        if let last = s.runs[i].loss.last {
            s.runs[i].loss.append(LossPoint(tokensT: last.tokensT + 0.0001, loss: last.loss * s.rng.range(1.15, 1.6), spike: true,
                                            pred: last.pred, gnorm: s.rng.range(3, 9)))
        }
        if s.runs[i].autoRollback, let cp = s.runs[i].saved.last {
            rollback(&s, i, to: cp)
            runLog(&s, i, "Loss spike! Auto-rolled back to the \(Int(cp.fraction * 100))% checkpoint.")
            return
        }
        // Incidents never pause a run (the decision stops the clock instead), so it can't sit idle waiting for an answer.
        runLog(&s, i, "Loss spike detected — waiting for your call.")
        let cp = s.runs[i].saved.last
        let d = s.runs[i].design
        let cause: String
        if d.optimizer == .muon && !s.researched.contains("muon_clip") { cause = "Attention logits are exploding under Muon — classic. MuonClip research would prevent this." }
        else if d.isMoE && !s.researched.contains("aux_free") { cause = "The MoE router collapsed onto a few experts." }
        else { cause = "It could be a bad data shard, an FP\(d.precision == .bf16 ? "16" : (d.precision == .fp8 ? "8" : "4")) overflow or a learning rate that's too hot." }
        Events.addDecision(&s, kind: "loss_spike", title: "Loss spike in \(d.name)",
                           body: "The training loss just jumped at \(Int(s.runs[i].progress * 100))% of pre-training. \(cause)",
                           image: "supercomputer",
                           options: [DecisionOption(label: cp.map { "Roll back to \(Int($0.fraction * 100))% checkpoint" } ?? "Restart from scratch",
                                                    detail: "Safest. Lose the progress since then and switch to a conservative learning rate."),
                                     DecisionOption(label: "Skip the bad batch", detail: "Keep going. Small permanent quality hit (×0.93)."),
                                     DecisionOption(label: "Push through", detail: "Gamble: ~55% it recovers on its own, otherwise the model is noticeably worse.")],
                           ref: s.runs[i].id.uuidString)
    }

    static func trainingBug(_ s: inout GameState, _ i: Int) {
        s.runs[i].decided.insert("train_bug")
        let onset = s.runs[i].bugOnset
        let before = s.runs[i].saved.last { $0.fraction <= onset }
        let bug = s.rng.pick(["the data loader has been silently re-reading the same shards", "a tokenizer change dropped all whitespace in code files",
                              "gradient clipping was applied twice after a config refactor", "a silent data-corruption bit-flip poisoned one node's gradients",
                              "the learning-rate schedule restarted at the last checkpoint resume"])
        runLog(&s, i, "Your engineers found a bug: \(bug).")
        Events.addDecision(&s, kind: "train_bug", title: "Bug found in \(s.runs[i].design.name)",
                           body: "Investigating why the loss drifted above forecast, your engineers found that \(bug). It started around \(Int(onset * 100))% of pre-training.",
                           image: "server_room",
                           options: [DecisionOption(label: before.map { "Roll back to \(Int($0.fraction * 100))% and fix it" } ?? "Fix and restart",
                                                    detail: "Lose the progress since the bug started; the model ends up as good as forecast."),
                                     DecisionOption(label: "Hot-fix and continue", detail: "Keep the progress. The damage already done stays (about a quarter of it)."),
                                     DecisionOption(label: "Ignore it", detail: "Ship on schedule. The model will be noticeably worse.")],
                           ref: s.runs[i].id.uuidString)
    }

    static func midRunEvents(_ s: inout GameState, _ i: Int, frac: Double) {
        let b = s.bonuses
        // Benchmark contamination
        if frac > 0.3 && frac < 0.75 && !s.runs[i].decided.contains("contamination") {
            if s.rng.chance(0.012 * b.contaminationKeep * (s.runs[i].toy ? 0 : 1)) {
                s.runs[i].decided.insert("contamination")
                Events.addDecision(&s, kind: "contamination", title: "Benchmark contamination in \(s.runs[i].design.name)",
                                   body: "An audit found test questions from popular benchmarks scattered through your web crawl. Your scores will be inflated — and someone will notice.",
                                   image: "dc_rows",
                                   options: [DecisionOption(label: "Scrub the data and rewind 5%", detail: "Costs time; scores stay honest."),
                                             DecisionOption(label: "Leave it", detail: "Higher scores now; a contamination scandal is likely after release.")],
                                   ref: s.runs[i].id.uuidString)
                return
            }
        } else if frac >= 0.75 { s.runs[i].decided.insert("contamination") }
        // The mid-training mix shift chosen in the Model Lab kicks in for the second half (its skills are in the forecast).
        if frac > 0.45 && !s.runs[i].decided.contains("data_mix") {
            s.runs[i].decided.insert("data_mix")
            let shift = s.runs[i].design.mixShift
            if shift != .keep && b.has(.curriculum) && s.runs[i].design.mode != .finetune {
                runLog(&s, i, "Mid-training: the second half now leans into \(shift == .code ? "code" : (shift == .stem ? "math & science" : "other languages")), as planned.")
            }
        }
    }

    static func faultStorm(_ s: inout GameState, _ i: Int) {
        s.runs[i].decided.insert("fault_storm")
        let a = HardwareCatalog.get(s.runs[i].design.accelID)
        Events.addDecision(&s, kind: "fault_storm", title: "Hardware fault storm",
                           body: "A bad batch of \(a?.name ?? "accelerators") is failing at 5× the normal rate — probably HBM from one supplier lot. \(s.runs[i].design.name) keeps restarting.",
                           image: "rack_rear",
                           options: [DecisionOption(label: "Swap the bad nodes (\(Fmt.money(Double(s.runs[i].design.chips) * 400)))", detail: "Two days of downtime, then back to normal."),
                                     DecisionOption(label: "Run degraded", detail: "Keep training at reduced goodput for weeks.")],
                           ref: s.runs[i].id.uuidString)
    }

    static func stageStarted(_ s: inout GameState, _ i: Int) {
        guard s.runs[i].stageIndex < s.runs[i].stages.count else { return }
        let name = s.runs[i].stages[s.runs[i].stageIndex].name
        runLog(&s, i, "\(name) started.")
        let quiet = s.runs[i].toy ? 0.0 : 1.0
        // A Dense Reward Oracle at level 3 can't be flattered or gamed.
        let honestRewards = s.signatureAt(.lodestar, 3)
        if (name == "RLHF" || name == "DPO") && !s.runs[i].decided.contains("sycophancy") && !honestRewards {
            if s.rng.chance(sycophancyRisk(s) * quiet) {
                s.runs[i].decided.insert("sycophancy")
                let prevent = s.researched.contains("anti_sycophancy") ? "" : " Anti-Sycophancy Training research makes this five times rarer."
                Events.addDecision(&s, kind: "sycophancy", title: "\(s.runs[i].design.name) has become a flatterer",
                                   body: "Preference tuning rewarded agreeable answers a bit too much. In evals the model praises bad business plans and agrees with obviously wrong claims.\(prevent)",
                                   image: "sf_skyline",
                                   options: [DecisionOption(label: "Retrain the reward model", detail: "Costs extra post-training time; fixes it."),
                                             DecisionOption(label: "Ship it", detail: "Users love it at first… until the screenshots go viral.")],
                                   ref: s.runs[i].id.uuidString)
            }
        }
        if name == "Reasoning RL" && !s.runs[i].decided.contains("reward_hack") && !honestRewards {
            if s.rng.chance(rewardHackRisk(s.runs[i].design, s) * quiet) {
                s.runs[i].decided.insert("reward_hack")
                let caught = s.researched.contains("cot_monitoring") ? "Chain-of-thought monitors caught it" : "A researcher noticed by accident"
                var missing: [String] = []
                if !s.researched.contains("cot_monitoring") { missing.append("Chain-of-Thought Monitoring") }
                if !s.researched.contains("verifiers") { missing.append("Verifiable Environments at Scale") }
                let prevent = missing.isEmpty ? "" : " \(missing.joined(separator: " and ")) research make\(missing.count == 1 ? "s" : "") this rarer."
                Events.addDecision(&s, kind: "reward_hack", title: "Reward hacking in \(s.runs[i].design.name)",
                                   body: "\(caught): the model learned to special-case unit tests and edit the grader instead of solving problems. RL reward is up; real ability isn't.\(prevent)",
                                   image: "server_room",
                                   options: [DecisionOption(label: "Patch the environments and redo RL", detail: "Repeat this stage. Honest gains."),
                                             DecisionOption(label: "Ship the checkpoint", detail: "Benchmarks look great. Real-world users will find out.")],
                                   ref: s.runs[i].id.uuidString)
            }
        }
    }

    /// Redo a post-training stage (from its start) after a bad outcome. Normally the run is still in it.
    static func redoStage(_ s: inout GameState, _ i: Int, named names: [String]) {
        guard s.runs[i].status == .postTraining || s.runs[i].status == .paused,
              let idx = s.runs[i].stages.firstIndex(where: { names.contains($0.name) }), idx <= s.runs[i].stageIndex else { return }
        let redone = s.runs[i].stages[idx..<min(s.runs[i].stageIndex, s.runs[i].stages.count)].reduce(0) { $0 + $1.flops } + s.runs[i].stageDone
        TrainingExperience.rewound(&s, i, redone)
        s.runs[i].stageIndex = idx
        s.runs[i].stageDone = 0
    }

    // MARK: Decisions

    static func resolve(_ s: inout GameState, kind: String, ref: String, option: Int) {
        guard let i = s.runs.firstIndex(where: { $0.id.uuidString == ref }) else { return }
        // Only possible if days passed with the decision open: the run has moved on without an answer.
        guard s.runs[i].status != .done && s.runs[i].status != .cancelled else { return }
        switch kind {
        case "loss_spike":
            switch option {
            case 0:
                if let cp = s.runs[i].saved.last { rollback(&s, i, to: cp) } else {
                    TrainingExperience.rewound(&s, i, s.runs[i].flopsDone)
                    s.runs[i].flopsDone = 0; s.runs[i].loss = []
                }
                s.runs[i].lr = LRSchedule.conservative.rawValue
                runLog(&s, i, "Rolled back and lowered the learning rate.")
            case 1:
                s.runs[i].qualityPenalty += 0.03
                runLog(&s, i, "Skipped the bad batch (×0.93 quality).")
            default:
                if s.rng.chance(0.55) {
                    runLog(&s, i, "Pushed through — the loss recovered on its own. Phew.")
                } else {
                    s.runs[i].qualityPenalty += 0.12
                    if let last = s.runs[i].loss.last {
                        s.runs[i].loss.append(LossPoint(tokensT: last.tokensT + 0.0001, loss: last.loss * 1.06, pred: last.pred, gnorm: 2))
                    }
                    runLog(&s, i, "Pushed through — partial divergence. The model will be noticeably worse (×0.76).")
                }
            }
        case "train_bug":
            switch option {
            case 0:
                let onset = s.runs[i].bugOnset
                if let cp = s.runs[i].saved.last(where: { $0.fraction <= onset }) { rollback(&s, i, to: cp) } else {
                    TrainingExperience.rewound(&s, i, s.runs[i].flopsDone)
                    s.runs[i].flopsDone = 0; s.runs[i].loss = []
                }
                s.runs[i].bugFound = true
                s.runs[i].bugPenalty = 0
                runLog(&s, i, "Rolled back to before the bug and fixed it.")
            case 1:
                s.runs[i].bugFound = true
                s.runs[i].qualityPenalty += s.runs[i].bugPenalty * 0.25
                s.runs[i].bugPenalty = 0
                runLog(&s, i, "Hot-fixed. Some damage remains.")
            default:
                s.runs[i].bugOnset = min(s.runs[i].bugOnset, s.runs[i].progress - 0.15)
                runLog(&s, i, "Ignored the bug. The model will carry it.")
            }
        case "contamination":
            if option == 0 {
                let back = max(0, s.runs[i].progress - 0.05)
                let cutoff = s.runs[i].design.tokensT * back + 1e-9
                TrainingExperience.rewound(&s, i, max(0, s.runs[i].flopsDone - s.runs[i].flopsTotal * back)
                                           + (s.runs[i].status == .postTraining ? s.runs[i].postTrainDone : 0))
                s.runs[i].flopsDone = s.runs[i].flopsTotal * back
                s.runs[i].loss.removeAll { $0.tokensT > cutoff }
                if s.runs[i].status == .postTraining {
                    s.runs[i].status = .running
                    s.runs[i].postTrainDone = 0
                    s.runs[i].stageIndex = 0
                    s.runs[i].stageDone = 0
                }
                runLog(&s, i, "Scrubbed contaminated documents and rewound 5%.")
            } else {
                s.runs[i].contaminated = true
                runLog(&s, i, "Left the contamination in. Scores will be inflated.")
            }
        case "data_mix":
            switch option {
            case 0: s.runs[i].dCode += 0.06; s.runs[i].dChat -= 0.03; runLog(&s, i, "Shifted the second half toward code.")
            case 1: s.runs[i].dReasoning += 0.06; runLog(&s, i, "Shifted the second half toward math & science.")
            case 2: s.runs[i].dLang += 0.18; runLog(&s, i, "Shifted the second half toward multilingual data.")
            default: runLog(&s, i, "Kept the planned mix.")
            }
        case "fault_storm":
            let day = dailyFlops(s.runs[i], state: s)
            let lost = (option == 0 ? 2 : 7 * 0.4) * day
            // Time lost in post-training comes out of the current stage, not out of finished pre-training.
            if s.runs[i].status == .postTraining {
                TrainingExperience.rewound(&s, i, min(s.runs[i].stageDone, lost))
                s.runs[i].stageDone = max(0, s.runs[i].stageDone - lost)
            } else {
                TrainingExperience.rewound(&s, i, min(s.runs[i].flopsDone, lost))
                s.runs[i].flopsDone = max(0, s.runs[i].flopsDone - lost)
            }
            if option == 0 {
                s.cash -= Double(s.runs[i].design.chips) * 400
                s.runs[i].lostHours += 48
                runLog(&s, i, "Swapped the bad nodes after two days of downtime. Back to normal.")
            } else {
                s.runs[i].lostHours += 24 * 7 * 0.4
                runLog(&s, i, "Ran degraded for weeks — lost about three days of progress.")
            }
        case "sycophancy":
            if option == 0 {
                redoStage(&s, i, named: ["RLHF", "DPO"])
                runLog(&s, i, "Retraining the reward model.")
            } else {
                s.runs[i].sycophantic = true
                s.runs[i].dSafety -= 8
                runLog(&s, i, "Shipping the flatterer.")
            }
        case "reward_hack":
            if option == 0 {
                redoStage(&s, i, named: ["Reasoning RL"])
                runLog(&s, i, "Patched the RL environments; redoing reasoning RL.")
            } else {
                s.runs[i].rewardHacked = true
                s.runs[i].dSafety -= 6
                runLog(&s, i, "Shipping a reward-hacked checkpoint.")
            }
        default: break
        }
        // Incidents no longer pause runs. One paused by an incident in an older save resumes here if its chips are free.
        if s.runs[i].status == .paused {
            let free = Economy.freeChips(s, s.runs[i].design.accelID)
            if free >= s.runs[i].design.chips {
                s.runs[i].status = s.runs[i].flopsDone >= s.runs[i].flopsTotal ? .postTraining : .running
            } else {
                runLog(&s, i, "Not enough free chips to resume — resume it from Training Runs.")
            }
        }
    }

    static func rollback(_ s: inout GameState, _ i: Int, to cp: TrainCheckpoint) {
        TrainingExperience.rewound(&s, i, max(0, s.runs[i].flopsDone - cp.flopsDone) + (s.runs[i].status == .postTraining ? s.runs[i].postTrainDone : 0))
        s.runs[i].flopsDone = cp.flopsDone
        s.runs[i].loss.removeAll { $0.tokensT > cp.tokensT + 1e-9 }
        s.runs[i].saved.removeAll { $0.fraction > cp.fraction + 1e-9 && $0.forkedModelID == nil }
        if s.runs[i].status == .postTraining {
            s.runs[i].status = .running
            s.runs[i].postTrainDone = 0
            s.runs[i].stageIndex = 0
            s.runs[i].stageDone = 0
        }
    }

    // MARK: Finish

    static func finishLadder(_ s: inout GameState, _ i: Int) {
        let run = s.runs[i]
        s.runs[i].status = .done
        s.runs[i].finished = s.date
        let fit = ScalingFit(signature: run.design.recipeSignature, maxCompute: run.flopsTotal, date: s.date)
        s.scalingFits.removeAll { $0.signature == fit.signature && $0.maxCompute <= fit.maxCompute }
        s.scalingFits.append(fit)
        Achievements.unlock(&s, "ladder")
        let lo = run.flopsTotal / 300
        runLog(&s, i, "Ladder complete: 5 proxy runs from \(Fmt.flops(lo)) to \(Fmt.flops(run.flopsTotal)) fit a clean power law.")
        Sim.news(&s, "Scaling ladder done for \(run.design.name)",
                 "Five proxy runs from \(Fmt.flops(lo)) to \(Fmt.flops(run.flopsTotal)) FLOPs line up on a power law. Forecasts for this recipe are now much tighter (valid up to ~\(Fmt.flops(run.flopsTotal * pow(10, 3.7)))), and the hyperparameters are tuned.",
                 .research, image: "wafer_closeup", good: true)
    }

    static func finishRun(_ s: inout GameState, _ i: Int) {
        let b = s.bonuses
        let run = s.runs[i]
        let d = run.design
        let fc = ForecastEngine.forecast(d, state: s, dataSources: run.dataSnapshot)
        let base = run.forecast?.c ?? fc.c
        let c = base + trueDeviation(run, at: 1) + run.schedule.qualityBonus
        var model = AIModel(name: d.name, design: d, created: s.date, c: c, reasoning: d.reasoning && b.has(.reasoning),
                            reasoningBoost: fc.reasoning + run.dReasoning - (run.rewardHacked ? 0.05 : 0),
                            codeBoost: fc.code + run.dCode, arenaBonus: 75 * (fc.chat + run.dChat) + (d.vision ? 8 : 0) + (d.audio ? 6 : 0),
                            scores: [:], index: 0)
        model.agentBoost = fc.agent
        model.chatSkill = fc.chat + run.dChat - (run.sycophantic ? 0.05 : 0)
        model.langSkill = fc.lang + run.dLang
        model.longctxSkill = fc.longctx
        model.visSkill = fc.vis
        model.usedShadowData = fc.usesShadowData
        model.tuned = d.benchmarkTuning || run.contaminated
        model.safety = clamp(fc.safety + run.dSafety, 0, 100)
        model.cForecast = base
        model.forecastSigma = run.forecast?.sigma ?? fc.sigma
        model.keyTech = fc.keyTech
        model.apiPrice = max(0.01, (Macro.referencePrice(c: c, y: s.year) * s.market.apiPricePressure * 0.85 * 1000).rounded() / 1000)
        model.servingPrecision = b.has(.int8Serving) ? .fp8 : .bf16
        if d.mixer == .diffusion { model.efficiencyBoost += 1.5 * b.result("x_diffusion_lm") }
        if d.mixer == .hybrid { model.efficiencyBoost += 0.3 }
        if d.mixer == .alien { model.efficiencyBoost += 0.4 }
        model.autoPrice = true
        let set = Leaderboard.indexSet(s)
        model.index = BenchmarkCatalog.index(Leaderboard.profile(model), set: set)
        let top = Leaderboard.entries(s, set: set, includeUnreleased: false).filter { !$0.isPlayer }.map(\.index).max() ?? 0
        model.tier = ForecastEngine.tier(index: model.index, top: top)
        let previousBest = s.models.filter { !$0.preview }.map(\.index).max()
        s.models.append(model)
        s.runs[i].status = .done
        s.runs[i].cFinal = c
        s.runs[i].modelID = model.id
        s.runs[i].finished = s.date
        s.runs[i].note = "Finished \(s.date.gameShort)."

        // Experience: techniques proven at this scale make future forecasts tighter.
        let logC = log10(max(run.flopsTotal, 1e12))
        for (key, _, _) in ForecastEngine.techKeys(d) { s.techExperience[key] = max(s.techExperience[key] ?? 0, logC) }
        s.maxRunCompute = max(s.maxRunCompute, run.flopsTotal)

        let rank = Leaderboard.rank(of: model.id, in: s)
        let delta = model.index - (run.forecast?.index ?? model.index)
        let verdict = abs(delta) < 1.5 ? "right on forecast" : (delta > 0 ? "beat its forecast by \(Fmt.trim(delta, 1)) points" : "missed its forecast by \(Fmt.trim(-delta, 1)) points")
        news(&s, "\(d.name) finished training", "Intelligence Index \(Fmt.score(model.index)) — #\(rank) worldwide, \(verdict). \(model.tier).",
             important: true, good: delta > -3)
        if delta >= 5 { Achievements.unlock(&s, "genius") }
        if d.chips >= 500_000 { Achievements.unlock(&s, "gigawatt_run") }
        if run.sdcMissed >= 1 || run.prevented >= 10 {
            runLog(&s, i, "Ops report: \(Int(run.prevented)) failures prevented, \(Int(run.sdcCaught)) corrupt nodes caught, \(Int(run.sdcMissed)) slipped through.")
        }
        TrainingExperience.finished(&s, run: s.runs[i], model: model, previousBest: previousBest, rank: rank)
        Families.adopt(&s, model)   // 3.5: a run named for an existing family becomes its new flagship
    }

    // MARK: Helpers

    static func news(_ s: inout GameState, _ title: String, _ body: String, important: Bool, good: Bool) {
        Sim.news(&s, title, body, .company, image: "supercomputer", important: important, good: good)
    }

    static func runLog(_ s: inout GameState, _ i: Int, _ text: String) {
        runLogDirect(&s.runs[i], s.date, text)
    }

    static func runLogDirect(_ run: inout TrainingRun, _ date: Date, _ text: String) {
        run.events.insert("\(date.gameShort) · \(text)", at: 0)
        if run.events.count > 60 { run.events.removeLast() }
        run.note = text
    }
}
