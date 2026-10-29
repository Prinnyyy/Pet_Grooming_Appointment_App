//
// Sending a request to saved groomers (S-063, made like iOS's own Select mode in S-064). Choosing a request on the strip puts the
// page in selection mode: the whole list slides right to make room for a circle on the left of each card, the hearts fold away to
// give the room back, a tap on a card ticks it (the circle fills with a tick and the card lights up in mint), and one "Send to 2
// groomers" rises from the bottom. Choosing the request again leaves the mode. Nothing grows or appears inside a card, so nothing
// can show outside it; every card moves together because that is what the mode is. A groomer already invited, or not a fit for the
// request, has a different circle (a pale mint plane, a grey dash) and says so on its card, and cannot be ticked. "Select all" is in the heading while the mode is on.
import SwiftUI


struct CustomerFavoriteGroomersView: View {
    let marketplace: CustomerMarketplaceSession
    let onSend: ((UUID) async -> Void)?
    let flow: CustomerRequestDiscoveryFlow?
    @State private var scope: GroomerDiscoveryScope?
    /// The requests were fetched at least once: until then the strip has nothing true to show (S-066).
    @State private var requestsLoaded = false
    /// The page has been dealt in and is a second old: from here on a card that leaves or comes back moves the list.
    @State private var entranceDone = false
    @State private var requestError: String?
    @State private var snackbar = SnackbarCenter()
    /// The groomers ticked for the chosen request; empty whenever the request changes.
    @State private var isSending = false
    @State private var showLimit = false
    @State private var selectedIDs: Set<UUID> = []
    /// The groomer whose profile is open (S-069).
    @State private var profileOf: FavoriteGroomer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    init(marketplace: CustomerMarketplaceSession, scope: GroomerDiscoveryScope? = nil, flow: CustomerRequestDiscoveryFlow? = nil,
         onSend: ((UUID) async -> Void)? = nil) {
        self.marketplace = marketplace; self.onSend = onSend; self.flow = flow
        _scope = State(initialValue: scope)
    }

    var body: some View {
        DesignPage(rhythm: .list, cascades: false) {
            if onSend == nil, !favorites.isEmpty {
                // Standalone page: the requests to pick from, then the groomers to send to. The page does not start until its
                // requests are known (`isReady`), so a person with a request never sees "New request" flash first.
                requestStrip.disabled(isSending).beckonEntrance(0)
                // Not "Saved groomers": that is the title of the page, a line above.
                BeckonLedgeHeading(title: "Your groomers", systemImage: "heart.fill",
                    count: marketplace.favorites.nextCursor == nil ? favorites.count : nil)
                    .beckonEntrance(1)
                    // The page puts 24 between its blocks; a heading belongs to what follows it, so it pulls its cards 12 closer.
                    .padding(.bottom, -DesignTokens.Spacing.md)
            } else if !favorites.isEmpty {
                summaryBanner.beckonEntrance(0)
            }
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
            // The page puts 24 between its blocks, but these cards are one list: 12 between them, as every other list of cards has.
            // (A card's lip is 5 more, so the gap you see is 17.)
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(Array(favorites.enumerated()), id: \.element.id) { index, favorite in
                    groomerCard(favorite, index: index)
                        .beckonEntrance(1 + min(index, 4))
                        .transition(.opacity)
                }
            }
            if !isReady || marketplace.favorites.isLoading { ProgressView().frame(maxWidth: .infinity) }
            if marketplace.favorites.nextCursor != nil {
                Button { Task { await marketplace.favorites.loadMore() } } label: {
                    DesignQuietAction(title: "Load more", systemImage: "arrow.down")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityIdentifier("favorites.load-more")
            }
            if let error = marketplace.distribution.error { BeckonInlineError(error.message) }
        }
        // The page waits, hidden, until its data is here and then deals its blocks in, exactly as it does when it opens with the data
        // already there (every visit after the first). Before this, the first visit played the page's blocks and the arrival of the
        // list at the same moment, and the list's own layout animation ran under them: the blocks seemed to stretch in from the left.
        .beckonEntranceActive(isReady)
        // A card leaving (the heart) or coming back (Undo) moves the list; the list arriving for the first time does not.
        .animation(entranceDone ? (reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap) : nil,
            value: favorites.map(\.id))
        .task(id: isReady) {
            guard isReady else { entranceDone = false; return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            entranceDone = true
        }
        .accessibilityIdentifier("customer.favorites")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let request = activeRequest, !selection.isEmpty { sendBar(request) }
        }
        .onChange(of: effectiveScope) { _, _ in selectedIDs = [] }
        .sheet(item: $profileOf) { favorite in profileSheet(favorite) }
        .snackbar(snackbar)
        .groomerLimitDialog(isPresented: $showLimit, isNewRequest: false, poolEnabled: nil)
        .navigationTitle("Saved groomers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // As in iOS's own Select mode: Select all is at the top right while the cards are being picked.
            ToolbarItem(placement: .topBarTrailing) {
                if isSelecting, selectableFavorites.count > 1 { selectAllButton }
            }
        }
        .task(id: effectiveScope) { await load() }
        .task { if onSend == nil { await refreshRequests() } }
        .refreshable {
            await load()
            if onSend == nil { await refreshRequests() }
        }
    }

    // MARK: Pieces

    private var favorites: [FavoriteGroomer] { marketplace.favorites.items }

    private var isEmptyList: Bool { marketplace.favorites.hasLoaded && favorites.isEmpty }

    /// The groomers are in (or the list failed, or is empty) and the requests are known. A visit after the first finds all of it
    /// already, so the page is ready on its first frame; the first visit waits for it.
    private var isReady: Bool {
        let groomersKnown = marketplace.favorites.hasLoaded || !favorites.isEmpty || marketplace.favorites.error != nil
        return groomersKnown && (onSend != nil || requestsLoaded || !sendableRequests.isEmpty)
    }

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

    /// The request in play: the one being sent, chosen on the strip. Null until one is chosen: the cards below are a plain list.
    private var activeRequest: CustomerGroomingRequest? {
        requestID.flatMap { id in sendableRequests.first { $0.id == id } }
    }

    /// One card per open request, the chosen one in mint, and the dashed New request card at the end (S-048). Tapping a card is the
    /// pick the "Change" menu used to make; New request goes to Requests and starts the wizard.
    private var requestStrip: some View {
        CustomerFavoriteRequestStrip(
            requests: sendableRequests,
            selectedID: activeRequest?.id,
            onSelect: { request in
                withAnimation(motion) {
                    if requestID == request.id { scope = nil }
                    else if let revision = request.termsRevision { choose(.request(id: request.id, termsRevision: revision)) }
                }
            },
            onNewRequest: { marketplace.createRequest?() }
        )
    }

    private func retryButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            DesignQuietAction(title: title, systemImage: "arrow.clockwise")
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
    }

    // MARK: A groomer

    private enum SendState: Equatable {
        /// No request chosen: the cards are a plain list.
        case browsing
        /// A request is chosen and this groomer can be sent it: the card can be ticked.
        case selectable
        /// Already invited to it (or answered, or it closed): what it says is the state's own title.
        case invited(String)
        case unavailable
    }

    private func sendState(for favorite: FavoriteGroomer) -> SendState {
        guard effectiveScope != nil else { return .browsing }
        guard marketplace.favorites.scope == effectiveScope, !marketplace.favorites.isLoading else { return .unavailable }
        let state = marketplace.distribution.state(requestID: requestID, groomerID: favorite.id, seed: favorite.invitationState)
        if state != .notSent { return .invited(state.title) }
        let eligible = favorite.eligibility.map { ["estimated_fit", "assessment_required"].contains($0.state) } == true
        return eligible && favorite.profile != nil ? .selectable : .unavailable
    }

    /// The groomers ticked that can still be sent the request, in the order of the list.
    private var selection: [FavoriteGroomer] {
        favorites.filter { selectedIDs.contains($0.id) && sendState(for: $0) == .selectable }
    }

    /// The list sliding into or out of the mode, and a ring turning into a tick.
    private var motion: Animation { reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap }

    /// A request is chosen: the cards are being picked from.
    private var isSelecting: Bool { effectiveScope != nil }

    private var selectionLimit: Int {
        GroomerInvitationCapacity(progress: requestID.flatMap { marketplace.distribution.progressByRequestID[$0] },
            offers: [], completeOffers: false).selectionLimit
    }

    private var selectableFavorites: [FavoriteGroomer] { favorites.filter { sendState(for: $0) == .selectable } }

    private var selectAllButton: some View {
        let maximum = min(selectionLimit, selectableFavorites.count)
        let all = maximum > 0 && selection.count == maximum
        return Button {
            withAnimation(motion) { selectedIDs = all ? [] : Set(selectableFavorites.prefix(maximum).map(\.id)) }
        } label: {
            Text(all ? "Deselect all" : selectableFavorites.count > maximum ? "Select up to \(maximum)" : "Select all")
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
        }
        .disabled(isSending)
        .accessibilityIdentifier("favorites.select-all")
        .disabled(maximum == 0)
    }

    /// Room for the circle: its width and the gap to the card.
    private static let circleColumn: CGFloat = 40
    /// The heart's circle: the smallest a thumb can hit, so the name beside it gets the room the 50-point one took (it also has to be
    /// at least `circleColumn`, because it is what absorbs the card's slide to the right in selection mode).
    private static let heartColumn: CGFloat = DesignTokens.Metrics.minimumTouchTarget

    private func toggle(_ id: UUID) {
        guard !isSending else { return }
        guard selectedIDs.contains(id) || selection.count < selectionLimit else { showLimit = true; return }
        withAnimation(motion) {
            if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
        }
    }

    /// One groomer. In selection mode a circle sits to the left of the card (the card is narrower by its width, and the heart, which
    /// has no place in the mode, folds away to give that room back, so the text hardly moves); ticked, the circle holds a tick and the
    /// card is mint with a deep-green border. The state of a card that cannot be ticked is a chip beside "Verified".
    private func groomerCard(_ favorite: FavoriteGroomer, index: Int) -> some View {
        let state = sendState(for: favorite)
        let isSelected = state == .selectable && selectedIDs.contains(favorite.id)
        // How far the card's left edge, and everything on it, has moved to the right to make room for the circle.
        let shift: CGFloat = isSelecting ? Self.circleColumn : 0
        return ZStack(alignment: .leading) {
            // The card is laid out the same in both modes (its text never re-wraps); the mode only moves things. The surface is
            // narrowed from the left, what is on it slides right by the same amount, the heart shrinks away in its own place, and the
            // circle grows in the room the surface leaves.
            card(favorite, state: state, isSelected: isSelected)
                .offset(x: shift)
                .background(alignment: .leading) { SelectableCardSurface(inset: shift, isSelected: isSelected) }
            selectionCircle(state, isSelected: isSelected)
                .frame(width: Self.circleColumn)
                .scaleEffect(isSelecting ? 1 : 0.4)
                .opacity(isSelecting ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { if state == .selectable { toggle(favorite.id) } }
                .allowsHitTesting(isSelecting)
                .accessibilityHidden(true)
        }
        .padding(.bottom, DesignTokens.Ledge.card)
        .transition(.opacity)
    }

    private func card(_ favorite: FavoriteGroomer, state: SendState, isSelected: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            cardSummary(favorite, state: state, isSelected: isSelected)
            rightColumn(favorite)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The column to the right of a card: the heart (let go of this groomer) and, under it, the quiet arrow that says the card opens.
    /// It keeps its width in both modes: in selection mode it is what the card's slide to the right moves out of sight.
    private func rightColumn(_ favorite: FavoriteGroomer) -> some View {
        VStack(spacing: 0) {
            heartButton(favorite)
                .frame(width: Self.heartColumn, height: Self.heartColumn, alignment: .trailing)
            Spacer(minLength: 0)
            if favorite.profile != nil { browseChevron }
        }
        .frame(width: Self.heartColumn)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func heartButton(_ favorite: FavoriteGroomer) -> some View {
        GroomerFavoriteButton(isFavorite: true, size: Self.heartColumn) {
            Task { await remove(favorite) }
        }
        .disabled(marketplace.favorites.mutatingIDs.contains(favorite.id))
        // The heart keeps its place and shrinks to nothing (a spring, with a little pop on the way back) instead of being pushed
        // aside, so the text beside it does not move for it.
        .scaleEffect(isSelecting ? 0.1 : 1)
        .opacity(isSelecting ? 0 : 1)
        .allowsHitTesting(!isSelecting)
        .accessibilityHidden(isSelecting)
        .accessibilityIdentifier("favorites.remove.\(favorite.id.uuidString)")
    }

    /// The quiet arrow at the foot of a card that says it opens: gone while the cards are being ticked.
    private var browseChevron: some View {
        Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.Expressive.label)
            .foregroundStyle(DesignTokens.Colors.textTertiary)
            .frame(width: Self.heartColumn, height: DesignTokens.Spacing.xl)
            .opacity(isSelecting ? 0 : 1)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func cardSummary(_ favorite: FavoriteGroomer, state: SendState, isSelected: Bool) -> some View {
        let dimmed: Bool = { if case .invited = state { true } else { state == .unavailable } }()
        let summary = Group {
            if let profile = favorite.profile {
                GroomerCandidateSummaryView(profile: profile, avatarData: marketplace.avatarData[favorite.id], compact: true,
                    status: statusBadge(state), onTint: isSelected)
                    .task(id: profile.avatarPath) { await marketplace.loadAvatar(profile) }
            } else {
                DesignInfoLine(systemImage: "person.crop.circle.badge.xmark",
                    text: favorite.availability == .paused ? "Groomer temporarily unavailable" : "Groomer unavailable")
                    .task { marketplace.revokeAvatar(favorite.id) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(dimmed ? 0.7 : 1)
        // One view in every state, never an `if` that wraps it in a Button only while it can be ticked: a different view in the tree
        // is a new view to SwiftUI, which fades it in where the old one fades out instead of moving it (the text vanished and came back
        // in its new place, S-065). Its tap and its accessibility are modifiers that only act while the card can be ticked.
        let canTick = state == .selectable
        let canOpen = favorite.profile != nil
        let hint = Self.cardHint(canTick: canTick, canOpen: canOpen)
        summary
            .contentShape(Rectangle())
            // Ticking a groomer wins while the card can be ticked; every other time the card opens the groomer's page. The photo
            // always opens it, so a groomer can be looked at while the cards are being ticked.
            .onTapGesture { if canTick { toggle(favorite.id) } else { openProfile(favorite) } }
            .overlay(alignment: .topLeading) {
                Color.clear.frame(width: 64, height: 64).contentShape(Rectangle())
                    .onTapGesture { openProfile(favorite) }
                    .allowsHitTesting(canOpen)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(canTick || canOpen ? .isButton : [])
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityValue(canTick ? (isSelected ? "Selected" : "Not selected") : "")
            .accessibilityHint(hint)
            .accessibilityAction { if canTick { toggle(favorite.id) } else { openProfile(favorite) } }
            .accessibilityAction(named: "Open profile") { openProfile(favorite) }
            .accessibilityIdentifier("favorites.card.\(favorite.id.uuidString)")
    }

    private static func cardHint(canTick: Bool, canOpen: Bool) -> String {
        if canTick { return "Adds or removes this groomer from the ones you send the request to." }
        return canOpen ? "Opens the groomer's profile." : ""
    }

    /// The circle to the left of a card, in the family of the app's own nodes: an empty ring in deep green (you can tick this), a mint
    /// disc with a tick (ticked), a pale mint disc with a deep-green paper plane (already sent: soft, because it is done and not
    /// waiting for you, and a plane because it was sent, not chosen) or a grey ring with a dash (not a fit). It is one circle in
    /// every state, whose fill, ring and glyph change under `Motion.morph`, so a tick turning into a plane when the request goes
    /// out is one shape changing, not one circle fading out and another in.
    private func selectionCircle(_ state: SendState, isSelected: Bool) -> some View {
        let look = Self.circleLook(state, isSelected: isSelected)
        return ZStack {
            Circle().fill(look.fill)
            Circle().strokeBorder(look.ring, lineWidth: 2.5)
            Image(systemName: look.glyph)
                .font(DesignTokens.Typography.Expressive.selectionGlyph) // glyph inside a fixed-size circle, fixed by design
                .foregroundStyle(look.ink)
                .contentTransition(.symbolEffect(.replace))
                .opacity(look.showsGlyph ? 1 : 0)
                .scaleEffect(look.showsGlyph ? 1 : 0.3)
        }
        .frame(width: 28, height: 28)
        .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.morph, value: look)
    }

    private struct CircleLook: Equatable {
        var fill: Color
        var ring: Color
        var ink: Color
        var glyph: String
        var showsGlyph: Bool
    }

    private static func circleLook(_ state: SendState, isSelected: Bool) -> CircleLook {
        typealias Colors = DesignTokens.Colors
        switch state {
        case .invited:
            return CircleLook(fill: Colors.customerTint, ring: Colors.customerFill, ink: Colors.customerDeep, glyph: "paperplane.fill",
                showsGlyph: true)
        case .unavailable:
            return CircleLook(fill: .clear, ring: Colors.border, ink: Colors.textTertiary, glyph: "minus", showsGlyph: true)
        case .selectable, .browsing:
            return CircleLook(fill: isSelected ? Colors.customerFill : Colors.surface, ring: Colors.customerDeep,
                ink: Colors.customerInk, glyph: "checkmark", showsGlyph: isSelected)
        }
    }

    // MARK: A groomer's page

    private func openProfile(_ favorite: FavoriteGroomer) {
        guard favorite.profile != nil else { return }
        profileOf = favorite
    }

    /// The profile of a saved groomer: the same page the request wizard opens, in a sheet. With a request chosen it starts with the
    /// groomer's place in it and ends in the same Select pill as the card (the ticks are the page's own, so a tick made here shows
    /// on the card behind); without one it is just the groomer. The heart lets go of the groomer, as on the card.
    @ViewBuilder
    private func profileSheet(_ favorite: FavoriteGroomer) -> some View {
        if let summary = favorite.profile {
            NavigationStack {
                CustomerGroomerProfilePage(groomerID: summary.id, marketplace: marketplace,
                    context: profileContext(favorite), isFavorite: true,
                    onFavorite: { profileOf = nil; Task { await remove(favorite) } }, onClose: { profileOf = nil }) {
                    profileBar(favorite)
                }
            }
            .designSheetStyle()
        }
    }

    /// How this groomer stands for the chosen request; nothing when no request is chosen.
    private func profileContext(_ favorite: FavoriteGroomer) -> GroomerProfileContext? {
        guard let request = activeRequest else { return nil }
        return GroomerProfileContext(petName: request.petSnapshot.name, eligibilityState: favorite.eligibility?.state,
            distanceMiles: nil, referencePrice: nil, evidence: nil)
    }

    @ViewBuilder
    private func profileBar(_ favorite: FavoriteGroomer) -> some View {
        let summary = activeRequest.map { "\($0.petSnapshot.name) · \($0.serviceType.title)" }
        switch sendState(for: favorite) {
        case .selectable:
            BeckonPinnedBar(summary: summary) {
                GroomerSelectionControl(name: favorite.profile?.displayName ?? "groomer",
                    isSelected: selectedIDs.contains(favorite.id), invitation: .notSent) { toggle(favorite.id) }
            }
        case .invited(let title):
            BeckonPinnedBar(summary: summary) {
                BeckonMetaChip(text: title == "Awaiting response" ? "Invited" : title, systemImage: "checkmark.circle.fill")
            }
        case .unavailable:
            BeckonPinnedBar(summary: summary) {
                BeckonMetaChip(text: "Not a fit for this request", systemImage: "minus.circle")
            }
        case .browsing:
            EmptyView()
        }
    }

    /// Short, because it shares a row with "Verified".
    private func statusBadge(_ state: SendState) -> (title: String, systemImage: String)? {
        switch state {
        case .invited(let title): (title == "Awaiting response" ? "Invited" : title, "checkmark.circle.fill")
        case .unavailable: ("Not a fit", "minus.circle")
        default: nil
        }
    }

    /// One button for every groomer ticked: what it sends is on the line above it, who it goes to is in the confirmation.
    private func sendBar(_ request: CustomerGroomingRequest) -> some View {
        let chosen = selection
        let names = chosen.compactMap { $0.profile?.displayName }
        return BeckonPinnedBar(summary: "\(request.petSnapshot.name) · \(request.serviceType.title)") {
            CustomerRequestSendButton(title: chosen.count == 1 ? "Send to 1 groomer" : "Send to \(chosen.count) groomers",
                confirmation: flow?.publicationConfirmation(names: names)) {
                Task { await sendSelected() }
            }
            .disabled(isSending || marketplace.distribution.isPublishing
                || marketplace.publication.pending != nil && marketplace.publication.pending?.acknowledgement == nil
                || requestID.map { marketplace.distribution.mutatingIDs.contains($0) } == true)
            .accessibilityIdentifier("favorites.send")
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

    /// The person's own pick wins (`scope` starts as the request a caller handed in), then the flow's request. The standalone page
    /// starts with none chosen: the groomers are a plain list until a request is picked, and a pick can be cleared (S-049).
    private var effectiveScope: GroomerDiscoveryScope? { scope ?? flow?.store.actionScope }
    private var requestID: UUID? { if case let .request(id, _) = effectiveScope { id } else { nil } }
    private func choose(_ value: GroomerDiscoveryScope) { scope = value }
    private func refreshRequests() async {
        defer { requestsLoaded = true }
        requestError = await marketplace.refreshRequestOptions?()
    }
    private func load() async {
        await marketplace.favorites.load(scope: effectiveScope)
        if let requestID { await marketplace.distribution.refresh(requestIDs: [requestID]) }
    }
    /// Sends the request to every groomer ticked. A flow that sends one at a time (`onSend`) is asked once for each; the page's own
    /// invitation goes out as one call. The ticks go once it is done, so the cards show "Invited".
    private func sendSelected() async {
        guard !isSending else { return }
        let ids = selection.map(\.id)
        let sendingScope = effectiveScope
        guard !ids.isEmpty, ids.count <= selectionLimit else { return }
        isSending = true
        defer { isSending = false }
        var sent = false
        if let onSend {
            for id in ids { await onSend(id) }
            sent = marketplace.distribution.error == nil && marketplace.publication.pending == nil
        } else if case let .request(requestID, revision) = sendingScope {
            sent = await marketplace.distribution.invite(requestID: requestID, termsRevision: revision, groomerIDs: ids)
        }
        if sent, sendingScope == effectiveScope { withAnimation(motion) { selectedIDs = [] } }
    }
}


/// The card's rounded rectangle with its left edge moved in by `inset`: what animates when the list slides into selection mode.
private struct LeadingInsetCard: Shape {
    var inset: CGFloat
    let radius: CGFloat

    var animatableData: CGFloat {
        get { inset }
        set { inset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .path(in: CGRect(x: rect.minX + inset, y: rect.minY, width: max(rect.width - inset, 0), height: rect.height))
    }
}


/// A ledge card (face, quiet edge, lip) whose left edge can move in, and that can light up. The ledge modifier cannot do it: it is as
/// wide as the thing it wraps. Ticked: mint face and a deep-green edge.
private struct SelectableCardSurface: View {
    let inset: CGFloat
    let isSelected: Bool

    var body: some View {
        let shape = LeadingInsetCard(inset: inset, radius: DesignTokens.CornerRadius.card)
        ZStack {
            shape.fill(DesignTokens.Colors.border)
                .offset(y: DesignTokens.Ledge.card)
            shape.fill(isSelected ? DesignTokens.Colors.customerTint : DesignTokens.Colors.surface)
            shape.stroke(DesignTokens.Colors.border, lineWidth: DesignTokens.Ledge.edgeWidth * 2).clipShape(shape)
            shape.stroke(DesignTokens.Colors.customerDeep, lineWidth: 6).clipShape(shape)
                .opacity(isSelected ? 1 : 0)
        }
    }
}


/// The Account-page entry with a chosen number of open requests (and optionally one of them chosen), so every state of the request
/// strip can be reviewed in Canvas. The sandbox host keeps one fixture request: its `createRequest` adds nothing once one exists,
/// so more than one is made here.
