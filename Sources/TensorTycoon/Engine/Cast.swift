import Foundation

/// The people of AI over time (3.4). Seeds the cast when a game starts, plays the founding labs' people through their
/// careers until October 2026, then moves people procedurally — tied to what the labs actually do: a spin-out takes its
/// founder from the parent lab, a takeover sends a lab's people to the buyer or onto the market, a raid on your team
/// puts your researchers on a rival's payroll, and every month someone may be promoted, poached, pushed out, retire,
/// join a government office or turn critic.
/// Hashed rolls only: nothing here draws from the game's RNG or feeds back into the simulation (the one touch outside the
/// people layer is cosmetic: researchers you inherit in a takeover carry the names of the lab's people who joined you).
enum Cast {
    /// Most people kept (old, quiet ones are pruned first).
    static let cap = 150
    static let historyCap = 12

    // MARK: Hashed rolls

    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("people|\(s.peopleSalt)|\(key)") }

    static func pick<T>(_ s: GameState, _ key: String, _ items: [T]) -> T? {
        items.isEmpty ? nil : items[min(items.count - 1, Int(roll(s, key) * Double(items.count)))]
    }

    static func weighted<T>(_ s: GameState, _ key: String, _ items: [(T, Double)]) -> T? {
        let total = items.reduce(0) { $0 + max(0, $1.1) }
        guard total > 0 else { return items.first?.0 }
        var left = roll(s, key) * total
        for (item, w) in items where w > 0 {
            left -= w
            if left <= 0 { return item }
        }
        return items.last { $0.1 > 0 }?.0
    }

    static func monthIndex(_ s: GameState) -> Int { s.date.ym.year * 12 + s.date.ym.month }

    /// Whole days from `a` to `b` (game dates are noon UTC, so this matches the calendar without its cost).
    static func days(_ a: Date, _ b: Date) -> Int { RivalIntel.dayIndex(b) - RivalIntel.dayIndex(a) }

    // MARK: Names and organisations

    /// A lab's name without "AI", "Labs" and the like: "Prometheus", "Dragon Lake".
    static func short(_ labID: String) -> String {
        var n = CompetitorCatalog.def(labID).name
        for suffix in [" Collective", " Labs", " AI", " Research", " Intelligence", " Systems"] where n.hasSuffix(suffix) {
            n = String(n.dropLast(suffix.count))
            break
        }
        return n
    }

    static func isLab(_ org: String) -> Bool { !org.isEmpty && org != "player" && CompetitorCatalog.lookup(org) != nil }

    /// Display name of an organisation: a lab's name, your company, or the organisation itself.
    static func orgName(_ org: String, _ s: GameState, short useShort: Bool = false) -> String {
        if org.isEmpty { return "" }
        if org == "player" { return s.companyName }
        if CompetitorCatalog.lookup(org) != nil { return useShort ? short(org) : CompetitorCatalog.def(org).name }
        return org
    }

    static func article(_ word: String) -> String {
        let head = Array(word.prefix(2))
        guard let c = head.first else { return "a" }
        // Acronyms go by sound: "an ML engineer", "a PhD researcher".
        if head.count == 2 && c.isUppercase && head[1].isUppercase { return "AEFHILMNORSX".contains(c) ? "an" : "a" }
        return "aeiouAEIOU".contains(c) ? "an" : "a"
    }

    /// Lowercases the first letter of a title, but leaves acronyms alone ("PhD researcher", "AI correspondent").
    static func lowerFirst(_ s: String) -> String {
        let chars = Array(s.prefix(2))
        if chars.count == 2 && chars[1].isUppercase { return s }
        return s.prefix(1).lowercased() + s.dropFirst()
    }

    /// "Prometheus's", "OpenWeights'", "Playtest Labs'".
    static func possessive(_ name: String) -> String {
        guard name.hasSuffix("s") else { return name + "'s" }
        return name.hasSuffix("us") || name.hasSuffix("ss") ? name + "'s" : name + "'"
    }

    /// How the press introduces someone: "Prometheus's chief executive", "a partner at Andromeda Ventures".
    static func desc(_ p: CastMember, _ s: GameState) -> String {
        if !p.desc.isEmpty { return p.desc }
        let role = lowerFirst(p.role)
        let org = orgName(p.org, s, short: true)
        switch p.castKind {
        case .leader, .scientist:
            return org.isEmpty ? role : "\(possessive(org)) \(role)"
        case .researcher:
            if org.isEmpty { return "a researcher" }
            let r = p.role.lowercased()
            if r.hasPrefix("head of ") { return "who heads \(p.role.dropFirst(8)) at \(org)" }
            if r == "president" { return "\(possessive(org)) president" }
            if r == "adviser" { return "an adviser to \(org)" }
            if r.hasSuffix(" lead") { return "who leads \(p.focus.isEmpty ? "research" : p.focus) at \(org)" }
            return "\(article(role)) \(role) at \(org)"
        case .free:
            return p.lastLab.isEmpty ? "an independent researcher" : "formerly of \(orgName(p.lastLab, s, short: true))"
        default:
            return org.isEmpty ? "\(article(role)) \(role)" : "\(article(role)) \(role) at \(org)"
        }
    }

    /// Whether someone from `region` would plausibly take a job at `lab`: Dragon Lake hires inside China's export
    /// walls; national labs mostly hire their own.
    static func fits(_ region: String, _ lab: String) -> Double {
        if lab == "dragonlake" { return region == "China" ? 1 : 0 }
        if let spec = CompetitorCatalog.spec(lab), spec.kind == .sovereign {
            return CastCatalog.hiringPool(spec.hq).contains { $0.0 == region && $0.1 >= 1 } ? 1 : 0.15
        }
        return region == "China" && lab != "dragonlake" ? 0.5 : 1
    }

    /// How well someone's views suit a lab: safety hawks shy away from labs that race without guardrails and gravitate to
    /// careful ones; people who want weights kept closed avoid open-weights labs, and open-weights believers seek them out.
    static func stanceFit(_ p: CastMember, _ lab: String) -> Double {
        guard let def = CompetitorCatalog.lookup(lab) else { return 1 }
        let labSafety = Competitors.trait(lab).safety
        var f = 1.0
        if p.safety >= 0.7 { f *= labSafety >= 5 ? 1.6 : (labSafety <= -10 ? 0.15 : 0.6) }
        if p.safety <= 0.3 && labSafety >= 10 { f *= 0.6 }
        if def.openWeights {
            f *= p.open < -0.3 ? 0.25 : (p.open > 0.4 ? 1.5 : 1)
        } else if p.open > 0.7 {
            f *= 0.5
        }
        return f
    }

    /// Labs that existed `yearsAgo` years before `date` (today by default) and that someone from `region` might have
    /// worked at: no lab before it was founded, no Dragon Lake outside China.
    static func pastLabs(_ s: GameState, yearsAgo: Int, region: String, excluding: String, on date: Date? = nil) -> [String] {
        let then = (date ?? s.date).decimalYear - Double(yearsAgo)
        return s.competitors.filter { $0.id != excluding && $0.def.founded.decimal <= then && fits(region, $0.id) > 0.5 }.map(\.id)
    }

    /// The government AI office someone at `org` (from `region`) would join: where they work decides, then where they're from.
    static func agency(org: String, region: String) -> String {
        let hq = isLab(org) ? CompetitorCatalog.def(org).hq.lowercased() : ""
        if hq.contains("hangzhou") { return "China's internet regulator" }
        if hq.contains("tokyo") { return "Japan's AI Safety Institute" }
        if hq.contains("bengaluru") { return "India's AI Mission" }
        if hq.hasPrefix("london") { return "the London AI Safety Institute" }
        if hq.contains("paris") || hq.contains("berlin") || hq.contains("zurich") { return "the EU AI Office" }
        if !hq.isEmpty && !hq.contains("seoul") && !hq.contains("abu dhabi") && !hq.contains("riyadh") && !hq.contains("singapore") {
            return "the US AI Standards Office"
        }
        switch region {
        case "UK", "Ireland", "Nigeria", "West Africa", "East Africa": return "the London AI Safety Institute"
        case "India": return "India's AI Mission"
        case "Japan": return "Japan's AI Safety Institute"
        case "China": return "China's internet regulator"
        case "France", "Germany", "Belgium", "Netherlands", "Italy", "Poland", "Nordics", "Sweden", "Norway", "Croatia", "EU": return "the EU AI Office"
        default: return "the US AI Standards Office"
        }
    }

    // MARK: Lookups

    static func index(_ s: GameState, id: String) -> Int? { s.cast.firstIndex { $0.id == id } }

    static func person(_ s: GameState, id: String) -> CastMember? { s.cast.first { $0.id == id } }

    /// Who's at a lab now: leader, chief scientist, then researchers by stature.
    static func staff(_ s: GameState, _ lab: String) -> [CastMember] {
        s.cast.filter { $0.active && $0.org == lab }.sorted { a, b in
            let ra = rank(a.castKind), rb = rank(b.castKind)
            return ra != rb ? ra < rb : a.stature > b.stature
        }
    }

    static func rank(_ k: CastKind) -> Int {
        switch k {
        case .leader: 0
        case .scientist: 1
        case .researcher: 2
        default: 3
        }
    }

    static func leader(_ s: GameState, _ lab: String) -> CastMember? { s.cast.first { $0.active && $0.org == lab && $0.castKind == .leader } }

    /// The person who speaks for a lab: its leader, or failing that its most senior person.
    static func voice(_ s: GameState, _ lab: String) -> CastMember? { leader(s, lab) ?? staff(s, lab).first }

    /// The name the Rivals hub shows as a lab's chief executive (nil before the cast exists).
    static func ceoName(_ s: GameState, _ lab: String) -> String? { leader(s, lab)?.name }

    /// People who once worked at `org` and have since left (newest departures first).
    static func alumni(_ s: GameState, of org: String) -> [CastMember] {
        s.cast.filter { p in p.org != org && (p.lastLab == org || p.history.contains { $0.org == org }) }.sorted { $0.since > $1.since }
    }

    /// Someone for a perspective, weighted by stature and avoiding whoever was quoted lately.
    static func find(_ s: GameState, key: String, avoid: [String] = [], _ test: (CastMember) -> Bool) -> CastMember? {
        let recent = Set(s.voiceRecent["speakers"] ?? [])
        var pool = s.cast.filter { $0.active && test($0) && !avoid.contains($0.id) }
        let fresh = pool.filter { !recent.contains($0.id) }
        if !fresh.isEmpty { pool = fresh }
        return weighted(s, key, pool.map { ($0, 0.25 + $0.stature) })
    }

    // MARK: Seeding

    static func seed(_ s: inout GameState) {
        if s.peopleSalt.isEmpty {
            s.peopleSalt = String(s.rng.state ^ UInt64(bitPattern: Int64(s.startDate.timeIntervalSince1970)), radix: 36)
        }
        guard s.cast.isEmpty else { return }
        let now = s.date
        for p in CastCatalog.people {
            guard let first = p.beats.first, first.ym <= now.ym else { continue }
            s.cast.append(member(p, upTo: now))
        }
        // Labs founded during the game (saves from before 3.4) get their founders.
        for spec in s.customLabs { ensureFounder(&s, spec, on: spec.founded.date) }
        // Labs that left the market before the cast existed: their people have moved on.
        for c in s.competitors where !c.exitNote.isEmpty && s.cast.contains(where: { $0.active && $0.org == c.id }) {
            labClosed(&s, c.id, quiet: true)
        }
    }

    /// Saves from before 3.4 meet the cast as it stands on the day they load.
    static func migrate(_ s: inout GameState) {
        if s.cast.isEmpty { seed(&s) }
    }

    static func member(_ p: CastCatalog.Person, upTo now: Date) -> CastMember {
        let nowYM = now.ym
        let done = Array(p.beats.enumerated().filter { $0.element.ym <= nowYM })
        let last = done.last?.element ?? p.beats[0]
        var m = CastMember(id: p.id, name: p.name, kind: last.kind.rawValue, role: last.role, org: last.org, traits: p.traits.map(\.rawValue),
                           voice: p.voice.rawValue, open: p.open, safety: p.safety, regulation: p.regulation, handle: p.handle,
                           region: p.region, stature: p.stature, since: last.ym.date)
        m.blurb = p.blurb
        m.desc = p.desc
        m.focus = p.focus
        m.history = done.reversed().map { CastEntry(date: $0.element.ym.date, text: $0.element.text, org: $0.element.org, role: $0.element.role) }
        m.beatsDone = done.map { "\(p.id)#\($0.offset)" }
        // The lab they left last, from the timeline.
        if done.count >= 2 {
            let prev = done[done.count - 2].element.org
            if prev != last.org && !prev.isEmpty { m.lastLab = prev }
        }
        return m
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        if s.cast.isEmpty { seed(&s) }
        var moves: [Move] = []
        scripted(&s, &moves)
        if s.year >= RivalHistory.end {
            staffing(&s, &moves)
            churn(&s, &moves)
        }
        watcherChurn(&s, &moves)
        prune(&s)
        report(&s, moves)
    }

    /// A career move this month, for the news and the Pulse.
    struct Move {
        enum Kind { case joined, founded, promoted, steppedDown, retired, government, critic, academia, investor, press, scripted }
        var personID: String
        var kind: Kind
        var from: String
        var to: String
        var role: String
        /// How newsworthy (0–1).
        var weight: Double
    }

    /// Timeline beats whose date has come: people join the story, change jobs and found the labs history says they found.
    static func scripted(_ s: inout GameState, _ moves: inout [Move]) {
        let now = s.date
        let nowYM = now.ym
        var at: [String: Int] = [:]
        for (k, p) in s.cast.enumerated() where CastCatalog.byID[p.id] != nil { at[p.id] = k }
        for p in CastCatalog.people {
            // Careers that have played every beat cost nothing.
            if let i = at[p.id], s.cast[i].beatsDone.count >= p.beats.count { continue }
            for (k, beat) in p.beats.enumerated() where beat.ym <= nowYM {
                let key = "\(p.id)#\(k)"
                guard let i = at[p.id] else {
                    if k == 0 {
                        s.cast.append(member(p, upTo: now))
                        at[p.id] = s.cast.count - 1
                    }
                    break
                }
                if s.cast[i].beatsDone.contains(key) { continue }
                s.cast[i].beatsDone.append(key)
                // History says this happens — unless the person's life has already gone another way (you bought the lab).
                if isLab(beat.org), let c = s.competitors.first(where: { $0.id == beat.org }), !c.exitNote.isEmpty { continue }
                if !s.cast[i].active { continue }
                let onScript = k == 0 || p.beats[k - 1].org == s.cast[i].org
                let from = s.cast[i].org
                let founding = beat.kind == .leader && isLab(beat.org) && from != beat.org
                let text = onScript ? beat.text
                    : (founding ? "Founded \(orgName(beat.org, s))." : "Joined \(orgName(beat.org, s)) as \(lowerFirst(beat.role)).")
                move(&s, i, to: beat.org, role: beat.role, kind: beat.kind, text: text)
                if from != beat.org {
                    moves.append(Move(personID: p.id, kind: founding ? .founded : .scripted, from: from, to: beat.org,
                                      role: beat.role, weight: founding ? 0.9 : 0.35 * p.stature))
                }
            }
        }
    }

    /// Move someone to a new job (dated today unless `on` says otherwise).
    static func move(_ s: inout GameState, _ i: Int, to org: String, role: String, kind: CastKind, text: String, on date: Date? = nil) {
        let old = s.cast[i].org
        if old != org && !old.isEmpty { s.cast[i].lastLab = old }
        if old != org { s.cast[i].desc = "" }
        s.cast[i].org = org
        s.cast[i].role = role
        s.cast[i].kind = kind.rawValue
        s.cast[i].since = date ?? s.date
        s.cast[i].active = true
        s.cast[i].history.insert(CastEntry(date: date ?? s.date, text: text, org: org, role: role), at: 0)
        if s.cast[i].history.count > historyCap { s.cast[i].history.removeLast(s.cast[i].history.count - historyCap) }
    }

    // MARK: New people

    /// A plausible name for someone hired in `hq`, not already taken — and, where possible, not sharing a family name with
    /// anyone active in the story, so nobody reads them as relatives.
    static func makeName(_ s: GameState, key: String, hq: String) -> (name: String, region: String) {
        let pool = CastCatalog.hiringPool(hq)
        let taken = Set(s.cast.map(\.name)).union(CompetitorCatalog.all.map(\.ceo))
        let families = famousSurnames.union(s.cast.filter(\.active).map { surname($0) })
        for attempt in 0..<10 {
            let region = weighted(s, "\(key)|region\(attempt)", pool) ?? "US"
            guard let np = CastCatalog.names[region], let f = pick(s, "\(key)|first\(attempt)", np.first),
                  let l = pick(s, "\(key)|last\(attempt)", np.last) else { continue }
            let name = np.familyFirst ? "\(l) \(f)" : "\(f) \(l)"
            if !taken.contains(name) && (!families.contains(l) || attempt >= 6) { return (name, region) }
        }
        return ("Alex Morgan", "US")
    }

    static let famousSurnames: Set<String> = Set(CastCatalog.people.filter { $0.stature >= 0.5 }.map { surname(of: $0.name, region: $0.region) })

    /// How the press refers to someone the second time: "Kearney", "Zhou".
    static func surname(of name: String, region: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        guard let first = parts.first, let last = parts.last else { return name }
        let familyFirst = region == "China" || (CastCatalog.names[region]?.familyFirst ?? false)
        if familyFirst { return first }
        // "Sanne de Vries" → "de Vries".
        if parts.count >= 3, let particle = parts[parts.count - 2].first, particle.isLowercase { return parts.suffix(2).joined(separator: " ") }
        return last
    }

    static func surname(_ p: CastMember) -> String { surname(of: p.name, region: p.region) }

    /// Titles that don't survive a takeover: the bought lab's chiefs become research directors at the buyer.
    static func senior(_ role: String) -> Bool {
        let r = role.lowercased()
        return r.contains("chief") || r.contains("president") || r.contains("director") || r.hasPrefix("head of")
    }

    /// Where a name from the name pools comes from (nil for names the pools don't know).
    static func regionOf(_ name: String) -> String? {
        let parts = name.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        for (region, pool) in CastCatalog.names.sorted(by: { $0.key < $1.key }) {
            let family = pool.familyFirst ? parts[0] : parts[parts.count - 1]
            let given = pool.familyFirst ? parts[parts.count - 1] : parts[0]
            if pool.last.contains(family) && pool.first.contains(given) { return region }
        }
        for (region, pool) in CastCatalog.names.sorted(by: { $0.key < $1.key }) where pool.last.contains(pool.familyFirst ? parts[0] : parts[parts.count - 1]) {
            return region
        }
        return nil
    }

    /// A university someone from `region` plausibly studied or taught at.
    static func university(_ s: GameState, _ key: String, region: String) -> String {
        let all = CastCatalog.universities
        if region == "China" && roll(s, key + "|cn") < 0.7 { return "the Qiantang Institute" }
        return pick(s, key, all.filter { $0 != "the Qiantang Institute" }) ?? "Northfield University"
    }

    /// What someone in a lab role works on ("Agents lead" → "agent research"), for the way the press describes them.
    static func focus(forRole role: String) -> String {
        switch role {
        case "Reasoning lead": "reasoning research"
        case "Post-training lead": "post-training"
        case "Agents lead": "agent research"
        case "Pre-training lead": "pre-training"
        case "Inference lead": "inference engineering"
        default: role.replacingOccurrences(of: " lead", with: "").lowercased()
        }
    }

    /// Your employees' jobs as the press writes them.
    static func jobTitle(_ r: Role) -> String {
        switch r {
        case .researcher: "Research scientist"
        case .mlEngineer: "ML engineer"
        case .infra: "Infrastructure engineer"
        case .data: "Data engineer"
        case .sales: "Partnerships lead"
        case .safety: "Safety researcher"
        case .chipDesigner: "Chip designer"
        }
    }

    static func jobFocus(_ r: Role) -> String {
        switch r {
        case .researcher: "research"
        case .mlEngineer: "ML engineering"
        case .infra: "infrastructure"
        case .data: "data"
        case .sales: "partnerships"
        case .safety: "safety research"
        case .chipDesigner: "chip design"
        }
    }

    static let researchTraits: [CastTrait] = [.academic, .pragmatic, .bold, .secretive, .cautious, .hypeProne, .contrarian]
    static let leaderTraits: [CastTrait] = [.bold, .pragmatic, .showman, .cautious, .academic, .contrarian, .accelerationist]

    static func voiceFor(_ t: CastTrait, _ s: GameState, _ key: String) -> VoiceStyle {
        switch t {
        case .bold: roll(s, key) < 0.5 ? .brash : .showman
        case .showman: .showman
        case .cautious: roll(s, key) < 0.5 ? .measured : .earnest
        case .academic: .professor
        case .contrarian: roll(s, key) < 0.6 ? .contrarian : .wry
        case .pragmatic: roll(s, key) < 0.6 ? .measured : .numbers
        case .secretive: .terse
        case .hypeProne, .accelerationist: .booster
        case .doomer: .alarmed
        }
    }

    /// Someone new to the story (not yet added).
    static func newPerson(_ s: GameState, key: String, name: String? = nil, hq: String, kind: CastKind, org: String, role: String,
                          focus: String, stature: Double, lab: String = "") -> CastMember {
        let made = makeName(s, key: key, hq: hq)
        let nm = name ?? made.name
        let region = nm == made.name ? made.region : (regionOf(nm) ?? CastCatalog.hiringPool(hq).max { $0.1 < $1.1 }?.0 ?? "US")
        let pool = kind == .leader ? leaderTraits : researchTraits
        let t1 = pick(s, key + "|t1", pool) ?? .pragmatic
        let t2 = pick(s, key + "|t2", pool.filter { $0 != t1 }) ?? .academic
        let home = lab.isEmpty ? org : lab
        let openLab = CompetitorCatalog.lookup(home)?.openWeights ?? false
        let labSafety = isLab(home) ? Competitors.trait(home).safety : 0
        let open = clamp((openLab ? 0.6 : -0.2) + (roll(s, key + "|open") - 0.5) * 0.6, -1, 1)
        let safety = clamp(0.4 + labSafety / 40 + (roll(s, key + "|safety") - 0.5) * 0.5, 0, 1)
        let regulation = clamp((safety - 0.45) * 1.2 + (roll(s, key + "|reg") - 0.5) * 0.6, -1, 1)
        let parts = nm.folding(options: .diacriticInsensitive, locale: nil).lowercased().replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "'", with: "").split(separator: " ")
        let handle = "@" + (parts.count >= 2 ? "\(parts[0])\(parts[parts.count - 1].prefix(1))" : String(parts.first ?? "anon"))
        let id = "gen-\(String(UInt64(roll(s, key + "|id") * 2_176_782_336), radix: 36))-\(s.cast.count)"
        var m = CastMember(id: id, name: nm, kind: kind.rawValue, role: role, org: org, traits: [t1.rawValue, t2.rawValue],
                           voice: voiceFor(t1, s, key + "|voice").rawValue, open: open, safety: safety, regulation: regulation,
                           handle: handle, region: region, stature: stature, since: s.date)
        m.focus = focus
        return m
    }

    /// Add someone new with a little past (years ago, organisation, role, line), newest last in the list.
    static func addWithPast(_ s: inout GameState, _ m: CastMember, past: [(Int, String, String, String)], text: String, on date: Date? = nil) {
        var m = m
        let today = date ?? s.date
        var history = past.map { CastEntry(date: GameCalendar.addMonths(today, -12 * $0.0), text: $0.3, org: $0.1, role: $0.2) }
        history.sort { $0.date > $1.date }
        history.insert(CastEntry(date: today, text: text, org: m.org, role: m.role), at: 0)
        m.history = Array(history.prefix(historyCap))
        m.since = today
        if let prev = history.dropFirst().first(where: { !$0.org.isEmpty && $0.org != m.org }) { m.lastLab = prev.org }
        s.cast.append(m)
    }

    // MARK: Labs founded during the game

    /// The founder of a spin-out from `parent`: one of its researchers, someone who left it lately, or — when the cast knows
    /// nobody there — a new name. RivalLifecycle puts the name in its news; `labFounded` then moves (or adds) the person.
    static func spinoutFounder(_ s: GameState, from parent: String, key: String) -> String {
        // Researchers leave to found labs far more often than chief scientists do; someone already out the door is likeliest.
        let pool: [(String, Double)] = s.cast.compactMap { p in
            guard p.active else { return nil }
            if p.org == parent && p.castKind == .researcher && p.employeeID.isEmpty { return (p.name, 0.3 + p.stature) }
            if p.org == parent && p.castKind == .scientist { return (p.name, 0.4 * (0.3 + p.stature)) }
            if p.castKind == .free && p.lastLab == parent && p.role != "Retired" { return (p.name, 1.2 * (0.3 + p.stature)) }
            return nil
        }
        if let name = weighted(s, "spinout|\(key)|\(monthIndex(s))", pool) { return name }
        return makeName(s, key: "founder|\(key)", hq: CompetitorCatalog.def(parent).hq).name
    }

    /// What a spin-out's founder led at the parent lab, for the founding story ("who led reasoning RL at Prometheus").
    static func team(_ s: GameState, founder: String, parent: String) -> String? {
        guard let p = s.cast.first(where: { $0.name == founder && ($0.org == parent || $0.lastLab == parent) }), !p.focus.isEmpty else { return nil }
        return p.focus
    }

    /// A founder's name for a new lab in `hq`: sometimes someone the industry already knows who is between jobs, usually a
    /// new face.
    static func founderName(_ s: GameState, key: String, hq: String) -> String {
        let local = Set(CastCatalog.hiringPool(hq).filter { $0.1 >= 1 }.map(\.0))
        let free = s.cast.filter { $0.active && $0.castKind == .free && $0.stature >= 0.3 && $0.role != "Retired" }
        if !free.isEmpty, roll(s, "founder-known|\(key)") < 0.45,
           let p = weighted(s, "founder-who|\(key)", free.map { ($0, $0.stature * (local.contains($0.region) ? 1 : 0.3)) }) {
            return p.name
        }
        return makeName(s, key: "founder|\(key)", hq: hq).name
    }

    /// The director of a national lab in `hq`: someone from that country — now and then a known name between jobs.
    static func directorName(_ s: GameState, key: String, hq: String) -> String {
        let home = CastCatalog.hiringPool(hq).max { $0.1 < $1.1 }?.0 ?? "US"
        let free = s.cast.filter { $0.active && $0.castKind == .free && $0.region == home && $0.stature >= 0.3 && $0.role != "Retired" }
        if !free.isEmpty, roll(s, "director-known|\(key)") < 0.35, let p = weighted(s, "director-who|\(key)", free.map { ($0, $0.stature) }) {
            return p.name
        }
        let taken = Set(s.cast.map(\.name))
        for attempt in 0..<8 {
            guard let np = CastCatalog.names[home], let f = pick(s, "director|\(key)|first\(attempt)", np.first),
                  let l = pick(s, "director|\(key)|last\(attempt)", np.last) else { break }
            let name = np.familyFirst ? "\(l) \(f)" : "\(f) \(l)"
            if !taken.contains(name) { return name }
        }
        return makeName(s, key: "director|\(key)", hq: hq).name
    }

    /// A lab was founded: its founder takes charge (moved from wherever they were, or new to the story), and a chief
    /// scientist joins — often someone between jobs, sometimes a researcher who leaves the parent lab with the founder.
    static func labFounded(_ s: inout GameState, _ spec: CustomLabSpec) {
        guard !s.cast.isEmpty else { return }
        ensureFounder(&s, spec)
        guard !s.cast.contains(where: { $0.active && $0.org == spec.id && $0.castKind == .scientist }) else { return }
        let key = "cofounder|\(spec.id)"
        let parentPeople = s.cast.filter { $0.active && $0.org == spec.parentID && $0.castKind == .researcher }
        let free = s.cast.filter { $0.active && $0.castKind == .free && $0.name != spec.ceo && $0.stature >= 0.25 }
        let r = roll(s, key)
        let local = Set(CastCatalog.hiringPool(spec.hq).filter { $0.1 >= 1 }.map(\.0))
        var picked: String? = nil
        if spec.kind == .spinout && !parentPeople.isEmpty && r < 0.45 {
            picked = weighted(s, key + "|p", parentPeople.map { ($0.id, 0.3 + $0.stature) })
        } else if !free.isEmpty && r < (spec.kind == .sovereign ? 0.6 : 0.75) {
            // A national lab hires its own; anyone else may hire from anywhere, locals first.
            let fitting = free.filter { spec.kind != .sovereign || local.contains($0.region) }
            picked = weighted(s, key + "|f", fitting.map { ($0.id, (0.3 + $0.stature) * (local.contains($0.region) ? 1 : 0.4)) })
        }
        let name = orgName(spec.id, s)
        if let id = picked, let i = index(s, id: id) {
            let from = orgName(s.cast[i].org.isEmpty ? s.cast[i].lastLab : s.cast[i].org, s, short: true)
            move(&s, i, to: spec.id, role: "Chief scientist", kind: .scientist,
                 text: from.isEmpty ? "Joined \(name) as co-founder and chief scientist." : "Left \(from) to co-found \(name) as chief scientist.")
            Pulse.personal(&s, s.cast[i].id, "joined")
        } else {
            let hq = spec.kind == .sovereign ? spec.hq : (spec.kind == .spinout && isLab(spec.parentID) ? CompetitorCatalog.def(spec.parentID).hq : spec.hq)
            let m = newPerson(s, key: key, hq: hq, kind: .scientist, org: spec.id, role: "Chief scientist",
                              focus: pick(s, key + "|focus", RivalLifecycle.teams) ?? "research", stature: 0.3, lab: spec.id)
            let prevLab = pick(s, key + "|prev", pastLabs(s, yearsAgo: 4, region: m.region, excluding: spec.id)) ?? ""
            let uni = university(s, key + "|uni", region: m.region)
            addWithPast(&s, m, past: prevLab.isEmpty ? [(6, uni, "Researcher", "Research at \(uni).")]
                                     : [(7, uni, "PhD researcher", "PhD at \(uni)."), (4, prevLab, "Research scientist", "Joined \(orgName(prevLab, s)).")],
                        text: spec.kind == .sovereign ? "Named chief scientist of \(name)." : "Co-founded \(name) as chief scientist.")
        }
    }

    /// Make sure a lab founded during the game has its founder in the cast.
    static func ensureFounder(_ s: inout GameState, _ spec: CustomLabSpec, on date: Date? = nil) {
        if s.cast.contains(where: { $0.active && $0.org == spec.id && $0.castKind == .leader }) { return }
        let lab = orgName(spec.id, s)
        let role = spec.kind == .sovereign ? "Director" : "Chief executive"
        let parent = spec.parentID == "player" ? s.companyName : spec.parentName
        if let i = s.cast.firstIndex(where: { $0.name == spec.ceo && $0.active && $0.org != spec.id }) {
            let from = orgName(s.cast[i].org, s, short: true)
            let text: String
            switch spec.kind {
            case .spinout: text = "Left \(parent.isEmpty ? from : parent) to found \(lab)."
            case .sovereign: text = "Named director of \(lab)."
            case .startup: text = from.isEmpty ? "Came back with a new lab: \(lab)." : "Left \(from) to found \(lab)."
            }
            move(&s, i, to: spec.id, role: role, kind: .leader, text: text, on: date)
            s.cast[i].stature = max(s.cast[i].stature, 0.45)
            return
        }
        let key = "found|\(spec.id)"
        let today = date ?? s.date
        let nameHQ = spec.kind == .spinout && isLab(spec.parentID) ? CompetitorCatalog.def(spec.parentID).hq : spec.hq
        var m = newPerson(s, key: key, name: spec.ceo, hq: nameHQ, kind: .leader, org: spec.id, role: role,
                          focus: spec.thesis, stature: spec.kind == .sovereign ? 0.45 : 0.4, lab: spec.id)
        m.blurb = spec.kind == .sovereign ? "Leads \(lab), a \(lowerFirst(spec.archetype))." : "Founded \(lab) to build \(spec.thesis)."
        let uni = university(s, key + "|uni", region: m.region)
        func elsewhere(_ years: Int) -> String? {
            pick(s, key + "|lab\(years)", pastLabs(s, yearsAgo: years, region: m.region, excluding: spec.id, on: today).filter { CompetitorCatalog.spec($0) == nil })
        }
        switch spec.kind {
        case .spinout:
            let team = pick(s, key + "|team", RivalLifecycle.teams) ?? "research"
            let parentOrg = spec.parentID.isEmpty ? (elsewhere(6) ?? "") : spec.parentID
            let parentName = parent.isEmpty ? orgName(parentOrg, s) : parent
            // They joined the parent when it existed: at most six years ago, and no earlier than its founding.
            let founded = isLab(parentOrg) ? CompetitorCatalog.def(parentOrg).founded.date.decimalYear : today.decimalYear - 6
            let joined = max(1, min(6, Int(today.decimalYear - founded)))
            var past: [(Int, String, String, String)] = [(joined + 3, uni, "PhD researcher", "PhD at \(uni)."),
                                                         (joined, parentOrg, "Research scientist", "Joined \(parentName).")]
            if joined >= 3 { past.append((joined / 2, parentOrg, "Team lead", "Led \(team) at \(parentName).")) }
            addWithPast(&s, m, past: parentOrg.isEmpty ? [(6, uni, "PhD researcher", "PhD at \(uni).")] : past,
                        text: "Left \(parentName) to found \(lab).", on: date)
        case .startup:
            if roll(s, key + "|path") < 0.4 {
                addWithPast(&s, m, past: [(10, uni, "Professor", "Professor at \(uni).")], text: "Took leave from \(uni) to found \(lab).", on: date)
            } else if let prev = elsewhere(5) {
                addWithPast(&s, m, past: [(8, uni, "PhD researcher", "PhD at \(uni)."), (5, prev, "Research scientist", "Joined \(orgName(prev, s))."),
                                          (2, "", "Founder", "Sold a small AI startup.")],
                            text: "Founded \(lab).", on: date)
            } else {
                addWithPast(&s, m, past: [(7, uni, "PhD researcher", "PhD at \(uni)."), (3, "", "Founder", "Sold a small AI startup.")],
                            text: "Founded \(lab).", on: date)
            }
        case .sovereign:
            let before = elsewhere(7)
            let city = before.map { CompetitorCatalog.def($0).hq.lowercased().components(separatedBy: " & ")[0] } ?? ""
            let text = before.map { spec.hq.lowercased().contains(city) ? "Left \(orgName($0, s)) to lead \(lab)." : "Came home to lead \(lab)." }
            addWithPast(&s, m, past: [(12, uni, "Researcher", "Research at \(uni).")]
                            + (before.map { [(7, $0, "Research director", "Ran a research group at \(orgName($0, s)).")] } ?? []),
                        text: text ?? "Named director of \(lab).", on: date)
        }
    }

    // MARK: Labs leaving the market

    /// A lab was bought, merged, wound down or went bankrupt: its people go to the buyer, to other labs, to academia or onto
    /// the market. `quiet` skips the Pulse (used when seeding an old save).
    static func labClosed(_ s: inout GameState, _ labID: String, quiet: Bool = false) {
        guard !s.cast.isEmpty, let c = s.competitors.first(where: { $0.id == labID }) else { return }
        let lab = orgName(labID, s)
        let buyer = c.acquiredBy
        let soldOutside = buyer.isEmpty && c.exitNote.hasPrefix("Acquired by")
        let key = "closed|\(labID)"
        let when = quiet ? c.exitDate : nil
        let others = s.competitors.filter { $0.alive && $0.id != labID && s.year >= $0.def.founded.decimal }
        let buyerAlive = isLab(buyer) && (s.competitors.first { $0.id == buyer }?.alive ?? false)
        var joinedYou: [Int] = []
        for i in s.cast.indices where s.cast[i].active && s.cast[i].org == labID {
            let r = roll(s, "\(key)|\(s.cast[i].id)")
            let isLeader = s.cast[i].castKind == .leader
            if buyerAlive {
                let bname = orgName(buyer, s)
                if isLeader {
                    if r < 0.4 {
                        move(&s, i, to: buyer, role: "Head of \(short(labID))", kind: .researcher, text: "Stayed on to run \(short(labID)) inside \(bname).", on: when)
                    } else {
                        move(&s, i, to: "", role: "Former chief executive", kind: .free, text: "Left after \(bname) bought \(lab).", on: when)
                    }
                } else if r < 0.65 {
                    move(&s, i, to: buyer, role: senior(s.cast[i].role) ? "Research director" : s.cast[i].role, kind: .researcher,
                         text: "Joined \(bname) when it bought \(lab).", on: when)
                } else {
                    scatter(&s, i, from: lab, others: others, key: key, on: when)
                }
            } else if buyer == "player" {
                if isLeader {
                    if r < 0.35 {
                        move(&s, i, to: "player", role: "Adviser", kind: .researcher, text: "Stayed on as an adviser after \(s.companyName) bought \(lab).", on: when)
                    } else {
                        move(&s, i, to: "", role: "Former chief executive", kind: .free, text: "Left after \(s.companyName) bought \(lab).", on: when)
                    }
                } else if r < 0.6 {
                    move(&s, i, to: "player", role: "Research scientist", kind: .researcher, text: "Joined \(s.companyName) when it bought \(lab).", on: when)
                    joinedYou.append(i)
                } else {
                    scatter(&s, i, from: lab, others: others, key: key, on: when)
                }
            } else if soldOutside {
                let giant = c.exitNote.dropFirst("Acquired by ".count).components(separatedBy: " for ").first ?? "a tech giant"
                if isLeader {
                    move(&s, i, to: "", role: "Former chief executive", kind: .free, text: "Left when \(lab) was sold to \(giant).", on: when)
                } else if r < 0.5 {
                    move(&s, i, to: giant, role: s.cast[i].role, kind: .researcher, text: "Went with \(lab) to \(giant).", on: when)
                } else {
                    scatter(&s, i, from: lab, others: others, key: key, on: when)
                }
            } else if isLeader {
                move(&s, i, to: "", role: "Former chief executive", kind: .free,
                     text: c.bankrupt ? "Was in charge when \(lab) went bankrupt." : "Wound down \(lab) and returned what was left to investors.", on: when)
            } else {
                scatter(&s, i, from: lab, others: others, key: key, on: when)
            }
        }
        // The researchers you inherit in an acquisition are the lab's named people.
        if buyer == "player" { linkInherited(&s, joinedYou) }
        if !quiet { Pulse.labClosed(&s, labID) }
    }

    /// Someone whose lab disappeared lands somewhere: another lab, a university, or between jobs.
    static func scatter(_ s: inout GameState, _ i: Int, from lab: String, others: [CompetitorState], key: String, on date: Date? = nil) {
        let pid = s.cast[i].id
        let region = s.cast[i].region
        let r = roll(s, "\(key)|where|\(pid)")
        let dests = others.map { ($0.id, fits(region, $0.id) * stanceFit(s.cast[i], $0.id) * (0.4 + log10(max(1, $0.valuation / 1e9)) + (RivalStrategy.play($0) == .talentRaid ? 1 : 0))) }
        if r < 0.55, let dest = weighted(s, "\(key)|dest|\(pid)", dests.filter { $0.1 > 0 }) {
            move(&s, i, to: dest, role: "Research scientist", kind: .researcher, text: "Joined \(orgName(dest, s)) after \(lab) closed.", on: date)
        } else if r < 0.7 {
            let uni = university(s, "\(key)|uni|\(pid)", region: region)
            move(&s, i, to: uni, role: "Visiting professor", kind: .academic, text: "Went back to academia at \(uni) after \(lab) ended.", on: date)
        } else {
            move(&s, i, to: "", role: "Researcher", kind: .free, text: "Between jobs after \(lab) ended.", on: date)
        }
    }

    /// Researchers you inherit in an acquisition carry the names of the lab's people who joined you.
    static func linkInherited(_ s: inout GameState, _ joined: [Int]) {
        var fresh = s.employees.indices.filter { s.employees[$0].hired == s.date && s.employees[$0].role == .researcher }
        for i in joined {
            guard let e = fresh.popLast() else { break }
            s.employees[e].name = s.cast[i].name
            s.cast[i].employeeID = s.employees[e].id.uuidString
        }
    }

    // MARK: Your people

    /// The cast entry for one of your employees (created the first time they matter).
    @discardableResult
    static func yours(_ s: inout GameState, _ e: Employee) -> Int {
        if let i = s.cast.firstIndex(where: { $0.employeeID == e.id.uuidString }) { return i }
        if s.cast.isEmpty { seed(&s) }
        let title = jobTitle(e.role)
        var m = newPerson(s, key: "yours|\(e.id.uuidString)", name: e.name, hq: s.sites.first?.location.name ?? "San Francisco", kind: .researcher,
                          org: "player", role: title, focus: jobFocus(e.role), stature: e.star ? 0.4 : 0.25)
        m.employeeID = e.id.uuidString
        m.since = e.hired
        m.blurb = "\(title) at \(s.companyName)\(e.star ? ", one of its stars" : "")."
        m.history = [CastEntry(date: e.hired, text: "Joined \(s.companyName) as \(article(title)) \(lowerFirst(title)).", org: "player", role: title)]
        s.cast.append(m)
        return s.cast.count - 1
    }

    /// One of your people got a big title (made Chief Scientist to keep them).
    static func promotedAtHome(_ s: inout GameState, _ e: Employee, title: String) {
        let i = yours(&s, e)
        move(&s, i, to: "player", role: title, kind: title == "Chief scientist" ? .scientist : .researcher, text: "Became \(possessive(s.companyName)) \(lowerFirst(title)).")
        s.cast[i].stature = max(s.cast[i].stature, 0.5)
        Pulse.personal(&s, s.cast[i].id, "promoted")
    }

    /// One of your people left: to found something (`lab` empty), or for a rival (its ID, its name, or a description).
    static func leftYou(_ s: inout GameState, _ e: Employee, to lab: String, why: String = "", pulse: Bool = true) {
        let i = yours(&s, e)
        let labID = s.competitors.first(where: { $0.id == lab || $0.def.name == lab })?.id
        let tail = why.isEmpty ? "." : (why.hasPrefix("in ") ? " \(why)." : ", \(why).")
        let title = jobTitle(e.role)
        if let labID {
            move(&s, i, to: labID, role: title, kind: .researcher, text: "Left \(s.companyName) for \(orgName(labID, s))\(tail)")
        } else if lab.isEmpty {
            move(&s, i, to: "", role: "Founder", kind: .free, text: "Left \(s.companyName) to start a lab of their own.")
        } else {
            move(&s, i, to: lab, role: title, kind: .researcher, text: "Left \(s.companyName) for \(lab)\(tail)")
        }
        s.cast[i].employeeID = ""
        s.cast[i].lastLab = "player"
        if pulse { Pulse.personal(&s, s.cast[i].id, lab.isEmpty ? "leaving" : "joined") }
    }

    // MARK: Staffing (after October 2026)

    /// Every lab in business has a leader and, once established, a chief scientist and a researcher or two the press knows
    /// by name. Vacancies are filled by promotion first.
    static func staffing(_ s: inout GameState, _ moves: inout [Move]) {
        let m = monthIndex(s)
        for c in s.competitors where c.alive && s.year >= c.def.founded.decimal {
            let lab = c.id
            let name = orgName(lab, s)
            var people = staff(s, lab)
            if !people.contains(where: { $0.castKind == .leader }) {
                let title = c.spec?.kind == .sovereign ? "Director" : "Chief executive"
                if let next = people.first(where: { $0.castKind == .scientist }) ?? people.first, let i = index(s, id: next.id) {
                    move(&s, i, to: lab, role: title, kind: .leader, text: "Took over as \(possessive(name)) \(lowerFirst(title)).")
                    s.cast[i].stature = min(1, max(s.cast[i].stature, 0.5))
                    moves.append(Move(personID: next.id, kind: .promoted, from: lab, to: lab, role: title, weight: 0.85))
                } else {
                    let p = newPerson(s, key: "ceo|\(lab)|\(m)", hq: c.def.hq, kind: .leader, org: lab, role: title, focus: "the business", stature: 0.5, lab: lab)
                    let prev = pick(s, "ceo-prev|\(lab)|\(m)", ["Nimbus Cloud", "a chip giant", "a search giant", "a consulting firm"]) ?? "a tech giant"
                    addWithPast(&s, p, past: [(6, prev, "Executive", "Ran a division at \(prev).")], text: "Hired as \(possessive(name)) \(lowerFirst(title)).")
                    moves.append(Move(personID: p.id, kind: .joined, from: "", to: lab, role: title, weight: 0.8))
                }
                people = staff(s, lab)
            }
            let established = c.spec == nil || (RivalLifecycle.age(c, s) ?? 0) >= 1
            if established && !people.contains(where: { $0.castKind == .scientist }) {
                if let next = people.filter({ $0.castKind == .researcher }).max(by: { $0.stature < $1.stature }), let i = index(s, id: next.id) {
                    move(&s, i, to: lab, role: "Chief scientist", kind: .scientist, text: "Promoted to chief scientist at \(name).")
                    s.cast[i].stature = min(1, s.cast[i].stature + 0.1)
                    moves.append(Move(personID: next.id, kind: .promoted, from: lab, to: lab, role: "Chief scientist", weight: 0.55))
                } else {
                    hire(&s, lab, role: "Chief scientist", kind: .scientist, key: "cs|\(lab)|\(m)", moves: &moves)
                }
                people = staff(s, lab)
            }
            let wanted = c.def.computeShare >= 0.15 ? 2 : (established && c.headcount >= 150 ? 1 : 0)
            if people.filter({ $0.castKind == .researcher }).count < wanted && roll(s, "hire|\(lab)|\(m)") < 0.35 {
                let role = pick(s, "hire-role|\(lab)|\(m)", ["Reasoning lead", "Post-training lead", "Agents lead", "Pre-training lead", "Inference lead"]) ?? "Research lead"
                hire(&s, lab, role: role, kind: .researcher, key: "res|\(lab)|\(m)", moves: &moves)
            }
        }
    }

    /// Someone new hired into a lab, with a past.
    static func hire(_ s: inout GameState, _ lab: String, role: String, kind: CastKind, key: String, moves: inout [Move]) {
        let hq = s.competitors.first { $0.id == lab }?.def.hq ?? "San Francisco"
        let p = newPerson(s, key: key, hq: hq, kind: kind, org: lab, role: role, focus: kind == .scientist ? "research" : focus(forRole: role),
                          stature: kind == .scientist ? 0.35 : 0.25, lab: lab)
        let uni = university(s, key + "|uni", region: p.region)
        let elsewhere = pick(s, key + "|prev", pastLabs(s, yearsAgo: 4, region: p.region, excluding: lab))
        let name = orgName(lab, s)
        if let elsewhere, roll(s, key + "|path") < 0.6 {
            addWithPast(&s, p, past: [(8, uni, "PhD researcher", "PhD at \(uni)."), (4, elsewhere, "Research scientist", "Joined \(orgName(elsewhere, s)).")],
                        text: "Joined \(name) as \(lowerFirst(role)).")
        } else {
            addWithPast(&s, p, past: [(6, uni, "Researcher", "Research at \(uni).")], text: "Left \(uni) to join \(name) as \(lowerFirst(role)).")
        }
        moves.append(Move(personID: p.id, kind: .joined, from: "", to: lab, role: role, weight: kind == .scientist ? 0.4 : 0.15))
    }

    // MARK: Churn (after October 2026)

    static func churn(_ s: inout GameState, _ moves: inout [Move]) {
        let m = monthIndex(s)
        let labs = s.competitors.filter { $0.alive && s.year >= $0.def.founded.decimal && !$0.models.isEmpty }
        guard !labs.isEmpty else { return }
        var events = 0

        // A leader pushed out by a lab in trouble, or one who has run a lab for a long time steps back.
        for c in labs where events < 2 {
            guard let l = leader(s, c.id), let i = index(s, id: l.id) else { continue }
            let years = Double(Cast.days(l.since, s.date)) / 365
            let trouble = c.distressMonths > 0 || c.turmoil > 0.8
            let odds = trouble && years >= 1.5 ? 0.05 : (years >= 12 ? 0.004 : 0)
            guard odds > 0, roll(s, "ceo-out|\(c.id)|\(m)") < odds else { continue }
            let name = orgName(c.id, s)
            if trouble {
                move(&s, i, to: "", role: "Former chief executive", kind: .free, text: "Pushed out as \(possessive(name)) chief executive after \(RivalLifecycle.turmoilReason(c, s)).")
            } else {
                move(&s, i, to: "", role: "Former chief executive", kind: .free, text: "Stepped back from running \(name).")
                if roll(s, "ceo-retire|\(c.id)|\(m)") < 0.5 { s.cast[i].active = false }
            }
            moves.append(Move(personID: l.id, kind: .steppedDown, from: c.id, to: "", role: l.role, weight: 1))
            events += 1
        }

        // A lab hires someone well known from another lab. Raiding and racing labs hire most; labs in turmoil lose most.
        let raiders = labs.filter { RivalStrategy.play($0) == .talentRaid }.count
        if events < 2, roll(s, "poach|\(m)") < min(0.35, 0.12 + 0.08 * Double(raiders)) {
            let movable = s.cast.filter { p in
                p.active && (p.castKind == .researcher || p.castKind == .scientist) && labs.contains { $0.id == p.org }
                    && Cast.days(p.since, s.date) > 540 && p.employeeID.isEmpty
            }
            let mover = weighted(s, "poach-who|\(m)", movable.map { p in (p, (0.3 + p.stature) * (0.5 + 2 * (labs.first { $0.id == p.org }?.turmoil ?? 0))) })
            if let p = mover, let i = index(s, id: p.id) {
                let dests = labs.filter { $0.id != p.org }.map { d -> (CompetitorState, Double) in
                    let play = RivalStrategy.play(d)
                    return (d, fits(p.region, d.id) * stanceFit(p, d.id) * (0.3 + (play == .talentRaid ? 2.5 : 0) + (play == .race ? 1 : 0) + min(2, log10(max(1, d.valuation / 1e9)))))
                }
                if let d = weighted(s, "poach-where|\(m)", dests.filter { $0.1 > 0 }) {
                    let role = p.castKind == .scientist ? (staff(s, d.id).contains { $0.castKind == .scientist } ? "Research director" : "Chief scientist") : p.role
                    move(&s, i, to: d.id, role: role, kind: role == "Chief scientist" ? .scientist : .researcher, text: "Left \(orgName(p.org, s)) for \(orgName(d.id, s)).")
                    moves.append(Move(personID: p.id, kind: .joined, from: p.org, to: d.id, role: role,
                                      weight: 0.3 + 0.5 * p.stature + (p.castKind == .scientist ? 0.2 : 0)))
                    events += 1
                }
            }
        }

        // Someone goes into government, or turns critic — more often after a scare.
        let scare = s.pulse.prefix(80).contains { $0.kind == PulseKind.safety.rawValue && Cast.days($0.date, s.date) < 90 }
        if events < 2, roll(s, "sides|\(m)") < 0.025 + (scare ? 0.04 : 0) {
            let pool = s.cast.filter { $0.active && $0.castKind == .researcher && isLab($0.org) && Cast.days($0.since, s.date) > 540 }
            if let p = weighted(s, "sides-who|\(m)", pool.map { ($0, 0.2 + $0.safety) }), let i = index(s, id: p.id) {
                let from = orgName(p.org, s)
                let uni = university(s, "sides-uni|\(m)", region: p.region)
                if p.regulation >= 0.2 && roll(s, "sides-gov|\(m)") < 0.5 {
                    let agency = agency(org: p.org, region: p.region)
                    move(&s, i, to: agency, role: "Chief technologist", kind: .official, text: "Left \(from) to join \(agency).")
                    moves.append(Move(personID: p.id, kind: .government, from: p.org, to: agency, role: "Chief technologist", weight: 0.45 + 0.3 * p.stature))
                } else if let org = pick(s, "critic|\(m)", p.safety >= 0.5 ? ["the Frontier Risk Institute", "the Frontier Risk Institute", uni] : [uni]) {
                    let critic = org == "the Frontier Risk Institute"
                    move(&s, i, to: org, role: critic ? "Senior fellow" : "Professor", kind: critic ? .critic : .academic,
                         text: critic ? "Quit \(from), saying the race was outrunning the safeguards, and joined \(org)." : "Left \(from) for a professorship at \(org).")
                    s.cast[i].safety = min(1, s.cast[i].safety + (critic ? 0.25 : 0.1))
                    s.cast[i].regulation = min(1, s.cast[i].regulation + (critic ? 0.3 : 0.1))
                    if critic { s.cast[i].voice = VoiceStyle.alarmed.rawValue }
                    moves.append(Move(personID: p.id, kind: critic ? .critic : .academia, from: p.org, to: org, role: critic ? "Senior fellow" : "Professor",
                                      weight: 0.4 + 0.4 * p.stature + (critic ? 0.15 : 0)))
                }
                events += 1
            }
        }

        // People between jobs land somewhere.
        let free = s.cast.filter { $0.active && $0.castKind == .free && Cast.days($0.since, s.date) > 90 }
        for p in free {
            guard roll(s, "land|\(p.id)|\(m)") < 0.1, let i = index(s, id: p.id) else { continue }
            let r = roll(s, "land-where|\(p.id)|\(m)")
            let landing = labs.map { ($0.id, fits(p.region, $0.id) * stanceFit(p, $0.id) * (0.4 + (RivalStrategy.play($0) == .talentRaid ? 1.5 : 0) + ((RivalLifecycle.age($0, s) ?? 9) < 2 ? 1 : 0))) }
            if r < 0.45, let d = weighted(s, "land-lab|\(p.id)|\(m)", landing.filter { $0.1 > 0 }) {
                let wasBoss = p.role.lowercased().contains("chief executive") || p.role == "Founder"
                let role = wasBoss ? "President" : "Research scientist"
                move(&s, i, to: d, role: role, kind: .researcher, text: "Joined \(orgName(d, s)) as \(lowerFirst(role)).")
                moves.append(Move(personID: p.id, kind: .joined, from: "", to: d, role: role, weight: 0.25 + 0.4 * p.stature))
            } else if r < 0.7, let fund = pick(s, "land-fund|\(p.id)|\(m)", NameBank.investors.filter { !$0.contains("(") }) {
                move(&s, i, to: fund, role: "Venture partner", kind: .investor, text: "Became a venture partner at \(fund).")
                if s.cast[i].voiceStyle.family == .terse { s.cast[i].voice = VoiceStyle.measured.rawValue }
                moves.append(Move(personID: p.id, kind: .investor, from: "", to: fund, role: "Venture partner", weight: 0.2 + 0.3 * p.stature))
            } else if r < 0.82 {
                let uni = university(s, "land-uni|\(p.id)|\(m)", region: p.region)
                move(&s, i, to: uni, role: "Professor", kind: .academic, text: "Joined the faculty at \(uni).")
                moves.append(Move(personID: p.id, kind: .academia, from: "", to: uni, role: "Professor", weight: 0.15 + 0.3 * p.stature))
            }
        }

        // Long careers end — not straight after a move, and rarely for the people who watch the industry for a living.
        let veterans = s.cast.filter { $0.active && $0.stature >= 0.5 && $0.castKind != .leader && Cast.days($0.since, s.date) > 730 }
        for p in veterans {
            let watcher = !p.castKind.atLab && p.castKind != .free
            guard let first = p.history.last?.date, Cast.days(first, s.date) > 365 * (watcher ? 20 : 14),
                  roll(s, "retire|\(p.id)|\(m)") < (watcher ? 0.0015 : 0.003), let i = index(s, id: p.id) else { continue }
            let years = Cast.days(first, s.date) / 365
            let org = orgName(p.org, s)
            let text: String
            switch p.castKind {
            case .official: text = "Left \(org) and public life after \(years) years."
            case .journalist, .analyst: text = "Retired after \(years) years of covering the industry."
            case .investor: text = "Retired from \(org) after \(years) years of investing."
            default: text = org.isEmpty ? "Retired after \(years) years in the field." : "Retired from \(org) after \(years) years in the field."
            }
            move(&s, i, to: "", role: "Retired", kind: .free, text: text)
            s.cast[i].active = false
            moves.append(Move(personID: p.id, kind: .retired, from: p.org, to: "", role: "Retired", weight: 0.35 + 0.3 * p.stature))
        }
    }

    /// Reporters, analysts and investors change desks now and then (any year).
    static func watcherChurn(_ s: inout GameState, _ moves: inout [Move]) {
        let m = monthIndex(s)
        guard roll(s, "desk|\(m)") < 0.02 else { return }
        // People who own what they run (a newsletter, a research shop, a podcast) stay put.
        let owners = ["Founded", "Co-founded", "Started", "Launched"]
        let pool = s.cast.filter { p in
            p.active && (p.castKind == .journalist || p.castKind == .analyst) && Cast.days(p.since, s.date) > 900
                && !p.history.contains { h in owners.contains { h.text.hasPrefix($0) } }
        }
        guard let p = pick(s, "desk-who|\(m)", pool), let i = index(s, id: p.id) else { return }
        let newsrooms = ["The Informant", "The Ledger", "Circuit Weekly", "Pacific Wire"] + (p.region == "France" ? ["Le Réseau"] : [])
        if p.castKind == .journalist, CastCatalog.outlets.contains(p.org), let dest = pick(s, "desk-where|\(m)", newsrooms.filter { $0 != p.org }) {
            move(&s, i, to: dest, role: p.role, kind: .journalist, text: "Moved from \(p.org) to \(dest).")
            moves.append(Move(personID: p.id, kind: .press, from: p.org, to: dest, role: p.role, weight: 0.15))
        } else if p.castKind == .analyst, p.org != "The Compute Ledger" && p.org != "Bastion Threat Intel",
                  let fund = pick(s, "desk-fund|\(m)", NameBank.investors.filter { !$0.contains("(") }) {
            move(&s, i, to: fund, role: "Partner", kind: .investor, text: "Left \(p.org) to become a partner at \(fund).")
            moves.append(Move(personID: p.id, kind: .investor, from: p.org, to: fund, role: "Partner", weight: 0.2))
            // The desk doesn't stay empty for long.
            var hire = newPerson(s, key: "desk-new|\(m)", hq: "New York", kind: .analyst, org: p.org, role: "AI analyst", focus: p.focus, stature: 0.35)
            hire.voice = VoiceStyle.numbers.rawValue
            let uni = university(s, "desk-new-uni|\(m)", region: hire.region)
            addWithPast(&s, hire, past: [(7, uni, "PhD researcher", "PhD in economics at \(uni).")], text: "Joined \(p.org) to cover AI.")
        }
    }

    /// Keep the cast to a readable size: the long-retired and long-forgotten go first.
    static func prune(_ s: inout GameState) {
        guard s.cast.count > cap else { return }
        // The catalog's people always stay (their scripted careers would otherwise bring them back).
        let catalog = CastCatalog.byID
        let scored = s.cast.enumerated().filter { catalog[$0.element.id] == nil }.map { k, p -> (Int, Double) in
            var keep = p.stature + (p.active ? 0.5 : 0) + (p.employeeID.isEmpty ? 0 : 1) + (p.castKind.atLab && isLab(p.org) ? 0.4 : 0)
            if p.castKind == .free { keep -= 0.3 }
            keep -= Double(Cast.days(p.since, s.date)) / 3650
            return (k, keep)
        }
        let drop = Set(scored.sorted { $0.1 < $1.1 }.prefix(s.cast.count - cap).map(\.0))
        s.cast = s.cast.enumerated().filter { !drop.contains($0.offset) }.map(\.element)
    }

    /// The month's moves: the most notable makes the news; the rest reach the Pulse.
    static func report(_ s: inout GameState, _ moves: [Move]) {
        let sorted = moves.sorted { $0.weight > $1.weight }
        for (k, mv) in sorted.enumerated() {
            if k == 0 && mv.weight >= 0.45 { Voices.career(&s, mv) }
            if k < 4 { Pulse.career(&s, mv) }
        }
    }
}
