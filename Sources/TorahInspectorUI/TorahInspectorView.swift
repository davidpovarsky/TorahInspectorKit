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
    private let chrome: TorahInspectorChrome
    private let configuration: TorahInspectorConfiguration
    private let externalSelectedTool: Binding<TorahStudyTool>?
    private let externalSelectedToolID: Binding<TorahStudyToolID>?
    @State private var localSelectedToolID: TorahStudyToolID = .commentaries
    @State private var readerSession = TorahReaderSessionState()

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        chrome: TorahInspectorChrome = .floatingPanel,
        selectedTool: Binding<TorahStudyTool>? = nil,
        configuration: TorahInspectorConfiguration = .legacy,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.repository = repository
        self.selection = selection
        self.entryMode = entryMode
        self.chrome = chrome
        self.configuration = configuration
        self.externalSelectedTool = selectedTool
        self.externalSelectedToolID = nil
        self.actions = actions
    }

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        chrome: TorahInspectorChrome = .floatingPanel,
        selectedTool: Binding<TorahStudyToolID>,
        configuration: TorahInspectorConfiguration,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.repository = repository
        self.selection = selection
        self.entryMode = entryMode
        self.chrome = chrome
        self.configuration = configuration
        self.externalSelectedTool = nil
        self.externalSelectedToolID = selectedTool
        self.actions = actions
    }

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        chrome: TorahInspectorChrome = .floatingPanel,
        selectedTool: Binding<TorahStudyTool>? = nil,
        configuration: TorahInspectorConfiguration = .legacy,
        onClose: (() -> Void)? = nil,
        onInsertSegment: ((TorahSourceTransfer) -> Void)? = nil,
        onOpenInNewTab: ((TorahInspectorSelection) -> Void)? = nil,
        onAddNote: ((TorahInspectorSelection, @escaping TorahInspectorHostActions.NotesDidChange) -> Void)? = nil,
        onOpenNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping TorahInspectorHostActions.NotesDidChange) -> Void)? = nil,
        onDeleteNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping TorahInspectorHostActions.NotesDidChange) -> Void)? = nil,
        showsCloseButton: Bool? = nil
    ) {
        self.init(
            repository: repository,
            selection: selection,
            entryMode: entryMode,
            chrome: chrome,
            selectedTool: selectedTool,
            configuration: configuration,
            actions: TorahInspectorHostActions(
                onClose: onClose,
                onInsertSegment: onInsertSegment,
                onOpenInNewTab: onOpenInNewTab,
                onAddNote: onAddNote,
                onOpenNote: onOpenNote,
                onDeleteNote: onDeleteNote,
                showsCloseButton: showsCloseButton
            )
        )
    }

    public var body: some View {
        switch entryMode {
        case .sourceReader:
            _InspectorSourceReaderEntry(
                selection: selection,
                repository: repository,
                selectedTool: selectedToolBinding,
                chrome: chrome,
                configuration: configuration,
                readerSession: readerSession,
                actions: actions
            )
        case .relationships, .segmentRelationships:
            _InspectorRelationshipsEntry(
                selection: selection,
                repository: repository,
                selectedTool: selectedToolBinding,
                chrome: chrome,
                configuration: configuration,
                readerSession: readerSession,
                actions: actions
            )
        }
    }

    private var selectedToolBinding: Binding<TorahStudyToolID> {
        Binding(
            get: {
                externalSelectedToolID?.wrappedValue
                    ?? externalSelectedTool?.wrappedValue.toolID
                    ?? localSelectedToolID
            },
            set: { newValue in
                if let externalSelectedToolID {
                    externalSelectedToolID.wrappedValue = newValue
                } else if let externalSelectedTool,
                          let legacy = TorahStudyTool(rawValue: newValue.rawValue) {
                    externalSelectedTool.wrappedValue = legacy
                } else {
                    localSelectedToolID = newValue
                }
            }
        )
    }
}

// MARK: - Internal entry-point views

/// Shared navigationDestination builder (extracted to avoid duplication).
private struct _InspectorNavigationDestinations: ViewModifier {
    let selection: TorahInspectorSelection
    let repository: TorahInspectorRepository
    @Binding var selectedTool: TorahStudyToolID
    let chrome: TorahInspectorChrome
    let configuration: TorahInspectorConfiguration
    let readerSession: TorahReaderSessionState
    let actions: TorahInspectorHostActions

    func body(content: Content) -> some View {
        content.navigationDestination(for: TorahInspectorRoute.self) { route in
            switch route {
            case .segment(let segment):
                TorahSegmentDetailView(
                    focus: TorahInspectorFocus(
                        segment: segment,
                        providerID: selection.providerID,
                        sectionRef: selection.canonicalRef
                    ),
                    repository: repository,
                    selectedTool: $selectedTool,
                    chrome: chrome,
                    configuration: configuration,
                    actions: actions
                )
            case .source(let nextSelection):
                _InspectorLinkedSourceEntry(
                    selection: nextSelection,
                    repository: repository,
                    selectedTool: $selectedTool,
                    chrome: chrome,
                    configuration: configuration,
                    actions: actions
                )
            case .fullSource(let nextSelection):
                TorahSourceReaderView(
                    selection: nextSelection,
                    repository: repository,
                    actions: actions,
                    session: readerSession,
                    theme: configuration.theme
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
    @Binding var selectedTool: TorahStudyToolID
    let chrome: TorahInspectorChrome
    let configuration: TorahInspectorConfiguration
    let actions: TorahInspectorHostActions

    @State private var segment: TorahTextSegment?
    @State private var errorMessage: String?
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if let segment {
                TorahSegmentDetailView(
                    focus: TorahInspectorFocus(
                        segment: segment,
                        providerID: selection.providerID,
                        sectionRef: selection.canonicalRef
                    ),
                    repository: repository,
                    selectedTool: $selectedTool,
                    chrome: chrome,
                    configuration: configuration,
                    actions: actions
                )
            } else if let errorMessage {
                ContentUnavailableView {
                    Label(TorahStrings.text("No text available", locale: locale), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button(TorahStrings.text("Retry", locale: locale)) { Task { await loadSegment() } }
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
            errorMessage = TorahStrings.message(for: error, locale: locale)
        }
    }
}

/// Entry at the scrollable source-reader (default behaviour).
private struct _InspectorSourceReaderEntry: View {
    let selection: TorahInspectorSelection
    let repository: TorahInspectorRepository
    @Binding var selectedTool: TorahStudyToolID
    let chrome: TorahInspectorChrome
    let configuration: TorahInspectorConfiguration
    let readerSession: TorahReaderSessionState
    let actions: TorahInspectorHostActions
    @State private var path: [TorahInspectorRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            TorahSourceReaderView(
                selection: selection,
                repository: repository,
                actions: actions,
                session: readerSession,
                theme: configuration.theme
            )
                .modifier(_InspectorNavigationDestinations(
                    selection: selection,
                    repository: repository,
                    selectedTool: $selectedTool,
                    chrome: chrome,
                    configuration: configuration,
                    readerSession: readerSession,
                    actions: actions
                ))
        }
    }
}

/// Entry directly at the segment relationships view.
/// The root of the NavigationStack is the segment detail (relationships),
/// so the user sees relationships immediately without a source reader flash.
/// Tapping a related source pushes within the same stack.
private struct _InspectorRelationshipsEntry: View {
    let selection: TorahInspectorSelection
    let repository: TorahInspectorRepository
    @Binding var selectedTool: TorahStudyToolID
    let chrome: TorahInspectorChrome
    let configuration: TorahInspectorConfiguration
    let readerSession: TorahReaderSessionState
    let actions: TorahInspectorHostActions
    @State private var path: [TorahInspectorRoute] = []
    @State private var focus: TorahInspectorFocus?
    @State private var errorMessage: String?
    @Environment(\.locale) private var locale

    init(
        selection: TorahInspectorSelection,
        repository: TorahInspectorRepository,
        selectedTool: Binding<TorahStudyToolID>,
        chrome: TorahInspectorChrome,
        configuration: TorahInspectorConfiguration,
        readerSession: TorahReaderSessionState,
        actions: TorahInspectorHostActions
    ) {
        self.selection = selection
        self.repository = repository
        self._selectedTool = selectedTool
        self.chrome = chrome
        self.configuration = configuration
        self.readerSession = readerSession
        self.actions = actions
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let focus {
                    TorahSegmentDetailView(
                        focus: focus,
                        repository: repository,
                        selectedTool: $selectedTool,
                        chrome: chrome,
                        configuration: configuration,
                        actions: actions
                    )
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label(TorahStrings.text("No text available", locale: locale), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button(TorahStrings.text("Retry", locale: locale)) { Task { await loadSegment() } }
                    }
                } else {
                    ProgressView()
                }
            }
            .modifier(_InspectorNavigationDestinations(
                selection: selection,
                repository: repository,
                selectedTool: $selectedTool,
                chrome: chrome,
                configuration: configuration,
                readerSession: readerSession,
                actions: actions
            ))
            .task(id: selection.id) { await loadSegment() }
            .toolbar {
                if TorahInspectorNavigationChrome.showsFullSourceButton(
                    pathIsEmpty: path.isEmpty,
                    hasFocus: focus != nil,
                    allowsInlineFullSourceNavigation: configuration.allowsInlineFullSourceNavigation
                ) {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            path.append(.fullSource(selection))
                        } label: {
                            Image(systemName: "book.closed")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(TorahStrings.text("Open full source", locale: locale))
                        .accessibilityIdentifier("torah-inspector-open-full-source")
                    }
                }
            }
        }
    }

    private func loadSegment() async {
        focus = nil
        errorMessage = nil
        do {
            let document = try await repository.document(
                for: selection.canonicalRef,
                providerID: selection.providerID
            )
            switch selection.scope {
            case .segment:
                guard let preferred = selection.preferredSegmentRef,
                      let resolved = TorahInspectorSegmentResolver.segment(
                        in: document,
                        preferredReference: preferred
                      ) else {
                    throw TorahError.noText
                }
                focus = TorahInspectorFocus(
                    segment: resolved,
                    providerID: selection.providerID,
                    sectionRef: selection.canonicalRef
                )
            case .section:
                focus = TorahInspectorFocus(
                    selection: selection,
                    displayRef: document.sectionRef,
                    hebrewDisplayRef: document.hebrewSectionRef,
                    text: document.segments.map(\.text).joined(separator: "\n")
                )
            }
        } catch is CancellationError {
        } catch {
            errorMessage = TorahStrings.message(for: error, locale: locale)
        }
    }
}

enum TorahInspectorNavigationChrome {
    static func showsFullSourceButton(
        pathIsEmpty: Bool,
        hasFocus: Bool,
        allowsInlineFullSourceNavigation: Bool
    ) -> Bool {
        pathIsEmpty && hasFocus && allowsInlineFullSourceNavigation
    }
}

enum TorahInspectorSegmentResolver {
    static func segment(
        in document: TorahTextDocument,
        preferredReference: String
    ) -> TorahTextSegment? {
        document.segments.first { $0.canonicalRef == preferredReference }
    }
}
