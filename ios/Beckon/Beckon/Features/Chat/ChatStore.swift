import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    private let participantID: UUID
    private let role: UserRole
    private let repository: any ChatRepository
    private let bookingRepository: (any BookingRepository)?
    private let now: () -> Date
    private let readStateCache: any ChatReadStateCaching
    private var debugRecorder: AppDebugEventRecorder?

    private(set) var conversations: [ChatConversation] = []
    private(set) var messagesByConversationID: [UUID: [ChatMessage]] = [:]
    private(set) var bookingDetailStoresByID: [UUID: BookingsStore] = [:]
    private(set) var nextConversationPageRequest: ListPageRequest?
    private(set) var nextMessagePageRequestByConversationID: [UUID: ListPageRequest] = [:]
    private(set) var isLoadingConversations = false
    private(set) var isLoadingMoreConversations = false
    private(set) var loadingConversationIDs: Set<UUID> = []
    private(set) var loadingEarlierMessageConversationIDs: Set<UUID> = []
    private(set) var sendingConversationIDs: Set<UUID> = []
    private(set) var messageLoadErrors: [UUID: String] = [:]
    private(set) var interruptedMessageSubscriptions: Set<UUID> = []
    private var readConversationTimestamps: [UUID: String] = [:]
    private var messageSubscriptionTasks: [UUID: Task<Void, Never>] = [:]
    private var messageSubscriptionIDs: [UUID: UUID] = [:]

    var errorMessage: String?
    var noticeMessage: String?

    var isBusy: Bool {
        isLoadingConversations
            || isLoadingMoreConversations
            || !loadingConversationIDs.isEmpty
            || !loadingEarlierMessageConversationIDs.isEmpty
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
        bookingRepository: (any BookingRepository)? = nil,
        now: @escaping () -> Date = Date.init,
        readStateCache: any ChatReadStateCaching = UserDefaultsChatReadStateCache.shared,
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.participantID = participantID
        self.role = role
        self.repository = repository
        self.bookingRepository = bookingRepository
        self.now = now
        self.readStateCache = readStateCache
        self.debugRecorder = debugRecorder
        readConversationTimestamps = readStateCache.timestamps(
            participantID: participantID,
            role: role
        )
    }

    func setDebugRecorder(_ recorder: AppDebugEventRecorder?) {
        debugRecorder = recorder
    }

    func messages(for conversationID: UUID) -> [ChatMessage] {
        messagesByConversationID[conversationID] ?? []
    }

    func isLoadingMessages(for conversationID: UUID) -> Bool {
        loadingConversationIDs.contains(conversationID)
            || (messageSubscriptionIDs[conversationID] != nil && messageSubscriptionTasks[conversationID] == nil)
    }

    func isSendingMessage(for conversationID: UUID) -> Bool {
        sendingConversationIDs.contains(conversationID)
    }

    func isLoadingEarlierMessages(for conversationID: UUID) -> Bool {
        loadingEarlierMessageConversationIDs.contains(conversationID)
    }

    func canLoadMoreMessages(for conversationID: UUID) -> Bool {
        nextMessagePageRequestByConversationID[conversationID] != nil
    }

    func canSendMessages(in conversation: ChatConversation) -> Bool {
        conversation.canSendMessages(now: now())
    }

    func previewText(for conversation: ChatConversation) -> String {
        if let message = messagesByConversationID[conversation.id]?.last,
           Self.messageDate(message.createdAt) >= Self.messageDate(conversation.latestMessageCreatedAt ?? message.createdAt),
           let normalized = Self.normalizedPreview(message.body) {
            return normalized
        }

        if let normalized = Self.normalizedPreview(conversation.latestMessageBody) {
            return normalized
        }

        return "No Messages Yet"
    }

    func conversation(for booking: Booking) -> ChatConversation? {
        conversations.first {
            $0.customerID == booking.customerID
                && $0.groomerID == booking.groomerID
        }
    }

    func resolveConversation(conversationID: UUID) async -> ChatConversation? {
        do {
            let conversation = try await repository.conversation(id: conversationID, participantID: participantID, role: role)
            try Task.checkCancellation()
            guard conversation.id == conversationID,
                  (role == .customer ? conversation.customerID : conversation.groomerID) == participantID else {
                throw ChatRepositoryError.notAllowed
            }
            errorMessage = nil
            return conversation
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return nil
        } catch ChatRepositoryError.cancelled {
            return nil
        } catch ChatRepositoryError.conversationNotFound {
            errorMessage = "This conversation is no longer available to this account."
            return nil
        } catch ChatRepositoryError.notAllowed {
            errorMessage = "This conversation is no longer available to this account."
            return nil
        } catch {
            errorMessage = "The conversation could not be verified. Check your connection and try again."
            return nil
        }
    }

    func resolveConversation(bookingID: UUID) async -> ChatConversation? {
        guard let bookingRepository else {
            errorMessage = "Booking chat could not be verified. Try again."
            return nil
        }
        do {
            let bookings = try await bookingRepository.bookings(bookingIDs: [bookingID])
            guard bookings.count == 1, let booking = bookings.first, booking.id == bookingID,
                  (role == .customer ? booking.customerID : booking.groomerID) == participantID else {
                throw ChatRepositoryError.conversationNotFound
            }
            let conversation = try await repository.conversation(
                customerID: booking.customerID, groomerID: booking.groomerID, role: role
            )
            try Task.checkCancellation()
            guard conversation.customerID == booking.customerID,
                  conversation.groomerID == booking.groomerID else {
                throw ChatRepositoryError.notAllowed
            }
            errorMessage = nil
            return conversation
        } catch is CancellationError {
            return nil
        } catch ChatRepositoryError.cancelled {
            return nil
        } catch {
            errorMessage = "Booking chat could not be verified. Refresh to try again."
            return nil
        }
    }

    func bookingDetailStore(for message: ChatMessage) -> BookingsStore? {
        guard let bookingID = message.bookingID else { return nil }
        return bookingDetailStoresByID[bookingID]
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

        return Self.messageDate(latestMessageCreatedAt) > Self.messageDate(readAt)
    }

    func reportMissingConversationForBooking() {
        errorMessage = "Booking chat is not available yet."
    }

    func loadConversations() async {
        guard !isLoadingConversations, !isLoadingMoreConversations else { return }

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
              !isLoadingMoreConversations,
              let pageRequest = nextConversationPageRequest else { return }

        let startedAt = Date()
        recordStoreStart("loadNextConversationsPage")
        isLoadingMoreConversations = true
        errorMessage = nil
        defer { isLoadingMoreConversations = false }

        do {
            let page = try await repository.conversations(
                participantID: participantID,
                role: role,
                page: pageRequest
            )
            conversations = ListPageMerge.appendingUnique(
                page.items,
                to: conversations
            )
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
        guard !loadingConversationIDs.contains(conversation.id),
              !loadingEarlierMessageConversationIDs.contains(conversation.id) else { return }

        let startedAt = Date()
        recordStoreStart(
            "loadMessages",
            metadata: ["conversationID": conversation.id.uuidString]
        )
        loadingConversationIDs.insert(conversation.id)
        messageLoadErrors.removeValue(forKey: conversation.id)
        errorMessage = nil
        defer { loadingConversationIDs.remove(conversation.id) }

        do {
            let page = try await repository.messages(
                conversationID: conversation.id,
                page: .first
            )
            try Task.checkCancellation()
            // Messages are immutable; a refresh must retain sends/events received while it was in flight.
            messagesByConversationID[conversation.id] = Self.messagesInDisplayOrder(
                ListPageMerge.appendingUnique(messages(for: conversation.id), to: page.items)
            )
            reconcileBookingDetailStores(from: page.items)
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
            messageLoadErrors[conversation.id] = errorMessage
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
            messageLoadErrors[conversation.id] = errorMessage
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
              !loadingEarlierMessageConversationIDs.contains(conversation.id),
              let pageRequest = nextMessagePageRequestByConversationID[conversation.id] else { return }

        let startedAt = Date()
        recordStoreStart(
            "loadNextMessagesPage",
            metadata: ["conversationID": conversation.id.uuidString]
        )
        loadingEarlierMessageConversationIDs.insert(conversation.id)
        errorMessage = nil
        defer { loadingEarlierMessageConversationIDs.remove(conversation.id) }

        do {
            let page = try await repository.messages(
                conversationID: conversation.id,
                page: pageRequest
            )
            messagesByConversationID[conversation.id] = Self.messagesInDisplayOrder(
                ListPageMerge.appendingUnique(
                    page.items,
                    to: messagesByConversationID[conversation.id, default: []]
                )
            )
            reconcileBookingDetailStores(from: page.items)
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

    @discardableResult
    func sendMessage(
        in conversation: ChatConversation,
        body: String
    ) async -> Bool {
        guard !Task.isCancelled, !sendingConversationIDs.contains(conversation.id) else { return false }

        guard canSendMessages(in: conversation) else {
            errorMessage = conversation.readOnlyReason
            noticeMessage = nil
            return false
        }

        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBody.isEmpty else {
            errorMessage = "Enter a message before sending."
            return false
        }

        guard normalizedBody.count <= 4000 else {
            errorMessage = "Messages must be 4000 characters or fewer."
            return false
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
            return true
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
        return false
    }

    func startMessageSubscription(for conversation: ChatConversation) async {
        guard !Task.isCancelled, messageSubscriptionIDs[conversation.id] == nil else {
            return
        }

        let startedAt = Date()
        let metadata = ["conversationID": conversation.id.uuidString]
        recordStoreStart("startMessageSubscription", metadata: metadata)
        let subscriptionID = UUID()
        messageSubscriptionIDs[conversation.id] = subscriptionID
        defer {
            if messageSubscriptionIDs[conversation.id] == subscriptionID,
               messageSubscriptionTasks[conversation.id] == nil {
                messageSubscriptionIDs.removeValue(forKey: conversation.id)
            }
        }

        do {
            let stream = try await repository.messageEvents(
                conversationID: conversation.id
            )
            let task = Task { [weak self] in
                for await message in stream {
                    guard !Task.isCancelled,
                          self?.messageSubscriptionIDs[conversation.id] == subscriptionID else { break }
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
            guard !Task.isCancelled, messageSubscriptionIDs[conversation.id] == subscriptionID else {
                // Consume cancellation so AsyncStream's termination handler releases its network channel.
                task.cancel()
                await task.value
                return
            }
            messageSubscriptionTasks[conversation.id] = task
            interruptedMessageSubscriptions.remove(conversation.id)
            recordStoreSuccess(
                "startMessageSubscription",
                startedAt: startedAt,
                metadata: metadata
            )
        } catch ChatRepositoryError.cancelled {
            recordStoreCancelled("startMessageSubscription", startedAt: startedAt)
        } catch let error as ChatRepositoryError {
            if messageSubscriptionIDs[conversation.id] == subscriptionID {
                interruptedMessageSubscriptions.insert(conversation.id)
            }
            recordStoreFailure(
                "startMessageSubscription",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("startMessageSubscription", startedAt: startedAt)
        } catch {
            if messageSubscriptionIDs[conversation.id] == subscriptionID {
                interruptedMessageSubscriptions.insert(conversation.id)
            }
            recordStoreFailure(
                "startMessageSubscription",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt
            )
        }
    }

    func stopMessageSubscription(for conversationID: UUID) {
        messageSubscriptionIDs.removeValue(forKey: conversationID)
        messageSubscriptionTasks.removeValue(forKey: conversationID)?.cancel()
        recordStoreInfo(
            "stopMessageSubscription",
            message: "stopped",
            metadata: ["conversationID": conversationID.uuidString]
        )
    }

    func stopAllMessageSubscriptions() {
        let count = messageSubscriptionIDs.count
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
        messagesByConversationID[message.conversationID] = Self.messagesInDisplayOrder(
            messages
        )
        reconcileBookingDetailStores(from: [message])
    }

    private func reconcileBookingDetailStores(from messages: [ChatMessage]) {
        guard let bookingRepository else { return }

        for booking in messages.compactMap(\.booking) {
            if let store = bookingDetailStoresByID[booking.id] {
                store.synchronizeExternalBooking(booking)
            } else {
                bookingDetailStoresByID[booking.id] = BookingsStore(
                    participantID: participantID,
                    role: role,
                    repository: bookingRepository,
                    initialBookings: [booking],
                    debugRecorder: debugRecorder
                )
            }
        }
    }

    private static func messagesInDisplayOrder(
        _ messages: [ChatMessage]
    ) -> [ChatMessage] {
        messages.map { (message: $0, date: messageDate($0.createdAt)) }.sorted {
            if $0.date == $1.date {
                return $0.message.id.uuidString < $1.message.id.uuidString
            }
            return $0.date < $1.date
        }.map(\.message)
    }

    private static func messageDate(_ raw: String) -> Date {
        GroomingRequestDateFormatting.parsedDate(from: raw) ?? .distantPast
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
        interruptedMessageSubscriptions.insert(conversationID)
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
        // A summary can be newer than delivered history; it is not proof that its message was seen.
        guard let readAt = messagesByConversationID[conversationID]?.last?.createdAt else { return }
        if let previous = readConversationTimestamps[conversationID],
           Self.messageDate(previous) >= Self.messageDate(readAt) { return }

        readConversationTimestamps[conversationID] = readAt
        readStateCache.save(
            readConversationTimestamps,
            participantID: participantID,
            role: role
        )
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
