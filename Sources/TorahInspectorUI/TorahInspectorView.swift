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
                _InspectorLinkedSourceEntry(
                    selection: nextSelection,
                    repository: repository,
                    actions: actions
                )
            }
        }
    }
}

/// A relationship tap is a drill-down inside the inspector. Loading the
/// linked document is still necessary, but presenting its full source reader
/// makes a compact inspector look and behave like a replacement reader.
private struct _InspectorLinkedSourceEntry: View {
    let selection: TorahInspectorSelection
    let repository: TorahInspectorRepository
    let actions: TorahInspectorHostActions

    @State private var segment: TorahTextSegment?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let segment {
                TorahSegmentDetailView(
                    segment: segment,
                    providerID: selection.providerID,
                    repository: repository,
                    actions: actions
                )
            } else if let errorMessage {
                ContentUnavailableView {
                    Label(TorahStrings.text("No text available"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button(TorahStrings.retry) { Task { await loadSegment() } }
                }
            } else {
                ProgressView()
            }
        }
        .task(id: selection.id) { await loadSegment() }
    }

    private func loadSegment() async {
        segment = nil
        errorMessage = nil
        do {
            let document = try await repository.document(
                for: selection.canonicalRef,
                providerID: selection.providerID
            )
            guard let resolved = TorahInspectorSegmentResolver.segment(
                in: document,
                preferredReference: selection.preferredSegmentRef ?? selection.canonicalRef
            ) else {
                throw TorahError.noText
            }
            segment = resolved
        } catch is CancellationError {
        } catch {
            errorMessage = TorahStrings.message(for: error)
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
    @State private var segment: TorahTextSegment?
    @State private var errorMessage: String?

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
            Group {
                if let segment {
                    TorahSegmentDetailView(
                        segment: segment,
                        providerID: selection.providerID,
                        repository: repository,
                        actions: actions
                    )
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label(TorahStrings.text("No text available"), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button(TorahStrings.retry) { Task { await loadSegment() } }
                    }
                } else {
                    ProgressView()
                }
            }
            .modifier(_InspectorNavigationDestinations(selection: selection, repository: repository, actions: actions))
            .task(id: selection.id) { await loadSegment() }
        }
    }

    private func loadSegment() async {
        segment = nil
        errorMessage = nil
        do {
            let document = try await repository.document(
                for: selection.canonicalRef,
                providerID: selection.providerID
            )
            guard let resolved = TorahInspectorSegmentResolver.segment(
                in: document,
                preferredReference: initialSegmentRef
            ) else {
                throw TorahError.noText
            }
            segment = resolved
        } catch is CancellationError {
        } catch {
            errorMessage = TorahStrings.message(for: error)
        }
    }
}

enum TorahInspectorSegmentResolver {
    static func segment(
        in document: TorahTextDocument,
        preferredReference: String
    ) -> TorahTextSegment? {
        document.segments.first { $0.canonicalRef == preferredReference }
            ?? document.segments.first
    }
}
