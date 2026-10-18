import Foundation

enum MoonshotStatus: String, Codable, Sendable {
    case offered, running, succeeded, failed, declined, rival
}

/// A moonshot your lab was offered, and what became of it.
struct Moonshot: Codable, Identifiable, Hashable {
    var id: String
    var status: MoonshotStatus
    var offered: Date
    var started: Date? = nil
    var ends: Date? = nil
    var cost: Double = 0
    var partnered = false
    /// Research points put in so far, and what the plan called for.
    var rpInvested: Double = 0
    var rpTarget: Double = 0
    /// Odds quoted at launch.
    var chance: Double = 0
    var royaltyMonthly: Double = 0
    var royaltyMonthsLeft: Int = 0
    /// A rival lab that takes it on after you pass, and when they succeed.
    var rivalID: String = ""
    var rivalDate: Date? = nil

    var def: MoonshotDef? { MoonshotCatalog.byID[id] }
}

/// 3.4: moonshots — the late-game system. From 2028, foundations, governments and industry consortia bring grand
/// challenges to frontier labs. Taking one on costs cash up front and a share of your research for one to three years;
/// success pays royalties for a decade, raises brand and political capital and leaves permanent research effects.
/// Each offer is a decision: fund it alone, share it with a national lab, or pass and maybe watch a rival do it.
enum Moonshots {
    static let opens = 2028.0
    static let maxRunning = 2
    static let royaltyMonths = 120
    static let kind = "moonshot"
    static let bonusPrefix = "moon:"

    // MARK: Odds, costs and rewards

    static func cost(_ d: MoonshotDef, _ s: GameState) -> Double {
        (max(2e9, Macro.frontierValuation(s.year) * d.costShare) / 1e8).rounded() * 1e8
    }

    /// Your best released model against the frontier, as a multiplier on the odds.
    static func capabilityFactor(_ s: GameState) -> Double {
        let best = s.releasedModels.map(\.c).max() ?? -10
        return clamp(1 + 0.5 * (best - Macro.frontier(s.year) + 0.3), 0.3, 1.2)
    }

    /// AI-for-science research makes every moonshot likelier.
    static func scienceFactor(_ s: GameState) -> Double {
        let n = ResearchCatalog.all.filter { $0.category == .science && s.researched.contains($0.id) }.count
        return 1 + min(0.15, 0.03 * Double(n)) + AgentOrgs.moonshotOdds(s)   // 3.6: discovery institutes
    }

    static func safetyFactor(_ d: MoonshotDef, _ s: GameState) -> Double {
        guard d.minSafety > 0 else { return 1 }
        return clamp(1 - (d.minSafety - s.safetyScore) / 40, 0.5, 1)
    }

    /// Odds of success if you start now and put in the planned research.
    static func chance(_ d: MoonshotDef, _ s: GameState, partnered: Bool) -> Double {
        clamp(d.baseChance * capabilityFactor(s) * scienceFactor(s) * safetyFactor(d, s) * (partnered ? 1.1 : 1) * Science.moonshotFactor(d.id, s), 0.05, 0.95)   // 3.6
    }

    static func royalty(_ d: MoonshotDef, _ s: GameState, partnered: Bool) -> Double {
        d.royaltyShare * Macro.marketSize(s.year) / 12 * (partnered ? 0.5 : 1)
    }

    // MARK: Research

    /// Share of research points the running moonshots take (never more than half). Zero when none are running.
    static func researchShare(_ s: GameState) -> Double {
        var share = 0.0
        for m in s.moonshots where m.status == .running { share += m.def?.researchShare ?? 0 }
        return min(0.5, share)
    }

    static func invest(_ s: inout GameState, _ rp: Double) {
        var total = 0.0
        for m in s.moonshots where m.status == .running { total += m.def?.researchShare ?? 0 }
        guard total > 0 else { return }
        for i in s.moonshots.indices where s.moonshots[i].status == .running {
            s.moonshots[i].rpInvested += rp * (s.moonshots[i].def?.researchShare ?? 0) / total
        }
    }

    // MARK: Bonuses

    static func bonusID(_ id: String) -> String { bonusPrefix + id }

    static var virtualItems: [ResearchItem] {
        MoonshotCatalog.all.map {
            ResearchItem(id: bonusID($0.id), name: $0.name, category: .science, year: 0, cost: 0, prereqs: [], effects: $0.effects, blurb: $0.blurb)
        }
    }

    /// Finished moonshots carry their effects: in full on success, a quarter on failure (what you learned trying).
    static func bonusSources(_ s: GameState) -> [(String, Double)] {
        s.moonshots.compactMap { m -> (String, Double)? in
            switch m.status {
            case .succeeded: return (bonusID(m.id), 1)
            case .failed: return (bonusID(m.id), 0.25)
            default: return nil
            }
        }
    }

    // MARK: Monthly

    static func monthly(_ s: inout GameState) {
        guard s.year >= opens else { return }
        payRoyalties(&s)
        finish(&s)
        rivalNews(&s)
        offer(&s)
    }

    static func payRoyalties(_ s: inout GameState) {
        for i in s.moonshots.indices where s.moonshots[i].status == .succeeded && s.moonshots[i].royaltyMonthsLeft > 0 {
            let r = s.moonshots[i].royaltyMonthly
            s.cash += r
            s.month.revLicensing += r
            s.lifetimeRevenue += r
            s.moonshots[i].royaltyMonthsLeft -= 1
        }
    }

    static func finish(_ s: inout GameState) {
        for i in s.moonshots.indices where s.moonshots[i].status == .running {
            guard let end = s.moonshots[i].ends, end <= s.date, let d = s.moonshots[i].def else { continue }
            let m = s.moonshots[i]
            // Falling short of the planned research hurts the odds; putting in more helps a little.
            let effort = clamp(m.rpTarget > 0 ? m.rpInvested / m.rpTarget : 1, 0.25, 1.5)
            let odds = clamp(chance(d, s, partnered: m.partnered) * pow(effort, 0.5), 0.03, 0.97)
            if s.rng.chance(odds) {
                let perMonth = royalty(d, s, partnered: m.partnered)
                s.moonshots[i].status = .succeeded
                s.moonshots[i].royaltyMonthly = perMonth
                s.moonshots[i].royaltyMonthsLeft = perMonth > 0 ? royaltyMonths : 0
                s.brand = min(100, s.brand + d.brand * (m.partnered ? 0.7 : 1))
                s.politicalCapital = min(100, s.politicalCapital + d.political + (m.partnered ? 8 : 0))
                var body = "After \(d.months) months, \(m.partnered ? "you and your national-lab partners have" : "your team has") done it."
                if perMonth > 0 { body += " Royalties of about \(Fmt.money(perMonth * 12)) a year start now, for ten years." }
                body += " " + d.effects.prefix(3).map { ResearchCatalog.describe($0) }.joined(separator: " · ") + "."
                Sim.news(&s, "Moonshot achieved: \(d.name)", body, .research, image: d.image ?? "supercomputer", important: true, good: true)
            } else {
                s.moonshots[i].status = .failed
                if !m.partnered { s.brand = max(0, s.brand - 2) }
                Sim.news(&s, "Moonshot falls short: \(d.name)",
                         "The \(d.field.lowercased()) programme ends without the breakthrough (the odds were \(Int((odds * 100).rounded()))%). What the team learned still counts: a quarter of the hoped-for research effects stay with you.",
                         .research, image: d.image, important: true, good: false)
            }
        }
    }

    static func rivalNews(_ s: inout GameState) {
        for i in s.moonshots.indices where s.moonshots[i].status == .declined && !s.moonshots[i].rivalID.isEmpty {
            guard let when = s.moonshots[i].rivalDate, when <= s.date, let d = s.moonshots[i].def else { continue }
            s.moonshots[i].status = .rival
            let lab = s.competitors.first { $0.id == s.moonshots[i].rivalID && !$0.acquired && !$0.bankrupt }?.def.name ?? "A research consortium"
            s.market.hype = min(3, s.market.hype + 0.02)
            Sim.news(&s, "\(lab) cracks \(d.name)", "The moonshot you passed on has been done by someone else. Their reputation soars, and so does the market's appetite for AI.",
                     .competitor, image: d.image, important: true, good: false)
        }
    }

    /// Now and then, a new grand challenge comes looking for a frontier lab.
    static func offer(_ s: inout GameState) {
        guard !s.moonshots.contains(where: { $0.status == .offered }),
              s.moonshots.filter({ $0.status == .running }).count < maxRunning,
              let best = s.releasedModels.map(\.c).max(), best >= Macro.frontier(s.year) - 1.2 else { return }
        let taken = Set(s.moonshots.map(\.id))
        let eligible = MoonshotCatalog.all.filter {
            $0.year <= s.year && !taken.contains($0.id) && s.researched.contains($0.prereq) && s.safetyScore >= $0.minSafety - 15
        }
        guard !eligible.isEmpty, s.rng.chance(0.15) else { return }
        let d = s.rng.pick(eligible)
        let price = cost(d, s)
        // Backers only pitch labs that could at least afford the shared version.
        guard s.cash + Economy.runRate(s) / 2 >= price / 2 else { return }
        let solo = chance(d, s, partnered: false)
        let shared = chance(d, s, partnered: true)
        let perYear = royalty(d, s, partnered: false) * 12
        let payoff = perYear > 1e6 ? "royalties of about \(Fmt.money(perYear)) a year for ten years" : "prestige rather than royalties"
        s.moonshots.append(Moonshot(id: d.id, status: .offered, offered: s.date))
        Events.addDecision(&s, kind: kind, title: "Moonshot: \(d.name)",
                           body: "\(d.blurb) It would take about \(d.months) months and \(Int((d.researchShare * 100).rounded()))% of your research while it runs. If it works: \(d.reward)",
                           image: d.image ?? "supercomputer",
                           options: [DecisionOption(label: "Fund it alone", detail: "\(Fmt.money(price)) up front · \(Int((solo * 100).rounded()))% chance · \(payoff)."),
                                     DecisionOption(label: "Partner with a national lab", detail: "\(Fmt.money(price / 2)) · \(Int((shared * 100).rounded()))% chance · half the royalties, more political capital."),
                                     DecisionOption(label: "Pass", detail: "A rival lab may take it on instead.")],
                           amount: price, ref: d.id)
    }

    // MARK: Decisions

    static func resolve(_ s: inout GameState, _ dec: Decision, option: Int) {
        guard let d = MoonshotCatalog.byID[dec.ref],
              let i = s.moonshots.firstIndex(where: { $0.id == d.id && $0.status == .offered }) else { return }
        guard option < 2 else { decline(&s, i); return }
        let partnered = option == 1
        let price = dec.amount * (partnered ? 0.5 : 1)
        guard s.cash >= price else {
            Sim.news(&s, "Couldn't fund \(d.name)", "The moonshot needed \(Fmt.money(price)) up front, which you don't have. The backers move on.", .company, good: false)
            decline(&s, i)
            return
        }
        s.cash -= price
        s.month.costOther += price
        s.moonshots[i].status = .running
        s.moonshots[i].started = s.date
        s.moonshots[i].ends = GameCalendar.addMonths(s.date, d.months)
        s.moonshots[i].cost = price
        s.moonshots[i].partnered = partnered
        s.moonshots[i].chance = chance(d, s, partnered: partnered)
        s.moonshots[i].rpTarget = d.researchShare * max(1, s.rpToday) * Double(d.months) * 30.4
        if partnered { s.politicalCapital = min(100, s.politicalCapital + 4) }
        Sim.news(&s, "Moonshot launched: \(d.name)",
                 "\(partnered ? "Together with a national lab, you" : "You") commit \(Fmt.money(price)) and \(Int((d.researchShare * 100).rounded()))% of your research for \(d.months) months. Odds today: \(Int((s.moonshots[i].chance * 100).rounded()))% — better models and more research raise them.",
                 .research, image: d.image ?? "supercomputer", important: true, good: true)
    }

    static func decline(_ s: inout GameState, _ i: Int) {
        s.moonshots[i].status = .declined
        let y = s.year
        let labs = s.competitors.filter { !$0.acquired && !$0.bankrupt && y >= $0.def.founded.decimal }
        if !labs.isEmpty, s.rng.chance(0.5) {
            s.moonshots[i].rivalID = s.rng.pick(labs).id
            s.moonshots[i].rivalDate = GameCalendar.addMonths(s.date, s.rng.int(12, 30))
        }
    }

    // MARK: Summary

    /// One line on where a moonshot stands, for the Research page.
    static func statusLine(_ m: Moonshot, _ s: GameState) -> String {
        switch m.status {
        case .offered: return "Offered — waiting for your answer in the inbox."
        case .running:
            let months = m.ends.map { max(0, GameCalendar.daysBetween(s.date, $0)) / 30 } ?? 0
            let effort = m.rpTarget > 0 ? m.rpInvested / m.rpTarget : 0
            return "Running\(m.partnered ? " with a national lab" : "") · \(months) months left · \(Int((m.chance * 100).rounded()))% odds at launch · research \(Int((effort * 100).rounded()))% of plan"
        case .succeeded:
            return m.royaltyMonthsLeft > 0 ? "Achieved · \(Fmt.money(m.royaltyMonthly))/month in royalties for \(m.royaltyMonthsLeft) more months" : "Achieved"
        case .failed: return "Fell short · a quarter of its research effects stayed with you"
        case .declined: return "Passed"
        case .rival: return "Passed — a rival did it"
        }
    }

    static func succeeded(_ s: GameState) -> Int { s.moonshots.filter { $0.status == .succeeded }.count }

    static func royaltiesMonthly(_ s: GameState) -> Double {
        s.moonshots.filter { $0.status == .succeeded && $0.royaltyMonthsLeft > 0 }.reduce(0) { $0 + $1.royaltyMonthly }
    }
}
