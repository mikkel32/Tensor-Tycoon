// Stub of the parts of CoreGraphics (and the CoreFoundation types it re-exports on Darwin) that the app uses.
// On Linux, CGFloat / CGPoint / CGSize / CGRect / CGAffineTransform already come from swift-corelibs-foundation,
// so this module only adds what corelibs lacks.
@_exported import Foundation

// MARK: - CoreFoundation types
//
// DELIBERATE RELAXATION: on Darwin CFString / CFURL / CFDictionary / CFArray / CFData are distinct CF classes that are
// toll-free bridged with their NS counterparts, so `url as CFURL` and `dict as CFDictionary` compile. Linux's
// CoreFoundation has no bridging, so here they are aliases of the NS classes (which do bridge with `as` on Linux).
// Net effect: code may pass an NSString where a CFString is expected, which Darwin rejects without a cast.
public typealias CFString = NSString
public typealias CFURL = NSURL
public typealias CFDictionary = NSDictionary
public typealias CFArray = NSArray
public typealias CFData = NSData
public typealias CFTypeRef = AnyObject

// MARK: - CGImage

/// A bitmap image (stub; never instantiated on Linux).
public final class CGImage: @unchecked Sendable {
    internal init() {}
    public var width: Int { 0 }
    public var height: Int { 0 }
    public var bitsPerComponent: Int { 0 }
    public var bitsPerPixel: Int { 0 }
    public var bytesPerRow: Int { 0 }
    public var isMask: Bool { false }
    public var colorSpace: CGColorSpace? { nil }
    public func cropping(to rect: CGRect) -> CGImage? { nil }
}

public final class CGColorSpace: @unchecked Sendable {
    internal init() {}
    public var name: CFString? { nil }
}

public final class CGColor: @unchecked Sendable {
    internal init() {}
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
    public init(gray: CGFloat, alpha: CGFloat) {}
    public var alpha: CGFloat { 1 }
    public var components: [CGFloat]? { nil }
    public var numberOfComponents: Int { 0 }
    public static let black = CGColor()
    public static let white = CGColor()
    public static let clear = CGColor()
}

public enum CGLineCap: Int32, Sendable { case butt = 0, round = 1, square = 2 }
public enum CGLineJoin: Int32, Sendable { case miter = 0, round = 1, bevel = 2 }

public final class CGPath: @unchecked Sendable { internal init() {} }
public final class CGMutablePath: @unchecked Sendable { public init() {} }
