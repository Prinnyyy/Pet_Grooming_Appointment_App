import SwiftUI

struct AuthenticatedEntryView: View {
    let session: AuthSessionSnapshot
    @Bindable var authenticationStore: AuthenticationStore
    private let customerProfileRepository: any CustomerProfileRepository
    private let customerPetRepository: any CustomerPetRepository
    private let customerRequestRepository: any CustomerRequestRepository
    private let customerNotificationRepository: any CustomerNotificationRepository
    private let bookingRepository: any BookingRepository
    private let chatRepository: any ChatRepository
    private let groomerProfileRepository: any GroomerProfileRepository
    private let groomerRequestRepository: any GroomerRequestRepository
    private let groomerNotificationRepository: any GroomerNotificationRepository
    private let operationalEventRecorder: AppOperationalEventRecorder?
    @State private var store: AuthenticatedEntryStore

    init(
        session: AuthSessionSnapshot,
        authenticationStore: AuthenticationStore,
        profileRepository: any ProfileRepository,
        customerProfileRepository: any CustomerProfileRepository,
        customerPetRepository: any CustomerPetRepository,
        customerRequestRepository: any CustomerRequestRepository,
        customerNotificationRepository: any CustomerNotificationRepository,
        bookingRepository: any BookingRepository,
        chatRepository: any ChatRepository,
        groomerProfileRepository: any GroomerProfileRepository,
        groomerRequestRepository: any GroomerRequestRepository,
        groomerNotificationRepository: any GroomerNotificationRepository,
        operationalEventRecorder: AppOperationalEventRecorder? = nil
    ) {
        self.session = session
        self.authenticationStore = authenticationStore
        self.customerProfileRepository = customerProfileRepository
        self.customerPetRepository = customerPetRepository
        self.customerRequestRepository = customerRequestRepository
        self.customerNotificationRepository = customerNotificationRepository
        self.bookingRepository = bookingRepository
        self.chatRepository = chatRepository
        self.groomerProfileRepository = groomerProfileRepository
        self.groomerRequestRepository = groomerRequestRepository
        self.groomerNotificationRepository = groomerNotificationRepository
        self.operationalEventRecorder = operationalEventRecorder
        _store = State(
            initialValue: AuthenticatedEntryStore(
                repository: profileRepository
            )
        )
    }

    var body: some View {
        Group {
            switch store.state {
            case .loading:
                loadingView

            case .onboarding:
                RoleOnboardingView(
                    session: session,
                    store: store,
                    onSignOut: signOut
                )

            case let .customer(profile):
                CustomerTabView(
                    customerID: profile.userID,
                    customerDisplayName: profile.displayName,
                    customerProfileRepository: customerProfileRepository,
                    petRepository: customerPetRepository,
                    requestRepository: customerRequestRepository,
                    notificationRepository: customerNotificationRepository,
                    bookingRepository: bookingRepository,
                    chatRepository: chatRepository,
                    accountContent: customerAccountContent(for: profile),
                    acceptanceSessionIsCurrent: {
                        guard !authenticationStore.isSubmitting,
                              case let .signedIn(current) = authenticationStore.rootState else { return false }
                        return current.userID == profile.userID
                    }
                )

            case let .groomer(profile):
                GroomerTabView(
                    groomerID: profile.userID,
                    groomerDisplayName: profile.displayName,
                    profileRepository: groomerProfileRepository,
                    requestRepository: groomerRequestRepository,
                    notificationRepository: groomerNotificationRepository,
                    bookingRepository: bookingRepository,
                    chatRepository: chatRepository,
                    accountContent: genericAccountContent(for: profile),
                    onSignOut: signOut
                )

            case let .failure(message):
                loadFailureView(message: message)
            }
        }
        .task(id: session.userID) {
            await store.load(userID: session.userID)
        }
        .task(id: activeCustomerIDForPushRegistration) {
            await CustomerPushNotificationRegistrationCoordinator.shared
                .activate(customerID: activeCustomerIDForPushRegistration)
        }
        .onDisappear {
            Task {
                await CustomerPushNotificationRegistrationCoordinator.shared
                    .activate(customerID: nil)
            }
        }
        .onChange(of: store.state) { _, newState in
            recordEntryState(newState)
        }
        .environment(\.appDebugEventRecorder, appDebugRecorder)
    }

    private var activeCustomerIDForPushRegistration: UUID? {
        if case let .customer(profile) = store.state {
            profile.userID
        } else {
            nil
        }
    }

    private var appDebugRecorder: AppDebugEventRecorder? {
        #if DEBUG
        AppDebugEventRecorder.shared
        #else
        nil
        #endif
    }

    private var loadingView: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            BeckonLoadingView(
                title: "Loading Profile…",
                message: "Preparing your Beckon workspace."
            )
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .accessibilityIdentifier("profile.loading")
        }
    }

    private func loadFailureView(message: String) -> some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: DesignTokens.Spacing.standard) {
                    BeckonErrorBanner(
                        title: "Profile Unavailable",
                        message: message
                    ) {
                        VStack(spacing: DesignTokens.Spacing.md) {
                            Button {
                                Task {
                                    await store.retry()
                                }
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(BeckonPrimaryButtonStyle())

                            Button(role: .destructive) {
                                signOut()
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
                            .disabled(authenticationStore.isSubmitting)
                            .accessibilityIdentifier("auth.sign-out")
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("profile.load-error")
    }

    private func customerAccountContent(for profile: MarketplaceProfile) -> AnyView {
        AnyView(
            CustomerAccountView(
                session: session,
                profile: profile,
                authenticationStore: authenticationStore,
                repository: customerProfileRepository,
                debugRecorder: appDebugRecorder
            )
        )
    }

    private func genericAccountContent(for profile: MarketplaceProfile) -> AnyView {
        AnyView(
            AuthenticatedAccountView(
                session: session,
                profile: profile,
                authenticationStore: authenticationStore
            )
        )
    }

    private func signOut() {
        Task {
            await authenticationStore.signOut()
        }
    }

    private func recordEntryState(_ state: AuthenticatedEntryState) {
        switch state {
        case .loading:
            break
        case .onboarding:
            operationalEventRecorder?.recordFunnelStep(
                .roleOnboarding,
                scope: "role.onboarding"
            )
        case .customer:
            operationalEventRecorder?.recordFunnelStep(
                .roleResolved,
                scope: "customer.home",
                actorRole: .customer
            )
        case .groomer:
            operationalEventRecorder?.recordFunnelStep(
                .roleResolved,
                scope: "groomer.requests",
                actorRole: .groomer
            )
        case .failure:
            operationalEventRecorder?.recordFunnelStep(
                .profileLoadFailed,
                scope: "profile"
            )
        }
    }
}
