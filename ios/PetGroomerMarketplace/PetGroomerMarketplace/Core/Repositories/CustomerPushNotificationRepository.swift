import Foundation

enum CustomerPushNotificationRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case invalidToken
    case networkUnavailable
    case cancelled
    case unavailable
}

@MainActor
protocol CustomerPushNotificationRepository: AnyObject {
    func registerDeviceToken(
        customerID: UUID,
        token: CustomerPushNotificationDeviceToken,
        installationID: UUID,
        environment: CustomerPushNotificationEnvironment
    ) async throws

    func unregisterDeviceToken(
        token: CustomerPushNotificationDeviceToken,
        installationID: UUID
    ) async throws
}
