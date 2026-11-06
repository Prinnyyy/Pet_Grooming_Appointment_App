import Foundation

enum GroomerRequestRepositoryError: Error, Equatable, Sendable {
    case clientUpdateRequired
    case notAllowed
    case matchNotFound
    case noLongerDismissible
    case requestNoLongerOpen
    case noLongerOfferable
    case activeOfferExists
    case groomerUnavailable
    case timingBuffersRequired
    case scheduleTimeZoneRequired
    case serviceTimeZoneRequired
    case serviceSpeciesRequired
    case assessmentConfirmationRequired
    case offerNotFound
    case noLongerWithdrawable
    case invalidInput
    case networkUnavailable
    case cancelled
    case unavailable
}

@MainActor
protocol GroomerRequestRepository: AnyObject {
    func offerDetail(groomerID: UUID, offerID: UUID) async throws -> GroomerOfferListItem?
    func groomingMatches(groomerID: UUID, location: GroomingLocationMode?, page: RankedPageRequest<GroomerMatchSort>) async throws -> RankedPage<GroomerMatchedRequest>
    func groomingOffers(groomerID: UUID, group: String, page: ListPageRequest) async throws -> ListPage<GroomerOfferListItem>
    func rankedMatches(groomerID: UUID, page: RankedPageRequest<GroomerMatchSort>) async throws -> RankedPage<GroomerMatchedRequest>
    func matchedRequest(groomerID: UUID, requestID: UUID) async throws -> GroomerMatchedRequest
    func offer(groomerID: UUID, offerID: UUID) async throws -> GroomerOffer?
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
    func offerDetail(groomerID: UUID, offerID: UUID) async throws -> GroomerOfferListItem? {
        guard let offer = try await offer(groomerID: groomerID, offerID: offerID) else { return nil }
        return GroomerOfferListItem(offer: offer, request: nil, booking: nil)
    }
    func groomingMatches(groomerID: UUID, location: GroomingLocationMode?, page: RankedPageRequest<GroomerMatchSort>) async throws -> RankedPage<GroomerMatchedRequest> {
        try await rankedMatches(groomerID: groomerID, page: page)
    }
    func groomingOffers(groomerID: UUID, group: String, page: ListPageRequest) async throws -> ListPage<GroomerOfferListItem> {
        try await offers(groomerID: groomerID, page: page)
    }
    func rankedMatches(groomerID: UUID, page: RankedPageRequest<GroomerMatchSort>) async throws -> RankedPage<GroomerMatchedRequest> {
        throw MatchRankingError.unavailable
    }
    func matchedRequest(groomerID: UUID, requestID: UUID) async throws -> GroomerMatchedRequest {
        throw GroomerRequestRepositoryError.unavailable
    }
    func offer(groomerID: UUID, offerID: UUID) async throws -> GroomerOffer? {
        throw GroomerRequestRepositoryError.unavailable
    }

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
