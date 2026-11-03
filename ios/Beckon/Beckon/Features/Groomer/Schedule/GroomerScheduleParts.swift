// The pieces of the groomer's Schedule (design): a week that says how busy each day is, the day's shape, the big card for what is
// happening now or comes next, the short rows after it, the free time between two of them, and the bars they leave while they wait.
// The page that holds them is GroomerScheduleView.swift; what they say comes from GroomerSchedulePlan.swift.
import SwiftUI


// MARK: Days

/// How busy a day is: how many bookings it has, and how much of its open hours they fill (0 to 1).
struct GroomerDayLoad: Equatable {
    let count: Int
    let fraction: Double

    /// A day with a booking never shows less than a sliver, and one past its hours never more than full.
    init(count: Int, bookedMinutes: Int, openMinutes: Int) {
        self.count = count
        fraction = count == 0 ? 0 : min(1, max(0.15, Double(bookedMinutes) / Double(max(1, openMinutes))))
    }

    static let empty = GroomerDayLoad(count: 0, bookedMinutes: 0, openMinutes: 1)
}


/// The next days and the days with a booking, as tiles on the ledge: seven fit the width, the rest scroll; the chosen one is the
/// coral pill and scrolls into view. Under each date a short bar says how full the day is: how much of its open hours its bookings
/// take, the same thing the day's strip of hours shows for the day on the page (a count of dots said the same for four bookings as
/// for eight, design).
struct GroomerDayStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let days: [GroomerScheduleDay]
    let calendar: Calendar
    let selectedDayKey: String
    /// How full each day is, by day key.
    let loads: [String: GroomerDayLoad]
    let onSelect: (GroomerScheduleDay) -> Void
    var loadsAreKnown = true

    private let spacing = DesignTokens.Spacing.xs

    /// Tiles in the room of the strip: fewer as the type grows, so a date never has to be squeezed.
    private var columns: Int { typeSize.isAccessibilitySize ? 4 : (typeSize >= .xxxLarge ? 5 : 7) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(days) { day in
                        let isSelected = day.id == selectedDayKey
                        Button { onSelect(day) } label: {
                            GroomerDayTile(day: day, calendar: calendar, load: loads[day.id] ?? .empty, isSelected: isSelected,
                                isKnown: loadsAreKnown)
                        }
                        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .containerRelativeFrame(.horizontal, count: columns, spacing: spacing)
                        .id(day.id)
                    }
                }
                .padding(.bottom, DesignTokens.Ledge.pill)
            }
            .scrollClipDisabled()
            .onChange(of: selectedDayKey) { _, key in
                withAnimation(reduceMotion ? nil : DesignTokens.Motion.reveal) { proxy.scrollTo(key, anchor: .center) }
            }
        }
        .accessibilityIdentifier("groomer.schedule.days")
    }
}


private struct GroomerDayTile: View {
    @ScaledMetric(relativeTo: .caption) private var height = DesignTokens.Metrics.dayChipHeight
    let day: GroomerScheduleDay
    let calendar: Calendar
    let load: GroomerDayLoad
    let isSelected: Bool
    var isKnown = true

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs / 2) {
            Text(GroomerScheduleDateFormatting.weekday(from: day.date, calendar: calendar))
                .font(DesignTokens.Typography.Expressive.caption)
                .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk
                    : (day.isToday ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.textSecondary))
            Text(GroomerScheduleDateFormatting.dayNumber(from: day.date, calendar: calendar))
                .font(DesignTokens.Typography.Expressive.title)
                .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
            loadBar
        }
        .frame(maxWidth: .infinity, minHeight: height)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GroomerScheduleDateFormatting.longDayTitle(from: day.date, calendar: calendar) + (day.isToday ? ", today" : ""))
        .accessibilityValue(isKnown ? (load.count == 0 ? "Nothing booked" : "\(load.count) appointment\(load.count == 1 ? "" : "s")") : "Not yet verified")
    }

    /// A track as long as the day's open hours, filled as far as they are booked. A day with nothing booked has no track but the
    /// same room, so every date stands on one line and choosing a day moves nothing.
    private var loadBar: some View {
        Color.clear
            .frame(width: DesignTokens.Metrics.dayLoadWidth, height: DesignTokens.Metrics.dayLoadHeight)
            .overlay {
                if !isKnown {
                    Capsule().fill(DesignTokens.Colors.skeleton)
                } else if load.count > 0 {
                    Capsule()
                        .fill(isSelected ? DesignTokens.Colors.customerTint : DesignTokens.Colors.border)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.customerDeep)
                                .frame(width: DesignTokens.Metrics.dayLoadWidth * load.fraction)
                        }
                }
            }
    }
}


struct GroomerDayStripSkeleton: View {
    var calendar: Calendar?
    var body: some View {
        let calendar = calendar ?? Calendar.current
        let start = calendar.startOfDay(for: Date())
        let days = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            return GroomerScheduleDay(id: "\(offset)", date: date, isToday: offset == 0)
        }
        // Calendar-only sizing data; no booking or availability is invented.
        GroomerDayStrip(days: days, calendar: calendar, selectedDayKey: "0", loads: [:], onSelect: { _ in })
        .redacted(reason: .placeholder)
        .designSkeletonOnPage()
        .designSkeleton(label: "Loading schedule")
    }
}


// MARK: The day's shape

/// Loading and verified content share the centered date/badge and summary geometry.
/// The device calendar is used only to size masked placeholders, never as an account time zone.
struct GroomerScheduleDayHeader: View {
    let date: Date
    let calendar: Calendar?
    let isToday: Bool
    let summary: String?
    var isLoading = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
                : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.sm))) {
                GroomerScheduleHeaderText(text: GroomerScheduleDateFormatting.longDayTitle(from: date,
                    calendar: calendar ?? .current), isLoading: calendar == nil)
                    .font(DesignTokens.Typography.Expressive.section)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if isToday {
                    GroomerScheduleHeaderText(text: "Today", isLoading: calendar == nil)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(DesignTokens.Colors.customerTint, in: Capsule())
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.sm) }
            }
            // Reserve the summary line even on an empty day; refresh never inserts a new row.
            GroomerScheduleHeaderText(text: summary ?? "Appointments · duration · total", isLoading: isLoading)
                .designSupportingText()
                .lineLimit(1)
                .opacity(summary != nil || isLoading ? 1 : 0)
                .accessibilityHidden(summary == nil)
                .accessibilityIdentifier("groomer.schedule.summary")
        }
        .designSkeletonOnPage()
    }
}

private struct GroomerScheduleHeaderText: View {
    let text: String
    let isLoading: Bool
    var body: some View {
        if isLoading {
            Text(text).hidden().overlay {
                DesignSkeletonBlock(cornerRadius: 4)
                    .mask(Text(text).redacted(reason: .placeholder))
            }
            .designSkeleton(label: nil)
            .accessibilityHidden(true)
        } else { Text(text) }
    }
}

struct GroomerDayShapeBarSkeleton: View {
    var body: some View {
        GroomerDayShapeBar(shape: nil)
            .designSkeleton(label: nil)
            .accessibilityHidden(true)
    }
}

/// One track/tick layout for verified and loading days. Data owns the range; state never changes its geometry.
struct GroomerDayShapeBar: View {
    let shape: GroomerDayShape?
    private var visible: ClosedRange<Int> { shape?.visible ?? (8 * 60)...(18 * 60) }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            GeometryReader { proxy in
                let span = CGFloat(max(1, visible.upperBound - visible.lowerBound))
                let x: (Int) -> CGFloat = { CGFloat($0 - visible.lowerBound) / span * proxy.size.width }
                ZStack(alignment: .leading) {
                    if let shape {
                        ZStack(alignment: .leading) {
                            Capsule().fill(DesignTokens.Colors.border)
                            if let open = shape.open {
                                Capsule().fill(DesignTokens.Colors.surface)
                                    .frame(width: max(0, x(open.upperBound) - x(open.lowerBound)))
                                    .offset(x: x(open.lowerBound))
                            }
                            ForEach(shape.segments) { segment in
                                Capsule().fill(color(of: segment.kind))
                                    .frame(width: max(6, x(segment.to) - x(segment.from)), height: proxy.size.height - 4)
                                    .offset(x: x(segment.from))
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipShape(Capsule())
                        // Keep the clock marker inside the same track height.
                        .overlay(alignment: .leading) {
                            if let now = shape.now, visible.contains(now) {
                                Capsule().fill(DesignTokens.Colors.textPrimary)
                                    .frame(width: DesignTokens.Metrics.dayShapeNowLine,
                                        height: proxy.size.height)
                                    .offset(x: min(max(0, x(now) - DesignTokens.Metrics.dayShapeNowLine / 2),
                                        max(0, proxy.size.width - DesignTokens.Metrics.dayShapeNowLine)))
                            }
                        }
                    } else {
                        DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.round)
                    }
                }
            }
            .frame(height: DesignTokens.Metrics.dayShapeHeight)
            // Preserve the shared strip-to-label spacing in loaded and skeleton states.
            .frame(height: DesignTokens.Metrics.dayShapeHeight + DesignTokens.Spacing.sm)
            HStack {
                GroomerScheduleHeaderText(text: GroomerScheduleText.hour(visible.lowerBound), isLoading: shape == nil)
                Spacer(minLength: 0)
                GroomerScheduleHeaderText(text: GroomerScheduleText.hour(visible.upperBound), isLoading: shape == nil)
            }
            .font(DesignTokens.Typography.Expressive.micro)
            .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
        .designSkeletonOnPage()
        .accessibilityHidden(true)
    }

    private func color(of kind: GroomerDayShape.Kind) -> Color {
        switch kind {
        case .done: DesignTokens.Colors.customerHeroBubble
        case .live: DesignTokens.Colors.customerDeep
        case .ahead: DesignTokens.Colors.customerFill
        }
    }
}


// MARK: Free time

/// What stands between two bookings, on the line that joins them: the time that is free between the end of one and the start of the
/// next, or that they touch or overlap.
struct GroomerFreeTimeLine: View {
    let freeTime: GroomerFreeTime

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            dash
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: symbol)
                Text(text)
            }
            .font(DesignTokens.Typography.Expressive.chip)
            .foregroundStyle(freeTime == .overlap ? DesignTokens.Colors.statusWarningText : DesignTokens.Colors.textTertiary)
            dash
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("groomer.schedule.free-time")
    }

    private var symbol: String { freeTime == .overlap ? "exclamationmark.triangle.fill" : "clock" }

    private var text: String {
        switch freeTime {
        case .free(let minutes): "\(GroomerScheduleText.duration(minutes: minutes)) free"
        case .backToBack: "Back to back"
        case .overlap: "Overlaps"
        }
    }

    private var dash: some View {
        GroomerDashLine()
            .stroke(DesignTokens.Colors.border, style: StrokeStyle(lineWidth: DesignTokens.Ledge.edgeWidth,
                lineCap: .round, dash: DesignTokens.Ledge.dash))
            .frame(height: DesignTokens.Ledge.edgeWidth)
    }
}


private nonisolated struct GroomerDashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}


// MARK: The now card

/// What is happening now, or comes next, on today's page: the coral card. Under way it shows how far the service has got and offers
/// Complete; when its time has come it offers Start service; before that it offers Message. The words that open the booking are the
/// card's own button, like a row's.
/// The same four anchored slots own the empty, appointment and placeholder footprint.
/// Width follows the page inset; heights depend only on Dynamic Type, never model strings.
struct GroomerScheduleFocusCard<Header: View, Identity: View, Detail: View, Actions: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let identity: () -> Identity
    @ViewBuilder let detail: () -> Detail
    @ViewBuilder let actions: () -> Actions
    var skeletonLabel: String? = nil
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var headerHeight = DesignTokens.Layout.scheduleFocusHeaderHeight
    @ScaledMetric(relativeTo: .body) private var identityHeight = DesignTokens.Layout.scheduleFocusIdentityHeight
    @ScaledMetric(relativeTo: .body) private var detailHeight = DesignTokens.Layout.scheduleFocusDetailHeight
    @ScaledMetric(relativeTo: .body) private var actionHeight = DesignTokens.Metrics.ledgePrimaryButtonHeight

    var body: some View {
        Group {
            if let skeletonLabel { slots.designSkeleton(label: skeletonLabel) }
            else { slots }
        }
        .designBanner()
    }

    private var slots: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            header().frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: typeSize.isAccessibilitySize ? headerHeight * 2 : headerHeight, alignment: .topLeading).clipped()
            identity().frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: identityHeight, alignment: .center).clipped()
            detail().frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: detailHeight, alignment: .topLeading).clipped()
            ZStack(alignment: .bottom) {
                Color.clear.allowsHitTesting(false)
                actions().frame(maxWidth: .infinity, alignment: .leading)
            }
                .frame(height: (typeSize.isAccessibilitySize ? actionHeight * 2 + DesignTokens.Spacing.md : actionHeight)
                    + DesignTokens.Ledge.room, alignment: .bottom).clipped()
        }
    }
}

struct GroomerScheduleEmptyCard: View {
    let note: String
    var isClosed = false
    var hours: String? = nil
    var onSeeRequests: (() -> Void)?

    var body: some View {
        GroomerScheduleFocusCard {
            GroomerFocusHeader(title: isClosed ? "Day off" : "Your day")
        } identity: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: isClosed ? "moon.zzz.fill" : "calendar")
                    .font(DesignTokens.Typography.Expressive.hero)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .frame(width: DesignTokens.Metrics.petAvatar, height: DesignTokens.Metrics.petAvatar)
                    .background(DesignTokens.Colors.customerHeroBubble, in: Circle())
                    .accessibilityHidden(true)
                Text("Nothing booked")
                    .font(DesignTokens.Typography.Expressive.hero)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } detail: {
            if let hours, !isClosed {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Label("Open hours", systemImage: "clock").font(DesignTokens.Typography.Expressive.label)
                    Text(hours).font(DesignTokens.Typography.Expressive.emphasis).lineLimit(1)
                }.foregroundStyle(DesignTokens.Colors.customerInk)
            } else {
                Text(note).font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.customerInk).lineLimit(2)
            }
        } actions: {
            if let onSeeRequests, !isClosed {
                Button(action: onSeeRequests) {
                    DesignActionLabel(title: "See new requests", systemImage: "tray.full")
                }
                .buttonStyle(BeckonLedgeButtonStyle(.primary))
                .accessibilityIdentifier("groomer.schedule.requests")
            }
        }
        .accessibilityIdentifier("groomer.schedule.empty")
    }
}

struct GroomerNowCard: View {
    let item: GroomerSchedulePlan.Item
    let calendar: Calendar
    let now: Date
    /// A service action is running: the buttons wait.
    var isBusy = false
    let onOpen: () -> Void
    let onMessage: () -> Void
    var onStart: (() -> Void)?
    var onComplete: (() -> Void)?

    private var booking: Booking { item.slot.booking }
    private var appointment: GroomerScheduleAppointmentPresentation { GroomerScheduleAppointmentPresentation(booking: booking) }
    private var isLive: Bool { item.phase == .live }

    var body: some View {
        GroomerScheduleFocusCard {
            header
        } identity: {
            Button(action: onOpen) { who.contentShape(Rectangle()) }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityIdentifier(AppTestOpsAccessibility.requestIdentifier(prefix: "groomer.booking.row.request",
                    requestID: booking.requestID))
        } detail: {
            VStack(alignment: .leading, spacing: isLive ? DesignTokens.Spacing.xs : DesignTokens.Spacing.sm) {
                if isLive { progress }
                else { GroomerFocusTiming(isLive: false, timing: timing,
                    duration: GroomerScheduleText.duration(minutes: item.slot.minutes)) }
                place
            }
        } actions: {
            actions
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.schedule.now")
    }

    // MARK: Words

    private func clock(_ value: String) -> String { GroomerScheduleDateFormatting.time(from: value, calendar: calendar) }

    private var title: String {
        switch item.phase {
        case .live: "In service"
        case .due: "Time to start"
        default: "Next"
        }
    }

    private var timing: String {
        switch item.phase {
        case .live: now < item.slot.end ? "Ends \(clock(booking.scheduledEnd))" : "Was due \(clock(booking.scheduledEnd))"
        case .due: "Due \(clock(booking.scheduledStart))"
        default: "Starts \(clock(booking.scheduledStart))"
        }
    }

    // MARK: Parts

    private var header: some View { GroomerFocusHeader(title: title, price: booking.priceSummary) }

    private var who: some View {
        GroomerFocusIdentity(species: booking.requestPetSnapshot?.species ?? "Dog", name: appointment.petName,
            detail: appointment.petDetail)
    }

    /// How far the service has got: minutes since it started against its length.
    private var progress: some View {
        let startedText = booking.fulfillment?.actualStartedAt ?? booking.scheduledStart
        let started = GroomingRequestDateFormatting.parsedDate(from: startedText) ?? item.slot.start
        let elapsed = max(0, Int(now.timeIntervalSince(started) / 60))
        let total = max(1, item.slot.minutes)
        let fraction = min(1, Double(elapsed) / Double(total))
        return GroomerFocusTiming(isLive: true, timing: timing,
            duration: GroomerScheduleText.duration(minutes: total), started: "Started \(clock(startedText))", fraction: fraction)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(elapsed) of \(total) minutes, started \(clock(startedText)), \(timing)")
    }

    private var place: some View {
        GroomerFocusPlace(symbol: booking.locationMode == .groomerComesToCustomer ? "car.fill" : "house.fill",
            text: GroomerScheduleText.place(of: booking))
    }

    /// One primary on the card: Complete under way, Start service when its time has come, otherwise Message.
    @ViewBuilder
    private var actions: some View {
        let messageID = AppTestOpsAccessibility.requestIdentifier(prefix: "groomer.booking.message.request", requestID: booking.requestID)
        if let primary {
            GroomerFocusActionLayout {
                Button(action: onMessage) {
                    GroomerFocusMessageGlyph().beckonLedge(.round)
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityLabel("Message")
                .accessibilityIdentifier(messageID)

                Button(action: primary.action) {
                    DesignActionLabel(title: primary.title, systemImage: primary.systemImage)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.primary))
                .disabled(isBusy)
                .accessibilityIdentifier(AppTestOpsAccessibility.requestIdentifier(prefix: primary.identifier, requestID: booking.requestID))
            }
        } else {
            Button(action: onMessage) {
                DesignActionLabel(title: "Message", systemImage: "bubble.left.fill")
            }
            .buttonStyle(BeckonLedgeButtonStyle(.primary))
            .accessibilityIdentifier(messageID)
        }
    }

    private var primary: (title: String, systemImage: String, identifier: String, action: () -> Void)? {
        if let onComplete { return ("Complete", "checkmark.circle.fill", "groomer.booking.complete.request", onComplete) }
        if let onStart { return ("Start service", "play.circle.fill", "groomer.booking.start.request", onStart) }
        return nil
    }
}


struct GroomerNowCardSkeleton: View {
    var body: some View {
        GroomerScheduleFocusCard {
            GroomerFocusHeader(title: "In service", price: "$00.00", isSkeleton: true)
        } identity: {
            GroomerFocusIdentity(species: "Dog", name: "Name", detail: "Breed · Service", isSkeleton: true)
        } detail: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                GroomerFocusTiming(isLive: true, timing: "Ends 12:00 PM", duration: "30 min",
                    started: "Started 11:30 AM", isSkeleton: true)
                GroomerFocusPlace(symbol: "car.fill", text: "Service location and city", isSkeleton: true)
            }
        } actions: {
            GroomerFocusActionLayout {
                GroomerFocusMessageGlyph(isSkeleton: true).beckonLedge(.round)
                DesignActionLabel(title: "Complete", systemImage: "checkmark.circle.fill")
                    .scheduleFocusPlaceholder(true, cornerRadius: DesignTokens.CornerRadius.ledgeButton)
                    .beckonLedge(.primary)
            }
        }
        .withLoadingLabel()
    }
}

private extension GroomerScheduleFocusCard {
    func withLoadingLabel() -> Self {
        var copy = self
        copy.skeletonLabel = "Loading appointments"
        return copy
    }

}


// MARK: Rows

/// One appointment as a short row: when it starts and how long it is on the left, who and what in the middle, the message button on
/// the right. Only what is out of the ordinary gets a status; the ordinary says where it is (Mobile, Studio). The text part opens
/// the booking. A service under way that is not the card's offers Complete under the row.
struct GroomerAppointmentRow: View {
    let item: GroomerSchedulePlan.Item
    let calendar: Calendar
    var isBusy = false
    let onOpen: () -> Void
    let onMessage: () -> Void
    var onComplete: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth = DesignTokens.Metrics.timeColumnWidth

    private var booking: Booking { item.slot.booking }
    private var appointment: GroomerScheduleAppointmentPresentation { GroomerScheduleAppointmentPresentation(booking: booking) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                Button(action: onOpen) {
                    summary
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityIdentifier(AppTestOpsAccessibility.requestIdentifier(prefix: "groomer.booking.row.request",
                    requestID: booking.requestID))
                if !typeSize.isAccessibilitySize {
                    Button(action: onMessage) {
                        DesignIconDisc(systemImage: "bubble.left.fill", size: .touch)
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .accessibilityLabel("Message")
                    .accessibilityIdentifier(messageIdentifier)
                }
            }
            if typeSize.isAccessibilitySize {
                Button(action: onMessage) { DesignQuietAction(title: "Message", systemImage: "bubble.left.fill") }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .accessibilityIdentifier(messageIdentifier)
            }
            if let onComplete {
                Button(action: onComplete) { DesignActionLabel(title: "Complete", systemImage: "checkmark.circle.fill") }
                    .buttonStyle(BeckonLedgeButtonStyle(.pill))
                    .disabled(isBusy)
                    .accessibilityIdentifier(AppTestOpsAccessibility.requestIdentifier(prefix: "groomer.booking.complete.request",
                        requestID: booking.requestID))
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .beckonLedge(.card)
    }

    private var messageIdentifier: String {
        AppTestOpsAccessibility.requestIdentifier(prefix: "groomer.booking.message.request", requestID: booking.requestID)
    }

    private var summary: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            timeColumn
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                GroomerPetAvatar(species: booking.requestPetSnapshot?.species ?? "Dog",
                    size: DesignTokens.Metrics.petAvatarSmall)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appointment.petName)
                        .font(DesignTokens.Typography.Expressive.title)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(appointment.petDetail).designSupportingText()
                    chip.padding(.top, DesignTokens.Spacing.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// "11:40", "AM" and "2h": when it starts and how long it takes.
    private var timeColumn: some View {
        let parts = GroomerScheduleDateFormatting.time(from: booking.scheduledStart, calendar: calendar).split(separator: " ")
        return VStack(alignment: .leading, spacing: 0) {
            Text(parts.first.map(String.init) ?? "")
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
            Text(parts.last.map(String.init) ?? "")
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            Text(GroomerScheduleText.duration(minutes: item.slot.minutes))
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
        .frame(width: typeSize.isAccessibilitySize ? nil : timeWidth, alignment: .leading)
        .fixedSize(horizontal: typeSize.isAccessibilitySize, vertical: false)
    }

    @ViewBuilder
    private var chip: some View {
        switch item.phase {
        case .done: BeckonStatusChip(booking.status.presentation)
        case .live: BeckonStatusChip(.agendaInService)
        case .due: BeckonStatusChip(.agendaReady)
        case .needsClosing: BeckonStatusChip(.agendaNeedsClosing)
        case .waiting(let words): BeckonStatusChip(.agendaWaiting(words))
        case .upcoming:
            BeckonMetaChip(text: appointment.location, systemImage: appointment.location == "Studio" ? "house.fill" : "car.fill")
        }
    }
}


struct GroomerAppointmentRowSkeleton: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth = DesignTokens.Metrics.timeColumnWidth

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                (typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
                    : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))) {
                    VStack(alignment: .leading, spacing: 0) {
                        DesignSkeletonLine(width: 0.9, font: DesignTokens.Typography.Expressive.emphasis)
                        DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.chip)
                        DesignSkeletonLine(width: 0.6, font: DesignTokens.Typography.Expressive.chip)
                    }
                    .frame(width: typeSize.isAccessibilitySize ? nil : timeWidth, alignment: .leading)
                    HStack(spacing: DesignTokens.Spacing.md) {
                        DesignSkeletonDisc()
                            .frame(width: DesignTokens.Metrics.petAvatarSmall, height: DesignTokens.Metrics.petAvatarSmall)
                        VStack(alignment: .leading, spacing: 2) {
                            DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.title)
                            DesignSkeletonLine(width: 0.8)
                            BeckonMetaChip(text: "Mobile", systemImage: "car.fill")
                                .hidden().overlay { DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.pill) }
                                .padding(.top, DesignTokens.Spacing.xs)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if !typeSize.isAccessibilitySize {
                    DesignSkeletonDisc()
                        .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                }
            }
            if typeSize.isAccessibilitySize {
                DesignQuietAction(title: "Message", systemImage: "bubble.left.fill")
                    .hidden().overlay { DesignSkeletonLine(width: 0.4) }
            }
        }
        .designSkeleton(label: "Loading appointments")
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .beckonLedge(.card)
    }
}
