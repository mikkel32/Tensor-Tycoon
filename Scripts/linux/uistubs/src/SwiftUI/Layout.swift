// SwiftUI stub — stacks, grids, scroll views, geometry, ForEach and the Layout protocol.

// MARK: - Stacks

@frozen public struct HStack<Content>: View where Content: View {
    nonisolated public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension HStack: Sendable {}

@frozen public struct VStack<Content>: View where Content: View {
    nonisolated public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension VStack: Sendable {}

@frozen public struct ZStack<Content>: View where Content: View {
    nonisolated public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension ZStack: Sendable {}

public struct LazyVStack<Content>: View where Content: View {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct LazyHStack<Content>: View where Content: View {
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct PinnedScrollableViews: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1)
    public static let sectionFooters = PinnedScrollableViews(rawValue: 2)
}

@frozen public struct Spacer: Sendable {
    public var minLength: CGFloat?
    nonisolated public init(minLength: CGFloat? = nil) { self.minLength = minLength }
}
extension Spacer: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct Divider: View, Sendable {
    nonisolated public init() {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}

@frozen public struct ViewThatFits<Content>: View where Content: View {
    public init(in axes: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}

// MARK: - Grids

@frozen public struct Grid<Content> where Content: View {
    nonisolated public init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}
extension Grid: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension Grid: Sendable {}

@frozen public struct GridRow<Content> where Content: View {
    nonisolated public init(alignment: VerticalAlignment? = nil, @ViewBuilder content: () -> Content) {}
}
extension GridRow: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension GridRow: Sendable {}

public struct GridItem: Sendable, Equatable {
    public enum Size: Sendable, Equatable {
        case fixed(_: CGFloat)
        case flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity)
        case adaptive(minimum: CGFloat, maximum: CGFloat = .infinity)
    }
    public var size: GridItem.Size
    public var spacing: CGFloat?
    public var alignment: Alignment?
    public init(_ size: GridItem.Size = .flexible(), spacing: CGFloat? = nil, alignment: Alignment? = nil) {
        self.size = size; self.spacing = spacing; self.alignment = alignment
    }
}

public struct LazyVGrid<Content>: View where Content: View {
    public init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct LazyHGrid<Content>: View where Content: View {
    public init(rows: [GridItem], alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}

// MARK: - ScrollView

public struct ScrollView<Content>: View where Content: View {
    public var content: Content
    public var axes: Axis.Set { [] }
    public var showsIndicators: Bool { true }
    @available(macOS, introduced: 10.15, deprecated: 100000.0, message: "Use the `scrollIndicators(_:axes:)` modifier instead.")
    nonisolated public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) { self.content = content() }
    nonisolated public init(_ axes: Axis.Set = .vertical, @ViewBuilder content: () -> Content) { self.content = content() }
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}

@frozen public struct ScrollViewReader<Content>: View where Content: View {
    public var content: (ScrollViewProxy) -> Content
    nonisolated public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) { self.content = content }
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}

public struct ScrollViewProxy {
    public func scrollTo<ID>(_ id: ID, anchor: UnitPoint? = nil) where ID: Hashable {}
}

public struct ScrollIndicatorVisibility: Equatable, Sendable {
    public static var automatic: ScrollIndicatorVisibility { .init() }
    public static var visible: ScrollIndicatorVisibility { .init() }
    public static var hidden: ScrollIndicatorVisibility { .init() }
    public static var never: ScrollIndicatorVisibility { .init() }
}

// MARK: - Geometry

@frozen public struct GeometryReader<Content>: View where Content: View {
    public var content: (GeometryProxy) -> Content
    nonisolated public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) { self.content = content }
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct GeometryProxy: Sendable {
    public var size: CGSize { .zero }
    public subscript<T>(anchor: Anchor<T>) -> T { _never() }
    public var safeAreaInsets: EdgeInsets { EdgeInsets() }
    @_disfavoredOverload public func frame(in coordinateSpace: CoordinateSpace) -> CGRect { .zero }
    public func frame(in coordinateSpace: some CoordinateSpaceProtocol) -> CGRect { .zero }
    public func bounds(of coordinateSpace: NamedCoordinateSpace) -> CGRect? { nil }
}

@frozen public struct Anchor<Value> {
    @frozen public struct Source {
        public init<T>(_ array: [Anchor<T>.Source]) where Value == [T] {}
    }
}
extension Anchor.Source where Value == CGRect {
    public static func rect(_ r: CGRect) -> Anchor<Value>.Source { _never() }
    public static var bounds: Anchor<CGRect>.Source { _never() }
}
extension Anchor.Source where Value == CGPoint {
    public static func point(_ p: CGPoint) -> Anchor<Value>.Source { _never() }
    public static func unitPoint(_ p: UnitPoint) -> Anchor<Value>.Source { _never() }
    public static var topLeading: Anchor<CGPoint>.Source { _never() }
    public static var top: Anchor<CGPoint>.Source { _never() }
    public static var center: Anchor<CGPoint>.Source { _never() }
    public static var bottom: Anchor<CGPoint>.Source { _never() }
}

public enum CoordinateSpace: Hashable, Sendable {
    case global
    case local
    case named(AnyHashable)
    public var isGlobal: Bool { self == .global }
    public var isLocal: Bool { self == .local }
}

public protocol CoordinateSpaceProtocol {
    var coordinateSpace: CoordinateSpace { get }
}
public struct NamedCoordinateSpace: CoordinateSpaceProtocol, Equatable {
    public var coordinateSpace: CoordinateSpace { .local }
}
public struct LocalCoordinateSpace: CoordinateSpaceProtocol {
    public init() {}
    public var coordinateSpace: CoordinateSpace { .local }
}
public struct GlobalCoordinateSpace: CoordinateSpaceProtocol {
    public init() {}
    public var coordinateSpace: CoordinateSpace { .global }
}
extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
    public static func named(_ name: some Hashable) -> NamedCoordinateSpace { NamedCoordinateSpace() }
    public static var scrollView: NamedCoordinateSpace { NamedCoordinateSpace() }
}
extension CoordinateSpaceProtocol where Self == LocalCoordinateSpace {
    public static var local: LocalCoordinateSpace { .init() }
}
extension CoordinateSpaceProtocol where Self == GlobalCoordinateSpace {
    public static var global: GlobalCoordinateSpace { .init() }
}

// MARK: - ForEach

public struct ForEach<Data, ID, Content> where Data: RandomAccessCollection, ID: Hashable {
    public var data: Data
    public var content: (Data.Element) -> Content
}
extension ForEach: View where Content: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension ForEach where ID == Data.Element.ID, Content: View, Data.Element: Identifiable {
    nonisolated public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) { self.data = data; self.content = content }
}
extension ForEach where Content: View {
    nonisolated public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) { self.data = data; self.content = content }
}
extension ForEach where Data == Range<Int>, ID == Int, Content: View {
    nonisolated public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) { self.data = data; self.content = content }
}
extension ForEach where Content: View {
    /// `ForEach($items) { $item in ... }`
    public init<C>(_ data: Binding<C>, @ViewBuilder content: @escaping (Binding<C.Element>) -> Content)
    where Data == LazyMapSequence<C.Indices, (C.Index, ID)>, ID == C.Element.ID, C: MutableCollection, C: RandomAccessCollection,
          C.Element: Identifiable, C.Index: Hashable { fatalError() }
    public init<C>(_ data: Binding<C>, id: KeyPath<C.Element, ID>, @ViewBuilder content: @escaping (Binding<C.Element>) -> Content)
    where Data == LazyMapSequence<C.Indices, (C.Index, ID)>, C: MutableCollection, C: RandomAccessCollection, C.Index: Hashable { fatalError() }
}
extension ForEach: DynamicViewContent where Content: View {}
extension ForEach: Sendable {}

@MainActor @preconcurrency public protocol DynamicViewContent: View {
    associatedtype Data: Collection
    var data: Self.Data { get }
}

extension DynamicViewContent {
    nonisolated public func onDelete(perform action: Optional<(IndexSet) -> Void>) -> some DynamicViewContent { self }
    nonisolated public func onMove(perform action: Optional<(IndexSet, Int) -> Void>) -> some DynamicViewContent { self }
}

// MARK: - Layout protocol

@preconcurrency public protocol Layout: Sendable, Animatable {
    static var layoutProperties: LayoutProperties { get }
    associatedtype Cache = Void
    typealias Subviews = LayoutSubviews
    func makeCache(subviews: Self.Subviews) -> Self.Cache
    func updateCache(_ cache: inout Self.Cache, subviews: Self.Subviews)
    func spacing(subviews: Self.Subviews, cache: inout Self.Cache) -> ViewSpacing
    func sizeThatFits(proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CGSize
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache)
    func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CGFloat?
    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CGFloat?
}

extension Layout {
    public static var layoutProperties: LayoutProperties { LayoutProperties() }
    public func updateCache(_ cache: inout Self.Cache, subviews: Self.Subviews) {}
    public func spacing(subviews: Self.Subviews, cache: inout Self.Cache) -> ViewSpacing { ViewSpacing() }
    public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CGFloat? { nil }
    public func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CGFloat? { nil }
    @_disfavoredOverload public func callAsFunction<V>(@ViewBuilder _ content: () -> V) -> some View where V: View { _VariadicLayoutView<Self, V>() }
}
extension Layout where Self.Cache == () {
    public func makeCache(subviews: Self.Subviews) -> Self.Cache { () }
}

public struct _VariadicLayoutView<L, Content>: View where L: Layout, Content: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct LayoutProperties: Sendable {
    public init() {}
    public var stackOrientation: Axis?
}

public struct ViewSpacing: Sendable {
    public static let zero = ViewSpacing()
    public init() {}
    public mutating func formUnion(_ other: ViewSpacing, edges: Edge.Set = .all) {}
    public func union(_ other: ViewSpacing, edges: Edge.Set = .all) -> ViewSpacing { self }
    public func distance(to next: ViewSpacing, along axis: Axis) -> CGFloat { 0 }
}

@frozen public struct ProposedViewSize: Equatable, Sendable {
    public var width: CGFloat?
    public var height: CGFloat?
    public static let zero = ProposedViewSize(width: 0, height: 0)
    public static let unspecified = ProposedViewSize(width: nil, height: nil)
    public static let infinity = ProposedViewSize(width: .infinity, height: .infinity)
    public init(width: CGFloat?, height: CGFloat?) { self.width = width; self.height = height }
    public init(_ size: CGSize) { width = size.width; height = size.height }
    public func replacingUnspecifiedDimensions(by size: CGSize = CGSize(width: 10, height: 10)) -> CGSize { size }
}

public struct LayoutSubviews: Equatable, RandomAccessCollection, Sendable {
    public typealias SubSequence = LayoutSubviews
    public typealias Element = LayoutSubview
    public typealias Index = Int
    public var layoutDirection: LayoutDirection
    public var startIndex: Int { 0 }
    public var endIndex: Int { 0 }
    public subscript(index: Int) -> LayoutSubviews.Element { _never() }
    public subscript(bounds: Range<Int>) -> LayoutSubviews { self }
    public subscript<S>(indices: S) -> LayoutSubviews where S: Sequence, S.Element == Int { self }
}

public struct LayoutSubview: Equatable, Sendable {
    public subscript<K>(key: K.Type) -> K.Value where K: LayoutValueKey { K.defaultValue }
    public var priority: Double { 0 }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { .zero }
    public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions { _never() }
    public var spacing: ViewSpacing { ViewSpacing() }
    public func place(at position: CGPoint, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) {}
}

public protocol LayoutValueKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
}

@frozen public struct AnyLayout: Layout {
    public init<L>(_ layout: L) where L: Layout {}
    public typealias Cache = Void
    public typealias AnimatableData = EmptyAnimatableData
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { .zero }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {}
}

@frozen public struct HStackLayout: Layout {
    public var alignment: VerticalAlignment
    public var spacing: CGFloat?
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) { self.alignment = alignment; self.spacing = spacing }
    public typealias Cache = Void
    public typealias AnimatableData = EmptyAnimatableData
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { .zero }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {}
}

@frozen public struct VStackLayout: Layout {
    public var alignment: HorizontalAlignment
    public var spacing: CGFloat?
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil) { self.alignment = alignment; self.spacing = spacing }
    public typealias Cache = Void
    public typealias AnimatableData = EmptyAnimatableData
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { .zero }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {}
}
