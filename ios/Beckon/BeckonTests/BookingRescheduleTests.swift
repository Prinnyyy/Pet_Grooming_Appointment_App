import Foundation
import Testing
import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
struct BookingRescheduleTests {
    static func booking(seed: Booking? = nil, shift: TimeInterval = 0) throws -> Booking {
        let original = seed ?? ServiceAgreementTests.booking()
        let start = seed.flatMap { GroomingRequestDateFormatting.parsedDate(from: $0.scheduledStart) }
            ?? Date().addingTimeInterval(86400 * 3)
        let starts = GroomingRequestDateFormatting.serverString(from: start.addingTimeInterval(shift))
        let ends = GroomingRequestDateFormatting.serverString(from: start.addingTimeInterval(shift + 3600))
        var agreement = try #require(JSONSerialization.jsonObject(with: ServiceAgreementTests.snapshot) as? [String: Any])
        agreement["scheduled_start"] = starts
        agreement["scheduled_end"] = ends
        return Booking(id: original.id, requestID: original.requestID, offerID: original.offerID,
            customerID: original.customerID, groomerID: original.groomerID, scheduledStart: starts, scheduledEnd: ends,
            priceEstimate: 125, status: .confirmed, cancelledBy: nil, cancelledAt: nil, completedAt: nil, completedBy: nil,
            createdAt: original.createdAt, updatedAt: original.updatedAt, review: nil,
            appliedTimingBuffers: try GroomingTimingBuffers(preparation: 0, cleanup: 10, inboundTravel: 0, outboundTravel: 0),
            serviceTimeZoneIdentifier: "America/Los_Angeles", scheduleTimeZoneIdentifier: "America/Los_Angeles",
            agreementSnapshot: try JSONDecoder().decode(ServiceAgreement.self, from: JSONSerialization.data(withJSONObject: agreement)),
            fulfillment: BookingFulfillment(revision: UUID(), phase: .scheduled, basis: "live", actualStartedAt: nil,
                actualEndedAt: nil, petReleaseAt: nil, resourceReleaseAt: nil, reportedOutcome: nil,
                reportedBy: nil, reportedAt: nil, reportPreviousPhase: nil, reportNote: nil))
    }

    static func proposal(for booking: Booking, id: UUID = UUID(), status: BookingRescheduleStatus = .pending,
        expires: Date = Date().addingTimeInterval(3600)) throws -> BookingRescheduleProposal {
        var original = try #require(JSONSerialization.jsonObject(with: ServiceAgreementTests.snapshot) as? [String: Any])
        original["scheduled_start"] = booking.scheduledStart
        original["scheduled_end"] = booking.scheduledEnd
        let newStart = GroomingRequestDateFormatting.serverString(from:
            try #require(GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart)).addingTimeInterval(3600))
        let newEnd = GroomingRequestDateFormatting.serverString(from:
            try #require(GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd)).addingTimeInterval(3600))
        var proposed = original
        proposed["scheduled_start"] = newStart
        proposed["scheduled_end"] = newEnd
        let body: [String: Any] = ["id": id.uuidString, "booking_id": booking.id.uuidString,
            "base_revision": booking.fulfillment!.revision.uuidString, "initiator_id": booking.customerID.uuidString,
            "proposed_start": newStart, "proposed_end": newEnd,
            "previous_agreement": original, "proposed_agreement": proposed, "status": status.rawValue,
            "effective_status": status.rawValue, "expires_at": GroomingRequestDateFormatting.serverString(from: expires)]
        return try JSONDecoder().decode(BookingRescheduleProposal.self, from: JSONSerialization.data(withJSONObject: body))
    }

    @Test func proposalRequiresOtherParticipantAndStopsAtDeadline() throws {
        let booking = try Self.booking()
        let now = Date()
        let proposal = try Self.proposal(for: booking, expires: now.addingTimeInterval(60))
        #expect(proposal.actions(for: booking, participantID: booking.customerID, now: now) == [.withdraw])
        #expect(proposal.actions(for: booking, participantID: booking.groomerID, now: now) == [.accept, .reject])
        #expect(proposal.actions(for: booking, participantID: UUID(), now: now).isEmpty)
        #expect(proposal.currentStatus(for: booking, now: now.addingTimeInterval(61)) == .expired)
        #expect(proposal.currentStatus(for: try Self.booking(seed: booking), now: now) == .invalidated)
    }

    @Test func acceptedSnapshotReplacesTimesRatherThanOnlyStatus() throws {
        let original = try Self.booking()
        let changed = try Self.booking(seed: original, shift: 1800)
        let applied = original.applyingReschedule(changed)
        #expect(applied.id == original.id)
        #expect(applied.scheduledStart == changed.scheduledStart)
        #expect(applied.agreementSnapshot == changed.agreementSnapshot)
        #expect(applied.fulfillment == changed.fulfillment)
    }

    @Test func lostAcceptanceSurvivesRestartWithoutAnotherProposalAndUpdatesReminder() async throws {
        let suite = "T378.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = try Self.booking()
        let proposal = try Self.proposal(for: original)
        let repository = BookingRepositoryFake()
        repository.rescheduleResult = .success(BookingRescheduleResult(booking: original, proposal: proposal, receipt: nil))
        let reminders = AppointmentReminderSchedulerFake()
        let store = BookingsStore(participantID: original.groomerID, role: .groomer, repository: repository,
            initialBookings: [original], appointmentReminderScheduler: reminders, fulfillmentDefaults: defaults)
        await store.loadReschedule(for: original.id)
        await store.performReschedule(.accept, for: original, reviewedProposal: proposal)
        let pending = try #require(store.pendingRescheduleOperation(for: original.id))
        #expect(repository.rescheduleOperations.count == 1)
        #expect(reminders.cancelledReminderIDs.isEmpty)
        let restarted = BookingsStore(participantID: original.groomerID, role: .groomer, repository: repository,
            initialBookings: [original], appointmentReminderScheduler: reminders, fulfillmentDefaults: defaults)
        #expect(restarted.pendingRescheduleOperation(for: original.id) == pending)
        await restarted.recoverReschedule(for: original.id)
        #expect(repository.rescheduleOperations.count == 1)
        await restarted.recoverReschedule(for: original.id, retryIfMissing: true)
        #expect(repository.rescheduleOperations == [pending, pending])
        let current = try Self.booking(seed: original, shift: 3600)
        repository.rescheduleLookup = BookingRescheduleResult(booking: current,
            proposal: try Self.proposal(for: original, id: proposal.id, status: .accepted),
            receipt: BookingRescheduleReceipt(operationID: pending.id, bookingID: original.id, proposalID: proposal.id,
                action: .accept, resultRevision: current.fulfillment!.revision))
        await restarted.recoverReschedule(for: original.id)
        #expect(restarted.pendingRescheduleOperation(for: original.id) == nil)
        #expect(restarted.booking(withID: original.id)?.scheduledStart == current.scheduledStart)
        #expect(reminders.cancelledReminderIDs == [original.id])
        #expect(reminders.lastSyncedBookings?.map(\.scheduledStart) == [current.scheduledStart])
    }

    @Test func changedProposalCannotReplaceTheOneActuallyReviewed() async throws {
        let booking = try Self.booking()
        let reviewed = try Self.proposal(for: booking)
        let repository = BookingRepositoryFake()
        repository.rescheduleResult = .success(BookingRescheduleResult(booking: booking,
            proposal: try Self.proposal(for: booking), receipt: nil))
        let store = BookingsStore(participantID: booking.groomerID, role: .groomer, repository: repository, initialBookings: [booking])
        await store.loadReschedule(for: booking.id)
        await store.performReschedule(.accept, for: booking, reviewedProposal: reviewed)
        #expect(repository.rescheduleOperations.isEmpty)
        #expect(store.rescheduleErrors[booking.id]?.contains("Review the current proposal") == true)
    }
}

@MainActor
final class BookingRescheduleRenderingTests: XCTestCase {
    func testBothParticipantsReviewDistinctOriginalAndProposedTimes() async throws {
        let booking = try BookingRescheduleTests.booking()
        let proposal = try BookingRescheduleTests.proposal(for: booking)
        for role: UserRole in [.customer, .groomer] {
            let repository = BookingRepositoryFake()
            repository.rescheduleResult = .success(BookingRescheduleResult(booking: booking, proposal: proposal, receipt: nil))
            let store = BookingsStore(participantID: role == .customer ? booking.customerID : booking.groomerID,
                role: role, repository: repository, initialBookings: [booking],
                appointmentReminderScheduler: AppointmentReminderSchedulerFake())
            await store.loadReschedule(for: booking.id)
            XCTAssertEqual(store.rescheduleActions(for: booking), role == .customer ? [.withdraw] : [.accept, .reject])
            try await render(ScrollView { BookingRescheduleSection(booking: booking, store: store).padding() },
                name: "T-378 \(role.rawValue) pending proposal")
            try await render(BookingRescheduleConfirmation(booking: booking, proposal: proposal,
                action: role == .customer ? .withdraw : .accept, onConfirm: { _ in }),
                name: "T-378 \(role.rawValue) exact consent")
        }
    }

    private func render<Content: View>(_ content: Content, name: String) async throws {
        let host = UIHostingController(rootView: content)
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
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(pixels))
        XCTAssertGreaterThan(Set(stride(from: 0, to: CFDataGetLength(pixels), by: 4).map { bytes[$0] }).count, 8)
    }
}
