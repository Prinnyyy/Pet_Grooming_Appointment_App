import Foundation

struct CustomerNotification:
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    let customerID: UUID
    let kind: CustomerNotificationKind
    let title: String
    let body: String
    let isRead: Bool
    let createdAt: String
    let readAt: String?
    let relatedRequestID: UUID?
    let relatedBookingID: UUID?
    let relatedOfferID: UUID?

    var createdAtDate: Date {
        GroomingRequestDateFormatting.parsedDate(from: createdAt) ?? .distantPast
    }

    var createdAtSummary: String {
        GroomingRequestDateFormatting.displayString(from: createdAt)
    }

    func replacingReadState(
        isRead: Bool,
        readAt: String?
    ) -> CustomerNotification {
        CustomerNotification(
            id: id,
            customerID: customerID,
            kind: kind,
            title: title,
            body: body,
            isRead: isRead,
            createdAt: createdAt,
            readAt: readAt,
            relatedRequestID: relatedRequestID,
            relatedBookingID: relatedBookingID,
            relatedOfferID: relatedOfferID
        )
    }
}

nonisolated enum CustomerNotificationKind:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Sendable
{
    case requestPublished = "request_published"
    case requestCancelled = "request_cancelled"
    case bookingConfirmed = "booking_confirmed"
    case bookingCancelled = "booking_cancelled"
    case newOffer = "new_offer"
    case newMessage = "new_message"
    case unknown

    var defaultTitle: String {
        switch self {
        case .requestPublished:
            "Request published"
        case .requestCancelled:
            "Request cancelled"
        case .bookingConfirmed:
            "Booking confirmed"
        case .bookingCancelled:
            "Booking cancelled"
        case .newOffer:
            "New offer received"
        case .newMessage:
            "New message"
        case .unknown:
            "Notification"
        }
    }

    var systemImage: String {
        switch self {
        case .requestPublished:
            "paperplane.fill"
        case .requestCancelled:
            "xmark.circle.fill"
        case .bookingConfirmed:
            "checkmark.seal.fill"
        case .bookingCancelled:
            "calendar.badge.xmark"
        case .newOffer:
            "tag.fill"
        case .newMessage:
            "message.fill"
        case .unknown:
            "bell.fill"
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}
