import Foundation

/// One usage row kept on the device. E-mail, principal id and the raw export are not stored.
public struct ImportedActivity: Equatable, Sendable {
    public var generationID: String
    public var createdAt: String
    public var instant: Date?
    public var costUSD: Double
    public var tokensPrompt: Int
    public var tokensCompletion: Int
    public var tokensReasoning: Int
    public var tokensCached: Int
    public var tokensCacheWrite: Int
    public var model: String
    public var providerName: String
    public var providerSource: String
    public var billingType: String?
    public var requestCount: Int

    public var totalTokens: Int { tokensPrompt + tokensCompletion + tokensReasoning }
}

public struct UsageImportStats: Codable, Equatable, Sendable {
    public var rows: Int
    public var mapped: Int
    public var duplicatesInFile: Int
    public var skippedMissingID: Int
    public var skippedBadTime: Int
    public var skippedUnknownProduct: Int
    public var skippedCurrency: Int
    public var undated: Int

    public init(
        rows: Int = 0, mapped: Int = 0, duplicatesInFile: Int = 0, skippedMissingID: Int = 0,
        skippedBadTime: Int = 0, skippedUnknownProduct: Int = 0, skippedCurrency: Int = 0, undated: Int = 0
    ) {
        self.rows = rows
        self.mapped = mapped
        self.duplicatesInFile = duplicatesInFile
        self.skippedMissingID = skippedMissingID
        self.skippedBadTime = skippedBadTime
        self.skippedUnknownProduct = skippedUnknownProduct
        self.skippedCurrency = skippedCurrency
        self.undated = undated
    }

    public var skipped: Int {
        skippedMissingID + skippedBadTime + skippedUnknownProduct + skippedCurrency
    }
}

public struct UsageBreakdown: Codable, Equatable, Sendable {
    public var freshInput: Int
    public var cachedRead: Int
    public var cacheWrite: Int
    public var output: Int
    public var includedCost: Double
    public var onDemandCost: Double
    public var creditsCost: Double
    public var includedCalls: Int
    public var onDemandCalls: Int
    public var creditsCalls: Int

    /// Nil when no row has a billing type (OpenRouter exports). Same sums as `usageBreakdown` on the web.
    public static func make(rows: [ImportedActivity]) -> UsageBreakdown? {
        var breakdown = UsageBreakdown(
            freshInput: 0, cachedRead: 0, cacheWrite: 0, output: 0,
            includedCost: 0, onDemandCost: 0, creditsCost: 0,
            includedCalls: 0, onDemandCalls: 0, creditsCalls: 0)
        var any = false
        for row in rows {
            guard let billing = row.billingType else { continue }
            any = true
            breakdown.cachedRead += row.tokensCached
            breakdown.cacheWrite += row.tokensCacheWrite
            breakdown.freshInput += max(0, row.tokensPrompt - row.tokensCached - row.tokensCacheWrite)
            breakdown.output += row.tokensCompletion
            let calls = row.requestCount
            switch billing {
            case "included":
                breakdown.includedCost += row.costUSD
                breakdown.includedCalls += calls
            case "on_demand":
                breakdown.onDemandCost += row.costUSD
                breakdown.onDemandCalls += calls
            default:
                breakdown.creditsCost += row.costUSD
                breakdown.creditsCalls += calls
            }
        }
        return any ? breakdown : nil
    }
}

public enum UsageImportError: Error, Equatable, Sendable {
    case empty
    case unrecognized
    case tooLarge
}

/// Parses the two CSV shapes the web already accepts. Nothing is uploaded.
public enum UsageImport {
    public static let maxBytes = 32_000_000

    public enum Kind: String, Codable, Equatable, Sendable {
        case openRouter
        case usageExport
    }

    public struct Result: Equatable, Sendable {
        public var kind: Kind
        public var rows: [ImportedActivity]
        public var stats: UsageImportStats
    }

    public static func parse(_ text: String) throws -> Result {
        if text.utf8.count > maxBytes { throw UsageImportError.tooLarge }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw UsageImportError.empty }
        let rawHeaders = Set(CSVTable.headerNames(text))
        let headers = Set(rawHeaders.map(canonicalHeader))
        // `created_at` is also an alias of the usage-export "Event Time" column, so the OpenRouter
        // check uses the raw header. A usage export still wins when its required columns are present.
        if isUsageExport(headers) {
            return parseUsageExport(text)
        }
        if rawHeaders.contains("generation_id") && rawHeaders.contains("created_at") {
            return parseOpenRouter(text)
        }
        throw UsageImportError.unrecognized
    }

    static func canonicalHeader(_ header: String) -> String {
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{FEFF}", with: "")
        return aliases[squash(trimmed)] ?? trimmed
    }

    private static func isUsageExport(_ headers: Set<String>) -> Bool {
        let hasUsage = headers.contains("Usage") || tokenKeys.contains { headers.contains($0) }
        return headers.contains("Billing Item ID") && headers.contains("Event Time") && headers.contains("Product") && hasUsage
    }

    private static func parseUsageExport(_ text: String) -> Result {
        let table = CSVTable.parse(text, transformHeader: canonicalHeader)
        var stats = UsageImportStats()
        var seen: Set<String> = []
        var rows: [ImportedActivity] = []
        for raw in table {
            stats.rows += 1
            switch mapUsageExport(raw) {
            case .skip(let reason):
                switch reason {
                case .missingID: stats.skippedMissingID += 1
                case .badTime: stats.skippedBadTime += 1
                case .unknownProduct: stats.skippedUnknownProduct += 1
                case .currency: stats.skippedCurrency += 1
                }
            case .row(let row):
                if seen.contains(row.generationID) {
                    stats.duplicatesInFile += 1
                    continue
                }
                seen.insert(row.generationID)
                stats.mapped += 1
                if row.instant == nil { stats.undated += 1 }
                rows.append(row)
            }
        }
        return Result(kind: .usageExport, rows: rows, stats: stats)
    }

    private static func parseOpenRouter(_ text: String) -> Result {
        let table = CSVTable.parse(text) { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{FEFF}", with: "") }
        var stats = UsageImportStats()
        var byID: [String: ImportedActivity] = [:]
        var order: [String] = []
        for raw in table {
            stats.rows += 1
            let id = (raw["generation_id"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let created = (raw["created_at"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if id.isEmpty {
                stats.skippedMissingID += 1
                continue
            }
            if created.isEmpty {
                stats.skippedBadTime += 1
                continue
            }
            if byID[id] != nil { stats.duplicatesInFile += 1 } else { order.append(id) }
            let instant = parseInstant(created)
            if instant == nil { stats.undated += 1 }
            byID[id] = ImportedActivity(
                generationID: id, createdAt: created, instant: instant,
                costUSD: number(raw["cost_total"]),
                tokensPrompt: whole(raw["tokens_prompt"]),
                tokensCompletion: whole(raw["tokens_completion"]),
                tokensReasoning: whole(raw["tokens_reasoning"]),
                tokensCached: whole(raw["tokens_cached"]),
                tokensCacheWrite: 0,
                model: raw["model_permaslug"] ?? "",
                providerName: raw["provider_name"] ?? "",
                providerSource: "openrouter",
                billingType: nil,
                requestCount: 1)
        }
        stats.mapped = byID.count
        return Result(kind: .openRouter, rows: order.compactMap { byID[$0] }, stats: stats)
    }

    private enum Skip { case missingID, badTime, unknownProduct, currency }
    private enum Mapped { case row(ImportedActivity), skip(Skip) }

    private static func mapUsageExport(_ row: [String: String]) -> Mapped {
        let id = (row["Billing Item ID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty { return .skip(.missingID) }
        let time = (row["Event Time"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let instant = parseInstant(time) else { return .skip(.badTime) }
        let productKey = (row["Product"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[\s_]+"#, with: "-", options: .regularExpression)
        guard let product = products[productKey] else { return .skip(.unknownProduct) }
        let currency = (row["Pricing Currency"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !currency.isEmpty && currency != "USD" { return .skip(.currency) }

        var usage: [String: String] = [:]
        if let raw = row["Usage"], !raw.isEmpty, let data = raw.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in object {
                usage[canonicalHeader(key)] = stringValue(value)
            }
        }
        for key in tokenKeys where usage[key] == nil {
            if let column = row[key], !column.isEmpty { usage[key] = column }
        }
        let fresh = positiveInt(usage["prompt-text-tokens"])
        let cached = positiveInt(usage["cached-prompt-text-tokens"])
        let cacheWrite = positiveInt(usage["cache-write-text-tokens"])
        let output = positiveInt(usage["completion-text-tokens"])
        let usageType = (row["Usage Type"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let billing = billingTypes.contains(usageType) ? usageType : nil
        let model = (row["Model"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let created = isoUTC(instant)
        return .row(ImportedActivity(
            generationID: id, createdAt: created, instant: instant,
            costUSD: money(row["Pricing Contracted"]),
            tokensPrompt: fresh + cached + cacheWrite,
            tokensCompletion: output,
            tokensReasoning: 0,
            tokensCached: cached,
            tokensCacheWrite: cacheWrite,
            model: model.isEmpty ? product.source : model,
            providerName: product.name,
            providerSource: product.source,
            billingType: billing,
            requestCount: 1))
    }

    /// Accepts ISO-8601 and the OpenRouter "yyyy-MM-dd HH:mm:ss" form. No zone means UTC.
    /// Does not accept loose words such as "yesterday".
    static func parseInstant(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if let date = ISO8601.date(from: text) { return date }
        var normalized = text.replacingOccurrences(of: " ", with: "T")
        if !normalized.hasSuffix("Z") && normalized.range(of: #"[+-]\d{2}:?\d{2}$"#, options: .regularExpression) == nil {
            normalized += "Z"
        }
        return ISO8601.date(from: normalized)
    }

    static func isoUTC(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func number(_ raw: String?) -> Double {
        let text = (raw ?? "").trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return 0 }
        return Double(text) ?? 0
    }

    private static func whole(_ raw: String?) -> Int {
        Int(number(raw).rounded(.towardZero))
    }

    private static func money(_ raw: String?) -> Double {
        let cleaned = (raw ?? "").replacingOccurrences(of: "[$\\s,]", with: "", options: .regularExpression)
        return Double(cleaned) ?? 0
    }

    private static func positiveInt(_ raw: String?) -> Int {
        guard let value = Double(raw ?? ""), value.isFinite, value > 0 else { return 0 }
        return Int(value.rounded())
    }

    private static func stringValue(_ value: Any) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    private static func squash(_ header: String) -> String {
        header.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    private static let tokenKeys = [
        "prompt-text-tokens", "cached-prompt-text-tokens", "cache-write-text-tokens", "completion-text-tokens",
    ]
    private static let billingTypes: Set<String> = ["included", "on_demand", "credits"]
    private static let products: [String: (source: String, name: String)] = [
        "cursor": ("cursor", "Cursor"),
        "grok-bot": ("grok-bot", "Grok Bot"),
    ]
    private static let aliases: [String: String] = {
        var map: [String: String] = [:]
        let pairs: [(String, [String])] = [
            ("Billing Item ID", ["billingitemid", "billingid", "itemid", "eventid", "requestid", "id"]),
            ("Event Time", ["eventtime", "timestamp", "time", "createdat", "date", "datetime"]),
            ("Product", ["product", "productname", "source"]),
            ("Usage", ["usage", "usagejson"]),
            ("Usage Type", ["usagetype", "billingtype", "chargetype"]),
            ("Pricing Currency", ["pricingcurrency", "currency"]),
            ("Pricing Contracted", ["pricingcontracted", "cost", "costusd", "amount", "amountusd", "price", "priceusd", "charge"]),
            ("Model", ["model", "modelname"]),
            ("prompt-text-tokens", ["prompttexttokens", "prompttokens", "inputtokens", "freshinputtokens"]),
            ("cached-prompt-text-tokens", ["cachedprompttexttokens", "cachedtokens", "cachereadtokens", "cachedinputtokens"]),
            ("cache-write-text-tokens", ["cachewritetexttokens", "cachewritetokens", "cachecreationtokens"]),
            ("completion-text-tokens", ["completiontexttokens", "completiontokens", "outputtokens"]),
        ]
        for (canon, names) in pairs {
            for name in names { map[name] = canon }
        }
        return map
    }()
}
