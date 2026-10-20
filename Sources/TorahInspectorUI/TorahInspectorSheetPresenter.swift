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
    @Binding private var selectedTool: TorahStudyToolID
    @Binding private var selectedDetent: TorahInspectorSheetDetent

    private let repository: TorahInspectorRepository
    private let entryMode: TorahInspectorEntryMode
    private let configuration: TorahInspectorConfiguration
    private let actions: TorahInspectorHostActions

    @Environment(\.layoutDirection) private var layoutDirection

    public init(
        selection: Binding<TorahInspectorSelection?>,
        repository: TorahInspectorRepository,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        selectedTool: Binding<TorahStudyToolID>,
        selectedDetent: Binding<TorahInspectorSheetDetent>,
        configuration: TorahInspectorConfiguration = .legacy,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) {
        self._selection = selection
        self.repository = repository
        self.entryMode = entryMode
        self._selectedTool = selectedTool
        self._selectedDetent = selectedDetent
        self.configuration = configuration
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
                configuration: configuration,
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
        let toolID = Binding<TorahStudyToolID>(
            get: { selectedTool.wrappedValue.toolID },
            set: { value in
                if let legacy = TorahStudyTool(rawValue: value.rawValue) {
                    selectedTool.wrappedValue = legacy
                }
            }
        )
        modifier(TorahInspectorSheetPresenter(
            selection: selection,
            repository: repository,
            entryMode: entryMode,
            selectedTool: toolID,
            selectedDetent: selectedDetent,
            configuration: .legacy,
            actions: actions
        ))
    }


    func torahInspectorSheet(
        selection: Binding<TorahInspectorSelection?>,
        repository: TorahInspectorRepository,
        entryMode: TorahInspectorEntryMode = .sourceReader,
        selectedTool: Binding<TorahStudyToolID>,
        selectedDetent: Binding<TorahInspectorSheetDetent>,
        configuration: TorahInspectorConfiguration,
        actions: TorahInspectorHostActions = TorahInspectorHostActions()
    ) -> some View {
        modifier(TorahInspectorSheetPresenter(
            selection: selection,
            repository: repository,
            entryMode: entryMode,
            selectedTool: selectedTool,
            selectedDetent: selectedDetent,
            configuration: configuration,
            actions: actions
        ))
    }
}

private struct TorahInspectorSheetContent: View {
    let selection: TorahInspectorSelection
    let repository: TorahInspectorRepository
    let entryMode: TorahInspectorEntryMode
    @Binding var selectedTool: TorahStudyToolID
    @Binding var selectedDetent: TorahInspectorSheetDetent
    let configuration: TorahInspectorConfiguration
    let actions: TorahInspectorHostActions
    @State private var hasExpanded = false

    var body: some View {
        ZStack {
            if hasExpanded || selectedDetent != .peek {
                TorahInspectorView(
                repository: repository,
                selection: selection,
                entryMode: entryMode,
                chrome: .embeddedSheet,
                selectedTool: $selectedTool,
                configuration: configuration,
                actions: actions
            )
                .opacity(selectedDetent == .peek ? 0 : 1)
                .allowsHitTesting(selectedDetent != .peek)
                .accessibilityHidden(selectedDetent == .peek)
            }

            if selectedDetent == .peek {
                TorahInspectorSheetPeekView(
                    selection: selection,
                    selectedTool: $selectedTool,
                    selectedDetent: $selectedDetent,
                    configuration: configuration,
                    actions: actions
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("torah-inspector-sheet-\(selectedDetent.rawValue)")
        .onChange(of: selectedDetent) { _, detent in
            if detent != .peek { hasExpanded = true }
        }
    }
}

private struct TorahInspectorSheetPeekView: View {
    let selection: TorahInspectorSelection
    @Binding var selectedTool: TorahStudyToolID
    @Binding var selectedDetent: TorahInspectorSheetDetent
    let configuration: TorahInspectorConfiguration
    let actions: TorahInspectorHostActions
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                configuration.theme.text(selection.relationshipRef, role: .heading)
                    .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    selectedDetent = .medium
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TorahStrings.text("Expand", locale: locale))
                .accessibilityIdentifier("torah-inspector-expand-medium")

                if let onClose = actions.onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TorahStrings.text("Close", locale: locale))
                    .accessibilityIdentifier("torah-inspector-peek-close")
                }
            }

            Picker(TorahStrings.text("Study Tools", locale: locale), selection: $selectedTool) {
                ForEach(configuration.availableTools) { tool in
                    Text(tool.localizedTitle(locale: locale)).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTool) { _, _ in selectedDetent = .medium }
            .accessibilityIdentifier("torah-inspector-peek-tools")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            if !configuration.availableTools.contains(selectedTool),
               let first = configuration.availableTools.first {
                selectedTool = first
            }
        }
        .accessibilityIdentifier("torah-inspector-peek")
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
