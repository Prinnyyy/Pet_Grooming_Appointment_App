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
        // The profile is its own page, dealt in once it is there; the loading and failure states are a page of their own, shown at once.
        Group {
            if let current {
                // The groomer's page: all that the app holds about them. The bar is the request's action (select, send, or the state
                // of the invitation); the heart is the page's own.
                CustomerGroomerProfilePage(groomerID: current.id, marketplace: marketplace,
                    context: context(for: current), isFavorite: isFavorite(current), onFavorite: { toggleFavorite(current) },
                    onClose: { dismiss() }) {
                    BeckonPinnedBar {
                        CustomerGroomerCandidateView(candidate: current, flow: flow, requests: requests,
                            marketplace: marketplace, compact: false, onDetails: {}, selection: selection,
                            showsSummary: false, showsFavorite: false)
                    }
                }
                .task(id: current.profile.avatarPath) { await marketplace.loadAvatar(current.profile) }
            } else {
                DesignPage(cascades: false) {
                    if let error {
                        BeckonErrorBanner(title: "Profile unavailable", message: error.message)
                        Button { Task { await load() } } label: {
                            DesignQuietAction(title: "Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(BeckonGuardedPlainButtonStyle())
                    } else {
                        BeckonLoadingView(title: "Loading profile…", message: "Fetching this groomer's details.", accent: .customer)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) { DesignSheetBar(title: "Groomer profile", closeIdentifier: "customer.groomer-profile.close") { dismiss() } }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private func context(for groomer: DiscoveredGroomer) -> GroomerProfileContext {
        GroomerProfileContext(
            petName: flow.requestID.flatMap { requests.request(withID: $0)?.petSnapshot.name },
            eligibilityState: groomer.eligibility.state, distanceMiles: groomer.distanceMiles,
            referencePrice: groomer.referencePrice, evidence: groomer.matchingEvidence)
    }

    private func isFavorite(_ groomer: DiscoveredGroomer) -> Bool {
        (marketplace.favorites.state(for: groomer.id) ?? groomer.favoriteState).isFavorite
    }

    private func toggleFavorite(_ groomer: DiscoveredGroomer) {
        let enabled = !isFavorite(groomer)
        Task { await marketplace.favorites.setFavorite(groomer.id, enabled: enabled) }
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
