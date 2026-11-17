import Foundation

/// CSV shapes that are not the Cursor usage export or the OpenRouter activity export.
/// Column sets follow the provider's own export, not a guessed schema.
enum ProviderCSV {
    static func detect(_ headers: [String]) -> UsageImport.Kind? {
        let names = Set(headers.map(squash))
        if names.contains("servicedescription"), names.contains("skudescription"),
            names.contains("date") || names.contains("month"),
            moneyHeader(headers) != nil {
            return .geminiBilling
        }
        if names.contains("cachewrite5mtokens") || names.contains("cachereadtokens") || names.contains("cachewrite1htokens") {
            return .anthropicUsage
        }
        if names.contains("inputcachedtokens") || names.contains("nummodelrequests") || names.contains("inputuncachedtokens") {
            return .openAIUsage
        }
        if names.contains("lineitem"), names.contains("starttime") || names.contains("date") {
            return .openAICost
        }
        if (names.contains("amount") || names.contains("amountusd")) && (names.contains("model") || names.contains("description"))
            && (names.contains("starttime") || names.contains("date") || names.contains("startingat"))
            && !names.contains("inputtokens") && !names.contains("lineitem") {
            return .anthropicCost
        }
        if names.contains("model") && names.contains("inputtokens") && names.contains("outputtokens")
            && (names.contains("starttime") || names.contains("startingat"))
            && (names.contains("servicetier") || names.contains("workspace") || names.contains("apikey")) {
            return .anthropicUsage
        }
        if names.contains("model") && (names.contains("inputtokens") || names.contains("outputtokens"))
            && (names.contains("starttime") || names.contains("date")) {
            return .openAIUsage
        }
        return nil
    }

    static func parse(_ text: String, kind: UsageImport.Kind) -> UsageImport.Result {
        let headers = CSVTable.headerNames(text)
        let table = CSVTable.parse(text) { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{FEFF}", with: "") }
        var stats = UsageImportStats()
        var seen: Set<String> = []
        var rows: [ImportedActivity] = []
        let money = moneyHeader(headers)
        for (offset, raw) in table.enumerated() {
            stats.rows += 1
            let row: ImportedActivity?
            switch kind {
            case .openAIUsage: row = openAIUsage(raw, line: offset, stats: &stats)
            case .openAICost: row = openAICost(raw, line: offset, stats: &stats)
            case .anthropicUsage: row = anthropicUsage(raw, line: offset, stats: &stats)
            case .anthropicCost: row = anthropicCost(raw, line: offset, stats: &stats)
            case .geminiBilling: row = gemini(raw, money: money, line: offset, stats: &stats)
            default: row = nil
            }
            guard let row else { continue }
            if seen.contains(row.generationID) {
                stats.duplicatesInFile += 1
                continue
            }
            seen.insert(row.generationID)
            stats.mapped += 1
            if row.instant == nil { stats.undated += 1 }
            rows.append(row)
        }
        return UsageImport.Result(kind: kind, rows: rows, stats: stats)
    }

    private static func openAIUsage(_ raw: [String: String], line: Int, stats: inout UsageImportStats) -> ImportedActivity? {
        let model = field(raw, "model", "Model")
        let start = field(raw, "start_time", "Start time", "start_time_iso", "Start Time")
        guard !model.isEmpty, let instant = instant(start, stats: &stats) else {
            if model.isEmpty { stats.skippedMissingID += 1 }
            return nil
        }
        let input = whole(field(raw, "input_tokens", "Input tokens", "input_text_tokens"))
        let cached = whole(field(raw, "input_cached_tokens", "Input cached tokens", "cached_tokens"))
        let output = whole(field(raw, "output_tokens", "Output tokens"))
        let batchRaw = field(raw, "batch", "Batch").lowercased()
        let tierKnown = raw.keys.contains { squash($0) == "batch" }
        let batch = batchRaw == "true" || batchRaw == "1" || batchRaw == "yes"
        let requests = max(1, whole(field(raw, "num_model_requests", "Num model requests", "requests")))
        let id = "openai:\(UsageImport.isoUTC(instant)):\(model):\(batch)"
        return activity(
            id: id, instant: instant, cost: 0, prompt: input, cached: cached, write: 0, output: output,
            model: model, provider: "OpenAI", source: "openai", billing: batch ? "batch" : nil,
            requests: requests, batch: batch, tierKnown: tierKnown)
    }

    private static func openAICost(_ raw: [String: String], line: Int, stats: inout UsageImportStats) -> ImportedActivity? {
        let item = field(raw, "line_item", "Line item")
        let start = field(raw, "start_time", "Start time", "date", "Date")
        guard !item.isEmpty, let instant = instant(start, stats: &stats) else {
            if item.isEmpty { stats.skippedMissingID += 1 }
            return nil
        }
        let currency = field(raw, "currency", "amount.currency", "Currency").lowercased()
        if !currency.isEmpty && currency != "usd" {
            stats.skippedCurrency += 1
            return nil
        }
        let amount = money(field(raw, "amount", "amount.value", "Amount", "Cost"))
        let model = item.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? item
        let id = "openai-cost:\(UsageImport.isoUTC(instant)):\(item)"
        return activity(
            id: id, instant: instant, cost: amount, prompt: 0, cached: 0, write: 0, output: 0,
            model: model, provider: "OpenAI", source: "openai", billing: nil, requests: 1,
            batch: false, tierKnown: false)
    }

    private static func anthropicUsage(_ raw: [String: String], line: Int, stats: inout UsageImportStats) -> ImportedActivity? {
        let model = field(raw, "Model", "model")
        let start = field(raw, "Start Time", "starting_at", "start_time")
        guard !model.isEmpty, let instant = instant(start, stats: &stats) else {
            if model.isEmpty { stats.skippedMissingID += 1 }
            return nil
        }
        let uncached = whole(field(raw, "Input Tokens", "uncached_input_tokens", "input_tokens"))
        let cacheRead = whole(field(raw, "Cache Read Tokens", "cache_read_input_tokens"))
        let write5 = whole(field(raw, "Cache Write 5m Tokens", "cache_creation.ephemeral_5m_input_tokens"))
        let write1 = whole(field(raw, "Cache Write 1h Tokens", "cache_creation.ephemeral_1h_input_tokens"))
        let output = whole(field(raw, "Output Tokens", "output_tokens"))
        let tier = field(raw, "Service Tier", "service_tier").lowercased()
        let tierKnown = raw.keys.contains { squash($0) == "servicetier" } && !tier.isEmpty
        let batch = tier == "batch"
        let id = "anthropic:\(UsageImport.isoUTC(instant)):\(model):\(tier)"
        return activity(
            id: id, instant: instant, cost: 0, prompt: uncached + cacheRead + write5 + write1, cached: cacheRead,
            write: write5 + write1, output: output, model: model, provider: "Anthropic", source: "anthropic",
            billing: tier.isEmpty ? nil : tier, requests: 1, batch: batch, tierKnown: tierKnown)
    }

    private static func anthropicCost(_ raw: [String: String], line: Int, stats: inout UsageImportStats) -> ImportedActivity? {
        let model = field(raw, "model", "Model", "description", "Description")
        let start = field(raw, "starting_at", "Start Time", "start_time", "date")
        guard !model.isEmpty, let instant = instant(start, stats: &stats) else {
            if model.isEmpty { stats.skippedMissingID += 1 }
            return nil
        }
        let currency = field(raw, "currency", "Currency").uppercased()
        if !currency.isEmpty && currency != "USD" {
            stats.skippedCurrency += 1
            return nil
        }
        let amount = money(field(raw, "Amount (USD)", "amount_usd", "amount", "Amount"))
        let id = "anthropic-cost:\(UsageImport.isoUTC(instant)):\(model)"
        return activity(
            id: id, instant: instant, cost: amount, prompt: 0, cached: 0, write: 0, output: 0,
            model: model, provider: "Anthropic", source: "anthropic", billing: nil, requests: 1,
            batch: false, tierKnown: false)
    }

    private static func gemini(
        _ raw: [String: String], money moneyColumn: (header: String, usd: Bool)?, line: Int, stats: inout UsageImportStats
    ) -> ImportedActivity? {
        guard let moneyColumn else {
            stats.skippedCurrency += 1
            return nil
        }
        if !moneyColumn.usd {
            stats.skippedCurrency += 1
            return nil
        }
        let service = field(raw, "Service description", "Service")
        let sku = field(raw, "SKU description", "SKU")
        let blob = (service + " " + sku).lowercased()
        guard blob.contains("generative language") || blob.contains("gemini") || blob.contains("vertex ai") else {
            stats.skippedUnknownProduct += 1
            return nil
        }
        let start = field(raw, "Date", "Month", "Usage date")
        guard let instant = instant(start, stats: &stats) else { return nil }
        let skuLower = sku.lowercased()
        let unit = field(raw, "Usage unit", "Unit").lowercased()
        let usage = whole(field(raw, "Usage amount", "Usage"))
        var prompt = 0
        var cached = 0
        var output = 0
        if unit.contains("token") || skuLower.contains("token") {
            if skuLower.contains("output") || skuLower.contains("thinking") {
                output = usage
            } else if skuLower.contains("cach") {
                cached = usage
                prompt = usage
            } else {
                prompt = usage
            }
        }
        let batch = skuLower.contains("batch")
        let cost = money(raw[moneyColumn.header] ?? "")
        let label = sku.isEmpty ? service : sku
        let id = "gemini:\(UsageImport.isoUTC(instant)):\(label)"
        return activity(
            id: id, instant: instant, cost: cost, prompt: prompt, cached: cached, write: 0, output: output,
            model: label, provider: "Gemini", source: "gemini", billing: batch ? "batch" : nil,
            requests: 0, batch: batch, tierKnown: true)
    }

    private static func moneyHeader(_ headers: [String]) -> (header: String, usd: Bool)? {
        let ranked = ["unrounded subtotal", "subtotal", "list cost", "cost"]
        var fallback: (String, Bool, Int)?
        for header in headers {
            let lower = header.lowercased()
            guard let rank = ranked.firstIndex(where: { lower.contains($0) }) else { continue }
            let usd = lower.contains("$") || lower.contains("usd")
            if usd { return (header, true) }
            if fallback == nil || rank < fallback!.2 { fallback = (header, false, rank) }
        }
        return fallback.map { ($0.0, $0.1) }
    }

    private static func activity(
        id: String, instant: Date, cost: Double, prompt: Int, cached: Int, write: Int, output: Int,
        model: String, provider: String, source: String, billing: String?, requests: Int, batch: Bool, tierKnown: Bool
    ) -> ImportedActivity {
        ImportedActivity(
            generationID: id, createdAt: UsageImport.isoUTC(instant), instant: instant, costUSD: cost,
            tokensPrompt: prompt, tokensCompletion: output, tokensReasoning: 0, tokensCached: cached,
            tokensCacheWrite: write, model: model, providerName: provider, providerSource: source,
            billingType: billing, requestCount: requests, countsAsBatch: batch, tierKnown: tierKnown)
    }

    private static func instant(_ raw: String, stats: inout UsageImportStats) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            stats.skippedBadTime += 1
            return nil
        }
        if text.range(of: #"^\d{10,13}$"#, options: .regularExpression) != nil, let number = Double(text) {
            let seconds = number > 10_000_000_000 ? number / 1000 : number
            return Date(timeIntervalSince1970: seconds)
        }
        if text.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil {
            return UsageImport.parseInstant(text + "-01T00:00:00Z")
        }
        if text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            return UsageImport.parseInstant(text + "T00:00:00Z")
        }
        if let date = UsageImport.parseInstant(text) { return date }
        stats.skippedBadTime += 1
        return nil
    }

    private static func field(_ raw: [String: String], _ names: String...) -> String {
        for name in names {
            if let value = raw[name]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty { return value }
        }
        let wanted = Set(names.map(squash))
        for (key, value) in raw where wanted.contains(squash(key)) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    private static func squash(_ header: String) -> String {
        header.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    private static func whole(_ raw: String) -> Int {
        let cleaned = raw.replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned), value.isFinite, value > 0 else { return 0 }
        return Int(value.rounded())
    }

    private static func money(_ raw: String) -> Double {
        var text = raw.trimmingCharacters(in: .whitespaces)
        let negative = text.hasPrefix("(") && text.hasSuffix(")")
        text = text.replacingOccurrences(of: "[$€£\\s,()]", with: "", options: .regularExpression)
        let value = Double(text) ?? 0
        return negative ? -value : value
    }
}
