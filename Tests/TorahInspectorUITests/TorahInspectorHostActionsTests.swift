import Foundation
import Testing
import TorahInspectorCore
@testable import TorahInspectorUI

@Suite("Optional host actions and entry modes")
struct TorahInspectorHostActionsTests {
    @Test func defaultsDoNotRequireAnyAppCallbacks() {
        let actions = TorahInspectorHostActions()
        #expect(actions.onClose == nil)
        #expect(actions.onInsertSegment == nil)
        #expect(actions.onOpenInNewTab == nil)
    }

    @Test func entryModesAreDistinct() {
        let modeDefault = TorahInspectorEntryMode.sourceReader
        let modeSegment = TorahInspectorEntryMode.segmentRelationships
        switch modeDefault {
        case .sourceReader:
            #expect(true)
        case .segmentRelationships:
            #expect(false)
        }
        switch modeSegment {
        case .segmentRelationships:
            #expect(true)
        case .sourceReader:
            #expect(false)
        }
    }

    @Test func hostOpenInNewTabOnlyTriggersWhenExplicitlyCalled() {
        var openedInNewTab: TorahInspectorSelection?
        let actions = TorahInspectorHostActions(
            onOpenInNewTab: { selection in
                openedInNewTab = selection
            }
        )
        #expect(openedInNewTab == nil)
        let selection = TorahInspectorSelection(providerID: "test", canonicalRef: "Genesis 1:1")
        actions.onOpenInNewTab?(selection)
        #expect(openedInNewTab == selection)
    }

    @Test func routesPreserveIdentityAndEquality() {
        let seg1 = TorahTextSegment(canonicalRef: "Genesis 1:1", text: "In the beginning", ordinal: 1)
        let seg2 = TorahTextSegment(canonicalRef: "Genesis 1:1", text: "In the beginning", ordinal: 1)
        let seg3 = TorahTextSegment(canonicalRef: "Genesis 1:2", text: "And the earth", ordinal: 2)
        #expect(TorahInspectorRoute.segment(seg1) == TorahInspectorRoute.segment(seg2))
        #expect(TorahInspectorRoute.segment(seg1) != TorahInspectorRoute.segment(seg3))

        let sel1 = TorahInspectorSelection(providerID: "p1", canonicalRef: "Gen 1")
        let sel2 = TorahInspectorSelection(providerID: "p1", canonicalRef: "Gen 1")
        #expect(TorahInspectorRoute.source(sel1) == TorahInspectorRoute.source(sel2))
    }

    @Test func relationshipEntryResolvesTheRequestedRealSegment() {
        let first = TorahTextSegment(canonicalRef: "Genesis 1:1", text: "In the beginning", ordinal: 1)
        let requested = TorahTextSegment(canonicalRef: "Genesis 1:2", text: "And the earth", ordinal: 2)
        let document = TorahTextDocument(
            providerID: "test",
            requestedRef: "Genesis 1",
            canonicalRef: "Genesis 1",
            sectionRef: "Genesis 1",
            segments: [first, requested],
            version: TorahTextVersionMetadata(language: "en", versionTitle: "Fixture")
        )

        let resolved = TorahInspectorSegmentResolver.segment(
            in: document,
            preferredReference: requested.canonicalRef
        )

        #expect(resolved == requested)
        #expect(resolved?.text.isEmpty == false)
    }

    @Test func referencesAndRelationshipTextFollowLocaleWithFallback() {
        let source = TorahLinkedSource(
            sourceRef: "Genesis 1:1",
            sourceHebrewRef: "בראשית א׳:א׳",
            category: "Tanakh",
            type: "reference",
            hebrewText: "בראשית",
            englishText: "In the beginning"
        )

        #expect(TorahInspectorPresentation.reference(
            canonical: source.sourceRef,
            hebrew: source.sourceHebrewRef,
            locale: Locale(identifier: "he_IL")
        ) == source.sourceHebrewRef)
        #expect(TorahInspectorPresentation.reference(
            canonical: source.sourceRef,
            hebrew: source.sourceHebrewRef,
            locale: Locale(identifier: "en_US")
        ) == source.sourceRef)
        #expect(TorahInspectorPresentation.linkedText(source, locale: Locale(identifier: "he_IL")) == "בראשית")
        #expect(TorahInspectorPresentation.linkedText(source, locale: Locale(identifier: "en_US")) == "In the beginning")
    }
}
