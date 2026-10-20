import SwiftUI
import TorahInspectorCore

public struct TorahSegmentPreviewCard: View {
    public let segment: TorahTextSegment
    public let section: TorahTextDocument
    @Environment(\.locale) private var locale

    public init(segment: TorahTextSegment, section: TorahTextDocument) {
        self.segment = segment
        self.section = section
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TorahInspectorPresentation.reference(
                canonical: segment.canonicalRef,
                hebrew: segment.hebrewRef,
                locale: locale
            ))
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
        .environment(\.layoutDirection, TorahInspectorPresentation.layoutDirection(for: text))
    }
}

private struct ScrollOffsetInfo: Equatable {
    let offsetY: CGFloat
    let contentHeight: CGFloat
    let containerHeight: CGFloat
}

private struct SegmentFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

public struct TorahSourceReaderView: View {
    public let selection: TorahInspectorSelection
    public let repository: TorahInspectorRepository
    public let actions: TorahInspectorHostActions
    public let session: TorahReaderSessionState

    @State private var sections: [TorahTextDocument] = []
    @State private var isLoading = false
    @State private var loadingPrevious = false
    @State private var loadingNext = false
    @State private var errorMessage: String?
    @State private var stateMachine = TorahReaderScrollStateMachine()
    @Environment(\.locale) private var locale
    @State private var viewportHeight: CGFloat = 1
    @State private var pendingViewport: TorahReaderViewport?

    private static let maximumSectionWindow = 7

    public init(
        selection: TorahInspectorSelection,
        repository: TorahInspectorRepository,
        actions: TorahInspectorHostActions = TorahInspectorHostActions(),
        session: TorahReaderSessionState = TorahReaderSessionState()
    ) {
        self.selection = selection
        self.repository = repository
        self.actions = actions
        self.session = session
    }

    public var body: some View {
        Group {
            if isLoading && sections.isEmpty {
                ProgressView()
            } else if let error = errorMessage, sections.isEmpty {
                ContentUnavailableView {
                    Label(TorahStrings.text("No text available", locale: locale), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button(TorahStrings.text("Retry", locale: locale)) { Task { await initialLoad() } }
                }
            } else {
                readerContent
            }
        }
        .navigationTitle(displayTitle)
        .torahInlineNavigationTitle()
        .toolbar {
            if let onClose = actions.onClose {
                ToolbarItem {
                    Button(action: onClose) { Image(systemName: "xmark").foregroundStyle(.secondary) }
                        .accessibilityLabel(TorahStrings.text("Close", locale: locale))
                }
            }
        }
        .task(id: selection.id) { await initialLoad() }
    }

    private var displayTitle: String {
        guard let section = sections.first else { return selection.canonicalRef }
        return TorahInspectorPresentation.reference(
            canonical: section.sectionRef,
            hebrew: section.hebrewSectionRef,
            locale: locale
        )
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
                        viewportHeight = max(newValue.containerHeight, 1)
                        handleScrollChange(newValue, proxy: proxy)
                    }
                    .onPreferenceChange(SegmentFramePreferenceKey.self) { frames in
                        recordViewport(from: frames)
                    }
                    .task(id: pendingViewport) { await restorePendingViewport(proxy: proxy) }
            } else {
                readerScrollView
                    .onPreferenceChange(SegmentFramePreferenceKey.self) { frames in
                        recordViewport(from: frames)
                    }
                    .task(id: pendingViewport) { await restorePendingViewport(proxy: proxy) }
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
                        Text(TorahInspectorPresentation.reference(
                            canonical: section.sectionRef,
                            hebrew: section.hebrewSectionRef,
                            locale: locale
                        ))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                if loadingNext { ProgressView().frame(maxWidth: .infinity) }
            }
            .padding()
        }
        .coordinateSpace(name: "torah-reader-viewport")
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
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SegmentFramePreferenceKey.self,
                    value: [segment.id: geometry.frame(in: .named("torah-reader-viewport"))]
                )
            }
        }
        .environment(\.layoutDirection, section.version.direction == "rtl" ? .rightToLeft : .leftToRight)
        .contextMenu {
            if let onInsertSegment = actions.onInsertSegment {
                Button { onInsertSegment(transfer) } label: {
                    Label(TorahStrings.text("Insert into document", locale: locale), systemImage: "arrow.down.doc")
                }
            }
            Button { TorahPlatformClipboard.copy(segment.text) } label: {
                Label(TorahStrings.text("Copy", locale: locale), systemImage: "doc.on.doc")
            }
            NavigationLink(value: TorahInspectorRoute.segment(segment)) {
                Label(TorahStrings.text("View details", locale: locale), systemImage: "info.circle")
            }
        } preview: {
            TorahSegmentPreviewCard(segment: segment, section: section)
        }
        .draggable(transfer) {
            TorahDragPreview(
                title: TorahInspectorPresentation.reference(
                    canonical: segment.canonicalRef,
                    hebrew: segment.hebrewRef,
                    locale: locale
                ),
                text: segment.text
            )
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
            if let snapshot = session.snapshot(for: selection) {
                sections = snapshot.sections
                pendingViewport = snapshot.viewport
                _ = stateMachine.onInitialLoadComplete(
                    hasPrevious: sections.first?.previousSectionRef != nil,
                    hasNext: sections.last?.nextSectionRef != nil,
                    isUnderfilled: false
                )
                return
            }
            let document = try await repository.document(for: selection.canonicalRef, providerID: selection.providerID)
            sections = [document]
            if let preferred = selection.preferredSegmentRef {
                pendingViewport = TorahReaderViewport(
                    providerID: selection.providerID,
                    sectionReference: document.sectionRef,
                    segmentReference: preferred,
                    relativePosition: 0.18,
                    loadedSectionReferences: [document.sectionRef]
                )
            }
            let decision = stateMachine.onInitialLoadComplete(
                hasPrevious: document.previousSectionRef != nil,
                hasNext: document.nextSectionRef != nil,
                isUnderfilled: document.segments.count <= 2
            )
            if decision.shouldLoadNext { await loadNext() }
        } catch is CancellationError {
        } catch {
            errorMessage = TorahStrings.message(for: error, locale: locale)
        }
    }

    private func loadPrevious(proxy: ScrollViewProxy) async {
        guard !loadingPrevious, let reference = sections.first?.previousSectionRef else { return }
        loadingPrevious = true
        defer { loadingPrevious = false }
        let anchorViewport = currentViewportSnapshot()
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
            if let anchorViewport {
                pendingViewport = anchorViewport
                await restorePendingViewport(proxy: proxy)
            } else {
                stateMachine.onAnchorRestorationCompleted()
            }
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

    private func recordViewport(from frames: [String: CGRect]) {
        guard !stateMachine.isRestoringAnchor,
              let visible = frames
                .filter({ $0.value.maxY > 0 && $0.value.minY < viewportHeight })
                .min(by: { abs($0.value.minY) < abs($1.value.minY) }),
              let section = sections.first(where: { section in
                  section.segments.contains(where: { $0.id == visible.key })
              }) else { return }
        let relative = Double(min(max(visible.value.minY / max(viewportHeight, 1), 0), 1))
        let viewport = TorahReaderViewport(
            providerID: selection.providerID,
            sectionReference: section.sectionRef,
            segmentReference: visible.key,
            relativePosition: relative,
            loadedSectionReferences: sections.map(\.sectionRef)
        )
        pendingViewport = nil
        session.save(selection: selection, sections: sections, viewport: viewport)
    }

    private func currentViewportSnapshot() -> TorahReaderViewport? {
        session.snapshot(for: selection)?.viewport
            ?? selection.preferredSegmentRef.map {
                TorahReaderViewport(
                    providerID: selection.providerID,
                    sectionReference: sections.first?.sectionRef ?? selection.canonicalRef,
                    segmentReference: $0,
                    relativePosition: 0.18,
                    loadedSectionReferences: sections.map(\.sectionRef)
                )
            }
    }

    private func restorePendingViewport(proxy: ScrollViewProxy) async {
        guard let viewport = pendingViewport,
              sections.contains(where: { section in
                  section.segments.contains(where: { $0.id == viewport.segmentReference })
              }) else { return }
        await Task.yield()
        proxy.scrollTo(
            viewport.segmentReference,
            anchor: UnitPoint(x: 0.5, y: viewport.relativePosition)
        )
        pendingViewport = nil
        stateMachine.onAnchorRestorationCompleted()
        let restoredViewport = TorahReaderViewport(
            providerID: viewport.providerID,
            sectionReference: viewport.sectionReference,
            segmentReference: viewport.segmentReference,
            relativePosition: viewport.relativePosition,
            loadedSectionReferences: sections.map(\.sectionRef)
        )
        session.save(selection: selection, sections: sections, viewport: restoredViewport)
    }
}
