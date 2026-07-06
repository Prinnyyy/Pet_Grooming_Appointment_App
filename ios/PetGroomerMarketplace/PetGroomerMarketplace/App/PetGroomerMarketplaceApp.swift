import SwiftUI

@main
struct PetGroomerMarketplaceApp: App {
    private let composition = AppComposition()

    var body: some Scene {
        WindowGroup {
            AppRootView(
                route: .authentication,
                authenticationBootstrapState: composition.authenticationBootstrapState,
                authenticationStore: composition.authenticationStore,
                profileRepository: composition.profileRepository,
                customerProfileRepository: composition.customerProfileRepository,
                customerPetRepository: composition.customerPetRepository,
                customerRequestRepository: composition.customerRequestRepository,
                customerNotificationRepository: composition.customerNotificationRepository,
                bookingRepository: composition.bookingRepository,
                chatRepository: composition.chatRepository,
                groomerProfileRepository: composition.groomerProfileRepository,
                groomerRequestRepository: composition.groomerRequestRepository
            )
            .transaction { transaction in
                if composition.launchConfiguration.testOps.disablesAnimations {
                    transaction.animation = nil
                }
            }
        }
    }
}
