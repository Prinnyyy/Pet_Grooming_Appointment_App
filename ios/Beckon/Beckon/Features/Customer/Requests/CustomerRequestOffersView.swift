import SwiftUI

// offers in the Home style: each quote is a ledge card led by the price, with fit evidence and a clear next step.
// Same data, sort, refresh and destinations as Features/Customer/Requests/CustomerOffersView.swift.
struct CustomerRequestOffersView: View {
    let requestID: UUID
    let store: CustomerRequestsStore

    var body: some View {
        if let request = store.request(withID: requestID) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(request, now: context.date)
            }
            .navigationTitle("Offers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: Binding(get: { store.offerSort }, set: { mode in
                            Task { await store.changeOfferSort(to: mode, for: request) }
                        })) {
                            ForEach(CustomerOfferSort.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                    .accessibilityIdentifier("customer.offers.sort")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await store.loadOffers(for: request) } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isLoadingOffers(for: request))
                    .accessibilityIdentifier("customer.offers.refresh")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("customer.offers.list")
            .task(id: request.id) { await store.loadOffers(for: request) }
        } else {
            DesignPage(rhythm: .list, cascades: false) { BeckonLedgeNote(systemImage: "doc.text.magnifyingglass", text: "This request isn't available. Refresh and try again.") }
        }
    }

    private func content(_ request: CustomerGroomingRequest, now: Date) -> some View {
        let offers = store.offers(for: request)
        let pending = offers.filter { $0.isCurrentProposal(now: now) }
        let history = offers.filter { !$0.isCurrentProposal(now: now) }
        // Beats: the banner leads, then the cards of each group one after another (at most four a group).
        let historyOrder = 1 + min(pending.count, 4)
        return DesignPage(rhythm: .list, cascades: false) {
            if store.rankedOfferPages[request.id]?.effectiveMode == "time_fallback" {
                BeckonLedgeNote(systemImage: "clock", text: "Recommendation unavailable. Showing earliest appointments.")
            }
            if store.isLoadingOffers(for: request), offers.isEmpty {
                BeckonLoadingView(title: "Loading offers…", message: "Checking for groomer responses.", accent: .customer)
                    .accessibilityIdentifier("customer.offers.loading")
            } else if offers.isEmpty, let message = store.offerError(for: request) {
                BeckonErrorBanner(title: "We could not load offers", message: message)
                    .accessibilityIdentifier("customer.offers.error")
            } else if offers.isEmpty {
                BeckonLedgeNote(systemImage: "tag", text: "No offers yet. Matched groomers can reply while this request is open.")
                    .accessibilityIdentifier("customer.offers.empty")
            } else {
                header(request, pending: pending.count)
                    .beckonEntrance(0)
                if pending.isEmpty {
                    BeckonLedgeNote(systemImage: "clock", text: "There are no pending offers for this request.")
                } else {
                    section("Pending offers", systemImage: "tag.fill", offers: pending, request: request, now: now,
                        isHistorical: false, order: 1, highlights: CustomerOfferHighlights(pending,
                            isComplete: store.loadedCurrentOfferCount(for: request, now: now) != nil))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("customer.offers.pending-list")
                }
                if !history.isEmpty {
                    section("Offer history", systemImage: "clock.arrow.circlepath", offers: history, request: request,
                        now: now, isHistorical: true, order: historyOrder)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("customer.offers.history-list")
                }
                if let message = store.offerError(for: request) {
                    BeckonErrorBanner(title: "More offers unavailable", message: message)
                        .accessibilityIdentifier("customer.offers.load-more-error")
                }
                if store.canLoadMoreOffers(for: request) || store.isLoadingMoreOffers(for: request) {
                    Button { Task { await store.loadNextOffersPage(for: request) } } label: {
                        DesignQuietAction(title: store.isLoadingMoreOffers(for: request) ? "Loading…" : "Load more offers",
                            systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .disabled(store.isLoadingMoreOffers(for: request))
                    .accessibilityIdentifier("customer.offers.load-more")
                }
            }
        }
    }

    private func header(_ request: CustomerGroomingRequest, pending: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "tag.fill")
                .font(DesignTokens.Typography.Expressive.glyphLarge)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .frame(width: 52, height: 52)
                .background(DesignTokens.Colors.surface, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(pending == 0 ? "Offers for \(request.petSnapshot.name)"
                    : "\(pending) offer\(pending == 1 ? "" : "s") for \(request.petSnapshot.name)")
                    .font(DesignTokens.Typography.Expressive.title)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Compare price, time and fit, then pick the one you like.")
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .designBanner()
    }

    private func section(_ title: String, systemImage: String, offers: [CustomerOfferReview],
                         request: CustomerGroomingRequest, now: Date, isHistorical: Bool, order: Int,
                         highlights: CustomerOfferHighlights? = nil) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: title, systemImage: systemImage, count: offers.count)
            ForEach(Array(offers.enumerated()), id: \.element.id) { index, review in
                CustomerNavigationLink(route: .offer(requestID: request.id, offerID: review.id)) {
                    CustomerOfferDetailView(request: request, offerID: review.id, store: store)
                } label: {
                    CustomerOfferCard(review: review, now: now, isHistorical: isHistorical,
                        badge: highlights?.badge(for: review.id))
                }
                .buttonStyle(BeckonLedgeButtonStyle(.card))
                .beckonEntrance(order + min(index, 3))
                .accessibilityIdentifier(AppTestOpsAccessibility.identifier(
                    prefix: "customer.offers.row", serviceNotes: request.serviceNotes) ?? "customer.offers.row")
            }
        }
    }
}

/// What one offer is best at, when there are several to compare. Worked out from the offers themselves (the cheapest price, the
/// earliest start), never claimed by the app; nothing is marked when all offers are equal or there is only one.
enum CustomerOfferBadge {
    case lowestPrice, earliest

    var title: String { self == .lowestPrice ? "Lowest price" : "Earliest" }
    var systemImage: String { self == .lowestPrice ? "tag.fill" : "clock.fill" }
}

struct CustomerOfferHighlights {
    private let badges: [UUID: CustomerOfferBadge]

    init(_ reviews: [CustomerOfferReview], isComplete: Bool) {
        var result: [UUID: CustomerOfferBadge] = [:]
        if isComplete, reviews.count > 1 {
            let prices = reviews.map(\.offer.priceEstimate)
            if let low = prices.min(), let high = prices.max(), low < high {
                for review in reviews where review.offer.priceEstimate == low { result[review.id] = .lowestPrice }
            }
            let starts = reviews.compactMap { review in
                GroomingRequestDateFormatting.parsedDate(from: review.offer.proposedStart).map { (review.id, $0) }
            }
            if let first = starts.map(\.1).min(), let last = starts.map(\.1).max(), first < last {
                for (id, date) in starts where date == first && result[id] == nil { result[id] = .earliest }
            }
        }
        badges = result
    }

    func badge(for id: UUID) -> CustomerOfferBadge? { badges[id] }
}

/// The offers of a request in a row of cards you swipe through: one card fills the width, several leave the next one peeking, a
/// page indicator says where you are, and the height never grows with the number of offers. Accessibility text sizes stack the
/// cards instead. Tapping a card opens that offer.
struct CustomerOfferCarousel<Destination: View>: View {
    let reviews: [CustomerOfferReview]
    let now: Date
    let highlights: CustomerOfferHighlights
    @ViewBuilder let destination: (CustomerOfferReview) -> Destination
    @State private var visibleID: UUID?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var currentIndex: Int {
        visibleID.flatMap { id in reviews.firstIndex(where: { $0.id == id }) } ?? 0
    }

    var body: some View {
        if typeSize.isAccessibilitySize || reviews.count < 2 {
            VStack(spacing: DesignTokens.Spacing.lg) {
                ForEach(reviews) { review in card(review) }
            }
        } else {
            VStack(spacing: DesignTokens.Spacing.md) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        ForEach(reviews) { review in
                            card(review)
                                .containerRelativeFrame(.horizontal) { length, _ in length * 0.88 }
                                .id(review.id)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
                // Bleeds past the page inset so the next card can peek in from the screen edge.
                .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $visibleID)
                .beckonTracksScroll()
                DesignPageDots(count: reviews.count, current: currentIndex,
                    label: "Offer \(currentIndex + 1) of \(reviews.count)")
            }
        }
    }

    private func card(_ review: CustomerOfferReview) -> some View {
        NavigationLink {
            destination(review)
        } label: {
            CustomerOfferCard(review: review, now: now, badge: highlights.badge(for: review.id), isCompact: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .accessibilityIdentifier("customer.offers.row")
    }
}

/// One quote. Price leads because it is what people compare first.
struct CustomerOfferCard: View {
    let review: CustomerOfferReview
    let now: Date
    var isHistorical = false
    /// "Lowest price" / "Earliest", when several offers are being compared.
    var badge: CustomerOfferBadge?
    /// In a row of cards: no fit evidence, and the button sits at the bottom whatever the height of the card next to it.
    var isCompact = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if let badge { BeckonMetaChip(text: badge.title, systemImage: badge.systemImage) }
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
                : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))) {
                BeckonProfileAvatar(data: review.groomerAvatarPhotoData, tone: .groomer, size: 52,
                    cornerRadius: DesignTokens.CornerRadius.pill, placeholderSize: 20)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(review.groomerTitle)
                        .font(DesignTokens.Typography.Expressive.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(review.groomerLocationSummary)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                BeckonStatusChip(review.offer.statusPresentation(now: now))
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(review.offer.priceSummary)
                    .font(DesignTokens.Typography.Expressive.hero)
                    .foregroundStyle(isHistorical ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textPrimary)
                Label(review.proposedTimeSummary, systemImage: "calendar")
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .accessibilityLabel(review.proposedTimePresentation.accessibilityLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isCompact, let fit = review.fitEvidencePresentation {
                BeckonFitEvidenceBlock(scoreText: fit.scoreText, summary: fit.listSummary, reason: fit.reason,
                    isCompact: true)
            }

            if isCompact { Spacer(minLength: 0) }

            if !isHistorical {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Review offer")
                    Image(systemName: "chevron.right")
                }
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                .beckonLedge(.pill)
                .accessibilityHidden(true)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .multilineTextAlignment(.leading)
    }
}
