import Foundation
import Testing
@testable import Beckon

@MainActor
struct GroomerAgendaTests {
    @Test func clockMovesAppointmentWithoutReload() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let booking = BookingsStoreTests.booking(scheduledStart: GroomingRequestDateFormatting.serverString(from: start),
            scheduledEnd: GroomingRequestDateFormatting.serverString(from: start.addingTimeInterval(3600)))
        let slot = try #require(GroomerScheduleSlot(booking))
        #expect(slot.phase(at: start.addingTimeInterval(-1)) == .upcoming)
        #expect(slot.phase(at: start) == .due)
        #expect(slot.phase(at: start.addingTimeInterval(3600)) == .needsClosing)
        let plan = GroomerSchedulePlan(slots: [slot], now: start.addingTimeInterval(3600), isToday: true)
        #expect(plan.focus == nil)
        #expect(plan.behind.map(\.id) == [booking.id])
    }

    @Test func serviceGapUsesAppointmentOnly() throws {
        let first = try #require(GroomerScheduleSlot(BookingsStoreTests.booking(
            scheduledStart: "2026-11-02T09:00:00Z", scheduledEnd: "2026-11-02T10:00:00Z")))
        for (start, expected) in [("2026-11-02T10:00:00Z", GroomerFreeTime.backToBack),
                                  ("2026-11-02T10:30:00Z", .free(minutes: 30)),
                                  ("2026-11-02T09:59:59Z", .overlap)] {
            let next = try #require(GroomerScheduleSlot(BookingsStoreTests.booking(
                scheduledStart: start, scheduledEnd: "2026-11-02T11:00:00Z")))
            #expect(GroomerFreeTime(from: first, to: next) == expected)
        }
    }

    @Test func displayedWeekDoesNotGrowForDistantBookings() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let today = try #require(GroomingRequestDateFormatting.parsedDate(from: "2026-11-01T08:00:00Z"))
        let days = (0..<7).map { index in
            let date = calendar.date(byAdding: .day, value: index, to: today)!
            return GroomerScheduleDay(id: GroomerScheduleDateFormatting.dayKey(from: date, calendar: calendar),
                date: date, isToday: index == 0)
        }
        let distant = BookingsStoreTests.booking(scheduledStart: "2027-03-10T09:00:00Z")
        let presentation = GroomerSchedulePresentation(referenceDate: today, bookings: [distant],
            selectedDayKey: days[0].id, scopedBookings: [], calendar: calendar, displayedDays: days)
        #expect(presentation.days.count == 7)
        #expect(presentation.selectedBookings.isEmpty)
        #expect(calendar.date(byAdding: .day, value: 7, to: today)!.timeIntervalSince(today) == 7 * 86400 + 3600)
    }

    @Test func validatedHoursRetainedAndForeignHoursRejected() async {
        let owner = UUID()
        let profiles = GroomerProfileRepositoryFake()
        let windows = GroomerAvailabilityWeekday.allCases.map {
            GroomerAvailabilityWindow(id: UUID(), groomerID: owner, weekday: $0,
                startMinutes: 480, endMinutes: 1080, isEnabled: true, timezone: "America/New_York")
        }
        profiles.availabilityResult = .success(windows)
        let store = BookingsStore(participantID: owner, role: .groomer, repository: BookingRepositoryFake(),
            groomerProfileRepository: profiles, appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        await store.load()
        #expect(store.scheduleAvailabilityWindows.count == 7)
        profiles.availabilityResult = .success(windows.dropLast().map { $0 })
        await store.load()
        #expect(store.scheduleCalendar == nil)
        #expect(store.scheduleAvailabilityWindows.isEmpty)
    }
}
