import Foundation

enum CustomerNotificationRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case notificationNotFound
    case invalidInput
    case networkUnavailable
    case cancelled
    case unavailable
}

@MainActor
protocol CustomerNotificationRepository: AnyObject {
    func notifications(customerID: UUID) async throws -> [CustomerNotification]

    func markRead(
        notificationID: UUID
    ) async throws -> CustomerNotification

    func markAllRead(
        customerID: UUID
    ) async throws -> [CustomerNotification]
}
