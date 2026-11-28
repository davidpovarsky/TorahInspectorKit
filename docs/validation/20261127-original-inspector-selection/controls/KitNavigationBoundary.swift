import Foundation
import TorahInspectorCore

// Explicit Linux control boundary for SwiftUI storage, text localization and
// layout. Original model/repository/lifetime/retention and extracted setters
// execute unchanged; no SwiftUI renderer, UIKit, scene or native ACK runs.
@MainActor final class ControlBox<Value> {
    var value: Value
    var willWrite: (@MainActor (Value) -> Void)?
    init(_ value: Value) { self.value = value }
}
@MainActor @propertyWrapper struct ControlState<Value> {
    let box: ControlBox<Value>
    init(wrappedValue: Value) { box = ControlBox(wrappedValue) }
    var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.willWrite?(newValue); box.value = newValue }
    }
}
@MainActor struct Binding<Value> {
    let get: @MainActor () -> Value
    let set: @MainActor (Value) -> Void
    init(get: @escaping @MainActor () -> Value, set: @escaping @MainActor (Value) -> Void) {
        self.get = get; self.set = set
    }
    var wrappedValue: Value { get { get() } nonmutating set { set(newValue) } }
}
enum TorahStrings {
    static func text(_ key: String, locale: Locale = .current) -> String { key }
}
struct TorahInspectorConfiguration { var availableTools: [TorahStudyToolID] = [.commentaries, .links, .notes] }
enum UnitPoint { case top }
@MainActor final class ScrollViewProxy {
    var calls: [TorahInspectorNavigationAnchor] = []
    var callback: (@MainActor () -> Void)?
    func scrollTo(_ anchor: TorahInspectorNavigationAnchor, anchor point: UnitPoint) {
        calls.append(anchor); callback?()
    }
}
struct ControlFailure: Error { let message: String }
func insist(_ condition: Bool, _ message: String) throws {
    guard condition else { throw ControlFailure(message: message) }
}
@MainActor func refuses(_ body: () throws -> Void) throws {
    do { try body() } catch { return }
    throw ControlFailure(message: "expected source refusal")
}

@MainActor final class KitFixture {
    let root = RootShell()
    let detail: DetailShell
    let path: PathShell
    let document = TorahDocumentLoadLifetime()
    let scroll = ScrollViewProxy()
    let focus: TorahInspectorFocus
    var request: TorahDocumentLoadLifetime.Request
    var scopeRead: (@MainActor () -> Void)?
    let source = TorahLinkedSource(sourceRef: "Commentary 1:1", category: "Commentary", type: "commentary",
        commentatorID: "author:one", workTitle: "Original work", hebrewText: "מקור", canonicalBookID: "work:one")
    init() {
        focus = .init(selection: .init(providerID: "otzaria", canonicalRef: "section:1", scope: .section),
                      displayRef: "Original section", text: "Original selected source")
        request = document.activate(selectionID: focus.selection.id)
        path = PathShell(lifetime: root.navigationLifetime)
        detail = DetailShell(focus: focus, selectedTool: root.controlBinding())
        loadAll()
    }
    func loadAll() {
        detail.controlLoad(links: [source], notes: [.init(id: "original-note", selectedText: "מקור", note: "Original note")])
    }
    func panel() -> TorahInspectorOriginalPanel {
        let capturedRequest = request
        let scope = TorahInspectorNavigationScope(lifetime: root.navigationLifetime) { [unowned self] focus in
            scopeRead?()
            return path.current.isEmpty && document.isCurrent(capturedRequest) && self.focus == focus
        }
        return detail.controlPanel(scope: scope, scroll: scroll)
    }
    func tool(_ tool: TorahStudyToolID) throws -> TorahInspectorNavigationTarget {
        try panel().currentState().targets.first { $0.anchor == .tool(tool) }.unwrap()
    }
    func row() throws -> TorahInspectorNavigationTarget {
        try panel().currentState().targets.first { if case .source = $0.anchor { return true }; return false }.unwrap()
    }
}
extension Optional {
    func unwrap() throws -> Wrapped {
        guard let value = self else { throw ControlFailure(message: "missing actual source value") }; return value
    }
}
