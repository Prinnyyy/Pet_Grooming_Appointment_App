import Foundation
import Testing
@testable import Beckon

struct BookingsStoreTests {
    @Test @MainActor
    func groomerScheduleDefaultsToFirstActiveDayAndBuildsOneSummary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(
            TimeZone(identifier: "America/Los_Angeles")
        )
        let referenceDate = try #require(
            GroomingRequestDateFormatting.parsedDate(
                from: "2026-08-20T16:00:00Z"
            )
        )
        let first = Self.booking(
            scheduledStart: "2026-08-22T16:00:00Z",
            scheduledEnd: "2026-08-22T18:00:00Z"
        )
        let second = Self.booking(
            scheduledStart: "2026-08-22T19:00:00Z",
            scheduledEnd: "2026-08-22T20:30:00Z"
        )
        let cancelled = Self.booking(
            status: .cancelledByCustomer,
            scheduledStart: "2026-08-21T15:00:00Z",
            scheduledEnd: "2026-08-21T16:00:00Z"
        )
        let past = Self.booking(
            scheduledStart: "2026-08-19T16:00:00Z",
            scheduledEnd: "2026-08-19T17:00:00Z"
        )

        let presentation = GroomerSchedulePresentation(
            referenceDate: referenceDate,
            bookings: [past, second, cancelled, first],
            selectedDayKey: nil,
            calendar: calendar
        )

        #expect(presentation.selectedDayKey == "2026-08-22")
        #expect(presentation.selectedBookings.map(\.id) == [first.id, second.id])
        #expect(presentation.summary?.bookingCount == 2)
        #expect(presentation.summary?.totalDurationSummary == "3h 30m")
        #expect(presentation.summary?.nextStartSummary == "9:00 AM")
    }

    @Test @MainActor
    func groomerScheduleEmptySelectionDoesNotCreateDuplicateSummary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(
            TimeZone(identifier: "America/Los_Angeles")
        )
        let referenceDate = try #require(
            GroomingRequestDateFormatting.parsedDate(
                from: "2026-08-20T16:00:00Z"
            )
        )
        let booking = Self.booking(
            scheduledStart: "2026-08-22T16:00:00Z",
            scheduledEnd: "2026-08-22T18:00:00Z"
        )

        let presentation = GroomerSchedulePresentation(
            referenceDate: referenceDate,
            bookings: [booking],
            selectedDayKey: "2026-08-20",
            calendar: calendar
        )

        #expect(presentation.selectedBookings.isEmpty)
        #expect(presentation.summary == nil)
    }

    @Test @MainActor
    func groomerScheduleAppointmentPrioritizesPetAndOperationalContext() throws {
        let booking = Self.booking(
            customerID: UUID(uuidString: "123E4567-E89B-42D3-A456-426614174000")!,
            serviceType: .fullGroom,
            locationMode: .groomerComesToCustomer,
            requestPetSnapshot: try Self.petSnapshot(breed: "Poodle")
        )

        let presentation = GroomerScheduleAppointmentPresentation(
            booking: booking
        )

        #expect(presentation.petName == "Mochi")
        #expect(presentation.petDetail == "Poodle · Full Groom")
        #expect(presentation.customerReference == "Customer ref 123E4567")
        #expect(presentation.location == "Mobile")
        #expect(presentation.status == .confirmed)
    }

    @Test @MainActor
    func bookingDetailActionsStayRoleCorrectAcrossStatuses() {
        let confirmed = Self.booking(status: .confirmed)
        let completed = Self.booking(status: .completed)

        let groomerActions = BookingDetailActionPresentation(
            booking: confirmed,
            role: .groomer
        )
        let customerActions = BookingDetailActionPresentation(
            booking: confirmed,
            role: .customer
        )
        let completedActions = BookingDetailActionPresentation(
            booking: completed,
            role: .groomer
        )

        #expect(groomerActions.canComplete)
        #expect(groomerActions.canCancel)
        #expect(!customerActions.canComplete)
        #expect(customerActions.canCancel)
        #expect(!completedActions.canComplete)
        #expect(!completedActions.canCancel)
    }

    @Test @MainActor
    func paginationRetriesThenAppendsUniqueBookingsAndStopsAtLastPage() async {
        let participantID = UUID()
        let first = Self.booking(
            customerID: participantID,
            scheduledStart: "2026-08-23T16:00:00Z"
        )
        let second = Self.booking(
            customerID: participantID,
            scheduledStart: "2026-08-22T16:00:00Z"
        )
        let repository = BookingRepositoryFake(
            bookingPages: [
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
        let scheduler = AppointmentReminderSchedulerFake()
        let store = BookingsStore(
            participantID: participantID,
            role: .customer,
            repository: repository,
            appointmentReminderScheduler: scheduler
        )

        await store.load()
        await store.loadNextPage()

        #expect(store.bookings.map(\.id) == [first.id])
        #expect(store.canLoadMore == true)
        #expect(store.isLoading == false)
        #expect(store.isLoadingMore == false)
        #expect(store.errorMessage == "Check your connection and try again.")

        await store.loadNextPage()

        #expect(repository.receivedBookingPages == [.first, .first.next, .first.next])
        #expect(store.bookings.map(\.id) == [first.id, second.id])
        #expect(store.canLoadMore == false)
        #expect(scheduler.syncCallCount == 2)
    }

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
    func loadSyncsUpcomingConfirmedAppointmentReminders() async throws {
        let participantID = UUID()
        let booking = Self.booking(
            id: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
            customerID: participantID,
            scheduledStart: "2026-08-22T16:00:00Z"
        )
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking])
        )
        let scheduler = AppointmentReminderSchedulerFake()
        let store = BookingsStore(
            participantID: participantID,
            role: .customer,
            repository: repository,
            appointmentReminderScheduler: scheduler
        )

        await store.load()

        #expect(scheduler.syncCallCount == 1)
        #expect(scheduler.lastSyncedBookings == [booking])
        #expect(scheduler.lastSyncedRole == .customer)
        #expect(store.appointmentReminderNotice == nil)
    }

    @Test @MainActor
    func loadRecordsReminderRefusalWithoutReplacingBookingErrorState() async throws {
        let booking = Self.booking(scheduledStart: "2026-08-22T16:00:00Z")
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking])
        )
        let scheduler = AppointmentReminderSchedulerFake(syncResult: .refused)
        let store = BookingsStore(
            participantID: booking.customerID,
            role: .customer,
            repository: repository,
            appointmentReminderScheduler: scheduler
        )

        await store.load()

        #expect(store.errorMessage == nil)
        #expect(store.appointmentReminderNotice == "Appointment reminders are off. Enable notifications in Settings to receive local reminders.")
    }

    @Test @MainActor
    func cancelAndCompleteRevokeAppointmentReminderAfterSuccessfulStateChange() async throws {
        let groomerID = UUID()
        let booking = Self.booking(
            groomerID: groomerID,
            scheduledStart: "2026-08-22T16:00:00Z"
        )
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking]),
            cancelResult: .success(
                CancelBookingResult(
                    bookingID: booking.id,
                    bookingStatus: .cancelledByGroomer,
                    cancelledTimestamp: "2026-06-21T12:00:00Z",
                    cancelledBy: groomerID
                )
            ),
            completeResult: .success(
                CompleteBookingResult(
                    bookingID: booking.id,
                    bookingStatus: .completed,
                    completedTimestamp: "2026-06-22T18:05:00Z",
                    completedBy: groomerID
                )
            )
        )
        let scheduler = AppointmentReminderSchedulerFake()
        let store = BookingsStore(
            participantID: groomerID,
            role: .groomer,
            repository: repository,
            appointmentReminderScheduler: scheduler
        )
        await store.load()

        await store.cancel(booking)
        await store.complete(booking)

        #expect(scheduler.cancelledReminderIDs == [booking.id, booking.id])
        #expect(scheduler.cancelledRoles == [.groomer, .groomer])
    }

    @Test @MainActor
    func loadFailureCreatesPersistentPageErrorState() async throws {
        let repository = BookingRepositoryFake(
            bookingsResult: .failure(.unavailable)
        )
        let store = BookingsStore(
            participantID: UUID(),
            role: .groomer,
            repository: repository
        )

        await store.load()

        #expect(repository.bookingsCallCount == 1)
        #expect(store.bookings.isEmpty)
        #expect(store.errorMessage == "We could not load your schedule. Please try again.")

        let presentation = BookingsFeedbackPresentation(
            role: .groomer,
            bookings: store.bookings,
            isLoading: store.isLoading,
            errorMessage: store.errorMessage
        )

        #expect(presentation.persistentLoadError?.title == "We Could Not Load Schedule")
        #expect(presentation.persistentLoadError?.message == "We could not load your schedule. Please try again.")
        #expect(presentation.persistentLoadError?.actionTitle == "Try Again")
        #expect(presentation.toastError == nil)
    }

    @Test @MainActor
    func customerLoadFailureUsesBookingSpecificCopy() async throws {
        let repository = BookingRepositoryFake(
            bookingsResult: .failure(.unavailable)
        )
        let store = BookingsStore(
            participantID: UUID(),
            role: .customer,
            repository: repository
        )

        await store.load()

        #expect(store.errorMessage == "We could not load your bookings. Please try again.")

        let presentation = BookingsFeedbackPresentation(
            role: .customer,
            bookings: store.bookings,
            isLoading: store.isLoading,
            errorMessage: store.errorMessage
        )

        #expect(presentation.persistentLoadError?.title == "We Could Not Load Bookings")
        #expect(presentation.persistentLoadError?.message == "We could not load your bookings. Please try again.")
        #expect(presentation.toastError == nil)
    }

    @Test @MainActor
    func loadCancellationIsLoggedButDoesNotSetUserError() async throws {
        let writer = AppDebugEventWriterSpy()
        let recorder = AppDebugEventRecorder(
            writer: writer,
            emitsToOSLog: false
        )
        let repository = BookingRepositoryFake(
            bookingsResult: .failure(.cancelled)
        )
        let store = BookingsStore(
            participantID: UUID(),
            role: .customer,
            repository: repository,
            debugRecorder: recorder
        )

        await store.load()

        #expect(repository.bookingsCallCount == 1)
        #expect(store.bookings.isEmpty)
        #expect(store.errorMessage == nil)
        #expect(store.isLoading == false)
        #expect(
            recorder.events.contains {
                $0.level == .info
                    && $0.category == .store
                    && $0.source == "BookingsStore.load"
                    && $0.message == "cancelled ignored"
            }
        )
        #expect(recorder.events.contains { $0.level == .error } == false)
    }

    @Test @MainActor
    func debugBookingRepositoryRecordsFailureMetadata() async throws {
        let writer = AppDebugEventWriterSpy()
        let recorder = AppDebugEventRecorder(
            writer: writer,
            emitsToOSLog: false
        )
        let base = BookingRepositoryFake(
            bookingsResult: .failure(.networkUnavailable)
        )
        let repository = DebugBookingRepository(
            base: base,
            debugRecorder: recorder
        )

        await #expect(throws: BookingRepositoryError.networkUnavailable) {
            _ = try await repository.bookings(
                participantID: UUID(),
                role: .customer
            )
        }

        let event = try #require(
            recorder.events.first { $0.source == "BookingRepository.bookings" }
        )
        #expect(event.level == .error)
        #expect(event.category == .repository)
        #expect(event.scope == "customer.bookings")
        #expect(event.metadata["operation"] == "bookings")
        #expect(event.metadata["role"] == "customer")
        #expect(event.underlyingErrorType == "BookingRepositoryError")
        #expect(event.underlyingErrorCode == "networkUnavailable")
    }

    @Test @MainActor
    func operationFailureCreatesOperationScopedToastWithoutPersistentLoadError() async throws {
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

        await store.cancel(booking)

        let presentation = BookingsFeedbackPresentation(
            role: .customer,
            bookings: store.bookings,
            isLoading: store.isLoading,
            errorMessage: store.errorMessage
        )

        #expect(presentation.persistentLoadError == nil)
        #expect(presentation.toastError?.scope == .operation("customer.bookings.operation"))
        #expect(presentation.toastError?.sourceKey == "customer.bookings.operation-error")
        #expect(presentation.toastError?.message == "This booking can no longer be cancelled.")
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
    func customerSubmitsStructuredPetFitReviewOutcomes() async throws {
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
            rating: 4,
            content: nil,
            createdAt: "2026-06-22T19:00:00Z"
        )
        let repository = BookingRepositoryFake(
            bookingsResult: .success([booking]),
            reviewResult: .success(
                CreateReviewResult(
                    review: review,
                    groomerRatingAverage: 4,
                    groomerRatingCount: 1
                )
            )
        )
        let store = BookingsStore(
            participantID: customerID,
            role: .customer,
            repository: repository
        )
        let selectedOutcomes = [
            BookingReviewPetFitOutcomeDraft(
                signal: .serviceFit(.curlyCoat),
                outcome: .positive
            ),
            BookingReviewPetFitOutcomeDraft(
                signal: .careFlag(.anxious),
                outcome: .negative
            )
        ]
        await store.load()

        await store.createReview(
            for: booking,
            rating: 4,
            content: "",
            petFitOutcomes: selectedOutcomes
        )

        #expect(repository.reviewCallCount == 1)
        #expect(repository.lastReviewDraft == BookingReviewDraft(
            rating: 4,
            content: nil,
            petFitOutcomes: selectedOutcomes
        ))
    }

    @Test
    func reviewPetFitOutcomeSelectionsDefaultToEmptyOutcomes() {
        let signals: [PetFitSignal] = [
            .breedGroup(.poodle),
            .careFlag(.anxious),
            .serviceFit(.gentleHandling)
        ]

        let selections = BookingReviewPetFitOutcomeSelection.defaults(
            for: signals
        )

        #expect(selections.map(\.signal) == signals)
        #expect(selections.map(\.outcome) == [nil, nil, nil])
        #expect(selections.selectedOutcomes.isEmpty)
    }

    @Test
    func reviewPetFitOutcomeSelectionsBuildSelectedOutcomesOnly() {
        var selections = BookingReviewPetFitOutcomeSelection.defaults(
            for: [
                .breedGroup(.poodle),
                .careFlag(.anxious),
                .serviceFit(.gentleHandling)
            ]
        )
        selections[0].outcome = .positive
        selections[2].outcome = .negative

        #expect(selections.selectedOutcomes == [
            BookingReviewPetFitOutcomeDraft(
                signal: .breedGroup(.poodle),
                outcome: .positive
            ),
            BookingReviewPetFitOutcomeDraft(
                signal: .serviceFit(.gentleHandling),
                outcome: .negative
            )
        ])
    }

    @Test
    func createReviewParametersEncodePetFitOutcomesRpcPayload() throws {
        let bookingID = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
        let parameters = CreateReviewParameters(
            bookingID: bookingID,
            draft: BookingReviewDraft(
                rating: 5,
                content: "Patient handling",
                petFitOutcomes: [
                    BookingReviewPetFitOutcomeDraft(
                        signal: .serviceFit(.gentleHandling),
                        outcome: .positive
                    ),
                    BookingReviewPetFitOutcomeDraft(
                        signal: .careFlag(.senior),
                        outcome: .negative
                    )
                ]
            )
        )

        let payload = try Self.encodedJSONObject(parameters)

        #expect(payload["p_booking_id"] as? String == bookingID.uuidString.lowercased())
        #expect(payload["p_rating"] as? Int == 5)
        #expect(payload["p_content"] as? String == "Patient handling")

        let outcomes = try #require(payload["p_pet_fit_outcomes"] as? [[String: String]])
        #expect(outcomes == [
            [
                "trait_type": "service_fit",
                "trait_value": "gentle_handling",
                "outcome": "positive"
            ],
            [
                "trait_type": "care_flag",
                "trait_value": "senior",
                "outcome": "negative"
            ]
        ])
    }

    @Test
    func createReviewParametersEncodeEmptyPetFitOutcomes() throws {
        let parameters = CreateReviewParameters(
            bookingID: UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!,
            draft: BookingReviewDraft(rating: 5, content: nil)
        )

        let payload = try Self.encodedJSONObject(parameters)

        #expect(payload["p_content"] is NSNull)
        let outcomes = try #require(payload["p_pet_fit_outcomes"] as? [Any])
        #expect(outcomes.isEmpty)
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
            groomerBaseStreetAddress: "456 Groomer Lane",
            groomerBaseCity: "Austin",
            groomerBaseState: "TX",
            groomerBaseZipCode: "78701",
            locationMode: .customerComesToGroomer
        )

        #expect(booking.partnerDisplayTitle(for: .customer) == "Groomer Name")
        #expect(booking.appointmentLocationTitle == "Customer Comes To Groomer")
        #expect(booking.appointmentAddressSummary == "456 Groomer Lane, Austin, TX 78701")
    }

    @Test
    func completedBookingDerivesReviewablePetFitSignalsFromRequestContext() throws {
        let booking = Self.booking(
            status: .completed,
            completedAt: "2026-06-22T18:05:00Z",
            serviceType: .fullGroom,
            requestPetSnapshot: try Self.petSnapshot(
                breed: "Toy Poodle",
                size: "Giant",
                weightLbs: 16,
                birthday: "2013-06-24",
                temperament: "Anxious"
            )
        )

        #expect(
            booking.reviewableFitSignals.map(\.id) == [
                "coat_type:curly_wavy",
                "breed_group:poodle",
                "size_band:S",
                "care_flag:anxious",
                "care_flag:senior",
                "service_fit:curly_coat",
                "service_fit:full_haircut_styling",
                "service_fit:gentle_handling",
                "service_fit:senior_care"
            ]
        )
    }

    @Test
    func reviewablePetFitSignalsRequireCompletedBookingAndRequestContext() throws {
        let confirmedBooking = Self.booking(
            status: .confirmed,
            serviceType: .haircutOnly,
            requestPetSnapshot: try Self.petSnapshot(
                breed: "West Highland White Terrier",
                weightLbs: 22
            )
        )
        let missingContextBooking = Self.booking(
            status: .completed,
            completedAt: "2026-06-22T18:05:00Z",
            serviceType: .haircutOnly,
            requestPetSnapshot: nil
        )

        #expect(confirmedBooking.reviewableFitSignals.isEmpty)
        #expect(missingContextBooking.reviewableFitSignals.isEmpty)
    }

    @Test
    func bookingReviewableSignalsIncludeTerrierServiceFitAndSizeContext() throws {
        let booking = Self.booking(
            status: .completed,
            completedAt: "2026-06-22T18:05:00Z",
            serviceType: .haircutOnly,
            requestPetSnapshot: try Self.petSnapshot(
                breed: "West Highland White Terrier",
                weightLbs: 42
            )
        )

        #expect(
            booking.reviewableFitSignals.map(\.id) == [
                "coat_type:wire",
                "breed_group:terrier",
                "size_band:L",
                "service_fit:full_haircut_styling",
                "service_fit:hand_stripping_carding",
                "service_fit:terrier_coat"
            ]
        )
    }

    fileprivate static func booking(
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
        groomerBaseStreetAddress: String? = nil,
        groomerBaseCity: String? = nil,
        groomerBaseState: String? = nil,
        groomerBaseZipCode: String? = nil,
        locationMode: GroomingLocationMode? = nil,
        customerStreetAddress: String? = nil,
        customerCity: String? = nil,
        customerState: String? = nil,
        customerZipCode: String? = nil,
        requestPetSnapshot: GroomingRequestPetSnapshot? = nil,
        scheduledStart: String = "2026-06-22T16:00:00Z",
        scheduledEnd: String = "2026-06-22T18:00:00Z"
    ) -> Booking {
        Booking(
            id: id,
            requestID: requestID,
            offerID: offerID,
            customerID: customerID,
            groomerID: groomerID,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
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
            requestPetSnapshot: requestPetSnapshot,
            groomerBusinessName: groomerBusinessName,
            groomerBaseStreetAddress: groomerBaseStreetAddress,
            groomerBaseCity: groomerBaseCity,
            groomerBaseState: groomerBaseState,
            groomerBaseZipCode: groomerBaseZipCode,
            locationMode: locationMode,
            customerStreetAddress: customerStreetAddress,
            customerCity: customerCity,
            customerState: customerState,
            customerZipCode: customerZipCode
        )
    }

    private static func petSnapshot(
        breed: String? = nil,
        size: String? = "S",
        weightLbs: Double? = 16,
        birthday: String? = nil,
        temperament: String? = nil
    ) throws -> GroomingRequestPetSnapshot {
        GroomingRequestPetSnapshot(
            id: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
            name: "Mochi",
            species: "Dog",
            breed: breed,
            coatType: nil,
            size: size,
            weightLbs: weightLbs,
            birthday: birthday,
            temperament: temperament,
            medicalNotes: nil,
            groomingNotes: nil,
            snapshotAt: nil
        )
    }

    private static func encodedJSONObject<T: Encodable>(
        _ value: T
    ) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }
}

struct AppointmentReminderPlanTests {
    @Test @MainActor
    func plannerKeepsOnlyFutureConfirmedBookings() throws {
        let now = try #require(
            GroomingRequestDateFormatting.parsedDate(
                from: "2026-08-22T14:00:00Z"
            )
        )
        let eligible = BookingsStoreTests.booking(
            id: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
            status: .confirmed,
            scheduledStart: "2026-08-22T16:00:00Z"
        )
        let cancelled = BookingsStoreTests.booking(
            id: UUID(uuidString: "22222222-2222-4333-8444-555555555555")!,
            status: .cancelledByCustomer,
            scheduledStart: "2026-08-22T16:00:00Z"
        )
        let past = BookingsStoreTests.booking(
            id: UUID(uuidString: "33333333-2222-4333-8444-555555555555")!,
            status: .confirmed,
            scheduledStart: "2026-08-22T13:00:00Z"
        )

        let reminders = AppointmentReminderPlan.reminders(
            for: [eligible, cancelled, past],
            role: .customer,
            now: now
        )

        #expect(reminders.count == 1)
        #expect(reminders.first?.bookingID == eligible.id)
        #expect(
            reminders.first?.identifier ==
                "beckon.appointment-reminder.customer.11111111-2222-4333-8444-555555555555"
        )
        #expect(
            reminders.first?.fireDate ==
                GroomingRequestDateFormatting.parsedDate(
                    from: "2026-08-22T15:00:00Z"
                )
        )
    }

    @Test @MainActor
    func plannerDeduplicatesRepeatedBookingRowsByReminderIdentifier() throws {
        let now = try #require(
            GroomingRequestDateFormatting.parsedDate(
                from: "2026-08-22T14:00:00Z"
            )
        )
        let bookingID = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
        let booking = BookingsStoreTests.booking(
            id: bookingID,
            status: .confirmed,
            scheduledStart: "2026-08-22T16:00:00Z"
        )

        let reminders = AppointmentReminderPlan.reminders(
            for: [booking, booking],
            role: .customer,
            now: now
        )

        #expect(reminders.map(\.identifier) == [
            "beckon.appointment-reminder.customer.11111111-2222-4333-8444-555555555555",
        ])
    }
}

private final class AppointmentReminderSchedulerFake:
    AppointmentReminderScheduling,
    @unchecked Sendable
{
    var syncResult: AppointmentReminderSyncResult

    private(set) var syncCallCount = 0
    private(set) var lastSyncedBookings: [Booking]?
    private(set) var lastSyncedRole: UserRole?
    private(set) var cancelledReminderIDs: [UUID] = []
    private(set) var cancelledRoles: [UserRole] = []

    init(syncResult: AppointmentReminderSyncResult = .scheduled(count: 1)) {
        self.syncResult = syncResult
    }

    func syncReminders(
        for bookings: [Booking],
        role: UserRole
    ) async -> AppointmentReminderSyncResult {
        syncCallCount += 1
        lastSyncedBookings = bookings
        lastSyncedRole = role
        return syncResult
    }

    func cancelReminder(for bookingID: UUID, role: UserRole) async {
        cancelledReminderIDs.append(bookingID)
        cancelledRoles.append(role)
    }
}

@MainActor
private final class BookingRepositoryFake: BookingRepository {
    var bookingsResult: Result<[Booking], BookingRepositoryError>
    var bookingPages: [Result<ListPage<Booking>, BookingRepositoryError>]
    var cancelResult: Result<CancelBookingResult, BookingRepositoryError>
    var completeResult: Result<CompleteBookingResult, BookingRepositoryError>
    var reviewResult: Result<CreateReviewResult, BookingRepositoryError>

    private(set) var bookingsCallCount = 0
    private(set) var receivedBookingPages: [ListPageRequest] = []
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
        bookingPages: [Result<ListPage<Booking>, BookingRepositoryError>] = [],
        cancelResult: Result<CancelBookingResult, BookingRepositoryError> =
            .failure(.unavailable),
        completeResult: Result<CompleteBookingResult, BookingRepositoryError> =
            .failure(.unavailable),
        reviewResult: Result<CreateReviewResult, BookingRepositoryError> =
            .failure(.unavailable)
    ) {
        self.bookingsResult = bookingsResult
        self.bookingPages = bookingPages
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

    func bookings(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<Booking> {
        bookingsCallCount += 1
        lastParticipantID = participantID
        lastRole = role
        receivedBookingPages.append(page)
        if !bookingPages.isEmpty {
            return try bookingPages.removeFirst().get()
        }

        return ListPage(
            items: try bookingsResult.get(),
            request: page,
            hasMore: false
        )
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
