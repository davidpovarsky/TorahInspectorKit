import Observation
import TorahInspectorCore

@MainActor @Observable
public final class TorahReaderSessionState {
    struct Snapshot {
        let sections: [TorahTextDocument]
        let viewport: TorahReaderViewport
    }

    private var snapshots: [String: Snapshot] = [:]

    public init() {}

    func snapshot(for selection: TorahInspectorSelection) -> Snapshot? {
        snapshots[selection.id]
    }

    func save(
        selection: TorahInspectorSelection,
        sections: [TorahTextDocument],
        viewport: TorahReaderViewport
    ) {
        snapshots[selection.id] = Snapshot(sections: sections, viewport: viewport)
    }
}
