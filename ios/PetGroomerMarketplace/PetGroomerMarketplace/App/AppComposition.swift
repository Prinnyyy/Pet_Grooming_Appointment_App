import Foundation

@MainActor
struct AppComposition {
    let authenticationBootstrapState: AuthenticationBootstrapState
    let authSessionRepository: (any AuthSessionRepository)?
    let authenticationStore: AuthenticationStore?

    init(bundle: Bundle = .main) {
        do {
            let configuration = try SupabaseConfiguration.load(from: bundle)
            let client = SupabaseClientFactory.make(configuration: configuration)
            let repository = SupabaseAuthSessionRepository(client: client)

            authenticationBootstrapState = .ready
            authSessionRepository = repository
            authenticationStore = AuthenticationStore(repository: repository)
        } catch {
            authenticationBootstrapState = .configurationError(
                message: error.localizedDescription
            )
            authSessionRepository = nil
            authenticationStore = nil
        }
    }
}
