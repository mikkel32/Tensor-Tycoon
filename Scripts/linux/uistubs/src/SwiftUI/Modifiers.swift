// SwiftUI stub — View modifiers.
//
// The `extension View` members below are generated from the iOS 26 SDK interface (tools/gen_members.py) for every
// modifier name the app uses: real labels, parameter types, generic constraints, default values, isolation and
// macOS deprecations. macOS-unavailable overloads are omitted. Hand-written supporting types follow.
import Symbols
import Combine

extension View {
    nonisolated public func disabled(_ disabled: Bool) -> some View { _m() }
    nonisolated public func offset(_ offset: CGSize) -> some View { _m() }
    nonisolated public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some View { _m() }
    nonisolated public func fixedSize(horizontal: Bool, vertical: Bool) -> some View { _m() }
    nonisolated public func fixedSize() -> some View { _m() }
    nonisolated public func accentColor(_ accentColor: Color?) -> some View { _m() }
    nonisolated public func padding(_ insets: EdgeInsets) -> some View { _m() }
    nonisolated public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View { _m() }
    nonisolated public func padding(_ length: CGFloat) -> some View { _m() }
    nonisolated public func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View { _m() }
    nonisolated public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some View { _m() }
    @_disfavoredOverload nonisolated public func overlay<Overlay>(_ overlay: Overlay, alignment: Alignment = .center) -> some View where Overlay : View { _m() }
    nonisolated public func overlay<V>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View where V : View { _m() }
    nonisolated public func overlay<S>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View where S : ShapeStyle { _m() }
    nonisolated public func overlay<S, T>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View where S : ShapeStyle, T : Shape { _m() }
    nonisolated public func blur(radius: CGFloat, opaque: Bool = false) -> some View { _m() }
    nonisolated public func opacity(_ opacity: Double) -> some View { _m() }
    nonisolated public func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View { _m() }
    nonisolated public func position(_ position: CGPoint) -> some View { _m() }
    nonisolated public func position(x: CGFloat = 0, y: CGFloat = 0) -> some View { _m() }
    nonisolated public func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> some View { _m() }
    nonisolated public func controlSize(_ controlSize: ControlSize) -> some View { _m() }
    nonisolated public func controlSize<T>(_ range: T) -> some View where T : RangeExpression, T.Bound == ControlSize { _m() }
    nonisolated public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> some View { _m() }
    nonisolated public func aspectRatio(_ aspectRatio: CGFloat? = nil, contentMode: ContentMode) -> some View { _m() }
    nonisolated public func aspectRatio(_ aspectRatio: CGSize, contentMode: ContentMode) -> some View { _m() }
    nonisolated public func multilineTextAlignment(_ alignment: TextAlignment) -> some View { _m() }
    nonisolated public func minimumScaleFactor(_ factor: CGFloat) -> some View { _m() }
    nonisolated public func textCase(_ textCase: Text.Case?) -> some View { _m() }
    nonisolated public func lineLimit(_ number: Int?) -> some View { _m() }
    nonisolated public func lineLimit(_ limit: PartialRangeFrom<Int>) -> some View { _m() }
    nonisolated public func lineLimit(_ limit: PartialRangeThrough<Int>) -> some View { _m() }
    nonisolated public func lineLimit(_ limit: ClosedRange<Int>) -> some View { _m() }
    nonisolated public func lineLimit(_ limit: Int, reservesSpace: Bool) -> some View { _m() }
    nonisolated public func foregroundStyle<S>(_ style: S) -> some View where S : ShapeStyle { _m() }
    nonisolated public func foregroundStyle<S1, S2>(_ primary: S1, _ secondary: S2) -> some View where S1 : ShapeStyle, S2 : ShapeStyle { _m() }
    nonisolated public func foregroundStyle<S1, S2, S3>(_ primary: S1, _ secondary: S2, _ tertiary: S3) -> some View where S1 : ShapeStyle, S2 : ShapeStyle, S3 : ShapeStyle { _m() }
    nonisolated public func onAppear(perform action: (() -> Void)? = nil) -> some View { _m() }
    nonisolated public func onDisappear(perform action: (() -> Void)? = nil) -> some View { _m() }
    nonisolated public func tag<V>(_ tag: V, includeOptional: Bool = true) -> some View where V : Hashable { _m() }
    nonisolated public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View { _m() }
    @available(*, deprecated, message: "Please pass one or more parameters.")
    nonisolated public func frame() -> some View { _m() }
    nonisolated public func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> some View { _m() }
    nonisolated public func contentShape<S>(_ shape: S, eoFill: Bool = false) -> some View where S : Shape { _m() }
    nonisolated public func contentShape<S>(_ kind: ContentShapeKinds, _ shape: S, eoFill: Bool = false) -> some View where S : Shape { _m() }
    nonisolated public func animation<V>(_ animation: Animation?, value: V) -> some View where V : Equatable { _m() }
    @available(macOS, deprecated: 14.0, message: "Use `onChange` with a two or zero parameter action closure instead.")
    nonisolated public func onChange<V>(of value: V, perform action: @escaping (_ newValue: V) -> Void) -> some View where V : Equatable { _m() }
    nonisolated public func onChange<V>(of value: V, initial: Bool = false, _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void) -> some View where V : Equatable { _m() }
    nonisolated public func onChange<V>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some View where V : Equatable { _m() }
    nonisolated public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View { _m() }
    nonisolated public func layoutPriority(_ value: Double) -> some View { _m() }
    nonisolated public func environment<T>(_ object: T?) -> some View where T : AnyObject, T : Observable { _m() }
    @_disfavoredOverload nonisolated public func background<Background>(_ background: Background, alignment: Alignment = .center) -> some View where Background : View { _m() }
    nonisolated public func background<V>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View where V : View { _m() }
    nonisolated public func background(ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { _m() }
    nonisolated public func background<S>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View where S : ShapeStyle { _m() }
    nonisolated public func background<S>(in shape: S, fillStyle: FillStyle = FillStyle()) -> some View where S : Shape { _m() }
    nonisolated public func background<S, T>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View where S : ShapeStyle, T : Shape { _m() }
    nonisolated public func background<S>(in shape: S, fillStyle: FillStyle = FillStyle()) -> some View where S : InsettableShape { _m() }
    nonisolated public func background<S, T>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View where S : ShapeStyle, T : InsettableShape { _m() }
    nonisolated public func contentTransition(_ transition: ContentTransition) -> some View { _m() }
    nonisolated public func saturation(_ amount: Double) -> some View { _m() }
    nonisolated public func multilineTextAlignment(strategy: Text.AlignmentStrategy) -> some View { _m() }
    nonisolated public func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> some View { _m() }
    nonisolated public func allowsHitTesting(_ enabled: Bool) -> some View { _m() }
    nonisolated public func font(_ font: Font?) -> some View { _m() }
    nonisolated public func monospacedDigit() -> some View { _m() }
    nonisolated public func monospaced(_ isActive: Bool = true) -> some View { _m() }
    nonisolated public func fontWeight(_ weight: Font.Weight?) -> some View { _m() }
    nonisolated public func bold(_ isActive: Bool = true) -> some View { _m() }
    nonisolated public func italic(_ isActive: Bool = true) -> some View { _m() }
    nonisolated public func clipShape<S>(_ shape: S, style: FillStyle = FillStyle()) -> some View where S : Shape { _m() }
    nonisolated public func clipped(antialiased: Bool = false) -> some View { _m() }
    @available(macOS, deprecated: 12.0, message: "Use withAnimation or animation(_:value:) instead.")
    @_disfavoredOverload nonisolated public func animation(_ animation: Animation?) -> some View { _m() }
    nonisolated public func id<ID>(_ id: ID) -> some View where ID : Hashable { _m() }
    nonisolated public func colorScheme(_ colorScheme: ColorScheme) -> some View { _m() }
    nonisolated public func gesture<T>(_ gesture: T, including mask: GestureMask = .all) -> some View where T : Gesture { _m() }
    nonisolated public func gesture<T>(_ gesture: T, isEnabled: Bool) -> some View where T : Gesture { _m() }
    nonisolated public func scaleEffect(_ scale: CGSize, anchor: UnitPoint = .center) -> some View { _m() }
    nonisolated public func scaleEffect(_ s: CGFloat, anchor: UnitPoint = .center) -> some View { _m() }
    nonisolated public func scaleEffect(x: CGFloat = 1.0, y: CGFloat = 1.0, anchor: UnitPoint = .center) -> some View { _m() }
    nonisolated public func tint<S>(_ tint: S?) -> some View where S : ShapeStyle { _m() }
    @_disfavoredOverload nonisolated public func tint(_ tint: Color?) -> some View { _m() }
    @_disfavoredOverload nonisolated public func transition(_ t: AnyTransition) -> some View { _m() }
    nonisolated public func transition<T>(_ transition: T) -> some View where T : Transition { _m() }
    nonisolated public func accessibilityValue(_ valueDescription: Text, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    nonisolated public func accessibilityValue(_ valueKey: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    @_disfavoredOverload nonisolated public func accessibilityValue<S>(_ value: S, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> where S : StringProtocol { _a() }
    nonisolated public func accessibilityValue(_ valueDescription: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    nonisolated public func accessibilityValue(_ valueKey: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    @_disfavoredOverload nonisolated public func accessibilityValue<S>(_ value: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> where S : StringProtocol { _a() }
    nonisolated public func navigationSplitViewColumnWidth(_ width: CGFloat) -> some View { _m() }
    nonisolated public func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> some View { _m() }
    nonisolated public func listStyle<S>(_ style: S) -> some View where S : ListStyle { _m() }
    nonisolated public func accessibilityLabel(_ label: Text, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    nonisolated public func accessibilityLabel(_ labelKey: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    @_disfavoredOverload nonisolated public func accessibilityLabel<S>(_ label: S, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> where S : StringProtocol { _a() }
    nonisolated public func accessibilityLabel(_ label: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    nonisolated public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    @_disfavoredOverload nonisolated public func accessibilityLabel<S>(_ label: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> where S : StringProtocol { _a() }
    nonisolated public func textSelection<S>(_ selectability: S) -> some View where S : TextSelectability { _m() }
    nonisolated public func selectionDisabled(_ isDisabled: Bool = true) -> some View { _m() }
    nonisolated public func accessibilityHint(_ hint: Text, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    nonisolated public func accessibilityHint(_ hintKey: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    @_disfavoredOverload nonisolated public func accessibilityHint<S>(_ hint: S, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> where S : StringProtocol { _a() }
    nonisolated public func accessibilityHint(_ hint: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    nonisolated public func accessibilityHint(_ hintKey: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    @_disfavoredOverload nonisolated public func accessibilityHint<S>(_ hint: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> where S : StringProtocol { _a() }
    nonisolated public func onReceive<P>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> some View where P : Publisher, P.Failure == Never { _m() }
    nonisolated public func menuStyle<S>(_ style: S) -> some View where S : MenuStyle { _m() }
    nonisolated public func toggleStyle<S>(_ style: S) -> some View where S : ToggleStyle { _m() }
    nonisolated public func symbolEffect<T>(_ effect: T, options: Symbols.SymbolEffectOptions = .default, isActive: Bool = true) -> some View where T : Symbols.IndefiniteSymbolEffect, T : Symbols.SymbolEffect { _m() }
    nonisolated public func symbolEffect<T, U>(_ effect: T, options: Symbols.SymbolEffectOptions = .default, value: U) -> some View where T : Symbols.DiscreteSymbolEffect, T : Symbols.SymbolEffect, U : Equatable { _m() }
    nonisolated public func task(priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View { _m() }
    nonisolated public func task<T>(id value: T, priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View where T : Equatable { _m() }
    nonisolated public func sheet<Item, Content>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View where Item : Identifiable, Content : View { _m() }
    nonisolated public func sheet<Content>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View where Content : View { _m() }
    nonisolated public func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> some View { _m() }
    nonisolated public func buttonStyle<S>(_ style: S) -> some View where S : PrimitiveButtonStyle { _m() }
    nonisolated public func focused<Value>(_ binding: FocusState<Value>.Binding, equals value: Value) -> some View where Value : Hashable { _m() }
    nonisolated public func focused(_ condition: FocusState<Bool>.Binding) -> some View { _m() }
    nonisolated public func contextMenu<MenuItems>(@ViewBuilder menuItems: () -> MenuItems) -> some View where MenuItems : View { _m() }
    nonisolated public func contextMenu<M, P>(@ViewBuilder menuItems: () -> M, @ViewBuilder preview: () -> P) -> some View where M : View, P : View { _m() }
    nonisolated public func toolbar(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { _m() }
    nonisolated public func buttonStyle<S>(_ style: S) -> some View where S : ButtonStyle { _m() }
    nonisolated public func textFieldStyle<S>(_ style: S) -> some View where S : TextFieldStyle { _m() }
    nonisolated public func alert<A>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View where A : View { _m() }
    @_disfavoredOverload nonisolated public func alert<S, A>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View where S : StringProtocol, A : View { _m() }
    nonisolated public func alert<A>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View where A : View { _m() }
    nonisolated public func alert<A, M>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View where A : View, M : View { _m() }
    @_disfavoredOverload nonisolated public func alert<S, A, M>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View where S : StringProtocol, A : View, M : View { _m() }
    nonisolated public func alert<A, M>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View where A : View, M : View { _m() }
    nonisolated public func alert<A, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View where A : View { _m() }
    @_disfavoredOverload nonisolated public func alert<S, A, T>(_ title: S, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View where S : StringProtocol, A : View { _m() }
    nonisolated public func alert<A, T>(_ title: Text, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View where A : View { _m() }
    nonisolated public func alert<A, M, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View where A : View, M : View { _m() }
    @_disfavoredOverload nonisolated public func alert<S, A, M, T>(_ title: S, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View where S : StringProtocol, A : View, M : View { _m() }
    nonisolated public func alert<A, M, T>(_ title: Text, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View where A : View, M : View { _m() }
    nonisolated public func alert<E, A>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: () -> A) -> some View where E : LocalizedError, A : View { _m() }
    nonisolated public func alert<E, A, M>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: (E) -> A, @ViewBuilder message: (E) -> M) -> some View where E : LocalizedError, A : View, M : View { _m() }
    nonisolated public func scrollContentBackground(_ visibility: Visibility) -> some View { _m() }
    nonisolated public func popover<Item, Content>(item: Binding<Item?>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View where Item : Identifiable, Content : View { _m() }
    nonisolated public func popover<Content>(isPresented: Binding<Bool>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge? = nil, @ViewBuilder content: @escaping () -> Content) -> some View where Content : View { _m() }
    nonisolated public func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = [.vertical, .horizontal]) -> some View { _m() }
    nonisolated public func labelsHidden() -> some View { _m() }
    nonisolated public func pickerStyle<S>(_ style: S) -> some View where S : PickerStyle { _m() }
    nonisolated public func accessibilityHidden(_ hidden: Bool, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    nonisolated public func accessibilityHidden(_ hidden: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    nonisolated public func toolbar(removing defaultItemKind: ToolbarDefaultItemKind?) -> some View { _m() }
    nonisolated public func confirmationDialog<A>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> some View where A : View { _m() }
    @_disfavoredOverload nonisolated public func confirmationDialog<S, A>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> some View where S : StringProtocol, A : View { _m() }
    nonisolated public func confirmationDialog<A>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> some View where A : View { _m() }
    nonisolated public func confirmationDialog<A, M>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View where A : View, M : View { _m() }
    @_disfavoredOverload nonisolated public func confirmationDialog<S, A, M>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View where S : StringProtocol, A : View, M : View { _m() }
    nonisolated public func confirmationDialog<A, M>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View where A : View, M : View { _m() }
    nonisolated public func confirmationDialog<A, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View where A : View { _m() }
    @_disfavoredOverload nonisolated public func confirmationDialog<S, A, T>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View where S : StringProtocol, A : View { _m() }
    nonisolated public func confirmationDialog<A, T>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View where A : View { _m() }
    nonisolated public func confirmationDialog<A, M, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View where A : View, M : View { _m() }
    @_disfavoredOverload nonisolated public func confirmationDialog<S, A, M, T>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View where S : StringProtocol, A : View, M : View { _m() }
    nonisolated public func confirmationDialog<A, M, T>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View where A : View, M : View { _m() }
    nonisolated public func gridCellColumns(_ count: Int) -> some View { _m() }
    nonisolated public func gridColumnAlignment(_ guide: HorizontalAlignment) -> some View { _m() }
    nonisolated public func toolbar<Content>(@ViewBuilder content: () -> Content) -> some View where Content : View { _m() }
    nonisolated public func toolbar<Content>(@ToolbarContentBuilder content: () -> Content) -> some View where Content : ToolbarContent { _m() }
    nonisolated public func toolbar<Content>(id: String, @ToolbarContentBuilder content: () -> Content) -> some View where Content : CustomizableToolbarContent { _m() }
    nonisolated public func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View { _m() }
    nonisolated public func onKeyPress(_ key: KeyEquivalent, phases: KeyPress.Phases, action: @escaping (KeyPress) -> KeyPress.Result) -> some View { _m() }
    nonisolated public func onKeyPress(keys: Set<KeyEquivalent>, phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View { _m() }
    nonisolated public func onKeyPress(characters: CharacterSet, phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View { _m() }
    nonisolated public func onKeyPress(phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View { _m() }
    nonisolated public func hidden() -> some View { _m() }
    nonisolated public func menuIndicator(_ visibility: Visibility) -> some View { _m() }
    nonisolated public func badge(_ count: Int) -> some View { _m() }
    nonisolated public func badge(_ label: Text?) -> some View { _m() }
    nonisolated public func badge(_ key: LocalizedStringKey?) -> some View { _m() }
    @_disfavoredOverload nonisolated public func badge<S>(_ label: S?) -> some View where S : StringProtocol { _m() }
    nonisolated public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View { _m() }
    nonisolated public func keyboardShortcut(_ shortcut: KeyboardShortcut) -> some View { _m() }
    nonisolated public func keyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View { _m() }
    nonisolated public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command, localization: KeyboardShortcut.Localization) -> some View { _m() }
    nonisolated public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _a() }
    nonisolated public func interactiveDismissDisabled(_ isDisabled: Bool = true) -> some View { _m() }
    nonisolated public func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View { _m() }
    @_disfavoredOverload nonisolated public func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform action: @escaping (CGPoint) -> Void) -> some View { _m() }
    nonisolated public func onTapGesture(count: Int = 1, coordinateSpace: some CoordinateSpaceProtocol = .local, perform action: @escaping (CGPoint) -> Void) -> some View { _m() }
    nonisolated public func help(_ textKey: LocalizedStringKey) -> some View { _m() }
    nonisolated public func help(_ text: Text) -> some View { _m() }
    @_disfavoredOverload nonisolated public func help<S>(_ text: S) -> some View where S : StringProtocol { _m() }
    nonisolated public func labelStyle<S>(_ style: S) -> some View where S : LabelStyle { _m() }
}

extension View where Self: Equatable {
    nonisolated public func animation(_ animation: Animation?) -> some View { _m() }
}

extension ModifiedContent where Modifier == AccessibilityAttachmentModifier {
    nonisolated public func accessibilityValue(_ valueDescription: Text, isEnabled: Bool) -> ModifiedContent<Content, Modifier> { self }
    nonisolated public func accessibilityValue(_ valueKey: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Content, Modifier> { self }
    @_disfavoredOverload nonisolated public func accessibilityValue<S>(_ value: S, isEnabled: Bool) -> ModifiedContent<Content, Modifier> where S : StringProtocol { self }
    nonisolated public func accessibilityValue(_ valueDescription: Text) -> ModifiedContent<Content, Modifier> { self }
    nonisolated public func accessibilityValue(_ valueKey: LocalizedStringKey) -> ModifiedContent<Content, Modifier> { self }
    @_disfavoredOverload nonisolated public func accessibilityValue<S>(_ value: S) -> ModifiedContent<Content, Modifier> where S : StringProtocol { self }
    nonisolated public func accessibilityLabel(_ label: Text, isEnabled: Bool) -> ModifiedContent<Content, Modifier> { self }
    nonisolated public func accessibilityLabel(_ labelKey: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Content, Modifier> { self }
    @_disfavoredOverload nonisolated public func accessibilityLabel<S>(_ label: S, isEnabled: Bool) -> ModifiedContent<Content, Modifier> where S : StringProtocol { self }
    nonisolated public func accessibilityLabel(_ label: Text) -> ModifiedContent<Content, Modifier> { self }
    nonisolated public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> ModifiedContent<Content, Modifier> { self }
    @_disfavoredOverload nonisolated public func accessibilityLabel<S>(_ label: S) -> ModifiedContent<Content, Modifier> where S : StringProtocol { self }
    nonisolated public func accessibilityHint(_ hint: Text, isEnabled: Bool) -> ModifiedContent<Content, Modifier> { self }
    nonisolated public func accessibilityHint(_ hintKey: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Content, Modifier> { self }
    @_disfavoredOverload nonisolated public func accessibilityHint<S>(_ hint: S, isEnabled: Bool) -> ModifiedContent<Content, Modifier> where S : StringProtocol { self }
    nonisolated public func accessibilityHint(_ hint: Text) -> ModifiedContent<Content, Modifier> { self }
    nonisolated public func accessibilityHint(_ hintKey: LocalizedStringKey) -> ModifiedContent<Content, Modifier> { self }
    @_disfavoredOverload nonisolated public func accessibilityHint<S>(_ hint: S) -> ModifiedContent<Content, Modifier> where S : StringProtocol { self }
    nonisolated public func accessibilityHidden(_ hidden: Bool, isEnabled: Bool) -> ModifiedContent<Content, Modifier> { self }
    nonisolated public func accessibilityHidden(_ hidden: Bool) -> ModifiedContent<Content, Modifier> { self }
    nonisolated public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Content, Modifier> { self }
}
