import Foundation

enum BookingRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case offerNotFound
    case offerNoLongerPending
    case requestNoLongerOpen
    case bookingAlreadyExists
    case bookingConflict
    case bookingNotFound
    case bookingNotCancellable
    case bookingNotCompletable
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
