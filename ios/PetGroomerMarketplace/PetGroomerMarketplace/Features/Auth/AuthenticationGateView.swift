import SwiftUI

struct AuthenticationGateView: View {
    @Bindable var store: AuthenticationStore
    let profileRepository: any ProfileRepository
    let customerPetRepository: any CustomerPetRepository
    let customerRequestRepository: any CustomerRequestRepository
    let bookingRepository: any BookingRepository
    let groomerProfileRepository: any GroomerProfileRepository
    let groomerRequestRepository: any GroomerRequestRepository

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
                    customerRequestRepository: customerRequestRepository,
                    bookingRepository: bookingRepository,
                    groomerProfileRepository: groomerProfileRepository,
                    groomerRequestRepository: groomerRequestRepository
                )
            }
        }
        .task {
            await store.start()
        }
    }
}
