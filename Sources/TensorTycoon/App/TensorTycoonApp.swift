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

    init() {
        let args = CommandLine.arguments
        if args.contains("--forecast-check") {
            BalanceHarness.forecastCheck()
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
                .frame(minWidth: 1180, minHeight: 760)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.save()
                }
        }
        .defaultSize(width: 1480, height: 940)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Main Menu") { store.quitToMenu() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(store.state == nil)
            }
            CommandMenu("Game") {
                Button("Save Game") { store.save(); store.show("Game saved") }
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
        }
    }
}
