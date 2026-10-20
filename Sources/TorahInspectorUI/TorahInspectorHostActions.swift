import TorahInspectorCore

public struct TorahInspectorHostActions {
    public typealias NotesDidChange = () -> Void

    public var onClose: (() -> Void)?
    public var onInsertSegment: ((TorahSourceTransfer) -> Void)?
    public var onOpenInNewTab: ((TorahInspectorSelection) -> Void)?
    public var onAddNote: ((TorahInspectorSelection, @escaping NotesDidChange) -> Void)?
    public var onOpenNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping NotesDidChange) -> Void)?
    public var onDeleteNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping NotesDidChange) -> Void)?
    public var onOpenRelatedDocument: ((TorahRelatedDocument) -> Void)?
    public var onUnlinkRelatedDocument: ((TorahRelatedDocument, TorahInspectorSelection, @escaping NotesDidChange) -> Void)?
    public var showsCloseButton: Bool

    public init(
        onClose: (() -> Void)? = nil,
        onInsertSegment: ((TorahSourceTransfer) -> Void)? = nil,
        onOpenInNewTab: ((TorahInspectorSelection) -> Void)? = nil,
        onAddNote: ((TorahInspectorSelection, @escaping NotesDidChange) -> Void)? = nil,
        onOpenNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping NotesDidChange) -> Void)? = nil,
        onDeleteNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping NotesDidChange) -> Void)? = nil,
        onOpenRelatedDocument: ((TorahRelatedDocument) -> Void)? = nil,
        onUnlinkRelatedDocument: ((TorahRelatedDocument, TorahInspectorSelection, @escaping NotesDidChange) -> Void)? = nil,
        showsCloseButton: Bool? = nil
    ) {
        self.onClose = onClose
        self.onInsertSegment = onInsertSegment
        self.onOpenInNewTab = onOpenInNewTab
        self.onAddNote = onAddNote
        self.onOpenNote = onOpenNote
        self.onDeleteNote = onDeleteNote
        self.onOpenRelatedDocument = onOpenRelatedDocument
        self.onUnlinkRelatedDocument = onUnlinkRelatedDocument
        self.showsCloseButton = showsCloseButton ?? (onClose != nil)
    }
}
