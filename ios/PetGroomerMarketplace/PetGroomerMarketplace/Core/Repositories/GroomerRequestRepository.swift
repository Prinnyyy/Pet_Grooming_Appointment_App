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
    case cancelled
    case unavailable
}

@MainActor
protocol GroomerRequestRepository: AnyObject {
    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest]

    func matchedRequests(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerMatchedRequest>

    func offers(groomerID: UUID) async throws -> [GroomerOfferListItem]

    func offers(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerOfferListItem>

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
    func matchedRequests(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerMatchedRequest> {
        ListPage(
            items: try await matchedRequests(groomerID: groomerID),
            request: page,
            hasMore: false
        )
    }

    func offers(groomerID: UUID) async throws -> [GroomerOfferListItem] {
        []
    }

    func offers(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerOfferListItem> {
        ListPage(
            items: try await offers(groomerID: groomerID),
            request: page,
            hasMore: false
        )
    }

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
