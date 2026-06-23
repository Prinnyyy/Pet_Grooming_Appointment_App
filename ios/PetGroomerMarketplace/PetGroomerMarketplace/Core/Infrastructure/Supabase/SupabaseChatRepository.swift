import Foundation
import Supabase

@MainActor
final class SupabaseChatRepository: ChatRepository {
    private static let conversationColumns = """
        id,booking_id,request_id,customer_id,groomer_id,created_at,updated_at
        """
    private static let bookingSummaryColumns =
        "id,scheduled_start,scheduled_end,price_estimate,status,completed_at"
    private static let groomerSummaryColumns = "user_id,business_name"
    private static let messageColumns = "id,conversation_id,sender_id,body,created_at"

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func conversations(
        participantID: UUID,
        role: UserRole
    ) async throws -> [ChatConversation] {
        do {
            let participantColumn = switch role {
            case .customer:
                "customer_id"
            case .groomer:
                "groomer_id"
            }

            let rows: [ChatConversationRow] = try await client
                .from("conversations")
                .select(Self.conversationColumns)
                .eq(participantColumn, value: participantID.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value

            let bookingSummaries = await bookingSummaries(
                for: rows.map(\.bookingID)
            )
            let groomerBusinessNames = switch role {
            case .customer:
                await groomerBusinessNames(for: rows.map(\.groomerID))
            case .groomer:
                [UUID: String]()
            }

            return rows.map { row in
                row.conversation(
                    bookingSummary: bookingSummaries[row.bookingID],
                    groomerBusinessName: groomerBusinessNames[row.groomerID]
                )
            }
        } catch {
            throw Self.map(error)
        }
    }

    func messages(
        conversationID: UUID
    ) async throws -> [ChatMessage] {
        do {
            let rows: [ChatMessageRow] = try await client
                .from("messages")
                .select(Self.messageColumns)
                .eq("conversation_id", value: conversationID.uuidString.lowercased())
                .order("created_at", ascending: true)
                .order("id", ascending: true)
                .execute()
                .value

            return rows.map(\.message)
        } catch {
            throw Self.map(error)
        }
    }

    func sendMessage(
        conversationID: UUID,
        senderID: UUID,
        body: String
    ) async throws -> ChatMessage {
        do {
            let rows: [ChatMessageRow] = try await client
                .from("messages")
                .insert(
                    ChatMessageInsertRow(
                        conversationID: conversationID,
                        senderID: senderID,
                        body: body
                    )
                )
                .select(Self.messageColumns)
                .execute()
                .value

            guard rows.count == 1, let message = rows.first?.message else {
                throw ChatRepositoryError.unavailable
            }

            return message
        } catch let error as ChatRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: any Error) -> ChatRepositoryError {
        if let repositoryError = error as? ChatRepositoryError {
            return repositoryError
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501", "28000":
                return .notAllowed
            case "23503":
                return .conversationNotFound
            case "23514", "22023":
                return .invalidMessage
            default:
                return .unavailable
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                return .networkUnavailable
            default:
                return .unavailable
            }
        }

        return .unavailable
    }

    private func bookingSummaries(
        for bookingIDs: [UUID]
    ) async -> [UUID: ChatBookingSummary] {
        let ids = uniqueLowercaseStrings(from: bookingIDs)
        guard !ids.isEmpty else { return [:] }

        do {
            let rows: [ChatBookingSummaryRow] = try await client
                .from("bookings")
                .select(Self.bookingSummaryColumns)
                .in("id", values: ids)
                .execute()
                .value

            return Dictionary(
                uniqueKeysWithValues: rows.map { ($0.id, $0.summary) }
            )
        } catch {
            return [:]
        }
    }

    private func groomerBusinessNames(
        for groomerIDs: [UUID]
    ) async -> [UUID: String] {
        let ids = uniqueLowercaseStrings(from: groomerIDs)
        guard !ids.isEmpty else { return [:] }

        do {
            let rows: [ChatGroomerSummaryRow] = try await client
                .from("groomer_profiles")
                .select(Self.groomerSummaryColumns)
                .in("user_id", values: ids)
                .execute()
                .value

            return Dictionary(
                uniqueKeysWithValues: rows.compactMap { row in
                    guard let businessName = row.normalizedBusinessName else {
                        return nil
                    }
                    return (row.userID, businessName)
                }
            )
        } catch {
            return [:]
        }
    }

    private func uniqueLowercaseStrings(from ids: [UUID]) -> [String] {
        Array(Set(ids)).map { $0.uuidString.lowercased() }
    }
}

private struct ChatConversationRow: Decodable {
    let id: UUID
    let bookingID: UUID
    let requestID: UUID
    let customerID: UUID
    let groomerID: UUID
    let createdAt: String
    let updatedAt: String

    func conversation(
        bookingSummary: ChatBookingSummary?,
        groomerBusinessName: String?
    ) -> ChatConversation {
        ChatConversation(
            id: id,
            bookingID: bookingID,
            requestID: requestID,
            customerID: customerID,
            groomerID: groomerID,
            scheduledStart: bookingSummary?.scheduledStart,
            scheduledEnd: bookingSummary?.scheduledEnd,
            priceEstimate: bookingSummary?.priceEstimate,
            bookingStatus: bookingSummary?.status,
            completedAt: bookingSummary?.completedAt,
            groomerBusinessName: groomerBusinessName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case bookingID = "booking_id"
        case requestID = "request_id"
        case customerID = "customer_id"
        case groomerID = "groomer_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct ChatBookingSummary: Sendable {
    let scheduledStart: String
    let scheduledEnd: String
    let priceEstimate: Double
    let status: BookingStatus
    let completedAt: String?
}

private struct ChatBookingSummaryRow: Decodable {
    let id: UUID
    let scheduledStart: String
    let scheduledEnd: String
    let priceEstimate: Double
    let status: BookingStatus
    let completedAt: String?

    var summary: ChatBookingSummary {
        ChatBookingSummary(
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            priceEstimate: priceEstimate,
            status: status,
            completedAt: completedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case scheduledStart = "scheduled_start"
        case scheduledEnd = "scheduled_end"
        case priceEstimate = "price_estimate"
        case status
        case completedAt = "completed_at"
    }
}

private struct ChatGroomerSummaryRow: Decodable {
    let userID: UUID
    let businessName: String?

    var normalizedBusinessName: String? {
        let trimmed = businessName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case businessName = "business_name"
    }
}

private struct ChatMessageRow: Decodable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let body: String
    let createdAt: String

    var message: ChatMessage {
        ChatMessage(
            id: id,
            conversationID: conversationID,
            senderID: senderID,
            body: body,
            createdAt: createdAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case body
        case createdAt = "created_at"
    }
}

private struct ChatMessageInsertRow: Encodable {
    let conversationID: UUID
    let senderID: UUID
    let body: String

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            conversationID.uuidString.lowercased(),
            forKey: .conversationID
        )
        try container.encode(senderID.uuidString.lowercased(), forKey: .senderID)
        try container.encode(body, forKey: .body)
    }

    private enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case body
    }
}
