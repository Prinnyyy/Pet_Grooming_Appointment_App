import SwiftUI

struct GroomerTabView: View {
    let groomerID: UUID?
    let profileRepository: (any GroomerProfileRepository)?
    let requestRepository: (any GroomerRequestRepository)?
    let bookingRepository: (any BookingRepository)?
    let chatRepository: (any ChatRepository)?
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?
    @State private var selection: GroomerTab = .requests
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
            ForEach(GroomerTab.allCases) { tab in
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
        .accessibilityIdentifier("groomer.tabs")
    }

    @ViewBuilder
    private func destination(for tab: GroomerTab) -> some View {
        if tab == .requests,
           let groomerID,
           let requestRepository {
            GroomerRequestsView(
                groomerID: groomerID,
                repository: requestRepository
            )
        } else if tab == .bookings,
                  let groomerID,
                  let bookingRepository {
            BookingsView(
                participantID: groomerID,
                role: .groomer,
                repository: bookingRepository
            )
        } else if tab == .messages,
                  let groomerID,
                  let chatRepository {
            ChatConversationsView(
                participantID: groomerID,
                role: .groomer,
                repository: chatRepository
            )
        } else if tab == .account,
           let groomerID,
           let profileRepository {
            GroomerProfileManagementView(
                groomerID: groomerID,
                repository: profileRepository,
                accountContent: accountContent,
                onSignOut: onSignOut
            )
        } else if tab == .account, let accountContent {
            accountContent
        } else {
            FeaturePlaceholderView(
                title: tab.title,
                message: "Groomer \(tab.title.lowercased()) is not connected yet.",
                systemImage: tab.systemImage,
                accent: .groomer
            )
        }
    }
}

#Preview {
    GroomerTabView()
}
