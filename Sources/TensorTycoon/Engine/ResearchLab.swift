import Foundation

/// Daily research: the queue (with overflow, so no research point is ever wasted), the research director,
/// eureka moments, refining unique breakthroughs, fusions, and the signature programme.
enum ResearchLab {
    // MARK: Daily

    static func daily(_ s: inout GameState, _ b: ResearchBonuses) {
        // 3.5: founding-kit research multipliers (×1 without a kit) speed up your people, not your agents.
        let rate = Sim.researchRate(s, b) * FoundingKit.researchMultiplier(s) + s.rsiRPToday + s.swarmRPToday
        s.rpToday = rate

        // Signature programme and alien study take their shares first.
        var sigRP = s.signature != nil && s.signatureLevel < SignatureSecret.maxLevel ? rate * clamp(s.signatureShare, 0, 0.75) : 0
        let studyRP = XenoScience.hasUndeciphered(s) ? rate * clamp(s.xenoStudyShare, 0, 0.6) : 0
        // 3.4: running moonshots take theirs (zero when none are running).
        let moonRP = rate * Moonshots.researchShare(s)
        var pool = max(0, rate - sigRP - studyRP - moonRP)

        if s.autoResearch { fillQueue(&s) }

        // Work through the queue; leftover points roll into the next project.
        var steps = 0
        while pool > 0.0001 && steps < 8, let current = s.researchQueue.first {
            steps += 1
            guard let (need, mult) = remaining(&s, current) else { continue }
            if pool >= need {
                pool -= need
                complete(&s, current, b)
                if s.autoResearch { fillQueue(&s) }
            } else {
                s.researchProgress[current, default: 0] += pool * mult
                pool = 0
            }
        }

        // Nothing queued: idle researchers push the signature programme instead.
        if pool > 0 && s.signature != nil && s.signatureLevel < SignatureSecret.maxLevel {
            sigRP += pool
            pool = 0
        }
        s.signatureRPToday = sigRP
        s.studyRPToday = studyRP
        if sigRP > 0 { advanceSignature(&s, sigRP) }
        if studyRP > 0 { XenoScience.study(&s, studyRP) }
        if moonRP > 0 { Moonshots.invest(&s, moonRP) }

        eureka(&s, rate)
    }

    /// Research points still needed for a queue entry and the speed multiplier on its progress, or nil if the entry
    /// was dropped (done, invalid or locked). Missing prerequisites are queued ahead of it.
    private static func remaining(_ s: inout GameState, _ entry: String) -> (Double, Double)? {
        if let p = FrontierProgram.get(entry: entry) {
            guard p.isOpen(s) else {
                s.researchQueue.removeFirst()
                return nil
            }
            return (max(0, p.cost(level: s.programLevel(p.id) + 1) - (s.researchProgress[entry] ?? 0)), 1)
        }
        if entry.hasPrefix(Breakthroughs.refinePrefix) {
            let id = String(entry.dropFirst(Breakthroughs.refinePrefix.count))
            guard let item = ResearchCatalog.byID[id], s.researched.contains(id),
                  (s.exoticMastery[id] ?? 1) < Breakthroughs.maxMastery else {
                s.researchQueue.removeFirst()
                return nil
            }
            let cost = Breakthroughs.refineCost(item, toLevel: (s.exoticMastery[id] ?? 1) + 1)
            return (max(0, cost - (s.researchProgress[entry] ?? 0)), 1)
        }
        guard let item = ResearchCatalog.byID[entry], !s.researched.contains(entry),
              !(item.isExotic && !s.exoticOwned.contains(entry)), XenoScience.researchUnlocked(entry, s) else {
            s.researchQueue.removeFirst()
            return nil
        }
        let missing = item.prereqs.filter { !s.researched.contains($0) }
        if !missing.isEmpty {
            s.researchQueue.removeAll { missing.contains($0) }
            s.researchQueue.insert(contentsOf: missing, at: 0)
            return nil
        }
        let cost = Sim.researchCost(item, year: s.year)
        let mult = max(0.1, item.category == .frontier ? 1 + s.traits.frontierRP : 1) * FoundingKit.categorySpeed(s, item)
        return (max(0, (cost - (s.researchProgress[entry] ?? 0)) / mult), mult)
    }

    // MARK: Completion

    static func complete(_ s: inout GameState, _ entry: String, _ b: ResearchBonuses) {
        s.researchQueue.removeAll { $0 == entry }
        s.researchProgress[entry] = nil
        if let p = FrontierProgram.get(entry: entry) {
            let level = s.programLevel(p.id) + 1
            s.programLevels[p.id] = level
            let total = FrontierProgram.strength(level)
            Sim.news(&s, "\(p.name) reaches level \(level)",
                     "This level adds \(Int((FrontierProgram.marginal(level) * 100).rounded()))% of what level 1 did. The programme so far: "
                        + p.effects.prefix(3).map { ResearchCatalog.describe($0, r: total) }.joined(separator: " · ") + ".",
                     .research, image: "wafer_closeup", important: level % 5 == 0, good: true)
            cascade(&s)
            return
        }
        if entry.hasPrefix(Breakthroughs.refinePrefix) {
            let id = String(entry.dropFirst(Breakthroughs.refinePrefix.count))
            guard let item = ResearchCatalog.byID[id] else { return }
            let level = min(Breakthroughs.maxMastery, (s.exoticMastery[id] ?? 1) + 1)
            s.exoticMastery[id] = level
            let mult = Breakthroughs.masteryMultiplier(level)
            Sim.news(&s, "\(item.name) refined to mastery \(roman(level))",
                     "Your team rebuilt it from first principles. Its benefits are now ×\(Fmt.trim(mult, 2)) of the original idea. \(item.effectSummary(result: (s.researchResults[id] ?? 1) * mult).prefix(2).joined(separator: " · ")).",
                     .research, image: "wafer_closeup", important: true, good: true)
            if level == Breakthroughs.maxMastery { Achievements.unlock(&s, "mastery") }
            cascade(&s)
            return
        }
        guard let item = ResearchCatalog.byID[entry] else { return }
        // How well did it work in *your* lab? Better teams and more experiment compute land better results.
        let researchers = s.employees.filter { $0.role == .researcher }
        let quality = researchers.isEmpty ? 0.5 : researchers.reduce(0) { $0 + $1.skill } / Double(researchers.count) / 100
        let computeBoost = min(0.08, Double(s.researchChips.values.reduce(0, +)) / 20_000)
        let spread = item.isExotic ? 0.32 : 0.16
        // Published techniques come with code and tutorials: they rarely flop.
        let floor = item.isExotic ? 0.4 : (s.year >= item.year ? 0.75 : 0.6)
        let r = clamp(1 + 0.25 * (quality - 0.5) + computeBoost + s.rng.gaussian() * spread, floor, item.isExotic ? 1.8 : 1.5)
        s.researchResults[entry] = (r * 100).rounded() / 100
        s.researched.insert(entry)
        if item.isExotic && s.exoticMastery[entry] == nil { s.exoticMastery[entry] = 1 }
        let verdict: String
        switch r {
        case ..<0.8: verdict = "Results came in below expectations (\(Fmt.trim(r, 2))×)."
        case ..<1.12: verdict = "Results matched the paper (\(Fmt.trim(r, 2))×)."
        default: verdict = item.isExotic && r >= 1.5 ? "A legendary result (\(Fmt.trim(r, 2))×)!" : "Your implementation beat the paper (\(Fmt.trim(r, 2))×)!"
        }
        let shown = item.isExotic ? r * Breakthroughs.masteryMultiplier(1) : r
        let effects = item.effectSummary(result: shown).prefix(3).joined(separator: " · ")
        Sim.news(&s, "\(item.isExotic ? "Unique breakthrough" : "Research complete"): \(item.name)", "\(verdict) \(effects).",
                 .research, image: "wafer_closeup", important: item.isExotic || item.category == .frontier || r >= 1.3, good: r >= 0.8)
        if s.publication == .open && item.year > s.year - 0.2 { s.brand = min(100, s.brand + 1.5) }
        if item.isExotic {
            Achievements.unlock(&s, "unique_tech")
            if s.publication == .open {
                s.publishedTech[entry] = s.date
                Sim.news(&s, "Your \(item.name) paper goes viral", "Open science wins you fans — and every rival lab will have reproduced it within about six months.", .research, good: true)
            }
        }
        checkFusions(&s)
        cascade(&s)
    }

    /// Insight Engine mastery: a finished project sometimes finishes the next one too.
    private static func cascade(_ s: inout GameState) {
        guard s.signatureAt(.oracle, 5), let next = s.researchQueue.first, s.rng.chance(0.25) else { return }
        if next.hasPrefix(Breakthroughs.refinePrefix) {
            let id = String(next.dropFirst(Breakthroughs.refinePrefix.count))
            if let item = ResearchCatalog.byID[id] {
                s.researchProgress[next] = Breakthroughs.refineCost(item, toLevel: (s.exoticMastery[id] ?? 1) + 1)
            }
        } else if let p = FrontierProgram.get(entry: next) {
            s.researchProgress[next] = p.cost(level: s.programLevel(p.id) + 1)
        } else if let item = ResearchCatalog.byID[next], item.prereqs.allSatisfy({ s.researched.contains($0) }) {
            s.researchProgress[next] = Sim.researchCost(item, year: s.year)
        }
    }

    static func checkFusions(_ s: inout GameState) {
        for f in Breakthroughs.activeFusions(s.researched) where !s.fusionsSeen.contains(f.id) {
            s.fusionsSeen.insert(f.id)
            let a = ResearchCatalog.byID[f.a]?.name ?? f.a
            let b = ResearchCatalog.byID[f.b]?.name ?? f.b
            Achievements.unlock(&s, "fusion")
            Sim.news(&s, "Fusion: \(f.name)",
                     "\(a) and \(b) turn out to be two halves of one idea. \(f.blurb) \(f.effects.map { ResearchCatalog.describe($0) }.joined(separator: " · ")).",
                     .research, image: "wafer_closeup", important: true, good: true)
        }
    }

    static func roman(_ n: Int) -> String { ["", "I", "II", "III", "IV", "V"][clamp(n, 0, 5)] }

    // MARK: Signature programme

    static func advanceSignature(_ s: inout GameState, _ rp: Double) {
        guard let sig = s.signature else { return }
        s.signatureProgress += rp
        while s.signatureLevel < SignatureSecret.maxLevel {
            let need = SignatureSecret.cost(toLevel: s.signatureLevel + 1)
            guard s.signatureProgress >= need else { break }
            s.signatureProgress -= need
            s.signatureLevel += 1
            let lvl = s.signatureLevel
            var body = "Project \(sig.codename) reached level \(lvl). " + sig.perLevel.map { ResearchCatalog.describe($0, r: Double(lvl)) }.joined(separator: " · ") + " in total."
            if lvl == 3 { body += " Capstone unlocked: \(sig.capstone3Text)" }
            if lvl == 5 { body += " Mastery: \(sig.capstone5Text)" }
            Sim.news(&s, "\(sig.title) — level \(lvl)", body, .research, image: "wafer_closeup", important: true, good: true)
            if lvl == SignatureSecret.maxLevel {
                s.signatureProgress = 0
                Achievements.unlock(&s, "signature_master")
            }
        }
    }

    /// Models you've trained (the Ouroboros lineage counts these).
    static func lineageCount(_ s: GameState) -> Int { s.models.filter { $0.design.mode != .finetune }.count }

    /// Extra log10 effective compute from Ouroboros lineage.
    static func lineage(_ s: GameState) -> Double {
        guard let sig = s.signature, sig == .ouroboros else { return 0 }
        let l = Double(s.signatureLevel)
        let mult = s.signatureLevel >= 5 ? 2.0 : 1.0
        return min(0.03 * l * mult, Double(lineageCount(s)) * 0.006 * l * mult)
    }

    // MARK: Eureka moments

    static func eureka(_ s: inout GameState, _ rate: Double) {
        guard let current = s.researchQueue.first, rate > 0 else { return }
        let researchers = s.employees.filter { $0.role == .researcher }
        let skill = researchers.isEmpty ? 50 : researchers.reduce(0) { $0 + $1.skill } / Double(researchers.count)
        var p = 0.004 * (0.6 + skill / 100) * (1 + min(1, Double(researchers.count) / 40))
        if s.signatureAt(.oracle, 3) { p *= 2 }
        if s.kit.contains("eureka_engine") { p *= 3 }   // 3.5: founding kit
        guard s.rng.chance(p) else { return }
        let cost: Double
        let name: String
        if current.hasPrefix(Breakthroughs.refinePrefix) {
            let id = String(current.dropFirst(Breakthroughs.refinePrefix.count))
            guard let item = ResearchCatalog.byID[id] else { return }
            cost = Breakthroughs.refineCost(item, toLevel: (s.exoticMastery[id] ?? 1) + 1)
            name = "refining \(item.name)"
        } else if let p = FrontierProgram.get(entry: current) {
            cost = p.cost(level: s.programLevel(p.id) + 1)
            name = p.name
        } else {
            guard let item = ResearchCatalog.byID[current] else { return }
            cost = Sim.researchCost(item, year: s.year)
            name = item.name
        }
        let jump = cost * s.rng.range(0.3, 0.6)
        s.researchProgress[current, default: 0] = min(cost, (s.researchProgress[current] ?? 0) + jump)
        s.eurekas += 1
        let who = researchers.max { $0.skill < $1.skill }?.name ?? s.founderName
        Sim.news(&s, "Eureka! \(who) cracks a problem in \(name)", "A shower thought saved weeks of experiments: \(Fmt.count(jump)) research points of progress overnight.",
                 .research, good: true)
        if s.eurekas >= 10 { Achievements.unlock(&s, "eureka") }
    }

    // MARK: Research director

    static func fillQueue(_ s: inout GameState) {
        var added = 0
        while s.researchQueue.count < 2 && added < 3, let next = pick(s) {
            s.researchQueue.append(next)
            added += 1
        }
    }

    /// Year from which the director sees the projected late-game research and the frontier programmes.
    static let lateDirectorYear = 2027.0
    /// How the director values one more level of a frontier programme (a new technique is worth 1–3).
    static let programValue = 0.6

    /// The director's next pick: the best value for money under your focus.
    static func pick(_ s: GameState) -> String? {
        let focus = s.focus
        let queued = Set(s.researchQueue)
        var best: (String, Double)? = nil
        for item in ResearchCatalog.all where !s.researched.contains(item.id) && !queued.contains(item.id) {
            if item.isExotic && !s.exoticOwned.contains(item.id) { continue }
            if !XenoScience.researchUnlocked(item.id, s) { continue }
            // 3.4: the projected 2028+ techniques stay out of the director's sight before 2027, so early eras play as before.
            if s.year < lateDirectorYear && ResearchCatalog.lateGameIDs.contains(item.id) { continue }
            guard item.prereqs.allSatisfy({ s.researched.contains($0) }) else { continue }
            // Don't sink years into ideas far ahead of their time unless you're chasing capability.
            let ahead = item.year - s.year
            if ahead > (focus == .capability ? 3 : 1.5) { continue }
            let cost = max(50, Sim.researchCost(item, year: s.year))
            var value = 1.0
            if ahead <= 0 { value += 0.6 }
            if item.isExotic { value += 1.2 + Double(Breakthroughs.rarity(item.id) == .legendary ? 1 : 0) }
            if item.effects.contains(where: { if case .unlock = $0 { return true } else { return false } }) { value += 0.5 }
            if item.category == .frontier { value += 0.8 }
            if let partner = Breakthroughs.partner(of: item.id), s.researched.contains(partner) { value += 2 }
            value *= ResearchCatalog.directorWeight(item)   // 3.4: domain-only research ranks below the core
            let score: Double = focus == .cheapest ? 1 / cost : focus.weight(item.category) * value / pow(cost, 0.75)
            if best == nil || score > best!.1 { best = (item.id, score) }
        }
        // 3.4: from 2027 the repeatable frontier programmes compete for research points, and refining unique
        // breakthroughs competes with them instead of waiting for the tree to run dry.
        if s.year >= lateDirectorYear {
            for p in FrontierProgram.all where p.isOpen(s) && !queued.contains(p.entry) {
                let cost = p.cost(level: s.programLevel(p.id) + 1)
                let score = focus == .cheapest ? 1 / cost : focus.weight(p.category) * programValue / pow(cost, 0.75)
                if best == nil || score > best!.1 { best = (p.entry, score) }
            }
            for id in s.exoticOwned where s.researched.contains(id) && (s.exoticMastery[id] ?? 1) < Breakthroughs.maxMastery
                && !queued.contains(Breakthroughs.refineID(id)) {
                guard let item = ResearchCatalog.byID[id] else { continue }
                let cost = max(50, Breakthroughs.refineCost(item, toLevel: (s.exoticMastery[id] ?? 1) + 1))
                let value = 1.2 + (Breakthroughs.rarity(id) == .legendary ? 1 : 0)
                let score = focus == .cheapest ? 1 / cost : focus.weight(.exotic) * value / pow(cost, 0.75)
                if best == nil || score > best!.1 { best = (Breakthroughs.refineID(id), score) }
            }
        }
        // Nothing left to learn: refine your best unique breakthrough.
        if best == nil {
            let refinable = s.exoticOwned.filter { s.researched.contains($0) && (s.exoticMastery[$0] ?? 1) < Breakthroughs.maxMastery }
                .filter { !queued.contains(Breakthroughs.refineID($0)) }
            if let id = refinable.max(by: { Breakthroughs.rarity($0).licenseBase < Breakthroughs.rarity($1).licenseBase }) {
                return Breakthroughs.refineID(id)
            }
        }
        return best?.0
    }

    /// Days until a queue entry finishes at today's rate, counting everything ahead of it.
    static func eta(_ s: GameState, entry: String, rate: Double) -> Double? {
        guard rate > 0, let idx = s.researchQueue.firstIndex(of: entry) else { return nil }
        var total = 0.0
        for e in s.researchQueue.prefix(idx + 1) { total += entryCost(s, e) - (s.researchProgress[e] ?? 0) }
        return max(0, total) / rate
    }

    static func entryCost(_ s: GameState, _ entry: String) -> Double {
        if let p = FrontierProgram.get(entry: entry) { return p.cost(level: s.programLevel(p.id) + 1) }
        if entry.hasPrefix(Breakthroughs.refinePrefix) {
            let id = String(entry.dropFirst(Breakthroughs.refinePrefix.count))
            guard let item = ResearchCatalog.byID[id] else { return 0 }
            return Breakthroughs.refineCost(item, toLevel: (s.exoticMastery[id] ?? 1) + 1)
        }
        guard let item = ResearchCatalog.byID[entry] else { return 0 }
        return Sim.researchCost(item, year: s.year)
    }

    static func entryName(_ entry: String) -> String {
        if let p = FrontierProgram.get(entry: entry) { return "\(p.name) (frontier programme)" }
        if entry.hasPrefix(Breakthroughs.refinePrefix) {
            let id = String(entry.dropFirst(Breakthroughs.refinePrefix.count))
            return "Refine \(ResearchCatalog.byID[id]?.name ?? id)"
        }
        return ResearchCatalog.byID[entry]?.name ?? entry
    }

    /// Research points per day left for the queue after the signature programme and alien study take their shares.
    static func queueRate(_ s: GameState, total: Double) -> Double {
        let sig = s.signature != nil && s.signatureLevel < SignatureSecret.maxLevel ? clamp(s.signatureShare, 0, 0.75) : 0
        let study = XenoScience.hasUndeciphered(s) ? clamp(s.xenoStudyShare, 0, 0.6) : 0
        return total * max(0, 1 - sig - study - Moonshots.researchShare(s))
    }

    // MARK: Monthly: new ideas, licence royalties

    static func monthly(_ s: inout GameState) {
        // Royalties from unique breakthroughs you licensed out.
        for i in s.exoticLicenses.indices where s.exoticLicenses[i].monthsLeft > 0 {
            let r = s.exoticLicenses[i].royaltyMonthly
            s.cash += r
            s.month.revLicensing += r
            s.lifetimeRevenue += r
            s.exoticLicenses[i].monthsLeft -= 1
        }
        // A brilliant team keeps having ideas nobody else has.
        let researchers = s.employees.filter { $0.role == .researcher }
        guard !researchers.isEmpty else { return }
        let skill = researchers.reduce(0) { $0 + $1.skill } / Double(researchers.count)
        var p = 0.03 * (0.5 + skill / 100) * (1 + min(1, Double(researchers.count) / 30))
        if s.signatureAt(.oracle, 3) { p *= 2 }
        if s.kit.contains("eureka_engine") { p *= 2 }   // 3.5: founding kit
        guard s.rng.chance(p) else { return }
        let taken = Set(s.exoticOwned + s.rivalTech.values.flatMap { $0 })
        let y = s.year
        var pool = ResearchCatalog.exotic.filter { !taken.contains($0.id) && $0.year <= y + 3 }
        if pool.isEmpty { pool = ResearchCatalog.exotic.filter { !s.exoticOwned.contains($0.id) && $0.year <= y + 2 } }
        guard let idea = pool.randomElement(using: &s.rng) else { return }
        s.exoticOwned.append(idea.id)
        let who = researchers.max { $0.skill < $1.skill }?.name ?? s.founderName
        var body = "\(who) came back from a long weekend with \(idea.name): \(idea.blurb) It's a \(Breakthroughs.rarity(idea.id).title.lowercased()) breakthrough, and it's yours alone."
        if let partner = Breakthroughs.partner(of: idea.id), s.exoticOwned.contains(partner),
           let f = Breakthroughs.fusion(for: idea.id) {
            body += " Combined with \(ResearchCatalog.byID[partner]?.name ?? partner) it becomes \(f.name)."
        }
        Sim.news(&s, "New unique idea: \(idea.name)", body, .research, image: "wafer_closeup", important: true, good: true)
    }

    // MARK: Licensing unique breakthroughs

    struct LicenseBuyer: Identifiable {
        var id: String
        var name: String
        var rival: Bool
        var upfront: Double
        var royalty: Double
    }

    static func licenseBuyers(_ s: GameState, tech: String) -> [LicenseBuyer] {
        guard let item = ResearchCatalog.byID[tech], item.isExotic, s.researched.contains(tech) else { return [] }
        let done = Set(s.exoticLicenses.filter { $0.techID == tech }.map(\.buyerID))
        let scale = clamp(Macro.frontierValuation(s.year) / 3e11, 0.02, 6)
        let mastery = Breakthroughs.masteryMultiplier(s.exoticMastery[tech] ?? 1) / 1.25
        let base = Breakthroughs.rarity(tech).licenseBase * scale * mastery * (s.researchResults[tech] ?? 1)
        var out: [LicenseBuyer] = []
        for c in s.competitors where !c.acquired && s.year >= c.def.founded.decimal && !done.contains(c.id)
            && !(s.rivalTech[c.id] ?? []).contains(tech) {
            let up = base * 1.6 * clamp(c.def.computeShare / 0.12, 0.4, 1.8)
            out.append(LicenseBuyer(id: c.id, name: c.def.name, rival: true, upfront: up, royalty: up * 0.012))
        }
        for p in BigPlayerCatalog.neutral where !done.contains(p.id) {
            let up = base * clamp(p.weight / 0.18, 0.4, 1.4)
            out.append(LicenseBuyer(id: p.id, name: p.name, rival: false, upfront: up, royalty: up * 0.01))
        }
        return out.sorted { $0.upfront > $1.upfront }
    }
}

// MARK: - Bonuses from everything you know

extension GameState {
    /// Researched techniques plus your signature, unique-breakthrough mastery, fusions and alien discoveries.
    var bonuses: ResearchBonuses {
        var ids = researched
        var res = researchResults
        if let sig = signature {
            ids.insert("sig:\(sig.rawValue)")
            res["sig:\(sig.rawValue)"] = Double(signatureLevel)
            if signatureLevel >= 3 { ids.insert("sig:\(sig.rawValue):3") }
            if signatureLevel >= 5 { ids.insert("sig:\(sig.rawValue):5") }
            let lineage = ResearchLab.lineage(self)
            if lineage > 0 {
                ids.insert("sig:lineage")
                res["sig:lineage"] = lineage / 0.01
            }
        }
        for f in Breakthroughs.activeFusions(researched) { ids.insert(f.id) }
        for (id, scale) in XenoScience.virtualSources(self) where scale > 0 {
            ids.insert(id)
            res[id] = scale
        }
        // 3.4: frontier programme levels and finished moonshots (both empty before 2027).
        for (id, level) in programLevels where level > 0 {
            guard let p = FrontierProgram.byID[id] else { continue }
            ids.insert(p.entry)
            res[p.entry] = FrontierProgram.strength(level)
        }
        for (id, scale) in Moonshots.bonusSources(self) {
            ids.insert(id)
            res[id] = scale
        }
        // 3.5: founding-kit cards and the RL lab (nothing without a kit or an RL lab).
        for (id, scale) in FoundingKit.bonusSources(self) {
            ids.insert(id)
            res[id] = scale
        }
        for (id, scale) in AdvancedProjects.bonusSources(self) {   // 3.5: delivered government programmes
            ids.insert(id)
            res[id] = scale
        }
        for (id, scale) in Semis.bonusSources(self) {   // 3.5: your own chips and fabs
            ids.insert(id)
            res[id] = scale
        }
        return ResearchCatalog.bonuses(ids, results: res, mastery: exoticMastery)
    }
}

// MARK: - Player actions

extension GameState {
    mutating func chooseSignature(_ secret: SignatureSecret) -> String? {
        if signatureLevel > 0 { return "Your lab's signature is already \(signature?.title ?? signatureID)." }
        signatureID = secret.rawValue
        signatureLevel = 1
        signatureProgress = 0
        if signatureShare <= 0 { signatureShare = SignatureSecret.defaultShare }
        Sim.news(&self, "Project \(secret.codename) begins", "\(secret.blurb) Level 1: " + secret.perLevel.map { ResearchCatalog.describe($0) }.joined(separator: " · ") + ".",
                 .research, image: "wafer_closeup", important: true, good: true)
        return nil
    }

    mutating func setSignatureShare(_ share: Double) { signatureShare = clamp(share, 0, 0.75) }

    mutating func setXenoStudyShare(_ share: Double) { xenoStudyShare = clamp(share, 0, 0.6) }

    mutating func setAutoResearch(_ on: Bool) {
        autoResearch = on
        if on { ResearchLab.fillQueue(&self) }
    }

    mutating func setResearchFocus(_ f: ResearchFocus) {
        researchFocus = f.rawValue
        if autoResearch { ResearchLab.fillQueue(&self) }
    }

    /// Move a queued project up (negative) or down (positive).
    mutating func moveResearch(_ entry: String, by delta: Int) {
        guard let i = researchQueue.firstIndex(of: entry) else { return }
        let j = clamp(i + delta, 0, researchQueue.count - 1)
        guard i != j else { return }
        researchQueue.remove(at: i)
        researchQueue.insert(entry, at: j)
    }

    mutating func researchNext(_ entry: String) {
        researchQueue.removeAll { $0 == entry }
        researchQueue.insert(entry, at: 0)
    }

    /// 3.4: queue the next level of a frontier programme.
    mutating func queueProgram(_ id: String) -> String? {
        guard let p = FrontierProgram.byID[id] else { return "Unknown programme." }
        if year < p.opens { return "\(p.name) opens in \(Int(p.opens))." }
        if !researched.contains(p.prereq) { return "Research \(ResearchCatalog.byID[p.prereq]?.name ?? p.prereq) first." }
        if researchQueue.contains(p.entry) { return nil }
        researchQueue.append(p.entry)
        return nil
    }

    mutating func queueRefine(_ id: String) -> String? {
        guard let item = ResearchCatalog.byID[id], item.isExotic, researched.contains(id) else { return "Research it first." }
        let level = exoticMastery[id] ?? 1
        if level >= Breakthroughs.maxMastery { return "\(item.name) is already fully mastered." }
        let entry = Breakthroughs.refineID(id)
        if researchQueue.contains(entry) { return nil }
        researchQueue.append(entry)
        return nil
    }

    /// Queue every published technique you can start right now, cheapest first.
    mutating func queueAllPublished() -> Int {
        let picks = (ResearchCatalog.core + ResearchCatalog.lateGame).filter { item in
            !researched.contains(item.id) && !researchQueue.contains(item.id) && item.year <= year
                && item.category != .frontier && XenoScience.researchUnlocked(item.id, self)
        }.sorted { Sim.researchCost($0, year: year) < Sim.researchCost($1, year: year) }
        researchQueue.append(contentsOf: picks.map(\.id))
        return picks.count
    }

    mutating func licenseExotic(_ tech: String, to buyerID: String) -> String? {
        guard let item = ResearchCatalog.byID[tech] else { return "Unknown technique." }
        guard let buyer = ResearchLab.licenseBuyers(self, tech: tech).first(where: { $0.id == buyerID }) else {
            return "\(item.name) can't be licensed to them."
        }
        cash += buyer.upfront
        month.oneOffIncome += buyer.upfront
        lifetimeRevenue += buyer.upfront
        exoticLicenses.append(ExoticLicense(techID: tech, buyerID: buyer.id, buyerName: buyer.name, signed: date,
                                            upfront: buyer.upfront, royaltyMonthly: buyer.royalty, monthsLeft: 36))
        if buyer.rival { rivalTech[buyer.id, default: []].append(tech) }
        Achievements.unlock(&self, "licensor")
        Sim.news(&self, "Licensed \(item.name) to \(buyer.name)",
                 "\(Fmt.money(buyer.upfront)) upfront and \(Fmt.money(buyer.royalty))/month for three years.\(buyer.rival ? " Their next models will use it." : "")",
                 .finance, image: "sf_skyline", important: true, good: true)
        return nil
    }
}
