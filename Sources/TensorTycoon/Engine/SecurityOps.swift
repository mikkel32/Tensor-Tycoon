import Foundation

/// Weight security: attackers go after your best weights in proportion to how valuable they are. Each security
/// level stops one more class of attacker (RAND SL1–SL5) and costs more to build, run and work behind.
enum SecurityOps {
    /// Bigger companies have more people, sites and attack surface to secure.
    static func sizeFactor(_ s: GameState) -> Double {
        clamp(Double(s.employees.count) / 40 + Double(s.sites.filter { $0.kind != .garage }.count) * 0.3, 0.5, 30)
    }

    static func discount(_ s: GameState) -> Double { min(0.6, s.bonuses.securityCost) }

    static func upgradeCost(_ to: SecurityLevel, _ s: GameState) -> Double {
        to.upgradeCost * sizeFactor(s) * (1 - discount(s))
    }

    static func upkeep(_ level: SecurityLevel, _ s: GameState) -> Double {
        level.upkeep * sizeFactor(s) * (1 - discount(s))
    }

    /// How badly attackers want your weights: 0 when you're far behind, ~2 when you lead the world.
    static func attractiveness(_ s: GameState) -> Double {
        guard let best = s.models.filter({ !$0.retired }).map(\.c).max() else { return 0 }
        return clamp(best - Macro.frontier(s.year) + 1.2, 0, 2.2)
    }

    struct Threat: Identifiable {
        var id: Int { tier }
        var tier: Int
        var who: String
        var monthlyChance: Double
    }

    static func threats(_ s: GameState) -> [Threat] {
        let a = attractiveness(s)
        let y = s.year
        // A post-incident lockdown takes the extra insider risk of a big company off the table.
        let insiders = s.employees.count > 50 && !s.firedEvents.contains("insider_lockdown") ? 1.5 : 1
        return [
            Threat(tier: 2, who: "Opportunistic hackers", monthlyChance: 0.06 * a),
            Threat(tier: 3, who: "Cybercrime groups & insiders", monthlyChance: 0.045 * a * insiders),
            Threat(tier: 4, who: "State-backed cyber units", monthlyChance: y >= 2023 ? 0.04 * pow(a, 1.5) : 0),
            Threat(tier: 5, who: "Top-priority nation-state operations", monthlyChance: y >= 2025 && a >= 1.0 ? 0.02 * pow(a, 2) : 0),
        ]
    }

    /// Chance an escaping model or swarm gets out, scaled by your containment.
    static func containmentFactor(_ s: GameState) -> Double {
        [1.0, 1.0, 0.85, 0.6, 0.35][s.security.rawValue - 1] * (s.researched.contains("eval_containment") ? 0.7 : 1)
            * (s.lawsPassed.contains("kill_switch") ? 0.75 : 1)
    }

    // MARK: Daily / monthly

    static func daily(_ s: inout GameState) {
        guard s.securityTarget > s.security.rawValue else { return }
        s.securityDaysLeft -= 1
        guard s.securityDaysLeft <= 0 else { return }
        s.securityRaw = s.securityTarget
        s.securityDaysLeft = 0
        let level = s.security
        if level >= .sl4 { Achievements.unlock(&s, "fort_knox") }
        Sim.news(&s, "Security upgraded to \(level.title)", "Your weights are now protected against \(level.stops.lowercased()).",
                 .company, image: "network", good: true)
    }

    static func monthly(_ s: inout GameState) {
        let cost = upkeep(s.security, s)
        if cost > 0 {
            s.cash -= cost
            s.month.costOther += cost
        }
        guard s.models.contains(where: { !$0.retired }) else { return }
        for t in threats(s) where t.monthlyChance > 0 && s.rng.chance(t.monthlyChance) {
            // A level well above the attacker's class almost never fails.
            let margin = s.security.rawValue - t.tier
            if margin >= 0 && s.rng.chance(min(0.995, 0.95 + 0.015 * Double(margin))) {
                s.attacksFoiled += 1
                if t.tier >= 3 {
                    s.safetyScore = min(100, s.safetyScore + 1)
                    Sim.news(&s, "Attack on your weights foiled", "\(t.who) tried to steal your model weights. Your \(s.security.title) defences held.",
                             .company, image: "network", good: true)
                }
            } else if s.rng.chance(0.75 * (1 - 0.6 * s.swarmSecurity)) {
                theft(&s, tier: t.tier, who: t.who)
                return
            }
        }
    }

    static func theft(_ s: inout GameState, tier: Int, who: String) {
        guard let m = s.models.filter({ !$0.retired }).max(by: { $0.c < $1.c }) else { return }
        s.thefts += 1
        s.boardConfidence = max(0, s.boardConfidence - 10)
        if tier <= 3 {
            // Criminals leak or sell the weights: copies everywhere.
            s.market.apiPricePressure = max(0.4, s.market.apiPricePressure - 0.08)
            s.brand = max(0, s.brand - 8)
            Sim.news(&s, "\(m.name) weights leaked online", "\(who) got the weights out and posted them. Free copies undercut your API; brand −8.",
                     .company, image: "network", important: true, good: false)
        } else {
            let candidates = s.competitors.filter { !$0.acquired && s.year >= $0.def.founded.decimal }
            let lab = candidates.first { $0.id == "dragonlake" } ?? candidates.randomElement(using: &s.rng)
            if let lab { s.stolenC[lab.id] = max(s.stolenC[lab.id] ?? -10, m.c - 0.05) }
            s.brand = max(0, s.brand - 6)
            s.safetyScore = max(0, s.safetyScore - 5)
            var body = "\(who) exfiltrated \(m.name). Expect a suspiciously similar model from \(lab?.def.name ?? "a state-backed lab") soon."
            if SafetyFramework.tier(m) >= .high {
                let fine = max(1e7, Economy.runRate(s) * 0.05) * Policy.fineFactor(s)
                s.cash -= fine
                s.month.costOther += fine
                body += " Losing a model above the High capability line cost \(Fmt.money(fine)) in penalties."
            }
            Sim.news(&s, "State hackers steal \(m.name)", body, .policy, image: "network", important: true, good: false)
        }
    }
}

extension GameState {
    mutating func upgradeSecurity() -> String? {
        if securityTarget > security.rawValue { return "An upgrade to SL\(securityTarget) is already under way." }
        guard let next = SecurityLevel(rawValue: security.rawValue + 1) else { return "You're already at SL5." }
        if next == .sl5 && year < 2026 { return "Nobody can build SL5 yet — the techniques don't exist before 2026." }
        if next == .sl5 && year < 2028 && politicalCapital < 40 {
            return "RAND judges SL5 \"currently not possible\" without help from the national-security community. Build political capital to 40 for a government partnership, or wait until 2028."
        }
        let cost = SecurityOps.upgradeCost(next, self)
        if cost > cash { return "Reaching \(next.title) costs \(Fmt.money(cost))." }
        cash -= cost
        month.capex += cost
        securityRaw = security.rawValue
        securityTarget = next.rawValue
        securityDaysLeft = Double(next.upgradeMonths) * 30.4
        Sim.news(&self, "Security programme: \(next.title)", "\(Fmt.money(cost)), about \(next.upgradeMonths) months. \(next.measures)", .company, image: "network")
        return nil
    }

    mutating func downgradeSecurity() -> String? {
        guard security.rawValue > 1 else { return "You're at the minimum." }
        securityRaw = security.rawValue - 1
        securityTarget = securityRaw
        securityDaysLeft = 0
        Sim.news(&self, "Security relaxed to \(security.title)", "Cheaper and faster to work — and easier to rob.", .company, good: false)
        return nil
    }
}
