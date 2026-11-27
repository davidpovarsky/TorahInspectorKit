import Foundation

/// A mounted reader owns its asynchronous document loads until it changes
/// selection or disappears. A provider need not cooperate with cancellation.
@MainActor
final class TorahDocumentLoadLifetime {
    struct Request: Equatable, Sendable {
        let selectionID: String
        let id: UUID
    }

    private var current: Request?

    @discardableResult
    func activate(selectionID: String) -> Request {
        let request = Request(selectionID: selectionID, id: UUID())
        current = request
        return request
    }

    /// Called synchronously by an explicit Retry action. A queued retry cannot
    /// reactivate a disappeared view or start work for a different selection.
    func restart(for selectionID: String) -> Request? {
        guard current?.selectionID == selectionID else { return nil }
        return activate(selectionID: selectionID)
    }

    func request(for selectionID: String) -> Request? {
        guard current?.selectionID == selectionID else { return nil }
        return current
    }

    func isCurrent(_ request: Request) -> Bool {
        current == request
    }

    func invalidate() {
        current = nil
    }

    func load<Value: Sendable>(
        for request: Request,
        operation: @MainActor () async throws -> Value
    ) async throws -> Value {
        try requireCurrent(request)
        let value: Value
        do {
            value = try await operation()
        } catch {
            // A late provider error belongs to its original owner too.
            try requireCurrent(request)
            throw error
        }
        try requireCurrent(request)
        return value
    }

    private func requireCurrent(_ request: Request) throws {
        try Task.checkCancellation()
        guard isCurrent(request) else { throw CancellationError() }
    }
}
