import Foundation
import Testing

@testable import TokenyCore

@Suite("Provider import and tips")
struct ImportAndTipsTests {
    private let prague = TimeZone(identifier: "Europe/Prague")!
    private let day = "2026-11-17"

    @Test func openAIUsageCSVKeepsTokensAndDoesNotInventCost() throws {
        let csv = """
        start_time,model,input_tokens,input_cached_tokens,output_tokens,num_model_requests,batch
        2026-11-01T00:00:00Z,gpt-5.4,1000,100,50,4,false
        2026-11-01T00:00:00Z,gpt-5.4,1000,100,50,4,false
        """
        let parsed = try UsageImport.parse(csv)
        #expect(parsed.kind == .openAIUsage)
        #expect(parsed.stats.duplicatesInFile == 1)
        #expect(parsed.rows.count == 1)
        let row = try #require(parsed.rows.first)
        #expect(row.providerSource == "openai")
        #expect(row.tokensPrompt == 1000)
        #expect(row.tokensCached == 100)
        #expect(row.tokensCompletion == 50)
        #expect(row.costUSD == 0)
        #expect(row.requestCount == 4)
        #expect(!row.countsAsBatch)
        #expect(row.tierKnown)
    }

    @Test func anthropicUsageCSVMapsCacheColumns() throws {
        let csv = """
        Start Time,API Key,Workspace,Model,Service Tier,Input Tokens,Output Tokens,Cache Read Tokens,Cache Write 5m Tokens,Cache Write 1h Tokens
        2026-11-02T00:00:00Z,apikey_123,Default,claude-sonnet-5-5,standard,10,4,6,2,1
        """
        let parsed = try UsageImport.parse(csv)
        #expect(parsed.kind == .anthropicUsage)
        let row = try #require(parsed.rows.first)
        #expect(row.model == "claude-sonnet-5-5")
        #expect(row.tokensPrompt == 19)
        #expect(row.tokensCached == 6)
        #expect(row.tokensCacheWrite == 3)
        #expect(row.tokensCompletion == 4)
        #expect(row.costUSD == 0)
        #expect(!row.countsAsBatch)
        #expect(row.tierKnown)
        #expect(!row.generationID.contains("apikey_123"))
    }

    @Test func anthropicCostCSVUsesTheAmountColumn() throws {
        let csv = """
        starting_at,model,amount,currency,description
        2026-11-03T00:00:00Z,claude-haiku-4-5,1.25,USD,tokens
        2026-11-03T00:00:00Z,claude-haiku-4-5,2,EUR,tokens
        """
        let parsed = try UsageImport.parse(csv)
        #expect(parsed.kind == .anthropicCost)
        #expect(parsed.rows.count == 1)
        #expect(parsed.stats.skippedCurrency == 1)
        #expect(abs(parsed.rows[0].costUSD - 1.25) < 0.000_001)
    }

    @Test func geminiBillingCSVKeepsSubtotalAndSkipsOtherServices() throws {
        let csv = """
        Date,Service description,SKU description,Usage amount,Usage unit,Subtotal ($)
        2026-11-04,Compute Engine,N1 Instance,3,hour,9.00
        2026-11-04,Generative Language API,Gemini 4 Carbon Input Tokens,2000000,tokens,4.00
        2026-11-05,Generative Language API,Gemini 4 Carbon Output Tokens,100000,tokens,1.00
        """
        let parsed = try UsageImport.parse(csv)
        #expect(parsed.kind == .geminiBilling)
        #expect(parsed.stats.skippedUnknownProduct == 1)
        #expect(parsed.rows.count == 2)
        let input = try #require(parsed.rows.first { $0.tokensPrompt == 2_000_000 })
        let output = try #require(parsed.rows.first { $0.tokensCompletion == 100_000 })
        #expect(input.costUSD == 4)
        #expect(output.costUSD == 1)
        #expect(parsed.rows.map(\.providerSource).allSatisfy { $0 == "gemini" })
    }

    @Test func geminiCSVInAnotherCurrencyIsNotTreatedAsDollars() throws {
        let csv = """
        Date,Service description,SKU description,Subtotal (Kč)
        2026-11-04,Generative Language API,Gemini 4 Carbon,100
        """
        let parsed = try UsageImport.parse(csv)
        #expect(parsed.rows.isEmpty)
        #expect(parsed.stats.skippedCurrency == 1)
    }

    @Test func openAIAdminJSONUsesCostAPIAmounts() throws {
        let usage = """
        {"data":[{"start_time":1761955200,"results":[{"model":"gpt-5.4","input_tokens":1000,"output_tokens":10,"input_cached_tokens":0,"num_model_requests":3,"batch":false}]}],"has_more":false}
        """.data(using: .utf8)!
        let costs = """
        {"data":[{"start_time":1761955200,"results":[{"line_item":"gpt-5.4, input","amount":{"value":0.42,"currency":"usd"}}]}],"has_more":true,"next_page":"p2"}
        """.data(using: .utf8)!
        let rows = try ProviderAPI.openAIRows(usage: usage, costs: costs)
        let tokens = try #require(rows.first { $0.tokensPrompt == 1000 })
        #expect(tokens.costUSD == 0)
        #expect(tokens.tierKnown)
        #expect(!tokens.countsAsBatch)
        let cost = try #require(rows.first { $0.costUSD > 0 })
        #expect(abs(cost.costUSD - 0.42) < 0.000_001)
        #expect(cost.model == "gpt-5.4")
        #expect(ProviderAPI.nextPage(openAI: costs) == "p2")
        #expect(ProviderAPI.nextPage(openAI: usage) == nil)
    }

    @Test func anthropicCostReportIsCentsAndDropsTheKey() throws {
        let usage = """
        {"data":[{"starting_at":"2026-11-01T00:00:00Z","results":[{"model":"claude-sonnet-5-5","service_tier":"standard","uncached_input_tokens":100,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}]}]}
        """.data(using: .utf8)!
        let costs = """
        {"data":[{"starting_at":"2026-11-01T00:00:00Z","results":[{"model":"claude-sonnet-5-5","description":"tokens","amount":"250","currency":"USD"}]}]}
        """.data(using: .utf8)!
        let rows = try ProviderAPI.anthropicRows(usage: usage, costs: costs)
        #expect(rows.contains { $0.tokensPrompt == 100 && $0.costUSD == 0 })
        #expect(rows.contains { abs($0.costUSD - 2.5) < 0.000_001 })
    }

    @Test func cursorBillingItemsIgnoreEmailAndPrincipal() throws {
        let json = """
        {"data":[{"billingItemId":"3f6c1b9e-5d2a-5c41-9b7e-2a4d8c0e1f35","eventTime":"2026-11-07T14:03:27.512Z","product":"grok-bot","chargeCategory":"usage","usageType":"on_demand","principal":{"type":"user","id":"user_secret"},"usage":{"prompt-text-tokens":"100","cached-prompt-text-tokens":"7","completion-text-tokens":"30"},"pricing":{"currency":"USD","contracted":"0.0421500000"},"displayExtras":{"userEmail":"jordan@example.com","displayLabel":"Jordan"}}],"pagination":{"hasMore":true,"nextCursor":"abc"}}
        """.data(using: .utf8)!
        let rows = try ProviderAPI.cursorRows(json)
        let row = try #require(rows.first)
        #expect(row.providerSource == "grok-bot")
        #expect(row.providerName == "Grok Bot")
        #expect(row.tokensPrompt == 107)
        #expect(row.tokensCached == 7)
        #expect(abs(row.costUSD - 0.04215) < 0.000_000_1)
        #expect(row.billingType == "on_demand")
        let dumped = "\(row.model) \(row.providerName) \(row.generationID)"
        #expect(!dumped.contains("example.com"))
        #expect(!dumped.contains("user_secret"))
        #expect(!dumped.contains("Jordan"))
        #expect(ProviderAPI.nextPage(cursor: json) == "abc")
    }

    @Test func requestsUseTheDocumentedHostsAndNeverPutTheKeyInTheURL() {
        let start = Date(timeIntervalSince1970: 1_762_000_000)
        let end = start.addingTimeInterval(86_400)
        let openAI = ProviderAPI.openAIUsage(apiKey: "sk-admin-secret", start: start, end: end)
        #expect(openAI.url.host == "api.openai.com")
        #expect(openAI.url.path == "/v1/organization/usage/completions")
        #expect(openAI.url.query?.contains("group_by") == true)
        #expect(!(openAI.url.absoluteString.contains("sk-admin-secret")))
        #expect(openAI.headers["Authorization"] == "Bearer sk-admin-secret")
        let anthropic = ProviderAPI.anthropicUsage(apiKey: "sk-ant-admin", start: start, end: end)
        #expect(anthropic.url.path == "/v1/organizations/usage_report/messages")
        #expect(anthropic.headers["anthropic-version"] == "2023-06-01")
        #expect(anthropic.headers["x-api-key"] == "sk-ant-admin")
        let cursor = ProviderAPI.cursorBilling(apiKey: "crsr_test", start: start, end: end)
        #expect(cursor.url.path == "/v2/teams/billing-items")
        let expected = Data("crsr_test:".utf8).base64EncodedString()
        #expect(cursor.headers["Authorization"] == "Basic \(expected)")
        #expect(ProviderEndpoint.isAllowed(openAI.url))
        #expect(!ProviderEndpoint.isAllowed(URL(string: "http://api.openai.com/v1/organization/costs")!))
        #expect(!ProviderEndpoint.isAllowed(URL(string: "https://example.com/usage")!))
        #expect(ProviderAPI.redact("key sk-admin-secret rejected", secret: "sk-admin-secret") == "key •••• rejected")
    }

    @Test func pricesMatchTheLongestNameAndExpire() throws {
        let catalog = ModelPrices.bundled()
        let opus = try #require(catalog.price(forModel: "claude-opus-4-6", on: day))
        #expect(opus.input == 5)
        #expect(opus.output == 25)
        #expect(opus.source.contains("claude.com"))
        #expect(catalog.price(forModel: "gpt-5.4-pro", on: day) == nil)
        #expect(catalog.price(forModel: "gemini-4-carbon", on: day)?.input == 2)
        #expect(catalog.price(forModel: "Generative Language API Gemini 4 Carbon Input Tokens", on: day)?.id == "gemini-4-carbon")
        #expect(catalog.price(forModel: "gemini-4-carbon", on: "2026-11-30")?.input == 2)
        #expect(catalog.price(id: "gemini-4-carbon", on: "2026-12-01")?.input == 4)
        #expect(catalog.price(id: "gemini-4-carbon", on: "2026-12-01")?.output == 20)
        #expect(catalog.price(id: "gemini-4-carbon", on: "2026-12-01")?.cached == 0.2)
        #expect(catalog.price(id: "gemini-4-argon", on: "2026-12-01")?.input == 4)
        #expect(catalog.price(forModel: "gpt-5.6-sol", on: "2026-11-30")?.batchFraction == 0.5)
        #expect(catalog.price(forModel: "gpt-5.6-sol", on: "2026-12-01") == nil)
        #expect(catalog.unverified.contains { $0.id == "gpt-5.6-sol" && $0.validFrom == "2026-12-01" })
        #expect(catalog.price(forModel: "gpt-5.4", on: day)?.batchFraction == nil)
        #expect(catalog.price(forModel: "gpt-6-luna", on: day)?.batchFraction == 0.5)
        #expect(catalog.price(forModel: "totally-unknown-model", on: day) == nil)
    }

    @Test func headerOnlyImportHasNoUsableRows() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-11-17T12:00:00Z"))
        let empty = try OnDeviceInsight.make(
            text: "generation_id,created_at,cost_total\n",
            fileName: "empty.csv", source: .file, now: now, timeZone: prague)
        #expect(empty.lacksUsableRows)
        #expect(empty.summary.month.costUSD == 0)
        let used = try OnDeviceInsight.make(
            text: "generation_id,created_at,cost_total,tokens_prompt,tokens_completion,model_permaslug\nused-1,2026-11-17T12:00:00Z,1,10,5,claude-haiku-4-5\n",
            fileName: "used.csv", source: .file, now: now, timeZone: prague)
        #expect(!used.lacksUsableRows)
    }

    @Test func cheaperModelTipUsesBilledCostAndNamesTheListPrice() {
        let slice = ModelSlice(
            model: "claude-opus-4-6", providerSource: "anthropic", costUSD: 40, tokensPrompt: 2_000_000,
            tokensCached: 0, tokensCacheWrite: 0, tokensCompletion: 20_000, requestCount: 40, batchRequests: 0,
            tierKnownRequests: 40)
        let tips = OptimizationTips.make(
            rollup: UsageRollup(models: [slice], days: []), budget: nil, monthCostUSD: 40,
            catalog: ModelPrices.bundled(), on: day)
        let cheaper = tips.first { $0.kind == "cheaperModel" }
        #expect(cheaper?.alternative == "claude-sonnet-5-5")
        #expect(cheaper?.usesBilledCost == true)
        #expect((cheaper?.savingUSD ?? 0) > 0)
        #expect(cheaper?.priceChecked == "2026-11-17")
        #expect(tips.contains { $0.kind == "spendLimit" })
    }

    @Test func unknownModelGetsNoPriceEstimate() {
        let slice = ModelSlice(
            model: "secret-model", providerSource: "openai", costUSD: 80, tokensPrompt: 5_000_000,
            tokensCached: 0, tokensCacheWrite: 0, tokensCompletion: 1000, requestCount: 100, batchRequests: 0,
            tierKnownRequests: 0)
        let tips = OptimizationTips.make(
            rollup: UsageRollup(models: [slice], days: [UsageSummary.Day(date: "2026-11-01", costUSD: 80)]),
            budget: UsageSummary.Budget(monthlyUSD: 100, thresholdPercent: 80, enabled: true), monthCostUSD: 80,
            catalog: ModelPrices.bundled(), on: day)
        #expect(!tips.contains { $0.kind == "cheaperModel" || $0.kind == "promptCache" || $0.kind == "batch" })
        #expect(!tips.contains { $0.kind == "spendLimit" })
    }

    @Test func cacheAndBatchAndSpikeAreSeparateRules() {
        let slice = ModelSlice(
            model: "claude-sonnet-5-5", providerSource: "anthropic", costUSD: 20, tokensPrompt: 2_000_000,
            tokensCached: 0, tokensCacheWrite: 0, tokensCompletion: 10_000, requestCount: 30, batchRequests: 0,
            tierKnownRequests: 30)
        let days = [
            UsageSummary.Day(date: "2026-11-01", costUSD: 1),
            UsageSummary.Day(date: "2026-11-02", costUSD: 1),
            UsageSummary.Day(date: "2026-11-03", costUSD: 1),
            UsageSummary.Day(date: "2026-11-04", costUSD: 12),
        ]
        let tips = OptimizationTips.make(
            rollup: UsageRollup(models: [slice], days: days),
            budget: UsageSummary.Budget(monthlyUSD: 50, thresholdPercent: 80, enabled: true), monthCostUSD: 15,
            catalog: ModelPrices.bundled(), on: day)
        #expect(tips.contains { $0.kind == "promptCache" && ($0.assumedShare ?? 0) == 0.5 })
        #expect(tips.contains { $0.kind == "batch" })
        let spike = tips.first { $0.kind == "spike" }
        #expect(spike?.day == "2026-11-04")
        #expect(spike?.costUSD == 12)
        #expect(spike?.savingUSD == nil)
    }

    @Test func ledgerDedupesAndRebuildsTheMonth() throws {
        let csv = """
        Start Time,Model,Service Tier,Input Tokens,Output Tokens,Cache Read Tokens,Cache Write 5m Tokens,Cache Write 1h Tokens,API Key,Workspace
        2026-11-10T08:00:00Z,claude-opus-4-6,standard,100,20,0,0,0,secret-key,ws
        """
        let parsed = try UsageImport.parse(csv)
        let record = ProviderImportRecord(
            id: "1", provider: "anthropic", method: "csv", at: "2026-11-17T00:00:00Z", added: 0, skipped: 0,
            alreadyStored: 0, outcome: "ok", keyPreview: nil)
        let first = OnDeviceLedger.empty.merging(parsed.rows, record: record, timeZone: prague, asSample: false)
        let second = first.ledger.merging(parsed.rows, record: record, timeZone: prague, asSample: false)
        #expect(first.added == 1)
        #expect(second.added == 0)
        #expect(second.alreadyStored == 1)
        let now = Date(timeIntervalSince1970: 1_794_740_400)
        let snap = second.ledger.snapshot(fileName: "usage.csv", now: now, timeZone: prague, budget: nil, stats: parsed.stats)
        #expect(snap.summary.month.costUSD == 0)
        #expect(snap.summary.month.tokens == 120)
        #expect(snap.imports?.count == 2)
        let dumped = String(data: try JSONEncoder().encode(snap), encoding: .utf8) ?? ""
        #expect(!dumped.contains("secret-key"))
    }

    @Test func maskKeepsOnlyTheEnds() {
        #expect(SecretPreview.mask("sk-ant-admin-key-abcd") == "sk-ant…abcd")
        #expect(SecretPreview.mask("short") == "••••")
    }
}
