import Foundation

// MARK: - 3.9: star researchers and the talent wars

/// Your best people as characters: a personality, a signature specialty and an ambition each; rivals bid for them and you
/// counter over a few rounds; they burn out, take sabbaticals, defect and sometimes come back; they win prizes that lift
/// your brand and bring more stars to the door; and pairs of them work well together, or don't.
enum Stars {
    static let offerKind = "star_offer"
    static let burnoutKind = "star_burnout"
    static let boomerangKind = "star_boomerang"
    static let raidKind = "star_raid"
    /// The panel and the system follow your dozen best.
    static let maxProfiles = 12
    static let maxRounds = 3
    static let lovelace = "Lovelace Award"
    static let stockholm = "Stockholm Prize"

    /// A per-game hashed roll: a star's personality is a function of who they are, not of the day they were noticed.
    static func roll(_ s: GameState, _ key: String) -> Double { Cast.roll(s, "stars|\(key)") }

    /// Hashed dice for one decision (keyed by game, day and purpose): the star system leaves the game's RNG alone, so
    /// adding it doesn't reshuffle every other system's luck.
    static func dice(_ s: GameState, _ key: String) -> GameRNG {
        GameRNG(seed: UInt64(roll(s, "\(key)|\(RivalIntel.dayIndex(s.date))") * 9_007_199_254_740_992))
    }

    static func isStar(_ e: Employee) -> Bool { e.star || e.skill >= 88 }

    static func index(_ s: GameState, _ id: String) -> Int? { s.stars.profiles.firstIndex { $0.id == id } }
    static func employeeIndex(_ s: GameState, _ id: String) -> Int? { s.employees.firstIndex { $0.id.uuidString == id } }

    /// Stars on sabbatical: they don't count toward research, MFU or anything else until they're back.
    static func away(_ s: GameState) -> Set<UUID> {
        guard s.stars.profiles.contains(where: { $0.sabbaticalUntil != nil }) else { return [] }
        return Set(s.stars.profiles.compactMap { $0.sabbaticalUntil == nil ? nil : UUID(uuidString: $0.id) })
    }

    static func firstName(_ name: String) -> String { String(name.split(separator: " ").first ?? Substring(name)) }

    /// A dedicated cluster for one person's ideas, a month (rented GPUs at the going rate).
    static func computeBudget(_ s: GameState) -> Double {
        (Double(computeGPUs(s)) * (s.year < 2021 ? 2.5 : 2.0) * 730 / 1_000).rounded() * 1_000
    }

    static func computeGPUs(_ s: GameState) -> Int { s.year < 2020 ? 64 : (s.year < 2023 ? 256 : (s.year < 2025.5 ? 1_024 : 2_048)) }

    // MARK: Profiles

    static let origins: [String] = [
        "Left a tenured post in Montreal because the compute was in industry.",
        "Dropped out of a Stanford PhD after one paper changed the field.",
        "Spent six years at a big-tech lab and shipped half of what it's known for.",
        "A physicist who wandered into deep learning and never left.",
        "Built a famous open-source library in their spare time.",
        "Ran the training team at a lab that no longer exists.",
        "Won an olympiad at sixteen and a best paper at twenty-four.",
        "Came from quant finance; still prices every decision.",
        "Co-wrote a paper every lab now cites in its model cards.",
        "Was a rival's most quoted researcher until you hired them.",
        "Taught themselves CUDA in a dorm room and never stopped.",
        "Ran a university lab whose alumni now lead three companies.",
        "Spent years in a government research institute before the boom.",
        "Moved from Zurich for the chance to work at the frontier.",
    ]

    static func personality(for e: Employee, _ s: GameState) -> StarPersonality {
        let r = roll(s, "pers|\(e.id.uuidString)")
        switch e.talent {
        case .loyal: return r < 0.7 ? .steady : .idealist
        case .diva: return r < 0.6 ? .showman : .maverick
        case .mentor: return r < 0.5 ? .scholar : .steady
        default: return StarPersonality.allCases[Int(r * Double(StarPersonality.allCases.count)) % StarPersonality.allCases.count]
        }
    }

    static func ambition(for p: StarPersonality, _ r: Double) -> StarAmbition {
        let pool: [StarAmbition]
        switch p {
        case .idealist: pool = [.mission, .mission, .publish, .ship]
        case .mercenary: pool = [.wealth, .wealth, .lead, .recognition]
        case .builder: pool = [.compute, .compute, .ship, .lead]
        case .showman: pool = [.recognition, .lead, .lead, .ship]
        case .scholar: pool = [.publish, .publish, .recognition, .compute]
        case .maverick: pool = [.lead, .compute, .publish, .recognition]
        case .steady: pool = [.ship, .ship, .lead, .wealth]
        }
        return pool[Int(r * Double(pool.count)) % pool.count]
    }

    static func makeProfile(_ s: GameState, _ e: Employee) -> StarProfile {
        let key = e.id.uuidString
        let pers = personality(for: e, s)
        let specs = StarSpecialty.options(e.role)
        let spec = specs[Int(roll(s, "spec|\(key)") * Double(specs.count)) % specs.count]
        var amb = ambition(for: pers, roll(s, "amb|\(key)"))
        if e.role == .sales, [.compute, .publish].contains(amb) { amb = .lead }   // sellers want a team, not a cluster
        var p = StarProfile(id: key, name: e.name, personality: pers, specialty: spec, ambition: amb,
                            origin: origins[Int(roll(s, "origin|\(key)") * Double(origins.count)) % origins.count], joined: e.hired)
        p.renown = clamp((e.skill - 80) * 2 + 6, 5, 40)
        p.fatigue = 10 + 20 * roll(s, "fat|\(key)")
        p.story = [StarBeat(date: e.hired, text: "Joined \(s.companyName) as \(Cast.article(e.role.title)) \(e.role.title.lowercased()).")]
        return p
    }

    static func beat(_ s: inout GameState, _ i: Int, _ text: String, tone: Int = 0) {
        s.stars.profiles[i].story.insert(StarBeat(date: s.date, text: text, tone: tone), at: 0)
        if s.stars.profiles[i].story.count > 16 { s.stars.profiles[i].story.removeLast() }
    }

    /// Profiles for new stars, alumni records for stars who left by any route (poached, let go, a talent raid).
    static func sync(_ s: inout GameState) {
        s.stars.synced = s.employees.count
        let ids = Set(s.employees.map { $0.id.uuidString })
        for p in s.stars.profiles where !ids.contains(p.id) { departed(&s, p) }
        s.stars.profiles.removeAll { !ids.contains($0.id) }
        guard s.stars.profiles.count < maxProfiles else { return }
        let have = Set(s.stars.profiles.map(\.id))
        let fresh = s.employees.filter { isStar($0) && !have.contains($0.id.uuidString) }.sorted { ($0.skill, $0.id.uuidString) > ($1.skill, $1.id.uuidString) }
        for e in fresh.prefix(maxProfiles - s.stars.profiles.count) {
            s.stars.profiles.append(makeProfile(s, e))
            Cast.yours(&s, e)   // the industry knows stars by name
        }
    }

    /// A star left without going through a bidding war: note where to.
    static func departed(_ s: inout GameState, _ p: StarProfile) {
        if s.stars.offer?.star == p.id { clearOffer(&s) }
        guard !s.stars.alumni.contains(where: { $0.id == p.id }) else { return }
        var lab = "", reason = "Left"
        if let ci = s.cast.firstIndex(where: { $0.employeeID == p.id }) {
            // Still on the books as yours: let go (or gone some other quiet way).
            Cast.move(&s, ci, to: "", role: "Researcher", kind: .free, text: "Left \(s.companyName).")
            s.cast[ci].employeeID = ""
            s.cast[ci].lastLab = "player"
            reason = "Let go"
        } else if let c = s.cast.first(where: { $0.lastLab == "player" && $0.name == p.name }) {
            lab = c.org
            reason = c.org.isEmpty ? "Left to start something of their own" : "Poached"
        }
        addAlumnus(&s, p, role: .researcher, skill: 88, salary: 0, lab: lab, reason: reason, amicable: false)
    }

    static func addAlumnus(_ s: inout GameState, _ p: StarProfile, role: Role, skill: Double, salary: Double, lab: String, reason: String, amicable: Bool) {
        var a = StarAlumnus(id: p.id, name: p.name, role: role, skill: skill, salary: salary, personality: p.personality, specialty: p.specialty,
                            ambition: p.ambition, origin: p.origin, lab: lab, left: s.date, reason: reason)
        a.amicable = amicable
        a.awards = p.awards
        a.story = [StarBeat(date: s.date, text: lab.isEmpty ? "\(reason)." : "\(reason): left for \(Cast.orgName(lab, s)).", tone: -1)] + p.story.prefix(10)
        s.stars.alumni.insert(a, at: 0)
        if s.stars.alumni.count > 24 { s.stars.alumni.removeLast() }
    }

    // MARK: Daily and monthly

    static func daily(_ s: inout GameState) {
        if s.stars.synced != s.employees.count { sync(&s) }
        for i in s.stars.profiles.indices {
            if let until = s.stars.profiles[i].sabbaticalUntil, until <= s.date { backFromSabbatical(&s, i) }
        }
    }

    static func monthly(_ s: inout GameState) {
        sync(&s)
        risingStar(&s)
        cleanupOffer(&s)
        let running = min(3, s.runs.filter { $0.status == .running }.count)
        for i in s.stars.profiles.indices { tick(&s, i, running: running) }
        chemistryMonth(&s)
        burnoutCheck(&s)
        poachCheck(&s)
        boomerangCheck(&s)
        awards(&s)
        halo(&s)
    }

    /// One month in a star's life: wear, wants, renown, their cluster bill and maybe a breakthrough.
    static func tick(_ s: inout GameState, _ i: Int, running: Int) {
        var d = dice(s, "tick|\(s.stars.profiles[i].id)")
        let p = s.stars.profiles[i]
        guard let ei = employeeIndex(s, p.id) else { return }
        s.stars.profiles[i].renown = clamp(p.renown * 0.99 + max(0, s.employees[ei].skill - 85) / 20, 0, 100)
        if p.computeBudget > 0 {
            s.cash -= p.computeBudget
            s.month.costOther += p.computeBudget
        }
        if p.sabbaticalUntil != nil {
            s.stars.profiles[i].fatigue = max(0, p.fatigue - 15)
            return
        }
        // Crunch wears people down: each training run in flight adds to it, quiet months let them recover.
        let launch = s.launches.last.map { GameCalendar.daysBetween($0.date, s.date) <= 45 } ?? false   // launch crunch
        var wear = (2 + 2.5 * Double(running) + (launch ? 3 : 0)) * p.personality.burnRate - (p.mandate ? 2 : 0) - (running == 0 && !launch ? 3 : 0)
        if s.employees[ei].morale > 80 { wear -= 1 }
        s.stars.profiles[i].fatigue = clamp(p.fatigue + wear, 0, 100)
        var m = s.employees[ei].morale
        if s.stars.profiles[i].fatigue >= 75 { m -= 4 }
        let want = wantMet(s, s.stars.profiles[i], s.employees[ei])
        if want {
            m += 3
            s.stars.profiles[i].unmetMonths = 0
        } else {
            s.stars.profiles[i].unmetMonths += 1
            m -= s.stars.profiles[i].unmetMonths > 4 ? 5 : 3
            if s.stars.profiles[i].unmetMonths == 4 {
                beat(&s, i, "Told you they're frustrated: \(Cast.lowerFirst(wantText(s, s.stars.profiles[i]))).", tone: -1)
            }
        }
        s.employees[ei].morale = clamp(m, 0, 100)
        // Signature work: a cluster of their own, a happy mind and good collaborators make breakthroughs likelier.
        let pp = s.stars.profiles[i]
        var chance = 0.05 + (pp.computeBudget > 0 ? 0.04 : 0) + (dreamPartner(s, pp) ? 0.03 : 0)
        chance *= s.employees[ei].morale / 80 * (pp.fatigue >= 75 ? 0.5 : 1) * (pp.mandate ? 1.3 : 1) * s.employees[ei].skill / 92
        if d.chance(chance) { breakthrough(&s, i) }
    }

    static func breakthrough(_ s: inout GameState, _ i: Int) {
        var d = dice(s, "bt|\(s.stars.profiles[i].id)")
        let p = s.stars.profiles[i]
        let result = d.pick(p.specialty.results)
        s.stars.profiles[i].breakthroughs += 1
        let name = p.name
        if p.mandate || p.specialty == .markets {
            // On their own agenda: the work is published under their name, not banked into your roadmap.
            s.stars.profiles[i].renown = min(100, p.renown + 5)
            s.brand = min(100, s.brand + (p.specialty == .markets ? 2 : 1))
            beat(&s, i, "Published \(result).", tone: 1)
            Sim.news(&s, "\(name) publishes \(result)", "Work from \(Cast.possessive(firstName(name))) own agenda. The field takes notice: their renown and your brand rise.", .research, good: true)
            return
        }
        let researchers = max(3, s.staff(.researcher).count)
        let share = clamp(3 / Double(researchers), 0.12, 1)
        var days = d.range(4, 10)
        let head = s.researchQueue.first
        let onRoadmap = head.flatMap { ResearchCatalog.byID[$0]?.category } == p.specialty.category && p.specialty.category != nil
        if onRoadmap { days *= 1.5 }
        let rp = s.rpToday * days * share * 3
        s.researchBanked += rp
        s.stars.profiles[i].renown = min(100, p.renown + 4)
        beat(&s, i, "Cracked \(result).", tone: 1)
        let target = head.flatMap { ResearchCatalog.byID[$0]?.name }
        Sim.news(&s, "\(name) cracks \(result)", "About \(max(1, Int((rp / max(0.01, s.rpToday)).rounded()))) day\(Int((rp / max(0.01, s.rpToday)).rounded()) > 1 ? "s" : "") of the whole lab's research\(target.map { ", banked into \($0)" } ?? "")\(onRoadmap ? " — right in their specialty" : "").", .research, good: true)
    }

    // MARK: Wants

    static func wantMet(_ s: GameState, _ p: StarProfile, _ e: Employee) -> Bool {
        switch p.ambition {
        case .lead: return !p.title.isEmpty
        case .compute: return p.computeBudget > 0
        case .publish: return p.mandate || s.publication == .open
        case .wealth: return e.salary >= People.marketSalary(s, e) * 1.15
        case .mission: return p.mandate || s.safetyScore >= 55
        case .ship:
            let best = s.releasedModels.map(\.c).max() ?? -10
            return best >= Macro.frontier(s.year) - 0.8
        case .recognition:
            return !p.awards.isEmpty || p.renown >= 45 || s.fun.keynotes > 0
                || s.fun.papers.contains { $0.outcome == .best && Double($0.year) >= s.year - 2 }
        }
    }

    static func wantText(_ s: GameState, _ p: StarProfile) -> String {
        switch p.ambition {
        case .lead: return "A title and a team of their own"
        case .compute: return "A cluster of their own (\(Fmt.int(computeGPUs(s))) GPUs, \(Fmt.money(computeBudget(s)))/mo)"
        case .publish: return "Freedom to publish: open science, or a research mandate"
        case .wealth: return "Pay well above market (115%+)"
        case .mission: return "A lab that takes safety seriously: safety score 55+, or a mandate to work on it"
        case .ship: return "To work on a frontier model: release one within reach of the best"
        case .recognition: return "Recognition: a best paper, a keynote, renown 45+ or a prize"
        }
    }

    // MARK: Chemistry

    static func pairBase(_ a: StarPersonality, _ b: StarPersonality) -> Double {
        if a == .steady || b == .steady { return 0.25 }
        if a == b {
            switch a {
            case .showman: return -0.6
            case .maverick: return -0.3
            case .idealist: return 0.3
            case .scholar: return 0.4
            case .builder: return 0.2
            default: return 0
            }
        }
        let pair = Set([a, b])
        let table: [(Set<StarPersonality>, Double)] = [
            ([.mercenary, .idealist], -0.5), ([.builder, .scholar], 0.45), ([.builder, .showman], 0.2), ([.showman, .scholar], -0.2),
            ([.maverick, .showman], -0.4), ([.maverick, .scholar], 0.3), ([.idealist, .scholar], 0.3), ([.idealist, .builder], 0.15),
            ([.mercenary, .showman], 0.1), ([.mercenary, .builder], 0.1), ([.maverick, .idealist], 0.2), ([.maverick, .mercenary], -0.15),
            ([.mercenary, .scholar], -0.25), ([.idealist, .showman], -0.15), ([.maverick, .builder], 0.1),
        ]
        return table.first { $0.0 == pair }?.1 ?? 0
    }

    /// −1 (they can't share a room) … +1 (they finish each other's papers).
    static func chemistry(_ s: GameState, _ a: StarProfile, _ b: StarProfile) -> Double {
        var c = pairBase(a.personality, b.personality)
        c += a.specialty == b.specialty ? -0.1 : 0.15   // complementary fields; the same one means turf
        let together = Double(GameCalendar.daysBetween(max(a.joined, b.joined), s.date)) / 365
        c += min(0.3, 0.1 * max(0, together))
        for id in [a.id, b.id] where s.employees.first(where: { $0.id.uuidString == id })?.talent == .diva { c -= 0.3 }
        return clamp(c, -1, 1)
    }

    static func dreamPartner(_ s: GameState, _ p: StarProfile) -> Bool {
        s.stars.profiles.contains { $0.id != p.id && $0.sabbaticalUntil == nil && chemistry(s, p, $0) >= 0.6 }
    }

    /// Pairs worth showing, strongest feelings first.
    static func pairs(_ s: GameState) -> [(a: StarProfile, b: StarProfile, c: Double)] {
        let ps = s.stars.profiles
        var out: [(StarProfile, StarProfile, Double)] = []
        for i in ps.indices { for j in ps.indices where j > i { out.append((ps[i], ps[j], chemistry(s, ps[i], ps[j]))) } }
        return out.sorted { abs($0.2) > abs($1.2) }
    }

    static func chemistrySum(_ s: GameState, _ p: StarProfile) -> Double {
        clamp(s.stars.profiles.filter { $0.id != p.id }.reduce(0) { $0 + chemistry(s, p, $1) }, -1.5, 1.5)
    }

    static func chemistryMonth(_ s: inout GameState) {
        var d = dice(s, "chem")
        let ps = s.stars.profiles.filter { $0.sabbaticalUntil == nil }
        guard ps.count >= 2 else { return }
        var delta: [String: Double] = [:]
        for i in ps.indices {
            for j in ps.indices where j > i {
                let c = chemistry(s, ps[i], ps[j])
                delta[ps[i].id, default: 0] += c * 2.5
                delta[ps[j].id, default: 0] += c * 2.5
                if c >= 0.6 {
                    // Dream pairs make each other better.
                    for id in [ps[i].id, ps[j].id] { if let e = employeeIndex(s, id) { s.employees[e].skill = min(99, s.employees[e].skill + 0.15) } }
                    if d.chance(0.08), let a = index(s, ps[i].id), let b = index(s, ps[j].id) {
                        beat(&s, a, "Wrote a paper with \(ps[j].name) that both call their best work.", tone: 1)
                        beat(&s, b, "Wrote a paper with \(ps[i].name) that both call their best work.", tone: 1)
                    }
                } else if c <= -0.4, d.chance(0.12), let a = index(s, ps[i].id), let b = index(s, ps[j].id) {
                    beat(&s, a, "Clashed with \(ps[j].name) over who gets credit.", tone: -1)
                    beat(&s, b, "Clashed with \(ps[i].name) over who gets credit.", tone: -1)
                    delta[ps[i].id, default: 0] -= 3
                    delta[ps[j].id, default: 0] -= 3
                    Sim.news(&s, "\(ps[i].name) and \(ps[j].name) clash", "An argument over credit for a paper spilled into an all-hands. Both are less happy this month.", .company, good: false)
                }
            }
        }
        for (id, d) in delta.sorted(by: { $0.key < $1.key }) {
            if let e = employeeIndex(s, id) { s.employees[e].morale = clamp(s.employees[e].morale + clamp(d, -6, 6), 0, 100) }
        }
    }

    // MARK: Burnout and sabbaticals

    static func burnoutCheck(_ s: inout GameState) {
        var d = dice(s, "burn")
        guard !s.decisions.contains(where: { $0.kind == burnoutKind }) else { return }
        for p in s.stars.profiles.sorted(by: { $0.id < $1.id }) where p.sabbaticalUntil == nil && p.fatigue >= 85 && s.stars.offer?.star != p.id {
            guard d.chance(0.4), let e = s.employees.first(where: { $0.id.uuidString == p.id }) else { continue }
            s.stars.burnouts += 1
            if let i = index(s, p.id) { beat(&s, i, "Hit a wall after months of crunch.", tone: -1) }
            Events.addDecision(&s, kind: burnoutKind, title: "\(p.name) is burning out",
                               body: "Months of back-to-back runs have caught up with your \(e.role.title.lowercased()). They're sleeping at the office, snapping at colleagues and their work is slipping.",
                               image: nil,
                               options: [DecisionOption(label: "Three-month sabbatical", detail: "Full pay, no work until \(GameCalendar.addDays(s.date, 90).gameShort). They come back rested, a little sharper, and sometimes with a big idea."),
                                         DecisionOption(label: "Lighten their load", detail: "Fewer meetings and no on-call. Fatigue −25; they keep working."),
                                         DecisionOption(label: "Ask them to push through", detail: "About a 35% chance they quit for a rival; otherwise morale −10 and the fatigue stays.")],
                               ref: p.id)
            return
        }
    }

    static func sabbaticalBlocker(_ s: GameState, _ p: StarProfile) -> String? {
        if p.sabbaticalUntil != nil { return "Already on sabbatical." }
        if s.stars.offer?.star == p.id { return "Not in the middle of a bidding war." }
        if let last = p.lastSabbatical, GameCalendar.daysBetween(last, s.date) < 365 { return "Had one in the past year." }
        return nil
    }

    static func startSabbatical(_ s: inout GameState, _ i: Int) {
        s.stars.profiles[i].sabbaticalUntil = GameCalendar.addDays(s.date, 90)
        s.stars.profiles[i].lastSabbatical = s.date
        beat(&s, i, "Started a three-month sabbatical.")
        Sim.news(&s, "\(s.stars.profiles[i].name) takes a sabbatical", "Back on \(GameCalendar.addDays(s.date, 90).gameShort). Until then they don't count toward research or engineering.", .company)
    }

    static func backFromSabbatical(_ s: inout GameState, _ i: Int) {
        var d = dice(s, "back|\(s.stars.profiles[i].id)")
        s.stars.profiles[i].sabbaticalUntil = nil
        s.stars.profiles[i].fatigue = min(s.stars.profiles[i].fatigue, 10)
        if let e = employeeIndex(s, s.stars.profiles[i].id) {
            s.employees[e].morale = min(100, s.employees[e].morale + 20)
            s.employees[e].skill = min(99, s.employees[e].skill + 1)
        }
        beat(&s, i, "Came back from sabbatical rested.", tone: 1)
        Sim.news(&s, "\(s.stars.profiles[i].name) is back", "Rested after three months away, and back at full speed.", .company, good: true)
        if d.chance(0.4) { breakthrough(&s, i) }
    }

    // MARK: Bidding wars (rivals after your stars)

    static func rivals(_ s: GameState) -> [CompetitorState] {
        s.competitors.filter { $0.alive && s.year >= $0.def.founded.decimal }
    }

    static func labName(_ s: GameState, _ lab: String) -> String {
        s.competitors.first { $0.id == lab }?.def.name ?? lab
    }

    static func labBrand(_ s: GameState, _ lab: String) -> Double { s.competitors.first { $0.id == lab }?.brand ?? 55 }

    static func recentAward(_ s: GameState, _ p: StarProfile) -> Bool {
        p.awards.contains { a in Int(a.split(separator: "|").last ?? "") ?? 0 >= s.date.ym.year - 1 }
    }

    static func poachCheck(_ s: inout GameState) {
        var d = dice(s, "poach")
        guard s.stars.offer == nil, !s.decisions.contains(where: { $0.kind == offerKind || $0.kind == raidKind }), s.decisions.count < 5 else { return }
        if let last = s.stars.lastOffer, GameCalendar.daysBetween(last, s.date) < 90 { return }
        let labs = rivals(s)
        guard !labs.isEmpty else { return }
        let era = s.year >= 2024.5 ? 1.5 : 1.0   // the 2025 talent wars
        for p in s.stars.profiles.sorted(by: { $0.id < $1.id }) where p.sabbaticalUntil == nil && p.lastOffer.map({ GameCalendar.daysBetween($0, s.date) >= 365 }) ?? true {
            guard let e = s.employees.first(where: { $0.id.uuidString == p.id }), e.talent != .loyal else { continue }
            var risk = 0.03 * p.personality.poachability * (1 + p.renown / 60) * clamp(1.6 - e.morale / 100, 0.5, 1.4) * era
            if recentAward(s, p) { risk *= 1.6 }
            if p.unmetMonths >= 3 { risk *= 1.3 }
            guard d.chance(risk) else { continue }
            startOffer(&s, p, e, labs: labs)
            return
        }
    }

    /// People.monthly's poaching roll landed on a star: instead of quietly leaving, they bring you the offer (true = handled).
    static func intercept(_ s: inout GameState, _ e: Employee) -> Bool {
        if s.stars.offer?.star == e.id.uuidString { return true }   // already weighing an offer: they decide that first
        guard s.stars.offer == nil, let p = s.stars.profiles.first(where: { $0.id == e.id.uuidString }), p.sabbaticalUntil == nil,
              !s.decisions.contains(where: { $0.kind == offerKind || $0.kind == raidKind }) else { return false }
        let labs = rivals(s)
        guard !labs.isEmpty else { return false }
        startOffer(&s, p, e, labs: labs)
        return true
    }

    static func startOffer(_ s: inout GameState, _ p: StarProfile, _ e: Employee, labs: [CompetitorState]) {
        var d = dice(s, "offer|\(p.id)")
        // Richer, better-known labs bid more often.
        let weights = labs.map { max(1, $0.brand) * (1 + log10(1 + max(0, $0.valuation) / 1e9)) }
        var u = d.unit() * weights.reduce(0, +)
        var lab = labs[0]
        for (k, w) in weights.enumerated() { u -= w; if u <= 0 { lab = labs[k]; break } }
        // Priced off the market for someone like them, at least a real raise, never more than 2.5× what they make.
        var mult = d.range(1.4, 2.2)
        if s.year >= 2025, p.renown >= 40 { mult *= d.range(1.3, 2) }   // the 2025 packages for the best-known names
        let market = People.marketSalary(s, e) * (s.year > 2024.5 && e.role == .researcher ? 4 : 1)
        let salary = (min(e.salary * 2.5, max(e.salary * d.range(1.25, 1.5), market * mult)) / 1_000).rounded() * 1_000
        let equity = (lab.valuation > 1e9 || d.chance(0.6)) ? (e.salary * d.range(1, 3) / 1_000).rounded() * 1_000 : 0
        let title = p.title.isEmpty && (p.ambition == .lead || p.personality == .showman || d.chance(0.3))
            ? (e.role == .researcher && d.chance(0.5) ? "Chief Scientist" : p.specialty.head) : ""
        let compute = p.computeBudget == 0 && (p.ambition == .compute || p.personality == .builder || d.chance(0.3))
        s.stars.offer = StarOffer(star: p.id, name: p.name, lab: lab.id, salary: salary, equity: equity, title: title, compute: compute, started: s.date)
        if let i = index(s, p.id) { s.stars.profiles[i].lastOffer = s.date }
        s.stars.wars += 1
        if let i = index(s, p.id) { beat(&s, i, "Got an offer from \(lab.def.name): \(Fmt.money(salary))/yr.", tone: -1) }
        postOfferDecision(&s)
    }

    static func offerSummary(_ s: GameState, _ o: StarOffer) -> String {
        var parts = ["\(Fmt.money(o.salary))/yr"]
        if o.equity > 0 { parts.append("\(Fmt.money(o.equity)) in stock") }
        if !o.title.isEmpty { parts.append("the title \(o.title)") }
        if o.compute { parts.append("a \(Fmt.int(computeGPUs(s)))-GPU cluster of their own") }
        return parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + " and " + parts.last!
    }

    /// Clusters and research agendas mean nothing to a seller.
    static func fits(_ p: StarProfile, _ l: StarLever) -> Bool { p.specialty != .markets || (l != .compute && l != .mandate) }

    /// The levers in "make it about the work": the two non-money things this star cares most about and doesn't have yet.
    static func workLevers(_ p: StarProfile) -> [StarLever] {
        let open: [StarLever] = [StarLever.title, .compute, .mandate].filter { fits(p, $0) }.filter { l in
            switch l {
            case .title: p.title.isEmpty
            case .compute: p.computeBudget == 0
            case .mandate: !p.mandate
            default: false
            }
        }
        return Array(open.sorted { (p.personality.weight($0), $0.rawValue) > (p.personality.weight($1), $1.rawValue) }.prefix(2))
    }

    static func levers(_ option: Int, _ p: StarProfile) -> [StarLever] {
        switch option {
        case 0: [.salary]
        case 1: workLevers(p)
        case 2: [.salary, .equity] + workLevers(p)
        default: []
        }
    }

    static func rivalPull(_ s: GameState, _ o: StarOffer, _ p: StarProfile, _ e: Employee) -> Double {
        let w = p.personality.weight
        var x = w(.salary) * 6 * log2(max(1, o.salary / max(1, e.salary)))
        if o.equity > 0 { x += w(.equity) * min(3, 1.5 * o.equity / max(1, e.salary)) }
        if !o.title.isEmpty && p.title.isEmpty { x += w(.title) * 3.5 }
        if o.compute && p.computeBudget == 0 { x += w(.compute) * 3.5 }
        x += (labBrand(s, o.lab) - s.brand) / 15
        x += Double(o.round - 1)   // persistence wears people down
        return x + 3   // a fresh start and a bigger stage tempt anyone
    }

    /// What keeps them with you, plus what a counter-offer with `levers` adds.
    static func hold(_ s: GameState, _ o: StarOffer, _ p: StarProfile, _ e: Employee, _ levers: Set<StarLever>) -> Double {
        let w = p.personality.weight
        var x = (e.morale - 60) / 10
        x += chemistrySum(s, p) * 1.5
        x += min(2, 0.7 * Double(GameCalendar.daysBetween(p.joined, s.date)) / 365)
        x += wantMet(s, p, e) ? 1.5 : -1.5
        if p.personality == .steady { x += 2 }
        if p.boomerang { x += 1.5 }
        if p.fatigue >= 75 { x -= 2 }
        if !p.title.isEmpty { x += w(.title) * 1.5 }
        if p.computeBudget > 0 { x += w(.compute) * 1.5 }
        if p.mandate { x += w(.mandate) * 2 }
        if levers.contains(.salary) { x += w(.salary) * (6 * log2(max(1, o.salary / max(1, e.salary))) + 1) }
        if levers.contains(.equity) { x += w(.equity) * 3 }
        if levers.contains(.title) && p.title.isEmpty { x += w(.title) * 3.5 }
        if levers.contains(.compute) && p.computeBudget == 0 && fits(p, .compute) { x += w(.compute) * 3.5 }
        if levers.contains(.mandate) && !p.mandate && fits(p, .mandate) { x += w(.mandate) * 3.5 }
        return x
    }

    /// The chance they stay if you counter with `levers`.
    static func stayOdds(_ s: GameState, _ levers: Set<StarLever>) -> Double? {
        guard let o = s.stars.offer, !o.outgoing, let p = s.stars.profiles.first(where: { $0.id == o.star }),
              let e = s.employees.first(where: { $0.id.uuidString == o.star }) else { return nil }
        return 1 / (1 + exp(-(hold(s, o, p, e, levers) - rivalPull(s, o, p, e)) / 3))
    }

    static func equityValue(_ s: GameState, _ o: StarOffer?, _ e: Employee) -> Double {
        let v = (o?.equity ?? 0) > 0 ? o!.equity : e.salary * 1.5
        return min(v, max(0, s.valuation) * 0.01)
    }

    static func postOfferDecision(_ s: inout GameState) {
        guard let o = s.stars.offer, let p = s.stars.profiles.first(where: { $0.id == o.star }),
              let e = s.employees.first(where: { $0.id.uuidString == o.star }) else { return }
        let lab = labName(s, o.lab)
        func odds(_ l: [StarLever]) -> String { "About \(Int(((stayOdds(s, Set(l)) ?? 0) * 100).rounded()))% they stay." }
        let work = workLevers(p)
        let workText = work.map { l -> String in
            switch l {
            case .title: return "the title \(titleFor(s, p))"
            case .compute: return "a \(Fmt.int(computeGPUs(s)))-GPU cluster (\(Fmt.money(computeBudget(s)))/mo)"
            default: return "a research mandate"
            }
        }.joined(separator: " and ")
        let raise = max(0, o.salary - e.salary)
        let round = o.round == 1 ? "" : " (round \(o.round) of \(maxRounds))"
        let body = o.round == 1
            ? "\(lab) offers \(p.name) \(offerSummary(s, o)). \(p.personality.title): \(p.personality.blurb) Wants: \(wantText(s, p))."
            : "You countered; \(lab) went higher: \(offerSummary(s, o)). Last chance to keep \(firstName(p.name)) is round \(maxRounds)."
        var options = [DecisionOption(label: "Match the money (+\(Fmt.money(raise))/yr)", detail: "Pay rises to \(Fmt.money(o.salary))/yr. \(odds([.salary]))")]
        options.append(work.isEmpty
            ? DecisionOption(label: "Make it about the work", detail: "They already have everything you could offer here. \(odds([]))")
            : DecisionOption(label: "Make it about the work", detail: "Offer \(workText). \(odds(work))"))
        options.append(DecisionOption(label: "Everything", detail: "Match the money, \(Fmt.money(equityValue(s, o, e))) in stock\(work.isEmpty ? "" : " and \(workText)"). \(odds([.salary, .equity] + work))"))
        options.append(DecisionOption(label: "Talk to them", detail: "No new money: remind them why they joined. \(odds([])) If not, \(lab) may come back with more."))
        options.append(DecisionOption(label: "Let them go gracefully", detail: "A send-off and a reference. Gracious exits come back more often."))
        Events.addDecision(&s, kind: offerKind, title: "\(lab) is trying to hire \(p.name)\(round)", body: body, image: "sf_skyline", options: options, ref: o.star)
        let did = s.decisions.last?.id
        s.stars.offer?.decision = did
    }

    static func clearOffer(_ s: inout GameState) {
        if let id = s.stars.offer?.decision { s.decisions.removeAll { $0.id == id } }
        s.stars.offer = nil
        s.stars.lastOffer = s.date
    }

    static func cleanupOffer(_ s: inout GameState) {
        guard let o = s.stars.offer else { return }
        let decided = o.decision.map { id in !s.decisions.contains { $0.id == id } } ?? true
        let gone = !o.outgoing && employeeIndex(s, o.star) == nil
        if decided || gone {
            if let id = o.decision { s.decisions.removeAll { $0.id == id } }
            s.stars.offer = nil
            s.stars.lastOffer = s.date
        }
    }

    /// Your counter-offer: from the decision's packages or the Stars panel's own mix.
    static func counter(_ s: inout GameState, _ levers: Set<StarLever>) {
        var d = dice(s, "counter|\(s.stars.offer?.star ?? "")|\(s.stars.offer?.round ?? 0)")
        guard let o = s.stars.offer, !o.outgoing, let i = index(s, o.star), let ei = employeeIndex(s, o.star) else { clearOffer(&s); return }
        let odds = stayOdds(s, levers) ?? 0
        let lab = labName(s, o.lab)
        var given: [String] = []
        for l in StarLever.allCases where levers.contains(l) {
            if let g = grant(&s, i, ei, l, offer: o) { given.append(g) }
        }
        if d.chance(odds) {
            s.employees[ei].morale = min(100, s.employees[ei].morale + 10)
            s.stars.profiles[i].renown = min(100, s.stars.profiles[i].renown + 3)
            s.stars.profiles[i].offersFended += 1
            s.stars.warsWon += 1
            beat(&s, i, "Turned down \(lab)\(given.isEmpty ? " after a long talk" : " for \(given.joined(separator: ", "))").", tone: 1)
            Sim.news(&s, "\(o.name) stays", "\(lab) offered \(offerSummary(s, o)). \(firstName(o.name)) is staying\(given.isEmpty ? "" : " — you gave \(given.joined(separator: ", "))").", .company, good: true)
            if let d = o.decision { s.decisions.removeAll { $0.id == d } }
            s.stars.offer = nil
            s.stars.lastOffer = s.date
            return
        }
        if o.round < maxRounds && d.chance(0.2) {
            // They won't go higher, and your star doesn't want to leave without a better offer.
            s.stars.warsWon += 1
            beat(&s, i, "Stayed when \(lab) wouldn't go any higher.", tone: 1)
            Sim.news(&s, "\(lab) gives up on \(o.name)", "\(lab) won't raise its offer again. \(firstName(o.name)) is staying\(given.isEmpty ? "" : ", with \(given.joined(separator: ", "))").", .company, good: true)
            if let d = o.decision { s.decisions.removeAll { $0.id == d } }
            s.stars.offer = nil
            s.stars.lastOffer = s.date
            return
        }
        if o.round < maxRounds {
            // They go higher.
            var next = o
            next.round += 1
            next.salary = (max(o.salary, s.employees[ei].salary) * d.range(1.15, 1.3) / 1_000).rounded() * 1_000
            if next.equity == 0 { next.equity = (s.employees[ei].salary * d.range(1, 2) / 1_000).rounded() * 1_000 }
            if next.title.isEmpty && s.stars.profiles[i].title.isEmpty { next.title = s.employees[ei].role == .researcher ? "Chief Scientist" : s.stars.profiles[i].specialty.head }
            if !next.compute && s.stars.profiles[i].computeBudget == 0 && d.chance(0.5) { next.compute = true }
            next.decision = nil
            if let d = o.decision { s.decisions.removeAll { $0.id == d } }
            s.stars.offer = next
            beat(&s, i, "\(lab) raised its offer to \(Fmt.money(next.salary))/yr.", tone: -1)
            postOfferDecision(&s)
            return
        }
        defect(&s, amicable: false, why: o.round >= maxRounds ? "in three rounds" : "")
    }

    /// The star takes the rival's offer.
    static func defect(_ s: inout GameState, amicable: Bool, why: String) {
        guard let o = s.stars.offer, let i = index(s, o.star), let ei = employeeIndex(s, o.star) else { clearOffer(&s); return }
        let p = s.stars.profiles[i]
        let e = s.employees[ei]
        let lab = labName(s, o.lab)
        if let d = o.decision { s.decisions.removeAll { $0.id == d } }
        s.stars.offer = nil
        s.stars.lastOffer = s.date
        s.stars.defections += 1
        addAlumnus(&s, p, role: e.role, skill: e.skill, salary: e.salary, lab: o.lab, reason: amicable ? "Left on good terms" : (why.isEmpty ? "Lost a bidding war" : "Defected, \(why)"), amicable: amicable)
        // Close collaborators feel it.
        for q in s.stars.profiles where q.id != p.id && chemistry(s, p, q) >= 0.3 {
            if let k = employeeIndex(s, q.id) { s.employees[k].morale = max(0, s.employees[k].morale - 8) }
            if let k = index(s, q.id) { beat(&s, k, "Lost their closest collaborator, \(p.name), to \(lab).", tone: -1) }
        }
        s.employees.remove(at: ei)
        s.stars.profiles.remove(at: i)
        s.stars.synced = s.employees.count
        Cast.leftYou(&s, e, to: o.lab, why: amicable ? "on good terms" : "after a bidding war")
        if let c = s.competitors.firstIndex(where: { $0.id == o.lab }) {
            s.competitors[c].brand = min(100, s.competitors[c].brand + 2)
            if var proj = s.competitors[c].project, proj.procedural {   // they know your recipes
                proj.cAdjust += 0.015
                s.competitors[c].project = proj
            }
        }
        Sim.news(&s, "\(p.name) joins \(lab)", amicable ? "You let \(firstName(p.name)) go with a send-off. The door stays open." : "\(lab) won the bidding war\(why.isEmpty ? "" : " \(why)"): \(offerSummary(s, o)). Their next model gets a little better.",
                 .company, important: true, good: false)
    }

    // MARK: Granting things

    static func titleFor(_ s: GameState, _ p: StarProfile) -> String {
        guard let e = s.employees.first(where: { $0.id.uuidString == p.id }) else { return "Distinguished Scientist" }
        let held = Set(s.stars.profiles.filter { $0.id != p.id }.map(\.title))
        if e.role == .researcher && !held.contains("Chief Scientist") { return "Chief Scientist" }
        let head = p.specialty.head
        if !held.contains(head) { return head }
        return e.role == .researcher || e.role == .safety ? "Distinguished Scientist" : "Distinguished Engineer"
    }

    /// Gives one lever (nil when there was nothing to give). Returns what was given, for the news.
    @discardableResult
    static func grant(_ s: inout GameState, _ i: Int, _ ei: Int, _ lever: StarLever, offer: StarOffer?) -> String? {
        let p = s.stars.profiles[i]
        guard fits(p, lever) else { return nil }
        switch lever {
        case .salary:
            let to = offer.map { max(s.employees[ei].salary, $0.salary) } ?? (s.employees[ei].salary * 1.2 / 1_000).rounded() * 1_000
            guard to > s.employees[ei].salary else { return nil }
            s.employees[ei].salary = to
            return "a raise to \(Fmt.money(to))/yr"
        case .equity:
            let value = equityValue(s, offer, s.employees[ei])
            let pct = clamp(value / max(1e7, s.valuation) * 100, 0.001, 1)
            s.employeePoolShares += s.totalShares * pct / 100
            s.employees[ei].equity += pct
            return "\(Fmt.money(value)) in stock"
        case .title:
            guard p.title.isEmpty else { return nil }
            let t = titleFor(s, p)
            s.stars.profiles[i].title = t
            Cast.promotedAtHome(&s, s.employees[ei], title: String(t.prefix(1)) + t.dropFirst().lowercased())
            return "the title \(t)"
        case .compute:
            guard p.computeBudget == 0 else { return nil }
            s.stars.profiles[i].computeBudget = computeBudget(s)
            return "a \(Fmt.int(computeGPUs(s)))-GPU cluster"
        case .mandate:
            guard !p.mandate else { return nil }
            s.stars.profiles[i].mandate = true
            return "a free research mandate"
        }
    }

    // MARK: Boomerangs

    static func boomerangCheck(_ s: inout GameState) {
        var d = dice(s, "boom")
        guard !s.decisions.contains(where: { $0.kind == boomerangKind }) else { return }
        for k in s.stars.alumni.indices {
            let a = s.stars.alumni[k]
            let months = GameCalendar.daysBetween(a.left, s.date) / 30
            guard !a.asked, !a.returned, !a.lab.isEmpty, (6...36).contains(months) else { continue }
            let rival = s.competitors.first { $0.id == a.lab }
            let weak = rival.map { !$0.alive || $0.brand < s.brand - 10 } ?? false
            var p = 0.025 * (weak ? 3 : 1) * (a.amicable ? 1.6 : 1) * (a.personality == .maverick ? 1.4 : 1)
            if s.brand > labBrand(s, a.lab) { p *= 1.3 }
            guard d.chance(p) else { continue }
            s.stars.alumni[k].asked = true
            let salary = (max(a.salary * 1.1, People.marketSalary(s, role: a.role, skill: a.skill, office: "", star: true, relocated: false)) / 1_000).rounded() * 1_000
            let tech = rivalTech(s, a.lab)
            let where_ = labName(s, a.lab)
            Events.addDecision(&s, kind: boomerangKind, title: "\(a.name) wants to come back",
                               body: "\(months) months at \(where_) was enough. \(firstName(a.name)) misses the team and would return as \(Cast.article(a.role.title)) \(a.role.title.lowercased()) for \(Fmt.money(salary))/yr."
                                + (tech.map { " They know how \(where_) does \(ResearchCatalog.byID[$0]?.name ?? "its secret work") — and could bring it with them." } ?? ""),
                               image: nil,
                               options: [DecisionOption(label: "Welcome them back (\(Fmt.money(salary))/yr)", detail: "Back as a star, a little sharper than when they left\(tech == nil ? "" : ", with \(where_)'s know-how (about a 15% chance \(where_) sues)"). Needs a free desk."),
                                         DecisionOption(label: "Pass", detail: "Wish them luck.")],
                               amount: salary, ref: a.id)
            return
        }
    }

    static func rivalTech(_ s: GameState, _ lab: String) -> String? {
        (s.rivalTech[lab] ?? []).sorted().first { !s.exoticOwned.contains($0) && !s.researched.contains($0) }
    }

    /// A free desk: headquarters first, then a satellite with room ("" = headquarters, nil = none).
    static func freeDesk(_ s: GameState) -> String? {
        if HQ.staffCount(s, office: "") < Economy.office(s, s.officeLevel).capacity { return "" }
        return s.hq.satellites.first { HQ.staffCount(s, office: $0.id.uuidString) < $0.seats }?.id.uuidString
    }

    static func rehire(_ s: inout GameState, _ k: Int, salary: Double) {
        var d = dice(s, "rehire|\(s.stars.alumni[k].id)")
        let a = s.stars.alumni[k]
        guard let desk = freeDesk(s) else {
            Sim.news(&s, "No desk for \(a.name)", "Every office is full, so they stayed at \(labName(s, a.lab)). Add desks on the Team page.", .company, good: false)
            return
        }
        var e = Employee(name: a.name, role: a.role, skill: min(99, a.skill + 2), salary: salary, morale: 85, hired: s.date, star: true)
        e.office = desk
        s.employees.append(e)
        s.stars.alumni[k].returned = true
        s.stars.boomerangs += 1
        var p = StarProfile(id: e.id.uuidString, name: a.name, personality: a.personality, specialty: a.specialty, ambition: a.ambition, origin: a.origin, joined: s.date)
        p.boomerang = true
        p.awards = a.awards
        p.renown = 25
        let months = GameCalendar.daysBetween(a.left, s.date) / 30
        p.story = [StarBeat(date: s.date, text: "Came back after \(months) months at \(labName(s, a.lab)).", tone: 1)] + a.story.prefix(12)
        s.stars.profiles.append(p)
        s.stars.synced = s.employees.count
        // The same person in the industry's eyes, not a namesake.
        if let ci = s.cast.firstIndex(where: { $0.name == a.name && $0.lastLab == "player" && $0.employeeID.isEmpty }) {
            Cast.move(&s, ci, to: "player", role: Cast.jobTitle(a.role), kind: .researcher, text: "Returned to \(s.companyName).")
            s.cast[ci].employeeID = e.id.uuidString
        } else {
            Cast.yours(&s, e)
        }
        var extra = ""
        if let tech = rivalTech(s, a.lab) {
            s.exoticOwned.append(tech)
            extra = " They brought \(ResearchCatalog.byID[tech]?.name ?? "a secret technique") with them: research it on the Research page."
            if d.chance(0.15) {
                let amount = clamp(max(salary * 4, s.valuation * 0.001), 2e6, 1e9)
                s.pendingSuits.append(PendingSuit(lab: a.lab, tech: tech, due: GameCalendar.addDays(s.date, d.int(30, 180)), amount: amount))
            }
        }
        Sim.news(&s, "\(a.name) returns", "A boomerang: back from \(labName(s, a.lab)) after \(months) months.\(extra)", .company, important: true, good: true)
    }

    // MARK: Raids (you after a rival's star)

    /// The best-known researchers at rival labs (not their chief executives).
    static func rivalStars(_ s: GameState) -> [CastMember] {
        let alive = Set(rivals(s).map(\.id))
        return s.cast.filter { $0.active && alive.contains($0.org) && ($0.castKind == .scientist || $0.castKind == .researcher) && $0.employeeID.isEmpty }
            .sorted { ($0.stature, $0.id) > ($1.stature, $1.id) }.prefix(8).map { $0 }
    }

    static func castPersonality(_ m: CastMember) -> StarPersonality {
        for t in m.castTraits {
            switch t {
            case .showman, .hypeProne: return .showman
            case .cautious, .pragmatic: return .steady
            case .contrarian: return .maverick
            case .academic: return .scholar
            case .doomer: return .idealist
            case .accelerationist, .bold: return .builder
            case .secretive: return .mercenary
            }
        }
        return .scholar
    }

    static func castSpecialty(_ m: CastMember) -> StarSpecialty {
        let f = (m.focus + " " + m.role).lowercased()
        if f.contains("reason") || f.contains("rl") { return .reasoning }
        if f.contains("interpret") || f.contains("safety") || f.contains("align") { return .interpretability }
        if f.contains("infra") || f.contains("system") || f.contains("kernel") { return .systems }
        if f.contains("vision") || f.contains("multimodal") || f.contains("video") || f.contains("audio") { return .multimodal }
        if f.contains("agent") { return .agents }
        if f.contains("science") || f.contains("bio") { return .science }
        if f.contains("data") { return .data }
        return .scaling
    }

    static func raidSkill(_ m: CastMember) -> Double { min(98, (84 + m.stature * 14).rounded()) }

    /// What they make where they are now (star pay, and the 2025 talent-war premium).
    static func raidBaseSalary(_ s: GameState, _ m: CastMember) -> Double {
        let base = People.marketSalary(s, role: .researcher, skill: raidSkill(m), office: "", star: true, relocated: false)
        return (base * (s.year > 2024.5 ? 4 : 1.5) / 1_000).rounded() * 1_000
    }

    static func raidBlocker(_ s: GameState) -> String? {
        if s.stars.offer != nil { return "Finish the bidding war in progress first." }
        if let last = s.stars.lastRaid, GameCalendar.daysBetween(last, s.date) < 60 { return "One approach at a time: next from \(GameCalendar.addDays(last, 60).gameShort)." }
        if freeDesk(s) == nil { return "No free desk. Add desks on the Team page." }
        return nil
    }

    static func raidOdds(_ s: GameState, _ m: CastMember, mult: Double, levers: Set<StarLever>, round: Int = 1) -> Double {
        let pers = castPersonality(m)
        let w = pers.weight
        var pull = w(.salary) * 6 * log2(max(1, mult))
        if levers.contains(.equity) { pull += w(.equity) * 3 }
        if levers.contains(.title) { pull += w(.title) * 4 }
        if levers.contains(.compute) { pull += w(.compute) * 4 }
        if levers.contains(.mandate) { pull += w(.mandate) * 4 }
        pull += (s.brand - labBrand(s, m.org)) / 15
        let best = s.releasedModels.map(\.c).max() ?? -10
        if best >= Macro.frontier(s.year) - 0.3 { pull += 1.5 }   // people want to work on the best model
        var stay = 7 + m.stature * 6 + (pers == .steady ? 2 : 0) + (m.castKind == .scientist ? 1.5 : 0)   // stock, a team and a title where they are
        stay -= Double(round - 1) * 1.5
        return 1 / (1 + exp(-(pull - stay) / 3))
    }

    static func raidCost(_ s: GameState, _ m: CastMember, mult: Double, levers: Set<StarLever>) -> (salary: Double, signing: Double, equity: Double) {
        let salary = (raidBaseSalary(s, m) * mult / 1_000).rounded() * 1_000
        let equity = levers.contains(.equity) ? min(salary * 2, max(0, s.valuation) * 0.01) : 0
        return (salary, salary * 0.15, equity)
    }

    static func startRaid(_ s: inout GameState, _ m: CastMember, mult: Double, levers: Set<StarLever>, round: Int = 1) -> String? {
        var d = dice(s, "raid|\(m.id)|\(round)")
        if round == 1, let why = raidBlocker(s) { return why }
        let cost = raidCost(s, m, mult: mult, levers: levers)
        if cost.signing > s.cash { return "The signing bonus is \(Fmt.money(cost.signing)); you have \(Fmt.money(max(0, s.cash)))." }
        s.stars.lastRaid = s.date
        let odds = raidOdds(s, m, mult: mult, levers: levers, round: round)
        let lab = labName(s, m.org)
        if d.chance(odds) { landRaid(&s, m, cost: cost, levers: levers); return nil }
        if round < 2 && d.chance(0.6) {
            // Their lab counters; you can go higher once.
            let higher = mult * 1.3
            let o2 = raidOdds(s, m, mult: higher, levers: levers, round: 2)
            let c2 = raidCost(s, m, mult: higher, levers: levers)
            s.stars.offer = StarOffer(star: m.id, name: m.name, lab: m.org, round: 2, salary: c2.salary, equity: c2.equity, title: levers.contains(.title) ? "yes" : "",
                                      compute: levers.contains(.compute), started: s.date, outgoing: true)
            if levers.contains(.mandate) { s.stars.offer?.title += "|mandate" }
            Events.addDecision(&s, kind: raidKind, title: "\(lab) counters for \(m.name)",
                               body: "\(m.name) was tempted, but \(lab) matched your offer. You can go higher.",
                               image: "sf_skyline",
                               options: [DecisionOption(label: "Raise to \(Fmt.money(c2.salary))/yr", detail: "About \(Int((o2 * 100).rounded()))% they accept. Signing bonus \(Fmt.money(c2.signing))."),
                                         DecisionOption(label: "Walk away", detail: "No hard feelings; \(lab) keeps them.")],
                               amount: c2.signing, ref: m.id)
            let did = s.decisions.last?.id
            s.stars.offer?.decision = did
            return nil
        }
        Sim.news(&s, "\(m.name) turns you down", "\(firstName(m.name)) is staying at \(lab). Word gets around that you're hiring.", .company, good: false)
        return nil
    }

    static func landRaid(_ s: inout GameState, _ m: CastMember, cost: (salary: Double, signing: Double, equity: Double), levers: Set<StarLever>) {
        guard let desk = freeDesk(s), let ci = s.cast.firstIndex(where: { $0.id == m.id }) else { return }
        let lab = labName(s, m.org)
        s.cash -= cost.signing
        s.month.costPayroll += cost.signing
        var e = Employee(name: m.name, role: .researcher, skill: raidSkill(m), salary: cost.salary, morale: 85, hired: s.date, star: true)
        e.office = desk
        if cost.equity > 0 {
            let pct = clamp(cost.equity / max(1e7, s.valuation) * 100, 0.001, 1)
            s.employeePoolShares += s.totalShares * pct / 100
            e.equity = pct
        }
        s.employees.append(e)
        var p = StarProfile(id: e.id.uuidString, name: m.name, personality: castPersonality(m), specialty: castSpecialty(m),
                            ambition: ambition(for: castPersonality(m), roll(s, "amb|\(m.id)")), origin: m.blurb.isEmpty ? "Was one of \(Cast.possessive(lab)) best-known researchers." : m.blurb, joined: s.date)
        p.renown = clamp(25 + m.stature * 50, 20, 80)
        p.story = [StarBeat(date: s.date, text: "Joined from \(lab) after you outbid them for \(Fmt.money(cost.salary))/yr.", tone: 1)]
        s.stars.profiles.append(p)
        s.stars.synced = s.employees.count
        s.stars.raidsWon += 1
        let pi = s.stars.profiles.count - 1
        let ei = s.employees.count - 1
        for l in [StarLever.title, .compute, .mandate] where levers.contains(l) { grant(&s, pi, ei, l, offer: nil) }
        s.cast[ci].lastLab = m.org
        Cast.move(&s, ci, to: "player", role: Cast.jobTitle(.researcher), kind: .researcher, text: "Left \(lab) for \(s.companyName).")
        s.cast[ci].employeeID = e.id.uuidString
        if let c = s.competitors.firstIndex(where: { $0.id == m.org }) {
            s.competitors[c].brand = max(0, s.competitors[c].brand - 1)
            if var proj = s.competitors[c].project, proj.procedural {
                proj.cAdjust -= 0.01
                s.competitors[c].project = proj
            }
        }
        Sim.news(&s, "\(m.name) leaves \(lab) for \(s.companyName)", "You won \(Cast.possessive(firstName(m.name))) signature: \(Fmt.money(cost.salary))/yr and a \(Fmt.money(cost.signing)) signing bonus. \(lab) loses one of its best-known researchers.",
                 .company, important: true, good: true)
    }

    // MARK: Prizes

    static func awards(_ s: inout GameState) {
        let month = s.date.ym.month
        let year = s.date.ym.year
        if month == 3 { lovelaceAward(&s, year) }
        if month == 10 { stockholmPrize(&s, year) }
    }

    static func awardScore(_ s: GameState, _ p: StarProfile) -> Double {
        guard let e = s.employees.first(where: { $0.id.uuidString == p.id }) else { return 0 }
        return p.renown + (e.skill - 80) + 5 * Double(p.breakthroughs) + 3 * Double(p.offersFended)
    }

    /// Your best candidate for a prize and the chance they win it this year.
    static func prizeOutlook(_ s: GameState, _ prize: String) -> (StarProfile, Double)? {
        let eligible = s.stars.profiles.filter { p in
            GameCalendar.daysBetween(p.joined, s.date) >= 365 && !p.awards.contains { $0.hasPrefix(prize) }
                && (prize == lovelace || p.specialty == .science || s.science.discoveries.count > 0)
        }
        guard let best = eligible.max(by: { (awardScore(s, $0), $0.id) < (awardScore(s, $1), $1.id) }) else { return nil }
        let score = awardScore(s, best)
        if prize == lovelace { return (best, score < 70 || best.renown < 60 ? 0 : clamp((score - 60) / 200, 0, 0.35)) }   // decades of work, usually
        guard s.year >= 2024 else { return (best, 0) }   // AI first wins one in 2024
        return (best, clamp(0.08 + 0.08 * Double(s.science.discoveries.count) + best.renown / 400 + (best.specialty == .science ? 0.08 : 0), 0, 0.5))
    }

    static func lovelaceAward(_ s: inout GameState, _ year: Int) {
        var d = dice(s, "lovelace|\(year)")
        guard !s.stars.awards.contains(where: { $0.prize == lovelace && $0.year == year }) else { return }
        if let (p, odds) = prizeOutlook(s, lovelace), odds > 0, d.chance(odds) {
            win(&s, p, prize: lovelace, year: year, citation: "for \(d.pick(p.specialty.results)) and the ideas behind it", brand: 5)
            return
        }
        // Someone else's year: the field's best-known researcher who hasn't won it.
        let won = Set(s.stars.awards.filter { $0.prize == lovelace }.map(\.winner))
        let field = s.cast.filter { $0.active && !won.contains($0.name) && $0.org != "player" && [.scientist, .academic, .researcher].contains($0.castKind) && $0.stature >= 0.35 }
            .sorted { ($0.stature, $0.id) > ($1.stature, $1.id) }.prefix(6)
        guard !field.isEmpty else { return }
        let m = d.pick(Array(field))
        let focus = castSpecialty(m).field
        s.stars.awards.insert(StarAward(prize: lovelace, year: year, winner: m.name, org: m.org, citation: "for foundational work on \(focus)"), at: 0)
        Sim.news(&s, "\(m.name) wins the \(year) \(lovelace)", "Computing's highest honour, with a $1M purse, goes to \(m.name) (\(Cast.orgName(m.org, s, short: true).isEmpty ? "independent" : Cast.orgName(m.org, s, short: true))) for foundational work on \(focus).", .research)
    }

    static func stockholmPrize(_ s: inout GameState, _ year: Int) {
        var d = dice(s, "stockholm|\(year)")
        guard s.year >= 2024, !s.stars.awards.contains(where: { $0.prize == stockholm && $0.year == year }) else { return }
        if let (p, odds) = prizeOutlook(s, stockholm), odds > 0, d.chance(odds) {
            let sci = StarSpecialty.science.results
            win(&s, p, prize: stockholm, year: year, citation: "for \(s.science.discoveries.last?.title.lowercased() ?? d.pick(sci))", brand: 8)
            return
        }
        // Most years the science prize goes to science without AI in it (no news); now and then to an AI researcher.
        guard d.chance(0.25) else { return }
        let won = Set(s.stars.awards.filter { $0.prize == stockholm }.map(\.winner))
        let field = s.cast.filter { $0.active && !won.contains($0.name) && $0.org != "player" && [.scientist, .academic, .leader].contains($0.castKind) && $0.stature >= 0.5 }
            .sorted { ($0.stature, $0.id) > ($1.stature, $1.id) }.prefix(4)
        guard !field.isEmpty else { return }
        let m = d.pick(Array(field))
        let cite = d.pick(StarSpecialty.science.results)
        s.stars.awards.insert(StarAward(prize: stockholm, year: year, winner: m.name, org: m.org, citation: "for \(cite)"), at: 0)
        Sim.news(&s, "\(m.name) shares the \(year) \(stockholm)", "The Stockholm committee honours AI work again: \(cite). 11 million kronor and a lot of attention for \(Cast.orgName(m.org, s, short: true).isEmpty ? "the field" : Cast.orgName(m.org, s, short: true)).", .research)
    }

    static func win(_ s: inout GameState, _ p: StarProfile, prize: String, year: Int, citation: String, brand: Double) {
        guard let i = index(s, p.id), let ei = employeeIndex(s, p.id) else { return }
        let id = "\(prize)|\(year)"
        var a = StarAward(prize: prize, year: year, winner: p.name, org: "player", citation: citation)
        a.mine = true
        s.stars.awards.insert(a, at: 0)
        if s.stars.awards.count > 30 { s.stars.awards.removeLast() }
        s.stars.profiles[i].awards.append(id)
        s.stars.profiles[i].renown = min(100, p.renown + 25)
        s.employees[ei].morale = 100
        s.brand = min(100, s.brand + brand)
        s.stars.haloUntil = GameCalendar.addMonths(s.date, 12)
        beat(&s, i, "Won the \(year) \(prize) \(citation).", tone: 1)
        if let ci = s.cast.firstIndex(where: { $0.employeeID == p.id }) { s.cast[ci].stature = max(s.cast[ci].stature, 0.7) }
        // Recruiting: the best PhDs want to work with a laureate.
        for _ in 0..<2 {
            var c = People.makeCandidate(&s, role: .researcher, star: true)
            c.bio += " Wants to work with \(p.name)."
            s.candidates.insert(c, at: 0)
        }
        Sim.news(&s, "\(p.name) wins the \(year) \(prize)", "\(prize == lovelace ? "Computing's highest honour" : "The Stockholm Prize, science's highest honour,") goes to your \(Cast.lowerFirst(p.title.isEmpty ? "star" : p.title)) \(citation). Brand +\(Int(brand)); two star researchers have already asked to join, and more will for a year.",
                 .research, important: true, good: true)
        Alerts.raise(&s, .milestone, key: id, title: "\(p.name) wins the \(prize)", body: String(citation.prefix(1)).uppercased() + String(citation.dropFirst()) + ".", screen: .team, celebrate: true, cooldown: 0)
    }

    /// A laureate on staff keeps bringing stars to the door for a year.
    static func halo(_ s: inout GameState) {
        var d = dice(s, "halo")
        guard let until = s.stars.haloUntil, until > s.date, d.chance(0.35) else { return }
        var c = People.makeCandidate(&s, role: d.chance(0.7) ? .researcher : .mlEngineer, star: true)
        c.bio += " Wants to work with your prize-winning team."
        s.candidates.insert(c, at: 0)
    }

    /// Veterans who keep delivering become stars in their own right.
    static func risingStar(_ s: inout GameState) {
        var d = dice(s, "rising")
        guard let i = s.employees.indices.first(where: { k in
            let e = s.employees[k]
            return !e.star && e.skill >= 82 && e.morale >= 60 && GameCalendar.daysBetween(e.hired, s.date) >= 730
        }), d.chance(0.03) else { return }
        s.employees[i].star = true
        Sim.news(&s, "\(s.employees[i].name) is becoming a star", "Two years of strong work and a few talks people still mention: rivals are starting to call. See them on the Team page.", .company, good: true)
    }

    // MARK: Decisions

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        var dc = dice(s, "resolve|\(d.kind)|\(d.ref)")
        switch d.kind {
        case offerKind:
            guard let o = s.stars.offer, o.star == d.ref, !o.outgoing, let p = s.stars.profiles.first(where: { $0.id == o.star }) else { return }
            s.stars.offer?.decision = nil   // it's already off the list
            if option == 4 { defect(&s, amicable: true, why: "") } else { counter(&s, Set(levers(option, p))) }
        case burnoutKind:
            guard let i = index(s, d.ref), let ei = employeeIndex(s, d.ref) else { return }
            switch option {
            case 0: startSabbatical(&s, i)
            case 1:
                s.stars.profiles[i].fatigue = max(0, s.stars.profiles[i].fatigue - 25)
                s.employees[ei].morale = min(100, s.employees[ei].morale + 5)
                beat(&s, i, "Got a lighter load to recover.")
            default:
                if dc.chance(0.35), let lab = rivals(s).sorted(by: { $0.brand > $1.brand }).first {
                    // They walk into the first lab that calls; any other war in progress carries on.
                    let pending = s.stars.offer?.star == d.ref ? nil : s.stars.offer
                    let lastOffer = s.stars.lastOffer
                    s.stars.offer = StarOffer(star: d.ref, name: s.stars.profiles[i].name, lab: lab.id, salary: s.employees[ei].salary * 1.3, equity: 0, title: "", compute: false, started: s.date)
                    defect(&s, amicable: false, why: "burned out and fed up")
                    if let pending {
                        s.stars.offer = pending
                        s.stars.lastOffer = lastOffer
                    }
                } else {
                    s.employees[ei].morale = max(0, s.employees[ei].morale - 10)
                    beat(&s, i, "Was asked to push through the burnout.", tone: -1)
                }
            }
        case boomerangKind:
            guard option == 0, let k = s.stars.alumni.firstIndex(where: { $0.id == d.ref }) else { return }
            rehire(&s, k, salary: d.amount)
        case raidKind:
            guard let o = s.stars.offer, o.outgoing, o.star == d.ref else { return }
            s.stars.offer = nil
            guard option == 0, let m = s.cast.first(where: { $0.id == d.ref && $0.active }) else {
                Sim.news(&s, "You walk away from \(o.name)", "\(labName(s, o.lab)) keeps them.", .company)
                return
            }
            var lv: Set<StarLever> = [.salary]
            if o.equity > 0 { lv.insert(.equity) }
            if o.title.hasPrefix("yes") { lv.insert(.title) }
            if o.compute { lv.insert(.compute) }
            if o.title.contains("mandate") { lv.insert(.mandate) }
            let mult = o.salary / max(1, raidBaseSalary(s, m))
            if let why = startRaid(&s, m, mult: mult, levers: lv, round: 2) {
                Sim.news(&s, "Your offer to \(o.name) fell through", why, .company, good: false)
            }
        default:
            break
        }
    }

    // MARK: Harness

    /// `REPLAY_STARS=1`: what the Stars panel shows, once a month, and the day's star news.
    static func replayLines(_ s: GameState) {
        for n in s.news.prefix(8) where n.date == s.date {
            let names = s.stars.profiles.map(\.name) + s.stars.alumni.map(\.name) + [lovelace, stockholm]
            if names.contains(where: { n.title.contains($0) }) || n.title.contains("star") { print("    STARS news: \(n.title) — \(n.body)") }
        }
        for d in s.decisions where d.date == s.date && [offerKind, burnoutKind, boomerangKind, raidKind].contains(d.kind) {
            print("    STARS decision: \(d.title) — \(d.body)")
            for (k, o) in d.options.enumerated() { print("      [\(k)] \(o.label): \(o.detail)") }
        }
        guard s.date.ym.month != 0, GameCalendar.components(s.date).day == 1 else { return }
        print("    STARS \(s.stars.profiles.count) stars · wars \(s.stars.wars) (won \(s.stars.warsWon)) · defections \(s.stars.defections) · boomerangs \(s.stars.boomerangs) · raids won \(s.stars.raidsWon) · burnouts \(s.stars.burnouts) · awards \(s.stars.awards.filter(\.mine).count)/\(s.stars.awards.count) · halo \(s.stars.haloUntil.map { $0 > s.date ? "until \($0.gameShort)" : "no" } ?? "no")")
        for p in s.stars.profiles {
            guard let e = s.employees.first(where: { $0.id.uuidString == p.id }) else { continue }
            print("      \(p.name) [\(p.personality.title), \(p.specialty.title), wants \(p.ambition.title)\(wantMet(s, p, e) ? " ✓" : " ✗")] skill \(Int(e.skill)) morale \(Int(e.morale)) fatigue \(Int(p.fatigue)) renown \(Int(p.renown))\(p.title.isEmpty ? "" : " · \(p.title)")\(p.computeBudget > 0 ? " · cluster \(Fmt.money(p.computeBudget))/mo" : "")\(p.mandate ? " · mandate" : "")\(p.sabbaticalUntil.map { " · sabbatical to \($0.gameShort)" } ?? "") · \(p.story.first?.text ?? "")")
        }
        if s.stars.profiles.count > 1 {
            let top = pairs(s).prefix(2).map { "\(firstName($0.a.name))+\(firstName($0.b.name)) \(Fmt.trim($0.c, 2))" }.joined(separator: ", ")
            print("      chemistry: \(top)")
        }
    }

    nonisolated(unsafe) static var replayHire = false
    nonisolated(unsafe) static var replayRaid = false
    nonisolated(unsafe) static var replayAnswer = -1
    nonisolated(unsafe) static var replayTired = false

    /// Replay args: `stars:hire` hires the best star candidate whenever one is on the market; `stars:raid` makes an offer to
    /// the best-known rival researcher once a quarter (2× their pay, title and cluster).
    static func replayDay(_ s: inout GameState) {
        if replayAnswer >= 0 {
            for d in s.decisions where [offerKind, burnoutKind, boomerangKind, raidKind].contains(d.kind) {
                let o = min(replayAnswer, d.options.count - 1)
                print("    STARS answer \"\(d.options[o].label)\" to: \(d.title)")
                s.resolveDecision(d.id, option: o)
            }
        }
        if replayTired {
            replayTired = false
            sync(&s)
            for i in s.stars.profiles.indices { s.stars.profiles[i].fatigue = 90 }
            print("    STARS test: every star's fatigue set to 90")
        }
        if replayHire, let c = s.candidates.filter({ $0.star && $0.salary * 0.15 < s.cash }).max(by: { ($0.skill, $0.id.uuidString) < ($1.skill, $1.id.uuidString) }) {
            let r = s.hire(c.id)
            print("    STARS hire \(c.name) (skill \(Int(c.skill)), \(Fmt.money(c.salary))/yr): \(r ?? "ok")")
        }
        if replayRaid, raidBlocker(s) == nil, s.stars.lastRaid.map({ GameCalendar.daysBetween($0, s.date) >= 90 }) ?? true, s.cash > 0, let m = rivalStars(s).first {
            let lv: Set<StarLever> = [.salary, .title, .compute]
            print("    STARS raid \(m.name) at \(labName(s, m.org)) (stature \(Fmt.trim(m.stature, 2))): odds \(Fmt.pct(raidOdds(s, m, mult: 2, levers: lv), decimals: 0)) cost \(Fmt.money(raidCost(s, m, mult: 2, levers: lv).salary))/yr")
            if let why = startRaid(&s, m, mult: 2, levers: lv) { print("      → \(why)") }
        }
    }
}

// MARK: - Player actions

extension GameState {
    /// Give a star one thing now (outside a bidding war).
    mutating func starGrant(_ id: String, _ lever: StarLever) -> String? {
        guard let i = Stars.index(self, id), let ei = Stars.employeeIndex(self, id) else { return "They're no longer here." }
        if lever == .equity, Stars.equityValue(self, nil, employees[ei]) <= 0 { return "Your company has no valuation to grant stock against." }
        guard let what = Stars.grant(&self, i, ei, lever, offer: nil) else { return "They already have that." }
        employees[ei].morale = min(100, employees[ei].morale + 6 * stars.profiles[i].personality.weight(lever))
        Stars.beat(&self, i, "You gave them \(what).", tone: 1)
        return nil
    }

    /// Take back a cluster or a mandate (it stings).
    mutating func starRevoke(_ id: String, _ lever: StarLever) {
        guard let i = Stars.index(self, id), let ei = Stars.employeeIndex(self, id) else { return }
        switch lever {
        case .compute where stars.profiles[i].computeBudget > 0: stars.profiles[i].computeBudget = 0
        case .mandate where stars.profiles[i].mandate: stars.profiles[i].mandate = false
        default: return
        }
        employees[ei].morale = max(0, employees[ei].morale - 8 * stars.profiles[i].personality.weight(lever))
        Stars.beat(&self, i, "Lost their \(lever.title.lowercased()).", tone: -1)
    }

    mutating func starSabbatical(_ id: String) -> String? {
        guard let i = Stars.index(self, id) else { return "They're no longer here." }
        if let why = Stars.sabbaticalBlocker(self, stars.profiles[i]) { return why }
        Stars.startSabbatical(&self, i)
        return nil
    }

    /// Counter the rival's offer with your own mix of levers (the Stars panel's builder).
    mutating func starCounter(_ levers: Set<StarLever>) -> String? {
        guard let o = stars.offer, !o.outgoing else { return "No bidding war in progress." }
        if levers.contains(.equity), let e = employees.first(where: { $0.id.uuidString == o.star }), Stars.equityValue(self, o, e) > 0, valuation <= 0 { return "No valuation to grant stock against." }
        if let d = o.decision { decisions.removeAll { $0.id == d } }
        stars.offer?.decision = nil
        Stars.counter(&self, levers)
        return nil
    }

    mutating func starLetGo() -> String? {
        guard let o = stars.offer, !o.outgoing else { return "No bidding war in progress." }
        if let d = o.decision { decisions.removeAll { $0.id == d } }
        stars.offer?.decision = nil
        Stars.defect(&self, amicable: true, why: "")
        return nil
    }

    mutating func starRaid(_ castID: String, mult: Double, levers: Set<StarLever>) -> String? {
        guard let m = cast.first(where: { $0.id == castID && $0.active }) else { return "They've moved on." }
        return Stars.startRaid(&self, m, mult: mult, levers: levers)
    }
}
