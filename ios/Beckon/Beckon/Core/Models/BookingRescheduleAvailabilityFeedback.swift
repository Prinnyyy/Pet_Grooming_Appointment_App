import Foundation

/// A schedule explanation, not a promise that a slot is free. Booking conflicts remain server-checked.
enum BookingRescheduleAvailabilityFeedback {
    static let prefix = "Groomer hours"

    static func isAvailabilityMessage(_ message: String) -> Bool {
        message == BookingRepositoryError.outsideAvailabilityMessage || message.hasPrefix(prefix + " · ")
    }

    static func message(start: Date, duration: TimeInterval, zone: String,
                        windows: [GroomerAvailabilityWindow], timeOff: [GroomerTimeOffWindow]) -> String? {
        guard let timezone = TimeZone(identifier: zone), duration > 0, duration <= 7 * 86400,
              windows.allSatisfy({ $0.timezone == zone }) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let label = DateFormatter()
        label.locale = Locale(identifier: "en_US_POSIX"); label.timeZone = timezone
        label.dateFormat = "EEE, MMM d"
        let key = DateFormatter()
        key.locale = Locale(identifier: "en_US_POSIX"); key.timeZone = timezone
        key.dateFormat = "yyyy-MM-dd"
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: start.addingTimeInterval(duration - 0.001))
        var lines: [String] = []
        while day <= last {
            let date = key.string(from: day)
            let weekday = (calendar.component(.weekday, from: day) + 5) % 7 + 1
            let hours = windows.filter { $0.weekday.rawValue == weekday && $0.isEnabled }
                .sorted { $0.startMinutes < $1.startMinutes }
            let value: String
            if timeOff.contains(where: { $0.startDate <= date && date <= $0.endDate }) {
                value = "Unavailable (time off)"
            } else if hours.isEmpty {
                value = "Closed"
            } else {
                value = hours.map {
                    GroomerAvailabilityWindow.displayTime(fromMinutes: $0.startMinutes % 1440)
                    + "–" + GroomerAvailabilityWindow.displayTime(fromMinutes: $0.endMinutes % 1440)
                }.joined(separator: ", ")
            }
            lines.append("\(label.string(from: day)): \(value)")
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = next
        }
        return prefix + " · " + lines.joined(separator: "; ") + ". Please choose another time."
    }
}
