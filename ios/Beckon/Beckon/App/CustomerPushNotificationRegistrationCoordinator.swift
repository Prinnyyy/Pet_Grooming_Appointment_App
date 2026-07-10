import Foundation
import UIKit
import UserNotifications

@MainActor
final class CustomerPushNotificationRegistrationCoordinator {
    static let shared = CustomerPushNotificationRegistrationCoordinator()

    private var registrationStore: CustomerPushNotificationRegistrationStore?
    private let installationIDStore: CustomerPushNotificationInstallationIDStore
    private let systemRegistrar: any CustomerPushNotificationSystemRegistrar

    init(
        installationIDStore: CustomerPushNotificationInstallationIDStore =
            CustomerPushNotificationInstallationIDStore(),
        systemRegistrar: any CustomerPushNotificationSystemRegistrar =
            LiveCustomerPushNotificationSystemRegistrar()
    ) {
        self.installationIDStore = installationIDStore
        self.systemRegistrar = systemRegistrar
    }

    func configure(repository: (any CustomerPushNotificationRepository)?) {
        guard let repository else {
            registrationStore = nil
            return
        }

        registrationStore = CustomerPushNotificationRegistrationStore(
            repository: repository,
            installationID: installationIDStore.installationID(),
            environment: .current
        )
    }

    func activate(customerID: UUID?) async {
        await registrationStore?.activate(customerID: customerID)
        guard customerID != nil else { return }

        do {
            if try await systemRegistrar.requestAuthorization() {
                systemRegistrar.registerForRemoteNotifications()
            }
        } catch {
            // Permission failures should not block the authenticated app shell.
        }
    }

    func didRegisterDeviceToken(_ data: Data) async {
        await registrationStore?.registerDeviceToken(data)
    }
}

struct CustomerPushNotificationInstallationIDStore {
    private static let key =
        "beckon.customerPushNotification.installationID"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func installationID() -> UUID {
        if let existingValue = userDefaults.string(forKey: Self.key),
           let existingID = UUID(uuidString: existingValue) {
            return existingID
        }

        let newID = UUID()
        userDefaults.set(newID.uuidString, forKey: Self.key)
        return newID
    }
}

@MainActor
protocol CustomerPushNotificationSystemRegistrar: AnyObject {
    func requestAuthorization() async throws -> Bool
    func registerForRemoteNotifications()
}

@MainActor
private final class LiveCustomerPushNotificationSystemRegistrar:
    CustomerPushNotificationSystemRegistrar
{
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        )
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
