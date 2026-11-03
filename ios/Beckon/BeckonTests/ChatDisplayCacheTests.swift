import Foundation
import Testing
@testable import Beckon

@MainActor
struct ChatDisplayCacheTests {
    @Test func restartShowsHistoryBeforeNetworkWithoutGrantingSendOrBookingActions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileChatDisplayCache(directory: directory)
        let customer = UUID(), groomer = UUID()
        let conversation = ChatConversation(id: UUID(), customerID: customer, groomerID: groomer,
            createdAt: "2026-11-03T12:00:00Z", updatedAt: "2026-11-03T12:00:00Z")
        let booking = BookingsStoreTests.booking(customerID: customer, groomerID: groomer)
        let text = ChatMessage(id: UUID(), conversationID: conversation.id, senderID: customer, kind: .text,
            body: "Mochi uses the side entrance", booking: nil, createdAt: conversation.createdAt)
        let ticket = ChatMessage(id: UUID(), conversationID: conversation.id, senderID: customer,
            kind: .bookingCard, body: nil, booking: booking, createdAt: conversation.updatedAt)
        cache.save(participantID: groomer, role: .groomer, conversations: [conversation],
            messages: [conversation.id: [text, ticket]], generation: cache.generation)
        #expect(cache.snapshot(participantID: groomer, role: .groomer)?.messages[conversation.id]?.count == 2)
        let repository = ChatRepositoryFake()
        repository.exactConversationResult = .failure(.networkUnavailable)
        let reads = ChatReadStateCacheFake()
        let restored = ChatStore(participantID: groomer, role: .groomer, repository: repository,
            readStateCache: reads, displayCache: FileChatDisplayCache(directory: directory))
        #expect(restored.messages(for: conversation.id).count == 2)
        #expect(restored.messages(for: conversation.id).first?.body == text.body)
        #expect(restored.messages(for: conversation.id).last?.booking?.priceEstimate == booking.priceEstimate)
        #expect(restored.bookingDetailStore(for: ticket) == nil)
        #expect(!restored.canSendMessages(in: conversation))
        #expect(repository.messagesCallCount == 0)
        #expect(reads.timestamps(participantID: groomer, role: .groomer).isEmpty)
        await restored.prepareMessages(for: conversation)
        #expect(restored.messages(for: conversation.id).count == 2, "A transient verification error retains visible history")
        #expect(!restored.canSendMessages(in: conversation))
        repository.exactConversationResult = .success(conversation)
        repository.messagesResult = .success([text, ticket])
        await restored.prepareMessages(for: conversation)
        #expect(restored.canSendMessages(in: conversation))
        repository.messagesResult = .failure(.notAllowed)
        await restored.loadMessages(for: conversation)
        #expect(restored.messages(for: conversation.id).isEmpty)
        restored.stopAllMessageSubscriptions()
    }

    @Test func snapshotsAreBoundedIsolatedAndCleanupRejectsLateWrites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileChatDisplayCache(directory: directory)
        let owner = UUID(), other = UUID()
        let conversations = (0..<25).map { _ in
            ChatConversation(id: UUID(), customerID: other, groomerID: owner,
                createdAt: "2026-11-03T12:00:00Z", updatedAt: "2026-11-03T12:00:00Z")
        }
        let messages = conversations.reduce(into: [UUID: [ChatMessage]]()) { result, conversation in
            result[conversation.id] = (0..<70).map { index in
                ChatMessage(id: UUID(), conversationID: conversation.id, senderID: other, kind: .text,
                    body: "Message \(index)", booking: nil, createdAt: conversation.createdAt)
            }
        }
        let token = cache.generation
        cache.save(participantID: owner, role: .groomer, conversations: conversations, messages: messages, generation: token)
        let snapshot = try #require(cache.snapshot(participantID: owner, role: .groomer))
        #expect(snapshot.conversations.count == 20)
        #expect(snapshot.messages.values.allSatisfy { $0.count == 50 })
        #expect(cache.snapshot(participantID: other, role: .groomer) == nil)
        #expect(cache.snapshot(participantID: owner, role: .customer) == nil)
        cache.remove(participantID: owner)
        cache.save(participantID: owner, role: .groomer, conversations: conversations, messages: messages, generation: token)
        #expect(cache.snapshot(participantID: owner, role: .groomer) == nil)
    }
}
