import Foundation

/// 3.9: `--replay-save <save> <days> probe:training` checks the Model Lab and training fixes on a real save (on a copy
/// of the state; the replay itself is untouched): failed starts keep leases, family-job chip messages, release &
/// deploy in whole replicas, and extend previews at the run's real pace.
enum TrainingProbe {
    static func run(_ base: GameState) {
        var s = base
        guard let pool = Economy.pools(s).filter({ $0.accel.supportsTraining(.bf16) && $0.owned > 8 }).max(by: { $0.free + ($0.leased) < $1.free + ($1.leased) }) else {
            print("probe: no owned training pool"); return
        }
        let id = pool.accel.id
        // 1. A start that fails a late check keeps leased-out chips leased.
        let lease = max(1, (pool.free + (s.leases[id] ?? 0)) / 2)
        _ = s.setLease(id, chips: lease)
        let leasedBefore = s.leases[id] ?? 0, newsBefore = s.news.count
        var d = RunPlanner.bestRecipe(s, accel: pool.accel, chips: Economy.freeChips(s, id) + leasedBefore, days: 30, name: "Probe-1")
        d.mode = .finetune
        d.baseModelRef = nil
        let e = s.startTraining(d)
        let kept = (s.leases[id] ?? 0) == leasedBefore && s.news.count == newsBefore
        print("probe failed start: \(e ?? "started?!") · leases \(leasedBefore) → \(s.leases[id] ?? 0) · \(kept ? "PASS kept" : "FAIL lost")")

        // 3. Release & deploy: a finished, unreleased copy of your best model goes live in whole replicas.
        // (a copy of your best model, retired or not, so the probe works on a save where everything is retired).
        if var m = s.models.filter({ !$0.preview }).max(by: { $0.index < $1.index }) {
            m.id = StableID.next()
            m.name = "Probe-Release"
            m.released = false
            m.retired = false
            m.deployments = []
            var t = s
            t.models.append(m)
            // 2. Family jobs: no chips picked says so; fork and merge recall leases like the others.
            var f = t
            f.models[f.models.count - 1].released = true
            print("probe distil on no chips: \(f.startDistill(m.id, tier: .spark, data: .standard, accelID: "", chips: 1) ?? "started?!")")
            print("probe post-train blocker on no chips: \(Families.passPlan(f, model: f.models.last!, pass: .safety, accelID: "", chips: 1).blocker ?? "none")")
            let fl = f.leases[id] ?? 0
            let fe = f.startPostTrain(m.id, pass: .safety, accelID: id, chips: Economy.freeChips(f, id) + fl)
            print("probe post-train on leased chips: \(fe ?? "started") · leases \(fl) → \(f.leases[id] ?? 0)")
            let r = t.undoingOnError { st in
                if let e = st.release(m.id, api: true, openWeights: false, plan: st.launchDefault) { return e }
                if let e = st.launch(m.id, plan: st.launchDefault) { return e }
                return st.models.first(where: { $0.id == m.id })?.deployments.isEmpty ?? true ? "no replica fits" : nil
            }
            let live = t.models.first { $0.id == m.id }
            let deps = live?.deployments.map { dep -> String in
                let k = HardwareCatalog.get(dep.accelID).map { Physics.chipsPerReplica(m, accel: $0, precision: m.servingPrecision, bonuses: t.bonuses) } ?? 1
                return "\(dep.chips)× \(dep.accelID) (replica \(k), \(dep.chips % max(1, k) == 0 ? "whole" : "PARTIAL"))"
            }.joined(separator: ", ") ?? "rolled back"
            print("probe release & deploy: \(r ?? "ok") · \(deps) · chat on it: \(t.chatModelID == m.id)")
        }

        // 4. Extend / end-early previews at the run's real pace (goodput, LR speed), with every chip group billed.
        var u = base
        let fd = RunPlanner.bestRecipe(u, accel: pool.accel, chips: max(4, Economy.freeChips(u, id) + (u.leases[id] ?? 0)), days: 60, name: "Probe-2")
        if u.startTraining(fd) == nil, let i = u.runs.lastIndex(where: { $0.design.name == "Probe-2" }) {
            for _ in 0..<3 { Sim.advanceDay(&u) }
            let run = u.runs[i]
            let raw = Training.dailyFlops(run, state: u) * Sim.checkpointOverhead(run.interval)
            let real = Training.expectedFlopsPerDay(run, state: u)
            if let ext = TrainingInterventions.extendPreview(u, run, by: 0.1) {
                print("probe extend +10%: \(Fmt.trim(ext.days, 1)) days (old raw-pace preview \(Fmt.trim(ext.days * real / max(raw, 1), 1))) · goodput×LR \(Fmt.trim(real / max(raw, 1), 2)) · \(Fmt.money(ext.cost))")
            } else { print("probe extend: no preview (\(run.status))") }
        } else { print("probe extend: could not start a run: \(u.startTraining(fd) ?? "")") }
    }
}
