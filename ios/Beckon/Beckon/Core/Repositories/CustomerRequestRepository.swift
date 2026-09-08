import Foundation

enum CustomerRequestRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case requestLimitExceeded
    case requestNotFound
    case requestNotCancellable
    case petNotFound
    case invalidInput
    case networkUnavailable
    case cancelled
    case unavailable
}

@MainActor
protocol CustomerRequestRepository: AnyObject {
    func request(customerID: UUID, requestID: UUID) async throws -> CustomerGroomingRequest
    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest]

    func requests(
        customerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerGroomingRequest>

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview]

    func offers(
        customerID: UUID,
        requestID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerOfferReview>

    func requestPhotos(
        customerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto]

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult

    func uploadRequestPhoto(
        customerID: UUID,
        requestID: UUID,
        data: Data,
        contentType: GroomingRequestPhotoContentType,
        caption: String?
    ) async throws -> GroomingRequestPhoto

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult

    func acknowledgedBookingHandoffRequestIDs(
        customerID: UUID
    ) async throws -> Set<UUID>

    func acknowledgeBookingHandoff(
        customerID: UUID,
        requestID: UUID,
        bookingID: UUID
    ) async throws
}

extension CustomerRequestRepository {
    func request(customerID: UUID, requestID: UUID) async throws -> CustomerGroomingRequest {
        throw CustomerRequestRepositoryError.unavailable
    }
    func requests(
        customerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerGroomingRequest> {
        ListPage(
            items: try await requests(customerID: customerID),
            request: page,
            hasMore: false
        )
    }

    func offers(
        customerID: UUID,
        requestID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerOfferReview> {
        ListPage(
            items: try await offers(customerID: customerID, requestID: requestID),
            request: page,
            hasMore: false
        )
    }

    func requestPhotos(
        customerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto] {
        []
    }

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data {
        throw CustomerRequestRepositoryError.unavailable
    }

    func acknowledgedBookingHandoffRequestIDs(
        customerID: UUID
    ) async throws -> Set<UUID> {
        []
    }

    func acknowledgeBookingHandoff(
        customerID: UUID,
        requestID: UUID,
        bookingID: UUID
    ) async throws {}
}
