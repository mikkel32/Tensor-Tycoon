import Foundation

/// 3.5: the founding kit in play — setting up the cards on day one, research multipliers, the RL lab and the starter
/// quests. Everything here is a no-op for a game without a kit, an RL lab or quests, so older saves and kit-less games
/// play exactly as before. None of it draws from the game's RNG.
extension FoundingKit {
    // MARK: Research

    static func researchMultiplier(_ s: GameState) -> Double {
        researchMultiplier(kit: s.kit, genius: s.kitMode == KitMode.genius.rawValue)
    }

    /// Extra speed on one research item from the kit (RL pioneers: reasoning & RL twice as fast).
    static func categorySpeed(_ s: GameState, _ item: ResearchItem) -> Double {
        guard !s.kit.isEmpty else { return 1 }
        if item.category == .reasoning && s.kit.contains("rl_pioneers") { return 2 }
        return 1
    }

    /// Virtual research sources for the bonus aggregator: the RL lab (scaled by level) and research-side cards.
    static func bonusSources(_ s: GameState) -> [(String, Double)] {
        var out: [(String, Double)] = []
        if s.rlLabLevel > 0 { out.append((rlLabID, Double(min(rlMaxLevel, s.rlLabLevel)))) }
        for id in s.kit where researchEffects[id] != nil { out.append(("kit:\(id)", 1)) }
        return out
    }

    // MARK: RL lab

    /// Cash to build the next RL lab level (level 1 opens the lab).
    static func rlLabCost(_ s: GameState) -> Double? {
        guard s.rlLabLevel < rlMaxLevel else { return nil }
        let scale = interpolate([(2016, 2.5e6), (2017, 3e6), (2020, 8e6), (2022, 15e6), (2026, 40e6), (2030, 150e6)], at: s.year)
        return (scale * 0.12 * pow(2, Double(s.rlLabLevel)) / 10_000).rounded() * 10_000
    }

    /// What the RL lab adds at a level, one line per effect.
    static func rlLabEffects(level: Int) -> [String] {
        guard level > 0 else { return [] }
        return rlLabPerLevel.map { ResearchCatalog.describe($0, r: Double(level)) }
    }

    // MARK: New game

    /// Before the seed round is priced: cards that change how much cash the founders start with.
    static func preSeed(_ s: inout GameState, _ settings: NewGameSettings) {
        guard !settings.kit.isEmpty else { return }
        if settings.kit.contains("bootstrapped") { s.cash *= 0.5 }
    }

    /// Day one: grant what the chosen cards promise. Does nothing for an empty kit (other than Genius mode or quests).
    static func setup(_ s: inout GameState, _ settings: NewGameSettings) {
        s.questsOn = settings.starterQuests
        let kit = settings.kit.filter { byID[$0] != nil }
        guard !kit.isEmpty || settings.kitMode == .genius else { return }
        s.kit = kit
        s.kitMode = settings.kitMode.rawValue
        let start = s.date
        let y = s.year
        let base = (Era.all.first { $0.id == s.eraID }?.cash ?? 15_000_000) * s.difficulty.cashMultiplier
        var lines: [String] = []

        // Money
        if kit.contains("rich_uncle") {
            s.cash += base
            lines.append("\(Fmt.money(base)) from your uncle")
        }
        if kit.contains("sovereign") {
            let amount = base * 4
            let shares = s.totalShares * 0.25   // 20% after the deal
            s.cash += amount
            s.holdings.append(Holding(name: "Meridian Sovereign Fund", shares: shares))
            s.valuation += amount
            lines.append("\(Fmt.money(amount)) from the Meridian Sovereign Fund for 20%")
        }
        if kit.contains("cloud_credits") {
            s.cloudCredits += base
            lines.append("\(Fmt.money(base)) of cloud credits")
        }

        // Compute
        if kit.contains("angel_cluster"), let gi = s.sites.firstIndex(where: { $0.kind == .garage }), let batch = s.owned.first {
            s.sites[gi].capacityKW *= 4
            s.owned.append(OwnedBatch(accelID: batch.accelID, count: 12, siteID: s.sites[gi].id, purchased: start, unitCost: batch.unitCost))
            Sim.mergeOwned(&s)
            lines.append("12 more \(HardwareCatalog.get(batch.accelID)?.name ?? "GPUs") in a rewired garage")
        }
        if kit.contains("dc_in_a_box") {
            let locationID = s.sites.first?.locationID ?? "nova"
            let hall = Site(name: "\(s.companyName) colo hall", kind: .colo, locationID: locationID, capacityKW: 250,
                            cooling: .air, powerDeal: .grid, opened: start, ready: start, capex: 0, monthlyFee: 0)
            s.sites.append(hall)
            let chips = HardwareCatalog.all.filter { $0.cls == .datacenter && $0.purchasable && !$0.liquid && $0.available <= start.ym
                && ($0.discontinued.map { $0 > start.ym } ?? true) }
                .max { $0.bf16 < $1.bf16 }
            if let a = chips, let price = a.price {
                let byCash = Int(base * 0.5 / price)
                let byPower = Int(250_000 / (a.tdpW * 1.4))
                let n = max(8, min(byCash, byPower, 256) / 8 * 8)
                s.owned.append(OwnedBatch(accelID: a.id, count: n, siteID: hall.id, purchased: start, unitCost: price))
                lines.append("a rent-free 250 kW colo hall with \(n)× \(a.name)")
            } else {
                lines.append("a rent-free 250 kW colo hall")
            }
        }

        // Talent
        func join(_ id: String, _ role: Role, _ skill: Double, _ trait: TalentTrait?, star: Bool, pay: Double = 1.4) {
            let k = "kit|\(s.peopleSalt)|\(s.companyName)|\(id)"
            let first = NameBank.first[Int(RivalIntel.unit(k + "|f") * Double(NameBank.first.count)) % NameBank.first.count]
            let last = NameBank.last[Int(RivalIntel.unit(k + "|l") * Double(NameBank.last.count)) % NameBank.last.count]
            var e = Employee(name: "\(first) \(last)", role: role, skill: skill, salary: (Macro.salary(role, y) * pay / 1000).rounded() * 1000,
                             morale: 88, hired: start, star: star, equity: star ? 0.5 : 0.1)
            if let trait { e.trait = trait.rawValue }
            s.employees.append(e)
            lines.append("\(e.name) (\(role.title.lowercased())\(trait.map { ", \($0.title)" } ?? ""))")
        }
        if kit.contains("star_visionary") { join("visionary", .researcher, 88, .visionary, star: true) }
        if kit.contains("star_kernel") { join("kernel", .mlEngineer, 85, .kernelWizard, star: true) }
        if kit.contains("safety_lead") { join("safety", .safety, 82, .redTeamer, star: true) }
        if kit.contains("data_curator") { join("curator", .data, 84, .curator, star: true) }
        if kit.contains("enterprise_rolodex") { join("rainmaker", .sales, 80, .rainmaker, star: true) }
        if kit.contains("defectors") {
            for (i, skill) in [76.0, 73, 70].enumerated() { join("defector\(i)", .researcher, skill, nil, star: false, pay: 1.2) }
            join("defector_infra", .infra, 72, nil, star: false, pay: 1.2)
        }

        // Brand
        if kit.contains("viral_launch") { s.brand = min(100, s.brand + 15) }
        if kit.contains("hype_merchant") { s.brand = min(100, s.brand + 8) }

        // Research
        var known: [String] = []
        func learn(_ id: String) {
            guard let item = ResearchCatalog.byID[id], !s.researched.contains(id) else { return }
            for p in item.prereqs { learn(p) }
            s.researched.insert(id)
            s.researchResults[id] = 1
            s.researchProgress[id] = nil
            s.researchQueue.removeAll { $0 == id }
            known.append(item.name)
        }
        if kit.contains("rlhf_pipeline") { for id in ["instruction_tuning", "rlhf", "dpo"] { learn(id) } }
        if kit.contains("prodigy") {
            for _ in 0..<3 {
                let next = (s.researchQueue.first { ResearchCatalog.byID[$0] != nil })
                    ?? ResearchCatalog.core.filter { !s.researched.contains($0.id) && $0.category != .frontier && $0.prereqs.allSatisfy { s.researched.contains($0) } }
                        .min { $0.year < $1.year }?.id
                if let next { learn(next) }
            }
        }
        if !known.isEmpty {
            if s.autoResearch { ResearchLab.fillQueue(&s) }
            ResearchLab.checkFusions(&s)
            lines.append("already known: " + known.joined(separator: ", "))
        }
        let rl = min(rlMaxLevel, kit.reduce(0) { $0 + rlLevels($1) })
        if rl > 0 {
            s.rlLabLevel = rl
            lines.append("an RL lab at level \(rl)")
        }
        if kit.contains("alien_signal") {
            s.xenoInsight += 0.4 * XenoScience.insightNeeded(s)
            Sim.news(&s, "A weight file nobody trained",
                     "An old drive from your lab's first server holds a model whose layers don't match any known architecture. Nobody knows where it came from. Your team has started to read it: you're 40% of the way to your first alien architecture.",
                     .research, image: "wafer_closeup", important: true, good: true)
        }
        let mult = researchMultiplier(s)
        if mult > 1 { lines.append("research ×\(Fmt.trim(mult, 1))") }

        let names = cards(kit).map(\.name)
        let title = settings.kitMode == .genius ? "Genius mode: your founding kit" : "Your founding kit"
        let body = (names.isEmpty ? "No cards, just raw speed." : names.joined(separator: " · ") + ".")
            + (lines.isEmpty ? "" : " On day one: " + lines.joined(separator: "; ") + ".")
        Sim.news(&s, title, body, .company, image: "supercomputer", important: true, good: true)
    }

    // MARK: Daily: starter quests

    /// Starter quests run for the first three years of a game that has them.
    static func questsActive(_ s: GameState) -> Bool {
        s.questsOn && s.date.timeIntervalSince(s.startDate) < 3 * 365 * 86_400
    }

    static func daily(_ s: inout GameState) {
        guard questsActive(s) else { return }
        let steps = EraGuide.steps(s)
        for step in steps where step.done && !step.key.isEmpty && !s.questsDone.contains(step.key) {
            guard let reward = questReward(step.key) else { continue }
            s.questsDone.insert(step.key)
            grant(&s, reward, quest: step.title)
        }
    }

    static func grant(_ s: inout GameState, _ r: QuestReward, quest: String) {
        let base = (Era.all.first { $0.id == s.eraID }?.cash ?? 15_000_000) * s.difficulty.cashMultiplier
        var got: [String] = []
        if r.cash > 0 {
            let amount = (base * r.cash / 10_000).rounded() * 10_000
            s.cash += amount
            s.month.oneOffIncome += amount
            got.append("a \(Fmt.money(amount)) grant")
        }
        if r.credits > 0 {
            let amount = (base * r.credits / 10_000).rounded() * 10_000
            s.cloudCredits += amount
            got.append("\(Fmt.money(amount)) of cloud credits")
        }
        if r.researchDays > 0, let current = s.researchQueue.first {
            let rp = r.researchDays * max(s.rpToday, 5)
            s.researchProgress[current, default: 0] += rp
            got.append("\(Fmt.count(rp)) research points on \(ResearchLab.entryName(current))")
        }
        if r.brand > 0 {
            s.brand = min(100, s.brand + r.brand)
            got.append("+\(Int(r.brand)) brand")
        }
        if r.culture > 0 {
            s.culturePoints += r.culture
            got.append("+\(r.culture) culture point\(r.culture == 1 ? "" : "s")")
        }
        if r.confidence > 0 {
            s.boardConfidence = min(100, s.boardConfidence + r.confidence)
            got.append("+\(Int(r.confidence)) board confidence")
        }
        if r.rlLevels > 0 && s.rlLabLevel < rlMaxLevel {
            s.rlLabLevel = min(rlMaxLevel, s.rlLabLevel + r.rlLevels)
            got.append("RL lab level \(s.rlLabLevel)")
        }
        guard !got.isEmpty else { return }
        Sim.news(&s, "Quest complete: \(quest)", "Reward: " + got.joined(separator: ", ") + ".", .company, good: true)
    }
}

extension GameState {
    /// Build the next level of the RL lab (level 1 opens it).
    mutating func upgradeRLLab() -> String? {
        guard let cost = FoundingKit.rlLabCost(self) else { return "Your RL lab is at its top level." }
        if cash < cost { return "The next RL lab level costs \(Fmt.money(cost)); you have \(Fmt.money(cash))." }
        cash -= cost
        month.capex += cost
        rlLabLevel += 1
        let lvl = rlLabLevel
        Sim.news(&self, lvl == 1 ? "Your RL lab opens" : "RL lab reaches level \(lvl)",
                 (lvl == 1 ? "Environments, reward models and a team to tune them. " : "More environments, sharper reward models. ")
                    + FoundingKit.rlLabEffects(level: lvl).joined(separator: " · ") + " in total.",
                 .research, image: "wafer_closeup", good: true)
        return nil
    }
}
