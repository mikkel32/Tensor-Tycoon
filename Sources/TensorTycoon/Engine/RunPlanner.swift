import Foundation

/// Plans a frontier training run the way the Model Lab's "best recipe" does: every researched technique switched
/// on, sized for a target number of days on a given number of chips. Used by the training delegate.
enum RunPlanner {
    /// Compute-optimal sizing for `flops` (GPT-3-style before Chinchilla research), within memory.
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

    /// The best recipe your research allows, sized to finish in about `days` on `chips` of `a`.
    static func bestRecipe(_ s: GameState, accel a: Accelerator, chips: Int, days: Double, name: String) -> ModelDesign {
        let b = s.bonuses
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
        size(&d, flops: perDay * days / (1 + post), overtrain: d.isMoE ? 2 : 1, accel: a, bonuses: b)
        return d
    }

    /// The next name in your model line ("Acme-3" after "Acme-2").
    static func nextName(_ s: GameState) -> String {
        let base = s.companyName.split(separator: " ").first.map(String.init) ?? "Model"
        var n = s.models.count + s.runs.count + 1
        let taken = Set(s.models.map(\.name) + s.runs.map(\.design.name))
        while taken.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }
}

extension Operations {
    /// Training delegate: when no frontier run is going and chips sit idle, plan the best run your research allows
    /// on them and start it — if its forecast beats your best model. Scripts plan long and cautious; a frontier agent
    /// uses every spare chip.
    static func autoTrain(_ s: inout GameState, precision: Double) {
        guard !s.runs.contains(where: { $0.kind == .full && ($0.status == .running || $0.status == .postTraining || $0.status == .paused) }) else { return }
        let reserve = s.ops.reserveShare
        let pools = Economy.pools(s).filter { $0.accel.cls != .consumer || $0.total <= 64 }
        // Chips leased to the market count as spare: they come back for your own training.
        func spare(_ p: ComputePool) -> Int { max(0, p.free + (s.leases[p.accel.id] ?? 0) - Int(Double(p.total) * reserve)) }
        guard let pool = pools.filter({ $0.accel.supportsTraining(.bf16) }).max(by: { Double(spare($0)) * $0.accel.bf16 < Double(spare($1)) * $1.accel.bf16 }),
              spare(pool) >= 4 else { return }
        let best = s.models.map(\.c).max() ?? -10
        let days = 90 - 15 * precision
        var chips = Int(Double(spare(pool)) * (0.7 + 0.3 * precision))
        // Fewer chips beat a run that spends its life restarting.
        while chips >= 4 {
            let d = RunPlanner.bestRecipe(s, accel: pool.accel, chips: chips, days: days, name: RunPlanner.nextName(s))
            if let est = Physics.estimate(d, state: s), est.memory.ok, est.goodput >= 0.6, est.days <= 150 {
                guard est.forecast.c > best + 0.1 else { return }
                guard est.totalCost < max(0, s.cash) * 0.5 else {
                    log(&s, "Training: \(d.name) would cost \(Fmt.money(est.totalCost)); waiting for more cash.")
                    return
                }
                let leased = s.leases[pool.accel.id] ?? 0
                if chips > pool.free && leased > 0 {
                    let back = min(leased, chips - pool.free)
                    _ = s.setLease(pool.accel.id, chips: leased - back)
                    log(&s, "Recalled \(Fmt.int(back)) leased \(pool.accel.name) to train \(d.name).")
                }
                if let e = s.startTraining(d) {
                    log(&s, "Training: couldn't start \(d.name): \(e)")
                } else {
                    log(&s, "Training: started \(d.name) on \(Fmt.int(chips)) \(pool.accel.name) — about \(Int(est.days)) days, forecast c \(Fmt.trim(est.forecast.c, 2)) (your best \(Fmt.trim(best, 2))).")
                }
                return
            }
            chips /= 2
        }
    }
}
