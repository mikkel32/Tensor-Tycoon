import SwiftUI

/// The Pulse (3.4): what the industry is saying. A feed of posts from the people of AI and the anonymous accounts
/// everyone reads, a directory of those people with their stances and dated careers, and a buzz board — who is being
/// talked about, and how kindly.
struct PulseView: View {
    @State private var tab: PulseTab = .feed

    var body: some View {
        Page(title: "The Pulse", subtitle: tab.subtitle, screen: .pulse) {
            SectionTabs(selection: $tab, options: PulseTab.allCases)
            switch tab {
            case .feed: PulseFeedTab()
            case .people: PeopleDirectoryTab()
            case .buzz: BuzzBoardTab()
            }
        }
    }
}

enum PulseTab: String, CaseIterable, Identifiable {
    case feed = "Feed"
    case people = "People"
    case buzz = "Buzz"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .feed: "The industry talking to itself: lab chiefs, researchers, analysts, reporters, officials, critics and the anonymous accounts everyone reads. Posts follow the news — launches, rounds, deals, votes, leaks — and the rumour mill."
        case .people: "Who's who in AI: where they work, what they believe, and every job they've held. Careers move with the game — raids, spin-outs, takeovers, promotions and people who leave to sound the alarm."
        case .buzz: "How loudly and how kindly each lab has been talked about over the last two months. Louder isn't always better."
        }
    }
}

// MARK: - Feed

private struct PulseFeedTab: View {
    @Environment(GameStore.self) private var store
    @State private var kind: PulseKind? = nil
    @State private var lab: String? = nil
    @State private var knownOnly = false
    @State private var search = ""

    var body: some View {
        let s = store.game
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let posts = s.pulse.filter { p in
            (kind.map { p.kind == $0.rawValue } ?? true) && (lab.map { p.labs.contains($0) } ?? true) && (!knownOnly || !p.author.isEmpty)
                && (q.isEmpty || p.text.lowercased().contains(q) || p.name.lowercased().contains(q) || p.handle.lowercased().contains(q))
        }
        let labs = mentioned(s)
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Picker("Kind", selection: $kind) {
                        Text("Everything").tag(PulseKind?.none)
                        ForEach(PulseKind.allCases, id: \.self) { k in Text(k.title).tag(PulseKind?.some(k)) }
                    }
                    .frame(width: 190)
                    Picker("About", selection: $lab) {
                        Text("Any lab").tag(String?.none)
                        ForEach(labs, id: \.self) { id in Text(id == "player" ? s.companyName : Cast.orgName(id, s)).tag(String?.some(id)) }
                    }
                    .frame(width: 220)
                    Toggle("Known names only", isOn: $knownOnly)
                    TextField("Search", text: $search)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                    Spacer(minLength: 0)
                }
                if posts.isEmpty {
                    Card {
                        EmptyStateView(symbol: "bubble.left.and.bubble.right", title: s.pulse.isEmpty ? "Quiet so far" : "Nothing matches",
                                       message: s.pulse.isEmpty ? "The industry starts talking as soon as something happens." : "Try another filter.")
                    }
                }
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(posts) { p in PulsePostRow(post: p, state: s) }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                BuzzSummaryCard(select: { lab = $0 })
                MostSharedCard()
            }
            .frame(width: 340)
        }
    }

    /// Labs the feed talks about, loudest first.
    private func mentioned(_ s: GameState) -> [String] {
        var seen = Set<String>()
        for p in s.pulse { seen.formUnion(p.labs) }
        return seen.sorted { (s.buzz[$0]?.attention ?? 0) > (s.buzz[$1]?.attention ?? 0) }
    }
}

/// The five loudest labs; clicking one filters the feed.
private struct BuzzSummaryCard: View {
    @Environment(GameStore.self) private var store
    let select: (String) -> Void

    var body: some View {
        let s = store.game
        let rows = s.buzz.filter { $0.value.attention >= 1 }.sorted { $0.value.attention > $1.value.attention }.prefix(5)
        Card {
            CardHeader("Loudest right now", symbol: "speaker.wave.3.fill", subtitle: "Attention over the last \(Pulse.window) days")
            if rows.isEmpty { Text("Nobody yet.").font(.callout).foregroundStyle(.secondary) }
            ForEach(Array(rows), id: \.key) { entry in
                Button {
                    select(entry.key)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            CompanyLogo(symbol: PulseStyle.orgSymbol(entry.key, s), color: PulseStyle.orgColor(entry.key, s), size: 18)
                            Text(entry.key == "player" ? s.companyName : Cast.orgName(entry.key, s)).font(.callout).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        BuzzMeterRow(buzz: entry.value)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Show only posts about it")
            }
        }
    }
}

/// The posts people passed around most this month.
private struct MostSharedCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let recent = s.pulse.filter { Cast.days($0.date, s.date) <= 30 }.sorted { $0.reposts > $1.reposts }.prefix(3)
        Card {
            CardHeader("Most shared this month", symbol: "arrow.2.squarepath")
            if recent.isEmpty { Text("Nothing has caught on this month.").font(.callout).foregroundStyle(.secondary) }
            ForEach(Array(recent)) { p in PulsePostRow(post: p, state: s, compact: true) }
        }
    }
}

// MARK: - People

private enum PeopleGroup: String, CaseIterable, Identifiable {
    case labs = "Labs"
    case money = "Analysts & investors"
    case press = "Press"
    case policy = "Policy"
    case critics = "Critics & academics"
    case yours = "Yours"
    case between = "Between jobs"

    var id: String { rawValue }

    func contains(_ p: CastMember) -> Bool {
        switch self {
        case .labs: p.castKind.atLab && p.org != "player"
        case .money: p.castKind == .analyst || p.castKind == .investor
        case .press: p.castKind == .journalist
        case .policy: p.castKind == .official
        case .critics: p.castKind == .critic || p.castKind == .academic
        case .yours: p.org == "player"
        case .between: p.castKind == .free
        }
    }
}

private struct PeopleDirectoryTab: View {
    @Environment(GameStore.self) private var store
    @State private var group: PeopleGroup = .labs
    @State private var search = ""

    var body: some View {
        let s = store.game
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let people = s.cast.filter { p in
            group.contains(p) && (q.isEmpty || p.name.lowercased().contains(q) || p.role.lowercased().contains(q)
                                  || Cast.orgName(p.org, s).lowercased().contains(q))
        }
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Picker("Group", selection: $group) {
                    ForEach(PeopleGroup.allCases) { g in Text("\(g.rawValue) (\(s.cast.filter { g.contains($0) }.count))").tag(g) }
                }
                .frame(width: 280)
                TextField("Search names, roles, organisations", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                Spacer(minLength: 0)
            }
            if people.isEmpty {
                Card { EmptyStateView(symbol: "person.2", title: "Nobody here", message: q.isEmpty ? "Nobody in this group yet." : "No one matches \"\(search)\".") }
            }
            if group == .labs {
                // One card per organisation, the biggest names first.
                let orgs = Dictionary(grouping: people, by: \.org).sorted { a, b in
                    (a.value.map(\.stature).max() ?? 0) > (b.value.map(\.stature).max() ?? 0)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 420), spacing: 16)], alignment: .leading, spacing: 16) {
                    ForEach(orgs, id: \.key) { entry in
                        Card {
                            HStack(spacing: 8) {
                                CompanyLogo(symbol: PulseStyle.orgSymbol(entry.key, s), color: PulseStyle.orgColor(entry.key, s), size: 24)
                                Text(Cast.orgName(entry.key, s)).font(.headline)
                                Spacer(minLength: 0)
                                if let b = s.buzz[entry.key] { Pill(text: b.label, color: PulseStyle.toneColor(b.tone)) }
                            }
                            ForEach(entry.value.sorted { Cast.rank($0.castKind) < Cast.rank($1.castKind) }) { p in PersonRow(person: p, state: s) }
                        }
                    }
                }
            } else {
                Card {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 16)], alignment: .leading, spacing: 12) {
                        ForEach(people.sorted { $0.stature > $1.stature }) { p in PersonRow(person: p, state: s, showOrg: true) }
                    }
                }
            }
        }
    }
}

// MARK: - Buzz

private struct BuzzBoardTab: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let alive = Set(s.competitors.filter(\.alive).map(\.id)).union(["player"])
        let rows = s.buzz.filter { alive.contains($0.key) }.sorted { $0.value.attention > $1.value.attention }
        VStack(alignment: .leading, spacing: 14) {
            Text("Attention counts posts about a lab over the last \(Pulse.window) days — newer and more-liked posts count more. Tone is how kind they were, from hostile to glowing.")
                .font(.callout).foregroundStyle(.secondary)
            if rows.isEmpty {
                Card { EmptyStateView(symbol: "waveform", title: "No buzz yet", message: "Buzz is worked out once a week from the Pulse.") }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], alignment: .leading, spacing: 14) {
                ForEach(rows, id: \.key) { entry in
                    BuzzTile(id: entry.key, buzz: entry.value, state: s) {
                        if entry.key != "player" { store.openLab(entry.key) }
                    }
                }
            }
        }
    }
}

// MARK: - Dashboard card

/// The dashboard's window on the Pulse (3.4): the posts worth reading from the last two weeks — known names first — and
/// who the industry is talking about. Self-contained: drop `PulseCard()` into any page.
struct PulseCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let recent = s.pulse.prefix(40).filter { Cast.days($0.date, s.date) <= 14 }
        let picks = recent.sorted { score($0) > score($1) }.prefix(3).sorted { $0.date > $1.date }
        let loud = s.buzz.filter { $0.value.attention >= 5 }.sorted { $0.value.attention > $1.value.attention }.prefix(3)
        Card {
            CardHeader(title: "The Pulse", symbol: "bubble.left.and.bubble.right.fill", subtitle: "What the industry is saying") {
                Button("Open") { store.open(.pulse) }.buttonStyle(.link)
            }
            if picks.isEmpty {
                Text(s.pulse.isEmpty ? "Quiet so far. The industry will have opinions soon." : "A quiet fortnight. Older posts are on the Pulse.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(picks)) { p in PulsePostRow(post: p, state: s, compact: true) }
            if !loud.isEmpty {
                HStack(spacing: 6) {
                    Text("Loudest:").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(loud), id: \.key) { entry in
                        Pill(text: "\(entry.key == "player" ? "You" : Cast.orgName(entry.key, s, short: true)) · \(entry.value.label.lowercased())",
                             color: PulseStyle.toneColor(entry.value.tone))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Known names and well-liked posts first; posts about you a little ahead.
    private func score(_ p: PulsePost) -> Double {
        (p.author.isEmpty ? 0 : 1.2) + log10(1 + Double(p.likes)) * 0.5 + (p.labs.contains("player") ? 0.6 : 0)
    }
}
