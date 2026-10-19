import Foundation
import SwiftUI
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
        #expect(actions.onAddNote == nil)
        #expect(actions.onOpenNote == nil)
        #expect(actions.onDeleteNote == nil)
        #expect(!actions.showsCloseButton)
    }

    @Test func studyToolStringsAreLocalizedInEnglishAndHebrew() {
        #expect(TorahStudyTool.commentaries.localizedTitle(locale: Locale(identifier: "en_US")) == "Commentaries")
        #expect(TorahStudyTool.links.localizedTitle(locale: Locale(identifier: "he_IL")) == "קישורים")
        #expect(TorahStudyTool.notes.localizedTitle(locale: Locale(identifier: "he_IL")) == "הערות")
        #expect(TorahStrings.text("Add Note", locale: Locale(identifier: "he_IL")) == "הוסף הערה")
        #expect(TorahStrings.text("Expand", locale: Locale(identifier: "he_IL")) == "הרחב")
    }

    @Test func sheetDetentsMapToNativePresentationDetents() {
        for detent in TorahInspectorSheetDetent.allCases {
            #expect(TorahInspectorSheetDetent(presentationDetent: detent.presentationDetent) == detent)
        }
    }

    @Test func physicalRightPlacementAccountsForLayoutDirection() {
        #expect(TorahInspectorSheetPlacementResolver.physicalRightEdge(for: .leftToRight) == .trailing)
        #expect(TorahInspectorSheetPlacementResolver.physicalRightEdge(for: .rightToLeft) == .leading)
    }

    @Test func peekUsesExactSegmentAndNeverSubstitutesAnotherSegment() {
        let first = TorahTextSegment(canonicalRef: "Genesis 1:1", text: "First", ordinal: 1)
        let second = TorahTextSegment(canonicalRef: "Genesis 1:2", text: "Second", ordinal: 2)
        let document = TorahTextDocument(
            providerID: "sefaria",
            requestedRef: "Genesis 1",
            canonicalRef: "Genesis 1",
            sectionRef: "Genesis 1",
            segments: [first, second],
            version: TorahTextVersionMetadata(language: "en", versionTitle: "Fixture")
        )

        #expect(TorahInspectorSheetPeekResolver.segment(
            in: document,
            selection: TorahInspectorSelection(
                providerID: "sefaria",
                canonicalRef: "Genesis 1",
                preferredSegmentRef: "Genesis 1:2",
                scope: .segment
            )
        ) == second)
        #expect(TorahInspectorSheetPeekResolver.segment(
            in: document,
            selection: TorahInspectorSelection(
                providerID: "sefaria",
                canonicalRef: "Genesis 1",
                preferredSegmentRef: "Genesis 1:99",
                scope: .segment
            )
        ) == nil)
        #expect(TorahInspectorSheetPeekResolver.segment(
            in: document,
            selection: TorahInspectorSelection(
                providerID: "sefaria",
                canonicalRef: "Genesis 1",
                scope: .section
            )
        ) == first)
    }

    @Test func entryModesAreDistinct() {
        let modeDefault = TorahInspectorEntryMode.sourceReader
        let modeRelationships = TorahInspectorEntryMode.relationships
        switch modeDefault {
        case .sourceReader:
            #expect(true)
        case .relationships, .segmentRelationships:
            #expect(false)
        }
        switch modeRelationships {
        case .relationships:
            #expect(true)
        case .sourceReader, .segmentRelationships:
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
        #expect(TorahInspectorSegmentResolver.segment(
            in: document,
            preferredReference: "Genesis 1:99"
        ) == nil)
    }

    @Test func fullSourceResolutionNeverFallsBackToAnUnrelatedFirstSegment() {
        let document = TorahTextDocument(
            providerID: "test",
            requestedRef: "Genesis 1",
            canonicalRef: "Genesis 1",
            sectionRef: "Genesis 1",
            segments: [
                TorahTextSegment(canonicalRef: "Genesis 1:1", text: "First", ordinal: 1),
                TorahTextSegment(canonicalRef: "Genesis 1:2", text: "Second", ordinal: 2),
            ],
            version: TorahTextVersionMetadata(language: "en", versionTitle: "Fixture")
        )
        #expect(TorahInspectorSourceTextResolver.text(
            in: document,
            exactReference: "Genesis 1:2"
        ) == "Second")
        #expect(TorahInspectorSourceTextResolver.text(
            in: document,
            exactReference: "Genesis 1"
        ) == "First\nSecond")
        #expect(TorahInspectorSourceTextResolver.text(
            in: document,
            exactReference: "Exodus 2:1"
        ) == nil)
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
