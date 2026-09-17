import Foundation

struct ChatConversation: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let customerID: UUID
    let groomerID: UUID
    let latestBookingID: UUID?
    let latestRequestID: UUID?
    let scheduledStart: String?
    let scheduledEnd: String?
    let priceEstimate: Double?
    let bookingStatus: BookingStatus?
    let completedAt: String?
    let groomerBusinessName: String?
    let counterpartAvatarPhotoData: Data?
    let latestMessageSenderID: UUID?
    let latestMessageCreatedAt: String?
    let latestMessageBody: String?
    let createdAt: String
    let updatedAt: String
    let serviceTimeZoneIdentifier: String?

    nonisolated init(
        id: UUID,
        customerID: UUID,
        groomerID: UUID,
        latestBookingID: UUID? = nil,
        latestRequestID: UUID? = nil,
        scheduledStart: String? = nil,
        scheduledEnd: String? = nil,
        priceEstimate: Double? = nil,
        bookingStatus: BookingStatus? = nil,
        completedAt: String? = nil,
        groomerBusinessName: String? = nil,
        counterpartAvatarPhotoData: Data? = nil,
        latestMessageSenderID: UUID? = nil,
        latestMessageCreatedAt: String? = nil,
        latestMessageBody: String? = nil,
        createdAt: String,
        updatedAt: String,
        serviceTimeZoneIdentifier: String? = nil
    ) {
        self.id = id
        self.customerID = customerID
        self.groomerID = groomerID
        self.latestBookingID = latestBookingID
        self.latestRequestID = latestRequestID
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.priceEstimate = priceEstimate
        self.bookingStatus = bookingStatus
        self.completedAt = completedAt
        self.groomerBusinessName = groomerBusinessName
        self.counterpartAvatarPhotoData = counterpartAvatarPhotoData
        self.latestMessageSenderID = latestMessageSenderID
        self.latestMessageCreatedAt = latestMessageCreatedAt
        self.latestMessageBody = latestMessageBody
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serviceTimeZoneIdentifier = serviceTimeZoneIdentifier
    }

    nonisolated var latestBookingReferenceCode: String? {
        latestBookingID.map(Self.referenceCode)
    }

    nonisolated var scheduledTimeSummary: String? {
        guard let scheduledStart, let scheduledEnd else { return nil }
        return "\(GroomingRequestDateFormatting.displayString(from: scheduledStart, serviceTimeZoneIdentifier: serviceTimeZoneIdentifier)) – \(GroomingRequestDateFormatting.displayString(from: scheduledEnd, serviceTimeZoneIdentifier: serviceTimeZoneIdentifier))"
    }

    nonisolated var priceSummary: String? {
        guard let priceEstimate else { return nil }
        return priceEstimate.formatted(
            .currency(code: "USD").precision(.fractionLength(2))
        )
    }

    nonisolated var bookingContextSummary: String {
        var parts: [String] = []
        if let latestBookingReferenceCode {
            parts.append("Booking ref \(latestBookingReferenceCode)")
        }
        if let scheduledTimeSummary {
            parts.append(scheduledTimeSummary)
        }
        if let priceSummary {
            parts.append(priceSummary)
        }
        return parts.joined(separator: " • ")
    }

    nonisolated var bookingReferenceAndPriceSummary: String {
        var parts: [String] = []
        if let latestBookingReferenceCode {
            parts.append("Booking ref \(latestBookingReferenceCode)")
        }
        if let priceSummary {
            parts.append(priceSummary)
        }
        return parts.joined(separator: " • ")
    }

    nonisolated var bookingStatusTitle: String {
        bookingStatus?.title ?? "Booking"
    }

    nonisolated func canSendMessages(now: Date = Date()) -> Bool {
        !isReadOnly(now: now)
    }

    nonisolated func isReadOnly(now: Date = Date()) -> Bool {
        guard bookingStatus == .completed else { return false }
        guard let closedDate = messageCloseReferenceDate else { return false }
        return now.timeIntervalSince(closedDate) >= Self.messageReadOnlyDelay
    }

    nonisolated var readOnlyReason: String {
        "This conversation is read-only because the booking ended more than 7 days ago."
    }

    nonisolated func participantReferenceCode(for role: UserRole) -> String {
        switch role {
        case .customer:
            Self.referenceCode(for: groomerID)
        case .groomer:
            Self.referenceCode(for: customerID)
        }
    }

    nonisolated func participantSummary(for role: UserRole) -> String {
        switch role {
        case .customer:
            if let groomerBusinessName = Self.normalized(groomerBusinessName) {
                return groomerBusinessName
            }
            return "Groomer ref \(participantReferenceCode(for: role))"
        case .groomer:
            return "Customer ref \(participantReferenceCode(for: role))"
        }
    }

    nonisolated private static func referenceCode(for id: UUID) -> String {
        String(id.uuidString.prefix(8)).uppercased()
    }

    nonisolated private var messageCloseReferenceDate: Date? {
        if let completedAt,
           let date = GroomingRequestDateFormatting.parsedDate(from: completedAt) {
            return date
        }

        if let scheduledEnd,
           let date = GroomingRequestDateFormatting.parsedDate(from: scheduledEnd) {
            return date
        }

        return nil
    }

    nonisolated private static let messageReadOnlyDelay: TimeInterval =
        7 * 24 * 60 * 60

    nonisolated private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated enum ChatCounterpartAvatarTarget: Equatable, Sendable {
    case customer
    case groomer

    static func viewer(_ role: UserRole) -> Self {
        switch role {
        case .customer:
            .groomer
        case .groomer:
            .customer
        }
    }

    var role: UserRole {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    func participantID(in conversation: ChatConversation) -> UUID {
        participantID(
            customerID: conversation.customerID,
            groomerID: conversation.groomerID
        )
    }

    func participantID(customerID: UUID, groomerID: UUID) -> UUID {
        switch self {
        case .customer:
            customerID
        case .groomer:
            groomerID
        }
    }
}

enum ChatMessageKind: String, Codable, Equatable, Hashable, Sendable {
    case text
    case bookingCard = "booking_card"
}

struct ChatMessage: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let kind: ChatMessageKind
    let body: String?
    let booking: Booking?
    let createdAt: String

    nonisolated var bookingID: UUID? {
        booking?.id
    }

    nonisolated func isSentBy(_ participantID: UUID) -> Bool {
        senderID == participantID
    }

    nonisolated var sentAtSummary: String {
        GroomingRequestDateFormatting.displayString(from: createdAt)
    }
}
