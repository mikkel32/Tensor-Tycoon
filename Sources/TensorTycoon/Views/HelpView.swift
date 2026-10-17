import SwiftUI

// MARK: - Help screen

/// Help & Glossary: every term in plain language (searchable), how a game goes, the keyboard shortcuts and the
/// first-visit hints switch.
struct HelpView: View {
    @State private var query = ""
    @State private var topic: GlossaryCategory?
    @State private var expanded: Set<GlossaryTerm> = []

    var body: some View {
        let router = HelpRouter.shared
        Page(title: "Help & Glossary", subtitle: "What the game's terms mean and where you see them, how a game goes, and the keyboard shortcuts.") {
            HStack(alignment: .top, spacing: 16) {
                glossary
                    .frame(maxWidth: .infinity)
                VStack(spacing: 16) {
                    HowAGameGoesCard()
                    ShortcutsCard()
                    HintSettingsCard()
                }
                .frame(width: 340)
            }
        }
        .onAppear { takePending() }
        .onChange(of: router.pending) { takePending() }
    }

    /// A "?" popover's "All terms" or a ⌘K result asked for a term: search for it and open it.
    private func takePending() {
        guard let term = HelpRouter.shared.pending else { return }
        HelpRouter.shared.pending = nil
        query = term.title
        topic = nil
        expanded.insert(term)
    }

    private var glossary: some View {
        let searching = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let found = Glossary.search(query).filter { topic == nil || $0.category == topic }
        return Card {
            CardHeader("Glossary", symbol: "book.closed.fill",
                       subtitle: "\(GlossaryTerm.allCases.count) terms in plain language. Click one for more and for where you see it.")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search, for example goodput or runway", text: $query)
                    .textFieldStyle(.roundedBorder)
                if searching {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.borderless)
                        .help("Clear the search")
                        .accessibilityLabel("Clear the search")
                }
                Picker("Topic", selection: $topic) {
                    Text("All topics").tag(GlossaryCategory?.none)
                    ForEach(GlossaryCategory.allCases) { c in Text(c.rawValue).tag(GlossaryCategory?.some(c)) }
                }
                .labelsHidden()
                .frame(width: 190)
            }
            if found.isEmpty {
                Text(searching ? "No term matches \"\(query)\". Try one word, like \"runway\" or \"index\"." : "No terms in this topic.")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else if searching {
                ForEach(found) { t in termRow(t) }
            } else {
                ForEach(GlossaryCategory.allCases.filter { c in topic == nil || topic == c }) { c in
                    Label(c.rawValue, systemImage: c.symbol)
                        .font(.headline)
                        .padding(.top, 6)
                    ForEach(found.filter { $0.category == c }) { t in termRow(t) }
                }
            }
        }
    }

    private func termRow(_ t: GlossaryTerm) -> some View {
        GlossaryRow(term: t, expanded: expanded.contains(t)) {
            if expanded.contains(t) { expanded.remove(t) } else { expanded.insert(t) }
        }
    }
}

/// One term: its definition, and when opened, how it works in the game and where you see it.
private struct GlossaryRow: View {
    @Environment(GameStore.self) private var store
    let term: GlossaryTerm
    let expanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: toggle) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(term.title).font(.callout.weight(.semibold))
                        Text(term.definition).font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Hides the details" : "Shows how it works and where you see it")
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(term.detail).font(.callout).fixedSize(horizontal: false, vertical: true)
                    if let screen = term.screen {
                        Button("Where you see it: \(screen.title)") { store.open(screen) }
                            .buttonStyle(.link)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 3)
    }
}

/// The loop of the game in six steps, each a link to where you do it.
private struct HowAGameGoesCard: View {
    @Environment(GameStore.self) private var store

    private static let steps: [(text: String, screen: Screen)] = [
        ("Train a model in the Model Lab. The forecast tells you what you'll get before you spend.", .lab),
        ("Release it and give it serving chips, so it can sell tokens through the API.", .models),
        ("Sell it in more ways: a chat app, agent seats and enterprise contracts.", .market),
        ("Research and hire, so the next run is better and cheaper.", .research),
        ("Watch cash and runway, and raise money before it runs low.", .funding),
        ("Keep an eye on rivals: Rival Watch shows who is about to ship what.", .rivalWatch),
    ]

    var body: some View {
        Card {
            CardHeader(title: "How a game goes", symbol: "map.fill") {
                Button("Era briefing") { store.showEraIntro = true }.buttonStyle(.link)
            }
            ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, step in
                Button {
                    store.open(step.screen)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "\(i + 1)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.accentColor, in: .circle)
                        Text(step.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Open \(step.screen.title)")
            }
            Text("The dashboard's Needs you list and the monthly briefing tell you what to do next; delegates on Operations can take the routine work.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ShortcutsCard: View {
    var body: some View {
        let speeds = GameStore.speeds.dropFirst().map { $0.label }.joined(separator: ", ")
        Card {
            CardHeader("Keyboard shortcuts", symbol: "keyboard")
            ShortcutRow(keys: "⌘K", action: "Go to a screen, a rival lab or a glossary term")
            ShortcutRow(keys: "⇧⌘P", action: "Pause or resume")
            ShortcutRow(keys: "⌘1 – ⌘5", action: "Game speed: \(speeds)")
            ShortcutRow(keys: "⌘→", action: "Advance one day")
            ShortcutRow(keys: "⌘S", action: "Save the game")
            ShortcutRow(keys: "⌘?", action: "Open Help & Glossary")
            ShortcutRow(keys: "⇧⌘N", action: "Save and go back to the main menu")
            Divider()
            ShortcutRow(keys: "↑ ↓  Return", action: "Pick a result in the ⌘K palette and go")
            ShortcutRow(keys: "Return", action: "The highlighted button in a sheet")
            ShortcutRow(keys: "Esc", action: "Close a sheet or the palette; \"Decide later\" on an inbox offer")
        }
    }
}

private struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(keys)
                .font(.callout.monospacedDigit().weight(.semibold))
                .frame(width: 92, alignment: .leading)
            Text(action).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Turn the first-visit hints on or off, or show them all again.
private struct HintSettingsCard: View {
    @Environment(GameStore.self) private var store
    @AppStorage(HintStore.seenKey) private var seen = ""
    @AppStorage(HintStore.enabledKey) private var enabled = true

    var body: some View {
        let dismissed = HintStore.screens(in: seen).count
        Card {
            CardHeader("Screen hints", symbol: "lightbulb.fill",
                       subtitle: "A short note on what a screen is for and the first thing to do there, until you dismiss it.")
            Toggle("Show hints on screens I haven't dismissed", isOn: $enabled)
                .toggleStyle(.switch)
            HStack {
                Button("Show hints again") {
                    seen = ""
                    enabled = true
                    store.show("Hints will show again on \(ScreenGuide.screens.count) screens")
                }
                .disabled(dismissed == 0 && enabled)
                Spacer()
                Text("\(dismissed) of \(ScreenGuide.screens.count) dismissed").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - "?" buttons and popovers

/// Where the Help screen should land next: a "?" popover's "All terms" link and ⌘K results set it.
@MainActor
@Observable
final class HelpRouter {
    static let shared = HelpRouter()
    var pending: GlossaryTerm?

    /// Open Help & Glossary at `term`.
    func show(_ term: GlossaryTerm, in store: GameStore) {
        pending = term
        store.open(.help)
    }
}

/// A small "?" next to a label: click it for the term's definition, how it works and a link to where you see it.
struct HelpButton: View {
    let term: GlossaryTerm
    @State private var shown = false

    var body: some View {
        Button {
            shown.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("What's this? \(term.title)")
        .accessibilityLabel("Explain \(term.title)")
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            GlossaryPopover(term: term) { shown = false }
        }
    }
}

/// The same explanation behind a text link ("More on goodput"), for hints and empty states.
struct HelpLink: View {
    let term: GlossaryTerm
    @State private var shown = false

    var body: some View {
        Button("More on \(term.title)") { shown.toggle() }
            .buttonStyle(.link)
            .popover(isPresented: $shown, arrowEdge: .bottom) {
                GlossaryPopover(term: term) { shown = false }
            }
    }
}

struct GlossaryPopover: View {
    @Environment(GameStore.self) private var store
    let term: GlossaryTerm
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(term.title, systemImage: "questionmark.circle.fill")
                .font(.headline)
            Text(term.definition)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(term.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack(spacing: 12) {
                if let screen = term.screen, !showing(screen) {
                    Button("Where you see it: \(screen.title)") {
                        close()
                        store.open(screen)
                    }
                    .buttonStyle(.link)
                }
                Spacer(minLength: 0)
                Button("All terms") {
                    close()
                    HelpRouter.shared.show(term, in: store)
                }
                .buttonStyle(.link)
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 340)
    }

    /// Already on that screen (the Rivals hub hosts Rival Watch, the industry and the labs).
    private func showing(_ screen: Screen) -> Bool {
        store.screen == screen || (store.screen == .rivals && [.rivalWatch, .industry, .competitors].contains(screen))
    }
}

extension View {
    /// A "?" in the top-right corner that explains `term`, for cards and tiles without a header slot for one.
    func helpBadge(_ term: GlossaryTerm) -> some View {
        overlay(alignment: .topTrailing) {
            HelpButton(term: term).padding(10)
        }
    }
}
