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
    private let presentationOptions: TorahInspectorPresentationOptions
    private let usesLegacyDetailLayout: Bool
    private let externalSelectedTool: Binding<TorahStudyTool>?
    private let externalSelectedToolID: Binding<TorahStudyToolID>?
    private let pendingSearchRequest: Binding<Bool>?
    private let onSearchPresentationChanged: (Bool) -> Void
    @State private var localSelectedToolID: TorahStudyToolID = .commentaries
    @State private var readerSession = TorahReaderSessionState()
    @State private var navigationLifetime = TorahInspectorNavigationLifetime()

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        chrome: TorahInspectorChrome = .floatingPanel,
        selectedTool: Binding<TorahStudyTool>? = nil,
        presentationOptions: TorahInspectorPresentationOptions = .init(),
        configuration: TorahInspectorConfiguration = .legacy,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.repository = repository
        self.selection = selection
        self.entryMode = entryMode
        self.chrome = chrome
        self.configuration = configuration
        self.presentationOptions = presentationOptions
        self.externalSelectedTool = selectedTool
        self.usesLegacyDetailLayout = true
        self.externalSelectedToolID = nil
        self.pendingSearchRequest = nil
        self.onSearchPresentationChanged = { _ in }
        self.actions = actions
    }

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        chrome: TorahInspectorChrome = .floatingPanel,
        selectedTool: Binding<TorahStudyToolID>,
        configuration: TorahInspectorConfiguration,
        presentationOptions: TorahInspectorPresentationOptions = .init(),
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.repository = repository
        self.selection = selection
        self.entryMode = entryMode
        self.chrome = chrome
        self.configuration = configuration
        self.presentationOptions = presentationOptions
        self.externalSelectedTool = nil
        self.usesLegacyDetailLayout = false
        self.externalSelectedToolID = selectedTool
        self.pendingSearchRequest = nil
        self.onSearchPresentationChanged = { _ in }
        self.actions = actions
    }

    init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        entryMode: TorahInspectorEntryMode,
        chrome: TorahInspectorChrome,
        selectedTool: Binding<TorahStudyToolID>,
        configuration: TorahInspectorConfiguration,
        presentationOptions: TorahInspectorPresentationOptions = .init(),
        actions: TorahInspectorHostActions,
        pendingSearchRequest: Binding<Bool>,
        onSearchPresentationChanged: @escaping (Bool) -> Void
    ) {
        self.repository = repository
        self.selection = selection
        self.entryMode = entryMode
        self.chrome = chrome
        self.configuration = configuration
        self.presentationOptions = presentationOptions
        self.externalSelectedTool = nil
        self.usesLegacyDetailLayout = false
        self.externalSelectedToolID = selectedTool
        self.pendingSearchRequest = pendingSearchRequest
        self.onSearchPresentationChanged = onSearchPresentationChanged
        self.actions = actions
    }

    public init(
        repository: TorahInspectorRepository,
        selection: TorahInspectorSelection,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        chrome: TorahInspectorChrome = .floatingPanel,
        selectedTool: Binding<TorahStudyTool>? = nil,
        presentationOptions: TorahInspectorPresentationOptions = .init(),
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
            presentationOptions: presentationOptions,
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
        Group {
            switch entryMode {
            case .sourceReader:
                _InspectorSourceReaderEntry(
                    selection: selection,
                    repository: repository,
                    selectedTool: selectedToolBinding,
                    chrome: chrome,
                    configuration: configuration,
                    readerSession: readerSession,
                    pendingSearchRequest: pendingSearchRequest,
                    onSearchPresentationChanged: onSearchPresentationChanged,
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
                    pendingSearchRequest: pendingSearchRequest,
                    onSearchPresentationChanged: onSearchPresentationChanged,
                    actions: actions
                )
            }
        }
        .background {
            TorahInspectorCloseKeyboardShortcut(onClose: actions.onClose)
        }
        .environment(\.torahInspectorPresentationOptions, presentationOptions)
        .environment(\.torahInspectorUsesLegacyDetailLayout, usesLegacyDetailLayout)
        .environment(\.torahInspectorNavigationLifetime, navigationLifetime)
        .onDisappear { navigationLifetime.identityWillChange() }
    }

    private var selectedToolBinding: Binding<TorahStudyToolID> {
        Binding(
            get: {
                externalSelectedToolID?.wrappedValue
                    ?? externalSelectedTool?.wrappedValue.toolID
                    ?? localSelectedToolID
            },
            set: { newValue in
                navigationLifetime.toolWillChange()
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
    @Binding var path: [TorahInspectorRoute]
    @Environment(\.torahInspectorNavigationStack) private var navigationStack

    func body(content: Content) -> some View {
        content.navigationDestination(for: TorahInspectorRoute.self) { route in
            switch route {
            case .search:
                if let search = actions.search {
                    search.destination(navigation: TorahInspectorSearchNavigation { nextSelection in
                        TorahInspectorSearchRouteCoordinator.navigateToFullSource(
                            nextSelection,
                            path: &path
                        )
                    })
                    .navigationTitle(TorahStrings.text("Search Torah sources"))
                    .torahInlineNavigationTitle()
                }
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
                    actions: destinationActions
                )
                .environment(\.torahInspectorNavigationScope, originalNavigationScope(for: route))
            case .source(let nextSelection):
                _InspectorLinkedSourceEntry(
                    selection: nextSelection,
                    repository: repository,
                    selectedTool: $selectedTool,
                    chrome: chrome,
                    configuration: configuration,
                    actions: destinationActions
                )
                .environment(\.torahInspectorNavigationScope, originalNavigationScope(for: route))
            case .fullSource(let nextSelection):
                TorahSourceReaderView(
                    selection: nextSelection,
                    repository: repository,
                    actions: destinationActions,
                    session: readerSession,
                    theme: configuration.theme
                )
                .modifier(_InspectorNavigationDestinations(
                    selection: nextSelection,
                    repository: repository,
                    selectedTool: $selectedTool,
                    chrome: chrome,
                    configuration: configuration,
                    readerSession: readerSession,
                    actions: actions,
                    path: $path
                ))
            }
        }
    }

    private func originalNavigationScope(for route: TorahInspectorRoute) -> TorahInspectorNavigationScope? {
        guard let navigationStack else { return nil }
        return TorahInspectorNavigationScope(lifetime: navigationStack.lifetime) { focus in
            guard navigationStack.isCurrentRoute(route) else { return false }
            switch route {
            case .segment(let segment):
                return focus == TorahInspectorFocus(segment: segment,
                    providerID: selection.providerID, sectionRef: selection.canonicalRef)
            case .source:
                // The linked entry additionally binds its actual document-load
                // request and resolved original segment before it exposes a panel.
                return true
            case .search, .fullSource:
                return false
            }
        }
    }

    private var destinationActions: TorahInspectorHostActions {
        var destinationActions = actions
        destinationActions.onRequestSearch = nil
        destinationActions.showsCloseButton = false
        return destinationActions
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
    @State private var documentLoads = TorahDocumentLoadLifetime()
    @Environment(\.locale) private var locale
    @Environment(\.torahInspectorNavigationScope) private var inheritedNavigationScope

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
                .environment(\.torahInspectorNavigationScope, originalDocumentScope)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label(TorahStrings.text("No text available", locale: locale), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button(TorahStrings.text("Retry", locale: locale), action: retrySegment)
                }
            } else {
                ProgressView()
            }
        }
        .task(id: selection.id) {
            guard !Task.isCancelled else { return }
            let request = documentLoads.activate(selectionID: selection.id)
            await loadSegment(request)
        }
        .onDisappear { documentLoads.invalidate() }
    }

    private var originalDocumentScope: TorahInspectorNavigationScope? {
        guard let inheritedNavigationScope,
              let request = documentLoads.request(for: selection.id) else { return nil }
        return TorahInspectorNavigationScope(lifetime: inheritedNavigationScope.lifetime) { candidate in
            guard documentLoads.isCurrent(request), let segment,
                  inheritedNavigationScope.isCurrent(candidate) else { return false }
            let expected = TorahInspectorFocus(segment: segment,
                providerID: selection.providerID, sectionRef: selection.canonicalRef)
            return candidate == expected && documentLoads.isCurrent(request)
        }
    }

    private func retrySegment() {
        guard let request = documentLoads.restart(for: selection.id) else { return }
        Task { await loadSegment(request) }
    }

    private func loadSegment(_ request: TorahDocumentLoadLifetime.Request) async {
        guard documentLoads.isCurrent(request), !Task.isCancelled else { return }
        segment = nil
        errorMessage = nil
        do {
            let document = try await documentLoads.load(for: request) {
                try await repository.document(
                    for: selection.canonicalRef,
                    providerID: selection.providerID
                )
            }
            guard documentLoads.isCurrent(request), !Task.isCancelled else { return }
            guard let resolved = TorahInspectorSegmentResolver.segment(
                in: document,
                preferredReference: selection.preferredSegmentRef ?? selection.canonicalRef
            ) else {
                throw TorahError.noText
            }
            segment = resolved
        } catch is CancellationError {
        } catch {
            guard documentLoads.isCurrent(request), !Task.isCancelled else { return }
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
    let pendingSearchRequest: Binding<Bool>?
    let onSearchPresentationChanged: (Bool) -> Void
    let actions: TorahInspectorHostActions
    @State private var path: [TorahInspectorRoute] = []
    @Environment(\.torahInspectorNavigationLifetime) private var navigationLifetime

    var body: some View {
        NavigationStack(path: originalNavigationPath) {
            TorahSourceReaderView(
                selection: selection,
                repository: repository,
                actions: rootActions,
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
                    actions: actions,
                    path: originalNavigationPath
                ))
        }
        .environment(\.torahInspectorNavigationStack, originalNavigationStack)
        .onAppear(perform: consumePendingSearchRequest)
        .onChange(of: pendingSearchRequest?.wrappedValue ?? false) { _, requested in
            if requested { consumePendingSearchRequest() }
        }
        .onChange(of: path) { oldPath, newPath in
            searchPathDidChange(from: oldPath, to: newPath)
        }
    }

    private var originalNavigationPath: Binding<[TorahInspectorRoute]> {
        Binding(get: { path }, set: { value in
            navigationLifetime?.identityWillChange()
            path = value
        })
    }

    private var originalNavigationStack: TorahInspectorNavigationStackSource? {
        guard let navigationLifetime else { return nil }
        return TorahInspectorNavigationStackSource(lifetime: navigationLifetime) { route in
            path.last == route
        }
    }

    private var rootActions: TorahInspectorHostActions {
        var rootActions = actions
        if actions.search != nil {
            rootActions.onRequestSearch = requestSearch
        }
        return rootActions
    }

    private func requestSearch() {
        guard actions.search != nil else { return }
        navigationLifetime?.identityWillChange()
        TorahInspectorSearchRouteCoordinator.showSearch(path: &path)
        onSearchPresentationChanged(true)
    }

    private func consumePendingSearchRequest() {
        guard let pendingSearchRequest, pendingSearchRequest.wrappedValue else { return }
        navigationLifetime?.identityWillChange()
        TorahInspectorSearchRouteCoordinator.showSearch(path: &path)
        pendingSearchRequest.wrappedValue = false
    }

    private func searchPathDidChange(
        from oldPath: [TorahInspectorRoute],
        to newPath: [TorahInspectorRoute]
    ) {
        if TorahInspectorSearchRouteCoordinator.didLeaveSearch(from: oldPath, to: newPath) {
            onSearchPresentationChanged(false)
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
    let pendingSearchRequest: Binding<Bool>?
    let onSearchPresentationChanged: (Bool) -> Void
    let actions: TorahInspectorHostActions
    @State private var path: [TorahInspectorRoute] = []
    @Environment(\.torahInspectorNavigationLifetime) private var navigationLifetime
    @State private var focus: TorahInspectorFocus?
    @State private var errorMessage: String?
    @State private var documentLoads = TorahDocumentLoadLifetime()
    @Environment(\.locale) private var locale

    init(
        selection: TorahInspectorSelection,
        repository: TorahInspectorRepository,
        selectedTool: Binding<TorahStudyToolID>,
        chrome: TorahInspectorChrome,
        configuration: TorahInspectorConfiguration,
        readerSession: TorahReaderSessionState,
        pendingSearchRequest: Binding<Bool>?,
        onSearchPresentationChanged: @escaping (Bool) -> Void,
        actions: TorahInspectorHostActions
    ) {
        self.selection = selection
        self.repository = repository
        self._selectedTool = selectedTool
        self.chrome = chrome
        self.configuration = configuration
        self.readerSession = readerSession
        self.pendingSearchRequest = pendingSearchRequest
        self.onSearchPresentationChanged = onSearchPresentationChanged
        self.actions = actions
    }

    var body: some View {
        NavigationStack(path: originalNavigationPath) {
            Group {
                if let focus {
                    TorahSegmentDetailView(
                        focus: focus,
                        repository: repository,
                        selectedTool: $selectedTool,
                        chrome: chrome,
                        configuration: configuration,
                        actions: rootActions
                    )
                    .environment(\.torahInspectorNavigationScope, originalRootScope)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label(TorahStrings.text("No text available", locale: locale), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button(TorahStrings.text("Retry", locale: locale), action: retrySegment)
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
                actions: actions,
                path: originalNavigationPath
            ))
            .task(id: selection.id) {
                guard !Task.isCancelled else { return }
                let request = documentLoads.activate(selectionID: selection.id)
                await loadSegment(request)
            }
            .onDisappear { documentLoads.invalidate() }
            .toolbar {
                if TorahInspectorNavigationChrome.showsFullSourceButton(
                    pathIsEmpty: path.isEmpty,
                    hasFocus: focus != nil,
                    allowsInlineFullSourceNavigation: configuration.allowsInlineFullSourceNavigation
                ) {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        fullSourceButton
                    }
                    #else
                    ToolbarItem(placement: .navigation) {
                        fullSourceButton
                    }
                    #endif
                }
            }
        }
        .environment(\.torahInspectorNavigationStack, originalNavigationStack)
        .onAppear(perform: consumePendingSearchRequest)
        .onChange(of: pendingSearchRequest?.wrappedValue ?? false) { _, requested in
            if requested { consumePendingSearchRequest() }
        }
        .onChange(of: path) { oldPath, newPath in
            searchPathDidChange(from: oldPath, to: newPath)
        }
    }

    private var originalNavigationPath: Binding<[TorahInspectorRoute]> {
        Binding(get: { path }, set: { value in
            navigationLifetime?.identityWillChange()
            path = value
        })
    }

    private var originalNavigationStack: TorahInspectorNavigationStackSource? {
        guard let navigationLifetime else { return nil }
        return TorahInspectorNavigationStackSource(lifetime: navigationLifetime) { route in
            path.last == route
        }
    }

    private var originalRootScope: TorahInspectorNavigationScope? {
        guard let navigationLifetime,
              let request = documentLoads.request(for: selection.id) else { return nil }
        return TorahInspectorNavigationScope(lifetime: navigationLifetime) { candidate in
            path.isEmpty && documentLoads.isCurrent(request) && focus == candidate
        }
    }

    private var rootActions: TorahInspectorHostActions {
        var rootActions = actions
        if actions.search != nil {
            rootActions.onRequestSearch = requestSearch
        }
        return rootActions
    }

    private func requestSearch() {
        guard actions.search != nil else { return }
        navigationLifetime?.identityWillChange()
        TorahInspectorSearchRouteCoordinator.showSearch(path: &path)
        onSearchPresentationChanged(true)
    }

    private func consumePendingSearchRequest() {
        guard let pendingSearchRequest, pendingSearchRequest.wrappedValue else { return }
        navigationLifetime?.identityWillChange()
        TorahInspectorSearchRouteCoordinator.showSearch(path: &path)
        pendingSearchRequest.wrappedValue = false
    }

    private func searchPathDidChange(
        from oldPath: [TorahInspectorRoute],
        to newPath: [TorahInspectorRoute]
    ) {
        if TorahInspectorSearchRouteCoordinator.didLeaveSearch(from: oldPath, to: newPath) {
            onSearchPresentationChanged(false)
        }
    }

    private var fullSourceButton: some View {
        Button {
            navigationLifetime?.identityWillChange()
            path.append(.fullSource(selection))
        } label: {
            Image(systemName: "book.closed")
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(TorahStrings.text("Open full source", locale: locale))
        .accessibilityIdentifier("torah-inspector-open-full-source")
    }

    private func retrySegment() {
        guard let request = documentLoads.restart(for: selection.id) else { return }
        Task { await loadSegment(request) }
    }

    private func loadSegment(_ request: TorahDocumentLoadLifetime.Request) async {
        guard documentLoads.isCurrent(request), !Task.isCancelled else { return }
        focus = nil
        errorMessage = nil
        do {
            let document = try await documentLoads.load(for: request) {
                try await repository.document(
                    for: selection.canonicalRef,
                    providerID: selection.providerID
                )
            }
            guard documentLoads.isCurrent(request), !Task.isCancelled else { return }
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
            guard documentLoads.isCurrent(request), !Task.isCancelled else { return }
            errorMessage = TorahStrings.message(for: error, locale: locale)
        }
    }
}

enum TorahInspectorSearchRouteCoordinator {
    static func showSearch(path: inout [TorahInspectorRoute]) {
        guard !path.contains(.search) else { return }
        path.append(.search)
    }

    static func navigateToFullSource(
        _ selection: TorahInspectorSelection,
        path: inout [TorahInspectorRoute]
    ) {
        guard path.contains(.search) else { return }
        let destination = TorahInspectorRoute.fullSource(selection)
        guard path.last != destination else { return }
        path.append(destination)
    }

    static func didLeaveSearch(
        from oldPath: [TorahInspectorRoute],
        to newPath: [TorahInspectorRoute]
    ) -> Bool {
        oldPath.contains(.search) && !newPath.contains(.search)
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
