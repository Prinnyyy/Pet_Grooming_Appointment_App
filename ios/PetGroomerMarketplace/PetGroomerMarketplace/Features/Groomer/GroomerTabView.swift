import SwiftUI

struct GroomerTabView: View {
    @Environment(\.appDebugEventRecorder) private var debugRecorder
    let groomerID: UUID?
    let profileRepository: (any GroomerProfileRepository)?
    let requestRepository: (any GroomerRequestRepository)?
    let bookingRepository: (any BookingRepository)?
    let chatRepository: (any ChatRepository)?
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?
    @State private var selection: GroomerTab = .requests
    @State private var focusedConversationBookingID: UUID?
    @State private var feedbackCenter = GroomlyFeedbackCenter()

    init(
        groomerID: UUID? = nil,
        profileRepository: (any GroomerProfileRepository)? = nil,
        requestRepository: (any GroomerRequestRepository)? = nil,
        bookingRepository: (any BookingRepository)? = nil,
        chatRepository: (any ChatRepository)? = nil,
        accountContent: AnyView? = nil,
        onSignOut: (() -> Void)? = nil
    ) {
        self.groomerID = groomerID
        self.profileRepository = profileRepository
        self.requestRepository = requestRepository
        self.bookingRepository = bookingRepository
        self.chatRepository = chatRepository
        self.accountContent = accountContent
        self.onSignOut = onSignOut
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
                focusedBookingID: $focusedConversationBookingID
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
        case .account:
            "account"
        }
    }
}

#Preview {
    GroomerTabView()
}
