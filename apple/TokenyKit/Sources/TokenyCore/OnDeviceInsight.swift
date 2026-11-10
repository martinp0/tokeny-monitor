import Foundation

/// Spend, forecast and an optional budget calculated from a file or from labeled sample rows.
///
/// `summary.plan` is always `.free` and `summary.forecastMonthUSD` is always nil, so this cannot
/// be mistaken for a Pro payload from `GET /api/usage-summary`. The forecast lives beside it.
public struct OnDeviceSnapshot: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        case sample
        case file
    }

    public var source: Source
    public var fileName: String?
    public var summary: UsageSummary
    public var forecast: MonthForecast
    public var breakdown: UsageBreakdown?
    public var stats: UsageImportStats
    /// True when koruna figures use ``UsageSummary/fallbackUSDCZK`` rather than a ČNB rate.
    public var usesFallbackExchangeRate: Bool

    public init(
        source: Source, fileName: String?, summary: UsageSummary, forecast: MonthForecast,
        breakdown: UsageBreakdown?, stats: UsageImportStats, usesFallbackExchangeRate: Bool
    ) {
        self.source = source
        self.fileName = fileName
        self.summary = summary
        self.forecast = forecast
        self.breakdown = breakdown
        self.stats = stats
        self.usesFallbackExchangeRate = usesFallbackExchangeRate
    }
}

public enum OnDeviceInsight {
    public static func make(
        text: String, fileName: String?, source: OnDeviceSnapshot.Source, now: Date = Date(),
        timeZone: TimeZone = MonthForecastMath.defaultTimeZone, budget: UsageSummary.Budget? = nil
    ) throws -> OnDeviceSnapshot {
        try assemble(UsageImport.parse(text), source: source, fileName: fileName, now: now, timeZone: timeZone, budget: budget)
    }

    /// Obvious sample rows for the current month. Ids start with `sample-not-your-account`.
    public static func sample(
        now: Date = Date(), timeZone: TimeZone = MonthForecastMath.defaultTimeZone, budget: UsageSummary.Budget? = nil
    ) -> OnDeviceSnapshot {
        let today = MonthForecastMath.localDay(now, timeZone: timeZone)
        var lines = [
            "generation_id,created_at,cost_total,tokens_prompt,tokens_completion,model_permaslug,provider_name"
        ]
        for age in 1...16 {
            let day = MonthForecastMath.addDays(today, -age)
            let midnight = MonthForecastMath.localMidnight(day: day, timeZone: timeZone)
            let instant = Date(timeIntervalSince1970: midnight / 1000 + 12 * 3600)
            lines.append(
                "sample-not-your-account-\(age),\(UsageImport.isoUTC(instant)),2,1000,200,sample-model,Sample")
        }
        lines.append("sample-not-your-account-today,\(UsageImport.isoUTC(now)),0.5,100,20,sample-model,Sample")
        let text = lines.joined(separator: "\n")
        return (try? make(text: text, fileName: nil, source: .sample, now: now, timeZone: timeZone, budget: budget))
            ?? empty(now: now, timeZone: timeZone, budget: budget)
    }

    static func assemble(
        _ imported: UsageImport.Result, source: OnDeviceSnapshot.Source, fileName: String?, now: Date,
        timeZone: TimeZone, budget: UsageSummary.Budget?
    ) -> OnDeviceSnapshot {
        let today = MonthForecastMath.localDay(now, timeZone: timeZone)
        let period = String(today.prefix(7))
        var rateDaily: [String: Double] = [:]
        var monthDaily: [String: Double] = [:]
        var todayCost = 0.0
        var todayTokens = 0
        var todayRequests = 0
        var monthCost = 0.0
        var monthTokens = 0
        var monthRequests = 0
        var modelCost: [String: Double] = [:]
        var providerCost: [String: Double] = [:]
        var monthRows: [ImportedActivity] = []
        var firstDay: String?
        for row in imported.rows {
            guard let instant = row.instant else { continue }
            let day = MonthForecastMath.localDay(instant, timeZone: timeZone)
            if firstDay == nil || day < firstDay! { firstDay = day }
            rateDaily[day, default: 0] += row.costUSD
            guard day.hasPrefix(period) && day <= today else { continue }
            monthDaily[day, default: 0] += row.costUSD
            monthCost += row.costUSD
            monthTokens += row.totalTokens
            monthRequests += row.requestCount
            monthRows.append(row)
            if day == today {
                todayCost += row.costUSD
                todayTokens += row.totalTokens
                todayRequests += row.requestCount
            }
            let model = row.model.isEmpty ? row.providerSource : row.model
            modelCost[model, default: 0] += row.costUSD
            let provider = row.providerName.isEmpty ? row.providerSource : row.providerName
            providerCost[provider, default: 0] += row.costUSD
        }
        let forecast = MonthForecastMath.forecast(daily: rateDaily, firstDataDay: firstDay, now: now, timeZone: timeZone)
        let summary = UsageSummary(
            version: 1, plan: .free, generatedAt: UsageImport.isoUTC(now), timeZone: timeZone.identifier,
            today: .init(costUSD: todayCost, tokens: todayTokens, requests: todayRequests),
            month: .init(costUSD: monthCost, tokens: monthTokens, requests: monthRequests, key: period),
            previousMonth: nil, forecastMonthUSD: nil, budget: budget, usdCZK: nil,
            daily: monthDaily.keys.sorted().map { UsageSummary.Day(date: $0, costUSD: monthDaily[$0] ?? 0) },
            topModels: modelCost.sorted { $0.value > $1.value }.prefix(8).map { UsageSummary.Share(name: $0.key, costUSD: $0.value) },
            providers: providerCost.sorted { $0.value > $1.value }.map { UsageSummary.Share(name: $0.key, costUSD: $0.value) },
            lastActivityAt: imported.rows.compactMap(\.instant).max().map(UsageImport.isoUTC))
        return OnDeviceSnapshot(
            source: source, fileName: source == .file ? fileName : nil, summary: summary, forecast: forecast,
            breakdown: UsageBreakdown.make(rows: monthRows), stats: imported.stats, usesFallbackExchangeRate: true)
    }

    private static func empty(now: Date, timeZone: TimeZone, budget: UsageSummary.Budget?) -> OnDeviceSnapshot {
        let today = MonthForecastMath.localDay(now, timeZone: timeZone)
        let forecast = MonthForecastMath.forecast(daily: [:], firstDataDay: nil, now: now, timeZone: timeZone)
        let summary = UsageSummary(
            plan: .free, generatedAt: UsageImport.isoUTC(now), timeZone: timeZone.identifier,
            today: .init(costUSD: 0, tokens: 0, requests: 0),
            month: .init(costUSD: 0, tokens: 0, requests: 0, key: String(today.prefix(7))),
            previousMonth: nil, forecastMonthUSD: nil, budget: budget, usdCZK: nil,
            daily: [], topModels: [], providers: [], lastActivityAt: nil)
        return OnDeviceSnapshot(
            source: .sample, fileName: nil, summary: summary, forecast: forecast, breakdown: nil,
            stats: UsageImportStats(), usesFallbackExchangeRate: true)
    }
}
