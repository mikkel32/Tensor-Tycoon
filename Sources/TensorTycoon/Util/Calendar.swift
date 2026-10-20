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

    // Game dates are UTC (no daylight saving, no leap seconds), so whole days are exactly 86,400 s and the civil
    // calendar can be computed with integer arithmetic. Foundation's Calendar was a quarter of the simulation's time
    // (`s.year` alone made two Calendar calls); these give identical answers (`--calendar-check` compares them).

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        // Calendar normalises out-of-range components (month 13, day 0); fall back to it for those.
        guard (1...12).contains(month), day >= 1, day <= monthLength(year, month) else {
            return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }
        return Date(timeIntervalSince1970: Double(daysFromCivil(year, month, day)) * 86_400 + 43_200)
    }

    static func addDays(_ date: Date, _ days: Int) -> Date {
        date.addingTimeInterval(Double(days) * 86_400)
    }

    static func addMonths(_ date: Date, _ months: Int) -> Date {
        calendar.date(byAdding: .month, value: months, to: date)!
    }

    static func components(_ date: Date) -> (year: Int, month: Int, day: Int) {
        civilFromDays(Int((date.timeIntervalSince1970 / 86_400).rounded(.down)))
    }

    static func ym(_ date: Date) -> YM {
        let c = components(date)
        return YM(c.year, c.month)
    }

    /// Fractional year including the day, e.g. 2024.37
    static func decimalYear(_ date: Date) -> Double {
        let c = components(date)
        let daysInMonth = Double(monthLength(c.year, c.month))
        return Double(c.year) + (Double(c.month - 1) + Double(c.day - 1) / daysInMonth) / 12.0
    }

    /// Whole days from `a` to `b`, truncated toward zero (as Calendar counts them).
    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        Int(b.timeIntervalSince(a) / 86_400)
    }

    static func daysInMonth(_ date: Date) -> Int {
        let c = components(date)
        return monthLength(c.year, c.month)
    }

    static func monthLength(_ year: Int, _ month: Int) -> Int {
        switch month {
        case 2: return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// Days since 1970-01-01 of a proleptic Gregorian date (H. Hinnant's algorithm).
    static func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// The civil date of a day count since 1970-01-01.
    static func civilFromDays(_ z0: Int) -> (year: Int, month: Int, day: Int) {
        let z = z0 + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }

    /// Compares the integer calendar with Foundation's over 1990–2100 at noon and odd times of day.
    static func selfCheck() -> Int {
        var bad = 0
        for day in daysFromCivil(1990, 1, 1)...daysFromCivil(2100, 12, 31) {
            for offset in [43_200.0, 0, 3_599.5, 86_399] {
                let t = Date(timeIntervalSince1970: Double(day) * 86_400 + offset)
                let c = calendar.dateComponents([.year, .month, .day], from: t)
                let mine = components(t)
                if mine.year != c.year! || mine.month != c.month! || mine.day != c.day! { bad += 1 }
                if monthLength(mine.year, mine.month) != calendar.range(of: .day, in: .month, for: t)!.count { bad += 1 }
                if offset == 43_200 {
                    if date(mine.year, mine.month, mine.day) != calendar.date(from: DateComponents(year: c.year, month: c.month, day: c.day, hour: 12))! { bad += 1 }
                    for n in [1, 7, 30, 365, -1, -400] {
                        if addDays(t, n) != calendar.date(byAdding: .day, value: n, to: t)! { bad += 1 }
                    }
                }
                for other in [t.addingTimeInterval(86_400 * 3), t.addingTimeInterval(-86_400 * 40 + 5_000), t.addingTimeInterval(80_000)] {
                    if daysBetween(t, other) != (calendar.dateComponents([.day], from: t, to: other).day ?? 0) { bad += 1 }
                }
            }
        }
        return bad
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
