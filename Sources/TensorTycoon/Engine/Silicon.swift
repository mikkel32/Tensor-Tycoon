import Foundation

/// Custom AI accelerator programs (like TPU, Trainium, Maia, MTIA): multi-year projects that end
/// with a chip only you can buy, at cost.
enum Silicon {
    static let codenames = ["Lumen", "Quasar", "Helix", "Nova", "Atlas", "Zephyr", "Orion", "Vega", "Cobalt", "Ember"]

    static func designerFactor(_ s: GameState) -> Double {
        let skill = s.employees.filter { $0.role == .chipDesigner }.reduce(0.0) { $0 + $1.weight }
        return min(1, skill / 20)
    }

    static func speed(_ p: ChipProject, _ s: GameState) -> Double {
        // > 1 means slower
        p.partner.speed * (1.25 - 0.35 * designerFactor(s)) * (1 - 0.3 * s.swarmSilicon) * max(0.4, 1 - s.traits.chipDesign)
    }

    static func totalDays(_ p: ChipProject, _ s: GameState) -> Double {
        ChipProject.phaseDays.reduce(0, +) * speed(p, s)
    }

    static func process(_ y: Double) -> String {
        switch y {
        case ..<2019: "TSMC 16nm"
        case ..<2021: "TSMC 7nm"
        case ..<2023: "TSMC 5nm"
        case ..<2025.5: "TSMC 4nm"
        case ..<2027.5: "TSMC 3nm"
        case ..<2029: "TSMC 2nm"
        default: "TSMC A16"
        }
    }

    /// Best purchasable NVIDIA/AMD datacenter part right now — the yardstick for your chip.
    static func reference(_ s: GameState) -> Accelerator {
        HardwareCatalog.all.filter { ($0.vendor == .nvidia || $0.vendor == .amd) && $0.cls == .datacenter && Economy.canBuy($0, s) }
            .max { $0.bf16 < $1.bf16 } ?? HardwareCatalog.h100
    }

    static func daily(_ s: inout GameState) {
        for i in s.chipProjects.indices where !s.chipProjects[i].done {
            let p = s.chipProjects[i]
            let perDay = p.budget / max(1, totalDays(p, s))
            if p.spent < p.budget * (1 + 0.25 * Double(p.respins)) {
                s.cash -= perDay
                s.month.costOther += perDay
                s.chipProjects[i].spent += perDay
            }
            s.chipProjects[i].phaseDaysLeft -= 1
            guard s.chipProjects[i].phaseDaysLeft <= 0 else { continue }
            // Phase complete
            if p.phase == 3 {
                let respinP = max(0.06, 0.3 - 0.07 * Double(p.generation - 1) - 0.1 * designerFactor(s) - (p.partner == .broadcom ? 0.05 : 0))
                if s.rng.chance(respinP) {
                    s.chipProjects[i].respins += 1
                    s.chipProjects[i].phaseDaysLeft = 120 * speed(p, s)
                    Sim.news(&s, "\(p.name) needs a respin", "First silicon came back with a timing bug in the matrix units. Another tape-out adds ~4 months and 25% to the budget.",
                             .company, image: "wafer", important: true, good: false)
                    continue
                }
            }
            if p.phase >= ChipProject.phases.count - 1 {
                finish(&s, i)
            } else {
                s.chipProjects[i].phase += 1
                s.chipProjects[i].phaseDaysLeft = ChipProject.phaseDays[s.chipProjects[i].phase] * speed(p, s)
                Sim.news(&s, "\(p.name): \(ChipProject.phases[s.chipProjects[i].phase]) started",
                         "Your silicon program moved to the next phase with \(p.partner.rawValue).", .company, image: "wafer_closeup")
            }
        }
    }

    static func finish(_ s: inout GameState, _ i: Int) {
        let p = s.chipProjects[i]
        let ref = reference(s)
        let budgetF = 0.15 * log10(max(p.budget, 1e7) / 1e8)
        var perf = 0.6 + budgetF + 0.08 * designerFactor(s) + p.partner.quality + 0.07 * Double(p.generation - 1) + 0.08 * s.swarmSilicon + 0.25 * s.traits.chipDesign
        perf = clamp(perf, 0.45, 1.3)
        let training = p.focus == .training
        let mem = ref.memoryGB * (training ? 1.0 : 1.25)
        let chip = CustomChip(
            id: "custom_\(p.id.uuidString.prefix(8))",
            name: "\(s.companyName.split(separator: " ").first ?? "Custom") \(p.name)",
            focus: p.focus, available: s.date, process: process(s.year),
            memoryGB: (mem / 8).rounded() * 8, memoryType: ref.memoryType, bandwidthTBs: ref.bandwidthTBs * perf * (training ? 1 : 1.1),
            bf16: ref.bf16 * perf * (training ? 1 : 0.7), fp8: max(ref.fp8, ref.bf16 * 2) * perf * (training ? 1 : 1.1),
            fp4: (ref.fp4 > 0 ? ref.fp4 : ref.bf16 * 4) * perf * (training ? 0.9 : 1.15),
            tdpW: ref.tdpW * (training ? 0.9 : 0.7), unitCost: (ref.price ?? 30_000) * 0.38 * p.partner.costFactor,
            decodeEff: training ? 0.65 : 0.78, scaleUp: training ? 128 : 64, generation: p.generation)
        s.customChips.append(chip)
        s.chipProjects[i].done = true
        HardwareCatalog.register(s.customChips)
        Achievements.unlock(&s, "silicon")
        Sim.news(&s, "Your chip is here: \(chip.name)",
                 "\(Int(perf * 100))% of a \(ref.name) at about \(Fmt.money(chip.unitCost)) per chip. Order it in the Hardware Store — only you can buy it.",
                 .hardware, image: "wafer", important: true, good: true)
    }
}

extension GameState {
    mutating func startChipProject(partner: ChipPartner, focus: ChipFocus, budget: Double) -> String? {
        guard bonuses.has(.customSilicon) else { return "Research Custom Accelerator Design first." }
        if chipProjects.contains(where: { !$0.done }) { return "Finish your current chip program first." }
        if budget < 50_000_000 { return "A serious chip program needs at least $50M." }
        if budget * 0.1 > cash { return "Keep at least 10% of the budget (\(Fmt.money(budget * 0.1))) in cash to start." }
        let gen = customChips.count + 1
        let name = "\(Silicon.codenames[(gen - 1) % Silicon.codenames.count]) v\(gen)"
        var p = ChipProject(name: name, partner: partner, focus: focus, budget: budget, started: date, phaseDaysLeft: 0, generation: gen)
        p.phaseDaysLeft = ChipProject.phaseDays[0] * Silicon.speed(p, self)
        chipProjects.append(p)
        Sim.news(&self, "Silicon program kicked off: \(name)",
                 "A \(focus.rawValue.lowercased()) accelerator with \(partner.rawValue), \(Fmt.money(budget)) budget. Expect ~\(Int(Silicon.totalDays(p, self) / 30)) months to volume.",
                 .company, image: "wafer", important: true)
        return nil
    }

    mutating func cancelChipProject(_ id: UUID) {
        chipProjects.removeAll { $0.id == id && !$0.done }
    }
}
