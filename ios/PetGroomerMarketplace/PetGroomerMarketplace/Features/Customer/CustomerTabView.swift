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
    @State private var feedbackCenter = GroomlyFeedbackCenter()

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
                }
                .tag(tab)
            }
        }
        .tint(DesignTokens.Colors.customerPrimaryDark)
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
                onBookingChatSelected: openBookingChat
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
