// SwiftUI stub — App, Scene, Commands, Toolbar, keyboard shortcuts.

// MARK: - App / Scene

@MainActor @preconcurrency public protocol App {
    associatedtype Body: Scene
    @SceneBuilder @MainActor @preconcurrency var body: Self.Body { get }
    @MainActor @preconcurrency init()
}

extension App {
    @MainActor @preconcurrency public static func main() {}
}

@MainActor @preconcurrency public protocol Scene {
    associatedtype Body: Scene
    @SceneBuilder @MainActor @preconcurrency var body: Self.Body { get }
}

extension Never: Scene {}

public struct _StubScene: Scene {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

@resultBuilder public struct SceneBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: Scene { content }
    public static func buildBlock() -> some Scene { _StubScene() }
    public static func buildBlock<Content>(_ content: Content) -> Content where Content: Scene { content }
    @_disfavoredOverload public static func buildBlock<each Content>(_ content: repeat each Content) -> some Scene where repeat each Content: Scene { _StubScene() }
    public static func buildOptional(_ scene: (any Scene & _LimitedAvailabilitySceneMarker)?) -> some Scene { _StubScene() }
    @available(*, unavailable, message: "if statements in a SceneBuilder can only be used with #available clauses")
    public static func buildOptional<S>(_ scene: S?) where S: Scene {}
    public static func buildLimitedAvailability(_ scene: some Scene) -> any Scene & _LimitedAvailabilitySceneMarker { _LimitedScene() }
}
public protocol _LimitedAvailabilitySceneMarker {}
public struct _LimitedScene: Scene, _LimitedAvailabilitySceneMarker {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct WindowGroup<Content>: Scene where Content: View {
    nonisolated public init(id: String, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init(_ title: Text, id: String, @ViewBuilder content: () -> Content) {}
    nonisolated public init(_ titleKey: LocalizedStringKey, id: String, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, id: String, @ViewBuilder content: () -> Content) where S: StringProtocol {}
    nonisolated public init(@ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init(_ title: Text, @ViewBuilder content: () -> Content) {}
    nonisolated public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S: StringProtocol {}
    @MainActor public var body: some Scene { _StubScene() }
}

public struct Window<Content>: Scene where Content: View {
    nonisolated public init(_ title: Text, id: String, @ViewBuilder content: () -> Content) {}
    nonisolated public init(_ titleKey: LocalizedStringKey, id: String, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, id: String, @ViewBuilder content: () -> Content) where S: StringProtocol {}
    @MainActor public var body: some Scene { _StubScene() }
}

/// macOS only.
public struct Settings<Content>: Scene where Content: View {
    nonisolated public init(@ViewBuilder content: () -> Content) {}
    @MainActor public var body: some Scene { _StubScene() }
}

extension Scene {
    nonisolated public func defaultSize(_ size: CGSize) -> some Scene { _StubScene() }
    nonisolated public func defaultSize(width: CGFloat, height: CGFloat) -> some Scene { _StubScene() }
    nonisolated public func defaultPosition(_ position: UnitPoint) -> some Scene { _StubScene() }
    nonisolated public func commands<Content>(@CommandsBuilder content: () -> Content) -> some Scene where Content: Commands { _StubScene() }
    nonisolated public func commandsRemoved() -> some Scene { _StubScene() }
    nonisolated public func windowResizability(_ resizability: WindowResizability) -> some Scene { _StubScene() }
    nonisolated public func windowStyle<S>(_ style: S) -> some Scene where S: WindowStyle { _StubScene() }
    nonisolated public func windowToolbarStyle<S>(_ style: S) -> some Scene where S: WindowToolbarStyle { _StubScene() }
    nonisolated public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some Scene { _StubScene() }
    nonisolated public func environment<T>(_ object: T?) -> some Scene where T: AnyObject, T: Observable { _StubScene() }
    nonisolated public func onChange<V>(of value: V, initial: Bool = false, _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void) -> some Scene where V: Equatable { _StubScene() }
    nonisolated public func onChange<V>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some Scene where V: Equatable { _StubScene() }
}

public struct WindowResizability: Sendable {
    public static var automatic: WindowResizability { .init() }
    public static var contentSize: WindowResizability { .init() }
    public static var contentMinSize: WindowResizability { .init() }
}

public protocol WindowStyle {}
public struct DefaultWindowStyle: WindowStyle { public init() {} }
public struct HiddenTitleBarWindowStyle: WindowStyle { public init() {} }
public struct TitleBarWindowStyle: WindowStyle { public init() {} }
extension WindowStyle where Self == DefaultWindowStyle { public static var automatic: DefaultWindowStyle { .init() } }
extension WindowStyle where Self == HiddenTitleBarWindowStyle { public static var hiddenTitleBar: HiddenTitleBarWindowStyle { .init() } }
extension WindowStyle where Self == TitleBarWindowStyle { public static var titleBar: TitleBarWindowStyle { .init() } }

public protocol WindowToolbarStyle {}
public struct DefaultWindowToolbarStyle: WindowToolbarStyle { public init() {} }
public struct UnifiedWindowToolbarStyle: WindowToolbarStyle { public init() {}; public init(showsTitle: Bool) {} }
public struct UnifiedCompactWindowToolbarStyle: WindowToolbarStyle { public init() {} }
public struct ExpandedWindowToolbarStyle: WindowToolbarStyle { public init() {} }
extension WindowToolbarStyle where Self == DefaultWindowToolbarStyle { public static var automatic: DefaultWindowToolbarStyle { .init() } }
extension WindowToolbarStyle where Self == UnifiedWindowToolbarStyle {
    public static var unified: UnifiedWindowToolbarStyle { .init() }
    public static func unified(showsTitle: Bool) -> UnifiedWindowToolbarStyle { .init(showsTitle: showsTitle) }
}
extension WindowToolbarStyle where Self == UnifiedCompactWindowToolbarStyle { public static var unifiedCompact: UnifiedCompactWindowToolbarStyle { .init() } }
extension WindowToolbarStyle where Self == ExpandedWindowToolbarStyle { public static var expanded: ExpandedWindowToolbarStyle { .init() } }

/// macOS only: bridges an AppKit app delegate into a SwiftUI `App`.
@MainActor @preconcurrency @propertyWrapper public struct NSApplicationDelegateAdaptor<DelegateType>: DynamicProperty where DelegateType: NSObject, DelegateType: NSApplicationDelegate {
    @MainActor @preconcurrency public var wrappedValue: DelegateType { _never() }
    @MainActor @preconcurrency public init(_ delegateType: DelegateType.Type = DelegateType.self) {}
}
extension NSApplicationDelegateAdaptor where DelegateType: Observable {
    @MainActor @preconcurrency public init(_ delegateType: DelegateType.Type = DelegateType.self) {}
    @MainActor @preconcurrency public var projectedValue: Bindable<DelegateType> { _never() }
}

// MARK: - Commands

@MainActor @preconcurrency public protocol Commands {
    associatedtype Body: Commands
    @CommandsBuilder @MainActor @preconcurrency var body: Self.Body { get }
}

extension Never: Commands {}

public struct EmptyCommands: Commands {
    nonisolated public init() {}
    public typealias Body = Never
    public var body: Never { fatalError() }
}

@resultBuilder public struct CommandsBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: Commands { content }
    public static func buildBlock() -> EmptyCommands { EmptyCommands() }
    public static func buildBlock<C>(_ content: C) -> C where C: Commands { content }
    public static func buildIf<Content>(_ content: Content?) -> Content? where Content: Commands { content }
    public static func buildLimitedAvailability(_ content: any Commands) -> some Commands { EmptyCommands() }
    public static func buildLimitedAvailability<C>(_ content: C) -> some Commands where C: Commands { EmptyCommands() }
    // Fixed arity, 2...10 children, as in the SDK.
    public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> some Commands where C0: Commands, C1: Commands { EmptyCommands() }
    public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> some Commands where C0: Commands, C1: Commands, C2: Commands { EmptyCommands() }
    public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> some Commands where C0: Commands, C1: Commands, C2: Commands, C3: Commands { EmptyCommands() }
    public static func buildBlock<C0, C1, C2, C3, C4>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> some Commands where C0: Commands, C1: Commands, C2: Commands, C3: Commands, C4: Commands { EmptyCommands() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> some Commands where C0: Commands, C1: Commands, C2: Commands, C3: Commands, C4: Commands, C5: Commands { EmptyCommands() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> some Commands where C0: Commands, C1: Commands, C2: Commands, C3: Commands, C4: Commands, C5: Commands, C6: Commands { EmptyCommands() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> some Commands where C0: Commands, C1: Commands, C2: Commands, C3: Commands, C4: Commands, C5: Commands, C6: Commands, C7: Commands { EmptyCommands() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> some Commands where C0: Commands, C1: Commands, C2: Commands, C3: Commands, C4: Commands, C5: Commands, C6: Commands, C7: Commands, C8: Commands { EmptyCommands() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> some Commands where C0: Commands, C1: Commands, C2: Commands, C3: Commands, C4: Commands, C5: Commands, C6: Commands, C7: Commands, C8: Commands, C9: Commands { EmptyCommands() }
    public static func buildEither<T, F>(first: T) -> _ConditionalContent<T, F> where T: Commands, F: Commands { _ConditionalContent(storage: .trueContent(first)) }
    public static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F> where T: Commands, F: Commands { _ConditionalContent(storage: .falseContent(second)) }
}

extension Optional: Commands where Wrapped: Commands {
    public typealias Body = Never
}
extension _ConditionalContent: Commands where TrueContent: Commands, FalseContent: Commands {
    public typealias Body = Never
}
extension Commands where Body == Never {
    public var body: Never { fatalError() }
}

public struct CommandGroup<Content>: Commands where Content: View {
    nonisolated public init(before group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {}
    nonisolated public init(after group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {}
    nonisolated public init(replacing group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {}
    @MainActor public var body: some Commands { EmptyCommands() }
}

public struct CommandMenu<Content>: Commands where Content: View {
    nonisolated public init(_ nameKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    nonisolated public init(_ name: Text, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ name: S, @ViewBuilder content: () -> Content) where S: StringProtocol {}
    @MainActor public var body: some Commands { EmptyCommands() }
}

public struct CommandGroupPlacement: Sendable {
    public static let appInfo = CommandGroupPlacement()
    public static let appSettings = CommandGroupPlacement()
    public static let systemServices = CommandGroupPlacement()
    public static let appVisibility = CommandGroupPlacement()
    public static let appTermination = CommandGroupPlacement()
    public static let newItem = CommandGroupPlacement()
    public static let saveItem = CommandGroupPlacement()
    public static let importExport = CommandGroupPlacement()
    public static let printItem = CommandGroupPlacement()
    public static let undoRedo = CommandGroupPlacement()
    public static let pasteboard = CommandGroupPlacement()
    public static let textEditing = CommandGroupPlacement()
    public static let textFormatting = CommandGroupPlacement()
    public static let toolbar = CommandGroupPlacement()
    public static let sidebar = CommandGroupPlacement()
    public static let windowSize = CommandGroupPlacement()
    public static let windowList = CommandGroupPlacement()
    public static let singleWindowList = CommandGroupPlacement()
    public static let windowArrangement = CommandGroupPlacement()
    public static let help = CommandGroupPlacement()
}

public struct SidebarCommands: Commands {
    nonisolated public init() {}
    public var body: some Commands { EmptyCommands() }
}

// MARK: - Keyboard

@frozen public struct EventModifiers: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let capsLock = EventModifiers(rawValue: 1)
    public static let shift = EventModifiers(rawValue: 2)
    public static let control = EventModifiers(rawValue: 4)
    public static let option = EventModifiers(rawValue: 8)
    public static let command = EventModifiers(rawValue: 16)
    public static let numericPad = EventModifiers(rawValue: 32)
    @available(macOS, deprecated: 15.0, message: "Function modifier is reserved for system applications")
    public static let function = EventModifiers(rawValue: 64)
    public static let all = EventModifiers(rawValue: 127)
}

@frozen public struct KeyEquivalent: Sendable, Hashable, ExpressibleByExtendedGraphemeClusterLiteral {
    public static let upArrow = KeyEquivalent("\u{F700}")
    public static let downArrow = KeyEquivalent("\u{F701}")
    public static let leftArrow = KeyEquivalent("\u{F702}")
    public static let rightArrow = KeyEquivalent("\u{F703}")
    public static let escape = KeyEquivalent("\u{1B}")
    public static let delete = KeyEquivalent("\u{8}")
    public static let deleteForward = KeyEquivalent("\u{F728}")
    public static let home = KeyEquivalent("\u{F729}")
    public static let end = KeyEquivalent("\u{F72B}")
    public static let pageUp = KeyEquivalent("\u{F72C}")
    public static let pageDown = KeyEquivalent("\u{F72D}")
    public static let clear = KeyEquivalent("\u{F739}")
    public static let tab = KeyEquivalent("\t")
    public static let space = KeyEquivalent(" ")
    public static let `return` = KeyEquivalent("\r")
    public var character: Character
    public init(_ character: Character) { self.character = character }
    public init(extendedGraphemeClusterLiteral: Character) { character = extendedGraphemeClusterLiteral }
    public typealias ExtendedGraphemeClusterLiteralType = Character
    public typealias UnicodeScalarLiteralType = Character
}

public struct KeyboardShortcut: Sendable, Hashable {
    public enum Localization: Sendable, Hashable {
        case automatic, withoutMirroring, custom
    }
    public static let defaultAction = KeyboardShortcut(.return, modifiers: [])
    public static let cancelAction = KeyboardShortcut(.escape, modifiers: [])
    public var key: KeyEquivalent
    public var modifiers: EventModifiers
    public var localization: KeyboardShortcut.Localization
    public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) { self.key = key; self.modifiers = modifiers; localization = .automatic }
    public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command, localization: KeyboardShortcut.Localization) { self.key = key; self.modifiers = modifiers; self.localization = localization }
}

public struct KeyPress: Sendable {
    public var phase: KeyPress.Phases
    public var key: KeyEquivalent
    public var characters: String
    public var modifiers: EventModifiers

    public struct Phases: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let down = Phases(rawValue: 1)
        public static let `repeat` = Phases(rawValue: 2)
        public static let up = Phases(rawValue: 4)
        public static let all = Phases(rawValue: 7)
    }

    public enum Result: Sendable, Equatable { case handled, ignored }
}

// MARK: - Toolbar

@MainActor @preconcurrency public protocol ToolbarContent {
    associatedtype Body: ToolbarContent
    @ToolbarContentBuilder @MainActor @preconcurrency var body: Self.Body { get }
}

@MainActor @preconcurrency public protocol CustomizableToolbarContent: ToolbarContent where Self.Body: CustomizableToolbarContent {}

extension Never: ToolbarContent, CustomizableToolbarContent {}

extension ToolbarContent where Body == Never {
    public var body: Never { fatalError() }
}

public struct _StubToolbarContent: CustomizableToolbarContent {
    public typealias Body = Never
}

extension Optional: ToolbarContent where Wrapped: ToolbarContent { public typealias Body = Never }
extension Optional: CustomizableToolbarContent where Wrapped: CustomizableToolbarContent {}
extension _ConditionalContent: ToolbarContent where TrueContent: ToolbarContent, FalseContent: ToolbarContent { public typealias Body = Never }
extension _ConditionalContent: CustomizableToolbarContent where TrueContent: CustomizableToolbarContent, FalseContent: CustomizableToolbarContent {}

@resultBuilder public struct ToolbarContentBuilder {
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: ToolbarContent { content }
    public static func buildBlock<Content>(_ content: Content) -> some ToolbarContent where Content: ToolbarContent { _StubToolbarContent() }
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: CustomizableToolbarContent { content }
    public static func buildBlock<Content>(_ content: Content) -> some CustomizableToolbarContent where Content: CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildIf<Content>(_ content: Content?) -> Content? where Content: ToolbarContent { content }
    public static func buildIf<Content>(_ content: Content?) -> Content? where Content: CustomizableToolbarContent { content }
    public static func buildEither<TrueContent, FalseContent>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: ToolbarContent, FalseContent: ToolbarContent { _ConditionalContent(storage: .trueContent(first)) }
    public static func buildEither<TrueContent, FalseContent>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: CustomizableToolbarContent, FalseContent: CustomizableToolbarContent { _ConditionalContent(storage: .trueContent(first)) }
    public static func buildEither<TrueContent, FalseContent>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: ToolbarContent, FalseContent: ToolbarContent { _ConditionalContent(storage: .falseContent(second)) }
    public static func buildEither<TrueContent, FalseContent>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: CustomizableToolbarContent, FalseContent: CustomizableToolbarContent { _ConditionalContent(storage: .falseContent(second)) }
    public static func buildLimitedAvailability(_ content: any ToolbarContent) -> some ToolbarContent { _StubToolbarContent() }
    public static func buildLimitedAvailability<Content>(_ content: Content) -> some ToolbarContent where Content: ToolbarContent { _StubToolbarContent() }
    public static func buildLimitedAvailability(_ content: any CustomizableToolbarContent) -> some CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildLimitedAvailability<Content>(_ content: Content) -> some CustomizableToolbarContent where Content: CustomizableToolbarContent { _StubToolbarContent() }
    // Fixed arity, 2...10 items, as in the SDK.
    public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> some ToolbarContent where C0: ToolbarContent, C1: ToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> some ToolbarContent where C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> some ToolbarContent where C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> some ToolbarContent where C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> some ToolbarContent where C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent, C5: ToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> some ToolbarContent where C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent, C5: ToolbarContent, C6: ToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> some ToolbarContent where C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent, C5: ToolbarContent, C6: ToolbarContent, C7: ToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> some ToolbarContent where C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent, C5: ToolbarContent, C6: ToolbarContent, C7: ToolbarContent, C8: ToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> some ToolbarContent where C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent, C5: ToolbarContent, C6: ToolbarContent, C7: ToolbarContent, C8: ToolbarContent, C9: ToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> some CustomizableToolbarContent where C0: CustomizableToolbarContent, C1: CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> some CustomizableToolbarContent where C0: CustomizableToolbarContent, C1: CustomizableToolbarContent, C2: CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> some CustomizableToolbarContent where C0: CustomizableToolbarContent, C1: CustomizableToolbarContent, C2: CustomizableToolbarContent, C3: CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> some CustomizableToolbarContent where C0: CustomizableToolbarContent, C1: CustomizableToolbarContent, C2: CustomizableToolbarContent, C3: CustomizableToolbarContent, C4: CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> some CustomizableToolbarContent where C0: CustomizableToolbarContent, C1: CustomizableToolbarContent, C2: CustomizableToolbarContent, C3: CustomizableToolbarContent, C4: CustomizableToolbarContent, C5: CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> some CustomizableToolbarContent where C0: CustomizableToolbarContent, C1: CustomizableToolbarContent, C2: CustomizableToolbarContent, C3: CustomizableToolbarContent, C4: CustomizableToolbarContent, C5: CustomizableToolbarContent, C6: CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> some CustomizableToolbarContent where C0: CustomizableToolbarContent, C1: CustomizableToolbarContent, C2: CustomizableToolbarContent, C3: CustomizableToolbarContent, C4: CustomizableToolbarContent, C5: CustomizableToolbarContent, C6: CustomizableToolbarContent, C7: CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> some CustomizableToolbarContent where C0: CustomizableToolbarContent, C1: CustomizableToolbarContent, C2: CustomizableToolbarContent, C3: CustomizableToolbarContent, C4: CustomizableToolbarContent, C5: CustomizableToolbarContent, C6: CustomizableToolbarContent, C7: CustomizableToolbarContent, C8: CustomizableToolbarContent { _StubToolbarContent() }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> some CustomizableToolbarContent where C0: CustomizableToolbarContent, C1: CustomizableToolbarContent, C2: CustomizableToolbarContent, C3: CustomizableToolbarContent, C4: CustomizableToolbarContent, C5: CustomizableToolbarContent, C6: CustomizableToolbarContent, C7: CustomizableToolbarContent, C8: CustomizableToolbarContent, C9: CustomizableToolbarContent { _StubToolbarContent() }
}

public struct ToolbarItem<ID, Content>: ToolbarContent where Content: View {
    public typealias Body = Never
}
extension ToolbarItem where ID == () {
    nonisolated public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
}
extension ToolbarItem: CustomizableToolbarContent where ID == String {
    nonisolated public init(id: String, placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
    nonisolated public init(id: String, placement: ToolbarItemPlacement = .automatic, showsByDefault: Bool, @ViewBuilder content: () -> Content) {}
}

public struct ToolbarItemGroup<Content>: ToolbarContent where Content: View {
    nonisolated public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
}

public struct ToolbarSpacer: ToolbarContent, CustomizableToolbarContent {
    nonisolated public init(_ sizing: SpacerSizing = .flexible, placement: ToolbarItemPlacement = .automatic) {}
    public typealias Body = Never
}
public struct SpacerSizing: Sendable {
    public static let flexible = SpacerSizing()
    public static let fixed = SpacerSizing()
}

public struct ToolbarItemPlacement {
    public static let automatic = ToolbarItemPlacement()
    public static let principal = ToolbarItemPlacement()
    public static let navigation = ToolbarItemPlacement()
    public static let primaryAction = ToolbarItemPlacement()
    public static let secondaryAction = ToolbarItemPlacement()
    public static let status = ToolbarItemPlacement()
    public static let confirmationAction = ToolbarItemPlacement()
    public static let cancellationAction = ToolbarItemPlacement()
    public static let destructiveAction = ToolbarItemPlacement()
    public static func accessoryBar<ID>(id: ID) -> ToolbarItemPlacement where ID: Hashable { .init() }
}

public struct ToolbarPlacement {
    public static var automatic: ToolbarPlacement { .init() }
    public static var windowToolbar: ToolbarPlacement { .init() }
}

public struct ToolbarDefaultItemKind {
    public static let sidebarToggle = ToolbarDefaultItemKind()
    public static let title = ToolbarDefaultItemKind()
    public static let search = ToolbarDefaultItemKind()
}

extension ToolbarContent {
    nonisolated public func hidden(_ hidden: Bool = true) -> some ToolbarContent { _StubToolbarContent() }
}
