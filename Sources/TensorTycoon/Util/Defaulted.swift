import Foundation

/// Types with a sensible "empty" value used when an older save file lacks a newer field.
protocol DefaultValue {
    static var defaultValue: Self { get }
}

extension Double: DefaultValue { static var defaultValue: Double { 0 } }
extension Int: DefaultValue { static var defaultValue: Int { 0 } }
extension UInt64: DefaultValue { static var defaultValue: UInt64 { 0 } }
extension Bool: DefaultValue { static var defaultValue: Bool { false } }
extension String: DefaultValue { static var defaultValue: String { "" } }
extension Array: DefaultValue { static var defaultValue: [Element] { [] } }
extension Set: DefaultValue { static var defaultValue: Set<Element> { [] } }
extension Dictionary: DefaultValue { static var defaultValue: [Key: Value] { [:] } }
extension Optional: DefaultValue { static var defaultValue: Wrapped? { nil } }

/// Property wrapper that lets synthesized `Codable` decode saves that predate a field.
/// Missing keys decode as `T.defaultValue` instead of failing.
@propertyWrapper
struct D<T: Codable & DefaultValue>: Codable {
    var wrappedValue: T

    init(wrappedValue: T) { self.wrappedValue = wrappedValue }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        wrappedValue = (try? c.decode(T.self)) ?? T.defaultValue
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

extension D: Equatable where T: Equatable {}
extension D: Hashable where T: Hashable {}

extension KeyedDecodingContainer {
    func decode<T>(_ type: D<T>.Type, forKey key: Key) throws -> D<T> {
        (try? decodeIfPresent(type, forKey: key)) ?? D(wrappedValue: T.defaultValue)
    }
}
