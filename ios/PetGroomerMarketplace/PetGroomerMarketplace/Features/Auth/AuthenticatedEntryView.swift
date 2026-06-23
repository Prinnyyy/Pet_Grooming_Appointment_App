import SwiftUI

struct AuthenticatedEntryView: View {
    let session: AuthSessionSnapshot
    @Bindable var authenticationStore: AuthenticationStore
    private let customerPetRepository: any CustomerPetRepository
    private let customerRequestRepository: any CustomerRequestRepository
    private let bookingRepository: any BookingRepository
    private let chatRepository: any ChatRepository
    private let groomerProfileRepository: any GroomerProfileRepository
    private let groomerRequestRepository: any GroomerRequestRepository
    @State private var store: AuthenticatedEntryStore

    init(
        session: AuthSessionSnapshot,
        authenticationStore: AuthenticationStore,
        profileRepository: any ProfileRepository,
        customerPetRepository: any CustomerPetRepository,
        customerRequestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository,
        chatRepository: any ChatRepository,
        groomerProfileRepository: any GroomerProfileRepository,
        groomerRequestRepository: any GroomerRequestRepository
    ) {
        self.session = session
        self.authenticationStore = authenticationStore
        self.customerPetRepository = customerPetRepository
        self.customerRequestRepository = customerRequestRepository
        self.bookingRepository = bookingRepository
        self.chatRepository = chatRepository
        self.groomerProfileRepository = groomerProfileRepository
        self.groomerRequestRepository = groomerRequestRepository
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
                    petRepository: customerPetRepository,
                    requestRepository: customerRequestRepository,
                    bookingRepository: bookingRepository,
                    chatRepository: chatRepository,
                    accountContent: accountContent(for: profile)
                )

            case let .groomer(profile):
                GroomerTabView(
                    groomerID: profile.userID,
                    profileRepository: groomerProfileRepository,
                    requestRepository: groomerRequestRepository,
                    bookingRepository: bookingRepository,
                    chatRepository: chatRepository,
                    accountContent: accountContent(for: profile)
                )

            case let .failure(message):
                loadFailureView(message: message)
            }
        }
        .task(id: session.userID) {
            await store.load(userID: session.userID)
        }
    }

    private var loadingView: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            GroomlyLoadingView(
                title: "Loading Profile…",
                message: "Preparing your Groomly workspace."
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
                    GroomlyErrorBanner(
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
                            .buttonStyle(GroomlyPrimaryButtonStyle())

                            Button(role: .destructive) {
                                signOut()
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))
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

    private func accountContent(for profile: MarketplaceProfile) -> AnyView {
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
}
