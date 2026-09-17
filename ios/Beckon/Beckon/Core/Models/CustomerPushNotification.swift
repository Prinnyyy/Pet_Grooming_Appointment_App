import Foundation

nonisolated struct CustomerPushNotificationDeviceToken:
    Equatable,
    Hashable,
    Sendable
{
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
            .filter(\.isHexDigit)
            .lowercased()
    }

    init(data: Data) {
        rawValue = data.map { byte in
            String(format: "%02x", byte)
        }
        .joined()
    }
}

nonisolated enum CustomerPushNotificationEnvironment:
    String,
    Codable,
    Equatable,
    Sendable
{
    case sandbox
    case production

    static var current: CustomerPushNotificationEnvironment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }
}
