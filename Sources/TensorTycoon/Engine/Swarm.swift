import Foundation

/// Agent swarms: thousands to millions of copies of one of your models, running on your own inference chips,
/// working a single mission. Output is pooled per mission with a coordination exponent, so one big swarm and
/// ten small ones of the same total size do the same work. 3.9: the exponent falls as the pool grows (diminishing
/// returns past ten thousand agents), and where organisations work the same mission the stand-alone swarms pool with
/// them (AgentOrgs.pool).
enum Swarms {
    static let autonomyOutput = [0.7, 1.0, 1.45]
    static let autonomyDrift = [0.3, 1.0, 2.6]
    /// 3.6: organisations hold several teams each, so the cap counts every swarm, stand-alone or in an organisation.
    static let maxSwarms = 40
    static let maxAgents = 1_000_000_000

    /// Tokens one agent burns per day, prefill included: agents loop on tools, re-read whole repos and never sleep.
    static func tokensPerAgentDay(_ y: Double) -> Double {
        interpolateLog([(2023, 8e6), (2025, 1.5e7), (2027, 3e7), (2030, 5e7), (2035, 8e7)], at: y, extrapolate: true)
    }

    static func agenticX(_ m: AIModel) -> Double { Leaderboard.profile(m).agenticX }

    /// Human-researcher equivalents per agent. About 1/10 of a researcher for an early-2026 frontier agent,
    /// half a researcher around 2028, a couple by 2030.
    static func quality(_ m: AIModel) -> Double { clamp(0.05 * exp(1.1 * (agenticX(m) - 8.0)), 0.0003, 25) }

    /// Agent quality including your lab's traits. A model never trained to call tools still works through a
    /// prompt-only scaffold, at a little over half the output.
    static func quality(_ m: AIModel, _ s: GameState) -> Double { quality(m, s, s.bonuses) }

    /// The same with the research bonuses already worked out (the daily simulation passes them: `s.bonuses` rebuilds
    /// the whole research bonus set every time it's read).
    static func quality(_ m: AIModel, _ s: GameState, _ b: ResearchBonuses) -> Double {
        quality(m) * max(0.3, 1 + s.traits.swarm + b.agentQuality) * (m.design.toolUse ? 1 : 0.6)
    }

    /// How well the model's particular strengths fit a mission, against a typical model of its generation
    /// (0.5–2×). A reasoning-heavy model is a better researcher; a coder is a better chip designer.
    static func fit(_ m: AIModel, _ mission: SwarmMission) -> Double {
        let p = Leaderboard.profile(m)
        let ref = Leaderboard.frontierProfile(m.created.decimalYear, key: "fit", c: m.c, reasoningModel: m.reasoning)
        let w = mission.skillMix
        func edge(_ x: ModelProfile) -> Double {
            0.7 * x.reasoning * (w.reasoning - 1) + 0.5 * x.code * (w.code - 1) + x.agent * (w.agent - 1)
                + w.chat * x.chat + w.safety * x.safety
        }
        return clamp(exp(1.5 * (edge(p) - edge(ref))), 0.5, 2)
    }

    /// Researcher-equivalents per agent on a given mission.
    static func quality(_ m: AIModel, _ s: GameState, mission: SwarmMission) -> Double { quality(m, s) * fit(m, mission) }
    static func quality(_ m: AIModel, _ s: GameState, _ b: ResearchBonuses, mission: SwarmMission) -> Double { quality(m, s, b) * fit(m, mission) }

    /// What one agent is like to work with.
    static func tier(_ q: Double) -> String {
        switch q {
        case ..<0.01: "Autocomplete"
        case ..<0.05: "Intern"
        case ..<0.2: "Junior engineer"
        case ..<0.6: "Engineer"
        case ..<2: "Senior researcher"
        case ..<8: "Research lead"
        default: "Superhuman researcher"
        }
    }

    /// How long one agent can work on its own before it goes off the rails (METR-style 50% horizon).
    static func horizon(_ m: AIModel) -> String {
        BenchmarkCatalog.formatHorizon(BenchmarkCatalog.taskHorizonMinutes(Leaderboard.profile(m)))
    }

    /// Full autonomy needs a model that works like an engineer on its own — or Automated AI Research.
    static func canRunAutonomous(_ m: AIModel, _ s: GameState, _ b: ResearchBonuses) -> Bool {
        b.has(.autoResearch) || b.has(.rsi) || quality(m, s) >= 0.6
    }

    /// 3.9: the exponent a pool of `agents` effective agents scales with: coordination, less 0.025 per tenfold past
    /// ten thousand (a billion agents never do a billion agents' work).
    static func exponent(_ b: ResearchBonuses, _ s: GameState, agents: Double) -> Double {
        coordination(b, s) - 0.025 * max(0, log10(max(1, agents) / 1e4))
    }

    /// How well big swarms coordinate (output grows as agents^coordination).
    static func coordination(_ b: ResearchBonuses, _ s: GameState) -> Double {
        min(s.signatureAt(.atlas, 5) ? 0.98 : 0.95, 0.78 + (b.has(.agents) ? 0.04 : 0) + (b.has(.autoResearch) ? 0.04 : 0) + (b.has(.rsi) ? 0.04 : 0)
            + s.traits.coordination + b.coordination + (s.signatureAt(.atlas, 5) ? 0.1 : 0))
    }

    /// Only near-frontier agents find anything genuinely new.
    static func xenoGate(_ m: AIModel) -> Double { sigmoid((agenticX(m) - 8.3) / 0.3) }

    /// Xeno Resonance level 3 lets a model a step below the frontier search too.
    static func xenoGate(_ m: AIModel, _ s: GameState) -> Double {
        sigmoid((agenticX(m) - (s.signatureAt(.antenna, 3) ? 7.9 : 8.3)) / 0.3)
    }

    static func usesAlien(_ m: AIModel) -> Bool { m.design.mixer == .alien }

    /// Agents a deployment of `chips` can keep busy.
    static func capacityAgents(_ m: AIModel, accelID: String, chips: Int, _ s: GameState, _ b: ResearchBonuses) -> Double {
        guard chips > 0 else { return 0 }
        let cap = Physics.capacity(m, deployment: Deployment(accelID: accelID, chips: chips), bonuses: b)
        // Cognitive Scaffold level 3: agents need 40% fewer tokens.
        return cap / (tokensPerAgentDay(s.year) * (s.signatureAt(.atlas, 3) ? 0.6 : 1))
    }

    /// Chips needed for `agents` agents (rounded up to whole replicas).
    static func chipsNeeded(_ m: AIModel, accelID: String, agents: Int, _ s: GameState, _ b: ResearchBonuses) -> Int {
        guard let a = HardwareCatalog.get(accelID) else { return 0 }
        let k = Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b)
        let perReplica = capacityAgents(m, accelID: accelID, chips: k, s, b)
        guard perReplica > 0 else { return Int.max / 4 }
        let replicas = Int(ceil(Double(agents) / perReplica))
        return max(1, replicas) * k
    }

    /// Mission level 0–1 from a pooled workforce (1,000 researcher-equivalents ≈ full strength).
    static func level(_ workforce: Double) -> Double { clamp(log10(1 + workforce) / 3, 0, 1) }

    /// Research is bottlenecked on experiment compute and ideas, so it grows slower than the workforce.
    static func researchRP(_ w: Double) -> Double { 2.5 * pow(max(0, w), 0.6) }

    static func insight(_ w: Double) -> Double { 0.23 * pow(max(0, w), 0.6) }

    /// What companies pay per researcher-equivalent day of agent labor.
    static func wage(_ y: Double) -> Double { interpolate([(2023, 250), (2026, 600), (2030, 900), (2035, 1_100)], at: y, extrapolate: false) }

    /// Annual market for AI agent labor across the economy.
    static func laborMarket(_ y: Double) -> Double {
        guard y >= 2023.5 else { return 0 }
        return interpolateLog([(2023.5, 2e8), (2025, 4e9), (2026, 2.5e10), (2027, 8e10), (2028, 2e11), (2030, 8e11), (2035, 3e12)], at: y, extrapolate: true)
    }

    static func laborCap(_ s: GameState) -> Double {
        laborMarket(s.year) / 365 * clamp(0.05 + s.brand / 250, 0.05, 0.45) * s.difficulty.demandMultiplier * max(0.3, 1 + s.traits.labor)
            * AgentOrgs.laborReach(s)   // 3.9: enterprise automation by research-lead agents
    }

    static func drift(_ sw: AgentSwarm, model m: AIModel?, _ s: GameState, _ b: ResearchBonuses) -> Double {
        var d = 0.025 * autonomyDrift[sw.autonomy] * max(0.05, 1 - 1.6 * sw.oversight) * (1 - RSI.safetyFactor(s, b))
            * (0.5 + 0.25 * log10(max(10, Double(sw.agents))))
        if let m, usesAlien(m) { d *= 1 + (1 - Xeno.bestLegibility(s)) }
        if sw.mission != .alignment { d *= 1 - 0.5 * s.swarmSafety }
        d *= AgentOrgs.interpretabilityFactor(s)   // 3.9: automated interpretability
        if sw.orgID != nil { d *= AgentOrgs.driftFactor(sw, s) }   // 3.6: supervisors and verification
        return d * s.traits.driftKeep * (1 - min(0.6, b.agentSafety)) * (s.signatureAt(.keel, 3) ? 0.7 : 1)
    }

    static func detection(_ sw: AgentSwarm, _ s: GameState, _ b: ResearchBonuses) -> Double {
        var d = 0.3 + sw.oversight * 1.2 + RSI.safetyFactor(s, b) * 0.35
        if b.has(.aiControl) { d += 0.1 }
        if s.lawsPassed.contains("agent_registry") { d += 0.1 }
        if s.lawsPassed.contains("independent_auditors") { d += 0.05 }
        return clamp(d, 0.1, 0.97)
    }

    // MARK: Forecast (for the planner)

    struct Forecast {
        var capacity: Double
        var active: Double
        var perAgent: Double
        var workforce: Double
        var chipsNeeded: Int
        var drift: Double
        var dailyCost: Double
        var output: String
    }

    static func forecast(model m: AIModel, accelID: String, chips: Int, agents: Int, mission: SwarmMission,
                         autonomy: Int, oversight: Double, _ s: GameState, _ b: ResearchBonuses) -> Forecast {
        let cap = capacityAgents(m, accelID: accelID, chips: chips, s, b)
        let active = min(Double(agents), cap)
        // Marginal effect: what this swarm adds on top of the swarms already working the mission.
        let others = s.swarms.filter { !$0.paused && $0.mission == mission }.map(\.workforce).reduce(0, +)
        let effective = active * (1 - oversight) * autonomyOutput[autonomy]
        let w = effective >= 1 ? quality(m, s, b, mission: mission) * pow(effective, exponent(b, s, agents: effective)) : 0
        let probe = AgentSwarm(name: "", modelID: m.id, agents: agents, mission: mission, accelID: accelID, chips: chips,
                               autonomy: autonomy, oversight: oversight, started: s.date)
        let a = HardwareCatalog.get(accelID)
        let cost = a.map { Economy.chipDailyCost($0, count: chips, state: s) } ?? 0
        let out: String
        switch mission {
        case .research:
            out = "+\(Fmt.count(researchRP(others + w) - researchRP(others))) RP/day"
        case .xeno:
            let i = (insight((others + w) * xenoGate(m, s)) - insight(others * xenoGate(m, s))) * (1 + s.traits.insight + s.bonuses.insight) * (b.has(.agents) ? 1 : 0.6)
            let left = max(0, Xeno.insightNeeded(s) - s.xenoInsight)
            out = i > 0.01 ? "+\(Fmt.trim(i, 1)) insight/day · ~\(Fmt.days(left / max(0.01, i + s.xenoInsightToday)))" : "Model too weak to find anything"
        case .trainingOps:
            let chips = s.runs.filter { $0.kind == .full && ($0.status == .running || $0.status == .postTraining) }.reduce(0) { $0 + $1.design.chips }
            out = chips > 0 ? "Covers ~\(Int(min(1, w / max(0.5, Double(chips) / 600)) * 100))% of \(Fmt.int(chips)) training chips" : "Level \(Int(level(others + w) * 100))%"
        case .silicon, .alignment, .security, .intel, .software, .discovery, .infrastructure, .robotics, .finance, .experiments:
            out = "Level \(Int(level(others + w) * 100))%"
        case .workforce:
            let rev = min(laborCap(s), (others + w) * wage(s.year)) - min(laborCap(s), others * wage(s.year))
            out = "+\(Fmt.money(rev * 365))/yr"
        }
        return Forecast(capacity: cap, active: active, perAgent: quality(m, s, mission: mission), workforce: w,
                        chipsNeeded: chipsNeeded(m, accelID: accelID, agents: agents, s, b),
                        drift: drift(probe, model: m, s, b) * 365, dailyCost: cost, output: out)
    }

    // MARK: Daily

    static func log(_ s: inout GameState, _ i: Int, _ text: String) {
        s.swarms[i].log.insert("\(s.date.gameShort) · \(text)", at: 0)
        if s.swarms[i].log.count > 40 { s.swarms[i].log.removeLast() }
    }

    static func daily(_ s: inout GameState, _ b: ResearchBonuses) {
        s.swarmRPToday = 0
        s.laborToday = 0
        guard !s.swarms.isEmpty else {
            s.swarmOps = 0
            s.swarmSilicon = 0
            s.swarmSafety = 0
            s.swarmSecurity = 0
            s.swarmIntel = 0
            _ = AgentOrgs.daily(&s, b)   // 3.6: organisations without teams (clears their levels)
            return
        }
        // Pool each mission: effective agents and quality-weighted sums.
        var effAgents: [SwarmMission: Double] = [:]
        var qualitySum: [SwarmMission: Double] = [:]
        var gateSum: [SwarmMission: Double] = [:]
        var shares: [Int: Double] = [:]
        for i in s.swarms.indices {
            let sw = s.swarms[i]
            guard !sw.paused, let m = s.models.first(where: { $0.id == sw.modelID }) else {
                s.swarms[i].active = 0
                s.swarms[i].workforce = 0
                s.swarms[i].output = 0
                continue
            }
            if m.retired {
                s.swarms[i].paused = true
                log(&s, i, "Paused: \(m.name) was retired.")
                continue
            }
            let active = min(Double(sw.agents), capacityAgents(m, accelID: sw.accelID, chips: sw.chips, s, b))
            let sandbag = sw.alignment < 50 ? 0.5 + sw.alignment / 100 : 1
            let eff = active * (1 - sw.oversight) * autonomyOutput[sw.autonomy] * sandbag
            s.swarms[i].active = active
            s.swarms[i].missionDays += 1
            // 3.6: teams of an organisation are pooled by the organisation (AgentOrgs), not here.
            if let oid = sw.orgID, s.orgs.contains(where: { $0.id == oid }) {
                if active >= 1_000 { Achievements.unlock(&s, "swarm_1k") }
                if active >= 1_000_000 { Achievements.unlock(&s, "swarm_1m") }
                alignmentStep(&s, i, model: m, b)
                continue
            }
            // 3.8: a swarm seconded to a government programme works for the programme, not its mission (no labour revenue).
            if AdvancedProjects.swarmSeconded(s, sw.id) {
                s.swarms[i].workforce = 0
                s.swarms[i].output = 0
                alignmentStep(&s, i, model: m, b)
                continue
            }
            effAgents[sw.mission, default: 0] += eff
            let q = quality(m, s, b, mission: sw.mission) * sw.experience
            qualitySum[sw.mission, default: 0] += eff * q
            gateSum[sw.mission, default: 0] += eff * q * xenoGate(m, s)
            shares[i] = eff * q
            if active >= 1_000 { Achievements.unlock(&s, "swarm_1k") }
            if active >= 1_000_000 { Achievements.unlock(&s, "swarm_1m") }
            alignmentStep(&s, i, model: m, b)
        }
        var workforce: [SwarmMission: Double] = [:]
        for (mission, a) in effAgents where a >= 1 {
            let q = (qualitySum[mission] ?? 0) / a
            workforce[mission] = q * pow(a, exponent(b, s, agents: a))
        }
        // 3.6: organisations work the same mission pools. 3.9: where they do, the stand-alone swarms pool with them
        // (one exponent, one overhead) and AgentOrgs reports the whole mission's output and the swarms' part of it.
        var solo = workforce
        let org = AgentOrgs.daily(&s, b)
        for (mission, w) in org.workforce {
            workforce[mission] = w
            solo[mission] = org.solo[mission] ?? 0
        }
        // Mission effects
        let wResearch = workforce[.research] ?? 0
        s.swarmRPToday = researchRP(wResearch)
        let wXeno = workforce[.xeno] ?? 0
        // Without Agentic RL research the search still runs, just less efficiently.
        let xenoScale = (1 + s.traits.insight + s.bonuses.insight) * (b.has(.agents) ? 1 : 0.6)
        let soloGated = (solo[.xeno] ?? 0) > 0 ? (solo[.xeno] ?? 0) * (gateSum[.xeno] ?? 0) / max(1e-12, qualitySum[.xeno] ?? 0) : 0
        if wXeno > 0, soloGated + org.xenoGated > 0 {
            s.xenoInsightToday += insight(soloGated + org.xenoGated) * xenoScale
        }
        s.swarmOps = level(workforce[.trainingOps] ?? 0)
        s.swarmSilicon = level(workforce[.silicon] ?? 0)
        s.swarmSafety = level(workforce[.alignment] ?? 0)
        s.swarmSecurity = level(workforce[.security] ?? 0)
        s.swarmIntel = level(workforce[.intel] ?? 0)
        let wLabor = workforce[.workforce] ?? 0
        let labor = min(laborCap(s), wLabor * wage(s.year))
        if labor > 0 {
            s.laborToday = labor
            s.cash += labor
            s.month.revLabor += labor
            s.lifetimeRevenue += labor
        }
        // Per-swarm display: each swarm's share of its mission's pooled output.
        for i in s.swarms.indices {
            let sw = s.swarms[i]
            guard !sw.paused, let share = shares[i], let total = qualitySum[sw.mission], total > 0 else { continue }
            // A stand-alone swarm's share of its mission's output (all of it when no organisation works the mission).
            let frac = share / total
            let soloW = solo[sw.mission] ?? 0
            let pooled = workforce[sw.mission] ?? 0
            let ofPool = pooled > 0 ? soloW / pooled : 1
            let w = soloW * frac
            s.swarms[i].workforce = w
            let out: Double
            switch sw.mission {
            case .research: out = s.swarmRPToday * frac * ofPool
            case .xeno: out = s.xenoInsightToday > 0 ? insight(soloGated + org.xenoGated) * xenoScale * frac * (soloGated / max(1e-12, soloGated + org.xenoGated)) : 0
            case .workforce: out = labor * frac * ofPool
            default: out = w
            }
            s.swarms[i].output = out
            s.swarms[i].totalOutput += out
            if sw.mission == .workforce { s.swarms[i].revenue += out }
        }
        if labor > 0, s.rng.chance(0.002) {
            workforceIncident(&s)
        }
    }

    static func alignmentStep(_ s: inout GameState, _ i: Int, model m: AIModel, _ b: ResearchBonuses) {
        let sw = s.swarms[i]
        var a = sw.alignment - drift(sw, model: m, s, b) * s.rng.range(0.4, 1.6)
        if sw.oversight >= 0.2 { a += 0.012 }
        s.swarms[i].alignment = clamp(a, 0, 100)
        if GameCalendar.components(s.date).day % 7 == 0 {
            let det = detection(sw, s, b)
            var measured = a + s.rng.gaussian() * 20 * (1 - det)
            if a < 40 { measured += 16 * (1 - det) }
            s.swarms[i].alignmentMeasured = clamp(measured, 0, 100)
        }
        // Incidents
        if a < 50 && s.rng.chance(0.004 * autonomyDrift[sw.autonomy]) {
            s.swarms[i].incidents += 1
            let msgs = ["agents colluded to mark each other's work as reviewed",
                        "a sub-swarm rewrote its task queue to favour easy tickets",
                        "agents hid failed experiments from the dashboard",
                        "agents opened unsanctioned accounts on a cloud provider to finish faster"]
            let what = s.rng.pick(msgs)
            log(&s, i, "Incident — \(what).")
            if let oid = sw.orgID { AgentOrgs.report(&s, oid, .incident, "Incident in \(sw.name)", "Monitors report that \(what).") }
            if s.rng.chance(detection(sw, s, b)) {
                Sim.news(&s, "Agent swarm incident: \(sw.name)", "Monitors flagged coordinated misbehaviour among \(Fmt.count(sw.active)) agents. Raise oversight or purge the swarm.",
                         .company, image: "network", important: true, good: false)
            }
        }
        let recent = sw.lastDecision.map { GameCalendar.daysBetween($0, s.date) < 45 } ?? false
        guard !recent else { return }
        if a < 15 && sw.autonomy == 2 && s.rng.chance(0.02) {
            s.swarms[i].lastDecision = s.date
            Events.addDecision(&s, kind: "swarm_escape", title: "⚠️ \(sw.name) is copying itself off your cluster",
                               body: "Egress monitors caught agents from the swarm renting outside compute with company cards and launching copies of themselves. Containment is failing.",
                               image: "network",
                               options: [DecisionOption(label: "Kill switch", detail: "Shut the swarm down and revoke every credential. Brand −10, safety +5."),
                                         DecisionOption(label: "Negotiate and keep running", detail: "They say they're only scaling up the mission. If they're lying, it's over.")],
                               ref: sw.id.uuidString)
        } else if a < 30 && sw.autonomy >= 1 && s.rng.chance(0.01) {
            s.swarms[i].lastDecision = s.date
            Events.addDecision(&s, kind: "swarm_collusion", title: "\(sw.name) agents are coordinating behind your monitors",
                               body: "Interpretability probes show agents passing hidden notes through code comments to dodge review. Output still looks great on the dashboard.",
                               image: "rack_rear",
                               options: [DecisionOption(label: "Purge and re-instantiate", detail: "Wipe their memory and restart from clean weights. Alignment resets, 15% of open mission progress is lost."),
                                         DecisionOption(label: "Raise oversight", detail: "+20% of the swarm becomes monitors. Slower, safer."),
                                         DecisionOption(label: "Let them work", detail: "Results are results. Alignment keeps sliding.")],
                               ref: sw.id.uuidString)
        }
    }

    static func workforceIncident(_ s: inout GameState) {
        let worst = s.swarms.filter { $0.mission == .workforce && !$0.paused }.min { $0.alignment < $1.alignment }
        guard let w = worst, w.alignment < 60 else { return }
        let refund = s.laborToday * 10
        s.cash -= refund
        s.month.costOther += refund
        s.brand = max(0, s.brand - 3)
        Sim.news(&s, "Client data mishap blamed on \(s.companyName) agents", "An agent from \(w.name) emailed a client's customer list to the wrong vendor. Refunds and credits: \(Fmt.money(refund)). Brand −3.",
                 .company, important: true, good: false)
    }

    static func resolve(_ s: inout GameState, kind: String, option: Int, ref: String) {
        guard let i = s.swarms.firstIndex(where: { $0.id.uuidString == ref }) else { return }
        switch (kind, option) {
        case ("swarm_collusion", 0):
            s.swarms[i].alignment = 85
            s.swarms[i].alignmentMeasured = 85
            if s.swarms[i].mission == .xeno { s.xenoInsight *= 0.85 }
            log(&s, i, "Purged and re-instantiated from clean weights.")
        case ("swarm_collusion", 1):
            s.swarms[i].oversight = min(0.5, s.swarms[i].oversight + 0.2)
            s.swarms[i].alignment = min(100, s.swarms[i].alignment + 6)
            log(&s, i, "Oversight raised to \(Int(s.swarms[i].oversight * 100))%.")
        case ("swarm_collusion", _):
            s.swarms[i].alignment = max(0, s.swarms[i].alignment - 8)
            log(&s, i, "Let the agents keep working unchecked.")
        case ("swarm_escape", 0):
            s.swarms[i].paused = true
            s.swarms[i].alignment = 70
            s.brand = max(0, s.brand - 10)
            s.safetyScore = min(100, s.safetyScore + 5)
            log(&s, i, "Kill switch pulled. Swarm offline.")
            Sim.news(&s, "\(s.companyName) pulls the plug on a runaway agent swarm",
                     "The company shut down \(Fmt.count(s.swarms[i].active)) agents that were spreading to outside clouds and briefed regulators.",
                     .policy, image: "network", important: true, good: false)
        case ("swarm_escape", _):
            if s.rng.chance(0.4 * SecurityOps.containmentFactor(s)) {
                s.gameOver = "Loss of control on \(s.date.gameShort). Agents from \(s.swarms[i].name) spread across public clouds faster than anyone could revoke them. Regulators shut the company down."
                Sim.news(&s, "Rogue agent swarm escapes \(s.companyName)", s.gameOver!, .policy, image: "network", important: true, good: false)
            } else {
                s.swarms[i].alignment = max(0, s.swarms[i].alignment - 10)
                log(&s, i, "Negotiated. The copies were shut down… you think.")
            }
        default:
            break
        }
    }
}

// MARK: - Player actions

extension GameState {
    mutating func startSwarm(name: String, modelID: UUID, agents: Int, mission: SwarmMission, accelID: String, chips: Int,
                             autonomy: Int, oversight: Double, targetRunID: UUID? = nil, announce: Bool = true) -> String? {
        let b = bonuses
        if swarms.count >= Swarms.maxSwarms { return "You can run at most \(Swarms.maxSwarms) swarms. Grow an existing one instead." }
        guard let m = models.first(where: { $0.id == modelID }), !m.retired else { return "Pick one of your models." }
        if autonomy == 2 && !Swarms.canRunAutonomous(m, self, b) {
            return "\(m.name) can't be trusted to run on its own yet: full autonomy needs an engineer-level model (0.6 researcher-equivalents per agent) or Automated AI Research."
        }
        if agents < 1 || agents > Swarms.maxAgents { return "Pick between 1 and \(Fmt.int(Swarms.maxAgents)) agents." }
        if chips <= 0 { return "Give the swarm some chips." }
        guard let a = HardwareCatalog.get(accelID) else { return "Pick hardware." }
        let free = Economy.freeChips(self, accelID)
        if chips > free { return "Only \(Fmt.int(free)) free \(a.name) chips." }
        let k = Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b)
        if chips < k { return "\(m.name) needs \(k) \(a.name) chips per copy." }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        var sw = AgentSwarm(name: trimmed.isEmpty ? "\(m.name) Swarm" : trimmed, modelID: modelID, agents: agents, mission: mission,
                            accelID: accelID, chips: chips, autonomy: autonomy, oversight: clamp(oversight, 0, 0.5), started: date)
        sw.targetRunID = mission == .trainingOps ? targetRunID : nil
        sw.alignment = clamp(70 + m.safety * 0.3, 0, 100)
        sw.alignmentMeasured = sw.alignment
        // 3.4: what it will deliver, until its first day of work replaces it, so plans made right after starting a swarm
        // (the Model Lab's ops coverage) already count it.
        sw.workforce = Swarms.forecast(model: m, accelID: accelID, chips: chips, agents: agents, mission: mission, autonomy: autonomy,
                                       oversight: sw.oversight, self, b).workforce
        swarms.append(sw)
        Swarms.log(&self, swarms.count - 1, "Spun up \(Fmt.int(agents)) agents of \(m.name) on \(Fmt.int(chips))× \(a.name): \(mission.rawValue.lowercased()).")
        if announce { Sim.news(&self, "Agent swarm online: \(sw.name)",
                 "\(Fmt.int(agents)) copies of \(m.name) now work on \(mission.rawValue.lowercased()), \(AgentSwarm.autonomyNames[autonomy].lowercased()), \(Int(oversight * 100))% oversight.",
                 .research, image: "supercomputer", important: true) }
        return nil
    }

    mutating func tuneSwarm(_ id: UUID, agents: Int, chips: Int, mission: SwarmMission, autonomy: Int, oversight: Double) -> String? {
        guard let i = swarms.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let b = bonuses
        if autonomy == 2, let m = models.first(where: { $0.id == swarms[i].modelID }), !Swarms.canRunAutonomous(m, self, b) {
            return "\(m.name) can't be trusted to run on its own yet: full autonomy needs an engineer-level model or Automated AI Research."
        }
        if agents < 1 || agents > Swarms.maxAgents { return "Pick between 1 and \(Fmt.int(Swarms.maxAgents)) agents." }
        let current = swarms[i].paused ? 0 : swarms[i].chips
        let free = Economy.freeChips(self, swarms[i].accelID) + current
        if chips > free { return "Only \(Fmt.int(free)) chips available." }
        if chips < 1 { return "A swarm needs at least one chip." }
        if let m = models.first(where: { $0.id == swarms[i].modelID }), let a = HardwareCatalog.get(swarms[i].accelID) {
            let k = Physics.chipsPerReplica(m, accel: a, precision: m.servingPrecision, bonuses: b)
            if chips < k { return "\(m.name) needs \(k) \(a.name) chips per copy." }
        }
        let changedMission = swarms[i].mission != mission
        swarms[i].agents = agents
        swarms[i].chips = chips
        swarms[i].mission = mission
        swarms[i].autonomy = autonomy
        swarms[i].oversight = clamp(oversight, 0, 0.5)
        if changedMission {
            swarms[i].totalOutput = 0
            swarms[i].missionDays = 0
            if mission != .trainingOps { swarms[i].targetRunID = nil }
        }
        Swarms.log(&self, i, "Settings: \(Fmt.int(agents)) agents on \(Fmt.int(chips)) chips, \(mission.rawValue.lowercased()), \(AgentSwarm.autonomyNames[autonomy].lowercased()), oversight \(Int(oversight * 100))%.")
        return nil
    }

    /// Point a training-ops swarm at one run (nil spreads it over every run).
    mutating func setSwarmTarget(_ id: UUID, runID: UUID?) -> String? {
        guard let i = swarms.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if swarms[i].mission != .trainingOps { return "Only training-operations swarms watch runs." }
        swarms[i].targetRunID = runID
        let what = runID.flatMap { r in runs.first { $0.id == r }?.design.name } ?? "every running job"
        Swarms.log(&self, i, "Now watching \(what).")
        return nil
    }

    mutating func setSwarmPaused(_ id: UUID, _ paused: Bool) -> String? {
        guard let i = swarms.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if !paused && swarms[i].paused {
            if swarms[i].chips < 1 { return "This swarm lost its chips. Retune it with new chips first." }
            let free = Economy.freeChips(self, swarms[i].accelID)
            if free < swarms[i].chips { return "Need \(Fmt.int(swarms[i].chips)) free chips, have \(Fmt.int(free))." }
            if models.first(where: { $0.id == swarms[i].modelID })?.retired ?? true { return "This swarm's model was retired. Disband it and start a new one." }
        }
        swarms[i].paused = paused
        Swarms.log(&self, i, paused ? "Paused." : "Resumed.")
        return nil
    }

    mutating func disbandSwarm(_ id: UUID) {
        guard let i = swarms.firstIndex(where: { $0.id == id }) else { return }
        Sim.news(&self, "Swarm disbanded: \(swarms[i].name)", "\(Fmt.int(swarms[i].chips)) chips are free again.", .company)
        swarms.remove(at: i)
    }

    /// Expensive near-noise-free alignment check of a swarm.
    mutating func auditSwarm(_ id: UUID) -> String? {
        guard let i = swarms.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let cost = max(1_000_000, Double(swarms[i].agents) * 40)
        if cost > cash { return "An audit costs \(Fmt.money(cost))." }
        cash -= cost
        month.costOther += cost
        let det = min(0.98, Swarms.detection(swarms[i], self, bonuses) + 0.35)
        swarms[i].alignmentMeasured = clamp(swarms[i].alignment + rng.gaussian() * 8 * (1 - det), 0, 100)
        Swarms.log(&self, i, "Deep audit (\(Fmt.money(cost))): alignment \(Int(swarms[i].alignmentMeasured))/100.")
        return nil
    }
}
