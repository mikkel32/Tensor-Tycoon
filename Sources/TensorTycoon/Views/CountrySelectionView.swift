import SwiftUI

/// 3.5: choose where the company is headquartered — the new-game step. Self-contained: it reads and writes only
/// `NewGameSettings.hqCountry` / `hqCity` through its bindings.
struct CountrySelectionView: View {
    @Binding var country: String
    @Binding var city: String
    var eraID = "2022"

    @State private var comparing = false
    @State private var expanded: String? = nil

    private var year: Double { (Era.all.first { $0.id == eraID } ?? Era.all[0]).start.decimalYear }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Headquarters").font(.subheadline.weight(.semibold))
                Text("Where you incorporate and hire. Taxes, pay, rent, grants and home politics follow; capital, cloud and datacenters stay global, and you can open offices abroad later.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Picker("View", selection: $comparing) {
                    Label("Cards", systemImage: "square.grid.2x2").tag(false)
                    Label("Compare", systemImage: "tablecells").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }
            if comparing {
                CountryComparison(selected: country, selectedCity: city, year: year) { pick($0, $1) }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                    ForEach(CountryCatalog.all) { c in
                        CountryCard(country: c, selected: country == c.id, cityID: country == c.id ? city : c.cities[0].id, year: year,
                                    expanded: expanded == c.id,
                                    select: { pick(c.id, $0) },
                                    toggle: { withAnimation(.spring(duration: 0.35)) { expanded = expanded == c.id ? nil : c.id } })
                    }
                }
            }
        }
        .onAppear {
            // Keep the pair consistent if settings arrive with a city from another country.
            let c = CountryCatalog.get(country)
            if !c.cities.contains(where: { $0.id == city }) { city = c.cities[0].id }
        }
    }

    private func pick(_ countryID: String, _ cityID: String?) {
        let c = CountryCatalog.get(countryID)
        country = c.id
        city = cityID.flatMap { id in c.cities.first { $0.id == id }?.id } ?? (country == c.id && c.cities.contains { $0.id == city } ? city : c.cities[0].id)
    }
}

// MARK: - Fact or estimate

/// Whether a number on this screen is a real rule (a statutory rate or programme date) or a game estimate.
private enum Provenance {
    case fact(String)
    case estimate

    var label: String {
        switch self {
        case .fact(let year): "real \(year) rule"
        case .estimate: "game estimate"
        }
    }
}

private struct ProvenanceBadge: View {
    let kind: Provenance

    var body: some View {
        switch kind {
        case .fact: Pill(kind.label, tone: .info)
        case .estimate: Pill(text: kind.label, color: .secondary)
        }
    }
}

/// A spec row with its provenance badge.
private struct SourcedRow: View {
    let label: String
    let value: String
    let kind: Provenance

    var body: some View {
        HStack(spacing: 6) {
            SpecRow(label: label, value: value)
            ProvenanceBadge(kind: kind).frame(width: 96, alignment: .trailing)
        }
    }
}

// MARK: - Card

private struct CountryCard: View {
    let country: HQCountry
    let selected: Bool
    let cityID: String
    let year: Double
    let expanded: Bool
    let select: (String) -> Void
    let toggle: () -> Void

    private var city: HQCity { country.city(cityID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Photo(key: city.image)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom))
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 10) {
                        FlagView(id: country.id).frame(width: 42, height: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(country.name).font(.title2.weight(.bold)).foregroundStyle(.white)
                            Text(city.name).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor, in: .capsule)
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
                .contentShape(.rect)
                .onTapGesture { select(city.id) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Headquarters in \(city.name), \(country.name)")

            VStack(alignment: .leading, spacing: 10) {
                Text(country.tagline).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)

                // Cities
                HStack(spacing: 6) {
                    ForEach(country.cities) { c in
                        Button { select(c.id) } label: {
                            Text(c.name).font(.caption.weight(.semibold)).lineLimit(1)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(selected && c.id == cityID ? Color.accentColor.opacity(0.85) : Theme.insetFill, in: .capsule)
                                .foregroundStyle(selected && c.id == cityID ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // At a glance
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Glance(symbol: "percent", label: "Tax", value: CountryText.glanceTax(country))
                        Glance(symbol: "person.2.fill", label: "Lab pay", value: "×\(Fmt.trim(country.pay(city), 2))")
                    }
                    GridRow {
                        Glance(symbol: "building.2.fill", label: "Office", value: CountryText.office(country, city))
                        Glance(symbol: "bolt.fill", label: "Power", value: "$\(Fmt.trim(country.location?.powerPrice ?? country.power, 3))/kWh")
                    }
                }

                Text(city.blurb).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button(action: toggle) {
                        Label(expanded ? "Fewer details" : "Details", systemImage: expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    if !selected {
                        Button("Choose \(country.name)") { select(city.id) }.controlSize(.small)
                    }
                }

                if expanded { CountryDetails(country: country, city: city, year: year) }
            }
            .padding(12)
        }
        .background(.background.secondary.opacity(0.6))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.accentColor : Theme.hairline, lineWidth: selected ? 3 : 1))
    }
}

private struct Glance: View {
    let symbol: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption2).foregroundStyle(.secondary).frame(width: 14)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
        }
    }
}

// MARK: - Details

private struct CountryDetails: View {
    let country: HQCountry
    let city: HQCity
    let year: Double

    var body: some View {
        let one = country.yearOne(city, year: year)
        let loc = country.location
        let us = country.id == "us"
        let grants = country.expectedGrantsAtStart(year)
        let contracts = PowerKind.allCases.filter { k in k.locations?.contains(country.homeLocation) ?? false }
        VStack(alignment: .leading, spacing: 12) {
            Text(country.overview).font(.caption).fixedSize(horizontal: false, vertical: true)

            Section2(title: "Economy", symbol: "chart.line.uptrend.xyaxis") {
                SourcedRow(label: "Corporate tax", value: CountryText.tax(country), kind: .fact("2024"))
                if country.id == "ro" {
                    SourcedRow(label: "Minimum turnover tax", value: "1% of turnover above €50M a year, from 2024", kind: .fact("2024"))
                }
                if country.rdScheme == .none {
                    SourcedRow(label: "R&D relief", value: "Built into the baseline", kind: .estimate)
                } else {
                    SourcedRow(label: "R&D relief", value: rdRate, kind: .fact("2024"))
                    Text(country.rdScheme.explain).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                SourcedRow(label: "Employer on-costs vs US", value: CountryText.onCosts(country), kind: .fact("2024"))
                SourcedRow(label: "Seed round", value: CountryText.seed(country), kind: .estimate)
                SourcedRow(label: "Early-round pricing", value: CountryText.earlyRounds(country), kind: .estimate)
                SourcedRow(label: "Office rent vs SF", value: CountryText.office(country, city), kind: .estimate)
            }
            Section2(title: "Talent", symbol: "person.3.fill") {
                SourcedRow(label: "Frontier-lab pay vs San Francisco", value: CountryText.pay(country, city), kind: .estimate)
                SourcedRow(label: "Candidates at a time", value: CountryText.candidates(country, city), kind: .estimate)
                SourcedRow(label: "Poaching pressure", value: CountryText.poaching(country), kind: .estimate)
                SpecRow(label: "Local specialists", value: CountryText.specialists(country, city))
                SpecRow(label: "Cluster", value: city.cluster)
                Text("Pay is what a lab competing for global ML talent pays here (local market rates are lower). Outgrow the pool and you can open satellite offices in other cities, at their pay and rent.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Section2(title: "Infrastructure & electricity", symbol: "bolt.horizontal.fill") {
                if let loc {
                    SpecRow(label: "Home datacenter site", value: loc.name)
                    SourcedRow(label: "Grid power", value: CountryText.gridPower(loc), kind: .fact("2024 price"))
                    if !contracts.isEmpty {
                        SourcedRow(label: "Power contracts there", value: CountryText.contracts(contracts, country, year), kind: .estimate)
                    }
                    SourcedRow(label: "Grid queue at home", value: "\(Int(Power.queueBase(country.homeLocation))) months before era and congestion", kind: .estimate)
                    SourcedRow(label: "Build cost at home", value: CountryText.buildCost(country), kind: .estimate)
                    Text(loc.blurb).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Section2(title: "Government", symbol: "building.columns.fill") {
                SpecRow(label: "Rules", value: country.regionLabel)
                Text(us ? "US federal rules (compute reporting, licences, permitting) apply to you and to any datacenter on US soil. The EU AI Act applies to any model you sell in the EU."
                        : "The EU AI Act applies to any model sold in the EU, wherever it's trained. US federal rules reach you only for runs and datacenters on US soil.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if country.diffusionTier >= 2 {
                    SourcedRow(label: "US chip rule (Jan–May 2025)", value: "Tier \(country.diffusionTier): chip orders rationed while it stood", kind: .fact("2025"))
                }
                SourcedRow(label: "Standing at home", value: CountryText.standing(country), kind: .estimate)
                if country.usStanding != 0 { SourcedRow(label: "Standing in Washington", value: "\(Int(country.usStanding))", kind: .estimate) }
                if !us {
                    SourcedRow(label: "Grant and compute offers", value: CountryText.grants(grants, year), kind: .estimate)
                    SourcedRow(label: "National contract", value: CountryText.contract(country, year), kind: .estimate)
                }
                ForEach(country.programmes.indices, id: \.self) { i in
                    let p = country.programmes[i]
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Label("\(p.name.prefix(1).uppercased() + p.name.dropFirst())", systemImage: p.kind == .compute ? "cpu" : (p.kind == .contract ? "signature" : "eurosign.circle"))
                            .font(.caption)
                        Spacer(minLength: 4)
                        if !p.real.isEmpty {
                            Text(p.real).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        if year < p.from {
                            Pill("from \(Int(p.from))", tone: .neutral)
                        }
                    }
                }
                ForEach(Array(Set((country.affinities + city.affinities).map(\.product))).sorted(), id: \.self) { id in
                    Label("Partners give \(ProductLines.name(id)) a head start", systemImage: "gearshape.2.fill").font(.caption)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(country.pros, id: \.self) { p in
                        Label { Text(p) } icon: { Image(systemName: "plus.circle.fill").foregroundStyle(Theme.good) }.font(.caption)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(country.cons, id: \.self) { c in
                        Label { Text(c) } icon: { Image(systemName: "minus.circle.fill").foregroundStyle(Theme.warning) }.font(.caption)
                    }
                }
            }
            Section2(title: "Estimated startup costs (first year)", symbol: "banknote.fill") {
                SpecRow(label: "Payroll: founders + 6 hires, with on-costs", value: Fmt.money(one.payroll), estimated: true)
                SpecRow(label: "Startup office", value: Fmt.money(one.office), estimated: true)
                SpecRow(label: "Total", value: Fmt.money(one.payroll + one.office), estimated: true)
                if one.rdRelief > 0 {
                    SpecRow(label: "R&D relief paid while loss-making", value: "up to \(Fmt.money(one.rdRelief))", estimated: true)
                } else if country.rdScheme == .againstProfit {
                    SpecRow(label: "R&D relief", value: "none until you make a profit (carried forward)", estimated: true)
                }
            }
            Section2(title: "Suggested strategies", symbol: "lightbulb.fill") {
                ForEach(country.strategies, id: \.self) { Label($0, systemImage: "arrow.right.circle").font(.caption) }
            }
            Text("Sources: \(country.sources) Statutory rates are real 2024 rules; values marked \"game estimate\" are rounded simplifications.")
                .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            ImageCreditLabel(key: city.image)
        }
        .padding(10)
        .background(Theme.insetFill, in: .rect(cornerRadius: 10))
    }

    private var rdRate: String {
        var t = "\(Fmt.pct(country.rdCredit, decimals: 0)) of R&D spend"
        if country.rdCapYear > 0 { t += " up to \(Fmt.money(country.rdCapYear))/yr, \(Fmt.pct(country.rdAbove, decimals: 0)) above" }
        if country.rdCreditCapYear > 0 { t += ", at most \(Fmt.money(country.rdCreditCapYear))/yr" }
        if country.rdRefundCapYear > 0 { t += "; loss refund up to \(Fmt.money(country.rdRefundCapYear))/yr" }
        return t
    }
}

private struct Section2<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            content
        }
    }
}

// MARK: - Comparison

/// Every headquarters city side by side, one row each; your pick is highlighted and the best value in each column is
/// bold with a check.
private struct CountryComparison: View {
    let selected: String
    let selectedCity: String
    let year: Double
    let choose: (String, String) -> Void

    private struct Metric {
        let label: String
        let value: (HQCountry, HQCity) -> Double
        let text: (HQCountry, HQCity) -> String
        /// Lower is better.
        let lower: Bool
    }

    private var metrics: [Metric] {
        [
            Metric(label: "Tax", value: { c, _ in c.corporateTax }, text: { c, _ in Fmt.pct(c.corporateTax, decimals: 1) }, lower: true),
            Metric(label: "Lab pay", value: { c, city in c.pay(city) }, text: { c, city in "×\(Fmt.trim(c.pay(city), 2))" }, lower: true),
            Metric(label: "Cost per hire", value: { c, city in c.netPayrollFactor(city) }, text: { c, city in "×\(Fmt.trim(c.netPayrollFactor(city), 2))" }, lower: true),
            Metric(label: "Office", value: { c, city in c.id == "us" ? 1 : city.office }, text: { c, city in "×\(Fmt.trim(c.id == "us" ? 1 : city.office, 2))" }, lower: true),
            Metric(label: "Candidates", value: { c, city in Double(c.candidates(city)) }, text: { c, city in "\(c.candidates(city))" }, lower: false),
            Metric(label: "Poaching", value: { c, _ in c.brainDrain }, text: { c, _ in "×\(Fmt.trim(c.brainDrain, 2))" }, lower: true),
            Metric(label: "DC power", value: { c, _ in c.location?.powerPrice ?? c.power }, text: { c, _ in "$\(Fmt.trim(c.location?.powerPrice ?? c.power, 3))" }, lower: true),
            Metric(label: "Early rounds", value: { c, _ in c.investorDepth }, text: { c, _ in "×\(Fmt.trim(c.investorDepth, 2))" }, lower: false),
            Metric(label: "Grants/yr", value: { c, _ in c.expectedGrantsAtStart(year) }, text: { c, _ in c.expectedGrantsAtStart(year) == 0 ? "—" : "≈\(Fmt.trim(c.expectedGrantsAtStart(year), 1))" }, lower: false),
            Metric(label: "Year one", value: { c, city in let o = c.yearOne(city, year: year); return o.payroll + o.office },
                   text: { c, city in let o = c.yearOne(city, year: year); return Fmt.money(o.payroll + o.office) }, lower: true),
        ]
    }

    var body: some View {
        let rows: [(HQCountry, HQCity)] = CountryCatalog.all.flatMap { c in c.cities.map { (c, $0) } }
        let ms = metrics
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("City").font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 170, alignment: .leading)
                    ForEach(ms.indices, id: \.self) { i in
                        Text(ms[i].label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 78, alignment: .trailing)
                    }
                }
                Divider()
                ForEach(rows.indices, id: \.self) { r in
                    let c = rows[r].0
                    let city = rows[r].1
                    let picked = c.id == selected && city.id == selectedCity
                    GridRow {
                        Button { choose(c.id, city.id) } label: {
                            HStack(spacing: 6) {
                                FlagView(id: c.id).frame(width: 21, height: 14)
                                Text(city.name).font(.caption.weight(picked ? .bold : .regular)).lineLimit(1)
                                if picked { Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(Color.accentColor).accessibilityLabel("Selected") }
                            }
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .frame(width: 170, alignment: .leading)
                            .background(picked ? Color.accentColor.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        ForEach(ms.indices, id: \.self) { i in
                            let m = ms[i]
                            let values = rows.map { m.value($0.0, $0.1) }
                            let best = m.lower ? values.min() : values.max()
                            let isBest = m.value(c, city) == best
                            HStack(spacing: 2) {
                                if isBest { Image(systemName: Tone.good.symbol).font(.caption2).foregroundStyle(Theme.good).accessibilityLabel("Best") }
                                Text(m.text(c, city)).font(.caption.monospacedDigit().weight(isBest ? .bold : .regular))
                            }
                            .frame(width: 78, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(10)
        }
        .background(Theme.insetFill, in: .rect(cornerRadius: 12))
        Text("Every city, one row each; click a row to choose it. Best value in each column marked with a check. Pay, pools, office costs and grant odds are game estimates; taxes are real 2024 rates (US: federal only).")
            .font(.caption2).foregroundStyle(.tertiary)
    }
}

// MARK: - Text

/// The longer strings of this file, built outside view expressions (long interpolated strings with conditions can be
/// too slow for the compiler to type-check inside a view).
private enum CountryText {
    static func glanceTax(_ c: HQCountry) -> String {
        var t = Fmt.pct(c.corporateTax, decimals: 1)
        if c.id == "us" { t += " fed." }
        return t
    }

    static func tax(_ c: HQCountry) -> String {
        c.id == "us" ? "21% federal (state tax not modelled)" : Fmt.pct(c.corporateTax, decimals: 1)
    }

    static func office(_ c: HQCountry, _ city: HQCity) -> String {
        let f = c.id == "us" ? 1 : city.office
        return "×" + Fmt.trim(f, 2)
    }

    static func onCosts(_ c: HQCountry) -> String {
        guard c.employerCost != 0 else { return "Baseline" }
        let sign = c.employerCost > 0 ? "+" : "−"
        return sign + Fmt.pct(abs(c.employerCost), decimals: 0)
    }

    static func seed(_ c: HQCountry) -> String {
        guard c.investorDepth < 1 else { return "Baseline" }
        return "×" + Fmt.trim((1 + c.investorDepth) / 2, 2) + " of the era's usual cash"
    }

    static func earlyRounds(_ c: HQCountry) -> String {
        guard c.investorDepth < 1 else { return "Silicon Valley" }
        return "×" + Fmt.trim(c.investorDepth, 2) + " until ≈$5B, then global"
    }

    static func pay(_ c: HQCountry, _ city: HQCity) -> String {
        var t = "×" + Fmt.trim(c.pay(city), 2)
        t += " (stars and relocating hires ×" + Fmt.trim(c.relocationPay(city), 2) + ")"
        return t
    }

    static func candidates(_ c: HQCountry, _ city: HQCity) -> String {
        guard c.id != "us" else { return "8 (16 once you're big)" }
        return "\(c.candidates(city)) while unknown; up to 8 once you're well known, the rest relocating from abroad"
    }

    static func poaching(_ c: HQCountry) -> String {
        guard c.brainDrain != 1 else { return "Baseline" }
        var t = "×" + Fmt.trim(c.brainDrain, 2)
        if c.brainDrain < 1 { t += " (less than SF)" }
        return t
    }

    static func specialists(_ c: HQCountry, _ city: HQCity) -> String {
        let roles = Set(c.specialties + city.specialties).map(\.title).sorted()
        return roles.isEmpty ? "Everyone" : roles.joined(separator: ", ")
    }

    static func gridPower(_ loc: Location) -> String {
        let sign = loc.pueDelta <= 0 ? "−" : "+"
        return "$" + Fmt.trim(loc.powerPrice, 3) + "/kWh · PUE " + sign + Fmt.trim(abs(loc.pueDelta), 2)
    }

    static func contracts(_ kinds: [PowerKind], _ c: HQCountry, _ year: Double) -> String {
        kinds.map { k in
            let price = Int((k.priceMWh(year) * k.localPriceFactor(c.homeLocation)).rounded())
            return "\(k.rawValue) ≈$\(price)/MWh"
        }.joined(separator: ", ")
    }

    static func buildCost(_ c: HQCountry) -> String {
        guard c.buildCost != 1 else { return "Baseline" }
        return "×" + Fmt.trim(c.buildCost, 2) + ", taken off each phase you build (not campuses you buy)"
    }

    static func standing(_ c: HQCountry) -> String {
        guard c.homeStanding > 0 else { return "Baseline" }
        return "+\(Int(c.homeStanding)) with " + c.region.title
    }

    static func grants(_ perYear: Double, _ year: Double) -> String {
        guard perYear > 0 else { return "None until a programme opens" }
        return "≈" + Fmt.trim(perYear, 1) + " a year expected in \(Int(year)) (spaced at least three months apart)"
    }

    static func contract(_ c: HQCountry, _ year: Double) -> String {
        let monthly = 3e6 * HQ.scale(year) * pow(c.homeMarket / 0.03, 0.75)
        return "≈" + Fmt.money(monthly) + "/month at the start, sized to the home market (from mid-2023)"
    }

    static func summary(_ s: GameState, _ c: HQCountry, _ city: HQCity) -> String {
        let won = s.hq.grants + s.hq.computeGrants + s.hq.rdCredits + s.hq.rebates
        let years = max(0.25, Double(GameCalendar.daysBetween(s.startDate, s.date)) / 365)
        var t = city.name + " · tax " + Fmt.pct(c.corporateTax, decimals: 1) + " · pay ×" + Fmt.trim(c.pay(city), 2)
        if won > 0 { t += " · " + Fmt.money(won) + " from grants, R&D relief and build incentives" }
        t += " · \(s.hq.grantOffers) grant offers in " + Fmt.trim(years, 1) + " years"
        return t
    }

    static func summaryHelp(_ s: GameState, _ c: HQCountry) -> String {
        var t = "Headquarters: " + c.name + ". " + c.tagline + " R&D relief: " + c.rdScheme.explain
        if s.hq.rdCarry > 1 { t += " " + Fmt.money(s.hq.rdCarry) + " carried forward." }
        return t
    }

    static func satellite(_ s: GameState, _ o: SatelliteOffice, staff: Int) -> String {
        let c = CountryCatalog.get(o.country)
        let key = o.id.uuidString
        let rent = Double(o.seats) * HQ.seatRent(country: o.country, city: o.city)
        var t = "\(staff)/\(o.seats) desks · pay ×" + Fmt.trim(c.pay(c.city(o.city)), 2) + " · rent " + Fmt.money(rent) + "/mo"
        t += " · \(s.candidates.filter { $0.office == key }.count) candidates"
        if o.country != s.hqCountry { t += " · outside the home R&D relief" }
        return t
    }

    static func satelliteOffer(_ c: HQCountry, _ city: HQCity) -> String {
        let pool = c.id == "us" ? 1 : c.talentPool * city.talent
        let onCosts = c.employerCost == 0 ? "as in the US" : Fmt.signedPct(c.employerCost) + " vs the US"
        var t = city.name + ": pay ×" + Fmt.trim(c.pay(city), 2) + " of San Francisco, on-costs " + onCosts
        t += ", \(HQ.satelliteStartSeats) desks at " + Fmt.money(HQ.seatRent(country: c.id, city: city.id)) + "/desk-month"
        t += ", a talent pool ×" + Fmt.trim(pool, 2) + " of San Francisco's. " + city.cluster + "."
        return t
    }

    static func partnershipTitle(_ p: NationalPartnership) -> String {
        let c = CountryCatalog.get(p.country)
        let kind = p.kind == .computeCentre ? "Compute centre" : "University chair"
        return kind + ", " + c.city(p.city).name + ", " + c.name
    }

    static func partnershipLine(_ p: NationalPartnership, _ s: GameState) -> String {
        let c = CountryCatalog.get(p.country)
        var t = Fmt.money(p.cost) + " · "
        t += p.active(s.date) ? "until " + p.until.gameMonth : "ended " + p.until.gameMonth
        t += p.counted ? " · counted at a January review" : " · pushes " + c.name + "'s dials next January"
        return t
    }
}

// MARK: - Flags

/// Drawn national flags (simplified proportions), so they look the same everywhere.
struct FlagView: View {
    let id: String

    var body: some View {
        ZStack {
            switch id {
            case "ro": tricolour(Color(red: 0, green: 0.17, blue: 0.5), Color(red: 0.99, green: 0.82, blue: 0.09), Color(red: 0.81, green: 0.07, blue: 0.15))
            case "it": tricolour(Color(red: 0, green: 0.57, blue: 0.27), .white, Color(red: 0.81, green: 0.17, blue: 0.22))
            case "fr": tricolour(Color(red: 0, green: 0.14, blue: 0.58), .white, Color(red: 0.93, green: 0.16, blue: 0.22))
            case "dk": denmark
            default: usa
            }
        }
        .clipShape(.rect(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.hairline, lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    private func tricolour(_ a: Color, _ b: Color, _ c: Color) -> some View {
        HStack(spacing: 0) { a; b; c }
    }

    private var denmark: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, bar = h * 0.14
            ZStack(alignment: .topLeading) {
                Color(red: 0.78, green: 0.06, blue: 0.18)
                Rectangle().fill(.white).frame(width: w, height: bar).offset(y: (h - bar) / 2)
                Rectangle().fill(.white).frame(width: bar, height: h).offset(x: w * 0.36 - bar / 2)
            }
        }
    }

    private var usa: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        Color(red: 0.7, green: 0.13, blue: 0.2).frame(height: h / 13)
                        if i < 6 { Color.white.frame(height: h / 13) }
                    }
                }
                Color(red: 0.24, green: 0.23, blue: 0.43).frame(width: w * 0.4, height: h * 7 / 13)
            }
        }
    }
}

// MARK: - In game

/// One line on the Team page: where you're based and what home has given you.
struct HQSummaryLine: View {
    let state: GameState

    var body: some View {
        let c = HQ.country(state)
        let city = HQ.city(state)
        if !HQ.isDefault(state) {
            HStack(spacing: 6) {
                FlagView(id: c.id).frame(width: 18, height: 12)
                Text(CountryText.summary(state, c, city))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            .help(CountryText.summaryHelp(state, c))
        }
    }
}

/// 3.4 overhaul: satellite offices on the Team page — open one in another city (at home or abroad) to hire from its
/// pool at its pay and rent; add desks; close it.
struct SatelliteOfficesCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var pick = "fr|paris"

    var body: some View {
        let s = state
        let choices: [(HQCountry, HQCity)] = CountryCatalog.all.flatMap { c in c.cities.map { (c, $0) } }
            .filter { pair in !(pair.0.id == s.hqCountry && pair.1.id == s.hqCity) && !s.hq.satellites.contains { $0.country == pair.0.id && $0.city == pair.1.id } }
        let keys = choices.map { "\($0.0.id)|\($0.1.id)" }
        let selection = keys.contains(pick) ? pick : (keys.first ?? "")
        let chosen = choices.first { "\($0.0.id)|\($0.1.id)" == selection }
        Card {
            CardHeader("Offices", symbol: "building.2.crop.circle",
                       subtitle: "Headquarters in \(HQ.place(s)) with \(HQ.staffCount(s, office: "")) people. A satellite office hires from its own city's pool at local pay, that country's employer on-costs and local rent.")
            if s.hq.satellites.isEmpty {
                Text("No satellite offices yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(s.hq.satellites) { o in
                let key = o.id.uuidString
                let c = CountryCatalog.get(o.country)
                let staff = HQ.staffCount(s, office: key)
                HStack(spacing: 8) {
                    FlagView(id: c.id).frame(width: 21, height: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(c.city(o.city).name), \(c.name)").font(.callout.weight(.semibold))
                        Text(CountryText.satellite(s, o, staff: staff))
                            .font(.caption).foregroundStyle(.secondary)
                        Meter(value: Double(staff) / Double(max(1, o.seats)), tint: staff >= o.seats ? Theme.warning : Theme.good, height: 4)
                    }
                    Spacer()
                    Button("+\(HQ.satelliteStep) desks (\(Fmt.money(HQ.satelliteExpandCost(o))))") {
                        store.act("Office expanded") { $0.expandSatellite(o.id) }
                    }
                    .font(.caption)
                    .disabled(o.seats >= HQ.satelliteMaxSeats)
                    Button("Close…") { store.act("Office closed") { $0.closeSatellite(o.id) } }
                        .buttonStyle(.borderless).font(.caption)
                        .help(staff > 0 ? "Lets the \(staff) people there go with severance." : "Hands the desks back.")
                }
            }
            if let chosen {
                let c = chosen.0
                let city = chosen.1
                Divider()
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Picker("Open an office in", selection: Binding(get: { selection }, set: { pick = $0 })) {
                        ForEach(choices.indices, id: \.self) { i in
                            Text("\(choices[i].1.name), \(choices[i].0.name)").tag("\(choices[i].0.id)|\(choices[i].1.id)")
                        }
                    }
                    .frame(maxWidth: 320)
                    Spacer()
                    Button("Open (\(Fmt.money(HQ.satelliteOpenCost(s, country: c.id, city: city.id))))") {
                        store.act("Office opened") { $0.openSatellite(country: c.id, city: city.id) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text(CountryText.satelliteOffer(c, city))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// 3.4 overhaul: national partnerships on the Nations page — co-fund a compute centre or endow a chair in a country, see
/// what you fund and what each does.
struct NationalPartnershipsCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var kind: PartnershipKind = .computeCentre
    @State private var place = ""

    var body: some View {
        let s = state
        let cities: [(HQCountry, HQCity)] = CountryCatalog.all.flatMap { c in c.cities.map { (c, $0) } }
        let key = place.isEmpty ? "\(s.hqCountry)|\(s.hqCity)" : place
        let parts = key.split(separator: "|").map(String.init)
        let chosen = cities.first { $0.0.id == parts.first && $0.1.id == parts.last } ?? cities[0]
        let cost = Nations.partnershipCost(kind, s)
        Card {
            CardHeader("National partnerships", symbol: "hands.and.sparkles.fill",
                       subtitle: "Co-fund public compute or a university chair. It costs money, earns standing and pushes that country's dials at its next January review.")
            let mine = s.hq.partners.sorted { $0.signed > $1.signed }
            if mine.isEmpty { Text("None yet.").font(.callout).foregroundStyle(.secondary) }
            ForEach(mine) { p in
                let c = CountryCatalog.get(p.country)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: p.kind.symbol).foregroundStyle(.secondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(CountryText.partnershipTitle(p)).font(.callout)
                        Text(CountryText.partnershipLine(p, s))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Pill(p.active(s.date) ? "Active" : "Ended", tone: p.active(s.date) ? .good : .neutral)
                }
            }
            Divider()
            Picker("Kind", selection: $kind) {
                ForEach(PartnershipKind.allCases) { k in Text(k.title).tag(k) }
            }
            .pickerStyle(.segmented)
            Picker("Where", selection: Binding(get: { key }, set: { place = $0 })) {
                ForEach(cities.indices, id: \.self) { i in Text("\(cities[i].1.name), \(cities[i].0.name)").tag("\(cities[i].0.id)|\(cities[i].1.id)") }
            }
            .frame(maxWidth: 340)
            Text(kind.effect).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Costs \(Fmt.money(cost)) now.").font(.caption.weight(.semibold))
                Spacer()
                Button("Sign in \(chosen.1.name)") {
                    store.act("Partnership signed") { $0.signNationalPartnership(kind, country: chosen.0.id, city: chosen.1.id) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(cost > s.cash)
            }
        }
    }
}
