import Foundation
import SwiftUI
import TorahInspectorCore

public struct TorahSegmentDetailView: View {
    public let segment: TorahTextSegment
    public let providerID: String
    public let repository: TorahInspectorRepository
    public let actions: TorahInspectorHostActions
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
    @State private var selectedCommentaryID: TorahLinkedSource.ID?
    @Environment(\.locale) private var locale

    public init(
        segment: TorahTextSegment,
        providerID: String,
        repository: TorahInspectorRepository,
        selectedTool: Binding<TorahStudyTool> = .constant(.commentaries),
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.segment = segment
        self.providerID = providerID
        self.repository = repository
        self._selectedTool = selectedTool
        self.actions = actions
    }

    private var selection: TorahInspectorSelection {
        TorahInspectorSelection(
            providerID: providerID,
            canonicalRef: segment.canonicalRef,
            preferredSegmentRef: segment.canonicalRef
        )
    }

    private var transferPayload: TorahSourceTransfer {
        TorahSourceTransfer(
            providerID: providerID,
            canonicalRef: segment.canonicalRef,
            hebrewRef: segment.hebrewRef,
            text: segment.text
        )
    }

    private var groups: TorahRelationshipGroups { TorahRelationshipGroups(sources: links) }

    public var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().opacity(0.45)
            toolContent
        }
        .background(.regularMaterial)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 7, x: 0, y: 2)
        .padding(8)
        .task(id: segment.id) { await loadPanelData() }
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
                if let onOpenInNewTab = actions.onOpenInNewTab {
                    Button {
                        onOpenInNewTab(selection)
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TorahStrings.openInNewTab)
                }
                if actions.showsCloseButton, let onClose = actions.onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TorahStrings.close)
                }
            }

            Picker(TorahStrings.studyTools, selection: $selectedTool) {
                ForEach(TorahStudyTool.allCases) { tool in
                    Text(tool.localizedTitle).tag(tool)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var toolContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                selectedSegmentCard
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
            Text(segment.text)
                .font(.subheadline)
                .lineLimit(2)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(segmentDisplayRef)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .environment(\.layoutDirection, segmentLayoutDirection)
        .padding(12)
        .background(Color.accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var commentariesContent: some View {
        if loadingLinks {
            loadingRow
        } else if let linksError {
            retryCard(linksError) { Task { await loadLinks() } }
        } else if groups.commentary.isEmpty {
            emptyRow(TorahStrings.text("No results"))
        } else {
            ForEach(groups.commentary) { source in
                let nextSelection = TorahInspectorSelection(providerID: providerID, canonicalRef: source.sourceRef)
                NavigationLink(value: TorahInspectorRoute.source(nextSelection)) {
                    commentaryCard(source)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { selectedCommentaryID = source.id })
                .contextMenu { sourceContextMenu(selection: nextSelection) }
            }
        }
    }

    private func commentaryCard(_ source: TorahLinkedSource) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(commentaryTitle(source))
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                if selectedCommentaryID == source.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            if let text = TorahInspectorPresentation.linkedText(source, locale: locale) {
                Text(text)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(displayReference(source))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(13)
        .background(selectedCommentaryID == source.id ? Color.accentColor.opacity(0.08) : .torahSecondarySystemBackground)
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
                let nextSelection = TorahInspectorSelection(providerID: providerID, canonicalRef: source.sourceRef)
                NavigationLink(value: TorahInspectorRoute.source(nextSelection)) {
                    linkedSourceCard(source)
                }
                .buttonStyle(.plain)
                .contextMenu { sourceContextMenu(selection: nextSelection) }
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
                Text(source.category)
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
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(13)
        .background(Color.torahSecondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    @ViewBuilder
    private func sourceContextMenu(selection: TorahInspectorSelection) -> some View {
        if let onOpenInNewTab = actions.onOpenInNewTab {
            Button { onOpenInNewTab(selection) } label: {
                Label(TorahStrings.openInNewTab, systemImage: "plus.square.on.square")
            }
        }
    }

    private var segmentDisplayRef: String {
        TorahInspectorPresentation.reference(canonical: segment.canonicalRef, hebrew: segment.hebrewRef, locale: locale)
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

    private var segmentLayoutDirection: LayoutDirection {
        for scalar in segment.text.unicodeScalars {
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
            links = try await repository.links(for: segment.canonicalRef, providerID: providerID)
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
            topics = try await repository.topics(for: segment.canonicalRef, providerID: providerID)
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
