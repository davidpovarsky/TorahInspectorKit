import Testing
@testable import TorahInspectorUI

@Suite("Optional host actions")
struct TorahInspectorHostActionsTests {
    @Test func defaultsDoNotRequireAnyAppCallbacks() {
        let actions = TorahInspectorHostActions()
        #expect(actions.onClose == nil)
        #expect(actions.onInsertSegment == nil)
        #expect(actions.onOpenInNewTab == nil)
    }
}
