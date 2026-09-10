import Foundation
import Observation

enum BookingScopeReadState { case idle, loading, complete, stale, failed }

@MainActor
@Observable
final class BookingsStore {
    private let participantID: UUID
    private let role: UserRole
    private let repository: any BookingRepository
    private let groomerProfileRepository: (any GroomerProfileRepository)?
    private(set) var scheduleCalendar: Calendar?
    private(set) var scheduleInterval: DateInterval?
    private(set) var scheduleBookings: [Booking] = []
    private(set) var scheduleReadState: BookingScopeReadState = .idle
    private(set) var scheduleVerifiedAt: Date?
    private(set) var scheduleRefreshID = UUID()
    private var scheduleReadID = UUID()
    private(set) var bookingReadStates: [UUID: BookingScopeReadState] = [:]
    private(set) var nearestBooking: Booking?
    private(set) var nearestReadState: BookingScopeReadState = .idle
    private(set) var nearestReadError: String?
    private var nearestReadID = UUID()
    private let sessionIsCurrent: @MainActor () -> Bool
    private var listGeneration = 0
    private var synchronizedBookingIDs: Set<UUID> = []
    private var needsListRefresh = false
    private var listRefreshTask: Task<Void, Never>?
    private let appointmentReminderScheduler: any AppointmentReminderScheduling
    private let debugRecorder: AppDebugEventRecorder?
    private let fulfillmentDefaults: UserDefaults
    private var pendingFulfillment: [UUID: BookingFulfillmentOperation] = [:]
    private(set) var isMutatingFulfillment = false
    private(set) var fulfillmentHistory: [UUID: [BookingFulfillmentEvent]] = [:]
    private(set) var fulfillmentHistoryErrors: [UUID: String] = [:]
    private var pendingReschedules: [UUID: BookingRescheduleOperation] = [:]
    private(set) var rescheduleSnapshots: [UUID: BookingRescheduleResult] = [:]
    private(set) var rescheduleErrors: [UUID: String] = [:]
    private(set) var isMutatingReschedule = false

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
        isLoading || isLoadingMore || isCancelling || isCompleting || isSubmittingReview || isMutatingFulfillment || isMutatingReschedule
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
        debugRecorder: AppDebugEventRecorder? = nil,
        fulfillmentDefaults: UserDefaults = .standard,
        sessionIsCurrent: @escaping @MainActor () -> Bool = { true }
    ) {
        self.participantID = participantID
        self.role = role
        self.repository = repository
        self.groomerProfileRepository = groomerProfileRepository
        self.appointmentReminderScheduler = appointmentReminderScheduler
        self.debugRecorder = debugRecorder
        self.fulfillmentDefaults = fulfillmentDefaults
        self.sessionIsCurrent = sessionIsCurrent
        bookings = initialBookings
        if let data = fulfillmentDefaults.data(forKey: "beckon.fulfillment.\(participantID).\(role.rawValue)"),
           let operations = try? JSONDecoder().decode([BookingFulfillmentOperation].self, from: data) {
            pendingFulfillment = operations.reduce(into: [:]) { $0[$1.bookingID] = $1 }
        }
        if let data = fulfillmentDefaults.data(forKey: "beckon.reschedule.\(participantID).\(role.rawValue)"),
           let operations = try? JSONDecoder().decode([BookingRescheduleOperation].self, from: data) {
            pendingReschedules = operations.reduce(into: [:]) { $0[$1.bookingID] = $1 }
        }
    }

    func booking(withID id: UUID) -> Booking? {
        bookings.first { $0.id == id }
    }

    func resolveBooking(id: UUID, forceRefresh: Bool = false) async {
        guard sessionIsCurrent(), !Task.isCancelled,
              forceRefresh || booking(withID: id) == nil, bookingReadStates[id] != .loading else { return }
        let generation = listGeneration
        bookingReadStates[id] = .loading
        do {
            let rows = try await repository.bookings(bookingIDs: [id])
            try Task.checkCancellation()
            guard sessionIsCurrent(), generation == listGeneration else {
                bookingReadStates[id] = .stale
                return
            }
            if rows.isEmpty {
                synchronizedBookingIDs.remove(id)
                bookings.removeAll { $0.id == id }
                invalidateList()
                scheduleListRefreshIfNeeded()
            }
            guard rows.count == 1, let booking = rows.first, booking.id == id,
                  (role == .customer ? booking.customerID : booking.groomerID) == participantID else {
                throw BookingRepositoryError.bookingNotFound
            }
            synchronizeExternalBooking(booking)
            bookingReadStates[id] = .complete
        } catch { bookingReadStates[id] = .failed }
    }

    func synchronizeExternalBooking(_ booking: Booking) {
        guard sessionIsCurrent(), owns(booking) else { return }
        guard self.booking(withID: booking.id) != booking || !synchronizedBookingIDs.contains(booking.id) else { return }
        invalidateList()
        synchronizedBookingIDs.insert(booking.id)
        if !replace(booking) {
            bookings.append(booking)
        }
        if nearestBooking?.id == booking.id {
            nearestReadID = UUID()
            nearestBooking = booking.status == .confirmed ? booking : nil
            nearestReadState = .stale
            nearestReadError = "The appointment changed. Refresh to verify the next appointment."
        }
        if let interval = scheduleInterval {
            scheduleReadID = UUID()
            scheduleRefreshID = UUID()
            scheduleBookings.removeAll { $0.id == booking.id }
            if Self.overlaps(booking, interval: interval) && !booking.status.isCancellation {
                scheduleBookings.append(booking)
            }
            scheduleReadState = .stale
        }
        scheduleListRefreshIfNeeded()
    }

    private func owns(_ booking: Booking) -> Bool {
        (role == .customer ? booking.customerID : booking.groomerID) == participantID
    }

    private func invalidateList() {
        listGeneration += 1
        nextPageRequest = nil
        needsListRefresh = true
    }

    private func scheduleListRefreshIfNeeded() {
        guard needsListRefresh, !isLoading, !isLoadingMore, listRefreshTask == nil,
              sessionIsCurrent(), !Task.isCancelled else { return }
        listRefreshTask = Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            if self.needsListRefresh, self.sessionIsCurrent(), !Task.isCancelled {
                await self.load()
            }
            self.listRefreshTask = nil
            self.scheduleListRefreshIfNeeded()
        }
    }

    func loadSchedule(interval: DateInterval) async {
        let operation = UUID()
        scheduleReadID = operation
        if scheduleInterval != interval { scheduleBookings = []; scheduleVerifiedAt = nil }
        scheduleInterval = interval
        scheduleReadState = .loading
        var collected: [Booking] = []
        var page = ListPageRequest.first
        do {
            guard interval.duration > 0, interval.duration <= 31 * 86400 else { throw BookingRepositoryError.invalidInput }
            while true {
                let result = try await repository.bookings(participantID: participantID, role: role, interval: interval, page: page)
                try Task.checkCancellation()
                guard scheduleReadID == operation else { return }
                guard result.items.allSatisfy({
                    (role == .customer ? $0.customerID : $0.groomerID) == participantID
                        && Self.overlaps($0, interval: interval) && !$0.status.isCancellation
                }) else { throw BookingRepositoryError.unavailable }
                let merged = ListPageMerge.appendingUnique(result.items, to: collected)
                guard !result.hasMore || merged.count > collected.count else { throw BookingRepositoryError.unavailable }
                collected = merged
                guard let next = result.nextRequest else { break }
                page = next
            }
            guard scheduleReadID == operation else { return }
            scheduleBookings = collected.sortedByScheduledStart(ascending: true)
            scheduleReadState = .complete
            scheduleVerifiedAt = Date()
            for booking in collected { if !replace(booking) { bookings.append(booking) } }
        } catch {
            guard scheduleReadID == operation else { return }
            scheduleReadState = scheduleVerifiedAt == nil ? .failed : .stale
        }
    }

    private static func overlaps(_ booking: Booking, interval: DateInterval) -> Bool {
        guard let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
              let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd) else { return false }
        return start < interval.end && end > interval.start
    }

    func loadNearest(now: Date = Date()) async {
        let operation = UUID()
        nearestReadID = operation
        nearestReadState = .loading
        nearestReadError = nil
        do {
            let booking = try await repository.nearestBooking(participantID: participantID, role: role, now: now)
            try Task.checkCancellation()
            guard nearestReadID == operation else { return }
            guard booking == nil || (role == .customer ? booking?.customerID : booking?.groomerID) == participantID else {
                throw BookingRepositoryError.notAllowed
            }
            nearestBooking = booking
            nearestReadState = .complete
            if let booking, !replace(booking) { bookings.append(booking) }
        } catch {
            guard nearestReadID == operation else { return }
            nearestReadState = nearestBooking == nil ? .failed : .stale
            nearestReadError = "The next appointment could not be verified. Refresh to try again."
        }
    }

    func load() async {
        guard sessionIsCurrent(), !Task.isCancelled else { return }
        guard !isLoading, !isLoadingMore else { needsListRefresh = true; return }
        needsListRefresh = false
        let generation = listGeneration

        let startedAt = Date()
        recordStoreStart("load")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; scheduleListRefreshIfNeeded() }

        do {
            let page = try await repository.bookings(
                participantID: participantID,
                role: role,
                page: .first
            )
            try Task.checkCancellation()
            guard sessionIsCurrent(), generation == listGeneration else { return }
            guard page.items.allSatisfy(owns) else { throw BookingRepositoryError.notAllowed }
            // A page does not establish absence of an individually verified booking.
            let retained = bookings.filter { synchronizedBookingIDs.contains($0.id) }
            bookings = ListPageMerge.appendingUnique(retained, to: page.items)
            nextPageRequest = page.nextRequest
            await loadScheduleCalendar()
            try Task.checkCancellation()
            guard sessionIsCurrent(), generation == listGeneration else { return }
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
            guard sessionIsCurrent(), generation == listGeneration else { return }
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
            guard sessionIsCurrent(), generation == listGeneration else { return }
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
        guard sessionIsCurrent(), !Task.isCancelled, !isLoading,
              !isLoadingMore,
              let pageRequest = nextPageRequest else { return }

        let startedAt = Date()
        let generation = listGeneration
        recordStoreStart("loadNextPage")
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false; scheduleListRefreshIfNeeded() }

        do {
            let page = try await repository.bookings(
                participantID: participantID,
                role: role,
                page: pageRequest
            )
            try Task.checkCancellation()
            guard sessionIsCurrent(), generation == listGeneration else { return }
            guard page.items.allSatisfy(owns) else { throw BookingRepositoryError.notAllowed }
            for booking in page.items { replace(booking) }
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
            guard sessionIsCurrent(), generation == listGeneration else { return }
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
            guard sessionIsCurrent(), generation == listGeneration else { return }
            errorMessage = message(for: .unavailable, action: "load")
            recordStoreFailure(
                "loadNextPage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func pendingFulfillmentOperation(for bookingID: UUID) -> BookingFulfillmentOperation? {
        pendingFulfillment[bookingID]
    }

    func fulfillmentActions(for booking: Booking, now: Date = Date()) -> [BookingFulfillmentAction] {
        guard pendingFulfillment[booking.id] == nil, pendingReschedules[booking.id] == nil else { return [] }
        return booking.fulfillmentActions(for: role, participantID: participantID, now: now)
    }

    func loadFulfillmentHistory(for bookingID: UUID) async {
        guard booking(withID: bookingID)?.fulfillment != nil else { return }
        do {
            fulfillmentHistory[bookingID] = try await repository.fulfillmentEvents(bookingID: bookingID)
            fulfillmentHistoryErrors[bookingID] = nil
        } catch {
            fulfillmentHistoryErrors[bookingID] = "Service activity could not be loaded."
        }
    }

    func refreshFulfillment(for bookingID: UUID) async {
        do {
            guard let current = try await repository.bookings(bookingIDs: [bookingID]).first,
                  current.id == bookingID,
                  (role == .customer ? current.customerID : current.groomerID) == participantID else {
                throw BookingRepositoryError.unavailable
            }
            synchronizeExternalBooking(current)
            errorMessage = nil
            await loadFulfillmentHistory(for: bookingID)
        } catch {
            errorMessage = "The current service outcome could not be refreshed. Existing details may be out of date."
        }
    }

    func performFulfillment(_ action: BookingFulfillmentAction, for booking: Booking, note: String? = nil) async {
        guard !isMutatingFulfillment, !isMutatingReschedule, pendingReschedules[booking.id] == nil else { return }
        guard pendingFulfillment[booking.id] == nil else {
            errorMessage = "Check the previous operation before changing this booking."
            return
        }
        guard let revision = booking.fulfillment?.revision,
              fulfillmentActions(for: booking).contains(action) else {
            errorMessage = BookingFulfillmentRejection.unavailable.message
            return
        }
        let normalizedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!action.requiresNote || normalizedNote?.isEmpty == false), (normalizedNote?.count ?? 0) <= 500 else {
            errorMessage = BookingFulfillmentRejection.noteRequired.message
            return
        }
        let operation = BookingFulfillmentOperation(id: UUID(), bookingID: booking.id,
            expectedRevision: revision, action: action, note: normalizedNote?.isEmpty == false ? normalizedNote : nil)
        pendingFulfillment[booking.id] = operation
        do { try persistFulfillmentOperations() }
        catch {
            pendingFulfillment[booking.id] = nil
            errorMessage = "The operation could not be saved for safe recovery. No change was sent."
            return
        }
        await runFulfillment(operation, lookupFirst: false, retryIfMissing: true)
    }

    func recoverFulfillment(for bookingID: UUID, retryIfMissing: Bool = false) async {
        guard !isMutatingFulfillment, !isMutatingReschedule, let operation = pendingFulfillment[bookingID] else { return }
        await runFulfillment(operation, lookupFirst: true, retryIfMissing: retryIfMissing)
    }

    private func runFulfillment(_ operation: BookingFulfillmentOperation, lookupFirst: Bool, retryIfMissing: Bool) async {
        isMutatingFulfillment = true
        errorMessage = nil
        noticeMessage = nil
        defer { isMutatingFulfillment = false }
        do {
            var result: BookingFulfillmentResult?
            if lookupFirst { result = try await repository.fulfillmentOperation(id: operation.id) }
            if result == nil && retryIfMissing { result = try await repository.mutateFulfillment(operation) }
            guard let result else {
                noticeMessage = "No recorded outcome yet. The original action remains available to retry."
                return
            }
            guard result.receipt.operationID == operation.id, result.receipt.bookingID == operation.bookingID,
                  result.receipt.action == operation.action, result.booking.id == operation.bookingID,
                  (role == .customer ? result.booking.customerID : result.booking.groomerID) == participantID,
                  result.booking.fulfillment != nil else { throw BookingRepositoryError.unavailable }
            let current = booking(withID: operation.bookingID)?.applyingFulfillment(result.booking) ?? result.booking
            synchronizeExternalBooking(current)
            pendingFulfillment[operation.bookingID] = nil
            try persistFulfillmentOperations()
            noticeMessage = "Booking status verified: \(current.fulfillmentTitle)."
            if current.fulfillment?.phase != .scheduled {
                await appointmentReminderScheduler.cancelReminder(for: current.id, role: role)
            }
            await loadFulfillmentHistory(for: current.id)
        } catch let error as BookingRepositoryError {
            switch error {
            case .networkUnavailable, .unavailable, .cancelled:
                errorMessage = "The outcome is not confirmed yet. Check booking status before retrying the original action."
            default:
                pendingFulfillment[operation.bookingID] = nil
                try? persistFulfillmentOperations()
                errorMessage = message(for: error, action: "update")
                if let current = try? await repository.bookings(bookingIDs: [operation.bookingID]).first,
                   current.id == operation.bookingID,
                   (role == .customer ? current.customerID : current.groomerID) == participantID {
                    synchronizeExternalBooking(current)
                }
            }
        } catch {
            errorMessage = "The outcome is not confirmed yet. Check booking status before retrying the original action."
        }
    }

    private func persistFulfillmentOperations() throws {
        let key = "beckon.fulfillment.\(participantID).\(role.rawValue)"
        if pendingFulfillment.isEmpty { fulfillmentDefaults.removeObject(forKey: key) }
        else { fulfillmentDefaults.set(try JSONEncoder().encode(Array(pendingFulfillment.values)), forKey: key) }
    }

    func pendingRescheduleOperation(for bookingID: UUID) -> BookingRescheduleOperation? {
        pendingReschedules[bookingID]
    }

    func rescheduleActions(for booking: Booking, now: Date = Date()) -> [BookingRescheduleAction] {
        guard pendingReschedules[booking.id] == nil, pendingFulfillment[booking.id] == nil,
              (role == .customer ? booking.customerID : booking.groomerID) == participantID,
              let snapshot = rescheduleSnapshots[booking.id] else { return [] }
        if let proposal = snapshot.proposal, proposal.currentStatus(for: booking, now: now) == .pending {
            return proposal.actions(for: booking, participantID: participantID, now: now)
        }
        return booking.canProposeReschedule(now: now) ? [.propose] : []
    }

    func loadReschedule(for bookingID: UUID) async {
        do {
            let result = try await repository.reschedule(bookingID: bookingID)
            try applyReschedule(result, bookingID: bookingID)
            rescheduleErrors[bookingID] = nil
        } catch {
            rescheduleErrors[bookingID] = "Time changes could not be refreshed. The current appointment remains in place."
        }
    }

    func performReschedule(_ action: BookingRescheduleAction, for booking: Booking,
        reviewedProposal: BookingRescheduleProposal? = nil, newStart: Date? = nil) async {
        guard !isMutatingReschedule, !isMutatingFulfillment,
              rescheduleActions(for: booking).contains(action), let revision = booking.fulfillment?.revision else { return }
        if action == .propose && newStart == nil { return }
        let proposalID: UUID
        if action == .propose { proposalID = UUID() }
        else if let reviewedProposal, reviewedProposal.id == rescheduleSnapshots[booking.id]?.proposal?.id {
            proposalID = reviewedProposal.id
        }
        else {
            rescheduleErrors[booking.id] = "The time proposal has changed. Review the current proposal before responding."
            return
        }
        let operation = BookingRescheduleOperation(id: UUID(), bookingID: booking.id,
            expectedRevision: revision, proposalID: proposalID, action: action,
            newStart: action == .propose ? newStart.map(GroomingRequestDateFormatting.serverString(from:)) : nil)
        pendingReschedules[booking.id] = operation
        do { try persistRescheduleOperations() }
        catch {
            pendingReschedules[booking.id] = nil
            rescheduleErrors[booking.id] = "The time change could not be saved for recovery. Nothing was submitted."
            return
        }
        await runReschedule(operation, lookupFirst: false, retryIfMissing: true)
    }

    func recoverReschedule(for bookingID: UUID, retryIfMissing: Bool = false) async {
        guard !isMutatingReschedule, !isMutatingFulfillment, let operation = pendingReschedules[bookingID] else { return }
        await runReschedule(operation, lookupFirst: true, retryIfMissing: retryIfMissing)
    }

    private func runReschedule(_ operation: BookingRescheduleOperation, lookupFirst: Bool, retryIfMissing: Bool) async {
        isMutatingReschedule = true
        rescheduleErrors[operation.bookingID] = nil
        defer { isMutatingReschedule = false }
        do {
            var result: BookingRescheduleResult?
            if lookupFirst { result = try await repository.rescheduleOperation(id: operation.id) }
            if result == nil && retryIfMissing { result = try await repository.mutateReschedule(operation) }
            guard let result else {
                rescheduleErrors[operation.bookingID] = "No recorded result yet. The original operation remains available to retry."
                return
            }
            guard let receipt = result.receipt, receipt.operationID == operation.id,
                  receipt.bookingID == operation.bookingID, receipt.proposalID == operation.proposalID,
                  receipt.action == operation.action, result.proposal?.id == operation.proposalID else {
                throw BookingRepositoryError.unavailable
            }
            let previous = booking(withID: operation.bookingID)
            try applyReschedule(result, bookingID: operation.bookingID)
            pendingReschedules[operation.bookingID] = nil
            try persistRescheduleOperations()
            noticeMessage = result.proposal?.currentStatus(for: result.booking).title
            if previous?.scheduledStart != result.booking.scheduledStart || previous?.status != result.booking.status {
                await appointmentReminderScheduler.cancelReminder(for: result.booking.id, role: role)
                let reminderResult = await appointmentReminderScheduler.syncReminders(for: [result.booking], role: role)
                if case .scheduled = reminderResult { appointmentReminderNotice = nil }
                else { appointmentReminderNotice = "The appointment changed, but its local reminder could not be updated." }
            }
        } catch let error as BookingRepositoryError {
            switch error {
            case .networkUnavailable, .unavailable, .cancelled:
                rescheduleErrors[operation.bookingID] = "The time-change result is not verified. Check its status before retrying."
            default:
                pendingReschedules[operation.bookingID] = nil
                try? persistRescheduleOperations()
                await loadReschedule(for: operation.bookingID)
                rescheduleErrors[operation.bookingID] = message(for: error, action: "change time")
            }
        } catch {
            rescheduleErrors[operation.bookingID] = "The time-change result is not verified. Check its status before retrying."
        }
    }

    private func applyReschedule(_ result: BookingRescheduleResult, bookingID: UUID) throws {
        guard result.booking.id == bookingID,
              (role == .customer ? result.booking.customerID : result.booking.groomerID) == participantID,
              result.booking.fulfillment != nil,
              result.proposal == nil || result.proposal?.bookingID == bookingID else { throw BookingRepositoryError.unavailable }
        let current = booking(withID: bookingID)?.applyingReschedule(result.booking) ?? result.booking
        synchronizeExternalBooking(current)
        rescheduleSnapshots[bookingID] = result
    }

    private func persistRescheduleOperations() throws {
        let key = "beckon.reschedule.\(participantID).\(role.rawValue)"
        if pendingReschedules.isEmpty { fulfillmentDefaults.removeObject(forKey: key) }
        else { fulfillmentDefaults.set(try JSONEncoder().encode(Array(pendingReschedules.values)), forKey: key) }
    }

    func cancel(_ booking: Booking) async {
        if booking.fulfillment != nil {
            await performFulfillment(.cancel, for: booking)
            return
        }
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

            try Task.checkCancellation()
            guard sessionIsCurrent() else { return }
            let wasLoaded = self.booking(withID: booking.id) != nil
            if wasLoaded {
                synchronizeExternalBooking(updatedBooking)
                noticeMessage = "Booking cancelled. The original request and offers remain closed."
            } else {
                invalidateList()
                scheduleListRefreshIfNeeded()
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
        if booking.fulfillment != nil {
            await performFulfillment(.complete, for: booking)
            return
        }
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

            try Task.checkCancellation()
            guard sessionIsCurrent() else { return }
            let wasLoaded = self.booking(withID: booking.id) != nil
            if wasLoaded {
                synchronizeExternalBooking(updatedBooking)
                noticeMessage = "Booking completed. The customer can now leave one review."
            } else {
                invalidateList()
                scheduleListRefreshIfNeeded()
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

            try Task.checkCancellation()
            guard sessionIsCurrent() else { return }
            let wasLoaded = self.booking(withID: booking.id) != nil
            if wasLoaded {
                synchronizeExternalBooking(updatedBooking)
                noticeMessage = "Review submitted. Thank you for your feedback."
            } else {
                invalidateList()
                scheduleListRefreshIfNeeded()
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
            "The groomer needs to send a new offer with current agreement details before you can book."
        case .clientUpdateRequired:
            "Update Beckon to confirm versioned appointment details. No booking was made."
        case .matchConstraintsChanged:
            "The groomer's current service or location no longer fits this request. No booking was made."
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
        case .fulfillmentRejected(let rejection):
            rejection.message
        case .rescheduleRejected(let message):
            message
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
