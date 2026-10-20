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
        #expect(actions.onOpenRelatedDocument == nil)
        #expect(actions.onUnlinkRelatedDocument == nil)
        #expect(!actions.showsCloseButton)
    }

    @Test func studyToolStringsAreLocalizedInEnglishAndHebrew() {
        #expect(TorahStudyTool.commentaries.localizedTitle(locale: Locale(identifier: "en_US")) == "Commentaries")
        #expect(TorahStudyTool.links.localizedTitle(locale: Locale(identifier: "he_IL")) == "קישורים")
        #expect(TorahStudyTool.notes.localizedTitle(locale: Locale(identifier: "he_IL")) == "הערות")
        #expect(TorahStudyToolID.relatedDocuments.localizedTitle(locale: Locale(identifier: "he_IL")) == "במסמכים")
        #expect(TorahStrings.text("Add Note", locale: Locale(identifier: "he_IL")) == "הוסף הערה")
        #expect(TorahStrings.text("Expand", locale: Locale(identifier: "he_IL")) == "הרחב")
        #expect(TorahStrings.text("Delete", locale: Locale(identifier: "he_IL")) == "מחק")
        #expect(TorahStrings.message(for: TorahError.noText, locale: Locale(identifier: "he_IL")) == "אין טקסט זמין למקור זה.")
    }

    @Test func sheetDetentsMapToNativePresentationDetents() {
        for detent in TorahInspectorSheetDetent.allCases {
            #expect(TorahInspectorSheetDetent(presentationDetent: detent.presentationDetent) == detent)
        }
    }

    @Test func physicalRightPlacementUsesEmpiricallyPhysicalTrailingEdge() {
        #expect(TorahInspectorSheetPlacementResolver.physicalRightEdge(for: .leftToRight) == .trailing)
        #expect(TorahInspectorSheetPlacementResolver.physicalRightEdge(for: .rightToLeft) == .trailing)
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
        #expect(TorahInspectorRoute.fullSource(sel1) == TorahInspectorRoute.fullSource(sel2))
    }

    @Test @MainActor func configurationKeepsLegacyAndAnytypeToolSetsDistinct() {
        #expect(TorahInspectorConfiguration.legacy.availableTools == [.commentaries, .links, .notes])
        #expect(!TorahInspectorConfiguration.legacy.allowsInlineFullSourceNavigation)
        let anytype = TorahInspectorConfiguration(
            availableTools: [.commentaries, .links, .relatedDocuments],
            allowsInlineFullSourceNavigation: true
        )
        #expect(anytype.availableTools == [.commentaries, .links, .relatedDocuments])
        #expect(!anytype.availableTools.contains(.notes))
        #expect(anytype.allowsInlineFullSourceNavigation)
    }

    @Test @MainActor func readerSessionRestoresExactCanonicalViewportAndWindow() {
        let selection = TorahInspectorSelection(
            providerID: "sefaria",
            canonicalRef: "Genesis 1",
            preferredSegmentRef: "Genesis 1:7"
        )
        let segment = TorahTextSegment(
            canonicalRef: "Genesis 1:7",
            text: "ויהי",
            ordinal: 7
        )
        let document = TorahTextDocument(
            providerID: "sefaria",
            requestedRef: "Genesis 1",
            canonicalRef: "Genesis 1",
            sectionRef: "Genesis 1",
            segments: [segment],
            version: TorahTextVersionMetadata(
                language: "he",
                versionTitle: "fixture",
                direction: "rtl"
            )
        )
        let viewport = TorahReaderViewport(
            providerID: "sefaria",
            sectionReference: "Genesis 1",
            segmentReference: "Genesis 1:7",
            relativePosition: 0.31,
            loadedSectionReferences: ["Genesis 1"]
        )
        let session = TorahReaderSessionState()

        session.save(selection: selection, sections: [document], viewport: viewport)

        let restored = session.snapshot(for: selection)
        #expect(restored?.sections.map(\.sectionRef) == ["Genesis 1"])
        #expect(restored?.viewport.segmentReference == "Genesis 1:7")
        #expect(restored?.viewport.relativePosition == 0.31)
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
        let work = TorahWorkGroup(
            id: "rashi",
            title: "Rashi",
            hebrewTitle: "רש״י",
            entries: [source]
        )
        #expect(TorahInspectorPresentation.workTitle(work, locale: Locale(identifier: "he_IL")) == "רש״י")
        #expect(TorahInspectorPresentation.workTitle(work, locale: Locale(identifier: "en_US")) == "Rashi")
        #expect(TorahInspectorPresentation.layoutDirection(for: "בראשית") == .rightToLeft)
        #expect(TorahInspectorPresentation.layoutDirection(for: "Genesis") == .leftToRight)
    }
}
