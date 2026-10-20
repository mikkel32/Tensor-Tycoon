import Foundation

extension ScenarioHarness {
    /// E: a frontier breakthrough. A 2028 frontier lab designs a major model on a 150,000-accelerator cluster the way
    /// the Model Lab sizes it, reviews it, starts it with ops agents watching, answers what happens mid-run (a
    /// diagnostic sweep, an extension), finishes it, reads the results, launches it with a keynote and checks that the
    /// market and the rivals answer. A copy of the game ends the same run early to check the Lab's "end now" estimate.
    static func scenarioE() -> Report {
        var r = Report(id: "E", title: all.first { $0.id == "E" }?.title ?? "E")
        var (s, flagship) = BalanceHarness.frontierLab(year: 2028, chips: 220_000, seed: 505)
        s.researched.formUnion(["checkpointing", "elastic", "sdc_detection", "evals_rsp", "wsd", "curriculum"])
        s.market.euAIAct = true
        let b = s.bonuses
        let ref = Silicon.reference(s)
        let set = Leaderboard.indexSet(s)

        // Design and review.
        var d = PTPlay.design(s, ref, chips: 150_000, days: 90, name: "Zenith-1", b: b)
        d.spares = 0.02
        d.safetyEvals = true
        if d.isMoE { d.experts = TrainingExperience.expertChoices(for: d.activeFraction).last ?? 0 }
        // Ops agents first, watching every run, so the plan the review makes already counts on them.
        if let m = s.models.first(where: { $0.id == flagship }) {
            let agents = Training.agentsForCoverage(m, chips: d.chips, s, s.bonuses)
            let need = Swarms.chipsNeeded(m, accelID: ref.id, agents: agents, s, s.bonuses)
            r.expect("ops swarm starts", s.startSwarm(name: "Zenith ops", modelID: flagship, agents: agents, mission: .trainingOps, accelID: ref.id,
                                                      chips: min(need, Economy.freeChips(s, ref.id)), autonomy: 1, oversight: 0) == nil)
        }
        guard let review = TrainingExperience.review(d, lr: .standard, interval: 0.1, state: s, set: set,
                                                     board: Leaderboard.entries(s, set: set), watch: []) else {
            r.expect("pre-training review exists", false)
            return r
        }
        r.note("design: \(Fmt.params(d.paramsB)) (\(Fmt.params(d.activeParamsB)) active, \(TrainingExperience.layout(d).label)) on \(Fmt.tokens(d.tokensT)), "
               + "\(Fmt.int(d.chips))× \(ref.name), forecast index \(Fmt.score(review.mean)) (\(Fmt.score(review.low))–\(Fmt.score(review.high))), \(Fmt.days(review.est.days)), \(Fmt.money(review.est.totalCost))")
        r.expect("review: a run this size is major or frontier", review.scale >= .major, review.scale.label)
        r.expect("review: it finishes and costs money", review.est.finishes && review.est.totalCost > 1e8,
                 "\(Fmt.days(review.est.days)), \(Fmt.money(review.est.totalCost))")
        r.expect("review: forecast band is honest (low < mean < high)", review.low < review.mean && review.mean < review.high)
        r.expect("review: MoE routing costs throughput", !d.isMoE || Physics.moeEfficiency(d, accel: ref, bonuses: b) < 1,
                 "MoE keeps \(Fmt.pct(Physics.moeEfficiency(d, accel: ref, bonuses: b), decimals: 1))")

        // Start it, with training-ops agents watching it.
        guard s.startTraining(d) == nil, let runID = s.runs.last?.id else {
            r.expect("run starts", false, s.startTraining(d) ?? "")
            return r
        }
        func run() -> TrainingRun? { s.runs.first { $0.id == runID } }
        r.expect("launch plan recorded", run()?.plan != nil)
        r.expect("no cluster first at launch", !TrainingExperience.has(s, "chips_100k"))

        // Train, answering incidents the careful way and intervening once or twice.
        var diagnosed = false, extended = false, clone: GameState? = nil, sawFirstAfterQuarter = false, forkID: UUID? = nil
        var forecastBeforeExtend = 0.0
        for _ in 0..<500 {
            guard let cur = run(), cur.status != .done, cur.status != .cancelled else { break }
            if !diagnosed && cur.progress >= 0.35 && cur.status == .running {
                let cash = s.cash
                let cost = TrainingInterventions.diagnoseCost(s, cur).money
                r.expect("diagnostic sweep runs", s.diagnoseRun(runID) == nil)
                r.expect("diagnostic sweep is paid for", abs(cash - s.cash - cost) < 1, "\(Fmt.money(cash - s.cash)) vs \(Fmt.money(cost))")
                r.expect("diagnostic sweep reports", run()?.events.contains { $0.contains("Diagnostic sweep") } ?? false)
                diagnosed = true
            }
            if clone == nil && cur.progress >= 0.5 && cur.status == .running {
                clone = s   // the game where you end pre-training here
            }
            if !extended && cur.progress >= 0.55 && cur.status == .running {
                forecastBeforeExtend = Training.projectedIndex(s, cur).0
                let total = cur.flopsTotal
                if let why = TrainingInterventions.extendBlocker(s, cur, by: 0.25) {
                    r.note("extension not possible: \(why)")
                } else {
                    let preview = TrainingInterventions.extendPreview(s, cur, by: 0.25)
                    r.expect("extension applies", s.extendRun(runID, by: 0.25) == nil)
                    let after = run()!
                    r.expect("extension adds a quarter more compute", after.flopsTotal > total * 1.24, "\(Fmt.flops(total)) → \(Fmt.flops(after.flopsTotal))")
                    r.expect("extension preview promises more", (preview?.index ?? 0) >= forecastBeforeExtend - 0.5,
                             "\(Fmt.score(forecastBeforeExtend)) → \(Fmt.score(preview?.index ?? 0))")
                }
                extended = true
            }
            Sim.advanceDay(&s)
            for _ in 0..<10 {
                guard let dd = s.decisions.first else { break }
                s.resolveDecision(dd.id, option: dd.kind == "acquisition" ? dd.options.count - 1 : 0)
            }
            if let c = run(), c.progress >= 0.25, TrainingExperience.has(s, "chips_100k") { sawFirstAfterQuarter = true }
            fund(&s, atLeast: 1e10)
        }
        guard let done = run(), done.status == .done, let mid = done.modelID, let model = s.models.first(where: { $0.id == mid }) else {
            r.expect("run finishes", false, run().map { "\($0.status.rawValue) at \(Int($0.progress * 100))%" } ?? "missing")
            return r
        }
        r.expect("run finishes", true, "\(GameCalendar.daysBetween(done.started, s.date)) days, \(Fmt.money(done.cost))")
        r.expect("cluster first after a quarter of training", sawFirstAfterQuarter)
        r.expect("telemetry kept, bounded", !done.telemetry.isEmpty && done.telemetry.count <= TrainingInterventions.telemetryDays, "\(done.telemetry.count) days")
        r.expect("telemetry faults within the run's interruptions", done.telemetry.reduce(0) { $0 + $1.failures } <= done.interruptions,
                 "\(done.telemetry.reduce(0) { $0 + $1.failures }) of \(done.interruptions)")
        r.expect("held-out validation recorded", done.loss.contains { $0.val > 0 })
        r.expect("ops agents watched it", done.opsCoverage > 0.3, Fmt.pct(done.opsCoverage, decimals: 0))
        r.expect("model uses the design's serving physics", model.archV2 && model.evaluated, "archV2 \(model.archV2), evaluated \(model.evaluated)")
        if let fc = done.forecast {
            let dev = model.c - fc.c
            r.expect("result within the forecast's uncertainty (±3σ, after known penalties)", abs(dev + done.qualityPenalty) <= 3 * fc.sigma + 0.05,
                     "c \(Fmt.trim(model.c, 2)) vs forecast \(Fmt.trim(fc.c, 2)) ± \(Fmt.trim(fc.sigma, 2))")
        }
        let board = Leaderboard.entries(s, set: Leaderboard.indexSet(s))
        let results = TrainingExperience.results(done, model: model, index: model.index, board: board, set: Leaderboard.indexSet(s), state: s)
        r.note("result: index \(Fmt.score(results.index)), #\(results.rank), \(results.days) days vs \(Fmt.days(results.plannedDays ?? 0)) planned, \(Fmt.money(results.cost)) vs \(Fmt.money(results.plannedCost ?? 0)) planned")
        r.expect("results compare plan and reality", results.plannedDays != nil && results.plannedCost != nil)
        if let pd = results.plannedDays, pd > 0 {
            // The plan was for the original length; the run was extended by a quarter partway through.
            let expected = pd * (1 + 0.25 * 0.45)
            r.expect("duration close to plan (after the extension)", abs(Double(results.days) - expected) / expected < 0.3,
                     "\(results.days) days vs ~\(Int(expected)) expected")
        }

        // The run ended early in the copy: the estimate the command centre showed against what happened.
        if var t = clone, let early = t.runs.first(where: { $0.id == runID }), let preview = TrainingInterventions.stopPreview(t, early) {
            let cost0 = early.cost
            // A preview forked from the newest checkpoint skips the run's evaluation stage: it can be evaluated afterwards.
            if let cp = early.saved.last, t.forkCheckpoint(runID, checkpoint: cp.id) == nil, let fork = t.models.last {
                r.expect("a forked preview starts unevaluated", !Evaluations.isEvaluated(t, fork))
                // Launched with a full system card and red-team report, it would count as evaluated at once.
                var card = t
                _ = card.release(fork.id, api: true, openWeights: false, plan: LaunchPlan(safety: .thorough))
                r.expect("a full system card counts as the evaluation", card.models.first { $0.id == fork.id }?.evaluated == true)
                let cash = t.cash, price = Evaluations.cost(t, fork)
                r.expect("evaluations can be commissioned for it", t.evaluateModel(fork.id) == nil, Evaluations.blocker(t, fork) ?? "")
                r.expect("evaluations are paid for", abs(cash - t.cash - price) < 1, Fmt.money(price))
                r.expect("evaluations can't be commissioned twice", t.evaluateModel(fork.id) != nil)
                forkID = fork.id
            } else {
                r.expect("a checkpoint can be forked", false, "\(early.saved.count) checkpoints")
            }
            r.expect("end pre-training early", t.endPretrainingEarly(runID) == nil)
            for _ in 0..<300 {
                guard let c = t.runs.first(where: { $0.id == runID }), c.status != .done else { break }
                Sim.advanceDay(&t)
                for dd in t.decisions { t.resolveDecision(dd.id, option: dd.kind == "acquisition" ? dd.options.count - 1 : 0) }
                t.decisions.removeAll()
                fund(&t, atLeast: 1e10)
            }
            if let c = t.runs.first(where: { $0.id == runID }), let mid2 = c.modelID, let m2 = t.models.first(where: { $0.id == mid2 }) {
                r.note("ended early at 50%: index \(Fmt.score(m2.index)) (estimated \(Fmt.score(preview.indexNow)), 80% \(Fmt.score(preview.indexLow))–\(Fmt.score(preview.indexHigh))), \(Fmt.money(c.cost)) vs \(Fmt.money(done.cost)) for the full run")
                r.expect("ending early costs less than finishing", c.cost < done.cost, "\(Fmt.money(c.cost)) vs \(Fmt.money(done.cost))")
                r.expect("ending early gives a weaker model than finishing", m2.c <= model.c + 0.05, "c \(Fmt.trim(m2.c, 2)) vs \(Fmt.trim(model.c, 2))")
                // The estimate is a posterior: it holds within its own stated uncertainty (±3σ in capability).
                r.expect("the end-now estimate holds (within ±3σ of its capability estimate)", abs(m2.c - preview.c) <= 3 * preview.sigma + 0.05,
                         "c \(Fmt.trim(m2.c, 2)) vs \(Fmt.trim(preview.c, 2)) ± \(Fmt.trim(preview.sigma, 2)); index \(Fmt.score(m2.index)) vs \(Fmt.score(preview.indexNow))")
                _ = cost0
            } else {
                r.expect("early-ended run finishes", false)
            }
            // The forked preview's evaluations, three weeks on.
            for _ in 0...Evaluations.days { Sim.advanceDay(&t); t.decisions.removeAll() }
            if let id = forkID, let fork = t.models.first(where: { $0.id == id }) {
                r.expect("evaluations report within \(Evaluations.days) days", fork.evaluated && fork.evalDue == nil)
            }
        }

        // Launch it with a keynote and put idle chips behind it.
        let revenueBefore = s.models.filter(\.released).reduce(0) { $0 + $1.revenueDay }
        r.expect("keynote launch", s.release(model.id, api: true, openWeights: false, plan: LaunchPlan(strategy: .keynote)) == nil)
        let k = Physics.chipsPerReplica(model, accel: ref, precision: model.servingPrecision, bonuses: s.bonuses)
        let free = Economy.freeChips(s, ref.id)
        _ = s.deploy(model.id, accelID: ref.id, chips: max(k, min(free, 40_000) / k * k))
        s.chatModelID = model.id
        for _ in 0..<45 {
            Sim.advanceDay(&s)
            for dd in s.decisions { s.resolveDecision(dd.id, option: dd.kind == "acquisition" ? dd.options.count - 1 : 0) }
            s.decisions.removeAll()
        }
        let launched = s.models.first { $0.id == model.id }
        let revenueAfter = s.models.filter(\.released).reduce(0) { $0 + $1.revenueDay }
        r.expect("the launch is recorded with a launch-day report", s.launches.last { $0.modelID == model.id }?.report != nil)
        r.expect("the new model earns", (launched?.revenueDay ?? 0) > 0, Fmt.money(launched?.revenueDay ?? 0) + "/day")
        r.note("revenue/day before \(Fmt.money(revenueBefore)), after \(Fmt.money(revenueAfter)); rank #\(Leaderboard.rank(of: model.id, in: s))")
        let launch = s.launches.last { $0.modelID == model.id }
        if Leaderboard.rank(of: model.id, in: s) <= 2 {
            let answered = launch?.responses.isEmpty == false || s.competitors.contains { $0.project.map { $0.rushed || $0.delays > 0 || $0.cAdjust != 0 } ?? false }
            r.expect("rivals answer a top model", answered)
        } else {
            // A mid-table model draws a weaker answer than the same keynote for a #1 would.
            let odds = launch?.responses.map(\.odds).max() ?? 0
            let top = Launches.responseOdds(LaunchPlan(strategy: .keynote), rank: 1)
            r.expect("rivals answer a mid-table model less than a #1", odds < top,
                     "#\(launch?.rank ?? 0): response odds \(Fmt.pct(odds, decimals: 0)) vs \(Fmt.pct(top, decimals: 0)) for a #1")
        }
        sanity(s, &r)
        return r
    }
}
