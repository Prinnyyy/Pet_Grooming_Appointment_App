import Foundation
import Observation

@MainActor
@Observable
final class CustomerNotificationsStore {
    private let customerID: UUID
    private let repository: any CustomerNotificationRepository

    private(set) var notifications: [CustomerNotification] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var isMarkingAllRead = false
    private(set) var markingNotificationIDs: Set<UUID> = []
    private(set) var nextPageRequest: ListPageRequest?
    private var needsReloadAfterCurrentLoad = false

    var errorMessage: String?

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var canLoadMore: Bool {
        nextPageRequest != nil
    }

    init(
        customerID: UUID,
        repository: any CustomerNotificationRepository
    ) {
        self.customerID = customerID
        self.repository = repository
    }

    func load() async {
        guard !isLoading, !isLoadingMore else {
            needsReloadAfterCurrentLoad = true
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            schedulePendingReloadIfNeeded()
        }

        do {
            let page = try await repository.notifications(
                customerID: customerID,
                page: .first
            )
            notifications = Self.displayOrdered(page.items)
            nextPageRequest = page.nextRequest
        } catch CustomerNotificationRepositoryError.cancelled {
            return
        } catch let error as CustomerNotificationRepositoryError {
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
        defer {
            isLoadingMore = false
            schedulePendingReloadIfNeeded()
        }

        do {
            let page = try await repository.notifications(
                customerID: customerID,
                page: pageRequest
            )
            notifications = Self.displayOrdered(
                ListPageMerge.appendingUnique(page.items, to: notifications)
            )
            nextPageRequest = page.nextRequest
        } catch CustomerNotificationRepositoryError.cancelled {
            return
        } catch let error as CustomerNotificationRepositoryError {
            errorMessage = Self.message(for: error, action: "load")
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            errorMessage = Self.message(for: .unavailable, action: "load")
        }
    }

    func resolveDestination(_ notification: CustomerNotification,
        requests: CustomerRequestsStore?, bookings: BookingsStore?, chat: ChatStore?
    ) async -> NotificationDestination? {
        guard notification.customerID == customerID else { return nil }
        do {
            let destination: NotificationDestination
            switch notification.kind {
            case .requestPublished, .requestCancelled, .newOffer:
                guard let id = notification.relatedRequestID, let requests else {
                    throw CustomerNotificationRepositoryError.notificationNotFound
                }
                let offerID = notification.kind == .newOffer ? notification.relatedOfferID : nil
                if notification.kind == .newOffer && offerID == nil { throw CustomerNotificationRepositoryError.notificationNotFound }
                _ = try await requests.resolveNotificationRequest(id: id, offerID: offerID)
                destination = offerID.map { .offer(requestID: id, offerID: $0) } ?? .request(id)
            case .bookingConfirmed, .bookingCancelled:
                guard let id = notification.relatedBookingID, let bookings else {
                    throw CustomerNotificationRepositoryError.notificationNotFound
                }
                await bookings.resolveBooking(id: id, forceRefresh: true)
                guard bookings.bookingReadStates[id] == .complete else { throw CustomerNotificationRepositoryError.notificationNotFound }
                destination = .booking(id)
            case .newMessage:
                guard let chat else {
                    throw CustomerNotificationRepositoryError.notificationNotFound
                }
                let resolved: ChatConversation?
                if let id = notification.relatedConversationID {
                    resolved = await chat.resolveConversation(conversationID: id)
                } else if let id = notification.relatedBookingID {
                    resolved = await chat.resolveConversation(bookingID: id)
                } else {
                    errorMessage = "This older notification does not identify its conversation. You can mark it as read."
                    return nil
                }
                try Task.checkCancellation()
                guard let conversation = resolved else {
                    errorMessage = chat.errorMessage ?? "This conversation is no longer available."
                    return nil
                }
                destination = .message(conversation)
            case .unknown: throw CustomerNotificationRepositoryError.notificationNotFound
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

    func markRead(_ notification: CustomerNotification) async {
        guard notification.customerID == customerID, !Task.isCancelled else { return }
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
            guard result.id == notification.id, result.customerID == customerID else {
                throw CustomerNotificationRepositoryError.notAllowed
            }
            replace(result)
        } catch CustomerNotificationRepositoryError.cancelled {
            return
        } catch let error as CustomerNotificationRepositoryError {
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
                try await repository.markAllRead(customerID: customerID)
            )
        } catch CustomerNotificationRepositoryError.cancelled {
            return
        } catch let error as CustomerNotificationRepositoryError {
            errorMessage = Self.message(for: error, action: "mark all read")
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            errorMessage = Self.message(for: .unavailable, action: "mark all read")
        }
    }

    func isMarkingRead(_ notification: CustomerNotification) -> Bool {
        markingNotificationIDs.contains(notification.id)
    }

    private func schedulePendingReloadIfNeeded() {
        guard needsReloadAfterCurrentLoad, !isLoading, !isLoadingMore else { return }
        needsReloadAfterCurrentLoad = false
        Task { await load() }
    }

    private func replace(_ notification: CustomerNotification?) {
        guard let notification,
              let index = notifications.firstIndex(where: { $0.id == notification.id }) else {
            return
        }

        notifications[index] = notification
        notifications = Self.displayOrdered(notifications)
    }

    private func applyUpdates(_ updates: [CustomerNotification]) {
        let updatesByID = Dictionary(uniqueKeysWithValues: updates.map { ($0.id, $0) })
        notifications = Self.displayOrdered(
            notifications.map { updatesByID[$0.id] ?? $0 }
        )
    }

    private static func displayOrdered(
        _ notifications: [CustomerNotification]
    ) -> [CustomerNotification] {
        notifications.sorted { lhs, rhs in
            if lhs.createdAtDate == rhs.createdAtDate {
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return lhs.createdAtDate > rhs.createdAtDate
        }
    }

    private static func message(
        for error: CustomerNotificationRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .networkUnavailable:
            "Notifications unavailable. Check your connection and try again."
        case .notAllowed:
            "Sign in with a customer account to view notifications."
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
