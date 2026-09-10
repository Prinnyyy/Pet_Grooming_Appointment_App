import Foundation
import Testing
@testable import Beckon

@MainActor
struct BookingScopedReadTests {
    @Test(arguments: [BookingRepositoryError.networkUnavailable, .cancelled])
    func failedRefreshRetainsCommittedBookingAndExplicitRetryRestoresPaging(failure: BookingRepositoryError) async {
        let owner = UUID()
        let accepted = CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner)
        let repository = BookingRepositoryFake(bookingPages: [
            .success(ListPage(items: [], request: .first, hasMore: true))
        ])
        let store = BookingsStore(participantID: owner, role: .customer, repository: repository,
            appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        await store.load()
        #expect(store.nextPageRequest != nil)
        repository.pageRead = { _ in throw failure }
        store.synchronizeExternalBooking(accepted)
        while repository.receivedBookingPages.count < 2 || store.isLoading { await Task.yield() }
        #expect(store.bookings == [accepted])
        #expect(store.nextPageRequest == nil)
        #expect(repository.receivedBookingPages == [.first, .first])
        repository.pageRead = { page in ListPage(items: [accepted], request: page, hasMore: true) }
        await store.load()
        #expect(store.bookings == [accepted])
        #expect(store.nextPageRequest == .first.next)
        #expect(store.errorMessage == nil)
        #expect(repository.receivedBookingPages == [.first, .first, .first])
    }

    @Test func lateExactReadCannotUndoCommittedCancellation() async {
        let owner = UUID()
        let original = CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner)
        let cancelled = original.replacing(status: .cancelledByCustomer, cancelledBy: owner, cancelledAt: original.updatedAt)
        var continuation: CheckedContinuation<[Booking], any Error>?
        let repository = BookingRepositoryFake()
        repository.exactRead = { _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        let store = BookingsStore(participantID: owner, role: .customer, repository: repository,
            initialBookings: [original], appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        let read = Task { await store.resolveBooking(id: original.id, forceRefresh: true) }
        while continuation == nil { await Task.yield() }
        store.synchronizeExternalBooking(cancelled)
        continuation?.resume(returning: [original])
        await read.value
        #expect(store.booking(withID: original.id)?.status == .cancelledByCustomer)
    }

    @Test func lateNextPageCannotOverwriteSynchronizedBooking() async {
        let owner = UUID()
        let original = CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner)
        let cancelled = original.replacing(status: .cancelledByCustomer, cancelledBy: owner, cancelledAt: original.updatedAt)
        let repository = BookingRepositoryFake(bookingPages: [.success(ListPage(items: [original], request: .first, hasMore: true))])
        let store = BookingsStore(participantID: owner, role: .customer, repository: repository,
            appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        await store.load()
        var continuation: CheckedContinuation<ListPage<Booking>, any Error>?
        repository.pageRead = { page in
            if page == .first { return ListPage(items: [cancelled], request: page, hasMore: false) }
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }
        let read = Task { await store.loadNextPage() }
        while continuation == nil { await Task.yield() }
        store.synchronizeExternalBooking(cancelled)
        continuation?.resume(returning: ListPage(items: [original], request: .first.next, hasMore: true))
        await read.value
        #expect(store.booking(withID: original.id)?.status == .cancelledByCustomer)
        #expect(store.nextPageRequest == nil)
        #expect(store.bookings.count == 1)
    }

    @Test func sessionChangeDiscardsLateListAndForeignSynchronization() async {
        let owner = UUID()
        let booking = CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner)
        var active = true
        let repository = BookingRepositoryFake()
        repository.pageRead = { page in
            active = false
            return ListPage(items: [booking], request: page, hasMore: false)
        }
        let store = BookingsStore(participantID: owner, role: .customer, repository: repository,
            appointmentReminderScheduler: AppointmentReminderSchedulerFake(), sessionIsCurrent: { active })
        await store.load()
        store.synchronizeExternalBooking(booking)
        #expect(store.bookings.isEmpty)
    }

    @Test func acceptedBookingSurvivesLateFirstPage() async {
        let owner = UUID()
        let accepted = CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner)
        var continuation: CheckedContinuation<ListPage<Booking>, any Error>?
        let repository = BookingRepositoryFake()
        repository.pageRead = { page in
            if repository.receivedBookingPages.count == 1 {
                return try await withCheckedThrowingContinuation { continuation = $0 }
            }
            throw BookingRepositoryError.networkUnavailable
        }
        let store = BookingsStore(participantID: owner, role: .customer, repository: repository,
            appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        let old = Task { await store.load() }
        while continuation == nil { await Task.yield() }
        store.synchronizeExternalBooking(accepted)
        continuation?.resume(returning: ListPage(items: [], request: .first, hasMore: false))
        await old.value
        #expect(store.booking(withID: accepted.id) == accepted)
    }

    @Test func firstPageAbsenceDoesNotDeleteSynchronizedBookingAndForeignRowsAreRejected() async {
        let owner = UUID()
        let accepted = CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner)
        let foreign = CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: UUID())
        let store = BookingsStore(participantID: owner, role: .customer, repository: BookingRepositoryFake(),
            appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        store.synchronizeExternalBooking(accepted)
        store.synchronizeExternalBooking(foreign)
        await store.load()
        #expect(store.bookings == [accepted])
    }

    @Test func customerHomeReadsNearestIndependentlyOfHistoryAndReportsStaleFailure() async {
        let owner = UUID()
        let now = ISO8601DateFormatter().date(from: "2026-06-24T00:00:00Z")!
        let rows = (0..<55).map { _ in CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner) }
            .sortedByScheduledStart(ascending: true)
        let repository = BookingRepositoryFake(bookingsResult: .success(Array(rows.reversed())))
        let store = BookingsStore(participantID: owner, role: .customer,
            repository: DebugBookingRepository(base: repository, debugRecorder: nil))
        await store.loadNearest(now: now)
        #expect(store.nearestBooking?.id == rows[0].id)
        #expect(store.nearestReadState == .complete)
        #expect(repository.nearestCallCount == 1)
        #expect(repository.bookingsCallCount == 0)
        repository.bookingsResult = .failure(.networkUnavailable)
        await store.loadNearest(now: now)
        #expect(store.nearestReadState == .stale)
        #expect(store.nearestBooking?.id == rows[0].id)
        #expect(store.nearestReadError != nil)
    }

    @Test func actualDebugCompositionPreservesLifecycleReaders() async throws {
        let booking = try BookingRescheduleTests.booking()
        let base = BookingRepositoryFake()
        base.rescheduleResult = .success(BookingRescheduleResult(booking: booking, proposal: nil, receipt: nil))
        let repository: any BookingRepository = DebugBookingRepository(base: base, debugRecorder: nil)
        #expect(try await repository.reschedule(bookingID: booking.id).booking.id == booking.id)
        #expect(try await repository.fulfillmentEvents(bookingID: booking.id).isEmpty)
        #expect(try await repository.fulfillmentOperation(id: UUID()) == nil)
        #expect(try await repository.rescheduleOperation(id: UUID()) == nil)
    }

    @Test func allDatePagesAreRequiredBeforeConfirmingTheDay() async {
        let owner = UUID()
        let rows = (0..<55).map { _ in CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner) }
        let interval = DateInterval(start: ISO8601DateFormatter().date(from: "2026-06-24T00:00:00Z")!, duration: 86400)
        let repository = BookingRepositoryFake()
        repository.datePages = [.success(ListPage(items: Array(rows.prefix(51)), request: .first)),
            .success(ListPage(items: Array(rows.suffix(5)), request: .first.next))]
        let store = BookingsStore(participantID: owner, role: .customer,
            repository: DebugBookingRepository(base: repository, debugRecorder: nil),
            appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        await store.loadSchedule(interval: interval)
        #expect(store.scheduleReadState == .complete)
        #expect(store.scheduleBookings.count == 55)
        #expect(repository.datePageRequests == [.first, .first.next])
        #expect(store.scheduleVerifiedAt != nil)
        #expect(store.scheduleBookings.map(\.id) == rows.sortedByScheduledStart(ascending: true).map(\.id))
        repository.datePages = [.failure(.networkUnavailable)]
        await store.loadSchedule(interval: interval)
        #expect(store.scheduleReadState == .stale)
        #expect(store.scheduleBookings.count == 55)
    }

    @Test func failedLaterPageCannotProduceAnEmptyOrCompleteDay() async {
        let owner = UUID()
        let rows = (0..<51).map { _ in CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner) }
        let interval = DateInterval(start: ISO8601DateFormatter().date(from: "2026-06-24T00:00:00Z")!, duration: 86400)
        let repository = BookingRepositoryFake()
        repository.datePages = [.success(ListPage(items: rows, request: .first)), .failure(.networkUnavailable)]
        let store = BookingsStore(participantID: owner, role: .customer,
            repository: DebugBookingRepository(base: repository, debugRecorder: nil))
        await store.loadSchedule(interval: interval)
        #expect(store.scheduleReadState == .failed)
        #expect(store.scheduleVerifiedAt == nil)
    }

    @Test func lateOldDayCannotOverwriteTheNewDay() async {
        let first = DateInterval(start: Date(), duration: 86400)
        let second = DateInterval(start: first.end, duration: 86400)
        var continuation: CheckedContinuation<ListPage<Booking>, any Error>?
        let repository = BookingRepositoryFake()
        repository.dateRead = { interval, page in
            if interval == first { return try await withCheckedThrowingContinuation { continuation = $0 } }
            return ListPage(items: [], request: page)
        }
        let store = BookingsStore(participantID: UUID(), role: .groomer, repository: repository)
        let old = Task { await store.loadSchedule(interval: first) }
        while continuation == nil { await Task.yield() }
        await store.loadSchedule(interval: second)
        continuation?.resume(returning: ListPage(items: [], request: .first))
        await old.value
        #expect(store.scheduleInterval == second)
        #expect(store.scheduleReadState == .complete)
    }

    @Test func exactLookupLoadsAnUnlistedBookingAndRejectsForeignOwnership() async {
        let owner = UUID()
        let booking = CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: owner)
        let repository = BookingRepositoryFake(bookingsResult: .success([booking]))
        let store = BookingsStore(participantID: owner, role: .customer, repository: repository)
        await store.resolveBooking(id: booking.id)
        #expect(store.booking(withID: booking.id)?.id == booking.id)
        let foreign = BookingsStore(participantID: UUID(), role: .customer, repository: repository)
        await foreign.resolveBooking(id: booking.id)
        #expect(foreign.booking(withID: booking.id) == nil)
        #expect(foreign.bookingReadStates[booking.id] == .failed)
    }
}
