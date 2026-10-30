import SwiftUI

struct CustomerTabView: View {
    @Environment(\.appDebugEventRecorder) private var debugRecorder
    let customerID: UUID?
    let customerDisplayName: String?
    let customerProfileRepository: (any CustomerProfileRepository)?
    let petRepository: (any CustomerPetRepository)?
    let requestRepository: (any CustomerRequestRepository)?
    let notificationRepository: (any CustomerNotificationRepository)?
    let bookingRepository: (any BookingRepository)?
    let chatRepository: (any ChatRepository)?
    let accountContent: AnyView?
    let acceptanceSessionIsCurrent: @MainActor () -> Bool
    @State private var navigation = CustomerNavigation()
    @State private var reminderScheduler = AppointmentReminderScheduler.shared
    private var selection: CustomerTab { navigation.selection }
    /// Grooming's New Request, with no pet, asked for the Pet form; Home owns it (design).
    @State private var addPetRequested = false
    @State private var notificationStore: CustomerNotificationsStore?
    @State private var chatStore: ChatStore?
    @State private var requestStore: CustomerRequestsStore?
    @State private var bookingsStore: BookingsStore?
    @State private var marketplace: CustomerMarketplaceSession?
    @State private var feedbackCenter = BeckonFeedbackCenter()
    #if DEBUG
    private var sandbox: CustomerSandboxSession?

    init(sandbox: CustomerSandboxSession, initialTab: CustomerTab = .home, navigation: CustomerNavigation? = nil) {
        let navigation = navigation ?? CustomerNavigation()
        navigation.selection = initialTab
        _navigation = State(initialValue: navigation)
        self.sandbox = sandbox
        customerID = CustomerSandboxFixtures.customerID
        customerDisplayName = sandbox.accountRepository.details.nickname
        customerProfileRepository = sandbox.accountRepository
        petRepository = sandbox.pets.repository
        requestRepository = sandbox.marketplaceRepository
        notificationRepository = sandbox.notificationRepository
        bookingRepository = sandbox.bookingRepository
        chatRepository = sandbox.chatRepository
        accountContent = AnyView(CustomerAccountView(sandbox: sandbox))
        acceptanceSessionIsCurrent = { sandbox.boundary.isActive }
        _notificationStore = State(initialValue: sandbox.notifications)
        _chatStore = State(initialValue: sandbox.chat)
        _requestStore = State(initialValue: sandbox.requests)
        _bookingsStore = State(initialValue: sandbox.bookings)
        _marketplace = State(initialValue: sandbox.marketplace)
        _feedbackCenter = State(initialValue: sandbox.feedback)
    }
    #endif

    init(
        customerID: UUID? = nil,
        customerDisplayName: String? = nil,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        petRepository: (any CustomerPetRepository)? = nil,
        requestRepository: (any CustomerRequestRepository)? = nil,
        notificationRepository: (any CustomerNotificationRepository)? = nil,
        bookingRepository: (any BookingRepository)? = nil,
        chatRepository: (any ChatRepository)? = nil,
        accountContent: AnyView? = nil,
        marketplaceServices: CustomerMarketplaceServices? = nil,
        acceptanceSessionIsCurrent: @escaping @MainActor () -> Bool = { true }
    ) {
        self.customerID = customerID
        self.customerDisplayName = customerDisplayName
        self.customerProfileRepository = customerProfileRepository
        self.petRepository = petRepository
        self.requestRepository = requestRepository
        self.notificationRepository = notificationRepository
        self.bookingRepository = bookingRepository
        self.chatRepository = chatRepository
        self.accountContent = accountContent
        self.acceptanceSessionIsCurrent = acceptanceSessionIsCurrent
        _notificationStore = State(
            initialValue: Self.makeNotificationStore(
                customerID: customerID,
                repository: notificationRepository
            )
        )
        _chatStore = State(
            initialValue: Self.makeChatStore(
                customerID: customerID,
                repository: chatRepository,
                bookingRepository: bookingRepository
            )
        )
        let sharedBookingsStore: BookingsStore? = if let customerID, let bookingRepository {
            BookingsStore(participantID: customerID, role: .customer, repository: bookingRepository,
                sessionIsCurrent: acceptanceSessionIsCurrent)
        } else { nil }
        _bookingsStore = State(initialValue: sharedBookingsStore)
        let marketplace: CustomerMarketplaceSession? = if let customerID, let requestRepository, let marketplaceServices {
            .init(customerID: customerID, requestRepository: requestRepository, services: marketplaceServices,
                sessionIsCurrent: acceptanceSessionIsCurrent)
        } else { nil }
        _marketplace = State(initialValue: marketplace)
        let sharedRequestsStore = Self.makeRequestStore(
                customerID: customerID,
                petRepository: petRepository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository,
                bookingsStore: sharedBookingsStore,
                marketplace: marketplace
            )
        sharedRequestsStore?.setAcceptanceSessionValidation(acceptanceSessionIsCurrent)
        _requestStore = State(initialValue: sharedRequestsStore)
    }

    var body: some View {
        tabs
        .modifier(CustomerRequestFlowPresenter(store: requestStore, profileRepository: customerProfileRepository,
            onAddPet: openPetForm, onPublished: {
                navigation.showGrooming($0)
                openReminderIfPossible()
            }))
        .tint(DesignTokens.Colors.customerDeep)
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .toolbarBackground(DesignTokens.Colors.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environment(\.beckonFeedbackCenter, feedbackCenter)
        .environment(\.beckonCustomerDesign, true)
        .environment(\.openBookingChat, openBookingChat)
        .environment(\.bookingConfirmed, confirmBooking)
        .environment(\.customerGroomingRequestStore, requestStore)
        .environment(\.customerNavigation, navigation)
        .environment(\.customerMarketplaceSession, marketplace)
        .overlay(alignment: .bottom) {
            BeckonGlobalFeedbackOverlay(center: feedbackCenter)
        }
        .onAppear {
            marketplace?.requestOptions = { [weak requestStore] in requestStore?.activeRequests ?? [] }
            marketplace?.refreshRequestOptions = { [weak requestStore] in
                await requestStore?.load()
                return requestStore?.errorMessage
            }
            marketplace?.createRequest = { [weak requestStore] in
                navigation.showGrooming(nil)
                requestStore?.startCreate()
            }
            feedbackCenter.setDebugRecorder(debugRecorder)
            chatStore?.setDebugRecorder(debugRecorder)
            requestStore?.setDebugRecorder(debugRecorder)
            requestStore?.setAcceptanceSessionValidation(acceptanceSessionIsCurrent)
            if let notificationStore {
                requestStore?.setNotificationRefresh { [weak notificationStore] in
                    await notificationStore?.load()
                }
            }
        }
        .task {
            await refreshBadgeSources()
        }
        .onDisappear {
            if !acceptanceSessionIsCurrent() { marketplace?.clearSession() }
        }
        .onChange(of: selection) { oldValue, newValue in
            debugRecorder?.record(
                level: .info,
                category: .navigation,
                source: "CustomerTabView.selection",
                scope: "customer.\(newValue.debugKey)",
                message: "\(oldValue.debugKey) -> \(newValue.debugKey)",
                metadata: [
                    "from": "customer.\(oldValue.debugKey)",
                    "to": "customer.\(newValue.debugKey)",
                ]
            )
        }
        .onChange(of: reminderScheduler.tap?.id, initial: true) { _, _ in openReminderIfPossible() }
        .onChange(of: requestStore?.isShowingWizard) { _, _ in openReminderIfPossible() }
        .onChange(of: requestStore?.discoveryFlow?.id) { _, _ in openReminderIfPossible() }
        .accessibilityIdentifier("customer.tabs")
    }

    private var tabs: some View {
        TabView(selection: Binding(get: { navigation.selection }, set: { navigation.selection = $0 })) {
            ForEach(CustomerTab.allCases) { tab in
                navigationRoot(for: tab)
                .beckonEntranceActive(selection == tab)
                .foregroundRefreshable(
                    isEnabled: tab == .requests && selection == .requests
                        && requestStore?.isShowingWizard == false && requestStore?.discoveryFlow == nil,
                    nextDeadline: tab == .requests ? GroomingFeed.nextTransition(bookings: bookingsStore?.bookings ?? [], requestDeadline: requestStore?.nextDistributionDeadline) : nil,
                    fallbackAction: {
                        guard let requestStore else { return }
                        if requestStore.marketplace != nil {
                            await requestStore.refreshDistributionProgress(requestIDs: requestStore.activeRequests.map(\.id))
                        } else {
                            await requestStore.load()
                        }
                    }
                ) {
                    await requestStore?.load()
                    await bookingsStore?.load()
                }
                .tabItem {
                    Label { Text(tab.title) } icon: { BeckonTabIcons.image(tab.icon, isSelected: selection == tab) }
                        .accessibilityIdentifier(tab.accessibilityIdentifier)
                }
                .background(BeckonTabBadgeAppearance(accent: .customer))
                .badge(
                    BeckonBadgeLabel.text(for: tab.badgeCount(
                        unreadNotificationCount: notificationUnreadCount,
                        unreadMessageCount: messageUnreadCount
                    ))
                )
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func destination(for tab: CustomerTab) -> some View {
        #if DEBUG
        if let sandbox, tab == .home {
            CustomerHomeView(sandbox: sandbox, isActiveTab: selection == .home, addPetRequested: $addPetRequested, onSelectRequest: { id in
                showRequest(id)
            }, onOpenChat: openBookingChat)
        } else if let sandbox, tab == .bookings {
            BookingsView(sandbox: sandbox, isActiveTab: selection == .bookings, onOpenChat: openBookingChat)
        } else {
            standardDestination(for: tab)
        }
        #else
        standardDestination(for: tab)
        #endif
    }

    @ViewBuilder
    private func standardDestination(for tab: CustomerTab) -> some View {
        if tab == .home,
           let customerID,
           let petRepository,
           let requestRepository,
           let notificationRepository,
           let bookingRepository {
            CustomerHomeView(
                customerID: customerID,
                displayName: customerDisplayName,
                isActiveTab: selection == .home,
                addPetRequested: $addPetRequested,
                repository: petRepository,
                customerProfileRepository: customerProfileRepository,
                requestRepository: requestRepository,
                notificationRepository: notificationRepository,
                bookingRepository: bookingRepository,
                debugRecorder: debugRecorder,
                notificationStore: notificationStore,
                requestStore: requestStore,
                chatStore: chatStore,
                bookingsStore: bookingsStore,
                onActiveRequestSelected: { requestID in
                    showRequest(requestID)
                },
                onBookingChatSelected: openBookingChat,
                sessionIsCurrent: acceptanceSessionIsCurrent
            )
        } else if tab == .requests, let requestStore, let bookingsStore {
            CustomerGroomingView(
                requestStore: requestStore,
                bookingsStore: bookingsStore,
                customerProfileRepository: customerProfileRepository,
                isActiveTab: selection == .requests,
                focusedRequestID: Binding(get: { navigation.focusedGroomingID }, set: { navigation.focusedGroomingID = $0 }),
                onOpenChat: openBookingChat,
                onAddPet: openPetForm
            )
        } else if tab == .messages,
                  let customerID,
                  let chatRepository,
                  let bookingRepository {
            ChatConversationsView(
                participantID: customerID,
                role: .customer,
                repository: chatRepository,
                bookingRepository: bookingRepository,
                debugRecorder: debugRecorder,
                store: chatStore
            )
        } else if tab == .account, let accountContent {
            accountContent
        } else {
            FeaturePlaceholderView(
                title: tab.title,
                message: "Customer \(tab.title.lowercased()) is not connected yet.",
                systemImage: tab.systemImage,
                accent: .customer
            )
        }
    }

    /// Home keeps its editor and store identity while the shell removes the old page path.
    private func openPetForm() {
        navigation.showHome()
        addPetRequested = true
    }

    private func openBookingChat(_ booking: Booking) {
        navigation.open(.bookingConversation(booking.id))
    }

    private func navigationRoot(for tab: CustomerTab) -> some View {
        CustomerNavigationStack(navigation: navigation, tab: tab) {
            destination(for: tab)
                .background(DesignTokens.Colors.appBackground)
                .navigationDestination(for: CustomerDestination.self) { route in
                    CustomerRouteDestination(route: route, customerID: customerID, notificationStore: notificationStore,
                        requestStore: requestStore, bookingsStore: bookingsStore, chatStore: chatStore,
                        marketplace: marketplace, onOpenChat: openBookingChat)
                }
        }
    }


    private func confirmBooking(_ handoff: CustomerRequestBookingHandoff) {
        guard acceptanceSessionIsCurrent() else { return }
        navigation.open(.grooming(.newBooking(handoff.booking.id)), replacing: true)
    }

    private func showRequest(_ requestID: UUID?) { navigation.showGrooming(requestID) }

    private func openReminderIfPossible() {
        guard let target = reminderScheduler.tap, target.role == .customer, target.accountID == customerID,
              acceptanceSessionIsCurrent(), requestStore?.isShowingWizard != true,
              requestStore?.isWizardSuspendedForPet != true, requestStore?.completedWizardRequestID == nil,
              requestStore?.discoveryFlow == nil else { return }
        navigation.open(.grooming(.booking(target.bookingID)), replacing: true)
        reminderScheduler.tap = nil
    }

    private var notificationUnreadCount: Int {
        notificationStore?.unreadCount ?? 0
    }

    private var messageUnreadCount: Int {
        chatStore?.unreadConversationCount ?? 0
    }

    private static func makeNotificationStore(
        customerID: UUID?,
        repository: (any CustomerNotificationRepository)?
    ) -> CustomerNotificationsStore? {
        guard let customerID, let repository else { return nil }

        return CustomerNotificationsStore(
            customerID: customerID,
            repository: repository
        )
    }

    private static func makeChatStore(
        customerID: UUID?,
        repository: (any ChatRepository)?,
        bookingRepository: (any BookingRepository)?
    ) -> ChatStore? {
        guard let customerID, let repository, let bookingRepository else {
            return nil
        }

        return ChatStore(
            participantID: customerID,
            role: .customer,
            repository: repository,
            bookingRepository: bookingRepository
        )
    }

    private static func makeRequestStore(
        customerID: UUID?,
        petRepository: (any CustomerPetRepository)?,
        requestRepository: (any CustomerRequestRepository)?,
        bookingRepository: (any BookingRepository)?,
        bookingsStore: BookingsStore?,
        marketplace: CustomerMarketplaceSession?
    ) -> CustomerRequestsStore? {
        guard let customerID, let petRepository, let requestRepository,
              let bookingRepository else { return nil }
        return CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: requestRepository,
            bookingRepository: bookingRepository,
            bookingsStore: bookingsStore,
            publicationCoordinator: marketplace?.publication,
            marketplace: marketplace
        )
    }

    private func refreshBadgeSources() async {
        if let notificationStore {
            await notificationStore.load()
        }
        if let chatStore {
            await chatStore.loadConversations()
        }
    }
}

private extension CustomerTab {
    var icon: BeckonTabIcon {
        switch self {
        case .home: .home
        case .requests, .bookings: .grooming
        case .messages: .messages
        case .account: .account
        }
    }

    var debugKey: String {
        switch self {
        case .home:
            "home"
        case .requests:
            "requests"
        case .bookings:
            "bookings"
        case .messages:
            "messages"
        case .account:
            "account"
        }
    }
}

#Preview {
    CustomerTabView()
}
