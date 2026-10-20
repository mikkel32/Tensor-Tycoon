// Stub of the CryptoKit APIs the updater uses (SHA-256 and Ed25519 signature verification).
import Foundation

public protocol Digest: ContiguousBytes, CustomStringConvertible, Hashable, Sendable, Sequence where Self.Element == UInt8 {
    static var byteCount: Int { get }
}

public protocol HashFunction: Sendable {
    static var blockByteCount: Int { get }
    associatedtype Digest: CryptoKit.Digest
    init()
    mutating func update(bufferPointer: UnsafeRawBufferPointer)
    func finalize() -> Self.Digest
}

extension HashFunction {
    public static func hash<D>(data: D) -> Self.Digest where D: DataProtocol { var h = Self(); h.update(data: data); return h.finalize() }
    public mutating func update<D>(data: D) where D: DataProtocol {}
}

public struct SHA256Digest: Digest {
    public static var byteCount: Int { 32 }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try [UInt8]().withUnsafeBytes(body) }
    public var description: String { "" }
    public typealias Element = UInt8
    public typealias Iterator = Array<UInt8>.Iterator
    public func makeIterator() -> Array<UInt8>.Iterator { [UInt8]().makeIterator() }
}

public struct SHA256: HashFunction {
    public static let blockByteCount: Int = 64
    public static let byteCount: Int = 32
    public typealias Digest = SHA256Digest
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {}
    public func finalize() -> SHA256.Digest { SHA256Digest() }
}

public struct CryptoKitError: Error { }

public enum Curve25519: Sendable {
    public enum Signing: Sendable {
        public struct PublicKey: Sendable {
            public init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {}
            public var rawRepresentation: Data { Data() }
            public func isValidSignature<S, D>(_ signature: S, for data: D) -> Bool where S: DataProtocol, D: DataProtocol { false }
        }
        public struct PrivateKey: Sendable {
            public init() {}
            public init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {}
            public var rawRepresentation: Data { Data() }
            public var publicKey: Curve25519.Signing.PublicKey { fatalError() }
            public func signature<D>(for data: D) throws -> Data where D: DataProtocol { Data() }
        }
    }
}
