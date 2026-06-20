import Foundation

@MainActor
struct AppComposition {
    let authenticationBootstrapState: AuthenticationBootstrapState
    let authSessionRepository: (any AuthSessionRepository)?
    let profileRepository: (any ProfileRepository)?
    let customerPetRepository: (any CustomerPetRepository)?
    let groomerProfileRepository: (any GroomerProfileRepository)?
    let authenticationStore: AuthenticationStore?

    init(bundle: Bundle = .main) {
        do {
            let configuration = try SupabaseConfiguration.load(from: bundle)
            let client = SupabaseClientFactory.make(configuration: configuration)
            let authRepository = SupabaseAuthSessionRepository(client: client)
            let profileRepository = SupabaseProfileRepository(client: client)
            let customerPetRepository = SupabaseCustomerPetRepository(client: client)
            let groomerProfileRepository = SupabaseGroomerProfileRepository(client: client)

            authenticationBootstrapState = .ready
            authSessionRepository = authRepository
            self.profileRepository = profileRepository
            self.customerPetRepository = customerPetRepository
            self.groomerProfileRepository = groomerProfileRepository
            authenticationStore = AuthenticationStore(repository: authRepository)
        } catch {
            authenticationBootstrapState = .configurationError(
                message: error.localizedDescription
            )
            authSessionRepository = nil
            profileRepository = nil
            customerPetRepository = nil
            groomerProfileRepository = nil
            authenticationStore = nil
        }
    }
}
