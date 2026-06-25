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
    private(set) var isCompleting = false
    private(set) var isSubmittingReview = false

    var errorMessage: String?
    var noticeMessage: String?

    var isBusy: Bool {
        isLoading || isCancelling || isCompleting || isSubmittingReview
    }

    init(
        participantID: UUID,
        role: UserRole,
        repository: any BookingRepository,
        initialBookings: [Booking] = []
    ) {
        self.participantID = participantID
        self.role = role
        self.repository = repository
        bookings = initialBookings
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

    func complete(_ booking: Booking) async {
        guard !isCompleting else { return }
        guard booking.canComplete(for: role) else {
            errorMessage = "This booking can no longer be completed by this account."
            return
        }

        isCompleting = true
        errorMessage = nil
        noticeMessage = nil
        defer { isCompleting = false }

        do {
            let result = try await repository.completeBooking(bookingID: booking.id)
            let updatedBooking = booking.replacing(
                status: result.bookingStatus,
                cancelledBy: booking.cancelledBy,
                cancelledAt: booking.cancelledAt,
                completedAt: result.completedTimestamp,
                completedBy: result.completedBy,
                review: booking.review
            )

            if replace(updatedBooking) {
                noticeMessage = "Booking completed. The customer can now leave one review."
            } else {
                noticeMessage = "Booking completed. Refresh bookings to see the latest state."
            }
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "complete")
        } catch {
            errorMessage = message(for: .unavailable, action: "complete")
        }
    }

    func createReview(
        for booking: Booking,
        rating: Int,
        content: String,
        petFitOutcomes: [BookingReviewPetFitOutcomeDraft] = []
    ) async {
        guard !isSubmittingReview else { return }
        guard booking.canReview(for: role) else {
            errorMessage = "This booking can no longer be reviewed by this account."
            return
        }
        guard (1...5).contains(rating) else {
            errorMessage = "Choose a rating from 1 to 5."
            return
        }

        let trimmedContent = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard trimmedContent.count <= 2000 else {
            errorMessage = "Review text must be 2,000 characters or fewer."
            return
        }

        isSubmittingReview = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSubmittingReview = false }

        let draft = BookingReviewDraft(
            rating: rating,
            content: trimmedContent.isEmpty ? nil : trimmedContent,
            petFitOutcomes: petFitOutcomes
        )

        do {
            let result = try await repository.createReview(
                bookingID: booking.id,
                draft: draft
            )
            let updatedBooking = booking.adding(review: result.review)

            if replace(updatedBooking) {
                noticeMessage = "Review submitted. Thank you for your feedback."
            } else {
                noticeMessage = "Review submitted. Refresh bookings to see the latest state."
            }
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "review")
        } catch {
            errorMessage = message(for: .unavailable, action: "review")
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
        case .bookingNotCompletable:
            "This booking can no longer be completed."
        case .bookingNotCompleted:
            "This booking must be completed before it can be reviewed."
        case .reviewAlreadyExists:
            "This booking already has a review."
        case .invalidReview:
            "Choose a 1–5 rating and keep review text under 2,000 characters."
        case .invalidInput:
            "Check the booking and try again."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not \(action) bookings. Please try again."
        }
    }
}
