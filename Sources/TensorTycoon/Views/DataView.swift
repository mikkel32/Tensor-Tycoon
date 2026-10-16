import SwiftUI

struct DataView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let b = s.bonuses
        let active = s.dataSources.compactMap { DataCatalog.byID[$0] }
        let tokens = Physics.availableTokensT(Array(s.dataSources), y: s.year, bonuses: b)
        let risk = active.reduce(0) { $0 + $1.legalRisk }
        Page(title: "Training Data", subtitle: "Models are what they eat. More unique tokens let you train bigger models without repeating data; quality data raises capability.") {
            HStack(spacing: 12) {
                StatTile(title: "Unique tokens", value: Fmt.tokens(tokens), detail: b.dataTokens > 0 ? "Incl. +\(Int(b.dataTokens * 100))% synthetic" : "Research synthetic data for more", symbol: "text.word.spacing", tint: .blue)
                StatTile(title: "Quality bonus", value: "+\(Fmt.trim(active.reduce(0) { $0 + $1.quality }, 2))", detail: "Capability from data", symbol: "sparkles", tint: .purple)
                StatTile(title: "Licensing cost", value: "\(Fmt.money(Economy.dataMonthlyCost(s)))/mo", detail: "Recurring", symbol: "doc.text.fill", tint: .orange)
                StatTile(title: "Legal risk", value: risk > 0.3 ? "High" : (risk > 0.05 ? "Moderate" : "Low"), detail: "Copyright exposure", symbol: "exclamationmark.shield.fill", tint: risk > 0.3 ? .red : .green)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 12)], spacing: 12) {
                ForEach(DataCatalog.all) { src in
                    let on = s.dataSources.contains(src.id)
                    let available = s.year >= src.available
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(src.name).font(.headline)
                            Spacer()
                            if on { Pill(text: "In use", color: .green, symbol: "checkmark") }
                            else if !available { Pill(text: "From \(Int(src.available))", color: .secondary) }
                        }
                        Text(src.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            if src.tokensT(s.year) > 0 { Pill(text: "\(Fmt.tokens(src.tokensT(s.year))) tokens", color: .blue) }
                            if src.quality > 0 { Pill(text: "+\(Fmt.trim(src.quality, 2)) quality", color: .purple) }
                            if src.code > 0 { Pill(text: "+code", color: .teal) }
                            if src.reasoning > 0 { Pill(text: "+reasoning", color: .pink) }
                            if src.arena > 0 { Pill(text: "+\(Int(src.arena)) Elo", color: .orange) }
                            if src.legalRisk > 0.1 { Pill(text: "Legal risk", color: .red, symbol: "exclamationmark.triangle.fill") }
                        }
                        HStack {
                            Text(src.free ? "Free" : (src.upfront > 0 ? "\(Fmt.money(src.upfront)) one-time" : "\(Fmt.money(src.monthly))/month"))
                                .font(.callout.weight(.semibold))
                            Spacer()
                            if src.id != "web" {
                                Button(on ? "Stop using" : (src.free ? "Use" : "License")) {
                                    store.act(on ? "Removed \(src.name)" : "Added \(src.name)") { $0.toggleData(src.id) }
                                }
                                .buttonStyle(.bordered)
                                .tint(on ? .secondary : .accentColor)
                                .disabled(!available && !on)
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            Text("Data choices are snapshotted when a training run starts. Removing a licence doesn't affect models already trained.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }
}
