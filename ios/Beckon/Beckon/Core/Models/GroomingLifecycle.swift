import Foundation

/// Customer journey timing. Finishing by elapsed time never changes fulfillment or verifies service evidence.
/// Keep the eligibility boundary aligned with app_private.grooming_finished_at.
nonisolated enum GroomingLifecycle {
    static func serviceCalendar(_ booking: Booking) -> Calendar? {
        guard let identifier = booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier,
              let zone = TimeZone(identifier: identifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    static func startOfAppointmentDay(_ booking: Booking) -> Date? {
        guard let calendar = serviceCalendar(booking),
              let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart) else { return nil }
        return calendar.startOfDay(for: start)
    }

    static func endOfAppointmentDay(_ booking: Booking) -> Date? {
        guard let calendar = serviceCalendar(booking), let day = startOfAppointmentDay(booking),
              let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
              let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd), end > start,
              let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return max(nextDay, end)
    }

    static func finishedAt(_ booking: Booking) -> Date? {
        if booking.status == .completed {
            return booking.completedAt.flatMap(GroomingRequestDateFormatting.parsedDate)
                ?? booking.fulfillment?.actualEndedAt.flatMap(GroomingRequestDateFormatting.parsedDate)
                ?? GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd)
        }
        guard booking.status == .confirmed, booking.fulfillment?.phase != .outcomeReported else { return nil }
        return endOfAppointmentDay(booking)
    }

    static func isFinished(_ booking: Booking, now: Date = Date()) -> Bool {
        finishedAt(booking).map { $0 <= now } ?? false
    }

    static func needsReviewReminder(_ booking: Booking, now: Date = Date()) -> Bool {
        guard case nil = booking.review, let finished = finishedAt(booking), finished <= now else { return false }
        return now < finished.addingTimeInterval(14 * 24 * 60 * 60)
    }
}
