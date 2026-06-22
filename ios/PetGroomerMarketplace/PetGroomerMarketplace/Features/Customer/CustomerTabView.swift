import SwiftUI

struct CustomerTabView: View {
    let customerID: UUID?
    let petRepository: (any CustomerPetRepository)?
    let requestRepository: (any CustomerRequestRepository)?
    let bookingRepository: (any BookingRepository)?
    let chatRepository: (any ChatRepository)?
    let accountContent: AnyView?
    @State private var selection: CustomerTab = .home

    init(
        customerID: UUID? = nil,
        petRepository: (any CustomerPetRepository)? = nil,
        requestRepository: (any CustomerRequestRepository)? = nil,
        bookingRepository: (any BookingRepository)? = nil,
        chatRepository: (any ChatRepository)? = nil,
        accountContent: AnyView? = nil
    ) {
        self.customerID = customerID
        self.petRepository = petRepository
        self.requestRepository = requestRepository
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
        .accessibilityIdentifier("customer.tabs")
    }

    @ViewBuilder
    private func destination(for tab: CustomerTab) -> some View {
        if tab == .home, let customerID, let petRepository {
            CustomerPetsView(
                customerID: customerID,
                repository: petRepository
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
                bookingRepository: bookingRepository
            )
        } else if tab == .bookings,
                  let customerID,
                  let bookingRepository {
            BookingsView(
                participantID: customerID,
                role: .customer,
                repository: bookingRepository
            )
        } else if tab == .messages,
                  let customerID,
                  let chatRepository {
            ChatConversationsView(
                participantID: customerID,
                role: .customer,
                repository: chatRepository
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
}

#Preview {
    CustomerTabView()
}
