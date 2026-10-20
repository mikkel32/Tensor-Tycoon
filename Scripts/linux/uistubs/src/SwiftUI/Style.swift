// SwiftUI stub — Color, ShapeStyle family, gradients, materials, and basic geometry value types.

// MARK: - ShapeStyle

public protocol ShapeStyle: Sendable {
    associatedtype Resolved: ShapeStyle = Never
    func resolve(in environment: EnvironmentValues) -> Self.Resolved
}

extension ShapeStyle where Self.Resolved == Never {
    public func resolve(in environment: EnvironmentValues) -> Never { fatalError() }
}

extension Never: ShapeStyle {
    public typealias Resolved = Never
}

/// Internal concrete result for `some ShapeStyle` members.
public struct _AnyShapeStyleStub: ShapeStyle {}

extension ShapeStyle {
    public func opacity(_ opacity: Double) -> some ShapeStyle { _AnyShapeStyleStub() }
    public func blendMode(_ mode: BlendMode) -> some ShapeStyle { _AnyShapeStyleStub() }
    public func shadow(_ style: ShadowStyle) -> some ShapeStyle { _AnyShapeStyleStub() }
    public func `in`(_ rect: CGRect) -> some ShapeStyle { _AnyShapeStyleStub() }
    public var secondary: some ShapeStyle { _AnyShapeStyleStub() }
    public var tertiary: some ShapeStyle { _AnyShapeStyleStub() }
    public var quaternary: some ShapeStyle { _AnyShapeStyleStub() }
    public var quinary: some ShapeStyle { _AnyShapeStyleStub() }
}

extension ShapeStyle where Self == AnyShapeStyle {
    public static func opacity(_ opacity: Double) -> some ShapeStyle { _AnyShapeStyleStub() }
    public static func blendMode(_ mode: BlendMode) -> some ShapeStyle { _AnyShapeStyleStub() }
    public static func shadow(_ style: ShadowStyle) -> some ShapeStyle { _AnyShapeStyleStub() }
}

@frozen public struct AnyShapeStyle: ShapeStyle {
    public init<S>(_ style: S) where S: ShapeStyle {}
}

@frozen public struct HierarchicalShapeStyle: ShapeStyle {
    public static let primary = HierarchicalShapeStyle()
    public static let secondary = HierarchicalShapeStyle()
    public static let tertiary = HierarchicalShapeStyle()
    public static let quaternary = HierarchicalShapeStyle()
    public static let quinary = HierarchicalShapeStyle()
}

extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var primary: HierarchicalShapeStyle { .primary }
    public static var secondary: HierarchicalShapeStyle { .secondary }
    public static var tertiary: HierarchicalShapeStyle { .tertiary }
    public static var quaternary: HierarchicalShapeStyle { .quaternary }
    public static var quinary: HierarchicalShapeStyle { .quinary }
}

@frozen public struct ForegroundStyle: ShapeStyle { public init() {} }
@frozen public struct BackgroundStyle: ShapeStyle { public init() {} }
public struct SeparatorShapeStyle: ShapeStyle { public init() {} }
public struct TintShapeStyle: ShapeStyle { public init() {} }
@frozen public struct FillShapeStyle: ShapeStyle { public init() {} }
@frozen public struct PlaceholderTextShapeStyle: ShapeStyle { public init() {} }
@frozen public struct LinkShapeStyle: ShapeStyle { public init() {} }
public struct SelectionShapeStyle: ShapeStyle { public init() {} }
public struct WindowBackgroundShapeStyle: ShapeStyle { public init() {} }

extension ShapeStyle where Self == ForegroundStyle { public static var foreground: ForegroundStyle { .init() } }
extension ShapeStyle where Self == BackgroundStyle { public static var background: BackgroundStyle { .init() } }
extension ShapeStyle where Self == SeparatorShapeStyle { public static var separator: SeparatorShapeStyle { .init() } }
extension ShapeStyle where Self == TintShapeStyle { public static var tint: TintShapeStyle { .init() } }
extension ShapeStyle where Self == FillShapeStyle { public static var fill: FillShapeStyle { .init() } }
extension ShapeStyle where Self == PlaceholderTextShapeStyle { public static var placeholder: PlaceholderTextShapeStyle { .init() } }
extension ShapeStyle where Self == LinkShapeStyle { public static var link: LinkShapeStyle { .init() } }
extension ShapeStyle where Self == SelectionShapeStyle { public static var selection: SelectionShapeStyle { .init() } }
extension ShapeStyle where Self == WindowBackgroundShapeStyle { public static var windowBackground: WindowBackgroundShapeStyle { .init() } }

public struct Material: Sendable {
    internal init() {}
    public static let regular = Material()
    public static let thick = Material()
    public static let thin = Material()
    public static let ultraThin = Material()
    public static let ultraThick = Material()
    public static let bar = Material()
}
extension Material: ShapeStyle {}
extension ShapeStyle where Self == Material {
    public static var regularMaterial: Material { .regular }
    public static var thickMaterial: Material { .thick }
    public static var thinMaterial: Material { .thin }
    public static var ultraThinMaterial: Material { .ultraThin }
    public static var ultraThickMaterial: Material { .ultraThick }
    public static var bar: Material { .bar }
}

public struct ShadowStyle: Equatable, Sendable {
    public static func drop(color: Color = .init(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> ShadowStyle { .init() }
    public static func inner(color: Color = .init(.sRGBLinear, white: 0, opacity: 0.55), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> ShadowStyle { .init() }
}

public enum BlendMode: Sendable, Equatable, Hashable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight
    case difference, exclusion, hue, saturation, color, luminosity, sourceAtop, destinationOver, destinationOut
    case plusDarker, plusLighter
}

// MARK: - Color

@frozen public struct Color: Hashable, CustomStringConvertible, Sendable {
    internal init() {}
    public var description: String { "Color" }

    public enum RGBColorSpace: Sendable, Hashable { case sRGB, sRGBLinear, displayP3 }

    public init(_ colorSpace: Color.RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) {}
    public init(_ colorSpace: Color.RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) {}
    public init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) {}
    public init(_ name: String, bundle: Bundle? = nil) {}
    public init(_ cgColor: CGColor) {}
    public init(cgColor: CGColor) {}
    /// macOS only.
    public init(nsColor: NSColor) {}
    @available(macOS, deprecated, renamed: "init(nsColor:)")
    public init(_ color: NSColor) {}
    public init<T>(_ color: T) where T: Hashable, T: ShapeStyle, T.Resolved == Color.Resolved {}
    public init(_ resolved: Color.Resolved) {}

    public static let red = Color()
    public static let orange = Color()
    public static let yellow = Color()
    public static let green = Color()
    public static let mint = Color()
    public static let teal = Color()
    public static let cyan = Color()
    public static let blue = Color()
    public static let indigo = Color()
    public static let purple = Color()
    public static let pink = Color()
    public static let brown = Color()
    public static let white = Color()
    public static let gray = Color()
    public static let black = Color()
    public static let clear = Color()
    public static let primary = Color()
    public static let secondary = Color()
    public static var accentColor: Color { Color() }

    public func opacity(_ opacity: Double) -> Color { self }
    public func mix(with rhs: Color, by fraction: Double, in colorSpace: Gradient.ColorSpace = .perceptual) -> Color { self }
    public var gradient: AnyGradient { AnyGradient(Gradient(colors: [self])) }
    public func resolve(in environment: EnvironmentValues) -> Color.Resolved { Color.Resolved(red: 0, green: 0, blue: 0) }

    public struct Resolved: Hashable, ShapeStyle, CustomStringConvertible, Sendable {
        public var linearRed: Float
        public var linearGreen: Float
        public var linearBlue: Float
        public var opacity: Float
        public init(colorSpace: Color.RGBColorSpace = .sRGB, red: Float, green: Float, blue: Float, opacity: Float = 1) {
            linearRed = red; linearGreen = green; linearBlue = blue; self.opacity = opacity
        }
        public var red: Float { linearRed }
        public var green: Float { linearGreen }
        public var blue: Float { linearBlue }
        public var cgColor: CGColor { fatalError() }
        public var description: String { "" }
    }
}

extension Color: ShapeStyle {}

extension Color: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

extension ShapeStyle where Self == Color {
    public static var red: Color { .red }
    public static var orange: Color { .orange }
    public static var yellow: Color { .yellow }
    public static var green: Color { .green }
    public static var mint: Color { .mint }
    public static var teal: Color { .teal }
    public static var cyan: Color { .cyan }
    public static var blue: Color { .blue }
    public static var indigo: Color { .indigo }
    public static var purple: Color { .purple }
    public static var pink: Color { .pink }
    public static var brown: Color { .brown }
    public static var white: Color { .white }
    public static var gray: Color { .gray }
    public static var black: Color { .black }
    public static var clear: Color { .clear }
}

// MARK: - Gradients

@frozen public struct Gradient: Equatable, Hashable, Sendable {
    @frozen public struct Stop: Equatable, Hashable, Sendable {
        public var color: Color
        public var location: CGFloat
        public init(color: Color, location: CGFloat) { self.color = color; self.location = location }
    }
    public var stops: [Gradient.Stop]
    public init(stops: [Gradient.Stop]) { self.stops = stops }
    public init(colors: [Color]) { stops = [] }

    public struct ColorSpace: Hashable, Sendable {
        public static let device = ColorSpace()
        public static let perceptual = ColorSpace()
    }
    public func colorSpace(_ space: Gradient.ColorSpace) -> AnyGradient { AnyGradient(self) }
}
extension Gradient: ShapeStyle {}

@frozen public struct AnyGradient: Hashable, ShapeStyle, Sendable {
    public init(_ gradient: Gradient) {}
    public func colorSpace(_ space: Gradient.ColorSpace) -> AnyGradient { self }
}

@frozen public struct LinearGradient: ShapeStyle, View, Sendable {
    nonisolated public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) {}
    nonisolated public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {}
    nonisolated public init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) {}
    public typealias Body = _ShapeView<Rectangle, LinearGradient>
    public var body: _ShapeView<Rectangle, LinearGradient> { _ShapeView(shape: Rectangle(), style: self) }
}

@frozen public struct RadialGradient: ShapeStyle, View, Sendable {
    nonisolated public init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    nonisolated public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    nonisolated public init(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    public typealias Body = _ShapeView<Rectangle, RadialGradient>
    public var body: _ShapeView<Rectangle, RadialGradient> { _ShapeView(shape: Rectangle(), style: self) }
}

@frozen public struct EllipticalGradient: ShapeStyle, View, Sendable {
    nonisolated public init(gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {}
    nonisolated public init(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {}
    nonisolated public init(stops: [Gradient.Stop], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {}
    public typealias Body = _ShapeView<Rectangle, EllipticalGradient>
    public var body: _ShapeView<Rectangle, EllipticalGradient> { _ShapeView(shape: Rectangle(), style: self) }
}

@frozen public struct AngularGradient: ShapeStyle, View, Sendable {
    nonisolated public init(gradient: Gradient, center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {}
    nonisolated public init(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) {}
    nonisolated public init(stops: [Gradient.Stop], center: UnitPoint, startAngle: Angle, endAngle: Angle) {}
    nonisolated public init(gradient: Gradient, center: UnitPoint, angle: Angle = .zero) {}
    nonisolated public init(colors: [Color], center: UnitPoint, angle: Angle = .zero) {}
    nonisolated public init(stops: [Gradient.Stop], center: UnitPoint, angle: Angle = .zero) {}
    public typealias Body = _ShapeView<Rectangle, AngularGradient>
    public var body: _ShapeView<Rectangle, AngularGradient> { _ShapeView(shape: Rectangle(), style: self) }
}

extension ShapeStyle where Self == LinearGradient {
    public static func linearGradient(_ gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { .init(gradient: gradient, startPoint: startPoint, endPoint: endPoint) }
    public static func linearGradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { .init(colors: colors, startPoint: startPoint, endPoint: endPoint) }
    public static func linearGradient(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { .init(stops: stops, startPoint: startPoint, endPoint: endPoint) }
}
extension ShapeStyle where Self == RadialGradient {
    public static func radialGradient(_ gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient { .init(gradient: gradient, center: center, startRadius: startRadius, endRadius: endRadius) }
    public static func radialGradient(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient { .init(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius) }
    public static func radialGradient(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient { .init(stops: stops, center: center, startRadius: startRadius, endRadius: endRadius) }
}
extension ShapeStyle where Self == AngularGradient {
    public static func angularGradient(_ gradient: Gradient, center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient { .init(gradient: gradient, center: center, startAngle: startAngle, endAngle: endAngle) }
    public static func angularGradient(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient { .init(colors: colors, center: center, startAngle: startAngle, endAngle: endAngle) }
    public static func conicGradient(_ gradient: Gradient, center: UnitPoint, angle: Angle = .zero) -> AngularGradient { .init(gradient: gradient, center: center, angle: angle) }
    public static func conicGradient(colors: [Color], center: UnitPoint, angle: Angle = .zero) -> AngularGradient { .init(colors: colors, center: center, angle: angle) }
}
extension ShapeStyle where Self == EllipticalGradient {
    public static func ellipticalGradient(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient { .init(colors: colors, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction) }
}

public struct ImagePaint: ShapeStyle {
    public var image: Image
    public var sourceRect: CGRect
    public var scale: CGFloat
    public init(image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) {
        self.image = image; self.sourceRect = sourceRect; self.scale = scale
    }
}
extension ShapeStyle where Self == ImagePaint {
    public static func image(_ image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) -> ImagePaint { .init(image: image, sourceRect: sourceRect, scale: scale) }
}

// MARK: - Geometry value types

@frozen public struct UnitPoint: Hashable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public init() { x = 0; y = 0 }
    public init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }
    public static let zero = UnitPoint()
    public static let center = UnitPoint(x: 0.5, y: 0.5)
    public static let leading = UnitPoint(x: 0, y: 0.5)
    public static let trailing = UnitPoint(x: 1, y: 0.5)
    public static let top = UnitPoint(x: 0.5, y: 0)
    public static let bottom = UnitPoint(x: 0.5, y: 1)
    public static let topLeading = UnitPoint(x: 0, y: 0)
    public static let topTrailing = UnitPoint(x: 1, y: 0)
    public static let bottomLeading = UnitPoint(x: 0, y: 1)
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)
}

@frozen public struct Angle: Hashable, Comparable, Sendable {
    public var radians: Double
    public var degrees: Double { get { radians * 180 / .pi } set { radians = newValue * .pi / 180 } }
    public init() { radians = 0 }
    public init(radians: Double) { self.radians = radians }
    public init(degrees: Double) { radians = degrees * .pi / 180 }
    public static func radians(_ radians: Double) -> Angle { Angle(radians: radians) }
    public static func degrees(_ degrees: Double) -> Angle { Angle(degrees: degrees) }
    public static let zero = Angle()
    public static func < (lhs: Angle, rhs: Angle) -> Bool { lhs.radians < rhs.radians }
}
extension Angle: Animatable {
    public var animatableData: Double { get { radians } set { radians = newValue } }
}

@frozen public struct EdgeInsets: Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat
    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top; self.leading = leading; self.bottom = bottom; self.trailing = trailing
    }
    public init() { top = 0; leading = 0; bottom = 0; trailing = 0 }
}

@frozen public enum Edge: Int8, CaseIterable, Sendable, Hashable {
    case top, leading, bottom, trailing
    @frozen public struct Set: OptionSet, Sendable, Hashable {
        public typealias Element = Edge.Set
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1)
        public static let leading = Set(rawValue: 2)
        public static let bottom = Set(rawValue: 4)
        public static let trailing = Set(rawValue: 8)
        public static let all: Set = [.top, .leading, .bottom, .trailing]
        public static let horizontal: Set = [.leading, .trailing]
        public static let vertical: Set = [.top, .bottom]
        public init(_ e: Edge) { self.init(rawValue: 1 << e.rawValue) }
    }
}

@frozen public enum HorizontalEdge: Int8, CaseIterable, Codable, Sendable, Hashable {
    case leading, trailing
}
@frozen public enum VerticalEdge: Int8, CaseIterable, Codable, Sendable, Hashable {
    case top, bottom
}

@frozen public enum Axis: Int8, CaseIterable, Sendable, Hashable {
    case horizontal, vertical
    @frozen public struct Set: OptionSet, Sendable, Hashable {
        public typealias Element = Axis.Set
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1)
        public static let vertical = Set(rawValue: 2)
    }
}

@frozen public struct HorizontalAlignment: Equatable, Sendable {
    public init(_ id: any AlignmentID.Type) {}
    public static let leading = HorizontalAlignment(_LeadingAlignmentID.self)
    public static let center = HorizontalAlignment(_LeadingAlignmentID.self)
    public static let trailing = HorizontalAlignment(_LeadingAlignmentID.self)
    public static let listRowSeparatorLeading = HorizontalAlignment(_LeadingAlignmentID.self)
    public static let listRowSeparatorTrailing = HorizontalAlignment(_LeadingAlignmentID.self)
    public static func == (a: HorizontalAlignment, b: HorizontalAlignment) -> Bool { true }
}

@frozen public struct VerticalAlignment: Equatable, Sendable {
    public init(_ id: any AlignmentID.Type) {}
    public static let top = VerticalAlignment(_LeadingAlignmentID.self)
    public static let center = VerticalAlignment(_LeadingAlignmentID.self)
    public static let bottom = VerticalAlignment(_LeadingAlignmentID.self)
    public static let firstTextBaseline = VerticalAlignment(_LeadingAlignmentID.self)
    public static let lastTextBaseline = VerticalAlignment(_LeadingAlignmentID.self)
    public static func == (a: VerticalAlignment, b: VerticalAlignment) -> Bool { true }
}

public protocol AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat
}
internal enum _LeadingAlignmentID: AlignmentID { static func defaultValue(in context: ViewDimensions) -> CGFloat { 0 } }

public struct ViewDimensions: Equatable {
    public var width: CGFloat { 0 }
    public var height: CGFloat { 0 }
    public subscript(guide: HorizontalAlignment) -> CGFloat { 0 }
    public subscript(guide: VerticalAlignment) -> CGFloat { 0 }
    public subscript(explicit guide: HorizontalAlignment) -> CGFloat? { nil }
    public subscript(explicit guide: VerticalAlignment) -> CGFloat? { nil }
}

@frozen public struct Alignment: Equatable, Sendable {
    public var horizontal: HorizontalAlignment
    public var vertical: VerticalAlignment
    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) { self.horizontal = horizontal; self.vertical = vertical }
    public static let center = Alignment(horizontal: .center, vertical: .center)
    public static let leading = Alignment(horizontal: .leading, vertical: .center)
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    public static let top = Alignment(horizontal: .center, vertical: .top)
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
    public static let centerFirstTextBaseline = Alignment(horizontal: .center, vertical: .firstTextBaseline)
    public static let centerLastTextBaseline = Alignment(horizontal: .center, vertical: .lastTextBaseline)
    public static let leadingFirstTextBaseline = Alignment(horizontal: .leading, vertical: .firstTextBaseline)
    public static let leadingLastTextBaseline = Alignment(horizontal: .leading, vertical: .lastTextBaseline)
    public static let trailingFirstTextBaseline = Alignment(horizontal: .trailing, vertical: .firstTextBaseline)
    public static let trailingLastTextBaseline = Alignment(horizontal: .trailing, vertical: .lastTextBaseline)
}

public enum TextAlignment: Hashable, CaseIterable, Sendable { case leading, center, trailing }

public enum ContentMode: Hashable, CaseIterable, Sendable { case fit, fill }

public enum ColorScheme: CaseIterable, Sendable, Hashable { case light, dark }

public enum ColorSchemeContrast: CaseIterable, Sendable, Hashable { case standard, increased }

public enum LayoutDirection: Hashable, CaseIterable, Sendable { case leftToRight, rightToLeft }

public enum ControlSize: CaseIterable, Sendable, Hashable, Comparable { case mini, small, regular, large, extraLarge }

@frozen public enum Visibility: Hashable, CaseIterable, Sendable { case automatic, visible, hidden }

public enum Prominence: Hashable, Sendable { case standard, increased }

public enum DynamicTypeSize: Hashable, Comparable, CaseIterable, Sendable {
    case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge
    case accessibility1, accessibility2, accessibility3, accessibility4, accessibility5
    public var isAccessibilitySize: Bool { self >= .accessibility1 }
}

public enum RoundedCornerStyle: Sendable, Hashable { case circular, continuous }

@frozen public struct RectangleCornerRadii: Equatable, Animatable, Sendable {
    public var topLeading: CGFloat
    public var bottomLeading: CGFloat
    public var bottomTrailing: CGFloat
    public var topTrailing: CGFloat
    public init(topLeading: CGFloat = 0, bottomLeading: CGFloat = 0, bottomTrailing: CGFloat = 0, topTrailing: CGFloat = 0) {
        self.topLeading = topLeading; self.bottomLeading = bottomLeading; self.bottomTrailing = bottomTrailing; self.topTrailing = topTrailing
    }
    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(topLeading, bottomLeading), .init(bottomTrailing, topTrailing)) } set {}
    }
}
