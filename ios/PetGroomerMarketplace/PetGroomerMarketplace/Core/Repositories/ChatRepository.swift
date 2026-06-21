import Foundation

enum ChatRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case conversationNotFound
    case invalidMessage
    case networkUnavailable
    case unavailable
}

@MainActor
protocol ChatRepository: AnyObject {
    func conversations(
        participantID: UUID,
        role: UserRole
    ) async throws -> [ChatConversation]

    func messages(
        conversationID: UUID
    ) async throws -> [ChatMessage]

    func sendMessage(
        conversationID: UUID,
        senderID: UUID,
        body: String
    ) async throws -> ChatMessage
}
