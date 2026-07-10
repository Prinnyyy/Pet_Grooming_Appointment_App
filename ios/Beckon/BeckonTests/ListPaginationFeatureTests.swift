import Foundation
import Testing
@testable import Beckon

struct ListPaginationFeatureTests {
    @Test
    func defaultPageRequestUsesBoundedFirstPage() {
        let request = ListPageRequest.first

        #expect(request.limit == 50)
        #expect(request.offset == 0)
        #expect(request.inclusiveRangeEnd == 50)
        #expect(request.next.offset == 50)
    }

    @Test
    func pageTrimsLimitPlusOneRowsAndReportsMorePages() {
        let rows = Array(0...50)
        let page = ListPage(items: rows, request: .first)

        #expect(page.items == Array(0..<50))
        #expect(page.hasMore == true)
        #expect(page.nextRequest == ListPageRequest(limit: 50, offset: 50))
    }

    @Test
    func pageWithoutExtraRowReportsNoMorePages() {
        let page = ListPage(items: Array(0..<12), request: .first)

        #expect(page.items == Array(0..<12))
        #expect(page.hasMore == false)
        #expect(page.nextRequest == nil)
    }

    @Test @MainActor
    func bookingsStoreLoadsFirstPageThenNextPage() async {
        let participantID = UUID()
        let firstBooking = Self.booking(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            participantID: participantID
        )
        let secondBooking = Self.booking(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            participantID: participantID
        )
        let repository = PaginatedBookingRepositoryFake(
            pages: [
                ListPage(items: [firstBooking], request: .first, hasMore: true),
                ListPage(
                    items: [secondBooking],
                    request: ListPageRequest(limit: 50, offset: 50),
                    hasMore: false
                ),
            ]
        )
        let store = BookingsStore(
            participantID: participantID,
            role: .customer,
            repository: repository,
            appointmentReminderScheduler: PaginatedAppointmentReminderSchedulerFake()
        )

        await store.load()
        await store.loadNextPage()

        #expect(repository.receivedPages == [
            .first,
            ListPageRequest(limit: 50, offset: 50),
        ])
        #expect(store.bookings.map(\.id) == [firstBooking.id, secondBooking.id])
        #expect(store.canLoadMore == false)
    }

    @Test @MainActor
    func chatStoreLoadsMessagePagesWithoutReplacingExistingMessages() async {
        let participantID = UUID()
        let conversationID = UUID()
        let conversation = Self.conversation(
            id: conversationID,
            participantID: participantID
        )
        let firstMessage = Self.message(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            conversationID: conversationID,
            senderID: participantID
        )
        let secondMessage = Self.message(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            conversationID: conversationID,
            senderID: participantID
        )
        let repository = PaginatedChatRepositoryFake(
            messages: [
                ListPage(items: [firstMessage], request: .first, hasMore: true),
                ListPage(
                    items: [secondMessage],
                    request: ListPageRequest(limit: 50, offset: 50),
                    hasMore: false
                ),
            ]
        )
        let store = ChatStore(
            participantID: participantID,
            role: .customer,
            repository: repository
        )

        await store.loadMessages(for: conversation)
        await store.loadNextMessagesPage(for: conversation)

        #expect(repository.receivedMessagePages == [
            .first,
            ListPageRequest(limit: 50, offset: 50),
        ])
        #expect(store.messages(for: conversationID).map(\.id) == [
            firstMessage.id,
            secondMessage.id,
        ])
        #expect(store.canLoadMoreMessages(for: conversationID) == false)
    }

    private static func booking(
        id: UUID,
        participantID: UUID
    ) -> Booking {
        Booking(
            id: id,
            requestID: UUID(),
            offerID: UUID(),
            customerID: participantID,
            groomerID: UUID(),
            scheduledStart: "2026-08-22T16:00:00Z",
            scheduledEnd: "2026-08-22T18:00:00Z",
            priceEstimate: 120,
            status: .confirmed,
            cancelledBy: nil,
            cancelledAt: nil,
            completedAt: nil,
            completedBy: nil,
            createdAt: "2026-08-20T12:00:00Z",
            updatedAt: "2026-08-20T12:00:00Z",
            review: nil
        )
    }

    private static func conversation(
        id: UUID,
        participantID: UUID
    ) -> ChatConversation {
        ChatConversation(
            id: id,
            bookingID: UUID(),
            requestID: UUID(),
            customerID: participantID,
            groomerID: UUID(),
            scheduledStart: "2026-08-22T16:00:00Z",
            scheduledEnd: "2026-08-22T18:00:00Z",
            priceEstimate: 120,
            bookingStatus: .confirmed,
            groomerBusinessName: "Fresh Paws",
            latestMessageSenderID: nil,
            latestMessageCreatedAt: nil,
            latestMessageBody: nil,
            createdAt: "2026-08-20T12:00:00Z",
            updatedAt: "2026-08-20T12:00:00Z"
        )
    }

    private static func message(
        id: UUID,
        conversationID: UUID,
        senderID: UUID
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationID: conversationID,
            senderID: senderID,
            body: "Hello",
            createdAt: "2026-08-20T12:00:00Z"
        )
    }
}

private struct PaginatedAppointmentReminderSchedulerFake: AppointmentReminderScheduling {
    func syncReminders(
        for bookings: [Booking],
        role: UserRole
    ) async -> AppointmentReminderSyncResult {
        .scheduled(count: 0)
    }

    func cancelReminder(for bookingID: UUID, role: UserRole) async {}
}

@MainActor
private final class PaginatedBookingRepositoryFake: BookingRepository {
    private var pages: [ListPage<Booking>]
    private(set) var receivedPages: [ListPageRequest] = []

    init(pages: [ListPage<Booking>]) {
        self.pages = pages
    }

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        []
    }

    func bookings(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<Booking> {
        receivedPages.append(page)
        return pages.removeFirst()
    }

    func acceptOffer(offerID: UUID) async throws -> AcceptGroomerOfferResult {
        throw BookingRepositoryError.unavailable
    }

    func cancelBooking(bookingID: UUID) async throws -> CancelBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func completeBooking(bookingID: UUID) async throws -> CompleteBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        throw BookingRepositoryError.unavailable
    }
}

@MainActor
private final class PaginatedChatRepositoryFake: ChatRepository {
    private var messagePages: [ListPage<ChatMessage>]
    private(set) var receivedMessagePages: [ListPageRequest] = []

    init(messages: [ListPage<ChatMessage>]) {
        messagePages = messages
    }

    func conversations(
        participantID: UUID,
        role: UserRole
    ) async throws -> [ChatConversation] {
        []
    }

    func conversations(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<ChatConversation> {
        ListPage(items: [], request: page)
    }

    func messages(
        conversationID: UUID
    ) async throws -> [ChatMessage] {
        []
    }

    func messages(
        conversationID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<ChatMessage> {
        receivedMessagePages.append(page)
        return messagePages.removeFirst()
    }

    func sendMessage(
        conversationID: UUID,
        senderID: UUID,
        body: String
    ) async throws -> ChatMessage {
        throw ChatRepositoryError.unavailable
    }

    func messageEvents(
        conversationID: UUID
    ) async throws -> AsyncStream<ChatMessage> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
