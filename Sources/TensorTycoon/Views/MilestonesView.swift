import SwiftUI

// MARK: - 3.4: the AI milestones race

struct MilestonesView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let wins = s.milestoneWins
        let tally = Milestones.tally(s)
        let mine = tally["player"] ?? 0
        let top = tally.filter { $0.key != "player" }.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }
        let next = Milestones.nextUp(s, count: 6)
        Page(title: "AI Milestones",
             subtitle: "The firsts every lab races for, from beating people at reading in 2018 to robots in every home. The first released model to clear a milestone's bars gets it: its lab makes the news and gains brand. \(CapStyle.scaleNote)", screen: .milestones) {
            KPIRow {
                StatTile(title: "Reached", value: "\(wins.count) of \(MilestoneCatalog.all.count)",
                         detail: wins.last.map { "Latest: \(MilestoneCatalog.byID[$0.id]?.title ?? $0.id)" }, symbol: "signpost.right.fill", tint: .indigo)
                StatTile(title: "Yours first", value: "\(mine)", detail: mine == 0 ? "Ship a model that clears one first" : "Each one adds brand",
                         symbol: "flag.fill", tint: .green)
                StatTile(title: "Most firsts", value: top.map { CapStyle.labName($0.key, s) } ?? "—",
                         detail: top.map { "\($0.value) milestones" }, symbol: "trophy.fill", tint: .orange)
                StatTile(title: "Next up", value: next.first?.title ?? "All reached",
                         detail: next.first.map { "Expected \($0.real ? "" : "around ")\($0.real ? $0.whenLabel : String(Int($0.year)))" },
                         symbol: "scope", tint: .purple)
            }
            HStack(alignment: .top, spacing: Theme.gap) {
                MilestoneNextUpCard(state: s, next: next)
                MilestoneProgressCard(state: s)
                    .frame(width: 430)
            }
            MilestoneTimelineCard(state: s)
            MilestoneOpenCard(state: s, shown: Set(next.map(\.id)))
        }
    }
}

/// Requirements as compact chips: "Agents 158 · Social 145".
struct MilestoneNeeds: View {
    let needs: [(CapDomain, Double)]
    var scores: DomainScores? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(needs.prefix(5).enumerated()), id: \.offset) { _, n in
                let met = scores.map { $0[n.0] >= n.1 } ?? false
                Pill(text: "\(n.0.short) \(Int(n.1.rounded()))", color: met ? .green : .secondary, symbol: n.0.symbol)
            }
            if needs.count > 5 {
                Pill(text: "+\(needs.count - 5) more", color: .secondary)
                    .help(needs.dropFirst(5).map { "\($0.0.label) \(Int($0.1.rounded()))" }.joined(separator: " · "))
            }
        }
    }
}

private struct MilestoneNextUpCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let next: [MilestoneDef]

    var body: some View {
        let s = state
        Card {
            CardHeader("Next up", symbol: "scope", subtitle: "The open milestones the field is closest to, and how close each lab is")
            if next.isEmpty {
                Text("Every milestone has been reached.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(next) { ms in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: ms.symbol).foregroundStyle(.secondary)
                        Text(ms.title).font(.callout.weight(.semibold))
                        if ms.tier >= 3 { Pill(text: "Historic", color: .purple) }
                        Spacer()
                        Text(ms.real ? "Real world: \(ms.whenLabel)" : "Forecast: \(Int(ms.year))").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(ms.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    MilestoneNeeds(needs: ms.needs)
                    ForEach(Milestones.field(s, ms, limit: 4), id: \.lab) { row in
                        HStack(spacing: 8) {
                            Text(row.name).font(.caption).lineLimit(1).frame(width: 150, alignment: .leading)
                                .foregroundStyle(row.lab == "player" ? Color.primary : Color.secondary)
                            Meter(value: row.closeness, tint: CapStyle.labColor(row.lab, s), height: 7)
                            Text(Fmt.pct(row.closeness, decimals: 0)).font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                .padding(.vertical, 4)
                if ms.id != next.last?.id { Divider() }
            }
            Text("Closeness: 0% means \(Int(Milestones.span)) capability points short on the weakest requirement (about three years of frontier progress); 100% is there.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct MilestoneProgressCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let released = s.labDomains["player"]
        let open = openByCloseness(s, released)
        let shippable = Capabilities.playerBest(s, releasedOnly: false).map { v in open.filter { Milestones.meets(v, $0) } } ?? []
        let mine = Array(s.milestoneWins.filter(\.isPlayer).reversed())
        Card {
            CardHeader(title: "Your progress", symbol: "person.fill.checkmark", subtitle: "Your best released model against each open milestone") {
                Button("Model Lab") { store.open(.lab) }.buttonStyle(.link)
            }
            if released == nil {
                Text("Release a model to enter the race.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(open.prefix(8))) { ms in
                MilestoneProgressRow(ms: ms, scores: released)
            }
            if !shippable.isEmpty {
                Label(shipNote(shippable), systemImage: "shippingbox.fill").font(.caption).foregroundStyle(.orange)
            }
            if !mine.isEmpty {
                Divider()
                Text("Firsts you hold").font(.caption.weight(.semibold))
                ForEach(mine) { w in MilestoneWinRow(win: w, color: .green) }
            }
        }
    }

    private func openByCloseness(_ s: GameState, _ v: DomainScores?) -> [MilestoneDef] {
        let reached = Milestones.won(s)
        let open = MilestoneCatalog.all.filter { !reached.contains($0.id) }
        let scored = open.map { (ms: $0, c: Milestones.closeness(v, $0)) }
        return scored.sorted { $0.c != $1.c ? $0.c > $1.c : $0.ms.year < $1.ms.year }.map(\.ms)
    }

    private func shipNote(_ list: [MilestoneDef]) -> String {
        "An unreleased model of yours already clears: \(list.prefix(3).map(\.title).joined(separator: ", ")). Release it to claim \(list.count == 1 ? "it" : "them")."
    }
}

private struct MilestoneProgressRow: View {
    let ms: MilestoneDef
    let scores: DomainScores?

    var body: some View {
        let c = Milestones.closeness(scores, ms)
        let gap = Milestones.gap(scores, ms)
        let note = gap.isFinite ? (gap < 0.05 ? "Ready" : "\(Fmt.trim(gap, 1)) pts to go") : "—"
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(ms.title).font(.caption.weight(.semibold)).lineLimit(1)
                Spacer()
                Text(note).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Meter(value: c, tint: c >= 1 ? .green : .accentColor, height: 6)
        }
    }
}

/// One milestone someone reached first: icon, title, model and date.
struct MilestoneWinRow: View {
    let win: MilestoneWin
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: MilestoneCatalog.byID[win.id]?.symbol ?? "flag.fill").font(.caption2).foregroundStyle(color)
            Text(MilestoneCatalog.byID[win.id]?.title ?? win.id).font(.caption)
            Spacer()
            Text("\(win.model) · \(win.date.gameMonth)").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct MilestoneTimelineCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let wins = s.milestoneWins.reversed()
        Card {
            CardHeader("Timeline", symbol: "calendar", subtitle: "Who got there first, with which model, and when (newest first)")
            if wins.isEmpty {
                Text("No milestone has been reached yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(wins)) { w in
                if let ms = MilestoneCatalog.byID[w.id] {
                    HStack(alignment: .top, spacing: 10) {
                        Text(w.date.gameMonth).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 74, alignment: .leading)
                        Image(systemName: ms.symbol).foregroundStyle(CapStyle.labColor(w.labID, s)).frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(ms.title).font(.callout.weight(ms.tier >= 3 ? .semibold : .regular))
                                if w.isPlayer { Pill(text: "You", color: .green, symbol: "flag.fill") }
                                if w.history { Pill(text: "Before you started", color: .secondary) }
                            }
                            Text(ms.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            labLink(w, s)
                            Text(w.model).font(.caption2).foregroundStyle(.secondary)
                            Text(ms.real ? "Real world: \(ms.whenLabel)" : "Forecast: \(Int(ms.year))").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func labLink(_ w: MilestoneWin, _ s: GameState) -> some View {
        if w.isPlayer {
            Text(w.lab).font(.caption.weight(.semibold)).foregroundStyle(CapStyle.labColor(w.labID, s))
        } else {
            Button(w.lab) { store.openLab(w.labID) }
                .buttonStyle(.link)
                .font(.caption.weight(.semibold))
        }
    }
}

private struct MilestoneOpenCard: View {
    let state: GameState
    let shown: Set<String>

    var body: some View {
        let s = state
        let reached = Milestones.won(s)
        let rest = MilestoneCatalog.all.filter { !reached.contains($0.id) && !shown.contains($0.id) }.sorted { $0.year < $1.year }
        if !rest.isEmpty {
            Card {
                CardHeader("Further out", symbol: "binoculars.fill", subtitle: "Still open, by when forecasters expect them")
                ForEach(rest) { ms in
                    HStack(spacing: 10) {
                        Text(ms.real ? ms.whenLabel : "~\(Int(ms.year))").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 74, alignment: .leading)
                        Image(systemName: ms.symbol).foregroundStyle(.secondary).frame(width: 18)
                        Text(ms.title).font(.callout)
                        Spacer()
                        MilestoneNeeds(needs: ms.needs, scores: s.labDomains["player"])
                    }
                    .help(ms.detail)
                }
            }
        }
    }
}

// MARK: - Dashboard card

/// The milestones race at a glance, for the dashboard: the latest firsts and what's next.
struct MilestonesCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let latest = s.milestoneWins.suffix(3).reversed()
        let next = Milestones.nextUp(s, count: 2)
        let mine = s.milestoneWins.filter(\.isPlayer).count
        Card {
            CardHeader(title: "AI milestones", symbol: "signpost.right.fill",
                       subtitle: "\(s.milestoneWins.count) of \(MilestoneCatalog.all.count) reached · \(mine) first by you") {
                Button("All milestones") { store.open(.milestones) }.buttonStyle(.link)
            }
            ForEach(Array(latest)) { w in
                HStack(spacing: 8) {
                    Image(systemName: MilestoneCatalog.byID[w.id]?.symbol ?? "flag.fill").font(.caption).foregroundStyle(CapStyle.labColor(w.labID, s))
                    Text(MilestoneCatalog.byID[w.id]?.title ?? w.id).font(.caption).lineLimit(1)
                    Spacer()
                    Text("\(w.isPlayer ? "You" : w.lab) · \(w.date.gameMonth)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if !next.isEmpty { Divider() }
            ForEach(next) { ms in
                let field = Milestones.field(s, ms, limit: 1)
                let me = Milestones.closeness(s.labDomains["player"], ms)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Next: \(ms.title)").font(.caption.weight(.semibold)).lineLimit(1)
                        Spacer()
                        if let lead = field.first {
                            Text("\(lead.lab == "player" ? "You lead" : lead.name) \(Fmt.pct(lead.closeness, decimals: 0))").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Meter(value: me, tint: CapStyle.labColor("player", s), height: 6)
                    Text("You: \(Fmt.pct(me, decimals: 0)) of the way").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
