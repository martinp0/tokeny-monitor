import Foundation

/// Documented usage endpoints. The app calls only these hosts.
public enum ProviderEndpoint {
    public static let openAIUsage = URL(string: "https://api.openai.com/v1/organization/usage/completions")!
    public static let openAICosts = URL(string: "https://api.openai.com/v1/organization/costs")!
    public static let anthropicUsage = URL(string: "https://api.anthropic.com/v1/organizations/usage_report/messages")!
    public static let anthropicCost = URL(string: "https://api.anthropic.com/v1/organizations/cost_report")!
    public static let cursorBilling = URL(string: "https://api.cursor.com/v2/teams/billing-items")!

    public static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return host == "api.openai.com" || host == "api.anthropic.com" || host == "api.cursor.com"
    }
}

public struct ProviderCall: Equatable, Sendable {
    public var url: URL
    public var headers: [String: String]

    public init(url: URL, headers: [String: String]) {
        self.url = url
        self.headers = headers
    }
}

public enum ProviderAPIError: Error, Equatable, Sendable {
    case unexpected
    case unauthorized
    case forbidden
    case rateLimited
    case badRequest
    case unreachable
}

/// Builds requests and reads JSON for the three providers that publish a usage API.
/// Gemini has no such API; its import is the Cloud Billing CSV.
public enum ProviderAPI {
    public static let windowDays = 31
    /// Legacy Usage and Cost API, the same endpoints the server already calls. Still supported.
    public static let anthropicVersion = "2023-06-01"

    public static func window(ending end: Date, days: Int = windowDays) -> (start: Date, end: Date) {
        let start = end.addingTimeInterval(-Double(days) * 86_400)
        return (start, end)
    }

    public static func openAIUsage(apiKey: String, start: Date, end: Date, page: String? = nil) -> ProviderCall {
        call(ProviderEndpoint.openAIUsage, query: openAIQuery(start: start, end: end, page: page, groups: ["model", "batch"]), headers: [
            "Authorization": "Bearer \(apiKey)",
        ])
    }

    public static func openAICosts(apiKey: String, start: Date, end: Date, page: String? = nil) -> ProviderCall {
        call(ProviderEndpoint.openAICosts, query: openAIQuery(start: start, end: end, page: page, groups: ["line_item"]), headers: [
            "Authorization": "Bearer \(apiKey)",
        ])
    }

    public static func anthropicUsage(apiKey: String, start: Date, end: Date, page: String? = nil) -> ProviderCall {
        var query = [
            URLQueryItem(name: "starting_at", value: UsageImport.isoUTC(start)),
            URLQueryItem(name: "ending_at", value: UsageImport.isoUTC(end)),
            URLQueryItem(name: "bucket_width", value: "1d"),
            URLQueryItem(name: "limit", value: "31"),
            URLQueryItem(name: "group_by[]", value: "model"),
            URLQueryItem(name: "group_by[]", value: "service_tier"),
        ]
        if let page { query.append(URLQueryItem(name: "page", value: page)) }
        return call(ProviderEndpoint.anthropicUsage, query: query, headers: anthropicHeaders(apiKey))
    }

    public static func anthropicCost(apiKey: String, start: Date, end: Date, page: String? = nil) -> ProviderCall {
        var query = [
            URLQueryItem(name: "starting_at", value: UsageImport.isoUTC(start)),
            URLQueryItem(name: "ending_at", value: UsageImport.isoUTC(end)),
            URLQueryItem(name: "bucket_width", value: "1d"),
            URLQueryItem(name: "limit", value: "31"),
            URLQueryItem(name: "group_by[]", value: "description"),
        ]
        if let page { query.append(URLQueryItem(name: "page", value: page)) }
        return call(ProviderEndpoint.anthropicCost, query: query, headers: anthropicHeaders(apiKey))
    }

    /// Team billing items. Basic auth, key as the username and an empty password. At most 31 days.
    public static func cursorBilling(apiKey: String, start: Date, end: Date, page: String? = nil) -> ProviderCall {
        var query = [
            URLQueryItem(name: "startTime", value: UsageImport.isoUTC(start)),
            URLQueryItem(name: "endTime", value: UsageImport.isoUTC(end)),
            URLQueryItem(name: "pageSize", value: "100"),
            URLQueryItem(name: "chargeCategory", value: "usage"),
        ]
        if let page { query.append(URLQueryItem(name: "cursor", value: page)) }
        let token = Data("\(apiKey):".utf8).base64EncodedString()
        return call(ProviderEndpoint.cursorBilling, query: query, headers: ["Authorization": "Basic \(token)"])
    }

    public static func nextPage(openAI data: Data) -> String? {
        guard let object = jsonObject(data), truth(object["has_more"]) else { return nil }
        let page = JSONBox.string(object["next_page"])
        return page.isEmpty ? nil : page
    }

    public static func nextPage(cursor data: Data) -> String? {
        guard let object = jsonObject(data),
            let page = object["pagination"] as? [String: Any], truth(page["hasMore"])
        else { return nil }
        let cursor = JSONBox.string(page["nextCursor"])
        return cursor.isEmpty ? nil : cursor
    }

    public static func openAIRows(usage: Data, costs: Data) throws -> [ImportedActivity] {
        let usageRows = try openAIUsageRows(usage)
        let costRows = try openAICostRows(costs)
        return usageRows + costRows
    }

    public static func anthropicRows(usage: Data, costs: Data) throws -> [ImportedActivity] {
        try anthropicUsageRows(usage) + anthropicCostRows(costs)
    }

    public static func cursorRows(_ data: Data) throws -> [ImportedActivity] {
        guard let object = jsonObject(data), let items = object["data"] as? [[String: Any]] else {
            throw ProviderAPIError.unexpected
        }
        var rows: [ImportedActivity] = []
        for item in items {
            guard JSONBox.string(item["chargeCategory"]) == "usage" || item["chargeCategory"] == nil else { continue }
            let id = JSONBox.string(item["billingItemId"])
            let time = JSONBox.string(item["eventTime"])
            guard !id.isEmpty, let instant = UsageImport.parseInstant(time) else { continue }
            let product = JSONBox.string(item["product"])
            let source = product == "grok-bot" ? "grok-bot" : "cursor"
            let name = source == "grok-bot" ? "Grok Bot" : "Cursor"
            let usage = item["usage"] as? [String: Any] ?? [:]
            let fresh = JSONBox.int(usage["prompt-text-tokens"])
            let cached = JSONBox.int(usage["cached-prompt-text-tokens"])
            let write = JSONBox.int(usage["cache-write-text-tokens"])
            let output = JSONBox.int(usage["completion-text-tokens"])
            let requests = max(1, JSONBox.int(usage["requests"]))
            let pricing = item["pricing"] as? [String: Any] ?? [:]
            let currency = JSONBox.string(pricing["currency"]).uppercased()
            if !currency.isEmpty && currency != "USD" { continue }
            let cost = JSONBox.double(pricing["contracted"])
            let usageType = JSONBox.string(item["usageType"])
            let billing = ["included", "on_demand", "credits"].contains(usageType) ? usageType : (usageType == "free" ? "included" : nil)
            let extras = item["displayExtras"] as? [String: Any] ?? [:]
            let model = JSONBox.string(extras["model"])
            rows.append(ImportedActivity(
                generationID: id, createdAt: UsageImport.isoUTC(instant), instant: instant, costUSD: max(0, cost),
                tokensPrompt: fresh + cached + write, tokensCompletion: output, tokensReasoning: 0,
                tokensCached: cached, tokensCacheWrite: write,
                model: model.isEmpty ? source : model, providerName: name, providerSource: source,
                billingType: billing, requestCount: requests, countsAsBatch: false, tierKnown: false))
        }
        return rows
    }

    public static func redact(_ text: String, secret: String) -> String {
        guard !secret.isEmpty else { return String(text.prefix(180)) }
        return String(text.replacingOccurrences(of: secret, with: "••••").prefix(180))
    }

    private static func openAIUsageRows(_ data: Data) throws -> [ImportedActivity] {
        guard let buckets = buckets(data, timeKey: "start_time") else { throw ProviderAPIError.unexpected }
        var rows: [ImportedActivity] = []
        for bucket in buckets {
            guard let start = bucket.time else { continue }
            let instant = Date(timeIntervalSince1970: start)
            for result in bucket.results {
                let model = JSONBox.string(result["model"])
                if model.isEmpty { continue }
                let input = JSONBox.int(result["input_tokens"])
                let cached = JSONBox.int(result["input_cached_tokens"])
                let output = JSONBox.int(result["output_tokens"])
                if input + output == 0 { continue }
                let batch = truth(result["batch"])
                let requests = max(1, JSONBox.int(result["num_model_requests"]))
                let id = "openai:\(Int(start)):\(model):\(batch):\(JSONBox.string(result["project_id"]))"
                rows.append(ImportedActivity(
                    generationID: id, createdAt: UsageImport.isoUTC(instant), instant: instant, costUSD: 0,
                    tokensPrompt: input, tokensCompletion: output, tokensReasoning: 0, tokensCached: cached,
                    tokensCacheWrite: 0, model: model, providerName: "OpenAI", providerSource: "openai",
                    billingType: batch ? "batch" : "standard", requestCount: requests, countsAsBatch: batch, tierKnown: true))
            }
        }
        return rows
    }

    /// Costs API amounts are dollars in `amount.value`, not a list-price estimate.
    private static func openAICostRows(_ data: Data) throws -> [ImportedActivity] {
        guard let buckets = buckets(data, timeKey: "start_time") else { throw ProviderAPIError.unexpected }
        var rows: [ImportedActivity] = []
        for bucket in buckets {
            guard let start = bucket.time else { continue }
            let instant = Date(timeIntervalSince1970: start)
            for result in bucket.results {
                let item = JSONBox.string(result["line_item"])
                if item.isEmpty { continue }
                let amount = result["amount"] as? [String: Any] ?? [:]
                let currency = JSONBox.string(amount["currency"]).lowercased()
                if !currency.isEmpty && currency != "usd" { continue }
                let model = item.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? item
                let id = "openai-cost:\(Int(start)):\(item)"
                rows.append(ImportedActivity(
                    generationID: id, createdAt: UsageImport.isoUTC(instant), instant: instant,
                    costUSD: max(0, JSONBox.double(amount["value"])),
                    tokensPrompt: 0, tokensCompletion: 0, tokensReasoning: 0, tokensCached: 0, tokensCacheWrite: 0,
                    model: model, providerName: "OpenAI", providerSource: "openai", billingType: nil,
                    requestCount: 1, countsAsBatch: false, tierKnown: false))
            }
        }
        return rows
    }

    private static func anthropicUsageRows(_ data: Data) throws -> [ImportedActivity] {
        guard let buckets = datedBuckets(data) else { throw ProviderAPIError.unexpected }
        var rows: [ImportedActivity] = []
        for bucket in buckets {
            guard let instant = bucket.instant else { continue }
            for result in bucket.results {
                let model = JSONBox.string(result["model"])
                if model.isEmpty { continue }
                let uncached = JSONBox.int(result["uncached_input_tokens"])
                let cacheRead = JSONBox.int(result["cache_read_input_tokens"])
                let creation = result["cache_creation"] as? [String: Any] ?? [:]
                let write = JSONBox.int(creation["ephemeral_5m_input_tokens"]) + JSONBox.int(creation["ephemeral_1h_input_tokens"])
                let legacyWrite = creation.isEmpty ? JSONBox.int(result["cache_creation_input_tokens"]) : 0
                let output = JSONBox.int(result["output_tokens"])
                let cacheWrite = write + legacyWrite
                if uncached + cacheRead + cacheWrite + output == 0 { continue }
                let tier = JSONBox.string(result["service_tier"]).lowercased()
                let id = "anthropic:\(UsageImport.isoUTC(instant)):\(model):\(tier)"
                rows.append(ImportedActivity(
                    generationID: id, createdAt: UsageImport.isoUTC(instant), instant: instant, costUSD: 0,
                    tokensPrompt: uncached + cacheRead + cacheWrite, tokensCompletion: output, tokensReasoning: 0,
                    tokensCached: cacheRead, tokensCacheWrite: cacheWrite, model: model, providerName: "Anthropic",
                    providerSource: "anthropic", billingType: tier.isEmpty ? nil : tier, requestCount: 1,
                    countsAsBatch: tier == "batch", tierKnown: !tier.isEmpty))
            }
        }
        return rows
    }

    /// Cost report `amount` is a decimal string of cents (USD minor units).
    private static func anthropicCostRows(_ data: Data) throws -> [ImportedActivity] {
        guard let buckets = datedBuckets(data) else { throw ProviderAPIError.unexpected }
        var rows: [ImportedActivity] = []
        for bucket in buckets {
            guard let instant = bucket.instant else { continue }
            for result in bucket.results {
                let currency = JSONBox.string(result["currency"]).uppercased()
                if !currency.isEmpty && currency != "USD" { continue }
                let model = JSONBox.string(result["model"])
                let description = JSONBox.string(result["description"])
                let label = model.isEmpty ? description : model
                if label.isEmpty { continue }
                let cents = JSONBox.double(result["amount"])
                let id = "anthropic-cost:\(UsageImport.isoUTC(instant)):\(label):\(description)"
                rows.append(ImportedActivity(
                    generationID: id, createdAt: UsageImport.isoUTC(instant), instant: instant, costUSD: max(0, cents / 100),
                    tokensPrompt: 0, tokensCompletion: 0, tokensReasoning: 0, tokensCached: 0, tokensCacheWrite: 0,
                    model: label, providerName: "Anthropic", providerSource: "anthropic", billingType: nil,
                    requestCount: 1, countsAsBatch: false, tierKnown: false))
            }
        }
        return rows
    }

    private struct TimedBucket {
        var time: Double?
        var instant: Date?
        var results: [[String: Any]]
    }

    private static func buckets(_ data: Data, timeKey: String) -> [TimedBucket]? {
        guard let object = jsonObject(data), let list = object["data"] as? [[String: Any]] else { return nil }
        return list.map { bucket in
            TimedBucket(time: JSONBox.double(bucket[timeKey]), instant: nil, results: bucket["results"] as? [[String: Any]] ?? [])
        }
    }

    private static func datedBuckets(_ data: Data) -> [TimedBucket]? {
        guard let object = jsonObject(data), let list = object["data"] as? [[String: Any]] else { return nil }
        return list.map { bucket in
            let raw = JSONBox.string(bucket["starting_at"]).isEmpty
                ? JSONBox.string(bucket["starts_at"]) : JSONBox.string(bucket["starting_at"])
            return TimedBucket(time: nil, instant: UsageImport.parseInstant(raw), results: bucket["results"] as? [[String: Any]] ?? [])
        }
    }

    private static func openAIQuery(start: Date, end: Date, page: String?, groups: [String]) -> [URLQueryItem] {
        var query = [
            URLQueryItem(name: "start_time", value: String(Int(start.timeIntervalSince1970))),
            URLQueryItem(name: "end_time", value: String(Int(end.timeIntervalSince1970))),
            URLQueryItem(name: "bucket_width", value: "1d"),
            URLQueryItem(name: "limit", value: "31"),
        ]
        query.append(contentsOf: groups.map { URLQueryItem(name: "group_by[]", value: $0) })
        if let page { query.append(URLQueryItem(name: "page", value: page)) }
        return query
    }

    private static func anthropicHeaders(_ apiKey: String) -> [String: String] {
        ["x-api-key": apiKey, "anthropic-version": anthropicVersion]
    }

    private static func call(_ url: URL, query: [URLQueryItem], headers: [String: String]) -> ProviderCall {
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        parts.queryItems = query
        return ProviderCall(url: parts.url!, headers: headers)
    }

    private static func jsonObject(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func truth(_ value: Any?) -> Bool {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        let text = JSONBox.string(value).lowercased()
        return text == "true" || text == "1"
    }
}

enum JSONBox {
    static func string(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    static func double(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) ?? 0 }
        return 0
    }

    static func int(_ value: Any?) -> Int {
        let number = double(value)
        guard number.isFinite, number > 0 else { return 0 }
        return Int(number.rounded())
    }
}
