// The groomer's Schedule, redesigned in the customer prototype's language with the groomer's coral (design) and then as an agenda
// (design). The job is the real one (the groomer branch of Features/Bookings/BookingsView.swift): pick a day, read how it is booked,
// go through its appointments (open one, message the customer, start and complete a service), and know the schedule's time zone.
// The store (`BookingsStore`), the day's own read and its "not verified" state, the presentation rules (`GroomerSchedulePresentation`)
// and every id are the real ones. What is new is the order of the page: a week that says how busy each day is, the day in one
// line and one strip of hours, what is happening now or comes next as the big card (today), the rest as short rows with the free
// time between them, and what is behind below. The pieces are in GroomerScheduleParts.swift, the arrangement in
// GroomerSchedulePlan.swift.
import SwiftUI


struct GroomerScheduleView: View {
    let store: BookingsStore
    @Binding var focusedBooking: Booking?
    let isActiveTab: Bool
    let onOpenChat: (Booking) -> Void
    /// Where an empty day can send the groomer: the requests that could fill it. Without it the empty day has no button.
    var onSeeRequests: (() -> Void)?
    @State private var selectedDayKey: String?
    @State private var isPickingDay = false
    @State private var pickedDate = Date()
    @State private var isSettled = false
    @State private var windowStart: Date?
    private var workingHours: [GroomerAvailabilityWindow] { store.scheduleAvailabilityWindows }
    @State private var serviceAction: BookingFulfillmentAction?
    @State private var serviceActionBooking: Booking?

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                    titleRow.beckonEntrance(0)
                    content
                }
                .beckonPageInsets()
                .beckonEntranceClock()
            }
            .scrollContentBackground(.hidden)
            .beckonTracksScroll()
            .refreshable { await refresh(forceRefresh: true) }
            .accessibilityIdentifier("groomer.schedule")
        }
        .toolbar(.hidden, for: .navigationBar)
        .beckonNavigationDestination(item: $focusedBooking) { booking in
            BookingDetailView(bookingID: booking.id, role: .groomer, store: store, onOpenChat: onOpenChat)
        }
        .background {
            BookingsStatusView(store: store, role: .groomer, presentation: feedbackPresentation)
        }
        .foregroundRefreshable(isEnabled: isActiveTab) { await refresh(forceRefresh: false) }
        .designModal(isPresented: $isPickingDay) {
            DesignModal(systemImage: "calendar", title: "Go to a day", actions: [
                .primary("Show this day", systemImage: "checkmark", identifier: "groomer.schedule.pick-day.confirm") { showPickedDay() },
                .quiet("Cancel", identifier: "groomer.schedule.pick-day.cancel"),
            ]) {
                DatePicker("Appointment date", selection: $pickedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(DesignTokens.Colors.customerDeep)
                    .environment(\.calendar, store.scheduleCalendar ?? .current)
                    .environment(\.timeZone, store.scheduleCalendar?.timeZone ?? .current)
            }
        }
        // The same question the booking page asks before a service starts: the card's Start service goes through it.
        .groomingFulfillmentDialog(action: $serviceAction) { action, note in
            guard let booking = serviceActionBooking else { return }
            Task { await store.performFulfillment(action, for: booking, note: note) }
        }
    }

    private var feedbackPresentation: BookingsFeedbackPresentation {
        BookingsFeedbackPresentation(role: .groomer, bookings: store.bookings, isLoading: store.isLoading,
            errorMessage: store.errorMessage)
    }

    private func refresh(forceRefresh: Bool) async {
        await store.load()
        guard !Task.isCancelled else { return }
        if let calendar = store.scheduleCalendar {
            await store.loadSchedule(interval: weekInterval(calendar: calendar), forceRefresh: forceRefresh)
        }
        guard !Task.isCancelled, store.scheduleReadState != .loading else { return }
        isSettled = true
    }

    var titleRow: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            BeckonPageTitle("Schedule")
            Button {
                pickedDate = presentation?.selectedDate ?? Date()
                isPickingDay = true
            } label: {
                Image(systemName: "calendar")
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                    .beckonLedge(.round)
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityLabel("Go to a day")
            .accessibilityIdentifier("groomer.schedule.pick-day")
            .disabled(store.scheduleCalendar == nil)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        DesignReveal(isLoading: !isSettled && !hasCurrentWeekSnapshot) {
            if let calendar = store.scheduleCalendar {
                loaded(calendar: calendar)
            } else {
                unavailable
            }
        } placeholder: {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                GroomerDayStripSkeleton(calendar: store.scheduleCalendar)
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                    GroomerScheduleDayHeader(date: presentation?.selectedDate ?? Date(), calendar: store.scheduleCalendar,
                        isToday: store.scheduleCalendar?.isDateInToday(presentation?.selectedDate ?? Date()) ?? true,
                        summary: nil, isLoading: true)
                    GroomerDayShapeBarSkeleton()
                }
                GroomerNowCardSkeleton()
                GroomerAppointmentRowSkeleton()
            }
            .accessibilityIdentifier("groomer.schedule.loading")
        }
        .beckonEntrance(1)
    }

    /// The day the page shows and what is booked on it, by the real presentation rules.
    private var presentation: GroomerSchedulePresentation? {
        guard let calendar = store.scheduleCalendar else { return nil }
        return agenda(calendar: calendar)
    }

    private var hasCurrentWeekSnapshot: Bool {
        guard let calendar = store.scheduleCalendar else { return false }
        return store.scheduleInterval == weekInterval(calendar: calendar) && store.scheduleVerifiedAt != nil
    }

    private func weekInterval(calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: windowStart ?? Date())
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
    }

    private func agenda(calendar: Calendar) -> GroomerSchedulePresentation {
        let interval = weekInterval(calendar: calendar)
        let days = (0..<7).compactMap { offset -> GroomerScheduleDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            return GroomerScheduleDay(id: GroomerScheduleDateFormatting.dayKey(from: date, calendar: calendar),
                date: date, isToday: calendar.isDateInToday(date))
        }
        let key = selectedDayKey ?? days.first?.id
        let bookings = store.scheduleBookings.filter {
            !$0.status.isCancellation && GroomerScheduleDateFormatting.dayKey(from: $0.scheduledStart, calendar: calendar) == key
        }
        return GroomerSchedulePresentation(referenceDate: Date(), bookings: store.bookings, selectedDayKey: key,
            scopedBookings: bookings, calendar: calendar, displayedDays: days)
    }

    private var isServiceBusy: Bool { store.isCompleting || store.isCancelling || store.isMutatingFulfillment }

    private func loaded(calendar: Calendar) -> some View {
        let presentation = agenda(calendar: calendar)
        let interval = calendar.dateInterval(of: .day, for: presentation.selectedDate)
        let scope = weekInterval(calendar: calendar)
        let scopeMatches = store.scheduleInterval == scope
        let read = GroomerScheduleReadPresentation(scopeMatches: scopeMatches, verifiedAt: store.scheduleVerifiedAt,
            state: store.scheduleReadState, calendarState: store.scheduleCalendarReadState)
        return VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
            if let message = store.appointmentReminderNotice {
                GroomingReminderNotice(message: message)
                    .accessibilityIdentifier("bookings.appointment-reminder-notice")
            }

            GroomerDayStrip(days: presentation.days, calendar: calendar, selectedDayKey: presentation.selectedDayKey,
                loads: dayLoads(presentation, calendar: calendar, hasSnapshot: read.hasSnapshot), onSelect: {
                selectedDayKey = $0.id
            }, loadsAreKnown: read.hasSnapshot)

            // The clock moves the day on: what is due, what ran over, how far a service has got. A minute is as fine as it needs.
            TimelineView(.everyMinute) { context in
                day(presentation, calendar: calendar, interval: interval, scopeMatches: scopeMatches, read: read, now: context.date)
            }
        }
        .task(id: "\(isActiveTab):\(scope.start):\(store.scheduleRefreshID)") {
            guard isActiveTab else { return }
            await store.loadSchedule(interval: scope, forceRefresh: false)
            guard !Task.isCancelled, store.scheduleReadState != .loading else { return }
            isSettled = true
        }
    }

    /// How full each day is, for the bars under the dates: the day on the page by its own verified read, the others by the list.
    /// The open hours are the groomer's for that weekday; when they are not known the day is the same ten hours its strip shows.
    private func dayLoads(_ presentation: GroomerSchedulePresentation, calendar: Calendar, hasSnapshot: Bool) -> [String: GroomerDayLoad] {
        var byDay: [String: [Booking]] = [:]
        for booking in store.scheduleBookings where hasSnapshot && !booking.status.isCancellation {
            if let key = GroomerScheduleDateFormatting.dayKey(from: booking.scheduledStart, calendar: calendar) {
                byDay[key, default: []].append(booking)
            }
        }
        if hasSnapshot { byDay[presentation.selectedDayKey] = presentation.selectedBookings }
        var loads: [String: GroomerDayLoad] = [:]
        for day in presentation.days {
            let bookings = byDay[day.id] ?? []
            let window = GroomerScheduleHours.window(on: day.date, calendar: calendar, in: workingHours)
            let open = GroomerScheduleHours.open(window).map { $0.upperBound - $0.lowerBound }
            loads[day.id] = GroomerDayLoad(count: bookings.count,
                bookedMinutes: bookings.reduce(0) { $0 + (GroomerScheduleSlot($1)?.minutes ?? 0) },
                openMinutes: open ?? GroomerScheduleHours.unknownOpenMinutes)
        }
        return loads
    }

    // MARK: The day

    private func day(_ presentation: GroomerSchedulePresentation, calendar: Calendar, interval: DateInterval?, scopeMatches: Bool,
                     read: GroomerScheduleReadPresentation, now: Date) -> some View {
        let isToday = presentation.days.first { $0.id == presentation.selectedDayKey }?.isToday ?? false
        let slots = presentation.selectedBookings.compactMap { GroomerScheduleSlot($0) }
        let plan = GroomerSchedulePlan(slots: slots, now: now, isToday: isToday)
        let window = GroomerScheduleHours.window(on: presentation.selectedDate, calendar: calendar, in: workingHours)
        let dayTitle = GroomerScheduleDateFormatting.longDayTitle(from: presentation.selectedDate, calendar: calendar)
        let price = presentation.selectedBookings.reduce(0) { $0 + $1.priceEstimate }
        let summary = presentation.summary.map {
            GroomerScheduleText.summary(count: $0.bookingCount, durationSummary: $0.totalDurationSummary, price: price)
        }
        return VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                GroomerScheduleDayHeader(date: presentation.selectedDate, calendar: calendar, isToday: isToday,
                    summary: read.hasSnapshot ? (presentation.selectedBookings.isEmpty ? "0 appointments" : summary) : nil, isLoading: read.showsPlaceholder)
                if read.showsPlaceholder {
                    GroomerDayShapeBarSkeleton()
                } else if scopeMatches {
                    GroomerDayShapeBar(shape: GroomerDayShape(items: plan.sequence + plan.behind,
                        dayStart: calendar.startOfDay(for: presentation.selectedDate),
                        open: GroomerScheduleHours.open(window), now: isToday ? now : nil))
                }
            }

            if read.showsPlaceholder {
                GroomerNowCardSkeleton()
                GroomerAppointmentRowSkeleton()
                    .accessibilityIdentifier("groomer.schedule.loading")
            } else if read.showsVerificationWarning {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    BeckonLedgeNote(systemImage: "exclamationmark.triangle.fill",
                        text: "This day's schedule is not verified. Refresh before relying on its availability.")
                    Button {
                        Task { await store.loadSchedule(interval: weekInterval(calendar: calendar)) }
                    } label: {
                        DesignQuietAction(title: "Refresh Day", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                }
            }

            if read.hasSnapshot && presentation.selectedBookings.isEmpty {
                emptyDay(dayTitle: dayTitle, window: window)
            } else if scopeMatches && !presentation.selectedBookings.isEmpty {
                appointments(plan, calendar: calendar, now: now)
            }
        }
    }

    /// Today: the big card, then what is ahead with the free time between, then what is behind. Any other day: the list.
    private func appointments(_ plan: GroomerSchedulePlan, calendar: Calendar, now: Date) -> some View {
        let sequence = plan.sequence
        return VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(Array(sequence.enumerated()), id: \.element.id) { index, item in
                    if index > 0, sequence[index - 1].slot.start <= item.slot.start {
                        GroomerFreeTimeLine(freeTime: GroomerFreeTime(from: sequence[index - 1].slot, to: item.slot))
                    }
                    if item.id == plan.focus?.id {
                        nowCard(item, calendar: calendar, now: now)
                    } else {
                        row(item, calendar: calendar, now: now)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("groomer.schedule.timeline")

            if !plan.behind.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                    BeckonLedgeHeading(title: "Earlier today", systemImage: "checkmark.circle.fill", count: plan.behind.count)
                    VStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(plan.behind) { row($0, calendar: calendar, now: now) }
                    }
                }
            }
        }
    }

    private func nowCard(_ item: GroomerSchedulePlan.Item, calendar: Calendar, now: Date) -> some View {
        let booking = item.slot.booking
        let canStart = store.fulfillmentActions(for: booking, now: now).contains(.start)
        return GroomerNowCard(item: item, calendar: calendar, now: now, isBusy: isServiceBusy,
            onOpen: { focusedBooking = booking }, onMessage: { onOpenChat(booking) },
            onStart: canStart ? { requestStart(booking) } : nil,
            onComplete: booking.canComplete(for: .groomer, now: now) ? { complete(booking) } : nil)
    }

    private func row(_ item: GroomerSchedulePlan.Item, calendar: Calendar, now: Date) -> some View {
        let booking = item.slot.booking
        return GroomerAppointmentRow(item: item, calendar: calendar, isBusy: isServiceBusy,
            onOpen: { focusedBooking = booking }, onMessage: { onOpenChat(booking) },
            onComplete: booking.canComplete(for: .groomer, now: now) ? { complete(booking) } : nil)
    }

    private func complete(_ booking: Booking) {
        Task { await store.complete(booking) }
    }

    private func requestStart(_ booking: Booking) {
        serviceActionBooking = booking
        serviceAction = .start
    }

    /// The empty day occupies the same coral focus-card slots as a confirmed appointment.
    private func emptyDay(dayTitle: String, window: GroomerAvailabilityWindow?) -> some View {
        GroomerScheduleEmptyCard(note: emptyDayNote(dayTitle: dayTitle, window: window),
            isClosed: window?.isEnabled == false,
            hours: window.flatMap { $0.isEnabled ? $0.timeRangeSummary.replacingOccurrences(of: " - ", with: " – ") : nil },
            onSeeRequests: onSeeRequests)
    }

    private func emptyDayNote(dayTitle: String, window: GroomerAvailabilityWindow?) -> String {
        guard let window else { return "Confirmed bookings for \(dayTitle) will appear here." }
        guard window.isEnabled else { return "You're not open on \(window.weekday.title)s." }
        return "You're open \(window.timeRangeSummary.replacingOccurrences(of: " - ", with: " – "))."
    }

    /// The schedule's time zone is read from the availability settings; without it days cannot be cut, so the bookings are a plain list.
    private var unavailable: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            BeckonErrorBanner(title: "Schedule time zone unavailable",
                message: "Check your availability settings or try again.") {
                Button { Task { await store.load() } } label: {
                    DesignQuietAction(title: "Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(store.isLoading)
            }
            ForEach(store.bookings.sortedByScheduledStart(ascending: true)) { booking in
                Button { focusedBooking = booking } label: {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(booking.appointmentServiceTitle)
                            .font(DesignTokens.Typography.Expressive.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                        Text(booking.scheduledTimeSummary).designSupportingText()
                        Text(booking.status.title)
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.card))
                .accessibilityIdentifier("groomer.schedule.fallback.\(booking.id.uuidString)")
            }
            if store.canLoadMore || store.isLoadingMore {
                BeckonLoadMoreButton(isLoading: store.isLoadingMore, accent: .groomer,
                    accessibilityIdentifier: "groomer.schedule.load-more") { await store.loadNextPage() }
            }
        }
        .accessibilityIdentifier("groomer.schedule.time-zone-unavailable")
    }

    private func showPickedDay() {
        guard let calendar = store.scheduleCalendar else { return }
        if !weekInterval(calendar: calendar).contains(pickedDate) { windowStart = calendar.startOfDay(for: pickedDate) }
        selectedDayKey = GroomerScheduleDateFormatting.dayKey(from: pickedDate, calendar: calendar)
    }
}
