import Combine
import SwiftUI


struct GroomerGroomingRequestDetail: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let target: GroomerRequestTarget
    let workspace: GroomerGroomingWorkspace
    private var requests: GroomerRequestsStore { workspace.session.requests }
    private var offers: GroomerOffersStore { workspace.session.offers }
    /// The Schedule's page of a booking: where the groomer goes once the customer accepted the offer.
    var onOpenBooking: ((Booking) -> Void)?

    @State private var form: GroomerOfferFormState
    @State private var selectedPet: GroomingRequestPetSnapshot?
    @State private var hasOpened = false
    @State private var resolvedOffer: GroomerOfferListItem?
    @State private var sending = false
    @State private var offerToConfirm: (draft: GroomerOfferDraft, request: GroomerMatchedGroomingRequest)?
    @State private var quoteError: String?
    @State private var startError: String?
    @State private var isConfirmingDismissal = false
    @State private var isConfirmingWithdrawal = false
    @State private var now = Date()
    @State private var focusedTarget: GroomerOfferFocusTarget?
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(target: GroomerRequestTarget, workspace: GroomerGroomingWorkspace,
         onOpenBooking: ((Booking) -> Void)? = nil) {
        self.target = target
        self.workspace = workspace
        self.onOpenBooking = onOpenBooking
        _form = State(initialValue: GroomerOfferFormState(store: workspace.session.requests))
    }

    var body: some View {
        content
            .beckonHidesTabBar()
            .groomerVisitDetailPresentation()
            .task(id: target) {
                if hasOpened, subject?.matched != nil { return }
                await open()
                guard !Task.isCancelled else { return }
                hasOpened = true
            }
            .onDisappear {
                guard selectedPet == nil else { return }
                form.cancelPendingLoads()
            }
            .onReceive(tick) { now = $0 }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    focusedTarget = nil
                    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                        .flatMap(\.windows).filter(\.isKeyWindow).forEach { $0.endEditing(true) }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let subject, subject.request != nil || subject.offer != nil {
            page(subject)
        } else if requests.isLoadingDetail || offers.isLoading || !hasOpened {
            let hint = listedSubject
            GroomerVisitRequestDetailLoading(subject: hint, booking: hint.item.flatMap(workspace.booking(for:)),
                groomerID: workspace.session.groomerID, decision: decision(hint, GroomerRequestStage(hint, now: now)))
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

    /// Use only the selected list row to size the placeholder while the detail read is pending.
    private var listedSubject: GroomerRequestSubject {
        switch target {
        case .match(let id):
            matchSubject(workspace.matches.first { $0.id == id } ?? requests.matchedRequests.first { $0.id == id })
        case .offer(let id):
            GroomerRequestSubject(item: workspace.offers.first { $0.id == id } ?? offers.offers.first { $0.id == id })
        }
    }

    /// The request with the match, the offer and the booking, put together from the stores; nil until the request can be read.
    private var subject: GroomerRequestSubject? {
        switch target {
        case .match(let id):
            guard let matched = requests.authorizedDetail, matched.id == id else { return nil }
            return matchSubject(matched)
        case .offer(let id):
            guard let item = resolvedOffer ?? workspace.offers.first(where: { $0.id == id }) ?? offers.offers.first(where: { $0.id == id }) else { return nil }
            let matched = requests.authorizedDetail.flatMap { $0.request.id == item.offer.requestID ? $0 : nil }
            // An explicitly opened offer keeps its own outcome even if a newer offer exists or the match reopened.
            let live = GroomerRequestStage(.init(item: item), now: now).kind == .offered && matched?.offer?.id == item.id
            return GroomerRequestSubject(matched: live ? matched : nil, item: item)
        }
    }

    private func matchSubject(_ matched: GroomerMatchedRequest?) -> GroomerRequestSubject {
        guard let matched else { return .init() }
        let latest = offers.offers.filter { $0.offer.requestID == matched.request.id }
            .max { $0.createdAtDate < $1.createdAtDate }
        return .init(matched: matched, item: latest)
    }

    /// Opens the request in the store: by its match, or from an offer (the offer's match when the list has it; for an offer that is
    /// still waiting or was withdrawn, the request is asked for, so the groomer can act on it).
    private func open() async {
        switch target {
        case .match(let id):
            await requests.openDetail(matchID: id)
            if offers.offers.isEmpty { await offers.load() }
        case .offer(let id):
            guard let item = try? await workspace.offerItem(id: id, forceRefresh: true), !Task.isCancelled else { return }
            resolvedOffer = item
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
        await workspace.refresh(.offers)
        await open()
        if let offer = subject?.offer, offer.status == .acceptedByCustomer,
           workspace.booking(for: offer, listedBooking: subject?.booking) == nil {
            await workspace.refresh(.bookings)
        }
    }

    // MARK: Page

    private func page(_ subject: GroomerRequestSubject) -> some View {
        let requestID = subject.request?.id ?? subject.offer?.requestID
        let petName = subject.request?.petSnapshot.name ?? subject.item?.groomerVisitPet?.name
        let stage = GroomerRequestStage(subject, now: now)
        let showsSend = subject.matched != nil && (stage.canAnswer || stage.hold == .checking)
        let showsBooking = stage.kind == .booked && onOpenBooking != nil
        let booking = subject.offer.flatMap { workspace.booking(for: $0, listedBooking: subject.booking) }
        let startAnchor = GroomerVisitCurrentOfferForm.startAnchor
        return ScrollViewReader { proxy in
            detailPage {
                Group {
                    GroomerVisitRequestOverview(subject: subject,
                        photo: subject.matched.flatMap(firstPhoto) ?? requestID.flatMap(workspace.photo(for:)),
                        stage: stage, now: now, decision: decision(subject, stage), selectedPet: $selectedPet, hasLinkedBooking: booking != nil)
                        .id("request-top")
                    if let request = subject.request {
                        GroomerVisitRequestFacts(request: request, booking: booking, groomerID: workspace.session.groomerID)
                    }
                }
                if stage.kind == .new {
                    needs(stage)
                    if stage.canAnswer, let matched = subject.matched {
                        offerForm(matched, hasEarlierOffer: subject.offer != nil)
                    }
                } else {
                    if let offer = subject.offer {
                        GroomerVisitRequestOfferRecord(offer: offer)
                    }
                    needs(stage)
                }
                if let error = requests.actionErrorMessage { BeckonLedgeNote(systemImage: "exclamationmark.circle", text: error) }
            }
            .beckonKeyboardAvoidance(focusedTarget: focusedTarget?.rawValue, using: proxy,
                additionallyPreventsPresentationDismissal: sending, showsDoneAccessory: false)
            .groomerVisitDismissKeyboardOnOutsideTap(isEditing: focusedTarget != nil) {
                focusedTarget = nil
            }
            .onChange(of: stage.kind) { _, _ in
                quoteError = nil
                startError = nil
                proxy.scrollTo("request-top", anchor: .top)
            }
            .refreshable { await refresh() }
            .modifier(GroomerVisitRequestFooter(showsPrimary: showsSend || showsBooking,
                onDismissMatch: stage.canDismiss ? { isConfirmingDismissal = true } : nil,
                onWithdrawOffer: stage.canWithdraw ? { isConfirmingWithdrawal = true } : nil,
                isEditing: focusedTarget != nil || scenePhase != .active,
                busy: sending || requests.isDismissing || requests.isWithdrawingOffer || requests.isLoadingDetail,
                error: quoteError) {
                if showsBooking, let onOpenBooking {
                    GroomerVisitViewBookingAction(booking: booking, open: onOpenBooking, refresh: refresh)
                } else if let matched = subject.matched {
                    sendButton(matched, checking: stage.hold == .checking) {
                        proxy.scrollTo(startAnchor, anchor: .top)
                    }
                }
            })
            .groomerVisitDesignModal(item: $offerToConfirm) { confirmation in
                .groomerVisitSendOffer(draft: confirmation.draft, request: confirmation.request, serviceTimeZone: form.serviceTimeZone,
                    keepEditing: { offerToConfirm = nil }) {
                    sendOffer(confirmation.draft) {
                        proxy.scrollTo(startAnchor, anchor: .top)
                    }
                }
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
        .beckonNavigationDestination(item: $selectedPet) { pet in
            GroomerVisitRequestPetProfile(pet: pet, photos: requestID.map { workspace.petProfilePhotos(for: $0, matched: subject.matched) } ?? [])
        }
        .onChange(of: selectedPet) { if selectedPet != nil { focusedTarget = nil } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.requests.detail")
        .task(id: stage.canAnswer) {
            if stage.canAnswer, let matched = subject.matched { await form.initializeRequestDraft(for: matched) }
        }
        .groomerVisitDesignModal(isPresented: $isConfirmingWithdrawal) {
            .groomerVisitWithdrawOffer(price: subject.offer?.priceSummary, petName: petName) {
                guard let matched = subject.matched else { return }
                Task {
                    await requests.withdrawOffer(for: matched)
                    await offers.load()
                    await refresh()
                }
            }
        }
        .groomerVisitDesignModal(isPresented: $isConfirmingDismissal) {
            .confirmation(title: "Dismiss this match?",
                message: (petName.map { $0 + "’s request" } ?? "This request") + " will be removed from your Matches list. The customer can still choose another groomer.",
                systemImage: "xmark.circle.fill", confirmTitle: "Dismiss match",
                confirmSystemImage: "xmark", confirmIdentifier: "groomer.requests.dismiss.confirm", cancelTitle: "Keep match") {
                guard let matched = subject.matched else { return }
                Task {
                    await requests.dismiss(matched)
                    // The match is gone from the list once it is dismissed: leave its page with it.
                    if !requests.matchedRequests.contains(where: { $0.id == matched.id }) { dismiss() }
                }
            }
        }
    }

    private func detailPage<Blocks: View>(@ViewBuilder _ blocks: @escaping () -> Blocks) -> some View {
        DesignPage(content: blocks)
    }

    // MARK: Blocks

    private func decision(_ subject: GroomerRequestSubject, _ stage: GroomerRequestStage) -> String? {
        if stage.kind == .new, let match = subject.matched { return workspace.matchDecision(match, now: now) }
        if let item = subject.item {
            return workspace.offerDecision(.init(item: item, stage: stage))
        }
        return nil
    }

    @ViewBuilder
    private func needs(_ stage: GroomerRequestStage) -> some View {
        if let hold = stage.hold {
            switch hold {
            case .checking: EmptyView()
            case .species: EmptyView() // Explained in the overview when action is required.
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
    }

    private func offerForm(_ matched: GroomerMatchedRequest, hasEarlierOffer: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: hasEarlierOffer ? "Make a new offer" : "Make an offer", systemImage: "tag.fill")
            let fields = GroomerVisitRequestOfferForm(matched: matched, form: form, focusedTarget: $focusedTarget, startError: startError)
            GroomerVisitCurrentOfferForm(fields: fields)
        }
        .id("request-quote")
        .onChange(of: form.proposedStart) { startError = nil }
        .onChange(of: form.selectedOccurrence) { startError = nil }
        .disabled(!form.didInitializeOfferForm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.requests.offer-form")
    }

    private func sendButton(_ matched: GroomerMatchedRequest, checking: Bool, revealStart: @escaping () -> Void) -> some View {
        Button {
            guard !sending, !checking else { return }
            quoteError = nil
            startError = nil
            focusedTarget = nil
            do {
                offerToConfirm = (try workspace.offerDraft(for: matched, form: form), matched.request)
            } catch let error as GroomerVisitOfferStartError {
                startError = error.localizedDescription
                revealStart()
            } catch { quoteError = error.localizedDescription }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(sending ? "Sending…" : checking ? "Checking…" : "Send offer")
                if sending {
                    ProgressView().tint(DesignTokens.Colors.customerInk)
                } else {
                    Image(systemName: checking ? "clock" : "paperplane.fill").font(DesignTokens.Typography.Expressive.glyph)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(GroomerVisitRequestFooterActionStyle(retainsDisabledColor: sending))
        .disabled(sending || checking || !form.didInitializeOfferForm || form.proposedEnd == nil || form.serviceTimeZone == nil)
        .accessibilityLabel(sending ? "Sending offer" : checking ? "Checking availability" : "Send offer")
        .accessibilityIdentifier("groomer.offers.submit")
    }

    /// The dialog closes itself before this runs. Only the page's existing button owns sending feedback.
    private func sendOffer(_ draft: GroomerOfferDraft, revealStart: @escaping () -> Void) {
        guard !sending else { return }
        sending = true
        Task {
            defer { sending = false }
            do {
                try await workspace.sendOffer(draft)
                if !Task.isCancelled { await refresh() }
            } catch let error as GroomerVisitOfferStartError {
                startError = error.localizedDescription
                revealStart()
            } catch { quoteError = error.localizedDescription }
        }
    }

    // MARK: Helpers



    private func firstPhoto(_ matched: GroomerMatchedRequest) -> Data? {
        requests.requestPhotos(for: matched).first.flatMap { requests.requestPhotoData(for: $0) }
    }

}

struct GroomerVisitRequestDetailLoading: View {
    let subject: GroomerRequestSubject
    let booking: Booking?
    let groomerID: UUID
    let decision: String?

    /// Only the shape is drawn on a cold open. Optional notes wait until a known row supplies them.
    private static let unfilled = GroomerRequestSubject()

    var body: some View {
        let now = Date()
        let shape = subject.request == nil && subject.offer == nil ? Self.unfilled : subject
        DesignPage(cascades: false) {
            GroomerVisitRequestOverview(subject: shape, photo: nil, stage: GroomerRequestStage(shape, now: now), now: now,
                decision: decision, selectedPet: .constant(nil), isPlaceholder: true)
            if let request = shape.request {
                GroomerVisitRequestFacts(request: request, booking: booking, groomerID: groomerID, isPlaceholder: true)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading request")
        .accessibilityIdentifier("groomer.requests.detail.loading")
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }
}
