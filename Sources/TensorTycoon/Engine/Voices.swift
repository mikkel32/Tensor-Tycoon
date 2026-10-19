import Foundation

/// Human voices in the news (3.4). Key stories — launches, records, rounds, listings, takeovers, failures, price wars,
/// safety scares, votes, big builds, career moves — get a headline and a shape picked from several, the facts the old
/// text had (every number), and a quote or two from the people involved: the lab's chief for its launch, an analyst's
/// take, a critic's worry, a rival's jab. Templates are picked by hashed rolls and by context (how the launch compared
/// with the Rival Watch forecast, the margin over #1, the size of a round, who is speaking), and a template used lately
/// sits out for a while. Every story is also passed to the Pulse.
/// Nothing here draws from the game's RNG or changes anything but the news, the cast's quote history and the Pulse.
enum Voices {
    // MARK: Templates

    /// Fills `{name}` placeholders; nil when one isn't known (so templates can depend on optional facts). `{name's}` is the
    /// possessive ("Prometheus's", "Playtest Labs'").
    static func fill(_ t: String, _ vars: [String: String]) -> String? {
        guard t.contains("{") else { return t }
        var out = ""
        out.reserveCapacity(t.count + 40)
        var i = t.startIndex
        while i < t.endIndex {
            let c = t[i]
            if c == "{", let close = t[i...].firstIndex(of: "}") {
                let key = String(t[t.index(after: i)..<close])
                guard var v = key.hasSuffix("'s") ? vars[String(key.dropLast(2))].map(Cast.possessive) : vars[key] else { return nil }
                // A fact that opens a sentence starts with a capital ("The Qiantang Institute will feel it").
                if out.isEmpty || out.hasSuffix(". ") || out.hasSuffix("? ") || out.hasSuffix("! "), let first = v.first, first.isLowercase {
                    v = first.uppercased() + v.dropFirst()
                }
                out += v
                i = t.index(after: close)
            } else {
                out.append(c)
                i = t.index(after: i)
            }
        }
        return out
    }

    /// "B|text" → ("B", "text"). Tags: "*" anyone, a family letter (B C T S W N), or "@voice".
    static func split(_ raw: String) -> (tag: Substring, text: Substring) {
        guard let bar = raw.firstIndex(of: "|") else { return ("*", raw[...]) }
        return (raw[..<bar], raw[raw.index(after: bar)...])
    }

    struct Choice {
        let id: String
        let text: String
    }

    /// Lines from `bank` that suit `voice` (nil: only lines for anyone) and whose facts are all known, weighted: a line
    /// written for the exact voice beats one for its family, which beats one for anyone.
    static func candidates(_ bank: String, _ vars: [String: String], voice: VoiceStyle?) -> [(Choice, Double)] {
        guard let lines = VoiceBank.lines[bank] else { return [] }
        var out: [(Choice, Double)] = []
        for (k, raw) in lines.enumerated() {
            let (tag, text) = split(raw)
            let w: Double
            if tag == "*" {
                w = 1
            } else if let v = voice {
                if tag.first == "@" {
                    guard tag.dropFirst() == v.rawValue else { continue }
                    w = 4
                } else {
                    guard tag.count == 1, tag.first == v.family.tag else { continue }
                    w = 2
                }
            } else {
                continue
            }
            guard let filled = fill(String(text), vars) else { continue }
            out.append((Choice(id: "\(bank)#\(k)", text: filled), w))
        }
        return out
    }

    /// One line from `bank`: suits the voice, all facts known, not used lately. Remembers it. Headlines and narration fall
    /// back on a recent line when every line was used lately; a quote (`speaker` set) doesn't — nobody repeats themselves within
    /// a year and a half, and a line rests for months between speakers — so the story quotes someone else, or nobody.
    static func pick(_ s: inout GameState, _ bank: String, _ vars: [String: String], voice: VoiceStyle? = nil, key: String,
                     speaker: String? = nil) -> String? {
        var cands = candidates(bank, vars, voice: voice)
        guard !cands.isEmpty else { return nil }
        let recent = Set(s.voiceRecent[bank] ?? [])
        let size = VoiceBank.lines[bank]?.count ?? 2
        let today = RivalIntel.dayIndex(s.date)
        if let speaker {
            // Each quote line keeps a short log of who said it when ("day:speaker"): a line rests 200 days between
            // speakers (a year if it was written for anyone) and a year and a half for the same person.
            cands = cands.filter { c in
                let log = s.voiceRecent["said|" + c.0.id] ?? []
                guard let last = log.last, let day = Int(last.prefix { $0 != ":" }) else { return true }
                if today - day <= (c.1 == 1 ? 365 : 200) { return false }
                return !log.contains { e in e.hasSuffix(":" + speaker) && (Int(e.prefix { $0 != ":" }).map { today - $0 <= 540 } ?? false) }
            }
            guard !cands.isEmpty else { return nil }
        } else {
            let fresh = cands.filter { !recent.contains($0.0.id) }
            if !fresh.isEmpty { cands = fresh }
        }
        guard let choice = Cast.weighted(s, "voice|\(bank)|\(key)", cands) else { return nil }
        if let speaker {
            // Four entries span at least 600 days, more than any rest period.
            remember(&s, "said|" + choice.id, "\(today):\(speaker)", keep: 4)
        } else {
            remember(&s, bank, choice.id, keep: max(1, min(8, size * 2 / 3)))
        }
        return choice.text
    }

    /// True when `name` hasn't happened in the last `days` days. Records that it happened today either way, so a burst
    /// (five benchmarks saturating in a week) gets the full treatment once.
    static func cooled(_ s: inout GameState, _ name: String, days: Int) -> Bool {
        let today = RivalIntel.dayIndex(s.date)
        var list = s.voiceRecent["cooldown"] ?? []
        let tag = name + "@"
        let last = list.last { $0.hasPrefix(tag) }.flatMap { Int($0.dropFirst(tag.count)) }
        list.removeAll { $0.hasPrefix(tag) }
        list.append("\(tag)\(today)")
        if list.count > 40 { list.removeFirst(list.count - 40) }
        s.voiceRecent["cooldown"] = list
        return last.map { today - $0 >= days } ?? true
    }

    static func remember(_ s: inout GameState, _ bank: String, _ id: String, keep: Int) {
        var list = s.voiceRecent[bank] ?? []
        list.removeAll { $0 == id }
        list.append(id)
        if list.count > keep { list.removeFirst(list.count - keep) }
        s.voiceRecent[bank] = list
    }

    // MARK: Quotes

    /// A quote from `p` out of `bank`, attributed in one of several shapes. Nil when nothing in the bank suits them.
    static func quote(_ s: inout GameState, _ bank: String, _ p: CastMember, _ vars: [String: String], key: String) -> String? {
        var v = vars
        if Cast.isLab(p.org) { v["mylab"] = Cast.short(p.org) }
        guard let q = pick(&s, bank, v, voice: p.voiceStyle, key: "\(key)|\(p.id)", speaker: p.id) else { return nil }
        remember(&s, "speakers", p.id, keep: 6)
        return attribute(s, q, p, key: key)
    }

    static let lq = "\u{201C}", rq = "\u{201D}"

    /// “Quote,” said Name, who they are.  /  Name, who they are, said: “Quote.”  /  and a few shapes that suit the voice.
    static func attribute(_ s: GameState, _ q: String, _ p: CastMember, key: String) -> String {
        shape(q, name: p.name, desc: Cast.desc(p, s), family: p.voiceStyle.family, roll: Cast.roll(s, "attr|\(key)|\(p.id)"))
    }

    static func shape(_ q: String, name: String, desc d: String, family: VoiceFamily, roll r: Double) -> String {
        let ends = q.last.map { "?!".contains($0) } ?? false
        let lead = ends ? q : (q.hasSuffix(".") ? String(q.dropLast()) + "," : q + ",")
        let full = (q.last.map { ".?!".contains($0) } ?? false) ? q : q + "."
        // With no description (someone the story has already introduced) the name stands alone: "Kearney said".
        let who = d.isEmpty ? name : "\(name), \(d),"
        let whoEnd = d.isEmpty ? name : "\(name), \(d)"
        let Who = who.prefix(1).uppercased() + who.dropFirst()
        if r < 0.36 { return "\(lq)\(lead)\(rq) said \(whoEnd)." }
        if r < 0.6 || (d.isEmpty && family == .skeptic) { return "\(Who) said: \(lq)\(full)\(rq)" }
        if r < 0.75 { return "\(lq)\(lead)\(rq) \(who) said." }
        switch family {
        case .bold: return "\(Who) didn't hedge: \(lq)\(full)\(rq)"
        case .terse: return "\(Who) said only: \(lq)\(full)\(rq)"
        case .worried: return "\(Who) warned: \(lq)\(full)\(rq)"
        case .numbers: return "\(lq)\(lead)\(rq) wrote \(whoEnd)."
        case .careful: return "\(lq)\(lead)\(rq) \(who) said in a statement."
        case .skeptic: return "\(Who) was unconvinced by the fuss: \(lq)\(full)\(rq)"
        }
    }

    /// Up to two quotes: the first perspective that yields one, then (usually) one more from the rest.
    static func quotes(_ s: inout GameState, _ options: [(bank: String, speaker: CastMember?)], vars: [String: String], key: String,
                       second: Double = 0.65) -> [String] {
        var out: [String] = []
        var used: Set<String> = []
        for (k, o) in options.enumerated() {
            guard let p = o.speaker, !used.contains(p.id) else { continue }
            if out.count == 1 && Cast.roll(s, "second|\(key)") > second { break }
            if let q = quote(&s, o.bank, p, vars, key: "\(key)|\(k)") {
                out.append(q)
                used.insert(p.id)
            }
            if out.count >= 2 { break }
        }
        return out
    }

    /// Post the story: facts first, then quotes, kept to a readable length.
    static func post(_ s: inout GameState, title: String, facts: [String], quotes: [String], _ cat: NewsCategory, image: String? = nil,
                     important: Bool = false, good: Bool? = nil) {
        var body = facts.filter { !$0.isEmpty }.joined(separator: " ")
        for (k, q) in quotes.enumerated() {
            if k > 0 && body.count + q.count > 560 { break }
            body += " " + q
        }
        Sim.news(&s, title, body, cat, image: image, important: important, good: good)
    }

    // MARK: Speakers

    /// Someone who reads the industry's numbers for a living: an analyst, or a journalist who writes analysis (reporters
    /// report; they aren't quoted for opinions). The threat researcher only talks about security.
    static func analyst(_ s: GameState, _ key: String, avoid: [String] = []) -> CastMember? {
        Cast.find(s, key: "analyst|\(key)", avoid: avoid) { isAnalyst($0) }
    }

    static func isAnalyst(_ p: CastMember) -> Bool {
        (p.castKind == .analyst || (p.castKind == .journalist && p.voiceStyle == .numbers)) && p.focus != "security"
    }

    static func critic(_ s: GameState, _ key: String) -> CastMember? {
        Cast.find(s, key: "critic|\(key)") { $0.castKind == .critic || ($0.castKind == .academic && $0.voiceStyle.family == .skeptic) }
    }

    /// A sceptic: someone outside the labs, or one of the few famous in-house sceptics — never from the labs in the story.
    static func skeptic(_ s: GameState, _ key: String, not labs: [String] = []) -> CastMember? {
        Cast.find(s, key: "skeptic|\(key)") { p in
            guard p.voiceStyle.family == .skeptic, !labs.contains(p.org), p.castKind != .free, p.org != "player" else { return false }
            return !p.castKind.atLab || (p.stature >= 0.6 && CastCatalog.byID[p.id] != nil)
        }
    }

    static func academic(_ s: GameState, _ key: String) -> CastMember? {
        Cast.find(s, key: "academic|\(key)") { $0.castKind == .academic || ($0.castKind == .critic && $0.voiceStyle == .professor) }
    }

    static func investor(_ s: GameState, fund: String, _ key: String) -> CastMember? {
        if let id = CastCatalog.fundVoices[fund], let p = Cast.person(s, id: id), p.active, p.org == fund { return p }
        if let p = s.cast.first(where: { $0.active && $0.castKind == .investor && $0.org == fund }) { return p }
        return nil
    }

    static func anyInvestor(_ s: GameState, _ key: String) -> CastMember? {
        Cast.find(s, key: "investor|\(key)") { $0.castKind == .investor && NameBank.investors.contains($0.org) }
    }

    static func official(_ s: GameState, _ key: String, _ test: (CastMember) -> Bool = { _ in true }) -> CastMember? {
        Cast.find(s, key: "official|\(key)") { $0.castKind == .official && test($0) }
    }

    /// A leader of another lab with something to lose: the strongest other labs first.
    static func rival(_ s: GameState, excluding: [String], _ key: String) -> CastMember? {
        let labs = s.competitors.filter { $0.alive && !excluding.contains($0.id) && !$0.models.isEmpty }
            .sorted { ($0.models.map(\.index).max() ?? 0) > ($1.models.map(\.index).max() ?? 0) }.prefix(4).map(\.id)
        let pool = labs.compactMap { Cast.voice(s, $0) }
        return Cast.weighted(s, "rival|\(key)", pool.map { ($0, 0.5 + $0.stature) })
    }

    /// The leader who just left a lab that closed (for its farewell).
    static func former(_ s: GameState, of lab: String) -> CastMember? {
        s.cast.filter { $0.lastLab == lab && $0.org != lab }.max { $0.since < $1.since }
            .flatMap { p in p.history.first.map { $0.date == s.date } == true ? p : nil }
    }

    // MARK: Shared facts

    static func base(_ s: GameState) -> [String: String] {
        ["you": s.companyName, "founder": s.founderName, "year": "\(s.date.ym.year)"]
    }

    static func labVars(_ s: GameState, _ id: String, prefix: String = "") -> [String: String] {
        let def = CompetitorCatalog.def(id)
        return ["\(prefix)lab": Cast.short(id), "\(prefix)labfull": def.name, "\(prefix)hq": def.hq, "\(prefix)product": def.chatProduct]
    }

    // MARK: Rival launches

    /// A rival lab ships a model. Keeps every fact of the old story: the index, the top benchmarks, the price, whether it
    /// takes #1 and what open weights do to prices.
    static func rivalLaunch(_ s: inout GameState, _ i: Int, model: CompetitorModel, index: Double, details: [String], isTop: Bool,
                            openNote: String, forecast: RivalOutlook?) {
        let c = s.competitors[i]
        let id = c.id
        let key = "rlaunch|\(id)|\(c.releaseCount)"
        var v = base(s).merging(labVars(s, id)) { a, _ in a }
        v["model"] = model.name
        v["index"] = Fmt.score(index)
        v["price"] = Fmt.price(model.price)
        if !details.isEmpty {
            v["details"] = details.count == 1 ? details[0] : details.dropLast().joined(separator: ", ") + " and " + details.last!
            v["detailsDots"] = details.joined(separator: " · ")
        }
        // The best model before this one, anywhere.
        var prev: (name: String, lab: String, index: Double)? = nil
        for o in s.competitors where o.id != id {
            for m in o.models where m.index > (prev?.index ?? -1) { prev = (m.name, Cast.short(o.id), m.index) }
        }
        for m in s.releasedModels where m.index > (prev?.index ?? -1) { prev = (m.name, s.companyName, m.index) }
        let ownBest = c.models.filter { $0.id != model.id }.map(\.index).max() ?? 0
        if let p = prev, p.index > ownBest {
            v["prev"] = p.name
            v["prevlab"] = p.lab
            if index > p.index { v["margin"] = Fmt.score(index - p.index) }
        }
        if let mine = s.releasedModels.max(by: { $0.index < $1.index }) {
            v["mine"] = mine.name
            v["mineindex"] = Fmt.score(mine.index)
            v["gap"] = Fmt.score(abs(index - mine.index))
        }
        var surprise = 0.0
        if let f = forecast {
            surprise = index - f.index
            v["forecast"] = Fmt.score(f.index)
            v["delta"] = Fmt.score(abs(surprise))
        }
        let beat = forecast != nil && surprise >= 2.5
        let miss = forecast != nil && surprise <= -2.5
        let first = c.models.count <= 1 && c.spec != nil

        // Headline
        let titleBank = isTop ? "rlaunch.title.top" : (model.open && Cast.roll(s, key + "|ot") < 0.6 ? "rlaunch.title.open"
            : (beat ? "rlaunch.title.beat" : (miss ? "rlaunch.title.miss" : "rlaunch.title.plain")))
        let title = pick(&s, titleBank, v, key: key) ?? "\(c.def.name) releases \(model.name)\(isTop ? " — new #1" : "")"

        // Facts, then what they mean.
        var facts: [String] = []
        facts.append(pick(&s, v["details"] == nil ? "rlaunch.lead.nodetails" : "rlaunch.lead", v, key: key)
                     ?? "Intelligence Index \(Fmt.score(index)). API price \(Fmt.price(model.price))/M tokens.")
        if !openNote.isEmpty { facts.append(pick(&s, "rlaunch.open", v, key: key) ?? openNote.trimmingCharacters(in: .whitespaces)) }
        if isTop, v["margin"] != nil, let t = pick(&s, "rlaunch.ctx.top", v, key: key) {
            facts.append(t)
        } else if beat, let t = pick(&s, "rlaunch.ctx.beat", v, key: key) {
            facts.append(t)
        } else if miss, let t = pick(&s, "rlaunch.ctx.miss", v, key: key) {
            facts.append(t)
        } else if forecast != nil && abs(surprise) < 1, Cast.roll(s, key + "|inline") < 0.4, let t = pick(&s, "rlaunch.ctx.inline", v, key: key) {
            facts.append(t)
        }

        // Who speaks: the lab first, then whoever has the most to say about it.
        let me = Cast.voice(s, id)
        let selfBank = first ? "rlaunch.self.first" : (model.open && c.def.openWeights ? "rlaunch.self.open" : (isTop ? "rlaunch.self.top" : "rlaunch.self.plain"))
        var others: [(bank: String, speaker: CastMember?)] = []
        let r = Cast.roll(s, key + "|who")
        if isTop {
            if r < 0.4 { others.append(("rlaunch.rival.top", rival(s, excluding: [id], key))) }
            if r < 0.7 { others.append(("rlaunch.critic", critic(s, key))) }
            others.append(("rlaunch.analyst.top", analyst(s, key)))
            others.append(("rlaunch.rival.top", rival(s, excluding: [id], key)))
        } else if beat {
            others.append(("rlaunch.analyst.beat", analyst(s, key)))
        } else if miss {
            others.append(("rlaunch.analyst.miss", analyst(s, key)))
        } else if model.open {
            others.append((r < 0.5 ? "rlaunch.analyst.open" : "rlaunch.analyst.price", analyst(s, key)))
        } else if r < 0.3 {
            others.append(("rlaunch.skeptic", r < 0.15 ? academic(s, key) : skeptic(s, key, not: [id])))
        } else if r < 0.6 {
            others.append(("rlaunch.analyst.price", analyst(s, key)))
        } else if forecast != nil {
            others.append(("rlaunch.analyst.inline", analyst(s, key)))
        }
        others.append(("rlaunch.skeptic", skeptic(s, key, not: [id])))
        let qs = quotes(&s, [(selfBank, me)] + others, vars: v, key: key, second: isTop ? 0.85 : 0.55)
        post(&s, title: title, facts: facts, quotes: qs, .competitor, important: isTop)
        Pulse.react(&s, isTop ? "rlaunch.top" : (miss ? "rlaunch.miss" : (model.open ? "rlaunch.open" : "rlaunch")), labs: [id], vars: v,
                    key: key, importance: isTop ? 1 : 0.5)
    }

    // MARK: Your launches

    /// You ship a model. Keeps the index and the rank; adds how it was launched, who led the work and what others think.
    static func playerLaunch(_ s: inout GameState, _ i: Int, rank: Int, previousBest: Double?, style: LaunchStyle) {
        let m = s.models[i]
        let key = "plaunch|\(m.id.uuidString)"
        var v = base(s)
        v["model"] = m.name
        v["index"] = Fmt.score(m.index)
        v["rank"] = "\(rank)"
        if let p = previousBest, m.index > p { v["jump"] = Fmt.score(m.index - p) }
        var leader: (lab: String, name: String, index: Double)? = nil
        for c in s.competitors where c.alive {
            for cm in c.models where cm.index > (leader?.index ?? -1) { leader = (c.id, cm.name, cm.index) }
        }
        if let l = leader {
            v["prev"] = l.name
            v["prevlab"] = Cast.short(l.lab)
            if m.index > l.index { v["margin"] = Fmt.score(m.index - l.index) }
        }
        let top = rank == 1
        let title = pick(&s, top ? "plaunch.title.top" : "plaunch.title.plain", v, key: key) ?? "\(s.companyName) releases \(m.name)"
        var facts = [pick(&s, "plaunch.lead", v, key: key) ?? "Intelligence Index \(Fmt.score(m.index)) — #\(rank) on the leaderboard."]
        switch style {
        case .keynote: facts.append(pick(&s, "plaunch.style.keynote", v, key: key) ?? "")
        case .blitz: facts.append(pick(&s, "plaunch.style.blitz", v, key: key) ?? "")
        case .staged: facts.append(pick(&s, "plaunch.style.staged", v, key: key) ?? "")
        case .standard: break
        // 3.7: launch strategies
        case .stealth: facts.append(pick(&s, "plaunch.style.stealth", v, key: key) ?? "")
        case .openWeights: facts.append(pick(&s, "plaunch.style.open", v, key: key) ?? "")
        case .enterprise: facts.append(pick(&s, "plaunch.style.enterprise", v, key: key) ?? "")
        case .government: facts.append(pick(&s, "plaunch.style.government", v, key: key) ?? "")
        }
        if top, v["margin"] != nil, let t = pick(&s, "plaunch.ctx.top", v, key: key) {
            facts.append(t)
        } else if v["jump"] != nil, Cast.roll(s, key + "|jump") < 0.5, let t = pick(&s, "plaunch.ctx.jump", v, key: key) {
            facts.append(t)
        }
        // The researcher who led the work speaks first, sometimes.
        var qs: [String] = []
        if let lead = s.employees.filter({ $0.role == .researcher }).max(by: { $0.skill < $1.skill }), Cast.roll(s, key + "|staff") < 0.45,
           let line = pick(&s, "plaunch.staff", v, key: key) {
            let what = Cast.pick(s, key + "|led", ["who led the work", "who ran the training", "who led the research team", "the project's research lead"]) ?? "who led the work"
            qs.append(shape(line, name: lead.name, desc: what, family: .careful, roll: Cast.roll(s, key + "|staffshape") * 0.75))
        }
        let leaderLab = leader?.lab ?? ""
        let rivalVoice = top && !leaderLab.isEmpty ? Cast.voice(s, leaderLab) : rival(s, excluding: [], key)
        let bank = top ? "plaunch.analyst.top" : (rank <= 5 ? "plaunch.analyst.mid" : "plaunch.analyst.low")
        var options: [(bank: String, speaker: CastMember?)] = [(bank, analyst(s, key))]
        if rank <= 3 { options.insert(("plaunch.rival.top", rivalVoice), at: Cast.roll(s, key + "|order") < 0.5 ? 0 : 1) }
        if top { options.append(("plaunch.critic", critic(s, key))) }
        qs += quotes(&s, options, vars: v, key: key, second: qs.isEmpty ? 0.7 : 0)
        post(&s, title: title, facts: facts, quotes: Array(qs.prefix(2)), .company, image: "sf_skyline", important: true, good: true)
        Pulse.react(&s, top ? "plaunch.top" : "plaunch", labs: ["player"], vars: v, key: key, importance: top ? 1 : 0.6)
    }

    // MARK: Benchmarks

    /// A benchmark saturated. Keeps the old story; adds a word from the people who build benchmarks. `labNames` are the
    /// two labs that got there (yours by its company name).
    static func saturated(_ s: inout GameState, bench: String, title: String, body: String, labs labNames: [String]) {
        let key = "saturate|\(bench)|\(s.date.ym.year)"
        var v = base(s)
        v["bench"] = bench
        let labs = labNames.compactMap { name in name == s.companyName ? "player" : s.competitors.first { $0.def.name == name }?.id }
        let t = pick(&s, "saturate.title", v, key: key) ?? title
        // Benchmarks often fall in bunches; the people who build them comment on the first, not on every one.
        let fresh = cooled(&s, "saturate", days: 30)
        let qs = fresh && Cast.roll(s, key + "|q") < 0.5
            ? quotes(&s, [("saturate.academic", academic(s, key)), ("saturate.skeptic", skeptic(s, key))], vars: v, key: key, second: 0.35) : []
        post(&s, title: t, facts: [body], quotes: qs, .research, image: "wafer_closeup")
        if fresh { Pulse.react(&s, "saturate", labs: labs, vars: v, key: key, importance: 0.4, count: 2) }
    }

    // MARK: Money

    /// A rival lab raises a round (after October 2026).
    static func round(_ s: inout GameState, _ i: Int, amount: Double, post postMoney: Double, label: String, lead: String, down: Bool,
                      prevPost: Double, runway: Int?, title: String, body: String) {
        let c = s.competitors[i]
        let key = "round|\(c.id)|\(c.rounds.count)"
        var v = base(s).merging(labVars(s, c.id)) { a, _ in a }
        v["amount"] = Fmt.money(amount)
        v["post"] = Fmt.money(postMoney)
        v["label"] = label
        v["lead"] = lead
        if prevPost > 0 { v["prevpost"] = Fmt.money(prevPost) }
        if let runway { v["runway"] = "\(runway)" }
        if c.revenueRun > 1e7 { v["multiple"] = "\(Int((postMoney / c.revenueRun).rounded()))" }
        let t = pick(&s, down ? "round.title.down" : "round.title", v, key: key) ?? title
        var facts = [body]
        if !down, isRecordRound(s, amount, excluding: c.id), let rec = pick(&s, "round.ctx.record", v, key: key) { facts.append(rec) }
        let me = Cast.voice(s, c.id)
        let options: [(bank: String, speaker: CastMember?)] = down
            ? [("round.down.analyst", analyst(s, key)), ("round.down.self", me)]
            : [(Cast.roll(s, key + "|first") < 0.5 ? "round.investor" : "round.self", Cast.roll(s, key + "|first") < 0.5 ? investor(s, fund: lead, key) : me),
               ("round.self", me), ("round.analyst", analyst(s, key))]
        let qs = quotes(&s, options, vars: v, key: key, second: 0.5)
        post(&s, title: t, facts: facts, quotes: qs, .finance, image: "stock_exchange")
        Pulse.react(&s, down ? "round.down" : "round", labs: [c.id], vars: v, key: key, importance: down ? 0.5 : min(1, amount / 2e10))
    }

    static func isRecordRound(_ s: GameState, _ amount: Double, excluding: String) -> Bool {
        let rivals = s.competitors.flatMap { c in c.rounds.filter { $0.kind == .equity || $0.kind == .strategic }.map(\.amount) }
        let mine = s.rounds.map(\.amount)
        return amount > (rivals + mine).filter { $0 != amount }.max() ?? .infinity
    }

    /// A lab's historical round (before October 2026): an analyst's read on it.
    static func historicRound(_ s: inout GameState, _ i: Int, amount: Double, title: String, body: String) {
        let c = s.competitors[i]
        let key = "hround|\(c.id)|\(c.historyIndex)"
        var v = base(s).merging(labVars(s, c.id)) { a, _ in a }
        v["amount"] = Fmt.money(amount)
        let qs = Cast.roll(s, key) < 0.6 ? quotes(&s, [("hround.analyst", analyst(s, key))], vars: v, key: key) : []
        post(&s, title: title, facts: [body.trimmingCharacters(in: .whitespaces)], quotes: qs, .finance, image: "stock_exchange")
        Pulse.react(&s, "round", labs: [c.id], vars: v, key: key, importance: min(1, amount / 2e10), count: 1)
    }

    /// A rival lists its shares.
    static func ipo(_ s: inout GameState, _ i: Int, value: Double, title: String, body: String) {
        let c = s.competitors[i]
        let key = "ipo|\(c.id)"
        var v = base(s).merging(labVars(s, c.id)) { a, _ in a }
        v["value"] = Fmt.money(value)
        let t = pick(&s, "ipo.title", v, key: key) ?? title
        let qs = quotes(&s, [("ipo.self", Cast.voice(s, c.id)), ("ipo.analyst", analyst(s, key)), ("ipo.analyst", skeptic(s, key, not: [c.id]))], vars: v, key: key)
        post(&s, title: t, facts: [body], quotes: qs, .finance, image: "stock_exchange", important: true)
        Pulse.react(&s, "ipo", labs: [c.id], vars: v, key: key, importance: 0.8)
    }

    // MARK: Stories about a lab

    /// A story about a lab with a fixed set of facts (`body` is kept word for word): distress, bankruptcy, a rescue, a sale
    /// to a giant, a takeover, a merger, a wind-down, a blocked bid. `lab` is the lab it's about, `other` the buyer or partner.
    static func labStory(_ s: inout GameState, _ kind: String, lab: String, other: String = "", title: String, body: String,
                         _ cat: NewsCategory, image: String? = nil, important: Bool = false, good: Bool? = nil, vars extra: [String: String] = [:]) {
        let key = "\(kind)|\(lab)|\(other)|\(Cast.monthIndex(s))"
        var v = base(s).merging(labVars(s, lab)) { a, _ in a }.merging(extra) { _, b in b }
        if !other.isEmpty && Cast.isLab(other) { v = v.merging(labVars(s, other, prefix: "other")) { a, _ in a } }
        v["target"] = v["lab"]
        v["buyer"] = v["otherlab"]
        let t = pick(&s, "\(kind).title", v, key: key) ?? title
        let me = Cast.voice(s, lab) ?? former(s, of: lab)
        let them = other.isEmpty ? nil : Cast.voice(s, other)
        var options: [(bank: String, speaker: CastMember?)] = []
        switch kind {
        case "takeover":
            options = Cast.roll(s, key) < 0.5 ? [("takeover.buyer", them), ("takeover.target", former(s, of: lab) ?? me), ("takeover.analyst", analyst(s, key))]
                                              : [("takeover.analyst", analyst(s, key)), ("takeover.buyer", them), ("takeover.target", former(s, of: lab) ?? me)]
        case "merge":
            options = [("merge.self", them), ("merge.analyst", analyst(s, key))]
        case "winddown", "bankrupt":
            options = [("\(kind).self", former(s, of: lab)), ("\(kind).analyst", analyst(s, key)), ("\(kind).analyst", skeptic(s, key, not: [lab, other]))]
        case "blocked":
            options = [("blocked.self", me), ("blocked.analyst", Cast.find(s, key: key) { $0.castKind == .journalist })]
        default:
            options = [("\(kind).analyst", analyst(s, key)), ("\(kind).analyst", skeptic(s, key, not: [lab, other]))]
        }
        let qs = quotes(&s, options, vars: v, key: key, second: 0.6)
        post(&s, title: t, facts: [body], quotes: qs, cat, image: image, important: important, good: good)
        Pulse.react(&s, kind, labs: other.isEmpty ? [lab] : [lab, other], vars: v, key: key, importance: important ? 0.8 : 0.4)
    }

    /// A lab founded during the game: the founder takes charge in the cast, then the news, with the founder's words.
    static func founded(_ s: inout GameState, _ spec: CustomLabSpec, event: RivalEvent.Kind, title: String, body: String, image: String?) {
        Cast.labFounded(&s, spec)
        let key = "founded|\(spec.id)"
        var v = base(s).merging(labVars(s, spec.id)) { a, _ in a }
        v["founder"] = spec.ceo
        v["thesis"] = spec.thesis
        if !spec.parentName.isEmpty { v["parent"] = spec.parentID == "player" ? s.companyName : spec.parentName }
        if !spec.backer.isEmpty { v["backer"] = spec.backer.prefix(1).uppercased() + spec.backer.dropFirst() }
        if let r = s.competitors.first(where: { $0.id == spec.id })?.rounds.first {
            v["amount"] = Fmt.money(r.amount)
            v["lead"] = r.lead
        }
        let flavour = spec.kind == .sovereign ? "sovereign" : (spec.parentID == "player" ? "alumni" : (spec.kind == .spinout ? "spinout" : "startup"))
        let t = pick(&s, "founded.title.\(flavour)", v, key: key) ?? title
        let founder = Cast.leader(s, spec.id)
        let founderBank = flavour == "sovereign" ? "founded.founder.sovereign" : (flavour == "alumni" ? "founded.founder.alumni" : "founded.founder")
        let backer = v["lead"].flatMap { investor(s, fund: $0, key) }
        let analystBank = flavour == "sovereign" ? "founded.analyst.sovereign" : "founded.analyst"
        let qs = quotes(&s, [(founderBank, founder), ("founded.investor", backer), (analystBank, analyst(s, key))], vars: v, key: key, second: 0.55)
        post(&s, title: t, facts: [body], quotes: qs, .competitor, image: image, important: true)
        Pulse.react(&s, "founded", labs: [spec.id], vars: v, key: key, importance: 0.7)
    }

    // MARK: Prices and open weights

    static func priceWar(_ s: inout GameState, _ i: Int, title: String, body: String, monthly: Bool, cut: Double = 0) {
        let c = s.competitors[i]
        let kind = monthly ? "priceslash" : "pricewar"
        let key = "\(kind)|\(c.id)|\(Cast.monthIndex(s))"
        var v = base(s).merging(labVars(s, c.id)) { a, _ in a }
        if cut > 0 { v["cut"] = "\(Int(cut * 100))" }
        let t = pick(&s, "\(kind).title", v, key: key) ?? title
        let qs = quotes(&s, [("\(kind).self", Cast.voice(s, c.id)), ("\(kind).analyst", analyst(s, key))], vars: v, key: key, second: 0.6)
        post(&s, title: t, facts: [body], quotes: qs, monthly ? .market : .competitor, important: true, good: false)
        Pulse.react(&s, "pricewar", labs: [c.id], vars: v, key: key, importance: 0.6)
    }

    static func openRelease(_ s: inout GameState, _ i: Int, model: String, title: String, body: String) {
        let c = s.competitors[i]
        let key = "openrelease|\(c.id)|\(model)"
        var v = base(s).merging(labVars(s, c.id)) { a, _ in a }
        v["model"] = model
        let t = pick(&s, c.def.openWeights ? "openrelease.title.open" : "openrelease.title", v, key: key) ?? title
        let qs = quotes(&s, [("openrelease.self", Cast.voice(s, c.id)), (Cast.roll(s, key) < 0.5 ? "openrelease.critic" : "openrelease.analyst",
                                                                          Cast.roll(s, key) < 0.5 ? critic(s, key) : analyst(s, key))],
                        vars: v, key: key, second: 0.7)
        post(&s, title: t, facts: [body], quotes: qs, .competitor, important: true, good: false)
        Pulse.react(&s, "openrelease", labs: [c.id], vars: v, key: key, importance: 0.6)
    }

    // MARK: Safety and security

    /// Your model shipped below its safety bar.
    static func unsafeRelease(_ s: inout GameState, model: String, title: String, body: String) {
        let key = "unsafe|\(model)"
        var v = base(s)
        v["model"] = model
        let t = pick(&s, "unsafe.title", v, key: key) ?? title
        let qs = quotes(&s, [("unsafe.critic", critic(s, key)), ("unsafe.official", official(s, key))], vars: v, key: key, second: 0.6)
        post(&s, title: t, facts: [body], quotes: qs, .company, important: true, good: false)
        Pulse.react(&s, "unsafe", labs: ["player"], vars: v, key: key, importance: 0.8)
    }

    /// Your weights were leaked or stolen.
    static func leak(_ s: inout GameState, model: String, stolen: Bool, title: String, body: String, cat: NewsCategory) {
        let key = "leak|\(model)|\(s.thefts)"
        var v = base(s)
        v["model"] = model
        let t = pick(&s, stolen ? "leak.title.stolen" : "leak.title", v, key: key) ?? title
        let security = Cast.find(s, key: key) { $0.focus == "security" } ?? analyst(s, key)
        let qs = quotes(&s, [("leak.security", security), ("leak.official", official(s, key))], vars: v, key: key, second: 0.5)
        post(&s, title: t, facts: [body], quotes: qs, cat, image: "network", important: true, good: false)
        Pulse.react(&s, "leak", labs: ["player"], vars: v, key: key, importance: 0.8)
    }

    // MARK: Policy

    /// Whether someone backs a bill.
    static func backs(_ id: String, _ safetyBill: Bool, _ p: CastMember) -> Bool {
        switch id {
        case "preemption": return p.regulation < 0
        case "permitting": return p.regulation < 0.5
        case "copyright": return p.regulation > 0.5
        case "nairr": return p.open > 0 || p.regulation > 0
        case "dc_moratorium": return p.regulation > 0.6
        default: return safetyBill ? p.regulation > 0.2 : p.regulation > 0
        }
    }

    /// A bill's facts for templates: its name with an article ("the AI Liability Act", "the Frontier Compute Licensing
    /// bill"), and gates for lines that only suit a safety bill ({ifsafety}) or one that loosens rules ({ifdereg}).
    static func billVars(_ bill: PolicyCatalog.Bill) -> [String: String] {
        let name = bill.title.hasSuffix("Act") ? bill.title : bill.title + " bill"
        var v = ["bill": bill.title, "billid": bill.id, "billsafety": bill.safetyBill ? "1" : "0", "thebill": "the \(name)", "Thebill": "The \(name)"]
        if bill.safetyBill { v["ifsafety"] = "" }
        if bill.id == "preemption" || bill.id == "permitting" { v["ifdereg"] = "" }
        return v
    }

    static func billVote(_ s: inout GameState, _ bill: PolicyCatalog.Bill, passed: Bool, sponsor: String, title: String, body: String, good: Bool?) {
        let key = "bill|\(bill.id)"
        var v = base(s)
        v.merge(billVars(bill)) { _, b in b }
        let t = pick(&s, passed ? "bill.title.pass" : "bill.title.fail", v, key: key) ?? title
        let us = s.cast.filter { $0.active && $0.castKind == .official && $0.region == "US" }
        let forIt = us.filter { backs(bill.id, bill.safetyBill, $0) }
        let against = us.filter { !backs(bill.id, bill.safetyBill, $0) }
        let winners = passed ? forIt : against
        let losers = passed ? against : forIt
        var options: [(bank: String, speaker: CastMember?)] = [
            ("bill.\(passed ? "pass" : "fail").\(passed ? "for" : "against")", Cast.weighted(s, key + "|w", winners.map { ($0, 0.3 + $0.stature) })),
            ("bill.\(passed ? "pass" : "fail").\(passed ? "against" : "for")", Cast.weighted(s, key + "|l", losers.map { ($0, 0.3 + $0.stature) })),
        ]
        if bill.safetyBill { options.insert(("bill.critic.\(passed ? "pass" : "fail")", critic(s, key)), at: Cast.roll(s, key + "|c") < 0.5 ? 0 : 1) }
        if bill.safetyBill && ["transparency", "liability", "kill_switch", "independent_auditors"].contains(bill.id), Cast.roll(s, key + "|eu") < 0.35 {
            options.append(("bill.eu", official(s, key) { $0.region == "EU" }))
        }
        if !sponsor.isEmpty, let lab = s.competitors.first(where: { $0.def.name == sponsor }) {
            options.insert(("bill.sponsor.\(passed ? "pass" : "fail")", Cast.voice(s, lab.id)), at: 1)
        }
        let qs = quotes(&s, options, vars: v, key: key, second: 0.6)
        post(&s, title: t, facts: [body], quotes: qs, .policy, image: "stock_exchange", important: true, good: good)
        Pulse.react(&s, passed ? "bill.pass" : "bill.fail", labs: [], vars: v, key: key, importance: 0.6)
    }

    // MARK: Building

    static func groundbreaking(_ s: inout GameState, site: String, mw: Double, place: String, title: String, body: String) {
        let key = "build|\(site)|\(Cast.monthIndex(s))"
        var v = base(s)
        v["site"] = site
        v["mw"] = Fmt.watts(mw * 1e6)
        v["place"] = place
        let t = pick(&s, "build.title", v, key: key) ?? title
        var facts = [body]
        if mw >= 100, Cast.roll(s, key + "|local") < 0.6, let local = pick(&s, "build.ctx.local", v, key: key) { facts.append(local) }
        let numbers = Cast.find(s, key: key) { $0.focus == "chips and datacentres" || $0.focus == "chips and AI labs" } ?? analyst(s, key)
        let qs = mw >= 50 ? quotes(&s, [("build.numbers", numbers), ("build.critic", critic(s, key))], vars: v, key: key, second: 0.4) : []
        post(&s, title: t, facts: facts, quotes: qs, .company, image: "dc_construction", important: true)
        if mw >= 100 { Pulse.react(&s, "build", labs: ["player"], vars: v, key: key, importance: min(1, mw / 2000)) }
    }

    // MARK: Markets

    static func correction(_ s: inout GameState, wiped: Double, title: String, body: String) {
        let key = "correction|\(Cast.monthIndex(s))"
        var v = base(s)
        v["wiped"] = Fmt.money(wiped)
        if s.industryMultiple > 0 { v["multiple"] = "\(Int(s.industryMultiple))" }
        let t = pick(&s, "correction.title", v, key: key) ?? title
        let bear = Cast.find(s, key: key + "|bear") { $0.focus == "bubbles" } ?? skeptic(s, key)
        let booster = Cast.find(s, key: key + "|boost") { $0.voiceStyle == .booster }
        let qs = quotes(&s, [("correction.bear", bear), ("correction.analyst", analyst(s, key)), ("correction.booster", booster)], vars: v, key: key, second: 0.7)
        post(&s, title: t, facts: [body], quotes: qs, .finance, image: "stock_exchange", important: true, good: false)
        Pulse.react(&s, "correction", labs: [], vars: v, key: key, importance: 1)
    }

    static func playerRound(_ s: inout GameState, round: String, amount: Double, post postMoney: Double, lead: String, title: String, body: String) {
        let key = "myround|\(s.rounds.count)"
        var v = base(s)
        v["round"] = round
        v["amount"] = Fmt.money(amount)
        v["post"] = Fmt.money(postMoney)
        v["lead"] = lead
        let t = pick(&s, "myround.title", v, key: key) ?? title
        let qs = quotes(&s, [("myround.investor", investor(s, fund: lead, key)), ("myround.analyst", analyst(s, key))], vars: v, key: key, second: 0.45)
        post(&s, title: t, facts: [body], quotes: qs, .finance, image: "sf_skyline", important: true, good: true)
        Pulse.react(&s, "myround", labs: ["player"], vars: v, key: key, importance: min(1, amount / 1e10))
    }

    static func playerIPO(_ s: inout GameState, raised: Double, title: String, body: String) {
        let key = "myipo"
        var v = base(s)
        v["raised"] = Fmt.money(raised)
        let t = pick(&s, "myipo.title", v, key: key) ?? title
        let qs = quotes(&s, [("myipo.analyst", analyst(s, key)), ("myipo.analyst", skeptic(s, key, not: ["player"]))], vars: v, key: key, second: 0.6)
        post(&s, title: t, facts: [body], quotes: qs, .finance, image: "stock_exchange", important: true, good: true)
        Pulse.react(&s, "myipo", labs: ["player"], vars: v, key: key, importance: 1)
    }

    // MARK: Careers

    /// A line from someone's career as a sentence about them: "Left Prometheus for Halcyon." → "Kemi Adebayo left
    /// Prometheus for Halcyon."; "Named chief scientist." → "… was named chief scientist."
    static func narrate(_ name: String, _ text: String) -> String {
        let passive: Set<String> = ["Pushed", "Promoted", "Named", "Hired", "Appointed", "Elected", "Put"]
        let first = text.split(separator: " ").first.map(String.init) ?? ""
        if first == "Between" { return "\(name) is \(Cast.lowerFirst(text))" }
        return passive.contains(first) ? "\(name) was \(Cast.lowerFirst(text))" : "\(name) \(Cast.lowerFirst(text))"
    }

    /// The month's most notable career move, as a story.
    static func career(_ s: inout GameState, _ mv: Cast.Move) {
        guard let p = Cast.person(s, id: mv.personID), let line = p.history.first else { return }
        let key = "career|\(p.id)|\(Cast.monthIndex(s))"
        var v = base(s)
        v["name"] = p.name
        v["from"] = Cast.orgName(mv.from, s)
        v["fromshort"] = Cast.orgName(mv.from, s, short: true)
        v["to"] = Cast.orgName(mv.to, s)
        v["toshort"] = Cast.orgName(mv.to, s, short: true)
        v["role"] = Cast.lowerFirst(mv.role)
        if mv.role == "Chief executive" || mv.role == "Director" { v["ifceo"] = "" }
        if mv.role == "Chief scientist" { v["ifcs"] = "" }
        if let start = p.history.last?.date { v["years"] = "\(max(1, Cast.days(start, s.date) / 365))" }
        if mv.from.isEmpty { v["from"] = nil; v["fromshort"] = nil }
        if mv.to.isEmpty { v["to"] = nil; v["toshort"] = nil }
        let kind: String
        switch mv.kind {
        case .joined, .scripted: kind = mv.from.isEmpty ? "hired" : "joined"
        case .founded: kind = "founded"
        case .promoted: kind = "promoted"
        case .steppedDown: kind = "out"
        case .retired: kind = "retired"
        case .government: kind = "government"
        case .critic: kind = "critic"
        case .academia: kind = "academia"
        case .investor, .press: kind = "joined"
        }
        guard let t = pick(&s, "career.title.\(kind)", v, key: key) else { return }
        var facts = [narrate(p.name, line.text)]
        // Context about the lab they left only makes sense when they left a lab.
        let fromLab = Cast.isLab(mv.from) || mv.from == "player"
        if p.stature >= 0.55 || mv.kind == .steppedDown, fromLab || kind == "critic",
           let lead = pick(&s, "career.ctx.\(kind)", v, key: key) { facts.append(lead) }
        // The story has just named them, so their own words are attributed by surname.
        var qs: [String] = []
        var sv = v
        if Cast.isLab(p.org) { sv["mylab"] = Cast.short(p.org) }
        if let q = pick(&s, "career.self.\(kind)", sv, voice: p.voiceStyle, key: "\(key)|self", speaker: p.id) {
            remember(&s, "speakers", p.id, keep: 6)
            qs.append(shape(q, name: Cast.surname(p), desc: "", family: p.voiceStyle.family, roll: Cast.roll(s, "attr|\(key)|\(p.id)")))
        }
        if Cast.roll(s, key + "|scoop") < 0.45, let r = Cast.find(s, key: key + "|reporter", { $0.castKind == .journalist && $0.voiceStyle == .reporter }) {
            var rv = v
            rv["reporter"] = r.name
            rv["outlet"] = Cast.orgName(r.org, s)
            if let scoop = pick(&s, "career.scoop", rv, key: key) { qs.append(scoop) }
        }
        let labs = [mv.from, mv.to].filter { Cast.isLab($0) || $0 == "player" }
        post(&s, title: t, facts: facts, quotes: qs, labs.contains("player") ? .company : .competitor)
    }
}
