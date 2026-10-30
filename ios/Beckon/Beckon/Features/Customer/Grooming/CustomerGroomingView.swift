// The Grooming tab (S-056; the old Requests tab's page again in S-058). The Requests tab and the Bookings tab as one, with the
// Requests tab's architecture: a header, a row of cards that swipe (the next peeking in, dots that follow the finger), a History
// row under it. A booking is not a new kind of card: it is the request card with the path lit up further (Booked, Groomed,
// Reviewed). Every function of both old tabs is here: the card opens the request or the booking, the filled button does the next
// step, Details and the quiet action under it do the rest; the wizard, the groomer picker, the photo retries, the reminder notice,
// load more and pull to refresh are the same ones. What is in progress is `GroomingFeed`, the same list Home's Next up
// row shows; what is over is on the History page.
import SwiftUI


struct CustomerGroomingView: View {
    @Environment(\.customerRequestFlowHosted) private var requestFlowHosted
    @State private var requestStore: CustomerRequestsStore
    @State private var bookingsStore: BookingsStore
    @Binding private var focusedRequestID: UUID?
    private let customerProfileRepository: (any CustomerProfileRepository)?
    /// False while another tab is showing: the request wizard is one shared sheet, and only the tab on screen presents it (S-041).
    private let isActiveTab: Bool
    private let onOpenChat: (Booking) -> Void
    /// Opens the Pet form, which Home owns: the tab view takes the person there (design).
    private let onAddPet: () -> Void
    /// New Request was tapped with no pet yet: the same dialog as Home's Start Grooming Request asks to add one first.
    @State private var isAskingForPet = false
    @State private var carouselPosition: UUID?
    @State private var destination: GroomingDestination?
    @State private var pendingCancelRequest: CustomerGroomingRequest?
    /// The requests and the bookings have each finished their first load (design): until then the page is its own shape in bars.
    private var requestsSettled: Bool { requestStore.hasLoadedOnce || !requestStore.requests.isEmpty }
    private var bookingsSettled: Bool { bookingsStore.hasLoadedOnce || !bookingsStore.bookings.isEmpty }
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        requestStore: CustomerRequestsStore,
        bookingsStore: BookingsStore,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        isActiveTab: Bool = true,
        focusedRequestID: Binding<UUID?> = .constant(nil),
        onOpenChat: @escaping (Booking) -> Void = { _ in },
        onAddPet: @escaping () -> Void = {}
    ) {
        _requestStore = State(initialValue: requestStore)
        _bookingsStore = State(initialValue: bookingsStore)
        _focusedRequestID = focusedRequestID
        self.customerProfileRepository = customerProfileRepository
        self.isActiveTab = isActiveTab
        self.onOpenChat = onOpenChat
        self.onAddPet = onAddPet
    }

    #if DEBUG
    init(sandbox: CustomerSandboxSession, isActiveTab: Bool = true, focusedRequestID: Binding<UUID?> = .constant(nil),
         onOpenChat: @escaping (Booking) -> Void = { _ in }, onAddPet: @escaping () -> Void = {}) {
        self.init(requestStore: sandbox.requests, bookingsStore: sandbox.bookings,
            customerProfileRepository: sandbox.accountRepository, isActiveTab: isActiveTab,
            focusedRequestID: focusedRequestID, onOpenChat: onOpenChat, onAddPet: onAddPet)
    }
    #endif

    private var isSettled: Bool { requestsSettled && bookingsSettled }

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                    GroomingHeader(
                        isLoading: !isSettled,
                        needsPet: requestStore.pets.isEmpty,
                        createRequest: startNewRequest
                    )
                    .beckonEntrance(0)

                    if let message = bookingsStore.appointmentReminderNotice {
                        GroomingReminderNotice(message: message)
                            .accessibilityIdentifier("bookings.appointment-reminder-notice")
                            .beckonEntrance(1)
                    }

                    listContent
                    loadMore
                }
                .beckonPageInsets()
                .beckonEntranceClock()
            }
            .beckonTracksScroll()
            .scrollContentBackground(.hidden)
            .refreshable {
                await requestStore.load()
                await bookingsStore.load()
            }
            .accessibilityIdentifier("customer.grooming.list")
            .onAppear(perform: showFocused)
            .onChange(of: focusedRequestID) { _, _ in showFocused() }
            .onChange(of: activeEntries.map(\.id)) { _, _ in showFocused() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background {
            CustomerRequestsStatusView(store: requestStore)
            BookingsStatusView(store: bookingsStore, role: .customer, presentation: bookingsFeedback)
        }
        .designAlertDialog(isPresented: $isAskingForPet) {
            .addPetFirst(confirmIdentifier: "customer.requests.create.add-pet", addPet: { onAddPet() })
        }
        .designAlertDialog(item: $pendingCancelRequest) { request in
            .destructive(title: "Cancel this request?",
                message: "This closes the request and any pending offers. A confirmed booking is cancelled from its own page.",
                systemImage: "xmark.circle.fill", keepTitle: "Keep Request", confirmTitle: "Cancel request",
                confirmSystemImage: "xmark.circle") { Task { await requestStore.cancel(request) } }
        }
        .sheet(isPresented: wizardPresentationBinding) {
            CustomerRequestWizardView(store: requestStore, customerProfileRepository: customerProfileRepository)
        }
        .sheet(item: Binding(get: { requestFlowHosted || requestStore.isShowingWizard ? nil : requestStore.discoveryFlow },
                             set: { requestStore.discoveryFlow = $0 })) { flow in
            if let marketplace = requestStore.marketplace {
                NavigationStack { CustomerGroomerDiscoveryView(flow: flow, requests: requestStore, marketplace: marketplace) }
                    .presentationDragIndicator(.visible)
                    .foregroundRefreshable(nextDeadline: marketplace.distribution.nextDeadline(requestIDs: flow.requestID.map { [$0] } ?? [])) {
                        if let id = flow.requestID { await requestStore.refreshDistributionProgress(requestIDs: [id]) }
                    }
            }
        }
        .groomingDestinations($destination, requestStore: requestStore, bookingsStore: bookingsStore, onOpenChat: onOpenChat)
    }

    /// New Request: the form, or, with no pet to ask for grooming, the question that leads to the Pet form.
    private func startNewRequest() {
        if requestStore.pets.isEmpty {
            isAskingForPet = true
        } else {
            requestStore.startCreate()
        }
    }

    // MARK: Page

    @ViewBuilder
    private var listContent: some View {
        // Until the first load is over the page is one card as bars; its errors, retries and cards take that place, in the same
        // place, so nothing above them moves. History does not wait for anything, so it is there from the first frame.
        DesignReveal(isLoading: !isSettled) {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                if case .error(let message) = GroomingCollectionPresentation(activeCardCount: activeEntries.count,
                    closedRequestCount: requestStore.requests.count + bookingsStore.bookings.count,
                    photoRetryCount: requestStore.requestPhotoUploadRetries.count, isLoading: false,
                    loadErrorMessage: requestStore.errorMessage).state {
                    GroomingLoadFailureBanner(message: message) { Task { await requestStore.load() } }
                }
                if let error = bookingsFeedback.persistentLoadError {
                    BeckonPersistentErrorView(error) {
                        Button {
                            Task { await bookingsStore.load() }
                        } label: {
                            Text(error.actionTitle ?? "Try again")
                                .font(DesignTokens.Typography.Expressive.emphasis)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .padding(.horizontal, DesignTokens.Spacing.lg)
                                .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                        }
                        .buttonStyle(BeckonLedgeButtonStyle(.card))
                    }
                    .accessibilityIdentifier("bookings.persistent-error")
                }
                GroomingPhotoUploadRetryList(store: requestStore)
                activeSection
            }
        } placeholder: {
            GroomingCardSkeleton(style: .full)
                .accessibilityIdentifier("customer.grooming.loading")
        }
        .beckonEntrance(2)

        DesignReveal(isLoading: !isSettled) {
            historyRow
        } placeholder: {
            GroomingHistoryRowSkeleton()
        }
        .beckonEntrance(3)
    }

    /// What is in progress: a row of cards to swipe, the next one peeking in, dots that follow the finger. One card (or large text)
    /// is a card at the width of the page.
    @ViewBuilder
    private var activeSection: some View {
        let entries = activeEntries
        if entries.isEmpty {
            emptyState.accessibilityIdentifier("customer.grooming.empty")
        } else if entries.count == 1 || typeSize.isAccessibilitySize {
            VStack(spacing: DesignTokens.Spacing.lg) {
                ForEach(entries) { card(for: $0).id($0.id) }
            }
        } else {
            BeckonPeekCarousel(wholeCards: 1, pageCount: entries.count,
                pageLabel: { "Grooming \($0 + 1) of \(entries.count)" }, scrollPosition: $carouselPosition) { width in
                ForEach(entries) { entry in
                    card(for: entry)
                        .frame(width: width)
                        .id(entry.id)
                }
            }
            .accessibilityIdentifier("customer.grooming.carousel")
        }
    }

    /// What is over is one tap away, as the Requests tab had it: closed requests and finished bookings on the History page.
    private var historyRow: some View {
        CustomerNavigationLink(route: .history) {
            GroomingHistoryView(requestStore: requestStore, bookingsStore: bookingsStore, onOpenChat: onOpenChat)
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                DesignIconDisc(systemImage: "clock.arrow.circlepath", font: DesignTokens.Typography.Expressive.glyph)
                Text("History")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(DesignTokens.Spacing.md)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .accessibilityIdentifier("customer.grooming.history")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("No active grooming")
                .font(DesignTokens.Typography.Expressive.title)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Text("Open requests and confirmed bookings will appear here.")
                .designSupportingText()
        }
        .designCardBody()
    }

    /// Either list can have another page: one button loads whichever has one.
    @ViewBuilder
    private var loadMore: some View {
        let canLoad = requestStore.canLoadMoreRequests || bookingsStore.canLoadMore
        let isLoading = requestStore.isLoadingMoreRequests || bookingsStore.isLoadingMore
        if canLoad || isLoading {
            BeckonLoadMoreButton(isLoading: isLoading, accent: .customer,
                accessibilityIdentifier: "customer.grooming.load-more") {
                if requestStore.canLoadMoreRequests { await requestStore.loadNextRequestsPage() }
                if bookingsStore.canLoadMore { await bookingsStore.loadNextPage() }
            }
        }
    }

    // MARK: Cards

    @ViewBuilder
    private func card(for entry: GroomingEntry) -> some View {
        switch entry {
        case .request(let item):
            requestCard(item)
        case .booking(let booking, let handoff, let avatar):
            bookingCard(booking, handoff: handoff, avatar: avatar)
        }
    }

    private func requestCard(_ item: CustomerRequestActionCardItem) -> some View {
        let request = item.request
        let isCancelling = requestStore.isCancelling(request)
        return GroomingCard(
            content: .request(item, reach: reachLine(for: request)),
            secondary: GroomingQuietAction(id: "cancel", title: isCancelling ? "Cancelling" : "Cancel request",
                systemImage: isCancelling ? "hourglass" : "xmark.circle", isDestructive: true,
                isDisabled: !request.status.isOpenForOffers || isCancelling) { pendingCancelRequest = request },
            onOpen: { destination = .request(request.id) },
            onPrimary: { performPrimary(for: request) }
        )
    }

    /// The next step: compare the offers there are, or invite groomers to get some.
    private func performPrimary(for request: CustomerGroomingRequest) {
        if request.status == .hasOffers {
            destination = .offers(request.id)
        } else if requestStore.marketplace != nil {
            requestStore.browseGroomers(for: request)
        } else {
            destination = .request(request.id)
        }
    }

    private func bookingCard(_ booking: Booking, handoff: CustomerRequestBookingHandoff?, avatar: Data?) -> some View {
        let content = GroomingCardContent.booking(booking, avatar: avatar, isNew: handoff != nil, request: handoff?.request)
        return GroomingCard(
            content: content,
            // A finished booking asks for its review and nothing else; Details and Message are on the page the card opens.
            secondary: content.hasQuietActions ? GroomingQuietAction(id: "message", title: "Message", systemImage: "message") {
                onOpenChat(booking)
            } : nil,
            onOpen: { open(booking, handoff: handoff) },
            onPrimary: { open(booking, handoff: handoff) }
        )
    }

    private func reachLine(for request: CustomerGroomingRequest) -> String? {
        guard request.status.isOpenForOffers, let marketplace = requestStore.marketplace else { return nil }
        return CustomerRequestReachLine.text(requestID: request.id, store: marketplace.distribution)
    }

    /// A just-booked offer is acknowledged when its booking is opened, as the old "View booking" did.
    private func open(_ booking: Booking, handoff: CustomerRequestBookingHandoff?) {
        if let handoff {
            destination = .handoff(handoff)
            Task { await requestStore.acknowledgeBookingHandoff(for: handoff) }
        } else {
            destination = .booking(booking.id)
        }
    }

    // MARK: Data

    private var bookingsFeedback: BookingsFeedbackPresentation {
        BookingsFeedbackPresentation(role: .customer, bookings: bookingsStore.bookings,
            isLoading: bookingsStore.isLoading, errorMessage: bookingsStore.errorMessage)
    }

    private var wizardPresentationBinding: Binding<Bool> {
        Binding(
            get: { CustomerRequestWizardPresentationOwnership.shouldPresent(storeRequested: requestStore.isShowingWizard, isActiveTab: isActiveTab && !requestFlowHosted) },
            set: { isPresented in
                guard isActiveTab, !requestFlowHosted else { return }
                requestStore.setWizardPresentation(isPresented)
            }
        )
    }

    /// A card asked for from Home or a notification: the row brings it to the front.
    private func showFocused() {
        guard let id = focusedRequestID, activeEntries.contains(where: { $0.id == id }) else { return }
        withAnimation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap) { carouselPosition = id }
        focusedRequestID = nil
    }

    private var activeEntries: [GroomingEntry] {
        GroomingFeed.activeEntries(cards: requestStore.visibleActionCards, bookings: bookingsStore.bookings,
            avatar: { requestStore.primaryPetPhotoData(petID: $0) })
    }
}


/// The page title and New Request (the same pill the Requests tab had). Nothing under the title: a line there would change the height
/// the button is centred on (design).
private struct GroomingHeader: View {
    /// New Request needs the pets, so until the first load is over it is a bar the size of the button.
    var isLoading = false
    /// No pet yet: the button is still there, and asks to add one first.
    let needsPet: Bool
    let createRequest: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                createSlot
            }
            // The row of a tab's title has one height on every tab (design).
            .frame(minHeight: DesignTokens.Metrics.tabTitleRowHeight)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                titleBlock
                createSlot
            }
        }
    }

    private var titleBlock: some View {
        Text("Grooming")
            .font(DesignTokens.Typography.Expressive.display)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    /// New Request depends on the pets, so until the first load is over it is a block the exact size of the button (the button itself,
    /// hidden, gives the size), and the button takes its place.
    private var createSlot: some View {
        DesignReveal(isLoading: isLoading) {
            createButton
        } placeholder: {
            createButton.hidden()
                .overlay {
                    DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.ledgeButton)
                        .designSkeletonOnPage()
                        .designSkeleton(label: nil)
                }
        }
    }

    private var createButton: some View {
        Button(action: createRequest) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "plus").font(DesignTokens.Typography.Expressive.glyph)
                Text("New Request").font(DesignTokens.Typography.Expressive.emphasis)
            }
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .accessibilityIdentifier("customer.requests.create")
        .accessibilityHint(needsPet ? "Asks you to add a pet profile first." : "Opens the grooming request form.")
    }
}
