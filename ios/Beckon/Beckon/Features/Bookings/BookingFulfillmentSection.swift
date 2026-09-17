import SwiftUI

struct BookingFulfillmentSection: View {
    let booking: Booking
    let store: BookingsStore
    @State private var selectedAction: BookingFulfillmentAction?
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            BeckonSectionHeader("Service Outcome")
            Text(booking.fulfillmentTitle).font(DesignTokens.Typography.headline)
            if booking.fulfillment == nil {
                Text("Service status has not been verified. Changes are unavailable until verification succeeds.")
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            Button("Refresh Outcome", systemImage: "arrow.clockwise") {
                Task { await store.refreshFulfillment(for: booking.id) }
            }
            if let state = booking.fulfillment {
                timestamp("Service Started", state.actualStartedAt)
                timestamp("Service Ended", state.actualEndedAt)
                if state.basis == "bilateral_retrospective" {
                    Text("Completion confirmed by both participants. Unrecorded service times remain unknown.")
                        .font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                if let release = state.resourceReleaseAt {
                    timestamp("Groomer Reserved Until", release)
                }
                if let report = state.reportNote {
                    Text(report).font(DesignTokens.Typography.body)
                }
            }
            if let message = store.errorMessage {
                Text(message).foregroundStyle(DesignTokens.Colors.errorText).font(DesignTokens.Typography.supporting)
            }
            if let message = store.noticeMessage {
                Text(message).font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            if let pending = store.pendingFulfillmentOperation(for: booking.id) {
                Text("\(pending.action.title): outcome not yet verified.").font(DesignTokens.Typography.supporting)
                Button {
                    Task { await store.recoverFulfillment(for: booking.id) }
                } label: {
                    Label("Check Status", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("booking.fulfillment.check")
                Button {
                    Task { await store.recoverFulfillment(for: booking.id, retryIfMissing: true) }
                } label: {
                    Label("Retry Original Operation", systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("booking.fulfillment.retry")
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        ForEach(store.fulfillmentActions(for: booking, now: context.date)) { action in
                            Button {
                                note = ""
                                selectedAction = action
                            } label: {
                                Label(action.title, systemImage: action.systemImage)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityIdentifier("booking.fulfillment.\(action.rawValue)")
                        }
                    }
                }
            }
            Divider()
            Text("Recent Service Activity").font(DesignTokens.Typography.headline)
            if let error = store.fulfillmentHistoryErrors[booking.id] {
                Text(error).font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textSecondary)
                Button("Retry", systemImage: "arrow.clockwise") {
                    Task { await store.loadFulfillmentHistory(for: booking.id) }
                }
            }
            ForEach(store.fulfillmentHistory[booking.id] ?? []) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Label(event.action.title, systemImage: event.action.systemImage).font(DesignTokens.Typography.fieldLabel)
                    Text(event.actorID == booking.customerID ? "Customer" : "Groomer")
                        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textSecondary)
                    timestamp("Recorded", event.recordedAt)
                    if let note = event.note { Text(note).font(DesignTokens.Typography.supporting) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disabled(store.isMutatingFulfillment)
        .task(id: booking.id) {
            if booking.fulfillment == nil { await store.refreshFulfillment(for: booking.id) }
            else { await store.loadFulfillmentHistory(for: booking.id) }
        }
        .sheet(item: $selectedAction) { action in
            NavigationStack {
                Form {
                    Section {
                        Text(action.confirmationMessage)
                        if action.requiresNote {
                            TextField("What happened?", text: $note, axis: .vertical)
                                .lineLimit(3...8)
                                .accessibilityIdentifier("booking.fulfillment.note")
                            if note.count > 500 {
                                Text("Use no more than 500 characters.").foregroundStyle(DesignTokens.Colors.errorText)
                            }
                        }
                    }
                    Section {
                        Button(action.title, systemImage: action.systemImage) {
                            selectedAction = nil
                            Task { await store.performFulfillment(action, for: booking, note: action.requiresNote ? note : nil) }
                        }
                        .disabled(store.isMutatingFulfillment || (action.requiresNote &&
                            (note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note.count > 500)))
                        .accessibilityIdentifier("booking.fulfillment.confirm")
                    }
                }
                .navigationTitle(action.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Dismiss") { selectedAction = nil }
                    }
                }
            }
        }
    }

    private func timestamp(_ title: String, _ raw: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 8)
            if let raw {
                Text(GroomingRequestDateFormatting.displayString(from: raw,
                    serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier))
                    .multilineTextAlignment(.trailing)
            } else {
                Text("Not recorded")
            }
        }
        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textSecondary)
    }
}

private extension BookingFulfillmentAction {
    var confirmationMessage: String {
        switch self {
        case .start: "Record the start of service now."
        case .complete: "Confirm the service is complete now. The agreed cleanup and travel buffer remains reserved."
        case .cancel: "Cancel this booking before service starts. The original request will not reopen."
        case .reportInterruption, .reportNoShow: "Describe what happened. This report does not release reserved time or assign fault; the other participant can confirm the outcome."
        case .confirmStop: "Confirm that service stopped or did not take place. This closes the booking without completion and releases remaining time after the agreed buffer."
        case .withdrawReport: "Withdraw your pending report and restore the previous service state. The activity record remains."
        case .closeElapsed: "Close the elapsed booking without confirmed completion. This does not assign fault or allow a review."
        case .reportCompletion: "Report that service took place. Completion requires the other participant's confirmation; missing actual times will not be invented."
        case .confirmCompletion: "Confirm the reported service took place. The booking becomes completed and the customer can leave a review."
        case .recordObjection: "Add your account to the service record. This does not change the booking outcome or automatically open a support case."
        }
    }
}
