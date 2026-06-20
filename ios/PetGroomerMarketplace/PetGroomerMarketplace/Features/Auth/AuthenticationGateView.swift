import SwiftUI

struct AuthenticationGateView: View {
    @Bindable var store: AuthenticationStore
    let profileRepository: any ProfileRepository
    let customerPetRepository: any CustomerPetRepository

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
                    customerPetRepository: customerPetRepository
                )
            }
        }
        .task {
            await store.start()
        }
    }
}
