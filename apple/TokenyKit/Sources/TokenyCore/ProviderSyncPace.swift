import Foundation

/// Cursor's usage API is fetched at most once an hour. Other providers follow the app's own refresh.
public enum ProviderSyncPace {
    public static let cursorInterval: TimeInterval = 60 * 60

    public static func shouldFetch(provider: String, lastSuccess: Date?, now: Date) -> Bool {
        guard provider == "cursor" else { return true }
        guard let lastSuccess else { return true }
        return now.timeIntervalSince(lastSuccess) >= cursorInterval
    }

    /// Latest successful API import for this provider, from records the ledger already stores.
    public static func lastSuccess(imports: [ProviderImportRecord], provider: String) -> Date? {
        for record in imports.reversed() {
            guard record.provider == provider, record.method == "api", record.outcome == "ok" else { continue }
            if let date = ISO8601.date(from: record.at) { return date }
        }
        return nil
    }
}
