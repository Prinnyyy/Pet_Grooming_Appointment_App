import Foundation

enum AuthCallbackConfiguration {
    static let scheme = "com.hellobeckon.beckon"
    static let host = "auth"
    static let path = "/callback"

    static let callbackURL = URL(
        string: "\(scheme)://\(host)\(path)"
    )!

    static let recoveryURL = URL(string: "\(scheme)://\(host)/recovery")!

    static func isRecoveryCallback(_ url: URL) -> Bool {
        guard url.scheme == scheme, url.host == host else { return false }
        if url.path == "/recovery" { return true }
        return url.path == path && (formEncodedParameters(from: url.query)["type"] == "recovery"
            || formEncodedParameters(from: url.fragment)["type"] == "recovery")
    }

    static func isSupportedCallback(_ url: URL) -> Bool {
        url.scheme == scheme
            && url.host == host
            && url.path == path
    }

    static func callbackErrorParameters(
        from url: URL
    ) -> [String: String] {
        var parameters = formEncodedParameters(from: url.query)
        formEncodedParameters(from: url.fragment).forEach { key, value in
            parameters[key] = value
        }
        return parameters.filter { key, _ in
            key == "error"
                || key == "error_code"
                || key == "error_description"
        }
    }

    private static func formEncodedParameters(
        from string: String?
    ) -> [String: String] {
        guard let string, !string.isEmpty else { return [:] }
        return string
            .split(separator: "&")
            .reduce(into: [String: String]()) { result, pair in
                let pieces = pair.split(
                    separator: "=",
                    maxSplits: 1,
                    omittingEmptySubsequences: false
                )
                guard let key = pieces.first.flatMap(decoded) else {
                    return
                }
                let value = pieces.dropFirst().first.flatMap(decoded) ?? ""
                result[key] = value
            }
    }

    private static func decoded(
        _ value: Substring
    ) -> String? {
        String(value)
            .replacingOccurrences(of: "+", with: " ")
            .removingPercentEncoding
    }
}
