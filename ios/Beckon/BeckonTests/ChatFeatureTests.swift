import Foundation
import Testing
@testable import Beckon

struct ChatStoreTests {
    @Test
    func chatComposerRemainsATrueKeyboardAccessory() {
        #expect(ChatComposerKeyboardPresentation.actionPlacement == .inputAccessory)
        #expect(ChatComposerKeyboardPresentation.includesExplicitDoneAccessory)
    }

    @Test
    func groomerConversationPresentationUsesOperationalUnreadSummary() {
        let empty = GroomerConversationListPresentation(
            conversationCount: 0,
            unreadConversationCount: 0
        )
        let active = GroomerConversationListPresentation(
            conversationCount: 3,
            unreadConversationCount: 2
        )

        #expect(empty.title == "Conversations")
        #expect(empty.subtitle == "All conversations are read.")
        #expect(empty.showsGroupedSurface == false)
        #expect(active.subtitle == "2 unread conversations.")
        #expect(active.showsGroupedSurface)
    }

    @Test @MainActor
    func conversationPaginationRetriesThenAppendsUniqueRowsAndStopsAtLastPage() async {
        let participantID = UUID()
        let first = Self.conversation(customerID: participantID)
        let second = Self.conversation(customerID: participantID)
        let repository = ChatRepositoryFake(
            conversationPages: [
                .success(ListPage(items: [first], request: .first, hasMore: true)),
                .failure(.networkUnavailable),
                .success(
                    ListPage(
                        items: [first, second],
                        request: .first.next,
                        hasMore: false
                    )
                ),
            ]
        )
        let store = ChatStore(
            participantID: participantID,
            role: .customer,
            repository: repository
        )

        await store.loadConversations()
        await store.loadNextConversationsPage()

        #expect(store.conversations.map(\.id) == [first.id])
        #expect(store.canLoadMoreConversations == true)
        #expect(store.isLoadingMoreConversations == false)
        #expect(store.errorMessage == "Check your connection and try again.")

        await store.loadNextConversationsPage()

        #expect(repository.receivedConversationPages == [.first, .first.next, .first.next])
        #expect(store.conversations.map(\.id) == [first.id, second.id])
        #expect(store.canLoadMoreConversations == false)
    }

    @Test @MainActor
    func olderMessagePaginationRetriesThenPrependsUniqueHistoryAndStops() async {
        let conversation = Self.conversation()
        let oldest = Self.message(
            conversationID: conversation.id,
            createdAt: "2026-06-21T05:01:00Z"
        )
        let older = Self.message(
            conversationID: conversation.id,
            createdAt: "2026-06-21T05:02:00Z"
        )
        let recent = Self.message(
            conversationID: conversation.id,
            createdAt: "2026-06-21T05:03:00Z"
        )
        let newest = Self.message(
            conversationID: conversation.id,
            createdAt: "2026-06-21T05:04:00Z"
        )
        let repository = ChatRepositoryFake(
            messagePages: [
                .success(
                    ListPage(
                        items: [recent, newest],
                        request: .first,
                        hasMore: true
                    )
                ),
                .failure(.networkUnavailable),
                .success(
                    ListPage(
                        items: [oldest, older, recent],
                        request: .first.next,
                        hasMore: false
                    )
                ),
            ]
        )
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.loadMessages(for: conversation)
        await store.loadNextMessagesPage(for: conversation)

        #expect(store.messages(for: conversation.id) == [recent, newest])
        #expect(store.canLoadMoreMessages(for: conversation.id) == true)
        #expect(store.isLoadingEarlierMessages(for: conversation.id) == false)
        #expect(store.errorMessage == "Check your connection and try again.")

        await store.loadNextMessagesPage(for: conversation)

        #expect(repository.receivedMessagePages == [.first, .first.next, .first.next])
        #expect(store.messages(for: conversation.id) == [oldest, older, recent, newest])
        #expect(store.canLoadMoreMessages(for: conversation.id) == false)
    }

    @Test @MainActor
    func repositoryMessagePageKeepsNewestWindowInDisplayOrder() {
        let conversationID = UUID()
        let oldest = Self.message(
            conversationID: conversationID,
            createdAt: "2026-06-21T05:01:00Z"
        )
        let middle = Self.message(
            conversationID: conversationID,
            createdAt: "2026-06-21T05:02:00Z"
        )
        let newest = Self.message(
            conversationID: conversationID,
            createdAt: "2026-06-21T05:03:00Z"
        )

        let page = SupabaseChatRepository.messagePage(
            fromDescendingMessages: [newest, middle, oldest],
            request: ListPageRequest(limit: 2)
        )

        #expect(page.items == [middle, newest])
        #expect(page.hasMore == true)
        #expect(page.nextRequest == ListPageRequest(limit: 2, offset: 2))
    }

    @Test
    func threadScrollPolicyIgnoresPrependedHistoryButFollowsNewLatestMessage() {
        let currentLatestID = UUID()

        #expect(
            ChatThreadScrollPolicy.shouldScrollToBottom(
                previousLatestMessageID: currentLatestID,
                currentLatestMessageID: currentLatestID
            ) == false
        )
        #expect(
            ChatThreadScrollPolicy.shouldScrollToBottom(
                previousLatestMessageID: currentLatestID,
                currentLatestMessageID: UUID()
            ) == true
        )
        #expect(
            ChatThreadScrollPolicy.shouldScrollToBottom(
                previousLatestMessageID: nil,
                currentLatestMessageID: currentLatestID
            ) == true
        )
    }

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
    func readConversationStateSurvivesStoreRecreation() async throws {
        let participantID = UUID()
        let conversation = Self.conversation(
            customerID: participantID,
            latestMessageSenderID: UUID(),
            latestMessageCreatedAt: "2026-06-21T05:04:00Z"
        )
        let message = Self.message(
            conversationID: conversation.id,
            createdAt: "2026-06-21T05:04:00Z"
        )
        let cache = ChatReadStateCacheFake()
        let repository = ChatRepositoryFake(
            conversationsResult: .success([conversation]),
            messagesResult: .success([message])
        )
        let firstStore = ChatStore(
            participantID: participantID,
            role: .customer,
            repository: repository,
            readStateCache: cache
        )

        await firstStore.loadConversations()
        #expect(firstStore.hasUnreadMessages(in: conversation))
        await firstStore.loadMessages(for: conversation)
        #expect(!firstStore.hasUnreadMessages(in: conversation))

        let relaunchedStore = ChatStore(
            participantID: participantID,
            role: .customer,
            repository: repository,
            readStateCache: cache
        )
        await relaunchedStore.loadConversations()

        #expect(!relaunchedStore.hasUnreadMessages(in: conversation))
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
        #expect(store.noticeMessage == nil)
    }

    @Test @MainActor
    func sharedChatStoreCanAttachDebugRecorderAfterTabInitialization() async throws {
        let conversation = Self.conversation()
        let sent = Self.message(
            conversationID: conversation.id,
            senderID: conversation.customerID,
            body: "Hello"
        )
        let recorder = AppDebugEventRecorder(
            writer: AppDebugEventWriterSpy(),
            emitsToOSLog: false
        )
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: ChatRepositoryFake(sendResult: .success(sent))
        )

        store.setDebugRecorder(recorder)
        await store.sendMessage(in: conversation, body: "Hello")

        #expect(
            recorder.events.contains {
                $0.source == "ChatStore.sendMessage" && $0.message == "success"
            }
        )
    }

    @Test @MainActor
    func conversationPreviewUsesKnownLatestMessageBody() async throws {
        let conversation = Self.conversation(latestMessageBody: " See you Friday. ")
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: ChatRepositoryFake()
        )

        #expect(store.previewText(for: conversation) == "See you Friday.")
    }

    @Test @MainActor
    func conversationPreviewPrefersLoadedLatestMessageBody() async throws {
        let conversation = Self.conversation(latestMessageBody: "Original preview")
        let older = Self.message(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            conversationID: conversation.id,
            body: "Earlier note"
        )
        let latest = Self.message(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            conversationID: conversation.id,
            body: "Latest body"
        )
        let repository = ChatRepositoryFake(
            messagesResult: .success([older, latest])
        )
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.loadMessages(for: conversation)

        #expect(store.previewText(for: conversation) == "Latest body")
    }

    @Test @MainActor
    func conversationLookupFindsLoadedBookingConversation() async throws {
        let conversation = Self.conversation()
        let booking = Self.booking(
            customerID: conversation.customerID,
            groomerID: conversation.groomerID
        )
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: ChatRepositoryFake(
                conversationsResult: .success([conversation])
            )
        )

        await store.loadConversations()

        #expect(store.conversation(for: booking) == conversation)
    }

    @Test @MainActor
    func bookingCardMessageCarriesTheLiveBookingAndNoTextBody() {
        let conversationID = UUID()
        let booking = Self.booking(status: .cancelledByCustomer)
        let message = ChatMessage(
            id: UUID(),
            conversationID: conversationID,
            senderID: booking.customerID,
            kind: .bookingCard,
            body: nil,
            booking: booking,
            createdAt: "2026-06-21T05:01:00Z"
        )

        #expect(message.kind == .bookingCard)
        #expect(message.body == nil)
        #expect(message.booking?.status == .cancelledByCustomer)
    }

    @Test @MainActor
    func bookingCardSortsBeforeItsFriendlyText() async throws {
        let conversation = Self.conversation()
        let booking = Self.booking(
            customerID: conversation.customerID,
            groomerID: conversation.groomerID
        )
        let card = ChatMessage(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            conversationID: conversation.id,
            senderID: conversation.customerID,
            kind: .bookingCard,
            body: nil,
            booking: booking,
            createdAt: "2026-06-21T05:01:00.000000Z"
        )
        let text = ChatMessage(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            conversationID: conversation.id,
            senderID: conversation.customerID,
            kind: .text,
            body: "Hi! I've accepted your offer.",
            booking: nil,
            createdAt: "2026-06-21T05:01:00.000001Z"
        )
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: ChatRepositoryFake(messagesResult: .success([text, card]))
        )

        await store.loadMessages(for: conversation)

        #expect(store.messages(for: conversation.id) == [card, text])
    }

    @Test @MainActor
    func unreadConversationCountTracksLatestMessagesFromOtherParticipant() async throws {
        let participantID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let otherParticipantID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let unreadConversation = Self.conversation(
            customerID: participantID,
            groomerID: otherParticipantID,
            latestMessageSenderID: otherParticipantID,
            latestMessageCreatedAt: "2026-06-21T05:10:00Z",
            latestMessageBody: "Could you confirm pickup?"
        )
        let ownLatestConversation = Self.conversation(
            customerID: participantID,
            groomerID: otherParticipantID,
            latestMessageSenderID: participantID,
            latestMessageCreatedAt: "2026-06-21T05:11:00Z",
            latestMessageBody: "Thanks"
        )
        let emptyConversation = Self.conversation(
            customerID: participantID,
            groomerID: otherParticipantID
        )
        let store = ChatStore(
            participantID: participantID,
            role: .customer,
            repository: ChatRepositoryFake(
                conversationsResult: .success([
                    unreadConversation,
                    ownLatestConversation,
                    emptyConversation,
                ])
            )
        )

        await store.loadConversations()

        #expect(store.unreadConversationCount == 1)
        #expect(store.hasUnreadMessages(in: unreadConversation))
        #expect(!store.hasUnreadMessages(in: ownLatestConversation))
        #expect(!store.hasUnreadMessages(in: emptyConversation))
    }

    @Test @MainActor
    func loadingMessagesMarksConversationReadForBadgeCount() async throws {
        let participantID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let otherParticipantID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let conversation = Self.conversation(
            customerID: participantID,
            groomerID: otherParticipantID,
            latestMessageSenderID: otherParticipantID,
            latestMessageCreatedAt: "2026-06-21T05:10:00Z",
            latestMessageBody: "Could you confirm pickup?"
        )
        let repository = ChatRepositoryFake(
            conversationsResult: .success([conversation]),
            messagesResult: .success([
                Self.message(
                    conversationID: conversation.id,
                    senderID: otherParticipantID,
                    body: "Could you confirm pickup?",
                    createdAt: "2026-06-21T05:10:00Z"
                )
            ])
        )
        let store = ChatStore(
            participantID: participantID,
            role: .customer,
            repository: repository
        )

        await store.loadConversations()
        #expect(store.unreadConversationCount == 1)

        await store.loadMessages(for: conversation)

        #expect(store.unreadConversationCount == 0)
        #expect(!store.hasUnreadMessages(in: conversation))
    }

    @Test @MainActor
    func missingBookingConversationReportsSafeUnavailableMessage() async throws {
        let store = ChatStore(
            participantID: UUID(),
            role: .customer,
            repository: ChatRepositoryFake()
        )

        store.reportMissingConversationForBooking()

        #expect(store.errorMessage == "Booking chat is not available yet.")
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

    @Test @MainActor
    func messageSubscriptionAppendsRemoteMessagesAndDeduplicates() async throws {
        let conversation = Self.conversation(latestMessageBody: "Original preview")
        let remoteMessage = Self.message(
            id: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
            conversationID: conversation.id,
            senderID: conversation.groomerID,
            body: "Remote hello"
        )
        let repository = ChatRepositoryFake()
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.startMessageSubscription(for: conversation)
        repository.yieldMessageEvent(remoteMessage)
        repository.yieldMessageEvent(remoteMessage)
        try await Self.waitForMessages([remoteMessage], in: store, conversationID: conversation.id)

        #expect(repository.messageEventsCallCount == 1)
        #expect(repository.lastMessageEventsConversationID == conversation.id)
        #expect(store.messages(for: conversation.id) == [remoteMessage])
        #expect(store.previewText(for: conversation) == "Remote hello")
    }

    @Test @MainActor
    func startingSameMessageSubscriptionTwiceKeepsSingleStream() async throws {
        let conversation = Self.conversation()
        let repository = ChatRepositoryFake()
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.startMessageSubscription(for: conversation)
        await store.startMessageSubscription(for: conversation)

        #expect(repository.messageEventsCallCount == 1)
    }

    @Test @MainActor
    func stoppingMessageSubscriptionIgnoresLaterEvents() async throws {
        let conversation = Self.conversation()
        let firstMessage = Self.message(
            id: UUID(uuidString: "44444444-4444-4444-8444-444444444444")!,
            conversationID: conversation.id,
            body: "Before stop"
        )
        let laterMessage = Self.message(
            id: UUID(uuidString: "55555555-5555-4555-8555-555555555555")!,
            conversationID: conversation.id,
            body: "After stop"
        )
        let repository = ChatRepositoryFake()
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.startMessageSubscription(for: conversation)
        repository.yieldMessageEvent(firstMessage)
        try await Self.waitForMessages([firstMessage], in: store, conversationID: conversation.id)

        store.stopMessageSubscription(for: conversation.id)
        repository.yieldMessageEvent(laterMessage)
        try await Task.sleep(nanoseconds: 25_000_000)

        #expect(store.messages(for: conversation.id) == [firstMessage])
    }

    @Test @MainActor
    func finishedMessageSubscriptionCanBeStartedAgain() async throws {
        let conversation = Self.conversation()
        let repository = ChatRepositoryFake()
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.startMessageSubscription(for: conversation)
        repository.finishMessageEvents()

        for _ in 0..<20 {
            await store.startMessageSubscription(for: conversation)
            if repository.messageEventsCallCount == 2 {
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(repository.messageEventsCallCount == 2)
    }

    @Test @MainActor
    func messageSubscriptionFailureDoesNotShowUserFacingError() async throws {
        let conversation = Self.conversation()
        let repository = ChatRepositoryFake(
            messageEventsResult: .failure(.networkUnavailable)
        )
        let store = ChatStore(
            participantID: conversation.customerID,
            role: .customer,
            repository: repository
        )

        await store.startMessageSubscription(for: conversation)

        #expect(repository.messageEventsCallCount == 1)
        #expect(store.errorMessage == nil)
    }

    @Test
    func conversationReferencesAreShortAndRoleSpecific() {
        let conversation = Self.conversation(
            bookingID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            customerID: UUID(uuidString: "12345678-0000-0000-0000-000000000000")!,
            groomerID: UUID(uuidString: "87654321-0000-0000-0000-000000000000")!
        )

        #expect(conversation.latestBookingReferenceCode == "11111111")
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

    @Test @MainActor
    func customerConversationCarriesTheLoadedGroomerAvatar() {
        let avatarData = Data([0x07, 0x08, 0x09])
        let conversation = Self.conversation(
            groomerAvatarPhotoData: avatarData
        )

        #expect(conversation.groomerAvatarPhotoData == avatarData)
    }

    private static func conversation(
        id: UUID = UUID(),
        bookingID: UUID = UUID(),
        customerID: UUID = UUID(),
        groomerID: UUID = UUID(),
        scheduledStart: String? = nil,
        scheduledEnd: String? = nil,
        priceEstimate: Double? = nil,
        status: BookingStatus? = nil,
        completedAt: String? = nil,
        groomerBusinessName: String? = nil,
        groomerAvatarPhotoData: Data? = nil,
        latestMessageSenderID: UUID? = nil,
        latestMessageCreatedAt: String? = nil,
        latestMessageBody: String? = nil
    ) -> ChatConversation {
        ChatConversation(
            id: id,
            customerID: customerID,
            groomerID: groomerID,
            latestBookingID: bookingID,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            priceEstimate: priceEstimate,
            bookingStatus: status,
            completedAt: completedAt,
            groomerBusinessName: groomerBusinessName,
            groomerAvatarPhotoData: groomerAvatarPhotoData,
            latestMessageSenderID: latestMessageSenderID,
            latestMessageCreatedAt: latestMessageCreatedAt,
            latestMessageBody: latestMessageBody,
            createdAt: "2026-06-21T05:00:00Z",
            updatedAt: "2026-06-21T05:00:00Z"
        )
    }

    private static func message(
        id: UUID = UUID(),
        conversationID: UUID = UUID(),
        senderID: UUID = UUID(),
        body: String = "Hello",
        createdAt: String = "2026-06-21T05:01:00Z"
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationID: conversationID,
            senderID: senderID,
            kind: .text,
            body: body,
            booking: nil,
            createdAt: createdAt
        )
    }

    private static func booking(
        id: UUID = UUID(),
        customerID: UUID = UUID(),
        groomerID: UUID = UUID(),
        status: BookingStatus = .confirmed
    ) -> Booking {
        Booking(
            id: id,
            requestID: UUID(),
            offerID: UUID(),
            customerID: customerID,
            groomerID: groomerID,
            scheduledStart: "2026-06-21T17:00:00Z",
            scheduledEnd: "2026-06-21T18:00:00Z",
            priceEstimate: 125,
            status: status,
            cancelledBy: status.isCancellation ? customerID : nil,
            cancelledAt: status.isCancellation ? "2026-06-21T05:00:00Z" : nil,
            completedAt: nil,
            completedBy: nil,
            createdAt: "2026-06-21T04:00:00Z",
            updatedAt: "2026-06-21T05:00:00Z",
            review: nil
        )
    }

    @MainActor
    private static func waitForMessages(
        _ expectedMessages: [ChatMessage],
        in store: ChatStore,
        conversationID: UUID
    ) async throws {
        for _ in 0..<20 {
            if store.messages(for: conversationID) == expectedMessages {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(store.messages(for: conversationID) == expectedMessages)
    }
}

private final class ChatReadStateCacheFake: ChatReadStateCaching {
    private var values: [String: [UUID: String]] = [:]

    func timestamps(participantID: UUID, role: UserRole) -> [UUID: String] {
        values[key(participantID, role), default: [:]]
    }

    func save(_ timestamps: [UUID: String], participantID: UUID, role: UserRole) {
        values[key(participantID, role)] = timestamps
    }

    private func key(_ participantID: UUID, _ role: UserRole) -> String {
        "\(role.rawValue):\(participantID.uuidString)"
    }
}

@MainActor
private final class ChatRepositoryFake: ChatRepository {
    var conversationsResult: Result<[ChatConversation], ChatRepositoryError>
    var messagesResult: Result<[ChatMessage], ChatRepositoryError>
    var conversationPages: [Result<ListPage<ChatConversation>, ChatRepositoryError>]
    var messagePages: [Result<ListPage<ChatMessage>, ChatRepositoryError>]
    var sendResult: Result<ChatMessage, ChatRepositoryError>
    var messageEventsResult: Result<Void, ChatRepositoryError>

    private(set) var conversationsCallCount = 0
    private(set) var messagesCallCount = 0
    private(set) var receivedConversationPages: [ListPageRequest] = []
    private(set) var receivedMessagePages: [ListPageRequest] = []
    private(set) var sendCallCount = 0
    private(set) var lastParticipantID: UUID?
    private(set) var lastRole: UserRole?
    private(set) var lastConversationID: UUID?
    private(set) var lastSentConversationID: UUID?
    private(set) var lastSenderID: UUID?
    private(set) var lastBody: String?
    private(set) var messageEventsCallCount = 0
    private(set) var lastMessageEventsConversationID: UUID?
    private var messageEventContinuations: [AsyncStream<ChatMessage>.Continuation] = []

    init(
        conversationsResult: Result<[ChatConversation], ChatRepositoryError> =
            .success([]),
        messagesResult: Result<[ChatMessage], ChatRepositoryError> = .success([]),
        conversationPages: [Result<ListPage<ChatConversation>, ChatRepositoryError>] = [],
        messagePages: [Result<ListPage<ChatMessage>, ChatRepositoryError>] = [],
        sendResult: Result<ChatMessage, ChatRepositoryError> =
            .failure(.unavailable),
        messageEventsResult: Result<Void, ChatRepositoryError> = .success(())
    ) {
        self.conversationsResult = conversationsResult
        self.messagesResult = messagesResult
        self.conversationPages = conversationPages
        self.messagePages = messagePages
        self.sendResult = sendResult
        self.messageEventsResult = messageEventsResult
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

    func conversations(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<ChatConversation> {
        conversationsCallCount += 1
        lastParticipantID = participantID
        lastRole = role
        receivedConversationPages.append(page)
        if !conversationPages.isEmpty {
            return try conversationPages.removeFirst().get()
        }

        return ListPage(
            items: try conversationsResult.get(),
            request: page,
            hasMore: false
        )
    }

    func messages(
        conversationID: UUID
    ) async throws -> [ChatMessage] {
        messagesCallCount += 1
        lastConversationID = conversationID
        return try messagesResult.get()
    }

    func messages(
        conversationID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<ChatMessage> {
        messagesCallCount += 1
        lastConversationID = conversationID
        receivedMessagePages.append(page)
        if !messagePages.isEmpty {
            return try messagePages.removeFirst().get()
        }

        return ListPage(
            items: try messagesResult.get(),
            request: page,
            hasMore: false
        )
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

    func messageEvents(
        conversationID: UUID
    ) async throws -> AsyncStream<ChatMessage> {
        messageEventsCallCount += 1
        lastMessageEventsConversationID = conversationID
        try messageEventsResult.get()
        return AsyncStream { continuation in
            messageEventContinuations.append(continuation)
        }
    }

    func yieldMessageEvent(_ message: ChatMessage) {
        messageEventContinuations.last?.yield(message)
    }

    func finishMessageEvents() {
        messageEventContinuations.last?.finish()
        _ = messageEventContinuations.popLast()
    }

}
