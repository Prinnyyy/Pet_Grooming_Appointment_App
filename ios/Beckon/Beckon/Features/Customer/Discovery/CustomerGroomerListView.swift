import SwiftUI

struct CustomerGroomerListView: View {
    @Bindable var flow: CustomerRequestDiscoveryFlow
    let requests: CustomerRequestsStore
    let marketplace: CustomerMarketplaceSession
    @State private var detail: DiscoveredGroomer?

    var body: some View {
        List {
            Picker("Sort", selection: Binding(get: { flow.store.sort }, set: { sort in
                Task {
                    let epoch = marketplace.favorites.readEpoch
                    await flow.store.changeSort(to: sort)
                    mergeFavorites(since: epoch)
                }
            })) {
                ForEach(GroomerDiscoverySort.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("discovery.sort")
            if let error = flow.store.error {
                BeckonErrorBanner(title: "List changed", message: error.message)
                Button("Refresh") { Task {
                    let epoch = marketplace.favorites.readEpoch
                    await flow.store.load(); mergeFavorites(since: epoch)
                } }
            }
            ForEach(flow.store.candidates) { candidate in
                CustomerGroomerCandidateView(candidate: candidate, flow: flow, requests: requests,
                    marketplace: marketplace, compact: true, onDetails: { detail = candidate })
                    .padding(.vertical, DesignTokens.Spacing.md)
            }
            if flow.store.isLoading || flow.store.isLoadingMore { ProgressView() }
            if flow.store.canLoadMore {
                Button("Load More Groomers", systemImage: "arrow.down") {
                    Task {
                        let epoch = marketplace.favorites.readEpoch
                        await flow.store.loadNextPage(); mergeFavorites(since: epoch)
                    }
                }.accessibilityIdentifier("discovery.load-more")
            }
            if let error = marketplace.distribution.error { Text(error.message).foregroundStyle(DesignTokens.Colors.errorText) }
            if let error = marketplace.favorites.error { Text(error.message).foregroundStyle(DesignTokens.Colors.errorText) }
        }
        .listStyle(.plain)
        .navigationTitle("All Eligible Groomers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { candidate in
            NavigationStack { CustomerGroomerDetailView(candidate: candidate, flow: flow, requests: requests, marketplace: marketplace) }
        }
        .accessibilityIdentifier("customer.discovery.list")
    }

    private func mergeFavorites(since epoch: UInt64) {
        marketplace.favorites.merge(Dictionary(uniqueKeysWithValues: flow.store.candidates.map { ($0.id, $0.favoriteState) }), since: epoch)
    }
}
