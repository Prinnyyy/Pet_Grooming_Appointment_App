import SwiftUI

struct AuthenticatedEntryView: View {
    @Environment(\.customerMarketplaceServices) private var marketplaceServices
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
    @State private var reminderScheduler = AppointmentReminderScheduler.shared

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
                AccountEntryLoadingView()

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
                    marketplaceServices: marketplaceServices,
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
                    onSignOut: signOut,
                    sessionIsCurrent: {
                        guard !authenticationStore.isSubmitting,
                              case let .signedIn(current) = authenticationStore.rootState else { return false }
                        return current.userID == profile.userID
                    }
                )

            case let .failure(message):
                loadFailureView(message: message)
            }
        }
        .preference(key: LaunchReadyKey.self, value: true)
        .task(id: session.userID) {
            await store.load(userID: session.userID)
        }
        .task(id: activeCustomerIDForPushRegistration) {
            await CustomerPushNotificationRegistrationCoordinator.shared
                .activate(customerID: activeCustomerIDForPushRegistration)
        }
        .task(id: store.state) {
            switch store.state {
            case let .customer(profile): await reminderScheduler.activate(participantID: profile.userID, role: .customer)
            case let .groomer(profile): await reminderScheduler.activate(participantID: profile.userID, role: .groomer)
            default: break
            }
        }
        .sheet(item: Binding(get: {
            guard let target = reminderScheduler.tap, target.accountID == session.userID,
                  case .groomer = store.state, target.role == .groomer else { return nil }
            return target
        }, set: { reminderScheduler.tap = $0 })) { target in
            AppointmentReminderDestinationView(target: target, repository: bookingRepository)
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

    private func loadFailureView(message: String) -> some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.appBackground
                    .ignoresSafeArea()

                VStack(spacing: DesignTokens.Spacing.standard) {
                    BeckonErrorBanner(
                        title: "Profile unavailable",
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
                                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
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

/// The role is not known yet. Keep the shared background, without implying an Account page
/// or a particular role. The destination owns its only skeleton-to-content reveal.
struct AccountEntryLoadingView: View {
    @Environment(\.beckonEntranceActive) private var pageIsActive
    @State private var showsProgress = false

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()
            ProgressView("Getting things ready…")
                .font(DesignTokens.Typography.Expressive.supporting)
                .tint(DesignTokens.Colors.textSecondary)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .padding(DesignTokens.Spacing.xl)
                .opacity(showsProgress ? 1 : 0)
                .animation(DesignTokens.Motion.reduced, value: showsProgress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your account")
        .accessibilityIdentifier("profile.loading")
        .task(id: pageIsActive) {
            showsProgress = false
            guard pageIsActive else { return }
            try? await Task.sleep(for: .seconds(DesignTokens.Motion.skeletonShowDelay))
            guard !Task.isCancelled else { return }
            showsProgress = true
        }
    }
}

#Preview("Account entry transition") {
    AccountEntryLoadingView()
}
