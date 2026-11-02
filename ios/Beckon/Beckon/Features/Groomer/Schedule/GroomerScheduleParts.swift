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
                            GroomerDayTile(day: day, calendar: calendar, load: loads[day.id] ?? .empty, isSelected: isSelected)
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
        .accessibilityValue(load.count == 0 ? "Nothing booked" : "\(load.count) appointment\(load.count == 1 ? "" : "s")")
    }

    /// A track as long as the day's open hours, filled as far as they are booked. A day with nothing booked has no track but the
    /// same room, so every date stands on one line and choosing a day moves nothing.
    private var loadBar: some View {
        Color.clear
            .frame(width: DesignTokens.Metrics.dayLoadWidth, height: DesignTokens.Metrics.dayLoadHeight)
            .overlay {
                if load.count > 0 {
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var height = DesignTokens.Metrics.dayChipHeight

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(0..<(typeSize.isAccessibilitySize ? 4 : 7), id: \.self) { _ in
                DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.card)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            }
        }
        .designSkeletonOnPage()
        .designSkeleton(label: "Loading schedule")
    }
}


// MARK: The day's shape

/// The day as a strip of hours: the hours the groomer is open as a light band, each booking where it stands (done, under way, still
/// to come), and a line where now is. It says in a glance how full the day is; the rows say the rest.
struct GroomerDayShapeBar: View {
    let shape: GroomerDayShape

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            GeometryReader { proxy in
                let span = CGFloat(max(1, shape.visible.upperBound - shape.visible.lowerBound))
                let x: (Int) -> CGFloat = { CGFloat($0 - shape.visible.lowerBound) / span * proxy.size.width }
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
                    if let now = shape.now, shape.visible.contains(now) {
                        Capsule().fill(DesignTokens.Colors.textPrimary)
                            .frame(width: DesignTokens.Metrics.dayShapeNowLine, height: proxy.size.height + DesignTokens.Spacing.sm)
                            .offset(x: x(now) - 1)
                    }
                }
            }
            .frame(height: DesignTokens.Metrics.dayShapeHeight)
            HStack {
                Text(GroomerScheduleText.hour(shape.visible.lowerBound))
                Spacer(minLength: 0)
                Text(GroomerScheduleText.hour(shape.visible.upperBound))
            }
            .font(DesignTokens.Typography.Expressive.micro)
            .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
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


private struct GroomerDashLine: Shape {
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
    @Environment(\.dynamicTypeSize) private var typeSize

    private var booking: Booking { item.slot.booking }
    private var appointment: GroomerScheduleAppointmentPresentation { GroomerScheduleAppointmentPresentation(booking: booking) }
    private var isLive: Bool { item.phase == .live }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            header
            Button(action: onOpen) { who.contentShape(Rectangle()) }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityIdentifier(AppTestOpsAccessibility.requestIdentifier(prefix: "groomer.booking.row.request",
                    requestID: booking.requestID))
            if isLive { progress }
            place
            actions
        }
        .designBanner()
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

    private var header: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.sm))) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Circle().fill(DesignTokens.Colors.customerDeep)
                    .frame(width: DesignTokens.Metrics.liveDot, height: DesignTokens.Metrics.liveDot)
                Text(title)
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.customerTint, in: Capsule())
            if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.sm) }
            Text(timing)
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.customerInk)
        }
        .accessibilityElement(children: .combine)
    }

    private var who: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            GroomerPetAvatar(species: booking.requestPetSnapshot?.species ?? "Dog", size: DesignTokens.Metrics.petAvatar)
            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.petName)
                    .font(DesignTokens.Typography.Expressive.hero)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(appointment.petDetail)
                    .font(DesignTokens.Typography.Expressive.body)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// How far the service has got: minutes since it started against its length.
    private var progress: some View {
        let startedText = booking.fulfillment?.actualStartedAt ?? booking.scheduledStart
        let started = GroomingRequestDateFormatting.parsedDate(from: startedText) ?? item.slot.start
        let elapsed = max(0, Int(now.timeIntervalSince(started) / 60))
        let total = max(1, item.slot.minutes)
        let fraction = min(1, Double(elapsed) / Double(total))
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Capsule()
                .fill(DesignTokens.Colors.customerHeroBubble)
                .frame(height: DesignTokens.Metrics.dayShapeHeight - 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule().fill(DesignTokens.Colors.customerInk).frame(width: proxy.size.width * fraction)
                    }
                }
            HStack {
                Text("\(elapsed) of \(total) min")
                Spacer(minLength: DesignTokens.Spacing.sm)
                Text("Started \(clock(startedText))")
            }
            .font(DesignTokens.Typography.Expressive.chip)
            .foregroundStyle(DesignTokens.Colors.customerInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(elapsed) of \(total) minutes, started \(clock(startedText))")
    }

    private var place: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: booking.locationMode == .groomerComesToCustomer ? "car.fill" : "house.fill")
                .font(DesignTokens.Typography.Expressive.label)
            Text(GroomerScheduleText.place(of: booking))
                .font(DesignTokens.Typography.Expressive.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(DesignTokens.Colors.customerInk)
    }

    /// One primary on the card: Complete under way, Start service when its time has come, otherwise Message.
    @ViewBuilder
    private var actions: some View {
        let messageID = AppTestOpsAccessibility.requestIdentifier(prefix: "groomer.booking.message.request", requestID: booking.requestID)
        if let primary {
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.md))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))) {
                Button(action: onMessage) {
                    Image(systemName: "bubble.left.fill")
                        .font(DesignTokens.Typography.Expressive.glyph)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .frame(width: DesignTokens.Metrics.ledgeRoundControl, height: DesignTokens.Metrics.ledgeRoundControl)
                        .beckonLedge(.round)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.pill)
                .frame(width: DesignTokens.Metrics.chipBarShort, height: DesignTokens.Metrics.chipHeight)
            HStack(spacing: DesignTokens.Spacing.md) {
                DesignSkeletonDisc()
                    .frame(width: DesignTokens.Metrics.petAvatar, height: DesignTokens.Metrics.petAvatar)
                VStack(alignment: .leading, spacing: 0) {
                    DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.hero)
                    DesignSkeletonLine(width: 0.8, font: DesignTokens.Typography.Expressive.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            DesignSkeletonLine(width: 0.6, font: DesignTokens.Typography.Expressive.label)
            DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.ledgeButton)
                .frame(height: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        }
        .designSkeleton(label: "Loading appointments")
        .designBanner()
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
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth = DesignTokens.Metrics.timeColumnWidth

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                DesignSkeletonLine(width: 0.9, font: DesignTokens.Typography.Expressive.emphasis)
                DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.chip)
                DesignSkeletonLine(width: 0.6, font: DesignTokens.Typography.Expressive.chip)
            }
            .frame(width: timeWidth)
            DesignSkeletonDisc()
                .frame(width: DesignTokens.Metrics.petAvatarSmall, height: DesignTokens.Metrics.petAvatarSmall)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.title)
                DesignSkeletonLine(width: 0.8)
                DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.pill)
                    .frame(width: DesignTokens.Metrics.chipBarShort, height: DesignTokens.Metrics.chipHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .designSkeleton(label: "Loading appointments")
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .beckonLedge(.card)
    }
}
