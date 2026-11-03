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
    private let displayCache: FileChatDisplayCache?
    private let displayCacheGeneration: Int
    private var unverifiedCachedConversations: Set<UUID> = []
    private var revokedConversationIDs: Set<UUID> = []
    private var resolvedConversationByBookingID: [UUID: UUID] = [:]
    private let readStateCache: any ChatReadStateCaching
    private var debugRecorder: AppDebugEventRecorder?

    private(set) var outgoingMessages: [ChatOutgoingMessage] = []
    private var localEchoDates: [UUID: Date] = [:]
    @ObservationIgnored private var outgoingWorkers: [UUID: (token: UUID, task: Task<Void, Never>)] = [:]
    private var legacyOutgoingIDs: Set<UUID> = []
    private(set) var conversations: [ChatConversation] = []
    private(set) var messagesByConversationID: [UUID: [ChatMessage]] = [:]
    private(set) var bookingDetailStoresByID: [UUID: BookingsStore] = [:]
    private(set) var nextConversationPageRequest: ListPageRequest?
    private(set) var nextMessagePageRequestByConversationID: [UUID: ListPageRequest] = [:]
    private(set) var isLoadingConversations = false
    private(set) var hasLoadedOnce = false
    private(set) var isLoadingMoreConversations = false
    private(set) var loadingConversationIDs: Set<UUID> = []
    private(set) var loadingEarlierMessageConversationIDs: Set<UUID> = []
    private(set) var sendingConversationIDs: Set<UUID> = []
    private(set) var messageLoadErrors: [UUID: String] = [:]
    private(set) var interruptedMessageSubscriptions: Set<UUID> = []
    private var readConversationTimestamps: [UUID: String] = [:]
    private var messageSubscriptionTasks: [UUID: Task<Void, Never>] = [:]
    private var messageSubscriptionIDs: [UUID: UUID] = [:]
    private var deferredReadConversationIDs: Set<UUID> = []
    #if DEBUG
    var sandboxBookingStore: BookingsStore?
    #endif

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
        debugRecorder: AppDebugEventRecorder? = nil,
        displayCache: FileChatDisplayCache? = nil
    ) {
        self.displayCache = displayCache
        displayCacheGeneration = displayCache?.generation ?? 0
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
        if let snapshot = displayCache?.snapshot(participantID: participantID, role: role) {
            conversations = snapshot.conversations
            messagesByConversationID = snapshot.messages
            resolvedConversationByBookingID = snapshot.bookingConversations
            localEchoDates = snapshot.localEchoDates
            outgoingMessages = snapshot.outgoingMessages.map { item in
                var restored = item
                if restored.failureMessage == nil { restored.failureMessage = "Sending was interrupted. Tap Retry to confirm or send." }
                return restored
            }
            unverifiedCachedConversations = Set(conversations.map(\.id))
            hasLoadedOnce = true // Display readiness only; restored metadata never authorizes sending.
        }
    }

    private func persistDisplay() {
        displayCache?.save(participantID: participantID, role: role, conversations: conversations,
            messages: messagesByConversationID, generation: displayCacheGeneration,
            bookingConversations: resolvedConversationByBookingID,
            outgoingMessages: outgoingMessages, localEchoDates: localEchoDates)
    }

    private func rememberConversation(_ conversation: ChatConversation) {
        guard (role == .customer ? conversation.customerID : conversation.groomerID) == participantID else { return }
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) { conversations[index] = conversation }
        else { conversations.append(conversation) }
        unverifiedCachedConversations.remove(conversation.id)
        revokedConversationIDs.remove(conversation.id)
    }

    func cachedConversation(bookingID: UUID) -> ChatConversation? {
        if let id = resolvedConversationByBookingID[bookingID], let conversation = conversations.first(where: { $0.id == id }) {
            return conversation
        }
        return conversations.first { conversation in
            conversation.latestBookingID == bookingID
                || messages(for: conversation.id).contains { $0.bookingID == bookingID }
        }
    }

    private var displaySessionIsCurrent: Bool {
        displayCache.map { $0.generation == displayCacheGeneration } ?? true
    }

    func isVerifyingCachedConversation(_ id: UUID) -> Bool { unverifiedCachedConversations.contains(id) }

    private func revokeConversation(_ id: UUID) {
        stopMessageSubscription(for: id)
        revokedConversationIDs.insert(id)
        outgoingWorkers.removeValue(forKey: id)?.task.cancel()
        outgoingMessages.removeAll { $0.conversationID == id }
        resolvedConversationByBookingID = resolvedConversationByBookingID.filter { $0.value != id }
        conversations.removeAll { $0.id == id }
        messagesByConversationID[id] = nil
        unverifiedCachedConversations.insert(id)
        persistDisplay()
    }

    func setDebugRecorder(_ recorder: AppDebugEventRecorder?) {
        debugRecorder = recorder
    }

    func displayMessages(for conversationID: UUID) -> [ChatMessage] {
        let confirmed = ChatLegacyBookingMessages.present(messages(for: conversationID))
        let ids = Set(confirmed.map(\.id))
        let pending = outgoingMessages.filter { $0.conversationID == conversationID && !ids.contains($0.id) }.map(\.message)
        return (confirmed + pending).enumerated().sorted { lhs, rhs in
            let left = localEchoDates[lhs.element.id] ?? Self.messageDate(lhs.element.createdAt)
            let right = localEchoDates[rhs.element.id] ?? Self.messageDate(rhs.element.createdAt)
            return left == right ? lhs.offset < rhs.offset : left < right
        }.map(\.element)
    }

    func outgoingMessage(id: UUID) -> ChatOutgoingMessage? { outgoingMessages.first { $0.id == id } }

    func messages(for conversationID: UUID) -> [ChatMessage] {
        messagesByConversationID[conversationID] ?? []
    }

    func isLoadingMessages(for conversationID: UUID) -> Bool {
        loadingConversationIDs.contains(conversationID)
            || (messageSubscriptionIDs[conversationID] != nil && messageSubscriptionTasks[conversationID] == nil)
    }

    /// A successful empty snapshot is content too; refreshing it must not restore a loader.
    func hasLoadedMessages(for conversationID: UUID) -> Bool {
        messagesByConversationID[conversationID] != nil
    }

    func hasActiveMessageSubscription(for conversationID: UUID) -> Bool {
        messageSubscriptionTasks[conversationID] != nil
    }

    func deferReadAcknowledgement(for conversationID: UUID) {
        deferredReadConversationIDs.insert(conversationID)
    }

    func acknowledgeVisibleMessages(for conversationID: UUID) {
        deferredReadConversationIDs.remove(conversationID)
        markConversationRead(conversationID)
    }

    /// Do not hold history behind a slow realtime handshake. Catch up once connected so
    /// messages sent between the first snapshot and subscription cannot fall into a gap.
    func prepareMessages(for conversation: ChatConversation) async {
        if unverifiedCachedConversations.contains(conversation.id) {
            guard await resolveConversation(conversationID: conversation.id) != nil else {
                messageLoadErrors[conversation.id] = errorMessage
                return
            }
        }
        async let subscription: Void = startMessageSubscription(for: conversation)
        await Task.yield()
        let snapshotHasSubscription = hasActiveMessageSubscription(for: conversation.id)
        await loadMessages(for: conversation)
        await subscription
        guard !Task.isCancelled else { return }
        if !snapshotHasSubscription, hasActiveMessageSubscription(for: conversation.id) {
            await loadMessages(for: conversation)
        }
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
        guard displaySessionIsCurrent, !unverifiedCachedConversations.contains(conversation.id) else { return false }
        return (conversations.first { $0.id == conversation.id } ?? conversation).canSendMessages(now: now())
    }

    func previewText(for conversation: ChatConversation) -> String {
        if let latest = messagesByConversationID[conversation.id]?.last, latest.kind == .bookingCard {
            return latest.bookingEvent?.title ?? "Booking update"
        }
        if let message = messagesByConversationID[conversation.id]?.last,
           Self.messageDate(message.createdAt) >= Self.messageDate(conversation.latestMessageCreatedAt ?? message.createdAt),
           let normalized = Self.normalizedPreview(message.body) {
            return normalized
        }

        if let normalized = Self.normalizedPreview(conversation.latestMessageBody) {
            return normalized
        }

        return "No messages yet"
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
            guard displaySessionIsCurrent else { return nil }
            rememberConversation(conversation)
            persistDisplay()
            errorMessage = nil
            return conversation
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return nil
        } catch ChatRepositoryError.cancelled {
            return nil
        } catch ChatRepositoryError.conversationNotFound {
            revokeConversation(conversationID)
            errorMessage = "This conversation is no longer available to this account."
            return nil
        } catch ChatRepositoryError.notAllowed {
            revokeConversation(conversationID)
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
            guard displaySessionIsCurrent else { return nil }
            rememberConversation(conversation)
            resolvedConversationByBookingID[bookingID] = conversation.id
            persistDisplay()
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
        guard !Task.isCancelled, !isLoadingConversations, !isLoadingMoreConversations else { return }

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
            try Task.checkCancellation()
            guard displaySessionIsCurrent else { return }
            hasLoadedOnce = true
            let queuedIDs = Set(outgoingMessages.map(\.conversationID))
            let queuedConversations = conversations.filter { queuedIDs.contains($0.id) }
            conversations = ListPageMerge.appendingUnique(queuedConversations, to: page.items)
            for conversation in page.items {
                unverifiedCachedConversations.remove(conversation.id)
                revokedConversationIDs.remove(conversation.id)
            }
            persistDisplay()
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
            guard !Task.isCancelled else { return }
            hasLoadedOnce = true
            if error == .notAllowed {
                let ids = Set(conversations.map(\.id)).union(messagesByConversationID.keys)
                revokedConversationIDs.formUnion(ids)
                unverifiedCachedConversations.formUnion(ids)
                stopAllMessageSubscriptions()
                conversations = []; messagesByConversationID = [:]; bookingDetailStoresByID = [:]
                outgoingWorkers.values.forEach { $0.task.cancel() }; outgoingWorkers = [:]
                outgoingMessages = []; localEchoDates = [:]
                persistDisplay()
            }
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
            guard !Task.isCancelled else { return }
            hasLoadedOnce = true
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
            guard displaySessionIsCurrent, !revokedConversationIDs.contains(conversation.id) else { return }
            // Messages are immutable; a refresh must retain sends/events received while it was in flight.
            messagesByConversationID[conversation.id] = Self.messagesInDisplayOrder(
                ListPageMerge.appendingUnique(messages(for: conversation.id), to: page.items)
            )
            if !unverifiedCachedConversations.contains(conversation.id) { rememberConversation(conversation) }
            reconcileBookingDetailStores(from: page.items)
            reconcileOutgoing(with: page.items)
            persistDisplay()
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
            if error == .notAllowed || error == .conversationNotFound { revokeConversation(conversation.id) }
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
            guard displaySessionIsCurrent, !revokedConversationIDs.contains(conversation.id), !Task.isCancelled else { return }
            messagesByConversationID[conversation.id] = Self.messagesInDisplayOrder(
                ListPageMerge.appendingUnique(
                    messagesByConversationID[conversation.id, default: []],
                    to: page.items
                )
            )
            if !unverifiedCachedConversations.contains(conversation.id) { rememberConversation(conversation) }
            reconcileBookingDetailStores(from: page.items)
            reconcileOutgoing(with: page.items)
            persistDisplay()
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

    // MARK: Per-message outbox

    @discardableResult
    func enqueueMessage(in conversation: ChatConversation, body: String) -> UUID? {
        guard let item = beginOutgoing(in: conversation, body: body) else { return nil }
        startOutgoingWorker(for: conversation)
        return item.id
    }

    func retryMessage(id: UUID, in conversation: ChatConversation) {
        guard canSendMessages(in: conversation), let index = outgoingMessages.firstIndex(where: {
            $0.id == id && $0.conversationID == conversation.id && $0.failureMessage != nil
        }) else { return }
        outgoingMessages[index].failureMessage = nil
        persistDisplay()
        startOutgoingWorker(for: conversation)
    }

    private func beginOutgoing(in conversation: ChatConversation, body: String) -> ChatOutgoingMessage? {
        guard !Task.isCancelled, canSendMessages(in: conversation) else {
            errorMessage = conversation.readOnlyReason
            return nil
        }
        let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { errorMessage = "Enter a message before sending."; return nil }
        guard body.count <= 4000 else { errorMessage = "Messages must be 4000 characters or fewer."; return nil }
        let scopes = Set(outgoingMessages.map(\.conversationID))
        guard outgoingMessages.count < 100,
              outgoingMessages.filter({ $0.conversationID == conversation.id }).count < 50,
              scopes.contains(conversation.id) || scopes.count < 20 else {
            errorMessage = "Retry pending messages before adding more. Your text is still in the input field."
            return nil
        }
        let item = ChatOutgoingMessage(id: UUID(), conversationID: conversation.id, senderID: participantID,
            body: body, queuedAt: now(), failureMessage: nil)
        errorMessage = nil; noticeMessage = nil
        rememberConversation(conversations.first { $0.id == conversation.id } ?? conversation)
        outgoingMessages.append(item)
        localEchoDates[item.id] = item.queuedAt
        persistDisplay()
        return item
    }

    private func startOutgoingWorker(for conversation: ChatConversation) {
        guard outgoingWorkers[conversation.id] == nil else { return }
        let token = UUID()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.drainOutgoing(in: conversation, token: token)
        }
        outgoingWorkers[conversation.id] = (token, task)
    }

    private func drainOutgoing(in conversation: ChatConversation, token: UUID) async {
        defer { if outgoingWorkers[conversation.id]?.token == token { outgoingWorkers[conversation.id] = nil } }
        while displaySessionIsCurrent, !Task.isCancelled, outgoingWorkers[conversation.id]?.token == token,
              let item = outgoingMessages.first(where: {
                  $0.conversationID == conversation.id && $0.failureMessage == nil && !legacyOutgoingIDs.contains($0.id)
              }) {
            guard canSendMessages(in: conversation) else {
                failOutgoing(id: item.id, error: ChatRepositoryError.notAllowed)
                continue
            }
            let startedAt = Date()
            recordStoreStart("sendMessage", metadata: ["conversationID": conversation.id.uuidString])
            do {
                let message = try await repository.sendMessage(messageID: item.id, conversationID: item.conversationID,
                    senderID: participantID, body: item.body)
                guard displaySessionIsCurrent, outgoingWorkers[conversation.id]?.token == token, !Task.isCancelled else { return }
                guard item.matches(message) else { throw ChatRepositoryError.invalidMessage }
                append(message)
                markConversationRead(conversation.id)
                recordStoreSuccess("sendMessage", startedAt: startedAt)
            } catch {
                guard displaySessionIsCurrent, outgoingWorkers[conversation.id]?.token == token else { return }
                failOutgoing(id: item.id, error: error)
                recordStoreFailure("sendMessage", error: error, mappedMessage: outgoingMessage(id: item.id)?.failureMessage,
                    startedAt: startedAt)
            }
        }
    }

    private func failOutgoing(id: UUID, error: any Error) {
        // A realtime/snapshot acknowledgement wins even if the HTTP response later fails.
        guard let index = outgoingMessages.firstIndex(where: { $0.id == id }) else { return }
        let cancelled = AppDebugErrorClassifier.isCancellation(error) || (error as? ChatRepositoryError) == .cancelled
        outgoingMessages[index].failureMessage = cancelled ? "Couldn't confirm sending. Tap Retry." :
            message(for: (error as? ChatRepositoryError) ?? .unavailable, action: "send message")
        persistDisplay()
    }

    private func reconcileOutgoing(with messages: [ChatMessage]) {
        outgoingMessages.removeAll { pending in messages.contains(where: pending.matches) }
    }

    /// Compatibility for non-composer callers: same confirmation result, with a visible local echo.
    @discardableResult
    func sendMessage(in conversation: ChatConversation, body: String) async -> Bool {
        guard !Task.isCancelled, !sendingConversationIDs.contains(conversation.id),
              let item = beginOutgoing(in: conversation, body: body) else { return false }
        let startedAt = Date()
        recordStoreStart("sendMessage", metadata: ["conversationID": conversation.id.uuidString])
        sendingConversationIDs.insert(conversation.id); legacyOutgoingIDs.insert(item.id)
        defer { sendingConversationIDs.remove(conversation.id); legacyOutgoingIDs.remove(item.id) }
        do {
            let message = try await repository.sendMessage(conversationID: conversation.id, senderID: participantID, body: item.body)
            guard displaySessionIsCurrent else { return false }
            outgoingMessages.removeAll { $0.id == item.id }
            if message.id != item.id { localEchoDates[item.id] = nil }
            localEchoDates[message.id] = item.queuedAt
            append(message)
            markConversationRead(conversation.id)
            recordStoreSuccess("sendMessage", startedAt: startedAt)
            return true
        } catch {
            // This legacy API used a server-generated identity; leave its draft with the caller.
            // Only the stable-ID composer API exposes a retryable local attempt.
            outgoingMessages.removeAll { $0.id == item.id }
            localEchoDates[item.id] = nil
            persistDisplay()
            if !AppDebugErrorClassifier.isCancellation(error), (error as? ChatRepositoryError) != .cancelled {
                errorMessage = message(for: (error as? ChatRepositoryError) ?? .unavailable, action: "send message")
            }
            return false
        }
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
        deferredReadConversationIDs.remove(conversationID)
        messageSubscriptionIDs.removeValue(forKey: conversationID)
        messageSubscriptionTasks.removeValue(forKey: conversationID)?.cancel()
        recordStoreInfo(
            "stopMessageSubscription",
            message: "stopped",
            metadata: ["conversationID": conversationID.uuidString]
        )
    }

    func stopAllMessageSubscriptions() {
        deferredReadConversationIDs.removeAll()
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
        guard displaySessionIsCurrent, !revokedConversationIDs.contains(message.conversationID) else { return }
        reconcileOutgoing(with: [message])
        var messages = messagesByConversationID[message.conversationID] ?? []
        guard !messages.contains(where: { $0.id == message.id }) else { persistDisplay(); return }
        messages.append(message)
        messagesByConversationID[message.conversationID] = Self.messagesInDisplayOrder(
            messages
        )
        reconcileBookingDetailStores(from: [message])
        persistDisplay()
    }

    private func reconcileBookingDetailStores(from messages: [ChatMessage]) {
        guard let bookingRepository else { return }

        for booking in messages.compactMap(\.booking) {
            #if DEBUG
            if let sandboxBookingStore {
                sandboxBookingStore.synchronizeExternalBooking(booking)
                bookingDetailStoresByID[booking.id] = sandboxBookingStore
                continue
            }
            #endif
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
        guard !deferredReadConversationIDs.contains(conversationID) else { return }
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
