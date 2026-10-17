import Foundation
import Testing
@testable import Beckon

@MainActor
struct ChatReliabilityTests {
    @Test
    func groomerCanDistinguishDifferentCustomersWithoutOpeningEachChat() {
        let first = Fixture().conversation
        let second = Fixture().conversation
        #expect(first.listTitle(for: .groomer) != second.listTitle(for: .groomer))
        #expect(first.shortRecipientName(for: .groomer) == "Customer")
    }

    @Test(arguments: [false, true])
    func stoppedPendingSubscriptionCannotDeliverOrBlockReentry(stopAll: Bool) async throws {
        let fixture = Fixture()
        let gate = Gate()
        fixture.repository.beforeMessageEvents = { await gate.suspend() }
        let start = Task { await fixture.store.startMessageSubscription(for: fixture.conversation) }
        try await gate.waitUntilEntered()
        #expect(fixture.store.isLoadingMessages(for: fixture.conversation.id))
        if stopAll { fixture.store.stopAllMessageSubscriptions() }
        else { fixture.store.stopMessageSubscription(for: fixture.conversation.id) }
        gate.release()
        await start.value
        let late = fixture.message("Late event", at: "2026-10-04T12:01:00Z")
        fixture.repository.yieldMessageEvent(late)
        for _ in 0..<20 { await Task.yield() }
        #expect(fixture.store.messages(for: fixture.conversation.id).isEmpty)
        #expect(fixture.repository.messageEventTerminationCount == 1)
        fixture.repository.beforeMessageEvents = nil
        await fixture.store.startMessageSubscription(for: fixture.conversation)
        #expect(fixture.repository.messageEventsCallCount == 2)
        fixture.store.stopAllMessageSubscriptions()
    }

    @Test
    func refreshCannotEraseMessageSentWhileItsSnapshotIsInFlight() async throws {
        let fixture = Fixture()
        let original = fixture.message("Original", at: "2026-10-04T12:00:00Z")
        let sent = fixture.message("Sent during refresh", at: "2026-10-04T12:01:00Z", outgoing: true)
        fixture.repository.messagesResult = .success([original])
        fixture.repository.sendResult = .success(sent)
        let gate = Gate()
        fixture.repository.beforeMessageRead = { await gate.suspend() }
        let refresh = Task { await fixture.store.loadMessages(for: fixture.conversation) }
        try await gate.waitUntilEntered()
        await fixture.store.sendMessage(in: fixture.conversation, body: sent.body!)
        gate.release()
        await refresh.value
        #expect(fixture.store.messages(for: fixture.conversation.id) == [original, sent])
    }

    @Test
    func staleMessagePageDoesNotAcknowledgeAnUnseenSummaryMessage() async {
        let fixture = Fixture(latest: "2026-10-04T12:01:00Z")
        await fixture.store.loadConversations()
        fixture.repository.messagesResult = .success([fixture.message("Older", at: "2026-10-04T12:00:00Z")])
        await fixture.store.loadMessages(for: fixture.conversation)
        #expect(fixture.store.unreadConversationCount == 1)
        fixture.repository.messagesResult = .success([fixture.message("Current", at: "2026-10-04T12:01:00Z")])
        await fixture.store.loadMessages(for: fixture.conversation)
        #expect(fixture.store.unreadConversationCount == 0)
    }

    @Test
    func readWatermarkDoesNotRegressAfterAnOlderReload() async {
        let fixture = Fixture(latest: "2026-10-04T12:01:00Z")
        fixture.repository.messagesResult = .success([fixture.message("Seen", at: "2026-10-04T12:01:00Z")])
        await fixture.store.loadMessages(for: fixture.conversation)
        fixture.repository.messagesResult = .success([fixture.message("Older", at: "2026-10-04T12:00:00Z")])
        await fixture.store.loadMessages(for: fixture.conversation)
        let reopened = ChatStore(participantID: fixture.conversation.customerID, role: .customer,
            repository: fixture.repository, readStateCache: fixture.cache)
        await reopened.loadConversations()
        #expect(reopened.unreadConversationCount == 0)
    }

    @Test
    func olderMessagePageKeepsBookingDetailsReachable() async throws {
        let booking = try BookingRescheduleTests.booking()
        let conversation = ChatConversation(id: UUID(), customerID: booking.customerID,
            groomerID: booking.groomerID, createdAt: "2026-10-04T12:00:00Z", updatedAt: "2026-10-04T12:00:00Z")
        let recent = ChatMessage(id: UUID(), conversationID: conversation.id,
            senderID: booking.customerID, kind: .text, body: "See you soon", booking: nil,
            createdAt: "2026-10-04T12:01:00Z")
        let card = ChatMessage(id: UUID(), conversationID: conversation.id,
            senderID: booking.customerID, kind: .bookingCard, body: nil, booking: booking,
            createdAt: "2026-10-04T12:00:00Z")
        let repository = ChatRepositoryFake(messagePages: [
            .success(ListPage(items: [recent], request: .first, hasMore: true)),
            .success(ListPage(items: [card], request: .first.next, hasMore: false)),
        ])
        let store = ChatStore(participantID: booking.customerID, role: .customer,
            repository: repository, bookingRepository: BookingRepositoryFake(),
            readStateCache: ChatReadStateCacheFake())

        await store.loadMessages(for: conversation)
        await store.loadNextMessagesPage(for: conversation)

        #expect(store.messages(for: conversation.id) == [card, recent])
        #expect(store.bookingDetailStore(for: card)?.booking(withID: booking.id) == booking)
    }

    @Test
    func fractionalTimestampMessagesSortByInstantRatherThanString() async {
        let fixture = Fixture()
        let first = fixture.message("First", at: "2026-10-04T12:00:00Z")
        let next = fixture.message("Next", at: "2026-10-04T12:00:00.500Z")
        fixture.repository.messagesResult = .success([next, first])
        await fixture.store.loadMessages(for: fixture.conversation)
        #expect(fixture.store.messages(for: fixture.conversation.id) == [first, next])
    }

    @Test(arguments: [ChatRepositoryError.cancelled, .networkUnavailable, .notAllowed])
    func unsuccessfulSendDoesNotReportSuccessOrAppend(error: ChatRepositoryError) async {
        let fixture = Fixture()
        fixture.repository.sendResult = .failure(error)
        #expect(await fixture.store.sendMessage(in: fixture.conversation, body: "Keep my draft") == false)
        #expect(fixture.store.messages(for: fixture.conversation.id).isEmpty)
        #expect(!fixture.store.isSendingMessage(for: fixture.conversation.id))
        let sent = fixture.message("Keep my draft", at: "2026-10-04T12:02:00Z", outgoing: true)
        fixture.repository.sendResult = .success(sent)
        #expect(await fixture.store.sendMessage(in: fixture.conversation, body: "Keep my draft"))
        #expect(fixture.store.messages(for: fixture.conversation.id) == [sent])
    }

    @Test
    func duplicateSendCannotReportTheOtherAttemptsSuccess() async throws {
        let fixture = Fixture()
        let gate = Gate()
        fixture.repository.beforeSend = { await gate.suspend() }
        fixture.repository.sendResult = .success(fixture.message("First", at: "2026-10-04T12:02:00Z", outgoing: true))
        let first = Task { await fixture.store.sendMessage(in: fixture.conversation, body: "First") }
        try await gate.waitUntilEntered()
        #expect(await fixture.store.sendMessage(in: fixture.conversation, body: "Second") == false)
        #expect(fixture.repository.sendCallCount == 1)
        gate.release()
        #expect(await first.value)
        #expect(fixture.store.messages(for: fixture.conversation.id).count == 1)
    }

    @Test
    func messageLoadAndSubscriptionFailuresExposeIndependentRecoveryState() async {
        let fixture = Fixture()
        fixture.repository.messagesResult = .failure(.networkUnavailable)
        fixture.repository.messageEventsResult = .failure(.networkUnavailable)
        await fixture.store.loadMessages(for: fixture.conversation)
        await fixture.store.startMessageSubscription(for: fixture.conversation)
        #expect(fixture.store.messageLoadErrors[fixture.conversation.id] != nil)
        #expect(fixture.store.interruptedMessageSubscriptions.contains(fixture.conversation.id))
        fixture.repository.messagesResult = .success([])
        fixture.repository.messageEventsResult = .success(())
        await fixture.store.startMessageSubscription(for: fixture.conversation)
        await fixture.store.loadMessages(for: fixture.conversation)
        #expect(fixture.store.messageLoadErrors[fixture.conversation.id] == nil)
        #expect(!fixture.store.interruptedMessageSubscriptions.contains(fixture.conversation.id))
        fixture.store.stopAllMessageSubscriptions()
    }

    @Test
    func readStateIsIsolatedBetweenAccountsAndRoles() async {
        let suite = "T404-chat-read-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fixture = Fixture(latest: "2026-10-04T12:01:00Z", cache: UserDefaultsChatReadStateCache(userDefaults: defaults))
        fixture.repository.messagesResult = .success([fixture.message("Seen", at: "2026-10-04T12:01:00Z")])
        await fixture.store.loadMessages(for: fixture.conversation)
        #expect(fixture.cache.timestamps(participantID: fixture.conversation.customerID, role: .customer).count == 1)
        #expect(fixture.cache.timestamps(participantID: fixture.conversation.customerID, role: .groomer).isEmpty)
        #expect(fixture.cache.timestamps(participantID: UUID(), role: .customer).isEmpty)
    }

    @MainActor private final class Fixture {
        let conversation: ChatConversation
        let repository: ChatRepositoryFake
        let store: ChatStore
        let cache: any ChatReadStateCaching
        init(latest: String? = nil, cache: any ChatReadStateCaching = ChatReadStateCacheFake()) {
            self.cache = cache
            let customer = UUID(), groomer = UUID()
            conversation = ChatConversation(id: UUID(), customerID: customer, groomerID: groomer,
                latestMessageSenderID: groomer, latestMessageCreatedAt: latest,
                createdAt: "2026-10-04T12:00:00Z", updatedAt: "2026-10-04T12:00:00Z")
            repository = ChatRepositoryFake(conversationsResult: .success([conversation]))
            store = ChatStore(participantID: customer, role: .customer, repository: repository, readStateCache: cache)
        }
        func message(_ body: String, at: String, outgoing: Bool = false) -> ChatMessage {
            ChatMessage(id: UUID(), conversationID: conversation.id,
                senderID: outgoing ? conversation.customerID : conversation.groomerID,
                kind: .text, body: body, booking: nil, createdAt: at)
        }
    }

    @MainActor private final class Gate {
        private var continuation: CheckedContinuation<Void, Never>?
        func suspend() async { await withCheckedContinuation { continuation = $0 } }
        func waitUntilEntered() async throws {
            for _ in 0..<100 where continuation == nil { try await Task.sleep(for: .milliseconds(5)) }
            try #require(continuation != nil)
        }
        func release() { continuation?.resume(); continuation = nil }
    }
}
