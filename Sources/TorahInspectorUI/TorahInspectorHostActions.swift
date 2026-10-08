import TorahInspectorCore

public struct TorahInspectorHostActions {
    public typealias NotesDidChange = () -> Void

    public var onClose: (() -> Void)?
    public var onInsertSegment: ((TorahSourceTransfer) -> Void)?
    public var onOpenInNewTab: ((TorahInspectorSelection) -> Void)?
    public var onAddNote: ((TorahInspectorSelection, NotesDidChange) -> Void)?
    public var onOpenNote: ((TorahInspectorNote, TorahInspectorSelection, NotesDidChange) -> Void)?
    public var onDeleteNote: ((TorahInspectorNote, TorahInspectorSelection, NotesDidChange) -> Void)?
    public var showsCloseButton: Bool

    public init(
        onClose: (() -> Void)? = nil,
        onInsertSegment: ((TorahSourceTransfer) -> Void)? = nil,
        onOpenInNewTab: ((TorahInspectorSelection) -> Void)? = nil,
        onAddNote: ((TorahInspectorSelection, NotesDidChange) -> Void)? = nil,
        onOpenNote: ((TorahInspectorNote, TorahInspectorSelection, NotesDidChange) -> Void)? = nil,
        onDeleteNote: ((TorahInspectorNote, TorahInspectorSelection, NotesDidChange) -> Void)? = nil,
        showsCloseButton: Bool? = nil
    ) {
        self.onClose = onClose
        self.onInsertSegment = onInsertSegment
        self.onOpenInNewTab = onOpenInNewTab
        self.onAddNote = onAddNote
        self.onOpenNote = onOpenNote
        self.onDeleteNote = onDeleteNote
        self.showsCloseButton = showsCloseButton ?? (onClose != nil)
    }
}
