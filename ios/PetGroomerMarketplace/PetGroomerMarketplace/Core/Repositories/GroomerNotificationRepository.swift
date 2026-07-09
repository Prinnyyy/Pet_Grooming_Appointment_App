import Foundation

enum GroomerNotificationRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case notificationNotFound
    case invalidInput
    case networkUnavailable
    case cancelled
    case unavailable
}

@MainActor
protocol GroomerNotificationRepository: AnyObject {
    func notifications(groomerID: UUID) async throws -> [GroomerNotification]

    func markRead(
        notificationID: UUID
    ) async throws -> GroomerNotification

    func markAllRead(
        groomerID: UUID
    ) async throws -> [GroomerNotification]
}
