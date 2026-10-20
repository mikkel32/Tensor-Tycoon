// Swift Charts stub for type-checking on Linux. Declarations mirror the iOS/macOS 26 SDK interface; the
// `extension View` / `extension ChartContent` / `extension AxisMark` members are generated from it
// (tools/gen_members.py) for the names the app uses. Real Charts imports SwiftUI without re-exporting it.
import SwiftUI

extension View {
    @inline(__always) nonisolated internal func _m() -> ModifiedContent<Self, EmptyModifier> {
        ModifiedContent(content: self, modifier: EmptyModifier())
    }
}
@inline(__always) internal func _never<T>() -> T { fatalError("Charts stub: not executable") }

// MARK: - Chart

@MainActor @preconcurrency public struct Chart<Content>: View where Content: ChartContent {
    nonisolated public init(@ChartContentBuilder content: () -> Content) {}
    nonisolated public init<Data, C>(_ data: Data, @ChartContentBuilder content: @escaping (Data.Element) -> C)
    where Content == ForEach<Data, Data.Element.ID, C>, Data: RandomAccessCollection, C: ChartContent, Data.Element: Identifiable {}
    nonisolated public init<Data, ID, C>(_ data: Data, id: KeyPath<Data.Element, ID>, @ChartContentBuilder content: @escaping (Data.Element) -> C)
    where Content == ForEach<Data, ID, C>, Data: RandomAccessCollection, ID: Hashable, C: ChartContent {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}

// MARK: - ChartContent

@preconcurrency @MainActor public protocol ChartContent {
    associatedtype Body: ChartContent
    @ChartContentBuilder @MainActor @preconcurrency var body: Self.Body { get }
}

extension Never: ChartContent {}
extension ChartContent where Body == Never {
    public var body: Never { fatalError() }
}

public struct _StubChartContent: ChartContent {
    nonisolated public init() {}
    public typealias Body = Never
}

@frozen public struct BuilderConditional<TrueContent, FalseContent> {
    @frozen public enum Storage { case trueContent(TrueContent), falseContent(FalseContent) }
    public let storage: Storage
}
extension BuilderConditional: ChartContent where TrueContent: ChartContent, FalseContent: ChartContent { public typealias Body = Never }
extension BuilderConditional: AxisContent where TrueContent: AxisContent, FalseContent: AxisContent {}
extension BuilderConditional: AxisMark where TrueContent: AxisMark, FalseContent: AxisMark {}

extension Optional: ChartContent where Wrapped: ChartContent { public typealias Body = Never }
extension Optional: AxisContent where Wrapped: AxisContent {}
extension Optional: AxisMark where Wrapped: AxisMark {}

public struct AnyChartContent: ChartContent {
    nonisolated public init<C>(erasing content: C) where C: ChartContent {}
    public typealias Body = Never
}

@resultBuilder public struct ChartContentBuilder {
    public static func buildBlock() -> some ChartContent { _StubChartContent() }
    public static func buildPartialBlock<T>(first content: T) -> T where T: ChartContent { content }
    public static func buildPartialBlock(accumulated: some ChartContent, next: some ChartContent) -> some ChartContent { _StubChartContent() }
    public static func buildBlock<C>(_ content: C) -> C where C: ChartContent { content }
    @_disfavoredOverload public static func buildBlock<each C>(_ content: repeat each C) -> some ChartContent where repeat each C: ChartContent { _StubChartContent() }
    public static func buildIf<T>(_ content: T?) -> T? where T: ChartContent { content }
    public static func buildEither<T1, T2>(first: T1) -> BuilderConditional<T1, T2> where T1: ChartContent, T2: ChartContent { BuilderConditional(storage: .trueContent(first)) }
    public static func buildEither<T1, T2>(second: T2) -> BuilderConditional<T1, T2> where T1: ChartContent, T2: ChartContent { BuilderConditional(storage: .falseContent(second)) }
    public static func buildLimitedAvailability(_ content: some ChartContent) -> AnyChartContent { AnyChartContent(erasing: content) }
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: ChartContent { content }
}

// ForEach can produce chart content (`ForEach(points) { LineMark(...) }` inside `Chart { }`).
extension ForEach: ChartContent where Content: ChartContent {
    public typealias Body = Never
}
extension ForEach where Content: ChartContent {
    nonisolated public init(_ data: Data, @ChartContentBuilder content: @escaping (Data.Element) -> Content) where ID == Data.Element.ID, Data.Element: Identifiable { fatalError() }
    nonisolated public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ChartContentBuilder content: @escaping (Data.Element) -> Content) { fatalError() }
}

extension ChartContent {
    nonisolated public func accessibilityLabel(_ label: Text) -> some ChartContent { _StubChartContent() }
    nonisolated public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> some ChartContent { _StubChartContent() }
    @_disfavoredOverload nonisolated public func accessibilityLabel<S>(_ label: S) -> some ChartContent where S : StringProtocol { _StubChartContent() }
    nonisolated public func accessibilityValue(_ valueDescription: Text) -> some ChartContent { _StubChartContent() }
    nonisolated public func accessibilityValue(_ valueKey: LocalizedStringKey) -> some ChartContent { _StubChartContent() }
    @_disfavoredOverload nonisolated public func accessibilityValue<S>(_ value: S) -> some ChartContent where S : StringProtocol { _StubChartContent() }
    nonisolated public func accessibilityHidden(_ hidden: Bool) -> some ChartContent { _StubChartContent() }
    nonisolated public func annotation<C>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> some ChartContent where C : View { _StubChartContent() }
    nonisolated public func annotation<C>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: @escaping (AnnotationContext) -> C) -> some ChartContent where C : View { _StubChartContent() }
    nonisolated public func annotation<C>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, overflowResolution: AnnotationOverflowResolution, @ViewBuilder content: () -> C) -> some ChartContent where C : View { _StubChartContent() }
    nonisolated public func annotation<C>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, overflowResolution: AnnotationOverflowResolution, @ViewBuilder content: @escaping (AnnotationContext) -> C) -> some ChartContent where C : View { _StubChartContent() }
    nonisolated public func foregroundStyle<S>(_ style: S) -> some ChartContent where S : ShapeStyle { _StubChartContent() }
    nonisolated public func foregroundStyle<D>(by value: PlottableValue<D>) -> some ChartContent where D : Plottable { _StubChartContent() }
    nonisolated public func position<P>(by value: PlottableValue<P>, axis: Axis? = nil, span: MarkDimension = .automatic) -> some ChartContent where P : Plottable { _StubChartContent() }
    nonisolated public func opacity(_ value: Double) -> some ChartContent { _StubChartContent() }
    nonisolated public func clipShape(_ shape: some Shape, style: FillStyle = FillStyle()) -> some ChartContent { _StubChartContent() }
    nonisolated public func lineStyle(_ style: StrokeStyle) -> some ChartContent { _StubChartContent() }
    nonisolated public func lineStyle<D>(by value: PlottableValue<D>) -> some ChartContent where D : Plottable { _StubChartContent() }
    nonisolated public func symbol<S>(_ symbol: S) -> some ChartContent where S : ChartSymbolShape { _StubChartContent() }
    nonisolated public func symbol<D>(by value: PlottableValue<D>) -> some ChartContent where D : Plottable { _StubChartContent() }
    nonisolated public func symbol<V>(@ViewBuilder symbol: () -> V) -> some ChartContent where V : View { _StubChartContent() }
    nonisolated public func symbolSize(_ area: CGFloat) -> some ChartContent { _StubChartContent() }
    nonisolated public func symbolSize(_ size: CGSize) -> some ChartContent { _StubChartContent() }
    nonisolated public func symbolSize<D>(by value: PlottableValue<D>) -> some ChartContent where D : Plottable { _StubChartContent() }
    nonisolated public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some ChartContent { _StubChartContent() }
    nonisolated public func offset(_ value: CGSize) -> some ChartContent { _StubChartContent() }
    nonisolated public func offset(x: CGFloat = 0, yStart: CGFloat = 0, yEnd: CGFloat = 0) -> some ChartContent { _StubChartContent() }
    nonisolated public func offset(xStart: CGFloat = 0, xEnd: CGFloat = 0, y: CGFloat = 0) -> some ChartContent { _StubChartContent() }
    nonisolated public func offset(xStart: CGFloat = 0, xEnd: CGFloat = 0, yStart: CGFloat = 0, yEnd: CGFloat = 0) -> some ChartContent { _StubChartContent() }
    nonisolated public func interpolationMethod(_ method: InterpolationMethod) -> some ChartContent { _StubChartContent() }
    nonisolated public func blur(radius: CGFloat) -> some ChartContent { _StubChartContent() }
    nonisolated public func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some ChartContent { _StubChartContent() }
}

// MARK: - Plottable

public protocol Plottable {
    associatedtype PrimitivePlottable: PrimitivePlottableProtocol
    var primitivePlottable: Self.PrimitivePlottable { get }
    init?(primitivePlottable: Self.PrimitivePlottable)
}

public protocol PrimitivePlottableProtocol: Plottable where Self == Self.PrimitivePlottable {}

extension PrimitivePlottableProtocol {
    public var primitivePlottable: Self { self }
    nonisolated public init?(primitivePlottable: Self.PrimitivePlottable) { self = primitivePlottable }
}

extension Plottable where Self: RawRepresentable, Self.RawValue: PrimitivePlottableProtocol {
    public var primitivePlottable: Self.RawValue { rawValue }
    public init?(primitivePlottable: Self.RawValue) { self.init(rawValue: primitivePlottable) }
}

extension Never: PrimitivePlottableProtocol { public typealias PrimitivePlottable = Never }
extension Double: Plottable, PrimitivePlottableProtocol { public typealias PrimitivePlottable = Double }
extension String: Plottable, PrimitivePlottableProtocol { public typealias PrimitivePlottable = String }
extension Date: Plottable, PrimitivePlottableProtocol { public typealias PrimitivePlottable = Date }
extension Float: PrimitivePlottableProtocol { public typealias PrimitivePlottable = Float }
extension Int: PrimitivePlottableProtocol { public typealias PrimitivePlottable = Int }
extension Int8: PrimitivePlottableProtocol { public typealias PrimitivePlottable = Int8 }
extension Int16: PrimitivePlottableProtocol { public typealias PrimitivePlottable = Int16 }
extension Int32: PrimitivePlottableProtocol { public typealias PrimitivePlottable = Int32 }
extension Int64: PrimitivePlottableProtocol { public typealias PrimitivePlottable = Int64 }
extension UInt: PrimitivePlottableProtocol { public typealias PrimitivePlottable = UInt }
extension UInt8: PrimitivePlottableProtocol { public typealias PrimitivePlottable = UInt8 }
extension UInt16: PrimitivePlottableProtocol { public typealias PrimitivePlottable = UInt16 }
extension UInt32: PrimitivePlottableProtocol { public typealias PrimitivePlottable = UInt32 }
extension UInt64: PrimitivePlottableProtocol { public typealias PrimitivePlottable = UInt64 }
extension Decimal: Plottable {
    public var primitivePlottable: Double { 0 }
    nonisolated public init?(primitivePlottable: Double) { self.init(primitivePlottable) }
    public typealias PrimitivePlottable = Double
}

public struct PlottableValue<Value> where Value: Plottable {
    internal init() {}
}
extension PlottableValue {
    public static func value(_ labelKey: LocalizedStringKey, _ value: Value) -> PlottableValue<Value> { .init() }
    @_disfavoredOverload public static func value<S>(_ label: S, _ value: Value) -> PlottableValue<Value> where S: StringProtocol { .init() }
    public static func value(_ label: Text, _ value: Value) -> PlottableValue<Value> { .init() }
    public static func value(_ labelKey: LocalizedStringKey, _ range: Range<Value>) -> PlottableValue<Value> where Value: Comparable { .init() }
    @_disfavoredOverload public static func value<S>(_ label: S, _ range: Range<Value>) -> PlottableValue<Value> where Value: Comparable, S: StringProtocol { .init() }
    public static func value(_ label: Text, _ range: Range<Value>) -> PlottableValue<Value> where Value: Comparable { .init() }
    public static func value(_ labelKey: LocalizedStringKey, _ range: ChartBinRange<Value>) -> PlottableValue<Value> where Value: Comparable { .init() }
    @_disfavoredOverload public static func value<S>(_ label: S, _ range: ChartBinRange<Value>) -> PlottableValue<Value> where Value: Comparable, S: StringProtocol { .init() }
    public static func value(_ labelKey: LocalizedStringKey, _ date: Date, unit: Calendar.Component, calendar: Calendar? = nil) -> PlottableValue<Value> where Value == Date { .init() }
    @_disfavoredOverload public static func value<S>(_ label: S, _ date: Date, unit: Calendar.Component, calendar: Calendar? = nil) -> PlottableValue<Value> where Value == Date, S: StringProtocol { .init() }
    public static func value(_ label: Text, _ date: Date, unit: Calendar.Component, calendar: Calendar? = nil) -> PlottableValue<Value> where Value == Date { .init() }
}

public struct ChartBinRange<Bound>: RangeExpression where Bound: Comparable {
    public var lowerBound: Bound
    public var upperBound: Bound
    public func relative<C>(to collection: C) -> Range<Bound> where Bound == C.Index, C: Collection { lowerBound..<upperBound }
    public func contains(_ element: Bound) -> Bool { false }
}

@frozen public struct MarkDimension: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, Sendable, CustomStringConvertible {
    internal init() {}
    public static var automatic: MarkDimension { .init() }
    public static func ratio(_ value: CGFloat) -> MarkDimension { .init() }
    public static func inset(_ value: CGFloat) -> MarkDimension { .init() }
    public static func fixed(_ value: CGFloat) -> MarkDimension { .init() }
    public init(floatLiteral value: Double) {}
    public init(integerLiteral value: Int) {}
    public var description: String { "" }
}

@frozen public struct MarkStackingMethod: Equatable, Sendable, CustomStringConvertible {
    internal init() {}
    public static var standard: MarkStackingMethod { .init() }
    public static var normalized: MarkStackingMethod { .init() }
    public static var center: MarkStackingMethod { .init() }
    public static var unstacked: MarkStackingMethod { .init() }
    public var description: String { "" }
}

@frozen public struct InterpolationMethod: Sendable, CustomStringConvertible {
    internal init() {}
    public static var linear: InterpolationMethod { .init() }
    public static var cardinal: InterpolationMethod { .init() }
    public static func cardinal(tension: CGFloat) -> InterpolationMethod { .init() }
    public static var catmullRom: InterpolationMethod { .init() }
    public static func catmullRom(alpha: CGFloat) -> InterpolationMethod { .init() }
    public static var monotone: InterpolationMethod { .init() }
    public static var stepStart: InterpolationMethod { .init() }
    public static var stepCenter: InterpolationMethod { .init() }
    public static var stepEnd: InterpolationMethod { .init() }
    public var description: String { "" }
}

public struct AnnotationPosition: Equatable, Sendable {
    public static let automatic = AnnotationPosition()
    public static let overlay = AnnotationPosition()
    public static let top = AnnotationPosition()
    public static let bottom = AnnotationPosition()
    public static let leading = AnnotationPosition()
    public static let trailing = AnnotationPosition()
    public static let topLeading = AnnotationPosition()
    public static let topTrailing = AnnotationPosition()
    public static let bottomLeading = AnnotationPosition()
    public static let bottomTrailing = AnnotationPosition()
}

public struct AnnotationContext {
    public let targetSize: CGSize
}

public struct AnnotationOverflowResolution: Sendable {
    public struct Strategy: Sendable {
        public static var automatic: Strategy { .init() }
        public static var fit: Strategy { .init() }
        public static func fit(to boundary: Boundary) -> Strategy { .init() }
        public static var padScale: Strategy { .init() }
        public static var disabled: Strategy { .init() }
    }
    public struct Boundary: Sendable {
        public static var automatic: Boundary { .init() }
        public static var plot: Boundary { .init() }
        public static var chart: Boundary { .init() }
    }
    public static var automatic: AnnotationOverflowResolution { .init() }
    public init(x: Strategy = .automatic, y: Strategy = .automatic) {}
}

// MARK: - Marks

public struct LineMark: ChartContent {
    public typealias Body = Never
    nonisolated public init<X, Y>(x: PlottableValue<X>, y: PlottableValue<Y>) where X: Plottable, Y: Plottable {}
    nonisolated public init<X, Y, S>(x: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<S>) where X: Plottable, Y: Plottable, S: Plottable {}
}

public struct AreaMark: ChartContent {
    public typealias Body = Never
    nonisolated public init<X, Y>(x: PlottableValue<X>, y: PlottableValue<Y>, stacking: MarkStackingMethod = .standard) where X: Plottable, Y: Plottable {}
    nonisolated public init<X, Y>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>) where X: Plottable, Y: Plottable {}
    nonisolated public init<X, Y>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) where X: Plottable, Y: Plottable {}
    nonisolated public init<X, Y, S>(x: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<S>, stacking: MarkStackingMethod = .standard) where X: Plottable, Y: Plottable, S: Plottable {}
    nonisolated public init<X, Y, S>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<S>) where X: Plottable, Y: Plottable, S: Plottable {}
    nonisolated public init<X, Y, S>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, series: PlottableValue<S>) where X: Plottable, Y: Plottable, S: Plottable {}
}

public struct BarMark: ChartContent {
    public typealias Body = Never
    nonisolated public init<X, Y>(x: PlottableValue<X>, y: PlottableValue<Y>, width: MarkDimension = .automatic, height: MarkDimension = .automatic, stacking: MarkStackingMethod = .standard) where X: Plottable, Y: Plottable {}
    nonisolated public init<X>(x: PlottableValue<X>, yStart: CGFloat? = nil, yEnd: CGFloat? = nil, width: MarkDimension = .automatic, stacking: MarkStackingMethod = .standard) where X: Plottable {}
    nonisolated public init<Y>(xStart: CGFloat? = nil, xEnd: CGFloat? = nil, y: PlottableValue<Y>, height: MarkDimension = .automatic, stacking: MarkStackingMethod = .standard) where Y: Plottable {}
    nonisolated public init<X, Y>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>, height: MarkDimension = .automatic) where X: Plottable, Y: Plottable {}
    nonisolated public init<X>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, yStart: CGFloat? = nil, yEnd: CGFloat? = nil) where X: Plottable {}
    nonisolated public init<X, Y>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, width: MarkDimension = .automatic) where X: Plottable, Y: Plottable {}
    nonisolated public init<Y>(xStart: CGFloat? = nil, xEnd: CGFloat? = nil, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) where Y: Plottable {}
}

public struct PointMark: ChartContent {
    public typealias Body = Never
    nonisolated public init<X, Y>(x: PlottableValue<X>, y: PlottableValue<Y>) where X: Plottable, Y: Plottable {}
    nonisolated public init<X>(x: PlottableValue<X>, y: CGFloat? = nil) where X: Plottable {}
    nonisolated public init<Y>(x: CGFloat? = nil, y: PlottableValue<Y>) where Y: Plottable {}
}

public struct RuleMark: ChartContent {
    public typealias Body = Never
    nonisolated public init<Y>(xStart: CGFloat? = nil, xEnd: CGFloat? = nil, y: PlottableValue<Y>) where Y: Plottable {}
    nonisolated public init<X, Y>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>) where X: Plottable, Y: Plottable {}
    nonisolated public init<X>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: CGFloat? = nil) where X: Plottable {}
    nonisolated public init<X>(x: PlottableValue<X>, yStart: CGFloat? = nil, yEnd: CGFloat? = nil) where X: Plottable {}
    nonisolated public init<X, Y>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) where X: Plottable, Y: Plottable {}
    nonisolated public init<Y>(x: CGFloat? = nil, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) where Y: Plottable {}
}

public struct RectangleMark: ChartContent {
    public typealias Body = Never
    nonisolated public init<X, Y>(x: PlottableValue<X>, y: PlottableValue<Y>, width: MarkDimension = .automatic, height: MarkDimension = .automatic) where X: Plottable, Y: Plottable {}
    nonisolated public init<X>(x: PlottableValue<X>, yStart: CGFloat? = nil, yEnd: CGFloat? = nil, width: MarkDimension = .automatic) where X: Plottable {}
    nonisolated public init<Y>(xStart: CGFloat? = nil, xEnd: CGFloat? = nil, y: PlottableValue<Y>, height: MarkDimension = .automatic) where Y: Plottable {}
    nonisolated public init<X, Y>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>, height: MarkDimension = .automatic) where X: Plottable, Y: Plottable {}
    nonisolated public init<X>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, yStart: CGFloat? = nil, yEnd: CGFloat? = nil) where X: Plottable {}
    nonisolated public init<X, Y>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, width: MarkDimension = .automatic) where X: Plottable, Y: Plottable {}
    nonisolated public init<Y>(xStart: CGFloat? = nil, xEnd: CGFloat? = nil, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) where Y: Plottable {}
    nonisolated public init<X, Y>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) where X: Plottable, Y: Plottable {}
    nonisolated public init(xStart: CGFloat? = nil, xEnd: CGFloat? = nil, yStart: CGFloat? = nil, yEnd: CGFloat? = nil) {}
}

public struct SectorMark: ChartContent {
    public typealias Body = Never
    nonisolated public init(angle: PlottableValue<some Plottable>, innerRadius: MarkDimension = .automatic, outerRadius: MarkDimension = .automatic, angularInset: CGFloat? = nil) {}
}

public protocol ChartSymbolShape: Shape {
    var perceptualUnitRect: CGRect { get }
}
public struct BasicChartSymbolShape: ChartSymbolShape {
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public var perceptualUnitRect: CGRect { .zero }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = _ShapeView<BasicChartSymbolShape, ForegroundStyle>
}
extension ChartSymbolShape where Self == BasicChartSymbolShape {
    public static var circle: BasicChartSymbolShape { .init() }
    public static var square: BasicChartSymbolShape { .init() }
    public static var triangle: BasicChartSymbolShape { .init() }
    public static var diamond: BasicChartSymbolShape { .init() }
    public static var pentagon: BasicChartSymbolShape { .init() }
    public static var plus: BasicChartSymbolShape { .init() }
    public static var cross: BasicChartSymbolShape { .init() }
    public static var asterisk: BasicChartSymbolShape { .init() }
}

// MARK: - Scales

public protocol ScaleDomain {}
public protocol ScaleRange {
    associatedtype VisualValue
}
public protocol PositionScaleRange: ScaleRange where Self.VisualValue == CGFloat {}

extension ClosedRange: ScaleDomain where Bound: Plottable {}
extension Array: ScaleDomain where Element: Plottable {}
extension ArraySlice: ScaleDomain where Element: Plottable {}
extension ClosedRange: ScaleRange where Bound: BinaryFloatingPoint { public typealias VisualValue = Bound }
extension ClosedRange: PositionScaleRange where Bound == CGFloat {}
extension Array: ScaleRange { public typealias VisualValue = Element }
extension Array: PositionScaleRange where Element == CGFloat {}
extension Gradient: ScaleRange { public typealias VisualValue = Gradient }
extension AnyGradient: ScaleRange { public typealias VisualValue = AnyGradient }

public struct AutomaticScaleDomain: ScaleDomain {}
extension ScaleDomain where Self == AutomaticScaleDomain {
    public static var automatic: AutomaticScaleDomain { .init() }
    public static func automatic(includesZero: Bool? = nil, reversed: Bool? = nil) -> AutomaticScaleDomain { .init() }
    public static func automatic<DataValue>(includesZero: Bool? = nil, reversed: Bool? = nil, dataType: DataValue.Type, modifyInferredDomain: @escaping (inout [DataValue]) -> Void) -> AutomaticScaleDomain where DataValue: Plottable { .init() }
}

public struct PlotDimensionScaleRange: PositionScaleRange {
    public typealias VisualValue = CGFloat
}
extension PositionScaleRange where Self == PlotDimensionScaleRange {
    public static var plotDimension: PlotDimensionScaleRange { .init() }
    public static func plotDimension(padding: CGFloat) -> PlotDimensionScaleRange { .init() }
    public static func plotDimension(startPadding: CGFloat = 0, endPadding: CGFloat = 0) -> PlotDimensionScaleRange { .init() }
}

public struct ScaleType: Sendable {
    public static var linear: ScaleType { .init() }
    public static var log: ScaleType { .init() }
    public static var date: ScaleType { .init() }
    public static var category: ScaleType { .init() }
    public static func power(exponent: Double) -> ScaleType { .init() }
    public static var squareRoot: ScaleType { .init() }
    public static func symmetricLog(slopeAtZero: Double) -> ScaleType { .init() }
    public static var symmetricLog: ScaleType { .init() }
}

// MARK: - Axes

public protocol AxisContent {}
public protocol AxisMark {}
extension Never: AxisContent, AxisMark {}

public struct _StubAxisContent: AxisContent { public init() {} }
public struct _StubAxisMark: AxisMark { public init() {} }
public struct AnyAxisContent: AxisContent { public init<C>(erasing content: C) where C: AxisContent {} }
public struct AnyAxisMark: AxisMark { public init<C>(erasing content: C) where C: AxisMark {} }

@resultBuilder public struct AxisContentBuilder {
    public static func buildBlock() -> some AxisContent { _StubAxisContent() }
    public static func buildPartialBlock<T>(first content: T) -> T where T: AxisContent { content }
    public static func buildPartialBlock(accumulated: some AxisContent, next: some AxisContent) -> some AxisContent { _StubAxisContent() }
    public static func buildBlock<T>(_ content: T) -> T where T: AxisContent { content }
    @_disfavoredOverload public static func buildBlock<each T>(_ content: repeat each T) -> some AxisContent where repeat each T: AxisContent { _StubAxisContent() }
    public static func buildIf<T>(_ content: T?) -> T? where T: AxisContent { content }
    public static func buildEither<T1, T2>(first: T1) -> BuilderConditional<T1, T2> where T1: AxisContent, T2: AxisContent { BuilderConditional(storage: .trueContent(first)) }
    public static func buildEither<T1, T2>(second: T2) -> BuilderConditional<T1, T2> where T1: AxisContent, T2: AxisContent { BuilderConditional(storage: .falseContent(second)) }
    public static func buildLimitedAvailability<Content>(_ content: Content) -> AnyAxisContent where Content: AxisContent { AnyAxisContent(erasing: content) }
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: AxisContent { content }
}

@resultBuilder public struct AxisMarkBuilder {
    public static func buildBlock() -> some AxisMark { _StubAxisMark() }
    public static func buildPartialBlock<T>(first content: T) -> T where T: AxisMark { content }
    public static func buildPartialBlock(accumulated: some AxisMark, next: some AxisMark) -> some AxisMark { _StubAxisMark() }
    public static func buildBlock<T>(_ content: T) -> T where T: AxisMark { content }
    @_disfavoredOverload public static func buildBlock<each T>(_ content: repeat each T) -> some AxisMark where repeat each T: AxisMark { _StubAxisMark() }
    public static func buildIf<T>(_ content: T?) -> T? where T: AxisMark { content }
    public static func buildEither<T1, T2>(first: T1) -> BuilderConditional<T1, T2> where T1: AxisMark, T2: AxisMark { BuilderConditional(storage: .trueContent(first)) }
    public static func buildEither<T1, T2>(second: T2) -> BuilderConditional<T1, T2> where T1: AxisMark, T2: AxisMark { BuilderConditional(storage: .falseContent(second)) }
    public static func buildLimitedAvailability<Content>(_ content: Content) -> AnyAxisMark where Content: AxisMark { AnyAxisMark(erasing: content) }
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: AxisMark { content }
}

public struct AxisMarks<Content>: AxisContent where Content: AxisMark {
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, @AxisMarkBuilder content: @escaping (AxisValue) -> Content) {}
    public init<Value>(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: [Value], @AxisMarkBuilder content: @escaping (AxisValue) -> Content) where Value: Plottable {}
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, @AxisMarkBuilder content: @escaping () -> Content) {}
    public init<Value>(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: [Value], @AxisMarkBuilder content: @escaping () -> Content) where Value: Plottable {}
}
extension AxisMarks {
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, stroke: StrokeStyle? = nil) where Content == BuilderConditional<AxisGridLine, AxisTick> {}
    public init<Value>(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: [Value], stroke: StrokeStyle? = nil) where Content == BuilderConditional<AxisGridLine, AxisTick>, Value: Plottable {}
}

public struct AxisMarkPreset: CustomStringConvertible, Sendable {
    public static var automatic: AxisMarkPreset { .init() }
    public static var extended: AxisMarkPreset { .init() }
    public static var aligned: AxisMarkPreset { .init() }
    public static var inset: AxisMarkPreset { .init() }
    public var description: String { "" }
}
public struct AxisMarkPosition: CustomStringConvertible, Sendable {
    public static var automatic: AxisMarkPosition { .init() }
    public static var leading: AxisMarkPosition { .init() }
    public static var trailing: AxisMarkPosition { .init() }
    public static var top: AxisMarkPosition { .init() }
    public static var bottom: AxisMarkPosition { .init() }
    public var description: String { "" }
}
public struct AxisMarkValues: CustomStringConvertible, Sendable {
    public static var automatic: AxisMarkValues { .init() }
    public static func automatic(desiredCount: Int? = nil, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil) -> AxisMarkValues { .init() }
    public static func automatic<P>(minimumStride: P, desiredCount: Int? = nil, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil) -> AxisMarkValues where P: BinaryFloatingPoint { .init() }
    public static func stride(by component: Calendar.Component, count: Int = 1, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil, calendar: Calendar? = nil) -> AxisMarkValues { .init() }
    public static func stride<P>(by stepSize: P, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil) -> AxisMarkValues where P: BinaryFloatingPoint { .init() }
    public var description: String { "" }
}

public struct AxisValue: Sendable {
    public func `as`<P>(_ type: P.Type) -> P? where P: Plottable { nil }
    public var index: Int { 0 }
    public var count: Int { 0 }
}

public struct AxisGridLine: AxisMark {
    public init(centered: Bool? = nil, stroke: StrokeStyle? = nil) {}
}

public struct AxisTick: AxisMark {
    public init(centered: Bool? = nil, length: AxisTick.Length = .automatic, stroke: StrokeStyle? = nil) {}
    public init(centered: Bool? = nil, length: CGFloat, stroke: StrokeStyle? = nil) {}
    public struct Length: CustomStringConvertible, Sendable {
        public static var automatic: AxisTick.Length { .init() }
        public static var label: AxisTick.Length { .init() }
        public static func label(extendPastBy: CGFloat = 0) -> AxisTick.Length { .init() }
        public static var longestLabel: AxisTick.Length { .init() }
        public static func longestLabel(extendPastBy: CGFloat = 0) -> AxisTick.Length { .init() }
        public var description: String { "" }
    }
}

public struct AxisValueLabelOrientation: CustomStringConvertible, Sendable {
    public static var automatic: AxisValueLabelOrientation { .init() }
    public static var horizontal: AxisValueLabelOrientation { .init() }
    public static var vertical: AxisValueLabelOrientation { .init() }
    public static var verticalReversed: AxisValueLabelOrientation { .init() }
    public var description: String { "" }
}
public struct AxisValueLabelCollisionResolution: CustomStringConvertible, Sendable {
    public static var automatic: AxisValueLabelCollisionResolution { .init() }
    public static var greedy: AxisValueLabelCollisionResolution { .init() }
    public static func greedy(priority: Double = 0, minimumSpacing: CGFloat? = nil) -> AxisValueLabelCollisionResolution { .init() }
    public static var truncate: AxisValueLabelCollisionResolution { .init() }
    public static var disabled: AxisValueLabelCollisionResolution { .init() }
    public var description: String { "" }
}

public struct AxisValueLabel<Content>: AxisMark where Content: View {
    nonisolated public init(centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) where Content == Never {}
    nonisolated public init(centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    nonisolated public init(_ titleKey: LocalizedStringKey, centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) where Content == Text {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) where Content == Text, S: StringProtocol {}
    nonisolated public init<Format>(format: Format, centered: Bool? = nil, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool? = nil, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) where Content == Never, Format: FormatStyle, Format.FormatInput: Plottable, Format.FormatOutput == String {}
}

extension AxisMark {
    public func foregroundStyle<S>(_ style: S) -> some AxisMark where S : ShapeStyle { _StubAxisMark() }
    public func font(_ font: Font?) -> some AxisMark { _StubAxisMark() }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some AxisMark { _StubAxisMark() }
    public func offset(_ offset: CGSize) -> some AxisMark { _StubAxisMark() }
}

// MARK: - Chart proxy / overlays

public struct ChartProxy {
    public var plotSize: CGSize { .zero }
    public func position<P>(forX value: P) -> CGFloat? where P: Plottable { nil }
    public func position<P>(forY value: P) -> CGFloat? where P: Plottable { nil }
    public func value<P>(atX position: CGFloat, as: P.Type = P.self) -> P? where P: Plottable { nil }
    public func value<P>(atY position: CGFloat, as: P.Type = P.self) -> P? where P: Plottable { nil }
    public var plotFrame: Anchor<CGRect>? { nil }
}

extension View {
    nonisolated public func chartXAxis(_ visibility: Visibility) -> some View { _m() }
    nonisolated public func chartYAxis(_ visibility: Visibility) -> some View { _m() }
    nonisolated public func chartXAxis<Content>(@AxisContentBuilder content: () -> Content) -> some View where Content : AxisContent { _m() }
    nonisolated public func chartYAxis<Content>(@AxisContentBuilder content: () -> Content) -> some View where Content : AxisContent { _m() }
    nonisolated public func chartXAxisLabel<C>(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> some View where C : View { _m() }
    nonisolated public func chartXAxisLabel(_ labelKey: LocalizedStringKey, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View { _m() }
    @_disfavoredOverload nonisolated public func chartXAxisLabel<S>(_ label: S, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View where S : StringProtocol { _m() }
    nonisolated public func chartYAxisLabel<C>(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> some View where C : View { _m() }
    nonisolated public func chartYAxisLabel(_ labelKey: LocalizedStringKey, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View { _m() }
    @_disfavoredOverload nonisolated public func chartYAxisLabel<S>(_ label: S, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View where S : StringProtocol { _m() }
    nonisolated public func chartLegend<Content>(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) -> some View where Content : View { _m() }
    @MainActor public func chartLegend(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View { _m() }
    @MainActor public func chartLegend(_ visibility: Visibility) -> some View { _m() }
    nonisolated public func chartXScale<Domain, Range>(domain: Domain, range: Range, type: ScaleType? = nil) -> some View where Domain : ScaleDomain, Range : PositionScaleRange { _m() }
    nonisolated public func chartXScale<Domain>(domain: Domain, type: ScaleType? = nil) -> some View where Domain : ScaleDomain { _m() }
    nonisolated public func chartXScale<Range>(range: Range, type: ScaleType? = nil) -> some View where Range : PositionScaleRange { _m() }
    nonisolated public func chartXScale(type: ScaleType? = nil) -> some View { _m() }
    nonisolated public func chartYScale<Domain, Range>(domain: Domain, range: Range, type: ScaleType? = nil) -> some View where Domain : ScaleDomain, Range : PositionScaleRange { _m() }
    nonisolated public func chartYScale<Domain>(domain: Domain, type: ScaleType? = nil) -> some View where Domain : ScaleDomain { _m() }
    nonisolated public func chartYScale<Range>(range: Range, type: ScaleType? = nil) -> some View where Range : PositionScaleRange { _m() }
    nonisolated public func chartYScale(type: ScaleType? = nil) -> some View { _m() }
    nonisolated public func chartForegroundStyleScale<Domain, Range>(domain: Domain, range: Range, type: ScaleType? = nil) -> some View where Domain : ScaleDomain, Range : ScaleRange, Range.VisualValue : ShapeStyle { _m() }
    nonisolated public func chartForegroundStyleScale<Domain>(domain: Domain, type: ScaleType? = nil) -> some View where Domain : ScaleDomain { _m() }
    nonisolated public func chartForegroundStyleScale<Range>(range: Range, type: ScaleType? = nil) -> some View where Range : ScaleRange, Range.VisualValue : ShapeStyle { _m() }
    nonisolated public func chartForegroundStyleScale(type: ScaleType? = nil) -> some View { _m() }
    nonisolated public func chartForegroundStyleScale<DataValue, S>(_ mapping: KeyValuePairs<DataValue, S>) -> some View where DataValue : Plottable, S : ShapeStyle { _m() }
    nonisolated public func chartForegroundStyleScale<Domain, S>(domain: Domain, mapping: @escaping (Domain.Element) -> S) -> some View where Domain : Collection, S : ShapeStyle, Domain.Element : Plottable { _m() }
    nonisolated public func chartForegroundStyleScale<DataValue, S>(mapping: @escaping (DataValue) -> S) -> some View where DataValue : Plottable, S : ShapeStyle { _m() }
    nonisolated public func chartOverlay<V>(alignment: Alignment = .center, @ViewBuilder content: @escaping (ChartProxy) -> V) -> some View where V: View { _m() }
    nonisolated public func chartBackground<V>(alignment: Alignment = .center, @ViewBuilder content: @escaping (ChartProxy) -> V) -> some View where V: View { _m() }
    nonisolated public func chartXSelection<P>(value: Binding<P?>) -> some View where P: Plottable { _m() }
    nonisolated public func chartYSelection<P>(value: Binding<P?>) -> some View where P: Plottable { _m() }
    nonisolated public func chartPlotStyle<Content>(@ViewBuilder content: @escaping (ChartPlotContent) -> Content) -> some View where Content: View { _m() }
}

public struct ChartPlotContent: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
