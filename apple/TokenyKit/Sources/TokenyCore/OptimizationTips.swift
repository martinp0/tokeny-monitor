import Foundation

/// One explainable rule. Dollar figures are estimates and only exist when both sides are in the price table
/// or the saving is a documented fraction of money already in the import.
public struct OptimizationTip: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: String
    public var model: String?
    public var alternative: String?
    public var requests: Int?
    public var tokens: Int?
    public var savingUSD: Double?
    /// False when the import had no billed dollars and the estimate compares list prices only.
    public var usesBilledCost: Bool
    public var day: String?
    public var costUSD: Double?
    public var medianUSD: Double?
    public var inputPerMillion: Double?
    public var outputPerMillion: Double?
    public var altInputPerMillion: Double?
    public var altOutputPerMillion: Double?
    public var cachedShare: Double?
    /// Fraction of uncached input the cache rule assumes could have been a cache read.
    public var assumedShare: Double?
    public var contextNote: String?
    public var priceChecked: String?
    public var priceSource: String?

    public init(
        id: String, kind: String, model: String? = nil, alternative: String? = nil, requests: Int? = nil,
        tokens: Int? = nil, savingUSD: Double? = nil, usesBilledCost: Bool = false, day: String? = nil,
        costUSD: Double? = nil, medianUSD: Double? = nil, inputPerMillion: Double? = nil,
        outputPerMillion: Double? = nil, altInputPerMillion: Double? = nil, altOutputPerMillion: Double? = nil,
        cachedShare: Double? = nil, assumedShare: Double? = nil, contextNote: String? = nil,
        priceChecked: String? = nil, priceSource: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.model = model
        self.alternative = alternative
        self.requests = requests
        self.tokens = tokens
        self.savingUSD = savingUSD
        self.usesBilledCost = usesBilledCost
        self.day = day
        self.costUSD = costUSD
        self.medianUSD = medianUSD
        self.inputPerMillion = inputPerMillion
        self.outputPerMillion = outputPerMillion
        self.altInputPerMillion = altInputPerMillion
        self.altOutputPerMillion = altOutputPerMillion
        self.cachedShare = cachedShare
        self.assumedShare = assumedShare
        self.contextNote = contextNote
        self.priceChecked = priceChecked
        self.priceSource = priceSource
    }
}

public struct ModelSlice: Codable, Equatable, Sendable {
    public var model: String
    public var providerSource: String
    public var costUSD: Double
    public var tokensPrompt: Int
    public var tokensCached: Int
    public var tokensCacheWrite: Int
    public var tokensCompletion: Int
    public var requestCount: Int
    public var batchRequests: Int
    public var tierKnownRequests: Int

    public init(
        model: String, providerSource: String, costUSD: Double, tokensPrompt: Int, tokensCached: Int,
        tokensCacheWrite: Int, tokensCompletion: Int, requestCount: Int, batchRequests: Int, tierKnownRequests: Int
    ) {
        self.model = model
        self.providerSource = providerSource
        self.costUSD = costUSD
        self.tokensPrompt = tokensPrompt
        self.tokensCached = tokensCached
        self.tokensCacheWrite = tokensCacheWrite
        self.tokensCompletion = tokensCompletion
        self.requestCount = requestCount
        self.batchRequests = batchRequests
        self.tierKnownRequests = tierKnownRequests
    }

    public var totalTokens: Int { tokensPrompt + tokensCompletion }
}

public struct UsageRollup: Codable, Equatable, Sendable {
    public var models: [ModelSlice]
    public var days: [UsageSummary.Day]

    public init(models: [ModelSlice], days: [UsageSummary.Day]) {
        self.models = models
        self.days = days
    }

    public static let empty = UsageRollup(models: [], days: [])
}

public enum OptimizationTips {
    /// A model needs this many calls, with a short average reply, before it counts as repetitive.
    public static let repetitiveRequests = 20
    public static let maxAverageOutput = 800
    /// Token volume that stands in for a request count when the file has none (billing SKUs).
    public static let repetitiveTokens = 500_000
    public static let minCostShare = 0.25
    public static let minSavingUSD = 0.05
    public static let cacheMinUncached = 100_000
    public static let cacheMaxReadRatio = 0.10
    public static let cacheAssumedShare = 0.50
    public static let batchMinRequests = 10
    public static let spikeMultiple = 2.5
    public static let spikeMinExcessUSD = 1.0

    public static func make(
        rollup: UsageRollup, budget: UsageSummary.Budget?, monthCostUSD: Double, catalog: ModelCatalog, on day: String
    ) -> [OptimizationTip] {
        var tips: [OptimizationTip] = []
        tips.append(contentsOf: cheaperModels(rollup.models, monthCostUSD: monthCostUSD, catalog: catalog, on: day))
        tips.append(contentsOf: caching(rollup.models, catalog: catalog, on: day))
        tips.append(contentsOf: batches(rollup.models, catalog: catalog, on: day))
        if let spike = spike(days: rollup.days) { tips.append(spike) }
        if spendLimit(monthCostUSD: monthCostUSD, budget: budget) {
            tips.append(OptimizationTip(id: "spend-limit", kind: "spendLimit"))
        }
        return Array(tips.prefix(5))
    }

    private static func cheaperModels(
        _ models: [ModelSlice], monthCostUSD: Double, catalog: ModelCatalog, on day: String
    ) -> [OptimizationTip] {
        var found: [OptimizationTip] = []
        for slice in models where isRepetitive(slice) {
            guard let current = catalog.price(forModel: slice.model, on: day),
                let altID = current.alternative,
                let alt = catalog.price(id: altID, on: day)
            else { continue }
            if monthCostUSD > 0, slice.costUSD / monthCostUSD < minCostShare, slice.costUSD > 0 { continue }
            let parts = tokenParts(slice)
            let currentList = current.listCost(
                uncachedInput: parts.uncached, cachedInput: parts.cached, cacheWriteTokens: parts.write, outputTokens: parts.output)
            let altList = alt.listCost(
                uncachedInput: parts.uncached, cachedInput: parts.cached, cacheWriteTokens: parts.write, outputTokens: parts.output)
            guard currentList > 0, altList < currentList * 0.98 else { continue }
            let billed = slice.costUSD > 0.01
            let saving = billed ? slice.costUSD * (1 - altList / currentList) : currentList - altList
            guard saving >= minSavingUSD else { continue }
            found.append(OptimizationTip(
                id: "cheaper-\(current.id)", kind: "cheaperModel", model: slice.model, alternative: alt.id,
                requests: slice.requestCount, tokens: slice.totalTokens, savingUSD: saving, usesBilledCost: billed,
                inputPerMillion: current.input, outputPerMillion: current.output,
                altInputPerMillion: alt.input, altOutputPerMillion: alt.output,
                contextNote: current.contextNote, priceChecked: current.checked, priceSource: current.source))
        }
        return found.sorted { ($0.savingUSD ?? 0) > ($1.savingUSD ?? 0) }.prefix(2).map { $0 }
    }

    private static func caching(_ models: [ModelSlice], catalog: ModelCatalog, on day: String) -> [OptimizationTip] {
        var found: [OptimizationTip] = []
        for slice in models {
            guard let price = catalog.price(forModel: slice.model, on: day), let cachedRate = price.cached else { continue }
            let parts = tokenParts(slice)
            let inputTotal = parts.uncached + parts.cached
            guard parts.uncached >= cacheMinUncached, inputTotal > 0 else { continue }
            let ratio = Double(parts.cached) / Double(inputTotal)
            guard ratio < cacheMaxReadRatio else { continue }
            let saving = Double(parts.uncached) * cacheAssumedShare * (price.input - cachedRate) / 1_000_000
            guard saving >= minSavingUSD else { continue }
            found.append(OptimizationTip(
                id: "cache-\(price.id)", kind: "promptCache", model: slice.model, tokens: parts.uncached,
                savingUSD: saving, cachedShare: ratio, assumedShare: cacheAssumedShare,
                contextNote: price.contextNote, priceChecked: price.checked, priceSource: price.source))
        }
        return found.sorted { ($0.savingUSD ?? 0) > ($1.savingUSD ?? 0) }.prefix(1).map { $0 }
    }

    private static func batches(_ models: [ModelSlice], catalog: ModelCatalog, on day: String) -> [OptimizationTip] {
        var found: [OptimizationTip] = []
        for slice in models {
            guard slice.tierKnownRequests > 0, slice.requestCount >= batchMinRequests || slice.totalTokens >= repetitiveTokens else { continue }
            guard let price = catalog.price(forModel: slice.model, on: day), let fraction = price.batchFraction, fraction < 1 else { continue }
            let known = max(slice.tierKnownRequests, 1)
            let batchShare = Double(slice.batchRequests) / Double(known)
            guard batchShare < 0.5 else { continue }
            let parts = tokenParts(slice)
            let list = price.listCost(
                uncachedInput: parts.uncached, cachedInput: parts.cached, cacheWriteTokens: parts.write, outputTokens: parts.output)
            let base = slice.costUSD > 0.01 ? slice.costUSD : list
            guard base > 0 else { continue }
            let nonBatch = 1 - batchShare
            let saving = base * nonBatch * (1 - fraction)
            guard saving >= minSavingUSD else { continue }
            found.append(OptimizationTip(
                id: "batch-\(price.id)", kind: "batch", model: slice.model, requests: slice.requestCount,
                savingUSD: saving, usesBilledCost: slice.costUSD > 0.01,
                priceChecked: price.checked, priceSource: price.source))
        }
        return found.sorted { ($0.savingUSD ?? 0) > ($1.savingUSD ?? 0) }.prefix(1).map { $0 }
    }

    private static func spike(days: [UsageSummary.Day]) -> OptimizationTip? {
        let positive = days.filter { $0.costUSD > 0 }.sorted { $0.costUSD < $1.costUSD }
        guard positive.count >= 3, let peak = positive.last else { return nil }
        let others = positive.dropLast()
        let mid = others.count / 2
        let median = others.count % 2 == 1 ? others[mid].costUSD : (others[mid - 1].costUSD + others[mid].costUSD) / 2
        guard median > 0, peak.costUSD >= median * spikeMultiple, peak.costUSD - median >= spikeMinExcessUSD else { return nil }
        return OptimizationTip(
            id: "spike-\(peak.date)", kind: "spike", day: peak.date, costUSD: peak.costUSD, medianUSD: median)
    }

    private static func spendLimit(monthCostUSD: Double, budget: UsageSummary.Budget?) -> Bool {
        guard monthCostUSD > 0 else { return false }
        guard let budget else { return true }
        return budget.monthlyUSD <= 0
    }

    private static func isRepetitive(_ slice: ModelSlice) -> Bool {
        if slice.requestCount >= repetitiveRequests {
            let average = slice.requestCount > 0 ? slice.tokensCompletion / slice.requestCount : 0
            return average <= maxAverageOutput
        }
        return slice.requestCount == 0 && slice.totalTokens >= repetitiveTokens
    }

    private static func tokenParts(_ slice: ModelSlice) -> (uncached: Int, cached: Int, write: Int, output: Int) {
        let cached = min(slice.tokensCached, slice.tokensPrompt)
        let write = min(slice.tokensCacheWrite, max(0, slice.tokensPrompt - cached))
        let uncached = max(0, slice.tokensPrompt - cached - write)
        return (uncached, cached, write, slice.tokensCompletion)
    }
}
