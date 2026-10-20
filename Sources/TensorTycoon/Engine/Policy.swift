import Foundation

/// Lobbying and legislation: spend to build political capital, take sides on AI bills, and live with the laws
/// that pass.
enum Policy {
    static func passChance(_ bill: PolicyCatalog.Bill, stance: Int, _ s: GameState) -> Double {
        clamp(bill.basePass + Double(stance) * (0.08 + s.politicalCapital / 250), 0.05, 0.95)
    }

    /// Multiplier on fines, settlements and penalties from traits, laws and political capital.
    static func fineFactor(_ s: GameState) -> Double {
        var f = 1 - s.traits.fines
        if s.lawsPassed.contains("preemption") { f *= 0.7 }
        if s.lawsFailed.contains("preemption") { f *= 1.15 }
        if s.lawsPassed.contains("liability") { f *= 1.2 }
        return max(0.05, f * (1 - s.politicalCapital / 300))
    }

    /// How long building takes at a location under US federal law (permitting reform, a datacenter moratorium). US laws
    /// only reach US soil: elsewhere it's 1, and local grid queues and national energy policy decide (3.4 overhaul).
    static func buildFactor(_ s: GameState, location: String) -> Double {
        guard Region.of(location: location) == .us else { return 1 }
        let permits = s.lawsPassed.contains("permitting") ? 0.75 : (s.lawsFailed.contains("permitting") ? 1.1 : 1)
        return permits * (s.lawsPassed.contains("dc_moratorium") ? 1.35 : 1)
    }

    /// Whether you count as a frontier developer (a model trained above 10^26 FLOP).
    static func isFrontierDeveloper(_ s: GameState) -> Bool {
        s.models.contains { $0.c >= 5 }
    }

    /// Whether US federal AI law reaches you: a US headquarters, or datacenters on US soil (3.4 overhaul). The EU AI
    /// Act is different: it applies to any model sold in the EU, wherever it was trained.
    static func usPresence(_ s: GameState) -> Bool {
        HQ.region(s) == .us || s.sites.contains { ($0.kind == .datacenter || $0.kind == .colo) && Region.of(location: $0.locationID) == .us }
    }

    /// Whether a training run falls under US federal rules: a US headquarters, or most of its chips in US datacenters
    /// (rented cloud capacity counts where the provider's customer is, not where the racks are).
    static func runUnderUSLaw(_ s: GameState, accelID: String, chips: Int) -> Bool {
        if HQ.region(s) == .us { return true }
        let usSites = Set(s.sites.filter { Region.of(location: $0.locationID) == .us }.map(\.id))
        let onUSSoil = s.owned.filter { $0.accelID == accelID && usSites.contains($0.siteID) }.reduce(0) { $0 + $1.count }
        return onUSSoil * 2 >= chips
    }

    static func monthly(_ s: inout GameState) {
        if s.lobbyBudget > 0 {
            s.cash -= s.lobbyBudget
            s.month.costOther += s.lobbyBudget
        }
        let gain = s.lobbyBudget > 0 ? 2.5 * log10(1 + s.lobbyBudget / 50_000) * Progression.lobbyFactor(s) : 0   // 3.7: policy office
        s.politicalCapital = clamp(s.politicalCapital * Progression.capitalRetention(s) + gain, 0, 100)

        // Votes
        let today = s.date
        for bill in s.bills where bill.vote <= today { vote(&s, bill) }
        s.bills.removeAll { $0.vote <= today }

        // Agent registry fees
        if s.lawsPassed.contains("agent_registry") {
            let big = s.swarms.filter { !$0.paused && $0.active > 100_000 }.reduce(0) { $0 + $1.active }
            if big > 0 {
                let fee = big * 2
                s.cash -= fee
                s.month.costOther += fee
            }
        }

        // On-site auditors (US federal law: labs based or building in the US)
        if s.lawsPassed.contains("independent_auditors") && isFrontierDeveloper(s) && usPresence(s) {
            s.cash -= 1e6
            s.month.costOther += 1e6
        }

        // New bills
        guard s.bills.count < 2, s.decisions.count < 2, s.rng.chance(0.12) else { return }
        let pending = Set(s.bills.map(\.id))
        let open = PolicyCatalog.all.filter {
            s.year >= $0.earliest && !s.lawsPassed.contains($0.id) && !s.lawsFailed.contains($0.id) && !pending.contains($0.id)
        }
        guard let bill = open.randomElement(using: &s.rng) else { return }
        introduce(&s, bill)
    }

    /// Put a bill before Congress and ask where you stand. A rival lab may be behind it.
    static func introduce(_ s: inout GameState, _ bill: PolicyCatalog.Bill, sponsor: String = "", boost: Double = 0) {
        var pb = PolicyBill(id: bill.id, proposed: s.date, vote: GameCalendar.addDays(s.date, 120))
        pb.sponsor = sponsor
        pb.boost = boost
        s.bills.append(pb)
        let base = clamp(bill.basePass + boost, 0.05, 0.95)
        let backer = sponsor.isEmpty ? "" : " \(sponsor)'s lobbyists wrote much of it."
        Events.addDecision(&s, kind: "policy_bill", title: "Bill introduced: \(bill.title)",
                           body: "\(bill.summary)\(backer) If it passes: \(bill.ifPasses) If it fails: \(bill.ifFails) Vote in about four months; it has a \(Int(base * 100))% chance on its own.",
                           image: "stock_exchange",
                           options: [DecisionOption(label: "Back it publicly", detail: "Pass chance → \(Int(clamp(passChance(bill, stance: 1, s) + boost, 0.05, 0.95) * 100))%. \(bill.popularity >= 0 ? "Popular" : "Unpopular") with the public\(bill.safetyBill ? "; safety advocates cheer" : "")."),
                                     DecisionOption(label: "Lobby against it", detail: "Pass chance → \(Int(clamp(passChance(bill, stance: -1, s) + boost, 0.05, 0.95) * 100))%. \(bill.popularity >= 0 ? "Bad optics" : "Popular with the industry")."),
                                     DecisionOption(label: "Stay out of it", detail: "No cost, no influence.")],
                           ref: bill.id)
        if !sponsor.isEmpty {
            Sim.news(&s, "\(sponsor) is behind the \(bill.title)", "Its lobbyists helped write the bill. \(bill.summary)", .policy, image: "stock_exchange")
        }
    }

    static func resolve(_ s: inout GameState, _ d: Decision, option: Int) {
        guard let bill = PolicyCatalog.byID[d.ref], let i = s.bills.firstIndex(where: { $0.id == d.ref }) else { return }
        switch option {
        case 0:
            s.bills[i].stance = 1
            s.brand = clamp(s.brand + bill.popularity * 3, 0, 100)
            if bill.safetyBill { s.safetyScore = min(100, s.safetyScore + 2) }
            s.politicalCapital = max(0, s.politicalCapital - 5)
        case 1:
            s.bills[i].stance = -1
            s.brand = clamp(s.brand - bill.popularity * 3, 0, 100)
            if bill.safetyBill { s.safetyScore = max(0, s.safetyScore - 2) }
            s.politicalCapital = max(0, s.politicalCapital - 5)
        default:
            break
        }
    }

    /// Take a side on a pending bill from the policy page (or change it). Taking a side costs 5 political capital and
    /// moves brand and safety like the decision does; stepping back costs 2; switching sides also costs 3 brand.
    static func setStance(_ s: inout GameState, _ id: String, _ stance: Int) -> String? {
        guard let bill = PolicyCatalog.byID[id], let i = s.bills.firstIndex(where: { $0.id == id }) else { return "That bill isn't pending." }
        let old = s.bills[i].stance
        let new = max(-1, min(1, stance))
        guard new != old else { return nil }
        if old != 0 {
            // Undo the old side's effect on brand and safety.
            s.brand = clamp(s.brand - Double(old) * bill.popularity * 3, 0, 100)
            if bill.safetyBill { s.safetyScore = clamp(s.safetyScore - Double(old) * 2, 0, 100) }
        }
        if new != 0 {
            s.brand = clamp(s.brand + Double(new) * bill.popularity * 3, 0, 100)
            if bill.safetyBill { s.safetyScore = clamp(s.safetyScore + Double(new) * 2, 0, 100) }
        }
        s.politicalCapital = max(0, s.politicalCapital - (new == 0 ? 2 : 5))
        if old != 0 && new != 0 { s.brand = max(0, s.brand - 3) }
        s.bills[i].stance = new
        // The bill's decision, if it's still waiting, is answered.
        s.decisions.removeAll { $0.kind == "policy_bill" && $0.ref == id }
        Stakeholders.tookSide(&s, id, stance: new, was: old)   // 3.4: world and stakeholders
        return nil
    }

    static func vote(_ s: inout GameState, _ b: PolicyBill) {
        guard let bill = PolicyCatalog.byID[b.id] else { return }
        let passed = s.rng.chance(clamp(passChance(bill, stance: b.stance, s) + b.boost, 0.05, 0.95))
        if passed { s.lawsPassed.insert(bill.id) } else { s.lawsFailed.insert(bill.id) }
        let won = b.stance != 0 && (b.stance > 0) == passed
        if won {
            s.politicalCapital = min(100, s.politicalCapital + 6)
            s.firedEvents.insert("policy_win_\(bill.id)")
            if s.firedEvents.filter({ $0.hasPrefix("policy_win_") }).count >= 3 { Achievements.unlock(&s, "kingmaker") }
        }
        switch (bill.id, passed) {
        case ("chip_security", true):
            s.market.exportControls = true
            s.market.hardwarePrice += 0.03
        case ("copyright", true): s.market.copyrightHeat += 0.5
        case ("copyright", false): s.market.copyrightHeat = max(0.3, s.market.copyrightHeat - 0.3)
        case ("nairr", true): s.market.hype += 0.05
        case ("preemption", true): s.market.hype += 0.05
        case ("independent_auditors", true): s.safetyScore = min(100, s.safetyScore + 3)
        case ("kill_switch", true) where isFrontierDeveloper(s) && usPresence(s):
            s.cash -= 5e7
            s.month.costOther += 5e7
        default: break
        }
        let side = b.stance == 0 ? "" : (won ? " You backed the winning side." : " You were on the losing side.")
        Voices.billVote(&s, bill, passed: passed, sponsor: b.sponsor, title: "\(bill.title) \(passed ? "passes" : "fails")",
                        body: "\(passed ? bill.ifPasses : bill.ifFails)\(side)", good: won ? true : nil)
    }
}

extension GameState {
    mutating func setLobbyBudget(_ monthly: Double) {
        lobbyBudget = max(0, monthly)
    }
}
