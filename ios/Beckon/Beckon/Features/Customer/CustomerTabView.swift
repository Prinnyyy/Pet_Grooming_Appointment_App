import SwiftUI

struct CustomerTabView: View {
    @Environment(\.appDebugEventRecorder) private var debugRecorder
    let customerID: UUID?
    let customerDisplayName: String?
    let customerProfileRepository: (any CustomerProfileRepository)?
    let petRepository: (any CustomerPetRepository)?
    let requestRepository: (any CustomerRequestRepository)?
    let notificationRepository: (any CustomerNotificationRepository)?
    let bookingRepository: (any BookingRepository)?
    let chatRepository: (any ChatRepository)?
    let accountContent: AnyView?
    @State private var selection: CustomerTab = .home
    @State private var focusedRequestID: UUID?
    @State private var focusedConversationBookingID: UUID?
    @State private var notificationStore: CustomerNotificationsStore?
    @State private var chatStore: ChatStore?
    @State private var requestStore: CustomerRequestsStore?
    @State private var feedbackCenter = BeckonFeedbackCenter()

    init(
        customerID: UUID? = nil,
        customerDisplayName: String? = nil,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        petRepository: (any CustomerPetRepository)? = nil,
        requestRepository: (any CustomerRequestRepository)? = nil,
        notificationRepository: (any CustomerNotificationRepository)? = nil,
        bookingRepository: (any BookingRepository)? = nil,
        chatRepository: (any ChatRepository)? = nil,
        accountContent: AnyView? = nil
    ) {
        self.customerID = customerID
        self.customerDisplayName = customerDisplayName
        self.customerProfileRepository = customerProfileRepository
        self.petRepository = petRepository
        self.requestRepository = requestRepository
        self.notificationRepository = notificationRepository
        self.bookingRepository = bookingRepository
        self.chatRepository = chatRepository
        self.accountContent = accountContent
        _notificationStore = State(
            initialValue: Self.makeNotificationStore(
                customerID: customerID,
                repository: notificationRepository
            )
        )
        _chatStore = State(
            initialValue: Self.makeChatStore(
                customerID: customerID,
                repository: chatRepository
            )
        )
        _requestStore = State(
            initialValue: Self.makeRequestStore(
                customerID: customerID,
                petRepository: petRepository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository
            )
        )
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(CustomerTab.allCases) { tab in
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
        .tint(DesignTokens.Colors.customerPrimaryDark)
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
            requestStore?.setDebugRecorder(debugRecorder)
        }
        .task {
            await refreshBadgeSources()
        }
        .onChange(of: selection) { oldValue, newValue in
            debugRecorder?.record(
                level: .info,
                category: .navigation,
                source: "CustomerTabView.selection",
                scope: "customer.\(newValue.debugKey)",
                message: "\(oldValue.debugKey) -> \(newValue.debugKey)",
                metadata: [
                    "from": "customer.\(oldValue.debugKey)",
                    "to": "customer.\(newValue.debugKey)",
                ]
            )
        }
        .accessibilityIdentifier("customer.tabs")
    }

    @ViewBuilder
    private func destination(for tab: CustomerTab) -> some View {
        if tab == .home,
           let customerID,
           let petRepository,
           let requestRepository,
           let notificationRepository,
           let bookingRepository {
            CustomerPetsView(
                customerID: customerID,
                displayName: customerDisplayName,
                repository: petRepository,
                customerProfileRepository: customerProfileRepository,
                requestRepository: requestRepository,
                notificationRepository: notificationRepository,
                bookingRepository: bookingRepository,
                debugRecorder: debugRecorder,
                notificationStore: notificationStore,
                requestStore: requestStore,
                onActiveRequestSelected: { requestID in
                    focusedRequestID = requestID
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selection = .requests
                    }
                },
                onBookingChatSelected: openBookingChat
            )
        } else if tab == .requests,
                  let customerID,
                  let petRepository,
                  let requestRepository,
                  let bookingRepository {
            CustomerRequestsView(
                customerID: customerID,
                petRepository: petRepository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository,
                customerProfileRepository: customerProfileRepository,
                debugRecorder: debugRecorder,
                focusedRequestID: $focusedRequestID,
                onBookingChatSelected: openBookingChat,
                store: requestStore
            )
        } else if tab == .bookings,
                  let customerID,
                  let bookingRepository {
            BookingsView(
                participantID: customerID,
                role: .customer,
                repository: bookingRepository,
                petRepository: petRepository,
                requestRepository: requestRepository,
                customerProfileRepository: customerProfileRepository,
                debugRecorder: debugRecorder,
                onOpenChat: openBookingChat
            )
        } else if tab == .messages,
                  let customerID,
                  let chatRepository {
            ChatConversationsView(
                participantID: customerID,
                role: .customer,
                repository: chatRepository,
                debugRecorder: debugRecorder,
                store: chatStore,
                focusedBookingID: $focusedConversationBookingID
            )
        } else if tab == .account, let accountContent {
            accountContent
        } else {
            FeaturePlaceholderView(
                title: tab.title,
                message: "Customer \(tab.title.lowercased()) is not connected yet.",
                systemImage: tab.systemImage,
                accent: .customer
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

    private static func makeNotificationStore(
        customerID: UUID?,
        repository: (any CustomerNotificationRepository)?
    ) -> CustomerNotificationsStore? {
        guard let customerID, let repository else { return nil }

        return CustomerNotificationsStore(
            customerID: customerID,
            repository: repository
        )
    }

    private static func makeChatStore(
        customerID: UUID?,
        repository: (any ChatRepository)?
    ) -> ChatStore? {
        guard let customerID, let repository else { return nil }

        return ChatStore(
            participantID: customerID,
            role: .customer,
            repository: repository
        )
    }

    private static func makeRequestStore(
        customerID: UUID?,
        petRepository: (any CustomerPetRepository)?,
        requestRepository: (any CustomerRequestRepository)?,
        bookingRepository: (any BookingRepository)?
    ) -> CustomerRequestsStore? {
        guard let customerID, let petRepository, let requestRepository,
              let bookingRepository else { return nil }
        return CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: requestRepository,
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

private extension CustomerTab {
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
    CustomerTabView()
}
