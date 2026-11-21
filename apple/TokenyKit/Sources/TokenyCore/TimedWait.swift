import Foundation

/// How long the paywall waits for StoreKit before it shows an error and Retry.
/// `Product.products(for:)` has no timeout of its own and can hang, for example while
/// App Store Connect subscriptions are still missing metadata.
public enum ProductLoadPolicy {
    public static let timeout: Duration = .seconds(10)
}

/// Runs an async operation until it finishes or `timeout` elapses.
public enum TimedWait {
    public struct Deadline: Error, Equatable {}

    /// The first of `operation` finishing or `timeout` elapsing wins.
    /// Cancelling the caller throws `CancellationError`, not ``Deadline``.
    public static func run<T: Sendable>(
        timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw Deadline()
            }
            let result = await group.nextResult()
            group.cancelAll()
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            case nil:
                throw Deadline()
            }
        }
    }
}
