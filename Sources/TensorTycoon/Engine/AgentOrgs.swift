import Foundation

/// 3.6: AI organisations. Swarms become teams inside an organisation with an objective, specialist and supervisor
/// teams (each running its own model), a compute budget (the teams' inference chips), a money budget, verification,
/// human oversight and a project history.
///
/// Productivity (3.9: pooled over every organisation of a kind, with that mission's stand-alone swarms, so splitting
/// one effort into many organisations never beats running it as one):
///
///     per agent     q_i  = Swarms.quality(model_i) × fit_i × experience_i
///     fit_i              = √(skill fit × domain fit)
///     skill fit          = Swarms.fit: reasoning/code/agentic skill vs a typical model of its generation (0.5–2)
///     domain fit         = clamp(exp(0.08 × Δ_i), 0.5, 2)
///                          Δ_i = model_i's domain-mix score − a typical model of its generation and compute (public
///                          research) − model_i's median gap on the core text domains, in capability points (10 = 10×)
///     effective     E_o  = Σ specialists: active_i × (1 − monitors) × autonomyOutput × sandbagging
///     pool          E    = Σ E_o over the kind's organisations (+ its stand-alone swarms)
///     working       E_w  = E_o × (1 − v_o)                              v = the organisation's verification share
///     hand-offs     k    = 1 + 0.35 log10(max(1, E/100))                work built on work: errors compound k times
///     error rate    ε    = agents' clamp(0.35 × exp(−0.8 × (agenticX − 8)), 0.01, 0.6) + 0.04 (k − 1)
///                          the second term is coordination error — misread specs and broken interfaces — which grows
///                          with the organisation's depth however good the agents are, so verification matters late
///     supervision   σ_o  = min(1, supervisor capacity / (5% of the specialists)); capacity = supervisor agents ×
///                          clamp(their quality ÷ the specialists', 0.05, 4): a weak supervisor covers few
///     caught        κ    = 1 − exp(−6v) × (1 − 0.5σ)
///     quality       Q_o  = (1 − 1.2 ε(1 − κ) − 0.2 εκ)^k / (1 − 1.2 ε_agents)  (vs a plain swarm, one hand-off; ≤ 2)
///     exponent      α    = min(0.98, Swarms.coordination + 0.02σ̄) − 0.025 max(0, log10(E/10⁴))
///                          diminishing returns: the bigger the effort, the less each extra agent adds
///     overhead      Ω    = min(0.6, 0.05 log2(teams) + 0.04 log2(organisations) + 0.035 max(0, log10(E/100)) × (1 − 0.7σ̄))
///     pooled        W    = (Σ q_o E_w,o Q_o ÷ Σ E_w,o) × (Σ E_w,o)^α × (1 − Ω), shared by q_o E_w,o Q_o
///     tools         F_o  = 1 − weight × (1 − funded)                    funded = budget / (cost per worker-day × W_o)
///     activity level     = clamp(log10(1 + W × share) / log10(full), 0, 1)   full = 10⁵, or 10⁶ / 10⁸ for the work only
///                          research leads (≥ 2) or superhuman agents (≥ 8) can do
///
/// So for frontier agents, supervised and verifying, a thousand times the agents (10³ → 10⁶) gives about 250–500× the
/// output once coordination research is complete (exponent 0.95; ~150× with the 0.82 of the mid-2020s), and only about
/// 40–100× more from 10⁶ to 10⁹ — a billion agents do the work of a few million to tens of millions, not a billion.
/// Error-prone models without supervisors do far worse. A model that is better at the mission's domains (coding for
/// software, science for discovery, robotics and vision for robotics) does more per agent. Organisations on the classic
/// missions add W to that mission's pool; the newer kinds, and every kind's higher activities, turn W into a level per
/// activity, which the hooks below read.
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

    /// 3.8: the error rate in your organisation, where the model's reliability know-how is known: more reliable models
    /// than the frontier make fewer mistakes (×0.6–1.4, `Capabilities.agentErrorFactor`).
    static func errorRate(_ m: AIModel, _ s: GameState) -> Double { clamp(errorRate(m) * Capabilities.agentErrorFactor(m, s), 0.005, 0.7) }

    /// 3.9: errors an organisation adds by its depth alone (misread specs, broken interfaces between teams).
    static func coordinationError(depth: Double) -> Double { 0.04 * max(0, depth - 1) }

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
        /// The agents' own error rate, and with the organisation's coordination error (3.9).
        var errorRate = 0.0
        var errorEff = 0.0
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
        var specialistTeams = 0
        /// 3.9: the pool this organisation works in: agents across every organisation of its kind (and the mission's
        /// stand-alone swarms), how many take part, and this organisation's share of the pooled output.
        var poolEffective = 0.0
        var poolParts = 1
        var poolTeams = 0
        var poolShare = 1.0
        /// Output 10× the agents would add, as a multiple (for the scaling line).
        var tenfold = 0.0

        /// Share of finished work that is right.
        var accuracy: Double { 1 - slip }
    }

    static func members(_ o: AgentOrg, _ s: GameState) -> [AgentSwarm] { s.swarms.filter { $0.orgID == o.id } }

    /// What one organisation's teams bring before pooling: its agents, their quality, errors and supervision.
    static func raw(_ o: AgentOrg, members: [AgentSwarm], _ s: GameState, _ b: ResearchBonuses) -> Eval {
        var e = Eval()
        e.verification = clamp(o.verification, 0, 0.5)
        var qSum = 0.0, fitSum = 0.0, edgeSum = 0.0, errSum = 0.0, gateSum = 0.0
        var sups: [(active: Double, q: Double)] = []
        var specialistRaw = 0.0
        for sw in members {
            if let a = HardwareCatalog.get(sw.accelID) { e.computeDaily += sw.paused ? 0 : Economy.chipDailyCost(a, count: sw.chips, state: s) }
            if !sw.paused { e.chips += sw.chips }
            guard !sw.paused, let m = s.models.first(where: { $0.id == sw.modelID }), !m.retired else { continue }
            let active = min(Double(sw.agents), Swarms.capacityAgents(m, accelID: sw.accelID, chips: sw.chips, s, b))
            let general = Swarms.quality(m, s, b)
            if sw.role == .supervisors {
                e.supervisors += active
                sups.append((active * (1 - sw.oversight), general))
                e.teams.append(TeamEval(id: sw.id, name: sw.name, model: m.name, role: .supervisors, active: active, effective: 0,
                                        perAgent: general, fit: 1, edge: 0, errorRate: errorRate(m, s)))
                continue
            }
            let sandbag = sw.alignment < 50 ? 0.5 + sw.alignment / 100 : 1
            let eff = active * (1 - sw.oversight) * Swarms.autonomyOutput[sw.autonomy] * sandbag
            let edge = domainEdge(m, o.kind, s)
            let fit = AgentOrgs.fit(skill: Swarms.fit(m, o.kind), domain: domainFit(edge: edge))
            let q = general * fit * sw.experience
            e.specialists += active
            specialistRaw += active * (1 - sw.oversight)
            e.specialistTeams += 1
            e.effective += eff
            qSum += eff * q
            fitSum += eff * fit
            edgeSum += eff * edge
            errSum += eff * errorRate(m, s)
            gateSum += eff * q * Swarms.xenoGate(m, s)
            e.bestQuality = max(e.bestQuality, general)
            e.teams.append(TeamEval(id: sw.id, name: sw.name, model: m.name, role: .specialists, active: active, effective: eff,
                                    perAgent: q, fit: fit, edge: edge, errorRate: errorRate(m, s), share: eff * q))
        }
        e.shares = activityShares(o.kind.activities, best: e.bestQuality, focus: o.focus)
        guard e.effective > 0 else { return e }
        e.perAgent = qSum / e.effective
        e.fit = fitSum / e.effective
        e.edge = edgeSum / e.effective
        e.errorRate = errSum / e.effective
        e.gate = qSum > 0 ? gateSum / qSum : 0
        for i in e.teams.indices where e.teams[i].role == .specialists { e.teams[i].share = qSum > 0 ? e.teams[i].share / qSum : 0 }
        // 3.9: supervisors cover specialists in proportion to how capable they are next to them (a supervisor a tenth
        // as capable covers a tenth as many), floored at 5%.
        let general = e.perAgent / max(0.01, e.fit)
        let capacity = sups.reduce(0) { $0 + $1.active * clamp($1.q / max(1e-6, general), 0.05, 4) }
        e.supervision = specialistRaw > 0 ? min(1, capacity / (supervisionTarget * specialistRaw)) : 0
        e.working = e.effective * (1 - e.verification)
        e.caught = caught(e.verification, supervision: e.supervision)
        e.naive = e.perAgent * e.effective
        return e
    }

    /// Stand-alone swarms on a mission, which pool with that mission's organisations.
    struct SoloBlock {
        var effective = 0.0
        /// Quality-weighted effective agents (Σ effective × researcher-equivalents per agent).
        var qualitySum = 0.0
        var teams = 0
    }

    static func soloBlock(_ kind: SwarmMission, _ s: GameState, _ b: ResearchBonuses) -> SoloBlock {
        var out = SoloBlock()
        for sw in s.swarms where sw.orgID == nil && !sw.paused && sw.mission == kind {
            guard let m = s.models.first(where: { $0.id == sw.modelID }), !m.retired else { continue }
            let active = min(Double(sw.agents), Swarms.capacityAgents(m, accelID: sw.accelID, chips: sw.chips, s, b))
            let sandbag = sw.alignment < 50 ? 0.5 + sw.alignment / 100 : 1
            let eff = active * (1 - sw.oversight) * Swarms.autonomyOutput[sw.autonomy] * sandbag
            out.effective += eff
            out.qualitySum += eff * Swarms.quality(m, s, b, mission: kind) * sw.experience
            out.teams += 1
        }
        return out
    }

    /// The pooled output of a kind: every organisation's raw evaluation, plus the mission's stand-alone swarms, put
    /// through one scaling exponent, one depth and one overhead. Returns each organisation's finished evaluation
    /// (in `orgs` order) and the stand-alone swarms' share.
    static func pool(_ kind: SwarmMission, orgs: [(org: AgentOrg, raw: Eval)], solo: SoloBlock, _ s: GameState, _ b: ResearchBonuses,
                     coordination: Double? = nil) -> (evals: [Eval], solo: Double) {
        let coord = coordination ?? Swarms.coordination(b, s)
        var evals = orgs.map(\.raw)
        let live = evals.indices.filter { evals[$0].effective > 0 }
        let E = live.reduce(0) { $0 + evals[$1].effective } + solo.effective
        guard E > 0 else { return (evals, 0) }
        let depth = depth(effective: E)
        let coordErr = coordinationError(depth: depth)
        let sigma = live.reduce(0) { $0 + evals[$1].effective * evals[$1].supervision } / E
        let alpha = poolAlpha(coord, supervision: sigma, effective: E)
        let teams = live.reduce(0) { $0 + evals[$1].specialistTeams } + solo.teams
        let parts = live.count + (solo.effective > 0 ? 1 : 0)
        let overhead = poolOverhead(teams: teams, parts: parts, effective: E, supervision: sigma)
        var base: [Int: Double] = [:]
        var working = solo.effective
        for i in live {
            let e = evals[i]
            let eps = min(0.6, e.errorRate + coordErr)
            let q = quality(errorRate: eps, caught: e.caught, depth: depth, baseline: e.errorRate)
            evals[i].errorEff = eps
            evals[i].slip = eps * (1 - e.caught)
            evals[i].quality = q
            base[i] = e.perAgent * e.working * q
            working += e.working
        }
        let soloBase = solo.qualitySum
        let total = base.values.reduce(0, +) + soloBase
        guard working >= 1, total > 0 else { return (evals, 0) }
        let pre = total / working * pow(working, alpha) * (1 - overhead)
        // What ten times the agents would do: a lower exponent, more overhead, deeper hand-offs.
        let orgE = live.reduce(0) { $0 + evals[$1].effective }
        let epsAvg = orgE > 0 ? live.reduce(0) { $0 + evals[$1].effective * evals[$1].errorRate } / orgE : 0.05
        let kAvg = orgE > 0 ? live.reduce(0) { $0 + evals[$1].effective * evals[$1].caught } / orgE : 0
        let depth10 = AgentOrgs.depth(effective: E * 10)
        let qNow = quality(errorRate: min(0.6, epsAvg + coordErr), caught: kAvg, depth: depth, baseline: epsAvg)
        let q10 = quality(errorRate: min(0.6, epsAvg + coordinationError(depth: depth10)), caught: kAvg, depth: depth10, baseline: epsAvg)
        let tenfold = pow(10 * working, poolAlpha(coord, supervision: sigma, effective: E * 10)) / pow(working, alpha)
            * (1 - poolOverhead(teams: teams, parts: parts, effective: E * 10, supervision: sigma)) / max(0.01, 1 - overhead) * q10 / max(1e-9, qNow)
        for i in evals.indices {
            evals[i].depth = depth
            evals[i].alpha = alpha
            evals[i].overhead = overhead
            evals[i].poolEffective = E
            evals[i].poolParts = parts
            evals[i].poolTeams = teams
            evals[i].tenfold = tenfold
            guard let bi = base[i] else { continue }
            let share = bi / total
            let p = pre * share
            let tool = kind.toolCost
            let budget = max(0, orgs[i].org.budgetMonthly) / 30.4
            evals[i].poolShare = share
            evals[i].needDaily = tool.perDay * p
            let funded = evals[i].needDaily > 0 ? min(1, budget / evals[i].needDaily) : 1
            evals[i].spendDaily = min(budget, evals[i].needDaily)
            evals[i].tools = 1 - tool.weight * (1 - funded)
            evals[i].workforce = p * evals[i].tools
        }
        return (evals, pre * soloBase / total)
    }

    /// 3.9: the scaling exponent of a pooled effort: coordination (research, traits) and supervision, less 0.025 per
    /// tenfold beyond ten thousand agents.
    static func poolAlpha(_ coordination: Double, supervision: Double, effective: Double) -> Double {
        min(0.98, coordination + 0.02 * supervision) - 0.025 * max(0, log10(max(1, effective) / 1e4))
    }

    static func poolOverhead(teams: Int, parts: Int, effective: Double, supervision: Double) -> Double {
        min(0.6, 0.05 * log2(Double(max(1, teams))) + 0.04 * log2(Double(max(1, parts)))
            + 0.035 * max(0, log10(max(1, effective) / 100)) * (1 - 0.7 * supervision))
    }

    /// Every organisation of `o`'s kind as it stands (with `o`'s teams replaced by `members`, or `o` added if it's a
    /// proposal), pooled, and `o`'s evaluation from it.
    static func evaluate(_ o: AgentOrg, members m: [AgentSwarm]? = nil, _ s: GameState, _ b: ResearchBonuses) -> Eval {
        var list: [(org: AgentOrg, raw: Eval)] = s.orgs.filter { $0.kind == o.kind && $0.id != o.id }.map { ($0, raw($0, members: members($0, s), s, b)) }
        list.append((o, raw(o, members: m ?? members(o, s), s, b)))
        return pool(o.kind, orgs: list, solo: soloBlock(o.kind, s, b), s, b).evals.last ?? Eval()
    }

    // MARK: Verification

    /// 3.8: hand-offs a piece of work passes through before it ships — one for a small team, more as the organisation
    /// grows (work built on other agents' work), so errors compound.
    static func depth(effective: Double) -> Double { 1 + 0.35 * max(0, log10(max(1, effective) / 100)) }

    /// Share of errors caught before they ship.
    static func caught(_ v: Double, supervision: Double) -> Double { 1 - exp(-6 * v) * (1 - 0.5 * supervision) }

    /// Useful output per unit of working time against a plain swarm (unverified, unsupervised, one hand-off, the agents'
    /// own error rate `baseline`). Each hand-off keeps 1 − 1.2 × (errors that slip) − 0.2 × (errors caught, which cost rework).
    static func quality(errorRate eps: Double, caught k: Double, depth: Double, baseline: Double? = nil) -> Double {
        let step = max(0.05, 1 - 1.2 * eps * (1 - k) - 0.2 * eps * k)
        return min(2, pow(step, depth) / max(0.1, 1 - 1.2 * (baseline ?? eps)))
    }

    /// Output with verification share v, relative to none (everything else equal): (1 − v)^α × Q(v) / Q(0).
    static func verificationGain(_ v: Double, _ e: Eval) -> Double {
        let eps = e.errorEff > 0 ? e.errorEff : e.errorRate
        let q = quality(errorRate: eps, caught: caught(v, supervision: e.supervision), depth: e.depth, baseline: e.errorRate)
        let q0 = quality(errorRate: eps, caught: caught(0, supervision: e.supervision), depth: e.depth, baseline: e.errorRate)
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
        /// Each classic mission's whole pooled output where organisations work it (stand-alone swarms included).
        var workforce: [SwarmMission: Double] = [:]
        /// The stand-alone swarms' part of it.
        var solo: [SwarmMission: Double] = [:]
        /// Alien search output weighted by how many of the agents are smart enough to find anything.
        var xenoGated = 0.0
    }

    static func key(_ kind: SwarmMission, _ activity: Int) -> String { "\(kind.rawValue).\(activity)" }

    /// Level (0–1) of an organisation activity from the researcher-equivalents on it: log-scaled like the classic
    /// missions, with full strength at `full` (100,000 for most: a whole company's worth of work, not one department's).
    static func level(_ w: Double, full: Double = 1e5) -> Double { clamp(log10(1 + max(0, w)) / log10(max(10, full)), 0, 1) }

    static let classic: Set<SwarmMission> = [.research, .xeno, .trainingOps, .silicon, .alignment, .workforce, .security, .intel]

    static func daily(_ s: inout GameState, _ b: ResearchBonuses) -> Contribution {
        var c = Contribution()
        guard !s.orgs.isEmpty else {
            if !s.orgLevels.isEmpty { s.orgLevels = [:] }
            return c
        }
        let newMonth = GameCalendar.components(s.date).day == 1
        if newMonth { for oi in s.orgs.indices { monthlyReport(&s, oi) } }
        var wByKey: [String: Double] = [:]
        var fullByKey: [String: Double] = [:]
        var evals: [UUID: Eval] = [:]
        // Pool each kind (in a fixed order).
        let kinds = SwarmMission.allCases.filter { k in s.orgs.contains { $0.kind == k } }
        for kind in kinds {
            let orgs = s.orgs.filter { $0.kind == kind }
            let raws = orgs.map { ($0, raw($0, members: members($0, s), s, b)) }
            let solo = classic.contains(kind) ? soloBlock(kind, s, b) : SoloBlock()
            let pooled = pool(kind, orgs: raws, solo: solo, s, b)
            for (k, o) in orgs.enumerated() { evals[o.id] = pooled.evals[k] }
            if classic.contains(kind) && pooled.evals.contains(where: { $0.effective > 0 }) {
                c.solo[kind] = pooled.solo
                c.workforce[kind] = pooled.solo
            }
        }
        for oi in s.orgs.indices {
            let o = s.orgs[oi]
            let e = evals[o.id] ?? Eval()
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
            let acts = o.kind.activities
            for (i, share) in e.shares.enumerated() where share > 0 && i < acts.count {
                wByKey[key(o.kind, i), default: 0] += w * share
                fullByKey[key(o.kind, i)] = acts[i].full
            }
            if classic.contains(o.kind) {
                c.workforce[o.kind, default: 0] += w * (e.shares.first ?? 1)
                if o.kind == .xeno { c.xenoGated += w * e.gate }
            }
            if o.kind == .research {
                let w1 = e.shares.count > 1 ? w * e.shares[1] : 0
                let w2 = e.shares.count > 2 ? w * e.shares[2] : 0
                if w1 + w2 > 0 { techniqueStep(&s, oi, w1 + 3 * w2) }
            }
        }
        var levels: [String: Double] = [:]
        for (k, w) in wByKey { levels[k] = level(w, full: fullByKey[k] ?? 1e5) }
        s.orgLevels = levels
        // Discovery institutes running autonomous experiments pull every running moonshot's finish date in.
        let pull = level(s, .discovery, 1) * 0.5
        if pull > 0 {
            for i in s.moonshots.indices where s.moonshots[i].status == .running {
                if let end = s.moonshots[i].ends, end > s.date { s.moonshots[i].ends = end.addingTimeInterval(-pull * 86_400) }
            }
        }
        goalsDaily(&s)
        return c
    }

    static func techniqueCost(_ n: Int) -> Double { 100 * pow(1.6, Double(n)) }

    /// Techniques an architecture-research department can publish: ten, and up to twenty once superhuman agents
    /// automate the research.
    static func techniqueCap(_ s: GameState) -> Int { maxTechniques + Int((10 * level(s, .research, 2)).rounded(.down)) }

    static func techniqueStep(_ s: inout GameState, _ oi: Int, _ w: Double) {
        guard s.orgTechniques < techniqueCap(s) else { return }
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
        if let g = goalLine(o, s) { body += " Objective: \(g)." }
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

    // MARK: Objectives (3.9)

    /// Something an organisation can be held to: a number the game already tracks, how to show it, and a sensible
    /// next step from where it stands.
    struct Metric {
        let key: String
        let title: String
        let kind: SwarmMission
        let format: (Double) -> String
        let value: (GameState) -> Double
        let step: (Double) -> Double
    }

    static func pctMetric(_ key: String, _ title: String, _ kind: SwarmMission, _ value: @escaping (GameState) -> Double, cap: Double = 1) -> Metric {
        Metric(key: key, title: title, kind: kind, format: { Fmt.pct($0, decimals: 0) }, value: value, step: { min(cap, $0 + max(0.1, (cap - $0) * 0.4)) })
    }

    static let metrics: [Metric] = [
        Metric(key: "techniques", title: "Techniques published", kind: .research, format: { "\(Int($0))" }, value: { Double($0.orgTechniques) }, step: { $0 + 2 }),
        Metric(key: "rp", title: "Research points a day from agents", kind: .research, format: { Fmt.count($0) }, value: { $0.swarmRPToday }, step: { max(10, $0 * 2) }),
        pctMetric("insight", "Progress to the next alien architecture", .xeno, { $0.xenoInsight / max(1, Xeno.insightNeeded($0)) }),
        pctMetric("ops", "Training-operations level", .trainingOps, { $0.swarmOps }),
        pctMetric("chiplevel", "Chip-design level", .silicon, { $0.swarmSilicon }),
        pctMetric("defects", "Defect density cut", .silicon, { 1 - defectFactor($0) }, cap: 0.25),
        pctMetric("safety", "Alignment level", .alignment, { $0.swarmSafety }),
        Metric(key: "labour", title: "Labour revenue a year", kind: .workforce, format: { Fmt.money($0) }, value: { $0.laborToday * 365 }, step: { max(1e8, $0 * 1.5) }),
        pctMetric("security", "Security level", .security, { $0.swarmSecurity }),
        pctMetric("intel", "Intelligence level", .intel, { $0.swarmIntel }),
        pctMetric("compiler", "Your chips' software maturity", .software, { $0.semi.software }),
        pctMetric("serving", "Product lines cheaper to serve", .software, { 1 - productServingFactor($0) }, cap: 0.4),
        pctMetric("moonshot", "Moonshot odds added", .discovery, { moonshotOdds($0) }, cap: 0.1),
        pctMetric("science", "Science labs faster", .discovery, { scienceBoost($0) - 1 }, cap: 1.5),
        pctMetric("outages", "Outages avoided", .infrastructure, { 1 - outageFactor($0) }, cap: 0.6),
        pctMetric("powerbill", "Power bill cut", .infrastructure, { 1 - powerFactor($0) }, cap: 0.12),
        Metric(key: "robots", title: "Robotics Brain quality added", kind: .robotics, format: { "+\(Fmt.trim($0, 1))" },
               value: { 2 * level($0, .robotics, 0) + 3 * level($0, .robotics, 1) }, step: { min(5, $0 + 1) }),
        Metric(key: "yield", title: "Interest on cash added (points)", kind: .finance, format: { "+\(Fmt.trim($0, 2))" }, value: { yieldBonus($0) }, step: { min(0.4, $0 + 0.1) }),
        pctMetric("experiments", "Experiments faster", .experiments, { experimentSpeed($0) - 1 }, cap: 0.5),
    ]

    static func metric(_ key: String) -> Metric? { metrics.first { $0.key == key } }

    /// The objectives an organisation of this kind can be given (the first is the default; a software team gets the
    /// compiler objective first once you design chips).
    static func goalOptions(_ kind: SwarmMission, _ s: GameState) -> [Metric] {
        let list = metrics.filter { $0.kind == kind }
        if kind == .software && s.semi.designs.isEmpty { return list.filter { $0.key != "compiler" } + list.filter { $0.key == "compiler" } }
        return list
    }

    /// Where the goal stands, in a phrase ("software maturity 42% → 80% by Mar 2028, on track").
    static func goalLine(_ o: AgentOrg, _ s: GameState) -> String? {
        guard let m = metric(o.goalKey), let deadline = o.goalDeadline else { return nil }
        let now = m.value(s)
        switch o.goalStatus {
        case 1: return "\(m.title.lowercased()) reached \(m.format(o.goalTarget))\(o.goalClosed.map { " on \($0.gameShort)" } ?? "")"
        case 2: return "\(m.title.lowercased()) missed \(m.format(o.goalTarget)) by \(deadline.gameShort) (got to \(m.format(o.goalEnd)))"
        default: return "\(m.title.lowercased()) \(m.format(now)) → \(m.format(o.goalTarget)) by \(deadline.gameShort)\(goalOnTrack(o, s) ? ", on track" : ", behind")"
        }
    }

    /// On track: at least as far from the starting point as the time elapsed would need, moving in a straight line.
    static func goalOnTrack(_ o: AgentOrg, _ s: GameState) -> Bool {
        guard let m = metric(o.goalKey), let deadline = o.goalDeadline else { return false }
        let total = Double(max(1, GameCalendar.daysBetween(o.goalSet ?? o.founded, deadline)))
        let left = Double(max(0, GameCalendar.daysBetween(s.date, deadline)))
        let need = o.goalStart + (o.goalTarget - o.goalStart) * (1 - left / total)
        return m.value(s) >= need - 1e-9
    }

    /// Checks every open objective: met when the number gets there, missed when the deadline passes first.
    static func goalsDaily(_ s: inout GameState) {
        for oi in s.orgs.indices where s.orgs[oi].goalStatus == 0 && !s.orgs[oi].goalKey.isEmpty {
            let o = s.orgs[oi]
            guard let m = metric(o.goalKey), let deadline = o.goalDeadline else { continue }
            let v = m.value(s)
            if v >= o.goalTarget - 1e-9 {
                s.orgs[oi].goalStatus = 1
                s.orgs[oi].goalClosed = s.date
                report(&s, o.id, .milestone, "Objective met: \(m.title.lowercased()) \(m.format(o.goalTarget))",
                       "Reached \(m.format(v)) \(GameCalendar.daysBetween(s.date, deadline)) days before the \(deadline.gameShort) deadline (it stood at \(m.format(o.goalStart))).")
                Sim.news(&s, "\(o.name) hit its objective", "\(m.title): \(m.format(v)), ahead of the \(deadline.gameShort) deadline.", .research, good: true)
            } else if s.date >= deadline {
                s.orgs[oi].goalStatus = 2
                s.orgs[oi].goalClosed = s.date
                s.orgs[oi].goalEnd = v
                report(&s, o.id, .incident, "Objective missed: \(m.title.lowercased()) \(m.format(o.goalTarget))",
                       "Got to \(m.format(v)) from \(m.format(o.goalStart)) by \(deadline.gameShort). More agents, better models, a bigger tools budget or a nearer target.")
                Sim.news(&s, "\(o.name) missed its objective", "\(m.title): \(m.format(v)) of the \(m.format(o.goalTarget)) promised by \(deadline.gameShort).", .research, good: false)
            }
        }
    }

    // MARK: Effects (read by other systems; all exactly neutral without organisations)

    static func level(_ s: GameState, _ kind: SwarmMission, _ activity: Int) -> Double { s.orgLevels[key(kind, activity)] ?? 0 }

    /// Architecture research: published techniques raise training MFU; training-operations teams autotuning kernels
    /// (research-lead agents) add up to 2 points more.
    static func mfuBonus(_ s: GameState) -> Double { 0.003 * Double(min(techniqueCap(s), s.orgTechniques)) + 0.02 * level(s, .trainingOps, 1) }

    /// Software engineering: product lines' serving cost multiplier.
    static func productServingFactor(_ s: GameState) -> Double { 1 - 0.25 * level(s, .software, 0) - 0.15 * level(s, .software, 3) }

    /// Software engineering (all product lines) and robotics engineering (the Robotics Brain): capability points
    /// added to your product-line quality.
    static func productQualityBonus(_ s: GameState, _ productID: String) -> Double {
        2 * level(s, .software, 1) + (productID == "robotics" ? 2 * level(s, .robotics, 0) + 3 * level(s, .robotics, 1) : 0)
    }

    /// Software engineering: the compiler-and-kernel work for your own chips (0–1), which matures their stack.
    static func compilerLevel(_ s: GameState) -> Double { level(s, .software, 2) }

    /// Infrastructure management: multiplier on the chance of a site outage.
    static func outageFactor(_ s: GameState) -> Double { 1 - 0.6 * level(s, .infrastructure, 0) }

    /// Infrastructure management: multiplier on the power bill.
    static func powerFactor(_ s: GameState) -> Double { 1 - 0.12 * level(s, .infrastructure, 1) }

    /// Infrastructure management: multiplier on campus construction time (research-lead agents planning builds).
    static func buildFactor(_ s: GameState) -> Double { 1 - 0.3 * level(s, .infrastructure, 2) }

    /// Financial analysis: percentage points added to the yield on idle cash.
    static func yieldBonus(_ s: GameState) -> Double { 0.4 * level(s, .finance, 0) }

    /// Experiment coordination: speed multiplier for experiments and proxy runs.
    static func experimentSpeed(_ s: GameState) -> Double { 1 + 0.5 * level(s, .experiments, 0) }

    /// Scientific discovery: added to the moonshot science factor.
    static func moonshotOdds(_ s: GameState) -> Double { 0.1 * level(s, .discovery, 0) }

    /// Scientific discovery: a general multiplier on scientific progress — your science labs' stage speed (1–2.5).
    /// (Science has no public way to grant a discovery outright, so automated science speeds the labs that make them.)
    static func scienceBoost(_ s: GameState) -> Double { 1 + 0.5 * (level(s, .discovery, 0) + level(s, .discovery, 1) + level(s, .discovery, 2)) }

    /// Semiconductor engineering with research-lead agents: defect density multiplier on your products.
    static func defectFactor(_ s: GameState) -> Double { 1 - 0.25 * level(s, .silicon, 1) }

    /// …and how far above the human cap (1.2) a design's architecture may go.
    static func archCapBonus(_ s: GameState) -> Double { 0.15 * level(s, .silicon, 1) }

    /// Semiconductor engineering with superhuman agents: architecture added to new designs, and respin odds multiplier.
    static func archSearch(_ s: GameState) -> Double { 0.12 * level(s, .silicon, 2) }
    static func respinFactor(_ s: GameState) -> Double { 1 - 0.4 * level(s, .silicon, 2) }

    /// Alignment institutes with research-lead agents: multiplier on every team's drift (automated interpretability).
    static func interpretabilityFactor(_ s: GameState) -> Double { 1 - 0.3 * level(s, .alignment, 1) }

    /// Digital-workforce agencies with research-lead agents: multiplier on the labour market you can reach.
    static func laborReach(_ s: GameState) -> Double { 1 + 0.5 * level(s, .workforce, 1) }

    /// What the organisations of this kind are doing to the game right now, in a phrase.
    static func impact(_ kind: SwarmMission, _ s: GameState) -> String {
        func p(_ v: Double) -> String { Fmt.pct(v, decimals: 0) }
        func extra(_ i: Int, _ text: String) -> String { level(s, kind, i) > 0.005 ? " · " + text : "" }
        switch kind {
        case .research:
            return "\(Fmt.count(s.swarmRPToday)) RP/day from agents · \(s.orgTechniques) technique\(s.orgTechniques == 1 ? "" : "s") (+\(Fmt.trim(mfuBonus(s) * 100, 1)) MFU points)"
                + extra(2, "up to \(techniqueCap(s)) techniques")
        case .xeno: return "\(Fmt.trim(s.xenoInsightToday, 1)) insight/day"
        case .trainingOps: return "Ops level \(p(s.swarmOps))" + extra(1, "kernels +\(Fmt.trim(2 * level(s, .trainingOps, 1), 1)) MFU points")
        case .silicon:
            return "Chip design level \(p(s.swarmSilicon))" + extra(1, "defects −\(p(1 - defectFactor(s))), architecture cap +\(Fmt.trim(archCapBonus(s), 2))")
                + extra(2, "architecture +\(Fmt.trim(archSearch(s), 2)), respins ×\(Fmt.trim(respinFactor(s), 2))")
        case .alignment: return "Safety level \(p(s.swarmSafety))" + extra(1, "drift −\(p(1 - interpretabilityFactor(s)))")
        case .workforce: return "\(Fmt.money(s.laborToday * 365))/yr of labour" + extra(1, "market reach +\(p(laborReach(s) - 1))")
        case .security: return "Security level \(p(s.swarmSecurity))"
        case .intel: return "Intel level \(p(s.swarmIntel))"
        case .software:
            return "Product lines \(p(1 - productServingFactor(s))) cheaper to serve · quality +\(Fmt.trim(2 * level(s, .software, 1), 1))"
                + extra(2, "chip software maturing +\(Fmt.trim(0.8 * compilerLevel(s), 2))/yr")
        case .discovery:
            return "Moonshot odds +\(p(moonshotOdds(s))) · moonshots \(Fmt.trim(1 + 0.5 * level(s, .discovery, 1), 2))× faster" + extra(2, "science labs \(Fmt.trim(scienceBoost(s), 2))× faster")
        case .infrastructure:
            return "Outages \(p(1 - outageFactor(s))) rarer · power bill −\(p(1 - powerFactor(s)))" + extra(2, "builds −\(p(1 - buildFactor(s)))")
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
        if e.poolParts > 1 {
            rows.append(("Pooled", Fmt.pct(e.poolShare, decimals: 0),
                         "Works alongside \(e.poolParts - 1) other \(e.poolParts == 2 ? "group" : "groups") on this kind of work (\(Fmt.count(e.poolEffective)) agents in all): one effort scaled once, so splitting it gains nothing"))
        }
        rows.append(("Scaling", "N^\(Fmt.trim(e.alpha, 2))",
                     "\(Fmt.count(e.poolEffective)) agents do the work of \(Fmt.count(pow(max(1, e.poolEffective), e.alpha))) independent ones; the exponent drops 0.025 per tenfold past 10,000 — ten times the agents would give about \(Fmt.trim(e.tenfold, 1))× the output"))
        let best = bestVerification(e)
        let advice: String
        if abs(best - e.verification) < 0.025 {
            advice = "about the best share for these models"
        } else {
            let gain = verificationGain(best, e) / max(1e-9, verificationGain(e.verification, e)) - 1
            advice = "\(Fmt.pct(best, decimals: 0)) would give \(gain >= 0.005 ? "+\(Fmt.pct(gain, decimals: 0))" : "about the same") output"
        }
        rows.append(("Verification", "−\(Fmt.pct(e.verification, decimals: 0)) time",
                     "Catches \(Fmt.pct(e.caught, decimals: 0)) of a \(Fmt.pct(e.errorEff, decimals: 0)) error rate (agents \(Fmt.pct(e.errorRate, decimals: 0)) + coordination \(Fmt.pct(max(0, e.errorEff - e.errorRate), decimals: 0))); \(Fmt.pct(e.slip, decimals: 1)) slips through · \(advice)"))
        rows.append(("Quality", "×\(Fmt.trim(e.quality, 2))",
                     "Against an unverified, unsupervised swarm of the same models. Work passes through \(Fmt.trim(e.depth, 1)) hand-offs here, so errors that slip compound"))
        rows.append(("Supervision", Fmt.pct(e.supervision, decimals: 0),
                     e.supervision >= 1 ? "Fully staffed: +0.02 to the exponent, less overhead, fewer errors and less drift"
                                        : "Supervisors for \(Fmt.pct(supervisionTarget, decimals: 0)) of the specialists give full supervision; a weaker model supervises proportionally fewer"))
        rows.append(("Coordination overhead", "−\(Fmt.pct(e.overhead, decimals: 0))", "Grows with teams (\(e.poolTeams)), separate organisations (\(e.poolParts)) and log(size); supervisors cut most of it"))
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
        AgentOrgs.setDefaultGoal(&self, org.id)
        AgentOrgs.report(&self, org.id, .milestone, "Founded", "Objective: \(org.objective)" + (AgentOrgs.goalLine(orgs.last!, self).map { " — \($0)" } ?? ""))
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
        AgentOrgs.setDefaultGoal(&self, org.id)
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

    /// 3.9: give an organisation a measurable objective: a metric its kind moves, a target and a deadline in months.
    mutating func setOrgGoal(_ id: UUID, key: String, target: Double, months: Int) -> String? {
        guard let oi = orgs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        guard let m = AgentOrgs.metric(key), m.kind == orgs[oi].kind else { return "Pick an objective this organisation can work on." }
        let now = m.value(self)
        if target <= now + 1e-9 { return "\(m.title) is already \(m.format(now)): set a higher target." }
        if months < 1 || months > 60 { return "Pick a deadline between 1 and 60 months away." }
        orgs[oi].goalKey = key
        orgs[oi].goalTarget = target
        orgs[oi].goalStart = now
        orgs[oi].goalSet = date
        orgs[oi].goalDeadline = GameCalendar.addMonths(date, months)
        orgs[oi].goalStatus = 0
        orgs[oi].goalClosed = nil
        AgentOrgs.report(&self, id, .change, "New objective", "\(m.title): \(m.format(now)) → \(m.format(target)) by \(orgs[oi].goalDeadline!.gameShort).")
        return nil
    }

    /// 3.9: a team can move to another model or other hardware (a team whose chips are gone could never run again).
    mutating func tuneOrgTeam(_ id: UUID, agents: Int, chips: Int, modelID: UUID? = nil, accelID: String? = nil) -> String? {
        guard let sw = swarms.first(where: { $0.id == id }) else { return "Not found." }
        return tuneSwarm(id, agents: agents, chips: chips, mission: sw.mission, autonomy: sw.autonomy, oversight: sw.oversight, modelID: modelID, accelID: accelID)
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

    /// A new organisation's first objective: its kind's main number, a sensible step up, a year to get there.
    static func setDefaultGoal(_ s: inout GameState, _ id: UUID) {
        guard let oi = s.orgs.firstIndex(where: { $0.id == id }), let m = goalOptions(s.orgs[oi].kind, s).first else { return }
        let now = m.value(s)
        s.orgs[oi].goalKey = m.key
        s.orgs[oi].goalStart = now
        s.orgs[oi].goalTarget = m.step(now)
        s.orgs[oi].goalSet = s.date
        s.orgs[oi].goalDeadline = GameCalendar.addMonths(s.date, 12)
        s.orgs[oi].goalStatus = 0
    }

    /// 3.9 bot: found one organisation of a sensible size once the lab can afford its compute — a software team
    /// (compilers for your chips when you design them) on the best model, sized to the free chips, with supervisors.
    static func botAct(_ s: inout GameState) {
        guard s.year >= 2024, let m = s.models.filter({ !$0.retired && $0.released }).max(by: { Swarms.quality($0, s) < Swarms.quality($1, s) }),
              Swarms.quality(m, s) >= 0.05 else { return }
        if let o = s.orgs.first {
            // Teams whose model was retired, or whose (rented) chips are gone, stop working: let them go and restaff
            // the organisation with the best model on whatever chips are free.
            for sw in s.swarms where sw.orgID == o.id && (sw.paused || sw.chips < 1 || (s.models.first { $0.id == sw.modelID }?.retired ?? true)) {
                s.disbandSwarm(sw.id)
            }
            if members(o, s).isEmpty { _ = botStaff(&s, o.id, m) }
            return
        }
        guard let (accel, chips, agents) = botTeam(s, m) ?? botRentTeam(&s, m) else { return }
        guard s.foundOrg(kind: .software, name: "", objective: "", modelID: m.id, accelID: accel, chips: chips, agents: agents,
                         autonomy: 1, oversight: 0.1, verification: 0.1, budgetMonthly: 0) == nil, let o = s.orgs.last else { return }
        botSupervise(&s, o.id, m, accel: accel, agents: agents)
    }

    /// 3.9: when every chip is busy serving (a rented fleet sized to demand), rent a small team's worth (1,000 agents)
    /// on demand on the pool it serves from, when that's under a tenth of the fleet.
    static func botRentTeam(_ s: inout GameState, _ m: AIModel) -> (accel: String, chips: Int, agents: Int)? {
        let b = s.bonuses
        guard let pool = Economy.pools(s).filter({ $0.accel.cls != .consumer && $0.inference > 0 }).max(by: { $0.inference < $1.inference }) else { return nil }
        let a = pool.accel
        let copy = Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b)
        let per = Swarms.chipsNeeded(m, accelID: a.id, agents: 1_000, s, b)
        guard per > 0, per < Int.max / 8 else { return nil }
        let chips = max(copy, per)
        guard chips <= pool.inference / 10, s.rentHardware(a.id, count: max(0, chips - pool.free), term: .onDemand) == nil else { return nil }
        let agents = min(1_000, Int(Swarms.capacityAgents(m, accelID: a.id, chips: chips, s, b)))
        return agents >= 100 ? (a.id, chips, agents) : nil
    }

    /// A team of sensible size for the bot: a quarter of the best free pool, at least one copy of the model, ten
    /// thousand agents at most.
    static func botTeam(_ s: GameState, _ m: AIModel) -> (accel: String, chips: Int, agents: Int)? {
        let b = s.bonuses
        guard let pool = Economy.pools(s).filter({ $0.free > 0 && $0.accel.cls != .consumer }).max(by: { Double($0.free) * $0.accel.best < Double($1.free) * $1.accel.best }) else { return nil }
        let a = pool.accel
        let copy = Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b)
        let per = Swarms.chipsNeeded(m, accelID: a.id, agents: 10_000, s, b)
        guard per > 0, per < Int.max / 8 else { return nil }
        // 3.9: at least one copy when the pool has one free (a quarter of a nearly full fleet is often less than a copy,
        // so whether the bot ever founded an organisation came down to luck).
        let chips = min(pool.free, max(copy, min(pool.free / 4, per)))
        guard chips >= copy else { return nil }
        let agents = min(10_000, Int(Swarms.capacityAgents(m, accelID: a.id, chips: chips, s, b)))
        return agents >= 100 ? (a.id, chips, agents) : nil
    }

    static func botStaff(_ s: inout GameState, _ id: UUID, _ m: AIModel) -> Bool {
        guard let (accel, chips, agents) = botTeam(s, m) else { return false }
        guard s.addOrgTeam(id, role: .specialists, name: "", modelID: m.id, accelID: accel, chips: chips, agents: agents) == nil else { return false }
        botSupervise(&s, id, m, accel: accel, agents: agents)
        return true
    }

    /// Supervisors (about 5% of the specialists) on the same chips if any are left, and a budget that funds the tools.
    static func botSupervise(_ s: inout GameState, _ id: UUID, _ m: AIModel, accel: String, agents: Int) {
        let b = s.bonuses
        let sup = max(1, agents / 20)
        let supChips = Swarms.chipsNeeded(m, accelID: accel, agents: sup, s, b)
        if supChips <= Economy.freeChips(s, accel) {
            _ = s.addOrgTeam(id, role: .supervisors, name: "", modelID: m.id, accelID: accel, chips: supChips, agents: sup)
        }
        guard let oi = s.orgs.firstIndex(where: { $0.id == id }) else { return }
        let e = evaluate(s.orgs[oi], s, b)
        s.orgs[oi].budgetMonthly = (e.needDaily * 30.4 / 1e4).rounded(.up) * 1e4
    }
}

extension AgentOrgs {
    /// Summary lines for the playtest (`orgs` flag).
    static func summary(_ s: GameState) -> [String] {
        guard !s.orgs.isEmpty else { return ["  orgs: none founded"] }
        let b = s.bonuses
        return s.orgs.map { o in
            let e = evaluate(o, s, b)
            return "  org \(o.name): \(Fmt.count(o.totalOutput)) researcher-eq-days in all, \(o.history.filter { $0.kind == .change }.count) changes · now \(Fmt.count(o.agents)) agents → \(Fmt.count(o.workforce)) researcher-eq (α \(Fmt.trim(e.alpha, 2)), overhead \(Fmt.pct(e.overhead, decimals: 0)), quality ×\(Fmt.trim(e.quality, 2)), supervision \(Fmt.pct(e.supervision, decimals: 0))) · spent \(Fmt.money(o.totalSpend)) on tools · \(impact(o.kind, s)) · objective: \(goalLine(o, s) ?? "none")"
        }
    }
}
