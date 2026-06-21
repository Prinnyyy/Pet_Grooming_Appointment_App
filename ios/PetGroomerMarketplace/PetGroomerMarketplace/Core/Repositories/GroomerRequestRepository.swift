import Foundation

enum GroomerRequestRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case matchNotFound
    case noLongerDismissible
    case requestNoLongerOpen
    case noLongerOfferable
    case activeOfferExists
    case offerNotFound
    case noLongerWithdrawable
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

    func createOffer(
        draft: GroomerOfferDraft
    ) async throws -> CreateGroomerOfferResult

    func withdrawOffer(
        offerID: UUID
    ) async throws -> WithdrawGroomerOfferResult
}
