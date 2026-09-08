import SwiftUI
import TorahInspectorCore

public struct TorahSegmentPreviewCard: View {
    public let segment: TorahTextSegment
    public let section: TorahTextDocument

    public init(segment: TorahTextSegment, section: TorahTextDocument) {
        self.segment = segment
        self.section = section
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(segment.hebrewRef ?? segment.canonicalRef)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(segment.text)
                .font(.body)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(width: 320, alignment: .leading)
        .environment(\.layoutDirection, section.version.direction == "rtl" ? .rightToLeft : .leftToRight)
    }
}

public struct TorahDragPreview: View {
    public let title: String
    public let text: String

    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            Text(text).font(.subheadline).lineLimit(2).multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 240, alignment: .leading)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct ScrollOffsetInfo: Equatable {
    let offsetY: CGFloat
    let contentHeight: CGFloat
    let containerHeight: CGFloat
}

public struct TorahSourceReaderView: View {
    public let selection: TorahInspectorSelection
    public let repository: TorahInspectorRepository
    public let actions: TorahInspectorHostActions

    @State private var sections: [TorahTextDocument] = []
    @State private var isLoading = false
    @State private var loadingPrevious = false
    @State private var loadingNext = false
    @State private var errorMessage: String?
    @State private var stateMachine = TorahReaderScrollStateMachine()

    private static let maximumSectionWindow = 7

    public init(
        selection: TorahInspectorSelection,
        repository: TorahInspectorRepository,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self.selection = selection
        self.repository = repository
        self.actions = actions
    }

    public var body: some View {
        Group {
            if isLoading && sections.isEmpty {
                ProgressView()
            } else if let error = errorMessage, sections.isEmpty {
                ContentUnavailableView {
                    Label(TorahStrings.text("No text available"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button(TorahStrings.retry) { Task { await initialLoad() } }
                }
            } else {
                readerContent
            }
        }
        .navigationTitle(displayTitle)
        .torahInlineNavigationTitle()
        .toolbar {
            if let onOpenInNewTab = actions.onOpenInNewTab {
                ToolbarItem {
                    Button { onOpenInNewTab(selection) } label: { Image(systemName: "plus.square.on.square") }
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
        .task(id: selection.id) { await initialLoad() }
    }

    private var displayTitle: String {
        sections.first?.hebrewSectionRef ?? sections.first?.sectionRef ?? selection.canonicalRef
    }

    @ViewBuilder
    private var readerContent: some View {
        ScrollViewReader { proxy in
            if #available(iOS 18.0, macOS 15.0, *) {
                readerScrollView
                    .onScrollGeometryChange(for: ScrollOffsetInfo.self) { geometry in
                        ScrollOffsetInfo(
                            offsetY: geometry.contentOffset.y,
                            contentHeight: geometry.contentSize.height,
                            containerHeight: geometry.containerSize.height
                        )
                    } action: { _, newValue in
                        handleScrollChange(newValue, proxy: proxy)
                    }
            } else {
                readerScrollView
            }
        }
    }

    private var readerScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if loadingPrevious { ProgressView().frame(maxWidth: .infinity) }
                ForEach(sections) { section in
                    Section {
                        ForEach(section.segments) { segment in
                            segmentRow(segment, in: section).id(segment.id)
                        }
                    } header: {
                        Text(section.hebrewSectionRef ?? section.sectionRef)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                if loadingNext { ProgressView().frame(maxWidth: .infinity) }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func segmentRow(_ segment: TorahTextSegment, in section: TorahTextDocument) -> some View {
        let transfer = TorahSourceTransfer(segment: segment, document: section)
        NavigationLink(value: TorahInspectorRoute.segment(segment)) {
            Text(segment.text)
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 7)
                .padding(.horizontal, 5)
                .background(
                    selection.prefers(segment) ? Color.accentColor.opacity(0.10) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, section.version.direction == "rtl" ? .rightToLeft : .leftToRight)
        .contextMenu {
            if let onInsertSegment = actions.onInsertSegment {
                Button { onInsertSegment(transfer) } label: {
                    Label(TorahStrings.insertIntoDocument, systemImage: "arrow.down.doc")
                }
            }
            Button { TorahPlatformClipboard.copy(segment.text) } label: {
                Label(TorahStrings.copy, systemImage: "doc.on.doc")
            }
            NavigationLink(value: TorahInspectorRoute.segment(segment)) {
                Label(TorahStrings.viewDetails, systemImage: "info.circle")
            }
        } preview: {
            TorahSegmentPreviewCard(segment: segment, section: section)
        }
        .draggable(transfer) {
            TorahDragPreview(title: segment.hebrewRef ?? segment.canonicalRef, text: segment.text)
        }
        .onDrag { transfer.itemProvider }
    }

    private func handleScrollChange(_ info: ScrollOffsetInfo, proxy: ScrollViewProxy) {
        let decision = stateMachine.onScrollOffsetChanged(
            offsetY: info.offsetY,
            contentHeight: info.contentHeight,
            containerHeight: info.containerHeight,
            hasPrevious: sections.first?.previousSectionRef != nil,
            hasNext: sections.last?.nextSectionRef != nil
        )
        if decision.shouldLoadPrevious { Task { await loadPrevious(proxy: proxy) } }
        if decision.shouldLoadNext { Task { await loadNext() } }
    }

    private func initialLoad() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let document = try await repository.document(for: selection.canonicalRef, providerID: selection.providerID)
            sections = [document]
            let decision = stateMachine.onInitialLoadComplete(
                hasPrevious: document.previousSectionRef != nil,
                hasNext: document.nextSectionRef != nil,
                isUnderfilled: document.segments.count <= 2
            )
            if decision.shouldLoadNext { await loadNext() }
        } catch is CancellationError {
        } catch {
            errorMessage = TorahStrings.message(for: error)
        }
    }

    private func loadPrevious(proxy: ScrollViewProxy) async {
        guard !loadingPrevious, let reference = sections.first?.previousSectionRef else { return }
        loadingPrevious = true
        defer { loadingPrevious = false }
        let anchorSegmentID = sections.first?.segments.first?.id
        do {
            let document = try await repository.document(for: reference, providerID: selection.providerID)
            guard !sections.contains(where: { $0.sectionRef == document.sectionRef }) else {
                stateMachine.onPreviousLoadCompleted()
                stateMachine.onAnchorRestorationCompleted()
                return
            }
            sections.insert(document, at: 0)
            trimFromEnd()
            stateMachine.onPreviousLoadCompleted()
            if let anchorSegmentID { proxy.scrollTo(anchorSegmentID, anchor: .top) }
            stateMachine.onAnchorRestorationCompleted()
        } catch {
            stateMachine.onPreviousLoadFailed()
        }
    }

    private func loadNext() async {
        guard !loadingNext, let reference = sections.last?.nextSectionRef else { return }
        loadingNext = true
        defer { loadingNext = false }
        do {
            let document = try await repository.document(for: reference, providerID: selection.providerID)
            guard !sections.contains(where: { $0.sectionRef == document.sectionRef }) else {
                stateMachine.onNextLoadCompleted()
                return
            }
            sections.append(document)
            trimFromStart()
            stateMachine.onNextLoadCompleted()
        } catch {
            stateMachine.onNextLoadFailed()
        }
    }

    private func trimFromEnd() {
        if sections.count > Self.maximumSectionWindow {
            sections.removeLast(sections.count - Self.maximumSectionWindow)
        }
    }

    private func trimFromStart() {
        if sections.count > Self.maximumSectionWindow {
            sections.removeFirst(sections.count - Self.maximumSectionWindow)
        }
    }
}
