import Foundation
import Testing
@testable import TorahInspectorUI

@MainActor
@Suite("Reader document load ownership", .timeLimit(.minutes(1)))
struct TorahDocumentLoadLifetimeTests {
    @Test(arguments: [false, true])
    func newerSelectionRejectsLateProviderCompletion(providerFails: Bool) async throws {
        let lifetime = TorahDocumentLoadLifetime()
        let old = lifetime.activate(selectionID: "source-a")
        let provider = SuspendedReaderDocument()
        let pending = Task { try await lifetime.load(for: old) { try await provider.read() } }
        defer { provider.cancelOutstanding(); pending.cancel() }
        try await provider.waitUntilStarted()

        let current = lifetime.activate(selectionID: "source-b")
        let value = try await lifetime.load(for: current) { "current-document" }
        #expect(value == "current-document")
        provider.finish(providerFails ? .failure(ReaderProbeFailure.provider) : .success("old-document"))
        await expectCancellation(pending)
        #expect(lifetime.isCurrent(current))
        #expect(lifetime.request(for: "source-a") == nil)
        #expect(provider.calls == 1)
    }

    @Test(arguments: [false, true])
    func sameSelectionRetryOrReactivationRejectsItsPriorLifetime(disappears: Bool) async throws {
        let lifetime = TorahDocumentLoadLifetime()
        let old = lifetime.activate(selectionID: "same-source")
        let provider = SuspendedReaderDocument()
        let pending = Task { try await lifetime.load(for: old) { try await provider.read() } }
        defer { provider.cancelOutstanding(); pending.cancel() }
        try await provider.waitUntilStarted()

        let current: TorahDocumentLoadLifetime.Request
        if disappears {
            lifetime.invalidate()
            #expect(lifetime.restart(for: "same-source") == nil)
            current = lifetime.activate(selectionID: "same-source")
        } else {
            current = try #require(lifetime.restart(for: "same-source"))
        }
        #expect(old != current)
        provider.finish(.success("previous-lifetime"))
        await expectCancellation(pending)
        #expect(lifetime.isCurrent(current))
        #expect(try await lifetime.load(for: current) { "current-lifetime" } == "current-lifetime")
    }

    @Test(arguments: [false, true])
    func callerCancellationRejectsANonCooperativeProvider(providerFails: Bool) async throws {
        let lifetime = TorahDocumentLoadLifetime()
        let request = lifetime.activate(selectionID: "source")
        let provider = SuspendedReaderDocument()
        let pending = Task { try await lifetime.load(for: request) { try await provider.read() } }
        defer { provider.cancelOutstanding(); pending.cancel() }
        try await provider.waitUntilStarted()

        pending.cancel()
        // Deliberately ignore cancellation at the provider boundary.
        provider.finish(providerFails ? .failure(ReaderProbeFailure.provider) : .success("late-success"))
        await expectCancellation(pending)
        #expect(provider.calls == 1)
    }

    @Test
    func preCancelledCallerDoesNotDispatchAProviderRead() async {
        let lifetime = TorahDocumentLoadLifetime()
        let request = lifetime.activate(selectionID: "source")
        var calls = 0
        let pending = Task {
            try await lifetime.load(for: request) { calls += 1; return "unexpected" }
        }
        pending.cancel()
        await expectCancellation(pending)
        #expect(calls == 0)
    }

    @Test
    func invalidatedOwnerCannotDispatchOrScheduleARetry() async {
        let lifetime = TorahDocumentLoadLifetime()
        let request = lifetime.activate(selectionID: "source")
        lifetime.invalidate()
        #expect(lifetime.request(for: "source") == nil)
        #expect(lifetime.restart(for: "source") == nil)
        var calls = 0
        do {
            _ = try await lifetime.load(for: request) { calls += 1; return "unexpected" }
            Issue.record("An invalidated owner must not dispatch a read")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected invalidated-owner error")
        }
        #expect(calls == 0)
    }

    @Test
    func currentProviderFailureRemainsAnActualFailure() async {
        let lifetime = TorahDocumentLoadLifetime()
        let request = lifetime.activate(selectionID: "source")
        do {
            let _: String = try await lifetime.load(for: request) { throw ReaderProbeFailure.provider }
            Issue.record("A current provider failure must remain visible to its caller")
        } catch ReaderProbeFailure.provider {
        } catch {
            Issue.record("Current provider failure was replaced")
        }
        #expect(lifetime.isCurrent(request))
        #expect(lifetime.restart(for: "different-source") == nil)
    }

    private func expectCancellation(_ pending: Task<String, any Error>) async {
        do {
            _ = try await pending.value
            Issue.record("A stale or cancelled reader must not publish")
        } catch is CancellationError {
        } catch {
            Issue.record("A stale provider error escaped its retired owner")
        }
    }
}

private enum ReaderProbeFailure: Error { case provider, rendezvousDeadline }

@MainActor
private final class SuspendedReaderDocument {
    private(set) var calls = 0
    private var continuation: CheckedContinuation<String, any Error>?

    func read() async throws -> String {
        try Task.checkCancellation()
        calls += 1
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func waitUntilStarted() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while continuation == nil {
            guard ContinuousClock.now < deadline else { throw ReaderProbeFailure.rendezvousDeadline }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    func finish(_ result: Result<String, any Error>) {
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }

    func cancelOutstanding() { finish(.failure(CancellationError())) }
}
