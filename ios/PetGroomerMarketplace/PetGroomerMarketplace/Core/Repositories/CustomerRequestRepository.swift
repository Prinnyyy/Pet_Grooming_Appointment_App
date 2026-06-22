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

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult
}
