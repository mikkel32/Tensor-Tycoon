import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct TensorTycoonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = GameStore()
    @State private var updater = Updater()

    init() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--check-save"), i + 1 < args.count {
            exit(GameStore.checkSave(URL(fileURLWithPath: args[i + 1])))
        }
        if let i = args.firstIndex(of: "--verify-update"), i + 3 < args.count {
            exit(UpdateSelfTest.verifyLocal(zip: args[i + 1], version: args[i + 2], signatureFile: args[i + 3]))
        }
        if let i = args.firstIndex(of: "--update-selftest") {
            exit(UpdateSelfTest.run(pretending: i + 1 < args.count ? args[i + 1] : "0.0.1"))
        }
        if args.contains("--forecast-check") {
            BalanceHarness.forecastCheck()
            exit(0)
        }
        if let i = args.firstIndex(of: "--strategy") {
            BalanceHarness.strategy(era: i + 1 < args.count ? args[i + 1] : "2022")
            exit(0)
        }
        if let i = args.firstIndex(of: "--industry") {
            BalanceHarness.industry(era: i + 1 < args.count ? args[i + 1] : "2017")
            exit(0)
        }
        if args.contains("--scale") {
            BalanceHarness.scale()
            exit(0)
        }
        if let i = args.firstIndex(of: "--watch") {
            BalanceHarness.watch(era: i + 1 < args.count ? args[i + 1] : "2026")
            exit(0)
        }
        if let i = args.firstIndex(of: "--research") {
            BalanceHarness.research(era: i + 1 < args.count ? args[i + 1] : "2022")
            exit(0)
        }
        if let i = args.firstIndex(of: "--playtest") {
            PlaytestHarness.main(Array(args.dropFirst(i + 1)))
            exit(0)
        }
        if let i = args.firstIndex(of: "--determinism") {
            DeterminismHarness.main(Array(args.dropFirst(i + 1)))
            exit(0)
        }
        if let i = args.firstIndex(of: "--experience") {
            BalanceHarness.experience(era: i + 1 < args.count ? args[i + 1] : "2024")
            exit(0)
        }
        if let i = args.firstIndex(of: "--ventures") {
            BalanceHarness.ventures(era: i + 1 < args.count ? args[i + 1] : "2026")
            exit(0)
        }
        if let i = args.firstIndex(of: "--simulate") {
            BalanceHarness.run(era: i + 1 < args.count ? args[i + 1] : "2022")
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup("Tensor Tycoon") {
            RootView()
                .environment(store)
                .environment(updater)
                .frame(minWidth: 1180, minHeight: 760)
                .task {
                    updater.prepareForRelaunch = { [store] in
                        store.setSpeed(0)
                        store.saveNow()
                        return store.currentSaveURL
                    }
                    updater.start()
                    // Relaunched by an update without release notes to show: go straight back into the game.
                    if updater.whatsNew == nil, let url = updater.takeResumeSave() { store.load(url) }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.saveNow()
                    updater.installOnQuitIfReady()
                }
        }
        .defaultSize(width: 1480, height: 940)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { Task { await updater.check(userInitiated: true) } }
            }
            CommandGroup(replacing: .newItem) {
                Button("Main Menu") { store.quitToMenu() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(store.state == nil)
            }
            CommandMenu("Game") {
                Button("Go to…") { store.showPalette = true }
                    .keyboardShortcut("k")
                    .disabled(store.state == nil)
                Button("Save Game") { store.save(force: true); store.show("Game saved") }
                    .keyboardShortcut("s")
                    .disabled(store.state == nil)
                Divider()
                Button(store.speed == 0 ? "Play" : "Pause") { store.togglePause() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .disabled(store.state == nil)
                ForEach(1..<GameStore.speeds.count, id: \.self) { i in
                    Button("Speed \(GameStore.speeds[i].label)") { store.setSpeed(i) }
                        .keyboardShortcut(KeyEquivalent(Character("\(i)")), modifiers: .command)
                        .disabled(store.state == nil)
                }
                Button("Advance One Day") { store.step() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                    .disabled(store.state == nil)
            }
            CommandGroup(replacing: .help) {
                Button("Tensor Tycoon Help & Glossary") { store.open(.help) }
                    .keyboardShortcut("?", modifiers: .command)
                    .disabled(store.state == nil)
            }
        }
    }
}
