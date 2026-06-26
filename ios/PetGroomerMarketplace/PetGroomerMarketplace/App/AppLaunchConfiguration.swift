import Foundation

struct AppLaunchConfiguration: Equatable, Sendable {
    static let signedOutAuthSessionArgument =
        "--groomly-ui-test-signed-out-auth"

    let usesSignedOutAuthSessionRepository: Bool

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        usesSignedOutAuthSessionRepository = arguments.contains(
            Self.signedOutAuthSessionArgument
        )
    }
}
