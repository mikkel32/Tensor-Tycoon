import Foundation

/// 3.9: hype. A meter (0–100) of how much the world is waiting for your next thing:
///  • It rests near a level your brand sets and moves with what you do: teasers, papers and awards on the conference
///    circuit, challenge wins, hackathon hits, viral moments, and the shows you put on (Stage).
///  • A launch spends it: the model gets a day-one rush (up to +55% demand on its chat and API traffic, halving every
///    12 days) and the press reads it — unless the model falls well short of the promise, when "overhyped" costs brand.
///  • Viral moments (a meme, a clip, a backlash) arrive weekly at odds that rise with hype and users; the bad ones ask
///    how you answer, and the inbox never spends money for you.
///  • Conference prestige brings researchers to your door each month; a recruiting booth brings more.
/// Rolls are hashed (never the game's RNG) except where a candidate is made, as every hire in the game is.
enum Hype {
    static let boostHalfLife = 12.0
    static let teaserCooldown = 14
    static let devDayCooldown = 300
    static let viralUpKind = "hype_viral_up"
    static let viralDownKind = "hype_viral_down"
    static let noShowKind = "hype_noshow"

    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("hype|\(s.peopleSalt)|\(key)") }

    /// Where the meter drifts back to: a little for anyone, more for a famous lab.
    static func rest(_ s: GameState) -> Double { 6 + 0.14 * clamp(s.brand, 0, 100) }

    static func mood(_ v: Double) -> String {
        switch v {
        case ..<15: "Quiet"
        case ..<30: "Murmurs"
        case ..<50: "Buzzing"
        case ..<70: "Hyped"
        default: "Fever pitch"
        }
    }

    /// The day-one demand boost a launch today would get (before the show and the delivery check).
    static func boostNow(_ s: GameState) -> Double { 0.55 * clamp(s.hype.meter, 0, 100) / 100 }

    static func add(_ s: inout GameState, _ v: Double, _ why: String) {
        guard abs(v) >= 0.05 else { return }
        s.hype.meter = clamp(s.hype.meter + v, 0, 100)
        s.hype.drivers.insert(HypeDriver(date: s.date, amount: (v * 10).rounded() / 10, text: why), at: 0)
        if s.hype.drivers.count > 16 { s.hype.drivers.removeLast(s.hype.drivers.count - 16) }
    }

    // MARK: Daily

    static func daily(_ s: inout GameState) {
        if !s.hype.ready {
            // An older save (or a new game) starts at rest rather than at zero.
            s.hype.ready = true
            s.hype.meter = rest(s)
        }
        let (_, _, d) = GameCalendar.components(s.date)
        // Anticipation: a show on the calendar pulls the meter up toward its cap; otherwise it drifts back to rest.
        if let e = s.hype.event, e.date > s.date {
            let cap = e.format.anticipationCap * (e.kind == .devDay ? 0.8 : 1)
            if s.hype.meter < cap { s.hype.meter += (cap - s.hype.meter) * 0.04 }
        } else {
            let r = rest(s)
            s.hype.meter += (r - s.hype.meter) * (s.hype.meter > r ? 0.03 : 0.05)
        }
        Stage.daily(&s)
        booth(&s)
        promise(&s)
        if d % 7 == 2 {
            s.hype.history.append((s.hype.meter * 10).rounded() / 10)
            if s.hype.history.count > 52 { s.hype.history.removeFirst(s.hype.history.count - 52) }
            s.hype.prestige *= 0.985
            Viral.weekly(&s)
        }
        if d == 1 { recruits(&s) }
    }

    // MARK: Launches spend it

    /// What a model delivered against the hype, on the same 0–100 scale: its rank, plus a little for a clear step up on
    /// your live models (older models' indices were scored on older benchmarks, so only a gain counts).
    static func delivered(_ s: GameState, _ m: AIModel, rank: Int, previousBest: Double?) -> Double {
        var v: Double = rank == 1 ? 95 : (rank <= 3 ? 78 : (rank <= 5 ? 58 : (rank <= 10 ? 38 : 22)))
        let live = s.releasedModels.filter { $0.id != m.id }.map(\.index).max()
        if let p = live ?? previousBest, m.index > p + 3 { v += min(10, (m.index - p) * 1.5) }
        return clamp(v, 0, 100)
    }

    /// From `release` (any launch but a family's auto-tier): records the day-one boost and checks the promise.
    static func launched(_ s: inout GameState, _ i: Int, plan: LaunchPlan, rank: Int, previousBest: Double?) {
        let m = s.models[i]
        // A quiet release keeps the hype for later.
        if plan.strategy == .stealth || plan.strategy == .limitedAccess { return }
        // A model out before its own launch event: the show will be its big moment.
        if let e = s.hype.event, e.kind == .launch, e.modelID == nil, e.date > s.date, GameCalendar.daysBetween(s.date, e.date) <= 45 {
            s.hype.event?.modelID = m.id
            Sim.news(&s, "\(m.name) is out ahead of your \(e.format.short.lowercased())",
                     "Its day-one rush waits for the show on \(e.date.gameShort): the hype is spent on stage.", .company)
            return
        }
        spend(&s, m, rank: rank, previousBest: previousBest)
    }

    static func spend(_ s: inout GameState, _ m: AIModel, rank: Int, previousBest: Double?) {
        let h = s.hype.meter
        let got = delivered(s, m, rank: rank, previousBest: previousBest)
        let show = s.hype.shows.first.flatMap { $0.date == s.date && $0.kind == .launch ? $0.score : nil } ?? -1
        var boost = 0.55 * h / 100 * (show >= 0 ? 0.8 + 0.4 * show / 100 : 1)
        var verdict = ""
        let key = "spend|\(m.name)|\(RivalIntel.dayIndex(s.date))"
        if h >= 45 && h - got > 30 {
            // Overhyped: the gap between the promise and the model is the story.
            verdict = "overhyped"
            boost *= 0.5
            let hit = min(5, (h - got) / 12)
            Fun.brand(&s, -hit)
            Stakeholders.move(&s, ["public": -1, "investors": -1], "\(m.name) didn't live up to the hype")
            Sim.news(&s, "\(m.name): \"overhyped\"", "The hype said frontier; the leaderboard says #\(rank). Reviews lead with the gap between the teasers and the model. Brand −\(Fmt.trim(hit, 1)).",
                     .company, important: true, good: false)
            Viral.chatter(&s, ViralDef(id: "overhyped", positive: false, title: "", detail: "", hashtag: "#\(tag(m.name))Disappoints", size: 1, year: 0,
                                       posts: [("skeptic", "{model} after a month of teasers: fine. Just fine. That's the review.", -0.6),
                                               ("joker", "{company} teasers: 🌌🚀🔥\n{model}: a decent model", -0.4),
                                               ("finance", "Expectations were priced for #1. {model} is not #1.", -0.4)]), model: m.name, key: key, views: 0)
        } else if got - h > 35 && got >= 75 {
            verdict = "sleeper"
            Fun.brand(&s, 2)
            Sim.news(&s, "\(m.name) comes out of nowhere", "Nobody was waiting for it, and it's #\(rank). The surprise is half the story. Brand +2.",
                     .company, good: true)
            Viral.chatter(&s, ViralDef(id: "sleeper", positive: true, title: "", detail: "", hashtag: "#\(tag(m.name))", size: 1, year: 0,
                                       posts: [("insider", "Nobody saw {model} coming. Not even people who should have.", 0.5),
                                               ("bench", "{model} just walked onto the top of the board with no warm-up act. Impressive.", 0.6)]), model: m.name, key: key, views: 0)
        } else if h >= 40 {
            let g = h / 40
            Fun.brand(&s, g)
            Sim.news(&s, "The wait for \(m.name) pays off", "Hype at \(Int(h)) turns into a day-one rush: about +\(Int((boost * 100).rounded()))% demand, fading over a few weeks.",
                     .company, good: true)
        }
        s.hype.launches.insert(HypeLaunch(modelID: m.id, model: m.name, date: s.date, hype: (h * 10).rounded() / 10, boost: boost,
                                          delivered: got, showScore: show, verdict: verdict), at: 0)
        if s.hype.launches.count > 12 { s.hype.launches.removeLast(s.hype.launches.count - 12) }
        // The meter is spent; a great model leaves some behind.
        let after = h * 0.35 + got * 0.12
        add(&s, after - h, "\(m.name) launched: the hype is spent")
        s.hype.teasers = 0
        if s.hype.promise != nil {
            Sim.news(&s, "Promise kept: \(m.name)", "You teased it on stage; it shipped. The crowd remembers who delivers.", .company, good: true)
            s.hype.promise = nil
            s.hype.promiseModel = ""
            Fun.brand(&s, 1)
        }
    }

    /// The launch's demand multiplier from hype (its model only) and from viral moments and a store (the chat app).
    static func demandFactor(_ s: GameState, _ modelID: UUID?, consumer: Bool) -> Double {
        var f = 1.0
        if let id = modelID {
            for l in s.hype.launches.prefix(4) where l.modelID == id {
                let t = Double(GameCalendar.daysBetween(l.date, s.date))
                if t >= 0 && t < 90 { f *= 1 + l.boost * pow(0.5, t / boostHalfLife) }
                break
            }
        }
        if consumer {
            if let d = s.hype.viralDate, s.hype.viralBoost > 0 {
                let t = Double(GameCalendar.daysBetween(d, s.date))
                if t >= 0 && t < 60 { f *= 1 + s.hype.viralBoost * pow(0.5, t / 10) }
            }
            if let u = s.hype.storeUntil, u > s.date { f *= 1.06 }
        }
        return f
    }

    /// The press's read of a launch, shifted by the hype it spent and the show (Launches.writeReport).
    static func pressShift(_ s: GameState, _ modelID: UUID) -> Double {
        guard let l = s.hype.launches.first(where: { $0.modelID == modelID }) else { return 0 }
        var t = 0.0
        if l.verdict == "overhyped" { t -= 0.25 }
        if l.verdict == "sleeper" { t += 0.15 }
        if l.verdict.isEmpty && l.hype >= 60 { t += 0.1 }
        if l.showScore >= 0 { t += (l.showScore - 50) / 200 }
        return t
    }

    // MARK: Teasers

    static func teaserBlocker(_ s: GameState) -> String? {
        if s.models.isEmpty && s.runs.isEmpty { return "Nothing to tease yet: start training a model." }
        if let t = s.hype.lastTeaser, GameCalendar.daysBetween(t, s.date) < teaserCooldown {
            return "You teased \(GameCalendar.daysBetween(t, s.date)) days ago. Next from \(GameCalendar.addDays(t, teaserCooldown).gameShort)."
        }
        return nil
    }

    /// Hype a teaser adds now: less with every teaser since your last launch.
    static func teaserGain(_ s: GameState) -> Double { max(1, 8 * pow(0.7, Double(s.hype.teasers))) }

    static func tease(_ s: inout GameState) -> String? {
        if let b = teaserBlocker(s) { return b }
        let n = s.hype.teasers
        let key = "tease|\(RivalIntel.dayIndex(s.date))"
        var gain = teaserGain(s)
        let text = HypeCatalog.teasers[Int(roll(s, key) * Double(HypeCatalog.teasers.count)) % HypeCatalog.teasers.count]
        s.hype.teasers += 1
        s.hype.lastTeaser = s.date
        let importance = 0.3 + 0.004 * s.hype.meter
        Viral.companyPost(&s, text, key: key, importance: importance)
        // Past the third teaser with nothing shipped, people start counting.
        if n >= 3 && roll(s, key + "|vapor") < 0.3 + 0.1 * Double(n - 3) {
            gain *= 0.4
            Fun.brand(&s, -0.5)
            Viral.chatter(&s, ViralDef(id: "vapor", positive: false, title: "", detail: "", hashtag: "#\(tag(s.companyName))Soon", size: 0.6, year: 0,
                                       posts: [("joker", "{company} teaser #\(n + 1). The model: still \"soon\".", -0.4),
                                               ("skeptic", "Teasers are not a release schedule.", -0.5)]), model: "", key: key, views: 0)
            add(&s, gain, "Teaser #\(n + 1) — people are counting")
            Sim.news(&s, "Another teaser, another round of \"soon\" jokes", "Hype +\(Fmt.trim(gain, 1)). Ship something before the next one.", .company, good: false)
            return nil
        }
        add(&s, gain, "Teaser: \"\(text)\"")
        Viral.chatter(&s, ViralDef(id: "teaser", positive: true, title: "", detail: "", hashtag: "", size: 0.5, year: 0,
                                   posts: [("insider", "{company} doesn't tease for nothing. Something's close.", 0.4),
                                           ("joker", "{company} posting cryptic one-liners again. Clear your calendars I guess", 0.2)]), model: "", key: key, views: 0)
        return nil
    }

    // MARK: Conference circuit

    /// Papers, talks, awards and keynotes (Fun.Conferences): prestige with researchers and a little hype. A best paper
    /// brings applicants the same week.
    static func circuit(_ s: inout GameState, prestige: Double, hype: Double, _ why: String, applicants: Int = 0) {
        s.hype.prestige = clamp(s.hype.prestige + prestige, 0, 100)
        add(&s, hype, why)
        if applicants > 0 { apply(&s, applicants, why: "after \(why.prefix(1).lowercased() + why.dropFirst())") }
    }

    /// Researchers who saw your talks apply: on the first of the month, one (two above 70 prestige) from 25 prestige.
    static func recruits(_ s: inout GameState) {
        let p = s.hype.prestige
        guard p >= 25 else { return }
        apply(&s, p >= 70 ? 2 : 1, why: "after seeing your work on the conference circuit")
    }

    /// Researcher candidates drawn by your standing (skill lifted by prestige), on top of the monthly market.
    static func apply(_ s: inout GameState, _ n: Int, why: String) {
        guard s.employees.count >= 2 else { return }
        let open = s.candidates.filter { $0.role == .researcher && $0.office.isEmpty }.count
        guard open < GameState.driveRoleCap else { return }
        var names: [String] = []
        for _ in 0..<min(n, GameState.driveRoleCap - open) {
            var c = People.makeCandidate(&s, role: .researcher)
            c.skill = min(97, (max(c.skill, 58) + 3 + s.hype.prestige / 6).rounded())   // people who read your papers are good
            c.sourced = true
            c.bio += " Applied after one of your conference talks."
            s.candidates.append(c)
            names.append("\(c.name) (skill \(Int(c.skill)))")
            s.hype.hires += 1
        }
        Sim.news(&s, "Your papers bring in applicants", "\(names.joined(separator: " and ")) applied \(why). They're on the Team page for 45 days.",
                 .research, good: true)
    }

    // MARK: Recruiting booths

    static func boothCost(_ s: GameState) -> Double { (clamp(GameState.keynoteCost(s) * 0.12, 30_000, 3_000_000) / 1_000).rounded() * 1_000 }

    /// The next conference far enough away to book a booth at.
    static func boothVenue(_ s: GameState) -> (VenueDef, Date)? {
        Conferences.upcoming(s, count: 5).first { GameCalendar.daysBetween(s.date, $0.1) >= 10 }
    }

    static func boothBlocker(_ s: GameState) -> String? {
        if !s.hype.booth.isEmpty { return "You already have a booth booked." }
        if s.employees.count < 2 { return "Hire at least two people first: someone has to staff it." }
        guard boothVenue(s) != nil else { return "No conference far enough ahead." }
        let c = boothCost(s)
        if c > s.cash { return "A booth costs \(Fmt.money(c)); you have \(Fmt.money(s.cash))." }
        return nil
    }

    static func bookBooth(_ s: inout GameState) -> String? {
        if let b = boothBlocker(s) { return b }
        guard let (v, d) = boothVenue(s) else { return "No conference far enough ahead." }
        let c = boothCost(s)
        s.cash -= c
        s.month.costMarketing += c
        s.hype.booth = "\(v.id)|\(d.ym.year)"
        Sim.news(&s, "Recruiting booth booked at \(v.short) \(d.ym.year)", "\(Fmt.money(c)) for a booth, a dinner and swag in \(v.city). Your people meet candidates on \(d.gameShort).", .company)
        return nil
    }

    static func booth(_ s: inout GameState) {
        let parts = s.hype.booth.split(separator: "|").map(String.init)
        guard parts.count == 2, let v = FunCatalog.venueByID[parts[0]], let year = Int(parts[1]) else {
            if !s.hype.booth.isEmpty { s.hype.booth = "" }
            return
        }
        let day = Conferences.date(v, year)
        if day < s.date { s.hype.booth = ""; return }
        guard day == s.date else { return }
        s.hype.booth = ""
        s.hype.boothsRun += 1
        var names: [String] = []
        for role in [Role.researcher, .researcher, .mlEngineer] {
            var c = People.makeCandidate(&s, role: role)
            c.skill = min(96, (c.skill + 4 + s.hype.prestige / 12).rounded())
            c.sourced = true
            c.bio += " Met your team at \(v.short) \(year)."
            s.candidates.append(c)
            names.append(c.name)
            s.hype.hires += 1
        }
        circuit(&s, prestige: 2, hype: 1.5, "Recruiting booth at \(v.short)")
        Sim.news(&s, "\(v.short) booth: three strong candidates", "\(names.joined(separator: ", ")) want to talk after meeting your team in \(v.city). They're on the Team page for 45 days.",
                 .company, image: v.image, good: true)
    }

    // MARK: Promises

    static func promise(_ s: inout GameState) {
        guard let p = s.hype.promise, p <= s.date else { return }
        s.hype.promise = nil
        let name = s.hype.promiseModel
        s.hype.promiseModel = ""
        Fun.brand(&s, -3)
        add(&s, -20, "The model you teased on stage never shipped")
        Stakeholders.move(&s, ["public": -1, "investors": -1.5], "\(name.isEmpty ? "A model teased on stage" : name) never shipped")
        Sim.news(&s, "Vaporware: \(name.isEmpty ? "the model you teased" : name) never shipped", "Five months after \"one more thing\", nothing. The clip of the tease is now a meme about promises. Brand −3.",
                 .company, important: true, good: false)
        Viral.chatter(&s, ViralDef(id: "vaporware", positive: false, title: "", detail: "", hashtag: "#Vaporware", size: 1, year: 0,
                                   posts: [("joker", "five months since {company}'s \"one more thing\". Still waiting on the thing.", -0.5),
                                           ("finance", "Missed launch windows cost credibility. {company} just spent some.", -0.5)]), model: "", key: "promise|\(RivalIntel.dayIndex(s.date))", views: 0)
    }

    /// A model name as a hashtag fragment.
    static func tag(_ name: String) -> String { name.filter { $0.isLetter || $0.isNumber } }

    static func fill(_ s: GameState, _ text: String, model: String) -> String {
        text.replacingOccurrences(of: "{model}", with: model)
            .replacingOccurrences(of: "{Model}", with: tag(model))
            .replacingOccurrences(of: "{company}", with: s.companyName)
            .replacingOccurrences(of: "{Company}", with: tag(s.companyName))
            .replacingOccurrences(of: "{founder}", with: s.founderName)
    }

    /// Inbox decisions from these systems.
    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        switch d.kind {
        case viralUpKind, viralDownKind: Viral.resolve(&s, d, option: option)
        case noShowKind: Stage.resolveNoShow(&s, d, option: option)
        default: break
        }
    }
}

// MARK: - Viral moments

enum Viral {
    /// Weekly: maybe a moment. Odds rise with hype, users and fame; the bad kind is likelier for a lab with weak safety.
    static func weekly(_ s: inout GameState) {
        guard let best = s.releasedModels.max(by: { $0.index < $1.index }) else { return }
        guard !s.decisions.contains(where: { $0.kind == Hype.viralUpKind || $0.kind == Hype.viralDownKind }) else { return }
        let key = "viral|\(RivalIntel.dayIndex(s.date))"
        let users = s.consumerUsers
        guard Hype.roll(s, key) < odds(s) else { return }
        let calm = s.hype.calmUntil.map { $0 > s.date } ?? false
        var bad = 0.42 + (50 - s.safetyScore) / 250 + (best.safety < 40 ? 0.08 : 0) - (calm ? 0.2 : 0) + (s.reliability < 0.95 ? 0.08 : 0)
        bad = clamp(bad, 0.15, 0.75)
        let positive = Hype.roll(s, key + "|tone") >= bad
        let chat = s.chatModelID != nil && users > 1_000
        let api = s.releasedModels.contains(where: \.api)
        let pool = HypeCatalog.viral.filter { d in
            d.positive == positive && s.year >= d.year && (!d.chat || chat) && (!d.api || api)
                && (d.id != "outage" || s.reliability < 0.985)
                && !s.hype.viral.prefix(4).contains { $0.kind == d.id }
        }
        guard let def = Cast.pick(s, "hype|\(key)|def", pool) else { return }
        fire(&s, def, model: best, key: key)
    }

    /// This week's chance of a moment (with a released model): about one a quarter for a quiet lab, one a month at fever pitch.
    static func odds(_ s: GameState) -> Double {
        guard !s.releasedModels.isEmpty else { return 0 }
        return 0.03 + 0.17 * s.hype.meter / 100 + 0.04 * clamp(log10(max(1, s.consumerUsers)) / 9, 0, 1) + (s.brand > 60 ? 0.015 : 0)
    }

    /// How far a moment travels: more users and more fame, more views.
    static func views(_ s: GameState, size: Double, key: String) -> Double {
        let base = 150_000 + s.consumerUsers * 0.15 + pow(clamp(s.brand, 0, 100), 2) * 900
        return (base * size * (0.6 + 0.8 * Hype.roll(s, key + "|views")) / 1_000).rounded() * 1_000
    }

    static func fire(_ s: inout GameState, _ def: ViralDef, model m: AIModel, key: String) {
        let impact = def.size * (0.6 + 0.8 * Hype.roll(s, key + "|impact"))
        let v = views(s, size: def.size, key: key)
        var moment = ViralMoment(date: s.date, kind: def.id, title: Hype.fill(s, def.title, model: m.name), detail: Hype.fill(s, def.detail, model: m.name),
                                 hashtag: Hype.fill(s, def.hashtag, model: m.name), positive: def.positive, views: v)
        moment.model = m.name
        if def.positive {
            let h = 7 * impact
            let b = 1.2 * impact
            moment.hypeDelta = h
            moment.brandDelta = b
            Hype.add(&s, h, "Viral: \(moment.hashtag)")
            Fun.brand(&s, b)
            s.hype.viralBoost = max(s.hype.viralBoost * 0.3, 0.18 * impact)
            s.hype.viralDate = s.date
            Stakeholders.move(&s, ["public": 0.5 * impact], "\(moment.hashtag) went viral")
            if def.id == "devtrend" || def.id == "student" {
                s.marketMoves.devEcosystem = min(100, s.marketMoves.devEcosystem + 2 * impact)
                Stakeholders.move(&s, ["developers": 0.8 * impact], "\(moment.hashtag) trended among developers")
            }
            let cost = adCost(s)
            Events.addDecision(&s, kind: Hype.viralUpKind, title: "Viral: \(moment.title)",
                               body: "\(moment.detail) \(Fmt.count(v)) views and climbing. Brand +\(Fmt.trim(b, 1)), hype +\(Fmt.trim(h, 1)).",
                               image: ImagePicker.pick(.events, seed: moment.title),
                               options: [DecisionOption(label: "Ride the wave (\(Fmt.money(cost)) of ads)", detail: "Put money behind it while everyone's watching: the chat app's lift nearly doubles."),
                                         DecisionOption(label: "Let it run", detail: "Enjoy it. It fades in a couple of weeks.")],
                               amount: cost, ref: moment.id.uuidString)
        } else {
            moment.hypeDelta = 2
            Hype.add(&s, 2, "Backlash: \(moment.hashtag) (attention is attention)")
            let fallout = 1.6 * impact
            Events.addDecision(&s, kind: Hype.viralDownKind, title: "Going viral, badly: \(moment.title)",
                               body: "\(moment.detail) \(Fmt.count(v)) views. Left alone, it costs about \(Fmt.trim(fallout, 1)) brand.",
                               image: ImagePicker.pick(.events, seed: moment.title),
                               options: [DecisionOption(label: "Own it: apologise and ship a fix", detail: "Four days of research go into the fix. A third of the brand damage; the public respects it."),
                                         DecisionOption(label: "Answer with a joke", detail: "Defuses it more often than not, and the joke itself can go viral. When it lands badly it's worse."),
                                         DecisionOption(label: "Say nothing", detail: "It blows over in a week or two. The brand damage stands.")],
                               amount: fallout, ref: moment.id.uuidString)
        }
        Sim.news(&s, def.positive ? "Viral: \(moment.title)" : "Backlash: \(moment.title)", moment.detail, .company, good: def.positive)
        chatter(&s, def, model: m.name, key: key, views: v)
        s.hype.viral.insert(moment, at: 0)
        if s.hype.viral.count > 30 { s.hype.viral.removeLast(s.hype.viral.count - 30) }
    }

    static func adCost(_ s: GameState) -> Double { (clamp(s.valuation * 0.0001, 50_000, 15_000_000) / 1_000).rounded() * 1_000 }

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        let i = s.hype.viral.firstIndex { $0.id.uuidString == d.ref }
        let tag = i.map { s.hype.viral[$0].hashtag } ?? "the moment"
        if d.kind == Hype.viralUpKind {
            guard option == 0 else {
                if let i { s.hype.viral[i].response = "Let it run" }
                return
            }
            guard s.cash >= d.amount else {
                Sim.news(&s, "No ad money for \(tag)", "There wasn't \(Fmt.money(d.amount)) in the bank.", .company, good: false)
                return
            }
            s.cash -= d.amount
            s.month.costMarketing += d.amount
            s.hype.viralBoost *= 1.8
            Hype.add(&s, 4, "Ads behind \(tag)")
            if let i { s.hype.viral[i].response = "Rode the wave"; s.hype.viral[i].hypeDelta += 4 }
            Sim.news(&s, "You put \(Fmt.money(d.amount)) behind \(tag)", "Ads ride the moment while it lasts: more sign-ups on the chat app for the next few weeks.", .company)
            return
        }
        let fallout = d.amount
        switch option {
        case 0:
            let rp = s.rpToday * 4
            if let head = s.researchQueue.first { s.researchProgress[head] = max(0, (s.researchProgress[head] ?? 0) - rp) }
            Fun.brand(&s, -fallout / 3)
            Stakeholders.move(&s, ["public": 0.8, "researchers": 0.3], "You owned up to \(tag) and shipped a fix")
            if let i { s.hype.viral[i].response = "Apologised and fixed it"; s.hype.viral[i].brandDelta = -fallout / 3 }
            Sim.news(&s, "You own up to \(tag)", "A plain apology and a fix within the week. The story moves on faster than it came.", .company, good: true)
        case 1:
            let key = "joke|\(d.ref)"
            if Hype.roll(s, key) < 0.55 {
                Fun.brand(&s, 0.5)
                Hype.add(&s, 5, "Your joke about \(tag) landed")
                if let i { s.hype.viral[i].response = "Joked — it landed"; s.hype.viral[i].brandDelta = 0.5; s.hype.viral[i].hypeDelta += 5 }
                Sim.news(&s, "Your reply to \(tag) goes viral too", "A self-deprecating post gets more likes than the original. Crisis turned into a bit.", .company, good: true)
                companyPost(&s, "Fair. We've had a word with it.", key: key, importance: 0.8)
            } else {
                Fun.brand(&s, -fallout * 1.4)
                Stakeholders.move(&s, ["public": -1], "A flippant reply to \(tag)")
                if let i { s.hype.viral[i].response = "Joked — it backfired"; s.hype.viral[i].brandDelta = -fallout * 1.4 }
                Sim.news(&s, "Your joke about \(tag) backfires", "\"Read the room\" is the top reply. The story gets a second day. Brand −\(Fmt.trim(fallout * 1.4, 1)).", .company, good: false)
            }
        default:
            Fun.brand(&s, -fallout)
            Stakeholders.move(&s, ["public": -0.5], "Silence over \(tag)")
            if let i { s.hype.viral[i].response = "Said nothing"; s.hype.viral[i].brandDelta = -fallout }
        }
    }

    // MARK: Posts

    /// The posts that carry a moment, about you, sized to its views.
    static func chatter(_ s: inout GameState, _ def: ViralDef, model: String, key: String, views: Double) {
        for (k, p) in def.posts.enumerated() {
            let text = Hype.fill(s, p.1, model: model) + (k == 0 && !def.hashtag.isEmpty ? " \(Hype.fill(s, def.hashtag, model: model))" : "")
            guard let a = Pulse.author(s, pool: p.0, lab: "player", person: "", key: "hype|\(key)|\(k)", avoid: []) else { continue }
            let kind: PulseKind = p.0 == "joker" ? .joke : (p.2 < -0.3 ? (p.0 == "worried" ? .safety : .skeptic) : (p.0 == "dev" ? .reaction : .hype))
            Pulse.add(&s, a, text: text, labs: ["player"], tone: p.2, kind: kind, topic: def.hashtag.isEmpty ? def.id : Hype.fill(s, def.hashtag, model: model),
                      importance: 0.5, key: "hype|\(key)|\(k)")
            if views > 0, !s.pulse.isEmpty {
                // A viral post is liked like one.
                let share = k == 0 ? 0.01 : 0.002
                s.pulse[0].likes = max(s.pulse[0].likes, Int(views * share * (0.5 + Hype.roll(s, "\(key)|likes|\(k)"))))
                s.pulse[0].reposts = max(s.pulse[0].reposts, s.pulse[0].likes / 6)
            }
        }
    }

    /// A post from your company's own account.
    static func companyPost(_ s: inout GameState, _ text: String, key: String, importance: Double) {
        let handle = "@" + Hype.tag(s.companyName).lowercased()
        let a = Pulse.Author(id: "", handle: handle, name: s.companyName, stature: 0.5)
        Pulse.add(&s, a, text: text, labs: ["player"], tone: 0.6, kind: .hype, topic: "teaser", importance: importance, key: "hype|own|\(key)")
        if !s.pulse.isEmpty {
            let fans = 2_000 + pow(clamp(s.brand, 0, 100), 2) * 60 + s.consumerUsers * 0.002
            s.pulse[0].likes = max(s.pulse[0].likes, Int(fans * (0.5 + s.hype.meter / 100)))
            s.pulse[0].reposts = s.pulse[0].likes / 8
        }
    }
}

// MARK: - Player actions

extension GameState {
    mutating func postTeaser() -> String? { Hype.tease(&self) }
    mutating func bookRecruitingBooth() -> String? { Hype.bookBooth(&self) }
}
