import Foundation

enum GroomerRequestRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case matchNotFound
    case noLongerDismissible
    case invalidInput
    case networkUnavailable
    case unavailable
}

@MainActor
protocol GroomerRequestRepository: AnyObject {
    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest]

    func dismiss(
        matchID: UUID,
        reason: String?
    ) async throws -> DismissRequestMatchResult
}
