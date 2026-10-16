import Foundation

/// A year + month pair used by the static catalogs (release dates etc).
struct YM: Hashable, Comparable, Sendable, Codable {
    let year: Int
    let month: Int

    init(_ year: Int, _ month: Int) {
        self.year = year
        self.month = month
    }

    /// Fractional year, e.g. 2023.5 for July 2023 (month start).
    var decimal: Double { Double(year) + Double(month - 1) / 12.0 }

    var date: Date { GameCalendar.date(year, month, 1) }

    var label: String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(names[max(0, min(11, month - 1))]) \(year)"
    }

    static func < (lhs: YM, rhs: YM) -> Bool {
        lhs.year != rhs.year ? lhs.year < rhs.year : lhs.month < rhs.month
    }

    func adding(months n: Int) -> YM {
        let total = year * 12 + (month - 1) + n
        return YM(total / 12, total % 12 + 1)
    }
}

enum GameCalendar {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    static func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }

    static func addMonths(_ date: Date, _ months: Int) -> Date {
        calendar.date(byAdding: .month, value: months, to: date)!
    }

    static func components(_ date: Date) -> (year: Int, month: Int, day: Int) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year!, c.month!, c.day!)
    }

    static func ym(_ date: Date) -> YM {
        let c = components(date)
        return YM(c.year, c.month)
    }

    /// Fractional year including the day, e.g. 2024.37
    static func decimalYear(_ date: Date) -> Double {
        let c = components(date)
        let daysInMonth = Double(calendar.range(of: .day, in: .month, for: date)?.count ?? 30)
        return Double(c.year) + (Double(c.month - 1) + Double(c.day - 1) / daysInMonth) / 12.0
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func daysInMonth(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "EEE d MMM yyyy"
        return f
    }()

    static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "MMM yyyy"
        return f
    }()
}

extension Date {
    var gameLong: String { GameCalendar.longFormatter.string(from: self) }
    var gameShort: String { GameCalendar.shortFormatter.string(from: self) }
    var gameMonth: String { GameCalendar.monthFormatter.string(from: self) }
    var ym: YM { GameCalendar.ym(self) }
    var decimalYear: Double { GameCalendar.decimalYear(self) }
}

/// Piecewise-linear interpolation over (x, y) anchor points. Clamps at the ends
/// unless `extrapolate` is set, in which case the last segment's slope continues.
func interpolate(_ points: [(Double, Double)], at x: Double, extrapolate: Bool = false) -> Double {
    guard let first = points.first, let last = points.last else { return 0 }
    if x <= first.0 { return first.1 }
    if x >= last.0 {
        guard extrapolate, points.count >= 2 else { return last.1 }
        let p = points[points.count - 2]
        let slope = (last.1 - p.1) / (last.0 - p.0)
        return last.1 + slope * (x - last.0)
    }
    for i in 1..<points.count where x <= points[i].0 {
        let a = points[i - 1], b = points[i]
        let t = (x - a.0) / (b.0 - a.0)
        return a.1 + (b.1 - a.1) * t
    }
    return last.1
}

/// Interpolates in log space (for quantities that grow exponentially).
func interpolateLog(_ points: [(Double, Double)], at x: Double, extrapolate: Bool = false) -> Double {
    exp(interpolate(points.map { ($0.0, log(max($0.1, 1e-12))) }, at: x, extrapolate: extrapolate))
}

func sigmoid(_ x: Double) -> Double { 1.0 / (1.0 + exp(-x)) }

func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }
