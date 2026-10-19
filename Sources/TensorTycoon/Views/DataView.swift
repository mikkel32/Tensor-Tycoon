import SwiftUI

/// 3.6: the data hub — inventory with quality radars, the market, the processing pipeline, annotation, synthetic data,
/// and contamination detection & rivals' data access.
struct DataView: View {
    @Environment(GameStore.self) private var store
    @State private var tab: DataTab = .inventory
    @State private var selected: String?

    enum DataTab: String, CaseIterable, Identifiable {
        case inventory = "Inventory", market = "Market", pipeline = "Pipeline", annotation = "Annotation", synthetic = "Synthetic", rivals = "Detection & rivals"
        var id: String { rawValue }
    }

    var body: some View {
        let s = store.game
        let b = s.bonuses
        let active = s.dataSources.compactMap { DataCatalog.byID[$0] }
        let tokens = Physics.availableTokensT(s.dataSources.sorted(), y: s.year, bonuses: b) + DataEconomy.extraUniqueT(s)
        let risk = active.reduce(0) { $0 + $1.legalRisk } + Double(s.dataEco.holdings.filter { $0.active && $0.quality.provenance < 0.5 }.count) * 0.2
        Page(title: "Training Data", subtitle: "Models are what they eat. Unique tokens let you train bigger without repeating; relevant, high-quality tokens raise the skills a model is built for.") {
            HStack(spacing: 12) {
                StatTile(title: "Unique tokens", value: Fmt.tokens(tokens), detail: b.dataTokens > 0 ? "Incl. +\(Int(b.dataTokens * 100))% from data research" : "Text you can train on", symbol: "text.word.spacing", tint: .blue)
                StatTile(title: "Datasets", value: "\(active.count + s.dataEco.holdings.filter(\.active).count)", detail: "\(s.dataEco.holdings.filter(\.exclusive).count) exclusive", symbol: "externaldrive.fill", tint: .purple)
                StatTile(title: "Data bill", value: "\(Fmt.money(Economy.dataMonthlyCost(s)))/mo", detail: "Licences, annotation, storage", symbol: "doc.text.fill", tint: .orange)
                StatTile(title: "Legal risk", value: risk > 0.3 ? "High" : (risk > 0.05 ? "Moderate" : "Low"), detail: "Copyright & provenance", symbol: "exclamationmark.shield.fill", tint: risk > 0.3 ? .red : .green)
            }
            Picker("", selection: $tab) {
                ForEach(DataTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            switch tab {
            case .inventory: inventory(s)
            case .market: market(s)
            case .pipeline: pipeline(s)
            case .annotation: annotation(s)
            case .synthetic: synthetic(s)
            case .rivals: rivals(s)
            }
        }
    }

    // MARK: Inventory

    @ViewBuilder private func inventory(_ s: GameState) -> some View {
        let items = DataEconomy.inventory(s)
        let pick = items.first { $0.id == selected } ?? items.first
        HStack(alignment: .top, spacing: 14) {
            Card {
                CardHeader("Inventory", symbol: "tray.full.fill", subtitle: "Original sources and your datasets. Select one for its quality profile.")
                ForEach(items) { it in
                    Button {
                        selected = it.id
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: it.kind.symbol).frame(width: 18).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(it.name).font(.callout).lineLimit(1)
                                Text("\(it.kind.label) · \(it.term)").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if it.holding?.active == false { Pill(text: "Inactive", color: .secondary) }
                            Text(Fmt.tokens(it.tokensT)).font(.caption.monospacedDigit())
                            Text("Q\(Int(it.quality.effective * 100))").font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(it.quality.effective > 0.7 ? .green : (it.quality.effective > 0.45 ? .primary : .orange))
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(pick?.id == it.id ? Color.accentColor.opacity(0.08) : .clear, in: .rect(cornerRadius: 6))
                }
            }
            .frame(minWidth: 380)
            if let it = pick {
                Card {
                    CardHeader(it.name, symbol: it.kind.symbol, subtitle: "\(it.kind.label) · \(Fmt.tokens(it.tokensT)) · effective quality \(Int(it.quality.effective * 100))")
                    QualityRadar(quality: it.quality)
                        .frame(height: 220)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 4) {
                        ForEach(it.quality.dims, id: \.0) { dim in
                            HStack {
                                Text(dim.0).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(dim.1 * 100))").font(.caption.monospacedDigit())
                                    .foregroundStyle((dim.2 ? dim.1 : 1 - dim.1) < 0.4 ? .orange : .primary)
                            }
                        }
                    }
                    let rel = DataEconomy.relevance(DataEconomy.Entry(id: it.id, name: it.name, kind: it.kind, focus: it.holding?.focus, uniqueT: it.tokensT, quality: it.quality, synthetic: false))
                    Text("Teaches most: " + CapDomain.allCases.sorted { rel[$0.index] > rel[$1.index] }.prefix(3).map(\.label).joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                    if it.quality.provenance < 0.5 { Label("Poor provenance: a lawsuit is likely, more so under a copyright law.", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red) }
                    if it.quality.contamination > 0.5 { Label("High contamination risk: benchmark items are likely inside.", systemImage: "drop.triangle.fill").font(.caption).foregroundStyle(.orange) }
                    HStack {
                        if it.legacy {
                            if it.id != "web" {
                                Button("Stop using") { store.act("Removed \(it.name)") { $0.toggleData(it.id) } }.buttonStyle(.bordered)
                            }
                        } else if let h = it.holding {
                            if h.term == .licence || h.term == .perRun {
                                Button("Renew") { store.act("Renewed \(h.name)") { DataEconomy.renew(&$0, h.id) } }.buttonStyle(.bordered)
                            }
                            Button(h.term == .licence || h.term == .partnership ? "End it" : "Delete") {
                                store.act("Dropped \(h.name)") { DataEconomy.drop(&$0, h.id) }
                            }
                            .buttonStyle(.bordered).tint(.secondary)
                        }
                        Spacer()
                        Button("Process…") { tab = .pipeline }.buttonStyle(.link)
                    }
                }
            }
        }
        Text("Older saves: your existing data sources are the start of this inventory, with their training effects unchanged until you process them. Runs snapshot their data when they start.")
            .font(.caption).foregroundStyle(.tertiary)
    }

    // MARK: Market

    @ViewBuilder private func market(_ s: GameState) -> some View {
        Text("Standard sources").font(.headline)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
            ForEach(DataCatalog.all) { src in
                let on = s.dataSources.contains(src.id)
                let available = s.year >= src.available
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(src.name).font(.headline)
                        Spacer()
                        if on { Pill(text: "In use", color: .green, symbol: "checkmark") }
                        else if !available { Pill(text: "From \(Int(src.available))", color: .secondary) }
                    }
                    Text(src.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        if src.tokensT(s.year) > 0 { Pill(text: "\(Fmt.tokens(src.tokensT(s.year))) tokens", color: .blue) }
                        if src.quality > 0 { Pill(text: "+\(Fmt.trim(src.quality, 2)) quality", color: .purple) }
                        if src.code > 0 { Pill(text: "+code", color: .teal) }
                        if src.reasoning > 0 { Pill(text: "+reasoning", color: .pink) }
                        if src.arena > 0 { Pill(text: "+\(Int(src.arena)) Elo", color: .orange) }
                        if src.legalRisk > 0.1 { Pill(text: "Legal risk", color: .red, symbol: "exclamationmark.triangle.fill") }
                    }
                    HStack {
                        Text(src.free ? "Free" : (src.upfront > 0 ? "\(Fmt.money(src.upfront)) one-time" : "\(Fmt.money(src.monthly))/month"))
                            .font(.callout.weight(.semibold))
                        Spacer()
                        if src.id != "web" {
                            Button(on ? "Stop using" : (src.free ? "Use" : "License")) {
                                store.act(on ? "Removed \(src.name)" : "Added \(src.name)") { $0.toggleData(src.id) }
                            }
                            .buttonStyle(.bordered)
                            .tint(on ? .secondary : .accentColor)
                            .disabled(!available && !on)
                        }
                    }
                }
                .cardStyle()
            }
        }
        Text("Datasets for sale").font(.headline)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
            ForEach(DataMarketCatalog.market.filter { s.year >= $0.available - 1 }) { def in
                let held = s.dataEco.holdings.contains { $0.source == def.id && $0.active }
                let holder = DataEconomy.exclusiveHolder(s, def.id)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: def.kind.symbol).foregroundStyle(.secondary)
                        Text(def.name).font(.headline)
                        Spacer()
                        if held { Pill(text: "Held", color: .green, symbol: "checkmark") }
                        else if let holder { Pill(text: "Exclusive to \(holder)", color: .red) }
                        else if s.year < def.available { Pill(text: "From \(Int(def.available))", color: .secondary) }
                    }
                    Text(def.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Pill(text: "\(Fmt.tokens(def.tokensT)) \(def.kind.label.lowercased())", color: .blue)
                        Pill(text: "Quality \(Int(def.quality.effective * 100))", color: .purple)
                        if def.quality.provenance < 0.5 { Pill(text: "Provenance", color: .red, symbol: "exclamationmark.triangle.fill") }
                        if def.quality.contamination > 0.5 { Pill(text: "Contamination", color: .orange) }
                        if def.rivalValue > 0 { Pill(text: "Rivals use it", color: .teal) }
                    }
                    Text("From \(def.seller).").font(.caption2).foregroundStyle(.tertiary)
                    if !held && holder == nil && s.year >= def.available {
                        ForEach(def.terms) { term in
                            HStack {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(term.label).font(.caption.weight(.semibold))
                                    Text(DataEconomy.termDetail(def, term)).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(term == .buy || term == .exclusive ? "Buy" : (term == .partnership ? "Partner" : "License")) {
                                    store.act("Acquired \(def.name)") { DataEconomy.acquire(&$0, def.id, term: term) }
                                }
                                .buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                    }
                }
                .cardStyle()
            }
        }
        Card {
            CardHeader("Rare collections & auctions", symbol: "building.columns.fill", subtitle: "Once in a while a unique archive comes up for sale. Offers and sealed-bid auctions arrive in your inbox; rival labs bid too.")
            let gains = s.dataEco.rivalGains.flatMap { lab, ids in ids.map { (CompetitorCatalog.def(lab).name, DataMarketCatalog.byID[$0]?.name ?? $0) } }
            if gains.isEmpty && s.dataEco.auctionsWon == 0 {
                Text("Nothing has come up yet.").font(.caption).foregroundStyle(.secondary)
            }
            if s.dataEco.auctionsWon > 0 { Text("You've won \(s.dataEco.auctionsWon) auction\(s.dataEco.auctionsWon == 1 ? "" : "s").").font(.caption) }
            ForEach(gains, id: \.1) { g in Text("\(g.0) bought \(g.1).").font(.caption).foregroundStyle(.secondary) }
        }
    }

    // MARK: Pipeline

    @ViewBuilder private func pipeline(_ s: GameState) -> some View {
        Card {
            CardHeader("Processing pipeline", symbol: "line.3.horizontal.decrease.circle.fill", subtitle: "Spend compute (rented H100-hours) and engineering time to raise a dataset's quality. Up to four jobs at once.")
            if s.dataEco.jobs.isEmpty {
                Text("No jobs running.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(s.dataEco.jobs) { j in
                let total = max(1, GameCalendar.daysBetween(j.started, j.done))
                let done = GameCalendar.daysBetween(j.started, s.date)
                HStack {
                    Text("\(j.stage.label): \(j.name)").font(.callout)
                    Spacer()
                    Meter(value: Double(done) / Double(total)).frame(width: 120)
                    Text("\(max(0, total - done))d").font(.caption.monospacedDigit())
                }
            }
        }
        ForEach(DataEconomy.targets(s), id: \.id) { t in
            Card {
                HStack {
                    Image(systemName: t.kind.symbol).foregroundStyle(.secondary)
                    Text(t.name).font(.headline)
                    Spacer()
                    Text("\(Fmt.tokens(t.tokensT)) · Q\(Int(t.quality.effective * 100))").font(.caption.monospacedDigit())
                }
                HStack(spacing: 8) {
                    ForEach(DataStage.allCases) { st in
                        let doneAlready = s.dataEco.applied[t.id, default: []].contains(st.rawValue)
                        let running = s.dataEco.jobs.contains { $0.target == t.id }
                        let locked = st.research.map { !s.researched.contains($0) } ?? false
                        let c = DataEconomy.jobCost(s, tokensT: t.tokensT, stage: st)
                        Button {
                            store.act("\(st.label) started on \(t.name)") { DataEconomy.startJob(&$0, target: t.id, stage: st) }
                        } label: {
                            VStack(spacing: 1) {
                                Text(st.label).font(.caption.weight(.semibold))
                                Text(doneAlready ? "Done" : (locked ? "Needs research" : "\(Fmt.money(c.cost)) · \(c.days)d"))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(doneAlready || running || locked)
                        .help(st.detail + " ~\(Fmt.count(c.gpuHours)) H100-hours.")
                    }
                }
            }
        }
    }

    // MARK: Annotation

    @ViewBuilder private func annotation(_ s: GameState) -> some View {
        Text("Vendors produce data to order every day: preference labels for RLHF, expert demonstrations, robot trajectories. What they deliver is yours to keep.")
            .font(.callout).foregroundStyle(.secondary)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
            ForEach(DataMarketCatalog.vendors) { v in
                let contract = s.dataEco.annotation.first { $0.id == v.id }
                let produced = s.dataEco.holdings.first { $0.id == "an:" + v.id }?.tokensT ?? 0
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: v.kind.symbol).foregroundStyle(.secondary)
                        Text(v.name).font(.headline)
                        Spacer()
                        if contract != nil { Pill(text: "Active", color: .green) }
                        else if s.year < v.available { Pill(text: "From \(Int(v.available))", color: .secondary) }
                    }
                    Text(v.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("\(Fmt.money(v.monthly))/mo per tier · \(Fmt.tokens(v.throughputT)) a month · quality \(Int(v.quality.effective * 100))\(produced > 0 ? " · delivered \(Fmt.tokens(produced))" : "")")
                        .font(.caption2).foregroundStyle(.secondary)
                    Picker("Tier", selection: Binding(get: { contract?.tier ?? 0 },
                                                      set: { t in store.act(t == 0 ? "Contract ended" : "Contract updated") { DataEconomy.setAnnotation(&$0, vendor: v.id, tier: t) } })) {
                        Text("Off").tag(0)
                        ForEach(DataEconomy.tiers, id: \.0) { t in Text("\(t.1) ×\(Fmt.trim(DataEconomy.throughputMult(t.0), 1))").tag(t.0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(s.year < v.available)
                }
                .cardStyle()
            }
        }
    }

    // MARK: Synthetic

    @ViewBuilder private func synthetic(_ s: GameState) -> some View {
        SyntheticCard(state: s)
    }

    // MARK: Detection & rivals

    @ViewBuilder private func rivals(_ s: GameState) -> some View {
        Card {
            CardHeader("Benchmark-contamination detection", symbol: "magnifyingglass.circle.fill", subtitle: "Fewer contamination incidents in your runs. Risky datasets raise them; decontaminated ones lower them.")
            ForEach(Array(DataEconomy.detectionLevels.enumerated()), id: \.offset) { i, lvl in
                HStack {
                    Image(systemName: s.dataEco.detection == i ? "largecircle.fill.circle" : "circle").foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(lvl.name).font(.callout.weight(.semibold))
                        Text(lvl.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(i == 0 ? "Free" : "\(Fmt.money(lvl.setup)) + \(Fmt.money(lvl.monthly))/mo").font(.caption.monospacedDigit())
                    Button("Use") { store.act("Detection: \(lvl.name)") { DataEconomy.setDetection(&$0, i) } }
                        .buttonStyle(.bordered).controlSize(.small).disabled(s.dataEco.detection == i)
                }
            }
        }
        Card {
            CardHeader("Rivals' data access", symbol: "person.2.wave.2.fill", subtitle: "Bigger labs license more. Your exclusive contracts cut them off; rare data they win helps them. The effect on their models is small: at most −0.05 / +0.04 log-compute.")
            ForEach(s.competitors.filter { !$0.acquired && !$0.bankrupt && $0.exitNote.isEmpty }.prefix(10)) { c in
                let a = DataEconomy.rivalAccess(s, c.id)
                let dc = DataEconomy.rivalC(s, c.id)
                HStack {
                    Text(c.def.name).font(.callout).frame(width: 160, alignment: .leading)
                    Meter(value: a, tint: .teal)
                    Text("\(Int(a * 100))%").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                    Text(abs(dc) < 0.0005 ? "—" : String(format: "%+.3f", dc)).font(.caption.monospacedDigit())
                        .foregroundStyle(dc < 0 ? .green : (dc > 0 ? .orange : .secondary)).frame(width: 56, alignment: .trailing)
                }
            }
        }
    }
}

/// Synthetic data generation with your own models.
private struct SyntheticCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var modelID: UUID?
    @State private var focus: CapDomain = .reasoning
    @State private var size = 0.05
    @State private var verified = true

    var body: some View {
        let s = state
        let models = s.models.filter { !$0.preview }.sorted { $0.c > $1.c }
        Card {
            CardHeader("Generate validated synthetic data", symbol: "wand.and.stars", subtitle: "Your own models write training data. Its quality is capped by how good the model is in that domain. Past ~20% of the corpus, model collapse sets in.")
            if !s.bonuses.has(.syntheticData) {
                Text("Research Synthetic Data Pipelines to generate data with your models.").font(.callout).foregroundStyle(.secondary)
            } else if models.isEmpty {
                Text("Train a model first.").font(.callout).foregroundStyle(.secondary)
            } else {
                let m = models.first { $0.id == modelID } ?? models[0]
                Picker("Model", selection: Binding(get: { m.id }, set: { modelID = $0 })) {
                    ForEach(models.prefix(12)) { Text($0.name).tag($0.id) }
                }
                Picker("Domain", selection: $focus) {
                    ForEach(DataEconomy.synthDomains) { Text($0.label).tag($0) }
                }
                Picker("Amount", selection: $size) {
                    Text("10B").tag(0.01)
                    Text("50B").tag(0.05)
                    Text("200B").tag(0.2)
                    Text("1T").tag(1.0)
                }
                .pickerStyle(.segmented)
                Toggle("Verify (filters and judges every sample: +quality, +50% compute)", isOn: $verified)
                let q = DataEconomy.synthQuality(s, model: m, focus: focus, verified: verified)
                let c = DataEconomy.synthCost(s, model: m, tokensT: size, verified: verified)
                HStack {
                    Text("Quality ~\(Int(q * 100)) · \(Fmt.money(c.cost)) · \(c.days) days").font(.callout.monospacedDigit())
                    Spacer()
                    Button("Generate") {
                        let id = m.id, f = focus, t = size, v = verified
                        store.act("Generation started") { DataEconomy.startSynth(&$0, model: id, focus: f, tokensT: t, verified: v) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            ForEach(s.dataEco.synth) { j in
                Text("\(j.modelName): \(Fmt.tokens(j.tokensT)) of \(j.focus.label.lowercased()), ready \(j.done.gameShort)").font(.caption).foregroundStyle(.secondary)
            }
            let synT = s.dataEco.holdings.filter { $0.synthetic && $0.active }.reduce(0) { $0 + $1.tokensT }
            if synT > 0 {
                let share = synT / max(1e-9, Physics.availableTokensT(s.dataSources.sorted(), y: s.year, bonuses: s.bonuses) + DataEconomy.extraUniqueT(s))
                Text("Synthetic data held: \(Fmt.tokens(synT)) (\(Int(share * 100))% of your corpus)").font(.caption)
                    .foregroundStyle(share > 0.2 ? .orange : .secondary)
            }
        }
    }
}

/// An eleven-spoke radar of a dataset's quality. "Bad when high" dimensions are drawn inverted so bigger is always better.
struct QualityRadar: View {
    let quality: DataQuality

    var body: some View {
        let dims = quality.dims
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let r = max(10, min(w, h) / 2 - 26)
            let values = dims.map { $0.2 ? $0.1 : 1 - $0.1 }
            ZStack {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { f in
                    shape(Array(repeating: f, count: dims.count), center: center, r: r).stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                }
                shape(values.map { max(0.03, $0) }, center: center, r: r).fill(Color.purple.opacity(0.18))
                shape(values.map { max(0.03, $0) }, center: center, r: r).stroke(Color.purple, lineWidth: 1.5)
                ForEach(Array(dims.enumerated()), id: \.offset) { i, d in
                    Text(d.2 ? d.0 : "Low " + d.0.lowercased())
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                        .position(point(i, 1, count: dims.count, center: center, r: r + 15))
                }
            }
        }
    }

    private func point(_ i: Int, _ f: Double, count: Int, center: CGPoint, r: Double) -> CGPoint {
        let a = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(count)
        return CGPoint(x: center.x + cos(a) * r * f, y: center.y + sin(a) * r * f)
    }

    private func shape(_ fr: [Double], center: CGPoint, r: Double) -> Path {
        Path { p in
            for (i, f) in fr.enumerated() {
                let pt = point(i, f, count: fr.count, center: center, r: r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
}
