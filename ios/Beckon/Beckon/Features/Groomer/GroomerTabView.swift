import SwiftUI

struct GroomerTabView: View {
    @Environment(\.appDebugEventRecorder) private var debugRecorder
    let groomerID: UUID?
    let groomerDisplayName: String
    let profileRepository: (any GroomerProfileRepository)?
    let requestRepository: (any GroomerRequestRepository)?
    let notificationRepository: (any GroomerNotificationRepository)?
    let bookingRepository: (any BookingRepository)?
    let chatRepository: (any ChatRepository)?
    let accountContent: AnyView?
    let authenticationStore: AuthenticationStore?
    let onSignOut: (() -> Void)?
    let sessionIsCurrent: @MainActor () -> Bool
    @State private var navigation = GroomerNavigation()
    private var selection: GroomerTab { navigation.selection }
    private var paths: [GroomerTab: NavigationPath] {
        get { navigation.paths }
        nonmutating set { navigation.paths = newValue }
    }
    @State private var homeStore: GroomerHomeStore?
    @State private var requestsStore: GroomerRequestsStore?
    @State private var offersStore: GroomerOffersStore?
    @State private var bookingsStore: BookingsStore?
    @State private var profileStore: GroomerProfileStore?
    private var focusedBooking: Booking? {
        get { navigation.focusedBooking }
        nonmutating set { navigation.focusedBooking = newValue }
    }
    private var focusedConversationBookingID: UUID? {
        get { navigation.focusedConversationBookingID }
        nonmutating set { navigation.focusedConversationBookingID = newValue }
    }
    private var requestedProfileRoute: GroomerProfileRoute? {
        get { navigation.requestedProfileRoute }
        nonmutating set { navigation.requestedProfileRoute = newValue }
    }
    private var requestsRoute: GroomerRequestsRoute {
        get { navigation.requestsRoute }
        nonmutating set { navigation.requestsRoute = newValue }
    }
    @State private var notificationStore: GroomerNotificationsStore?
    @State private var chatStore: ChatStore?
    @State private var feedbackCenter = BeckonFeedbackCenter()

    init(
        groomerID: UUID? = nil,
        groomerDisplayName: String = "Groomer",
        profileRepository: (any GroomerProfileRepository)? = nil,
        requestRepository: (any GroomerRequestRepository)? = nil,
        notificationRepository: (any GroomerNotificationRepository)? = nil,
        bookingRepository: (any BookingRepository)? = nil,
        chatRepository: (any ChatRepository)? = nil,
        accountContent: AnyView? = nil,
        authenticationStore: AuthenticationStore? = nil,
        onSignOut: (() -> Void)? = nil,
        sessionIsCurrent: @escaping @MainActor () -> Bool = { true },
        requestCountCache: GroomerRequestCountCache? = nil,
        chatDisplayCache: FileChatDisplayCache? = nil
    ) {
        self.groomerID = groomerID
        self.groomerDisplayName = groomerDisplayName
        self.profileRepository = profileRepository
        self.requestRepository = requestRepository
        self.notificationRepository = notificationRepository
        self.bookingRepository = bookingRepository
        self.chatRepository = chatRepository
        self.accountContent = accountContent
        self.authenticationStore = authenticationStore
        self.onSignOut = onSignOut
        self.sessionIsCurrent = sessionIsCurrent
        if let groomerID, let profileRepository, let requestRepository, let bookingRepository {
            _homeStore = State(initialValue: GroomerHomeStore(groomerID: groomerID, displayName: groomerDisplayName,
                profileRepository: profileRepository, requestRepository: requestRepository, bookingRepository: bookingRepository))
            _requestsStore = State(initialValue: GroomerRequestsStore(groomerID: groomerID, repository: requestRepository,
                profileRepository: profileRepository, countCache: requestCountCache))
            _offersStore = State(initialValue: GroomerOffersStore(groomerID: groomerID, repository: requestRepository,
                countCache: requestCountCache, sessionIsCurrent: sessionIsCurrent))
            _bookingsStore = State(initialValue: BookingsStore(participantID: groomerID, role: .groomer,
                repository: bookingRepository, groomerProfileRepository: profileRepository, sessionIsCurrent: sessionIsCurrent))
            _profileStore = State(initialValue: GroomerProfileStore(groomerID: groomerID, repository: profileRepository))
        }
        _notificationStore = State(
            initialValue: Self.makeNotificationStore(
                groomerID: groomerID,
                repository: notificationRepository
            )
        )
        _chatStore = State(
            initialValue: Self.makeChatStore(
                groomerID: groomerID,
                repository: chatRepository,
                bookingRepository: bookingRepository,
                displayCache: chatDisplayCache
            )
        )
    }

    var body: some View {
        TabView(selection: Binding(get: { selection }, set: { select($0) })) {
            ForEach(GroomerTab.allCases) { tab in
                BeckonTabBarOwner {
                NavigationStack(path: Binding(get: { paths[tab] ?? NavigationPath() }, set: { paths[tab] = $0 })) {
                    destination(for: tab)
                        .background(DesignTokens.Colors.appBackground)
                }
                }
                .beckonEntranceActive(selection == tab)
                .environment(\.beckonNavigationResetCount, navigation.resetCounts[tab, default: 0])
                .tabItem {
                    Label { Text(tab.title) } icon: { BeckonTabIcons.image(tab.icon, isSelected: selection == tab) }
                        .accessibilityIdentifier(tab.accessibilityIdentifier)
                }
                .background(BeckonTabBadgeAppearance(accent: .groomer))
                .badge(
                    BeckonBadgeLabel.text(for: tab.badgeCount(
                        unreadNotificationCount: notificationUnreadCount,
                        unreadMessageCount: messageUnreadCount
                    ))
                )
                .tag(tab)
            }
        }
        .tint(DesignTokens.Colors.groomerDeep)
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .toolbarBackground(DesignTokens.Colors.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environment(\.beckonRole, .groomer)

        .environment(\.beckonFeedbackCenter, feedbackCenter)
        .environment(\.openBookingChat, openBookingChat)
        .overlay(alignment: .bottom) {
            BeckonGlobalFeedbackOverlay(center: feedbackCenter)
        }
        .onAppear {
            requestsStore?.setSessionValidation(sessionIsCurrent)
            feedbackCenter.setDebugRecorder(debugRecorder)
            chatStore?.setDebugRecorder(debugRecorder)
        }
        .task {
            await refreshBadgeSources()
        }
        .onChange(of: sessionIsCurrent()) { _, current in
            if !current { requestsStore?.invalidateSession() }
        }
        .onChange(of: selection) { oldValue, newValue in
            debugRecorder?.record(
                level: .info,
                category: .navigation,
                source: "GroomerTabView.selection",
                scope: "groomer.\(newValue.debugKey)",
                message: "\(oldValue.debugKey) -> \(newValue.debugKey)",
                metadata: [
                    "from": "groomer.\(oldValue.debugKey)",
                    "to": "groomer.\(newValue.debugKey)",
                ]
            )
        }
        .accessibilityIdentifier("groomer.tabs")
    }

    @ViewBuilder
    private func destination(for tab: GroomerTab) -> some View {
        if tab == .home, let homeStore, let requestsStore, let offersStore, let bookingsStore {
            GroomerHomeView(home: homeStore, notifications: notificationStore, requests: requestsStore,
                offers: offersStore, bookings: bookingsStore, chat: chatStore, isActiveTab: selection == .home,
                unreadMessageCount: messageUnreadCount,
                requestsAction: { openRequests(.matches) }, offersAction: { openRequests(.offers) },
                bookingAction: { booking in focusedBooking = booking; select(.bookings) }, messagesAction: { select(.messages) },
                availabilityAction: openAvailability, scheduleAction: { select(.bookings) },
                accountAction: { select(.account) })
        } else if tab == .requests, let requestsStore, let offersStore {
            GroomerRequestsView(route: Binding(get: { requestsRoute }, set: { requestsRoute = $0 }),
                requests: requestsStore, offers: offersStore,
                onOpenBooking: { focusedBooking = $0; select(.bookings) }, sessionIsCurrent: sessionIsCurrent)
        } else if tab == .bookings, let bookingsStore {
            GroomerScheduleView(store: bookingsStore,
                focusedBooking: Binding(get: { focusedBooking }, set: { focusedBooking = $0 }),
                isActiveTab: selection == .bookings, onOpenChat: openBookingChat,
                onSeeRequests: { select(.requests) })
        } else if tab == .messages,
                  let groomerID,
                  let chatRepository,
                  let bookingRepository {
            ChatConversationsView(
                participantID: groomerID,
                role: .groomer,
                repository: chatRepository,
                bookingRepository: bookingRepository,
                debugRecorder: debugRecorder,
                store: chatStore,
                focusedBookingID: Binding(get: { focusedConversationBookingID }, set: { focusedConversationBookingID = $0 })
            )
        } else if tab == .account, let profileStore {
            GroomerAccountView(store: profileStore,
                requestedRoute: Binding(get: { requestedProfileRoute }, set: { requestedProfileRoute = $0 }),
                onSignOut: { onSignOut?() }, authenticationStore: authenticationStore)
        } else if tab == .account, let accountContent {
            accountContent
        } else {
            FeaturePlaceholderView(
                title: tab.title,
                message: "Sign in with a groomer account to load this area.",
                systemImage: tab.systemImage,
                accent: .groomer
            )
        }
    }

    private func openBookingChat(_ booking: Booking) {
        focusedConversationBookingID = booking.id
        select(.messages)
    }

    private func select(_ tab: GroomerTab) { navigation.select(tab) }

    private func openAvailability() {
        requestedProfileRoute = .availability
        select(.account)
    }

    private func openRequests(_ route: GroomerRequestsRoute) {
        requestsRoute = route
        select(.requests)
    }

    private var notificationUnreadCount: Int {
        notificationStore?.unreadCount ?? 0
    }

    private var messageUnreadCount: Int {
        chatStore?.unreadConversationCount ?? 0
    }

    private func openNotificationRoute(_ route: GroomerNotificationRoute) {
        switch route {
        case .requests, .offers:
            if let target = GroomerRequestsRoute(notificationRoute: route) { openRequests(target) }
        case .bookings: select(.bookings)
        case let .messages(id): focusedConversationBookingID = id; select(.messages)
        }
    }

    private static func makeNotificationStore(
        groomerID: UUID?,
        repository: (any GroomerNotificationRepository)?
    ) -> GroomerNotificationsStore? {
        guard let groomerID, let repository else { return nil }

        return GroomerNotificationsStore(
            groomerID: groomerID,
            repository: repository
        )
    }

    private static func makeChatStore(
        groomerID: UUID?,
        repository: (any ChatRepository)?,
        bookingRepository: (any BookingRepository)?,
        displayCache: FileChatDisplayCache?
    ) -> ChatStore? {
        guard let groomerID, let repository, let bookingRepository else {
            return nil
        }

        return ChatStore(
            participantID: groomerID,
            role: .groomer,
            repository: repository,
            bookingRepository: bookingRepository,
            displayCache: displayCache
        )
    }

    private func refreshBadgeSources() async {
        if let notificationStore {
            await notificationStore.load()
        }
        if let chatStore {
            await chatStore.loadConversations()
        }
    }
}

extension GroomerTab {
    var icon: BeckonTabIcon {
        switch self {
        case .home: .home
        case .requests: .requests
        case .bookings: .schedule
        case .messages: .messages
        case .account: .account
        }
    }
}

private extension GroomerTab {
    var debugKey: String {
        switch self {
        case .home:
            "home"
        case .requests:
            "requests"
        case .bookings:
            "bookings"
        case .messages:
            "messages"
        case .account:
            "account"
        }
    }
}

#if DEBUG
extension GroomerTabView {
    init(sandbox: GroomerSandboxSession, initialTab: GroomerTab = .home, initialRoute: GroomerRequestsRoute = .matches,
         authenticationStore: AuthenticationStore? = nil, onSignOut: (() -> Void)? = nil) {
        self.init(groomerID: sandbox.groomerID, groomerDisplayName: sandbox.groomerName,
            profileRepository: sandbox.profileRepository, requestRepository: sandbox.requestRepository,
            notificationRepository: sandbox.notificationRepository, bookingRepository: sandbox.bookingRepository,
            chatRepository: sandbox.chatRepository, authenticationStore: authenticationStore ?? sandbox.authentication,
            onSignOut: onSignOut)
        _homeStore = State(initialValue: sandbox.home); _requestsStore = State(initialValue: sandbox.requests)
        _offersStore = State(initialValue: sandbox.offers); _bookingsStore = State(initialValue: sandbox.bookings)
        _profileStore = State(initialValue: sandbox.account); _notificationStore = State(initialValue: sandbox.notifications)
        _chatStore = State(initialValue: sandbox.chat); _navigation = State(initialValue: GroomerNavigation(selection: initialTab))
        navigation.requestsRoute = initialRoute
    }
}
#endif

#Preview {
    GroomerTabView()
}
