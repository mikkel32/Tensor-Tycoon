import SwiftUI

// MARK: - 3.9: Challenges & Open Source — prize competitions and the community around what you give away

enum ChallengesTab: String, CaseIterable, Identifiable {
    case challenges = "Grand Challenges"
    case open = "Open Source"

    var id: String { rawValue }
}

struct ChallengesView: View {
    @Environment(GameStore.self) private var store
    @State private var tab: ChallengesTab = .challenges

    var body: some View {
        let s = store.game
        Page(title: "Challenges & Open Source",
             subtitle: "Prize competitions decided by what your models can really do, and the developer community that grows around the weights, tools and data you publish.",
             screen: .challenges) {
            SectionTabs(selection: $tab, options: ChallengesTab.allCases)
            switch tab {
            case .challenges: GrandChallengesSection(state: s)
            case .open: OpenSourceSection(state: s)
            }
        }
    }
}

// MARK: - Grand challenges

struct GrandChallengesSection: View {
    let state: GameState

    var body: some View {
        let c = state.challenges
        let live = GrandChallenges.live(state)
        let claimed = ChallengeCatalog.all.filter { $0.grandPrize > 0 && c.claimed[$0.id] != nil }.count
        let withGrand = ChallengeCatalog.all.filter { $0.grandPrize > 0 }.count
        KPIRow {
            StatTile(title: "Prize money", value: Fmt.money(c.prizeMoney), detail: "Purses, milestone awards and grand prizes", symbol: "dollarsign.circle.fill", tint: .green)
            StatTile(title: "Wins", value: "\(c.wins)", detail: "\(c.podiums) podium\(c.podiums == 1 ? "" : "s") in all", symbol: "trophy.fill", tint: .yellow)
            StatTile(title: "Grand prizes", value: "\(c.grandPrizes)", detail: "\(claimed) of \(withGrand) claimed worldwide", symbol: "medal.star.fill", tint: .orange)
            if let next = live.first {
                StatTile(title: "Next results", value: next.results.gameShort, detail: GrandChallenges.label(next), symbol: "calendar.badge.clock", tint: .indigo)
            } else if let up = GrandChallenges.upcoming(state, count: 1).first {
                StatTile(title: "Next announcement", value: up.1.gameShort, detail: up.0.short, symbol: "calendar", tint: .indigo)
            }
        }
        if live.isEmpty {
            Card {
                EmptyStateView(symbol: "rosette", title: "No grand challenge is open right now",
                               message: GrandChallenges.upcoming(state, count: 1).first.map { "\($0.0.name) is announced \($0.1.gameShort). Invitations arrive in your inbox; you can also enter here." }
                                   ?? "Every challenge has run its course.", compact: true)
            }
        }
        ForEach(live) { e in ChallengeEditionCard(state: state, edition: e) }
        CardGrid(minWidth: 360, maxColumns: 2) {
            UpcomingChallengesCard(state: state)
            ChallengeHistoryCard(state: state)
        }
        ChallengeCatalogueCard(state: state)
    }
}

struct ChallengeEditionCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let edition: ChallengeEdition

    var body: some View {
        let e = edition
        if let d = e.def {
            let effort: ChallengeEffort = e.effort == .none ? .standard : e.effort
            let mine = GrandChallenges.expected(d, state, effort: effort, pushed: e.pushed)
            let entry = GrandChallenges.entryModel(d, state)
            let field = GrandChallenges.field(d, state, at: e.results)
            let blockers = GrandChallenges.blockers(d, state)
            let bar = GrandChallenges.barFor(e)
            Card {
                CardHeader(title: GrandChallenges.label(e), symbol: d.symbol, subtitle: "Run by \(d.organiser)") { statusPill(e) }
                HStack(alignment: .top, spacing: Theme.gap) {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text(d.task).font(.callout).fixedSize(horizontal: false, vertical: true)
                        Text(GrandChallenges.stakesLine(d, state)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text("Win it: \(d.reward)").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    IllustrativeBanner(key: d.photo, height: 110).frame(width: 220)
                }
                StageStrip(steps: steps(e), tint: .orange)
                KPIRow(minWidth: 140) {
                    MetricTile(label: e.status == .entered ? "Your entry (expected)" : "You'd score", value: mine.map { d.metricText($0, bar: bar) } ?? "—", symbol: "person.fill")
                    MetricTile(label: state.challenges.claimed[d.id] == nil ? "Grand prize bar" : "This year's bar", value: d.metricText(bar, bar: bar), symbol: "flag.checkered")
                    MetricTile(label: e.status == .open ? "Entries close" : "Results", value: (e.status == .open ? e.entryCloses : e.results).gameShort, symbol: "calendar")
                    MetricTile(label: e.status == .entered ? "Spent" : "Standard entry", value: Fmt.money(e.status == .entered ? e.spent : GrandChallenges.cost(d, .standard)), symbol: "banknote")
                }
                if let entry {
                    Label(entry.exhibition ? "Prize money needs open weights: \(entry.name) would go in as an exhibition. Open a strong model's weights before results day to compete for the money."
                                           : "Your entry: \(entry.name)\(d.openTrack ? " (open weights, on the prize track)" : "").",
                          systemImage: entry.exhibition ? "lock.fill" : "cube.box.fill")
                        .font(.caption).foregroundStyle(entry.exhibition ? Theme.warning : .secondary)
                }
                fieldList(d, field: field, mine: mine, model: entry?.name ?? "", bar: bar)
                if e.status == .open || e.status == .entered, blockers.isEmpty,
                   let o = GrandChallenges.odds(d, state, effort: effort, pushed: e.pushed, key: e.id) {
                    HStack(spacing: Theme.gap) {
                        OddsBar(probability: o.win, label: "Win\(e.status == .open ? " (standard entry)" : "")")
                        OddsBar(probability: o.podium, label: "Podium")
                        if d.grandPrize > 0 && state.challenges.claimed[d.id] == nil { OddsBar(probability: o.grand, label: "Grand prize") }
                    }
                }
                ForEach(blockers, id: \.self) { b in Label(b, systemImage: "xmark.octagon.fill").font(.caption).foregroundStyle(Theme.bad) }
                actions(d, e, blocked: !blockers.isEmpty)
                Text(d.basis).font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusPill(_ e: ChallengeEdition) -> some View {
        switch e.status {
        case .open: Pill("Entries open", tone: .accent)
        case .entered: Pill(e.effort == .allIn ? "Entered · all-in" : "Entered", tone: .good)
        case .watching: Pill("Not entered", tone: .neutral)
        case .done: Pill("Decided", tone: .info)
        }
    }

    private func steps(_ e: ChallengeEdition) -> [StageStep] {
        let total = Double(max(1, GameCalendar.daysBetween(e.checkpoint, e.results)))
        let toResults = clamp(Double(GameCalendar.daysBetween(e.checkpoint, state.date)) / total, 0, 1)
        let lead = Double(max(1, GameCalendar.daysBetween(e.announced, e.checkpoint)))
        let toCheck = clamp(Double(GameCalendar.daysBetween(e.announced, state.date)) / lead, 0, 1)
        return [
            StageStep(id: "a", title: "Announced", status: .done, note: e.announced.gameShort),
            StageStep(id: "e", title: e.status == .watching ? "Passed" : "Entries", status: e.status == .open ? .current : (e.status == .watching ? .blocked : .done),
                      note: e.status == .open ? "until \(e.entryCloses.gameShort)" : nil),
            StageStep(id: "c", title: e.checkpointPlace > 0 ? "Leaderboard: \(Contests.ordinal(e.checkpointPlace))" : "Public leaderboard",
                      status: e.checkpointDone ? .done : (e.status == .open ? .upcoming : .current), progress: toCheck, note: e.checkpoint.gameShort),
            StageStep(id: "r", title: "Results", status: e.checkpointDone ? .current : .upcoming, progress: toResults, note: e.results.gameShort),
        ]
    }

    private func fieldList(_ d: ChallengeDef, field: [ChallengeStanding], mine: Double?, model: String, bar: Double) -> some View {
        var rows = Array(field.prefix(5))
        if let mine { rows.append(ChallengeStanding(lab: "player", team: state.companyName, model: model, score: mine)) }
        rows.sort { $0.score > $1.score }
        let hi = max(bar, rows.map(\.score).max() ?? bar) + 5
        let lo = min(rows.map(\.score).min() ?? 0, bar) - 10
        return VStack(alignment: .leading, spacing: 4) {
            Text("The field today (expected, before luck)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 8) {
                    Text(r.team).font(.caption.weight(r.lab == "player" ? .bold : .regular)).lineLimit(1).frame(width: 170, alignment: .leading)
                    Text(r.model.isEmpty ? (r.lab.hasPrefix("outside:") ? "outside team" : "") : r.model).font(.caption2).foregroundStyle(.secondary).lineLimit(1).frame(width: 110, alignment: .leading)
                    Meter(value: (r.score - lo) / max(1, hi - lo), tint: r.lab == "player" ? .orange : (r.score >= bar ? .green : .gray), height: 6)
                    Text(d.metricText(r.score, bar: bar)).font(.caption.monospacedDigit()).frame(width: 150, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private func actions(_ d: ChallengeDef, _ e: ChallengeEdition, blocked: Bool) -> some View {
        if e.status == .open && !blocked {
            HStack {
                Button("Enter · \(Fmt.money(GrandChallenges.cost(d, .standard)))") { store.act("Entered \(GrandChallenges.label(e))") { $0.enterChallenge(e.id, allIn: false) } }
                    .buttonStyle(.borderedProminent)
                Button("Go all-in · \(Fmt.money(GrandChallenges.cost(d, .allIn)))") { store.act("All in on \(GrandChallenges.label(e))") { $0.enterChallenge(e.id, allIn: true) } }
                Button("Pass") { store.act { $0.passChallenge(e.id) } }
                Spacer()
                if let o = GrandChallenges.odds(d, state, effort: .allIn, key: e.id) {
                    Text("All-in: \(Fmt.odds(o.win)) to win").font(.caption).foregroundStyle(.secondary)
                }
            }
        } else if e.status == .entered && e.checkpointDone && !e.pushed {
            HStack {
                Button("Push harder · \(Fmt.money(GrandChallenges.pushCost(d)))") { store.act("Late push on \(GrandChallenges.label(e))") { $0.pushChallenge(e.id) } }
                Text("+\(Fmt.trim(GrandChallenges.pushBonus, 1)) points before results day").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct UpcomingChallengesCard: View {
    let state: GameState

    var body: some View {
        Card {
            CardHeader("Coming up", symbol: "calendar", subtitle: "Announcements: the invitation lands in your inbox")
            let up = GrandChallenges.upcoming(state, count: 8)
            if up.isEmpty { Text("Nothing scheduled.").font(.caption).foregroundStyle(.secondary) }
            ForEach(up, id: \.0.id) { d, when in
                HStack(spacing: 10) {
                    Image(systemName: d.symbol).foregroundStyle(.white).frame(width: 28, height: 28).background(Color.orange.gradient, in: .rect(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.name).font(.callout.weight(.semibold)).lineLimit(1)
                        Text(GrandChallenges.stakesLine(d, state)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(when.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ChallengeHistoryCard: View {
    let state: GameState

    var body: some View {
        let done = state.challenges.editions.filter { $0.status == .done }.reversed()
        Card {
            CardHeader("Results", symbol: "list.number", subtitle: "Every edition decided while you've been running the lab")
            if done.isEmpty { Text("No results yet.").font(.caption).foregroundStyle(.secondary) }
            ForEach(Array(done.prefix(10))) { e in
                if let d = e.def {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(GrandChallenges.label(e)).font(.callout.weight(.semibold))
                            if e.place > 0 { Pill(e.place == 1 ? "You won" : "You: \(Contests.ordinal(e.place))", tone: e.place <= 3 ? .good : .neutral) }
                            if !e.grandBy.isEmpty { Pill(text: "Grand prize: \(GrandChallenges.teamName(e.grandBy, state))", color: .orange, symbol: "medal.star.fill") }
                            Spacer()
                            if e.prize > 0 { Text("+\(Fmt.money(e.prize))").font(.caption.monospacedDigit()).foregroundStyle(Theme.good) }
                        }
                        Text(e.standings.prefix(3).enumerated().map { "\($0.offset + 1). \($0.element.team) \(d.metricText($0.element.score, bar: GrandChallenges.barFor(e)))" }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        }
    }
}

struct ChallengeCatalogueCard: View {
    let state: GameState

    var body: some View {
        Card {
            CardHeader("The challenges", symbol: "books.vertical.fill", subtitle: "What each one tests, and where it stands")
            ForEach(ChallengeCatalog.all) { d in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: d.symbol).frame(width: 22).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(d.name).font(.callout.weight(.semibold))
                            Text(d.mix.map { "\($0.0.short) \(Int(($0.1 * 100).rounded()))%" }.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(status(d)).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("\(d.grandGoal). \(d.basis)").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if !d.knowhow.isEmpty {
                            Text("Helps: " + d.knowhow.map { "\(ResearchCatalog.byID[$0.0]?.name ?? $0.0) +\(Int($0.1))\(state.researched.contains($0.0) ? " ✓" : "")" }.joined(separator: ", ")
                                 + (d.labs.isEmpty ? "" : "; a \(d.labs.map(\.rawValue).joined(separator: " or ")) lab +3"))
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func status(_ d: ChallengeDef) -> String {
        if let who = state.challenges.claimed[d.id] { return "Grand prize: \(GrandChallenges.teamName(who, state))\(d.endsOnGrand ? " (closed)" : "")" }
        if let next = GrandChallenges.nextAnnouncement(d, after: state.date, state) { return "Next \(next.gameShort)" }
        return state.challenges.editions.contains { $0.challenge == d.id && $0.status != .done } ? "Running" : "Finished"
    }
}

// MARK: - Open source

struct OpenSourceSection: View {
    let state: GameState

    var body: some View {
        let c = state.challenges
        KPIRow {
            StatTile(title: "Stars", value: Fmt.count(c.stars), detail: "\(c.repos.count) project\(c.repos.count == 1 ? "" : "s")", symbol: "star.fill", tint: .yellow)
            StatTile(title: "Forks", value: Fmt.count(c.forks), detail: "Fine-tunes and derivatives", symbol: "arrow.triangle.branch", tint: .teal)
            StatTile(title: "Contributors", value: Fmt.int(Int(c.contributors)), detail: "\(c.contributorHires) asked to join you", symbol: "person.3.fill", tint: .blue)
            StatTile(title: "Goodwill", value: "\(Int(c.goodwill.rounded()))/100", detail: c.grants ? "Grants and bounties on" : "How the community sees you", symbol: "heart.fill", tint: .pink)
            StatTile(title: "Safety scrutiny", value: "\(Int(c.scrutiny.rounded()))/100", detail: c.incidents > 0 ? "\(c.incidents) incident\(c.incidents == 1 ? "" : "s")" : "Incidents start above 25",
                     symbol: "exclamationmark.shield.fill", tint: c.scrutiny > 50 ? .red : .orange)
        }
        HStack(alignment: .top, spacing: Theme.gap) {
            CommunityEffectsCard(state: state)
            CommunityLogCard(state: state).frame(width: 380)
        }
        ReposCard(state: state)
        CardGrid(minWidth: 380, maxColumns: 2) {
            OpenToolsCard(state: state)
            OpenWeightsCard(state: state)
        }
    }
}

struct CommunityEffectsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let lift = OpenSource.ecosystemLift(s)
        let monthGain = max(0.01, (Macro.frontier(s.year + 1) - Macro.frontier(s.year)) / 12)
        let rival = OpenSource.rivalC(s)
        Card {
            CardHeader("What the community does for you", symbol: "sparkles", subtitle: "Updated on the first of each month")
            row("Developer ecosystem", "+\(Fmt.trim(lift, 1)) points toward its target (now \(Int(s.marketMoves.devEcosystem.rounded()))/100: API demand +\(Fmt.trim((Launches.ecosystemFactor(s) - 1) * 100, 1))%)", "chevron.left.forwardslash.chevron.right", .green)
            row("Standing", "Researchers +\(Fmt.trim(OpenSource.standing(s, .researchers), 1)), developers +\(Fmt.trim(OpenSource.standing(s, .developers), 1)) on the World page; better candidates follow researchers", "person.2.fill", .blue)
            row("Recruiting", "\(s.challenges.contributorHires) top contributor\(s.challenges.contributorHires == 1 ? "" : "s") applied so far; more contributors, more applications", "person.badge.plus", .blue)
            row("Rivals catch up", rival > 0 ? "Your tools give every rival +\(Fmt.trim(rival, 3)) capability, about \(Fmt.trim(rival / monthGain, 1)) months of progress. Open weights let them build on up to 70% of any lead." : "Nothing of yours they build on yet. Open weights let rivals build on up to 70% of any lead.", "figure.run", .orange)
            row("Safety scrutiny", s.challenges.scrutiny > 25 ? "\(Int(s.challenges.scrutiny)): incidents are possible (stripped fine-tunes, regulators' letters). It fades about 7% a month; a safety classifier or eval harness calms it." : "\(Int(s.challenges.scrutiny)): quiet. Powerful open weights raise it fast.", "exclamationmark.shield.fill", s.challenges.scrutiny > 50 ? .red : .orange)
            row("Cost", "\(Fmt.money(OpenSource.monthlyCost(s)))/month for maintainers\(s.challenges.grants ? " and grants" : ""); \(Fmt.money(s.challenges.spent)) so far", "banknote", .secondary)
            Toggle(isOn: Binding(get: { s.challenges.grants }, set: { on in store.act { $0.setCommunityGrants(on) } })) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Contributor grants and bug bounties").font(.callout.weight(.semibold))
                    Text("\(Fmt.money(OpenSource.grantsMonth(s)))/month · 40% more contributors, goodwill +6, stars grow faster").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func row(_ title: String, _ text: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CommunityLogCard: View {
    let state: GameState

    var body: some View {
        Card {
            CardHeader("Community log", symbol: "text.bubble.fill")
            if state.challenges.log.isEmpty { Text("Nothing yet. Publish something.").font(.caption).foregroundStyle(.secondary) }
            ForEach(Array(state.challenges.log.prefix(12).enumerated()), id: \.offset) { _, l in
                Text(l).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ReposCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let repos = state.challenges.repos.sorted { $0.stars > $1.stars }
        Card {
            CardHeader("Your projects", symbol: "shippingbox.fill", subtitle: "Stars grow toward each project's potential; unmaintained ones stall and lose contributors")
            if repos.isEmpty {
                EmptyStateView(symbol: "lock.open.fill", title: "Nothing open-sourced yet", message: "Publish a tool below, or open a model's weights. Everything you give away gathers its own community.", compact: true)
            }
            ForEach(repos) { r in
                HStack(spacing: 10) {
                    Image(systemName: r.kind == .model ? "cube.box.fill" : (r.kind == .tool ? (OpenSource.tool(r)?.symbol ?? "hammer.fill") : "lock.shield.fill"))
                        .foregroundStyle(.white).frame(width: 26, height: 26).background((r.kind == .model ? Color.blue : (r.kind == .tool ? Color.teal : Color.purple)).gradient, in: .rect(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.name).font(.callout.weight(.semibold)).lineLimit(1)
                        Text("\(r.kind == .model ? "Open weights" : (r.kind == .tool ? (OpenSource.tool(r)?.what ?? "Tool") : "Challenge system")) · since \(r.released.gameShort)")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    stat("star.fill", Fmt.count(r.stars), "of ~\(Fmt.count(r.potential))")
                    stat("arrow.triangle.branch", Fmt.count(r.forks), "forks")
                    stat("person.3.fill", Fmt.int(Int(r.contributors)), "contributors")
                    if r.kind != .model {
                        Toggle("Maintained", isOn: Binding(get: { r.maintained }, set: { on in store.act { $0.setRepoMaintained(r.id, on) } }))
                            .toggleStyle(.switch).controlSize(.small)
                            .help("\(OpenSource.maintainers(OpenRepo(id: r.id, kind: r.kind, name: r.name, released: r.released, maintained: true))) maintainers · \(Fmt.money(Double(OpenSource.maintainers(OpenRepo(id: r.id, kind: r.kind, name: r.name, released: r.released, maintained: true))) * OpenSource.maintainerMonth(state)))/month")
                    }
                }
            }
        }
    }

    private func stat(_ symbol: String, _ value: String, _ label: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Label(value, systemImage: symbol).font(.caption.monospacedDigit().weight(.semibold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 92, alignment: .trailing)
    }
}

struct OpenToolsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        Card {
            CardHeader("Tools you could open-source", symbol: "hammer.fill", subtitle: "Libraries, data and protocols: each one needs maintainers")
            ForEach(ChallengeCatalog.tools) { t in
                let blocker = OpenSource.toolBlocker(t, state)
                let released = state.challenges.repos.contains { $0.id == "tool:\(t.id)" }
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: t.symbol).foregroundStyle(.teal).frame(width: 20)
                        Text(OpenSource.toolName(t, state)).font(.callout.weight(.semibold))
                        Text(t.what).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        if released {
                            Pill("Open source", tone: .good)
                        } else if let blocker {
                            Text(blocker).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        } else {
                            Button("Open-source it") { store.act("\(OpenSource.toolName(t, state)) is open source") { $0.openSourceTool(t.id) } }
                                .controlSize(.small)
                        }
                    }
                    Text("↑ \(t.upside)  ↓ \(t.downside)").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("Up to ~\(Fmt.count(t.stars * OpenSource.era(state.year))) stars today · ecosystem +\(Int(t.ecosystem)) · \(t.maintainers) maintainer\(t.maintainers == 1 ? "" : "s") (\(Fmt.money(Double(t.maintainers) * OpenSource.maintainerMonth(state)))/mo)"
                         + (t.rivalC > 0 ? " · rivals +\(Fmt.trim(t.rivalC, 2)) capability" : "") + (t.scrutiny != 0 ? " · scrutiny \(t.scrutiny > 0 ? "+" : "")\(Int(t.scrutiny))" : ""))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct OpenWeightsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let closed = state.models.filter { $0.released && !$0.retired && !$0.openWeights }.sorted { $0.c > $1.c }
        Card {
            CardHeader("Open a model's weights", symbol: "lock.open.fill", subtitle: "The biggest community lever, and the biggest trade-off")
            if closed.isEmpty { Text("No released closed-weights models.").font(.caption).foregroundStyle(.secondary) }
            ForEach(closed.prefix(5)) { m in
                let q = OpenSource.modelQuality(m, state)
                let tier = SafetyFramework.tier(m)
                let blocker = DataEconomy.openWeightsBlocker(state, model: m.id)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(m.name).font(.callout.weight(.semibold))
                        Text("index \(Fmt.score(m.index))").font(.caption).foregroundStyle(.secondary)
                        if tier >= .high { Pill(tier.label, tone: .bad) } else if tier == .earlyWarning { Pill(tier.label, tone: .warning) }
                        Spacer()
                        if let blocker {
                            Text(blocker).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        } else {
                            Button("Open the weights") { store.act("\(m.name) released with open weights") { $0.release(m.id, api: m.api, openWeights: true) } }
                                .controlSize(.small)
                        }
                    }
                    Text("~\(Fmt.count(90_000 * q * q * OpenSource.era(state.year) * 0.25)) stars on day one, heading for ~\(Fmt.count(90_000 * q * q * OpenSource.era(state.year))) · "
                         + (m.c >= Macro.frontier(state.year) - 0.5 ? "near the frontier: rivals build on it and developers flock" : "behind the frontier: a modest community")
                         + (tier >= .high ? " · above the High danger line: heavy safety scrutiny" : ""))
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if ChallengeCatalog.all.contains(where: { $0.openTrack && state.challenges.claimed[$0.id] == nil }) {
                Label("The Gauss Prize pays only for open-weights entries.", systemImage: "function").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
