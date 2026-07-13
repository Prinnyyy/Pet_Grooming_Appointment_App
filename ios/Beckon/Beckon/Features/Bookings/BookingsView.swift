import SwiftUI

struct BookingsView: View {
    private let role: UserRole
    private let customerProfileRepository: (any CustomerProfileRepository)?
    private let onOpenChat: (Booking) -> Void
    @State private var store: BookingsStore
    @State private var requestStore: CustomerRequestsStore?
    @State private var selectedScope: BookingListScope = .upcoming
    @State private var selectedScheduleDayKey: String?

    init(
        participantID: UUID,
        role: UserRole,
        repository: any BookingRepository,
        petRepository: (any CustomerPetRepository)? = nil,
        requestRepository: (any CustomerRequestRepository)? = nil,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        debugRecorder: AppDebugEventRecorder? = nil,
        onOpenChat: @escaping (Booking) -> Void = { _ in }
    ) {
        self.role = role
        self.customerProfileRepository = customerProfileRepository
        self.onOpenChat = onOpenChat
        _store = State(
            initialValue: BookingsStore(
                participantID: participantID,
                role: role,
                repository: repository,
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

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            bookingsContent
        }
        .navigationTitle(role == .groomer ? "Schedule" : "")
        .navigationBarTitleDisplayMode(role == .groomer ? .large : .inline)
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
        .sheet(isPresented: requestWizardPresented) {
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

    @ViewBuilder
    private var bookingsContent: some View {
        if role == .groomer {
            groomerScheduleContent
        } else {
            customerBookingsContent
        }
    }

    private var customerBookingsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                BeckonPageTitle("Bookings")

                BookingScopeControl(selection: $selectedScope)

                appointmentReminderNotice

                if store.isLoading, store.bookings.isEmpty {
                    BeckonLoadingView(
                        title: "Loading Bookings...",
                        message: "Fetching confirmed appointments for your account.",
                        accent: role.loadingAccent
                    )
                    .accessibilityIdentifier("bookings.loading")
                } else if let persistentLoadError = feedbackPresentation.persistentLoadError {
                    persistentLoadErrorView(persistentLoadError)
                } else if visibleBookings.isEmpty {
                    BeckonEmptyState(
                        title: selectedScope.emptyTitle,
                        message: selectedScope.emptyMessage,
                        systemImage: "calendar.badge.clock",
                        accent: role.emptyStateAccent
                    )
                    .accessibilityIdentifier("bookings.empty")
                } else {
                    LazyVStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(visibleBookings) { booking in
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
                            } label: {
                                BookingSummaryRow(
                                    booking: booking,
                                    role: role
                                )
                            }
                            .buttonStyle(.plain)
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
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("bookings.list")
    }

    private var groomerScheduleContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                appointmentReminderNotice

                GroomerScheduleDayStrip(
                    days: schedulePresentation.days,
                    selectedDayKey: schedulePresentation.selectedDayKey,
                    onSelect: { selectedScheduleDayKey = $0.id }
                )

                if store.isLoading, store.bookings.isEmpty {
                    BeckonLoadingView(
                        title: "Loading Schedule...",
                        message: "Fetching confirmed appointments for your day.",
                        accent: .groomer
                    )
                    .accessibilityIdentifier("groomer.schedule.loading")
                } else if let persistentLoadError = feedbackPresentation.persistentLoadError {
                    persistentLoadErrorView(persistentLoadError)
                } else if schedulePresentation.selectedBookings.isEmpty {
                    GroomerScheduleEmptyDayView(
                        dayTitle: GroomerScheduleDateFormatting.longDayTitle(
                            from: schedulePresentation.selectedDate
                        )
                    )
                } else {
                    if let summary = schedulePresentation.summary {
                        GroomerScheduleSummaryBand(
                            dayTitle: GroomerScheduleDateFormatting.longDayTitle(
                                from: schedulePresentation.selectedDate
                            ),
                            summary: summary
                        )
                    }

                    GroomerScheduleTimeline(
                        bookings: schedulePresentation.selectedBookings,
                        store: store,
                        onOpenChat: onOpenChat
                    )
                }

                if store.canLoadMore || store.isLoadingMore {
                    BeckonLoadMoreButton(
                        isLoading: store.isLoadingMore,
                        accent: .groomer,
                        accessibilityIdentifier: "groomer.schedule.load-more"
                    ) {
                        await store.loadNextPage()
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
        }
        .scrollContentBackground(.hidden)
            .accessibilityIdentifier("groomer.schedule")
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
                requestStore?.isShowingWizard == true
            },
            set: { isPresented in
                if !isPresented {
                    requestStore?.cancelWizard()
                }
            }
        )
    }

    @ViewBuilder
    private var appointmentReminderNotice: some View {
        if let message = store.appointmentReminderNotice {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "bell.slash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(role.primaryColor)

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
            await requestStore.load()
            _ = requestStore.startRepublish(
                from: booking,
                originalRequest: requestStore.request(withID: booking.requestID)
            )
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
                Text(error.actionTitle ?? "Try Again")
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

    private var schedulePresentation: GroomerSchedulePresentation {
        GroomerSchedulePresentation(
            referenceDate: Date(),
            bookings: store.bookings,
            selectedDayKey: selectedScheduleDayKey
        )
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
            title: role == .groomer ? "We Could Not Load Schedule" : "We Could Not Load Bookings",
            message: errorMessage,
            actionTitle: "Try Again"
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
            title: "Booking Update Failed",
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

struct BookingSummaryRow: View {
    let booking: Booking
    let role: UserRole

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center) {
                    BeckonStatusChip(
                        booking.status.title,
                        systemImage: booking.status.chipIcon,
                        tone: booking.status.chipTone(for: role)
                    )

                    Spacer(minLength: DesignTokens.Spacing.md)

                    Text(BookingListDateFormatting.day(from: booking.scheduledStart))
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
                        cornerRadius: 18
                    )

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(booking.partnerDisplayTitle(for: role))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(booking.listContextSummary)
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
        HStack(spacing: 0) {
            ForEach(BookingListScope.allCases) { scope in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = scope
                    }
                } label: {
                    Text(scope.title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(
                            selection == scope
                                ? DesignTokens.Colors.textPrimary
                                : DesignTokens.Colors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background {
                            if selection == scope {
                                RoundedRectangle(
                                    cornerRadius: DesignTokens.CornerRadius.input,
                                    style: .continuous
                                )
                                .fill(DesignTokens.Colors.surface)
                                .beckonShadow(DesignTokens.Shadows.smallCard)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bookings.scope.\(scope.rawValue)")
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .fill(DesignTokens.Colors.borderSoft.opacity(0.72))
        }
        .accessibilityElement(children: .contain)
    }
}

private struct GroomerScheduleDayStrip: View {
    let days: [GroomerScheduleDay]
    let selectedDayKey: String
    let onSelect: (GroomerScheduleDay) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(days) { day in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            onSelect(day)
                        }
                    } label: {
                        GroomerScheduleDayChip(
                            day: day,
                            isSelected: day.id == selectedDayKey
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .scrollClipDisabled()
        .accessibilityIdentifier("groomer.schedule.days")
    }
}

private struct GroomerScheduleDayChip: View {
    let day: GroomerScheduleDay
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(GroomerScheduleDateFormatting.weekday(from: day.date))
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? Color.white.opacity(0.86) : DesignTokens.Colors.textTertiary)

            Text(GroomerScheduleDateFormatting.dayNumber(from: day.date))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(isSelected ? Color.white : DesignTokens.Colors.textPrimary)

            Text(day.isToday ? "Today" : GroomerScheduleDateFormatting.month(from: day.date))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : DesignTokens.Colors.textTertiary)
        }
        .frame(width: 64, height: 78)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? DesignTokens.Colors.groomerAccent : DesignTokens.Colors.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected ? DesignTokens.Colors.groomerAccentDark.opacity(0.2) : DesignTokens.Colors.border,
                    lineWidth: 1.5
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct GroomerScheduleSummaryBand: View {
    let dayTitle: String
    let summary: GroomerScheduleSummary

    var body: some View {
        GroomerGroupedSurface {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(dayTitle)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text("Next at \(summary.nextStartSummary) · \(summary.totalDurationSummary) booked")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(summary.bookingCount) \(summary.bookingCount == 1 ? "appointment" : "appointments")")
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                    .clipShape(Capsule())
            }
            .padding(DesignTokens.Spacing.md)
        }
        .accessibilityIdentifier("groomer.schedule.summary")
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerScheduleEmptyDayView: View {
    let dayTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(dayTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            BeckonEmptyState(
                title: "No Appointments",
                message: "Confirmed bookings for this day will appear here.",
                systemImage: "calendar.badge.clock",
                accent: .groomer
            )
        }
        .accessibilityIdentifier("groomer.schedule.empty")
    }
}

private struct GroomerScheduleTimeline: View {
    let bookings: [Booking]
    let store: BookingsStore
    let onOpenChat: (Booking) -> Void

    var body: some View {
        GroomerWorkspaceSection(title: "Appointments") {
            GroomerGroupedSurface {
                VStack(spacing: 0) {
                    ForEach(Array(bookings.enumerated()), id: \.element.id) { index, booking in
                        if index > 0 {
                            GroomerWorkspaceDivider(leadingInset: 72)
                        }

                        GroomerScheduleAppointmentRow(
                            booking: booking,
                            store: store,
                            onOpenChat: onOpenChat
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("groomer.schedule.timeline")
    }
}

private struct GroomerScheduleAppointmentRow: View {
    let booking: Booking
    let store: BookingsStore
    let onOpenChat: (Booking) -> Void

    private var presentation: GroomerScheduleAppointmentPresentation {
        GroomerScheduleAppointmentPresentation(booking: booking)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            NavigationLink {
                BookingDetailView(
                    bookingID: booking.id,
                    role: .groomer,
                    store: store,
                    onOpenChat: onOpenChat
                )
            } label: {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(BookingListDateFormatting.time(from: booking.scheduledStart))
                            .font(DesignTokens.Typography.caption.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.groomerAccentDark)

                        Text(BookingListDateFormatting.time(from: booking.scheduledEnd))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                    .frame(width: 56, alignment: .leading)

                    ZStack {
                        DesignTokens.Colors.groomerAccent.opacity(0.15)
                        Image(systemName: "pawprint.fill")
                            .font(.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(presentation.petName)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(1)

                        Text(presentation.petDetail)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(1)

                        Text("\(presentation.customerReference) · \(presentation.location)")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.sm) {
                        BeckonStatusChip(
                            presentation.status.title,
                            systemImage: presentation.status.chipIcon,
                            tone: presentation.status.chipTone(for: .groomer)
                        )

                        Image(systemName: "chevron.right")
                            .font(DesignTokens.Typography.caption.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                AppTestOpsAccessibility.requestIdentifier(
                    prefix: "groomer.booking.row.request",
                    requestID: booking.requestID
                )
            )

            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    onOpenChat(booking)
                } label: {
                    Label("Message", systemImage: "message")
                }
                .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
                .accessibilityIdentifier(
                    AppTestOpsAccessibility.requestIdentifier(
                        prefix: "groomer.booking.message.request",
                        requestID: booking.requestID
                    )
                )

                if booking.canComplete(for: .groomer) {
                    Button {
                        Task { await store.complete(booking) }
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer))
                    .disabled(store.isCompleting || store.isCancelling)
                    .accessibilityIdentifier(
                        AppTestOpsAccessibility.requestIdentifier(
                            prefix: "groomer.booking.complete.request",
                            requestID: booking.requestID
                        )
                    )
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
    }
}

private enum BookingListDateFormatting {
    static func day(from value: String) -> String {
        format(value, pattern: "EEE, MMM d")
    }

    static func time(from value: String) -> String {
        format(value, pattern: "h:mm a")
    }

    private static func format(_ value: String, pattern: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

private extension Booking {
    var listContextSummary: String {
        "\(BookingListDateFormatting.time(from: scheduledStart)) · \(priceSummary)"
    }

    var timeWindowSummary: String {
        "\(BookingListDateFormatting.time(from: scheduledStart)) - \(BookingListDateFormatting.time(from: scheduledEnd))"
    }

    var detailTitle: String {
        switch status {
        case .confirmed:
            "Booking Confirmed"
        case .completed:
            "Booking Completed"
        case .cancelledByCustomer, .cancelledByGroomer:
            "Booking Cancelled"
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

struct BookingDetailView: View {
    let bookingID: UUID
    let role: UserRole
    let store: BookingsStore
    let onOpenChat: (Booking) -> Void
    let onCreateNewRequestFromCancelledBooking: ((Booking) -> Void)?
    @FocusState private var focusedReviewTarget: BookingReviewFocusTarget?

    init(
        bookingID: UUID,
        role: UserRole,
        store: BookingsStore,
        onOpenChat: @escaping (Booking) -> Void = { _ in },
        onCreateNewRequestFromCancelledBooking: ((Booking) -> Void)? = nil
    ) {
        self.bookingID = bookingID
        self.role = role
        self.store = store
        self.onOpenChat = onOpenChat
        self.onCreateNewRequestFromCancelledBooking =
            onCreateNewRequestFromCancelledBooking
    }

    var body: some View {
        if let booking = store.booking(withID: bookingID) {
            ScrollViewReader { scrollProxy in
                ZStack {
                    DesignTokens.Colors.background
                        .ignoresSafeArea()

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                            BookingDetailHeroCard(
                                booking: booking,
                                role: role
                            )

                            BookingDetailInfoCard(
                                title: "Appointment",
                                systemImage: "calendar.badge.clock",
                                role: role
                            ) {
                                BookingDetailFactRow("Service", value: booking.appointmentServiceTitle)
                                BookingDetailFactRow("Date", value: BookingListDateFormatting.day(from: booking.scheduledStart))
                                BookingDetailFactRow("Time", value: booking.timeWindowSummary)
                                BookingDetailFactRow("Service Location", value: booking.appointmentLocationTitle)
                                BookingDetailFactRow("Address", value: booking.appointmentAddressSummary)
                                BookingDetailFactRow("Price", value: booking.priceSummary)
                            }

                            if role == .customer,
                               booking.status.isCancellation,
                               let onCreateNewRequestFromCancelledBooking {
                                CustomerRequestRepublishButton(
                                    actionTitle: "Create a New Request from This Booking",
                                    accessibilityIdentifier: "customer.bookings.republish",
                                    action: {
                                        onCreateNewRequestFromCancelledBooking(booking)
                                    }
                                )
                            }

                            BookingPartnerOverviewCard(
                                booking: booking,
                                role: role,
                                onOpenChat: onOpenChat
                            )

                            if booking.status == .completed {
                                BeckonSectionHeader("Review")

                                if let review = booking.review {
                                    BookingReviewDisplay(review: review)
                                } else if booking.canReview(for: role) {
                                    BookingReviewForm(
                                        booking: booking,
                                        store: store,
                                        accent: role.primaryButtonAccent,
                                        focusedTarget: $focusedReviewTarget
                                    )
                                } else {
                                    BeckonCard {
                                        BookingMetadataRow(
                                            systemImage: "star",
                                            text: "Waiting for the customer to leave a review."
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                        .padding(.top, DesignTokens.Spacing.lg)
                        .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
                    }
                    .beckonKeyboardAvoidance(
                        focusedTarget: focusedReviewTarget?.rawValue,
                        using: scrollProxy
                    )
                }
            }
            .navigationTitle("Booking")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("bookings.detail")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BookingDetailActionBar(
                    booking: booking,
                    role: role,
                    store: store
                )
            }
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                BeckonEmptyState(
                    title: "Booking Unavailable",
                    message: "Refresh bookings and try again.",
                    systemImage: "calendar.badge.exclamationmark",
                    accent: role.emptyStateAccent
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Booking")
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

private struct BookingDetailActionBar: View {
    let booking: Booking
    let role: UserRole
    let store: BookingsStore

    private var presentation: BookingDetailActionPresentation {
        BookingDetailActionPresentation(booking: booking, role: role)
    }

    @ViewBuilder
    var body: some View {
        if presentation.canCancel || presentation.canComplete {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if presentation.canCancel {
                    Button(role: .destructive) {
                        Task { await store.cancel(booking) }
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
                    .disabled(store.isCancelling || store.isCompleting)
                    .accessibilityIdentifier(
                        AppTestOpsAccessibility.requestIdentifier(
                            prefix: role == .groomer
                                ? "groomer.booking.cancel.request"
                                : "customer.booking.cancel.request",
                            requestID: booking.requestID
                        )
                    )
                }

                if presentation.canComplete {
                    Button {
                        Task { await store.complete(booking) }
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer))
                    .disabled(store.isCancelling || store.isCompleting)
                    .accessibilityIdentifier(
                        AppTestOpsAccessibility.requestIdentifier(
                            prefix: "groomer.booking.detail.complete.request",
                            requestID: booking.requestID
                        )
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                GroomerWorkspaceDivider()
            }
        }
    }
}

private struct BookingDetailHeroCard: View {
    let booking: Booking
    let role: UserRole

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .center) {
                    BeckonStatusChip(
                        booking.status.title,
                        systemImage: booking.status.chipIcon,
                        tone: booking.status.chipTone(for: role)
                    )

                    Spacer(minLength: DesignTokens.Spacing.md)

                    Text("Order #\(booking.referenceCode)")
                        .font(DesignTokens.Typography.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                    if role == .customer {
                        BeckonProfileAvatar(
                            data: booking.groomerAvatarPhotoData,
                            tone: .groomer,
                            size: 64,
                            cornerRadius: 18
                        )
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(role.primaryColor)
                            .frame(width: 64, height: 64)
                            .background(role.primaryColor.opacity(0.24))
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
                        .foregroundStyle(role.primaryColor)
                        .frame(width: 38, height: 38)
                        .background(role.primaryColor.opacity(0.15))
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }

                content
            }
        }
    }
}

private struct BookingPartnerOverviewCard: View {
    let booking: Booking
    let role: UserRole
    let onOpenChat: (Booking) -> Void

    var body: some View {
        BookingDetailInfoCard(
            title: role == .customer ? "Groomer" : "Customer",
            systemImage: "person.fill",
            role: role
        ) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                BeckonProfileAvatar(
                    data: role == .customer
                        ? booking.groomerAvatarPhotoData
                        : nil,
                    tone: role == .customer ? .groomer : .customer,
                    size: 56,
                    cornerRadius: 16,
                    placeholderSize: 22
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(
                        role == .groomer
                            ? booking.participantSummary(for: .groomer)
                            : booking.partnerDisplayTitle(for: role)
                    )
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(role == .customer ? "Confirmed grooming provider" : "Booking customer")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                BookingMiniChip(title: "Chat Ready", systemImage: "message")
                BookingMiniChip(title: booking.status.title, systemImage: booking.status.chipIcon)
            }

            Button {
                onOpenChat(booking)
            } label: {
                Label("Open Chat", systemImage: "message.fill")
            }
            .buttonStyle(BeckonPrimaryButtonStyle(accent: role.primaryButtonAccent))
            .accessibilityIdentifier("bookings.detail.open-chat")
        }
    }
}

private struct BookingMiniChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(DesignTokens.Typography.caption.weight(.bold))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.borderSoft.opacity(0.72))
            .clipShape(Capsule())
    }
}

private struct BookingDetailFactRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(value)
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
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
                        .foregroundStyle(DesignTokens.Colors.warning)
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
                        Text("Pet Fit Notes")
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

private struct BookingReviewFitOutcomeDisplay: View {
    let outcome: BookingReviewPetFitOutcomeRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
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
        .background(tint.opacity(0.1))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch outcome.outcome {
        case .positive:
            DesignTokens.Colors.success
        case .negative:
            DesignTokens.Colors.warning
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

private struct BookingReviewForm: View {
    let booking: Booking
    let store: BookingsStore
    let accent: BeckonPrimaryButtonStyle.Accent
    @State private var rating = 5
    @State private var content = ""
    @State private var fitOutcomeSelections: [BookingReviewPetFitOutcomeSelection]
    @FocusState.Binding var focusedTarget: BookingReviewFocusTarget?

    init(
        booking: Booking,
        store: BookingsStore,
        accent: BeckonPrimaryButtonStyle.Accent,
        focusedTarget: FocusState<BookingReviewFocusTarget?>.Binding
    ) {
        self.booking = booking
        self.store = store
        self.accent = accent
        _focusedTarget = focusedTarget
        _fitOutcomeSelections = State(
            initialValue: BookingReviewPetFitOutcomeSelection.defaults(
                for: booking.reviewableFitSignals
            )
        )
    }

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Picker("Rating", selection: $rating) {
                    ForEach(1...5, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .tint(DesignTokens.Colors.customerPrimary)
                .accessibilityIdentifier("bookings.review.rating")

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    TextEditor(text: $content)
                        .focused($focusedTarget, equals: .content)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .beckonFormField()
                        .accessibilityIdentifier("bookings.review.content")

                    Text("Optional review text, up to 2,000 characters.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .beckonKeyboardFocusTarget(
                    BookingReviewKeyboardPresentation.contentFocusTarget
                )

                if !fitOutcomeSelections.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Pet Fit Notes")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        ForEach($fitOutcomeSelections) { $selection in
                            BookingReviewFitOutcomePicker(selection: $selection)
                        }
                    }
                }

                Button {
                    Task {
                        await store.createReview(
                            for: booking,
                            rating: rating,
                            content: content,
                            petFitOutcomes: fitOutcomeSelections.selectedOutcomes
                        )
                    }
                } label: {
                    Label("Submit Review", systemImage: "star.bubble")
                }
                .buttonStyle(BeckonPrimaryButtonStyle(accent: accent))
                .disabled(store.isSubmittingReview)
                .accessibilityIdentifier("bookings.review.submit")
            }
        }
    }
}

private struct BookingReviewFitOutcomePicker: View {
    @Binding var selection: BookingReviewPetFitOutcomeSelection

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                Text(selection.title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Spacer(minLength: DesignTokens.Spacing.sm)

                Text(selection.groupTitle)
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            Picker(
                "Pet fit outcome",
                selection: $selection.outcome
            ) {
                Text("Skip").tag(nil as BookingReviewPetFitOutcome?)

                ForEach(BookingReviewPetFitOutcome.allCases) { outcome in
                    Text(outcome.title).tag(Optional(outcome))
                }
            }
            .pickerStyle(.segmented)
            .tint(DesignTokens.Colors.customerPrimary)
            .accessibilityIdentifier(
                "bookings.review.fit.\(selection.signal.id)"
            )
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.borderSoft.opacity(0.42))
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.input,
                style: .continuous
            )
        )
    }
}

private struct BookingsStatusView: View {
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

        if store.isSubmittingReview {
            return BeckonGlobalFeedbackProgress(
                scope: .operation("\(presentation.scopeID).review"),
                sourceKey: "\(presentation.scopeID).review-progress",
                title: "Submitting Review…",
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

    var primaryColor: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerPrimaryDark
        case .groomer:
            DesignTokens.Colors.groomerAccentDark
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

private extension BookingStatus {
    var chipIcon: String {
        switch self {
        case .confirmed:
            "calendar.badge.checkmark"
        case .completed:
            "checkmark.circle.fill"
        case .cancelledByCustomer, .cancelledByGroomer:
            "xmark.circle.fill"
        case .unknown:
            "questionmark.circle"
        }
    }

    func chipTone(for role: UserRole) -> BeckonStatusChip.Tone {
        switch self {
        case .confirmed:
            role == .groomer ? .groomer : .customer
        case .completed:
            .success
        case .cancelledByCustomer, .cancelledByGroomer:
            .error
        case .unknown:
            .neutral
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
