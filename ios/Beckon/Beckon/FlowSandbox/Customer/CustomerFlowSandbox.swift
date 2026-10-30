#if DEBUG
import SwiftUI

struct CustomerFlowSandbox: View {
    var body: some View { CustomerSandboxScreenHost(screen: .tabs) }
}

struct CustomerScreenIndexSandbox: View {
    @State private var selected: CustomerSandboxScreen?
    var body: some View {
        NavigationStack {
            List(CustomerSandboxScreen.allCases) { screen in
                Button { selected = screen } label: {
                    HStack {
                        Text(screen.rawValue)
                        Spacer()
                        Text("\(screen.states.count)").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                    }
                }
                .accessibilityIdentifier("sandbox.index.\(screen.rawValue)")
            }
            .navigationTitle("Customer screen index")
        }
        .sheet(item: $selected) { CustomerSandboxScreenHost(screen: $0) }
        .preferredColorScheme(.light)
    }
}

struct CustomerSandboxScreenHost: View {
    let screen: CustomerSandboxScreen
    var replaysLoading = false
    var startsOnGrooming = false
    @State private var state: CustomerSandboxState
    @State private var session: CustomerSandboxSession
    @State private var ready = false
    @State private var preparationError: String?
    @Environment(\.dismiss) private var dismiss

    init(screen: CustomerSandboxScreen, state: CustomerSandboxState? = nil, replaysLoading: Bool = false, startsOnGrooming: Bool = false) {
        self.screen = screen
        self.replaysLoading = replaysLoading
        self.startsOnGrooming = startsOnGrooming
        let state = state ?? screen.states[0]
        _state = State(initialValue: state)
        _session = State(initialValue: CustomerSandboxSession(screen: screen, state: state))
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Group {
                if let preparationError { ContentUnavailableView("Fixture setup failed", systemImage: "exclamationmark.triangle", description: Text(preparationError)) }
                else if ready {
                    renderedScreen
                        .task { await session.activate() }
                } else { ProgressView("Preparing local fixtures") }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .id(session.id)
        .task(id: session.id) {
            let current = session
            do {
                try await current.prepare()
                guard session === current, !Task.isCancelled else { return }
                ready = true
                if replaysLoading {
                    try await Task.sleep(for: .seconds(1.6))
                    guard session === current, !Task.isCancelled else { return }
                    current.boundary.state = .loaded
                }
            } catch { preparationError = String(describing: error) }
        }
        .environment(\.beckonFeedbackCenter, session.feedback)
        .environment(\.customerMarketplaceSession, session.marketplace)
        .environment(\.appDebugEventRecorder, nil)
        .environment(\.beckonCustomerDesign, true)
        .environment(\.sandboxRequestAdvance, session.advanceRequest)
        .environment(\.openURL, OpenURLAction { _ in
            session.feedback.showNotice("External links stay closed in this sandbox.")
            return .handled
        })
        .overlay(alignment: .bottom) {
            if screen != .tabs { BeckonGlobalFeedbackOverlay(center: session.feedback) }
        }
        .preferredColorScheme(.light)
        .tint(DesignTokens.Colors.customerDeep)
        .onDisappear { session.invalidate() }
    }

    @ViewBuilder private var renderedScreen: some View {
        CustomerSandboxAppScreen(session: session, startsOnGrooming: startsOnGrooming)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button("Close sandbox", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly).frame(width: 44, height: 44).help("Close sandbox")
            Picker("Fixture state", selection: $state) {
                ForEach(screen.states) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("sandbox.state")
            .onChange(of: state) { _, _ in reset() }
            if state == .loading {
                Button("Show loaded content") { session.boundary.state = .loaded }
                    .accessibilityIdentifier("sandbox.loaded")
            }
            Button("Reset sandbox", systemImage: "arrow.counterclockwise") { reset() }
                .labelStyle(.iconOnly).frame(width: 44, height: 44).help("Reset local fixtures")
                .accessibilityIdentifier("sandbox.reset")
        }
        .dynamicTypeSize(.large)
        .padding(.horizontal, 8)
        .background(DesignTokens.Colors.surface)
    }

    private func reset() {
        session.invalidate()
        ready = false; preparationError = nil
        session = CustomerSandboxSession(screen: screen, state: state)
    }
}

private struct CustomerSandboxAppScreen: View {
    let session: CustomerSandboxSession
    var startsOnGrooming = false
    @State private var requestPath: [UUID] = []
    @FocusState private var reviewFocus: BookingReviewFocusTarget?

    var body: some View {
        if [.tabs, .landing, .signIn, .signUp, .passwordRecovery, .onboarding, .reminder].contains(session.screen) {
            content
        } else {
            NavigationStack(path: $requestPath) {
                content
                    .navigationDestination(for: UUID.self) { id in GroomingDetailView(target: session.bookings.booking(withID: id) != nil ? .booking(id) : .request(id), requestStore: session.requests, bookingsStore: session.bookings) }
            }
            .modifier(CustomerRequestFlowPresenter(store: session.requests, profileRepository: session.accountRepository))
        }
    }

    @ViewBuilder private var content: some View {
        let requestID = CustomerSandboxFixtures.requestID
        let bookingID = CustomerSandboxFixtures.bookingID
                switch session.screen {
        case .tabs:
            if session.authentication.rootState == .signedOut {
                AuthenticationView(sandboxStore: session.authentication, showsForm: true)
            } else { CustomerTabView(sandbox: session, initialTab: startsOnGrooming ? .requests : .home) }
        case .landing, .signIn, .signUp:
            Group {
                if case .signedIn = session.authentication.rootState { CustomerTabView(sandbox: session) }
                else { AuthenticationView(sandboxStore: session.authentication, showsForm: session.screen != .landing) }
            }
                .sheet(isPresented: Binding(get: { session.authentication.recoveryState != nil }, set: { if !$0 { session.authentication.recoveryState = nil } })) {
                    PasswordRecoveryView(store: session.authentication)
                }
        case .passwordRecovery: PasswordRecoveryView(store: session.authentication)
        case .onboarding:
            if case .customer = session.onboarding.state { CustomerTabView(sandbox: session) }
            else {
                RoleOnboardingView(session: session.authSession, store: session.onboarding,
                    onSignOut: { Task { await session.authentication.signOut() } })
            }
        case .authenticatedAccount:
            AuthenticatedAccountView(session: session.authSession, profile: session.marketplaceProfile, authenticationStore: session.authentication)
        case .home:
            CustomerHomeView(sandbox: session, onSelectRequest: { requestPath.append($0) })
        case .notifications:
            CustomerNotificationsView(store: session.notifications, requestStore: session.requests,
                bookingStore: session.bookings, chatStore: session.chat)
        case .pets, .petRecovery, .petCreate, .petEdit:
            CustomerSandboxPetList(session: session)
        case .requests, .dashboard, .publication, .photoRetry,
             .wizardPet, .wizardService, .wizardTime, .wizardDetails, .wizardReview:
            CustomerGroomingView(requestStore: session.requests, bookingsStore: session.bookings,
                customerProfileRepository: session.accountRepository)
        case .requestDetail: GroomingDetailView(target: .request(requestID), requestStore: session.requests, bookingsStore: session.bookings)
        case .offers: CustomerRequestOffersView(requestID: requestID, store: session.requests)
        case .groomerPicker:
            CustomerGroomerDiscoveryView(flow: session.discoveryFlow, requests: session.requests, marketplace: session.marketplace)
        case .groomerDetail:
            CustomerGroomerDetailView(candidate: CustomerSandboxFixtures.candidate(state: session.state),
                flow: session.discoveryFlow, requests: session.requests, marketplace: session.marketplace)
        case .candidateActions:
            CustomerSandboxCandidate(session: session)
        case .favorites: CustomerFavoriteGroomersView(marketplace: session.marketplace)
        case .bookings: GroomingHistoryView(requestStore: session.requests, bookingsStore: session.bookings, onOpenChat: { _ in })
        case .bookingDetail: GroomingDetailView(target: .booking(bookingID), requestStore: session.requests, bookingsStore: session.bookings)
        case .fulfillment, .reschedule: GroomingDetailView(target: .booking(bookingID), requestStore: session.requests, bookingsStore: session.bookings)
        case .review:
            GroomingDetailView(target: .booking(bookingID), requestStore: session.requests, bookingsStore: session.bookings)
        case .reminder: AppointmentReminderDestinationView(sandbox: session)
        case .messages:
            ChatConversationsView(participantID: session.customerID, role: .customer, repository: session.chatRepository,
                bookingRepository: session.bookingRepository, store: session.chat)
        case .chat:
            ChatThreadView(participantID: session.customerID, role: .customer,
                conversation: session.chatRepository.conversationFixture, store: session.chat)
        case .account: CustomerAccountView(sandbox: session)
        case .profile: CustomerProfileSettingsView(store: session.profile)
        case .feedback:
            ScrollView {
                VStack(spacing: 16) {
                    BeckonErrorBanner(title: "Couldn't load", message: "Your changes are preserved.")
                    Button("Show saved feedback", systemImage: "checkmark") { session.feedback.showNotice("Changes saved.") }
                }.padding()
            }
        }
    }
}

private struct CustomerSandboxCandidate: View {
    let session: CustomerSandboxSession
    @State private var showsDetails = false
    var body: some View {
        let candidate = CustomerSandboxFixtures.candidate(state: session.state)
        ScrollView {
            CustomerGroomerCandidateView(candidate: candidate, flow: session.discoveryFlow,
                requests: session.requests, marketplace: session.marketplace,
                compact: false, onDetails: { showsDetails = true }).padding()
        }
        .navigationDestination(isPresented: $showsDetails) {
            CustomerGroomerDetailView(candidate: candidate, flow: session.discoveryFlow,
                requests: session.requests, marketplace: session.marketplace)
        }
    }
}

private struct CustomerSandboxPetList: View {
    let session: CustomerSandboxSession
    var body: some View {
        @Bindable var store = session.pets.store
        ScrollView { CustomerHomePetsSection(store: store).padding() }
            .sheet(isPresented: $store.isShowingPetForm) { CustomerPetFormView(store: store) }
            .background { CustomerPetsStatusView(store: store) }
    }
}

#Preview("Customer - all tabs") { CustomerFlowSandbox() }
#Preview("Customer - screen index") { CustomerScreenIndexSandbox() }
#Preview("Home · loading replay") { CustomerSandboxScreenHost(screen: .home, state: .loading, replaysLoading: true) }
#Preview("Grooming · loading replay") { CustomerSandboxScreenHost(screen: .requests, state: .loading, replaysLoading: true) }
#Preview("Messages · loading replay") { CustomerSandboxScreenHost(screen: .messages, state: .loading, replaysLoading: true) }
#Preview("Account · loading replay") { CustomerSandboxScreenHost(screen: .account, state: .loading, replaysLoading: true) }
#Preview("Detail · loading replay") { CustomerSandboxScreenHost(screen: .bookingDetail, state: .loading, replaysLoading: true) }
#Preview("Grooming · add first pet") { CustomerSandboxScreenHost(screen: .tabs, state: .empty, startsOnGrooming: true) }
#Preview("Launch scene") { LaunchScene() }
#endif
