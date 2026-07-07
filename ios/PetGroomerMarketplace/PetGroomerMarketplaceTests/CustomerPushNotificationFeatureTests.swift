import Foundation
import Testing
@testable import PetGroomerMarketplace

struct CustomerPushNotificationRegistrationStoreTests {
    @Test @MainActor
    func registerDeviceTokenUsesActiveCustomerAndStableInstallationID() async throws {
        let customerID = UUID()
        let installationID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let repository = CustomerPushNotificationRepositoryFake()
        let store = CustomerPushNotificationRegistrationStore(
            repository: repository,
            installationID: installationID,
            environment: .sandbox
        )

        await store.activate(customerID: customerID)
        await store.registerDeviceToken(Data([0x0A, 0xFF, 0x10]))

        #expect(repository.registerCallCount == 1)
        #expect(repository.lastRegisteredCustomerID == customerID)
        #expect(repository.lastRegisteredToken == "0aff10")
        #expect(repository.lastRegisteredInstallationID == installationID)
        #expect(repository.lastRegisteredEnvironment == .sandbox)
    }

    @Test @MainActor
    func registerDeviceTokenIsIgnoredWithoutActiveCustomer() async throws {
        let repository = CustomerPushNotificationRepositoryFake()
        let store = CustomerPushNotificationRegistrationStore(
            repository: repository,
            installationID: UUID(),
            environment: .production
        )

        await store.registerDeviceToken(Data([0x01, 0x02]))

        #expect(repository.registerCallCount == 0)
    }

    @Test
    func deviceTokenDataUsesLowercaseHexEncoding() {
        #expect(CustomerPushNotificationDeviceToken(data: Data([0x00, 0x0A, 0xFF])).rawValue == "000aff")
    }
}

@MainActor
private final class CustomerPushNotificationRepositoryFake: CustomerPushNotificationRepository {
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var lastRegisteredCustomerID: UUID?
    private(set) var lastRegisteredToken: String?
    private(set) var lastRegisteredInstallationID: UUID?
    private(set) var lastRegisteredEnvironment: CustomerPushNotificationEnvironment?

    func registerDeviceToken(
        customerID: UUID,
        token: CustomerPushNotificationDeviceToken,
        installationID: UUID,
        environment: CustomerPushNotificationEnvironment
    ) async throws {
        registerCallCount += 1
        lastRegisteredCustomerID = customerID
        lastRegisteredToken = token.rawValue
        lastRegisteredInstallationID = installationID
        lastRegisteredEnvironment = environment
    }

    func unregisterDeviceToken(
        token: CustomerPushNotificationDeviceToken,
        installationID: UUID
    ) async throws {
        unregisterCallCount += 1
    }
}
