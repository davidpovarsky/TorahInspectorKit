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

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.repository = repository
        self.selection = selection
        self.actions = actions
    }

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        onClose: (() -> Void)? = nil,
        onInsertSegment: ((TorahSourceTransfer) -> Void)? = nil,
        onOpenInNewTab: ((TorahInspectorSelection) -> Void)? = nil
    ) {
        self.init(
            repository: repository,
            selection: selection,
            actions: TorahInspectorHostActions(
                onClose: onClose,
                onInsertSegment: onInsertSegment,
                onOpenInNewTab: onOpenInNewTab
            )
        )
    }

    public var body: some View {
        NavigationStack {
            TorahSourceReaderView(selection: selection, repository: repository, actions: actions)
                .navigationDestination(for: TorahInspectorRoute.self) { route in
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
}
