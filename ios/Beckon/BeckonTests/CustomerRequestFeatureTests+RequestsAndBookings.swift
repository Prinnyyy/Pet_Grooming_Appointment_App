import Foundation
import Testing
@testable import Beckon

extension CustomerRequestsStoreTests {
    @Test @MainActor
    func recentClosedRequestsCanKeepOnlyTheThreeNewestCancelledRecords() {
        let customerID = UUID()
        let petID = UUID()
        let requests = (1...7).map { day in
            Self.request(
                customerID: customerID,
                petID: petID,
                status: .cancelled,
                updatedAt: String(
                    format: "2026-06-%02dT12:00:00Z",
                    day
                )
            )
        }

        let recent = requests.recentClosedRequests(limit: 3)

        #expect(recent.count == 3)
        #expect(recent.map(\.updatedAt) == [
            "2026-06-07T12:00:00Z",
            "2026-06-06T12:00:00Z",
            "2026-06-05T12:00:00Z",
        ])
    }

    @Test @MainActor
    func requestPaginationRetriesThenAppendsUniqueRowsAndStopsAtLastPage() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let first = Self.request(customerID: customerID, petID: pet.id)
        let second = Self.request(customerID: customerID, petID: pet.id)
        let repository = CustomerRequestRepositoryFake(
            requestPages: [
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
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.load()
        await store.loadNextRequestsPage()

        #expect(store.requests.map(\.id) == [first.id])
        #expect(store.canLoadMoreRequests == true)
        #expect(store.errorMessage == "Check your connection and try again.")

        await store.loadNextRequestsPage()

        #expect(repository.receivedRequestPages == [.first, .first.next, .first.next])
        #expect(store.requests.map(\.id) == [first.id, second.id])
        #expect(store.canLoadMoreRequests == false)
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

        await store.acknowledgeBookingHandoff(for: store.bookingHandoffs[0])

        #expect(store.bookingHandoffs.isEmpty)
        #expect(store.requests.first?.status == .booked)
    }

    @Test @MainActor
    func bookingHandoffLoadFailureDoesNotSurfaceAsRequestUpdateError() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            bookingsResult: .failure(.unavailable)
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
        #expect(store.requests == [bookedRequest])
        #expect(store.bookingHandoffs.isEmpty)
        #expect(store.errorMessage == nil)
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
        await firstStore.acknowledgeBookingHandoff(for: handoff)

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
    func bookingHandoffLoadMergesRemoteAcknowledgementsWithLocalFallback() async throws {
        let customerID = UUID()
        let suiteName = "CustomerRequestsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let pet = Self.pet(customerID: customerID)
        let remoteAcknowledgedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let localAcknowledgedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let visibleRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        defaults.set(
            [localAcknowledgedRequest.id.uuidString],
            forKey: "beckon.customerRequests.bookingHandoffAcknowledgements.\(customerID.uuidString)"
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([
                remoteAcknowledgedRequest,
                localAcknowledgedRequest,
                visibleRequest,
            ]),
            acknowledgedBookingHandoffRequestIDsResult: .success([remoteAcknowledgedRequest.id])
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            bookingsResult: .success([
                Self.booking(requestID: remoteAcknowledgedRequest.id, customerID: customerID, status: .confirmed),
                Self.booking(requestID: localAcknowledgedRequest.id, customerID: customerID, status: .confirmed),
                Self.booking(requestID: visibleRequest.id, customerID: customerID, status: .confirmed),
            ])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: bookingRepository,
            handoffAcknowledgementDefaults: defaults
        )

        await store.load()

        #expect(requestRepository.acknowledgedBookingHandoffRequestIDsCallCount == 1)
        #expect(requestRepository.lastAcknowledgedBookingHandoffCustomerID == customerID)
        #expect(store.acknowledgedBookingHandoffRequestIDs == [
            remoteAcknowledgedRequest.id,
            localAcknowledgedRequest.id,
        ])
        #expect(store.bookingHandoffs.map(\.request.id) == [visibleRequest.id])
    }

    @Test @MainActor
    func acknowledgeBookingHandoffKeepsLocalFallbackWhenRemoteWriteFails() async throws {
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
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([bookedRequest]),
            acknowledgeBookingHandoffResult: .failure(.networkUnavailable)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake(
                bookingsResult: .success([booking])
            ),
            handoffAcknowledgementDefaults: defaults
        )
        await store.load()
        let handoff = try #require(store.bookingHandoffs.first)

        await store.acknowledgeBookingHandoff(for: handoff)

        #expect(requestRepository.acknowledgeBookingHandoffCallCount == 1)
        #expect(requestRepository.lastAcknowledgedBookingHandoffRequestID == bookedRequest.id)
        #expect(requestRepository.lastAcknowledgedBookingHandoffBookingID == booking.id)
        #expect(store.bookingHandoffs.isEmpty)
        #expect(store.acknowledgedBookingHandoffRequestIDs.contains(bookedRequest.id))
        #expect(
            defaults.stringArray(
                forKey: "beckon.customerRequests.bookingHandoffAcknowledgements.\(customerID.uuidString)"
            ) == [bookedRequest.id.uuidString]
        )
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
        await store.acknowledgeBookingHandoff(for: handoff)

        #expect(store.visibleActionCards.map(\.request.id) == [
            openRequest.id,
            offerRequest.id,
        ])
    }

}
