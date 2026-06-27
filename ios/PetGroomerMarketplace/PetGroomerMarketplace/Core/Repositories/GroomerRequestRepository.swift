import Foundation

enum GroomerRequestRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case matchNotFound
    case noLongerDismissible
    case requestNoLongerOpen
    case noLongerOfferable
    case activeOfferExists
    case groomerUnavailable
    case offerNotFound
    case noLongerWithdrawable
    case invalidInput
    case networkUnavailable
    case unavailable
}

@MainActor
protocol GroomerRequestRepository: AnyObject {
    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest]

    func requestPhotos(
        groomerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto]

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data

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

extension GroomerRequestRepository {
    func requestPhotos(
        groomerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto] {
        []
    }

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data {
        throw GroomerRequestRepositoryError.unavailable
    }
}
