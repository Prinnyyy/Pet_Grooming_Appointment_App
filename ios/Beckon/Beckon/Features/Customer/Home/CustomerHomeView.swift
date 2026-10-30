import SwiftUI


struct CustomerHomeView: View {
    @Environment(\.customerRequestFlowHosted) private var requestFlowHosted
    private let displayName: String
    private let isActiveTab: Bool
    @Binding private var addPetRequested: Bool
    private let customerProfileRepository: (any CustomerProfileRepository)?
    private let onActiveRequestSelected: (UUID) -> Void
    private let onBookingChatSelected: (Booking) -> Void
    private let chatStore: ChatStore?
    @State private var petStore: CustomerPetsStore
    @State private var requestStore: CustomerRequestsStore
    @State private var bookingStore: BookingsStore
    @State private var notificationStore: CustomerNotificationsStore
    @State private var isShowingNotifications = false
    /// Each store has finished its first load (design). Until then a place shows its own shape in bars, never an empty state.
    private var petsSettled: Bool { petStore.hasLoadedOnce || !petStore.pets.isEmpty }
    private var requestsSettled: Bool { requestStore.hasLoadedOnce || !requestStore.requests.isEmpty }
    private var bookingSettled: Bool { bookingStore.hasLoadedOnce || !bookingStore.bookings.isEmpty }
    /// Start Grooming Request was tapped with no pet yet: a dialog asks to add one first (design).
    @State private var isAskingForPet = false
    /// Where the page is scrolled (design): the scene's layers and the header read it; the page itself does not.
    @State private var scrollDepth = BeckonScrollDepth()
    /// The page is pulled far enough that letting go refreshes it.
    @State private var isPullArmed = false
    @State private var didHapticForPull = false
    @State private var refreshTask: Task<Void, Never>?

    init(
        customerID: UUID,
        displayName: String? = nil,
        isActiveTab: Bool = true,
        addPetRequested: Binding<Bool> = .constant(false),
        repository: any CustomerPetRepository,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        requestRepository: any CustomerRequestRepository,
        notificationRepository: any CustomerNotificationRepository,
        bookingRepository: any BookingRepository,
        debugRecorder: AppDebugEventRecorder? = nil,
        notificationStore: CustomerNotificationsStore? = nil,
        requestStore: CustomerRequestsStore? = nil,
        chatStore: ChatStore? = nil,
        bookingsStore: BookingsStore? = nil,
        onActiveRequestSelected: @escaping (UUID) -> Void = { _ in },
        onBookingChatSelected: @escaping (Booking) -> Void = { _ in },
        sessionIsCurrent: @escaping @MainActor () -> Bool = { true }
    ) {
        let trimmedName = displayName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        self.displayName = trimmedName.isEmpty ? "there" : trimmedName
        self.isActiveTab = isActiveTab
        _addPetRequested = addPetRequested
        self.customerProfileRepository = customerProfileRepository
        self.onActiveRequestSelected = onActiveRequestSelected
        self.onBookingChatSelected = onBookingChatSelected
        self.chatStore = chatStore
        _petStore = State(
            initialValue: CustomerPetsStore(
                customerID: customerID,
                repository: repository,
                debugRecorder: debugRecorder,
                sessionIsCurrent: sessionIsCurrent
            )
        )
        _requestStore = State(
            initialValue: requestStore ?? CustomerRequestsStore(
                customerID: customerID,
                petRepository: repository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository,
                debugRecorder: debugRecorder
            )
        )
        _bookingStore = State(
            initialValue: bookingsStore ?? BookingsStore(
                participantID: customerID,
                role: .customer,
                repository: bookingRepository,
                debugRecorder: debugRecorder
            )
        )
        _notificationStore = State(
            initialValue: notificationStore ?? CustomerNotificationsStore(
                customerID: customerID,
                repository: notificationRepository
            )
        )
    }

    var body: some View {
        @Bindable var petStore = petStore
        @Bindable var requestStore = requestStore

        ZStack {
            BeckonExpressiveBackdrop()

            screenContent
        }
        .toolbar(.hidden, for: .navigationBar)
        .background {
            CustomerHomeStatusView(
                petStore: petStore,
                requestStore: requestStore,
                nextBookingPresentation: nextBookingPresentation
            )
        }
        .sheet(isPresented: $petStore.isShowingPetForm) {
            CustomerPetFormView(store: petStore)
        }
        .onChange(of: petStore.pets) { _, currentPets in
            requestStore.synchronizePets(currentPets)
        }
        // A request is for a pet, so with none the button asks first and Add pet opens the same form as the Pets row's last cell.
        .designAlertDialog(isPresented: $isAskingForPet) {
            .addPetFirst(confirmIdentifier: "customer.home.start-request.add-pet") { petStore.startCreate() }
        }
        // Another tab (Grooming's New Request) asked for the Pet form: this is the page that owns it.
        .onChange(of: addPetRequested, initial: true) { _, requested in
            guard requested else { return }
            addPetRequested = false
            petStore.startCreate()
        }
        .sheet(isPresented: requestWizardPresentationBinding) {
            CustomerRequestWizardView(
                store: requestStore,
                customerProfileRepository: customerProfileRepository
            ) {
                requestStore.cancelWizard()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    petStore.startCreate()
                }
            }
        }
        .navigationDestination(isPresented: $isShowingNotifications) {
            CustomerNotificationsView(store: notificationStore, requestStore: requestStore,
                bookingStore: bookingStore, chatStore: chatStore)
        }
        .foregroundRefreshable(isEnabled: isActiveTab && !requestStore.isShowingWizard && requestStore.discoveryFlow == nil,
            nextDeadline: GroomingFeed.nextTransition(bookings: bookingStore.bookings, requestDeadline: requestStore.nextDistributionDeadline)) {
            await loadHome()
        }
        .accessibilityIdentifier("customer.home")
        .environment(\.beckonCustomerDesign, true)
        .onDisappear { refreshTask?.cancel(); refreshTask = nil; scrollDepth.isRefreshing = false }
    }

    private var screenContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                CustomerHomeTop(
                    displayName: displayName,
                    isHeroLoading: !petsSettled,
                    depth: scrollDepth,
                    unreadNotificationCount: notificationStore.unreadCount,
                    notificationAction: {
                        isShowingNotifications = true
                    },
                    startAction: startGroomingRequest
                )

                if petStore.hasPendingCreation || petStore.hasCreationRecoveryError {
                    Button { petStore.startCreate() } label: {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            DesignIconDisc(systemImage: "arrow.clockwise", font: DesignTokens.Typography.Expressive.glyph)
                            Text("Finish saving your pet")
                                .font(DesignTokens.Typography.Expressive.emphasis)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(DesignTokens.Spacing.md)
                    }
                    .buttonStyle(BeckonLedgeButtonStyle(.card))
                    .accessibilityLabel("Confirm pending pet")
                    .accessibilityIdentifier("customer.pets.resume-create")
                    .beckonEntrance(2)
                }

                GroomingPhotoUploadRetryList(store: requestStore)
                    .beckonEntrance(2)

                CustomerHomePetsSection(store: petStore, isSettled: petsSettled)

                CustomerHomeNextUpSection(
                    entries: nextUpEntries,
                    isSettled: requestsSettled && bookingSettled,
                    requests: activeRequestPresentation,
                    booking: nextBookingPresentation,
                    staleBookingNote: nextBooking == nil ? nil : bookingStore.errorMessage,
                    onSelect: onActiveRequestSelected,
                    retryRequests: {
                        Task {
                            await requestStore.load()
                        }
                    },
                    retryBookings: {
                        Task {
                            await bookingStore.load()
                        }
                    }
                )
                .beckonEntrance(5)
                .beckonScrollEase()
            }
            .beckonPageInsets(bottom: DesignTokens.Layout.pageBottomInset * 2)
            .beckonEntranceClock()
        }
            .beckonTracksScroll()
        .scrollContentBackground(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrollDepth.offset = offset
            let armed = -offset >= BeckonScrollDepth.armedPull
            if armed != isPullArmed { isPullArmed = armed }
            if armed, !scrollDepth.isRefreshing, !didHapticForPull { didHapticForPull = true }
        }
        // Pull down and let go: refresh the page (the same load as coming back to the app). Nothing is drawn for it, neither a
        // spinner nor a mark in the scene: what changed changes in place (design).
        .onScrollPhaseChange { old, new in
            if new == .interacting { didHapticForPull = false }
            guard old == .interacting, new != .interacting, isPullArmed, isActiveTab, !scrollDepth.isRefreshing else { return }
            refreshByPull()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: didHapticForPull) { _, armed in armed }
    }

    private func refreshByPull() {
        scrollDepth.isRefreshing = true
        refreshTask = Task {
            let started = ProcessInfo.processInfo.systemUptime
            await loadHome()
            // Another pull has to wait a moment, however quick the answer was.
            let rest = DesignTokens.Motion.pullRefreshMinimum - (ProcessInfo.processInfo.systemUptime - started)
            if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
            if !Task.isCancelled { scrollDepth.isRefreshing = false }
        }
    }

    private var requestHeroPresentation: CustomerHomeRequestHeroPresentation {
        CustomerHomeRequestHeroPresentation(
            hasPets: !petStore.pets.isEmpty,
            isRequestStoreBusy: requestStore.isBusy
        )
    }

    private var activeRequestPresentation: CustomerHomeActiveRequestPresentation {
        CustomerHomeActiveRequestPresentation(
            cards: requestStore.visibleActionCards,
            isLoading: !requestsSettled && requestStore.isLoading,
            loadErrorMessage: requestStore.errorMessage
        )
    }

    private var nextBooking: Booking? {
        bookingStore.bookings.filter { $0.status == .confirmed && !GroomingLifecycle.isFinished($0) }
            .sorted { $0.scheduledStart < $1.scheduledStart }.first
    }

    /// Home and Grooming use the same current request/booking projection.
    private var nextUpEntries: [GroomingEntry] {
        GroomingFeed.activeEntries(cards: requestStore.visibleActionCards, bookings: bookingStore.bookings,
            avatar: { requestStore.primaryPetPhotoData(petID: $0) })
    }

    private var nextBookingPresentation: CustomerHomeNextBookingPresentation {
        CustomerHomeNextBookingPresentation(
            booking: nextBooking,
            isLoading: !bookingSettled && bookingStore.isLoading,
            loadErrorMessage: bookingStore.errorMessage
        )
    }

    @MainActor
    private func loadHome() async {
        if !petStore.isShowingPetForm { await petStore.load() }
        await requestStore.load()
        await bookingStore.load()
        await notificationStore.load()
    }

    private func startGroomingRequest() {
        if requestHeroPresentation.needsPetFirst {
            isAskingForPet = true
        } else {
            requestStore.startCreate()
        }
    }

    private var requestWizardPresentationBinding: Binding<Bool> {
        Binding(
            get: {
                CustomerRequestWizardPresentationOwnership.shouldPresent(
                    storeRequested: requestStore.isShowingWizard,
                    isActiveTab: isActiveTab && !requestFlowHosted
                )
            },
            set: { isPresented in
                guard isActiveTab, !requestFlowHosted else { return }
                requestStore.setWizardPresentation(isPresented)
            }
        )
    }
}


struct CustomerHomeRequestHeroPresentation: Equatable {
    static let title = "Need grooming for your pet?"
    static let message = "Create one request and compare offers from available groomers."
    static let actionTitle = "Start Grooming Request"

    let hasPets: Bool
    let isRequestStoreBusy: Bool

    /// The button is always offered; with no pet it asks to add one before it starts a request.
    var needsPetFirst: Bool {
        !hasPets
    }
}


struct CustomerHomeActiveRequestPresentation: Equatable {
    let cards: [CustomerRequestActionCardItem]
    let isLoading: Bool
    let loadErrorMessage: String?

    init(
        cards: [CustomerRequestActionCardItem],
        isLoading: Bool,
        loadErrorMessage: String? = nil
    ) {
        self.cards = cards
        self.isLoading = isLoading
        self.loadErrorMessage = loadErrorMessage
    }

    var state: GroomingCollectionState {
        if !cards.isEmpty {
            return .loaded
        }
        if isLoading {
            return .loading
        }
        if let message = loadErrorMessage?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !message.isEmpty {
            return .error(message)
        }
        return .empty
    }
}


struct CustomerHomeNextBookingPresentation: Equatable {
    let booking: Booking?
    let isLoading: Bool
    let loadErrorMessage: String?

    init(
        booking: Booking?,
        isLoading: Bool,
        loadErrorMessage: String? = nil
    ) {
        self.booking = booking
        self.isLoading = isLoading
        self.loadErrorMessage = loadErrorMessage
    }

    var shouldShowBooking: Bool { booking != nil }
    var shouldShowEmptyText: Bool { booking == nil && !shouldShowLoading && !shouldShowLoadError }
    var shouldShowEmptyCard: Bool { false }

    var shouldShowLoading: Bool {
        booking == nil && isLoading
    }

    var shouldShowLoadError: Bool {
        booking == nil
            && !isLoading
            && !(loadErrorMessage?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty ?? true)
    }

    var globalErrorPrompt: BeckonGlobalFeedbackError? {
        guard shouldShowLoadError, let loadErrorMessage else {
            return nil
        }
        return BeckonGlobalFeedbackError(
            scope: .page("customer.home"),
            sourceKey: "customer.home.bookings.load",
            title: "Grooming didn't load",
            message: loadErrorMessage
        )
    }
}


/// The top of Home (design, design): the title with the bell on one row, like the other tabs, then the request card straight under it.
/// Nothing is written under the title; the room above the card is the pup's. Behind all of it stands the scene (sky, clouds,
/// mountains, lawn). While the page is pulled down the title and the bell stay where they are and the card goes down with the
/// page, so the scene opens up between them.
private struct CustomerHomeTop: View {
    let displayName: String
    var isHeroLoading = false
    let depth: BeckonScrollDepth
    let unreadNotificationCount: Int
    let notificationAction: () -> Void
    let startAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CustomerHomeHeader(
                displayName: displayName,
                unreadNotificationCount: unreadNotificationCount,
                notificationAction: notificationAction
            )
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .beckonEntrance(0)
            .beckonStaysWhilePulled(depth)
            // The scene stands behind the hero and reaches up behind the title, so the title is drawn above it.
            .zIndex(1)

            CustomerHomeRequestHero(
                isLoading: isHeroLoading,
                action: startAction
            )
            .beckonEntrance(1)
            .beckonScrollEase()
            .background(alignment: .top) {
                BeckonHomeScene(depth: depth)
                    .padding(.horizontal, -DesignTokens.Layout.pageHorizontalInset)
                    .offset(y: -BeckonHomeScene.headroom)
            }
        }
    }
}


private struct CustomerHomeHeader: View {
    let displayName: String
    let unreadNotificationCount: Int
    let notificationAction: () -> Void
    /// One size above `Expressive.display` (design): the greeting is the only text of the top, so it carries it; it still follows the
    /// text size setting (up to the largest ordinary size) and shrinks before it wraps.
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = DesignTokens.Metrics.homeTitleSize

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Text("Hi, \(displayName)!")
                .font(DesignTokens.Typography.Expressive.homeGreeting(size: titleSize))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Metrics.homeTitleMinimumScale)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            BeckonExpressiveNotificationBell(
                unreadCount: unreadNotificationCount,
                accessibilityIdentifier: "customer.home.notifications",
                action: notificationAction
            )
        }
    }
}


private struct CustomerHomeRequestHero: View {
    /// The pets are not known yet (design): the card says nothing, as bars, its button is a bar (it depends on the pets, so it is not
    /// offered before they are known), and the pup is not there; when the words arrive the pup comes up from behind the card.
    var isLoading = false
    let action: () -> Void
    @State private var isActionPressed = false
    @State private var isRevealed: Bool

    init(isLoading: Bool = false, action: @escaping () -> Void) {
        self.isLoading = isLoading
        self.action = action
        _isRevealed = State(initialValue: !isLoading)
    }

    var body: some View {
        BeckonLedgeHero(isExcited: isActionPressed, isPupHidden: !isRevealed) {
            DesignReveal(isLoading: isLoading, onReveal: { isRevealed = true }) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    words
                    startButton
                }
            } placeholder: {
                bars
            }
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(CustomerHomeRequestHeroPresentation.title)
                .font(DesignTokens.Typography.Expressive.hero)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(CustomerHomeRequestHeroPresentation.message)
                .font(DesignTokens.Typography.Expressive.body)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var startButton: some View {
        Button(action: action) {
            BeckonLedgePrimaryLabel(
                title: CustomerHomeRequestHeroPresentation.actionTitle,
                systemImage: "scissors"
            )
        }
        .buttonStyle(BeckonLedgeButtonStyle(.primary) { isActionPressed = $0 })
        .padding(.top, DesignTokens.Spacing.sm)
        .accessibilityIdentifier("customer.home.start-request")
        .accessibilityLabel(CustomerHomeRequestHeroPresentation.actionTitle)
    }

    /// The same room as the words and the button: a headline of two lines, a text of two lines, the button as a block.
    private var bars: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                DesignSkeletonLine(width: 0.82, font: DesignTokens.Typography.Expressive.hero)
                DesignSkeletonLine(width: 0.58, font: DesignTokens.Typography.Expressive.hero)
            }
            VStack(alignment: .leading, spacing: 0) {
                DesignSkeletonLine(width: 0.96, font: DesignTokens.Typography.Expressive.body)
                DesignSkeletonLine(width: 0.6, font: DesignTokens.Typography.Expressive.body)
            }
            DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.ledgeButton)
                .frame(height: DesignTokens.Metrics.ledgePrimaryButtonHeight)
                .padding(.top, DesignTokens.Spacing.sm)
        }
        .designSkeleton(label: "Loading")
    }
}


struct CustomerHomePetsSection: View {
    @Bindable var store: CustomerPetsStore
    /// False while the first load is out: the row shows pet cards as bars (design).
    var isSettled = true
    @State private var removing: CustomerPet?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            DesignReveal(isLoading: !isSettled) {
                BeckonLedgeHeading(title: "Pets", systemImage: "pawprint.fill", count: store.pets.count)
            } placeholder: {
                DesignSkeletonHeading()
            }
            .beckonEntrance(2)

            DesignReveal(isLoading: !isSettled) {
                petsContent
            } placeholder: {
                petsPlaceholder
            }
            .beckonEntrance(3)
        }
        // Removing a pet has no restore (no snackbar to offer), so it asks first.
        .designAlertDialog(item: $removing) { pet in
            .destructive(title: "Remove \(pet.name)?",
                message: "\(pet.name) will leave your pets. You can add \(pet.name) again later, but this can't be undone.",
                systemImage: "pawprint.fill", keepTitle: "Keep \(pet.name)", confirmTitle: "Remove",
                confirmIdentifier: "customer.pets.confirm-remove") {
                Task { await store.softDelete(pet) }
            }
        }
    }

    @ViewBuilder
    private var petsContent: some View {
        // With no pet the row is the same row with only its last cell, the dashed Add pet card, at the width of a pet card (design).
        if typeSize.isAccessibilitySize {
            // Accessibility sizes reflow the carousel into full-width cards instead of squeezing text.
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                tiles(width: 0)
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .accessibilityIdentifier("customer.pets.list")
        } else {
            BeckonPeekCarousel(wholeCards: 2) { width in tiles(width: width) }
            .accessibilityIdentifier("customer.pets.list")
        }
    }

    /// The row while the pets are on their way: the cards in the size they will have, as bars, the third peeking in.
    @ViewBuilder
    private var petsPlaceholder: some View {
        if typeSize.isAccessibilitySize {
            CustomerHomePetTileSkeleton(width: 0)
                .padding(.vertical, DesignTokens.Spacing.sm)
        } else {
            BeckonPeekCarousel(wholeCards: 2) { width in
                CustomerHomePetTileSkeleton(width: width)
                CustomerHomePetTileSkeleton(width: width)
                CustomerHomePetTileSkeleton(width: width)
            }
            .scrollDisabled(true)
        }
    }

    /// `width` is the carousel's card width; accessibility sizes stack full-width cards and ignore it.
    @ViewBuilder
    private func tiles(width: CGFloat) -> some View {
        ForEach(Array(store.pets.enumerated()), id: \.element.id) { index, pet in
            CustomerHomePetTile(pet: pet, index: index, store: store, width: width) { removing = $0 }
        }

        CustomerHomeAddPetTile(width: width) {
            store.startCreate()
        }
    }
}


/// A pet card as bars: the head, the name and breed, the two facts; the same frame as the card, so the card takes its place.
private struct CustomerHomePetTileSkeleton: View {
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DesignSkeletonBlock(cornerRadius: 0)
                .frame(height: 112)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    DesignSkeletonLine(width: 0.7, font: DesignTokens.Typography.Expressive.title)
                    DesignSkeletonLine(width: 0.55)
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    DesignSkeletonLine(width: 0.4, font: DesignTokens.Typography.Expressive.label)
                    DesignSkeletonLine(width: 0.34, font: DesignTokens.Typography.Expressive.label)
                }
                Spacer(minLength: 0)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .designSkeleton(label: "Loading your pets")
        .homePetCardFrame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .beckonLedge(.card)
    }
}


private struct CustomerHomePetTile: View {
    let pet: CustomerPet
    let index: Int
    @Bindable var store: CustomerPetsStore
    let width: CGFloat
    let onRemove: (CustomerPet) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button {
            store.startEdit(pet)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                portrait

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // The card has a fixed size, so long text is truncated here and the full text lives in the editor.
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(pet.name)
                            .font(DesignTokens.Typography.Expressive.title)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)

                        Text(petBreedLine)
                            .font(DesignTokens.Typography.Expressive.supporting)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    }

                    // Age and weight, one to a line in one type size: nothing is shrunk to fit, so a 12-year-old and a 100 lb dog
                    // read as well as a puppy.
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        ForEach(facts, id: \.self) { CustomerHomePetFactRow(fact: $0) }
                    }

                    // A pet without an age or weight leaves its room at the bottom, so the names still line up across the cards.
                    Spacer(minLength: 0)
                }
                .padding(DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .homePetCardFrame(width: width)
            // The head runs edge to edge, so the card's own corners clip it (the face's border is drawn over this).
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pet.name)
        .accessibilityValue(pet.accessibilitySummary)
        .accessibilityHint("Opens pet profile for editing.")
        .contextMenu {
            Button("Edit") {
                store.startEdit(pet)
            }

            Button("Remove", role: .destructive) {
                onRemove(pet)
            }
        }
        .accessibilityIdentifier("customer.pets.card")
    }

    /// The card's head: the photo (or the artwork) edge to edge. No edit button on it: the whole card opens the editor.
    private var portrait: some View {
        BeckonPortrait(
            data: store.primaryPhotoData(for: pet),
            symbol: BeckonPetPresentation.symbol(for: pet.displaySpecies),
            index: index,
            clipsToShape: false
        )
    }

    private var petBreedLine: String {
        let breed = pet.displayBreed?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let breed, !breed.isEmpty {
            return breed
        }

        return pet.displaySpecies
    }

    /// Age and weight, the two numbers an owner glances at; a fact the profile does not have is not shown.
    private var facts: [CustomerHomePetFact] {
        var result: [CustomerHomePetFact] = []
        if let age = pet.displayAge {
            result.append(.init(systemImage: "birthday.cake.fill", value: Self.shortAge(age)))
        }
        if let weight = pet.weightLbs, weight.isFinite, weight > 0 {
            result.append(.init(systemImage: "scalemass.fill", value: "\(weight.formatted(.number.precision(.fractionLength(0...1)))) lb"))
        }
        return result
    }

    /// "4 years old" becomes "4 years": the symbol says it is the age.
    private static func shortAge(_ age: String) -> String {
        age.replacingOccurrences(of: " old", with: "")
    }
}


private struct CustomerHomePetFact: Hashable {
    let systemImage: String
    let value: String
}


/// One fact of the pet card: its symbol and its text, one line, one size for every fact and every pet.
private struct CustomerHomePetFactRow: View {
    let fact: CustomerHomePetFact

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: fact.systemImage)
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(width: DesignTokens.Spacing.lg)
                .accessibilityHidden(true)
            Text(fact.value)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}


/// One size for every pet card and the add slot, whatever the data: the width comes from the row (two cards and the start of the
/// third), the height is fixed. Height follows Dynamic Type; accessibility sizes reflow to full-width cards that grow with their
/// text instead of clipping.
private struct CustomerHomePetCardFrame: ViewModifier {
    let width: CGFloat
    var flexibleMinHeight: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var scaledHeight = DesignTokens.Metrics.petCardHeight

    func body(content: Content) -> some View {
        if typeSize.isAccessibilitySize {
            content.frame(maxWidth: .infinity, minHeight: flexibleMinHeight, alignment: .topLeading)
        } else {
            // Grows with larger text but never drops below the design height: the portrait and spacings do not scale.
            content.frame(width: width,
                height: max(scaledHeight, DesignTokens.Metrics.petCardHeight), alignment: .topLeading)
        }
    }
}


private extension View {
    func homePetCardFrame(width: CGFloat, flexibleMinHeight: CGFloat = 0) -> some View {
        modifier(CustomerHomePetCardFrame(width: width, flexibleMinHeight: flexibleMinHeight))
    }
}


private struct CustomerHomeAddPetTile: View {
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BeckonLedgeAddSlot(title: "Add pet")
                .homePetCardFrame(width: width, flexibleMinHeight: 160)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.dashed))
        .accessibilityLabel("Add pet")
        .accessibilityHint("Opens the pet profile form.")
        .accessibilityIdentifier("customer.pets.add")
    }
}


/// Home's one module for what is in progress (S-057): the requests and the next booking were two modules (Active request, Next
/// booking) while the Grooming tab already holds them as one. Same cards, glance size, same order, no page dots (the next card
/// peeking in says it swipes). A tap opens the Grooming tab on that card, where the button and the menu live. Everything the two
/// modules said when something was wrong is kept: loading, requests that failed (Try again), bookings that failed (Try again), a
/// stale note when the booking could not refresh, and the empty line.
private struct CustomerHomeNextUpSection: View {
    let entries: [GroomingEntry]
    /// False while the first load of the requests or the booking is out: one card as bars (design).
    let isSettled: Bool
    let requests: CustomerHomeActiveRequestPresentation
    let booking: CustomerHomeNextBookingPresentation
    let staleBookingNote: String?
    let onSelect: (UUID) -> Void
    let retryRequests: () -> Void
    let retryBookings: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            DesignReveal(isLoading: !isSettled) {
                BeckonLedgeHeading(title: "Next up", systemImage: "sparkles", count: entries.count)
            } placeholder: {
                DesignSkeletonHeading()
            }

            DesignReveal(isLoading: !isSettled) {
                loadedContent
            } placeholder: {
                GroomingCardSkeleton(style: .glance)
                    .accessibilityIdentifier("customer.home.next-up.loading")
            }
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            if !entries.isEmpty {
                row
                if let staleBookingNote {
                    Text(staleBookingNote)
                        .font(DesignTokens.Typography.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            } else {
                if case .error(let message) = requests.state {
                    GroomingLoadFailureBanner(
                        message: message,
                        accessibilityIdentifier: "customer.home.next-up.requests-error",
                        retry: retryRequests
                    )
                }
                if booking.shouldShowLoadError, let message = booking.loadErrorMessage {
                    BeckonErrorBanner(
                        title: "Grooming didn't load",
                        message: message,
                        systemImage: "calendar.badge.exclamationmark"
                    ) {
                        Button("Try again", action: retryBookings)
                            .buttonStyle(
                                BeckonSecondaryButtonStyle(
                                    accent: .customer,
                                    isFullWidth: false
                                )
                            )
                    }
                    .accessibilityIdentifier("customer.home.next-up.bookings-error")
                }
                if requests.state == .empty, !booking.shouldShowLoadError {
                    BeckonLedgeNote(systemImage: "sparkles", text: GroomingEmptyCopy.message)
                        .accessibilityIdentifier("customer.home.next-up.empty")
                }
            }
        }
    }

    @ViewBuilder
    private var row: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                ForEach(entries) { card($0) }
            }
        } else if entries.count > 1 {
            BeckonPeekCarousel(wholeCards: 1) { width in
                ForEach(entries) { entry in
                    card(entry).frame(width: width)
                }
            }
            .accessibilityIdentifier("customer.home.next-up.carousel")
        } else if let entry = entries.first {
            card(entry)
        }
    }

    private func card(_ entry: GroomingEntry) -> some View {
        GroomingCard(content: .entry(entry), style: .glance, onOpen: { onSelect(entry.id) })
    }
}


private struct CustomerHomeStatusView: View {
    let petStore: CustomerPetsStore
    let requestStore: CustomerRequestsStore
    let nextBookingPresentation: CustomerHomeNextBookingPresentation

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            CustomerPetsStatusView(store: petStore)
            CustomerRequestsStatusView(store: requestStore)

            if let errorPrompt = nextBookingPresentation.globalErrorPrompt {
                BeckonGlobalFeedbackForwarder(error: errorPrompt)
            }
        }
    }
}

#if DEBUG
extension CustomerHomeView {
    init(sandbox: CustomerSandboxSession, isActiveTab: Bool = true, addPetRequested: Binding<Bool> = .constant(false),
         onSelectRequest: @escaping (UUID) -> Void, onOpenChat: @escaping (Booking) -> Void = { _ in }) {
        displayName = sandbox.accountRepository.details.nickname
        self.isActiveTab = isActiveTab
        _addPetRequested = addPetRequested
        customerProfileRepository = sandbox.accountRepository
        onActiveRequestSelected = onSelectRequest
        onBookingChatSelected = onOpenChat
        chatStore = sandbox.chat
        _petStore = State(initialValue: sandbox.pets.store)
        _requestStore = State(initialValue: sandbox.requests)
        _bookingStore = State(initialValue: sandbox.bookings)
        _notificationStore = State(initialValue: sandbox.notifications)
    }

    init(previewSession: CustomerHomeFlowSandboxSession, onSelectRequest: @escaping (UUID) -> Void) {
        displayName = "Lian"
        isActiveTab = true
        _addPetRequested = .constant(false)
        customerProfileRepository = nil
        onActiveRequestSelected = onSelectRequest
        onBookingChatSelected = { _ in previewSession.pets.feedbackCenter.showError(
            .init(scope: .page("customer.home"), sourceKey: "home.preview.chat",
                title: "Chat unavailable", message: "Messaging is not connected in this local preview.")) }
        chatStore = nil
        _petStore = State(initialValue: previewSession.pets.store)
        _requestStore = State(initialValue: previewSession.requests)
        _bookingStore = State(initialValue: previewSession.bookings)
        _notificationStore = State(initialValue: previewSession.notifications)
    }
}

#Preview("Customer Home") {
    CustomerHomeFlowSandbox()
}

@MainActor
final class CustomerPetsPreviewRepository: CustomerPetRepository {
    let customerID: UUID
    var mutationDelay: Duration = .milliseconds(450)
    var failsNextSave = false
    var isActive = true
    var sandboxBoundary: CustomerSandboxBoundary?
    private(set) var storedPets: [CustomerPet]
    private var storedPhotos: [CustomerPetPhoto] = []
    private var photoBytes: [UUID: Data] = [:]
    private var creations: [UUID: (draft: CustomerPetDraft, pet: CustomerPet)] = [:]

    init(customerID: UUID = UUID()) {
        self.customerID = customerID
        let petID = UUID()
        storedPets = [
            CustomerPet(
                id: petID,
                customerID: customerID,
                name: "Mochi",
                species: "Dog",
                breed: "Shiba Inu",
                coatType: nil,
                size: "M",
                weightLbs: 22,
                birthday: "2022-03-10",
                temperament: "Friendly",
                medicalNotes: nil,
                groomingNotes: "Sensitive paws",
                isActive: true,
                revision: UUID()
            ),
            CustomerPet(
                id: UUID(),
                customerID: customerID,
                name: "Biscuit",
                species: "Dog",
                breed: "Pomeranian",
                coatType: nil,
                size: "S",
                weightLbs: 12,
                birthday: "2023-05-14",
                temperament: "Playful",
                medicalNotes: nil,
                groomingNotes: nil,
                isActive: true,
                revision: UUID()
            ),
        ]
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        try await sandboxBoundary?.check()
        try requireOwner(customerID)
        return storedPets
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        try await sandboxBoundary?.check()
        try requireOwner(customerID)
        return storedPhotos
    }

    func createPet(
        customerID: UUID,
        operationID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPetSaveResult {
        try requireOwner(customerID)
        try await prepareSave()
        if let previous = creations[operationID] {
            guard previous.draft == draft else { throw CustomerPetRepositoryError.operationIntentChanged }
            let current = storedPets.first { $0.id == previous.pet.id }
            return .init(petID: previous.pet.id, resultRevision: previous.pet.revision!,
                replayed: true, state: current == nil ? .unavailable : .active, pet: current)
        }
        let pet = makePet(id: UUID(), draft: draft)
        storedPets.insert(pet, at: 0)
        creations[operationID] = (draft, pet)
        return .init(petID: pet.id, resultRevision: pet.revision!, replayed: false, state: .active, pet: pet)
    }

    func updatePet(
        petID: UUID,
        expectedRevision: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        try await prepareSave()
        guard let index = storedPets.firstIndex(where: { $0.id == petID }) else {
            throw CustomerPetRepositoryError.petNotFound
        }
        guard storedPets[index].revision == expectedRevision else {
            throw CustomerPetRepositoryError.revisionConflict
        }
        let pet = makePet(id: petID, draft: draft)
        storedPets[index] = pet
        return pet
    }

    private func makePet(id: UUID, draft: CustomerPetDraft) -> CustomerPet {
        CustomerPet(
            id: id,
            customerID: customerID,
            name: draft.name,
            species: draft.species,
            breed: draft.breed,
            coatType: draft.coatType,
            size: draft.size,
            weightLbs: draft.weightLbs,
            birthday: draft.birthday,
            temperament: draft.temperament,
            medicalNotes: draft.medicalNotes,
            groomingNotes: draft.groomingNotes,
            isActive: true,
            coatTypeSource: draft.coatTypeConfirmed ? "explicit" : "legacy_unverified",
            mattingConfirmed: draft.mattingConfirmed,
            revision: UUID()
        )
    }

    func softDeletePet(_ pet: CustomerPet) async throws {
        try requireOwner(pet.customerID)
        guard let current = storedPets.first(where: { $0.id == pet.id }) else {
            throw CustomerPetRepositoryError.petNotFound
        }
        guard current.revision == pet.revision else { throw CustomerPetRepositoryError.revisionConflict }
        storedPets.removeAll { $0.id == pet.id }
        for photo in storedPhotos where photo.petID == pet.id { photoBytes[photo.id] = nil }
        storedPhotos.removeAll { $0.petID == pet.id }
    }

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        try requireOwner(customerID)
        guard storedPets.contains(where: { $0.id == petID }) else {
            throw CustomerPetRepositoryError.petNotFound
        }
        let photo = CustomerPetPhoto(
            id: UUID(),
            petID: petID,
            customerID: customerID,
            storageBucket: "pet-photos",
            storagePath: CustomerPetPhotoPath.make(
                customerID: customerID,
                petID: petID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: storedPhotos.filter { $0.petID == petID }.count,
            isPrimary: !storedPhotos.contains { $0.petID == petID }
        )
        storedPhotos.append(photo)
        photoBytes[photo.id] = data
        return photo
    }

    func photoData(_ photo: CustomerPetPhoto) async throws -> Data {
        try requireOwner(photo.customerID)
        guard let bytes = photoBytes[photo.id] else { throw CustomerPetRepositoryError.unavailable }
        return bytes
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {
        try requireOwner(photo.customerID)
        storedPhotos.removeAll { $0.id == photo.id }
        photoBytes[photo.id] = nil
    }

    private func requireOwner(_ id: UUID) throws {
        guard isActive, !Task.isCancelled else { throw CustomerPetRepositoryError.cancelled }
        guard id == customerID else { throw CustomerPetRepositoryError.notAllowed }
    }

    private func prepareSave() async throws {
        try requireOwner(customerID)
        try await Task.sleep(for: mutationDelay)
        try requireOwner(customerID)
        if failsNextSave {
            failsNextSave = false
            throw CustomerPetRepositoryError.networkUnavailable
        }
    }

    func configureSandbox(state: CustomerSandboxState, boundary: CustomerSandboxBoundary) {
        sandboxBoundary = boundary
        storedPets = state == .empty ? [] : [CustomerSandboxFixtures.pet(longNames: state == .longNames), CustomerSandboxFixtures.pet(1)]
        if state == .photos {
            let photo = CustomerPetPhoto(id: CustomerSandboxFixtures.id(91), petID: CustomerSandboxFixtures.id(10),
                customerID: customerID, storageBucket: "sandbox", storagePath: "fixture.png", caption: nil, sortOrder: 0, isPrimary: true)
            storedPhotos = [photo]; photoBytes[photo.id] = CustomerSandboxFixtures.imageData
        }
    }
}

@MainActor
final class CustomerHomePreviewRequestRepository: CustomerRequestRepository {
    private(set) var storedRequests: [CustomerGroomingRequest]

    init(pet: CustomerPet, now: Date = Date()) {
        storedRequests = [CustomerGroomingRequest(
            id: UUID(), customerID: pet.customerID, petID: pet.id,
            petSnapshot: GroomingRequestPetSnapshot(id: pet.id, name: pet.name, species: pet.species,
                breed: pet.breed, coatType: pet.coatType, size: pet.size, weightLbs: pet.weightLbs,
                birthday: pet.birthday, temperament: pet.temperament, medicalNotes: pet.medicalNotes,
                groomingNotes: pet.groomingNotes, snapshotAt: now.ISO8601Format()),
            photoSnapshot: [], serviceType: .fullGroom, serviceNotes: "Trim and brush out. Please be gentle around the paws.",
            preferredStart: now.addingTimeInterval(3 * 86400).ISO8601Format(),
            preferredEnd: now.addingTimeInterval(3 * 86400 + 7200).ISO8601Format(),
            locationMode: .groomerComesToCustomer, streetAddress: "123 Pine Street",
            city: "Seattle", state: "WA", zipCode: "98101", travelRadiusMiles: nil,
            status: .open, expiresAt: now.addingTimeInterval(2 * 86400).ISO8601Format(),
            createdAt: now.ISO8601Format(), updatedAt: now.ISO8601Format(),
            preferenceTimeZoneIdentifier: "America/Los_Angeles", termsRevision: UUID())]
    }

    /// Preview-only: moves the fixture request through its stages so Home can be inspected in each one.
    func setPreviewStatus(_ status: GroomingRequestStatus) {
        guard !storedRequests.isEmpty else { return }
        storedRequests[0] = storedRequests[0].replacing(status: status, updatedAt: Date().ISO8601Format())
    }

    func rankedOffers(customerID: UUID, requestID: UUID, page: RankedPageRequest<CustomerOfferSort>) async throws -> RankedPage<CustomerOfferReview> {
        let now = Date()
        let values = try await offers(customerID: customerID, requestID: requestID)
        return RankedPage(items: values, rankingRevision: "preview", scoreAsOf: now,
            validUntil: now.addingTimeInterval(300), algorithmVersion: "matching-v1",
            requestedMode: page.mode.rawValue, effectiveMode: page.mode.rawValue,
            pendingCount: values.count, assessmentCount: 0, nextCursor: nil)
    }
    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        storedRequests.filter { $0.customerID == customerID }
    }

    func request(customerID: UUID, requestID: UUID) async throws -> CustomerGroomingRequest {
        guard let request = storedRequests.first(where: { $0.id == requestID && $0.customerID == customerID }) else {
            throw CustomerRequestRepositoryError.requestNotFound
        }
        return request
    }

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview] {
        guard let request = storedRequests.first(where: { $0.id == requestID && $0.customerID == customerID }),
              request.status == .hasOffers else { return [] }
        return CustomerSandboxFixtures.offers(for: request)
    }

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult {
        // Home previews do not simulate publication or claim a successful transaction.
        throw CustomerRequestRepositoryError.unavailable
    }

    func uploadRequestPhoto(
        customerID: UUID,
        requestID: UUID,
        data: Data,
        contentType: GroomingRequestPhotoContentType,
        caption: String?
    ) async throws -> GroomingRequestPhoto {
        GroomingRequestPhoto(
            id: UUID(),
            requestID: requestID,
            customerID: customerID,
            storageBucket: "request-photos",
            storagePath: GroomingRequestPhotoPath.make(
                customerID: customerID,
                requestID: requestID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: 0,
            createdAt: "2026-06-20T14:00:00Z"
        )
    }

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult {
        guard let index = storedRequests.firstIndex(where: { $0.id == requestID }) else {
            throw CustomerRequestRepositoryError.requestNotFound
        }
        let timestamp = Date().ISO8601Format()
        storedRequests[index] = storedRequests[index].replacing(status: .cancelled, updatedAt: timestamp)
        return CancelGroomingRequestResult(
            requestID: requestID,
            requestStatus: .cancelled,
            cancelledTimestamp: timestamp
        )
    }
}

@MainActor
final class CustomerHomePreviewNotificationRepository: CustomerNotificationRepository {
    private var items: [CustomerNotification]

    init(request: CustomerGroomingRequest, booking: Booking) {
        items = [
            CustomerNotification(id: UUID(), customerID: request.customerID, kind: .requestPublished,
                title: "Your grooming request is live", body: "Your request for \(request.petSnapshot.name) is ready for groomers.",
                isRead: false, createdAt: request.createdAt, readAt: nil,
                relatedRequestID: request.id, relatedBookingID: nil, relatedOfferID: nil),
            CustomerNotification(id: UUID(), customerID: booking.customerID, kind: .bookingConfirmed,
                title: "Your appointment is confirmed", body: "View the details of your upcoming appointment.",
                isRead: false, createdAt: booking.createdAt, readAt: nil,
                relatedRequestID: booking.requestID, relatedBookingID: booking.id, relatedOfferID: nil),
        ]
    }

    func notifications(customerID: UUID) async throws -> [CustomerNotification] {
        items.filter { $0.customerID == customerID }
    }

    func markRead(notificationID: UUID) async throws -> CustomerNotification {
        guard let index = items.firstIndex(where: { $0.id == notificationID }) else {
            throw CustomerNotificationRepositoryError.notificationNotFound
        }
        items[index] = items[index].replacingReadState(isRead: true, readAt: Date().ISO8601Format())
        return items[index]
    }

    func markAllRead(customerID: UUID) async throws -> [CustomerNotification] {
        items = items.map { $0.customerID == customerID
            ? $0.replacingReadState(isRead: true, readAt: Date().ISO8601Format()) : $0 }
        return items.filter { $0.customerID == customerID }
    }
}

@MainActor
final class CustomerHomePreviewBookingRepository: BookingRepository {
    let sample: Booking

    init(pet: CustomerPet, requestID: UUID = UUID(), now: Date = Date()) {
        sample = Booking(id: UUID(), requestID: requestID, offerID: UUID(), customerID: pet.customerID,
            groomerID: UUID(), scheduledStart: now.addingTimeInterval(86400).ISO8601Format(),
            scheduledEnd: now.addingTimeInterval(86400 + 5400).ISO8601Format(), priceEstimate: 120,
            status: .confirmed, cancelledBy: nil, cancelledAt: nil, completedAt: nil, completedBy: nil,
            createdAt: now.ISO8601Format(), updatedAt: now.ISO8601Format(), review: nil,
            serviceType: .fullGroom,
            requestPetSnapshot: GroomingRequestPetSnapshot(id: pet.id, name: pet.name, species: pet.species,
                breed: pet.breed, coatType: pet.coatType, size: pet.size, weightLbs: pet.weightLbs,
                birthday: pet.birthday, temperament: pet.temperament, medicalNotes: pet.medicalNotes,
                groomingNotes: pet.groomingNotes, snapshotAt: now.ISO8601Format()),
            groomerBusinessName: "Pine Street Grooming", locationMode: .groomerComesToCustomer,
            customerStreetAddress: "123 Pine Street", customerCity: "Seattle", customerState: "WA",
            customerZipCode: "98101", serviceTimeZoneIdentifier: "America/Los_Angeles")
    }

    func nearestBooking(participantID: UUID, role: UserRole, now: Date) async throws -> Booking? {
        guard participantID == sample.customerID, role == .customer,
              let start = GroomingRequestDateFormatting.parsedDate(from: sample.scheduledStart), start > now else { return nil }
        return sample
    }

    func bookings(bookingIDs: [UUID]) async throws -> [Booking] {
        bookingIDs.contains(sample.id) ? [sample] : []
    }

    func fulfillmentEvents(bookingID: UUID) async throws -> [BookingFulfillmentEvent] {
        guard bookingID == sample.id else { throw BookingRepositoryError.bookingNotFound }
        return []
    }

    func reschedule(bookingID: UUID) async throws -> BookingRescheduleResult {
        guard bookingID == sample.id else { throw BookingRepositoryError.bookingNotFound }
        return .init(booking: sample, proposal: nil, receipt: nil)
    }

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        participantID == sample.customerID && role == .customer ? [sample] : []
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        throw BookingRepositoryError.unavailable
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        throw BookingRepositoryError.unavailable
    }
}
#endif
