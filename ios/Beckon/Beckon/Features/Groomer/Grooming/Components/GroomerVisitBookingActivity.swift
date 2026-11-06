import SwiftUI

extension GroomingTimelineEntry {
    @MainActor static func groomerVisitBooking(_ booking: Booking, changes: [BookingTimeChangeActivity],
        proposal: BookingRescheduleProposal?, now: Date) -> [Self] {
        let zone = booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier
        func when(_ raw: String?) -> String? {
            raw.map { GroomingRequestDateFormatting.displayString(from: $0, serviceTimeZoneIdentifier: zone) }
        }
        func who(_ id: UUID?) -> String { id == booking.groomerID ? "You" : id == booking.customerID ? "Customer" : "" }
        func title(_ name: String, actor: UUID?) -> String {
            let person = who(actor)
            return person.isEmpty ? name : name + " · " + person
        }
        func interval(_ start: String, _ end: String) -> String {
            guard let a = GroomingRequestDateFormatting.parsedDate(from: start),
                  let b = GroomingRequestDateFormatting.parsedDate(from: end) else { return "Time unavailable" }
            var calendar = Calendar.current
            if let zone, let tz = TimeZone(identifier: zone) { calendar.timeZone = tz }
            let labels = GroomerVisitRequestTimeLabels(start: a, end: b, calendar: calendar)
            return labels.startDate + "\n" + labels.startTime + " – " + labels.endTime
        }
        var rows: [(String, Self)] = []
        func add(_ id: String, _ name: String, _ icon: String, _ time: String?, actor: UUID? = nil, note: String? = nil) {
            rows.append((time ?? "", .init(id: id, systemImage: icon, title: title(name, actor: actor), detail: when(time), note: note)))
        }
        add("booked", "Booked", "calendar", booking.createdAt)
        let history = changes
        for change in history {
            let p = change.proposal
            let name: String
            let note: String?
            switch change.action {
            case .propose:
                name = "Time change requested"
                note = "Current\n" + interval(p.previousAgreement.scheduledStart, p.previousAgreement.scheduledEnd)
                    + "\n\nProposed\n" + interval(p.proposedStart, p.proposedEnd)
            case .accept:
                name = "Time change accepted"; note = nil
            case .reject:
                name = "Time change declined"; note = nil
            case .withdraw:
                name = "Time change withdrawn"; note = nil
            }
            add(change.id.uuidString, name, "calendar.badge.clock", change.recordedAt, actor: change.actor, note: note)
        }
        if let proposal, proposal.currentStatus(for: booking, now: now) == .expired {
            add("expired-" + proposal.id.uuidString, "Time change expired", "clock", proposal.expiresAt)
        }
        if let time = booking.completedAt { add("finished", "Finished", "checkmark", time, actor: booking.completedBy) }
        if let time = booking.cancelledAt { add("cancelled", "Cancelled", "xmark", time, actor: booking.cancelledBy) }
        if let review = booking.review { add("reviewed", "Reviewed", "star", review.createdAt) }
        return rows.enumerated().sorted { a, b in
            a.element.0 == b.element.0 ? a.offset < b.offset : a.element.0 < b.element.0
        }.map { $0.element.1 }
    }
}
