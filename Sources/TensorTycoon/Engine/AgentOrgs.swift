import Foundation

/// 3.6: AI organisations. Swarms become teams inside an organisation with an objective, specialist and supervisor
/// teams (each running its own model), a compute budget (the teams' inference chips), a money budget, verification,
/// human oversight and a project history.
///
/// Productivity, per organisation (all teams that aren't paused):
///
///     per agent     q_i  = Swarms.quality(model_i) × fit_i × experience_i
///     fit_i              = √(skill fit × domain fit)
///     skill fit          = Swarms.fit: reasoning/code/agentic skill vs a typical model of its generation (0.5–2)
///     domain fit         = clamp(exp(0.08 × Δ_i), 0.5, 2)
///                          Δ_i = model_i's domain-mix score − a typical model of its generation and compute (public
///                          research) − model_i's median gap on the core text domains, in capability points (10 = 10×)
///     effective     E    = Σ specialists: active_i × (1 − monitors) × autonomyOutput × sandbagging
///     working       E_w  = E × (1 − v)                                 v = verification share
///     error rate    ε    = E-weighted clamp(0.35 × exp(−0.8 × (agenticX − 8)), 0.01, 0.6)
///     supervision   σ    = min(1, supervisor capacity / (5% of the specialists)); a smarter supervisor covers more
///     caught        κ    = 1 − exp(−6v) × (1 − 0.5σ)
///     hand-offs     k    = 1 + 0.35 log10(max(1, E/100))              work built on work: errors compound k times
///     quality       Q    = (1 − 1.2 ε(1 − κ) − 0.2 εκ)^k / (1 − 1.2 ε)  (vs a plain swarm, one hand-off; ≤ 2)
///                          so a big organisation of error-prone models loses most of its output to compounding errors
///                          unless it verifies: with ε high, a moderate v (10–30%) maximises W; with ε low, v ≈ 0 does
///     exponent      α    = min(0.98, Swarms.coordination + 0.02σ)
///     overhead      Ω    = min(0.5, 0.05 log2(teams) + 0.035 max(0, log10(E/100)) × (1 − 0.7σ))
///     tools         F    = 1 − weight × (1 − funded)                  funded = budget / (cost per worker-day × W)
///     output        W    = q̄ × E_w^α × Q × (1 − Ω) × F                 researcher-equivalents
///     activity level     = clamp(log10(1 + W × share) / 5, 0, 1)      organisation-only kinds (100K for full)
///
/// So a thousand times the agents gives ~250–500× the output, overhead included, and a model that is better at the
/// mission's domains (coding for software, science for discovery, robotics and vision for robotics) does more per agent.
/// Organisations on the classic missions add W to that mission's pool (with any stand-alone swarms); the newer kinds
/// turn W into a level per activity (see above), which
/// the hooks below read. Stand-alone swarms (every swarm from older saves) work exactly as before.
enum AgentOrgs {
    static let maxOrgs = 10
    static let maxTeams = 8
    /// Supervisors needed for full supervision, as a share of the specialists.
    static let supervisionTarget = 0.05
    static let historyCap = 60
    static let maxTechniques = 10

    // MARK: Per agent

    /// Share of an agent's work products that are wrong (bugs, bad analyses, broken experiments).
    static func errorRate(_ m: AIModel) -> Double { clamp(0.35 * exp(-0.8 * (Swarms.agenticX(m) - 8)), 0.01, 0.6) }

    static func scores(_ m: AIModel, _ s: GameState) -> DomainScores {
        s.domainScores[m.id.uuidString] ?? Capabilities.playerScores(m, research: Capabilities.researchDomains(s))
    }

    /// A typical model of the same generation and compute, with what the field has published by then.
    static func referenceScores(_ m: AIModel) -> DomainScores {
        let y = m.created.decimalYear
        let p = Leaderboard.frontierProfile(y, key: "org-fit", c: m.c, reasoningModel: m.reasoning)
        return Capabilities.scores(p, extra: CapDomain.allCases.map { Capabilities.field($0, at: y) }, video: m.design.video)
    }

    /// The text domains that set a model's overall level (modalities, memory and robotics vary with design choices).
    static let coreDomains: [CapDomain] = [.knowledge, .reasoning, .math, .science, .coding, .social]

    /// The model's particular strengths for this mission, in capability points: its gap to a typical model of its
    /// generation on the mission's domains, minus its median gap on the core text domains. Overall strength already
    /// sets what an agent is worth (`Swarms.quality`, from agentic skill); this is what makes a coder better at
    /// software, a scientist better at discovery and a model with robotics research and vision better with robots.
    static func domainEdge(_ m: AIModel, _ kind: SwarmMission, _ s: GameState) -> Double {
        let v = scores(m, s), r = referenceScores(m)
        let core = coreDomains.map { v[$0] - r[$0] }.sorted()
        let median = (core[2] + core[3]) / 2
        return v.mix(kind.domainMix) - r.mix(kind.domainMix) - median
    }

    static func domainFit(edge: Double) -> Double { clamp(exp(0.08 * edge), 0.5, 2) }

    static func domainFit(_ m: AIModel, _ kind: SwarmMission, _ s: GameState) -> Double { domainFit(edge: domainEdge(m, kind, s)) }

    /// How well the model suits the work: half its skill fit (reasoning, code and agentic skill, as for a swarm) and
    /// half its domain fit, geometrically (0.5–2).
    static func fit(skill: Double, domain: Double) -> Double { (skill * domain).squareRoot() }

    static func fit(_ m: AIModel, _ kind: SwarmMission, _ s: GameState) -> Double { fit(skill: Swarms.fit(m, kind), domain: domainFit(m, kind, s)) }

    /// Researcher-equivalents per agent of this model in an organisation of this kind.
    static func perAgent(_ m: AIModel, _ kind: SwarmMission, _ s: GameState) -> Double { Swarms.quality(m, s) * fit(m, kind, s) }

    static func canFound(_ kind: SwarmMission, _ s: GameState) -> Bool {
        kind.minQuality <= 0 || s.models.contains { !$0.retired && Swarms.quality($0, s) >= kind.minQuality }
    }

    // MARK: Evaluation

    struct TeamEval: Identifiable {
        var id: UUID
        var name: String
        var model: String
        var role: TeamRole
        var active: Double
        var effective: Double
        var perAgent: Double
        var fit: Double
        var edge: Double
        var errorRate: Double
        var share: Double = 0
    }

    struct Eval {
        var teams: [TeamEval] = []
        var specialists = 0.0
        var supervisors = 0.0
        var effective = 0.0
        var working = 0.0
        var perAgent = 0.0
        var fit = 1.0
        var edge = 0.0
        var errorRate = 0.0
        var verification = 0.0
        var caught = 0.0
        var slip = 0.0
        var quality = 1.0
        /// Hand-offs work passes through (errors compound across them).
        var depth = 1.0
        var supervision = 0.0
        var alpha = 0.0
        var overhead = 0.0
        var tools = 1.0
        var needDaily = 0.0
        var spendDaily = 0.0
        var workforce = 0.0
        var naive = 0.0
        var bestQuality = 0.0
        var gate = 0.0
        var shares: [Double] = []
        var chips = 0
        var computeDaily = 0.0

        /// Share of finished work that is right.
        var accuracy: Double { 1 - slip }
    }

    static func members(_ o: AgentOrg, _ s: GameState) -> [AgentSwarm] { s.swarms.filter { $0.orgID == o.id } }

    static func evaluate(_ o: AgentOrg, _ s: GameState, _ b: ResearchBonuses) -> Eval { evaluate(o, members: members(o, s), s, b) }

    static func evaluate(_ o: AgentOrg, members: [AgentSwarm], _ s: GameState, _ b: ResearchBonuses) -> Eval {
        var e = Eval()
        e.verification = clamp(o.verification, 0, 0.5)
        var qSum = 0.0, fitSum = 0.0, edgeSum = 0.0, errSum = 0.0, gateSum = 0.0
        var sups: [(active: Double, q: Double)] = []
        var specialistRaw = 0.0, specialistTeams = 0
        for sw in members {
            if let a = HardwareCatalog.get(sw.accelID) { e.computeDaily += sw.paused ? 0 : Economy.chipDailyCost(a, count: sw.chips, state: s) }
            if !sw.paused { e.chips += sw.chips }
            guard !sw.paused, let m = s.models.first(where: { $0.id == sw.modelID }), !m.retired else { continue }
            let active = min(Double(sw.agents), Swarms.capacityAgents(m, accelID: sw.accelID, chips: sw.chips, s, b))
            let general = Swarms.quality(m, s)
            if sw.role == .supervisors {
                e.supervisors += active
                sups.append((active * (1 - sw.oversight), general))
                e.teams.append(TeamEval(id: sw.id, name: sw.name, model: m.name, role: .supervisors, active: active, effective: 0,
                                        perAgent: general, fit: 1, edge: 0, errorRate: errorRate(m)))
                continue
            }
            let sandbag = sw.alignment < 50 ? 0.5 + sw.alignment / 100 : 1
            let eff = active * (1 - sw.oversight) * Swarms.autonomyOutput[sw.autonomy] * sandbag
            let edge = domainEdge(m, o.kind, s)
            let fit = AgentOrgs.fit(skill: Swarms.fit(m, o.kind), domain: domainFit(edge: edge))
            let q = general * fit * sw.experience
            e.specialists += active
            specialistRaw += active * (1 - sw.oversight)
            specialistTeams += 1
            e.effective += eff
            qSum += eff * q
            fitSum += eff * fit
            edgeSum += eff * edge
            errSum += eff * errorRate(m)
            gateSum += eff * q * Swarms.xenoGate(m, s)
            e.bestQuality = max(e.bestQuality, general)
            e.teams.append(TeamEval(id: sw.id, name: sw.name, model: m.name, role: .specialists, active: active, effective: eff,
                                    perAgent: q, fit: fit, edge: edge, errorRate: errorRate(m), share: eff * q))
        }
        let acts = o.kind.activities
        e.shares = activityShares(acts, best: e.bestQuality, focus: o.focus)
        guard e.effective > 0 else { return e }
        e.perAgent = qSum / e.effective
        e.fit = fitSum / e.effective
        e.edge = edgeSum / e.effective
        e.errorRate = errSum / e.effective
        e.gate = qSum > 0 ? gateSum / qSum : 0
        for i in e.teams.indices where e.teams[i].role == .specialists { e.teams[i].share = qSum > 0 ? e.teams[i].share / qSum : 0 }
        // Supervision: supervisors smarter than the specialists cover more of them (√ of the quality ratio, 0.5–2×).
        let capacity = sups.reduce(0) { $0 + $1.active * clamp($1.q / max(1e-6, e.perAgent / max(0.01, e.fit)), 0.25, 4).squareRoot() }
        e.supervision = specialistRaw > 0 ? min(1, capacity / (supervisionTarget * specialistRaw)) : 0
        e.alpha = min(0.98, Swarms.coordination(b, s) + 0.02 * e.supervision)
        e.overhead = min(0.5, 0.05 * log2(Double(max(1, specialistTeams)))
                         + 0.035 * max(0, log10(max(1, e.effective) / 100)) * (1 - 0.7 * e.supervision))
        e.working = e.effective * (1 - e.verification)
        e.depth = depth(effective: e.effective)
        e.caught = caught(e.verification, supervision: e.supervision)
        e.slip = e.errorRate * (1 - e.caught)
        e.quality = quality(errorRate: e.errorRate, caught: e.caught, depth: e.depth)
        e.naive = e.perAgent * e.effective
        guard e.working >= 1 else { return e }
        let pre = e.perAgent * pow(e.working, e.alpha) * e.quality * (1 - e.overhead)
        let tool = o.kind.toolCost
        e.needDaily = tool.perDay * pre
        let budget = max(0, o.budgetMonthly) / 30.4
        let funded = e.needDaily > 0 ? min(1, budget / e.needDaily) : 1
        e.spendDaily = min(budget, e.needDaily)
        e.tools = 1 - tool.weight * (1 - funded)
        e.workforce = pre * e.tools
        return e
    }

    // MARK: Verification

    /// 3.8: hand-offs a piece of work passes through before it ships — one for a small team, more as the organisation
    /// grows (work built on other agents' work), so errors compound.
    static func depth(effective: Double) -> Double { 1 + 0.35 * max(0, log10(max(1, effective) / 100)) }

    /// Share of errors caught before they ship.
    static func caught(_ v: Double, supervision: Double) -> Double { 1 - exp(-6 * v) * (1 - 0.5 * supervision) }

    /// Useful output per unit of working time against a plain swarm (unverified, unsupervised, one hand-off).
    /// Each hand-off keeps 1 − 1.2 × (errors that slip) − 0.2 × (errors caught, which cost rework).
    static func quality(errorRate eps: Double, caught k: Double, depth: Double) -> Double {
        let step = max(0.05, 1 - 1.2 * eps * (1 - k) - 0.2 * eps * k)
        return min(2, pow(step, depth) / max(0.1, 1 - 1.2 * eps))
    }

    /// Output with verification share v, relative to none (everything else equal): (1 − v)^α × Q(v) / Q(0).
    static func verificationGain(_ v: Double, _ e: Eval) -> Double {
        let q = quality(errorRate: e.errorRate, caught: caught(v, supervision: e.supervision), depth: e.depth)
        let q0 = quality(errorRate: e.errorRate, caught: caught(0, supervision: e.supervision), depth: e.depth)
        return pow(1 - v, max(0.5, e.alpha)) * q / max(1e-9, q0)
    }

    /// The verification share (in the slider's 5% steps) that gets the most useful output from this organisation.
    static func bestVerification(_ e: Eval) -> Double {
        stride(from: 0.0, through: 0.5, by: 0.05).max { verificationGain($0, e) < verificationGain($1, e) } ?? 0
    }

    /// Effort per activity: everything to the only one unlocked; with several, 60% to the focus and the rest shared.
    static func activityShares(_ acts: [OrgActivity], best: Double, focus: Int) -> [Double] {
        let open = acts.indices.filter { best >= acts[$0].minQuality }
        guard !open.isEmpty else { return acts.indices.map { $0 == 0 ? 1 : 0 } }
        if open.count == 1 { return acts.indices.map { $0 == open[0] ? 1 : 0 } }
        let f = open.contains(focus) ? focus : open[0]
        return acts.indices.map { i in i == f ? 0.6 : (open.contains(i) ? 0.4 / Double(open.count - 1) : 0) }
    }

    // MARK: Daily

    /// What organisations add to the classic mission pools today.
    struct Contribution {
        var workforce: [SwarmMission: Double] = [:]
        /// Alien search output weighted by how many of the agents are smart enough to find anything.
        var xenoGated = 0.0
    }

    static func key(_ kind: SwarmMission, _ activity: Int) -> String { "\(kind.rawValue).\(activity)" }

    /// Level (0–1) of an organisation-only activity from the researcher-equivalents on it: log-scaled like the
    /// classic missions, but full strength takes 100,000 (a whole company's worth of work, not one department's).
    static func level(_ w: Double) -> Double { clamp(log10(1 + max(0, w)) / 5, 0, 1) }

    static func daily(_ s: inout GameState, _ b: ResearchBonuses) -> Contribution {
        var c = Contribution()
        guard !s.orgs.isEmpty else {
            if !s.orgLevels.isEmpty { s.orgLevels = [:] }
            return c
        }
        let newMonth = GameCalendar.components(s.date).day == 1
        var wByKey: [String: Double] = [:]
        for oi in s.orgs.indices {
            if newMonth { monthlyReport(&s, oi) }
            let o = s.orgs[oi]
            let e = evaluate(o, s, b)
            let w = e.workforce
            if e.spendDaily > 0 {
                s.cash -= e.spendDaily
                s.month.costAgentOrgs += e.spendDaily
            }
            s.orgs[oi].workforce = w
            s.orgs[oi].quality = e.effective > 0 ? e.accuracy : 0
            s.orgs[oi].agents = e.specialists + e.supervisors
            s.orgs[oi].supervision = e.supervision
            s.orgs[oi].spendToday = e.spendDaily
            s.orgs[oi].totalOutput += w
            s.orgs[oi].totalSpend += e.spendDaily
            s.orgs[oi].monthOutput += w
            s.orgs[oi].monthSpend += e.spendDaily
            s.orgs[oi].monthDays += 1
            // Teams: specialists get their share of the output (training-ops coverage reads it), supervisors none.
            for t in e.teams {
                guard let si = s.swarms.firstIndex(where: { $0.id == t.id }) else { continue }
                let tw = t.role == .specialists ? w * t.share : 0
                s.swarms[si].workforce = tw
                s.swarms[si].output = tw
                s.swarms[si].totalOutput += tw
            }
            guard w > 0 else { continue }
            for (i, share) in e.shares.enumerated() where share > 0 { wByKey[key(o.kind, i), default: 0] += w * share }
            switch o.kind {
            case .research, .xeno, .trainingOps, .silicon, .alignment, .workforce, .security, .intel:
                c.workforce[o.kind, default: 0] += w * (e.shares.first ?? 1)
                if o.kind == .xeno { c.xenoGated += w * e.gate }
            default:
                break
            }
            if o.kind == .research, e.shares.count > 1, e.shares[1] > 0 { techniqueStep(&s, oi, w * e.shares[1]) }
        }
        var levels: [String: Double] = [:]
        for (k, w) in wByKey { levels[k] = level(w) }
        s.orgLevels = levels
        // Discovery institutes running autonomous experiments pull every running moonshot's finish date in.
        let pull = level(s, .discovery, 1) * 0.5
        if pull > 0 {
            for i in s.moonshots.indices where s.moonshots[i].status == .running {
                if let end = s.moonshots[i].ends, end > s.date { s.moonshots[i].ends = end.addingTimeInterval(-pull * 86_400) }
            }
        }
        return c
    }

    static func techniqueCost(_ n: Int) -> Double { 100 * pow(1.6, Double(n)) }

    static func techniqueStep(_ s: inout GameState, _ oi: Int, _ w: Double) {
        guard s.orgTechniques < maxTechniques else { return }
        s.orgs[oi].techProgress += 0.02 * pow(w, 0.6)
        let cost = techniqueCost(s.orgTechniques)
        guard s.orgs[oi].techProgress >= cost else { return }
        s.orgs[oi].techProgress -= cost
        s.orgTechniques += 1
        let names = ["a fused attention-and-MLP kernel", "a better learning-rate schedule", "a cheaper mixture-of-experts router",
                     "a lossless activation compression", "an optimizer that needs a third less memory", "a smarter data-loader overlap",
                     "a communication-free pipeline schedule", "an FP6 training recipe", "a self-tuning parallelism planner",
                     "a sparse-gradient all-reduce"]
        let what = names[(s.orgTechniques - 1) % names.count]
        report(&s, s.orgs[oi].id, .milestone, "Technique #\(s.orgTechniques): \(what)",
               "Training runs reach +\(Fmt.trim(mfuBonus(s) * 100, 1)) points of MFU from your department's techniques.")
        Sim.news(&s, "\(s.orgs[oi].name) publishes a new technique internally",
                 "Agents found \(what). Every training run gets a little faster (+0.3 points of MFU).", .research, image: "supercomputer", good: true)
    }

    static func monthlyReport(_ s: inout GameState, _ oi: Int) {
        let o = s.orgs[oi]
        guard o.monthDays > 0 else { return }
        let avg = o.monthOutput / o.monthDays
        var body = "Averaged \(Fmt.count(avg)) researcher-equivalents across \(Fmt.count(o.agents)) agents; \(Fmt.pct(o.quality, decimals: 0)) of work right first time."
        if o.monthSpend > 0 { body += " Spent \(Fmt.money(o.monthSpend)) on tools and equipment." }
        body += " \(impact(o.kind, s))."
        report(&s, o.id, .report, "Progress report", body)
        s.orgs[oi].monthOutput = 0
        s.orgs[oi].monthSpend = 0
        s.orgs[oi].monthDays = 0
    }

    static func report(_ s: inout GameState, _ orgID: UUID, _ kind: OrgReport.Kind, _ title: String, _ body: String = "") {
        guard let i = s.orgs.firstIndex(where: { $0.id == orgID }) else { return }
        s.orgs[i].history.insert(OrgReport(date: s.date, kind: kind, title: title, body: body), at: 0)
        if s.orgs[i].history.count > historyCap { s.orgs[i].history.removeLast(s.orgs[i].history.count - historyCap) }
        if kind == .incident { s.orgs[i].incidents += 1 }
    }

    /// An organisation's teams drift less: supervisors and verification catch misbehaviour early.
    static func driftFactor(_ sw: AgentSwarm, _ s: GameState) -> Double {
        guard let oid = sw.orgID, let o = s.orgs.first(where: { $0.id == oid }) else { return 1 }
        return (1 - 0.3 * o.supervision) * (1 - 0.5 * clamp(o.verification, 0, 0.5))
    }

    // MARK: Effects (read by other systems; all exactly neutral without organisations)

    static func level(_ s: GameState, _ kind: SwarmMission, _ activity: Int) -> Double { s.orgLevels[key(kind, activity)] ?? 0 }

    /// Architecture research: published techniques raise training MFU.
    static func mfuBonus(_ s: GameState) -> Double { 0.003 * Double(min(maxTechniques, s.orgTechniques)) }

    /// Software engineering: product lines' serving cost multiplier.
    static func productServingFactor(_ s: GameState) -> Double { 1 - 0.25 * level(s, .software, 0) }

    /// Software engineering (all product lines) and robotics engineering (the Robotics Brain): capability points
    /// added to your product-line quality.
    static func productQualityBonus(_ s: GameState, _ productID: String) -> Double {
        2 * level(s, .software, 1) + (productID == "robotics" ? 2 * level(s, .robotics, 0) + 3 * level(s, .robotics, 1) : 0)
    }

    /// Infrastructure management: multiplier on the chance of a site outage.
    static func outageFactor(_ s: GameState) -> Double { 1 - 0.6 * level(s, .infrastructure, 0) }

    /// Infrastructure management: multiplier on the power bill.
    static func powerFactor(_ s: GameState) -> Double { 1 - 0.12 * level(s, .infrastructure, 1) }

    /// Financial analysis: percentage points added to the yield on idle cash.
    static func yieldBonus(_ s: GameState) -> Double { 0.4 * level(s, .finance, 0) }

    /// Experiment coordination: speed multiplier for experiments and proxy runs.
    static func experimentSpeed(_ s: GameState) -> Double { 1 + 0.5 * level(s, .experiments, 0) }

    /// Scientific discovery: added to the moonshot science factor.
    static func moonshotOdds(_ s: GameState) -> Double { 0.1 * level(s, .discovery, 0) }

    /// Scientific discovery: a general multiplier on scientific progress (1–2). The hook for science systems.
    static func scienceBoost(_ s: GameState) -> Double { 1 + 0.5 * (level(s, .discovery, 0) + level(s, .discovery, 1)) }

    /// What the organisations of this kind are doing to the game right now, in a phrase.
    static func impact(_ kind: SwarmMission, _ s: GameState) -> String {
        func p(_ v: Double) -> String { Fmt.pct(v, decimals: 0) }
        switch kind {
        case .research:
            return "\(Fmt.count(s.swarmRPToday)) RP/day from agents · \(s.orgTechniques) technique\(s.orgTechniques == 1 ? "" : "s") (+\(Fmt.trim(mfuBonus(s) * 100, 1)) MFU points)"
        case .xeno: return "\(Fmt.trim(s.xenoInsightToday, 1)) insight/day"
        case .trainingOps: return "Ops level \(p(s.swarmOps))"
        case .silicon: return "Chip design level \(p(s.swarmSilicon))"
        case .alignment: return "Safety level \(p(s.swarmSafety))"
        case .workforce: return "\(Fmt.money(s.laborToday * 365))/yr of labour"
        case .security: return "Security level \(p(s.swarmSecurity))"
        case .intel: return "Intel level \(p(s.swarmIntel))"
        case .software:
            return "Product lines \(p(1 - productServingFactor(s))) cheaper to serve · quality +\(Fmt.trim(2 * level(s, .software, 1), 1))"
        case .discovery:
            return "Moonshot odds +\(p(moonshotOdds(s))) · moonshots \(Fmt.trim(1 + 0.5 * level(s, .discovery, 1), 2))× faster"
        case .infrastructure:
            return "Outages \(p(1 - outageFactor(s))) rarer · power bill −\(p(1 - powerFactor(s)))"
        case .robotics:
            return "Robotics Brain quality +\(Fmt.trim(productQualityBonus(s, "robotics") - 2 * level(s, .software, 1), 1))"
        case .finance: return "Interest on cash +\(Fmt.trim(yieldBonus(s), 2)) points"
        case .experiments: return "Experiments \(Fmt.trim(experimentSpeed(s), 2))× faster"
        }
    }

    /// The productivity breakdown, line by line, for the "why this output" panel.
    static func explanation(_ o: AgentOrg, _ e: Eval, _ s: GameState) -> [(label: String, value: String, detail: String)] {
        guard e.effective > 0 else { return [] }
        let domains = o.kind.domainMix.map { $0.0.short.lowercased() }.joined(separator: ", ")
        var rows: [(String, String, String)] = []
        rows.append(("Agents at work", Fmt.count(e.effective),
                     "\(Fmt.count(e.specialists)) specialists, after monitors\(e.supervisors > 0 ? " · \(Fmt.count(e.supervisors)) supervisors" : "")"))
        rows.append(("Per agent", "\(Fmt.trim(e.perAgent, e.perAgent < 0.1 ? 3 : 2)) researcher-eq",
                     "Agentic skill × fit \(Fmt.trim(e.fit, 2))× (skills and domains; \(domains): \(e.edge >= 0 ? "+" : "")\(Fmt.trim(e.edge, 1)) points vs its level)"))
        rows.append(("Scaling", "N^\(Fmt.trim(e.alpha, 2))",
                     "\(Fmt.count(e.working)) agents do the work of \(Fmt.count(pow(max(1, e.working), e.alpha))) independent ones"))
        let best = bestVerification(e)
        let advice: String
        if abs(best - e.verification) < 0.025 {
            advice = "about the best share for these models"
        } else {
            let gain = verificationGain(best, e) / max(1e-9, verificationGain(e.verification, e)) - 1
            advice = "\(Fmt.pct(best, decimals: 0)) would give \(gain >= 0.005 ? "+\(Fmt.pct(gain, decimals: 0))" : "about the same") output"
        }
        rows.append(("Verification", "−\(Fmt.pct(e.verification, decimals: 0)) time",
                     "Catches \(Fmt.pct(e.caught, decimals: 0)) of a \(Fmt.pct(e.errorRate, decimals: 0)) error rate; \(Fmt.pct(e.slip, decimals: 1)) slips through · \(advice)"))
        rows.append(("Quality", "×\(Fmt.trim(e.quality, 2))",
                     "Against an unverified, unsupervised swarm of the same models. Work passes through \(Fmt.trim(e.depth, 1)) hand-offs here, so errors that slip compound"))
        rows.append(("Supervision", Fmt.pct(e.supervision, decimals: 0),
                     e.supervision >= 1 ? "Fully staffed: +0.02 to the exponent, less overhead, fewer errors and less drift"
                                        : "Supervisors for \(Fmt.pct(supervisionTarget, decimals: 0)) of the specialists give full supervision"))
        rows.append(("Coordination overhead", "−\(Fmt.pct(e.overhead, decimals: 0))", "Grows with teams and with log(size); supervisors cut most of it"))
        rows.append(("Tools & equipment", "×\(Fmt.trim(e.tools, 2))",
                     e.tools >= 0.999 ? "Fully funded (\(Fmt.money(e.spendDaily * 30.4))/mo)" : "Budget covers \(Fmt.pct(e.needDaily > 0 ? e.spendDaily / e.needDaily : 1, decimals: 0)) of the \(Fmt.money(e.needDaily * 30.4))/mo it could use"))
        rows.append(("Output", "\(Fmt.count(e.workforce)) researcher-eq",
                     e.naive > 0 ? "\(Fmt.pct(e.workforce / e.naive, decimals: 1)) of agents × per-agent value" : ""))
        return rows
    }

    // MARK: Forecast

    /// The organisation's output with one more team.
    static func forecast(_ o: AgentOrg, adding probe: AgentSwarm, _ s: GameState, _ b: ResearchBonuses) -> (before: Eval, after: Eval) {
        let m = members(o, s)
        return (evaluate(o, members: m, s, b), evaluate(o, members: m + [probe], s, b))
    }
}

// MARK: - Player actions

extension GameState {
    /// Found an organisation with its first team of specialists.
    mutating func foundOrg(kind: SwarmMission, name: String, objective: String, modelID: UUID, accelID: String, chips: Int, agents: Int,
                           autonomy: Int, oversight: Double, verification: Double, budgetMonthly: Double) -> String? {
        if orgs.count >= AgentOrgs.maxOrgs { return "You can run at most \(AgentOrgs.maxOrgs) organisations. Grow an existing one." }
        guard let m = models.first(where: { $0.id == modelID }), !m.retired else { return "Pick one of your models." }
        if Swarms.quality(m, self) < kind.minQuality {
            return "A \(kind.orgTitle.lowercased()) needs agents of at least \(Swarms.tier(kind.minQuality)) level. \(m.name) is \(Swarms.tier(Swarms.quality(m, self)).lowercased())."
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let goal = objective.trimmingCharacters(in: .whitespaces)
        let org = AgentOrg(name: trimmed.isEmpty ? kind.orgTitle : trimmed, kind: kind, objective: goal.isEmpty ? kind.defaultObjective : goal,
                           founded: date, autonomy: autonomy, oversight: clamp(oversight, 0, 0.5), verification: clamp(verification, 0, 0.5),
                           budgetMonthly: max(0, budgetMonthly))
        orgs.append(org)
        if let err = addOrgTeam(org.id, role: .specialists, name: "", modelID: modelID, accelID: accelID, chips: chips, agents: agents) {
            orgs.removeAll { $0.id == org.id }
            return err
        }
        AgentOrgs.report(&self, org.id, .milestone, "Founded", "Objective: \(org.objective)")
        Sim.news(&self, "New AI organisation: \(org.name)",
                 "\(Fmt.int(agents)) agents of \(m.name) now work as a \(kind.orgTitle.lowercased()). Objective: \(org.objective)",
                 .research, image: "supercomputer", important: true)
        return nil
    }

    /// Turn a stand-alone swarm into the first team of a new organisation on its mission.
    mutating func formOrg(fromSwarm id: UUID) -> String? {
        guard let i = swarms.firstIndex(where: { $0.id == id }), swarms[i].orgID == nil else { return "Not found." }
        if orgs.count >= AgentOrgs.maxOrgs { return "You can run at most \(AgentOrgs.maxOrgs) organisations." }
        let sw = swarms[i]
        let org = AgentOrg(name: sw.mission.orgTitle, kind: sw.mission, objective: sw.mission.defaultObjective, founded: date,
                           autonomy: sw.autonomy, oversight: sw.oversight, verification: 0.1, budgetMonthly: 0)
        orgs.append(org)
        swarms[i].orgID = org.id
        swarms[i].role = .specialists
        // Fund the tools it would use at today's output.
        let e = AgentOrgs.evaluate(org, self, bonuses)
        if let oi = orgs.firstIndex(where: { $0.id == org.id }) {
            orgs[oi].budgetMonthly = (e.needDaily * 30.4 / 1e4).rounded(.up) * 1e4
        }
        Swarms.log(&self, i, "Became the first team of \(org.name).")
        AgentOrgs.report(&self, org.id, .milestone, "Formed from \(sw.name)", "Objective: \(org.objective)")
        return nil
    }

    mutating func addOrgTeam(_ orgID: UUID, role: TeamRole, name: String, modelID: UUID, accelID: String, chips: Int, agents: Int) -> String? {
        guard let oi = orgs.firstIndex(where: { $0.id == orgID }) else { return "Not found." }
        let o = orgs[oi]
        if swarms.filter({ $0.orgID == orgID }).count >= AgentOrgs.maxTeams { return "An organisation has at most \(AgentOrgs.maxTeams) teams." }
        let modelName = models.first { $0.id == modelID }?.name ?? "Agent"
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let teamName = trimmed.isEmpty ? "\(modelName) \(role.title.lowercased())" : trimmed
        if let err = startSwarm(name: teamName, modelID: modelID, agents: agents, mission: o.kind, accelID: accelID, chips: chips,
                                autonomy: o.autonomy, oversight: o.oversight, announce: false) { return err }
        let i = swarms.count - 1
        swarms[i].orgID = orgID
        swarms[i].role = role
        AgentOrgs.report(&self, orgID, .change, "New \(role.title.lowercased()) team: \(teamName)",
                         "\(Fmt.int(agents)) agents of \(modelName) on \(Fmt.int(chips)) chips.")
        return nil
    }

    mutating func tuneOrg(_ id: UUID, name: String, objective: String, autonomy: Int, oversight: Double, verification: Double,
                          budgetMonthly: Double, focus: Int) -> String? {
        guard let oi = orgs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let b = bonuses
        if autonomy == 2 {
            for sw in swarms where sw.orgID == id {
                if let m = models.first(where: { $0.id == sw.modelID }), !Swarms.canRunAutonomous(m, self, b) {
                    return "\(m.name) (team \(sw.name)) can't be trusted to run on its own yet: full autonomy needs an engineer-level model or Automated AI Research."
                }
            }
        }
        let before = orgs[oi]
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { orgs[oi].name = trimmed }
        let goal = objective.trimmingCharacters(in: .whitespaces)
        if !goal.isEmpty { orgs[oi].objective = goal }
        orgs[oi].autonomy = clamp(autonomy, 0, 2)
        orgs[oi].oversight = clamp(oversight, 0, 0.5)
        orgs[oi].verification = clamp(verification, 0, 0.5)
        orgs[oi].budgetMonthly = max(0, budgetMonthly)
        orgs[oi].focus = max(0, focus)
        for i in swarms.indices where swarms[i].orgID == id {
            swarms[i].autonomy = orgs[oi].autonomy
            swarms[i].oversight = orgs[oi].oversight
        }
        let o = orgs[oi]
        if o.autonomy != before.autonomy || o.oversight != before.oversight || o.verification != before.verification
            || o.budgetMonthly != before.budgetMonthly || o.focus != before.focus {
            var what = "\(AgentOrgs.oversightNames[o.autonomy]), \(Int(o.oversight * 100))% monitors, \(Int(o.verification * 100))% verification, \(Fmt.money(o.budgetMonthly))/mo budget"
            let acts = o.kind.activities
            if acts.count > 1, o.focus < acts.count { what += ", focus: \(acts[o.focus].name.lowercased())" }
            AgentOrgs.report(&self, id, .change, "New settings", what + ".")
        }
        return nil
    }

    mutating func tuneOrgTeam(_ id: UUID, agents: Int, chips: Int) -> String? {
        guard let sw = swarms.first(where: { $0.id == id }) else { return "Not found." }
        return tuneSwarm(id, agents: agents, chips: chips, mission: sw.mission, autonomy: sw.autonomy, oversight: sw.oversight)
    }

    mutating func setOrgPaused(_ id: UUID, _ paused: Bool) -> String? {
        guard let oi = orgs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        for sw in swarms where sw.orgID == id && sw.paused != paused {
            if let err = setSwarmPaused(sw.id, paused) { return "\(sw.name): \(err)" }
        }
        orgs[oi].paused = paused
        AgentOrgs.report(&self, id, .change, paused ? "Paused" : "Resumed")
        return nil
    }

    /// Disband every team and close the organisation. Its chips become idle.
    mutating func dissolveOrg(_ id: UUID) {
        guard let oi = orgs.firstIndex(where: { $0.id == id }) else { return }
        let chips = swarms.filter { $0.orgID == id }.reduce(0) { $0 + $1.chips }
        swarms.removeAll { $0.orgID == id }
        Sim.news(&self, "Organisation dissolved: \(orgs[oi].name)", "\(Fmt.int(chips)) chips are free again.", .company)
        orgs.remove(at: oi)
    }
}

extension AgentOrgs {
    /// Human oversight, by organisation autonomy level.
    static let oversightNames = ["Humans approve every change", "Humans spot-check", "Fully autonomous"]
}
