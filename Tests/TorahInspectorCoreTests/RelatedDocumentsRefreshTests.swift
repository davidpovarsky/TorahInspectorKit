import Foundation
import Testing
@testable import TorahInspectorCore

private actor RelatedFetchGate {
    private var started: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?
    private var didStart = false
    private var calls = 0
    func fetch() async -> TorahRelatedDocumentsSnapshot {
        calls += 1
        if calls == 1 {
            didStart = true
            started?.resume()
            await withCheckedContinuation { release = $0 }
            return .init(documents: [], coverage: .currentDocumentOnly)
        }
        return .init(documents: [], coverage: .indexedDocumentsOnly,
                     limitations: [.blockAssociationsNotIndexed, .indexFreshnessUnverified])
    }
    func waitForStart() async {
        if didStart { return }
        await withCheckedContinuation { started = $0 }
    }
    func finishOld() { release?.resume(); release = nil }
    func count() -> Int { calls }
}

@Test @MainActor func invalidatedLateResultCannotReplaceFreshRelatedDocuments() async throws {
    let gate = RelatedFetchGate()
    let selection = TorahInspectorSelection(providerID: "test", canonicalRef: "Genesis 1")
    let repository = TorahInspectorRepository(
        textFetcher: { _, _ in throw CancellationError() },
        relatedDocumentsFetcher: { _ in await gate.fetch() }
    )
    let old = Task { try await repository.relatedDocuments(for: selection) }
    await gate.waitForStart()
    let fresh = try await repository.relatedDocuments(for: selection, forceRefresh: true)
    await gate.finishOld()
    do {
        _ = try await old.value
        Issue.record("An invalidated result was returned")
    } catch is CancellationError { }
    let cached = try await repository.relatedDocuments(for: selection)
    #expect(fresh == cached)
    #expect(cached.coverage == .indexedDocumentsOnly)
    #expect(cached.limitations == [.blockAssociationsNotIndexed, .indexFreshnessUnverified])
    #expect(await gate.count() == 2)
}

private actor RelatedCoverageRuntime {
    private var current: TorahRelatedDocumentsSnapshot

    init(_ snapshot: TorahRelatedDocumentsSnapshot) { current = snapshot }
    func replace(with snapshot: TorahRelatedDocumentsSnapshot) { current = snapshot }
    func fetch() -> TorahRelatedDocumentsSnapshot { current }
}

@Test @MainActor func refreshedCoverageRetainsExactBlocksAndDropsThemAfterRuntimeFallback() async throws {
    let source = TorahInspectorSelection(providerID: "test", canonicalRef: "Genesis 1")
    let document = TorahRelatedDocument(
        id: "space-document", spaceID: "space", objectID: "document", title: "Document",
        sourceReference: source.relationshipRef, canUnlink: true
    )
    let quote = TorahRelatedDocument(
        id: "space-document-quote", spaceID: "space", objectID: "document", title: "Document",
        sourceReference: source.relationshipRef, blockID: "quoted-block", canUnlink: false
    )
    let fallback = TorahRelatedDocumentsSnapshot(
        documents: [document], coverage: .indexedDocumentsOnly,
        limitations: [.blockAssociationsNotIndexed, .sourceQuotesNotIndexed, .indexFreshnessUnverified]
    )
    let runtime = RelatedCoverageRuntime(fallback)
    let repository = TorahInspectorRepository(
        textFetcher: { _, _ in throw CancellationError() },
        relatedDocumentsFetcher: { _ in await runtime.fetch() }
    )
    #expect(try await repository.relatedDocuments(for: source) == fallback)

    let expanded = TorahRelatedDocumentsSnapshot(
        documents: [document, quote], coverage: .indexedTargetsOnly,
        limitations: [.indexFreshnessUnverified, .resultLimitReached]
    )
    await runtime.replace(with: expanded)
    let upgraded = try await repository.relatedDocuments(for: source, forceRefresh: true)
    #expect(upgraded.documents.map(\.blockID) == [nil, "quoted-block"])
    #expect(upgraded.documents.map(\.canUnlink) == [true, false])
    #expect(upgraded.coverage != .spaceWide)
    #expect(upgraded.limitations == [.indexFreshnessUnverified, .resultLimitReached])
    #expect(try await repository.relatedDocuments(for: source) == upgraded)

    await runtime.replace(with: fallback)
    let downgraded = try await repository.relatedDocuments(for: source, forceRefresh: true)
    #expect(downgraded == fallback)
    #expect(try await repository.relatedDocuments(for: source) == fallback)
}
