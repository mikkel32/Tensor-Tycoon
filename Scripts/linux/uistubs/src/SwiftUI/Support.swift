// SwiftUI stub — supporting types: animation, transitions, accessibility, gestures, glass, canvas, timeline,
// presentation anchors.

// MARK: - Animation

@frozen public struct Animation: Equatable, Hashable, Sendable, CustomStringConvertible {
    internal init() {}
    public var description: String { "Animation" }
    public static let `default` = Animation()

    public static func spring(duration: TimeInterval = 0.5, bounce: Double = 0.0, blendDuration: Double = 0) -> Animation { .init() }
    @_disfavoredOverload public static func spring(response: Double = 0.5, dampingFraction: Double = 0.825, blendDuration: TimeInterval = 0) -> Animation { .init() }
    public static var spring: Animation { .init() }
    public static func spring(_ spring: Spring, blendDuration: TimeInterval = 0.0) -> Animation { .init() }
    @_disfavoredOverload public static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: TimeInterval = 0.25) -> Animation { .init() }
    public static var interactiveSpring: Animation { .init() }
    public static func interactiveSpring(duration: TimeInterval = 0.15, extraBounce: Double = 0.0, blendDuration: TimeInterval = 0.25) -> Animation { .init() }
    public static func interpolatingSpring(mass: Double = 1.0, stiffness: Double, damping: Double, initialVelocity: Double = 0.0) -> Animation { .init() }
    public static func interpolatingSpring(duration: TimeInterval = 0.5, bounce: Double = 0.0, initialVelocity: Double = 0.0) -> Animation { .init() }
    public static var interpolatingSpring: Animation { .init() }
    public static var smooth: Animation { .init() }
    public static func smooth(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Animation { .init() }
    public static var snappy: Animation { .init() }
    public static func snappy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Animation { .init() }
    public static var bouncy: Animation { .init() }
    public static func bouncy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Animation { .init() }
    public static func easeInOut(duration: TimeInterval) -> Animation { .init() }
    public static var easeInOut: Animation { .init() }
    public static func easeIn(duration: TimeInterval) -> Animation { .init() }
    public static var easeIn: Animation { .init() }
    public static func easeOut(duration: TimeInterval) -> Animation { .init() }
    public static var easeOut: Animation { .init() }
    public static func linear(duration: TimeInterval) -> Animation { .init() }
    public static var linear: Animation { .init() }
    public static func timingCurve(_ p1x: Double, _ p1y: Double, _ p2x: Double, _ p2y: Double, duration: TimeInterval = 0.35) -> Animation { .init() }

    public func delay(_ delay: TimeInterval) -> Animation { self }
    public func speed(_ speed: Double) -> Animation { self }
    public func repeatCount(_ repeatCount: Int, autoreverses: Bool = true) -> Animation { self }
    public func repeatForever(autoreverses: Bool = true) -> Animation { self }
}

public struct Spring: Hashable, Sendable {
    public init(duration: TimeInterval = 0.5, bounce: Double = 0.0) {}
    public init(response: Double, dampingRatio: Double) {}
    public static var smooth: Spring { .init() }
    public static var snappy: Spring { .init() }
    public static var bouncy: Spring { .init() }
}

// MARK: - Transitions

@frozen public struct AnyTransition: Sendable {
    internal init() {}
    public init<T>(_ transition: T) where T: Transition {}
    public static func modifier<E>(active: E, identity: E) -> AnyTransition where E: ViewModifier { .init() }
    public static func offset(_ offset: CGSize) -> AnyTransition { .init() }
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyTransition { .init() }
    public static func move(edge: Edge) -> AnyTransition { .init() }
    nonisolated(unsafe) public static let opacity = AnyTransition()
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition { .init() }
    public static var slide: AnyTransition { .init() }
    public static func push(from edge: Edge) -> AnyTransition { .init() }
    public static var identity: AnyTransition { .init() }
    public static var scale: AnyTransition { .init() }
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition { .init() }
    public func animation(_ animation: Animation?) -> AnyTransition { self }
    public func combined(with other: AnyTransition) -> AnyTransition { self }
}

public enum TransitionPhase: Equatable, Sendable {
    case willAppear, identity, didDisappear
    public var isIdentity: Bool { self == .identity }
    public var value: Double { 0 }
}

public struct TransitionProperties: Sendable {
    public init(hasMotion: Bool = true) {}
    public var hasMotion: Bool { true }
}

@MainActor @preconcurrency public protocol Transition {
    associatedtype Body: View
    @ViewBuilder func body(content: Self.Content, phase: TransitionPhase) -> Self.Body
    static var properties: TransitionProperties { get }
    typealias Content = PlaceholderContentView<Self>
}
extension Transition {
    public static var properties: TransitionProperties { TransitionProperties() }
    @MainActor public func combined<T>(with other: T) -> some Transition where T: Transition { _StubTransition() }
    @MainActor public func animation(_ animation: Animation?) -> some Transition { _StubTransition() }
}

public struct PlaceholderContentView<Value>: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct _StubTransition: Transition {
    public func body(content: Content, phase: TransitionPhase) -> some View { content }
}

public struct OpacityTransition: Transition {
    public init() {}
    @MainActor public func body(content: OpacityTransition.Content, phase: TransitionPhase) -> some View { content }
}
public struct MoveTransition: Transition {
    public var edge: Edge
    public init(edge: Edge) { self.edge = edge }
    @MainActor public func body(content: MoveTransition.Content, phase: TransitionPhase) -> some View { content }
}
public struct ScaleTransition: Transition {
    public var scale: Double
    public var anchor: UnitPoint
    public init(_ scale: Double, anchor: UnitPoint = .center) { self.scale = scale; self.anchor = anchor }
    @MainActor public func body(content: ScaleTransition.Content, phase: TransitionPhase) -> some View { content }
}
public struct SlideTransition: Transition {
    public init() {}
    @MainActor public func body(content: SlideTransition.Content, phase: TransitionPhase) -> some View { content }
}
public struct PushTransition: Transition {
    public var edge: Edge
    public init(edge: Edge) { self.edge = edge }
    @MainActor public func body(content: PushTransition.Content, phase: TransitionPhase) -> some View { content }
}
public struct OffsetTransition: Transition {
    public var offset: CGSize
    public init(_ offset: CGSize) { self.offset = offset }
    @MainActor public func body(content: OffsetTransition.Content, phase: TransitionPhase) -> some View { content }
}
public struct IdentityTransition: Transition {
    public init() {}
    @MainActor public func body(content: IdentityTransition.Content, phase: TransitionPhase) -> some View { content }
}
public struct BlurReplaceTransition: Transition {
    public init(configuration: Configuration) {}
    public struct Configuration: Equatable, Sendable {
        public static var downUp: Configuration { .init() }
        public static var upUp: Configuration { .init() }
    }
    @MainActor public func body(content: BlurReplaceTransition.Content, phase: TransitionPhase) -> some View { content }
}

extension Transition where Self == OpacityTransition { @MainActor public static var opacity: OpacityTransition { .init() } }
extension Transition where Self == MoveTransition { @MainActor public static func move(edge: Edge) -> Self { Self(edge: edge) } }
extension Transition where Self == ScaleTransition {
    @MainActor public static var scale: ScaleTransition { .init(0) }
    @MainActor public static func scale(_ scale: Double, anchor: UnitPoint = .center) -> Self { Self(scale, anchor: anchor) }
}
extension Transition where Self == SlideTransition { @MainActor public static var slide: SlideTransition { .init() } }
extension Transition where Self == PushTransition { @MainActor public static func push(from edge: Edge) -> Self { Self(edge: edge) } }
extension Transition where Self == OffsetTransition {
    @MainActor public static func offset(_ offset: CGSize) -> Self { Self(offset) }
    @MainActor public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> Self { Self(CGSize(width: x, height: y)) }
}
extension Transition where Self == IdentityTransition { @MainActor public static var identity: IdentityTransition { .init() } }
extension Transition where Self == BlurReplaceTransition {
    @MainActor public static var blurReplace: BlurReplaceTransition { .init(configuration: .downUp) }
    @MainActor public static func blurReplace(_ config: BlurReplaceTransition.Configuration = .downUp) -> Self { .init(configuration: config) }
}

public struct ContentTransition: Equatable, Sendable {
    internal init() {}
    public static let identity = ContentTransition()
    public static let opacity = ContentTransition()
    public static let interpolate = ContentTransition()
    public static func numericText(countsDown: Bool = false) -> ContentTransition { .init() }
    public static func numericText(value: Double) -> ContentTransition { .init() }
    public static var symbolEffect: ContentTransition { .init() }
}

// MARK: - Accessibility

public struct AccessibilityAttachmentModifier: ViewModifier {
    nonisolated internal init() {}
    public typealias Body = Never
}

public struct AccessibilityChildBehavior: Hashable, Sendable {
    public static let ignore = AccessibilityChildBehavior()
    public static let contain = AccessibilityChildBehavior()
    public static let combine = AccessibilityChildBehavior()
}

public struct AccessibilityTraits: SetAlgebra, Sendable {
    internal var raw: UInt64
    public init() { raw = 0 }
    internal init(raw: UInt64) { self.raw = raw }
    public static let isButton = AccessibilityTraits(raw: 1 << 0)
    public static let isHeader = AccessibilityTraits(raw: 1 << 1)
    public static let isSelected = AccessibilityTraits(raw: 1 << 2)
    public static let isLink = AccessibilityTraits(raw: 1 << 3)
    public static let isSearchField = AccessibilityTraits(raw: 1 << 4)
    public static let isImage = AccessibilityTraits(raw: 1 << 5)
    public static let playsSound = AccessibilityTraits(raw: 1 << 6)
    public static let isKeyboardKey = AccessibilityTraits(raw: 1 << 7)
    public static let isStaticText = AccessibilityTraits(raw: 1 << 8)
    public static let isSummaryElement = AccessibilityTraits(raw: 1 << 9)
    public static let updatesFrequently = AccessibilityTraits(raw: 1 << 10)
    public static let startsMediaSession = AccessibilityTraits(raw: 1 << 11)
    public static let allowsDirectInteraction = AccessibilityTraits(raw: 1 << 12)
    public static let causesPageTurn = AccessibilityTraits(raw: 1 << 13)
    public static let isModal = AccessibilityTraits(raw: 1 << 14)
    public static let isToggle = AccessibilityTraits(raw: 1 << 15)
    public static let isTabBar = AccessibilityTraits(raw: 1 << 16)
    public func union(_ other: AccessibilityTraits) -> AccessibilityTraits { .init(raw: raw | other.raw) }
    public mutating func formUnion(_ other: AccessibilityTraits) { raw |= other.raw }
    public func intersection(_ other: AccessibilityTraits) -> AccessibilityTraits { .init(raw: raw & other.raw) }
    public mutating func formIntersection(_ other: AccessibilityTraits) { raw &= other.raw }
    public func symmetricDifference(_ other: AccessibilityTraits) -> AccessibilityTraits { .init(raw: raw ^ other.raw) }
    public mutating func formSymmetricDifference(_ other: AccessibilityTraits) { raw ^= other.raw }
    public func contains(_ member: AccessibilityTraits) -> Bool { raw & member.raw == member.raw }
    @discardableResult public mutating func insert(_ newMember: AccessibilityTraits) -> (inserted: Bool, memberAfterInsert: AccessibilityTraits) { raw |= newMember.raw; return (true, newMember) }
    @discardableResult public mutating func remove(_ member: AccessibilityTraits) -> AccessibilityTraits? { nil }
    @discardableResult public mutating func update(with newMember: AccessibilityTraits) -> AccessibilityTraits? { nil }
    public typealias Element = AccessibilityTraits
    public typealias ArrayLiteralElement = AccessibilityTraits
}

public enum AccessibilityHeadingLevel: UInt, Sendable { case unspecified, h1, h2, h3, h4, h5, h6 }

// MARK: - Glass (macOS 26)

public struct Glass: Equatable, Sendable {
    public static var regular: Glass { .init() }
    public static var clear: Glass { .init() }
    public static var identity: Glass { .init() }
    public func tint(_ color: Color?) -> Glass { self }
    public func interactive(_ isEnabled: Bool = true) -> Glass { self }
}

public struct DefaultGlassEffectShape: Shape {
    nonisolated public init() {}
    nonisolated public func path(in rect: CGRect) -> Path { Path() }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = _ShapeView<DefaultGlassEffectShape, ForegroundStyle>
}

@MainActor @preconcurrency public struct GlassEffectContainer<Content>: View where Content: View {
    nonisolated public init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}

// MARK: - Gestures

@MainActor @preconcurrency public protocol Gesture<Value> {
    associatedtype Value
    associatedtype Body: Gesture
    var body: Self.Body { get }
}
extension Never: Gesture {
    public typealias Value = Never
}
extension Gesture where Body == Never {
    public var body: Never { fatalError() }
}

public struct _EndedGesture<Content>: Gesture where Content: Gesture {
    public typealias Value = Content.Value
    public typealias Body = Never
}
public struct _ChangedGesture<Content>: Gesture where Content: Gesture, Content.Value: Equatable {
    public typealias Value = Content.Value
    public typealias Body = Never
}
public struct _MapGesture<Content, Value>: Gesture where Content: Gesture {
    public typealias Body = Never
}
public struct SimultaneousGesture<First, Second>: Gesture where First: Gesture, Second: Gesture {
    public struct Value { public var first: First.Value?; public var second: Second.Value? }
    public typealias Body = Never
}
public struct ExclusiveGesture<First, Second>: Gesture where First: Gesture, Second: Gesture {
    public enum Value { case first(First.Value), second(Second.Value) }
    public typealias Body = Never
}

extension Gesture {
    nonisolated public func onEnded(_ action: @escaping (Self.Value) -> Void) -> _EndedGesture<Self> { _never() }
    nonisolated public func map<T>(_ body: @escaping (Self.Value) -> T) -> _MapGesture<Self, T> { _never() }
    nonisolated public func simultaneously<Other>(with other: Other) -> SimultaneousGesture<Self, Other> where Other: Gesture { _never() }
    nonisolated public func exclusively<Other>(before other: Other) -> ExclusiveGesture<Self, Other> where Other: Gesture { _never() }
}
extension Gesture where Self.Value: Equatable {
    @MainActor public func onChanged(_ action: @escaping (Self.Value) -> Void) -> _ChangedGesture<Self> { _never() }
}

public struct MagnifyGesture: Gesture {
    public struct Value: Equatable, Sendable {
        public var time: Date
        public var magnification: CGFloat
        public var velocity: CGFloat
        public var startAnchor: UnitPoint
        public var startLocation: CGPoint
    }
    public var minimumScaleDelta: CGFloat
    nonisolated public init(minimumScaleDelta: CGFloat = 0.01) { self.minimumScaleDelta = minimumScaleDelta }
    public typealias Body = Never
}

public struct TapGesture: Gesture {
    public var count: Int
    nonisolated public init(count: Int = 1) { self.count = count }
    public typealias Value = ()
    public typealias Body = Never
}

public struct DragGesture: Gesture {
    public struct Value: Equatable, Sendable {
        public var time: Date
        public var location: CGPoint
        public var startLocation: CGPoint
        public var translation: CGSize { .zero }
        public var velocity: CGSize { .zero }
        public var predictedEndLocation: CGPoint { .zero }
        public var predictedEndTranslation: CGSize { .zero }
    }
    public var minimumDistance: CGFloat
    public var coordinateSpace: CoordinateSpace
    nonisolated public init(minimumDistance: CGFloat = 10, coordinateSpace: CoordinateSpace = .local) { self.minimumDistance = minimumDistance; self.coordinateSpace = coordinateSpace }
    public typealias Body = Never
}

public struct LongPressGesture: Gesture {
    public var minimumDuration: Double
    nonisolated public init(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10) { self.minimumDuration = minimumDuration }
    public typealias Value = Bool
    public typealias Body = Never
}

@frozen public struct GestureMask: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let none = GestureMask([])
    public static let gesture = GestureMask(rawValue: 1)
    public static let subviews = GestureMask(rawValue: 2)
    public static let all = GestureMask(rawValue: 3)
}

// MARK: - Layout-ish option sets used by modifiers

@frozen public struct SafeAreaRegions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let container = SafeAreaRegions(rawValue: 1)
    public static let keyboard = SafeAreaRegions(rawValue: 2)
    public static let all = SafeAreaRegions(rawValue: 3)
}

public struct ContentShapeKinds: OptionSet, Sendable {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let interaction = ContentShapeKinds(rawValue: 1)
    public static let dragPreview = ContentShapeKinds(rawValue: 2)
    public static let focusEffect = ContentShapeKinds(rawValue: 16)
    public static let accessibility = ContentShapeKinds(rawValue: 32)
}

public enum PopoverAttachmentAnchor {
    case rect(Anchor<CGRect>.Source)
    case point(UnitPoint)
}

// MARK: - Canvas / GraphicsContext

public struct Canvas<Symbols>: View where Symbols: View {
    public var symbols: Symbols
    public var renderer: (inout GraphicsContext, CGSize) -> Void
    public var isOpaque: Bool
    public var colorMode: ColorRenderingMode
    public var rendersAsynchronously: Bool
    nonisolated public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false,
                            renderer: @escaping (inout GraphicsContext, CGSize) -> Void, @ViewBuilder symbols: () -> Symbols) {
        self.symbols = symbols(); self.renderer = renderer; isOpaque = opaque; self.colorMode = colorMode; self.rendersAsynchronously = rendersAsynchronously
    }
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension Canvas where Symbols == EmptyView {
    nonisolated public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false,
                            renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {
        symbols = EmptyView(); self.renderer = renderer; isOpaque = opaque; self.colorMode = colorMode; self.rendersAsynchronously = rendersAsynchronously
    }
}

@frozen public struct GraphicsContext {
    public var opacity: Double { get { 1 } set {} }
    public var blendMode: GraphicsContext.BlendMode { get { .normal } set {} }
    public var environment: EnvironmentValues { EnvironmentValues() }
    public var transform: CGAffineTransform { get { .identity } set {} }
    public mutating func scaleBy(x: CGFloat, y: CGFloat) {}
    public mutating func translateBy(x: CGFloat, y: CGFloat) {}
    public mutating func rotate(by angle: Angle) {}
    public mutating func concatenate(_ matrix: CGAffineTransform) {}
    public var clipBoundingRect: CGRect { .zero }
    public mutating func clip(to path: Path, style: FillStyle = FillStyle(), options: GraphicsContext.ClipOptions = ClipOptions()) {}
    public func drawLayer(content: (inout GraphicsContext) throws -> Void) rethrows {}

    @frozen public struct BlendMode: RawRepresentable, Equatable {
        public let rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }
        public static var normal: BlendMode { .init(rawValue: 0) }
        public static var multiply: BlendMode { .init(rawValue: 1) }
        public static var screen: BlendMode { .init(rawValue: 2) }
        public static var overlay: BlendMode { .init(rawValue: 3) }
        public static var plusLighter: BlendMode { .init(rawValue: 4) }
    }
    @frozen public struct ClipOptions: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static var inverse: GraphicsContext.ClipOptions { .init(rawValue: 1) }
    }
    @frozen public struct GradientOptions: OptionSet {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static var `repeat`: GraphicsContext.GradientOptions { .init(rawValue: 1) }
        public static var mirror: GraphicsContext.GradientOptions { .init(rawValue: 2) }
        public static var linearColor: GraphicsContext.GradientOptions { .init(rawValue: 4) }
    }
    public struct Shading: Sendable {
        public static var backdrop: GraphicsContext.Shading { .init() }
        public static var foreground: GraphicsContext.Shading { .init() }
        public static func palette(_ array: [GraphicsContext.Shading]) -> GraphicsContext.Shading { .init() }
        public static func color(_ color: Color) -> GraphicsContext.Shading { .init() }
        public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) -> GraphicsContext.Shading { .init() }
        public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) -> GraphicsContext.Shading { .init() }
        public static func style<S>(_ style: S) -> GraphicsContext.Shading where S: ShapeStyle { .init() }
        public static func linearGradient(_ gradient: Gradient, startPoint: CGPoint, endPoint: CGPoint, options: GraphicsContext.GradientOptions = GradientOptions()) -> GraphicsContext.Shading { .init() }
        public static func radialGradient(_ gradient: Gradient, center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, options: GraphicsContext.GradientOptions = GradientOptions()) -> GraphicsContext.Shading { .init() }
        public static func conicGradient(_ gradient: Gradient, center: CGPoint, angle: Angle = Angle(), options: GraphicsContext.GradientOptions = GradientOptions()) -> GraphicsContext.Shading { .init() }
        public static func tiledImage(_ image: Image, origin: CGPoint = .zero, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) -> GraphicsContext.Shading { .init() }
    }
    public func fill(_ path: Path, with shading: GraphicsContext.Shading, style: FillStyle = FillStyle()) {}
    public func stroke(_ path: Path, with shading: GraphicsContext.Shading, style: StrokeStyle) {}
    public func stroke(_ path: Path, with shading: GraphicsContext.Shading, lineWidth: CGFloat = 1) {}
    public func draw(_ image: Image, in rect: CGRect, style: FillStyle = FillStyle()) {}
    public func draw(_ image: Image, at point: CGPoint, anchor: UnitPoint = .center) {}
    public func draw(_ text: Text, in rect: CGRect) {}
    public func draw(_ text: Text, at point: CGPoint, anchor: UnitPoint = .center) {}
    public func resolve(_ text: Text) -> GraphicsContext.ResolvedText { ResolvedText() }
    public func draw(_ text: GraphicsContext.ResolvedText, in rect: CGRect) {}
    public func draw(_ text: GraphicsContext.ResolvedText, at point: CGPoint, anchor: UnitPoint = .center) {}
    public struct ResolvedText {
        public var shading: GraphicsContext.Shading = .foreground
        public func measure(in size: CGSize) -> CGSize { .zero }
    }
}

// MARK: - TimelineView

public protocol TimelineSchedule {
    associatedtype Entries: Sequence where Self.Entries.Element == Date
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Self.Entries
}
public enum TimelineScheduleMode: Sendable { case normal, lowFrequency }

public struct AnimationTimelineSchedule: TimelineSchedule, Sendable {
    public init(minimumInterval: Double? = nil, paused: Bool = false) {}
    public func entries(from start: Date, mode: TimelineScheduleMode) -> [Date] { [] }
}
public struct PeriodicTimelineSchedule: TimelineSchedule, Sendable {
    public init(from startDate: Date, by interval: TimeInterval) {}
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] { [] }
}
public struct EveryMinuteTimelineSchedule: TimelineSchedule, Sendable {
    public init() {}
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] { [] }
}
extension TimelineSchedule where Self == AnimationTimelineSchedule {
    public static var animation: AnimationTimelineSchedule { .init() }
    public static func animation(minimumInterval: Double? = nil, paused: Bool = false) -> AnimationTimelineSchedule { .init(minimumInterval: minimumInterval, paused: paused) }
}
extension TimelineSchedule where Self == PeriodicTimelineSchedule {
    public static func periodic(from startDate: Date, by interval: TimeInterval) -> PeriodicTimelineSchedule { .init(from: startDate, by: interval) }
}
extension TimelineSchedule where Self == EveryMinuteTimelineSchedule {
    public static var everyMinute: EveryMinuteTimelineSchedule { .init() }
}

public struct TimelineViewDefaultContext {
    public enum Cadence: Comparable, Sendable { case live, seconds, minutes }
    public let date: Date
    public let cadence: TimelineViewDefaultContext.Cadence
}

public struct TimelineView<Schedule, Content> where Schedule: TimelineSchedule {
    public typealias Context = TimelineViewDefaultContext
}
extension TimelineView: View where Content: View {
    nonisolated public init(_ schedule: Schedule, @ViewBuilder content: @escaping (TimelineViewDefaultContext) -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}
