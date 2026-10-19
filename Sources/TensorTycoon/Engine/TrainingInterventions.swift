import Foundation

/// 3.4: what you can do to a run while it trains, beyond pausing it: run a diagnostic eval sweep, investigate
/// instability, red-team the reinforcement-learning environments, end pre-training early or extend it. Each has a
/// real cost (cluster time, money, quality) and a real effect on the run, and the command centre shows both before
/// you commit.
enum TrainingInterventions {
    // MARK: Telemetry

    /// Days of telemetry a run keeps for the command centre.
    static let telemetryDays = 120

    static func recordDay(_ s: inout GameState, _ i: Int, _ day: RunDay) {
        guard s.runs[i].kind == .full else { return }
        s.runs[i].telemetry.append(day)
        if s.runs[i].telemetry.count > telemetryDays { s.runs[i].telemetry.removeFirst(s.runs[i].telemetry.count - telemetryDays) }
    }

    // MARK: Validation

    /// Held-out loss over the training loss at pre-training fraction `f`. Repeating data stops helping after about four
    /// passes and then starts to overfit; a silent bug shows up on held-out data a little before the training curve
    /// drifts (corrupted batches still fit, they just don't generalise).
    static func validationGap(_ run: TrainingRun, at f: Double) -> Double {
        var gap = 0.0
        if run.uniqueT > 0 {
            let epochs = run.design.tokensT * f / run.uniqueT
            gap += 0.006 * pow(max(0, epochs - 4), 1.3)
        }
        if run.bugPenalty > 0 && !run.bugFound {
            let start = run.bugOnset - 0.05
            if f > start { gap += 0.015 * min(1, (f - start) / 0.1) * run.bugPenalty / 0.2 }
        }
        return gap
    }

    /// What repeating the run's data is doing: passes so far and the held-out gap it causes.
    static func repetition(_ run: TrainingRun) -> (epochs: Double, gap: Double) {
        guard run.uniqueT > 0 else { return (0, 0) }
        let epochs = run.design.tokensT * run.progress / run.uniqueT
        return (epochs, 0.006 * pow(max(0, epochs - 4), 1.3))
    }

    // MARK: Diagnostic eval sweep

    static let diagnoseCooldown = 21

    /// Cluster time and money a diagnostic sweep costs: a quarter of a day of the run's compute (the cluster runs the
    /// full eval suite and held-out analysis instead of training) plus the engineers' time.
    static func diagnoseCost(_ s: GameState, _ run: TrainingRun) -> (flops: Double, money: Double) {
        let perDay = Training.dailyFlops(run, state: s)
        let chipDay = HardwareCatalog.get(run.design.accelID).map { Economy.chipDailyCost($0, count: run.design.chips, state: s) } ?? 0
        return (perDay * 0.25, max(25_000, chipDay * 0.1))
    }

    static func diagnoseBlocker(_ s: GameState, _ run: TrainingRun) -> String? {
        guard run.kind == .full, run.status == .running || run.status == .postTraining else { return "Only a live run can be diagnosed." }
        if run.progress < 0.05 { return "Too early: there's nothing to evaluate before 5% of pre-training." }
        if let last = run.diagnosedAt, GameCalendar.daysBetween(last, s.date) < diagnoseCooldown {
            return "The last sweep was \(GameCalendar.daysBetween(last, s.date)) days ago; run another after \(diagnoseCooldown) days."
        }
        let cost = diagnoseCost(s, run)
        if s.cash < cost.money { return "A sweep costs \(Fmt.money(cost.money))." }
        return nil
    }

    /// The probability the routine audit would still catch leaked benchmarks later in this run (the daily odds the
    /// simulation uses, over the pre-training days left in the audit window).
    static func latentContamination(_ s: GameState, _ i: Int) -> Double {
        let run = s.runs[i]
        guard !run.decided.contains("contamination"), run.progress < 0.75, !run.toy else { return 0 }
        let perDay = Training.dailyFlops(run, state: s)
        guard perDay > 0 else { return 0 }
        let preDays = run.flopsTotal / perDay
        let window = max(0, 0.75 - max(run.progress, 0.3)) * preDays
        let daily = 0.012 * s.bonuses.contaminationKeep * Training.contaminationRisk(s, run)
        return 1 - pow(1 - min(0.5, daily), window)
    }

    struct Finding: Hashable {
        var title: String
        var detail: String
        var tone: Int   // -1 bad, 0 neutral, 1 good
    }

    /// Runs the sweep: evaluates the latest checkpoint and the held-out loss, scans the data for benchmark leakage and
    /// looks for the signature of a silent bug. A bug or contamination it finds becomes the usual decision, earlier and
    /// cheaper to fix; a clean scan clears the run of contamination for good.
    static func diagnose(_ s: inout GameState, _ i: Int) -> [Finding] {
        let run = s.runs[i]
        let cost = diagnoseCost(s, run)
        s.cash -= cost.money
        s.month.costOther += cost.money
        s.runs[i].cost += cost.money
        s.runs[i].diagnosedAt = s.date
        if run.status == .running {
            TrainingExperience.rewound(&s, i, min(s.runs[i].flopsDone, cost.flops))
            s.runs[i].flopsDone = max(0, s.runs[i].flopsDone - cost.flops)
        }
        var out: [Finding] = []
        // Silent bug: its signature is on the held-out loss once it has started.
        if run.bugPenalty > 0 && !run.bugFound && run.progress > run.bugOnset - 0.03 && !run.decided.contains("train_bug") {
            if s.rng.chance(0.85) {
                Training.trainingBug(&s, i)
                out.append(Finding(title: "Bug found", detail: "Held-out loss pulled away from training loss: your engineers traced it to its cause. Decide what to do in the inbox.", tone: -1))
            } else {
                out.append(Finding(title: "Held-out loss looks off", detail: "Something is pulling validation away from training loss, but the sweep couldn't pin it down. Try again later.", tone: -1))
            }
        }
        // Benchmark contamination: resolve now what the audit would otherwise find later.
        let latent = latentContamination(s, i)
        if !s.runs[i].decided.contains("contamination") && run.status == .running && run.progress < 0.75 {
            if s.rng.chance(latent) {
                s.runs[i].decided.insert("contamination")
                s.runs[i].contaminationEarly = true
                Events.addDecision(&s, kind: "contamination", title: "Benchmark contamination in \(run.design.name)",
                                   body: "Your diagnostic sweep found test questions from popular benchmarks in the training data. Caught early, a scrub only rewinds 3%.",
                                   image: "dc_rows",
                                   options: [DecisionOption(label: "Scrub the data and rewind 3%", detail: "Costs a little time; scores stay honest."),
                                             DecisionOption(label: "Leave it", detail: "Higher scores now; a contamination scandal is likely after release.")],
                                   ref: run.id.uuidString)
                out.append(Finding(title: "Benchmark leakage", detail: "Test questions in the corpus. Scrub them now for a 3% rewind instead of 5% later.", tone: -1))
            } else if run.progress >= 0.05 {
                s.runs[i].decided.insert("contamination")
                out.append(Finding(title: "No benchmark leakage", detail: "The corpus scan came back clean: no contamination audit will interrupt this run.", tone: 1))
            }
        }
        // Repetition.
        let rep = repetition(s.runs[i])
        if rep.epochs > 4 {
            out.append(Finding(title: "Repeating data", detail: "\(Fmt.trim(rep.epochs, 1)) passes over \(Fmt.tokens(s.runs[i].uniqueT)) of unique data so far: held-out loss is \(Fmt.trim(rep.gap, 3)) above training loss. More unique data, or ending pre-training early, stops the waste.", tone: -1))
        } else if rep.epochs > 0 {
            out.append(Finding(title: "Data is fresh", detail: "\(Fmt.trim(rep.epochs, 2)) passes over the unique data: no sign of overfitting.", tone: 1))
        }
        // Where the run stands.
        Training.observe(&s, i, frac: s.runs[i].progress)
        let p = Training.projectedIndex(s, s.runs[i])
        out.append(Finding(title: "Projected index \(Fmt.score(p.0))", detail: "80% range \(Fmt.score(p.1))–\(Fmt.score(p.2)) from today's evals.", tone: 0))
        Training.runLog(&s, i, "Diagnostic sweep: " + out.map(\.title).joined(separator: " · ") + ".")
        return out
    }

    // MARK: Instability investigation

    static func investigateBlocker(_ s: GameState, _ run: TrainingRun) -> String? {
        guard run.status == .running else { return "Only a run in pre-training can be investigated." }
        if run.spikes == 0 { return "No loss spikes to investigate yet." }
        if run.investigated { return "Already investigated." }
        return nil
    }

    /// What's behind this design's loss spikes, as engineers would find it.
    static func instabilityCause(_ d: ModelDesign, _ s: GameState) -> (cause: String, fix: String) {
        if d.optimizer == .muon && !s.researched.contains("muon_clip") {
            return ("Attention logits growing without bound under Muon.", "Capped the query-key logits for the rest of the run.")
        }
        if d.isMoE && !s.researched.contains("aux_free") {
            return ("The MoE router collapsing onto a few experts.", "Raised the balancing loss and re-initialised dead experts.")
        }
        if d.precision != .bf16 {
            return ("Overflows in \(d.precision.short) matmuls on outlier activations.", "Moved the outlier layers to BF16 and tightened loss scaling.")
        }
        if d.attention == .mha && !s.researched.contains("qk_norm") {
            return ("Attention logit growth in deep layers.", "Added QK normalisation to the training config.")
        }
        return ("A few bad data shards with extreme lengths and repeated tokens.", "Filtered them and lowered the peak learning rate slightly.")
    }

    /// Half a day of engineers on the instability: finds the cause and fixes it for the rest of the run (spikes about
    /// 45% less likely).
    static func investigate(_ s: inout GameState, _ i: Int) -> String {
        let perDay = Training.dailyFlops(s.runs[i], state: s)
        TrainingExperience.rewound(&s, i, min(s.runs[i].flopsDone, perDay * 0.5))
        s.runs[i].flopsDone = max(0, s.runs[i].flopsDone - perDay * 0.5)
        s.runs[i].investigated = true
        s.runs[i].stabilised = true
        let (cause, fix) = instabilityCause(s.runs[i].design, s)
        let text = "Cause: \(cause) Fix: \(fix)"
        Training.runLog(&s, i, "Instability investigation. \(text)")
        return text
    }

    // MARK: Red-teaming the RL environments

    static func redTeamBlocker(_ s: GameState, _ run: TrainingRun) -> String? {
        guard run.design.reasoning, s.bonuses.has(.reasoning) else { return "This run has no reasoning RL." }
        if run.redTeamed { return "Already red-teamed." }
        guard let idx = run.stages.firstIndex(where: { $0.name == "Reasoning RL" }) else { return "This run has no reasoning RL." }
        if run.status == .postTraining && run.stageIndex >= idx { return "Reasoning RL has already started." }
        if run.status == .done || run.status == .cancelled { return "The run is over." }
        return nil
    }

    /// Red-teams the reward environments before reasoning RL starts: the stage takes 5% longer, and the model is about
    /// 70% less likely to learn to game its graders.
    static func redTeam(_ s: inout GameState, _ i: Int) {
        guard let idx = s.runs[i].stages.firstIndex(where: { $0.name == "Reasoning RL" }) else { return }
        let extra = s.runs[i].stages[idx].flops * 0.05
        s.runs[i].stages[idx].flops += extra
        s.runs[i].postTrainFlops += extra
        s.runs[i].redTeamed = true
        Training.runLog(&s, i, "Red team assigned to the reasoning-RL environments: graders hardened before the stage starts.")
    }

    // MARK: Ending or extending pre-training

    struct StopPreview {
        /// Projected index if pre-training ended today, and if it ran as planned.
        var indexNow: Double
        var indexPlanned: Double
        /// The 80% range of the index if it ended today: what the checkpoints so far can't yet tell apart.
        var indexLow: Double
        var indexHigh: Double
        /// The capability (log10 effective compute) it would end at, and its uncertainty (1σ).
        var c: Double
        var sigma: Double
        /// Days and money the rest of pre-training would take.
        var daysLeft: Double
        var costLeft: Double
        /// Quality lost by stopping before the learning rate decayed (cosine without an annealing stage).
        var schedulePenalty: Double
        /// Compute the decay phase adds when ending early (WSD and annealed runs decay instead of stopping cold).
        var decayShare: Double
    }

    /// How a run ends its pre-training early: with annealing it decays over a final 8% (as planned); with WSD it
    /// decays over 5% from wherever it is; a plain cosine schedule stops with its learning rate still high.
    static func stopPlan(_ run: TrainingRun, _ s: GameState) -> (decay: Double, penalty: Double) {
        let d = run.design
        let b = s.bonuses
        let p = run.progress
        if d.anneal && b.has(.curriculum) && d.mode == .scratch { return (0.08, 0) }
        if d.schedule == .wsd && b.has(.wsd) { return (0.05, 0) }
        return (0, 0.03 * clamp((1 - p) / 0.7, 0, 1))
    }

    static func endEarlyBlocker(_ s: GameState, _ run: TrainingRun) -> String? {
        guard run.kind == .full, run.status == .running else { return "Only a run in pre-training can end early." }
        if run.progress < 0.3 { return "Too early: end pre-training after 30% at the soonest." }
        if run.progress > 0.9 { return "It's nearly done; let it finish." }
        if run.endedEarlyAt > 0 { return "Already ended early." }
        return nil
    }

    static func stopPreview(_ s: GameState, _ run: TrainingRun) -> StopPreview? {
        guard run.kind == .full, run.status == .running, let fc = run.forecast else { return nil }
        let p = run.progress
        let plan = stopPlan(run, s)
        var partial = run.design
        partial.tokensT = max(run.design.tokensT * p, 0.0001)
        let f = Training.forecast(partial, run, s)
        let known = -run.qualityPenalty - plan.penalty + run.lrCredit - (run.bugFound ? run.bugPenalty * 0.25 : 0)
        let c = f.c + run.revealMean + known
        let set = Leaderboard.indexSet(s)
        let extra = (run.dReasoning, run.dCode, run.dChat, run.dSafety, run.dLang)
        func idx(_ c: Double, _ k: String) -> Double {
            ForecastEngine.index(ForecastEngine.profile(f, design: partial, key: k, c: c, extra: extra), set: set)
        }
        let now = idx(c, "stop")
        let sd = max(run.revealSigma, 0.01)
        let planned = Training.projectedIndex(s, run).0
        let perDay = Training.dailyFlops(run, state: s) * Sim.checkpointOverhead(run.interval)
        let left = max(0, run.flopsTotal - run.flopsDone)
        let days = perDay > 0 ? left / perDay : .infinity
        let chipDay = HardwareCatalog.get(run.design.accelID).map { Economy.chipDailyCost($0, count: run.design.chips, state: s) } ?? 0
        _ = fc
        return StopPreview(indexNow: now, indexPlanned: planned, indexLow: idx(c - 1.28 * sd, "stopl"), indexHigh: idx(c + 1.28 * sd, "stoph"),
                           c: c, sigma: sd, daysLeft: days, costLeft: days.isFinite ? days * chipDay : .infinity,
                           schedulePenalty: plan.penalty, decayShare: plan.decay)
    }

    /// What extending pre-training by `x` would give: the projected index, and the extra days and money.
    static func extendPreview(_ s: GameState, _ run: TrainingRun, by x: Double) -> (index: Double, days: Double, cost: Double)? {
        guard run.kind == .full, run.status == .running, run.forecast != nil else { return nil }
        let wsd = run.design.schedule == .wsd && s.bonuses.has(.wsd)
        var longer = run.design
        longer.tokensT *= 1 + x
        let f = Training.forecast(longer, run, s)
        let known = -run.qualityPenalty - (wsd ? 0 : 0.01) + run.lrCreditAtEnd - (run.bugFound ? run.bugPenalty * 0.25 : 0)
        let extra = (run.dReasoning, run.dCode, run.dChat, run.dSafety, run.dLang)
        let index = ForecastEngine.index(ForecastEngine.profile(f, design: longer, key: "extend", c: f.c + run.revealMean + known, extra: extra),
                                         set: Leaderboard.indexSet(s))
        let perDay = Training.dailyFlops(run, state: s) * Sim.checkpointOverhead(run.interval)
        let days = perDay > 0 ? run.flopsTotal * x * (wsd ? 1 : 1.02) / perDay : .infinity
        let chipDay = HardwareCatalog.get(run.design.accelID).map { Economy.chipDailyCost($0, count: run.design.chips, state: s) } ?? 0
        return (index, days, days.isFinite ? days * chipDay : .infinity)
    }

    /// Re-plans a run for a new pre-training total: the design's tokens, the stages, the forecast and every fraction the
    /// run keeps (checkpoints, the learning-rate credit, a silent bug's onset) move to the new scale. The run's luck
    /// stays what it was.
    static func rescale(_ s: inout GameState, _ i: Int, newTotal: Double) {
        let old = s.runs[i].flopsTotal
        guard old > 0, newTotal > 0 else { return }
        let k = old / newTotal
        let b = s.bonuses
        s.runs[i].design.tokensT *= newTotal / old
        s.runs[i].flopsTotal = newTotal
        s.runs[i].lrCredit *= k
        s.runs[i].lrCreditTo *= k
        for j in s.runs[i].saved.indices {
            s.runs[i].saved[j].fraction *= k
            s.runs[i].saved[j].lrCredit = s.runs[i].saved[j].lrCredit.map { $0 * k }
        }
        if s.runs[i].bugOnset < 2 {
            s.runs[i].bugOnset *= k
            if s.runs[i].bugOnset >= 1 { s.runs[i].bugPenalty = 0 }   // stopped before the bug would have struck
        }
        s.runs[i].stages = Training.stages(s.runs[i].design, pretrain: newTotal, bonuses: b)
        s.runs[i].postTrainFlops = s.runs[i].stages.filter { !$0.isPre }.reduce(0) { $0 + $1.flops }
        // The forecast for what the run now is.
        let d = s.runs[i].design
        let f = Training.forecast(d, s.runs[i], s)
        var withLR = f
        let lr = s.runs[i].forecast?.lrBonus ?? 0
        withLR.c += lr
        let set = Leaderboard.indexSet(s)
        let band = ForecastEngine.indexBand(withLR, design: d, set: set)
        let top = Leaderboard.entries(s, set: set, includeUnreleased: false).filter { !$0.isPlayer }.map(\.index).max() ?? 0
        s.runs[i].forecast = RunForecast(c: withLR.c, sigma: f.sigma, index: band.mean, indexLow: band.low, indexHigh: band.high,
                                         tier: ForecastEngine.tier(index: band.mean, top: top),
                                         comparable: RealModels.closest(index: band.mean, set: set).map { "\($0.name) (\($0.lab), \($0.date.label))" } ?? "—",
                                         finalLoss: f.finalLoss, lrBonus: lr)
    }

    /// Ends pre-training now: what's trained is kept, the learning rate decays as the schedule allows, and post-training
    /// follows on the smaller pre-training budget.
    static func endEarly(_ s: inout GameState, _ i: Int) -> String {
        let p = s.runs[i].progress
        let plan = stopPlan(s.runs[i], s)
        let done = s.runs[i].flopsDone
        rescale(&s, i, newTotal: done / (1 - plan.decay))
        s.runs[i].endedEarlyAt = p
        if plan.penalty > 0 {
            s.runs[i].qualityPenalty += plan.penalty
            s.runs[i].penaltySchedule += plan.penalty
        }
        Training.creditLR(&s.runs[i])
        let how = plan.decay > 0 ? "A \(Int(plan.decay * 100))% decay phase finishes it properly." : "The cosine schedule stops with its learning rate still high (×\(Fmt.trim(pow(10, -plan.penalty), 3)) quality)."
        let text = "Pre-training ended at \(Int((p * 100).rounded()))%: \(Fmt.tokens(s.runs[i].design.tokensT)) tokens. \(how)"
        Training.runLog(&s, i, text)
        return text
    }

    static func extendBlocker(_ s: GameState, _ run: TrainingRun, by x: Double) -> String? {
        guard run.kind == .full, run.status == .running else { return "Only a run in pre-training can be extended." }
        if run.progress > 0.85 { return "Too late: the schedule is already decaying." }
        if run.endedEarlyAt > 0 { return "This run already ended early." }
        let cap = Physics.maxTokensT(run.design, state: s)
        if run.design.tokensT * (1 + x) > cap * 1.001 { return "That's more than the \(Fmt.tokens(cap)) of tokens your data supports." }
        return nil
    }

    /// Extends pre-training by `x` (0.25 = a quarter more tokens). WSD just keeps going; a cosine schedule has to be
    /// re-warmed, which costs 2% more compute and a little quality.
    static func extend(_ s: inout GameState, _ i: Int, by x: Double) -> String {
        let wsd = s.runs[i].design.schedule == .wsd && s.bonuses.has(.wsd)
        let old = s.runs[i].flopsTotal
        rescale(&s, i, newTotal: old * (1 + x) * (wsd ? 1 : 1.02))
        s.runs[i].extendedBy += x
        if !wsd {
            s.runs[i].qualityPenalty += 0.01
            s.runs[i].penaltySchedule += 0.01
        }
        Training.creditLR(&s.runs[i])
        let text = "Pre-training extended by \(Int((x * 100).rounded()))% to \(Fmt.tokens(s.runs[i].design.tokensT)) tokens"
            + (wsd ? ": WSD carries on at its stable learning rate." : ": the cosine schedule was re-warmed (2% more compute, ×0.977 quality).")
        Training.runLog(&s, i, text)
        return text
    }
}

extension GameState {
    mutating func diagnoseRun(_ id: UUID) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if let why = TrainingInterventions.diagnoseBlocker(self, runs[i]) { return why }
        _ = TrainingInterventions.diagnose(&self, i)
        return nil
    }

    mutating func investigateRun(_ id: UUID) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if let why = TrainingInterventions.investigateBlocker(self, runs[i]) { return why }
        _ = TrainingInterventions.investigate(&self, i)
        return nil
    }

    mutating func redTeamRun(_ id: UUID) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if let why = TrainingInterventions.redTeamBlocker(self, runs[i]) { return why }
        TrainingInterventions.redTeam(&self, i)
        return nil
    }

    mutating func endPretrainingEarly(_ id: UUID) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if let why = TrainingInterventions.endEarlyBlocker(self, runs[i]) { return why }
        _ = TrainingInterventions.endEarly(&self, i)
        return nil
    }

    mutating func extendRun(_ id: UUID, by x: Double) -> String? {
        guard let i = runs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if let why = TrainingInterventions.extendBlocker(self, runs[i], by: x) { return why }
        _ = TrainingInterventions.extend(&self, i, by: x)
        return nil
    }
}
