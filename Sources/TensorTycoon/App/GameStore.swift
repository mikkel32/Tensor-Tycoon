import AppKit
import Foundation
import Observation

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool
}

/// Everything views need that is expensive to compute. Rebuilt once per tick (not once per view).
struct Derived {
    var bonuses = ResearchBonuses()
    var pools: [ComputePool] = []
    var poolByID: [String: ComputePool] = [:]
    var benchmarks: [Benchmark] = []
    var indexSet: [Benchmark] = []
    var board: [Leaderboard.Entry] = []
    var entryByID: [String: Leaderboard.Entry] = [:]
    var rankByID: [String: Int] = [:]
    var snapshot = MarketSnapshot()
    var runRate = 0.0
    var h100e = 0.0
    var totalChips = 0
    var frontier = 0.0

    init() {}

    init(_ s: GameState) {
        bonuses = s.bonuses
        pools = Economy.pools(s)
        poolByID = Dictionary(uniqueKeysWithValues: pools.map { ($0.accel.id, $0) })
        benchmarks = s.benchmarks
        indexSet = BenchmarkCatalog.indexSet(benchmarks, date: s.date, saturated: s.benchSaturated)
        board = Leaderboard.entries(s, set: indexSet)
        for (i, e) in board.enumerated() {
            entryByID[e.id] = e
            rankByID[e.id] = i + 1
        }
        snapshot = Market.snapshot(s)
        runRate = Economy.runRate(s)
        h100e = pools.reduce(0) { $0 + Double($1.total) * $1.accel.bf16 / HardwareCatalog.h100.bf16 }
        totalChips = Economy.totalChips(s)
        frontier = Macro.frontier(s.year)
    }

    func free(_ accelID: String) -> Int { poolByID[accelID]?.free ?? 0 }
    func rank(_ id: UUID) -> Int {
        guard let me = entryByID[id.uuidString] else { return board.count + 1 }
        return board.filter { !$0.isPlayer && $0.released && $0.index > me.index }.count + 1
    }
    func entry(_ id: UUID) -> Leaderboard.Entry? { entryByID[id.uuidString] }
}

@MainActor
@Observable
final class GameStore {
    var state: GameState?
    var speed = 0
    var screen: Screen = .dashboard
    var toast: Toast?
    var focusModelID: UUID?
    var focusAccelID: String?
    /// A finished training run whose report sheet should be shown.
    var reportRunID: UUID?
    var showRunReports = UserDefaults.standard.object(forKey: "showRunReports") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showRunReports, forKey: "showRunReports") }
    }
    private(set) var derived = Derived()
    /// Last non-nil state, so views being torn down after "quit to menu" never see a missing game.
    @ObservationIgnored private var lastState: GameState?
    /// Non-optional game state for views inside the game shell.
    var game: GameState { state ?? lastState! }
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var dayDebt = 0.0
    @ObservationIgnored private var lastSave = Date.distantPast
    @ObservationIgnored private var lastCustomChipCount = -1

    /// Simulated days per real second.
    static let speeds: [(label: String, daysPerSecond: Double)] = [
        ("Paused", 0), ("1×", 1.5), ("2×", 4), ("4×", 10), ("Fast", 30), ("Turbo", 90),
    ]
    static let frameInterval = 0.1

    // MARK: Derived data

    func refreshDerived() {
        guard let s = state else { derived = Derived(); return }
        lastState = s
        if s.customChips.count != lastCustomChipCount {
            HardwareCatalog.register(s.customChips)
            lastCustomChipCount = s.customChips.count
        }
        derived = Derived(s)
    }

    // MARK: Lifecycle

    func newGame(_ settings: NewGameSettings) {
        lastCustomChipCount = -1
        state = NewGame.create(settings)
        refreshDerived()
        screen = .dashboard
        setSpeed(0)
        save(force: true)
    }

    func quitToMenu() {
        save(force: true)
        setSpeed(0)
        state = nil
        refreshDerived()
    }

    func setSpeed(_ s: Int) {
        speed = s
        timer?.invalidate()
        timer = nil
        dayDebt = 0
        if s == 0 { save() }
        guard s > 0, state?.gameOver == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func togglePause() { setSpeed(speed == 0 ? 1 : 0) }

    func tick() {
        guard state != nil, speed > 0 else { return }
        dayDebt += Self.speeds[speed].daysPerSecond * Self.frameInterval
        let days = Int(dayDebt)
        guard days > 0 else { return }
        dayDebt -= Double(days)
        // Simulate on a local copy, then publish once: one UI update per frame no matter how many days pass.
        var s = state!
        let startMonth = s.date.ym
        let training = Set(s.runs.filter { $0.status != .done && $0.status != .cancelled }.map(\.id))
        var finished: UUID? = nil
        for _ in 0..<days {
            Sim.advanceDay(&s)
            if showRunReports, !training.isEmpty,
               let done = s.runs.last(where: { training.contains($0.id) && $0.status == .done }) {
                finished = done.id
                break
            }
            if s.gameOver != nil || !s.decisions.isEmpty { break }
        }
        let stop = s.gameOver != nil || !s.decisions.isEmpty || finished != nil
        state = s
        refreshDerived()
        if let finished { reportRunID = finished }
        if stop { setSpeed(0) }
        if s.date.ym != startMonth { save() }
    }

    /// Advance exactly one day (for the "step" button).
    func step() {
        guard state != nil else { return }
        Sim.advanceDay(&state!)
        refreshDerived()
    }

    // MARK: Actions

    @discardableResult
    func act(_ success: String? = nil, _ action: (inout GameState) -> String?) -> Bool {
        guard state != nil else { return false }
        if let err = action(&state!) {
            show(err, error: true)
            return false
        }
        refreshDerived()
        if let success { show(success) }
        return true
    }

    func mutate(_ action: (inout GameState) -> Void) {
        guard state != nil else { return }
        action(&state!)
        refreshDerived()
    }

    func show(_ message: String, error: Bool = false) {
        let t = Toast(message: message, isError: error)
        toast = t
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(error ? 4.5 : 2.5))
            if self.toast == t { self.toast = nil }
        }
    }

    func open(_ s: Screen) { screen = s }

    // MARK: Persistence

    nonisolated static var saveDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("TensorTycoon/Saves", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileName(for s: GameState) -> String {
        let safe = s.companyName.replacingOccurrences(of: "[^A-Za-z0-9 _-]", with: "", options: .regularExpression)
        return "\(safe.isEmpty ? "Company" : safe).json"
    }

    /// Saves are written in order on one serial queue, so a late background write can never overwrite a newer save.
    private static let saveQueue = DispatchQueue(label: "TensorTycoon.save", qos: .utility)

    /// File of the game in progress.
    var currentSaveURL: URL? { state.map { Self.saveDirectory.appendingPathComponent(Self.fileName(for: $0)) } }

    /// Encodes and writes on a background queue so saving never stalls the UI.
    func save(force: Bool = false) {
        guard let s = state, let url = currentSaveURL else { return }
        if !force && Date().timeIntervalSince(lastSave) < 12 { return }
        lastSave = Date()
        Self.saveQueue.async { Self.write(s, to: url) }
    }

    /// Writes the save before returning: used when quitting or relaunching for an update.
    func saveNow() {
        guard let s = state, let url = currentSaveURL else { return }
        lastSave = Date()
        Self.saveQueue.sync { Self.write(s, to: url) }
    }

    private nonisolated static func write(_ s: GameState, to url: URL) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        if let data = try? enc.encode(s) {
            try? data.write(to: url, options: .atomic)
        }
    }

    struct SaveInfo: Identifiable {
        var id: URL { url }
        let url: URL
        let company: String
        let date: Date
        let cash: Double
        let valuation: Double
        let modified: Date
        let over: Bool
    }

    static func listSaves() -> [SaveInfo] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: saveDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return files.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url), let s = try? dec.decode(GameState.self, from: data),
                  s.version >= GameState.currentVersion else { return nil }
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return SaveInfo(url: url, company: s.companyName, date: s.date, cash: s.cash, valuation: s.valuation, modified: mod, over: s.gameOver != nil)
        }.sorted { $0.modified > $1.modified }
    }

    func load(_ url: URL) {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        do {
            let data = try Data(contentsOf: url)
            var s = try dec.decode(GameState.self, from: data)
            Self.migrate(&s)
            BenchmarkCatalog.resetCache()
            lastCustomChipCount = -1
            state = s
            refreshDerived()
            screen = .dashboard
            setSpeed(0)
        } catch {
            show("Couldn't load save: \(error.localizedDescription)", error: true)
        }
    }

    /// Loads a save with this build and plays 90 days on a copy; the file itself is never written.
    /// `TensorTycoon --check-save <file>` exits 0 when the save loads and plays (used before releasing an update).
    static func checkSave(_ url: URL) -> Int32 {
        do {
            let result = try SaveMigration.check(Data(contentsOf: url), name: url.lastPathComponent)
            print(result.report)
            return result.current ? 0 : 2
        } catch {
            print("FAILED \(url.lastPathComponent): \(error)")
            return 1
        }
    }

    /// Bring saves from older versions up to date.
    static func migrate(_ s: inout GameState) { SaveMigration.migrate(&s) }

    static func deleteSave(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
