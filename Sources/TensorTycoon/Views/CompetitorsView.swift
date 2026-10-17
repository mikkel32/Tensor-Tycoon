import SwiftUI

/// The Rivals hub's Labs tab: a card per lab in business (click for its profile), the labs that left the market, and
/// the ones not founded yet.
struct RivalLabsTab: View {
    @Environment(GameStore.self) private var store
    let open: (String) -> Void

    var body: some View {
        let s = store.game
        let alive = RivalLifecycle.labsInBusiness(s).sorted { ($0.models.map(\.index).max() ?? -1) > ($1.models.map(\.index).max() ?? -1) }
        let gone = s.competitors.filter { !$0.exitNote.isEmpty }.sorted { ($0.exitDate ?? .distantPast) > ($1.exitDate ?? .distantPast) }
        let later = s.competitors.filter { s.year < $0.def.founded.decimal }
        let watch = store.derived.watch
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 14)], spacing: 14) {
                ForEach(alive) { c in
                    LabCard(comp: c, state: s, next: watch.first { $0.id == c.id }, open: open)
                }
            }
            if !gone.isEmpty {
                GoneLabsCard(labs: gone, state: s, open: open)
            }
            if !later.isEmpty {
                Text("Not founded yet: " + later.map { "\($0.def.name) (\($0.def.founded.label))" }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// A lab at a glance; the whole card opens its profile.
private struct LabCard: View {
    let comp: CompetitorState
    let state: GameState
    let next: RivalIntel.Row?
    let open: (String) -> Void

    var body: some View {
        Button {
            open(comp.id)
        } label: {
            Card {
                header
                stats
                strategy
                footer
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Open \(comp.def.name)'s profile")
    }

    private var header: some View {
        let d = comp.def
        let best = comp.models.max { $0.index < $1.index }
        return HStack(alignment: .top, spacing: 12) {
            CompanyLogo(symbol: d.symbol, color: Theme.competitorColor(d.color), size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.name).font(.title3.weight(.bold)).lineLimit(1)
                Text(d.archetype).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 5) {
                    let status = RivalEconomy.status(comp, state)
                    Pill(text: status, color: RivalsStyle.statusColor(status))
                    if let spec = comp.spec { Pill(text: spec.kind.label, color: .secondary) }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(best.map { Fmt.score($0.index) } ?? "—").font(.title.weight(.bold).monospacedDigit())
                Text(best?.name ?? "No model yet").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4), alignment: .leading, spacing: 8) {
            LabMini(label: "Valuation", value: comp.valuation > 0 ? Fmt.money(comp.valuation) : "—")
            LabMini(label: "Revenue / yr", value: Fmt.money(comp.revenueRun))
            LabMini(label: "Compute", value: "\(Fmt.count(comp.computeH100e)) H100e")
            LabMini(label: "Staff", value: Fmt.int(comp.headcount))
        }
    }

    @ViewBuilder
    private var strategy: some View {
        if let play = RivalStrategy.play(comp) {
            Label(play.title, systemImage: play.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(play.threat >= 2 ? .red : (play.threat == 1 ? .orange : .secondary))
            Text(comp.playReason).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        } else if comp.models.isEmpty {
            Label("Building its first model, due around \(comp.def.firstModel.label)", systemImage: "hammer.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let n = next {
            Label("Next: \(n.project.name) · \(RivalIntel.windowText(n.outlook)) · forecast \(Fmt.score(n.outlook.index))", systemImage: "binoculars.fill")
                .font(.caption)
                .foregroundStyle(n.threat == .passYou ? .red : .secondary)
        }
    }
}

struct LabMini: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.callout.weight(.semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// Labs that left the market, and how.
private struct GoneLabsCard: View {
    let labs: [CompetitorState]
    let state: GameState
    let open: (String) -> Void

    var body: some View {
        Card {
            CardHeader("Gone", symbol: "archivebox.fill", subtitle: "Bought, merged, bankrupt or wound down. Their models stay on the record.")
            ForEach(labs) { c in
                Button {
                    open(c.id)
                } label: {
                    HStack(spacing: 10) {
                        CompanyLogo(symbol: c.def.symbol, color: Theme.competitorColor(c.def.color).opacity(0.6), size: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.def.name).font(.callout.weight(.semibold))
                            Text(c.exitNote).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        let status = RivalEconomy.status(c, state)
                        Pill(text: status, color: RivalsStyle.statusColor(status))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Price, payment mix, antitrust risk and what you'd get for buying a rival.
struct AcquirePanel: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let comp: CompetitorState
    let state: GameState
    @State private var stockShare = 0.5

    var body: some View {
        let s = state
        let price = Acquisitions.price(comp, s)
        let risk = Acquisitions.antitrustRisk(comp, s)
        let haul = Acquisitions.haul(comp, s)
        let blocker = Acquisitions.blocker(comp, s)
        let cashPart = price * (1 - stockShare)
        let dilution = price * stockShare / max(1, s.valuation + price * stockShare)
        VStack(alignment: .leading, spacing: 10) {
            Text("Acquire \(comp.def.name)").font(.title3.weight(.bold))
            SpecRow(label: "Their valuation", value: Fmt.money(comp.valuation))
            SpecRow(label: "Price (\(Int((Acquisitions.premium - 1) * 100))% control premium)", value: Fmt.money(price))
            HStack {
                Text("Pay in stock")
                Slider(value: $stockShare, in: 0...0.8, step: 0.05)
                Text(Fmt.pct(stockShare, decimals: 0)).font(.callout.monospacedDigit()).frame(width: 44)
            }
            SpecRow(label: "Cash", value: "\(Fmt.money(cashPart)) of \(Fmt.money(s.cash))")
            SpecRow(label: "New shares (dilution)", value: Fmt.pct(dilution, decimals: 1))
            SpecRow(label: "Antitrust block risk", value: Fmt.pct(risk, decimals: 0))
            Divider()
            Text("You'd inherit").font(.headline)
            Text("\(haul.techs.count) secret technique\(haul.techs.count == 1 ? "" : "s") · \(haul.researchers) researchers · \(Fmt.int(haul.chips))× \(haul.chipName) · \(Fmt.count(haul.users)) chat users · \(Fmt.count(haul.seats)) agent seats\(haul.model.map { " · their model \($0)" } ?? "")")
                .font(.callout).foregroundStyle(.secondary)
            if let blocker {
                Label(blocker, systemImage: "lock.fill").font(.caption).foregroundStyle(.orange)
            }
            Button {
                store.act("Deal announced") { $0.acquireRival(comp.id, stockShare: stockShare) }
                dismiss()
            } label: {
                Label("Make the offer", systemImage: "signature").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(blocker != nil || cashPart > s.cash)
            Text("If regulators block it you pay a 2% break fee and wait a year.").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 420)
    }
}
