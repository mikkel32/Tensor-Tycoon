import Foundation

/// `--research <era>`: signature secrets, the research director, unique breakthroughs and xenoscience, headless.
extension BalanceHarness {
    static func research(era: String) {
        catalogCheck()
        signatureSweep(era: era)
        directorCheck(era: era)
        breakthroughCheck(era: era)
        xenoCheck()
    }

    /// Every prerequisite exists, none is far in the future of the item that needs it, and IDs are unique.
    static func catalogCheck() {
        var problems: [String] = []
        let ids = ResearchCatalog.all.map(\.id)
        if Set(ids).count != ids.count { problems.append("duplicate IDs") }
        for item in ResearchCatalog.all {
            for p in item.prereqs {
                guard let pre = ResearchCatalog.byID[p] else { problems.append("\(item.id) needs unknown \(p)"); continue }
                if pre.year > item.year + 1.5 && !item.isExotic { problems.append("\(item.id) (\(item.year)) needs later \(p) (\(pre.year))") }
            }
        }
        for f in Breakthroughs.fusions where ResearchCatalog.byID[f.a] == nil || ResearchCatalog.byID[f.b] == nil {
            problems.append("fusion \(f.id) refers to a missing breakthrough")
        }
        let names = Dictionary(grouping: ResearchCatalog.all, by: \.name).filter { $0.value.count > 1 }.keys
        if !names.isEmpty { problems.append("duplicate names: \(names.sorted().joined(separator: ", "))") }
        print("== Catalog: \(ResearchCatalog.core.count) techniques, \(ResearchCatalog.exotic.count) unique breakthroughs, \(Breakthroughs.fusions.count) fusions, \(SignatureSecret.allCases.count) signatures ==")
        print(problems.isEmpty ? "  no problems" : problems.map { "  ⚠︎ \($0)" }.joined(separator: "\n"))
    }

    /// A lab with a real research team, so the numbers mean something.
    static func researchLab(era: String, signature: SignatureSecret, seed: UInt64, researchers: Int = 20) -> GameState {
        var settings = NewGameSettings(companyName: "Probe Labs", founderName: "Bot", eraID: era, difficulty: .normal)
        settings.signature = signature
        var s = NewGame.create(settings, seed: seed)
        s.officeLevel = Economy.officeLevels.count - 1
        for i in 0..<researchers {
            s.employees.append(Employee(name: "Researcher \(i)", role: .researcher, skill: 70, salary: 200_000, morale: 80,
                                        hired: s.date, star: false, equity: 0))
        }
        s.cash = 1e10
        return s
    }

    static func runDays(_ s: inout GameState, _ days: Int) {
        for _ in 0..<days {
            Sim.advanceDay(&s)
            s.decisions.removeAll()
            s.gameOver = nil
            s.cash = max(s.cash, 1e9)
        }
    }

    static func signatureSweep(era: String) {
        print("== Signature secrets: 3 years from \(era) with 20 researchers ==")
        print("secret      level  RP/day  algo   rp     rl     data   mfu    agentQ  safety  insight  researched  eurekas  uniques")
        for sig in SignatureSecret.allCases {
            var s = researchLab(era: era, signature: sig, seed: 40)
            runDays(&s, 365 * 3)
            let b = s.bonuses
            print(String(format: "%-11@ %d      %-7.1f %-6.2f %-6.2f %-6.2f %-6.2f %-6.2f %-7.2f %-7.0f %-8.2f %-11d %-8d %d",
                         sig.rawValue as NSString, s.signatureLevel, s.rpToday, b.algo, b.rp, b.rl, b.dataTokens, b.mfu, b.agentQuality, b.safety,
                         b.insight, s.researched.count, s.eurekas, s.exoticOwned.count))
        }
        print("level costs: " + (2...SignatureSecret.maxLevel).map { "L\($0) \(Fmt.count(SignatureSecret.cost(toLevel: $0))) RP" }.joined(separator: " · "))
    }

    static func directorCheck(era: String) {
        print("\n== Research director: techniques completed in 2 years from \(era) ==")
        for auto in [false, true] {
            var s = researchLab(era: era, signature: .oracle, seed: 41)
            s.autoResearch = auto
            if !auto { s.researchQueue = Array(s.researchQueue.prefix(2)) }
            let before = s.researched.count
            var idleDays = 0
            for _ in 0..<(365 * 2) {
                runDays(&s, 1)
                if s.researchQueue.isEmpty { idleDays += 1 }
            }
            print("  director \(auto ? "on " : "off"): \(s.researched.count - before) techniques, queue empty \(idleDays) days, signature L\(s.signatureLevel), focus \(s.focus.title)")
        }
        for f in ResearchFocus.allCases {
            var s = researchLab(era: era, signature: .cortex, seed: 42)
            s.researchFocus = f.rawValue
            s.researchQueue = []
            let picks = (0..<4).compactMap { _ -> String? in
                guard let p = ResearchLab.pick(s) else { return nil }
                s.researchQueue.append(p)
                return ResearchLab.entryName(p)
            }
            print("  \(f.title): \(picks.joined(separator: ", "))")
        }
        let s = researchLab(era: era, signature: .cortex, seed: 43)
        let samples = ResearchCatalog.core.filter { $0.year <= s.year }.sorted { $0.year < $1.year }
        if let old = samples.first, let mid = samples.last(where: { $0.year <= s.year - 1.5 }), let fresh = samples.last {
            print("  catch-up pricing in \(era): \(old.name) \(Fmt.count(Sim.researchCost(old, year: s.year)))/\(Fmt.count(old.cost)) RP · \(mid.name) \(Fmt.count(Sim.researchCost(mid, year: s.year)))/\(Fmt.count(mid.cost)) · \(fresh.name) \(Fmt.count(Sim.researchCost(fresh, year: s.year)))/\(Fmt.count(fresh.cost))")
        }
    }

    static func breakthroughCheck(era: String) {
        print("\n== Unique breakthroughs (\(era)) ==")
        var s = researchLab(era: era, signature: .oracle, seed: 44)
        for id in s.exoticOwned {
            guard let item = ResearchCatalog.byID[id] else { continue }
            let partner = Breakthroughs.partner(of: id).flatMap { ResearchCatalog.byID[$0]?.name } ?? "—"
            print("  \(Breakthroughs.rarity(id).title.padding(toLength: 9, withPad: " ", startingAt: 0)) \(item.name) (\(Fmt.trim(item.year, 1))) · \(Fmt.count(Sim.researchCost(item, year: s.year))) RP · fusion partner: \(partner)")
        }
        // Research every unique you own, then look at mastery and licensing.
        for id in s.exoticOwned where !s.researched.contains(id) {
            s.researched.insert(id)
            s.researchResults[id] = 1
            s.exoticMastery[id] = 1
        }
        ResearchLab.checkFusions(&s)
        let before = s.bonuses
        if let id = s.exoticOwned.first, let item = ResearchCatalog.byID[id] {
            print("  refine \(item.name): II \(Fmt.count(Breakthroughs.refineCost(item, toLevel: 2))) RP, III \(Fmt.count(Breakthroughs.refineCost(item, toLevel: 3))) RP")
            s.exoticMastery[id] = 3
            let after = s.bonuses
            print("  mastery III changes: algo \(Fmt.trim(before.algo, 3))→\(Fmt.trim(after.algo, 3)), rp \(Fmt.trim(before.rp, 2))→\(Fmt.trim(after.rp, 2)), throughput \(Fmt.trim(before.throughput, 2))→\(Fmt.trim(after.throughput, 2)), reasoning \(Fmt.trim(before.skill(.reasoning), 2))→\(Fmt.trim(after.skill(.reasoning), 2))")
            let buyers = ResearchLab.licenseBuyers(s, tech: id).prefix(4)
            print("  license \(item.name): " + buyers.map { "\($0.name) \(Fmt.money($0.upfront))\($0.rival ? " (rival)" : "")" }.joined(separator: " · "))
            if let b = buyers.first { _ = s.licenseExotic(id, to: b.id) }
        }
        print("  active fusions: \(Breakthroughs.activeFusions(s.researched).map(\.name).joined(separator: ", ").isEmpty ? "none" : Breakthroughs.activeFusions(s.researched).map(\.name).joined(separator: ", "))")
        var t = researchLab(era: era, signature: .oracle, seed: 45, researchers: 40)
        let owned = t.exoticOwned.count
        runDays(&t, 365 * 4)
        print("  4 years with 40 researchers: \(t.exoticOwned.count - owned) new unique ideas, \(t.eurekas) eureka moments, fusions: \(t.fusionsSeen.count)")
    }

    static func xenoCheck() {
        print("\n== Xenoscience (2027 frontier lab) ==")
        var (s, _) = frontierLab(year: 2027, chips: 20_000, seed: 46)
        let b0 = s.bonuses
        for kind in [XenoKind.architecture, .optimizer, .codec, .materials, .mathematics, .biology, .cognition] {
            s.xenoTarget = kind.rawValue
            s.xenoInsight = XenoScience.insightNeeded(s)
            XenoScience.discover(&s, s.bonuses)
        }
        let b1 = s.bonuses
        print("  discoveries: \(XenoScience.discoveries(s)) · next needs \(Fmt.count(XenoScience.insightNeeded(s))) insight")
        for a in s.xenoArtifacts {
            print("  \(a.kind.title.padding(toLength: 18, withPad: " ", startingAt: 0)) \(a.name): potency ×\(Fmt.trim(a.potency, 2)), legibility \(Int(a.legibility * 100))%, strength \(Fmt.trim(XenoScience.strength(a), 2))")
        }
        print("  bonuses: algo \(Fmt.trim(b0.algo, 2))→\(Fmt.trim(b1.algo, 2)) · throughput \(Fmt.trim(b0.throughput, 2))→\(Fmt.trim(b1.throughput, 2)) · rp \(Fmt.trim(b0.rp, 2))→\(Fmt.trim(b1.rp, 2)) · reasoning \(Fmt.trim(b0.skill(.reasoning), 2))→\(Fmt.trim(b1.skill(.reasoning), 2)) · safety \(Fmt.trim(b0.safety, 1))→\(Fmt.trim(b1.safety, 1))")
        print("  power bill ×\(Fmt.trim(XenoScience.powerFactor(s), 2)), datacenter build time ×\(Fmt.trim(XenoScience.buildFactor(s), 2))")
        for a in s.xenoArtifacts where a.kind.hasVenture {
            let o = XenoScience.licenseOffer(a, s)
            print("  \(a.name): license \(Fmt.money(o.upfront)) + \(Fmt.money(o.monthly))/mo · in-house \(Fmt.money(XenoScience.inhouseCapex(a, s))) capex → \(Fmt.money(XenoCatalog.inhouseShare(a.kind) * Macro.frontierValuation(s.year) * XenoScience.strength(a)))/mo")
        }
        // Run two years: study at 20%, build every venture in-house, start every mega-project you can, resolve anomalies in turn.
        s.xenoStudyShare = 0.2
        for a in s.xenoArtifacts where a.kind.hasVenture { _ = s.buildVenture(a.id) }
        let legBefore = s.xenoArtifacts.map(\.legibility).reduce(0, +) / Double(max(1, s.xenoArtifacts.count))
        var anomalies = 0
        var option = 0
        let startCash = s.cash
        for day in 0..<(365 * 2) {
            if day % 30 == 0 {
                for m in XenoCatalog.megaProjects where XenoScience.megaBlocker(m.id, s) == nil { _ = s.startMegaProject(m.id) }
            }
            Sim.advanceDay(&s)
            for d in s.decisions where d.kind == "xeno_anomaly" {
                anomalies += 1
                s.resolveDecision(d.id, option: option % 3)
                option += 1
            }
            s.decisions.removeAll()
            s.gameOver = nil
            s.cash = max(s.cash, 5e10)
        }
        let legAfter = s.xenoArtifacts.map(\.legibility).reduce(0, +) / Double(max(1, s.xenoArtifacts.count))
        let ventureRevenue = s.xenoArtifacts.reduce(0) { $0 + $1.ventureRevenue }
        print("  2 years: legibility \(Int(legBefore * 100))%→\(Int(legAfter * 100))%, \(anomalies) anomalies, venture revenue \(Fmt.money(ventureRevenue)), artifacts left \(s.xenoArtifacts.count), cash Δ \(Fmt.money(s.cash - startCash))")
        print("  mega-projects: " + s.megaProjects.map { "\(XenoCatalog.megaByID[$0.id]?.name ?? $0.id) \($0.done ? "done" : "\(Int($0.daysLeft))d left")" }.joined(separator: " · "))
        print("  alien victory progress \(Int(Victory.progress(.xeno, s) * 100))%")
    }
}
