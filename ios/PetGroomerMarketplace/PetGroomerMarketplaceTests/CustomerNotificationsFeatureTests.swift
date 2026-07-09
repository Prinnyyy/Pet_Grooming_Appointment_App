import Foundation
import Testing
@testable import PetGroomerMarketplace

struct CustomerNotificationsStoreTests {
    @Test @MainActor
    func loadFetchesNotificationsAndTracksUnreadCount() async throws {
        let customerID = UUID()
        let unread = Self.notification(
            customerID: customerID,
            kind: .requestPublished,
            isRead: false,
            createdAt: "2026-07-06T12:00:00Z"
        )
        let read = Self.notification(
            customerID: customerID,
            kind: .bookingConfirmed,
            isRead: true,
            createdAt: "2026-07-06T11:00:00Z"
        )
        let repository = CustomerNotificationRepositoryFake(
            notificationsResult: .success([read, unread])
        )
        let store = CustomerNotificationsStore(
            customerID: customerID,
            repository: repository
        )

        await store.load()

        #expect(repository.notificationsCallCount == 1)
        #expect(repository.lastCustomerID == customerID)
        #expect(store.notifications == [unread, read])
        #expect(store.unreadCount == 1)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func loadUsesStableIDTieBreakerForSameTimestampNotifications() async throws {
        let customerID = UUID()
        let highIDNotification = Self.notification(
            id: UUID(uuidString: "FFFFFFFF-FFFF-4FFF-BFFF-FFFFFFFFFFFF")!,
            customerID: customerID,
            kind: .newOffer
        )
        let lowIDNotification = Self.notification(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            customerID: customerID,
            kind: .bookingConfirmed
        )
        let repository = CustomerNotificationRepositoryFake(
            notificationsResult: .success([highIDNotification, lowIDNotification])
        )
        let store = CustomerNotificationsStore(
            customerID: customerID,
            repository: repository
        )

        await store.load()

        #expect(store.notifications == [lowIDNotification, highIDNotification])
        #expect(store.unreadCount == 2)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func markReadUpdatesOneLocalNotification() async throws {
        let customerID = UUID()
        let unread = Self.notification(
            customerID: customerID,
            kind: .requestCancelled,
            isRead: false
        )
        let read = unread.replacingReadState(
            isRead: true,
            readAt: "2026-07-06T12:30:00Z"
        )
        let repository = CustomerNotificationRepositoryFake(
            notificationsResult: .success([unread]),
            markReadResult: .success(read)
        )
        let store = CustomerNotificationsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        await store.markRead(unread)

        #expect(repository.markReadCallCount == 1)
        #expect(repository.lastMarkedNotificationID == unread.id)
        #expect(store.notifications == [read])
        #expect(store.unreadCount == 0)
    }

    @Test @MainActor
    func markAllReadAppliesStableDisplayOrderForSameTimestampNotifications() async throws {
        let customerID = UUID()
        let first = Self.notification(
            id: UUID(uuidString: "FFFFFFFF-FFFF-4FFF-BFFF-FFFFFFFFFFFF")!,
            customerID: customerID,
            kind: .requestPublished
        )
        let second = Self.notification(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            customerID: customerID,
            kind: .bookingCancelled
        )
        let updatedFirst = first.replacingReadState(
            isRead: true,
            readAt: "2026-07-06T12:30:00Z"
        )
        let updatedSecond = second.replacingReadState(
            isRead: true,
            readAt: "2026-07-06T12:30:00Z"
        )
        let repository = CustomerNotificationRepositoryFake(
            notificationsResult: .success([first, second]),
            markAllReadResult: .success([updatedFirst, updatedSecond])
        )
        let store = CustomerNotificationsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        await store.markAllRead()

        #expect(repository.markAllReadCallCount == 1)
        #expect(repository.lastMarkAllCustomerID == customerID)
        #expect(store.notifications == [updatedSecond, updatedFirst])
        #expect(store.unreadCount == 0)
    }

    @Test @MainActor
    func duplicateConcurrentMarkReadOnlyCallsRepositoryOnce() async throws {
        let customerID = UUID()
        let unread = Self.notification(
            customerID: customerID,
            kind: .newOffer,
            isRead: false
        )
        let read = unread.replacingReadState(
            isRead: true,
            readAt: "2026-07-06T12:30:00Z"
        )
        let repository = CustomerNotificationRepositoryFake(
            notificationsResult: .success([unread]),
            markReadResult: .success(read)
        )
        repository.markReadDelayNanoseconds = 80_000_000
        let store = CustomerNotificationsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        let firstTask = Task { await store.markRead(unread) }
        await Task.yield()
        await store.markRead(unread)
        await firstTask.value

        #expect(repository.markReadCallCount == 1)
        #expect(store.notifications == [read])
        #expect(store.unreadCount == 0)
    }

    @Test @MainActor
    func markAllReadFailurePreservesNotificationsAndShowsError() async throws {
        let customerID = UUID()
        let unread = Self.notification(
            customerID: customerID,
            kind: .newMessage,
            isRead: false
        )
        let repository = CustomerNotificationRepositoryFake(
            notificationsResult: .success([unread]),
            markAllReadResult: .failure(.networkUnavailable)
        )
        let store = CustomerNotificationsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        await store.markAllRead()

        #expect(repository.markAllReadCallCount == 1)
        #expect(store.notifications == [unread])
        #expect(store.unreadCount == 1)
        #expect(store.errorMessage == "Notifications unavailable. Check your connection and try again.")
    }

    @Test
    func unknownCustomerNotificationKindDecodesToUnknownFallback() throws {
        let decoded = try JSONDecoder().decode(
            CustomerNotificationKind.self,
            from: Data(#""backend_added_new_kind""#.utf8)
        )

        #expect(decoded.rawValue == "unknown")
        #expect(decoded.defaultTitle == "Notification")
        #expect(decoded.systemImage == "bell.fill")
    }

    @Test @MainActor
    func debugRepositoryRecordsCustomerNotificationFailureEvent() async throws {
        let customerID = UUID()
        let writer = AppDebugEventWriterSpy()
        let recorder = AppDebugEventRecorder(
            writer: writer,
            emitsToOSLog: false
        )
        let repository = DebugCustomerNotificationRepository(
            base: CustomerNotificationRepositoryFake(
                notificationsResult: .failure(.networkUnavailable)
            ),
            debugRecorder: recorder
        )

        do {
            _ = try await repository.notifications(customerID: customerID)
        } catch CustomerNotificationRepositoryError.networkUnavailable {
        }

        let event = try #require(
            recorder.events.first {
                $0.source == "CustomerNotificationRepository.notifications"
            }
        )
        #expect(event.level == .error)
        #expect(event.category == .repository)
        #expect(event.scope == "customer.notifications")
        #expect(event.metadata["operation"] == "notifications")
        #expect(event.metadata["table"] == "customer_notifications")
        #expect(event.metadata["customerID"] == customerID.uuidString.prefix(8).uppercased())
        #expect(event.underlyingErrorType == "CustomerNotificationRepositoryError")
        #expect(event.underlyingErrorCode == "networkUnavailable")
    }

    private static func notification(
        id: UUID = UUID(),
        customerID: UUID,
        kind: CustomerNotificationKind,
        isRead: Bool = false,
        createdAt: String = "2026-07-06T12:00:00Z"
    ) -> CustomerNotification {
        CustomerNotification(
            id: id,
            customerID: customerID,
            kind: kind,
            title: kind.defaultTitle,
            body: "System message",
            isRead: isRead,
            createdAt: createdAt,
            readAt: isRead ? "2026-07-06T12:15:00Z" : nil,
            relatedRequestID: UUID(),
            relatedBookingID: nil,
            relatedOfferID: nil
        )
    }
}

@MainActor
private final class CustomerNotificationRepositoryFake: CustomerNotificationRepository {
    var notificationsResult: Result<[CustomerNotification], CustomerNotificationRepositoryError>
    var markReadResult: Result<CustomerNotification, CustomerNotificationRepositoryError>
    var markAllReadResult: Result<[CustomerNotification], CustomerNotificationRepositoryError>
    var markReadDelayNanoseconds: UInt64 = 0

    private(set) var notificationsCallCount = 0
    private(set) var markReadCallCount = 0
    private(set) var markAllReadCallCount = 0
    private(set) var lastCustomerID: UUID?
    private(set) var lastMarkedNotificationID: UUID?
    private(set) var lastMarkAllCustomerID: UUID?

    init(
        notificationsResult: Result<[CustomerNotification], CustomerNotificationRepositoryError> = .success([]),
        markReadResult: Result<CustomerNotification, CustomerNotificationRepositoryError> = .failure(.unavailable),
        markAllReadResult: Result<[CustomerNotification], CustomerNotificationRepositoryError> = .success([])
    ) {
        self.notificationsResult = notificationsResult
        self.markReadResult = markReadResult
        self.markAllReadResult = markAllReadResult
    }

    func notifications(customerID: UUID) async throws -> [CustomerNotification] {
        notificationsCallCount += 1
        lastCustomerID = customerID
        return try notificationsResult.get()
    }

    func markRead(notificationID: UUID) async throws -> CustomerNotification {
        markReadCallCount += 1
        lastMarkedNotificationID = notificationID
        if markReadDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: markReadDelayNanoseconds)
        }
        return try markReadResult.get()
    }

    func markAllRead(customerID: UUID) async throws -> [CustomerNotification] {
        markAllReadCallCount += 1
        lastMarkAllCustomerID = customerID
        return try markAllReadResult.get()
    }
}
