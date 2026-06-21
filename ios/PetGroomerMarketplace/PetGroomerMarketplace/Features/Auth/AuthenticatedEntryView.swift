import SwiftUI

struct AuthenticatedEntryView: View {
    let session: AuthSessionSnapshot
    @Bindable var authenticationStore: AuthenticationStore
    private let customerPetRepository: any CustomerPetRepository
    private let customerRequestRepository: any CustomerRequestRepository
    private let bookingRepository: any BookingRepository
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
        groomerProfileRepository: any GroomerProfileRepository,
        groomerRequestRepository: any GroomerRequestRepository
    ) {
        self.session = session
        self.authenticationStore = authenticationStore
        self.customerPetRepository = customerPetRepository
        self.customerRequestRepository = customerRequestRepository
        self.bookingRepository = bookingRepository
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
                    petRepository: customerPetRepository,
                    requestRepository: customerRequestRepository,
                    bookingRepository: bookingRepository,
                    accountContent: accountContent(for: profile)
                )

            case let .groomer(profile):
                GroomerTabView(
                    groomerID: profile.userID,
                    profileRepository: groomerProfileRepository,
                    requestRepository: groomerRequestRepository,
                    bookingRepository: bookingRepository,
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

            ProgressView("Loading profile…")
                .accessibilityIdentifier("profile.loading")
        }
    }

    private func loadFailureView(message: String) -> some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: DesignTokens.Spacing.standard) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)

                    Text("Profile unavailable")
                        .font(.title2.bold())

                    Text(message)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)

                    Button("Retry") {
                        Task {
                            await store.retry()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Sign Out", role: .destructive) {
                        signOut()
                    }
                    .disabled(authenticationStore.isSubmitting)
                    .accessibilityIdentifier("auth.sign-out")
                }
                .padding(DesignTokens.Spacing.large)
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
