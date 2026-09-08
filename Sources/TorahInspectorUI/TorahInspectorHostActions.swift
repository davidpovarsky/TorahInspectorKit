import TorahInspectorCore

public struct TorahInspectorHostActions {
    public var onClose: (() -> Void)?
    public var onInsertSegment: ((TorahSourceTransfer) -> Void)?
    public var onOpenInNewTab: ((TorahInspectorSelection) -> Void)?

    public init(
        onClose: (() -> Void)? = nil,
        onInsertSegment: ((TorahSourceTransfer) -> Void)? = nil,
        onOpenInNewTab: ((TorahInspectorSelection) -> Void)? = nil
    ) {
        self.onClose = onClose
        self.onInsertSegment = onInsertSegment
        self.onOpenInNewTab = onOpenInNewTab
    }
}
