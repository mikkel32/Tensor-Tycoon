import SwiftUI

/// 3.6: AI Organisations (the old Agent Swarms screen). Organisations of agent teams, plus any stand-alone swarms.
struct SwarmView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let b = store.derived.bonuses
        let running = s.swarms.filter { !$0.paused }
        let active = running.reduce(0) { $0 + $1.active }
        let workforce = running.reduce(0) { $0 + $1.workforce }
        let solo = s.swarms.filter { $0.orgID == nil }
        let spend = s.orgs.reduce(0) { $0 + $1.spendToday }
        let best = s.models.filter { !$0.retired }.max { Swarms.quality($0, s) < Swarms.quality($1, s) }
        Page(title: "AI Organisations", subtitle: "Build organisations out of agent teams: specialists running your models, supervisors to coordinate them, a compute and money budget, verification and human oversight. What they produce depends on the models' skills in the domains the work needs — and a billion agents never do a billion agents' work.", screen: .swarms) {
            HeroBanner(image: "dc_rows", height: 160) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your AI organisations").font(.title.weight(.bold))
                        Text(active > 0 ? "\(s.orgs.count) organisation\(s.orgs.count == 1 ? "" : "s") · \(Fmt.count(active)) agents · worth \(Fmt.count(workforce)) human researchers"
                                        : "Your own models, put to work. No agents running yet.")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    if let best {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Best agent: \(best.name)").font(.caption).opacity(0.8)
                            Text(Swarms.tier(Swarms.quality(best, s))).font(TypeRamp.bannerMetric)
                            Text("works \(Swarms.horizon(best)) on its own").font(.caption).opacity(0.8)
                        }
                    }
                }
            }
            KPIRow(minWidth: 190) {
                StatTile(title: "Agents running", value: Fmt.count(active), detail: "\(s.orgs.count) organisations · \(s.swarms.count) of \(Swarms.maxSwarms) teams", symbol: "person.3.sequence.fill", tint: .indigo)
                StatTile(title: "Researcher-equivalents", value: Fmt.count(workforce), detail: "After scaling, overhead and verification", symbol: "brain.head.profile", tint: .purple)
                StatTile(title: "Agent research", value: "\(Fmt.count(s.swarmRPToday)) RP/day", detail: s.orgTechniques > 0 ? "\(s.orgTechniques) techniques published" : "Added to your research queue", symbol: "lightbulb.max.fill", tint: .pink)
                StatTile(title: "Digital workforce", value: "\(Fmt.money(s.laborToday * 365))/yr", detail: "Cap \(Fmt.money(Swarms.laborCap(s) * 365))/yr at your brand", symbol: "briefcase.fill", tint: .green)
                StatTile(title: "Mission levels", value: "\(Int(s.swarmOps * 100))% · \(Int(s.swarmSilicon * 100))% · \(Int(s.swarmSafety * 100))%",
                         detail: "Training ops · chip design · alignment", symbol: "dial.medium.fill", tint: .teal)
                StatTile(title: "Tools & equipment", value: "\(Fmt.money(spend * 30.4))/mo", detail: "Organisation budgets being spent", symbol: "wrench.and.screwdriver.fill", tint: .orange)
            }
            if !b.has(.toolUse) {
                Label("No tool-use research yet: agents run through a prompt-only scaffold at about 60% of their output. Research Tool Use & Function Calling and train it into a model to unlock their full value.",
                      systemImage: "info.circle.fill")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if s.orgs.contains(where: { $0.kind == .xeno }) || s.swarms.contains(where: { $0.mission == .xeno }) || s.xenoInsight > 0 {
                XenoProgressCard(state: s)
            }
            FoundOrgCard(state: s)
            ForEach(s.orgs) { o in OrgCard(org: o, state: s) }
            if !solo.isEmpty {
                Card {
                    CardHeader(title: "Stand-alone swarms", symbol: "person.3.sequence",
                               subtitle: "Swarms from before organisations. They keep working exactly as they did; turn one into an organisation to add supervisors, verification and a budget.") { HelpButton(term: .swarms) }
                }
                ForEach(solo) { sw in SwarmCard(swarm: sw, state: s) }
            }
        }
    }
}

// MARK: - Dashboard

/// The dashboard's AI-organisations card: every organisation with its output and what it is doing for the company,
/// plus stand-alone swarms and the alien search.
struct AgentOrgsDashboardCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader(title: "AI organisations", symbol: "person.3.sequence.fill") {
                HelpButton(term: .swarms)
                Button("Organisations") { store.open(.swarms) }.buttonStyle(.link)
            }
            ForEach(s.orgs) { o in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: o.kind.symbol).foregroundStyle(.secondary).frame(width: 18)
                        Text(o.name).font(.callout.weight(.semibold)).lineLimit(1)
                        Text("\(Fmt.count(o.agents)) agents · \(Fmt.count(o.workforce)) researcher-eq").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        let a = AgentOrgViews.minAlignment(o, s)
                        Label("\(Int(a))", systemImage: "shield.lefthalf.filled").font(.caption)
                            .foregroundStyle(AgentOrgViews.alignColor(a))
                            .help("Lowest measured alignment among its teams, 0–100")
                    }
                    Text(AgentOrgs.impact(o.kind, s)).font(.caption).foregroundStyle(.secondary).lineLimit(1).padding(.leading, 26)
                }
            }
            ForEach(s.swarms.filter { $0.orgID == nil }) { sw in
                HStack {
                    Image(systemName: sw.mission.symbol).foregroundStyle(.secondary).frame(width: 18)
                    Text(sw.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text("\(Fmt.count(sw.active)) agents · stand-alone").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    let a = sw.alignmentMeasured
                    Label("\(Int(a))", systemImage: "shield.lefthalf.filled").font(.caption).foregroundStyle(AgentOrgViews.alignColor(a))
                }
            }
            if s.xenoInsightToday > 0 || s.xenoInsight > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Alien architecture #\(s.alienArchs.count + 1): \(Fmt.pct(s.xenoInsight / Xeno.insightNeeded(s), decimals: 0))").font(.caption.weight(.semibold))
                    Meter(value: s.xenoInsight / Xeno.insightNeeded(s), tint: .purple, height: 6)
                }
            }
        }
    }
}

enum AgentOrgViews {
    static func alignColor(_ a: Double) -> Color { a >= 70 ? .green : (a >= 45 ? .yellow : .red) }

    static func minAlignment(_ o: AgentOrg, _ s: GameState) -> Double {
        s.swarms.filter { $0.orgID == o.id }.map(\.alignmentMeasured).min() ?? 100
    }

    static func historySymbol(_ k: OrgReport.Kind) -> String {
        switch k {
        case .report: "doc.text.fill"
        case .incident: "exclamationmark.triangle.fill"
        case .milestone: "star.fill"
        case .change: "slider.horizontal.3"
        }
    }

    static func historyColor(_ k: OrgReport.Kind) -> Color {
        switch k {
        case .report: .blue
        case .incident: .red
        case .milestone: .orange
        case .change: .secondary
        }
    }
}

// MARK: - Agent profile

/// What one agent of a model is like in an organisation of a kind: tier, horizon, domain fit and value.
private struct AgentProfile: View {
    let model: AIModel
    let state: GameState
    let kind: SwarmMission

    var body: some View {
        let s = state
        let fit = AgentOrgs.fit(model, kind, s)
        let edge = AgentOrgs.domainEdge(model, kind, s)
        let q = Swarms.quality(model, s) * fit
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Swarms.tier(Swarms.quality(model, s))).font(.headline)
                Text("Works \(Swarms.horizon(model)) on its own · \(Fmt.pct(AgentOrgs.errorRate(model), decimals: 0)) error rate").font(.caption).foregroundStyle(.secondary)
            }
            Divider().frame(height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Fmt.trim(q, q < 0.1 ? 3 : 2)) researcher-eq per agent").font(.callout.weight(.semibold).monospacedDigit())
                Text(abs(fit - 1) < 0.05 ? "A typical fit for this work" : "\(fit > 1 ? "Strong" : "Weak") in \(kind.domainMix.map { $0.0.short.lowercased() }.joined(separator: ", ")) (\(edge >= 0 ? "+" : "")\(Fmt.trim(edge, 1)) points): \(Fmt.trim(fit, 2))×")
                    .font(.caption).foregroundStyle(fit >= 1 ? .green : .orange)
            }
            Spacer()
            if !model.design.toolUse {
                Pill(text: "No tool use: 60%", color: .orange, symbol: "wrench.adjustable")
            }
        }
        .padding(10)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

struct XenoProgressCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let needed = Xeno.insightNeeded(s)
        let rate = s.xenoInsightToday
        let left = max(0, needed - s.xenoInsight)
        Card {
            CardHeader(title: "Alien architecture search", symbol: "atom",
                       subtitle: XenoScience.discoveries(s) == 0 ? "Nobody has found one. Point an alien architecture lab (or a self-improvement run) at it." : "\(XenoScience.discoveries(s)) found — next: \(XenoScience.nextKind(s).title.lowercased()), 2.2× the insight of the last") {
                if store.screen != .xeno {
                    Button("Alien Tech") { store.open(.xeno) }.buttonStyle(.link)
                }
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Meter(value: s.xenoInsight / max(1, needed), tint: .purple, height: 10)
                    Text("\(Fmt.count(s.xenoInsight)) of \(Fmt.count(needed)) insight for discovery #\(XenoScience.discoveries(s) + 1)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(rate > 0 ? "\(Fmt.trim(rate, 1))/day" : "Idle").font(.callout.monospacedDigit().weight(.semibold))
                    Text(rate > 0 ? "~\(Fmt.days(left / rate)) to go" : "No search running").font(.caption).foregroundStyle(.secondary)
                }
                .frame(width: 150, alignment: .trailing)
            }
        }
    }
}

// MARK: - Found an organisation

private struct FoundOrgCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var name = ""
    @State private var objective = ""
    @State private var kind: SwarmMission = .software
    @State private var modelID: UUID? = nil
    @State private var agentsLog = 3.0
    @State private var accelID = ""
    @State private var chips = 1
    @State private var autonomy = 1
    @State private var oversight = 0.1
    @State private var verification = 0.1
    @State private var funded = true

    private var agents: Int { Int(pow(10, agentsLog).rounded()) }

    var body: some View {
        let s = state
        let models = s.models.filter { !$0.retired }.sorted { Swarms.agenticX($0) > Swarms.agenticX($1) }
        Card {
            CardHeader(title: "Found an organisation", symbol: "plus.circle.fill", subtitle: "Pick the work, the model its first team runs and the chips behind it. Add supervisors and more teams afterwards.") { HelpButton(term: .swarms) }
            if models.isEmpty {
                NextStep("Train a model first. Agents are copies of one of your models — the better its agentic skill, the more each agent is worth.", action: "Open Model Lab", screen: .lab)
            } else if s.orgs.count >= AgentOrgs.maxOrgs {
                Text("You're running the maximum of \(AgentOrgs.maxOrgs) organisations. Grow an existing one.").foregroundStyle(.secondary)
            } else if s.swarms.count >= Swarms.maxSwarms {
                Text("You're running the maximum of \(Swarms.maxSwarms) teams. Disband one first.").foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        KindGrid(state: s, model: models.first { $0.id == modelID }, kind: $kind)
                        HStack {
                            TextField(kind.orgTitle, text: $name).textFieldStyle(.roundedBorder).frame(width: 260)
                            TextField(kind.defaultObjective, text: $objective).textFieldStyle(.roundedBorder)
                        }
                        Picker("Model", selection: $modelID) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(models) { m in
                                Text("\(m.name) · \(Swarms.tier(Swarms.quality(m, s))) · \(Fmt.trim(AgentOrgs.perAgent(m, kind, s), 2)) researcher/agent here").tag(UUID?.some(m.id))
                            }
                        }
                        if let m = models.first(where: { $0.id == modelID }) {
                            AgentProfile(model: m, state: s, kind: kind)
                        }
                        TeamSizeControls(state: s, agentsLog: $agentsLog, accelID: $accelID, chips: $chips)
                        OversightControls(state: s, models: models.filter { $0.id == modelID }, autonomy: $autonomy, oversight: $oversight, verification: $verification)
                        Toggle("Fund tools and equipment fully", isOn: $funded)
                            .help("Each organisation needs money for tools, data, lab time and equipment. Without it, output falls (up to 30% for labs and fabs).")
                    }
                    .frame(maxWidth: .infinity)
                    forecastPanel(s, models)
                        .frame(width: 330)
                }
            }
        }
        .onAppear {
            if modelID == nil { modelID = models.first?.id }
            let d = store.derived
            if accelID.isEmpty, let p = d.pools.max(by: { Double($0.free) * $0.accel.best < Double($1.free) * $1.accel.best }) {
                accelID = p.accel.id
                chips = max(1, p.free)
            }
        }
    }

    private func probe(_ s: GameState, _ m: AIModel) -> (AgentOrg, AgentSwarm) {
        var o = AgentOrg(name: "", kind: kind, objective: "", founded: s.date, autonomy: autonomy, oversight: oversight, verification: verification)
        var sw = AgentSwarm(name: "", modelID: m.id, agents: agents, mission: kind, accelID: accelID, chips: chips, autonomy: autonomy, oversight: oversight, started: s.date)
        sw.orgID = o.id
        sw.alignment = clamp(70 + m.safety * 0.3, 0, 100)
        o.budgetMonthly = 1e15
        return (o, sw)
    }

    @ViewBuilder
    private func forecastPanel(_ s: GameState, _ models: [AIModel]) -> some View {
        let b = store.derived.bonuses
        VStack(alignment: .leading, spacing: 8) {
            Text("Forecast").font(.headline)
            if let m = models.first(where: { $0.id == modelID }), !accelID.isEmpty {
                let (o, sw) = probe(s, m)
                let e = AgentOrgs.evaluate(o, members: [sw], s, b)
                let cost = HardwareCatalog.get(accelID).map { Economy.chipDailyCost($0, count: chips, state: s) } ?? 0
                let need = Swarms.chipsNeeded(m, accelID: accelID, agents: agents, s, b)
                let free = store.derived.free(accelID)
                SpecRow(label: "Chips for \(Fmt.int(agents)) agents", value: Fmt.int(need))
                SpecRow(label: "Agents these chips run", value: Fmt.count(e.specialists))
                SpecRow(label: "Researcher-equivalents", value: Fmt.count(e.workforce))
                SpecRow(label: "Work right first time", value: Fmt.pct(e.accuracy, decimals: 1))
                SpecRow(label: "Compute cost", value: "\(Fmt.money(cost * 30.4))/mo")
                SpecRow(label: "Tools budget", value: funded ? "\(Fmt.money(e.needDaily * 30.4))/mo" : "None (−\(Fmt.pct(kind.toolCost.weight, decimals: 0)))")
                if let goal = AgentOrgs.goalOptions(kind, s).first {
                    SpecRow(label: "First objective (12 months)", value: goal.title)
                }
                if need != chips {
                    Button(need <= free ? "Use \(Fmt.int(need)) chips" : "Use all \(Fmt.int(free)) free chips") { chips = max(1, min(free, need)) }
                        .buttonStyle(.link)
                }
                if Swarms.quality(m, s) < kind.minQuality {
                    Label("Needs \(Swarms.tier(kind.minQuality).lowercased())-level agents.", systemImage: "lock.fill").font(.caption).foregroundStyle(.orange)
                }
                if autonomy == 2 && oversight < 0.1 {
                    Label("Millions of unwatched autonomous agents is how containment fails.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
                Button {
                    let budget = funded ? (e.needDaily * 30.4 / 1e4).rounded(.up) * 1e4 : 0
                    store.act("Organisation founded") {
                        $0.foundOrg(kind: kind, name: name, objective: objective, modelID: m.id, accelID: accelID, chips: chips, agents: agents,
                                    autonomy: autonomy, oversight: oversight, verification: verification, budgetMonthly: budget)
                    }
                } label: {
                    Label("Found with \(Fmt.int(agents)) agents", systemImage: "building.2.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("Pick a model and hardware.").font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

/// The fourteen kinds of organisation, locked ones greyed out with the tier they need.
private struct KindGrid: View {
    let state: GameState
    let model: AIModel?
    @Binding var kind: SwarmMission

    var body: some View {
        let s = state
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(SwarmMission.allCases) { k in
                let open = AgentOrgs.canFound(k, s)
                let value = model.map { AgentOrgs.perAgent($0, k, s) }
                Button { kind = k } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: open ? k.symbol : "lock.fill").foregroundStyle(kind == k ? Color.accentColor : .secondary)
                            Text(k.orgTitle).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Text(k.blurb).font(.caption2).foregroundStyle(.secondary).lineLimit(3, reservesSpace: true)
                        if !open {
                            Text("Needs \(Swarms.tier(k.minQuality).lowercased())-level agents").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                        } else if let value {
                            Text("\(Fmt.trim(value, value < 0.1 ? 3 : 2)) per agent").font(.caption2.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(kind == k ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(kind == k ? Color.accentColor : .clear, lineWidth: 1.5))
                    .contentShape(.rect)
                    .opacity(open ? 1 : 0.55)
                }
                .buttonStyle(.plain)
                .disabled(!open)
            }
        }
    }
}

/// Agents, hardware and chips for a team.
private struct TeamSizeControls: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @Binding var agentsLog: Double
    @Binding var accelID: String
    @Binding var chips: Int

    var body: some View {
        let d = store.derived
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Agents")
                Slider(value: $agentsLog, in: 1...9)
                Text(Fmt.int(Int(pow(10, agentsLog).rounded()))).font(.callout.monospacedDigit().weight(.semibold)).frame(width: 120, alignment: .trailing)
            }
            HStack(spacing: 6) {
                ForEach([2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0], id: \.self) { v in
                    Button(Fmt.count(pow(10, v), decimals: 0)) { agentsLog = v }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            HStack {
                Picker("Hardware", selection: $accelID) {
                    Text("Choose…").tag("")
                    ForEach(d.pools) { p in Text("\(p.accel.name) — \(Fmt.int(p.free)) free").tag(p.accel.id) }
                }
                QuantityPicker(value: $chips, range: 1...max(1, d.free(accelID)))
            }
        }
    }
}

/// Human oversight, alignment monitors and verification.
private struct OversightControls: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let models: [AIModel]
    @Binding var autonomy: Int
    @Binding var oversight: Double
    @Binding var verification: Double

    var body: some View {
        let b = store.derived.bonuses
        let autonomousOK = !models.isEmpty && models.allSatisfy { Swarms.canRunAutonomous($0, state, b) }
        VStack(alignment: .leading, spacing: 8) {
            Picker("Human oversight", selection: $autonomy) {
                ForEach(0..<3) { i in Text(AgentOrgs.oversightNames[i]).tag(i).disabled(i == 2 && !autonomousOK) }
            }
            .pickerStyle(.segmented)
            Text("More autonomy works faster (\(Fmt.trim(Swarms.autonomyOutput[autonomy], 2))× output) but drifts out of alignment faster (\(Fmt.trim(Swarms.autonomyDrift[autonomy], 1))× drift)."
                 + (autonomousOK ? "" : " Full autonomy opens with an engineer-level model or Automated AI Research."))
                .font(.caption2).foregroundStyle(.secondary)
            HStack {
                Text("Monitors")
                Slider(value: $oversight, in: 0...0.5, step: 0.05)
                Text("\(Int(oversight * 100))% watch for misalignment").font(.callout.monospacedDigit()).frame(width: 210, alignment: .trailing)
            }
            HStack {
                Text("Verification")
                Slider(value: $verification, in: 0...0.5, step: 0.05)
                Text("\(Int(verification * 100))% of time re-checking work").font(.callout.monospacedDigit()).frame(width: 210, alignment: .trailing)
            }
        }
    }
}

// MARK: - An organisation

private struct OrgCard: View {
    @Environment(GameStore.self) private var store
    let org: AgentOrg
    let state: GameState
    @State private var panel: Panel? = nil
    @State private var confirmDissolve = false
    @State private var showWhy = false

    enum Panel { case settings, addTeam, history }

    var body: some View {
        let o = org
        let s = state
        let e = AgentOrgs.evaluate(o, s, store.derived.bonuses)
        let teams = AgentOrgs.members(o, s)
        let paused = !teams.isEmpty && teams.allSatisfy(\.paused)
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: o.kind.symbol).font(.title2).foregroundStyle(Color.accentColor)
                        Text(o.name).font(.title2.weight(.bold)).lineLimit(1)
                        Pill(text: teams.isEmpty ? "No teams" : (paused ? "Paused" : "Running"), color: paused || teams.isEmpty ? .orange : .green)
                        Pill(text: o.kind.orgTitle, color: .purple)
                        Pill(text: AgentOrgs.oversightNames[o.autonomy], color: o.autonomy == 2 ? .red : .secondary)
                        if o.incidents > 0 { Pill(text: "\(o.incidents) incident\(o.incidents == 1 ? "" : "s")", color: .red, symbol: "exclamationmark.triangle.fill") }
                    }
                    Text("Objective: \(o.objective)").font(.callout).foregroundStyle(.secondary)
                    OrgGoalLine(org: o, state: s)
                    Text(orgLine(o, teams: teams.count, s)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack {
                    if paused {
                        Button("Resume", systemImage: "play.fill") { store.act { $0.setOrgPaused(o.id, false) } }.buttonStyle(.borderedProminent)
                    } else {
                        Button("Pause", systemImage: "pause.fill") { store.act { $0.setOrgPaused(o.id, true) } }
                    }
                    Button("Add team", systemImage: "person.badge.plus") { panel = panel == .addTeam ? nil : .addTeam }
                    Button("Settings", systemImage: "slider.horizontal.3") { panel = panel == .settings ? nil : .settings }
                    Button("History", systemImage: "clock.arrow.circlepath") { panel = panel == .history ? nil : .history }
                    Button("Dissolve", systemImage: "xmark.circle", role: .destructive) { confirmDissolve = true }
                }
            }
            EqualColumns(minWidth: 120, spacing: 10, maxColumns: 6) {
                OrgStat(label: "Agents", value: "\(Fmt.count(e.specialists + e.supervisors))", symbol: "person.3.fill", tint: .indigo)
                OrgStat(label: "Throughput", value: "\(Fmt.count(e.workforce)) r-eq", symbol: "speedometer", tint: .purple)
                OrgStat(label: "Right first time", value: e.effective > 0 ? Fmt.pct(e.accuracy, decimals: 1) : "—", symbol: "checkmark.seal.fill", tint: .green)
                OrgStat(label: "Compute", value: "\(Fmt.count(Double(e.chips))) chips", symbol: "cpu", tint: .blue)
                OrgStat(label: "Compute cost", value: "\(Fmt.money(e.computeDaily * 30.4))/mo", symbol: "bolt.fill", tint: .orange)
                OrgStat(label: "Budget", value: "\(Fmt.money(e.spendDaily * 30.4)) of \(Fmt.money(o.budgetMonthly))", symbol: "banknote.fill", tint: e.tools < 0.999 ? .orange : .mint)
            }
            OrgChart(org: o, eval: e, teams: teams, state: s)
            ActivitiesView(org: o, eval: e, state: s)
            DisclosureGroup(isExpanded: $showWhy) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(AgentOrgs.explanation(o, e, s).enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.label).font(.caption.weight(.semibold)).frame(width: 150, alignment: .leading)
                            Text(row.value).font(.caption.monospacedDigit().weight(.semibold)).frame(width: 140, alignment: .leading)
                            Text(row.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Output = per agent × working agents^exponent × quality × (1 − overhead) × tools.").font(.caption2).foregroundStyle(.secondary).padding(.top, 2)
                }
                .padding(.top, 4)
            } label: {
                Label("Why \(Fmt.count(e.workforce)) researcher-equivalents?", systemImage: "questionmark.circle").font(.callout.weight(.semibold))
            }
            if panel != nil { Divider() }
            switch panel {
            case .settings:
                OrgSettings(org: o, state: s, eval: e) { panel = nil }
            case .addTeam:
                AddTeamPanel(org: o, state: s) { panel = nil }
            case .history:
                OrgHistory(org: o, limit: 30)
            case nil:
                OrgHistory(org: o, limit: 3)
            }
        }
        .confirmationDialog("Dissolve \(o.name)? Every team is disbanded and its chips become idle.", isPresented: $confirmDissolve) {
            Button("Dissolve", role: .destructive) { store.mutate { $0.dissolveOrg(o.id) } }
        }
    }
}

extension OrgCard {
    func orgLine(_ o: AgentOrg, teams: Int, _ s: GameState) -> String {
        var t = "\(teams) team" + (teams == 1 ? "" : "s")
        t += " · founded \(o.founded.gameShort) · " + AgentOrgs.impact(o.kind, s)
        t += " · \(Fmt.money(o.totalSpend)) spent on tools so far"
        return t
    }
}

private struct OrgStat: View {
    let label: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        MetricTile(label: label, value: value, symbol: symbol, tint: tint)
    }
}

/// Supervisors on top, specialist teams below.
private struct OrgChart: View {
    let org: AgentOrg
    let eval: AgentOrgs.Eval
    let teams: [AgentSwarm]
    let state: GameState

    var body: some View {
        let sups = teams.filter { $0.role == .supervisors }
        let specs = teams.filter { $0.role == .specialists }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Org chart").font(.headline)
                Spacer()
                Text("Supervision \(Fmt.pct(eval.supervision, decimals: 0)) · \(Fmt.pct(org.verification, decimals: 0)) verification · \(Fmt.pct(org.oversight, decimals: 0)) monitors")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if sups.isEmpty {
                Label("No supervisors: add a supervisor team of about \(Fmt.pct(AgentOrgs.supervisionTarget, decimals: 0)) of the specialists' size for better scaling, fewer errors and less drift.", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(sups) { sw in TeamBox(team: sw, eval: eval.teams.first { $0.id == sw.id }, state: state) }
                }
                Image(systemName: "arrow.down").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 8)], spacing: 8) {
                ForEach(specs) { sw in TeamBox(team: sw, eval: eval.teams.first { $0.id == sw.id }, state: state) }
            }
        }
    }
}

private struct TeamBox: View {
    @Environment(GameStore.self) private var store
    let team: AgentSwarm
    let eval: AgentOrgs.TeamEval?
    let state: GameState
    @State private var editing = false
    @State private var agentsLog = 3.0
    @State private var chips = 1
    @State private var confirmRemove = false

    var body: some View {
        let sw = team
        let s = state
        let model = s.models.first { $0.id == sw.modelID }
        let accel = HardwareCatalog.get(sw.accelID)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: sw.role.symbol).foregroundStyle(sw.role == .supervisors ? .orange : .accentColor)
                Text(sw.name).font(.callout.weight(.semibold)).lineLimit(1)
                Spacer()
                Label("\(Int(sw.alignmentMeasured))", systemImage: "shield.lefthalf.filled").font(.caption)
                    .foregroundStyle(AgentOrgViews.alignColor(sw.alignmentMeasured)).help("Measured alignment, 0–100")
            }
            Text("\(model?.name ?? "?") · \(Fmt.int(sw.chips))× \(accel?.name ?? "?")").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text("\(Fmt.count(sw.active)) of \(Fmt.count(Double(sw.agents))) agents running\(sw.paused ? " · paused" : "")").font(.caption.monospacedDigit())
                .foregroundStyle(sw.active + 0.5 < Double(sw.agents) ? .orange : .secondary)
            if let ev = eval {
                Text(sw.role == .supervisors ? "\(Fmt.trim(ev.perAgent, 2)) r-eq per agent · reviews and routes work"
                                             : "\(Fmt.trim(ev.perAgent, ev.perAgent < 0.1 ? 3 : 2)) r-eq/agent · fit \(Fmt.trim(ev.fit, 2))× · \(Fmt.pct(ev.share, decimals: 0)) of output")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Button(sw.paused ? "Resume" : "Pause") { store.act { $0.setSwarmPaused(sw.id, !sw.paused) } }
                Button("Resize") {
                    if !editing {
                        agentsLog = log10(Double(max(1, sw.agents)))
                        chips = sw.chips
                    }
                    editing.toggle()
                }
                Button("Audit") { store.act("Audit complete") { $0.auditSwarm(sw.id) } }.help("Expensive, accurate alignment check.")
                Button("Remove", role: .destructive) { confirmRemove = true }
            }
            .controlSize(.small)
            if editing {
                HStack {
                    Slider(value: $agentsLog, in: 1...9)
                    Text(Fmt.count(pow(10, agentsLog), decimals: 0)).font(.caption.monospacedDigit()).frame(width: 50)
                }
                HStack {
                    QuantityPicker(value: $chips, range: 1...max(1, store.derived.free(sw.accelID) + (sw.paused ? 0 : sw.chips)))
                    Button("Apply") {
                        store.act("Team resized") { $0.tuneOrgTeam(sw.id, agents: Int(pow(10, agentsLog).rounded()), chips: chips) }
                        editing = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.small)
                if let m = model {
                    let need = Swarms.chipsNeeded(m, accelID: sw.accelID, agents: Int(pow(10, agentsLog).rounded()), s, store.derived.bonuses)
                    Text("\(Fmt.int(need)) chips run that many agents.").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((sw.role == .supervisors ? Color.orange : Color.accentColor).opacity(0.07), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder((sw.role == .supervisors ? Color.orange : Color.accentColor).opacity(0.3), lineWidth: 1))
        .confirmationDialog("Remove \(sw.name)? Its chips become idle.", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { store.mutate { $0.disbandSwarm(sw.id) } }
        }
    }
}

/// 3.9: the organisation's measurable objective: where the number stands, the target, the deadline and how it ended.
private struct OrgGoalLine: View {
    let org: AgentOrg
    let state: GameState

    var body: some View {
        let o = org
        if let m = AgentOrgs.metric(o.goalKey), let line = AgentOrgs.goalLine(o, state) {
            let now = m.value(state)
            let span = o.goalTarget - o.goalStart
            let progress = span > 0 ? (now - o.goalStart) / span : 0
            let onTrack = AgentOrgs.goalOnTrack(o, state)
            let tone = Self.tone(o.goalStatus, onTrack: onTrack)
            HStack(spacing: 8) {
                Pill(Self.word(o.goalStatus, onTrack: onTrack), tone: tone)
                Text(Self.capitalised(line)).font(.caption).lineLimit(1)
                if o.goalStatus == 0 {
                    Meter(value: progress, tint: tone.color, height: 6).frame(width: 120)
                        .accessibilityLabel("Progress to the objective")
                }
            }
        }
    }
}

extension OrgGoalLine {
    static func tone(_ status: Int, onTrack: Bool) -> Tone {
        switch status {
        case 1: return .good
        case 2: return .bad
        default: return onTrack ? .info : .warning
        }
    }

    static func word(_ status: Int, onTrack: Bool) -> String {
        switch status {
        case 1: return "Met"
        case 2: return "Missed"
        default: return onTrack ? "On track" : "Behind"
        }
    }

    static func capitalised(_ line: String) -> String {
        guard let first = line.first else { return line }
        return String(first).uppercased() + String(line.dropFirst())
    }
}

/// Classes of work and how the effort is split between them.
private struct ActivitiesView: View {
    let org: AgentOrg
    let eval: AgentOrgs.Eval
    let state: GameState

    var body: some View {
        let acts = org.kind.activities
        VStack(alignment: .leading, spacing: 4) {
            Text("Work").font(.headline)
            if org.kind == .research && state.orgTechniques < AgentOrgs.techniqueCap(state) && eval.shares.count > 1 && eval.shares[1] > 0 {
                Text("Next technique: \(Fmt.pct(org.techProgress / AgentOrgs.techniqueCost(state.orgTechniques), decimals: 0)) of the way (\(state.orgTechniques) of \(AgentOrgs.techniqueCap(state)) published)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(acts.enumerated()), id: \.offset) { i, a in
                let share = i < eval.shares.count ? eval.shares[i] : 0
                let open = eval.bestQuality >= a.minQuality
                HStack(spacing: 8) {
                    Image(systemName: open ? (share >= 0.5 && acts.count > 1 ? "star.fill" : "circle.fill") : "lock.fill")
                        .font(.caption).foregroundStyle(open ? Color.accentColor : .secondary).frame(width: 16)
                    Text(a.name).font(.callout.weight(.semibold)).frame(width: 230, alignment: .leading)
                    if open {
                        Meter(value: share, tint: .purple, height: 6).frame(width: 120)
                        Text(Fmt.pct(share, decimals: 0)).font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                    } else {
                        Text("Unlocks with \(Swarms.tier(a.minQuality).lowercased())-level agents").font(.caption).foregroundStyle(Theme.warning).frame(width: 166, alignment: .leading)
                    }
                    Text(effectLine(a, index: i, open: open)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
}

extension ActivitiesView {
    /// What an activity does and, for the levelled ones, how far along it is.
    func effectLine(_ a: OrgActivity, index i: Int, open: Bool) -> String {
        guard open && (i > 0 || !AgentOrgs.classic.contains(org.kind)) else { return a.effect }
        let level = Fmt.pct(AgentOrgs.level(state, org.kind, i), decimals: 0)
        return a.effect + " · level \(level) (full at \(Fmt.count(a.full)) researcher-eq)"
    }
}

private struct OrgSettings: View {
    @Environment(GameStore.self) private var store
    let org: AgentOrg
    let state: GameState
    let eval: AgentOrgs.Eval
    let done: () -> Void
    @State private var name = ""
    @State private var objective = ""
    @State private var autonomy = 1
    @State private var oversight = 0.1
    @State private var verification = 0.1
    @State private var budgetLog = 6.0
    @State private var noBudget = false
    @State private var focus = 0
    @State private var loaded = false
    @State private var goalKey = ""
    @State private var goalTarget = 0.0
    @State private var goalMonths = 12

    var body: some View {
        let o = org
        let s = state
        let models = AgentOrgs.members(o, s).compactMap { sw in s.models.first { $0.id == sw.modelID } }
        let goals = AgentOrgs.goalOptions(o.kind, s)
        let goal = goals.first { $0.key == goalKey } ?? goals.first
        let open = o.kind.activities.indices.filter { eval.bestQuality >= o.kind.activities[$0].minQuality }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Name", text: $name).textFieldStyle(.roundedBorder).frame(width: 260)
                TextField("Objective", text: $objective).textFieldStyle(.roundedBorder)
            }
            OversightControls(state: s, models: models, autonomy: $autonomy, oversight: $oversight, verification: $verification)
            HStack {
                Text("Money budget")
                Slider(value: $budgetLog, in: 4...11).disabled(noBudget)
                Text(noBudget ? "None" : "\(Fmt.money(pow(10, budgetLog)))/mo").font(.callout.monospacedDigit()).frame(width: 110, alignment: .trailing)
                Toggle("None", isOn: $noBudget)
                Button("Fund fully") {
                    noBudget = false
                    budgetLog = log10(max(1e4, eval.needDaily * 30.4 * 1.05))
                }
                .help("What it could use at today's output: \(Fmt.money(eval.needDaily * 30.4))/mo")
            }
            if let goal {
                HStack {
                    Picker("Objective", selection: Binding(get: { goal.key }, set: { k in
                        goalKey = k
                        if let m = AgentOrgs.metric(k) { goalTarget = m.step(m.value(s)) }
                    })) {
                        ForEach(goals, id: \.key) { m in Text(m.title).tag(m.key) }
                    }
                    .frame(width: 300)
                    Text("now \(goal.format(goal.value(s))) →").font(.caption).foregroundStyle(.secondary)
                    TextField("Target", value: $goalTarget, format: .number).textFieldStyle(.roundedBorder).frame(width: 90)
                    Stepper("by \(GameCalendar.addMonths(s.date, goalMonths).gameShort)", value: $goalMonths, in: 1...60)
                    Button("Set objective") { store.act("Objective set") { $0.setOrgGoal(o.id, key: goal.key, target: goalTarget, months: goalMonths) } }
                }
                Text("A target the game measures: \(goal.title.lowercased()), \(goal.format(goalTarget)) as entered (percentages as fractions: 0.8 is 80%). The organisation reports progress monthly and you hear when it's met or missed.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if open.count > 1 {
                Picker("Focus", selection: $focus) {
                    ForEach(open, id: \.self) { i in Text(o.kind.activities[i].name).tag(i) }
                }
                .pickerStyle(.segmented)
                Text("The focus gets 60% of the effort; the rest is shared.").font(.caption2).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { done() }
                Button("Apply") {
                    let budget = noBudget ? 0 : (pow(10, budgetLog) / 1e4).rounded() * 1e4
                    store.act("Organisation updated") {
                        $0.tuneOrg(o.id, name: name, objective: objective, autonomy: autonomy, oversight: oversight, verification: verification,
                                   budgetMonthly: budget, focus: focus)
                    }
                    done()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = o.name
            objective = o.objective
            autonomy = o.autonomy
            oversight = o.oversight
            verification = o.verification
            noBudget = o.budgetMonthly <= 0
            budgetLog = o.budgetMonthly > 0 ? clamp(log10(o.budgetMonthly), 4, 11) : 6
            focus = o.focus
            goalKey = o.goalKey.isEmpty ? (AgentOrgs.goalOptions(o.kind, s).first?.key ?? "") : o.goalKey
            if let m = AgentOrgs.metric(goalKey) { goalTarget = o.goalStatus == 0 && !o.goalKey.isEmpty ? o.goalTarget : m.step(m.value(s)) }
        }
    }
}

private struct AddTeamPanel: View {
    @Environment(GameStore.self) private var store
    let org: AgentOrg
    let state: GameState
    let done: () -> Void
    @State private var role: TeamRole = .specialists
    @State private var name = ""
    @State private var modelID: UUID? = nil
    @State private var agentsLog = 3.0
    @State private var accelID = ""
    @State private var chips = 1

    var body: some View {
        let o = org
        let s = state
        let b = store.derived.bonuses
        let models = s.models.filter { !$0.retired }.sorted { Swarms.agenticX($0) > Swarms.agenticX($1) }
        let agents = Int(pow(10, agentsLog).rounded())
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Picker("Role", selection: $role) {
                        ForEach(TeamRole.allCases) { r in Label(r.title, systemImage: r.symbol).tag(r) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    TextField("Team name", text: $name).textFieldStyle(.roundedBorder)
                }
                Text(role == .supervisors ? "Supervisors plan, route and review. A smarter (or cheaper) model can supervise; about \(Fmt.pct(AgentOrgs.supervisionTarget, decimals: 0)) of the specialists' size gives full supervision."
                                          : "Specialists do the work. Each team can run a different model: one strong in this work's domains is worth more per agent.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Model", selection: $modelID) {
                    Text("Choose…").tag(UUID?.none)
                    ForEach(models) { m in
                        Text("\(m.name) · \(Swarms.tier(Swarms.quality(m, s))) · \(Fmt.trim(AgentOrgs.perAgent(m, o.kind, s), 2)) here").tag(UUID?.some(m.id))
                    }
                }
                if let m = models.first(where: { $0.id == modelID }) { AgentProfile(model: m, state: s, kind: o.kind) }
                TeamSizeControls(state: s, agentsLog: $agentsLog, accelID: $accelID, chips: $chips)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                Text("With this team").font(.headline)
                if let m = models.first(where: { $0.id == modelID }), !accelID.isEmpty {
                    let probe = probeTeam(o, m, agents, s)
                    let f = AgentOrgs.forecast(o, adding: probe, s, b)
                    SpecRow(label: "Output", value: "\(Fmt.count(f.before.workforce)) → \(Fmt.count(f.after.workforce)) r-eq")
                    SpecRow(label: "Right first time", value: "\(Fmt.pct(f.before.accuracy, decimals: 1)) → \(Fmt.pct(f.after.accuracy, decimals: 1))")
                    SpecRow(label: "Supervision", value: "\(Fmt.pct(f.before.supervision, decimals: 0)) → \(Fmt.pct(f.after.supervision, decimals: 0))")
                    SpecRow(label: "Chips for \(Fmt.int(agents)) agents", value: Fmt.int(Swarms.chipsNeeded(m, accelID: accelID, agents: agents, s, b)))
                    Button {
                        store.act("Team added") { $0.addOrgTeam(o.id, role: role, name: name, modelID: m.id, accelID: accelID, chips: chips, agents: agents) }
                        done()
                    } label: {
                        Label("Add \(Fmt.int(agents)) \(role.title.lowercased())", systemImage: "person.badge.plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Pick a model and hardware.").font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(width: 300)
            .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
        }
        .onAppear {
            if modelID == nil { modelID = models.first?.id }
            let d = store.derived
            if accelID.isEmpty, let p = d.pools.max(by: { Double($0.free) * $0.accel.best < Double($1.free) * $1.accel.best }) {
                accelID = p.accel.id
                chips = max(1, p.free)
            }
        }
    }

    private func probeTeam(_ o: AgentOrg, _ m: AIModel, _ agents: Int, _ s: GameState) -> AgentSwarm {
        var sw = AgentSwarm(name: "", modelID: m.id, agents: agents, mission: o.kind, accelID: accelID, chips: chips, autonomy: o.autonomy, oversight: o.oversight, started: s.date)
        sw.orgID = o.id
        sw.role = role
        sw.alignment = clamp(70 + m.safety * 0.3, 0, 100)
        return sw
    }
}

private struct OrgHistory: View {
    let org: AgentOrg
    let limit: Int

    var body: some View {
        if !org.history.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if limit > 3 { Text("Project history").font(.headline) }
                ForEach(org.history.prefix(limit)) { r in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: AgentOrgViews.historySymbol(r.kind)).font(.caption).foregroundStyle(AgentOrgViews.historyColor(r.kind)).frame(width: 14)
                        Text(r.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                        Text(r.title).font(.caption.weight(.semibold))
                        if !r.body.isEmpty { Text(r.body).font(.caption).foregroundStyle(.secondary).lineLimit(limit > 3 ? 3 : 1) }
                    }
                }
            }
        }
    }
}

// MARK: - Stand-alone swarms

private struct SwarmCard: View {
    @Environment(GameStore.self) private var store
    let swarm: AgentSwarm
    let state: GameState
    @State private var editing = false
    @State private var agentsLog = 3.0
    @State private var chips = 1
    @State private var mission: SwarmMission = .research
    @State private var autonomy = 1
    @State private var oversight = 0.1
    @State private var confirmDisband = false

    var body: some View {
        let sw = swarm
        let s = state
        let model = s.models.first { $0.id == sw.modelID }
        let accel = HardwareCatalog.get(sw.accelID)
        let align = sw.alignmentMeasured
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: sw.mission.symbol).font(.title2).foregroundStyle(Color.accentColor)
                        Text(sw.name).font(.title2.weight(.bold))
                        Pill(text: sw.paused ? "Paused" : "Running", color: sw.paused ? .orange : .green)
                        Pill(text: sw.mission.rawValue, color: .purple)
                        Pill(text: AgentSwarm.autonomyNames[sw.autonomy], color: sw.autonomy == 2 ? .red : .secondary)
                        if sw.experience > 1.01 { Pill(text: "Experience +\(Int((sw.experience - 1) * 100))%", color: .teal, symbol: "graduationcap.fill") }
                        if sw.mission == .trainingOps {
                            let target = sw.targetRunID.flatMap { t in s.runs.first { $0.id == t && Training.isLive($0) } }
                            Pill(text: target.map { "Watching \($0.design.name)" } ?? "Watching every run", color: .indigo, symbol: "eye.fill")
                        }
                        if sw.incidents > 0 { Pill(text: "\(sw.incidents) incident\(sw.incidents == 1 ? "" : "s")", color: .red, symbol: "exclamationmark.triangle.fill") }
                    }
                    Text("\(model?.name ?? "?") · \(Fmt.int(sw.chips))× \(accel?.name ?? "?") · oversight \(Int(sw.oversight * 100))% · since \(sw.started.gameShort)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                HStack {
                    Button("Form organisation", systemImage: "building.2.fill") { store.act("Organisation formed") { $0.formOrg(fromSwarm: sw.id) } }
                        .help("Make this swarm the first team of a new organisation on its mission (\(projection(sw, s))). Add supervisors, verification and a budget there.")
                    if sw.paused {
                        Button("Resume", systemImage: "play.fill") { store.act { $0.setSwarmPaused(sw.id, false) } }.buttonStyle(.borderedProminent)
                    } else {
                        Button("Pause", systemImage: "pause.fill") { store.act { $0.setSwarmPaused(sw.id, true) } }
                    }
                    Button("Audit", systemImage: "magnifyingglass") { store.act("Audit complete") { $0.auditSwarm(sw.id) } }
                        .help("Expensive, accurate alignment check.")
                    Button(editing ? "Done" : "Retune", systemImage: "slider.horizontal.3") {
                        if !editing {
                            agentsLog = log10(Double(max(1, sw.agents)))
                            chips = sw.chips
                            mission = sw.mission
                            autonomy = sw.autonomy
                            oversight = sw.oversight
                        }
                        editing.toggle()
                    }
                    Button("Disband", systemImage: "xmark.circle", role: .destructive) { confirmDisband = true }
                }
            }
            EqualColumns(minWidth: 120, spacing: 10, maxColumns: 5) {
                OrgStat(label: "Agents running", value: "\(Fmt.count(sw.active)) / \(Fmt.count(Double(sw.agents)))", symbol: "person.3.fill", tint: .indigo)
                OrgStat(label: "Researcher-equivalents", value: Fmt.count(sw.workforce), symbol: "brain.head.profile", tint: .purple)
                OrgStat(label: "Today", value: output(sw, s), symbol: sw.mission.symbol, tint: .blue)
                OrgStat(label: "Alignment (last eval)", value: "\(Int(align))/100", symbol: "shield.lefthalf.filled", tint: AgentOrgViews.alignColor(align))
                OrgStat(label: sw.mission == .workforce ? "Revenue so far" : "Total output", value: total(sw), symbol: "sum", tint: .green)
            }
            if editing {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Agents")
                        Slider(value: $agentsLog, in: 1...9)
                        Text(Fmt.int(Int(pow(10, agentsLog).rounded()))).font(.callout.monospacedDigit()).frame(width: 120, alignment: .trailing)
                        Text("Chips")
                        QuantityPicker(value: $chips, range: 1...max(1, store.derived.free(sw.accelID) + (sw.paused ? 0 : sw.chips)))
                    }
                    HStack {
                        Picker("Mission", selection: $mission) {
                            ForEach(SwarmMission.swarmCases) { m in Text(m.rawValue).tag(m) }
                        }
                        .frame(width: 280)
                        Picker("Autonomy", selection: $autonomy) {
                            ForEach(0..<3) { i in Text(AgentSwarm.autonomyNames[i]).tag(i) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 330)
                        Text("Oversight")
                        Slider(value: $oversight, in: 0...0.5, step: 0.05).frame(width: 140)
                        Text("\(Int(oversight * 100))%").font(.callout.monospacedDigit())
                        Spacer()
                        Button("Apply") {
                            store.act("Swarm retuned") {
                                $0.tuneSwarm(sw.id, agents: Int(pow(10, agentsLog).rounded()), chips: chips, mission: mission, autonomy: autonomy, oversight: oversight)
                            }
                            editing = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if sw.mission == .trainingOps {
                        Picker("Watch", selection: Binding(get: { sw.targetRunID }, set: { v in store.act("Swarm reassigned") { $0.setSwarmTarget(sw.id, runID: v) } })) {
                            Text("Every running job").tag(UUID?.none)
                            ForEach(s.runs.filter { Training.isLive($0) && $0.kind == .full }) { r in
                                Text("\(r.design.name) — \(Fmt.int(r.design.chips)) chips").tag(UUID?.some(r.id))
                            }
                        }
                        .frame(width: 420)
                    }
                }
            }
            if !sw.log.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(sw.log.prefix(3).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
        .confirmationDialog("Disband \(sw.name)? Its chips become idle.", isPresented: $confirmDisband) {
            Button("Disband", role: .destructive) { store.mutate { $0.disbandSwarm(sw.id) } }
        }
    }

    /// What the swarm would produce as the first team of an organisation with default settings.
    private func projection(_ sw: AgentSwarm, _ s: GameState) -> String {
        var o = AgentOrg(name: "", kind: sw.mission, objective: "", founded: s.date, autonomy: sw.autonomy, oversight: sw.oversight, verification: 0.1)
        o.budgetMonthly = 1e15
        var team = sw
        team.orgID = o.id
        let e = AgentOrgs.evaluate(o, members: [team], s, store.derived.bonuses)
        return "about \(Fmt.count(e.workforce)) researcher-equivalents before supervisors, against \(Fmt.count(sw.workforce)) now"
    }

    private func output(_ sw: AgentSwarm, _ s: GameState) -> String {
        guard !sw.paused else { return "—" }
        switch sw.mission {
        case .research: return "\(Fmt.count(sw.output)) RP"
        case .xeno: return "\(Fmt.trim(sw.output, 1)) insight"
        case .trainingOps:
            if let t = sw.targetRunID, let r = s.runs.first(where: { $0.id == t && Training.isLive($0) }) {
                return "\(Fmt.pct(r.opsCoverage, decimals: 0)) of \(r.design.name)"
            }
            return "Ops level \(Int(s.swarmOps * 100))%"
        case .silicon: return "Design level \(Int(s.swarmSilicon * 100))%"
        case .alignment: return "Safety level \(Int(s.swarmSafety * 100))%"
        case .workforce: return Fmt.money(sw.output)
        case .security: return "Security level \(Int(s.swarmSecurity * 100))%"
        case .intel: return "Intel level \(Int(s.swarmIntel * 100))%"
        default: return "\(Fmt.count(sw.workforce)) r-eq"
        }
    }

    private func total(_ sw: AgentSwarm) -> String {
        switch sw.mission {
        case .research: return "\(Fmt.count(sw.totalOutput)) RP"
        case .xeno: return "\(Fmt.count(sw.totalOutput)) insight"
        case .workforce: return Fmt.money(sw.revenue)
        default: return "\(Fmt.count(sw.totalOutput)) worker-days"
        }
    }
}
