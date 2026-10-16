import SwiftUI

struct ResearchView: View {
    @Environment(GameStore.self) private var store
    @State private var hideDone = true
    @State private var filter: ResearchCategory? = nil
    @State private var query = ""

    var body: some View {
        let s = store.game
        let rate = Sim.researchRate(s, store.derived.bonuses)
        let core = ResearchCatalog.core
        let doneCount = core.filter { s.researched.contains($0.id) }.count
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        Page(title: "Research", subtitle: "Researchers generate research points (RP); compute multiplies their output. Every technique is an experiment: in your lab it can land better or worse than the paper, and that decides how much it really helps your models.") {
            HStack(alignment: .top, spacing: 16) {
                CurrentProjectCard(state: s, rate: rate)
                CapacityCard(state: s, rate: rate)
                    .frame(width: 400)
            }

            UniqueTechSection(state: s)
            RivalIntelSection(state: s)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Research tree").font(.title2.weight(.bold))
                    Text("\(doneCount) of \(core.count) techniques researched").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Search techniques", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Picker("Category", selection: $filter) {
                    Text("All categories").tag(ResearchCategory?.none)
                    Divider()
                    ForEach(ResearchCategory.allCases.filter { $0 != .exotic }) { c in
                        Label(c.rawValue, systemImage: c.symbol).tag(Optional(c))
                    }
                }
                .labelsHidden()
                .frame(width: 250)
                Toggle("Hide completed", isOn: $hideDone).toggleStyle(.switch)
            }

            ForEach(ResearchCategory.allCases.filter { $0 != .exotic && (filter == nil || filter == $0) }) { cat in
                let items = core.filter { item in
                    item.category == cat && (!hideDone || !s.researched.contains(item.id))
                        && (q.isEmpty || item.name.lowercased().contains(q) || item.blurb.lowercased().contains(q))
                }.sorted { $0.year < $1.year }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(cat.rawValue, systemImage: cat.symbol).font(.title3.weight(.semibold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 12, alignment: .top)], spacing: 12) {
                            ForEach(items) { item in ResearchCard.make(item, state: s).equatable() }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Header cards

private struct CurrentProjectCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let rate: Double

    var body: some View {
        let s = state
        let current = s.researchQueue.first.flatMap { ResearchCatalog.byID[$0] }
        Card {
            CardHeader("Current project", symbol: "lightbulb.fill")
            if let current {
                let cost = Sim.researchCost(current, year: s.year)
                let done = s.researchProgress[current.id] ?? 0
                HStack {
                    Text(current.name).font(.title2.weight(.bold))
                    if current.isExotic { Pill(text: "Unique", color: .purple, symbol: "atom") }
                }
                Meter(value: done / cost, tint: current.isExotic ? .purple : .pink, height: 10)
                Text("\(Fmt.count(done)) / \(Fmt.count(cost)) RP · \(Fmt.days((cost - done) / max(rate, 0.01))) left at \(Fmt.trim(rate, 1)) RP/day")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Idle! Pick something below.").font(.headline).foregroundStyle(.orange)
            }
            if s.researchQueue.count > 1 {
                Text("Up next").font(.caption.weight(.semibold)).padding(.top, 4)
                ForEach(Array(s.researchQueue.dropFirst().enumerated()), id: \.element) { i, id in
                    HStack {
                        Text("\(i + 2). \(ResearchCatalog.byID[id]?.name ?? id)").font(.caption)
                        Spacer()
                        Button { store.mutate { $0.researchQueue.removeAll { $0 == id } } } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless).font(.caption)
                            .accessibilityLabel("Remove from queue")
                    }
                }
            }
        }
    }
}

private struct CapacityCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let rate: Double

    var body: some View {
        let s = state
        Card {
            CardHeader("Research capacity", symbol: "brain")
            let researchers = s.employees.filter { $0.role == .researcher }
            SpecRow(label: "Research scientists", value: "\(researchers.count) (+ you)")
            if !researchers.isEmpty {
                SpecRow(label: "Average skill", value: "\(Int(researchers.reduce(0) { $0 + $1.skill } / Double(researchers.count)))")
            }
            SpecRow(label: "Research points / day", value: Fmt.trim(rate, 1))
            Text("Compute for experiments").font(.caption.weight(.semibold)).padding(.top, 4)
            let pools = store.derived.pools
            if pools.isEmpty { Text("No accelerators.").font(.caption).foregroundStyle(.secondary) }
            ForEach(pools) { p in ResearchChipRow(pool: p, assigned: s.researchChips[p.accel.id] ?? 0) }
            Text("Better researchers and more experiment compute make results land above the paper's promise.")
                .font(.caption2).foregroundStyle(.secondary)
            Divider().padding(.vertical, 2)
            Text("Publication policy").font(.caption.weight(.semibold))
            Picker("Publication policy", selection: Binding(get: { s.publication }, set: { v in store.mutate { $0.publication = v } })) {
                ForEach(PublicationPolicy.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(s.publication.detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Hire researchers") { store.open(.team) }.buttonStyle(.link).font(.caption)
        }
    }
}

private struct ResearchChipRow: View {
    @Environment(GameStore.self) private var store
    let pool: ComputePool
    let assigned: Int
    @State private var value = 0

    var body: some View {
        HStack {
            Text(pool.accel.name).font(.caption).lineLimit(1)
            Spacer()
            Stepper("\(Fmt.int(value))", value: $value, in: 0...(assigned + pool.free), step: max(1, (assigned + pool.free) / 16))
                .font(.caption.monospacedDigit())
            Button("Set") { store.mutate { $0.researchChips[pool.accel.id] = value } }
                .disabled(value == assigned)
                .font(.caption)
        }
        .onAppear { value = assigned }
    }
}

// MARK: - Unique breakthroughs

private struct UniqueTechSection: View {
    let state: GameState

    var body: some View {
        let s = state
        let items = s.exoticOwned.compactMap { ResearchCatalog.byID[$0] }.sorted { $0.year < $1.year }
        let done = items.filter { s.researched.contains($0.id) }.count
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Your lab's unique breakthroughs", systemImage: "atom").font(.title2.weight(.bold))
                Spacer()
                Text("\(done) of \(items.count) completed").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text("Ideas only your team is chasing. Nobody has published them, so there is no discount and no guarantee: the result can land anywhere from 0.35× to 1.8× of the idea's promise, and most come with a real trade-off. Headhunt rival researchers to add more.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if items.isEmpty {
                Text("No unique research yet.").font(.callout).foregroundStyle(.tertiary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(items) { item in ResearchCard.make(item, state: s).equatable() }
                }
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [.purple.opacity(0.16), .indigo.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.purple.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Rival intel

private struct RivalIntelSection: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var target: String? = nil

    var body: some View {
        let s = state
        let fee = s.headhuntFee
        Card {
            CardHeader(title: "Rival labs' secret projects", symbol: "eye.fill",
                       subtitle: "Every lab has a signature strength and techniques nobody else has. Deployed ones already show up in their models and benchmark scores.") {
                if let ready = s.headhuntReadyOn {
                    Pill(text: "Recruiters busy until \(ready.gameShort)", color: .orange, symbol: "hourglass")
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(s.competitors.filter { !$0.acquired }) { comp in
                    RivalTechCard(comp: comp, state: s, fee: fee) { target = comp.id }
                }
            }
            Text("Headhunting a senior researcher costs \(Fmt.money(fee)) in signing packages, win or lose (2025's talent war saw nine-figure offers). Success odds depend on your brand vs theirs and your publication policy. Failed attempts can end in legal threats.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .confirmationDialog("Headhunt from \(target.flatMap { CompetitorCatalog.byID[$0]?.name } ?? "rival")?",
                            isPresented: Binding(get: { target != nil }, set: { if !$0 { target = nil } }), presenting: target) { lab in
            Button("Make the offer (\(Fmt.money(fee)))") {
                store.act("Offer made") { $0.headhunt(lab) }
            }
        } message: { lab in
            let tech = s.headhuntTargets(lab).first.flatMap { ResearchCatalog.byID[$0]?.name } ?? "their secret work"
            Text("Target: someone who knows \(tech). Estimated odds \(Int(s.headhuntChance(lab) * 100))%. The fee is spent either way.")
        }
    }
}

private struct RivalTechCard: View {
    let comp: CompetitorState
    let state: GameState
    let fee: Double
    let onHeadhunt: () -> Void

    var body: some View {
        let s = state
        let def = comp.def
        let trait = Competitors.trait(comp.id)
        let techs = (s.rivalTech[comp.id] ?? []).compactMap { ResearchCatalog.byID[$0] }.sorted { $0.year < $1.year }
        let targets = s.headhuntTargets(comp.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: def.symbol).font(.callout.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Theme.competitorColor(def.color).gradient, in: .rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(def.name).font(.headline)
                    Text(trait.signature).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Button("Headhunt…", action: onHeadhunt)
                    .controlSize(.small)
                    .disabled(targets.isEmpty || s.headhuntReadyOn != nil || s.cash < fee)
                    .help(targets.isEmpty ? "Nothing they're working on that you could hire into yet." : "Try to hire someone who knows their secret work.")
            }
            ForEach(techs) { item in
                let st = RivalTechStatus(item: item, year: s.year)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: st.symbol).foregroundStyle(st.color).frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(st.hidden ? "Unconfirmed \(item.domainHint) breakthrough" : item.name)
                                .font(.callout.weight(.semibold))
                                .italic(st.hidden)
                            Pill(text: st.label, color: st.color)
                            if s.exoticOwned.contains(item.id) { Pill(text: "You know it too", color: .purple, symbol: "atom") }
                        }
                        if !st.hidden, let r = item.rival {
                            Text((st.label == "Deployed" ? "In their models: " : "If it works: ") + Self.summary(r))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .help(st.hidden ? "Too early to tell what they're building." : item.blurb)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }

    static func summary(_ r: RivalBoost) -> String {
        var parts: [String] = []
        func signed(_ v: Double, _ name: String) {
            guard v != 0 else { return }
            parts.append("\(v > 0 ? "+" : "−")\(Fmt.trim(abs(v), 2)) \(name)")
        }
        signed(r.c, "capability")
        signed(r.reasoning, "reasoning")
        signed(r.code, "coding")
        signed(r.agent, "agentic")
        signed(r.chat, "chat")
        signed(r.lang, "multilingual")
        signed(r.longctx, "long context")
        if r.tps != 1 { parts.append("\(Fmt.trim(r.tps, 1))× tokens/sec") }
        if r.price != 1 { parts.append(r.price < 1 ? "\(Int(((1 - r.price) * 100).rounded()))% cheaper to serve" : "\(Int(((r.price - 1) * 100).rounded()))% pricier") }
        return parts.isEmpty ? "effects unclear" : parts.joined(separator: " · ")
    }
}

private struct RivalTechStatus {
    let label: String
    let symbol: String
    let color: Color
    let hidden: Bool

    init(item: ResearchItem, year y: Double) {
        if item.year <= y + 0.3 {
            label = "Deployed"; symbol = "checkmark.circle.fill"; color = .red; hidden = false
        } else if item.year <= y + 1 {
            label = "In development"; symbol = "hammer.fill"; color = .orange; hidden = false
        } else if item.year <= y + 2 {
            label = "Rumor"; symbol = "ear.fill"; color = .secondary; hidden = false
        } else {
            label = "Rumor"; symbol = "questionmark.circle"; color = .secondary; hidden = true
        }
    }
}

// MARK: - Cards

private extension ResearchEffect {
    var isDownside: Bool {
        switch self {
        case .algo(let v), .dataAlgo(let v), .moeAlgo(let v), .muonAlgo(let v), .shampooAlgo(let v), .rl(let v), .rlEfficiency(let v),
             .agentRL(let v), .distill(let v), .thinkingEfficiency(let v), .stability(let v), .forecast(let v), .failureCost(let v),
             .bugGuard(let v), .contaminationGuard(let v), .mfu(let v), .throughput(let v), .tps(let v), .kvMemory(let v), .scaleOut(let v),
             .postTrainCost(let v), .rp(let v), .dataTokens(let v), .safety(let v), .consumerDemand(let v), .apiDemand(let v),
             .enterpriseDemand(let v), .agentQuality(let v), .coordination(let v), .agentSafety(let v), .insight(let v),
             .legibility(let v), .securityCost(let v), .chipDesign(let v), .distillGuard(let v):
            return v < 0
        case .skill(_, let v):
            return v < 0
        case .unlock:
            return false
        }
    }
}

private struct ResearchCard: View, Equatable {
    @Environment(GameStore.self) private var store
    let item: ResearchItem
    let done: Bool
    let queuedAt: Int?
    let missing: [String]
    let cost: Double
    /// Fraction complete, rounded to 1% so cards only redraw when it visibly changes.
    let progress: Double
    let published: Bool
    let ahead: Bool
    /// How well it worked in your lab (1 = as the paper promised), once done.
    let result: Double?

    static func make(_ item: ResearchItem, state s: GameState) -> ResearchCard {
        let cost = Sim.researchCost(item, year: s.year)
        return ResearchCard(item: item, done: s.researched.contains(item.id), queuedAt: s.researchQueue.firstIndex(of: item.id),
                            missing: item.prereqs.filter { !s.researched.contains($0) }.compactMap { ResearchCatalog.byID[$0]?.name },
                            cost: (cost / 10).rounded() * 10, progress: ((s.researchProgress[item.id] ?? 0) / max(cost, 1) * 100).rounded() / 100,
                            published: s.year >= item.year && !item.isExotic, ahead: item.year > s.year + 0.5, result: s.researchResults[item.id])
    }

    static func == (a: ResearchCard, b: ResearchCard) -> Bool {
        a.item.id == b.item.id && a.done == b.done && a.queuedAt == b.queuedAt && a.missing == b.missing && a.cost == b.cost
            && a.progress == b.progress && a.published == b.published && a.ahead == b.ahead && a.result == b.result
    }

    private var accent: Color { item.isExotic ? .purple : .pink }

    var body: some View {
        Button {
            guard !done else { return }
            if queuedAt != nil {
                store.mutate { $0.researchQueue.removeAll { $0 == item.id } }
            } else {
                store.mutate { $0.queueResearch(item.id) }
                store.show(missing.isEmpty ? "Queued \(item.name)" : "Queued \(item.name) (prerequisites will be researched first)")
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    if item.isExotic { Image(systemName: "atom").foregroundStyle(.purple) }
                    Text(item.name).font(.headline).lineLimit(2)
                    Spacer()
                    if done { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
                    else if let q = queuedAt { Pill(text: q == 0 ? "Researching" : "Queued #\(q + 1)", color: accent) }
                }
                HStack(spacing: 6) {
                    Pill(text: item.year >= 2027 ? "Future" : "\(Int(item.year))", color: item.year >= 2027 ? .purple : .secondary)
                    if let r = result {
                        resultPill(r)
                    } else if !done {
                        Pill(text: "\(Fmt.count(cost)) RP", color: .blue)
                        if item.isExotic { Pill(text: "Unique to you", color: .purple) }
                        else if published && item.category != .frontier { Pill(text: "Published −50%", color: .green) }
                        else if ahead { Pill(text: "Ahead of its time", color: .orange) }
                    }
                }
                Text(item.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(5).fixedSize(horizontal: false, vertical: true)
                let r = result ?? 1
                ForEach(item.effects.map { (ResearchCatalog.describe($0, r: r), $0.isDownside) }, id: \.0) { line in
                    Label(line.0, systemImage: line.1 ? "arrow.down.right" : "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(line.1 ? .orange : .green)
                }
                if let t = item.tradeoff {
                    Label(t, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !done {
                    Text(item.isExotic ? "Outcome uncertain: 0.35–1.8× of the promise" : "Typical outcome: 0.55–1.5× of the paper")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                if !missing.isEmpty && !done {
                    Text("Requires: \(missing.joined(separator: ", "))")
                        .font(.caption2).foregroundStyle(.orange)
                }
                if progress > 0 && !done { Meter(value: progress, tint: accent, height: 5) }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(done ? AnyShapeStyle(Color.green.opacity(0.07)) : AnyShapeStyle(.background.secondary), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(queuedAt != nil ? accent.opacity(0.7) : (item.isExotic ? Color.purple.opacity(0.4) : Color.secondary.opacity(0.2)),
                                                                     lineWidth: queuedAt != nil ? 2 : (item.isExotic ? 1 : 0.5)))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .opacity(done ? 0.8 : 1)
    }

    private func resultPill(_ r: Double) -> some View {
        let (text, color): (String, Color) = switch r {
        case ..<0.8: ("Weak result \(Fmt.trim(r, 2))×", .red)
        case ..<1.12: ("As expected \(Fmt.trim(r, 2))×", .secondary)
        default: ("Beat the paper \(Fmt.trim(r, 2))×", .green)
        }
        return Pill(text: text, color: color, symbol: "flask.fill")
    }
}
