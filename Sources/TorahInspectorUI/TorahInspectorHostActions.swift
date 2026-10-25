import SwiftUI
import TorahInspectorCore

/// The narrow host-owned bridge used to render search inside the Inspector's
/// existing navigation stack. The Kit never imports or models host search
/// state; it only supplies navigation back into its full-source reader.
@MainActor
public struct TorahInspectorSearchCapability {
    private let destinationFactory: (TorahInspectorSearchNavigation) -> AnyView

    public init<Destination: View>(
        @ViewBuilder destination: @escaping (TorahInspectorSearchNavigation) -> Destination
    ) {
        destinationFactory = { navigation in
            AnyView(destination(navigation))
        }
    }

    func destination(navigation: TorahInspectorSearchNavigation) -> AnyView {
        destinationFactory(navigation)
    }
}

/// Navigation operations exposed to the host-owned search destination.
/// Opening a result appends to the current Inspector stack; it never changes
/// the outer sheet selection or presents another sheet.
@MainActor
public struct TorahInspectorSearchNavigation {
    private let navigate: (TorahInspectorSelection) -> Void

    init(navigate: @escaping (TorahInspectorSelection) -> Void) {
        self.navigate = navigate
    }

    public func navigateToFullSource(_ selection: TorahInspectorSelection) {
        navigate(selection)
    }
}

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
    public var search: TorahInspectorSearchCapability?
    public var showsCloseButton: Bool
    var onRequestSearch: (() -> Void)?

    public init(
        onClose: (() -> Void)? = nil,
        onInsertSegment: ((TorahSourceTransfer) -> Void)? = nil,
        onOpenInNewTab: ((TorahInspectorSelection) -> Void)? = nil,
        onAddNote: ((TorahInspectorSelection, @escaping NotesDidChange) -> Void)? = nil,
        onOpenNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping NotesDidChange) -> Void)? = nil,
        onDeleteNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping NotesDidChange) -> Void)? = nil,
        onOpenRelatedDocument: ((TorahRelatedDocument) -> Void)? = nil,
        onUnlinkRelatedDocument: ((TorahRelatedDocument, TorahInspectorSelection, @escaping NotesDidChange) -> Void)? = nil,
        search: TorahInspectorSearchCapability? = nil,
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
        self.search = search
        self.showsCloseButton = showsCloseButton ?? (onClose != nil)
    }
}

struct TorahInspectorSearchButton: View {
    let actions: TorahInspectorHostActions
    let accessibilityIdentifier: String
    @Environment(\.locale) private var locale

    var body: some View {
        Button {
            actions.onRequestSearch?()
        } label: {
            Image(systemName: "magnifyingglass")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TorahStrings.text("Search Torah sources", locale: locale))
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAction(named: Text(TorahStrings.text("Close", locale: locale))) {
            actions.onClose?()
        }
    }
}

struct TorahInspectorCloseKeyboardShortcut: View {
    let onClose: (() -> Void)?

    var body: some View {
        if let onClose {
            Button(action: onClose) {
                EmptyView()
            }
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
}
