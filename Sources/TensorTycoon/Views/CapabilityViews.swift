import SwiftUI

// MARK: - 3.4: capability domains in the UI

enum CapStyle {
    /// The one line that explains every domain number.
    static let scaleNote = "Domain scores use the Capability yardstick: 100 = the frontier of early 2023, and +10 = ten times the effective compute."

    static func labColor(_ id: String, _ s: GameState) -> Color {
        id == "player" ? Theme.logoColor(s.logoColor) : Theme.competitorColor(CompetitorCatalog.def(id).color)
    }

    static func labName(_ id: String, _ s: GameState) -> String {
        id == "player" ? s.companyName : CompetitorCatalog.def(id).name
    }

    static func delta(_ d: Double) -> String {
        let r = d.rounded()
        return r > 0 ? "+\(Int(r))" : (r < 0 ? "−\(Int(-r))" : "±0")
    }

    static func deltaColor(_ d: Double) -> Color { d >= 0.5 ? .green : (d <= -0.5 ? .orange : .secondary) }
}

/// A spider chart of domain scores. Every series shares one radial scale, so shapes compare directly.
struct DomainRadar: View {
    struct Series: Identifiable {
        let id: String
        let scores: DomainScores
        let color: Color
    }

    let series: [Series]
    var labels = true

    private var domains: [CapDomain] { CapDomain.allCases }

    /// The radial range: a little below the weakest score shown to a little above the strongest.
    private var range: (lo: Double, hi: Double) {
        let all = series.flatMap { s in domains.map { s.scores[$0] } }
        let hi = (all.max() ?? 100) + 4
        let lo = max(0, ((all.min() ?? 0) - 12) / 10).rounded(.down) * 10
        return (lo, max(hi, lo + 20))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let r = max(10, min(w, h) / 2 - (labels ? 22 : 4))
            let rg = range
            ZStack {
                ForEach([0.34, 0.67, 1.0], id: \.self) { f in
                    outline(Array(repeating: f, count: domains.count), center: center, r: r)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                }
                ForEach(domains) { d in
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: point(d.index, 1, center: center, r: r))
                    }
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                }
                ForEach(series) { sr in
                    let fr = domains.map { clamp((sr.scores[$0] - rg.lo) / (rg.hi - rg.lo), 0.03, 1) }
                    outline(fr, center: center, r: r).fill(sr.color.opacity(0.16))
                    outline(fr, center: center, r: r).stroke(sr.color, lineWidth: 1.5)
                }
                if labels {
                    ForEach(domains) { d in
                        Text(d.short)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .position(point(d.index, 1, center: center, r: r + 13))
                    }
                }
            }
        }
    }

    private func point(_ i: Int, _ f: Double, center: CGPoint, r: Double) -> CGPoint {
        let a = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(domains.count)
        return CGPoint(x: center.x + cos(a) * r * f, y: center.y + sin(a) * r * f)
    }

    private func outline(_ fr: [Double], center: CGPoint, r: Double) -> Path {
        Path { p in
            for (i, f) in fr.enumerated() {
                let pt = point(i, f, center: center, r: r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
}

/// A coloured dot and a name, for chart legends.
struct DomainLegend: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

/// Every domain's score, with the gap to a comparison (the best rival, or another model).
struct DomainGrid: View {
    let scores: DomainScores
    /// What to compare each domain against (nil hides the gap).
    var compare: DomainScores? = nil
    var columns = 2

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), alignment: .leading, spacing: 5) {
            ForEach(CapDomain.allCases) { d in
                HStack(spacing: 5) {
                    Image(systemName: d.symbol).font(.caption2).foregroundStyle(.secondary).frame(width: 14)
                    Text(d.short).font(.caption).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(verbatim: "\(Int(scores[d].rounded()))").font(.caption.monospacedDigit().weight(.semibold))
                    if let c = compare {
                        let gap = scores[d] - c[d]
                        Text(CapStyle.delta(gap)).font(.caption2.monospacedDigit()).foregroundStyle(CapStyle.deltaColor(gap))
                            .frame(width: 30, alignment: .trailing)
                    }
                }
                .help(d.about)
            }
        }
    }
}

// MARK: - Model cards

/// A model's capability domains against the best rival today, and the milestones it reached first.
struct ModelDomainsSection: View {
    let model: AIModel
    let state: GameState

    var body: some View {
        let s = state
        if let v = s.domainScores[model.id.uuidString] {
            let rival = DomainScores(Capabilities.bestRival(s).map(\.score))
            let firsts = s.milestoneWins.filter { $0.isPlayer && $0.model == model.name }
            HStack(alignment: .top, spacing: 18) {
                DomainRadar(series: [.init(id: "rival", scores: rival, color: .orange),
                                     .init(id: "model", scores: v, color: .accentColor)])
                    .frame(width: 200, height: 180)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Capability domains").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        DomainLegend(label: model.name, color: .accentColor)
                        DomainLegend(label: "Best rival in each domain", color: .orange)
                    }
                    DomainGrid(scores: v, compare: rival, columns: 3)
                    Text(CapStyle.scaleNote + " The small number is the gap to the best rival model in that domain.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if !firsts.isEmpty {
                        Label("First AI to: " + firsts.compactMap { MilestoneCatalog.byID[$0.id]?.title }.joined(separator: " · "),
                              systemImage: "signpost.right.fill")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
            }
        }
    }
}

// MARK: - Lab profiles

/// A rival lab's capability shape against yours, the milestones it got to first and the product lines it sells.
struct LabCapabilitiesCard: View {
    @Environment(GameStore.self) private var store
    let labID: String

    var body: some View {
        let s = store.game
        let mine = s.labDomains["player"]
        let wins = s.milestoneWins.filter { $0.labID == labID }
        let lines = ProductLines.rivalLines(s, lab: labID)
        Card {
            CardHeader("Capabilities, milestones & product lines", symbol: "circle.hexagongrid.fill",
                       subtitle: "Its best released score in each domain")
            if let v = s.labDomains[labID] {
                HStack(alignment: .top, spacing: 14) {
                    DomainRadar(series: (mine.map { [DomainRadar.Series(id: "you", scores: $0, color: CapStyle.labColor("player", s))] } ?? [])
                        + [.init(id: labID, scores: v, color: CapStyle.labColor(labID, s))])
                        .frame(width: 190, height: 170)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            DomainLegend(label: CapStyle.labName(labID, s), color: CapStyle.labColor(labID, s))
                            if mine != nil { DomainLegend(label: "You", color: CapStyle.labColor("player", s)) }
                        }
                        DomainGrid(scores: v, compare: mine, columns: 2)
                        if mine != nil {
                            Text("The small number is its lead (+) or deficit (−) against your best released model.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No model out yet.").font(.callout).foregroundStyle(.secondary)
            }
            Divider()
            if wins.isEmpty {
                Text("No AI milestones reached first yet.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("First to \(wins.count) AI milestone\(wins.count == 1 ? "" : "s")").font(.caption.weight(.semibold))
                ForEach(wins.suffix(5).reversed()) { w in
                    HStack {
                        Image(systemName: MilestoneCatalog.byID[w.id]?.symbol ?? "signpost.right.fill").font(.caption2).foregroundStyle(.secondary)
                        Text(MilestoneCatalog.byID[w.id]?.title ?? w.id).font(.caption)
                        Spacer()
                        Text("\(w.model) · \(w.date.gameMonth)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            if lines.isEmpty {
                Text("Sells no product lines beyond chat, API and agents.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Product lines").font(.caption.weight(.semibold))
                ForEach(lines, id: \.product.id) { l in
                    HStack {
                        Image(systemName: l.def.symbol).font(.caption2).foregroundStyle(.secondary).frame(width: 14)
                        Text(ProductLines.rivalProductName(l.def, lab: labID)).font(.caption)
                        Spacer()
                        Text("\(Fmt.pct(l.product.share)) of \(l.def.name.lowercased()) · ≈\(Fmt.money(l.monthly))/mo")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Leaderboard

/// You against the best rival in each domain: where you lead and where you trail.
struct DomainRaceCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let s = store.game
        let best = Capabilities.bestRival(s)
        let rival = DomainScores(best.map(\.score))
        let mine = s.labDomains["player"]
        let unreleased = Capabilities.playerBest(s, releasedOnly: false)
        Card {
            CardHeader(title: "Capability domains: you vs the best rival", symbol: "circle.hexagongrid.fill",
                       subtitle: "Your best released model in each domain against the strongest rival model there") {
                Button("Milestones") { store.open(.milestones) }.buttonStyle(.link)
            }
            HStack(alignment: .top, spacing: 18) {
                DomainRadar(series: [.init(id: "rival", scores: rival, color: .orange)]
                            + (mine.map { [DomainRadar.Series(id: "you", scores: $0, color: CapStyle.labColor("player", s))] } ?? []))
                    .frame(width: 230, height: 210)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Domain").frame(width: 150, alignment: .leading)
                        Text("You").frame(width: 44, alignment: .trailing)
                        Text("Best rival").frame(width: 70, alignment: .trailing)
                        Text("Lab").frame(width: 130, alignment: .leading)
                        Text("Gap").frame(width: 44, alignment: .trailing)
                    }
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(CapDomain.allCases) { d in
                        let r = best[d.index]
                        HStack {
                            Label(d.label, systemImage: d.symbol).frame(width: 150, alignment: .leading)
                            Text(mine.map { "\(Int($0[d].rounded()))" } ?? "—").frame(width: 44, alignment: .trailing)
                            Text(verbatim: "\(Int(r.score.rounded()))").frame(width: 70, alignment: .trailing)
                            Text(r.lab.isEmpty ? "—" : CapStyle.labName(r.lab, s)).lineLimit(1).frame(width: 130, alignment: .leading)
                            if let m = mine {
                                Text(CapStyle.delta(m[d] - r.score)).foregroundStyle(CapStyle.deltaColor(m[d] - r.score))
                                    .frame(width: 44, alignment: .trailing)
                            } else {
                                Text("—").frame(width: 44, alignment: .trailing)
                            }
                        }
                        .font(.caption.monospacedDigit())
                        .help(d.about)
                    }
                    if let u = unreleased, let m = mine, CapDomain.allCases.contains(where: { u[$0] > m[$0] + 0.5 }) {
                        Text("An unreleased model of yours is stronger in \(CapDomain.allCases.filter { u[$0] > m[$0] + 0.5 }.map(\.short).joined(separator: ", ")). Ship it to count.")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                    Text(CapStyle.scaleNote).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Model Lab

/// What a design is forecast to reach in each domain, and which firsts and product lines that would open.
struct DesignDomainsCard: View {
    let profile: ModelProfile
    let design: ModelDesign
    let state: GameState

    var body: some View {
        let s = state
        let v = Capabilities.forecast(profile, design: design, state: s)
        let mine = s.labDomains["player"]
        let firsts = Milestones.reachable(s, v)
        let products = ProductLines.clears(v).filter { p in !s.productLines.contains { $0.id == p.id } }
        Card {
            CardHeader("Capability domains (forecast)", symbol: "circle.hexagongrid.fill",
                       subtitle: mine == nil ? "At the expected capability" : "At the expected capability · small numbers: change vs your best released model")
            DomainGrid(scores: v, compare: mine, columns: 3)
            if !firsts.isEmpty {
                Label("Would be the first AI to: " + firsts.prefix(4).map(\.title).joined(separator: " · ") + (firsts.count > 4 ? " and \(firsts.count - 4) more" : ""),
                      systemImage: "signpost.right.fill")
                    .font(.caption).foregroundStyle(.green)
            }
            if !products.isEmpty {
                Label("Clears the bar for: " + products.map { p in
                    p.name + (s.researched.contains(p.research) ? "" : " (needs \(ResearchCatalog.byID[p.research]?.name ?? p.research))")
                }.joined(separator: " · "), systemImage: "square.grid.2x2.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !design.vision || !design.audio {
                Text("\(design.vision ? "" : "Without vision it can't see (Vision and Robotics stay low). ")\(design.audio ? "" : "Without audio it talks through a speech pipeline (Voice stays low).")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
