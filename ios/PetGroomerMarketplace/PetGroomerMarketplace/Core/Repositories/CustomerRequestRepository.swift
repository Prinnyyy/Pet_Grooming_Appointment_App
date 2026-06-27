import Foundation

enum CustomerRequestRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case requestLimitExceeded
    case requestNotFound
    case requestNotCancellable
    case petNotFound
    case invalidInput
    case networkUnavailable
    case unavailable
}

@MainActor
protocol CustomerRequestRepository: AnyObject {
    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest]

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview]

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
}

extension CustomerRequestRepository {
    func requestPhotos(
        customerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto] {
        []
    }

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data {
        throw CustomerRequestRepositoryError.unavailable
    }
}
