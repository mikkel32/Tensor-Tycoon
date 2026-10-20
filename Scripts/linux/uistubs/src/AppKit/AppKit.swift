// Stub of the AppKit surface the app touches. Real AppKit re-exports Foundation, which on Darwin re-exports
// Clang-imported AppKit declarations marked NS_SWIFT_UI_ACTOR behave as `@MainActor @preconcurrency` in Swift; the
// stub spells that out so Swift 5 mode diagnoses isolation the same way.
// Observation; mirror that so `import AppKit` (and `import SwiftUI`, which re-exports AppKit on macOS) sees @Observable.
@_exported import Foundation
@_exported import CoreGraphics
@_exported import Observation

// MARK: - NSResponder / NSApplication

@MainActor @preconcurrency open class NSResponder: NSObject {
    public override init() { super.init() }
    open var nextResponder: NSResponder?
}

@MainActor @preconcurrency public protocol NSApplicationDelegate: NSObjectProtocol {
    // DELIBERATE RELAXATION: these are `@objc optional` requirements on Darwin. Linux has no ObjC interop, so they
    // are ordinary requirements with default implementations in the extension below.
    func applicationWillFinishLaunching(_ notification: Notification)
    func applicationDidFinishLaunching(_ notification: Notification)
    func applicationWillTerminate(_ notification: Notification)
    func applicationDidBecomeActive(_ notification: Notification)
    func applicationDidResignActive(_ notification: Notification)
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
    func application(_ application: NSApplication, open urls: [URL])
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool
}

extension NSApplicationDelegate {
    public func applicationWillFinishLaunching(_ notification: Notification) {}
    public func applicationDidFinishLaunching(_ notification: Notification) {}
    public func applicationWillTerminate(_ notification: Notification) {}
    public func applicationDidBecomeActive(_ notification: Notification) {}
    public func applicationDidResignActive(_ notification: Notification) {}
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateNow }
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { true }
    public func application(_ application: NSApplication, open urls: [URL]) {}
    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { false }
}

@MainActor @preconcurrency open class NSApplication: NSResponder {
    public enum ActivationPolicy: Int, @unchecked Sendable {
        case regular = 0, accessory = 1, prohibited = 2
    }
    public enum TerminateReply: UInt, @unchecked Sendable {
        case terminateCancel = 0, terminateNow = 1, terminateLater = 2
    }
    public enum RequestUserAttentionType: UInt, @unchecked Sendable {
        case criticalRequest = 0, informationalRequest = 10
    }

    open class var shared: NSApplication { fatalError() }
    unowned(unsafe) open var delegate: (any NSApplicationDelegate)?
    open var applicationIconImage: NSImage!
    open var isActive: Bool { false }
    open var isHidden: Bool { false }
    open var windows: [NSWindow] { [] }
    open var keyWindow: NSWindow? { nil }
    open var mainWindow: NSWindow? { nil }
    open var mainMenu: NSMenu?
    open var currentEvent: NSEvent? { nil }
    open var appearance: NSAppearance?
    open var effectiveAppearance: NSAppearance { fatalError() }
    open func activationPolicy() -> NSApplication.ActivationPolicy { .regular }
    @discardableResult open func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool { true }
    open func activate() {}
    @available(macOS, deprecated: 14.0, message: "This method will be deprecated in a future release. Use NSApp.activate instead.")
    open func activate(ignoringOtherApps flag: Bool) {}
    open func deactivate() {}
    open func hide(_ sender: Any?) {}
    open func unhide(_ sender: Any?) {}
    open func terminate(_ sender: Any?) {}
    open func run() {}
    open func stop(_ sender: Any?) {}
    open func reply(toApplicationShouldTerminate shouldTerminate: Bool) {}
    open func requestUserAttention(_ requestType: NSApplication.RequestUserAttentionType) -> Int { 0 }
    open func orderFrontStandardAboutPanel(_ sender: Any?) {}

    nonisolated public static let willTerminateNotification = NSNotification.Name("NSApplicationWillTerminateNotification")
    nonisolated public static let didFinishLaunchingNotification = NSNotification.Name("NSApplicationDidFinishLaunchingNotification")
    nonisolated public static let willFinishLaunchingNotification = NSNotification.Name("NSApplicationWillFinishLaunchingNotification")
    nonisolated public static let didBecomeActiveNotification = NSNotification.Name("NSApplicationDidBecomeActiveNotification")
    nonisolated public static let didResignActiveNotification = NSNotification.Name("NSApplicationDidResignActiveNotification")
    nonisolated public static let willBecomeActiveNotification = NSNotification.Name("NSApplicationWillBecomeActiveNotification")
    nonisolated public static let willResignActiveNotification = NSNotification.Name("NSApplicationWillResignActiveNotification")
    nonisolated public static let didHideNotification = NSNotification.Name("NSApplicationDidHideNotification")
    nonisolated public static let didChangeScreenParametersNotification = NSNotification.Name("NSApplicationDidChangeScreenParametersNotification")
}

/// The global application object (`NSApplication.shared`).
@MainActor @preconcurrency public var NSApp: NSApplication! { NSApplication.shared }

// MARK: - Windows, menus, events (opaque)

@MainActor @preconcurrency open class NSWindow: NSResponder {
    open var title: String = ""
    open var isVisible: Bool { false }
    open var isKeyWindow: Bool { false }
    open var frame: NSRect { .zero }
    open func makeKeyAndOrderFront(_ sender: Any?) {}
    open func close() {}
    open func performClose(_ sender: Any?) {}
    open func orderOut(_ sender: Any?) {}
    open func center() {}
}

@MainActor @preconcurrency open class NSMenu: NSObject {
    public init(title: String) { super.init() }
}

open class NSEvent: NSObject, @unchecked Sendable {
    public struct ModifierFlags: OptionSet, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let capsLock = ModifierFlags(rawValue: 1 << 16)
        public static let shift = ModifierFlags(rawValue: 1 << 17)
        public static let control = ModifierFlags(rawValue: 1 << 18)
        public static let option = ModifierFlags(rawValue: 1 << 19)
        public static let command = ModifierFlags(rawValue: 1 << 20)
        public static let numericPad = ModifierFlags(rawValue: 1 << 21)
        public static let help = ModifierFlags(rawValue: 1 << 22)
        public static let function = ModifierFlags(rawValue: 1 << 23)
        public static let deviceIndependentFlagsMask = ModifierFlags(rawValue: 0xffff0000)
    }
    open class var modifierFlags: NSEvent.ModifierFlags { [] }
    open var modifierFlags: NSEvent.ModifierFlags { [] }
    open var keyCode: UInt16 { 0 }
    open var characters: String? { nil }
    open var charactersIgnoringModifiers: String? { nil }
}

open class NSAppearance: NSObject, @unchecked Sendable {
    public struct Name: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let aqua = Name("NSAppearanceNameAqua")
        public static let darkAqua = Name("NSAppearanceNameDarkAqua")
    }
    public init?(named name: NSAppearance.Name) { super.init() }
    open var name: NSAppearance.Name { .aqua }
    open func bestMatch(from appearances: [NSAppearance.Name]) -> NSAppearance.Name? { nil }
}

// MARK: - NSImage

open class NSImage: NSObject, @unchecked Sendable {
    public typealias Name = String
    public init(size: NSSize) { super.init() }
    public init(cgImage: CGImage, size: NSSize) { super.init() }
    public init?(contentsOf url: URL) { super.init() }
    public init?(contentsOfFile fileName: String) { super.init() }
    public init?(data: Data) { super.init() }
    public init?(named name: NSImage.Name) { super.init() }
    public init?(systemSymbolName name: String, accessibilityDescription description: String?) { super.init() }
    open var size: NSSize = .zero
    open var isTemplate: Bool = false
    open var tiffRepresentation: Data? { nil }
    open func cgImage(forProposedRect proposedDestRect: UnsafeMutablePointer<NSRect>?, context referenceContext: NSGraphicsContext?,
                      hints: [NSImageRep.HintKey: Any]?) -> CGImage? { nil }
}

open class NSImageRep: NSObject, @unchecked Sendable {
    public struct HintKey: RawRepresentable, Hashable, @unchecked Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }
}

open class NSGraphicsContext: NSObject, @unchecked Sendable {}

// MARK: - NSColor

open class NSColor: NSObject, @unchecked Sendable {
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { super.init() }
    public init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { super.init() }
    public init(white: CGFloat, alpha: CGFloat) { super.init() }
    public init?(named name: String) { super.init() }
    public init(name: String?, dynamicProvider: @escaping (NSAppearance) -> NSColor) { super.init() }
    public init?(cgColor: CGColor) { super.init() }
    open var cgColor: CGColor { fatalError() }
    open var alphaComponent: CGFloat { 1 }
    open func withAlphaComponent(_ alpha: CGFloat) -> NSColor { self }
    open func usingColorSpace(_ space: NSColorSpace) -> NSColor? { self }
    open var redComponent: CGFloat { 0 }
    open var greenComponent: CGFloat { 0 }
    open var blueComponent: CGFloat { 0 }

    open class var black: NSColor { fatalError() }
    open class var white: NSColor { fatalError() }
    open class var clear: NSColor { fatalError() }
    open class var red: NSColor { fatalError() }
    open class var green: NSColor { fatalError() }
    open class var blue: NSColor { fatalError() }
    open class var orange: NSColor { fatalError() }
    open class var yellow: NSColor { fatalError() }
    open class var gray: NSColor { fatalError() }
    open class var systemRed: NSColor { fatalError() }
    open class var systemGreen: NSColor { fatalError() }
    open class var systemBlue: NSColor { fatalError() }
    open class var systemOrange: NSColor { fatalError() }
    open class var systemYellow: NSColor { fatalError() }
    open class var systemGray: NSColor { fatalError() }
    open class var labelColor: NSColor { fatalError() }
    open class var secondaryLabelColor: NSColor { fatalError() }
    open class var tertiaryLabelColor: NSColor { fatalError() }
    open class var quaternaryLabelColor: NSColor { fatalError() }
    open class var textColor: NSColor { fatalError() }
    open class var linkColor: NSColor { fatalError() }
    open class var separatorColor: NSColor { fatalError() }
    open class var gridColor: NSColor { fatalError() }
    open class var controlColor: NSColor { fatalError() }
    open class var controlAccentColor: NSColor { fatalError() }
    open class var controlBackgroundColor: NSColor { fatalError() }
    open class var windowBackgroundColor: NSColor { fatalError() }
    open class var underPageBackgroundColor: NSColor { fatalError() }
    open class var textBackgroundColor: NSColor { fatalError() }
    open class var selectedContentBackgroundColor: NSColor { fatalError() }
    open class var unemphasizedSelectedContentBackgroundColor: NSColor { fatalError() }
    open class var alternatingContentBackgroundColors: [NSColor] { [] }
    open class var shadowColor: NSColor { fatalError() }
}

open class NSColorSpace: NSObject, @unchecked Sendable {
    open class var sRGB: NSColorSpace { fatalError() }
    open class var deviceRGB: NSColorSpace { fatalError() }
    open class var genericRGB: NSColorSpace { fatalError() }
}

// MARK: - NSWorkspace / NSPasteboard / NSScreen

open class NSWorkspace: NSObject, @unchecked Sendable {
    open class var shared: NSWorkspace { fatalError() }
    @discardableResult open func open(_ url: URL) -> Bool { false }
    open func activateFileViewerSelecting(_ fileURLs: [URL]) {}
    @discardableResult open func selectFile(_ fullPath: String?, inFileViewerRootedAtPath rootFullPath: String) -> Bool { false }
    open func icon(forFile fullPath: String) -> NSImage { NSImage(size: .zero) }
    open func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL? { nil }
}

open class NSPasteboard: NSObject, @unchecked Sendable {
    public struct PasteboardType: RawRepresentable, Hashable, @unchecked Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let string = PasteboardType("public.utf8-plain-text")
        public static let URL = PasteboardType("public.url")
        public static let fileURL = PasteboardType("public.file-url")
        public static let png = PasteboardType("public.png")
        public static let tiff = PasteboardType("public.tiff")
    }
    open class var general: NSPasteboard { fatalError() }
    @discardableResult open func clearContents() -> Int { 0 }
    @discardableResult open func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool { false }
    @discardableResult open func setData(_ data: Data?, forType dataType: NSPasteboard.PasteboardType) -> Bool { false }
    open func string(forType dataType: NSPasteboard.PasteboardType) -> String? { nil }
    open func data(forType dataType: NSPasteboard.PasteboardType) -> Data? { nil }
}

@MainActor @preconcurrency open class NSScreen: NSObject {
    open class var main: NSScreen? { nil }
    open class var screens: [NSScreen] { [] }
    open var frame: NSRect { .zero }
    open var visibleFrame: NSRect { .zero }
    open var backingScaleFactor: CGFloat { 2 }
}

// MARK: - Sound / haptics (opaque)

open class NSSound: NSObject, @unchecked Sendable {
    public typealias Name = String
    public init?(named name: NSSound.Name) { super.init() }
    @discardableResult open func play() -> Bool { false }
}

public func NSBeep() {}
