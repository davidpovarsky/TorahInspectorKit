import SwiftUI
import TorahInspectorCore

public enum TorahInspectorSheetDetent: String, CaseIterable, Identifiable, Sendable {
    case peek
    case medium
    case large

    public var id: Self { self }

    var presentationDetent: PresentationDetent {
        switch self {
        case .peek: .height(155)
        case .medium: .medium
        case .large: .large
        }
    }

    init(presentationDetent: PresentationDetent) {
        if presentationDetent == .height(155) {
            self = .peek
        } else if presentationDetent == .large {
            self = .large
        } else {
            self = .medium
        }
    }
}

public struct TorahInspectorSheetPresenter: ViewModifier {
    @Binding private var selection: TorahInspectorSelection?
    @Binding private var selectedTool: TorahStudyTool
    @Binding private var selectedDetent: TorahInspectorSheetDetent

    private let repository: TorahInspectorRepository
    private let entryMode: TorahInspectorEntryMode
    private let actions: TorahInspectorHostActions

    @Environment(\.layoutDirection) private var layoutDirection

    public init(
        selection: Binding<TorahInspectorSelection?>,
        repository: TorahInspectorRepository,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        selectedTool: Binding<TorahStudyTool>,
        selectedDetent: Binding<TorahInspectorSheetDetent>,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self._selection = selection
        self.repository = repository
        self.entryMode = entryMode
        self._selectedTool = selectedTool
        self._selectedDetent = selectedDetent
        self.actions = actions
    }

    public func body(content: Content) -> some View {
        content.sheet(item: $selection, onDismiss: actions.onClose) { presentedSelection in
            TorahInspectorSheetContent(
                selection: presentedSelection,
                repository: repository,
                entryMode: entryMode,
                selectedTool: $selectedTool,
                selectedDetent: $selectedDetent,
                actions: presentedActions
            )
            .presentationDetents(
                [.height(155), .medium, .large],
                selection: presentationDetent
            )
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .modifier(TorahInspectorNativeSheetPlacement(layoutDirection: layoutDirection))
        }
    }

    private var presentationDetent: Binding<PresentationDetent> {
        Binding(
            get: { selectedDetent.presentationDetent },
            set: { selectedDetent = TorahInspectorSheetDetent(presentationDetent: $0) }
        )
    }

    private var presentedActions: TorahInspectorHostActions {
        var presentedActions = actions
        presentedActions.onClose = { selection = nil }
        presentedActions.showsCloseButton = true
        return presentedActions
    }
}

public extension View {
    func torahInspectorSheet(
        selection: Binding<TorahInspectorSelection?>,
        repository: TorahInspectorRepository,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        selectedTool: Binding<TorahStudyTool>,
        selectedDetent: Binding<TorahInspectorSheetDetent>,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) -> some View {
        modifier(TorahInspectorSheetPresenter(
            selection: selection,
            repository: repository,
            entryMode: entryMode,
            selectedTool: selectedTool,
            selectedDetent: selectedDetent,
            actions: actions
        ))
    }
}

private struct TorahInspectorSheetContent: View {
    let selection: TorahInspectorSelection
    let repository: TorahInspectorRepository
    let entryMode: TorahInspectorEntryMode
    @Binding var selectedTool: TorahStudyTool
    @Binding var selectedDetent: TorahInspectorSheetDetent
    let actions: TorahInspectorHostActions

    var body: some View {
        ZStack {
            TorahInspectorView(
                repository: repository,
                selection: selection,
                entryMode: entryMode,
                chrome: .embeddedSheet,
                selectedTool: $selectedTool,
                actions: actions
            )
            .opacity(selectedDetent == .peek ? 0 : 1)
            .allowsHitTesting(selectedDetent != .peek)
            .accessibilityHidden(selectedDetent == .peek)

            if selectedDetent == .peek {
                TorahInspectorSheetPeekView(
                    selection: selection,
                    repository: repository,
                    selectedDetent: $selectedDetent,
                    actions: actions
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("torah-inspector-sheet-\(selectedDetent.rawValue)")
    }
}

private struct TorahInspectorSheetPeekView: View {
    let selection: TorahInspectorSelection
    let repository: TorahInspectorRepository
    @Binding var selectedDetent: TorahInspectorSheetDetent
    let actions: TorahInspectorHostActions

    @State private var document: TorahTextDocument?
    @State private var errorMessage: String?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayReference)
                        .font(.headline)
                        .lineLimit(1)
                    peekBody
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    selectedDetent = .medium
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TorahStrings.text("Expand", locale: locale))
                .accessibilityIdentifier("torah-inspector-expand-medium")

                if let onClose = actions.onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TorahStrings.text("Close", locale: locale))
                    .accessibilityIdentifier("torah-inspector-peek-close")
                }
            }

            if let transfer, let onInsertSegment = actions.onInsertSegment {
                Button {
                    onInsertSegment(transfer)
                } label: {
                    Label(TorahStrings.text("Insert into document", locale: locale), systemImage: "arrow.down.doc")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("torah-inspector-peek-insert")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .task(id: selection.id) { await load() }
        .accessibilityIdentifier("torah-inspector-peek")
    }

    @ViewBuilder
    private var peekBody: some View {
        if let errorMessage {
            Button(TorahStrings.text("Retry", locale: locale)) { Task { await load() } }
                .font(.caption)
                .accessibilityHint(errorMessage)
        } else if let segment {
            Text(segment.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .environment(\.layoutDirection, textLayoutDirection)
        } else {
            ProgressView()
                .controlSize(.small)
        }
    }

    private var segment: TorahTextSegment? {
        guard let document else { return nil }
        return TorahInspectorSheetPeekResolver.segment(in: document, selection: selection)
    }

    private var displayReference: String {
        guard let document else { return selection.relationshipRef }
        let resolvedSegment = segment
        return TorahInspectorPresentation.reference(
            canonical: resolvedSegment?.canonicalRef ?? document.sectionRef,
            hebrew: resolvedSegment?.hebrewRef ?? document.hebrewSectionRef,
            locale: locale
        )
    }

    private var textLayoutDirection: LayoutDirection {
        document?.version.direction == "rtl" ? .rightToLeft : .leftToRight
    }

    private var transfer: TorahSourceTransfer? {
        guard let document, let segment else { return nil }
        return TorahSourceTransfer(segment: segment, document: document)
    }

    @MainActor
    private func load() async {
        document = nil
        errorMessage = nil
        do {
            document = try await repository.document(
                for: selection.canonicalRef,
                providerID: selection.providerID
            )
        } catch is CancellationError {
        } catch {
            errorMessage = TorahStrings.message(for: error, locale: locale)
        }
    }
}

enum TorahInspectorSheetPeekResolver {
    static func segment(
        in document: TorahTextDocument,
        selection: TorahInspectorSelection
    ) -> TorahTextSegment? {
        if let preferredSegmentRef = selection.preferredSegmentRef {
            return document.segments.first { $0.canonicalRef == preferredSegmentRef }
        }
        return document.segments.first
    }
}

enum TorahInspectorSheetPhysicalEdge: Equatable {
    case leading
    case trailing
}

enum TorahInspectorSheetPlacementResolver {
    static func physicalRightEdge(for layoutDirection: LayoutDirection) -> TorahInspectorSheetPhysicalEdge {
        // iPadOS 27's presentationPlacement edges are physical in the native
        // side-sheet presentation. Simulator evidence in Hebrew RTL confirms
        // that `.leading` is left and `.trailing` is right.
        _ = layoutDirection
        return .trailing
    }
}

private struct TorahInspectorNativeSheetPlacement: ViewModifier {
    let layoutDirection: LayoutDirection

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS) && compiler(>=6.3)
        if #available(iOS 27.0, *) {
            switch TorahInspectorSheetPlacementResolver.physicalRightEdge(for: layoutDirection) {
            case .leading:
                content.presentationPlacement(.leading)
            case .trailing:
                content.presentationPlacement(.trailing)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
