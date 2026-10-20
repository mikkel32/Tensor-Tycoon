import Charts
import SwiftUI

struct ModelsView: View {
    @Environment(GameStore.self) private var store
    @State private var showRetired = false

    var body: some View {
        let s = store.game
        let focus = store.focusModelID
        let models = s.models.filter { showRetired || !$0.retired }
            .sorted { ($0.id == focus ? 1 : 0, $0.created) > ($1.id == focus ? 1 : 0, $1.created) }
        Page(title: "Models & Serving", subtitle: "Release models, give them accelerators, set prices. Tokens/sec comes from memory bandwidth; capacity from FLOPS.", screen: .models) {
            ScreenHint(.models)
            HStack {
                Toggle("Show retired", isOn: $showRetired).toggleStyle(.switch)
                Spacer()
                Button("Train a new model", systemImage: "flask.fill") { store.open(.lab) }
            }
            if models.isEmpty {
                Card {
                    EmptyStateView(symbol: "cube.box", title: "No models yet", message: "Finished training runs show up here, ready to release and serve.",
                                   actionTitle: "Open Model Lab") { store.open(.lab) }
                }
            }
            ForEach(models) { m in
                ModelCard(model: m, state: s)
                    .overlay(RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(Color.accentColor, lineWidth: m.id == focus ? 2 : 0))
            }
        }
        .onDisappear { store.focusModelID = nil }
    }
}

private struct ModelCard: View {
    @Environment(GameStore.self) private var store
    let model: AIModel
    let state: GameState
    @State private var priceText = ""
    @State private var launch: LaunchPlan?   // 3.7: nil = your default plan
    @State private var addAccel = ""
    @State private var confirmRetire = false
    @State private var familySheet: FamilySheet?   // 3.5: model families

    var body: some View {
        let s = state
        let m = model
        let d = store.derived
        let rank = d.rank(m.id)
        let entry = d.entry(m.id)
        let p = Leaderboard.profile(m)
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(m.name).font(.title2.weight(.bold))
                        if m.retired { Pill(text: "Retired", color: .secondary) }
                        else if m.released { Pill(text: "Released", color: .green, symbol: "checkmark") }
                        else { Pill(text: "Unreleased", color: .orange) }
                        if m.openWeights { Pill(text: "Open weights", color: .blue, symbol: "lock.open") }
                        if m.reasoning { Pill(text: "Reasoning", color: .pink) }
                        if s.chatModelID == m.id { Pill(text: "Powers chat app", color: .purple, symbol: "bubble.left.fill") }
                        if m.design.mode == .finetune { Pill(text: "Fine-tune", color: .secondary) }
                        if m.preview { Pill(text: "Preview checkpoint", color: .yellow, symbol: "arrow.triangle.branch") }
                        if m.rsiGeneration > 0 { Pill(text: "Self-improved g\(m.rsiGeneration)", color: .purple, symbol: "arrow.triangle.2.circlepath") }
                        if m.efficiencyBoost > 0.05 { Pill(text: "+\(Int(m.efficiencyBoost * 100))% serving efficiency", color: .teal) }
                        if s.agentModelID == m.id { Pill(text: "Powers agent product", color: .indigo, symbol: "figure.walk.motion") }
                        if let f = Families.family(of: m.id, s), let t = f.tier(of: m.id) { Pill(text: "\(f.name) \(t.label)", color: .teal, symbol: t.symbol) }
                    }
                    Text("\(Fmt.params(m.design.paramsB)) params\(m.design.isMoE ? " (\(Fmt.params(m.design.activeParamsB)) active)" : "") · \(Fmt.tokens(m.design.tokensT)) tokens · \(m.design.contextK >= 1000 ? "1M" : "\(m.design.contextK)K") context · trained \(m.created.gameShort)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Fmt.score(entry?.index ?? BenchmarkCatalog.index(p, set: d.indexSet))).font(TypeRamp.bannerMetric)
                    Text("Index · #\(rank) lab worldwide").font(.caption).foregroundStyle(.secondary)
                    Text("Capability \(Int(BenchmarkCatalog.capability(p).rounded())) (GPT-4 = 100)").font(.caption).foregroundStyle(.secondary)
                    Text("Task horizon \(BenchmarkCatalog.formatHorizon(BenchmarkCatalog.taskHorizonMinutes(p)))").font(.caption2).foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                BenchmarkBars(profile: p, set: d.indexSet, extra: d.benchmarks.filter { $0.isActive(s.date, saturated: s.benchSaturated) && !d.indexSet.contains($0) }.suffix(3).map { $0 },
                              arena: Leaderboard.playerArena(m))
                    .frame(maxWidth: .infinity)
                if !m.retired {
                    releasePanel(m, s)
                        .frame(width: 330)
                } else {
                    // 3.8: retiring is reversible.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Retired").font(.headline)
                        Text("It isn't serving anyone. Bring it back to give it servers again and move the chat app, agents and any contract with no model onto it.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Bring back") { store.act("\(m.name) is back") { $0.unretire(m.id); return nil } }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(width: 330, alignment: .leading)
                }
            }
            ModelDomainsSection(model: m, state: s)   // 3.4: capability domains

            if m.released && !m.retired {
                Divider()
                servingPanel(m, s)
            }
        }
        .onAppear { priceText = String(format: "%.3f", m.apiPrice) }
        .familySheet($familySheet)
    }

    @ViewBuilder
    private func releasePanel(_ m: AIModel, _ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Distribution").font(.headline)
            if !m.released {
                Text("Releasing boosts your brand. Then deploy chips and set a price.").font(.caption).foregroundStyle(.secondary)
                let plan = launch ?? s.launchDefault
                LaunchPlanPicker(plan: Binding(get: { launch ?? s.launchDefault }, set: { launch = $0 }), state: s, rank: store.derived.rank(m.id))
                HStack {
                    Button("Release via API") { store.act("\(m.name) released") { $0.release(m.id, api: true, openWeights: false, plan: plan) } }
                        .buttonStyle(.borderedProminent)
                    if plan.strategy != .openWeights {
                        Button("Release open weights") { store.act("\(m.name) released with open weights") { $0.release(m.id, api: true, openWeights: true, plan: plan) } }
                    }
                }
            } else {
                Toggle("Sell via API", isOn: Binding(get: { m.api }, set: { on in store.act { $0.release(m.id, api: on, openWeights: m.openWeights) } }))
                    .toggleStyle(.switch)
                Button(s.chatModelID == m.id ? "Powering your chat app" : "Use for chat app") {
                    store.mutate { $0.chatModelID = m.id }
                    store.show("\(m.name) now powers \(s.companyName) Chat")
                }
                .disabled(s.chatModelID == m.id || !m.design.instruct)
                Button(s.agentModelID == m.id ? "Powering your agent product" : "Use for agent product") {
                    store.mutate { $0.agentModelID = m.id }
                    store.show("\(m.name) now powers \(s.companyName) Agent")
                }
                .disabled(s.agentModelID == m.id || !m.design.toolUse || !store.derived.bonuses.has(.toolUse))
                .help("Coding & computer-use agent seats. Needs a tool-use model.")
                if !m.design.instruct { Text("Base models (no instruction tuning) can't power a chat app.").font(.caption).foregroundStyle(.secondary) }
                if !m.openWeights {
                    Button("Open-source the weights") { store.act("Weights released") { $0.release(m.id, api: m.api, openWeights: true) } }
                }
            }
            evaluationRow(m, s)   // 3.4: dangerous-capability evaluations
            if !m.preview {
                // 3.5: model families
                HStack {
                    Button("Distil a tier…") { familySheet = .distill(m.id) }
                        .help("Train a smaller, much cheaper student from this model")
                    Button("Post-train…") { familySheet = .postTrain(m.id) }
                        .help("Reasoning RL, agentic training, safety tuning or long context as a point release — or fork a coding, science, medicine, reasoning, vision & voice or robotics specialist into its family")
                }
            }
            Button("Retire model…", role: .destructive) { confirmRetire = true }
                .buttonStyle(.link)
                .font(.caption)
                .confirmationDialog("Retire \(m.name)?", isPresented: $confirmRetire, titleVisibility: .visible) {
                    Button("Retire", role: .destructive) { store.mutate { $0.retire(m.id) } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(retireWarning(m, s))
                }
        }
    }

    /// What retiring does, said plainly. 3.8: it can be undone, and when nothing else can take over, everything goes dark.
    private func retireWarning(_ m: AIModel, _ s: GameState) -> String {
        let others = s.models.filter { $0.released && !$0.retired && $0.id != m.id }
        var text = "It stops serving and its chips are freed. You can bring it back later from \"Show retired\"; its servers are set up again then."
        let chatDark = s.chatModelID == m.id && !others.contains { $0.design.instruct }
        let agentDark = s.agentModelID == m.id && !others.contains { $0.design.toolUse }
        if others.isEmpty && m.released {
            text += " It is your last live model: the chat app, agents and API go dark and revenue falls toward $0 until you bring a model back."
        } else if chatDark || agentDark {
            let what = chatDark && agentDark ? "chat app and agents" : (chatDark ? "chat app" : "agents")
            text += " No other live model can run your \(what), so they go dark and that revenue falls toward $0."
        } else {
            text += " Products and contracts on it move to your next best model."
        }
        return text
    }

    /// Whether the model has been through dangerous-capability evaluations, and the button that commissions them.
    @ViewBuilder
    private func evaluationRow(_ m: AIModel, _ s: GameState) -> some View {
        if Evaluations.isEvaluated(s, m) {
            Label("Capability evaluations on record", systemImage: "checkmark.shield")
                .font(.caption).foregroundStyle(.secondary)
        } else if let due = m.evalDue {
            Label("Evaluations under way: results \(due.gameShort)", systemImage: "hourglass")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            let why = Evaluations.blocker(s, m)
            Button(evaluationTitle(m, s)) { store.act("Evaluations commissioned for \(m.name)") { $0.evaluateModel(m.id) } }
                .disabled(why != nil)
                .help(why ?? evaluationHelp(s))
        }
    }

    private func evaluationTitle(_ m: AIModel, _ s: GameState) -> String {
        "Commission evaluations (\(Fmt.money(Evaluations.cost(s, m))), \(Evaluations.days) days)"
    }

    private func evaluationHelp(_ s: GameState) -> String {
        let law = s.market.euAIAct ? " The EU AI Act fines near-frontier models shipped without them." : ""
        return "Red-teamers and outside evaluators test it for dangerous capabilities: +3 safety." + law
    }

    @ViewBuilder
    private func servingPanel(_ m: AIModel, _ s: GameState) -> some View {
        let b = s.bonuses
        let pools = store.derived.pools
        let load = m.capacityTokensDay > 0 ? m.demandTokensDay / m.capacityTokensDay : 0
        let dailyCost = m.deployments.reduce(0.0) { acc, d in acc + (HardwareCatalog.get(d.accelID).map { Economy.chipDailyCost($0, count: d.chips, state: s) } ?? 0) }
        // 3.8: per 1M tokens sold: a reasoning model's servers also generate its thinking tokens.
        let costPerM = m.capacityTokensDay > 0 ? dailyCost / m.capacityTokensDay * 1e6 * Families.thinkingTokens(m, b) : 0
        let ref = Macro.referencePrice(c: m.c, y: s.year) * s.market.apiPricePressure

        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Inference deployment").font(.headline)
                Picker("Serving precision", selection: Binding(get: { m.servingPrecision }, set: { p in store.mutate { $0.setServingPrecision(m.id, p) } })) {
                    ForEach(Precision.allCases) { p in
                        Text(p == .bf16 ? "BF16" : (p == .fp8 ? "FP8/INT8" : "4-bit")).tag(p)
                            .disabled(!Physics.allowedServingPrecisions(HardwareCatalog.h100, bonuses: b).contains(p))
                    }
                }
                .pickerStyle(.segmented)
                Text("Lower precision halves memory and boosts speed; costs a little quality (−\(Fmt.trim(Physics.servingPenalty(m), 2)) c\(m.qat ? ", cut by its quantisation-aware training" : "")).")
                    .font(.caption).foregroundStyle(.secondary)
                if m.reasoning {
                    // 3.8: test-time compute — how long it thinks before answering.
                    Picker("Reasoning effort", selection: Binding(get: { m.effort }, set: { e in store.act("Reasoning effort: \(e.label.lowercased())") { $0.setReasoningEffort(m.id, e) } })) {
                        ForEach(ReasoningEffort.allCases) { e in Text(e.label).tag(e) }
                    }
                    .pickerStyle(.segmented)
                    Text(Self.effortText(m, b)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                ForEach(m.deployments) { d in
                    if let a = HardwareCatalog.get(d.accelID) {
                        DeploymentRow(model: m, dep: d, accel: a, state: s)
                    }
                }
                let options = pools.filter { p in !m.deployments.contains { $0.accelID == p.accel.id } && p.free > 0 }
                if !options.isEmpty {
                    // 3.9: one copy of the model needs `k` chips of a type; a pool with fewer can't serve it at all, so say
                    // so up front instead of asking for a full replica and failing with "only N chips available".
                    let perReplica = { (p: ComputePool) in Physics.chipsPerReplica(m, accel: p.accel, precision: m.servingPrecision, bonuses: b) }
                    let chosen = options.first { $0.accel.id == addAccel }
                    HStack {
                        Picker("Add accelerators", selection: $addAccel) {
                            Text("Choose hardware…").tag("")
                            ForEach(options) { p in
                                let k = perReplica(p)
                                Text(p.free >= k ? "\(p.accel.name) (\(p.free) free, \(p.free / k) replica\(p.free / k == 1 ? "" : "s"))"
                                                 : "\(p.accel.name) (\(p.free) free — one replica needs \(k))").tag(p.accel.id)
                            }
                        }
                        Button("Deploy") {
                            guard let p = chosen else { return }
                            let n = (p.free / perReplica(p)) * perReplica(p)
                            store.act("Deployed \(n) chips") { $0.deploy(m.id, accelID: p.accel.id, chips: n) }
                            addAccel = ""
                        }
                        .disabled(chosen.map { $0.free < perReplica($0) } ?? true)
                    }
                    if let p = chosen, p.free < perReplica(p) {
                        Text("\(m.name) needs \(perReplica(p)) \(p.accel.name) chips for one copy of itself at \(m.servingPrecision.short); you have \(p.free) free. Free more, serve at a lower precision, or pick other chips.")
                            .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    }
                } else if m.deployments.isEmpty {
                    Text("No free accelerators. Rent or buy more, or free some from training/research.").font(.caption).foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Live metrics").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    Metric(label: "Tokens/sec per user", value: m.tps > 0 ? "\(Int(m.tps))" : "—", symbol: "speedometer")
                    Metric(label: "Capacity / day", value: Fmt.count(m.capacityTokensDay), symbol: "square.stack.3d.up")
                    Metric(label: "Demand / day", value: Fmt.count(m.demandTokensDay), symbol: "person.3")
                    Metric(label: m.reasoning ? "Serving cost / 1M sold" : "Serving cost / 1M", value: costPerM > 0 ? Fmt.price(costPerM) : "—", symbol: "bolt")
                    Metric(label: "API revenue / day", value: Fmt.money(m.revenueDay), symbol: "dollarsign")
                    Metric(label: "Gross margin", value: m.revenueDay > 0 ? Fmt.pct((m.revenueDay - dailyCost) / m.revenueDay, decimals: 0) : "—", symbol: "percent")
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Utilisation").font(.caption)
                        Spacer()
                        Text(Fmt.pct(min(load, 9.99), decimals: 0)).font(.caption.monospacedDigit()).foregroundStyle(load > 1 ? .red : .secondary)
                    }
                    Meter(value: min(load, 1), tint: load > 1 ? .red : (load > 0.85 ? .orange : .green))
                    if load > 1 { Text("Over capacity: requests are failing and users are churning. Add chips!").font(.caption).foregroundStyle(.red) }
                }
                // 3.8: which kinds of API work it wins.
                let segs = Market.segments(of: m.id, store.derived.snapshot)
                if m.api && !segs.isEmpty {
                    Text(Self.segmentText(segs))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        .help("Its share of each kind of API work. Buyers pick models on the domains the work needs: a coding specialist wins coding traffic from a stronger generalist.")
                }
                if m.api {
                    Toggle(isOn: Binding(get: { m.autoPrice }, set: { v in store.mutate { $0.setAutoPrice(m.id, v) } })) {
                        Text("Auto-price: keep it 80–90% busy near the going rate (\(Fmt.price(Treasury.targetPrice(m, s))) today)")
                    }
                    .help("Re-prices a little every day: up when the model is swamped, down when it sits idle, within half to twice the going rate and never below serving cost. Setting a price by hand turns it off.")
                    HStack {
                        Text("API price $/1M tokens")
                        TextField("Price", text: $priceText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .onSubmit { applyPrice(m) }
                        Button("Set") { applyPrice(m) }
                    }
                    HStack(spacing: 12) {
                        Text("Going rate \(Fmt.price(Treasury.marketPrice(m, s))) · serving cost \(Fmt.price(Economy.servingCostPerM(m, s)))").font(.caption).foregroundStyle(.secondary)
                        Button("Match market") { priceText = String(format: "%.3f", ref); applyPrice(m) }.buttonStyle(.link).font(.caption)
                        Button("Undercut 30%") { priceText = String(format: "%.3f", ref * 0.7); applyPrice(m) }.buttonStyle(.link).font(.caption)
                    }
                }
            }
            .frame(width: 420)
        }
    }

    /// 3.8: what the reasoning effort costs and buys (built here: long strings are slow to type-check in views).
    static func effortText(_ m: AIModel, _ b: ResearchBonuses) -> String {
        var t = "\(m.effort.blurb) It now generates \(Fmt.trim(Families.thinkingTokens(m, b), 2)) tokens per token of answer"
        if b.thinkingEfficiency > 0.005 {
            t += " (thinking-efficiency research saves \(Fmt.pct(min(0.8, b.thinkingEfficiency), decimals: 0)) of the thinking)"
        }
        t += ": chat traffic needs that much more capacity, and every API token sold costs that much more to serve."
        return t
    }

    static func segmentText(_ segs: [(segment: APISegment, share: Double)]) -> String {
        "API segments: " + segs.prefix(5).map { "\($0.segment.label) \(Fmt.pct($0.share, decimals: 1))" }.joined(separator: " · ")
    }

    private func applyPrice(_ m: AIModel) {
        if let v = Double(priceText.replacingOccurrences(of: "$", with: "")), v > 0 {
            // Below serving cost the price is held at the floor and the reason is shown.
            if store.act("Price set to \(Fmt.price(v))/M tokens", { $0.setAPIPrice(m.id, v) }) == false {
                priceText = String(format: "%.3f", store.game.models.first { $0.id == m.id }?.apiPrice ?? v)
            }
        }
    }
}

private struct DeploymentRow: View {
    @Environment(GameStore.self) private var store
    let model: AIModel
    let dep: Deployment
    let accel: Accelerator
    let state: GameState
    @State private var chips = 0

    var body: some View {
        let b = state.bonuses
        let k = Physics.chipsPerReplica(model, accel: accel, precision: model.servingPrecision, bonuses: b)
        let tps = Physics.tps(model, accel: accel, precision: model.servingPrecision, bonuses: b)
        let cap = Physics.capacity(model, deployment: dep, bonuses: b)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Photo(key: accel.image).frame(width: 46, height: 32).clipShape(.rect(cornerRadius: 6)).acceleratorPhotoLabel(accel)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(Fmt.int(dep.chips))× \(accel.name)").font(.callout.weight(.semibold))
                    Text("\(k) chip\(k == 1 ? "" : "s") per replica · \(dep.chips / k) replicas · \(Int(tps)) tok/s · \(Fmt.count(cap))/day")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack {
                QuantityPicker(value: $chips, range: 0...(dep.chips + store.derived.available(accel.id)), presets: [k, k * 4, k * 16, k * 64])   // 3.9: deploy recalls leased chips
                Button("Apply") { store.act("Deployment updated") { $0.deploy(model.id, accelID: accel.id, chips: chips) } }
                    .disabled(chips == dep.chips)
                if dep.chips % k != 0 {
                    Text("\(dep.chips % k) idle (need multiples of \(k))").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .padding(10)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
        .onAppear { chips = dep.chips }
        .onChange(of: dep.chips) { _, new in chips = new }
    }
}

private struct Metric: View {
    let label: String
    let value: String
    let symbol: String
    var body: some View {
        MetricTile(label: label, value: value, symbol: symbol, style: .plain)
    }
}

struct BenchmarkBars: View {
    let profile: ModelProfile
    let set: [Benchmark]
    var extra: [Benchmark] = []
    let arena: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Intelligence Index benchmarks").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(set) { b in row(b) }
            if !extra.isEmpty {
                Text("Also tracked").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(extra) { b in row(b) }
            }
            HStack(spacing: 8) {
                Text("LMArena Elo").font(.caption).frame(width: 160, alignment: .leading)
                Text(verbatim: "\(Int(arena))").font(.caption.monospacedDigit().weight(.semibold))
            }
        }
    }

    private func row(_ b: Benchmark) -> some View {
        let v = BenchmarkCatalog.cachedScore(b, profile)
        return HStack(spacing: 8) {
            Image(systemName: b.kind.symbol).font(.caption2).foregroundStyle(color(b.kind)).frame(width: 14)
            Text(b.name).font(.caption).frame(width: 140, alignment: .leading).lineLimit(1)
            Meter(value: v / 100, tint: color(b.kind), height: 8)
            Text(Fmt.score(v)).font(.caption.monospacedDigit()).frame(width: 38, alignment: .trailing)
        }
        .help(b.about)
    }

    private func color(_ k: BenchKind) -> Color { k.color }
}
