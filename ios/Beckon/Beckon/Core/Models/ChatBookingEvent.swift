import Foundation

/// Server-recorded display facts. Never used to authorize booking actions or reviews.
nonisolated struct ChatBookingEvent: Codable, Equatable, Hashable, Sendable {
    let version: Int
    let action: String
    let bookingID: UUID
    let actorID: UUID
    let actorRole: String
    var scheduledStart: String? = nil
    var scheduledEnd: String? = nil
    var previousStart: String? = nil
    var price: Double? = nil
    var petName: String? = nil
    var serviceType: GroomingServiceType? = nil
    var locationMode: GroomingLocationMode? = nil
    var timeZone: String? = nil
    var status: BookingStatus? = nil

    var title: String {
        switch action {
        case "confirmed": "Confirmed"
        case "start": "In service"
        case "complete", "confirm_completion": "Completed"
        case "cancel": actorRole == "customer" ? "Cancelled by customer" : actorRole == "groomer" ? "Cancelled by groomer" : "Cancelled"
        case "reschedule_propose": "Time change proposed"
        case "reschedule_accept": "New time confirmed"
        case "reschedule_reject": "Time change declined"
        case "reschedule_withdraw": "Time change withdrawn"
        case "report_no_show": "Absence reported"
        case "report_interruption": "Interruption reported"
        case "service_issue_reported": "Service issue reported"
        case "report_completion": "Completion reported"
        case "confirm_report", "close_elapsed": "Service not completed"
        case "withdraw_report": "Report withdrawn"
        case "record_objection": "Outcome disputed"
        default: "Booking update"
        }
    }
    var isCompletion: Bool { ["complete", "confirm_completion"].contains(action) }
    var isCancelled: Bool { action == "cancel" }
    var isWarning: Bool { ["report_no_show", "report_interruption", "service_issue_reported", "report_completion", "record_objection"].contains(action) }
    func verified(bookingID: UUID?, senderID: UUID) -> Self? {
        guard [0, 1].contains(version), self.bookingID == bookingID, actorID == senderID,
              ["customer", "groomer"].contains(actorRole) else { return nil }
        return self
    }
    private enum CodingKeys: String, CodingKey {
        case version, action, price, status
        case bookingID = "booking_id", actorID = "actor_id", actorRole = "actor_role"
        case scheduledStart = "scheduled_start", scheduledEnd = "scheduled_end", previousStart = "previous_start"
        case petName = "pet_name", serviceType = "service_type", locationMode = "location_mode", timeZone = "time_zone"
    }
}

/// Recognize only the old server's exact card + text pair (same sender, one microsecond apart).
/// A person typing the same words later is still an ordinary message; no history rows are deleted.
nonisolated enum ChatLegacyBookingMessages {
    static let actions: [String: String] = [
        "Hi! I've accepted your offer and confirmed this booking. Looking forward to working with you!": "confirmed",
        "Hi, I'm sorry, but I've had to cancel this booking. Thank you for understanding.": "cancel",
        "Service has started.": "start",
        "Service is completed. The customer can leave a review.": "complete",
        "This booking was cancelled before service. The original request remains closed.": "cancel",
        "The proposed appointment time was accepted. This booking now uses the newly agreed time.": "reschedule_accept",
        "A new appointment time was proposed. The original appointment remains confirmed until both participants agree.": "reschedule_propose",
        "The time change was declined. The original appointment remains confirmed.": "reschedule_reject",
        "The time change was withdrawn. The original appointment remains confirmed.": "reschedule_withdraw",
        "A service issue was reported. Please confirm the service outcome. No fault has been assigned.": "service_issue_reported",
        "Both participants confirmed that service ended without completion. No fault has been assigned.": "confirm_report",
        "The service outcome report was withdrawn. Previous observations remain recorded.": "withdraw_report",
        "This elapsed booking was closed without confirmed completion. No fault has been assigned.": "close_elapsed",
        "Service completion was reported retrospectively. The other participant must confirm it.": "report_completion",
        "Both participants confirmed service completion. Unrecorded actual times remain unverified.": "confirm_completion",
        "An observation about the recorded service outcome was added. No automatic judgment has been made.": "record_objection"
    ]
    private static func microseconds(_ value: String) -> Int64? {
        // ISO8601DateFormatter drops sub-millisecond precision on some iOS versions.
        // Compare the server's exact microseconds instead of broadening the match window.
        let whole: String
        var fraction: Int64 = 0
        if let dot = value.firstIndex(of: ".") {
            let tail = value[value.index(after: dot)...]
            let digits = tail.prefix { $0.isNumber }
            guard !digits.isEmpty, digits.count <= 6,
                  let micros = Int64(String(digits) + String(repeating: "0", count: 6 - digits.count)) else { return nil }
            fraction = micros
            whole = String(value[..<dot]) + String(tail.dropFirst(digits.count))
        } else { whole = value }
        guard let date = GroomingRequestDateFormatting.parsedDate(from: whole) else { return nil }
        return Int64(date.timeIntervalSince1970.rounded()) * 1_000_000 + fraction
    }

    static func present(_ messages: [ChatMessage]) -> [ChatMessage] {
        var result: [ChatMessage] = []
        for message in messages {
            if message.kind == .text, let body = message.body, let action = actions[body],
               var card = result.last, card.kind == .bookingCard,
               card.senderID == message.senderID, card.conversationID == message.conversationID,
               let before = microseconds(card.createdAt),
               let after = microseconds(message.createdAt), after - before == 1,
               let booking = card.booking {
                if card.bookingEvent == nil {
                    card.bookingEvent = .init(version: 0, action: action, bookingID: booking.id, actorID: card.senderID,
                        actorRole: card.senderID == booking.customerID ? "customer" : "groomer")
                    result[result.count - 1] = card
                }
                continue
            }
            result.append(message)
        }
        return result
    }
}

extension ChatBookingEvent {
    nonisolated func displayBooking(fallback b: Booking) -> Booking {
        let status: BookingStatus = self.status ?? (isCancelled ? (actorRole == "customer" ? .cancelledByCustomer : .cancelledByGroomer)
            : isCompletion ? .completed : ["confirm_report", "close_elapsed"].contains(action) ? .unfulfilled : .confirmed)
        return Booking(id: b.id, requestID: b.requestID, offerID: b.offerID, customerID: b.customerID, groomerID: b.groomerID,
            scheduledStart: scheduledStart ?? b.scheduledStart, scheduledEnd: scheduledEnd ?? b.scheduledEnd,
            priceEstimate: price ?? b.priceEstimate, status: status, cancelledBy: isCancelled ? actorID : nil,
            cancelledAt: nil, completedAt: nil, completedBy: nil, createdAt: b.createdAt, updatedAt: b.updatedAt,
            review: nil, serviceType: serviceType ?? b.serviceType,
            requestPetSnapshot: b.agreementSnapshot?.petSnapshot ?? b.requestPetSnapshot,
            locationMode: locationMode ?? b.locationMode,
            serviceTimeZoneIdentifier: timeZone ?? b.agreementSnapshot?.serviceTimeZoneIdentifier ?? b.serviceTimeZoneIdentifier)
    }
}
