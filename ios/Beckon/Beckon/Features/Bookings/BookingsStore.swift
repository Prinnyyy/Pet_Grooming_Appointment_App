import Foundation
import Observation

@MainActor
@Observable
final class BookingsStore {
    private let participantID: UUID
    private let role: UserRole
    private let repository: any BookingRepository
    private let groomerProfileRepository: (any GroomerProfileRepository)?
    private(set) var scheduleCalendar: Calendar?
    private let appointmentReminderScheduler: any AppointmentReminderScheduling
    private let debugRecorder: AppDebugEventRecorder?

    private(set) var bookings: [Booking] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var isCancelling = false
    private(set) var isCompleting = false
    private(set) var isSubmittingReview = false
    private(set) var nextPageRequest: ListPageRequest?

    var errorMessage: String?
    var noticeMessage: String?
    var appointmentReminderNotice: String?

    var isBusy: Bool {
        isLoading || isLoadingMore || isCancelling || isCompleting || isSubmittingReview
    }

    var canLoadMore: Bool {
        nextPageRequest != nil
    }

    init(
        participantID: UUID,
        role: UserRole,
        repository: any BookingRepository,
        groomerProfileRepository: (any GroomerProfileRepository)? = nil,
        initialBookings: [Booking] = [],
        appointmentReminderScheduler: any AppointmentReminderScheduling =
            AppointmentReminderScheduler.shared,
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.participantID = participantID
        self.role = role
        self.repository = repository
        self.groomerProfileRepository = groomerProfileRepository
        self.appointmentReminderScheduler = appointmentReminderScheduler
        self.debugRecorder = debugRecorder
        bookings = initialBookings
    }

    func booking(withID id: UUID) -> Booking? {
        bookings.first { $0.id == id }
    }

    func synchronizeExternalBooking(_ booking: Booking) {
        if !replace(booking) {
            bookings.append(booking)
        }
    }

    func load() async {
        guard !isLoading, !isLoadingMore else { return }

        let startedAt = Date()
        recordStoreStart("load")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await repository.bookings(
                participantID: participantID,
                role: role,
                page: .first
            )
            bookings = page.items
            nextPageRequest = page.nextRequest
            await loadScheduleCalendar()
            try Task.checkCancellation()
            recordStoreSuccess(
                "load",
                startedAt: startedAt,
                metadata: [
                    "bookingCount": "\(bookings.count)",
                    "hasMore": "\(canLoadMore)",
                ]
            )
            await syncAppointmentReminders()
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

    private func loadScheduleCalendar() async {
        guard role == .groomer, let groomerProfileRepository else { return }
        scheduleCalendar = nil
        do {
            let snapshot = try await groomerProfileRepository.availabilitySnapshot(groomerID: participantID)
            guard !Task.isCancelled else { return }
            let zones = Set(snapshot.windows.map(\.timezone))
            guard snapshot.windows.count == 7,
                  Set(snapshot.windows.map(\.weekday)).count == 7,
                  snapshot.windows.allSatisfy({ $0.groomerID == participantID }),
                  zones.count == 1, let identifier = zones.first else { return }
            scheduleCalendar = try GroomingServiceTiming.locationCalendar(identifier)
        } catch {
            scheduleCalendar = nil
        }
    }

    func loadNextPage() async {
        guard !isLoading,
              !isLoadingMore,
              let pageRequest = nextPageRequest else { return }

        let startedAt = Date()
        recordStoreStart("loadNextPage")
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let page = try await repository.bookings(
                participantID: participantID,
                role: role,
                page: pageRequest
            )
            bookings = ListPageMerge.appendingUnique(page.items, to: bookings)
            nextPageRequest = page.nextRequest
            recordStoreSuccess(
                "loadNextPage",
                startedAt: startedAt,
                metadata: [
                    "bookingCount": "\(bookings.count)",
                    "loadedCount": "\(page.items.count)",
                    "hasMore": "\(canLoadMore)",
                ]
            )
            await syncAppointmentReminders()
        } catch BookingRepositoryError.cancelled {
            recordStoreCancelled("loadNextPage", startedAt: startedAt)
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "load")
            recordStoreFailure(
                "loadNextPage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("loadNextPage", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "load")
            recordStoreFailure(
                "loadNextPage",
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
            await appointmentReminderScheduler.cancelReminder(
                for: booking.id,
                role: role
            )
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
            await appointmentReminderScheduler.cancelReminder(
                for: booking.id,
                role: role
            )
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
        case .updatedOfferRequired:
            "This offer needs updated timing details from the groomer before you can book."
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
            unavailableMessage(action: action)
        }
    }

    private func unavailableMessage(action: String) -> String {
        guard action == "load" else {
            return "We could not \(action) bookings. Please try again."
        }

        switch role {
        case .customer:
            return "We could not load your bookings. Please try again."
        case .groomer:
            return "We could not load your schedule. Please try again."
        }
    }

    private var debugScope: String {
        "\(role.appDebugScopePrefix).bookings"
    }

    private func syncAppointmentReminders() async {
        let result = await appointmentReminderScheduler.syncReminders(
            for: bookings,
            role: role
        )

        switch result {
        case .scheduled:
            appointmentReminderNotice = nil
        case .refused:
            appointmentReminderNotice =
                "Appointment reminders are off. Enable notifications in Settings to receive local reminders."
            recordReminderSync(result: result)
        case .unavailable:
            recordReminderSync(result: result)
        }
    }

    private func recordReminderSync(result: AppointmentReminderSyncResult) {
        let message = switch result {
        case .scheduled:
            "scheduled"
        case .refused:
            "permission refused"
        case .unavailable:
            "unavailable"
        }

        debugRecorder?.record(
            level: result == .unavailable ? .warning : .info,
            category: .store,
            source: "BookingsStore.appointmentReminders",
            scope: debugScope,
            message: message,
            metadata: ["role": role.appDebugName]
        )
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
