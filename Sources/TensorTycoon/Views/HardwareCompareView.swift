import SwiftUI

// MARK: - Honest photo labels

extension Accelerator {
    /// The chip doesn't ship as real hardware (a roadmap projection, a fictional part, your own or alien silicon), so
    /// its photo is an illustration, never a picture of the thing itself.
    var photoIsIllustrative: Bool {
        if vendor == .custom { return true }
        guard representativeImage else { return false }
        return name.localizedCaseInsensitiveContains("roadmap") || fact.localizedCaseInsensitiveContains("roadmap")
            || fact.localizedCaseInsensitiveContains("fictional")
    }

    /// A pill for the photo: "Illustrative" for chips that don't exist yet, "Similar hardware" for real chips shown with
    /// a stand-in photo, nothing for a photo of the chip itself.
    var photoLabel: (text: String, help: String)? {
        if photoIsIllustrative {
            return ("Illustrative", "Not a photo of this chip: it's a roadmap projection or your own design, so the picture is a stand-in.")
        }
        if representativeImage {
            return ("Similar hardware", "A photo of closely related hardware; no freely licensed photo of this exact chip was available.")
        }
        return nil
    }
}

/// The photo pill for an accelerator's picture (nothing when the photo shows the chip itself).
struct AcceleratorPhotoLabel: View {
    let accel: Accelerator

    var body: some View {
        if let l = accel.photoLabel {
            PhotoPill(text: l.text, symbol: accel.photoIsIllustrative ? "paintbrush.pointed.fill" : "photo")
                .help(l.help)
                .accessibilityLabel("\(l.text) photo")
        }
    }
}

// MARK: - Side-by-side comparison

/// Two to four accelerators side by side: every spec the catalogue has, with the best in each row marked by a star and
/// colour, and the game's own estimates marked *est.* exactly as the detail sheet does.
struct HardwareCompareView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// The store's picks: changes here show on the store's cards too.
    @Binding var ids: [String]

    static let maxChips = 4

    var body: some View {
        if let s = store.state { content(s) }
    }

    private func content(_ s: GameState) -> some View {
        let chips = ids.compactMap { HardwareCatalog.get($0) }
        let rows = CompareRow.all(s)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compare accelerators").font(.title2.weight(.bold))
                    Text("Dense numbers from the catalogue; vendor headline figures are often sparse. Pick two to four chips.")
                        .font(TypeRamp.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.hierarchical) }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close")
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    Grid(alignment: .leading, horizontalSpacing: Theme.Space.m, verticalSpacing: Theme.Space.s) {
                        GridRow(alignment: .top) {
                            Text("").frame(width: 170, alignment: .leading)
                            ForEach(chips) { a in header(a, s) }
                            if chips.count < Self.maxChips { addSlot(s) }
                        }
                        ForEach(rows) { row in
                            Divider().gridCellColumns(chips.count + 1 + (chips.count < Self.maxChips ? 1 : 0))
                            GridRow(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.label).font(TypeRamp.caption.weight(.semibold))
                                    if let note = row.note { Text(note).font(TypeRamp.micro).foregroundStyle(.tertiary) }
                                }
                                .frame(width: 170, alignment: .leading)
                                let values = chips.map { row.value($0) }
                                let best = row.bestIndices(values)
                                ForEach(Array(chips.enumerated()), id: \.element.id) { i, a in
                                    cell(row, a, value: values[i], best: best.contains(i))
                                }
                                if chips.count < Self.maxChips { Text("") }
                            }
                        }
                    }
                    if chips.count < 2 {
                        Label("Add at least two chips to compare.", systemImage: "info.circle")
                            .font(TypeRamp.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: Theme.Space.l) {
                        Label("Best in the row", systemImage: "star.fill").foregroundStyle(Theme.good)
                        HStack(spacing: 4) {
                            Text("est.").foregroundStyle(Theme.warning)
                            Text("the game's estimate: the vendor hasn't published it")
                        }
                        Text("Prices today include market conditions, your deals and partner discounts.")
                    }
                    .font(TypeRamp.micro)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
        .frame(width: 1000, height: 720)
    }

    // MARK: Columns

    private func header(_ a: Accelerator, _ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Photo(key: a.image)
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(.rect(cornerRadius: Theme.Radius.inset))
                .overlay(alignment: .bottomLeading) { AcceleratorPhotoLabel(accel: a).padding(5) }
                .accessibilityHidden(true)
            VendorBadge(vendor: a.vendor)
            Text(a.name).font(TypeRamp.cardTitle).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(a.architecture).font(TypeRamp.micro).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 6) {
                chipMenu(s, title: "Change", replacing: a.id)
                Button { ids.removeAll { $0 == a.id } } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                    .help("Remove from the comparison")
                    .accessibilityLabel("Remove \(a.name)")
            }
            .controlSize(.small)
        }
        .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
    }

    private func addSlot(_ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: Theme.Radius.inset)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(height: 96)
                .overlay(Image(systemName: "plus").font(.title2).foregroundStyle(.secondary))
                .accessibilityHidden(true)
            chipMenu(s, title: "Add a chip", replacing: nil)
        }
        .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
    }

    /// Every announced chip, one submenu per vendor.
    private func chipMenu(_ s: GameState, title: String, replacing: String?) -> some View {
        let catalog = HardwareCatalog.everything.filter { Economy.isAnnounced($0, s) && !ids.contains($0.id) }
        let vendors = Vendor.allCases.filter { v in catalog.contains { $0.vendor == v } }
        return Menu(title) {
            ForEach(vendors) { v in
                Menu(v.rawValue) {
                    ForEach(catalog.filter { $0.vendor == v }.sorted { $0.available > $1.available }) { a in
                        Button("\(a.name) (\(a.available.year))") {
                            if let r = replacing, let i = ids.firstIndex(of: r) { ids[i] = a.id } else if ids.count < Self.maxChips { ids.append(a.id) }
                        }
                    }
                }
            }
        }
        .fixedSize()
    }

    private func cell(_ row: CompareRow, _ a: Accelerator, value: Double?, best: Bool) -> some View {
        let text = row.text(a, value)
        let est = (value != nil || !row.isNumeric) && row.estimated(a)
        return HStack(spacing: 4) {
            if best {
                Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.good).accessibilityHidden(true)
            }
            Text(text)
                .font(TypeRamp.tableNumber.weight(best ? .semibold : .regular))
                .foregroundStyle(best ? Theme.good : (value == nil && row.isNumeric ? Color.secondary : Color.primary))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if est {
                Text("est.").font(.caption2).foregroundStyle(Theme.warning)
            }
        }
        .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.label), \(a.name): \(text)\(est ? ", estimated" : "")\(best ? ", best" : "")")
    }
}

// MARK: - Rows

/// One spec row: how to read the number, how to show it, which way is better, and when it's the game's estimate.
struct CompareRow: Identifiable {
    enum Better { case higher, lower, none }

    let label: String
    var note: String? = nil
    let better: Better
    let value: (Accelerator) -> Double?
    let text: (Accelerator, Double?) -> String
    let estimated: (Accelerator) -> Bool
    var isNumeric = true

    var id: String { label }

    /// Best values (ties included), only when at least two chips have a number and they differ.
    func bestIndices(_ values: [Double?]) -> Set<Int> {
        guard better != .none else { return [] }
        let present = values.enumerated().compactMap { i, v in v.map { (i, $0) } }
        guard present.count >= 2 else { return [] }
        let target = better == .higher ? present.map(\.1).max()! : present.map(\.1).min()!
        guard present.contains(where: { abs($0.1 - target) > abs(target) * 1e-9 }) else { return [] }
        return Set(present.filter { abs($0.1 - target) <= abs(target) * 1e-9 }.map(\.0))
    }

    static func all(_ s: GameState) -> [CompareRow] {
        func dash(_ f: @escaping (Double) -> String) -> (Accelerator, Double?) -> String { { _, v in v.map(f) ?? "—" } }
        func est(_ keys: String...) -> (Accelerator) -> Bool { { a in keys.contains { a.isEstimated($0) } } }
        return [
            CompareRow(label: "BF16 / FP16 dense", better: .higher, value: { $0.bf16 > 0 ? $0.bf16 : nil },
                       text: dash(Fmt.tflops), estimated: est("bf16")),
            CompareRow(label: "FP8 dense", better: .higher, value: { $0.fp8 > 0 ? $0.fp8 : nil },
                       text: dash(Fmt.tflops), estimated: est("fp8")),
            CompareRow(label: "FP4 dense", better: .higher, value: { $0.fp4 > 0 ? $0.fp4 : nil },
                       text: dash(Fmt.tflops), estimated: est("fp4")),
            CompareRow(label: "INT8 dense", better: .higher, value: { $0.int8 > 0 ? $0.int8 : nil },
                       text: dash { "\(Fmt.trim($0, 0)) TOPS" }, estimated: est("int8")),
            CompareRow(label: "Memory", better: .higher, value: { $0.memoryGB },
                       text: { a, v in v.map { "\(Fmt.memory($0)) \(a.memoryType)" } ?? "—" }, estimated: est("mem")),
            CompareRow(label: "Memory bandwidth", better: .higher, value: { $0.bandwidthTBs },
                       text: dash { "\(Fmt.trim($0, 2)) TB/s" }, estimated: est("bw")),
            CompareRow(label: "TDP", note: "lower is better", better: .lower, value: { $0.tdpW },
                       text: dash { Fmt.watts($0) }, estimated: est("tdp")),
            CompareRow(label: "Interconnect", better: .higher, value: { $0.interconnectGBs > 0 ? $0.interconnectGBs : nil },
                       text: { a, v in v.map { "\(Fmt.trim($0, 0)) GB/s · \(a.interconnect)" } ?? a.interconnect }, estimated: est("ic")),
            CompareRow(label: "Scale-up domain", better: .higher, value: { Double($0.scaleUp) },
                       text: dash { "\(Fmt.int(Int($0))) chips" }, estimated: { _ in false }),
            CompareRow(label: "Launch price", note: "lower is better", better: .lower, value: { $0.price },
                       text: dash { Fmt.money($0) }, estimated: est("price")),
            CompareRow(label: "Price today", note: "if you can buy it now", better: .lower,
                       value: { a in Economy.canBuy(a, s) ? Economy.price(a, s) : nil },
                       text: dash { Fmt.money($0) }, estimated: est("price")),
            CompareRow(label: "Rent today", note: "per chip-hour, if rentable now", better: .lower,
                       value: { a in Economy.canRent(a, s) ? Economy.rent(a, s) : nil },
                       text: dash { "\(Fmt.price($0))/hr" }, estimated: est("rent")),
            CompareRow(label: "$ per BF16 TFLOP", note: "launch price · lower is better", better: .lower,
                       value: { a in a.price.flatMap { p in a.bf16 > 0 ? p / a.bf16 : nil } },
                       text: dash { Fmt.money($0) }, estimated: est("price", "bf16")),
            CompareRow(label: "Perf per watt", note: "BF16 TFLOPS per kW", better: .higher,
                       value: { a in a.bf16 > 0 && a.tdpW > 0 ? a.bf16 / a.tdpW * 1000 : nil },
                       text: dash { Fmt.trim($0, $0 < 100 ? 1 : 0) }, estimated: est("bf16", "tdp")),
            CompareRow(label: "Available", better: .none, value: { $0.available.decimal },
                       text: { a, _ in a.available.label }, estimated: { _ in false }),
            CompareRow(label: "Process", better: .none, value: { _ in nil },
                       text: { a, _ in a.process }, estimated: est("process"), isNumeric: false),
            CompareRow(label: "Cooling", better: .none, value: { _ in nil },
                       text: { a, _ in a.liquid ? "Liquid required" : "Air OK" }, estimated: { _ in false }, isNumeric: false),
        ]
    }
}
