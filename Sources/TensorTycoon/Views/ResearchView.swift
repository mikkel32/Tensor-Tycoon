import SwiftUI

struct ResearchView: View {
    @Environment(GameStore.self) private var store
    @State private var hideDone = true
    @State private var filter: ResearchCategory? = nil
    @State private var query = ""
    /// The tree as a graph (default) or the original card grid; remembered between sessions.
    @AppStorage("researchTreeMode") private var treeMode = "graph"

    var body: some View {
        let s = store.game
        let rate = Sim.researchRate(s, store.derived.bonuses) * FoundingKit.researchMultiplier(s) + s.rsiRPToday + s.swarmRPToday
        let core = ResearchCatalog.core + ResearchCatalog.lateGame + ResearchCatalog.capabilityTech
        let doneCount = core.filter { s.researched.contains($0.id) }.count
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        Page(title: "Research", subtitle: "Researchers generate research points (RP); compute multiplies their output. Every technique is an experiment: in your lab it can land better or worse than the paper. Leftover points roll into the next project, and idle research feeds your signature programme, so nothing is wasted.", screen: .research) {
            ScreenHint(.research)
            SignatureCard(state: s)
            RLLabCard(state: s)   // 3.5
            HStack(alignment: .top, spacing: Theme.gap) {
                QueueCard(state: s, rate: rate)
                CapacityCard(state: s, rate: rate)
                    .frame(width: 400)
            }

            UniqueTechSection(state: s)
            if s.year >= ResearchLab.lateDirectorYear || s.programLevelsTotal > 0 || !s.moonshots.isEmpty {
                FrontierProgramsSection(state: s)
            }
            RivalIntelSection(state: s)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Research tree").font(.title2.weight(.bold))
                    Text("\(doneCount) of \(core.count) techniques researched").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
                if treeMode == "grid" {
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
                Picker("View", selection: $treeMode) {
                    Label("Graph", systemImage: "point.3.connected.trianglepath.dotted").tag("graph")
                    Label("Grid", systemImage: "square.grid.2x2").tag("grid")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
                .help("Show the research tree as a dependency graph or as cards by category.")
            }

            if treeMode != "grid" {
                TechTreeView(state: s)
            } else {
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
}

// MARK: - Signature secret

private struct SignatureCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var share = SignatureSecret.defaultShare
    @State private var loaded = false

    var body: some View {
        let s = state
        if let sig = s.signature {
            let level = s.signatureLevel
            let maxed = level >= SignatureSecret.maxLevel
            let need = maxed ? 0 : SignatureSecret.cost(toLevel: level + 1)
            let perDay = s.signatureRPToday
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: sig.symbol)
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("PROJECT \(sig.codename)").font(.caption.monospaced().weight(.bold)).foregroundStyle(.purple)
                            Pill(text: "Signature secret", color: .purple, symbol: "crown.fill")
                        }
                        Text(sig.title).font(.title2.weight(.bold))
                        Text(sig.tagline).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 3) {
                            ForEach(1...SignatureSecret.maxLevel, id: \.self) { l in
                                Image(systemName: l <= level ? "star.fill" : "star")
                                    .foregroundStyle(l <= level ? Color.yellow : .secondary)
                            }
                        }
                        Text(maxed ? "Mastered" : "Level \(level) of \(SignatureSecret.maxLevel)").font(.callout.weight(.semibold))
                    }
                }
                if !maxed {
                    VStack(alignment: .leading, spacing: 4) {
                        Meter(value: s.signatureProgress / max(1, need), tint: .purple, height: 10)
                        Text("\(Fmt.count(s.signatureProgress)) / \(Fmt.count(need)) RP to level \(level + 1)"
                             + (perDay > 0 ? " · \(Fmt.trim(perDay, 1)) RP/day · about \(Fmt.days((need - s.signatureProgress) / perDay)) to go" : " · no research going in"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Working for you now").font(.caption.weight(.semibold))
                        ForEach(sig.perLevel.map { ResearchCatalog.describe($0, r: Double(level)) }, id: \.self) { line in
                            Label(line, systemImage: "arrow.up.right").font(.caption).foregroundStyle(.green)
                        }
                        if !maxed {
                            Text("Each level adds " + sig.perLevel.map { ResearchCatalog.describe($0) }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Capstones").font(.caption.weight(.semibold))
                        capstone(3, sig.capstone3Text, unlocked: level >= 3)
                        capstone(5, sig.capstone5Text, unlocked: level >= 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !maxed {
                    HStack {
                        Text("Share of research").font(.caption.weight(.semibold))
                        Slider(value: $share, in: 0...0.75, step: 0.05)
                            .frame(maxWidth: 240)
                        Text("\(Int((share * 100).rounded()))%").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                        Button("Set") { store.mutate { $0.setSignatureShare(share) } }
                            .disabled(abs(share - s.signatureShare) < 0.001)
                        Spacer()
                        Text("Idle research always flows here.").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(LinearGradient(colors: [.purple.opacity(0.18), .indigo.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.purple.opacity(0.4), lineWidth: 1))
            .onAppear {
                guard !loaded else { return }
                loaded = true
                share = s.signatureShare
            }
        } else {
            SignatureChooser()
        }
    }

    private func capstone(_ n: Int, _ text: String, unlocked: Bool) -> some View {
        Label("Level \(n): \(text)", systemImage: unlocked ? "checkmark.seal.fill" : "lock.fill")
            .font(.caption)
            .foregroundStyle(unlocked ? Color.purple : .secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// For labs founded before signature secrets existed.
private struct SignatureChooser: View {
    @Environment(GameStore.self) private var store
    @State private var pick: SignatureSecret = .cortex

    var body: some View {
        Card {
            CardHeader("Choose your signature secret", symbol: "crown.fill",
                       subtitle: "Every lab now has one research programme nobody else can copy. It starts at level 1 and grows with the research you give it.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                ForEach(SignatureSecret.allCases) { sig in
                    Button { pick = sig } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sig.symbol).foregroundStyle(pick == sig ? Color.purple : .secondary).frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sig.title).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                Text(sig.codename).font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(pick == sig ? Color.purple.opacity(0.15) : Color.secondary.opacity(0.06), in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(pick == sig ? Color.purple : .clear, lineWidth: 1.5))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(pick.blurb).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Every level: " + pick.perLevel.map { ResearchCatalog.describe($0) }.joined(separator: " · ")).font(.caption)
            Text("Level 3: \(pick.capstone3Text)  ·  Level 5: \(pick.capstone5Text)").font(.caption).foregroundStyle(.purple)
            HStack {
                Spacer()
                Button("Start Project \(pick.codename)") {
                    store.act("Project \(pick.codename) started") { $0.chooseSignature(pick) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Queue

private struct QueueCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let rate: Double

    var body: some View {
        let s = state
        let qRate = ResearchLab.queueRate(s, total: rate)
        var flow = "\(Fmt.trim(rate, 1)) RP/day"
        if s.signatureRPToday > 0 { flow += " · \(Fmt.trim(s.signatureRPToday, 1)) to your signature" }
        if s.studyRPToday > 0 { flow += " · \(Fmt.trim(s.studyRPToday, 1)) to alien study" }
        return Card {
            CardHeader(title: "Research queue", symbol: "lightbulb.fill", subtitle: flow) {
                HelpButton(term: .researchPoints)
                Toggle("Research director", isOn: Binding(get: { s.autoResearch }, set: { v in store.mutate { $0.setAutoResearch(v) } }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Keeps the queue full with the best value for money under your focus.")
            }
            if s.autoResearch {
                HStack(spacing: 10) {
                    Picker("Focus", selection: Binding(get: { s.focus }, set: { v in store.mutate { $0.setResearchFocus(v) } })) {
                        ForEach(ResearchFocus.allCases) { f in Label(f.title, systemImage: f.symbol).tag(f) }
                    }
                    .frame(maxWidth: 240)
                    Text(s.focus.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if !ResearchLab.focusHasOptions(s) {
                    Text("Nothing in \(s.focus.title.lowercased()) is open to research right now, so the director refines breakthroughs and picks general work instead.")
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
            }
            if s.researchQueue.isEmpty {
                Text(s.autoResearch ? "Nothing worth starting yet — idle research goes to your signature programme." : "Idle! Pick something below, or turn on the research director.")
                    .font(.callout)
                    .foregroundStyle(s.autoResearch ? Color.secondary : Color.orange)
            }
            ForEach(Array(s.researchQueue.enumerated()), id: \.element) { i, entry in
                QueueRow(state: s, entry: entry, index: i, count: s.researchQueue.count, rate: qRate)
            }
            HStack {
                Button("Queue all published") {
                    var n = 0
                    store.mutate { n = $0.queueAllPublished() }
                    store.show(n == 0 ? "Nothing published left to queue" : "Queued \(n) published techniques")
                }
                .help("Queue every published technique you can start now, cheapest first.")
                Spacer()
                if s.eurekas > 0 {
                    Label("\(s.eurekas) eureka moment\(s.eurekas == 1 ? "" : "s")", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct QueueRow: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let entry: String
    let index: Int
    let count: Int
    let rate: Double

    var body: some View {
        let s = state
        let cost = ResearchLab.entryCost(s, entry)
        let done = s.researchProgress[entry] ?? 0
        let exotic = entry.hasPrefix(Breakthroughs.refinePrefix) || (ResearchCatalog.byID[entry]?.isExotic ?? false)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(index == 0 ? "Now" : "\(index + 1).")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
                Text(ResearchLab.entryName(entry)).font(index == 0 ? Font.headline : Font.callout).lineLimit(1)
                if exotic { Image(systemName: "atom").foregroundStyle(.purple) }
                Spacer()
                if let eta = ResearchLab.eta(s, entry: entry, rate: rate) {
                    Text(Fmt.days(eta)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Button { store.mutate { $0.moveResearch(entry, by: -1) } } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.borderless)
                    .disabled(index == 0)
                    .accessibilityLabel("Move up")
                Button { store.mutate { $0.moveResearch(entry, by: 1) } } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.borderless)
                    .disabled(index == count - 1)
                    .accessibilityLabel("Move down")
                Button { store.mutate { $0.researchQueue.removeAll { $0 == entry } } } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove from queue")
            }
            if index == 0 || done > 0 {
                Meter(value: done / max(1, cost), tint: exotic ? .purple : .pink, height: index == 0 ? 8 : 4)
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
            let bonuses = s.bonuses
            let kit = FoundingKit.researchMultiplier(s)
            let nowRP = Sim.researchRate(s, bonuses) * kit
            ForEach(pools) { p in
                ResearchChipRow(pool: p, assigned: s.researchChips[p.accel.id] ?? 0, otherPF: Sim.researchPF(s.researchChips.filter { $0.key != p.accel.id }),
                                rpWith: { n in
                                    var t = s
                                    t.researchChips[p.accel.id] = n
                                    return rate + (Sim.researchRate(t, bonuses) * kit - nowRP)
                                })
            }
            let capPF = Sim.researchComputeCapPF
            let havePF = Sim.researchPF(s.researchChips)
            HStack {
                Button("Use enough for the full boost") {
                    var n = 0
                    store.mutate { n = $0.assignResearchChipsForCap() }
                    store.show(n == 0 ? "Nothing more to add: the boost is full or no chips are free" : "Put \(Fmt.int(n)) idle chips on experiments")
                }
                .disabled(havePF >= capPF)
                .font(.caption)
                Text(havePF >= capPF ? "Full boost reached" : "\(Fmt.trim(havePF, 0)) of \(Fmt.trim(capPF, 0)) PF (bf16) for the full boost")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Toggle("Director uses idle chips", isOn: Binding(get: { !s.directorChipsOff }, set: { v in store.mutate { $0.directorChipsOff = !v } }))
                .toggleStyle(.switch).controlSize(.small).font(.caption)
                .help("While the research director is on, it puts idle chips on experiments each day until the boost is full. It never takes chips that are in use, and training or serving can take them back.")
            Text("Compute multiplies your researchers' output, up to 4× at the full boost, with only a little on top after that. Better researchers and more experiment compute also make results land above the paper's promise.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
    /// Petaflops other chip kinds already put on research.
    let otherPF: Double
    /// Research points per day with this many of these chips on research.
    let rpWith: (Int) -> Double
    @State private var value = 0

    var body: some View {
        let top = assigned + pool.free
        let cap = max(1, Int(((Sim.researchComputeCapPF - otherPF) * 1000 / max(0.001, pool.accel.bf16)).rounded(.up)))
        // Coarse steps far from the cap, fine ones near it.
        let step = max(1, min(top / 16, cap / 10))
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(pool.accel.name).font(.caption).lineLimit(1)
                Spacer()
                Stepper("\(Fmt.int(value))", value: $value, in: 0...top, step: step)
                    .font(.caption.monospacedDigit())
                Button("Set") { store.mutate { $0.researchChips[pool.accel.id] = value } }
                    .disabled(value == assigned)
                    .font(.caption)
            }
            Text("\(Fmt.trim(rpWith(value), 1)) RP/day with \(Fmt.int(value)) · full boost at \(Fmt.int(cap)) of these\(top < cap ? " (you have \(Fmt.int(top)) free or assigned)" : "")")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .onAppear { value = assigned }
    }
}

// MARK: - Unique breakthroughs

private func rarityColor(_ r: Rarity) -> Color {
    switch r {
    case .rare: .blue
    case .epic: .purple
    case .legendary: .orange
    }
}

private func raritySymbol(_ r: Rarity) -> String {
    switch r {
    case .rare: "diamond.fill"
    case .epic: "sparkles"
    case .legendary: "crown.fill"
    }
}

private struct UniqueTechSection: View {
    let state: GameState

    var body: some View {
        let s = state
        let items = s.exoticOwned.compactMap { ResearchCatalog.byID[$0] }.sorted { $0.year < $1.year }
        let done = items.filter { s.researched.contains($0.id) }.count
        let fusions = Breakthroughs.fusions.filter { s.exoticOwned.contains($0.a) || s.exoticOwned.contains($0.b) }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Your lab's unique breakthroughs", systemImage: "atom").font(.title2.weight(.bold))
                Spacer()
                Text("\(done) of \(items.count) completed").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text("Ideas only your team is chasing. They're already stronger in your hands than on paper; refine finished ones to mastery II and III, complete both halves of a pair to unlock a fusion, or license them to other labs for cash. A brilliant team keeps coming up with new ones.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if items.isEmpty {
                Text("No unique research yet.").font(.callout).foregroundStyle(.tertiary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(items) { item in UniqueCard(item: item, state: s) }
                }
            }
            if !fusions.isEmpty {
                Text("Fusions").font(.headline).padding(.top, 4)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(fusions) { f in FusionCard(fusion: f, state: s) }
                }
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [.purple.opacity(0.16), .indigo.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.purple.opacity(0.35), lineWidth: 1))
    }
}

private struct UniqueCard: View {
    @Environment(GameStore.self) private var store
    let item: ResearchItem
    let state: GameState

    var body: some View {
        let s = state
        let done = s.researched.contains(item.id)
        let rarity = Breakthroughs.rarity(item.id)
        let color = rarityColor(rarity)
        let mastery = s.exoticMastery[item.id] ?? 1
        let queued = s.researchQueue.firstIndex(of: item.id)
        let refineEntry = Breakthroughs.refineID(item.id)
        let refining = s.researchQueue.contains(refineEntry)
        let cost = Sim.researchCost(item, year: s.year)
        let result = s.researchResults[item.id] ?? 1
        let up = (done ? result : 1) * Breakthroughs.masteryMultiplier(done ? mastery : 1)
        let down = done ? result : 1
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                Image(systemName: "atom").foregroundStyle(color)
                Text(item.name).font(.headline).lineLimit(2)
                Spacer()
                Pill(text: rarity.title, color: color, symbol: raritySymbol(rarity))
            }
            HStack(spacing: 6) {
                if done {
                    Pill(text: "Mastery \(ResearchLab.roman(mastery))", color: color, symbol: "star.fill")
                    Pill(text: "\(Fmt.trim(result, 2))× result", color: result >= 1.12 ? .green : (result < 0.8 ? .red : .secondary), symbol: "flask.fill")
                } else if let q = queued {
                    Pill(text: q == 0 ? "Researching" : "Queued #\(q + 1)", color: color)
                } else {
                    Pill(text: "\(Fmt.count(cost)) RP", color: .blue)
                    if item.year > s.year + 0.5 { Pill(text: "Ahead of its time", color: .orange) }
                }
            }
            Text(item.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(5).fixedSize(horizontal: false, vertical: true)
            ForEach(item.shownEffects.map { (ResearchCatalog.describe($0, r: $0.isDownside ? down : up), $0.isDownside) }, id: \.0) { line in
                Label(line.0, systemImage: line.1 ? "arrow.down.right" : "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(line.1 ? .orange : .green)
            }
            if let t = item.tradeoff {
                Label(t, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let f = Breakthroughs.fusion(for: item.id), let p = Breakthroughs.partner(of: item.id) {
                let active = s.researched.contains(f.a) && s.researched.contains(f.b)
                let partnerName = ResearchCatalog.byID[p]?.name ?? p
                Label(active ? "Fusion active: \(f.name)" : "Pairs with \(partnerName)\(s.exoticOwned.contains(p) ? "" : " (not yours yet)") → \(f.name)",
                      systemImage: active ? "link.circle.fill" : "link")
                    .font(.caption2)
                    .foregroundStyle(active ? Color.purple : .secondary)
            }
            if done {
                HStack {
                    if mastery < Breakthroughs.maxMastery {
                        Button(refining ? "Refining…" : "Refine to \(ResearchLab.roman(mastery + 1)) · \(Fmt.count(Breakthroughs.refineCost(item, toLevel: mastery + 1))) RP") {
                            store.act("Queued: refine \(item.name)") { $0.queueRefine(item.id) }
                        }
                        .disabled(refining)
                    } else {
                        Label("Fully mastered", systemImage: "crown.fill").font(.caption).foregroundStyle(color)
                    }
                    Spacer()
                    Menu("License") {
                        ForEach(ResearchLab.licenseBuyers(s, tech: item.id)) { b in
                            Button("\(b.name): \(Fmt.money(b.upfront)) + \(Fmt.money(b.royalty))/mo\(b.rival ? " (rival lab)" : "")") {
                                store.act("Licensed \(item.name)") { $0.licenseExotic(item.id, to: b.id) }
                            }
                        }
                    }
                    .fixedSize()
                    .help("Sell the technique for cash. Rival labs that buy it put it in their models.")
                }
                .controlSize(.small)
            } else {
                HStack {
                    Spacer()
                    Button(queued == nil ? "Research" : "Remove from queue") {
                        if queued == nil {
                            store.mutate { $0.queueResearch(item.id) }
                        } else {
                            store.mutate { $0.researchQueue.removeAll { $0 == item.id } }
                        }
                    }
                    .controlSize(.small)
                }
            }
            if !done, let p = s.researchProgress[item.id], p > 0 {
                Meter(value: p / max(1, cost), tint: color, height: 5)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(done ? AnyShapeStyle(color.opacity(0.08)) : AnyShapeStyle(.background.secondary), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(queued != nil ? 0.8 : 0.4), lineWidth: queued != nil ? 2 : 1))
    }
}

private struct FusionCard: View {
    let fusion: Fusion
    let state: GameState

    var body: some View {
        let s = state
        let active = s.researched.contains(fusion.a) && s.researched.contains(fusion.b)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: active ? "link.circle.fill" : "link").foregroundStyle(active ? Color.purple : .secondary)
                Text(fusion.name).font(.headline)
                Spacer()
                Pill(text: active ? "Active" : "Incomplete", color: active ? .purple : .secondary)
            }
            ForEach([fusion.a, fusion.b], id: \.self) { id in
                let have = s.exoticOwned.contains(id)
                let done = s.researched.contains(id)
                Label("\(ResearchCatalog.byID[id]?.name ?? id)\(have ? "" : " — not yours yet")",
                      systemImage: done ? "checkmark.circle.fill" : (have ? "circle" : "questionmark.circle"))
                    .font(.caption)
                    .foregroundStyle(done ? Color.green : .secondary)
            }
            Text(fusion.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(fusion.effects.map { ResearchCatalog.describe($0) }.joined(separator: " · ")).font(.caption2).foregroundStyle(active ? Color.green : .secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(active ? Color.purple.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Frontier programmes & moonshots (3.4)

private struct FrontierProgramsSection: View {
    let state: GameState

    var body: some View {
        let s = state
        let moonshots = s.moonshots.filter { $0.status != .offered && $0.status != .declined }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Frontier programmes", systemImage: "sparkles").font(.title2.weight(.bold))
                Spacer()
                Text("\(s.programLevelsTotal) levels completed").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text("Open-ended research for when the tree runs dry. Every level costs more than the last and adds a little less, but never nothing. The research director queues them by itself once nothing better is left.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(FrontierProgram.all) { p in ProgramCard(program: p, state: s) }
            }
            if !moonshots.isEmpty {
                Text("Moonshots").font(.headline).padding(.top, 4)
                ForEach(moonshots) { m in MoonshotRow(moonshot: m, state: s) }
            }
        }
        .padding(16)
        .background(Color.pink.opacity(0.06), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.pink.opacity(0.3), lineWidth: 1))
    }
}

private struct ProgramCard: View {
    @Environment(GameStore.self) private var store
    let program: FrontierProgram
    let state: GameState

    var body: some View {
        let s = state
        let p = program
        let level = s.programLevel(p.id)
        let queued = s.researchQueue.firstIndex(of: p.entry)
        let cost = p.cost(level: level + 1)
        let done = s.researchProgress[p.entry] ?? 0
        let buttonLabel: String = queued.map { $0 == 0 ? "Researching" : "Queued #\($0 + 1)" } ?? "Queue level \(level + 1)"
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: p.symbol).foregroundStyle(.pink)
                Text(p.name).font(.headline).lineLimit(2)
                Spacer()
                Pill(text: "Level \(level)", color: level > 0 ? .pink : .secondary, symbol: "star.fill")
            }
            Text(p.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(4).fixedSize(horizontal: false, vertical: true)
            ForEach(p.effects.map { ResearchCatalog.describe($0, r: FrontierProgram.strength(max(1, level))) }, id: \.self) { line in
                Label(line, systemImage: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(level > 0 ? Color.green : .secondary)
            }
            if p.isOpen(s) {
                HStack {
                    Text("Next: \(Fmt.count(cost)) RP for +\(Int((FrontierProgram.marginal(level + 1) * 100).rounded()))% of level 1")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    Button(buttonLabel) {
                        store.act("Queued: \(p.name) level \(level + 1)") { $0.queueProgram(p.id) }
                    }
                    .disabled(queued != nil)
                    .controlSize(.small)
                }
                if done > 0 {
                    Meter(value: done / max(1, cost), tint: .pink, height: 5)
                }
            } else {
                Text(s.year < p.opens ? "Opens in \(Int(p.opens))." : "Needs \(ResearchCatalog.byID[p.prereq]?.name ?? p.prereq).")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.pink.opacity(queued != nil ? 0.8 : 0.3), lineWidth: queued != nil ? 2 : 1))
    }
}

private struct MoonshotRow: View {
    let moonshot: Moonshot
    let state: GameState

    var body: some View {
        let m = moonshot
        HStack(spacing: 10) {
            Image(systemName: m.def?.symbol ?? "sparkles").foregroundStyle(.teal).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.def?.name ?? m.id).font(.callout.weight(.semibold))
                Text(Moonshots.statusLine(m, state)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
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
        case .skill(_, let v), .domain(_, let v):
            return v < 0
        case .unlock, .product:
            return false
        }
    }
}

/// A technique's card: shown in the grid view and as the detail of the graph's selection (TechTreeView).
struct ResearchCard: View, Equatable {
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
                        else if published && cost < item.cost { Pill(text: "Published −\(Int(((1 - cost / item.cost) * 100).rounded()))%", color: .green) }
                        else if ahead { Pill(text: "Ahead of its time", color: .orange) }
                    }
                }
                Text(item.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(5).fixedSize(horizontal: false, vertical: true)
                let r = result ?? 1
                ForEach(item.shownEffects.map { (ResearchCatalog.describe($0, r: r), $0.isDownside) }, id: \.0) { line in
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
                    Text(item.isExotic ? "Outcome uncertain: 0.4–1.8× of the promise" : (published ? "Published code helps: 0.75–1.5× of the paper" : "Typical outcome: 0.6–1.5× of the paper"))
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
