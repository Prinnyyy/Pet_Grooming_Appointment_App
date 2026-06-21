import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    private let participantID: UUID
    private let role: UserRole
    private let repository: any ChatRepository

    private(set) var conversations: [ChatConversation] = []
    private(set) var messagesByConversationID: [UUID: [ChatMessage]] = [:]
    private(set) var isLoadingConversations = false
    private(set) var loadingConversationIDs: Set<UUID> = []
    private(set) var sendingConversationIDs: Set<UUID> = []

    var errorMessage: String?
    var noticeMessage: String?

    var isBusy: Bool {
        isLoadingConversations
            || !loadingConversationIDs.isEmpty
            || !sendingConversationIDs.isEmpty
    }

    init(
        participantID: UUID,
        role: UserRole,
        repository: any ChatRepository
    ) {
        self.participantID = participantID
        self.role = role
        self.repository = repository
    }

    func messages(for conversationID: UUID) -> [ChatMessage] {
        messagesByConversationID[conversationID] ?? []
    }

    func isLoadingMessages(for conversationID: UUID) -> Bool {
        loadingConversationIDs.contains(conversationID)
    }

    func isSendingMessage(for conversationID: UUID) -> Bool {
        sendingConversationIDs.contains(conversationID)
    }

    func loadConversations() async {
        isLoadingConversations = true
        errorMessage = nil
        defer { isLoadingConversations = false }

        do {
            conversations = try await repository.conversations(
                participantID: participantID,
                role: role
            )
        } catch let error as ChatRepositoryError {
            errorMessage = message(for: error, action: "load conversations")
        } catch {
            errorMessage = message(for: .unavailable, action: "load conversations")
        }
    }

    func loadMessages(for conversation: ChatConversation) async {
        guard !loadingConversationIDs.contains(conversation.id) else { return }

        loadingConversationIDs.insert(conversation.id)
        errorMessage = nil
        defer { loadingConversationIDs.remove(conversation.id) }

        do {
            messagesByConversationID[conversation.id] =
                try await repository.messages(conversationID: conversation.id)
        } catch let error as ChatRepositoryError {
            errorMessage = message(for: error, action: "load messages")
        } catch {
            errorMessage = message(for: .unavailable, action: "load messages")
        }
    }

    func sendMessage(
        in conversation: ChatConversation,
        body: String
    ) async {
        guard !sendingConversationIDs.contains(conversation.id) else { return }

        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBody.isEmpty else {
            errorMessage = "Enter a message before sending."
            return
        }

        guard normalizedBody.count <= 4000 else {
            errorMessage = "Messages must be 4000 characters or fewer."
            return
        }

        sendingConversationIDs.insert(conversation.id)
        errorMessage = nil
        noticeMessage = nil
        defer { sendingConversationIDs.remove(conversation.id) }

        do {
            let message = try await repository.sendMessage(
                conversationID: conversation.id,
                senderID: participantID,
                body: normalizedBody
            )
            append(message)
            noticeMessage = "Message sent."
        } catch let error as ChatRepositoryError {
            errorMessage = self.message(for: error, action: "send message")
        } catch {
            errorMessage = self.message(for: .unavailable, action: "send message")
        }
    }

    private func append(_ message: ChatMessage) {
        var messages = messagesByConversationID[message.conversationID] ?? []
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        messages.sort {
            if $0.createdAt == $1.createdAt {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.createdAt < $1.createdAt
        }
        messagesByConversationID[message.conversationID] = messages
    }

    private func message(
        for error: ChatRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) for this conversation."
        case .conversationNotFound:
            "This conversation is no longer available."
        case .invalidMessage:
            "Check the message and try again."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not \(action). Please try again."
        }
    }
}
