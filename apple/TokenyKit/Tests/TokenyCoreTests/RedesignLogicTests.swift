import Foundation
import Testing

@testable import TokenyCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("Overview ranges, intraday and insights")
struct RedesignLogicTests {
    private let prague = TimeZone(identifier: "Europe/Prague")!

    @Test func monthUsesTheMonthTotalAndADelta() {
        let daily = [
            UsageSummary.Day(date: "2026-11-01", costUSD: 2),
            UsageSummary.Day(date: "2026-11-20", costUSD: 3),
            UsageSummary.Day(date: "2026-10-31", costUSD: 9),
        ]
        let slice = SpendWindows.slice(
            daily: daily, monthCostUSD: 10, previousMonthUSD: 8, range: .month, today: "2026-11-20")
        #expect(slice.costUSD == 10)
        #expect(slice.daily.map(\.date) == ["2026-11-01", "2026-11-20"])
        #expect(slice.delta == 0.25)
    }

    @Test func sevenDaysSumsOnlyThatWindow() {
        let daily = [
            UsageSummary.Day(date: "2026-11-10", costUSD: 4),
            UsageSummary.Day(date: "2026-11-18", costUSD: 1),
            UsageSummary.Day(date: "2026-11-20", costUSD: 3),
        ]
        let slice = SpendWindows.slice(
            daily: daily, monthCostUSD: 99, previousMonthUSD: 8, range: .sevenDays, today: "2026-11-20")
        #expect(slice.costUSD == 4)
        #expect(slice.delta == nil)
        #expect(slice.daily.map(\.date) == ["2026-11-18", "2026-11-20"])
    }

    @Test func todayIsHourlyAndHistoryStaysDaily() {
        let now = Date(timeIntervalSince1970: 1_794_740_400)
        let plan = ProviderFetchPlanBuilder.make(now: now, timeZone: prague)
        #expect(plan.historyBucket == "1d")
        #expect(plan.intradayBucket == "1h")
        #expect(plan.intradayStart != nil)
        #expect(plan.intradayEnd == now)
        let openAI = ProviderAPI.openAIUsage(
            apiKey: "sk-admin-secret", start: now, end: now.addingTimeInterval(3600), bucketWidth: "1h")
        #expect(openAI.url.query?.contains("bucket_width=1h") == true)
        #expect(openAI.url.query?.contains("limit=24") == true)
        #expect(!(openAI.url.absoluteString.contains("sk-admin-secret")))
        let daily = ProviderAPI.openAIUsage(apiKey: "sk-admin-secret", start: now, end: now.addingTimeInterval(3600))
        #expect(daily.url.query?.contains("bucket_width=1d") == true)
        let anthropic = ProviderAPI.anthropicUsage(apiKey: "sk-ant", start: now, end: now.addingTimeInterval(3600), bucketWidth: "1h")
        #expect(anthropic.url.query?.contains("bucket_width=1h") == true)
        #expect(ProviderAPI.openAICosts(apiKey: "sk-admin-secret", start: now, end: now).url.query?.contains("bucket_width=1d") == true)
    }

    @Test func cursorWaitsAnHour() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(ProviderSyncPace.shouldFetch(provider: "cursor", lastSuccess: nil, now: now))
        #expect(!ProviderSyncPace.shouldFetch(provider: "cursor", lastSuccess: now.addingTimeInterval(-60), now: now))
        #expect(ProviderSyncPace.shouldFetch(provider: "cursor", lastSuccess: now.addingTimeInterval(-3600), now: now))
        #expect(ProviderSyncPace.shouldFetch(provider: "openai", lastSuccess: now, now: now))
        let imports = [
            ProviderImportRecord(
                id: "1", provider: "cursor", method: "api", at: "2026-11-20T10:00:00Z", added: 1, skipped: 0,
                alreadyStored: 0, outcome: "ok", keyPreview: nil)
        ]
        #expect(ProviderSyncPace.lastSuccess(imports: imports, provider: "cursor") != nil)
        #expect(ProviderSyncPace.lastSuccess(imports: imports, provider: "openai") == nil)
    }

    @Test func hoursGroupALocalDayAndReplaceOneProvider() {
        let rows = [
            activity("a", "2026-11-20T09:15:00Z", provider: "openai", cost: 1, tokens: 10),
            activity("b", "2026-11-20T09:45:00Z", provider: "openai", cost: 2, tokens: 5),
            activity("c", "2026-11-20T11:00:00Z", provider: "anthropic", cost: 4, tokens: 1),
        ]
        let points = IntradaySeries.points(rows, timeZone: prague)
        let totals = IntradaySeries.totals(points, day: "2026-11-20")
        #expect(totals.count == 2)
        #expect(totals[0].tokens == 15)
        #expect(totals[0].costUSD == 3)
        let replaced = IntradaySeries.replacing(points, providers: ["openai"], with: [])
        #expect(replaced.allSatisfy { $0.providerSource == "anthropic" })
    }

    @Test func oldLedgerWithoutHoursStillDecodes() throws {
        let json = #"{"ids":["a"],"buckets":[],"imports":[],"isSample":false}"#.data(using: .utf8)!
        let ledger = try JSONDecoder().decode(OnDeviceLedger.self, from: json)
        #expect(ledger.ids == ["a"])
        #expect(ledger.hours.isEmpty)
    }

    @Test func tipBriefCopiesNumbersAndDoesNotAddAny() {
        let tip = OptimizationTip(
            id: "cheaper-x", kind: "cheaperModel", model: "claude-opus-4-6", alternative: "claude-sonnet-5-5",
            savingUSD: 1.5, usesBilledCost: true)
        let brief = TipFacts.brief(tips: [tip], monthUSD: 12, rate: 23.5, currency: .usd, languageCode: "en")
        #expect(brief.contains("$12.00"))
        #expect(brief.contains("$1.50"))
        #expect(brief.contains("claude-opus-4-6"))
        #expect(!brief.contains("999"))
        #expect(!brief.contains("$40"))
        let czech = TipFacts.fallback(tips: [tip], monthUSD: 12, rate: 23.5, currency: .czk, languageCode: "cs")
        #expect(czech.contains("Kč"))
        #expect(!czech.contains("999"))
    }

    @Test func missingInsightsRouteIsAnEmptyList() async throws {
        let config = AppConfig(webURL: URL(string: "https://tokeny.example")!, appGroup: "group.test")
        let api = UsageAPI(config: config, transport: { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        })
        let insights = try await api.fetchInsights(accessToken: "e30.e30.e30")
        #expect(insights.isEmpty)
        let body = """
        {"insights":[{"id":"1","title":"Cache","detail":"Half the input","saving_usd":2.5}]}
        """.data(using: .utf8)!
        let decoded = try UsageAPI.decodeInsights(body)
        #expect(decoded.count == 1)
        #expect(decoded[0].savingUSD == 2.5)
        #expect(decoded[0].detail == "Half the input")
    }

    private func activity(_ id: String, _ instant: String, provider: String, cost: Double, tokens: Int) -> ImportedActivity {
        ImportedActivity(
            generationID: id, createdAt: instant, instant: ISO8601.date(from: instant), costUSD: cost,
            tokensPrompt: tokens, tokensCompletion: 0, tokensReasoning: 0, tokensCached: 0, tokensCacheWrite: 0,
            model: "m", providerName: provider, providerSource: provider, billingType: nil, requestCount: 1,
            countsAsBatch: false, tierKnown: false)
    }
}
