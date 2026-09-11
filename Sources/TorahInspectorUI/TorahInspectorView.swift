import Observation
import SwiftUI
import TorahInspectorCore

@MainActor @Observable
public final class TorahInspectorModel {
    public private(set) var selection: TorahInspectorSelection
    public let repository: TorahInspectorRepository

    public init(repository: TorahInspectorRepository, selection: TorahInspectorSelection) {
        self.selection = selection
        self.repository = repository
    }
}

public struct TorahInspectorView: View {
    private let selection: TorahInspectorSelection
    private let repository: TorahInspectorRepository
    private let actions: TorahInspectorHostActions
    private let entryMode: TorahInspectorEntryMode

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.repository = repository
        self.selection = selection
        self.entryMode = entryMode
        self.actions = actions
    }

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        onClose: (() -> Void)? = nil,
        onInsertSegment: ((TorahSourceTransfer) -> Void)? = nil,
        onOpenInNewTab: ((TorahInspectorSelection) -> Void)? = nil
    ) {
        self.init(
            repository: repository,
            selection: selection,
            entryMode: entryMode,
            actions: TorahInspectorHostActions(
                onClose: onClose,
                onInsertSegment: onInsertSegment,
                onOpenInNewTab: onOpenInNewTab
            )
        )
    }

    public var body: some View {
        switch entryMode {
        case .sourceReader:
            _InspectorSourceReaderEntry(
                selection: selection,
                repository: repository,
                actions: actions
            )
        case .segmentRelationships:
            if let segRef = selection.preferredSegmentRef {
                _InspectorSegmentRelationshipsEntry(
                    selection: selection,
                    initialSegmentRef: segRef,
                    repository: repository,
                    actions: actions
                )
            } else {
                _InspectorSourceReaderEntry(
                    selection: selection,
                    repository: repository,
                    actions: actions
                )
            }
        }
    }
}

// MARK: - Internal entry-point views

/// Shared navigationDestination builder (extracted to avoid duplication).
private struct _InspectorNavigationDestinations: ViewModifier {
    let selection: TorahInspectorSelection
    let repository: TorahInspectorRepository
    let actions: TorahInspectorHostActions

    func body(content: Content) -> some View {
        content.navigationDestination(for: TorahInspectorRoute.self) { route in
            switch route {
            case .segment(let segment):
                TorahSegmentDetailView(
                    segment: segment,
                    providerID: selection.providerID,
                    repository: repository,
                    actions: actions
                )
            case .source(let nextSelection):
                TorahSourceReaderView(selection: nextSelection, repository: repository, actions: actions)
            }
        }
    }
}

/// Entry at the scrollable source-reader (default behaviour).
private struct _InspectorSourceReaderEntry: View {
    let selection: TorahInspectorSelection
    let repository: TorahInspectorRepository
    let actions: TorahInspectorHostActions

    var body: some View {
        NavigationStack {
            TorahSourceReaderView(selection: selection, repository: repository, actions: actions)
                .modifier(_InspectorNavigationDestinations(selection: selection, repository: repository, actions: actions))
        }
    }
}

/// Entry directly at the segment relationships view.
/// The root of the NavigationStack is the segment detail (relationships),
/// so the user sees relationships immediately without a source reader flash.
/// Tapping a related source pushes within the same stack.
private struct _InspectorSegmentRelationshipsEntry: View {
    let selection: TorahInspectorSelection
    let initialSegmentRef: String
    let repository: TorahInspectorRepository
    let actions: TorahInspectorHostActions

    /// Synthesise a lightweight segment stub for the root view.
    /// The real relationship content is fetched lazily inside TorahSegmentDetailView.
    private var initialSegment: TorahTextSegment {
        TorahTextSegment(canonicalRef: initialSegmentRef, hebrewRef: initialSegmentRef, text: "", ordinal: 0)
    }

    init(
        selection: TorahInspectorSelection,
        initialSegmentRef: String,
        repository: TorahInspectorRepository,
        actions: TorahInspectorHostActions
    ) {
        self.selection = selection
        self.initialSegmentRef = initialSegmentRef
        self.repository = repository
        self.actions = actions
    }

    var body: some View {
        NavigationStack {
            TorahSegmentDetailView(
                segment: initialSegment,
                providerID: selection.providerID,
                repository: repository,
                actions: actions
            )
            .modifier(_InspectorNavigationDestinations(selection: selection, repository: repository, actions: actions))
        }
    }
}
