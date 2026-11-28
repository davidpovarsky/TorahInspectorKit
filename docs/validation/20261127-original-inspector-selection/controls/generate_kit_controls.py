from pathlib import Path
import hashlib, json, shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'controls' / 'generated'
OUT.mkdir(exist_ok=True)
records = []

def sha(b): return hashlib.sha256(b).hexdigest()
def source(name):
    p = ROOT / 'candidate' / 'Sources' / 'TorahInspectorUI' / name
    return p, p.read_text()

def block(name, marker, occurrence=0):
    p, s = source(name)
    starts = []
    index = 0
    while (index := s.find(marker, index)) != -1:
        starts.append(index); index += len(marker)
    start = starts[occurrence]
    opening = s.index('{', start)
    depth = 0
    for index in range(opening, len(s)):
        if s[index] == '{': depth += 1
        elif s[index] == '}':
            depth -= 1
            if depth == 0: break
    assert depth == 0
    value = s[start:index+1]
    records.append({'file': str(p.relative_to(ROOT)), 'wholeSHA256': sha(p.read_bytes()),
                    'marker': marker, 'occurrence': occurrence, 'startByte': len(s[:start].encode()),
                    'bytes': len(value.encode()), 'sha256': sha(value.encode()), 'transformation': 'none'})
    return value

p, contract = source('TorahInspectorNavigationSurface.swift')
prefix = contract.split('/// Optional passive view hooks.')[0]
assert prefix.count('import SwiftUI\n') == 1
(OUT/'OriginalNavigationSurface.swift').write_text(prefix.replace('import SwiftUI\n', ''))
records.append({'file': str(p.relative_to(ROOT)), 'wholeSHA256': sha(p.read_bytes()),
    'prefixBytes': len(prefix.encode()), 'prefixSHA256': sha(prefix.encode()),
    'transformation': 'retain complete original navigation model/lifetime/catalog/retention prefix; remove one unavailable SwiftUI import only; passive view/environment hooks outside this component control'})

route = '\n\n'.join(block('TorahInspectorRoute.swift', x) for x in [
    'public enum TorahInspectorRoute:', 'public struct TorahStudyToolID:', 'public enum TorahStudyTool:'])
(OUT/'OriginalRouteTypes.swift').write_text('import Foundation\nimport TorahInspectorCore\n\n'+route+'\n')
for name in ['TorahDocumentLoadLifetime.swift','TorahPanelLoadState.swift']:
    p = ROOT/'base26/Sources/TorahInspectorUI'/name
    shutil.copyfile(p, OUT/name)
    records.append({'file': str(p.relative_to(ROOT)), 'wholeSHA256': sha(p.read_bytes()), 'transformation':'none: complete original file'})

root = '''@MainActor struct RootShell {
    let navigationLifetime = TorahInspectorNavigationLifetime()
    let external = ControlState<TorahStudyToolID>(wrappedValue: .commentaries)
    @ControlState var localSelectedToolID: TorahStudyToolID = .commentaries
    var externalSelectedToolID: Binding<TorahStudyToolID>? {
        Binding(get: { external.wrappedValue }, set: { external.wrappedValue = $0 })
    }
    var externalSelectedTool: Binding<TorahStudyTool>? { nil }
    func controlBinding() -> Binding<TorahStudyToolID> { selectedToolBinding }
'''+block('TorahInspectorView.swift','private var selectedToolBinding:')+'\n}\n'
path = '''@MainActor struct PathShell {
    let navigationLifetime: TorahInspectorNavigationLifetime?
    @ControlState var path: [TorahInspectorRoute] = []
    init(lifetime: TorahInspectorNavigationLifetime) { navigationLifetime = lifetime }
    var current: [TorahInspectorRoute] { path }
    func change(_ value: [TorahInspectorRoute]) { originalNavigationPath.wrappedValue = value }
'''+block('TorahInspectorView.swift','private var originalNavigationPath:',0)+'\n}\n'
detail = '''@MainActor struct DetailShell {
    let focus: TorahInspectorFocus
    let repository = TorahInspectorRepository(textFetcher: { _, _ in throw ControlFailure(message: "unused original text fetch") })
    let navigationLifetime = TorahInspectorNavigationLifetime()
    let originalToolBinding: Binding<TorahStudyToolID>
    let locale = Locale(identifier: "en")
    @ControlState var configuration = TorahInspectorConfiguration()
    @ControlState var linksState = TorahPanelLoadState<TorahLinksSnapshot>.idle
    @ControlState var topicsState = TorahPanelLoadState<[TorahLinkedTopic]>.idle
    @ControlState var notesState = TorahPanelLoadState<[TorahInspectorNote]>.idle
    @ControlState var loadedFocusID: String? = nil
    @ControlState var expandedCommentaryGroupIDs = Set<String>()
    @ControlState var expandedSourceIDs = Set<String>()
    var selectedTool: TorahStudyToolID {
        get { originalToolBinding.wrappedValue }
        nonmutating set { originalToolBinding.wrappedValue = newValue }
    }
    init(focus: TorahInspectorFocus, selectedTool: Binding<TorahStudyToolID>) {
        self.focus = focus; originalToolBinding = selectedTool
    }
    // Explicit localization-only boundary; the actual values/IDs and catalog
    // selection branch below are retained from the original view.
    func commentaryGroupTitle(_ group: TorahSourceGroup) -> String { group.title }
    func displayReference(_ source: TorahLinkedSource) -> String { source.sourceRef }
    var expanded: Set<String> { expandedCommentaryGroupIDs }
    func controlConfigure(_ tools: [TorahStudyToolID]) { configuration.availableTools = tools }
    func controlExpand(_ id: String, _ value: Bool) { originalGroupExpansion(id).wrappedValue = value }
    func controlPanel(scope: TorahInspectorNavigationScope, scroll: ScrollViewProxy) -> TorahInspectorOriginalPanel {
        originalNavigationPanel(scope: scope, scroll: scroll)
    }
    func controlLoad(links: [TorahLinkedSource], notes: [TorahInspectorNote]) {
        loadedFocusID = focus.id
        controlReloadLinks(links)
        navigationLifetime.contentWillChange()
        let request = topicsState.begin(focusID: focus.id)
        originalContentWillPublish(topicsState, request: request)
        topicsState.publish([], for: request)
        controlPendingNotes(); controlCompleteNotes(notes)
    }
    func controlReloadLinks(_ links: [TorahLinkedSource]) {
        navigationLifetime.contentWillChange()
        let request = linksState.begin(focusID: focus.id)
        let snapshot = TorahLinksSnapshot(sources: links, groups: TorahRelationshipGroups(sources: links))
        originalContentWillPublish(linksState, request: request)
        linksState.publish(snapshot, for: request)
    }
    func controlPendingNotes() {
        navigationLifetime.contentWillChange()
        _ = notesState.begin(focusID: focus.id)
    }
    func controlCompleteNotes(_ notes: [TorahInspectorNote]) {
        if case .loading = notesState {} else { controlPendingNotes() }
        guard case .loading(let request, _) = notesState else { fatalError("fixture load must exist") }
        originalContentWillPublish(notesState, request: request)
        notesState.publish(notes, for: request)
    }
'''
for marker in ['private var groups:', 'private var notes:', 'private func originalGroupExpansion(',
               'private func originalContentWillPublish<', 'private var originalNavigationState:',
               'private func originalNavigationPanel(']:
    detail += block('TorahSegmentDetailView.swift',marker)+'\n\n'
detail += '}\n'
(OUT/'OriginalViewMethodShells.swift').write_text('import Foundation\nimport TorahInspectorCore\n\n'+root+path+detail)
for name in ['KitNavigationBoundary.swift','KitNavigationControls.swift']:
    p=ROOT/'controls'/name; shutil.copyfile(p,OUT/name)
    records.append({'file':str(p.relative_to(ROOT)),'wholeSHA256':sha(p.read_bytes()),'transformation':'explicit control boundary / stimuli, not production'})
report={'scope':'Verbatim complete navigation retention/catalog; exact original view setter/state/panel methods and original document/load state; SwiftUI storage/localization/layout boundary. No Apple SDK, UIKit, native app, receipt ACK, database or network qualification.',
        'extractions':records,'generated':[{ 'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()) } for p in sorted(OUT.glob('*.swift'))]}
(OUT/'SOURCE_EXTRACTION.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'generated':len(report['generated']),'sourceBlocks':len(records),'bytes':sum(x['bytes'] for x in report['generated'])}))
