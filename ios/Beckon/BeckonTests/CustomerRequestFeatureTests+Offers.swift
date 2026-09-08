import Foundation
import Testing
@testable import Beckon

extension CustomerRequestsStoreTests {
    @Test @MainActor
    func signOutDuringAcceptanceRefreshDoesNotPublishRequestPage() async {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let review = Self.offerReview(customerID: customerID, requestID: request.id)
        let requests = CustomerRequestRepositoryFake(requestsResult: .success([request]))
        let repository = CustomerRequestBookingRepositoryFake(acceptResult: .success(
            AcceptGroomerOfferResult(bookingID: UUID(), conversationID: UUID(), requestID: request.id,
                offerID: review.offer.id, bookingStatus: .confirmed,
                offerStatus: .acceptedByCustomer, requestStatus: .booked)))
        let scheduler = CustomerRequestAppointmentReminderSchedulerFake()
        let store = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: requests,
            bookingRepository: repository, appointmentReminderScheduler: scheduler)
        var sessionCurrent = true
        store.setAcceptanceSessionValidation { sessionCurrent }
        requests.onRequestPageRead = { sessionCurrent = false }
        let handoff = await store.accept(offerReview: review, for: request)
        #expect(handoff == nil)
        #expect(store.requests.isEmpty)
        #expect(scheduler.syncCallCount == 0)
    }

    @Test @MainActor
    func signOutDuringAcceptanceKeepsRecoveryIdentityWithoutPublishingOldAccountState() async {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let review = Self.offerReview(customerID: customerID, requestID: request.id)
        let repository = CustomerRequestBookingRepositoryFake(acceptResult: .success(
            AcceptGroomerOfferResult(bookingID: UUID(), conversationID: UUID(), requestID: request.id,
                offerID: review.offer.id, bookingStatus: .confirmed,
                offerStatus: .acceptedByCustomer, requestStatus: .booked)), acceptDelayNanoseconds: 50_000_000)
        let scheduler = CustomerRequestAppointmentReminderSchedulerFake()
        let store = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: repository, appointmentReminderScheduler: scheduler)
        var sessionCurrent = true
        store.setAcceptanceSessionValidation { sessionCurrent }
        let pending = Task { await store.accept(offerReview: review, for: request) }
        while repository.acceptCallCount == 0 { await Task.yield() }
        sessionCurrent = false
        let handoff = await pending.value
        #expect(handoff == nil)
        #expect(store.bookings.isEmpty)
        #expect(store.noticeMessage == nil)
        #expect(scheduler.syncCallCount == 0)
    }

    @Test(.enabled(if:
        ProcessInfo.processInfo.environment["T373_RECOVERY_PHASE"] != nil ||
        ProcessInfo.processInfo.environment["TEST_RUNNER_T373_RECOVERY_PHASE"] != nil
    )) @MainActor
    func acceptanceRecoveryAcrossIndependentProcessLaunches() async throws {
        let phase = ProcessInfo.processInfo.environment["T373_RECOVERY_PHASE"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_T373_RECOVERY_PHASE"]
        let customerID = try #require(UUID(uuidString: "37300000-0000-0000-0000-000000000001"))
        let requestID = try #require(UUID(uuidString: "37300000-0000-0000-0000-000000000002"))
        let offerID = try #require(UUID(uuidString: "37300000-0000-0000-0000-000000000003"))
        let suite = "beckon.tests.T373.independentProcessRecovery"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let request = Self.request(id: requestID, customerID: customerID, petID: UUID())
        let review = Self.offerReview(offerID: offerID, customerID: customerID, requestID: requestID)
        let repository = CustomerRequestBookingRepositoryFake(acceptResult: .failure(.networkUnavailable))
        let requests = CustomerRequestRepositoryFake(requestsResult: .success([request]))
        if phase == "write" {
            defaults.removePersistentDomain(forName: suite)
            let store = CustomerRequestsStore(customerID: customerID,
                petRepository: CustomerRequestPetRepositoryFake(), requestRepository: requests,
                bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
            _ = await store.accept(offerReview: review, for: request)
            #expect(repository.acceptCallCount == 1)
            // Do not force a test-only flush: the next process must use the
            // persistence behavior actually supplied by production code.
        } else {
            #expect(phase == "recover")
            defer { defaults.removePersistentDomain(forName: suite) }
            let booking = Self.booking(requestID: requestID, customerID: customerID, status: .cancelledByGroomer)
            repository.bookingsResult = .success([booking])
            repository.acceptanceLookupResult = .success(AcceptGroomerOfferResult(
                bookingID: booking.id, conversationID: UUID(), requestID: requestID, offerID: offerID,
                bookingStatus: .cancelledByGroomer, offerStatus: .acceptedByCustomer, requestStatus: .booked))
            let store = CustomerRequestsStore(customerID: customerID,
                petRepository: CustomerRequestPetRepositoryFake(), requestRepository: requests,
                bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
            await store.load()
            #expect(repository.acceptanceLookupCallCount == 1)
            #expect(repository.acceptCallCount == 0)
            #expect(store.noticeMessage == "Booking recovered. Cancelled by groomer.")
        }
    }

    @Test @MainActor
    func lostAcceptanceSurvivesStoreRestartAndReconcilesWithoutAnotherWrite() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let review = Self.offerReview(customerID: customerID, requestID: request.id)
        let booking = Self.booking(requestID: request.id, customerID: customerID)
        let suite = "T373.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = CustomerRequestBookingRepositoryFake(acceptResult: .failure(.networkUnavailable))
        let requests = CustomerRequestRepositoryFake(requestsResult: .success([request]))
        let original = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: requests,
            bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
        _ = await original.accept(offerReview: review, for: request)
        repository.acceptanceLookupResult = .success(AcceptGroomerOfferResult(
            bookingID: booking.id, conversationID: UUID(), requestID: request.id,
            offerID: review.offer.id, bookingStatus: .confirmed,
            offerStatus: .acceptedByCustomer, requestStatus: .booked))
        repository.bookingsResult = .success([booking])
        let restarted = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: requests,
            bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
        await restarted.load()
        #expect(repository.acceptanceLookupCallCount == 1)
        #expect(repository.acceptCallCount == 1)
        #expect(restarted.request(withID: request.id)?.status == .booked)
        #expect(restarted.noticeMessage == "Booking recovered. Confirmed.")
        await restarted.load()
        #expect(repository.acceptanceLookupCallCount == 1)
    }

    @Test @MainActor
    func legacyQuoteRejectionDoesNotPersistUnknownAcceptanceOrCloseRequest() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let review = Self.offerReview(customerID: customerID, requestID: request.id)
        let suite = "T374.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = CustomerRequestBookingRepositoryFake(acceptResult: .failure(.updatedOfferRequired))
        let requests = CustomerRequestRepositoryFake(requestsResult: .success([request]))
        let store = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: requests,
            bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
        await store.load()
        let handoff = await store.accept(offerReview: review, for: request)
        #expect(handoff == nil)
        #expect(store.request(withID: request.id)?.status == request.status)
        #expect(store.errorMessage == "This offer needs updated timing details from the groomer before you can book. Your request is still open.")
        #expect(store.noticeMessage == nil)
        let restarted = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: requests,
            bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
        await restarted.load()
        #expect(repository.acceptanceLookupCallCount == 0)
        #expect(repository.acceptCallCount == 1)
    }

    @Test @MainActor
    func terminalAcceptanceReplayDoesNotAnnounceConfirmation() async {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let review = Self.offerReview(customerID: customerID, requestID: request.id)
        let repository = CustomerRequestBookingRepositoryFake(acceptResult: .success(
            AcceptGroomerOfferResult(bookingID: UUID(), conversationID: UUID(),
                requestID: request.id, offerID: review.offer.id,
                bookingStatus: .cancelledByCustomer, offerStatus: .acceptedByCustomer,
                requestStatus: .booked)))
        let store = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(requestsResult: .failure(.unavailable)),
            bookingRepository: repository)
        let result = await store.accept(offerReview: review, for: request)
        #expect(result?.booking.status == .cancelledByCustomer)
        #expect(store.noticeMessage == "Booking recovered. Cancelled by customer.")
    }

    @Test @MainActor
    func unresolvedAcceptanceDoesNotLeakAcrossAccountsOrRetryWhenLookupFails() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let review = Self.offerReview(customerID: customerID, requestID: request.id)
        let suite = "T373.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = CustomerRequestBookingRepositoryFake(acceptResult: .failure(.networkUnavailable))
        let store = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
        _ = await store.accept(offerReview: review, for: request)
        let otherAccount = CustomerRequestsStore(customerID: UUID(),
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
        await otherAccount.load()
        #expect(repository.acceptanceLookupCallCount == 0)
        repository.acceptanceLookupResult = .failure(.networkUnavailable)
        _ = await store.accept(offerReview: review, for: request)
        #expect(repository.acceptanceLookupCallCount == 1)
        #expect(repository.acceptCallCount == 1)
        let restarted = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
        await restarted.load()
        #expect(repository.acceptanceLookupCallCount == 2)
        #expect(repository.acceptCallCount == 1)
        #expect(restarted.errorMessage == "We could not check your previous booking. Refresh before trying again.")
    }

    @Test @MainActor
    func emptyAcceptanceLookupDoesNotAutomaticallySubmitOnReload() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let review = Self.offerReview(customerID: customerID, requestID: request.id)
        let suite = "T373.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = CustomerRequestBookingRepositoryFake(acceptResult: .failure(.networkUnavailable))
        let store = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(), requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: repository, handoffAcknowledgementDefaults: defaults)
        _ = await store.accept(offerReview: review, for: request)
        await store.load()
        await store.load()
        #expect(repository.acceptanceLookupCallCount == 2)
        #expect(repository.acceptCallCount == 1)
        #expect(store.errorMessage == "Your previous booking is not confirmed. Retry the same offer to check again.")
        _ = await store.accept(offerReview: review, for: request)
        #expect(repository.acceptanceLookupCallCount == 3)
        #expect(repository.acceptCallCount == 2)
        #expect(repository.lastAcceptedOfferID == review.offer.id)
    }

    @Test @MainActor
    func offerAcceptancePresentationShowsCompleteDecisionContext() {
        let customerID = UUID()
        let request = Self.request(
            customerID: customerID,
            petID: UUID(),
            locationMode: .groomerComesToCustomer,
            streetAddress: "770 S Harbor Blvd",
            addressLine2: "Unit 2410",
            city: "Fullerton",
            state: "CA",
            zipCode: "92832"
        )
        let offerReview = Self.offerReview(
            customerID: customerID,
            requestID: request.id
        )

        let presentation = CustomerOfferAcceptancePresentation(
            request: request,
            offerReview: offerReview
        )

        #expect(presentation.title == "Confirm Booking")
        #expect(presentation.groomer == "Fresh Paws Grooming")
        #expect(presentation.service == "Full Groom")
        #expect(presentation.price == "$125.00")
        #expect(presentation.time == offerReview.proposedTimeSummary)
        #expect(presentation.location == "My Home")
        #expect(
            presentation.address ==
                "770 S Harbor Blvd, Unit 2410, Fullerton, CA 92832"
        )
        #expect(
            presentation.cancellation ==
                "You can cancel from Booking details while the appointment is confirmed. Cancelling will not reopen this request or its other offers."
        )
        #expect(presentation.confirmActionTitle == "Confirm & Book")
        #expect(presentation.supportingText.localizedCaseInsensitiveContains("backend") == false)
    }

    @Test @MainActor
    func offerReviewCarriesTheLoadedGroomerAvatar() {
        let avatarData = Data([0x04, 0x05, 0x06])
        let review = Self.offerReview(
            customerID: UUID(),
            requestID: UUID(),
            groomerAvatarPhotoData: avatarData
        )

        #expect(review.groomerAvatarPhotoData == avatarData)
    }

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

        let handoff = await store.accept(
            offerReview: acceptedPending,
            for: request
        )

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
        #expect(handoff?.request.id == request.id)
        #expect(handoff?.booking.id == acceptedBooking.id)
    }

    @Test @MainActor
    func acceptOfferReturnsLocalBookingHandoffWhenRefreshFails() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
        let initialReview = Self.offerReview(
            customerID: customerID,
            requestID: request.id
        )
        var timedOffer = initialReview.offer
        timedOffer.appliedTimingBuffers = try GroomingTimingBuffers(preparation: 15, cleanup: 10,
            inboundTravel: 0, outboundTravel: 0)
        timedOffer.serviceTimeZoneIdentifier = "America/Los_Angeles"
        timedOffer.scheduleTimeZoneIdentifier = "America/New_York"
        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: timedOffer.proposedStart))
        let end = try #require(GroomingRequestDateFormatting.parsedDate(from: timedOffer.proposedEnd))
        timedOffer.occupiedStart = ISO8601DateFormatter().string(from: start.addingTimeInterval(-900))
        timedOffer.occupiedEnd = ISO8601DateFormatter().string(from: end.addingTimeInterval(600))
        let offerReview = CustomerOfferReview(offer: timedOffer, groomerProfile: initialReview.groomerProfile)
        let bookingID = UUID()
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request]),
            offersResult: .success([offerReview])
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            acceptResult: .success(
                AcceptGroomerOfferResult(
                    bookingID: bookingID,
                    conversationID: UUID(),
                    requestID: request.id,
                    offerID: offerReview.id,
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
        requestRepository.requestsResult = .failure(.networkUnavailable)

        let handoff = await store.accept(
            offerReview: offerReview,
            for: request
        )

        #expect(handoff?.request.status == .booked)
        #expect(handoff?.booking.id == bookingID)
        #expect(handoff?.booking.offerID == offerReview.id)
        #expect(handoff?.booking.groomerID == offerReview.offer.groomerID)
        #expect(handoff?.booking.serviceType == request.serviceType)
        #expect(handoff?.booking.locationMode == request.locationMode)
        #expect(handoff?.booking.customerStreetAddress == request.streetAddress)
        #expect(handoff?.booking.appliedTimingBuffers == timedOffer.appliedTimingBuffers)
        #expect(handoff?.booking.serviceTimeZoneIdentifier == timedOffer.serviceTimeZoneIdentifier)
        #expect(handoff?.booking.scheduleTimeZoneIdentifier == timedOffer.scheduleTimeZoneIdentifier)
        #expect(handoff?.booking.occupiedStart == timedOffer.occupiedStart)
        #expect(handoff?.booking.occupiedEnd == timedOffer.occupiedEnd)
        #expect(store.bookingHandoffs.map(\.booking.id) == [bookingID])
    }

    @Test @MainActor
    func concurrentOfferAcceptanceSubmitsOnlyOnce() async throws {
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
                    offerID: offerReview.id,
                    bookingStatus: .confirmed,
                    offerStatus: .acceptedByCustomer,
                    requestStatus: .booked
                )
            ),
            acceptDelayNanoseconds: 100_000_000
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: bookingRepository
        )

        async let first = store.accept(
            offerReview: offerReview,
            for: request
        )
        await Task.yield()
        async let second = store.accept(
            offerReview: offerReview,
            for: request
        )
        let handoffs = await [first, second]

        #expect(bookingRepository.acceptCallCount == 1)
        #expect(handoffs.compactMap { $0 }.count == 1)
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
                "That time is no longer available for this booking."
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
