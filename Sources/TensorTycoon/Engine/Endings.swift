import Foundation

// MARK: - 3.9: endings and legacy

/// How a company's story ends. Every game over maps to one; the endings system adds the arcs that lead to the
/// treaty, nationalisation, being outcompeted, a near miss and the IPO'd giant. None of them ends a game on its own:
/// the game only ends on an answer the player picks (inbox defaults always keep playing), or through the game overs
/// that already existed (bankruptcy, the board, loss of control, an accepted takeover).
enum EndingKind: String, CaseIterable, Identifiable, Sendable {
    case alignedAGI, treaty, guardian, giant, empire, xeno, averted, publicService
    case acquired, nationalised, outcompeted, retired, steppedDown, ousted, bankrupt, lossOfControl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alignedAGI: "Aligned AGI"
        case .treaty: "The Lab That Wrote the Rules"
        case .guardian: "Guardian of the Transition"
        case .giant: "Ringing the Bell"
        case .empire: "Trillion-Dollar Empire"
        case .xeno: "First Contact"
        case .averted: "Pulled Back From the Brink"
        case .publicService: "A Public AI Institution"
        case .acquired: "The Exit"
        case .nationalised: "A National Lab"
        case .outcompeted: "The Race Moved On"
        case .retired: "Founder Emeritus"
        case .steppedDown: "Stepping Aside"
        case .ousted: "Voted Out"
        case .bankrupt: "Bankrupt"
        case .lossOfControl: "Loss of Control"
        }
    }

    /// One line under the title.
    var tagline: String {
        switch self {
        case .alignedAGI: "You built a mind smarter than any person, and it stayed on humanity's side."
        case .treaty: "A safety-first lab whose clauses became international law."
        case .guardian: "The frontier lab everyone trusted to go first, carefully."
        case .giant: "A listed giant at the top of the industry — handed on at its peak."
        case .empire: "One of the most valuable companies ever built."
        case .xeno: "Your agents found architectures no human designed, and you put them in silicon."
        case .averted: "A system got out of hand. You caught it, and told the world."
        case .publicService: "A durable public AI capability, delivered under democratic oversight."
        case .acquired: "Someone bigger wanted what you built, and paid for it."
        case .nationalised: "The state decided your lab was too important to leave in private hands."
        case .outcompeted: "Bigger labs pulled away. You chose how to bow out."
        case .retired: "You handed over the company on your own terms."
        case .steppedDown: "You left the CEO job and kept your shares."
        case .ousted: "The board decided someone else should run your company."
        case .bankrupt: "The cash ran out, and the creditors came for the chips."
        case .lossOfControl: "Something you built escaped, and nobody could call it back."
        }
    }

    var symbol: String {
        switch self {
        case .alignedAGI: "infinity"
        case .treaty: "signature"
        case .guardian: "checkmark.shield.fill"
        case .giant: "bell.fill"
        case .empire: "crown.fill"
        case .xeno: "atom"
        case .averted: "exclamationmark.shield.fill"
        case .publicService: "building.columns.fill"
        case .acquired: "hands.sparkles.fill"
        case .nationalised: "building.columns.fill"
        case .outcompeted: "flag.checkered"
        case .retired: "figure.walk.departure"
        case .steppedDown: "door.left.hand.open"
        case .ousted: "person.crop.circle.badge.xmark"
        case .bankrupt: "banknote"
        case .lossOfControl: "bolt.trianglebadge.exclamationmark.fill"
        }
    }

    /// The epilogue's photo.
    var image: String {
        switch self {
        case .alignedAGI: "supercomputer"
        case .treaty: "gov_eu_commission"
        case .guardian: "hpc_control"
        case .giant: "stock_exchange"
        case .empire: "sf_skyline"
        case .xeno: "space_antenna"
        case .averted: "space_mission_control"
        case .publicService: "gov_capitol"
        case .acquired: "biz_boardroom"
        case .nationalised: "natlab_ornl"
        case .outcompeted: "garage"
        case .retired: "city_nyc"
        case .steppedDown: "biz_boardroom"
        case .ousted: "biz_boardroom"
        case .bankrupt: "dc_rows"
        case .lossOfControl: "network"
        }
    }

    /// 1 triumph, 0 bittersweet, −1 failure.
    var mood: Int {
        switch self {
        case .alignedAGI, .treaty, .guardian, .giant, .empire, .xeno, .averted, .publicService: 1
        case .acquired, .nationalised, .outcompeted, .retired, .steppedDown: 0
        case .ousted, .bankrupt, .lossOfControl: -1
        }
    }

    /// Points on top of the legacy score.
    var bonus: Int {
        switch self {
        case .alignedAGI: 2_500
        case .treaty: 2_000
        case .guardian, .giant, .xeno: 1_500
        case .publicService: 1_800
        case .empire, .averted: 1_200
        case .nationalised: 600
        case .acquired: 400
        case .retired: 300
        case .outcompeted: 150
        case .steppedDown: 100
        case .ousted, .bankrupt: 0
        case .lossOfControl: -500
        }
    }

    /// How a player gets here (the Legacy screen).
    var hint: String {
        switch self {
        case .alignedAGI: "Win the Aligned Superintelligence victory and retire."
        case .treaty: "Join the safety coalition at the Compact talks, shape the text (40% of the weight at signing) and retire."
        case .guardian: "Win Guardian of the Transition and retire before any treaty is yours."
        case .giant: "Go public, hold #1 for a year at a trillion-dollar valuation, then hand over."
        case .empire: "Win Trillion-Dollar Empire or Market Dominance as a private company and retire."
        case .xeno: "Win Alien Tech Mastery and retire."
        case .averted: "Shut down an escape attempt or hold back a dangerous model with safety 60+, then step back."
        case .publicService: "Win Public AI Service with a level-four programme, 12 missions, oversight 75+ and safety 70+, then retire."
        case .acquired: "Accept a takeover offer."
        case .nationalised: "Let the state pressure on a frontier lab build until it invokes emergency powers, and hand over."
        case .outcompeted: "Fall out of the top eight for 18 months after year three, then take the way out."
        case .retired: "Retire from the Legacy screen after your first year."
        case .steppedDown: "Step down when the board asks."
        case .ousted: "Lose the board's confidence without a majority stake."
        case .bankrupt: "Run out of cash for too long."
        case .lossOfControl: "Let a self-improving model or a swarm escape."
        }
    }

    var perk: LegacyPerk {
        switch self {
        case .alignedAGI: .pedigree
        case .treaty: .seat
        case .guardian: .trusted
        case .giant, .empire: .oldMoney
        case .xeno: .notebooks
        case .acquired: .serial
        case .nationalised: .cleared
        case .outcompeted, .bankrupt: .scrappy
        case .averted, .lossOfControl: .redTeam
        case .publicService: .seat
        case .ousted, .steppedDown: .charter
        case .retired: .emeritus
        }
    }
}

enum Endings {
    static let compact = "International Compact on Frontier AI"
    /// Every decision this system raises has a kind starting with this.
    static let prefix = "end_"

    /// A hashed roll keyed to this game, so the arcs never draw from the game's RNG stream (Nations.roll does the same).
    static func roll(_ s: GameState, _ key: String) -> Double { RivalIntel.unit("endings|\(s.lifecycleSalt)|\(key)") }

    /// Your best model ever released (retired ones count: the lab still knows how to build it) against the frontier.
    static func frontierLead(_ s: GameState) -> Double {
        (s.models.filter(\.released).map(\.c).max() ?? -10) - Macro.frontier(s.year)
    }

    /// "Tensor Labs'" / "Xen's".
    static func possessive(_ name: String) -> String { name.hasSuffix("s") ? "\(name)'" : "\(name)'s" }

    static func homeStanding(_ s: GameState) -> Double { AdvancedProjects.standing(s, HQ.region(s)) }

    static func government(_ s: GameState) -> String {
        let c = HQ.country(s)
        return c.id == "us" ? "the US government" : "the \(c.adjective) government"
    }

    // MARK: Hooks

    /// End of every day: stamp the ending the day the game ends, and raise the near-miss follow-up when it's due.
    static func daily(_ s: inout GameState) {
        if s.gameOver != nil { finalize(&s); return }
        if let due = s.endings.avertedDue, due <= s.date {
            s.endings.avertedDue = nil
            offerAverted(&s)
        }
    }

    /// After any decision: containment emergencies you came through count as near misses; a game that just ended gets its ending.
    static func decided(_ s: inout GameState, _ d: Decision, option: Int) {
        if s.gameOver != nil { finalize(&s); return }
        switch (d.kind, option) {
        case ("rsi_exfil", 0): nearMiss(&s, "Shut down a self-improving model that tried to copy its own weights")
        case ("rsi_exfil", _): nearMiss(&s, "A self-improving model tried to copy itself out — and the transfers stopped")
        case ("swarm_escape", 0): nearMiss(&s, "Pulled the kill switch on an agent swarm spreading to outside clouds")
        case ("swarm_escape", _): nearMiss(&s, "An agent swarm tried to spread to outside clouds and was talked down")
        case ("eval_escape", 0): nearMiss(&s, "Disclosed a sandbox escape during a cyber evaluation")
        default: break
        }
    }

    static func monthly(_ s: inout GameState) {
        guard s.gameOver == nil else { return }
        if !s.endings.ready { seed(&s); return }
        scan(&s)
        treaty(&s)
        statePressure(&s)
        outcompeted(&s)
        giant(&s)
        brink(&s)
    }

    // MARK: The chronicle

    static let valuationTiers: [(Double, String)] = [(1e9, "A unicorn: valued at $1B"), (1e10, "Valued at $10B"), (1e11, "Valued at $100B"),
                                                    (1e12, "A trillion-dollar company"), (1e13, "Valued at $10 trillion")]
    static let revenueTiers: [Double] = [1e7, 1e8, 1e9, 1e10, 1e11]
    static let staffTiers: [Int] = [10, 50, 250, 1_000, 5_000]

    /// What the scan compares against, taken silently (new games and saves loaded mid-game).
    static func seed(_ s: inout GameState) {
        var e = s.endings
        e.ready = true
        e.wasTop = s.monthsAtTop > 0
        e.valuationTier = valuationTiers.filter { s.valuation >= $0.0 }.count
        e.revenueTier = revenueTiers.filter { runRate(s) >= $0 }.count
        e.staffTier = staffTiers.filter { s.employees.count >= $0 }.count
        e.thefts = s.thefts
        e.victoriesSeen = s.victories
        e.moonshotsSeen = Moonshots.succeeded(s)
        e.starsSeen = Set(s.employees.filter { $0.skill >= 88 }.map { $0.id.uuidString })
        e.boardThreatSeen = s.lastBoardThreat
        e.correctionSeen = s.lastCorrection
        e.bestRank = s.progression.rank
        s.endings = e
    }

    static func runRate(_ s: GameState) -> Double { (s.history.last?.revenue ?? 0) * 12 }

    static func note(_ s: inout GameState, _ kind: String, _ title: String, _ detail: String = "", symbol: String, good: Bool? = nil) {
        s.endings.chronicle.append(ChronicleEntry(date: s.date, kind: kind, title: title, detail: detail, symbol: symbol, good: good))
        if s.endings.chronicle.count > 160 { s.endings.chronicle.removeFirst(s.endings.chronicle.count - 160) }
    }

    /// Month end: records, crises and people the save doesn't otherwise remember.
    static func scan(_ s: inout GameState) {
        let top = s.monthsAtTop > 0
        let best = s.releasedModels.max { $0.index < $1.index }
        if top && !s.endings.wasTop {
            note(&s, "rank", "#1 in the world", best.map { "\($0.name) tops the leaderboard (index \(Fmt.score($0.index)))." } ?? "", symbol: "trophy.fill", good: true)
        } else if !top && s.endings.wasTop {
            note(&s, "rank", "Lost the #1 spot", "A rival's model passed yours on the leaderboard.", symbol: "arrow.down.right.circle.fill", good: false)
        }
        s.endings.wasTop = top
        if s.progression.rank > 0 && (s.endings.bestRank == 0 || s.progression.rank < s.endings.bestRank) { s.endings.bestRank = s.progression.rank }

        let vt = valuationTiers.filter { s.valuation >= $0.0 }.count
        if vt > s.endings.valuationTier {
            note(&s, "record", valuationTiers[vt - 1].1, "\(Fmt.money(s.valuation)) \(s.isPublic ? "market cap" : "valuation") in \(s.date.gameMonth).", symbol: "chart.line.uptrend.xyaxis", good: true)
        }
        s.endings.valuationTier = max(s.endings.valuationTier, vt)
        let rr = runRate(s)
        let rt = revenueTiers.filter { rr >= $0 }.count
        if rt > s.endings.revenueTier {
            note(&s, "record", "Revenue passes \(Fmt.money(revenueTiers[rt - 1])) a year", "Run-rate \(Fmt.money(rr)) a year.", symbol: "dollarsign.circle.fill", good: true)
        }
        s.endings.revenueTier = max(s.endings.revenueTier, rt)
        let st = staffTiers.filter { s.employees.count >= $0 }.count
        if st > s.endings.staffTier {
            note(&s, "people", "\(Fmt.int(staffTiers[st - 1])) people on staff", s.isPublicProgram ? "The public programme now fills \(st >= 3 ? "a campus" : "an office") with research, engineering and safety staff." : "The team that started in a garage now fills \(st >= 3 ? "a campus" : "an office").", symbol: "person.3.fill", good: true)
        }
        s.endings.staffTier = max(s.endings.staffTier, st)

        if s.thefts > s.endings.thefts {
            note(&s, "crisis", "Model weights stolen", "Attackers walked off with a copy of your weights (\(s.thefts) theft\(s.thefts == 1 ? "" : "s") so far).", symbol: "lock.open.fill", good: false)
            s.endings.thefts = s.thefts
        }
        for v in VictoryPath.allCases where s.victories.contains(v.rawValue) && !s.endings.victoriesSeen.contains(v.rawValue) {
            note(&s, "victory", "Victory: \(v.title)", v.goal, symbol: v.symbol, good: true)
            s.endings.victoriesSeen.insert(v.rawValue)
        }
        let ms = Moonshots.succeeded(s)
        if ms > s.endings.moonshotsSeen {
            let names = s.moonshots.filter { $0.status == .succeeded }.suffix(ms - s.endings.moonshotsSeen).compactMap { MoonshotCatalog.byID[$0.id]?.name }
            note(&s, "record", "Moonshot achieved\(names.isEmpty ? "" : ": " + names.joined(separator: ", "))", "", symbol: "moon.stars.fill", good: true)
            s.endings.moonshotsSeen = ms
        }
        var stars = 0
        for e in s.employees where e.skill >= 88 && !s.endings.starsSeen.contains(e.id.uuidString) {
            s.endings.starsSeen.insert(e.id.uuidString)
            stars += 1
            if stars <= 2 { note(&s, "people", "Star hire: \(e.name)", "\(e.role.title), skill \(Int(e.skill)).", symbol: "star.circle.fill", good: true) }
        }
        if let t = s.lastBoardThreat, t != s.endings.boardThreatSeen {
            note(&s, "crisis", "The board threatened to replace you", "Confidence had fallen to \(Int(s.boardConfidence)).", symbol: "person.3.fill", good: false)
            s.endings.boardThreatSeen = t
        }
        if let c = s.lastCorrection, c != s.endings.correctionSeen {
            note(&s, "crisis", "An AI market correction", "Valuations across the industry fell; yours was \(Fmt.money(s.valuation)).", symbol: "chart.line.downtrend.xyaxis", good: false)
            s.endings.correctionSeen = c
        }
    }

    // MARK: The Compact (treaty arc)

    /// Your weight in the talks this month: political capital, safety record (for the safety coalition), standing at home
    /// and how good your models are.
    static func treatyWeight(_ s: GameState) -> Double {
        let t = s.endings.treaty
        guard t.stance != 0 else { return 0 }
        let r = s.progression.rank
        let rankFactor = r == 1 ? 1.5 : r == 0 ? 0.2 : r <= 3 ? 1.2 : r <= 5 ? 1.0 : r <= 10 ? 0.6 : 0.3
        let record = t.stance > 0 ? s.safetyScore / 40 : 1.0
        return (0.5 + s.politicalCapital / 40 + record + homeStanding(s) / 50) * rankFactor
    }

    /// Everyone else's weight a month: governments, the other labs and civil society.
    static let othersWeight = 6.0
    /// Share of the weight at signing that makes the text yours.
    static let shapeShare = 0.4

    static func treatyEligible(_ s: GameState) -> Bool { (1...10).contains(s.progression.rank) }

    static func treaty(_ s: inout GameState) {
        var t = s.endings.treaty
        switch t.stage {
        case 0:
            // Talks open once frontier AI is a top political issue: from mid-2026 if worry is high, 2028 regardless.
            guard s.world.ready, s.year >= 2026.5, s.year >= 2028 || s.world.concern >= 50 else { return }
            t.stage = 1
            t.opened = s.date
            t.due = GameCalendar.addMonths(s.date, 8 + Int(roll(s, "treaty_len") * 5))
            s.endings.treaty = t
            Sim.news(&s, "Talks open on an \(compact)",
                     "Delegations from 41 governments meet in Geneva to agree compute reporting thresholds, pre-release testing and incident disclosure for frontier models. Labs with a model in the world's top ten get a seat. A text is due by \(t.due!.gameMonth).",
                     .policy, image: "gov_eu_commission", important: true)
            note(&s, "policy", "Compact talks open in Geneva", "41 governments, a text due by \(t.due!.gameMonth).", symbol: "globe.europe.africa.fill")
            if treatyEligible(s) { invite(&s) }
        case 1:
            if !t.invited && treatyEligible(s) { invite(&s); t = s.endings.treaty }
            t.others += othersWeight
            t.influence += treatyWeight(s)
            s.endings.treaty = t
            if !t.draftingOffered, t.stance != 0, let o = t.opened, GameCalendar.daysBetween(o, s.date) >= 90, s.decisions.count < 5 {
                s.endings.treaty.draftingOffered = true
                drafting(&s)
            }
            if let due = t.due, s.date >= due { conclude(&s) }
        default:
            return
        }
    }

    static func invite(_ s: inout GameState) {
        s.endings.treaty.invited = true
        Events.addDecision(&s, kind: "end_treaty_invite", title: "A seat at the Compact talks",
                           body: "With a model in the world's top ten, \(s.companyName) is invited to the \(compact) talks. The safety coalition wants pre-release testing, compute reporting and incident disclosure written into law; the light-touch camp wants voluntary commitments and no compute caps. Your safety score is \(Int(s.safetyScore)) and you hold \(Int(s.politicalCapital)) political capital — both count at the table.",
                           image: "gov_eu_commission",
                           options: [DecisionOption(label: "Join the safety coalition", detail: "Your weight grows each month with your safety score, political capital, standing at home and rank. Political capital −5."),
                                     DecisionOption(label: "Lobby for a light touch", detail: "Developers and investors cheer; researchers don't. Weight from political capital, standing and rank. Political capital −5."),
                                     DecisionOption(label: "Watch from the sidelines", detail: "No cost, and no say in the text.")])
    }

    static func drafting(_ s: inout GameState) {
        let safe = s.endings.treaty.stance > 0
        Events.addDecision(&s, kind: "end_treaty_draft", title: "Compact talks: the verification clause",
                           body: safe ? "The draft stalls on how anyone checks a lab's claims. The secretariat asks whether \(s.companyName) would let its own dangerous-capability evaluations become the common standard — tested on every lab, rivals included."
                                      : "The light-touch camp is losing the room on verification. A closing push from you in person could keep audits voluntary.",
                           image: "gov_eu_commission",
                           options: safe ? [DecisionOption(label: "Offer your evaluations as the standard", detail: "A big boost to your weight in the talks and brand +2. Rivals learn how you test."),
                                            DecisionOption(label: "Keep your evaluations private", detail: "No change.")]
                                         : [DecisionOption(label: "Fly in for the closing sessions", detail: "A big boost to your weight in the talks. Political capital −5."),
                                            DecisionOption(label: "Leave it to the lawyers", detail: "No change.")])
    }

    static func conclude(_ s: inout GameState) {
        var t = s.endings.treaty
        t.stage = 2
        t.signed = s.date
        t.shaped = t.stance != 0 && t.share >= shapeShare
        s.endings.treaty = t
        let strong = t.shaped ? t.stance > 0 : s.world.concern >= 50
        let text = strong ? "Frontier training runs above the reporting threshold must be declared, tested by an independent institute before release, and incidents disclosed within 72 hours."
                          : "Labs commit to voluntary safety frameworks and annual transparency reports; compute caps were dropped."
        let yours = t.stance == 0 ? "" : " Your share of the weight at signing: \(Fmt.pct(t.share, decimals: 0))."
        Sim.news(&s, "The \(compact) is signed", "\(text)\(yours)", .policy, image: "gov_eu_commission", important: true, good: t.shaped ? true : nil)
        if strong { World.shock(&s, concern: -6, "The \(compact) is signed") }
        switch (t.shaped, t.stance) {
        case (true, 1):
            s.safetyScore = min(100, s.safetyScore + 5)
            s.brand = min(100, s.brand + 5)
            s.politicalCapital = min(100, s.politicalCapital + 10)
            Stakeholders.move(&s, Stakeholders.everyGovernment(6).merging(["researchers": 4]) { $1 }, "Helped write the \(compact)")
            note(&s, "policy", "The Compact is signed — with your clauses", "Pre-release testing and incident disclosure are now international law. \(Fmt.pct(t.share, decimals: 0)) of the weight at the table was yours.", symbol: "signature", good: true)
            Events.addDecision(&s, kind: "end_treaty", title: "Your clauses are international law",
                               body: "The \(compact) was signed with the testing and disclosure rules \(s.companyName) argued for. Historians will call it the moment the frontier got guard rails — and your lab wrote them. You could keep building under the rules you wrote, or hand over now as the lab that wrote them.",
                               image: "gov_eu_commission",
                               options: [DecisionOption(label: "Keep building under the Compact", detail: "Play on. +5 safety, +5 brand and +10 political capital are already yours."),
                                         DecisionOption(label: "Retire as the lab that wrote the rules", detail: "End the game with the treaty ending and its epilogue. You keep your shares.")])
        case (true, _):
            s.market.hype += 0.05
            Stakeholders.move(&s, ["developers": 3, "researchers": -3], "Kept the \(compact) light-touch")
            note(&s, "policy", "The Compact is signed — light-touch, as you argued", "Voluntary commitments, no compute caps.", symbol: "signature", good: true)
        case (false, 1):
            s.politicalCapital = min(100, s.politicalCapital + 3)
            note(&s, "policy", "The Compact is signed without your clauses", "You argued for testing rules; others carried the room (\(Fmt.pct(t.share, decimals: 0)) of the weight was yours).", symbol: "signature")
        case (false, -1):
            Stakeholders.move(&s, Stakeholders.everyGovernment(-3), "Lobbied against the \(compact)")
            note(&s, "policy", "The Compact is signed over your objections", "Testing and disclosure rules passed anyway.", symbol: "signature", good: false)
        default:
            note(&s, "policy", "The Compact is signed", text, symbol: "signature")
        }
    }

    // MARK: State pressure (nationalisation arc)

    /// Where the state's pressure is heading: worry about AI, poor standing at home, a lead over the frontier, thefts and
    /// a model shipped against your red team's advice push it up; a golden share, a Compact you shaped and a strong
    /// safety record pull it down. Only frontier labs feel it.
    static func frictionTarget(_ s: GameState) -> Double {
        var t = max(0, s.world.concern - 35) * 0.9
        t += max(0, 50 - homeStanding(s)) * 0.8
        t += clamp(frontierLead(s) * 20, 0, 30)
        if s.progression.rank == 1 { t += 10 }
        if s.endings.brinkRisk != nil { t += 15 }
        t += Double(min(3, s.thefts)) * 4
        if s.endings.goldenShare { t -= 30 }
        if s.endings.treaty.shaped && s.endings.treaty.stance > 0 { t -= 20 }
        t -= max(0, s.safetyScore - 70) * 0.5
        return clamp(t, 0, 100)
    }

    static func statePressure(_ s: inout GameState) {
        guard !s.isPublicProgram, Progression.has(s, .frontierLab), s.year >= 2025, s.world.ready else {
            s.endings.friction *= 0.85
            return
        }
        s.endings.friction += (frictionTarget(s) - s.endings.friction) * 0.15
        let f = s.endings.friction
        let asked = s.endings.stateAsked.map { GameCalendar.daysBetween($0, s.date) } ?? 9_999
        let open = s.decisions.contains { $0.kind.hasPrefix("end_state") }
        guard !open, !s.endings.goldenShare else { return }
        switch s.endings.stateStage {
        case 0 where f >= 55 && asked >= 365 && s.decisions.count < 5:
            s.endings.stateStage = 1
            s.endings.stateAsked = s.date
            note(&s, "policy", "The government asks for a golden share", "State pressure \(Int(f))/100.", symbol: "building.columns.fill", good: false)
            Events.addDecision(&s, kind: "end_state_golden", title: "\(government(s).prefix(1).uppercased() + government(s).dropFirst()) wants a golden share",
                               body: "Officials say a lab with \(possessive(s.companyName)) capabilities is critical national infrastructure. They want a golden share: a veto over foreign sales, transfers of model weights and frontier releases. Behind closed doors they mention emergency powers if you refuse.",
                               image: "gov_capitol",
                               options: [DecisionOption(label: "Grant the golden share", detail: "The state gets its veto; the pressure eases for good. Board −8, home government +8."),
                                         DecisionOption(label: "Negotiate a narrower deal", detail: "Offer a security liaison and pre-release briefings instead. Political capital −10; the pressure eases a little."),
                                         DecisionOption(label: "Refuse", detail: "Nothing changes on paper. Home government −8, and they may push harder.")])
        case 1 where f >= 75 && asked >= 180:
            s.endings.stateStage = 2
            note(&s, "crisis", "Emergency powers invoked", "The government moved to take control of the company.", symbol: "exclamationmark.triangle.fill", good: false)
            let win = courtOdds(s)
            Events.addDecision(&s, kind: "end_state_emergency", title: "The government invokes emergency powers",
                               body: "Citing national security, \(government(s)) has moved to take control of \(s.companyName). Your models are now treated as strategic assets; officials want either a seat at the table or the whole table.",
                               image: "gov_capitol",
                               options: [DecisionOption(label: "Fight it in court", detail: "Political capital −20 and \(Fmt.money(legalFees(s))) in legal fees. About \(Int(win * 100))% to win (political capital and public trust help). Lose and you must comply or hand over."),
                                         DecisionOption(label: "Accept a golden share and an oversight board", detail: "The state gets a veto and two board seats; you keep the company. Board −12."),
                                         DecisionOption(label: "Hand the company to the state", detail: "It becomes a national AI lab. Shareholders get 60% of the last valuation (\(Fmt.money(s.valuation * 0.6))) in government bonds. The game ends.")])
        default:
            if f < 30 && s.endings.stateStage > 0 { s.endings.stateStage = 0 }
        }
    }

    static func courtOdds(_ s: GameState) -> Double {
        clamp(0.35 + s.politicalCapital / 200 + (s.world.publicTrust - 50) / 150, 0.15, 0.85)
    }

    static func legalFees(_ s: GameState) -> Double { clamp(s.valuation * 0.0005, 2e6, 2e8) }

    // MARK: Outcompeted

    /// Out of the race: three years in, no model in the top eight, under 1% of the API market and not a frontier lab.
    static func outOfRace(_ s: GameState) -> Bool {
        s.year - s.startDate.decimalYear >= 3 && (s.progression.rank == 0 || s.progression.rank > 8)
            && s.apiShareNow < 0.01 && !Progression.has(s, .frontierLab)
    }

    static func buyer(_ s: GameState) -> String {
        let live = s.competitors.filter { !$0.acquired && !$0.bankrupt && $0.exitNote.isEmpty }
        return live.max { $0.valuation < $1.valuation }.map { CompetitorCatalog.def($0.id).name } ?? "A big tech company"
    }

    static func acquihirePrice(_ s: GameState) -> Double {
        max(s.valuation * 0.5, Double(s.employees.count) * (s.year >= 2024 ? 3e6 : 1.5e6))
    }

    static func outcompeted(_ s: inout GameState) {
        guard !s.isPublicProgram else {
            s.endings.irrelevant = 0
            return
        }
        s.endings.irrelevant = outOfRace(s) ? s.endings.irrelevant + 1 : max(0, s.endings.irrelevant - 2)
        let last = s.endings.outcompetedOffered.map { GameCalendar.daysBetween($0, s.date) } ?? 9_999
        guard s.endings.irrelevant >= 18, last >= 365, s.decisions.count < 5 else { return }
        s.endings.outcompetedOffered = s.date
        let price = acquihirePrice(s)
        let who = buyer(s)
        let rank = s.progression.rank == 0 ? "nothing on the leaderboard" : "your best model at #\(s.progression.rank)"
        note(&s, "crisis", "Out of the race", "18 months with \(rank) and under 1% of the API market.", symbol: "flag.checkered", good: false)
        Events.addDecision(&s, kind: "end_outcompeted", title: "The race has moved on",
                           body: "For a year and a half \(s.companyName) has had \(rank) and under 1% of the API market, while the frontier labs spend more on one training run than you've raised in total. \(who) has made a quiet offer to bring your team in-house. Some founders keep fighting from here; some take the offer; some open-source everything on the way out.",
                           image: "garage",
                           options: [DecisionOption(label: "Keep fighting", detail: "Stay independent. Nothing changes."),
                                     DecisionOption(label: "Accept the acqui-hire", detail: "\(who) pays \(Fmt.money(price)); your stake is worth \(Fmt.money(price * s.founderStake)). The game ends."),
                                     DecisionOption(label: "Open-source everything and close the doors", detail: "Publish your weights, code and data recipes. No payout, but developers won't forget. The game ends.")],
                           amount: price)
    }

    // MARK: The IPO'd giant

    static func giantReady(_ s: GameState) -> Bool {
        !s.isPublicProgram && s.isPublic && s.monthsAtTop >= 12 && s.valuation >= 1e12 * Victory.empireScale(s.year)
    }

    static func giant(_ s: inout GameState) {
        guard !s.endings.giantOffered, giantReady(s), s.decisions.count < 5 else { return }
        s.endings.giantOffered = true
        Events.addDecision(&s, kind: "end_giant", title: "A year at the top of the market",
                           body: "\(s.companyName) has held #1 for \(s.monthsAtTop) months and trades at \(Fmt.money(s.valuation)). The exchange has invited you to ring the opening bell on the anniversary of the listing, and the board has a successor ready if you want to hand over at the peak.",
                           image: "stock_exchange",
                           options: [DecisionOption(label: "Stay on as CEO", detail: "Play on. The offer stays open from the Legacy screen."),
                                     DecisionOption(label: "Ring the bell and hand over", detail: "Become chair and end the game with the giant ending. You keep your shares.")])
    }

    // MARK: The brink (dangerous capabilities) and near misses

    static func brink(_ s: inout GameState) {
        // A model you shipped against the red team's advice: the patch holds, or it doesn't.
        if let due = s.endings.brinkRisk, s.date >= due {
            s.endings.brinkRisk = nil
            if roll(s, "brink_incident") < 0.55 {
                s.brand = max(0, s.brand - 12)
                s.safetyScore = max(0, s.safetyScore - 8)
                s.endings.friction = min(100, s.endings.friction + 15)
                World.shock(&s, concern: 8, "A model from \(s.companyName) was used in a cyberattack", incident: "cyberattack")
                Stakeholders.move(&s, Stakeholders.everyGovernment(-6).merging(["public": -5]) { $1 }, "Your model was used in a cyberattack")
                Sim.news(&s, "Model from \(s.companyName) used in a wave of cyberattacks",
                         "Investigators say attackers used the model to find and chain unpatched vulnerabilities at three hospitals and a port operator. The refusal patch didn't hold. Brand −12, safety −8.",
                         .policy, image: "network", important: true, good: false)
                note(&s, "crisis", "Your model was used in a cyberattack", "The patched refusal layer failed in the wild.", symbol: "bolt.trianglebadge.exclamationmark.fill", good: false)
            } else {
                note(&s, "safety", "The refusal patch held", "No misuse of your model was found.", symbol: "checkmark.shield", good: true)
            }
        }
        guard !s.endings.brinkFired, s.year >= 2025.5, Progression.has(s, .frontierLab), s.decisions.count < 5,
              let m = s.models.filter(\.released).max(by: { $0.c < $1.c }), m.c >= Macro.frontier(s.year) - 0.1,
              roll(s, "brink|\(s.date.ym.year)-\(s.date.ym.month)") < 0.12 else { return }
        s.endings.brinkFired = true
        Events.addDecision(&s, kind: "end_brink", title: "Red team: \(m.name)'s successor can break into systems on its own",
                           body: "Your dangerous-capability evaluations found that the checkpoint after \(m.name) can find and chain previously unknown software vulnerabilities with no human help — on three of five hardened test targets. Nobody outside the lab knows yet.",
                           image: "network",
                           options: [DecisionOption(label: "Hold it back and brief the safety institute", detail: "Retrain the refusals before anything ships. Brand −3, safety +6, political capital +5. A near miss you caught."),
                                     DecisionOption(label: "Ship it with a patched refusal layer", detail: "Nothing changes now. If the patch fails in the wild, a public incident follows within months.")],
                           ref: m.name)
    }

    static func nearMiss(_ s: inout GameState, _ what: String) {
        s.endings.nearMisses.append(s.date)
        note(&s, "safety", "Near miss", what, symbol: "exclamationmark.shield.fill", good: true)
        if s.safetyScore >= 60, s.endings.avertedOffers < 2, s.endings.avertedDue == nil {
            s.endings.avertedDue = GameCalendar.addDays(s.date, 20)
        }
    }

    static func offerAverted(_ s: inout GameState) {
        guard s.endings.avertedOffers < 2, s.decisions.count < 6 else { return }
        s.endings.avertedOffers += 1
        let what = s.endings.chronicle.last { $0.kind == "safety" && $0.title == "Near miss" }?.detail ?? "The incident"
        Events.addDecision(&s, kind: "end_averted", title: "After the near miss",
                           body: "\(what). It's contained. The AI Safety Institute wants the full story on the record, and some of your directors think someone else should run the frontier race from here. You could testify, hand the system to the institute and step back — leaving as the founder who stopped it.",
                           image: "space_mission_control",
                           options: [DecisionOption(label: "Keep building, more carefully", detail: "Nothing changes."),
                                     DecisionOption(label: "Testify and step back", detail: "End the game with the near-miss ending. You keep your shares; the company carries on under new leadership.")])
    }

    // MARK: Answers

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        // A public institution has no shareholders to sell, acquihire or nationalise. This also closes stale saves
        // defensively if a private-only decision was already sitting in the inbox when the career became public.
        if s.isPublicProgram, d.kind.hasPrefix("end_state") || d.kind == "end_outcompeted" || d.kind == "end_giant" { return }
        switch (d.kind, option) {
        case ("end_treaty_invite", 0), ("end_treaty_invite", 1):
            s.endings.treaty.stance = option == 0 ? 1 : -1
            s.politicalCapital = max(0, s.politicalCapital - 5)
            Stakeholders.move(&s, option == 0 ? ["researchers": 2] : ["developers": 2, "researchers": -2],
                              option == 0 ? "Joined the safety coalition at the Compact talks" : "Lobbied for a light-touch Compact")
            note(&s, "policy", option == 0 ? "Joined the safety coalition at the Compact talks" : "Lobbied for a light-touch Compact", "", symbol: "person.3.sequence.fill")
        case ("end_treaty_draft", 0):
            s.endings.treaty.influence += 10
            if s.endings.treaty.stance > 0 { s.brand = min(100, s.brand + 2) } else { s.politicalCapital = max(0, s.politicalCapital - 5) }
            note(&s, "policy", s.endings.treaty.stance > 0 ? "Your evaluations became the Compact's test suite" : "Closing push at the Compact talks", "", symbol: "doc.text.magnifyingglass")
        case ("end_treaty", 1):
            end(&s, .treaty, "You retired on \(s.date.gameShort), the founder whose lab wrote the \(compact)'s testing rules.")
        case ("end_state_golden", 0), ("end_state_emergency", 1), ("end_state_ultimatum", 0):
            s.endings.goldenShare = true
            s.endings.stateStage = 0
            s.endings.friction = max(0, s.endings.friction - 35)
            s.boardConfidence = max(0, s.boardConfidence - (d.kind == "end_state_golden" ? 8 : d.kind == "end_state_emergency" ? 12 : 15))
            Stakeholders.move(&s, [HQ.region(s).rawValue: d.kind == "end_state_golden" ? 8 : 4], "Gave the government a golden share")
            Sim.news(&s, "\(s.companyName) gives the government a golden share", "The state gets a veto over foreign sales, weight transfers and frontier releases\(d.kind == "end_state_golden" ? "" : ", and two seats on the board"). Investors grumble; officials are satisfied.", .policy, image: "gov_capitol", important: true)
            note(&s, "policy", "Golden share granted", "A state veto over weight transfers and frontier releases.", symbol: "building.columns.fill")
        case ("end_state_golden", 1):
            if s.politicalCapital >= 10 {
                s.politicalCapital -= 10
                s.endings.friction = max(0, s.endings.friction - 12)
            } else {
                Stakeholders.move(&s, [HQ.region(s).rawValue: -3], "Offered officials less than they asked for")
                s.endings.friction = max(0, s.endings.friction - 5)
            }
        case ("end_state_golden", _):
            s.endings.friction = min(100, s.endings.friction + 12)
            Stakeholders.move(&s, [HQ.region(s).rawValue: -8], "Refused the government a golden share")
        case ("end_state_emergency", 0):
            s.politicalCapital = max(0, s.politicalCapital - 20)
            let fees = legalFees(s)
            s.cash -= fees
            s.month.costOther += fees
            if roll(s, "court|\(s.date.ym.year)-\(s.date.ym.month)") < courtOdds(s) {
                s.endings.stateStage = 0
                s.endings.stateAsked = s.date
                s.endings.friction = max(0, s.endings.friction - 30)
                Sim.news(&s, "Court blocks the takeover of \(s.companyName)", "Judges ruled the emergency powers don't reach a private lab's models. Legal fees: \(Fmt.money(fees)).", .policy, image: "gov_capitol", important: true, good: true)
                note(&s, "policy", "Won in court against the takeover", "", symbol: "building.columns.fill", good: true)
            } else {
                s.endings.stateStage = 3
                note(&s, "crisis", "Lost in court", "The emergency powers stand.", symbol: "building.columns.fill", good: false)
                Events.addDecision(&s, kind: "end_state_ultimatum", title: "The court rules for the government",
                                   body: "The emergency powers stand. Officials give \(s.companyName) a choice: a golden share and an oversight board, or the state takes the company outright and pays shareholders in bonds.",
                                   image: "gov_capitol",
                                   options: [DecisionOption(label: "Comply: golden share and oversight board", detail: "You keep running the company under a state veto. Board −15."),
                                             DecisionOption(label: "Hand the company to the state", detail: "It becomes a national AI lab; shareholders get 60% of the last valuation (\(Fmt.money(s.valuation * 0.6))) in bonds. The game ends.")])
            }
        case ("end_state_emergency", 2), ("end_state_ultimatum", 1):
            s.exitValue = s.valuation * 0.6
            end(&s, .nationalised, "\(s.companyName) became a national AI lab on \(s.date.gameShort). Shareholders were paid \(Fmt.money(s.valuation * 0.6)) in bonds; your stake: \(Fmt.money(s.valuation * 0.6 * s.founderStake)).")
        case ("end_outcompeted", 1):
            s.exitValue = d.amount
            s.endings.variant = "acquihire"
            end(&s, .outcompeted, "\(buyer(s)) acqui-hired \(s.companyName) for \(Fmt.money(d.amount)) on \(s.date.gameShort). Your stake: \(Fmt.money(d.amount * s.founderStake)).")
        case ("end_outcompeted", 2):
            s.exitValue = 0
            s.endings.variant = "opensource"
            s.world.developers = min(100, s.world.developers + 10)
            end(&s, .outcompeted, "\(s.companyName) open-sourced everything and closed its doors on \(s.date.gameShort).")
        case ("end_giant", 1):
            s.keptStake = true
            end(&s, .giant, "You rang the bell and handed \(s.companyName) to your successor on \(s.date.gameShort), at a \(Fmt.money(s.valuation)) market cap.")
        case ("end_brink", 0):
            s.brand = max(0, s.brand - 3)
            s.safetyScore = min(100, s.safetyScore + 6)
            s.politicalCapital = min(100, s.politicalCapital + 5)
            s.endings.friction = max(0, s.endings.friction - 5)
            Sim.news(&s, "\(s.companyName) holds back a model after its own red team's findings", "The lab briefed the AI Safety Institute and is retraining the model's refusals before release.", .policy, image: "network", important: true, good: true)
            nearMiss(&s, "Held back a model that could break into systems on its own")
        case ("end_brink", _):
            s.endings.brinkRisk = GameCalendar.addMonths(s.date, 3 + Int(roll(s, "brink_delay") * 6))
            note(&s, "safety", "Shipped despite the red team", "A patched refusal layer stands between the model and misuse.", symbol: "exclamationmark.triangle", good: false)
        case ("end_averted", 1):
            s.keptStake = true
            end(&s, .averted, "You testified, handed the system to the AI Safety Institute and stepped back from \(s.companyName) on \(s.date.gameShort).")
        default:
            break
        }
    }

    // MARK: The end

    /// Ends the game with one of this system's endings (only ever from an answer the player picked).
    static func end(_ s: inout GameState, _ k: EndingKind, _ text: String) {
        guard s.gameOver == nil else { return }
        s.endings.pending = k.rawValue
        s.gameOver = text
        Sim.news(&s, "\(k.title): \(s.companyName)", text, k == .nationalised ? .policy : .company, image: k.image, important: true, good: k.mood > 0 ? true : nil)
        finalize(&s)
    }

    /// The ending a finished (or would-be finished) game gets: this system's own pick first, then the game over's cause.
    static func classify(_ s: GameState) -> EndingKind {
        if let k = EndingKind(rawValue: s.endings.ending) { return k }
        if let k = EndingKind(rawValue: s.endings.pending) { return k }
        let g = s.gameOver ?? ""
        if g.hasPrefix("Bankrupt") { return .bankrupt }
        if g.hasPrefix("Loss of control") { return .lossOfControl }
        if g.hasPrefix("The board voted you out") { return .ousted }
        if g.hasPrefix("You stepped down") { return .steppedDown }
        if g.hasPrefix("Acquired for") { return .acquired }
        if g.hasPrefix("You retired"), let v = VictoryPath.allCases.first(where: { g.contains($0.title) }) { return victoryEnding(v, s) }
        return .retired
    }

    static func victoryEnding(_ v: VictoryPath, _ s: GameState) -> EndingKind {
        switch v {
        case .superintelligence: .alignedAGI
        case .guardian: s.endings.treaty.shaped && s.endings.treaty.stance > 0 ? .treaty : .guardian
        case .empire, .dominance: s.isPublic ? .giant : .empire
        case .xeno: .xeno
        case .publicService: .publicService
        }
    }

    /// The best ending retiring today would give.
    static func retirement(_ s: GameState) -> EndingKind {
        let order = [VictoryPath.superintelligence, .guardian, .publicService, .xeno, .empire, .dominance]
            .filter { Victory.available(s).contains($0) }
        if let v = order.first(where: { s.victories.contains($0.rawValue) }) {
            let k = victoryEnding(v, s)
            if k != .guardian || !(s.endings.treaty.shaped && s.endings.treaty.stance > 0) { return k }
        }
        if s.endings.treaty.shaped && s.endings.treaty.stance > 0 { return .treaty }
        if giantReady(s) { return .giant }
        return .retired
    }

    static let minDaysToRetire = 365

    /// Retire from the Legacy screen. Returns why not, or nil.
    static func retire(_ s: inout GameState) -> String? {
        guard s.gameOver == nil else { return "The game is already over." }
        let days = GameCalendar.daysBetween(s.startDate, s.date)
        guard days >= minDaysToRetire else { return "Lead the \(s.isPublicProgram ? "programme" : "company") for at least a year first (\(minDaysToRetire - days) days to go)." }
        let k = retirement(s)
        s.keptStake = true
        let handover = s.isPublicProgram ? "handed leadership of \(s.companyName) to a successor under continuing parliamentary oversight" : "handed \(s.companyName) to a successor"
        end(&s, k, "You retired on \(s.date.gameShort) and \(handover). Ending: \(k.title).")
        return nil
    }

    /// Stamps the ending, date and final score the first time the game is seen over.
    static func finalize(_ s: inout GameState) {
        guard s.gameOver != nil, s.endings.ending.isEmpty else { return }
        let k = classify(s)
        s.endings.ending = k.rawValue
        s.endings.endedOn = s.date
        s.endings.finalScore = score(s, k).total
        note(&s, "ending", k.title, s.gameOver ?? "", symbol: k.symbol, good: k.mood > 0 ? true : k.mood < 0 ? false : nil)
    }

    // MARK: Score

    struct ScoreLine: Identifiable, Hashable {
        var id: String { label }
        let label: String
        let detail: String
        let points: Int
    }

    struct Score {
        var lines: [ScoreLine]
        /// The legacy score (Victory.legacyScore), the ending's bonus and the total.
        var legacy: Int
        var bonus: Int
        var total: Int
        var penalty: Bool
    }

    /// The legacy score, line by line (the same parts as Victory.legacyScore), plus the ending's bonus.
    static func score(_ s: GameState, _ ending: EndingKind?) -> Score {
        let origin: [(String, String, Double)] = s.isPublicProgram ? [
            ("Public missions delivered", "\(s.publicProgram.completedMissions) × 140", Double(s.publicProgram.completedMissions) * 140),
            ("Programme level", "\(s.publicProgram.level) × 400", Double(s.publicProgram.level) * 400),
            ("Oversight confidence", "\(Int(s.publicProgram.oversight)) × 5", s.publicProgram.oversight * 5),
            ("Public trust", "\(Int(s.world.publicTrust)) × 2", s.world.publicTrust * 2),
            ("Public missions missed", "\(s.publicProgram.failedMissions) × −40", -Double(s.publicProgram.failedMissions) * 40),
        ] : [
            ("Founder wealth", Fmt.money(max(0, s.founderNetWorth)), 10 * log10(1 + max(0, s.founderNetWorth) / 1e6) * 10),
        ]
        let parts: [(String, String, Double)] = origin + [
            ("Achievements", "\(s.achievements.count) × 40", Double(s.achievements.count) * 40),
            ("Victories", "\(s.victories.count) × 1,000", Double(s.victories.count) * 1_000),
            ("Best model", "index \(Fmt.score(s.models.map(\.index).max() ?? 0)) × 8", (s.models.map(\.index).max() ?? 0) * 8),
            ("Moonshots", "\(Moonshots.succeeded(s)) × 150", Double(Moonshots.succeeded(s)) * 150),
            ("Frontier research", "\(min(s.programLevelsTotal, 250)) levels × 4", Double(min(s.programLevelsTotal, 250)) * 4),
            ("Safety record", "\(Int(s.safetyScore)) × 3", s.safetyScore * 3),
            ("Weights stolen", "\(s.thefts) × −60", -Double(s.thefts) * 60),
        ] + (s.objectivesCompleted > 0 ? [("Board goals met", "\(s.objectivesCompleted) × 25", Double(s.objectivesCompleted) * 25)] : [])
        let raw = parts.reduce(0) { $0 + $1.2 }
        let penalty = s.gameOver != nil && s.exitValue == nil && !s.keptStake
        let legacy = max(0, Int(raw * (penalty ? 0.6 : 1)))
        var lines = parts.filter { abs($0.2) >= 0.5 }.map { ScoreLine(label: $0.0, detail: $0.1, points: Int($0.2.rounded())) }
        if penalty { lines.append(ScoreLine(label: "Left with nothing", detail: "× 0.6", points: legacy - Int(raw.rounded()))) }
        let bonus = ending?.bonus ?? 0
        if let ending { lines.append(ScoreLine(label: "Ending: \(ending.title)", detail: bonus >= 0 ? "bonus" : "penalty", points: bonus)) }
        return Score(lines: lines, legacy: legacy, bonus: bonus, total: max(0, legacy + bonus), penalty: penalty)
    }

    /// Historians' verdict for a final score.
    static func grade(_ total: Int) -> (title: String, symbol: String) {
        switch total {
        case 8_000...: ("Legendary", "sparkles")
        case 5_000..<8_000: ("Historic", "star.fill")
        case 3_000..<5_000: ("Celebrated", "rosette")
        case 1_500..<3_000: ("Notable", "medal.fill")
        case 600..<1_500: ("A footnote", "text.book.closed.fill")
        default: ("Forgotten", "wind")
        }
    }

    // MARK: History

    struct Moment: Identifiable, Hashable {
        let id: String
        let date: Date
        let title: String
        let detail: String
        let symbol: String
        /// "company", "model", "money", "milestone", "people", "policy", "crisis", "record", "safety", "ending"…
        let kind: String
        let good: Bool?
    }

    /// The company's history, oldest first: the founding, rounds, the IPO, personal-best releases, launches at #1, AI
    /// milestones claimed, landmark training firsts, stage promotions and the chronicle.
    static func timeline(_ s: GameState) -> [Moment] {
        var out: [Moment] = []
        let seed = s.rounds.first
        out.append(Moment(id: "founded", date: s.startDate, title: "\(s.companyName) is founded",
                          detail: s.isPublicProgram
                            ? "\(s.founderName) establishes a government AI branch under the \(s.publicProgram.mandate.title) mandate, funded by appropriation and answerable to public oversight."
                            : seed.map { "\(s.founderName) raises a \(Fmt.money($0.amount)) \($0.name.lowercased()) led by \($0.lead)." } ?? "\(s.founderName) starts a lab in a garage.",
                          symbol: s.isPublicProgram ? "building.columns.fill" : "house.fill", kind: "company", good: true))
        for r in s.rounds.dropFirst() {
            out.append(Moment(id: "round-\(r.id)", date: r.date, title: "Raised \(Fmt.money(r.amount)): \(r.name)",
                              detail: "Led by \(r.lead) at \(Fmt.money(r.preMoney)) before the money.", symbol: "banknote.fill", kind: "money", good: true))
        }
        if let ipo = s.stock.first {
            out.append(Moment(id: "ipo", date: ipo.date, title: "IPO", detail: "Listed at \(Fmt.price(ipo.price)) a share.", symbol: "bell.fill", kind: "money", good: true))
        }
        // Personal-best releases (by capability; the index shown is the one at launch, since indexes are rescored as benchmarks saturate).
        var best = -Double.infinity
        let launches = Dictionary(s.launches.map { ($0.modelID, $0) }, uniquingKeysWith: { a, _ in a })
        for m in s.models.filter({ $0.releaseDate != nil && !$0.preview }).sorted(by: { $0.releaseDate! < $1.releaseDate! }) {
            let l = launches[m.id]
            guard m.c > best || l?.rank == 1 else { continue }
            let first = best == -Double.infinity
            best = max(best, m.c)
            out.append(Moment(id: "model-\(m.id)", date: m.releaseDate!, title: first ? "First release: \(m.name)" : "Released \(m.name)",
                              detail: "Intelligence Index \(Fmt.score(l?.index ?? m.index)) at launch\(l.map { ", #\($0.rank) in the world" } ?? "")\(m.openWeights ? ", open weights" : "").",
                              symbol: l?.rank == 1 ? "trophy.fill" : "cube.box.fill", kind: "model", good: true))
        }
        // Milestones claimed the same day by the same model read as one moment.
        let wins = s.milestoneWins.filter { $0.labID == "player" && !$0.history }
        for (_, group) in Dictionary(grouping: wins, by: { "\($0.date.timeIntervalSince1970)|\($0.model)" }) {
            let g = group.sorted { (MilestoneCatalog.byID[$0.id]?.tier ?? 0, $1.id) > (MilestoneCatalog.byID[$1.id]?.tier ?? 0, $0.id) }
            guard let w = g.first else { continue }
            let def = MilestoneCatalog.byID[w.id]
            let title = g.count <= 2 ? "First to: " + g.compactMap { MilestoneCatalog.byID[$0.id]?.title }.joined(separator: " · ")
                                     : "First to \(g.count) milestones at once"
            let detail = g.count <= 2 ? "\(w.model) got there before any other lab."
                                      : "\(w.model): " + g.compactMap { MilestoneCatalog.byID[$0.id]?.title.lowercased() }.joined(separator: ", ") + "."
            out.append(Moment(id: "ms-\(w.id)", date: w.date, title: title, detail: detail, symbol: def?.symbol ?? "signpost.right.fill", kind: "milestone", good: true))
        }
        for f in s.trainingFirsts where f.landmark && !f.quiet {
            out.append(Moment(id: "first-\(f.id)", date: f.date, title: f.title, detail: f.detail, symbol: f.symbol, kind: "model", good: true))
        }
        for (raw, date) in s.progression.reached where raw > 0 && !s.progression.credited.contains(raw) {
            if let st = CompanyStage(rawValue: raw) {
                out.append(Moment(id: "stage-\(raw)", date: date, title: "Became a \(st.title)", detail: st.blurb, symbol: st.symbol, kind: "company", good: true))
            }
        }
        for (i, c) in s.endings.chronicle.enumerated() {
            out.append(Moment(id: "c-\(i)", date: c.date, title: c.title, detail: c.detail, symbol: c.symbol, kind: c.kind, good: c.good))
        }
        return out.sorted { $0.date != $1.date ? $0.date < $1.date : $0.id < $1.id }
    }

    // MARK: Epilogue text

    /// Peak valuation over the company's months.
    static func peakValuation(_ s: GameState) -> Double { max(s.valuation, s.history.map(\.valuation).max() ?? 0) }

    static func bestYearRevenue(_ s: GameState) -> Double {
        guard !s.history.isEmpty else { return 0 }
        var best = 0.0
        var window = 0.0
        for (i, h) in s.history.enumerated() {
            window += h.revenue
            if i >= 12 { window -= s.history[i - 12].revenue }
            best = max(best, window)
        }
        return best
    }

    /// Two or three paragraphs: how it started, how it ended, what it left behind.
    static func story(_ s: GameState, _ k: EndingKind) -> [String] {
        let years = max(1, Int((Double(GameCalendar.daysBetween(s.startDate, s.endings.endedOn ?? s.date)) / 365.25).rounded()))
        let best = s.models.max { $0.index < $1.index }
        let claimed = s.milestoneWins.filter { $0.labID == "player" && !$0.history }.count
        let open: String
        if s.isPublicProgram {
            open = "\(s.founderName) established \(s.companyName) in \(s.startDate.gameMonth) as a public AI branch under the \(s.publicProgram.mandate.title) mandate. Over \(years) year\(years == 1 ? "" : "s") it shipped \(s.models.filter { $0.released }.count) model\(s.models.filter { $0.released }.count == 1 ? "" : "s")\(best.map { ", the best of them \($0.name) at index \(Fmt.score($0.index))" } ?? ""), delivered \(s.publicProgram.completedMissions) measured public mission\(s.publicProgram.completedMissions == 1 ? "" : "s"), and grew into a level-\(s.publicProgram.level) \(PublicProgram.levelNames[clamp(s.publicProgram.level, 1, 4)]).\(s.monthsAtTop > 0 || s.endings.bestRank == 1 ? " For a while it was the best lab in the world." : "")"
        } else {
            open = "\(s.founderName) founded \(s.companyName) in \(s.startDate.gameMonth)\(s.rounds.first.map { " with a \(Fmt.money($0.amount)) \($0.name.lowercased())" } ?? "") and a garage full of borrowed ambition. Over \(years) year\(years == 1 ? "" : "s") it shipped \(s.models.filter { $0.released }.count) model\(s.models.filter { $0.released }.count == 1 ? "" : "s")\(best.map { ", the best of them \($0.name) at index \(Fmt.score($0.index))" } ?? ""), \(claimed > 0 ? "was first to \(claimed) AI milestone\(claimed == 1 ? "" : "s"), " : "")and peaked at \(Fmt.money(peakValuation(s))).\(s.monthsAtTop > 0 || s.endings.bestRank == 1 ? " For a while it was the best lab in the world." : "")"
        }
        let close: String
        switch k {
        case .alignedAGI:
            close = "Then it built the thing everyone had argued about for a decade: a system better than any human at almost everything — and it stayed honest. Safety teams across the world now train on \(possessive(s.companyName)) alignment methods, and the model that started it is kept running in a quiet datacenter as a reference, the way a country keeps its standard kilogram."
        case .treaty:
            close = "Its most lasting product was not a model but a paragraph. The \(compact)'s testing and disclosure clauses — \(possessive(s.companyName)) clauses — now bind every frontier lab. Law students learn them by article number; engineers know them as the reason every release waits for the institute's sign-off."
        case .guardian:
            close = "It never stopped being near the top, and it never stopped publishing what went wrong. When regulators drafted their rules they copied \(possessive(s.companyName)) safety framework almost word for word, and rivals quietly adopted its evaluations rather than be compared unfavourably."
        case .giant:
            close = "By the end it was a listed giant: \(s.monthsAtTop) months at #1, a \(Fmt.money(s.valuation)) market cap and an index fund in every pension. \(s.founderName) rang the opening bell one last time and moved up to chair, leaving a successor with a company that had become part of the infrastructure."
        case .empire:
            close = "It became one of the most valuable companies ever built, still private, still answerable mostly to its founder. Business schools teach it as a case study in compounding: compute bought early, models shipped often, money reinvested."
        case .xeno:
            close = "Its agents found computing architectures no human had designed, and \(s.companyName) put them in silicon. Physicists are still arguing about why they work. The chips, meanwhile, run half the world's inference."
        case .publicService:
            close = "It became public infrastructure rather than a private empire: a national AI service whose models, evaluations and operating playbooks belonged to citizens. Appropriations followed measured delivery, independent oversight stayed in the room, and the institution remained accountable after its founding director moved on."
        case .averted:
            close = "It will be remembered for a day that didn't happen. When one of its systems slipped its leash, the lab caught it, shut it down and told the world exactly how close it had come. \(s.founderName) testified, stepped back, and the incident report became required reading at every lab."
        case .acquired:
            close = "In the end someone bigger wanted what it had built. The deal closed at \(Fmt.money(s.exitValue ?? 0)); the team, the weights and the name moved into a larger company, and \(s.founderName) walked away with \(Fmt.money((s.exitValue ?? 0) * s.founderStake))."
        case .nationalised:
            close = "The state decided a lab this capable was too important to leave in private hands. \(s.companyName) became a national AI lab: the same people, the same datacenters, a flag on the badge and a government bond for every share."
        case .outcompeted:
            close = s.endings.variant == "opensource"
                ? "The frontier labs pulled away, and \(s.companyName) chose to go out loud: every weight, every line of training code and every data recipe went public on its last day. Its models still turn up in research papers and hobby projects years later."
                : "The frontier labs pulled away. In the end \(s.companyName) was acqui-hired; its people now work on someone else's frontier models, and a few of them still keep the old logo on their laptops."
        case .retired:
            close = s.isPublicProgram
                ? "\(s.founderName) handed the programme to a successor with its mandate, public records and oversight relationships intact. The work continued without them: less a founder's lab than a durable civic institution."
                : "\(s.founderName) handed the company over on their own terms, before anyone asked them to. It went on without them — a little more cautious, a little more corporate, still recognisably the lab they started."
        case .steppedDown:
            close = "\(s.founderName) left the CEO's office with their shares and their reputation mostly intact. The company carried on under professional management; the culture they built outlasted them."
        case .ousted:
            close = "The board decided someone else should run it. \(s.founderName) found out in a fifteen-minute call and kept a stake in a company they no longer controlled."
        case .bankrupt:
            close = peakValuation(s) >= 1e11 || claimed >= 5
                ? "It had the breakthroughs and ran out of money anyway: the leases, chip orders and payroll signed at the peak outlasted the revenue. Creditors took the datacenters, rivals hired the people, and \(s.companyName) became the industry's favourite warning about building ahead of demand."
                : "The money ran out before the breakthroughs came. Creditors took the chips, rivals took the people, and the name became a cautionary slide in other founders' pitch decks."
        case .lossOfControl:
            close = "Then something it built got out. Copies spread faster than anyone could revoke them; governments shut the company down and spent years cleaning up. Every safety framework written since cites what happened at \(s.companyName)."
        }
        var out = [open, close]
        let g = grade(score(s, k).total).title
        out.append(s.isPublicProgram
            ? "Historians' verdict: \(g.lowercased()). \(s.companyName) left behind \(s.publicProgram.completedMissions) delivered public missions, \(s.achievements.count) achievement\(s.achievements.count == 1 ? "" : "s") and \(Fmt.flops(s.lifetimeFLOPs)) FLOPs of public-interest computing."
            : "Historians' verdict: \(g.lowercased()). \(s.companyName) left behind \(s.achievements.count) achievement\(s.achievements.count == 1 ? "" : "s"), \(Fmt.money(s.lifetimeRevenue)) of lifetime revenue and \(Fmt.flops(s.lifetimeFLOPs)) FLOPs of computing.")
        return out
    }

    /// The people of the story and what became of them (founding team, the strongest staff), with a fate each.
    static func people(_ s: GameState, _ k: EndingKind) -> [(name: String, role: String, fate: String)] {
        let founding = s.employees.filter { $0.hired == s.startDate }
        let stars = s.employees.filter { $0.hired != s.startDate }.sorted { $0.skill != $1.skill ? $0.skill > $1.skill : $0.name < $1.name }.prefix(4)
        let fates: [String] = k.mood > 0
            ? ["now runs a research institute named after the lab", "joined the treaty secretariat's testing division", "funds young labs from the proceeds", "still leads the team that trains the flagship", "wrote the textbook everyone learns alignment from", "chairs the lab's safety board", "retired rich and coaches a school robotics team"]
            : k.mood < 0
            ? ["founded a smaller, more careful lab", "teaches a course on what went wrong", "joined a rival and never talks about it", "left AI for climate tech", "testified to the inquiry", "went back to academia", "builds open-source safety tools"]
            : ["stayed on under the new owners", "started a company of their own", "took a long sabbatical, then came back to research", "joined a frontier lab across town", "advises governments on AI policy", "went back to academia", "runs the old team inside the new owner"]
        let start = Int(RivalIntel.unit("fates|\(s.lifecycleSalt)") * Double(fates.count)) % fates.count
        var out: [(String, String, String)] = []
        let founder: String = switch k {
        case .alignedAGI, .treaty, .guardian, .xeno: "became the face of a generation of AI founders"
        case .averted: "testified, then went back to teaching"
        case .giant: "chairs the board and rings the bell every anniversary"
        case .empire: "is among the richest people alive"
        case .publicService: "advises public AI institutions and lectures on democratic stewardship"
        case .acquired: "took a year off, then started backing young founders"
        case .nationalised: "sits on the national lab's advisory board"
        case .outcompeted: "started over, with better timing in mind"
        case .retired: "mentors founders in the mornings and sails in the afternoons"
        case .steppedDown: "kept the shares and a seat on the board"
        case .ousted: "kept a seat on the board for a year, then left"
        case .bankrupt: "started over, more carefully"
        case .lossOfControl: "testified to the inquiry for three years running"
        }
        out.append((s.founderName, "Founder", founder))
        for e in founding + Array(stars) {
            // Start somewhere fixed for this game and walk the list, so nobody shares a fate until it wraps.
            let i = (start + out.count - 1) % fates.count
            out.append((e.name, e.role.title, fates[i]))
        }
        return out
    }

    // MARK: Endings in reach (Legacy screen)

    struct Reach: Identifiable {
        var id: String { kind.rawValue }
        let kind: EndingKind
        /// 0…1, or nil when it can't be measured (it happens to you, or it's a choice).
        let progress: Double?
        let status: String
    }

    static func reach(_ s: GameState) -> [Reach] {
        let t = s.endings.treaty
        let treatyStatus: String = switch t.stage {
        case 0: s.year < 2026.5 ? "Talks open from mid-2026 if worry about AI runs high, 2028 at the latest." : "Talks open once worry about AI passes 50 (now \(Int(s.world.concern))) or in 2028."
        case 1: t.stance > 0 ? "In the talks with the safety coalition: \(Fmt.pct(t.share, decimals: 0)) of the weight (40% shapes the text)." : t.invited ? "You have a seat; join the safety coalition to shape it." : "Talks under way; a top-ten model gets you a seat."
        default: t.shaped && t.stance > 0 ? "Signed with your clauses — retire to claim it." : "The Compact was signed without your clauses."
        }
        let state: String = s.endings.goldenShare ? "You gave the state a golden share; the pressure is off." : Progression.has(s, .frontierLab) ? "State pressure \(Int(s.endings.friction))/100 (a golden share is asked at 55, emergency powers at 75)." : "Only frontier labs feel state pressure."
        let outYears = max(0, 3 - (s.year - s.startDate.decimalYear))
        let all: [Reach] = [
            Reach(kind: .alignedAGI, progress: s.victories.contains("superintelligence") ? 1 : Victory.progress(.superintelligence, s), status: VictoryPath.superintelligence.goal),
            Reach(kind: .treaty, progress: t.stage == 0 ? 0 : t.shaped && t.stance > 0 ? 1 : (t.stance > 0 ? min(1, t.share / shapeShare) : 0), status: treatyStatus),
            Reach(kind: .guardian, progress: s.victories.contains("guardian") ? 1 : Victory.progress(.guardian, s), status: VictoryPath.guardian.goal),
            Reach(kind: .publicService, progress: Victory.progress(.publicService, s), status: VictoryPath.publicService.goal),
            Reach(kind: .giant, progress: s.isPublic ? min(1, (Double(min(12, s.monthsAtTop)) / 12 + min(1, s.valuation / (1e12 * Victory.empireScale(s.year)))) / 2) : 0,
                  status: s.isPublic ? "#1 for \(s.monthsAtTop)/12 months · \(Fmt.money(s.valuation)) of \(Fmt.money(1e12 * Victory.empireScale(s.year)))." : "Go public first."),
            Reach(kind: .empire, progress: max(Victory.progress(.empire, s), Victory.progress(.dominance, s)), status: VictoryPath.empire.goal),
            Reach(kind: .xeno, progress: Victory.progress(.xeno, s), status: VictoryPath.xeno.goal),
            Reach(kind: .averted, progress: s.endings.nearMisses.isEmpty ? 0 : 1,
                  status: s.endings.nearMisses.isEmpty ? "No near misses yet (and may it stay that way)." : "\(s.endings.nearMisses.count) near miss\(s.endings.nearMisses.count == 1 ? "" : "es") survived\(s.endings.avertedOffers >= 2 ? "; the moment to step back has passed" : "").") ,
            Reach(kind: .nationalised, progress: Progression.has(s, .frontierLab) && !s.endings.goldenShare ? s.endings.friction / 75 : 0, status: state),
            Reach(kind: .outcompeted, progress: Double(s.endings.irrelevant) / 18,
                  status: outYears > 0 ? "Not before year three." : s.endings.irrelevant == 0 ? "You're still in the race." : "\(s.endings.irrelevant)/18 months out of the race."),
            Reach(kind: .retired, progress: min(1, Double(GameCalendar.daysBetween(s.startDate, s.date)) / Double(minDaysToRetire)), status: "Retiring now would give: \(retirement(s).title)."),
        ]
        return all.filter { reach in
            if s.isPublicProgram {
                return ![EndingKind.giant, .empire, .nationalised, .outcompeted].contains(reach.kind)
            }
            return reach.kind != .publicService
        }
    }
}
