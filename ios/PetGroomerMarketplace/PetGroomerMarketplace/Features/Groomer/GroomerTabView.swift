import SwiftUI

struct GroomerTabView: View {
    @Environment(\.appDebugEventRecorder) private var debugRecorder
    let groomerID: UUID?
    let profileRepository: (any GroomerProfileRepository)?
    let requestRepository: (any GroomerRequestRepository)?
    let notificationRepository: (any GroomerNotificationRepository)?
    let bookingRepository: (any BookingRepository)?
    let chatRepository: (any ChatRepository)?
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?
    @State private var selection: GroomerTab = .requests
    @State private var focusedConversationBookingID: UUID?
    @State private var notificationStore: GroomerNotificationsStore?
    @State private var chatStore: ChatStore?
    @State private var feedbackCenter = GroomlyFeedbackCenter()

    init(
        groomerID: UUID? = nil,
        profileRepository: (any GroomerProfileRepository)? = nil,
        requestRepository: (any GroomerRequestRepository)? = nil,
        notificationRepository: (any GroomerNotificationRepository)? = nil,
        bookingRepository: (any BookingRepository)? = nil,
        chatRepository: (any ChatRepository)? = nil,
        accountContent: AnyView? = nil,
        onSignOut: (() -> Void)? = nil
    ) {
        self.groomerID = groomerID
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
                repository: chatRepository
            )
        )
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(GroomerTab.visibleCases) { tab in
                NavigationStack {
                    destination(for: tab)
                        .background(DesignTokens.Colors.background)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
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
        .environment(\.groomlyFeedbackCenter, feedbackCenter)
        .overlay(alignment: .bottom) {
            GroomlyGlobalFeedbackOverlay(center: feedbackCenter)
        }
        .onAppear {
            feedbackCenter.setDebugRecorder(debugRecorder)
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
        if tab == .requests,
           let groomerID,
           let requestRepository {
            GroomerRequestsView(
                groomerID: groomerID,
                repository: requestRepository,
                debugRecorder: debugRecorder
            )
        } else if tab == .offers,
                  let groomerID,
                  let requestRepository {
            GroomerOffersView(
                groomerID: groomerID,
                repository: requestRepository
            )
        } else if tab == .bookings,
                  let groomerID,
                  let bookingRepository {
            BookingsView(
                participantID: groomerID,
                role: .groomer,
                repository: bookingRepository,
                debugRecorder: debugRecorder,
                onOpenChat: openBookingChat
            )
        } else if tab == .messages,
                  let groomerID,
                  let chatRepository {
            ChatConversationsView(
                participantID: groomerID,
                role: .groomer,
                repository: chatRepository,
                debugRecorder: debugRecorder,
                store: chatStore,
                focusedBookingID: $focusedConversationBookingID
            )
        } else if tab == .notifications,
                  let notificationStore {
            GroomerNotificationsView(
                store: notificationStore,
                routeAction: openNotificationRoute
            )
        } else if tab == .account,
           let groomerID,
           let profileRepository {
            GroomerProfileManagementView(
                groomerID: groomerID,
                repository: profileRepository,
                debugRecorder: debugRecorder,
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
        withAnimation(.easeInOut(duration: 0.22)) {
            selection = .messages
        }
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
            case .requests:
                selection = .requests
            case .offers:
                selection = .offers
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
        repository: (any ChatRepository)?
    ) -> ChatStore? {
        guard let groomerID, let repository else { return nil }

        return ChatStore(
            participantID: groomerID,
            role: .groomer,
            repository: repository
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
        case .requests:
            "requests"
        case .offers:
            "offers"
        case .bookings:
            "bookings"
        case .messages:
            "messages"
        case .notifications:
            "notifications"
        case .account:
            "account"
        }
    }
}

#Preview {
    GroomerTabView()
}
