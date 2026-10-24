import Foundation

/// Deterministic, saveable RNG (SplitMix64) so a saved game replays identically.
struct GameRNG: RandomNumberGenerator, Codable, Sendable {
    var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * unit() }

    mutating func chance(_ p: Double) -> Bool { unit() < p }

    /// Approximately normal(0, 1) via Box–Muller.
    mutating func gaussian() -> Double {
        let u1 = max(unit(), 1e-12), u2 = unit()
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    mutating func pick<T>(_ items: [T]) -> T { items[Int(next() % UInt64(items.count))] }

    mutating func int(_ lo: Int, _ hi: Int) -> Int { lo + Int(next() % UInt64(max(1, hi - lo + 1))) }
}

enum Fmt {
    /// $1.23B, $450K, $12.50
    static func money(_ v: Double, decimals: Int = 1) -> String {
        let sign = v < 0 ? "-" : ""
        let a = abs(v)
        switch a {
        case 1e12...: return "\(sign)$\(trim(a / 1e12, decimals))T"
        case 1e9...: return "\(sign)$\(trim(a / 1e9, decimals))B"
        case 1e6...: return "\(sign)$\(trim(a / 1e6, decimals))M"
        case 1e4...: return "\(sign)$\(trim(a / 1e3, decimals))K"
        case 100...: return "\(sign)$\(Int(a.rounded()))"
        default: return "\(sign)$\(String(format: "%.2f", a))"
        }
    }

    static func price(_ v: Double) -> String {
        if v >= 100 { return money(v) }
        if v < 0.01 { return "$" + String(format: "%.4f", v) }
        return "$" + String(format: v < 1 ? "%.3f" : "%.2f", v)
    }

    static func trim(_ v: Double, _ decimals: Int) -> String {
        let s = String(format: "%.\(decimals)f", v)
        if s.contains(".") {
            var t = s
            while t.hasSuffix("0") { t.removeLast() }
            if t.hasSuffix(".") { t.removeLast() }
            return t
        }
        return s
    }

    /// 1.2K, 3.4M, 5B
    static func count(_ v: Double, decimals: Int = 1) -> String {
        let a = abs(v), sign = v < 0 ? "-" : ""
        switch a {
        case 1e15...: return "\(sign)\(trim(a / 1e15, decimals))Q"
        case 1e12...: return "\(sign)\(trim(a / 1e12, decimals))T"
        case 1e9...: return "\(sign)\(trim(a / 1e9, decimals))B"
        case 1e6...: return "\(sign)\(trim(a / 1e6, decimals))M"
        case 1e3...: return "\(sign)\(trim(a / 1e3, decimals))K"
        default: return "\(sign)\(trim(a, a < 10 ? decimals : 0))"
        }
    }

    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    static func int(_ v: Int) -> String {
        intFormatter.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    /// Parameter counts given in billions: 0.35B -> "350M", 1750 -> "1.75T"
    static func params(_ billions: Double) -> String {
        if billions >= 1000 { return "\(trim(billions / 1000, 2))T" }
        if billions >= 1 { return "\(trim(billions, billions < 10 ? 1 : 0))B" }
        return "\(trim(billions * 1000, 0))M"
    }

    /// Token counts given in trillions.
    static func tokens(_ trillions: Double) -> String {
        if trillions >= 1 { return "\(trim(trillions, 1))T" }
        if trillions >= 0.001 { return "\(trim(trillions * 1000, 0))B" }
        return "\(trim(trillions * 1e6, 0))M"
    }

    /// FLOPs as scientific: 2.1e25
    static func flops(_ v: Double) -> String {
        guard v > 0 else { return "0" }
        let e = floor(log10(v))
        let m = v / pow(10, e)
        return String(format: "%.1fe%d", m, Int(e))
    }

    /// TFLOPS → "989 TF" / "4.6 PF" / "42.5 EF"
    static func tflops(_ tf: Double) -> String {
        switch tf {
        case 1e6...: return "\(trim(tf / 1e6, 1)) EF"
        case 1e3...: return "\(trim(tf / 1e3, 1)) PF"
        default: return "\(trim(tf, tf < 10 ? 1 : 0)) TF"
        }
    }

    static func watts(_ w: Double) -> String {
        switch w {
        case 1e9...: return "\(trim(w / 1e9, 2)) GW"
        case 1e6...: return "\(trim(w / 1e6, 1)) MW"
        case 1e3...: return "\(trim(w / 1e3, 1)) kW"
        default: return "\(Int(w)) W"
        }
    }

    static func pct(_ v: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", v * 100)
    }

    static func score(_ v: Double) -> String { String(format: "%.1f", v) }

    static func odds(_ p: Double) -> String {
        let x = clamp(p, 0, 1)
        if x <= 0 { return "0%" }
        if x >= 1 { return "100%" }
        if x < 0.01 { return String(format: "%.2f%%", x * 100) }
        if x < 0.1 { return String(format: "%.1f%%", x * 100) }
        return "\(Int((x * 100).rounded()))%"
    }

    static func days(_ d: Double) -> String {
        if d.isInfinite || d.isNaN { return "∞" }
        if d >= 730 { return "\(trim(d / 365, 1)) yrs" }
        if d >= 60 { return "\(trim(d / 30.4, 1)) mo" }
        return "\(Int(d.rounded(.up))) days"
    }

    static func memory(_ gb: Double) -> String {
        if gb >= 1000 { return "\(trim(gb / 1000, 1)) TB" }
        if gb < 1 { return "\(Int((gb * 1000).rounded())) MB" }
        return "\(trim(gb, gb < 10 ? 1 : 0)) GB"
    }
}
