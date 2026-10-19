import Foundation

/// One contribution to a forecast, shown to the player ("MoE ×3.1", "Under-trained ×0.62").
struct ForecastDriver: Identifiable, Hashable {
    enum Kind: Hashable { case base, gain, penalty, skill }
    var id: String { name }
    let name: String
    /// log10 effective-compute contribution (or skill units for `.skill`).
    let value: Double
    let kind: Kind
    var detail: String = ""

    var multiplier: Double { pow(10, value) }
}

/// The scaling-law forecast for a design: expected capability, its uncertainty, and everything behind it.
struct Forecast {
    var c: Double = 0
    var sigma: Double = 0.3
    var rawC: Double = 0
    var allocation: Double = 0
    var repetition: Double = 0
    var algo: Double = 0
    var data: Double = 0
    var reasoning: Double = 0
    var code: Double = 0
    var agent: Double = 0
    var chat: Double = 0
    var lang: Double = 0
    var longctx: Double = 0
    var vis: Double = 0
    var safety: Double = 30
    var arena: Double = 0
    var drivers: [ForecastDriver] = []
    var penalties: [String] = []
    var notes: [String] = []
    var novel: [String] = []
    var bugRisk: Double = 0
    var usesShadowData = false
    var keyTech: [String] = []
    var finalLoss: Double = 0
    var ladderCovered = false
    var tokensPerParam: Double = 0
    var optimalTokensPerParam: Double = 20
}

enum ForecastEngine {
    // Epoch AI's replication of the Chinchilla fit (Besiroglu et al., 2024):
    // L(N, D) = E + A / N^α + B / D^β
    static let E = 1.8172
    static let A = 482.01
    static let B = 2085.43
    static let alpha = 0.3478
    static let beta = 0.3658
    static var gamma: Double { alpha * beta / (alpha + beta) }

    static func loss(paramsB: Double, tokensT: Double) -> Double {
        let n = max(paramsB * 1e9, 1e6), d = max(tokensT * 1e12, 1e6)
        return E + A / pow(n, alpha) + B / pow(d, beta)
    }

    /// Compute-optimal parameter count (in billions) for C FLOPs.
    static func optimalParamsB(flops c: Double) -> Double {
        let g = pow(alpha * A / (beta * B), 1 / (alpha + beta))
        let a = beta / (alpha + beta)
        return g * pow(max(c, 1e12) / 6, a) / 1e9
    }

    static func optimalLoss(flops c: Double) -> Double {
        let n = optimalParamsB(flops: c)
        let d = max(c, 1e12) / 6 / (n * 1e9) / 1e12
        return loss(paramsB: n, tokensT: d)
    }

    /// Compute at which a compute-optimal model would reach `l`.
    static func computeForLoss(_ l: Double, reference c: Double) -> Double {
        let lref = optimalLoss(flops: c) - E
        let target = max(l - E, 1e-6)
        return c * pow(lref / target, 1 / gamma)
    }

    /// Effective unique data after repetition (Muennighoff et al. 2023: repeated tokens decay with R* ≈ 15).
    static func effectiveTokens(_ d: Double, unique u: Double) -> Double {
        guard u > 0, d > u else { return d }
        let rStar = 15.4
        let repeats = d / u - 1
        return u + u * rStar * (1 - exp(-repeats / rStar))
    }

    static func sparsityFactor(_ f: Double) -> Double {
        switch f {
        case ..<0.02: 1.3
        case ..<0.04: 1.25
        case ..<0.08: 1.15
        case ..<0.16: 1.0
        default: 0.7
        }
    }

    // MARK: Forecast

    static func forecast(_ d: ModelDesign, state s: GameState, dataSources: [String]) -> Forecast {
        let dataSources = dataSources.sorted()   // 3.7: fixed order (float sums), whatever order a run's snapshot was saved in
        let b = s.bonuses
        let y = s.year
        var f = Forecast()
        let sources = dataSources.compactMap { DataCatalog.byID[$0] }
        var drivers: [ForecastDriver] = []
        let plan = DataEconomy.plan(d, state: s, sources: dataSources)   // 3.6: data economy (all zero without new data)

        let pre = Physics.pretrainFLOPs(d)
        f.rawC = log10(max(pre, 1e12)) - 21
        drivers.append(ForecastDriver(name: "Training compute", value: f.rawC, kind: .base,
                                      detail: "\(Fmt.flops(pre)) FLOPs (6 × \(Fmt.params(d.activeParamsB)) active params × \(Fmt.tokens(d.tokensT)) tokens)"))

        // Data available & repetition
        var unique = Physics.availableTokensT(dataSources, y: y, bonuses: b)
        unique += plan.syntheticUniqueT   // one synthetic budget: the slider and synthetic datasets, approaching your real tokens
        if plan.active { unique += plan.extraUniqueT }
        f.tokensPerParam = d.tokensT * 1000 / max(d.activeParamsB, 0.001)
        f.optimalTokensPerParam = d.tokensT > 0 ? (pre / 6 / (optimalParamsB(flops: pre) * 1e9)) / (optimalParamsB(flops: pre) * 1e9) : 20

        var c: Double
        switch d.mode {
        case .scratch:
            // MoE experts store knowledge too: count them partially when judging the parameter/token split.
            let nEff = d.activeParamsB * (d.isMoE ? pow(1 / d.activeFraction, 0.3) : 1)
            let l1 = loss(paramsB: nEff, tokensT: d.tokensT)
            // Synthetic Mind Data level 3: repeated data loses no value.
            let dEff = s.signatureAt(.mirror, 3) ? d.tokensT : effectiveTokens(d.tokensT, unique: unique)
            let l2 = loss(paramsB: nEff, tokensT: dEff)
            f.allocation = min(0, log10(computeForLoss(l1, reference: pre) / pre))
            f.repetition = min(0, log10(computeForLoss(l2, reference: pre) / pre) - f.allocation)
            if f.allocation < -0.02 {
                let under = f.tokensPerParam < f.optimalTokensPerParam
                drivers.append(ForecastDriver(name: under ? "Under-trained" : "Over-trained", value: f.allocation, kind: .penalty,
                                              detail: "\(Int(f.tokensPerParam)) tokens/param; compute-optimal ≈ \(Int(f.optimalTokensPerParam))"))
                if f.allocation < -0.05 {
                    f.penalties.append(under ? "Under-trained: \(Int(f.tokensPerParam)) tokens per parameter wastes compute (×\(Fmt.trim(pow(10, f.allocation), 2)))"
                                             : "Over-trained for its size (×\(Fmt.trim(pow(10, f.allocation), 2))) — cheaper to serve, though")
                }
            }
            if f.repetition < -0.01 {
                drivers.append(ForecastDriver(name: "Repeated data", value: f.repetition, kind: .penalty,
                                              detail: "\(Fmt.trim(d.tokensT / max(unique, 1e-9), 1)) epochs over \(Fmt.tokens(unique)) unique tokens"))
                f.penalties.append("Data repeated \(Fmt.trim(d.tokensT / max(unique, 1e-9), 1))× (only \(Fmt.tokens(unique)) unique tokens)")
            }

            // Algorithmic gains that apply to every run
            var algo = b.algo
            if b.algo > 0.005 { drivers.append(ForecastDriver(name: "Research stack", value: b.algo, kind: .gain, detail: "Architecture & training techniques you've researched")) }
            if !b.has(.transformer) {
                algo -= 1.2
                drivers.append(ForecastDriver(name: "Pre-Transformer (LSTM)", value: -1.2, kind: .penalty))
                f.penalties.append("Pre-Transformer architecture (LSTM) ×0.06")
            }
            // Optimizer
            switch d.optimizer {
            case .muon where b.has(.muon):
                algo += b.muonAlgo
                drivers.append(ForecastDriver(name: "Muon optimizer", value: b.muonAlgo, kind: .gain))
                f.keyTech.append("Muon")
            case .shampoo where b.has(.shampoo):
                algo += b.shampooAlgo
                drivers.append(ForecastDriver(name: "Second-order optimizer", value: b.shampooAlgo, kind: .gain))
            default: break
            }
            // MoE
            if d.isMoE && b.has(.moe) {
                let scale = clamp(0.6 + 0.1 * f.rawC, 0.65, 1.2)
                let g = b.moeAlgo * sparsityFactor(d.activeFraction) * scale
                algo += g
                drivers.append(ForecastDriver(name: "Mixture-of-Experts (1/\(Int((1 / d.activeFraction).rounded())))", value: g, kind: .gain,
                                              detail: "Gains grow with sparsity and scale"))
                f.keyTech.append("MoE 1/\(Int((1 / d.activeFraction).rounded()))")
                // 3.4: the expert pool. Finer experts (more of them, more per token, same active share) learn more per FLOP
                // once fine-grained experts are researched; coarser ones learn less. Their traffic costs throughput
                // (Physics.moeEfficiency), so neither end is free.
                if d.experts > 0 {
                    let steps = log2(Double(d.experts) / Double(TrainingExperience.experts(for: d.activeFraction).experts))
                    let pool = clamp(steps * (steps > 0 ? (b.has(.fineMoE) ? 0.012 : 0.004) : 0.015), -0.045, 0.04)
                    if abs(pool) > 0.0005 {
                        algo += pool
                        drivers.append(ForecastDriver(name: "Expert pool (\(TrainingExperience.layout(d).label))", value: pool, kind: pool > 0 ? .gain : .penalty,
                                                      detail: pool > 0 ? "Finer experts specialise more; they cost more all-to-all traffic" : "Coarse experts: cheaper routing, less specialisation"))
                    }
                }
            }
            // Attention / mixer / heads
            if d.attention == .mla && b.has(.mla) {
                let g = 0.02 * b.result("mla")
                algo += g
                drivers.append(ForecastDriver(name: "Latent attention (MLA)", value: g, kind: .gain))
            }
            switch d.mixer {
            case .hybrid where b.has(.ssmHybrid):
                algo -= 0.04
                drivers.append(ForecastDriver(name: "Hybrid SSM layers", value: -0.04, kind: .penalty, detail: "Faster decoding, slightly less quality"))
                f.keyTech.append("Hybrid SSM")
            case .diffusion where b.has(.diffusionLM):
                let pen = -0.14 * (2 - b.result("x_diffusion_lm"))
                algo += pen
                drivers.append(ForecastDriver(name: "Diffusion decoding", value: pen, kind: .penalty, detail: "5–10× faster generation"))
                f.keyTech.append("Diffusion LM")
            case .alien:
                if let arch = Xeno.best(s) {
                    algo += arch.computeGain * (s.researched.contains("xeno_hybrid") ? 1.2 : 1)
                    drivers.append(ForecastDriver(name: "Alien architecture (\(arch.name))", value: arch.computeGain, kind: .gain,
                                                  detail: "Found by your agents. Humans follow about \(Int(arch.legibility * 100))% of it"))
                    f.keyTech.append("Alien: \(arch.name)")
                }
            default: break
            }
            if d.mtp && b.has(.mtp) {
                let g = 0.04 * b.result("mtp")
                algo += g
                drivers.append(ForecastDriver(name: "Multi-token prediction", value: g, kind: .gain))
            }
            if d.anneal && b.has(.curriculum) {
                var g = 0.03 * b.result("curriculum")
                if d.schedule == .wsd && b.has(.wsd) { g += 0.02 * b.result("wsd") }
                algo += g
                drivers.append(ForecastDriver(name: d.schedule == .wsd ? "WSD + annealing" : "Annealing stage", value: g, kind: .gain))
            }
            switch d.precision {
            case .bf16: break
            case .fp8:
                algo -= 0.01
            case .fp4:
                algo -= 0.04
                f.penalties.append("FP4 training noise (×0.91)")
            }
            // Team: careful hyperparameter work
            let team = s.employees.filter { $0.role == .researcher || $0.role == .mlEngineer }.reduce(0.0) { $0 + $1.weight }
            let teamGain = 0.03 * min(1, team / 8)
            algo += teamGain
            let culture = s.traits.algo
            if abs(culture) > 0.001 {
                algo += culture
                drivers.append(ForecastDriver(name: "Lab doctrine & culture", value: culture, kind: .gain, detail: "\(s.doctrine.title), \(s.background.title.lowercased()) founder and culture perks"))
            }
            f.algo = algo

            // Data quality
            var data = b.dataAlgo + sources.reduce(0) { $0 + $1.quality }
            let dataTeam = s.employees.filter { $0.role == .data }.reduce(0.0) { $0 + $1.weight }
            data += 0.08 * min(1, dataTeam / 3)
            switch d.dataMix {
            case .balanced: break
            case .code, .stem: data -= 0.01
            case .multilingual: data -= 0.03
            case .conversational: data -= 0.02
            }
            if d.syntheticShare > 0 && b.has(.syntheticData) {
                // Model collapse is judged on all generated data together (slider and datasets): it's in `plan.dData`.
                data += 0.08 * min(d.syntheticShare, 0.25) / 0.25 * b.result("synthetic_data") * plan.collapseFactor
            }
            if plan.active {
                data += plan.dData
                if plan.collapse < 0 { f.penalties.append("\(Int(plan.syntheticShare * 100))% of the corpus is generated: model collapse (×\(Fmt.trim(pow(10, plan.collapse), 2)))") }
            }
            f.data = data
            if abs(data) > 0.005 { drivers.append(ForecastDriver(name: "Data quality", value: data, kind: data >= 0 ? .gain : .penalty, detail: "Sources, filtering and your data team")) }
            if teamGain > 0.005 { drivers.append(ForecastDriver(name: "Hyperparameter tuning (team)", value: teamGain, kind: .gain)) }

            c = f.rawC + f.allocation + f.repetition + algo + data

            // Finetune of open weights / distillation
        case .finetune:
            let base = Physics.openModelC(d.baseModelRef, state: s) ?? (f.rawC + b.algo)
            let ftGain = 0.12 * min(1, d.tokensT / 0.05)
            let dataQ = (sources.reduce(0) { $0 + $1.quality } + plan.dData) * 0.3
            c = base - 0.06 + ftGain + dataQ
            drivers = [ForecastDriver(name: "Open-weights base model", value: base, kind: .base),
                       ForecastDriver(name: "Your fine-tune", value: ftGain - 0.06 + dataQ, kind: .gain)]
            f.penalties.append("Built on an open model: less differentiated")
            f.keyTech.append("Open-weights base")
        case .distill:
            let l1 = loss(paramsB: d.activeParamsB, tokensT: d.tokensT)
            let own = f.rawC + min(0, log10(computeForLoss(l1, reference: pre) / pre)) + b.algo + b.dataAlgo
            if let ref = d.baseModelRef, let teacher = s.models.first(where: { $0.id.uuidString == ref }) {
                let gap = max(0.15, 0.45 - b.distill)
                c = max(own, min(teacher.c - gap, own + 1.3))
                drivers = [ForecastDriver(name: "Teacher: \(teacher.name)", value: teacher.c, kind: .base),
                           ForecastDriver(name: "Distillation gap", value: -gap, kind: .penalty)]
            } else {
                c = own
            }
            f.keyTech.append("Distilled")
        }

        // Skills
        let dataReason = sources.reduce(0) { $0 + $1.reasoning }
        let dataCode = sources.reduce(0) { $0 + $1.code }
        let dataArena = sources.reduce(0) { $0 + $1.arena }
        var reasoning = b.skill(.reasoning) + dataReason
        var code = b.skill(.code) + dataCode
        switch d.dataMix {
        case .code: code += 0.08; reasoning += 0.02
        case .stem: reasoning += 0.08; code += 0.02
        default: break
        }
        // Mid-training mix shift for the second half (chosen in the Model Lab; needs the data curriculum).
        let shift = b.has(.curriculum) && d.mode != .finetune ? d.mixShift : .keep
        switch shift {
        case .code: code += 0.06
        case .stem: reasoning += 0.06
        case .keep, .multilingual: break
        }
        if shift != .keep {
            drivers.append(ForecastDriver(name: "Mid-training: \(shift.rawValue.lowercased())", value: shift == .multilingual ? 0.18 : 0.06, kind: .skill,
                                          detail: shift.detail))
        }
        if d.reasoning && b.has(.reasoning) {
            let level = d.effectiveRL
            let scale = log2(1 + level.share / 0.01) / log2(1 + 0.05 / 0.01)
            let rl = b.rl * scale
            reasoning += rl
            code += 0.05
            drivers.append(ForecastDriver(name: "Reasoning RL (\(level.label.lowercased()))", value: rl, kind: .skill,
                                          detail: "\(Int(level.share * 100))% of pre-training compute spent on RL"))
            f.keyTech.append("Reasoning RL")
        }
        if d.mixer == .hybrid { reasoning -= 0.05 }
        if d.mixer == .diffusion { reasoning -= 0.1 }
        if !d.instruct { reasoning -= 0.2 }
        var agent = b.skill(.agent) + (d.toolUse ? 0.05 : 0)
        if d.agentRL && b.has(.agents) && d.toolUse {
            agent += b.agentRL
            drivers.append(ForecastDriver(name: "Agentic RL environments", value: b.agentRL, kind: .skill))
            f.keyTech.append("Agentic RL")
        }
        if d.toolUse { code += 0.03 }
        // Instruction following: only from the post-training stages this design actually runs
        var chat = -0.6
        if d.instruct {
            chat += 0.85 * b.result("instruction_tuning") + b.skill(.chat)
            if d.rlhf { chat += 0.45 * b.result("rlhf") }
            if d.useDPO && b.has(.dpo) { chat += 0.02 }
        }
        chat += dataArena / 90
        if d.dataMix == .conversational { chat += 0.1 }
        if shift == .code { chat -= 0.03 }
        if plan.active {
            reasoning += plan.dReasoning
            code += plan.dCode
            agent += plan.dAgent
            chat += plan.dChat
            let skills = plan.dReasoning + plan.dCode + plan.dAgent + plan.dChat
            if abs(skills) > 0.005 {
                drivers.append(ForecastDriver(name: "Data plan", value: skills, kind: .skill, detail: "Your datasets' domain-relevant, quality-weighted tokens (Training Data page)"))
            }
        }
        if d.rlhf && !dataSources.contains("human_feedback") && plan.preferenceShortfall > 0.01 {
            // Needs fresh labels: the minimum delivered in the last twelve months; the penalty scales with what's missing.
            chat -= 0.2 * plan.preferenceShortfall
            f.penalties.append(plan.preferenceShortfall >= 0.99 ? "RLHF without fresh human-preference data is weak (Training Data page)"
                                                                 : "RLHF on too little fresh preference data: \(Int(plan.preferenceShortfall * 100))% weaker (Training Data page)")
        }
        var lang = 0.05 + b.skill(.lang)
        if d.dataMix == .multilingual { lang += 0.3 }
        if shift == .multilingual { lang += 0.18 }
        var longctx = b.skill(.longctx)
        if d.mixer == .hybrid { longctx += 0.1 }
        var vis = d.vision ? b.skill(.vis) : 0
        if plan.active { lang += plan.dLang; longctx += plan.dLongctx; vis += plan.dVis }
        var safety = 25 + b.safety + (d.safetyTraining ? 15 : 0) + (d.rlhf ? 5 : 0)
        let safetyTeam = s.employees.filter { $0.role == .safety }.reduce(0.0) { $0 + $1.weight }
        safety += 20 * min(1, safetyTeam / 4)
        safety += s.traits.safety
        if d.mixer == .alien {
            // You can't audit what you can't read.
            safety -= 25 * (1 - Xeno.bestLegibility(s)) * (s.researched.contains("xeno_hybrid") ? 0.5 : 1)
            reasoning += 0.05
            agent += 0.05
        }
        f.reasoning = reasoning
        f.code = code
        f.agent = agent
        f.chat = chat
        f.lang = lang
        f.longctx = longctx
        f.vis = vis
        f.safety = clamp(safety, 0, 100)
        f.arena = 75 * chat + (d.vision ? 8 : 0) + (d.audio ? 6 : 0)
        f.usesShadowData = dataSources.contains("shadow_books")

        // Uncertainty
        let (sigma, novel, covered, notes) = uncertainty(d, state: s, flops: pre)
        f.sigma = sigma
        f.novel = novel
        f.ladderCovered = covered
        f.notes = notes
        if covered {
            c += 0.02
            drivers.append(ForecastDriver(name: "Scaling ladder (tuned hyperparameters)", value: 0.02, kind: .gain))
        }
        // 3.8: alien tech past the frontier has diminishing returns.
        let uncharted = alienOvershoot(c, d, s)
        if uncharted < -0.005 {
            c += uncharted
            drivers.append(ForecastDriver(name: "Uncharted regime", value: uncharted, kind: .penalty,
                                          detail: "More than \(Fmt.trim(alienFreeLead, 1)) past the best model anyone has without alien tech (\(Fmt.trim(alienReference(s), 2))), nobody has the evals, data or hyperparameters for where you are: each further step is worth less"))
        }
        f.c = c
        f.bugRisk = bugRisk(d, state: s, covered: covered, novelCount: novel.count)
        f.drivers = drivers
        // Predicted final loss: algorithmic and data gains act like extra compute.
        let unique2 = max(unique, 1e-9)
        let lRaw = loss(paramsB: d.activeParamsB, tokensT: effectiveTokens(d.tokensT, unique: unique2))
        f.finalLoss = E + (lRaw - E) * pow(10, -gamma * (f.algo + f.data))
        return f
    }

    // MARK: Alien tech past the frontier (3.8)

    /// Lead over the frontier an alien-tech model keeps in full.
    static let alienFreeLead = 0.5
    /// Scale of the diminishing returns beyond it: an extra lead x is worth k·ln(1 + x/k).
    static let alienLeadScale = 0.5

    /// Whether a design runs on alien tech: the alien architecture, or alien chips.
    static func usesAlienTech(_ d: ModelDesign) -> Bool { d.mixer == .alien || AlienFab.isAlienChip(d.accelID) }

    /// The best capability reached without alien tech: the world's frontier, the best rival model, and your own best
    /// model that doesn't use alien tech.
    static func alienReference(_ s: GameState) -> Double {
        let rival = s.competitors.flatMap(\.models).map(\.c).max() ?? -9
        let own = s.models.filter { !usesAlienTech($0.design) }.map(\.c).max() ?? -9
        return max(Macro.frontier(s.year), rival, own)
    }

    /// The (negative) correction for an alien-tech model forecast at `c`: a lead past `alienReference` beyond
    /// `alienFreeLead` counts k·ln(1 + x/k) instead of x — +1 becomes +0.55, +2 becomes +0.8, +4 becomes +1.1.
    static func alienOvershoot(_ c: Double, _ d: ModelDesign, _ s: GameState) -> Double {
        guard usesAlienTech(d) else { return 0 }
        let x = c - alienReference(s) - alienFreeLead
        guard x > 0 else { return 0 }
        return alienLeadScale * log(1 + x / alienLeadScale) - x
    }

    // MARK: Uncertainty

    static func techKeys(_ d: ModelDesign) -> [(String, String, Double)] {
        var out: [(String, String, Double)] = []
        if d.isMoE { out.append(("moe", "Mixture-of-Experts", 0.08)) }
        switch d.optimizer {
        case .muon: out.append(("muon", "Muon optimizer", 0.07))
        case .shampoo: out.append(("shampoo", "Second-order optimizer", 0.04))
        case .adamw: break
        }
        if d.attention == .mla { out.append(("mla", "Latent attention", 0.03)) }
        switch d.mixer {
        case .hybrid: out.append(("hybrid", "Hybrid SSM", 0.08))
        case .diffusion: out.append(("diffusion", "Diffusion LM", 0.15))
        case .alien: out.append(("alien", "Alien architecture", 0.18))
        case .transformer: break
        }
        if d.mtp { out.append(("mtp", "Multi-token prediction", 0.02)) }
        switch d.precision {
        case .fp8: out.append(("fp8", "FP8 training", 0.03))
        case .fp4: out.append(("fp4", "FP4 training", 0.05))
        case .bf16: break
        }
        if let v = HardwareCatalog.get(d.accelID)?.vendor { out.append(("vendor:\(v.rawValue)", "\(v.rawValue) software stack", 0.025)) }
        return out
    }

    /// 1-sigma forecast error in log10 effective compute.
    static func uncertainty(_ d: ModelDesign, state s: GameState, flops: Double) -> (Double, [String], Bool, [String]) {
        let b = s.bonuses
        let logC = log10(max(flops, 1e12))
        var notes: [String] = []
        let base = 0.30 * b.forecastScale
        let previous = max(s.maxRunCompute, 1e17)
        let decades = logC - log10(previous)
        let ext = 0.035 * max(0, decades - 1)
        if decades > 1.2 { notes.append("Extrapolating \(Fmt.trim(pow(10, decades), 0))× beyond your largest run so far") }
        var novelSq = 0.0
        var novel: [String] = []
        for (key, name, sig) in techKeys(d) {
            let exp = s.techExperience[key] ?? 0
            let gap = clamp((logC - exp) / 2, 0, 1)
            if gap > 0.25 {
                novelSq += pow(sig * gap, 2)
                novel.append(name)
            }
        }
        let team = s.employees.filter { $0.role == .researcher || $0.role == .mlEngineer }.reduce(0.0) { $0 + $1.weight }
        let teamSig = 0.05 * max(0, 1 - team / 6)
        let covered = s.scalingFits.contains { $0.signature == d.recipeSignature && flops <= $0.maxCompute * pow(10, 3.7) }
        var sigma = sqrt(base * base + ext * ext + novelSq * (covered ? 0.16 : 1) + teamSig * teamSig)
        if covered {
            sigma *= 0.55
            notes.append("Scaling ladder validated this recipe — forecast tightened")
        } else if b.has(.proxyLadder) {
            notes.append("Run a scaling ladder to tighten this forecast")
        }
        if !novel.isEmpty { notes.append("New at this scale: \(novel.joined(separator: ", "))") }
        if d.mode != .scratch { sigma *= 0.5 }
        return (max(0.025, sigma), novel, covered, notes)
    }

    static func bugRisk(_ d: ModelDesign, state s: GameState, covered: Bool, novelCount: Int) -> Double {
        let b = s.bonuses
        let engineers = s.employees.filter { $0.role == .mlEngineer }.reduce(0.0) { $0 + $1.weight }
        var p = 0.18 + 0.04 * Double(novelCount)
        p *= b.bugKeep
        if covered { p *= 0.4 }
        p *= 1 - 0.35 * min(1, engineers / 4)
        if d.mode != .scratch { p *= 0.4 }
        return clamp(p, 0.01, 0.6)
    }

    // MARK: Profiles & verdicts

    static func profile(_ f: Forecast, design d: ModelDesign, key: String, c: Double? = nil, extra: (reasoning: Double, code: Double, chat: Double, safety: Double, lang: Double) = (0, 0, 0, 0, 0)) -> ModelProfile {
        ModelProfile(key: key, c: c ?? f.c, reasoning: f.reasoning + extra.reasoning, code: f.code + extra.code, agent: f.agent,
                     vision: d.vision, contextK: d.contextK, tuning: d.benchmarkTuning ? 1 : 0,
                     chat: f.chat + extra.chat, safety: clamp(f.safety + extra.safety, 0, 100), lang: f.lang + extra.lang,
                     longctx: f.longctx, vis: f.vis, audio: d.audio)
    }

    static func index(_ p: ModelProfile, set: [Benchmark]) -> Double {
        guard !set.isEmpty else { return 0 }
        return set.reduce(0) { $0 + $1.score(p, noise: false) } / Double(set.count)
    }

    /// Intelligence Index forecast with an 80% interval (±1.28σ).
    static func indexBand(_ f: Forecast, design d: ModelDesign, set: [Benchmark]) -> (mean: Double, low: Double, high: Double) {
        let mean = index(profile(f, design: d, key: "fc"), set: set)
        let low = index(profile(f, design: d, key: "fc-lo", c: f.c - 1.28 * f.sigma), set: set)
        let high = index(profile(f, design: d, key: "fc-hi", c: f.c + 1.28 * f.sigma), set: set)
        return (mean, low, high)
    }

    static func tier(index: Double, top: Double) -> String {
        switch index - top {
        case 3...: "Genius — new state of the art"
        case -2..<3: "Frontier-class"
        case -10 ..< -2: "Strong"
        case -20 ..< -10: "Solid"
        case -35 ..< -20: "Okay"
        default: "Weak"
        }
    }
}
