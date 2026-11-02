// The groomer's Requests tab, redesigned in the customer prototype's language with the groomer's coral (design) and then from the
// flow it serves (design). Same job as Features/Groomer/Requests/GroomerRequestsView.swift: the requests that match the groomer's
// services, sorted by fit, distance or newest (Matches), and the offers the groomer has made (Offers). The stores, the sort
// preference, the pull to refresh, the route that notifications use and the accessibility identifiers are the real ones.
// What the flow asks of the page: a request is answered once, and then it is an offer, so Matches holds what is still to answer
// and Offers what was answered, in the order the groomer works through it (to replace, waiting, booked, earlier). One row
// (`GroomerRequestRow`) serves both lists, built from the stage the request page shows, with a chip only for what is out
// of the ordinary.
import Combine
import SwiftUI


struct GroomerRequestsView: View {
    @Binding var route: GroomerRequestsRoute
    @State var requests: GroomerRequestsStore
    @State var offers: GroomerOffersStore
    /// The Schedule's page of a booking, for a request whose offer was accepted.
    var onOpenBooking: ((Booking) -> Void)?
    var sessionIsCurrent: @MainActor () -> Bool = { true }
    @State private var matchesSettled = false
    @State private var offersSettled = false
    @State private var focusedTarget: GroomerRequestTarget?
    @State private var showsEarlier = false
    /// The last try to load more matches (or offers) failed. The page keeps this from what its own call returned: the store's one
    /// `errorMessage` is also set by an offer that did not go through, and used to show here under the wrong title (design).
    @State private var moreRequestsFailed = false
    @State private var moreOffersFailed = false
    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                    titleRow.beckonEntrance(0)
                    segments.beckonEntrance(1)
                    content.beckonEntrance(2)
                }
                .beckonPageInsets()
                .beckonEntranceClock()
            }
            .scrollContentBackground(.hidden)
            .beckonTracksScroll()
            .refreshable { await refreshAll() }
            .accessibilityIdentifier("groomer.requests.list")


        }
        .toolbar(.hidden, for: .navigationBar)
        .background {
            GroomerRequestsStatusView(store: requests)
        }
        .foregroundRefreshable {
            requests.setSessionValidation(sessionIsCurrent)
            await refreshAll()
        }
        .onChange(of: sessionIsCurrent()) { _, current in
            if !current { requests.invalidateSession() }
        }
        .onReceive(tick) { now = $0 }
        .onChange(of: route) { _, _ in applyRouteIfAvailable() }
        .onChange(of: route.segment) { _, segment in
            guard segment == .offers else { return }
            Task {
                await offers.load()
                applyRouteIfAvailable()
            }
        }
        .beckonResetsNavigation { focusedTarget = nil }
        .navigationDestination(item: $focusedTarget) { target in
            GroomerRequestDetailView(target: target, requests: requests, offers: offers, onOpenBooking: onOpenBooking)
        }
    }

    // MARK: Header

    private var titleRow: some View {
        BeckonPageTitle("Requests")
    }

    /// How the matches are ordered, where the list starts, as a word the groomer can read and change (a round button said neither).
    private var sortRow: some View {
        Menu {
            Picker("Sort", selection: Binding(get: { requests.sort }, set: { mode in
                Task { await requests.changeSort(to: mode) }
            })) {
                ForEach(GroomerMatchSort.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("Sorted by")
                    .font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                Text(requests.sort.title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                Image(systemName: "chevron.up.chevron.down")
                    .font(DesignTokens.Typography.Expressive.micro)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Sort")
        .accessibilityValue(requests.sort.title)
        .accessibilityIdentifier("groomer.requests.sort")
    }

    private var segments: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(GroomerRequestsSegment.allCases) { segment in
                segmentChip(segment)
            }
        }
    }

    /// The chosen segment is the coral pill, the other a white card; a count rides in each once its list has loaded.
    private func segmentChip(_ segment: GroomerRequestsSegment) -> some View {
        let isSelected = route.segment == segment
        let count = segment == .matches ? matchCount : offerCount
        return Button {
            route = segment == .matches ? .matches : .offers
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(segment.title).font(DesignTokens.Typography.Expressive.emphasis)
                if let count {
                    Text("\(count)")
                        .font(DesignTokens.Typography.Expressive.label)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .frame(minWidth: 24, minHeight: 24)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .background(isSelected ? DesignTokens.Colors.surface : DesignTokens.Colors.customerTint, in: Capsule())
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
        .accessibilityIdentifier(segment.accessibilityIdentifier)
        .accessibilityValue(count.map { "\($0)" } ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var matchCount: Int? {
        requests.hasLoadedOnce ? toAnswer.count : nil
    }

    /// The matches still waiting for an answer. Once the groomer has made an offer the request is an offer and lives in Offers
    /// (the store keeps it as a match, which is how a notification still finds it).
    private var toAnswer: [GroomerMatchedRequest] {
        requests.matchedRequests.filter {
            GroomerRequestStage(GroomerRequestSubject(matched: $0, item: nil, history: []), now: now).kind == .new
        }
    }

    private var offerCount: Int? {
        offers.hasLoadedOnce ? offers.offers.count : nil
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch route.segment {
        case .matches: matchesContent
        case .offers: offersContent
        }
    }

    private var matchesContent: some View {
        DesignReveal(isLoading: !matchesSettled && !requests.hasLoadedOnce) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                notes
                if toAnswer.isEmpty {
                    if let message = requests.loadErrorMessage {
                        BeckonErrorBanner(title: "Requests unavailable", message: message) {
                            Button { Task { await requests.load() } } label: {
                                DesignQuietAction(title: "Try again", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(BeckonGuardedPlainButtonStyle())
                            .disabled(requests.isBusy)
                        }
                        .accessibilityIdentifier("groomer.requests.error")
                    } else if (requests.rankedPage?.pendingCount ?? 0) > 0 {
                        BeckonLedgeNote(systemImage: "hourglass", text: "Availability checks pending.")
                    } else if !requests.matchedRequests.isEmpty {
                        emptyCard(title: "Nothing to answer",
                            message: "New requests that match your services will appear here. The ones you made an offer on are in Offers.")
                            .accessibilityIdentifier("groomer.requests.empty")
                    } else {
                        emptyCard(title: "No matched requests",
                            message: "New active customer requests will appear here when they match your profile and services.")
                            .accessibilityIdentifier("groomer.requests.empty")
                    }
                } else {
                    if toAnswer.count > 1 { sortRow }
                    ForEach(toAnswer) { matched in
                        GroomerRequestRow(content: .match(matched, photo: photo(for: matched), now: now),
                            onOpen: { focusedTarget = .match(matched.id) })
                            .accessibilityIdentifier(AppTestOpsAccessibility.identifier(prefix: "groomer.requests.row",
                                serviceNotes: matched.request.serviceNotes) ?? "groomer.requests.row")
                            .accessibilityValue(AppTestOpsAccessibility.requestReference(matched.request.id))
                    }
                    if requests.canLoadMore || requests.isLoadingMore {
                        BeckonLoadMoreButton(isLoading: requests.isLoadingMore, accent: .groomer,
                            accessibilityIdentifier: "groomer.requests.load-more", failed: moreRequestsFailed) {
                            moreRequestsFailed = false
                            await requests.loadNextPage()
                            moreRequestsFailed = requests.loadMoreErrorMessage != nil
                        }
                    }
                }
            }
        } placeholder: {
            VStack(spacing: DesignTokens.Spacing.md) {
                GroomerRequestRowSkeleton()
                GroomerRequestRowSkeleton()
                GroomerRequestRowSkeleton()
            }
            .accessibilityIdentifier("groomer.requests.loading")
        }
    }

    /// The few lines of context the list can carry above its rows, each one a quiet line.
    @ViewBuilder
    private var notes: some View {
        if requests.rankedPage?.effectiveMode == "time_fallback" {
            DesignInfoLine(systemImage: "clock", text: "Experience ranking unavailable. Showing newest requests.")
        }
        if let count = requests.rankedPage?.pendingCount, count > 0, !requests.matchedRequests.isEmpty {
            DesignInfoLine(systemImage: "hourglass", text: "\(count) requests awaiting availability checks")
        }
        if requests.listNeedsRefresh {
            DesignInfoLine(systemImage: "arrow.clockwise", text: "Matches changed. Pull down to refresh.")
        }
    }

    private var offersContent: some View {
        DesignReveal(isLoading: !offersSettled && !offers.hasLoadedOnce) {
            let groups = GroomerOfferGroups(offers.offers, now: now)
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                if offers.offers.isEmpty {
                    if let message = offers.loadErrorMessage {
                        BeckonErrorBanner(title: "Offers unavailable", message: message) {
                            Button { Task { await offers.load() } } label: {
                                DesignQuietAction(title: "Try again", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(BeckonGuardedPlainButtonStyle())
                            .disabled(offers.isLoading)
                        }
                        .accessibilityIdentifier("groomer.offers.error")
                    } else {
                        emptyCard(title: "No offers yet",
                            message: "Offers you submit from matched requests will appear here with their latest customer status.")
                            .accessibilityIdentifier("groomer.offers.empty")
                    }
                } else {
                    offerSection("Needs attention", systemImage: "exclamationmark.triangle.fill", groups.attention)
                    offerSection("Pending", systemImage: "hourglass", groups.pending)
                    offerSection("Booked", systemImage: "checkmark.seal.fill", groups.booked)
                    earlierSection(groups.earlier)
                    if offers.canLoadMore || offers.isLoadingMore {
                        BeckonLoadMoreButton(isLoading: offers.isLoadingMore, accent: .groomer,
                            accessibilityIdentifier: "groomer.offers.load-more", failed: moreOffersFailed) {
                            moreOffersFailed = false
                            await offers.loadNextPage()
                            moreOffersFailed = offers.loadMoreErrorMessage != nil
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("groomer.offers.list")
        } placeholder: {
            VStack(spacing: DesignTokens.Spacing.md) {
                GroomerRequestRowSkeleton(label: "Loading offers")
                GroomerRequestRowSkeleton(label: "Loading offers")
            }
            .accessibilityIdentifier("groomer.offers.loading")
        }
    }

    /// A stage of the offers: its heading says where they stand, so a row repeats nothing of it.
    @ViewBuilder
    private func offerSection(_ title: String, systemImage: String, _ entries: [GroomerOfferGroups.Entry]) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                BeckonLedgeHeading(title: title, systemImage: systemImage, count: entries.count)
                offerRows(entries)
            }
        }
    }

    /// What is over (declined, withdrawn, expired, closed): behind its heading until the groomer asks.
    @ViewBuilder
    private func earlierSection(_ entries: [GroomerOfferGroups.Entry]) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                Button {
                    withAnimation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap) { showsEarlier.toggle() }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        BeckonLedgeHeading(title: "Earlier", systemImage: "clock.arrow.circlepath", count: entries.count)
                        Spacer(minLength: DesignTokens.Spacing.sm)
                        Image(systemName: "chevron.down")
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .rotationEffect(.degrees(showsEarlier ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityValue(showsEarlier ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("groomer.offers.earlier.toggle")
                if showsEarlier { offerRows(entries) }
            }
        }
    }

    private func offerRows(_ entries: [GroomerOfferGroups.Entry]) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(entries) { entry in
                GroomerRequestRow(content: .offer(entry, now: now), onOpen: { focusedTarget = .offer(entry.id) })
                    .accessibilityIdentifier("groomer.offers.row")
            }
        }
    }

    /// An empty list is a plain card that says what will be here (no mascot: it stays where it was asked for).
    private func emptyCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.Expressive.title)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Text(message).designSupportingText()
        }
        .designCardBody()
    }

    private func photo(for matched: GroomerMatchedRequest) -> Data? {
        requests.requestPhotos(for: matched).first.flatMap { requests.requestPhotoData(for: $0) }
    }

    // MARK: Loading

    private func refreshAll() async {
        moreRequestsFailed = false
        moreOffersFailed = false
        await requests.load()
        if !Task.isCancelled && sessionIsCurrent() { matchesSettled = true }
        await offers.load()
        if !Task.isCancelled && sessionIsCurrent() { offersSettled = true }
        applyRouteIfAvailable()
    }

    private func applyRouteIfAvailable() {
        if let requestID = route.requestID,
           let matched = requests.matchedRequests.first(where: { $0.request.id == requestID }) {
            focusedTarget = .match(matched.id)
            route = .matches
        }
        if let offerID = route.offerID, offers.offers.contains(where: { $0.id == offerID }) {
            focusedTarget = .offer(offerID)
            route = .offers
        }
    }
}


// MARK: Messages

/// Sends what the store says (a notice, an error, a running action) to the global feedback layer, as the real page does.
struct GroomerRequestsStatusView: View {
    let store: GroomerRequestsStore

    var body: some View {
        BeckonGlobalFeedbackForwarder(
            noticeMessage: store.noticeMessage,
            clearNotice: { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            },
            error: errorPrompt,
            progress: progressPrompt
        )
    }

    private var errorPrompt: BeckonGlobalFeedbackError? {
        guard let errorMessage = store.actionErrorMessage else { return nil }
        return BeckonGlobalFeedbackError(scope: .page("groomer.requests"), sourceKey: "groomer.requests.error",
            title: "Request update failed", message: errorMessage)
    }

    private var progressPrompt: BeckonGlobalFeedbackProgress? {
        if store.isDismissing {
            return BeckonGlobalFeedbackProgress(scope: .operation("groomer.requests.dismiss"),
                sourceKey: "groomer.requests.dismiss-progress", title: "Dismissing…", tone: .groomer)
        }
        if store.isSubmittingOffer {
            return BeckonGlobalFeedbackProgress(scope: .operation("groomer.requests.offer"),
                sourceKey: "groomer.requests.offer-progress", title: "Submitting offer…", tone: .groomer)
        }
        if store.isWithdrawingOffer {
            return BeckonGlobalFeedbackProgress(scope: .operation("groomer.requests.withdraw"),
                sourceKey: "groomer.requests.withdraw-progress", title: "Withdrawing offer…", tone: .groomer)
        }
        return nil
    }
}

#if DEBUG
extension GroomerRequestsView {
    init(groomerID: UUID, repository: any GroomerRequestRepository,
         profileRepository: (any GroomerProfileRepository)? = nil, route: Binding<GroomerRequestsRoute>,
         debugRecorder: AppDebugEventRecorder? = nil, sessionIsCurrent: @escaping @MainActor () -> Bool = { true }) {
        self.init(route: route,
            requests: GroomerRequestsStore(groomerID: groomerID, repository: repository,
                profileRepository: profileRepository, debugRecorder: debugRecorder),
            offers: GroomerOffersStore(groomerID: groomerID, repository: repository),
            sessionIsCurrent: sessionIsCurrent)
    }
}
#endif
