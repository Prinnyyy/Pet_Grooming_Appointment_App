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
    func groomerCompletesConfirmedBooking() async throws {
        let groomerID = UUID()
        let booking = Self.booking(groomerID: groomerID)
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking]),
            completeResult: .success(
                CompleteBookingResult(
                    bookingID: booking.id,
                    bookingStatus: .completed,
                    completedTimestamp: "2026-06-22T18:05:00Z",
                    completedBy: groomerID
                )
            )
        )
        let store = BookingsStore(
            participantID: groomerID,
            role: .groomer,
            repository: repository
        )
        await store.load()

        await store.complete(booking)

        #expect(repository.completeCallCount == 1)
        #expect(repository.lastCompletedBookingID == booking.id)
        #expect(store.bookings.first?.status == .completed)
        #expect(store.bookings.first?.completedAt == "2026-06-22T18:05:00Z")
        #expect(store.bookings.first?.completedBy == groomerID)
        #expect(
            store.noticeMessage ==
                "Booking completed. The customer can now leave one review."
        )
    }

    @Test @MainActor
    func customerSubmitsReviewForCompletedBooking() async throws {
        let customerID = UUID()
        let booking = Self.booking(
            customerID: customerID,
            status: .completed,
            completedAt: "2026-06-22T18:05:00Z"
        )
        let review = BookingReview(
            id: UUID(),
            bookingID: booking.id,
            customerID: booking.customerID,
            groomerID: booking.groomerID,
            rating: 5,
            content: "Great service",
            createdAt: "2026-06-22T19:00:00Z"
        )
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking]),
            reviewResult: .success(
                CreateReviewResult(
                    review: review,
                    groomerRatingAverage: 5,
                    groomerRatingCount: 1
                )
            )
        )
        let store = BookingsStore(
            participantID: customerID,
            role: .customer,
            repository: repository
        )
        await store.load()

        await store.createReview(
            for: booking,
            rating: 5,
            content: "  Great service\n"
        )

        #expect(repository.reviewCallCount == 1)
        #expect(repository.lastReviewedBookingID == booking.id)
        #expect(repository.lastReviewDraft == BookingReviewDraft(
            rating: 5,
            content: "Great service"
        ))
        #expect(store.bookings.first?.review == review)
        #expect(
            store.noticeMessage ==
                "Review submitted. Thank you for your feedback."
        )
    }

    @Test @MainActor
    func invalidReviewDoesNotCallRepository() async throws {
        let booking = Self.booking(status: .completed)
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking])
        )
        let store = BookingsStore(
            participantID: booking.customerID,
            role: .customer,
            repository: repository
        )
        await store.load()

        await store.createReview(for: booking, rating: 6, content: "")

        #expect(repository.reviewCallCount == 0)
        #expect(store.errorMessage == "Choose a rating from 1 to 5.")
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

    @Test
    func bookingPresentationUsesGroomerNameAndAppointmentLocationContext() {
        let booking = Self.booking(
            serviceType: .bathAndBrush,
            groomerBusinessName: " Ava Chen ",
            locationMode: .groomerComesToCustomer,
            customerStreetAddress: "123 Pine Street",
            customerCity: "Seattle",
            customerState: "WA",
            customerZipCode: "98101"
        )

        #expect(booking.partnerDisplayTitle(for: .customer) == "Ava Chen")
        #expect(booking.appointmentServiceTitle == "Bath & Brush")
        #expect(booking.appointmentLocationTitle == "Groomer Comes To Customer")
        #expect(booking.appointmentAddressSummary == "123 Pine Street, Seattle, WA 98101")
    }

    @Test
    func bookingPresentationUsesGroomerLocationFallbackWhenCustomerVisits() {
        let booking = Self.booking(
            groomerBusinessName: nil,
            groomerBaseCity: "Austin",
            groomerBaseState: "TX",
            locationMode: .customerComesToGroomer
        )

        #expect(booking.partnerDisplayTitle(for: .customer) == "Groomer Name")
        #expect(booking.appointmentLocationTitle == "Customer Comes To Groomer")
        #expect(booking.appointmentAddressSummary == "Austin, TX")
    }

    private static func booking(
        id: UUID = UUID(),
        requestID: UUID = UUID(),
        offerID: UUID = UUID(),
        customerID: UUID = UUID(),
        groomerID: UUID = UUID(),
        status: BookingStatus = .confirmed,
        completedAt: String? = nil,
        review: BookingReview? = nil,
        serviceType: GroomingServiceType? = nil,
        groomerBusinessName: String? = nil,
        groomerBaseCity: String? = nil,
        groomerBaseState: String? = nil,
        locationMode: GroomingLocationMode? = nil,
        customerStreetAddress: String? = nil,
        customerCity: String? = nil,
        customerState: String? = nil,
        customerZipCode: String? = nil
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
            completedAt: completedAt,
            completedBy: completedAt == nil ? nil : groomerID,
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z",
            review: review,
            serviceType: serviceType,
            groomerBusinessName: groomerBusinessName,
            groomerBaseCity: groomerBaseCity,
            groomerBaseState: groomerBaseState,
            locationMode: locationMode,
            customerStreetAddress: customerStreetAddress,
            customerCity: customerCity,
            customerState: customerState,
            customerZipCode: customerZipCode
        )
    }
}

@MainActor
private final class BookingRepositoryFake: BookingRepository {
    var bookingsResult: Result<[Booking], BookingRepositoryError>
    var cancelResult: Result<CancelBookingResult, BookingRepositoryError>
    var completeResult: Result<CompleteBookingResult, BookingRepositoryError>
    var reviewResult: Result<CreateReviewResult, BookingRepositoryError>

    private(set) var bookingsCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var completeCallCount = 0
    private(set) var reviewCallCount = 0
    private(set) var lastParticipantID: UUID?
    private(set) var lastRole: UserRole?
    private(set) var lastCancelledBookingID: UUID?
    private(set) var lastCompletedBookingID: UUID?
    private(set) var lastReviewedBookingID: UUID?
    private(set) var lastReviewDraft: BookingReviewDraft?

    init(
        bookingsResult: Result<[Booking], BookingRepositoryError> = .success([]),
        cancelResult: Result<CancelBookingResult, BookingRepositoryError> =
            .failure(.unavailable),
        completeResult: Result<CompleteBookingResult, BookingRepositoryError> =
            .failure(.unavailable),
        reviewResult: Result<CreateReviewResult, BookingRepositoryError> =
            .failure(.unavailable)
    ) {
        self.bookingsResult = bookingsResult
        self.cancelResult = cancelResult
        self.completeResult = completeResult
        self.reviewResult = reviewResult
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

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        completeCallCount += 1
        lastCompletedBookingID = bookingID
        return try completeResult.get()
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        reviewCallCount += 1
        lastReviewedBookingID = bookingID
        lastReviewDraft = draft
        return try reviewResult.get()
    }
}
