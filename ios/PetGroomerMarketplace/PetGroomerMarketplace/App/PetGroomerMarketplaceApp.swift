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
                customerPetRepository: composition.customerPetRepository,
                customerRequestRepository: composition.customerRequestRepository,
                bookingRepository: composition.bookingRepository,
                chatRepository: composition.chatRepository,
                groomerProfileRepository: composition.groomerProfileRepository,
                groomerRequestRepository: composition.groomerRequestRepository,
                storageImageURLProvider: composition.storageImageURLProvider
            )
        }
    }
}
