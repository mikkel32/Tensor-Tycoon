import SwiftUI

// MARK: - 3.4: product lines that capabilities unlock

struct ProductLinesView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let last = ProductLines.lastMonth(s)
        let lifetime = s.productLines.reduce(0) { $0 + $1.lifetime }
        let open = ProductLines.catalog.filter { p in ProductLines.status(p, s).ok && !s.productLines.contains { $0.id == p.id } }.count
        Page(title: "Product Lines",
             subtitle: "Products beyond chat, API, agents and contracts. Each opens when your best released model clears its domain bars and you've done the research that makes it shippable. Your share follows your product's quality against the rivals selling one, your brand and your reach.") {
            HStack(spacing: 14) {
                StatTile(title: "Lines running", value: "\(s.productLines.count) of \(ProductLines.catalog.count)",
                         detail: open > 0 ? "\(open) ready to launch" : nil, symbol: "square.grid.2x2.fill", tint: .indigo)
                StatTile(title: "Revenue last month", value: Fmt.money(last.revenue), detail: "Booked as other revenue", symbol: "dollarsign.circle.fill", tint: .green)
                StatTile(title: "Costs last month", value: Fmt.money(last.cost), detail: "Serving compute and upkeep", symbol: "arrow.down.circle.fill", tint: .orange)
                StatTile(title: "Lifetime revenue", value: Fmt.money(lifetime), symbol: "chart.line.uptrend.xyaxis", tint: .teal)
            }
            Card {
                CardHeader("How product share works", symbol: "info.circle")
                Text("Each product's quality is a mix of capability domains on your best released models (shown on every card). Against each rival product, every 10 points of quality is worth about 4.5× the pull, like the API market. Brand helps, and so does reach: labs sell new products first to the API, chat and agent customers they already have (your reach today: ×\(Fmt.trim(ProductLines.playerReach(s), 2))). Product lines run on your serving fleet, so they lose customers when it's overloaded, like the API (you serve \(Fmt.pct(s.reliability, decimals: 0)) of demand). Specialist companies keep part of every market. Customers sign up over a few months, so share builds slowly after a launch.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 16) {
                ForEach(ProductLines.catalog) { p in ProductCard(product: p, state: s) }
            }
        }
    }
}

private struct ProductCard: View {
    @Environment(GameStore.self) private var store
    let product: ProductDef
    let state: GameState
    @State private var confirmClose = false

    var body: some View {
        let s = state
        let p = product
        let line = s.productLines.first { $0.id == p.id }
        let st = ProductLines.status(p, s)
        let market = ProductLines.marketSize(p, s)
        let rivals = s.rivalProducts.filter { $0.product == p.id }.sorted { $0.share > $1.share }
        let mine = ProductLines.quality(p, s.labDomains["player"])
        let bestRival = rivals.map(\.quality).max()
        Card {
            HStack(alignment: .top) {
                Image(systemName: p.symbol).font(.title2).foregroundStyle(Color.accentColor).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.headline)
                    Text(p.pitch).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if line != nil {
                    Pill(text: "On sale", color: .green, symbol: "checkmark")
                } else if st.ok {
                    Pill(text: "Ready to launch", color: .blue)
                } else {
                    Pill(text: "Locked", color: .secondary, symbol: "lock.fill")
                }
            }
            SpecRow(label: "Market today", value: market > 0 ? "\(Fmt.money(market))/year" : "Not yet")
            SpecRow(label: "How it earns", value: p.earns)
            HStack(spacing: 6) {
                Text("Quality mix").font(.caption).foregroundStyle(.secondary)
                ForEach(Array(p.mix.enumerated()), id: \.offset) { _, m in
                    Pill(text: "\(m.0.short) \(Int((m.1 * 100).rounded()))%", color: .secondary, symbol: m.0.symbol)
                }
            }
            if s.labDomains["player"] != nil {
                SpecRow(label: "Your quality / best rival's", value: "\(Int(mine.rounded())) / \(bestRival.map { "\(Int($0.rounded()))" } ?? "—")")
            }
            if let line {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Your share").font(.caption)
                        Spacer()
                        Text("\(Fmt.pct(line.share)) → \(Fmt.pct(line.target))").font(.caption.monospacedDigit())
                    }
                    Meter(value: line.share / max(0.01, max(line.share, line.target, rivals.first?.share ?? 0)), tint: .green, height: 7)
                    Text("Last month: \(Fmt.money(line.lastRevenue)) revenue, \(Fmt.money(line.lastCost)) costs · since \(line.launched.gameMonth)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Button("Close this product line…", role: .destructive) { confirmClose = true }
                    .buttonStyle(.link).font(.caption)
                    .confirmationDialog("Close \(p.name)?", isPresented: $confirmClose) {
                        Button("Close it", role: .destructive) { store.mutate { $0.closeProduct(p.id) } }
                        Button("Keep it", role: .cancel) {}
                    }
            } else {
                if !st.ok {
                    ForEach(st.missing, id: \.self) { m in
                        Label(m, systemImage: "xmark.circle").font(.caption).foregroundStyle(.orange)
                    }
                }
                HStack {
                    Button("Launch for \(Fmt.money(ProductLines.launchCost(p, s.year)))") {
                        store.act("\(p.name) launched") { $0.launchProduct(p.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!st.ok)
                    Text("then \(Fmt.money(ProductLines.upkeep(p, s.year)))/mo upkeep + \(Int(p.serving * 100))% of revenue for serving")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if rivals.isEmpty {
                Text("No rival lab sells one yet.").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Competing: " + rivals.prefix(4).map { "\(CapStyle.labName($0.lab, s)) \(Fmt.pct($0.share, decimals: 0))" }.joined(separator: " · ")
                     + (rivals.count > 4 ? " · +\(rivals.count - 4) more" : ""))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
