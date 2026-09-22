import SwiftUI

struct CustomerGroomerDetailView: View {
    let candidate: DiscoveredGroomer
    let flow: CustomerRequestDiscoveryFlow
    let requests: CustomerRequestsStore
    let marketplace: CustomerMarketplaceSession
    @Environment(\.dismiss) private var dismiss
    @State private var current: DiscoveredGroomer?
    @State private var error: RequestDiscoveryError?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error {
                    BeckonErrorBanner(title: "Profile unavailable", message: error.message)
                    Button("Retry", systemImage: "arrow.clockwise") { Task { await load() } }
                } else if let current {
                    CustomerGroomerCandidateView(candidate: current, flow: flow, requests: requests,
                        marketplace: marketplace, compact: false, onDetails: {})
                } else { ProgressView("Loading profile...") }
            }.padding(DesignTokens.Spacing.screenHorizontal)
        }
        .navigationTitle("Groomer Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .task { await load() }
        .accessibilityIdentifier("customer.discovery.detail")
    }

    private func load() async {
        current = nil; error = nil
        let epoch = marketplace.favorites.readEpoch
        do {
            let profile = try await flow.store.detail(for: candidate.id)
            marketplace.favorites.merge([profile.id: profile.favoriteState], since: epoch)
            current = profile
        } catch {
            marketplace.revokeAvatar(candidate.id)
            self.error = (error as? RequestDiscoveryError) ?? .unavailable
        }
    }
}
