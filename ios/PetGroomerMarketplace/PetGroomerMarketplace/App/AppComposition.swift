import Foundation

@MainActor
struct AppComposition {
    let authenticationBootstrapState: AuthenticationBootstrapState
    let authSessionRepository: (any AuthSessionRepository)?
    let profileRepository: (any ProfileRepository)?
    let customerPetRepository: (any CustomerPetRepository)?
    let customerRequestRepository: (any CustomerRequestRepository)?
    let groomerProfileRepository: (any GroomerProfileRepository)?
    let groomerRequestRepository: (any GroomerRequestRepository)?
    let authenticationStore: AuthenticationStore?

    init(bundle: Bundle = .main) {
        do {
            let configuration = try SupabaseConfiguration.load(from: bundle)
            let client = SupabaseClientFactory.make(configuration: configuration)
            let authRepository = SupabaseAuthSessionRepository(client: client)
            let profileRepository = SupabaseProfileRepository(client: client)
            let customerPetRepository = SupabaseCustomerPetRepository(client: client)
            let customerRequestRepository = SupabaseCustomerRequestRepository(client: client)
            let groomerProfileRepository = SupabaseGroomerProfileRepository(client: client)
            let groomerRequestRepository = SupabaseGroomerRequestRepository(client: client)

            authenticationBootstrapState = .ready
            authSessionRepository = authRepository
            self.profileRepository = profileRepository
            self.customerPetRepository = customerPetRepository
            self.customerRequestRepository = customerRequestRepository
            self.groomerProfileRepository = groomerProfileRepository
            self.groomerRequestRepository = groomerRequestRepository
            authenticationStore = AuthenticationStore(repository: authRepository)
        } catch {
            authenticationBootstrapState = .configurationError(
                message: error.localizedDescription
            )
            authSessionRepository = nil
            profileRepository = nil
            customerPetRepository = nil
            customerRequestRepository = nil
            groomerProfileRepository = nil
            groomerRequestRepository = nil
            authenticationStore = nil
        }
    }
}
