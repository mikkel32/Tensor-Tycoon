import Charts
import SwiftUI

struct HardwareStoreView: View {
    @Environment(GameStore.self) private var store
    @State private var vendor: Vendor? = nil
    @State private var cls: AccelClass? = nil
    @State private var availability = 0
    @State private var sort = "perf"
    @State private var search = ""
    @State private var selected: Accelerator? = nil
    @State private var showDeals = false

    var body: some View {
        let s = store.game
        let d = store.derived
        let catalog = HardwareCatalog.everything
        let items = filtered(s, catalog)
        let forSale = catalog.filter { Economy.canBuy($0, s) }.count
        let rentable = catalog.filter { Economy.canRent($0, s) }.count
        Page(title: "Hardware Store", subtitle: "Real accelerators with real specs. Dense TFLOPS shown (vendor headline numbers are often sparse). Buy for your sites or rent by the chip-hour.") {
            HeroBanner(image: "gb200_rack", height: 150) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compute is the new oil").font(.title.weight(.bold))
                        Text("\(forSale) chips for sale · \(rentable) rentable · lead time ~\(Int(s.market.leadTimeDays)) days · prices \(s.market.hardwarePrice >= 1 ? "+" : "")\(Int((s.market.hardwarePrice - 1) * 100))% vs list")
                            .font(.callout).opacity(0.9)
                    }
                    Spacer()
                    Button {
                        showDeals.toggle()
                    } label: {
                        Label(s.supplyDeals.isEmpty ? "Supply agreements" : "\(s.supplyDeals.count) supply agreement\(s.supplyDeals.count == 1 ? "" : "s")", systemImage: "signature")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.black.opacity(0.65), in: .capsule)
                            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            if showDeals { SupplyDealsCard(state: s) }

            HStack(spacing: 10) {
                TextField("Search", text: $search).textFieldStyle(.roundedBorder).frame(width: 180)
                Picker("Vendor", selection: $vendor) {
                    Text("All vendors").tag(Vendor?.none)
                    ForEach(Vendor.allCases.filter { $0 != .custom || !s.customChips.isEmpty }) { v in Text(v.rawValue).tag(Vendor?.some(v)) }
                }
                .frame(width: 170)
                Picker("Type", selection: $cls) {
                    Text("All types").tag(AccelClass?.none)
                    ForEach(AccelClass.allCases) { c in Text(c.rawValue).tag(AccelClass?.some(c)) }
                }
                .frame(width: 170)
                Picker("Show", selection: $availability) {
                    Text("Available now").tag(0)
                    Text("Including announced").tag(1)
                    Text("Everything (history)").tag(2)
                }
                .frame(width: 200)
                Spacer()
                Picker("Sort", selection: $sort) {
                    Text("Most powerful").tag("perf")
                    Text("Best perf / $ (buy)").tag("perfDollar")
                    Text("Best perf / $ (rent)").tag("perfRent")
                    Text("Most memory").tag("memory")
                    Text("Newest").tag("newest")
                }
                .frame(width: 200)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                ForEach(items) { a in
                    Button { selected = a } label: {
                        AcceleratorCard(accel: a,
                                        buy: Economy.canBuy(a, s) ? Economy.price(a, s) : nil,
                                        rent: Economy.canRent(a, s) ? Economy.rent(a, s) : nil,
                                        owned: d.poolByID[a.id]?.total ?? 0,
                                        comingLabel: Economy.availableFor(a, s) > s.date.ym ? Economy.availableFor(a, s).label : nil,
                                        deal: Economy.hasDeal(a, s),
                                        early: Economy.isEarlyAccess(a, s),
                                        blocked: Partners.blocker(a, s) != nil,
                                        partnerDiscount: Partners.discount(a, s))
                            .equatable()
                    }
                    .buttonStyle(.plain)
                }
            }
            if items.isEmpty {
                EmptyStateView(symbol: "magnifyingglass", title: "Nothing matches", message: "Try a different filter.")
            }
        }
        .sheet(item: $selected) { a in
            AcceleratorDetail(accel: a)
        }
        .onAppear {
            if let id = store.focusAccelID, let a = HardwareCatalog.get(id) {
                selected = a
                store.focusAccelID = nil
            }
        }
    }

    private func filtered(_ s: GameState, _ catalog: [Accelerator]) -> [Accelerator] {
        var list = catalog.filter { a in
            switch availability {
            case 0: return Economy.canBuy(a, s) || Economy.canRent(a, s)
            case 1: return Economy.isAnnounced(a, s) && (a.discontinued.map { $0 > s.date.ym } ?? true || Economy.canRent(a, s))
            default: return Economy.isAnnounced(a, s)
            }
        }
        if let vendor { list = list.filter { $0.vendor == vendor } }
        if let cls { list = list.filter { $0.cls == cls } }
        if !search.isEmpty { list = list.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.architecture.localizedCaseInsensitiveContains(search) } }
        switch sort {
        case "perfDollar": list.sort { perfPerDollar($0, s) > perfPerDollar($1, s) }
        case "perfRent": list.sort { perfPerRent($0, s) > perfPerRent($1, s) }
        case "memory": list.sort { $0.memoryGB > $1.memoryGB }
        case "newest": list.sort { $0.available > $1.available }
        default: list.sort { $0.best > $1.best }
        }
        return list
    }

    private func perfPerDollar(_ a: Accelerator, _ s: GameState) -> Double {
        guard let p = Economy.price(a, s), Economy.canBuy(a, s) else { return 0 }
        return a.best / p
    }

    private func perfPerRent(_ a: Accelerator, _ s: GameState) -> Double {
        guard let r = Economy.rent(a, s), Economy.canRent(a, s) else { return 0 }
        return a.best / r
    }
}

struct AcceleratorCard: View, Equatable {
    let accel: Accelerator
    let buy: Double?
    let rent: Double?
    let owned: Int
    let comingLabel: String?
    let deal: Bool
    var early = false
    var blocked = false
    var partnerDiscount = 0.0

    var body: some View {
        let a = accel
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Photo(key: a.image)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom))
                HStack {
                    VendorBadge(vendor: a.vendor, onPhoto: true)
                    Spacer()
                    if blocked {
                        PhotoPill(text: "Exclusivity", color: .red, symbol: "lock.fill")
                    } else if early {
                        PhotoPill(text: "Early access", color: .purple, symbol: "bolt.badge.clock.fill")
                    } else if let comingLabel {
                        PhotoPill(text: "Coming \(comingLabel)", color: .orange, symbol: "clock.fill")
                    } else if owned > 0 {
                        PhotoPill(text: "You have \(Fmt.int(owned))", color: .green, symbol: "checkmark.circle.fill")
                    }
                }
                .padding(10)
                if a.minOrder > 1 || deal || partnerDiscount > 0 {
                    HStack(spacing: 6) {
                        if a.minOrder > 1 { PhotoPill(text: "Racks of \(a.minOrder)", color: .cyan, symbol: "square.stack.3d.up.fill") }
                        if deal { PhotoPill(text: "Supply deal", color: .green, symbol: "signature") }
                        if partnerDiscount > 0 { PhotoPill(text: "Partner −\(Int((partnerDiscount * 100).rounded()))%", color: .green, symbol: "tag.fill") }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .frame(height: 150)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.name).font(.headline).lineLimit(1)
                    Text(verbatim: "\(a.architecture) · \(a.cls.rawValue) · \(a.available.year)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 12) {
                    SpecChip(value: Fmt.memory(a.memoryGB), label: a.memoryType)
                    SpecChip(value: "\(Fmt.trim(a.bandwidthTBs, a.bandwidthTBs < 10 ? 2 : 0)) TB/s", label: "bandwidth")
                    SpecChip(value: Fmt.tflops(a.best), label: a.bestPrecisionLabel)
                    SpecChip(value: Fmt.watts(a.tdpW), label: "TDP")
                }
                Divider()
                HStack {
                    if let buy {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(Fmt.money(buy)).font(.callout.weight(.semibold).monospacedDigit())
                            Text(a.vendor == .custom ? "at cost" : "to buy").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let rent {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(Fmt.price(rent))/hr").font(.callout.weight(.semibold).monospacedDigit())
                            Text("to rent").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if buy == nil && rent == nil {
                        Text(comingLabel != nil ? "Not yet available" : "No longer sold").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .background(.background.secondary, in: .rect(cornerRadius: Theme.corner))
        .clipShape(.rect(cornerRadius: Theme.corner))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(a.vendor == .custom ? Color.indigo.opacity(0.8) : Color.secondary.opacity(0.25), lineWidth: a.vendor == .custom ? 1.5 : 0.5))
        .contentShape(.rect(cornerRadius: Theme.corner))
    }
}

private struct SpecChip: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.caption.weight(.semibold).monospacedDigit()).lineLimit(1)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

struct AcceleratorDetail: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let accel: Accelerator
    @State private var qty = 8
    @State private var siteID: UUID? = nil
    @State private var term: RentalTerm = .onDemand

    var body: some View {
        if let s = store.state { content(s) }
    }

    @ViewBuilder
    private func content(_ s: GameState) -> some View {
        let a = accel
        let buy = Economy.canBuy(a, s) ? Economy.price(a, s) : nil
        let rent = Economy.canRent(a, s) ? Economy.rent(a, s) : nil
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Photo(key: a.image)
                    .frame(height: 230)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 6) {
                    VendorBadge(vendor: a.vendor, onPhoto: true)
                    Text(a.name).font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                    Text(a.fact).font(.callout).foregroundStyle(.white.opacity(0.9))
                }
                .padding(20)
            }
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.hierarchical) }
                    .buttonStyle(.plain).foregroundStyle(.white).padding(14)
                    .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ImageCreditLabel(key: a.image, representative: a.representativeImage)
                    if let why = Partners.blocker(a, s) {
                        Label(why, systemImage: "lock.fill").font(.callout).foregroundStyle(.red)
                    } else if Economy.isEarlyAccess(a, s) {
                        Label("Early access through your partnership — everyone else waits until \(a.available.label).", systemImage: "bolt.badge.clock.fill")
                            .font(.callout).foregroundStyle(.purple)
                    }
                    if Partners.discount(a, s) > 0, let p = Partners.covering(a, s) {
                        Label("\(p.def.name) partner pricing: \(Int((p.discount * 100).rounded()))% off, \(Fmt.trim(p.allocationMult, 1))× allocation, +\(Int(p.mfuBonus * 100)) pts MFU from co-engineering.",
                              systemImage: "signature")
                            .font(.callout).foregroundStyle(.green)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        specs(a).frame(maxWidth: .infinity)
                        VStack(spacing: 14) {
                            comparison(a)
                            if buy != nil || rent != nil { purchase(a, s, buy: buy, rent: rent) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 900, height: 720)
        .onAppear {
            siteID = s.sites.first { $0.isReady(s.date) && a.tdpW <= $0.maxChipTDP && (!a.liquid || $0.cooling.supportsLiquidChips) }?.id
            qty = a.minOrder > 1 ? a.minOrder : (a.cls == .consumer || a.cls == .workstation ? 4 : 8)
        }
    }

    private func specs(_ a: Accelerator) -> some View {
        Card {
            CardHeader("Specifications", symbol: "list.bullet.rectangle")
            Group {
                SpecRow(label: "Architecture", value: a.architecture)
                SpecRow(label: "Process", value: a.process, estimated: a.isEstimated("process"))
                SpecRow(label: "Announced / available", value: "\(a.announced.label) / \(a.available.label)")
                if let t = a.transistorsB { SpecRow(label: "Transistors", value: "\(Fmt.trim(t, 1))B") }
                SpecRow(label: "Memory", value: "\(Fmt.memory(a.memoryGB)) \(a.memoryType)", estimated: a.isEstimated("mem"))
                SpecRow(label: "Memory bandwidth", value: "\(Fmt.trim(a.bandwidthTBs, 2)) TB/s", estimated: a.isEstimated("bw"))
            }
            Divider()
            Group {
                SpecRow(label: "BF16 / FP16 dense", value: Fmt.tflops(a.bf16), estimated: a.isEstimated("bf16"))
                SpecRow(label: "FP8 dense", value: a.fp8 > 0 ? Fmt.tflops(a.fp8) : "—", estimated: a.isEstimated("fp8"))
                SpecRow(label: "FP4 dense", value: a.fp4 > 0 ? Fmt.tflops(a.fp4) : "—", estimated: a.isEstimated("fp4"))
                SpecRow(label: "INT8 dense", value: a.int8 > 0 ? "\(Fmt.trim(a.int8, 0)) TOPS" : "—")
                SpecRow(label: "TDP", value: Fmt.watts(a.tdpW), estimated: a.isEstimated("tdp"))
                SpecRow(label: "Cooling", value: a.liquid ? "Liquid required" : "Air OK")
            }
            Divider()
            Group {
                SpecRow(label: "Interconnect", value: "\(a.interconnect) · \(Fmt.trim(a.interconnectGBs, 0)) GB/s", estimated: a.isEstimated("ic"))
                SpecRow(label: "Scale-up domain", value: "\(Fmt.int(a.scaleUp)) chips")
                SpecRow(label: "Launch price", value: a.price.map { Fmt.money($0) } ?? "Not sold", estimated: a.isEstimated("price"))
                SpecRow(label: "Launch rental", value: a.rent.map { "\(Fmt.price($0))/chip-hr on \(a.cloudProvider)" } ?? "—", estimated: a.isEstimated("rent"))
            }
        }
    }

    private func comparison(_ a: Accelerator) -> some View {
        let h = HardwareCatalog.h100
        let rows: [(String, Double)] = [
            ("BF16", a.bf16 / h.bf16),
            ("Best low-precision", a.best / h.best),
            ("Memory", a.memoryGB / h.memoryGB),
            ("Bandwidth", a.bandwidthTBs / h.bandwidthTBs),
            ("Power", a.tdpW / h.tdpW),
        ]
        return Card {
            CardHeader("vs. H100 SXM", symbol: "chart.bar.xaxis", subtitle: "1.0 = one H100")
            VStack(spacing: 8) {
                ForEach(rows, id: \.0) { r in
                    LogBarRow(label: r.0, ratio: r.1)
                }
            }
        }
    }

    @ViewBuilder
    private func purchase(_ a: Accelerator, _ s: GameState, buy: Double?, rent: Double?) -> some View {
        Card {
            CardHeader("Acquire", symbol: "cart")
            HStack {
                Text("Quantity")
                Spacer()
                QuantityPicker(value: $qty, range: 1...max(1, max(Economy.allocationLimit(a, s), Economy.rentalLimit(a, s))),
                               presets: a.minOrder > 1 ? [a.minOrder, a.minOrder * 4, a.minOrder * 16, a.minOrder * 64] : [1, 8, 64, 512, 4096])
            }
            if a.minOrder > 1 && buy != nil && qty % a.minOrder != 0 {
                Label("Purchases ship in full racks of \(a.minOrder) (rentals can be any size).", systemImage: "square.stack.3d.up").font(.caption).foregroundStyle(.orange)
            }
            if let buy {
                let sites = s.sites.filter { $0.isReady(s.date) || $0.kind == .datacenter || $0.kind == .colo }
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Install at", selection: $siteID) {
                        Text("Choose a site…").tag(UUID?.none)
                        ForEach(sites) { site in
                            let free = site.capacityKW - Economy.siteLoadKW(s, site.id)
                            Text("\(site.name) — \(Fmt.watts(max(0, free) * 1000)) free\(site.isReady(s.date) ? "" : " (under construction)")").tag(UUID?.some(site.id))
                        }
                    }
                    let total = buy * Double(qty)
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(Fmt.money(total)) total").font(.headline.monospacedDigit())
                            Text("\(Fmt.watts(Economy.chipKW(a) * Double(qty) * 1000)) incl. servers · ships in ~\(Economy.leadTimeDays(a, s)) days · max \(Fmt.int(Economy.allocationLimit(a, s))) per order")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Buy") {
                            guard let siteID else { store.show("Pick a site first", error: true); return }
                            if store.act("Order placed", { $0.buyHardware(a.id, count: qty, siteID: siteID) }) { dismiss() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(siteID == nil)
                    }
                    if a.liquid { Label("Needs a liquid-cooled colocation cage or datacenter.", systemImage: "drop.fill").font(.caption).foregroundStyle(.blue) }
                }
            }
            if let rent {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Term", selection: $term) {
                        ForEach(RentalTerm.allCases) { t in Text("\(t.rawValue) (\(Fmt.price(rent * t.discount))/hr)").tag(t) }
                    }
                    let monthly = rent * term.discount * 24 * 30.4 * Double(qty)
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(Fmt.money(monthly))/month").font(.headline.monospacedDigit())
                            Text("On \(a.cloudProvider). Instant, no power or cooling needed. Limit \(Fmt.int(Economy.rentalLimit(a, s))) for your size.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Rent") {
                            if store.act("Capacity rented", { $0.rentHardware(a.id, count: qty, term: term) }) { dismiss() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                    }
                }
            }
        }
    }
}
