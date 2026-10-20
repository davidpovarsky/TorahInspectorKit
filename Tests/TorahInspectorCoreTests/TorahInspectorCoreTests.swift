import Foundation
import Testing
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
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

    @Test @MainActor func optionalNotesProviderDefaultsToEmptyAndSupportsRefresh() async throws {
        let selection = TorahInspectorSelection(
            providerID: "fixture",
            canonicalRef: "Genesis 1:1",
            preferredSegmentRef: "Genesis 1:1"
        )
        let compatibleRepository = TorahInspectorRepository(textFetcher: { reference, _ in
            makeDocument(reference: reference)
        })
        #expect(try await compatibleRepository.notes(for: selection).isEmpty)

        let count = Counter()
        let repository = TorahInspectorRepository(
            textFetcher: { reference, _ in makeDocument(reference: reference) },
            notesFetcher: { _ in
                await count.increment()
                return [TorahInspectorNote(id: "42", selectedText: "בראשית", note: "My note", tag: "study")]
            }
        )
        let first = try await repository.notes(for: selection)
        let cached = try await repository.notes(for: selection)
        #expect(first == cached)
        #expect(first.first == TorahInspectorNote(id: "42", selectedText: "בראשית", note: "My note", tag: "study"))
        let cachedFetchCount = await count.value()
        #expect(cachedFetchCount == 1)
        repository.invalidateNotes(for: selection)
        _ = try await repository.notes(for: selection)
        let refreshedFetchCount = await count.value()
        #expect(refreshedFetchCount == 2)
    }
}

@Suite("Inspector identity and relationships")
struct InspectorIdentityTests {
    @Test func sectionAndSegmentSelectionsHaveExplicitDistinctIdentity() {
        let section = TorahInspectorSelection(
            providerID: "sefaria",
            canonicalRef: "Genesis 1",
            scope: .section
        )
        let segment = TorahInspectorSelection(
            providerID: "sefaria",
            canonicalRef: "Genesis 1",
            preferredSegmentRef: "Genesis 1:1",
            scope: .segment
        )
        #expect(section.scope == .section)
        #expect(section.preferredSegmentRef == nil)
        #expect(section.relationshipRef == "Genesis 1")
        #expect(segment.scope == .segment)
        #expect(segment.relationshipRef == "Genesis 1:1")
        #expect(section.id != segment.id)

        // Verify that section scope always returns canonicalRef even when preferredSegmentRef is present
        let sectionWithSegmentRef = TorahInspectorSelection(
            providerID: "otzaria",
            canonicalRef: "otzaria:unit:v1:1:ch1:1:50",
            preferredSegmentRef: "otzaria:v1:1:1",
            scope: .section
        )
        #expect(sectionWithSegmentRef.scope == .section)
        #expect(sectionWithSegmentRef.relationshipRef == "otzaria:unit:v1:1:ch1:1:50")

        // Verify that segment scope falls back to canonicalRef when preferredSegmentRef is nil
        let segmentWithoutPreferred = TorahInspectorSelection(
            providerID: "otzaria",
            canonicalRef: "otzaria:v1:1:5",
            preferredSegmentRef: nil,
            scope: .segment
        )
        #expect(segmentWithoutPreferred.scope == .segment)
        #expect(segmentWithoutPreferred.relationshipRef == "otzaria:v1:1:5")
    }

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
        #expect(groups.commentaryGroups.count == 2)
    }

    @Test func commentaryGroupingSeparatesQuotingCommentaryIntoDistinctGroup() {
        let sources = [
            TorahLinkedSource(
                sourceRef: "Rashi on Genesis 1:1",
                category: "Commentary",
                type: "commentary",
                collectiveTitle: "Rashi",
                canonicalBookID: "sefaria:Rashi on Genesis",
                anchorRefs: ["Genesis 1:1"]
            ),
            TorahLinkedSource(
                sourceRef: "Rashi on Genesis 1:2",
                category: "Commentary",
                type: "commentary",
                collectiveTitle: "Rashi",
                canonicalBookID: "sefaria:Rashi on Genesis",
                anchorRefs: ["Genesis 1:2"]
            ),
            TorahLinkedSource(
                sourceRef: "Rashi on Exodus 1:1",
                category: "Quoting Commentary",
                type: "quoting commentary",
                collectiveTitle: "Rashi",
                canonicalBookID: "sefaria:Rashi on Exodus",
                anchorRefs: ["Exodus 1:1"]
            )
        ]

        let groups = TorahRelationshipGroups(sources: sources)

        #expect(groups.commentaryGroups.count == 1)
        #expect(groups.commentaryGroups[0].title == "Rashi")
        #expect(groups.commentaryGroups[0].entries.count == 2)
        #expect(groups.quotingCommentaryGroups.count == 1)
        #expect(groups.quotingCommentaryGroups[0].title == "Rashi")
        #expect(groups.quotingCommentaryGroups[0].category == .quotingCommentary)
        #expect(groups.quotingCommentaryGroups[0].entries.first?.sourceRef == "Rashi on Exodus 1:1")
    }

    @Test func commentatorGroupingUnifiesSameCommentatorAcrossMultipleWorks() {
        let sources = [
            TorahLinkedSource(
                sourceRef: "Chomat Anakh on Psalms 1:1",
                category: "Commentary",
                type: "commentary",
                collectiveTitle: "Chomat Anakh",
                commentatorID: "author:chida",
                commentatorName: "Chida",
                workTitle: "Chomat Anakh on Psalms",
                canonicalBookID: "book:101",
                anchorRefs: ["Psalms 1:1"]
            ),
            TorahLinkedSource(
                sourceRef: "Chomat Anakh on Psalms 2:1",
                category: "Commentary",
                type: "commentary",
                collectiveTitle: "Chomat Anakh",
                commentatorID: "author:chida",
                commentatorName: "Chida",
                workTitle: "Chomat Anakh on Psalms",
                canonicalBookID: "book:101",
                anchorRefs: ["Psalms 2:1"]
            ),
            TorahLinkedSource(
                sourceRef: "Marit HaAyin on Berakhot 2a:1",
                category: "Commentary",
                type: "commentary",
                collectiveTitle: "Marit HaAyin",
                commentatorID: "author:chida",
                commentatorName: "Chida",
                workTitle: "Marit HaAyin",
                canonicalBookID: "book:102",
                anchorRefs: ["Berakhot 2a:1"]
            )
        ]

        let groups = TorahRelationshipGroups(sources: sources)

        #expect(groups.commentaryGroups.count == 1)
        let chidaGroup = groups.commentaryGroups[0]
        #expect(chidaGroup.id == "author:chida")
        #expect(chidaGroup.title == "Chida")
        #expect(chidaGroup.count == 3)
        #expect(chidaGroup.works.count == 2)
        #expect(chidaGroup.works.map(\.title) == ["Chomat Anakh on Psalms", "Marit HaAyin"])
        #expect(chidaGroup.works[0].count == 2)
        #expect(chidaGroup.works[1].count == 1)
    }

    @Test func differentCommentatorsWithSimilarNamesRemainSeparate() {
        let sources = [
            TorahLinkedSource(
                sourceRef: "Ibn Ezra on Genesis 1:1",
                category: "Commentary",
                type: "commentary",
                commentatorID: "author:ibn-ezra",
                commentatorName: "Ibn Ezra",
                canonicalBookID: "book:201"
            ),
            TorahLinkedSource(
                sourceRef: "Ibn Caspi on Genesis 1:1",
                category: "Commentary",
                type: "commentary",
                commentatorID: "author:ibn-caspi",
                commentatorName: "Ibn Caspi",
                canonicalBookID: "book:202"
            )
        ]

        let groups = TorahRelationshipGroups(sources: sources)
        #expect(groups.commentaryGroups.count == 2)
        #expect(groups.commentaryGroups.map(\.id) == ["author:ibn-ezra", "author:ibn-caspi"])
    }

#if canImport(UniformTypeIdentifiers)
    @Test func transferPayloadKeepsPinkhaUTTypeAndRoundTrips() throws {
        let transfer = TorahSourceTransfer(segment: makeDocument().segments[0], document: makeDocument())
        let decoded = try JSONDecoder().decode(TorahSourceTransfer.self, from: JSONEncoder().encode(transfer))
        #expect(decoded == transfer)
        #expect(UTType.torahSource.identifier == "com.gloiiire.pinkha.torahSource")
    }
#endif

    @Test func changingSelectedSegmentUpdatesPreferredIdentity() {
        let seg1 = TorahTextSegment(canonicalRef: "Berakhot 2a:1", text: "From when", ordinal: 1)
        let seg2 = TorahTextSegment(canonicalRef: "Berakhot 2a:2", text: "They may recite", ordinal: 2)
        var selection = TorahInspectorSelection(
            providerID: "sefaria",
            canonicalRef: "Berakhot 2a",
            preferredSegmentRef: seg1.canonicalRef
        )
        #expect(selection.prefers(seg1))
        #expect(!selection.prefers(seg2))

        selection = TorahInspectorSelection(
            providerID: "sefaria",
            canonicalRef: "Berakhot 2a",
            preferredSegmentRef: seg2.canonicalRef
        )
        #expect(!selection.prefers(seg1))
        #expect(selection.prefers(seg2))
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

@Suite("Snippet hydration")
struct SnippetHydrationTests {
    @Test @MainActor func fetchSnippetsUsesInlineTextWhenAvailable() async throws {
        let repo = TorahInspectorRepository(
            textFetcher: { _, _ in makeDocument() },
            snippetsFetcher: { _ in [:] }
        )
        let sourceWithInline = TorahLinkedSource(
            sourceRef: "Ref:1",
            category: "Commentary",
            type: "commentary",
            hebrewText: "פירוש ראשוני"
        )
        let results = try await repo.fetchSnippets(for: [sourceWithInline])
        #expect(results[sourceWithInline.id] == "פירוש ראשוני")
        #expect(repo.cachedSnippet(for: sourceWithInline.id) == "פירוש ראשוני")
    }

    @Test @MainActor func fetchSnippetsFetchesAndCachesUnhydratedSources() async throws {
        let fetchCount = Counter()
        let sourceUnhydrated = TorahLinkedSource(
            sourceRef: "Ref:2",
            category: "Commentary",
            type: "commentary"
        )
        let repo = TorahInspectorRepository(
            textFetcher: { _, _ in makeDocument() },
            snippetsFetcher: { sources in
                await fetchCount.increment()
                return [sourceUnhydrated.id: "טקסט שנשלף"]
            }
        )
        #expect(repo.cachedSnippet(for: sourceUnhydrated.id) == nil)
        let results = try await repo.fetchSnippets(for: [sourceUnhydrated])
        #expect(results[sourceUnhydrated.id] == "טקסט שנשלף")
        #expect(repo.cachedSnippet(for: sourceUnhydrated.id) == "טקסט שנשלף")
        #expect(await fetchCount.value() == 1)

        // Second call should hit the cache without calling fetcher
        let secondResults = try await repo.fetchSnippets(for: [sourceUnhydrated])
        #expect(secondResults[sourceUnhydrated.id] == "טקסט שנשלף")
        #expect(await fetchCount.value() == 1)

        // Invalidating snippets clears cache
        repo.invalidateSnippets()
        #expect(repo.cachedSnippet(for: sourceUnhydrated.id) == nil)
    }
}

@Suite("Relationship classification & grouping")
struct RelationshipClassificationTests {
    @Test func infersCommentaryFromHebrewAndEnglishTokens() {
        let hebrewComm = TorahLinkedSource(
            sourceRef: "Rashi on Genesis 7:1",
            category: "תנ״ך / פירושים",
            type: "פירוש"
        )
        #expect(hebrewComm.relationshipKind == .commentary)
        #expect(hebrewComm.semanticCategory == .commentary)

        let parshanut = TorahLinkedSource(
            sourceRef: "Ibn Ezra on Genesis 7:1",
            category: "Commentary",
            type: "PARSHANUT"
        )
        #expect(parshanut.relationshipKind == .commentary)
        #expect(parshanut.semanticCategory == .commentary)

        let superComm = TorahLinkedSource(
            sourceRef: "Gur Aryeh on Rashi",
            category: "Commentary",
            type: "SUPER_COMMENTARY"
        )
        #expect(superComm.relationshipKind == .commentary)

        let dh = TorahLinkedSource(
            sourceRef: "Tosafot on Berakhot 2a",
            category: "Commentary",
            type: "DIBUR_HAMATCHIL"
        )
        #expect(dh.relationshipKind == .commentary)

        let crossRef = TorahLinkedSource(
            sourceRef: "Genesis 1:1",
            category: "תנ״ך",
            type: "REFERENCE"
        )
        #expect(crossRef.relationshipKind == .link)
        #expect(crossRef.semanticCategory == .tanakh)

        let targum = TorahLinkedSource(
            sourceRef: "Targum Onkelos",
            category: "Targum",
            type: "TARGUM"
        )
        #expect(targum.relationshipKind == .link)
        #expect(targum.semanticCategory == .targum)
    }

    @Test func relationshipGroupsPartitionsCommentariesAndLinksAccurately() {
        let rashi = TorahLinkedSource(
            sourceRef: "Rashi on Genesis 7:1",
            category: "Commentary",
            type: "COMMENTARY",
            commentatorID: "author:rashi",
            commentatorName: "רש״י",
            relationshipKind: .commentary
        )
        let ramban = TorahLinkedSource(
            sourceRef: "Ramban on Genesis 7:1",
            category: "Commentary",
            type: "PARSHANUT",
            commentatorID: "author:ramban",
            commentatorName: "רמב״ן",
            relationshipKind: .commentary
        )
        let ref = TorahLinkedSource(
            sourceRef: "Psalms 28:1",
            category: "Tanakh",
            type: "REFERENCE",
            relationshipKind: .link,
            semanticCategory: .tanakh
        )

        let groups = TorahRelationshipGroups(sources: [rashi, ramban, ref])
        #expect(groups.commentary.count == 2)
        #expect(groups.commentaryGroups.count == 2)
        #expect(groups.linkedSources.count == 1)
        #expect(groups.linkedSourceGroups.count == 1)
        #expect(groups.commentary.count + groups.quotingCommentary.count + groups.linkedSources.count == 3)
    }
}


