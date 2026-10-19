import SwiftUI

// MARK: - 3.5: model families

/// What a family sheet is about: distil a tier from a teacher, or post-train a model.
enum FamilySheet: Identifiable, Hashable {
    case distill(UUID)
    case postTrain(UUID)

    var id: String {
        switch self {
        case .distill(let id): "d-\(id.uuidString)"
        case .postTrain(let id): "p-\(id.uuidString)"
        }
    }
}

extension View {
    /// Presents the distillation or post-training sheet for `item`.
    func familySheet(_ item: Binding<FamilySheet?>) -> some View {
        sheet(item: item) { which in
            switch which {
            case .distill(let id): DistillSheet(teacherID: id)
            case .postTrain(let id): PostTrainSheet(modelID: id)
            }
        }
    }
}

struct FamiliesView: View {
    @Environment(GameStore.self) private var store
    @State private var sheet: FamilySheet?
    @State private var founder: UUID?

    var body: some View {
        let s = store.game
        let loose = s.models.filter { !$0.retired && !$0.preview && Families.family(of: $0.id, s) == nil }.sorted { $0.index > $1.index }
        Page(title: "Model Families", subtitle: "A lineup, not just a flagship: distil cheaper tiers from your best model, post-train upgrades, and let each tier serve the traffic it's priced for.", screen: .families) {
            ScreenHint(.families)
            if !s.families.jobs.isEmpty { JobsCard(state: s) }
            if s.families.families.isEmpty {
                Card {
                    EmptyStateView(symbol: "square.stack.3d.down.right", title: "No families yet",
                                   message: "Distil a smaller tier from one of your models and a family forms around it: the flagship for hard problems and enterprise, cheaper tiers for the free chat tier and price-sensitive API buyers.",
                                   actionTitle: loose.first.map { "Distil a tier from \($0.name)" } ?? "Open Model Lab") {
                        if let m = loose.first { sheet = .distill(m.id) } else { store.open(.lab) }
                    }
                }
            }
            ForEach(s.families.families) { f in
                FamilyCard(family: f, state: s, sheet: $sheet)
            }
            if !loose.isEmpty {
                Card {
                    CardHeader("Start a family", symbol: "plus.square.on.square", subtitle: "Any model you own can be a flagship. Distilling from it starts the family automatically.")
                    HStack {
                        Picker("Flagship", selection: Binding(get: { founder ?? loose.first?.id }, set: { founder = $0 })) {
                            ForEach(loose) { m in Text("\(m.name) · index \(Fmt.score(m.index))").tag(Optional(m.id)) }
                        }
                        .frame(maxWidth: 360)
                        Button("Start family") {
                            guard let id = founder ?? loose.first?.id else { return }
                            store.act("Family started") { $0.startFamily(id) }
                        }
                        Button("Distil a tier…") { if let id = founder ?? loose.first?.id { sheet = .distill(id) } }
                        Button("Post-train…") { if let id = founder ?? loose.first?.id { sheet = .postTrain(id) } }
                    }
                }
            }
        }
        .familySheet($sheet)
    }
}

/// Distillations, post-training passes and merges in progress.
private struct JobsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("In progress", symbol: "hourglass", subtitle: "Their chips count as training chips on Compute Fleet.")
            ForEach(s.families.jobs) { j in
                let day = Families.perDay(s, accelID: j.accelID, chips: j.chips, bonuses: store.derived.bonuses)
                let left = day > 0 ? max(0, (j.flops - j.done) / day) : .infinity
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: j.kind == .distill ? "arrow.down.right.and.arrow.up.left" : (j.kind == .merge ? "arrow.triangle.merge" : (j.passValue?.symbol ?? "wand.and.stars")))
                            .foregroundStyle(.secondary)
                        Text(j.name).font(.callout.weight(.semibold))
                        if j.paused { Pill("Paused", tone: .warning) }
                        Spacer()
                        Text("\(Fmt.int(j.chips))× \(HardwareCatalog.get(j.accelID)?.name ?? j.accelID) · \(left.isFinite ? "\(Int(left.rounded(.up))) days left" : "stalled") · \(Fmt.money(j.cost)) so far")
                            .font(.caption).foregroundStyle(.secondary)
                        if j.paused {
                            Button("Resume") { store.act("Resumed") { $0.resumeModelJob(j.id) } }.controlSize(.small)
                        }
                        Button("Cancel", role: .destructive) { store.mutate { $0.cancelModelJob(j.id) } }.buttonStyle(.link).font(.caption)
                    }
                    Meter(value: j.progress, tint: j.paused ? .orange : .indigo)
                }
            }
        }
    }
}

struct FamilyCard: View {
    @Environment(GameStore.self) private var store
    let family: ModelFamily
    let state: GameState
    @Binding var sheet: FamilySheet?

    var body: some View {
        let s = state
        let f = family
        let rows = Families.members(f, s)
        let shares = Families.trafficShares(f, s)
        let cannibal = Families.cannibalisation(s, f)
        let flagship = Families.flagship(f, s)
        let lift = flagship.map { Families.generationLift(s, $0) } ?? 1   // 3.8
        Card {
            CardHeader(title: f.name, symbol: "square.stack.3d.down.right.fill",
                       subtitle: Self.subtitle(f, models: rows.count, lift: lift)) {
                if let flagship {
                    Button("Distil a tier…") { sheet = .distill(flagship.id) }
                    Button("Post-train…") { sheet = .postTrain(flagship.id) }
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Tier"); Text("Model"); Text("Index"); Text("Price / 1M"); Text("Serving / 1M"); Text("Traffic"); Text("Serves"); Text("")
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(rows, id: \.model.id) { row in
                    let m = row.model
                    let cost = Families.servingCost(s, m)
                    GridRow {
                        Label(row.member.tier.label, systemImage: row.member.tier.symbol).font(.callout.weight(.semibold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.name).font(.callout)
                            Text("\(Fmt.params(m.design.paramsB)) · \(m.released ? (m.api ? "on sale" : "released") : "unreleased")\(m.passes.isEmpty ? "" : " · \(m.passes.count) pass\(m.passes.count == 1 ? "" : "es")")")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(Fmt.score(m.index)).font(.callout.monospacedDigit())
                        Text(m.api && m.released ? Fmt.price(m.apiPrice) : "—").font(.callout.monospacedDigit())
                        Text(cost > 0 ? Fmt.price(cost) : "—").font(.callout.monospacedDigit())
                            .foregroundStyle(m.api && cost > m.apiPrice ? Color.red : Color.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shares[m.id].map { Fmt.pct($0, decimals: 0) } ?? "—").font(.callout.monospacedDigit())
                            Meter(value: shares[m.id] ?? 0, tint: .indigo, height: 5).frame(width: 70)
                        }
                        Text(Families.segments(s, m).joined(separator: " · ").isEmpty ? "Nothing yet" : Families.segments(s, m).joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        HStack(spacing: 6) {
                            if !m.released {
                                Button("Launch") { store.act("\(m.name) launched") { $0.launch(m.id) } }.controlSize(.small)
                            }
                            Button("Post-train") { sheet = .postTrain(m.id) }.controlSize(.small)
                            Button("Open") { store.focusModelID = m.id; store.open(.models) }.buttonStyle(.link).font(.caption)
                        }
                    }
                }
            }
            DomainsByTier(rows: rows, state: s)
            routingRow(f, s, rows: rows)
            freeTierRow(f, s, rows: rows)
            contractsRow(f, s, rows: rows)
            if !cannibal.isEmpty { cannibalisation(cannibal, rows: rows) }
        }
    }

    /// The card's subtitle (built here: long interpolated strings are slow to type-check inside views).
    static func subtitle(_ f: ModelFamily, models: Int, lift: Double) -> String {
        var t = "Generation \(f.generation) · \(models) model"
        if models != 1 { t += "s" }
        t += " · family brand \(Int(f.brand.rounded()))/100 (up to +\(Int((0.15 * f.brand).rounded()))% API demand for every tier)"
        if f.generation >= 2 { t += "; a new flagship launches on the family name (+\(Int((lift - 1) * 100))% brand gain)" }
        return t
    }

    static func routingText(_ routed: Bool) -> String {
        routed ? "Sold through one router: each API request goes to the member that suits it, and buyers like the single endpoint (+12% in every segment)."
               : "Each member competes for API buyers on its own. Research Model Routing to sell the family through one router."
    }

    /// 3.8: how the family is sold on the API: one router, or members competing for the same buyers.
    @ViewBuilder
    private func routingRow(_ f: ModelFamily, _ s: GameState, rows: [(member: FamilyMember, model: AIModel)]) -> some View {
        let selling = rows.map(\.model).filter { $0.released && $0.api }
        if selling.count >= 2 {
            let routed = store.derived.bonuses.has(.modelRouting)
            let symbol = routed ? "arrow.triangle.branch" : "arrow.triangle.swap"
            Label(Self.routingText(routed), systemImage: symbol)
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func freeTierRow(_ f: ModelFamily, _ s: GameState, rows: [(member: FamilyMember, model: AIModel)]) -> some View {
        if let chat = s.chatModelID, f.has(chat) {
            let options = rows.map(\.model).filter { $0.released && $0.design.instruct && $0.id != chat }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Chat free tier").font(.callout.weight(.semibold))
                    Picker("Served by", selection: Binding(get: { f.freeTierID }, set: { id in store.act(id == nil ? "Free users back on the chat model" : "Free tier rerouted") { $0.setFreeTier(f.id, id) } })) {
                        Text("The chat model (\(Families.model(chat, s)?.name ?? "—"))").tag(UUID?.none)
                        ForEach(options) { m in Text(m.name).tag(Optional(m.id)) }
                    }
                    .frame(maxWidth: 420)
                }
                Text(s.freeTier
                     ? "About \(Fmt.pct(Families.freeShare(s), decimals: 0)) of chat users are on the free tier. Serving them on a cheaper tier cuts their serving bill; the app reads a little weaker to the market (−20% of the quality gap, weighted by the free share). Paying users stay on the chat model."
                     : "Your chat app has no free tier, so every user is a paying user on the chat model.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func contractsRow(_ f: ModelFamily, _ s: GameState, rows: [(member: FamilyMember, model: AIModel)]) -> some View {
        let deals = s.deals.filter { d in d.active && d.modelID.map { f.has($0) } ?? false }
        if !deals.isEmpty {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enterprise").font(.callout.weight(.semibold))
                    Text("\(deals.count) contract\(deals.count == 1 ? "" : "s") on this family, \(Fmt.count(deals.reduce(0) { $0 + $1.tokensPerDay })) tokens/day. Each client only needs its minimum index: a cheaper tier that clears it serves the same contract for less.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Move to cheapest qualifying tier") { store.act("Contracts moved") { $0.rehomeContracts(f.id) } }
            }
        }
    }

    private func cannibalisation(_ c: [UUID: Families.Cannibal], rows: [(member: FamilyMember, model: AIModel)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cannibalisation (API)").font(.callout.weight(.semibold))
            ForEach(rows.map(\.model).filter { c[$0.id] != nil }) { m in
                if let x = c[m.id] {
                    let share = x.tokens > 0 ? x.fromSiblings / x.tokens : 0
                    HStack(spacing: 8) {
                        Text(m.name).font(.caption.weight(.semibold)).frame(width: 150, alignment: .leading)
                        Text("sells \(Fmt.count(x.tokens)) tokens/day (\(Fmt.money(x.revenue))/day): \(Fmt.pct(share, decimals: 0)) of it would otherwise have gone to its siblings, who'd earn \(Fmt.money(x.revenueFromSiblings))/day more without it. \(Fmt.count(x.newTokens)) tokens/day are new to the family.")
                            .font(.caption).foregroundStyle(share > 0.5 ? Color.orange : Color.secondary)
                    }
                }
            }
            Text("Measured by re-running today's API market without each tier. Cheap tiers win price-sensitive buyers from rivals but also from your own flagship.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// Every tier's domain scores side by side.
private struct DomainsByTier: View {
    let rows: [(member: FamilyMember, model: AIModel)]
    let state: GameState

    var body: some View {
        let scored = rows.compactMap { r in state.domainScores[r.model.id.uuidString].map { (r.member.tier, r.model, $0) } }
        if !scored.isEmpty {
            Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    Text("Domains").gridColumnAlignment(.leading)
                    ForEach(CapDomain.allCases) { d in Image(systemName: d.symbol).help(d.label) }
                }
                .font(.caption2).foregroundStyle(.secondary)
                ForEach(scored, id: \.1.id) { tier, m, v in
                    GridRow {
                        Text("\(tier.label) · \(m.name)").font(.caption).lineLimit(1).gridColumnAlignment(.leading)
                        ForEach(CapDomain.allCases) { d in Text("\(Int(v[d].rounded()))").font(.caption.monospacedDigit()) }
                    }
                }
            }
        }
    }
}

// MARK: - Compute picker

private struct JobCompute: View {
    @Environment(GameStore.self) private var store
    @Binding var accelID: String
    @Binding var chips: Int

    var body: some View {
        let pools = store.derived.pools.filter { $0.free > 0 || $0.accel.id == accelID }
        HStack {
            Picker("Hardware", selection: $accelID) {
                if pools.isEmpty { Text("No free chips").tag(accelID) }
                ForEach(pools) { p in Text("\(p.accel.name) (\(Fmt.int(p.free)) free)").tag(p.accel.id) }
            }
            .frame(maxWidth: 320)
            QuantityPicker(value: $chips, range: 1...max(1, store.derived.free(accelID)), presets: [8, 64, 512, 4_096, 32_768, 262_144])
        }
        .onChange(of: accelID) { _, new in chips = max(1, min(chips, store.derived.free(new))) }
    }
}

// MARK: - Distillation

struct DistillSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let teacherID: UUID
    @State private var tier: FamilyTier = .spark
    @State private var data: DistillData = .standard
    @State private var accelID = ""
    @State private var chips = 1
    @State private var autoLaunch = true

    var body: some View {
        let s = store.game
        VStack(alignment: .leading, spacing: 14) {
            if let t = s.models.first(where: { $0.id == teacherID }) {
                content(t, s)
            } else {
                Text("That model no longer exists.")
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Start distillation") {
                    let (t, a, n, d, l) = (tier, accelID, chips, data, autoLaunch)
                    if store.act("Distillation started", { $0.startDistill(teacherID, tier: t, data: d, accelID: a, chips: n, autoLaunch: l) }) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(plan(s)?.blocker != nil)
            }
        }
        .padding(22)
        .frame(width: 820)
        .onAppear {
            if let t = s.models.first(where: { $0.id == teacherID }), let c = Families.defaultCompute(s, for: t) {
                accelID = c.accelID
                chips = c.chips
            }
        }
    }

    private func plan(_ s: GameState) -> Families.DistillPlan? {
        guard let t = s.models.first(where: { $0.id == teacherID }) else { return nil }
        return Families.distillPlan(s, teacher: t, tier: tier, data: data, accelID: accelID, chips: chips)
    }

    @ViewBuilder
    private func content(_ t: AIModel, _ s: GameState) -> some View {
        let p = Families.distillPlan(s, teacher: t, tier: tier, data: data, accelID: accelID, chips: chips)
        let fam = Families.family(of: t.id, s)?.name ?? Families.suggestedName(t)
        let student = Families.student(s, teacher: t, plan: p, name: Families.tierName(s, family: fam, tier: tier), accelID: accelID, chips: chips)
        // 3.8: the teacher as it is scored today; the student on the teacher's know-how (not research done since).
        let tv = s.domainScores[t.id.uuidString] ?? Capabilities.playerScores(t, research: Capabilities.knowHow(t, s))
        let sv = Capabilities.playerScores(student, research: student.knowHow)
        let set = store.derived.indexSet
        let sIndex = BenchmarkCatalog.index(Leaderboard.profile(student), set: set)
        Text("Distil from \(t.name)").font(.title2.weight(.bold))
        Text("A smaller student learns from \(t.name)'s outputs. It keeps most of the teacher's ability for a fraction of the serving cost, and joins the \(fam) family.")
            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        Picker("Tier", selection: $tier) {
            ForEach(FamilyTier.sizes.filter { $0 != .flagship }) { t in Text("\(t.label) (\(Fmt.pct(t.sizeFraction, decimals: t.sizeFraction < 0.05 ? 1 : 0)) size)").tag(t) }
        }
        .pickerStyle(.segmented)
        Text(tier.role).font(.caption).foregroundStyle(.secondary)
        Picker("Distillation data", selection: $data) {
            ForEach(DistillData.allCases) { d in Text("\(d.label) · \(Int(d.tokensPerParam)) tokens/param").tag(d) }
        }
        .pickerStyle(.segmented)
        JobCompute(accelID: $accelID, chips: $chips)
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How much it keeps").font(.headline)
                ForEach(p.lines, id: \.self) { l in Text("• " + l).font(.caption).fixedSize(horizontal: false, vertical: true) }
                Text("\(fam) \(tier.label): \(Fmt.params(p.studentParamsB)) params, Intelligence Index about \(Fmt.score(sIndex)) (teacher \(Fmt.score(t.index))).")
                    .font(.callout.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text("Cost and payoff").font(.headline)
                SpecRow(label: "Compute", value: "\(Fmt.flops(p.flops)) FLOPs")
                SpecRow(label: "Time", value: p.days.isFinite ? "\(Int(p.days.rounded(.up))) days" : "—")
                SpecRow(label: "Chip cost", value: p.cost.isFinite ? Fmt.money(p.cost) : "—")
                SpecRow(label: "Serving / 1M: teacher", value: p.teacherCostPerM > 0 ? Fmt.price(p.teacherCostPerM) : "—")
                SpecRow(label: "Serving / 1M: student", value: p.studentCostPerM > 0 ? Fmt.price(p.studentCostPerM) : "—")
                if p.studentCostPerM > 0 {
                    Text("About \(Fmt.trim(p.teacherCostPerM / p.studentCostPerM, 0))× cheaper per token; it would list near \(Fmt.price(student.apiPrice)) against \(Fmt.price(t.apiPrice)).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Release it with an API as soon as it's done", isOn: $autoLaunch)
            }
            .frame(width: 330, alignment: .leading)
        }
        Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 3) {
            GridRow {
                Text("Domain").gridColumnAlignment(.leading)
                Text("Teacher"); Text("Student"); Text("Change")
                Text("Compute"); Text("Weight")
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(CapDomain.allCases) { d in
                GridRow {
                    Label(d.short, systemImage: d.symbol).font(.caption).gridColumnAlignment(.leading)
                    Text("\(Int(tv[d].rounded()))").font(.caption.monospacedDigit())
                    Text("\(Int(sv[d].rounded()))").font(.caption.monospacedDigit())
                    // Scores are logarithmic (10 points = 10× effective compute): show the point change and what share of the
                    // teacher's effective compute it amounts to, not a ratio of scores.
                    let delta = sv[d] - tv[d]
                    Text(tv[d] > 0 ? CapStyle.delta(delta) : "—").font(.caption.monospacedDigit())
                        .foregroundStyle(tv[d] > 0 && delta <= -5 ? Color.orange : Color.secondary)
                    Text(Self.computeShare(tv[d], delta)).font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("×\(Fmt.trim(Families.retentionWeight(d), 2))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        if let b = p.blocker { Label(b, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.orange) }
    }

    /// What share of the teacher's effective compute a domain's point change amounts to (scores are logarithmic).
    static func computeShare(_ teacher: Double, _ delta: Double) -> String {
        guard teacher > 0 else { return "—" }
        let f = pow(10, delta / 10)
        return Fmt.pct(f, decimals: f < 0.1 ? 1 : 0)
    }
}

// MARK: - Post-training

struct PostTrainSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let modelID: UUID
    @State private var pass: PostTrainPass = .reasoningRL
    @State private var accelID = ""
    @State private var chips = 1

    var body: some View {
        let s = store.game
        VStack(alignment: .leading, spacing: 14) {
            if let m = s.models.first(where: { $0.id == modelID }) {
                content(m, s)
            } else {
                Text("That model no longer exists.")
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(pass.forks ? "Fork & specialise" : "Start \(pass.label.lowercased())") {
                    let (p, a, n) = (pass, accelID, chips)
                    if store.act("Post-training started", { $0.startPostTrain(modelID, pass: p, accelID: a, chips: n) }) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(s.models.first(where: { $0.id == modelID }).map { Families.passPlan(s, model: $0, pass: pass, accelID: accelID, chips: chips).blocker != nil } ?? true)
            }
        }
        .padding(22)
        .frame(width: 820)
        .onAppear {
            if let m = s.models.first(where: { $0.id == modelID }) {
                if let c = Families.defaultCompute(s, for: m) {
                    accelID = c.accelID
                    chips = c.chips
                }
                pass = PostTrainPass.allCases.first { Families.passBlocker(s, m, $0) == nil } ?? .safety
            }
        }
    }

    @ViewBuilder
    private func content(_ m: AIModel, _ s: GameState) -> some View {
        let p = Families.passPlan(s, model: m, pass: pass, accelID: accelID, chips: chips)
        let set = store.derived.indexSet
        let before = s.domainScores[m.id.uuidString] ?? Capabilities.playerScores(m, research: Capabilities.knowHow(m, s))
        let after = Capabilities.playerScores(p.after, research: p.after.knowHow)
        let idxBefore = BenchmarkCatalog.index(Leaderboard.profile(m), set: set)
        let idxAfter = BenchmarkCatalog.index(Leaderboard.profile(p.after), set: set)
        let costBefore = Economy.servingCostPerM(m, s)
        let costAfter = Economy.servingCostPerM(p.after, s)
        Text(Self.title(pass, m)).font(.title2.weight(.bold))
        Text(Self.explainer(pass, m)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        Text(Self.knowHowNote(pass)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            ForEach(PostTrainPass.allCases) { x in
                let blocked = Families.passBlocker(s, m, x)
                let done = m.passes.filter { $0 == x.rawValue }.count
                Button { pass = x } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: x.symbol).frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.passTitle(x, done: done, recipe: Families.inRecipe(s, m, x))).font(.callout.weight(.semibold))
                            Text(blocked ?? x.blurb).font(.caption2).foregroundStyle(blocked == nil ? Color.secondary : Color.orange).lineLimit(3)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(pass == x ? AnyShapeStyle(Color.indigo.opacity(0.18)) : AnyShapeStyle(.quaternary.opacity(0.4)), in: .rect(cornerRadius: 8))
                    .contentShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .opacity(blocked == nil ? 1 : 0.6)
            }
        }
        JobCompute(accelID: $accelID, chips: $chips)
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gains").font(.headline)
                ForEach(p.gains, id: \.self) { Text("+ " + $0).font(.caption).foregroundStyle(.green) }
                Text("Trade-offs").font(.headline).padding(.top, 4)
                ForEach(p.costs, id: \.self) { Text("− " + $0).font(.caption).foregroundStyle(.orange) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                SpecRow(label: "Intelligence Index", value: "\(Fmt.score(idxBefore)) → \(Fmt.score(idxAfter))")
                SpecRow(label: "Safety", value: "\(Int(m.safety.rounded())) → \(Int(p.after.safety.rounded()))")
                SpecRow(label: "Serving / 1M", value: "\(Fmt.price(costBefore)) → \(Fmt.price(costAfter))")
                SpecRow(label: "Compute", value: "\(Fmt.flops(p.flops)) FLOPs")
                SpecRow(label: "Time", value: p.days.isFinite ? "\(Int(p.days.rounded(.up))) days" : "—")
                SpecRow(label: "Chip cost", value: p.cost.isFinite ? Fmt.money(p.cost) : "—")
                if Families.previewFactor(s, m) < 1 { Text("Research-preview feedback: this pass costs 30% less.").font(.caption).foregroundStyle(.secondary) }
                if pass.forks { Text("The specialist needs its own servers once it's on sale.").font(.caption).foregroundStyle(.secondary) }
            }
            .frame(width: 330, alignment: .leading)
        }
        HStack(spacing: 10) {
            ForEach(CapDomain.allCases) { d in
                let delta = after[d] - before[d]
                VStack(spacing: 1) {
                    Image(systemName: d.symbol).font(.caption2).foregroundStyle(.secondary)
                    Text(CapStyle.delta(delta)).font(.caption.monospacedDigit()).foregroundStyle(CapStyle.deltaColor(delta))
                }
                .help("\(d.label): \(Int(before[d].rounded())) → \(Int(after[d].rounded()))")
            }
        }
        if let b = p.blocker { Label(b, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.orange) }
        if Families.canMerge(m) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Merge into a point release").font(.headline)
                    Text("\(m.passesSinceMerge) passes since the last release. Weight-merging their checkpoints wins back half of the trade-offs and ships \(Families.versionLabel(m.version % 10 < 5 ? m.version / 10 * 10 + 5 : (m.version / 10 + 1) * 10)).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Merge (\(Fmt.flops(Families.mergeFlops(m))) FLOPs)") {
                    let (a, n) = (accelID, chips)
                    if store.act("Merge started", { $0.startMerge(modelID, accelID: a, chips: n) }) { dismiss() }
                }
            }
        }
    }
}

extension PostTrainSheet {
    /// Strings for the sheet, built here (long interpolated strings are slow to type-check inside views).
    static func title(_ pass: PostTrainPass, _ m: AIModel) -> String {
        pass.forks ? "Fork & specialise \(m.name)" : "Post-train \(m.name)"
    }

    static func explainer(_ pass: PostTrainPass, _ m: AIModel) -> String {
        if pass.forks {
            var t = "A specialisation forks a new member of the family: a copy of \(m.name) trained for one kind of work, sold beside it as the "
            t += "\(pass.tier?.label ?? "specialist") tier with servers of its own. \(m.name) itself is unchanged; API buyers who need that work go to whichever member suits them."
            return t
        }
        var t = "A pass upgrades the model in place: same servers, same products, a new point version "
        t += "(\(Families.versionLabel(m.version)) → \(Families.versionLabel(m.version + 1))). "
        t += "Every pass has a trade-off; merging two or more passes into a point release wins half of it back."
        return t
    }

    static func knowHowNote(_ pass: PostTrainPass) -> String {
        let domains = pass.refreshes.map { $0.short.lowercased() }.joined(separator: ", ")
        return "A pass teaches the model the published techniques of its own domains (\(domains)) and nothing else: research in other fields reaches your models through training new ones."
    }

    static func passTitle(_ x: PostTrainPass, done: Int, recipe: Bool) -> String {
        var t = x.forks ? "Fork: " : ""
        t += x.label
        if done > 0 { t += " (done \(done)×)" }
        if recipe { t += " · family recipe, half cost" }
        return t
    }
}

// MARK: - Dashboard

/// Families at a glance: each lineup's tiers, its traffic and what's being distilled or post-trained.
struct ModelFamiliesCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader(title: "Model families", symbol: "square.stack.3d.down.right.fill") {
                Button("Model Families") { store.open(.families) }.buttonStyle(.link)
            }
            if s.families.families.isEmpty {
                Text("One flagship serves everything. Distil cheaper tiers to serve the free chat tier and price-sensitive API buyers for a fraction of the cost.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(s.families.families.prefix(3)) { f in
                let rows = Families.members(f, s)
                let shares = Families.trafficShares(f, s)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(f.name).font(.callout.weight(.semibold))
                        Spacer()
                        Text("brand \(Int(f.brand.rounded()))").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        ForEach(rows, id: \.model.id) { r in
                            Pill(text: "\(r.member.tier.label) \(shares[r.model.id].map { Fmt.pct($0, decimals: 0) } ?? "—")",
                                 color: r.model.released ? .indigo : .secondary, symbol: r.member.tier.symbol)
                        }
                    }
                }
            }
            if !s.families.jobs.isEmpty {
                ForEach(s.families.jobs.prefix(3)) { j in
                    HStack {
                        Text(j.name).font(.caption).lineLimit(1)
                        Meter(value: j.progress, tint: j.paused ? .orange : .indigo, height: 5)
                    }
                }
            }
        }
    }
}
