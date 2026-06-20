import SwiftUI

@main
struct PetGroomerMarketplaceApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView(route: .authentication)
        }
    }
}
