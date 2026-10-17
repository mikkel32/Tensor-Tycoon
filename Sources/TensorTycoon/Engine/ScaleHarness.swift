import Foundation

/// `--scale`: gigawatt campuses, 500K-GPU training runs watched (or not) by ops agents, and what agents of
/// different model generations are worth on each mission.
extension BalanceHarness {
    static func scale() {
        campusCheck()
        hugeRunCheck()
        swarmIntelligenceCheck()
    }

    static func campusCheck() {
        print("== Campuses: how big, how fast, what it costs ==")
        for y in [2026.0, 2030.0, 2035.0] {
            var s = NewGame.create(NewGameSettings(companyName: "Probe Labs", founderName: "Bot", eraID: "2026", difficulty: .normal), seed: 80)
            s.date = GameCalendar.date(Int(y), 3, 1)
            let caps = PowerDeal.allCases.map { d in "\(d.rawValue) \(d.available(s) ? Fmt.watts(Campus.siteCapMW(LocationCatalog.byID["texas"]!, d, s) * 1e6) : "—")" }
            print("  \(Int(y)) Abilene caps: " + caps.joined(separator: " · "))
        }
        // A 10 GW gas campus started in 2027, watched until it's fully built.
        var s = NewGame.create(NewGameSettings(companyName: "Probe Labs", founderName: "Bot", eraID: "2026", difficulty: .normal), seed: 81)
        while s.year < 2027 { Sim.advanceDay(&s); s.decisions.removeAll(); s.gameOver = nil }
        s.cash = 5e11
        if let err = s.buildSite(kind: .datacenter, locationID: "texas", capacityKW: 10_000_000, cooling: .liquid, power: .gas, name: "Gigacampus") {
            print("  build error: \(err)")
            return
        }
        let start = s.date
        var last = -1.0
        while s.sites.contains(where: { $0.name == "Gigacampus" && ($0.plannedKW > 0 || $0.expanding > 0 || !$0.isReady(s.date)) }) && s.year < 2036 {
            Sim.advanceDay(&s)
            s.decisions.removeAll()
            s.gameOver = nil
            s.cash = max(s.cash, 5e11)
            if let site = s.sites.first(where: { $0.name == "Gigacampus" }), site.isReady(s.date), site.capacityKW != last {
                last = site.capacityKW
                print("    \(s.date.gameShort): \(Fmt.watts(site.capacityKW * 1000)) online, \(Fmt.watts(site.expanding * 1000)) building, \(Fmt.watts(site.plannedKW * 1000)) planned · capex so far \(Fmt.money(site.capex))")
            }
        }
        print("  10 GW gas campus fully built in \(Fmt.trim(Double(GameCalendar.daysBetween(start, s.date)) / 30.4, 0)) months")
        // Limits, selling and moving.
        print("  allocation per order at $1T valuation: " + ["b200", "h100"].compactMap { id -> String? in
            guard let a = HardwareCatalog.get(id) else { return nil }
            var t = s
            t.valuation = 1e12
            return "\(a.name) \(Fmt.int(Economy.allocationLimit(a, t)))"
        }.joined(separator: " · "))
        if let site = s.sites.first(where: { $0.name == "Gigacampus" }) {
            let ref = Silicon.reference(s)
            print("  max order of \(ref.name) for it: \(Fmt.int(Campus.maxOrder(ref, site: site, s)))")
            s.owned.append(OwnedBatch(accelID: ref.id, count: 1_000, siteID: site.id, purchased: s.date, unitCost: ref.price ?? 30_000))
            print("  sell with chips inside: \(s.sellSite(site.id) ?? "sold?!")")
            if let other = s.sites.first(where: { $0.id != site.id && $0.kind != .garage }) {
                print("  move to \(other.name): \(s.moveHardware(batchID: s.owned.last!.id, count: 1_000, to: other.id) ?? "moved")")
            } else {
                s.owned.removeAll { $0.siteID == site.id }
            }
            s.owned.removeAll { $0.siteID == site.id }
            let cash = s.cash
            print("  sell empty: \(s.sellSite(site.id) ?? "sold for \(Fmt.money(s.cash - cash))")")
        }
    }

    static func hugeRunCheck() {
        print("\n== 100K and 500K-GPU runs, with and without ops agents (2028 frontier lab) ==")
        for chips in [16_000, 100_000, 500_000] {
            for withAgents in [false, true] {
                var (s, modelID) = frontierLab(year: 2028, chips: chips + 200_000, seed: 82)
                let b = s.bonuses
                s.researched.formUnion(["checkpointing", "elastic", "optical_switching", "sdc_detection"])
                let ref = Silicon.reference(s)
                var d = ModelDesign()
                d.name = "Mega-\(chips / 1000)K"
                d.paramsB = 4_000
                d.activeFraction = 1.0 / 16
                d.tokensT = 200
                d.accelID = ref.id
                d.chips = chips
                d.precision = b.has(.fp8Training) && ref.fp8 > 0 ? .fp8 : .bf16
                let perDay = Double(chips) * ref.trainTFLOPS(d.precision) * 1e12 * Physics.mfu(accel: ref, chips: chips, state: s, bonuses: b) * 86_400
                d.tokensT = perDay * 90 / (6 * d.activeParamsB * 1e9) / 1e12
                if let err = s.startTraining(d) { print("  start error: \(err)"); continue }
                guard let m = s.models.first(where: { $0.id == modelID }) else { continue }
                var agents = 0
                if withAgents {
                    agents = Training.agentsForCoverage(m, chips: chips, s, s.bonuses)
                    let need = Swarms.chipsNeeded(m, accelID: ref.id, agents: agents, s, s.bonuses)
                    let runID = s.runs.last!.id
                    if let err = s.startSwarm(name: "Ops", modelID: modelID, agents: agents, mission: .trainingOps, accelID: ref.id,
                                              chips: min(need, Economy.freeChips(s, ref.id)), autonomy: 1, oversight: 0, targetRunID: runID) {
                        print("  swarm error: \(err)")
                    }
                }
                let i = s.runs.count - 1
                let before = s.runs[i].flopsDone
                for _ in 0..<30 {
                    Sim.advanceDay(&s)
                    for dd in s.decisions { s.resolveDecision(dd.id, option: 0) }
                    if s.runs[s.runs.count - 1].status == .paused { _ = s.setRunStatus(s.runs[s.runs.count - 1].id, .running) }
                    s.decisions.removeAll()
                    s.gameOver = nil
                    s.cash = max(s.cash, 5e10)
                }
                let r = s.runs[i]
                _ = before
                // Time lost to failures over the 30 days, and the steady-state goodput model.
                let failureTime = max(0, 1 - r.lostHours / (30 * 24))
                let model = Training.goodput(chips: chips, coverage: r.opsCoverage, state: s, bonuses: s.bonuses)
                print(String(format: "  %7@ chips %@: coverage %3d%% · uptime %3d%% (model %3d%%) · %4d interruptions, %5.0f h lost, %4.0f prevented · SDC caught %4.1f missed %4.1f · agents %@",
                             Fmt.int(chips) as NSString, (withAgents ? "with ops agents" : "no agents      ") as NSString,
                             Int(r.opsCoverage * 100), Int(failureTime * 100), Int(model * 100), r.interruptions, r.lostHours, r.prevented, r.sdcCaught, r.sdcMissed,
                             (withAgents ? Fmt.int(agents) : "—") as NSString))
            }
        }
    }

    static func swarmIntelligenceCheck() {
        print("\n== What an agent is worth, by model generation ==")
        for y in [2024.0, 2026.0, 2028.0, 2030.0] {
            let (s, id) = frontierLab(year: y, chips: 20_000, seed: 83)
            guard let m = s.models.first(where: { $0.id == id }) else { continue }
            let q = Swarms.quality(m, s)
            let missions = SwarmMission.allCases.map { "\($0.rawValue.components(separatedBy: " ").first ?? "") \(Fmt.trim(Swarms.quality(m, s, mission: $0), 2))" }
            print("  \(Int(y)) frontier model: \(Fmt.trim(q, 3)) researcher-eq/agent — \(Swarms.tier(q)), horizon \(Swarms.horizon(m)), "
                  + "autonomous \(Swarms.canRunAutonomous(m, s, s.bonuses) ? "yes" : "no")")
            print("    per mission: " + missions.joined(separator: " · "))
            print("    ops agents to cover 500K chips: \(Fmt.int(Training.agentsForCoverage(m, chips: 500_000, s, s.bonuses)))")
        }
    }
}
