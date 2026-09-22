import SwiftUI

struct CustomerGroomerDiscoveryView: View {
    @Bindable var flow: CustomerRequestDiscoveryFlow
    let requests: CustomerRequestsStore
    let marketplace: CustomerMarketplaceSession
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsFullList = false
    @State private var detail: DiscoveredGroomer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let id = flow.requestID {
                    CustomerRequestProgressView(requestID: id, store: marketplace.distribution)
                } else {
                    Toggle("Also join the request pool", isOn: $flow.poolEnabled)
                        .accessibilityIdentifier("discovery.pool-consent")
                        .disabled(marketplace.publication.pending != nil)
                    Text("When enabled, all eligible groomers can see this request and send offers.")
                        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                if let error = flow.store.error {
                    BeckonErrorBanner(title: "Groomers could not be loaded", message: error.message)
                    Button("Refresh Groomers", systemImage: "arrow.clockwise") { Task { await load() } }
                        .accessibilityIdentifier("discovery.refresh")
                }
                if flow.store.isLoading && flow.store.candidates.isEmpty {
                    ProgressView("Finding groomers...").frame(maxWidth: .infinity, minHeight: 180)
                } else if flow.store.candidates.isEmpty && flow.store.error == nil {
                    ContentUnavailableView(flow.store.pendingCount > 0 ? "Checking Availability" : "No Groomers Available",
                        systemImage: "person.crop.circle.badge.clock",
                        description: Text(flow.store.pendingCount > 0 ? "Some groomers are still being checked." : "No groomers currently meet this request."))
                    Button("Edit Request", systemImage: "square.and.pencil") { dismiss() }
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
                } else if !flow.store.candidates.isEmpty {
                    carousel
                    if flow.store.pendingCount > 0 {
                        Text("\(flow.store.pendingCount) more availability checks pending").font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }
                if let error = marketplace.distribution.error {
                    BeckonErrorBanner(title: "Request update", message: error.message)
                }
                if let error = marketplace.favorites.error {
                    BeckonErrorBanner(title: "Favorites update", message: error.message)
                }
                if let error = requests.errorMessage { BeckonErrorBanner(title: "Publication recovery", message: error) }
                sendActions
                NavigationLink {
                    CustomerFavoriteGroomersView(marketplace: marketplace, scope: flow.store.actionScope, flow: flow,
                        onSend: { id in await requests.sendDiscovery(flow, groomerIDs: [id]) })
                } label: { Label("Saved Groomers", systemImage: "heart") }
                .accessibilityIdentifier("discovery.favorites")
            }
            .padding(DesignTokens.Spacing.screenHorizontal)
        }
        .background(DesignTokens.Colors.background)
        .navigationTitle(flow.requestID == nil ? "Choose Groomers" : "Invite Groomers")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(flow.requestID != nil)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if flow.requestID != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { requests.cancelWizard(); dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh groomers").help("Refresh groomers")
                    .accessibilityIdentifier("discovery.reload")
                    .disabled(flow.store.isLoading)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { flow.store.showAll() } label: { Image(systemName: "list.bullet") }
                    .accessibilityLabel("All eligible groomers").help("All eligible groomers")
                    .accessibilityIdentifier("discovery.show-all")
            }
        }
        .navigationDestination(isPresented: Binding(get: { flow.store.isShowingAll }, set: {
            if $0 { flow.store.showAll() } else { flow.store.showRecommendations() }
        })) {
            CustomerGroomerListView(flow: flow, requests: requests, marketplace: marketplace)
        }
        .sheet(item: $detail) { candidate in
            NavigationStack { CustomerGroomerDetailView(candidate: candidate, flow: flow, requests: requests, marketplace: marketplace) }
        }
        .confirmationDialog("Show all eligible groomers?", isPresented: $confirmsFullList, titleVisibility: .visible) {
            Button("Show All Groomers") { flow.store.showAll() }
            Button("Keep Browsing", role: .cancel) { flow.store.selectedGroomerID = flow.store.recommended.last?.id }
        }
        .task { if flow.store.page == nil { await load() } }
        .accessibilityIdentifier("customer.discovery")
    }

    private var carousel: some View {
        VStack(spacing: 10) {
            TabView(selection: Binding(get: { flow.store.selectedGroomerID }, set: { flow.store.selectedGroomerID = $0 })) {
                ForEach(flow.store.recommended) { candidate in
                    ScrollView {
                        CustomerGroomerCandidateView(candidate: candidate, flow: flow, requests: requests,
                            marketplace: marketplace, compact: false, onDetails: { detail = candidate })
                            .padding(.horizontal, DesignTokens.Spacing.xs).padding(.bottom, DesignTokens.Spacing.screenHorizontal)
                    }
                    .tag(Optional(candidate.id))
                }
                VStack(spacing: 16) {
                    Image(systemName: "person.3").font(DesignTokens.Typography.largeTitle)
                    Button("Show All Groomers") { confirmsFullList = true }
                        .buttonStyle(BeckonPrimaryButtonStyle(accent: .customer)).accessibilityIdentifier("discovery.more")
                }
                .tag(Optional<UUID>.none)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 510)
            .onChange(of: flow.store.selectedGroomerID) { _, id in
                if id == nil && !flow.store.recommended.isEmpty { confirmsFullList = true }
            }
            let index = flow.store.recommended.firstIndex { $0.id == flow.store.selectedGroomerID }
            Text(index.map { "\($0 + 1) of \(flow.store.recommended.count)" } ?? "More Groomers")
                .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                .accessibilityIdentifier("discovery.page-position")
        }
    }

    @ViewBuilder private var sendActions: some View {
        if let pending = marketplace.publication.pending, pending.acknowledgement != nil {
            Button("Finish Request Sync", systemImage: "arrow.clockwise") {
                Task { await requests.publish() }
            }
            .disabled(requests.isSubmitting)
            .accessibilityIdentifier("discovery.finish-publication")
        } else if let pending = marketplace.publication.pending, pending.acknowledgement == nil {
            Button("Retry Sending Request", systemImage: "arrow.clockwise") {
                Task { await requests.sendDiscovery(flow, groomerIDs: pending.groomerIDs) }
            }
            .disabled(marketplace.distribution.isPublishing)
            .accessibilityIdentifier("discovery.retry-publication")
        } else if flow.requestID == nil && flow.poolEnabled {
            CustomerRequestSendButton(title: "Publish to Request Pool", confirmation: flow.publicationConfirmation(names: [])) {
                Task { await requests.sendDiscovery(flow, groomerIDs: []) }
            }
            .buttonStyle(BeckonPrimaryButtonStyle(accent: .customer))
            .disabled(marketplace.distribution.isPublishing || requests.isSubmitting)
            .accessibilityIdentifier("discovery.publish-pool")
        }
    }

    private func load() async {
        let epoch = marketplace.favorites.readEpoch
        await flow.store.load()
        marketplace.favorites.merge(Dictionary(uniqueKeysWithValues: flow.store.candidates.map { ($0.id, $0.favoriteState) }), since: epoch)
    }
}

struct CustomerGroomerCandidateView: View {
    let candidate: DiscoveredGroomer
    @Bindable var flow: CustomerRequestDiscoveryFlow
    let requests: CustomerRequestsStore
    let marketplace: CustomerMarketplaceSession
    let compact: Bool
    let onDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onDetails) {
                GroomerCandidateSummaryView(profile: candidate.profile, avatarData: marketplace.avatarData[candidate.id],
                    candidate: candidate, compact: compact)
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("discovery.profile.\(candidate.id.uuidString)")
            GroomerCandidateActionsView(id: candidate.id,
                isFavorite: (marketplace.favorites.state(for: candidate.id) ?? candidate.favoriteState).isFavorite,
                invitation: marketplace.distribution.state(requestID: flow.requestID, groomerID: candidate.id, seed: candidate.invitationState),
                disabled: marketplace.distribution.isPublishing || requests.isSubmitting
                    || flow.requestID.map { marketplace.distribution.mutatingIDs.contains($0) } == true
                    || marketplace.publication.pending?.acknowledgement == nil && marketplace.publication.pending != nil,
                onFavorite: { Task { await marketplace.favorites.setFavorite(candidate.id,
                    enabled: !(marketplace.favorites.state(for: candidate.id) ?? candidate.favoriteState).isFavorite) } },
                onSend: { Task { await requests.sendDiscovery(flow, groomerIDs: [candidate.id]) } },
                publicationConfirmation: flow.publicationConfirmation(names: [candidate.profile.displayName]))
        }
        .task(id: candidate.profile.avatarPath) { await marketplace.loadAvatar(candidate.profile) }
    }
}
