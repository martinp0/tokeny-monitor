import Foundation

public enum LedgerDisk {
    public static func url() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("tokeny-ondevice-ledger.json")
    }

    public static func load() -> OnDeviceLedger {
        guard let data = try? Data(contentsOf: url()) else { return .empty }
        return (try? JSONDecoder().decode(OnDeviceLedger.self, from: data)) ?? .empty
    }

    public static func save(_ ledger: OnDeviceLedger) {
        let url = url()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public static func remove() {
        try? FileManager.default.removeItem(at: url())
    }
}

/// Day and model totals kept on device so a second import does not double-count, and so tips can be rebuilt.
public struct DayModelBucket: Codable, Equatable, Sendable {
    public var day: String
    public var model: String
    public var providerSource: String
    public var providerName: String
    public var costUSD: Double
    public var tokensPrompt: Int
    public var tokensCached: Int
    public var tokensCacheWrite: Int
    public var tokensCompletion: Int
    public var requestCount: Int
    public var batchRequests: Int
    public var tierKnownRequests: Int
    public var includedCost: Double
    public var onDemandCost: Double
    public var creditsCost: Double
    public var includedCalls: Int
    public var onDemandCalls: Int
    public var creditsCalls: Int
    public var untypedCost: Double

    public var key: String { "\(day)|\(providerSource)|\(model)" }
}

public struct OnDeviceLedger: Codable, Equatable, Sendable {
    public var ids: [String]
    public var buckets: [DayModelBucket]
    public var imports: [ProviderImportRecord]
    public var isSample: Bool

    public init(ids: [String] = [], buckets: [DayModelBucket] = [], imports: [ProviderImportRecord] = [], isSample: Bool = false) {
        self.ids = ids
        self.buckets = buckets
        self.imports = imports
        self.isSample = isSample
    }

    public static let empty = OnDeviceLedger()

    /// Adds rows whose ids are new. A sample ledger is replaced by a real import, and a sample replaces everything.
    public func merging(
        _ rows: [ImportedActivity], record: ProviderImportRecord, timeZone: TimeZone, asSample: Bool
    ) -> (ledger: OnDeviceLedger, added: Int, alreadyStored: Int) {
        var base = asSample || (isSample && !asSample) ? OnDeviceLedger() : self
        var seen = Set(base.ids)
        var added = 0
        var already = 0
        var index: [String: Int] = [:]
        for (offset, bucket) in base.buckets.enumerated() { index[bucket.key] = offset }
        for row in rows {
            if seen.contains(row.generationID) {
                already += 1
                continue
            }
            guard let instant = row.instant else { continue }
            seen.insert(row.generationID)
            added += 1
            let day = MonthForecastMath.localDay(instant, timeZone: timeZone)
            let model = row.model.isEmpty ? row.providerSource : row.model
            let key = "\(day)|\(row.providerSource)|\(model)"
            var bucket = index[key].map { base.buckets[$0] } ?? DayModelBucket(
                day: day, model: model, providerSource: row.providerSource,
                providerName: row.providerName.isEmpty ? row.providerSource : row.providerName,
                costUSD: 0, tokensPrompt: 0, tokensCached: 0, tokensCacheWrite: 0, tokensCompletion: 0,
                requestCount: 0, batchRequests: 0, tierKnownRequests: 0, includedCost: 0, onDemandCost: 0,
                creditsCost: 0, includedCalls: 0, onDemandCalls: 0, creditsCalls: 0, untypedCost: 0)
            bucket.tokensPrompt += row.tokensPrompt
            bucket.tokensCached += row.tokensCached
            bucket.tokensCacheWrite += row.tokensCacheWrite
            bucket.tokensCompletion += row.tokensCompletion
            bucket.requestCount += row.requestCount
            if row.countsAsBatch { bucket.batchRequests += max(row.requestCount, 1) }
            if row.tierKnown { bucket.tierKnownRequests += max(row.requestCount, 1) }
            switch row.billingType {
            case "included":
                bucket.includedCost += row.costUSD
                bucket.includedCalls += row.requestCount
            case "on_demand":
                bucket.onDemandCost += row.costUSD
                bucket.onDemandCalls += row.requestCount
            case "credits":
                bucket.creditsCost += row.costUSD
                bucket.creditsCalls += row.requestCount
            default:
                bucket.untypedCost += row.costUSD
            }
            bucket.costUSD = bucket.untypedCost + bucket.includedCost + bucket.onDemandCost + bucket.creditsCost
            if let offset = index[key] {
                base.buckets[offset] = bucket
            } else {
                index[key] = base.buckets.count
                base.buckets.append(bucket)
            }
        }
        base.ids = seen.sorted()
        var record = record
        record.added = added
        record.alreadyStored = already
        base.imports.append(record)
        if base.imports.count > 12 { base.imports.removeFirst(base.imports.count - 12) }
        base.isSample = asSample
        return (base, added, already)
    }

    public func snapshot(
        fileName: String?, now: Date, timeZone: TimeZone, budget: UsageSummary.Budget?, stats: UsageImportStats
    ) -> OnDeviceSnapshot {
        var rows: [ImportedActivity] = []
        for bucket in buckets {
            guard let instant = UsageImport.parseInstant(bucket.day + "T12:00:00Z") else { continue }
            let billed = bucket.includedCalls + bucket.onDemandCalls + bucket.creditsCalls > 0
                || bucket.includedCost + bucket.onDemandCost + bucket.creditsCost > 0
            if billed {
                let parts: [(String, Double, Int)] = [
                    ("included", bucket.includedCost, bucket.includedCalls),
                    ("on_demand", bucket.onDemandCost, bucket.onDemandCalls),
                    ("credits", bucket.creditsCost, bucket.creditsCalls),
                ]
                var first = true
                for (type, cost, calls) in parts where cost != 0 || calls != 0 {
                    rows.append(row(bucket, instant: instant, cost: cost, billing: type, tokens: first, requests: calls))
                    first = false
                }
                if bucket.untypedCost != 0 {
                    rows.append(row(bucket, instant: instant, cost: bucket.untypedCost, billing: nil, tokens: false, requests: 0))
                }
            } else {
                rows.append(row(bucket, instant: instant, cost: bucket.costUSD, billing: nil, tokens: true, requests: bucket.requestCount))
            }
        }
        let imported = UsageImport.Result(kind: .openRouter, rows: rows, stats: stats)
        var snap = OnDeviceInsight.assemble(
            imported, source: isSample ? .sample : .file, fileName: isSample ? nil : fileName,
            now: now, timeZone: timeZone, budget: budget)
        snap.imports = imports
        return snap
    }

    private func row(
        _ bucket: DayModelBucket, instant: Date, cost: Double, billing: String?, tokens: Bool, requests: Int
    ) -> ImportedActivity {
        ImportedActivity(
            generationID: bucket.key + (billing ?? ""), createdAt: UsageImport.isoUTC(instant), instant: instant,
            costUSD: cost, tokensPrompt: tokens ? bucket.tokensPrompt : 0, tokensCompletion: tokens ? bucket.tokensCompletion : 0,
            tokensReasoning: 0, tokensCached: tokens ? bucket.tokensCached : 0,
            tokensCacheWrite: tokens ? bucket.tokensCacheWrite : 0, model: bucket.model, providerName: bucket.providerName,
            providerSource: bucket.providerSource, billingType: billing, requestCount: requests,
            countsAsBatch: tokens && bucket.batchRequests > 0, tierKnown: tokens && bucket.tierKnownRequests > 0)
    }
}
