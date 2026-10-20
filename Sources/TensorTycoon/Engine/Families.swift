import Foundation

/// 3.5: model families. A flagship and the smaller tiers distilled from it, sold under one name; post-training passes
/// that upgrade a model you already have (v1.1, v1.2 …) and merges that fold them into a point release (v1.5).
/// Everything here is opt-in: a lab with no families plays exactly as before (no dice are rolled here either).
enum Families {
    // MARK: Lookup

    static func family(of id: UUID, _ s: GameState) -> ModelFamily? {
        guard !s.families.families.isEmpty else { return nil }
        return s.families.families.first { $0.has(id) }
    }

    static func tier(of id: UUID, _ s: GameState) -> FamilyTier? { family(of: id, s)?.tier(of: id) }

    static func model(_ id: UUID?, _ s: GameState) -> AIModel? {
        guard let id else { return nil }
        return s.models.first { $0.id == id }
    }

    /// Members of a family that still exist, flagship first and newest first within a tier.
    static func members(_ f: ModelFamily, _ s: GameState, includeRetired: Bool = false) -> [(member: FamilyMember, model: AIModel)] {
        f.members.compactMap { mem in model(mem.modelID, s).map { (mem, $0) } }
            .filter { includeRetired || !$0.model.retired }
            .sorted { ($0.member.tier.rank, $1.model.created) < ($1.member.tier.rank, $0.model.created) }
    }

    /// The family's current flagship: its best live flagship-tier model.
    static func flagship(_ f: ModelFamily, _ s: GameState) -> AIModel? {
        members(f, s).filter { $0.member.tier == .flagship }.map(\.model).max { $0.index < $1.index }
    }

    // MARK: Versions

    /// "v1.0", "v1.1", "v1.5", "v2.0".
    static func versionLabel(_ v: Int) -> String { "v\(1 + v / 10).\(v % 10)" }

    /// The model's name without a version suffix.
    static func baseName(_ name: String) -> String {
        guard let r = name.range(of: #" v\d+\.\d+$"#, options: .regularExpression) else { return name }
        return String(name[..<r.lowerBound])
    }

    static func setVersion(_ m: inout AIModel, _ v: Int) {
        m.version = v
        m.name = "\(baseName(m.name)) \(versionLabel(v))"
    }

    // MARK: Distillation

    /// How each domain carries over to a smaller student, as a multiple of the average gap. Knowledge lives in the
    /// parameters and is the first thing a small model loses; style and step-by-step reasoning copy well from the
    /// teacher's outputs; long agentic tasks and robotics fall apart first.
    static func retentionWeight(_ d: CapDomain) -> Double {
        switch d {
        case .knowledge: 1.4
        case .reasoning: 0.8
        case .math: 0.85
        case .science: 1.05
        case .coding: 0.9
        case .agents: 1.25
        case .memory: 1.1
        case .vision: 1.1
        case .voice: 1.0
        case .social: 0.7
        case .robotics: 1.2
        }
    }

    /// The size part of the gap: 0.75 log-compute per decade of parameters, as with open-weights size variants.
    static let sizeGapPerDecade = 0.75

    struct DistillPlan {
        var tier: FamilyTier
        var data: DistillData
        var studentParamsB: Double
        var studentActiveB: Double
        var tokensT: Double
        var flops: Double
        var perDay: Double
        var days: Double
        var dailyCost: Double
        var cost: Double
        /// Average capability lost (log10 effective compute; 0.1 = one capability point).
        var gap: Double
        var technique: String
        /// The formula, step by step, in plain words.
        var lines: [String]
        var teacherCostPerM: Double
        var studentCostPerM: Double
        var blocker: String?
    }

    /// Effective FLOPs per day `chips` of `accelID` give a distillation or post-training job.
    static func perDay(_ s: GameState, accelID: String, chips: Int, bonuses b: ResearchBonuses) -> Double {
        guard let a = HardwareCatalog.get(accelID), chips > 0 else { return 0 }
        return Double(chips) * a.trainTFLOPS(.bf16) * 1e12 * Physics.mfu(accel: a, chips: chips, state: s, bonuses: b) * 86_400 * 0.95
    }

    /// The hardware a job on model `m` would use by default, and how many chips: the model's own training chips if
    /// they're free, else the pool with the most idle compute.
    static func defaultCompute(_ s: GameState, for m: AIModel) -> (accelID: String, chips: Int)? {
        let pools = Economy.pools(s).filter { $0.free > 0 }
        if let p = pools.first(where: { $0.accel.id == m.design.accelID }) { return (p.accel.id, min(p.free, max(1, m.design.chips))) }
        guard let p = pools.max(by: { Double($0.free) * $0.accel.best < Double($1.free) * $1.accel.best }) else { return nil }
        return (p.accel.id, p.free)
    }

    static func distillPlan(_ s: GameState, teacher t: AIModel, tier: FamilyTier, data: DistillData, accelID: String, chips: Int) -> DistillPlan {
        let b = s.bonuses
        let f = tier.sizeFraction
        let paramsB = t.design.paramsB * f
        let activeB = t.design.activeParamsB * f
        let tokensT = min(max(t.design.tokensT, 0.001), activeB * data.tokensPerParam / 1000)
        // The student trains (6 FLOPs per active parameter per token); the teacher scores a quarter of the tokens.
        let flops = (6 * activeB + 0.5 * t.design.activeParamsB) * 1e9 * tokensT * 1e12
        let day = perDay(s, accelID: accelID, chips: chips, bonuses: b)
        let days = day > 0 ? flops / day + 1 : .infinity
        let dailyCost = HardwareCatalog.get(accelID).map { Economy.chipDailyCost($0, count: chips, state: s) } ?? 0

        let sizeGap = sizeGapPerDecade * log10(1 / f)
        let logit = b.has(.distillation)
        let tech = logit ? 0.8 : 1.0
        let quality = 1 - 0.4 * min(1, b.distill)
        let gap = sizeGap * tech * quality * data.gapFactor
        var lines: [String] = []
        lines.append("Size: the student has \(Fmt.pct(f, decimals: f < 0.05 ? 1 : 0)) of the teacher's parameters (\(Fmt.params(paramsB))): \(Fmt.trim(sizeGapPerDecade, 2)) × log10(1 / \(Fmt.trim(f, 3))) = \(Fmt.trim(sizeGap, 2)) gap.")
        lines.append(logit ? "Technique: logit distillation (Knowledge Distillation research) ×0.80 — the student learns the teacher's whole output distribution."
                           : "Technique: synthetic-data distillation ×1.00 — the student only sees the teacher's answers. Knowledge Distillation research makes it ×0.80.")
        if b.distill > 0.001 { lines.append("Distillation research (+\(Fmt.pct(b.distill, decimals: 0)) quality): ×\(Fmt.trim(quality, 2)).") }
        lines.append("Data: \(data.label.lowercased()), \(Int(data.tokensPerParam)) tokens per student parameter (\(Fmt.tokens(tokensT))): ×\(Fmt.trim(data.gapFactor, 2)).")
        lines.append("Gap = \(Fmt.trim(gap, 2)) log-compute: about \(Fmt.trim(gap * 10, 1)) capability points on average. Each domain loses that times its weight (knowledge ×1.4 … social ×0.7).")

        func serve(_ m: AIModel) -> Double {
            var d = m.design
            d.accelID = accelID
            return Economy.servingCostPerM(design: d, s) ?? 0
        }
        var studentDesign = t
        studentDesign.design.paramsB = paramsB
        var blocker: String? = nil
        if t.retired { blocker = "\(t.name) is retired." }
        else if t.preview { blocker = "Preview checkpoints can't teach: finish the run first." }
        else if activeB < 0.02 { blocker = "\(t.name) is too small to distil a \(tier.label) tier from." }
        else if chips <= 0 { blocker = "Pick free chips for the job (Compute Fleet frees them up)." }
        else if !days.isFinite { blocker = "Those chips can't run the job." }
        else if s.families.jobs.contains(where: { $0.kind == .distill && $0.modelID == t.id && $0.tier == tier.rawValue }) { blocker = "A \(tier.label) distillation of \(t.name) is already running." }
        return DistillPlan(tier: tier, data: data, studentParamsB: paramsB, studentActiveB: activeB, tokensT: tokensT, flops: flops, perDay: day,
                           days: days, dailyCost: dailyCost, cost: days.isFinite ? dailyCost * days : .infinity, gap: gap,
                           technique: logit ? "Logit distillation" : "Synthetic-data distillation", lines: lines,
                           teacherCostPerM: serve(t), studentCostPerM: serve(studentDesign), blocker: blocker)
    }

    /// The student a finished distillation produces.
    static func student(_ s: GameState, teacher t: AIModel, plan p: DistillPlan, name: String, accelID: String, chips: Int) -> AIModel {
        var d = t.design
        d.name = name
        d.mode = .distill
        d.baseModelRef = t.id.uuidString
        d.paramsB = p.studentParamsB
        d.tokensT = p.tokensT
        d.accelID = accelID
        d.chips = chips
        var m = AIModel(name: name, design: d, created: s.date, c: t.c - p.gap, reasoning: t.reasoning, reasoningBoost: t.reasoningBoost,
                        codeBoost: t.codeBoost, arenaBonus: t.arenaBonus - 7.5 * p.gap, scores: [:], index: 0)
        m.agentBoost = t.agentBoost
        m.chatSkill = t.chatSkill
        m.langSkill = t.langSkill
        m.longctxSkill = t.longctxSkill
        m.visSkill = t.visSkill
        m.usedShadowData = t.usedShadowData
        m.tuned = t.tuned
        m.safety = max(0, t.safety - 3)
        m.efficiencyBoost = t.efficiencyBoost
        m.servingPrecision = t.servingPrecision
        m.keyTech = t.keyTech.filter { $0 != "Distilled" } + ["Distilled"]
        m.cForecast = m.c
        m.forecastSigma = 0
        m.teacherID = t.id
        m.domainBonus = CapDomain.allCases.map { dom in
            (dom.index < t.domainBonus.count ? t.domainBonus[dom.index] : 0) - (retentionWeight(dom) - 1) * p.gap
        }
        m.apiPrice = max(0.001, (Macro.referencePrice(c: m.c, y: s.year) * s.market.apiPricePressure * 0.85 * 1000).rounded() / 1000)
        m.autoPrice = true
        return m
    }

    /// A tier name that isn't taken: "Atlas Spark", then "Atlas Spark 2".
    static func tierName(_ s: GameState, family: String, tier: FamilyTier) -> String {
        let base = "\(family) \(tier.label)"
        var name = base
        var n = 2
        while s.models.contains(where: { baseName($0.name) == name }) {
            name = "\(base) \(n)"
            n += 1
        }
        return name
    }

    /// A family name for a model: its design's family, else its name up to the first dash or digit run.
    static func suggestedName(_ m: AIModel) -> String {
        if !m.design.family.isEmpty { return m.design.family }
        let base = baseName(m.name)
        let cut = base.split(whereSeparator: { $0 == "-" || $0 == " " }).first.map(String.init) ?? base
        return cut.isEmpty ? base : cut
    }

    // MARK: Post-training

    struct PassPlan {
        var pass: PostTrainPass
        var flops: Double
        var perDay: Double
        var days: Double
        var dailyCost: Double
        var cost: Double
        var gains: [String]
        var costs: [String]
        var before: AIModel
        var after: AIModel
        var blocker: String?
    }

    static let contextSteps: [Int: Int] = [1: 2, 2: 8, 8: 32, 32: 128, 128: 1000]

    /// How strong the next pass of a kind is: each repeat of the same pass does half as much.
    static func diminishing(_ m: AIModel, _ pass: PostTrainPass) -> Double {
        pow(0.5, Double(m.passes.filter { $0 == pass.rawValue }.count))
    }

    static func passFlops(_ s: GameState, _ m: AIModel, _ pass: PostTrainPass) -> Double {
        let b = s.bonuses
        let base = max(Physics.pretrainFLOPs(m.design), 1e18)
        let discount = pass == .reasoningRL ? (1 - b.rlEfficiency) : (1 - b.postTrainCost)
        let first = pass == .reasoningRL && !m.reasoning ? 1.25 : 1
        return base * pass.computeShare * max(0.2, discount) * first
    }

    static func passBlocker(_ s: GameState, _ m: AIModel, _ pass: PostTrainPass) -> String? {
        let b = s.bonuses
        if m.retired { return "\(m.name) is retired." }
        if m.preview { return "Preview checkpoints can't be post-trained: finish the run first." }
        if s.families.jobs.contains(where: { $0.modelID == m.id && $0.kind != .distill }) { return "\(m.name) is already being post-trained." }
        switch pass {
        case .reasoningRL: if !b.has(.reasoning) { return "Research reasoning RL first." }
        case .agentic: if !b.has(.toolUse) { return "Research tool use first." }
        case .longContext:
            guard let next = contextSteps[m.design.contextK] else { return "Already at the longest context window." }
            if next >= 1000 && !b.has(.context1m) { return "Research 1M Context first." }
            if next >= 128 && !b.has(.context128k) { return "Research 128K Context first." }
            if next >= 32 && !b.has(.context32k) { return "Research RoPE & Context Extension first." }
        case .safety, .specCode, .specScience, .specMedicine:
            if !m.design.instruct { return "Base models need instruction tuning before targeted post-training." }
        }
        return nil
    }

    /// Applies a pass to a model, returning what it gained and what it gave up, in plain words.
    @discardableResult
    static func apply(_ pass: PostTrainPass, to m: inout AIModel, bonuses b: ResearchBonuses) -> (gains: [String], costs: [String]) {
        let k = diminishing(m, pass)
        var gains: [String] = [], costs: [String] = []
        if m.domainBonus.count < CapDomain.count { m.domainBonus += [Double](repeating: 0, count: CapDomain.count - m.domainBonus.count) }
        if m.tradeoffDomains.count < CapDomain.count { m.tradeoffDomains += [Double](repeating: 0, count: CapDomain.count - m.tradeoffDomains.count) }
        func domain(_ d: CapDomain, _ v: Double) {
            m.domainBonus[d.index] += v
            if v < 0 { m.tradeoffDomains[d.index] += v }
            if v > 0 { gains.append("+\(Fmt.trim(v * 10, 1)) \(d.short.lowercased())") } else { costs.append("−\(Fmt.trim(-v * 10, 1)) \(d.short.lowercased())") }
        }
        func chat(_ v: Double, _ why: String) {
            m.chatSkill += v
            m.tradeoffChat += v
            costs.append("Chat \(Fmt.trim(v, 2)) (\(why))")
        }
        func safety(_ v: Double, _ why: String) {
            let before = m.safety
            m.safety = clamp(m.safety + v, 0, 100)
            let d = m.safety - before
            if abs(d) < 0.5 { return }
            if d >= 0 { gains.append("Safety +\(Int(d.rounded())) (\(why))") } else { costs.append("Safety \(Int(d.rounded())) (\(why))") }
        }
        switch pass {
        case .reasoningRL:
            let was = m.reasoning
            let g = (was ? 0.25 : 0.6) * max(0.1, b.rl) * k
            m.reasoningBoost += g
            m.codeBoost += 0.03 * k
            gains.append("Reasoning skill +\(Fmt.trim(g, 2))")
            if !was {
                m.reasoning = true
                m.design.reasoning = true
                if m.design.rlLevel == .off { m.design.rlLevel = .standard }
                gains.append("Becomes a reasoning model")
                costs.append("Thinks before answering: chat traffic on it uses about 2.2× the tokens")
            }
            chat(-0.03 * k, "long, over-thought answers")
            safety(-2 * k, "RL can learn to game its graders")
            domain(.social, -0.03 * k)
        case .agentic:
            let g: Double
            if !m.design.toolUse {
                m.design.toolUse = true
                g = 0.05 + (b.has(.agents) ? 0.6 * b.agentRL : 0.02)
                gains.append("Learns tool use: can power your agent product")
            } else {
                g = (0.03 + 0.3 * b.agentRL) * k
            }
            m.agentBoost += g
            m.codeBoost += 0.02 * k
            gains.append("Agentic skill +\(Fmt.trim(g, 2))")
            domain(.agents, 0.05 * k)
            safety(-4 * k, "more autonomy, wider misuse surface")
        case .safety:
            safety(12 * k, "refusals, red-teaming, constitution")
            chat(-0.04 * k, "over-refusal on borderline requests")
            domain(.science, -0.04 * k)
            domain(.social, -0.04 * k)
            domain(.knowledge, -0.02 * k)
        case .longContext:
            let next = contextSteps[m.design.contextK] ?? m.design.contextK
            m.design.contextK = next
            m.longctxSkill += 0.05
            gains.append("Context window \(next >= 1000 ? "1M" : "\(next)K")")
            domain(.memory, 0.05)
            domain(.knowledge, -0.01)
            costs.append("Bigger KV cache: more memory per replica, higher serving cost")
        case .specCode:
            m.codeBoost += 0.08 * k
            gains.append("Code skill +\(Fmt.trim(0.08 * k, 2))")
            domain(.coding, 0.15 * k)
            for d in [CapDomain.knowledge, .social, .voice, .vision] { domain(d, -0.05 * k) }
            chat(-0.03 * k, "narrower")
        case .specScience:
            m.reasoningBoost += 0.02 * k
            domain(.science, 0.2 * k)
            domain(.math, 0.08 * k)
            domain(.social, -0.05 * k)
            domain(.coding, -0.03 * k)
            chat(-0.02 * k, "narrower")
        case .specMedicine:
            domain(.knowledge, 0.15 * k)
            domain(.science, 0.1 * k)
            safety(3 * k, "careful, hedged answers")
            domain(.coding, -0.05 * k)
            domain(.agents, -0.04 * k)
            chat(-0.02 * k, "narrower")
        }
        if k < 0.99 { costs.append("Repeat pass: \(Fmt.pct(k, decimals: 0)) of the first one's effect") }
        m.passes.append(pass.rawValue)
        m.passesSinceMerge += 1
        return (gains, costs)
    }

    static func passPlan(_ s: GameState, model m: AIModel, pass: PostTrainPass, accelID: String, chips: Int) -> PassPlan {
        let b = s.bonuses
        let flops = passFlops(s, m, pass)
        let day = perDay(s, accelID: accelID, chips: chips, bonuses: b)
        let days = day > 0 ? flops / day + 1 : .infinity
        let dailyCost = HardwareCatalog.get(accelID).map { Economy.chipDailyCost($0, count: chips, state: s) } ?? 0
        var after = m
        let (gains, costs) = apply(pass, to: &after, bonuses: b)
        var blocker = passBlocker(s, m, pass)
        if blocker == nil && chips <= 0 { blocker = "Pick free chips for the job (Compute Fleet frees them up)." }
        if blocker == nil && !days.isFinite { blocker = "Those chips can't run the job." }
        return PassPlan(pass: pass, flops: flops, perDay: day, days: days, dailyCost: dailyCost, cost: days.isFinite ? dailyCost * days : .infinity,
                        gains: gains, costs: costs, before: m, after: after, blocker: blocker)
    }

    // MARK: Merges

    static func canMerge(_ m: AIModel) -> Bool { m.passesSinceMerge >= 2 }

    static func mergeFlops(_ m: AIModel) -> Double { max(Physics.pretrainFLOPs(m.design), 1e18) * 0.002 }

    /// Weight-merges the pass checkpoints into one point release: wins back half of what the passes gave up.
    static func merge(_ m: inout AIModel) {
        for i in m.tradeoffDomains.indices where i < m.domainBonus.count {
            m.domainBonus[i] -= 0.5 * m.tradeoffDomains[i]
            m.tradeoffDomains[i] *= 0.5
        }
        m.chatSkill -= 0.5 * m.tradeoffChat
        m.tradeoffChat *= 0.5
        m.passesSinceMerge = 0
        let v = m.version
        setVersion(&m, v % 10 < 5 ? v / 10 * 10 + 5 : (v / 10 + 1) * 10)
    }

    // MARK: Daily

    static func daily(_ s: inout GameState, _ b: ResearchBonuses) {
        guard !s.families.isEmpty else { return }
        var done: [ModelJob] = []
        for i in s.families.jobs.indices where !s.families.jobs[i].paused {
            let j = s.families.jobs[i]
            guard let a = HardwareCatalog.get(j.accelID) else { continue }
            let day = perDay(s, accelID: j.accelID, chips: j.chips, bonuses: b)
            s.families.jobs[i].done += day
            s.families.jobs[i].cost += Economy.chipDailyCost(a, count: j.chips, state: s)
            s.lifetimeFLOPs += day
            if s.families.jobs[i].done >= j.flops && GameCalendar.daysBetween(j.started, s.date) >= 2 { done.append(s.families.jobs[i]) }
        }
        if !done.isEmpty {
            let ids = Set(done.map(\.id))
            s.families.jobs.removeAll { ids.contains($0.id) }
            for j in done {
                switch j.kind {
                case .distill: finishDistill(&s, j)
                case .postTrain: finishPass(&s, j)
                case .merge: finishMerge(&s, j)
                }
            }
        }
        tidy(&s)
    }

    /// Drop members that no longer exist, move the free tier off retired models, and let family brands drift
    /// toward what the lineup earns: released tiers and how close the flagship is to the frontier.
    static func tidy(_ s: inout GameState) {
        let frontier = Macro.frontier(s.year)
        for fi in s.families.families.indices {
            let ids = Set(s.models.map(\.id))
            s.families.families[fi].members.removeAll { !ids.contains($0.modelID) }
            if let free = s.families.families[fi].freeTierID, model(free, s).map({ $0.retired || !$0.released }) ?? true {
                s.families.families[fi].freeTierID = nil
            }
            let f = s.families.families[fi]
            let live = members(f, s).filter { $0.model.released }
            let tiers = Set(live.map(\.member.tier)).count
            let lead = flagship(f, s).map { clamp(($0.c - frontier + 0.5) / 0.5, 0, 1) } ?? 0
            let target = live.isEmpty ? 10 : 20 + 12 * Double(tiers) + 20 * lead
            s.families.families[fi].brand += (min(100, target) - f.brand) * 0.02
        }
    }

    /// Pause jobs on `accelID` when the pool runs short (after training runs).
    static func shrink(_ s: inout GameState, accelID: String, excess: inout Int) {
        for i in s.families.jobs.indices where s.families.jobs[i].accelID == accelID && !s.families.jobs[i].paused && excess > 0 {
            s.families.jobs[i].paused = true
            excess -= s.families.jobs[i].chips
            Alerts.raise(&s, .runPaused, key: "job-\(s.families.jobs[i].id.uuidString)", title: "\(s.families.jobs[i].name) paused",
                         body: "Not enough \(HardwareCatalog.get(accelID)?.name ?? "chips") for it. Free some up, then resume it on Model Families.",
                         screen: .families, cooldown: 7)
        }
    }

    /// Jobs paused for lack of chips start again when enough are free.
    static func resumeJobs(_ s: inout GameState) {
        for i in s.families.jobs.indices where s.families.jobs[i].paused {
            let j = s.families.jobs[i]
            guard Economy.freeChips(s, j.accelID) >= j.chips else { continue }
            s.families.jobs[i].paused = false
            Sim.news(&s, "\(j.name.isEmpty ? "Model job" : j.name) resumed", "Its \(Fmt.int(j.chips)) \(HardwareCatalog.get(j.accelID)?.name ?? "chips") are free again.", .company, good: true)
        }
    }

    // MARK: Finishing jobs

    static func finishDistill(_ s: inout GameState, _ j: ModelJob) {
        guard let t = model(j.modelID, s) else { return }
        let plan = distillPlan(s, teacher: t, tier: j.tierValue, data: j.dataValue, accelID: j.accelID, chips: j.chips)
        let fi = ensureFamily(&s, for: t, id: j.familyID)
        var m = student(s, teacher: t, plan: plan, name: j.name, accelID: j.accelID, chips: j.chips)
        let set = Leaderboard.indexSet(s)
        m.index = BenchmarkCatalog.index(Leaderboard.profile(m), set: set)
        let top = Leaderboard.entries(s, set: set, includeUnreleased: false).filter { !$0.isPlayer }.map(\.index).max() ?? 0
        m.tier = ForecastEngine.tier(index: m.index, top: top)
        s.models.append(m)
        s.families.families[fi].members.append(FamilyMember(modelID: m.id, tier: j.tierValue, joined: s.date))
        s.families.distilled += 1
        let famName = s.families.families[fi].name
        let cheaper = plan.studentCostPerM > 0 ? plan.teacherCostPerM / plan.studentCostPerM : 0
        var body = "Distilled from \(t.name): Intelligence Index \(Fmt.score(m.index)) against the teacher's \(Fmt.score(t.index)), "
            + "about \(Fmt.trim(cheaper, 0))× cheaper to serve per token."
        if j.autoLaunch, s.release(m.id, api: true, openWeights: false, plan: LaunchPlan(), by: "family") == nil {
            // Servers for about a third of the teacher's traffic, on the job's chips (they're free again now).
            var chips = 0
            if let a = HardwareCatalog.get(j.accelID) {
                let b = s.bonuses
                let k = Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b)
                let per = Physics.capacity(m, deployment: Deployment(accelID: a.id, chips: k), bonuses: b)
                let want = max(1, Int((0.3 * t.servedTokensDay / max(per, 1)).rounded(.up)))
                chips = min(Economy.freeChips(s, a.id) / k, want) * k
                if chips > 0 { _ = s.deploy(m.id, accelID: a.id, chips: chips) }
            }
            body += chips > 0 ? " Released with an API on \(Fmt.int(chips)) chips." : " Released with an API; give it chips on Models & Serving."
        }
        Sim.news(&s, "\(m.name) joins the \(famName) family", body, .company, image: "server_room", good: true)
        Alerts.raise(&s, .milestone, key: "family-\(m.id.uuidString)", title: "\(m.name) is ready", body: body, screen: .families, celebrate: true, cooldown: 0)
        offerFreeTier(&s, fi, student: m.id)
    }

    /// After a cheap tier ships under the model that powers your chat app: put the free users on it? (Inbox, default yes.)
    static func offerFreeTier(_ s: inout GameState, _ fi: Int, student: UUID) {
        let f = s.families.families[fi]
        guard let chat = s.chatModelID, f.has(chat), chat != student, f.freeTierID == nil,
              let m = model(student, s), m.released, m.design.instruct, s.chatMoment != nil, s.freeTier else { return }
        let chatName = model(chat, s)?.name ?? "your chat model"
        Events.addDecision(&s, kind: decisionKind, title: "Serve free chat users on \(m.name)?",
                           body: "\(chatName) answers every free user today. \(m.name) costs far less per token; free users would notice a slightly weaker app, paying users keep \(chatName).",
                           image: "sf_skyline",
                           options: [DecisionOption(label: "Route the free tier to \(m.name)", detail: "Cheaper serving; the app's quality reads a little lower."),
                                     DecisionOption(label: "Keep everyone on \(chatName)", detail: "Best experience, full serving bill.")],
                           ref: "\(f.id.uuidString)|\(student.uuidString)")
    }

    static let decisionKind = "family_route"

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        guard option == 0 else { return }
        let parts = d.ref.split(separator: "|").map(String.init)
        guard parts.count == 2, let fid = UUID(uuidString: parts[0]), let mid = UUID(uuidString: parts[1]) else { return }
        _ = s.setFreeTier(fid, mid)
    }

    static func finishPass(_ s: inout GameState, _ j: ModelJob) {
        guard let i = s.models.firstIndex(where: { $0.id == j.modelID }), let pass = j.passValue else { return }
        let b = s.bonuses
        let (gains, costs) = apply(pass, to: &s.models[i], bonuses: b)
        setVersion(&s.models[i], s.models[i].version + 1)
        s.families.passes += 1
        rescore(&s, i)
        let m = s.models[i]
        let body = "\(pass.label): \(gains.joined(separator: ", "))." + (costs.isEmpty ? "" : " Trade-offs: \(costs.joined(separator: ", ")).")
            + " Intelligence Index now \(Fmt.score(m.index))."
        Sim.news(&s, "\(m.name) ships", body, .company, image: "supercomputer", good: true)
        Alerts.raise(&s, .milestone, key: "pass-\(j.id.uuidString)", title: "\(m.name): \(pass.label.lowercased()) done", body: body, screen: .families, celebrate: true, cooldown: 0)
    }

    static func finishMerge(_ s: inout GameState, _ j: ModelJob) {
        guard let i = s.models.firstIndex(where: { $0.id == j.modelID }) else { return }
        merge(&s.models[i])
        s.families.merges += 1
        rescore(&s, i)
        if let fi = s.families.families.firstIndex(where: { $0.has(j.modelID) }) { s.families.families[fi].brand = min(100, s.families.families[fi].brand + 3) }
        let m = s.models[i]
        Sim.news(&s, "\(m.name): a merged point release", "The post-training checkpoints were weight-merged into one model: half of what the passes gave up is back. Intelligence Index \(Fmt.score(m.index)).",
                 .company, image: "supercomputer", good: true)
    }

    /// Recompute a changed model's index, tier and domain scores, then the lab's best scores and milestones.
    static func rescore(_ s: inout GameState, _ i: Int) {
        let set = Leaderboard.indexSet(s)
        s.models[i].index = BenchmarkCatalog.index(Leaderboard.profile(s.models[i]), set: set)
        let top = Leaderboard.entries(s, set: set, includeUnreleased: false).filter { !$0.isPlayer }.map(\.index).max() ?? 0
        s.models[i].tier = ForecastEngine.tier(index: s.models[i].index, top: top)
        s.domainScores[s.models[i].id.uuidString] = Capabilities.playerScores(s.models[i], research: Capabilities.researchDomains(s))
        Capabilities.refreshLabs(&s)
        Milestones.check(&s, newModels: [], announce: true)
    }

    /// The family a model belongs to, creating one around it if it has none. Returns its index.
    @discardableResult
    static func ensureFamily(_ s: inout GameState, for m: AIModel, id: UUID? = nil) -> Int {
        if let id, let fi = s.families.families.firstIndex(where: { $0.id == id }) {
            if !s.families.families[fi].has(m.id) { s.families.families[fi].members.append(FamilyMember(modelID: m.id, tier: .flagship, joined: s.date)) }
            return fi
        }
        if let fi = s.families.families.firstIndex(where: { $0.has(m.id) }) { return fi }
        var name = suggestedName(m)
        var n = 2
        while s.families.families.contains(where: { $0.name == name }) {
            name = "\(suggestedName(m)) \(n)"
            n += 1
        }
        s.families.families.append(ModelFamily(name: name, created: s.date, members: [FamilyMember(modelID: m.id, tier: .flagship, joined: s.date)]))
        return s.families.families.count - 1
    }

    /// A finished training run whose design names an existing family joins it as its new flagship generation.
    static func adopt(_ s: inout GameState, _ m: AIModel) {
        guard !s.families.families.isEmpty, !m.design.family.isEmpty,
              let fi = s.families.families.firstIndex(where: { $0.name.caseInsensitiveCompare(m.design.family) == .orderedSame }),
              !s.families.families[fi].has(m.id) else { return }
        s.families.families[fi].members.append(FamilyMember(modelID: m.id, tier: .flagship, joined: s.date))
        s.families.families[fi].generation += 1
        Sim.news(&s, "\(m.name) is the new \(s.families.families[fi].name) flagship",
                 "Generation \(s.families.families[fi].generation) of the family. Distil fresh tiers from it on Model Families when it's released.", .company)
    }

    // MARK: Serving and the market

    /// API demand multiplier for a model in a family of two or more: the family's name carries (up to +15%).
    static func brandMult(_ s: GameState, _ id: UUID) -> Double {
        guard !s.families.families.isEmpty, let f = family(of: id, s), f.members.count >= 2 else { return 1 }
        return 1 + 0.15 * clamp(f.brand, 0, 100) / 100
    }

    /// The model that serves the chat app's free users, if the chat model's family routes them to a cheaper tier.
    static func freeRoute(_ s: GameState, chatID: UUID) -> AIModel? {
        guard !s.families.families.isEmpty else { return nil }
        for f in s.families.families where f.has(chatID) {
            guard let fid = f.freeTierID, fid != chatID,
                  let m = s.models.first(where: { $0.id == fid && $0.released && !$0.retired && $0.design.instruct }) else { continue }
            return m
        }
        return nil
    }

    /// Share of chat users on the free tier (yesterday's paying share).
    static func freeShare(_ s: GameState) -> Double {
        guard s.freeTier else { return 0 }
        return s.consumerUsers > 1 ? clamp(1 - s.paidUsers / s.consumerUsers, 0, 1) : 0.95
    }

    /// The chat app's quality as the market sees it: the chat model, pulled a little toward the free tier's model
    /// when free users are served by a cheaper tier.
    static func chatQuality(_ s: GameState, _ m: AIModel) -> Double {
        guard let free = freeRoute(s, chatID: m.id) else { return m.c }
        return m.c - 0.2 * freeShare(s) * max(0, m.c - free.c)
    }

    /// A family tier whose servers came online today: the market sees it at once (capacity is only measured at the end
    /// of the day, and without this a new tier and the capacity delegate chase each other's lag forever).
    static func servesToday(_ s: GameState, _ m: AIModel) -> Bool {
        !m.deployments.isEmpty && !s.families.families.isEmpty && tier(of: m.id, s) != nil
    }

    /// Models a family keeps on the books: delegates don't retire tiers of a lineup.
    static func protected(_ s: GameState) -> [UUID] {
        guard !s.families.families.isEmpty else { return [] }
        return s.families.families.filter { $0.members.count >= 2 }.flatMap { $0.members.map(\.modelID) }
    }

    /// The traffic segments a model serves today.
    static func segments(_ s: GameState, _ m: AIModel) -> [String] {
        var out: [String] = []
        if s.chatModelID == m.id {
            out.append(freeRoute(s, chatID: m.id) == nil ? "Chat app (all users)" : "Chat app (paying users)")
        }
        if s.families.families.contains(where: { $0.freeTierID == m.id }), let chat = s.chatModelID, freeRoute(s, chatID: chat)?.id == m.id {
            out.append("Chat free tier")
        }
        if m.api && m.released { out.append("API") }
        if s.agentModelID == m.id { out.append("Agent seats") }
        let deals = s.deals.filter { $0.active && $0.modelID == m.id }.count
        if deals > 0 { out.append("Enterprise ×\(deals)") }
        return out
    }

    struct Cannibal {
        /// API tokens a day this tier sells.
        var tokens: Double
        /// Of those, tokens its siblings would have sold without it (and their revenue).
        var fromSiblings: Double
        var revenueFromSiblings: Double
        /// Its own API revenue a day.
        var revenue: Double
        var newTokens: Double { max(0, tokens - fromSiblings) }
    }

    /// For each API-selling member: how much of its traffic it took from its own siblings (the market without it).
    static func cannibalisation(_ s: GameState, _ f: ModelFamily) -> [UUID: Cannibal] {
        let live = members(f, s).map(\.model).filter { $0.released && $0.api && $0.capacityTokensDay > 0 }
        guard live.count >= 2 else { return [:] }
        let snap = Market.snapshot(s)
        func tokens(_ snap: MarketSnapshot, _ id: UUID) -> Double {
            snap.api.filter { $0.modelID == id }.reduce(0) { $0 + $1.share } * snap.apiTokenPool
        }
        var out: [UUID: Cannibal] = [:]
        for m in live {
            guard let i = s.models.firstIndex(where: { $0.id == m.id }) else { continue }
            var t = s
            t.models[i].api = false
            let without = Market.snapshot(t)
            var lost = 0.0, lostRev = 0.0
            for o in live where o.id != m.id {
                let d = max(0, tokens(without, o.id) - tokens(snap, o.id))
                lost += d
                lostRev += d / 1e6 * o.apiPrice
            }
            let own = tokens(snap, m.id)
            out[m.id] = Cannibal(tokens: own, fromSiblings: min(own, lost), revenueFromSiblings: lostRev, revenue: own / 1e6 * m.apiPrice)
        }
        return out
    }

    /// Serving cost per 1M tokens of a model (its deployments, or one replica of its hardware).
    static func servingCost(_ s: GameState, _ m: AIModel) -> Double { Economy.servingCostPerM(m, s) }

    /// Tokens a day the family serves, and each member's share of them.
    static func trafficShares(_ f: ModelFamily, _ s: GameState) -> [UUID: Double] {
        let live = members(f, s).map(\.model)
        let total = live.reduce(0) { $0 + $1.servedTokensDay }
        guard total > 0 else { return [:] }
        var out: [UUID: Double] = [:]
        for m in live { out[m.id] = m.servedTokensDay / total }
        return out
    }
}

// MARK: - Player actions

extension GameState {
    /// Start a family around one of your models (it becomes the flagship).
    @discardableResult
    mutating func startFamily(_ modelID: UUID, name: String = "") -> String? {
        guard let m = models.first(where: { $0.id == modelID }) else { return "Not found." }
        if Families.family(of: modelID, self) != nil { return "\(m.name) is already in a family." }
        if m.retired { return "\(m.name) is retired." }
        let fi = Families.ensureFamily(&self, for: m)
        let clean = name.trimmingCharacters(in: .whitespaces)
        if !clean.isEmpty && !families.families.contains(where: { $0.name == clean }) { families.families[fi].name = clean }
        return nil
    }

    mutating func renameFamily(_ id: UUID, _ name: String) -> String? {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return "Give it a name." }
        guard let fi = families.families.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if families.families.contains(where: { $0.name == clean && $0.id != id }) { return "Another family already has that name." }
        families.families[fi].name = clean
        return nil
    }

    /// Distil a smaller tier from one of your models.
    @discardableResult
    mutating func startDistill(_ teacherID: UUID, tier: FamilyTier, data: DistillData, accelID: String, chips: Int, autoLaunch: Bool = true) -> String? {
        guard let t = models.first(where: { $0.id == teacherID }) else { return "Not found." }
        guard tier != .flagship else { return "Pick a smaller tier." }
        if chips > Economy.freeChips(self, accelID) { return "Only \(Fmt.int(Economy.freeChips(self, accelID))) chips of that type are free." }
        let plan = Families.distillPlan(self, teacher: t, tier: tier, data: data, accelID: accelID, chips: chips)
        if let e = plan.blocker { return e }
        let fi = Families.ensureFamily(&self, for: t)
        let name = Families.tierName(self, family: families.families[fi].name, tier: tier)
        families.jobs.append(ModelJob(kind: .distill, modelID: t.id, familyID: families.families[fi].id, name: name, tier: tier.rawValue, data: data.rawValue,
                                      accelID: accelID, chips: chips, flops: plan.flops, started: date, autoLaunch: autoLaunch))
        return nil
    }

    /// Run a post-training pass on one of your models.
    @discardableResult
    mutating func startPostTrain(_ modelID: UUID, pass: PostTrainPass, accelID: String, chips: Int) -> String? {
        guard let m = models.first(where: { $0.id == modelID }) else { return "Not found." }
        if chips > Economy.freeChips(self, accelID) { return "Only \(Fmt.int(Economy.freeChips(self, accelID))) chips of that type are free." }
        let plan = Families.passPlan(self, model: m, pass: pass, accelID: accelID, chips: chips)
        if let e = plan.blocker { return e }
        families.jobs.append(ModelJob(kind: .postTrain, modelID: m.id, familyID: Families.family(of: m.id, self)?.id,
                                      name: "\(Families.baseName(m.name)) \(Families.versionLabel(m.version + 1)): \(pass.label.lowercased())",
                                      pass: pass.rawValue, accelID: accelID, chips: chips, flops: plan.flops, started: date))
        return nil
    }

    /// Merge a model's post-training checkpoints into a point release (v1.5).
    @discardableResult
    mutating func startMerge(_ modelID: UUID, accelID: String, chips: Int) -> String? {
        guard let m = models.first(where: { $0.id == modelID }) else { return "Not found." }
        guard Families.canMerge(m) else { return "Merging needs at least two post-training passes since the last release." }
        if jobs(for: modelID) { return "\(m.name) is already being post-trained." }
        guard chips > 0, chips <= Economy.freeChips(self, accelID) else { return "Pick free chips for the merge." }
        families.jobs.append(ModelJob(kind: .merge, modelID: m.id, familyID: Families.family(of: m.id, self)?.id,
                                      name: "\(Families.baseName(m.name)) merge", accelID: accelID, chips: chips, flops: Families.mergeFlops(m), started: date))
        return nil
    }

    private func jobs(for modelID: UUID) -> Bool { families.jobs.contains { $0.modelID == modelID && $0.kind != .distill } }

    mutating func cancelModelJob(_ id: UUID) { families.jobs.removeAll { $0.id == id } }

    mutating func resumeModelJob(_ id: UUID) -> String? {
        guard let i = families.jobs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let j = families.jobs[i]
        if Economy.freeChips(self, j.accelID) < j.chips { return "Needs \(Fmt.int(j.chips)) free chips; \(Fmt.int(Economy.freeChips(self, j.accelID))) are free." }
        families.jobs[i].paused = false
        return nil
    }

    /// Move the family's enterprise contracts onto the cheapest-to-serve released tier that still meets each client's bar.
    mutating func rehomeContracts(_ familyID: UUID) -> String? {
        guard let f = families.families.first(where: { $0.id == familyID }) else { return "Not found." }
        let tiers = Families.members(f, self).map(\.model).filter { $0.released && !$0.retired }
        var moved = 0
        for i in deals.indices where deals[i].active {
            guard let cur = deals[i].modelID, f.has(cur) else { continue }
            let fits = tiers.filter { $0.index + 0.01 >= deals[i].minIndex }
            guard let best = fits.min(by: { Families.servingCost(self, $0) < Families.servingCost(self, $1) }), best.id != cur else { continue }
            deals[i].modelID = best.id
            moved += 1
        }
        return moved == 0 ? "Every contract is already on the cheapest tier that meets its bar." : nil
    }

    /// Serve the chat app's free users on a family member (nil: back on the chat model).
    @discardableResult
    mutating func setFreeTier(_ familyID: UUID, _ modelID: UUID?) -> String? {
        guard let fi = families.families.firstIndex(where: { $0.id == familyID }) else { return "Not found." }
        guard let modelID else { families.families[fi].freeTierID = nil; return nil }
        guard families.families[fi].has(modelID), let m = models.first(where: { $0.id == modelID }) else { return "Not in this family." }
        if !m.released || m.retired { return "Release \(m.name) first." }
        if !m.design.instruct { return "\(m.name) isn't instruction-tuned." }
        families.families[fi].freeTierID = modelID
        return nil
    }
}
