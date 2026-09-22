import SwiftUI

struct CustomerFavoriteGroomersView: View {
    let marketplace: CustomerMarketplaceSession
    let onSend: ((UUID) async -> Void)?
    let flow: CustomerRequestDiscoveryFlow?
    @State private var scope: GroomerDiscoveryScope?
    @State private var isLoadingRequests = false
    @State private var requestError: String?

    init(marketplace: CustomerMarketplaceSession, scope: GroomerDiscoveryScope? = nil, flow: CustomerRequestDiscoveryFlow? = nil,
         onSend: ((UUID) async -> Void)? = nil) {
        self.marketplace = marketplace; self.onSend = onSend; self.flow = flow
        _scope = State(initialValue: scope)
    }

    var body: some View {
        List {
            if onSend == nil {
                Menu {
                    Button("No Request Selected") { choose(nil) }
                    ForEach(marketplace.requestOptions()) { request in
                        if let revision = request.termsRevision {
                            Button("\(request.petSnapshot.name) - \(request.serviceType.title) (\(request.id.uuidString.prefix(8)))") {
                                choose(.request(id: request.id, termsRevision: revision))
                            }
                            .accessibilityIdentifier("favorites.request.\(request.id.uuidString)")
                        }
                    }
                } label: {
                    Label(scope == nil ? "Choose a Request" : "Change Request", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(isLoadingRequests)
                .accessibilityIdentifier("favorites.choose-request")
                if let requestError {
                    BeckonErrorBanner(title: "Requests could not be loaded", message: requestError)
                    Button("Retry Requests", systemImage: "arrow.clockwise") { Task { await refreshRequests() } }
                }
                Button("Create Request", systemImage: "plus") { marketplace.createRequest?() }
                    .accessibilityIdentifier("favorites.create-request")
            }
            if let error = marketplace.favorites.error {
                BeckonErrorBanner(title: "Favorites could not be loaded", message: error.message)
                Button("Retry", systemImage: "arrow.clockwise") { Task { await load() } }
            } else if marketplace.favorites.hasLoaded && marketplace.favorites.items.isEmpty {
                ContentUnavailableView("No Saved Groomers", systemImage: "heart")
            }
            ForEach(marketplace.favorites.items) { favorite in
                VStack(alignment: .leading, spacing: 12) {
                    if let profile = favorite.profile {
                        GroomerCandidateSummaryView(profile: profile, avatarData: marketplace.avatarData[favorite.id], compact: true)
                            .task(id: profile.avatarPath) { await marketplace.loadAvatar(profile) }
                    } else {
                        Label(favorite.availability == .paused ? "Groomer temporarily unavailable" : "Groomer unavailable", systemImage: "person.crop.circle.badge.xmark")
                            .task { marketplace.revokeAvatar(favorite.id) }
                    }
                    HStack {
                        Button {
                            Task { await marketplace.favorites.setFavorite(favorite.id, enabled: false) }
                        } label: { Image(systemName: "heart.fill").frame(width: 44, height: 44) }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove favorite")
                        .accessibilityIdentifier("favorites.remove.\(favorite.id.uuidString)")
                        .disabled(marketplace.favorites.mutatingIDs.contains(favorite.id))
                        Spacer(minLength: 8)
                        if scope != nil {
                            let eligible = favorite.eligibility.map { ["estimated_fit", "assessment_required"].contains($0.state) } == true
                            let state = marketplace.distribution.state(requestID: requestID, groomerID: favorite.id, seed: favorite.invitationState)
                            if state != .notSent { Text(state.title).font(DesignTokens.Typography.supporting) }
                            else if eligible && favorite.profile != nil {
                                CustomerRequestSendButton(title: "Send Request",
                                    confirmation: flow?.publicationConfirmation(names: [favorite.profile!.displayName])) {
                                    Task { await send(favorite.id) }
                                }
                                    .buttonStyle(BeckonPrimaryButtonStyle(accent: .customer))
                                    .disabled(marketplace.distribution.isPublishing
                                        || marketplace.publication.pending != nil && marketplace.publication.pending?.acknowledgement == nil
                                        || requestID.map { marketplace.distribution.mutatingIDs.contains($0) } == true)
                                    .accessibilityIdentifier("favorites.send.\(favorite.id.uuidString)")
                            } else { Text("Unavailable for this request").font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textSecondary) }
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
            if marketplace.favorites.isLoading { ProgressView() }
            if marketplace.favorites.nextCursor != nil {
                Button("Load More", systemImage: "arrow.down") { Task { await marketplace.favorites.loadMore() } }
                    .accessibilityIdentifier("favorites.load-more")
            }
            if let error = marketplace.distribution.error { Text(error.message).foregroundStyle(DesignTokens.Colors.errorText) }
        }
        .listStyle(.plain)
        .navigationTitle("Saved Groomers")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: effectiveScope) { await load() }
        .task { if onSend == nil { await refreshRequests() } }
        .refreshable {
            await load()
            if onSend == nil { await refreshRequests() }
        }
        .accessibilityIdentifier("customer.favorites")
    }

    private var effectiveScope: GroomerDiscoveryScope? { flow?.store.actionScope ?? scope }
    private var requestID: UUID? { if case let .request(id, _) = effectiveScope { id } else { nil } }
    private func choose(_ value: GroomerDiscoveryScope?) { scope = value }
    private func refreshRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }
        requestError = await marketplace.refreshRequestOptions?()
    }
    private func load() async {
        await marketplace.favorites.load(scope: effectiveScope)
        if let requestID { await marketplace.distribution.refresh(requestIDs: [requestID]) }
    }
    private func send(_ id: UUID) async {
        if let onSend { await onSend(id) }
        else if case let .request(requestID, revision) = scope {
            _ = await marketplace.distribution.invite(requestID: requestID, termsRevision: revision, groomerIDs: [id])
        }
    }
}
