import Foundation
import SwiftUI
import TorahInspectorCore

public struct TorahSegmentDetailView: View {
    public let focus: TorahInspectorFocus
    public let repository: TorahInspectorRepository
    public let actions: TorahInspectorHostActions
    public let chrome: TorahInspectorChrome
    @Binding private var selectedTool: TorahStudyTool

    @State private var links: [TorahLinkedSource] = []
    @State private var topics: [TorahLinkedTopic] = []
    @State private var notes: [TorahInspectorNote] = []
    @State private var linksError: String?
    @State private var topicsError: String?
    @State private var notesError: String?
    @State private var loadingLinks = true
    @State private var loadingTopics = true
    @State private var loadingNotes = true
    @State private var expandedSourceIDs: Set<TorahLinkedSource.ID> = []
    @State private var expandedSourceText: [TorahLinkedSource.ID: String] = [:]
    @State private var expandedSourceErrors: [TorahLinkedSource.ID: String] = [:]
    @State private var loadingSourceIDs: Set<TorahLinkedSource.ID> = []
    @State private var expandedCommentaryGroupIDs: Set<TorahSourceGroup.ID> = []
    @Environment(\.locale) private var locale

    public init(
        focus: TorahInspectorFocus,
        repository: TorahInspectorRepository,
        selectedTool: Binding<TorahStudyTool> = .constant(.commentaries),
        chrome: TorahInspectorChrome = .floatingPanel,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.focus = focus
        self.repository = repository
        self._selectedTool = selectedTool
        self.chrome = chrome
        self.actions = actions
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

    private var selection: TorahInspectorSelection { focus.selection }
    private var providerID: String { selection.providerID }

    private var groups: TorahRelationshipGroups { TorahRelationshipGroups(sources: links) }

    @ViewBuilder
    public var body: some View {
        switch chrome {
        case .embeddedSheet:
            panelContent
                .background(.regularMaterial)
        case .floatingPanel:
            panelContent
                .background(.regularMaterial)
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
    }

    private var panelHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TorahStrings.studyTools)
                        .font(.title3.weight(.semibold))
                    Text(segmentDisplayRef)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if actions.showsCloseButton, let onClose = actions.onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TorahStrings.close)
                    .accessibilityIdentifier("torah-inspector-close")
                }
            }

            selectedSegmentCard

            Picker(TorahStrings.studyTools, selection: $selectedTool) {
                ForEach(TorahStudyTool.allCases) { tool in
                    Text(tool.localizedTitle).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("torah-inspector-tools")
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
                }
            }
            .padding(14)
        }
    }

    private var selectedSegmentCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(TorahStrings.selectedSegment)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let text = focus.text, !text.isEmpty {
                Text(text)
                    .font(.subheadline)
                    .lineLimit(2)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(segmentDisplayRef)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .environment(\.layoutDirection, segmentLayoutDirection)
        .padding(12)
        .background(Color.accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("torah-inspector-selected-segment")
    }

    @ViewBuilder
    private var commentariesContent: some View {
        if loadingLinks {
            loadingRow
        } else if let linksError {
            retryCard(linksError) { Task { await loadLinks() } }
        } else if groups.commentaryGroups.isEmpty {
            emptyRow(TorahStrings.text("No results"))
        } else {
            ForEach(groups.commentaryGroups) { group in
                commentaryGroupCard(group)
                    .accessibilityIdentifier("torah-inspector-commentary-group-\(group.id)")
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
                ForEach(group.entries) { source in
                    expandableSourceRow(source, commentary: true)
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

    private func commentaryCard(_ source: TorahLinkedSource) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayReference(source))
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                expansionIndicator(source)
            }
            if let text = TorahInspectorPresentation.linkedText(source, locale: locale) {
                Text(text)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(TorahInspectorPresentation.categoryTitle(source.semanticCategory, locale: locale))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(13)
        .background(expandedSourceIDs.contains(source.id) ? Color.accentColor.opacity(0.08) : .torahSecondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var linksContent: some View {
        if loadingLinks {
            loadingRow
        } else if let linksError {
            retryCard(linksError) { Task { await loadLinks() } }
        } else if groups.linkedSources.isEmpty && topics.isEmpty && !loadingTopics {
            emptyRow(TorahStrings.text("No results"))
        } else {
            ForEach(groups.linkedSources) { source in
                expandableSourceRow(source, commentary: false)
            }
            topicsContent
        }
    }

    private func linkedSourceCard(_ source: TorahLinkedSource) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: TorahInspectorAppearance.referenceSymbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(displayReference(source))
                    .font(.subheadline.weight(.semibold))
                Text(TorahInspectorPresentation.categoryTitle(source.semanticCategory, locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let text = TorahInspectorPresentation.linkedText(source, locale: locale) {
                    Text(text)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 6)
            expansionIndicator(source)
        }
        .padding(13)
        .background(Color.torahSecondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func expansionIndicator(_ source: TorahLinkedSource) -> some View {
        Image(systemName: expandedSourceIDs.contains(source.id) ? "chevron.up" : "chevron.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
    }

    private func expandableSourceRow(_ source: TorahLinkedSource, commentary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                            openInReader(source)
                        case .second:
                            toggleExpansion(source)
                        }
                    }
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("torah-inspector-source-\(source.id)")
            .accessibilityAction { toggleExpansion(source) }
            .accessibilityAction(named: Text(TorahStrings.openInNewTab)) {
                openInReader(source)
            }

            if expandedSourceIDs.contains(source.id) {
                expandedSourceContent(source)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.torahSecondarySystemBackground.opacity(0.72))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("torah-inspector-source-expanded-\(source.id)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func expandedSourceContent(_ source: TorahLinkedSource) -> some View {
        if loadingSourceIDs.contains(source.id) {
            ProgressView().frame(maxWidth: .infinity)
        } else if let message = expandedSourceErrors[source.id] {
            retryCard(message) { Task { await loadFullSource(source) } }
        } else if let text = expandedSourceText[source.id] {
            Text(text)
                .font(.body)
                .lineSpacing(5)
                .textSelection(.enabled)
                .environment(\.layoutDirection, layoutDirection(for: text))
        }
    }

    private func toggleExpansion(_ source: TorahLinkedSource) {
        if expandedSourceIDs.remove(source.id) != nil { return }
        expandedSourceIDs.insert(source.id)
        guard expandedSourceText[source.id] == nil,
              !loadingSourceIDs.contains(source.id) else { return }
        Task { await loadFullSource(source) }
    }

    private func openInReader(_ source: TorahLinkedSource) {
        actions.onOpenInNewTab?(
            TorahInspectorSelection(
                providerID: providerID,
                canonicalRef: source.sourceRef,
                preferredSegmentRef: source.sourceRef,
                scope: .segment
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
            expandedSourceErrors[source.id] = TorahStrings.message(for: error)
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
                Text(TorahStrings.text("Topics"))
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
        if loadingNotes {
            loadingRow
        } else if let notesError {
            retryCard(notesError) { Task { await refreshNotes() } }
        } else if notes.isEmpty {
            emptyRow(TorahStrings.text("No notes"))
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
                    .contextMenu {
                        if let onDeleteNote = actions.onDeleteNote {
                            Button(role: .destructive) {
                                onDeleteNote(note, selection, notesDidChange)
                            } label: {
                                Label(TorahStrings.text("Delete"), systemImage: "trash")
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

        if let onAddNote = actions.onAddNote {
            Button {
                onAddNote(selection, notesDidChange)
            } label: {
                Label(TorahStrings.addNote, systemImage: "plus")
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
            Button(TorahStrings.retry, action: action)
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
        _ = await (loadedLinks, loadedTopics, loadedNotes)
    }

    @MainActor
    private func loadLinks() async {
        loadingLinks = true
        linksError = nil
        do {
            links = try await repository.links(for: selection.relationshipRef, providerID: providerID)
        } catch is CancellationError {
        } catch {
            linksError = TorahStrings.couldNotLoadRelatedSources
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
            topicsError = TorahStrings.couldNotLoadRelatedSources
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
            notesError = TorahStrings.text("Could not load notes")
        }
        loadingNotes = false
    }

    @MainActor
    private func refreshNotes() async {
        repository.invalidateNotes(for: selection)
        await loadNotes()
    }

    private func notesDidChange() {
        Task { await refreshNotes() }
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
