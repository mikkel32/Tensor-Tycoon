// SwiftUI stub — Text, LocalizedStringKey, Font, Image, Label.

// MARK: - LocalizedStringKey

@frozen public struct LocalizedStringKey: Equatable, ExpressibleByStringInterpolation, Sendable {
    internal var key: String
    public init(_ value: String) { key = value }
    public init(stringLiteral value: String) { key = value }
    public init(stringInterpolation: LocalizedStringKey.StringInterpolation) { key = "" }

    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) {}
        public mutating func appendInterpolation(_ string: String) {}
        public mutating func appendInterpolation(_ substring: Substring) {}
        public mutating func appendInterpolation<Subject>(_ subject: Subject, formatter: Formatter? = nil) where Subject: ReferenceConvertible {}
        public mutating func appendInterpolation<Subject>(_ subject: Subject, formatter: Formatter? = nil) where Subject: NSObject {}
        public mutating func appendInterpolation<F>(_ input: F.FormatInput, format: F) where F: FormatStyle, F.FormatInput: Equatable, F.FormatOutput == String {}
        public mutating func appendInterpolation<F>(_ input: F.FormatInput, format: F) where F: FormatStyle, F.FormatInput: Equatable, F.FormatOutput == AttributedString {}
        public mutating func appendInterpolation<T>(_ value: T) where T: _FormatSpecifiable {}
        public mutating func appendInterpolation<T>(_ value: T, specifier: String) where T: _FormatSpecifiable {}
        public mutating func appendInterpolation(_ text: Text) {}
        public mutating func appendInterpolation(_ attributedString: AttributedString) {}
        public mutating func appendInterpolation(_ image: Image) {}
        public mutating func appendInterpolation(_ date: Date, style: Text.DateStyle) {}
        public mutating func appendInterpolation(_ dates: ClosedRange<Date>) {}
        public mutating func appendInterpolation(_ interval: DateInterval) {}
        public mutating func appendInterpolation(timerInterval: ClosedRange<Date>, pauseTime: Date? = nil, countsDown: Bool = true, showsHours: Bool = true) {}
        public mutating func appendInterpolation(accessibilityName color: Color) {}
        // Real SDK (26.0): a deprecated, disfavoured catch-all that falls back to String(describing:).
        @available(*, deprecated, message: "Localized string interpolation produces an unlocalized, debug description for this type of value. Use a type supported by LocalizedStringKey.StringInterpolation or initialize a LocalizedStringResource instead with an interpolated value that conforms to CustomLocalizedStringResourceConvertible.")
        @_disfavoredOverload public mutating func appendInterpolation<T>(_ object: T) {}
        public typealias StringLiteralType = String
    }

    public static func == (a: LocalizedStringKey, b: LocalizedStringKey) -> Bool { a.key == b.key }
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias StringLiteralType = String
    public typealias UnicodeScalarLiteralType = String
}

public protocol _FormatSpecifiable: Equatable {
    associatedtype _Arg: CVarArg
    var _arg: Self._Arg { get }
    var _specifier: String { get }
}
extension Int: _FormatSpecifiable { public var _arg: Int64 { Int64(self) }; public var _specifier: String { "%lld" } }
extension Int8: _FormatSpecifiable { public var _arg: Int32 { Int32(self) }; public var _specifier: String { "%d" } }
extension Int16: _FormatSpecifiable { public var _arg: Int32 { Int32(self) }; public var _specifier: String { "%d" } }
extension Int32: _FormatSpecifiable { public var _arg: Int32 { self }; public var _specifier: String { "%d" } }
extension Int64: _FormatSpecifiable { public var _arg: Int64 { self }; public var _specifier: String { "%lld" } }
extension UInt: _FormatSpecifiable { public var _arg: UInt64 { UInt64(self) }; public var _specifier: String { "%llu" } }
extension UInt8: _FormatSpecifiable { public var _arg: UInt32 { UInt32(self) }; public var _specifier: String { "%u" } }
extension UInt16: _FormatSpecifiable { public var _arg: UInt32 { UInt32(self) }; public var _specifier: String { "%u" } }
extension UInt32: _FormatSpecifiable { public var _arg: UInt32 { self }; public var _specifier: String { "%u" } }
extension UInt64: _FormatSpecifiable { public var _arg: UInt64 { self }; public var _specifier: String { "%llu" } }
extension Float: _FormatSpecifiable { public var _arg: Float { self }; public var _specifier: String { "%f" } }
extension Double: _FormatSpecifiable { public var _arg: Double { self }; public var _specifier: String { "%lf" } }
extension CGFloat: _FormatSpecifiable { public var _arg: CGFloat { self }; public var _specifier: String { "%lf" } }

// MARK: - Text

@frozen public struct Text: Equatable, Sendable {
    public init(verbatim content: String) {}
    @_disfavoredOverload public init<S>(_ content: S) where S: StringProtocol {}
    public init(_ key: LocalizedStringKey, tableName: String? = nil, bundle: Bundle? = nil, comment: StaticString? = nil) {}
    public init<Subject>(_ subject: Subject, formatter: Formatter) where Subject: ReferenceConvertible {}
    public init<Subject>(_ subject: Subject, formatter: Formatter) where Subject: NSObject {}
    public init<F>(_ input: F.FormatInput, format: F) where F: FormatStyle, F.FormatInput: Equatable, F.FormatOutput == String {}
    public init<F>(_ input: F.FormatInput, format: F) where F: FormatStyle, F.FormatInput: Equatable, F.FormatOutput == AttributedString {}
    public init(_ image: Image) {}
    public init(_ date: Date, style: Text.DateStyle) {}
    public init(_ dates: ClosedRange<Date>) {}
    public init(_ interval: DateInterval) {}
    public init(timerInterval: ClosedRange<Date>, pauseTime: Date? = nil, countsDown: Bool = true, showsHours: Bool = true) {}
    @_disfavoredOverload public init(_ attributedContent: AttributedString) {}
    public static func == (a: Text, b: Text) -> Bool { true }

    public struct DateStyle: Equatable, Codable, Sendable {
        public static let time = DateStyle()
        public static let date = DateStyle()
        public static let relative = DateStyle()
        public static let offset = DateStyle()
        public static let timer = DateStyle()
    }

    public enum TruncationMode: Sendable, Equatable, Hashable { case head, tail, middle }
    public enum Case: Sendable, Equatable, Hashable { case uppercase, lowercase }

    public struct LineStyle: Hashable, Sendable {
        public init(pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) {}
        public struct Pattern: Sendable, Hashable {
            public static let solid = Pattern()
            public static let dot = Pattern()
            public static let dash = Pattern()
            public static let dashDot = Pattern()
            public static let dashDotDot = Pattern()
        }
        public static let single = LineStyle()
    }

    public struct Scale: Hashable, Sendable {
        public static let `default` = Scale()
        public static let secondary = Scale()
    }

    public struct AlignmentStrategy: Hashable, Sendable {
        public static let layoutBased = AlignmentStrategy()
        public static let writingDirectionBased = AlignmentStrategy()
        public static let `default` = AlignmentStrategy()
    }
}

extension Text: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

extension Text {
    public static func + (lhs: Text, rhs: Text) -> Text { lhs }

    nonisolated public func foregroundColor(_ color: Color?) -> Text { self }
    nonisolated public func foregroundStyle<S>(_ style: S) -> Text where S: ShapeStyle { self }
    nonisolated public func font(_ font: Font?) -> Text { self }
    nonisolated public func fontWeight(_ weight: Font.Weight?) -> Text { self }
    nonisolated public func fontWidth(_ width: Font.Width?) -> Text { self }
    nonisolated public func bold() -> Text { self }
    nonisolated public func bold(_ isActive: Bool) -> Text { self }
    nonisolated public func italic() -> Text { self }
    nonisolated public func italic(_ isActive: Bool) -> Text { self }
    nonisolated public func monospaced(_ isActive: Bool = true) -> Text { self }
    nonisolated public func fontDesign(_ design: Font.Design?) -> Text { self }
    nonisolated public func monospacedDigit() -> Text { self }
    nonisolated public func strikethrough(_ isActive: Bool = true, color: Color? = nil) -> Text { self }
    nonisolated public func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern, color: Color? = nil) -> Text { self }
    nonisolated public func underline(_ isActive: Bool = true, color: Color? = nil) -> Text { self }
    nonisolated public func underline(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern, color: Color? = nil) -> Text { self }
    nonisolated public func kerning(_ kerning: CGFloat) -> Text { self }
    nonisolated public func tracking(_ tracking: CGFloat) -> Text { self }
    nonisolated public func baselineOffset(_ baselineOffset: CGFloat) -> Text { self }
    public func textScale(_ scale: Text.Scale, isEnabled: Bool = true) -> Text { self }
    nonisolated public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> Text { self }
    nonisolated public func accessibilityLabel(_ label: Text) -> Text { self }
    nonisolated public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> Text { self }
    @_disfavoredOverload nonisolated public func accessibilityLabel<S>(_ label: S) -> Text where S: StringProtocol { self }
    public func speechSpellsOutCharacters(_ value: Bool = true) -> Text { self }
}

// MARK: - Font

@frozen public struct Font: Hashable, Sendable {
    internal init() {}

    public static let largeTitle = Font()
    public static let title = Font()
    public static let title2 = Font()
    public static let title3 = Font()
    public static let headline = Font()
    public static let subheadline = Font()
    public static let body = Font()
    public static let callout = Font()
    public static let footnote = Font()
    public static let caption = Font()
    public static let caption2 = Font()
    public static var `default`: Font { Font() }

    public static func system(_ style: Font.TextStyle, design: Font.Design? = nil, weight: Font.Weight? = nil) -> Font { Font() }
    @_disfavoredOverload public static func system(_ style: Font.TextStyle, design: Font.Design = .default) -> Font { Font() }
    public static func system(size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil) -> Font { Font() }
    @_disfavoredOverload public static func system(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font { Font() }
    public static func custom(_ name: String, size: CGFloat) -> Font { Font() }
    public static func custom(_ name: String, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font { Font() }
    public static func custom(_ name: String, fixedSize: CGFloat) -> Font { Font() }
    public init(_ font: CTFont) {}
    public init(_ font: NSFont) {}

    public enum TextStyle: CaseIterable, Sendable, Codable, Hashable {
        case largeTitle, title, title2, title3, headline, subheadline, body, callout, footnote, caption, caption2
    }

    public func italic() -> Font { self }
    public func italic(_ isActive: Bool) -> Font { self }
    public func smallCaps() -> Font { self }
    public func lowercaseSmallCaps() -> Font { self }
    public func uppercaseSmallCaps() -> Font { self }
    public func monospacedDigit() -> Font { self }
    public func weight(_ weight: Font.Weight) -> Font { self }
    public func width(_ width: Font.Width) -> Font { self }
    public func bold() -> Font { self }
    public func bold(_ isActive: Bool) -> Font { self }
    public func monospaced() -> Font { self }
    public func monospaced(_ isActive: Bool) -> Font { self }
    public func leading(_ leading: Font.Leading) -> Font { self }
    public func pointSize(_ size: CGFloat) -> Font { self }
    public func scaled(by factor: CGFloat) -> Font { self }

    @frozen public struct Weight: Hashable, Sendable {
        internal var value: CGFloat
        public static let ultraLight = Weight(value: -0.8)
        public static let thin = Weight(value: -0.6)
        public static let light = Weight(value: -0.4)
        public static let regular = Weight(value: 0)
        public static let medium = Weight(value: 0.23)
        public static let semibold = Weight(value: 0.3)
        public static let bold = Weight(value: 0.4)
        public static let heavy = Weight(value: 0.56)
        public static let black = Weight(value: 0.62)
    }

    public struct Width: Hashable, Sendable {
        public var value: CGFloat
        public static let compressed = Width(-0.3)
        public static let condensed = Width(-0.2)
        public static let standard = Width(0)
        public static let expanded = Width(0.2)
        public init(_ value: CGFloat) { self.value = value }
    }

    public enum Leading: Sendable, Hashable { case standard, tight, loose }

    public enum Design: Hashable, Sendable { case `default`, serif, rounded, monospaced }
}

/// Opaque CoreText / AppKit font types, only so `Font.init(_:)` overloads exist.
public final class CTFont: @unchecked Sendable { internal init() {} }
open class NSFont: NSObject, @unchecked Sendable {
    public init?(name fontName: String, size fontSize: CGFloat) { super.init() }
    open class func systemFont(ofSize fontSize: CGFloat) -> NSFont { fatalError() }
    open class func monospacedDigitSystemFont(ofSize fontSize: CGFloat, weight: NSFont.Weight) -> NSFont { fatalError() }
    public struct Weight: Hashable, Sendable {
        public init(_ rawValue: CGFloat) {}
        public static let regular = Weight(0), medium = Weight(0.23), semibold = Weight(0.3), bold = Weight(0.4)
    }
}

// MARK: - Image

@frozen public struct Image: Equatable, Sendable {
    public init(_ name: String, bundle: Bundle? = nil) {}
    public init(_ name: String, bundle: Bundle? = nil, label: Text) {}
    public init(decorative name: String, bundle: Bundle? = nil) {}
    public init(systemName: String) {}
    public init(systemName: String, variableValue: Double?) {}
    public init(_ cgImage: CGImage, scale: CGFloat, orientation: Image.Orientation = .up, label: Text) {}
    public init(decorative cgImage: CGImage, scale: CGFloat, orientation: Image.Orientation = .up) {}
    /// macOS only.
    public init(nsImage: NSImage) {}
    public init(size: CGSize, label: Text? = nil, opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear,
                renderer: @escaping (inout GraphicsContext) -> Void) {}
    public static func == (lhs: Image, rhs: Image) -> Bool { true }

    public enum ResizingMode: Sendable, Hashable { case tile, stretch }
    @frozen public enum Orientation: UInt8, CaseIterable, Hashable, Sendable {
        case up, upMirrored, down, downMirrored, left, leftMirrored, right, rightMirrored
    }
    public enum Interpolation: Sendable, Hashable { case none, low, medium, high }
    public enum TemplateRenderingMode: Sendable, Hashable { case template, original }
    public enum Scale: Hashable, Sendable { case small, medium, large }

    public func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: Image.ResizingMode = .stretch) -> Image { self }
    public func interpolation(_ interpolation: Image.Interpolation) -> Image { self }
    public func antialiased(_ isAntialiased: Bool) -> Image { self }
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> Image { self }
    public func renderingMode(_ renderingMode: Image.TemplateRenderingMode?) -> Image { self }
}

extension Image: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct SymbolRenderingMode: Sendable, Equatable {
    public static let monochrome = SymbolRenderingMode()
    public static let multicolor = SymbolRenderingMode()
    public static let hierarchical = SymbolRenderingMode()
    public static let palette = SymbolRenderingMode()
}

public struct SymbolVariants: Hashable, Sendable {
    public static let none = SymbolVariants()
    public static let circle = SymbolVariants()
    public static let square = SymbolVariants()
    public static let rectangle = SymbolVariants()
    public static let fill = SymbolVariants()
    public static let slash = SymbolVariants()
    public var circle: SymbolVariants { self }
    public var square: SymbolVariants { self }
    public var fill: SymbolVariants { self }
    public var slash: SymbolVariants { self }
    public func contains(_ other: SymbolVariants) -> Bool { false }
}

public enum ColorRenderingMode: Equatable, Hashable, Sendable { case nonLinear, linear, extendedLinear }

// MARK: - Label

public struct Label<Title, Icon>: View where Title: View, Icon: View {
    nonisolated public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}

extension Label where Title == Text, Icon == Image {
    nonisolated public init(_ titleKey: LocalizedStringKey, image name: String) {}
    nonisolated public init(_ titleKey: LocalizedStringKey, systemImage name: String) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, image name: String) where S: StringProtocol {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, systemImage name: String) where S: StringProtocol {}
}

extension Label where Title == LabelStyleConfiguration.Title, Icon == LabelStyleConfiguration.Icon {
    nonisolated public init(_ configuration: LabelStyleConfiguration) {}
}

@MainActor @preconcurrency public protocol LabelStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
    typealias Configuration = LabelStyleConfiguration
}

public struct LabelStyleConfiguration {
    public struct Title: View { public typealias Body = Never; public var body: Never { fatalError() } }
    public struct Icon: View { public typealias Body = Never; public var body: Never { fatalError() } }
    public var title: LabelStyleConfiguration.Title { _never() }
    public var icon: LabelStyleConfiguration.Icon { _never() }
}

public struct DefaultLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
public struct IconOnlyLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
public struct TitleOnlyLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
public struct TitleAndIconLabelStyle: LabelStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension LabelStyle where Self == DefaultLabelStyle { public static var automatic: DefaultLabelStyle { .init() } }
extension LabelStyle where Self == IconOnlyLabelStyle { public static var iconOnly: IconOnlyLabelStyle { .init() } }
extension LabelStyle where Self == TitleOnlyLabelStyle { public static var titleOnly: TitleOnlyLabelStyle { .init() } }
extension LabelStyle where Self == TitleAndIconLabelStyle { public static var titleAndIcon: TitleAndIconLabelStyle { .init() } }
