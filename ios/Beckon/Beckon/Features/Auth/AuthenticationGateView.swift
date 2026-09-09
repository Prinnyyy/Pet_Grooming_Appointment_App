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
    let groomerNotificationRepository: any GroomerNotificationRepository
    let operationalEventRecorder: AppOperationalEventRecorder?

    var body: some View {
        Group {
            switch store.rootState {
            case .loading:
                ZStack {
                    DesignTokens.Colors.background
                        .ignoresSafeArea()

                    BeckonLoadingView(
                        title: "Restoring session…",
                        message: "Checking your secure Beckon session."
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
                    groomerRequestRepository: groomerRequestRepository,
                    groomerNotificationRepository: groomerNotificationRepository,
                    operationalEventRecorder: operationalEventRecorder
                )
                .id(session.userID)
            }
        }
        .task {
            await store.start()
        }
        .onChange(of: store.rootState) { _, newState in
            recordAuthState(newState)
        }
    }

    private func recordAuthState(_ state: AuthenticationRootState) {
        switch state {
        case .loading:
            break
        case .signedOut:
            operationalEventRecorder?.recordFunnelStep(
                .authSignedOut,
                scope: "auth"
            )
        case .signedIn:
            operationalEventRecorder?.recordFunnelStep(
                .authRestored,
                scope: "auth"
            )
        }
    }
}
