import Foundation

struct ChatConversation: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let bookingID: UUID
    let requestID: UUID
    let customerID: UUID
    let groomerID: UUID
    let scheduledStart: String?
    let scheduledEnd: String?
    let priceEstimate: Double?
    let groomerBusinessName: String?
    let createdAt: String
    let updatedAt: String

    nonisolated init(
        id: UUID,
        bookingID: UUID,
        requestID: UUID,
        customerID: UUID,
        groomerID: UUID,
        scheduledStart: String? = nil,
        scheduledEnd: String? = nil,
        priceEstimate: Double? = nil,
        groomerBusinessName: String? = nil,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.bookingID = bookingID
        self.requestID = requestID
        self.customerID = customerID
        self.groomerID = groomerID
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.priceEstimate = priceEstimate
        self.groomerBusinessName = groomerBusinessName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    nonisolated var bookingReferenceCode: String {
        Self.referenceCode(for: bookingID)
    }

    nonisolated var scheduledTimeSummary: String? {
        guard let scheduledStart, let scheduledEnd else { return nil }
        return "\(GroomingRequestDateFormatting.displayString(from: scheduledStart)) – \(GroomingRequestDateFormatting.displayString(from: scheduledEnd))"
    }

    nonisolated var priceSummary: String? {
        guard let priceEstimate else { return nil }
        return priceEstimate.formatted(
            .currency(code: "USD").precision(.fractionLength(2))
        )
    }

    nonisolated var bookingContextSummary: String {
        var parts = ["Booking ref \(bookingReferenceCode)"]
        if let scheduledTimeSummary {
            parts.append(scheduledTimeSummary)
        }
        if let priceSummary {
            parts.append(priceSummary)
        }
        return parts.joined(separator: " • ")
    }

    nonisolated var bookingReferenceAndPriceSummary: String {
        var parts = ["Booking ref \(bookingReferenceCode)"]
        if let priceSummary {
            parts.append(priceSummary)
        }
        return parts.joined(separator: " • ")
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

    nonisolated private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ChatMessage: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let body: String
    let createdAt: String

    nonisolated func isSentBy(_ participantID: UUID) -> Bool {
        senderID == participantID
    }

    nonisolated var sentAtSummary: String {
        GroomingRequestDateFormatting.displayString(from: createdAt)
    }
}
