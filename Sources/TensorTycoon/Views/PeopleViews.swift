import SwiftUI

// 3.4: the people of AI on screen — a lab's people in its profile, your notable people on the Team screen, the industry's
// buzz on the Rivals overview, and the pieces the Pulse screen shares (avatars, post rows, buzz bars).

// MARK: - Style

enum PulseStyle {
    static func kindColor(_ k: PulseKind) -> Color {
        switch k {
        case .hype: .orange
        case .skeptic: .gray
        case .joke: .pink
        case .bench: .blue
        case .rumor: .purple
        case .reaction: .indigo
        case .money: .green
        case .policy: .brown
        case .safety: .red
        case .people: .teal
        case .ambient: .secondary
        }
    }

    static func castColor(_ k: CastKind) -> Color {
        switch k {
        case .leader: .orange
        case .scientist: .purple
        case .researcher: .blue
        case .analyst: .teal
        case .investor: .green
        case .journalist: .indigo
        case .official: .brown
        case .critic: .red
        case .academic: .mint
        case .free: .gray
        }
    }

    /// A lab's colour, or yours.
    static func orgColor(_ id: String, _ s: GameState) -> Color {
        id == "player" ? Theme.logoColor(s.logoColor) : Theme.competitorColor(CompetitorCatalog.def(id).color)
    }

    static func orgSymbol(_ id: String, _ s: GameState) -> String {
        id == "player" ? s.logoSymbol : CompetitorCatalog.def(id).symbol
    }

    /// Someone's colour: their lab's when they work at one, otherwise their line of work's.
    static func personColor(_ p: CastMember, _ s: GameState) -> Color {
        Cast.isLab(p.org) || p.org == "player" ? orgColor(p.org, s) : castColor(p.castKind)
    }

    static func toneColor(_ tone: Double) -> Color {
        tone >= 0.08 ? .green : (tone <= -0.08 ? .red : .orange)
    }

    /// "Chief executive · DeepGrove", "Senior analyst · Halvorsen Research", "Between jobs (formerly Prometheus)".
    static func roleLine(_ p: CastMember, _ s: GameState) -> String {
        if p.castKind == .free {
            let was = p.lastLab.isEmpty ? "" : " (formerly \(Cast.orgName(p.lastLab, s, short: true)))"
            return (p.active ? "Between jobs" : p.role) + was
        }
        let org = Cast.orgName(p.org, s)
        return org.isEmpty ? p.role : "\(p.role) · \(org)"
    }
}

// MARK: - Small pieces

/// A round avatar with initials, or an @ for anonymous accounts.
struct PersonAvatar: View {
    let initials: String
    let color: Color
    var anonymous = false
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle().fill(color.gradient)
            if anonymous {
                Image(systemName: "at").font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(.white)
            } else {
                Text(initials).font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
    }
}

/// One post on the Pulse.
struct PulsePostRow: View {
    let post: PulsePost
    let state: GameState
    var compact = false
    var showLabs = true

    var body: some View {
        let s = state
        let person = post.author.isEmpty ? nil : Cast.person(s, id: post.author)
        let kind = PulseKind(rawValue: post.kind) ?? .reaction
        HStack(alignment: .top, spacing: 10) {
            PersonAvatar(initials: person?.initials ?? "", color: person.map { PulseStyle.personColor($0, s) } ?? .gray,
                         anonymous: person == nil, size: compact ? 26 : 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(post.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(post.handle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if let person, !compact {
                        Text("· " + PulseStyle.roleLine(person, s)).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(post.date.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Text(post.text)
                    .font(compact ? .caption : .callout)
                    .fixedSize(horizontal: false, vertical: true)
                if !compact {
                    HStack(spacing: 12) {
                        Label(Fmt.count(Double(post.likes)), systemImage: "heart")
                        Label(Fmt.count(Double(post.reposts)), systemImage: "arrow.2.squarepath")
                        Pill(text: kind.title, color: PulseStyle.kindColor(kind))
                        if showLabs {
                            ForEach(post.labs, id: \.self) { id in
                                Pill(text: Cast.orgName(id, s, short: true), color: PulseStyle.orgColor(id, s))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(compact ? 6 : 10)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// Twelve weeks of attention as small bars.
struct BuzzSparkline: View {
    let values: [Double]
    var tint: Color = .accentColor
    var height: CGFloat = 26

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<values.count, id: \.self) { k in
                Capsule()
                    .fill(tint.opacity(k == values.count - 1 ? 1 : 0.55))
                    .frame(width: 5, height: max(2, height * min(1, values[k] / 100)))
            }
        }
        .frame(height: height, alignment: .bottom)
        .help("Attention over the last \(values.count) weeks")
    }
}

/// Attention (0–100) as a bar, with the tone beside it.
struct BuzzMeterRow: View {
    let buzz: LabBuzz

    var body: some View {
        HStack(spacing: 8) {
            Meter(value: buzz.attention / 100, tint: PulseStyle.toneColor(buzz.tone), height: 7)
            Text("\(Int(buzz.attention.rounded()))").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 26, alignment: .trailing)
            Pill(text: buzz.label, color: PulseStyle.toneColor(buzz.tone))
        }
        .help("Attention \(Int(buzz.attention.rounded())) of 100 from \(buzz.posts) posts in the last \(Pulse.window) days; tone \(Fmt.trim(buzz.tone, 2)) (−1 hostile … +1 glowing).")
    }
}

/// Where someone stands: open weights, worry about risk, appetite for rules.
struct StanceBars: View {
    let person: CastMember

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            bar("Closed", "Open weights", (person.open + 1) / 2, .teal)
            bar("Relaxed", "Worried about risk", person.safety, .red)
            bar("Fewer rules", "More rules", (person.regulation + 1) / 2, .purple)
        }
    }

    private func bar(_ low: String, _ high: String, _ v: Double, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(low).font(.caption2).foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary).frame(height: 5)
                Circle().fill(tint).frame(width: 9, height: 9).offset(x: 110 * clamp(v, 0, 1) - 4)
            }
            .frame(width: 110, height: 9, alignment: .leading)
            Text(high).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// A person, with their dated career one click away.
struct PersonRow: View {
    let person: CastMember
    let state: GameState
    var showOrg = false
    @State private var expanded = false

    var body: some View {
        let p = person
        let s = state
        VStack(alignment: .leading, spacing: 6) {
            Button {
                expanded.toggle()
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    PersonAvatar(initials: p.initials, color: PulseStyle.personColor(p, s), size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(p.name).font(.callout.weight(.semibold))
                            Text(p.handle).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(showOrg ? PulseStyle.roleLine(p, s) : "\(p.role) since \(p.since.gameMonth)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        HStack(spacing: 4) {
                            ForEach(p.castTraits, id: \.self) { t in Pill(text: t.title, color: .secondary) }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help(p.blurb.isEmpty ? "Show career" : p.blurb)
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !p.blurb.isEmpty { Text(p.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                    StanceBars(person: p)
                    CareerTimeline(entries: p.history)
                }
                .padding(.leading, 42)
            }
        }
    }
}

/// Dated career lines, newest first.
struct CareerTimeline: View {
    let entries: [CastEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(0..<entries.count, id: \.self) { k in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entries[k].date.gameMonth).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                    Text(entries[k].text).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - A lab's people (lab profile)

/// A lab's people (3.4), for its profile: who runs it and does its science, where its alumni went, how loudly and kindly
/// the industry has talked about it lately, and the latest posts about it.
struct LabPeopleSection: View {
    @Environment(GameStore.self) private var store
    let labID: String

    var body: some View {
        let s = store.game
        let staff = Cast.staff(s, labID)
        let alumni = Array(Cast.alumni(s, of: labID).prefix(6))
        let posts = Array(s.pulse.lazy.filter { $0.labs.contains(labID) }.prefix(4))
        HStack(alignment: .top, spacing: 16) {
            Card {
                CardHeader("People", symbol: "person.2.fill",
                           subtitle: staff.isEmpty ? "Nobody the press knows by name" : "\(staff.count) known by name · click someone for their career")
                if staff.isEmpty {
                    Text(s.cast.isEmpty ? "The cast arrives with the next month." : "Its people have moved on, or the press hasn't learned their names yet.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(staff) { p in PersonRow(person: p, state: s) }
                if !alumni.isEmpty {
                    Divider()
                    Text("Alumni").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(alumni) { p in PersonRow(person: p, state: s, showOrg: true) }
                }
            }
            Card {
                CardHeader("Buzz", symbol: "waveform", subtitle: "What the industry has said about it in the last \(Pulse.window) days")
                if let b = s.buzz[labID] {
                    BuzzMeterRow(buzz: b)
                    if b.trend.count > 1 { BuzzSparkline(values: b.trend, tint: PulseStyle.toneColor(b.tone)) }
                }
                if posts.isEmpty {
                    Text("Nobody's talking about it right now.").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(posts) { p in PulsePostRow(post: p, state: s, compact: true) }
                Button("All posts on the Pulse") { store.open(.pulse) }.buttonStyle(.link)
            }
            .frame(width: 440)
        }
    }
}

// MARK: - Your people (Team screen)

/// Your people the industry knows by name (3.4) — promoted stars, the ones who stayed after an acquisition — and the
/// ones who left, with where they went.
struct NotablePeopleCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let mine = s.cast.filter { $0.active && $0.org == "player" }.sorted { $0.stature > $1.stature }
        let gone = s.cast.filter { p in p.org != "player" && (p.lastLab == "player" || p.history.contains { $0.org == "player" }) }
            .sorted { $0.since > $1.since }
        Card {
            CardHeader("Notable people", symbol: "star.circle.fill",
                       subtitle: "Your people the press knows by name, and where the ones who left ended up")
            if mine.isEmpty && gone.isEmpty {
                Text("Nobody here is known outside the company yet. Stars who get a big title, get poached or leave to found a lab make the news — and the Pulse.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if !mine.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], alignment: .leading, spacing: 10) {
                    ForEach(mine.prefix(12)) { p in PersonRow(person: p, state: s) }
                }
            }
            if !gone.isEmpty {
                Divider()
                Text("Alumni").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], alignment: .leading, spacing: 10) {
                    ForEach(gone.prefix(12)) { p in PersonRow(person: p, state: s, showOrg: true) }
                }
            }
        }
    }
}

// MARK: - Industry buzz (Rivals overview)

/// Who the industry is talking about (3.4): each lab's attention and tone over the last two months of the Pulse, with
/// the line people are passing around. Click a lab for its profile.
struct IndustryBuzzCard: View {
    @Environment(GameStore.self) private var store
    let open: (String) -> Void

    var body: some View {
        let s = store.game
        let alive = Set(s.competitors.filter(\.alive).map(\.id)).union(["player"])
        let rows = s.buzz.filter { alive.contains($0.key) && $0.value.attention >= 1 }.sorted { $0.value.attention > $1.value.attention }.prefix(8)
        Card {
            CardHeader(title: "Industry buzz", symbol: "waveform",
                       subtitle: "Who's being talked about, and how kindly — the last \(Pulse.window) days of the Pulse") {
                Button("The Pulse") { store.open(.pulse) }.buttonStyle(.link)
            }
            if rows.isEmpty {
                Text("The industry hasn't found anything to talk about yet.").font(.callout).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(Array(rows), id: \.key) { entry in
                    BuzzTile(id: entry.key, buzz: entry.value, state: s) {
                        if entry.key != "player" { open(entry.key) } else { store.open(.pulse) }
                    }
                }
            }
        }
    }
}

/// One lab on the buzz board: name, attention, tone, trend and the most-liked recent post about it.
struct BuzzTile: View {
    let id: String
    let buzz: LabBuzz
    let state: GameState
    let action: () -> Void

    var body: some View {
        let s = state
        let top = s.pulse.lazy.filter { $0.labs.contains(id) && Cast.days($0.date, s.date) <= Pulse.window }
            .max { $0.likes < $1.likes }
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    CompanyLogo(symbol: PulseStyle.orgSymbol(id, s), color: PulseStyle.orgColor(id, s), size: 22)
                    Text(id == "player" ? "\(s.companyName) (you)" : Cast.orgName(id, s)).font(.callout.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    if buzz.trend.count > 1 { BuzzSparkline(values: buzz.trend, tint: PulseStyle.toneColor(buzz.tone), height: 18) }
                }
                BuzzMeterRow(buzz: buzz)
                if let top {
                    Text("“\(top.text)” — \(top.name)").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
