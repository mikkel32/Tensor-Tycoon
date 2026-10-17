import SwiftUI

/// ⌘K: jump to any screen or run a common action by typing a few letters.
struct CommandPalette: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected = 0
    @FocusState private var focused: Bool

    struct Item: Identifiable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        let keywords: String
        let run: @MainActor (GameStore) -> Void
    }

    var body: some View {
        let items = filtered
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Go to a screen or do something…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($focused)
                    .onSubmit { if items.indices.contains(selected) { execute(items[selected]) } }
                    .onKeyPress(.downArrow) { selected = min(selected + 1, max(0, items.count - 1)); return .handled }
                    .onKeyPress(.upArrow) { selected = max(selected - 1, 0); return .handled }
                    .onChange(of: query) { _, _ in selected = 0 }
            }
            .padding(14)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            Button { execute(item) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: item.symbol).frame(width: 22).foregroundStyle(i == selected ? Color.white : Color.accentColor)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.title).font(.callout.weight(.medium))
                                        if !item.detail.isEmpty {
                                            Text(item.detail).font(.caption).foregroundStyle(i == selected ? Color.white.opacity(0.8) : .secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(i == selected ? Color.white : Color.primary)
                                .background(i == selected ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 8))
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                        if items.isEmpty {
                            Text("Nothing matches \"\(query)\".").font(.callout).foregroundStyle(.secondary).padding(14)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: selected) { _, new in
                    if items.indices.contains(new) { proxy.scrollTo(items[new].id) }
                }
            }
            Divider()
            HStack {
                Text("↑↓ to choose · Return to go · Esc to close").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Close") { close() }.keyboardShortcut(.cancelAction)
            }
            .padding(10)
        }
        .frame(width: 520, height: 460)
        .onAppear { focused = true }
    }

    private var all: [Item] {
        var out: [Item] = []
        let s = store.state
        if let b = s?.briefings.first {
            out.append(Item(id: "briefing", title: "Read the \(b.month.gameMonth) briefing", detail: b.headline, symbol: "doc.text.magnifyingglass",
                            keywords: "briefing month report summary") { $0.openBriefing(b.id) })
        }
        for d in (s?.decisions ?? []).filter({ !Alerts.isUrgent($0) }) {
            out.append(Item(id: "inbox-\(d.id)", title: "Answer: \(d.title)", detail: "Waiting in your inbox", symbol: "tray.full.fill",
                            keywords: "inbox decision offer answer") { $0.openDecisionID = d.id })
        }
        out.append(Item(id: "pause", title: store.speed == 0 ? "Resume the game" : "Pause the game", detail: "⇧⌘P", symbol: store.speed == 0 ? "play.fill" : "pause.fill",
                        keywords: "pause play resume speed time") { $0.togglePause() })
        out.append(Item(id: "save", title: "Save the game", detail: "⌘S", symbol: "square.and.arrow.down",
                        keywords: "save") { st in st.save(force: true); st.show("Game saved") })
        out.append(Item(id: "era", title: "Era briefing", detail: "The world when you started and how to open", symbol: "globe",
                        keywords: "era intro start help guide") { $0.showEraIntro = true })
        for section in Screen.sections {
            for screen in section.1 {
                out.append(Item(id: "screen-\(screen.rawValue)", title: screen.title, detail: section.0, symbol: screen.symbol,
                                keywords: "\(screen.rawValue) \(section.0)") { $0.open(screen) })
            }
        }
        return out
    }

    private var filtered: [Item] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        let words = q.split(separator: " ").map(String.init)
        return all.filter { item in
            let hay = (item.title + " " + item.keywords + " " + item.detail).lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
        .sorted { a, b in
            // Titles that start with the query come first.
            let pa = a.title.lowercased().hasPrefix(q), pb = b.title.lowercased().hasPrefix(q)
            return pa && !pb
        }
    }

    private func execute(_ item: Item) {
        close()
        item.run(store)
    }

    private func close() {
        store.showPalette = false
        dismiss()
    }
}
