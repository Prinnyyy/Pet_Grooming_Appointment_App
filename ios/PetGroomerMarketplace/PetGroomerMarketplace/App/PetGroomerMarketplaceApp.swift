import SwiftUI

@main
struct PetGroomerMarketplaceApp: App {
    private let composition = AppComposition()

    var body: some Scene {
        WindowGroup {
            AppRootView(
                route: .authentication,
                authenticationBootstrapState: composition.authenticationBootstrapState
            )
        }
    }
}
