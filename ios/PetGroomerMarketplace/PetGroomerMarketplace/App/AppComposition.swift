import Foundation

@MainActor
struct AppComposition {
    let authenticationBootstrapState: AuthenticationBootstrapState
    let authSessionRepository: (any AuthSessionRepository)?

    init(bundle: Bundle = .main) {
        do {
            let configuration = try SupabaseConfiguration.load(from: bundle)
            let client = SupabaseClientFactory.make(configuration: configuration)

            authenticationBootstrapState = .ready
            authSessionRepository = SupabaseAuthSessionRepository(client: client)
        } catch {
            authenticationBootstrapState = .configurationError(
                message: error.localizedDescription
            )
            authSessionRepository = nil
        }
    }
}
