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
    func markAllReadReplacesNotificationsWithRepositoryResult() async throws {
        let customerID = UUID()
        let first = Self.notification(customerID: customerID, kind: .requestPublished)
        let second = Self.notification(customerID: customerID, kind: .bookingCancelled)
        let updated = [
            first.replacingReadState(isRead: true, readAt: "2026-07-06T12:30:00Z"),
            second.replacingReadState(isRead: true, readAt: "2026-07-06T12:30:00Z"),
        ]
        let repository = CustomerNotificationRepositoryFake(
            notificationsResult: .success([first, second]),
            markAllReadResult: .success(updated)
        )
        let store = CustomerNotificationsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        await store.markAllRead()

        #expect(repository.markAllReadCallCount == 1)
        #expect(repository.lastMarkAllCustomerID == customerID)
        #expect(store.notifications == updated)
        #expect(store.unreadCount == 0)
    }

    private static func notification(
        customerID: UUID,
        kind: CustomerNotificationKind,
        isRead: Bool = false,
        createdAt: String = "2026-07-06T12:00:00Z"
    ) -> CustomerNotification {
        CustomerNotification(
            id: UUID(),
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
        return try markReadResult.get()
    }

    func markAllRead(customerID: UUID) async throws -> [CustomerNotification] {
        markAllReadCallCount += 1
        lastMarkAllCustomerID = customerID
        return try markAllReadResult.get()
    }
}
