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

    /// Bytes of training state per parameter: BF16 weights and gradients plus FP32 master weights and the optimizer's
    /// moments (Adam keeps two, Muon one, Shampoo/SOAP adds preconditioners). Lower-precision training keeps smaller
    /// copies, and offloading moves the master weights and moments to host memory.
    static func stateBytesPerParam(_ d: ModelDesign) -> Double {
        var bytes = trainingBytesPerParam
        switch d.optimizer {
        case .adamw: break
        case .muon: bytes -= 4
        case .shampoo: bytes += 4
        }
        switch d.precision {
        case .bf16: break
        case .fp8: bytes -= 1
        case .fp4: bytes -= 1.5
        }
        if d.memoryPlan == .offload { bytes = min(bytes, 4) }
        return bytes
    }

    /// Activation memory per parameter at the design's context length (1.6 bytes up to 8K tokens). Long sequences
    /// hold more activations; sequence parallelism (ring attention) splits long ones across chips; recomputing
    /// activations in the backward pass keeps about a fifth of them.
    static func activationBytesPerParam(_ d: ModelDesign, bonuses b: ResearchBonuses) -> Double {
        var ctx = d.contextK >= 512 ? 5.0 : (d.contextK >= 128 ? 2.5 : (d.contextK >= 32 ? 1.5 : 1))
        if b.has(.context1m) { ctx = 1 + (ctx - 1) * 0.5 }
        return 1.6 * ctx * (d.memoryPlan == .checkpointing ? 0.2 : 1)
    }

    /// Training memory per parameter, state plus activations (17.6 bytes for an AdamW BF16 short-context design).
    static func trainingBytes(_ d: ModelDesign, bonuses b: ResearchBonuses) -> Double {
        d.mode == .finetune ? finetuneBytesPerParam : stateBytesPerParam(d) + activationBytesPerParam(d, bonuses: b)
    }

    /// Throughput kept by the memory plan: recomputing activations costs about a third of a forward pass, and
    /// streaming optimizer state over PCIe stalls each step.
    static func memoryPlanSpeed(_ d: ModelDesign) -> Double {
        switch d.memoryPlan {
        case .standard: 1
        case .checkpointing: 0.9
        case .offload: 0.8
        }
    }

    static func trainingMemory(_ d: ModelDesign, accel: Accelerator, bonuses b: ResearchBonuses) -> MemoryCheck {
        let need = d.paramsB * trainingBytes(d, bonuses: b)
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
        let engineers = s.employees.filter { $0.role == .mlEngineer }.reduce(0.0) { $0 + $1.weight }
        let needed = 0.5 + Double(chips) / 1_500
        base += 0.04 * min(1, engineers / needed)
        // Agent swarms on training operations tune kernels and route around bad nodes.
        base += 0.04 * s.swarmOps + s.traits.mfu + AgentOrgs.mfuBonus(s)   // 3.6: techniques from architecture research
        if engineers < 0.5 && chips > 64 { base -= 0.05 }
        return clamp(base * scaleOutFactor(accel: accel, chips: chips, bonuses: b), 0.05, 0.7)
    }

    /// Share of MFU kept once a run spans more chips than one scale-up domain (NVLink/ICI): cross-node communication
    /// costs a fixed share per decade of scale-out. 1 inside one domain.
    static func scaleOutFactor(accel: Accelerator, chips: Int, bonuses b: ResearchBonuses) -> Double {
        guard chips > accel.scaleUp else { return 1 }
        let decades = log10(Double(chips) / Double(max(1, accel.scaleUp)))
        let perDecade = (accel.scaleUp <= 2 ? 0.13 : 0.06) * (1 - b.scaleOut)
        return max(0.35, 1 - decades * perDecade)
    }

    /// Infra engineers on the team, weighted by skill (a skill-50 engineer counts as one).
    static func infraWeight(_ s: GameState) -> Double {
        s.employees.filter { $0.role == .infra }.reduce(0.0) { $0 + $1.weight }
    }

    /// Chips of the biggest run going (or about to go: `planned`), which the infra team is staffed against.
    static func staffedChips(_ s: GameState, planned: Int = 0) -> Int {
        max(1, planned, s.runs.filter { $0.status == .running || $0.status == .postTraining }.map(\.design.chips).max() ?? 1)
    }

    /// Hours of progress lost per hardware interruption (restart + work since the last save). The infra team is
    /// staffed against the biggest run going *including the one being planned* (`chips`), so an estimate made
    /// before a run starts sees the same staffing the run will. `infra` overrides the team ("if you hired…").
    static func hoursLostPerFailure(state s: GameState, bonuses b: ResearchBonuses, chips planned: Int = 0, infra: Double? = nil) -> Double {
        let team = infra ?? infraWeight(s)
        let staffing = min(1, team / Training.opsNeeded(chips: staffedChips(s, planned: planned)))
        return 1.5 * b.failureKeep * (1.3 - 0.3 * staffing) * (1 - 0.4 * s.swarmOps)
    }

    /// Small synchronisation losses from stragglers and slow nodes at scale.
    static func stragglerFactor(chips: Int, bonuses b: ResearchBonuses) -> Double {
        clamp(1 - 0.015 * log10(max(1, Double(chips) / 500)) * (1 - b.scaleOut), 0.9, 1)
    }

    /// Expected fraction of wall-clock time that makes forward progress (hardware failures at Llama 3 rates,
    /// stragglers): the same expectation the daily simulation draws from, so it really can reach zero.
    /// `coverage` is the share of the run watched by ops agents; by default, what your unpinned training-ops
    /// swarms would give a new run of this size. Past ~100K chips, a run without agents barely moves.
    static func goodput(chips: Int, state s: GameState, bonuses b: ResearchBonuses, coverage: Double? = nil) -> Double {
        let cov = coverage ?? Training.plannedCoverage(s, chips: chips)
        return Training.goodput(chips: chips, coverage: cov, state: s, bonuses: b)
    }

    /// MFU the daily simulation will use for this design (ops agents tune kernels too).
    static func runMFU(_ d: ModelDesign, accel: Accelerator, coverage cov: Double, state s: GameState, bonuses b: ResearchBonuses) -> Double {
        var m = mfu(accel: accel, chips: d.chips, state: s, bonuses: b) + 0.02 * cov
        if d.optimizer == .shampoo { m -= 0.02 }
        // 3.4: what the design itself costs: sparse experts' all-to-all traffic and router imbalance, the memory plan,
        // and chips held back as hot spares.
        m *= moeEfficiency(d, accel: accel, bonuses: b) * memoryPlanSpeed(d) * (1 - clamp(d.spares, 0, 0.1))
        return max(0.05, m)
    }

    /// Share of MFU a sparse model keeps after expert-parallel communication and router load imbalance (1 when dense).
    /// Every layer sends each token to its experts and back: more and smaller experts, and more of them per token,
    /// mean more traffic, which costs about three times as much once it leaves a scale-up domain. DualPipe-style overlap
    /// hides most of it; auxiliary-loss-free balancing removes most of the imbalance that leaves chips waiting.
    static func moeEfficiency(_ d: ModelDesign, accel: Accelerator, bonuses b: ResearchBonuses) -> Double {
        guard d.isMoE else { return 1 }
        let layout = TrainingExperience.layout(d)
        let fan = 0.6 * log2(Double(max(4, layout.experts)) / 4) + 0.4 * log2(Double(max(1, layout.active)))
        var comm = 0.022 * fan * (d.chips > accel.scaleUp ? 1 : 0.35)
        if b.researched.contains("dualpipe") { comm *= 0.35 }
        let imbalance = b.researched.contains("aux_free") ? 0.01 : 0.035
        return clamp(1 - comm - imbalance, 0.7, 1)
    }

    /// Hours lost per failure kept when hot spares stand by: a failed node is swapped for a spare in seconds instead of
    /// waiting for the job to be rescheduled (3% spares capture most of it).
    static func spareRecovery(_ spares: Double) -> Double {
        1 - 0.7 * min(1, max(0, spares) / 0.03)
    }

    /// Expected FLOPs a design's cluster delivers per day, exactly as the daily simulation computes them on average.
    static func flopsPerDay(_ d: ModelDesign, state s: GameState, lr: LRSchedule = .standard, interval: Double = 0.1) -> Double {
        guard let a = HardwareCatalog.get(d.accelID) else { return 0 }
        let b = s.bonuses
        let cov = Training.plannedCoverage(s, chips: d.chips)
        return Double(d.chips) * a.trainTFLOPS(d.precision) * 1e12 * runMFU(d, accel: a, coverage: cov, state: s, bonuses: b)
            * Training.goodput(chips: d.chips, coverage: cov, state: s, bonuses: b, spares: d.spares) * 86_400 * lr.speed * Sim.checkpointOverhead(interval)
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
        /// Expected wall-clock days, including the LR schedule's speed, checkpoint overhead and expected incidents.
        /// Infinite when hardware failures leave no time for progress.
        var days: Double
        var dailyCost: Double
        var totalCost: Double
        var mfu: Double
        var goodput: Double
        var memory: MemoryCheck
        var forecast: Forecast
        /// Ops-agent coverage the estimate assumes (training-ops swarms that watch every run).
        var coverage: Double = 0
        /// Days set aside for incidents answered the careful way (loss-spike rollbacks, fault storms, contamination scrubs,
        /// post-training stages redone); see `Training.incidentDays`.
        var incidentDays: Double = 0
        /// Small enough to be an experiment: no mid-run incidents (`Training.toyCost`).
        var toy: Bool = false

        /// Whether the run would finish at all.
        var finishes: Bool { days.isFinite }
    }

    static func estimate(_ d: ModelDesign, state s: GameState, lr: LRSchedule = .standard, interval: Double = 0.1) -> Estimate? {
        guard let accel = HardwareCatalog.get(d.accelID) else { return nil }
        let b = s.bonuses
        let pre = pretrainFLOPs(d)
        let post = postTrainFLOPs(d, pretrain: pre, bonuses: b)
        let cov = Training.plannedCoverage(s, chips: d.chips)
        let m = runMFU(d, accel: accel, coverage: cov, state: s, bonuses: b)
        let g = Training.goodput(chips: d.chips, coverage: cov, state: s, bonuses: b, spares: d.spares)
        let perDay = flopsPerDay(d, state: s, lr: lr, interval: interval)
        let daily = Economy.chipDailyCost(accel, count: d.chips, state: s)
        var days = Double.infinity, incidents = 0.0, toy = false
        // Below 1% goodput progress comes from the odd lucky day, if ever: the run doesn't finish.
        if perDay > 0 && g >= Training.stallGoodput {
            let base = (pre + post) / perDay + 0.5          // a run ends at the end of a day
            toy = Training.isToy(cost: daily * base)
            incidents = toy ? 0 : Training.incidentDays(d, pretrain: pre, perDay: perDay, goodput: g, interval: interval, lr: lr,
                                                        coverage: cov, state: s, bonuses: b)
            days = base + incidents
        }
        return Estimate(flops: pre, postFlops: post, days: days, dailyCost: daily, totalCost: days.isFinite ? daily * days : .infinity,
                        mfu: m, goodput: g, memory: trainingMemory(d, accel: accel, bonuses: b),
                        forecast: ForecastEngine.forecast(d, state: s, dataSources: s.dataSources.sorted()),
                        coverage: cov, incidentDays: incidents, toy: toy)
    }

    // MARK: Size limits

    /// Biggest model (total parameters, billions) your training stack can shard: 20T to start, ×1.5 with fine-grained
    /// experts, ×1.5 with expert parallelism, ×1.25 with multi-datacenter training, and +25% a year from 2026 as tooling
    /// matures. It grows slower than compute on purpose: past it, compute goes into more tokens (over-training), which is
    /// what real labs do to keep giant models affordable to serve.
    static func maxParamsB(_ s: GameState) -> Double {
        let b = s.bonuses
        var cap = 20_000.0
        if b.has(.fineMoE) { cap *= 1.5 }
        if b.researched.contains("dualpipe") { cap *= 1.5 }
        if b.has(.multiSite) { cap *= 1.25 }
        return cap * (1 + 0.25 * max(0, s.year - 2026))
    }

    /// What would raise `maxParamsB`, for the Model Lab.
    static func paramCapLifts(_ s: GameState) -> String {
        let b = s.bonuses
        var out: [String] = []
        if !b.has(.fineMoE) { out.append("Fine-grained & Shared Experts research (×1.5)") }
        if !b.researched.contains("dualpipe") { out.append("DualPipe & Expert Parallelism research (×1.5)") }
        if !b.has(.multiSite) { out.append("Multi-Datacenter Training research (×1.25)") }
        let time = s.year < 2026 ? "starts growing 25% a year in 2026" : "grows 25% a year as tooling matures"
        return out.isEmpty ? "It \(time)." : "\(out.joined(separator: ", ")) raise it, and it \(time)."
    }

    /// Unique tokens (trillions) a design can draw on: your data sources, data research and its synthetic share.
    static func uniqueTokensT(_ d: ModelDesign, state s: GameState) -> Double {
        let b = s.bonuses
        let raw = availableTokensT(s.dataSources.sorted(), y: s.year, bonuses: b)
        return raw * (d.syntheticShare > 0 && b.has(.syntheticData) ? 1 + d.syntheticShare * 3 : 1) + DataEconomy.extraUniqueT(s)   // 3.6
    }

    /// Passes over the unique data worth planning: past this a repeated token is worth well under half a fresh one.
    static let maxEpochs = 16.0

    /// Most training tokens worth planning (trillions): `maxEpochs` passes over your unique data, never below 150T.
    static func maxTokensT(_ d: ModelDesign, state s: GameState) -> Double {
        max(150, maxEpochs * uniqueTokensT(d, state: s))
    }

    /// What would raise `maxTokensT`, for the Model Lab.
    static func tokenCapLifts(_ d: ModelDesign, state s: GameState) -> String {
        let b = s.bonuses
        var out = ["more data sources (Training Data page)"]
        if !b.has(.syntheticData) { out.append("Synthetic Data Pipelines research") }
        else if d.syntheticShare < 0.5 { out.append("a higher synthetic share") }
        out.append("data research that adds usable tokens")
        return "It's \(Int(maxEpochs)) passes over your \(Fmt.tokens(uniqueTokensT(d, state: s))) of unique data: \(out.joined(separator: ", ")) raise it."
    }

    /// Chinchilla loss (Epoch AI's corrected fit).
    static func chinchillaLoss(paramsB: Double, tokensT: Double) -> Double {
        ForecastEngine.loss(paramsB: paramsB, tokensT: tokensT)
    }

    // MARK: Data

    static func availableTokensT(_ sources: [String], y: Double, bonuses b: ResearchBonuses) -> Double {
        let raw = sources.sorted().compactMap { DataCatalog.byID[$0] }.reduce(0) { $0 + $1.tokensT(y) }   // 3.7: fixed order
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

    // MARK: Architecture (3.4)

    /// A design's layer shape from its active parameters (12·L·d² per dense stack, width ≈ 128 × depth). The
    /// architecture diagram draws it, and serving reads the KV cache from it.
    struct Shape: Hashable {
        var layers: Int
        var dModel: Int
        var heads: Int
        var kvHeads: Int
        var latent: Int
        var attentionLayers: Int
        var ssmLayers: Int
    }

    static func shape(_ d: ModelDesign) -> Shape {
        let active = max(d.activeParamsB, 0.001) * 1e9
        let l = max(2, Int(pow(active / (12 * 128 * 128), 1.0 / 3).rounded()))
        let rawD = (active / (12 * Double(l))).squareRoot()
        let dModel = max(256, Int((rawD / 128).rounded()) * 128)
        let heads = max(2, dModel / 128)
        var kv = heads, latent = 0
        switch d.attention {
        case .mha: break
        case .gqa: kv = min(8, heads)
        case .mla:
            kv = 0
            latent = max(256, dModel / 14 / 64 * 64)
        }
        var attn = l, ssm = 0
        if d.mixer == .hybrid {
            attn = max(1, l / 8)
            ssm = l - attn
        }
        return Shape(layers: l, dModel: dModel, heads: heads, kvHeads: kv, latent: latent, attentionLayers: attn, ssmLayers: ssm)
    }

    /// KV-cache bytes per token of context (every attention layer, BF16).
    static func kvBytesPerToken(_ d: ModelDesign) -> Double {
        let sh = shape(d)
        let width = d.attention == .mla ? Double(sh.latent) : Double(2 * sh.kvHeads * 128)
        return Double(sh.attentionLayers) * width * 2
    }

    /// The design's KV footprint relative to multi-head attention on the same model (1 = MHA): grouped-query heads share
    /// keys and values, latent attention compresses them, hybrid models keep attention in one layer in eight. The floor
    /// covers activations and buffers that don't shrink with the attention.
    static func kvFactor(_ d: ModelDesign) -> Double {
        let sh = shape(d)
        let mha = Double(sh.layers * 2 * sh.heads * 128 * 2)
        return 0.15 + 0.85 * min(1, kvBytesPerToken(d) / max(mha, 1))
    }

    /// Serving speed-ups the design itself brings (on top of research): diffusion decodes blocks at once, hybrid SSM
    /// layers decode in linear time, alien operators are leaner.
    static func designEfficiency(_ d: ModelDesign, bonuses b: ResearchBonuses) -> Double {
        switch d.mixer {
        case .diffusion: 1.5 * b.result("x_diffusion_lm")
        case .hybrid: 0.3
        case .alien: 0.4
        case .transformer: 0
        }
    }

    /// Research bonuses as they apply to serving model `m`. Models trained from 3.4 on only get attention and decoding
    /// research their design uses: grouped-query and latent attention shape the KV cache of designs built with them
    /// (`kvFactor` covers it, so their KV-memory research isn't counted twice) and lift throughput only there, and
    /// multi-token prediction speeds up decoding only for models trained with its heads. Older models keep the rules
    /// they were balanced with.
    static func servingBonuses(_ m: AIModel, _ b: ResearchBonuses) -> ResearchBonuses {
        guard m.archV2 else { return b }
        var out = b
        let d = m.design
        func q(_ id: String) -> Double { b.researched.contains(id) ? b.result(id) : 0 }
        out.kvMemory = min(0.85, max(0, rawKVMemory(b) - 0.5 * q("gqa") - 0.3 * q("mla")))
        if d.attention == .mha { out.throughput -= 0.15 * q("gqa") + 0.2 * q("mla") }
        if d.attention == .gqa { out.throughput -= 0.2 * q("mla") }
        if !d.mtp { out.tps -= 0.15 * q("mtp") }
        return out
    }

    /// KV-memory research before the 85% cap (so taking the attention items out of it is exact).
    static func rawKVMemory(_ b: ResearchBonuses) -> Double {
        var sum = 0.0
        for id in b.researched.sorted() {
            guard let item = ResearchCatalog.byID[id] else { continue }
            for e in item.effects { if case .kvMemory(let x) = e { sum += x * b.result(id) } }
        }
        return sum
    }

    static func kvOverhead(_ m: AIModel, bonuses b: ResearchBonuses) -> Double {
        let ctx = m.design.contextK >= 512 ? 2.0 : (m.design.contextK >= 128 ? 1.4 : (m.design.contextK >= 32 ? 1.15 : 1.0))
        guard m.archV2 else { return 0.3 * ctx * (1 - b.kvMemory) }
        return 0.3 * ctx * kvFactor(m.design) * (1 - servingBonuses(m, b).kvMemory)
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
    static func capacity(_ m: AIModel, deployment dep: Deployment, bonuses b0: ResearchBonuses) -> Double {
        guard let accel = HardwareCatalog.get(dep.accelID) else { return 0 }
        let b = servingBonuses(m, b0)
        let k = chipsPerReplica(m, accel: accel, precision: m.servingPrecision, bonuses: b0)
        let usable = (dep.chips / k) * k
        guard usable > 0 else { return 0 }
        let flopsPerToken = 2 * max(m.design.activeParamsB, 0.001) * 1e9
        let tf = accel.inferTFLOPS(m.servingPrecision) * 1e12 * servingUtilization(b)
        return Double(usable) * tf / flopsPerToken * 86_400 * (1 + m.efficiencyBoost)
    }

    /// Per-user decode speed in tokens/second.
    static func tps(_ m: AIModel, accel: Accelerator, precision: Precision, bonuses b0: ResearchBonuses, load: Double = 0.5) -> Double {
        let k = chipsPerReplica(m, accel: accel, precision: precision, bonuses: b0)
        let b = servingBonuses(m, b0)
        let bw = Double(k) * accel.bandwidthTBs * 1e12 * accel.decodeEff
        let effParams = m.design.activeParamsB + 0.25 * (m.design.paramsB - m.design.activeParamsB)
        var bytesPerToken = max(effParams, 0.001) * 1e9 * precision.bytesPerParam
        // 3.4: each decoded token also reads the sequence's KV cache (a typical request fills a fifth of the window).
        if m.archV2 { bytesPerToken += kvBytesPerToken(m.design) * (1 - b.kvMemory) * min(200_000, Double(m.design.contextK) * 1024 * 0.2) }
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

    /// Quality hit from serving model `m` at its precision: quantisation-aware training cuts it to about a third.
    static func servingPenalty(_ m: AIModel) -> Double {
        servingPenalty(m.servingPrecision) * (m.qat ? 0.3 : 1)
    }
}

extension ResearchBonuses {
    var researchedChinchilla: Bool { researched.contains("chinchilla") }
}

/// The Model Lab's sizing rules. They live in the engine so headless harnesses size runs exactly like the Lab does.
enum LabMath {
    /// Splits a FLOP budget between parameters and tokens. Before Chinchilla research labs sized like GPT-3
    /// (big, ~2 tokens/param); after it, compute-optimally (Epoch's corrected fit). `overtrain` multiplies tokens/param.
    /// Memory and the parameter cap limit the model, the token cap (the data wall) limits tokens: when one binds the
    /// compute moves to the other side, and only when both bind does compute go unused. Returns a note saying which
    /// limit bound and what lifts it, or nil.
    @discardableResult
    static func size(_ design: inout ModelDesign, flops: Double, overtrain: Double, accel a: Accelerator, state s: GameState) -> String? {
        let b = s.bonuses
        var active: Double
        if b.researchedChinchilla {
            active = ForecastEngine.optimalParamsB(flops: flops) / sqrt(overtrain)
        } else {
            active = sqrt(flops / (6 * 2 * overtrain)) / 1e9
        }
        let perParam = Physics.trainingBytes(design, bonuses: b)
        let memCap = a.weightStreaming ? 1e9 : (b.has(.sharding) ? Double(design.chips) * a.memoryGB / perParam
            : (b.has(.modelParallel) ? Double(min(design.chips, a.scaleUp)) * a.memoryGB / perParam : a.memoryGB / perParam))
        let paramCap = Physics.maxParamsB(s)
        let tokenCap = Physics.maxTokensT(design, state: s)
        func tokensFor(_ act: Double) -> Double { flops / (6 * max(act, 0.001) * 1e9) / 1e12 }
        // Out of fresh data: a bigger model gets more out of the compute than more passes over the same tokens.
        let dataBound = tokensFor(active) > tokenCap
        if dataBound { active = flops / (6 * tokenCap * 1e12) / 1e9 }
        let want = active / design.activeFraction
        let total = clamp(min(want, memCap * 0.9), 0.05, paramCap)
        design.paramsB = total
        let tokens = tokensFor(total * design.activeFraction)
        design.tokensT = clamp(tokens, 0.0005, tokenCap)

        let memBound = want > memCap * 0.9 && memCap * 0.9 < paramCap
        let capBound = want > paramCap && paramCap <= memCap * 0.9
        let modelLimit = memBound
            ? "memory (\(Fmt.int(design.chips)) \(a.name) chips train at most ~\(Fmt.params(memCap * 0.9)) parameters; more chips, sharding research or bigger-memory chips raise it)"
            : "the \(Fmt.params(paramCap)) parameter cap (\(Physics.paramCapLifts(s)))"
        if tokens > tokenCap * 1.001 {
            let used = 6 * total * design.activeFraction * 1e9 * tokenCap * 1e12 / max(flops, 1)
            return "Both size limits bind, so the model uses only \(Fmt.pct(used, decimals: 0)) of this compute and the run will be shorter. "
                + "Parameters are limited by \(modelLimit). Tokens are capped at \(Fmt.tokens(tokenCap)): \(Physics.tokenCapLifts(design, state: s))"
        }
        if memBound || capBound {
            return "Model size is limited by \(modelLimit), so the extra compute went into more tokens."
        }
        if dataBound {
            return "Out of fresh data: tokens are capped at \(Fmt.tokens(tokenCap)), so the extra compute went into a bigger model. \(Physics.tokenCapLifts(design, state: s))"
        }
        return nil
    }

    /// Keep the compute, re-split it.
    @discardableResult
    static func reshape(_ design: inout ModelDesign, overtrain: Double, accel: Accelerator?, state s: GameState) -> String? {
        guard let a = accel else { return nil }
        return size(&design, flops: Physics.pretrainFLOPs(design), overtrain: overtrain, accel: a, state: s)
    }

    /// The Model Lab's auto-size: first shrink a cluster that your team, ops agents and research couldn't keep running
    /// (expected goodput under `Training.goodputTarget`), so a plan never rests on a goodput floor; then size the model
    /// to finish in about `days`, post-training included. Returns notes for the player, or nil.
    @discardableResult
    static func autoSize(_ design: inout ModelDesign, days: Double, overtrain: Double, state s: GameState,
                         lr: LRSchedule = .standard, interval: Double = 0.1) -> String? {
        guard let a = HardwareCatalog.get(design.accelID) else { return nil }
        let b = s.bonuses
        var notes: [String] = []
        let healthy = Training.healthyChips(design.chips, target: Training.goodputTarget, state: s, bonuses: b)
        if healthy < design.chips {
            notes.append("Sized for \(Fmt.int(healthy)) of your \(Fmt.int(design.chips)) chips: beyond that, hardware failures would eat more than "
                         + "\(Int(((1 - Training.goodputTarget) * 100).rounded()))% of the time. Ops agents, infra engineers and fault-tolerance research let a run use more.")
            design.chips = healthy
        }
        let post = Physics.postTrainFLOPs(design, pretrain: 1e24, bonuses: b) / 1e24
        let perDay = Physics.flopsPerDay(design, state: s, lr: lr, interval: interval)
        if let note = size(&design, flops: perDay * days / (1 + post), overtrain: overtrain, accel: a, state: s) { notes.append(note) }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    /// Capability needed to hit a target index (binary search).
    static func capabilityFor(index target: Double, base: ModelProfile, set: [Benchmark]) -> Double? {
        var lo = -4.0, hi = 16.0
        var p = base
        p.c = hi
        if ForecastEngine.index(p, set: set) < target { return nil }
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            p.c = mid
            if ForecastEngine.index(p, set: set) < target { lo = mid } else { hi = mid }
        }
        return hi
    }
}
