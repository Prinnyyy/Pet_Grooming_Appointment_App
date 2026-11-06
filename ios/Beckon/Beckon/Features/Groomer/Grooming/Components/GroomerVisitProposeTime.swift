import SwiftUI
import Combine

struct GroomerVisitProposeTime: View {
    let booking: Booking
    let bookings: () -> [Booking]
    let submit: (Date) async -> String?
    @State private var feedback = BeckonFeedbackCenter()
    @State private var sending = false
    @State private var draft: GroomerVisitTimeProposalDraft
    @State private var editing = false
    @Environment(\.scenePhase) private var scenePhase
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    init(booking: Booking, bookings: @escaping () -> [Booking], submit: @escaping (Date) async -> String?) {
        self.booking = booking
        self.bookings = bookings
        self.submit = submit
        _draft = State(initialValue: GroomerVisitTimeProposalDraft(booking: booking))
    }

    private var zone: String? { booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier }
    private var end: Date? {
        guard let start = draft.proposedStart, let duration = draft.duration else { return nil }
        return start.addingTimeInterval(duration)
    }

    private func display(_ date: Date) -> String {
        GroomingRequestDateFormatting.displayString(from: GroomingRequestDateFormatting.serverString(from: date), serviceTimeZoneIdentifier: zone)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                BeckonLedgeHeading(title: "Propose new time", systemImage: "calendar.badge.clock")
                Text("Your customer can accept or decline. The current time stays booked until they accept.")
                    .designSupportingText()
                VStack(alignment: .leading, spacing: 0) {
                    GroomerVisitDetailRowGroup {
                        GroomerVisitBookedTimeRow(start: booking.scheduledStart, end: booking.scheduledEnd,
                            timeZoneIdentifier: zone, title: "Current appointment", systemImage: "calendar",
                            dateFont: DesignTokens.Typography.Expressive.emphasis,
                            timeFont: DesignTokens.Typography.Expressive.headline)
                        GroomerVisitDisclosureRow(systemImage: "calendar", title: "Proposed start",
                            value: draft.proposedStart.map(display) ?? "Choose a valid time", isExpanded: editing,
                            headerIdentifier: "booking.reschedule.start", onToggle: {
                                if !editing { draft.refreshMinimum() }
                                withAnimation(GroomerVisitDetailMotion.expansion(reduceMotion: reduceMotion)) { editing.toggle() }
                            }) { timePicker }
                            .groomerVisitKeyboardInputRegion()
                        GroomerVisitRequestFactRow(systemImage: "hourglass", title: "Service duration",
                            value: draft.duration.map { Duration.seconds($0).formatted(.units(allowed: [.hours, .minutes])) } ?? "Unavailable",
                            detail: end.map { "Ends " + display($0) })
                    }.padding(DesignTokens.Spacing.lg)
                }.clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)).beckonLedge(.card)
            }.padding(DesignTokens.Layout.pageHorizontalInset).padding(.top, DesignTokens.Spacing.md)
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { draft.refreshMinimum() } }
        .onReceive(clock) { _ in if scenePhase == .active { draft.refreshMinimum() } }
        .overlay(alignment: .bottom) {
            BeckonGlobalFeedbackOverlay(center: feedback, bottomPadding: DesignTokens.Spacing.sm)
        }
        .tint(DesignTokens.Colors.groomerDeep)
        .background(DesignTokens.Colors.appBackground)
        .safeAreaInset(edge: .bottom) {
            GroomerVisitFooterColumns(gap: DesignTokens.Spacing.md) {
                Button("Cancel") { dismiss() }.buttonStyle(GroomerVisitRequestFooterActionStyle(tone: .secondary))
                Button(sending ? "Sending…" : "Propose time", systemImage: "paperplane.fill") {
                    guard !sending else { return }
                    let previous = draft.selectedStart
                    draft.refreshMinimum()
                    guard previous == draft.selectedStart, draft.hasChanged, let start = draft.proposedStart else { return }
                    if let error = GroomerVisitRescheduleValidation.message(booking: booking, start: start, bookings: bookings()) {
                        feedback.showNotice(error)
                        return
                    }
                    sending = true
                    Task { @MainActor in
                        let error = await submit(start)
                        sending = false
                        if let error {
                            feedback.showNotice(error)
                        } else { dismiss() }
                    }
                }.labelStyle(GroomerVisitFooterLabelStyle()).buttonStyle(GroomerVisitRequestFooterActionStyle())
                    .disabled(sending || end == nil || !draft.hasChanged)
            }.padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
                .padding(.vertical, DesignTokens.Layout.actionAreaInset)
                .background(DesignTokens.Colors.appBackground)
        }
        .groomerVisitDismissKeyboardOnOutsideTap(isEditing: editing) {
            withAnimation(GroomerVisitDetailMotion.expansion(reduceMotion: reduceMotion)) { editing = false }
        }
    }

    private var serviceCalendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        if let zone, let tz = TimeZone(identifier: zone) { value.timeZone = tz }
        return value
    }

    private var timePicker: some View {
        @Bindable var draft = draft
        return DatePicker("Proposed start", selection: $draft.selectedStart,
            in: draft.minimumStart..., displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.wheel).labelsHidden()
            .environment(\.timeZone, serviceCalendar.timeZone)
            .environment(\.calendar, serviceCalendar)
            .frame(maxWidth: .infinity).clipped()
    }

}

/// Shared by the sheet and isolated repository; touching endpoints are allowed.
enum GroomerVisitRescheduleValidation {
    static let conflictMessage = "This time overlaps another booking. Please choose a different time."
    static func message(booking: Booking, start: Date, bookings: [Booking], now: Date = .now) -> String? {
        guard start > now else { return "Choose a future date and time." }
        guard let original = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
              let originalEnd = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd), originalEnd > original else {
            return "The appointment time is unavailable. Please refresh and try again."
        }
        let end = start.addingTimeInterval(originalEnd.timeIntervalSince(original))
        let overlaps = bookings.contains { other in
            guard other.id != booking.id, other.groomerID == booking.groomerID, other.status == .confirmed,
                  let from = GroomingRequestDateFormatting.parsedDate(from: other.scheduledStart),
                  let to = GroomingRequestDateFormatting.parsedDate(from: other.scheduledEnd) else { return false }
            return start < to && end > from
        }
        return overlaps ? conflictMessage : nil
    }
}

@Observable @MainActor
private final class GroomerVisitTimeProposalDraft {
    let booking: Booking
    var selectedStart: Date
    var minimumStart: Date

    init(booking: Booking) {
        self.booking = booking
        let minimum = Self.nextMinute()
        minimumStart = minimum
        selectedStart = max(GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart) ?? minimum, minimum)
    }

    private static func nextMinute() -> Date {
        Date(timeIntervalSince1970: (floor(Date().timeIntervalSince1970 / 60) + 1) * 60)
    }

    func refreshMinimum() {
        minimumStart = Self.nextMinute()
        if selectedStart < minimumStart { selectedStart = minimumStart }
    }

    var proposedStart: Date? { selectedStart }

    var hasChanged: Bool {
        guard let proposedStart, let original = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart) else { return false }
        // Compare actual instants at the minute precision exposed by the picker.
        return floor(proposedStart.timeIntervalSince1970 / 60) != floor(original.timeIntervalSince1970 / 60)
    }

    var duration: TimeInterval? {
        guard let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
              let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd) else { return nil }
        return end.timeIntervalSince(start)
    }
}
