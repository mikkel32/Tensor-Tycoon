import SwiftUI

/// 3.10: a government branch's money and machines in one place. Ask the state for funding, GPUs or a bigger facility and
/// it's granted on the spot, with tasks attached; agencies order models built for them.
struct PublicFundingView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        Page(title: "Funding & Commissions", subtitle: "Ask the state for money, GPUs or power: it's granted on the spot, and the committee attaches tasks to deliver. Agencies order models built for them.", screen: .publicFunding) {
            if !s.isPublicProgram {
                Card {
                    EmptyStateView(symbol: "banknote", title: "No public programme",
                                   message: "Choose the Government AI branch origin when founding a new game.",
                                   actionTitle: "Back to Dashboard") { store.open(.dashboard) }
                }
            } else {
                GovHero(state: s)
                AskGovernmentCard(state: s)
                CardGrid(minWidth: 420, maxColumns: 2) {
                    FacilityCard(state: s)
                    CommitmentsCard(state: s)
                }
                MoneySourcesCard(state: s)
                CommissionsCard(state: s)
            }
        }
    }
}

/// The government screens' accent.
enum GovTheme {
    static let tint = Color.purple
    static let gradient = LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let wash = Color.purple.opacity(0.08)
}

// MARK: - Hero

private struct GovHero: View {
    let state: GameState

    var body: some View {
        let s = state
        let p = s.publicProgram
        let withheld = p.clawback
        ZStack(alignment: .bottomLeading) {
            Photo(key: "gov_capitol").frame(height: 190).frame(maxWidth: .infinity).clipped()
            LinearGradient(colors: [Color.purple.opacity(0.92), Color.indigo.opacity(0.75), Color.black.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
            HStack(alignment: .bottom, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Funding & Commissions", systemImage: "building.columns.fill").font(.largeTitle.weight(.heavy))
                    Text("The state funds you. You deliver.").font(.title3.weight(.medium)).opacity(0.92)
                    HStack(spacing: 8) {
                        heroPill(PublicProgram.levelNames[clamp(p.level, 1, 4)], "star.fill")
                        heroPill("Oversight \(Int(p.oversight))/100", "checkmark.shield.fill")
                        heroPill("\(GovRequests.open(s).count)/\(GovRequests.maxOpen) requests open", "list.bullet.clipboard.fill")
                        if withheld > 0 { heroPill("\(Fmt.money(withheld)) to be withheld", "exclamationmark.triangle.fill") }
                    }
                }
                Spacer()
                HStack(spacing: 26) {
                    metric("Annual budget", Fmt.money(PublicProgram.authorisedBudget(s)))
                    metric("Reserves", Fmt.money(s.cash))
                    metric("Next budget", p.lastTranche.map { GameCalendar.addDays($0, 90).gameShort } ?? "Soon")
                }
            }
            .foregroundStyle(.white)
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.purple.opacity(0.6), lineWidth: 1))
    }

    private func heroPill(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol).font(.caption.weight(.semibold))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(.white.opacity(0.18), in: .capsule)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).opacity(0.75)
            Text(value).font(.title.weight(.bold).monospacedDigit())
        }
    }
}

// MARK: - Ask the government

private struct AskGovernmentCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var kind: GovRequestKind = .funding
    @State private var share: Double = 0.25
    @State private var chips: Double = 0
    @State private var power: Double = 100_000

    var body: some View {
        let s = state
        let blocked = GovRequests.blocker(s)
        Card {
            HStack(alignment: .firstTextBaseline) {
                Label("Ask the government", systemImage: "hand.raised.fill").font(.title2.weight(.bold)).foregroundStyle(GovTheme.tint)
                Spacer()
                Picker("", selection: $kind) {
                    ForEach(GovRequestKind.allCases) { k in Label(k.title, systemImage: k.symbol).tag(k) }
                }
                .pickerStyle(.segmented).frame(width: 360).labelsHidden()
            }
            Text("Granted the moment you ask. In return the committee attaches tasks, more for a bigger request, due by a deadline. Deliver them all: oversight +5 and a culture point. Miss the deadline: oversight −8\(kind == .funding ? ", and 30% of the money is withheld from your next budgets" : kind == .chips ? ", and half the GPUs are reassigned to other agencies" : "").")
                .font(.callout).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    switch kind {
                    case .funding: fundingPicker(s)
                    case .chips: chipPicker(s)
                    case .power: powerPicker(s)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                TermsPanel(state: s, tier: tier(s), arrives: arrivesDays, action: actionTitle(s), disabled: blocked != nil || disabledReason(s) != nil,
                           reason: blocked ?? disabledReason(s)) { submit() }
                    .frame(width: 380)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(GovTheme.tint.opacity(0.45), lineWidth: 1.5))
        .onAppear { resetChips(s) }
        .onChange(of: kind) { _, _ in resetChips(s) }
    }

    // MARK: Pickers

    @ViewBuilder
    private func fundingPicker(_ s: GameState) -> some View {
        let budget = PublicProgram.authorisedBudget(s)
        let amount = fundingAmount(s)
        Text(Fmt.money(amount)).font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(GovTheme.gradient)
        Text("\(Fmt.pct(share, decimals: 0)) of your \(Fmt.money(budget)) annual budget, paid today").font(.callout).foregroundStyle(.secondary)
        Slider(value: $share, in: 0.1...2.0).tint(GovTheme.tint)
        HStack(spacing: 6) {
            ForEach([0.1, 0.25, 0.5, 1.0, 2.0], id: \.self) { v in
                Button(Fmt.money(budget * v)) { share = v }
                    .buttonStyle(.bordered).controlSize(.small)
                    .tint(abs(share - v) < 0.005 ? GovTheme.tint : nil)
            }
        }
    }

    @ViewBuilder
    private func chipPicker(_ s: GameState) -> some View {
        if let a = GovRequests.chipChoice(s) {
            let range = GovRequests.chipRange(s)
            let n = chipCount(s)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Fmt.int(n)).font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(GovTheme.gradient)
                Text(a.name).font(.title2.weight(.semibold))
            }
            Text("\(Fmt.count(a.bf16 * Double(n))) TFLOPS BF16 · \(Fmt.watts(Economy.chipKW(a) * Double(n) * 1000)) · arrives in \(GovRequests.chipDays) days at the national facility, power paid by the ministry")
                .font(.callout).foregroundStyle(.secondary)
            if range.upperBound > range.lowerBound {
                Slider(value: $chips, in: Double(range.lowerBound)...Double(range.upperBound)).tint(GovTheme.tint)
                HStack(spacing: 6) {
                    ForEach([512, 1_024, 2_048, 4_096, 8_192].filter { $0 >= range.lowerBound && $0 < range.upperBound }, id: \.self) { v in
                        Button(Fmt.int(v)) { chips = Double(v) }.buttonStyle(.bordered).controlSize(.small)
                    }
                    Button("Max \(Fmt.int(range.upperBound))") { chips = Double(range.upperBound) }.buttonStyle(.bordered).controlSize(.small)
                }
            } else if range.upperBound == 0 {
                Label("The facility has no power left for more GPUs. Ask for more power first.", systemImage: "bolt.slash.fill").foregroundStyle(.orange)
            }
        } else {
            Text("No datacenter GPUs can be procured right now.").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func powerPicker(_ s: GameState) -> some View {
        let cap = GovRequests.capacityKW(s)
        Text("+\(Fmt.watts(power * 1000))").font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(GovTheme.gradient)
        Text("The facility goes from \(Fmt.watts(cap * 1000)) to \(Fmt.watts((cap + power) * 1000)), commissioned in \(GovRequests.powerDays) days. The ministry pays the power.")
            .font(.callout).foregroundStyle(.secondary)
        HStack(spacing: 10) {
            ForEach(GovRequests.powerSteps, id: \.self) { kw in
                Button { power = kw } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "bolt.fill").font(.title2)
                        Text("+\(Fmt.watts(kw * 1000))").font(.callout.weight(.bold))
                        Text("\(GovRequests.tasks(s, tier: GovRequests.powerTier(kw)).count) tasks").font(.caption2).opacity(0.8)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(power == kw ? AnyShapeStyle(GovTheme.gradient) : AnyShapeStyle(GovTheme.wash), in: .rect(cornerRadius: 12))
                    .foregroundStyle(power == kw ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Request

    private func fundingAmount(_ s: GameState) -> Double {
        let r = GovRequests.fundingRange(s)
        return (clamp(PublicProgram.authorisedBudget(s) * share, r.lowerBound, r.upperBound) / 100_000).rounded() * 100_000
    }

    private func chipCount(_ s: GameState) -> Int {
        let r = GovRequests.chipRange(s)
        let step = max(1, GovRequests.chipChoice(s)?.minOrder ?? 1)
        return clamp(Int(chips.rounded()), r.lowerBound, r.upperBound) / step * step
    }

    private func resetChips(_ s: GameState) {
        let r = GovRequests.chipRange(s)
        if chips <= 0 || Int(chips) > r.upperBound { chips = Double(min(r.upperBound, max(r.lowerBound, 1_024))) }
    }

    private func tier(_ s: GameState) -> Int {
        switch kind {
        case .funding: GovRequests.fundingTier(fundingAmount(s), s)
        case .chips: GovRequests.chipTier(chipCount(s), s)
        case .power: GovRequests.powerTier(power)
        }
    }

    private var arrivesDays: Int? {
        switch kind {
        case .funding: nil
        case .chips: GovRequests.chipDays
        case .power: GovRequests.powerDays
        }
    }

    private func actionTitle(_ s: GameState) -> String {
        switch kind {
        case .funding: "Request \(Fmt.money(fundingAmount(s)))"
        case .chips: "Request \(Fmt.int(chipCount(s))) GPUs"
        case .power: "Request +\(Fmt.watts(power * 1000))"
        }
    }

    private func disabledReason(_ s: GameState) -> String? {
        switch kind {
        case .funding: nil
        case .chips: GovRequests.chipChoice(s) == nil || chipCount(s) <= 0 ? "No room or no GPUs to procure." : nil
        case .power: GovRequests.powerBlocker(s)
        }
    }

    private func submit() {
        let s = state
        switch kind {
        case .funding:
            let a = fundingAmount(s)
            store.act("\(Fmt.money(a)) granted") { $0.requestGovernmentFunding(a) }
        case .chips:
            let n = chipCount(s)
            store.act("\(Fmt.int(n)) GPUs granted") { $0.requestGovernmentChips(n) }
            resetChips(store.game)
        case .power:
            let kw = power
            store.act("Expansion granted") { $0.requestGovernmentPower(kw) }
        }
    }
}

/// What a request costs in work: the tasks, the deadline, the button.
private struct TermsPanel: View {
    let state: GameState
    let tier: Int
    let arrives: Int?
    let action: String
    let disabled: Bool
    let reason: String?
    let submit: () -> Void

    var body: some View {
        let s = state
        let tasks = GovRequests.tasks(s, tier: tier)
        let days = GovRequests.days(tier)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("The committee asks in return").font(.headline)
                Spacer()
                Text(String(repeating: "●", count: tier) + String(repeating: "○", count: 4 - tier)).foregroundStyle(GovTheme.tint).help("Size of the request: more tasks for more")
            }
            ForEach(tasks) { task in
                HStack(spacing: 10) {
                    Image(systemName: task.kind.symbol).foregroundStyle(GovTheme.tint).frame(width: 22)
                    Text(task.title).font(.callout)
                }
            }
            Divider()
            Label("Due \(GameCalendar.addDays(s.date, days).gameShort) · \(days) days\(arrives.map { " · arrives in \($0) days" } ?? "")", systemImage: "calendar.badge.clock")
                .font(.caption).foregroundStyle(.secondary)
            Button(action: submit) {
                Label(action, systemImage: "checkmark.seal.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).tint(GovTheme.tint).controlSize(.large)
            .disabled(disabled)
            if let reason { Text(reason).font(.caption).foregroundStyle(.orange) }
        }
        .padding(14)
        .background(GovTheme.wash, in: .rect(cornerRadius: 12))
    }
}

// MARK: - The national facility

private struct FacilityCard: View {
    let state: GameState

    var body: some View {
        let s = state
        Card {
            if let f = GovRequests.facility(s) {
                let cap = f.capacityKW
                let used = GovRequests.committedKW(s)
                let pendingPower = GovRequests.pendingPowerKW(s)
                let batches = Dictionary(grouping: s.owned.filter { $0.siteID == f.id }, by: \.accelID)
                    .map { (HardwareCatalog.get($0.key), $0.value.reduce(0) { $0 + $1.count }) }
                    .sorted { ($0.0?.bf16 ?? 0) > ($1.0?.bf16 ?? 0) }
                CardHeader(title: f.name, symbol: "building.columns.fill", subtitle: "The state's own compute: power paid by the ministry") {
                    Pill(text: Fmt.watts(cap * 1000), color: GovTheme.tint, symbol: "bolt.fill")
                }
                HStack {
                    Text("Power in use").font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(Fmt.watts(used * 1000)) of \(Fmt.watts(cap * 1000))\(pendingPower > 0 ? " · +\(Fmt.watts(pendingPower * 1000)) coming" : "")").font(.caption.monospacedDigit())
                }
                Meter(value: used / max(1, cap), tint: used / max(1, cap) > 0.85 ? .orange : GovTheme.tint, height: 12)
                ForEach(Array(batches.enumerated()), id: \.offset) { _, b in
                    HStack {
                        Image(systemName: "cpu.fill").foregroundStyle(GovTheme.tint)
                        Text(b.0?.name ?? "GPU").font(.callout.weight(.medium))
                        Spacer()
                        Text(Fmt.int(b.1)).font(.title3.weight(.bold).monospacedDigit())
                        Text("· \(Fmt.count((b.0?.bf16 ?? 0) * Double(b.1))) TF").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(GovRequests.open(s).filter { !$0.arrived && $0.kind != .funding }) { r in
                    Label("\(r.title) arriving \(r.arrives?.gameShort ?? "soon")", systemImage: r.kind == .chips ? "shippingbox.fill" : "hammer.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(used / max(1, cap) >= 0.5 ? "Over half full: you can ask for more power above." : "Room for more GPUs: ask for them above, or buy your own in the Hardware store.")
                    .font(.caption2).foregroundStyle(.tertiary)
            } else {
                CardHeader("National compute facility", symbol: "building.columns.fill")
                Text("The facility opens with the next day.").foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Commitments

private struct CommitmentsCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let open = GovRequests.open(s)
        let closed = s.publicProgram.grants.filter { $0.status != .active }.prefix(4)
        Card {
            CardHeader(title: "Your commitments", symbol: "list.bullet.clipboard.fill", subtitle: "Tasks attached to what the state granted you") {
                Pill(text: "\(s.publicProgram.grantsCompleted) met · \(s.publicProgram.grantsFailed) missed", color: GovTheme.tint)
            }
            if open.isEmpty {
                Text("Nothing owed. Ask for funding, GPUs or power above and the tasks will show here.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(open) { r in
                let days = GameCalendar.daysBetween(s.date, r.due)
                let total = Double(max(1, GameCalendar.daysBetween(r.issued, r.due)))
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Image(systemName: r.kind.symbol).foregroundStyle(.white).frame(width: 28, height: 28).background(GovTheme.gradient, in: .circle)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(.callout.weight(.semibold))
                            Text(r.kind == .funding ? "Paid \(r.issued.gameShort)" : r.arrived ? "Delivered" : "Arrives \(r.arrives?.gameShort ?? "soon")")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(r.tasks.filter(\.done).count)/\(r.tasks.count)").font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(GovTheme.tint)
                        Text(days >= 0 ? "\(days)d left" : "Overdue").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(days < 30 ? .orange : .secondary)
                    }
                    Meter(value: 1 - Double(max(0, days)) / total, tint: days < 30 ? .orange : GovTheme.tint.opacity(0.6), height: 4)
                    ForEach(r.tasks) { task in
                        let prog = GovRequests.progress(task, r, s)
                        HStack(spacing: 8) {
                            Image(systemName: task.done ? "checkmark.circle.fill" : "circle").foregroundStyle(task.done ? .green : .secondary)
                            Text(task.title).font(.caption).strikethrough(task.done, color: .secondary)
                            Spacer()
                            if !task.done { Meter(value: prog, tint: GovTheme.tint, height: 5).frame(width: 70) }
                        }
                    }
                }
                .padding(10)
                .background(GovTheme.wash, in: .rect(cornerRadius: 10))
            }
            if !closed.isEmpty {
                ForEach(Array(closed)) { r in
                    HStack {
                        Image(systemName: r.status == .completed ? "checkmark.seal.fill" : "xmark.octagon.fill").foregroundStyle(r.status == .completed ? .green : .red)
                        Text(r.title).font(.caption)
                        Spacer()
                        Text(r.status == .completed ? "Met" : "Missed").font(.caption2).foregroundStyle(.secondary)
                        Text((r.closed ?? r.due).gameShort).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Where the money comes from

private struct MoneySourcesCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let p = s.publicProgram
        let missions = p.missions.filter { $0.status == .active }
        let service = Commissions.inService(s).reduce(0) { $0 + $1.serviceYearly }
        Card {
            CardHeader("Where the money comes from", symbol: "arrow.down.circle.fill", subtitle: "Four sources: two automatic, two you ask for or earn")
            EqualColumns(minWidth: 210, spacing: 12, maxColumns: 4) {
                source("1", "calendar", .blue, "Quarterly budget", "Automatic",
                       "\(Fmt.money(PublicProgram.nextTranche(s))) arrives \(p.lastTranche.map { "on \(GameCalendar.addDays($0, 90).gameShort)" } ?? "each quarter")\(p.clawback > 0 ? ", less \(Fmt.money(min(p.clawback, PublicProgram.nextTranche(s) * 0.5))) withheld" : "").")
                source("2", "target", .purple, "Mission payments", "Automatic",
                       missions.isEmpty ? "New missions arrive soon." : "\(Fmt.money(missions.reduce(0) { $0 + $1.reward })) waiting on \(missions.count) active mission\(missions.count == 1 ? "" : "s"), paid the day each is met.",
                       action: ("Missions", .publicProgram))
                source("3", "hand.raised.fill", .indigo, "Requests", "\(GovRequests.open(s).count)/\(GovRequests.maxOpen) open",
                       "Ask for up to twice your budget, GPUs or power. Granted at once; the committee attaches tasks.")
                source("4", "building.2.fill", .orange, "Agency commissions", "\(Commissions.inService(s).count) in service",
                       "Agencies order models built for them: paid to build, then \(service > 0 ? "\(Fmt.money(service)) a year" : "a yearly fee") to run.\(Commissions.open(s).isEmpty ? "" : " \(Commissions.open(s).count) order\(Commissions.open(s).count == 1 ? "" : "s") waiting.")")
            }
        }
    }

    private func source(_ n: String, _ symbol: String, _ tint: Color, _ title: String, _ status: String, _ text: String, action: (String, Screen)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(tint.opacity(0.18)).frame(width: 30, height: 30)
                    Image(systemName: symbol).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(n). \(title)").font(.callout.weight(.semibold))
                    Text(status).font(.caption2.weight(.medium)).foregroundStyle(tint)
                }
            }
            Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let action { Button(action.0) { store.open(action.1) }.buttonStyle(.link).font(.caption) }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
    }
}

// MARK: - Agency commissions

private struct CommissionsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let offers = Commissions.open(s)
        let active = Commissions.active(s)
        let service = Commissions.inService(s)
        let record = s.publicProgram.commissions.filter { ![.offered, .active, .inService].contains($0.status) }.reversed()
        Card {
            CardHeader(title: "Agency commissions", symbol: "building.2.fill",
                       subtitle: "Government agencies order models built just for them. Accept an order, train a model that meets its bar, hand it over.") {
                Pill(text: "\(s.publicProgram.commissionsDelivered) delivered", color: .green)
            }
            if offers.isEmpty && active.isEmpty && service.isEmpty {
                Text("No orders yet. Agencies send one about every \(Commissions.offerEveryDays) days; they arrive in the news and here.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if !offers.isEmpty {
                section("Orders waiting for an answer", "tray.and.arrow.down.fill")
                ForEach(offers) { c in OfferRow(state: s, commission: c) }
            }
            if !active.isEmpty {
                section("Building now", "hammer.fill")
                ForEach(active) { c in ActiveCommissionRow(state: s, commission: c) }
            }
            if !service.isEmpty {
                section("In service", "checkmark.seal.fill")
                ForEach(service) { c in
                    HStack(spacing: 10) {
                        Image(systemName: c.symbol).foregroundStyle(.green).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(c.modelName) at the \(c.agency)").font(.callout.weight(.semibold))
                            Text("\(c.title) · \(Fmt.money(c.serviceYearly))/yr until \(c.serviceUntil?.gameShort ?? "—") · \(Fmt.money(c.paid)) paid so far\(c.internalOnly ? " · keep it internal" : "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            if !record.isEmpty {
                section("Record", "archivebox.fill")
                ForEach(Array(record.prefix(6))) { c in
                    HStack {
                        Image(systemName: c.status == .completed ? "checkmark.circle.fill" : c.status == .failed || c.status == .cancelled ? "xmark.octagon.fill" : "minus.circle")
                            .foregroundStyle(c.status == .completed ? .green : c.status == .failed || c.status == .cancelled ? .red : .secondary)
                        Text("\(c.agency): \(c.title)").font(.caption)
                        Spacer()
                        Text(statusText(c.status)).font(.caption2).foregroundStyle(.secondary)
                        Text((c.closed ?? c.offered).gameShort).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func section(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
    }

    private func statusText(_ st: CommissionStatus) -> String {
        switch st {
        case .completed: "Service complete"
        case .failed: "Missed the deadline"
        case .cancelled: "Contract ended"
        case .declined: "Declined"
        case .expired: "Offer lapsed"
        default: ""
        }
    }
}

/// The bar an order sets, as chips.
private struct RequirementChips: View {
    let commission: AgencyCommission

    var body: some View {
        let c = commission
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) { chips(c) }
        }
        .font(.caption2)
    }

    @ViewBuilder
    private func chips(_ c: AgencyCommission) -> some View {
        Pill(text: "Capability \(Fmt.trim(c.capabilityMin, 2))+", color: .blue, symbol: "cpu")
        Pill(text: "\(c.domain.label) \(Commissions.signed(c.domainEdgeMin))+", color: .purple, symbol: "scope")
        if c.safetyMin > 0 { Pill(text: "Safety \(Int(c.safetyMin))+", color: .green, symbol: "checkmark.shield") }
        if c.needsEvaluation { Pill(text: "Evaluated", color: .teal, symbol: "checklist") }
        if c.internalOnly { Pill(text: "Internal only", color: .orange, symbol: "lock.fill") }
        if c.openWeights { Pill(text: "Open weights", color: .mint, symbol: "lock.open.fill") }
        if c.securityMin > 0 { Pill(text: "SL\(c.securityMin)", color: .red, symbol: "lock.shield") }
    }
}

private struct OfferRow: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let commission: AgencyCommission

    var body: some View {
        let c = commission
        let left = GameCalendar.daysBetween(state.date, c.expires)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: c.symbol).font(.title2).foregroundStyle(.orange).frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(c.agency): \(c.title)").font(.callout.weight(.semibold))
                    Text(c.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.money(c.value)).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(.green)
                    Text("+ \(Fmt.money(c.serviceYearly))/yr for \(c.serviceMonths / 12) years").font(.caption2).foregroundStyle(.secondary)
                }
            }
            RequirementChips(commission: c)
            HStack {
                Text("\(Fmt.money(c.value * Commissions.upfront)) when you accept, the rest on delivery. \(c.deliveryDays) days to deliver a model trained after you accept. Offer open \(max(0, left)) more days.")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Decline") { store.mutate { $0.declineCommission(c.id) } }
                Button("Accept") { store.act("Order accepted") { $0.acceptCommission(c.id) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(Commissions.active(state).count >= Commissions.maxActive)
            }
        }
        .padding(11)
        .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 10))
    }
}

private struct ActiveCommissionRow: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let commission: AgencyCommission

    var body: some View {
        let s = state
        let c = commission
        let days = c.due.map { GameCalendar.daysBetween(s.date, $0) } ?? 0
        let elapsed = 1 - Double(max(0, days)) / Double(max(1, c.deliveryDays))
        let models = Commissions.candidatesModels(c, s)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: c.symbol).font(.title2).foregroundStyle(.purple).frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(c.agency): \(c.title)").font(.callout.weight(.semibold))
                    Text("\(Fmt.money(c.value * (1 - Commissions.upfront))) on delivery, then \(Fmt.money(c.serviceYearly))/yr").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(days >= 0 ? "\(days) days left" : "Overdue").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(days < 45 ? .orange : .secondary)
            }
            Meter(value: elapsed, tint: days < 45 ? .orange : .purple, height: 6)
            RequirementChips(commission: c)
            if models.isEmpty {
                HStack {
                    Text("No model trained since you accepted. Design one aimed at \(c.domain.label.lowercased()) in the Model Lab; a specialist fork or post-training pass in \(c.domain.label.lowercased()) helps it clear the bar.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Model Lab") { store.open(.lab) }
                    Button("Families") { store.open(.families) }
                }
            } else {
                ForEach(models.prefix(4)) { m in
                    let checks = Commissions.checks(c, m, s)
                    let ok = Commissions.qualifies(c, m, s)
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(ok ? .green : .secondary)
                        Text(m.name).font(.callout.weight(.medium)).frame(width: 150, alignment: .leading).lineLimit(1)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(checks) { ch in
                                    Pill(text: "\(ch.label): \(ch.detail)", color: ch.met ? .green : .red, symbol: ch.met ? "checkmark" : "xmark")
                                }
                            }
                            .font(.caption2)
                        }
                        Button("Deliver") { store.act("Model delivered") { $0.deliverCommission(c.id, modelID: m.id) } }
                            .buttonStyle(.borderedProminent)
                            .disabled(!ok)
                    }
                }
            }
        }
        .padding(11)
        .background(Color.purple.opacity(0.07), in: .rect(cornerRadius: 10))
    }
}

