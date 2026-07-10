import Foundation

nonisolated struct BookingDetailActionPresentation: Equatable, Sendable {
    let canComplete: Bool
    let canCancel: Bool

    init(booking: Booking, role: UserRole) {
        canComplete = booking.canComplete(for: role)
        canCancel = booking.canCancel
    }
}

nonisolated struct GroomerSchedulePresentation: Sendable {
    let days: [GroomerScheduleDay]
    let selectedDayKey: String
    let selectedDate: Date
    let selectedBookings: [Booking]
    let summary: GroomerScheduleSummary?

    init(
        referenceDate: Date,
        bookings: [Booking],
        selectedDayKey: String?,
        calendar: Calendar = .current
    ) {
        let days = GroomerScheduleDay.days(
            around: referenceDate,
            bookings: bookings,
            calendar: calendar
        )
        let resolvedDayKey = Self.resolveSelectedDayKey(
            requestedDayKey: selectedDayKey,
            days: days,
            bookings: bookings,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let selectedBookings = bookings
            .filter { booking in
                !booking.status.isCancellation
                    && GroomerScheduleDateFormatting.dayKey(
                        from: booking.scheduledStart,
                        calendar: calendar
                    ) == resolvedDayKey
            }
            .sortedByScheduledStart(ascending: true)

        self.days = days
        self.selectedDayKey = resolvedDayKey
        self.selectedDate = days.first(where: { $0.id == resolvedDayKey })?.date
            ?? calendar.startOfDay(for: referenceDate)
        self.selectedBookings = selectedBookings
        self.summary = GroomerScheduleSummary(
            bookings: selectedBookings,
            calendar: calendar
        )
    }

    private static func resolveSelectedDayKey(
        requestedDayKey: String?,
        days: [GroomerScheduleDay],
        bookings: [Booking],
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        if let requestedDayKey,
           days.contains(where: { $0.id == requestedDayKey }) {
            return requestedDayKey
        }

        let visibleDayKeys = Set(days.map(\.id))
        let firstVisibleBookingDayKey = (
            bookings
                .filter { !$0.status.isCancellation }
                .sortedByScheduledStart(ascending: true)
                .compactMap {
                    GroomerScheduleDateFormatting.dayKey(
                        from: $0.scheduledStart,
                        calendar: calendar
                    )
                }
        ).first(where: visibleDayKeys.contains)
        if let firstVisibleBookingDayKey {
            return firstVisibleBookingDayKey
        }

        return GroomerScheduleDateFormatting.dayKey(
            from: referenceDate,
            calendar: calendar
        )
    }
}

nonisolated struct GroomerScheduleSummary: Equatable, Sendable {
    let bookingCount: Int
    let nextStartSummary: String
    let totalDurationSummary: String

    init?(bookings: [Booking], calendar: Calendar = .current) {
        guard let firstBooking = bookings.first else { return nil }

        bookingCount = bookings.count
        nextStartSummary = GroomerScheduleDateFormatting.time(
            from: firstBooking.scheduledStart,
            calendar: calendar
        )
        totalDurationSummary = Self.durationSummary(for: bookings)
    }

    private static func durationSummary(for bookings: [Booking]) -> String {
        let minutes = bookings.reduce(0) { total, booking in
            guard
                let start = GroomingRequestDateFormatting.parsedDate(
                    from: booking.scheduledStart
                ),
                let end = GroomingRequestDateFormatting.parsedDate(
                    from: booking.scheduledEnd
                )
            else {
                return total
            }

            return total + max(0, Int(end.timeIntervalSince(start) / 60))
        }

        guard minutes > 0 else { return "Time unavailable" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 { return "\(remainingMinutes)m" }
        if remainingMinutes == 0 { return "\(hours)h" }
        return "\(hours)h \(remainingMinutes)m"
    }
}

nonisolated struct GroomerScheduleAppointmentPresentation:
    Equatable,
    Sendable
{
    let petName: String
    let petDetail: String
    let customerReference: String
    let location: String
    let status: BookingStatus

    init(booking: Booking) {
        petName = booking.requestPetSnapshot?.name ?? "Pet details"
        let breed = booking.requestPetSnapshot?.breed
            ?? booking.requestPetSnapshot?.species
            ?? "Pet"
        petDetail = "\(breed) · \(booking.appointmentServiceTitle)"
        customerReference = booking.participantSummary(for: .groomer)
        location = switch booking.locationMode {
        case .groomerComesToCustomer:
            "Mobile"
        case .customerComesToGroomer:
            "Studio"
        case nil:
            "Location"
        }
        status = booking.status
    }
}

nonisolated struct GroomerScheduleDay: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let isToday: Bool

    static func days(
        around date: Date,
        bookings: [Booking],
        calendar: Calendar = .current
    ) -> [GroomerScheduleDay] {
        let today = calendar.startOfDay(for: date)
        var dates = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: today)
        }
        var seenKeys = Set(
            dates.map {
                GroomerScheduleDateFormatting.dayKey(
                    from: $0,
                    calendar: calendar
                )
            }
        )

        let bookingDates = bookings
            .filter { !$0.status.isCancellation }
            .compactMap {
                GroomingRequestDateFormatting.parsedDate(
                    from: $0.scheduledStart
                )
            }
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 >= today }

        for bookingDate in bookingDates {
            let key = GroomerScheduleDateFormatting.dayKey(
                from: bookingDate,
                calendar: calendar
            )
            if seenKeys.insert(key).inserted {
                dates.append(bookingDate)
            }
        }

        return dates.sorted().map { day in
            GroomerScheduleDay(
                id: GroomerScheduleDateFormatting.dayKey(
                    from: day,
                    calendar: calendar
                ),
                date: day,
                isToday: calendar.isDate(day, inSameDayAs: today)
            )
        }
    }
}

nonisolated enum GroomerScheduleDateFormatting {
    static func dayKey(
        from value: String,
        calendar: Calendar = .current
    ) -> String? {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return nil
        }
        return dayKey(from: date, calendar: calendar)
    }

    static func dayKey(
        from date: Date,
        calendar: Calendar = .current
    ) -> String {
        format(date, pattern: "yyyy-MM-dd", calendar: calendar)
    }

    static func weekday(from date: Date) -> String {
        format(date, pattern: "EEE").uppercased()
    }

    static func dayNumber(from date: Date) -> String {
        format(date, pattern: "d")
    }

    static func month(from date: Date) -> String {
        format(date, pattern: "MMM")
    }

    static func longDayTitle(from date: Date) -> String {
        format(date, pattern: "EEEE, MMM d")
    }

    static func time(
        from value: String,
        calendar: Calendar = .current
    ) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return "Time unavailable"
        }
        return format(date, pattern: "h:mm a", calendar: calendar)
    }

    private static func format(
        _ date: Date,
        pattern: String,
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
