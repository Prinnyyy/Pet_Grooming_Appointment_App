import Foundation
import Testing
@testable import PetGroomerMarketplace

struct CustomerRequestsStoreTests {
    @Test @MainActor
    func loadPopulatesPetsRequestsAndDefaultSelection() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
        let petRepository = CustomerRequestPetRepositoryFake(
            petsResult: .success([pet])
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.load()

        #expect(store.pets == [pet])
        #expect(store.requests == [request])
        #expect(store.selectedPetID == pet.id)
    }

    @Test @MainActor
    func publishTrimsDraftCallsRepositoryAndReloadsRequests() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
        let petRepository = CustomerRequestPetRepositoryFake(
            petsResult: .success([pet])
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request]),
            createResult: .success(
                GroomingRequestPublishResult(
                    requestID: request.id,
                    matchCount: 2
                )
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.serviceType = " Full groom "
        store.serviceNotes = "   "
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.city = " Seattle "
        store.state = " WA "
        store.zipCode = " 98101 "

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(requestRepository.requestsCallCount == 2)
        #expect(requestRepository.lastCustomerID == customerID)
        #expect(requestRepository.lastDraft?.petID == pet.id)
        #expect(requestRepository.lastDraft?.serviceType == "Full groom")
        #expect(requestRepository.lastDraft?.serviceNotes == nil)
        #expect(requestRepository.lastDraft?.city == "Seattle")
        #expect(requestRepository.lastDraft?.state == "WA")
        #expect(requestRepository.lastDraft?.zipCode == "98101")
        #expect(store.isShowingWizard == false)
        #expect(store.noticeMessage == "Request published. 2 groomers matched.")
        #expect(store.publishResult?.matchCount == 2)
    }

    @Test @MainActor
    func invalidFormDoesNotCallRepository() async {
        let repository = CustomerRequestRepositoryFake()
        let store = CustomerRequestsStore(
            customerID: UUID(),
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.publish()

        #expect(repository.createCallCount == 0)
        #expect(store.errorMessage == "Add a pet before creating a request.")
    }

    @Test @MainActor
    func nearFutureStartTimeDoesNotCallRepository() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let repository = CustomerRequestRepositoryFake()
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.serviceType = "Bath"
        store.preferredStart = Date().addingTimeInterval(60)
        store.preferredEnd = Date().addingTimeInterval(2 * 60 * 60)
        store.city = "Seattle"
        store.state = "WA"
        store.zipCode = "98101"

        await store.publish()

        #expect(repository.createCallCount == 0)
        #expect(
            store.errorMessage ==
                "Preferred start must be at least 5 minutes from now."
        )
    }

    @Test @MainActor
    func publishFailurePreservesWizardInput() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let petRepository = CustomerRequestPetRepositoryFake(
            petsResult: .success([pet])
        )
        let requestRepository = CustomerRequestRepositoryFake(
            createResult: .failure(.requestLimitExceeded)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.serviceType = "Bath"
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(2 * 60 * 60)
        store.city = "Seattle"
        store.state = "WA"
        store.zipCode = "98101"

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(store.isShowingWizard)
        #expect(store.serviceType == "Bath")
        #expect(store.errorMessage == "You can have at most 3 open grooming requests.")
    }

    @Test @MainActor
    func cancelOpenRequestCallsRepositoryAndUpdatesLocalState() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request]),
            cancelResult: .success(
                CancelGroomingRequestResult(
                    requestID: request.id,
                    requestStatus: .cancelled,
                    cancelledTimestamp: "2026-06-22T14:00:00Z"
                )
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        await store.cancel(request)

        #expect(requestRepository.cancelCallCount == 1)
        #expect(requestRepository.lastCancelRequestID == request.id)
        #expect(store.requests.first?.status == .cancelled)
        #expect(store.noticeMessage == "Request cancelled.")
    }

    @Test @MainActor
    func cancelBookedRequestDoesNotCallRepository() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        await store.cancel(request)

        #expect(requestRepository.cancelCallCount == 0)
        #expect(store.requests.first?.status == .booked)
        #expect(store.errorMessage == "This request can no longer be cancelled.")
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
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request]),
            offersResult: .success([acceptedPending, competingPending])
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            acceptResult: .success(
                AcceptGroomerOfferResult(
                    bookingID: UUID(),
                    conversationID: UUID(),
                    requestID: request.id,
                    offerID: acceptedOfferID,
                    bookingStatus: .confirmed,
                    offerStatus: .acceptedByCustomer,
                    requestStatus: .booked
                )
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: bookingRepository
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

    private static func pet(customerID: UUID) -> CustomerPet {
        CustomerPet(
            id: UUID(),
            customerID: customerID,
            name: "Mochi",
            species: "Dog",
            breed: "Corgi",
            size: "Small",
            weightLbs: 22,
            birthday: nil,
            temperament: "Gentle",
            medicalNotes: nil,
            groomingNotes: nil,
            isActive: true
        )
    }

    private static func request(
        customerID: UUID,
        petID: UUID,
        status: GroomingRequestStatus = .open
    ) -> CustomerGroomingRequest {
        CustomerGroomingRequest(
            id: UUID(),
            customerID: customerID,
            petID: petID,
            petSnapshot: GroomingRequestPetSnapshot(
                id: petID,
                name: "Mochi",
                species: "Dog",
                breed: "Corgi",
                size: "Small",
                weightLbs: 22,
                birthday: nil,
                temperament: "Gentle",
                medicalNotes: nil,
                groomingNotes: nil,
                snapshotAt: "2026-06-20T12:00:00Z"
            ),
            photoSnapshot: [],
            serviceType: "Full groom",
            serviceNotes: nil,
            preferredStart: "2026-06-22T16:00:00Z",
            preferredEnd: "2026-06-22T18:00:00Z",
            city: "Seattle",
            state: "WA",
            zipCode: "98101",
            status: status,
            expiresAt: "2026-06-22T12:00:00Z",
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z"
        )
    }

    private static func offerReview(
        offerID: UUID = UUID(),
        customerID: UUID,
        requestID: UUID,
        status: GroomerOfferStatus = .pending,
        createdAt: String = "2026-06-20T13:00:00Z"
    ) -> CustomerOfferReview {
        let groomerID = UUID()
        return CustomerOfferReview(
            offer: GroomerOffer(
                id: offerID,
                requestID: requestID,
                matchID: UUID(),
                customerID: customerID,
                groomerID: groomerID,
                proposedStart: "2026-06-22T16:30:00Z",
                proposedEnd: "2026-06-22T18:30:00Z",
                priceEstimate: 125,
                message: "I can help.",
                status: status,
                expiresAt: "2026-06-22T12:00:00Z",
                withdrawnAt: nil,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            groomerProfile: GroomerProfile(
                userID: groomerID,
                businessName: "Fresh Paws Grooming",
                bio: "Gentle grooming.",
                yearsExperience: 5,
                baseCity: "Seattle",
                baseState: "WA",
                serviceRadiusMiles: 12,
                ratingAverage: 4.8,
                ratingCount: 18,
                isActive: true,
                isVerified: true
            )
        )
    }
}

@MainActor
private final class CustomerRequestPetRepositoryFake: CustomerPetRepository {
    var petsResult: Result<[CustomerPet], CustomerPetRepositoryError>

    init(
        petsResult: Result<[CustomerPet], CustomerPetRepositoryError> = .success([])
    ) {
        self.petsResult = petsResult
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        try petsResult.get()
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        []
    }

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        throw CustomerPetRepositoryError.unavailable
    }

    func updatePet(
        pet: CustomerPet,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        throw CustomerPetRepositoryError.unavailable
    }

    func softDeletePet(_ pet: CustomerPet) async throws {}

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        throw CustomerPetRepositoryError.unavailable
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {}
}

@MainActor
private final class CustomerRequestRepositoryFake: CustomerRequestRepository {
    var requestsResult: Result<[CustomerGroomingRequest], CustomerRequestRepositoryError>
    var offersResult: Result<[CustomerOfferReview], CustomerRequestRepositoryError>
    var createResult: Result<GroomingRequestPublishResult, CustomerRequestRepositoryError>
    var cancelResult: Result<CancelGroomingRequestResult, CustomerRequestRepositoryError>

    private(set) var requestsCallCount = 0
    private(set) var offersCallCount = 0
    private(set) var createCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var lastCustomerID: UUID?
    private(set) var lastOfferCustomerID: UUID?
    private(set) var lastOfferRequestID: UUID?
    private(set) var lastCancelRequestID: UUID?
    private(set) var lastDraft: GroomingRequestDraft?

    init(
        requestsResult: Result<[CustomerGroomingRequest], CustomerRequestRepositoryError> = .success([]),
        offersResult: Result<[CustomerOfferReview], CustomerRequestRepositoryError> = .success([]),
        createResult: Result<GroomingRequestPublishResult, CustomerRequestRepositoryError> =
            .failure(.unavailable),
        cancelResult: Result<CancelGroomingRequestResult, CustomerRequestRepositoryError> =
            .failure(.unavailable)
    ) {
        self.requestsResult = requestsResult
        self.offersResult = offersResult
        self.createResult = createResult
        self.cancelResult = cancelResult
    }

    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        requestsCallCount += 1
        return try requestsResult.get()
    }

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview] {
        offersCallCount += 1
        lastOfferCustomerID = customerID
        lastOfferRequestID = requestID
        return try offersResult.get()
    }

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult {
        createCallCount += 1
        lastCustomerID = customerID
        lastDraft = draft
        return try createResult.get()
    }

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult {
        cancelCallCount += 1
        lastCancelRequestID = requestID
        return try cancelResult.get()
    }
}

@MainActor
private final class CustomerRequestBookingRepositoryFake: BookingRepository {
    var acceptResult: Result<AcceptGroomerOfferResult, BookingRepositoryError>

    private(set) var acceptCallCount = 0
    private(set) var lastAcceptedOfferID: UUID?

    init(
        acceptResult: Result<AcceptGroomerOfferResult, BookingRepositoryError> =
            .failure(.unavailable)
    ) {
        self.acceptResult = acceptResult
    }

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        []
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        acceptCallCount += 1
        lastAcceptedOfferID = offerID
        return try acceptResult.get()
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        throw BookingRepositoryError.unavailable
    }
}
