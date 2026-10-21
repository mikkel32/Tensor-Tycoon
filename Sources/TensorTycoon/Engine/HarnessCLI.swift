import Foundation

/// The headless checks, shared by the app (`TensorTycoon --research 2017` …) and the Linux engine build
/// (`Scripts/linux_build.sh`), so both run exactly the same harnesses.
enum HarnessCLI {
    /// Runs the harness `args` asks for and returns its exit code, or nil when `args` names none.
    static func run(_ args: [String]) -> Int32? {
        func arg(after flag: String, _ fallback: String) -> String? {
            guard let i = args.firstIndex(of: flag) else { return nil }
            return i + 1 < args.count && !args[i + 1].hasPrefix("--") ? args[i + 1] : fallback
        }
        func rest(after flag: String) -> [String]? {
            args.firstIndex(of: flag).map { Array(args.dropFirst($0 + 1)) }
        }
        // Headless: every ID the game creates comes from its seed.
        StableID.alwaysDraw = true
        if let i = args.firstIndex(of: "--check-save"), i + 1 < args.count {
            let url = URL(fileURLWithPath: args[i + 1])
            do {
                let result = try SaveMigration.check(Data(contentsOf: url), name: url.lastPathComponent)
                print(result.report)
                return result.current ? 0 : 2
            } catch {
                print("FAILED \(url.lastPathComponent): \(error)")
                return 1
            }
        }
        if args.contains("--calendar-check") {
            let bad = GameCalendar.selfCheck()
            print(bad == 0 ? "OK: integer calendar matches Foundation's from 1990 to 2100" : "FAILED: \(bad) calendar mismatches")
            return bad == 0 ? 0 : 1
        }
        // 3.8: play a real save forward day by day (see ReplayHarness).
        if let r = rest(after: "--replay-save") { return ReplayHarness.main(r) }
        if let a = rest(after: "--founding") { return FoundingHarness.main(a) }   // 3.9: founding contracts by era and country
        if args.contains("--forecast-check") { BalanceHarness.forecastCheck(); return 0 }
        if args.contains("--photo-check") { return PhotoHarness.main() }   // 3.4: photo credits and honest labels
        if let era = arg(after: "--strategy", "2022") { BalanceHarness.strategy(era: era); return 0 }
        if let era = arg(after: "--industry", "2017") { BalanceHarness.industry(era: era); return 0 }
        if args.contains("--scale") { BalanceHarness.scale(); return 0 }
        if let era = arg(after: "--watch", "2026") { BalanceHarness.watch(era: era); return 0 }
        if let era = arg(after: "--research", "2022") { BalanceHarness.research(era: era); return 0 }
        if let a = rest(after: "--playtest") { PlaytestHarness.main(a); return 0 }
        if let a = rest(after: "--determinism") { DeterminismHarness.main(a); return 0 }
        if let a = rest(after: "--scenarios") { return ScenarioHarness.main(a) }
        if let a = rest(after: "--drama") { return DramaHarness.main(a) }   // 3.9: dramatic events
        if args.contains("--finance-check") { return FinanceHarness.main() }   // 3.8: books, valuation, debt, payouts, tax, crises, stages
        if args.contains("--intelligence") { return IntelligenceHarness.main() }   // 3.8: intelligence, families, launches, markets, rivals
        if let era = arg(after: "--experience", "2024") { BalanceHarness.experience(era: era); return 0 }
        if let era = arg(after: "--ventures", "2026") { BalanceHarness.ventures(era: era); return 0 }
        if let era = arg(after: "--simulate", "2022") { BalanceHarness.run(era: era); return 0 }
        if let y = arg(after: "--data-value", "2025") { PTPlay.dataValue(year: Int(y) ?? 2025); return 0 }   // what datasets are worth to a coding model
        if args.contains("--data-check") { return PTPlay.dataCheck() == 0 ? 0 : 1 }   // data economy and science rules, scripted
        StableID.alwaysDraw = false
        return nil
    }
}
