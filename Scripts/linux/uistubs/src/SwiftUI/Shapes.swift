// SwiftUI stub — Shape, Path and the built-in shapes.
//
// DELIBERATE RELAXATION/STRICTNESS NOTE: real `Shape` also refines the marker protocol `_RemoveGlobalActorIsolation`
// (declared `@_marker @_ImpossibleActor`) so conforming types are not inferred to be main-actor isolated. The Linux
// 6.2.4 compiler does not know `@_ImpossibleActor`, so it is omitted; built-in shapes mark their members
// `nonisolated` explicitly instead. A *custom* Shape in app code would be inferred `@MainActor @preconcurrency` here,
// which in Swift 5 mode produces no extra errors.

public protocol Shape: Sendable, Animatable, View {
    nonisolated func path(in rect: CGRect) -> Path
    nonisolated static var role: ShapeRole { get }
    nonisolated var layoutDirectionBehavior: LayoutDirectionBehavior { get }
    nonisolated func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize
}

extension Shape {
    nonisolated public static var role: ShapeRole { .fill }
    nonisolated public var layoutDirectionBehavior: LayoutDirectionBehavior { .fixed }
    nonisolated public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { .zero }
    public var body: _ShapeView<Self, ForegroundStyle> { _never() }
}

public enum ShapeRole: Sendable, Hashable { case fill, stroke, separator }

public enum LayoutDirectionBehavior: Hashable, Sendable {
    case fixed
    case mirrors(in: LayoutDirection)
    public static var mirrors: LayoutDirectionBehavior { .mirrors(in: .rightToLeft) }
}

public protocol InsettableShape: Shape {
    associatedtype InsetShape: InsettableShape
    nonisolated func inset(by amount: CGFloat) -> Self.InsetShape
}

// Shape modifiers that produce shapes.
public struct _StubShape: InsettableShape {
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    nonisolated public func inset(by amount: CGFloat) -> _StubShape { self }
    public typealias AnimatableData = EmptyAnimatableData
}

extension Shape {
    nonisolated public func trim(from startFraction: CGFloat = 0, to endFraction: CGFloat = 1) -> some Shape { _StubShape() }
    nonisolated public func stroke(style: StrokeStyle) -> some Shape { _StubShape() }
    nonisolated public func stroke(lineWidth: CGFloat = 1) -> some Shape { _StubShape() }
    nonisolated public func intersection<T>(_ other: T, eoFill: Bool = false) -> some Shape where T: Shape { _StubShape() }
    nonisolated public func union<T>(_ other: T, eoFill: Bool = false) -> some Shape where T: Shape { _StubShape() }
    nonisolated public func subtracting<T>(_ other: T, eoFill: Bool = false) -> some Shape where T: Shape { _StubShape() }
    nonisolated public func size(_ size: CGSize) -> some Shape { _StubShape() }
    nonisolated public func size(width: CGFloat, height: CGFloat) -> some Shape { _StubShape() }
    nonisolated public func offset(_ offset: CGSize) -> OffsetShape<Self> { OffsetShape(shape: self, offset: offset) }
    nonisolated public func offset(_ offset: CGPoint) -> OffsetShape<Self> { OffsetShape(shape: self, offset: CGSize(width: offset.x, height: offset.y)) }
    nonisolated public func offset(x: CGFloat = 0, y: CGFloat = 0) -> OffsetShape<Self> { OffsetShape(shape: self, offset: CGSize(width: x, height: y)) }
    nonisolated public func scale(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> ScaledShape<Self> { ScaledShape(shape: self, scale: CGSize(width: x, height: y), anchor: anchor) }
    nonisolated public func scale(_ scale: CGFloat, anchor: UnitPoint = .center) -> ScaledShape<Self> { ScaledShape(shape: self, scale: CGSize(width: scale, height: scale), anchor: anchor) }
    nonisolated public func rotation(_ angle: Angle, anchor: UnitPoint = .center) -> RotatedShape<Self> { RotatedShape(shape: self, angle: angle, anchor: anchor) }
}

@frozen public struct OffsetShape<Content>: Shape where Content: Shape {
    public var shape: Content
    public var offset: CGSize
    nonisolated public init(shape: Content, offset: CGSize) { self.shape = shape; self.offset = offset }
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public var animatableData: EmptyAnimatableData { get { .init() } set {} }
}
@frozen public struct ScaledShape<Content>: Shape where Content: Shape {
    public var shape: Content
    public var scale: CGSize
    public var anchor: UnitPoint
    nonisolated public init(shape: Content, scale: CGSize, anchor: UnitPoint = .center) { self.shape = shape; self.scale = scale; self.anchor = anchor }
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public var animatableData: EmptyAnimatableData { get { .init() } set {} }
}
@frozen public struct RotatedShape<Content>: Shape where Content: Shape {
    public var shape: Content
    public var angle: Angle
    public var anchor: UnitPoint
    nonisolated public init(shape: Content, angle: Angle, anchor: UnitPoint = .center) { self.shape = shape; self.angle = angle; self.anchor = anchor }
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public var animatableData: EmptyAnimatableData { get { .init() } set {} }
}

// Shapes as views: fill / stroke.
extension Shape {
    @_disfavoredOverload nonisolated public func fill<S>(_ content: S, style: FillStyle = FillStyle()) -> some View where S: ShapeStyle { _ShapeView(shape: self, style: content, fillStyle: style) }
    @_disfavoredOverload nonisolated public func fill(style: FillStyle = FillStyle()) -> some View { _ShapeView(shape: self, style: ForegroundStyle(), fillStyle: style) }
    @_disfavoredOverload nonisolated public func stroke<S>(_ content: S, style: StrokeStyle) -> some View where S: ShapeStyle { _ShapeView(shape: self, style: content) }
    @_disfavoredOverload nonisolated public func stroke<S>(_ content: S, lineWidth: CGFloat = 1) -> some View where S: ShapeStyle { _ShapeView(shape: self, style: content) }

    nonisolated public func fill<S>(_ content: S = .foreground, style: FillStyle = FillStyle()) -> _ShapeView<Self, S> where S: ShapeStyle { _ShapeView(shape: self, style: content, fillStyle: style) }
    nonisolated public func stroke<S>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> StrokeShapeView<Self, S, EmptyView> where S: ShapeStyle { StrokeShapeView(shape: self, style: content, strokeStyle: style, isAntialiased: antialiased, background: EmptyView()) }
    nonisolated public func stroke<S>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeShapeView<Self, S, EmptyView> where S: ShapeStyle { StrokeShapeView(shape: self, style: content, strokeStyle: StrokeStyle(lineWidth: lineWidth), isAntialiased: antialiased, background: EmptyView()) }
}

extension InsettableShape {
    @_disfavoredOverload nonisolated public func strokeBorder<S>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> some View where S: ShapeStyle { _ShapeView(shape: self, style: content) }
    @_disfavoredOverload nonisolated public func strokeBorder(style: StrokeStyle, antialiased: Bool = true) -> some View { _ShapeView(shape: self, style: ForegroundStyle()) }
    @_disfavoredOverload nonisolated public func strokeBorder<S>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> some View where S: ShapeStyle { _ShapeView(shape: self, style: content) }
    @_disfavoredOverload nonisolated public func strokeBorder(lineWidth: CGFloat = 1, antialiased: Bool = true) -> some View { _ShapeView(shape: self, style: ForegroundStyle()) }

    nonisolated public func strokeBorder<S>(_ content: S = .foreground, style: StrokeStyle, antialiased: Bool = true) -> StrokeBorderShapeView<Self, S, EmptyView> where S: ShapeStyle { StrokeBorderShapeView(shape: self, style: content, strokeStyle: style, isAntialiased: antialiased, background: EmptyView()) }
    nonisolated public func strokeBorder<S>(_ content: S = .foreground, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeBorderShapeView<Self, S, EmptyView> where S: ShapeStyle { StrokeBorderShapeView(shape: self, style: content, strokeStyle: StrokeStyle(lineWidth: lineWidth), isAntialiased: antialiased, background: EmptyView()) }
}

public protocol ShapeView<Content>: View {
    associatedtype Content: Shape
    var shape: Self.Content { get }
}

extension ShapeView {
    nonisolated public func fill<S>(_ content: S = .foreground, style: FillStyle = FillStyle()) -> FillShapeView<Self.Content, S, Self> where S: ShapeStyle { FillShapeView(shape: shape, style: content, fillStyle: style, background: self) }
    nonisolated public func stroke<S>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> StrokeShapeView<Self.Content, S, Self> where S: ShapeStyle { StrokeShapeView(shape: shape, style: content, strokeStyle: style, isAntialiased: antialiased, background: self) }
    nonisolated public func stroke<S>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeShapeView<Self.Content, S, Self> where S: ShapeStyle { StrokeShapeView(shape: shape, style: content, strokeStyle: StrokeStyle(lineWidth: lineWidth), isAntialiased: antialiased, background: self) }
}

extension ShapeView where Self.Content: InsettableShape {
    nonisolated public func strokeBorder<S>(_ content: S = .foreground, style: StrokeStyle, antialiased: Bool = true) -> StrokeBorderShapeView<Self.Content, S, Self> where S: ShapeStyle { StrokeBorderShapeView(shape: shape, style: content, strokeStyle: style, isAntialiased: antialiased, background: self) }
    nonisolated public func strokeBorder<S>(_ content: S = .foreground, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeBorderShapeView<Self.Content, S, Self> where S: ShapeStyle { StrokeBorderShapeView(shape: shape, style: content, strokeStyle: StrokeStyle(lineWidth: lineWidth), isAntialiased: antialiased, background: self) }
}

@frozen public struct _ShapeView<Content, Style>: View, ShapeView where Content: Shape, Style: ShapeStyle {
    public var shape: Content
    public var style: Style
    public var fillStyle: FillStyle
    nonisolated public init(shape: Content, style: Style, fillStyle: FillStyle = FillStyle()) {
        self.shape = shape; self.style = style; self.fillStyle = fillStyle
    }
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct FillShapeView<Content, Style, Background>: ShapeView where Content: Shape, Style: ShapeStyle, Background: View {
    public var shape: Content
    public var style: Style
    public var fillStyle: FillStyle
    public var background: Background
    nonisolated public init(shape: Content, style: Style, fillStyle: FillStyle, background: Background) {
        self.shape = shape; self.style = style; self.fillStyle = fillStyle; self.background = background
    }
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct StrokeShapeView<Content, Style, Background>: ShapeView where Content: Shape, Style: ShapeStyle, Background: View {
    public var shape: Content
    public var style: Style
    public var strokeStyle: StrokeStyle
    public var isAntialiased: Bool
    public var background: Background
    nonisolated public init(shape: Content, style: Style, strokeStyle: StrokeStyle, isAntialiased: Bool, background: Background) {
        self.shape = shape; self.style = style; self.strokeStyle = strokeStyle; self.isAntialiased = isAntialiased; self.background = background
    }
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct StrokeBorderShapeView<Content, Style, Background>: ShapeView where Content: InsettableShape, Style: ShapeStyle, Background: View {
    public var shape: Content
    public var style: Style
    public var strokeStyle: StrokeStyle
    public var isAntialiased: Bool
    public var background: Background
    nonisolated public init(shape: Content, style: Style, strokeStyle: StrokeStyle, isAntialiased: Bool, background: Background) {
        self.shape = shape; self.style = style; self.strokeStyle = strokeStyle; self.isAntialiased = isAntialiased; self.background = background
    }
    public typealias Body = Never
    public var body: Never { fatalError() }
}

@frozen public struct FillStyle: Equatable, Sendable {
    public var isEOFilled: Bool
    public var isAntialiased: Bool
    public init(eoFill: Bool = false, antialiased: Bool = true) { isEOFilled = eoFill; isAntialiased = antialiased }
}

@frozen public struct StrokeStyle: Equatable, Sendable {
    public var lineWidth: CGFloat
    public var lineCap: CGLineCap
    public var lineJoin: CGLineJoin
    public var miterLimit: CGFloat
    public var dash: [CGFloat]
    public var dashPhase: CGFloat
    public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: CGFloat = 10, dash: [CGFloat] = [CGFloat](), dashPhase: CGFloat = 0) {
        self.lineWidth = lineWidth; self.lineCap = lineCap; self.lineJoin = lineJoin; self.miterLimit = miterLimit; self.dash = dash; self.dashPhase = dashPhase
    }
}

// MARK: - Path

@frozen public struct Path: Equatable, LosslessStringConvertible, @unchecked Sendable {
    public init() {}
    public init(_ path: CGPath) {}
    public init(_ path: CGMutablePath) {}
    public init(_ rect: CGRect) {}
    public init(roundedRect rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous) {}
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) {}
    public init(roundedRect rect: CGRect, cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) {}
    public init(ellipseIn rect: CGRect) {}
    public init(_ callback: (inout Path) -> ()) {}
    public init?(_ string: String) {}
    public var description: String { "" }
    public var cgPath: CGPath { fatalError() }
    public var isEmpty: Bool { true }
    public var boundingRect: CGRect { .zero }
    public func contains(_ p: CGPoint, eoFill: Bool = false) -> Bool { false }

    @frozen public enum Element: Equatable, Sendable {
        case move(to: CGPoint)
        case line(to: CGPoint)
        case quadCurve(to: CGPoint, control: CGPoint)
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
        case closeSubpath
    }
    public func forEach(_ body: (Path.Element) -> Void) {}
    public func strokedPath(_ style: StrokeStyle) -> Path { self }
    public func trimmedPath(from: CGFloat, to: CGFloat) -> Path { self }

    public mutating func move(to end: CGPoint) {}
    public mutating func addLine(to end: CGPoint) {}
    public mutating func addQuadCurve(to end: CGPoint, control: CGPoint) {}
    public mutating func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {}
    public mutating func closeSubpath() {}
    public mutating func addRect(_ rect: CGRect, transform: CGAffineTransform = .identity) {}
    public mutating func addRoundedRect(in rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous, transform: CGAffineTransform = .identity) {}
    public mutating func addRoundedRect(in rect: CGRect, cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous, transform: CGAffineTransform = .identity) {}
    public mutating func addEllipse(in rect: CGRect, transform: CGAffineTransform = .identity) {}
    public mutating func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) {}
    public mutating func addLines(_ lines: [CGPoint]) {}
    public mutating func addRelativeArc(center: CGPoint, radius: CGFloat, startAngle: Angle, delta: Angle, transform: CGAffineTransform = .identity) {}
    public mutating func addArc(center: CGPoint, radius: CGFloat, startAngle: Angle, endAngle: Angle, clockwise: Bool, transform: CGAffineTransform = .identity) {}
    public mutating func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat, transform: CGAffineTransform = .identity) {}
    public mutating func addPath(_ path: Path, transform: CGAffineTransform = .identity) {}
    public var currentPoint: CGPoint? { nil }
    public func normalized(eoFill: Bool = true) -> Path { self }
    public func intersection(_ other: Path, eoFill: Bool = false) -> Path { self }
    public func union(_ other: Path, eoFill: Bool = false) -> Path { self }
    public func subtracting(_ other: Path, eoFill: Bool = false) -> Path { self }
    public func applying(_ transform: CGAffineTransform) -> Path { self }
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> Path { self }
    public static func == (a: Path, b: Path) -> Bool { true }
}

extension Path: Shape {
    nonisolated public func path(in _: CGRect) -> Path { self }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = _ShapeView<Path, ForegroundStyle>
}

// MARK: - Built-in shapes

@frozen public struct Rectangle: Shape {
    nonisolated public init() {}
    nonisolated public func path(in rect: CGRect) -> Path { Path(rect) }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = _ShapeView<Rectangle, ForegroundStyle>
}

@frozen public struct RoundedRectangle: Shape {
    public var cornerSize: CGSize
    public var style: RoundedCornerStyle
    nonisolated public init(cornerSize: CGSize, style: RoundedCornerStyle = .continuous) { self.cornerSize = cornerSize; self.style = style }
    nonisolated public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) { cornerSize = CGSize(width: cornerRadius, height: cornerRadius); self.style = style }
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public var animatableData: CGSize.AnimatableData { get { cornerSize.animatableData } set {} }
    public typealias Body = _ShapeView<RoundedRectangle, ForegroundStyle>
}

@frozen public struct UnevenRoundedRectangle: Shape {
    public var cornerRadii: RectangleCornerRadii
    public var style: RoundedCornerStyle
    nonisolated public init(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) { self.cornerRadii = cornerRadii; self.style = style }
    nonisolated public init(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0, style: RoundedCornerStyle = .continuous) {
        cornerRadii = RectangleCornerRadii(topLeading: topLeadingRadius, bottomLeading: bottomLeadingRadius, bottomTrailing: bottomTrailingRadius, topTrailing: topTrailingRadius); self.style = style
    }
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public var animatableData: RectangleCornerRadii.AnimatableData { get { cornerRadii.animatableData } set {} }
    public typealias Body = _ShapeView<UnevenRoundedRectangle, ForegroundStyle>
}

@frozen public struct Capsule: Shape {
    public var style: RoundedCornerStyle
    nonisolated public init(style: RoundedCornerStyle = .continuous) { self.style = style }
    nonisolated public func path(in r: CGRect) -> Path { Path() }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = _ShapeView<Capsule, ForegroundStyle>
}

@frozen public struct Ellipse: Shape {
    nonisolated public init() {}
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = _ShapeView<Ellipse, ForegroundStyle>
}

@frozen public struct Circle: Shape {
    nonisolated public init() {}
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = _ShapeView<Circle, ForegroundStyle>
}

@frozen public struct ContainerRelativeShape: Shape {
    nonisolated public init() {}
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = _ShapeView<ContainerRelativeShape, ForegroundStyle>
}

public struct ButtonBorderShape: Equatable, Sendable {
    public static let automatic = ButtonBorderShape()
    public static let capsule = ButtonBorderShape()
    public static let roundedRectangle = ButtonBorderShape()
    public static func roundedRectangle(radius: CGFloat) -> ButtonBorderShape { .init() }
    public static let circle = ButtonBorderShape()
}

extension Rectangle: InsettableShape { nonisolated public func inset(by amount: CGFloat) -> some InsettableShape { _StubShape() } }
extension RoundedRectangle: InsettableShape { nonisolated public func inset(by amount: CGFloat) -> some InsettableShape { _StubShape() } }
extension UnevenRoundedRectangle: InsettableShape { nonisolated public func inset(by amount: CGFloat) -> some InsettableShape { _StubShape() } }
extension Capsule: InsettableShape { nonisolated public func inset(by amount: CGFloat) -> some InsettableShape { _StubShape() } }
extension Ellipse: InsettableShape { nonisolated public func inset(by amount: CGFloat) -> some InsettableShape { _StubShape() } }
extension Circle: InsettableShape { nonisolated public func inset(by amount: CGFloat) -> some InsettableShape { _StubShape() } }
extension ContainerRelativeShape: InsettableShape { nonisolated public func inset(by amount: CGFloat) -> some InsettableShape { _StubShape() } }

extension Shape where Self == Rectangle { public static var rect: Rectangle { Rectangle() } }
extension Shape where Self == RoundedRectangle {
    public static func rect(cornerSize: CGSize, style: RoundedCornerStyle = .continuous) -> Self { .init(cornerSize: cornerSize, style: style) }
    public static func rect(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) -> Self { .init(cornerRadius: cornerRadius, style: style) }
}
extension Shape where Self == UnevenRoundedRectangle {
    public static func rect(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) -> Self { .init(cornerRadii: cornerRadii, style: style) }
    public static func rect(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0, style: RoundedCornerStyle = .continuous) -> Self {
        .init(topLeadingRadius: topLeadingRadius, bottomLeadingRadius: bottomLeadingRadius, bottomTrailingRadius: bottomTrailingRadius, topTrailingRadius: topTrailingRadius, style: style)
    }
}
extension Shape where Self == Capsule {
    public static var capsule: Capsule { Capsule() }
    public static func capsule(style: RoundedCornerStyle) -> Self { .init(style: style) }
}
extension Shape where Self == Ellipse { public static var ellipse: Ellipse { Ellipse() } }
extension Shape where Self == Circle { public static var circle: Circle { Circle() } }
extension Shape where Self == ContainerRelativeShape { public static var containerRelative: ContainerRelativeShape { .init() } }

/// Type-erased shape.
@frozen public struct AnyShape: Shape, @unchecked Sendable {
    nonisolated public init<S>(_ shape: S) where S: Shape {}
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = _ShapeView<AnyShape, ForegroundStyle>
}
