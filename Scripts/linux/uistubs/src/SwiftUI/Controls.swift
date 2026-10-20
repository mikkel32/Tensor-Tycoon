// SwiftUI stub — controls (Button, Toggle, Picker, Slider, Stepper, TextField, Menu, ...), their styles, and
// containers (List, Section, Form, Table, NavigationSplitView, DisclosureGroup, ...).
// Only styles available on macOS are declared.

// MARK: - Button

public struct ButtonRole: Equatable, Sendable {
    public static let destructive = ButtonRole()
    public static let cancel = ButtonRole()
    public static let confirm = ButtonRole()
    public static let close = ButtonRole()
}

public struct Button<Label>: View where Label: View {
    @preconcurrency nonisolated public init(action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {}
    @preconcurrency nonisolated public init(role: ButtonRole?, action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}

extension Button where Label == Text {
    @preconcurrency nonisolated public init(_ titleKey: LocalizedStringKey, action: @escaping @MainActor () -> Void) {}
    @preconcurrency @_disfavoredOverload nonisolated public init<S>(_ title: S, action: @escaping @MainActor () -> Void) where S: StringProtocol {}
    @preconcurrency nonisolated public init(_ titleKey: LocalizedStringKey, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
    @preconcurrency @_disfavoredOverload nonisolated public init<S>(_ title: S, role: ButtonRole?, action: @escaping @MainActor () -> Void) where S: StringProtocol {}
}

extension Button where Label == SwiftUI.Label<Text, Image> {
    @preconcurrency nonisolated public init(_ titleKey: LocalizedStringKey, systemImage: String, action: @escaping @MainActor () -> Void) {}
    @preconcurrency @_disfavoredOverload nonisolated public init<S>(_ title: S, systemImage: String, action: @escaping @MainActor () -> Void) where S: StringProtocol {}
    @preconcurrency nonisolated public init(_ titleKey: LocalizedStringKey, systemImage: String, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
    @preconcurrency @_disfavoredOverload nonisolated public init<S>(_ title: S, systemImage: String, role: ButtonRole?, action: @escaping @MainActor () -> Void) where S: StringProtocol {}
}

extension Button where Label == PrimitiveButtonStyleConfiguration.Label {
    nonisolated public init(_ configuration: PrimitiveButtonStyleConfiguration) {}
}

@MainActor @preconcurrency public protocol ButtonStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Self.Configuration) -> Self.Body
    typealias Configuration = ButtonStyleConfiguration
}

public struct ButtonStyleConfiguration {
    public struct Label: View { public typealias Body = Never; public var body: Never { fatalError() } }
    public let role: ButtonRole?
    public let label: ButtonStyleConfiguration.Label
    public let isPressed: Bool
}

@MainActor @preconcurrency public protocol PrimitiveButtonStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Self.Configuration) -> Self.Body
    typealias Configuration = PrimitiveButtonStyleConfiguration
}

public struct PrimitiveButtonStyleConfiguration {
    public struct Label: View { public typealias Body = Never; public var body: Never { fatalError() } }
    public let role: ButtonRole?
    public let label: PrimitiveButtonStyleConfiguration.Label
    public func trigger() {}
}

public struct DefaultButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct PlainButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct BorderlessButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct BorderedButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct BorderedProminentButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
/// macOS only.
public struct LinkButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryBarButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryBarActionButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct GlassButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct GlassProminentButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }

extension PrimitiveButtonStyle where Self == DefaultButtonStyle { public static var automatic: DefaultButtonStyle { .init() } }
extension PrimitiveButtonStyle where Self == PlainButtonStyle { public static var plain: PlainButtonStyle { .init() } }
extension PrimitiveButtonStyle where Self == BorderlessButtonStyle { public static var borderless: BorderlessButtonStyle { .init() } }
extension PrimitiveButtonStyle where Self == BorderedButtonStyle { public static var bordered: BorderedButtonStyle { .init() } }
extension PrimitiveButtonStyle where Self == BorderedProminentButtonStyle { public static var borderedProminent: BorderedProminentButtonStyle { .init() } }
extension PrimitiveButtonStyle where Self == LinkButtonStyle { public static var link: LinkButtonStyle { .init() } }
extension PrimitiveButtonStyle where Self == AccessoryBarButtonStyle { public static var accessoryBar: AccessoryBarButtonStyle { .init() } }
extension PrimitiveButtonStyle where Self == AccessoryBarActionButtonStyle { public static var accessoryBarAction: AccessoryBarActionButtonStyle { .init() } }
extension PrimitiveButtonStyle where Self == GlassButtonStyle {
    public static var glass: GlassButtonStyle { .init() }
}
extension PrimitiveButtonStyle where Self == GlassProminentButtonStyle { public static var glassProminent: GlassProminentButtonStyle { .init() } }

public struct ButtonRepeatBehavior: Hashable, Sendable {
    public static let automatic = ButtonRepeatBehavior()
    public static let enabled = ButtonRepeatBehavior()
    public static let disabled = ButtonRepeatBehavior()
}

// MARK: - Toggle

public struct Toggle<Label>: View where Label: View {
    nonisolated public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {}
    nonisolated public init<C>(sources: C, isOn: KeyPath<C.Element, Binding<Bool>>, @ViewBuilder label: () -> Label) where C: RandomAccessCollection {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension Toggle where Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, isOn: Binding<Bool>) where S: StringProtocol {}
}
extension Toggle where Label == SwiftUI.Label<Text, Image> {
    nonisolated public init(_ titleKey: LocalizedStringKey, systemImage: String, isOn: Binding<Bool>) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, systemImage: String, isOn: Binding<Bool>) where S: StringProtocol {}
}
extension Toggle where Label == ToggleStyleConfiguration.Label {
    nonisolated public init(_ configuration: ToggleStyleConfiguration) {}
}

@MainActor @preconcurrency public protocol ToggleStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Self.Configuration) -> Self.Body
    typealias Configuration = ToggleStyleConfiguration
}
public struct ToggleStyleConfiguration {
    public struct Label: View { public typealias Body = Never; public var body: Never { fatalError() } }
    public let label: ToggleStyleConfiguration.Label
    @Binding public var isOn: Bool
    public var isMixed: Bool
}
public struct DefaultToggleStyle: ToggleStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct SwitchToggleStyle: ToggleStyle { public init() {}; public init(tint: Color) {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
/// macOS only.
public struct CheckboxToggleStyle: ToggleStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct ButtonToggleStyle: ToggleStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
extension ToggleStyle where Self == DefaultToggleStyle { public static var automatic: DefaultToggleStyle { .init() } }
extension ToggleStyle where Self == SwitchToggleStyle { public static var `switch`: SwitchToggleStyle { .init() } }
extension ToggleStyle where Self == CheckboxToggleStyle { public static var checkbox: CheckboxToggleStyle { .init() } }
extension ToggleStyle where Self == ButtonToggleStyle { public static var button: ButtonToggleStyle { .init() } }

// MARK: - Picker

public struct Picker<Label, SelectionValue, Content>: View where Label: View, SelectionValue: Hashable, Content: View {
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension Picker {
    nonisolated public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    nonisolated public init<C>(sources: C, selection: KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) where C: RandomAccessCollection {}
    nonisolated public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> some View) {}
    @available(macOS, introduced: 10.15, deprecated: 100000.0, message: "Use Picker.init(selection:content:label:) instead.")
    nonisolated public init(selection: Binding<SelectionValue>, label: Label, @ViewBuilder content: () -> Content) {}
}
extension Picker where Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) where S: StringProtocol {}
    nonisolated public init<C>(_ titleKey: LocalizedStringKey, sources: C, selection: KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content) where C: RandomAccessCollection {}
    nonisolated public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder currentValueLabel: () -> some View) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder currentValueLabel: () -> some View) where S: StringProtocol {}
}
extension Picker where Label == SwiftUI.Label<Text, Image> {
    nonisolated public init(_ titleKey: LocalizedStringKey, systemImage: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, systemImage: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) where S: StringProtocol {}
}

@MainActor @preconcurrency public protocol PickerStyle {}
public struct DefaultPickerStyle: PickerStyle { public init() {} }
public struct SegmentedPickerStyle: PickerStyle { public init() {} }
public struct MenuPickerStyle: PickerStyle { public init() {} }
public struct InlinePickerStyle: PickerStyle { public init() {} }
/// macOS only.
public struct RadioGroupPickerStyle: PickerStyle { public init() {} }
public struct PalettePickerStyle: PickerStyle { public init() {} }
extension PickerStyle where Self == DefaultPickerStyle { public static var automatic: DefaultPickerStyle { .init() } }
extension PickerStyle where Self == SegmentedPickerStyle { public static var segmented: SegmentedPickerStyle { .init() } }
extension PickerStyle where Self == MenuPickerStyle { public static var menu: MenuPickerStyle { .init() } }
extension PickerStyle where Self == InlinePickerStyle { public static var inline: InlinePickerStyle { .init() } }
extension PickerStyle where Self == RadioGroupPickerStyle { public static var radioGroup: RadioGroupPickerStyle { .init() } }
extension PickerStyle where Self == PalettePickerStyle { public static var palette: PalettePickerStyle { .init() } }

// MARK: - Slider

public struct Slider<Label, ValueLabel>: View where Label: View, ValueLabel: View {
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension Slider {
    nonisolated public init<V>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {}
    nonisolated public init<V>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {}
}
extension Slider where ValueLabel == EmptyView {
    nonisolated public init<V>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {}
    nonisolated public init<V>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {}
}
extension Slider where Label == EmptyView, ValueLabel == EmptyView {
    nonisolated public init<V>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {}
    nonisolated public init<V>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {}
}

// MARK: - Stepper

public struct Stepper<Label>: View where Label: View {
    nonisolated public init(@ViewBuilder label: () -> Label, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension Stepper {
    nonisolated public init<V>(value: Binding<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: Strideable {}
    nonisolated public init<V>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: Strideable {}
    @_disfavoredOverload nonisolated public init(onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }, @ViewBuilder label: () -> Label) {}
    @_disfavoredOverload nonisolated public init<V>(value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, @ViewBuilder label: () -> Label) where V: Strideable {}
    @_disfavoredOverload nonisolated public init<V>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }, @ViewBuilder label: () -> Label) where V: Strideable {}
}
extension Stepper where Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where S: StringProtocol {}
    nonisolated public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: Strideable {}
    @_disfavoredOverload nonisolated public init<S, V>(_ title: S, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where S: StringProtocol, V: Strideable {}
    nonisolated public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V: Strideable {}
    @_disfavoredOverload nonisolated public init<S, V>(_ title: S, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where S: StringProtocol, V: Strideable {}
}

// MARK: - TextField / SecureField

public struct TextField<Label>: View where Label: View {
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension TextField where Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, text: Binding<String>) where S: StringProtocol {}
    nonisolated public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, text: Binding<String>, prompt: Text?) where S: StringProtocol {}
    nonisolated public init(_ titleKey: LocalizedStringKey, text: Binding<String>, axis: Axis) {}
    nonisolated public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?, axis: Axis) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, text: Binding<String>, axis: Axis) where S: StringProtocol {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, text: Binding<String>, prompt: Text?, axis: Axis) where S: StringProtocol {}
    nonisolated public init(_ titleKey: LocalizedStringKey, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void = { _ in }, onCommit: @escaping () -> Void = {}) {}
    nonisolated public init<F>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) where F: ParseableFormatStyle, F.FormatOutput == String {}
    @_disfavoredOverload nonisolated public init<S, F>(_ title: S, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) where S: StringProtocol, F: ParseableFormatStyle, F.FormatOutput == String {}
    nonisolated public init<F>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil) where F: ParseableFormatStyle, F.FormatOutput == String {}
    nonisolated public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter) {}
    @_disfavoredOverload nonisolated public init<S, V>(_ title: S, value: Binding<V>, formatter: Formatter) where S: StringProtocol {}
}
extension TextField {
    nonisolated public init(text: Binding<String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) {}
    nonisolated public init(text: Binding<String>, prompt: Text? = nil, axis: Axis, @ViewBuilder label: () -> Label) {}
    nonisolated public init<F>(value: Binding<F.FormatInput>, format: F, prompt: Text? = nil, @ViewBuilder label: () -> Label) where F: ParseableFormatStyle, F.FormatOutput == String {}
}

public struct SecureField<Label>: View where Label: View {
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension SecureField where Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, text: Binding<String>) where S: StringProtocol {}
    nonisolated public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {}
}

@MainActor @preconcurrency public protocol TextFieldStyle {}
public struct DefaultTextFieldStyle: TextFieldStyle { public init() {} }
public struct PlainTextFieldStyle: TextFieldStyle { public init() {} }
public struct RoundedBorderTextFieldStyle: TextFieldStyle { public init() {} }
/// macOS only.
public struct SquareBorderTextFieldStyle: TextFieldStyle { public init() {} }
extension TextFieldStyle where Self == DefaultTextFieldStyle { public static var automatic: DefaultTextFieldStyle { .init() } }
extension TextFieldStyle where Self == PlainTextFieldStyle { public static var plain: PlainTextFieldStyle { .init() } }
extension TextFieldStyle where Self == RoundedBorderTextFieldStyle { public static var roundedBorder: RoundedBorderTextFieldStyle { .init() } }
extension TextFieldStyle where Self == SquareBorderTextFieldStyle { public static var squareBorder: SquareBorderTextFieldStyle { .init() } }

public struct SubmitTriggers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let text = SubmitTriggers(rawValue: 1)
    public static let search = SubmitTriggers(rawValue: 2)
}

public protocol TextSelectability {
    static var allowsSelection: Bool { get }
}
public struct EnabledTextSelectability: TextSelectability { public static var allowsSelection: Bool { true } }
public struct DisabledTextSelectability: TextSelectability { public static var allowsSelection: Bool { false } }
extension TextSelectability where Self == EnabledTextSelectability { public static var enabled: EnabledTextSelectability { .init() } }
extension TextSelectability where Self == DisabledTextSelectability { public static var disabled: DisabledTextSelectability { .init() } }

// MARK: - Menu

public struct Menu<Label, Content>: View where Label: View, Content: View {
    nonisolated public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    nonisolated public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, primaryAction: @escaping () -> Void) {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension Menu where Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S: StringProtocol {}
    nonisolated public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Void) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Void) where S: StringProtocol {}
}
extension Menu where Label == SwiftUI.Label<Text, Image> {
    nonisolated public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, systemImage: String, @ViewBuilder content: () -> Content) where S: StringProtocol {}
}

@MainActor @preconcurrency public protocol MenuStyle {}
public struct DefaultMenuStyle: MenuStyle { public init() {} }
public struct ButtonMenuStyle: MenuStyle { public init() {} }
/// macOS only.
public struct BorderlessButtonMenuStyle: MenuStyle { public init() {} }
/// macOS only.
public struct BorderedButtonMenuStyle: MenuStyle { public init() {} }
extension MenuStyle where Self == DefaultMenuStyle { public static var automatic: DefaultMenuStyle { .init() } }
extension MenuStyle where Self == ButtonMenuStyle { public static var button: ButtonMenuStyle { .init() } }
extension MenuStyle where Self == BorderlessButtonMenuStyle { public static var borderlessButton: BorderlessButtonMenuStyle { .init() } }
extension MenuStyle where Self == BorderedButtonMenuStyle { public static var borderedButton: BorderedButtonMenuStyle { .init() } }

// MARK: - DisclosureGroup

public struct DisclosureGroup<Label, Content>: View where Label: View, Content: View {
    nonisolated public init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) {}
    nonisolated public init(isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension DisclosureGroup where Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {}
    nonisolated public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ label: S, @ViewBuilder content: @escaping () -> Content) where S: StringProtocol {}
    @_disfavoredOverload nonisolated public init<S>(_ label: S, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) where S: StringProtocol {}
}

// MARK: - ProgressView / Gauge

public struct ProgressView<Label, CurrentValueLabel>: View where Label: View, CurrentValueLabel: View {
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension ProgressView where CurrentValueLabel == EmptyView {
    nonisolated public init() where Label == EmptyView {}
    nonisolated public init(@ViewBuilder label: () -> Label) {}
    nonisolated public init(_ titleKey: LocalizedStringKey) where Label == Text {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S) where Label == Text, S: StringProtocol {}
}
extension ProgressView {
    nonisolated public init<V>(value: V?, total: V = 1.0) where Label == EmptyView, CurrentValueLabel == EmptyView, V: BinaryFloatingPoint {}
    nonisolated public init<V>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label) where CurrentValueLabel == EmptyView, V: BinaryFloatingPoint {}
    nonisolated public init<V>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) where V: BinaryFloatingPoint {}
    nonisolated public init<V>(_ titleKey: LocalizedStringKey, value: V?, total: V = 1.0) where Label == Text, CurrentValueLabel == EmptyView, V: BinaryFloatingPoint {}
    @_disfavoredOverload nonisolated public init<S, V>(_ title: S, value: V?, total: V = 1.0) where Label == Text, CurrentValueLabel == EmptyView, S: StringProtocol, V: BinaryFloatingPoint {}
    nonisolated public init(_ progress: Progress) where Label == EmptyView, CurrentValueLabel == EmptyView {}
    nonisolated public init(timerInterval: ClosedRange<Date>, countsDown: Bool = true) where Label == EmptyView, CurrentValueLabel == EmptyView {}
}

@MainActor @preconcurrency public protocol ProgressViewStyle {}
public struct DefaultProgressViewStyle: ProgressViewStyle { public init() {} }
public struct LinearProgressViewStyle: ProgressViewStyle { public init() {}; public init(tint: Color) {} }
public struct CircularProgressViewStyle: ProgressViewStyle { public init() {}; public init(tint: Color) {} }
extension ProgressViewStyle where Self == DefaultProgressViewStyle { public static var automatic: DefaultProgressViewStyle { .init() } }
extension ProgressViewStyle where Self == LinearProgressViewStyle { public static var linear: LinearProgressViewStyle { .init() } }
extension ProgressViewStyle where Self == CircularProgressViewStyle { public static var circular: CircularProgressViewStyle { .init() } }

public struct Gauge<Label, CurrentValueLabel, BoundsLabel, MarkedValueLabels>: View where Label: View, CurrentValueLabel: View, BoundsLabel: View, MarkedValueLabels: View {
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension Gauge {
    nonisolated public init<V>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label) where CurrentValueLabel == EmptyView, BoundsLabel == EmptyView, MarkedValueLabels == EmptyView, V: BinaryFloatingPoint {}
    nonisolated public init<V>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) where BoundsLabel == EmptyView, MarkedValueLabels == EmptyView, V: BinaryFloatingPoint {}
    nonisolated public init<V>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel, @ViewBuilder minimumValueLabel: () -> BoundsLabel, @ViewBuilder maximumValueLabel: () -> BoundsLabel) where MarkedValueLabels == EmptyView, V: BinaryFloatingPoint {}
}

@MainActor @preconcurrency public protocol GaugeStyle {}
public struct DefaultGaugeStyle: GaugeStyle { public init() {} }
public struct LinearCapacityGaugeStyle: GaugeStyle { public init() {} }
public struct AccessoryCircularGaugeStyle: GaugeStyle { public init() {} }
public struct AccessoryCircularCapacityGaugeStyle: GaugeStyle { public init() {} }
public struct AccessoryLinearGaugeStyle: GaugeStyle { public init() {} }
public struct AccessoryLinearCapacityGaugeStyle: GaugeStyle { public init() {} }
extension GaugeStyle where Self == DefaultGaugeStyle { public static var automatic: DefaultGaugeStyle { .init() } }
extension GaugeStyle where Self == LinearCapacityGaugeStyle { public static var linearCapacity: LinearCapacityGaugeStyle { .init() } }
extension GaugeStyle where Self == AccessoryCircularGaugeStyle { public static var accessoryCircular: AccessoryCircularGaugeStyle { .init() } }
extension GaugeStyle where Self == AccessoryCircularCapacityGaugeStyle { public static var accessoryCircularCapacity: AccessoryCircularCapacityGaugeStyle { .init() } }
extension GaugeStyle where Self == AccessoryLinearGaugeStyle { public static var accessoryLinear: AccessoryLinearGaugeStyle { .init() } }
extension GaugeStyle where Self == AccessoryLinearCapacityGaugeStyle { public static var accessoryLinearCapacity: AccessoryLinearCapacityGaugeStyle { .init() } }

// MARK: - Link / LabeledContent / ShareLink-free helpers

@MainActor @preconcurrency public struct Link<Label>: View where Label: View {
    @MainActor @preconcurrency public init(destination: URL, @ViewBuilder label: () -> Label) {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension Link where Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, destination: URL) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, destination: URL) where S: StringProtocol {}
}

public struct LabeledContent<Label, Content> {}
extension LabeledContent: View where Label: View, Content: View {
    nonisolated public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension LabeledContent where Label == Text, Content: View {
    nonisolated public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S: StringProtocol {}
}
extension LabeledContent where Label == Text, Content == Text {
    nonisolated public init<S>(_ titleKey: LocalizedStringKey, value: S) where S: StringProtocol {}
    @_disfavoredOverload nonisolated public init<S1, S2>(_ title: S1, value: S2) where S1: StringProtocol, S2: StringProtocol {}
    nonisolated public init<F>(_ titleKey: LocalizedStringKey, value: F.FormatInput, format: F) where F: FormatStyle, F.FormatInput: Equatable, F.FormatOutput == String {}
    nonisolated public init<S, F>(_ title: S, value: F.FormatInput, format: F) where S: StringProtocol, F: FormatStyle, F.FormatInput: Equatable, F.FormatOutput == String {}
}

// MARK: - List / Section / Form

@MainActor @preconcurrency public struct List<SelectionValue, Content>: View where SelectionValue: Hashable, Content: View {
    @MainActor public init(selection: Binding<Set<SelectionValue>>?, @ViewBuilder content: () -> Content) {}
    @MainActor public init(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload @MainActor public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
    @MainActor public init<Data, RowContent>(_ data: Data, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == ForEach<Data, Data.Element.ID, RowContent>, Data: RandomAccessCollection, RowContent: View, Data.Element: Identifiable {}
    @MainActor public init<Data, ID, RowContent>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == ForEach<Data, ID, RowContent>, Data: RandomAccessCollection, ID: Hashable, RowContent: View {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension List where SelectionValue == Never {
    @MainActor public init(@ViewBuilder content: () -> Content) {}
    @MainActor public init<Data, RowContent>(_ data: Data, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == ForEach<Data, Data.Element.ID, RowContent>, Data: RandomAccessCollection, RowContent: View, Data.Element: Identifiable {}
    @MainActor public init<Data, ID, RowContent>(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == ForEach<Data, ID, RowContent>, Data: RandomAccessCollection, ID: Hashable, RowContent: View {}
    @MainActor public init<RowContent>(_ data: Range<Int>, @ViewBuilder rowContent: @escaping (Int) -> RowContent)
    where Content == ForEach<Range<Int>, Int, RowContent>, RowContent: View {}
}

@MainActor @preconcurrency public protocol ListStyle {}
public struct DefaultListStyle: ListStyle { public init() {} }
public struct PlainListStyle: ListStyle { public init() {} }
public struct SidebarListStyle: ListStyle { public init() {} }
public struct InsetListStyle: ListStyle { public init() {}; public init(alternatesRowBackgrounds: Bool) {} }
/// macOS only.
public struct BorderedListStyle: ListStyle { public init() {}; public init(alternatesRowBackgrounds: Bool) {} }
extension ListStyle where Self == DefaultListStyle { public static var automatic: DefaultListStyle { .init() } }
extension ListStyle where Self == PlainListStyle { public static var plain: PlainListStyle { .init() } }
extension ListStyle where Self == SidebarListStyle { public static var sidebar: SidebarListStyle { .init() } }
extension ListStyle where Self == InsetListStyle {
    public static var inset: InsetListStyle { .init() }
    public static func inset(alternatesRowBackgrounds: Bool) -> InsetListStyle { .init(alternatesRowBackgrounds: alternatesRowBackgrounds) }
}
extension ListStyle where Self == BorderedListStyle {
    public static var bordered: BorderedListStyle { .init() }
    public static func bordered(alternatesRowBackgrounds: Bool) -> BorderedListStyle { .init(alternatesRowBackgrounds: alternatesRowBackgrounds) }
}

public struct Section<Parent, Content, Footer> {}
extension Section: View where Parent: View, Content: View, Footer: View {
    nonisolated public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent, @ViewBuilder footer: () -> Footer) {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension Section where Parent == EmptyView, Content: View, Footer: View {
    nonisolated public init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {}
}
extension Section where Parent: View, Content: View, Footer == EmptyView {
    nonisolated public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {}
    nonisolated public init(isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {}
}
extension Section where Parent == EmptyView, Content: View, Footer == EmptyView {
    nonisolated public init(@ViewBuilder content: () -> Content) {}
}
extension Section where Parent == Text, Content: View, Footer == EmptyView {
    nonisolated public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S: StringProtocol {}
    nonisolated public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) where S: StringProtocol {}
}

public struct Form<Content>: View where Content: View {
    nonisolated public init(@ViewBuilder content: () -> Content) {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}

@MainActor @preconcurrency public protocol FormStyle {}
public struct AutomaticFormStyle: FormStyle { public init() {} }
public struct ColumnsFormStyle: FormStyle { public init() {} }
public struct GroupedFormStyle: FormStyle { public init() {} }
extension FormStyle where Self == AutomaticFormStyle { public static var automatic: AutomaticFormStyle { .init() } }
extension FormStyle where Self == ColumnsFormStyle { public static var columns: ColumnsFormStyle { .init() } }
extension FormStyle where Self == GroupedFormStyle { public static var grouped: GroupedFormStyle { .init() } }

// MARK: - Navigation

public struct NavigationSplitView<Sidebar, Content, Detail>: View where Sidebar: View, Content: View, Detail: View {
    nonisolated public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {}
    nonisolated public init(columnVisibility: Binding<NavigationSplitViewVisibility>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {}
    nonisolated public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) where Content == EmptyView {}
    nonisolated public init(columnVisibility: Binding<NavigationSplitViewVisibility>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) where Content == EmptyView {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}

public struct NavigationSplitViewVisibility: Equatable, Codable, Sendable {
    public static var detailOnly: NavigationSplitViewVisibility { .init() }
    public static var doubleColumn: NavigationSplitViewVisibility { .init() }
    public static var all: NavigationSplitViewVisibility { .init() }
    public static var automatic: NavigationSplitViewVisibility { .init() }
}

public struct NavigationStack<Data, Root>: View where Root: View {
    nonisolated public init(@ViewBuilder root: () -> Root) where Data == NavigationPath {}
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}

public struct NavigationPath: Equatable {
    public init() {}
    public var count: Int { 0 }
    public var isEmpty: Bool { true }
    public mutating func append<V>(_ value: V) where V: Hashable {}
    public mutating func removeLast(_ k: Int = 1) {}
}

// MARK: - Table

@preconcurrency @MainActor public protocol TableColumnContent<TableRowValue, TableColumnSortComparator> {
    associatedtype TableRowValue: Identifiable = Self.TableColumnBody.TableRowValue
    associatedtype TableColumnSortComparator: SortComparator = Self.TableColumnBody.TableColumnSortComparator
    associatedtype TableColumnBody: TableColumnContent
    nonisolated var tableColumnBody: Self.TableColumnBody { get }
}

@preconcurrency @MainActor public protocol TableRowContent<TableRowValue> {
    associatedtype TableRowValue: Identifiable = Self.TableRowBody.TableRowValue
    associatedtype TableRowBody: TableRowContent
    @MainActor @preconcurrency var tableRowBody: Self.TableRowBody { get }
}

extension Never: TableColumnContent, TableRowContent {
    public typealias TableRowValue = Never
    public typealias TableColumnSortComparator = Never
    public typealias TableColumnBody = Never
    public typealias TableRowBody = Never
    public var tableColumnBody: Never { fatalError() }
    public var tableRowBody: Never { fatalError() }
}


public struct TableColumn<RowValue, Sort, Content, Label>: TableColumnContent where RowValue: Identifiable, Sort: SortComparator, Content: View, Label: View {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public typealias TableColumnBody = Never
    nonisolated public var tableColumnBody: Never { fatalError() }
}
extension TableColumn where Sort == Never, Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping (RowValue) -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, @ViewBuilder content: @escaping (RowValue) -> Content) where S: StringProtocol {}
    nonisolated public init(_ text: Text, @ViewBuilder content: @escaping (RowValue) -> Content) {}
    nonisolated public init(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, String>) where Content == Text {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, value: KeyPath<RowValue, String>) where Content == Text, S: StringProtocol {}
}
extension TableColumn where RowValue == Sort.Compared, Label == Text {
    nonisolated public init(_ titleKey: LocalizedStringKey, sortUsing comparator: Sort, @ViewBuilder content: @escaping (RowValue) -> Content) {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, sortUsing comparator: Sort, @ViewBuilder content: @escaping (RowValue) -> Content) where S: StringProtocol {}
}
extension TableColumn where Sort == KeyPathComparator<RowValue>, Label == Text {
    nonisolated public init<V>(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, V>, @ViewBuilder content: @escaping (RowValue) -> Content) where V: Comparable {}
    @_disfavoredOverload nonisolated public init<S, V>(_ title: S, value: KeyPath<RowValue, V>, @ViewBuilder content: @escaping (RowValue) -> Content) where S: StringProtocol, V: Comparable {}
    nonisolated public init(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, String>, comparator: String.StandardComparator = .localizedStandard) where Content == Text {}
    @_disfavoredOverload nonisolated public init<S>(_ title: S, value: KeyPath<RowValue, String>, comparator: String.StandardComparator = .localizedStandard) where Content == Text, S: StringProtocol {}
}
extension TableColumn {
    nonisolated public func width(_ width: CGFloat? = nil) -> TableColumn<RowValue, Sort, Content, Label> { self }
    nonisolated public func width(min: CGFloat? = nil, ideal: CGFloat? = nil, max: CGFloat? = nil) -> TableColumn<RowValue, Sort, Content, Label> { self }
}
extension TableColumnContent {
    @MainActor @preconcurrency public func alignment(_ alignment: TableColumnAlignment) -> some TableColumnContent<Self.TableRowValue, Self.TableColumnSortComparator> { self }
    nonisolated public func defaultVisibility(_ visibility: Visibility) -> some TableColumnContent<Self.TableRowValue, Self.TableColumnSortComparator> { self }
}

public struct TableColumnAlignment: Hashable, Sendable {
    public static var automatic: TableColumnAlignment { .init() }
    public static var leading: TableColumnAlignment { .init() }
    public static var center: TableColumnAlignment { .init() }
    public static var trailing: TableColumnAlignment { .init() }
    public static var numeric: TableColumnAlignment { .init() }
    public static func numeric(_ numberingSystem: Locale.NumberingSystem) -> TableColumnAlignment { .init() }
}

@frozen public struct TupleTableColumnContent<RowValue, Sort, T>: TableColumnContent where RowValue: Identifiable, Sort: SortComparator {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public typealias TableColumnBody = Never
    public var value: T
    nonisolated internal init(_ value: T, valueType: RowValue.Type, sortType: Sort.Type) { self.value = value }
    nonisolated public var tableColumnBody: Never { fatalError() }
}

extension _ConditionalContent: TableColumnContent where TrueContent: TableColumnContent, FalseContent: TableColumnContent,
    TrueContent.TableRowValue == FalseContent.TableRowValue, TrueContent.TableColumnSortComparator == FalseContent.TableColumnSortComparator {
    public typealias TableRowValue = TrueContent.TableRowValue
    public typealias TableColumnSortComparator = TrueContent.TableColumnSortComparator
    public typealias TableColumnBody = Never
    nonisolated public var tableColumnBody: Never { fatalError() }
}

extension Optional: TableColumnContent where Wrapped: TableColumnContent {
    public typealias TableRowValue = Wrapped.TableRowValue
    public typealias TableColumnSortComparator = Wrapped.TableColumnSortComparator
    public typealias TableColumnBody = Never
    nonisolated public var tableColumnBody: Never { fatalError() }
}

@resultBuilder public struct TableColumnBuilder<RowValue, Sort> where RowValue: Identifiable, Sort: SortComparator {
    public static func buildExpression<Content, Label>(_ column: TableColumn<RowValue, Sort, Content, Label>) -> TableColumn<RowValue, Sort, Content, Label> where Content: View, Label: View { column }
    @_disfavoredOverload public static func buildExpression<Content, Label>(_ column: TableColumn<RowValue, Never, Content, Label>) -> TableColumn<RowValue, Never, Content, Label> where Content: View, Label: View { column }
    public static func buildExpression<Column>(_ column: Column) -> Column where RowValue == Column.TableRowValue, Sort == Column.TableColumnSortComparator, Column: TableColumnContent { column }
    @_disfavoredOverload public static func buildExpression<Column>(_ column: Column) -> Column where RowValue == Column.TableRowValue, Column: TableColumnContent, Column.TableColumnSortComparator == Never { column }
    public static func buildBlock<Column>(_ column: Column) -> Column where RowValue == Column.TableRowValue, Sort == Column.TableColumnSortComparator, Column: TableColumnContent { column }
    @_disfavoredOverload public static func buildBlock<Column>(_ column: Column) -> Column where RowValue == Column.TableRowValue, Column: TableColumnContent, Column.TableColumnSortComparator == Never { column }
    public static func buildIf<C>(_ content: C?) -> C? where RowValue == C.TableRowValue, Sort == C.TableColumnSortComparator, C: TableColumnContent { content }
    @_disfavoredOverload public static func buildIf<C>(_ content: C?) -> C? where RowValue == C.TableRowValue, C: TableColumnContent, C.TableColumnSortComparator == Never { content }
    public static func buildEither<T, F>(first: T) -> _ConditionalContent<T, F> where RowValue == T.TableRowValue, Sort == T.TableColumnSortComparator, T: TableColumnContent, F: TableColumnContent, T.TableColumnSortComparator == F.TableColumnSortComparator, T.TableRowValue == F.TableRowValue { _ConditionalContent(storage: .trueContent(first)) }
    public static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F> where RowValue == T.TableRowValue, Sort == T.TableColumnSortComparator, T: TableColumnContent, F: TableColumnContent, T.TableColumnSortComparator == F.TableColumnSortComparator, T.TableRowValue == F.TableRowValue { _ConditionalContent(storage: .falseContent(second)) }
}


// Fixed-arity column blocks, 2...10 columns, exactly as in the SDK (an 11-column Table does not compile on macOS).
extension TableColumnBuilder {
    public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> TupleTableColumnContent<RowValue, Sort, (C0, C1)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C0.TableRowValue == C1.TableRowValue { TupleTableColumnContent((c0, c1), valueType: RowValue.self, sortType: Sort.self) }
    @_disfavoredOverload public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> TupleTableColumnContent<RowValue, Never, (C0, C1)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableColumnSortComparator == Never, C1.TableColumnSortComparator == Never { TupleTableColumnContent((c0, c1), valueType: RowValue.self, sortType: Never.self) }
    public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue { TupleTableColumnContent((c0, c1, c2), valueType: RowValue.self, sortType: Sort.self) }
    @_disfavoredOverload public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleTableColumnContent<RowValue, Never, (C0, C1, C2)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableColumnSortComparator == Never, C1.TableColumnSortComparator == Never, C2.TableColumnSortComparator == Never { TupleTableColumnContent((c0, c1, c2), valueType: RowValue.self, sortType: Never.self) }
    public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue { TupleTableColumnContent((c0, c1, c2, c3), valueType: RowValue.self, sortType: Sort.self) }
    @_disfavoredOverload public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleTableColumnContent<RowValue, Never, (C0, C1, C2, C3)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableColumnSortComparator == Never, C1.TableColumnSortComparator == Never, C2.TableColumnSortComparator == Never, C3.TableColumnSortComparator == Never { TupleTableColumnContent((c0, c1, c2, c3), valueType: RowValue.self, sortType: Never.self) }
    public static func buildBlock<C0, C1, C2, C3, C4>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue { TupleTableColumnContent((c0, c1, c2, c3, c4), valueType: RowValue.self, sortType: Sort.self) }
    @_disfavoredOverload public static func buildBlock<C0, C1, C2, C3, C4>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleTableColumnContent<RowValue, Never, (C0, C1, C2, C3, C4)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableColumnSortComparator == Never, C1.TableColumnSortComparator == Never, C2.TableColumnSortComparator == Never, C3.TableColumnSortComparator == Never, C4.TableColumnSortComparator == Never { TupleTableColumnContent((c0, c1, c2, c3, c4), valueType: RowValue.self, sortType: Never.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue { TupleTableColumnContent((c0, c1, c2, c3, c4, c5), valueType: RowValue.self, sortType: Sort.self) }
    @_disfavoredOverload public static func buildBlock<C0, C1, C2, C3, C4, C5>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleTableColumnContent<RowValue, Never, (C0, C1, C2, C3, C4, C5)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableColumnSortComparator == Never, C1.TableColumnSortComparator == Never, C2.TableColumnSortComparator == Never, C3.TableColumnSortComparator == Never, C4.TableColumnSortComparator == Never, C5.TableColumnSortComparator == Never { TupleTableColumnContent((c0, c1, c2, c3, c4, c5), valueType: RowValue.self, sortType: Never.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5, C6)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C6 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue { TupleTableColumnContent((c0, c1, c2, c3, c4, c5, c6), valueType: RowValue.self, sortType: Sort.self) }
    @_disfavoredOverload public static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleTableColumnContent<RowValue, Never, (C0, C1, C2, C3, C4, C5, C6)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C6 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableColumnSortComparator == Never, C1.TableColumnSortComparator == Never, C2.TableColumnSortComparator == Never, C3.TableColumnSortComparator == Never, C4.TableColumnSortComparator == Never, C5.TableColumnSortComparator == Never, C6.TableColumnSortComparator == Never { TupleTableColumnContent((c0, c1, c2, c3, c4, c5, c6), valueType: RowValue.self, sortType: Never.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5, C6, C7)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C6 : TableColumnContent, C7 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableRowValue == C7.TableRowValue { TupleTableColumnContent((c0, c1, c2, c3, c4, c5, c6, c7), valueType: RowValue.self, sortType: Sort.self) }
    @_disfavoredOverload public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleTableColumnContent<RowValue, Never, (C0, C1, C2, C3, C4, C5, C6, C7)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C6 : TableColumnContent, C7 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableRowValue == C7.TableRowValue, C0.TableColumnSortComparator == Never, C1.TableColumnSortComparator == Never, C2.TableColumnSortComparator == Never, C3.TableColumnSortComparator == Never, C4.TableColumnSortComparator == Never, C5.TableColumnSortComparator == Never, C6.TableColumnSortComparator == Never, C7.TableColumnSortComparator == Never { TupleTableColumnContent((c0, c1, c2, c3, c4, c5, c6, c7), valueType: RowValue.self, sortType: Never.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5, C6, C7, C8)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C6 : TableColumnContent, C7 : TableColumnContent, C8 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableRowValue == C7.TableRowValue, C0.TableRowValue == C8.TableRowValue { TupleTableColumnContent((c0, c1, c2, c3, c4, c5, c6, c7, c8), valueType: RowValue.self, sortType: Sort.self) }
    @_disfavoredOverload public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleTableColumnContent<RowValue, Never, (C0, C1, C2, C3, C4, C5, C6, C7, C8)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C6 : TableColumnContent, C7 : TableColumnContent, C8 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableRowValue == C7.TableRowValue, C0.TableRowValue == C8.TableRowValue, C0.TableColumnSortComparator == Never, C1.TableColumnSortComparator == Never, C2.TableColumnSortComparator == Never, C3.TableColumnSortComparator == Never, C4.TableColumnSortComparator == Never, C5.TableColumnSortComparator == Never, C6.TableColumnSortComparator == Never, C7.TableColumnSortComparator == Never, C8.TableColumnSortComparator == Never { TupleTableColumnContent((c0, c1, c2, c3, c4, c5, c6, c7, c8), valueType: RowValue.self, sortType: Never.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C6 : TableColumnContent, C7 : TableColumnContent, C8 : TableColumnContent, C9 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableRowValue == C7.TableRowValue, C0.TableRowValue == C8.TableRowValue, C0.TableRowValue == C9.TableRowValue { TupleTableColumnContent((c0, c1, c2, c3, c4, c5, c6, c7, c8, c9), valueType: RowValue.self, sortType: Sort.self) }
    @_disfavoredOverload public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleTableColumnContent<RowValue, Never, (C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> where RowValue == C0.TableRowValue, C0 : TableColumnContent, C1 : TableColumnContent, C2 : TableColumnContent, C3 : TableColumnContent, C4 : TableColumnContent, C5 : TableColumnContent, C6 : TableColumnContent, C7 : TableColumnContent, C8 : TableColumnContent, C9 : TableColumnContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableRowValue == C7.TableRowValue, C0.TableRowValue == C8.TableRowValue, C0.TableRowValue == C9.TableRowValue, C0.TableColumnSortComparator == Never, C1.TableColumnSortComparator == Never, C2.TableColumnSortComparator == Never, C3.TableColumnSortComparator == Never, C4.TableColumnSortComparator == Never, C5.TableColumnSortComparator == Never, C6.TableColumnSortComparator == Never, C7.TableColumnSortComparator == Never, C8.TableColumnSortComparator == Never, C9.TableColumnSortComparator == Never { TupleTableColumnContent((c0, c1, c2, c3, c4, c5, c6, c7, c8, c9), valueType: RowValue.self, sortType: Never.self) }
}

public struct TableForEachContent<Data>: TableRowContent where Data: RandomAccessCollection, Data.Element: Identifiable {
    public typealias TableRowValue = Data.Element
    public typealias TableRowBody = Never
    @MainActor public var tableRowBody: Never { fatalError() }
}

@resultBuilder public struct TableRowBuilder<Value> where Value: Identifiable {
    public static func buildExpression<Content>(_ content: Content) -> Content where Value == Content.TableRowValue, Content: TableRowContent { content }
    public static func buildBlock<C>(_ content: C) -> C where Value == C.TableRowValue, C: TableRowContent { content }
    public static func buildIf<C>(_ content: C?) -> C? where Value == C.TableRowValue, C: TableRowContent { content }
    public static func buildEither<T, F>(first: T) -> _ConditionalContent<T, F> where Value == T.TableRowValue, T: TableRowContent, F: TableRowContent, T.TableRowValue == F.TableRowValue { _ConditionalContent(storage: .trueContent(first)) }
    public static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F> where Value == T.TableRowValue, T: TableRowContent, F: TableRowContent, T.TableRowValue == F.TableRowValue { _ConditionalContent(storage: .falseContent(second)) }
    public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> TupleTableRowContent<Value, (C0, C1)> where Value == C0.TableRowValue, C0: TableRowContent, C1: TableRowContent, C0.TableRowValue == C1.TableRowValue { TupleTableRowContent((c0, c1), ofType: Value.self) }
    public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleTableRowContent<Value, (C0, C1, C2)> where Value == C0.TableRowValue, C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue { TupleTableRowContent((c0, c1, c2), ofType: Value.self) }
    public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleTableRowContent<Value, (C0, C1, C2, C3)> where Value == C0.TableRowValue, C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue { TupleTableRowContent((c0, c1, c2, c3), ofType: Value.self) }
    public static func buildBlock<C0, C1, C2, C3, C4>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4)> where Value == C0.TableRowValue, C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue { TupleTableRowContent((c0, c1, c2, c3, c4), ofType: Value.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5)> where Value == C0.TableRowValue, C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue { TupleTableRowContent((c0, c1, c2, c3, c4, c5), ofType: Value.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5, C6)> where Value == C0.TableRowValue, C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent, C6: TableRowContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue { TupleTableRowContent((c0, c1, c2, c3, c4, c5, c6), ofType: Value.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5, C6, C7)> where Value == C0.TableRowValue, C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent, C6: TableRowContent, C7: TableRowContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableRowValue == C7.TableRowValue { TupleTableRowContent((c0, c1, c2, c3, c4, c5, c6, c7), ofType: Value.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5, C6, C7, C8)> where Value == C0.TableRowValue, C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent, C6: TableRowContent, C7: TableRowContent, C8: TableRowContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableRowValue == C7.TableRowValue, C0.TableRowValue == C8.TableRowValue { TupleTableRowContent((c0, c1, c2, c3, c4, c5, c6, c7, c8), ofType: Value.self) }
    public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> where Value == C0.TableRowValue, C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent, C6: TableRowContent, C7: TableRowContent, C8: TableRowContent, C9: TableRowContent, C0.TableRowValue == C1.TableRowValue, C0.TableRowValue == C2.TableRowValue, C0.TableRowValue == C3.TableRowValue, C0.TableRowValue == C4.TableRowValue, C0.TableRowValue == C5.TableRowValue, C0.TableRowValue == C6.TableRowValue, C0.TableRowValue == C7.TableRowValue, C0.TableRowValue == C8.TableRowValue, C0.TableRowValue == C9.TableRowValue { TupleTableRowContent((c0, c1, c2, c3, c4, c5, c6, c7, c8, c9), ofType: Value.self) }
}

@frozen public struct TupleTableRowContent<Value, T>: TableRowContent where Value: Identifiable {
    public typealias TableRowValue = Value
    public typealias TableRowBody = Never
    public var value: T
    nonisolated internal init(_ value: T, ofType: Value.Type) { self.value = value }
    @MainActor public var tableRowBody: Never { fatalError() }
}
extension Optional: TableRowContent where Wrapped: TableRowContent {
    public typealias TableRowValue = Wrapped.TableRowValue
    public typealias TableRowBody = Never
    @MainActor public var tableRowBody: Never { fatalError() }
}
extension _ConditionalContent: TableRowContent where TrueContent: TableRowContent, FalseContent: TableRowContent, TrueContent.TableRowValue == FalseContent.TableRowValue {
    public typealias TableRowValue = TrueContent.TableRowValue
    public typealias TableRowBody = Never
    @MainActor public var tableRowBody: Never { fatalError() }
}

public struct Table<Value, Rows, Columns>: View where Value == Rows.TableRowValue, Rows: TableRowContent, Columns: TableColumnContent, Rows.TableRowValue == Columns.TableRowValue {
    @MainActor @preconcurrency public var body: some View { EmptyView() }
}
extension Table {
    nonisolated public init(of valueType: Value.Type, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {}
    nonisolated public init<Data>(_ data: Data, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Columns.TableRowValue == Data.Element {}
    nonisolated public init<Data>(_ data: Data, selection: Binding<Value.ID?>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Columns.TableRowValue == Data.Element {}
    nonisolated public init<Data>(_ data: Data, selection: Binding<Set<Value.ID>>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Columns.TableRowValue == Data.Element {}
    nonisolated public init<Data, Sort>(_ data: Data, sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Sort: SortComparator, Columns.TableRowValue == Data.Element, Data.Element == Sort.Compared {}
}

@MainActor @preconcurrency public protocol TableStyle {}
public struct AutomaticTableStyle: TableStyle { public init() {} }
public struct InsetTableStyle: TableStyle { public init() {}; public init(alternatesRowBackgrounds: Bool) {} }
/// macOS only.
public struct BorderedTableStyle: TableStyle { public init() {}; public init(alternatesRowBackgrounds: Bool) {} }
extension TableStyle where Self == AutomaticTableStyle { public static var automatic: AutomaticTableStyle { .init() } }
extension TableStyle where Self == InsetTableStyle {
    public static var inset: InsetTableStyle { .init() }
    public static func inset(alternatesRowBackgrounds: Bool) -> InsetTableStyle { .init(alternatesRowBackgrounds: alternatesRowBackgrounds) }
}
extension TableStyle where Self == BorderedTableStyle {
    public static var bordered: BorderedTableStyle { .init() }
    public static func bordered(alternatesRowBackgrounds: Bool) -> BorderedTableStyle { .init(alternatesRowBackgrounds: alternatesRowBackgrounds) }
}
