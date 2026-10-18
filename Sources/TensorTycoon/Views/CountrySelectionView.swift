import SwiftUI

/// 3.5: choose where the company is headquartered — the new-game step. Self-contained: it reads and writes only
/// `NewGameSettings.hqCountry` / `hqCity` through its bindings.
struct CountrySelectionView: View {
    @Binding var country: String
    @Binding var city: String
    var eraID = "2022"
    var difficulty: Difficulty = .normal

    @State private var comparing = false
    @State private var expanded: String? = nil

    private var year: Double { (Era.all.first { $0.id == eraID } ?? Era.all[0]).start.decimalYear }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Headquarters").font(.subheadline.weight(.semibold))
                Text("Where you incorporate and hire. Taxes, pay, rent, grants and home politics follow; capital, cloud and datacenters stay global.")
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
                CountryComparison(selected: country, year: year) { pick($0, nil) }
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
                                .background(selected && c.id == cityID ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08), in: .capsule)
                                .foregroundStyle(selected && c.id == cityID ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // At a glance
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Glance(symbol: "percent", label: "Tax", value: Fmt.pct(country.corporateTax, decimals: 1))
                        Glance(symbol: "person.2.fill", label: "ML pay", value: "×\(Fmt.trim(country.pay(city), 2))")
                    }
                    GridRow {
                        Glance(symbol: "building.2.fill", label: "Office", value: "×\(Fmt.trim(country.id == "us" ? 1 : city.office, 2))")
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
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.accentColor : .white.opacity(0.1), lineWidth: selected ? 3 : 1))
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
        VStack(alignment: .leading, spacing: 12) {
            Text(country.overview).font(.caption).fixedSize(horizontal: false, vertical: true)

            Section2(title: "Economy", symbol: "chart.line.uptrend.xyaxis") {
                SpecRow(label: "Corporate tax", value: Fmt.pct(country.corporateTax, decimals: 1))
                SpecRow(label: "R&D tax credit", value: country.rdCredit > 0 ? "\(Fmt.pct(country.rdCredit, decimals: 0)) of R&D payroll\(country.rdRefundable ? ", refundable" : "")" : "Built into the baseline")
                SpecRow(label: "Employer on-costs vs US", value: country.employerCost == 0 ? "Baseline" : "\(country.employerCost > 0 ? "+" : "−")\(Fmt.pct(abs(country.employerCost), decimals: 0))")
                SpecRow(label: "Seed round", value: country.investorDepth >= 1 ? "Baseline" : "×\(Fmt.trim((1 + country.investorDepth) / 2, 2)) of the era's usual cash")
                SpecRow(label: "Early-round pricing", value: country.investorDepth >= 1 ? "Silicon Valley" : "×\(Fmt.trim(country.investorDepth, 2)) until ≈$5B, then global")
                SpecRow(label: "Office rent vs SF", value: "×\(Fmt.trim(country.id == "us" ? 1 : city.office, 2))")
            }
            Section2(title: "Talent", symbol: "person.3.fill") {
                SpecRow(label: "ML pay vs San Francisco", value: "×\(Fmt.trim(country.pay(city), 2)) (stars ×\(Fmt.trim(country.id == "us" ? 1 : (1 + country.pay(city)) / 2, 2)))")
                SpecRow(label: "Candidates at a time", value: "\(country.candidates(city)) (SF: 8)")
                SpecRow(label: "Poaching pressure", value: country.brainDrain == 1 ? "Baseline" : "×\(Fmt.trim(country.brainDrain, 2))")
                SpecRow(label: "Local specialists", value: Set(country.specialties + city.specialties).map(\.title).sorted().joined(separator: ", ").isEmpty ? "Everyone" : Set(country.specialties + city.specialties).map(\.title).sorted().joined(separator: ", "))
                SpecRow(label: "Cluster", value: city.cluster)
            }
            Section2(title: "Infrastructure & electricity", symbol: "bolt.horizontal.fill") {
                if let loc {
                    SpecRow(label: "Home datacenter site", value: loc.name)
                    SpecRow(label: "Power", value: "$\(Fmt.trim(loc.powerPrice, 3))/kWh · PUE \(loc.pueDelta <= 0 ? "−" : "+")\(Fmt.trim(abs(loc.pueDelta), 2))")
                    SpecRow(label: "Build cost at home", value: country.buildCost == 1 ? "Baseline" : "×\(Fmt.trim(country.buildCost, 2)) (incentive refunded monthly)")
                    Text(loc.blurb).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Section2(title: "Government", symbol: "building.columns.fill") {
                SpecRow(label: "Rules", value: country.regionLabel)
                SpecRow(label: "Standing at home", value: country.homeStanding > 0 ? "+\(Int(country.homeStanding)) with \(country.region.title)" : "Baseline")
                if country.usStanding != 0 { SpecRow(label: "Standing in Washington", value: "\(Int(country.usStanding))") }
                ForEach(country.programmes.indices, id: \.self) { i in
                    let p = country.programmes[i]
                    Label("\(p.name.prefix(1).uppercased() + p.name.dropFirst())", systemImage: p.kind == .compute ? "cpu" : (p.kind == .contract ? "signature" : "eurosign.circle"))
                        .font(.caption)
                }
                ForEach(Array(Set((country.affinities + city.affinities).map(\.product))).sorted(), id: \.self) { id in
                    Label("Partners give \(ProductLines.name(id)) a head start", systemImage: "gearshape.2.fill").font(.caption).foregroundStyle(.purple)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(country.pros, id: \.self) { Label($0, systemImage: "plus.circle.fill").font(.caption).foregroundStyle(.green) }
                }
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(country.cons, id: \.self) { Label($0, systemImage: "minus.circle.fill").font(.caption).foregroundStyle(.orange) }
                }
            }
            Section2(title: "Estimated startup costs (first year)", symbol: "banknote.fill") {
                SpecRow(label: "Payroll: founders + 6 hires", value: Fmt.money(one.payroll), estimated: true)
                SpecRow(label: "Startup office", value: Fmt.money(one.office), estimated: true)
                SpecRow(label: "Total", value: Fmt.money(one.payroll + one.office), estimated: true)
            }
            Section2(title: "Suggested strategies", symbol: "lightbulb.fill") {
                ForEach(country.strategies, id: \.self) { Label($0, systemImage: "arrow.right.circle").font(.caption) }
            }
            Text("Sources: \(country.sources) Values are rounded, game-simplified approximations.")
                .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            ImageCreditLabel(key: city.image)
        }
        .padding(10)
        .background(Color.white.opacity(0.04), in: .rect(cornerRadius: 10))
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

private struct CountryComparison: View {
    let selected: String
    let year: Double
    let choose: (String) -> Void

    private struct Metric {
        let label: String
        let value: (HQCountry, HQCity) -> Double
        let text: (HQCountry, HQCity) -> String
        /// Lower is better.
        let lower: Bool
    }

    private var metrics: [Metric] {
        [
            Metric(label: "Corporate tax", value: { c, _ in c.corporateTax }, text: { c, _ in Fmt.pct(c.corporateTax, decimals: 1) }, lower: true),
            Metric(label: "R&D tax credit", value: { c, _ in c.rdCredit }, text: { c, _ in c.rdCredit > 0 ? Fmt.pct(c.rdCredit, decimals: 0) : "—" }, lower: false),
            Metric(label: "ML pay vs SF", value: { c, city in c.pay(city) }, text: { c, city in "×\(Fmt.trim(c.pay(city), 2))" }, lower: true),
            Metric(label: "Net cost per research hire", value: { c, city in c.netPayrollFactor(city) }, text: { c, city in "×\(Fmt.trim(c.netPayrollFactor(city), 2))" }, lower: true),
            Metric(label: "Office rent vs SF", value: { c, city in c.id == "us" ? 1 : city.office }, text: { c, city in "×\(Fmt.trim(c.id == "us" ? 1 : city.office, 2))" }, lower: true),
            Metric(label: "Candidates at a time", value: { c, city in Double(c.candidates(city)) }, text: { c, city in "\(c.candidates(city))" }, lower: false),
            Metric(label: "Poaching pressure", value: { c, _ in c.brainDrain }, text: { c, _ in "×\(Fmt.trim(c.brainDrain, 2))" }, lower: true),
            Metric(label: "Datacenter power", value: { c, _ in c.location?.powerPrice ?? c.power }, text: { c, _ in "$\(Fmt.trim(c.location?.powerPrice ?? c.power, 3))" }, lower: true),
            Metric(label: "Cooling (PUE)", value: { c, _ in c.location?.pueDelta ?? 0 }, text: { c, _ in Fmt.trim(c.location?.pueDelta ?? 0, 2) }, lower: true),
            Metric(label: "Early-round pricing", value: { c, _ in c.investorDepth }, text: { c, _ in "×\(Fmt.trim(c.investorDepth, 2))" }, lower: false),
            Metric(label: "Grants & public compute", value: { c, _ in c.grantRate }, text: { c, _ in c.grantRate == 0 ? "—" : "≈\(Fmt.trim(c.grantRate * 12, 1))/yr" }, lower: false),
            Metric(label: "Standing at home", value: { c, _ in c.homeStanding }, text: { c, _ in c.homeStanding > 0 ? "+\(Int(c.homeStanding))" : "—" }, lower: false),
            Metric(label: "Year-one burn (8 people)", value: { c, city in let o = c.yearOne(city, year: year); return o.payroll + o.office },
                   text: { c, city in let o = c.yearOne(city, year: year); return Fmt.money(o.payroll + o.office) }, lower: true),
        ]
    }

    var body: some View {
        let cols = CountryCatalog.all
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("").frame(width: 170, alignment: .leading)
                    ForEach(cols) { c in
                        Button { choose(c.id) } label: {
                            VStack(spacing: 4) {
                                FlagView(id: c.id).frame(width: 36, height: 24)
                                Text(c.name).font(.caption.weight(.bold)).lineLimit(1)
                            }
                            .frame(width: 104)
                            .padding(.vertical, 4)
                            .background(c.id == selected ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider()
                ForEach(metrics.indices, id: \.self) { i in
                    let metric = metrics[i]
                    let values = cols.map { metric.value($0, $0.cities[0]) }
                    let best = metric.lower ? values.min() : values.max()
                    GridRow {
                        Text(metric.label).font(.caption).foregroundStyle(.secondary).frame(width: 170, alignment: .leading)
                        ForEach(cols.indices, id: \.self) { k in
                            Text(metric.text(cols[k], cols[k].cities[0]))
                                .font(.caption.monospacedDigit().weight(values[k] == best ? .bold : .regular))
                                .foregroundStyle(values[k] == best ? Color.green : Color.primary)
                                .frame(width: 104)
                        }
                    }
                }
            }
            .padding(10)
        }
        .background(Color.white.opacity(0.04), in: .rect(cornerRadius: 12))
        Text("Each country's first city shown; city choices change pay, rent and the talent pool. Best value in green.")
            .font(.caption2).foregroundStyle(.tertiary)
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
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
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
            let won = state.hq.grants + state.hq.computeGrants + state.hq.rdCredits + state.hq.rebates
            HStack(spacing: 6) {
                FlagView(id: c.id).frame(width: 18, height: 12)
                Text("\(city.name) · tax \(Fmt.pct(c.corporateTax, decimals: 1)) · pay ×\(Fmt.trim(c.pay(city), 2))\(won > 0 ? " · \(Fmt.money(won)) from grants, credits and incentives" : "")")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            .help("Headquarters: \(c.name). \(c.tagline)")
        }
    }
}
