import Foundation
import Testing
import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class CustomerTimingRecoveryRenderingTests: XCTestCase {
    func testOldRequestExposesRecoveryWithoutCancellingOnRender() async throws {
        let owner = UUID()
        let pet = CustomerRequestsStoreTests.pet(customerID: owner)
        let request = CustomerRequestsStoreTests.request(customerID: owner, petID: pet.id)
        let newRequestID = UUID()
        let provider = TimingRecoveryAddressProvider()
        let repository = CustomerRequestRepositoryFake(requestsResult: .success([request]),
            createResult: .success(GroomingRequestPublishResult(requestID: newRequestID, matchCount: 1)),
            cancelResult: .success(CancelGroomingRequestResult(requestID: request.id,
                requestStatus: .cancelled, cancelledTimestamp: "2026-09-08T15:00:00Z")))
        let store = CustomerRequestsStore(customerID: owner,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
            requestRepository: repository, bookingRepository: CustomerRequestBookingRepositoryFake(),
            addressProvider: provider)
        await store.load()
        let host = UIHostingController(rootView: NavigationStack {
            CustomerRequestDetailView(requestID: request.id, store: store)
                .sheet(isPresented: Binding(get: { store.isShowingWizard }, set: { store.setWizardPresentation($0) })) {
                    CustomerRequestWizardView(store: store)
                }
        })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        func scrollViews(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews($0) }
        }
        let scroll = try XCTUnwrap(scrollViews(host.view).first { $0.contentSize.height > $0.bounds.height })
        for _ in 0..<6 {
            scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height
                + scroll.adjustedContentInset.bottom)), animated: false)
            try await Task.sleep(for: .milliseconds(150))
        }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data) as Data
        XCTAssertGreaterThan(Set(stride(from: 0, to: pixels.count, by: 4).map { pixels[$0] }).count, 8)
        let attachment = XCTAttachment(image: image)
        attachment.name = "T-374 customer timing recovery"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(repository.cancelCallCount, 0)
        if FileManager.default.fileExists(atPath: "/tmp/beckon-t374-customer-recovery-interaction") {
            for _ in 0..<180 where !store.isShowingWizard {
                try await Task.sleep(for: .seconds(1))
            }
            XCTAssertEqual(repository.cancelCallCount, 1)
            XCTAssertEqual(store.request(withID: request.id)?.status, .cancelled)
            XCTAssertTrue(store.isShowingWizard)
            XCTAssertEqual(store.wizardInitialStep, .time)
            XCTAssertNil(store.addressEditorState.confirmedAddress)
            try await Task.sleep(for: .milliseconds(500))
            let wizard = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let wizardAttachment = XCTAttachment(image: wizard)
            wizardAttachment.name = "T-374 recovery template wizard"
            wizardAttachment.lifetime = .keepAlways
            add(wizardAttachment)
            for _ in 0..<240 where repository.createCallCount == 0 {
                try await Task.sleep(for: .seconds(1))
            }
            XCTAssertEqual(repository.createCallCount, 1)
            XCTAssertGreaterThan(provider.geocodeCount, 0)
            let draft = try XCTUnwrap(repository.lastDraft)
            XCTAssertEqual(draft.petID, pet.id)
            XCTAssertEqual(draft.serviceType, request.serviceType)
            XCTAssertEqual(draft.confirmedAddress?.timeZoneIdentifier, "America/Los_Angeles")
            XCTAssertGreaterThan(draft.preferredEnd, draft.preferredStart)
            XCTAssertNotEqual(newRequestID, request.id)
            XCTAssertEqual(repository.cancelCallCount, 1)
        }
    }
}

@MainActor
private final class TimingRecoveryAddressProvider: BeckonAddressProviding {
    private(set) var geocodeCount = 0
    func clear() {}
    func updateSuggestions(for line1Query: String) async -> [BeckonAddressCandidate] { [] }
    func resolve(candidateID: String, preservingLine2: String) async throws -> BeckonResolvedAddress {
        throw BeckonAddressProviderError.unknownCandidate
    }
    func geocode(_ input: BeckonAddressInput) async throws -> [BeckonResolvedAddress] {
        geocodeCount += 1
        return [BeckonResolvedAddress(provider: "apple_maps", placeID: nil,
            coordinate: BeckonAddressCoordinate(latitude: 33.8703, longitude: -117.9242),
            suggested: input, resolutionSource: "manual_geocode", timeZoneIdentifier: "America/Los_Angeles")]
    }
}

extension CustomerRequestsStoreTests {
    @Test @MainActor
    func defaultDetailRepublishActionOpensUnconfirmedTemplate() async {
        let owner = UUID()
        let pet = Self.pet(customerID: owner)
        let request = Self.request(customerID: owner, petID: pet.id, status: .cancelled)
        let store = CustomerRequestsStore(customerID: owner,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
            requestRepository: CustomerRequestRepositoryFake(requestsResult: .success([request])),
            bookingRepository: CustomerRequestBookingRepositoryFake())
        await store.load()
        let detail = CustomerRequestDetailView(requestID: request.id, store: store)
        detail.onRepublishRequest(request)
        #expect(store.isShowingWizard)
        #expect(store.wizardInitialStep == .time)
        #expect(store.addressEditorState.confirmedAddress == nil)
        #expect(store.request(withID: request.id)?.status == .cancelled)
    }

    @Test @MainActor
    func failedTimingRecoveryCancellationDoesNotEnableRepublish() async throws {
        let owner = UUID()
        let pet = Self.pet(customerID: owner)
        let request = Self.request(customerID: owner, petID: pet.id)
        let repository = CustomerRequestRepositoryFake(requestsResult: .success([request]),
            cancelResult: .failure(.networkUnavailable))
        let store = CustomerRequestsStore(customerID: owner,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
            requestRepository: repository, bookingRepository: CustomerRequestBookingRepositoryFake())
        await store.load()
        await store.cancel(request)
        let retained = try #require(store.request(withID: request.id))
        #expect(retained.status == request.status)
        #expect(!CustomerRequestDetailPresentation(status: retained.status).showsRepublish)
        #expect(store.errorMessage != nil)
        #expect(store.cancellingRequestIDs.isEmpty)
        #expect(repository.cancelCallCount == 1)
    }

    @Test @MainActor
    func timingRecoveryRequiresOpenRequestAndMissingReferenceZone() {
        for status in GroomingRequestStatus.allCases {
            for zone in [nil, "Invalid/Zone", "America/New_York"] as [String?] {
                let presentation = CustomerRequestDetailPresentation(status: status, preferenceTimeZoneIdentifier: zone)
                #expect(presentation.showsTimingRecovery ==
                    (status.isOpenForOffers && zone != "America/New_York"))
                #expect(presentation.showsRepublish == (status == .cancelled))
            }
        }
    }

    @Test @MainActor
    func requestCardOffersActionUsesAuthoritativeRequestStatus() {
        let open = CustomerRequestCardActionsPresentation(status: .open)
        let hasOffers = CustomerRequestCardActionsPresentation(status: .hasOffers)

        #expect(open.isOffersEnabled == false)
        #expect(hasOffers.isOffersEnabled)
    }

    @Test @MainActor
    func cancelledRequestDetailShowsRepublishWithoutOwningOffers() {
        let cancelled = CustomerRequestDetailPresentation(status: .cancelled)
        let open = CustomerRequestDetailPresentation(status: .open)

        #expect(cancelled.showsRepublish)
        #expect(open.showsRepublish == false)
    }

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
        var notificationRefreshCount = 0
        store.setNotificationRefresh {
            notificationRefreshCount += 1
        }
        await store.load()

        await store.cancel(request)

        #expect(requestRepository.cancelCallCount == 1)
        #expect(requestRepository.lastCancelRequestID == request.id)
        #expect(store.requests.first?.status == .cancelled)
        #expect(store.noticeMessage == "Request cancelled.")
        #expect(notificationRefreshCount == 1)
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
