import Foundation

/// The Pulse (3.4): the industry talking to itself. Short posts from the cast and from anonymous accounts react to what
/// happens — launches, rounds, takeovers, votes, leaks, career moves, your milestones — and a weekly pass adds the
/// background chatter: rumours from the rumour mill, leaderboard arguments, market mood, policy, jokes. The same weekly
/// pass turns the last ~60 days of posts into each lab's buzz (how much it's talked about, and how kindly).
/// Posts are written at event time and once a week, never per frame. Hashed rolls only; nothing feeds back into the game.
enum Pulse {
    /// Posts kept (newest first).
    static let cap = 200
    /// Days of posts that count toward buzz.
    static let window = 60

    static func roll(_ s: GameState, _ key: String) -> Double { Cast.roll(s, "pulse|\(key)") }

    // MARK: Authors

    struct Author {
        var id: String
        var handle: String
        var name: String
        var stature: Double
    }

    static let personaOf: [String: String] = [
        "contrarian": "skeptic", "hypeman": "booster", "critic": "worried", "analyst": "finance", "investor": "booster",
        "reporter": "insider", "academic": "bench", "official": "worried",
    ]

    static func anon(_ s: GameState, persona: String, key: String, avoid: Set<String>) -> Author? {
        var pool = CastCatalog.accounts.filter { $0.persona == persona && !avoid.contains($0.handle) }
        if pool.isEmpty { pool = CastCatalog.accounts.filter { $0.persona == persona } }
        guard let a = Cast.pick(s, "anon|\(key)", pool) else { return nil }
        return Author(id: "", handle: a.handle, name: a.name, stature: 0.15)
    }

    static func cast(_ p: CastMember?) -> Author? { p.map { Author(id: $0.id, handle: $0.handle, name: $0.name, stature: $0.stature) } }

    /// Who posts a line written for `pool`, about `lab`. `vars` carries the bill for "backer" and "opponent"; `voices`
    /// (family letters, e.g. "BS") limits a line to people who talk that way — a careful chief executive doesn't post "Cute."
    static func author(_ s: GameState, pool: String, lab: String, person: String, key: String, avoid: Set<String>,
                       vars: [String: String] = [:], voices: String = "") -> Author? {
        func sounds(_ p: CastMember) -> Bool { voices.isEmpty || voices.contains(p.voiceStyle.family.tag) }
        // Outsiders' takes come from outside: nobody at the lab in the story, and none of your people.
        func find(_ test: @escaping (CastMember) -> Bool) -> Author? {
            cast(Cast.find(s, key: "pulse|\(pool)|\(key)", avoid: Array(avoid)) { $0.org != lab && $0.org != "player" && sounds($0) && test($0) })
        }
        switch pool {
        case "insider", "skeptic", "joker", "booster", "dev", "bench", "finance", "worried":
            return anon(s, persona: pool, key: key, avoid: avoid)
        case "self":
            return cast(Cast.person(s, id: person).flatMap { sounds($0) ? $0 : nil })
        case "lead":
            return cast(Cast.voice(s, lab).flatMap { sounds($0) && !avoid.contains($0.id) ? $0 : nil })
        case "staff":
            let here = Cast.staff(s, lab).filter { $0.castKind != .leader && !avoid.contains($0.id) && sounds($0) }
            let people = here.isEmpty ? s.cast.filter { $0.lastLab == lab && $0.org != lab && !avoid.contains($0.id) && Cast.days($0.since, s.date) <= 60 && sounds($0) } : here
            return cast(Cast.weighted(s, "pulse-staff|\(key)", people.map { ($0, 0.3 + $0.stature) }))
        case "you":
            let mine = s.cast.filter { $0.active && $0.org == "player" && !avoid.contains($0.id) && sounds($0) }
            return cast(Cast.weighted(s, "pulse-you|\(key)", mine.map { ($0, 0.3 + $0.stature) }))
        case "rival":
            return cast(Voices.rival(s, excluding: [lab], "pulse|\(key)").flatMap { sounds($0) && !avoid.contains($0.id) ? $0 : nil })
        // Officials who test models before release.
        case "tester": return find { $0.castKind == .official && ($0.org.contains("Institute") || $0.org.contains("Office")) }
        case "analyst": return find { Voices.isAnalyst($0) }
        case "reporter": return find { $0.castKind == .journalist && $0.voiceStyle == .reporter }
        case "investor": return find { $0.castKind == .investor && $0.voiceStyle.family != .skeptic }
        case "critic": return find { $0.castKind == .critic && $0.voiceStyle != .evangelist }
        case "academic": return find { $0.castKind == .academic }
        case "official": return find { $0.castKind == .official }
        // Officials who want rules, and officials who want fewer.
        case "regulator": return find { $0.castKind == .official && $0.regulation > 0.3 }
        case "deregulator": return find { $0.castKind == .official && $0.regulation < 0 }
        // For or against the bill in the story (US officials vote on US bills).
        case "backer", "opponent":
            guard let bill = vars["billid"] else { return nil }
            let safety = vars["billsafety"] == "1"
            return find { $0.castKind == .official && $0.region == "US" && Voices.backs(bill, safety, $0) == (pool == "backer") }
        // Someone already at the place a person just joined.
        case "colleague":
            guard let org = vars["toorg"], !org.isEmpty else { return nil }
            return find { $0.org == org && $0.id != person }
        case "hypeman": return find { ($0.voiceStyle == .booster || $0.voiceStyle == .showman) && !$0.castKind.atLab }
        case "contrarian": return find { $0.voiceStyle.family == .skeptic && $0.castKind != .leader && $0.castKind != .free }
        default: return nil
        }
    }

    static func kind(of pool: String, event: String) -> PulseKind {
        if event.hasPrefix("career") || event.hasPrefix("personal") { return .people }
        if event.hasPrefix("bill") || event.hasPrefix("amb.policy") { return .policy }
        if event == "unsafe" || event == "leak" || event.hasPrefix("amb.safety") { return .safety }
        if event.hasPrefix("amb.rumor") { return .rumor }
        switch pool {
        case "joker": return .joke
        case "skeptic", "contrarian": return .skeptic
        case "bench", "academic": return .bench
        case "insider", "reporter": return .rumor
        case "booster", "hypeman": return .hype
        case "finance", "investor", "analyst": return .money
        case "worried", "critic": return .safety
        case "official", "regulator", "deregulator", "backer", "opponent", "tester": return .policy
        default: return event.hasPrefix("amb") ? .ambient : .reaction
        }
    }

    static let baseTone: [String: Double] = [
        "lead": 0.8, "staff": 0.7, "self": 0.4, "you": 0.6, "hypeman": 0.6, "booster": 0.6, "dev": 0.3, "insider": 0.15, "investor": 0.4,
        "joker": 0.05, "bench": 0, "analyst": 0, "reporter": 0, "official": 0, "finance": 0, "rival": -0.25, "contrarian": -0.35,
        "skeptic": -0.4, "critic": -0.5, "worried": -0.5, "academic": -0.1, "regulator": -0.2, "deregulator": 0.2, "backer": 0, "opponent": 0, "colleague": 0.5,
    ]

    // MARK: Posting

    static func add(_ s: inout GameState, _ a: Author, text: String, labs: [String], tone: Double, kind: PulseKind, topic: String,
                    importance: Double, key: String) {
        let r = roll(s, "heat|\(key)|\(a.handle)")
        let exponent = a.id.isEmpty ? 0.8 + 1.9 * r + 0.8 * importance : 1.0 + 2.4 * a.stature + 0.8 * importance + 0.7 * r
        let likes = Int(pow(10, min(5.8, exponent)))
        var p = PulsePost(date: s.date, author: a.id, handle: a.handle, name: a.name, text: text, labs: labs, tone: clamp(tone, -1, 1),
                          kind: kind.rawValue, likes: likes)
        p.reposts = Int(Double(likes) * (0.05 + 0.15 * roll(s, "reposts|\(key)|\(a.handle)")))
        p.topic = topic
        s.pulse.insert(p, at: 0)
        if s.pulse.count > cap { s.pulse.removeLast(s.pulse.count - cap) }
    }

    /// When each line of `bank` was last posted (line index → day): the bank's log holds one "line@day" entry per line used.
    static func lastPosted(_ s: GameState, _ bank: String) -> [Int: Int] {
        var out: [Int: Int] = [:]
        for e in s.voiceRecent["posted|" + bank] ?? [] {
            guard let at = e.firstIndex(of: "@"), let k = Int(e[..<at]), let day = Int(e[e.index(after: at)...]) else { continue }
            out[k] = day
        }
        return out
    }

    static func markPosted(_ s: inout GameState, _ bank: String, line k: Int, day: Int) {
        let logKey = "posted|" + bank
        var log = (s.voiceRecent[logKey] ?? []).filter { !$0.hasPrefix("\(k)@") }
        log.append("\(k)@\(day)")
        s.voiceRecent[logKey] = log
    }

    /// Posts reacting to a story: `count` lines (one to three by default, more for bigger stories) from bank "p.<event>", each from a
    /// different kind of voice. A line posted in the last `freshDays` days waits; when nothing fresher fits, the line
    /// used longest ago fills in so the story still gets one reaction — unless `allowStale` is off (background chatter).
    @discardableResult
    static func react(_ s: inout GameState, _ event: String, labs: [String], vars: [String: String], key: String, importance: Double = 0.5,
                      count: Int? = nil, person: String = "", freshDays: Int = 150, allowStale: Bool = true) -> Int {
        guard !s.cast.isEmpty, let lines = PulseBank.lines["p.\(event)"] else { return 0 }
        // A busy day (three labs cutting prices at once) gets a reaction or two each, not a flood.
        let sameDay = s.pulse.prefix(14).filter { $0.date == s.date }.count
        guard sameDay < 12 else { return 0 }
        let n = sameDay >= 6 ? 1 : count ?? (1 + Int(roll(s, "count|\(key)") * 1.5 + importance * 1.2))
        let lab = labs.first ?? ""
        var usedPools: Set<String> = []
        var usedAuthors: Set<String> = Set(s.pulse.prefix(3).map { $0.author.isEmpty ? $0.handle : $0.author })
        var posted = 0
        let today = RivalIntel.dayIndex(s.date)
        let last = lastPosted(s, "p.\(event)")
        // A hashed starting line and stride (one roll each), so different events start from different voices.
        let count = lines.count
        let start = Int(roll(s, "order|\(key)") * Double(count)) % count
        let strides = [1, 3, 5, 7, 11].filter { count % $0 != 0 || $0 == 1 }
        let step = strides[Int(roll(s, "stride|\(key)") * Double(strides.count)) % strides.count]
        let order = (0..<count).map { (start + $0 * step) % count }
        let fresh = order.filter { k in last[k].map { today - $0 >= freshDays } ?? true }
        let stale = allowStale ? order.filter { k in !fresh.contains(k) }.sorted { (last[$0] ?? 0) < (last[$1] ?? 0) } : []
        for (pass, ks) in [fresh, stale].enumerated() {
            for k in ks where posted < (pass == 0 ? n : 1) {
                let (tagSub, textSub) = Voices.split(lines[k])
                // "rival-/BS": pool, tone nudge, and the voice families the line suits.
                let parts = tagSub.split(separator: "/", maxSplits: 1)
                var pool = String(parts.first ?? "")
                let voices = parts.count > 1 ? String(parts[1]) : ""
                var shift = 0.0
                if pool.hasSuffix("+") { shift = 0.35; pool.removeLast() } else if pool.hasSuffix("-") { shift = -0.35; pool.removeLast() }
                guard !usedPools.contains(pool) else { continue }
                guard let a = author(s, pool: pool, lab: lab, person: person, key: "\(key)|\(k)", avoid: usedAuthors, vars: vars,
                                     voices: voices) else { continue }
                var v = vars
                v["name"] = v["name"] ?? a.name
                guard let text = Voices.fill(String(textSub), v) else { continue }
                add(&s, a, text: text, labs: labs, tone: (baseTone[pool] ?? 0) + shift, kind: kind(of: pool, event: event), topic: event,
                    importance: importance, key: "\(key)|\(k)")
                markPosted(&s, "p.\(event)", line: k, day: today)
                usedPools.insert(pool)
                usedAuthors.insert(a.id.isEmpty ? a.handle : a.id)
                posted += 1
            }
        }
        return posted
    }

    // MARK: Hooks

    /// A lab left the market: farewells, gallows humour and where its people go.
    static func labClosed(_ s: inout GameState, _ labID: String) {
        var v = Voices.base(s).merging(Voices.labVars(s, labID)) { a, _ in a }
        v["labfull"] = CompetitorCatalog.def(labID).name
        react(&s, "closed", labs: [labID], vars: v, key: "closed|\(labID)", importance: 0.6, count: 2)
    }

    /// One of your people in the news: promoted, leaving, joining a rival.
    static func personal(_ s: inout GameState, _ personID: String, _ what: String) {
        guard let p = Cast.person(s, id: personID) else { return }
        var v = Voices.base(s)
        v["name"] = p.name
        if !p.org.isEmpty { v["toshort"] = Cast.orgName(p.org, s, short: true) }
        if !p.lastLab.isEmpty { v["fromshort"] = Cast.orgName(p.lastLab, s, short: true) }
        react(&s, "personal.\(what)", labs: ["player"], vars: v, key: "personal|\(personID)|\(Cast.monthIndex(s))|\(what)", importance: 0.4,
              count: 2, person: personID)
    }

    /// A career move from the month's churn.
    static func career(_ s: inout GameState, _ mv: Cast.Move) {
        guard let p = Cast.person(s, id: mv.personID) else { return }
        var v = Voices.base(s)
        v["name"] = p.name
        v["role"] = Cast.lowerFirst(mv.role)
        if !mv.from.isEmpty { v["fromshort"] = Cast.orgName(mv.from, s, short: true) }
        if !mv.to.isEmpty { v["toshort"] = Cast.orgName(mv.to, s, short: true); v["to"] = Cast.orgName(mv.to, s); v["toorg"] = mv.to }
        if Cast.isLab(mv.from) || mv.from == "player" { v["iffromlab"] = "" }
        if mv.role == "Chief executive" || mv.role == "Director" { v["ifceo"] = "" }
        if mv.role == "Chief scientist" { v["ifcs"] = "" }
        if Cast.isLab(mv.to), CompetitorCatalog.def(mv.to).founded.decimal <= s.year - 1 { v["ifestablished"] = "" }
        if let start = p.history.last?.date { v["years"] = "\(max(1, Cast.days(start, s.date) / 365))" }
        let kind: String
        switch mv.kind {
        case .joined, .scripted, .press: kind = mv.from.isEmpty ? "hired" : "joined"
        case .founded: kind = "founded"
        case .promoted: kind = "promoted"
        case .steppedDown: kind = "out"
        case .retired: kind = "retired"
        case .government: kind = "government"
        case .critic: kind = "critic"
        case .academia: kind = "academia"
        case .investor: kind = "investor"
        }
        let labs = [mv.from, mv.to].filter { Cast.isLab($0) || $0 == "player" }
        react(&s, "career.\(kind)", labs: labs, vars: v, key: "career|\(p.id)|\(Cast.monthIndex(s))", importance: 0.2 + 0.4 * p.stature,
              count: mv.weight >= 0.45 ? 2 : 1, person: p.id)
    }

    /// Your milestones get noticed.
    static func milestone(_ s: inout GameState, _ id: String) {
        guard PulseBank.lines["p.milestone.\(id)"] != nil else { return }
        let v = Voices.base(s)
        react(&s, "milestone.\(id)", labs: ["player"], vars: v, key: "milestone|\(id)", importance: 0.7, count: 2)
    }

    /// A lab changed strategy (RivalStrategy): the chatter that follows.
    static func play(_ s: inout GameState, _ i: Int) {
        let c = s.competitors[i]
        guard let play = RivalStrategy.play(c), PulseBank.lines["p.play.\(play.rawValue)"] != nil else { return }
        // Labs often change course on the same day; the chatter picks up two at most, and the same move once in a while.
        let today = s.pulse.prefix(12).filter { $0.date == s.date && $0.topic.hasPrefix("play.") }.count
        guard today < 2, Voices.cooled(&s, "play.\(play.rawValue)", days: 75) else { return }
        var v = Voices.base(s).merging(Voices.labVars(s, c.id)) { a, _ in a }
        let byValue = s.competitors.filter(\.alive).sorted { $0.valuation > $1.valuation }.map(\.id)
        if let rank = byValue.firstIndex(of: c.id) {
            if rank < 3 { v["ifbig"] = "" }
            if rank >= byValue.count / 2 { v["ifsmall"] = "" }
        }
        react(&s, "play.\(play.rawValue)", labs: [c.id], vars: v, key: "play|\(c.id)|\(Cast.monthIndex(s))", importance: 0.3, count: 1)
    }

    // MARK: Weekly

    /// Background chatter (one to three posts, each topic and line resting a while) and buzz.
    static func weekly(_ s: inout GameState) {
        guard !s.cast.isEmpty else { return }
        let week = RivalIntel.dayIndex(s.date) / 7
        var topics: [(String, [String], [String: String], Double)] = []
        let base = Voices.base(s)

        // The rumour mill.
        if let r = s.rumors.first(where: { Cast.days($0.date, s.date) <= 10 && $0.kind != "strategy" }),
           let c = s.competitors.first(where: { $0.id == r.labID }), let p = c.project {
            var v = base.merging(Voices.labVars(s, c.id)) { a, _ in a }
            v["codename"] = p.codename
            v["model"] = p.name
            topics.append(("amb.rumor", [c.id], v, 3))
        }
        // The leaderboard.
        var best: [(lab: String, model: String, index: Double)] = []
        for c in s.competitors where c.alive {
            if let m = c.models.max(by: { $0.index < $1.index }) { best.append((c.id, m.name, m.index)) }
        }
        if let m = s.releasedModels.max(by: { $0.index < $1.index }) { best.append(("player", m.name, m.index)) }
        best.sort { $0.index > $1.index }
        if best.count >= 2 {
            let a = best[0], b = best[1]
            let close = a.index - b.index < 1.5 && a.lab != "player" && b.lab != "player"
            if a.lab == "player" && s.monthsAtTop >= 2 {
                var v = base
                v["months"] = "\(s.monthsAtTop)"
                topics.append(("amb.board.you", ["player"], v, 1.2))
            } else if close {
                var v = base.merging(Voices.labVars(s, a.lab)) { x, _ in x }
                v["other"] = Cast.short(b.lab)
                topics.append(("amb.board.close", [a.lab, b.lab], v, 1.3))
            } else if a.lab != "player" {
                var v = base.merging(Voices.labVars(s, a.lab)) { x, _ in x }
                v["model"] = a.model
                v["gap"] = Fmt.score(a.index - b.index)
                topics.append(("amb.board.lab", [a.lab], v, 1))
            }
        }
        // Money and mood.
        if RivalEconomy.inCorrection(s) {
            topics.append(("amb.cold", [], base, 1.2))
        } else if s.market.hype > 1.4 {
            topics.append(("amb.hot", [], base, 1))
        }
        if s.market.apiPricePressure < 0.75 { topics.append(("amb.cheap", [], base, 0.6)) }
        // Policy.
        if let b = s.bills.first, let bill = PolicyCatalog.byID[b.id] {
            var v = base
            v.merge(Voices.billVars(bill)) { _, b in b }
            topics.append(("amb.policy", [], v, 1))
        }
        // You.
        if s.reliability < 0.9 && !s.releasedModels.isEmpty { topics.append(("amb.you.outage", ["player"], base, 0.9)) }
        if s.consumerUsers > 1e8 { topics.append(("amb.you.big", ["player"], base, 0.5)) }
        if let last = s.releasedModels.compactMap(\.releaseDate).max(), Cast.days(last, s.date) > 300 {
            topics.append(("amb.you.quiet", ["player"], base, 0.7))
        }
        // A quiet lab.
        if let quiet = s.competitors.filter({ $0.alive && ($0.models.last.map { Cast.days($0.date, s.date) > 300 } ?? false) })
            .min(by: { ($0.models.last?.date ?? .distantPast) < ($1.models.last?.date ?? .distantPast) }) {
            topics.append(("amb.lab.quiet", [quiet.id], base.merging(Voices.labVars(s, quiet.id)) { a, _ in a }, 0.5))
        }
        // Evergreen.
        topics.append(("amb.compute", [], base, 0.8))
        topics.append(("amb.joke", [], base, 1))
        topics.append(("amb.safety", [], base, 0.6))

        // A topic aired in the last six weeks mostly sits out (an outage gets talked about once, not every week), and a
        // line of chatter isn't posted twice in a year — a topic that has run out of fresh lines stays quiet.
        let aired = s.voiceRecent["amb"] ?? []
        func lastAired(_ topic: String) -> Int? { aired.last { $0.hasPrefix(topic + "@") }.flatMap { Int($0.dropFirst(topic.count + 1)) } }
        let n = 1 + Int(roll(s, "ambient-count|\(week)") * 2.6)
        var used: Set<String> = []
        var posted = 0
        for k in 0..<(n + 3) where posted < n {
            let left = topics.filter { !used.contains($0.0) }.map { t -> ((String, [String], [String: String], Double), Double) in
                guard let w = lastAired(t.0) else { return (t, t.3) }
                return (t, week - w < 6 ? t.3 * 0.1 : t.3)
            }
            guard let t = Cast.weighted(s, "pulse|ambient|\(week)|\(k)", left) else { break }
            used.insert(t.0)
            let got = react(&s, t.0, labs: t.1, vars: t.2, key: "amb|\(week)|\(k)", importance: 0.2, count: 1, freshDays: 365, allowStale: false)
            guard got > 0 else { continue }
            posted += got
            var list = (s.voiceRecent["amb"] ?? []).filter { !$0.hasPrefix(t.0 + "@") }
            list.append("\(t.0)@\(week)")
            if list.count > 24 { list.removeFirst(list.count - 24) }
            s.voiceRecent["amb"] = list
        }
        computeBuzz(&s)
    }

    /// Each lab's attention (0–100) and tone over the last `window` days, newer and louder posts counting more.
    static func computeBuzz(_ s: inout GameState) {
        var raw: [String: Double] = [:], toneSum: [String: Double] = [:], count: [String: Int] = [:]
        for p in s.pulse {
            let age = Cast.days(p.date, s.date)
            guard age <= window else { continue }
            let w = exp(-Double(age) / 30) * (0.6 + 0.4 * min(1, log10(1 + Double(p.likes)) / 4))
            for lab in p.labs {
                raw[lab, default: 0] += w
                toneSum[lab, default: 0] += w * p.tone
                count[lab, default: 0] += 1
            }
        }
        var ids = Set(s.competitors.filter { $0.alive }.map(\.id))
        ids.insert("player")
        ids.formUnion(raw.keys)
        var out: [String: LabBuzz] = [:]
        for id in ids {
            var b = s.buzz[id] ?? LabBuzz()
            let r = raw[id] ?? 0
            b.attention = 100 * (1 - exp(-r / 5))
            b.tone = r > 0 ? clamp((toneSum[id] ?? 0) / r, -1, 1) : 0
            b.posts = count[id] ?? 0
            b.trend.append((b.attention * 10).rounded() / 10)
            if b.trend.count > 12 { b.trend.removeFirst(b.trend.count - 12) }
            // Labs that are gone keep their last word but stop trending.
            if b.attention > 0 || id == "player" || s.competitors.contains(where: { $0.id == id && $0.alive }) { out[id] = b }
        }
        s.buzz = out
    }
}
