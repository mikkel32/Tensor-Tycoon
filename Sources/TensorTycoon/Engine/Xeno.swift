import Foundation

/// Alien architectures: designs found by agent swarms or self-improving models in parts of the design space humans
/// never search. Each one is a model architecture (far more compute-efficient) plus a chip that costs a few percent of
/// an NVIDIA part to make. Keep it, sell the chips, or license the blueprint.
enum Xeno {
    static let names = ["Xenolattice", "Hollow Spiral", "Mycelial Mesh", "Tesseract Fabric", "Glass Choir", "Silent Braid",
                        "Fractal Reef", "Möbius Engine", "Obsidian Bloom", "Echo Lattice", "Quiet Storm", "Paper Moon"]

    /// Insight needed for the next discovery (each one is three times harder).
    static func insightNeeded(_ s: GameState) -> Double { 6_000 * pow(3, Double(s.alienArchs.count)) }

    static func best(_ s: GameState) -> AlienArch? { s.alienArchs.max { $0.computeGain < $1.computeGain } }
    static func bestGain(_ s: GameState) -> Double { best(s)?.computeGain ?? 0 }
    static func bestLegibility(_ s: GameState) -> Double { best(s).map { legibility($0, s) } ?? 1 }

    /// Legibility after your interpretability research.
    static func legibility(_ a: AlienArch, _ s: GameState) -> Double { min(0.95, a.legibility + s.bonuses.legibility) }

    /// One-time cost to tape out an alien chip. The agents already wrote the RTL.
    static func fabCost(_ s: GameState) -> Double { 2.5e8 }

    static func fabDays(_ s: GameState, _ b: ResearchBonuses) -> Double {
        150 * (1 - 0.35 * s.swarmSilicon) * (b.has(.customSilicon) ? 1 : 1.3) * max(0.4, 1 - s.traits.chipDesign)
    }

    // MARK: Daily

    static func daily(_ s: inout GameState, _ b: ResearchBonuses) {
        if s.xenoInsightToday > 0 {
            s.xenoInsight += s.xenoInsightToday
            if s.xenoInsight >= insightNeeded(s) { discover(&s, b) }
        }
        for i in s.alienArchs.indices where s.alienArchs[i].fabbing {
            s.alienArchs[i].fabDaysLeft -= 1
            guard s.alienArchs[i].fabDaysLeft <= 0 else { continue }
            let respinP = 0.12 * (1 - 0.5 * s.swarmSilicon)
            if s.alienArchs[i].fabRespins < 2 && s.rng.chance(respinP) {
                s.alienArchs[i].fabRespins += 1
                s.alienArchs[i].fabDaysLeft = 60 * (1 - 0.35 * s.swarmSilicon)
                Sim.news(&s, "\(s.alienArchs[i].name) chip needs a respin",
                         "First silicon works, but a clock-domain bug the agents didn't anticipate halves yields. Two more months.",
                         .hardware, image: "wafer", important: true, good: false)
                continue
            }
            finishFab(&s, i)
        }
    }

    static func discover(_ s: inout GameState, _ b: ResearchBonuses) {
        let needed = insightNeeded(s)
        let g = s.alienArchs.count + 1
        let luck = s.rng.gaussian()
        var legibility = 0.45 - 0.1 * Double(g - 1) + 0.1 * s.rng.gaussian() + 0.15 * s.swarmSafety
        if s.researched.contains("interpretability") { legibility += 0.08 }
        if b.has(.aiControl) { legibility += 0.05 }
        let used = Set(s.alienArchs.map(\.name))
        let name = names.first { !used.contains($0) } ?? "Xeno-\(g)"
        let arch = AlienArch(name: name, generation: g, discovered: s.date,
                             computeGain: clamp(0.35 + 0.12 * Double(g - 1) + 0.08 * luck, 0.2, 0.95),
                             chipPerf: clamp(2.5 + 1.2 * Double(g - 1) + 0.5 * luck, 1.6, 9),
                             costFactor: clamp(0.07 - 0.01 * Double(g - 1) - 0.012 * luck, 0.02, 0.12),
                             powerFactor: clamp(0.7 - 0.05 * Double(g - 1), 0.4, 0.9),
                             legibility: clamp(legibility, 0.05, 0.9))
        s.alienArchs.append(arch)
        s.xenoInsight = max(0, s.xenoInsight - needed)
        Achievements.unlock(&s, "first_contact")
        Sim.news(&s, "Your agents found an alien architecture: \(arch.name)",
                 "A model design worth ×\(Fmt.trim(arch.multiplier, 1)) training compute and a chip with ~\(Fmt.trim(arch.chipPerf, 1))× the throughput of today's best GPU at ~\(Int(arch.costFactor * 100))% of its cost. Humans can follow about \(Int(arch.legibility * 100))% of it. Decide what to do with it on the Alien Tech page.",
                 .research, image: "wafer_closeup", important: true, good: true)
    }

    static func finishFab(_ s: inout GameState, _ i: Int) {
        let arch = s.alienArchs[i]
        let ref = Silicon.reference(s)
        let perf = arch.chipPerf
        let refPrice = ChipBusiness.listPrice(ref, s)
        let chip = CustomChip(
            id: "alien_\(arch.id.uuidString.prefix(8))",
            name: "\(s.companyName.split(separator: " ").first ?? "Xeno") \(arch.name)",
            focus: .training, available: s.date, process: Silicon.process(s.year),
            memoryGB: (ref.memoryGB * 1.5 / 8).rounded() * 8, memoryType: "Stacked SRAM + \(ref.memoryType)",
            bandwidthTBs: ref.bandwidthTBs * max(1.5, perf * 0.8),
            bf16: ref.bf16 * perf, fp8: max(ref.fp8, ref.bf16 * 2) * perf, fp4: (ref.fp4 > 0 ? ref.fp4 : ref.bf16 * 4) * perf,
            tdpW: ref.tdpW * arch.powerFactor, unitCost: max(300, refPrice * arch.costFactor),
            decodeEff: 0.85, scaleUp: 1_024, generation: arch.generation, alien: true)
        s.customChips.append(chip)
        HardwareCatalog.register(s.customChips)
        s.alienArchs[i].fabbing = false
        s.alienArchs[i].fabDaysLeft = 0
        s.alienArchs[i].chipID = chip.id
        if s.alienArchs[i].policy == .sellChips { ChipBusiness.ensureLine(&s, chipID: chip.id) }
        Achievements.unlock(&s, "xeno_chip")
        Achievements.unlock(&s, "silicon")
        Sim.news(&s, "\(chip.name) is in production",
                 "\(Fmt.trim(perf, 1))× a \(ref.name) for \(Fmt.money(chip.unitCost)) a chip. Order it in the Hardware Store, or sell it to big players from Chip & Cloud Sales.",
                 .hardware, image: "wafer", important: true, good: true)
    }

    // MARK: Monthly: royalties, offers, rival integration

    static func monthly(_ s: inout GameState) {
        for i in s.alienArchs.indices {
            for li in s.alienArchs[i].licenses.indices where s.alienArchs[i].licenses[li].monthsLeft > 0 {
                let r = s.alienArchs[i].licenses[li].royaltyMonthly
                s.cash += r
                s.month.revLicensing += r
                s.lifetimeRevenue += r
                s.alienArchs[i].licenses[li].monthsLeft -= 1
            }
            let today = s.date
            s.alienArchs[i].offers.removeAll { ($0.expires ?? .distantPast) < today }
            guard s.alienArchs[i].policy == .license, s.alienArchs[i].offers.count < 3 else { continue }
            let taken = Set(s.alienArchs[i].licenses.map(\.buyerID) + s.alienArchs[i].offers.map(\.buyerID))
            var pool = BigPlayerCatalog.buyers(s, includeRivals: true).map(\.id).filter { !taken.contains($0) }
            pool.shuffle(using: &s.rng)
            for buyer in pool.prefix(2) where s.rng.chance(0.35) {
                let t = licenseTerms(s, s.alienArchs[i], buyer: buyer)
                let offer = ArchLicense(buyerID: buyer, buyerName: BigPlayerCatalog.name(buyer), signed: s.date, upfront: t.upfront,
                                        royaltyMonthly: t.royalty, monthsLeft: 36, effective: GameCalendar.addDays(s.date, 180),
                                        expires: GameCalendar.addDays(s.date, 45))
                s.alienArchs[i].offers.append(offer)
                Sim.news(&s, "License offer: \(offer.buyerName) wants \(s.alienArchs[i].name)",
                         "\(Fmt.money(t.upfront)) upfront plus \(Fmt.money(t.royalty))/month for 3 years. Expires in 45 days.",
                         .finance, image: "sf_skyline", important: true, good: true)
            }
        }
        for i in s.competitors.indices { s.competitors[i].armedH100e *= 0.97 }
    }

    static func licenseTerms(_ s: GameState, _ arch: AlienArch, buyer: String) -> (upfront: Double, royalty: Double) {
        let scale: Double
        if let def = CompetitorCatalog.byID[buyer] {
            scale = clamp(def.computeShare / 0.12, 0.3, 1.6)
        } else {
            scale = clamp((BigPlayerCatalog.neutral.first { $0.id == buyer }?.weight ?? 0.15) / 0.18, 0.4, 1.6)
        }
        let upfront = Macro.frontierValuation(s.year) * 0.005 * arch.computeGain * scale * clamp(s.market.hype / 1.3, 0.6, 1.5)
        return (upfront, upfront * 0.012)
    }

    /// What exclusive (or partly exclusive) alien tech adds to your valuation.
    static func moatValue(_ s: GameState) -> Double {
        s.alienArchs.reduce(0) { acc, a in
            let f = a.licensedOnce ? 0.35 : (a.policy == .sellChips ? 0.6 : 1.0)
            return acc + Macro.frontierValuation(s.year) * 0.04 * a.computeGain * f
        }
    }

    /// Capability a rival gains from your licenses and chips by `date`.
    static func rivalC(_ s: GameState, _ lab: String, at date: Date) -> Double {
        var c = 0.0
        for a in s.alienArchs {
            if a.licenses.contains(where: { $0.buyerID == lab && $0.effective <= date }) { c = max(c, a.computeGain * 0.6) }
            // Running thousands of your alien chips teaches their compiler team how the architecture thinks.
            if let chip = a.chipID, let line = s.chipLines.first(where: { $0.chipID == chip }), (line.buyerUnits[lab] ?? 0) >= 10_000 {
                c = max(c, a.computeGain * 0.35)
            }
        }
        if let comp = s.competitors.first(where: { $0.id == lab }), comp.armedH100e > 0 {
            c += log10(1 + comp.armedH100e / max(1, comp.computeH100e))
        }
        return c
    }

    /// Labs whose models already benefit from your alien tech.
    static func armedRivals(_ s: GameState) -> [String] {
        s.competitors.filter { rivalC(s, $0.id, at: s.date) > 0.01 }.map(\.id)
    }
}

// MARK: - Player actions

extension GameState {
    mutating func fabAlienChip(_ id: UUID) -> String? {
        guard let i = alienArchs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        if alienArchs[i].chipID != nil { return "This chip is already in production." }
        if alienArchs[i].fabbing { return "The tape-out is already under way." }
        let cost = Xeno.fabCost(self)
        if cost > cash { return "Masks, packaging and bring-up cost \(Fmt.money(cost))." }
        cash -= cost
        month.capex += cost
        alienArchs[i].fabbing = true
        alienArchs[i].fabDaysLeft = Xeno.fabDays(self, bonuses)
        Sim.news(&self, "Taping out the \(alienArchs[i].name) chip",
                 "The swarm's RTL went to the foundry. \(Fmt.money(cost)), first chips in about \(Int(alienArchs[i].fabDaysLeft / 30) + 1) months.",
                 .hardware, image: "wafer", important: true)
        return nil
    }

    mutating func setXenoPolicy(_ id: UUID, _ policy: XenoPolicy) -> String? {
        guard let i = alienArchs.firstIndex(where: { $0.id == id }) else { return "Not found." }
        let old = alienArchs[i].policy
        guard old != policy else { return nil }
        alienArchs[i].policy = policy
        if let chip = alienArchs[i].chipID {
            if policy == .sellChips {
                ChipBusiness.ensureLine(&self, chipID: chip)
            } else if let li = chipLines.firstIndex(where: { $0.chipID == chip }) {
                chipLines[li].active = false
            }
        }
        if policy != .license { alienArchs[i].offers = [] }
        let note: String
        switch policy {
        case .exclusive: note = alienArchs[i].licensedOnce ? "No new licenses — but existing licensees keep what they learned." : "Nobody else gets it."
        case .sellChips: note = alienArchs[i].chipID == nil ? "Tape out the chip to start selling." : "Set prices and fab capacity in Chip & Cloud Sales."
        case .license: note = "Big players will send offers over the coming months."
        }
        Sim.news(&self, "\(alienArchs[i].name): \(policy.rawValue.lowercased())", note, .company)
        return nil
    }

    mutating func acceptLicense(_ archID: UUID, offer offerID: UUID) -> String? {
        guard let i = alienArchs.firstIndex(where: { $0.id == archID }),
              let oi = alienArchs[i].offers.firstIndex(where: { $0.id == offerID }) else { return "Not found." }
        var l = alienArchs[i].offers.remove(at: oi)
        l.signed = date
        l.effective = GameCalendar.addDays(date, 180)
        l.expires = nil
        alienArchs[i].licenses.append(l)
        alienArchs[i].licensedOnce = true
        cash += l.upfront
        month.oneOffIncome += l.upfront
        lifetimeRevenue += l.upfront
        if !BigPlayerCatalog.isRival(l.buyerID) {
            // Clouds build it into their fleets: compute gets cheaper for everyone, you included.
            market.rentPrice = max(0.5, market.rentPrice - 0.04)
            market.hardwarePrice = max(0.5, market.hardwarePrice - 0.02)
        }
        Achievements.unlock(&self, "licensor")
        Sim.news(&self, "Licensed \(alienArchs[i].name) to \(l.buyerName)",
                 "\(Fmt.money(l.upfront)) upfront and \(Fmt.money(l.royaltyMonthly))/month. \(BigPlayerCatalog.isRival(l.buyerID) ? "Their models will use it in about six months." : "Their clouds will run it in about six months.")",
                 .finance, image: "sf_skyline", important: true, good: true)
        return nil
    }

    mutating func declineLicense(_ archID: UUID, offer offerID: UUID) {
        guard let i = alienArchs.firstIndex(where: { $0.id == archID }) else { return }
        alienArchs[i].offers.removeAll { $0.id == offerID }
    }
}
