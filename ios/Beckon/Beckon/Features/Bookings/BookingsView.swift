import SwiftUI

struct BookingsView: View {
    private let role: UserRole
    private let isActiveTab: Bool
    private let customerProfileRepository: (any CustomerProfileRepository)?
    private let onOpenChat: (Booking) -> Void
    @State private var store: BookingsStore
    @State private var requestStore: CustomerRequestsStore?
    @State private var selectedScope: BookingListScope = .upcoming
    @State private var selectedScheduleDayKey: String?
    @Binding private var focusedBooking: Booking?

    #if DEBUG
    init(sandbox: CustomerSandboxSession, isActiveTab: Bool = true, onOpenChat: @escaping (Booking) -> Void = { _ in }) {
        role = .customer
        self.isActiveTab = isActiveTab
        customerProfileRepository = sandbox.accountRepository
        self.onOpenChat = onOpenChat
        _store = State(initialValue: sandbox.bookings)
        _requestStore = State(initialValue: sandbox.requests)
        _focusedBooking = .constant(nil)
        _selectedScope = State(initialValue: [.completed, .reviewed, .cancelled, .unfulfilled].contains(sandbox.state) ? .past : .upcoming)
    }
    #endif

    init(role: UserRole, store: BookingsStore, focusedBooking: Binding<Booking?> = .constant(nil), onOpenChat: @escaping (Booking) -> Void = { _ in }) {
        self.role = role
        isActiveTab = true
        self.customerProfileRepository = nil
        self.onOpenChat = onOpenChat
        _store = State(initialValue: store)
        _requestStore = State(initialValue: nil)
        _focusedBooking = focusedBooking
    }

    init(
        participantID: UUID,
        role: UserRole,
        repository: any BookingRepository,
        petRepository: (any CustomerPetRepository)? = nil,
        requestRepository: (any CustomerRequestRepository)? = nil,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        groomerProfileRepository: (any GroomerProfileRepository)? = nil,
        debugRecorder: AppDebugEventRecorder? = nil,
        store: BookingsStore? = nil,
        focusedBooking: Binding<Booking?> = .constant(nil),
        isActiveTab: Bool = true,
        onOpenChat: @escaping (Booking) -> Void = { _ in }
    ) {
        self.role = role
        self.isActiveTab = isActiveTab
        self.customerProfileRepository = customerProfileRepository
        self.onOpenChat = onOpenChat
        _focusedBooking = focusedBooking
        _store = State(
            initialValue: store ?? BookingsStore(
                participantID: participantID,
                role: role,
                repository: repository,
                groomerProfileRepository: groomerProfileRepository,
                debugRecorder: debugRecorder
            )
        )
        if role == .customer,
           let petRepository,
           let requestRepository {
            _requestStore = State(
                initialValue: CustomerRequestsStore(
                    customerID: participantID,
                    petRepository: petRepository,
                    requestRepository: requestRepository,
                    bookingRepository: repository,
                    debugRecorder: debugRecorder
                )
            )
        } else {
            _requestStore = State(initialValue: nil)
        }
    }

    @ViewBuilder
    var body: some View {
        if role == .groomer {
            GroomerScheduleView(store: store, focusedBooking: $focusedBooking,
                isActiveTab: isActiveTab, onOpenChat: onOpenChat)
        } else { customerBody }
    }

    private var customerBody: some View {
        ZStack {
            if role == .customer {
                BeckonExpressiveBackdrop()
            } else {
            DesignTokens.Colors.appBackground
                .ignoresSafeArea()
            }

            customerBookingsContent
        }
        .navigationTitle(role == .groomer ? "Schedule" : "")
        .navigationBarTitleDisplayMode(role == .groomer ? .large : .inline)
        .beckonNavigationDestination(item: $focusedBooking) { booking in
            BookingDetailView(
                bookingID: booking.id,
                role: role,
                store: store,
                onOpenChat: onOpenChat
            )
        }
        .background {
            BookingsStatusView(
                store: store,
                role: role,
                presentation: feedbackPresentation
            )

            if let requestStore {
                CustomerRequestsStatusView(store: requestStore)
            }
        }
        .beckonSheet(isPresented: requestWizardPresented) {
            if let requestStore {
                CustomerRequestWizardView(
                    store: requestStore,
                    customerProfileRepository: customerProfileRepository
                )
            }
        }
        .refreshable {
            await store.load()
        }
        .foregroundRefreshable {
            await store.load()
        }
    }

    private var customerBookingsContent: some View {
        ScrollView {
            // Keep one lazy row container; nested height estimation can stall scrolling.
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text("Bookings")
                    .font(DesignTokens.Typography.Expressive.display)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .beckonEntrance(0)

                BookingScopeControl(selection: $selectedScope)
                    .beckonEntrance(1)

                appointmentReminderNotice
                    .beckonEntrance(1)

                if store.isLoading, !store.hasLoadedOnce, store.bookings.isEmpty {
                    BeckonLoadingView(
                        title: "Loading bookings...",
                        message: "Fetching confirmed appointments for your account.",
                        accent: role.loadingAccent
                    )
                    .accessibilityIdentifier("bookings.loading")
                } else if let persistentLoadError = feedbackPresentation.persistentLoadError {
                    persistentLoadErrorView(persistentLoadError)
                } else if visibleBookings.isEmpty {
                    DesignPupPeek {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text(selectedScope.emptyTitle)
                                .font(DesignTokens.Typography.Expressive.title)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                            Text(selectedScope.emptyMessage)
                                .designSupportingText()
                        }
                        .designCardBody()
                    }
                    .accessibilityIdentifier("bookings.empty")
                } else {
                    LazyVStack(spacing: DesignTokens.Spacing.lg) {
                        ForEach(Array(visibleBookings.enumerated()), id: \.element.id) { index, booking in
                            NavigationLink {
                                BookingDetailView(
                                    bookingID: booking.id,
                                    role: role,
                                    store: store,
                                    onOpenChat: onOpenChat,
                                    onCreateNewRequestFromCancelledBooking:
                                        requestStore == nil ? nil : { booking in
                                            startNewRequestFromCancelledBooking(booking)
                                        }
                                )
                                .beckonHidesTabBar()
                            } label: {
                                BookingCard(
                                    booking: booking,
                                    role: role
                                )
                            }
                            .buttonStyle(BeckonLedgeButtonStyle(.card))
                            .beckonEntrance(2 + min(index, 4))
                            .accessibilityIdentifier(
                                AppTestOpsAccessibility.requestIdentifier(
                                    prefix: "bookings.row.request",
                                    requestID: booking.requestID
                                )
                            )
                        }
                    }
                }

                if store.canLoadMore || store.isLoadingMore {
                    BeckonLoadMoreButton(
                        isLoading: store.isLoadingMore,
                        accent: .customer,
                        accessibilityIdentifier: "customer.bookings.load-more"
                    ) {
                        await store.loadNextPage()
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
            .beckonEntranceClock()
        }
            .beckonTracksScroll()
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("bookings.list")
    }

    private var feedbackPresentation: BookingsFeedbackPresentation {
        BookingsFeedbackPresentation(
            role: role,
            bookings: store.bookings,
            isLoading: store.isLoading,
            errorMessage: store.errorMessage
        )
    }

    private var requestWizardPresented: Binding<Bool> {
        Binding(
            get: {
                CustomerRequestWizardPresentationOwnership.shouldPresent(
                    storeRequested: requestStore?.isShowingWizard == true,
                    isActiveTab: isActiveTab
                )
            },
            set: { isPresented in
                guard isActiveTab else { return }
                if !isPresented {
                    requestStore?.cancelWizard()
                }
            }
        )
    }

    @ViewBuilder
    private var appointmentReminderNotice: some View {
        if role == .customer, let issue = store.appointmentReminderIssue {
            BookingReminderNotice(issue: issue)
                .accessibilityIdentifier("bookings.appointment-reminder-notice")
        } else if let message = store.appointmentReminderNotice {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "bell.slash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            )
            .accessibilityIdentifier("bookings.appointment-reminder-notice")
        }
    }

    private func startNewRequestFromCancelledBooking(_ booking: Booking) {
        guard let requestStore else { return }

        Task {
            await requestStore.prepareRepublish(from: booking)
        }
    }

    private func persistentLoadErrorView(
        _ error: BeckonPersistentFeedbackError
    ) -> some View {
        BeckonPersistentErrorView(error) {
            Button {
                Task {
                    await store.load()
                }
            } label: {
                Text(error.actionTitle ?? "Try again")
            }
            .buttonStyle(BeckonPrimaryButtonStyle(accent: role.primaryButtonAccent))
        }
        .accessibilityIdentifier("bookings.persistent-error")
    }

    private var visibleBookings: [Booking] {
        let referenceDate = Date()
        return store.bookings
            .filter {
                selectedScope.contains($0, referenceDate: referenceDate)
            }
            .sortedByScheduledStart(ascending: selectedScope == .upcoming)
    }

}

struct BookingsFeedbackPresentation {
    let role: UserRole
    let bookings: [Booking]
    let isLoading: Bool
    let errorMessage: String?

    init(
        role: UserRole,
        bookings: [Booking],
        isLoading: Bool,
        errorMessage: String?
    ) {
        self.role = role
        self.bookings = bookings
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }

    var persistentLoadError: BeckonPersistentFeedbackError? {
        guard let errorMessage,
              !isLoading,
              bookings.isEmpty
        else {
            return nil
        }

        return BeckonPersistentFeedbackError(
            scope: .page(scopeID),
            sourceKey: "\(scopeID).load",
            title: role == .groomer ? "We could not load schedule" : "We could not load bookings",
            message: errorMessage,
            actionTitle: "Try again"
        )
    }

    var toastError: BeckonGlobalFeedbackError? {
        guard let errorMessage,
              persistentLoadError == nil
        else {
            return nil
        }

        return BeckonGlobalFeedbackError(
            scope: .operation("\(scopeID).operation"),
            sourceKey: "\(scopeID).operation-error",
            title: "Booking update failed",
            message: errorMessage
        )
    }

    var scopeID: String {
        switch role {
        case .customer:
            "customer.bookings"
        case .groomer:
            "groomer.bookings"
        }
    }
}

struct BookingCard: View {
    let booking: Booking
    let role: UserRole
    @Environment(\.dynamicTypeSize) private var typeSize

    @ViewBuilder var body: some View {
        if role == .customer { customerBody } else { groomerBody }
    }

    private var customerBody: some View {
        VStack(spacing: 0) {
            BeckonCountdownStrip(
                title: booking.status == .confirmed
                    ? (BeckonBookingCountdown.label(for: booking) ?? "Upcoming") : booking.status.title,
                trailing: booking.priceSummary)

            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.lg))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.lg))) {
                if let parts = BeckonBookingCountdown.dateParts(for: booking) {
                    BeckonDateTile(month: parts.month, day: parts.day)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(booking.partnerDisplayTitle(for: role))
                        .font(DesignTokens.Typography.Expressive.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(booking.scheduledTimeSummary)
                        .accessibilityLabel(booking.scheduledTimePresentation.accessibilityLabel)
                        .designSupportingText()

                    BeckonStatusChip(booking.status.presentation)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                DesignIconDisc(systemImage: "chevron.right", font: DesignTokens.Typography.Expressive.label)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .multilineTextAlignment(.leading)
    }
    private var groomerBody: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center) {
                    BeckonStatusChip(booking.status.presentation)

                    Spacer(minLength: DesignTokens.Spacing.md)

                    Text(booking.priceSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                    BeckonProfileAvatar(
                        data: role == .customer
                            ? booking.groomerAvatarPhotoData
                            : nil,
                        tone: role == .customer ? .groomer : .customer,
                        size: 64,
                        cornerRadius: 18,
                        participantID: role == .customer ? booking.groomerID : booking.customerID
                    )

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(booking.partnerDisplayTitle(for: role))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(booking.scheduledTimeSummary)
                            .accessibilityLabel(booking.scheduledTimePresentation.accessibilityLabel)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

extension Array where Element == Booking {
    nonisolated func sortedByScheduledStart(ascending: Bool) -> [Booking] {
        sorted { lhs, rhs in
            let lhsDate = GroomingRequestDateFormatting.parsedDate(
                from: lhs.scheduledStart
            ) ?? .distantFuture
            let rhsDate = GroomingRequestDateFormatting.parsedDate(
                from: rhs.scheduledStart
            ) ?? .distantFuture

            if lhsDate == rhsDate {
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
        }
    }
}

enum BookingListScope: String, CaseIterable, Identifiable {
    case upcoming
    case past

    var id: Self { self }

    var title: String {
        return switch self {
        case .upcoming:
            "Upcoming"
        case .past:
            "Past"
        }
    }

    var emptyTitle: String {
        return switch self {
        case .upcoming:
            "No Upcoming Bookings"
        case .past:
            "No Past Bookings"
        }
    }

    var emptyMessage: String {
        switch self {
        case .upcoming:
            "Confirmed appointments will appear here after an offer is accepted."
        case .past:
            "Completed and cancelled appointments will appear here."
        }
    }

    func contains(
        _ booking: Booking,
        referenceDate: Date = Date()
    ) -> Bool {
        let scheduledEnd = GroomingRequestDateFormatting.parsedDate(
            from: booking.scheduledEnd
        )
        let isUpcoming = booking.status == .confirmed
            && (scheduledEnd.map { $0 > referenceDate } ?? true)

        return switch self {
        case .upcoming:
            isUpcoming
        case .past:
            !isUpcoming
        }
    }
}

private struct BookingScopeControl: View {
    @Binding var selection: BookingListScope

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ForEach(BookingListScope.allCases) { scope in
                Button {
                    withAnimation(DesignTokens.Motion.swap) { selection = scope }
                } label: {
                    Text(scope.title)
                        .font(DesignTokens.Typography.Expressive.headline)
                        .foregroundStyle(selection == scope
                            ? DesignTokens.Colors.customerInk
                            : DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                }
                .buttonStyle(BeckonLedgeButtonStyle(selection == scope ? .pill : .card))
                .accessibilityAddTraits(selection == scope ? .isSelected : [])
                .accessibilityIdentifier("bookings.scope.\(scope.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct BookingDetailView: View {
    @Environment(\.customerGroomingRequestStore) private var customerRequestStore
    let bookingID: UUID
    let role: UserRole
    let store: BookingsStore
    let onOpenChat: ((Booking) -> Void)?
    @Environment(\.openBookingChat) private var shellOpenChat
    let onCreateNewRequestFromCancelledBooking: ((Booking) -> Void)?
    @FocusState private var focusedReviewTarget: BookingReviewFocusTarget?

    init(
        bookingID: UUID,
        role: UserRole,
        store: BookingsStore,
        onOpenChat: ((Booking) -> Void)? = nil,
        onCreateNewRequestFromCancelledBooking: ((Booking) -> Void)? = nil
    ) {
        self.bookingID = bookingID
        self.role = role
        self.store = store
        self.onOpenChat = onOpenChat
        self.onCreateNewRequestFromCancelledBooking =
            onCreateNewRequestFromCancelledBooking
    }

    @ViewBuilder
    var body: some View {
        if role == .customer {
            GroomingDetailView(target: .booking(bookingID), requestStore: customerRequestStore, bookingsStore: store,
                onOpenChat: onOpenChat ?? shellOpenChat,
                onCreateNewRequestFromBooking: onCreateNewRequestFromCancelledBooking)

        } else {
            GroomerBookingDetailView(bookingID: bookingID, store: store, onOpenChat: onOpenChat ?? shellOpenChat)
        }
    }
}

nonisolated enum BookingReviewFocusTarget: String, Hashable {
    case content = "bookings.review.content.container"
}

nonisolated enum BookingReviewKeyboardPresentation {
    static let actionPlacement: BeckonKeyboardActionPlacement = .pageAction
    static let contentFocusTarget = BookingReviewFocusTarget.content.rawValue
}

private extension Booking {

    var detailTitle: String {
        switch status {
        case .confirmed:
            "Booking confirmed"
        case .completed:
            "Booking completed"
        case .unfulfilled:
            "Service not confirmed"
        case .cancelledByCustomer, .cancelledByGroomer:
            "Booking cancelled"
        case .unknown:
            "Booking Status Unknown"
        }
    }

    func detailSubtitle(for role: UserRole) -> String {
        switch role {
        case .customer:
            "Your appointment is managed from Bookings."
        case .groomer:
            "This appointment is managed from Bookings."
        }
    }

    var scheduleLocationShortTitle: String {
        switch locationMode {
        case .groomerComesToCustomer:
            "Mobile"
        case .customerComesToGroomer:
            "Studio"
        case nil:
            "Location"
        }
    }
}

private struct BookingDetailHeroCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let booking: Booking
    let role: UserRole

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))
                layout {
                    BeckonStatusChip(booking.status.presentation)

                    if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.md) }

                    Text("Order #\(booking.referenceCode)")
                        .font(DesignTokens.Typography.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                layout {
                    if role == .customer {
                        BeckonProfileAvatar(
                            data: booking.groomerAvatarPhotoData,
                            tone: .groomer,
                            size: 64,
                            cornerRadius: 18,
                            participantID: booking.groomerID
                        )
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .frame(width: 64, height: 64)
                            .background(DesignTokens.Colors.placeholderFill)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                            )
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(heroTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(heroSubtitle)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var heroTitle: String {
        if role == .groomer {
            return booking.requestPetSnapshot?.name ?? booking.detailTitle
        }
        return booking.detailTitle
    }

    private var heroSubtitle: String {
        if role == .groomer {
            return "\(booking.appointmentServiceTitle) · \(booking.participantSummary(for: .groomer))"
        }
        return booking.detailSubtitle(for: role)
    }
}

private struct BookingDetailInfoCard<Content: View>: View {
    let title: String
    let systemImage: String
    let role: UserRole
    let content: Content

    init(
        title: String,
        systemImage: String,
        role: UserRole = .customer,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.content = content()
    }

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(DesignTokens.Colors.iconTileFill)
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }

                content
            }
        }
    }
}

private struct BookingPartnerOverviewCard: View {
    let booking: Booking
    let role: UserRole
    let onOpenChat: ((Booking) -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        BookingDetailInfoCard(
            title: role == .customer ? "Groomer" : "Customer",
            systemImage: "person.fill",
            role: role
        ) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
                : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))
            layout {
                BeckonProfileAvatar(
                    data: role == .customer
                        ? booking.groomerAvatarPhotoData
                        : nil,
                    tone: role == .customer ? .groomer : .customer,
                    size: 56,
                    cornerRadius: 16,
                    placeholderSize: 22,
                    participantID: role == .customer ? booking.groomerID : booking.customerID
                )

                Text(role == .groomer
                    ? booking.participantSummary(for: .groomer)
                    : booking.partnerDisplayTitle(for: role))
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let onOpenChat {
                Button {
                    onOpenChat(booking)
                } label: {
                    Label("Open chat", systemImage: "message.fill")
                }
                .buttonStyle(BeckonPrimaryButtonStyle(accent: role.primaryButtonAccent))
                .accessibilityIdentifier("bookings.detail.open-chat")
            }
        }
    }
}

private struct BookingDetailFactRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let value: String
    let stacksValue: Bool

    init(_ title: String, value: String, stacksValue: Bool = false) {
        self.title = title
        self.value = value
        self.stacksValue = stacksValue
    }

    var body: some View {
        let stacked = stacksValue || typeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md))
        layout {
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            if !stacked { Spacer(minLength: DesignTokens.Spacing.md) }

            Text(value)
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(stacked ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BookingReviewDisplay: View {
    let review: BookingReview

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(DesignTokens.Colors.ratingStar)
                        .accessibilityHidden(true)

                    Text(review.ratingSummary)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }

                Text(review.displayContent)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                BookingFactRow(
                    "Submitted",
                    value: GroomingRequestDateFormatting.displayString(
                        from: review.createdAt
                    )
                )

                if !review.petFitOutcomes.isEmpty {
                    Divider()
                        .overlay(DesignTokens.Colors.divider)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Pet fit notes")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        ForEach(review.petFitOutcomes) { outcome in
                            BookingReviewFitOutcomeDisplay(outcome: outcome)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("bookings.review.display")
    }
}

struct BookingReviewFitOutcomeDisplay: View {
    let outcome: BookingReviewPetFitOutcomeRecord
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm))
        layout {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(outcome.title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(outcome.groupTitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(outcome.outcome.title)
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surface)
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch outcome.outcome {
        case .positive:
            DesignTokens.Colors.statusSuccessText
        case .negative:
            DesignTokens.Colors.statusWarningText
        }
    }

    private var systemImage: String {
        switch outcome.outcome {
        case .positive:
            "checkmark.circle.fill"
        case .negative:
            "exclamationmark.triangle.fill"
        }
    }
}

/// Compatibility entry for existing detail hosts; one composer owns every review.
struct BookingReviewForm: View {
    let booking: Booking
    let store: BookingsStore
    let accent: BeckonPrimaryButtonStyle.Accent
    @FocusState.Binding var focusedTarget: BookingReviewFocusTarget?
    var body: some View { BookingReviewEntry(booking: booking, store: store) }
}

struct BookingsStatusView: View {
    let store: BookingsStore
    let role: UserRole
    let presentation: BookingsFeedbackPresentation

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
        presentation.toastError
    }

    private var progressPrompt: BeckonGlobalFeedbackProgress? {
        if store.isCancelling {
            return BeckonGlobalFeedbackProgress(
                scope: .operation("\(presentation.scopeID).cancel"),
                sourceKey: "\(presentation.scopeID).cancel-progress",
                title: "Cancelling…",
                tone: role.feedbackTone
            )
        }

        if store.isCompleting {
            return BeckonGlobalFeedbackProgress(
                scope: .operation("\(presentation.scopeID).complete"),
                sourceKey: "\(presentation.scopeID).complete-progress",
                title: "Completing…",
                tone: role.feedbackTone
            )
        }


        return nil
    }
}

private struct BookingFactRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(value)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BookingMetadataRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .frame(width: DesignTokens.Spacing.lg)
                .accessibilityHidden(true)

            Text(text)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension UserRole {
    var primaryButtonAccent: BeckonPrimaryButtonStyle.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var loadingAccent: BeckonLoadingView.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var emptyStateAccent: BeckonEmptyState<EmptyView>.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var feedbackTone: BeckonFeedbackTone {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var bookingsSubtitle: String {
        switch self {
        case .customer:
            "Track confirmed appointments and review completed services."
        case .groomer:
            "Review confirmed appointments and close completed services."
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        BookingsView(
            participantID: UUID(),
            role: .customer,
            repository: BookingsPreviewRepository()
        )
    }
}

@MainActor
private final class BookingsPreviewRepository: BookingRepository {
    private var bookings: [Booking] = [
        Booking(
            id: UUID(),
            requestID: UUID(),
            offerID: UUID(),
            customerID: UUID(),
            groomerID: UUID(),
            scheduledStart: "2026-06-22T16:00:00Z",
            scheduledEnd: "2026-06-22T18:00:00Z",
            priceEstimate: 125,
            status: .confirmed,
            cancelledBy: nil,
            cancelledAt: nil,
            completedAt: nil,
            completedBy: nil,
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z",
            review: nil
        ),
    ]

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        bookings
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        throw BookingRepositoryError.unavailable
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        bookings[0] = bookings[0].replacing(
            status: .cancelledByCustomer,
            cancelledBy: bookings[0].customerID,
            cancelledAt: "2026-06-20T13:00:00Z"
        )
        return CancelBookingResult(
            bookingID: bookingID,
            bookingStatus: .cancelledByCustomer,
            cancelledTimestamp: "2026-06-20T13:00:00Z",
            cancelledBy: bookings[0].customerID
        )
    }

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        bookings[0] = bookings[0].replacing(
            status: .completed,
            cancelledBy: nil,
            cancelledAt: nil,
            completedAt: "2026-06-22T18:05:00Z",
            completedBy: bookings[0].groomerID
        )
        return CompleteBookingResult(
            bookingID: bookingID,
            bookingStatus: .completed,
            completedTimestamp: "2026-06-22T18:05:00Z",
            completedBy: bookings[0].groomerID
        )
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        let review = BookingReview(
            id: UUID(),
            bookingID: bookingID,
            customerID: bookings[0].customerID,
            groomerID: bookings[0].groomerID,
            rating: draft.rating,
            content: draft.content,
            createdAt: "2026-06-22T19:00:00Z",
            petFitOutcomes: draft.petFitOutcomes.map {
                BookingReviewPetFitOutcomeRecord(
                    id: UUID(),
                    signal: $0.signal,
                    outcome: $0.outcome
                )
            }
        )
        bookings[0] = bookings[0].adding(review: review)
        return CreateReviewResult(
            review: review,
            groomerRatingAverage: Double(draft.rating),
            groomerRatingCount: 1
        )
    }
}
#endif

struct BookingReminderNotice: View {
    let issue: AppointmentReminderIssue
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isOff: Bool { issue == .permissionDenied }

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            HStack(spacing: DesignTokens.Spacing.md) {
                DesignIconDisc(systemImage: "bell.slash.fill")
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(isOff ? "Reminders are off" : "Reminders")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text(isOff ? "Allow notifications to get alerts before appointments." : issue.message)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isOff {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Text("Settings")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                        .background(DesignTokens.Colors.customerTint, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityHint("Opens iOS Settings so you can allow notifications.")
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .beckonLedge(.card)
        .accessibilityElement(children: .contain)
    }
}
