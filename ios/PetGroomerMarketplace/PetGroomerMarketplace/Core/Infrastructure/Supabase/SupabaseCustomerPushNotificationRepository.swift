import Foundation
import Supabase

@MainActor
final class SupabaseCustomerPushNotificationRepository:
    CustomerPushNotificationRepository
{
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func registerDeviceToken(
        customerID: UUID,
        token: CustomerPushNotificationDeviceToken,
        installationID: UUID,
        environment: CustomerPushNotificationEnvironment
    ) async throws {
        do {
            let _: [CustomerPushTokenRegistrationRow] = try await client
                .rpc(
                    "register_customer_push_token",
                    params: RegisterCustomerPushTokenParameters(
                        token: token,
                        installationID: installationID,
                        environment: environment
                    )
                )
                .execute()
                .value
            _ = customerID
        } catch {
            throw Self.map(error)
        }
    }

    func unregisterDeviceToken(
        token: CustomerPushNotificationDeviceToken,
        installationID: UUID
    ) async throws {
        do {
            let _: Bool = try await client
                .rpc(
                    "unregister_customer_push_token",
                    params: UnregisterCustomerPushTokenParameters(
                        token: token,
                        installationID: installationID
                    )
                )
                .execute()
                .value
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(
        _ error: any Error
    ) -> CustomerPushNotificationRepositoryError {
        if AppDebugErrorClassifier.isCancellation(error) {
            return .cancelled
        }

        if let repositoryError = error as? CustomerPushNotificationRepositoryError {
            return repositoryError
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501", "28000":
                return .notAllowed
            case "22023":
                return .invalidToken
            default:
                return .unavailable
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                return .networkUnavailable
            default:
                return .unavailable
            }
        }

        return .unavailable
    }
}

private struct CustomerPushTokenRegistrationRow: Decodable {
    let tokenID: UUID
    let customerID: UUID
    let environment: CustomerPushNotificationEnvironment
    let isActive: Bool
    let registeredAt: String

    private enum CodingKeys: String, CodingKey {
        case tokenID = "token_id"
        case customerID = "customer_id"
        case environment
        case isActive = "is_active"
        case registeredAt = "registered_at"
    }
}

private struct RegisterCustomerPushTokenParameters: Encodable {
    let token: CustomerPushNotificationDeviceToken
    let installationID: UUID
    let environment: CustomerPushNotificationEnvironment

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token.rawValue, forKey: .token)
        try container.encode(
            installationID.uuidString.lowercased(),
            forKey: .installationID
        )
        try container.encode(environment.rawValue, forKey: .environment)
    }

    private enum CodingKeys: String, CodingKey {
        case token = "p_token"
        case installationID = "p_installation_id"
        case environment = "p_environment"
    }
}

private struct UnregisterCustomerPushTokenParameters: Encodable {
    let token: CustomerPushNotificationDeviceToken
    let installationID: UUID

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token.rawValue, forKey: .token)
        try container.encode(
            installationID.uuidString.lowercased(),
            forKey: .installationID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case token = "p_token"
        case installationID = "p_installation_id"
    }
}
