import Foundation

nonisolated enum GroomingTimingError: Error, Equatable {
    case invalidDuration
    case invalidBuffers
    case invalidWindow
    case invalidTimeZone
    case invalidNotice
}

nonisolated struct GroomingTimeSpan: Equatable, Sendable {
    let start: Date
    let end: Date

    init(start: Date, end: Date) throws {
        guard start.timeIntervalSinceReferenceDate.isFinite,
              end.timeIntervalSinceReferenceDate.isFinite, start < end else {
            throw GroomingTimingError.invalidWindow
        }
        self.start = start
        self.end = end
    }

    func overlaps(_ other: Self) -> Bool {
        start < other.end && other.start < end
    }

    func contains(_ other: Self) -> Bool {
        start <= other.start && other.end <= end
    }
}

nonisolated struct GroomingTimingBuffers: Hashable, Codable, Sendable {
    let preparation: Int
    let cleanup: Int
    let inboundTravel: Int
    let outboundTravel: Int

    init(preparation: Int, cleanup: Int, inboundTravel: Int, outboundTravel: Int) throws {
        guard (0...120).contains(preparation), (0...120).contains(cleanup),
              (0...180).contains(inboundTravel), (0...180).contains(outboundTravel) else {
            throw GroomingTimingError.invalidBuffers
        }
        self.preparation = preparation
        self.cleanup = cleanup
        self.inboundTravel = inboundTravel
        self.outboundTravel = outboundTravel
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(preparation: values.decode(Int.self, forKey: .preparation),
            cleanup: values.decode(Int.self, forKey: .cleanup),
            inboundTravel: values.decode(Int.self, forKey: .inboundTravel),
            outboundTravel: values.decode(Int.self, forKey: .outboundTravel))
    }

    private enum CodingKeys: String, CodingKey {
        case preparation = "preparation_minutes"
        case cleanup = "cleanup_minutes"
        case inboundTravel = "inbound_travel_minutes"
        case outboundTravel = "outbound_travel_minutes"
    }
}

nonisolated struct GroomingTimingAllocation: Equatable, Sendable {
    let service: GroomingTimeSpan
    let occupied: GroomingTimeSpan
}

nonisolated enum GroomingWallTimeResolution: Equatable, Sendable {
    case unique(Date)
    case ambiguous(first: Date, last: Date)
    case nonexistent
}

nonisolated enum GroomingServiceTiming {
    static let minimumLeadTime: TimeInterval = 5 * 60
    static let durationBounds = 15...720
    private static let locationTimeZones = Set(TimeZone.knownTimeZoneIdentifiers).union(["UTC"])

    static func serviceEnd(start: Date, durationMinutes: Int) -> Date? {
        guard durationBounds.contains(durationMinutes), start.timeIntervalSinceReferenceDate.isFinite else { return nil }
        let end = start.addingTimeInterval(TimeInterval(durationMinutes) * 60)
        guard end.timeIntervalSinceReferenceDate.isFinite, end > start else { return nil }
        return end
    }

    static func remainingWindow(start: Date, end: Date, now: Date) -> GroomingTimeSpan? {
        guard now.timeIntervalSinceReferenceDate.isFinite,
              (try? GroomingTimeSpan(start: start, end: end)) != nil else { return nil }
        return try? GroomingTimeSpan(start: max(start, now.addingTimeInterval(minimumLeadTime)), end: end)
    }

    static func allocation(start: Date, durationMinutes: Int, buffers: GroomingTimingBuffers,
                           locationMode: GroomingLocationMode) throws -> GroomingTimingAllocation {
        guard let end = serviceEnd(start: start, durationMinutes: durationMinutes) else {
            throw GroomingTimingError.invalidDuration
        }
        let mobile = locationMode == .groomerComesToCustomer
        let before = buffers.preparation + (mobile ? buffers.inboundTravel : 0)
        let after = buffers.cleanup + (mobile ? buffers.outboundTravel : 0)
        return GroomingTimingAllocation(
            service: try GroomingTimeSpan(start: start, end: end),
            occupied: try GroomingTimeSpan(start: start.addingTimeInterval(-TimeInterval(before) * 60),
                                          end: end.addingTimeInterval(TimeInterval(after) * 60))
        )
    }

    static func earliestStart(now: Date, noticeDays: Int, scheduleTimeZone: String) throws -> Date {
        guard (0...2).contains(noticeDays), now.timeIntervalSinceReferenceDate.isFinite else {
            throw GroomingTimingError.invalidNotice
        }
        let calendar = try locationCalendar(scheduleTimeZone)
        guard let day = calendar.date(byAdding: .day, value: noticeDays, to: calendar.startOfDay(for: now)) else {
            throw GroomingTimingError.invalidNotice
        }
        return max(now.addingTimeInterval(minimumLeadTime), day)
    }

    // A UTC-backed value carries editable wall components without DST normalization.
    static func wallInput(for instant: Date, timeZoneIdentifier: String) throws -> Date {
        let source = try locationCalendar(timeZoneIdentifier)
        var input = Calendar(identifier: .gregorian)
        input.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = source.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        guard let date = input.date(from: parts) else { throw GroomingTimingError.invalidTimeZone }
        return date
    }

    static func resolveWallInput(_ input: Date, timeZoneIdentifier: String) throws -> GroomingWallTimeResolution {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: input)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let hour = parts.hour, let minute = parts.minute else { return .nonexistent }
        return try resolveWallTime(year: year, month: month, day: day, hour: hour, minute: minute,
            timeZoneIdentifier: timeZoneIdentifier)
    }

    static func resolveWallTime(year: Int, month: Int, day: Int, hour: Int, minute: Int,
                                timeZoneIdentifier: String) throws -> GroomingWallTimeResolution {
        let calendar = try locationCalendar(timeZoneIdentifier)
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute),
              let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else {
            return .nonexistent
        }
        let actualDay = calendar.dateComponents([.year, .month, .day], from: noon)
        guard actualDay.year == year, actualDay.month == month, actualDay.day == day else { return .nonexistent }
        let anchor = calendar.startOfDay(for: noon).addingTimeInterval(-1)
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: 0)
        guard let first = calendar.nextDate(after: anchor, matching: components, matchingPolicy: .strict,
                                           repeatedTimePolicy: .first),
              let last = calendar.nextDate(after: anchor, matching: components, matchingPolicy: .strict,
                                          repeatedTimePolicy: .last) else { return .nonexistent }
        return first == last ? .unique(first) : .ambiguous(first: first, last: last)
    }

    static func locationCalendar(_ identifier: String) throws -> Calendar {
        guard locationTimeZones.contains(identifier), let zone = TimeZone(identifier: identifier) else {
            throw GroomingTimingError.invalidTimeZone
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }
}
