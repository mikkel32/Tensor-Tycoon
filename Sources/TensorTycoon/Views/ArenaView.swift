import SwiftUI

// MARK: - 3.9: the live model arena

/// The arena: the table (overall or one category) with each model's rating history, the weekly top 10, the battle
/// feed, the board's goal while one runs, and anonymous tests of your unreleased models.
struct ArenaView: View {
    @Environment(GameStore.self) private var store
    @State private var category: ArenaCategory? = nil
    @State private var showAll = false

    var body: some View {
        let s = store.game
        Page(title: "Model Arena",
             subtitle: "\(Arena.name(s.year)): crowds compare two anonymous answers and vote. Ratings move with every day's battles; a top spot sells your API and chat app.",
             screen: .arena) {
            ScreenHint(.arena)
            if s.arena.opened == nil {
                ArenaNotOpenCard(state: s)
            } else {
                ArenaHeadline(state: s)
                if let p = s.arena.pledge { ArenaPledgeCard(pledge: p, state: s) }
                HStack(alignment: .top, spacing: Theme.gap) {
                    ArenaTableCard(state: s, category: $category, showAll: $showAll)
                    VStack(spacing: Theme.gap) {
                        ArenaTopTenCard(state: s)
                        ArenaFeedCard(state: s)
                    }
                    .frame(width: 420)
                }
                ArenaAnonymousCard(state: s)
                ArenaHowCard(state: s)
            }
        }
    }
}

enum ArenaStyle {
    static func color(_ labID: String, _ s: GameState) -> Color { CapStyle.labColor(labID, s) }

    /// "kingfisher (your Atlas-3)" for your own anonymous tests; everyone else sees only the codename.
    static func label(_ e: ArenaEntry) -> String { e.anonymous && e.isPlayer ? "\(e.codename) (your \(e.name))" : e.shownName }

    static func movement(_ now: Int, _ before: Int) -> (text: String, color: Color, symbol: String?) {
        if before == 0 { return ("new", .blue, nil) }
        if before > now { return ("\(before - now)", Theme.good, "arrow.up") }
        if before < now { return ("\(now - before)", Theme.bad, "arrow.down") }
        return ("–", .secondary, nil)
    }
}

/// Before May 2023 (or five months after an early chat moment): what's coming.
struct ArenaNotOpenCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let when = Arena.openingYear(s)
        Card {
            CardHeader("No public arena yet", symbol: "figure.fencing",
                       subtitle: s.chatMoment == nil ? "It opens in May 2023, or about five months after chat assistants go mainstream if that happens sooner."
                                                     : "Chat assistants are mainstream: a public arena follows within months.")
            Text("When it opens, every released model (yours and the rivals') plays daily head-to-head battles judged by the crowd, with an Elo rating overall and for writing, coding and math; vision and agent battles follow. "
                 + "A top rank lifts demand for your API and chat app, and #1 makes headlines.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if when < 90 {
                Label("Expected around \(Fmt.trim(when, 1)).", systemImage: "calendar").font(.callout.weight(.medium))
            }
        }
    }
}

/// Your standing in numbers.
struct ArenaHeadline: View {
    let state: GameState

    var body: some View {
        let s = state
        let board = Arena.table(s, nil)
        let mine = board.first { $0.isPlayer && !$0.anonymous }
        let rank = mine.flatMap { s.arena.ranks[$0.id] }
        let pull = mine.flatMap { UUID(uuidString: $0.id) }.map { Arena.pull(s, $0) } ?? 1
        KPIRow {
            StatTile(title: "Your best model", value: rank.map { "#\($0) of \(board.count)" } ?? "Not ranked",
                     detail: mine.map { "\($0.name) · best ever #\(s.arena.bestRank)" } ?? "Release a model to enter",
                     symbol: "medal.fill", tint: rank == 1 ? .yellow : .accentColor, help: .arenaElo)
            StatTile(title: "Its rating", value: mine.map { "\(Int($0.overall.rounded())) ±\(Arena.interval($0))" } ?? "—",
                     detail: mine.map { $0.provisional ? "Preliminary: \($0.matches) battles" : "\(Fmt.int($0.matches)) battles, \(winRate($0)) won" } ?? "—",
                     symbol: "chart.line.uptrend.xyaxis", tint: .orange,
                     trend: mine.flatMap { e in e.history.count >= 2 ? e.history[e.history.count - 1] - e.history[e.history.count - 2] : nil })
            StatTile(title: "Weeks at #1", value: "\(s.arena.weeksAtTop)",
                     detail: s.arena.firstTop.map { "First on \($0.gameShort)" } ?? "Leader: \(s.arena.leaderModel)",
                     symbol: "crown.fill", tint: .yellow)
            StatTile(title: "Demand pull", value: pull == 1 ? "Neutral" : "\(pull > 1 ? "+" : "−")\(Fmt.trim(abs(pull - 1) * 100, 1))% brand",
                     detail: "On your API and chat app", symbol: "megaphone.fill", tint: pull >= 1 ? Theme.good : Theme.bad)
            StatTile(title: "Battles", value: Fmt.int(s.arena.matchCount), detail: "\(Fmt.count(s.arena.votes)) votes cast",
                     symbol: "person.2.wave.2.fill", tint: .purple)
        }
    }

    private func winRate(_ e: ArenaEntry) -> String { e.matches > 0 ? Fmt.pct(Double(e.wins) / Double(e.matches), decimals: 0) : "—" }
}

/// The board's goal: hold #1 on enough weekly tables.
struct ArenaPledgeCard: View {
    let pledge: ArenaPledge
    let state: GameState

    var body: some View {
        let p = pledge
        let left = p.weeksTotal - p.weeksSeen
        let spare = (p.weeksTotal - p.weeksNeeded) - (p.weeksSeen - p.weeksHeld)
        Card {
            CardHeader("Board goal: stay #1", symbol: "target",
                       subtitle: "Top the overall table on \(p.weeksNeeded) of \(p.weeksTotal) weekly tables (set \(p.started.gameShort) after \(p.model) took #1).")
            HStack(spacing: 14) {
                Meter(value: Double(p.weeksHeld) / Double(max(1, p.weeksNeeded)), tint: .yellow, height: 8)
                Text("\(p.weeksHeld)/\(p.weeksNeeded) weeks at #1").font(.callout.monospacedDigit().weight(.semibold))
            }
            HStack(spacing: 10) {
                Pill(text: "\(left) table\(left == 1 ? "" : "s") left", color: .secondary)
                Pill(spare > 0 ? "Can lose #1 \(spare) more time\(spare == 1 ? "" : "s")" : "No weeks to spare", tone: spare > 0 ? .neutral : .warning)
                Pill(text: "Pays \(Fmt.money(max(p.reward, Board.tranche(state) * 0.8))) · +\(Int(p.confidence)) confidence", color: Theme.good)
                Spacer(minLength: 0)
            }
        }
    }
}

/// The live table, overall or by category.
struct ArenaTableCard: View {
    let state: GameState
    @Binding var category: ArenaCategory?
    @Binding var showAll: Bool

    var body: some View {
        let s = state
        let cats = Arena.openCategories(s)
        let rows = Arena.table(s, category)
        let shown = showAll ? rows : rows.enumerated().filter { $0.offset < 15 || $0.element.isPlayer }.map(\.element)
        Card {
            CardHeader("Leaderboard", symbol: "list.number",
                       subtitle: category.map { "\($0.title): \($0.blurb)" } ?? "Every battle counts toward the overall rating. Arrows compare with the last weekly table.")
            Picker("Category", selection: $category) {
                Text("Overall").tag(ArenaCategory?.none)
                ForEach(cats) { c in Label(c.title, systemImage: c.symbol).tag(Optional(c)) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    Text("#").gridColumnAlignment(.trailing)
                    Text("")
                    Text("Model")
                    Text("Rating").gridColumnAlignment(.trailing)
                    Text("Last 26 weeks")
                    Text("Won").gridColumnAlignment(.trailing)
                    Text("Battles").gridColumnAlignment(.trailing)
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(shown) { e in
                    let rank = (rows.firstIndex { $0.id == e.id } ?? 0) + 1
                    row(e, rank: rank, s)
                }
            }
            if rows.count > 15 {
                Button(showAll ? "Show the top 15" : "Show all \(rows.count) models") { showAll.toggle() }.buttonStyle(.link)
            }
        }
    }

    @ViewBuilder
    private func row(_ e: ArenaEntry, rank: Int, _ s: GameState) -> some View {
        let tint = ArenaStyle.color(e.labID, s)
        let mv = category == nil ? ArenaStyle.movement(rank, s.arena.ranks[e.id] ?? 0) : nil
        let n = category.map { e.catMatches[$0.index] } ?? e.matches
        GridRow {
            Text("\(rank)").font(.callout.monospacedDigit().weight(rank <= 3 ? .bold : .regular))
            Group {
                if let mv {
                    HStack(spacing: 1) {
                        if let sym = mv.symbol { Image(systemName: sym) }
                        Text(mv.text)
                    }
                    .font(.caption2.weight(.semibold)).foregroundStyle(mv.color)
                } else {
                    Text("")
                }
            }
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 8, height: 8).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ArenaStyle.label(e)).font(.callout.weight(e.isPlayer ? .semibold : .regular)).lineLimit(1)
                    Text(e.anonymous ? "Anonymous" : e.lab).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                if e.provisional { Pill(text: "Preliminary", color: .orange) }
                if e.anonymous { Pill(text: "Codename", color: .purple, symbol: "theatermasks.fill") }
                if e.open { Pill(text: "Open", color: .teal) }
            }
            Text(verbatim: "\(Int(e.rating(category).rounded())) ±\(Arena.interval(e))").font(.callout.monospacedDigit())
            ArenaSparkline(values: Array(e.history.suffix(26)), tint: tint)
                .frame(width: 110, height: 20)
            Text(e.matches > 0 ? Fmt.pct(Double(e.wins) / Double(e.matches), decimals: 0) : "—").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text(Fmt.int(n)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 1)
        .background(e.isPlayer ? tint.opacity(0.08) : Color.clear)
        .accessibilityElement(children: .combine)
    }
}

/// A rating line, scaled to its own range: the shape is what matters.
struct ArenaSparkline: View {
    let values: [Double]
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { g in
            if values.count >= 2, let lo = values.min(), let hi = values.max() {
                let span = max(8, hi - lo)
                let pts = values.enumerated().map { k, v in
                    CGPoint(x: g.size.width * CGFloat(k) / CGFloat(values.count - 1),
                            y: g.size.height * (1 - CGFloat((v - lo) / span)) * 0.9 + g.size.height * 0.05)
                }
                Path { p in
                    p.move(to: pts[0])
                    for q in pts.dropFirst() { p.addLine(to: q) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                Circle().fill(tint).frame(width: 4, height: 4).position(pts[pts.count - 1])
            } else {
                Text("new").font(.caption2).foregroundStyle(.tertiary).frame(maxHeight: .infinity)
            }
        }
        .help(values.count >= 2 ? "Weekly overall rating: \(Int(values.first!)) → \(Int(values.last!))" : "On the board less than two weeks")
        .accessibilityLabel(values.count >= 2 ? "Rating from \(Int(values.first!)) to \(Int(values.last!))" : "New")
    }
}

/// The weekly top 10, overall.
struct ArenaTopTenCard: View {
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("This week's top 10", symbol: "crown.fill",
                       subtitle: s.arena.lastWeekly.map { "Published \($0.gameShort) · week \(s.arena.weeks)" } ?? "")
            ForEach(s.arena.top10) { t in
                let mv = ArenaStyle.movement(t.rank, t.prev)
                HStack(spacing: 8) {
                    Text("\(t.rank)").font(.callout.monospacedDigit().weight(.bold)).frame(width: 22, alignment: .trailing)
                    HStack(spacing: 1) {
                        if let sym = mv.symbol { Image(systemName: sym) }
                        Text(mv.text)
                    }
                    .font(.caption2.weight(.semibold)).foregroundStyle(mv.color).frame(width: 30, alignment: .leading)
                    Circle().fill(ArenaStyle.color(t.labID, s)).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(t.name).font(.callout.weight(t.labID == "player" ? .semibold : .regular)).lineLimit(1)
                    Text(t.lab).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(verbatim: "\(Int(t.rating))").font(.callout.monospacedDigit())
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The latest battles.
struct ArenaFeedCard: View {
    let state: GameState
    @State private var mineOnly = false

    var body: some View {
        let s = state
        let feed = s.arena.feed.filter { !mineOnly || $0.aLab == "player" || $0.bLab == "player" }.prefix(14)
        Card {
            CardHeader(title: "Latest battles", symbol: "bolt.fill", subtitle: "Each battle is a day's batch of votes between two models.") {
                Toggle("Yours", isOn: $mineOnly).toggleStyle(.switch).controlSize(.mini)
            }
            if feed.isEmpty {
                Text(mineOnly ? "None of your models has played yet." : "No battles yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(feed)) { m in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: m.category.symbol).font(.caption).foregroundStyle(.secondary).frame(width: 16).accessibilityLabel(m.category.title)
                        side(m.aName, lab: m.aLab, won: m.aWon && !m.tie, s)
                        Text(verbatim: "\(Int((m.shareA * 100).rounded()))–\(100 - Int((m.shareA * 100).rounded()))").font(.caption.monospacedDigit().weight(.semibold))
                        side(m.bName, lab: m.bLab, won: !m.aWon && !m.tie, s)
                        Spacer(minLength: 0)
                        if m.upset { Pill(text: "Upset", color: .pink, symbol: "exclamationmark") }
                    }
                    Text("\(m.category.title) · \(Fmt.int(m.votes)) votes · \(Int(m.ratingA.rounded())) vs \(Int(m.ratingB.rounded())) · \(Leaderboard.ago(m.date, now: s.date))")
                        .font(.caption2).foregroundStyle(.secondary).padding(.leading, 22)
                }
                .padding(.vertical, 2)
                .background((m.aLab == "player" || m.bLab == "player") ? Color.accentColor.opacity(0.06) : Color.clear, in: .rect(cornerRadius: 6))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func side(_ name: String, lab: String, won: Bool, _ s: GameState) -> some View {
        HStack(spacing: 4) {
            Circle().fill(ArenaStyle.color(lab, s)).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(name).font(.caption.weight(won ? .bold : .regular)).foregroundStyle(won ? .primary : .secondary).lineLimit(1)
        }
    }
}

/// Anonymous tests of trained models you haven't released.
struct ArenaAnonymousCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let unreleased = s.models.filter { !$0.released }.sorted { $0.c > $1.c }.prefix(6)
        let testing = s.arena.entries.filter { $0.active && $0.anonymous && $0.isPlayer }
        Card {
            CardHeader("Anonymous testing", symbol: "theatermasks.fill",
                       subtitle: "Labs try unreleased models on the arena under codenames. You see the real rating within a couple of weeks; the name comes off at release, and a strong proven rating makes the launch news. Up to \(Arena.maxAnonymous) at a time; testers sometimes guess the lab.")
            if unreleased.isEmpty {
                Text("No trained, unreleased model right now. Finish a run in Training to test it here before launch.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(unreleased)) { m in
                let e = testing.first { $0.id == m.id.uuidString }
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.name).font(.callout.weight(.semibold))
                        if let e {
                            Text("Playing as “\(e.codename)” · #\(s.arena.ranks[e.id].map(String.init) ?? "–") overall · \(Int(e.overall.rounded())) ±\(Arena.interval(e)) after \(e.matches) battles\(e.leaked ? " · testers suspect it's yours" : "")")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Capability \(Int(BenchmarkCatalog.capability(Leaderboard.profile(m)).rounded())) · static Elo estimate \(Int(Leaderboard.playerArena(m).rounded()))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if e != nil {
                        Button("Withdraw") { store.act("\(m.name) withdrawn from the arena.") { $0.arenaWithdraw(m.id) } }
                    } else {
                        Button("Test anonymously") { store.act { $0.arenaTestAnonymously(m.id) } }
                            .disabled(testing.count >= Arena.maxAnonymous)
                    }
                }
            }
        }
    }
}

/// How the ratings work, in one card.
struct ArenaHowCard: View {
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader("How the arena works", symbol: "info.circle")
            VStack(alignment: .leading, spacing: 6) {
                Label("Each model has a strength per category from its real capability profile: the domains the prompts test, plus chat style where voters care about it (most in writing, least in math).", systemImage: "scalemass")
                Label("A battle is a batch of votes. The stronger model usually wins, but the vote count and the day's prompts add luck, so upsets happen. Ratings move Elo-style: new models move fast and show a wide interval until about ten battles in.", systemImage: "dice")
                Label("Ratings are re-anchored weekly, so the scale stays comparable. The leaderboard's Elo column shows these live ratings.", systemImage: "arrow.left.and.right")
                Label("Where your models rank sways buyers: #1 adds 6% to your brand's pull on your API and chat app, the top 3 4%, the top 10 2%; below #20 a model looks dated (−2%). #1 also nudges your brand up every week.", systemImage: "megaphone")
                Label("Categories open as the real ones did: writing, coding and math from the start, vision battles from mid-2024, agent (WebDev) battles from late 2024.", systemImage: "calendar")
            }
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let o = s.arena.opened { Text("\(Arena.name(s.year)) has been running since \(o.gameShort).").font(.caption2).foregroundStyle(.tertiary) }
        }
    }
}
