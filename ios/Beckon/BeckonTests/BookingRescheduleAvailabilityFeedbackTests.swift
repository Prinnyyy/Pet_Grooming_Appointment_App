import Foundation
import Testing
@testable import Beckon

@MainActor
struct BookingRescheduleAvailabilityFeedbackTests {
    let groomerID = UUID()
    let zone = "America/Los_Angeles"

    private func window(_ day: GroomerAvailabilityWeekday, start: Int, end: Int) -> GroomerAvailabilityWindow {
        GroomerAvailabilityWindow(id: UUID(), groomerID: groomerID, weekday: day,
            startMinutes: start, endMinutes: end, isEnabled: true, timezone: zone)
    }

    @Test func selectedDateUsesGroomerHoursAndClosedDays() throws {
        let friday = try #require(ISO8601DateFormatter().date(from: "2026-11-06T18:00:00Z"))
        let windows = [window(.friday, start: 540, end: 1020)]
        let open = try #require(BookingRescheduleAvailabilityFeedback.message(start: friday,
            duration: 3600, zone: zone, windows: windows, timeOff: []))
        #expect(open.contains("Fri, Nov 6: 9:00 AM–5:00 PM"))
        #expect(BookingRescheduleAvailabilityFeedback.isAvailabilityMessage(open))
        let closed = try #require(BookingRescheduleAvailabilityFeedback.message(start: friday.addingTimeInterval(86400),
            duration: 3600, zone: zone, windows: windows, timeOff: []))
        #expect(closed.contains("Sat, Nov 7: Closed"))
    }

    @Test func timeOffOverridesHoursWithoutDisclosingPrivateTitle() throws {
        let start = try #require(ISO8601DateFormatter().date(from: "2026-11-06T18:00:00Z"))
        let off = GroomerTimeOffWindow(id: UUID(), groomerID: groomerID, title: "Private appointment",
            startDate: "2026-11-06", endDate: "2026-11-06")
        let text = try #require(BookingRescheduleAvailabilityFeedback.message(start: start, duration: 3600,
            zone: zone, windows: [window(.friday, start: 540, end: 1020)], timeOff: [off]))
        #expect(text.contains("Unavailable (time off)"))
        #expect(!text.contains(off.title))
        #expect(!text.contains("9:00 AM"))
    }

    @Test func overnightShowsBothDaysButMidnightEndDoesNotIncludeNextDay() throws {
        let start = try #require(ISO8601DateFormatter().date(from: "2026-11-07T07:30:00Z"))
        let windows = [window(.friday, start: 540, end: 1020), window(.saturday, start: 600, end: 840)]
        let cross = try #require(BookingRescheduleAvailabilityFeedback.message(start: start, duration: 3600,
            zone: zone, windows: windows, timeOff: []))
        #expect(cross.contains("Fri, Nov 6:"))
        #expect(cross.contains("Sat, Nov 7: 10:00 AM–2:00 PM"))
        let midnight = try #require(BookingRescheduleAvailabilityFeedback.message(start: start, duration: 1800,
            zone: zone, windows: windows, timeOff: []))
        #expect(!midnight.contains("Nov 7"))
    }
}
