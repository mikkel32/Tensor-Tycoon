import SwiftUI

// MARK: - 3.5: Events & Records — conferences, challenges, hackathons, the scenario and the hall of fame

/// One dated thing on the events calendar.
struct FunEvent: Identifiable {
    let id: String
    let date: Date
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
}

enum FunStyle {
    static func outcomeColor(_ o: PaperOutcome) -> Color {
        switch o {
        case .submitted: .secondary
        case .rejected: .red
        case .poster: .blue
        case .oral: .purple
        case .best: .orange
        }
    }

    static func tierColor(_ t: Int) -> Color { t >= 2 ? .orange : (t == 1 ? .green : .secondary) }

    /// The next conferences and challenges, merged and dated.
    static func calendar(_ s: GameState, count: Int = 8) -> [FunEvent] {
        var out: [FunEvent] = []
        for (v, d) in Conferences.upcoming(s, count: 5) {
            let mine = s.fun.papers.first { $0.venue == v.id && $0.year == d.ym.year }
            let status = mine.map { "Your paper: \($0.outcome.label.lowercased())" } ?? (s.publication == .secret ? "You don't publish" : "Call for papers \(GameCalendar.addDays(d, -Conferences.cfpLead).gameShort)")
            out.append(FunEvent(id: "conf|\(v.id)|\(d.ym.year)", date: d, title: "\(v.short) \(d.ym.year)", detail: "\(v.city) · \(status)",
                                symbol: "building.columns.fill", tint: .indigo))
        }
        for (c, d) in Contests.upcoming(s, count: 7) {
            let me = s.labDomains["player"]?[c.domain]
            let best = s.labDomains.filter { $0.key != "player" }.map { $0.value[c.domain] }.max() ?? 0
            let standing = me.map { $0 >= best ? "you lead the field" : "you trail by \(Int((best - $0).rounded()))" } ?? "ship a model to enter"
            out.append(FunEvent(id: "contest|\(c.id)|\(d.ym.year)", date: d, title: "\(c.name) \(d.ym.year)",
                                detail: "\(c.domain.short) · \(Fmt.money(c.purse)) purse · \(standing)", symbol: c.symbol, tint: .orange))
        }
        return Array(out.sorted { $0.date < $1.date }.prefix(count))
    }
}

struct EventsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let accepted = s.fun.papers.filter { $0.outcome == .poster || $0.outcome == .oral || $0.outcome == .best }.count
        let awards = s.fun.papers.filter { $0.outcome == .best }.count
        let wins = s.fun.contests.filter { $0.standings.first?.lab == "player" }.count
        Page(title: "Events & Records",
             subtitle: "Conferences, public challenges and hackathons: the industry's calendar, and what you've won on it. Your models enter every challenge automatically; papers wait in your inbox.", screen: .events) {
            if let d = Scenarios.def(s) { ScenarioCard(state: s, def: d) }
            KPIRow {
                StatTile(title: "Papers accepted", value: "\(accepted)", detail: "\(s.fun.papers.count) submitted", symbol: "doc.text.magnifyingglass", tint: .indigo)
                StatTile(title: "Best papers", value: "\(awards)", detail: s.fun.keynotes > 0 ? "\(s.fun.keynotes) keynote\(s.fun.keynotes == 1 ? "" : "s")" : "Orals and awards lift your brand",
                         symbol: "rosette", tint: .orange)
                StatTile(title: "Challenges won", value: "\(wins)", detail: s.fun.prizeMoney > 0 ? "\(Fmt.money(s.fun.prizeMoney)) in prizes" : "Your best model enters each one",
                         symbol: "trophy.circle.fill", tint: .yellow)
                StatTile(title: "Hackathons", value: "\(s.fun.hackathons.count)", detail: "\(s.fun.hackathons.filter { $0.tier == 2 }.count) hits", symbol: "party.popper.fill", tint: .pink)
            }
            HStack(alignment: .top, spacing: Theme.gap) {
                FunCalendarCard(state: s)
                HackathonCard(state: s)
                    .frame(width: 420)
            }
            CardGrid(minWidth: 340, maxColumns: 2) {
                PapersCard(state: s)
                ContestsCard(state: s)
            }
            ConferenceHistoryCard(state: s)
            RecordsCard(state: s)
        }
    }
}

// MARK: - Calendar

struct FunCalendarCard: View {
    let state: GameState

    var body: some View {
        Card {
            CardHeader("Coming up", symbol: "calendar", subtitle: "Conferences (papers) and challenges (your best released model enters)")
            if let next = Conferences.upcoming(state, count: 1).first {
                IllustrativeBanner(key: next.0.image, height: 90)
            }
            ForEach(FunStyle.calendar(state)) { e in
                HStack(spacing: 10) {
                    Image(systemName: e.symbol)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(e.tint.gradient, in: .rect(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.title).font(.callout.weight(.semibold))
                        Text(e.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(e.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Hackathons

struct HackathonCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let running = Hackathons.running(state)
        let blocker = Hackathons.blocker(state)
        Card {
            CardHeader("Hackathon week", symbol: "party.popper.fill",
                       subtitle: "Costs a week of research (\(Fmt.trim(Hackathons.cost(state), 0)) points) and \(Fmt.money(Hackathons.cashCost(state))) of pizza")
            IllustrativeBanner(key: ImagePicker.pick(.hackathon, seed: "hackathon \(state.date.ym.year)"), height: 80)
            if let h = running {
                Label("\(h.theme.title): \(h.people) people hacking until \(h.ends.gameShort)", systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.pink)
            } else {
                ForEach(HackTheme.allCases) { t in
                    Button {
                        store.act("Hackathon started: \(t.title.lowercased())") { $0.startHackathon(t) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: t.symbol).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.title).font(.callout.weight(.semibold))
                                Text(t.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                    .buttonStyle(.bordered)
                    .disabled(blocker != nil)
                }
                if let blocker { Text(blocker).font(.caption).foregroundStyle(.secondary) }
            }
            let done = state.fun.hackathons.filter(\.done).prefix(4)
            if !done.isEmpty {
                Divider()
                ForEach(Array(done)) { h in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Pill(text: h.tier >= 2 ? "Hit" : (h.tier == 1 ? "Decent" : "Flop"), color: FunStyle.tierColor(h.tier))
                            Text(h.headline).font(.caption.weight(.semibold)).lineLimit(1)
                        }
                        Text("\(h.ends.gameShort) · \(h.detail)").font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        }
    }
}

// MARK: - Papers

struct PapersCard: View {
    let state: GameState

    var body: some View {
        Card {
            CardHeader("Your papers", symbol: "doc.richtext",
                       subtitle: state.publication == .secret ? "Your Secretive policy keeps you out of conferences"
                                 : (state.publication == .open ? "Open science: your team submits its best work to every conference" : "Calls for papers arrive in your inbox"))
            if state.fun.papers.isEmpty {
                Text("No papers yet. Finish research of your own (or release a model) and the next call for papers will ask what to send.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(state.fun.papers.prefix(8))) { p in
                HStack(spacing: 8) {
                    Image(systemName: p.outcome.symbol).foregroundStyle(FunStyle.outcomeColor(p.outcome)).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.title).font(.callout).lineLimit(1)
                        Text("\(FunCatalog.venueByID[p.venue]?.short ?? p.venue) \(p.year)\(p.reveal ? " · revealed a unique breakthrough" : "")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Pill(text: p.outcome.label, color: FunStyle.outcomeColor(p.outcome))
                }
            }
        }
    }
}

// MARK: - Challenges

struct ContestsCard: View {
    let state: GameState

    var body: some View {
        Card {
            CardHeader("Challenge results", symbol: "trophy.fill", subtitle: "Every lab's best released model enters; beating the bar claims the grand prize")
            if state.fun.contests.isEmpty {
                Text("The first challenges open in 2018.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(state.fun.contests.prefix(7))) { r in
                let def = FunCatalog.contestByID[r.contest]
                let top = r.standings.first
                let mine = r.standings.firstIndex { $0.lab == "player" }
                HStack(spacing: 8) {
                    Image(systemName: def?.symbol ?? "trophy").foregroundStyle(top?.lab == "player" ? .orange : .secondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(def?.name ?? r.contest) \(r.year)").font(.callout).lineLimit(1)
                        Text("\(top.map { "\($0.model) (\(Fun.labName(state, $0.lab, short: true)))" } ?? "—")\(mine.map { $0 > 0 ? " · you \(Contests.ordinal($0 + 1))" : "" } ?? "")")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if r.grand { Pill(text: "Grand prize", color: .orange, symbol: "star.fill") }
                    if top?.lab == "player" { Pill("Won", tone: .good) }
                }
            }
            let open = FunCatalog.contests.filter { state.year >= Double($0.opens) }
            if !open.isEmpty {
                Divider()
                Text("Grand prize bars").font(.caption.weight(.semibold))
                ForEach(open) { c in
                    let me = state.labDomains["player"]?[c.domain] ?? 0
                    let bar = Contests.bar(c, state)
                    HStack(spacing: 8) {
                        Text(c.name).font(.caption).frame(width: 170, alignment: .leading).lineLimit(1)
                        Meter(value: me > 0 ? me / bar : 0, tint: me >= bar ? .orange : .accentColor, height: 6)
                        Text("\(Int(me)) / \(Int(bar))").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                    }
                    .help("\(c.task) Grand prize (\(Fmt.money(c.grandPrize))): \(Cast.lowerFirst(c.grandGoal)).")
                }
            }
        }
    }
}

// MARK: - Conference history

struct ConferenceHistoryCard: View {
    let state: GameState

    var body: some View {
        Card {
            CardHeader("Best papers", symbol: "rosette", subtitle: "Who took the award at each conference")
            if state.fun.editions.isEmpty {
                Text("No conferences since you started. The next one is \(Conferences.upcoming(state, count: 1).first.map { "\($0.0.short), \($0.1.gameShort)" } ?? "soon").")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                ForEach(Array(state.fun.editions.prefix(10))) { e in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("\(FunCatalog.venueByID[e.venue]?.short ?? e.venue) \(e.year)").font(.caption.weight(.semibold))
                            Spacer()
                            if e.keynote == "player" { Pill(text: "Your keynote", color: .purple, symbol: "mic.fill") }
                        }
                        Text("\"\(e.bestTitle)\"").font(.callout).lineLimit(2)
                        Text(Fun.labName(state, e.bestLab)).font(.caption).foregroundStyle(e.bestLab == "player" ? .orange : .secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.insetFill, in: .rect(cornerRadius: Theme.Radius.inset))
                }
            }
        }
    }
}

// MARK: - Scenario

struct ScenarioCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let def: ScenarioDef

    var body: some View {
        let outcome = state.fun.scenarioOutcome
        let progress = Scenarios.progress(state)
        HeroBanner(image: def.image, height: 170) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: def.symbol)
                    Text("Challenge: \(def.title)").font(.title2.weight(.bold))
                    if let o = outcome { Pill(text: o.won ? "Won · \(o.score)" : "Failed · \(o.score)", color: o.won ? .green : .red) }
                }
                Text(outcome?.summary ?? def.goal).font(.callout)
                if outcome == nil {
                    HStack(spacing: 10) {
                        if let p = progress {
                            Meter(value: p, tint: .green, height: 7).frame(width: 220)
                            Text("\(Int(p * 100))%").font(.caption.monospacedDigit())
                        }
                        Text("Deadline \(def.deadline.gameShort) · \(max(0, GameCalendar.daysBetween(state.date, def.deadline))) days left · lose if: \(Cast.lowerFirst(def.lose))")
                            .font(.caption)
                    }
                } else {
                    Text("The game carries on as a sandbox. Your score is in the records below.").font(.caption)
                }
            }
        }
    }
}

// MARK: - Records

struct RecordsCard: View {
    let state: GameState
    @State private var hall = HallOfFame()

    var body: some View {
        let mine = HallOfFame.values(state)
        let game = HallOfFame.gameKey(state)
        Card {
            CardHeader("Hall of fame", symbol: "crown.fill", subtitle: "Your best across every game on this Mac (\(max(1, hall.games.count)) played). This game's numbers on the right.")
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                ForEach(HallOfFame.kinds) { k in
                    let rec = hall.records[k.id]
                    GridRow {
                        Label(k.title, systemImage: k.symbol).font(.callout)
                        Text(rec.map { "\($0.detail) · \($0.company)" } ?? "—")
                            .font(.callout).foregroundStyle(rec?.game == game ? .orange : .primary).lineLimit(1)
                        Text(mine[k.id]?.1 ?? "—").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            let scores = FunCatalog.scenarios.compactMap { d in hall.scenarios[d.id].map { (d, $0) } }
            if !scores.isEmpty {
                Divider()
                Text("Challenge high scores").font(.caption.weight(.semibold))
                ForEach(scores, id: \.0.id) { d, r in
                    HStack {
                        Label(d.title, systemImage: d.symbol).font(.callout)
                        Spacer()
                        Text("\(Int(r.value)) · \(r.detail) · \(r.company)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { hall = HallOfFame.load() }
    }
}

// MARK: - Dashboard card (self-contained; not yet placed on the dashboard)

/// The next event, a running hackathon and the scenario at a glance. Opens Events & Records.
struct FunDashboardCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let next = FunStyle.calendar(s, count: 2)
        Card {
            CardHeader(title: "Events", symbol: "trophy.circle.fill") {
                Button("Open") { store.open(.events) }.buttonStyle(.borderless)
            }
            if let d = Scenarios.def(s) {
                HStack {
                    Image(systemName: d.symbol)
                    Text(d.title).font(.callout.weight(.semibold))
                    Spacer()
                    if let o = s.fun.scenarioOutcome {
                        Pill(text: o.won ? "Won · \(o.score)" : "Failed", color: o.won ? .green : .red)
                    } else if let p = Scenarios.progress(s) {
                        Meter(value: p, tint: .green, height: 6).frame(width: 90)
                    }
                }
            }
            if let h = Hackathons.running(s) {
                Label("Hackathon (\(h.theme.title.lowercased())) until \(h.ends.gameShort)", systemImage: "party.popper.fill").font(.caption).foregroundStyle(.pink)
            }
            ForEach(next) { e in
                HStack {
                    Image(systemName: e.symbol).foregroundStyle(e.tint)
                    Text(e.title).font(.caption)
                    Spacer()
                    Text(e.date.gameShort).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Scenario picker (main menu)

struct ScenarioPickerSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picked = FunCatalog.scenarios[0].id
    @State private var settings = NewGameSettings()
    @State private var hall = HallOfFame()

    var body: some View {
        let d = FunCatalog.scenarioByID[picked] ?? FunCatalog.scenarios[0]
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Challenges").font(.title.weight(.bold))
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Curated starts with a goal, a deadline and a score. When a challenge ends, win or lose, the company carries on as a normal game.")
                .font(.callout).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(FunCatalog.scenarios) { sc in
                            Button { picked = sc.id } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: sc.symbol).frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sc.title).font(.callout.weight(.semibold))
                                        Text(sc.tagline).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(String(repeating: "★", count: sc.stars)).font(.caption).foregroundStyle(.orange)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(picked == sc.id ? Color.accentColor.opacity(0.18) : Color.clear, in: .rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: 330)
                VStack(alignment: .leading, spacing: 10) {
                    Photo(key: d.image, thumb: false).frame(height: 130).clipShape(.rect(cornerRadius: 12))
                    Text(d.title).font(.title2.weight(.bold))
                    Text(d.story).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Label(d.goal, systemImage: "flag.checkered").font(.callout.weight(.semibold))
                    Label("You lose if: \(Cast.lowerFirst(d.lose))", systemImage: "xmark.octagon").font(.caption).foregroundStyle(.secondary)
                    Text("Starts \(Era.all.first { $0.id == d.era }?.subtitle ?? d.era) · \(d.doctrine.title) · \(d.background.title) · deadline \(d.deadline.gameShort)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let best = hall.scenarios[d.id] {
                        Label("Your best: \(Int(best.value)) (\(best.detail), \(best.company))", systemImage: "crown.fill").font(.caption).foregroundStyle(.orange)
                    }
                    HStack {
                        TextField("Company", text: $settings.companyName).textFieldStyle(.roundedBorder)
                        TextField("Founder", text: $settings.founderName).textFieldStyle(.roundedBorder)
                    }
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        Button {
                            store.newGame(Scenarios.settings(d, from: settings))
                            store.mutate { Scenarios.apply(&$0, d) }
                            dismiss()
                        } label: {
                            Label("Start challenge", systemImage: "flag.checkered").padding(.horizontal, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 860, height: 600)
        .onAppear { hall = HallOfFame.load() }
    }
}
