import SwiftUI

/// Rendering only: retains the booking's service state and elapsed connector progress.
struct GroomerVisitBookingJourney: View {
    let booking: Booking
    let stage: GroomerBookingStage
    let status: GroomerVisitCardStatus
    let decision: String?
    let now: Date

    var body: some View {
        if let closed = stage.closed {
            let cancelled = booking.status.isCancellation
            let title = cancelled ? "Cancelled" : "Closed"
            let text = booking.status == .cancelledByCustomer ? "Customer cancelled"
                : booking.status == .cancelledByGroomer ? "Cancelled by you" : closed.status.title
            GroomerVisitJourneyCallout(text, cancelled ? "xmark.circle.fill" : "archivebox", .quiet)
                .track(stops: [.booked, .init(title: title, systemImage: cancelled ? "xmark" : "archivebox")],
                       current: 1, fills: [1], column: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Booked. " + text)
        } else if let path = stage.path {
            let finishedWaiting = stage.isFinished && booking.review == nil
            let current = finishedWaiting ? 2 : path.current
            let fills = finishedWaiting ? [1.0, 1.0, 0.4] : path.fills
            let column = finishedWaiting ? 2 : min(path.bubble?.column ?? current, path.stops.count - 1)
            callout(path).track(stops: path.stops, current: current, fills: fills, column: column)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(path.status + ". " + callout(path).text)
        } else {
            GroomerVisitJourneyCallout("Status unavailable", "questionmark.circle", .quiet)
                .track(stops: BeckonJourneyStop.servicePath, current: 0, fills: [0,0,0], column: 0)
        }
    }

    private func callout(_ path: GroomingDetailHero.Path) -> GroomerVisitJourneyCallout {
        if let decision {
            return .init(decision == "Reply to time change" ? "Reply to time change" : decision,
                         "exclamationmark.circle.fill", .action)
        }
        if let responder = status.waitingFor {
            return .init(stage.isFinished ? "Awaiting review" : "Waiting for customer", nil, .waitingFor(responder))
        }
        if stage.isFinished { return .init("Review received", "star.fill", .success) }
        if let bubble = path.bubble {
            if case .countdown = bubble.kind, let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart) {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier ?? "") ?? .current
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: start)).day ?? 0
                let time = start.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: calendar,
                    timeZone: calendar.timeZone).hour().minute())
                return .init(days > 1 ? "In \(days) days" : days == 1 ? "Tomorrow" : "Today · " + time, "clock.fill", .quiet)
            }
            if let semantic = GroomerVisitJourneyCallout.booking(bubble.kind) { return semantic }
        }
        return .init(status.title, status.symbol, status.resolvedTone)
    }
}
