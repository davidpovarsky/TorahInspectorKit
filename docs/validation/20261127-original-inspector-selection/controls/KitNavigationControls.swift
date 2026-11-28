import Foundation
import TorahInspectorCore

@main struct KitNavigationControls {
    @MainActor static func main() async {
        var cases: [[String: Any]] = []
        func run(_ name: String, _ body: @MainActor () throws -> Void) {
            do { try body(); cases.append(["name": name, "pass": true]) }
            catch { cases.append(["name": name, "pass": false, "error": String(describing: error)]) }
        }
        run("actual original catalog exposes exactly three configured tools and full loaded values") {
            let f = KitFixture(), state = try f.panel().currentState()
            let tools = state.targets.filter { if case .tool = $0.anchor { return true }; return false }
            try insist(tools.count == 3 && !tools.contains { $0.tool == .relatedDocuments }, "finite original tools")
            let row = try f.row()
            try insist(row.source == f.source && row.group?.entries == [f.source], "full original payload joins")
        }
        run("actual original selected-tool setter commits once without scroll or receipt") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes))
            let before = f.root.navigationLifetime.revision.tool
            let result = try op.reveal(layoutRevision: 1, validateExternal: {})
            try insist(result == .awaitingOriginalWitness && op.originalToolWriteCommitted, "setter is not ACK")
            try insist(f.root.controlBinding().wrappedValue == .notes
                && f.root.navigationLifetime.revision.tool == before! + 1 && f.scroll.calls.isEmpty, "one original tool write")
            try insist(try op.isReadyForOriginalWitness(), "actual loaded tool can now seek independent witness")
        }
        run("already selected tool uses zero equal publications") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.commentaries))
            _ = try op.reveal(layoutRevision: 0, validateExternal: {})
            try insist(f.root.navigationLifetime.revision.tool == 0 && !op.originalToolWriteCommitted, "zero redundant write")
        }
        run("original pending content remains pending after a committed tool selection") {
            let f = KitFixture(); f.detail.controlPendingNotes()
            let op = try f.panel().retain(f.tool(.notes))
            try insist(try op.reveal(layoutRevision: 0, validateExternal: {}) == .awaitingOriginalContent,
                       "loading is not accepted as selected ready content")
            try insist(try !op.isReadyForOriginalWitness(), "no ready witness during original load")
            f.detail.controlCompleteNotes([])
            try insist(try op.reveal(layoutRevision: 1, validateExternal: {}) == .awaitingOriginalWitness,
                       "same original tool load may finish")
            try insist(f.root.navigationLifetime.revision.tool == 1, "load completion did not replay tool setter")
        }
        run("original path A-search-A invalidates retained tool before effect") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes))
            f.path.change([.search]); f.path.change([])
            try refuses { _ = try op.reveal(layoutRevision: 0, validateExternal: {}) }
            try insist(f.root.controlBinding().wrappedValue == .commentaries && f.scroll.calls.isEmpty, "zero effect")
        }
        run("original equal selected-tool publication invalidates retained source") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes))
            f.root.controlBinding().wrappedValue = .commentaries
            try refuses { _ = try op.reveal(layoutRevision: 0, validateExternal: {}) }
        }
        run("original selected-tool A-B-A cannot renew a retained source") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes))
            f.root.controlBinding().wrappedValue = .links; f.root.controlBinding().wrappedValue = .commentaries
            try refuses { _ = try op.reveal(layoutRevision: 0, validateExternal: {}) }
        }
        run("original Disclosure expansion waits for strictly newer real layout") {
            let f = KitFixture(), row = try f.row(), op = try f.panel().retain(row)
            try insist(try op.reveal(layoutRevision: 7, validateExternal: {}) == .awaitingOriginalLayout, "wait original layout")
            try insist(f.detail.expanded.contains(row.group!.id) && f.scroll.calls.isEmpty, "one original disclosure only")
            _ = try op.reveal(layoutRevision: 7, validateExternal: {})
            _ = try op.reveal(layoutRevision: 6, validateExternal: {})
            try insist(f.scroll.calls.isEmpty, "same/older publication is not layout progress")
            _ = try op.reveal(layoutRevision: 8, validateExternal: {})
            _ = try op.reveal(layoutRevision: 9, validateExternal: {})
            try insist(f.scroll.calls == [row.anchor], "exact original private row scrolled once")
        }
        run("already expanded original row scrolls without extra disclosure write") {
            let f = KitFixture(), row = try f.row(); f.detail.controlExpand(row.group!.id, true)
            let before = f.detail.navigationLifetime.revision.expansion
            let op = try f.panel().retain(row); _ = try op.reveal(layoutRevision: 1, validateExternal: {})
            try insist(f.detail.navigationLifetime.revision.expansion == before && f.scroll.calls == [row.anchor], "no redundant expansion")
        }
        run("original Disclosure A-B-A revokes retained row") {
            let f = KitFixture(), row = try f.row(), op = try f.panel().retain(row)
            f.detail.controlExpand(row.group!.id, true); f.detail.controlExpand(row.group!.id, false)
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
            try insist(f.scroll.calls.isEmpty, "no late scroll")
        }
        run("original reload of identical payload still retires row history") {
            let f = KitFixture(), row = try f.row(), op = try f.panel().retain(row)
            f.detail.controlReloadLinks([f.source])
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
        }
        run("original document request replacement for same selection cannot revive scope") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes))
            _ = f.document.activate(selectionID: f.focus.selection.id)
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
            try insist(f.root.controlBinding().wrappedValue == .commentaries, "same selection is not same request")
        }
        run("original document invalidate retires current panel") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes)); f.document.invalidate()
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
        }
        run("external cancellation before reveal makes zero original calls") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes))
            try refuses { _ = try op.reveal(layoutRevision: 1) { throw CancellationError() } }
            try insist(f.root.navigationLifetime.revision.tool == 0 && f.scroll.calls.isEmpty, "cancel before effect")
        }
        run("revoked original admission before layout prevents delayed scroll") {
            let f = KitFixture(), op = try f.panel().retain(f.row())
            _ = try op.reveal(layoutRevision: 1, validateExternal: {})
            try refuses { _ = try op.reveal(layoutRevision: 2) { throw ControlFailure(message: "original deadline") } }
            try insist(f.scroll.calls.isEmpty, "no later mutation after expiry")
        }
        run("nested reveal during original admission cannot claim or repeat effect") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes)); var nested = false
            do {
                _ = try op.reveal(layoutRevision: 1) {
                    do { _ = try op.reveal(layoutRevision: 1, validateExternal: {}); nested = true } catch {}
                }
            } catch {}
            try insist(!nested && f.root.navigationLifetime.revision.tool == 0, "nested call refuses and retires")
        }
        run("release during external admission is terminal before setter") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes))
            try refuses { _ = try op.reveal(layoutRevision: 1) { op.retire() } }
            try refuses { _ = try op.reveal(layoutRevision: 2, validateExternal: {}) }
            try insist(f.root.navigationLifetime.revision.tool == 0, "no setter after release")
        }
        run("release inside original tool setter preserves possible effect but refuses completion") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes))
            f.root.external.box.willWrite = { _ in op.retire() }
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
            try insist(f.root.external.box.value == .notes && f.root.navigationLifetime.revision.tool == 1,
                       "actual original committed effect is not rolled back or called success")
            try insist(try !op.isReadyForOriginalWitness(), "retired source has no witness ACK")
        }
        run("extra equal original tool write inside setter is not the permitted plus-one") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes)); var entered = false
            f.root.external.box.willWrite = { _ in
                if !entered { entered = true; f.root.controlBinding().wrappedValue = .commentaries }
            }
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
            try insist(f.root.navigationLifetime.revision.tool == 2, "two publications remain distinguishable")
        }
        run("release inside actual scroll preserves one effect but no completion") {
            let f = KitFixture(), row = try f.row(); f.detail.controlExpand(row.group!.id, true)
            let op = try f.panel().retain(row); f.scroll.callback = { op.retire() }
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
            try insist(f.scroll.calls == [row.anchor], "possible original scroll remains recorded")
            try insist(try !op.isReadyForOriginalWitness(), "no acknowledgement after revoked scroll")
        }
        run("source callback path publication is rechecked before setter") {
            let f = KitFixture(), op = try f.panel().retain(f.tool(.notes)); var called = false
            f.scopeRead = { if !called { called = true; f.path.change([.search]); f.path.change([]) } }
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
            try insist(f.root.navigationLifetime.revision.tool == 0, "changed source inside getter cannot pass")
        }
        run("catalog keeps same loaded rows across disclosure but row operation retains its own expansion") {
            let f = KitFixture(), row = try f.row(), catalog = try f.panel().retainCatalog(), op = try f.panel().retain(row)
            f.detail.controlExpand(row.group!.id, true)
            try catalog.validate()
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
            try insist(catalog.targets.contains(row), "catalog metadata is not renewed execution authority")
        }
        run("catalog cannot revive after path ABA") {
            let f = KitFixture(), catalog = try f.panel().retainCatalog()
            f.path.change([.search]); f.path.change([])
            try refuses { try catalog.validate() }; try refuses { try catalog.validate() }
        }
        run("catalog rejects identical-data original reload") {
            let f = KitFixture(), catalog = try f.panel().retainCatalog()
            f.detail.controlReloadLinks([f.source]); try refuses { try catalog.validate() }
        }
        run("duplicate original note anchors refuse unambiguous retention") {
            let f = KitFixture(); f.root.controlBinding().wrappedValue = .notes
            f.detail.controlCompleteNotes([.init(id: "duplicate", selectedText: "one", note: "First"),
                                           .init(id: "duplicate", selectedText: "two", note: "Second")])
            let panel = f.panel(), row = try panel.currentState().targets.first { if case .note = $0.anchor { return true }; return false }.unwrap()
            try refuses { _ = try panel.retain(row) }
        }
        run("nullable publication overflow is permanent") {
            var value: UInt64? = .max
            TorahInspectorNavigationLifetime.advance(&value)
            try insist(value == nil, "overflow fails closed")
            TorahInspectorNavigationLifetime.advance(&value)
            try insist(value == nil, "no counter reset")
        }
        run("unsupported original configured tool is not publicly manufactured") {
            let f = KitFixture(); f.detail.controlConfigure([.relatedDocuments])
            let targets = try f.panel().currentState().targets
            try insist(!targets.contains { $0.tool == .relatedDocuments }
                && !targets.contains { if case .tool = $0.anchor { return true }; return false },
                "unreviewed original tool has no manufactured tool target")
        }
        run("changed note payload with same numeric identity is refused") {
            let f = KitFixture(); f.root.controlBinding().wrappedValue = .notes
            let panel = f.panel(), target = try panel.currentState().targets.first { if case .note = $0.anchor { return true }; return false }.unwrap()
            let op = try panel.retain(target)
            f.detail.controlCompleteNotes([.init(id: "original-note", selectedText: "מקור", note: "Changed note")])
            try refuses { _ = try op.reveal(layoutRevision: 1, validateExternal: {}) }
        }
        let failed = cases.filter { ($0["pass"] as? Bool) != true }.count
        let report: [String: Any] = ["scope": "Actual Kit Core module, unchanged document/load state, complete navigation retention/catalog bodies, and verbatim original tool/path/disclosure/catalog/scroll-proxy methods. Explicit SwiftUI storage/localization/layout boundary. No native/SDK/geometry/ACK.",
            "cases": cases, "passed": cases.count - failed, "failed": failed, "nativeRuns": 0, "AppleSDK": "NOT_RUN"]
        print(String(decoding: try! JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        if failed != 0 { exit(1) }
    }
}
