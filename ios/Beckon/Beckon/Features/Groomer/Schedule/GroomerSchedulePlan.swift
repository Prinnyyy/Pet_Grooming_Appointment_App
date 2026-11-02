// What the groomer's Schedule says about one day (design): the day's bookings sorted by what the groomer has to do about them, the
// free time between two of them, the shape of the day and the words for it. The real page (Features/Bookings/
// GroomerSchedulePresentation.swift) still cuts the days and picks the day's bookings; this file only arranges what it hands over.
// Every time is the booking's own: its start and end. Nothing is added around them (design): the groomer judges what fits.
import SwiftUI


/// One booking of the day with its times read once.
struct GroomerScheduleSlot: Identifiable {
    let booking: Booking
    let start: Date
    let end: Date

    var id: UUID { booking.id }
    var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }

    init?(_ booking: Booking) {
        guard let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
              let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd) else { return nil }
        self.booking = booking
        self.start = start
        self.end = end
    }
}


/// Where a booking stands against the clock.
enum GroomerSlotPhase: Equatable {
    /// The service is under way.
    case live
    /// Its time has come and the service has not started.
    case due
    /// Its time has not come.
    case upcoming
    /// Its time is over and nobody closed it.
    case needsClosing
    /// An outcome waits for a word (the other side's confirmation) or the service was not confirmed; the booking's own words.
    case waiting(String)
    case done

    /// Still to do: the big card and the rows after it, as opposed to what is behind.
    var isAhead: Bool {
        switch self {
        case .live, .due, .upcoming: true
        case .needsClosing, .waiting, .done: false
        }
    }
}


extension GroomerScheduleSlot {
    func phase(at now: Date) -> GroomerSlotPhase {
        if booking.status == .completed { return .done }
        if booking.status == .unfulfilled { return .waiting(booking.fulfillmentTitle) }
        guard let fulfillment = booking.fulfillment else { return clockPhase(at: now) }
        switch fulfillment.phase {
        case .completed, .cancelled: return .done
        case .inService: return .live
        case .outcomeReported, .unfulfilled: return .waiting(booking.fulfillmentTitle)
        case .scheduled: return clockPhase(at: now)
        }
    }

    private func clockPhase(at now: Date) -> GroomerSlotPhase {
        now < start ? .upcoming : (now < end ? .due : .needsClosing)
    }
}


/// A day's bookings arranged for the groomer. Today has a focus (what is happening or comes next, the big card), what is ahead of
/// it and what is behind; any other day is one list in time order.
struct GroomerSchedulePlan {
    struct Item: Identifiable {
        let slot: GroomerScheduleSlot
        let phase: GroomerSlotPhase
        var id: UUID { slot.id }
    }

    let focus: Item?
    let ahead: [Item]
    let behind: [Item]

    /// The focus first, then what is ahead: the order the page shows them in.
    var sequence: [Item] { (focus.map { [$0] } ?? []) + ahead }

    init(slots: [GroomerScheduleSlot], now: Date, isToday: Bool) {
        let items = slots.sorted { $0.start < $1.start }.map { Item(slot: $0, phase: $0.phase(at: now)) }
        guard isToday else {
            focus = nil
            ahead = items
            behind = []
            return
        }
        let focus = items.first { $0.phase == .live } ?? items.first { $0.phase == .due } ?? items.first { $0.phase == .upcoming }
        self.focus = focus
        ahead = items.filter { $0.id != focus?.id && $0.phase.isAhead }
        behind = items.filter { !$0.phase.isAhead }
    }
}


/// The time that stands free between the end of one booking and the start of the next.
enum GroomerFreeTime: Equatable {
    case free(minutes: Int)
    case backToBack
    case overlap

    /// Shorter than this is not time to do anything in.
    static let usableMinutes = 15

    init(from first: GroomerScheduleSlot, to second: GroomerScheduleSlot) {
        let minutes = Int(second.start.timeIntervalSince(first.end) / 60)
        self = second.start < first.end ? .overlap : (minutes < Self.usableMinutes ? .backToBack : .free(minutes: minutes))
    }
}


/// The day as a strip of hours: where the bookings stand in it, when the groomer is open, and where now is.
struct GroomerDayShape {
    enum Kind { case done, live, ahead }

    struct Segment: Identifiable {
        let id: UUID
        let from: Int
        let to: Int
        let kind: Kind
    }

    /// Minutes of the day, whole hours, never less than 8 AM to 6 PM.
    let visible: ClosedRange<Int>
    let segments: [Segment]
    /// The hours the groomer is open that day, when they are known.
    let open: ClosedRange<Int>?
    /// Now, as a minute of the day (today only).
    let now: Int?

    init(items: [GroomerSchedulePlan.Item], dayStart: Date, open: ClosedRange<Int>?, now: Date?) {
        func minute(_ date: Date) -> Int { max(0, min(24 * 60, Int(date.timeIntervalSince(dayStart) / 60))) }
        let segments = items.map { item -> Segment in
            let kind: Kind = switch item.phase {
            case .live: .live
            case .due, .upcoming: .ahead
            case .needsClosing, .waiting, .done: .done
            }
            return Segment(id: item.id, from: minute(item.slot.start), to: minute(item.slot.end), kind: kind)
        }
        var low = 8 * 60
        var high = 18 * 60
        if let first = segments.map(\.from).min() { low = min(low, first / 60 * 60) }
        if let last = segments.map(\.to).max() { high = max(high, (last + 59) / 60 * 60) }
        if let open {
            low = min(low, open.lowerBound / 60 * 60)
            high = max(high, (open.upperBound + 59) / 60 * 60)
        }
        visible = max(0, low)...min(24 * 60, high)
        self.segments = segments
        self.open = open
        self.now = now.map(minute)
    }
}


/// The weekly hours of a day, from the groomer's availability.
enum GroomerScheduleHours {
    /// How long a day is when the groomer's hours for it are not known: 8 AM to 6 PM, as the day's strip of hours draws it.
    static let unknownOpenMinutes = 10 * 60

    /// The window of the weekday `date` falls on in `calendar` (Monday is 1 in the availability, Sunday is 1 in a calendar).
    static func window(on date: Date, calendar: Calendar, in windows: [GroomerAvailabilityWindow]) -> GroomerAvailabilityWindow? {
        let weekday = (calendar.component(.weekday, from: date) + 5) % 7 + 1
        return windows.first { $0.weekday.rawValue == weekday }
    }

    /// The minutes of the day the groomer is open, when that day is open and the window makes sense.
    static func open(_ window: GroomerAvailabilityWindow?) -> ClosedRange<Int>? {
        guard let window, window.isEnabled, window.endMinutes > window.startMinutes else { return nil }
        return window.startMinutes...window.endMinutes
    }
}


/// The words of the Schedule that are worked out, not stored.
enum GroomerScheduleText {
    /// "1h 05m", "35 min", "2h".
    static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(String(format: "%02d", rest))m"
    }

    /// "8 AM", "12 PM".
    static func hour(_ minute: Int) -> String {
        let hour = minute / 60 % 24
        return "\(hour % 12 == 0 ? 12 : hour % 12) \(hour >= 12 ? "PM" : "AM")"
    }

    /// The day in one line: "3 appointments · 4h 30m booked · $205".
    static func summary(count: Int, durationSummary: String, price: Double) -> String {
        var parts = ["\(count) appointment\(count == 1 ? "" : "s")"]
        if durationSummary != "Time unavailable" { parts.append("\(durationSummary) booked") }
        if price > 0 { parts.append(price.formatted(.currency(code: "USD").precision(.fractionLength(0...2)))) }
        return parts.joined(separator: " · ")
    }

    /// Where the appointment is, as short as it can be said: "Mobile · 88 Maple Court, Seattle" or "Studio".
    static func place(of booking: Booking) -> String {
        guard booking.locationMode == .groomerComesToCustomer else { return "Studio" }
        let parts = [booking.customerStreetAddress, booking.customerCity].compactMap { $0 }.filter { !$0.isEmpty }
        return "Mobile · " + (parts.isEmpty ? booking.appointmentAddressSummary : parts.joined(separator: ", "))
    }
}
