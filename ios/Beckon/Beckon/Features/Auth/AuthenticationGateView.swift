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
    @State private var showsFormAfterRecovery = false

    var body: some View {
        Group {
            if store.recoveryState != nil {
                PasswordRecoveryView(store: store)
                    .preference(key: LaunchReadyKey.self, value: true)
            } else {
                routedContent
            }
        }
        .task { await store.start() }
        .onChange(of: store.recoveryState != nil, initial: true) { _, recovering in
            if recovering { showsFormAfterRecovery = true }
        }
        .onChange(of: store.rootState) { _, newState in
            recordAuthState(newState)
            if case .signedIn = newState { showsFormAfterRecovery = false }
        }
    }

    private var routedContent: some View {
        Group {
            switch store.rootState {
            case .loading:
                LaunchWaitingView().accessibilityIdentifier("auth.loading")

            case .signedOut:
                AuthenticationView(store: store, showsForm: showsFormAfterRecovery)
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
