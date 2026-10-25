// Redesigned "Choose groomers" (sandbox design S-009, plan A). Same stores and sends as Features/Customer/Discovery/CustomerGroomerDiscoveryView.swift;
// one list with sort and saved chips, a tick per groomer, and a single send bar. No deck, no per-card send, no separate list page.
import SwiftUI

struct CustomerGroomerDiscoveryView: View {
    @Bindable var flow: CustomerRequestDiscoveryFlow
    let requests: CustomerRequestsStore
    let marketplace: CustomerMarketplaceSession
    /// Inside the request wizard the wizard draws the progress header; on its own (a sheet, the sandbox) this page draws it.
    var embeddedInWizard = false
    /// What Back does before the request is sent; by default the page just dismisses.
    var onBack: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.showRequests) private var showRequests
    @State private var detail: DiscoveredGroomer?
    @State private var selection = GroomerSelection()
    @State private var savedOnly = false
    @State private var showLimit = false
    @State private var withdrawing: DiscoveredGroomer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let topAnchor = "discovery.top"

    private var isSent: Bool { flow.requestID != nil }
    /// Opened from a request that already exists (its card or its detail): not a step of creating one, so it has no step path.
    private var isManaging: Bool { isSent && !embeddedInWizard }

    /// Two faces of one page. Creating a request: the last step, so it looks like the steps before it (the same progress
    /// header, a title block, content, the one action bar), and after the send it keeps going as "Invite more groomers".
    /// Opened from an existing request: its own title and the request it is for, no step path, the same list and bar.
    var body: some View {
        VStack(spacing: 0) {
            if !embeddedInWizard && !isManaging { CustomerRequestWizardHeader(step: .groomers, isSent: isSent) }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                        titleBlock.id(Self.topAnchor).beckonEntrance(CustomerRequestStepMotion.titleOrder)

                        BeckonCascade(start: CustomerRequestStepMotion.contentStart, spacing: DesignTokens.Layout.sectionSpacing) {
                            notice
                            spotsNote
                            if isSent {
                                requestPoolCard
                            } else {
                                GroomerPoolCard(isOn: $flow.poolEnabled, isLocked: marketplace.publication.pending != nil)
                            }
                            content
                        }
                    }
                    .beckonPageInsets(bottom: DesignTokens.Layout.sectionSpacing)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .beckonTracksScroll()

                .onChange(of: isSent) { _, _ in animate { proxy.scrollTo(Self.topAnchor, anchor: .top) } }
            }
        }
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        .standsAloneInStepFamily(!embeddedInWizard)
        .groomerLimitDialog(isPresented: $showLimit, isNewRequest: flow.requestID == nil,
            poolEnabled: flow.requestID == nil ? $flow.poolEnabled : nil)
        .designAlertDialog(item: $withdrawing) { groomer in
            .destructive(title: "Withdraw this invitation?",
                message: "\(groomer.profile.displayName) won't be asked to send an offer, and you can't invite them again for this request. The spot opens up for someone else.",
                systemImage: "person.fill.xmark", keepTitle: "Keep it",
                confirmTitle: "Withdraw invitation to \(groomer.profile.displayName)", confirmSystemImage: "person.fill.xmark") {
                withdraw(groomer)
            }
        }
        .onChange(of: invitationCapacity, initial: true) { _, capacity in
            selection.limit = capacity.selectionLimit
        }
        .toolbar(.hidden, for: .navigationBar)
        // This page lives in a sheet. Scrolling must never turn into dragging the sheet away: the content scrolls first, and a
        // creation in progress (ticked groomers, a send running) cannot be swiped away by accident; Back and Done are in the bar.
        .presentationContentInteraction(.scrolls)
        .interactiveDismissDisabled(isBusy || (!isSent && !selection.isEmpty))
        .sheet(item: $detail) { candidate in
            NavigationStack {
                CustomerGroomerDetailView(candidate: candidate, flow: flow, requests: requests,
                    marketplace: marketplace, selection: $selection)
            }
        }
        .onChange(of: flow.requestID) { _, _ in selection.removeAll() }
        .task {
            if let id = flow.requestID, marketplace.distribution.progressByRequestID[id] == nil {
                await requests.refreshDistributionProgress(requestIDs: [id])
            }
            if let id = flow.requestID, let request = requests.request(withID: id) {
                await requests.loadOffers(for: request)
            }
            if flow.store.page == nil { await load() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("customer.discovery")
    }

    // MARK: Header

    private var titleBlock: some View {
        Group {
            if isManaging {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    CustomerRequestWizardTitleBlock(headline: "Invite more groomers",
                        subtitle: "Groomers you pick hear about this request right away.")
                    requestChips
                }
            } else if isSent {
                CustomerRequestWizardTitleBlock(headline: "Invite more groomers",
                    subtitle: "Your request is out. Add groomers while you wait for offers. You can come back to this any time from the request card.")
            } else {
                CustomerRequestWizardTitleBlock(step: .groomers)
            }
        }
        .accessibilityIdentifier("discovery.title")
    }

    /// Which request this is for, and until when it is open, so the sheet never floats free of the request it belongs to.
    private var requestChips: some View {
        let title = flow.requestID.flatMap { requests.request(withID: $0)?.displayTitle }
        let closes = flow.requestID.flatMap { marketplace.distribution.progressByRequestID[$0]?.expiresAt }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.Spacing.sm) { chips(title: title, closes: closes) }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) { chips(title: title, closes: closes) }
        }
    }

    @ViewBuilder
    private func chips(title: String?, closes: Date?) -> some View {
        if let title { BeckonMetaChip(text: title, systemImage: "doc.text.fill") }
        if let closes {
            BeckonMetaChip(text: "Closes \(closes.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
        }
    }

    /// A sent request: the same switch as on a new one, wired to the request itself (it used to live in the progress card).
    @ViewBuilder
    private var requestPoolCard: some View {
        if let id = flow.requestID {
            let distribution = marketplace.distribution
            let progress = distribution.progressByRequestID[id]
            let isOpen = progress.map { $0.status.isOpenForOffers && $0.expiresAt > Date() } ?? false
            GroomerPoolCard(
                isOn: Binding(get: { progress?.poolEnabled ?? false },
                    set: { enabled in Task { _ = await distribution.setPool(requestID: id, enabled: enabled) } }),
                isLocked: !isOpen || distribution.mutatingIDs.contains(id) || distribution.uncertainRequestIDs.contains(id),
                identifier: "discovery.pool")
        }
    }

    /// Above the list: how many fit and how many are picked, and when inviting more, who is using a spot.
    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summaryLine)
                .designSupportingText()
                .accessibilityIdentifier("discovery.summary")
            if let spotsLine {
                Text(spotsLine)
                    .designSupportingText()
                    .accessibilityIdentifier("discovery.spots")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The limit is not a headline: it only shows up as "room for 1 more" when it is about to matter.
    private var summaryLine: String {
        let store = flow.store
        let count = "\(store.candidates.count)\(store.canLoadMore ? "+" : "")"
        var parts = ["\(count) fit your request"]
        if !selection.isEmpty {
            parts.append("\(selection.count) selected" + (selection.remaining == 1 ? ", room for 1 more" : ""))
        }
        if store.pendingCount > 0 { parts.append("\(store.pendingCount) still being checked") }
        return parts.joined(separator: " · ")
    }

    /// Inviting more on an existing request: who is using a spot and how many are free, so a spot opening up is visible.
    private var spotsLine: String? {
        guard flow.requestID != nil, !flow.store.candidates.isEmpty else { return nil }
        let waiting = invitationCount(.awaitingResponse), offers = invitationCount(.offered)
        var parts: [String] = []
        if waiting > 0 { parts.append("\(waiting) waiting") }
        if offers > 0 { parts.append("\(offers) offer\(offers == 1 ? "" : "s") in") }
        if let free = invitationCapacity.remaining {
            parts.append("\(free) spot\(free == 1 ? "" : "s") available at last check")
        } else {
            parts.append("Available spots checked when you send")
        }
        return parts.joined(separator: " · ")
    }

    /// Shown only when nothing can be invited right now, so the dead end explains itself before the first tap.
    @ViewBuilder
    private var spotsNote: some View {
        if flow.requestID != nil, selection.limit == 0, !flow.store.candidates.isEmpty {
            BeckonLedgeNote(systemImage: "hourglass",
                text: "All \(GroomerSelection.invitationLimit) spots are in use. A spot opens when an invitation closes or an offer is no longer available.")
        }
    }

    /// One message at a time: the first problem that needs the customer's attention.
    @ViewBuilder
    private var notice: some View {
        if let error = flow.store.error {
            BeckonErrorBanner(title: "Groomers could not be loaded", message: error.message) {
                Button("Try again") { Task { await load() } }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer, isFullWidth: false))
                    .accessibilityIdentifier("discovery.refresh")
            }
        } else if let message = requests.errorMessage {
            BeckonErrorBanner(title: "Publication recovery", message: message)
        } else if let error = marketplace.distribution.error {
            if let id = flow.requestID, marketplace.distribution.uncertainRequestIDs.contains(id) {
                BeckonErrorBanner(title: "Request update", message: error.message) {
                    Button("Retry update") { Task { _ = await marketplace.distribution.retry(requestID: id) } }
                        .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer, isFullWidth: false))
                        .accessibilityIdentifier("discovery.retry-update")
                }
            } else {
                BeckonErrorBanner(title: "Request update", message: error.message)
            }
        } else if let error = marketplace.favorites.error {
            BeckonErrorBanner(title: "Favorites update", message: error.message)
        } else if let pending = marketplace.publication.pending {
            BeckonLedgeNote(systemImage: "arrow.clockwise",
                text: pending.acknowledgement != nil ? "Your request is saved. Finish sending to continue."
                    : "Your request was not sent yet. Try sending it again.")
        }
    }

    // MARK: List

    @ViewBuilder
    private var content: some View {
        if flow.store.isLoading && flow.store.candidates.isEmpty {
            BeckonLoadingView(title: "Finding groomers…", message: "Checking who fits your request.", accent: .customer)
        } else if flow.store.candidates.isEmpty {
            if flow.store.error == nil { emptyState }
        } else {
            // Carries on after the title (0) and the pool card (1) that sit above it in the page's own cascade.
            BeckonCascade(start: CustomerRequestStepMotion.contentStart + 1, spacing: DesignTokens.Layout.sectionContentSpacing) {
                summary
                controls
                if visibleCandidates.isEmpty {
                    BeckonLedgeNote(systemImage: "heart",
                        text: "No saved groomers fit this request yet. Tap the heart on a groomer to keep them here.")
                }
                ForEach(visibleCandidates, id: \.id) { candidate in
                    row(candidate)
                }
                if flow.store.isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
                if flow.store.canLoadMore {
                    Button { Task { await loadMore() } } label: {
                        DesignQuietAction(title: "Show more groomers", systemImage: "arrow.down")
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .accessibilityIdentifier("discovery.load-more")
                }
                // Replaces pull to refresh: reloading re-ranks the list and starts it over from the top, so it is something to
                // ask for, not something a pull at the top edge should do while scrolling.
                Button { Task { await refresh() } } label: {
                    DesignQuietAction(title: "Refresh list", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(flow.store.isLoading)
                .accessibilityIdentifier("discovery.refresh-list")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        BeckonLedgeNote(systemImage: "person.crop.circle.badge.clock",
            text: flow.store.pendingCount > 0 ? "Checking availability. Some groomers are still being checked."
                : "No groomers available. No groomers currently meet this request.")
        if !isSent {
            Button { leave() } label: {
                DesignQuietAction(title: "Edit request", systemImage: "square.and.pencil")
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
        }
    }

    /// Order on the left, saved filter on the right; wraps under each other at large text sizes.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                sortChips
                Spacer(minLength: DesignTokens.Spacing.sm)
                savedChip
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                sortChips
                savedChip
            }
        }
        .disabled(flow.store.isLoading)
    }

    @ViewBuilder
    private var sortChips: some View {
        ForEach(GroomerDiscoverySort.allCases, id: \.self) { sort in
            DesignChoiceChip(title: sort.title, isSelected: flow.store.sort == sort) { changeSort(to: sort) }
                .accessibilityIdentifier("discovery.sort.\(sort.rawValue)")
        }
    }

    private var savedChip: some View {
        DesignChoiceChip(title: "Saved", systemImage: savedOnly ? "heart.fill" : "heart", isSelected: savedOnly) {
            animate { savedOnly.toggle() }
        }
        .accessibilityIdentifier("discovery.saved-filter")
    }

    private func row(_ candidate: DiscoveredGroomer) -> some View {
        let invitation = marketplace.distribution.state(requestID: flow.requestID, groomerID: candidate.id,
            seed: candidate.invitationState)
        return GroomerChoiceRow(candidate: candidate, avatarData: marketplace.avatarData[candidate.id],
            isFavorite: isFavorite(candidate), invitation: invitation,
            isSelected: selection.contains(candidate.id), canSelect: selection.canTick(candidate.id),
            replyBy: replyBy(for: candidate, state: invitation),
            onWithdraw: flow.requestID != nil && invitation == .awaitingResponse ? { withdrawing = candidate } : nil,
            isLocked: isSelectionLocked,
            onDetails: { detail = candidate },
            onFavorite: { Task { await marketplace.favorites.setFavorite(candidate.id, enabled: !isFavorite(candidate)) } },
            onToggle: { toggle(candidate) })
            .task(id: candidate.profile.avatarPath) { await marketplace.loadAvatar(candidate.profile) }
    }

    /// With every spot used, a tap explains the limit and offers a way forward instead of doing nothing.
    private func toggle(_ candidate: DiscoveredGroomer) {
        guard selection.canTick(candidate.id) else { showLimit = true; return }
        animate { selection.toggle(candidate.id, name: candidate.profile.displayName) }
    }

    private func withdraw(_ candidate: DiscoveredGroomer) {
        guard let id = flow.requestID else { return }
        Task { _ = await marketplace.distribution.withdraw(requestID: id, groomerID: candidate.id) }
    }

    private func replyBy(for candidate: DiscoveredGroomer, state: RequestInvitationState) -> Date? {
        guard state == .awaitingResponse, let id = flow.requestID,
              let invitation = marketplace.distribution.progressByRequestID[id]?.invitations.first(where: { $0.groomerID == candidate.id }),
              invitation.replyBy > Date() else { return nil }
        return invitation.replyBy
    }

    /// The springy swap, or a plain fade when Reduce Motion is on.
    private func animate(_ change: () -> Void) {
        withAnimation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap, change)
    }

    private var invitationCapacity: GroomerInvitationCapacity {
        let request = flow.requestID.flatMap { requests.request(withID: $0) }
        return GroomerInvitationCapacity(
            progress: flow.requestID.flatMap { marketplace.distribution.progressByRequestID[$0] },
            offers: request.map { requests.offers(for: $0) } ?? [],
            completeOffers: request.map { requests.loadedCurrentOfferCount(for: $0) != nil } ?? false)
    }

    private func invitationCount(_ state: RequestInvitationState) -> Int {
        guard let id = flow.requestID, let progress = marketplace.distribution.progressByRequestID[id] else { return 0 }
        return progress.invitations.filter {
            marketplace.distribution.state(requestID: id, groomerID: $0.groomerID, seed: $0.state) == state
        }.count
    }

    private var visibleCandidates: [DiscoveredGroomer] {
        savedOnly ? flow.store.candidates.filter(isFavorite) : flow.store.candidates
    }

    private func isFavorite(_ candidate: DiscoveredGroomer) -> Bool {
        (marketplace.favorites.state(for: candidate.id) ?? candidate.favoriteState).isFavorite
    }

    // MARK: Action bar

    private var isBusy: Bool {
        marketplace.distribution.isPublishing || requests.isSubmitting
            || flow.requestID.map { marketplace.distribution.mutatingIDs.contains($0) } == true
    }

    /// Ticking is frozen while a send is running or waiting to be retried.
    private var isSelectionLocked: Bool { isBusy || marketplace.publication.pending != nil }

    /// Back before the request is sent (to the wizard's review, or whatever opened this page); Done once it is out.
    private func leave() {
        if isSent {
            // The request is out: as the last step of the wizard, Done closes it and lands on Requests, on the new request's card.
            if embeddedInWizard { showRequests?(flow.requestID) }
            requests.cancelWizard()
            dismiss()
        }
        else if let onBack { onBack() }
        else { dismiss() }
    }

    /// The same bar as every earlier step: Back (Done after sending) on the left, the one primary action on the right.
    @ViewBuilder
    private var actionBar: some View {
        if let pending = marketplace.publication.pending {
            if pending.acknowledgement != nil {
                bar("Finish sending", image: "arrow.clockwise", enabled: !requests.isSubmitting, busy: requests.isSubmitting,
                    id: "discovery.finish-publication") { Task { await requests.publish() } }
            } else {
                bar("Try sending again", image: "arrow.clockwise", enabled: !marketplace.distribution.isPublishing,
                    busy: marketplace.distribution.isPublishing, id: "discovery.retry-publication") {
                    Task { await requests.sendDiscovery(flow, groomerIDs: pending.groomerIDs) }
                }
            }
        } else if !isSent {
            newRequestBar
        } else {
            bar(selection.isEmpty ? "Pick groomers" : "Invite \(selection.count) groomer\(selection.count == 1 ? "" : "s")",
                image: "paperplane.fill", enabled: !selection.isEmpty && !isBusy, busy: isBusy, id: "discovery.send") {
                send(selection.ids)
            }
        }
    }

    /// New request: the groomers picked, the open-to-all switch, or both; one Send, confirmed with who will get it.
    private var newRequestBar: some View {
        let hasGroomers = !selection.isEmpty
        let canSend = hasGroomers || flow.poolEnabled
        return bar(hasGroomers ? "Send to \(selection.count) groomer\(selection.count == 1 ? "" : "s")"
                : flow.poolEnabled ? "Send request" : "Pick a groomer",
            image: "paperplane.fill", enabled: canSend && !isBusy, busy: isBusy,
            confirmation: canSend ? flow.publicationConfirmation(names: selection.names) : nil,
            id: hasGroomers ? "discovery.send" : "discovery.publish-pool") {
            send(selection.ids)
        }
    }

    private func bar(_ title: String, image: String, enabled: Bool, busy: Bool, confirmation: String? = nil, id: String,
                     action: @escaping () -> Void) -> some View {
        DesignActionBar(leadingTitle: isSent ? "Done" : "Back", leadingImage: isSent ? "checkmark" : "chevron.left",
            primaryTitle: title, primaryImage: image, isPrimaryEnabled: enabled, isBusy: busy, confirmation: confirmation,
            leadingIdentifier: isSent ? "discovery.done" : "discovery.back", primaryIdentifier: id,
            bumpTrigger: CustomerRequestStep.groomers.rawValue, leading: leave, primary: action)
    }

    private func send(_ ids: [UUID]) {
        guard ids.count <= invitationCapacity.selectionLimit else { showLimit = true; return }
        Task {
            await requests.sendDiscovery(flow, groomerIDs: ids)
            // Invited groomers turn into status chips, so a clean send empties the selection (a failed one keeps it for the retry).
            if requests.errorMessage == nil, marketplace.distribution.error == nil, marketplace.publication.pending == nil {
                selection.removeAll()
            }
        }
    }

    // MARK: Loading

    private func changeSort(to sort: GroomerDiscoverySort) {
        guard sort != flow.store.sort else { return }
        Task {
            let epoch = marketplace.favorites.readEpoch
            await flow.store.changeSort(to: sort)
            mergeFavorites(since: epoch)
        }
    }

    private func loadMore() async {
        let epoch = marketplace.favorites.readEpoch
        await flow.store.loadNextPage()
        mergeFavorites(since: epoch)
    }

    private func refresh() async {
        await load()
        if let id = flow.requestID {
            await requests.refreshDistributionProgress(requestIDs: [id])
            if let request = requests.request(withID: id) { await requests.loadOffers(for: request) }
        }
    }

    private func load() async {
        let epoch = marketplace.favorites.readEpoch
        await flow.store.load()
        mergeFavorites(since: epoch)
        // A full, clean reload shows everyone who is still eligible; ticks for anyone else are dropped.
        if flow.store.error == nil, !flow.store.canLoadMore {
            selection.keep(Set(flow.store.candidates.map(\.id)))
        }
    }

    private func mergeFavorites(since epoch: UInt64) {
        marketplace.favorites.merge(Dictionary(uniqueKeysWithValues: flow.store.candidates.map { ($0.id, $0.favoriteState) }), since: epoch)
    }
}

/// One groomer's summary and actions, used by the profile sheet and the sandbox's candidate screen. Without `selection`
/// it keeps the original per-groomer "Send request" button; with it, the card ticks the groomer into the list's selection.
struct CustomerGroomerCandidateView: View {
    let candidate: DiscoveredGroomer
    @Bindable var flow: CustomerRequestDiscoveryFlow
    let requests: CustomerRequestsStore
    let marketplace: CustomerMarketplaceSession
    let compact: Bool
    let onDetails: () -> Void
    var selection: Binding<GroomerSelection>? = nil
    @State private var showLimit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            summary
            actions.fixedSize(horizontal: false, vertical: true)
        }
        .task(id: candidate.profile.avatarPath) { await marketplace.loadAvatar(candidate.profile) }
        .groomerLimitDialog(isPresented: $showLimit, isNewRequest: flow.requestID == nil,
            poolEnabled: flow.requestID == nil ? $flow.poolEnabled : nil)
    }

    private var summary: some View {
        Button(action: onDetails) {
            GroomerCandidateSummaryView(profile: candidate.profile, avatarData: marketplace.avatarData[candidate.id],
                candidate: candidate, compact: compact)
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .accessibilityIdentifier("discovery.profile.\(candidate.id.uuidString)")
    }

    private var isFavorite: Bool {
        (marketplace.favorites.state(for: candidate.id) ?? candidate.favoriteState).isFavorite
    }

    private var invitation: RequestInvitationState {
        marketplace.distribution.state(requestID: flow.requestID, groomerID: candidate.id, seed: candidate.invitationState)
    }

    private var isDisabled: Bool {
        marketplace.distribution.isPublishing || requests.isSubmitting
            || flow.requestID.map { marketplace.distribution.mutatingIDs.contains($0) } == true
            || marketplace.publication.pending != nil && marketplace.publication.pending?.acknowledgement == nil
    }

    private func toggleFavorite() {
        Task { await marketplace.favorites.setFavorite(candidate.id, enabled: !isFavorite) }
    }

    @ViewBuilder
    private var actions: some View {
        if let selection {
            GroomerSelectionActions(id: candidate.id, name: candidate.profile.displayName, isFavorite: isFavorite,
                invitation: invitation, isSelected: selection.wrappedValue.contains(candidate.id),
                canSelect: selection.wrappedValue.canTick(candidate.id), disabled: isDisabled,
                onFavorite: toggleFavorite,
                onToggle: {
                    guard selection.wrappedValue.canTick(candidate.id) else { showLimit = true; return }
                    withAnimation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap) {
                        selection.wrappedValue.toggle(candidate.id, name: candidate.profile.displayName)
                    }
                })
        } else {
            GroomerCandidateActionsView(id: candidate.id, isFavorite: isFavorite, invitation: invitation,
                disabled: isDisabled, onFavorite: toggleFavorite,
                onSend: { Task { await requests.sendDiscovery(flow, groomerIDs: [candidate.id]) } },
                publicationConfirmation: flow.publicationConfirmation(names: [candidate.profile.displayName]))
        }
    }
}

private extension View {
    /// The step family when the picker stands alone (a sheet from a request, the sandbox). As the sixth step of the wizard it takes
    /// the family and the direction the wizard sets, so all six steps are dealt by one rule.
    @ViewBuilder
    func standsAloneInStepFamily(_ standsAlone: Bool) -> some View {
        if standsAlone { beckonEntranceRhythm(.step) } else { self }
    }
}
