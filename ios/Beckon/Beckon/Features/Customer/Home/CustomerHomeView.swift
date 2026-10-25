import SwiftUI

struct CustomerHomeView: View {
    private let displayName: String
    private let isActiveTab: Bool
    private let customerProfileRepository: (any CustomerProfileRepository)?
    private let onActiveRequestSelected: (UUID) -> Void
    private let onBookingChatSelected: (Booking) -> Void
    private let chatStore: ChatStore?
    @State private var petStore: CustomerPetsStore
    @State private var requestStore: CustomerRequestsStore
    @State private var bookingStore: BookingsStore
    @State private var notificationStore: CustomerNotificationsStore
    @State private var isShowingNotifications = false

    init(
        customerID: UUID,
        displayName: String? = nil,
        isActiveTab: Bool = true,
        repository: any CustomerPetRepository,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        requestRepository: any CustomerRequestRepository,
        notificationRepository: any CustomerNotificationRepository,
        bookingRepository: any BookingRepository,
        debugRecorder: AppDebugEventRecorder? = nil,
        notificationStore: CustomerNotificationsStore? = nil,
        requestStore: CustomerRequestsStore? = nil,
        chatStore: ChatStore? = nil,
        onActiveRequestSelected: @escaping (UUID) -> Void = { _ in },
        onBookingChatSelected: @escaping (Booking) -> Void = { _ in },
        sessionIsCurrent: @escaping @MainActor () -> Bool = { true }
    ) {
        let trimmedName = displayName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        self.displayName = trimmedName.isEmpty ? "there" : trimmedName
        self.isActiveTab = isActiveTab
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
            initialValue: BookingsStore(
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
            nextDeadline: requestStore.nextDistributionDeadline) {
            await loadHome()
        }
        .accessibilityIdentifier("customer.home")
        .environment(\.beckonCustomerDesign, true)
    }

    private var screenContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                CustomerHomeHeader(
                    displayName: displayName,
                    line: greeting.line,
                    unreadNotificationCount: notificationStore.unreadCount,
                    notificationAction: {
                        isShowingNotifications = true
                    }
                )
                .beckonEntrance(0)

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
                    .beckonEntrance(1)
                }

                CustomerHomeRequestHero(
                    isDisabled: requestHeroPresentation.isStartRequestDisabled,
                    action: startGroomingRequest
                )
                .beckonEntrance(1)
                .beckonScrollEase()

                CustomerRequestPhotoUploadRetryList(store: requestStore)
                    .beckonEntrance(2)

                CustomerHomePetsSection(store: petStore)

                CustomerHomeActiveRequestSection(
                    presentation: activeRequestPresentation,
                    onSelectRequest: onActiveRequestSelected,
                    retry: {
                        Task {
                            await requestStore.load()
                        }
                    }
                )
                .beckonEntrance(5)
                .beckonScrollEase()

                if let message = bookingStore.nearestReadError, bookingStore.nearestBooking != nil {
                    Text(message).font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                CustomerHomeNextBookingSection(
                    presentation: nextBookingPresentation,
                    store: bookingStore,
                    onOpenChat: onBookingChatSelected,
                    retry: {
                        Task {
                            await bookingStore.loadNearest()
                        }
                    }
                )
                .beckonEntrance(6)
                .beckonScrollEase()
            }
            .beckonPageInsets(bottom: DesignTokens.Layout.pageBottomInset * 2)
            .beckonEntranceClock()
        }
            .beckonTracksScroll()
        .scrollContentBackground(.hidden)
    }

    private var requestHeroPresentation: CustomerHomeRequestHeroPresentation {
        CustomerHomeRequestHeroPresentation(
            hasPets: !petStore.pets.isEmpty,
            isRequestStoreBusy: requestStore.isBusy
        )
    }

    private var greeting: CustomerHomeGreetingPresentation {
        let card = requestStore.visibleActionCards.first
        return CustomerHomeGreetingPresentation(
            requestStep: card.flatMap { CustomerRequestSummaryPresentation(card: $0).step },
            offerCount: card?.loadedOfferCount,
            petName: card?.request.petSnapshot.name ?? petStore.pets.first?.name,
            bookingCountdown: bookingStore.nearestBooking.flatMap { BeckonBookingCountdown.label(for: $0) }
        )
    }

    private var activeRequestPresentation: CustomerHomeActiveRequestPresentation {
        CustomerHomeActiveRequestPresentation(
            cards: requestStore.visibleActionCards,
            isLoading: requestStore.isLoading,
            loadErrorMessage: requestStore.errorMessage
        )
    }

    private var nextBooking: Booking? {
        bookingStore.nearestBooking
    }

    private var nextBookingPresentation: CustomerHomeNextBookingPresentation {
        CustomerHomeNextBookingPresentation(
            booking: nextBooking,
            isLoading: bookingStore.nearestReadState == .idle || bookingStore.nearestReadState == .loading,
            loadErrorMessage: bookingStore.nearestReadError
        )
    }

    @MainActor
    private func loadHome() async {
        if !petStore.isShowingPetForm { await petStore.load() }
        await requestStore.load()
        await bookingStore.loadNearest()
        await notificationStore.load()
    }

    private func startGroomingRequest() {
        requestStore.startCreate()
    }

    private var requestWizardPresentationBinding: Binding<Bool> {
        Binding(
            get: {
                CustomerRequestWizardPresentationOwnership.shouldPresent(
                    storeRequested: requestStore.isShowingWizard,
                    isActiveTab: isActiveTab
                )
            },
            set: { isPresented in
                guard isActiveTab else { return }
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

    var isStartRequestDisabled: Bool {
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

    var state: CustomerRequestCollectionState {
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

    var shouldShowBooking: Bool {
        booking != nil
    }

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

    var shouldShowEmptyText: Bool {
        booking == nil && !shouldShowLoading && !shouldShowLoadError
    }

    var shouldShowEmptyCard: Bool {
        false
    }

    var globalErrorPrompt: BeckonGlobalFeedbackError? {
        guard shouldShowLoadError, let loadErrorMessage else {
            return nil
        }
        return BeckonGlobalFeedbackError(
            scope: .page("customer.home"),
            sourceKey: "customer.home.bookings.load",
            title: "Bookings didn't load",
            message: loadErrorMessage
        )
    }
}

/// The one line under the greeting: always names the next step, from the data the modules below show.
struct CustomerHomeGreetingPresentation: Equatable {
    let line: String

    init(requestStep: Int?, offerCount: Int?, petName: String?, bookingCountdown: String?) {
        let subject = petName ?? "Your pet"
        switch (requestStep, bookingCountdown) {
        case (2?, _):
            let pet = petName ?? "your pet"
            line = offerCount.map { "\($0) offer\($0 == 1 ? " is" : "s are") waiting for \(pet)!" }
                ?? "Offers are waiting for \(pet)!"
        case (3?, let when?), (nil, let when?):
            line = "\(subject)'s groom is \(when.lowercased())"
        case (3?, nil):
            line = "\(subject)'s groom is booked!"
        case (1?, _):
            line = "Groomers are looking at your request"
        default:
            line = "Ready for a fresh trim?"
        }
    }
}

private struct CustomerHomeHeader: View {
    let displayName: String
    let line: String
    let unreadNotificationCount: Int
    let notificationAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Hi, \(displayName)!")
                        .font(DesignTokens.Typography.Expressive.display)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    BeckonWaveHand()
                }

                Text(line)
                    .designSupportingText()
                    .id(line)
                    .transition(.push(from: .bottom))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .beckonAnimation(DesignTokens.Motion.swap, value: line)

            BeckonExpressiveNotificationBell(
                unreadCount: unreadNotificationCount,
                accessibilityIdentifier: "customer.home.notifications",
                action: notificationAction
            )
        }
    }
}

private struct CustomerHomeRequestHero: View {
    let isDisabled: Bool
    let action: () -> Void
    @State private var isActionPressed = false

    var body: some View {
        BeckonLedgeHero(isExcited: isActionPressed) {
            Text(CustomerHomeRequestHeroPresentation.title)
                .font(DesignTokens.Typography.Expressive.hero)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(CustomerHomeRequestHeroPresentation.message)
                .font(DesignTokens.Typography.Expressive.body)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                BeckonLedgePrimaryLabel(
                    title: CustomerHomeRequestHeroPresentation.actionTitle,
                    systemImage: "scissors"
                )
            }
            .buttonStyle(BeckonLedgeButtonStyle(.primary) { isActionPressed = $0 })
            .padding(.top, DesignTokens.Spacing.sm)
            .disabled(isDisabled)
            .accessibilityIdentifier("customer.home.start-request")
            .accessibilityLabel(CustomerHomeRequestHeroPresentation.actionTitle)

            if isDisabled {
                Label(
                    "Add a pet profile before starting a grooming request.",
                    systemImage: "pawprint"
                )
                .font(DesignTokens.Typography.status)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("customer.home.start-request.requirement")
            }
        }
    }
}

struct CustomerHomePetsSection: View {
    @Bindable var store: CustomerPetsStore
    @State private var removing: CustomerPet?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Pets", systemImage: "pawprint.fill", count: store.pets.count)
                .beckonEntrance(2)

            if store.isLoading, store.pets.isEmpty {
                BeckonLoadingView(
                    title: "Loading pets…",
                    message: "Fetching your saved pet profiles.",
                    accent: .customer
                )
                .accessibilityIdentifier("customer.pets.loading")
            } else if store.pets.isEmpty {
                DesignPupPeek {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text("Add your first pet")
                            .font(DesignTokens.Typography.Expressive.title)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                        Text("A profile helps groomers match you with the right care.")
                            .designSupportingText()
                        Button { store.startCreate() } label: {
                            DesignActionLabel(title: "Add pet", systemImage: "plus")
                        }
                        .buttonStyle(BeckonLedgeButtonStyle(.pill))
                        .accessibilityIdentifier("customer.pets.add")
                    }
                    .designCardBody()
                }
                .accessibilityIdentifier("customer.pets.list")
            } else if typeSize.isAccessibilitySize {
                // Accessibility sizes reflow the carousel into full-width cards instead of squeezing text.
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    tiles
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .accessibilityIdentifier("customer.pets.list")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                        tiles
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
                // Horizontal carousels cancel the page inset so cards can bleed to the screen edge.
                .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .beckonTracksScroll()
                .accessibilityIdentifier("customer.pets.list")
            }
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
    private var tiles: some View {
        ForEach(Array(store.pets.enumerated()), id: \.element.id) { index, pet in
            CustomerHomePetTile(pet: pet, index: index, store: store) { removing = $0 }
                .beckonEntrance(3 + min(index, 1))
        }

        CustomerHomeAddPetTile {
            store.startCreate()
        }
        .beckonEntrance(3 + min(store.pets.count, 1))
    }
}

private struct CustomerHomePetTile: View {
    let pet: CustomerPet
    let index: Int
    @Bindable var store: CustomerPetsStore
    let onRemove: (CustomerPet) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button {
            store.startEdit(pet)
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                BeckonPortrait(
                    data: store.primaryPhotoData(for: pet),
                    symbol: BeckonPetPresentation.symbol(for: pet.displaySpecies),
                    index: index
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "pencil")
                        .font(DesignTokens.Typography.Expressive.label)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .frame(width: DesignTokens.Metrics.ledgeIconTile, height: DesignTokens.Metrics.ledgeIconTile)
                        .background(DesignTokens.Colors.surface, in: Circle())
                        .overlay(Circle().strokeBorder(DesignTokens.Colors.customerFill, lineWidth: 2))
                        .padding(DesignTokens.Spacing.sm)
                        .accessibilityHidden(true)
                }

                // The card has a fixed size, so long text is truncated here and the full text lives in the editor.
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(pet.name)
                        .font(DesignTokens.Typography.Expressive.title)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)

                    Text(petBreedLine)
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                }

                // Pins the chips to the bottom edge so they line up across cards, with or without a second breed line.
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    if let age = pet.displayAge {
                        BeckonMetaChip(text: age, systemImage: "birthday.cake.fill")
                    }
                    if let weight = pet.displayWeightAndSize {
                        BeckonMetaChip(text: weight, systemImage: "scalemass.fill")
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .homePetCardFrame()
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .beckonCarouselTilt(isEnabled: !typeSize.isAccessibilitySize)
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

    private var petBreedLine: String {
        let breed = pet.displayBreed?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let breed, !breed.isEmpty {
            return breed
        }

        return pet.displaySpecies
    }
}

/// One size for every pet card and the add slot: fixed width and height, so the carousel never changes shape with the data.
/// Height follows Dynamic Type; accessibility sizes reflow to full-width cards that grow with their text instead of clipping.
private struct CustomerHomePetCardFrame: ViewModifier {
    var flexibleMinHeight: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var scaledHeight = DesignTokens.Metrics.petCardHeight

    func body(content: Content) -> some View {
        if typeSize.isAccessibilitySize {
            content.frame(maxWidth: .infinity, minHeight: flexibleMinHeight, alignment: .topLeading)
        } else {
            // Grows with larger text but never drops below the design height: the portrait and spacings do not scale.
            content.frame(width: DesignTokens.Metrics.petCardWidth,
                height: max(scaledHeight, DesignTokens.Metrics.petCardHeight), alignment: .topLeading)
        }
    }
}

private extension View {
    func homePetCardFrame(flexibleMinHeight: CGFloat = 0) -> some View {
        modifier(CustomerHomePetCardFrame(flexibleMinHeight: flexibleMinHeight))
    }
}

private struct CustomerHomeAddPetTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BeckonLedgeAddSlot(title: "Add pet")
                .homePetCardFrame(flexibleMinHeight: 160)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.dashed))
        .accessibilityLabel("Add pet")
        .accessibilityHint("Opens the pet profile form.")
        .accessibilityIdentifier("customer.pets.add")
    }
}

private struct CustomerHomeActiveRequestSection: View {
    let presentation: CustomerHomeActiveRequestPresentation
    let onSelectRequest: (UUID) -> Void
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Active request", systemImage: "paperplane.fill", count: presentation.cards.count)

            switch presentation.state {
            case .loaded:
                CustomerRequestSummaryCarousel(
                    cards: presentation.cards,
                    onSelectRequest: onSelectRequest
                )
                    .accessibilityIdentifier("customer.home.active-request.carousel")

            case .loading:
                BeckonLoadingView(
                    title: "Loading requests…",
                    message: "Checking your active grooming requests.",
                    accent: .customer
                )
                .accessibilityIdentifier("customer.home.active-request.loading")

            case .error(let message):
                CustomerRequestLoadFailureBanner(
                    message: message,
                    accessibilityIdentifier: "customer.home.active-request.error",
                    retry: retry
                )

            case .empty:
                BeckonLedgeNote(systemImage: "paperplane", text: CustomerRequestEmptyCopy.message)
                    .accessibilityIdentifier("customer.home.active-request.empty")
            }
        }
    }
}

private struct CustomerHomeNextBookingSection: View {
    let presentation: CustomerHomeNextBookingPresentation
    let store: BookingsStore
    let onOpenChat: (Booking) -> Void
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Next booking", systemImage: "calendar")

            if presentation.shouldShowLoading {
                BeckonLoadingView(
                    title: "Loading booking…",
                    message: "Checking confirmed appointments.",
                    accent: .customer
                )
                .accessibilityIdentifier("customer.home.next-booking.loading")
            } else if presentation.shouldShowLoadError,
                      let message = presentation.loadErrorMessage {
                BeckonErrorBanner(
                    title: "Bookings didn't load",
                    message: message,
                    systemImage: "calendar.badge.exclamationmark"
                ) {
                    Button("Try again", action: retry)
                        .buttonStyle(
                            BeckonSecondaryButtonStyle(
                                accent: .customer,
                                isFullWidth: false
                            )
                        )
                }
                .accessibilityIdentifier("customer.home.next-booking.error")
            } else if let booking = presentation.booking {
                NavigationLink {
                    BookingDetailView(
                        bookingID: booking.id,
                        role: .customer,
                        store: store,
                        onOpenChat: onOpenChat
                    )
                } label: {
                    BookingCard(booking: booking, role: .customer)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.card))
                .accessibilityIdentifier("customer.home.next-booking.view")
            } else {
                BeckonLedgeNote(
                    systemImage: "calendar",
                    text: "Accepted offers will appear here as upcoming appointments."
                )
                .accessibilityIdentifier("customer.home.next-booking.empty")
            }
        }
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
    init(sandbox: CustomerSandboxSession, isActiveTab: Bool = true,
         onSelectRequest: @escaping (UUID) -> Void, onOpenChat: @escaping (Booking) -> Void = { _ in }) {
        displayName = sandbox.accountRepository.details.nickname
        self.isActiveTab = isActiveTab
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
