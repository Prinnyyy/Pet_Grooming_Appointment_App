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

    func notifications(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerNotification>

    func markRead(
        notificationID: UUID
    ) async throws -> GroomerNotification

    func markAllRead(
        groomerID: UUID
    ) async throws -> [GroomerNotification]
}

extension GroomerNotificationRepository {
    func notifications(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerNotification> {
        ListPage(
            items: try await notifications(groomerID: groomerID),
            request: page,
            hasMore: false
        )
    }
}
