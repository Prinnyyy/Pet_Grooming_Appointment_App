import SwiftUI

struct CustomerGroomerDetailView: View {
    let candidate: DiscoveredGroomer
    let flow: CustomerRequestDiscoveryFlow
    let requests: CustomerRequestsStore
    let marketplace: CustomerMarketplaceSession
    /// Passed by "Choose groomers" so the profile ticks the groomer into the same selection; nil keeps the per-groomer send.
    var selection: Binding<GroomerSelection>? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var current: DiscoveredGroomer?
    @State private var error: RequestDiscoveryError?

    var body: some View {
        // The profile is dealt in once it is there; the loading and failure states around it are shown at once.
        DesignPage(cascades: false) {
            if let error {
                BeckonErrorBanner(title: "Profile unavailable", message: error.message)
                Button { Task { await load() } } label: {
                    DesignQuietAction(title: "Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
            } else if let current {
                CustomerGroomerCandidateView(candidate: current, flow: flow, requests: requests,
                    marketplace: marketplace, compact: false, onDetails: {}, selection: selection)
                    .designCardBody()
                    .beckonEntrance(0)
            } else {
                BeckonLoadingView(title: "Loading profile…", message: "Fetching this groomer's details.", accent: .customer)
            }
        }
        .navigationTitle("Groomer profile")
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
