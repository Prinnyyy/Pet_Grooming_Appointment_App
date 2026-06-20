import SwiftUI

struct AppRootView: View {
    let route: AppEntryRoute
    let authenticationBootstrapState: AuthenticationBootstrapState

    init(
        route: AppEntryRoute,
        authenticationBootstrapState: AuthenticationBootstrapState = .ready
    ) {
        self.route = route
        self.authenticationBootstrapState = authenticationBootstrapState
    }

    var body: some View {
        switch route {
        case .authentication:
            AuthenticationBootstrapView(state: authenticationBootstrapState)
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
