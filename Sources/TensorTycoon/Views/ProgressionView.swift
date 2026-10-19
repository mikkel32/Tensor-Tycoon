import SwiftUI

// MARK: - 3.7: company stages

/// Garage to Civilisational: where you are, what the next stage needs, the powers each unlocks, and your launches.
struct ProgressionView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let current = s.progression.current
        Page(title: "Progression", subtitle: "How big a company you've become, what the next stage takes, and how your launches landed.", screen: .progression) {
            ScreenHint(.progression)
            if Progression.celebrating(s) { PromotionCeremony(state: s) }
            StageLadder(state: s)
            if let next = current.next {
                NextStageCard(state: s, next: next)
            } else {
                Card {
                    Label("Civilisational: there is no stage beyond this one.", systemImage: "globe.americas.fill").font(.headline)
                    Text("Every power is yours. What the world does with a company like this is the rest of the game.").font(.callout).foregroundStyle(.secondary)
                }
            }
            PowersCard(state: s)
            Card {
                CardHeader("Default launch plan", symbol: "paperplane", subtitle: "Used by one-click launches, the Chief of Staff's Launch it and the launch delegate. The plain release (blog post, market price, standard system card) changes nothing.")
                LaunchPlanPicker(plan: Binding(get: { store.game.launchDefault }, set: { new in store.mutate { $0.setLaunchDefault(new) } }),
                                 state: s, rank: max(1, s.progression.rank == 0 ? 10 : s.progression.rank), showDefaultButton: false)
                    .frame(maxWidth: 520, alignment: .leading)
            }
            LaunchHistoryCard(state: s)
        }
    }
}

/// The small ceremony after a promotion: shown on the page and the dashboard card for 30 days, never as a popup.
struct PromotionCeremony: View {
    let state: GameState

    var body: some View {
        let st = state.progression.current
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: st.symbol).font(.title2.weight(.bold)).foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(state.companyName) is now a \(st.title)").font(.title3.weight(.bold))
                Text(st.blurb + (state.progression.lastPromotion.map { " Since \($0.gameShort)." } ?? "")).font(.callout).foregroundStyle(.secondary)
                if let p = Progression.power(st) {
                    Label("New power — \(p.title): \(p.text)", systemImage: p.symbol).font(.callout.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(LinearGradient(colors: [Color.yellow.opacity(0.18), Color.orange.opacity(0.08)], startPoint: .leading, endPoint: .trailing),
                    in: .rect(cornerRadius: Theme.Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.tile).strokeBorder(Color.orange.opacity(0.4)))
        .accessibilityElement(children: .combine)
    }
}

/// The six stages, left to right, with when you reached each.
struct StageLadder: View {
    let state: GameState

    var body: some View {
        let cur = state.progression.current
        Card {
            CardHeader("Company stage", symbol: "stairs", subtitle: cur.blurb)
            HStack(alignment: .top, spacing: 6) {
                ForEach(CompanyStage.allCases) { st in
                    let done = st <= cur
                    VStack(spacing: 4) {
                        Image(systemName: st.symbol)
                            .font(.title3)
                            .foregroundStyle(st == cur ? Color.orange : (done ? Color.accentColor : Color.secondary.opacity(0.5)))
                            .frame(height: 26)
                        Text(st.title).font(.caption.weight(st == cur ? .bold : .regular))
                            .foregroundStyle(done ? .primary : .secondary)
                        Text(reached(st)).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(st == cur ? Color.orange.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    if st != CompanyStage.allCases.last {
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary).padding(.top, 8)
                    }
                }
            }
        }
    }

    private func reached(_ st: CompanyStage) -> String {
        if st == .garage { return "start" }
        guard let d = state.progression.reached[st.rawValue] else { return "—" }
        return state.progression.credited.contains(st.rawValue) ? "before \(d.gameShort)" : d.gameShort
    }
}

/// The four criteria for the next stage, each with a meter.
struct NextStageCard: View {
    let state: GameState
    let next: CompanyStage

    var body: some View {
        let s = state
        let crit = Progression.criteria(s, for: next, rank: s.progression.rank == 0 ? nil : s.progression.rank)
        Card {
            CardHeader("Next: \(next.title)", symbol: next.symbol, subtitle: "All four criteria, checked weekly. Revenue and compute are shares of the AI market and of the industry's compute, so the bar rises with the years.")
            ForEach(crit) { c in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: c.met ? "checkmark.circle.fill" : "circle").foregroundStyle(c.met ? Theme.good : .secondary)
                            .accessibilityLabel(c.met ? "Met" : "Not yet")
                        Text(c.label).font(.callout.weight(.semibold))
                        Spacer()
                        Text("\(c.have)  /  \(c.need)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Meter(value: c.progress, tint: c.met ? .green : .accentColor, height: 6)
                }
                .accessibilityElement(children: .combine)
            }
            if let p = Progression.power(next) {
                Label("Unlocks \(p.title): \(p.text)", systemImage: p.symbol).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Progression.features(next), id: \.self) { f in
                Label("Opens \(f.title.lowercased()): \(f.text)", systemImage: f.symbol).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if Progression.slots(next) > Progression.slots(s.progression.current) {
                Label("Room for \(Progression.slots(next)) subsidiaries (now \(Progression.subsidiarySlots(s))).", systemImage: "square.stack.3d.up.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// What each stage unlocks — its power, the decisions it opens and the subsidiaries it can run — with links to where
/// each one works. A gated action anywhere in the game says which stage it needs.
struct PowersCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        Card {
            CardHeader("What each stage unlocks", symbol: "bolt.shield",
                       subtitle: "A power that strengthens a system you already use, and decisions you can't take before. Features an older save already used stay open.")
            ForEach(CompanyStage.allCases.filter { $0 != .garage }) { st in
                let on = Progression.has(state, st)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: st.symbol).foregroundStyle(on ? Color.accentColor : .secondary).frame(width: 20).accessibilityHidden(true)
                        Text(st.title).font(.callout.weight(.bold)).foregroundStyle(on ? .primary : .secondary)
                        if on { Pill("Reached", tone: .good) } else { Pill("Locked", tone: .neutral) }
                        Spacer()
                        Text("\(Progression.slots(st)) subsidiaries").font(.caption).foregroundStyle(.secondary)
                    }
                    if let p = Progression.power(st) {
                        UnlockRow(symbol: p.symbol, title: p.title, text: p.text, open: on, screen: p.screen)
                    }
                    ForEach(Progression.features(st), id: \.self) { f in
                        UnlockRow(symbol: f.symbol, title: f.title, text: f.text, open: Progression.allows(state, f), screen: f.screen,
                                  note: !on && Progression.allows(state, f) ? "kept from before" : nil)
                    }
                }
                .padding(.vertical, 4)
                if st != CompanyStage.allCases.last { Divider() }
            }
        }
    }
}

/// One power or unlocked decision: open (with a link to where it works) or still locked.
private struct UnlockRow: View {
    @Environment(GameStore.self) private var store
    let symbol: String
    let title: String
    let text: String
    let open: Bool
    let screen: Screen
    var note: String? = nil

    private var heading: String {
        guard let note else { return title }
        return "\(title) (\(note))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: open ? symbol : "lock.fill").foregroundStyle(open ? Color.accentColor : .secondary).frame(width: 20)
                .accessibilityLabel(open ? "Open" : "Locked")
            VStack(alignment: .leading, spacing: 1) {
                Text(heading).font(.callout.weight(.semibold)).foregroundStyle(open ? .primary : .secondary)
                Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if open { Button("Open \(screen.title)") { store.open(screen) }.buttonStyle(.link).font(.caption) }
        }
        .padding(.leading, 26)
    }
}

// MARK: - Dashboard

/// Your stage, the next one's progress, the latest promotion's ceremony and the latest launch's verdict.
struct ProgressionCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let cur = s.progression.current
        Card {
            CardHeader(title: "Company stage", symbol: "stairs") {
                Button("Progression") { store.open(.progression) }.buttonStyle(.link)
            }
            if Progression.celebrating(s) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(.orange)
                    Text("Promoted to \(cur.title)\(Progression.power(cur).map { " — new power: \($0.title)" } ?? "")")
                        .font(.callout.weight(.semibold))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: .rect(cornerRadius: 8))
            }
            HStack {
                Label(cur.title, systemImage: cur.symbol).font(.title3.weight(.bold))
                Spacer()
                if let next = cur.next { Text("next: \(next.title)").font(.caption).foregroundStyle(.secondary) }
            }
            if let next = cur.next {
                let crit = Progression.criteria(s, for: next, rank: s.progression.rank == 0 ? nil : s.progression.rank)
                HStack(spacing: 8) {
                    ForEach(crit) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 2) {
                                if c.met { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Theme.good).accessibilityLabel("Met") }
                                Text(c.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Meter(value: c.progress, tint: c.met ? Theme.good : .accentColor, height: 5)
                        }
                        .help("\(c.label): \(c.have) of \(c.need)")
                    }
                }
            }
            if let r = s.launches.last(where: { $0.by != "family" }) {
                HStack {
                    Text("Last launch: \(r.modelName)").font(.caption).lineLimit(1)
                    Spacer()
                    if let rep = r.report {
                        Pill(text: rep.verdictTitle, color: rep.verdictColor, symbol: rep.verdictSymbol)
                        Button("Report") { store.launchReportID = r.id }.buttonStyle(.link).font(.caption)
                    } else {
                        Text("report \(GameCalendar.addDays(r.date, 7).gameShort)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
