import Foundation
import Observation

@MainActor
@Observable
final class BookingsStore {
    private let participantID: UUID
    private let role: UserRole
    private let repository: any BookingRepository

    private(set) var bookings: [Booking] = []
    private(set) var isLoading = false
    private(set) var isCancelling = false

    var errorMessage: String?
    var noticeMessage: String?

    var isBusy: Bool {
        isLoading || isCancelling
    }

    init(
        participantID: UUID,
        role: UserRole,
        repository: any BookingRepository
    ) {
        self.participantID = participantID
        self.role = role
        self.repository = repository
    }

    func booking(withID id: UUID) -> Booking? {
        bookings.first { $0.id == id }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            bookings = try await repository.bookings(
                participantID: participantID,
                role: role
            )
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "load")
        } catch {
            errorMessage = message(for: .unavailable, action: "load")
        }
    }

    func cancel(_ booking: Booking) async {
        guard !isCancelling else { return }
        guard booking.canCancel else {
            errorMessage = "This booking can no longer be cancelled."
            return
        }

        isCancelling = true
        errorMessage = nil
        noticeMessage = nil
        defer { isCancelling = false }

        do {
            let result = try await repository.cancelBooking(bookingID: booking.id)
            let updatedBooking = booking.replacing(
                status: result.bookingStatus,
                cancelledBy: result.cancelledBy,
                cancelledAt: result.cancelledTimestamp
            )

            if replace(updatedBooking) {
                noticeMessage = "Booking cancelled. The original request and offers remain closed."
            } else {
                noticeMessage = "Booking cancelled. Refresh bookings to see the latest state. The original request and offers remain closed."
            }
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "cancel")
        } catch {
            errorMessage = message(for: .unavailable, action: "cancel")
        }
    }

    @discardableResult
    private func replace(_ booking: Booking) -> Bool {
        guard let index = bookings.firstIndex(where: { $0.id == booking.id }) else {
            return false
        }

        bookings[index] = booking
        return true
    }

    private func message(
        for error: BookingRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) bookings."
        case .offerNotFound:
            "This offer is no longer available."
        case .offerNoLongerPending:
            "This offer can no longer be accepted."
        case .requestNoLongerOpen:
            "This request can no longer become a booking."
        case .bookingAlreadyExists:
            "This request already has a booking."
        case .bookingConflict:
            "That groomer is no longer available at the proposed time."
        case .bookingNotFound:
            "This booking is no longer available."
        case .bookingNotCancellable:
            "This booking can no longer be cancelled."
        case .invalidInput:
            "Check the booking and try again."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not \(action) bookings. Please try again."
        }
    }
}
