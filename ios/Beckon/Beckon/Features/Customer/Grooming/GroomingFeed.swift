// What is "in progress" for the owner, as one ordered list (S-057). The Grooming tab and Home's Next up row both show it, so the
// rule lives once: an open request and a booking are two records but one grooming, a booking made from an offer shows once (as the
// booking), a finished booking waiting for its review stays a while, and what needs the person first comes first.
import SwiftUI


/// One card of the Active list: an open request, or a booking (confirmed and coming up, just booked, or done and waiting for its review).
enum GroomingEntry: Identifiable {
    case request(CustomerRequestActionCardItem)
    case booking(Booking, handoff: CustomerRequestBookingHandoff?, avatar: Data?)

    var id: UUID {
        switch self {
        case .request(let card): card.request.id
        case .booking(let booking, _, _): booking.id
        }
    }
}


enum GroomingFeed {
    static func startOfAppointmentDay(_ booking: Booking) -> Date? { GroomingLifecycle.startOfAppointmentDay(booking) }
    static func endOfAppointmentDay(_ booking: Booking) -> Date? { GroomingLifecycle.endOfAppointmentDay(booking) }
    static func isFinished(_ booking: Booking, now: Date) -> Bool { GroomingLifecycle.isFinished(booking, now: now) }

    /// How far along the line from Booked to Finished a booking is. Nothing is half done before the day, so the line is empty; on the
    /// appointment's day it is half way ("Today"); once the appointment's own time is over but the day is not, it is most of the way
    /// (it is only waiting for the groomer, or for midnight); a service reported but not yet confirmed is there too. Finished is full.
    static func waitingProgress(_ booking: Booking, now: Date) -> Double {
        if isFinished(booking, now: now) { return 1 }
        if booking.fulfillment?.phase == .outcomeReported { return 0.8 }
        guard let startOfDay = startOfAppointmentDay(booking), now >= startOfDay else { return 0 }
        if let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd), now >= end { return 0.8 }
        return 0.5
    }

    /// Finished and not reviewed, and finished recently: it is still something to do, so it stays in the row a while (14 days from
    /// when it finished; without a limit every old unreviewed booking would come back as a card).
    static func needsReview(_ booking: Booking, now: Date) -> Bool {
        GroomingLifecycle.needsReviewReminder(booking, now: now)
    }

    /// In the row: before the appointment's day is over, or finished and waiting for its review.
    static func isActive(_ booking: Booking, now: Date) -> Bool {
        if needsReview(booking, now: now) { return true }
        return booking.status == .confirmed && !isFinished(booking, now: now)
    }

    /// A refreshed booking wins over the snapshot retained for the acceptance animation.
    static func canonicalBookings(cards: [CustomerRequestActionCardItem], bookings: [Booking]) -> [Booking] {
        var byID: [UUID: Booking] = [:]
        for card in cards { if let booking = card.handoff?.booking { byID[booking.id] = booking } }
        for booking in bookings { byID[booking.id] = booking }
        return Array(byID.values)
    }

    static func activeEntries(cards: [CustomerRequestActionCardItem], bookings: [Booking],
                              avatar: (UUID?) -> Data?, now: Date = Date()) -> [GroomingEntry] {
        let current = canonicalBookings(cards: cards, bookings: bookings)
        let bookedRequests = Set(current.map(\.requestID))
        var entries: [GroomingEntry] = cards.filter {
            $0.handoff == nil && !bookedRequests.contains($0.request.id) && $0.request.status.isOpenForOffers
        }.map(GroomingEntry.request)
        for booking in current where isActive(booking, now: now) {
            let card = cards.first { $0.request.id == booking.requestID }
            let handoff = card?.handoff.map { CustomerRequestBookingHandoff(request: $0.request, booking: booking) }
            entries.append(.booking(booking, handoff: handoff, avatar: card?.petAvatarPhotoData ?? avatar(booking.requestPetSnapshot?.id)))
        }
        return entries.sorted { lhs, rhs in
            let (left, right) = (sortKey(lhs, now: now), sortKey(rhs, now: now))
            if left.rank != right.rank { return left.rank < right.rank }
            if left.order != right.order { return left.order < right.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Refresh at midnight, the service boundary, or the end of the reminder period, including after foregrounding.
    static func nextTransition(bookings: [Booking], requestDeadline: Date?, now: Date = Date()) -> Date? {
        var deadlines = bookings.flatMap { booking in
            [startOfAppointmentDay(booking), endOfAppointmentDay(booking),
             GroomingLifecycle.finishedAt(booking)?.addingTimeInterval(14 * 86_400)]
        }.compactMap { $0 }.filter { $0 > now }
        if let requestDeadline, requestDeadline > now { deadlines.append(requestDeadline) }
        return deadlines.min()
    }

    private static func sortKey(_ entry: GroomingEntry, now: Date) -> (rank: Int, order: Double) {
        switch entry {
        case .request(let card):
            let created = GroomingRequestDateFormatting.parsedDate(from: card.request.createdAt)?.timeIntervalSince1970 ?? 0
            return (card.request.status == .hasOffers ? 0 : 3, -created)
        case .booking(let booking, _, _):
            let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart)?.timeIntervalSince1970 ?? 0
            return (needsReview(booking, now: now) ? 1 : 2, start)
        }
    }
}
