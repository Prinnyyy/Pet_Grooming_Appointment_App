import SwiftUI

struct BookingsView: View {
    private let role: UserRole
    private let onOpenChat: (Booking) -> Void
    @State private var store: BookingsStore
    @State private var selectedScope: BookingListScope = .upcoming
    @State private var selectedScheduleDayKey: String?

    init(
        participantID: UUID,
        role: UserRole,
        repository: any BookingRepository,
        onOpenChat: @escaping (Booking) -> Void = { _ in }
    ) {
        self.role = role
        self.onOpenChat = onOpenChat
        _store = State(
            initialValue: BookingsStore(
                participantID: participantID,
                role: role,
                repository: repository
            )
        )
    }

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            bookingsContent
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BookingsStatusView(
                store: store,
                role: role
            )
        }
        .refreshable {
            await store.load()
        }
        .task {
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
                CustomerTabTitle("Bookings")

                BookingScopeControl(selection: $selectedScope)

                if store.isLoading, store.bookings.isEmpty {
                    GroomlyLoadingView(
                        title: "Loading Bookings...",
                        message: "Fetching confirmed appointments for your account.",
                        accent: role.loadingAccent
                    )
                    .accessibilityIdentifier("bookings.loading")
                } else if visibleBookings.isEmpty {
                    GroomlyEmptyState(
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
                                    onOpenChat: onOpenChat
                                )
                            } label: {
                                BookingSummaryRow(
                                    booking: booking,
                                    role: role
                                )
                            }
                            .buttonStyle(.plain)
                        }
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
                CustomerTabTitle("Schedule")

                GroomerScheduleDayStrip(
                    days: scheduleDays,
                    selectedDayKey: effectiveScheduleDayKey,
                    onSelect: { selectedScheduleDayKey = $0.id }
                )

                GroomerScheduleSnapshotCard(
                    dayTitle: GroomerScheduleDateFormatting.longDayTitle(
                        from: effectiveScheduleDate
                    ),
                    bookings: selectedScheduleBookings
                )

                if store.isLoading, store.bookings.isEmpty {
                    GroomlyLoadingView(
                        title: "Loading Schedule...",
                        message: "Fetching confirmed appointments for your day.",
                        accent: .groomer
                    )
                    .accessibilityIdentifier("groomer.schedule.loading")
                } else if selectedScheduleBookings.isEmpty {
                    GroomlyEmptyState(
                        title: "No Appointments",
                        message: "Confirmed bookings for the selected day will appear here.",
                        systemImage: "calendar.badge.clock",
                        accent: .groomer
                    )
                    .accessibilityIdentifier("groomer.schedule.empty")
                } else {
                    GroomerScheduleTimeline(
                        bookings: selectedScheduleBookings,
                        store: store,
                        onOpenChat: onOpenChat
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("groomer.schedule")
    }

    private var visibleBookings: [Booking] {
        store.bookings
            .filter(selectedScope.contains)
            .sortedByScheduledStart(ascending: selectedScope == .upcoming)
    }

    private var scheduleDays: [GroomerScheduleDay] {
        GroomerScheduleDay.days(around: Date(), bookings: store.bookings)
    }

    private var effectiveScheduleDayKey: String {
        if let selectedScheduleDayKey,
           scheduleDays.contains(where: { $0.id == selectedScheduleDayKey }) {
            return selectedScheduleDayKey
        }

        if let dayWithBookings = scheduleDays.first(where: { day in
            store.bookings.contains { booking in
                !booking.status.isCancellation &&
                    GroomerScheduleDateFormatting.dayKey(from: booking.scheduledStart) == day.id
            }
        }) {
            return dayWithBookings.id
        }

        return GroomerScheduleDateFormatting.dayKey(from: Date())
    }

    private var effectiveScheduleDate: Date {
        scheduleDays.first { $0.id == effectiveScheduleDayKey }?.date ?? Date()
    }

    private var selectedScheduleBookings: [Booking] {
        store.bookings
            .filter { booking in
                !booking.status.isCancellation &&
                    GroomerScheduleDateFormatting.dayKey(from: booking.scheduledStart) == effectiveScheduleDayKey
            }
            .sortedByScheduledStart(ascending: true)
    }
}

struct BookingSummaryRow: View {
    let booking: Booking
    let role: UserRole

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center) {
                    GroomlyStatusChip(
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
                    BookingAvatar(role: role)

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

private struct BookingAvatar: View {
    let role: UserRole

    var body: some View {
        Image(systemName: role == .customer ? "person.fill" : "person.crop.square.fill")
            .font(.title2.weight(.bold))
            .foregroundStyle(role.primaryColor)
            .frame(width: 64, height: 64)
            .background(role.primaryColor.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension Array where Element == Booking {
    func sortedByScheduledStart(ascending: Bool) -> [Booking] {
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

private enum BookingListScope: String, CaseIterable, Identifiable {
    case upcoming
    case past

    var id: Self { self }

    var title: String {
        switch self {
        case .upcoming:
            "Upcoming"
        case .past:
            "Past"
        }
    }

    var emptyTitle: String {
        switch self {
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

    func contains(_ booking: Booking) -> Bool {
        switch self {
        case .upcoming:
            booking.status == .confirmed
        case .past:
            booking.status != .confirmed
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
                                .groomlyShadow(DesignTokens.Shadows.smallCard)
                            }
                        }
                }
                .buttonStyle(.plain)
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

private struct GroomerScheduleDay: Identifiable, Equatable {
    let id: String
    let date: Date
    let isToday: Bool

    static func days(around date: Date, bookings: [Booking]) -> [GroomerScheduleDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        var dates = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: today)
        }
        var seenKeys = Set(dates.map(GroomerScheduleDateFormatting.dayKey(from:)))

        let bookingDates = bookings
            .filter { !$0.status.isCancellation }
            .compactMap { GroomingRequestDateFormatting.parsedDate(from: $0.scheduledStart) }
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 >= today }

        for bookingDate in bookingDates {
            let key = GroomerScheduleDateFormatting.dayKey(from: bookingDate)
            if seenKeys.insert(key).inserted {
                dates.append(bookingDate)
            }
        }

        return dates
            .sorted()
            .map { day in
                GroomerScheduleDay(
                    id: GroomerScheduleDateFormatting.dayKey(from: day),
                    date: day,
                    isToday: calendar.isDate(day, inSameDayAs: today)
                )
            }
    }
}

private struct GroomerScheduleDayStrip: View {
    let days: [GroomerScheduleDay]
    let selectedDayKey: String
    let onSelect: (GroomerScheduleDay) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.md) {
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
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text(GroomerScheduleDateFormatting.weekday(from: day.date))
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? Color.white.opacity(0.86) : DesignTokens.Colors.textTertiary)

            Text(GroomerScheduleDateFormatting.dayNumber(from: day.date))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(isSelected ? Color.white : DesignTokens.Colors.textPrimary)

            Text(day.isToday ? "Today" : GroomerScheduleDateFormatting.month(from: day.date))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : DesignTokens.Colors.textTertiary)
        }
        .frame(width: 76, height: 92)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? DesignTokens.Colors.groomerAccent : DesignTokens.Colors.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isSelected ? DesignTokens.Colors.groomerAccentDark.opacity(0.2) : DesignTokens.Colors.border,
                    lineWidth: 1.5
                )
        }
        .groomlyShadow(isSelected ? DesignTokens.Shadows.groomerAction : DesignTokens.Shadows.smallCard)
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerScheduleSnapshotCard: View {
    let dayTitle: String
    let bookings: [Booking]

    var body: some View {
        GroomlyCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .frame(width: 52, height: 52)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(dayTitle)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(snapshotSummary)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                    Text("\(bookings.count)")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(bookings.count == 1 ? "Booking" : "Bookings")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
        }
    }

    private var snapshotSummary: String {
        guard let nextBooking = bookings.first else {
            return "You have no confirmed appointments on this day."
        }

        return "Next appointment starts at \(BookingListDateFormatting.time(from: nextBooking.scheduledStart)). \(totalDurationSummary) booked."
    }

    private var totalDurationSummary: String {
        let minutes = bookings.reduce(0) { total, booking in
            guard
                let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
                let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd)
            else {
                return total
            }

            return total + max(0, Int(end.timeIntervalSince(start) / 60))
        }

        guard minutes > 0 else {
            return "Time"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(remainingMinutes)m"
        }

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }
}

private struct GroomerScheduleTimeline: View {
    let bookings: [Booking]
    let store: BookingsStore
    let onOpenChat: (Booking) -> Void

    var body: some View {
        LazyVStack(spacing: DesignTokens.Spacing.md) {
            ForEach(bookings) { booking in
                GroomerScheduleTimelineRow(
                    booking: booking,
                    store: store,
                    onOpenChat: onOpenChat
                )
            }
        }
        .accessibilityIdentifier("groomer.schedule.timeline")
    }
}

private struct GroomerScheduleTimelineRow: View {
    let booking: Booking
    let store: BookingsStore
    let onOpenChat: (Booking) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(BookingListDateFormatting.time(from: booking.scheduledStart))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Circle()
                    .fill(DesignTokens.Colors.groomerAccent)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(DesignTokens.Colors.groomerAccent.opacity(0.28), lineWidth: 6)
                    }

                Rectangle()
                    .fill(DesignTokens.Colors.borderSoft)
                    .frame(width: 2)
                    .frame(minHeight: 112)
            }
            .frame(width: 62)
            .padding(.top, DesignTokens.Spacing.md)

            GroomerScheduleAppointmentCard(
                booking: booking,
                store: store,
                onOpenChat: onOpenChat
            )
        }
    }
}

private struct GroomerScheduleAppointmentCard: View {
    let booking: Booking
    let store: BookingsStore
    let onOpenChat: (Booking) -> Void

    var body: some View {
        GroomlyCard(padding: 0) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                NavigationLink {
                    BookingDetailView(
                        bookingID: booking.id,
                        role: .groomer,
                        store: store,
                        onOpenChat: onOpenChat
                    )
                } label: {
                    cardHeader
                }
                .buttonStyle(.plain)

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button {
                        onOpenChat(booking)
                    } label: {
                        Text("Message")
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))

                    if booking.canComplete(for: .groomer) {
                        Button {
                            Task {
                                await store.complete(booking)
                            }
                        } label: {
                            Text("Complete")
                        }
                        .buttonStyle(GroomlyPrimaryButtonStyle(accent: .groomer))
                        .disabled(store.isCompleting)
                    } else {
                        Text(booking.status.title)
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.success)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .background(DesignTokens.Colors.success.opacity(0.13))
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: DesignTokens.CornerRadius.button,
                                    style: .continuous
                                )
                            )
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DesignTokens.Colors.groomerAccent)
                .frame(width: 5)
                .padding(.vertical, DesignTokens.Spacing.md)
        }
    }

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(booking.timeWindowSummary)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: DesignTokens.Spacing.sm)

                GroomlyStatusChip(
                    booking.status.title,
                    systemImage: booking.status.chipIcon,
                    tone: booking.status.chipTone(for: .groomer)
                )
            }

            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "pawprint.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .frame(width: 52, height: 52)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(booking.appointmentServiceTitle)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("\(booking.partnerDisplayTitle(for: .groomer)) · \(booking.scheduleLocationShortTitle)")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("Order #\(booking.referenceCode)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct CustomerTabTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignTokens.Spacing.sm)
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

private enum GroomerScheduleDateFormatting {
    static func dayKey(from value: String) -> String? {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return nil
        }

        return dayKey(from: date)
    }

    static func dayKey(from date: Date) -> String {
        format(date, pattern: "yyyy-MM-dd")
    }

    static func weekday(from date: Date) -> String {
        format(date, pattern: "EEE").uppercased()
    }

    static func dayNumber(from date: Date) -> String {
        format(date, pattern: "d")
    }

    static func month(from date: Date) -> String {
        format(date, pattern: "MMM")
    }

    static func longDayTitle(from date: Date) -> String {
        format(date, pattern: "EEEE, MMM d")
    }

    private static func format(_ date: Date, pattern: String) -> String {
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

    init(
        bookingID: UUID,
        role: UserRole,
        store: BookingsStore,
        onOpenChat: @escaping (Booking) -> Void = { _ in }
    ) {
        self.bookingID = bookingID
        self.role = role
        self.store = store
        self.onOpenChat = onOpenChat
    }

    var body: some View {
        if let booking = store.booking(withID: bookingID) {
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
                            systemImage: "calendar.badge.clock"
                        ) {
                            BookingDetailFactRow("Service", value: booking.appointmentServiceTitle)
                            BookingDetailFactRow("Date", value: BookingListDateFormatting.day(from: booking.scheduledStart))
                            BookingDetailFactRow("Time", value: booking.timeWindowSummary)
                            BookingDetailFactRow("Service Location", value: booking.appointmentLocationTitle)
                            BookingDetailFactRow("Address", value: booking.appointmentAddressSummary)
                            BookingDetailFactRow("Price", value: booking.priceSummary)
                        }

                        BookingPartnerOverviewCard(
                            booking: booking,
                            role: role,
                            onOpenChat: onOpenChat
                        )

                        if booking.status == .completed {
                            GroomlySectionHeader("Review")

                            if let review = booking.review {
                                BookingReviewDisplay(review: review)
                            } else if booking.canReview(for: role) {
                                BookingReviewForm(
                                    booking: booking,
                                    store: store,
                                    accent: role.primaryButtonAccent
                                )
                            } else {
                                GroomlyCard {
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
            }
            .navigationTitle("Booking")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("bookings.detail")
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                GroomlyEmptyState(
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

private struct BookingDetailHeroCard: View {
    let booking: Booking
    let role: UserRole

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .center) {
                    GroomlyStatusChip(
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
                    BookingAvatar(role: role)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(booking.detailTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(booking.detailSubtitle(for: role))
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct BookingDetailInfoCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                        .frame(width: 38, height: 38)
                        .background(DesignTokens.Colors.customerPrimary.opacity(0.15))
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
            systemImage: "person.fill"
        ) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                BookingAvatar(role: role)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(booking.partnerDisplayTitle(for: role))
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
            .buttonStyle(GroomlyPrimaryButtonStyle(accent: role.primaryButtonAccent))
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
        GroomlyCard {
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
    let accent: GroomlyPrimaryButtonStyle.Accent
    @State private var rating = 5
    @State private var content = ""
    @State private var fitOutcomeSelections: [BookingReviewPetFitOutcomeSelection]

    init(
        booking: Booking,
        store: BookingsStore,
        accent: GroomlyPrimaryButtonStyle.Accent
    ) {
        self.booking = booking
        self.store = store
        self.accent = accent
        _fitOutcomeSelections = State(
            initialValue: BookingReviewPetFitOutcomeSelection.defaults(
                for: booking.reviewableFitSignals
            )
        )
    }

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Picker("Rating", selection: $rating) {
                    ForEach(1...5, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .tint(DesignTokens.Colors.customerPrimary)
                .accessibilityIdentifier("bookings.review.rating")

                TextEditor(text: $content)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .groomlyFormField()
                    .accessibilityIdentifier("bookings.review.content")

                Text("Optional review text, up to 2,000 characters.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

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
                .buttonStyle(GroomlyPrimaryButtonStyle(accent: accent))
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

    var body: some View {
        VStack(spacing: 0) {
            GroomlyNoticeForwarder(message: store.noticeMessage) { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            }

            if hasInlineStatus {
                inlineStatus
            }
        }
    }

    private var inlineStatus: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if store.isCancelling {
                progressRow("Cancelling…")
            }

            if store.isCompleting {
                progressRow("Completing…")
            }

            if store.isSubmittingReview {
                progressRow("Submitting Review…")
            }

            if let errorMessage = store.errorMessage {
                GroomlyErrorBanner(
                    title: "Booking Update Failed",
                    message: errorMessage
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .animation(.easeInOut(duration: 0.24), value: hasInlineStatus)
    }

    private var hasInlineStatus: Bool {
        store.isCancelling ||
            store.isCompleting ||
            store.isSubmittingReview ||
            store.errorMessage != nil
    }

    private func progressRow(_ title: String) -> some View {
        GroomlyStatusProgressToast(title, tint: role.primaryColor)
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
    var primaryButtonAccent: GroomlyPrimaryButtonStyle.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var loadingAccent: GroomlyLoadingView.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var emptyStateAccent: GroomlyEmptyState<EmptyView>.Accent {
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
        }
    }

    func chipTone(for role: UserRole) -> GroomlyStatusChip.Tone {
        switch self {
        case .confirmed:
            role == .groomer ? .groomer : .customer
        case .completed:
            .success
        case .cancelledByCustomer, .cancelledByGroomer:
            .error
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
