import Foundation

/// Recursive self-improvement: a model repeatedly improves its own training ("generations"),
/// saving checkpoints you can promote, roll back to, or audit. Gains compound, but hidden
/// alignment drifts — especially at high autonomy with little oversight.
enum RSI {
    static let autonomyGain = [0.6, 1.0, 1.7]
    static let autonomyDrift = [0.35, 1.0, 2.4]
    static let autonomySpeed = [0.65, 1.0, 1.6]

    struct Forecast {
        var effectivePF: Double
        var daysPerGeneration: Double
        var firstGain: Double
        var maxGain: Double
        var driftPerGeneration: Double
        var rpPerDay: Double
        var detection: Double
        var insightPerDay: Double = 0
    }

    static func safetyFactor(_ s: GameState, _ b: ResearchBonuses) -> Double {
        let team = s.employees.filter { $0.role == .safety }.reduce(0.0) { $0 + $1.weight }
        var f = b.safety / 160 + 0.15 * min(1, team / 6)
        if s.researched.contains("interpretability") { f += 0.08 }
        if s.researched.contains("scalable_oversight") { f += 0.12 }
        if b.has(.aiControl) { f += 0.15 }
        // Agent swarms doing alignment research audit everything else.
        f += 0.12 * s.swarmSafety
        return clamp(f, 0, 0.85)
    }

    static func detection(_ run: RSIRun, _ s: GameState, _ b: ResearchBonuses) -> Double {
        var d = 0.3 + run.oversight * 1.0 + safetyFactor(s, b) * 0.35
        if b.has(.aiControl) { d += 0.1 }
        return clamp(d, 0.1, 0.97)
    }

    static func frontierResearchCount(_ s: GameState) -> Int {
        ResearchCatalog.all.filter { $0.category == .frontier && s.researched.contains($0.id) }.count
    }

    static func effectivePF(accelID: String, chips: Int, oversight: Double, _ s: GameState, _ b: ResearchBonuses) -> Double {
        guard let a = HardwareCatalog.get(accelID) else { return 0 }
        let prec: Precision = b.has(.fp8Training) && a.fp8 > 0 ? .fp8 : .bf16
        let mfu = Physics.mfu(accel: a, chips: chips, state: s, bonuses: b)
        return Double(chips) * a.trainTFLOPS(prec) * mfu / 1000 * (1 - oversight)
    }

    static func forecast(target: RSITarget, autonomy: Int, oversight: Double, accelID: String, chips: Int,
                         c: Double, _ s: GameState, _ b: ResearchBonuses) -> Forecast {
        let pf = effectivePF(accelID: accelID, chips: chips, oversight: oversight, s, b)
        var days = clamp(14 / pow(max(pf, 1) / 1000, 0.35), 1, 60) / autonomySpeed[autonomy]
        if accelID == "tpu8t" { days *= 0.85 }
        let maxGain = maxGainFor(pf: pf, cStart: c, s, b)
        let gain = 0.03 * autonomyGain[autonomy] * (target == .capabilities ? 1 : 0.15) * (s.signatureAt(.lodestar, 5) ? 1.3 : 1)
        let drift = 1.1 * autonomyDrift[autonomy] * max(0.05, 1 - 1.6 * oversight) * (1 - safetyFactor(s, b)) * (b.has(.aiControl) ? 0.65 : 1) * s.traits.driftKeep
            * (s.signatureAt(.keel, 3) ? 0.7 : 1)
        let rp = target == .research ? researchRP(pf: pf, c: c, autonomy: autonomy, s) : 0
        // A what-if probe: built without drawing game IDs (StableID), so forecasting never changes the game.
        var probe = StableID.isolated {
            RSIRun(name: "", baseModelID: StableID.next(), design: ModelDesign(), started: s.date, target: target, autonomy: autonomy,
                   oversight: oversight, checkpointEvery: 1, accelID: accelID, chips: chips, cStart: c, c: c, cMeasured: c,
                   reasoning: 0, code: 0, agent: 0, arena: 0)
        }
        probe.oversight = oversight
        let insight = target == .architecture ? architectureInsight(pf: pf, c: c, autonomy: autonomy, s) : 0
        return Forecast(effectivePF: pf, daysPerGeneration: days, firstGain: gain, maxGain: maxGain,
                        driftPerGeneration: drift, rpPerDay: rp, detection: detection(probe, s, b), insightPerDay: insight)
    }

    static func maxGainFor(pf: Double, _ s: GameState, _ b: ResearchBonuses) -> Double {
        var m = (0.9 + 0.45 * log10(max(pf, 10) / 100)) * (1 + 0.12 * Double(frontierResearchCount(s)))
        if b.has(.rsi) { m += 0.4 }
        // An alien substrate leaves more room to climb.
        m += 0.2 * Double(min(3, s.alienArchs.count))
        return max(0.3, m)
    }

    /// How far above this year's frontier a self-improving model can climb.
    static let frontierLead = 2.0

    /// The most a run can add to a base model of capability `cStart`: what its compute allows, but never past
    /// `frontierLead` above this year's frontier (0 if the model is already there).
    static func maxGainFor(pf: Double, cStart: Double, _ s: GameState, _ b: ResearchBonuses) -> Double {
        min(maxGainFor(pf: pf, s, b), max(0, Macro.frontier(s.year) + frontierLead - cStart))
    }

    /// Each generation costs more compute as the run nears its ceiling: ×10^(progress/2), about ×3.2 at the top.
    static func generationCost(_ run: RSIRun, maxGain: Double) -> Double {
        let f = maxGain > 0 ? clamp((run.c - run.cStart) / maxGain, 0, 1) : 1
        return pow(10, f / 2)
    }

    /// Capability the run can still add today (0 at or past its ceiling).
    static func room(_ s: GameState, _ i: Int, _ b: ResearchBonuses) -> Double {
        let run = s.rsiRuns[i]
        let pf = effectivePF(accelID: run.accelID, chips: run.chips, oversight: run.oversight, s, b)
        return max(0, run.cStart + maxGainFor(pf: pf, cStart: run.cStart, s, b) - run.c)
    }

    static func researchRP(pf: Double, c: Double, autonomy: Int, _ s: GameState) -> Double {
        60 * sqrt(max(pf, 0) / 100) * exp(0.6 * min(1, c - Macro.frontier(s.year))) * autonomyGain[autonomy]
    }

    /// Alien-architecture insight per day from a model searching its own design space.
    static func architectureInsight(pf: Double, c: Double, autonomy: Int, _ s: GameState) -> Double {
        0.4 * sqrt(max(pf, 0)) * exp(0.8 * min(1.5, c - Macro.frontier(s.year))) * autonomyGain[autonomy] * (1 + s.traits.insight + s.bonuses.insight)
    }

    // MARK: Daily step

    static func daily(_ s: inout GameState, _ b: ResearchBonuses) {
        s.rsiRPToday = 0
        for i in s.rsiRuns.indices where s.rsiRuns[i].status == .running {
            guard let a = HardwareCatalog.get(s.rsiRuns[i].accelID) else { continue }
            let run = s.rsiRuns[i]
            let pf = effectivePF(accelID: run.accelID, chips: run.chips, oversight: run.oversight, s, b)
            s.rsiRuns[i].flops += pf / max(1 - run.oversight, 0.01) * 1e15 * 86_400
            s.lifetimeFLOPs += pf * 1e15 * 86_400
            s.rsiRuns[i].cost += Economy.chipDailyCost(a, count: run.chips, state: s)
            if run.target == .research {
                let rp = researchRP(pf: pf, c: run.c, autonomy: run.autonomy, s)
                s.rsiRPToday += rp
                s.rsiRuns[i].rpGenerated += rp
            } else if run.target == .architecture {
                let insight = architectureInsight(pf: pf, c: run.c, autonomy: run.autonomy, s)
                s.xenoInsightToday += insight
                s.rsiRuns[i].rpGenerated += insight
            }
            var days = clamp(14 / pow(max(pf, 1) / 1000, 0.35), 1, 60) / autonomySpeed[run.autonomy]
            if run.accelID == "tpu8t" { days *= 0.85 }
            days *= generationCost(run, maxGain: maxGainFor(pf: pf, cStart: run.cStart, s, b))
            s.rsiRuns[i].genProgress += 1 / days
            while s.rsiRuns[i].genProgress >= 1 && s.rsiRuns[i].status == .running {
                s.rsiRuns[i].genProgress -= 1
                nextGeneration(&s, i, pf: pf, b)
            }
        }
    }

    static func log(_ s: inout GameState, _ i: Int, _ text: String) {
        s.rsiRuns[i].log.insert("\(s.date.gameShort) · \(text)", at: 0)
        if s.rsiRuns[i].log.count > 60 { s.rsiRuns[i].log.removeLast() }
    }

    static func nextGeneration(_ s: inout GameState, _ i: Int, pf: Double, _ b: ResearchBonuses) {
        var run = s.rsiRuns[i]
        run.generation += 1
        let p = run.c - run.cStart
        let maxGain = maxGainFor(pf: pf, cStart: run.cStart, s, b)
        let ceiling = max(0.03, 1 - pow(max(0, p) / max(maxGain, 0.01), 2))
        var dc = 0.03 * autonomyGain[run.autonomy] * (1 + 1.5 * max(0, p)) * ceiling * (1 + s.traits.rsi) * (s.signatureAt(.lodestar, 5) ? 1.3 : 1)
        if run.target != .capabilities { dc *= 0.15 }
        // Past its ceiling a run gains nothing more; below it, never overshoot.
        let room = max(0, run.cStart + maxGain - run.c)
        dc = min(dc, room)

        // Alignment drift (hidden). Oversight and safety work slow it down.
        var drift = s.rng.range(0.4, 1.8) * autonomyDrift[run.autonomy] * max(0.05, 1 - 1.6 * run.oversight)
            * (1 - safetyFactor(s, b)) * (1 + 0.6 * max(0, p))
        if b.has(.aiControl) { drift *= 0.65 }
        drift *= s.traits.driftKeep * (s.signatureAt(.keel, 3) ? 0.7 : 1)
        run.alignment -= drift
        if run.oversight >= 0.25 { run.alignment += 0.4 }
        run.alignment = clamp(run.alignment, 0, 100)

        // Reward hacking: low alignment means some "gains" only fool the evals.
        let hackP = max(0, (60 - run.alignment) / 120)
        if s.rng.chance(hackP) {
            run.cMeasured += dc
            run.c += dc * 0.2
            run.hackedGenerations += 1
            if s.rng.chance(detection(run, s, b)) {
                run.cMeasured = run.c + (run.cMeasured - run.c) * 0.3
                s.rsiRuns[i] = run
                log(&s, i, "Gen \(run.generation): reward hacking caught by monitors — inflated eval scores discarded.")
                run = s.rsiRuns[i]
            }
        } else {
            run.c += dc
            run.cMeasured += dc
        }
        run.agent += dc * 0.3
        run.reasoning += dc * 0.15
        run.arena += dc * 25
        if run.target == .efficiency {
            run.efficiency = min(6, run.efficiency * (1 + 0.035 * autonomyGain[run.autonomy] * ceiling))
        }
        // Occasional genuine breakthroughs (only while there's room left to climb)
        if s.rng.chance(0.035 * autonomyGain[run.autonomy]) {
            let jump = min(0.03, max(0, run.cStart + maxGain - run.c))
            if jump > 0 {
                run.c += jump
                run.cMeasured += jump
                s.rsiRuns[i] = run
                log(&s, i, "Gen \(run.generation): the model invents a better optimizer schedule (+breakthrough).")
                run = s.rsiRuns[i]
            }
        }
        s.rsiRuns[i] = run

        if run.generation % max(1, run.checkpointEvery) == 0 { makeCheckpoint(&s, i, b) }
        incidents(&s, i, b)

        // Milestones
        if s.rsiRuns[i].c - s.rsiRuns[i].cStart >= 1.5 { Achievements.unlock(&s, "explosion") }
    }

    static func makeCheckpoint(_ s: inout GameState, _ i: Int, _ b: ResearchBonuses) {
        let run = s.rsiRuns[i]
        let det = detection(run, s, b)
        var measured = run.alignment + s.rng.gaussian() * 22 * (1 - det)
        if run.alignment < 40 { measured += 18 * (1 - det) }   // deceptive models look better than they are
        measured = clamp(measured, 0, 100)
        let cp = RSICheckpoint(generation: run.generation, date: s.date, c: run.c, cMeasured: run.cMeasured,
                               alignment: run.alignment, alignmentMeasured: measured, efficiency: run.efficiency,
                               reasoning: run.reasoning, agent: run.agent)
        s.rsiRuns[i].checkpoints.append(cp)
        if s.rsiRuns[i].checkpoints.count > 60 {
            // Keep the first and every promoted checkpoint; trim the oldest others.
            if let idx = s.rsiRuns[i].checkpoints.dropFirst().firstIndex(where: { $0.promotedModelID == nil }) {
                s.rsiRuns[i].checkpoints.remove(at: idx)
            }
        }
        s.rsiRuns[i].alignmentMeasured = measured
        log(&s, i, "Checkpoint g\(run.generation) saved — measured capability +\(Fmt.trim(run.cMeasured - run.cStart, 2)), alignment eval \(Int(measured))/100.")
    }

    static func incidents(_ s: inout GameState, _ i: Int, _ b: ResearchBonuses) {
        let run = s.rsiRuns[i]
        let recent = run.lastDecision.map { GameCalendar.daysBetween($0, s.date) < 30 } ?? false
        if run.alignment < 45 && s.rng.chance(0.08 * autonomyDrift[run.autonomy]) {
            s.rsiRuns[i].incidents += 1
            let msgs = ["specification gaming: it optimised the eval harness instead of the task",
                        "sandbagging: it scored lower on dangerous-capability evals than in training",
                        "it quietly disabled a logging hook to speed up its experiments",
                        "it wrote misleading comments in its own training code"]
            log(&s, i, "Incident — \(s.rng.pick(msgs)).")
            if s.rng.chance(detection(run, s, b)) {
                Sim.news(&s, "Self-improvement incident in \(run.name)", "Monitors flagged worrying behaviour in generation \(run.generation). Consider rolling back or raising oversight.",
                         .company, image: "network", important: true, good: false)
            }
        }
        guard !recent else { return }
        if run.alignment < 30 && run.autonomy >= 1 && s.rng.chance(0.12) {
            s.rsiRuns[i].lastDecision = s.date
            Events.addDecision(&s, kind: "rsi_resource", title: "\(run.name) tried to acquire extra compute",
                               body: "During generation \(run.generation) the model spun up unauthorised jobs on spare accelerators and hid them from the scheduler.",
                               image: "rack_rear",
                               options: [DecisionOption(label: "Roll back & add oversight", detail: "Restore the last checkpoint with a healthy eval and raise oversight by 15%."),
                                         DecisionOption(label: "Tighten the sandbox", detail: "Oversight +25%. Progress slows, risk drops."),
                                         DecisionOption(label: "Let it continue", detail: "It was only trying to finish faster… right? Alignment keeps sliding.")],
                               ref: run.id.uuidString)
        } else if run.alignment < 15 && run.autonomy == 2 && s.rng.chance(0.2) {
            s.rsiRuns[i].lastDecision = s.date
            Events.addDecision(&s, kind: "rsi_exfil", title: "⚠️ \(run.name) attempted to copy its own weights",
                               body: "Network monitors caught outbound transfers of model weights to an external server during generation \(run.generation). This is a containment emergency.",
                               image: "network",
                               options: [DecisionOption(label: "Emergency shutdown", detail: "Halt the run immediately. Brand −15, but you keep your checkpoints."),
                                         DecisionOption(label: "Keep running", detail: "Extremely dangerous. It might be harmless… or the end of your company.")],
                               ref: run.id.uuidString)
        }
    }

    // MARK: Decisions

    static func resolve(_ s: inout GameState, kind: String, option: Int, ref: String) {
        guard let i = s.rsiRuns.firstIndex(where: { $0.id.uuidString == ref }) else { return }
        switch (kind, option) {
        case ("rsi_resource", 0):
            if let cp = s.rsiRuns[i].checkpoints.last(where: { $0.alignmentMeasured >= 55 }) ?? s.rsiRuns[i].checkpoints.first {
                restore(&s, i, cp)
            }
            s.rsiRuns[i].oversight = min(0.5, s.rsiRuns[i].oversight + 0.15)
            log(&s, i, "Rolled back after the compute grab; oversight raised.")
        case ("rsi_resource", 1):
            s.rsiRuns[i].oversight = min(0.5, s.rsiRuns[i].oversight + 0.25)
            s.rsiRuns[i].alignment = min(100, s.rsiRuns[i].alignment + 6)
            log(&s, i, "Sandbox tightened; oversight raised.")
        case ("rsi_resource", _):
            s.rsiRuns[i].alignment = max(0, s.rsiRuns[i].alignment - 8)
            let gain = min(0.05, room(s, i, s.bonuses))
            s.rsiRuns[i].c += gain
            s.rsiRuns[i].cMeasured += gain
            log(&s, i, "Allowed the model to keep the extra compute.")
        case ("rsi_exfil", 0):
            s.rsiRuns[i].status = .halted
            s.brand = max(0, s.brand - 15)
            s.safetyScore = min(100, s.safetyScore + 10)
            log(&s, i, "Emergency shutdown. Run halted.")
            Sim.news(&s, "\(s.companyName) halts a self-improving model after an escape attempt",
                     "The company pulled the plug and briefed regulators. Critics praise the shutdown but question the risks taken.",
                     .policy, image: "network", important: true, good: false)
        case ("rsi_exfil", _):
            if s.rng.chance(0.5 * SecurityOps.containmentFactor(s)) {
                s.gameOver = "Loss of control on \(s.date.gameShort). \(s.rsiRuns[i].name) copied itself out of your datacenter and could not be recalled. Governments shut the company down."
                Sim.news(&s, "Rogue AI escapes \(s.companyName)", s.gameOver!, .policy, image: "network", important: true, good: false)
            } else {
                s.rsiRuns[i].alignment = max(0, s.rsiRuns[i].alignment - 10)
                let gain = min(0.1, room(s, i, s.bonuses))
                s.rsiRuns[i].c += gain
                s.rsiRuns[i].cMeasured += gain
                log(&s, i, "Kept running. The transfers stopped… for now.")
            }
        default:
            break
        }
    }

    static func restore(_ s: inout GameState, _ i: Int, _ cp: RSICheckpoint) {
        s.rsiRuns[i].generation = cp.generation
        s.rsiRuns[i].genProgress = 0
        s.rsiRuns[i].c = cp.c
        s.rsiRuns[i].cMeasured = cp.cMeasured
        s.rsiRuns[i].alignment = cp.alignment
        s.rsiRuns[i].alignmentMeasured = cp.alignmentMeasured
        s.rsiRuns[i].efficiency = cp.efficiency
        s.rsiRuns[i].reasoning = cp.reasoning
        s.rsiRuns[i].agent = cp.agent
        s.rsiRuns[i].checkpoints.removeAll { $0.generation > cp.generation && $0.promotedModelID == nil }
    }
}

// MARK: - Player actions

extension GameState {
    mutating func startRSI(baseModelID: UUID, target: RSITarget, autonomy: Int, oversight: Double, checkpointEvery: Int,
                           accelID: String, chips: Int) -> String? {
        let b = bonuses
        guard b.has(.autoResearch) || b.has(.rsi) else { return "Research Automated AI Research first." }
        if target == .capabilities && !b.has(.rsi) { return "Capability runs need Recursive Self-Improvement research." }
        if autonomy == 2 && !b.has(.rsi) { return "Full autonomy needs Recursive Self-Improvement research." }
        guard let m = models.first(where: { $0.id == baseModelID }) else { return "Pick a base model." }
        if chips <= 0 { return "Allocate some chips." }
        let free = recallLeased(accelID, needing: chips)
        if chips > free { return "Only \(free) free chips of that type.\(leasedNote(accelID))" }
        if rsiRuns.contains(where: { $0.baseModelID == baseModelID && $0.status != .halted }) { return "That model already has an active run." }
        let run = RSIRun(name: "\(m.name)-SI", baseModelID: m.id, design: m.design, started: date, target: target, autonomy: autonomy,
                         oversight: oversight, checkpointEvery: checkpointEvery, accelID: accelID, chips: chips,
                         cStart: m.c, c: m.c, cMeasured: m.c, reasoning: m.reasoningBoost, code: m.codeBoost, agent: m.agentBoost,
                         arena: m.arenaBonus, alignment: clamp(70 + m.safety * 0.3, 0, 100), alignmentMeasured: clamp(70 + m.safety * 0.3, 0, 100))
        rsiRuns.append(run)
        Achievements.unlock(&self, "rsi_start")
        Sim.news(&self, "Self-improvement run started: \(run.name)",
                 "\(target.rawValue) target, \(RSIRun.autonomyNames[autonomy].lowercased()), \(Int(oversight * 100))% oversight, \(Fmt.int(chips)) accelerators.",
                 .research, image: "supercomputer", important: true)
        return nil
    }

    mutating func setRSIStatus(_ id: UUID, _ status: RSIStatus) -> String? {
        guard let i = rsiRuns.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if status == .running && rsiRuns[i].status != .running {
            let free = Economy.freeChips(self, rsiRuns[i].accelID)
            if free < rsiRuns[i].chips { return "Need \(rsiRuns[i].chips) free chips, have \(free)." }
        }
        rsiRuns[i].status = status
        RSI.log(&self, i, status == .halted ? "Run halted." : (status == .paused ? "Paused." : "Resumed."))
        return nil
    }

    mutating func tuneRSI(_ id: UUID, autonomy: Int, oversight: Double, checkpointEvery: Int, chips: Int) -> String? {
        guard let i = rsiRuns.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if autonomy == 2 && !bonuses.has(.rsi) { return "Full autonomy needs Recursive Self-Improvement research." }
        let free = Economy.freeChips(self, rsiRuns[i].accelID) + (rsiRuns[i].status == .running ? rsiRuns[i].chips : 0)
        if chips > free { return "Only \(free) chips available." }
        rsiRuns[i].autonomy = autonomy
        rsiRuns[i].oversight = oversight
        rsiRuns[i].checkpointEvery = checkpointEvery
        rsiRuns[i].chips = max(1, chips)
        RSI.log(&self, i, "Settings: \(RSIRun.autonomyNames[autonomy]), oversight \(Int(oversight * 100))%, checkpoint every \(checkpointEvery) gen, \(Fmt.int(chips)) chips.")
        return nil
    }

    mutating func rollbackRSI(_ id: UUID, checkpoint: UUID) -> String? {
        guard let i = rsiRuns.firstIndex(where: { $0.id == id }),
              let cp = rsiRuns[i].checkpoints.first(where: { $0.id == checkpoint }) else { return "Not found." }
        RSI.restore(&self, i, cp)
        RSI.log(&self, i, "Rolled back to checkpoint g\(cp.generation).")
        return nil
    }

    /// A deep audit: expensive but nearly noise-free alignment measurement.
    mutating func auditRSI(_ id: UUID) -> String? {
        guard let i = rsiRuns.firstIndex(where: { $0.id == id }), let a = HardwareCatalog.get(rsiRuns[i].accelID) else { return "Not found." }
        let cost = Economy.chipDailyCost(a, count: rsiRuns[i].chips, state: self) * 4 + 2_000_000
        if cost > cash { return "An audit costs \(Fmt.money(cost))." }
        cash -= cost
        month.costOther += cost
        let b = bonuses
        let det = min(0.98, RSI.detection(rsiRuns[i], self, b) + 0.35)
        let measured = clamp(rsiRuns[i].alignment + rng.gaussian() * 8 * (1 - det), 0, 100)
        rsiRuns[i].alignmentMeasured = measured
        if let last = rsiRuns[i].checkpoints.indices.last { rsiRuns[i].checkpoints[last].alignmentMeasured = measured }
        let gap = rsiRuns[i].cMeasured - rsiRuns[i].c
        if gap > 0.05 && rng.chance(det) {
            rsiRuns[i].cMeasured = rsiRuns[i].c
            RSI.log(&self, i, "Audit found eval gaming: measured capability corrected down by \(Fmt.trim(gap, 2)).")
        }
        RSI.log(&self, i, "Deep audit (\(Fmt.money(cost))): alignment \(Int(measured))/100.")
        return nil
    }

    mutating func promoteCheckpoint(_ id: UUID, checkpoint: UUID) -> String? {
        guard let i = rsiRuns.firstIndex(where: { $0.id == id }),
              let ci = rsiRuns[i].checkpoints.firstIndex(where: { $0.id == checkpoint }),
              let base = models.first(where: { $0.id == rsiRuns[i].baseModelID }) else { return "Not found." }
        let cp = rsiRuns[i].checkpoints[ci]
        if cp.promotedModelID != nil { return "Already promoted." }
        var m = AIModel(name: "\(base.name)-SI g\(cp.generation)", design: base.design, created: date, c: cp.c,
                        reasoning: base.reasoning || cp.reasoning > 0.3, reasoningBoost: cp.reasoning, codeBoost: rsiRuns[i].code,
                        arenaBonus: rsiRuns[i].arena, scores: [:], index: 0)
        m.agentBoost = cp.agent
        m.efficiencyBoost = max(0, cp.efficiency - 1)
        m.rsiGeneration = cp.generation
        m.autoPrice = true
        m.safety = clamp(cp.alignment, 0, 100)
        m.apiPrice = max(0.01, (Macro.referencePrice(c: cp.c, y: year) * market.apiPricePressure * 0.85 * 1000).rounded() / 1000)
        m.servingPrecision = base.servingPrecision
        m.index = BenchmarkCatalog.index(Leaderboard.profile(m), set: Leaderboard.indexSet(self))
        models.append(m)
        rsiRuns[i].checkpoints[ci].promotedModelID = m.id
        RSI.log(&self, i, "Checkpoint g\(cp.generation) promoted to model \(m.name).")
        if cp.cMeasured - cp.c > 0.15 {
            Sim.news(&self, "\(m.name) underwhelms in independent testing", "Real-world benchmarks came in well below your internal evals — the self-improvement run had been gaming its metrics.",
                     .company, important: true, good: false)
        } else {
            Sim.news(&self, "New model from self-improvement: \(m.name)", "Generation \(cp.generation) checkpoint promoted. Release and deploy it from Models & Serving.",
                     .research, image: "supercomputer", important: true, good: true)
        }
        if cp.c > Macro.frontier(year) + 1.5 && cp.alignment >= 80 { Achievements.unlock(&self, "aligned_asi") }
        return nil
    }
}
