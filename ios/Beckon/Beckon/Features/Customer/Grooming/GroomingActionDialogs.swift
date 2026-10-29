// The two confirmations of a grooming's booking (a service action such as cancel or report, and a time change) as the prototype's own
// dialogs (S-089: was BookingActionDialogs.swift, the snapshot of Features/Bookings/BookingActionDialogs.swift).
// They used to be unstyled system `Form` sheets sliding up from the bottom (S-041). A decision with a sentence of consequence is an
// alert dialog; one that also collects something (a note, a new time) is a modal. Same data and actions as the sheets they replace.
import SwiftUI


/// A time change the person is about to confirm: which action, and the proposal it answers (nil when proposing a new time).
struct GroomingRescheduleSelection: Identifiable {
    let id = UUID()
    let action: BookingRescheduleAction
    let proposal: BookingRescheduleProposal?
}


extension View {
    /// Asks before a service action runs. Cancel, stop and close ask as an alert dialog (the safe answer is the pill); an action
    /// that needs a note ("What happened?") is a modal with the field, and its button waits for the note.
    func groomingFulfillmentDialog(action: Binding<BookingFulfillmentAction?>,
                                           confirm: @escaping @MainActor (BookingFulfillmentAction, String?) -> Void) -> some View {
        let asksOnly = Binding<BookingFulfillmentAction?>(
            get: { action.wrappedValue.flatMap { $0.requiresNote ? nil : $0 } },
            set: { if $0 == nil { action.wrappedValue = nil } })
        let asksNote = Binding<BookingFulfillmentAction?>(
            get: { action.wrappedValue.flatMap { $0.requiresNote ? $0 : nil } },
            set: { if $0 == nil { action.wrappedValue = nil } })
        return self
            .designAlertDialog(item: asksOnly) { item in
                if item.isDestructive {
                    .destructive(title: item.title, message: item.confirmationMessage, systemImage: item.systemImage,
                        keepTitle: item == .cancel ? "Keep booking" : "Not now", confirmTitle: item.title,
                        confirmSystemImage: item.systemImage, confirmIdentifier: "booking.fulfillment.confirm") { confirm(item, nil) }
                } else {
                    .confirmation(title: item.title, message: item.confirmationMessage, systemImage: item.systemImage,
                        confirmTitle: item.title, confirmSystemImage: item.systemImage,
                        confirmIdentifier: "booking.fulfillment.confirm") { confirm(item, nil) }
                }
            }
            .designModal(item: asksNote) { item in
                let draft = GroomingNoteDraft()
                return DesignModal(systemImage: item.systemImage, tone: item.isDestructive ? .caution : .customer,
                    title: item.title, message: item.confirmationMessage, actions: [
                        .primary(item.title, systemImage: item.systemImage, identifier: "booking.fulfillment.confirm",
                            isEnabled: { draft.isValid }) { confirm(item, draft.note) },
                        .quiet("Cancel", identifier: "dialog.cancel"),
                    ]) { GroomingNoteField(draft: draft) }
            }
    }

    /// Asks before a time change is sent. Proposing a new time is a modal with the time picker (its button waits for a valid time);
    /// answering a proposal is a modal that shows the two times.
    func groomingRescheduleDialog(selection: Binding<GroomingRescheduleSelection?>, booking: Booking?,
                                          confirm: @escaping @MainActor (GroomingRescheduleSelection, Date?) -> Void) -> some View {
        designModal(item: selection) { item in
            guard let booking else {
                return DesignModal(systemImage: "exclamationmark.circle", title: "Booking unavailable",
                    message: "Refresh this grooming before changing its time.", actions: [.quiet("Close")])
            }
            let draft = GroomingProposalDraft(booking: booking)
            let isPropose = item.action == .propose
            return DesignModal(systemImage: "calendar.badge.clock", title: item.action.title,
                message: isPropose
                    ? "The service, duration, price, pet, participants, location and buffers stay unchanged. The original appointment remains confirmed until both participants accept a valid new time."
                    : item.action == .accept
                        ? "The service, duration, price, pet, participants, location and buffers stay unchanged. Accepting replaces the original appointment only if the new time is still available."
                        : "The service, duration, price, pet, participants, location and buffers stay unchanged. The original appointment remains confirmed until both participants accept a valid new time.",
                actions: [
                    .primary(item.action.title, systemImage: "calendar.badge.checkmark", identifier: "booking.reschedule.confirm",
                        isEnabled: { !isPropose || (draft.proposedStart != nil && draft.duration != nil) }) {
                        confirm(item, isPropose ? draft.proposedStart : nil)
                    },
                    .quiet("Cancel", identifier: "dialog.cancel"),
                ]) { GroomingTimeFields(draft: draft, proposal: item.proposal, isPropose: isPropose) }
        }
    }
}


// MARK: Note for a service report

@Observable @MainActor
private final class GroomingNoteDraft {
    var note = ""
    var isValid: Bool { !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && note.count <= 500 }
}


private struct GroomingNoteField: View {
    @Bindable var draft: GroomingNoteDraft

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            TextField("What happened?", text: $draft.note, axis: .vertical)
                .lineLimit(3...6)
                .beckonFormField(isInvalid: draft.note.count > 500)
                .accessibilityLabel("What happened? Required")
                .accessibilityIdentifier("booking.fulfillment.note")
            if draft.note.count > 500 {
                BeckonInlineError("Use no more than 500 characters.")
            }
        }
    }
}


// MARK: Times of a change

/// The new start the person is choosing, and what follows from it (the end, whether the local time exists or is ambiguous).
@Observable @MainActor
private final class GroomingProposalDraft {
    let booking: Booking
    var proposedWallTime = Date() { didSet { selectedOccurrence = nil } }
    var selectedOccurrence: Date?

    init(booking: Booking) {
        self.booking = booking
        if let zone = booking.serviceTimeZoneIdentifier,
           let original = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
           let input = try? GroomingServiceTiming.wallInput(for: original.addingTimeInterval(3600), timeZoneIdentifier: zone) {
            proposedWallTime = input
            selectedOccurrence = nil
        }
    }

    var resolution: GroomingWallTimeResolution? {
        guard let zone = booking.serviceTimeZoneIdentifier else { return nil }
        return try? GroomingServiceTiming.resolveWallInput(proposedWallTime, timeZoneIdentifier: zone)
    }

    var proposedStart: Date? {
        switch resolution {
        case .unique(let date): return date
        case let .ambiguous(first, last):
            return selectedOccurrence == first || selectedOccurrence == last ? selectedOccurrence : nil
        case .nonexistent, nil: return nil
        }
    }

    var duration: TimeInterval? {
        guard let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
              let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd) else { return nil }
        return end.timeIntervalSince(start)
    }
}


private struct GroomingTimeFields: View {
    @Bindable var draft: GroomingProposalDraft
    let proposal: BookingRescheduleProposal?
    let isPropose: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if isPropose {
                DesignValueRow(title: "Original time", value: draft.booking.scheduledTimeSummary, systemImage: "clock")
                DatePicker("Proposed start", selection: $draft.proposedWallTime, displayedComponents: [.date, .hourAndMinute])
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                    .environment(\.calendar, Calendar(identifier: .gregorian))
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .accessibilityIdentifier("booking.reschedule.start")
                if case let .ambiguous(first, last) = draft.resolution {
                    Picker("Start Occurrence", selection: $draft.selectedOccurrence) {
                        Text("Choose occurrence").tag(Optional<Date>.none)
                        ForEach([first, last], id: \.self) { date in
                            Text(GroomingRequestDateFormatting.displayString(
                                from: GroomingRequestDateFormatting.serverString(from: date),
                                serviceTimeZoneIdentifier: draft.booking.serviceTimeZoneIdentifier)).tag(Optional(date))
                        }
                    }
                    .pickerStyle(.menu)
                }
                if draft.resolution == .nonexistent {
                    BeckonInlineError("This local time does not exist. Choose another start time.")
                }
                if let start = draft.proposedStart, let duration = draft.duration {
                    DesignValueRow(title: "Proposed end", value: GroomingRequestDateFormatting.displayString(
                        from: GroomingRequestDateFormatting.serverString(from: start.addingTimeInterval(duration)),
                        serviceTimeZoneIdentifier: draft.booking.serviceTimeZoneIdentifier), systemImage: "clock.badge.checkmark")
                }
            } else if let proposal {
                GroomingRescheduleTimes(booking: draft.booking, proposal: proposal)
            }
            Text("Service time zone: \(draft.booking.serviceTimeZoneIdentifier ?? "Unverified")")
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


struct GroomingRescheduleTimes: View {
    let booking: Booking
    let proposal: BookingRescheduleProposal
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            DesignFactRow(systemImage: "clock", title: "Original time",
                value: summary(proposal.previousAgreement.scheduledStart, proposal.previousAgreement.scheduledEnd))
            DesignFactRow(systemImage: "calendar.badge.clock", title: "Proposed time",
                value: summary(proposal.proposedStart, proposal.proposedEnd))
        }
    }
    private func summary(_ start: String, _ end: String) -> String {
        let zone = booking.serviceTimeZoneIdentifier
        return BeckonDateTimeFormatter.interval(from: start, to: end, serviceTimeZoneIdentifier: zone).summary
    }
}
