// One request, opened from the Requests list, an offer in it, a notification or Home (design; merged with the offer page in design).
// The request page and the offer page told two halves of one story (the offer was on both, each linking to the other), as the owner's
// Request detail and Booking detail once did. Now one page follows the request from the match to the booking, and is the owner's
// Grooming detail seen from the other side: the hero is the request opened up (the groomer's path: Matched, Offer sent, Booked, with
// its bubble), under it the cards that say what holds the groomer back or what is wrong with their offer, then the one thing for the
// stage (what was asked and the form that answers it; the offer that is waiting; the booking it became), the quiet manage rows, and
// what happened. Same job as GroomerRequestDetailView and GroomerOfferDetailView in Features/Groomer: read the request, answer it
// with an offer (a time in the service's time zone, a duration, a price, a message, and the confirmations some requests ask for),
// withdraw a pending offer, dismiss the match, and see what became of the offer. The stores, the form's state and the identifiers
// are the real ones.
import Combine
import SwiftUI


struct GroomerRequestDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.groomerGroomingWorkspace) private var adoptedWorkspace
    let target: GroomerRequestTarget
    let requests: GroomerRequestsStore
    let offers: GroomerOffersStore
    /// The Schedule's page of a booking: where the groomer goes once the customer accepted the offer.
    var onOpenBooking: ((Booking) -> Void)?

    @State private var form: GroomerOfferFormState
    @State private var hasOpened = false
    @State private var isConfirmingDismissal = false
    @State private var isConfirmingWithdrawal = false
    @State private var now = Date()
    @FocusState private var focusedTarget: GroomerOfferFocusTarget?
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(target: GroomerRequestTarget, requests: GroomerRequestsStore, offers: GroomerOffersStore,
         onOpenBooking: ((Booking) -> Void)? = nil) {
        self.target = target
        self.requests = requests
        self.offers = offers
        self.onOpenBooking = onOpenBooking
        _form = State(initialValue: GroomerOfferFormState(store: requests))
    }

    var body: some View {
        if let adoptedWorkspace {
            GroomerGroomingRequestDetail(target: target, workspace: adoptedWorkspace, onOpenBooking: onOpenBooking)
                .environment(\.groomerVisitAppearance, true)
        } else { legacyBody }
    }

    private var legacyBody: some View {
        content
            .beckonHidesTabBar()
            .task(id: target) {
                await open()
                guard !Task.isCancelled else { return }
                hasOpened = true
            }
            .onDisappear { requests.closeDetail(); form.cancelPendingLoads() }
            .onReceive(tick) { now = $0 }
    }

    @ViewBuilder
    private var content: some View {
        if let subject, let request = subject.request {
            page(subject, request)
        } else if requests.isLoadingDetail || offers.isLoading || !hasOpened {
            ZStack {
                BeckonExpressiveBackdrop()
                DesignPage(cascades: false) { GroomingDetailSkeleton(pathStops: BeckonJourneyStop.groomerRequestPath, deadlineInCorner: true) }
                    .accessibilityIdentifier("groomer.requests.detail.loading")
            }
            .navigationTitle("Request")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            unavailable
        }
    }

    private var unavailable: some View {
        ZStack {
            BeckonExpressiveBackdrop()
            VStack(spacing: DesignTokens.Spacing.md) {
                BeckonLedgeNote(systemImage: "tray", text: requests.detailError ?? "Refresh your requests and try again.")
                Button { Task { await open() } } label: {
                    DesignQuietAction(title: "Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: What the page is about

    /// The request with the match, the offer and the booking, put together from the stores; nil until the request can be read.
    private var subject: GroomerRequestSubject? {
        switch target {
        case .match(let id):
            guard let matched = requests.authorizedDetail, matched.id == id else { return nil }
            return makeSubject(matched: matched, opened: nil)
        case .offer(let id):
            guard let item = offers.offers.first(where: { $0.id == id }) else { return nil }
            let matched = requests.authorizedDetail.flatMap { $0.request.id == item.offer.requestID ? $0 : nil }
            return makeSubject(matched: matched, opened: item)
        }
    }

    private func makeSubject(matched: GroomerMatchedRequest?, opened: GroomerOfferListItem?) -> GroomerRequestSubject {
        let requestID = matched?.request.id ?? opened?.offer.requestID
        let listed = offers.offers.filter { $0.offer.requestID == requestID }
        var history = listed.map(\.offer)
        if let offer = matched?.offer, !history.contains(where: { $0.id == offer.id }) { history.append(offer) }
        history.sort { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
        // The page is of the request, so it is about the latest offer, whichever of them it was opened on.
        let latest = listed.max { $0.createdAtDate < $1.createdAtDate } ?? opened
        return GroomerRequestSubject(matched: matched, item: latest, history: history)
    }

    /// Opens the request in the store: by its match, or from an offer (the offer's match when the list has it; for an offer that is
    /// still waiting or was withdrawn, the request is asked for, so the groomer can act on it).
    private func open() async {
        switch target {
        case .match(let id):
            await requests.openDetail(matchID: id)
            if offers.offers.isEmpty { await offers.load() }
        case .offer(let id):
            if offers.offers.isEmpty { await offers.load() }
            guard let item = offers.offers.first(where: { $0.id == id }) else { return }
            let requestID = item.offer.requestID
            if let listed = requests.matchedRequests.first(where: { $0.request.id == requestID }) {
                await requests.openDetail(matchID: listed.id)
            } else if item.offer.status == .pending || item.offer.status == .withdrawnByGroomer,
                      let resolved = try? await requests.resolveNotificationRequest(id: requestID) {
                await requests.openDetail(matchID: resolved.id)
            }
        }
    }

    /// Pull to refresh: the offers first (the customer's answer and the booking it made are there), then the request itself.
    private func refresh() async {
        await offers.load()
        await open()
    }

    // MARK: Page

    private func page(_ subject: GroomerRequestSubject, _ request: GroomerMatchedGroomingRequest) -> some View {
        let stage = GroomerRequestStage(subject, now: now)
        return ScrollViewReader { proxy in
            DesignPage {
                hero(subject, request, stage)
                needs(stage)
                if stage.kind == .new, let matched = subject.matched { GroomerWhyMatched(matched: matched) }
                blocks(subject, request, stage)
                manage(stage)
                activity(subject)
                if stage.canAnswer {
                    // The pinned button covers the foot of the page: this much room keeps the last block above it.
                    Color.clear.frame(height: DesignTokens.Layout.stationaryActionContentClearance - DesignTokens.Layout.pageBottomInset)
                        .accessibilityHidden(true)
                }
            }
            .beckonKeyboardAvoidance(focusedTarget: focusedTarget?.rawValue, using: proxy,
                additionallyPreventsPresentationDismissal: requests.isSubmittingOffer)
            .refreshable { await refresh() }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.requests.detail")
        .task(id: stage.canAnswer) {
            if stage.canAnswer, let matched = subject.matched { await form.initializeOfferFormIfNeeded(for: matched) }
        }
        .onChange(of: subject.matched?.request.termsRevision) { _, _ in form.confirmedAssessmentKeys = [] }
        .onChange(of: subject.matched?.match.eligibilityEvaluation?.sourceRevision) { _, _ in form.confirmedAssessmentKeys = [] }
        .onChange(of: subject.matched?.match.eligibilityEvaluation?.confirmationKeys) { _, _ in form.confirmedAssessmentKeys = [] }
        .beckonStationaryPageAction {
            if stage.canAnswer, let matched = subject.matched {
                submitBar(matched).disabled(requests.isLoadingDetail)
            }
        }
        .designAlertDialog(isPresented: $isConfirmingWithdrawal) {
            .destructive(title: "Withdraw this offer?", message: "The customer will no longer be able to accept it.",
                systemImage: "arrow.uturn.backward.circle.fill", keepTitle: "Keep offer", confirmTitle: "Withdraw",
                confirmSystemImage: "arrow.uturn.backward", confirmIdentifier: "groomer.offers.withdraw.confirm") {
                guard let matched = subject.matched else { return }
                Task {
                    await requests.withdrawOffer(for: matched)
                    await offers.load()
                }
            }
        }
        .designAlertDialog(isPresented: $isConfirmingDismissal) {
            .destructive(title: "Dismiss this match?", message: "It leaves your matches.",
                systemImage: "xmark.circle.fill", keepTitle: "Keep it", confirmTitle: "Dismiss match",
                confirmSystemImage: "xmark", confirmIdentifier: "groomer.requests.dismiss.confirm") {
                guard let matched = subject.matched else { return }
                Task {
                    await requests.dismiss(matched)
                    // The match is gone from the list once it is dismissed: leave its page with it.
                    if !requests.matchedRequests.contains(where: { $0.id == matched.id }) { dismiss() }
                }
            }
        }
    }

    // MARK: Blocks

    private func hero(_ subject: GroomerRequestSubject, _ request: GroomerMatchedGroomingRequest,
                      _ stage: GroomerRequestStage) -> some View {
        let pet = request.petSnapshot
        // Booked, the time is the one the customer accepted; before, it is the one they asked for.
        let accepted = stage.kind == .booked ? subject.offer : nil
        let when = accepted.flatMap {
            BeckonWhen(start: $0.proposedStart, end: $0.proposedEnd,
                zoneIdentifier: $0.serviceTimeZoneIdentifier ?? request.preferenceTimeZoneIdentifier, now: now)
        } ?? BeckonWhen(start: request.preferredStart, end: request.preferredEnd,
            zoneIdentifier: request.preferenceTimeZoneIdentifier, now: now)
        return GroomingDetailHero(species: pet.species, avatarData: subject.matched.flatMap(firstPhoto),
            title: "\(request.serviceType.title) · \(pet.name)", time: request.preferredTimePresentation.summary, when: when,
            card: nil, closed: stage.closed, closes: stage.closes, deadlineInCorner: true, path: stage.path, identifier: "groomer.requests.hero")
    }

    /// What holds the groomer back, or what is wrong with their offer. Nothing is drawn when nothing is.
    @ViewBuilder
    private func needs(_ stage: GroomerRequestStage) -> some View {
        if let hold = stage.hold {
            switch hold {
            case .checking:
                GroomingNeedsCard(title: hold.title, systemImage: "clock.arrow.circlepath", tone: .info) {
                    Text("Service and availability are being checked. You can make an offer when that is done.")
                        .designSupportingText()
                }
                .accessibilityIdentifier("groomer.requests.needs")
            case .species:
                GroomingNeedsCard(title: hold.title, systemImage: "pawprint.circle.fill") {
                    Text("Confirm the accepted species for this service in your profile before making an offer.")
                        .designSupportingText()
                }
                .accessibilityIdentifier("groomer.requests.needs")
            case .unsupported:
                GroomingNeedsCard(title: hold.title, systemImage: "exclamationmark.triangle.fill") {
                    Text("This request requires service confirmations that are not supported by this version of Beckon.")
                        .designSupportingText()
                }
                .accessibilityIdentifier("groomer.requests.needs")
            case .unavailable:
                GroomingNeedsCard(title: hold.title, systemImage: "lock.fill") {
                    Text("This request can no longer receive a new offer from this account.").designSupportingText()
                }
                .accessibilityIdentifier("groomer.requests.needs")
            }
        }
        if let problem = stage.problem {
            switch problem {
            case .timingMissing:
                replaceOffer(title: problem.title,
                    text: "This offer is missing confirmed timing details. Withdraw it and send a new offer.")
            case .newOfferRequired:
                replaceOffer(title: problem.title,
                    text: "The request or the agreed details changed. Withdraw this offer and send a new one.")
            case .timeUnavailable:
                GroomingNeedsCard(title: problem.title, systemImage: "calendar.badge.exclamationmark") {
                    Text("This time is currently unavailable. Check again before the offer ends.").designSupportingText()
                }
                .accessibilityIdentifier("groomer.requests.needs")
            case .checking:
                GroomingNeedsCard(title: problem.title, systemImage: "clock.arrow.circlepath", tone: .info) {
                    Text("The customer's view of your offer is being checked.").designSupportingText()
                }
                .accessibilityIdentifier("groomer.requests.needs")
            }
        }
    }

    private func replaceOffer(title: String, text: String) -> some View {
        GroomingNeedsCard(title: title, systemImage: "exclamationmark.triangle.fill") {
            Text(text).designSupportingText()
            GroomingActionButton(title: "Withdraw offer", systemImage: "arrow.uturn.backward.circle",
                identifier: "groomer.offers.withdraw") { isConfirmingWithdrawal = true }
                .disabled(requests.isWithdrawingOffer)
        }
        .accessibilityIdentifier("groomer.requests.needs")
    }

    /// The one thing for the stage, and what was asked. A new request is read first and answered under it; an offer that is
    /// waiting, a booking it became, and a request that is over come first, and the request after them as what it was.
    @ViewBuilder
    private func blocks(_ subject: GroomerRequestSubject, _ request: GroomerMatchedGroomingRequest,
                        _ stage: GroomerRequestStage) -> some View {
        switch stage.kind {
        case .new:
            details(subject, request)
            if let offer = subject.offer {
                GroomerOfferRecord(offer: offer, title: "Your earlier offer", now: now, showsStatus: true)
            }
            if stage.canAnswer, let matched = subject.matched { offerForm(matched, hasEarlierOffer: subject.offer != nil) }
        case .offered, .closed:
            if let offer = subject.offer { GroomerOfferRecord(offer: offer, now: now) }
            details(subject, request)
        case .booked:
            GroomerBookedCard(booking: subject.booking, onOpenBooking: onOpenBooking)
            if let offer = subject.offer { GroomerOfferRecord(offer: offer, now: now, showsTime: subject.booking == nil) }
            details(subject, request)
        }
    }

    @ViewBuilder
    private func details(_ subject: GroomerRequestSubject, _ request: GroomerMatchedGroomingRequest) -> some View {
        GroomerRequestDetails(request: request)
        GroomerPetCard(pet: request.petSnapshot, visitNotes: request.serviceNotes,
            photos: subject.matched.map(photos) ?? [], identifier: "groomer.requests.pet")
    }

    private func offerForm(_ matched: GroomerMatchedRequest, hasEarlierOffer: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: hasEarlierOffer ? "Make a new offer" : "Make an offer", systemImage: "tag.fill")
            GroomerOfferForm(matched: matched, form: form, focusedTarget: $focusedTarget)
        }
        .disabled(!form.didInitializeOfferForm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.requests.offer-form")
    }

    /// The rows nobody needs often: withdraw the offer that is waiting, dismiss a match that is new.
    @ViewBuilder
    private func manage(_ stage: GroomerRequestStage) -> some View {
        let showsWithdraw = stage.canWithdraw && stage.problem?.needsWithdrawal != true
        if showsWithdraw || stage.canDismiss {
            DesignSection(title: "Manage request", systemImage: "slider.horizontal.3") {
                if showsWithdraw {
                    DesignManageRow(title: "Withdraw offer", systemImage: "arrow.uturn.backward.circle", isDestructive: true) {
                        isConfirmingWithdrawal = true
                    }
                    .disabled(requests.isWithdrawingOffer)
                    .accessibilityIdentifier("groomer.offers.withdraw")
                }
                if stage.canDismiss {
                    DesignManageRow(title: "Dismiss match", systemImage: "xmark.circle", isDestructive: true) {
                        isConfirmingDismissal = true
                    }
                    .disabled(requests.isDismissing || requests.isLoadingDetail)
                    .accessibilityIdentifier("groomer.requests.dismiss")
                }
            }
        }
    }

    /// What happened, from the match to the booking.
    @ViewBuilder
    private func activity(_ subject: GroomerRequestSubject) -> some View {
        let entries = GroomingTimelineEntry.groomerRequest(subject)
        if entries.count > 1 {
            GroomingTimeline(entries: entries, identifier: "groomer.requests.activity",
                toggleIdentifier: "groomer.requests.activity.toggle")
        }
    }

    // MARK: Pinned button

    private func submitBar(_ matched: GroomerMatchedRequest) -> some View {
        let isBusy = requests.isSubmittingOffer
        return Button {
            Task { await form.submitOffer(for: matched) }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isBusy { ProgressView().tint(DesignTokens.Colors.customerInk) }
                Text(isBusy ? "Submitting offer…" : "Submit offer")
                    .font(DesignTokens.Typography.Expressive.headline)
                if !isBusy { Image(systemName: "paperplane.fill").font(DesignTokens.Typography.Expressive.glyph) }
            }
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .disabled(isBusy || !form.didInitializeOfferForm || form.proposedEnd == nil || form.serviceTimeZone == nil
            || form.confirmedAssessmentKeys != (matched.match.eligibilityEvaluation?.confirmationKeys ?? []))
        .accessibilityIdentifier("groomer.offers.submit")
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.actionAreaInset)
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) { DesignTokens.Colors.borderSoft.frame(height: DesignTokens.Ledge.edgeWidth / 2) }
    }

    // MARK: Helpers

    private func firstPhoto(_ matched: GroomerMatchedRequest) -> Data? {
        requests.requestPhotos(for: matched).first.flatMap { requests.requestPhotoData(for: $0) }
    }

    private func photos(_ matched: GroomerMatchedRequest) -> [GroomerPetCard.Photo] {
        requests.requestPhotos(for: matched).map {
            GroomerPetCard.Photo(id: "\($0.id)", data: requests.requestPhotoData(for: $0), label: $0.caption ?? $0.fileName)
        }
    }
}
