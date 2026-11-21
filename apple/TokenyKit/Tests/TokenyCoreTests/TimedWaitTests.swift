import Foundation
import Testing

@testable import TokenyCore

struct TimedWaitTests {
    @Test func returnsTheOperationResult() async throws {
        let value = try await TimedWait.run(timeout: .milliseconds(400)) { "ok" }
        #expect(value == "ok")
    }

    @Test func deadlineWhenTheOperationOutlastsTheTimeout() async {
        let started = ContinuousClock.now
        await #expect(throws: TimedWait.Deadline.self) {
            try await TimedWait.run(timeout: .milliseconds(50)) {
                try await Task.sleep(for: .seconds(3))
                return 1
            }
        }
        #expect(ContinuousClock.now - started < .milliseconds(900))
    }

    @Test func cancellationIsNotADeadline() async {
        let task = Task {
            try await TimedWait.run(timeout: .seconds(5)) {
                try await Task.sleep(for: .seconds(5))
                return 1
            }
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func productLoadWaitsTenSeconds() {
        #expect(ProductLoadPolicy.timeout == .seconds(10))
    }
}
