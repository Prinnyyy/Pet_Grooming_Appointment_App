import Foundation
import Testing
@testable import PetGroomerMarketplace

struct BookingsStoreTests {
    @Test @MainActor
    func loadFetchesRoleSpecificBookings() async throws {
        let participantID = UUID()
        let booking = Self.booking(customerID: participantID)
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking])
        )
        let store = BookingsStore(
            participantID: participantID,
            role: .customer,
            repository: repository
        )

        await store.load()

        #expect(repository.bookingsCallCount == 1)
        #expect(repository.lastParticipantID == participantID)
        #expect(repository.lastRole == .customer)
        #expect(store.bookings == [booking])
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func cancelConfirmedBookingUpdatesLocalStatus() async throws {
        let customerID = UUID()
        let booking = Self.booking(customerID: customerID)
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking]),
            cancelResult: .success(
                CancelBookingResult(
                    bookingID: booking.id,
                    bookingStatus: .cancelledByCustomer,
                    cancelledTimestamp: "2026-06-21T12:00:00Z",
                    cancelledBy: customerID
                )
            )
        )
        let store = BookingsStore(
            participantID: customerID,
            role: .customer,
            repository: repository
        )
        await store.load()

        await store.cancel(booking)

        #expect(repository.cancelCallCount == 1)
        #expect(repository.lastCancelledBookingID == booking.id)
        #expect(store.bookings.first?.status == .cancelledByCustomer)
        #expect(store.bookings.first?.cancelledBy == customerID)
        #expect(store.bookings.first?.cancelledAt == "2026-06-21T12:00:00Z")
        #expect(
            store.noticeMessage ==
                "Booking cancelled. The original request and offers remain closed."
        )
    }

    @Test @MainActor
    func nonConfirmedBookingDoesNotCallCancelRPC() async throws {
        let booking = Self.booking(status: .completed)
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking])
        )
        let store = BookingsStore(
            participantID: booking.groomerID,
            role: .groomer,
            repository: repository
        )
        await store.load()

        await store.cancel(booking)

        #expect(repository.cancelCallCount == 0)
        #expect(store.errorMessage == "This booking can no longer be cancelled.")
    }

    @Test @MainActor
    func cancelMissingLocalBookingReportsRefreshNotice() async throws {
        let customerID = UUID()
        let booking = Self.booking(customerID: customerID)
        let repository = BookingRepositoryFake(
            cancelResult: .success(
                CancelBookingResult(
                    bookingID: booking.id,
                    bookingStatus: .cancelledByCustomer,
                    cancelledTimestamp: "2026-06-21T12:00:00Z",
                    cancelledBy: customerID
                )
            )
        )
        let store = BookingsStore(
            participantID: customerID,
            role: .customer,
            repository: repository
        )

        await store.cancel(booking)

        #expect(repository.cancelCallCount == 1)
        #expect(store.bookings.isEmpty)
        #expect(
            store.noticeMessage ==
                "Booking cancelled. Refresh bookings to see the latest state. The original request and offers remain closed."
        )
    }

    @Test
    func bookingReferenceCodesUseShortStableIdentifiers() {
        let booking = Self.booking(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            requestID: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            offerID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            customerID: UUID(uuidString: "12345678-0000-0000-0000-000000000000")!,
            groomerID: UUID(uuidString: "87654321-0000-0000-0000-000000000000")!
        )

        #expect(booking.referenceCode == "11111111")
        #expect(booking.requestReferenceCode == "AAAAAAAA")
        #expect(booking.offerReferenceCode == "99999999")
        #expect(booking.participantReferenceCode(for: .customer) == "87654321")
        #expect(booking.participantReferenceCode(for: .groomer) == "12345678")
        #expect(booking.participantSummary(for: .customer) == "Groomer ref 87654321")
        #expect(booking.participantSummary(for: .groomer) == "Customer ref 12345678")
    }

    private static func booking(
        id: UUID = UUID(),
        requestID: UUID = UUID(),
        offerID: UUID = UUID(),
        customerID: UUID = UUID(),
        groomerID: UUID = UUID(),
        status: BookingStatus = .confirmed
    ) -> Booking {
        Booking(
            id: id,
            requestID: requestID,
            offerID: offerID,
            customerID: customerID,
            groomerID: groomerID,
            scheduledStart: "2026-06-22T16:00:00Z",
            scheduledEnd: "2026-06-22T18:00:00Z",
            priceEstimate: 125,
            status: status,
            cancelledBy: nil,
            cancelledAt: nil,
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z"
        )
    }
}

@MainActor
private final class BookingRepositoryFake: BookingRepository {
    var bookingsResult: Result<[Booking], BookingRepositoryError>
    var cancelResult: Result<CancelBookingResult, BookingRepositoryError>

    private(set) var bookingsCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var lastParticipantID: UUID?
    private(set) var lastRole: UserRole?
    private(set) var lastCancelledBookingID: UUID?

    init(
        bookingsResult: Result<[Booking], BookingRepositoryError> = .success([]),
        cancelResult: Result<CancelBookingResult, BookingRepositoryError> =
            .failure(.unavailable)
    ) {
        self.bookingsResult = bookingsResult
        self.cancelResult = cancelResult
    }

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        bookingsCallCount += 1
        lastParticipantID = participantID
        lastRole = role
        return try bookingsResult.get()
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        throw BookingRepositoryError.unavailable
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        cancelCallCount += 1
        lastCancelledBookingID = bookingID
        return try cancelResult.get()
    }
}
