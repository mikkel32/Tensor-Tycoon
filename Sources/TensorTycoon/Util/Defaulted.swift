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
/// Missing keys decode as `T.defaultValue` instead of failing. A field that is present but can't be read (a newer
/// format, a damaged file) also falls back to its default so the save still opens, but it is recorded in
/// `SaveRepairs` so the game can say which part of the save was reset instead of losing it silently.
@propertyWrapper
struct D<T: Codable & DefaultValue>: Codable {
    var wrappedValue: T

    init(wrappedValue: T) { self.wrappedValue = wrappedValue }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            wrappedValue = T.defaultValue
            return
        }
        do {
            wrappedValue = try c.decode(T.self)
        } catch {
            SaveRepairs.note(decoder.codingPath, error)
            wrappedValue = T.defaultValue
        }
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
        do {
            return try decodeIfPresent(type, forKey: key) ?? D(wrappedValue: T.defaultValue)
        } catch {
            SaveRepairs.note(codingPath + [key], error)
            return D(wrappedValue: T.defaultValue)
        }
    }
}

/// Parts of a save that couldn't be read and were reset to their defaults during the last decode.
enum SaveRepairs {
    nonisolated(unsafe) private static var paths: [String] = []
    private static let lock = NSLock()

    static func note(_ path: [CodingKey], _ error: Error) {
        let name = path.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
        lock.lock()
        defer { lock.unlock() }
        if paths.count < 50 { paths.append(name.isEmpty ? "(root)" : name) }
    }

    /// Starts a fresh record (call before decoding a save).
    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        paths = []
    }

    /// What was reset since the last `reset()`, outermost sections first.
    static func taken() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return paths.sorted { $0.count < $1.count }
    }
}

/// The save file's JSON settings, shared by the game, the save list and `--check-save`. Non-finite numbers are written
/// as strings, so one NaN somewhere in the simulation can't stop the game from saving.
enum SaveCoding {
    static func encoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        enc.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return enc
    }

    static func decoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        dec.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return dec
    }
}
