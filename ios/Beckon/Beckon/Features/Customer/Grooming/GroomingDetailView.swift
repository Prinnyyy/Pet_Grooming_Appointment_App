// The detail page of a grooming (S-062): one page where there were two. The Request detail and the Booking detail each told half of
// the same story, so a request that got booked changed pages and lost what it was (its offers, its photos, its notes) while the
// booking never knew where it came from. Now a card's Details, a notification, a reminder, a chat and an accepted offer all open
// this page, and it follows the grooming from Posted to Reviewed: the hero is the card opened up (same path, same bubble); under it,
// first what needs the owner, then the one thing for this stage (the groomers to invite, the offers to compare, the review to
// leave), then the details (your request, which becomes the appointment), the quiet manage rows, and what happened.
// Every function of both old pages is here. Stores and fixtures stay shared.
import Combine
import SwiftUI


/// What the page is about: a request that has not become a booking, or a booking (which knows its request).
enum GroomingTarget: Hashable {
    case request(UUID)
    case booking(UUID)
}


struct GroomingDetailView: View {
    let target: GroomingTarget
    var requestStore: CustomerRequestsStore?
    var bookingsStore: BookingsStore?
    var onOpenChat: ((Booking) -> Void)?
    var onRepublishRequest: ((CustomerGroomingRequest) -> Void)?
    var onCreateNewRequestFromBooking: ((Booking) -> Void)?
    /// A booking just made from an offer: Booked throws its sparkles once.
    var celebratesNewBooking = false
    @Environment(\.openBookingChat) private var shellOpenChat
    @FocusState private var focusedReviewTarget: GroomingReviewFocusTarget?
    @State private var fulfillmentAction: BookingFulfillmentAction?
    @State private var rescheduleReview: GroomingRescheduleSelection?
    @State private var isCancelRequestPresented = false
    @State private var now = Date()
    @State private var loadError: String?
    @State private var isResolving = true
    @Environment(\.scenePhase) private var scenePhase
    private let tick = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private enum Stage { case posted, offers, booked, finished, closedRequest, closedBooking }

    // MARK: What the page is about

    private var booking: Booking? {
        switch target {
        case .booking(let id): bookingsStore?.booking(withID: id)
        case .request(let id): bookingsStore?.bookings.first { $0.requestID == id }
        }
    }

    private var request: CustomerGroomingRequest? {
        switch target {
        case .request(let id): requestStore?.request(withID: id)
        case .booking: booking.flatMap { requestStore?.request(withID: $0.requestID) }
        }
    }

    private var stage: Stage {
        if let booking {
            if booking.status.isCancellation || booking.status == .unfulfilled { return .closedBooking }
            return GroomingFeed.isFinished(booking, now: now) ? .finished : .booked
        }
        switch request?.status {
        case .open?: return .posted
        case .hasOffers?: return .offers
        case .booked?: return .booked
        default: return .closedRequest
        }
    }

    private var avatar: Data? {
        requestStore?.primaryPetPhotoData(petID: request?.petID ?? booking?.requestPetSnapshot?.id)
    }

    private var openChat: ((Booking) -> Void)? { onOpenChat ?? shellOpenChat }

    // MARK: Body

    var body: some View {
        DesignReveal(isLoading: isResolving && booking == nil && request == nil) {
            if booking != nil || request != nil { page } else { unavailable }
        } placeholder: {
            DesignPage(cascades: false) { GroomingDetailSkeleton() }
                .accessibilityIdentifier("grooming.detail.loading")
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(booking != nil ? "bookings.detail" : "customer.requests.detail")
        .task(id: target) {
            isResolving = true
            await load()
            guard !Task.isCancelled else { return }
            isResolving = false
        }
        .onReceive(tick) { if scenePhase == .active { now = $0 } }
    }

    private var page: some View {
        ScrollViewReader { proxy in
            DesignPage {
                hero
                if let loadError {
                    BeckonErrorBanner(title: "Some details didn't load", message: loadError) {
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(BeckonGuardedPlainButtonStyle())
                    }
                }
                DesignReveal(isLoading: isResolving && booking != nil && booking?.fulfillment == nil && (stage == .booked || stage == .finished)) {
                    needsYou
                } placeholder: { GroomingNeedsSkeleton() }
                stageSection
                details
                manage
                activity
            }
            .refreshable { await load() }
            .beckonKeyboardAvoidance(focusedTarget: focusedReviewTarget?.rawValue, using: proxy)
        }
        .disabled((bookingsStore?.isMutatingFulfillment ?? false) || (bookingsStore?.isMutatingReschedule ?? false))
        .groomingFulfillmentDialog(action: $fulfillmentAction) { action, note in
            if let booking, let bookingsStore { Task { await bookingsStore.performFulfillment(action, for: booking, note: note) } }
        }
        .groomingRescheduleDialog(selection: $rescheduleReview, booking: booking) { selection, newStart in
            if let booking, let bookingsStore {
                Task { await bookingsStore.performReschedule(selection.action, for: booking, reviewedProposal: selection.proposal, newStart: newStart) }
            }
        }
        .designAlertDialog(isPresented: $isCancelRequestPresented) {
            .destructive(title: "Cancel this request?",
                message: "This closes the request and any pending offers. After cancellation succeeds, you can create a new request from its template.",
                systemImage: "xmark.circle.fill", keepTitle: "Keep Request", confirmTitle: "Cancel request",
                confirmSystemImage: "xmark.circle") {
                if let request, let requestStore { Task { await requestStore.cancel(request) } }
            }
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        if let booking {
            GroomingDetailHero(
                species: booking.agreementSnapshot?.petSnapshot.species ?? booking.requestPetSnapshot?.species ?? "",
                avatarData: avatar, title: GroomingCardContent.groomingTitle(booking), time: booking.scheduledTimeSummary,
                when: BeckonWhen(start: booking.scheduledStart, end: booking.scheduledEnd,
                    zoneIdentifier: booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier, now: now),
                card: stage == .closedBooking ? nil : GroomingCardContent.booking(booking, avatar: avatar,
                    isNew: celebratesNewBooking, now: now),
                closed: stage == .closedBooking ? .init(status: booking.status.presentation, message: closedMessage(booking.status)) : nil)
        } else if let request {
            GroomingDetailHero(
                species: request.petSnapshot.species, avatarData: avatar, title: request.displayTitle,
                time: request.preferredTimePresentation.summary,
                when: BeckonWhen(start: request.preferredStart, end: request.preferredEnd,
                    zoneIdentifier: request.preferenceTimeZoneIdentifier, now: now),
                card: requestCard(request),
                closed: requestCard(request) == nil
                    ? .init(status: request.status.presentation, message: closedMessage(request.status)) : nil,
                closes: closingLine(request))
        }
    }

    private func requestCard(_ request: CustomerGroomingRequest) -> GroomingCardContent? {
        guard request.status.isOpenForOffers, let requestStore else { return nil }
        let item = CustomerRequestActionCardItem(request: request, handoff: nil, petAvatarPhotoData: avatar,
            loadedOfferCount: requestStore.loadedCurrentOfferCount(for: request))
        return .request(item, reach: nil, now: now)
    }

    private func closingLine(_ request: CustomerGroomingRequest) -> String? {
        guard request.status.isOpenForOffers, let date = GroomingRequestDateFormatting.parsedDate(from: request.expiresAt),
              date > now else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Closes " + formatter.localizedString(for: date, relativeTo: now)
    }

    private func closedMessage(_ status: GroomingRequestStatus) -> String {
        switch status {
        case .cancelled: "This request was cancelled. Nothing more will happen on it."
        case .expired: "This request expired before a booking was made."
        case .booked: "This request was booked."
        default: "This request is no longer active."
        }
    }

    private func closedMessage(_ status: BookingStatus) -> String {
        switch status {
        case .unfulfilled: "This service was not confirmed. You can start a new request any time."
        case .cancelledByCustomer: "You cancelled this booking."
        case .cancelledByGroomer: "The groomer cancelled this booking. You can start a new request any time."
        default: "This booking is no longer active."
        }
    }

    // MARK: Needs you

    @ViewBuilder
    private var needsYou: some View {
        if let booking, let bookingsStore {
            GroomingNeedsYou(booking: booking, store: bookingsStore, now: now,
                fulfillmentAction: $fulfillmentAction, rescheduleReview: $rescheduleReview)
        } else if let request, let requestStore, showsTimingRecovery(request) {
            GroomingNeedsCard(title: "This request can't go further", systemImage: "exclamationmark.triangle.fill") {
                Text("This request has no confirmed time zone. Cancel it, then create a new request from its template and confirm the service address.")
                    .designSupportingText()
                Button(role: .destructive) { isCancelRequestPresented = true } label: {
                    DesignQuietAction(title: "Cancel outdated request", systemImage: "xmark.circle", isDestructive: true)
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(requestStore.cancellingRequestIDs.contains(request.id))
                .accessibilityIdentifier("customer.requests.timing-recovery.cancel")
            }
        }
    }

    /// An open request whose time zone is not confirmed cannot go on: the only way out is to cancel it and start again.
    private func showsTimingRecovery(_ request: CustomerGroomingRequest) -> Bool {
        CustomerRequestDetailPresentation(status: request.status, preferenceTimeZoneIdentifier: request.preferenceTimeZoneIdentifier).showsTimingRecovery
    }

    func republish(_ request: CustomerGroomingRequest) {
        (onRepublishRequest ?? { requestStore?.startRepublish(from: $0) })(request)
    }

    // MARK: The one thing for this stage

    @ViewBuilder
    private var stageSection: some View {
        switch stage {
        case .posted, .offers:
            if let request, let requestStore {
                offers(request, store: requestStore)
                if let marketplace = requestStore.marketplace, request.status.isOpenForOffers {
                    CustomerRequestReachCard(requestID: request.id, store: marketplace.distribution) {
                        requestStore.browseGroomers(for: request)
                    }
                }
            }
        case .finished:
            if let booking, let bookingsStore {
                GroomingReviewSection(booking: booking, store: bookingsStore, focusedTarget: $focusedReviewTarget)
            }
        case .closedRequest:
            if let request {
                Button { republish(request) } label: {
                    DesignActionLabel(title: "Create a new request from this template", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(BeckonLedgeButtonStyle(.pill))
                .accessibilityIdentifier("customer.requests.republish")
            }
        case .closedBooking:
            if let booking {
                Button {
                    if let onCreateNewRequestFromBooking { onCreateNewRequestFromBooking(booking) }
                    else if let requestStore { Task { await requestStore.prepareRepublish(from: booking) } }
                } label: {
                    DesignActionLabel(title: "Create a new request from this booking", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(BeckonLedgeButtonStyle(.pill))
                .accessibilityIdentifier("customer.bookings.republish")
            }
        case .booked:
            EmptyView()
        }
    }

    /// The offers as a row of cards you swipe through (up to five), with the page dots under them and one link to compare them all.
    @ViewBuilder
    private func offers(_ request: CustomerGroomingRequest, store: CustomerRequestsStore) -> some View {
        let pending = store.offers(for: request).filter { $0.isCurrentProposal() }
        if request.status.isOpenForOffers, !pending.isEmpty {
            let shown = Array(pending.prefix(5))
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                BeckonLedgeHeading(title: "Offers", systemImage: "tag.fill", count: pending.count)
                CustomerOfferCarousel(reviews: shown, now: now, highlights: CustomerOfferHighlights(pending, isComplete: store.loadedCurrentOfferCount(for: request) != nil)) { review in
                    CustomerOfferDetailView(request: request, offerID: review.id, store: store)
                }
                CustomerNavigationLink(route: .offers(request.id)) {
                    CustomerRequestOffersView(requestID: request.id, store: store)
                } label: {
                    DesignLinkCardLabel(
                        title: pending.count > shown.count ? "See all \(pending.count) offers"
                            : pending.count > 1 ? "Compare offers" : "Offers and history",
                        summary: pending.count > 1 ? "Sort by price or time, side by side" : "Includes past offers",
                        systemImage: "square.stack.3d.up.fill"
                    )
                }
                .buttonStyle(BeckonLedgeButtonStyle(.card))
                .accessibilityIdentifier("customer.requests.see-offers")
            }
        }
    }

    // MARK: Details

    @ViewBuilder
    private var details: some View {
        if request != nil || booking != nil {
            GroomingDetailsCard(request: request, booking: booking, requestStore: requestStore, onOpenChat: openChat)
        }
    }

    // MARK: Manage

    @ViewBuilder
    private var manage: some View {
        if let booking, let bookingsStore, stage == .booked || stage == .finished {
            GroomingBookingManage(booking: booking, store: bookingsStore, now: now,
                fulfillmentAction: $fulfillmentAction, rescheduleReview: $rescheduleReview)
        } else if let request, let requestStore, request.status.isOpenForOffers, booking == nil {
            DesignSection(title: "Manage request", systemImage: "slider.horizontal.3") {
                DesignManageRow(title: "Revise request", systemImage: "square.and.pencil") {
                    requestStore.startRevision(from: request)
                }
                .disabled(requestStore.isSubmitting || request.termsRevision == nil)
                .accessibilityHint("Reopens this request so you can change it and publish it again.")
                .accessibilityIdentifier("customer.requests.revise")
                DesignRowDivider()
                DesignManageRow(title: requestStore.isCancelling(request) ? "Cancelling" : "Cancel request",
                    systemImage: requestStore.isCancelling(request) ? "hourglass" : "xmark.circle", isDestructive: true) {
                    isCancelRequestPresented = true
                }
                .disabled(requestStore.isCancelling(request))
                .accessibilityIdentifier("customer.requests.cancel")
            }
        }
    }

    // MARK: Activity

    @ViewBuilder
    private var activity: some View {
        let entries = timeline
        let showsOffersLink = request != nil && requestStore != nil && stage != .posted && stage != .offers
            && !(requestStore?.offers(for: request!).isEmpty ?? true)
        if entries.count > 1 || showsOffersLink {
            GroomingTimeline(entries: entries,
                offersDestination: showsOffersLink ? request.flatMap { request in
                    requestStore.map { AnyView(CustomerRequestOffersView(requestID: request.id, store: $0)) }
                } : nil)
        }
    }

    /// What happened, from the request to the review, each with its time when there is one.
    private var timeline: [GroomingTimelineEntry] {
        var entries: [GroomingTimelineEntry] = []
        let zone = booking?.serviceTimeZoneIdentifier ?? request?.preferenceTimeZoneIdentifier
        func when(_ raw: String?) -> String? {
            raw.map { GroomingRequestDateFormatting.displayString(from: $0, serviceTimeZoneIdentifier: zone) }
        }
        if let request {
            entries.append(.init(id: "posted", systemImage: "paperplane.fill", title: "Request posted", detail: when(request.createdAt)))
            let count = requestStore?.offers(for: request).count ?? 0
            if count > 0 {
                entries.append(.init(id: "offers", systemImage: "tag.fill", title: count == 1 ? "1 offer received" : "\(count) offers received"))
            }
            if booking == nil, !request.status.isOpenForOffers, request.status != .booked {
                entries.append(.init(id: "closed", systemImage: request.status.presentation.systemImage,
                    title: request.status.presentation.title, detail: when(request.updatedAt)))
            }
        }
        guard let booking else { return entries }
        entries.append(.init(id: "booked", systemImage: "calendar", title: "Booked",
            detail: when(booking.createdAt), note: "\(booking.partnerDisplayTitle(for: .customer)) · \(booking.priceSummary)"))
        if let bookingsStore {
            if let proposal = bookingsStore.rescheduleSnapshots[booking.id]?.proposal,
               proposal.currentStatus(for: booking, now: now) != .pending {
                entries.append(.init(id: "reschedule", systemImage: "calendar.badge.clock",
                    title: proposal.currentStatus(for: booking, now: now).title))
            }
            if let service = booking.fulfillment {
                if let started = service.actualStartedAt {
                    entries.append(.init(id: "started", systemImage: "sparkles", title: "Service started", detail: when(started)))
                }
                if let ended = service.actualEndedAt {
                    entries.append(.init(id: "ended", systemImage: "checkmark.circle", title: "Service ended", detail: when(ended)))
                }
                if service.basis == "bilateral_retrospective" {
                    entries.append(.init(id: "basis", systemImage: "checkmark.seal",
                        title: "Completion confirmed by both participants",
                        note: "Unrecorded service times remain unknown."))
                }
            }
            for event in bookingsStore.fulfillmentHistory[booking.id] ?? [] {
                entries.append(.init(id: "event-\(event.id)", systemImage: event.action.systemImage, title: event.action.title,
                    detail: (event.actorID == booking.customerID ? "You" : "Groomer") + " · " + (when(event.recordedAt) ?? ""),
                    note: event.note))
            }
            if let error = bookingsStore.fulfillmentHistoryErrors[booking.id] {
                entries.append(.init(id: "history-error", systemImage: "exclamationmark.triangle", title: "The record did not load", note: error))
            }
        }
        if let review = booking.review {
            entries.append(.init(id: "review", systemImage: "star.fill", title: "Review left", detail: when(review.createdAt),
                note: review.ratingSummary))
        }
        return entries
    }

    // MARK: Loading and refreshing

    private func load() async {
        loadError = nil
        switch target {
        case .booking(let id): await bookingsStore?.resolveBooking(id: id)
        case .request: break
        }
        let requestID: UUID? = switch target {
        case .request(let id): id
        case .booking: booking?.requestID
        }
        if let requestID, let requestStore {
            do {
                let current = try await requestStore.resolveNotificationRequest(id: requestID)
                if current.status == .booked, case .request = target,
                   let resolved = try await requestStore.resolveBookingForGrooming(requestID: requestID) {
                    bookingsStore?.synchronizeExternalBooking(resolved)
                }
                if current.status.isOpenForOffers {
                    await requestStore.loadOffers(for: current)
                    await requestStore.refreshDistributionProgress(requestIDs: [requestID])
                }
            } catch { if !Task.isCancelled { loadError = "Request details could not be refreshed. Try again." } }
        }
        if let booking, let bookingsStore {
            if booking.fulfillment == nil { await bookingsStore.refreshFulfillment(for: booking.id) }
            else { await bookingsStore.loadFulfillmentHistory(for: booking.id) }
            await bookingsStore.loadReschedule(for: booking.id)
        }
    }

    // MARK: Waiting and unavailable

    private var unavailable: some View {
        ZStack {
            BeckonExpressiveBackdrop()
            switch target {
            case .request:
                DesignPage(cascades: false) {
                    BeckonLedgeNote(systemImage: "doc.text.magnifyingglass",
                        text: loadError ?? "This request isn't available. Refresh requests and try again.")
                    Button("Retry") { Task { await load() } }.buttonStyle(BeckonGuardedPlainButtonStyle())
                }
            case .booking(let id):
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        BeckonLedgeNote(systemImage: "calendar.badge.exclamationmark",
                            text: "Booking unavailable. This booking could not be verified.")
                        Button { Task { await bookingsStore?.resolveBooking(id: id) } } label: {
                            DesignActionLabel(title: "Retry booking", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(BeckonLedgeButtonStyle(.pill))
                        .accessibilityIdentifier("bookings.detail.retry")
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
        }
    }
}
