import Foundation
import Observation
import SwiftUI
import Testing
import UIKit
import XCTest
@testable import Beckon

@MainActor
struct UIModuleFlowTests {
    private func requestStore() -> CustomerRequestsStore {
        CustomerRequestsStore(customerID: UUID(), petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(), bookingRepository: BookingRepositoryFake(),
            appointmentReminderScheduler: AppointmentReminderSchedulerFake())
    }

    private func profile(owner: UUID) -> CustomerProfileDetails {
        CustomerProfileDetails(userID: owner, nickname: "Owner", avatarPath: nil,
            streetAddress: "100 Main Street", city: "Seattle", stateCode: .washington,
            zipCode: "98101", contactEmail: nil, phoneNumber: nil)
    }

    @Test func profileAddressLoadsIntoDraftAndClearsFieldErrors() async {
        let store = requestStore()
        let repository = CustomerProfileRepositoryFake(profileResult: .success(profile(owner: store.customerID)))
        let flow = CustomerRequestWizardState(store: store, profileRepository: repository)
        flow.invalidFields = [.streetAddress, .city, .state, .zipCode, .notes]
        #expect(await flow.applyProfileAddress() == .applied)
        #expect(store.streetAddress == "100 Main Street")
        #expect(store.city == "Seattle")
        #expect(flow.invalidFields == [.notes])
        #expect(!flow.isApplyingProfileAddress)
    }

    @Test(arguments: [false, true])
    func staleProfileReadCannotOverwriteEditedOrDismissedDraft(dismiss: Bool) async throws {
        let store = requestStore()
        let repository = CustomerProfileRepositoryFake(profileResult: .success(profile(owner: store.customerID)))
        var pending: CheckedContinuation<Void, Never>?
        repository.onProfileRead = { await withCheckedContinuation { pending = $0 } }
        defer { pending?.resume() }
        let flow = CustomerRequestWizardState(store: store, profileRepository: repository)
        let load = Task { await flow.applyProfileAddress() }
        for _ in 0..<100 where pending == nil { await Task.yield() }
        _ = try #require(pending)
        #expect(await flow.applyProfileAddress() == .cancelled)
        if dismiss { flow.cancelPendingLoads() }
        store.addressEditorState.updateLine1("My newer address")
        pending?.resume()
        pending = nil
        #expect(await load.value == .cancelled)
        #expect(store.streetAddress == "My newer address")
        #expect(!flow.isApplyingProfileAddress)
    }

    @Test func profileAddressFailuresAreDistinctFromMissingAndCancellation() async {
        let store = requestStore()
        let repository = CustomerProfileRepositoryFake(profileResult: .failure(.networkUnavailable))
        let flow = CustomerRequestWizardState(store: store, profileRepository: repository)
        #expect(await flow.applyProfileAddress() == .unavailable)
        repository.profileResult = .failure(.cancelled)
        #expect(await flow.applyProfileAddress() == .cancelled)
        repository.profileResult = CustomerProfileRepositoryFake().profileResult
        #expect(await flow.applyProfileAddress() == .missing)
        #expect(!flow.isApplyingProfileAddress)
    }

    @Test func invalidWizardStepDoesNotAdvanceOrRequestPublication() async {
        let flow = CustomerRequestWizardState(store: requestStore())
        flow.currentStep = .pet
        #expect(await flow.continueForward() == false)
        #expect(flow.currentStep == .pet)
        #expect(flow.invalidFields.contains(.pet))
    }

    @Test func quoteStatePreservesAmbiguousAndNonexistentTimeGuards() async throws {
        let owner = UUID()
        let base = GroomerRequestsStoreTests.matchedRequest(groomerID: owner)
        var request = base.request
        request.preferenceTimeZoneIdentifier = "America/New_York"
        let matched = GroomerMatchedRequest(match: base.match, request: request, offer: nil)
        let store = GroomerRequestsStore(groomerID: owner, repository: GroomerRequestRepositoryFake(),
            profileRepository: GroomerProfileRepositoryFake())
        let form = GroomerOfferFormState(store: store)
        await form.initializeOfferFormIfNeeded(for: matched)
        #expect(form.didInitializeOfferForm)
        form.durationMinutesText = "60"
        form.proposedStart = try #require(ISO8601DateFormatter().date(from: "2026-11-01T01:30:00Z"))
        guard case let .ambiguous(first, last) = form.proposedStartResolution else {
            Issue.record("Expected ambiguous New York fall-back time")
            return
        }
        #expect(form.proposedEnd == nil)
        form.selectedOccurrence = last
        #expect(form.resolvedProposedStart == last)
        #expect(form.proposedEnd == last.addingTimeInterval(3600))
        form.selectedOccurrence = first.addingTimeInterval(60)
        #expect(form.resolvedProposedStart == nil)
        form.proposedStart = try #require(ISO8601DateFormatter().date(from: "2026-03-08T02:30:00Z"))
        #expect(form.proposedStartResolution == .nonexistent)
        #expect(form.proposedEnd == nil)
    }
}

@MainActor
final class BookingNavigationRenderingTests: XCTestCase {
    func testHomeBookingHandoffResolvesExactBookingOutsideLoadedPage() async throws {
        try await renderBookingHandoff(alreadySelected: false)
    }

    func testHandoffBeforeBookingsTabAppearsStillOpensSelectedBooking() async throws {
        try await renderBookingHandoff(alreadySelected: true)
    }

    private func renderBookingHandoff(alreadySelected: Bool) async throws {
        let owner = UUID()
        let booking = BookingsStoreTests.booking(groomerID: owner)
        let repository = BookingRepositoryFake(bookingsResult: .success([]))
        let loaded = expectation(description: "Selected appointment resolved by ID")
        var didResolve = false
        repository.exactRead = { ids in
            XCTAssertEqual(ids, [booking.id])
            if !didResolve {
                didResolve = true
                loaded.fulfill()
            }
            return [booking]
        }
        let store = BookingsStore(participantID: owner, role: .groomer, repository: repository,
            appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        let route = BookingNavigationTestRoute()
        if alreadySelected { route.booking = booking }
        let host = UIHostingController(rootView: NavigationStack {
            BookingsView(role: .groomer, store: store, focusedBooking: Binding(
                get: { route.booking }, set: { route.booking = $0 }
            ))
        })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await Task.sleep(for: .milliseconds(300))
        if !alreadySelected { route.booking = booking }
        await fulfillment(of: [loaded], timeout: 5)
        XCTAssertEqual(store.booking(withID: booking.id)?.id, booking.id)
        try await Task.sleep(for: .milliseconds(300))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "T-396 exact booking destination"
        attachment.lifetime = .keepAlways
        add(attachment)
        route.booking = nil
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(route.booking)
    }
}

@MainActor @Observable
private final class BookingNavigationTestRoute {
    var booking: Booking?
}
