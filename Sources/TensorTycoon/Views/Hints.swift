import SwiftUI

/// Which first-visit hints the player dismissed. Kept in UserDefaults, so it's per player on this Mac and shared by every
/// company they run; Help & Glossary turns hints off or shows them all again.
enum HintStore {
    static let seenKey = "hints.dismissedScreens"
    static let enabledKey = "hints.enabled"

    static func screens(in raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init))
    }

    static func adding(_ screen: Screen, to raw: String) -> String {
        var set = screens(in: raw)
        set.insert(screen.rawValue)
        return set.sorted().joined(separator: ",")
    }

    static func removing(_ screen: Screen, from raw: String) -> String {
        var set = screens(in: raw)
        set.remove(screen.rawValue)
        return set.sorted().joined(separator: ",")
    }
}

/// The first-visit hint for a screen: what it's for and the first useful thing to do, until dismissed. One line at the
/// top of a page's content: `ScreenHint(.models)`. Shows nothing for screens without a hint (`ScreenGuide`).
struct ScreenHint: View {
    @AppStorage(HintStore.seenKey) private var seen = ""
    @AppStorage(HintStore.enabledKey) private var enabled = true
    let screen: Screen

    init(_ screen: Screen) {
        self.screen = screen
    }

    var body: some View {
        if enabled, !HintStore.screens(in: seen).contains(screen.rawValue), let hint = ScreenGuide.hint(for: screen) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(hint.text)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(hint.firstStep, systemImage: "arrow.right.circle.fill")
                        .font(.callout.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        Button("Got it") { seen = HintStore.adding(screen, to: seen) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        if let term = hint.term { HelpLink(term: term) }
                        Spacer(minLength: 0)
                        Button("Hide all hints") { enabled = false }
                            .buttonStyle(.link)
                            .font(.caption)
                            .help("Turn hints back on in Help & Glossary")
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.08), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.35), lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Hint: \(hint.title)")
        }
    }
}

/// An empty state inside a card: what's missing, and a button to the next step.
struct NextStep: View {
    @Environment(GameStore.self) private var store
    let text: String
    let action: String
    let screen: Screen?
    let perform: (() -> Void)?

    /// Opens `screen`.
    init(_ text: String, action: String, screen: Screen) {
        self.text = text
        self.action = action
        self.screen = screen
        self.perform = nil
    }

    /// Runs `perform`.
    init(_ text: String, action: String, perform: @escaping () -> Void) {
        self.text = text
        self.action = action
        self.screen = nil
        self.perform = perform
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action) {
                if let perform {
                    perform()
                } else if let screen {
                    store.open(screen)
                }
            }
            .controlSize(.small)
        }
    }
}
