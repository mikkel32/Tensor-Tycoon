import SwiftUI

// MARK: - 3.9: the Stars panel on the Team screen

/// Your stars as people: what drives them, how they're doing, what they want, who they work well with, the bidding war in
/// progress, the prizes and the ones who got away — and the rivals' stars you could go after.
struct StarsPanel: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let st = s.stars
        Card {
            CardHeader(title: "Stars", symbol: "star.fill",
                       subtitle: "Your best people: what drives them, who they work well with, and who's trying to hire them") {
                if st.wars + st.raidsWon + st.awards.filter(\.mine).count > 0 {
                    Text("Wars won \(st.warsWon) of \(st.wars) · raids \(st.raidsWon) · prizes \(st.awards.filter(\.mine).count)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if let o = st.offer, !o.outgoing { BiddingWarCard(offer: o, state: s) }
            if st.profiles.isEmpty {
                Text("No stars yet. Star candidates (gold border) come onto the market every few months, and a veteran with skill 82+ after two years can become one. Each star has a personality, a specialty and an ambition — and rival labs will try to hire them.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(st.profiles) { p in
                        if let e = s.employees.first(where: { $0.id.uuidString == p.id }) { StarCard(profile: p, employee: e, state: s) }
                    }
                }
            }
            if st.profiles.count >= 2 { ChemistryStrip(state: s) }
            PrizesStrip(state: s)
            if !st.alumni.isEmpty { AlumniStrip(state: s) }
            RivalStarsStrip(state: s)
        }
    }
}

private func starColor(_ p: StarPersonality) -> Color {
    switch p {
    case .idealist: .teal
    case .mercenary: .green
    case .builder: .orange
    case .showman: .pink
    case .scholar: .indigo
    case .maverick: .purple
    case .steady: .blue
    }
}

private func initials(_ name: String) -> String {
    name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
}

/// A rival's offer and your counter, lever by lever, with the odds as you build it.
private struct BiddingWarCard: View {
    @Environment(GameStore.self) private var store
    let offer: StarOffer
    let state: GameState
    @State private var levers: Set<StarLever> = [.salary]

    var body: some View {
        let s = state
        let o = offer
        let p = s.stars.profiles.first { $0.id == o.star }
        let e = s.employees.first { $0.id.uuidString == o.star }
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("\(Stars.labName(s, o.lab)) is trying to hire \(o.name)").font(.headline)
                Spacer()
                Pill(text: "Round \(o.round) of \(Stars.maxRounds)", color: .orange)
            }
            Text("Their offer: \(Stars.offerSummary(s, o)).").font(.callout)
            if let p { Text("\(p.personality.title): \(p.personality.blurb)").font(.caption).foregroundStyle(.secondary) }
            if let p, let e {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], alignment: .leading, spacing: 6) {
                    ForEach(StarLever.allCases.filter { Stars.fits(p, $0) && (!s.isPublicProgram || $0 != .equity) }) { l in
                        let held = (l == .title && !p.title.isEmpty) || (l == .compute && p.computeBudget > 0) || (l == .mandate && p.mandate)
                        Toggle(isOn: Binding(get: { levers.contains(l) && !held }, set: { on in if on { levers.insert(l) } else { levers.remove(l) } })) {
                            VStack(alignment: .leading, spacing: 0) {
                                Label(leverText(l, s, o, p, e), systemImage: l.symbol).font(.caption.weight(.semibold))
                                Text(held ? "Already has it" : weightText(p.personality.weight(l))).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .disabled(held)
                    }
                }
                let odds = Stars.stayOdds(s, levers) ?? 0
                HStack(spacing: 10) {
                    Text("Chance they stay").font(.caption)
                    Meter(value: odds, tint: odds >= 0.6 ? Theme.good : (odds >= 0.35 ? Theme.warning : Theme.bad), height: 8).frame(width: 160)
                    Text(Fmt.pct(odds, decimals: 0)).font(.callout.weight(.bold).monospacedDigit())
                    Spacer()
                    Button("Let them go gracefully") { store.act("You let \(Stars.firstName(o.name)) go") { $0.starLetGo() } }
                    Button(levers.isEmpty ? "Just talk to them" : "Send counter-offer") { store.act(nil) { $0.starCounter(levers) } }
                        .buttonStyle(.borderedProminent)
                }
                Text(s.isPublicProgram ? "If they turn you down, \(Stars.labName(s, o.lab)) may go higher for another round — or win. Public retention uses pay, titles and research resources, never equity." : "If they turn you down, \(Stars.labName(s, o.lab)) may go higher for another round — or win. Pay rises are permanent; stock, titles and clusters stay given.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.5), lineWidth: 1))
    }

    func leverText(_ l: StarLever, _ s: GameState, _ o: StarOffer, _ p: StarProfile, _ e: Employee) -> String {
        switch l {
        case .salary: "Match \(Fmt.money(o.salary))/yr (+\(Fmt.money(max(0, o.salary - e.salary))))"
        case .equity: "Stock worth \(Fmt.money(Stars.equityValue(s, o, e)))"
        case .title: "Title: \(Stars.titleFor(s, p))"
        case .compute: "\(Fmt.int(Stars.computeGPUs(s)))-GPU cluster (\(Fmt.money(Stars.computeBudget(s)))/mo)"
        case .mandate: "Their own research agenda"
        }
    }

    func weightText(_ w: Double) -> String { w >= 1.4 ? "Matters a lot to them" : (w >= 0.9 ? "Matters to them" : "Matters little to them") }
}

/// One star: who they are, how they're doing, what they want and what you've given them.
private struct StarCard: View {
    @Environment(GameStore.self) private var store
    let profile: StarProfile
    let employee: Employee
    let state: GameState
    @State private var storyOpen = false

    var body: some View {
        let p = profile
        let e = employee
        let s = state
        let met = Stars.wantMet(s, p, e)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                PersonAvatar(initials: initials(p.name), color: starColor(p.personality), size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(p.name).font(.headline)
                        if p.boomerang { Image(systemName: "arrow.uturn.backward.circle.fill").foregroundStyle(.teal).help("Came back after leaving") }
                        ForEach(p.awards, id: \.self) { a in Image(systemName: "rosette").foregroundStyle(.yellow).help(a.replacingOccurrences(of: "|", with: " ")) }
                    }
                    Text(p.title.isEmpty ? e.role.title : "\(p.title) · \(e.role.title)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Int(e.skill))").font(.title2.weight(.bold).monospacedDigit())
                    Text("skill").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 4) {
                Pill(text: p.personality.title, color: starColor(p.personality), symbol: p.personality.symbol).help(p.personality.blurb)
                Pill(text: p.specialty.title, color: .secondary, symbol: "scope")
                if let until = p.sabbaticalUntil { Pill(text: "Sabbatical to \(until.gameShort)", color: .teal, symbol: "beach.umbrella.fill") }
            }
            Text(p.origin).font(.caption).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    Text("Mood").font(.caption2).foregroundStyle(.secondary)
                    Meter(value: e.morale / 100, tint: e.morale < 40 ? Theme.bad : (e.morale < 65 ? Theme.warning : Theme.good), height: 6)
                    Text("\(Int(e.morale))").font(.caption2.monospacedDigit())
                }
                GridRow {
                    Text("Fatigue").font(.caption2).foregroundStyle(.secondary)
                    Meter(value: p.fatigue / 100, tint: p.fatigue >= 75 ? Theme.bad : (p.fatigue >= 50 ? Theme.warning : .teal), height: 6)
                    Text("\(Int(p.fatigue))").font(.caption2.monospacedDigit())
                }
                .help("Training runs in flight wear stars down; quiet months, mandates and sabbaticals bring it back. Over 75 their work slips; over 85 they can burn out.")
                GridRow {
                    Text("Renown").font(.caption2).foregroundStyle(.secondary)
                    Meter(value: p.renown / 100, tint: .yellow, height: 6)
                    Text("\(Int(p.renown))").font(.caption2.monospacedDigit())
                }
                .help("How well known they are in the field: breakthroughs, fended-off offers and prizes raise it. Renowned stars win prizes — and get more offers.")
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: met ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(met ? Theme.good : Theme.warning)
                Text("Wants: \(Stars.wantText(s, p))").font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            .help(met ? "Their want is met: mood rises a little every month." : "Unmet: mood drops every month, faster after four, and offers from rivals tempt them more.")
            HStack(spacing: 6) {
                if p.computeBudget > 0 { Pill(text: "Cluster \(Fmt.money(p.computeBudget))/mo", color: .orange, symbol: "cpu") }
                if p.mandate { Pill(text: "Own agenda", color: .indigo, symbol: "map") }
                if p.breakthroughs > 0 { Pill(text: "\(p.breakthroughs) breakthrough\(p.breakthroughs == 1 ? "" : "s")", color: .purple, symbol: "sparkles") }
                if p.offersFended > 0 { Pill(text: "Turned down \(p.offersFended)", color: .green, symbol: "shield.fill") }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Menu("Give…") {
                    Button("A raise to \(Fmt.money((e.salary * 1.2 / 1_000).rounded() * 1_000))/yr") { store.act("Raised \(Stars.firstName(p.name))'s pay") { $0.starGrant(p.id, .salary) } }
                    if !s.isPublicProgram {
                        Button("Stock worth \(Fmt.money(Stars.equityValue(s, nil, e)))") { store.act("Granted stock") { $0.starGrant(p.id, .equity) } }
                    }
                    if p.title.isEmpty { Button("The title \(Stars.titleFor(s, p))") { store.act("\(p.name) is now \(Stars.titleFor(s, p))") { $0.starGrant(p.id, .title) } } }
                    if !Stars.fits(p, .compute) {
                    } else if p.computeBudget == 0 {
                        Button("A \(Fmt.int(Stars.computeGPUs(s)))-GPU cluster (\(Fmt.money(Stars.computeBudget(s)))/mo)") { store.act("Cluster approved") { $0.starGrant(p.id, .compute) } }
                    } else {
                        Button("Take back their cluster") { store.mutate { $0.starRevoke(p.id, .compute) } }
                    }
                    if !Stars.fits(p, .mandate) {
                    } else if !p.mandate {
                        Button("Their own research agenda") { store.act("Mandate granted") { $0.starGrant(p.id, .mandate) } }
                    } else {
                        Button("Put them back on the roadmap") { store.mutate { $0.starRevoke(p.id, .mandate) } }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Pay and stock matter most to mercenaries, titles to showmen, clusters to builders and a free agenda to scholars and mavericks. A cluster speeds up breakthroughs; a mandate turns them into papers and renown instead of research points for your roadmap.")
                let why = Stars.sabbaticalBlocker(s, p)
                Button("Sabbatical") { store.act("Enjoy the time off, \(Stars.firstName(p.name))") { $0.starSabbatical(p.id) } }
                    .buttonStyle(.borderless).disabled(why != nil)
                    .help(why ?? "Three months away on full pay: fatigue resets, and they often come back with an idea.")
                Spacer()
                Button(storyOpen ? "Hide story" : "Story") { storyOpen.toggle() }.buttonStyle(.borderless)
            }
            .font(.caption)
            if storyOpen { StoryList(beats: p.story) }
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(starColor(p.personality).opacity(0.35), lineWidth: 1))
    }
}

private struct StoryList: View {
    let beats: [StarBeat]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(beats.enumerated()), id: \.offset) { _, b in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(b.date.gameMonth).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                    Text(b.text).font(.caption).foregroundStyle(b.tone > 0 ? Theme.good : (b.tone < 0 ? Theme.warning : .primary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 4)
    }
}

/// The strongest bonds and the worst feuds among your stars.
private struct ChemistryStrip: View {
    let state: GameState

    var body: some View {
        let pairs = Stars.pairs(state).prefix(4)
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Chemistry").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 10)], alignment: .leading, spacing: 6) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, x in
                    HStack(spacing: 6) {
                        Image(systemName: x.c >= 0.3 ? "link" : (x.c <= -0.3 ? "bolt.horizontal.fill" : "equal")).foregroundStyle(x.c >= 0.3 ? Theme.good : (x.c <= -0.3 ? Theme.bad : .secondary))
                        Text("\(Stars.firstName(x.a.name)) & \(Stars.firstName(x.b.name))").font(.caption.weight(.semibold))
                        Text(x.c >= 0.6 ? "dream team" : (x.c >= 0.3 ? "work well together" : (x.c <= -0.4 ? "feud" : (x.c < 0 ? "friction" : "fine")))).font(.caption).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text(Fmt.trim(x.c, 2)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Good pairs lift each other's mood every month; dream teams (0.6+) sharpen each other's skills and make breakthroughs likelier. Personalities, complementary specialties and years together all count.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

/// The two prizes: your best shot this year, and who has won lately.
private struct PrizesStrip: View {
    let state: GameState

    var body: some View {
        let s = state
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Prizes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                outlook(Stars.lovelace, "Computing's highest honour, announced each March. $1M.", Stars.prizeOutlook(s, Stars.lovelace))
                outlook(Stars.stockholm, "Science's highest honour, announced each October. AI work first wins in 2024.", Stars.prizeOutlook(s, Stars.stockholm))
            }
            ForEach(s.stars.awards.prefix(5)) { a in
                HStack(spacing: 6) {
                    Image(systemName: "rosette").foregroundStyle(a.mine ? .yellow : .secondary)
                    Text("\(a.year) \(a.prize)").font(.caption.weight(.semibold).monospacedDigit())
                    Text("\(a.winner)\(a.mine ? " (yours)" : (Cast.orgName(a.org, s, short: true).isEmpty ? "" : ", \(Cast.orgName(a.org, s, short: true))")) — \(a.citation)")
                        .font(.caption).foregroundStyle(a.mine ? .primary : .secondary).lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    func outlook(_ prize: String, _ what: String, _ o: (StarProfile, Double)?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(prize).font(.callout.weight(.semibold))
            Text(what).font(.caption2).foregroundStyle(.secondary)
            if let (p, odds) = o {
                Text(odds > 0 ? "Your best shot: \(p.name), about \(Fmt.pct(odds, decimals: 0)) this year" : "\(p.name) needs more renown and breakthroughs to be in the running")
                    .font(.caption)
            } else {
                Text("Nobody eligible yet: a star needs a year with you\(prize == Stars.stockholm ? " and a science specialty or a science discovery" : "").").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Stars who left, where they went, and whether they came back.
private struct AlumniStrip: View {
    let state: GameState

    var body: some View {
        let s = state
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("The ones who got away").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(s.stars.alumni.prefix(6)) { a in
                HStack(spacing: 6) {
                    Image(systemName: a.returned ? "arrow.uturn.backward.circle.fill" : "door.left.hand.open").foregroundStyle(a.returned ? .teal : .secondary)
                    Text(a.name).font(.caption.weight(.semibold))
                    Text("\(a.reason)\(a.lab.isEmpty ? "" : " → \(Stars.labName(s, a.lab))") · \(a.left.gameMonth)\(a.returned ? " · came back" : (a.asked ? " · asked to come back" : ""))")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
}

/// The best-known researchers at rival labs, and an offer you can make one of them.
private struct RivalStarsStrip: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let rivals = Stars.rivalStars(s)
        if !rivals.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                HStack {
                    Text("Rival stars").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if let why = Stars.raidBlocker(s) { Text(why).font(.caption2).foregroundStyle(.secondary) }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], alignment: .leading, spacing: 6) {
                    ForEach(rivals.prefix(6)) { m in RaidRow(member: m, state: s) }
                }
            }
        }
    }
}

private struct RaidRow: View {
    @Environment(GameStore.self) private var store
    let member: CastMember
    let state: GameState
    @State private var open = false
    @State private var mult = 1.6
    @State private var levers: Set<StarLever> = []

    var body: some View {
        let s = state
        let m = member
        HStack(spacing: 8) {
            PersonAvatar(initials: m.initials, color: starColor(Stars.castPersonality(m)), size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(m.name).font(.caption.weight(.semibold))
                Text("\(m.role), \(Stars.labName(s, m.org)) · \(Stars.castPersonality(m).title) · \(Stars.castSpecialty(m).title)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button("Make an offer…") { open = true }
                .buttonStyle(.borderless).font(.caption)
                .disabled(Stars.raidBlocker(s) != nil)
                .popover(isPresented: $open) { popover(s, m) }
        }
    }

    @ViewBuilder
    func popover(_ s: GameState, _ m: CastMember) -> some View {
        let cost = Stars.raidCost(s, m, mult: mult, levers: levers)
        let odds = Stars.raidOdds(s, m, mult: mult, levers: levers)
        VStack(alignment: .leading, spacing: 10) {
            Text("Hire \(m.name) from \(Stars.labName(s, m.org))").font(.headline)
            Text("Skill about \(Int(Stars.raidSkill(m))) · makes about \(Fmt.money(Stars.raidBaseSalary(s, m)))/yr now. \(Stars.castPersonality(m).blurb)").font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Pay: \(Fmt.trim(mult, 1))× → \(Fmt.money(cost.salary))/yr").font(.caption.monospacedDigit())
                Slider(value: $mult, in: 1.2...3, step: 0.1)
            }
            ForEach([StarLever.equity, .title, .compute, .mandate].filter { !s.isPublicProgram || $0 != .equity }) { l in
                Toggle(isOn: Binding(get: { levers.contains(l) }, set: { on in if on { levers.insert(l) } else { levers.remove(l) } })) {
                    Text(text(l, s, cost.equity)).font(.caption)
                }
                .toggleStyle(.checkbox)
            }
            HStack {
                Text("Chance they say yes").font(.caption)
                Meter(value: odds, tint: odds >= 0.5 ? Theme.good : Theme.warning, height: 8).frame(width: 120)
                Text(Fmt.pct(odds, decimals: 0)).font(.callout.weight(.bold).monospacedDigit())
            }
            Text("Signing bonus \(Fmt.money(cost.signing)) if they accept. Their lab may counter once; turned down, you can try someone again in 60 days.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Send the offer") {
                    open = false
                    store.act(nil) { $0.starRaid(m.id, mult: mult, levers: levers) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    func text(_ l: StarLever, _ s: GameState, _ equity: Double) -> String {
        switch l {
        case .equity: "Stock worth \(Fmt.money(levers.contains(.equity) ? equity : Stars.raidCost(s, member, mult: mult, levers: [.equity]).equity))"
        case .title: "A big title"
        case .compute: "A \(Fmt.int(Stars.computeGPUs(s)))-GPU cluster of their own (\(Fmt.money(Stars.computeBudget(s)))/mo)"
        case .mandate: "Their own research agenda"
        case .salary: ""
        }
    }
}
