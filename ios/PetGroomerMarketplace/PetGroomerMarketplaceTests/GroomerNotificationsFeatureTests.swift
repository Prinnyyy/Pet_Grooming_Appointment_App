import Foundation
import Testing
@testable import PetGroomerMarketplace

struct GroomerNotificationsStoreTests {
    @Test @MainActor
    func loadFetchesNotificationsAndTracksUnreadCount() async throws {
        let groomerID = UUID()
        let unread = Self.notification(
            groomerID: groomerID,
            kind: .newMatch,
            isRead: false,
            createdAt: "2026-07-09T12:00:00Z"
        )
        let read = Self.notification(
            groomerID: groomerID,
            kind: .offerAccepted,
            isRead: true,
            createdAt: "2026-07-09T11:00:00Z"
        )
        let repository = GroomerNotificationRepositoryFake(
            notificationsResult: .success([read, unread])
        )
        let store = GroomerNotificationsStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(repository.notificationsCallCount == 1)
        #expect(repository.lastGroomerID == groomerID)
        #expect(store.notifications == [unread, read])
        #expect(store.unreadCount == 1)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func loadUsesStableIDTieBreakerForSameTimestampNotifications() async throws {
        let groomerID = UUID()
        let highIDNotification = Self.notification(
            id: UUID(uuidString: "FFFFFFFF-FFFF-4FFF-BFFF-FFFFFFFFFFFF")!,
            groomerID: groomerID,
            kind: .newMessage
        )
        let lowIDNotification = Self.notification(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            groomerID: groomerID,
            kind: .bookingCancelledByCustomer
        )
        let repository = GroomerNotificationRepositoryFake(
            notificationsResult: .success([highIDNotification, lowIDNotification])
        )
        let store = GroomerNotificationsStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(store.notifications == [lowIDNotification, highIDNotification])
        #expect(store.unreadCount == 2)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func markReadUpdatesOneLocalNotification() async throws {
        let groomerID = UUID()
        let unread = Self.notification(
            groomerID: groomerID,
            kind: .newMatch,
            isRead: false
        )
        let read = unread.replacingReadState(
            isRead: true,
            readAt: "2026-07-09T12:30:00Z"
        )
        let repository = GroomerNotificationRepositoryFake(
            notificationsResult: .success([unread]),
            markReadResult: .success(read)
        )
        let store = GroomerNotificationsStore(
            groomerID: groomerID,
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
        let groomerID = UUID()
        let first = Self.notification(
            id: UUID(uuidString: "FFFFFFFF-FFFF-4FFF-BFFF-FFFFFFFFFFFF")!,
            groomerID: groomerID,
            kind: .newMatch
        )
        let second = Self.notification(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            groomerID: groomerID,
            kind: .newMessage
        )
        let updatedFirst = first.replacingReadState(
            isRead: true,
            readAt: "2026-07-09T12:30:00Z"
        )
        let updatedSecond = second.replacingReadState(
            isRead: true,
            readAt: "2026-07-09T12:30:00Z"
        )
        let repository = GroomerNotificationRepositoryFake(
            notificationsResult: .success([first, second]),
            markAllReadResult: .success([updatedFirst, updatedSecond])
        )
        let store = GroomerNotificationsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.markAllRead()

        #expect(repository.markAllReadCallCount == 1)
        #expect(repository.lastMarkAllGroomerID == groomerID)
        #expect(store.notifications == [updatedSecond, updatedFirst])
        #expect(store.unreadCount == 0)
    }

    @Test @MainActor
    func duplicateConcurrentMarkAllReadOnlyCallsRepositoryOnce() async throws {
        let groomerID = UUID()
        let unread = Self.notification(
            groomerID: groomerID,
            kind: .newMatch,
            isRead: false
        )
        let read = unread.replacingReadState(
            isRead: true,
            readAt: "2026-07-09T12:30:00Z"
        )
        let repository = GroomerNotificationRepositoryFake(
            notificationsResult: .success([unread]),
            markAllReadResult: .success([read])
        )
        repository.markAllReadDelayNanoseconds = 80_000_000
        let store = GroomerNotificationsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        let firstTask = Task { await store.markAllRead() }
        await Task.yield()
        await store.markAllRead()
        await firstTask.value

        #expect(repository.markAllReadCallCount == 1)
        #expect(store.notifications == [read])
        #expect(store.unreadCount == 0)
    }

    @Test @MainActor
    func loadCancellationPreservesExistingNotificationsWithoutError() async throws {
        let groomerID = UUID()
        let existing = Self.notification(
            groomerID: groomerID,
            kind: .newMessage,
            isRead: false
        )
        let repository = GroomerNotificationRepositoryFake(
            notificationsResult: .success([existing])
        )
        let store = GroomerNotificationsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        repository.notificationsResult = .failure(.cancelled)
        await store.load()

        #expect(repository.notificationsCallCount == 2)
        #expect(store.notifications == [existing])
        #expect(store.unreadCount == 1)
        #expect(store.errorMessage == nil)
    }

    @Test
    func unknownGroomerNotificationKindDecodesToUnknownFallback() throws {
        let decoded = try JSONDecoder().decode(
            GroomerNotificationKind.self,
            from: Data(#""backend_added_new_kind""#.utf8)
        )

        #expect(decoded.rawValue == "unknown")
        #expect(decoded.defaultTitle == "Notification")
        #expect(decoded.systemImage == "bell.fill")
    }

    @Test @MainActor
    func debugRepositoryRecordsGroomerNotificationCancellationAsInfoEvent() async throws {
        let groomerID = UUID()
        let writer = AppDebugEventWriterSpy()
        let recorder = AppDebugEventRecorder(
            writer: writer,
            emitsToOSLog: false
        )
        let repository = DebugGroomerNotificationRepository(
            base: GroomerNotificationRepositoryFake(
                notificationsResult: .failure(.cancelled)
            ),
            debugRecorder: recorder
        )

        do {
            _ = try await repository.notifications(groomerID: groomerID)
        } catch GroomerNotificationRepositoryError.cancelled {
        }

        let event = try #require(
            recorder.events.first {
                $0.source == "GroomerNotificationRepository.notifications"
            }
        )
        #expect(event.level == .info)
        #expect(event.category == .repository)
        #expect(event.scope == "groomer.notifications")
        #expect(event.message == "cancelled")
        #expect(event.metadata["operation"] == "notifications")
        #expect(event.metadata["table"] == "groomer_notifications")
        #expect(event.metadata["groomerID"] == groomerID.uuidString.prefix(8).uppercased())
        #expect(event.underlyingErrorType == "GroomerNotificationRepositoryError")
        #expect(event.underlyingErrorCode == "cancelled")
    }

    @Test
    func notificationsMapToExpectedGroomerRoutes() {
        let requestID = UUID()
        let bookingID = UUID()
        let offerID = UUID()

        #expect(
            Self.notification(
                groomerID: UUID(),
                kind: .newMatch,
                relatedRequestID: requestID
            ).route == .requests(requestID: requestID)
        )
        #expect(
            Self.notification(
                groomerID: UUID(),
                kind: .offerAccepted,
                relatedBookingID: bookingID,
                relatedOfferID: offerID
            ).route == .bookings(bookingID: bookingID)
        )
        #expect(
            Self.notification(
                groomerID: UUID(),
                kind: .bookingCancelledByCustomer,
                relatedBookingID: bookingID
            ).route == .bookings(bookingID: bookingID)
        )
        #expect(
            Self.notification(
                groomerID: UUID(),
                kind: .newMessage,
                relatedBookingID: bookingID
            ).route == .messages(bookingID: bookingID)
        )
    }

    private static func notification(
        id: UUID = UUID(),
        groomerID: UUID,
        kind: GroomerNotificationKind,
        isRead: Bool = false,
        createdAt: String = "2026-07-09T12:00:00Z",
        relatedRequestID: UUID? = UUID(),
        relatedBookingID: UUID? = nil,
        relatedOfferID: UUID? = nil
    ) -> GroomerNotification {
        GroomerNotification(
            id: id,
            groomerID: groomerID,
            kind: kind,
            title: kind.defaultTitle,
            body: "System message",
            isRead: isRead,
            createdAt: createdAt,
            readAt: isRead ? "2026-07-09T12:15:00Z" : nil,
            relatedRequestID: relatedRequestID,
            relatedBookingID: relatedBookingID,
            relatedOfferID: relatedOfferID
        )
    }
}

@MainActor
private final class GroomerNotificationRepositoryFake: GroomerNotificationRepository {
    var notificationsResult: Result<[GroomerNotification], GroomerNotificationRepositoryError>
    var markReadResult: Result<GroomerNotification, GroomerNotificationRepositoryError>
    var markAllReadResult: Result<[GroomerNotification], GroomerNotificationRepositoryError>
    var markAllReadDelayNanoseconds: UInt64 = 0

    private(set) var notificationsCallCount = 0
    private(set) var markReadCallCount = 0
    private(set) var markAllReadCallCount = 0
    private(set) var lastGroomerID: UUID?
    private(set) var lastMarkedNotificationID: UUID?
    private(set) var lastMarkAllGroomerID: UUID?

    init(
        notificationsResult: Result<[GroomerNotification], GroomerNotificationRepositoryError> = .success([]),
        markReadResult: Result<GroomerNotification, GroomerNotificationRepositoryError> = .failure(.unavailable),
        markAllReadResult: Result<[GroomerNotification], GroomerNotificationRepositoryError> = .success([])
    ) {
        self.notificationsResult = notificationsResult
        self.markReadResult = markReadResult
        self.markAllReadResult = markAllReadResult
    }

    func notifications(groomerID: UUID) async throws -> [GroomerNotification] {
        notificationsCallCount += 1
        lastGroomerID = groomerID
        return try notificationsResult.get()
    }

    func markRead(notificationID: UUID) async throws -> GroomerNotification {
        markReadCallCount += 1
        lastMarkedNotificationID = notificationID
        return try markReadResult.get()
    }

    func markAllRead(groomerID: UUID) async throws -> [GroomerNotification] {
        markAllReadCallCount += 1
        lastMarkAllGroomerID = groomerID
        if markAllReadDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: markAllReadDelayNanoseconds)
        }
        return try markAllReadResult.get()
    }
}
