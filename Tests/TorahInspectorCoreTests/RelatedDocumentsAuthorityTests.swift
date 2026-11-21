import Foundation
import Testing
@testable import TorahInspectorCore

@MainActor
private final class RelatedAuthorityFetcher {
    var calls = 0
    var action: @MainActor (TorahInspectorSelection) async throws -> TorahRelatedDocumentsSnapshot

    init(action: @escaping @MainActor (TorahInspectorSelection) async throws -> TorahRelatedDocumentsSnapshot) {
        self.action = action
    }

    func read(_ selection: TorahInspectorSelection) async throws -> TorahRelatedDocumentsSnapshot {
        calls += 1
        return try await action(selection)
    }
}

@MainActor
private final class RelatedAuthorityGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        opened = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

@MainActor
private final class RelatedAuthorityEvents {
    var owners: [ObjectIdentifier] = []

    func observe() -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .torahInspectorRelatedDocumentsAccessDidChange, object: nil, queue: nil
        ) { [self] notification in
            let ownerID = (notification.object as? TorahInspectorRepository).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                if let ownerID { owners.append(ownerID) }
            }
        }
    }
}

private func authoritySnapshot(
    _ selection: TorahInspectorSelection, version: Int
) -> TorahRelatedDocumentsSnapshot {
    .init(documents: [
        .init(id: selection.id + "-" + String(version), spaceID: "space", objectID: "document",
              title: "Private version " + String(version), sourceReference: selection.relationshipRef)
    ], coverage: .indexedTargetsOnly)
}

@MainActor
private func authorityRepository(_ fetcher: RelatedAuthorityFetcher) -> TorahInspectorRepository {
    TorahInspectorRepository(
        textFetcher: { _, _ in throw CancellationError() },
        relatedDocumentsFetcher: { try await fetcher.read($0) }
    )
}

@Suite("Related document current access", .serialized)
@MainActor
struct RelatedDocumentsAuthorityTests {
    @Test(arguments: [TorahRelatedDocumentsAccessError.denied, .invalidated])
    func currentAccessFailureEvictsEverySelection(reason: TorahRelatedDocumentsAccessError) async throws {
        let first = TorahInspectorSelection(providerID: "provider", canonicalRef: "Genesis 1")
        let second = TorahInspectorSelection(providerID: "provider", canonicalRef: "Exodus 1")
        let fetcher = RelatedAuthorityFetcher { authoritySnapshot($0, version: 1) }
        let repository = authorityRepository(fetcher)
        _ = try await repository.relatedDocuments(for: first)
        _ = try await repository.relatedDocuments(for: second)
        #expect(fetcher.calls == 2)
        let events = RelatedAuthorityEvents()
        let observer = events.observe()
        defer { NotificationCenter.default.removeObserver(observer) }

        fetcher.action = { _ in throw reason }
        do {
            _ = try await repository.relatedDocuments(for: first, forceRefresh: true)
            Issue.record("A confirmed access failure returned private rows")
        } catch let failure as TorahRelatedDocumentsAccessError {
            #expect(failure == reason)
        }
        #expect(events.owners == [ObjectIdentifier(repository)])

        // Permission can be restored by the engine. The shared repository must
        // obtain new results for every selection, never revive either cache.
        fetcher.action = { authoritySnapshot($0, version: 2) }
        #expect(try await repository.relatedDocuments(for: second) == authoritySnapshot(second, version: 2))
        #expect(try await repository.relatedDocuments(for: first) == authoritySnapshot(first, version: 2))
        #expect(fetcher.calls == 5)
    }

    @Test
    func retirementRejectsCachedAndNewReadsUntilReactivation() async throws {
        let selection = TorahInspectorSelection(providerID: "provider", canonicalRef: "Genesis 1")
        let fetcher = RelatedAuthorityFetcher { authoritySnapshot($0, version: 1) }
        let repository = authorityRepository(fetcher)
        _ = try await repository.relatedDocuments(for: selection)
        let events = RelatedAuthorityEvents()
        let observer = events.observe()
        defer { NotificationCenter.default.removeObserver(observer) }

        repository.retireRelatedDocuments()
        #expect(events.owners == [ObjectIdentifier(repository)], "Retirement must signal synchronously")
        for forceRefresh in [false, true] {
            do {
                _ = try await repository.relatedDocuments(for: selection, forceRefresh: forceRefresh)
                Issue.record("A retired owner read related documents")
            } catch TorahRelatedDocumentsAccessError.invalidated { }
        }
        #expect(fetcher.calls == 1)
        repository.retireRelatedDocuments()
        #expect(events.owners.count == 1)

        fetcher.action = { authoritySnapshot($0, version: 2) }
        repository.resumeRelatedDocuments()
        #expect(try await repository.relatedDocuments(for: selection) == authoritySnapshot(selection, version: 2))
        #expect(fetcher.calls == 2)
    }

    @Test
    func retiredUncooperativeResultCannotReplaceReactivatedOwner() async throws {
        let selection = TorahInspectorSelection(providerID: "provider", canonicalRef: "Genesis 1")
        let entered = RelatedAuthorityGate(), release = RelatedAuthorityGate()
        let fetcher = RelatedAuthorityFetcher { selection in
            entered.open()
            await release.wait() // Deliberately ignores Task cancellation.
            return authoritySnapshot(selection, version: 1)
        }
        let repository = authorityRepository(fetcher)
        let former = Task { try await repository.relatedDocuments(for: selection) }
        await entered.wait()
        repository.retireRelatedDocuments()
        repository.resumeRelatedDocuments()
        fetcher.action = { authoritySnapshot($0, version: 2) }
        let fresh = try await repository.relatedDocuments(for: selection)
        release.open()
        do {
            _ = try await former.value
            Issue.record("A retired flight delivered its previous owner's result")
        } catch is CancellationError { }
        #expect(fresh == authoritySnapshot(selection, version: 2))
        #expect(try await repository.relatedDocuments(for: selection) == fresh)
        #expect(fetcher.calls == 2)
    }

    @Test
    func currentDenialFencesAnUncooperativeOtherSelection() async throws {
        let first = TorahInspectorSelection(providerID: "provider", canonicalRef: "Genesis 1")
        let second = TorahInspectorSelection(providerID: "provider", canonicalRef: "Exodus 1")
        let entered = RelatedAuthorityGate(), release = RelatedAuthorityGate()
        let fetcher = RelatedAuthorityFetcher { selection in
            if selection == second {
                entered.open()
                await release.wait()
                return authoritySnapshot(selection, version: 1)
            }
            throw TorahRelatedDocumentsAccessError.denied
        }
        let repository = authorityRepository(fetcher)
        let pending = Task { try await repository.relatedDocuments(for: second) }
        await entered.wait()
        do {
            _ = try await repository.relatedDocuments(for: first)
            Issue.record("A confirmed denial returned related documents")
        } catch TorahRelatedDocumentsAccessError.denied { }
        release.open()
        do {
            _ = try await pending.value
            Issue.record("Another selection republished a pre-denial result")
        } catch is CancellationError { }
        fetcher.action = { authoritySnapshot($0, version: 2) }
        #expect(try await repository.relatedDocuments(for: second) == authoritySnapshot(second, version: 2))
        #expect(fetcher.calls == 3)
    }

    @Test
    func lateDenialCannotInvalidateNewOwnerOrAnotherRepository() async throws {
        let selection = TorahInspectorSelection(providerID: "provider", canonicalRef: "Genesis 1")
        let entered = RelatedAuthorityGate(), release = RelatedAuthorityGate()
        let fetcher = RelatedAuthorityFetcher { _ in
            entered.open()
            await release.wait()
            throw TorahRelatedDocumentsAccessError.denied
        }
        let repository = authorityRepository(fetcher)
        let otherFetcher = RelatedAuthorityFetcher { authoritySnapshot($0, version: 9) }
        let otherRepository = authorityRepository(otherFetcher)
        let other = try await otherRepository.relatedDocuments(for: selection)
        let events = RelatedAuthorityEvents()
        let observer = events.observe()
        defer { NotificationCenter.default.removeObserver(observer) }
        let former = Task { try await repository.relatedDocuments(for: selection) }
        await entered.wait()

        repository.retireRelatedDocuments()
        repository.resumeRelatedDocuments()
        fetcher.action = { authoritySnapshot($0, version: 2) }
        let fresh = try await repository.relatedDocuments(for: selection)
        release.open()
        do {
            _ = try await former.value
            Issue.record("A stale denial escaped into the new owner")
        } catch is CancellationError { }
        #expect(events.owners == [ObjectIdentifier(repository)], "Only the explicit retirement may signal")
        #expect(try await repository.relatedDocuments(for: selection) == fresh)
        #expect(try await otherRepository.relatedDocuments(for: selection) == other)
        #expect(fetcher.calls == 2)
        #expect(otherFetcher.calls == 1)
    }

    @Test
    func transientFailureKeepsOtherCachesAndDoesNotSignalAuthorityLoss() async throws {
        let first = TorahInspectorSelection(providerID: "provider", canonicalRef: "Genesis 1")
        let second = TorahInspectorSelection(providerID: "provider", canonicalRef: "Exodus 1")
        let fetcher = RelatedAuthorityFetcher { authoritySnapshot($0, version: 1) }
        let repository = authorityRepository(fetcher)
        _ = try await repository.relatedDocuments(for: first)
        let retained = try await repository.relatedDocuments(for: second)
        let events = RelatedAuthorityEvents()
        let observer = events.observe()
        defer { NotificationCenter.default.removeObserver(observer) }
        fetcher.action = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await repository.relatedDocuments(for: first, forceRefresh: true)
            Issue.record("The offline refresh unexpectedly succeeded")
        } catch let failure as URLError {
            #expect(failure.code == .notConnectedToInternet)
        }
        #expect(events.owners.isEmpty)
        #expect(try await repository.relatedDocuments(for: second) == retained)
        #expect(fetcher.calls == 3)
    }
}
