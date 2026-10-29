import Foundation
import Testing
@testable import Beckon

@MainActor
struct GroomingLifecycleTests {
    static func booking(id: UUID = UUID(), requestID: UUID = UUID(), status: BookingStatus = .confirmed, zone: String? = "America/Los_Angeles",
                        start: String = "2000-01-01T18:00:00Z", end: String = "2000-01-01T19:00:00Z") -> Booking {
        Booking(id: id, requestID: requestID, offerID: UUID(), customerID: UUID(), groomerID: UUID(),
            scheduledStart: start, scheduledEnd: end, priceEstimate: 80, status: status,
            cancelledBy: nil, cancelledAt: nil, completedAt: status == .completed ? end : nil,
            completedBy: nil, createdAt: start, updatedAt: end, review: nil, serviceTimeZoneIdentifier: zone)
    }

    @Test func elapsedConfirmedGroomingCanBeReviewedFromHistory() {
        let value = Self.booking()
        #expect(value.canReview(for: .customer))
        #expect(value.status == .confirmed) // Eligibility must not fabricate a completed service.
        #expect(value.completedAt == nil)
    }

    @Test func missingZoneAndClosedOutcomesDoNotInventReviewEligibility() {
        #expect(!Self.booking(zone: nil).canReview(for: .customer))
        #expect(!Self.booking(zone: "Invalid/Zone").canReview(for: .customer))
        #expect(!Self.booking(status: .cancelledByCustomer).canReview(for: .customer))
        #expect(!Self.booking(status: .unfulfilled).canReview(for: .customer))
        #expect(!Self.booking().canReview(for: .groomer))
    }
    @Test func serviceDayBoundaryAndRetentionAreSeparateFromReviewEligibility() throws {
        let booking = Self.booking(start: "2032-06-15T18:00:00Z", end: "2032-06-15T19:00:00Z")
        let finish = try #require(GroomingLifecycle.finishedAt(booking))
        #expect(finish == GroomingRequestDateFormatting.parsedDate(from: "2032-06-16T07:00:00Z"))
        #expect(!booking.canReview(for: .customer, now: finish.addingTimeInterval(-1)))
        #expect(booking.canReview(for: .customer, now: finish))
        #expect(GroomingFeed.isActive(booking, now: finish.addingTimeInterval(14 * 86_400 - 1)))
        let later = finish.addingTimeInterval(14 * 86_400)
        #expect(!GroomingFeed.isActive(booking, now: later))
        #expect(booking.canReview(for: .customer, now: later))
        let history = GroomingFeed.pastEntries(cards: [], bookings: [booking], closedRequests: [], avatar: { _ in nil }, now: later)
        #expect(history.first?.content.status.title == "Finished")
    }

    @Test func daylightSavingAndCrossMidnightAppointmentsUseActualLocalBoundary() throws {
        let spring = Self.booking(start: "2032-03-14T09:00:00Z", end: "2032-03-14T11:00:00Z")
        let autumn = Self.booking(start: "2032-11-07T08:00:00Z", end: "2032-11-07T11:00:00Z")
        #expect(try #require(GroomingLifecycle.endOfAppointmentDay(spring))
            .timeIntervalSince(try #require(GroomingLifecycle.startOfAppointmentDay(spring))) == 23 * 3600)
        #expect(try #require(GroomingLifecycle.endOfAppointmentDay(autumn))
            .timeIntervalSince(try #require(GroomingLifecycle.startOfAppointmentDay(autumn))) == 25 * 3600)
        let overnight = Self.booking(start: "2032-06-16T06:00:00Z", end: "2032-06-16T09:00:00Z")
        #expect(GroomingLifecycle.finishedAt(overnight) == GroomingRequestDateFormatting.parsedDate(from: overnight.scheduledEnd))
    }

    @Test func currentBookingReplacesStaleHandoffAndAppearsOnlyInHistory() throws {
        let request = CustomerSandboxFixtures.request()
        let stale = Self.booking(requestID: request.id, start: "2032-06-15T18:00:00Z", end: "2032-06-15T19:00:00Z")
        let current = Self.booking(id: stale.id, requestID: request.id, status: .cancelledByCustomer)
        let cards = [CustomerRequestActionCardItem(request: request,
            handoff: .init(request: request, booking: stale))]
        #expect(GroomingFeed.activeEntries(cards: cards, bookings: [current], avatar: { _ in nil }).isEmpty)
        let history = GroomingFeed.pastEntries(cards: cards, bookings: [current], closedRequests: [request], avatar: { _ in nil })
        #expect(history.count == 1)
        #expect(history.first?.id == current.id)
        #expect(GroomingFeed.activeEntries(cards: [.init(request: request, handoff: nil)],
            bookings: [current], avatar: { _ in nil }).isEmpty)
    }

    @Test func elapsedHandoffDoesNotDisappearFromBothLists() {
        let request = CustomerSandboxFixtures.request()
        let booking = Self.booking(requestID: request.id)
        let cards = [CustomerRequestActionCardItem(request: request, handoff: .init(request: request, booking: booking))]
        #expect(GroomingFeed.activeEntries(cards: cards, bookings: [], avatar: { _ in nil }).isEmpty)
        let history = GroomingFeed.pastEntries(cards: cards, bookings: [], closedRequests: [], avatar: { _ in nil })
        #expect(history.count == 1)
        #expect(history.first?.content.status.title == "Finished")
        #expect(booking.status == .confirmed) // The customer journey label is not a fulfillment mutation.
    }

    @Test func reportedOutcomeStaysActionableAndReviewedServiceLeavesActiveFeed() {
        let old = Date(timeIntervalSince1970: 946_684_800)
        let disputed = CustomerSandboxFixtures.booking(state: .outcomeReported, now: old)
        #expect(!disputed.canReview(for: .customer))
        #expect(GroomingFeed.isActive(disputed, now: .now))
        let reviewed = CustomerSandboxFixtures.booking(state: .reviewed)
        #expect(!reviewed.canReview(for: .customer))
        #expect(!GroomingFeed.isActive(reviewed, now: .now))
    }

}
