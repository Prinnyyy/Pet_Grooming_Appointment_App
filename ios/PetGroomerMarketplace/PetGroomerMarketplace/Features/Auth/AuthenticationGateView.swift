import SwiftUI

struct AuthenticationGateView: View {
    @Bindable var store: AuthenticationStore
    let profileRepository: any ProfileRepository
    let customerPetRepository: any CustomerPetRepository
    let groomerProfileRepository: any GroomerProfileRepository

    var body: some View {
        Group {
            switch store.rootState {
            case .loading:
                ZStack {
                    DesignTokens.Colors.background
                        .ignoresSafeArea()

                    ProgressView("Restoring session…")
                        .accessibilityIdentifier("auth.loading")
                }

            case .signedOut:
                AuthenticationView(store: store)

            case let .signedIn(session):
                AuthenticatedEntryView(
                    session: session,
                    authenticationStore: store,
                    profileRepository: profileRepository,
                    customerPetRepository: customerPetRepository,
                    groomerProfileRepository: groomerProfileRepository
                )
            }
        }
        .task {
            await store.start()
        }
    }
}
