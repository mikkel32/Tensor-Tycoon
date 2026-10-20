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
    /// Labs out of the race (acquired or bankrupt): they don't rank.
    var gone: Set<String> = []
    var snapshot = MarketSnapshot()
    var runRate = 0.0
    var h100e = 0.0
    var totalChips = 0
    var frontier = 0.0
    /// Rival Watch rows and the Chief of Staff's list, computed once per tick for every view that shows them.
    var watch: [RivalIntel.Row] = []
    var advice: [AdvisorItem] = []
    /// 3.9: chips leased out by type: starting work recalls them, so chip pickers count them.
    var leases: [String: Int] = [:]

    init() {}

    init(_ s: GameState) {
        bonuses = s.bonuses
        pools = Economy.pools(s)
        poolByID = Dictionary(uniqueKeysWithValues: pools.map { ($0.accel.id, $0) })
        benchmarks = s.benchmarks
        indexSet = BenchmarkCatalog.indexSet(benchmarks, date: s.date, saturated: s.benchSaturated)
        board = Leaderboard.entries(s, set: indexSet)
        gone = Leaderboard.goneLabs(s)
        for (i, e) in board.enumerated() {
            entryByID[e.id] = e
            rankByID[e.id] = i + 1
        }
        snapshot = Market.snapshot(s)
        runRate = Economy.runRate(s)
        h100e = pools.reduce(0) { $0 + Double($1.total) * $1.accel.bf16 / HardwareCatalog.h100.bf16 }
        totalChips = Economy.totalChips(s)
        frontier = Macro.frontier(s.year)
        watch = RivalIntel.rows(s, set: indexSet)
        advice = Advisor.items(s, pools: pools, watch: watch, set: indexSet)
        leases = s.leases.filter { $0.value > 0 }
    }

    func free(_ accelID: String) -> Int { poolByID[accelID]?.free ?? 0 }
    /// 3.9: idle chips plus those leased out, which starting a run, swarm or deployment takes back.
    func available(_ accelID: String) -> Int { free(accelID) + (leases[accelID] ?? 0) }
    /// "1,200 free" or "1,200 idle + 800 leased (recalled on start)".
    func availableText(_ accelID: String) -> String {
        let n = leases[accelID] ?? 0
        return n > 0 ? "\(Fmt.int(free(accelID))) idle + \(Fmt.int(n)) leased (recalled on start)" : "\(Fmt.int(free(accelID))) free"
    }
    func rank(_ id: UUID) -> Int {
        guard let me = entryByID[id.uuidString] else { return board.count + 1 }
        return Leaderboard.labRank(index: me.index, board: board, gone: gone)
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
    /// 3.7: a launch whose launch-day report sheet is open.
    var launchReportID: UUID?
    /// An inbox decision the player opened.
    var openDecisionID: UUID?
    /// A monthly briefing the player opened.
    var briefingID: UUID?
    /// Why the clock last stopped on its own.
    var pauseReason: String?
    /// The era introduction, shown once when a new game starts.
    var showEraIntro = false
    /// The ⌘K "Go to…" palette.
    var showPalette = false
    /// The Photo Credits sheet, opened from the Help menu or the main menu when no game is running.
    var showPhotoCredits = false
    var showRunReports = UserDefaults.standard.object(forKey: "showRunReports") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showRunReports, forKey: "showRunReports") }
    }
    /// 3.5: a major run that just launched; the Training screen plays its launch sequence once (presentation only).
    var launchRunID: UUID?
    /// 3.5: the run the Training screen's command centre shows.
    var focusRunID: UUID?
    var showLaunchSequence = UserDefaults.standard.object(forKey: "showLaunchSequence") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showLaunchSequence, forKey: "showLaunchSequence") }
    }
    /// 3.4: calmer presentation in the game itself (launch sequences, landmark moments), on top of the system's Reduce Motion.
    var reduceAnimations = UserDefaults.standard.bool(forKey: "reduceAnimations") {
        didSet { UserDefaults.standard.set(reduceAnimations, forKey: "reduceAnimations") }
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
    /// 3.9: the game file and month of the last autosave (game time, not wall-clock time).
    @ObservationIgnored private var lastAutosave = ""

    /// Simulated days per real second.
    static let speeds: [(label: String, daysPerSecond: Double)] = [
        ("Paused", 0), ("1×", 1.5), ("2×", 4), ("4×", 10), ("Fast", 30), ("Turbo", 90),
    ]
    static let frameInterval = 0.1

    /// How often the UI gets a new state. At Fast and Turbo several days pass per frame anyway, so publishing
    /// 4–5 times a second instead of 10 halves the rendering work without slowing the game.
    static func publishInterval(_ speed: Int) -> Double { speed >= 5 ? 0.25 : (speed == 4 ? 0.2 : frameInterval) }

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
        showEraIntro = true
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
        if s > 0 { pauseReason = nil }
        timer?.invalidate()
        timer = nil
        dayDebt = 0
        if s == 0 { save() }
        guard s > 0, state?.gameOver == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.publishInterval(s), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func togglePause() { setSpeed(speed == 0 ? 1 : 0) }

    func tick() {
        guard state != nil, speed > 0 else { return }
        dayDebt += Self.speeds[speed].daysPerSecond * Self.publishInterval(speed)
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
            // Only urgent decisions stop the clock; offers wait in the inbox.
            if s.gameOver != nil || s.pauseRequested || s.decisions.contains(where: Alerts.isUrgent) { break }
        }
        var reason: String? = nil
        if s.pauseRequested {
            s.pauseRequested = false
            reason = s.alerts.first(where: { !$0.seen && s.pauseKinds.contains($0.kind) })?.title ?? "Something needs you"
        }
        let urgent = s.decisions.contains(where: Alerts.isUrgent)
        let stop = s.gameOver != nil || urgent || reason != nil || finished != nil
        state = s
        refreshDerived()
        if let finished { reportRunID = finished }
        if stop {
            setSpeed(0)
            pauseReason = reason ?? (urgent ? "A decision needs you" : nil)
        }
        if s.date.ym != startMonth {
            save()
            autosaveIfDue(s)
        }
    }

    /// Advance exactly one day (for the "step" button).
    func step() {
        guard state != nil else { return }
        Sim.advanceDay(&state!)
        state!.pauseRequested = false
        refreshDerived()
    }

    // MARK: Chief of Staff, inbox, alerts

    /// Carry out a Chief of Staff fix, or open what it points at.
    func applyFix(_ item: AdvisorItem) {
        guard let fix = item.fix else { open(item.screen); return }
        if case .openDecision(let id) = fix {
            openDecisionID = id
            return
        }
        act("Done: \(item.fixLabel.isEmpty ? item.title : item.fixLabel)") { Advisor.apply(&$0, fix) }
    }

    func snooze(_ item: AdvisorItem, days: Int) {
        mutate { $0.snoozeAdvice(item.id, days: days) }
        show("Hidden for \(days) days")
    }

    /// Follow an alert's link.
    func follow(_ alert: GameAlert) {
        mutate { $0.dismissAlert(alert.id) }
        if alert.alertKind == .briefing, let b = state?.briefings.first {
            briefingID = b.id
        } else if alert.alertKind == .inbox, let d = state?.decisions.first(where: { !Alerts.isUrgent($0) && alert.title == $0.title }) {
            openDecisionID = d.id
        } else if alert.title.hasPrefix(Launches.reportTitle),
                  let r = state?.launches.last(where: { Launches.reportTitle + $0.modelName == alert.title && $0.report != nil }) {
            launchReportID = r.id   // 3.7: the launch-day report
        } else if let target = alert.target {
            open(target)
        }
    }

    // MARK: Actions

    @discardableResult
    func act(_ success: String? = nil, _ action: (inout GameState) -> String?) -> Bool {
        guard state != nil else { return false }
        if let err = StableID.drawing({ action(&state!) }) {
            show(err, error: true)
            return false
        }
        refreshDerived()
        if let success { show(success) }
        return true
    }

    func mutate(_ action: (inout GameState) -> Void) {
        guard state != nil else { return }
        StableID.drawing { action(&state!) }
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

    /// Where the Rivals hub lands next: links to Rival Watch, the AI industry and rival labs open its tabs.
    var rivalsTab: RivalsTab?
    var rivalsLab: String?

    func open(_ s: Screen) {
        switch s {
        case .rivalWatch: rivalsTab = .watch; screen = .rivals
        case .industry: rivalsTab = .industry; screen = .rivals
        case .competitors: rivalsTab = .labs; screen = .rivals
        default: screen = s
        }
    }

    /// The photo credits: the Credits screen in a game, a sheet from the main menu.
    func openPhotoCredits() {
        if state != nil { open(.credits) } else { showPhotoCredits = true }
    }

    /// A rival lab's profile in the Rivals hub.
    func openLab(_ id: String) {
        rivalsLab = id
        rivalsTab = .labs
        screen = .rivals
    }

    func openBriefing(_ id: UUID) {
        briefingID = id
        mutate { $0.markBriefingSeen(id) }
    }

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
        guard var s = state, let url = currentSaveURL else { return }
        s.idStream = StableID.current
        if !force && Date().timeIntervalSince(lastSave) < 12 { return }
        lastSave = Date()
        Self.saveQueue.async { [weak self] in
            if let err = Self.write(s, to: url) {
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.show("Couldn't save the game: \(err)", error: true) } }
            }
        }
        if let broke = HallOfFame.record(s) { show(broke) }   // 3.5: records across games
    }

    /// Writes the save before returning: used when quitting or relaunching for an update.
    func saveNow() {
        guard var s = state, let url = currentSaveURL else { return }
        s.idStream = StableID.current
        lastSave = Date()
        if let err = Self.saveQueue.sync(execute: { Self.write(s, to: url) }) { show("Couldn't save the game: \(err)", error: true) }
    }

    /// Writes a save; returns why it failed, if it did.
    @discardableResult
    private nonisolated static func write(_ s: GameState, to url: URL) -> String? {
        do {
            let data = try SaveCoding.encoder().encode(s)
            try data.write(to: url, options: .atomic)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: Autosaves (rewind)

    nonisolated static var autosaveRoot: URL { saveDirectory.appendingPathComponent("Autosaves", isDirectory: true) }

    nonisolated static func autosaveFolder(company file: String) -> URL {
        let dir = autosaveRoot.appendingPathComponent(file.replacingOccurrences(of: ".json", with: ""), isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A rolling autosave at the start of each quarter (the last eight are kept), so a bad call can be undone.
    private func autosaveIfDue(_ s: GameState) {
        let ym = s.date.ym
        // 3.9: once per quarter in game time. A 20-second wall-clock throttle left autosaves years apart at Turbo.
        let key = "\(Self.fileName(for: s))|\(ym.year)-\(ym.month)"
        guard ym.month % 3 == 1, key != lastAutosave else { return }
        lastAutosave = key
        let dir = Self.autosaveFolder(company: Self.fileName(for: s))
        let url = dir.appendingPathComponent(String(format: "%04d-%02d.json", ym.year, ym.month))
        var s = s
        s.idStream = StableID.current
        Self.saveQueue.async {
            Self.write(s, to: url)
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent } ?? []
            for old in files.dropFirst(8) { try? FileManager.default.removeItem(at: old) }
        }
    }

    struct AutosaveInfo: Identifiable {
        var id: URL { url }
        let url: URL
        let year: Int
        let month: Int
        var label: String { GameCalendar.date(year, month, 1).gameMonth }
    }

    /// The current game's autosaves, newest first (read from the file names, so it's instant).
    func autosaves() -> [AutosaveInfo] {
        guard let s = state else { return [] }
        let dir = Self.autosaveFolder(company: Self.fileName(for: s))
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { url -> AutosaveInfo? in
            let parts = url.deletingPathExtension().lastPathComponent.split(separator: "-").compactMap { Int($0) }
            guard url.pathExtension == "json", parts.count == 2 else { return nil }
            return AutosaveInfo(url: url, year: parts[0], month: parts[1])
        }
        .filter { GameCalendar.date($0.year, $0.month, 1) < s.date }
        .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
    }

    /// Go back to an autosave. The game in progress is replaced.
    func rewind(_ a: AutosaveInfo) {
        load(a.url)
        save(force: true)
        show("Rewound to \(a.label)")
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

    /// Reads the save list off the main thread (each save is decoded to show its summary).
    nonisolated static func loadSaveList() async -> [SaveInfo] {
        await Task.detached(priority: .userInitiated) { GameStore.listSaves() }.value
    }

    nonisolated static func listSaves() -> [SaveInfo] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: saveDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        let dec = SaveCoding.decoder()
        return files.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url), let s = try? dec.decode(GameState.self, from: data),
                  s.version >= GameState.currentVersion else { return nil }
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return SaveInfo(url: url, company: s.companyName, date: s.date, cash: s.cash, valuation: s.valuation, modified: mod, over: s.gameOver != nil)
        }.sorted { $0.modified > $1.modified }
    }

    func load(_ url: URL) {
        openDecisionID = nil
        briefingID = nil
        pauseReason = nil
        launchRunID = nil
        focusRunID = nil
        let dec = SaveCoding.decoder()
        do {
            let data = try Data(contentsOf: url)
            SaveRepairs.reset()
            var s = try dec.decode(GameState.self, from: data)
            let repaired = SaveRepairs.taken()
            StableID.resume(s)   // 3.7: a loaded game keeps drawing IDs where it left off
            Self.migrate(&s)
            BenchmarkCatalog.resetCache()
            lastCustomChipCount = -1
            state = s
            refreshDerived()
            screen = .dashboard
            setSpeed(0)
            if !repaired.isEmpty {
                // A part of the save this version couldn't read was reset rather than refusing the whole file.
                show("Some of this save couldn't be read and was reset: \(repaired.prefix(3).joined(separator: ", "))\(repaired.count > 3 ? " and \(repaired.count - 3) more" : "").", error: true)
            }
        } catch {
            show("Couldn't load save: \(error.localizedDescription)", error: true)
        }
    }

    /// Bring saves from older versions up to date.
    static func migrate(_ s: inout GameState) { SaveMigration.migrate(&s) }

    static func deleteSave(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        // Its autosaves go with it.
        let dir = autosaveRoot.appendingPathComponent(url.deletingPathExtension().lastPathComponent, isDirectory: true)
        try? FileManager.default.trashItem(at: dir, resultingItemURL: nil)
    }
}
