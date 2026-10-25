import Foundation
import SwiftUI
import TorahInspectorCore

public struct TorahSegmentDetailView: View {
    public let focus: TorahInspectorFocus
    public let repository: TorahInspectorRepository
    public let actions: TorahInspectorHostActions
    public let chrome: TorahInspectorChrome
    public let configuration: TorahInspectorConfiguration
    @Binding private var selectedTool: TorahStudyToolID

    @State private var linksState = TorahPanelLoadState<TorahLinksSnapshot>.idle
    @State private var topicsState = TorahPanelLoadState<[TorahLinkedTopic]>.idle
    @State private var notesState = TorahPanelLoadState<[TorahInspectorNote]>.idle
    @State private var relatedDocumentsState = TorahPanelLoadState<TorahRelatedDocumentsSnapshot>.idle
    @State private var loadedFocusID: String?
    @State private var selectorState = TorahToolSelectorStateMachine()
    @State private var expandedSourceIDs: Set<TorahLinkedSource.ID> = []
    @State private var expandedSourceText: [TorahLinkedSource.ID: String] = [:]
    @State private var expandedSourceErrors: [TorahLinkedSource.ID: String] = [:]
    @State private var loadingSourceIDs: Set<TorahLinkedSource.ID> = []
    @State private var expandedCommentaryGroupIDs: Set<TorahSourceGroup.ID> = []
    @Environment(\.locale) private var locale

    public init(
        focus: TorahInspectorFocus,
        repository: TorahInspectorRepository,
        selectedTool: Binding<TorahStudyToolID>,
        chrome: TorahInspectorChrome = .floatingPanel,
        configuration: TorahInspectorConfiguration,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.focus = focus
        self.repository = repository
        self._selectedTool = selectedTool
        self.chrome = chrome
        self.configuration = configuration
        self.actions = actions
    }

    public init(
        focus: TorahInspectorFocus,
        repository: TorahInspectorRepository,
        selectedTool: Binding<TorahStudyTool> = .constant(.commentaries),
        chrome: TorahInspectorChrome = .floatingPanel,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        let bridged = Binding<TorahStudyToolID>(
            get: { selectedTool.wrappedValue.toolID },
            set: { value in
                if let legacy = TorahStudyTool(rawValue: value.rawValue) {
                    selectedTool.wrappedValue = legacy
                }
            }
        )
        self.init(
            focus: focus,
            repository: repository,
            selectedTool: bridged,
            chrome: chrome,
            configuration: .legacy,
            actions: actions
        )
    }

    public init(
        segment: TorahTextSegment,
        providerID: String,
        repository: TorahInspectorRepository,
        selectedTool: Binding<TorahStudyTool> = .constant(.commentaries),
        chrome: TorahInspectorChrome = .floatingPanel,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.init(
            focus: TorahInspectorFocus(segment: segment, providerID: providerID),
            repository: repository,
            selectedTool: selectedTool,
            chrome: chrome,
            actions: actions
        )
    }

    public init(
        segment: TorahTextSegment,
        providerID: String,
        repository: TorahInspectorRepository,
        selectedTool: Binding<TorahStudyToolID>,
        chrome: TorahInspectorChrome = .floatingPanel,
        configuration: TorahInspectorConfiguration,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.init(
            focus: TorahInspectorFocus(segment: segment, providerID: providerID),
            repository: repository,
            selectedTool: selectedTool,
            chrome: chrome,
            configuration: configuration,
            actions: actions
        )
    }

    private var selection: TorahInspectorSelection { focus.selection }
    private var providerID: String { selection.providerID }
    private var links: [TorahLinkedSource] { linksState.value?.sources ?? [] }
    private var groups: TorahRelationshipGroups {
        linksState.value?.groups ?? TorahRelationshipGroups(sources: [])
    }
    private var topics: [TorahLinkedTopic] { topicsState.value ?? [] }
    private var notes: [TorahInspectorNote] { notesState.value ?? [] }
    private var relatedDocuments: TorahRelatedDocumentsSnapshot? { relatedDocumentsState.value }
    private var linksError: String? { linksState.errorMessage }
    private var topicsError: String? { topicsState.errorMessage }
    private var notesError: String? { notesState.errorMessage }
    private var relatedDocumentsError: String? { relatedDocumentsState.errorMessage }
    private var loadingLinks: Bool { linksState.isLoadingWithoutValue }
    private var loadingTopics: Bool { topicsState.isLoadingWithoutValue }
    private var loadingNotes: Bool { notesState.isLoadingWithoutValue }
    private var loadingRelatedDocuments: Bool { relatedDocumentsState.isLoadingWithoutValue }

    @ViewBuilder
    public var body: some View {
        switch chrome {
        case .embeddedSheet:
            panelContent
                .background(configuration.theme.background)
        case .floatingPanel:
            panelContent
                .background(configuration.theme.background)
                .compositingGroup()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.035), radius: 7, x: 0, y: 2)
                .padding(8)
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            if selectorState.visibility == .visible {
                toolSelector
                Divider().opacity(0.45)
            }
            toolContent
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("torah-inspector-panel")
        .navigationTitle(segmentDisplayRef)
        .torahInlineNavigationTitle()
        .toolbar { detailToolbar }
        .task(id: TorahPanelLoadTaskID(focusID: focus.id, tool: selectedTool)) {
            prepareForCurrentFocus()
            await loadSelectedTool()
        }
        .onAppear { ensureValidSelectedTool() }
        .onChange(of: configuration.availableTools) { _, _ in ensureValidSelectedTool() }
        .onReceive(NotificationCenter.default.publisher(for: .torahInspectorNotesDidChange)) { _ in
            if selectedTool == .notes {
                Task { @MainActor in await loadNotes(force: true) }
            } else {
                notesState.reset()
            }
        }
    }

    private var toolSelector: some View {
        Picker(TorahStrings.text("Study Tools", locale: locale), selection: $selectedTool) {
            ForEach(configuration.availableTools) { tool in
                Text(tool.localizedTitle(locale: locale)).tag(tool)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("torah-inspector-tools")
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        #if os(iOS)
        ToolbarItemGroup(placement: .topBarTrailing) {
            detailToolbarButtons
        }
        #else
        ToolbarItemGroup(placement: .primaryAction) {
            detailToolbarButtons
        }
        #endif
    }

    @ViewBuilder
    private var detailToolbarButtons: some View {
        if selectorState.visibility == .collapsed {
            Button {
                selectorState.revealManually()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(TorahStrings.text("Study Tools", locale: locale))
            .accessibilityIdentifier("torah-inspector-show-tools")
        }
        if actions.onRequestSearch != nil {
            TorahInspectorSearchButton(
                actions: actions,
                accessibilityIdentifier: "torah-inspector-search-entry"
            )
        } else if actions.showsCloseButton, let onClose = actions.onClose {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(TorahStrings.text("Close", locale: locale))
            .accessibilityIdentifier("torah-inspector-close")
        }
    }

    private var toolContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                switch selectedTool {
                case .commentaries:
                    commentariesContent
                case .links:
                    linksContent
                case .notes:
                    notesContent
                case .relatedDocuments:
                    relatedDocumentsContent
                default:
                    emptyRow(TorahStrings.text("No results", locale: locale))
                }
            }
            .padding(14)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: TorahSelectorFallbackContentPreferenceKey.self,
                        value: TorahSelectorFallbackContentInfo(
                            offset: max(
                                0,
                                -geometry.frame(in: .named(torahSelectorScrollCoordinateSpace)).minY
                            ),
                            contentHeight: geometry.size.height
                        )
                    )
                }
            }
        }
        .coordinateSpace(name: torahSelectorScrollCoordinateSpace)
        .modifier(TorahSelectorScrollObserver(state: $selectorState))
    }

    @ViewBuilder
    private var commentariesContent: some View {
        if loadingLinks {
            loadingRow
        } else if let linksError {
            retryCard(linksError) { Task { await loadLinks(force: true) } }
        } else if groups.commentaryGroups.isEmpty && groups.quotingCommentaryGroups.isEmpty {
            emptyRow(TorahStrings.text("No results", locale: locale))
        } else {
            if !groups.commentaryGroups.isEmpty {
                ForEach(groups.commentaryGroups) { group in
                    commentaryGroupCard(group)
                        .accessibilityIdentifier("torah-inspector-commentary-group-\(group.id)")
                }
            }
            if !groups.quotingCommentaryGroups.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(TorahStrings.text("Quoting Commentaries", locale: locale))
                        .font(.headline)
                        .padding(.top, groups.commentaryGroups.isEmpty ? 0 : 8)
                    ForEach(groups.quotingCommentaryGroups) { group in
                        commentaryGroupCard(group)
                            .accessibilityIdentifier("torah-inspector-quoting-commentary-group-\(group.id)")
                    }
                }
            }
        }
    }

    private func commentaryGroupCard(_ group: TorahSourceGroup) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCommentaryGroupIDs.contains(group.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedCommentaryGroupIDs.insert(group.id)
                    } else {
                        expandedCommentaryGroupIDs.remove(group.id)
                    }
                }
            )
        ) {
            LazyVStack(alignment: .leading, spacing: 10) {
                if group.works.count > 1 {
                    ForEach(group.works) { work in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(TorahInspectorPresentation.workTitle(work, locale: locale))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            ForEach(work.entries) { source in
                                expandableSourceRow(source, commentary: true)
                            }
                        }
                    }
                } else {
                    ForEach(group.entries) { source in
                        expandableSourceRow(source, commentary: true)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(commentaryGroupTitle(group))
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text(group.count, format: .number)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.05), in: Capsule())
            }
        }
        .padding(13)
        .background(Color.torahSecondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func sourceBodyContent(source: TorahLinkedSource, isCommentary: Bool) -> some View {
        let isExpanded = expandedSourceIDs.contains(source.id)
        if isExpanded {
            if loadingSourceIDs.contains(source.id) {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Spacer()
                }
            } else if let errorMsg = expandedSourceErrors[source.id] {
                VStack(alignment: .leading, spacing: 6) {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(TorahStrings.text("Retry", locale: locale)) {
                        Task { await loadFullSource(source) }
                    }
                    .font(.caption.weight(.semibold))
                }
            } else if let fullText = expandedSourceText[source.id] {
                Text(fullText)
                    .font(isCommentary ? .system(size: 15) : .body)
                    .lineSpacing(isCommentary ? 4 : 3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, layoutDirection(for: fullText))
            } else if let snippet = TorahInspectorPresentation.linkedText(source, locale: locale) {
                Text(snippet)
                    .font(isCommentary ? .system(size: 15) : .caption)
                    .lineSpacing(isCommentary ? 4 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if let snippet = TorahInspectorPresentation.linkedText(source, locale: locale) {
            Text(snippet)
                .font(isCommentary ? .system(size: 15) : .caption)
                .lineSpacing(isCommentary ? 4 : 2)
                .lineLimit(isCommentary ? 5 : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(isCommentary ? .primary : .secondary)
        }
    }

    private func commentaryCard(_ source: TorahLinkedSource) -> some View {
        let isExpanded = expandedSourceIDs.contains(source.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayReference(source))
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                expansionIndicator(source)
            }
            sourceBodyContent(source: source, isCommentary: true)
            HStack {
                Text(TorahInspectorPresentation.categoryTitle(source.semanticCategory, locale: locale))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if isExpanded, actions.onOpenInNewTab != nil {
                    Button {
                        openInReader(source)
                    } label: {
                        Label(TorahStrings.text("Open in new tab", locale: locale), systemImage: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("torah-inspector-open-\(source.id)")
                }
            }
        }
        .padding(13)
        .background(isExpanded ? Color.accentColor.opacity(0.08) : Color.torahSecondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var linksContent: some View {
        if loadingLinks && links.isEmpty {
            loadingRow
        } else {
            if let linksError {
                retryCard(linksError) { Task { await loadLinks(force: true) } }
            }
            ForEach(groups.linkedSources) { source in
                expandableSourceRow(source, commentary: false)
            }
            topicsContent
            if groups.linkedSources.isEmpty,
               topics.isEmpty,
               !loadingTopics,
               linksError == nil,
               topicsError == nil {
                emptyRow(TorahStrings.text("No results", locale: locale))
            }
        }
    }

    private func linkedSourceCard(_ source: TorahLinkedSource) -> some View {
        let isExpanded = expandedSourceIDs.contains(source.id)
        return HStack(alignment: .top, spacing: 11) {
            Image(systemName: TorahInspectorAppearance.referenceSymbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayReference(source))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 4)
                    expansionIndicator(source)
                }
                Text(TorahInspectorPresentation.categoryTitle(source.semanticCategory, locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                sourceBodyContent(source: source, isCommentary: false)
                if isExpanded {
                    NavigationLink(value: TorahInspectorRoute.source(sourceSelection(source))) {
                        Label(TorahStrings.text("View details", locale: locale), systemImage: "chevron.forward")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("torah-inspector-view-source-\(source.id)")
                }
                if isExpanded, actions.onOpenInNewTab != nil {
                    Button {
                        openInReader(source)
                    } label: {
                        Label(TorahStrings.text("Open in new tab", locale: locale), systemImage: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 4)
                    .accessibilityIdentifier("torah-inspector-open-\(source.id)")
                }
            }
        }
        .padding(13)
        .background(isExpanded ? Color.accentColor.opacity(0.08) : Color.torahSecondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func expansionIndicator(_ source: TorahLinkedSource) -> some View {
        Image(systemName: expandedSourceIDs.contains(source.id) ? "chevron.up" : "chevron.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
    }

    private func expandableSourceRow(_ source: TorahLinkedSource, commentary: Bool) -> some View {
        let isExpanded = expandedSourceIDs.contains(source.id)
        return VStack(alignment: .leading, spacing: 0) {
            Group {
                if commentary {
                    commentaryCard(source)
                } else {
                    linkedSourceCard(source)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                TapGesture(count: 2)
                    .exclusively(before: TapGesture(count: 1))
                    .onEnded { value in
                        switch value {
                        case .first:
                            if actions.onOpenInNewTab != nil {
                                openInReader(source)
                            } else {
                                toggleExpansion(source)
                            }
                        case .second:
                            toggleExpansion(source)
                        }
                    }
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("torah-inspector-source-\(source.id)")
            .accessibilityLabel("\(displayReference(source)), \(TorahInspectorPresentation.categoryTitle(source.semanticCategory, locale: locale))")
            .accessibilityValue(TorahStrings.text(isExpanded ? "Expanded" : "Collapsed", locale: locale))
            .accessibilityAction { toggleExpansion(source) }
            .contextMenu {
                if actions.onOpenInNewTab != nil {
                    Button(TorahStrings.text("Open in new tab", locale: locale), systemImage: "arrow.up.right.square") {
                        openInReader(source)
                    }
                }
                #if canImport(UIKit)
                Button(TorahStrings.text("Copy", locale: locale), systemImage: "doc.on.doc") {
                    let textToCopy = expandedSourceText[source.id] ?? TorahInspectorPresentation.linkedText(source, locale: locale) ?? ""
                    UIPasteboard.general.string = textToCopy
                }
                #endif
            }

            if isExpanded {
                Color.clear
                    .frame(height: 2)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("torah-inspector-source-expanded-\(source.id)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func toggleExpansion(_ source: TorahLinkedSource) {
        if expandedSourceIDs.remove(source.id) != nil { return }
        expandedSourceIDs.insert(source.id)
        guard expandedSourceText[source.id] == nil,
              !loadingSourceIDs.contains(source.id) else { return }
        Task { await loadFullSource(source) }
    }

    private func openInReader(_ source: TorahLinkedSource) {
        actions.onOpenInNewTab?(sourceSelection(source))
    }

    private func sourceSelection(_ source: TorahLinkedSource) -> TorahInspectorSelection {
        TorahInspectorSelection(
            providerID: providerID,
            canonicalRef: source.sourceRef,
            preferredSegmentRef: source.sourceRef,
            scope: .segment,
            displayMetadata: TorahReferenceDisplayMetadata(
                english: source.sourceRef,
                hebrew: source.sourceHebrewRef
            )
        )
    }

    @MainActor
    private func loadFullSource(_ source: TorahLinkedSource) async {
        loadingSourceIDs.insert(source.id)
        expandedSourceErrors.removeValue(forKey: source.id)
        defer { loadingSourceIDs.remove(source.id) }
        do {
            let document = try await repository.document(
                for: source.sourceRef,
                providerID: providerID
            )
            guard let text = TorahInspectorSourceTextResolver.text(
                in: document,
                exactReference: source.sourceRef
            ) else {
                throw TorahError.noText
            }
            expandedSourceText[source.id] = text
        } catch is CancellationError {
        } catch {
            expandedSourceErrors[source.id] = TorahStrings.message(for: error, locale: locale)
        }
    }

    @ViewBuilder
    private var topicsContent: some View {
        if loadingTopics {
            loadingRow
        } else if let topicsError {
            retryCard(topicsError) { Task { await loadTopics(force: true) } }
        } else if !topics.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text(TorahStrings.text("Topics", locale: locale))
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(topics) { topic in
                        Label(TorahInspectorPresentation.topicTitle(topic, locale: locale), systemImage: TorahInspectorAppearance.topicSymbol)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.torahSecondarySystemBackground)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var notesContent: some View {
        if let onAddNote = actions.onAddNote {
            Button {
                onAddNote(selection, notesDidChange)
            } label: {
                Label(TorahStrings.text("Add Note", locale: locale), systemImage: "plus")
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .accessibilityIdentifier("torah-inspector-add-note")
        }

        if loadingNotes {
            loadingRow
        } else if let notesError {
            retryCard(notesError) { Task { await refreshNotes() } }
        } else if notes.isEmpty {
            emptyRow(TorahStrings.text("No notes", locale: locale))
        } else {
            VStack(spacing: 0) {
                ForEach(notes) { note in
                    Button {
                        actions.onOpenNote?(note, selection, notesDidChange)
                    } label: {
                        noteRow(note)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("torah-inspector-note-\(note.id)")
                    .accessibilityLabel(note.note)
                    .contextMenu {
                        if let onDeleteNote = actions.onDeleteNote {
                            Button(role: .destructive) {
                                onDeleteNote(note, selection, notesDidChange)
                            } label: {
                                Label(TorahStrings.text("Delete", locale: locale), systemImage: "trash")
                            }
                        }
                    }
                    if note.id != notes.last?.id {
                        Divider().opacity(0.35)
                    }
                }
            }
            .background(Color.torahSecondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private var relatedDocumentsContent: some View {
        if let onAddNote = actions.onAddNote {
            Button {
                onAddNote(selection, relatedDocumentsDidChange)
            } label: {
                Label(TorahStrings.text("Add Note", locale: locale), systemImage: "plus")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("torah-inspector-related-add-note")
        }
        if loadingRelatedDocuments {
            loadingRow
        } else if let relatedDocumentsError {
            retryCard(relatedDocumentsError) { Task { await loadRelatedDocuments(force: true) } }
        } else if let snapshot = relatedDocuments {
            if snapshot.coverage != .spaceWide {
                Label(
                    TorahStrings.text("Space-wide backlinks are unavailable", locale: locale),
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(configuration.theme.secondaryText)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(configuration.theme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("torah-inspector-related-documents-unavailable")
            }
            if snapshot.documents.isEmpty {
                emptyRow(TorahStrings.text("No current-document links", locale: locale))
            } else {
                ForEach(snapshot.documents) { document in
                    Button {
                        actions.onOpenRelatedDocument?(document)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            configuration.theme.text(document.title, role: .body)
                            if let snippet = document.snippet, !snippet.isEmpty {
                                configuration.theme.text(snippet, role: .caption)
                                    .foregroundStyle(configuration.theme.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(13)
                        .background(configuration.theme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(actions.onOpenRelatedDocument == nil)
                    .contextMenu {
                        if let onUnlink = actions.onUnlinkRelatedDocument {
                            Button(role: .destructive) {
                                onUnlink(document, selection, relatedDocumentsDidChange)
                            } label: {
                                Label(TorahStrings.text("Unlink", locale: locale), systemImage: "link.badge.minus")
                            }
                        }
                    }
                }
            }
        }
    }

    private func noteRow(_ note: TorahInspectorNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.selectedText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(note.note)
                .font(.system(size: 18))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let tag = note.tag, !tag.isEmpty {
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.045))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }

    private var loadingRow: some View {
        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    private func emptyRow(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    private func retryCard(_ message: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Text(message).font(.caption).foregroundStyle(.secondary)
            Button(TorahStrings.text("Retry", locale: locale), action: action)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.torahSecondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var segmentDisplayRef: String {
        TorahInspectorPresentation.reference(
            canonical: focus.displayRef,
            hebrew: focus.hebrewDisplayRef,
            locale: locale
        )
    }

    private func displayReference(_ source: TorahLinkedSource) -> String {
        TorahInspectorPresentation.reference(canonical: source.sourceRef, hebrew: source.sourceHebrewRef, locale: locale)
    }

    private func commentaryTitle(_ source: TorahLinkedSource) -> String {
        let prefersHebrew = TorahInspectorPresentation.prefersHebrew(locale)
        let preferred = prefersHebrew ? source.hebrewCollectiveTitle : source.collectiveTitle
        let fallback = prefersHebrew ? source.collectiveTitle : source.hebrewCollectiveTitle
        return preferred ?? fallback ?? displayReference(source)
    }

    private func commentaryGroupTitle(_ group: TorahSourceGroup) -> String {
        let prefersHebrew = TorahInspectorPresentation.prefersHebrew(locale)
        let preferred = prefersHebrew ? group.hebrewTitle : group.title
        let fallback = prefersHebrew ? group.title : group.hebrewTitle
        return preferred ?? fallback ?? group.title
    }

    private var segmentLayoutDirection: LayoutDirection {
        layoutDirection(for: focus.text ?? focus.displayRef)
    }

    private func layoutDirection(for text: String) -> LayoutDirection {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF:
                return .rightToLeft
            default:
                if CharacterSet.letters.contains(scalar) { return .leftToRight }
            }
        }
        return .leftToRight
    }

    @MainActor
    private func prepareForCurrentFocus() {
        guard loadedFocusID != focus.id else { return }
        loadedFocusID = focus.id
        linksState.reset()
        topicsState.reset()
        notesState.reset()
        relatedDocumentsState.reset()
        expandedSourceIDs.removeAll()
        expandedSourceText.removeAll()
        expandedSourceErrors.removeAll()
        loadingSourceIDs.removeAll()
        expandedCommentaryGroupIDs.removeAll()
    }

    private func loadSelectedTool() async {
        switch TorahPanelLoadDemand.demand(for: selectedTool) {
        case .links:
            await loadLinks()
        case .linksAndTopics:
            async let loadedLinks: Void = loadLinks()
            async let loadedTopics: Void = loadTopics()
            _ = await (loadedLinks, loadedTopics)
        case .notes:
            await loadNotes()
        case .relatedDocuments:
            await loadRelatedDocuments()
        case .none:
            break
        }
    }

    @MainActor
    private func loadLinks(force: Bool = false) async {
        if !force, case .loaded = linksState { return }
        let request = linksState.begin(focusID: focus.id)
        do {
            let fetched = try await repository.links(for: selection.relationshipRef, providerID: providerID)
            try Task.checkCancellation()
            let snapshot = TorahLinksSnapshot(
                sources: fetched,
                groups: TorahRelationshipGroups(sources: fetched)
            )
            try Task.checkCancellation()
            linksState.publish(snapshot, for: request)
        } catch is CancellationError {
            linksState.cancel(request)
        } catch {
            linksState.fail(
                TorahStrings.text("Could not load related sources", locale: locale),
                for: request
            )
        }
    }

    @MainActor
    private func loadTopics(force: Bool = false) async {
        if !force, case .loaded = topicsState { return }
        let request = topicsState.begin(focusID: focus.id)
        do {
            let fetched = try await repository.topics(
                for: selection.relationshipRef,
                providerID: providerID
            )
            try Task.checkCancellation()
            topicsState.publish(fetched, for: request)
        } catch is CancellationError {
            topicsState.cancel(request)
        } catch {
            topicsState.fail(
                TorahStrings.text("Could not load related sources", locale: locale),
                for: request
            )
        }
    }

    @MainActor
    private func loadNotes(force: Bool = false) async {
        if !force, case .loaded = notesState { return }
        let request = notesState.begin(focusID: focus.id)
        do {
            let fetched = try await repository.notes(for: selection)
            try Task.checkCancellation()
            notesState.publish(fetched, for: request)
        } catch is CancellationError {
            notesState.cancel(request)
        } catch {
            notesState.fail(
                TorahStrings.text("Could not load notes", locale: locale),
                for: request
            )
        }
    }

    @MainActor
    private func refreshNotes() async {
        repository.invalidateNotes(for: selection)
        await loadNotes(force: true)
    }

    private func notesDidChange() {
        Task { @MainActor in
            repository.invalidateNotes(for: selection)
            await loadNotes(force: true)
        }
    }

    @MainActor
    private func loadRelatedDocuments(force: Bool = false) async {
        if !force, case .loaded = relatedDocumentsState { return }
        let request = relatedDocumentsState.begin(focusID: focus.id)
        do {
            let fetched = try await repository.relatedDocuments(for: selection)
            try Task.checkCancellation()
            relatedDocumentsState.publish(fetched, for: request)
        } catch is CancellationError {
            relatedDocumentsState.cancel(request)
        } catch {
            relatedDocumentsState.fail(
                TorahStrings.text("Could not load related documents", locale: locale),
                for: request
            )
        }
    }

    private func relatedDocumentsDidChange() {
        Task { @MainActor in
            repository.invalidateRelatedDocuments(for: selection)
            await loadRelatedDocuments(force: true)
        }
    }

    private func ensureValidSelectedTool() {
        guard !configuration.availableTools.contains(selectedTool),
              let first = configuration.availableTools.first else { return }
        selectedTool = first
    }
}

private struct TorahSelectorScrollInfo: Equatable {
    let offset: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat
}

private let torahSelectorScrollCoordinateSpace = "torah-inspector-tool-scroll"

private struct TorahSelectorFallbackContentInfo: Equatable, Sendable {
    let offset: CGFloat
    let contentHeight: CGFloat

    static let zero = Self(offset: 0, contentHeight: 0)
}

private struct TorahSelectorFallbackContentPreferenceKey: PreferenceKey {
    static let defaultValue = TorahSelectorFallbackContentInfo.zero

    static func reduce(
        value: inout TorahSelectorFallbackContentInfo,
        nextValue: () -> TorahSelectorFallbackContentInfo
    ) {
        value = nextValue()
    }
}

private struct TorahSelectorFallbackViewportPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TorahSelectorScrollObserver: ViewModifier {
    @Binding var state: TorahToolSelectorStateMachine
    @State private var fallbackContent = TorahSelectorFallbackContentInfo.zero
    @State private var fallbackViewportHeight: CGFloat = 0

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: TorahSelectorScrollInfo.self) { geometry in
                TorahSelectorScrollInfo(
                    offset: geometry.contentOffset.y,
                    contentHeight: geometry.contentSize.height,
                    viewportHeight: geometry.containerSize.height
                )
            } action: { _, info in
                _ = state.update(
                    offset: info.offset,
                    contentHeight: info.contentHeight,
                    viewportHeight: info.viewportHeight
                )
            }
        } else {
            content
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: TorahSelectorFallbackViewportPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                }
                .onPreferenceChange(TorahSelectorFallbackContentPreferenceKey.self) { info in
                    fallbackContent = info
                    updateFallbackState()
                }
                .onPreferenceChange(TorahSelectorFallbackViewportPreferenceKey.self) { height in
                    fallbackViewportHeight = height
                    updateFallbackState()
                }
        }
    }

    private func updateFallbackState() {
        guard fallbackContent.contentHeight > 0, fallbackViewportHeight > 0 else { return }
        _ = state.update(
            offset: fallbackContent.offset,
            contentHeight: fallbackContent.contentHeight,
            viewportHeight: fallbackViewportHeight
        )
    }
}

enum TorahInspectorSourceTextResolver {
    static func text(in document: TorahTextDocument, exactReference: String) -> String? {
        if let segment = document.segments.first(where: { $0.canonicalRef == exactReference }) {
            return segment.text.isEmpty ? nil : segment.text
        }
        let documentMatches = [document.requestedRef, document.canonicalRef, document.sectionRef]
            .contains(exactReference)
        guard documentMatches else { return nil }
        let text = document.segments.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n")
        return text.isEmpty ? nil : text
    }
}
