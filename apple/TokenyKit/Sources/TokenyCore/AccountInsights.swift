import Foundation

/// Response of `GET /api/insights` (`server/insights.ts`).
/// Money is either an exact USD amount or a band that contains it. Free accounts receive bands.
public struct AccountInsights: Codable, Equatable, Sendable {
    public var version: Int
    public var plan: String
    public var amounts: String
    public var tz: String
    public var window: Window
    public var usdToCzk: Double?
    public var rateDate: String?
    public var cacheHitRate: Double?
    public var modelMix: [ModelRow]
    public var groups: [GroupRow]
    public var tips: [Tip]
    public var truncated: Bool

    public struct Window: Codable, Equatable, Sendable {
        public var from: String
        public var to: String
    }

    public struct Money: Codable, Equatable, Sendable {
        public var kind: String
        public var usd: Double?
        public var czk: Double?
        public var lowUsd: Double?
        public var highUsd: Double?
        public var lowCzk: Double?
        public var highCzk: Double?
    }

    public struct Observed: Codable, Equatable, Sendable {
        public var cost: Money
        public var median: Money
    }

    public struct Tip: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var kind: String
        public var model: String?
        public var alternative: String?
        public var explanation: String
        public var saving: Money?
        public var observed: Observed?
        public var priceSource: String?
        public var priceChecked: String?
        public var contextNote: String?
        public var basis: String
        public var assumedShare: Double?
        public var requests: Int?
        public var tokens: Int?
    }

    public struct ModelRow: Codable, Equatable, Sendable, Identifiable {
        public var model: String
        public var provider: String
        public var share: Double?
        public var requests: Int
        public var tokens: Int
        public var cacheHitRate: Double?
        public var cost: Money?
        public var costBasis: String?
        public var priceSource: String?
        public var priceChecked: String?
        public var id: String { "\(provider)|\(model)" }
    }

    public struct GroupRow: Codable, Equatable, Sendable, Identifiable {
        public var kind: String
        public var label: String
        public var share: Double?
        public var requests: Int
        public var tokens: Int
        public var cost: Money?
        public var id: String { "\(kind)|\(label)" }
    }

    public var hasContent: Bool {
        !tips.isEmpty || !modelMix.isEmpty || !groups.isEmpty || cacheHitRate != nil
    }

    public static func decode(_ data: Data) throws -> AccountInsights {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AccountInsights.self, from: data)
    }
}
