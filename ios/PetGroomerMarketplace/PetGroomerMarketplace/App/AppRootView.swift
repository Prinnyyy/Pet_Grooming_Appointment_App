import SwiftUI

struct AppRootView: View {
    let route: AppEntryRoute
    let authenticationBootstrapState: AuthenticationBootstrapState
    let authenticationStore: AuthenticationStore?
    let profileRepository: (any ProfileRepository)?
    let customerPetRepository: (any CustomerPetRepository)?
    let groomerProfileRepository: (any GroomerProfileRepository)?
    let roleOnboardingContent: AnyView?

    init(
        route: AppEntryRoute,
        authenticationBootstrapState: AuthenticationBootstrapState = .ready,
        authenticationStore: AuthenticationStore? = nil,
        profileRepository: (any ProfileRepository)? = nil,
        customerPetRepository: (any CustomerPetRepository)? = nil,
        groomerProfileRepository: (any GroomerProfileRepository)? = nil,
        roleOnboardingContent: AnyView? = nil
    ) {
        self.route = route
        self.authenticationBootstrapState = authenticationBootstrapState
        self.authenticationStore = authenticationStore
        self.profileRepository = profileRepository
        self.customerPetRepository = customerPetRepository
        self.groomerProfileRepository = groomerProfileRepository
        self.roleOnboardingContent = roleOnboardingContent
    }

    var body: some View {
        switch route {
        case .authentication:
            if let authenticationStore,
               let profileRepository,
               let customerPetRepository,
               let groomerProfileRepository {
                AuthenticationGateView(
                    store: authenticationStore,
                    profileRepository: profileRepository,
                    customerPetRepository: customerPetRepository,
                    groomerProfileRepository: groomerProfileRepository
                )
            } else {
                AuthenticationBootstrapView(state: authenticationBootstrapState)
            }
        case .roleOnboarding:
            if let roleOnboardingContent {
                roleOnboardingContent
            } else {
                AuthenticationBootstrapView(
                    state: .configurationError(
                        message: "Role onboarding requires an authenticated session."
                    )
                )
            }
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

#if DEBUG
#Preview("Role onboarding") {
    let session = AuthSessionSnapshot(
        userID: UUID(),
        email: "owner@example.com"
    )
    let store = AuthenticatedEntryStore(
        repository: AppRootPreviewProfileRepository()
    )

    AppRootView(
        route: .roleOnboarding,
        roleOnboardingContent: AnyView(
            RoleOnboardingView(
                session: session,
                store: store,
                onSignOut: {}
            )
        )
    )
}
#endif

#Preview("Customer") {
    AppRootView(route: .customer)
}

#Preview("Groomer") {
    AppRootView(route: .groomer)
}

#if DEBUG
@MainActor
private final class AppRootPreviewProfileRepository: ProfileRepository {
    func profile(userID: UUID) async throws -> MarketplaceProfile? {
        nil
    }

    func createProfile(
        role: UserRole,
        displayName: String
    ) async throws -> MarketplaceProfile {
        MarketplaceProfile(
            userID: UUID(),
            role: role,
            displayName: displayName
        )
    }
}
#endif
