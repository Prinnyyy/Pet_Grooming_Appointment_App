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
