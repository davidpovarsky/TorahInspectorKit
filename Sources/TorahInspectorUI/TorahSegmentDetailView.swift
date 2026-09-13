import Foundation
import SwiftUI
import TorahInspectorCore

public struct TorahSegmentDetailView: View {
    public let segment: TorahTextSegment
    public let providerID: String
    public let repository: TorahInspectorRepository
    public let actions: TorahInspectorHostActions

    @State private var links: [TorahLinkedSource] = []
    @State private var topics: [TorahLinkedTopic] = []
    @State private var linksError: String?
    @State private var topicsError: String?
    @State private var loadingLinks = true
    @State private var loadingTopics = true
    @Environment(\.locale) private var locale

    public init(
        segment: TorahTextSegment,
        providerID: String,
        repository: TorahInspectorRepository,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.segment = segment
        self.providerID = providerID
        self.repository = repository
        self.actions = actions
    }

    private var transferPayload: TorahSourceTransfer {
        TorahSourceTransfer(
            providerID: providerID,
            canonicalRef: segment.canonicalRef,
            hebrewRef: segment.hebrewRef,
            text: segment.text
        )
    }

    public var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text(segment.text)
                        .font(.body)
                        .environment(\.layoutDirection, segmentLayoutDirection)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 12) {
                        if let onInsertSegment = actions.onInsertSegment {
                            Button { onInsertSegment(transferPayload) } label: {
                                Label(TorahStrings.insertIntoDocument, systemImage: "arrow.down.doc")
                                    .font(.subheadline.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Button { TorahPlatformClipboard.copy(segment.text) } label: {
                            Label(TorahStrings.copy, systemImage: "doc.on.doc").font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: {
                Text(segmentDisplayRef).font(.headline)
            }

            relationshipSection(title: TorahStrings.text("Commentary"), values: groups.commentary)
            relationshipSection(title: TorahStrings.text("Linked sources"), values: groups.linkedSources)

            Section(TorahStrings.text("Topics")) {
                if loadingTopics {
                    ProgressView()
                } else if let topicsError {
                    retryRow(topicsError) { loadTopics() }
                } else if topics.isEmpty {
                    Text(TorahStrings.text("No results")).foregroundStyle(.secondary)
                } else {
                    ForEach(topics) { topic in
                        HStack {
                            Image(systemName: TorahInspectorAppearance.topicSymbol).foregroundStyle(.purple)
                            Text(TorahInspectorPresentation.topicTitle(topic, locale: locale))
                        }
                    }
                }
            }
        }
        .navigationTitle(segmentDisplayRef)
        .torahInlineNavigationTitle()
        .toolbar {
            if let onOpenInNewTab = actions.onOpenInNewTab {
                ToolbarItem {
                    Button {
                        onOpenInNewTab(.init(providerID: providerID, canonicalRef: segment.canonicalRef, preferredSegmentRef: segment.canonicalRef))
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .accessibilityLabel(TorahStrings.openInNewTab)
                }
            }
            if let onClose = actions.onClose {
                ToolbarItem {
                    Button(action: onClose) { Image(systemName: "xmark").foregroundStyle(.secondary) }
                        .accessibilityLabel(TorahStrings.close)
                }
            }
        }
        .task { loadLinks(); loadTopics() }
    }

    private var groups: TorahRelationshipGroups { TorahRelationshipGroups(sources: links) }

    private var segmentDisplayRef: String {
        TorahInspectorPresentation.reference(
            canonical: segment.canonicalRef,
            hebrew: segment.hebrewRef,
            locale: locale
        )
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

    @ViewBuilder
    private func relationshipSection(title: String, values: [TorahLinkedSource]) -> some View {
        Section(title) {
            if loadingLinks {
                ProgressView()
            } else if let linksError {
                retryRow(linksError) { loadLinks() }
            } else if values.isEmpty {
                Text(TorahStrings.text("No results")).foregroundStyle(.secondary)
            } else {
                ForEach(values) { value in
                    let selection = TorahInspectorSelection(providerID: providerID, canonicalRef: value.sourceRef)
                    NavigationLink(value: TorahInspectorRoute.source(selection)) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: TorahInspectorAppearance.referenceSymbol).foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(TorahInspectorPresentation.reference(
                                    canonical: value.sourceRef,
                                    hebrew: value.sourceHebrewRef,
                                    locale: locale
                                )).font(.body)
                                Text(value.category).font(.caption).foregroundStyle(.secondary)
                                if let text = TorahInspectorPresentation.linkedText(value, locale: locale) {
                                    Text(text).font(.caption).lineLimit(3).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .contextMenu {
                        if let onOpenInNewTab = actions.onOpenInNewTab {
                            Button { onOpenInNewTab(selection) } label: {
                                Label(TorahStrings.openInNewTab, systemImage: "plus.square.on.square")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func retryRow(_ message: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message).font(.caption).foregroundStyle(.secondary)
            Button(TorahStrings.retry, action: action)
        }
    }

    private func loadLinks() {
        loadingLinks = true
        linksError = nil
        Task {
            do {
                links = try await repository.links(for: segment.canonicalRef, providerID: providerID)
                loadingLinks = false
            } catch is CancellationError {
            } catch {
                linksError = TorahStrings.couldNotLoadRelatedSources
                loadingLinks = false
            }
        }
    }

    private func loadTopics() {
        loadingTopics = true
        topicsError = nil
        Task {
            do {
                topics = try await repository.topics(for: segment.canonicalRef, providerID: providerID)
                loadingTopics = false
            } catch is CancellationError {
            } catch {
                topicsError = TorahStrings.couldNotLoadRelatedSources
                loadingTopics = false
            }
        }
    }
}
