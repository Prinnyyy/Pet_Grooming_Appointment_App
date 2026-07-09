import Foundation
import Observation

@MainActor
@Observable
final class GroomerNotificationsStore {
    private let groomerID: UUID
    private let repository: any GroomerNotificationRepository

    private(set) var notifications: [GroomerNotification] = []
    private(set) var isLoading = false
    private(set) var isMarkingAllRead = false
    private(set) var markingNotificationIDs: Set<UUID> = []

    var errorMessage: String?

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    init(
        groomerID: UUID,
        repository: any GroomerNotificationRepository
    ) {
        self.groomerID = groomerID
        self.repository = repository
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            notifications = Self.displayOrdered(
                try await repository.notifications(groomerID: groomerID)
            )
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

    func markRead(_ notification: GroomerNotification) async {
        guard !notification.isRead else { return }
        guard !markingNotificationIDs.contains(notification.id) else { return }

        markingNotificationIDs.insert(notification.id)
        errorMessage = nil
        defer {
            markingNotificationIDs.remove(notification.id)
        }

        do {
            replace(try await repository.markRead(notificationID: notification.id))
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
        guard unreadCount > 0, !isMarkingAllRead else { return }

        isMarkingAllRead = true
        errorMessage = nil
        defer { isMarkingAllRead = false }

        do {
            notifications = Self.displayOrdered(
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
