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
                LaunchWaitingView().accessibilityIdentifier("auth.loading")

            case .signedOut:
                AuthenticationView(store: store)
                    .preference(key: LaunchReadyKey.self, value: true)

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
        .fullScreenCover(isPresented: Binding(
            get: { store.recoveryState != nil },
            set: { presented in
                if !presented { Task { await store.closePasswordRecovery() } }
            }
        )) {
            PasswordRecoveryView(store: store)
                .interactiveDismissDisabled()
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
