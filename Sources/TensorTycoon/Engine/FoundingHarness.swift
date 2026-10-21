import Foundation

/// 3.9: `--founding [days] [era:country …]`: the founding award each new game is offered (every era × home country),
/// then a simple bot plays the listed games for `days` — hiring, training what the run planner proposes and releasing
/// it — printing the award's events, reviews and payments as they happen.
enum FoundingHarness {
    static func main(_ args: [String]) -> Int32 {
        let days = args.first.flatMap { Int($0) } ?? 0
        var games = args.dropFirst().filter { $0.contains(":") }
        print("== Founding awards offered at the start ==")
        for era in ["2017", "2020", "2022", "2026"] {
            for country in ["us", "dk", "fr", "it", "ro"] {
                let s = game(era: era, country: country)
                guard let c = s.founding.current else { print("\(era) \(country): NO OFFER"); continue }
                print("\(era) \(country) [tier \(FoundingContracts.tier(s))]:")
                for l in FoundingContracts.describe(s, c) { print(l) }
            }
        }
        guard days > 0 else { return 0 }
        if games.isEmpty { games = ["2017:us", "2020:dk", "2022:fr", "2026:it", "2022:ro"] }
        var failures = 0
        for g in games {
            let p = g.split(separator: ":").map(String.init)
            var s = game(era: p[0], country: p[1])
            var seen: [String: Int] = [:]
            func events(status: Bool = false) {
                for c in s.founding.contracts.reversed() {
                    let n = c.history.count, k = seen[c.id] ?? 0
                    if n > k { for e in c.history.prefix(n - k).reversed() { print("\(e.date.gameShort) \(c.agencyShort) P\(c.phase): \(e.text)") } }
                    seen[c.id] = n
                }
                if status, GameCalendar.components(s.date).day == 1, let c = s.founding.current { print("\(s.date.gameShort) " + FoundingContracts.statusLine(s, c)) }
            }
            print("\n== \(p[0]) \(p[1]): playing \(days) days ==")
            for day in 0..<days where s.gameOver == nil {
                for _ in 0..<10 {
                    guard let d = s.decisions.first else { break }
                    s.resolveDecision(d.id, option: d.kind == "acquisition" ? d.options.count - 1 : 0)
                }
                if day % 45 == 5, let c = s.candidates.filter({ ($0.role == .researcher || $0.role == .mlEngineer) && $0.salary * 4 < s.cash }).max(by: { $0.skill < $1.skill }) {
                    _ = s.hire(c.id)
                }
                if !s.runs.contains(where: { $0.status == .running || $0.status == .postTraining || $0.status == .paused }) {
                    // Nothing to train on: rent a few datacenter chips while the cash lasts.
                    if RunPlanner.proposals(s).isEmpty, s.cash > 2e6,
                       let a = HardwareCatalog.all.filter({ Economy.canRent($0, s) && $0.cls == .datacenter }).max(by: { $0.trainTFLOPS(.bf16) < $1.trainTFLOPS(.bf16) }) {
                        _ = s.rentHardware(a.id, count: 8, term: .onDemand)
                    }
                    if let first = RunPlanner.proposals(s).first { _ = RunPlanner.start(first, &s) }
                }
                for m in s.models where !m.released { _ = s.release(m.id, api: true, openWeights: false) }
                events()
                Sim.advanceDay(&s)
                events(status: true)
            }
            print("models: " + s.models.map { "\($0.name) c=\(Fmt.trim($0.c, 2)) idx \(Fmt.score($0.index)) (\($0.created.gameShort))" }.joined(separator: "; "))
            for c in s.founding.contracts.reversed() { print(FoundingContracts.statusLine(s, c)) }
            print("contract revenue booked: \(Fmt.money(s.founding.lifetimePaid)) · Advanced Projects record: \(s.advanced.ratings.map { "\($0.key) \(Fmt.trim($0.value, 1))" }.sorted().joined(separator: ", "))")
            if s.founding.contracts.isEmpty { failures += 1 }
        }
        return failures == 0 ? 0 : 1
    }

    static func game(era: String, country: String) -> GameState {
        var st = NewGameSettings(companyName: "Founding Labs", founderName: "Bot", eraID: era, difficulty: .normal)
        st.hqCountry = country
        st.hqCity = CountryCatalog.get(country).cities[0].id
        return NewGame.create(st, seed: 7)
    }
}
