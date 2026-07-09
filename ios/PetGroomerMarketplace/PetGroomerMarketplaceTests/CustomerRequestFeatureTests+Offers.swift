import Foundation
import Testing
@testable import PetGroomerMarketplace

extension CustomerRequestsStoreTests {
    @Test @MainActor
    func offerPaginationRetriesThenAppendsUniqueRowsAndStopsAtLastPage() async {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let first = Self.offerReview(
            customerID: customerID,
            requestID: request.id,
            createdAt: "2026-06-20T14:00:00Z"
        )
        let second = Self.offerReview(
            customerID: customerID,
            requestID: request.id,
            createdAt: "2026-06-20T13:00:00Z"
        )
        let repository = CustomerRequestRepositoryFake(
            offerPages: [
                .success(ListPage(items: [first], request: .first, hasMore: true)),
                .failure(.networkUnavailable),
                .success(
                    ListPage(
                        items: [first, second],
                        request: .first.next,
                        hasMore: false
                    )
                ),
            ]
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.loadOffers(for: request)
        await store.loadNextOffersPage(for: request)

        #expect(store.offers(for: request).map(\.id) == [first.id])
        #expect(store.canLoadMoreOffers(for: request) == true)
        #expect(store.offerError(for: request) == "Check your connection and try again.")

        await store.loadNextOffersPage(for: request)

        #expect(repository.receivedOfferPages == [.first, .first.next, .first.next])
        #expect(store.offers(for: request).map(\.id) == [first.id, second.id])
        #expect(store.canLoadMoreOffers(for: request) == false)
    }

    @Test @MainActor
    func loadOffersPopulatesOfferReviewsForRequest() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let offerReview = Self.offerReview(
            customerID: customerID,
            requestID: request.id
        )
        let repository = CustomerRequestRepositoryFake(
            offersResult: .success([offerReview])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.loadOffers(for: request)

        #expect(repository.offersCallCount == 1)
        #expect(repository.lastOfferCustomerID == customerID)
        #expect(repository.lastOfferRequestID == request.id)
        #expect(store.offers(for: request) == [offerReview])
        #expect(store.offerError(for: request) == nil)
    }

    @Test @MainActor
    func loadOffersOrdersPendingBeforeHistoricalOffers() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let withdrawnOffer = Self.offerReview(
            customerID: customerID,
            requestID: request.id,
            status: .withdrawnByGroomer,
            createdAt: "2026-06-20T14:00:00Z"
        )
        let pendingOffer = Self.offerReview(
            customerID: customerID,
            requestID: request.id,
            status: .pending,
            createdAt: "2026-06-20T13:00:00Z"
        )
        let repository = CustomerRequestRepositoryFake(
            offersResult: .success([withdrawnOffer, pendingOffer])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.loadOffers(for: request)

        #expect(store.offers(for: request).map(\.offer.status) == [
            .pending,
            .withdrawnByGroomer,
        ])
    }

    @Test @MainActor
    func offerReviewFitEvidencePresentationUsesExplanationFirstCopyWithoutRawScore() {
        let offerReview = Self.offerReview(
            customerID: UUID(),
            requestID: UUID(),
            matchScore: 94.4,
            matchReason: """
            Same city and service location. Pet-fit evidence: completed poodle coats.
            """
        )

        let presentation = offerReview.fitEvidencePresentation

        #expect(presentation?.scoreText == nil)
        #expect(
            presentation?.reason
                == "Same city and service location. Pet-fit evidence: completed poodle coats."
        )
        #expect(
            presentation?.listSummary
                == "Location And Service Fit: Same city and service location. Earned Evidence: completed poodle coats."
        )
    }

    @Test @MainActor
    func offerReviewFitEvidencePresentationIgnoresBlankReason() {
        let offerReview = Self.offerReview(
            customerID: UUID(),
            requestID: UUID(),
            matchScore: 91,
            matchReason: "   \n  "
        )

        #expect(offerReview.fitEvidencePresentation == nil)
    }

    @Test @MainActor
    func loadOffersFailureIsScopedToRequest() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let repository = CustomerRequestRepositoryFake(
            offersResult: .failure(.networkUnavailable)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.loadOffers(for: request)

        #expect(repository.offersCallCount == 1)
        #expect(store.offers(for: request).isEmpty)
        #expect(store.offerError(for: request) == "Check your connection and try again.")
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func acceptOfferCallsBookingRPCAndRefreshesRequestAndOffers() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
        let acceptedOfferID = UUID()
        let competingOfferID = UUID()
        let acceptedPending = Self.offerReview(
            offerID: acceptedOfferID,
            customerID: customerID,
            requestID: request.id
        )
        let competingPending = Self.offerReview(
            offerID: competingOfferID,
            customerID: customerID,
            requestID: request.id
        )
        let acceptedFinal = Self.offerReview(
            offerID: acceptedOfferID,
            customerID: customerID,
            requestID: request.id,
            status: .acceptedByCustomer
        )
        let competingFinal = Self.offerReview(
            offerID: competingOfferID,
            customerID: customerID,
            requestID: request.id,
            status: .declinedByCustomer
        )
        let acceptedBooking = Self.booking(
            requestID: request.id,
            customerID: customerID
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request]),
            offersResult: .success([acceptedPending, competingPending])
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            bookingsResult: .success([acceptedBooking]),
            acceptResult: .success(
                AcceptGroomerOfferResult(
                    bookingID: acceptedBooking.id,
                    conversationID: UUID(),
                    requestID: request.id,
                    offerID: acceptedOfferID,
                    bookingStatus: .confirmed,
                    offerStatus: .acceptedByCustomer,
                    requestStatus: .booked
                )
            )
        )
        let scheduler = CustomerRequestAppointmentReminderSchedulerFake()
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: bookingRepository,
            appointmentReminderScheduler: scheduler
        )
        await store.load()
        await store.loadOffers(for: request)

        requestRepository.requestsResult = .success([
            request.replacing(status: .booked),
        ])
        requestRepository.offersResult = .success([
            acceptedFinal,
            competingFinal,
        ])

        await store.accept(offerReview: acceptedPending, for: request)

        #expect(bookingRepository.acceptCallCount == 1)
        #expect(bookingRepository.lastAcceptedOfferID == acceptedOfferID)
        #expect(requestRepository.requestsCallCount == 2)
        #expect(requestRepository.offersCallCount == 2)
        #expect(store.request(withID: request.id)?.status == .booked)
        let statusesByOfferID = Dictionary(
            uniqueKeysWithValues: store.offers(for: request).map {
                ($0.offer.id, $0.offer.status)
            }
        )
        #expect(statusesByOfferID[acceptedOfferID] == .acceptedByCustomer)
        #expect(statusesByOfferID[competingOfferID] == .declinedByCustomer)
        #expect(store.noticeMessage == "Offer accepted. Booking confirmed.")
        #expect(scheduler.syncCallCount == 1)
        #expect(scheduler.lastSyncedBookings == [acceptedBooking])
        #expect(scheduler.lastSyncedRole == .customer)
    }

    @Test @MainActor
    func acceptOfferConflictExplainsNoLocalBooking() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let offerReview = Self.offerReview(
            customerID: customerID,
            requestID: request.id
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            acceptResult: .failure(.bookingConflict)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: bookingRepository
        )

        await store.accept(offerReview: offerReview, for: request)

        #expect(bookingRepository.acceptCallCount == 1)
        #expect(
            store.errorMessage ==
                "That groomer is no longer available at the proposed time."
        )
        #expect(store.noticeMessage == nil)
    }

    @Test @MainActor
    func acceptOfferWithMissingLocalStateReportsRefreshHint() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let offerReview = Self.offerReview(
            customerID: customerID,
            requestID: request.id
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            acceptResult: .success(
                AcceptGroomerOfferResult(
                    bookingID: UUID(),
                    conversationID: UUID(),
                    requestID: request.id,
                    offerID: offerReview.offer.id,
                    bookingStatus: .confirmed,
                    offerStatus: .acceptedByCustomer,
                    requestStatus: .booked
                )
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: bookingRepository
        )

        await store.accept(offerReview: offerReview, for: request)

        #expect(bookingRepository.acceptCallCount == 1)
        #expect(
            store.noticeMessage ==
                "Offer accepted. Booking confirmed. Refresh this request if the offer state does not update."
        )
    }

}
