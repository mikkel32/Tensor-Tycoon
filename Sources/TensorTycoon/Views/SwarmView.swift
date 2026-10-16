import SwiftUI

struct SwarmView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let b = store.derived.bonuses
        let running = s.swarms.filter { !$0.paused }
        let active = running.reduce(0) { $0 + $1.active }
        let workforce = running.reduce(0) { $0 + $1.workforce }
        Page(title: "Agent Swarms", subtitle: "Run a hundred, a thousand or ten million copies of one of your models and point them at a single mission. Every agent needs inference chips — and big swarms drift out of alignment faster.") {
            HeroBanner(image: "dc_rows", height: 160) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your digital workforce").font(.title.weight(.bold))
                        Text(b.has(.toolUse) ? "\(Fmt.count(active)) agents running · worth \(Fmt.count(workforce)) human researchers"
                                             : "Locked — research Tool Use & Function Calling to run agents.")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                }
            }
            if !b.has(.toolUse) {
                LockedSwarms(state: s)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                    StatTile(title: "Agents running", value: Fmt.count(active), detail: "\(s.swarms.count) of \(Swarms.maxSwarms) swarms", symbol: "person.3.sequence.fill", tint: .indigo)
                    StatTile(title: "Researcher-equivalents", value: Fmt.count(workforce), detail: "Pooled per mission", symbol: "brain.head.profile", tint: .purple)
                    StatTile(title: "Swarm research", value: "\(Fmt.count(s.swarmRPToday)) RP/day", detail: "Added to your research queue", symbol: "lightbulb.max.fill", tint: .pink)
                    StatTile(title: "Digital workforce", value: "\(Fmt.money(s.laborToday * 365))/yr", detail: "Cap \(Fmt.money(Swarms.laborCap(s) * 365))/yr at your brand", symbol: "briefcase.fill", tint: .green)
                    StatTile(title: "Mission levels", value: "\(Int(s.swarmOps * 100))% · \(Int(s.swarmSilicon * 100))% · \(Int(s.swarmSafety * 100))%",
                             detail: "Training ops · chip design · alignment", symbol: "dial.medium.fill", tint: .teal)
                }
                XenoProgressCard(state: s)
                NewSwarmCard(state: s)
                ForEach(s.swarms) { sw in SwarmCard(swarm: sw, state: s) }
            }
        }
    }
}

private struct LockedSwarms: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        Card {
            CardHeader("Locked", symbol: "lock.fill")
            Text("Agents need a model that can call tools. Research **Tool Use & Function Calling**, then train or fine-tune a model with tool use. **Agentic RL** unlocks alien-architecture search.")
            HStack {
                let queued = state.researchQueue.contains("tool_use")
                Button(queued ? "Queued" : "Queue Tool Use") {
                    store.mutate { $0.queueResearch("tool_use") }
                    store.show("Queued Tool Use & Function Calling")
                }
                .buttonStyle(.borderedProminent)
                .disabled(queued)
                Button("Open Research") { store.open(.research) }
            }
        }
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
                       subtitle: s.alienArchs.isEmpty ? "Nobody has found one. Point a swarm (or a self-improvement run) at it." : "\(s.alienArchs.count) found — each next one takes 3× the insight") {
                if store.screen != .xeno {
                    Button("Alien Tech") { store.open(.xeno) }.buttonStyle(.link)
                }
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Meter(value: s.xenoInsight / max(1, needed), tint: .purple, height: 10)
                    Text("\(Fmt.count(s.xenoInsight)) of \(Fmt.count(needed)) insight for discovery #\(s.alienArchs.count + 1)")
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

private struct NewSwarmCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var name = ""
    @State private var modelID: UUID? = nil
    @State private var mission: SwarmMission = .research
    @State private var agentsLog = 3.0
    @State private var accelID = ""
    @State private var chips = 1
    @State private var autonomy = 1
    @State private var oversight = 0.1

    private var agents: Int { Int(pow(10, agentsLog).rounded()) }

    var body: some View {
        let s = state
        let d = store.derived
        let b = d.bonuses
        let models = s.models.filter { !$0.retired }.sorted { Swarms.agenticX($0) > Swarms.agenticX($1) }
        Card {
            CardHeader("Spin up a swarm", symbol: "plus.circle.fill", subtitle: "Agents run on your own inference chips — pick hardware with idle capacity")
            if models.isEmpty {
                Text("Train a model first. Agents are copies of one of your models — the better its agentic skill, the more each agent is worth.")
                    .foregroundStyle(.secondary)
            } else if s.swarms.count >= Swarms.maxSwarms {
                Text("You're running the maximum of \(Swarms.maxSwarms) swarms. Grow or retarget an existing one.").foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField("Swarm name", text: $name).textFieldStyle(.roundedBorder).frame(width: 200)
                            Picker("Model", selection: $modelID) {
                                Text("Choose…").tag(UUID?.none)
                                ForEach(models) { m in
                                    Text("\(m.name) · \(Fmt.trim(Swarms.quality(m, s), 2)) researcher/agent").tag(UUID?.some(m.id))
                                }
                            }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(SwarmMission.allCases) { m in
                                let locked = m == .xeno && !b.has(.agents)
                                Button { mission = m } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: m.symbol).foregroundStyle(mission == m ? Color.accentColor : .secondary)
                                            Text(m.rawValue).font(.callout.weight(.semibold)).lineLimit(1)
                                            if locked { Image(systemName: "lock.fill").font(.caption2) }
                                        }
                                        Text(m.blurb).font(.caption2).foregroundStyle(.secondary).lineLimit(3, reservesSpace: true)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(mission == m ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06), in: .rect(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(mission == m ? Color.accentColor : .clear, lineWidth: 1.5))
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .disabled(locked)
                                .opacity(locked ? 0.5 : 1)
                            }
                        }
                        HStack {
                            Text("Agents")
                            Slider(value: $agentsLog, in: 1...7.7)
                            Text(Fmt.int(agents)).font(.callout.monospacedDigit().weight(.semibold)).frame(width: 100, alignment: .trailing)
                        }
                        HStack(spacing: 6) {
                            ForEach([2.0, 3.0, 4.0, 5.0, 6.0, 7.0], id: \.self) { v in
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
                        Picker("Autonomy", selection: $autonomy) {
                            ForEach(0..<3) { i in
                                Text(AgentSwarm.autonomyNames[i]).tag(i).disabled(i == 2 && !b.has(.autoResearch) && !b.has(.rsi))
                            }
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Text("Oversight")
                            Slider(value: $oversight, in: 0...0.5, step: 0.05)
                            Text("\(Int(oversight * 100))% of agents watch").font(.callout.monospacedDigit()).frame(width: 150, alignment: .trailing)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    forecastPanel(s, b, models)
                        .frame(width: 330)
                }
            }
        }
        .onAppear {
            if modelID == nil { modelID = models.first?.id }
            if accelID.isEmpty, let p = d.pools.max(by: { Double($0.free) * $0.accel.best < Double($1.free) * $1.accel.best }) {
                accelID = p.accel.id
                chips = max(1, p.free)
            }
        }
    }

    @ViewBuilder
    private func forecastPanel(_ s: GameState, _ b: ResearchBonuses, _ models: [AIModel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forecast").font(.headline)
            if let m = models.first(where: { $0.id == modelID }), !accelID.isEmpty {
                let f = Swarms.forecast(model: m, accelID: accelID, chips: chips, agents: agents, mission: mission, autonomy: autonomy, oversight: oversight, s, b)
                let free = store.derived.free(accelID)
                SpecRow(label: "Chips for \(Fmt.int(agents)) agents", value: Fmt.int(f.chipsNeeded))
                SpecRow(label: "Agents these chips run", value: Fmt.count(f.capacity))
                SpecRow(label: "Researcher-equivalents", value: Fmt.count(f.workforce))
                SpecRow(label: "Output", value: f.output)
                SpecRow(label: "Compute cost", value: "\(Fmt.money(f.dailyCost * 30.4))/mo")
                SpecRow(label: "Alignment drift", value: "−\(Fmt.trim(f.drift, 1))/yr")
                if f.chipsNeeded != chips {
                    Button(f.chipsNeeded <= free ? "Use \(Fmt.int(f.chipsNeeded)) chips" : "Use all \(Fmt.int(free)) free chips") {
                        chips = max(1, min(free, f.chipsNeeded))
                    }
                    .buttonStyle(.link)
                }
                if f.active < Double(agents) * 0.99 {
                    Label("Only \(Fmt.count(f.active)) agents fit on \(Fmt.int(chips)) chips.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                if autonomy == 2 && oversight < 0.1 {
                    Label("Millions of unwatched autonomous agents is how containment fails.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
            } else {
                Text("Pick a model and hardware.").font(.callout).foregroundStyle(.secondary)
            }
            Button {
                guard let id = modelID else { store.show("Pick a model", error: true); return }
                store.act("Swarm online") {
                    $0.startSwarm(name: name, modelID: id, agents: agents, mission: mission, accelID: accelID, chips: chips, autonomy: autonomy, oversight: oversight)
                }
            } label: {
                Label("Launch \(Fmt.int(agents)) agents", systemImage: "person.3.sequence.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(accelID.isEmpty || modelID == nil)
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 12))
    }
}

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
        let alignColor: Color = align >= 70 ? .green : (align >= 45 ? .yellow : .red)
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: sw.mission.symbol).font(.title2).foregroundStyle(Color.accentColor)
                        Text(sw.name).font(.title2.weight(.bold))
                        Pill(text: sw.paused ? "Paused" : "Running", color: sw.paused ? .orange : .green)
                        Pill(text: sw.mission.rawValue, color: .purple)
                        Pill(text: AgentSwarm.autonomyNames[sw.autonomy], color: sw.autonomy == 2 ? .red : .secondary)
                        if sw.incidents > 0 { Pill(text: "\(sw.incidents) incident\(sw.incidents == 1 ? "" : "s")", color: .red, symbol: "exclamationmark.triangle.fill") }
                    }
                    Text("\(model?.name ?? "?") · \(Fmt.int(sw.chips))× \(accel?.name ?? "?") · oversight \(Int(sw.oversight * 100))% · since \(sw.started.gameShort)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                HStack {
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                SwarmStat(label: "Agents running", value: "\(Fmt.count(sw.active)) / \(Fmt.count(Double(sw.agents)))", symbol: "person.3.fill", tint: .indigo)
                SwarmStat(label: "Researcher-equivalents", value: Fmt.count(sw.workforce), symbol: "brain.head.profile", tint: .purple)
                SwarmStat(label: "Today", value: output(sw, s), symbol: sw.mission.symbol, tint: .blue)
                SwarmStat(label: "Alignment (last eval)", value: "\(Int(align))/100", symbol: "shield.lefthalf.filled", tint: alignColor)
                SwarmStat(label: sw.mission == .workforce ? "Revenue so far" : "Total output", value: total(sw), symbol: "sum", tint: .green)
            }
            if sw.agents > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sw.active + 0.5 < Double(sw.agents) ? "Compute-bound: add chips to run every agent" : "Every agent has compute")
                        .font(.caption.weight(.semibold))
                    Meter(value: sw.active / Double(sw.agents), tint: sw.active + 0.5 < Double(sw.agents) ? .orange : .green, height: 6)
                }
            }
            if editing {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Agents")
                        Slider(value: $agentsLog, in: 1...7.7)
                        Text(Fmt.int(Int(pow(10, agentsLog).rounded()))).font(.callout.monospacedDigit()).frame(width: 100, alignment: .trailing)
                        Text("Chips")
                        QuantityPicker(value: $chips, range: 1...max(1, store.derived.free(sw.accelID) + (sw.paused ? 0 : sw.chips)))
                    }
                    HStack {
                        Picker("Mission", selection: $mission) {
                            ForEach(SwarmMission.allCases) { m in Text(m.rawValue).tag(m) }
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
                    if let m = model {
                        let need = Swarms.chipsNeeded(m, accelID: sw.accelID, agents: Int(pow(10, agentsLog).rounded()), s, store.derived.bonuses)
                        Text("\(Fmt.int(need)) chips run \(Fmt.int(Int(pow(10, agentsLog).rounded()))) agents of \(m.name).").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !sw.log.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(sw.log.prefix(4).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
        .confirmationDialog("Disband \(sw.name)? Its chips become idle.", isPresented: $confirmDisband) {
            Button("Disband", role: .destructive) { store.mutate { $0.disbandSwarm(sw.id) } }
        }
    }

    private func output(_ sw: AgentSwarm, _ s: GameState) -> String {
        guard !sw.paused else { return "—" }
        switch sw.mission {
        case .research: return "\(Fmt.count(sw.output)) RP"
        case .xeno: return "\(Fmt.trim(sw.output, 1)) insight"
        case .trainingOps: return "Ops level \(Int(s.swarmOps * 100))%"
        case .silicon: return "Design level \(Int(s.swarmSilicon * 100))%"
        case .alignment: return "Safety level \(Int(s.swarmSafety * 100))%"
        case .workforce: return Fmt.money(sw.output)
        }
    }

    private func total(_ sw: AgentSwarm) -> String {
        switch sw.mission {
        case .research: return "\(Fmt.count(sw.totalOutput)) RP"
        case .xeno: return "\(Fmt.count(sw.totalOutput)) insight"
        case .workforce: return Fmt.money(sw.revenue)
        case .trainingOps, .silicon, .alignment: return "\(Fmt.count(sw.totalOutput)) worker-days"
        }
    }
}

private struct SwarmStat: View {
    let label: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: symbol).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 10))
    }
}
