import SwiftUI

enum Theme {
    static let logoColors: [Color] = [.indigo, .blue, .teal, .green, .orange, .pink, .purple, .red, .mint, .cyan]
    static let accentGradient = LinearGradient(colors: [Color(red: 0.42, green: 0.36, blue: 1.0), Color(red: 0.0, green: 0.78, blue: 0.95)],
                                               startPoint: .leading, endPoint: .trailing)
    static let positive = Color.green
    static let negative = Color.red
    static let corner: CGFloat = 16

    static func logoColor(_ i: Int) -> Color { logoColors[abs(i) % logoColors.count] }

    static func competitorColor(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    static func vendorColor(_ v: Vendor) -> Color {
        switch v {
        case .nvidia: Color(red: 0.46, green: 0.73, blue: 0.0)
        case .google: Color(red: 0.26, green: 0.52, blue: 0.96)
        case .amd: Color(red: 0.93, green: 0.11, blue: 0.14)
        case .intel: Color(red: 0.0, green: 0.44, blue: 0.77)
        case .aws: Color(red: 1.0, green: 0.6, blue: 0.0)
        case .microsoft: Color(red: 0.0, green: 0.64, blue: 0.94)
        case .apple: .gray
        case .cerebras: Color(red: 0.95, green: 0.36, blue: 0.1)
        case .groq: Color(red: 0.96, green: 0.31, blue: 0.21)
        case .tesla: Color(red: 0.8, green: 0.0, blue: 0.0)
        case .huawei: Color(red: 0.8, green: 0.05, blue: 0.1)
        case .qualcomm: Color(red: 0.2, green: 0.38, blue: 0.89)
        case .tenstorrent: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .custom: .purple
        }
    }

    static func categoryColor(_ c: NewsCategory) -> Color {
        switch c {
        case .company: .indigo
        case .hardware: .green
        case .competitor: .orange
        case .market: .teal
        case .finance: .yellow
        case .policy: .purple
        case .research: .pink
        }
    }

    static func roleColor(_ r: Role) -> Color {
        switch r {
        case .researcher: .purple
        case .mlEngineer: .blue
        case .infra: .teal
        case .data: .orange
        case .sales: .green
        case .safety: .pink
        case .chipDesigner: .indigo
        }
    }
}

// MARK: - Containers

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: Theme.corner))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

struct CardHeader<Trailing: View>: View {
    let title: String
    var symbol: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            trailing
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(_ title: String, symbol: String? = nil, subtitle: String? = nil) {
        self.title = title
        self.symbol = symbol
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }
}

/// Standard scrolling page with a title.
struct Page<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.largeTitle.weight(.bold))
                    if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
                }
                content
            }
            .padding(24)
            .frame(maxWidth: 1500, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollContentBackground(.hidden)
        .background(PageBackground())
    }
}

struct PageBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: [Color.indigo.opacity(0.10), .clear], startPoint: .top, endPoint: .center)
                .frame(height: 420)
        }
        .ignoresSafeArea()
    }
}

/// Wide photo banner with a gradient and overlay text.
struct HeroBanner<Overlay: View>: View {
    let image: String
    var height: CGFloat = 190
    @ViewBuilder var overlay: Overlay

    var body: some View {
        Photo(key: image, thumb: false)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.2), .clear], startPoint: .bottomLeading, endPoint: .topTrailing)
            }
            .overlay {
                // A bottom scrim keeps stats on the trailing side readable over bright photos too.
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                overlay
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                    .padding(20)
            }
            .clipShape(.rect(cornerRadius: Theme.corner + 4))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner + 4).strokeBorder(.white.opacity(0.08)))
    }
}

// MARK: - Small pieces

struct StatTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    var symbol: String
    var tint: Color = .accentColor
    var trend: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(tint.gradient, in: .rect(cornerRadius: 6))
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let trend {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(trend >= 0 ? Theme.positive : Theme.negative)
                }
            }
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

struct Pill: View {
    let text: String
    var color: Color = .secondary
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(color.opacity(0.14), in: .capsule)
    }
}

struct Meter: View {
    let value: Double
    var tint: Color = .accentColor
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(tint.gradient)
                    .frame(width: max(height, geo.size.width * clamp(value, 0, 1)))
                    .opacity(value > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.smooth, value: value)
    }
}

struct SpecRow: View {
    let label: String
    let value: String
    var estimated = false

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
            if estimated {
                Text("est.").font(.caption2).foregroundStyle(.orange)
            }
        }
        .font(.callout)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
}

struct CompanyLogo: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: size * 0.28)
            )
            .shadow(color: color.opacity(0.35), radius: size * 0.15, y: size * 0.05)
    }
}

struct VendorBadge: View {
    let vendor: Vendor
    var onPhoto = false
    var body: some View {
        if onPhoto {
            PhotoPill(text: vendor.rawValue, color: Theme.vendorColor(vendor), symbol: vendor.symbol)
        } else {
            Pill(text: vendor.rawValue, color: Theme.vendorColor(vendor), symbol: vendor.symbol)
        }
    }
}

/// High-contrast pill for labels drawn on top of photos (white text on a dark capsule, tinted icon).
struct PhotoPill: View {
    let text: String
    var color: Color = .white
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).foregroundStyle(color) }
            Text(text).foregroundStyle(.white)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.62), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }
}

struct ImageCreditLabel: View {
    let key: String
    var representative = false
    var body: some View {
        if let c = ImageLibrary.credit(key) {
            Text("\(representative ? "Representative photo · " : "")Photo: \(c.author) · \(c.license) · Wikimedia Commons")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

struct ToastView: View {
    let toast: Toast
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(toast.isError ? .orange : .green)
            Text(toast.message).font(.callout).lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 520)
        .glassEffect(.regular, in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

/// A number field with +/- buttons for quick quantity selection.
struct QuantityPicker: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var presets: [Int] = [1, 8, 64, 512, 4096, 32_768, 262_144, 1_048_576]

    var body: some View {
        HStack(spacing: 6) {
            Button { value = max(range.lowerBound, value / 2) } label: { Image(systemName: "minus") }
                .buttonStyle(.bordered)
                .help("Halve").accessibilityLabel("Halve the quantity")
            TextField("Qty", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .multilineTextAlignment(.center)
                .onChange(of: value) { _, new in value = clamp(new, range.lowerBound, max(range.lowerBound, range.upperBound)) }
            Button { value = min(range.upperBound, max(1, value * 2)) } label: { Image(systemName: "plus") }
                .buttonStyle(.bordered)
                .help("Double").accessibilityLabel("Double the quantity")
            Menu("Presets") {
                ForEach(presets.filter { $0 <= range.upperBound }, id: \.self) { p in
                    Button(Fmt.int(p)) { value = p }
                }
                Button("Max (\(Fmt.int(range.upperBound)))") { value = range.upperBound }
            }
            .menuStyle(.button)
            .fixedSize()
        }
    }
}

extension View {
    func cardStyle() -> some View {
        self.padding(16)
            .background(.background.secondary, in: .rect(cornerRadius: Theme.corner))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

func signedMoney(_ v: Double) -> String { (v >= 0 ? "+" : "") + Fmt.money(v) }

/// Horizontal bar for a ratio vs a reference (1.0), drawn on a log scale from 1/10x to 100x.
struct LogBarRow: View {
    let label: String
    let ratio: Double

    var body: some View {
        HStack(spacing: 10) {
            Text(label).font(.caption).frame(width: 120, alignment: .leading)
            GeometryReader { geo in
                let pos = { (v: Double) in clamp((log10(max(v, 0.001)) + 1) / 3, 0, 1) * geo.size.width }
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(ratio >= 1 ? Color.green.gradient : Color.orange.gradient)
                        .frame(width: max(6, pos(ratio)))
                    Rectangle().fill(.secondary).frame(width: 1.5, height: 16).offset(x: pos(1))
                }
            }
            .frame(height: 12)
            Text("\(Fmt.trim(ratio, ratio < 10 ? 2 : 0))×").font(.caption.monospacedDigit()).frame(width: 52, alignment: .trailing)
        }
    }
}

extension BenchKind {
    var color: Color {
        switch self {
        case .knowledge: .blue
        case .reasoning: .purple
        case .math: .orange
        case .code: .teal
        case .agentic: .indigo
        case .multimodal: .pink
        case .longContext: .cyan
        case .science: .green
        case .instruction: .mint
        case .multilingual: .brown
        case .safety: .green
        case .dangerous: .red
        case .speech: .yellow
        }
    }
}
