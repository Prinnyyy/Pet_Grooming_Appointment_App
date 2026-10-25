import SwiftUI

struct CustomerFavoriteGroomersView: View {
    let marketplace: CustomerMarketplaceSession
    let onSend: ((UUID) async -> Void)?
    let flow: CustomerRequestDiscoveryFlow?
    @State private var scope: GroomerDiscoveryScope?
    @State private var isLoadingRequests = false
    @State private var requestError: String?
    @State private var snackbar = SnackbarCenter()
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(marketplace: CustomerMarketplaceSession, scope: GroomerDiscoveryScope? = nil, flow: CustomerRequestDiscoveryFlow? = nil,
         onSend: ((UUID) async -> Void)? = nil) {
        self.marketplace = marketplace; self.onSend = onSend; self.flow = flow
        _scope = State(initialValue: scope)
    }

    var body: some View {
        DesignPage(rhythm: .list, cascades: false) {
            if onSend == nil, !isEmptyList, let request = activeRequest {
                requestBanner(request).beckonEntrance(0)
            } else if !favorites.isEmpty {
                summaryBanner.beckonEntrance(0)
            }
            if onSend == nil, !isEmptyList, sendableRequests.isEmpty, !isLoadingRequests { noRequestNote }
            if let requestError {
                BeckonErrorBanner(title: "Requests could not be loaded", message: requestError)
                retryButton("Retry requests") { await refreshRequests() }
            }
            if let error = marketplace.favorites.error {
                BeckonErrorBanner(title: "Favorites could not be loaded", message: error.message)
                retryButton("Retry") { await load() }
            } else if isEmptyList {
                DesignPupPeek {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("No saved groomers yet")
                            .font(DesignTokens.Typography.Expressive.title)
                        Text("Tap the heart on a groomer to keep them here.")
                            .font(DesignTokens.Typography.Expressive.supporting)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .designCardBody()
                }
            }
            ForEach(Array(favorites.enumerated()), id: \.element.id) { index, favorite in
                groomerCard(favorite)
                    .beckonEntrance(1 + min(index, 4))
                    .transition(.opacity)
            }
            if marketplace.favorites.isLoading { ProgressView() }
            if marketplace.favorites.nextCursor != nil {
                Button { Task { await marketplace.favorites.loadMore() } } label: {
                    DesignQuietAction(title: "Load more", systemImage: "arrow.down")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityIdentifier("favorites.load-more")
            }
            if let error = marketplace.distribution.error { BeckonInlineError(error.message) }
        }
        .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap,
            value: favorites.map(\.id))
        .snackbar(snackbar)
        .navigationTitle("Saved groomers")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: effectiveScope) { await load() }
        .task { if onSend == nil { await refreshRequests() } }
        .refreshable {
            await load()
            if onSend == nil { await refreshRequests() }
        }
        .accessibilityIdentifier("customer.favorites")
    }

    // MARK: Pieces

    private var favorites: [FavoriteGroomer] { marketplace.favorites.items }

    private var isEmptyList: Bool { marketplace.favorites.hasLoaded && favorites.isEmpty }

    /// Count and what the page can do for the person right now: the one thing the old page left them to guess.
    private var summaryBanner: some View {
        let count = "\(favorites.count)\(marketplace.favorites.nextCursor == nil ? "" : "+")"
        return HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "heart.fill")
                .font(DesignTokens.Typography.Expressive.glyph)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(width: DesignTokens.Metrics.ledgeRoundControl, height: DesignTokens.Metrics.ledgeRoundControl)
                .background(DesignTokens.Colors.surface, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(favorites.count == 1 && marketplace.favorites.nextCursor == nil ? "1 saved groomer" : "\(count) saved groomers")
                    .font(DesignTokens.Typography.Expressive.title)
                Text(bannerLine)
                    .font(DesignTokens.Typography.Expressive.supporting)
            }
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .designBanner()
        .accessibilityElement(children: .combine)
    }

    private var bannerLine: String {
        onSend == nil ? "Your favorites, in one place." : "Send your request to any of them."
    }

    /// Open requests the person can send to a saved groomer (the ones that still take offers).
    private var sendableRequests: [CustomerGroomingRequest] {
        marketplace.requestOptions().filter { $0.termsRevision != nil }
    }

    /// The request in play: the one being sent. The first open request is already picked, so nobody has to choose before they can
    /// act: every card below shows Send request right away. Null with no open request (a note says so instead).
    private var activeRequest: CustomerGroomingRequest? {
        requestID.flatMap { id in sendableRequests.first { $0.id == id } }
    }

    private func title(of request: CustomerGroomingRequest) -> String {
        "\(request.petSnapshot.name) · \(request.serviceType.title)"
    }

    /// Names the request the Send buttons below will send, once. With more than one open request a white "Change" button opens a
    /// menu to switch; with one there is nothing to change and the banner is just a statement.
    private func requestBanner(_ request: CustomerGroomingRequest) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))
        return layout {
            Image(systemName: "pawprint.fill")
                .font(DesignTokens.Typography.Expressive.glyph)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(width: DesignTokens.Metrics.ledgeRoundControl, height: DesignTokens.Metrics.ledgeRoundControl)
                .background(DesignTokens.Colors.surface, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Request to send")
                    .font(DesignTokens.Typography.Expressive.supporting)
                Text(request.petSnapshot.name)
                    .font(DesignTokens.Typography.Expressive.title)
                Text(request.serviceType.title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
            }
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if sendableRequests.count > 1 { changeMenu }
        }
        .designBanner()
    }

    private var changeMenu: some View {
        Menu {
            ForEach(sendableRequests) { request in
                if let revision = request.termsRevision {
                    Button {
                        choose(.request(id: request.id, termsRevision: revision))
                    } label: {
                        if requestID == request.id {
                            Label(title(of: request), systemImage: "checkmark")
                        } else {
                            Text(title(of: request))
                        }
                    }
                    .accessibilityIdentifier("favorites.request.\(request.id.uuidString)")
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("Change")
                Image(systemName: "chevron.up.chevron.down")
                    .font(DesignTokens.Typography.Expressive.label)
                    .accessibilityHidden(true)
            }
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgePressStyle(.primary))
        .disabled(isLoadingRequests)
        .accessibilityLabel("Change request")
        .accessibilityIdentifier("favorites.choose-request")
    }

    private var noRequestNote: some View {
        BeckonLedgeNote(systemImage: "list.bullet.rectangle",
            text: "You have no open request. Post one in Requests to invite these groomers.")
    }

    private func retryButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            DesignQuietAction(title: title, systemImage: "arrow.clockwise")
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
    }

    /// One groomer: who they are with the heart (remove) at the corner; when a request is chosen, a footer says where they stand
    /// for it (invited, or a Send button). Without a request there is no footer at all.
    private func groomerCard(_ favorite: FavoriteGroomer) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                if let profile = favorite.profile {
                    GroomerCandidateSummaryView(profile: profile, avatarData: marketplace.avatarData[favorite.id], compact: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .task(id: profile.avatarPath) { await marketplace.loadAvatar(profile) }
                } else {
                    DesignInfoLine(systemImage: "person.crop.circle.badge.xmark",
                        text: favorite.availability == .paused ? "Groomer temporarily unavailable" : "Groomer unavailable")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .task { marketplace.revokeAvatar(favorite.id) }
                }
                GroomerFavoriteButton(isFavorite: true) {
                    Task { await remove(favorite) }
                }
                .disabled(marketplace.favorites.mutatingIDs.contains(favorite.id))
                .accessibilityIdentifier("favorites.remove.\(favorite.id.uuidString)")
            }
            if effectiveScope != nil {
                BeckonGroupedDivider()
                requestStatus(for: favorite)
            }
        }
        .designCardBody()
        .transition(.opacity)
    }

    /// The card leaves the list at once (the heart is the only control it had), so the way back is a snackbar: "Removed from saved",
    /// the groomer's name, Undo while the bar runs. Undo saves the groomer again; if the list was reloaded in between, it reloads.
    /// The snackbar only appears when the removal went through (the store shows its own error otherwise).
    private func remove(_ favorite: FavoriteGroomer) async {
        await marketplace.favorites.setFavorite(favorite.id, enabled: false)
        guard marketplace.favorites.state(for: favorite.id)?.isFavorite == false else { return }
        snackbar.show(title: "Removed from saved", detail: favorite.profile?.displayName, systemImage: "heart.slash.fill") {
            await marketplace.favorites.setFavorite(favorite.id, enabled: true)
            if !marketplace.favorites.items.contains(where: { $0.id == favorite.id }) { await load() }
        }
    }

    @ViewBuilder
    private func requestStatus(for favorite: FavoriteGroomer) -> some View {
        let eligible = favorite.eligibility.map { ["estimated_fit", "assessment_required"].contains($0.state) } == true
        let state = marketplace.distribution.state(requestID: requestID, groomerID: favorite.id, seed: favorite.invitationState)
        if state != .notSent {
            BeckonMetaChip(text: state.title, systemImage: "checkmark.circle.fill")
        } else if eligible, let profile = favorite.profile {
            CustomerRequestSendButton(title: "Send request",
                confirmation: flow?.publicationConfirmation(names: [profile.displayName])) {
                Task { await send(favorite.id) }
            }
            .disabled(marketplace.distribution.isPublishing
                || marketplace.publication.pending != nil && marketplace.publication.pending?.acknowledgement == nil
                || requestID.map { marketplace.distribution.mutatingIDs.contains($0) } == true)
            .accessibilityIdentifier("favorites.send.\(favorite.id.uuidString)")
        } else {
            Text("Unavailable for this request")
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
    }

    /// The person's own pick wins (`scope` starts as the request a caller handed in), then the flow's request, then (on the
    /// standalone page only) the first open request, so the page opens ready to send instead of asking for a choice first.
    private var effectiveScope: GroomerDiscoveryScope? {
        if let inherited = scope ?? flow?.store.actionScope { return inherited }
        guard onSend == nil, flow == nil, let first = sendableRequests.first, let revision = first.termsRevision else { return nil }
        return .request(id: first.id, termsRevision: revision)
    }
    private var requestID: UUID? { if case let .request(id, _) = effectiveScope { id } else { nil } }
    private func choose(_ value: GroomerDiscoveryScope) { scope = value }
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
        else if case let .request(requestID, revision) = effectiveScope {
            _ = await marketplace.distribution.invite(requestID: requestID, termsRevision: revision, groomerIDs: [id])
        }
    }
}
