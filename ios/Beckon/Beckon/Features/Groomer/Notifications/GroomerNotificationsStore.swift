import Foundation
import Observation

@MainActor
@Observable
final class GroomerNotificationsStore {
    private let groomerID: UUID
    private let repository: any GroomerNotificationRepository

    private(set) var notifications: [GroomerNotification] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var isMarkingAllRead = false
    private(set) var markingNotificationIDs: Set<UUID> = []
    private(set) var nextPageRequest: ListPageRequest?

    var errorMessage: String?

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var canLoadMore: Bool {
        nextPageRequest != nil
    }

    init(
        groomerID: UUID,
        repository: any GroomerNotificationRepository
    ) {
        self.groomerID = groomerID
        self.repository = repository
    }

    func load() async {
        guard !isLoading, !isLoadingMore else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await repository.notifications(
                groomerID: groomerID,
                page: .first
            )
            notifications = Self.displayOrdered(page.items)
            nextPageRequest = page.nextRequest
        } catch GroomerNotificationRepositoryError.cancelled {
            return
        } catch let error as GroomerNotificationRepositoryError {
            errorMessage = Self.message(for: error, action: "load")
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            errorMessage = Self.message(for: .unavailable, action: "load")
        }
    }

    func loadNextPage() async {
        guard !isLoading,
              !isLoadingMore,
              let pageRequest = nextPageRequest else { return }

        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let page = try await repository.notifications(
                groomerID: groomerID,
                page: pageRequest
            )
            notifications = Self.displayOrdered(
                ListPageMerge.appendingUnique(page.items, to: notifications)
            )
            nextPageRequest = page.nextRequest
        } catch GroomerNotificationRepositoryError.cancelled {
            return
        } catch let error as GroomerNotificationRepositoryError {
            errorMessage = Self.message(for: error, action: "load")
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            errorMessage = Self.message(for: .unavailable, action: "load")
        }
    }

    func resolveDestination(_ notification: GroomerNotification,
        requests: GroomerRequestsStore?, bookings: BookingsStore?, chat: ChatStore?
    ) async -> NotificationDestination? {
        guard notification.groomerID == groomerID else { return nil }
        do {
            let destination: NotificationDestination
            switch notification.kind {
            case .newMatch:
                guard let id = notification.relatedRequestID, let requests else {
                    throw GroomerNotificationRepositoryError.notificationNotFound
                }
                let item = try await requests.resolveNotificationRequest(id: id)
                destination = .request(item.id)
            case .offerAccepted, .bookingCancelledByCustomer:
                guard let id = notification.relatedBookingID, let bookings else {
                    throw GroomerNotificationRepositoryError.notificationNotFound
                }
                await bookings.resolveBooking(id: id, forceRefresh: true)
                guard bookings.bookingReadStates[id] == .complete else { throw GroomerNotificationRepositoryError.notificationNotFound }
                destination = .booking(id)
            case .newMessage:
                guard let id = notification.relatedBookingID, let chat,
                      let conversation = await chat.resolveConversation(bookingID: id) else {
                    throw GroomerNotificationRepositoryError.notificationNotFound
                }
                destination = .message(conversation)
            case .unknown: throw GroomerNotificationRepositoryError.notificationNotFound
            }
            try Task.checkCancellation()
            await markRead(notification)
            try Task.checkCancellation()
            return destination
        } catch is CancellationError { return nil }
        catch {
            guard !Task.isCancelled else { return nil }
            errorMessage = "This notification's destination could not be opened. Refresh and try again."
            return nil
        }
    }

    func markRead(_ notification: GroomerNotification) async {
        guard notification.groomerID == groomerID, !Task.isCancelled else { return }
        guard !notification.isRead else { return }
        guard !markingNotificationIDs.contains(notification.id) else { return }

        markingNotificationIDs.insert(notification.id)
        errorMessage = nil
        defer {
            markingNotificationIDs.remove(notification.id)
        }

        do {
            let result = try await repository.markRead(notificationID: notification.id)
            try Task.checkCancellation()
            guard result.id == notification.id, result.groomerID == groomerID else {
                throw GroomerNotificationRepositoryError.notAllowed
            }
            replace(result)
        } catch GroomerNotificationRepositoryError.cancelled {
            return
        } catch let error as GroomerNotificationRepositoryError {
            errorMessage = Self.message(for: error, action: "mark read")
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            errorMessage = Self.message(for: .unavailable, action: "mark read")
        }
    }

    func markAllRead() async {
        guard !isMarkingAllRead else { return }

        isMarkingAllRead = true
        errorMessage = nil
        defer { isMarkingAllRead = false }

        do {
            applyUpdates(
                try await repository.markAllRead(groomerID: groomerID)
            )
        } catch GroomerNotificationRepositoryError.cancelled {
            return
        } catch let error as GroomerNotificationRepositoryError {
            errorMessage = Self.message(for: error, action: "mark all read")
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            errorMessage = Self.message(for: .unavailable, action: "mark all read")
        }
    }

    func isMarkingRead(_ notification: GroomerNotification) -> Bool {
        markingNotificationIDs.contains(notification.id)
    }

    private func replace(_ notification: GroomerNotification?) {
        guard let notification,
              let index = notifications.firstIndex(where: { $0.id == notification.id }) else {
            return
        }

        notifications[index] = notification
        notifications = Self.displayOrdered(notifications)
    }

    private func applyUpdates(_ updates: [GroomerNotification]) {
        let updatesByID = Dictionary(uniqueKeysWithValues: updates.map { ($0.id, $0) })
        notifications = Self.displayOrdered(
            notifications.map { updatesByID[$0.id] ?? $0 }
        )
    }

    private static func displayOrdered(
        _ notifications: [GroomerNotification]
    ) -> [GroomerNotification] {
        notifications.sorted { lhs, rhs in
            if lhs.createdAtDate == rhs.createdAtDate {
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return lhs.createdAtDate > rhs.createdAtDate
        }
    }

    private static func message(
        for error: GroomerNotificationRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .networkUnavailable:
            "Notifications unavailable. Check your connection and try again."
        case .notAllowed:
            "Sign in with a groomer account to view notifications."
        case .notificationNotFound:
            "This notification is no longer available."
        case .invalidInput:
            "We could not \(action). Refresh notifications and try again."
        case .cancelled:
            ""
        case .unavailable:
            "Notifications unavailable. Try again in a moment."
        }
    }
}
