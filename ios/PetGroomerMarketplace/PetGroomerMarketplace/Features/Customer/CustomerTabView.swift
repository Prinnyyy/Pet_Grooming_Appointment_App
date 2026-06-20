import SwiftUI

struct CustomerTabView: View {
    @State private var selection: CustomerTab = .home

    var body: some View {
        TabView(selection: $selection) {
            ForEach(CustomerTab.allCases) { tab in
                NavigationStack {
                    FeaturePlaceholderView(
                        title: tab.title,
                        message: "Customer \(tab.title.lowercased()) is not connected yet.",
                        systemImage: tab.systemImage
                    )
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .accessibilityIdentifier("customer.tabs")
    }
}

#Preview {
    CustomerTabView()
}
