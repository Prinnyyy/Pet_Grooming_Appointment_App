import Foundation
import Supabase

@MainActor
final class SupabaseChatRepository: ChatRepository {
    private static let conversationColumns = """
        id,customer_id,groomer_id,created_at,updated_at
        """
    private static let groomerSummaryColumns = "user_id,business_name"
    private static let messageColumns =
        "id,conversation_id,sender_id,kind,body,booking_id,created_at"

    private let client: SupabaseClient
    private let participantAvatarLoader: SupabaseParticipantAvatarLoader
    private let bookingRepository: SupabaseBookingRepository

    init(
        client: SupabaseClient,
        privateImageLoader: (any PrivateImageLoading)? = nil
    ) {
        self.client = client
        participantAvatarLoader = SupabaseParticipantAvatarLoader(
            client: client,
            privateImageLoader: privateImageLoader
        )
        bookingRepository = SupabaseBookingRepository(
            client: client,
            privateImageLoader: privateImageLoader
        )
    }

    func conversations(
        participantID: UUID,
        role: UserRole
    ) async throws -> [ChatConversation] {
        try await conversations(
            participantID: participantID,
            role: role,
            page: .first
        ).items
    }

    func conversations(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<ChatConversation> {
        do {
            guard page.limit <= 100 else { throw ChatRepositoryError.unavailable }
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
                .order("updated_at", ascending: false)
                .order("id", ascending: false)
                .range(from: page.offset, to: page.inclusiveRangeEnd)
                .execute()
                .value

            let rowPage = ListPage(items: rows, request: page)
            return ListPage(items: try await hydrate(rowPage.items, role: role), request: page, hasMore: rowPage.hasMore)
        } catch {
            throw Self.map(error)
        }
    }

    func conversation(id: UUID, participantID: UUID, role: UserRole) async throws -> ChatConversation {
        do {
            let rows: [ChatConversationRow] = try await client.from("conversations")
                .select(Self.conversationColumns)
                .eq("id", value: id.uuidString.lowercased())
                .eq(role == .customer ? "customer_id" : "groomer_id", value: participantID.uuidString.lowercased())
                .limit(1).execute().value
            guard rows.count == 1, let row = rows.first, row.id == id,
                  (role == .customer ? row.customerID : row.groomerID) == participantID,
                  let result = try await hydrate(rows, role: role).first else {
                throw ChatRepositoryError.conversationNotFound
            }
            return result
        } catch { throw Self.map(error) }
    }

    func conversation(customerID: UUID, groomerID: UUID, role: UserRole) async throws -> ChatConversation {
        do {
            let rows: [ChatConversationRow] = try await client.from("conversations")
                .select(Self.conversationColumns)
                .eq("customer_id", value: customerID.uuidString.lowercased())
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .limit(1).execute().value
            guard rows.count == 1, let result = try await hydrate(rows, role: role).first else {
                throw ChatRepositoryError.conversationNotFound
            }
            return result
        } catch { throw Self.map(error) }
    }

    private func hydrate(_ rows: [ChatConversationRow], role: UserRole) async throws -> [ChatConversation] {
        guard !rows.isEmpty else { return [] }
        let summaries: [ChatConversationSummaryRow] = try await client.rpc(
            "get_conversation_summaries",
            params: ["p_conversation_ids": rows.map { $0.id.uuidString.lowercased() }]
        ).execute().value
        guard summaries.count == rows.count,
              Set(summaries.map(\.conversationID)) == Set(rows.map(\.id)) else {
            throw ChatRepositoryError.unavailable
        }
        let summariesByID = Dictionary(uniqueKeysWithValues: summaries.map { ($0.conversationID, $0) })
        let groomerBusinessNames = switch role {
        case .customer:
            await groomerBusinessNames(for: rows.map(\.groomerID))
        case .groomer:
            [UUID: String]()
        }
        let avatarTarget = ChatCounterpartAvatarTarget.viewer(role)
        let counterpartAvatars = await participantAvatarLoader.avatars(
            for: rows.map { row in
                avatarTarget.participantID(
                    customerID: row.customerID,
                    groomerID: row.groomerID
                )
            },
            role: avatarTarget.role
        )

        return rows.map { row in
            row.conversation(
                bookingSummary: summariesByID[row.id]?.bookingSummary?.summary,
                groomerBusinessName: groomerBusinessNames[row.groomerID],
                counterpartAvatarPhotoData: counterpartAvatars[
                    avatarTarget.participantID(
                        customerID: row.customerID,
                        groomerID: row.groomerID
                    )
                ],
                latestMessage: summariesByID[row.id]?.latestMessage
            )
        }
    }

    func messages(
        conversationID: UUID
    ) async throws -> [ChatMessage] {
        try await messages(
            conversationID: conversationID,
            page: .first
        ).items
    }

    func messages(
        conversationID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<ChatMessage> {
        do {
            let rows: [ChatMessageRow] = try await client
                .from("messages")
                .select(Self.messageColumns)
                .eq("conversation_id", value: conversationID.uuidString.lowercased())
                .order("created_at", ascending: false)
                .order("id", ascending: false)
                .range(from: page.offset, to: page.inclusiveRangeEnd)
                .execute()
                .value

            let bookingsByID = try await bookingsByID(
                for: rows.compactMap(\.bookingID)
            )
            return Self.messagePage(
                fromDescendingMessages: rows.map {
                    $0.message(booking: $0.bookingID.flatMap { bookingsByID[$0] })
                },
                request: page
            )
        } catch {
            throw Self.map(error)
        }
    }

    nonisolated static func messagePage(
        fromDescendingMessages messages: [ChatMessage],
        request: ListPageRequest
    ) -> ListPage<ChatMessage> {
        let descendingPage = ListPage(items: messages, request: request)
        return ListPage(
            items: Array(descendingPage.items.reversed()),
            request: request,
            hasMore: descendingPage.hasMore
        )
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

            guard rows.count == 1, let row = rows.first else {
                throw ChatRepositoryError.unavailable
            }

            return row.message(booking: nil)
        } catch let error as ChatRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func messageEvents(
        conversationID: UUID
    ) async throws -> AsyncStream<ChatMessage> {
        do {
            let normalizedConversationID = conversationID.uuidString.lowercased()
            let channel = client.channel("messages:\(normalizedConversationID)")
            let insertStream = channel.postgresChange(
                InsertAction.self,
                table: "messages",
                filter: .eq("conversation_id", value: normalizedConversationID)
            )

            try await channel.subscribeWithError()

            let client = self.client
            let bookingRepository = self.bookingRepository
            return AsyncStream { continuation in
                let task = Task {
                    for await action in insertStream {
                        guard !Task.isCancelled else { break }
                        if let row = try? action.decodeRecord(
                            as: ChatMessageRow.self,
                            decoder: JSONDecoder()
                        ) {
                            let booking: Booking?
                            if let bookingID = row.bookingID {
                                let bookings = try? await bookingRepository.bookings(
                                    bookingIDs: [bookingID]
                                )
                                booking = bookings?.first
                            } else {
                                booking = nil
                            }
                            continuation.yield(row.message(booking: booking))
                        }
                    }
                    continuation.finish()
                }

                continuation.onTermination = { _ in
                    task.cancel()
                    Task {
                        await client.removeChannel(channel)
                    }
                }
            }
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: any Error) -> ChatRepositoryError {
        if AppDebugErrorClassifier.isCancellation(error) {
            return .cancelled
        }

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

    private func bookingsByID(
        for bookingIDs: [UUID]
    ) async throws -> [UUID: Booking] {
        let bookings = try await bookingRepository.bookings(bookingIDs: bookingIDs)
        return Dictionary(uniqueKeysWithValues: bookings.map { ($0.id, $0) })
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

private struct ChatConversationSummaryRow: Decodable {
    let conversationID: UUID
    let latestMessage: ChatLatestMessageRow?
    let bookingSummary: ChatBookingSummaryRow?

    private enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case latestMessage = "latest_message"
        case bookingSummary = "booking_summary"
    }
}

private struct ChatConversationRow: Decodable {
    let id: UUID
    let customerID: UUID
    let groomerID: UUID
    let createdAt: String
    let updatedAt: String

    var participantPair: ChatParticipantPair {
        ChatParticipantPair(customerID: customerID, groomerID: groomerID)
    }

    func conversation(
        bookingSummary: ChatBookingSummary?,
        groomerBusinessName: String?,
        counterpartAvatarPhotoData: Data?,
        latestMessage: ChatLatestMessageRow?
    ) -> ChatConversation {
        ChatConversation(
            id: id,
            customerID: customerID,
            groomerID: groomerID,
            latestBookingID: bookingSummary?.id,
            latestRequestID: bookingSummary?.requestID,
            scheduledStart: bookingSummary?.scheduledStart,
            scheduledEnd: bookingSummary?.scheduledEnd,
            priceEstimate: bookingSummary?.priceEstimate,
            bookingStatus: bookingSummary?.status,
            completedAt: bookingSummary?.completedAt,
            groomerBusinessName: groomerBusinessName,
            counterpartAvatarPhotoData: counterpartAvatarPhotoData,
            latestMessageSenderID: latestMessage?.senderID,
            latestMessageCreatedAt: latestMessage?.createdAt,
            latestMessageBody: latestMessage?.body,
            createdAt: createdAt,
            updatedAt: updatedAt,
            serviceTimeZoneIdentifier: bookingSummary?.serviceTimeZoneIdentifier
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case customerID = "customer_id"
        case groomerID = "groomer_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct ChatBookingSummary: Sendable {
    let id: UUID
    let requestID: UUID
    let scheduledStart: String
    let scheduledEnd: String
    let priceEstimate: Double
    let status: BookingStatus
    let completedAt: String?
    let serviceTimeZoneIdentifier: String?
}

private struct ChatBookingSummaryRow: Decodable {
    let id: UUID
    let requestID: UUID
    let customerID: UUID
    let groomerID: UUID
    let scheduledStart: String
    let scheduledEnd: String
    let priceEstimate: Double
    let status: BookingStatus
    let completedAt: String?
    let serviceTimeZoneIdentifier: String?

    var participantPair: ChatParticipantPair {
        ChatParticipantPair(customerID: customerID, groomerID: groomerID)
    }

    var summary: ChatBookingSummary {
        ChatBookingSummary(
            id: id,
            requestID: requestID,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            priceEstimate: priceEstimate,
            status: status,
            completedAt: completedAt,
            serviceTimeZoneIdentifier: serviceTimeZoneIdentifier
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requestID = "request_id"
        case customerID = "customer_id"
        case groomerID = "groomer_id"
        case scheduledStart = "scheduled_start"
        case scheduledEnd = "scheduled_end"
        case priceEstimate = "price_estimate"
        case status
        case completedAt = "completed_at"
        case serviceTimeZoneIdentifier = "service_time_zone_identifier"
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

private struct ChatLatestMessageRow: Decodable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let kind: ChatMessageKind
    let body: String?
    let bookingID: UUID?
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case kind
        case body
        case bookingID = "booking_id"
        case createdAt = "created_at"
    }
}

private struct ChatMessageRow: Decodable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let kind: ChatMessageKind
    let body: String?
    let bookingID: UUID?
    let createdAt: String

    func message(booking: Booking?) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationID: conversationID,
            senderID: senderID,
            kind: kind,
            body: body,
            booking: booking,
            createdAt: createdAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case kind
        case body
        case bookingID = "booking_id"
        case createdAt = "created_at"
    }
}

private struct ChatParticipantPair: Hashable, Sendable {
    let customerID: UUID
    let groomerID: UUID
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
