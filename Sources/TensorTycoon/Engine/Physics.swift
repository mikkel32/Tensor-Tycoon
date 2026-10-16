import Foundation

/// Everything about how compute turns into models and tokens.
enum Physics {
    // MARK: Training

    static let trainingBytesPerParam = 16.0   // BF16 weights + grads + FP32 Adam states
    static let chinchillaRatio = 20.0

    struct MemoryCheck {
        var ok: Bool
        var needGB: Double
        var haveGB: Double
        var note: String
    }

    /// LoRA-style fine-tune: frozen BF16 weights plus small adapters, optimizer states and activations.
    static let finetuneBytesPerParam = 2.4

    static func trainingMemory(_ d: ModelDesign, accel: Accelerator, bonuses b: ResearchBonuses) -> MemoryCheck {
        let need = d.paramsB * (d.mode == .finetune ? finetuneBytesPerParam : trainingBytesPerParam * 1.1)
        if accel.weightStreaming {
            return MemoryCheck(ok: true, needGB: need, haveGB: .infinity, note: "Weights stream from external memory — no limit.")
        }
        let group: Int
        let note: String
        if b.has(.sharding) {
            group = d.chips
            note = "Sharded across all \(d.chips) chips (ZeRO/FSDP)."
        } else if b.has(.modelParallel) {
            group = min(d.chips, max(1, accel.scaleUp))
            note = "Model-parallel within a \(group)-chip node. Research ZeRO/FSDP to shard across everything."
        } else {
            group = 1
            note = "Each chip must hold the whole model. Research Tensor Parallelism to split it."
        }
        let have = Double(group) * accel.memoryGB
        return MemoryCheck(ok: have >= need, needGB: need, haveGB: have, note: note)
    }

    static func mfu(accel: Accelerator, chips: Int, state s: GameState, bonuses b: ResearchBonuses) -> Double {
        var base = accel.baseMFU + min(0.10, b.mfu) + Partners.mfuBonus(accel, s)
        let engineers = s.employees.filter { $0.role == .mlEngineer }.reduce(0.0) { $0 + $1.skill / 50 }
        let needed = 0.5 + Double(chips) / 1_500
        base += 0.04 * min(1, engineers / needed)
        if engineers < 0.5 && chips > 64 { base -= 0.05 }
        var mult = 1.0
        if chips > accel.scaleUp {
            let decades = log10(Double(chips) / Double(max(1, accel.scaleUp)))
            let perDecade = (accel.scaleUp <= 2 ? 0.13 : 0.06) * (1 - b.scaleOut)
            mult = max(0.35, 1 - decades * perDecade)
        }
        return clamp(base * mult, 0.05, 0.7)
    }

    /// Hours of progress lost per hardware interruption (restart + work since the last save).
    static func hoursLostPerFailure(state s: GameState, bonuses b: ResearchBonuses) -> Double {
        let infra = s.employees.filter { $0.role == .infra }.reduce(0.0) { $0 + $1.skill / 50 }
        let chips = max(1, s.runs.filter { $0.status == .running || $0.status == .postTraining }.map(\.design.chips).max() ?? 1)
        let staffing = min(1, infra / max(0.5, Double(chips) / 600))
        return 1.5 * b.failureKeep * (1.3 - 0.3 * staffing)
    }

    /// Small synchronisation losses from stragglers and slow nodes at scale.
    static func stragglerFactor(chips: Int, bonuses b: ResearchBonuses) -> Double {
        clamp(1 - 0.015 * log10(max(1, Double(chips) / 500)) * (1 - b.scaleOut), 0.9, 1)
    }

    /// Fraction of wall-clock time that makes forward progress (hardware failures at Llama 3 rates, stragglers).
    static func goodput(chips: Int, state s: GameState, bonuses b: ResearchBonuses) -> Double {
        let failuresPerDay = Double(chips) * Training.failuresPerChipDay
        let lost = failuresPerDay * hoursLostPerFailure(state: s, bonuses: b) / 24
        return clamp((1 - lost) * stragglerFactor(chips: chips, bonuses: b), 0.2, 0.998)
    }

    static func pretrainFLOPs(_ d: ModelDesign) -> Double {
        let ctx = d.contextK >= 128 ? 1.08 : (d.contextK >= 32 ? 1.03 : 1.0)
        return 6 * d.activeParamsB * 1e9 * d.tokensT * 1e12 * ctx
    }

    static func postTrainFLOPs(_ d: ModelDesign, pretrain: Double, bonuses b: ResearchBonuses) -> Double {
        Training.stages(d, pretrain: pretrain, bonuses: b).filter { !$0.isPre }.reduce(0) { $0 + $1.flops }
    }

    static func clusterFLOPS(_ d: ModelDesign, accel: Accelerator, state s: GameState, bonuses b: ResearchBonuses) -> Double {
        Double(d.chips) * accel.trainTFLOPS(d.precision) * 1e12 * mfu(accel: accel, chips: d.chips, state: s, bonuses: b)
    }

    struct Estimate {
        var flops: Double
        var postFlops: Double
        var days: Double
        var dailyCost: Double
        var totalCost: Double
        var mfu: Double
        var goodput: Double
        var memory: MemoryCheck
        var forecast: Forecast
    }

    static func estimate(_ d: ModelDesign, state s: GameState) -> Estimate? {
        guard let accel = HardwareCatalog.get(d.accelID) else { return nil }
        let b = s.bonuses
        let pre = pretrainFLOPs(d)
        let post = postTrainFLOPs(d, pretrain: pre, bonuses: b)
        var m = mfu(accel: accel, chips: d.chips, state: s, bonuses: b)
        if d.optimizer == .shampoo { m -= 0.02 }
        let g = goodput(chips: d.chips, state: s, bonuses: b)
        let perDay = Double(d.chips) * accel.trainTFLOPS(d.precision) * 1e12 * max(0.05, m) * g * 86_400
        let days = (pre + post) / max(perDay, 1)
        let daily = Economy.chipDailyCost(accel, count: d.chips, state: s)
        return Estimate(flops: pre, postFlops: post, days: days, dailyCost: daily, totalCost: daily * days,
                        mfu: m, goodput: g, memory: trainingMemory(d, accel: accel, bonuses: b),
                        forecast: ForecastEngine.forecast(d, state: s, dataSources: Array(s.dataSources)))
    }

    /// Chinchilla loss (Epoch AI's corrected fit).
    static func chinchillaLoss(paramsB: Double, tokensT: Double) -> Double {
        ForecastEngine.loss(paramsB: paramsB, tokensT: tokensT)
    }

    // MARK: Data

    static func availableTokensT(_ sources: [String], y: Double, bonuses b: ResearchBonuses) -> Double {
        let raw = sources.compactMap { DataCatalog.byID[$0] }.reduce(0) { $0 + $1.tokensT(y) }
        return raw * (1 + b.dataTokens)
    }

    /// Capability of an open-weights model (or one of its distilled sizes) the player can fine-tune.
    static func openModelC(_ ref: String?, state s: GameState) -> Double? {
        guard let ref else { return nil }
        return openModels(s, latestPerLab: nil).first { $0.model.id.uuidString == ref }?.model.c
    }

    /// Open releases come as a family of sizes, like Llama 8B/70B/405B: the flagship plus distilled smaller variants.
    static let openVariantSizes: [Double] = [1, 3, 8, 14, 32, 70]

    static func openVariantID(_ base: UUID, size: Double) -> UUID {
        var u = base.uuid
        u.14 ^= 0xA5
        u.15 ^= UInt8(truncatingIfNeeded: Int(size))
        return UUID(uuid: u)
    }

    /// Open-weights models to fine-tune, best first. `latestPerLab` limits the list to each lab's newest open releases.
    static func openModels(_ s: GameState, latestPerLab: Int? = 3) -> [(lab: String, model: CompetitorModel)] {
        var out: [(lab: String, model: CompetitorModel)] = []
        for comp in s.competitors {
            var releases = comp.models.filter(\.open)
            if let n = latestPerLab { releases = Array(releases.sorted { $0.date > $1.date }.prefix(n)) }
            for m in releases {
                out.append((comp.def.name, m))
                for size in openVariantSizes where size < m.paramsB * 0.6 {
                    var v = m
                    v.id = openVariantID(m.id, size: size)
                    v.name = "\(m.name) \(Fmt.params(size))"
                    v.paramsB = size
                    // Distilled from the flagship: smaller, but better than training that size from scratch.
                    v.c = m.c - 0.75 * log10(m.paramsB / size)
                    out.append((comp.def.name, v))
                }
            }
        }
        return out.sorted { $0.model.c > $1.model.c }
    }

    // MARK: Inference

    static func kvOverhead(_ m: AIModel, bonuses b: ResearchBonuses) -> Double {
        let ctx = m.design.contextK >= 512 ? 2.0 : (m.design.contextK >= 128 ? 1.4 : (m.design.contextK >= 32 ? 1.15 : 1.0))
        return 0.3 * ctx * (1 - b.kvMemory)
    }

    static func chipsPerReplica(_ m: AIModel, accel: Accelerator, precision: Precision, bonuses b: ResearchBonuses) -> Int {
        let weights = m.design.paramsB * precision.bytesPerParam
        let need = weights * (1 + kvOverhead(m, bonuses: b))
        return max(1, Int(ceil(need / (accel.memoryGB * 0.92))))
    }

    static func servingUtilization(_ b: ResearchBonuses) -> Double {
        min(0.62, 0.20 * (1 + b.throughput))
    }

    /// Max tokens/day a deployment can produce.
    static func capacity(_ m: AIModel, deployment dep: Deployment, bonuses b: ResearchBonuses) -> Double {
        guard let accel = HardwareCatalog.get(dep.accelID) else { return 0 }
        let k = chipsPerReplica(m, accel: accel, precision: m.servingPrecision, bonuses: b)
        let usable = (dep.chips / k) * k
        guard usable > 0 else { return 0 }
        let flopsPerToken = 2 * max(m.design.activeParamsB, 0.001) * 1e9
        let tf = accel.inferTFLOPS(m.servingPrecision) * 1e12 * servingUtilization(b)
        return Double(usable) * tf / flopsPerToken * 86_400 * (1 + m.efficiencyBoost)
    }

    /// Per-user decode speed in tokens/second.
    static func tps(_ m: AIModel, accel: Accelerator, precision: Precision, bonuses b: ResearchBonuses, load: Double = 0.5) -> Double {
        let k = chipsPerReplica(m, accel: accel, precision: precision, bonuses: b)
        let bw = Double(k) * accel.bandwidthTBs * 1e12 * accel.decodeEff
        let effParams = m.design.activeParamsB + 0.25 * (m.design.paramsB - m.design.activeParamsB)
        let bytesPerToken = max(effParams, 0.001) * 1e9 * precision.bytesPerParam
        var t = bw / bytesPerToken * (1 + b.tps) * (1 + 0.5 * m.efficiencyBoost)
        t = min(t, 4_000)
        if load > 0.85 { t *= max(0.25, 1 - (load - 0.85) * 2.5) }
        return t
    }

    static func modelTPS(_ m: AIModel, bonuses b: ResearchBonuses, load: Double) -> Double {
        guard let dep = m.deployments.max(by: { $0.chips < $1.chips }), let accel = HardwareCatalog.get(dep.accelID) else { return 0 }
        return tps(m, accel: accel, precision: m.servingPrecision, bonuses: b, load: load)
    }

    static func allowedServingPrecisions(_ accel: Accelerator, bonuses b: ResearchBonuses) -> [Precision] {
        var out: [Precision] = [.bf16]
        if b.has(.int8Serving) { out.append(.fp8) }
        if b.has(.int4Serving) { out.append(.fp4) }
        return out
    }

    /// Quality hit from quantised serving.
    static func servingPenalty(_ p: Precision) -> Double {
        switch p {
        case .bf16: 0
        case .fp8: 0.01
        case .fp4: 0.05
        }
    }
}
