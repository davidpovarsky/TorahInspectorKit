import Foundation
import Testing
@testable import TorahInspectorCore

@Suite("Inspector document consumer cancellation", .serialized)
@MainActor
struct DocumentConsumerCancellationTests {
    @Test("A cancelled reader cannot publish a late document or cancel another reader")
    func cancelledOwnerPreservesSharedFetch() async throws {
        let gate = DocumentConsumerFetchGate()
        let repository = TorahInspectorRepository(textFetcher: { _, _ in await gate.fetch() })
        let abandoned = Task { try await repository.document(for: "Genesis 1", providerID: "test") }
        await gate.waitForStart()
        abandoned.cancel()
        let remaining = Task { try await repository.document(for: "Genesis 1", providerID: "test") }
        await gate.finish()

        await expectCancellation(from: abandoned)
        let document = try await remaining.value
        #expect(document.canonicalRef == "Genesis 1")
        #expect(await gate.callCount == 1)
        #expect(repository.cachedDocument(for: "Genesis 1", providerID: "test") == document)
    }

    @Test("Cancelling a joined reader preserves the original reader and shared cache")
    func cancelledJoinerPreservesOriginalReader() async throws {
        let gate = DocumentConsumerFetchGate()
        let repository = TorahInspectorRepository(textFetcher: { _, _ in await gate.fetch() })
        let original = Task { try await repository.document(for: "Genesis 1", providerID: "test") }
        await gate.waitForStart()
        let entered = DocumentConsumerLatch()
        let abandoned = Task {
            entered.signal()
            return try await repository.document(for: "Genesis 1", providerID: "test")
        }
        await entered.wait()
        abandoned.cancel()
        await gate.finish()

        await expectCancellation(from: abandoned)
        let document = try await original.value
        #expect(document.canonicalRef == "Genesis 1")
        #expect(await gate.callCount == 1)
        #expect(repository.cachedDocument(for: "Genesis 1", providerID: "test") == document)
    }

    @Test("A cancelled cached read returns cancellation instead of stale success")
    func cancelledCachedReadIsRejected() async throws {
        let calls = DocumentConsumerCallCount()
        let repository = TorahInspectorRepository(textFetcher: { _, _ in
            await calls.increment()
            return Self.fixture
        })
        _ = try await repository.document(for: "Genesis 1", providerID: "test")
        let abandoned = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await repository.document(for: "Genesis 1", providerID: "test")
        }

        await expectCancellation(from: abandoned)
        #expect(await calls.value == 1)
        #expect(repository.cachedDocument(for: "Genesis 1", providerID: "test") != nil)
    }

    @Test("An already cancelled read never starts a provider request")
    func cancelledColdReadDoesNotFetch() async {
        let calls = DocumentConsumerCallCount()
        let repository = TorahInspectorRepository(textFetcher: { _, _ in
            await calls.increment()
            return Self.fixture
        })
        let abandoned = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await repository.document(for: "Genesis 1", providerID: "test")
        }

        await expectCancellation(from: abandoned)
        #expect(await calls.value == 0)
        #expect(repository.cachedDocument(for: "Genesis 1", providerID: "test") == nil)
    }

    nonisolated static var fixture: TorahTextDocument {
        TorahTextDocument(
            providerID: "test",
            requestedRef: "Genesis 1",
            canonicalRef: "Genesis 1",
            sectionRef: "Genesis 1",
            segments: [TorahTextSegment(canonicalRef: "Genesis 1:1", text: "Fixture", ordinal: 1)],
            version: TorahTextVersionMetadata(language: "en", versionTitle: "Fixture")
        )
    }

    private func expectCancellation(from task: Task<TorahTextDocument, Error>) async {
        do {
            _ = try await task.value
            Issue.record("A cancelled document consumer received a successful result")
        } catch is CancellationError {
        } catch {
            Issue.record("Expected cancellation, received \(error)")
        }
    }
}

private actor DocumentConsumerFetchGate {
    private var started = false
    private var startedWaiter: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?
    private(set) var callCount = 0

    func fetch() async -> TorahTextDocument {
        callCount += 1
        await withCheckedContinuation { continuation in
            release = continuation
            started = true
            startedWaiter?.resume()
            startedWaiter = nil
        }
        return DocumentConsumerCancellationTests.fixture
    }

    func waitForStart() async {
        if started { return }
        await withCheckedContinuation { startedWaiter = $0 }
    }

    func finish() {
        release?.resume()
        release = nil
    }
}

@MainActor
private final class DocumentConsumerLatch {
    private var signalled = false
    private var waiter: CheckedContinuation<Void, Never>?

    func signal() {
        signalled = true
        waiter?.resume()
        waiter = nil
    }

    func wait() async {
        if signalled { return }
        await withCheckedContinuation { waiter = $0 }
    }
}

private actor DocumentConsumerCallCount {
    private(set) var value = 0
    func increment() { value += 1 }
}
