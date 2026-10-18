import SwiftUI

/// One line of a briefing: ▲ good, ▼ bad, · neutral, with a link to where you'd act on it.
struct BriefingLineView: View {
    @Environment(GameStore.self) private var store
    let line: BriefingLine
    var onGo: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 14)
            Text(line.text).font(.callout).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            if let target = line.target {
                Button {
                    onGo?()
                    store.open(target)
                } label: {
                    Image(systemName: "arrow.right.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Open \(target.title)")
                .accessibilityLabel("Open \(target.title)")
            }
        }
    }

    private var symbol: String {
        switch line.good {
        case .some(true): "arrowtriangle.up.fill"
        case .some(false): "arrowtriangle.down.fill"
        case .none: "circle.fill"
        }
    }

    private var tint: Color {
        switch line.good {
        case .some(true): .green
        case .some(false): .red
        case .none: .secondary
        }
    }
}

/// The latest monthly briefing on the dashboard.
struct BriefingCard: View {
    @Environment(GameStore.self) private var store
    let briefing: MonthlyBriefing

    var body: some View {
        Card {
            CardHeader(title: "\(briefing.month.gameMonth) briefing", symbol: "doc.text.magnifyingglass", subtitle: "What changed last month and why") {
                Button("Read the briefing") { store.openBriefing(briefing.id) }.buttonStyle(.link)
            }
            Text(briefing.headline).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            let lines = Array((briefing.drivers + briefing.rivals.filter { $0.good == false }).prefix(4))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                BriefingLineView(line: l)
            }
        }
    }
}

struct BriefingSheet: View {
    @Environment(GameStore.self) private var store
    let id: UUID
    @State private var current: UUID?

    var body: some View {
        let all = store.state?.briefings ?? []
        let shown = current ?? id
        if let i = all.firstIndex(where: { $0.id == shown }) {
            content(all[i], newer: i > 0 ? all[i - 1].id : nil, older: i + 1 < all.count ? all[i + 1].id : nil)
        } else {
            VStack(spacing: 12) {
                Text("This briefing is no longer available.").foregroundStyle(.secondary)
                Button("Close") { close() }.keyboardShortcut(.defaultAction)
            }
            .padding(30)
        }
    }

    private func content(_ b: MonthlyBriefing, newer: UUID?, older: UUID?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { current = older } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless).disabled(older == nil).help("Previous month").accessibilityLabel("Previous month")
                Text("\(b.month.gameMonth) briefing").font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                Button { current = newer } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless).disabled(newer == nil).help("Next month").accessibilityLabel("Next month")
                Spacer()
            }
            .padding([.horizontal, .top], 22)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(b.headline).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        StatTile(title: "Revenue", value: Fmt.money(b.revenue),
                                 detail: "\(b.revenueChange >= 0 ? "+" : "−")\(Fmt.pct(abs(b.revenueChange), decimals: 1)) per day vs. the month before",
                                 symbol: "chart.line.uptrend.xyaxis", tint: b.revenueChange >= 0 ? .green : .orange)
                        StatTile(title: "Profit", value: Fmt.money(b.profit), detail: b.profit >= 0 ? "In the black" : "Burning cash",
                                 symbol: "plus.forwardslash.minus", tint: b.profit >= 0 ? .green : .orange)
                        StatTile(title: "Cash", value: Fmt.money(b.cash), detail: b.runway.map { "\(Fmt.trim($0, 1)) months at this burn" } ?? "Cash-flow positive",
                                 symbol: "banknote.fill", tint: (b.runway ?? 99) < 6 ? .red : .blue)
                    }
                    section("Why the numbers moved", "chart.bar.doc.horizontal", b.drivers, empty: "Nothing moved much.")
                    section("Rivals", "binoculars.fill", b.rivals, empty: "A quiet month in the industry.")
                    section("Risks", "exclamationmark.triangle.fill", b.risks, empty: "Nothing urgent on the horizon.")
                    section("What to do", "checklist", b.actions, empty: "The Chief of Staff has nothing for you.")
                }
                .padding(22)
            }
            Divider()
            HStack {
                Text("Briefings arrive on the 1st of each month. The last 12 are kept.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { close() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 680, height: 640)
        .onAppear { store.mutate { $0.markBriefingSeen(b.id) } }
    }

    @ViewBuilder
    private func section(_ title: String, _ symbol: String, _ lines: [BriefingLine], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline)
            if lines.isEmpty {
                Text(empty).font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                    BriefingLineView(line: l) { close() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }

    private func close() {
        store.briefingID = nil
    }
}
