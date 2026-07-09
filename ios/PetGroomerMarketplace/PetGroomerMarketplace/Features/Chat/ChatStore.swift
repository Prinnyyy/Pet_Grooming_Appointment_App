import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    private let participantID: UUID
    private let role: UserRole
    private let repository: any ChatRepository
    private let now: () -> Date
    private let debugRecorder: AppDebugEventRecorder?

    private(set) var conversations: [ChatConversation] = []
    private(set) var messagesByConversationID: [UUID: [ChatMessage]] = [:]
    private(set) var nextConversationPageRequest: ListPageRequest?
    private(set) var nextMessagePageRequestByConversationID: [UUID: ListPageRequest] = [:]
    private(set) var isLoadingConversations = false
    private(set) var loadingConversationIDs: Set<UUID> = []
    private(set) var sendingConversationIDs: Set<UUID> = []
    private var readConversationTimestamps: [UUID: String] = [:]
    private var messageSubscriptionTasks: [UUID: Task<Void, Never>] = [:]
    private var messageSubscriptionIDs: [UUID: UUID] = [:]
    private var startingMessageSubscriptionIDs: Set<UUID> = []

    var errorMessage: String?
    var noticeMessage: String?

    var isBusy: Bool {
        isLoadingConversations
            || !loadingConversationIDs.isEmpty
            || !sendingConversationIDs.isEmpty
    }

    var unreadConversationCount: Int {
        conversations.filter(hasUnreadMessages).count
    }

    var canLoadMoreConversations: Bool {
        nextConversationPageRequest != nil
    }

    init(
        participantID: UUID,
        role: UserRole,
        repository: any ChatRepository,
        now: @escaping () -> Date = Date.init,
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.participantID = participantID
        self.role = role
        self.repository = repository
        self.now = now
        self.debugRecorder = debugRecorder
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

    func canLoadMoreMessages(for conversationID: UUID) -> Bool {
        nextMessagePageRequestByConversationID[conversationID] != nil
    }

    func canSendMessages(in conversation: ChatConversation) -> Bool {
        conversation.canSendMessages(now: now())
    }

    func previewText(for conversation: ChatConversation) -> String {
        if let body = messagesByConversationID[conversation.id]?.last?.body,
           let normalized = Self.normalizedPreview(body) {
            return normalized
        }

        if let normalized = Self.normalizedPreview(conversation.latestMessageBody) {
            return normalized
        }

        return "No Messages Yet"
    }

    func conversation(forBookingID bookingID: UUID) -> ChatConversation? {
        conversations.first { $0.bookingID == bookingID }
    }

    func hasUnreadMessages(in conversation: ChatConversation) -> Bool {
        guard let latestMessageSenderID = conversation.latestMessageSenderID,
              latestMessageSenderID != participantID,
              let latestMessageCreatedAt = conversation.latestMessageCreatedAt else {
            return false
        }

        guard let readAt = readConversationTimestamps[conversation.id] else {
            return true
        }

        return latestMessageCreatedAt > readAt
    }

    func reportMissingConversationForBooking() {
        errorMessage = "Booking chat is not available yet."
    }

    func loadConversations() async {
        let startedAt = Date()
        recordStoreStart("loadConversations")
        isLoadingConversations = true
        errorMessage = nil
        defer { isLoadingConversations = false }

        do {
            let page = try await repository.conversations(
                participantID: participantID,
                role: role,
                page: .first
            )
            conversations = page.items
            nextConversationPageRequest = page.nextRequest
            recordStoreSuccess(
                "loadConversations",
                startedAt: startedAt,
                metadata: [
                    "conversationCount": "\(conversations.count)",
                    "hasMore": "\(canLoadMoreConversations)",
                ]
            )
        } catch ChatRepositoryError.cancelled {
            recordStoreCancelled("loadConversations", startedAt: startedAt)
        } catch let error as ChatRepositoryError {
            errorMessage = message(for: error, action: "load conversations")
            recordStoreFailure(
                "loadConversations",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("loadConversations", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "load conversations")
            recordStoreFailure(
                "loadConversations",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func loadNextConversationsPage() async {
        guard !isLoadingConversations,
              let pageRequest = nextConversationPageRequest else { return }

        let startedAt = Date()
        recordStoreStart("loadNextConversationsPage")
        isLoadingConversations = true
        errorMessage = nil
        defer { isLoadingConversations = false }

        do {
            let page = try await repository.conversations(
                participantID: participantID,
                role: role,
                page: pageRequest
            )
            conversations.append(contentsOf: page.items)
            nextConversationPageRequest = page.nextRequest
            recordStoreSuccess(
                "loadNextConversationsPage",
                startedAt: startedAt,
                metadata: [
                    "conversationCount": "\(conversations.count)",
                    "loadedCount": "\(page.items.count)",
                    "hasMore": "\(canLoadMoreConversations)",
                ]
            )
        } catch ChatRepositoryError.cancelled {
            recordStoreCancelled("loadNextConversationsPage", startedAt: startedAt)
        } catch let error as ChatRepositoryError {
            errorMessage = message(for: error, action: "load conversations")
            recordStoreFailure(
                "loadNextConversationsPage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("loadNextConversationsPage", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "load conversations")
            recordStoreFailure(
                "loadNextConversationsPage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func loadMessages(for conversation: ChatConversation) async {
        guard !loadingConversationIDs.contains(conversation.id) else { return }

        let startedAt = Date()
        recordStoreStart(
            "loadMessages",
            metadata: ["conversationID": conversation.id.uuidString]
        )
        loadingConversationIDs.insert(conversation.id)
        errorMessage = nil
        defer { loadingConversationIDs.remove(conversation.id) }

        do {
            let page = try await repository.messages(
                conversationID: conversation.id,
                page: .first
            )
            messagesByConversationID[conversation.id] = page.items
            nextMessagePageRequestByConversationID[conversation.id] = page.nextRequest
            markConversationRead(conversation.id)
            recordStoreSuccess(
                "loadMessages",
                startedAt: startedAt,
                metadata: [
                    "conversationID": conversation.id.uuidString,
                    "messageCount": "\(messagesByConversationID[conversation.id]?.count ?? 0)",
                    "hasMore": "\(canLoadMoreMessages(for: conversation.id))",
                ]
            )
        } catch ChatRepositoryError.cancelled {
            recordStoreCancelled("loadMessages", startedAt: startedAt)
        } catch let error as ChatRepositoryError {
            errorMessage = message(for: error, action: "load messages")
            recordStoreFailure(
                "loadMessages",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("loadMessages", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "load messages")
            recordStoreFailure(
                "loadMessages",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func loadNextMessagesPage(for conversation: ChatConversation) async {
        guard !loadingConversationIDs.contains(conversation.id),
              let pageRequest = nextMessagePageRequestByConversationID[conversation.id] else { return }

        let startedAt = Date()
        recordStoreStart(
            "loadNextMessagesPage",
            metadata: ["conversationID": conversation.id.uuidString]
        )
        loadingConversationIDs.insert(conversation.id)
        errorMessage = nil
        defer { loadingConversationIDs.remove(conversation.id) }

        do {
            let page = try await repository.messages(
                conversationID: conversation.id,
                page: pageRequest
            )
            messagesByConversationID[conversation.id, default: []].append(contentsOf: page.items)
            nextMessagePageRequestByConversationID[conversation.id] = page.nextRequest
            markConversationRead(conversation.id)
            recordStoreSuccess(
                "loadNextMessagesPage",
                startedAt: startedAt,
                metadata: [
                    "conversationID": conversation.id.uuidString,
                    "messageCount": "\(messagesByConversationID[conversation.id]?.count ?? 0)",
                    "loadedCount": "\(page.items.count)",
                    "hasMore": "\(canLoadMoreMessages(for: conversation.id))",
                ]
            )
        } catch ChatRepositoryError.cancelled {
            recordStoreCancelled("loadNextMessagesPage", startedAt: startedAt)
        } catch let error as ChatRepositoryError {
            errorMessage = message(for: error, action: "load messages")
            recordStoreFailure(
                "loadNextMessagesPage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("loadNextMessagesPage", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "load messages")
            recordStoreFailure(
                "loadNextMessagesPage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func sendMessage(
        in conversation: ChatConversation,
        body: String
    ) async {
        guard !sendingConversationIDs.contains(conversation.id) else { return }

        guard canSendMessages(in: conversation) else {
            errorMessage = conversation.readOnlyReason
            noticeMessage = nil
            return
        }

        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBody.isEmpty else {
            errorMessage = "Enter a message before sending."
            return
        }

        guard normalizedBody.count <= 4000 else {
            errorMessage = "Messages must be 4000 characters or fewer."
            return
        }

        let startedAt = Date()
        recordStoreStart(
            "sendMessage",
            metadata: ["conversationID": conversation.id.uuidString]
        )
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
            markConversationRead(conversation.id)
            recordStoreSuccess(
                "sendMessage",
                startedAt: startedAt,
                metadata: ["conversationID": conversation.id.uuidString]
            )
        } catch ChatRepositoryError.cancelled {
            recordStoreCancelled("sendMessage", startedAt: startedAt)
        } catch let error as ChatRepositoryError {
            errorMessage = self.message(for: error, action: "send message")
            recordStoreFailure(
                "sendMessage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("sendMessage", startedAt: startedAt)
        } catch {
            errorMessage = self.message(for: .unavailable, action: "send message")
            recordStoreFailure(
                "sendMessage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func startMessageSubscription(for conversation: ChatConversation) async {
        guard messageSubscriptionTasks[conversation.id] == nil,
              !startingMessageSubscriptionIDs.contains(conversation.id) else {
            return
        }

        let startedAt = Date()
        let metadata = ["conversationID": conversation.id.uuidString]
        recordStoreStart("startMessageSubscription", metadata: metadata)
        startingMessageSubscriptionIDs.insert(conversation.id)
        defer { startingMessageSubscriptionIDs.remove(conversation.id) }

        do {
            let stream = try await repository.messageEvents(
                conversationID: conversation.id
            )
            let subscriptionID = UUID()
            messageSubscriptionIDs[conversation.id] = subscriptionID
            messageSubscriptionTasks[conversation.id] = Task { [weak self] in
                for await message in stream {
                    guard !Task.isCancelled else { break }
                    self?.receiveMessageEvent(
                        message,
                        expectedConversationID: conversation.id
                    )
                }
                self?.finishMessageSubscription(
                    conversationID: conversation.id,
                    subscriptionID: subscriptionID
                )
            }
            recordStoreSuccess(
                "startMessageSubscription",
                startedAt: startedAt,
                metadata: metadata
            )
        } catch ChatRepositoryError.cancelled {
            recordStoreCancelled("startMessageSubscription", startedAt: startedAt)
        } catch let error as ChatRepositoryError {
            recordStoreFailure(
                "startMessageSubscription",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("startMessageSubscription", startedAt: startedAt)
        } catch {
            recordStoreFailure(
                "startMessageSubscription",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt
            )
        }
    }

    func stopMessageSubscription(for conversationID: UUID) {
        guard let task = messageSubscriptionTasks.removeValue(forKey: conversationID) else {
            return
        }
        messageSubscriptionIDs.removeValue(forKey: conversationID)
        task.cancel()
        recordStoreInfo(
            "stopMessageSubscription",
            message: "stopped",
            metadata: ["conversationID": conversationID.uuidString]
        )
    }

    func stopAllMessageSubscriptions() {
        guard !messageSubscriptionTasks.isEmpty else { return }
        let count = messageSubscriptionTasks.count
        for task in messageSubscriptionTasks.values {
            task.cancel()
        }
        messageSubscriptionTasks.removeAll()
        messageSubscriptionIDs.removeAll()
        recordStoreInfo(
            "stopAllMessageSubscriptions",
            message: "stopped",
            metadata: ["subscriptionCount": "\(count)"]
        )
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

    private func receiveMessageEvent(
        _ message: ChatMessage,
        expectedConversationID: UUID
    ) {
        guard message.conversationID == expectedConversationID else { return }
        let previousCount = messagesByConversationID[message.conversationID]?.count ?? 0
        append(message)
        markConversationRead(message.conversationID)
        let currentCount = messagesByConversationID[message.conversationID]?.count ?? 0
        recordStoreInfo(
            "messageEvent",
            message: currentCount == previousCount ? "duplicate ignored" : "received",
            metadata: [
                "conversationID": message.conversationID.uuidString,
                "messageID": message.id.uuidString,
            ]
        )
    }

    private func finishMessageSubscription(
        conversationID: UUID,
        subscriptionID: UUID
    ) {
        guard messageSubscriptionIDs[conversationID] == subscriptionID else {
            return
        }
        messageSubscriptionIDs.removeValue(forKey: conversationID)
        messageSubscriptionTasks.removeValue(forKey: conversationID)
        recordStoreInfo(
            "messageSubscriptionFinished",
            message: "finished",
            metadata: ["conversationID": conversationID.uuidString]
        )
    }

    private static func normalizedPreview(_ value: String?) -> String? {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func markConversationRead(_ conversationID: UUID) {
        let loadedLatest = messagesByConversationID[conversationID]?.last?.createdAt
        let conversationLatest = conversations.first {
            $0.id == conversationID
        }?.latestMessageCreatedAt

        let readAt: String?
        switch (loadedLatest, conversationLatest) {
        case let (loaded?, conversation?):
            readAt = max(loaded, conversation)
        case let (loaded?, nil):
            readAt = loaded
        case let (nil, conversation?):
            readAt = conversation
        case (nil, nil):
            readAt = nil
        }

        guard let readAt else {
            return
        }

        readConversationTimestamps[conversationID] = readAt
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
        case .cancelled:
            "The message action was cancelled."
        case .unavailable:
            "We could not \(action). Please try again."
        }
    }

    private var debugScope: String {
        "\(role.appDebugScopePrefix).messages"
    }

    private func recordStoreStart(
        _ operation: String,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        eventMetadata["participantID"] = participantID.uuidString
        eventMetadata["role"] = role.appDebugName
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "ChatStore.\(operation)",
            scope: debugScope,
            message: "start",
            metadata: eventMetadata
        )
    }

    private func recordStoreSuccess(
        _ operation: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "ChatStore.\(operation)",
            scope: debugScope,
            message: "success",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

    private func recordStoreFailure(
        _ operation: String,
        error: any Error,
        mappedMessage: String?,
        startedAt: Date
    ) {
        debugRecorder?.record(
            level: .error,
            category: .store,
            source: "ChatStore.\(operation)",
            scope: debugScope,
            message: mappedMessage ?? "failure",
            underlyingError: error,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation]
        )
    }

    private func recordStoreInfo(
        _ operation: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "ChatStore.\(operation)",
            scope: debugScope,
            message: message,
            metadata: eventMetadata
        )
    }

    private func recordStoreCancelled(
        _ operation: String,
        startedAt: Date
    ) {
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "ChatStore.\(operation)",
            scope: debugScope,
            message: "cancelled ignored",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation]
        )
    }
}
