import Foundation
import Testing
import UniformTypeIdentifiers
@testable import TorahInspectorCore

private struct FixtureProvider: TorahInspectorProvider {
    let providerID = "fixture"

    func fetchText(reference: String, request: TorahTextRequest) async throws -> TorahTextDocument {
        makeDocument(reference: reference)
    }

    func links(for reference: String) async throws -> [TorahLinkedSource] {
        [.init(sourceRef: "Rashi 1", category: "Commentary", type: "commentary")]
    }

    func topics(for reference: String) async throws -> [TorahLinkedTopic] {
        [.init(slug: "creation", titleHe: "בריאה", titleEn: "Creation")]
    }
}

private actor Counter {
    private var count = 0
    func increment() { count += 1 }
    func value() -> Int { count }
}

private func makeDocument(reference: String = "Genesis 1") -> TorahTextDocument {
    TorahTextDocument(
        providerID: "fixture",
        requestedRef: reference,
        canonicalRef: reference,
        hebrewRef: "בראשית א",
        sectionRef: reference,
        hebrewSectionRef: "בראשית א",
        segments: [
            TorahTextSegment(canonicalRef: "\(reference):1", hebrewRef: "בראשית א:א", text: "בראשית", ordinal: 1)
        ],
        previousSectionRef: "Genesis 0",
        nextSectionRef: "Genesis 2",
        version: TorahTextVersionMetadata(language: "he", versionTitle: "Fixture", direction: "rtl")
    )
}

@Suite("Repository boundary")
struct RepositoryBoundaryTests {
    @Test @MainActor func mapsCombinedProviderAndRejectsAnotherProviderID() async throws {
        let repository = TorahInspectorRepository(provider: FixtureProvider())
        #expect(try await repository.document(for: "Genesis 1", providerID: "fixture").providerID == "fixture")
        #expect(try await repository.links(for: "Genesis 1:1", providerID: "fixture").count == 1)
        #expect(try await repository.topics(for: "Genesis 1:1", providerID: "fixture").first?.slug == "creation")
        await #expect(throws: TorahError.missingProvider) {
            try await repository.document(for: "Genesis 1", providerID: "other")
        }
    }

    @Test @MainActor func providerErrorsArePreservedAndRetryStartsANewFetch() async throws {
        let attempts = Counter()
        let repository = TorahInspectorRepository(textFetcher: { reference, _ in
            await attempts.increment()
            if await attempts.value() == 1 { throw TorahError.network("offline") }
            return makeDocument(reference: reference)
        })
        await #expect(throws: TorahError.network("offline")) {
            try await repository.document(for: "Genesis 1", providerID: "fixture")
        }
        #expect(try await repository.document(for: "Genesis 1", providerID: "fixture").canonicalRef == "Genesis 1")
        let attemptCount = await attempts.value()
        #expect(attemptCount == 2)
    }

    @Test @MainActor func simultaneousRequestsShareOneProviderFetch() async throws {
        let count = Counter()
        let repository = TorahInspectorRepository(textFetcher: { reference, _ in
            await count.increment()
            try await Task.sleep(for: .milliseconds(25))
            return makeDocument(reference: reference)
        })
        async let first = repository.document(for: "Genesis 1", providerID: "fixture")
        async let second = repository.document(for: "Genesis 1", providerID: "fixture")
        _ = try await (first, second)
        let fetchCount = await count.value()
        #expect(fetchCount == 1)
    }
}

@Suite("Inspector identity and relationships")
struct InspectorIdentityTests {
    @Test func preferredSegmentUsesStableReferenceIdentity() {
        let document = makeDocument()
        let selection = TorahInspectorSelection(
            providerID: "fixture",
            canonicalRef: document.canonicalRef,
            preferredSegmentRef: document.segments[0].canonicalRef
        )
        #expect(selection.prefers(document.segments[0]))
        #expect(!selection.prefers(.init(canonicalRef: "Genesis 1:2", text: "השמים", ordinal: 2)))
    }

    @Test func commentaryGroupingAcceptsProviderCategoryOrTypeCasing() {
        let sources = [
            TorahLinkedSource(sourceRef: "Rashi", category: "Commentary", type: "commentary"),
            TorahLinkedSource(sourceRef: "Local", category: "COMMENTARY", type: "link"),
            TorahLinkedSource(sourceRef: "Midrash", category: "Midrash", type: "midrash")
        ]
        let groups = TorahRelationshipGroups(sources: sources)
        #expect(groups.commentary.map(\.sourceRef) == ["Rashi", "Local"])
        #expect(groups.linkedSources.map(\.sourceRef) == ["Midrash"])
    }

    @Test func transferPayloadKeepsPinkhaUTTypeAndRoundTrips() throws {
        let transfer = TorahSourceTransfer(segment: makeDocument().segments[0], document: makeDocument())
        let decoded = try JSONDecoder().decode(TorahSourceTransfer.self, from: JSONEncoder().encode(transfer))
        #expect(decoded == transfer)
        #expect(UTType.torahSource.identifier == "com.gloiiire.pinkha.torahSource")
    }
}

@Suite("Reader navigation state")
struct ReaderNavigationStateTests {
    @Test @MainActor func underfilledInitialDocumentLoadsNextButNeverPrevious() {
        let machine = TorahReaderScrollStateMachine()
        let decision = machine.onInitialLoadComplete(hasPrevious: true, hasNext: true, isUnderfilled: true)
        #expect(!decision.shouldLoadPrevious)
        #expect(decision.shouldLoadNext)
    }

    @Test @MainActor func previousAndNextEdgesRequireExpectedScrollDirection() {
        let previous = TorahReaderScrollStateMachine()
        _ = previous.onInitialLoadComplete(hasPrevious: true, hasNext: true, isUnderfilled: false)
        _ = previous.onScrollOffsetChanged(offsetY: 120, contentHeight: 1_000, containerHeight: 400, hasPrevious: true, hasNext: true)
        #expect(previous.onScrollOffsetChanged(offsetY: 30, contentHeight: 1_000, containerHeight: 400, hasPrevious: true, hasNext: true).shouldLoadPrevious)

        let next = TorahReaderScrollStateMachine()
        _ = next.onInitialLoadComplete(hasPrevious: true, hasNext: true, isUnderfilled: false)
        _ = next.onScrollOffsetChanged(offsetY: 399, contentHeight: 1_000, containerHeight: 400, hasPrevious: true, hasNext: true)
        #expect(next.onScrollOffsetChanged(offsetY: 450, contentHeight: 1_000, containerHeight: 400, hasPrevious: true, hasNext: true).shouldLoadNext)
    }
}
