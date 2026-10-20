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

    @State private var links: [TorahLinkedSource] = []
    @State private var topics: [TorahLinkedTopic] = []
    @State private var notes: [TorahInspectorNote] = []
    @State private var relatedDocuments: TorahRelatedDocumentsSnapshot?
    @State private var linksError: String?
    @State private var topicsError: String?
    @State private var notesError: String?
    @State private var loadingLinks = true
    @State private var loadingTopics = true
    @State private var loadingNotes = true
    @State private var loadingRelatedDocuments = true
    @State private var relatedDocumentsError: String?
    @State private var selectorState = TorahToolSelectorStateMachine()
    @State private var expandedSourceIDs: Set<TorahLinkedSource.ID> = []
    @State private var expandedSourceText: [TorahLinkedSource.ID: String] = [:]
    @State private var expandedSourceErrors: [TorahLinkedSource.ID: String] = [:]
    @State private var loadingSourceIDs: Set<TorahLinkedSource.ID> = []
    @State private var expandedCommentaryGroupIDs: Set<TorahSourceGroup.ID> = []
    @State private var cachedGroups: TorahRelationshipGroups?
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

    private var groups: TorahRelationshipGroups { cachedGroups ?? TorahRelationshipGroups(sources: links) }

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
            panelHeader
            Divider().opacity(0.45)
            toolContent
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("torah-inspector-panel")
        .task(id: focus.id) { await loadPanelData() }
        .onAppear { ensureValidSelectedTool() }
        .onChange(of: configuration.availableTools) { _, _ in ensureValidSelectedTool() }
        .onReceive(NotificationCenter.default.publisher(for: .torahInspectorNotesDidChange)) { _ in
            Task { @MainActor in
                await loadNotes()
            }
        }
        .onChange(of: links) { _, newLinks in
            if cachedGroups == nil {
                cachedGroups = TorahRelationshipGroups(sources: newLinks)
            }
        }
    }

    private var panelHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                configuration.theme.text(segmentDisplayRef, role: .heading)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if selectorState.visibility == .collapsed {
                    Button {
                        selectorState.revealManually()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TorahStrings.text("Study Tools", locale: locale))
                    .accessibilityIdentifier("torah-inspector-show-tools")
                }
                if configuration.allowsInlineFullSourceNavigation {
                    NavigationLink(value: TorahInspectorRoute.fullSource(selection)) {
                        Image(systemName: "book.closed")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TorahStrings.text("Open full source", locale: locale))
                    .accessibilityIdentifier("torah-inspector-open-full-source")
                }
                if actions.showsCloseButton, let onClose = actions.onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TorahStrings.text("Close", locale: locale))
                    .accessibilityIdentifier("torah-inspector-close")
                }
            }

            if selectorState.visibility == .visible {
                Picker(TorahStrings.text("Study Tools", locale: locale), selection: $selectedTool) {
                    ForEach(configuration.availableTools) { tool in
                        Text(tool.localizedTitle(locale: locale)).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("torah-inspector-tools")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
        }
        .modifier(TorahSelectorScrollObserver(state: $selectorState))
    }

    @ViewBuilder
    private var commentariesContent: some View {
        if loadingLinks {
            loadingRow
        } else if let linksError {
            retryCard(linksError) { Task { await loadLinks() } }
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
        if loadingLinks {
            loadingRow
        } else if let linksError {
            retryCard(linksError) { Task { await loadLinks() } }
        } else if groups.linkedSources.isEmpty && topics.isEmpty && !loadingTopics {
            emptyRow(TorahStrings.text("No results", locale: locale))
        } else {
            ForEach(groups.linkedSources) { source in
                expandableSourceRow(source, commentary: false)
            }
            topicsContent
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
            scope: .segment
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
            retryCard(topicsError) { Task { await loadTopics() } }
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
            retryCard(relatedDocumentsError) { Task { await loadRelatedDocuments() } }
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

    private func loadPanelData() async {
        async let loadedLinks: Void = loadLinks()
        async let loadedTopics: Void = loadTopics()
        async let loadedNotes: Void = loadNotes()
        async let loadedRelatedDocuments: Void = loadRelatedDocuments()
        _ = await (loadedLinks, loadedTopics, loadedNotes, loadedRelatedDocuments)
    }

    @MainActor
    private func loadLinks() async {
        loadingLinks = true
        linksError = nil
        do {
            let fetched = try await repository.links(for: selection.relationshipRef, providerID: providerID)
            let computedGroups: TorahRelationshipGroups
            if fetched.isEmpty {
                computedGroups = TorahRelationshipGroups(sources: [])
            } else {
                computedGroups = await Task.detached(priority: .userInitiated) {
                    TorahRelationshipGroups(sources: fetched)
                }.value
            }
            guard !Task.isCancelled else { return }
            cachedGroups = computedGroups
            links = fetched
        } catch is CancellationError {
        } catch {
            linksError = TorahStrings.text("Could not load related sources", locale: locale)
        }
        loadingLinks = false
    }

    @MainActor
    private func loadTopics() async {
        loadingTopics = true
        topicsError = nil
        do {
            topics = try await repository.topics(for: selection.relationshipRef, providerID: providerID)
        } catch is CancellationError {
        } catch {
            topicsError = TorahStrings.text("Could not load related sources", locale: locale)
        }
        loadingTopics = false
    }

    @MainActor
    private func loadNotes() async {
        loadingNotes = true
        notesError = nil
        do {
            notes = try await repository.notes(for: selection)
        } catch is CancellationError {
        } catch {
            notesError = TorahStrings.text("Could not load notes", locale: locale)
        }
        loadingNotes = false
    }

    @MainActor
    private func refreshNotes() async {
        repository.invalidateNotes(for: selection)
        await loadNotes()
    }

    private func notesDidChange() {
        Task { @MainActor in
            repository.invalidateNotes(for: selection)
            await loadNotes()
        }
    }

    @MainActor
    private func loadRelatedDocuments() async {
        loadingRelatedDocuments = true
        relatedDocumentsError = nil
        do {
            relatedDocuments = try await repository.relatedDocuments(for: selection)
        } catch is CancellationError {
        } catch {
            relatedDocumentsError = TorahStrings.text("Could not load related documents", locale: locale)
        }
        loadingRelatedDocuments = false
    }

    private func relatedDocumentsDidChange() {
        Task { @MainActor in
            repository.invalidateRelatedDocuments(for: selection)
            await loadRelatedDocuments()
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

private struct TorahSelectorScrollObserver: ViewModifier {
    @Binding var state: TorahToolSelectorStateMachine

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
        }
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
