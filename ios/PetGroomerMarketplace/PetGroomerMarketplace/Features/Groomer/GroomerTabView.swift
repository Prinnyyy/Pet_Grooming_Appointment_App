import SwiftUI

struct GroomerTabView: View {
    let groomerID: UUID?
    let profileRepository: (any GroomerProfileRepository)?
    let requestRepository: (any GroomerRequestRepository)?
    let accountContent: AnyView?
    @State private var selection: GroomerTab = .requests

    init(
        groomerID: UUID? = nil,
        profileRepository: (any GroomerProfileRepository)? = nil,
        requestRepository: (any GroomerRequestRepository)? = nil,
        accountContent: AnyView? = nil
    ) {
        self.groomerID = groomerID
        self.profileRepository = profileRepository
        self.requestRepository = requestRepository
        self.accountContent = accountContent
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(GroomerTab.allCases) { tab in
                NavigationStack {
                    destination(for: tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
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
        } else if tab == .account,
           let groomerID,
           let profileRepository {
            GroomerProfileManagementView(
                groomerID: groomerID,
                repository: profileRepository,
                accountContent: accountContent
            )
        } else if tab == .account, let accountContent {
            accountContent
        } else {
            FeaturePlaceholderView(
                title: tab.title,
                message: "Groomer \(tab.title.lowercased()) is not connected yet.",
                systemImage: tab.systemImage
            )
        }
    }
}

#Preview {
    GroomerTabView()
}
