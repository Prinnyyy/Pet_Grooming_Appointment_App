import Foundation

enum ChatRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case conversationNotFound
    case invalidMessage
    case networkUnavailable
    case cancelled
    case unavailable
}

@MainActor
protocol ChatRepository: AnyObject {
    func requestContact(requestID: UUID, groomerID: UUID) async throws -> RequestChatContact
    func openRequestConversation(requestID: UUID, groomerID: UUID) async throws -> UUID

    func sendMessage(messageID: UUID, conversationID: UUID, senderID: UUID, body: String) async throws -> ChatMessage

    func conversation(id: UUID, participantID: UUID, role: UserRole) async throws -> ChatConversation
    func conversation(customerID: UUID, groomerID: UUID, role: UserRole) async throws -> ChatConversation

    func conversations(
        participantID: UUID,
        role: UserRole
    ) async throws -> [ChatConversation]

    func conversations(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<ChatConversation>

    func messages(
        conversationID: UUID
    ) async throws -> [ChatMessage]

    func messages(
        conversationID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<ChatMessage>

    func sendMessage(
        conversationID: UUID,
        senderID: UUID,
        body: String
    ) async throws -> ChatMessage

    func messageEvents(
        conversationID: UUID
    ) async throws -> AsyncStream<ChatMessage>
}

extension ChatRepository {
    func requestContact(requestID: UUID, groomerID: UUID) async throws -> RequestChatContact { throw ChatRepositoryError.unavailable }
    func openRequestConversation(requestID: UUID, groomerID: UUID) async throws -> UUID { throw ChatRepositoryError.unavailable }

    // An older repository must not silently retry with a different server identity.
    func sendMessage(messageID: UUID, conversationID: UUID, senderID: UUID, body: String) async throws -> ChatMessage {
        throw ChatRepositoryError.unavailable
    }

    func conversation(id: UUID, participantID: UUID, role: UserRole) async throws -> ChatConversation {
        throw ChatRepositoryError.unavailable
    }

    func conversation(customerID: UUID, groomerID: UUID, role: UserRole) async throws -> ChatConversation {
        throw ChatRepositoryError.unavailable
    }

    func conversations(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<ChatConversation> {
        ListPage(
            items: try await conversations(
                participantID: participantID,
                role: role
            ),
            request: page,
            hasMore: false
        )
    }

    func firstConversationPage(
        participantID: UUID,
        role: UserRole
    ) async throws -> ListPage<ChatConversation> {
        try await conversations(
            participantID: participantID,
            role: role,
            page: .first
        )
    }

    func messages(
        conversationID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<ChatMessage> {
        ListPage(
            items: try await messages(conversationID: conversationID),
            request: page,
            hasMore: false
        )
    }
}

nonisolated struct RequestChatContact: Decodable, Sendable {
    let canMessage: Bool
    let displayName: String?
    let conversationID: UUID?
    private enum CodingKeys: String, CodingKey {
        case canMessage = "can_message", displayName = "display_name", conversationID = "conversation_id"
    }
}
