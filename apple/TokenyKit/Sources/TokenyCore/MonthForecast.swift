import Foundation

/// Month-end spend forecast. Same weighted run-rate as `server/lib/forecast.ts`.
///
/// Pure: no network. Days are calendar days in the given time zone. Today is still running, so the
/// rate learns from complete days only. The result is a calculation on this device. It is not the
/// Pro forecast the server returns in `UsageSummary.forecastMonthUSD`.
public struct MonthForecast: Codable, Equatable, Sendable {
    public enum Confidence: String, Codable, Sendable {
        case none, low, medium, high
    }

    public var period: String
    public var spentUSD: Double
    public var forecastUSD: Double?
    public var lowUSD: Double?
    public var highUSD: Double?
    public var dailyRateUSD: Double?
    public var confidence: Confidence
    public var daysObserved: Int
    public var dayOfMonth: Int
    public var daysInMonth: Int
    public var daysRemaining: Double
    /// Always `weighted_run_rate`, matching the server field `method`.
    public var method: String

    public init(
        period: String, spentUSD: Double, forecastUSD: Double?, lowUSD: Double?, highUSD: Double?,
        dailyRateUSD: Double?, confidence: Confidence, daysObserved: Int, dayOfMonth: Int,
        daysInMonth: Int, daysRemaining: Double, method: String = "weighted_run_rate"
    ) {
        self.period = period
        self.spentUSD = spentUSD
        self.forecastUSD = forecastUSD
        self.lowUSD = lowUSD
        self.highUSD = highUSD
        self.dailyRateUSD = dailyRateUSD
        self.confidence = confidence
        self.daysObserved = daysObserved
        self.dayOfMonth = dayOfMonth
        self.daysInMonth = daysInMonth
        self.daysRemaining = daysRemaining
        self.method = method
    }
}

public enum MonthForecastMath {
    public static let windowDays = 28
    public static let halfLifeDays = 7.0
    public static let z80 = 1.2816
    public static let defaultTimeZone = TimeZone(identifier: "Europe/Prague")!

    /// "YYYY-MM-DD" of `date` in `timeZone`.
    public static func localDay(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Calendar arithmetic on "YYYY-MM-DD" in UTC, matching `addDays` in forecast.ts.
    public static func addDays(_ day: String, _ count: Int) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return day }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
        let next = utc.date(byAdding: .day, value: count, to: start) ?? start
        let c = utc.dateComponents([.year, .month, .day], from: next)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// UTC milliseconds of local midnight that starts `day` in `timeZone` (two-pass offset, DST-safe).
    public static func localMidnight(day: String, timeZone: TimeZone) -> Double {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return 0 }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let wallDate = utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
        let wall = wallDate.timeIntervalSince1970 * 1000
        var t = wall - offsetMs(at: wall, timeZone: timeZone)
        t = wall - offsetMs(at: t, timeZone: timeZone)
        return t
    }

    public static func forecast(
        daily: [String: Double], firstDataDay: String?, now: Date = Date(), timeZone: TimeZone = defaultTimeZone
    ) -> MonthForecast {
        let today = localDay(now, timeZone: timeZone)
        let pieces = today.split(separator: "-").compactMap { Int($0) }
        let year = pieces.count == 3 ? pieces[0] : 1970
        let month = pieces.count == 3 ? pieces[1] : 1
        let dayOfMonth = pieces.count == 3 ? pieces[2] : 1
        let period = String(today.prefix(7))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let daysInMonth = utc.range(of: .day, in: .month, for: utc.date(from: DateComponents(year: year, month: month, day: 1))!)?.count ?? 30
        let todayStart = localMidnight(day: today, timeZone: timeZone)
        let todayLength = localMidnight(day: addDays(today, 1), timeZone: timeZone) - todayStart
        let nowMs = now.timeIntervalSince1970 * 1000
        let elapsed = todayLength > 0 ? min(1, max(0, (nowMs - todayStart) / todayLength)) : 0
        let daysRemaining = Double(daysInMonth - dayOfMonth) + (1 - elapsed)

        var spent = 0.0
        for (day, value) in daily where day.hasPrefix(period) && day <= today {
            spent += value
        }

        var observed: [(age: Int, value: Double)] = []
        if let first = firstDataDay?.prefix(10) {
            let firstDay = String(first)
            for age in 0..<windowDays {
                let day = addDays(today, -(age + 1))
                if day < firstDay { break }
                observed.append((age, max(0, daily[day] ?? 0)))
            }
        }
        let count = observed.count
        let baseSpent = round6(spent)
        let baseRemaining = round6(daysRemaining)
        if count == 0 {
            return MonthForecast(
                period: period, spentUSD: baseSpent, forecastUSD: nil, lowUSD: nil, highUSD: nil,
                dailyRateUSD: nil, confidence: .none, daysObserved: 0, dayOfMonth: dayOfMonth,
                daysInMonth: daysInMonth, daysRemaining: baseRemaining)
        }

        var weightSum = 0.0
        var weightSquare = 0.0
        var weightedValues = 0.0
        for item in observed {
            let weight = pow(0.5, Double(item.age) / halfLifeDays)
            weightSum += weight
            weightSquare += weight * weight
            weightedValues += weight * item.value
        }
        let rate = weightedValues / weightSum
        var weightedVariance = 0.0
        for item in observed {
            let weight = pow(0.5, Double(item.age) / halfLifeDays)
            weightedVariance += weight * (item.value - rate) * (item.value - rate)
        }
        weightedVariance /= weightSum
        let effective = (weightSum * weightSum) / weightSquare
        let sd = count > 1 ? sqrt(weightedVariance * (effective / max(effective - 1, 1e-9))) : rate
        let remaining = daysRemaining
        let total = sqrt(remaining * sd * sd + (remaining * sd) * (remaining * sd) / effective)
        let point = spent + rate * remaining
        let confidence: MonthForecast.Confidence = count < 7 ? .low : count < 14 ? .medium : .high
        return MonthForecast(
            period: period, spentUSD: baseSpent, forecastUSD: round6(point),
            lowUSD: round6(max(spent, point - z80 * total)), highUSD: round6(point + z80 * total),
            dailyRateUSD: round6(rate), confidence: confidence, daysObserved: count,
            dayOfMonth: dayOfMonth, daysInMonth: daysInMonth, daysRemaining: baseRemaining)
    }

    /// UTC offset of `timeZone` at `at` milliseconds, matching `offsetMs` in forecast.ts.
    static func offsetMs(at: Double, timeZone: TimeZone) -> Double {
        let date = Date(timeIntervalSince1970: at / 1000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let wall = utc.date(from: DateComponents(
            year: parts.year, month: parts.month, day: parts.day,
            hour: (parts.hour ?? 0) % 24, minute: parts.minute, second: parts.second
        )) ?? date
        return wall.timeIntervalSince1970 * 1000 - floor(at / 1000) * 1000
    }

    static func round6(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }
}
