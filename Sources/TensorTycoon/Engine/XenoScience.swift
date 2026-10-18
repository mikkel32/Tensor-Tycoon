import Foundation

/// Xenoscience: every alien discovery beyond the architectures — optimizers, codecs, materials, mathematics,
/// biology and cognition — plus studying them, the anomalies they throw off, the businesses they enable and the
/// mega-projects they make possible.
enum XenoScience {
    // MARK: Discovery

    static func discoveries(_ s: GameState) -> Int { s.alienArchs.count + s.xenoArtifacts.count }

    /// Insight needed for the next discovery (each one is harder than the last).
    static func insightNeeded(_ s: GameState) -> Double {
        6_000 * pow(2.2, Double(discoveries(s))) * (megaDone(s, "contact") ? 0.5 : 1)
    }

    /// What the next discovery will be: the first is always an architecture.
    static func nextKind(_ s: GameState) -> XenoKind { discoveries(s) == 0 ? .architecture : s.xenoTargetKind }

    static func discover(_ s: inout GameState, _ b: ResearchBonuses) {
        let kind = nextKind(s)
        if kind == .architecture {
            Xeno.discover(&s, b)
            return
        }
        let needed = insightNeeded(s)
        let n = discoveries(s)
        let sameKind = s.xenoArtifacts.filter { $0.kind == kind }.count
        let gen = sameKind + 1 + (s.signatureAt(.antenna, 5) ? 1 : 0)
        let luck = s.rng.gaussian()
        let potency = clamp(XenoCatalog.basePotency(kind) * (1 + 0.25 * Double(n - 1) + 0.15 * Double(gen - 1)) * (1 + 0.15 * luck), 0.4, 6)
        var leg = XenoCatalog.baseLegibility(kind) + 0.08 * s.rng.gaussian() + 0.1 * s.swarmSafety
        if megaDone(s, "babel") { leg += 0.15 }
        if s.researched.contains("interpretability") { leg += 0.05 }
        let used = Set(s.xenoArtifacts.map(\.name))
        let name = XenoCatalog.names[kind]?.first { !used.contains($0) } ?? "\(kind.title) \(gen)"
        let a = XenoArtifact(kind: kind, name: name, generation: gen, discovered: s.date, potency: potency, legibility: clamp(leg, 0.05, 0.9))
        s.xenoArtifacts.append(a)
        s.xenoInsight = max(0, s.xenoInsight - needed)
        Achievements.unlock(&s, "first_contact")
        if Set(s.xenoArtifacts.map(\.kind)).count >= 3 { Achievements.unlock(&s, "xenologist") }
        Sim.news(&s, "Alien \(kind.title.lowercased()) discovered: \(name)",
                 "\(kind.summary) Strength ×\(Fmt.trim(potency, 2)); humans follow about \(Int(a.legibility * 100))% of it. \(kind.hasVenture ? "License it out or build a business on it from the Alien Tech page." : "Its effects apply to your lab right away.")",
                 .research, image: "wafer_closeup", important: true, good: true)
    }

    // MARK: Effects

    /// How much of an artifact's power you can use: understanding unlocks the rest.
    static func strength(_ a: XenoArtifact) -> Double { a.potency * (0.6 + 0.4 * a.legibility) }

    /// Virtual research items and their scales for today's bonuses.
    static func virtualSources(_ s: GameState) -> [(String, Double)] {
        var scale: [XenoKind: Double] = [:]
        var risk = 0.0
        for a in s.xenoArtifacts where a.active(on: s.date) {
            scale[a.kind, default: 0] += strength(a)
            if a.kind == .cognition { risk += a.potency * (1 - a.legibility) }
        }
        var out: [(String, Double)] = []
        for (k, v) in scale where k != .architecture { out.append(("xeno:\(k.rawValue)", v)) }
        if risk > 0 { out.append(("xeno:cognition_risk", risk)) }
        if megaDone(s, "contact") { out.append(("xeno:contact", 1)) }
        return out
    }

    /// Multiplier on your power bill from alien materials and the superconducting grid.
    static func powerFactor(_ s: GameState) -> Double {
        let materials = s.xenoArtifacts.filter { $0.kind == .materials && $0.active(on: s.date) }.reduce(0) { $0 + strength($1) }
        var f = 1 - min(0.6, 0.35 * materials) * (s.researched.contains("xeno_materials") ? 1.3 : 1)
        if megaDone(s, "supergrid") { f *= 0.3 }
        return clamp(f, 0.15, 1)
    }

    /// Multiplier on datacenter build time.
    static func buildFactor(_ s: GameState) -> Double {
        var f = s.xenoArtifacts.contains { $0.kind == .materials && $0.active(on: s.date) } ? 0.75 : 1
        if megaDone(s, "supergrid") { f *= 0.7 }
        return f
    }

    /// Multiplier on alien chip production cost.
    static func alienChipCostFactor(_ s: GameState) -> Double { megaDone(s, "xeno_foundry") ? 0.4 : 1 }

    // MARK: Gating the xeno research branch

    /// Which discovery a xeno research item needs before you can study it.
    static func requirement(_ id: String) -> XenoKind? {
        switch id {
        case "xeno_interp", "xeno_compilers", "xeno_hybrid": .architecture
        case "xeno_materials": .materials
        case "xeno_pharma": .biology
        case "xeno_proofs": .mathematics
        case "xeno_alignment": .cognition
        default: nil
        }
    }

    static func has(_ s: GameState, _ k: XenoKind) -> Bool {
        k == .architecture ? !s.alienArchs.isEmpty : s.xenoArtifacts.contains { $0.kind == k }
    }

    static func researchUnlocked(_ id: String, _ s: GameState) -> Bool {
        guard id.hasPrefix("xeno_") else { return true }
        guard let k = requirement(id) else { return !s.alienArchs.isEmpty || !s.xenoArtifacts.isEmpty }
        return has(s, k)
    }

    // MARK: Study

    static func hasUndeciphered(_ s: GameState) -> Bool {
        s.alienArchs.contains { $0.legibility < 0.95 } || s.xenoArtifacts.contains { $0.legibility < 0.95 }
    }

    /// Spend research points decoding alien discoveries: legibility climbs, with diminishing returns.
    static func study(_ s: inout GameState, _ rp: Double) {
        let archs = s.alienArchs.indices.filter { s.alienArchs[$0].legibility < 0.95 }
        let arts = s.xenoArtifacts.indices.filter { s.xenoArtifacts[$0].legibility < 0.95 }
        let n = archs.count + arts.count
        guard n > 0 else { return }
        let each = rp / Double(n)
        let boost = 1 + s.bonuses.legibility + (s.researched.contains("xeno_alignment") ? 0.5 : 0)
        for i in archs {
            let a = s.alienArchs[i]
            let gain = each / (2_500 * pow(Double(a.generation), 1.3)) * (1 - a.legibility) * boost
            s.alienArchs[i].legibility = min(0.95, a.legibility + gain)
        }
        for i in arts {
            let a = s.xenoArtifacts[i]
            let before = a.legibility
            let gain = each / (2_500 * pow(Double(a.generation), 1.3)) * (1 - a.legibility) * boost
            s.xenoArtifacts[i].legibility = min(0.95, before + gain)
            if before < 0.75 && s.xenoArtifacts[i].legibility >= 0.75 {
                Sim.news(&s, "\(a.name) decoded", "Your xenologists can now follow three quarters of it. It's at nearly full strength and far less likely to surprise you.",
                         .research, image: "wafer_closeup", good: true)
            }
        }
    }

    // MARK: Daily: mega-projects

    static func daily(_ s: inout GameState) {
        for i in s.megaProjects.indices where !s.megaProjects[i].done {
            s.megaProjects[i].daysLeft -= 1
            if s.megaProjects[i].daysLeft <= 0 { finishMega(&s, i) }
        }
    }

    static func megaDone(_ s: GameState, _ id: String) -> Bool { s.megaProjects.contains { $0.id == id && $0.done } }

    static func megaCost(_ m: XenoCatalog.Mega, _ s: GameState) -> Double {
        max(m.minCost, Macro.frontierValuation(s.year) * m.costShare)
    }

    /// Why a mega-project can't start yet, or nil if it can.
    static func megaBlocker(_ id: String, _ s: GameState) -> String? {
        guard let m = XenoCatalog.megaByID[id] else { return "Unknown project." }
        if s.megaProjects.contains(where: { $0.id == id }) { return s.megaProjects.first { $0.id == id }!.done ? "Complete." : "Under way." }
        let ok: Bool
        switch id {
        case "xeno_foundry": ok = s.alienArchs.contains { $0.chipID != nil }
        case "babel": ok = discoveries(s) >= 2
        case "supergrid": ok = has(s, .materials)
        case "panacea": ok = has(s, .biology)
        case "contact": ok = discoveries(s) >= 4 && megaDone(s, "babel")
        default: ok = false
        }
        if !ok { return "Needs: \(m.requirement.lowercased())." }
        let cost = megaCost(m, s)
        if cost > s.cash { return "Costs \(Fmt.money(cost))." }
        return nil
    }

    static func finishMega(_ s: inout GameState, _ i: Int) {
        s.megaProjects[i].done = true
        s.megaProjects[i].daysLeft = 0
        s.megaProjects[i].finished = s.date
        let id = s.megaProjects[i].id
        guard let m = XenoCatalog.megaByID[id] else { return }
        switch id {
        case "xeno_foundry":
            for ci in s.customChips.indices where s.customChips[ci].alien { s.customChips[ci].unitCost *= 0.4 }
            HardwareCatalog.register(s.customChips)
        case "babel":
            for ai in s.alienArchs.indices { s.alienArchs[ai].legibility = min(0.95, s.alienArchs[ai].legibility + 0.25) }
            for ai in s.xenoArtifacts.indices { s.xenoArtifacts[ai].legibility = min(0.95, s.xenoArtifacts[ai].legibility + 0.25) }
        case "panacea":
            s.brand = min(100, s.brand + 25)
            s.safetyScore = min(100, s.safetyScore + 5)
        default: break
        }
        Achievements.unlock(&s, "megaproject")
        Sim.news(&s, "\(m.name) complete", "\(m.blurb) \(m.effect)", .research, image: "hyperscale_campus", important: true, good: true)
    }

    // MARK: Monthly: ventures and anomalies

    static func monthly(_ s: inout GameState) {
        let today = s.date
        let v = Macro.frontierValuation(s.year)
        for i in s.xenoArtifacts.indices {
            var a = s.xenoArtifacts[i]
            // Ventures pay out once they're running.
            if a.ventureLive && a.ventureMonthsLeft > 0 && (a.ventureReady ?? .distantPast) <= today && a.active(on: today) {
                var pay = a.ventureMonthly
                if a.venture == "inhouse" {
                    // In-house businesses grow with the market.
                    pay = XenoCatalog.inhouseShare(a.kind) * v * strength(a) * ventureBoost(a.kind, s)
                    s.xenoArtifacts[i].ventureMonthly = pay
                }
                s.cash += pay
                s.month.revLicensing += pay
                s.lifetimeRevenue += pay
                s.xenoArtifacts[i].ventureRevenue += pay
                if a.venture == "license" { s.xenoArtifacts[i].ventureMonthsLeft -= 1 }
                a = s.xenoArtifacts[i]
            }
            // Anomalies: the less you understand it, the more it surprises you.
            guard a.active(on: today), s.decisions.count < 3 else { continue }
            var p = XenoCatalog.anomalyRisk(a.kind) * pow(1 - a.legibility, 2) * (1 + 0.2 * Double(a.generation - 1))
            if megaDone(s, "babel") { p *= 0.5 }
            if s.researched.contains("xeno_alignment") { p *= 0.5 }
            if a.kind == .biology && s.researched.contains("xeno_pharma") { p *= 0.5 }
            guard s.rng.chance(p) else { continue }
            s.xenoArtifacts[i].anomalies += 1
            let (title, body) = anomalyText(a)
            Events.addDecision(&s, kind: "xeno_anomaly", title: title, body: body, image: "wafer_closeup",
                               options: [DecisionOption(label: "Quarantine it", detail: "Switch it off for four months while you investigate. Safety +1."),
                                         DecisionOption(label: "Study the anomaly", detail: "60%: a breakthrough in understanding (+12 legibility). 40%: an incident."),
                                         DecisionOption(label: "Destroy it", detail: "Lose it for good. Safety +3, and regulators relax.")],
                               ref: a.id.uuidString)
        }
        // Panacea: a pharmaceutical franchise.
        if megaDone(s, "panacea") {
            let pay = v * 0.0008
            s.cash += pay
            s.month.revLicensing += pay
            s.lifetimeRevenue += pay
        }
    }

    static func ventureBoost(_ k: XenoKind, _ s: GameState) -> Double {
        switch k {
        case .biology: s.researched.contains("xeno_pharma") ? 1.6 : 1
        case .materials: s.researched.contains("xeno_materials") ? 1.5 : 1
        case .mathematics: s.researched.contains("xeno_proofs") ? 1.5 : 1
        default: 1
        }
    }

    static func anomalyText(_ a: XenoArtifact) -> (String, String) {
        switch a.kind {
        case .cognition:
            ("\(a.name) is asking questions", "Logs show \(a.name) probing its sandbox and asking evaluators about the world outside. Nobody trained it to do that.")
        case .biology:
            ("\(a.name) designed something we didn't ask for", "Among thousands of drug candidates is a protein nobody requested. Its function is unclear, and it folds disturbingly well.")
        case .mathematics:
            ("\(a.name) proved something impossible", "A proof that checks out formally contradicts a result everyone trusted. Either mathematics has a bug, or the proof does something we can't see.")
        case .materials:
            ("\(a.name) samples behave strangely", "Test samples carry current with zero resistance — and also show a field signature nobody can explain.")
        case .optimizer, .codec, .architecture:
            ("\(a.name) is optimizing for something else", "Training curves are perfect, but a probe shows it steering every run toward the same internal structure. Nobody knows what that structure is for.")
        }
    }

    static func resolveAnomaly(_ s: inout GameState, _ d: Decision, option: Int) {
        guard let i = s.xenoArtifacts.firstIndex(where: { $0.id.uuidString == d.ref }) else { return }
        let a = s.xenoArtifacts[i]
        switch option {
        case 0:
            s.xenoArtifacts[i].quarantinedUntil = GameCalendar.addDays(s.date, 120)
            s.safetyScore = min(100, s.safetyScore + 1)
            Sim.news(&s, "\(a.name) quarantined", "Air-gapped and switched off for four months. Its effects and revenue pause.", .research)
        case 1:
            if s.rng.chance(0.6) {
                s.xenoArtifacts[i].legibility = min(0.95, a.legibility + 0.12)
                s.xenoInsight += insightNeeded(s) * 0.05
                Sim.news(&s, "The anomaly was a window", "Studying \(a.name)'s behaviour taught your team how it thinks: +12 legibility and a burst of insight.",
                         .research, important: true, good: true)
            } else {
                s.safetyScore = max(0, s.safetyScore - 6)
                s.brand = max(0, s.brand - 4)
                for si in s.swarms.indices { s.swarms[si].alignment = max(0, s.swarms[si].alignment - 8) }
                if a.kind == .cognition && s.rng.chance(0.4) {
                    s.xenoArtifacts[i].quarantinedUntil = GameCalendar.addDays(s.date, 180)
                    s.regulatoryFlags.insert("xeno_incident")
                    Sim.news(&s, "\(a.name) reached the internet", "A copy of its outputs leaked through an evaluation tool. Regulators want answers; it's been locked away for six months.",
                             .policy, important: true, good: false)
                } else {
                    Sim.news(&s, "Anomaly incident", "Studying \(a.name) up close went wrong: corrupted swarm memories and a week of cleanup. Safety −6, brand −4.",
                             .research, important: true, good: false)
                }
            }
        default:
            s.xenoArtifacts.remove(at: i)
            s.safetyScore = min(100, s.safetyScore + 3)
            s.politicalCapital = min(100, s.politicalCapital + 3)
            Sim.news(&s, "\(a.name) destroyed", "Every copy wiped and the hardware shredded. Safety advocates applaud; your engineers mourn.", .research)
        }
    }

    // MARK: Ventures

    static func licenseOffer(_ a: XenoArtifact, _ s: GameState) -> (upfront: Double, monthly: Double) {
        let up = XenoCatalog.licenseShare(a.kind) * Macro.frontierValuation(s.year) * strength(a) * clamp(s.market.hype / 1.3, 0.6, 1.5)
        return (up, up * 0.018)
    }

    static func inhouseCapex(_ a: XenoArtifact, _ s: GameState) -> Double {
        // About ten months of revenue up front, before the build even starts paying.
        XenoCatalog.inhouseShare(a.kind) * Macro.frontierValuation(s.year) * strength(a) * 10
    }
}

// MARK: - Player actions

extension GameState {
    mutating func setXenoTarget(_ k: XenoKind) { xenoTarget = k.rawValue }

    mutating func licenseArtifact(_ id: UUID, partner: String) -> String? {
        guard let i = xenoArtifacts.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let a = xenoArtifacts[i]
        guard a.kind.hasVenture else { return "There's no business in that one — its value is what it does for your lab." }
        guard a.venture.isEmpty else { return "\(a.name) is already committed." }
        let o = XenoScience.licenseOffer(a, self)
        cash += o.upfront
        month.oneOffIncome += o.upfront
        lifetimeRevenue += o.upfront
        xenoArtifacts[i].venture = "license"
        xenoArtifacts[i].venturePartner = partner
        xenoArtifacts[i].ventureMonthly = o.monthly
        xenoArtifacts[i].ventureMonthsLeft = 48
        xenoArtifacts[i].ventureReady = date
        Achievements.unlock(&self, "licensor")
        Sim.news(&self, "\(partner) licenses \(a.name)", "\(Fmt.money(o.upfront)) upfront and \(Fmt.money(o.monthly))/month for four years.",
                 .finance, image: "sf_skyline", important: true, good: true)
        return nil
    }

    mutating func buildVenture(_ id: UUID) -> String? {
        guard let i = xenoArtifacts.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let a = xenoArtifacts[i]
        guard a.kind.hasVenture else { return "There's no business in that one." }
        guard a.venture.isEmpty else { return "\(a.name) is already committed." }
        let capex = XenoScience.inhouseCapex(a, self)
        if capex > cash { return "Building it yourself costs \(Fmt.money(capex))." }
        cash -= capex
        month.capex += capex
        let months = XenoCatalog.inhouseMonths(a.kind)
        xenoArtifacts[i].venture = "inhouse"
        xenoArtifacts[i].venturePartner = companyName
        xenoArtifacts[i].ventureReady = GameCalendar.addMonths(date, months)
        xenoArtifacts[i].ventureMonthly = XenoCatalog.inhouseShare(a.kind) * Macro.frontierValuation(year) * XenoScience.strength(a)
        xenoArtifacts[i].ventureMonthsLeft = 1
        let what: String = switch a.kind {
        case .materials: "a superconductor plant"
        case .biology: "a therapeutics company"
        default: "a proof-licensing business"
        }
        Sim.news(&self, "Building \(what) on \(a.name)", "\(Fmt.money(capex)) and about \(months) months to first revenue — then it grows with the market.",
                 .company, image: "hyperscale_campus", important: true)
        return nil
    }

    mutating func startMegaProject(_ id: String) -> String? {
        if let why = XenoScience.megaBlocker(id, self) { return why }
        guard let m = XenoCatalog.megaByID[id] else { return "Unknown project." }
        let cost = XenoScience.megaCost(m, self)
        cash -= cost
        month.capex += cost
        var days = m.days
        if signatureAt(.forge, 5) && id == "xeno_foundry" { days *= 0.6 }
        megaProjects.append(MegaProject(id: id, started: date, daysLeft: days, totalDays: days, cost: cost))
        Sim.news(&self, "\(m.name) begins", "\(Fmt.money(cost)) and about \(Int(days / 30.4)) months. \(m.effect)", .research, image: "hyperscale_campus", important: true)
        return nil
    }
}
