import Foundation

nonisolated struct BeckonDateTimePresentation: Equatable, Sendable {
    let text: String
    let accessibilityLabel: String
    var timeZoneNotice: String? = nil

    var summary: String { [text, timeZoneNotice].compactMap { $0 }.joined(separator: "\n") }
}

nonisolated enum BeckonDateTimeFormatter {
    static func interval(
        from start: String, to end: String, serviceTimeZoneIdentifier: String?,
        deviceTimeZone: TimeZone = .current, referenceDate: Date = Date()
    ) -> BeckonDateTimePresentation {
        guard let calendar = serviceCalendar(serviceTimeZoneIdentifier) else { return unknownZone }
        guard let start = GroomingRequestDateFormatting.parsedDate(from: start),
              let end = GroomingRequestDateFormatting.parsedDate(from: end), end > start else { return unavailable }
        return range(from: start, to: end, calendar: calendar,
            deviceTimeZone: deviceTimeZone, referenceDate: referenceDate)
    }

    static func interval(
        from start: Date, to end: Date, serviceTimeZoneIdentifier: String?,
        deviceTimeZone: TimeZone = .current, referenceDate: Date = Date()
    ) -> BeckonDateTimePresentation {
        guard let calendar = serviceCalendar(serviceTimeZoneIdentifier) else { return unknownZone }
        guard end > start else { return unavailable }
        return range(from: start, to: end, calendar: calendar,
            deviceTimeZone: deviceTimeZone, referenceDate: referenceDate)
    }

    static func instant(
        from value: String, serviceTimeZoneIdentifier: String?,
        deviceTimeZone: TimeZone = .current, referenceDate: Date = Date()
    ) -> BeckonDateTimePresentation {
        guard let calendar = serviceCalendar(serviceTimeZoneIdentifier) else { return unknownZone }
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else { return unavailable }
        let formatter = formatter(calendar: calendar)
        let day = day(date, formatter: formatter, includeYear: calendar.component(.year, from: date) != calendar.component(.year, from: referenceDate))
        let time = format(date, "h:mm a", formatter)
        let suffix = calendar.timeZone != deviceTimeZone || offsetChangesNear(date, zone: calendar.timeZone)
            ? " \(format(date, "z", formatter))" : ""
        let text = "\(day) · \(time)\(suffix)"
        return .init(text: text, accessibilityLabel: "\(text), \(calendar.timeZone.identifier)")
    }

    static func localInstant(from value: String, deviceTimeZone: TimeZone = .current) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else { return unavailable.text }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = deviceTimeZone
        return format(date, "MMM d, yyyy · h:mm a", formatter(calendar: calendar))
    }

    static func zoneLabel(_ zone: TimeZone, at date: Date) -> String {
        zone.abbreviation(for: date) ?? zone.localizedName(for: .shortStandard, locale: Locale(identifier: "en_US")) ?? "Local time"
    }

    private static var unavailable: BeckonDateTimePresentation {
        .init(text: "Time unavailable", accessibilityLabel: "Time unavailable")
    }

    private static var unknownZone: BeckonDateTimePresentation {
        .init(text: "Time unavailable", accessibilityLabel: "Time unavailable. Time zone not confirmed",
              timeZoneNotice: "Time zone not confirmed")
    }

    private static func serviceCalendar(_ identifier: String?) -> Calendar? {
        identifier.flatMap { try? GroomingServiceTiming.locationCalendar($0) }
    }

    private static func range(
        from start: Date, to end: Date, calendar: Calendar,
        deviceTimeZone: TimeZone, referenceDate: Date
    ) -> BeckonDateTimePresentation {
        let formatter = formatter(calendar: calendar)
        let zone = calendar.timeZone
        let includeYear = calendar.component(.year, from: start) != calendar.component(.year, from: end)
            || calendar.component(.year, from: start) != calendar.component(.year, from: referenceDate)
        let startDay = day(start, formatter: formatter, includeYear: includeYear)
        let endDay = day(end, formatter: formatter, includeYear: includeYear)
        let startTime = format(start, "h:mm a", formatter)
        let endTime = format(end, "h:mm a", formatter)
        let changesOffset = zone.secondsFromGMT(for: start) != zone.secondsFromGMT(for: end)
        let needsZone = zone != deviceTimeZone || changesOffset
            || offsetChangesNear(start, zone: zone) || offsetChangesNear(end, zone: zone)
        let startZone = needsZone ? " \(format(start, "z", formatter))" : ""
        let endZone = needsZone ? " \(format(end, "z", formatter))" : ""
        let text: String
        if !calendar.isDate(start, inSameDayAs: end) {
            text = "\(startDay) · \(startTime)\(startZone) – \(endDay) · \(endTime)\(endZone)"
        } else if changesOffset {
            // Repeated wall-clock hours must retain both offsets, even on a local device.
            text = "\(startDay) · \(startTime)\(startZone)–\(endTime)\(endZone)"
        } else {
            let sharesMeridiem = format(start, "a", formatter) == format(end, "a", formatter)
            let compactStart = sharesMeridiem ? format(start, "h:mm", formatter) : startTime
            text = "\(startDay) · \(compactStart)–\(endTime)\(endZone)"
        }
        return .init(text: text, accessibilityLabel: "\(startDay), \(startTime)\(startZone) to \(endDay), \(endTime)\(endZone), \(zone.identifier)")
    }

    private static func offsetChangesNear(_ date: Date, zone: TimeZone) -> Bool {
        let offset = zone.secondsFromGMT(for: date)
        return zone.secondsFromGMT(for: date.addingTimeInterval(-3600)) != offset
            || zone.secondsFromGMT(for: date.addingTimeInterval(3600)) != offset
    }

    private static func formatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return formatter
    }

    private static func day(_ date: Date, formatter: DateFormatter, includeYear: Bool) -> String {
        format(date, includeYear ? "EEE, MMM d, yyyy" : "EEE, MMM d", formatter)
    }

    private static func format(_ date: Date, _ pattern: String, _ formatter: DateFormatter) -> String {
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
