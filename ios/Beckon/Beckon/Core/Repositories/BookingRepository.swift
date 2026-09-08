import Foundation

enum BookingRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case offerNotFound
    case offerNoLongerPending
    case updatedOfferRequired
    case clientUpdateRequired
    case matchConstraintsChanged
    case requestNoLongerOpen
    case bookingAlreadyExists
    case bookingConflict
    case bookingNotFound
    case bookingNotCancellable
    case bookingNotCompletable
    case fulfillmentRejected(BookingFulfillmentRejection)
    case rescheduleRejected(String)
    case bookingNotCompleted
    case reviewAlreadyExists
    case invalidReview
    case invalidInput
    case networkUnavailable
    case cancelled
    case unavailable
}

@MainActor
protocol BookingRepository: AnyObject {
    func mutateFulfillment(_ operation: BookingFulfillmentOperation) async throws -> BookingFulfillmentResult
    func fulfillmentOperation(id: UUID) async throws -> BookingFulfillmentResult?
    func fulfillmentEvents(bookingID: UUID) async throws -> [BookingFulfillmentEvent]
    func reschedule(bookingID: UUID) async throws -> BookingRescheduleResult
    func mutateReschedule(_ operation: BookingRescheduleOperation) async throws -> BookingRescheduleResult
    func rescheduleOperation(id: UUID) async throws -> BookingRescheduleResult?
    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking]

    func bookings(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<Booking>

    func bookings(
        bookingIDs: [UUID]
    ) async throws -> [Booking]

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult

    func offerAcceptance(offerID: UUID) async throws -> AcceptGroomerOfferResult?
    func acceptOffer(offerID: UUID, expectedQuoteRevision: UUID) async throws -> AcceptGroomerOfferResult

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult
}

extension BookingRepository {
    func reschedule(bookingID: UUID) async throws -> BookingRescheduleResult { throw BookingRepositoryError.unavailable }
    func mutateReschedule(_ operation: BookingRescheduleOperation) async throws -> BookingRescheduleResult { throw BookingRepositoryError.unavailable }
    func rescheduleOperation(id: UUID) async throws -> BookingRescheduleResult? { throw BookingRepositoryError.unavailable }
    func mutateFulfillment(_ operation: BookingFulfillmentOperation) async throws -> BookingFulfillmentResult {
        throw BookingRepositoryError.unavailable
    }
    func fulfillmentOperation(id: UUID) async throws -> BookingFulfillmentResult? {
        throw BookingRepositoryError.unavailable
    }
    func fulfillmentEvents(bookingID: UUID) async throws -> [BookingFulfillmentEvent] {
        throw BookingRepositoryError.unavailable
    }
    func acceptOffer(offerID: UUID, expectedQuoteRevision: UUID) async throws -> AcceptGroomerOfferResult {
        try await acceptOffer(offerID: offerID)
    }

    func offerAcceptance(offerID: UUID) async throws -> AcceptGroomerOfferResult? {
        throw BookingRepositoryError.unavailable
    }

    func bookings(
        bookingIDs: [UUID]
    ) async throws -> [Booking] {
        throw BookingRepositoryError.unavailable
    }

    func bookings(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<Booking> {
        ListPage(
            items: try await bookings(
                participantID: participantID,
                role: role
            ),
            request: page,
            hasMore: false
        )
    }

    func firstBookingPage(
        participantID: UUID,
        role: UserRole
    ) async throws -> ListPage<Booking> {
        try await bookings(
            participantID: participantID,
            role: role,
            page: .first
        )
    }
}
