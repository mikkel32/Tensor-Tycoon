import AppKit
import SwiftUI

// MARK: - Main menu banner

/// Shown on the main menu when a newer version is out: one click downloads, verifies, installs and relaunches.
struct UpdateBanner: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        if updater.updateAvailable, let release = updater.latest {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Theme.accentGradient).frame(width: 46, height: 46)
                    Image(systemName: updater.isReady ? "checkmark.seal.fill" : "arrow.down")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: updater.isReady)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(updater.isReady ? "Tensor Tycoon \(release.version) is ready to install" : "Tensor Tycoon \(release.version) is available")
                        .font(.headline)
                    UpdateProgressLine(release: release)
                }
                Spacer(minLength: 12)
                Button("What's New") { updater.showSheet = true }
                    .buttonStyle(.bordered)
                UpdatePrimaryButton()
            }
            .padding(16)
            .background(.regularMaterial, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.accentGradient, lineWidth: 1.5))
            .environment(\.colorScheme, .dark)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// "Version 3.1 · Up to date · Check for Updates" under the main menu title.
struct UpdateStatusLine: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        HStack(spacing: 8) {
            Text(updater.versionLabel)
            Text("·")
            switch updater.phase {
            case .checking:
                ProgressView().controlSize(.mini)
                Text("Checking for updates…")
            case .upToDate:
                Label("Up to date", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed where updater.latest == nil:
                Label("Couldn't check for updates", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            default:
                if let checked = updater.lastChecked {
                    Text("Checked \(checked.formatted(.relative(presentation: .named)))")
                }
            }
            Button("Check for Updates") { Task { await updater.check(userInitiated: true) } }
                .buttonStyle(.link)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.7))
    }
}

// MARK: - In-game toolbar

struct UpdateToolbarButton: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        if let release = updater.latest {
            Button { updater.showSheet = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: updater.isReady ? "checkmark.seal.fill" : "arrow.down.circle.fill")
                    Text(updater.isReady ? "Restart to update" : "Update \(release.version)")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.accentGradient, in: .capsule)
            }
            .buttonStyle(.plain)
            .help("Tensor Tycoon \(release.version) is available")
        }
    }
}

// MARK: - Shared pieces

private struct UpdatePrimaryButton: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        switch updater.phase {
        case .downloading, .verifying, .installing:
            Button {} label: {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(updater.phase == .installing ? "Installing…" : (updater.phase == .verifying ? "Verifying…" : "Downloading…"))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)
        case .ready:
            Button("Install & Relaunch") { updater.installAndRelaunch() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        default:
            Button(updater.isPackaged ? "Update Now" : "Open Release Page") {
                if updater.isPackaged {
                    updater.updateNow()
                } else if let page = updater.latest?.page {
                    NSWorkspace.shared.open(page)
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }
}

/// Size / progress / status in one line.
private struct UpdateProgressLine: View {
    @Environment(Updater.self) private var updater
    let release: AppRelease

    var body: some View {
        switch updater.phase {
        case .downloading:
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(updater.received), total: Double(max(updater.expected, 1)))
                    .frame(maxWidth: 320)
                Text(downloadDetail).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        case .verifying:
            Text("Verifying the download…").font(.callout).foregroundStyle(.secondary)
        case .ready:
            Text("Downloaded and verified. Your game is saved and reopens right where you left off.")
                .font(.callout).foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).font(.callout).foregroundStyle(.orange).lineLimit(2)
        default:
            Text(summary).font(.callout).foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        var parts = ["You have \(updater.currentVersion?.description ?? "a development build")"]
        parts.append(ByteCountFormatter.string(fromByteCount: release.zip.size, countStyle: .file))
        if let date = release.published { parts.append("released \(date.formatted(.relative(presentation: .named)))") }
        if updater.missed.count > 1 { parts.append("includes \(updater.missed.count) versions") }
        return parts.joined(separator: " · ")
    }

    private var downloadDetail: String {
        let got = ByteCountFormatter.string(fromByteCount: updater.received, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: updater.expected, countStyle: .file)
        guard updater.bytesPerSecond > 0 else { return "\(got) of \(total)" }
        let speed = ByteCountFormatter.string(fromByteCount: Int64(updater.bytesPerSecond), countStyle: .file)
        let left = Double(updater.expected - updater.received) / updater.bytesPerSecond
        return "\(got) of \(total) · \(speed)/s · \(left < 1 ? "almost done" : "\(Int(left.rounded())) s left")"
    }
}

// MARK: - Update sheet

struct UpdateSheet: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        @Bindable var updater = updater
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Check for updates automatically", isOn: $updater.autoCheck)
                    Toggle("Download updates in the background", isOn: $updater.autoDownload)
                        .disabled(!updater.autoCheck)
                }
                .toggleStyle(.checkbox)
                .font(.caption)
                Spacer()
                buttons
            }
            .padding(16)
        }
        .frame(width: 640, height: 580)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title2.weight(.bold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }

    private var title: String {
        switch updater.phase {
        case .checking: "Checking for updates…"
        case .upToDate: "You're up to date"
        case .installing: "Installing…"
        case .failed where updater.latest == nil: "Couldn't check for updates"
        default:
            if let r = updater.latest { updater.isReady ? "Tensor Tycoon \(r.version) is ready" : "Tensor Tycoon \(r.version) is available" } else { "Software Update" }
        }
    }

    private var subtitle: String {
        let current = updater.currentVersion?.description ?? "a development build"
        switch updater.phase {
        case .upToDate: return "Tensor Tycoon \(current) is the newest version."
        case .installing: return "Tensor Tycoon will reopen in a moment, right where you left off."
        default:
            guard let r = updater.latest else { return "You have \(current)." }
            var s = "You have \(current)."
            if let date = r.published { s += " Released \(date.formatted(date: .abbreviated, time: .omitted))." }
            return s
        }
    }

    @ViewBuilder
    private var content: some View {
        switch updater.phase {
        case .checking where updater.latest == nil:
            VStack(spacing: 12) {
                ProgressView()
                Text("Looking for new releases on GitHub…").foregroundStyle(.secondary)
            }
        case .upToDate:
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(.green)
                if let checked = updater.lastChecked {
                    Text("Checked \(checked.formatted(.relative(presentation: .named)))").foregroundStyle(.secondary)
                }
            }
        case .failed(let message) where updater.latest == nil:
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark").font(.system(size: 44)).foregroundStyle(.orange)
                Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 420)
            }
        default:
            if let release = updater.latest {
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        MarkdownNotes(text: updater.combinedNotes.isEmpty ? "No release notes." : updater.combinedNotes)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if updater.phase != .available || !updater.steps.isEmpty {
                        Divider()
                        UpdateSteps(release: release).padding(16)
                    }
                    if !updater.isPackaged {
                        Divider()
                        Label("You're running from source, so there's no app to replace. Download the release from GitHub or rebuild.",
                              systemImage: "hammer.fill")
                            .font(.caption).foregroundStyle(.secondary).padding(12)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch updater.phase {
        case .checking, .upToDate, .idle:
            Button("Done") { updater.later() }.keyboardShortcut(.defaultAction)
        case .failed where updater.latest == nil:
            Button("Close") { updater.later() }
            Button("Try Again") { Task { await updater.check(userInitiated: true) } }.keyboardShortcut(.defaultAction)
        case .downloading:
            Button("Cancel Download") { updater.cancelDownload() }
            Button("Later") { updater.later() }
            UpdatePrimaryButton()
        case .verifying, .installing:
            Button("Later") { updater.later() }.disabled(updater.phase == .installing)
            UpdatePrimaryButton()
        case .failed:
            Button("Later") { updater.later() }
            Button("Try Again") { updater.updateNow() }.keyboardShortcut(.defaultAction)
        case .ready:
            Button("Later") { updater.later() }
            UpdatePrimaryButton()
        case .available:
            Button("Skip This Version") { updater.skipThisVersion() }
            Button("Later") { updater.later() }
            UpdatePrimaryButton()
        }
    }
}

/// Download progress and each verification step as it passes.
private struct UpdateSteps: View {
    @Environment(Updater.self) private var updater
    let release: AppRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if updater.phase == .downloading {
                HStack {
                    Text("Downloading from GitHub").font(.caption.weight(.semibold))
                    Spacer()
                }
                UpdateProgressLine(release: release)
            }
            ForEach(updater.steps, id: \.self) { step in
                Label(step, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if updater.phase == .verifying {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Verifying…").font(.caption).foregroundStyle(.secondary)
                }
            }
            if case .failed(let message) = updater.phase {
                Label(message, systemImage: "xmark.octagon.fill").font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - What's new (first launch after an update)

struct WhatsNewSheet: View {
    let info: Updater.WhatsNew
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 84, height: 84)
                Text("Updated to Tensor Tycoon \(info.version)").font(.title.weight(.bold))
                Text("Here's what's new.").foregroundStyle(.secondary)
            }
            .padding(24)
            Divider()
            ScrollView {
                MarkdownNotes(text: info.notes.isEmpty ? "Bug fixes and improvements." : info.notes)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Spacer()
                Button {
                    onDone()
                } label: {
                    Text(info.resumeCompany.map { "Continue \($0)" } ?? "Let's go")
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 600, height: 560)
    }
}

// MARK: - Release notes

/// Renders GitHub release notes: headings, bullets, code blocks and inline markdown (bold, links, code).
struct MarkdownNotes: View {
    let text: String

    private struct Block: Identifiable {
        enum Kind { case heading(Int), bullet, code, paragraph }
        let id: Int
        let kind: Kind
        let text: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks) { block in
                switch block.kind {
                case .heading(let level):
                    inline(block.text)
                        .font(level <= 1 ? .title2.weight(.bold) : (level == 2 ? .title3.weight(.semibold) : .headline))
                        .padding(.top, 6)
                case .bullet:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        inline(block.text)
                    }
                case .code:
                    Text(block.text)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
                case .paragraph:
                    inline(block.text)
                }
            }
        }
    }

    private func inline(_ s: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return Text((try? AttributedString(markdown: s, options: options)) ?? AttributedString(s))
    }

    private var blocks: [Block] {
        var out: [Block] = []
        var paragraph: [String] = []
        var code: [String]? = nil
        func flush() {
            if !paragraph.isEmpty {
                out.append(Block(id: out.count, kind: .paragraph, text: paragraph.joined(separator: " ")))
                paragraph = []
            }
        }
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if let c = code {
                    out.append(Block(id: out.count, kind: .code, text: c.joined(separator: "\n")))
                    code = nil
                } else {
                    flush()
                    code = []
                }
                continue
            }
            if code != nil {
                code?.append(raw)
                continue
            }
            if line.isEmpty {
                flush()
            } else if line.hasPrefix("#") {
                flush()
                let level = line.prefix { $0 == "#" }.count
                out.append(Block(id: out.count, kind: .heading(level), text: line.dropFirst(level).trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flush()
                out.append(Block(id: out.count, kind: .bullet, text: String(line.dropFirst(2))))
            } else {
                paragraph.append(line)
            }
        }
        if let c = code { out.append(Block(id: out.count, kind: .code, text: c.joined(separator: "\n"))) }
        flush()
        return out
    }
}
