import Foundation

/// Plans a frontier training run the way the Model Lab's "best recipe" does: every researched technique switched
/// on, sized for a target number of days on a given number of chips. Used by the training delegate.
enum RunPlanner {
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
        // Lean the second half of training toward what sells: code once agents matter, science before that.
        d.mixShift = b.has(.curriculum) ? (s.year >= 2024 ? .code : .stem) : .keep
        // The Model Lab's auto-size: shrink to a cluster that stays healthy, then size for the days.
        LabMath.autoSize(&d, days: days, overtrain: d.isMoE ? 2 : 1, state: s)
        return d
    }

    // MARK: Plan my next model

    /// One concrete way to spend idle chips on a new frontier run.
    struct Proposal: Identifiable {
        var id: String { label + design.accelID + String(design.chips) }
        var label: String
        var blurb: String
        var design: ModelDesign
        var est: Physics.Estimate
        /// Forecast capability minus your best live model's (nil when none is live) and minus the best rival's.
        var vsBest: Double?
        var vsRival: Double
        /// Chips of this type you could have used but the plan left out (health or cash), and why.
        var leftOut: Int
        var leftOutWhy: String
        /// Idle chips of other types, which stay free for serving the new model or other work.
        var othersIdle: String = ""
    }

    /// Chips of `p` a new run may take: idle plus leased-out, minus the ops reserve.
    static func spareChips(_ s: GameState, _ p: ComputePool) -> Int {
        max(0, p.free + (s.leases[p.accel.id] ?? 0) - Int(Double(p.total) * s.ops.reserveShare))
    }

    static func bestLiveC(_ s: GameState) -> Double? {
        s.models.filter { !$0.retired && !$0.preview }.map(\.c).max()
    }

    static func bestRivalC(_ s: GameState) -> Double {
        s.competitors.flatMap(\.models).filter { $0.date <= s.date }.map(\.c).max() ?? -10
    }

    /// 3.9: up to three designs sized to the chips you own and have idle, one chip type each (a run uses one type),
    /// best forecast first: the strongest model you can train, a fast one, and the cheapest that still beats your best.
    static func proposals(_ s: GameState) -> [Proposal] {
        let live = bestLiveC(s), rival = bestRivalC(s)
        let name = nextName(s)
        var all: [(tier: Int, p: Proposal)] = []
        let tiers: [(label: String, days: Double, share: Double)] = [("Strongest", 90, 1), ("Fast", 35, 1), ("Lean", 60, 0.3)]
        for pool in Economy.pools(s) where pool.accel.supportsTraining(.bf16) && (pool.accel.cls != .consumer || pool.total <= 64) {
            let spare = spareChips(s, pool)
            guard spare >= 4 else { continue }
            for (ti, t) in tiers.enumerated() {
                let want = max(4, Int(Double(spare) * t.share))
                let d = bestRecipe(s, accel: pool.accel, chips: want, days: t.days, name: name)
                guard let est = Physics.estimate(d, state: s) else { continue }
                if ProcessInfo.processInfo.environment["PLAN_DEBUG"] != nil { print("  cand \(t.label) \(pool.accel.name) chips \(d.chips) days \(est.days) mem \(est.memory.ok) gp \(est.goodput) c \(est.forecast.c)") }
                guard est.memory.ok, est.finishes, est.goodput >= 0.6 else { continue }
                let why = d.chips < spare ? (t.share < 1 ? "kept back for serving and research" : "more would stall on hardware failures (add ops agents or infra engineers)") : ""
                let others = Economy.pools(s).filter { $0.accel.id != pool.accel.id && $0.free >= 100 }.sorted { $0.free > $1.free }.prefix(3)
                    .map { "\(Fmt.int($0.free)) \($0.accel.name)" }.joined(separator: ", ")
                let blurb = "\(Fmt.int(d.chips)) \(pool.accel.name) for about \(Fmt.days(est.days)), \(Fmt.money(est.totalCost))"
                all.append((ti, Proposal(label: t.label, blurb: blurb, design: d, est: est, vsBest: live.map { est.forecast.c - $0 },
                                         vsRival: est.forecast.c - rival, leftOut: spare - d.chips, leftOutWhy: why, othersIdle: others)))
            }
        }
        var out: [Proposal] = []
        func take(_ p: Proposal?) {
            guard let p, !out.contains(where: { $0.design.accelID == p.design.accelID && $0.design.chips == p.design.chips && Int($0.est.days) == Int(p.est.days) }) else { return }
            out.append(p)
        }
        take(all.filter { $0.tier == 0 }.max { $0.p.est.forecast.c < $1.p.est.forecast.c }?.p)
        // Fast: the strongest that finishes within ~6 weeks.
        take(all.filter { $0.p.est.days <= 45 }.max { $0.p.est.forecast.c < $1.p.est.forecast.c }?.p.with(label: "Fast"))
        // Lean: cheapest that still beats your best live model (or, with none live, 80% of the strongest's forecast).
        let strongest = out.first?.est.forecast.c ?? 0
        let bar = live ?? (strongest - 0.5)
        take(all.filter { $0.p.est.forecast.c > bar + 0.1 }.min { $0.p.est.totalCost < $1.p.est.totalCost }?.p.with(label: "Lean"))
        return out
    }

    /// Starts a proposal as planned. Returns an error text, or nil.
    static func start(_ p: Proposal, _ s: inout GameState) -> String? {
        s.startTraining(p.design)
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
        // 3.8: a run that has sat paused for over a month no longer blocks the next one (it used to block it forever).
        guard !s.runs.contains(where: {
            $0.kind == .full && ($0.status == .running || $0.status == .postTraining
                                 || ($0.status == .paused && GameCalendar.daysBetween($0.pausedSince ?? $0.started, s.date) <= 30))
        }) else { return }
        let reserve = s.ops.reserveShare
        let pools = Economy.pools(s).filter { $0.accel.cls != .consumer || $0.total <= 64 }
        // Chips leased to the market count as spare: they come back for your own training.
        func spare(_ p: ComputePool) -> Int { max(0, p.free + (s.leases[p.accel.id] ?? 0) - Int(Double(p.total) * reserve)) }
        guard let pool = pools.filter({ $0.accel.supportsTraining(.bf16) }).max(by: { Double(spare($0)) * $0.accel.bf16 < Double(spare($1)) * $1.accel.bf16 }),
              spare(pool) >= 4 else { return }
        // 3.8: the bar is your best live model: a retired one can't be beaten by (or serve) anything.
        let best = s.models.filter { !$0.retired && !$0.preview }.map(\.c).max() ?? -10
        let days = 90 - 15 * precision
        var chips = Int(Double(spare(pool)) * (0.7 + 0.3 * precision))
        // Fewer chips beat a run that spends its life restarting (auto-size already shrinks to a healthy cluster).
        while chips >= 4 {
            let d = RunPlanner.bestRecipe(s, accel: pool.accel, chips: chips, days: days, name: RunPlanner.nextName(s))
            chips = d.chips
            if let est = Physics.estimate(d, state: s), est.memory.ok, est.goodput >= 0.6, est.days <= 150 {
                guard est.forecast.c > best + 0.1 else {
                    if !s.opsLog.prefix(8).contains(where: { $0.contains("not past your best") }) {   // once a while, not every pass
                        log(&s, "Training: \(d.name) would reach c \(Fmt.trim(est.forecast.c, 2)) on \(Fmt.int(chips)) \(pool.accel.name), not past your best live model (\(Fmt.trim(best, 2))); not started.")
                    }
                    return
                }
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

extension RunPlanner.Proposal {
    func with(label l: String) -> RunPlanner.Proposal { var c = self; c.label = l; return c }
}
