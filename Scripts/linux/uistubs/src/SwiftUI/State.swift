// SwiftUI stub — property wrappers (State, Binding, Environment, Bindable, AppStorage, FocusState, ...) and
// EnvironmentValues.

// MARK: - State

@frozen @propertyWrapper public struct State<Value>: DynamicProperty {
    public init(wrappedValue value: Value) {}
    public init(initialValue value: Value) {}
    public var wrappedValue: Value { get { _never() } nonmutating set {} }
    public var projectedValue: Binding<Value> { _never() }
}
extension State: Sendable where Value: Sendable {}
extension State where Value: ExpressibleByNilLiteral {
    public init() {}
}

// MARK: - Binding

@frozen @propertyWrapper @dynamicMemberLookup public struct Binding<Value> {
    public var transaction: Transaction { get { Transaction() } set {} }
    @preconcurrency public init(@_inheritActorContext get: @escaping @isolated(any) @Sendable () -> Value,
                                @_inheritActorContext set: @escaping @isolated(any) @Sendable (Value) -> Void) {}
    @preconcurrency public init(@_inheritActorContext get: @escaping @isolated(any) @Sendable () -> Value,
                                @_inheritActorContext set: @escaping @isolated(any) @Sendable (Value, Transaction) -> Void) {}
    public static func constant(_ value: Value) -> Binding<Value> { _never() }
    public var wrappedValue: Value { get { _never() } nonmutating set {} }
    public var projectedValue: Binding<Value> { self }
    public init(projectedValue: Binding<Value>) {}
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> { _never() }
    public func transaction(_ transaction: Transaction) -> Binding<Value> { self }
    public func animation(_ animation: Animation? = .default) -> Binding<Value> { self }
}
extension Binding: @unchecked Sendable where Value: Sendable {}
extension Binding: Identifiable where Value: Identifiable {
    public var id: Value.ID { _never() }
    public typealias ID = Value.ID
}
extension Binding: Sequence where Value: MutableCollection {
    public typealias Element = Binding<Value.Element>
    public typealias Iterator = IndexingIterator<Binding<Value>>
    public typealias SubSequence = Slice<Binding<Value>>
}
extension Binding: Collection where Value: MutableCollection {
    public typealias Index = Value.Index
    public typealias Indices = Value.Indices
    public var startIndex: Binding<Value>.Index { _never() }
    public var endIndex: Binding<Value>.Index { _never() }
    public var indices: Value.Indices { _never() }
    public func index(after i: Binding<Value>.Index) -> Binding<Value>.Index { _never() }
    public func formIndex(after i: inout Binding<Value>.Index) {}
    public subscript(position: Binding<Value>.Index) -> Binding<Value>.Element { _never() }
}
extension Binding: BidirectionalCollection where Value: BidirectionalCollection, Value: MutableCollection {
    public func index(before i: Binding<Value>.Index) -> Binding<Value>.Index { _never() }
    public func formIndex(before i: inout Binding<Value>.Index) {}
}
extension Binding: RandomAccessCollection where Value: MutableCollection, Value: RandomAccessCollection {}
extension Binding: DynamicProperty {}
extension Binding {
    public init<V>(_ base: Binding<V>) where Value == V? {}
    public init?(_ base: Binding<Value?>) { return nil }
    public init<V>(_ base: Binding<V>) where Value == AnyHashable, V: Hashable {}
}

// MARK: - Transaction / animation helpers

public struct Transaction {
    public init() {}
    public init(animation: Animation?) {}
    public var animation: Animation?
    public var disablesAnimations: Bool = false
    public var isContinuous: Bool = false
}

public func withTransaction<Result>(_ transaction: Transaction, _ body: () throws -> Result) rethrows -> Result { try body() }

public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result { try body() }

public func withAnimation<Result>(_ animation: Animation? = .default, completionCriteria: AnimationCompletionCriteria = .logicallyComplete,
                                  _ body: () throws -> Result, completion: @escaping () -> Void) rethrows -> Result { try body() }

public struct AnimationCompletionCriteria: Hashable, Sendable {
    public static let logicallyComplete = AnimationCompletionCriteria()
    public static let removed = AnimationCompletionCriteria()
}

// MARK: - Environment

@frozen @propertyWrapper public struct Environment<Value>: DynamicProperty {
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {}
    public var wrappedValue: Value { _never() }
}
extension Environment: Sendable where Value: Sendable {}
extension Environment {
    public init(_ objectType: Value.Type) where Value: AnyObject, Value: Observable {}
    public init<T>(_ objectType: T.Type) where Value == T?, T: AnyObject, T: Observable {}
}

public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
}

public struct EnvironmentValues: CustomStringConvertible {
    public init() {}
    public var description: String { "" }
    public subscript<K>(key: K.Type) -> K.Value where K: EnvironmentKey { get { K.defaultValue } set {} }

    public var accessibilityReduceMotion: Bool { false }
    public var accessibilityReduceTransparency: Bool { false }
    public var accessibilityDifferentiateWithoutColor: Bool { false }
    public var accessibilityInvertColors: Bool { false }
    public var accessibilityEnabled: Bool { get { false } set {} }
    public var accessibilityVoiceOverEnabled: Bool { false }
    public var colorScheme: ColorScheme { get { .light } set {} }
    public var colorSchemeContrast: ColorSchemeContrast { .standard }
    public var layoutDirection: LayoutDirection { get { .leftToRight } set {} }
    public var locale: Locale { get { .current } set {} }
    public var calendar: Calendar { get { .current } set {} }
    public var timeZone: TimeZone { get { .current } set {} }
    public var font: Font? { get { nil } set {} }
    public var lineLimit: Int? { get { nil } set {} }
    public var multilineTextAlignment: TextAlignment { get { .leading } set {} }
    public var dynamicTypeSize: DynamicTypeSize { get { .large } set {} }
    public var controlSize: ControlSize { get { .regular } set {} }
    public var isEnabled: Bool { get { true } set {} }
    public var isFocused: Bool { false }
    public var displayScale: CGFloat { get { 2 } set {} }
    public var pixelLength: CGFloat { 0.5 }
    public var openURL: OpenURLAction { get { OpenURLAction(handler: { _ in .handled }) } set {} }
    public var openWindow: OpenWindowAction { _never() }
    public var dismissWindow: DismissWindowAction { _never() }
    public var dismiss: DismissAction { _never() }
    public var isPresented: Bool { false }
    public var scenePhase: ScenePhase { get { .active } set {} }
    public var redactionReasons: RedactionReasons { get { [] } set {} }
    public var isSearching: Bool { false }
    public var horizontalSizeClass: UserInterfaceSizeClass? { get { nil } set {} }
    public var verticalSizeClass: UserInterfaceSizeClass? { get { nil } set {} }
    public var backgroundStyle: AnyShapeStyle? { get { nil } set {} }
    public var supportsMultipleWindows: Bool { true }
    public var undoManager: UndoManager? { nil }
}

public enum ScenePhase: Comparable, Hashable, Sendable { case background, inactive, active }
public enum UserInterfaceSizeClass: Hashable, Sendable { case compact, regular }

public struct RedactionReasons: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let placeholder = RedactionReasons(rawValue: 1)
    public static let privacy = RedactionReasons(rawValue: 2)
    public static let invalidated = RedactionReasons(rawValue: 4)
}

@MainActor @preconcurrency public struct DismissAction {
    @MainActor @preconcurrency public func callAsFunction() {}
}

@MainActor @preconcurrency public struct OpenURLAction {
    public struct Result: Sendable {
        public static let handled = Result()
        public static let discarded = Result()
        public static let systemAction = Result()
        public static func systemAction(_ url: URL) -> Result { Result() }
    }
    @preconcurrency public init(handler: @escaping @MainActor @Sendable (URL) -> OpenURLAction.Result) {}
    @MainActor @preconcurrency public func callAsFunction(_ url: URL) {}
    @MainActor @preconcurrency public func callAsFunction(_ url: URL, completion: @escaping (_ accepted: Bool) -> Void) {}
}

@MainActor @preconcurrency public struct OpenWindowAction {
    @MainActor @preconcurrency public func callAsFunction(id: String) {}
    @MainActor @preconcurrency public func callAsFunction<D>(value: D) where D: Decodable, D: Encodable, D: Hashable {}
    @MainActor @preconcurrency public func callAsFunction<D>(id: String, value: D) where D: Decodable, D: Encodable, D: Hashable {}
}

@MainActor @preconcurrency public struct DismissWindowAction {
    @MainActor @preconcurrency public func callAsFunction() {}
    @MainActor @preconcurrency public func callAsFunction(id: String) {}
}

// MARK: - Bindable

@dynamicMemberLookup @propertyWrapper public struct Bindable<Value> {
    public var wrappedValue: Value
    public var projectedValue: Bindable<Value> { self }
    @available(*, unavailable, message: "The wrapped value must be an object that conforms to Observable")
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    @available(*, unavailable, message: "The wrapped value must be an object that conforms to Observable")
    public init(projectedValue: Bindable<Value>) { wrappedValue = projectedValue.wrappedValue }
}
extension Bindable where Value: AnyObject {
    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> { _never() }
}
extension Bindable where Value: AnyObject, Value: Observable {
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(_ wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(projectedValue: Bindable<Value>) { wrappedValue = projectedValue.wrappedValue }
}
extension Bindable: Identifiable where Value: Identifiable {
    public var id: Value.ID { wrappedValue.id }
    public typealias ID = Value.ID
}
extension Bindable: Sendable where Value: Sendable {}
extension Bindable: DynamicProperty {}

// MARK: - AppStorage / SceneStorage

@frozen @propertyWrapper public struct AppStorage<Value>: DynamicProperty {
    internal init(_stub: Void) {}
    public var wrappedValue: Value { get { _never() } nonmutating set {} }
    public var projectedValue: Binding<Value> { _never() }
}
extension AppStorage: Sendable where Value: Sendable {}
extension AppStorage {
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Bool {}
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Int {}
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Double {}
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == String {}
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == URL {}
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Date {}
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Data {}
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == Int {}
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == String {}
}
extension AppStorage where Value: ExpressibleByNilLiteral {
    public init(_ key: String, store: UserDefaults? = nil) where Value == Bool? {}
    public init(_ key: String, store: UserDefaults? = nil) where Value == Int? {}
    public init(_ key: String, store: UserDefaults? = nil) where Value == Double? {}
    public init(_ key: String, store: UserDefaults? = nil) where Value == String? {}
    public init(_ key: String, store: UserDefaults? = nil) where Value == URL? {}
    public init(_ key: String, store: UserDefaults? = nil) where Value == Date? {}
    public init(_ key: String, store: UserDefaults? = nil) where Value == Data? {}
}
extension AppStorage {
    public init<R>(_ key: String, store: UserDefaults? = nil) where Value == R?, R: RawRepresentable, R.RawValue == String {}
    public init<R>(_ key: String, store: UserDefaults? = nil) where Value == R?, R: RawRepresentable, R.RawValue == Int {}
}

@frozen @propertyWrapper public struct SceneStorage<Value>: DynamicProperty {
    public var wrappedValue: Value { get { _never() } nonmutating set {} }
    public var projectedValue: Binding<Value> { _never() }
    public init(wrappedValue: Value, _ key: String) where Value == Bool {}
    public init(wrappedValue: Value, _ key: String) where Value == Int {}
    public init(wrappedValue: Value, _ key: String) where Value == Double {}
    public init(wrappedValue: Value, _ key: String) where Value == String {}
    public init(wrappedValue: Value, _ key: String) where Value: RawRepresentable, Value.RawValue == String {}
}

// MARK: - FocusState / Namespace / ScaledMetric

@frozen @propertyWrapper public struct FocusState<Value>: DynamicProperty where Value: Hashable {
    @frozen @propertyWrapper public struct Binding {
        internal init(_stub: Void) {}
        public var wrappedValue: Value { get { _never() } nonmutating set {} }
        public var projectedValue: FocusState<Value>.Binding { self }
    }
    public var wrappedValue: Value { get { _never() } nonmutating set {} }
    public var projectedValue: FocusState<Value>.Binding { _never() }
    public init() where Value == Bool {}
    public init<T>() where Value == T?, T: Hashable {}
}
extension FocusState: Sendable {}
extension FocusState.Binding: Sendable {}

@frozen @propertyWrapper public struct Namespace: DynamicProperty, Sendable {
    public init() {}
    public var wrappedValue: Namespace.ID { ID() }
    @frozen public struct ID: Hashable, Sendable {}
}

@propertyWrapper public struct ScaledMetric<Value>: DynamicProperty where Value: BinaryFloatingPoint {
    public init(wrappedValue: Value, relativeTo textStyle: Font.TextStyle) {}
    public init(wrappedValue: Value) {}
    public var wrappedValue: Value { _never() }
}
extension ScaledMetric: Sendable where Value: Sendable {}

// MARK: - Preferences

public protocol PreferenceKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
    static func reduce(value: inout Self.Value, nextValue: () -> Self.Value)
}
extension PreferenceKey where Self.Value: ExpressibleByNilLiteral {
    public static var defaultValue: Self.Value { nil }
}
