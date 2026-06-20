import SwiftUI

struct GroomerTabView: View {
    @State private var selection: GroomerTab = .requests

    var body: some View {
        TabView(selection: $selection) {
            ForEach(GroomerTab.allCases) { tab in
                NavigationStack {
                    FeaturePlaceholderView(
                        title: tab.title,
                        message: "Groomer \(tab.title.lowercased()) is not connected yet.",
                        systemImage: tab.systemImage
                    )
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .accessibilityIdentifier("groomer.tabs")
    }
}

#Preview {
    GroomerTabView()
}
