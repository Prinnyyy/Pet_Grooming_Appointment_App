import SwiftUI

private struct BookingRescheduleReview: Identifiable {
    let id = UUID()
    let action: BookingRescheduleAction
    let booking: Booking
    let proposal: BookingRescheduleProposal?
}

struct BookingRescheduleSection: View {
    let booking: Booking
    let store: BookingsStore
    @State private var review: BookingRescheduleReview?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            BeckonSectionHeader("Appointment Changes")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let proposal = store.rescheduleSnapshots[booking.id]?.proposal {
                    Text(proposal.currentStatus(for: booking, now: context.date).title)
                        .font(DesignTokens.Typography.headline)
                    BookingRescheduleTimes(booking: booking, proposal: proposal)
                    Text(proposal.initiatorID == booking.customerID ? "Proposed by Customer" : "Proposed by Groomer")
                        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textSecondary)
                    if proposal.currentStatus(for: booking, now: context.date) == .pending {
                        Text("Reply before " + GroomingRequestDateFormatting.displayString(from: proposal.expiresAt,
                            serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier))
                            .font(DesignTokens.Typography.supporting)
                        Text("The original appointment remains confirmed. The proposed time is not reserved.")
                            .font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }
                if store.pendingRescheduleOperation(for: booking.id) == nil {
                    ForEach(store.rescheduleActions(for: booking, now: context.date)) { action in
                        Button(action.title, systemImage: action == .propose ? "calendar.badge.clock" : "checkmark.circle") {
                            review = BookingRescheduleReview(action: action, booking: booking,
                                proposal: store.rescheduleSnapshots[booking.id]?.proposal)
                        }
                        .accessibilityIdentifier("booking.reschedule.\(action.rawValue)")
                    }
                }
            }
            if let error = store.rescheduleErrors[booking.id] {
                Text(error).font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.errorText)
            }
            if let notice = store.appointmentReminderNotice {
                Text(notice).font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            if let pending = store.pendingRescheduleOperation(for: booking.id) {
                Text("\(pending.action.title): result not yet verified.").font(DesignTokens.Typography.supporting)
                Button("Check Change Status", systemImage: "arrow.clockwise") {
                    Task { await store.recoverReschedule(for: booking.id) }
                }
                Button("Retry Original Change", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await store.recoverReschedule(for: booking.id, retryIfMissing: true) }
                }
            } else {
                Button("Refresh Time Changes", systemImage: "arrow.clockwise") {
                    Task { await store.loadReschedule(for: booking.id) }
                }
            }
        }
        .disabled(store.isMutatingReschedule || store.isMutatingFulfillment)
        .task(id: booking.id) { await store.loadReschedule(for: booking.id) }
        .sheet(item: $review) { selection in
            BookingRescheduleConfirmation(booking: selection.booking, proposal: selection.proposal,
                action: selection.action) { newStart in
                review = nil
                Task { await store.performReschedule(selection.action, for: selection.booking,
                    reviewedProposal: selection.proposal, newStart: newStart) }
            }
        }
    }
}

private struct BookingRescheduleTimes: View {
    let booking: Booking
    let proposal: BookingRescheduleProposal
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Original Time").font(DesignTokens.Typography.fieldLabel)
            Text(summary(proposal.previousAgreement.scheduledStart, proposal.previousAgreement.scheduledEnd))
                .font(DesignTokens.Typography.body)
            Text("Proposed Time").font(DesignTokens.Typography.fieldLabel)
            Text(summary(proposal.proposedStart, proposal.proposedEnd)).font(DesignTokens.Typography.body)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    private func summary(_ start: String, _ end: String) -> String {
        let zone = booking.serviceTimeZoneIdentifier
        return "\(GroomingRequestDateFormatting.displayString(from: start, serviceTimeZoneIdentifier: zone)) - \(GroomingRequestDateFormatting.displayString(from: end, serviceTimeZoneIdentifier: zone))"
    }
}

struct BookingRescheduleConfirmation: View {
    let booking: Booking
    let proposal: BookingRescheduleProposal?
    let action: BookingRescheduleAction
    let onConfirm: (Date?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var proposedWallTime = Date()
    @State private var selectedOccurrence: Date?

    private var resolution: GroomingWallTimeResolution? {
        guard let zone = booking.serviceTimeZoneIdentifier else { return nil }
        return try? GroomingServiceTiming.resolveWallInput(proposedWallTime, timeZoneIdentifier: zone)
    }
    private var proposedStart: Date? {
        switch resolution {
        case .unique(let date): return date
        case let .ambiguous(first, last):
            return selectedOccurrence == first || selectedOccurrence == last ? selectedOccurrence : nil
        case .nonexistent, nil: return nil
        }
    }
    private var duration: TimeInterval? {
        guard let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
              let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd) else { return nil }
        return end.timeIntervalSince(start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if action == .propose {
                        Text("Original Time").font(DesignTokens.Typography.fieldLabel)
                        Text(booking.scheduledTimeSummary).font(DesignTokens.Typography.body)
                        DatePicker("Proposed Start", selection: $proposedWallTime, displayedComponents: [.date, .hourAndMinute])
                            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                            .environment(\.calendar, Calendar(identifier: .gregorian))
                            .onChange(of: proposedWallTime) { _, _ in selectedOccurrence = nil }
                        if case let .ambiguous(first, last) = resolution {
                            Picker("Start Occurrence", selection: $selectedOccurrence) {
                                Text("Choose occurrence").tag(Optional<Date>.none)
                                ForEach([first, last], id: \.self) { date in
                                    Text(GroomingRequestDateFormatting.displayString(
                                        from: GroomingRequestDateFormatting.serverString(from: date),
                                        serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier)).tag(Optional(date))
                                }
                            }
                        }
                        if resolution == .nonexistent {
                            Text("This local time does not exist. Choose another start time.")
                                .foregroundStyle(DesignTokens.Colors.errorText)
                        }
                        if let proposedStart, let duration {
                            Text("Proposed End").font(DesignTokens.Typography.fieldLabel)
                            Text(GroomingRequestDateFormatting.displayString(
                                from: GroomingRequestDateFormatting.serverString(from: proposedStart.addingTimeInterval(duration)),
                                serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier))
                        }
                    } else if let proposal {
                        BookingRescheduleTimes(booking: booking, proposal: proposal)
                    }
                    Text("Service Time Zone: \(booking.serviceTimeZoneIdentifier ?? "Unverified")")
                        .font(DesignTokens.Typography.caption)
                }
                Section {
                    Text("The service, duration, price, pet, participants, location and buffers stay unchanged.")
                    if action == .accept {
                        Text("Accepting replaces the original appointment only if the new time is still available.")
                    } else {
                        Text("The original appointment remains confirmed until both participants accept a valid new time.")
                    }
                }
                Section {
                    Button(action.title, systemImage: "calendar.badge.checkmark") {
                        onConfirm(action == .propose ? proposedStart : nil)
                    }
                    .disabled(action == .propose && (proposedStart == nil || duration == nil))
                    .accessibilityIdentifier("booking.reschedule.confirm")
                }
            }
            .font(DesignTokens.Typography.body)
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Dismiss") { dismiss() } } }
            .task {
                guard action == .propose, let zone = booking.serviceTimeZoneIdentifier,
                      let original = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
                      let input = try? GroomingServiceTiming.wallInput(for: original.addingTimeInterval(3600), timeZoneIdentifier: zone) else { return }
                proposedWallTime = input
            }
        }
    }
}
