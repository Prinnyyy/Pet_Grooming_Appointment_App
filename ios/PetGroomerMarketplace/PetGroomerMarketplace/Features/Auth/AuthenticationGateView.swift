import SwiftUI

struct AuthenticationGateView: View {
    @Bindable var store: AuthenticationStore
    let profileRepository: any ProfileRepository
    let customerProfileRepository: any CustomerProfileRepository
    let customerPetRepository: any CustomerPetRepository
    let customerRequestRepository: any CustomerRequestRepository
    let customerNotificationRepository: any CustomerNotificationRepository
    let bookingRepository: any BookingRepository
    let chatRepository: any ChatRepository
    let groomerProfileRepository: any GroomerProfileRepository
    let groomerRequestRepository: any GroomerRequestRepository

    var body: some View {
        Group {
            switch store.rootState {
            case .loading:
                ZStack {
                    DesignTokens.Colors.background
                        .ignoresSafeArea()

                    GroomlyLoadingView(
                        title: "Restoring session…",
                        message: "Checking your secure Groomly session."
                    )
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                        .accessibilityIdentifier("auth.loading")
                }

            case .signedOut:
                AuthenticationView(store: store)

            case let .signedIn(session):
                AuthenticatedEntryView(
                    session: session,
                    authenticationStore: store,
                    profileRepository: profileRepository,
                    customerProfileRepository: customerProfileRepository,
                    customerPetRepository: customerPetRepository,
                    customerRequestRepository: customerRequestRepository,
                    customerNotificationRepository: customerNotificationRepository,
                    bookingRepository: bookingRepository,
                    chatRepository: chatRepository,
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
