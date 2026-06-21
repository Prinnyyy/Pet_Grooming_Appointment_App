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
    case invalidInput
    case networkUnavailable
    case unavailable
}

@MainActor
protocol BookingRepository: AnyObject {
    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking]

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult
}
