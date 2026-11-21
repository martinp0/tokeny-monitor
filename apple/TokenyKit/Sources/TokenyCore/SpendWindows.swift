import Foundation

/// The three ranges on the overview. Month uses the month total. The other two sum daily rows.
public enum SpendRange: String, CaseIterable, Sendable, Identifiable {
    case month
    case sevenDays
    case thirtyDays

    public var id: String { rawValue }
}

public struct SpendSlice: Equatable, Sendable {
    public var costUSD: Double
    public var daily: [UsageSummary.Day]
    /// `(current - previous) / previous` for the month, when the previous month cost is positive.
    public var delta: Double?

    public init(costUSD: Double, daily: [UsageSummary.Day], delta: Double?) {
        self.costUSD = costUSD
        self.daily = daily
        self.delta = delta
    }
}

public enum SpendWindows {
    public static func slice(
        daily: [UsageSummary.Day], monthCostUSD: Double, previousMonthUSD: Double?, range: SpendRange, today: String
    ) -> SpendSlice {
        switch range {
        case .month:
            let month = String(today.prefix(7))
            let days = daily.filter { String($0.date.prefix(7)) == month && $0.date <= today }
                .sorted { $0.date < $1.date }
            let delta: Double?
            if let previousMonthUSD, previousMonthUSD > 0 {
                delta = (monthCostUSD - previousMonthUSD) / previousMonthUSD
            } else {
                delta = nil
            }
            return SpendSlice(costUSD: monthCostUSD, daily: days, delta: delta)
        case .sevenDays, .thirtyDays:
            let count = range == .sevenDays ? 7 : 30
            let start = MonthForecastMath.addDays(today, -(count - 1))
            let days = daily.filter { $0.date >= start && $0.date <= today }.sorted { $0.date < $1.date }
            let cost = days.reduce(0.0) { $0 + $1.costUSD }
            return SpendSlice(costUSD: cost, daily: days, delta: nil)
        }
    }
}
