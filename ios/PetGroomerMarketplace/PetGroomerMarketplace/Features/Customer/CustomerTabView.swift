import SwiftUI

struct CustomerTabView: View {
    let customerID: UUID?
    let petRepository: (any CustomerPetRepository)?
    let requestRepository: (any CustomerRequestRepository)?
    let accountContent: AnyView?
    @State private var selection: CustomerTab = .home

    init(
        customerID: UUID? = nil,
        petRepository: (any CustomerPetRepository)? = nil,
        requestRepository: (any CustomerRequestRepository)? = nil,
        accountContent: AnyView? = nil
    ) {
        self.customerID = customerID
        self.petRepository = petRepository
        self.requestRepository = requestRepository
        self.accountContent = accountContent
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(CustomerTab.allCases) { tab in
                NavigationStack {
                    destination(for: tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
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
                  let requestRepository {
            CustomerRequestsView(
                customerID: customerID,
                petRepository: petRepository,
                requestRepository: requestRepository
            )
        } else if tab == .account, let accountContent {
            accountContent
        } else {
            FeaturePlaceholderView(
                title: tab.title,
                message: "Customer \(tab.title.lowercased()) is not connected yet.",
                systemImage: tab.systemImage
            )
        }
    }
}

#Preview {
    CustomerTabView()
}
