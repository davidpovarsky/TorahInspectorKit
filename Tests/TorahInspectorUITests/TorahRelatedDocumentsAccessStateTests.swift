import Foundation
import Testing
import TorahInspectorCore
@testable import TorahInspectorUI

@Suite("Related document access presentation")
struct TorahRelatedDocumentsAccessStateTests {
    @Test(arguments: [TorahRelatedDocumentsAccessError.denied, .invalidated])
    func permanentAccessFailureDropsPreviousRows(reason: TorahRelatedDocumentsAccessError) {
        var state = TorahPanelLoadState<[String]>.loaded(["former private row"])
        let request = state.begin(focusID: "source")
        state.fail("Could not load related documents", for: request, underlyingError: reason)
        #expect(state.value == nil)
        #expect(state.errorMessage == "Could not load related documents")
        state.publish(["late private row"], for: request)
        #expect(state.value == nil)
    }

    @Test
    func transientFailureKeepsPreviousRowsWithItsError() {
        var state = TorahPanelLoadState<[String]>.loaded(["allowed previous row"])
        let request = state.begin(focusID: "source")
        state.fail("Refresh failed", for: request, underlyingError: URLError(.notConnectedToInternet))
        #expect(state.value == ["allowed previous row"])
        #expect(state.errorMessage == "Refresh failed")
    }

    @Test
    func ownerInvalidationClearsRowsAndRejectsLatePublication() {
        var state = TorahPanelLoadState<[String]>.loaded(["former owner"])
        let request = state.begin(focusID: "source")
        state.discardPreviousValue("Access changed")
        #expect(state.value == nil)
        state.publish(["late former owner"], for: request)
        state.cancel(request)
        #expect(state.value == nil)
        #expect(state.errorMessage == "Access changed")
    }

    @Test
    func staleDenialCannotClearANewerPanelRequest() {
        var state = TorahPanelLoadState<[String]>.loaded(["previous"])
        let former = state.begin(focusID: "old")
        let current = state.begin(focusID: "new")
        state.fail("Old denial", for: former, underlyingError: TorahRelatedDocumentsAccessError.denied)
        #expect(state.value == ["previous"])
        state.publish(["current"], for: current)
        #expect(state.value == ["current"])
        #expect(state.errorMessage == nil)
    }
}
