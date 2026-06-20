import SwiftUI

struct AppRootView: View {
    let route: AppEntryRoute

    var body: some View {
        switch route {
        case .authentication:
            AuthenticationBootstrapView()
        case .roleOnboarding:
            RoleOnboardingPlaceholderView()
        case .customer:
            CustomerTabView()
        case .groomer:
            GroomerTabView()
        }
    }
}

#Preview("Authentication") {
    AppRootView(route: .authentication)
}

#Preview("Role onboarding") {
    AppRootView(route: .roleOnboarding)
}

#Preview("Customer") {
    AppRootView(route: .customer)
}

#Preview("Groomer") {
    AppRootView(route: .groomer)
}
