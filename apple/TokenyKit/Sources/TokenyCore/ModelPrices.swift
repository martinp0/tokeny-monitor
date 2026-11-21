import Foundation

/// List prices used only for labeled estimates. Unknown models have no price, so a tip cannot invent one.
public struct ModelPrice: Equatable, Sendable {
    public var id: String
    public var provider: String
    public var input: Double
    public var output: Double
    public var cached: Double?
    public var cacheWrite: Double?
    /// Share of the list price charged for batch. 0.5 means the batch tier costs half.
    public var batchFraction: Double?
    public var alternative: String?
    public var contextNote: String?
    public var source: String
    public var checked: String
    /// Inclusive yyyy-mm-dd. The row is not a price before this day.
    public var validFrom: String?
    /// Inclusive yyyy-mm-dd. The row is not a price after this day.
    public var validThrough: String?
    /// False rows are kept so an unpublished price is visible, and are never used in a tip.
    public var verified: Bool
    /// Extra names, lowercased at match time. The id is always included.
    public var match: [String]

    public func listCost(uncachedInput: Int, cachedInput: Int, cacheWriteTokens: Int, outputTokens: Int) -> Double {
        let cachedRate = cached ?? input
        let writeRate = cacheWrite ?? input
        let tokens = Double(uncachedInput) * input
            + Double(cachedInput) * cachedRate
            + Double(cacheWriteTokens) * writeRate
            + Double(outputTokens) * output
        return tokens / 1_000_000
    }
}

/// A provider price the catalog refuses to estimate. The reason says what the official page left out.
public struct UnverifiedModelPrice: Equatable, Sendable {
    public var id: String
    public var reason: String
    public var source: String
    public var checked: String
    public var validFrom: String?
}

public struct ModelCatalog: Equatable, Sendable {
    public var models: [ModelPrice]
    public var unverified: [UnverifiedModelPrice]

    public init(models: [ModelPrice], unverified: [UnverifiedModelPrice] = []) {
        self.models = models
        self.unverified = unverified
    }

    public static let empty = ModelCatalog(models: [])

    /// Longest matching list row that is still valid on `day` (yyyy-mm-dd). No default price.
    public func price(forModel model: String, on day: String) -> ModelPrice? {
        let haystack = model.lowercased()
        var best: (length: Int, price: ModelPrice)?
        for price in models where Self.isCurrent(price, on: day) {
            let patterns = ([price.id] + price.match).map { $0.lowercased() }
            for pattern in patterns where Self.matches(haystack, pattern: pattern) {
                if best == nil || pattern.count > best!.length {
                    best = (pattern.count, price)
                }
            }
        }
        return best?.price
    }

    public func price(id: String, on day: String) -> ModelPrice? {
        models.first { $0.id == id && Self.isCurrent($0, on: day) }
    }

    static func isCurrent(_ price: ModelPrice, on day: String) -> Bool {
        guard price.verified else { return false }
        if let from = price.validFrom, day < from { return false }
        if let through = price.validThrough, day > through { return false }
        return true
    }

    /// A dated suffix (`-20250514`) still matches. A different SKU (`-pro`, `-mini`) does not.
    static func matches(_ model: String, pattern: String) -> Bool {
        guard let range = model.range(of: pattern) else { return false }
        let after = model[range.upperBound...]
        guard let first = after.first else { return true }
        guard first == "-" || first == "." else { return true }
        let token = after.dropFirst().prefix { $0.isLetter || $0.isNumber }
        return !token.isEmpty && token.allSatisfy(\.isNumber)
    }
}

public enum ModelPrices {
    public static func load(from data: Data) throws -> ModelCatalog {
        let decoded = try JSONDecoder().decode(File.self, from: data)
        let models = decoded.models.map { row in
            ModelPrice(
                id: row.id, provider: row.provider, input: row.input, output: row.output,
                cached: row.cached, cacheWrite: row.cacheWrite, batchFraction: row.batchFraction,
                alternative: row.alternative, contextNote: row.contextNote, source: row.source,
                checked: row.checked, validFrom: row.validFrom, validThrough: row.validThrough,
                verified: row.verified ?? true, match: row.match ?? [])
        }
        let unverified = (decoded.unverified ?? []).map { row in
            UnverifiedModelPrice(
                id: row.id, reason: row.reason, source: row.source, checked: row.checked, validFrom: row.validFrom)
        }
        return ModelCatalog(models: models, unverified: unverified)
    }

    public static func bundled() -> ModelCatalog {
        // Copied from shared/pricing/model-prices.json by scripts/sync-shared-pricing.sh.
        guard let url = Bundle.module.url(forResource: "model-prices", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let catalog = try? load(from: data)
        else { return .empty }
        return catalog
    }

    private struct File: Decodable {
        var models: [Row]
        var unverified: [Gap]?
    }

    private struct Row: Decodable {
        var id: String
        var provider: String
        var match: [String]?
        var input: Double
        var output: Double
        var cached: Double?
        var cacheWrite: Double?
        var batchFraction: Double?
        var alternative: String?
        var contextNote: String?
        var source: String
        var checked: String
        var validFrom: String?
        var validThrough: String?
        var verified: Bool?
    }

    private struct Gap: Decodable {
        var id: String
        var reason: String
        var source: String
        var checked: String
        var validFrom: String?
    }
}

/// Shows the tail of a secret so the owner can recognise it. Never the middle.
public enum SecretPreview {
    public static func mask(_ secret: String) -> String {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else { return "••••" }
        return "\(trimmed.prefix(6))…\(trimmed.suffix(4))"
    }
}
