import Foundation
import Testing
@testable import Beckon

@MainActor
struct ChatOutboxTests {
    @Test func immediateEchoQueuesMultipleMessagesAndKeepsTheirIdentity() async throws {
        let f = Fixture(), gate = Gate()
        f.repository.beforeSend = { await gate.suspend() }
        let first = try #require(f.store.enqueueMessage(in: f.conversation, body: "First"))
        #expect(f.store.displayMessages(for: f.conversation.id).map(\.body) == ["First"])
        #expect(f.store.messages(for: f.conversation.id).isEmpty)
        try await gate.wait()
        let second = try #require(f.store.enqueueMessage(in: f.conversation, body: "Second"))
        #expect(f.store.displayMessages(for: f.conversation.id).map(\.id) == [first, second])
        #expect(f.repository.sendCallCount == 1)
        // Refreshing confirmed history must not erase the two local rows.
        await f.store.loadMessages(for: f.conversation)
        #expect(f.store.displayMessages(for: f.conversation.id).count == 2)
        f.repository.beforeSend = nil
        gate.release()
        try await settled { f.store.outgoingMessages.isEmpty }
        #expect(f.repository.sentMessageIDs == [first, second])
        #expect(f.store.displayMessages(for: f.conversation.id).map(\.id) == [first, second])
        #expect(f.store.messages(for: f.conversation.id).count == 2)
    }

    @Test func failureIsPerMessageAndRetryUsesSameIDWithoutDoubleSending() async throws {
        let f = Fixture()
        f.repository.sendResult = .failure(.networkUnavailable)
        let id = try #require(f.store.enqueueMessage(in: f.conversation, body: "Try again"))
        try await settled { f.store.outgoingMessage(id: id)?.failureMessage != nil }
        #expect(f.store.errorMessage == nil)
        #expect(f.store.displayMessages(for: f.conversation.id).map(\.id) == [id])
        let gate = Gate()
        f.repository.beforeSend = { await gate.suspend() }
        f.repository.sendResult = .success(f.response())
        f.store.retryMessage(id: id, in: f.conversation)
        f.store.retryMessage(id: id, in: f.conversation)
        try await gate.wait()
        #expect(f.repository.sentMessageIDs == [id, id])
        gate.release()
        try await settled { f.store.outgoingMessages.isEmpty }
        #expect(f.store.messages(for: f.conversation.id).map(\.id) == [id])
    }

    @Test func snapshotAcknowledgementWinsOverLostHTTPReply() async throws {
        let f = Fixture(), gate = Gate()
        f.repository.beforeSend = { await gate.suspend() }
        f.repository.sendResult = .failure(.networkUnavailable)
        let id = try #require(f.store.enqueueMessage(in: f.conversation, body: "Already committed"))
        try await gate.wait()
        f.repository.messagesResult = .success([f.response(id: id, body: "Already committed")])
        await f.store.loadMessages(for: f.conversation)
        #expect(f.store.outgoingMessages.isEmpty)
        gate.release()
        try await settled { f.repository.sendCallCount == 1 }
        for _ in 0..<10 { await Task.yield() }
        #expect(f.store.outgoingMessages.isEmpty)
        #expect(f.store.messages(for: f.conversation.id).map(\.id) == [id])
        #expect(f.store.errorMessage == nil)
    }

    @Test func pendingSurvivesRestartAsRetryableWithoutAutomaticNetworkWrites() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileChatDisplayCache(directory: directory)
        let f = Fixture(cache: cache), gate = Gate()
        f.repository.beforeSend = { await gate.suspend() }
        let id = try #require(f.store.enqueueMessage(in: f.conversation, body: "Keep across restart"))
        try await gate.wait()
        #expect(cache.snapshot(participantID: f.conversation.customerID, role: .customer)?.outgoingMessages.count == 1)
        let repository = ChatRepositoryFake()
        let restored = ChatStore(participantID: f.conversation.customerID, role: .customer, repository: repository,
            readStateCache: ChatReadStateCacheFake(), displayCache: FileChatDisplayCache(directory: directory))
        #expect(restored.displayMessages(for: f.conversation.id).map(\.id) == [id])
        #expect(restored.outgoingMessage(id: id)?.failureMessage != nil)
        #expect(!restored.canSendMessages(in: f.conversation))
        restored.retryMessage(id: id, in: f.conversation)
        #expect(repository.sendCallCount == 0)
        #expect(cache.snapshot(participantID: UUID(), role: .customer) == nil)
        cache.remove(participantID: f.conversation.customerID)
        gate.release()
        for _ in 0..<10 { await Task.yield() }
        #expect(cache.snapshot(participantID: f.conversation.customerID, role: .customer) == nil)
        #expect(f.store.messages(for: f.conversation.id).isEmpty)
    }

    @Test func invalidTextNeverBecomesAnOutgoingAttempt() {
        let f = Fixture()
        #expect(f.store.enqueueMessage(in: f.conversation, body: "  \n") == nil)
        #expect(f.store.enqueueMessage(in: f.conversation, body: String(repeating: "x", count: 4001)) == nil)
        #expect(f.store.outgoingMessages.isEmpty)
        #expect(f.repository.sendCallCount == 0)
    }

    private func settled(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() { try await Task.sleep(for: .milliseconds(5)) }
        #expect(condition())
    }

    @MainActor private final class Fixture {
        let conversation: ChatConversation
        let repository: ChatRepositoryFake
        let store: ChatStore
        init(cache: FileChatDisplayCache? = nil) {
            conversation = ChatConversation(id: UUID(), customerID: UUID(), groomerID: UUID(),
                createdAt: "2026-11-03T12:00:00Z", updatedAt: "2026-11-03T12:00:00Z")
            let template = ChatMessage(id: UUID(), conversationID: conversation.id, senderID: conversation.customerID,
                kind: .text, body: "Template", booking: nil, createdAt: "2026-11-03T12:01:00Z")
            repository = ChatRepositoryFake(conversationsResult: .success([conversation]), sendResult: .success(template))
            store = ChatStore(participantID: conversation.customerID, role: .customer, repository: repository,
                readStateCache: ChatReadStateCacheFake(), displayCache: cache)
        }
        func response(id: UUID = UUID(), body: String = "Try again") -> ChatMessage {
            ChatMessage(id: id, conversationID: conversation.id, senderID: conversation.customerID,
                kind: .text, body: body, booking: nil, createdAt: "2026-11-03T12:01:00Z")
        }
    }
    @MainActor private final class Gate {
        var continuation: CheckedContinuation<Void, Never>?
        func suspend() async { await withCheckedContinuation { continuation = $0 } }
        func wait() async throws {
            for _ in 0..<100 where continuation == nil { try await Task.sleep(for: .milliseconds(5)) }
            try #require(continuation != nil)
        }
        func release() { continuation?.resume(); continuation = nil }
    }
}
