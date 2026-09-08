import Foundation
import Testing
import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class BookingFulfillmentRenderingTests: XCTestCase {
    func testBothParticipantsSeeReportedOutcomeOnCompactScreen() async throws {
        for role: UserRole in [.customer, .groomer] {
            try await render(role: role, largeText: false)
        }
    }

    func testReportedOutcomeRemainsScrollableAtAccessibilitySize() async throws {
        try await render(role: .groomer, largeText: true)
    }

    private func render(role: UserRole, largeText: Bool) async throws {
        var booking = ServiceAgreementTests.booking()
        booking.fulfillment = BookingFulfillment(revision: UUID(), phase: .outcomeReported, basis: "live",
            actualStartedAt: booking.scheduledStart, actualEndedAt: nil, petReleaseAt: nil,
            resourceReleaseAt: nil, reportedOutcome: "interruption", reportedBy: booking.customerID,
            reportedAt: booking.scheduledStart, reportPreviousPhase: "in_service",
            reportNote: "Service was interrupted. Please confirm the outcome before releasing reserved time.")
        let store = BookingsStore(participantID: role == .customer ? booking.customerID : booking.groomerID,
            role: role, repository: BookingRepositoryFake(), initialBookings: [booking],
            appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        let host = UIHostingController(rootView: NavigationStack {
            BookingDetailView(bookingID: booking.id, role: role, store: store)
                .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large)
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
        try await Task.sleep(for: .milliseconds(350))
        let scroll = try XCTUnwrap(Self.scrollViews(host.view).first { $0.contentSize.height > $0.bounds.height })
        scroll.setContentOffset(CGPoint(x: 0, y: max(0,
            scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
        try await Task.sleep(for: .milliseconds(350))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "T-377 \(role.rawValue) outcome \(largeText ? "accessibility" : "compact")"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(scroll.contentOffset.y, 0)
        XCTAssertTrue(store.fulfillmentActions(for: booking).contains(role == .customer ? .withdrawReport : .confirmStop))
        XCTAssertFalse(store.fulfillmentActions(for: booking).contains(.cancel))
        let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(pixels))
        XCTAssertGreaterThan(Set(stride(from: 0, to: CFDataGetLength(pixels), by: 4).map { bytes[$0] }).count, 8)
    }

    private static func scrollViews(_ view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews($0) }
    }
}

@MainActor
struct BookingFulfillmentTests {
    @Test func provisionalHandoffCannotMutateBeforeAuthoritativeRefresh() async {
        let provisional = ServiceAgreementTests.booking()
        let repository = BookingRepositoryFake(bookingsResult: .failure(.networkUnavailable))
        let store = BookingsStore(participantID: provisional.customerID, role: .customer,
            repository: repository, initialBookings: [provisional],
            appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        #expect(store.fulfillmentActions(for: provisional).isEmpty)
        await store.performFulfillment(.cancel, for: provisional)
        #expect(repository.fulfillmentOperations.isEmpty)
        await store.refreshFulfillment(for: provisional.id)
        #expect(store.errorMessage != nil)
        #expect(store.booking(withID: provisional.id)?.fulfillment == nil)
        var current = provisional
        current.fulfillment = state(.scheduled)
        repository.bookingsResult = .success([current])
        await store.refreshFulfillment(for: provisional.id)
        #expect(store.errorMessage == nil)
        #expect(store.booking(withID: provisional.id)?.fulfillment == current.fulfillment)
        #expect(repository.fulfillmentOperations.isEmpty)
    }

    @Test func fulfillmentTransportPreservesVersionAndExactIntent() throws {
        let operation = BookingFulfillmentOperation(id: UUID(), bookingID: UUID(), expectedRevision: UUID(),
            action: .reportInterruption, note: "Service stopped")
        let data = try JSONEncoder().encode(SupabaseFulfillmentParameters(operation: operation))
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == ["p_operation_id": operation.id.uuidString, "p_booking_id": operation.bookingID.uuidString,
            "p_expected_revision": operation.expectedRevision.uuidString, "p_action": "report_interruption",
            "p_note": "Service stopped"])
    }

    @Test func fulfillmentPayloadCannotFallBackToLegacyWhenStateIsMalformed() throws {
        let booking = ServiceAgreementTests.booking()
        var body: [String: Any] = ["id": booking.id.uuidString, "request_id": booking.requestID.uuidString,
            "offer_id": booking.offerID.uuidString, "customer_id": booking.customerID.uuidString,
            "groomer_id": booking.groomerID.uuidString, "scheduled_start": booking.scheduledStart,
            "scheduled_end": booking.scheduledEnd, "price_estimate": booking.priceEstimate,
            "status": "unfulfilled", "created_at": booking.createdAt, "updated_at": booking.updatedAt]
        let fulfillment = state(.unfulfilled)
        let fields = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fulfillment)) as? [String: Any])
        body.merge(fields) { _, new in new }
        let decoded = try JSONDecoder().decode(SupabaseBookingRow.self, from: JSONSerialization.data(withJSONObject: body))
        #expect(decoded.booking.fulfillment == fulfillment)
        #expect(decoded.booking.status == .unfulfilled)
        body["fulfillment_phase"] = "invalid"
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(SupabaseBookingRow.self, from: JSONSerialization.data(withJSONObject: body))
        }
    }

    @Test func uncertainOperationSurvivesRestartAndStatusCheckNeverWrites() async throws {
        let suite = "T377.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var booking = ServiceAgreementTests.booking()
        booking.fulfillment = state(.scheduled)
        let repository = BookingRepositoryFake()
        let reminders = AppointmentReminderSchedulerFake()
        let store = BookingsStore(participantID: booking.customerID, role: .customer,
            repository: repository, initialBookings: [booking],
            appointmentReminderScheduler: reminders, fulfillmentDefaults: defaults)
        await store.performFulfillment(.cancel, for: booking)
        let pending = try #require(store.pendingFulfillmentOperation(for: booking.id))
        #expect(repository.fulfillmentOperations.count == 1)
        #expect(reminders.cancelledReminderIDs.isEmpty)
        let restarted = BookingsStore(participantID: booking.customerID, role: .customer,
            repository: repository, initialBookings: [booking],
            appointmentReminderScheduler: reminders, fulfillmentDefaults: defaults)
        #expect(restarted.pendingFulfillmentOperation(for: booking.id) == pending)
        await restarted.recoverFulfillment(for: booking.id)
        #expect(repository.fulfillmentOperations.count == 1)
        #expect(repository.fulfillmentLookupCount == 1)
        await restarted.performFulfillment(.cancel, for: booking)
        #expect(repository.fulfillmentOperations.count == 1)
        await restarted.recoverFulfillment(for: booking.id, retryIfMissing: true)
        #expect(repository.fulfillmentOperations == [pending, pending])

        var current = booking.replacing(status: .cancelledByCustomer,
            cancelledBy: booking.customerID, cancelledAt: "2026-09-08T12:00:00Z")
        current.fulfillment = state(.cancelled)
        repository.fulfillmentLookup = BookingFulfillmentResult(receipt: BookingFulfillmentReceipt(
            id: UUID(), operationID: pending.id, bookingID: booking.id, action: .cancel,
            resultRevision: current.fulfillment!.revision, recordedAt: "2026-09-08T12:00:00Z"),
            booking: current, replayed: true)
        await restarted.recoverFulfillment(for: booking.id)
        #expect(restarted.pendingFulfillmentOperation(for: booking.id) == nil)
        #expect(restarted.booking(withID: booking.id)?.status == .cancelledByCustomer)
        #expect(repository.fulfillmentOperations.count == 2)
        #expect(reminders.cancelledReminderIDs == [booking.id])
        let third = BookingsStore(participantID: booking.customerID, role: .customer,
            repository: repository, fulfillmentDefaults: defaults)
        #expect(third.pendingFulfillmentOperation(for: booking.id) == nil)
    }

    private func state(_ phase: BookingFulfillmentPhase, actualStart: String? = nil, reporter: UUID? = nil) -> BookingFulfillment {
        BookingFulfillment(revision: UUID(), phase: phase, basis: "live", actualStartedAt: actualStart,
            actualEndedAt: nil, petReleaseAt: nil, resourceReleaseAt: nil, reportedOutcome: "interruption",
            reportedBy: reporter, reportedAt: nil, reportPreviousPhase: "in_service", reportNote: "Stopped")
    }

    @Test func futureBookingCannotBeCompletedBeforeActualStart() throws {
        let booking = ServiceAgreementTests.booking()
        let before = try #require(GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart))
            .addingTimeInterval(-60)
        #expect(!booking.canComplete(for: .groomer, now: before))
    }

    @Test func startDoesNotPermitInstantCompletion() throws {
        var booking = ServiceAgreementTests.booking()
        booking.fulfillment = state(.inService, actualStart: booking.scheduledStart)
        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart))
        #expect(!booking.canComplete(for: .groomer, now: start.addingTimeInterval(59)))
        #expect(booking.canComplete(for: .groomer, now: start.addingTimeInterval(60)))
        #expect(!booking.canComplete(for: .customer, now: start.addingTimeInterval(60)))
    }

    @Test func noShowWaitAndElapsedRecoveryHaveExplicitBoundaries() throws {
        var booking = ServiceAgreementTests.booking()
        booking.fulfillment = state(.scheduled)
        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart))
        #expect(booking.fulfillmentActions(for: .customer, participantID: booking.customerID, now: start.addingTimeInterval(-1)) == [.cancel])
        #expect(!booking.fulfillmentActions(for: .customer, participantID: booking.customerID, now: start.addingTimeInterval(899)).contains(.reportNoShow))
        #expect(booking.fulfillmentActions(for: .customer, participantID: booking.customerID, now: start.addingTimeInterval(900)).contains(.reportNoShow))
        let end = try #require(GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd))
        #expect(booking.fulfillmentActions(for: .customer, participantID: booking.customerID, now: end).contains(.closeElapsed))
        #expect(booking.fulfillmentActions(for: .groomer, participantID: booking.groomerID, now: end).contains(.reportCompletion))
        #expect(!booking.fulfillmentActions(for: .groomer, participantID: booking.groomerID, now: end).contains(.start))
    }

    @Test func reportAuthorCannotSupplyBothParticipantsConsent() {
        var booking = ServiceAgreementTests.booking()
        booking.fulfillment = state(.outcomeReported, reporter: booking.customerID)
        let customer = booking.fulfillmentActions(for: .customer, participantID: booking.customerID)
        let groomer = booking.fulfillmentActions(for: .groomer, participantID: booking.groomerID)
        #expect(customer.contains(.withdrawReport))
        #expect(!customer.contains(.confirmStop))
        #expect(groomer.contains(.confirmStop))
        #expect(booking.fulfillmentActions(for: .customer, participantID: UUID()).isEmpty)
        #expect(booking.replacing(status: .confirmed, cancelledBy: nil, cancelledAt: nil).fulfillment == booking.fulfillment)
    }
}
