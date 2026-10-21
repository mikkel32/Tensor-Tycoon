import Charts
import SwiftUI

// MARK: - 3.9: the epilogue, the Legacy screen and the New Game+ perk picker

private extension EndingKind {
    var tone: Tone { mood > 0 ? .good : mood < 0 ? .bad : .info }
    var tint: Color { mood > 0 ? .yellow : mood < 0 ? .red : .teal }
}

/// The end of a game: the ending, the story, the company's history, the numbers, the score and what it unlocks.
struct EpilogueSheet: View {
    @Environment(GameStore.self) private var store
    @State private var unlocked: [LegacyPerk] = []
    @State private var recorded = false

    var body: some View {
        // The sheet can re-render while it dismisses after the game is closed.
        if let s = store.state {
            VStack(spacing: 0) {
                ScrollView {
                    EpilogueContent(state: s, final: true, unlocked: unlocked)
                        .padding(.bottom, 12)
                }
                Divider()
                HStack {
                    Text("Your save keeps this epilogue; reopen it from the main menu any time.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Main Menu") { store.quitToMenu() }
                    Button {
                        store.quitToMenu()
                    } label: {
                        Label(unlocked.isEmpty ? "Found a new company" : "New Game+", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .help("Back to the main menu, where your legacy perks are waiting on the new-company card.")
                }
                .padding(16)
            }
            .frame(width: 900, height: 760)
            .onAppear {
                guard !recorded else { return }
                recorded = true
                unlocked = LegacyVault.record(s)
            }
        }
    }
}

/// The epilogue's content, shared by the end-of-game sheet (`final`) and the Legacy screen's "story so far".
struct EpilogueContent: View {
    let state: GameState
    var final = true
    var unlocked: [LegacyPerk] = []
    @State private var tab: Tab

    init(state: GameState, final: Bool = true, unlocked: [LegacyPerk] = [], tab: Tab = .story) {
        self.state = state
        self.final = final
        self.unlocked = unlocked
        _tab = State(initialValue: tab)
    }

    enum Tab: String, CaseIterable, Identifiable {
        case story = "Story", timeline = "Timeline", numbers = "Numbers", score = "Score"
        var id: String { rawValue }
    }

    var body: some View {
        let s = state
        let k = final ? Endings.classify(s) : Endings.retirement(s)
        let score = Endings.score(s, final ? k : nil)
        let grade = Endings.grade(score.total)
        VStack(alignment: .leading, spacing: 16) {
            if final { hero(s, k, score, grade) }
            SectionTabs(selection: $tab, options: Tab.allCases)
            switch tab {
            case .story: story(s, k)
            case .timeline: EpilogueTimeline(moments: Endings.timeline(s), limit: final ? nil : 60)
            case .numbers: numbers(s)
            case .score: scoreCard(score, grade, final: final)
            }
        }
        .padding(final ? 20 : 0)
    }

    private func hero(_ s: GameState, _ k: EndingKind, _ score: Endings.Score, _ grade: (title: String, symbol: String)) -> some View {
        Photo(key: k.image, thumb: false)
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .overlay(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EPILOGUE · \(s.companyName.uppercased())")
                            .font(.caption.weight(.heavy)).tracking(2).opacity(0.8)
                        Label(k.title, systemImage: k.symbol)
                            .font(.system(size: 34, weight: .heavy))
                        Text(k.tagline).font(.callout).opacity(0.9)
                        Text("\(s.startDate.gameMonth) – \((s.endings.endedOn ?? s.date).gameMonth)").font(.caption).opacity(0.75)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Final score").font(.caption).opacity(0.8)
                        Text(Fmt.int(score.total)).font(TypeRamp.display)
                        Label(grade.title, systemImage: grade.symbol).font(.callout.weight(.semibold)).foregroundStyle(k.tint)
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
                .padding(20)
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.hero))
            .help(ImageLibrary.tooltip(k.image, illustrative: false))
    }

    @ViewBuilder
    private func story(_ s: GameState, _ k: EndingKind) -> some View {
        Card {
            CardHeader(final ? "How it ended" : "If you retired today", symbol: "text.book.closed.fill",
                       subtitle: final ? s.gameOver : "Ending: \(k.title)")
            ForEach(Array(Endings.story(s, k).enumerated()), id: \.offset) { _, p in
                Text(p).font(.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        if final {
            Card {
                CardHeader("What became of them", symbol: "person.3.fill")
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ForEach(Array(Endings.people(s, k).enumerated()), id: \.offset) { _, p in
                        GridRow {
                            Text(p.name).font(.callout.weight(.semibold))
                            Text(p.role).font(.caption).foregroundStyle(.secondary)
                            Text(p.fate).font(.callout)
                        }
                    }
                }
            }
            LegacyUnlockCard(ending: k, unlocked: unlocked)
        }
    }

    @ViewBuilder
    private func numbers(_ s: GameState) -> some View {
        let best = s.models.max { $0.index < $1.index }
        LazyVGrid(columns: Theme.tileColumns, spacing: Theme.Space.m) {
            StatTile(title: "Years in business", value: Fmt.trim(Double(GameCalendar.daysBetween(s.startDate, s.endings.endedOn ?? s.date)) / 365.25, 1), symbol: "calendar")
            StatTile(title: "Peak valuation", value: Fmt.money(Endings.peakValuation(s)), symbol: "chart.line.uptrend.xyaxis", tint: .green)
            StatTile(title: "Best year of revenue", value: Fmt.money(Endings.bestYearRevenue(s)), symbol: "dollarsign.circle.fill", tint: .green)
            StatTile(title: "Lifetime revenue", value: Fmt.money(s.lifetimeRevenue), symbol: "banknote.fill", tint: .green)
            StatTile(title: "Best model", value: best.map { Fmt.score($0.index) } ?? "—", detail: best?.name, symbol: "cube.box.fill", tint: .indigo)
            StatTile(title: "Best rank", value: bestRank(s) > 0 ? "#\(bestRank(s))" : "—", detail: s.monthsAtTop > 0 ? "\(s.monthsAtTop) months at #1 (latest run)" : nil, symbol: "trophy.fill", tint: .yellow)
            StatTile(title: "Milestones claimed", value: "\(s.milestoneWins.filter { $0.labID == "player" && !$0.history }.count)", symbol: "signpost.right.fill", tint: .orange)
            StatTile(title: "Compute used", value: Fmt.flops(s.lifetimeFLOPs), detail: "FLOPs", symbol: "cpu.fill", tint: .purple)
            StatTile(title: "Raised", value: Fmt.money(s.rounds.reduce(0) { $0 + $1.amount }), detail: "\(s.rounds.count) round\(s.rounds.count == 1 ? "" : "s")", symbol: "banknote", tint: .teal)
            StatTile(title: "Team", value: Fmt.int(s.employees.count), detail: "people at the end", symbol: "person.3.fill", tint: .blue)
            StatTile(title: "Achievements", value: "\(s.achievements.count) / \(AchievementCatalog.all.count)", symbol: "medal.fill", tint: .yellow)
            StatTile(title: "Founder net worth", value: Fmt.money(s.founderCash + s.founderStake * (s.exitValue ?? ((s.keptStake || s.gameOver == nil) ? s.valuation : 0))),
                     symbol: "person.crop.circle.fill", tint: .green)
        }
        if s.history.count >= 3 {
            ChartCard("Valuation over the years", symbol: "chart.xyaxis.line", height: 180, caption: "Month-end valuation (market cap once public), on a log scale.") {
                Chart(s.history.filter { $0.valuation > 0 }, id: \.month) { m in
                    // No area fill: an area starts at zero, which a log scale can't draw (Charts traps on it).
                    LineMark(x: .value("Month", m.month, unit: .month), y: .value("Valuation", m.valuation))
                        .foregroundStyle(.green)
                }
                .chartYScale(type: .log)
                .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
            }
        }
    }

    /// Best leaderboard rank seen (a save loaded mid-game starts from today's).
    private func bestRank(_ s: GameState) -> Int {
        let now = s.progression.rank
        return [s.endings.bestRank, now].filter { $0 > 0 }.min() ?? 0
    }

    private func scoreCard(_ score: Endings.Score, _ grade: (title: String, symbol: String), final: Bool) -> some View {
        Card {
            CardHeader("Score", symbol: "sum", subtitle: final ? "The legacy score plus the ending's bonus." : "The legacy score so far; the ending adds its bonus when the game ends.")
            ForEach(score.lines) { l in
                HStack {
                    Text(l.label)
                    Text(l.detail).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(l.points >= 0 ? "+\(Fmt.int(l.points))" : Fmt.int(l.points)).monospacedDigit()
                        .foregroundStyle(l.points >= 0 ? Color.primary : Theme.bad)
                }
                .font(.callout)
            }
            Divider()
            HStack {
                Label(grade.title, systemImage: grade.symbol).font(.headline)
                Spacer()
                Text(Fmt.int(score.total)).font(TypeRamp.heroMetric)
            }
            Text("Verdicts: Forgotten under 600 · A footnote · Notable from 1,500 · Celebrated from 3,000 · Historic from 5,000 · Legendary from 8,000.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// The company's history, grouped by year.
struct EpilogueTimeline: View {
    let moments: [Endings.Moment]
    var limit: Int? = nil

    var body: some View {
        let shown = limit.map { Array(moments.suffix($0)) } ?? moments
        let years = Dictionary(grouping: shown) { $0.date.ym.year }
        Card {
            CardHeader("Timeline", symbol: "clock.arrow.circlepath",
                       subtitle: "\(moments.count) moments: launches, rounds, records, milestones, crises, people\(limit != nil && moments.count > (limit ?? 0) ? " — the latest \(limit!) shown" : "")")
            ForEach(years.keys.sorted(), id: \.self) { y in
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(y)).font(.title3.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(years[y] ?? []) { m in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: m.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(color(m).gradient, in: .circle)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(m.title).font(.callout.weight(.semibold))
                                    Spacer()
                                    Text(m.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                if !m.detail.isEmpty { Text(m.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func color(_ m: Endings.Moment) -> Color {
        if m.good == false { return .red }
        switch m.kind {
        case "model": return .indigo
        case "money": return .green
        case "milestone": return .orange
        case "people": return .blue
        case "policy": return .teal
        case "safety": return .mint
        case "record", "rank", "victory": return .yellow
        case "ending": return .purple
        default: return .gray
        }
    }
}

/// What this ending unlocks for the next company.
private struct LegacyUnlockCard: View {
    let ending: EndingKind
    let unlocked: [LegacyPerk]

    var body: some View {
        let vault = LegacyVault.load()
        Card {
            CardHeader("Legacy", symbol: "gift.fill", subtitle: "\(vault.endings.count) of \(EndingKind.allCases.count) endings reached across your games · \(vault.slots) perk slot\(vault.slots == 1 ? "" : "s") for your next company")
            HStack(spacing: 12) {
                Image(systemName: ending.perk.symbol).font(.title2).foregroundStyle(ending.tint)
                    .frame(width: 44, height: 44).background(ending.tint.opacity(0.15), in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(ending.perk.title).font(.headline)
                        if unlocked.contains(ending.perk) { Pill("New perk unlocked", tone: .good) } else { Pill("Already unlocked", tone: .neutral) }
                    }
                    Text(ending.perk.detail).font(.callout).foregroundStyle(.secondary)
                }
            }
            if unlocked.count > 1 || (unlocked.count == 1 && unlocked.first != ending.perk) {
                Text("Also unlocked: \(unlocked.filter { $0 != ending.perk }.map(\.title).joined(separator: ", ")).").font(.caption)
            }
            Text("Pick perks on the new-company card. A third different ending gives a second slot; a seventh, a third.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - The Legacy screen

struct LegacyView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmRetire = false
    @State private var vault = LegacyVault()

    var body: some View {
        let s = store.game
        let score = Endings.score(s, nil)
        let grade = Endings.grade(score.total)
        let retire = Endings.retirement(s)
        Page(title: "Legacy & Endings", subtitle: "How your company's story could end, what it has done so far, and the head start it leaves the next one.", screen: .legacy) {
            HeroBanner(image: "city_nyc", height: 150) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.companyName).font(.title.weight(.bold))
                        Text("Founded \(s.startDate.gameMonth) · \(Endings.timeline(s).count) moments in its history · retiring now: \(retire.title)")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Legacy score").font(.caption).opacity(0.8)
                        Text(Fmt.int(score.total)).font(TypeRamp.bannerMetric)
                        Label(grade.title, systemImage: grade.symbol).font(.caption.weight(.semibold))
                    }
                }
            }

            Card {
                CardHeader(title: "Endings in reach", symbol: "signpost.right.and.left.fill",
                           subtitle: "None of these ends the game by itself: each is offered, and an unanswered offer always keeps you playing.") {
                    Button {
                        confirmRetire = true
                    } label: { Label("Retire…", systemImage: "figure.walk.departure") }
                    .disabled(GameCalendar.daysBetween(s.startDate, s.date) < Endings.minDaysToRetire || s.gameOver != nil)
                    .help(GameCalendar.daysBetween(s.startDate, s.date) < Endings.minDaysToRetire ? "Available after your first year." : "End the game now with the \(retire.title) ending.")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                    ForEach(Endings.reach(s)) { r in
                        ReachTile(reach: r, seen: vault.endings[r.kind.rawValue] != nil)
                    }
                }
            }

            CardGrid(minWidth: 340, maxColumns: 3) {
                ArcsCard(state: s)
                Card {
                    CardHeader("Endings you've reached", symbol: "books.vertical.fill", subtitle: "\(vault.endings.count) of \(EndingKind.allCases.count), across every game on this Mac")
                    ForEach(EndingKind.allCases) { k in
                        let rec = vault.endings[k.rawValue]
                        HStack(spacing: 8) {
                            Image(systemName: rec == nil ? "lock.fill" : k.symbol).foregroundStyle(rec == nil ? Color.secondary : k.tint).frame(width: 18)
                            Text(rec == nil ? "???" : k.title).font(.callout).foregroundStyle(rec == nil ? .secondary : .primary)
                            Spacer()
                            if let rec { Text("\(rec.company) · \(Fmt.int(rec.score))").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                        }
                        .help(rec == nil ? k.hint : k.tagline)
                    }
                }
                Card {
                    CardHeader("Legacy perks", symbol: "gift.fill", subtitle: s.endings.perks.isEmpty ? "This company started without any" : "This company started with")
                    ForEach(s.endings.perks.compactMap(LegacyPerk.init(rawValue:))) { p in
                        Label { VStack(alignment: .leading) { Text(p.title).font(.callout.weight(.semibold)); Text(p.detail).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: p.symbol) }
                    }
                    Divider()
                    Text("Unlocked for your next company: \(vault.unlocked.isEmpty ? "none yet — finish a game" : LegacyPerk.allCases.filter { vault.unlocked.contains($0) }.map(\.title).joined(separator: ", ")).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            EpilogueContent(state: s, final: false)
        }
        .onAppear { vault = LegacyVault.load() }
        .confirmationDialog("Retire and end the game?", isPresented: $confirmRetire, titleVisibility: .visible) {
            Button("Retire: \(retire.title)") {
                store.mutate { s in _ = Endings.retire(&s) }
                store.setSpeed(0)
            }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("You hand \(s.companyName) to a successor and keep your shares. The game ends with the \(retire.title) ending (bonus \(Fmt.int(retire.bonus))) and its epilogue, and unlocks \(retire.perk.title) for your next company.")
        }
    }
}

private struct ReachTile: View {
    let reach: Endings.Reach
    let seen: Bool

    var body: some View {
        let k = reach.kind
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: k.symbol).foregroundStyle(k.tint)
                Text(k.title).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                if seen { Image(systemName: "checkmark.seal.fill").foregroundStyle(.secondary).help("You've reached this ending in an earlier game.") }
            }
            Text(reach.status).font(.caption2).foregroundStyle(.secondary).lineLimit(3, reservesSpace: true)
            if let p = reach.progress {
                Meter(value: p, tint: p >= 1 ? .yellow : k.tint.opacity(0.8), height: 6)
            }
            Text("Unlocks \(k.perk.title) · bonus \(Fmt.int(k.bonus))").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
        .help(k.hint)
    }
}

/// The arcs in motion: the Compact, the state's pressure, the race, near misses.
private struct ArcsCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let t = s.endings.treaty
        Card {
            CardHeader("Arcs in motion", symbol: "point.3.connected.trianglepath.dotted")
            SpecRow(label: "\(Endings.compact)", value: t.stage == 0 ? "Not yet" : t.stage == 1 ? "Talks until \(t.due?.gameMonth ?? "?")" : "Signed \(t.signed?.gameMonth ?? "")",
                    tone: t.shaped && t.stance > 0 ? .good : nil)
            if t.stage >= 1 {
                SpecRow(label: "Your side", value: t.stance > 0 ? "Safety coalition" : t.stance < 0 ? "Light touch" : t.invited ? "Watching" : "No seat")
                if t.stance != 0 {
                    SpecRow(label: "Your weight", value: "\(Fmt.pct(t.share, decimals: 0)) (+\(Fmt.trim(Endings.treatyWeight(s), 1))/mo vs \(Fmt.trim(Endings.othersWeight, 0)))")
                    Meter(value: t.share / Endings.shapeShare, tint: t.share >= Endings.shapeShare ? .green : .teal, height: 6)
                }
            }
            SpecRow(label: "State pressure", value: s.endings.goldenShare ? "Golden share granted" : "\(Int(s.endings.friction))/100",
                    tone: s.endings.goldenShare ? .neutral : s.endings.friction >= 55 ? .warning : nil)
            SpecRow(label: "World concern about AI", value: "\(Int(s.world.concern))/100")
            SpecRow(label: "Months out of the race", value: "\(s.endings.irrelevant)", tone: s.endings.irrelevant >= 12 ? .warning : nil)
            SpecRow(label: "Near misses", value: "\(s.endings.nearMisses.count)")
            if let r = s.endings.brinkRisk {
                Label("A model shipped against your red team's advice; the patch is tested in the wild until \(r.gameMonth).", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - New Game+

/// The new-company card's legacy perks: unlocked by endings in earlier games, limited by slots.
struct LegacyPerkPicker: View {
    @Binding var perks: [String]
    @State private var vault = LegacyVault()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Legacy perks (New Game+)").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(perks.count) of \(vault.slots) slot\(vault.slots == 1 ? "" : "s") · \(vault.endings.count) of \(EndingKind.allCases.count) endings reached")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if vault.unlocked.isEmpty {
                Text("Finish a company — any ending, good or bad — to unlock a small head start for the next one.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                    ForEach(LegacyPerk.allCases.filter { vault.unlocked.contains($0) }) { p in
                        let on = perks.contains(p.rawValue)
                        Button {
                            if on { perks.removeAll { $0 == p.rawValue } } else if perks.count < vault.slots { perks.append(p.rawValue) }
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: on ? "checkmark.circle.fill" : p.symbol).foregroundStyle(on ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.title).font(.callout.weight(.semibold))
                                    Text(p.detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(on ? Color.green.opacity(0.12) : Theme.insetFill, in: .rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!on && perks.count >= vault.slots)
                        .help(on ? "Remove" : perks.count >= vault.slots ? "All slots are taken" : "Unlocked by: \(p.unlockedBy.map(\.title).joined(separator: ", "))")
                    }
                }
            }
        }
        .onAppear {
            vault = LegacyVault.load()
            perks = perks.filter { id in LegacyPerk(rawValue: id).map { vault.unlocked.contains($0) } ?? false }
        }
    }
}
