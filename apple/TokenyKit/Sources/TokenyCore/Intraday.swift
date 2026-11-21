import Foundation

/// One hour of usage for the "today" chart. Cost stays 0 when the provider only returned tokens.
public struct HourPoint: Codable, Equatable, Sendable, Identifiable {
    public var hour: String
    public var providerSource: String
    public var costUSD: Double
    public var tokens: Int

    public var id: String { "\(hour)|\(providerSource)" }

    public init(hour: String, providerSource: String, costUSD: Double, tokens: Int) {
        self.hour = hour
        self.providerSource = providerSource
        self.costUSD = costUSD
        self.tokens = tokens
    }
}

public struct HourTotal: Equatable, Sendable, Identifiable {
    public var hour: String
    public var costUSD: Double
    public var tokens: Int
    public var id: String { hour }

    public init(hour: String, costUSD: Double, tokens: Int) {
        self.hour = hour
        self.costUSD = costUSD
        self.tokens = tokens
    }
}

public enum IntradaySeries {
    /// Groups rows into local hours (`yyyy-MM-dd'T'HH`). Rows without an instant are dropped.
    public static func points(_ rows: [ImportedActivity], timeZone: TimeZone) -> [HourPoint] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        struct Acc {
            var cost = 0.0
            var tokens = 0
        }
        var grouped: [String: (provider: String, acc: Acc)] = [:]
        for row in rows {
            guard let instant = row.instant else { continue }
            let parts = calendar.dateComponents([.year, .month, .day, .hour], from: instant)
            let hour = String(
                format: "%04d-%02d-%02dT%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0)
            let provider = row.providerSource.isEmpty ? row.providerName : row.providerSource
            let key = "\(hour)|\(provider)"
            var entry = grouped[key] ?? (provider, Acc())
            entry.acc.cost += row.costUSD
            entry.acc.tokens += row.totalTokens
            grouped[key] = entry
        }
        return grouped.map { key, entry in
            let hour = String(key.split(separator: "|").first ?? "")
            return HourPoint(hour: hour, providerSource: entry.provider, costUSD: entry.acc.cost, tokens: entry.acc.tokens)
        }.sorted { $0.hour < $1.hour }
    }

    /// Replaces every stored hour for `providers` with `fresh`. Other providers stay.
    public static func replacing(_ existing: [HourPoint], providers: Set<String>, with fresh: [HourPoint]) -> [HourPoint] {
        existing.filter { !providers.contains($0.providerSource) } + fresh
    }

    /// Hours of one local day, summed across providers, for the chart.
    public static func totals(_ points: [HourPoint], day: String) -> [HourTotal] {
        var cost: [String: Double] = [:]
        var tokens: [String: Int] = [:]
        for point in points where point.hour.hasPrefix(day) {
            cost[point.hour, default: 0] += point.costUSD
            tokens[point.hour, default: 0] += point.tokens
        }
        return cost.keys.sorted().map { hour in
            HourTotal(hour: hour, costUSD: cost[hour] ?? 0, tokens: tokens[hour] ?? 0)
        }
    }
}

/// Which bucket each call uses. Today is hourly so the chart can show the day.
/// A 1-minute bucket for a full day is 1 440 rows and several pages, which would trip provider
/// rate limits on every foreground sync. One hour is the finest width that still fits in a page.
/// OpenAI costs have no hourly bucket. Cursor is event-level and is paced separately.
public struct ProviderFetchPlan: Equatable, Sendable {
    public var historyStart: Date
    public var historyEnd: Date
    public var historyBucket: String
    public var intradayStart: Date?
    public var intradayEnd: Date?
    public var intradayBucket: String

    public init(
        historyStart: Date, historyEnd: Date, historyBucket: String, intradayStart: Date?, intradayEnd: Date?,
        intradayBucket: String
    ) {
        self.historyStart = historyStart
        self.historyEnd = historyEnd
        self.historyBucket = historyBucket
        self.intradayStart = intradayStart
        self.intradayEnd = intradayEnd
        self.intradayBucket = intradayBucket
    }
}

public enum ProviderFetchPlanBuilder {
    public static func make(now: Date, timeZone: TimeZone, windowDays: Int = ProviderAPI.windowDays) -> ProviderFetchPlan {
        let window = ProviderAPI.window(ending: now, days: windowDays)
        let day = MonthForecastMath.localDay(now, timeZone: timeZone)
        let start = Date(timeIntervalSince1970: MonthForecastMath.localMidnight(day: day, timeZone: timeZone) / 1000)
        let intraday = start < now ? start : nil
        return ProviderFetchPlan(
            historyStart: window.start, historyEnd: window.end, historyBucket: "1d",
            intradayStart: intraday, intradayEnd: intraday == nil ? nil : now, intradayBucket: "1h")
    }
}
