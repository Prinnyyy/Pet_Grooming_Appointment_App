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
        store.locationMode = .visitGroomer
        store.streetAddress = " 120 Pine St "
        store.travelRangeMiles = 24.6
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
        #expect(requestRepository.lastDraft?.locationMode == .visitGroomer)
        #expect(requestRepository.lastDraft?.streetAddress == "120 Pine St")
        #expect(requestRepository.lastDraft?.travelRangeMiles == 25)
        #expect(requestRepository.lastDraft?.city == "Seattle")
        #expect(requestRepository.lastDraft?.state == "WA")
        #expect(requestRepository.lastDraft?.zipCode == "98101")
        #expect(store.isShowingWizard == false)
        #expect(store.noticeMessage == "Request published. 2 groomers matched.")
        #expect(store.publishResult?.matchCount == 2)
    }

    @Test @MainActor
    func supabaseRequestContractUsesBackendTravelRadiusColumn() throws {
        #expect(
            SupabaseCustomerRequestRepository.requestColumns
                .contains("travel_radius_miles")
        )
        #expect(
            !SupabaseCustomerRequestRepository.requestColumns
                .contains("travel_range_miles")
        )

        let row = try JSONDecoder().decode(
            GroomingRequestRow.self,
            from: Self.requestRowData(travelRadiusMiles: 25)
        )

        #expect(row.request.travelRangeMiles == 25)
    }

    @Test @MainActor
    func supabaseCreateRequestParametersUseBackendTravelRadiusRPCName() throws {
        let payloadData = try JSONEncoder().encode(
            CreateGroomingRequestParameters(draft: Self.createRequestDraft())
        )
        let payload = try #require(
            JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        )

        #expect((payload["p_travel_radius_miles"] as? NSNumber)?.intValue == 25)
        #expect(payload["p_travel_range_miles"] == nil)
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
    func wizardPhotoUploadAddsPhotoForSelectedPet() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let photo = Self.photo(customerID: customerID, petID: pet.id)
        let petRepository = CustomerRequestPetRepositoryFake(
            petsResult: .success([pet]),
            uploadPhotoResult: .success(photo)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        await store.uploadPhotoForSelectedPet(
            data: Data([0x01, 0x02]),
            contentType: .jpeg
        )

        #expect(petRepository.uploadPhotoCallCount == 1)
        #expect(petRepository.lastUploadedPetID == pet.id)
        #expect(store.photos(for: pet) == [photo])
        #expect(store.selectedPetPhotos == [photo])
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
    func activeRequestsIncludeOnlyOpenAndOfferStates() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let openRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .open
        )
        let offerRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .hasOffers
        )
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let cancelledRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .cancelled
        )
        let expiredRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .expired
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([
                    openRequest,
                    offerRequest,
                    bookedRequest,
                    cancelledRequest,
                    expiredRequest,
                ])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.load()

        #expect(store.activeRequests.map(\.id) == [
            openRequest.id,
            offerRequest.id,
        ])
    }

    @Test @MainActor
    func bookedRequestWithConfirmedBookingCreatesSessionHandoff() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let booking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            bookingsResult: .success([booking])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([bookedRequest])
            ),
            bookingRepository: bookingRepository
        )

        await store.load()

        #expect(bookingRepository.bookingsCallCount == 1)
        #expect(bookingRepository.lastBookingsParticipantID == customerID)
        #expect(bookingRepository.lastBookingsRole == .customer)
        #expect(store.activeRequests.isEmpty)
        #expect(store.bookingHandoffs.map(\.request.id) == [bookedRequest.id])
        #expect(store.bookingHandoffs.first?.booking.id == booking.id)

        store.acknowledgeBookingHandoff(for: store.bookingHandoffs[0])

        #expect(store.bookingHandoffs.isEmpty)
        #expect(store.requests.first?.status == .booked)
    }

    @Test @MainActor
    func acknowledgedBookingHandoffPersistsAcrossStoreReloads() async throws {
        let customerID = UUID()
        let suiteName = "CustomerRequestsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let booking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let firstStore = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([bookedRequest])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake(
                bookingsResult: .success([booking])
            ),
            handoffAcknowledgementDefaults: defaults
        )

        await firstStore.load()
        let handoff = try #require(firstStore.bookingHandoffs.first)
        firstStore.acknowledgeBookingHandoff(for: handoff)

        let secondStore = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([bookedRequest])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake(
                bookingsResult: .success([booking])
            ),
            handoffAcknowledgementDefaults: defaults
        )

        await secondStore.load()

        #expect(secondStore.bookingHandoffs.isEmpty)
        #expect(secondStore.acknowledgedBookingHandoffRequestIDs.contains(bookedRequest.id))
    }

    @Test @MainActor
    func bookedRequestHandoffsRequireConfirmedBooking() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let completedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let cancelledRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            bookingsResult: .success([
                Self.booking(
                    requestID: completedRequest.id,
                    customerID: customerID,
                    status: .completed
                ),
                Self.booking(
                    requestID: cancelledRequest.id,
                    customerID: customerID,
                    status: .cancelledByCustomer
                ),
            ])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([
                    completedRequest,
                    cancelledRequest,
                ])
            ),
            bookingRepository: bookingRepository
        )

        await store.load()

        #expect(store.activeRequests.isEmpty)
        #expect(store.bookingHandoffs.isEmpty)
    }

    @Test @MainActor
    func visibleActionCardsMirrorRequestsDashboardFilteringForHome() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let openRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .open
        )
        let offerRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .hasOffers
        )
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let cancelledRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .cancelled
        )
        let expiredRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .expired
        )
        let confirmedBooking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([
                    openRequest,
                    offerRequest,
                    bookedRequest,
                    cancelledRequest,
                    expiredRequest,
                ])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake(
                bookingsResult: .success([confirmedBooking])
            )
        )

        await store.load()

        #expect(store.visibleActionCards.map(\.request.id) == [
            openRequest.id,
            offerRequest.id,
            bookedRequest.id,
        ])
        #expect(store.visibleActionCards.first?.handoff == nil)
        #expect(store.visibleActionCards.last?.handoff?.booking.id == confirmedBooking.id)

        let handoff = try #require(store.visibleActionCards.last?.handoff)
        store.acknowledgeBookingHandoff(for: handoff)

        #expect(store.visibleActionCards.map(\.request.id) == [
            openRequest.id,
            offerRequest.id,
        ])
    }

    @Test @MainActor
    func homeRequestHeroStaysEnabledWhileRequestsReloadWhenPetsExist() {
        let loadingWithPet = CustomerHomeRequestHeroPresentation(
            hasPets: true,
            isRequestStoreBusy: true
        )
        let emptyPets = CustomerHomeRequestHeroPresentation(
            hasPets: false,
            isRequestStoreBusy: false
        )

        #expect(loadingWithPet.isStartRequestDisabled == false)
        #expect(emptyPets.isStartRequestDisabled == true)
    }

    @Test @MainActor
    func homeActiveRequestPresentationUsesAllCardsAndNeverShowsLoadingCard() {
        let customerID = UUID()
        let openRequest = Self.request(
            customerID: customerID,
            petID: UUID(),
            status: .open
        )
        let offerRequest = Self.request(
            customerID: customerID,
            petID: UUID(),
            status: .hasOffers
        )
        let cards = [
            CustomerRequestActionCardItem(request: openRequest, handoff: nil),
            CustomerRequestActionCardItem(request: offerRequest, handoff: nil),
        ]
        let populated = CustomerHomeActiveRequestPresentation(
            cards: cards,
            isLoading: true
        )
        let emptyLoading = CustomerHomeActiveRequestPresentation(
            cards: [],
            isLoading: true
        )

        #expect(populated.cards == cards)
        #expect(populated.shouldShowCarousel == true)
        #expect(populated.shouldShowEmptyText == false)
        #expect(populated.shouldShowLoadingCard == false)
        #expect(emptyLoading.cards.isEmpty)
        #expect(emptyLoading.shouldShowCarousel == false)
        #expect(emptyLoading.shouldShowEmptyText == true)
        #expect(emptyLoading.shouldShowLoadingCard == false)
    }

    @Test @MainActor
    func requestEmptyCopyIsSharedByHomeAndRequests() {
        #expect(CustomerRequestEmptyCopy.title == "No Active Request")
        #expect(
            CustomerRequestEmptyCopy.message ==
                "Open quests and newly confirmed booking handoffs will appear here."
        )
    }

    @Test @MainActor
    func requestWizardStepsMatchPrototypeProgression() {
        #expect(CustomerRequestWizardStep.allCases.map(\.title) == [
            "Pet",
            "Service",
            "Time",
            "Details",
            "Review",
        ])
        #expect(CustomerRequestWizardStep.pet.progress == 0.2)
        #expect(CustomerRequestWizardStep.review.progress == 1)
    }

    @Test @MainActor
    func requestWizardServiceOptionsMapToExistingServiceTypeField() {
        #expect(CustomerRequestServiceOption.allCases.count == 6)
        #expect(CustomerRequestServiceOption.fullGroom.title == "Full Groom")
        #expect(CustomerRequestServiceOption.fullGroom.serviceType == "Full Groom")
        #expect(CustomerRequestServiceOption.bathAndBrush.serviceType == "Bath & Brush")
        #expect(CustomerRequestServiceOption.customRequest.subtitle == "Describe exactly what you need")
    }

    @Test @MainActor
    func requestWizardTimeWindowsApplyPresetRangesToSelectedDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let selectedDate = try #require(Self.isoDate("2026-06-19T12:00:00Z"))

        let morning = try #require(
            CustomerRequestTimeWindowOption.morning.range(
                on: selectedDate,
                calendar: calendar
            )
        )
        let afternoon = try #require(
            CustomerRequestTimeWindowOption.afternoon.range(
                on: selectedDate,
                calendar: calendar
            )
        )
        let evening = try #require(
            CustomerRequestTimeWindowOption.evening.range(
                on: selectedDate,
                calendar: calendar
            )
        )

        #expect(Self.hourMinute(morning.start, calendar: calendar) == [6, 0])
        #expect(Self.hourMinute(morning.end, calendar: calendar) == [11, 59])
        #expect(Self.hourMinute(afternoon.start, calendar: calendar) == [12, 0])
        #expect(Self.hourMinute(afternoon.end, calendar: calendar) == [16, 59])
        #expect(Self.hourMinute(evening.start, calendar: calendar) == [17, 0])
        #expect(Self.hourMinute(evening.end, calendar: calendar) == [21, 0])
        #expect(
            CustomerRequestTimeWindowOption.detailed.range(
                on: selectedDate,
                calendar: calendar
            ) == nil
        )
    }

    @Test @MainActor
    func requestWizardFlexibleTimeUsesAllDayWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let selectedDate = try #require(Self.isoDate("2026-06-19T12:00:00Z"))

        let flexible = CustomerRequestTimeWindowOption.flexibleRange(
            on: selectedDate,
            calendar: calendar
        )

        #expect(Self.hourMinute(flexible.start, calendar: calendar) == [0, 0])
        #expect(Self.hourMinute(flexible.end, calendar: calendar) == [23, 59])
    }

    @Test @MainActor
    func requestWizardTravelRangeClampsToSupportedMiles() {
        #expect(CustomerRequestTravelRange.clampedMiles(3) == 5)
        #expect(CustomerRequestTravelRange.clampedMiles(42) == 42)
        #expect(CustomerRequestTravelRange.clampedMiles(120) == 100)
    }

    @Test @MainActor
    func requestWizardReviewSummaryUsesCurrentRequestFields() {
        let summary = CustomerRequestWizardReviewPresentation(
            pet: "Mochi · Toy Poodle",
            service: "Full Groom",
            preferredTime: "Fri 19 · Afternoon",
            location: "Mobile · Seattle, WA 98101",
            notes: "Mochi needs a teddy-style trim."
        )

        #expect(summary.rows.map(\.title) == [
            "Pet",
            "Service",
            "Preferred Time",
            "Location",
            "Notes",
        ])
        #expect(summary.rows.map(\.value) == [
            "Mochi · Toy Poodle",
            "Full Groom",
            "Fri 19 · Afternoon",
            "Mobile · Seattle, WA 98101",
            "Mochi needs a teddy-style trim.",
        ])
    }

    @Test @MainActor
    func bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let booking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let presentation = CustomerRequestProgressCardPresentation(
            request: bookedRequest,
            handoff: CustomerRequestBookingHandoff(
                request: bookedRequest,
                booking: booking
            )
        )

        #expect(presentation.headline == "Booking\nConfirmed")
        #expect(presentation.subtitle == "Full groom for Mochi")
        #expect(presentation.infoLines == [
            CustomerRequestProgressCardPresentation.InfoLine(
                systemImage: "calendar",
                text: Self.compactDisplayRange(
                    from: booking.scheduledStart,
                    to: booking.scheduledEnd
                )
            ),
            CustomerRequestProgressCardPresentation.InfoLine(
                systemImage: "mappin.and.ellipse",
                text: "Seattle, WA 98101"
            ),
        ])
    }

    @Test @MainActor
    func openRequestCardPresentationUsesTitleCaseHeadlineAndCompactTimeRange() async throws {
        let customerID = UUID()
        let request = Self.request(
            customerID: customerID,
            petID: UUID(),
            status: .open
        )
        let presentation = CustomerRequestProgressCardPresentation(
            request: request,
            handoff: nil
        )

        #expect(presentation.headline == "Open\nRequest")
        #expect(presentation.infoLines.first == CustomerRequestProgressCardPresentation.InfoLine(
            systemImage: "calendar",
            text: Self.compactDisplayRange(
                from: request.preferredStart,
                to: request.preferredEnd
            )
        ))
        #expect(presentation.infoLines.first?.text.contains("2026") == false)
        #expect(presentation.infoLines.first?.text.contains("\n") == false)
    }

    @Test @MainActor
    func clearNoticeOnlyDismissesMatchingMessage() async throws {
        let store = CustomerRequestsStore(
            customerID: UUID(),
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        store.noticeMessage = "Request cancelled."
        store.clearNotice(ifCurrent: "Offer accepted. Booking confirmed.")
        #expect(store.noticeMessage == "Request cancelled.")

        store.clearNotice(ifCurrent: "Request cancelled.")
        #expect(store.noticeMessage == nil)
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

    private static func photo(
        customerID: UUID,
        petID: UUID
    ) -> CustomerPetPhoto {
        CustomerPetPhoto(
            id: UUID(),
            petID: petID,
            customerID: customerID,
            storageBucket: "pet-photos",
            storagePath: CustomerPetPhotoPath.make(
                customerID: customerID,
                petID: petID,
                contentType: .jpeg
            ),
            caption: nil,
            sortOrder: 0,
            isPrimary: false
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
            locationMode: .comeToMe,
            streetAddress: nil,
            travelRangeMiles: nil,
            city: "Seattle",
            state: "WA",
            zipCode: "98101",
            status: status,
            expiresAt: "2026-06-22T12:00:00Z",
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z"
        )
    }

    private static func createRequestDraft() -> GroomingRequestDraft {
        GroomingRequestDraft(
            petID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            serviceType: "Full groom",
            serviceNotes: nil,
            preferredStart: Date(timeIntervalSince1970: 1_783_000_000),
            preferredEnd: Date(timeIntervalSince1970: 1_783_007_200),
            locationMode: .visitGroomer,
            streetAddress: "120 Pine St",
            travelRangeMiles: 25,
            city: "Seattle",
            state: "WA",
            zipCode: "98101"
        )
    }

    private static func requestRowData(travelRadiusMiles: Int) -> Data {
        Data(
            #"""
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "customer_id": "22222222-2222-2222-2222-222222222222",
              "pet_id": "33333333-3333-3333-3333-333333333333",
              "pet_snapshot": {
                "id": "33333333-3333-3333-3333-333333333333",
                "name": "Mochi",
                "species": "Dog",
                "breed": "Corgi",
                "size": "Small",
                "weight_lbs": 22,
                "birthday": null,
                "temperament": "Gentle",
                "medical_notes": null,
                "grooming_notes": null,
                "snapshot_at": "2026-06-20T12:00:00Z"
              },
              "photo_snapshot": [],
              "service_type": "Full groom",
              "service_notes": null,
              "preferred_start": "2026-06-22T16:00:00Z",
              "preferred_end": "2026-06-22T18:00:00Z",
              "location_mode": "visit_groomer",
              "street_address": "120 Pine St",
              "travel_radius_miles": \#(travelRadiusMiles),
              "city": "Seattle",
              "state": "WA",
              "zip_code": "98101",
              "status": "open",
              "expires_at": "2026-06-22T12:00:00Z",
              "created_at": "2026-06-20T12:00:00Z",
              "updated_at": "2026-06-20T12:00:00Z"
            }
            """#.utf8
        )
    }

    private static func compactDisplayRange(from start: String, to end: String) -> String {
        "\(compactDisplayString(from: start)) - \(compactDisplayString(from: end))"
    }

    private static func compactDisplayString(from value: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private static func isoDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func hourMinute(_ date: Date, calendar: Calendar) -> [Int] {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return [
            components.hour ?? -1,
            components.minute ?? -1,
        ]
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

    private static func booking(
        requestID: UUID,
        customerID: UUID,
        status: BookingStatus = .confirmed
    ) -> Booking {
        Booking(
            id: UUID(),
            requestID: requestID,
            offerID: UUID(),
            customerID: customerID,
            groomerID: UUID(),
            scheduledStart: "2026-06-24T16:00:00Z",
            scheduledEnd: "2026-06-24T18:00:00Z",
            priceEstimate: 128,
            status: status,
            cancelledBy: nil,
            cancelledAt: nil,
            completedAt: nil,
            completedBy: nil,
            createdAt: "2026-06-22T16:00:00Z",
            updatedAt: "2026-06-22T16:00:00Z",
            review: nil
        )
    }
}

@MainActor
private final class CustomerRequestPetRepositoryFake: CustomerPetRepository {
    var petsResult: Result<[CustomerPet], CustomerPetRepositoryError>
    var photosResult: Result<[CustomerPetPhoto], CustomerPetRepositoryError>
    var uploadPhotoResult: Result<CustomerPetPhoto, CustomerPetRepositoryError>

    private(set) var uploadPhotoCallCount = 0
    private(set) var lastUploadedCustomerID: UUID?
    private(set) var lastUploadedPetID: UUID?
    private(set) var lastUploadedContentType: CustomerPetPhotoContentType?

    init(
        petsResult: Result<[CustomerPet], CustomerPetRepositoryError> = .success([]),
        photosResult: Result<[CustomerPetPhoto], CustomerPetRepositoryError> = .success([]),
        uploadPhotoResult: Result<CustomerPetPhoto, CustomerPetRepositoryError> =
            .failure(.unavailable)
    ) {
        self.petsResult = petsResult
        self.photosResult = photosResult
        self.uploadPhotoResult = uploadPhotoResult
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        try petsResult.get()
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        try photosResult.get()
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
        uploadPhotoCallCount += 1
        lastUploadedCustomerID = customerID
        lastUploadedPetID = petID
        lastUploadedContentType = contentType
        return try uploadPhotoResult.get()
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
    var bookingsResult: Result<[Booking], BookingRepositoryError>
    var acceptResult: Result<AcceptGroomerOfferResult, BookingRepositoryError>

    private(set) var bookingsCallCount = 0
    private(set) var acceptCallCount = 0
    private(set) var lastBookingsParticipantID: UUID?
    private(set) var lastBookingsRole: UserRole?
    private(set) var lastAcceptedOfferID: UUID?

    init(
        bookingsResult: Result<[Booking], BookingRepositoryError> = .success([]),
        acceptResult: Result<AcceptGroomerOfferResult, BookingRepositoryError> =
            .failure(.unavailable)
    ) {
        self.bookingsResult = bookingsResult
        self.acceptResult = acceptResult
    }

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        bookingsCallCount += 1
        lastBookingsParticipantID = participantID
        lastBookingsRole = role
        return try bookingsResult.get()
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
