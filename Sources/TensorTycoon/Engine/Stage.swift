import Foundation

/// 3.9: launch events and developer days. You book a show weeks ahead (a livestream, a press event or an arena), build
/// its run of show from up to four segments, rehearse the risky ones, and on the day it plays out beat by beat:
///  • A launch event puts your best unreleased model live on stage (released with the pricing you reveal), or makes
///    the big moment of one you released since booking. With nothing to show, a week before you choose: postpone,
///    a vision keynote, or cancel.
///  • A developer day grows the developer ecosystem: tools, credits, an app store and a community hackathon.
/// Anticipation lifts hype while the show is on the calendar; the score moves hype, brand and the people who matter,
/// and the launch spends the hype (Hype.spend). Live demos fail at odds you can read and rehearse down.
enum Stage {
    static let maxSegments = 4
    static let maxRehearsals = 3
    static let leadDays = [14, 21, 30, 45]

    // MARK: Costs and odds

    static func cost(_ s: GameState, _ f: StageFormat) -> Double { (GameState.keynoteCost(s) * f.costShare / 1_000).rounded() * 1_000 }
    static func cameoFee(_ s: GameState) -> Double { (GameState.keynoteCost(s) * 0.3 / 1_000).rounded() * 1_000 }
    static func creditsCost(_ s: GameState) -> Double { (clamp(s.valuation * 0.0004, 250_000, 200_000_000) / 1_000).rounded() * 1_000 }

    /// The model a launch event would put on stage today: your best unreleased model, else one released since booking.
    static func showModel(_ s: GameState, _ e: StageEvent) -> (model: AIModel, release: Bool)? {
        if e.kind == .devDay { return s.releasedModels.filter(\.api).max { $0.index < $1.index }.map { ($0, false) } }
        if let id = e.modelID, let m = s.models.first(where: { $0.id == id && $0.released && !$0.retired }) { return (m, false) }
        if let m = s.models.filter({ !$0.released && !$0.retired }).max(by: { $0.index < $1.index }) { return (m, true) }
        if let m = s.releasedModels.filter({ ($0.releaseDate.map { GameCalendar.daysBetween($0, s.date) } ?? 999) <= 21 }).max(by: { $0.index < $1.index }) { return (m, false) }
        return nil
    }

    /// Chance a live demo goes wrong: shaky serving, a model short of the frontier and a low safety score add risk;
    /// each rehearsal takes a third of it away. An agent demo is half again as risky.
    static func demoRisk(_ s: GameState, _ e: StageEvent, agent: Bool) -> Double {
        let m = showModel(s, e)?.model
        var r = 0.26 + 0.6 * (1 - clamp(s.reliability, 0, 1))
        if let m {
            r += clamp((Macro.frontier(s.year) - m.c) * 0.08, -0.06, 0.12)
            r -= (m.safety - 50) / 600
        } else {
            r += 0.15
        }
        if agent { r *= 1.5 }
        r *= pow(0.67, Double(e.rehearsals))
        return clamp(r, 0.04, agent ? 0.75 : 0.6)
    }

    static func segmentBlocker(_ s: GameState, _ seg: StageSegment) -> String? {
        if seg == .agentDemo && s.year < 2024 { return "Agents that act on their own arrive around 2024." }
        if seg == .store && s.year < 2023 { return "App stores for AI models arrive around 2023." }
        return nil
    }

    // MARK: Booking

    static func blocker(_ s: GameState, kind: StageKind, format: StageFormat) -> String? {
        if let e = s.hype.event { return "Your \(e.kind.title.lowercased()) is on \(e.date.gameShort). One show at a time." }
        switch kind {
        case .launch:
            if s.models.isEmpty && s.runs.isEmpty { return "Start training a model first: there would be nothing to launch." }
        case .devDay:
            if !s.releasedModels.contains(where: \.api) { return "Release a model on your API first: developers need something to build on." }
            if let last = s.hype.lastDevDay, GameCalendar.daysBetween(last, s.date) < Hype.devDayCooldown {
                return "One developer day a year: next from \(GameCalendar.addDays(last, Hype.devDayCooldown).gameShort)."
            }
        }
        let c = cost(s, format)
        if c > s.cash { return "Booking costs \(Fmt.money(c)); you have \(Fmt.money(s.cash))." }
        return nil
    }

    static func announce(_ s: inout GameState, kind: StageKind, format: StageFormat, days: Int) -> String? {
        if let b = blocker(s, kind: kind, format: format) { return b }
        let c = cost(s, format)
        s.cash -= c
        s.month.costMarketing += c
        let date = GameCalendar.addDays(s.date, max(7, min(60, days)))
        var e = StageEvent(kind: kind, format: format, announced: s.date, date: date)
        e.cost = c
        e.segments = kind == .launch ? [.benchmarks, .liveDemo, .pricing] : [.sdk, .hackathon, .liveDemo]
        s.hype.event = e
        Hype.add(&s, 4 * format.reach, "\(kind.title) announced for \(date.gameShort)")
        let what = kind == .launch ? "a launch event" : "\(s.companyName) Developer Day"
        Sim.news(&s, "You announce \(what) for \(date.gameShort)", "\(format.title), \(Fmt.money(c)). Anticipation builds until the day; plan the run of show on the Spotlight page.",
                 .company, image: ImagePicker.pick(.events, seed: "stage|\(s.companyName)"))
        Viral.companyPost(&s, kind == .launch ? "\(date.gameShort). You'll want to watch this one." : "\(s.companyName) Developer Day, \(date.gameShort). Bring your laptops.",
                          key: "announce|\(RivalIntel.dayIndex(s.date))", importance: 0.5)
        return nil
    }

    static func setSegments(_ s: inout GameState, _ segs: [StageSegment]) -> String? {
        guard let e = s.hype.event else { return "No show on the calendar." }
        var out: [StageSegment] = []
        for g in segs where !out.contains(g) && StageSegment.options(e.kind).contains(g) {
            if let b = segmentBlocker(s, g) { return b }
            out.append(g)
        }
        if out.count > maxSegments { return "A show has room for \(maxSegments) segments." }
        s.hype.event?.segments = out
        return nil
    }

    static func rehearsalBlocker(_ s: GameState) -> String? {
        guard let e = s.hype.event else { return "No show on the calendar." }
        if e.rehearsals >= maxRehearsals { return "Three rehearsals is all the team will sit through." }
        if !e.segments.contains(.liveDemo) && !e.segments.contains(.agentDemo) { return "Nothing live to rehearse." }
        return nil
    }

    /// Three days of the research team's time in exchange for a third off the demo risk.
    static func rehearse(_ s: inout GameState) -> String? {
        if let b = rehearsalBlocker(s) { return b }
        let rp = s.rpToday * 3
        if let head = s.researchQueue.first { s.researchProgress[head] = max(0, (s.researchProgress[head] ?? 0) - rp) }
        s.hype.event?.rehearsals += 1
        return nil
    }

    static func postpone(_ s: inout GameState, days: Int = 21, quiet: Bool = false) -> String? {
        guard let e = s.hype.event else { return "No show on the calendar." }
        if e.postponed >= 2 { return "You've postponed twice already. Hold it or cancel it." }
        s.hype.event?.date = GameCalendar.addDays(e.date, days)
        s.hype.event?.postponed += 1
        Hype.add(&s, -6, "\(e.kind.title) postponed")
        if !quiet {
            Sim.news(&s, "Your \(e.kind.title.lowercased()) moves to \(GameCalendar.addDays(e.date, days).gameShort)", "\"We want it to be ready.\" The crowd shrugs; hype −6.", .company)
        }
        return nil
    }

    static func cancel(_ s: inout GameState) -> String? {
        guard let e = s.hype.event else { return "No show on the calendar." }
        s.hype.event = nil
        Hype.add(&s, -15, "\(e.kind.title) cancelled")
        if GameCalendar.daysBetween(s.date, e.date) <= 14 { Fun.brand(&s, -1) }
        Sim.news(&s, "You cancel your \(e.kind.title.lowercased())", "The booking (\(Fmt.money(e.cost))) is gone, and so is some goodwill: hype −15.", .company, good: false)
        return nil
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        guard let e = s.hype.event else { return }
        let left = GameCalendar.daysBetween(s.date, e.date)
        if left == 7 && e.kind == .launch && e.warnedFor != e.date && showModel(s, e) == nil {
            s.hype.event?.warnedFor = e.date
            let can = e.postponed < 2
            var options: [DecisionOption] = []
            if can { options.append(DecisionOption(label: "Postpone three weeks", detail: "Hype −6. Time for a run to finish.")) }
            options += [DecisionOption(label: "Go ahead with a vision keynote", detail: "Talk about the future with nothing to ship. Hard to score well; \"where's the model?\" is the top reply."),
                        DecisionOption(label: "Cancel it", detail: "Hype −15, brand −1. The booking is lost.")]
            Events.addDecision(&s, kind: Hype.noShowKind, title: "Nothing to launch at your event on \(e.date.gameShort)",
                               body: "No model is ready to go on stage. The event is a week away and the press has the date.",
                               image: ImagePicker.pick(.events, seed: "noshow"), options: options, ref: can ? "p" : "")
        }
        if left <= 0 { hold(&s, e) }
    }

    static func resolveNoShow(_ s: inout GameState, _ d: Decision, option: Int) {
        let o = d.ref == "p" ? option : option + 1
        switch o {
        case 0: _ = postpone(&s)
        case 1: Sim.news(&s, "The show goes on", "A vision keynote it is. The team rewrites the slides.", .company)
        default: _ = cancel(&s)
        }
    }

    // MARK: The show

    struct Beat {
        var text: String
        var appeal: Double
        var segment: StageSegment?
    }

    static func hold(_ s: inout GameState, _ e: StageEvent) {
        s.hype.event = nil
        s.decisions.removeAll { $0.kind == Hype.noShowKind }   // the day has come: the question is moot
        let key = "show|\(RivalIntel.dayIndex(e.date))|\(e.kind.rawValue)"
        func r(_ k: String) -> Double { Hype.roll(s, "\(key)|\(k)") }
        func pick(_ list: [String], _ k: String) -> String { list[Int(r(k) * Double(list.count)) % list.count] }
        let found = showModel(s, e)
        let m = found?.model
        let name = m?.name ?? ""
        let rank = m.map { Leaderboard.rank(of: $0.id, in: s) } ?? 99
        let previousBest = s.releasedModels.filter { $0.id != m?.id }.map(\.index).max()
        let vision = e.kind == .launch && m == nil
        let before = s.hype.meter
        var beats: [Beat] = []
        var demo = ""
        var promised = ""   // set after the launch, so this launch doesn't keep its own promise
        let venue = e.format == .arena ? "five thousand people" : (e.format == .pressEvent ? "three hundred journalists" : "the camera")
        beats.append(Beat(text: e.kind == .launch
                          ? "Lights down. \(s.founderName) walks out to \(venue)\(vision ? " with no model to show" : ""). \(before >= 60 ? "The room is loud before a word is said." : (before >= 30 ? "A curious crowd." : "Polite applause."))"
                          : "\(s.companyName) Developer Day opens. \(s.founderName) thanks \(Fmt.count(max(500, s.marketMoves.devEcosystem * 400))) developers in the room and online.",
                          appeal: 0, segment: nil))
        for seg in e.segments {
            switch seg {
            case .benchmarks:
                if let m, !vision {
                    let a: Double = rank == 1 ? 16 : (rank <= 3 ? 10 : (rank <= 5 ? 3 : -6))
                    let text = rank == 1 ? "The charts: \(m.name) is #1 on the Intelligence Index (\(Fmt.score(m.index))). The bar chart gets its own cheer."
                        : (rank <= 5 ? "The charts: \(m.name) lands #\(rank) at \(Fmt.score(m.index)). Solid, and the slide says so in big letters."
                                     : "The charts: #\(rank). Someone in the press row notices the y-axis doesn't start at zero. Chart crimes trend within minutes.")
                    beats.append(Beat(text: text, appeal: a, segment: seg))
                } else {
                    beats.append(Beat(text: "Charts of last year's results. Phones come out.", appeal: -4, segment: seg))
                }
            case .liveDemo, .agentDemo:
                let agent = seg == .agentDemo
                let risk = demoRisk(s, e, agent: agent)
                let who = m?.name ?? "A prototype"
                if r("demo|\(seg.rawValue)") < risk {
                    demo = "fail"
                    beats.append(Beat(text: "Live \(agent ? "agent " : "")demo: \(who) \(pick(agent ? HypeCatalog.agentFails : HypeCatalog.demoFails, "fail|\(seg.rawValue)")). The clip is online before the next slide.",
                                      appeal: agent ? -18 : -14, segment: seg))
                } else {
                    if demo.isEmpty { demo = "ok" }
                    beats.append(Beat(text: "Live \(agent ? "agent " : "")demo: \(who) \(pick(agent ? HypeCatalog.agentDemos : HypeCatalog.demos, "ok|\(seg.rawValue)")). First try. The room erupts.",
                                      appeal: (agent ? 28 : 20) * (vision ? 0.6 : 1), segment: seg))
                }
            case .pricing:
                guard let m, !vision else {
                    beats.append(Beat(text: "\"Pricing later.\" Nobody writes it down.", appeal: -2, segment: seg))
                    continue
                }
                switch e.pricing {
                case .undercut: beats.append(Beat(text: "The price: a quarter under the going rate. The developers in the room stand up. Somewhere a rival schedules an emergency meeting.", appeal: 14, segment: seg))
                case .match: beats.append(Beat(text: "The price: the going rate for a model like \(m.name). Fair; nobody tweets about it.", appeal: 4, segment: seg))
                case .premium: beats.append(Beat(text: "The price: a quarter above the going rate. A murmur, then a joke about luxury goods. Investors nod.", appeal: -3, segment: seg))
                }
            case .safety:
                s.hype.calmUntil = GameCalendar.addDays(s.date, 90)
                beats.append(Beat(text: "The safety segment: red-team results and what the model refuses to do. Quiet in the hall; the public and researchers take note.", appeal: 3, segment: seg))
            case .partner:
                if let d = s.deals.filter(\.active).max(by: { $0.monthly < $1.monthly }) {
                    beats.append(Beat(text: "\(d.client)'s chief executive on stage: \"\(d.title.prefix(1).uppercased() + d.title.dropFirst()) with \(s.companyName) changed how we work.\" Investors love it.", appeal: 8, segment: seg))
                } else {
                    beats.append(Beat(text: "A friendly startup founder says kind things. Nobody knows who they are.", appeal: 3, segment: seg))
                }
            case .cameo:
                let fee = cameoFee(s)
                s.cash -= fee
                s.month.costMarketing += fee
                let who = pick(HypeCatalog.cameos, "cameo")
                if r("cameo") < 0.75 {
                    beats.append(Beat(text: "Surprise guest: \(who) asks \(m?.name ?? "the model") to write something about \(HQ.city(s).name). It's genuinely funny. Fee: \(Fmt.money(fee)).", appeal: 12, segment: seg))
                } else {
                    beats.append(Beat(text: "Surprise guest: \(who), reading a script about \"the future of intelligence\". Visible cringe. Fee: \(Fmt.money(fee)).", appeal: -6, segment: seg))
                }
            case .oneMoreThing:
                let next = nextName(s, m)
                promised = next
                beats.append(Beat(text: "\"One more thing.\" A single slide: \(next). \"Training now.\" The loudest noise of the day.", appeal: 15, segment: seg))
            case .sdk:
                s.marketMoves.devEcosystem = min(100, s.marketMoves.devEcosystem + 5 * e.format.reach)
                Stakeholders.move(&s, ["developers": 1.5], "Agent tools at \(s.companyName) Developer Day")
                beats.append(Beat(text: "An agent SDK, function calling, evals in the console. Laptops open across the hall.", appeal: 10, segment: seg))
            case .credits:
                let c = creditsCost(s)
                s.cash -= c
                s.month.costMarketing += c
                s.marketMoves.devEcosystem = min(100, s.marketMoves.devEcosystem + 9 * e.format.reach)
                Stakeholders.move(&s, ["developers": 2], "Free credits for startups at \(s.companyName) Developer Day")
                beats.append(Beat(text: "\(Fmt.money(c)) in free credits for startups. The biggest cheer of the day goes to free compute.", appeal: 12, segment: seg))
            case .store:
                s.hype.storeUntil = GameCalendar.addDays(s.date, 120)
                if r("store") < 0.2 {
                    beats.append(Beat(text: "An app store for apps built on your models. The first demo app is a knock-off of a famous game. Awkward laughter.", appeal: -2, segment: seg))
                } else {
                    beats.append(Beat(text: "An app store for apps built on your models, with revenue sharing. Developers start counting.", appeal: 10, segment: seg))
                }
            case .hackathon:
                Stakeholders.move(&s, ["developers": 1], "A community hackathon at \(s.companyName) Developer Day")
                beats.append(Beat(text: "The community hackathon results: a thousand outside developers, forty finished demos, one standing ovation for a blind user's navigation app.", appeal: 6, segment: seg))
            }
        }
        // Order matters: close on your best moment; don't open on your worst.
        let segs = beats.filter { $0.segment != nil }
        var bonus = 0.0
        if let last = segs.last, let top = segs.map(\.appeal).max(), segs.count >= 2, last.appeal == top, top > 0 {
            bonus += 6
            beats.append(Beat(text: "Closing on the high point. \(e.kind == .launch && !vision ? "\(name) is live as the lights come up." : "The hall empties buzzing.")", appeal: 0, segment: nil))
        } else if let first = segs.first, first.appeal < 0 {
            bonus -= 3
        }
        var score = 30 + segs.reduce(0) { $0 + $1.appeal } + bonus + (before - 40) * 0.1
        if vision { score = min(score - 8, 62) }
        if e.segments.isEmpty { score = min(score, 30) }
        score = clamp(score.rounded(), 0, 100)
        let grade = score >= 85 ? "Standing ovation" : (score >= 70 ? "A strong show" : (score >= 50 ? "A solid show" : (score >= 35 ? "A flat show" : "A disaster")))
        beats.append(Beat(text: "\(grade). \(score >= 70 ? "The replay trends for days." : (score >= 50 ? "Good coverage, no surprises." : "The reviews are kinder to the snacks."))", appeal: 0, segment: nil))
        // What it does.
        let reach = e.format.reach
        Hype.add(&s, (score - 48) * 0.45 * reach, "\(e.kind == .launch ? "Launch event" : "Developer day"): \(grade.lowercased())")
        if vision {
            Hype.add(&s, -12, "\"Where's the model?\"")
            Stakeholders.move(&s, ["investors": -1], "A launch event with nothing to launch")
        }
        Fun.brand(&s, (score - 50) / 15 * reach)
        Stakeholders.move(&s, ["public": (score - 50) / 30 * reach, "investors": e.segments.contains(.partner) ? 1.5 : 0.3,
                               "researchers": e.segments.contains(.safety) ? 0.5 : 0], "\(s.companyName)'s \(e.kind.title.lowercased()) (\(Int(score))/100)")
        if e.segments.contains(.safety) { Stakeholders.move(&s, ["public": 1], "A safety segment on stage") }
        if e.kind == .devDay {
            s.hype.lastDevDay = s.date
            s.marketMoves.devEcosystem = min(100, s.marketMoves.devEcosystem + max(0, score - 40) / 10)
        }
        let viewers = audience(s, e, before: before)
        var show = StageShow(kind: e.kind, format: e.format, date: s.date,
                             title: e.kind == .launch ? (vision ? "\(s.companyName) keynote" : "Introducing \(name)") : "\(s.companyName) Developer Day \(s.date.ym.year)",
                             model: vision ? "" : name, score: score, viewers: viewers, hypeBefore: (before * 10).rounded() / 10, hypeAfter: 0)
        var clock = e.kind == .launch ? 600 : 570
        for b in beats {
            show.beats.append(ShowBeat(clock: "\(clock / 60):\(clock % 60 < 10 ? "0" : "")\(clock % 60)", text: b.text, tone: clamp(b.appeal / 20, -1, 1), segment: b.segment?.rawValue ?? ""))
            clock += 5 + Int(r("clock|\(show.beats.count)") * 11)
        }
        show.demo = demo
        show.headline = "\(show.title): \(grade.lowercased()) (\(Int(score))/100)"
        s.hype.shows.insert(show, at: 0)
        if s.hype.shows.count > 12 { s.hype.shows.removeLast(s.hype.shows.count - 12) }
        Sim.news(&s, show.headline, "\(Fmt.count(viewers)) watched. \(beats.dropFirst().first?.text ?? "")", .company,
                 image: ImagePicker.pick(.events, seed: show.title), important: score >= 80 || score < 35, good: score >= 50)
        if score >= 80 {
            Alerts.raise(&s, .milestone, key: "show|\(key)", title: grade, body: "\(show.title): \(Int(score))/100, \(Fmt.count(viewers)) watched.", screen: .events, celebrate: true, cooldown: 0)
        }
        showChatter(&s, show, key: key, demoFailed: demo == "fail", vision: vision)
        // The model goes live (Hype.launched spends the hype with the show's score), or the show was its moment.
        if let found, e.kind == .launch {
            if found.release {
                var plan = LaunchPlan()
                if e.segments.contains(.pricing) { plan.pricing = e.pricing }
                if let err = s.launch(found.model.id, plan: plan) {
                    Sim.news(&s, "\(name) couldn't go live on stage", err, .company, good: false)
                }
            } else if e.modelID == found.model.id {
                Hype.spend(&s, found.model, rank: rank, previousBest: previousBest)
            }
        }
        if !promised.isEmpty {
            s.hype.promise = GameCalendar.addDays(s.date, 150)
            s.hype.promiseModel = promised
            Hype.add(&s, 12, "\"One more thing\": \(promised)")
        }
        if let i = s.hype.shows.firstIndex(where: { $0.id == show.id }) { s.hype.shows[i].hypeAfter = (s.hype.meter * 10).rounded() / 10 }
        if e.segments.contains(.hackathon), r("hackviral") < 0.3, let best = s.releasedModels.max(by: { $0.index < $1.index }),
           let def = HypeCatalog.byID["student"] {
            Viral.fire(&s, def, model: best, key: key + "|hack")
        }
    }

    /// The model after this one, by your naming pattern (Name-3 → Name-4).
    static func nextName(_ s: GameState, _ m: AIModel?) -> String {
        if let run = s.runs.first(where: { ($0.status == .running || $0.status == .postTraining) && $0.kind != .proxy && $0.design.name != m?.name }) { return run.design.name }
        let base = m?.name ?? s.models.last?.name ?? s.companyName
        if let dash = base.lastIndex(of: "-"), let n = Int(base[base.index(after: dash)...]) { return "\(base[..<dash])-\(n + 1)" }
        return "\(base) Next"
    }

    static func audience(_ s: GameState, _ e: StageEvent, before: Double) -> Double {
        let base = 20_000 + s.consumerUsers * 0.03 + pow(clamp(s.brand, 0, 100), 2) * 300
        return (base * e.format.reach * (0.5 + before / 100) / 1_000).rounded() * 1_000
    }

    static func showChatter(_ s: inout GameState, _ show: StageShow, key: String, demoFailed: Bool, vision: Bool) {
        let posts: [(String, String, Double)]
        if demoFailed {
            posts = [("joker", "the {company} demo freezing live is the best thing I've watched all year", -0.3),
                     ("skeptic", "If it can't survive a demo, it can't survive production.", -0.5),
                     ("booster", "Live demos fail. Faked ones don't. Respect for doing it live.", 0.3)]
        } else if vision {
            posts = [("skeptic", "An hour of vision, zero models. Where's the model, {company}?", -0.5),
                     ("joker", "{company} keynote summary: the future is coming (date TBC)", -0.3)]
        } else if show.score >= 70 {
            posts = [("booster", "That {company} show. That's how you launch.", 0.8),
                     ("dev", "Watched the whole {company} keynote. Already building with it.", 0.6),
                     ("insider", "Rival labs were watching that one very closely.", 0.3)]
        } else {
            posts = [("bench", "Decent {company} show. Waiting for independent evals before getting excited.", 0),
                     ("joker", "{company} keynote: 40% charts, 40% applause breaks, 20% vibes", -0.1)]
        }
        let def = ViralDef(id: "show", positive: show.score >= 50, title: "", detail: "", hashtag: "", size: 1, year: 0, posts: posts)
        Viral.chatter(&s, def, model: show.model, key: key, views: show.viewers)
        if demoFailed, let m = s.releasedModels.max(by: { $0.index < $1.index }) ?? s.models.max(by: { $0.index < $1.index }) {
            // The fail clip is a moment of its own (no decision: it's already the story of the day).
            var moment = ViralMoment(date: s.date, kind: "demofail", title: "The \(show.title) demo fail", detail: "The clip of the demo going wrong on stage.",
                                     hashtag: "#\(Hype.tag(s.companyName))DemoFail", positive: false, views: (show.viewers * 3 / 1_000).rounded() * 1_000)
            moment.model = m.name
            moment.response = "On stage"
            s.hype.viral.insert(moment, at: 0)
        }
    }
}

// MARK: - Player actions

extension GameState {
    mutating func announceStageEvent(_ kind: StageKind, format: StageFormat, days: Int) -> String? { Stage.announce(&self, kind: kind, format: format, days: days) }
    mutating func setStageSegments(_ segs: [StageSegment]) -> String? { Stage.setSegments(&self, segs) }
    mutating func setStagePricing(_ p: PricingStance) { hype.event?.pricing = p }
    mutating func rehearseStage() -> String? { Stage.rehearse(&self) }
    mutating func postponeStage() -> String? { Stage.postpone(&self) }
    mutating func cancelStage() -> String? { Stage.cancel(&self) }
}
