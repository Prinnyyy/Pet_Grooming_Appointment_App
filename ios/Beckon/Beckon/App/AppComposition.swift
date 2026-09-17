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
    let customerNotificationRepository: (any CustomerNotificationRepository)?
    let customerPushNotificationRepository: (any CustomerPushNotificationRepository)?
    let bookingRepository: (any BookingRepository)?
    let chatRepository: (any ChatRepository)?
    let groomerProfileRepository: (any GroomerProfileRepository)?
    let groomerRequestRepository: (any GroomerRequestRepository)?
    let groomerNotificationRepository: (any GroomerNotificationRepository)?
    let authenticationStore: AuthenticationStore?
    let operationalEventRecorder: AppOperationalEventRecorder

    init(
        bundle: Bundle = .main,
        launchConfiguration: AppLaunchConfiguration = AppLaunchConfiguration()
    ) {
        self.launchConfiguration = launchConfiguration
        operationalEventRecorder = AppOperationalEventRecorder.shared

        #if DEBUG
        let debugRecorder = AppDebugEventRecorder.shared
        debugRecorder.configureTestOps(launchConfiguration.testOps)
        operationalEventRecorder.setDebugRecorder(debugRecorder)
        #endif

        do {
            let configuration = try SupabaseConfiguration.load(from: bundle)
            let client = SupabaseClientFactory.make(configuration: configuration)
            let authRepository: any AuthSessionRepository =
                if launchConfiguration.usesSignedOutAuthSessionRepository {
                    SignedOutAuthSessionRepository()
                } else {
                    SupabaseAuthSessionRepository(client: client,
                        recoveryClient: SupabaseClientFactory.makeRecovery(configuration: configuration))
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
            let customerNotificationRepository = DebugCustomerNotificationRepository(
                base: SupabaseCustomerNotificationRepository(client: client),
                debugRecorder: debugRecorder
            )
            let customerPushNotificationRepository = DebugCustomerPushNotificationRepository(
                base: SupabaseCustomerPushNotificationRepository(client: client),
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
            let groomerNotificationRepository = DebugGroomerNotificationRepository(
                base: SupabaseGroomerNotificationRepository(client: client),
                debugRecorder: debugRecorder
            )
            #else
            let customerProfileRepository = SupabaseCustomerProfileRepository(client: client)
            let customerPetRepository = SupabaseCustomerPetRepository(client: client)
            let customerRequestRepository = SupabaseCustomerRequestRepository(client: client)
            let customerNotificationRepository = SupabaseCustomerNotificationRepository(client: client)
            let customerPushNotificationRepository = SupabaseCustomerPushNotificationRepository(client: client)
            let bookingRepository = SupabaseBookingRepository(client: client)
            let chatRepository = SupabaseChatRepository(client: client)
            let groomerProfileRepository = SupabaseGroomerProfileRepository(client: client)
            let groomerRequestRepository = SupabaseGroomerRequestRepository(client: client)
            let groomerNotificationRepository = SupabaseGroomerNotificationRepository(client: client)
            #endif

            authenticationBootstrapState = .ready
            authSessionRepository = authRepository
            self.profileRepository = profileRepository
            self.customerProfileRepository = customerProfileRepository
            self.customerPetRepository = customerPetRepository
            self.customerRequestRepository = customerRequestRepository
            self.customerNotificationRepository = customerNotificationRepository
            self.customerPushNotificationRepository = customerPushNotificationRepository
            self.bookingRepository = bookingRepository
            AppointmentReminderScheduler.shared.configure(repository: bookingRepository)
            AppointmentReminderScheduler.shared.startConnectivityMonitoring()
            self.chatRepository = chatRepository
            self.groomerProfileRepository = groomerProfileRepository
            self.groomerRequestRepository = groomerRequestRepository
            self.groomerNotificationRepository = groomerNotificationRepository
            authenticationStore = AuthenticationStore(
                repository: authRepository,
                clearsSessionBeforeRestore:
                    launchConfiguration.testOps.clearsSessionBeforeRestore,
                localAccountCleanup: { userID in
                    FileProfileSnapshotCache.shared.remove(userID: userID)
                    FilePrivateImageCache.shared.removeAll()
                    FileCustomerPetPhotoCache.shared.removeAll(
                        customerID: userID
                    )
                }
            )
            CustomerPushNotificationRegistrationCoordinator.shared.configure(
                repository: customerPushNotificationRepository
            )
        } catch {
            AppointmentReminderScheduler.shared.configure(repository: nil)
            AppointmentReminderScheduler.shared.setAccount(nil)
            authenticationBootstrapState = .configurationError(
                message: error.localizedDescription
            )
            authSessionRepository = nil
            profileRepository = nil
            customerProfileRepository = nil
            customerPetRepository = nil
            customerRequestRepository = nil
            customerNotificationRepository = nil
            customerPushNotificationRepository = nil
            bookingRepository = nil
            chatRepository = nil
            groomerProfileRepository = nil
            groomerRequestRepository = nil
            groomerNotificationRepository = nil
            authenticationStore = nil
            CustomerPushNotificationRegistrationCoordinator.shared.configure(
                repository: nil
            )
        }
    }
}
