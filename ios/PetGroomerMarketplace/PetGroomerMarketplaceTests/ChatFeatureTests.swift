import Foundation
import Testing
@testable import PetGroomerMarketplace

struct ChatStoreTests {
    @Test @MainActor
    func loadConversationsFetchesRoleScopedRows() async throws {
        let participantID = UUID()
        let conversation = Self.conversation(customerID: participantID)
        let repository = ChatRepositoryFake(
            conversationsResult: .success([conversation])
        )
        let store = ChatStore(
            participantID: participantID,
            role: .customer,
            repository: repository
        )

        await store.loadConversations()

        #expect(repository.conversationsCallCount == 1)
        #expect(repository.lastParticipantID == participantID)
        #expect(repository.lastRole == .customer)
        #expect(store.conversations == [conversation])
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func loadMessagesStoresConversationMessages() async throws {
        let conversation = Self.conversation()
        let message = Self.message(conversationID: conversation.id)
        let repository = ChatRepositoryFake(
            messagesResult: .success([message])
        )
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.loadMessages(for: conversation)

        #expect(repository.messagesCallCount == 1)
        #expect(repository.lastConversationID == conversation.id)
        #expect(store.messages(for: conversation.id) == [message])
    }

    @Test @MainActor
    func sendMessageTrimsAndAppendsReturnedMessage() async throws {
        let conversation = Self.conversation()
        let sent = Self.message(
            conversationID: conversation.id,
            senderID: conversation.customerID,
            body: "Hello"
        )
        let repository = ChatRepositoryFake(sendResult: .success(sent))
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.sendMessage(in: conversation, body: "  Hello\n")

        #expect(repository.sendCallCount == 1)
        #expect(repository.lastSentConversationID == conversation.id)
        #expect(repository.lastSenderID == conversation.customerID)
        #expect(repository.lastBody == "Hello")
        #expect(store.messages(for: conversation.id) == [sent])
        #expect(store.noticeMessage == "Message sent.")
    }

    @Test @MainActor
    func completedConversationOlderThanSevenDaysDoesNotSend() async throws {
        let conversation = Self.conversation(
            status: .completed,
            completedAt: "2026-06-01T18:00:00Z"
        )
        let repository = ChatRepositoryFake()
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository,
            now: { Date(timeIntervalSince1970: 1_781_028_000) }
        )

        #expect(store.canSendMessages(in: conversation) == false)

        await store.sendMessage(in: conversation, body: "Hello")

        #expect(repository.sendCallCount == 0)
        #expect(
            store.errorMessage ==
                "This conversation is read-only because the booking ended more than 7 days ago."
        )
    }

    @Test @MainActor
    func blankMessageDoesNotCallRepository() async throws {
        let conversation = Self.conversation()
        let repository = ChatRepositoryFake()
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.sendMessage(in: conversation, body: " \n ")

        #expect(repository.sendCallCount == 0)
        #expect(store.errorMessage == "Enter a message before sending.")
    }

    @Test @MainActor
    func sendNotAllowedMapsToSafeMessage() async throws {
        let conversation = Self.conversation()
        let repository = ChatRepositoryFake(sendResult: .failure(.notAllowed))
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.sendMessage(in: conversation, body: "Hello")

        #expect(repository.sendCallCount == 1)
        #expect(
            store.errorMessage ==
                "This account cannot send message for this conversation."
        )
        #expect(store.noticeMessage == nil)
    }

    @Test
    func conversationReferencesAreShortAndRoleSpecific() {
        let conversation = Self.conversation(
            bookingID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            customerID: UUID(uuidString: "12345678-0000-0000-0000-000000000000")!,
            groomerID: UUID(uuidString: "87654321-0000-0000-0000-000000000000")!
        )

        #expect(conversation.bookingReferenceCode == "11111111")
        #expect(conversation.participantReferenceCode(for: .customer) == "87654321")
        #expect(conversation.participantReferenceCode(for: .groomer) == "12345678")
        #expect(conversation.participantSummary(for: .customer) == "Groomer ref 87654321")
        #expect(conversation.participantSummary(for: .groomer) == "Customer ref 12345678")
    }

    @Test
    func conversationUsesPublicGroomerNameAndBookingSummaryWhenAvailable() {
        let conversation = Self.conversation(
            bookingID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            scheduledStart: "2026-06-21T17:00:00Z",
            scheduledEnd: "2026-06-21T18:00:00Z",
            priceEstimate: 125.50,
            groomerBusinessName: " Fresh Coat Grooming "
        )

        #expect(conversation.participantSummary(for: .customer) == "Fresh Coat Grooming")
        #expect(conversation.participantSummary(for: .groomer).hasPrefix("Customer ref "))
        #expect(conversation.scheduledTimeSummary != nil)
        #expect(conversation.priceSummary != nil)
        #expect(conversation.bookingContextSummary.contains("Booking ref 11111111"))
        #expect(conversation.bookingReferenceAndPriceSummary.contains("Booking ref 11111111"))
    }

    private static func conversation(
        id: UUID = UUID(),
        bookingID: UUID = UUID(),
        requestID: UUID = UUID(),
        customerID: UUID = UUID(),
        groomerID: UUID = UUID(),
        scheduledStart: String? = nil,
        scheduledEnd: String? = nil,
        priceEstimate: Double? = nil,
        status: BookingStatus? = nil,
        completedAt: String? = nil,
        groomerBusinessName: String? = nil
    ) -> ChatConversation {
        ChatConversation(
            id: id,
            bookingID: bookingID,
            requestID: requestID,
            customerID: customerID,
            groomerID: groomerID,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            priceEstimate: priceEstimate,
            bookingStatus: status,
            completedAt: completedAt,
            groomerBusinessName: groomerBusinessName,
            createdAt: "2026-06-21T05:00:00Z",
            updatedAt: "2026-06-21T05:00:00Z"
        )
    }

    private static func message(
        id: UUID = UUID(),
        conversationID: UUID = UUID(),
        senderID: UUID = UUID(),
        body: String = "Hello"
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationID: conversationID,
            senderID: senderID,
            body: body,
            createdAt: "2026-06-21T05:01:00Z"
        )
    }
}

@MainActor
private final class ChatRepositoryFake: ChatRepository {
    var conversationsResult: Result<[ChatConversation], ChatRepositoryError>
    var messagesResult: Result<[ChatMessage], ChatRepositoryError>
    var sendResult: Result<ChatMessage, ChatRepositoryError>

    private(set) var conversationsCallCount = 0
    private(set) var messagesCallCount = 0
    private(set) var sendCallCount = 0
    private(set) var lastParticipantID: UUID?
    private(set) var lastRole: UserRole?
    private(set) var lastConversationID: UUID?
    private(set) var lastSentConversationID: UUID?
    private(set) var lastSenderID: UUID?
    private(set) var lastBody: String?

    init(
        conversationsResult: Result<[ChatConversation], ChatRepositoryError> =
            .success([]),
        messagesResult: Result<[ChatMessage], ChatRepositoryError> = .success([]),
        sendResult: Result<ChatMessage, ChatRepositoryError> =
            .failure(.unavailable)
    ) {
        self.conversationsResult = conversationsResult
        self.messagesResult = messagesResult
        self.sendResult = sendResult
    }

    func conversations(
        participantID: UUID,
        role: UserRole
    ) async throws -> [ChatConversation] {
        conversationsCallCount += 1
        lastParticipantID = participantID
        lastRole = role
        return try conversationsResult.get()
    }

    func messages(
        conversationID: UUID
    ) async throws -> [ChatMessage] {
        messagesCallCount += 1
        lastConversationID = conversationID
        return try messagesResult.get()
    }

    func sendMessage(
        conversationID: UUID,
        senderID: UUID,
        body: String
    ) async throws -> ChatMessage {
        sendCallCount += 1
        lastSentConversationID = conversationID
        lastSenderID = senderID
        lastBody = body
        return try sendResult.get()
    }
}
