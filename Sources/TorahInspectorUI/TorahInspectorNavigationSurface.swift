import Foundation
import SwiftUI
import TorahInspectorCore

/// Finite locations in the original relationship panel. A host may expose a
/// retained catalog entry; an unqualified string is not a catalog entry.
public enum TorahInspectorNavigationAnchor: Hashable, Sendable {
    case tool(TorahStudyToolID)
    case commentaryGroup(id: String, quoting: Bool)
    case source(id: String, groupID: String?, quoting: Bool)
    case note(id: String)
}

public struct TorahInspectorNavigationTarget: Identifiable, Equatable, Sendable {
    public var id: TorahInspectorNavigationAnchor { anchor }
    public let anchor: TorahInspectorNavigationAnchor
    public let title: String
    public let tool: TorahStudyToolID
    public let group: TorahSourceGroup?
    public let source: TorahLinkedSource?
    public let note: TorahInspectorNote?

    // Only the original view constructs targets from its actual loaded values.
    init(anchor: TorahInspectorNavigationAnchor, title: String,
         tool: TorahStudyToolID, group: TorahSourceGroup? = nil,
         source: TorahLinkedSource? = nil, note: TorahInspectorNote? = nil) {
        self.anchor = anchor
        self.title = title
        self.tool = tool
        self.group = group
        self.source = source
        self.note = note
    }
}

public enum TorahInspectorNavigationError: Error {
    case unavailable
    case staleSource
    case ambiguousTarget
    case alreadyApplied
}

/// Passive, non-Observable publication metadata. It owns no document, request,
/// repository, selection or loader and invokes no observer callbacks.
@MainActor
final class TorahInspectorNavigationLifetime {
    struct Revision: Equatable {
        let identity: UInt64?
        let tool: UInt64?
        let content: UInt64?
        let expansion: UInt64?

        var isAvailable: Bool {
            identity != nil && tool != nil && content != nil && expansion != nil
        }
    }

    let id = UUID()
    private var identityRevision: UInt64? = 0
    private var toolRevision: UInt64? = 0
    private var contentRevision: UInt64? = 0
    private var expansionRevision: UInt64? = 0

    var revision: Revision {
        Revision(identity: identityRevision, tool: toolRevision,
                 content: contentRevision, expansion: expansionRevision)
    }

    func identityWillChange() { Self.advance(&identityRevision) }
    func toolWillChange() { Self.advance(&toolRevision) }
    func contentWillChange() { Self.advance(&contentRevision) }
    func expansionWillChange() { Self.advance(&expansionRevision) }

    static func advance(_ revision: inout UInt64?) {
        guard let value = revision else { return }
        revision = value == .max ? nil : value + 1
    }
}

/// The original NavigationStack supplies this predicate. It reads its actual
/// path and the existing TorahDocumentLoadLifetime; it does not start a load.
@MainActor
struct TorahInspectorNavigationScope {
    let lifetime: TorahInspectorNavigationLifetime
    let isCurrent: @MainActor (TorahInspectorFocus) -> Bool
}

@MainActor
struct TorahInspectorNavigationStackSource {
    let lifetime: TorahInspectorNavigationLifetime
    let isCurrentRoute: @MainActor (TorahInspectorRoute) -> Bool
}

/// A snapshot of the actual original tool/load/expansion values. The three tool
/// targets do not retain row data; row targets additionally bind contentRevision
/// and the complete original group/source/note value.
public struct TorahInspectorNavigationPanelState: Equatable, Sendable {
    public let selectedTool: TorahStudyToolID
    public let readyTools: Set<TorahStudyToolID>
    public let targets: [TorahInspectorNavigationTarget]
    public let expandedGroupIDs: Set<String>
    public let expandedSourceIDs: Set<String>

    init(selectedTool: TorahStudyToolID, readyTools: Set<TorahStudyToolID>,
         targets: [TorahInspectorNavigationTarget], expandedGroupIDs: Set<String>,
         expandedSourceIDs: Set<String>) {
        self.selectedTool = selectedTool
        self.readyTools = readyTools
        self.targets = targets
        self.expandedGroupIDs = expandedGroupIDs
        self.expandedSourceIDs = expandedSourceIDs
    }
}

/// An original view's read-only source plus its finite original setters and
/// ScrollViewReader. The host must retain its own Reader/backend/window proof
/// and the external selectedTool Binding publication across every operation.
@MainActor
public struct TorahInspectorOriginalPanel {
    public let ownerID: UUID
    public let renderID: UUID
    public let focus: TorahInspectorFocus
    public let repository: TorahInspectorRepository
    let lifetime: TorahInspectorNavigationLifetime
    let scope: TorahInspectorNavigationScope
    let read: @MainActor () -> TorahInspectorNavigationPanelState
    let selectTool: @MainActor (TorahStudyToolID) -> Void
    let expandGroup: @MainActor (String) -> Void
    let scroll: @MainActor (TorahInspectorNavigationAnchor) -> Void

    init(lifetime: TorahInspectorNavigationLifetime,
         scope: TorahInspectorNavigationScope, focus: TorahInspectorFocus,
         repository: TorahInspectorRepository,
         read: @escaping @MainActor () -> TorahInspectorNavigationPanelState,
         selectTool: @escaping @MainActor (TorahStudyToolID) -> Void,
         expandGroup: @escaping @MainActor (String) -> Void,
         scroll: @escaping @MainActor (TorahInspectorNavigationAnchor) -> Void) {
        ownerID = lifetime.id
        renderID = UUID()
        self.lifetime = lifetime
        self.scope = scope
        self.focus = focus
        self.repository = repository
        self.read = read
        self.selectTool = selectTool
        self.expandGroup = expandGroup
        self.scroll = scroll
    }

    public func currentState() throws -> TorahInspectorNavigationPanelState {
        let root = scope.lifetime.revision
        let detail = lifetime.revision
        guard root.isAvailable, detail.isAvailable, scope.isCurrent(focus) else {
            throw TorahInspectorNavigationError.unavailable
        }
        let value = read()
        guard root == scope.lifetime.revision, detail == lifetime.revision,
              scope.isCurrent(focus), root == scope.lifetime.revision,
              detail == lifetime.revision else {
            throw TorahInspectorNavigationError.staleSource
        }
        return value
    }

    public func retain(_ target: TorahInspectorNavigationTarget) throws -> TorahInspectorNavigationRetention {
        let root = scope.lifetime.revision
        let detail = lifetime.revision
        let state = try currentState()
        let matches = state.targets.filter { $0.anchor == target.anchor }
        guard matches.count == 1 else { throw TorahInspectorNavigationError.ambiguousTarget }
        guard matches[0] == target, root == scope.lifetime.revision,
              detail == lifetime.revision else { throw TorahInspectorNavigationError.staleSource }
        return TorahInspectorNavigationRetention(panel: self, target: target,
            root: root, detail: detail, state: state)
    }

    public func retainCatalog() throws -> TorahInspectorNavigationCatalog {
        let root = scope.lifetime.revision
        let detail = lifetime.revision
        let state = try currentState()
        let result = TorahInspectorNavigationCatalog(panel: self, root: root, detail: detail, state: state)
        try result.validate()
        return result
    }
}

/// A catalog retains the actual loaded values and original path/tool/content
/// publication. Disclosure expansion changes presentation, so it is validated
/// separately by each one-use reveal and does not mint a replacement record.
@MainActor
public final class TorahInspectorNavigationCatalog {
    public let targets: [TorahInspectorNavigationTarget]
    public var ownerID: UUID { panel.ownerID }
    public var focus: TorahInspectorFocus { panel.focus }
    public var repository: TorahInspectorRepository { panel.repository }
    private let panel: TorahInspectorOriginalPanel
    private let root: TorahInspectorNavigationLifetime.Revision
    private let detail: TorahInspectorNavigationLifetime.Revision
    private let selectedTool: TorahStudyToolID
    private var valid = true
    private var reading = false

    init(panel: TorahInspectorOriginalPanel, root: TorahInspectorNavigationLifetime.Revision,
         detail: TorahInspectorNavigationLifetime.Revision, state: TorahInspectorNavigationPanelState) {
        self.panel = panel; self.root = root; self.detail = detail
        targets = state.targets; selectedTool = state.selectedTool
    }

    public func retire() { valid = false }

    public func validate() throws {
        guard valid, !reading else { throw TorahInspectorNavigationError.staleSource }
        reading = true
        defer { reading = false }
        do {
            let currentRoot = panel.scope.lifetime.revision
            let currentDetail = panel.lifetime.revision
            guard root.isAvailable, detail.isAvailable, currentRoot == root,
                  currentDetail.isAvailable, currentDetail.identity == detail.identity,
                  currentDetail.tool == detail.tool, currentDetail.content == detail.content else {
                throw TorahInspectorNavigationError.staleSource
            }
            let state = try panel.currentState()
            guard valid, state.selectedTool == selectedTool, state.targets == targets,
                  panel.scope.lifetime.revision == currentRoot,
                  panel.lifetime.revision == currentDetail else {
                throw TorahInspectorNavigationError.staleSource
            }
        } catch { valid = false; throw error }
    }
}

public enum TorahInspectorNavigationProgress: Equatable, Sendable {
    case awaitingOriginalLayout
    case awaitingOriginalContent
    case awaitingOriginalWitness
}

/// A one-use original reveal. This is not application routing authority and it
/// does not manufacture an acknowledgement. Completion still requires the
/// host's same-window, unclipped, exact original control/row witness.
@MainActor
public final class TorahInspectorNavigationRetention {
    public let target: TorahInspectorNavigationTarget
    public var ownerID: UUID { panel.ownerID }
    public var focus: TorahInspectorFocus { panel.focus }
    public var repository: TorahInspectorRepository { panel.repository }
    public var originalToolWriteCommitted: Bool { expectedToolRevision != root.tool }

    private enum Phase: Equatable {
        case captured
        case applying
        case awaitingLayout(UInt64)
        case awaitingWitness
        case retired
    }

    private let panel: TorahInspectorOriginalPanel
    private let root: TorahInspectorNavigationLifetime.Revision
    private let detail: TorahInspectorNavigationLifetime.Revision
    private let initialState: TorahInspectorNavigationPanelState
    private var expectedToolRevision: UInt64?
    private var expectedExpansionRevision: UInt64?
    private var expectedTool: TorahStudyToolID
    private var expectedGroups: Set<String>
    private var phase = Phase.captured
    private var reading = false

    init(panel: TorahInspectorOriginalPanel, target: TorahInspectorNavigationTarget,
         root: TorahInspectorNavigationLifetime.Revision,
         detail: TorahInspectorNavigationLifetime.Revision,
         state: TorahInspectorNavigationPanelState) {
        self.panel = panel
        self.target = target
        self.root = root
        self.detail = detail
        initialState = state
        expectedToolRevision = root.tool
        expectedExpansionRevision = detail.expansion
        expectedTool = state.selectedTool
        expectedGroups = state.expandedGroupIDs
    }

    public func retire() { phase = .retired }

    private var isRow: Bool {
        if case .tool = target.anchor { return false }
        return true
    }

    public func validate() throws {
        _ = try validatedState()
    }

    private func validatedState() throws -> TorahInspectorNavigationPanelState {
        if case .retired = phase { throw TorahInspectorNavigationError.staleSource }
        guard !reading else { throw TorahInspectorNavigationError.alreadyApplied }
        let retainedPhase = phase
        reading = true
        defer { reading = false }
        let beforeRoot = panel.scope.lifetime.revision
        let beforeDetail = panel.lifetime.revision
        guard beforeRoot.isAvailable, beforeDetail.isAvailable,
              beforeRoot.identity == root.identity,
              beforeRoot.tool == expectedToolRevision,
              beforeRoot.content == root.content,
              beforeRoot.expansion == root.expansion,
              beforeDetail.identity == detail.identity,
              beforeDetail.tool == detail.tool,
              beforeDetail.expansion == expectedExpansionRevision,
              !isRow || beforeDetail.content == detail.content,
              panel.scope.isCurrent(panel.focus) else {
            throw TorahInspectorNavigationError.staleSource
        }
        let state = panel.read()
        let matches = state.targets.filter { $0.anchor == target.anchor }
        guard state.selectedTool == expectedTool,
              state.expandedGroupIDs == expectedGroups,
              state.expandedSourceIDs == initialState.expandedSourceIDs,
              matches.count == 1, matches[0] == target,
              beforeRoot == panel.scope.lifetime.revision,
              beforeDetail == panel.lifetime.revision,
              panel.scope.isCurrent(panel.focus),
              beforeRoot == panel.scope.lifetime.revision,
              beforeDetail == panel.lifetime.revision,
              phase == retainedPhase else {
            throw TorahInspectorNavigationError.staleSource
        }
        return state
    }

    /// Call only from the original application transaction, retaining its
    /// original validation closure/deadline. layoutRevision must come from the
    /// actual original panel layout, never a timer or a synthesized route event.
    public func reveal(layoutRevision: UInt64,
                       validateExternal: @MainActor () throws -> Void) throws -> TorahInspectorNavigationProgress {
        do {
            return try revealOriginal(layoutRevision: layoutRevision, validateExternal: validateExternal)
        } catch {
            phase = .retired
            throw error
        }
    }

    private func revealOriginal(layoutRevision: UInt64,
                                validateExternal: @MainActor () throws -> Void) throws -> TorahInspectorNavigationProgress {
        switch phase {
        case .captured:
            // Consume before calling any host code; nested delivery cannot use
            // the same retained operation while validation or a setter runs.
            phase = .applying
            do {
                try validateExternal()
                try validate()
                if case .tool(let tool) = target.anchor {
                    if expectedTool != tool {
                        guard let revision = expectedToolRevision, revision < .max else {
                            throw TorahInspectorNavigationError.staleSource
                        }
                        panel.selectTool(tool)
                        // These are the sole declared original writes. No
                        // refreshed identity/content/expansion source is taken.
                        expectedToolRevision = revision + 1
                        expectedTool = tool
                        try validate()
                        try validateExternal()
                        try validate()
                    }
                    phase = .awaitingWitness
                } else if let group = target.group, !expectedGroups.contains(group.id) {
                    guard let revision = expectedExpansionRevision, revision < .max else {
                        throw TorahInspectorNavigationError.staleSource
                    }
                    panel.expandGroup(group.id)
                    expectedExpansionRevision = revision + 1
                    expectedGroups.insert(group.id)
                    try validate()
                    try validateExternal()
                    try validate()
                    phase = .awaitingLayout(layoutRevision)
                    return .awaitingOriginalLayout
                } else {
                    try validateExternal()
                    try validate()
                    panel.scroll(target.anchor)
                    try validate()
                    try validateExternal()
                    try validate()
                    phase = .awaitingWitness
                }
            } catch {
                phase = .retired
                throw error
            }
        case .awaitingLayout(let previous):
            phase = .applying
            do {
                try validateExternal()
                try validate()
                guard layoutRevision > previous else {
                    phase = .awaitingLayout(previous)
                    return .awaitingOriginalLayout
                }
                panel.scroll(target.anchor)
                try validate()
                try validateExternal()
                try validate()
                phase = .awaitingWitness
            } catch {
                phase = .retired
                throw error
            }
        case .awaitingWitness:
            phase = .applying
            try validateExternal()
            try validate()
            phase = .awaitingWitness
        case .applying, .retired:
            throw TorahInspectorNavigationError.alreadyApplied
        }
        let current = try validatedState()
        return current.readyTools.contains(target.tool)
            ? .awaitingOriginalWitness : .awaitingOriginalContent
    }

    /// A read-only fence for the independent original row/control geometry
    /// witness. Neither a completed setter nor a source snapshot is a receipt.
    public func isReadyForOriginalWitness() throws -> Bool {
        guard case .awaitingWitness = phase else { return false }
        let state = try validatedState()
        return state.selectedTool == target.tool && state.readyTools.contains(target.tool)
    }
}

/// Optional passive view hooks. They are nil for existing Kit hosts. A supplied
/// view must be noninteractive and must not replace the original UI. The host
/// owns actual UIKit/window/layout evidence and the application transaction.
@MainActor
public struct TorahInspectorNavigationHooks {
    public let panel: @MainActor (TorahInspectorOriginalPanel) -> AnyView
    public let witness: @MainActor (UUID, TorahInspectorNavigationAnchor) -> AnyView

    public init(panel: @escaping @MainActor (TorahInspectorOriginalPanel) -> AnyView,
                witness: @escaping @MainActor (UUID, TorahInspectorNavigationAnchor) -> AnyView) {
        self.panel = panel
        self.witness = witness
    }
}

private struct TorahInspectorNavigationHooksKey: EnvironmentKey {
    static let defaultValue: TorahInspectorNavigationHooks? = nil
}

private struct TorahInspectorNavigationScopeKey: EnvironmentKey {
    static let defaultValue: TorahInspectorNavigationScope? = nil
}

private struct TorahInspectorNavigationLifetimeKey: EnvironmentKey {
    static let defaultValue: TorahInspectorNavigationLifetime? = nil
}

private struct TorahInspectorNavigationStackKey: EnvironmentKey {
    static let defaultValue: TorahInspectorNavigationStackSource? = nil
}

extension EnvironmentValues {
    var torahInspectorNavigationHooks: TorahInspectorNavigationHooks? {
        get { self[TorahInspectorNavigationHooksKey.self] }
        set { self[TorahInspectorNavigationHooksKey.self] = newValue }
    }

    var torahInspectorNavigationScope: TorahInspectorNavigationScope? {
        get { self[TorahInspectorNavigationScopeKey.self] }
        set { self[TorahInspectorNavigationScopeKey.self] = newValue }
    }

    var torahInspectorNavigationLifetime: TorahInspectorNavigationLifetime? {
        get { self[TorahInspectorNavigationLifetimeKey.self] }
        set { self[TorahInspectorNavigationLifetimeKey.self] = newValue }
    }

    var torahInspectorNavigationStack: TorahInspectorNavigationStackSource? {
        get { self[TorahInspectorNavigationStackKey.self] }
        set { self[TorahInspectorNavigationStackKey.self] = newValue }
    }
}

public extension View {
    func torahInspectorNavigation(_ hooks: TorahInspectorNavigationHooks?) -> some View {
        environment(\.torahInspectorNavigationHooks, hooks)
    }
}
