import Foundation
import TorahInspectorCore

struct TorahPanelRequest: Equatable, Sendable {
    let focusID: String
    let id: UUID

    init(focusID: String, id: UUID = UUID()) {
        self.focusID = focusID
        self.id = id
    }
}

enum TorahPanelLoadState<Value: Sendable>: Sendable {
    case idle
    case loading(request: TorahPanelRequest, cached: Value?)
    case loaded(Value)
    case failed(message: String, cached: Value?)

    var value: Value? {
        switch self {
        case .idle:
            nil
        case .loading(_, let cached), .failed(_, let cached):
            cached
        case .loaded(let value):
            value
        }
    }

    var errorMessage: String? {
        guard case .failed(let message, _) = self else { return nil }
        return message
    }

    var isLoadingWithoutValue: Bool {
        guard case .loading(_, let cached) = self else { return false }
        return cached == nil
    }

    mutating func begin(focusID: String) -> TorahPanelRequest {
        let request = TorahPanelRequest(focusID: focusID)
        self = .loading(request: request, cached: value)
        return request
    }

    mutating func publish(_ value: Value, for request: TorahPanelRequest) {
        guard isCurrent(request) else { return }
        self = .loaded(value)
    }

    mutating func fail(_ message: String, for request: TorahPanelRequest) {
        guard isCurrent(request) else { return }
        self = .failed(message: message, cached: value)
    }

    mutating func cancel(_ request: TorahPanelRequest) {
        guard isCurrent(request) else { return }
        self = value.map(Self.loaded) ?? .idle
    }

    mutating func reset() {
        self = .idle
    }

    private func isCurrent(_ request: TorahPanelRequest) -> Bool {
        guard case .loading(let current, _) = self else { return false }
        return current == request
    }
}

struct TorahLinksSnapshot: Sendable {
    let sources: [TorahLinkedSource]
    let groups: TorahRelationshipGroups
}

struct TorahPanelLoadTaskID: Hashable {
    let focusID: String
    let tool: TorahStudyToolID
}

enum TorahPanelLoadDemand: Equatable {
    case links
    case linksAndTopics
    case notes
    case relatedDocuments
    case none

    static func demand(for tool: TorahStudyToolID) -> Self {
        switch tool {
        case .commentaries: .links
        case .links: .linksAndTopics
        case .notes: .notes
        case .relatedDocuments: .relatedDocuments
        default: .none
        }
    }
}
