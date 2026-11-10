import Foundation
import Testing

@testable import TokenyCore

@Suite("Month forecast")
struct MonthForecastTests {
    private let prague = TimeZone(identifier: "Europe/Prague")!
    /// 2026-11-15 12:00 in Prague (CET). 30-day month, 15.5 days left.
    private let noon15 = Date(timeIntervalSince1970: 1_794_740_400)

    @Test func constantSpendProjectsExactly() {
        let forecast = MonthForecastMath.forecast(daily: days("2026-10-01", 46, { _ in 2 }), firstDataDay: "2026-10-01", now: noon15, timeZone: prague)
        #expect(forecast.period == "2026-11")
        #expect(close(forecast.spentUSD, 30))
        #expect(close(forecast.dailyRateUSD ?? -1, 2))
        #expect(close(forecast.forecastUSD ?? -1, 30 + 2 * 15.5))
        #expect(close(forecast.lowUSD ?? -1, forecast.forecastUSD ?? 0))
        #expect(close(forecast.highUSD ?? -1, forecast.forecastUSD ?? 0))
        #expect(forecast.confidence == .high)
        #expect(forecast.daysObserved == 28)
        #expect(forecast.method == "weighted_run_rate")
    }

    @Test func recentDaysWeighMore() {
        let daily = days("2026-10-01", 45) { $0 >= 38 && $0 <= 44 ? 5.0 : 1 }
        let forecast = MonthForecastMath.forecast(daily: daily, firstDataDay: "2026-10-01", now: noon15, timeZone: prague)
        let plain = (7.0 * 5 + 21.0 * 1) / 28
        let rate = forecast.dailyRateUSD ?? 0
        #expect(rate > plain)
        #expect(rate < 5)
    }

    @Test func noDataHasNoForecast() {
        let forecast = MonthForecastMath.forecast(daily: [:], firstDataDay: nil, now: noon15, timeZone: prague)
        #expect(forecast.forecastUSD == nil)
        #expect(forecast.confidence == .none)
        #expect(forecast.spentUSD == 0)
    }

    @Test func todayOnlyHasSpentButNoRate() {
        let forecast = MonthForecastMath.forecast(daily: ["2026-11-15": 3], firstDataDay: "2026-11-15", now: noon15, timeZone: prague)
        #expect(forecast.spentUSD == 3)
        #expect(forecast.forecastUSD == nil)
        #expect(forecast.daysObserved == 0)
    }

    @Test func fewDaysStayAtLeastAtSpent() {
        let forecast = MonthForecastMath.forecast(
            daily: ["2026-11-13": 1, "2026-11-14": 3, "2026-11-15": 1], firstDataDay: "2026-11-13", now: noon15, timeZone: prague)
        #expect(forecast.daysObserved == 2)
        #expect(forecast.confidence == .low)
        #expect((forecast.lowUSD ?? 0) >= forecast.spentUSD)
        #expect((forecast.highUSD ?? 0) - (forecast.lowUSD ?? 0) > 10)
    }

    @Test func daysBeforeFirstUsageAreNotZeros() {
        let forecast = MonthForecastMath.forecast(
            daily: ["2026-11-10": 4, "2026-11-11": 4, "2026-11-12": 4, "2026-11-13": 4, "2026-11-14": 4],
            firstDataDay: "2026-11-10", now: noon15, timeZone: prague)
        #expect(forecast.daysObserved == 5)
        #expect(close(forecast.dailyRateUSD ?? -1, 4))
        #expect(forecast.confidence == .low)
    }

    @Test func firstDayOfMonthUsesLastMonth() {
        let now = Date(timeIntervalSince1970: 1_793_487_600) // 2026-10-31T23:00:00Z = 2026-11-01 00:00 Prague
        let forecast = MonthForecastMath.forecast(daily: days("2026-10-01", 31, { _ in 1 }), firstDataDay: "2026-10-01", now: now, timeZone: prague)
        #expect(forecast.spentUSD == 0)
        #expect(close(forecast.forecastUSD ?? -1, 30))
    }

    private func days(_ from: String, _ count: Int, _ value: (Int) -> Double) -> [String: Double] {
        var out: [String: Double] = [:]
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        let start = parser.date(from: from + "T00:00:00Z")!
        for index in 0..<count {
            let day = MonthForecastMath.localDay(
                start.addingTimeInterval(Double(index) * 86_400), timeZone: TimeZone(secondsFromGMT: 0)!)
            out[day] = value(index)
        }
        return out
    }

    private func close(_ actual: Double, _ expected: Double) -> Bool {
        abs(actual - expected) < 0.000_001
    }
}
