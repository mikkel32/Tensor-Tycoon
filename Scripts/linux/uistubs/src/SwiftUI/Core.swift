// SwiftUI stub for type-checking on Linux — core protocols, builders and type-erasure.
//
// Declarations mirror the macOS 26 / iOS 26 SDK interface (SwiftUICore + SwiftUI). Bodies are placeholders: the
// module is only ever used for `swiftc -typecheck`, never linked or run.
//
// Re-exports: on macOS, `import SwiftUI` re-exports AppKit (via its clang module), which re-exports Foundation, which
// re-exports Observation. CoreGraphics is re-exported by SwiftUI's Swift interface.
//
// Deliberate relaxations (everything else mirrors the SDK; tools/audit.py and sanity/negative/run.sh check this):
//  * Opaque `some View` results are all `ModifiedContent<Self, EmptyModifier>` and SDK-private helper types are
//    replaced by `_Stub…` types; clients can't observe either.
//  * `Shape` lacks the SDK's `_RemoveGlobalActorIsolation` marker (needs `@_ImpossibleActor`, unknown to the 6.2.4
//    Linux compiler); see Shapes.swift.
//  * Only the SDK members the app (plausibly) needs are declared; anything missing shows up as an error, never as
//    silent acceptance. EnvironmentValues carries a subset of keys.
//  * Darwin-only Foundation/CoreGraphics API (CGAffineTransform, CGVector, UndoManager, markdown AttributedString,
//    FileManager.trashItem, …) comes from the CoreGraphics stub (DarwinGaps.swift); CF types are NS aliases.
@_exported import AppKit
@_exported import CoreGraphics
@_exported import Observation
import Combine

// MARK: - Stub helpers (internal, invisible to clients)

extension View {
    /// Wraps `self` so a modifier stub has a concrete `some View` result.
    @inline(__always) nonisolated internal func _m() -> ModifiedContent<Self, EmptyModifier> {
        ModifiedContent(content: self, modifier: EmptyModifier())
    }
    @inline(__always) nonisolated internal func _a() -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier())
    }
}

@inline(__always) internal func _never<T>() -> T { fatalError("SwiftUI stub: not executable") }

// MARK: - View

@MainActor @preconcurrency public protocol View {
    associatedtype Body: View
    @ViewBuilder @MainActor @preconcurrency var body: Self.Body { get }
}

extension Never: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

// MARK: - ViewBuilder

@resultBuilder public struct ViewBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: View { content }
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<Content>(_ content: Content) -> Content where Content: View { content }
    @_disfavoredOverload
    public static func buildBlock<each Content>(_ content: repeat each Content) -> TupleView<(repeat each Content)> where repeat each Content: View {
        TupleView((repeat each content))
    }
    public static func buildIf<Content>(_ content: Content?) -> Content? where Content: View { content }
    public static func buildEither<TrueContent, FalseContent>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: View, FalseContent: View {
        _ConditionalContent(storage: .trueContent(first))
    }
    public static func buildEither<TrueContent, FalseContent>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: View, FalseContent: View {
        _ConditionalContent(storage: .falseContent(second))
    }
    public static func buildLimitedAvailability<Content>(_ content: Content) -> AnyView where Content: View { AnyView(content) }
}

@available(*, unavailable)
extension ViewBuilder: Sendable {}

// MARK: - Structural views

@frozen public struct TupleView<T>: View {
    public var value: T
    nonisolated public init(_ value: T) { self.value = value }
    public typealias Body = Never
    public var body: Never { fatalError() }
}

@frozen public struct _ConditionalContent<TrueContent, FalseContent> {
    @frozen public enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }
    public let storage: _ConditionalContent<TrueContent, FalseContent>.Storage
    nonisolated internal init(storage: Storage) { self.storage = storage }
}

extension _ConditionalContent: View where TrueContent: View, FalseContent: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

@frozen public struct EmptyView: View {
    nonisolated public init() {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}

@frozen public struct AnyView: View {
    nonisolated public init<V>(_ view: V) where V: View {}
    nonisolated public init<V>(erasing view: V) where V: View {}
    public init?(_fromValue value: Any) { return nil }
    public typealias Body = Never
    public var body: Never { fatalError() }
}

@frozen public struct Group<Content> {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

extension Group: View where Content: View {
    public init(@ViewBuilder content: () -> Content) {}
}

extension Group: Scene where Content: Scene {
    public init(@SceneBuilder content: () -> Content) {}
}

extension Group: ToolbarContent where Content: ToolbarContent {
    public init(@ToolbarContentBuilder content: () -> Content) {}
}

extension Group: Commands where Content: Commands {
    public init(@CommandsBuilder content: () -> Content) {}
}

extension Group {
    /// Constructs a group from the subviews of the given view.
    public init<Base, Result>(subviews view: Base, @ViewBuilder transform: @escaping (SubviewsCollection) -> Result)
    where Content == GroupElementsOfContent<Base, Result>, Base: View, Result: View {}
}

public struct GroupElementsOfContent<Subviews, Content>: View where Subviews: View, Content: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

/// An opaque collection of subviews (used by `Group(subviews:)` and `ForEach(subviews:)`).
public struct SubviewsCollection: RandomAccessCollection {
    public typealias Element = Subview
    public var startIndex: Int { 0 }
    public var endIndex: Int { 0 }
    public subscript(index: Int) -> Subview { _never() }
}

public struct Subview: View, Identifiable {
    public struct ID: Hashable {}
    public var id: Subview.ID { _never() }
    public typealias Body = Never
    public var body: Never { fatalError() }
}

@frozen public struct EquatableView<Content>: View where Content: Equatable, Content: View {
    public var content: Content
    nonisolated public init(content: Content) { self.content = content }
    public typealias Body = Never
    public var body: Never { fatalError() }
}

extension View where Self: Equatable {
    nonisolated public func equatable() -> EquatableView<Self> { EquatableView(content: self) }
}

// MARK: - ViewModifier

@MainActor @preconcurrency public protocol ViewModifier {
    associatedtype Body: View
    @ViewBuilder @MainActor @preconcurrency func body(content: Self.Content) -> Self.Body
    typealias Content = _ViewModifier_Content<Self>
}

public struct _ViewModifier_Content<Modifier>: View where Modifier: ViewModifier {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

extension ViewModifier where Self.Body == Never {
    public func body(content: Self.Content) -> Self.Body { fatalError() }
}

extension ViewModifier {
    nonisolated public func concat<T>(_ modifier: T) -> ModifiedContent<Self, T> { ModifiedContent(content: self, modifier: modifier) }
}

@frozen public struct EmptyModifier: ViewModifier {
    nonisolated public static let identity = EmptyModifier()
    public typealias Body = Never
    nonisolated public init() {}
}

@frozen public struct ModifiedContent<Content, Modifier> {
    public typealias Body = Never
    public var content: Content
    public var modifier: Modifier
    nonisolated public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }
}

extension ModifiedContent: View where Content: View, Modifier: ViewModifier {
    public var body: Never { fatalError() }
}

extension ModifiedContent: ViewModifier where Content: ViewModifier, Modifier: ViewModifier {}

extension ModifiedContent: Equatable where Content: Equatable, Modifier: Equatable {}

extension View {
    nonisolated public func modifier<T>(_ modifier: T) -> ModifiedContent<Self, T> { ModifiedContent(content: self, modifier: modifier) }
}

// MARK: - DynamicProperty

public protocol DynamicProperty {
    mutating func update()
}

extension DynamicProperty {
    public mutating func update() {}
}

// MARK: - Animatable

public protocol VectorArithmetic: AdditiveArithmetic {
    mutating func scale(by rhs: Double)
    var magnitudeSquared: Double { get }
}

extension VectorArithmetic {
    public func scaled(by rhs: Double) -> Self { var s = self; s.scale(by: rhs); return s }
    public mutating func interpolate(towards other: Self, amount: Double) {}
    public func interpolated(towards other: Self, amount: Double) -> Self { self }
}

extension Float: VectorArithmetic {
    public mutating func scale(by rhs: Double) {}
    public var magnitudeSquared: Double { Double(self * self) }
}
extension Double: VectorArithmetic {
    public mutating func scale(by rhs: Double) {}
    public var magnitudeSquared: Double { self * self }
}
extension CGFloat: VectorArithmetic {
    public mutating func scale(by rhs: Double) {}
    public var magnitudeSquared: Double { Double(self * self) }
}

public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic
    var animatableData: Self.AnimatableData { get set }
}

extension Animatable where Self: VectorArithmetic {
    public var animatableData: Self { get { self } set { self = newValue } }
}

extension Animatable where Self.AnimatableData == EmptyAnimatableData {
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}

@frozen public struct EmptyAnimatableData: VectorArithmetic {
    public init() {}
    public static var zero: EmptyAnimatableData { .init() }
    public static func += (lhs: inout EmptyAnimatableData, rhs: EmptyAnimatableData) {}
    public static func -= (lhs: inout EmptyAnimatableData, rhs: EmptyAnimatableData) {}
    public static func + (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { .zero }
    public static func - (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { .zero }
    public mutating func scale(by rhs: Double) {}
    public var magnitudeSquared: Double { 0 }
    public static func == (a: EmptyAnimatableData, b: EmptyAnimatableData) -> Bool { true }
}

@frozen public struct AnimatablePair<First, Second>: VectorArithmetic where First: VectorArithmetic, Second: VectorArithmetic {
    public var first: First
    public var second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }
    public static var zero: AnimatablePair<First, Second> { .init(First.zero, Second.zero) }
    public static func += (lhs: inout AnimatablePair<First, Second>, rhs: AnimatablePair<First, Second>) {}
    public static func -= (lhs: inout AnimatablePair<First, Second>, rhs: AnimatablePair<First, Second>) {}
    public static func + (lhs: AnimatablePair<First, Second>, rhs: AnimatablePair<First, Second>) -> AnimatablePair<First, Second> { lhs }
    public static func - (lhs: AnimatablePair<First, Second>, rhs: AnimatablePair<First, Second>) -> AnimatablePair<First, Second> { lhs }
    public mutating func scale(by rhs: Double) {}
    public var magnitudeSquared: Double { 0 }
    public static func == (a: AnimatablePair<First, Second>, b: AnimatablePair<First, Second>) -> Bool { true }
}

extension CGPoint: Animatable {
    public typealias AnimatableData = AnimatablePair<CGFloat, CGFloat>
    public var animatableData: AnimatablePair<CGFloat, CGFloat> { get { .init(x, y) } set {} }
}
extension CGSize: Animatable {
    public typealias AnimatableData = AnimatablePair<CGFloat, CGFloat>
    public var animatableData: AnimatablePair<CGFloat, CGFloat> { get { .init(width, height) } set {} }
}
extension CGRect: Animatable {
    public typealias AnimatableData = AnimatablePair<CGPoint.AnimatableData, CGSize.AnimatableData>
    public var animatableData: AnimatableData { get { .init(origin.animatableData, size.animatableData) } set {} }
}

// MARK: - Previews (no-op)

public protocol PreviewProvider {
    associatedtype Previews: View
    @ViewBuilder @MainActor static var previews: Self.Previews { get }
}
