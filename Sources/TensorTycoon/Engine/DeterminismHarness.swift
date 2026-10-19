import Foundation

/// 3.7: determinism check.
///
///   TensorTycoon --determinism [days]
///
/// Plays the playtest bot for `days` (default 240) in each era twice with the same seed, in this process, and
/// compares a digest of the whole saved game; a third game with another seed must differ. Then saves the first game,
/// loads it back and plays on, twice, and compares again. A last game plays from a European headquarters with the
/// bot's optional systems switched on (advanced projects, science labs, the data economy), so their daily code is
/// checked too. Exits 1 on any mismatch.
/// (Cross-process determinism, which also catches Set / Dictionary iteration order, is checked by running a playtest
/// twice and diffing the output.)
enum DeterminismHarness {
    static func main(_ a: [String]) {
        let days = a.first.flatMap { Int($0) } ?? 240
        let years = Double(days) / 365.25
        print("== Determinism: same seed, same game (\(days) days per era) ==")
        var failed = false
        let games: [(label: String, era: String, flags: [String])] = [
            ("2017", "2017", []), ("2022", "2022", []), ("2026", "2026", []),
            ("2022, Copenhagen, more systems", "2022", ["hq=dk:copenhagen", "advproj", "science", "data"]),
        ]
        for (label, era, flags) in games {
            let one = play(era, seed: 11, years: years, flags: flags)
            let two = play(era, seed: 11, years: years, flags: flags)
            let other = play(era, seed: 12, years: years, flags: flags)
            let same = one.digest == two.digest, differs = one.digest != other.digest
            // A saved game, loaded and played on, plays the same way every time.
            let r1 = resumed(one.state, days: 30), r2 = resumed(one.state, days: 30)
            let resumes = r1 == r2
            if !(same && differs && resumes) { failed = true }
            print("  \(label): seed 11 \(hex(one.digest)) / \(hex(two.digest)) \(same ? "same" : "MISMATCH") · "
                  + "seed 12 \(hex(other.digest)) \(differs ? "differs" : "SAME (seed ignored?)") · "
                  + "save, load, 30 days ×2 \(resumes ? "same" : "MISMATCH")")
        }
        print(failed ? "  FAILED: the simulation is not deterministic" : "  OK: same seed, same game")
        if failed { exit(1) }
    }

    static func play(_ era: String, seed: UInt64, years: Double, flags: [String] = []) -> (digest: UInt64, state: GameState) {
        _ = PTPlay.play(era: era, seed: seed, years: years, mode: "silent", flags: Set(flags))
        var s = PTPlay.lastState!
        s.idStream = StableID.current   // as a save would record it
        return (digest(s), s)
    }

    static func resumed(_ s: GameState, days: Int) -> UInt64 {
        guard let data = encode(s) else { return 0 }
        guard var t = try? SaveCoding.decoder().decode(GameState.self, from: data) else { return 0 }
        StableID.resume(t)
        SaveMigration.migrate(&t)
        BenchmarkCatalog.resetCache()
        for _ in 0..<days where t.gameOver == nil {
            for _ in 0..<10 {
                guard let d = t.decisions.first else { break }
                t.resolveDecision(d.id, option: 0)
            }
            Sim.advanceDay(&t)
        }
        return digest(t)
    }

    static func encode(_ s: GameState) -> Data? {
        let enc = SaveCoding.encoder()
        enc.outputFormatting = [.sortedKeys]
        return try? enc.encode(s)
    }

    /// FNV-1a over the saved game in a canonical form. Swift seeds every Set and Dictionary differently (per
    /// instance, and per launch), so two equal games can write their sets in different orders: keys are sorted and
    /// arrays of plain strings or numbers (sets of IDs, of strings, of numbers) are sorted before hashing.
    static func digest(_ s: GameState) -> UInt64 {
        guard let data = encode(s), let obj = try? JSONSerialization.jsonObject(with: data),
              let canonical = try? JSONSerialization.data(withJSONObject: canon(obj), options: [.sortedKeys]) else { return 0 }
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in canonical {
            h ^= UInt64(byte)
            h = h &* 0x100_0000_01b3
        }
        return h
    }

    static func canon(_ x: Any) -> Any {
        if let d = x as? [String: Any] { return d.mapValues(canon) }
        guard let a = x as? [Any] else { return x }
        let c = a.map(canon)
        if !c.isEmpty, c.allSatisfy({ $0 is String }) { return c.map { $0 as! String }.sorted() }
        let numbers = c.compactMap { v -> Double? in (v as? Double) ?? (v as? Int).map(Double.init) ?? (v as? NSNumber)?.doubleValue }
        if !c.isEmpty, numbers.count == c.count { return numbers.sorted() }
        return c
    }

    static func hex(_ v: UInt64) -> String { String(v, radix: 16) }
}
