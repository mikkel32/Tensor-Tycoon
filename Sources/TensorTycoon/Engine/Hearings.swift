import Foundation

// MARK: - 3.9: hearings — testify before Congress, the European Parliament or your own parliament

/// Where you're called to testify.
enum HearingVenue: String, CaseIterable, Sendable {
    case senate, europarl, commons, national

    /// The government whose view of you the hearing moves.
    func region(_ s: GameState) -> Region {
        switch self {
        case .senate: .us
        case .europarl: .eu
        case .commons: .uk
        case .national: HQ.region(s)
        }
    }

    func title(_ s: GameState) -> String {
        switch self {
        case .senate: "US Senate"
        case .europarl: "European Parliament"
        case .commons: "House of Commons"
        case .national:
            switch s.hqCountry {
            case "dk": "Folketing"
            case "fr": "Assemblée nationale"
            case "it": "Italian Parliament"
            case "ro": "Romanian Parliament"
            default: "\(HQ.country(s).name)'s parliament"
            }
        }
    }

    /// The committee that sits, for sentences ("before the Senate subcommittee on technology and the law").
    func committee(_ s: GameState) -> String {
        switch self {
        case .senate: "the Senate subcommittee on technology and the law"
        case .europarl: "the European Parliament's internal-market and civil-liberties committees"
        case .commons: "the Commons science, innovation and technology committee"
        case .national:
            switch s.hqCountry {
            case "dk": "the Folketing's digitalisation committee"
            case "fr": "the Assemblée nationale's economic affairs committee"
            case "it": "the Italian Chamber's transport and telecoms committee"
            case "ro": "the Romanian Chamber's IT and communications committee"
            default: "\(HQ.country(s).adjective) lawmakers"
            }
        }
    }

    /// What its members are called.
    var member: String {
        switch self {
        case .senate: "Senator"
        case .europarl: "MEP"
        case .commons, .national: "MP"
        }
    }

    /// How much the answers move things (national committees and the Commons matter a little less).
    var weight: Double { self == .senate || self == .europarl ? 1 : 0.8 }
}

/// What a hearing is about.
enum HearingTopic: String, CaseIterable, Sendable {
    case frontier, incident, jobs, chips, elections, children, copyright, lobbying, competition, champion

    /// Mid-sentence ("a hearing on oversight of frontier AI").
    var phrase: String {
        switch self {
        case .frontier: "oversight of frontier AI"
        case .incident: "an AI incident"
        case .jobs: "AI and jobs"
        case .chips: "chip exports and smuggling"
        case .elections: "AI and elections"
        case .children: "chatbots and children"
        case .copyright: "AI and copyright"
        case .lobbying: "AI money in politics"
        case .competition: "competition in AI"
        case .champion: "building a national AI champion"
        }
    }

    var title: String {
        switch self {
        case .frontier: "Oversight of frontier AI"
        case .incident: "An AI incident"
        case .jobs: "AI and jobs"
        case .chips: "Chip exports and smuggling"
        case .elections: "AI and elections"
        case .children: "Chatbots and children"
        case .copyright: "AI and copyright"
        case .lobbying: "AI money in politics"
        case .competition: "Competition in AI"
        case .champion: "Building a national AI champion"
        }
    }
}

/// One answer a witness can give, and what it does.
struct HearingAnswer: Sendable {
    let label: String
    /// The committee's reaction, −15 to +15.
    let mood: Double
    /// Stakeholder moves ("gov" is the hearing's government; "capital", "brand", "concern", "cost" as in GovRelations.apply).
    let fx: [String: Double]
    var promise: GovPromise? = nil
    /// Grudge it adds with the leading rival (negative: it mends fences).
    var rival: Double = 0
    /// Chance the answer becomes the clip everyone shares, and which way it cuts.
    var clip: Double = 0
    var clipText: String = ""
    var clipGood: Bool? = nil
}

/// One question in a hearing. Text takes {you}, {lab}, {model}, {rival}, {incident}, {country} and {member}.
struct HearingQuestion: Sendable {
    let id: String
    /// Topics it's asked at; empty for any hearing.
    let topics: [HearingTopic]
    /// "open", "topic", "general" or "close".
    let slot: String
    let asker: String
    let text: String
    let answers: [HearingAnswer]
}

enum Hearings {
    static let questionsPerHearing = 4
    /// Days between hearings at least, and between two on the same topic at the same venue.
    static let gapDays = 240
    static let repeatDays = 730

    // MARK: Invitations

    /// Invite the founder to testify, about a month out.
    static func invite(_ s: inout GameState, _ venue: HearingVenue, _ topic: HearingTopic, reason: String, subpoena: Bool = false) {
        guard s.gov.hearing == nil else { return }
        let key = "\(venue.rawValue)|\(topic.rawValue)|\(s.date.ym.year)-\(s.date.ym.month)"
        let days = subpoena ? 30 : 28 + Int(World.roll(s, "hdate|\(key)") * 21)
        var h = Hearing(venue: venue.rawValue, topic: topic.rawValue, date: GameCalendar.addDays(s.date, days), invited: s.date)
        h.reason = reason
        h.questions = pickQuestions(s, topic, key: key)
        s.gov.hearing = h
        s.gov.prep = 0
        let r = venue.region(s)
        let standing = Int(s.world.government(r))
        let broken = s.gov.commitments.filter { $0.status == "broken" }.count
        let mood = broken > 0 ? " They haven't forgotten the \(broken == 1 ? "promise" : "promises") you broke." : ""
        if subpoena {
            h.witness = ""
            s.gov.hearing = h
            Events.addDecision(&s, kind: "gov_subpoena", title: "Subpoena: \(venue.committee(s).capitalizedFirst) orders \(s.founderName) to testify",
                               body: "You stayed away last time; now it's compulsory. The hearing on \(topic.phrase) sits on \(h.date.gameShort).\(mood)",
                               image: "stock_exchange",
                               options: [DecisionOption(label: "Comply and testify", detail: "You face four questions in person. Book mock hearings on the Government Relations page first."),
                                         DecisionOption(label: "Fight the subpoena in court", detail: "\(r.short) standing −8, public trust −3, board confidence −2. Lawyers win time, not friends.")])
            GovRelations.note(&s, "Subpoenaed by \(venue.committee(s))", kind: "hearing")
            return
        }
        Events.addDecision(&s, kind: "gov_invite", title: "\(venue.committee(s).capitalizedFirst) invites \(s.founderName) to testify",
                           body: "Topic: \(topic.phrase). \(reason) The hearing sits on \(h.date.gameShort), about \(days / 7) weeks away. Your standing with the \(r.short) government is \(standing)/100.\(mood) A witness who prepares does better: book mock hearings on the Government Relations page.",
                           image: "stock_exchange",
                           options: [DecisionOption(label: "Testify yourself", detail: "You answer four questions live. Good answers can lift \(r.short) standing, public trust and political capital a lot; bad ones go viral."),
                                     DecisionOption(label: "Send your head of policy", detail: "Safe, careful answers at half the effect. The committee wanted the CEO: a small hit."),
                                     DecisionOption(label: "Decline", detail: "\(r.short) standing −6, public trust −2. \(venue == .senate ? "The Senate may answer with a subpoena." : "An empty chair makes the news.")")])
        Sim.news(&s, "\(s.founderName) invited to testify before the \(venue.title(s))", "\(venue.committee(s).capitalizedFirst) wants to hear from \(s.companyName) on \(topic.phrase). \(reason)",
                 .policy, image: "stock_exchange", important: true)
        GovRelations.note(&s, "Invited to testify before \(venue.committee(s)) on \(topic.phrase)", kind: "hearing")
    }

    /// Four questions: an opening, two on the topic, and a closing ask. Hashed rolls, so the RNG isn't touched.
    static func pickQuestions(_ s: GameState, _ topic: HearingTopic, key: String) -> [String] {
        func pick(_ pool: [HearingQuestion], _ n: Int, _ salt: String, avoid: Set<String> = []) -> [String] {
            var left = pool.filter { !avoid.contains($0.id) }
            var out: [String] = []
            for i in 0..<n where !left.isEmpty {
                let j = min(left.count - 1, Int(World.roll(s, "q|\(key)|\(salt)|\(i)") * Double(left.count)))
                out.append(left.remove(at: j).id)
            }
            return out
        }
        let onTopic = bank.filter { $0.slot == "topic" && $0.topics.contains(topic) }
        let general = bank.filter { $0.slot == "general" }
        var qs = pick(bank.filter { $0.slot == "open" }, 1, "open")
        let topical = pick(onTopic, 2, "topic")
        qs += topical
        if topical.count < 2 { qs += pick(general, 2 - topical.count, "general") }
        let closers = bank.filter { $0.slot == "close" && ($0.topics.isEmpty || $0.topics.contains(topic)) }
        let closing = topic == .champion ? closers.filter { $0.topics.contains(.champion) } : closers.filter { $0.topics.isEmpty }
        qs += pick(closing.isEmpty ? closers : closing, 1, "close")
        return qs
    }

    // MARK: Triggers

    /// Once a month: is anyone calling you to testify? At most one hearing every eight months, and the same committee
    /// asks about the same thing at most every two years.
    static func monthly(_ s: inout GameState) {
        guard s.world.ready, s.gov.hearing == nil, !s.decisions.contains(where: { $0.kind == "world_summons" }) else { return }
        if let last = s.gov.hearings.first, GameCalendar.daysBetween(last.date, s.date) < gapDays { return }
        if let summoned = s.world.fired["summons"], GameCalendar.daysBetween(summoned, s.date) < 180 { return }
        let ym = "\(s.date.ym.year)-\(s.date.ym.month)"
        let options = candidates(s)
        guard !options.isEmpty, World.roll(s, "hearing|\(ym)") < 0.24 else { return }
        let total = options.reduce(0) { $0 + $1.weight }
        var x = World.roll(s, "hearingpick|\(ym)") * total
        for o in options {
            x -= o.weight
            if x <= 0 { invite(&s, o.venue, o.topic, reason: o.reason); return }
        }
        if let o = options.last { invite(&s, o.venue, o.topic, reason: o.reason) }
    }

    struct Candidate {
        let venue: HearingVenue
        let topic: HearingTopic
        let reason: String
        let weight: Double
    }

    /// Hearings your situation could bring on, weighted by how likely the committee is to call one.
    static func candidates(_ s: GameState) -> [Candidate] {
        var out: [Candidate] = []
        let us = Policy.usPresence(s) || HQ.region(s) == .us
        let home = HQ.region(s)
        let best = s.releasedModels.max { $0.c < $1.c }
        let notable = GovRelations.notable(s)
        func recent(_ v: HearingVenue, _ t: HearingTopic) -> Bool {
            s.gov.hearings.contains { $0.venue == v.rawValue && $0.topic == t.rawValue && GameCalendar.daysBetween($0.date, s.date) < repeatDays }
        }
        func add(_ v: HearingVenue, _ t: HearingTopic, _ reason: String, _ w: Double) {
            if !recent(v, t) { out.append(Candidate(venue: v, topic: t, reason: reason, weight: w)) }
        }
        let main: HearingVenue = us ? .senate : .europarl
        // Your own incident: lawmakers want answers.
        if let at = s.world.incidentDate, GameCalendar.daysBetween(at, s.date) <= 120, s.world.incident.contains(s.companyName) {
            add(main, .incident, "They want to know what happened in \(s.world.incident) and why it won't happen again.", 3)
        }
        if let at = s.gov.lastScandal, GameCalendar.daysBetween(at, s.date) <= 150 {
            add(us ? .senate : (home == .us ? .senate : .national), .lobbying, "Your political spending made headlines, and members want it on the record.", 2.5)
        }
        // The most capable model in the world draws the oversight committees (after the chatbot moment, or once it's
        // obviously powerful).
        if let m = best, m.c >= World.capability(s) - 0.3, s.chatMoment != nil || m.c >= 4.4 {
            add(main, .frontier, "\(m.name) is one of the most capable AI systems in the world.", 2)
            if us && s.gov.choices["gpai_code"] == 1 { add(.europarl, .frontier, "You refused to sign the EU's code of practice for general-purpose AI.", 2) }
            if !us && home != .us && s.year >= 2023.8 { add(.commons, .frontier, "Britain wants frontier labs to commit to testing before release.", 0.6) }
        } else if s.gov.choices["gpai_code"] == 1, notable {
            add(.europarl, .frontier, "You refused to sign the EU's code of practice for general-purpose AI.", 1.5)
        }
        if s.consumerUsers >= 20e6 && s.year >= 2024.8 { add(main, .children, "Millions of teenagers use your chat app every day.", 1.5) }
        let y = s.date.ym.year
        if s.consumerUsers >= 5e6 && s.year >= 2023.9 && (2...6).contains(s.date.ym.month) {
            if y % 2 == 0 && us { add(.senate, .elections, "Voters go to the polls in November, and deepfakes are everywhere.", 1.2) }
            if (y == 2024 || y == 2029) && !us { add(.europarl, .elections, "European elections are weeks away.", 1.2) }
        }
        if s.world.jobPressure >= 0.6 && Stakeholders.automationShare(s) >= 0.03 {
            add(home == .us ? .senate : .national, .jobs, "AI is taking jobs, and your agents are doing a lot of the work.", 1.5)
        }
        if s.year >= 2023.5 && s.releasedModels.contains(where: { $0.usedShadowData }) {
            add(main, .copyright, "Authors and artists say your models were trained on their work without permission.", 1)
        }
        let gulf = s.sites.contains { Region.of(location: $0.locationID) == .gulf && $0.kind != .garage }
        let chips = s.owned.reduce(0) { $0 + $1.count }
        if s.year >= 2023.7 && (gulf || chips >= 50_000) && us {
            add(.senate, .chips, gulf ? "You're building AI datacenters in the Gulf." : "You buy more accelerators than most countries.", 1)
        }
        if s.year >= 2024 && (s.valuation >= 0.4 * Macro.frontierValuation(s.year) || s.models.contains(where: { $0.released && $0.c >= World.capability(s) - 0.1 })) && notable {
            add(main, .competition, "A handful of labs, yours included, now dominate the market.", 0.8)
        }
        if home != .us && !HQ.isDefault(s) && s.valuation >= 3e8 {
            add(.national, .champion, "\(HQ.country(s).adjective) lawmakers want to know how to keep a national AI champion at home.", 1.5)
        }
        return out
    }

    // MARK: The session

    static func daily(_ s: inout GameState) {
        // A session whose question went missing (a rewind, say) picks up where it left off.
        if let h = s.gov.hearing, h.live, !s.decisions.contains(where: { $0.kind == "gov_hearing" }) { ask(&s, h.answers.count); return }
        guard var h = s.gov.hearing, !h.live, s.date >= h.date else { return }
        // An invitation nobody answered goes to the head of policy.
        if s.decisions.contains(where: { $0.kind == "gov_invite" || $0.kind == "gov_subpoena" }) {
            s.decisions.removeAll { $0.kind == "gov_invite" || $0.kind == "gov_subpoena" }
            h.witness = h.witness.isEmpty ? "policy" : h.witness
        }
        switch h.witness {
        case "founder":
            h.live = true
            h.mood = startMood(s, h)
            s.gov.hearing = h
            Sim.news(&s, "\(s.founderName) testifies before the \(HearingVenue(rawValue: h.venue)?.title(s) ?? "committee")", "Cameras, a packed gallery and \(questionsPerHearing) questions on \(HearingTopic(rawValue: h.topic)?.phrase ?? "AI").",
                     .policy, image: "stock_exchange", important: true)
            ask(&s, 0)
        case "declined":
            emptyChair(&s, h)
        default:
            s.gov.hearing = h
            deputy(&s)
        }
    }

    /// Where the committee starts: how it already sees you, how well you prepared, and promises you broke.
    static func startMood(_ s: GameState, _ h: Hearing) -> Double {
        let venue = HearingVenue(rawValue: h.venue) ?? .senate
        let standing = s.world.government(venue.region(s))
        let broken = Double(s.gov.commitments.filter { $0.status == "broken" }.count)
        let grudges = s.gov.grudges.values.filter { $0 >= 40 }.count
        return clamp(50 + (standing - 50) * 0.3 + Double(s.gov.prep) * 5 - broken * 6 - Double(grudges) * 3 + (h.topic == HearingTopic.champion.rawValue ? 8 : 0), 15, 85)
    }

    static func question(_ id: String) -> HearingQuestion? { bank.first { $0.id == id } }

    /// Fill a question's placeholders.
    static func fill(_ text: String, _ s: GameState, _ venue: HearingVenue) -> String {
        let model = s.releasedModels.max { $0.c < $1.c }?.name ?? "your model"
        let rival = GovRelations.leadingRival(s)?.def.name ?? "a rival lab"
        let incident = s.world.incident.isEmpty ? "the incident" : s.world.incident
        return text.replacingOccurrences(of: "A {member}", with: "\(venue.member.hasPrefix("M") ? "An" : "A") \(venue.member)")
            .replacingOccurrences(of: "{rival's}", with: World.possessive(rival))
            .replacingOccurrences(of: "{you}", with: s.founderName)
            .replacingOccurrences(of: "{lab}", with: s.companyName)
            .replacingOccurrences(of: "{model}", with: model)
            .replacingOccurrences(of: "{rival}", with: rival)
            .replacingOccurrences(of: "{incident}", with: incident)
            .replacingOccurrences(of: "{country}", with: HQ.country(s).name)
            .replacingOccurrences(of: "{member}", with: venue.member)
    }

    /// The room, in words.
    static func moodWord(_ m: Double) -> String {
        switch m {
        case 72...: "warm — members are nodding"
        case 55..<72: "attentive"
        case 40..<55: "sceptical"
        case 25..<40: "hostile"
        default: "openly angry"
        }
    }

    /// What an answer is likely to do, for the option's detail line.
    static func preview(_ a: HearingAnswer, _ venue: HearingVenue, _ s: GameState) -> String {
        let tone: String
        switch a.mood {
        case 8...: tone = "The committee will like this"
        case 3..<8: tone = "Goes down fine"
        case -3..<3: tone = "Neither here nor there"
        case -8 ..< -3: tone = "Draws frowns"
        default: tone = "Risky: the room may turn on you"
        }
        var parts = [tone]
        let r = venue.region(s)
        let names: [(String, String)] = [("gov", "\(r.short) standing"), ("public", "public trust"), ("researchers", "researchers"), ("developers", "developers"),
                                         ("investors", "board"), ("capital", "political capital"), ("china", "China standing")]
        for (k, label) in names {
            guard let v = a.fx[k], abs(v * venue.weight) >= 0.5 else { continue }
            parts.append("\(label) \(v > 0 ? "+" : "−")\(Fmt.trim(abs(v * venue.weight), 0))")
        }
        if let c = a.fx["cost"] { parts.append("costs \(Fmt.money(cost(c, s)))") }
        if let p = a.promise { parts.append("promise: \(p.title.lowercasedFirst)") }
        if a.rival > 0 { parts.append("\(GovRelations.leadingRival(s)?.def.name ?? "the rival") won't forget it") }
        if a.rival < 0 { parts.append("mends fences with \(GovRelations.leadingRival(s)?.def.name ?? "rivals")") }
        if a.clip >= 0.2 { parts.append(a.clipGood == false ? "could go viral, badly" : "could be the clip of the day") }
        return parts.joined(separator: " · ")
    }

    /// A cost answer's price: a share of your run-rate (a fund, a programme), within sensible bounds.
    static func cost(_ share: Double, _ s: GameState) -> Double { clamp(Economy.runRate(s) * share, 1e6, 3e8) }

    static func ask(_ s: inout GameState, _ i: Int) {
        guard let h = s.gov.hearing, h.questions.indices.contains(i), let q = question(h.questions[i]),
              let venue = HearingVenue(rawValue: h.venue) else { conclude(&s); return }
        let amount = q.answers.first?.fx["cost"].map { cost($0, s) } ?? 0
        Events.addDecision(&s, kind: "gov_hearing", title: "\(venue.title(s)) hearing — question \(i + 1) of \(h.questions.count)",
                           body: "\(fill(q.asker, s, venue)): “\(fill(q.text, s, venue))”\n\nThe room is \(moodWord(h.mood)).",
                           image: "stock_exchange",
                           options: q.answers.map { DecisionOption(label: fill($0.label, s, venue), detail: preview($0, venue, s)) },
                           amount: amount, ref: q.id)
    }

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        switch d.kind {
        case "gov_invite":
            guard s.gov.hearing != nil else { return }
            s.gov.hearing?.witness = option == 0 ? "founder" : (option == 1 ? "policy" : "declined")
            if option == 0 { GovRelations.note(&s, "Agreed to testify in person", kind: "hearing") }
        case "gov_subpoena":
            guard let h = s.gov.hearing, let venue = HearingVenue(rawValue: h.venue) else { return }
            if option == 0 {
                s.gov.hearing?.witness = "founder"
                GovRelations.note(&s, "Complied with the subpoena", kind: "hearing")
            } else {
                let r = venue.region(s)
                GovRelations.apply(&s, ["gov": -8, "public": -3, "investors": -2], region: r, why: "Fought a congressional subpoena in court")
                record(&s, h, grade: "Subpoena fought", mood: 20)
                Sim.news(&s, "\(s.companyName) fights a subpoena", "Lawyers argue the committee overreached. Commentators call it the most expensive way to look guilty.", .policy, important: true, good: false)
                s.gov.hearing = nil
            }
        case "gov_hearing":
            answer(&s, d, option: option)
        default:
            break
        }
    }

    /// The witness answers; the next question follows straight away.
    static func answer(_ s: inout GameState, _ d: Decision, option: Int) {
        guard var h = s.gov.hearing, let q = question(d.ref), q.answers.indices.contains(option), let venue = HearingVenue(rawValue: h.venue) else { return }
        let a = q.answers[option]
        let r = venue.region(s)
        // Prepared witnesses lose less when an answer lands badly.
        let mood = a.mood < 0 ? a.mood * (1 - 0.2 * Double(s.gov.prep)) : a.mood
        h.mood = clamp(h.mood + mood, 0, 100)
        for (k, v) in a.fx where k != "cost" { h.effects[k, default: 0] += v * venue.weight }
        h.answers.append(option)
        h.lines.append("\(fill(q.asker, s, venue)): “\(fill(q.text, s, venue))” — \(fill(a.label, s, venue)).")
        if let c = a.fx["cost"] {
            let x = cost(c, s)
            s.cash -= x
            s.month.costOther += x
        }
        if let p = a.promise { GovRelations.promise(&s, p, venue: "before the \(venue.title(s))", region: r) }
        if a.rival != 0, let rival = GovRelations.leadingRival(s) {
            s.gov.grudges[rival.id] = clamp((s.gov.grudges[rival.id] ?? 0) + a.rival, 0, 100)
            if a.rival > 0, let i = s.competitors.firstIndex(where: { $0.id == rival.id }) { s.competitors[i].brand = max(0, s.competitors[i].brand - 1.5) }
        }
        if h.clip.isEmpty, a.clip > 0, World.roll(s, "clip|\(h.invited.timeIntervalSince1970)|\(q.id)") < a.clip {
            h.clip = fill(a.clipText, s, venue)
            let good = a.clipGood
            h.effects["public", default: 0] += good == true ? 2 : (good == false ? -3 : 0)
            h.effects["brand", default: 0] += good == true ? 3 : (good == false ? -3 : 1)
            Sim.news(&s, "The clip everyone is sharing", h.clip, .policy, image: "stock_exchange", important: true, good: good)
        }
        s.gov.hearing = h
        let next = h.answers.count
        if next < h.questions.count { ask(&s, next) } else { conclude(&s) }
    }

    /// The head of policy goes instead: the careful answer to every question, at half the effect.
    static func deputy(_ s: inout GameState) {
        guard var h = s.gov.hearing, let venue = HearingVenue(rawValue: h.venue) else { return }
        h.mood = startMood(s, h) - 6
        for id in h.questions {
            guard let q = question(id), q.answers.count > 1 else { continue }
            let a = q.answers[1]
            h.mood = clamp(h.mood + a.mood * 0.6, 0, 100)
            for (k, v) in a.fx where k != "cost" { h.effects[k, default: 0] += v * venue.weight * 0.5 }
            h.answers.append(1)
            h.lines.append("\(fill(q.asker, s, venue)): “\(fill(q.text, s, venue))” — your head of policy: \(fill(a.label, s, venue).lowercasedFirst).")
        }
        h.effects["gov", default: 0] -= 1.5
        h.witness = "policy"
        s.gov.hearing = h
        conclude(&s)
    }

    static func emptyChair(_ s: inout GameState, _ h: Hearing) {
        guard let venue = HearingVenue(rawValue: h.venue) else { s.gov.hearing = nil; return }
        let r = venue.region(s)
        GovRelations.apply(&s, ["gov": -6, "public": -2, "investors": -1], region: r, why: "Declined to testify before the \(venue.title(s))")
        World.shock(&s, concern: 1, "\(s.companyName) declined to testify")
        Sim.news(&s, "An empty chair for \(s.companyName)", "\(s.founderName) declined to appear before \(venue.committee(s)). Members read out the questions anyway.", .policy, image: "stock_exchange", important: true, good: false)
        record(&s, h, grade: "Empty chair", mood: 25)
        s.gov.hearing = nil
        // The Senate can compel a witness who stays away.
        if venue == .senate && World.roll(s, "subpoena|\(h.date.timeIntervalSince1970)") < 0.5 {
            invite(&s, venue, HearingTopic(rawValue: h.topic) ?? .frontier, reason: "", subpoena: true)
        }
    }

    /// The gavel: grade the afternoon, apply everything once, and remember it.
    static func conclude(_ s: inout GameState) {
        guard let h = s.gov.hearing, let venue = HearingVenue(rawValue: h.venue) else { s.gov.hearing = nil; return }
        let r = venue.region(s)
        var fx = h.effects
        let grade: String
        let summary: String
        switch h.mood {
        case 72...:
            grade = "Reassuring"
            summary = "Members thanked \(s.founderName) for straight answers. Even the sceptics sounded persuaded."
            fx["gov", default: 0] += 3; fx["public", default: 0] += 1; fx["capital", default: 0] += 4; fx["brand", default: 0] += 2
        case 55..<72:
            grade = "Steady"
            summary = "No disasters and a few good moments. The committee will remember \(s.companyName) as serious."
            fx["gov", default: 0] += 1; fx["capital", default: 0] += 1
        case 40..<55:
            grade = "Bruising"
            summary = "A long afternoon. Several answers drew groans, and the follow-up letters are already being drafted."
            fx["gov", default: 0] -= 1; fx["investors", default: 0] -= 1
        default:
            grade = "Disaster"
            summary = "The hearing went badly from the first question. Investors called before \(s.founderName) reached the car."
            fx["gov", default: 0] -= 3; fx["public", default: 0] -= 2; fx["investors", default: 0] -= 3; fx["brand", default: 0] -= 3
        }
        let who = h.witness == "policy" ? "Your head of policy testified" : "\(s.founderName) testified"
        GovRelations.apply(&s, fx, region: r, why: "\(who) before the \(venue.title(s)) (\(grade.lowercased()))")
        if let c = fx["concern"], abs(c) >= 0.5 { World.shock(&s, concern: c, "\(s.companyName) testified on \(HearingTopic(rawValue: h.topic)?.phrase ?? "AI")") }
        var done = h
        done.effects = fx
        s.gov.hearing = done
        record(&s, done, grade: grade, mood: h.mood)
        Sim.news(&s, "Hearing: \(grade.lowercased()) for \(s.companyName)", "\(who) before \(venue.committee(s)) on \(HearingTopic(rawValue: h.topic)?.phrase ?? "AI"). \(summary)",
                 .policy, image: "stock_exchange", important: true, good: grade == "Reassuring" || grade == "Steady")
        s.gov.hearing = nil
        s.gov.prep = 0
    }

    static func record(_ s: inout GameState, _ h: Hearing, grade: String, mood: Double) {
        let rec = HearingRecord(date: s.date, venue: h.venue, topic: h.topic, witness: h.witness.isEmpty ? "policy" : h.witness, grade: grade, mood: mood,
                                lines: h.lines, effects: h.effects, clip: h.clip)
        s.gov.hearings.insert(rec, at: 0)
        if s.gov.hearings.count > 24 { s.gov.hearings.removeLast(s.gov.hearings.count - 24) }
        GovRelations.note(&s, "Hearing before the \(HearingVenue(rawValue: h.venue)?.title(s) ?? "committee"): \(grade.lowercased())", kind: "hearing")
    }

    // MARK: The questions

    static let bank: [HearingQuestion] = [
        // Openings
        HearingQuestion(id: "o_worst", topics: [], slot: "open", asker: "The chair", text: "In plain words, {you}: what is the worst that could happen with the systems {lab} builds?", answers: [
            HearingAnswer(label: "Name the worst cases out loud", mood: 10, fx: ["gov": 2, "public": 1, "investors": -1, "concern": 1], clip: 0.15,
                          clipText: "{you}: “If this technology goes wrong, it can go quite wrong — and we want to work with you to prevent that.”", clipGood: true),
            HearingAnswer(label: "Start with the good it does", mood: 2, fx: ["investors": 1]),
            HearingAnswer(label: "Call the fears overblown", mood: -10, fx: ["gov": -2, "researchers": -1, "developers": 1, "investors": 1], clip: 0.2,
                          clipText: "{you} waves away the risks of AI before the committee; the clip runs on every evening bulletin.", clipGood: false),
        ]),
        HearingQuestion(id: "o_smarter", topics: [], slot: "open", asker: "The committee's most senior member", text: "Will your systems one day be smarter than everyone in this room?", answers: [
            HearingAnswer(label: "Yes, and sooner than you think", mood: 4, fx: ["researchers": 2, "public": -1, "concern": 2], clip: 0.3,
                          clipText: "{you} tells lawmakers machines will outthink them “sooner than you think”. The gallery gasps; the clip doesn't stop.", clipGood: nil),
            HearingAnswer(label: "In narrow ways they already are", mood: 5, fx: ["gov": 1]),
            HearingAnswer(label: "No, they're tools", mood: -3, fx: ["researchers": -2, "public": 1]),
        ]),
        HearingQuestion(id: "o_why", topics: [], slot: "open", asker: "The chair", text: "Why should the public trust a private company with technology this powerful?", answers: [
            HearingAnswer(label: "Invite oversight: “you shouldn't have to”", mood: 9, fx: ["gov": 2, "public": 2, "investors": -1]),
            HearingAnswer(label: "Point to the safety record", mood: 3, fx: ["gov": 1]),
            HearingAnswer(label: "Say markets keep companies honest", mood: -7, fx: ["gov": -2, "public": -1, "investors": 1]),
        ]),
        // General
        HearingQuestion(id: "g_test", topics: [], slot: "general", asker: "A {member} from the minority", text: "Will you commit, here and now, to let independent experts test your models before release?", answers: [
            HearingAnswer(label: "Yes — commit to it", mood: 12, fx: ["gov": 3, "public": 1, "researchers": 1], promise: .institute),
            HearingAnswer(label: "We already test them internally", mood: -2, fx: [:]),
            HearingAnswer(label: "Not before release: it would leak our secrets", mood: -10, fx: ["gov": -3, "investors": 1]),
        ]),
        HearingQuestion(id: "g_liable", topics: [], slot: "general", asker: "A former prosecutor on the committee", text: "When an AI system hurts someone, who should be liable?", answers: [
            HearingAnswer(label: "The developer, for foreseeable misuse", mood: 8, fx: ["gov": 2, "public": 2, "investors": -3, "developers": -1]),
            HearingAnswer(label: "Whoever deploys it", mood: 2, fx: ["developers": -2, "investors": 1]),
            HearingAnswer(label: "Existing law is enough", mood: -7, fx: ["public": -1, "investors": 2]),
        ]),
        HearingQuestion(id: "g_lobby", topics: [], slot: "general", asker: "A {member} known for grilling witnesses", text: "How much did {lab} spend lobbying this body last year?", answers: [
            HearingAnswer(label: "Give the exact figure", mood: 5, fx: ["public": 1]),
            HearingAnswer(label: "Refer them to the public filings", mood: -1, fx: [:]),
            HearingAnswer(label: "Say every company advocates", mood: -4, fx: ["public": -1]),
        ]),
        HearingQuestion(id: "g_china", topics: [], slot: "general", asker: "A {member} on the intelligence committee", text: "If we slow you down, don't we just hand the lead to China?", answers: [
            HearingAnswer(label: "Safety and speed aren't opposites", mood: 6, fx: ["gov": 1, "researchers": 1]),
            HearingAnswer(label: "Yes: the race is real", mood: 3, fx: ["investors": 1, "concern": 1, "china": -2]),
            HearingAnswer(label: "Propose talks with Beijing on red lines", mood: -2, fx: ["researchers": 2, "china": 3], clip: 0.15,
                          clipText: "{you} proposes US–China talks on AI red lines; half the room applauds, half walks out.", clipGood: nil),
        ]),
        // Frontier
        HearingQuestion(id: "f_release", topics: [.frontier], slot: "topic", asker: "The ranking member", text: "{model} is one of the most capable systems on Earth. Who decided it was safe to release, and how?", answers: [
            HearingAnswer(label: "Walk through the evaluations, findings and all", mood: 9, fx: ["gov": 2, "researchers": 2]),
            HearingAnswer(label: "Our safety team signed off", mood: 2, fx: [:]),
            HearingAnswer(label: "“The market decided”", mood: -12, fx: ["gov": -2, "public": -2], clip: 0.35,
                          clipText: "“The market decided,” says {you}, asked who judged {model} safe. The committee room goes silent; the internet does not.", clipGood: false),
        ]),
        HearingQuestion(id: "f_shutdown", topics: [.frontier, .incident], slot: "topic", asker: "A {member} who used to run a power utility", text: "If {model} started copying itself or hiding what it does, could you switch it off?", answers: [
            HearingAnswer(label: "Yes — describe the kill switch and the drills", mood: 8, fx: ["gov": 2, "public": 1], promise: .security),
            HearingAnswer(label: "Admit there's no perfect off switch", mood: 3, fx: ["researchers": 2, "concern": 2], clip: 0.2,
                          clipText: "{you} admits there is “no perfect off switch” for frontier AI. It's the line every paper leads with.", clipGood: nil),
            HearingAnswer(label: "That's science fiction", mood: -8, fx: ["researchers": -2, "gov": -1]),
        ]),
        HearingQuestion(id: "f_rival", topics: [.frontier, .competition], slot: "topic", asker: "A {member} reading from {rival's} submission", text: "{rival} says your lab cuts corners to ship first. Is that true?", answers: [
            HearingAnswer(label: "Offer a joint safety audit with {rival}", mood: 6, fx: ["gov": 1, "researchers": 1], rival: -10),
            HearingAnswer(label: "Decline to discuss competitors", mood: 1, fx: [:]),
            HearingAnswer(label: "Point to {rival's} own record", mood: -2, fx: ["public": 1], rival: 15, clip: 0.25,
                          clipText: "{you} turns the tables on {rival} mid-hearing. The exchange gets more views than the rest of the session combined.", clipGood: nil),
        ]),
        HearingQuestion(id: "f_policy", topics: [.frontier], slot: "topic", asker: "A {member} from the majority", text: "Will you publish the rules you use to decide when a model is too dangerous to release?", answers: [
            HearingAnswer(label: "Yes: publish a scaling policy", mood: 9, fx: ["gov": 2, "researchers": 2], promise: .framework),
            HearingAnswer(label: "Parts of it are public already", mood: 1, fx: [:]),
            HearingAnswer(label: "It's commercially sensitive", mood: -8, fx: ["gov": -2, "investors": 1]),
        ]),
        // Incident
        HearingQuestion(id: "i_timeline", topics: [.incident], slot: "topic", asker: "The chair", text: "Walk us through {incident}. When did you first know?", answers: [
            HearingAnswer(label: "Give the full timeline, mistakes included", mood: 10, fx: ["gov": 3, "public": 2, "investors": -2]),
            HearingAnswer(label: "Read the prepared statement", mood: -2, fx: [:]),
            HearingAnswer(label: "Blame the users who abused it", mood: -12, fx: ["public": -3, "gov": -2], clip: 0.3,
                          clipText: "{you} blames users for {incident}. Victims' families, seated behind, shake their heads on camera.", clipGood: false),
        ]),
        HearingQuestion(id: "i_trust", topics: [.incident], slot: "topic", asker: "A {member} from the minority", text: "Why should anyone trust {lab} again?", answers: [
            HearingAnswer(label: "Announce an independent review and publish it", mood: 8, fx: ["gov": 2, "public": 2], promise: .evals),
            HearingAnswer(label: "Point to the fix you shipped", mood: 2, fx: [:]),
            HearingAnswer(label: "Note that every lab has incidents", mood: -6, fx: ["public": -1], rival: 5),
        ]),
        HearingQuestion(id: "i_pay", topics: [.incident, .children], slot: "topic", asker: "A {member} holding a constituent's letter", text: "Will you compensate the people who were harmed?", answers: [
            HearingAnswer(label: "Yes — set up a compensation fund", mood: 10, fx: ["public": 3, "gov": 1, "investors": -1, "cost": 0.004]),
            HearingAnswer(label: "Our lawyers are reviewing claims", mood: -3, fx: [:]),
            HearingAnswer(label: "Existing law covers it", mood: -8, fx: ["public": -2]),
        ]),
        // Jobs
        HearingQuestion(id: "j_workers", topics: [.jobs], slot: "topic", asker: "A {member} from a manufacturing district", text: "Your agents now do work people used to be paid for. What do you say to them?", answers: [
            HearingAnswer(label: "Back retraining and a share of the gains", mood: 9, fx: ["public": 3, "investors": -2, "gov": 1]),
            HearingAnswer(label: "History says new jobs will come", mood: -2, fx: ["public": -1]),
            HearingAnswer(label: "Productivity is the point", mood: -10, fx: ["public": -3, "investors": 2], clip: 0.3,
                          clipText: "“Productivity is the point,” {you} tells a lawmaker whose district lost a call centre to AI agents.", clipGood: false),
        ]),
        HearingQuestion(id: "j_tax", topics: [.jobs], slot: "topic", asker: "The ranking member", text: "Would you support a tax on automation?", answers: [
            HearingAnswer(label: "Yes, if it funds the transition", mood: 6, fx: ["public": 2, "investors": -4, "gov": 1]),
            HearingAnswer(label: "Prefer wage insurance from general taxes", mood: 2, fx: [:]),
            HearingAnswer(label: "It would push the work offshore", mood: -4, fx: ["investors": 2]),
        ]),
        HearingQuestion(id: "j_staff", topics: [.jobs], slot: "topic", asker: "A {member} from the majority", text: "How many of your own staff has AI replaced?", answers: [
            HearingAnswer(label: "Give the honest number", mood: 5, fx: ["public": 1, "researchers": 1]),
            HearingAnswer(label: "We're still hiring", mood: 2, fx: [:]),
            HearingAnswer(label: "Decline: an internal matter", mood: -6, fx: [:]),
        ]),
        // Chips
        HearingQuestion(id: "c_smuggle", topics: [.chips], slot: "topic", asker: "A {member} on the China committee", text: "Can you guarantee none of your accelerators ends up in a country under export controls?", answers: [
            HearingAnswer(label: "Back location verification for chips", mood: 8, fx: ["gov": 3, "developers": -1]),
            HearingAnswer(label: "Describe your know-your-customer checks", mood: 3, fx: ["gov": 1]),
            HearingAnswer(label: "No one can guarantee that", mood: -6, fx: ["gov": -2], clip: 0.15,
                          clipText: "“No one can guarantee that,” {you} says of chip smuggling. Export hawks have their soundbite.", clipGood: false),
        ]),
        HearingQuestion(id: "c_gulf", topics: [.chips], slot: "topic", asker: "The chair", text: "Should America sell its best chips to the Gulf?", answers: [
            HearingAnswer(label: "Yes, under licences with strict conditions", mood: 5, fx: ["gov": 1, "gulf": 2]),
            HearingAnswer(label: "Only with no Chinese hardware on site", mood: 3, fx: ["gov": 2, "china": -2]),
            HearingAnswer(label: "Let the market decide", mood: -6, fx: ["investors": 1, "gov": -1]),
        ]),
        HearingQuestion(id: "c_rent", topics: [.chips, .competition], slot: "topic", asker: "A {member} from the minority", text: "Is anyone in China renting compute from you?", answers: [
            HearingAnswer(label: "No, and we audit for it", mood: 6, fx: ["gov": 2, "china": -3]),
            HearingAnswer(label: "Not knowingly", mood: -2, fx: [:]),
            HearingAnswer(label: "Renting isn't exporting", mood: -8, fx: ["gov": -3], clip: 0.2,
                          clipText: "{you} tells lawmakers that renting AI compute to Chinese firms “isn't exporting”. Expect a bill by Friday.", clipGood: false),
        ]),
        // Elections
        HearingQuestion(id: "e_deepfake", topics: [.elections], slot: "topic", asker: "A {member} who was deepfaked last month", text: "Your models can fake a candidate's voice in seconds. What stops that this election?", answers: [
            HearingAnswer(label: "Watermark everything; ban political impersonation", mood: 9, fx: ["public": 2, "developers": -1, "gov": 1]),
            HearingAnswer(label: "Our usage policy forbids it", mood: 1, fx: [:]),
            HearingAnswer(label: "That's for the platforms to police", mood: -8, fx: ["public": -2]),
        ]),
        HearingQuestion(id: "e_ads", topics: [.elections, .lobbying], slot: "topic", asker: "The ranking member", text: "Will you take money for AI-generated political ads?", answers: [
            HearingAnswer(label: "No political ads, full stop", mood: 6, fx: ["public": 1, "investors": -1]),
            HearingAnswer(label: "Only with clear labels", mood: 3, fx: [:]),
            HearingAnswer(label: "It's legal speech", mood: -5, fx: ["public": -1]),
        ]),
        // Children
        HearingQuestion(id: "k_teens", topics: [.children], slot: "topic", asker: "A {member} and parent of two", text: "Teenagers spend hours a day talking to your chatbot, and some of them are in crisis. What are you doing about it?", answers: [
            HearingAnswer(label: "Age checks, parental controls, crisis hand-offs", mood: 10, fx: ["public": 3, "developers": -1, "investors": -1]),
            HearingAnswer(label: "Users must be 13 or older", mood: -5, fx: ["public": -1]),
            HearingAnswer(label: "Parents are responsible", mood: -12, fx: ["public": -4], clip: 0.35,
                          clipText: "“Parents are responsible,” says {you}, as grieving families hold up photos behind the witness table.", clipGood: false),
        ]),
        HearingQuestion(id: "k_study", topics: [.children], slot: "topic", asker: "A {member} from the majority", text: "Will you let independent researchers study what your chatbot does to children?", answers: [
            HearingAnswer(label: "Yes, under strict privacy rules", mood: 7, fx: ["researchers": 3, "public": 1]),
            HearingAnswer(label: "We fund our own studies", mood: -1, fx: [:]),
            HearingAnswer(label: "User privacy prevents it", mood: -4, fx: [:]),
        ]),
        // Copyright
        HearingQuestion(id: "p_books", topics: [.copyright], slot: "topic", asker: "A {member} and published novelist", text: "Did you train {model} on pirated books?", answers: [
            HearingAnswer(label: "Admit what's in the data; offer licences", mood: 6, fx: ["public": 1, "investors": -2]),
            HearingAnswer(label: "Training is fair use", mood: -2, fx: ["developers": 1]),
            HearingAnswer(label: "Decline on legal advice", mood: -6, fx: [:], clip: 0.2,
                          clipText: "{you} declines, on legal advice, to say whether {model} read pirated books. The silence says plenty.", clipGood: false),
        ]),
        HearingQuestion(id: "p_pay", topics: [.copyright], slot: "topic", asker: "The chair", text: "Should creators be paid when their work trains AI?", answers: [
            HearingAnswer(label: "Yes, through collective licensing", mood: 7, fx: ["public": 2, "investors": -2]),
            HearingAnswer(label: "Opt-outs, not payments", mood: 1, fx: [:]),
            HearingAnswer(label: "Learning from public work is how science works", mood: -4, fx: ["developers": 2]),
        ]),
        // Lobbying
        HearingQuestion(id: "l_pac", topics: [.lobbying], slot: "topic", asker: "A {member} your PAC's ads attacked", text: "Your political money went after members of this committee. Why?", answers: [
            HearingAnswer(label: "Apologise and stop the PAC money", mood: 12, fx: ["public": 2, "gov": 2], promise: .noPAC),
            HearingAnswer(label: "Every industry takes part in politics", mood: -6, fx: ["investors": 1]),
            HearingAnswer(label: "Stand by every dollar", mood: -14, fx: ["gov": -3, "public": -2], clip: 0.3,
                          clipText: "“I stand by every dollar,” {you} tells the lawmaker their PAC tried to unseat. The clip writes itself.", clipGood: false),
        ]),
        HearingQuestion(id: "l_rules", topics: [.lobbying], slot: "topic", asker: "The ranking member", text: "You say you want regulation. Why do your lobbyists fight every bill?", answers: [
            HearingAnswer(label: "Publish all political spending; back safety bills", mood: 6, fx: ["public": 2], promise: .safetyBills),
            HearingAnswer(label: "We support smart rules", mood: -2, fx: [:]),
            HearingAnswer(label: "Lobbying is legal", mood: -6, fx: ["public": -1]),
        ]),
        // Competition
        HearingQuestion(id: "x_breakup", topics: [.competition], slot: "topic", asker: "A {member} on the antitrust subcommittee", text: "{lab} and two others control most of this market. Should we break you up?", answers: [
            HearingAnswer(label: "Back open interfaces and data portability", mood: 6, fx: ["developers": 3, "investors": -1]),
            HearingAnswer(label: "Point to the open-weights challengers", mood: 1, fx: [:]),
            HearingAnswer(label: "Scale is what it takes to compete with China", mood: -3, fx: ["investors": 2]),
        ]),
        HearingQuestion(id: "x_compute", topics: [.competition], slot: "topic", asker: "A {member} from a college town", text: "Do your compute deals lock universities and startups out?", answers: [
            HearingAnswer(label: "Pledge compute credits to academics", mood: 7, fx: ["researchers": 3, "developers": 1, "cost": 0.001]),
            HearingAnswer(label: "Our deals are standard", mood: -1, fx: [:]),
            HearingAnswer(label: "Smaller labs should raise more money", mood: -7, fx: ["developers": -2], clip: 0.2,
                          clipText: "“They should raise more money,” {you} says of locked-out universities. Academics are not amused.", clipGood: false),
        ]),
        // National champion (friendly)
        HearingQuestion(id: "n_needs", topics: [.champion], slot: "topic", asker: "The committee chair", text: "What does {lab} need from {country} to keep building here?", answers: [
            HearingAnswer(label: "Cheaper power and faster permits", mood: 5, fx: ["gov": 2, "investors": 1]),
            HearingAnswer(label: "Fast visas for researchers", mood: 6, fx: ["researchers": 2, "gov": 1]),
            HearingAnswer(label: "Public contracts on a level field", mood: 4, fx: ["capital": 3]),
        ]),
        HearingQuestion(id: "n_language", topics: [.champion], slot: "topic", asker: "A {member} from the culture committee", text: "Will your models keep working well in our language, and in our public services?", answers: [
            HearingAnswer(label: "Commit to a national-language model", mood: 8, fx: ["gov": 3, "public": 2, "cost": 0.001]),
            HearingAnswer(label: "Where there's demand", mood: 1, fx: [:]),
            HearingAnswer(label: "We build for the global market", mood: -5, fx: ["gov": -2]),
        ]),
        // Closing asks
        HearingQuestion(id: "z_licence", topics: [], slot: "close", asker: "The ranking member", text: "Last question. Would you support a licence to train the most powerful models?", answers: [
            HearingAnswer(label: "Yes — license frontier training", mood: 12, fx: ["gov": 3, "public": 1, "developers": -4, "researchers": -1, "capital": 2], rival: 6),
            HearingAnswer(label: "Standards and testing, not licences", mood: 3, fx: ["gov": 1]),
            HearingAnswer(label: "No — it would freeze the field", mood: -6, fx: ["gov": -2, "developers": 3, "investors": 1]),
        ]),
        HearingQuestion(id: "z_ask", topics: [], slot: "close", asker: "The chair", text: "If you were in my seat, what would you have us do?", answers: [
            HearingAnswer(label: "Create an agency for frontier AI", mood: 10, fx: ["gov": 3, "public": 1, "investors": -2, "developers": -1], rival: 3),
            HearingAnswer(label: "Fund the safety institute and set testing standards", mood: 6, fx: ["gov": 2, "researchers": 1]),
            HearingAnswer(label: "Mostly stay out of the way", mood: -8, fx: ["gov": -3, "investors": 2, "developers": 2]),
        ]),
        HearingQuestion(id: "z_stay", topics: [.champion], slot: "close", asker: "The committee chair", text: "Would you ever sell {lab} to an American or Chinese buyer?", answers: [
            HearingAnswer(label: "No: we're staying independent", mood: 8, fx: ["gov": 3, "investors": -3]),
            HearingAnswer(label: "Our duty is to our shareholders", mood: -4, fx: ["investors": 2]),
            HearingAnswer(label: "Never say never", mood: -1, fx: [:]),
        ]),
    ]
}

extension String {
    /// "Back it" → "back it" (for quoting an answer mid-sentence).
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
}
