import SwiftUI

/// 3.6: data economy — the Model Lab's data plan: domain-relevant tokens for this design, what the datasets add, and
/// warnings (too little code for a coding model, synthetic overuse, contamination, provenance, expiring licences).
/// A run freezes this plan when it starts.
struct DataPlanPanel: View {
    let design: ModelDesign
    let state: GameState

    var body: some View {
        let s = state
        let p = DataEconomy.plan(design, state: s, sources: s.dataSources.sorted(), detail: true)
        let warnings = DataEconomy.warnings(design, state: s, plan: p, est: Physics.estimate(design, state: s))
        let focus = Set(design.objective.focus + DataEconomy.wantedShare(design).map(\.0))
        let shown = CapDomain.allCases.filter { focus.contains($0) || p.relevantT[$0.index] > 0.0005 || p.gains[$0.index] != 0 }
        let top = max(1e-9, shown.map { p.effective[$0.index] }.max() ?? 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Data plan").font(.subheadline.weight(.semibold))
                Spacer()
                if p.datasets {
                    Pill(text: "Datasets in play", color: .purple, symbol: "externaldrive.fill.badge.plus")
                }
            }
            Text("Unique tokens relevant to each domain, and quality-weighted (curated tokens count many times raw crawl; noise counts for nothing). Domains this design is built for count 30% more. Frozen when the run starts.")
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(shown) { dm in
                let e = p.effective[dm.index]
                let g = p.gains[dm.index]
                HStack(spacing: 6) {
                    Image(systemName: dm.symbol).frame(width: 14).foregroundStyle(focus.contains(dm) ? Color.accentColor : Color.secondary)
                    Text(dm.short).font(.caption).frame(width: 64, alignment: .leading)
                    Meter(value: log10(1 + 9 * e / top), tint: focus.contains(dm) ? .accentColor : .gray, height: 6)
                    Text(Fmt.tokens(p.relevantT[dm.index])).font(.caption2.monospacedDigit()).frame(width: 56, alignment: .trailing)
                    Text(abs(g) < 0.005 ? "—" : String(format: "%+.2f", g))
                        .font(.caption2.monospacedDigit()).frame(width: 36, alignment: .trailing)
                        .foregroundStyle(Self.gainColor(g))
                        .help("log10 of quality-weighted tokens vs. your original sources alone, weighted by what the design is for")
                }
            }
            if p.active {
                let adds = Self.addsLine(p)
                if !adds.isEmpty {
                    Text(adds).font(.caption).foregroundStyle(.purple)
                }
                if p.syntheticRawT > 0.0005 {
                    Text(Self.syntheticLine(p))
                        .font(.caption2).foregroundStyle(p.collapseFactor < 1 ? Tone.warning.color : Color.secondary)
                }
            }
            ForEach(warnings, id: \.self) { w in
                Label(w, systemImage: Tone.warning.symbol)
                    .font(.caption).foregroundStyle(Tone.warning.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }

    static func gainColor(_ g: Double) -> Color {
        if g > 0.005 { return Tone.good.color }
        return g < -0.005 ? Tone.warning.color : Color.secondary
    }

    /// "Datasets add: code +0.07 · science +0.4 pts · +2T unique" ("" when nothing).
    static func addsLine(_ p: DataPlan) -> String {
        let skills: [(String, Double)] = [("data", p.dData), ("code", p.dCode), ("reasoning", p.dReasoning), ("agents", p.dAgent), ("chat", p.dChat),
                                          ("languages", p.dLang), ("vision", p.dVis), ("long context", p.dLongctx)]
        var parts: [String] = []
        for (name, v) in skills where abs(v) >= 0.005 { parts.append("\(name) \(String(format: "%+.2f", v))") }
        for d in CapDomain.allCases where abs(p.domain[d.index]) >= 0.005 {
            parts.append("\(d.short.lowercased()) \(String(format: "%+.1f", 10 * p.domain[d.index])) pts")
        }
        guard !parts.isEmpty else { return "" }
        var t = "Datasets add: "
        t += parts.joined(separator: " · ")
        if p.extraUniqueT > 0.001 { t += " · +\(Fmt.tokens(p.extraUniqueT)) unique" }
        return t
    }

    /// Synthetic data in this plan: generated, counted as new, share, collapse.
    static func syntheticLine(_ p: DataPlan) -> String {
        var t = "Synthetic data (slider and datasets): \(Fmt.tokens(p.syntheticRawT)) generated, "
        t += "\(Fmt.tokens(p.syntheticUniqueT)) count as new tokens · \(Int(p.syntheticShare * 100))% of the corpus"
        if p.collapseFactor < 1 { t += " · collapse keeps ×\(Fmt.trim(p.collapseFactor, 2)) of the gains" }
        return t
    }
}
