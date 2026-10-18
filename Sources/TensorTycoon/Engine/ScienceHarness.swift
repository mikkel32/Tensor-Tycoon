import Foundation

// MARK: - 3.6: science labs in the playtest bot (the `science` flag; without it the bot never touches science)

extension PTPlay {
    /// One lab, run sensibly: an Energy Research Lab at home once it's small next to the cash pile, staffed for its
    /// capacity, equipment upgraded while cheap, and a project in every free slot (easiest first) with a few agents
    /// and a little compute.
    static func science(_ s: inout GameState) {
        if s.science.labs.isEmpty {
            let site = ScienceCatalog.siteByID[s.hqCity] != nil ? s.hqCity : "sf"
            guard s.cash > 25 * Science.capex(.energy, site: site, s) else { return }
            _ = s.buildLab(.energy, site: site, staff: 8)
            return
        }
        let lab = s.science.labs[0]
        guard lab.isReady(s.date) else { return }
        let want = Int(Science.staffPerProject) * Science.capacity(lab)
        if lab.staff < want { _ = s.hireScientists(lab.id, want - lab.staff) }
        if lab.equipment < 3 && lab.upgradeReady == nil && s.cash > 40 * Science.upgradeCost(lab, s) { _ = s.upgradeLab(lab.id) }
        let agents = Science.agentScore(s) > 100 ? 8 : 0
        while Science.active(s.science.labs[0], s).count < Science.capacity(s.science.labs[0]),
              let next = Science.available(s.science.labs[0], s).first {
            if s.startScienceProject(next.id, lab: lab.id, agents: agents, compute: 1) != nil { break }
        }
    }

    /// Spin out what feeds a product line, publish mathematics, patent the rest.
    static func scienceChoice(_ dd: Decision, _ s: GameState) -> Int {
        let codes = dd.ref.split(separator: "|").last.map { $0.split(separator: ",").map(String.init) } ?? []
        guard let id = dd.ref.split(separator: "|").first.flatMap({ UUID(uuidString: String($0)) }),
              let d = s.science.discoveries.first(where: { $0.id == id })?.projectDef else { return 0 }
        let f = ScienceCatalog.field(d.field)
        if !f.product.isEmpty, let i = codes.firstIndex(of: SciChoice.spinout.rawValue) { return i }
        if d.field == .mathematics, let i = codes.firstIndex(of: SciChoice.publish.rawValue) { return i }
        return 0
    }

    static func scienceSummary(_ s: GameState, seed: UInt64) {
        let sc = s.science
        var byStatus: [String: Int] = [:]
        for p in sc.projects { byStatus[p.status.rawValue, default: 0] += 1 }
        let reruns = sc.projects.reduce(0) { $0 + $1.log.filter { $0.outcome == "rerun" }.count }
        print("SCIENCE seed \(seed): " + sc.labs.map { "\($0.name) eq\($0.equipment) staff \($0.staff) skill \(Int($0.skill))" }.joined(separator: ", "))
        print("  projects \(sc.projects.count): " + byStatus.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " ") + " · reruns \(reruns)")
        print("  spent: build \(m(sc.spentBuild)), running \(m(sc.spentRun)) · income: licences \(m(sc.licensing)), spin-outs \(m(sc.spinoutCash)) · last month cost \(m(sc.lastCost)), income \(m(sc.lastIncome))")
        for p in sc.projects {
            let d = p.projectDef
            let trail = p.log.map { "\(String(Science.stageName(SciStage(rawValue: $0.stage) ?? .hypothesis, d?.field ?? .energy).prefix(4)))\($0.outcome == "passed" ? "✓" : ($0.outcome == "rerun" ? "↺" : "✗"))" }.joined(separator: " ")
            print("  \(d?.name ?? p.def) [\(p.status.rawValue)] \(p.started.gameShort)→\(p.ended?.gameShort ?? "…") \(m(p.spent)): \(trail)")
        }
        for d in sc.discoveries {
            print("  ★ \(d.date.gameShort) \(d.title) · level \(Fmt.trim(d.level, 2)) · \(d.choice.isEmpty ? "pending" : d.choice)\(d.scooped.isEmpty ? "" : " · scooped by \(d.scooped)")\(d.commercialised.map { " · commercialised \($0.gameShort)" } ?? "")")
        }
        if let last = s.history.last, Science.powerFactor(s) < 1 {
            let without = last.costPower / Science.powerFactor(s)
            print("  power bill last month \(m(last.costPower)) (≈ \(m(without)) without the discoveries: saving \(m(without - last.costPower))/month)")
        }
        print("  effects: power bill ×\(Fmt.trim(Science.powerFactor(s), 3)) · battery capex ×\(Fmt.trim(Science.storageCapexFactor(s), 3)) · fusion \(Fmt.trim(Science.fusionPullIn(s), 2)) yr sooner · rival results \(sc.rivals.count) (scooped you \(sc.rivals.filter(\.scoopedYou).count))")
    }
}
