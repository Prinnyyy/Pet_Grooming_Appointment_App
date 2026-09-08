import Foundation
import Testing
import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
struct ServiceAgreementTests {
    @Test func displayedQuoteExpiresWithoutAnotherNetworkRead() throws {
        var offer = CustomerRequestsStoreTests.offerReview(customerID: UUID(), requestID: UUID()).offer
        offer.agreementSnapshotLoaded = true
        let expiry = try #require(GroomingRequestDateFormatting.parsedDate(from: offer.expiresAt))
        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: offer.proposedStart))
        let cutoff = min(expiry, start.addingTimeInterval(-300))
        #expect(!offer.hasPassedConfirmationDeadline(now: cutoff.addingTimeInterval(-1)))
        #expect(offer.hasPassedConfirmationDeadline(now: cutoff))
        #expect(offer.hasPassedConfirmationDeadline(now: cutoff.addingTimeInterval(1)))
    }

    @Test func legacyBookingNeverClaimsCurrentProfileAddressAsOriginal() {
        #expect(Self.booking().appointmentAddressSummary == "Original address unverified. Confirm with the other participant.")
    }

    @Test func agreementSurvivesLifecycleChanges() throws {
        var booking = Self.booking()
        booking.agreementSnapshot = try JSONDecoder().decode(ServiceAgreement.self, from: Self.snapshot)
        let cancelled = booking.replacing(status: .cancelledByCustomer, cancelledBy: booking.customerID,
            cancelledAt: "2026-09-09T20:00:00Z")
        #expect(cancelled.agreementSnapshot == booking.agreementSnapshot)
        #expect(cancelled.appointmentAddressSummary.contains("Unit 4B"))
        #expect(!cancelled.appointmentAddressSummary.contains("Current Profile"))
    }

    static func booking() -> Booking {
        Booking(id: UUID(), requestID: UUID(), offerID: UUID(), customerID: UUID(), groomerID: UUID(),
            scheduledStart: "2026-10-01T16:00:00Z", scheduledEnd: "2026-10-01T17:00:00Z",
            priceEstimate: 125, status: .confirmed, cancelledBy: nil, cancelledAt: nil,
            completedAt: nil, completedBy: nil, createdAt: "2026-09-08T20:00:00Z",
            updatedAt: "2026-09-08T20:00:00Z", review: nil,
            groomerBaseStreetAddress: "99 Current Profile Street", groomerBaseCity: "Seattle",
            groomerBaseState: "WA", groomerBaseZipCode: "98101", locationMode: .customerComesToGroomer)
    }

    @Test func completeSnapshotIncludesUnitAndUsesAgreedAddress() throws {
        let agreement = try JSONDecoder().decode(ServiceAgreement.self, from: Self.snapshot)
        #expect(agreement.address.summary == "10 Original Street, Unit 4B, Seattle, WA, 98101, US")
        #expect(agreement.serviceTimeZoneIdentifier == "America/Los_Angeles")
        #expect(agreement.isSupported)
        #expect(agreement.priceEstimate == 125)
    }

    @Test func unsupportedSnapshotCannotBecomeConfirmedTerms() throws {
        let data = Data(String(decoding: Self.snapshot, as: UTF8.self)
            .replacingOccurrences(of: "\"schema_version\":1", with: "\"schema_version\":99").utf8)
        #expect(try !JSONDecoder().decode(ServiceAgreement.self, from: data).isSupported)
    }

    @Test func temporaryCapacityAndTerminalValidityRemainIndependent() throws {
        let pending = try JSONDecoder().decode(QuoteEvaluation.self, from: Data(
            #"{"terms_valid":true,"selectable":false,"reason":"capacity_unavailable"}"#.utf8))
        #expect(pending.termsValid)
        #expect(!pending.selectable)
        #expect(pending.summary == "This time is currently unavailable. Check again before the offer expires.")
        let expired = try JSONDecoder().decode(QuoteEvaluation.self, from: Data(
            #"{"terms_valid":false,"selectable":false,"reason":"expired"}"#.utf8))
        #expect(!expired.termsValid)
        #expect(expired.summary == "This offer has expired. Request a new offer.")
    }

    static let snapshot = Data(#"""
    {"schema_version":1,"request_revision":"11111111-1111-4111-8111-111111111111",
     "quote_revision":"22222222-2222-4222-8222-222222222222",
     "pet_id":"33333333-3333-4333-8333-333333333333",
     "pet_snapshot":{"id":"33333333-3333-4333-8333-333333333333","name":"Mochi","species":"Dog"},
     "service_type":"full_groom","service_notes":"Quiet appointment",
     "location_mode":"customer_comes_to_groomer",
     "address":{"street_address":"10 Original Street","address_line_2":"Unit 4B",
       "city":"Seattle","state":"WA","zip_code":"98101","country_code":"US"},
     "service_time_zone_identifier":"America/Los_Angeles",
     "scheduled_start":"2026-10-01T16:00:00Z","scheduled_end":"2026-10-01T17:00:00Z",
     "price_estimate":125,"currency":"USD","captured_at":"2026-09-08T20:00:00Z"}
    """#.utf8)
}

@MainActor
final class ServiceAgreementRenderingTests: XCTestCase {
    func testReplacementReviewKeepsOriginalUntilPublishing() async throws {
        let owner = UUID()
        let pet = CustomerRequestsStoreTests.pet(customerID: owner)
        var request = CustomerRequestsStoreTests.request(customerID: owner, petID: pet.id)
        request.termsRevision = UUID()
        let repository = CustomerRequestRepositoryFake(requestsResult: .success([request]))
        let store = CustomerRequestsStore(customerID: owner,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
            requestRepository: repository, bookingRepository: CustomerRequestBookingRepositoryFake())
        await store.load()
        store.startRevision(from: request)
        store.wizardInitialStep = .review
        let host = UIHostingController(rootView: CustomerRequestWizardView(store: store))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(400))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "T-376 request replacement review"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(store.isRevisingRequest)
        XCTAssertEqual(repository.cancelCallCount, 0)
        XCTAssertEqual(repository.createCallCount, 0)
        XCTAssertEqual(store.request(withID: request.id)?.status, request.status)
    }

    func testBothParticipantsSeeAgreedOrExplicitlyUnverifiedAddress() async throws {
        for role in [UserRole.customer, .groomer] {
            for verified in [true, false] {
                var booking = ServiceAgreementTests.booking()
                if verified {
                    booking.agreementSnapshot = try JSONDecoder().decode(ServiceAgreement.self, from: ServiceAgreementTests.snapshot)
                }
                let store = BookingsStore(participantID: role == .customer ? booking.customerID : booking.groomerID,
                    role: role, repository: BookingRepositoryFake(), initialBookings: [booking],
                    appointmentReminderScheduler: AppointmentReminderSchedulerFake())
                let host = UIHostingController(rootView: NavigationStack {
                    BookingDetailView(bookingID: booking.id, role: role, store: store)
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
                try await Task.sleep(for: .milliseconds(250))
                func scrolls(_ view: UIView) -> [UIScrollView] {
                    (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap(scrolls)
                }
                if let scroll = scrolls(host.view).first {
                    scroll.setContentOffset(CGPoint(x: 0, y: min(420, max(0, scroll.contentSize.height-scroll.bounds.height))), animated: false)
                }
                host.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(200))
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "T-376 \(role) agreement \(verified ? "verified" : "legacy")"
                attachment.lifetime = .keepAlways
                add(attachment)
                XCTAssertEqual(image.size, window.bounds.size)
                XCTAssertEqual(store.booking(withID: booking.id)?.agreementSnapshot, booking.agreementSnapshot)
            }
        }
    }
}
