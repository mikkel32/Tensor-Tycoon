import Foundation

// MARK: - 3.5: training experience

/// What a model is for. Picking one in the Model Lab sets the existing knobs (data mix, mid-training shift,
/// post-training stages, sparsity, the parameter/token split); the objective itself adds nothing, so every gain or cost
/// shows up in the forecast's drivers and the domain math like any other choice.
enum ModelObjective: String, Codable, CaseIterable, Identifiable, Sendable {
    case general, coding, reasoning, science, multimodal, efficient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: "General"
        case .coding: "Coding"
        case .reasoning: "Reasoning"
        case .science: "Science"
        case .multimodal: "Multimodal"
        case .efficient: "Efficient"
        }
    }

    var symbol: String {
        switch self {
        case .general: "sparkles"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .reasoning: "brain"
        case .science: "atom"
        case .multimodal: "eye.fill"
        case .efficient: "bolt.fill"
        }
    }

    /// What picking it changes.
    var blurb: String {
        switch self {
        case .general: "Balanced data, no mid-training shift. Strong everywhere, best nowhere."
        case .coding: "Code-heavy data, a code shift in the second half, tool use, agentic and reasoning RL where researched."
        case .reasoning: "Math & science data and shift, heavy reasoning RL. Gains in reasoning and maths, a little chat lost to RL."
        case .science: "Math & science data and shift, reasoning RL and tool use: science draws on reasoning and some code."
        case .multimodal: "Vision and voice where researched, conversational data. Sees and speaks; slightly weaker per FLOP on text."
        case .efficient: "Sparse experts, multi-token prediction and hybrid layers where researched, and a smaller model on more tokens: cheap and fast to serve."
        }
    }

    /// The domains the objective is aimed at (for results and the specialist firsts).
    var focus: [CapDomain] {
        switch self {
        case .general: [.knowledge, .reasoning]
        case .coding: [.coding, .agents]
        case .reasoning: [.reasoning, .math]
        case .science: [.science, .math]
        case .multimodal: [.vision, .voice]
        case .efficient: []
        }
    }

    /// Applies the objective's recipe to a design with what you've researched. Returns what changed.
    @discardableResult
    func apply(to d: inout ModelDesign, state s: GameState) -> [String] {
        let b = s.bonuses
        var changes: [String] = []
        let shiftOK = b.has(.curriculum) && d.mode != .finetune
        func mix(_ m: DataMix) { if d.dataMix != m { d.dataMix = m; changes.append("\(m.rawValue.lowercased()) data") } }
        func shift(_ m: MixShift) { if shiftOK && d.mixShift != m { d.mixShift = m; changes.append("mid-training: \(m.rawValue.lowercased())") } }
        func on(_ kp: WritableKeyPath<ModelDesign, Bool>, _ ok: Bool, _ name: String) {
            if ok && !d[keyPath: kp] { d[keyPath: kp] = true; changes.append(name) }
        }
        func reasoningRL(_ level: RLLevel) {
            guard b.has(.reasoning) else { return }
            on(\.instruct, b.has(.chat), "instruction tuning")
            guard d.instruct else { return }
            on(\.reasoning, true, "reasoning RL")
            if d.rlLevel.rawValue < level.rawValue { d.rlLevel = level; changes.append("\(level.label.lowercased()) RL") }
        }
        d.objective = self
        switch self {
        case .general:
            mix(.balanced)
            if d.mixShift != .keep { d.mixShift = .keep; changes.append("no mid-training shift") }
        case .coding:
            mix(.code)
            shift(.code)
            on(\.toolUse, b.has(.toolUse), "tool use")
            on(\.agentRL, b.has(.agents) && d.toolUse, "agentic RL")
            reasoningRL(.standard)
        case .reasoning:
            mix(.stem)
            shift(.stem)
            reasoningRL(.heavy)
        case .science:
            mix(.stem)
            shift(.stem)
            reasoningRL(.standard)
            on(\.toolUse, b.has(.toolUse), "tool use")
        case .multimodal:
            mix(.conversational)
            on(\.vision, b.has(.vision), "vision")
            on(\.audio, b.has(.audio), "voice")
        case .efficient:
            if b.has(.moe) && d.mode == .scratch {
                let f = b.has(.fineMoE) ? 1.0 / 32 : 1.0 / 16
                if d.activeFraction > f + 1e-9 { d.activeFraction = f; changes.append("\(TrainingExperience.experts(for: f).label) experts") }
            }
            on(\.mtp, b.has(.mtp), "multi-token prediction")
            if b.has(.ssmHybrid) && d.mixer == .transformer { d.mixer = .hybrid; changes.append("hybrid SSM layers") }
            if d.mode == .scratch, let a = HardwareCatalog.get(d.accelID) {
                let before = d.tokensT
                LabMath.reshape(&d, overtrain: 8, accel: a, state: s)
                if d.tokensT > before * 1.05 { changes.append("smaller model on \(Fmt.tokens(d.tokensT)) tokens") }
            }
        }
        return changes
    }
}

extension ModelObjective: DefaultValue { static var defaultValue: ModelObjective { .general } }

/// Compute-threshold rules a run may fall under (moved from the Model Lab so the pre-training review can use it).
enum Regulation {
    static func note(flops: Double, state s: GameState) -> String? {
        if flops >= 1e26 && s.year >= 2023.83 && s.year < 2025.06 { return "Above 10²⁶ FLOPs: must be reported to the US government (EO 14110)." }
        if flops >= 1e25 && s.market.euAIAct { return "Above 10²⁵ FLOPs: an EU AI Act systemic-risk model — needs safety evals before release." }
        return nil
    }
}

/// What the Model Lab's estimate promised when a run started.
struct RunPlan: Codable, Hashable {
    /// Expected wall-clock days (0 when the estimate said it would never finish).
    var days: Double
    var cost: Double
    /// Pre- plus post-training FLOPs.
    var flops: Double
    var mfu: Double
    var goodput: Double
    var coverage: Double
    var incidentDays: Double
    var finish: Date
    var powerMW: Double
    /// `RunScale` raw value.
    var scale: Int
    /// Pre-training compute over the largest run known to be training at the time.
    var frontierShare: Double
    /// Lab rank the forecast index would have had against the released board at launch.
    var expectedRank: Int
}

/// Where a run's peak compute went: every day the training loop adds what it actually lost to each cause.
/// All FLOPs; `useful` is what moved the run forward. Tracked for full runs from 3.5 on (`since` is the progress at
/// which tracking began for runs already going in an older save).
struct RunLedger: Codable, Hashable, DefaultValue {
    @D var days: Int = 0
    @D var peak: Double = 0
    @D var useful: Double = 0
    /// Below peak inside each chip: kernels, memory stalls, the optimizer (MFU short of 100% before communication).
    @D var kernel: Double = 0
    /// Cross-node communication once a run spans more than one scale-up domain.
    @D var comm: Double = 0
    @D var checkpoint: Double = 0
    @D var stragglers: Double = 0
    /// Hardware failures: restart time and work since the last save.
    @D var failures: Double = 0
    /// Days lost while an incident waited for a call (loss spikes, fault storms).
    @D var incidents: Double = 0
    /// Progress thrown away: rollbacks, rewinds, stages redone.
    @D var rewound: Double = 0
    @D var energyMWh: Double = 0
    @D var since: Double = 0

    static var defaultValue: RunLedger { RunLedger() }

    var tracked: Bool { days > 0 && peak > 0 }
}

/// A training first for your lab: shown once, kept in the company history.
struct TrainingFirst: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var model: String
    var date: Date
    var symbol: String
    @D var runID: UUID? = nil
    /// Passed on the way to a bigger first the same day (kept so it never fires later, not shown).
    @D var quiet: Bool = false
}

enum TrainingExperience {
    // MARK: Architecture

    /// Mixture-of-Experts layouts the Model Lab offers, by active fraction (top-k routed experts of a pool).
    struct ExpertLayout: Hashable, Identifiable {
        var fraction: Double
        var experts: Int
        var active: Int
        var needsFine: Bool
        var id: Double { fraction }
        var label: String { "\(experts) × top-\(active)" }
    }

    static let expertLayouts: [ExpertLayout] = [
        ExpertLayout(fraction: 0.25, experts: 8, active: 2, needsFine: false),
        ExpertLayout(fraction: 0.125, experts: 16, active: 2, needsFine: false),
        ExpertLayout(fraction: 0.0625, experts: 64, active: 4, needsFine: false),
        ExpertLayout(fraction: 0.03125, experts: 256, active: 8, needsFine: true),
        ExpertLayout(fraction: 0.015625, experts: 512, active: 8, needsFine: true),
    ]

    static func experts(for fraction: Double) -> ExpertLayout {
        expertLayouts.min { abs(log($0.fraction / max(fraction, 1e-6))) < abs(log($1.fraction / max(fraction, 1e-6))) } ?? expertLayouts[1]
    }

    /// A plausible layer layout for a design, for the architecture diagram. Derived from its parameter count with the
    /// usual transformer proportions (12·L·d² parameters per dense stack, width ≈ 128 × depth); the simulation itself
    /// only uses parameters, sparsity, attention kind, mixer, context and modalities, which the sketch shows as they are.
    struct ArchSketch: Hashable {
        var layers: Int
        var dModel: Int
        var heads: Int
        var kvHeads: Int
        var latent: Int
        var ffn: Int
        var experts: Int
        var activeExperts: Int
        var attentionLayers: Int
        var ssmLayers: Int
        var contextK: Int
        var modalities: [String]
        var routing: String
        var attentionNote: String
        var mixerNote: String
        /// Weights in BF16 and the KV cache for one full-context sequence, GB.
        var weightsGB: Double
        var kvCacheGB: Double
    }

    static func sketch(_ d: ModelDesign, state s: GameState) -> ArchSketch {
        let active = max(d.activeParamsB, 0.001) * 1e9
        let layout = d.isMoE ? experts(for: d.activeFraction) : ExpertLayout(fraction: 1, experts: 1, active: 1, needsFine: false)
        // Per layer: attention 4d² plus the active FFN 8d² (dense) — width ≈ 128 × depth.
        let l = max(2, Int(pow(active / (12 * 128 * 128), 1.0 / 3).rounded()))
        let rawD = (active / (12 * Double(l))).squareRoot()
        let dModel = max(256, Int((rawD / 128).rounded()) * 128)
        let heads = max(2, dModel / 128)
        let kv: Int
        var latent = 0
        let attNote: String
        switch d.attention {
        case .mha:
            kv = heads
            attNote = "Every head keeps its own keys and values: the biggest KV cache."
        case .gqa:
            kv = min(8, heads)
            attNote = "\(heads) query heads share \(min(8, heads)) key/value heads: a \(max(1, heads / min(8, heads)))× smaller KV cache."
        case .mla:
            kv = 0
            latent = max(256, dModel / 14 / 64 * 64)
            attNote = "Keys and values compressed into a \(latent)-wide latent: a KV cache a few percent of multi-head's."
        }
        var attnLayers = l, ssm = 0
        let mixNote: String
        switch d.mixer {
        case .transformer: mixNote = "Standard decoder-only transformer."
        case .hybrid:
            attnLayers = max(1, l / 8)
            ssm = l - attnLayers
            mixNote = "Mamba-style state-space layers with one attention layer in eight: linear-time decoding, long context."
        case .diffusion: mixNote = "Bidirectional transformer that denoises whole blocks of tokens at once instead of one at a time."
        case .alien: mixNote = Xeno.best(s).map { "\($0.name): operators your agents found. Humans follow about \(Int(Xeno.legibility($0, s) * 100))% of it." } ?? "Agent-designed operators."
        }
        var modal = ["Text"]
        if d.vision { modal.append("Vision") }
        if d.audio { modal.append("Voice") }
        if d.video { modal.append("Video") }
        let routing: String
        if d.isMoE {
            routing = "Each token goes to its top \(layout.active) of \(layout.experts) experts; "
                + (s.researched.contains("aux_free") ? "aux-loss-free load balancing keeps the router stable." : "an auxiliary balancing loss — without aux-free routing the router collapses more often (more loss spikes).")
        } else {
            routing = "Dense: every parameter works on every token."
        }
        let ffn = Int((Double(dModel) * 8 / 3 / 256).rounded()) * 256 / (d.isMoE ? max(1, layout.active) : 1)
        let kvWidth = d.attention == .mla ? Double(latent) : Double(2 * kv * 128)
        let kvGB = Double(attnLayers) * kvWidth * Double(d.contextK) * 1024 * 2 / 1e9
        return ArchSketch(layers: l, dModel: dModel, heads: heads, kvHeads: kv, latent: latent, ffn: max(256, ffn),
                          experts: layout.experts, activeExperts: layout.active, attentionLayers: attnLayers, ssmLayers: ssm,
                          contextK: d.contextK, modalities: modal, routing: routing, attentionNote: attNote, mixerNote: mixNote,
                          weightsGB: d.paramsB * 2, kvCacheGB: kvGB)
    }

    // MARK: Scale

    enum RunScale: Int, Comparable {
        case experiment, standard, major, frontier

        static func < (a: RunScale, b: RunScale) -> Bool { a.rawValue < b.rawValue }

        var label: String {
            switch self {
            case .experiment: "Experiment"
            case .standard: "Standard run"
            case .major: "Major run"
            case .frontier: "Frontier run"
            }
        }
    }

    /// The largest pre-training run you know of: rival runs whose start has leaked (or that good intel reveals) and
    /// your own largest so far.
    static func frontierReference(_ s: GameState) -> (flops: Double, source: String) {
        var best = (max(s.maxRunCompute, 1e18), s.maxRunCompute > 0 ? "your largest run" : "")
        let q = RivalIntel.quality(s)
        for c in s.competitors where c.alive {
            guard let p = c.project, p.leaked.contains("start") || q >= 0.5 else { continue }
            if p.flops > best.0 { best = (p.flops, "\(c.def.name)'s \(p.codename)") }
        }
        return best
    }

    /// Frontier: at least half the largest known run. Major: a twentieth of it, or a new personal record by 3× that's
    /// still at least 1% of it.
    static func scale(flops: Double, toy: Bool, state s: GameState) -> RunScale {
        guard !toy else { return .experiment }
        let share = flops / frontierReference(s).flops
        if share >= 0.5 { return .frontier }
        if share >= 0.05 || (s.maxRunCompute > 0 && flops >= 3 * s.maxRunCompute && share >= 0.01) { return .major }
        return .standard
    }

    // MARK: Power

    /// Data-centre PUE the training bill uses (the first real site, as `Economy.chipDailyCost` does).
    static func pue(_ s: GameState) -> Double {
        (s.sites.first { $0.kind != .garage } ?? s.sites.first)?.pue ?? 1.4
    }

    /// Facility power of a run, MW (chips at their TDP plus host overhead, times PUE).
    static func powerMW(chips: Int, accel a: Accelerator, state s: GameState) -> Double {
        Double(chips) * Economy.chipKW(a) * pue(s) / 1000
    }

    // MARK: Ledger (called from the daily training step; arithmetic only, no dice)

    static func ledgerDay(_ s: inout GameState, _ i: Int, accel a: Accelerator, coverage cov: Double, raw: Double, ckpt: Double, straggle: Double) {
        let d = s.runs[i].design
        let b = s.bonuses
        let peak = Double(d.chips) * a.trainTFLOPS(d.precision) * 1e12 * 86_400
        let m = Physics.runMFU(d, accel: a, coverage: cov, state: s, bonuses: b)
        let mult = Physics.scaleOutFactor(accel: a, chips: d.chips, bonuses: b)
        let comm = min(max(0, peak - raw), mult < 1 ? peak * m * (1 / mult - 1) : 0)
        if s.runs[i].ledger.days == 0 { s.runs[i].ledger.since = s.runs[i].status == .postTraining ? 1 : s.runs[i].progress }
        s.runs[i].ledger.days += 1
        s.runs[i].ledger.peak += peak
        s.runs[i].ledger.comm += comm
        s.runs[i].ledger.kernel += max(0, peak - raw - comm)
        s.runs[i].ledger.checkpoint += raw * (1 - ckpt)
        s.runs[i].ledger.stragglers += raw * ckpt * (1 - straggle)
        s.runs[i].ledger.energyMWh += powerMW(chips: d.chips, accel: a, state: s) * 24
    }

    static func rewound(_ s: inout GameState, _ i: Int, _ flops: Double) {
        guard flops > 0, s.runs[i].kind == .full else { return }
        s.runs[i].ledger.rewound += flops
    }

    // MARK: Compute breakdown

    struct Slice: Identifiable, Hashable {
        enum Kind: String { case useful, kernel, comm, checkpoint, stragglers, failures, incidents, rewound }
        var kind: Kind
        var share: Double
        var id: String { kind.rawValue }

        var label: String {
            switch kind {
            case .useful: "Useful training"
            case .kernel: "Kernel efficiency"
            case .comm: "Communication"
            case .checkpoint: "Checkpointing"
            case .stragglers: "Stragglers"
            case .failures: "Failures & restarts"
            case .incidents: "Incidents"
            case .rewound: "Rolled back"
            }
        }

        var about: String {
            switch kind {
            case .useful: "Compute that moved the model forward."
            case .kernel: "Inside each chip: kernels, memory stalls and the optimizer keep MFU below 100%."
            case .comm: "Gradients and activations crossing between scale-up domains."
            case .checkpoint: "Pausing to write checkpoints and run evals."
            case .stragglers: "The whole job waits for its slowest nodes."
            case .failures: "Restarts after hardware faults and the work since the last save."
            case .incidents: "Days spent waiting on a loss spike or fault storm."
            case .rewound: "Progress thrown away by rollbacks, rewinds and redone stages."
            }
        }
    }

    /// Expected split of a design's peak compute, from exactly the terms the daily step uses.
    static func expectedSlices(_ d: ModelDesign, coverage cov: Double, interval: Double, incidentShare: Double, state s: GameState) -> [Slice] {
        guard let a = HardwareCatalog.get(d.accelID) else { return [] }
        let b = s.bonuses
        let m = Physics.runMFU(d, accel: a, coverage: cov, state: s, bonuses: b)
        let mult = Physics.scaleOutFactor(accel: a, chips: d.chips, bonuses: b)
        let comm = min(1 - m, mult < 1 ? m * (1 / mult - 1) : 0)
        let e = Training.opsEffect(cov, s)
        let ckpt = Sim.checkpointOverhead(interval)
        let strag = 1 - (1 - Physics.stragglerFactor(chips: d.chips, bonuses: b)) * (1 - e.stragglers)
        let lambda = Double(d.chips) * Training.failuresPerChipDay * (1 - e.prevented)
        let hours = Physics.hoursLostPerFailure(state: s, bonuses: b, chips: d.chips) * (1 - e.recovery)
        let up = Training.expectedUptime(lambda: lambda, hours: hours)
        let afterOverheads = m * ckpt * strag
        let running = afterOverheads * up
        let inc = running * clamp(incidentShare, 0, 1)
        return [
            Slice(kind: .useful, share: running - inc),
            Slice(kind: .kernel, share: max(0, 1 - m - comm)),
            Slice(kind: .comm, share: comm),
            Slice(kind: .checkpoint, share: m * (1 - ckpt)),
            Slice(kind: .stragglers, share: m * ckpt * (1 - strag)),
            Slice(kind: .failures, share: afterOverheads * (1 - up)),
            Slice(kind: .incidents, share: inc),
        ]
    }

    /// What actually happened to a run's peak compute so far (nil before the first tracked day).
    static func actualSlices(_ l: RunLedger) -> [Slice]? {
        guard l.tracked else { return nil }
        let p = l.peak
        // Rewound compute was counted useful the day it ran; move it out.
        return [
            Slice(kind: .useful, share: max(0, l.useful - l.rewound) / p),
            Slice(kind: .kernel, share: l.kernel / p),
            Slice(kind: .comm, share: l.comm / p),
            Slice(kind: .checkpoint, share: l.checkpoint / p),
            Slice(kind: .stragglers, share: l.stragglers / p),
            Slice(kind: .failures, share: l.failures / p),
            Slice(kind: .incidents, share: l.incidents / p),
            Slice(kind: .rewound, share: min(l.rewound, l.useful) / p),
        ]
    }

    // MARK: Fixes

    /// Something a warning or the bottleneck inspector can do for you.
    enum FixAction: Hashable {
        /// Model Lab design changes.
        case designChips(Int), designTokens(Double), designParams(Double), reshape, ladder, designCheckpoint(Double), designLR(LRSchedule)
        /// Running-run changes.
        case resizeRun(Int), runCheckpoint(Double), runLR(LRSchedule), assignOps
        case open(Screen)
    }

    struct Fix: Hashable, Identifiable {
        var label: String
        var action: FixAction
        var id: String { label }
    }

    struct Warning: Hashable, Identifiable {
        enum Level: Int { case info, warn, block }
        var level: Level
        var title: String
        var detail: String
        var fixes: [Fix] = []
        var id: String { title }
    }

    /// The biggest loss of compute and what would cut it.
    struct Bottleneck: Hashable {
        var kind: Slice.Kind
        var share: Double
        var headline: String
        var detail: String
        var fixes: [Fix]
    }

    /// `running` true for a live run (its coverage and settings); false for a Model Lab design.
    static func bottleneck(_ slices: [Slice], design d: ModelDesign, coverage cov: Double, interval: Double, running: Bool, state s: GameState) -> Bottleneck? {
        let b = s.bonuses
        guard let worst = slices.filter({ $0.kind != .useful }).max(by: { $0.share < $1.share }), worst.share > 0.01,
              let a = HardwareCatalog.get(d.accelID) else { return nil }
        let pct = Fmt.pct(worst.share, decimals: 0)
        var fixes: [Fix] = []
        var detail = ""
        let headline = "\(worst.label) takes \(pct) of peak compute"
        switch worst.kind {
        case .useful: return nil
        case .kernel:
            let m = Physics.runMFU(d, accel: a, coverage: cov, state: s, bonuses: b)
            let engineers = s.employees.filter { $0.role == .mlEngineer }.reduce(0.0) { $0 + $1.weight }
            let needed = 0.5 + Double(d.chips) / 1_500
            detail = "MFU is \(Fmt.pct(m, decimals: 0)) on \(a.name) (base \(Fmt.pct(a.baseMFU, decimals: 0))). Every frontier lab loses most of peak here; "
                + (engineers < needed * 0.95 ? "your ML engineers (\(Fmt.trim(engineers, 1)) of ~\(Fmt.trim(needed, 1)) needed for this size) add up to +4 points when fully staffed, " : "")
                + "MFU research and training-ops agents add a few more."
            if engineers < needed * 0.95 { fixes.append(Fix(label: "Hire ML engineers", action: .open(.team))) }
            fixes.append(Fix(label: "MFU research", action: .open(.research)))
        case .comm:
            let domains = Int((Double(d.chips) / Double(max(1, a.scaleUp))).rounded(.up))
            detail = "\(Fmt.int(d.chips)) chips span \(Fmt.int(domains)) scale-up domains of \(a.scaleUp) (\(a.interconnect)); every tenfold beyond one domain costs \(Fmt.pct((a.scaleUp <= 2 ? 0.13 : 0.06) * (1 - b.scaleOut), decimals: 0)) of MFU. Chips with bigger scale-up domains and scale-out research cut it."
            fixes.append(Fix(label: "Scale-out research", action: .open(.research)))
            fixes.append(Fix(label: "Hardware with bigger NVLink domains", action: .open(.hardware)))
        case .checkpoint:
            detail = "Saving every \(Int(interval * 100))% of pre-training pauses the job often. Every 10% costs a fraction as much; the trade-off is more lost on a loss-spike rollback."
            fixes.append(Fix(label: "Checkpoint every 10%", action: running ? .runCheckpoint(0.1) : .designCheckpoint(0.1)))
        case .stragglers:
            detail = "At \(Fmt.int(d.chips)) chips the synchronous job waits for its slowest nodes. Ops agents evict stragglers (70% of the loss at full coverage)."
            fixes.append(Fix(label: running ? "Assign ops agents" : "Start a training-ops swarm", action: running ? .assignOps : .open(.swarms)))
        case .failures:
            let adv = Training.goodputAdvice(chips: d.chips, coverage: cov, running: running, state: s, bonuses: b)
            detail = adv?.headline ?? "A fault every few hours at this size; each restart loses the work since the last save."
            if cov < 0.95 { fixes.append(Fix(label: running ? "Assign ops agents" : "Start a training-ops swarm", action: running ? .assignOps : .open(.swarms))) }
            if let adv, adv.healthyChips < d.chips {
                fixes.append(Fix(label: "Use \(Fmt.int(adv.healthyChips)) chips", action: running ? .resizeRun(adv.healthyChips) : .designChips(adv.healthyChips)))
            }
            fixes.append(Fix(label: "Infra engineers", action: .open(.team)))
        case .incidents:
            detail = "Loss spikes and fault storms that waited for a call. Ops agents catch most spikes within minutes; a conservative learning rate makes them a third as likely."
            fixes.append(Fix(label: "Conservative learning rate", action: running ? .runLR(.conservative) : .designLR(.conservative)))
            if cov < 0.5 { fixes.append(Fix(label: running ? "Assign ops agents" : "Start a training-ops swarm", action: running ? .assignOps : .open(.swarms))) }
        case .rewound:
            detail = "Progress thrown away by rollbacks, contamination scrubs and redone post-training stages."
            fixes.append(Fix(label: "Conservative learning rate", action: running ? .runLR(.conservative) : .designLR(.conservative)))
        }
        return Bottleneck(kind: worst.kind, share: worst.share, headline: headline, detail: detail, fixes: fixes)
    }

    // MARK: Review

    /// Everything the pre-training review shows, from the estimate, the forecast and the world as it stands.
    struct Review {
        var design: ModelDesign
        var est: Physics.Estimate
        var accel: Accelerator
        var scale: RunScale
        var frontierShare: Double
        var frontierSource: String
        var known: Bool
        var mean: Double
        var low: Double
        var high: Double
        var tier: String
        var comparable: String
        var domains: DomainScores
        var memPerChipGB: Double
        var memGroup: Int
        var scaleUpDomains: Int
        var scaleOutLoss: Double
        var powerMW: Double
        var energyMWh: Double
        var finish: Date?
        var servingPerM: Double?
        var rankNow: Int
        var rankAtFinish: Int
        /// Rival releases the Rival Watch expects before this run finishes that would beat its forecast.
        var rivalsAhead: [(lab: String, model: String, index: Double, date: Date)]
        var expectedFailures: Double
        var expectedSpikes: Double
        var risks: [String]
        var warnings: [Warning]
        var slices: [Slice]
        var bottleneck: Bottleneck?
        var arch: ArchSketch
    }

    static func review(_ d: ModelDesign, lr: LRSchedule, interval: Double, state s: GameState, set: [Benchmark],
                       board: [Leaderboard.Entry], watch: [RivalIntel.Row]) -> Review? {
        guard let a = HardwareCatalog.get(d.accelID), let est = Physics.estimate(d, state: s, lr: lr, interval: interval) else { return nil }
        let b = s.bonuses
        var f = est.forecast
        f.c += lr.qualityBonus
        let band = ForecastEngine.indexBand(f, design: d, set: set)
        let released = board.filter(\.released)
        let gone = Leaderboard.goneLabs(s)
        let top = released.filter { !$0.isPlayer }.map(\.index).max() ?? 0
        let ref = frontierReference(s)
        let total = est.flops
        let scale = self.scale(flops: total, toy: est.toy, state: s)
        let mem = est.memory
        let group = mem.haveGB.isFinite ? max(1, Int((mem.haveGB / max(a.memoryGB, 1)).rounded())) : d.chips
        let perChip = mem.needGB / Double(group)
        let mult = Physics.scaleOutFactor(accel: a, chips: d.chips, bonuses: b)
        let mw = powerMW(chips: d.chips, accel: a, state: s)
        let finish = est.finishes ? GameCalendar.addDays(s.date, Int(est.days.rounded(.up))) : nil
        let rankNow = Leaderboard.labRank(index: band.mean, board: released, gone: gone)
        var ahead: [(lab: String, model: String, index: Double, date: Date)] = []
        var aheadLabs = Set(released.filter { !$0.isPlayer && $0.index > band.mean && !gone.contains($0.labID) }.map(\.labID))
        if let finish {
            for r in watch where r.outlook.center <= finish && r.outlook.index > band.mean {
                ahead.append((r.lab, r.project.name, r.outlook.index, r.outlook.center))
                aheadLabs.insert(r.id)
            }
        }
        let rankAtFinish = aheadLabs.count + 1
        let cov = est.coverage
        let spikes = est.toy ? 0 : Training.spikeChance(d, lr: lr, state: s, bonuses: b) * (1 - Training.opsEffect(cov, s).spikes) * (est.finishes ? est.days : 0) * 0.97
        var risks: [String] = []
        if !est.toy {
            risks.append("\(Int((f.bugRisk * 100).rounded()))% chance of a silent bug that drags the loss above forecast until someone finds it.")
            if spikes >= 0.3 { risks.append("About \(Fmt.trim(spikes, 1)) loss spikes expected\(cov >= 0.5 ? " (ops agents rewind them in minutes)" : ""). Each one waits for your call unless auto-rollback is on.") }
            if d.chips >= 4_000 { risks.append("Big enough for a hardware fault storm (a bad batch of chips) — two days of node swaps, or weeks degraded.") }
            risks += Training.postTrainingRisks(d, toy: false, state: s)
        }
        let incidentShare = est.finishes && est.days > 0 ? est.incidentDays / est.days : 0
        let slices = expectedSlices(d, coverage: cov, interval: interval, incidentShare: incidentShare, state: s)
        var warnings: [Warning] = []

        // Memory
        if !mem.ok {
            var fixes: [Fix] = []
            let fitParams = mem.haveGB / (d.mode == .finetune ? Physics.finetuneBytesPerParam : Physics.trainingBytesPerParam * 1.1) * 0.95
            if fitParams >= 0.05 && d.mode == .scratch { fixes.append(Fix(label: "Shrink to \(Fmt.params(fitParams))", action: .designParams(fitParams))) }
            if b.has(.sharding) {
                let need = Int((mem.needGB / a.memoryGB).rounded(.up))
                let free = Economy.freeChips(s, d.accelID)
                if need <= free { fixes.append(Fix(label: "Use \(Fmt.int(need)) chips", action: .designChips(need))) }
            }
            fixes.append(Fix(label: "Hardware Store", action: .open(.hardware)))
            warnings.append(Warning(level: .block, title: "Doesn't fit in memory",
                                    detail: "Training state needs \(Fmt.memory(mem.needGB)) and \(group == 1 ? "each chip" : "each group of \(group)") holds \(Fmt.memory(mem.haveGB)). \(mem.note)",
                                    fixes: fixes))
        }
        // Data
        if d.mode == .scratch {
            let unique = Physics.uniqueTokensT(d, state: s)
            if f.repetition < -0.01 {
                var fixes = [Fix(label: "Re-split the compute", action: .reshape), Fix(label: "More data sources", action: .open(.data))]
                if unique * 4 < d.tokensT { fixes.insert(Fix(label: "Cut to \(Fmt.tokens(unique * 4)) (4 epochs)", action: .designTokens(unique * 4)), at: 1) }
                warnings.append(Warning(level: .warn, title: "Data repeated \(Fmt.trim(d.tokensT / max(unique, 1e-9), 1))×",
                                        detail: "Only \(Fmt.tokens(unique)) unique tokens: repeated tokens are worth less (×\(Fmt.trim(pow(10, f.repetition), 2)) effective compute). A bigger model on fewer passes, or more data, gets more from the same FLOPs.",
                                        fixes: fixes))
            }
            if f.allocation < -0.05 {
                let under = f.tokensPerParam < f.optimalTokensPerParam
                warnings.append(Warning(level: under ? .warn : .info, title: under ? "Under-trained for its size" : "Over-trained for its size",
                                        detail: "\(Int(f.tokensPerParam)) tokens per parameter against ~\(Int(f.optimalTokensPerParam)) compute-optimal: ×\(Fmt.trim(pow(10, f.allocation), 2)) effective compute."
                                            + (under ? "" : " Fine if you want it cheap to serve."),
                                        fixes: b.has(.scalingLaws) ? [Fix(label: "Compute-optimal split", action: .reshape)] : []))
            }
        }
        // Scale-out
        if mult < 0.85 {
            warnings.append(Warning(level: .info, title: "Scale-out costs \(Fmt.pct(1 - mult, decimals: 0)) of MFU",
                                    detail: "\(Fmt.int(d.chips)) chips across \(Fmt.int(Int((Double(d.chips) / Double(max(1, a.scaleUp))).rounded(.up)))) domains of \(a.scaleUp) over \(a.interconnect).",
                                    fixes: [Fix(label: "Scale-out research", action: .open(.research))]))
        }
        // Goodput
        if let adv = Training.goodputAdvice(chips: d.chips, coverage: cov, running: false, state: s, bonuses: b) {
            var fixes: [Fix] = []
            if adv.healthyChips < d.chips { fixes.append(Fix(label: "Use \(Fmt.int(adv.healthyChips)) chips", action: .designChips(adv.healthyChips))) }
            if cov < 0.95 { fixes.append(Fix(label: "Start a training-ops swarm", action: .open(.swarms))) }
            fixes.append(Fix(label: "Infra engineers", action: .open(.team)))
            warnings.append(Warning(level: adv.blocked ? .block : .warn,
                                    title: adv.blocked ? "Would stall: goodput \(Fmt.pct(adv.goodput, decimals: 0))" : "Low goodput: \(Fmt.pct(adv.goodput, decimals: 0))",
                                    detail: adv.headline + (cov < 0.05 ? " No ops agents watch new runs." : ""), fixes: fixes))
        }
        // Money and time
        if est.finishes && est.totalCost > s.cash {
            warnings.append(Warning(level: .warn, title: "Costs more than your cash",
                                    detail: "\(Fmt.money(est.totalCost)) over \(Fmt.days(est.days)) against \(Fmt.money(s.cash)) in the bank. The run keeps billing daily.",
                                    fixes: [Fix(label: "Funding", action: .open(.funding))]))
        }
        if est.finishes && est.days > 180 {
            warnings.append(Warning(level: .info, title: "Takes \(Fmt.days(est.days))",
                                    detail: "The field moves on while it trains: the Rival Watch expects \(ahead.count) release\(ahead.count == 1 ? "" : "s") that beat its forecast before it finishes.",
                                    fixes: [Fix(label: "Get more compute", action: .open(.hardware))]))
        }
        // Forecast confidence
        if b.has(.proxyLadder) && d.mode == .scratch && !f.ladderCovered && scale >= .major {
            warnings.append(Warning(level: .info, title: "Forecast untested at this scale",
                                    detail: "±\(Fmt.trim(f.sigma, 2)) uncertainty (×\(Fmt.trim(pow(10, f.sigma), 2)) effective compute). A scaling ladder costs ~2% of the compute, nearly halves it and catches most bugs.",
                                    fixes: [Fix(label: "Run a scaling ladder first", action: .ladder)]))
        }
        if let note = Regulation.note(flops: total, state: s) {
            warnings.append(Warning(level: .info, title: "Regulated compute", detail: note))
        }
        warnings.sort { $0.level.rawValue > $1.level.rawValue }
        return Review(design: d, est: est, accel: a, scale: scale, frontierShare: total / ref.flops, frontierSource: ref.source,
                      known: b.has(.scalingLaws), mean: band.mean, low: band.low, high: band.high,
                      tier: ForecastEngine.tier(index: band.mean, top: top),
                      comparable: RealModels.closest(index: band.mean, set: set).map { "\($0.name) (\($0.lab), \($0.date.label))" } ?? "—",
                      domains: Capabilities.forecast(ForecastEngine.profile(f, design: d, key: "review"), design: d, state: s),
                      memPerChipGB: perChip, memGroup: group, scaleUpDomains: Int((Double(d.chips) / Double(max(1, a.scaleUp))).rounded(.up)),
                      scaleOutLoss: 1 - mult, powerMW: mw, energyMWh: est.finishes ? mw * 24 * est.days : 0, finish: finish,
                      servingPerM: Economy.servingCostPerM(design: d, s), rankNow: rankNow, rankAtFinish: rankAtFinish,
                      rivalsAhead: ahead.sorted { $0.date < $1.date },
                      expectedFailures: Double(d.chips) * Training.failuresPerChipDay * (1 - Training.opsEffect(cov, s).prevented) * (est.finishes ? est.days : 1),
                      expectedSpikes: spikes, risks: risks, warnings: warnings, slices: slices,
                      bottleneck: bottleneck(slices, design: d, coverage: cov, interval: interval, running: false, state: s),
                      arch: sketch(d, state: s))
    }

    /// Applies a design-side fix (the Model Lab carries the others out itself). Returns a note, or nil.
    @discardableResult
    static func applyDesignFix(_ a: FixAction, to d: inout ModelDesign, state s: GameState) -> String? {
        switch a {
        case .designChips(let n): d.chips = max(1, n); return nil
        case .designTokens(let t): d.tokensT = max(0.0005, t); return nil
        case .designParams(let p): d.paramsB = max(0.05, p); return nil
        case .reshape:
            guard let acc = HardwareCatalog.get(d.accelID) else { return nil }
            return LabMath.reshape(&d, overtrain: d.objective == .efficient ? 8 : 1, accel: acc, state: s)
        default: return nil
        }
    }

    // MARK: Plan (at launch)

    static func plan(_ run: TrainingRun, est: Physics.Estimate, expectedRank: Int, state s: GameState) -> RunPlan {
        let a = HardwareCatalog.get(run.design.accelID)
        let ref = frontierReference(s)
        let finite = est.finishes
        return RunPlan(days: finite ? est.days : 0, cost: finite ? est.totalCost : 0, flops: est.flops + est.postFlops, mfu: est.mfu,
                       goodput: est.goodput, coverage: est.coverage, incidentDays: est.incidentDays,
                       finish: finite ? GameCalendar.addDays(s.date, Int(est.days.rounded(.up))) : s.date,
                       powerMW: a.map { powerMW(chips: run.design.chips, accel: $0, state: s) } ?? 0,
                       scale: scale(flops: est.flops, toy: est.toy, state: s).rawValue,
                       frontierShare: est.flops / ref.flops, expectedRank: expectedRank)
    }

    // MARK: Training firsts

    static let paramFirsts: [(id: String, b: Double, title: String)] = [
        ("params_1b", 1, "First billion-parameter model"), ("params_10b", 10, "First 10B-parameter model"),
        ("params_100b", 100, "First 100B-parameter model"), ("params_1t", 1_000, "First trillion-parameter model"),
    ]
    static let chipFirsts: [(id: String, n: Int, title: String)] = [
        ("chips_10k", 10_000, "First 10,000-accelerator run"), ("chips_100k", 100_000, "First 100,000-accelerator run"),
        ("chips_500k", 500_000, "First 500,000-accelerator run"),
    ]

    static func has(_ s: GameState, _ id: String) -> Bool { s.trainingFirsts.contains { $0.id == id } }

    /// A first an older save already reached before firsts were recorded: (model, date).
    typealias Precedent = (model: String, date: Date)

    /// Records the largest new first of a ladder (the smaller ones it passed are kept quietly) and announces it.
    /// Firsts an older save had already reached go into the history with their original model and date, unannounced.
    private static func award(_ s: inout GameState, ladder: [(id: String, title: String)], detail: String, model: String, runID: UUID, symbol: String,
                              precedent: (String) -> Precedent?) {
        var fresh: [(id: String, title: String)] = []
        for f in ladder where !has(s, f.id) {
            if let p = precedent(f.id) {
                s.trainingFirsts.append(TrainingFirst(id: f.id, title: f.title, detail: "Reached before the lab kept a training history.",
                                                      model: p.model, date: p.date, symbol: symbol))
            } else {
                fresh.append(f)
            }
        }
        s.trainingFirsts.sort { $0.date < $1.date }
        guard let top = fresh.last else { return }
        for f in fresh.dropLast() {
            s.trainingFirsts.append(TrainingFirst(id: f.id, title: f.title, detail: "", model: model, date: s.date, symbol: symbol, runID: runID, quiet: true))
        }
        record(&s, id: top.id, title: top.title, detail: detail, model: model, runID: runID, symbol: symbol)
    }

    private static func record(_ s: inout GameState, id: String, title: String, detail: String, model: String, runID: UUID, symbol: String,
                               precedent: Precedent? = nil) {
        guard !has(s, id) else { return }
        if let p = precedent {
            s.trainingFirsts.append(TrainingFirst(id: id, title: title, detail: "Reached before the lab kept a training history.", model: p.model, date: p.date, symbol: symbol))
            s.trainingFirsts.sort { $0.date < $1.date }
            return
        }
        s.trainingFirsts.append(TrainingFirst(id: id, title: title, detail: detail, model: model, date: s.date, symbol: symbol, runID: runID))
        Sim.news(&s, "\(s.companyName) history: \(title.lowercased())", "\(model): \(detail)", .company, image: "supercomputer", important: true, good: true)
        Alerts.raise(&s, .milestone, key: "first|\(id)", title: title, body: "\(model) — \(detail)", screen: .training, celebrate: true, cooldown: 0)
    }

    /// Firsts a run earns when it starts: cluster size.
    static func launched(_ s: inout GameState, run: TrainingRun) {
        guard run.kind == .full, !run.toy else { return }
        let chips = run.design.chips
        let ladder = chipFirsts.filter { chips >= $0.n }.map { (id: $0.id, title: $0.title) }
        let a = HardwareCatalog.get(run.design.accelID)?.name ?? "accelerators"
        let earlier = s.runs.filter { $0.kind == .full && !$0.toy && $0.id != run.id }
        award(&s, ladder: ladder, detail: "\(Fmt.int(chips)) \(a) training one model, drawing \(Fmt.trim(run.plan?.powerMW ?? 0, 0)) MW of facility power.",
              model: run.design.name, runID: run.id, symbol: "cpu.fill") { id in
            guard let n = chipFirsts.first(where: { $0.id == id })?.n,
                  let r = earlier.filter({ $0.design.chips >= n }).min(by: { $0.started < $1.started }) else { return nil }
            return (r.design.name, r.started)
        }
    }

    /// Firsts a finished run earns: size, sparsity, the frontier, specialists, autonomy.
    static func finished(_ s: inout GameState, run: TrainingRun, model m: AIModel, previousBest: Double?, rank: Int) {
        guard run.kind == .full else { return }
        let d = run.design
        let ladder = paramFirsts.filter { d.paramsB >= $0.b }.map { (id: $0.id, title: $0.title) }
        let earlier = s.models.filter { $0.id != m.id && !$0.preview }
        func first(_ ok: (AIModel) -> Bool) -> Precedent? {
            earlier.filter(ok).min { $0.created < $1.created }.map { ($0.name, $0.created) }
        }
        award(&s, ladder: ladder, detail: "\(Fmt.params(d.paramsB)) parameters\(d.isMoE ? " (\(Fmt.params(d.activeParamsB)) active)" : "") trained on \(Fmt.tokens(d.tokensT)) tokens.",
              model: m.name, runID: run.id, symbol: "square.stack.3d.up.fill") { id in
            guard let b = paramFirsts.first(where: { $0.id == id })?.b else { return nil }
            return first { $0.design.paramsB >= b }
        }
        guard !run.toy && !m.preview else { return }
        if d.isMoE, let prev = previousBest, m.index > prev {
            let layout = experts(for: d.activeFraction)
            record(&s, id: "moe_breakthrough", title: "First Mixture-of-Experts breakthrough",
                   detail: "\(layout.label) experts beat every model you had: index \(Fmt.score(m.index)) against \(Fmt.score(prev)).",
                   model: m.name, runID: run.id, symbol: "square.grid.3x3.fill",
                   precedent: first { e in e.design.isMoE && e.index > (earlier.filter { $0.created < e.created }.map(\.index).max() ?? .infinity) })
        }
        if rank == 1 {
            let before: Precedent? = s.achievements.contains("frontier")
                ? (first { $0.tier.hasPrefix("Genius") } ?? earlier.max { $0.index < $1.index }.map { ($0.name, $0.created) }) : nil
            record(&s, id: "past_frontier", title: "First model past the frontier",
                   detail: "Intelligence Index \(Fmt.score(m.index)): ahead of every released rival model.", model: m.name, runID: run.id, symbol: "crown.fill",
                   precedent: before)
        }
        let v = Capabilities.playerScores(m, research: Capabilities.researchDomains(s))
        switch d.objective {
        case .coding:
            record(&s, id: "specialist_coding", title: "First specialist coding model",
                   detail: "Trained for code: coding \(Fmt.trim(v[.coding], 0)), agents \(Fmt.trim(v[.agents], 0)).", model: m.name, runID: run.id, symbol: "chevron.left.forwardslash.chevron.right")
        case .science:
            record(&s, id: "specialist_science", title: "First specialist science model",
                   detail: "Trained for science: science \(Fmt.trim(v[.science], 0)), maths \(Fmt.trim(v[.math], 0)).", model: m.name, runID: run.id, symbol: "atom")
        default: break
        }
        if let ms = MilestoneCatalog.byID["ai_scientist"], Milestones.meets(v, ms) {
            record(&s, id: "autonomous_research", title: "First model capable of autonomous research",
                   detail: "Science \(Fmt.trim(v[.science], 0)) and agents \(Fmt.trim(v[.agents], 0)): it can run a research programme on its own.",
                   model: m.name, runID: run.id, symbol: "flask.fill",
                   precedent: first { e in s.domainScores[e.id.uuidString].map { Milestones.meets($0, ms) } ?? false })
        }
    }

    // MARK: Results

    struct Results {
        var index: Double
        var rank: Int
        /// The launch forecast re-scored on today's benchmarks (the index rotates while a run trains), with its 80% band.
        var forecastIndex: Double?
        var forecastLow: Double?
        var forecastHigh: Double?
        /// The forecast as quoted at launch, on that day's benchmarks.
        var launchIndex: Double?
        var plannedDays: Double?
        var plannedCost: Double?
        var plannedFinish: Date?
        var expectedRank: Int?
        var days: Int
        var cost: Double
        var domains: DomainScores
        /// Domains sorted by the margin over the best rival in each (strongest first).
        var margins: [(domain: CapDomain, score: Double, rival: Double, lab: String)]
        var previous: (name: String, index: Double)?
        var tps: Double?
        var servingPerM: Double?
        var firsts: [TrainingFirst]
        var record: Bool
        var disappointing: Bool
    }

    static func results(_ run: TrainingRun, model m: AIModel, index: Double, board: [Leaderboard.Entry], set: [Benchmark], state s: GameState) -> Results {
        let b = s.bonuses
        let released = board.filter(\.released)
        let rank = Leaderboard.labRank(index: index, board: released, gone: Leaderboard.goneLabs(s))
        let v = s.domainScores[m.id.uuidString] ?? Capabilities.playerScores(m, research: Capabilities.researchDomains(s))
        let names = Dictionary(uniqueKeysWithValues: s.competitors.map { ($0.id, $0.def.name) })
        let rivals = Capabilities.bestRival(s)
        let margins = CapDomain.allCases.map { d in
            (domain: d, score: v[d], rival: rivals[d.index].score, lab: names[rivals[d.index].lab] ?? "")
        }.sorted { ($0.score - $0.rival) > ($1.score - $1.rival) }
        let prev = s.models.filter { $0.id != m.id && !$0.preview && $0.created <= m.created }.max { $0.index < $1.index }
        let days = max(1, GameCalendar.daysBetween(run.started, run.finished ?? s.date))
        let accel = HardwareCatalog.get(run.design.accelID)
        let tps = accel.map { Physics.tps(m, accel: $0, precision: m.servingPrecision, bonuses: b) }
        var serving = m
        if let a = accel { serving.deployments = [Deployment(accelID: a.id, chips: Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b))] }
        let perM = accel != nil ? Economy.servingCostPerM(serving, s, bonuses: b) : 0
        let firsts = s.trainingFirsts.filter { $0.runID == run.id && !$0.quiet }
        // Worth a staged reveal: #1, your first model, a big jump on your best, or a first about the model itself.
        let record = rank == 1 || prev == nil || index > (prev?.index ?? 0) + 5 || firsts.contains { !$0.id.hasPrefix("chips_") }
        let fc = run.forecast
        // Re-score the forecast capability on today's benchmarks, as the forecast verdict does.
        var today: (mean: Double, low: Double, high: Double)? = nil
        if fc != nil && m.cForecast != 0 {
            var p = Leaderboard.profile(m)
            let sigma = max(0.01, m.forecastSigma)
            func at(_ c: Double, _ k: String) -> Double {
                p.c = c
                p.key = "\(m.id.uuidString)-\(k)"
                return BenchmarkCatalog.index(p, set: set)
            }
            today = (at(m.cForecast, "fc"), at(m.cForecast - 1.28 * sigma, "fcl"), at(m.cForecast + 1.28 * sigma, "fch"))
        }
        // Below the 80% band by a visible margin, or well short of the mean.
        let disappointing = today.map { index < min($0.low, $0.mean - 1.5) || index < $0.mean - 4 } ?? false
        return Results(index: index, rank: rank, forecastIndex: today?.mean, forecastLow: today?.low, forecastHigh: today?.high, launchIndex: fc?.index,
                       plannedDays: run.plan.flatMap { $0.days > 0 ? $0.days : nil }, plannedCost: run.plan.flatMap { $0.cost > 0 ? $0.cost : nil },
                       plannedFinish: run.plan?.finish, expectedRank: run.plan?.expectedRank, days: days, cost: run.cost, domains: v, margins: margins,
                       previous: prev.map { ($0.name, $0.index) }, tps: tps, servingPerM: perM > 0 ? perM : nil, firsts: firsts,
                       record: record, disappointing: disappointing)
    }

    // MARK: Validation loss (derived)

    /// A held-out loss series for the chart. The simulation draws one training loss per point; this derives the
    /// validation curve from it without new dice: a 5-point moving average of the training loss (spikes excluded),
    /// plus a generalisation gap that opens once the run repeats its data — 0.01 nats per extra epoch over the unique
    /// tokens it had at launch.
    static func validation(_ run: TrainingRun, uniqueTokensT: Double) -> [(tokensT: Double, loss: Double)] {
        let pts = run.loss.filter { !$0.spike }
        guard pts.count >= 2 else { return [] }
        var out: [(Double, Double)] = []
        out.reserveCapacity(pts.count)
        for i in pts.indices {
            let lo = max(0, i - 4)
            let avg = pts[lo...i].reduce(0) { $0 + $1.loss } / Double(i - lo + 1)
            let epochs = uniqueTokensT > 0 ? pts[i].tokensT / uniqueTokensT : 0
            out.append((pts[i].tokensT, avg + 0.01 * max(0, epochs - 1)))
        }
        return out
    }
}
