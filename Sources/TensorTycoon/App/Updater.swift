import AppKit
import CryptoKit
import Foundation
import Observation

// MARK: - Configuration

enum UpdateConfig {
    /// GitHub repository whose Releases deliver updates.
    static let repository = "mikkel32/Tensor-Tycoon"
    /// Ed25519 public keys allowed to sign releases (base64, raw 32 bytes). A new key can be rotated in
    /// by shipping it in an update signed with an old one. Scripts/release.sh signs with the matching private key.
    static let publicKeys = ["cWIpneUDtgp6shxFW2/4MRdcksyqxtnfvLE54+B+Moo="]
    /// Release assets are named Tensor-Tycoon-<version>.zip, with a detached signature in <zip>.sig.
    static let assetPrefix = "Tensor-Tycoon-"
    /// How often a running copy looks for updates.
    static let checkInterval: TimeInterval = 6 * 3600
    /// Testing hook: read releases from another URL (e.g. a local file). Signatures are still required.
    static let feedOverride = ProcessInfo.processInfo.environment["TENSORTYCOON_UPDATE_FEED"].flatMap(URL.init(string:))
}

// MARK: - Versions

/// Semantic version ("v3.1", "3.10.2", "4.0-beta.2"). Missing components count as 0, and a pre-release sorts
/// before its release.
struct SemVer: Comparable, Hashable, CustomStringConvertible, Sendable {
    let numbers: [Int]
    let prerelease: String?

    init?(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.first == "v" || s.first == "V" { s.removeFirst() }
        let parts = s.split(separator: "-", maxSplits: 1).map(String.init)
        guard let core = parts.first, !core.isEmpty else { return nil }
        let nums = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !nums.isEmpty, nums.allSatisfy({ $0 != nil }) else { return nil }
        numbers = nums.compactMap { $0 }
        prerelease = parts.count > 1 ? parts[1] : nil
    }

    var description: String { numbers.map(String.init).joined(separator: ".") + (prerelease.map { "-\($0)" } ?? "") }

    private var normalized: [Int] {
        var n = numbers
        while n.count > 1, n.last == 0 { n.removeLast() }
        return n
    }

    static func == (a: SemVer, b: SemVer) -> Bool { a.normalized == b.normalized && a.prerelease == b.prerelease }

    func hash(into h: inout Hasher) {
        h.combine(normalized)
        h.combine(prerelease)
    }

    static func < (a: SemVer, b: SemVer) -> Bool {
        for i in 0..<max(a.numbers.count, b.numbers.count) {
            let x = i < a.numbers.count ? a.numbers[i] : 0
            let y = i < b.numbers.count ? b.numbers[i] : 0
            if x != y { return x < y }
        }
        switch (a.prerelease, b.prerelease) {
        case (nil, _): return false
        case (_, nil): return true
        case let (p?, q?): return p.compare(q, options: .numeric) == .orderedAscending
        }
    }
}

// MARK: - Releases

struct AppRelease: Identifiable, Equatable, Sendable {
    struct Asset: Equatable, Sendable {
        let name: String
        let url: URL
        let size: Int64
        /// Hex SHA-256 published by GitHub for the asset, when available.
        let sha256: String?
    }

    var id: String { tag }
    let tag: String
    let version: SemVer
    let title: String
    let notes: String
    let published: Date?
    let page: URL?
    let zip: Asset
    let signature: Asset?
}

enum UpdateError: LocalizedError {
    case offline
    case rateLimited(Date?)
    case server(Int)
    case noAsset
    case missingSignature
    case sizeMismatch
    case checksumMismatch
    case badSignature
    case unpackFailed(String)
    case wrongApp
    case versionMismatch(String)
    case needsNewerMacOS(String)
    case wrongArchitecture
    case codeSignature(String)
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .offline: "Couldn't reach GitHub. Check your internet connection."
        case .rateLimited(let reset):
            "GitHub is rate-limiting update checks" + (reset.map { " until \($0.formatted(date: .omitted, time: .shortened))" } ?? "") + ". Try again later."
        case .server(let code): "GitHub answered with an error (HTTP \(code))."
        case .noAsset: "The newest release has no downloadable app."
        case .missingSignature: "The release isn't signed, so it was not installed."
        case .sizeMismatch: "The download is incomplete. Try again."
        case .checksumMismatch: "The download is corrupted (checksum mismatch). Try again."
        case .badSignature: "The update's signature is invalid. It was not installed."
        case .unpackFailed(let why): "Couldn't unpack the update: \(why)"
        case .wrongApp: "The download doesn't contain Tensor Tycoon."
        case .versionMismatch(let v): "The download contains version \(v), not the one advertised."
        case .needsNewerMacOS(let v): "This update needs macOS \(v) or newer."
        case .wrongArchitecture: "This update doesn't support this Mac's processor."
        case .codeSignature(let why): "The app inside the update is damaged: \(why)"
        case .installFailed(let why): "Couldn't install the update: \(why)"
        }
    }
}

// MARK: - Engine (no UI state; also used by the --update-selftest harness)

enum UpdateEngine {
    static let userAgent: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        return "TensorTycoon-Updater/\(v) (macOS)"
    }()

    static var updatesDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("TensorTycoon/Updates", isDirectory: true)
    }

    private static var releasesCache: URL { updatesDirectory.appendingPathComponent("releases.json") }

    /// Every published, non-draft, non-prerelease release that ships an app zip, newest first.
    /// Uses an ETag so repeat checks are answered with "304 Not Modified" and don't eat into GitHub's rate limit.
    static func fetchReleases() async throws -> [AppRelease] {
        let feed = UpdateConfig.feedOverride ?? URL(string: "https://api.github.com/repos/\(UpdateConfig.repository)/releases?per_page=20")!
        var request = URLRequest(url: feed)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let defaults = UserDefaults.standard
        let cached = UpdateConfig.feedOverride == nil ? try? Data(contentsOf: releasesCache) : nil
        if cached != nil, let etag = defaults.string(forKey: "update.etag") {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code != .cancelled {
            throw UpdateError.offline
        }
        let http = response as? HTTPURLResponse
        let body: Data
        switch http?.statusCode ?? 200 {
        case 200:
            body = data
            if UpdateConfig.feedOverride == nil {
                try? FileManager.default.createDirectory(at: updatesDirectory, withIntermediateDirectories: true)
                try? data.write(to: releasesCache, options: .atomic)
                defaults.set(http?.value(forHTTPHeaderField: "ETag"), forKey: "update.etag")
            }
        case 304:
            guard let cached else { throw UpdateError.server(304) }
            body = cached
        case 403, 429:
            let reset = http?.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
            throw UpdateError.rateLimited(reset)
        case 404:
            return []
        case let code:
            throw UpdateError.server(code)
        }
        return try parse(body)
    }

    static func parse(_ data: Data) throws -> [AppRelease] {
        struct GHAsset: Decodable {
            let name: String
            let size: Int64
            let browserDownloadUrl: URL
            let digest: String?
        }
        struct GHRelease: Decodable {
            let tagName: String
            let name: String?
            let body: String?
            let draft: Bool
            let prerelease: Bool
            let publishedAt: Date?
            let htmlUrl: URL?
            let assets: [GHAsset]
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let releases = try decoder.decode([GHRelease].self, from: data)
        return releases.compactMap { r -> AppRelease? in
            guard !r.draft, !r.prerelease, let version = SemVer(r.tagName),
                  let zip = r.assets.first(where: { $0.name.hasPrefix(UpdateConfig.assetPrefix) && $0.name.hasSuffix(".zip") })
            else { return nil }
            func asset(_ a: GHAsset) -> AppRelease.Asset {
                let sha = a.digest.flatMap { $0.hasPrefix("sha256:") ? String($0.dropFirst(7)).lowercased() : nil }
                return AppRelease.Asset(name: a.name, url: a.browserDownloadUrl, size: a.size, sha256: sha)
            }
            let sig = r.assets.first { $0.name == zip.name + ".sig" }
            return AppRelease(tag: r.tagName, version: version, title: (r.name?.isEmpty == false ? r.name! : "Tensor Tycoon \(version)"),
                              notes: r.body ?? "", published: r.publishedAt, page: r.htmlUrl, zip: asset(zip), signature: sig.map(asset))
        }
        .sorted { $0.version > $1.version }
    }

    static func fetchSmall(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        guard status == 200 else { throw UpdateError.server(status) }
        return data
    }

    static func workDirectory(for version: SemVer) -> URL {
        updatesDirectory.appendingPathComponent(version.description, isDirectory: true)
    }

    /// The exact bytes Scripts/update_signing.swift signs. Binding version, hash and size stops an old signed
    /// build from being passed off as a newer one.
    static func manifest(version: String, sha256: String, size: Int64) -> Data {
        Data("TensorTycoon update v1\nversion=\(version)\nsha256=\(sha256)\nsize=\(size)\n".utf8)
    }

    static func sha256Hex(of url: URL) throws -> (hex: String, size: Int64) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var size: Int64 = 0
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
            size += Int64(chunk.count)
        }
        return (hasher.finalize().map { String(format: "%02x", $0) }.joined(), size)
    }

    static func isTrusted(signature: Data, manifest: Data) -> Bool {
        guard let sig = Data(base64Encoded: String(decoding: signature, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return UpdateConfig.publicKeys.contains { b64 in
            guard let raw = Data(base64Encoded: b64), let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw) else { return false }
            return key.isValidSignature(sig, for: manifest)
        }
    }

    /// Checks a downloaded update end to end and returns the unpacked, ready-to-install app.
    static func verify(zip: URL, release: AppRelease, signature: Data, workDir: URL, step: (String) -> Void) throws -> URL {
        let (hex, size) = try sha256Hex(of: zip)
        guard size == release.zip.size else { throw UpdateError.sizeMismatch }
        if let expected = release.zip.sha256, expected != hex { throw UpdateError.checksumMismatch }
        step(release.zip.sha256 != nil ? "Checksum matches GitHub (SHA-256)" : "Download complete (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))")

        guard isTrusted(signature: signature, manifest: manifest(version: release.version.description, sha256: hex, size: size)) else {
            throw UpdateError.badSignature
        }
        step("Signed by the Tensor Tycoon release key")

        let unpacked = workDir.appendingPathComponent("unpacked", isDirectory: true)
        try? FileManager.default.removeItem(at: unpacked)
        try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)
        do {
            _ = try run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])
        } catch {
            throw UpdateError.unpackFailed(error.localizedDescription)
        }
        let contents = (try? FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)) ?? []
        guard let app = contents.first(where: { $0.pathExtension == "app" }), let bundle = Bundle(url: app) else {
            throw UpdateError.wrongApp
        }
        guard bundle.bundleIdentifier == (Bundle.main.bundleIdentifier ?? "com.tensortycoon.game") else { throw UpdateError.wrongApp }
        let shipped = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        guard SemVer(shipped) == release.version else { throw UpdateError.versionMismatch(shipped) }
        if let minimum = bundle.infoDictionary?["LSMinimumSystemVersion"] as? String, let needed = SemVer(minimum) {
            let os = ProcessInfo.processInfo.operatingSystemVersion
            if SemVer("\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")! < needed { throw UpdateError.needsNewerMacOS(minimum) }
        }
        #if arch(arm64)
        let arch = NSBundleExecutableArchitectureARM64
        #else
        let arch = NSBundleExecutableArchitectureX86_64
        #endif
        if let archs = bundle.executableArchitectures?.map(\.intValue), !archs.contains(arch) { throw UpdateError.wrongArchitecture }
        step("Tensor Tycoon \(shipped) for this Mac")

        do {
            _ = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        } catch {
            throw UpdateError.codeSignature(error.localizedDescription)
        }
        _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", app.path])
        step("App bundle intact")
        return app
    }

    @discardableResult
    static func run(_ tool: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "TensorTycoon.Update", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return output
    }

    /// Where the new app goes: in place, unless macOS is running us from a read-only or translocated location.
    static func installTarget(for running: URL) -> URL {
        let parent = running.deletingLastPathComponent()
        let translocated = running.path.contains("/AppTranslocation/")
        if !translocated && FileManager.default.isWritableFile(atPath: parent.path) { return running }
        let system = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let base = FileManager.default.isWritableFile(atPath: system.path)
            ? system
            : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        return base.appendingPathComponent(running.lastPathComponent)
    }

    /// Swaps the new app into place. The running copy keeps working from memory until it quits.
    static func install(_ staged: URL, at target: URL) throws {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: target.path) {
                _ = try fm.replaceItemAt(target, withItemAt: staged)
            } else {
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: staged, to: target)
            }
        } catch {
            throw UpdateError.installFailed(error.localizedDescription)
        }
    }

    /// Copies every save into Saves/Backups/<date> <label>/ (keeping the newest five backups).
    static func backUpSaves(label: String) {
        let fm = FileManager.default
        let saves = GameStore.saveDirectory
        let files = ((try? fm.contentsOfDirectory(at: saves, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "json" }
        guard !files.isEmpty else { return }
        let backups = saves.appendingPathComponent("Backups", isDirectory: true)
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false).timeSeparator(.omitted))
        let folder = backups.appendingPathComponent("\(stamp) \(label)", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for f in files { try? fm.copyItem(at: f, to: folder.appendingPathComponent(f.lastPathComponent)) }
        let all = ((try? fm.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)) ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
        for old in all.dropLast(5) { try? fm.removeItem(at: old) }
    }
}

// MARK: - Download with progress

/// One file download with progress callbacks, wrapped for async/await and cancellable.
final class UpdateDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let onProgress: @Sendable (Int64, Int64) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var task: URLSessionDownloadTask?
    private var lastReport = Date.distantPast
    private let lock = NSLock()

    init(destination: URL, onProgress: @escaping @Sendable (Int64, Int64) -> Void) {
        self.destination = destination
        self.onProgress = onProgress
    }

    func run(_ url: URL) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                lock.withLock { continuation = cont }
                let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
                var request = URLRequest(url: url)
                request.setValue(UpdateEngine.userAgent, forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 60
                let t = session.downloadTask(with: request)
                lock.withLock { task = t }
                t.resume()
            }
        } onCancel: {
            cancel()
        }
    }

    func cancel() {
        lock.withLock { task }?.cancel()
    }

    private func finish(_ result: Result<Void, Error>) {
        let cont: CheckedContinuation<Void, Error>? = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        cont?.resume(with: result)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let now = Date()
        guard now.timeIntervalSince(lastReport) > 0.1 || totalBytesWritten == totalBytesExpectedToWrite else { return }
        lastReport = now
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The temporary file disappears when this method returns, so move it now.
        if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
            finish(.failure(UpdateError.server(http.statusCode)))
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            finish(.success(()))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            let cancelled = (error as? URLError)?.code == .cancelled
            finish(.failure(cancelled ? CancellationError() : UpdateError.offline))
        }
        session.finishTasksAndInvalidate()
    }
}

// MARK: - Updater (UI state)

@MainActor
@Observable
final class Updater {
    enum Phase: Equatable {
        case idle, checking, upToDate, available, downloading, verifying, ready, installing
        case failed(String)
    }

    struct WhatsNew: Identifiable {
        let id = UUID()
        let version: String
        let notes: String
        let resumeCompany: String?
    }

    private enum Key {
        static let autoCheck = "update.autoCheck"
        static let autoDownload = "update.autoDownload"
        static let skipped = "update.skippedVersion"
        static let lastChecked = "update.lastChecked"
        static let installedVersion = "update.installedVersion"
        static let installedNotes = "update.installedNotes"
        static let resumeSave = "update.resumeSave"
    }

    private(set) var phase: Phase = .idle
    /// The newest release above the running version.
    private(set) var latest: AppRelease?
    /// Every release above the running version, newest first (their notes are shown together).
    private(set) var missed: [AppRelease] = []
    private(set) var received: Int64 = 0
    private(set) var expected: Int64 = 0
    private(set) var bytesPerSecond: Double = 0
    private(set) var steps: [String] = []
    private(set) var lastChecked: Date?
    var showSheet = false
    var whatsNew: WhatsNew?

    var autoCheck: Bool { didSet { UserDefaults.standard.set(autoCheck, forKey: Key.autoCheck) } }
    var autoDownload: Bool { didSet { UserDefaults.standard.set(autoDownload, forKey: Key.autoDownload) } }
    private(set) var skippedVersion: String? { didSet { UserDefaults.standard.set(skippedVersion, forKey: Key.skipped) } }

    let currentVersion: SemVer?
    /// False when running from `swift run` / Xcode: there's no app bundle to replace.
    let isPackaged: Bool

    /// Saves the game synchronously and returns its file, so the relaunched app can reopen it.
    @ObservationIgnored var prepareForRelaunch: (() -> URL?)?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var stagedApp: URL?
    @ObservationIgnored private var download: UpdateDownload?
    @ObservationIgnored private var downloadStarted = Date()
    /// "Update Now" was clicked: install as soon as the download is verified.
    @ObservationIgnored private var installWhenReady = false

    init() {
        let defaults = UserDefaults.standard
        currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(SemVer.init)
        isPackaged = Bundle.main.bundleURL.pathExtension == "app"
        autoCheck = defaults.object(forKey: Key.autoCheck) as? Bool ?? true
        autoDownload = defaults.object(forKey: Key.autoDownload) as? Bool ?? true
        skippedVersion = defaults.string(forKey: Key.skipped)
        lastChecked = defaults.object(forKey: Key.lastChecked) as? Date

        // First launch after an update: show what changed, then offer to jump back into the game.
        if let installed = defaults.string(forKey: Key.installedVersion), SemVer(installed) == currentVersion {
            let resume = defaults.string(forKey: Key.resumeSave).map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
            whatsNew = WhatsNew(version: installed, notes: defaults.string(forKey: Key.installedNotes) ?? "", resumeCompany: resume)
        }
        defaults.removeObject(forKey: Key.installedVersion)
        defaults.removeObject(forKey: Key.installedNotes)
    }

    var versionLabel: String { currentVersion.map { "Version \($0)" } ?? "Development build" }

    /// Show the banner / toolbar button?
    var updateAvailable: Bool {
        guard let latest else { return false }
        switch phase {
        case .ready, .installing: return true
        // .checking: a background re-check shouldn't make the banner flicker away.
        case .available, .downloading, .verifying, .failed, .checking: return latest.version.description != skippedVersion
        case .idle, .upToDate: return false
        }
    }

    var isReady: Bool { phase == .ready }

    // MARK: Scheduling

    func start() {
        guard !started else { return }
        started = true
        cleanUpOldDownloads()
        guard isPackaged else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            while !Task.isCancelled {
                if autoCheck && Date().timeIntervalSince(lastChecked ?? .distantPast) > UpdateConfig.checkInterval - 60 {
                    await check(userInitiated: false)
                }
                try? await Task.sleep(for: .seconds(1800))
            }
        }
    }

    // MARK: Check

    func check(userInitiated: Bool) async {
        if userInitiated { showSheet = true }
        switch phase {
        case .checking, .downloading, .verifying, .installing: return
        case .ready where !userInitiated: return
        default: break
        }
        let before = phase
        phase = .checking
        do {
            let releases = try await UpdateEngine.fetchReleases()
            lastChecked = Date()
            UserDefaults.standard.set(lastChecked, forKey: Key.lastChecked)
            let current = currentVersion ?? SemVer("0")!
            missed = releases.filter { $0.version > current }
            guard let top = missed.first else {
                latest = nil
                stagedApp = nil
                phase = .upToDate
                return
            }
            if latest?.version != top.version {
                latest = top
                stagedApp = nil
                steps = []
            }
            if stagedApp != nil {
                phase = .ready
                return
            }
            phase = .available
            let skipped = top.version.description == skippedVersion
            if isPackaged && autoDownload && (!skipped || userInitiated) {
                await downloadUpdate()
            }
        } catch {
            if userInitiated {
                phase = .failed(error.localizedDescription)
            } else {
                phase = before == .checking ? .idle : before
            }
        }
    }

    // MARK: Download & verify

    func downloadUpdate() async {
        guard let release = latest, isPackaged else { return }
        switch phase {
        case .downloading, .verifying, .installing, .ready: return
        default: break
        }
        phase = .downloading
        received = 0
        expected = release.zip.size
        bytesPerSecond = 0
        steps = []
        downloadStarted = Date()
        let dir = UpdateEngine.workDirectory(for: release.version)
        do {
            try? FileManager.default.removeItem(at: dir)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let zipURL = dir.appendingPathComponent(release.zip.name)
            let job = UpdateDownload(destination: zipURL) { [weak self] got, total in
                Task { @MainActor in self?.progress(got, total) }
            }
            download = job
            try await job.run(release.zip.url)
            download = nil
            steps.append("Downloaded \(ByteCountFormatter.string(fromByteCount: release.zip.size, countStyle: .file)) from GitHub")
            guard let sigAsset = release.signature else { throw UpdateError.missingSignature }
            let signature = try await UpdateEngine.fetchSmall(sigAsset.url)
            phase = .verifying
            let app = try await Task.detached(priority: .userInitiated) {
                try UpdateEngine.verify(zip: zipURL, release: release, signature: signature, workDir: dir) { step in
                    Task { @MainActor [weak self] in self?.steps.append(step) }
                }
            }.value
            stagedApp = app
            phase = .ready
            if installWhenReady { installAndRelaunch() }
        } catch is CancellationError {
            download = nil
            installWhenReady = false
            phase = .available
        } catch {
            download = nil
            installWhenReady = false
            phase = .failed(error.localizedDescription)
        }
    }

    /// One click: download (if needed), verify, install and relaunch.
    func updateNow() {
        guard isPackaged, latest != nil else { return }
        installWhenReady = true
        showSheet = true
        switch phase {
        case .ready: installAndRelaunch()
        case .downloading, .verifying, .installing: break
        default: Task { await downloadUpdate() }
        }
    }

    func cancelDownload() {
        installWhenReady = false
        download?.cancel()
    }

    private func progress(_ got: Int64, _ total: Int64) {
        guard phase == .downloading else { return }
        received = got
        if total > 0 { expected = total }
        let elapsed = Date().timeIntervalSince(downloadStarted)
        if elapsed > 0.3 { bytesPerSecond = Double(got) / elapsed }
    }

    // MARK: Install

    /// Saves the game, backs up saves, swaps in the new app and relaunches straight back into the game.
    func installAndRelaunch() {
        guard let release = latest, let staged = stagedApp else { return }
        phase = .installing
        let resume = prepareForRelaunch?()
        let target = UpdateEngine.installTarget(for: Bundle.main.bundleURL)
        UpdateEngine.backUpSaves(label: "before \(release.version)")
        do {
            try UpdateEngine.install(staged, at: target)
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }
        stagedApp = nil
        rememberInstall(release, resume: resume)

        // A tiny shell waits for this process to exit, then opens the new copy.
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        relauncher.arguments = ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$2\"",
                                "relaunch", "\(ProcessInfo.processInfo.processIdentifier)", target.path]
        do {
            try relauncher.run()
        } catch {
            phase = .failed("Installed, but couldn't relaunch. Open Tensor Tycoon again.")
            return
        }
        // AppKit won't quit while a sheet is open, so close ours first and quit on a later turn of the run loop.
        // The game is already saved, so if something else still blocks quitting, exit anyway.
        showSheet = false
        whatsNew = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            NSApp.terminate(nil)
            try? await Task.sleep(for: .seconds(4))
            UserDefaults.standard.synchronize()
            exit(0)
        }
    }

    /// Called while quitting: a downloaded, verified update installs itself so the next launch is up to date.
    func installOnQuitIfReady() {
        guard phase == .ready, let release = latest, let staged = stagedApp else { return }
        let target = UpdateEngine.installTarget(for: Bundle.main.bundleURL)
        UpdateEngine.backUpSaves(label: "before \(release.version)")
        guard (try? UpdateEngine.install(staged, at: target)) != nil else { return }
        stagedApp = nil
        rememberInstall(release, resume: nil)
    }

    private func rememberInstall(_ release: AppRelease, resume: URL?) {
        let defaults = UserDefaults.standard
        defaults.set(release.version.description, forKey: Key.installedVersion)
        defaults.set(combinedNotes, forKey: Key.installedNotes)
        if let resume { defaults.set(resume.path, forKey: Key.resumeSave) } else { defaults.removeObject(forKey: Key.resumeSave) }
    }

    /// Notes for every version the player is skipping over, newest first.
    var combinedNotes: String {
        if missed.count <= 1 { return latest?.notes ?? "" }
        return missed.map { "## \($0.title)\n\n\($0.notes)" }.joined(separator: "\n\n")
    }

    /// The save to reopen after an update relaunch (consumed once).
    func takeResumeSave() -> URL? {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: Key.resumeSave) else { return nil }
        defaults.removeObject(forKey: Key.resumeSave)
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: User choices

    func skipThisVersion() {
        skippedVersion = latest?.version.description
        showSheet = false
    }

    func later() {
        showSheet = false
    }

    private func cleanUpOldDownloads() {
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(at: UpdateEngine.updatesDirectory, includingPropertiesForKeys: nil)) ?? []
        for d in dirs where d.hasDirectoryPath {
            if let v = SemVer(d.lastPathComponent), let current = currentVersion, v <= current { try? fm.removeItem(at: d) }
        }
    }
}

// MARK: - Headless self-test (`TensorTycoon --update-selftest [pretend-version]`)

enum UpdateSelfTest {
    /// Runs the app's own verifier on a local zip + signature (`--verify-update <zip> <version> <sig file>`).
    static func verifyLocal(zip: String, version: String, signatureFile: String) -> Int32 {
        do {
            let url = URL(fileURLWithPath: zip)
            guard let v = SemVer(version) else { print("Bad version"); return 1 }
            let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            let release = AppRelease(tag: "v\(version)", version: v, title: "local", notes: "", published: nil, page: nil,
                                     zip: AppRelease.Asset(name: url.lastPathComponent, url: url, size: size, sha256: nil), signature: nil)
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tt-verify-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let signature = try Data(contentsOf: URL(fileURLWithPath: signatureFile))
            let app = try UpdateEngine.verify(zip: url, release: release, signature: signature, workDir: dir) { print("  ✓ \($0)") }
            print("VERIFIED \(app.lastPathComponent) \(version)")
            return 0
        } catch {
            print("REJECTED: \(error.localizedDescription)")
            return 1
        }
    }

    /// Runs the real check → download → verify pipeline against GitHub without installing anything.
    static func run(pretending version: String) -> Int32 {
        let semaphore = DispatchSemaphore(value: 0)
        var code: Int32 = 1
        Task.detached {
            defer { semaphore.signal() }
            do {
                print("Checking https://github.com/\(UpdateConfig.repository)/releases as version \(version)…")
                let releases = try await UpdateEngine.fetchReleases()
                for r in releases { print("  release \(r.version)  zip=\(r.zip.name) \(r.zip.size) B  sha256=\(r.zip.sha256 ?? "–")  sig=\(r.signature?.name ?? "MISSING")") }
                guard let current = SemVer(version), let top = releases.first, top.version > current else {
                    print("No newer release than \(version).")
                    code = 0
                    return
                }
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tt-update-selftest-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: dir) }
                let zip = dir.appendingPathComponent(top.zip.name)
                print("Downloading \(top.zip.url.absoluteString)…")
                try await UpdateDownload(destination: zip) { _, _ in }.run(top.zip.url)
                guard let sig = top.signature else { throw UpdateError.missingSignature }
                let signature = try await UpdateEngine.fetchSmall(sig.url)
                let app = try UpdateEngine.verify(zip: zip, release: top, signature: signature, workDir: dir) { print("  ✓ \($0)") }
                print("Ready to install: \(app.path)")
                print("Install target from here would be: \(UpdateEngine.installTarget(for: Bundle.main.bundleURL).path)")
                code = 0
            } catch {
                print("FAILED: \(error.localizedDescription)")
                code = 1
            }
        }
        semaphore.wait()
        return code
    }
}
