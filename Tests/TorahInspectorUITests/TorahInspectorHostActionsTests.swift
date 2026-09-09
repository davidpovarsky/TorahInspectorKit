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
}
