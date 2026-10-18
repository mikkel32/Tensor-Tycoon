import SwiftUI

/// 3.6: data economy — the Model Lab's data plan: domain-relevant tokens for this design, what the datasets add, and
/// warnings (too little code for a coding model, synthetic overuse, contamination, provenance, expiring licences).
struct DataPlanPanel: View {
    let design: ModelDesign
    let state: GameState

    var body: some View {
        let s = state
        let p = DataEconomy.plan(design, state: s, sources: Array(s.dataSources), detail: true)
        let warnings = DataEconomy.warnings(design, state: s, plan: p, est: Physics.estimate(design, state: s))
        let focus = Set(design.objective.focus + DataEconomy.wantedShare(design).map(\.0))
        let shown = CapDomain.allCases.filter { focus.contains($0) || p.relevantT[$0.index] > 0.0005 || p.gains[$0.index] != 0 }
        let top = max(1e-9, shown.map { p.effective[$0.index] }.max() ?? 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Data plan").font(.subheadline.weight(.semibold))
                Spacer()
                if p.active {
                    Pill(text: "Datasets in play", color: .purple, symbol: "externaldrive.fill.badge.plus")
                }
            }
            Text("Unique tokens relevant to each domain, and quality-weighted (curated tokens count many times raw crawl).")
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
                        .foregroundStyle(g > 0.005 ? .green : (g < -0.005 ? .orange : .secondary))
                        .help("log10 of quality-weighted tokens vs. your original sources alone")
                }
            }
            if p.active {
                let parts = [("data", p.dData), ("code", p.dCode), ("reasoning", p.dReasoning), ("agents", p.dAgent), ("chat", p.dChat),
                             ("languages", p.dLang), ("vision", p.dVis), ("long context", p.dLongctx)].filter { abs($0.1) >= 0.005 }
                if !parts.isEmpty {
                    Text("Datasets add: " + parts.map { "\($0.0) \(String(format: "%+.2f", $0.1))" }.joined(separator: " · ")
                         + (p.extraUniqueT > 0.001 ? " · +\(Fmt.tokens(p.extraUniqueT)) unique" : ""))
                        .font(.caption).foregroundStyle(.purple)
                }
            }
            ForEach(warnings, id: \.self) { w in
                Label(w, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }
}
