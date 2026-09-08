import Foundation
import Testing
@testable import Beckon

struct GroomingServiceTimingTests {
    @Test
    func scheduleDateStripUsesLocalMonthAndDayAtUTCBoundary() throws {
        let calendar = try GroomingServiceTiming.locationCalendar("America/Los_Angeles")
        let date = try #require(GroomingRequestDateFormatting.parsedDate(from: "2027-01-01T01:00:00Z"))
        #expect(GroomerScheduleDateFormatting.weekday(from: date, calendar: calendar) == "THU")
        #expect(GroomerScheduleDateFormatting.dayNumber(from: date, calendar: calendar) == "31")
        #expect(GroomerScheduleDateFormatting.month(from: date, calendar: calendar) == "Dec")
    }

    @Test
    func scheduleOffsetsDistinguishRepeatedHours() throws {
        let calendar = try GroomingServiceTiming.locationCalendar("America/New_York")
        #expect(GroomerScheduleDateFormatting.offset(from: "2026-11-01T05:30:00Z", calendar: calendar) == "-04:00")
        #expect(GroomerScheduleDateFormatting.offset(from: "2026-11-01T06:30:00Z", calendar: calendar) == "-05:00")
    }

    @Test
    func scheduleLabelsUseSameExplicitCalendarAcrossMidnight() throws {
        let calendar = try GroomingServiceTiming.locationCalendar("America/Los_Angeles")
        let value = "2026-11-02T01:30:00Z"
        let date = try #require(GroomingRequestDateFormatting.parsedDate(from: value))
        #expect(GroomerScheduleDateFormatting.time(from: value, calendar: calendar) == "5:30 PM")
        #expect(GroomerScheduleDateFormatting.longDayTitle(from: date, calendar: calendar) == "Sunday, Nov 1")
    }

    @Test
    func repeatedQuoteTimesDisplayDistinctOffsets() {
        let first = GroomingRequestDateFormatting.displayString(from: "2026-11-01T05:30:00Z",
            serviceTimeZoneIdentifier: "America/New_York")
        let last = GroomingRequestDateFormatting.displayString(from: "2026-11-01T06:30:00Z",
            serviceTimeZoneIdentifier: "America/New_York")
        #expect(first != last)
        #expect(first.contains("-04"))
        #expect(last.contains("-05"))
    }

    @Test
    func quoteDisplayDoesNotInventLegacyServiceZone() {
        let instant = "2026-11-01T05:30:00Z"
        for identifier in [nil, "Invalid/Zone"] as [String?] {
            #expect(GroomingRequestDateFormatting.displayString(from: instant,
                serviceTimeZoneIdentifier: identifier) == "\(instant) (service time zone unconfirmed)")
        }
        let known = GroomingRequestDateFormatting.displayString(from: instant,
            serviceTimeZoneIdentifier: "America/New_York")
        #expect(known.hasSuffix("(America/New_York)"))
        #expect(!known.contains("unconfirmed"))
    }

    @Test
    func wallInputPreservesMissingAndRepeatedClockTimes() throws {
        let parser = ISO8601DateFormatter()
        let missing = try #require(parser.date(from: "2026-03-08T02:30:00Z"))
        #expect(try GroomingServiceTiming.resolveWallInput(missing,
            timeZoneIdentifier: "America/New_York") == .nonexistent)
        let first = try #require(parser.date(from: "2026-11-01T05:30:00Z"))
        let last = try #require(parser.date(from: "2026-11-01T06:30:00Z"))
        let input = try GroomingServiceTiming.wallInput(for: first, timeZoneIdentifier: "America/New_York")
        #expect(input == parser.date(from: "2026-11-01T01:30:00Z"))
        #expect(try GroomingServiceTiming.wallInput(for: last, timeZoneIdentifier: "America/New_York") == input)
        #expect(try GroomingServiceTiming.resolveWallInput(input,
            timeZoneIdentifier: "America/New_York") == .ambiguous(first: first, last: last))
    }

    @Test @MainActor
    func bookingRowsRetainOriginalAllocationRatherThanCurrentSettings() throws {
        let base: [String: Any] = [
            "id": UUID().uuidString, "request_id": UUID().uuidString, "offer_id": UUID().uuidString,
            "customer_id": UUID().uuidString, "groomer_id": UUID().uuidString,
            "scheduled_start": "2026-11-02T04:00:00Z", "scheduled_end": "2026-11-02T05:00:00Z",
            "price_estimate": 100, "status": "confirmed",
            "created_at": "2026-11-01T00:00:00Z", "updated_at": "2026-11-01T00:00:00Z"
        ]
        var timed = base
        timed["service_time_zone_identifier"] = "America/Los_Angeles"
        timed["schedule_time_zone_identifier"] = "America/New_York"
        timed["occupied_start"] = "2026-11-02T03:45:00Z"
        timed["occupied_end"] = "2026-11-02T05:10:00Z"
        timed["applied_timing_buffers"] = ["preparation_minutes": 15, "cleanup_minutes": 10,
            "inbound_travel_minutes": 0, "outbound_travel_minutes": 0]
        let unknown = try JSONDecoder().decode(SupabaseBookingRow.self,
            from: JSONSerialization.data(withJSONObject: base)).booking
        let known = try JSONDecoder().decode(SupabaseBookingRow.self,
            from: JSONSerialization.data(withJSONObject: timed)).booking
        #expect(known != unknown)
        #expect(unknown.appliedTimingBuffers == nil)
        #expect(unknown.serviceTimeZoneIdentifier == nil)
        #expect(unknown.scheduleTimeZoneIdentifier == nil)
        #expect(unknown.occupiedStart == nil)
        #expect(unknown.occupiedEnd == nil)
        #expect(known.serviceTimeZoneIdentifier == "America/Los_Angeles")
        #expect(known.scheduleTimeZoneIdentifier == "America/New_York")
        #expect(known.occupiedStart == "2026-11-02T03:45:00Z")
        #expect(known.occupiedEnd == "2026-11-02T05:10:00Z")
        let buffers = try GroomingTimingBuffers(preparation: 15, cleanup: 10, inboundTravel: 0, outboundTravel: 0)
        #expect(known.appliedTimingBuffers == buffers)
        for status: BookingStatus in [.cancelledByCustomer, .completed] {
            let replaced = known.replacing(status: status, cancelledBy: nil, cancelledAt: nil)
            #expect(replaced.appliedTimingBuffers == buffers)
            #expect(replaced.serviceTimeZoneIdentifier == known.serviceTimeZoneIdentifier)
            #expect(replaced.scheduleTimeZoneIdentifier == known.scheduleTimeZoneIdentifier)
            #expect(replaced.occupiedStart == known.occupiedStart)
            #expect(replaced.occupiedEnd == known.occupiedEnd)
            #expect(replaced.scheduledStart == known.scheduledStart)
            #expect(replaced.scheduledEnd == known.scheduledEnd)
        }
    }

    @Test @MainActor
    func offerRowsDoNotDiscardAuthoritativeTimingEvidence() throws {
        let base: [String: Any] = [
            "id": UUID().uuidString, "request_id": UUID().uuidString, "match_id": UUID().uuidString,
            "customer_id": UUID().uuidString, "groomer_id": UUID().uuidString,
            "proposed_start": "2026-11-02T04:00:00Z", "proposed_end": "2026-11-02T05:00:00Z",
            "price_estimate": 100, "status": "pending", "expires_at": "2026-11-03T00:00:00Z"
        ]
        var timed = base
        timed["service_time_zone_identifier"] = "America/Los_Angeles"
        timed["schedule_time_zone_identifier"] = "America/New_York"
        timed["occupied_start"] = "2026-11-02T03:45:00Z"
        timed["occupied_end"] = "2026-11-02T05:10:00Z"
        timed["applied_timing_buffers"] = ["preparation_minutes": 15, "cleanup_minutes": 10,
            "inbound_travel_minutes": 0, "outbound_travel_minutes": 0]
        let unknownData = try JSONSerialization.data(withJSONObject: base)
        let timedData = try JSONSerialization.data(withJSONObject: timed)
        let customer = try JSONDecoder().decode(CustomerOfferRow.self, from: timedData).offer
        let groomer = try JSONDecoder().decode(SupabaseGroomerOfferRow.self, from: timedData).offer
        #expect(customer == groomer)
        #expect(customer.hasTimingSnapshot)
        #expect(groomer.hasTimingSnapshot)
        #expect(!customer.requiresTimingUpdate)
        #expect(customer.timingSnapshotLoaded)
        let unknown = try JSONDecoder().decode(CustomerOfferRow.self, from: unknownData).offer
        #expect(customer != unknown)
        #expect(!unknown.hasTimingSnapshot)
        #expect(unknown.requiresTimingUpdate)
        var unread = unknown
        unread.timingSnapshotLoaded = false
        #expect(!unread.requiresTimingUpdate)
        var invalidSnapshot = customer
        invalidSnapshot.serviceTimeZoneIdentifier = "Invalid/Zone"
        #expect(invalidSnapshot.requiresTimingUpdate)
        invalidSnapshot = customer
        invalidSnapshot.occupiedEnd = customer.proposedStart
        #expect(invalidSnapshot.requiresTimingUpdate)
        invalidSnapshot = customer
        invalidSnapshot.occupiedStart = "not-a-timestamp"
        #expect(invalidSnapshot.requiresTimingUpdate)
        invalidSnapshot = customer
        invalidSnapshot.appliedTimingBuffers = nil
        #expect(invalidSnapshot.requiresTimingUpdate)
        #expect(try unknown == JSONDecoder().decode(SupabaseGroomerOfferRow.self, from: unknownData).offer)
        #expect(unknown.appliedTimingBuffers == nil)
        #expect(unknown.serviceTimeZoneIdentifier == nil)
        #expect(unknown.scheduleTimeZoneIdentifier == nil)
        #expect(unknown.occupiedStart == nil)
        #expect(unknown.occupiedEnd == nil)
        #expect(customer.serviceTimeZoneIdentifier == "America/Los_Angeles")
        #expect(customer.scheduleTimeZoneIdentifier == "America/New_York")
        #expect(customer.occupiedStart == "2026-11-02T03:45:00Z")
        #expect(customer.occupiedEnd == "2026-11-02T05:10:00Z")
        let expectedBuffers = try GroomingTimingBuffers(preparation: 15, cleanup: 10,
            inboundTravel: 0, outboundTravel: 0)
        #expect(customer.appliedTimingBuffers == expectedBuffers)
        let withdrawn = customer.replacing(status: .withdrawnByGroomer, withdrawnAt: "2026-11-01T00:00:00Z")
        #expect(withdrawn.timingSnapshotLoaded)
        #expect(withdrawn.appliedTimingBuffers == customer.appliedTimingBuffers)
        #expect(withdrawn.serviceTimeZoneIdentifier == customer.serviceTimeZoneIdentifier)
        #expect(withdrawn.scheduleTimeZoneIdentifier == customer.scheduleTimeZoneIdentifier)
        #expect(withdrawn.occupiedStart == customer.occupiedStart)
        #expect(withdrawn.occupiedEnd == customer.occupiedEnd)
        timed["applied_timing_buffers"] = ["preparation_minutes": 121, "cleanup_minutes": 10,
            "inbound_travel_minutes": 0, "outbound_travel_minutes": 0]
        let invalid = try JSONSerialization.data(withJSONObject: timed)
        #expect(throws: GroomingTimingError.invalidBuffers) {
            try JSONDecoder().decode(CustomerOfferRow.self, from: invalid)
        }
        #expect(throws: GroomingTimingError.invalidBuffers) {
            try JSONDecoder().decode(SupabaseGroomerOfferRow.self, from: invalid)
        }
    }

    @Test
    func bufferWireRoundTripPreservesExplicitZeroAndRejectsInvalidInput() throws {
        let buffers = try GroomingTimingBuffers(preparation: 0, cleanup: 15, inboundTravel: 30, outboundTravel: 0)
        let data = try JSONEncoder().encode(buffers)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Int])
        #expect(json == ["preparation_minutes": 0, "cleanup_minutes": 15,
            "inbound_travel_minutes": 30, "outbound_travel_minutes": 0])
        #expect(try JSONDecoder().decode(GroomingTimingBuffers.self, from: data) == buffers)
        let invalid = Data(#"{"preparation_minutes":121,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0}"#.utf8)
        #expect(throws: GroomingTimingError.invalidBuffers) {
            try JSONDecoder().decode(GroomingTimingBuffers.self, from: invalid)
        }
        let missing = Data(#"{"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0}"#.utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(GroomingTimingBuffers.self, from: missing)
        }
    }

    private func date(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }

    @Test
    func buffersAreSeparateFromServiceAndCustomerTravel() throws {
        let start = try date("2026-09-07T18:00:00Z")
        let buffers = try GroomingTimingBuffers(preparation: 15, cleanup: 10, inboundTravel: 30, outboundTravel: 20)
        let mobile = try GroomingServiceTiming.allocation(start: start, durationMinutes: 60,
            buffers: buffers, locationMode: .groomerComesToCustomer)
        #expect(mobile.service.start == start)
        #expect(mobile.service.end == start.addingTimeInterval(3600))
        #expect(mobile.occupied.start == start.addingTimeInterval(-2700))
        #expect(mobile.occupied.end == start.addingTimeInterval(5400))
        let atGroomer = try GroomingServiceTiming.allocation(start: start, durationMinutes: 60,
            buffers: buffers, locationMode: .customerComesToGroomer)
        #expect(atGroomer.occupied.start == start.addingTimeInterval(-900))
        #expect(atGroomer.occupied.end == start.addingTimeInterval(4200))
    }

    @Test
    func adjacentHalfOpenIntervalsDoNotOverlap() throws {
        let start = try date("2026-09-07T18:00:00Z")
        let first = try GroomingTimeSpan(start: start, end: start.addingTimeInterval(3600))
        let adjacent = try GroomingTimeSpan(start: first.end, end: first.end.addingTimeInterval(3600))
        let conflicting = try GroomingTimeSpan(start: first.end.addingTimeInterval(-1), end: adjacent.end)
        #expect(!first.overlaps(adjacent))
        #expect(first.overlaps(conflicting))
    }

    @Test(arguments: [-1, 121])
    func preparationBoundsRejectInvalidValues(value: Int) {
        #expect(throws: GroomingTimingError.invalidBuffers) {
            try GroomingTimingBuffers(preparation: value, cleanup: 0, inboundTravel: 0, outboundTravel: 0)
        }
    }

    @Test(arguments: [-1, 181])
    func travelBoundsRejectInvalidValues(value: Int) {
        #expect(throws: GroomingTimingError.invalidBuffers) {
            try GroomingTimingBuffers(preparation: 0, cleanup: 0, inboundTravel: value, outboundTravel: 0)
        }
    }

    @Test(arguments: [14, 721])
    func durationBoundsAreShared(value: Int) {
        #expect(GroomingServiceTiming.serviceEnd(start: Date(), durationMinutes: value) == nil)
    }

    @Test
    func springGapIsNotSilentlyShifted() throws {
        let result = try GroomingServiceTiming.resolveWallTime(year: 2026, month: 3, day: 8,
            hour: 2, minute: 30, timeZoneIdentifier: "America/Los_Angeles")
        #expect(result == .nonexistent)
    }

    @Test
    func fallRepeatedTimeRequiresAnOccurrenceChoice() throws {
        let result = try GroomingServiceTiming.resolveWallTime(year: 2026, month: 11, day: 1,
            hour: 1, minute: 30, timeZoneIdentifier: "America/Los_Angeles")
        #expect(result == .ambiguous(first: try date("2026-11-01T08:30:00Z"),
            last: try date("2026-11-01T09:30:00Z")))
    }

    @Test
    func ordinaryWallTimeUsesTheDeclaredLocationZone() throws {
        let result = try GroomingServiceTiming.resolveWallTime(year: 2026, month: 9, day: 7,
            hour: 10, minute: 0, timeZoneIdentifier: "America/Los_Angeles")
        #expect(result == .unique(try date("2026-09-07T17:00:00Z")))
    }

    @Test
    func unknownZoneCannotFallBackToDeviceTime() {
        #expect(throws: GroomingTimingError.invalidTimeZone) {
            try GroomingServiceTiming.resolveWallTime(year: 2026, month: 9, day: 7,
                hour: 10, minute: 0, timeZoneIdentifier: "Not/A_Zone")
        }
    }

    @Test
    func noticeDaysAreLocalCalendarDaysAcrossSpringTransition() throws {
        let now = try date("2026-03-08T07:30:00Z")
        let earliest = try GroomingServiceTiming.earliestStart(now: now, noticeDays: 1,
            scheduleTimeZone: "America/Los_Angeles")
        #expect(earliest == (try date("2026-03-08T08:00:00Z")))
        let twoDays = try GroomingServiceTiming.earliestStart(now: now, noticeDays: 2,
            scheduleTimeZone: "America/Los_Angeles")
        #expect(twoDays == (try date("2026-03-09T07:00:00Z")))
    }

    @Test
    func sameDayNoticeStillRequiresFiveMinutes() throws {
        let now = try date("2026-09-07T17:00:00Z")
        #expect(try GroomingServiceTiming.earliestStart(now: now, noticeDays: 0,
            scheduleTimeZone: "America/Los_Angeles") == now.addingTimeInterval(300))
    }
}
