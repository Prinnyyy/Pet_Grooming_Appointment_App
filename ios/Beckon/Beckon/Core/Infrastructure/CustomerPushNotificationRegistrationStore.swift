import Foundation

@MainActor
final class CustomerPushNotificationRegistrationStore {
    private let repository: any CustomerPushNotificationRepository
    private let installationID: UUID
    private let environment: CustomerPushNotificationEnvironment
    private var activeCustomerID: UUID?

    private(set) var lastError: CustomerPushNotificationRepositoryError?

    init(
        repository: any CustomerPushNotificationRepository,
        installationID: UUID,
        environment: CustomerPushNotificationEnvironment
    ) {
        self.repository = repository
        self.installationID = installationID
        self.environment = environment
    }

    func activate(customerID: UUID?) async {
        activeCustomerID = customerID
    }

    func registerDeviceToken(_ data: Data) async {
        guard let activeCustomerID else { return }

        do {
            try await repository.registerDeviceToken(
                customerID: activeCustomerID,
                token: CustomerPushNotificationDeviceToken(data: data),
                installationID: installationID,
                environment: environment
            )
            lastError = nil
        } catch let error as CustomerPushNotificationRepositoryError {
            if error != .cancelled {
                lastError = error
            }
        } catch {
            lastError = .unavailable
        }
    }
}
