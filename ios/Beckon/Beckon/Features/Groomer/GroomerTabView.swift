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
    let onSignOut: (() -> Void)?
    @State private var selection: GroomerTab = .home
    @State private var focusedConversationBookingID: UUID?
    @State private var requestedProfileRoute: GroomerProfileRoute?
    @State private var requestsRoute: GroomerRequestsRoute = .matches
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
        onSignOut: (() -> Void)? = nil
    ) {
        self.groomerID = groomerID
        self.groomerDisplayName = groomerDisplayName
        self.profileRepository = profileRepository
        self.requestRepository = requestRepository
        self.notificationRepository = notificationRepository
        self.bookingRepository = bookingRepository
        self.chatRepository = chatRepository
        self.accountContent = accountContent
        self.onSignOut = onSignOut
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
                bookingRepository: bookingRepository
            )
        )
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(GroomerTab.allCases) { tab in
                NavigationStack {
                    destination(for: tab)
                        .background(DesignTokens.Colors.background)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                        .accessibilityIdentifier(tab.accessibilityIdentifier)
                }
                .badge(
                    tab.badgeCount(
                        unreadNotificationCount: notificationUnreadCount,
                        unreadMessageCount: messageUnreadCount
                    )
                )
                .tag(tab)
            }
        }
        .tint(DesignTokens.Colors.groomerAccentDark)
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .toolbarBackground(DesignTokens.Colors.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environment(\.beckonFeedbackCenter, feedbackCenter)
        .overlay(alignment: .bottom) {
            BeckonGlobalFeedbackOverlay(center: feedbackCenter)
        }
        .onAppear {
            feedbackCenter.setDebugRecorder(debugRecorder)
            chatStore?.setDebugRecorder(debugRecorder)
        }
        .task {
            await refreshBadgeSources()
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
        if tab == .home,
           let groomerID,
           let profileRepository,
           let requestRepository,
           let bookingRepository {
            GroomerHomeView(
                groomerID: groomerID,
                displayName: groomerDisplayName,
                profileRepository: profileRepository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository,
                unreadNotificationCount: notificationUnreadCount,
                unreadMessageCount: messageUnreadCount,
                notificationStore: notificationStore,
                debugRecorder: debugRecorder,
                chatStore: chatStore,
                requestsAction: { openRequests(.matches) },
                offersAction: { openRequests(.offers) },
                bookingAction: { _ in select(.bookings) },
                messagesAction: { select(.messages) },
                availabilityAction: openAvailability
            )
        } else if tab == .requests,
           let groomerID,
           let requestRepository {
            GroomerRequestsView(
                groomerID: groomerID,
                repository: requestRepository,
                profileRepository: profileRepository,
                route: $requestsRoute,
                debugRecorder: debugRecorder
            )
        } else if tab == .bookings,
                  let groomerID,
                  let bookingRepository {
            BookingsView(
                participantID: groomerID,
                role: .groomer,
                repository: bookingRepository,
                groomerProfileRepository: profileRepository,
                debugRecorder: debugRecorder,
                onOpenChat: openBookingChat
            )
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
                focusedBookingID: $focusedConversationBookingID
            )
        } else if tab == .account,
           let groomerID,
           let profileRepository {
            GroomerProfileManagementView(
                groomerID: groomerID,
                repository: profileRepository,
                debugRecorder: debugRecorder,
                requestedRoute: $requestedProfileRoute,
                accountContent: accountContent,
                onSignOut: onSignOut
            )
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

    private func select(_ tab: GroomerTab) {
        withAnimation(.easeInOut(duration: 0.22)) {
            selection = tab
        }
    }

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
        withAnimation(.easeInOut(duration: 0.22)) {
            switch route {
            case .requests, .offers:
                if let requestsRoute = GroomerRequestsRoute(notificationRoute: route) {
                    self.requestsRoute = requestsRoute
                }
                selection = .requests
            case .bookings:
                selection = .bookings
            case let .messages(bookingID):
                focusedConversationBookingID = bookingID
                selection = .messages
            }
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
        bookingRepository: (any BookingRepository)?
    ) -> ChatStore? {
        guard let groomerID, let repository, let bookingRepository else {
            return nil
        }

        return ChatStore(
            participantID: groomerID,
            role: .groomer,
            repository: repository,
            bookingRepository: bookingRepository
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

#Preview {
    GroomerTabView()
}
