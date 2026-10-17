import SwiftUI

/// Operations: the delegates that run your chores on your best model, what stops the clock, and rewinding.
struct OperationsView: View {
    @Environment(GameStore.self) private var store
    @State private var rewindTo: GameStore.AutosaveInfo?

    var body: some View {
        let s = store.game
        let c = Operations.competence(s)
        Page(title: "Operations", subtitle: "Hand the chores to delegates that run on your best model, choose what stops the clock, and rewind a bad call.") {
            HStack(spacing: 12) {
                StatTile(title: "Your COO", value: c.tier, detail: c.model.map { "Runs on \($0)" } ?? "No model of yours yet",
                         symbol: "person.badge.shield.checkmark.fill", tint: .indigo)
                StatTile(title: "Acts", value: c.everyDays == 1 ? "Every day" : "Every \(c.everyDays) days", detail: "Better models check in more often",
                         symbol: "clock.arrow.circlepath", tint: .teal)
                StatTile(title: "Precision", value: Fmt.pct(c.precision, decimals: 0), detail: "How close it gets to the right call",
                         symbol: "scope", tint: .orange)
                StatTile(title: "Actions logged", value: "\(s.opsLog.count)", detail: s.ops.anyOn ? "Delegates are working" : "All delegates are off",
                         symbol: "list.bullet.rectangle", tint: s.ops.anyOn ? .green : .secondary)
            }
            Text(c.summary).font(.callout).foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                delegates(s)
                    .frame(maxWidth: .infinity)
                VStack(spacing: 16) {
                    pauseSettings(s)
                    standing(s)
                    rewind(s)
                }
                .frame(maxWidth: .infinity)
            }
            log(s)
        }
        .confirmationDialog("Rewind to \(rewindTo?.label ?? "")?", isPresented: Binding(get: { rewindTo != nil }, set: { if !$0 { rewindTo = nil } }),
                            titleVisibility: .visible) {
            Button("Rewind", role: .destructive) {
                if let r = rewindTo { store.rewind(r) }
                rewindTo = nil
            }
            Button("Cancel", role: .cancel) { rewindTo = nil }
        } message: {
            Text("Everything since then is lost. The game in progress is replaced by the autosave.")
        }
    }

    // MARK: Delegates

    private func delegates(_ s: GameState) -> some View {
        Card {
            CardHeader("Delegates", symbol: "switch.2", subtitle: "Each one runs on its own schedule. Turn off any you'd rather handle yourself.")
            DelegateRow(title: "Serving capacity", symbol: "server.rack",
                        detail: "Adds inference chips when a model is turning users away and frees them when demand falls. Takes leased chips back first; with a cloud budget it rents on-demand chips when serving pays for them.",
                        isOn: flag(\.autoscale))
            if s.ops.autoscale {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Target load").font(.caption)
                        Slider(value: Binding(get: { store.game.ops.target }, set: { v in store.mutate { $0.ops.targetUtil = v } }), in: 0.6...0.95, step: 0.05)
                        Text(Fmt.pct(s.ops.target, decimals: 0)).font(.caption.monospacedDigit()).frame(width: 40)
                    }
                    HStack {
                        Text("Keep free").font(.caption)
                        Slider(value: Binding(get: { store.game.ops.reserveShare }, set: { v in store.mutate { $0.ops.reserve = v } }), in: 0.05...0.5, step: 0.05)
                        Text(Fmt.pct(s.ops.reserveShare, decimals: 0)).font(.caption.monospacedDigit()).frame(width: 40)
                    }
                    HStack {
                        Text("Cloud budget").font(.caption)
                        Picker("Cloud budget", selection: Binding(get: { store.game.ops.rentBudget }, set: { v in store.mutate { $0.ops.rentBudget = v } })) {
                            Text("None").tag(0.0)
                            Text("$1M a month").tag(1e6)
                            Text("$10M a month").tag(1e7)
                            Text("$100M a month").tag(1e8)
                            Text("$1B a month").tag(1e9)
                            Text("$10B a month").tag(1e10)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        Spacer()
                        let rented = s.rentals.filter { s.ops.delegateRentals.contains($0.id) }
                        if !rented.isEmpty {
                            Text("Renting \(Fmt.int(rented.reduce(0) { $0 + $1.count })) chips · \(Fmt.money(rented.reduce(0) { $0 + $1.hourly * 24 * 30.4 * Double($1.count) }))/mo")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    Text("Lower load means headroom for spikes; the free share stays available for training and research. The cloud budget is used only when a rented chip earns at least 30% more than its rent, and those chips go back first when demand falls.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 34)
            }
            DelegateRow(title: "Training", symbol: "flask.fill",
                        detail: "When no frontier run is going and chips sit idle, plans the best run your research allows on them and starts it — only if its forecast beats your best model.",
                        isOn: flag(\.autoTrain))
            DelegateRow(title: "Launches", symbol: "shippingbox.fill",
                        detail: "Ships finished models that beat your best, gives them servers, moves chat, agents and contracts onto them, and retires models nobody uses.",
                        isOn: flag(\.autoLaunch))
            DelegateRow(title: "Cloud renewals", symbol: "clock.badge.checkmark",
                        detail: "Renews reserved capacity two days before it ends, at today's rate.",
                        isOn: flag(\.autoRenew))
            DelegateRow(title: "Lease idle chips", symbol: "arrow.left.arrow.right.circle",
                        detail: "Rents out owned chips that sit idle beyond the free share, and recalls them when you need them.",
                        isOn: flag(\.leaseIdle))
            DelegateRow(title: "Hiring", symbol: "person.badge.plus",
                        detail: "Fills gaps for the size of your runs, fleet and revenue: engineers, infra, researchers, safety, data and sales.",
                        isOn: flag(\.autoHire))
            if s.ops.autoHire {
                HStack {
                    Text("New payroll per month").font(.caption)
                    Picker("New payroll per month", selection: Binding(get: { store.game.ops.hireBudget }, set: { v in store.mutate { $0.ops.hireBudget = v } })) {
                        Text("Automatic").tag(0.0)
                        Text("$50K").tag(50_000.0)
                        Text("$200K").tag(200_000.0)
                        Text("$1M").tag(1_000_000.0)
                        Text("$5M").tag(5_000_000.0)
                        Text("$20M").tag(20_000_000.0)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                .padding(.leading, 34)
            }
            DelegateRow(title: "Pay", symbol: "dollarsign.arrow.circlepath",
                        detail: "Raises anyone paid well below the market before rivals poach them.",
                        isOn: flag(\.autoRaises))
            DelegateRow(title: "Enterprise leads", symbol: "briefcase.fill",
                        detail: "Signs leads your best model and safety record can serve.",
                        isOn: flag(\.autoLeads))
            HStack {
                Button("Turn all on") {
                    store.mutate {
                        $0.updateOps { o in
                            o.autoscale = true; o.autoLaunch = true; o.autoRenew = true; o.leaseIdle = true
                            o.autoHire = true; o.autoRaises = true; o.autoLeads = true; o.autoTrain = true
                        }
                    }
                }
                Button("Turn all off") {
                    store.mutate {
                        $0.updateOps { o in
                            o.autoscale = false; o.autoLaunch = false; o.autoRenew = false; o.leaseIdle = false
                            o.autoHire = false; o.autoRaises = false; o.autoLeads = false; o.autoTrain = false
                        }
                    }
                }
            }
            .controlSize(.small)
        }
    }

    private func flag(_ kp: WritableKeyPath<OpsPolicy, Bool>) -> Binding<Bool> {
        Binding(get: { store.game.ops[keyPath: kp] }, set: { v in store.mutate { $0.ops[keyPath: kp] = v } })
    }

    // MARK: Pausing

    private func pauseSettings(_ s: GameState) -> some View {
        Card {
            CardHeader("What stops the clock", symbol: "pause.circle", subtitle: "Every alert shows as a banner. These also pause the game.")
            ForEach(AlertKind.allCases) { k in
                Toggle(isOn: Binding(get: { store.game.pauseKinds.contains(k.rawValue) }, set: { v in store.mutate { $0.setPauseOn(k, v) } })) {
                    Label(k.title, systemImage: k.symbol).font(.callout)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            HStack {
                Button("Defaults") { store.mutate { $0.pauseKinds = Alerts.defaultPauseKinds } }
                Button("Never pause") { store.mutate { $0.pauseKinds = [] } }
            }
            .controlSize(.small)
            Text("Decisions that can't wait (incidents, lawsuits, a stalled board) always stop the clock. Offers go to your inbox on the Dashboard and answer themselves if they expire.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Standing answers

    private func standing(_ s: GameState) -> some View {
        Card {
            CardHeader("Standing answers", symbol: "arrow.triangle.branch", subtitle: "Decisions the game answers for you. Tick \"Always answer this way\" on a decision to add one.")
            if s.standingAnswers.isEmpty {
                Text("None yet.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(s.standingAnswers.keys.sorted(), id: \.self) { kind in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Alerts.rememberable[kind] ?? kind).font(.callout.weight(.semibold))
                            Text("Always: \(s.standingLabels[kind] ?? "option \((s.standingAnswers[kind] ?? 0) + 1)")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Forget") { store.mutate { $0.setStandingAnswer(kind, nil) } }.controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: Rewind

    private func rewind(_ s: GameState) -> some View {
        let saves = store.autosaves()
        return Card {
            CardHeader("Rewind", symbol: "arrow.uturn.backward.circle", subtitle: "An autosave at the start of every quarter; the last eight are kept.")
            if saves.isEmpty {
                Text("No autosaves yet. The first one is made at the start of the next quarter.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(saves) { a in
                    HStack {
                        Image(systemName: "externaldrive.fill").foregroundStyle(.secondary)
                        Text(a.label).font(.callout)
                        Spacer()
                        Button("Rewind…") { rewindTo = a }.controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: Log

    private func log(_ s: GameState) -> some View {
        Card {
            CardHeader("What the delegates did", symbol: "list.bullet.rectangle.portrait", subtitle: "Newest first, last 60 actions")
            if s.opsLog.isEmpty {
                Text(s.ops.anyOn ? "Nothing yet: the delegates act on their schedule." : "Turn on a delegate and its actions show up here.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(s.opsLog.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct DelegateRow: View {
    let title: String
    let symbol: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}
