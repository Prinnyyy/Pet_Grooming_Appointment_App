import Foundation
import Observation

@MainActor
@Observable
final class BookingsStore {
    private let participantID: UUID
    private let role: UserRole
    private let repository: any BookingRepository
    private let debugRecorder: AppDebugEventRecorder?

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
        initialBookings: [Booking] = [],
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.participantID = participantID
        self.role = role
        self.repository = repository
        self.debugRecorder = debugRecorder
        bookings = initialBookings
    }

    func booking(withID id: UUID) -> Booking? {
        bookings.first { $0.id == id }
    }

    func load() async {
        let startedAt = Date()
        recordStoreStart("load")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            bookings = try await repository.bookings(
                participantID: participantID,
                role: role
            )
            recordStoreSuccess(
                "load",
                startedAt: startedAt,
                metadata: ["bookingCount": "\(bookings.count)"]
            )
        } catch BookingRepositoryError.cancelled {
            recordStoreCancelled("load", startedAt: startedAt)
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("load", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func cancel(_ booking: Booking) async {
        guard !isCancelling else { return }
        guard booking.canCancel else {
            errorMessage = "This booking can no longer be cancelled."
            return
        }

        isCancelling = true
        let startedAt = Date()
        recordStoreStart("cancel")
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
            recordStoreSuccess("cancel", startedAt: startedAt)
        } catch BookingRepositoryError.cancelled {
            recordStoreCancelled("cancel", startedAt: startedAt)
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "cancel")
            recordStoreFailure(
                "cancel",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("cancel", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "cancel")
            recordStoreFailure(
                "cancel",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func complete(_ booking: Booking) async {
        guard !isCompleting else { return }
        guard booking.canComplete(for: role) else {
            errorMessage = "This booking can no longer be completed by this account."
            return
        }

        isCompleting = true
        let startedAt = Date()
        recordStoreStart("complete")
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
            recordStoreSuccess("complete", startedAt: startedAt)
        } catch BookingRepositoryError.cancelled {
            recordStoreCancelled("complete", startedAt: startedAt)
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "complete")
            recordStoreFailure(
                "complete",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("complete", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "complete")
            recordStoreFailure(
                "complete",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
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
        let startedAt = Date()
        recordStoreStart("createReview")
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
            recordStoreSuccess("createReview", startedAt: startedAt)
        } catch BookingRepositoryError.cancelled {
            recordStoreCancelled("createReview", startedAt: startedAt)
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "review")
            recordStoreFailure(
                "createReview",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("createReview", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "review")
            recordStoreFailure(
                "createReview",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
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
        case .cancelled:
            "The booking action was cancelled."
        case .unavailable:
            "We could not \(action) bookings. Please try again."
        }
    }

    private var debugScope: String {
        "\(role.appDebugScopePrefix).bookings"
    }

    private func recordStoreStart(_ operation: String) {
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "BookingsStore.\(operation)",
            scope: debugScope,
            message: "start",
            metadata: [
                "operation": operation,
                "participantID": participantID.uuidString,
                "role": role.appDebugName,
            ]
        )
    }

    private func recordStoreSuccess(
        _ operation: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "BookingsStore.\(operation)",
            scope: debugScope,
            message: "success",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

    private func recordStoreFailure(
        _ operation: String,
        error: any Error,
        mappedMessage: String?,
        startedAt: Date
    ) {
        debugRecorder?.record(
            level: .error,
            category: .store,
            source: "BookingsStore.\(operation)",
            scope: debugScope,
            message: mappedMessage ?? "failure",
            underlyingError: error,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation]
        )
    }

    private func recordStoreCancelled(
        _ operation: String,
        startedAt: Date
    ) {
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "BookingsStore.\(operation)",
            scope: debugScope,
            message: "cancelled ignored",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation]
        )
    }
}
