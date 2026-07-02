import Foundation

@MainActor
struct AppComposition {
    let launchConfiguration: AppLaunchConfiguration
    let authenticationBootstrapState: AuthenticationBootstrapState
    let authSessionRepository: (any AuthSessionRepository)?
    let profileRepository: (any ProfileRepository)?
    let customerProfileRepository: (any CustomerProfileRepository)?
    let customerPetRepository: (any CustomerPetRepository)?
    let customerRequestRepository: (any CustomerRequestRepository)?
    let bookingRepository: (any BookingRepository)?
    let chatRepository: (any ChatRepository)?
    let groomerProfileRepository: (any GroomerProfileRepository)?
    let groomerRequestRepository: (any GroomerRequestRepository)?
    let authenticationStore: AuthenticationStore?

    init(
        bundle: Bundle = .main,
        launchConfiguration: AppLaunchConfiguration = AppLaunchConfiguration()
    ) {
        self.launchConfiguration = launchConfiguration

        #if DEBUG
        let debugRecorder = AppDebugEventRecorder.shared
        debugRecorder.configureTestOps(launchConfiguration.testOps)
        #endif

        do {
            let configuration = try SupabaseConfiguration.load(from: bundle)
            let client = SupabaseClientFactory.make(configuration: configuration)
            let authRepository: any AuthSessionRepository =
                if launchConfiguration.usesSignedOutAuthSessionRepository {
                    SignedOutAuthSessionRepository()
                } else {
                    SupabaseAuthSessionRepository(client: client)
                }
            let profileRepository = SupabaseProfileRepository(client: client)
            #if DEBUG
            let customerProfileRepository = DebugCustomerProfileRepository(
                base: SupabaseCustomerProfileRepository(client: client),
                debugRecorder: debugRecorder
            )
            let customerPetRepository = DebugCustomerPetRepository(
                base: SupabaseCustomerPetRepository(client: client),
                debugRecorder: debugRecorder
            )
            let customerRequestRepository = DebugCustomerRequestRepository(
                base: SupabaseCustomerRequestRepository(client: client),
                debugRecorder: debugRecorder
            )
            let bookingRepository = DebugBookingRepository(
                base: SupabaseBookingRepository(client: client),
                debugRecorder: debugRecorder
            )
            let chatRepository = DebugChatRepository(
                base: SupabaseChatRepository(client: client),
                debugRecorder: debugRecorder
            )
            let groomerProfileRepository = DebugGroomerProfileRepository(
                base: SupabaseGroomerProfileRepository(client: client),
                debugRecorder: debugRecorder
            )
            let groomerRequestRepository = DebugGroomerRequestRepository(
                base: SupabaseGroomerRequestRepository(client: client),
                debugRecorder: debugRecorder
            )
            #else
            let customerProfileRepository = SupabaseCustomerProfileRepository(client: client)
            let customerPetRepository = SupabaseCustomerPetRepository(client: client)
            let customerRequestRepository = SupabaseCustomerRequestRepository(client: client)
            let bookingRepository = SupabaseBookingRepository(client: client)
            let chatRepository = SupabaseChatRepository(client: client)
            let groomerProfileRepository = SupabaseGroomerProfileRepository(client: client)
            let groomerRequestRepository = SupabaseGroomerRequestRepository(client: client)
            #endif

            authenticationBootstrapState = .ready
            authSessionRepository = authRepository
            self.profileRepository = profileRepository
            self.customerProfileRepository = customerProfileRepository
            self.customerPetRepository = customerPetRepository
            self.customerRequestRepository = customerRequestRepository
            self.bookingRepository = bookingRepository
            self.chatRepository = chatRepository
            self.groomerProfileRepository = groomerProfileRepository
            self.groomerRequestRepository = groomerRequestRepository
            authenticationStore = AuthenticationStore(
                repository: authRepository,
                clearsSessionBeforeRestore:
                    launchConfiguration.testOps.clearsSessionBeforeRestore
            )
        } catch {
            authenticationBootstrapState = .configurationError(
                message: error.localizedDescription
            )
            authSessionRepository = nil
            profileRepository = nil
            customerProfileRepository = nil
            customerPetRepository = nil
            customerRequestRepository = nil
            bookingRepository = nil
            chatRepository = nil
            groomerProfileRepository = nil
            groomerRequestRepository = nil
            authenticationStore = nil
        }
    }
}
