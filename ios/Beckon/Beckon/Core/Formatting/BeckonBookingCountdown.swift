import Foundation

/// Calendar-day countdown and tile parts for a booking, evaluated in the booking's service time zone.
nonisolated enum BeckonBookingCountdown {
    private static func calendar(for booking: Booking) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        let identifier = booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier
        if let identifier, let zone = TimeZone(identifier: identifier) { calendar.timeZone = zone }
        return calendar
    }

    private static func start(of booking: Booking) -> Date? {
        GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart)
    }

    /// "Today", "Tomorrow" or "In N days". Nil when the start is unparseable or already on a past day.
    static func label(for booking: Booking, now: Date = Date()) -> String? {
        guard let start = start(of: booking) else { return nil }
        let calendar = calendar(for: booking)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: start)).day ?? 0
        switch days {
        case ..<0: return nil
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    /// Upper-case abbreviated month and day of month, such as ("OCT", "24").
    static func dateParts(for booking: Booking) -> (month: String, day: String)? {
        guard let start = start(of: booking) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar(for: booking).timeZone
        formatter.dateFormat = "MMM"
        let month = formatter.string(from: start).uppercased()
        formatter.dateFormat = "d"
        return (month, formatter.string(from: start))
    }
}
