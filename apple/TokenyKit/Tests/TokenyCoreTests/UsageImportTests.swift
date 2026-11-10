import Foundation
import Testing

@testable import TokenyCore

@Suite("Usage import")
struct UsageImportTests {
    private let prague = TimeZone(identifier: "Europe/Prague")!

    @Test func usageExportFixtureMatchesTheWebRules() throws {
        let text = try String(contentsOf: fixtureURL, encoding: .utf8)
        let parsed = try UsageImport.parse(text)
        #expect(parsed.kind == .usageExport)
        #expect(parsed.stats.rows == 10)
        #expect(parsed.stats.mapped == 6)
        #expect(parsed.stats.duplicatesInFile == 1)
        #expect(parsed.stats.skippedMissingID == 1)
        #expect(parsed.stats.skippedUnknownProduct == 1)
        #expect(parsed.stats.skippedCurrency == 1)
        #expect(parsed.stats.skippedBadTime == 0)
        let byID = Dictionary(uniqueKeysWithValues: parsed.rows.map { (String($0.generationID.suffix(1)), $0) })
        let first = try #require(byID["1"])
        #expect(first.providerSource == "grok-bot")
        #expect(first.providerName == "Grok Bot")
        #expect(first.model == "grok-bot")
        #expect(first.tokensPrompt == 32100)
        #expect(first.tokensCached == 30000)
        #expect(first.tokensCacheWrite == 2000)
        #expect(first.tokensCompletion == 300)
        #expect(first.costUSD == 0)
        #expect(first.billingType == "included")
        #expect(first.createdAt == "2026-10-22T09:15:00.000Z")
        let fourth = try #require(byID["4"])
        #expect(fourth.providerSource == "cursor")
        #expect(fourth.model == "claude-4.5-sonnet")
        #expect(fourth.costUSD == 0.125)
        #expect(fourth.billingType == "on_demand")
        let fifth = try #require(byID["5"])
        #expect(fifth.billingType == "credits")
        #expect(fifth.tokensPrompt == 900)
        #expect(fifth.tokensCached == 0)
        let sixth = try #require(byID["6"])
        #expect(sixth.tokensPrompt == 0)
        #expect(sixth.tokensCompletion == 0)
        let breakdown = try #require(UsageBreakdown.make(rows: parsed.rows))
        #expect(breakdown.cachedRead == 30000 + 80000 + 12000 + 60000)
        #expect(breakdown.cacheWrite == 2000 + 1000 + 5000)
        #expect(breakdown.freshInput == 100 + 2 + 1500 + 400 + 900)
        #expect(breakdown.output == 300 + 500 + 800 + 1200 + 50)
        #expect(abs(breakdown.onDemandCost - 0.16625) < 0.000_000_1)
        #expect(breakdown.includedCost == 0)
        #expect(breakdown.includedCalls == 3)
        #expect(breakdown.onDemandCalls == 2)
        #expect(breakdown.creditsCalls == 1)
        let dumped = parsed.rows.map { "\($0.generationID) \($0.model) \($0.providerName)" }.joined(separator: "\n")
        #expect(!dumped.contains("example.com"))
        #expect(!dumped.contains("user_demo"))
    }

    @Test func renamedHeadersAndSeparateTokenColumns() throws {
        let csv = [
            "billing_item_id,timestamp,product,usage_type,currency,cost,model,input_tokens,cached_tokens,cache_write_tokens,output_tokens,user_email",
            "a1,2026-10-22T09:15:00Z,Grok Bot,on_demand,USD,$0.50,grok-4.3,100,2000,30,40,x@example.com",
            "a1,2026-10-22T09:15:00Z,Grok Bot,on_demand,USD,$0.50,grok-4.3,100,2000,30,40,x@example.com",
            "a2,2026-10-22T10:00:00Z,cursor,included,USD,0,,10,0,0,5,x@example.com",
        ].joined(separator: "\n")
        let parsed = try UsageImport.parse(csv)
        #expect(parsed.stats.duplicatesInFile == 1)
        #expect(parsed.rows.count == 2)
        let row = try #require(parsed.rows.first { $0.generationID == "a1" })
        #expect(row.providerSource == "grok-bot")
        #expect(abs(row.costUSD - 0.5) < 0.000_001)
        #expect(row.tokensPrompt == 2130)
        #expect(row.tokensCached == 2000)
        #expect(row.tokensCompletion == 40)
        #expect(row.billingType == "on_demand")
        #expect(parsed.rows.contains { $0.generationID == "a2" && $0.providerSource == "cursor" })
        #expect(!parsed.rows.map(\.model).joined().contains("example.com"))
    }

    @Test func openRouterLastDuplicateWinsAndDropsBlankIds() throws {
        let header = "generation_id,created_at,cost_total,tokens_prompt,tokens_completion,model_permaslug,provider_name"
        let csv = [
            header,
            "gen-1,2026-05-13 05:04:04.916,0.000377,4712,1258,google/gemini-2.5-flash-lite,Google",
            ",2026-01-01,1,0,0,m,p",
            "gen-2,,1,0,0,m,p",
            "gen-1,2026-01-01T00:00:00Z,2,0,0,m,p",
        ].joined(separator: "\n")
        let parsed = try UsageImport.parse(csv)
        #expect(parsed.kind == .openRouter)
        #expect(parsed.rows.count == 1)
        #expect(parsed.rows[0].generationID == "gen-1")
        #expect(parsed.rows[0].costUSD == 2)
        #expect(parsed.rows[0].providerSource == "openrouter")
        #expect(parsed.stats.duplicatesInFile == 1)
        #expect(parsed.stats.skippedMissingID == 1)
        #expect(parsed.stats.skippedBadTime == 1)
    }

    @Test func rejectsUnknownAndEmptyFiles() {
        #expect(throws: UsageImportError.unrecognized) { try UsageImport.parse("hello,world\n1,2\n") }
        #expect(throws: UsageImportError.empty) { try UsageImport.parse(" \n") }
    }

    @Test func openRouterHeaderWithNoRowsIsEmpty() throws {
        let emptyExport = try UsageImport.parse("generation_id,created_at,cost_total\n")
        #expect(emptyExport.kind == .openRouter)
        #expect(emptyExport.rows.isEmpty)
    }

    @Test func sampleIsLabeledAndNotAServerForecast() {
        let now = Date(timeIntervalSince1970: 1_794_740_400) // 2026-11-15T11:00:00Z
        let snap = OnDeviceInsight.sample(now: now, timeZone: prague)
        #expect(snap.source == .sample)
        #expect(snap.fileName == nil)
        #expect(snap.summary.plan == .free)
        #expect(snap.summary.forecastMonthUSD == nil)
        #expect(snap.usesFallbackExchangeRate)
        #expect(snap.forecast.forecastUSD != nil)
        #expect(snap.summary.month.costUSD > 0)
        #expect(snap.summary.providers.allSatisfy { $0.name == "Sample" })
        #expect(snap.summary.topModels.allSatisfy { $0.name == "sample-model" })
        let encoded = String(data: (try? JSONEncoder().encode(snap)) ?? Data(), encoding: .utf8) ?? ""
        #expect(encoded.contains("\"source\":\"sample\""))
        #expect(encoded.contains("sample-model"))
        #expect(!encoded.contains("forecast_month_usd"))
        #expect(!encoded.contains("example.com"))
    }

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("src/test/fixtures/usage-export-sample.csv")
    }
}
