import Foundation

/// `--replay-save <file> [days] [tech…]`: load a real save, optionally queue techniques the way the Research
/// button does, and play it forward day by day, printing usable and waiting compute and how the research queue
/// moves. For chasing "I bought it but can't use it" and "the queue doesn't move" reports on a player's own game.
enum ReplayHarness {
    static func main(_ args: [String]) -> Int32 {
        guard let path = args.first else {
            print("usage: --replay-save <save.json> [days] [tech…]")
            return 1
        }
        let days = args.count > 1 ? Int(args[1]) ?? 7 : 7
        let techs = Array(args.dropFirst(2))
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)), var s = try? dec.decode(GameState.self, from: data) else {
            print("FAILED to load \(path)")
            return 1
        }
        StableID.resume(s)
        SaveMigration.migrate(&s)
        BenchmarkCatalog.resetCache()
        HardwareCatalog.register(s.customChips)
        for t in techs {
            if t.hasPrefix("order:") {
                let parts = t.split(separator: ":").map(String.init)
                let why = parts.count == 3 ? s.orderOwnChips(parts[1], count: Int(parts[2]) ?? 0) : "use order:<chip>:<count>"
                print(why.map { "could not order: \($0)" } ?? "ordered \(parts[2])× \(parts[1])")
                continue
            }
            if t.hasPrefix(Breakthroughs.refinePrefix) {
                _ = s.queueRefine(String(t.dropFirst(Breakthroughs.refinePrefix.count)))
            } else {
                s.queueResearch(t)
            }
            print(s.researchQueue.firstIndex(of: t).map { "queued \(t) at #\($0 + 1)" } ?? "could not queue \(t)")
        }
        report(s)
        for _ in 0..<days where s.gameOver == nil {
            for _ in 0..<10 {
                guard let d = s.decisions.first else { break }
                s.resolveDecision(d.id, option: 0)
            }
            Sim.advanceDay(&s)
            report(s)
        }
        return 0
    }

    private static func report(_ s: GameState) {
        let pools = Economy.pools(s)
        let usable = pools.reduce(0) { $0 + $1.owned }
        let waiting = Economy.waitingChips(s).reduce(0) { $0 + $1.count }
        let queue = s.researchQueue.prefix(4).map { e in
            "\(e) \(Int(s.researchProgress[e] ?? 0))/\(Int(ResearchLab.entryCost(s, e)))"
        }.joined(separator: ", ")
        print("\(s.date.gameShort): owned usable \(Fmt.int(usable)), idle \(Fmt.int(pools.reduce(0) { $0 + $1.free })), waiting \(Fmt.int(waiting)), research chips \(s.researchChips.values.reduce(0, +))"
              + " · \(Fmt.trim(s.rpToday, 1)) RP/day · queue: \(queue.isEmpty ? "empty" : queue)")
        let fab = s.orders.filter { AlienFab.isAlienChip($0.accelID) }
        if s.alienFab.exists {
            let own = s.owned.filter { AlienFab.isAlienChip($0.accelID) }.reduce(0) { $0 + $1.count }
            print("    fab \(Fmt.int(Int(s.alienFab.capacityMonth)))/mo · own chips installed \(Fmt.int(own)) · "
                  + (fab.isEmpty ? "no orders" : fab.map { "\(Fmt.int($0.count)) to come (\(Fmt.int($0.delivered ?? 0)) delivered), all by \($0.arrives.gameShort)" }.joined(separator: "; ")))
        }
    }
}
