import SwiftUI

struct BookingFulfillmentSection: View {
    let booking: Booking
    let store: BookingsStore
    let role: UserRole
    @State private var selectedAction: BookingFulfillmentAction?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            BeckonSectionHeader("Service outcome")
            Text(booking.fulfillmentTitle).font(DesignTokens.Typography.headline)
            if booking.fulfillment == nil {
                Text("Service status has not been verified. Changes are unavailable until verification succeeds.")
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            if let state = booking.fulfillment {
                if state.phase != .scheduled && state.phase != .cancelled {
                    timestamp("Service started", state.actualStartedAt)
                    timestamp("Service ended", state.actualEndedAt)
                }
                if state.basis == "bilateral_retrospective" {
                    Text("Completion confirmed by both participants. Unrecorded service times remain unknown.")
                        .font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                if let release = state.resourceReleaseAt {
                    timestamp("Groomer reserved until", release)
                }
                if let report = state.reportNote {
                    Text(report).font(DesignTokens.Typography.body)
                }
            }
            if let message = store.errorMessage {
                BeckonErrorBanner(title: "Operation not completed", message: message)
            }
            if let message = store.noticeMessage {
                Text(message).font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            if let pending = store.pendingFulfillmentOperation(for: booking.id) {
                Text("\(pending.action.title): outcome not yet verified.").font(DesignTokens.Typography.supporting)
                Button {
                    Task { await store.recoverFulfillment(for: booking.id) }
                } label: {
                    Label("Check status", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("booking.fulfillment.check")
                Button {
                    Task { await store.recoverFulfillment(for: booking.id, retryIfMissing: true) }
                } label: {
                    Label("Retry original operation", systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("booking.fulfillment.retry")
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        ForEach(store.fulfillmentActions(for: booking, now: context.date)) { action in
                            actionButton(action)
                        }
                    }
                }
            }
            Button("Refresh Outcome", systemImage: "arrow.clockwise") {
                Task { await store.refreshFulfillment(for: booking.id) }
            }
            .accessibilityIdentifier("booking.fulfillment.refresh")
            Divider()
            Text("Recent service activity").font(DesignTokens.Typography.headline).accessibilityAddTraits(.isHeader)
            if let error = store.fulfillmentHistoryErrors[booking.id] {
                Text(error).font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textTertiary)
                Button("Retry", systemImage: "arrow.clockwise") {
                    Task { await store.loadFulfillmentHistory(for: booking.id) }
                }
            }
            ForEach(store.fulfillmentHistory[booking.id] ?? []) { event in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Label(event.action.title, systemImage: event.action.systemImage).font(DesignTokens.Typography.fieldLabel)
                    Text(event.actorID == booking.customerID ? "Customer" : "Groomer")
                        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                    timestamp("Recorded", event.recordedAt)
                    if let note = event.note { Text(note).font(DesignTokens.Typography.supporting) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let events = store.fulfillmentHistory[booking.id], events.isEmpty {
                Text("No service activity recorded yet.")
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
        }
        .buttonStyle(BeckonSecondaryButtonStyle(accent: role == .customer ? .customer : .groomer))
        .disabled(store.isMutatingFulfillment || store.isMutatingReschedule)
        .task(id: booking.id) {
            if booking.fulfillment == nil { await store.refreshFulfillment(for: booking.id) }
            else { await store.loadFulfillmentHistory(for: booking.id) }
        }
        .bookingFulfillmentDialog(action: $selectedAction) { action, note in
            Task { await store.performFulfillment(action, for: booking, note: note) }
        }
    }

    @ViewBuilder
    private func actionButton(_ action: BookingFulfillmentAction) -> some View {
        let button = Button {
            selectedAction = action
        } label: {
            Label(action.title, systemImage: action.systemImage)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("booking.fulfillment.\(action.rawValue)")
        if action.isDestructive {
            button.buttonStyle(BeckonDestructiveButtonStyle())
        } else {
            button
        }
    }

    private func timestamp(_ title: String, _ raw: String?) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm))
        return layout {
            Text(title)
            if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.sm) }
            if let raw {
                Text(GroomingRequestDateFormatting.displayString(from: raw,
                    serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier))
                    .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
            } else {
                Text("Not recorded")
            }
        }
        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
        .accessibilityElement(children: .combine)
    }
}
