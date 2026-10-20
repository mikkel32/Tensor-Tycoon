import Charts
import SwiftUI

// MARK: - 3.9: Spotlight — the hype meter, launch events and developer days, viral moments and the conference circuit

struct SpotlightView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let year = s.date.ym.year
        let viralYear = s.hype.viral.filter { $0.date.ym.year == year }
        Page(title: "Spotlight",
             subtitle: "How much the world is waiting for your next thing. Tease it, put on a show, ride the memes and survive the backlash — then spend the hype on a launch.",
             screen: .spotlight) {
            KPIRow {
                StatTile(title: "Hype", value: "\(Int(s.hype.meter.rounded()))", detail: Hype.mood(s.hype.meter), symbol: "flame.fill", tint: SpotlightStyle.heat(s.hype.meter),
                         trend: s.hype.history.count >= 2 ? s.hype.meter - s.hype.history[s.hype.history.count - 2] : nil)
                StatTile(title: "Launch today", value: "+\(Int((Hype.boostNow(s) * 100).rounded()))%", detail: "Day-one demand, halving every \(Int(Hype.boostHalfLife)) days",
                         symbol: "chart.line.uptrend.xyaxis", tint: .orange)
                StatTile(title: "Prestige", value: "\(Int(s.hype.prestige.rounded()))", detail: s.hype.hires > 0 ? "\(s.hype.hires) candidates drawn so far" : "Papers and talks draw researchers",
                         symbol: "graduationcap.fill", tint: .indigo)
                StatTile(title: "Viral this year", value: "\(viralYear.count)", detail: "\(viralYear.filter(\.positive).count) good, \(viralYear.filter { !$0.positive }.count) bad",
                         symbol: "bolt.heart.fill", tint: .pink)
                StatTile(title: "Next show", value: s.hype.event.map { "\(max(0, GameCalendar.daysBetween(s.date, $0.date))) days" } ?? "—",
                         detail: s.hype.event.map { "\($0.kind.title), \($0.date.gameShort)" } ?? "Nothing booked", symbol: "sparkles.tv.fill", tint: .purple)
            }
            HStack(alignment: .top, spacing: Theme.gap) {
                HypeMeterCard(state: s)
                StageCard(state: s)
                    .frame(width: 480)
            }
            CardGrid(minWidth: 380, maxColumns: 2) {
                LastShowCard(state: s)
                ViralCard(state: s)
            }
            CardGrid(minWidth: 380, maxColumns: 2) {
                SocialFeedCard(state: s)
                CircuitCard(state: s)
            }
            HypeLaunchesCard(state: s)
        }
    }
}

enum SpotlightStyle {
    static func heat(_ v: Double) -> Color {
        switch v {
        case ..<15: .gray
        case ..<30: .teal
        case ..<50: .yellow
        case ..<70: .orange
        default: .red
        }
    }

    static func tone(_ t: Double) -> Color { t > 0.15 ? Theme.good : (t < -0.15 ? Theme.bad : .secondary) }
}

// MARK: - The meter

private struct HypeGauge: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.5)
                .stroke(.quaternary, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(180))
            Circle().trim(from: 0, to: 0.5 * clamp(value, 0, 100) / 100)
                .stroke(AngularGradient(colors: [.teal, .yellow, .orange, .red, .pink], center: .center, startAngle: .degrees(180), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(180))
            VStack(spacing: 0) {
                Text("\(Int(value.rounded()))").font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                Text(Hype.mood(value).uppercased()).font(.caption.weight(.heavy)).foregroundStyle(SpotlightStyle.heat(value))
            }
            .offset(y: -8)
        }
        .frame(width: 200, height: 200)
        .frame(height: 120, alignment: .top)
        .clipped()
        .animation(.smooth, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hype")
        .accessibilityValue("\(Int(value)) of 100, \(Hype.mood(value))")
    }
}

private struct HypeMeterCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let teaser = Hype.teaserBlocker(s)
        Card {
            CardHeader("Hype meter", symbol: "flame.fill", subtitle: "Rests near \(Int(Hype.rest(s))) for a lab with your brand; a show on the calendar pulls it up")
            HStack(alignment: .center, spacing: 18) {
                HypeGauge(value: s.hype.meter)
                VStack(alignment: .leading, spacing: 6) {
                    if s.hype.history.count >= 3 {
                        Chart(Array(s.hype.history.enumerated()), id: \.offset) { p in
                            AreaMark(x: .value("Week", p.offset), y: .value("Hype", p.element))
                                .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.35), .orange.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Week", p.offset), y: .value("Hype", p.element))
                                .foregroundStyle(.orange)
                                .interpolationMethod(.monotone)
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis(.hidden)
                        .chartYAxis { AxisMarks(values: [0, 50, 100]) }
                        .frame(height: 80)
                        Text("Last \(s.hype.history.count) weeks").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("The chart fills in week by week.").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("A launch now gets **+\(Int((Hype.boostNow(s) * 100).rounded()))%** demand on day one. Launch a model that falls well short of the hype and the reviews say \"overhyped\".")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            HStack {
                Button {
                    store.act("Teaser posted") { $0.postTeaser() }
                } label: {
                    Label("Post a teaser (+\(Fmt.trim(Hype.teaserGain(s), 1)))", systemImage: "eye.trianglebadge.exclamationmark")
                }
                .disabled(teaser != nil)
                .help(teaser ?? "A cryptic post from your company account. Each one since your last launch adds less, and after three people start counting.")
                Spacer()
                if s.hype.teasers > 0 {
                    Text("\(s.hype.teasers) teaser\(s.hype.teasers == 1 ? "" : "s") since your last launch").font(.caption).foregroundStyle(s.hype.teasers >= 3 ? .orange : .secondary)
                }
            }
            if let p = s.hype.promise {
                Label("You promised \(s.hype.promiseModel) on stage: ship a new model by \(p.gameShort) (\(GameCalendar.daysBetween(s.date, p)) days).", systemImage: "hourglass")
                    .font(.caption).foregroundStyle(.orange)
            }
            if !s.hype.drivers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What moved it").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(Array(s.hype.drivers.prefix(7).enumerated()), id: \.offset) { _, d in
                        HStack(spacing: 8) {
                            Text((d.amount >= 0 ? "+" : "") + Fmt.trim(d.amount, 1))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(d.amount >= 0 ? Theme.good : Theme.bad)
                                .frame(width: 44, alignment: .trailing)
                            Text(d.text).font(.caption).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(d.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - The stage

private struct StageCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var kind: StageKind = .launch
    @State private var format: StageFormat = .pressEvent
    @State private var days = 30

    var body: some View {
        let s = state
        Card {
            if let e = s.hype.event {
                planned(s, e)
            } else {
                planner(s)
            }
        }
    }

    @ViewBuilder
    private func planner(_ s: GameState) -> some View {
        CardHeader("Put on a show", symbol: "sparkles.tv.fill", subtitle: "Book it weeks ahead: anticipation builds until the day")
        Picker("Show", selection: $kind) {
            ForEach(StageKind.allCases) { k in Label(k.title, systemImage: k.symbol).tag(k) }
        }
        .pickerStyle(.segmented)
        Text(kind.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(StageFormat.allCases) { f in
                Button {
                    format = f
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: format == f ? "largecircle.fill.circle" : "circle").foregroundStyle(format == f ? Theme.accent : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(f.title).font(.callout.weight(.semibold))
                                Spacer()
                                Text(Fmt.money(Stage.cost(s, f))).font(.callout.monospacedDigit())
                            }
                            Text("\(f.detail) Anticipation up to \(Int(f.anticipationCap * (kind == .devDay ? 0.8 : 1))).")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        Picker("When", selection: $days) {
            ForEach(Stage.leadDays, id: \.self) { d in Text("In \(d) days (\(GameCalendar.addDays(s.date, d).gameShort))").tag(d) }
        }
        let why = Stage.blocker(s, kind: kind, format: format)
        HStack {
            if let why { Label(why, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange) }
            Spacer()
            Button("Announce it") {
                store.act("\(kind.title) announced") { $0.announceStageEvent(kind, format: format, days: days) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(why != nil)
        }
        if let last = s.hype.shows.first {
            Text("Last show: \(last.headline), \(last.date.gameShort).").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func planned(_ s: GameState, _ e: StageEvent) -> some View {
        let left = GameCalendar.daysBetween(s.date, e.date)
        CardHeader(title: e.kind.title, symbol: e.kind.symbol, subtitle: "\(e.format.title) · \(e.date.gameShort) · booked for \(Fmt.money(e.cost))") {
            Text(left <= 0 ? "Today" : "in \(left) days").font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(.purple)
        }
        if e.kind == .launch {
            if let found = Stage.showModel(s, e) {
                let rank = Leaderboard.rank(of: found.model.id, in: s)
                Label(found.release ? "On stage: \(found.model.name), going live on the day (would rank #\(rank))" : "On stage: \(found.model.name) (#\(rank)), released already — the show is its big moment",
                      systemImage: "cube.box.fill")
                    .font(.callout).foregroundStyle(.green)
            } else {
                Label("Nothing to launch yet: finish a model by \(e.date.gameShort), or it's a vision keynote.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
            }
        }
        Text("Run of show (up to \(Stage.maxSegments), in order — close on your best moment)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        ForEach(Array(e.segments.enumerated()), id: \.element) { i, seg in
            HStack(spacing: 8) {
                Text("\(i + 1)").font(.caption.monospacedDigit().weight(.bold)).frame(width: 18)
                Image(systemName: seg.symbol).frame(width: 18).foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 1) {
                    Text(seg.title).font(.callout.weight(.semibold))
                    if seg == .liveDemo || seg == .agentDemo {
                        OddsBar(probability: Stage.demoRisk(s, e, agent: seg == .agentDemo), label: "Chance it goes wrong", risk: true)
                            .frame(maxWidth: 260)
                    } else if seg == .cameo {
                        Text("Fee on the day: \(Fmt.money(Stage.cameoFee(s)))").font(.caption).foregroundStyle(.secondary)
                    } else if seg == .credits {
                        Text("Credits handed out: \(Fmt.money(Stage.creditsCost(s)))").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(seg.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
                Button { move(e, i, -1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.borderless).disabled(i == 0)
                Button { move(e, i, 1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.borderless).disabled(i == e.segments.count - 1)
                Button { set(e.segments.filter { $0 != seg }) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.borderless).foregroundStyle(.secondary)
            }
        }
        let spare = StageSegment.options(e.kind).filter { !e.segments.contains($0) && Stage.segmentBlocker(s, $0) == nil }
        if e.segments.count < Stage.maxSegments && !spare.isEmpty {
            Menu {
                ForEach(spare) { seg in
                    Button { set(e.segments + [seg]) } label: { Label("\(seg.title) — \(seg.detail)", systemImage: seg.symbol) }
                }
            } label: {
                Label("Add a segment", systemImage: "plus.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        if e.segments.contains(.pricing) {
            Picker("Price to reveal", selection: Binding(get: { e.pricing }, set: { p in store.mutate { $0.setStagePricing(p) } })) {
                ForEach(PricingStance.allCases) { p in Text(p.title).tag(p) }
            }
            .pickerStyle(.segmented)
        }
        Divider()
        let rehearse = Stage.rehearsalBlocker(s)
        HStack {
            Button {
                store.act("Rehearsed: demo risk down a third") { $0.rehearseStage() }
            } label: {
                Label("Rehearse (\(e.rehearsals)/\(Stage.maxRehearsals))", systemImage: "music.mic")
            }
            .disabled(rehearse != nil)
            .help(rehearse ?? "Three days of the research team's time (\(Fmt.trim(s.rpToday * 3, 0)) points): each rehearsal takes a third off the demo risk.")
            Spacer()
            Button("Postpone 3 weeks") { store.act("Postponed") { $0.postponeStage() } }
                .disabled(e.postponed >= 2)
                .help("Hype −6. At most twice.")
            Button("Cancel", role: .destructive) { store.act("Cancelled") { $0.cancelStage() } }
                .help("Hype −15 (and brand −1 inside two weeks). The booking is lost.")
        }
        .controlSize(.small)
    }

    private func set(_ segs: [StageSegment]) { store.act { $0.setStageSegments(segs) } }

    private func move(_ e: StageEvent, _ i: Int, _ by: Int) {
        var segs = e.segments
        let j = i + by
        guard segs.indices.contains(j) else { return }
        segs.swapAt(i, j)
        set(segs)
    }
}

// MARK: - The last show

private struct LastShowCard: View {
    let state: GameState
    @State private var pick: UUID? = nil

    var body: some View {
        let s = state
        let show = s.hype.shows.first { $0.id == pick } ?? s.hype.shows.first
        Card {
            CardHeader(title: "Live blog", symbol: "dot.radiowaves.left.and.right", subtitle: show.map { "\($0.title) · \($0.date.gameShort) · \(Fmt.count($0.viewers)) watched" } ?? "Your shows, beat by beat") {
                if s.hype.shows.count > 1 {
                    Picker("Show", selection: Binding(get: { show?.id }, set: { pick = $0 })) {
                        ForEach(s.hype.shows) { sh in Text("\(sh.title) (\(sh.date.gameShort))").tag(UUID?.some(sh.id)) }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            }
            if let show {
                HStack(spacing: 14) {
                    VStack(spacing: 0) {
                        Text("\(Int(show.score))").font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                        Text("/ 100").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 70, height: 64)
                    .background((show.score >= 70 ? Color.green : (show.score >= 50 ? Color.blue : Color.red)).opacity(0.15), in: .rect(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(show.headline).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        Text("Hype \(Int(show.hypeBefore)) → \(Int(show.hypeAfter)) · \(show.format.short)\(show.demo == "fail" ? " · the demo failed" : (show.demo == "ok" ? " · demos worked" : ""))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(show.beats.enumerated()), id: \.offset) { i, b in
                        HStack(alignment: .top, spacing: 10) {
                            Text(b.clock).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                            VStack(spacing: 0) {
                                Circle().fill(SpotlightStyle.tone(b.tone)).frame(width: 9, height: 9).padding(.top, 4)
                                if i < show.beats.count - 1 { Rectangle().fill(.quaternary).frame(width: 2).frame(maxHeight: .infinity) }
                            }
                            .frame(width: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                if let seg = StageSegment(rawValue: b.segment) {
                                    Label(seg.title, systemImage: seg.symbol).font(.caption2.weight(.semibold)).foregroundStyle(.purple)
                                }
                                Text(b.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, 10)
                        }
                    }
                }
            } else {
                EmptyStateView(symbol: "sparkles.tv", title: "No shows yet", message: "Book a launch event or a developer day. The live blog of the day appears here.", compact: true)
            }
        }
    }
}

// MARK: - Viral moments

private struct ViralCard: View {
    let state: GameState

    var body: some View {
        let s = state
        let trending = Array(Set(s.hype.viral.filter { GameCalendar.daysBetween($0.date, s.date) <= 30 }.map(\.hashtag))).sorted()
        // Moments the older systems wrote up (viral demos, jailbreaks, viral papers).
        let elsewhere = s.news.filter { n in
            n.title.lowercased().contains("viral") && !n.title.hasPrefix("Viral:") && !n.title.hasPrefix("Backlash:") && !n.title.hasPrefix("Going viral")
                && GameCalendar.daysBetween(n.date, s.date) <= 180
        }.prefix(3)
        Card {
            CardHeader("Viral moments", symbol: "bolt.heart.fill", subtitle: "Memes, clips and backlashes. Likelier with more hype and more users; the bad kind with weak safety")
            if !trending.isEmpty {
                HStack(spacing: 6) {
                    Text("Trending").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(trending.prefix(4), id: \.self) { t in Pill(text: t, color: .pink) }
                }
            }
            if s.hype.viral.isEmpty && elsewhere.isEmpty {
                EmptyStateView(symbol: "bolt.heart", title: "Nothing has caught fire", message: "Release a model people can use. Hype and a big user base make moments likelier.", compact: true)
            }
            ForEach(s.hype.viral.prefix(6)) { v in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: v.positive ? "flame.fill" : "exclamationmark.bubble.fill")
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background((v.positive ? Color.orange : Color.red).gradient, in: .rect(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.title).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Text(v.hashtag).foregroundStyle(.pink)
                            Text("\(Fmt.count(v.views)) views")
                            if abs(v.brandDelta) >= 0.05 { Text("brand \(v.brandDelta >= 0 ? "+" : "")\(Fmt.trim(v.brandDelta, 1))").foregroundStyle(v.brandDelta >= 0 ? Theme.good : Theme.bad) }
                            if !v.response.isEmpty { Text(v.response) }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text(v.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                }
            }
            if !elsewhere.isEmpty {
                Divider()
                ForEach(Array(elsewhere)) { n in
                    Label(n.title, systemImage: "newspaper").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
}

// MARK: - The feed

private struct SocialFeedCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let posts = s.pulse.filter { $0.labs.contains("player") }.prefix(8)
        Card {
            CardHeader(title: "What they're saying about you", symbol: "bubble.left.and.bubble.right.fill",
                       subtitle: s.buzz["player"].map { "Attention \(Int($0.attention)) · tone \($0.tone >= 0 ? "+" : "")\(Fmt.trim($0.tone, 2)) over \(Pulse.window) days" } ?? "The Pulse, filtered to you") {
                Button("The Pulse") { store.open(.pulse) }.buttonStyle(.link)
            }
            if posts.isEmpty {
                EmptyStateView(symbol: "bubble.left", title: "Nobody's talking yet", message: "Tease something, ship something, or win something.", compact: true)
            }
            ForEach(Array(posts)) { p in PulsePostRow(post: p, state: s, showLabs: false) }
        }
    }
}

// MARK: - The conference circuit

private struct CircuitCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        let boothWhy = Hype.boothBlocker(s)
        Card {
            CardHeader(title: "Conference circuit", symbol: "graduationcap.fill", subtitle: "Papers and talks build prestige; from 25, researchers apply every month") {
                Button("Events") { store.open(.events) }.buttonStyle(.link)
            }
            HStack(spacing: 10) {
                Text("Prestige").font(.caption).foregroundStyle(.secondary)
                Meter(value: s.hype.prestige / 100, tint: .indigo)
                Text("\(Int(s.hype.prestige.rounded()))").font(.callout.monospacedDigit().weight(.semibold))
            }
            ForEach(Conferences.upcoming(s, count: 4), id: \.0.id) { item in
                let (v, d) = item
                let cfp = GameCalendar.addDays(d, -Conferences.cfpLead)
                let mine = s.fun.papers.first { $0.venue == v.id && $0.year == d.ym.year }
                HStack(spacing: 10) {
                    Image(systemName: "building.columns.fill").foregroundStyle(.white).frame(width: 26, height: 26).background(Color.indigo.gradient, in: .rect(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(v.short) \(d.ym.year) · \(v.city)").font(.callout.weight(.semibold))
                        Text(mine.map { "Your paper: \($0.outcome.label.lowercased())" }
                             ?? (s.publication == .secret ? "You don't publish" : (cfp > s.date ? "Paper deadline \(cfp.gameShort)" : "Deadline passed")))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if s.hype.booth == "\(v.id)|\(d.ym.year)" { Pill(text: "Booth booked", color: .green, symbol: "person.badge.plus") }
                    Text(d.gameShort).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            HStack {
                Button {
                    store.act("Recruiting booth booked") { $0.bookRecruitingBooth() }
                } label: {
                    Label("Book a recruiting booth (\(Fmt.money(Hype.boothCost(s))))", systemImage: "person.badge.plus")
                }
                .disabled(boothWhy != nil)
                .help(boothWhy ?? "Your team meets candidates at \(Hype.boothVenue(s).map { $0.0.short } ?? "the next conference"): three strong candidates on the day, better with prestige.")
                Spacer()
                if s.hype.boothsRun > 0 { Text("\(s.hype.boothsRun) booth\(s.hype.boothsRun == 1 ? "" : "s") so far").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

// MARK: - Launches and the hype they spent

private struct HypeLaunchesCard: View {
    let state: GameState

    var body: some View {
        let s = state
        if !s.hype.launches.isEmpty {
            Card {
                CardHeader("Launches and the hype they spent", symbol: "chart.bar.doc.horizontal", subtitle: "Hype at launch against what the model delivered (rank and progress, on the same scale)")
                ForEach(Array(s.hype.launches.prefix(6).enumerated()), id: \.offset) { _, l in
                    HStack(spacing: 12) {
                        Text(l.model).font(.callout.weight(.semibold)).frame(width: 140, alignment: .leading).lineLimit(1)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Hype").font(.caption2).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
                                Meter(value: l.hype / 100, tint: .orange, height: 6)
                                Text("\(Int(l.hype))").font(.caption.monospacedDigit()).frame(width: 26)
                            }
                            HStack(spacing: 6) {
                                Text("Delivered").font(.caption2).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
                                Meter(value: l.delivered / 100, tint: .green, height: 6)
                                Text("\(Int(l.delivered))").font(.caption.monospacedDigit()).frame(width: 26)
                            }
                        }
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("+\(Int((l.boost * 100).rounded()))% day one").font(.caption.monospacedDigit())
                            if l.verdict == "overhyped" { Pill(text: "Overhyped", color: .red) }
                            else if l.verdict == "sleeper" { Pill(text: "Sleeper hit", color: .green) }
                            else if l.showScore >= 0 { Pill(text: "Show \(Int(l.showScore))/100", color: .purple) }
                        }
                        .frame(width: 120, alignment: .trailing)
                        Text(l.date.gameShort).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}
