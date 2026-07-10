import Foundation

struct SupabaseConfiguration: Equatable, Sendable {
    let url: URL
    let publishableKey: String

    static func load(from bundle: Bundle = .main) throws -> Self {
        try parse(
            urlValue: bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            publishableKeyValue: bundle.object(
                forInfoDictionaryKey: "SupabasePublishableKey"
            ) as? String
        )
    }

    static func parse(
        urlValue: String?,
        publishableKeyValue: String?
    ) throws -> Self {
        guard let urlValue = normalized(urlValue) else {
            throw SupabaseConfigurationError.missingValue("SupabaseURL")
        }

        guard
            let url = URL(string: urlValue),
            url.scheme == "https",
            url.host?.isEmpty == false
        else {
            throw SupabaseConfigurationError.invalidURL
        }

        guard let publishableKey = normalized(publishableKeyValue) else {
            throw SupabaseConfigurationError.missingValue(
                "SupabasePublishableKey"
            )
        }

        guard publishableKey.hasPrefix("sb_publishable_") else {
            throw SupabaseConfigurationError.invalidPublishableKey
        }

        return Self(url: url, publishableKey: publishableKey)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }

        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !normalizedValue.isEmpty,
            !normalizedValue.hasPrefix("$(")
        else {
            return nil
        }

        return normalizedValue
    }
}

enum SupabaseConfigurationError: Error, Equatable, LocalizedError {
    case missingValue(String)
    case invalidURL
    case invalidPublishableKey

    var errorDescription: String? {
        switch self {
        case let .missingValue(key):
            "Missing required configuration value: \(key)."
        case .invalidURL:
            "SupabaseURL must be a valid HTTPS URL."
        case .invalidPublishableKey:
            "SupabasePublishableKey must use the sb_publishable_ format."
        }
    }
}
