// Darwin APIs that swift-corelibs-foundation lacks but that real CoreGraphics / Foundation provide on macOS.
// They live here because every UI stub module (ImageIO, AppKit, SwiftUI, Charts) re-exports CoreGraphics.

// MARK: CoreGraphics geometry

@frozen public struct CGAffineTransform: Equatable, Sendable {
    public var a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat
    public init() { a = 1; b = 0; c = 0; d = 1; tx = 0; ty = 0 }
    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }
    public init(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat, _ tx: CGFloat, _ ty: CGFloat) {
        self.init(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }
    public init(translationX tx: CGFloat, y ty: CGFloat) { self.init(a: 1, b: 0, c: 0, d: 1, tx: tx, ty: ty) }
    public init(scaleX sx: CGFloat, y sy: CGFloat) { self.init(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0) }
    public init(rotationAngle angle: CGFloat) { self.init() }
    public static let identity = CGAffineTransform()
    public var isIdentity: Bool { self == .identity }
    public func translatedBy(x tx: CGFloat, y ty: CGFloat) -> CGAffineTransform { self }
    public func scaledBy(x sx: CGFloat, y sy: CGFloat) -> CGAffineTransform { self }
    public func rotated(by angle: CGFloat) -> CGAffineTransform { self }
    public func inverted() -> CGAffineTransform { self }
    public func concatenating(_ t2: CGAffineTransform) -> CGAffineTransform { self }
}

extension CGPoint { public func applying(_ t: CGAffineTransform) -> CGPoint { self } }
extension CGSize { public func applying(_ t: CGAffineTransform) -> CGSize { self } }
extension CGRect { public func applying(_ t: CGAffineTransform) -> CGRect { self } }

@frozen public struct CGVector: Equatable, Hashable, Sendable {
    public var dx: CGFloat
    public var dy: CGFloat
    public init() { dx = 0; dy = 0 }
    public init(dx: CGFloat, dy: CGFloat) { self.dx = dx; self.dy = dy }
    public init(dx: Double, dy: Double) { self.dx = CGFloat(dx); self.dy = CGFloat(dy) }
    public init(dx: Int, dy: Int) { self.dx = CGFloat(dx); self.dy = CGFloat(dy) }
    public static var zero: CGVector { CGVector() }
}

// MARK: Foundation

extension String.StandardComparator {
    /// Darwin Foundation: Finder-like localized comparison.
    public static let localizedStandard = String.StandardComparator(.lexical, order: .forward)
    /// Darwin Foundation: localized comparison.
    public static let localized = String.StandardComparator(.lexical, order: .forward)
}

open class UndoManager: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open var canUndo: Bool { false }
    open var canRedo: Bool { false }
    open func undo() {}
    open func redo() {}
    open func removeAllActions() {}
}

/// Darwin stdlib (ObjC interop) pointer type used by Foundation out-parameters; never instantiated here.
@frozen public struct AutoreleasingUnsafeMutablePointer<Pointee>: Equatable {
    public var pointee: Pointee { get { fatalError() } nonmutating set {} }
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension FileManager {
    /// Darwin Foundation: moves an item to the Trash.
    public func trashItem(at url: URL, resultingItemURL outResultingURL: AutoreleasingUnsafeMutablePointer<NSURL?>?) throws {}
}

// Mach-O CPU types for `Bundle.executableArchitectures` (NSBundle.h).
public var NSBundleExecutableArchitectureI386: Int { 0x00000007 }
public var NSBundleExecutableArchitecturePPC: Int { 0x00000012 }
public var NSBundleExecutableArchitectureX86_64: Int { 0x01000007 }
public var NSBundleExecutableArchitecturePPC64: Int { 0x01000012 }
public var NSBundleExecutableArchitectureARM64: Int { 0x0100000c }

// Markdown parsing (Darwin Foundation only).
extension AttributedString {
    public struct MarkdownParsingOptions: Sendable {
        public enum FailurePolicy: Int, Sendable, Hashable { case throwError, returnPartiallyParsedIfPossible }
        public enum InterpretedSyntax: Int, Sendable, Hashable { case full, inlineOnly, inlineOnlyPreservingWhitespace }
        public var allowsExtendedAttributes: Bool
        public var interpretedSyntax: AttributedString.MarkdownParsingOptions.InterpretedSyntax
        public var failurePolicy: AttributedString.MarkdownParsingOptions.FailurePolicy
        public var languageCode: String?
        public var appliesSourcePositionAttributes: Bool
        public init(allowsExtendedAttributes: Bool = false, interpretedSyntax: AttributedString.MarkdownParsingOptions.InterpretedSyntax = .full,
                    failurePolicy: AttributedString.MarkdownParsingOptions.FailurePolicy = .throwError, languageCode: String? = nil) {
            self.allowsExtendedAttributes = allowsExtendedAttributes; self.interpretedSyntax = interpretedSyntax
            self.failurePolicy = failurePolicy; self.languageCode = languageCode; appliesSourcePositionAttributes = false
        }
        public init(allowsExtendedAttributes: Bool = false, interpretedSyntax: AttributedString.MarkdownParsingOptions.InterpretedSyntax = .full,
                    failurePolicy: AttributedString.MarkdownParsingOptions.FailurePolicy = .throwError, languageCode: String? = nil,
                    appliesSourcePositionAttributes: Bool = false) {
            self.init(allowsExtendedAttributes: allowsExtendedAttributes, interpretedSyntax: interpretedSyntax, failurePolicy: failurePolicy, languageCode: languageCode)
            self.appliesSourcePositionAttributes = appliesSourcePositionAttributes
        }
    }
    public init(markdown: String, options: AttributedString.MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws { self.init(markdown) }
    public init(markdown: Data, options: AttributedString.MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws { self.init() }
}
