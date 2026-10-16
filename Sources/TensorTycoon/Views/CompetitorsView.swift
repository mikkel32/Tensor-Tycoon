import Charts
import SwiftUI

struct CompetitorsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let comps = s.competitors.sorted { ($0.latest?.index ?? -1) > ($1.latest?.index ?? -1) }
        Page(title: "Competitors", subtitle: "Eight rival labs (fictional, inspired by real archetypes). They release on their own schedules and react when you pull ahead.") {
            Card {
                CardHeader("Compute arms race", symbol: "cpu", subtitle: "Estimated H100-equivalents")
                let rows: [(String, Double, Color)] = comps.filter { $0.computeH100e > 0 }.map { ($0.def.name, $0.computeH100e, Theme.competitorColor($0.def.color)) }
                    + [(s.companyName, max(0.1, store.derived.h100e), Theme.logoColor(s.logoColor))]
                let maxV = rows.map(\.1).max() ?? 1
                VStack(spacing: 7) {
                    ForEach(rows.sorted { $0.1 > $1.1 }, id: \.0) { r in
                        HStack(spacing: 10) {
                            Text(r.0).font(.caption).frame(width: 160, alignment: .leading).lineLimit(1)
                            GeometryReader { geo in
                                let frac = clamp(log10(max(r.1, 0.1) * 10) / max(log10(maxV * 10), 1), 0.01, 1)
                                Capsule().fill(r.2.gradient).frame(width: geo.size.width * frac)
                            }
                            .frame(height: 12)
                            Text(Fmt.count(r.1)).font(.caption.monospacedDigit()).frame(width: 60, alignment: .trailing)
                        }
                    }
                    Text("Log scale").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 440), spacing: 14)], spacing: 14) {
                ForEach(comps) { c in CompetitorCard(comp: c, state: s) }
            }
        }
    }
}

private struct CompetitorCard: View {
    let comp: CompetitorState
    let state: GameState

    var body: some View {
        let d = comp.def
        let s = state
        let founded = s.year >= d.founded.decimal
        let color = Theme.competitorColor(d.color)
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: d.symbol).font(.title2.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name).font(.title3.weight(.bold))
                    Text("\(d.archetype) · \(d.hq)").font(.caption).foregroundStyle(.secondary)
                    Text("CEO \(d.ceo) · founded \(d.founded.label)").font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
                if let m = comp.latest {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Fmt.score(m.index)).font(.title.weight(.bold).monospacedDigit())
                        Text(m.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !founded {
                Text("Not founded yet.").font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), alignment: .leading) {
                    Mini(label: "Valuation", value: comp.valuation > 0 ? Fmt.money(comp.valuation) : "—")
                    Mini(label: "Compute", value: "\(Fmt.count(comp.computeH100e)) H100e")
                    Mini(label: "API share", value: Fmt.pct(comp.apiShare))
                    Mini(label: "Chat share", value: Fmt.pct(comp.consumerShare))
                    Mini(label: "Agent share", value: Fmt.pct(comp.agentShare))
                }
                let trait = Competitors.trait(comp.id)
                Label("Signature: \(trait.signature)", systemImage: "seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                let armed = Xeno.rivalC(s, comp.id, at: s.date)
                if armed > 0.005 {
                    Label("Running on your tech: +\(Fmt.trim(armed, 2)) capability from chips and licenses you sold them", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                let techs = (s.rivalTech[comp.id] ?? []).compactMap { ResearchCatalog.byID[$0] }.filter { $0.year <= s.year + 1 }
                if !techs.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(techs) { item in
                            let live = item.year <= s.year + 0.3
                            Pill(text: "\(item.name)\(live ? "" : " (in development)")", color: live ? .purple : .secondary, symbol: "atom")
                                .help(item.blurb)
                        }
                    }
                }
                if comp.priceCut > 0.01 {
                    Label("Price war: API prices cut \(Fmt.pct(comp.priceCut, decimals: 0))", systemImage: "tag.slash.fill").font(.caption).foregroundStyle(.red)
                }
                if comp.models.count > 1 {
                    Chart(comp.models) { m in
                        LineMark(x: .value("Date", m.date), y: .value("Index", m.index))
                            .foregroundStyle(color)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", m.date), y: .value("Index", m.index))
                            .foregroundStyle(color)
                            .symbolSize(18)
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 110)
                }
                HStack(spacing: 6) {
                    ForEach(comp.models.suffix(4).reversed()) { m in
                        Pill(text: "\(m.name) · \(m.date.gameMonth)", color: color)
                    }
                }
                if comp.nextRelease > s.date && comp.nextRelease < GameCalendar.addDays(s.date, 120) {
                    Text("Rumour: next model expected around \(comp.nextRelease.gameMonth)").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .opacity(founded ? 1 : 0.6)
    }
}

private struct Mini: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.callout.weight(.semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
