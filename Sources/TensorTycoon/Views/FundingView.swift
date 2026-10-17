import Charts
import SwiftUI

struct FundingView: View {
    @Environment(GameStore.self) private var store
    @State private var fraction = 0.15
    @State private var secondary = 0.05
    @State private var founderSale = 0.05
    @State private var confirmSale = false

    var body: some View {
        let s = store.game
        let total = s.totalShares
        var slices: [(String, Double)] = [("You (\(s.founderName))", s.founderShares), ("Employee pool", s.employeePoolShares)]
        var investors: [String: Double] = [:]
        for h in s.holdings { investors[h.name, default: 0] += h.shares }
        slices += investors.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        if s.publicShares > 0 { slices.append(("Public float", s.publicShares)) }
        let (ipoOK, ipoWhy) = Economy.ipoEligible(s)

        return Page(title: "Funding & Equity", subtitle: "Sell slices of the company to fund compute. Every round dilutes you — the trick is raising at ever-higher valuations.") {
            HStack(alignment: .top, spacing: 16) {
                Card {
                    CardHeader("Cap table", symbol: "chart.pie.fill", subtitle: "\(Fmt.count(total)) shares outstanding")
                    HStack(spacing: 16) {
                        Chart(slices, id: \.0) { sl in
                            SectorMark(angle: .value("Shares", sl.1), innerRadius: .ratio(0.55), angularInset: 1)
                                .foregroundStyle(by: .value("Holder", sl.0))
                        }
                        .chartLegend(.hidden)
                        .frame(width: 190, height: 190)
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(slices.prefix(10), id: \.0) { sl in
                                HStack {
                                    Text(sl.0).lineLimit(1)
                                    Spacer()
                                    Text(Fmt.pct(sl.1 / total)).monospacedDigit()
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
                VStack(spacing: 12) {
                    StatTile(title: "Valuation", value: Fmt.money(s.valuation), detail: s.isPublic ? "Market cap" : "Private mark", symbol: "building.columns.fill", tint: .purple)
                    StatTile(title: "Your stake", value: Fmt.money(s.valuation * s.founderStake), detail: Fmt.pct(s.founderStake), symbol: "person.crop.circle.fill", tint: .green)
                    StatTile(title: "Your net worth", value: Fmt.money(s.founderNetWorth), detail: s.founderCash > 0 ? "\(Fmt.money(s.founderCash)) cashed out" : "All on paper", symbol: "dollarsign.circle.fill", tint: .yellow)
                }
                .frame(width: 260)
            }

            if s.isPublic {
                Card {
                    CardHeader("Stock", symbol: "chart.line.uptrend.xyaxis", subtitle: "\(Fmt.price(s.sharePrice)) per share")
                    Chart(s.stock, id: \.date) { p in
                        LineMark(x: .value("Date", p.date), y: .value("Price", p.price))
                            .foregroundStyle(Theme.accentGradient)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 220)
                    HStack {
                        Text("Secondary offering")
                        Slider(value: $secondary, in: 0.01...0.15)
                        Text("\(Fmt.pct(secondary, decimals: 0)) new shares ≈ \(Fmt.money(s.totalShares * secondary * s.sharePrice * 0.95))").font(.callout.monospacedDigit())
                        Button("Issue") { store.act("Shares issued") { $0.secondaryOffering(fraction: secondary) } }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    Card {
                        CardHeader("Raise a round", symbol: "banknote", subtitle: "Investors price you on revenue, model quality, brand and hype")
                        if s.raising {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Pitching investors for \(Fmt.pct(s.raiseFraction, decimals: 0))… term sheets arrive over the coming weeks.")
                                    .font(.callout)
                            }
                            ForEach(s.raiseOffers) { o in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(o.investor) — \(o.roundName)").font(.callout.weight(.semibold))
                                        Text("\(Fmt.money(o.amount)) at \(Fmt.money(o.preMoney)) pre · \(Fmt.pct(o.amount / (o.preMoney + o.amount))) dilution\(o.cloudCredits > 0 ? " · \(Fmt.money(o.cloudCredits)) as cloud credits" : "") · expires \(o.expires.gameShort)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Accept") { store.act("Round closed!") { $0.acceptOffer(o.id) } }
                                        .buttonStyle(.borderedProminent)
                                }
                            }
                            Button("Stop raising") { store.mutate { $0.cancelRaise() } }.buttonStyle(.link)
                        } else {
                            HStack {
                                Text("Sell")
                                Slider(value: $fraction, in: 0.05...0.3, step: 0.01)
                                Text(Fmt.pct(fraction, decimals: 0)).font(.headline.monospacedDigit()).frame(width: 50)
                            }
                            let pre = Finance.privateValue(s)
                            Text("At today's ~\(Fmt.money(pre)) valuation that's roughly \(Fmt.money(min(pre * fraction / (1 - fraction), Finance.maxRaise(s.year)))).")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Start fundraising") { store.act("Fundraise started") { $0.startRaise(fraction: fraction) } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    Card {
                        CardHeader("IPO", symbol: "bell.fill")
                        Text(ipoWhy).font(.callout).foregroundStyle(ipoOK ? .primary : .secondary)
                        Button("Ring the bell") { store.act("You're public!") { $0.ipo() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(!ipoOK)
                    }
                    .frame(width: 320)
                }
            }

            Card {
                CardHeader("Founder liquidity", symbol: "person.crop.circle.badge.checkmark",
                           subtitle: "Sell part of your own stake. The money is yours, not the company's — it counts toward your net worth.")
                let blocker = Treasury.founderSaleBlocker(s)
                let price = Treasury.founderSalePrice(s)
                let gross = s.founderShares * founderSale * price
                HStack {
                    Text("Sell")
                    Slider(value: $founderSale, in: 0.01...0.25, step: 0.01)
                    Text("\(Fmt.pct(founderSale, decimals: 0)) of your shares").font(.callout.monospacedDigit()).frame(width: 150)
                    Text("≈ \(Fmt.money(gross * (1 - Treasury.capitalGainsTax))) after tax").font(.callout.monospacedDigit()).foregroundStyle(.green)
                    Button("Sell shares…") { confirmSale = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(blocker != nil)
                        .confirmationDialog("Sell \(Fmt.pct(founderSale, decimals: 0)) of your shares?", isPresented: $confirmSale, titleVisibility: .visible) {
                            Button("Sell for \(Fmt.money(gross * (1 - Treasury.capitalGainsTax))) after tax") {
                                store.act("Shares sold") { $0.sellFounderShares(fraction: founderSale) }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Your stake falls from \(Fmt.pct(s.founderStake, decimals: 1)) to about \(Fmt.pct(s.founderStake * (1 - founderSale), decimals: 1)). Below 50% you no longer control the board.")
                        }
                }
                Text(blocker ?? "\(s.isPublic ? "Sold into the market at" : "Secondary buyers pay") \(Fmt.price(price))/share\(s.isPublic ? " (the stock dips a little)" : " — a 15% discount to the last mark")). One sale every six months; over 10% at once spooks the press.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Card {
                CardHeader("Funding history", symbol: "clock.arrow.circlepath")
                ForEach(s.rounds.reversed()) { r in
                    HStack {
                        Text(r.name).font(.callout.weight(.semibold)).frame(width: 120, alignment: .leading)
                        Text(r.date.gameShort).font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
                        Text(Fmt.money(r.amount)).monospacedDigit().frame(width: 90, alignment: .leading)
                        Text("@ \(Fmt.money(r.preMoney + r.amount)) post").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(r.lead).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
