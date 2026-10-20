import Charts
import SwiftUI

/// Today: where you stand, then four sections — Needs you, The race, Business and Programmes — each in two columns.
/// Cards for systems you haven't started stay hidden. Everything comes from the store's cached `derived` data or cheap
/// reads (`Agenda`), each computed once per redraw and passed down, so the page redraws fast.
struct DashboardView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let d = store.derived
        let labs = Leaderboard.labs(d.board, state: s)
        let race = Agenda.race(labs)
        let needs = Agenda.needs(s, advice: d.advice)
        let upcoming = Agenda.upcoming(s, watch: d.watch, bonuses: d.bonuses)
        let steps = EraGuide.steps(s)
        let stepsLeft = steps.contains { !$0.done }
        let liveRSI = s.rsiRuns.filter { $0.status != .halted }
        let liveRuns = s.runs.filter { $0.status == .running || $0.status == .postTraining || $0.status == .paused }.count
        let hasFamilies = !s.families.families.isEmpty || !s.families.jobs.isEmpty
        let hasOrgs = !s.swarms.isEmpty || !s.orgs.isEmpty || s.xenoInsight > 0 || !s.alienArchs.isEmpty
        let hasAdvanced = !s.advanced.programmes.isEmpty || !s.advanced.solicitations.isEmpty
        let hasScience = !s.science.labs.isEmpty || !s.science.discoveries.isEmpty

        Page(title: "Today", subtitle: "Your dashboard: what needs you, how the race stands, the business and the work in progress.", screen: .dashboard) {
            ScreenHint(.dashboard)
            TodayHeader(state: s, derived: d, race: race)

            DashboardSection(title: "Needs you", symbol: "exclamationmark.bubble.fill",
                             subtitle: needs.isEmpty ? "Nothing waiting on you" : "\(needs.count) item\(needs.count == 1 ? "" : "s") to look at") {
                NeedsYouCard(needs: needs, stepsLeft: stepsLeft)
                GettingStarted(state: s, steps: steps)
                FoundingKitCard(state: s)   // 3.5
            } right: {
                ComingUpCard(items: upcoming, today: s.date)
                SinceLastMonthCard(state: s)
            }

            DashboardSection(title: "The race", symbol: "flag.checkered",
                             subtitle: race.rank.map { "#\($0) of \(race.labs) · \(race.gap)" } ?? "Release a model to enter the rankings") {
                RaceCard(labs: labs, state: s)
                TopLabsCard(labs: labs)
                BenchmarkRaceCard(set: d.indexSet, board: d.board, saturated: s.benchSaturated)
            } right: {
                ProgressionCard(state: s)   // 3.7
                MilestonesCard()
                RivalWatchList(rows: Array(d.watch.prefix(5)))
                PulseCard()
                LatestNewsCard(news: Array(s.news.prefix(6)))
            }

            DashboardSection(title: "Business", symbol: "chart.pie.fill",
                             subtitle: d.runRate >= 1 ? "Run-rate \(Fmt.money(d.runRate))/yr · cash \(Fmt.money(s.cash))" : "Pre-revenue · cash \(Fmt.money(s.cash))") {
                RevenueCard(state: s)
                BusinessCard(state: s, derived: d)
                if s.corp.engaged || s.isPublic { CorporateCard(state: s) }   // 3.5
            } right: {
                WorldCard()
                NationsCard(state: s)   // 3.7
                if s.semi.engaged { SemiconductorCard(state: s) }   // 3.5
            }

            DashboardSection(title: "Programmes", symbol: "square.stack.3d.up.fill",
                             subtitle: liveRuns == 0 ? "No training runs in progress" : "\(liveRuns) training run\(liveRuns == 1 ? "" : "s") in progress") {
                ActiveRunsCard(state: s)
                if hasFamilies { ModelFamiliesCard(state: s) }   // 3.5
                if !liveRSI.isEmpty { RSIStatusCard(runs: liveRSI) }
                if hasOrgs { AgentOrgsDashboardCard(state: s) }   // 3.6
            } right: {
                if hasAdvanced { AdvancedProjectsCard(state: s) }   // 3.5
                if hasScience { ScienceDashboardCard(state: s) }   // 3.6
                FunDashboardCard()
            }
        }
    }
}

/// One dashboard section: a header, then two columns of cards that keep their own heights.
private struct DashboardSection<Left: View, Right: View>: View {
    let title: String
    let symbol: String
    let subtitle: String
    let left: Left
    let right: Right

    init(title: String, symbol: String, subtitle: String, @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.title = title
        self.symbol = symbol
        self.subtitle = subtitle
        self.left = left()
        self.right = right()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            SectionHeader(title, symbol: symbol, subtitle: subtitle)
            HStack(alignment: .top, spacing: Theme.gap) {
                VStack(spacing: Theme.gap) { left }
                    .frame(maxWidth: .infinity, alignment: .top)
                VStack(spacing: Theme.gap) { right }
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .padding(.top, Theme.Space.s)
    }
}

// MARK: - Header

/// Who you are and the date, then four numbers: your place in the race, cash and runway, revenue and its trend, valuation.
private struct TodayHeader: View {
    let state: GameState
    let derived: Derived
    let race: Agenda.Race

    var body: some View {
        let s = state
        let d = derived
        let day = GameCalendar.daysBetween(s.startDate, s.date) + 1
        let change = Agenda.revenueChange(s)
        VStack(spacing: 12) {
            HeroBanner(image: heroImage(s), height: 150) {
                HStack(alignment: .bottom) {
                    CompanyLogo(symbol: s.logoSymbol, color: Theme.logoColor(s.logoColor), size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(s.companyName).font(.system(size: 28, weight: .bold))
                            PhotoPill(text: s.doctrine.title, symbol: s.doctrine.symbol)
                        }
                        Text("\(s.date.gameLong) · day \(Fmt.int(day))")
                            .font(.callout.weight(.semibold).monospacedDigit())
                        Text("\(Economy.office(s, s.officeLevel).name) · \(Fmt.int(s.employees.count + 1)) people · \(Fmt.int(d.totalChips)) accelerators · \(Fmt.count(d.h100e)) H100e")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Your net worth").font(.caption).opacity(0.8)
                        Text(Fmt.money(s.founderNetWorth)).font(.title2.weight(.bold).monospacedDigit())
                        Text("\(Fmt.pct(s.founderStake)) of the company\(s.founderCash > 0 ? " · \(Fmt.money(s.founderCash)) cashed out" : "")")
                            .font(.caption).opacity(0.8)
                    }
                }
            }
            KPIRow(minWidth: 220) {
                HeadlineTile(title: "Place in the race", value: race.rank.map { "#\($0) of \(race.labs)" } ?? "Not ranked",
                             detail: race.gap, symbol: "flag.checkered", tint: .orange, term: .capability, screen: .leaderboard)
                HeadlineTile(title: "Cash", value: Fmt.money(s.cash), detail: Agenda.runwayText(s), symbol: "banknote.fill",
                             tint: s.cash >= 0 ? .green : .red, term: .runway, screen: .finance)
                HeadlineTile(title: "Revenue run-rate", value: d.runRate >= 1 ? "\(Fmt.money(d.runRate))/yr" : "$0", detail: revenueDetail(s, change),
                             symbol: "chart.line.uptrend.xyaxis", tint: .blue, term: .runRate, screen: .market, trend: change)
                HeadlineTile(title: "Valuation", value: Fmt.money(s.valuation),
                             detail: s.isPublic ? "Public · \(Fmt.price(s.sharePrice)) a share" : "Private mark · you own \(Fmt.pct(s.founderStake))",
                             symbol: "building.columns.fill", tint: .purple, term: .valuation, screen: .funding)
            }
        }
    }

    private func revenueDetail(_ s: GameState, _ change: Double?) -> String {
        guard s.month.revenue > 0 || s.history.contains(where: { $0.revenue > 0 }) else {
            return "Pre-revenue: release a model and sell it"
        }
        guard let last = s.history.last else { return "This month \(Fmt.money(s.month.revenue)) so far" }
        guard let ch = change else { return "Last month \(Fmt.money(last.revenue)) · this month \(Fmt.money(s.month.revenue)) so far" }
        let vs = ch >= 1 ? "\(Fmt.trim(1 + ch, 1))× the month before" : "\(ch >= 0 ? "+" : "−")\(Fmt.pct(abs(ch), decimals: 0)) on the month before"
        return "Last month \(Fmt.money(last.revenue)), \(vs)"
    }

    private func heroImage(_ s: GameState) -> String {
        if let dc = s.sites.filter({ $0.kind == .datacenter && $0.isReady(s.date) }).max(by: { $0.capacityKW < $1.capacityKW }) { return dc.location.image }
        if s.sites.contains(where: { $0.kind == .colo }) { return "dc_corridor" }
        return Economy.office(s, s.officeLevel).image
    }
}

/// A headline number with a "?" for its glossary term and a link to the screen behind it.
private struct HeadlineTile: View {
    @Environment(GameStore.self) private var store
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color
    let term: GlossaryTerm
    let screen: Screen
    var trend: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(tint.gradient, in: .rect(cornerRadius: Theme.Radius.chip))
                    .accessibilityHidden(true)
                Text(title).font(TypeRamp.label).foregroundStyle(.secondary).lineLimit(1)
                HelpButton(term: term)
                Spacer(minLength: 0)
                Button {
                    store.open(screen)
                } label: {
                    Image(systemName: "arrow.right.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Open \(screen.title)")
                .accessibilityLabel("Open \(screen.title)")
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(TypeRamp.metric)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                if let trend {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(trend >= 0 ? Theme.good : Theme.bad)
                        .accessibilityLabel(trend >= 0 ? "Up" : "Down")
                }
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.tile).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

// MARK: - Needs you

/// The top things to act on from the Chief of Staff, the inbox and unread alerts, each with its one-click action.
private struct NeedsYouCard: View {
    @Environment(GameStore.self) private var store
    let needs: [Agenda.Need]
    /// Opening steps still to do (the Next steps card): the empty state points there.
    let stepsLeft: Bool
    @State private var showAll = false

    var body: some View {
        let shown = showAll ? needs : Array(needs.prefix(3))
        Card {
            CardHeader(title: "Needs you", symbol: "exclamationmark.bubble.fill", subtitle: subtitle) {
                HStack(spacing: 10) {
                    HelpButton(term: .chiefOfStaff)
                    Button("Delegates") { store.open(.operations) }.buttonStyle(.link)
                }
            }
            if needs.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nothing needs you right now.").font(.callout.weight(.semibold))
                        Text(stepsLeft ? "Work through Next steps to get your lab going, then let the clock run."
                                       : "Let the clock run. Delegates on Operations can take more of the routine work.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                ForEach(shown) { n in NeedRow(need: n) }
                if needs.count > 3 {
                    Button(showAll ? "Show only the top 3" : "Show all \(needs.count)") { showAll.toggle() }
                        .buttonStyle(.link)
                }
            }
        }
    }

    private var subtitle: String {
        guard !needs.isEmpty else { return "From your Chief of Staff, inbox and alerts" }
        let quick = needs.filter { n in
            switch n.kind {
            case .advice(let a): a.fix != nil
            case .decision, .alert: true
            }
        }.count
        return "\(needs.count) item\(needs.count == 1 ? "" : "s"), \(quick) with a one-click action"
    }
}

private struct NeedRow: View {
    let need: Agenda.Need

    var body: some View {
        switch need.kind {
        case .advice(let item): AdviceRow(item: item)
        case .decision(let d): InboxRow(decision: d)
        case .alert(let a): AlertRow(alert: a)
        }
    }
}

/// Icon, title, a line or two of detail and the actions, on a tinted background.
private struct NeedLayout<Actions: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.semibold)).lineLimit(2)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) { actions }
                    .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 10))
    }
}

/// A Chief of Staff item: its one-click fix, a link to the screen, and the bell to hide it for a while.
struct AdviceRow: View {
    @Environment(GameStore.self) private var store
    let item: AdvisorItem

    var body: some View {
        let tint = Self.color(item.level)
        NeedLayout(symbol: item.symbol, tint: tint, title: item.title, detail: item.detail) {
            if item.fix != nil {
                Button(item.fixLabel.isEmpty ? "Fix it" : item.fixLabel) { store.applyFix(item) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(tint)
            }
            Button("Open \(item.screen.title)") { store.open(item.screen) }
                .buttonStyle(.link)
                .font(.caption)
            Spacer(minLength: 0)
            SnoozeMenu { days in store.snooze(item, days: days) }
        }
    }

    static func color(_ l: AdvisorItem.Level) -> Color {
        switch l {
        case .urgent: .red
        case .warning: .orange
        case .info: .blue
        }
    }
}

/// An offer waiting in the inbox: how long it waits and what happens if you don't answer.
private struct InboxRow: View {
    @Environment(GameStore.self) private var store
    let decision: Decision

    var body: some View {
        let left = Agenda.daysLeft(decision, today: store.game.date)
        let tint: Color = left <= 3 ? .orange : .blue
        let fallback = Agenda.defaultAnswer(decision, store.game).map { " it resolves as \"\($0)\"" } ?? " it resolves on its own"
        NeedLayout(symbol: "tray.full.fill", tint: tint, title: decision.title,
                   detail: "Waiting in your inbox. \(left == 0 ? "Today is the last day; then" : "\(left) day\(left == 1 ? "" : "s") left, then")\(fallback).") {
            Button("Answer") { store.openDecisionID = decision.id }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(tint)
            Spacer(minLength: 0)
            SnoozeMenu { days in
                store.mutate { $0.snoozeAdvice("inbox-\(decision.id)", days: days) }
                store.show("Hidden for \(days) days")
            }
        }
    }
}

/// An unread alert that nothing else on the page covers.
private struct AlertRow: View {
    @Environment(GameStore.self) private var store
    let alert: GameAlert

    var body: some View {
        NeedLayout(symbol: alert.celebrate ? "star.circle.fill" : alert.alertKind.symbol, tint: alert.tint, title: alert.title, detail: alert.body) {
            Button(alert.target.map { "Open \($0.title)" } ?? "Open") { store.follow(alert) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(alert.tint)
            Text(alert.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            Button {
                store.mutate { $0.dismissAlert(alert.id) }
            } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
            .accessibilityLabel("Dismiss alert")
        }
    }
}

private struct SnoozeMenu: View {
    let snooze: (Int) -> Void

    var body: some View {
        Menu {
            Button("Hide for a week") { snooze(7) }
            Button("Hide for a month") { snooze(30) }
            Button("Hide for a year") { snooze(365) }
        } label: {
            Image(systemName: "bell.slash")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Hide this for a while")
        .accessibilityLabel("Hide this for a while")
    }
}

/// Measured alignment (0–100) with a symbol that changes with the level, so it reads without colour.
struct AlignmentBadge: View {
    let value: Double

    var body: some View {
        let tone = Tone.level(value, good: 70, warning: 45)
        Label("\(Int(value))", systemImage: tone == .good ? "checkmark.shield.fill" : (tone == .warning ? "shield.lefthalf.filled" : "exclamationmark.shield.fill"))
            .font(.caption.monospacedDigit())
            .foregroundStyle(tone == .warning ? Color.yellow : tone.color)
            .help("Measured alignment, 0–100")
            .accessibilityLabel("Measured alignment \(Int(value)) of 100, \(tone == .good ? "healthy" : (tone == .warning ? "drifting" : "unsafe"))")
    }
}

// MARK: - Coming up

/// Dated things ahead, soonest first, with how long to go.
private struct ComingUpCard: View {
    @Environment(GameStore.self) private var store
    let items: [Agenda.Upcoming]
    let today: Date
    @State private var showAll = false

    var body: some View {
        let shown = showAll ? items : Array(items.prefix(7))
        Card {
            CardHeader(title: "Coming up", symbol: "calendar.badge.clock", subtitle: "The next six months, soonest first") {
                Button("Rival Watch") { store.open(.rivalWatch) }.buttonStyle(.link)
            }
            if items.isEmpty {
                NextStep("Nothing dated in the next six months. Start a training run and its finish date shows up here.",
                         action: "Open Model Lab", screen: .lab)
            }
            ForEach(shown) { u in UpcomingRow(item: u, today: today) }
            if items.count > 7 {
                Button(showAll ? "Show fewer" : "Show all \(items.count)") { showAll.toggle() }
                    .buttonStyle(.link)
            }
        }
    }
}

private struct UpcomingRow: View {
    @Environment(GameStore.self) private var store
    let item: Agenda.Upcoming
    let today: Date

    var body: some View {
        let days = GameCalendar.daysBetween(today, item.date)
        let tint = Self.color(item.tone)
        Button {
            if let lab = item.labID { store.openLab(lab) } else { store.open(item.screen) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.symbol)
                    .foregroundStyle(tint)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(when(days))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(days <= 7 && item.tone != .good ? tint : Color.primary)
                    Text(item.window ?? item.date.gameShort)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .fixedSize()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(item.labID != nil ? "Open the lab's profile" : "Open \(item.screen.title)")
    }

    /// Rival launches are rumours: "in about 3 weeks" style, never an exact day.
    private func when(_ days: Int) -> String {
        guard item.window != nil else { return Agenda.daysText(days) }
        return days <= 1 ? "any day now" : "about \(Agenda.daysText(days))"
    }

    static func color(_ t: Agenda.Upcoming.Tone) -> Color {
        switch t {
        case .good: .green
        case .bad: .red
        case .warning: .orange
        case .neutral: .accentColor
        }
    }
}

// MARK: - Since last month

private struct SinceLastMonthCard: View {
    let state: GameState

    var body: some View {
        if let b = state.briefings.first, GameCalendar.daysBetween(b.month, state.date) <= 62 {
            BriefingCard(briefing: b)
        } else {
            Card {
                CardHeader("Since last month", symbol: "doc.text.magnifyingglass", subtitle: "The monthly briefing")
                Text("Your first briefing arrives on the 1st: what moved revenue and why, what rivals did and what to do next.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Money and work in progress

private struct RevenueCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        ChartCard(title: "Revenue vs. costs", symbol: "chart.bar.fill", subtitle: "Monthly; the dashed red line is costs", height: 220) {
            RevenueChart(history: Array(state.history.suffix(24)) + [state.month], week: RevenueChart.week(state.date))
                .equatable()
        } trailing: {
            Button("Finance") { store.open(.finance) }.buttonStyle(.link)
        }
    }
}

struct ActiveRunsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let runs = state.runs.filter { $0.status == .running || $0.status == .postTraining || $0.status == .paused }
        let b = store.derived.bonuses
        Card {
            CardHeader(title: "Training runs", symbol: "chart.line.downtrend.xyaxis") {
                Button("Training Runs") { store.open(.training) }.buttonStyle(.link)
            }
            if runs.isEmpty {
                NextStep("No runs in progress. Design one in the Model Lab; its forecast shows what you'd get before you spend.",
                         action: "Open Model Lab", screen: .lab)
            }
            ForEach(runs) { run in
                let post = run.status == .postTraining
                let share = post ? (run.postTrainFlops > 0 ? run.postTrainDone / run.postTrainFlops : 0) : run.progress
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(run.design.name).font(.callout.weight(.semibold))
                        if run.status == .paused {
                            Pill(run.status.rawValue, tone: .warning)
                        } else {
                            Pill(text: run.status.rawValue, color: post ? .purple : .blue)
                        }
                        Spacer()
                        Text(eta(run, b)).font(.caption).foregroundStyle(.secondary)
                        Text(Fmt.pct(share, decimals: 0)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Meter(value: share, tint: post ? .purple : .blue)
                }
            }
        }
    }

    private func eta(_ run: TrainingRun, _ b: ResearchBonuses) -> String {
        if run.status == .paused { return "waiting for you" }
        guard let date = Agenda.runETA(run, state, bonuses: b) else { return "" }
        return "done \(Agenda.daysText(GameCalendar.daysBetween(state.date, date)))"
    }
}

struct RSIStatusCard: View {
    @Environment(GameStore.self) private var store
    let runs: [RSIRun]

    var body: some View {
        Card {
            CardHeader(title: "Self-improvement", symbol: "arrow.triangle.2.circlepath") {
                HelpButton(term: .alignmentDrift)
                Button("Lab") { store.open(.rsi) }.buttonStyle(.link)
            }
            ForEach(runs) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(r.name).font(.callout.weight(.semibold))
                        Pill(text: "g\(r.generation)", color: .purple)
                        Spacer()
                        let a = r.alignmentMeasured
                        AlignmentBadge(value: a)
                    }
                    Meter(value: r.genProgress, tint: .purple, height: 6)
                }
            }
        }
    }
}

struct SwarmStatusCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let s = state
        Card {
            CardHeader(title: "Agent swarms", symbol: "person.3.sequence.fill") {
                HelpButton(term: .swarms)
                Button("Swarms") { store.open(.swarms) }.buttonStyle(.link)
            }
            ForEach(s.swarms) { sw in
                HStack {
                    Image(systemName: sw.mission.symbol).foregroundStyle(.secondary).frame(width: 18)
                    Text(sw.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text("\(Fmt.count(sw.active)) agents").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    let a = sw.alignmentMeasured
                    AlignmentBadge(value: a)
                }
            }
            if s.xenoInsightToday > 0 || s.xenoInsight > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Alien architecture #\(s.alienArchs.count + 1): \(Fmt.pct(s.xenoInsight / Xeno.insightNeeded(s), decimals: 0))").font(.caption.weight(.semibold))
                    Meter(value: s.xenoInsight / Xeno.insightNeeded(s), tint: .purple, height: 6)
                }
            }
        }
    }
}

/// The numbers behind the business at a glance (collapsible).
private struct BusinessCard: View {
    let state: GameState
    let derived: Derived

    var body: some View {
        let s = state
        let d = derived
        let last = s.history.last
        let profit = last?.profit ?? 0
        let best = d.board.filter(\.isPlayer).max { $0.index < $1.index }
        Collapsible("Business at a glance", symbol: "square.grid.2x2.fill", subtitle: "Users, tokens, seats and the rest", key: "business", open: true) {
            KPIRow(minWidth: 190) {
                StatTile(title: "Last month's profit", value: signedMoney(profit), detail: last.map { "Revenue \(Fmt.money($0.revenue))" } ?? "No month closed yet",
                         symbol: profit >= 0 ? "arrow.up.forward" : "arrow.down.forward", tint: profit >= 0 ? Theme.good : Theme.warning)
                StatTile(title: "Chat users", value: Fmt.count(s.consumerUsers), detail: "\(Fmt.count(s.paidUsers)) paying", symbol: "person.2.fill", tint: .pink)
                StatTile(title: "API tokens a day", value: Fmt.count(s.models.reduce(0) { $0 + $1.servedTokensDay }),
                         detail: "Reliability \(Fmt.pct(s.reliability, decimals: 0))", symbol: "bolt.horizontal.fill", tint: .teal)
                StatTile(title: "Best model", value: best.map { Fmt.score($0.index) } ?? "—",
                         detail: best.map { "\($0.model) · capability \(Int($0.capability.rounded()))\($0.released ? "" : " (unreleased)")" } ?? "Train one in the Model Lab",
                         symbol: "trophy.fill", tint: .orange)
                StatTile(title: "Agent seats", value: Fmt.count(s.agentSeats),
                         detail: s.agentModelID == nil ? "Launch an agent product in Market" : "\(Fmt.pct(s.agentShare, decimals: 1)) share · \(Fmt.money(s.agentPrice)) a seat",
                         symbol: "person.badge.key.fill", tint: .indigo)
                if !s.swarms.isEmpty {
                    StatTile(title: "Agent swarms", value: Fmt.count(s.swarms.filter { !$0.paused }.reduce(0) { $0 + $1.active }),
                             detail: "\(Fmt.count(s.swarmRPToday)) RP a day · \(Fmt.money(s.laborToday * 30.4)) a month of labor", symbol: "person.3.sequence.fill", tint: .purple)
                }
                if !s.leases.isEmpty || !s.chipLines.isEmpty {
                    StatTile(title: "Compute sales", value: "\(Fmt.money((s.leaseRevenueToday + s.chipLines.reduce(0) { $0 + $1.unitsToday * $1.price }) * 365))/yr",
                             detail: "Leasing and chip sales", symbol: "shippingbox.fill", tint: .green)
                }
                StatTile(title: "Interest on cash", value: "\(Fmt.trim(Treasury.yieldRate(s), 2))%", detail: "\(Fmt.money(s.month.interestIncome)) this month",
                         symbol: "percent", tint: .mint)
            }
        }
    }
}

// MARK: - The race

/// Each leading lab's best released capability over three years, and yours: the leaderboard's race chart.
private struct RaceCard: View {
    @Environment(GameStore.self) private var store
    let labs: [Leaderboard.LabRow]
    let state: GameState

    var body: some View {
        let race = Leaderboard.race(labs, today: state.date, months: 36, top: 4)
        let colors = Self.colors(labs, state)
        Card {
            CardHeader(title: "The race", symbol: "flag.checkered", subtitle: "Best capability of the leading labs and you, over three years") {
                HStack(spacing: 10) {
                    HelpButton(term: .capability)
                    Button("Leaderboard") { store.open(.leaderboard) }.buttonStyle(.link)
                }
            }
            RaceChart(points: race.points, colors: colors)
                .equatable()
                .frame(height: 210)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 4) {
                ForEach(race.series) { sr in
                    LegendItem(color: colors[sr.id] ?? Color.gray, label: sr.isPlayer ? "\(sr.lab) (you)" : sr.lab, value: "\(Int(sr.capability.rounded()))")
                }
            }
        }
    }

    static func colors(_ labs: [Leaderboard.LabRow], _ s: GameState) -> [String: Color] {
        var out: [String: Color] = [:]
        for r in labs {
            out[r.labID] = r.isPlayer ? Theme.logoColor(s.logoColor) : (CompetitorCatalog.byID[r.labID].map { Theme.competitorColor($0.color) } ?? .gray)
        }
        return out
    }
}

/// The top labs by flagship (one row per lab), plus you if you're further down.
private struct TopLabsCard: View {
    @Environment(GameStore.self) private var store
    let labs: [Leaderboard.LabRow]

    var body: some View {
        let ranked = labs.filter { $0.rank > 0 }.sorted { $0.rank < $1.rank }
        let top = ranked.contains { $0.isPlayer && $0.rank > 6 } ? Array(ranked.prefix(5)) + ranked.filter(\.isPlayer) : Array(ranked.prefix(6))
        Card {
            CardHeader(title: "World leaderboard", symbol: "trophy") {
                HStack(spacing: 10) {
                    HelpButton(term: .intelligenceIndex)
                    Button("All labs") { store.open(.leaderboard) }.buttonStyle(.link)
                }
            }
            if top.isEmpty {
                Text("No lab has released a model yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(top) { r in
                Button {
                    if r.isPlayer { store.open(.leaderboard) } else { store.openLab(r.labID) }
                } label: {
                    HStack {
                        Text(verbatim: "\(r.rank)").font(.caption.monospacedDigit().weight(.bold)).frame(width: 18).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(r.lab).font(.callout.weight(r.isPlayer ? .bold : .regular))
                            Text(verbatim: "\(r.flagship.model) · capability \(Int(r.flagship.capability.rounded()))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.score(r.flagship.index)).font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(r.isPlayer ? Color.accentColor : .primary)
                            .help("Intelligence Index")
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(r.isPlayer ? "Open the leaderboard" : "Open \(r.lab)'s profile")
            }
        }
    }
}

/// Every lab's next model as the rumour mill sees it (collapsible; Coming up shows the nearest ones).
private struct RivalWatchList: View {
    @Environment(GameStore.self) private var store
    let rows: [RivalIntel.Row]

    var body: some View {
        Collapsible("Rival Watch", symbol: "binoculars.fill", subtitle: "Next launches, as the rumour mill sees them", key: "watch") {
            if rows.isEmpty {
                Text("No rival runs to watch yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(rows) { r in
                Button {
                    store.openLab(r.id)
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.competitorColor(r.color)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(r.project.name).font(.callout.weight(.semibold)).lineLimit(1)
                            Text("\(r.lab) · \(r.outlook.phase.rawValue)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(RivalIntel.windowText(r.outlook)).font(.caption.monospacedDigit())
                            Text("~\(Fmt.score(r.outlook.index))").font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(RivalWatchView.threatColor(r.threat))
                                .help("Forecast Intelligence Index: \(r.threat.rawValue.lowercased())")
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            HStack {
                HelpLink(term: .forecastBand)
                Spacer()
                Button("Open Rival Watch") { store.open(.rivalWatch) }.buttonStyle(.link)
            }
        }
    }
}

/// The benchmarks in the Intelligence Index now: the best score in the world, yours, and the saturation line.
struct BenchmarkRaceCard: View {
    @Environment(GameStore.self) private var store
    let set: [Benchmark]
    let board: [Leaderboard.Entry]
    let saturated: [String: Date]

    var body: some View {
        Collapsible("Benchmark race", symbol: "flame.fill", subtitle: "The tests in the Intelligence Index now", key: "benchmarks") {
            let released = board.filter(\.released)
            let mine = board.filter(\.isPlayer)
            Text("Orange: the best score in the world; blue: yours. The red tick is the saturation line: once two labs pass it, the benchmark rotates out when a successor is ready.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(set.prefix(6)) { b in
                let retiring = saturated[b.id] != nil
                let sota = released.map { $0.score(b) }.max() ?? 0
                let you = mine.map { $0.score(b) }.max()
                HStack(spacing: 8) {
                    Text(b.name).font(.caption.weight(.medium)).frame(width: 150, alignment: .leading).lineLimit(1)
                        .help(retiring ? "Saturated: leaves the index when a successor is ready." : b.about)
                    ZStack(alignment: .leading) {
                        Meter(value: sota / 100, tint: retiring ? .green : .orange, height: 7)
                        if let you { Meter(value: you / 100, tint: .accentColor, height: 3).padding(.top, 9) }
                        GeometryReader { g in
                            Rectangle().fill(.red.opacity(0.75)).frame(width: 2, height: 12).offset(x: g.size.width * b.saturation / 100 - 1, y: -2)
                        }
                    }
                    .frame(height: 12)
                    Text(Fmt.score(sota)).font(.caption.monospacedDigit()).frame(width: 34, alignment: .trailing)
                }
            }
            HStack {
                HelpLink(term: .saturation)
                Spacer()
                Button("All benchmarks") { store.open(.benchmarks) }.buttonStyle(.link)
            }
        }
    }
}

private struct LatestNewsCard: View {
    @Environment(GameStore.self) private var store
    let news: [NewsItem]

    var body: some View {
        Collapsible("Latest news", symbol: "newspaper", subtitle: "The newest headlines", key: "news", open: true) {
            if news.isEmpty {
                Text("News appears as the world moves.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(news) { n in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: n.category.symbol)
                        .foregroundStyle(Theme.categoryColor(n.category))
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(n.title).font(.callout.weight(.medium)).lineLimit(2)
                        Text(n.date.gameShort).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            Button("All news") { store.open(.news) }.buttonStyle(.link)
        }
    }
}

/// A card whose body folds away; the choice is remembered.
private struct Collapsible<Content: View>: View {
    let title: String
    let symbol: String
    let subtitle: String?
    @AppStorage private var open: Bool
    @ViewBuilder var content: Content

    init(_ title: String, symbol: String, subtitle: String? = nil, key: String, open: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.subtitle = subtitle
        _open = AppStorage(wrappedValue: open, "dashboard.open.\(key)")
        self.content = content()
    }

    var body: some View {
        Card {
            Button {
                withAnimation(.snappy) { open.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    CardHeader(title, symbol: symbol, subtitle: subtitle)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(open ? "shown" : "hidden")")
            .accessibilityHint(open ? "Hides this card's contents" : "Shows this card's contents")
            if open { content }
        }
    }
}

// MARK: - Charts and getting started

/// Redraws when a month closes or a new game week starts, not on every tick: Charts layout is expensive.
struct RevenueChart: View, Equatable {
    let history: [MonthRecord]
    /// The game week this snapshot of the current month was taken in.
    let week: Int

    static func week(_ date: Date) -> Int { Int(date.timeIntervalSince1970 / 86_400) / 7 }

    static func == (a: RevenueChart, b: RevenueChart) -> Bool {
        a.week == b.week && a.history.count == b.history.count && a.history.first?.month == b.history.first?.month
            && a.history.last?.month == b.history.last?.month
    }

    struct Bar: Identifiable {
        var id: String { "\(month.timeIntervalSince1970)-\(kind)" }
        let month: Date
        let kind: String
        let value: Double
    }

    var body: some View {
        let bars = history.flatMap { m -> [Bar] in
            [Bar(month: m.month, kind: "API", value: m.revAPI),
             Bar(month: m.month, kind: "Consumer", value: m.revConsumer),
             Bar(month: m.month, kind: "Enterprise", value: m.revEnterprise),
             Bar(month: m.month, kind: "Product lines", value: m.revOther),
             Bar(month: m.month, kind: "Agents", value: m.revAgents),
             Bar(month: m.month, kind: "Compute & chips", value: m.revCloud + m.revChips),
             Bar(month: m.month, kind: "Labor & licensing", value: m.revLabor + m.revLicensing)]
        }
        if history.allSatisfy({ $0.revenue == 0 && $0.opex == 0 }) {
            EmptyStateView(symbol: "chart.bar", title: "No numbers yet", message: "Revenue and costs appear here as the weeks go by.")
        } else {
            Chart {
                ForEach(bars) { b in
                    BarMark(x: .value("Month", b.month, unit: .month), y: .value("Revenue", b.value))
                        .foregroundStyle(by: .value("Segment", b.kind))
                }
                ForEach(history) { m in
                    LineMark(x: .value("Month", m.month, unit: .month), y: .value("Costs", m.opex + m.costInterest))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .interpolationMethod(.monotone)
                }
            }
            .chartForegroundStyleScale(["API": Color.teal, "Consumer": Color.pink, "Enterprise": Color.indigo, "Product lines": Color.mint,
                                        "Agents": Color.orange, "Compute & chips": Color.green, "Labor & licensing": Color.purple])
            .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.money(d, decimals: 0)) } } } }
            .chartLegend(position: .bottom, alignment: .leading)
        }
    }
}

/// The era's opening checklist until it's done.
struct GettingStarted: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    /// The era's steps, when the caller already has them.
    var steps: [EraGuide.Step]? = nil

    var body: some View {
        let steps = steps ?? EraGuide.steps(state)
        let remaining = steps.filter { !$0.done }
        if !remaining.isEmpty {
            Card {
                CardHeader(title: "Next steps", symbol: "checklist", subtitle: "\(steps.count - remaining.count) of \(steps.count) done") {
                    Button("Era briefing") { store.showEraIntro = true }.buttonStyle(.link)
                }
                ForEach(steps) { step in
                    Button {
                        store.open(step.screen)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.done ? .green : .secondary)
                                .font(.title3)
                                .accessibilityLabel(step.done ? "Done" : "To do")
                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.title).font(.callout.weight(.semibold)).strikethrough(step.done)
                                Text(step.detail).font(.caption).foregroundStyle(.secondary)
                                if FoundingKit.questsActive(state), !step.done, let r = FoundingKit.questReward(step.key) {
                                    Text("Reward: \(r.text)").font(.caption.weight(.semibold)).foregroundStyle(.green)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
