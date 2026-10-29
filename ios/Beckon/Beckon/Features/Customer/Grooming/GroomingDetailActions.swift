// What a booking asks of the owner on the Grooming detail page (S-062): the cards that say it (a new time to answer, a service to
// confirm, an operation to check) and the quiet rows for what is rarely needed (change the time, cancel, report a problem). The
// same actions, texts and store calls as the old Booking detail page, in cards made for the merged page.
import SwiftUI


/// What the store says about a booking right now, worked out once for the cards and the rows.
struct GroomingBookingActionState {
    let booking: Booking
    let store: BookingsStore
    let now: Date

    private static let forwardActions: Set<BookingFulfillmentAction> = [.start, .complete, .reportCompletion, .confirmCompletion]

    var proposal: BookingRescheduleProposal? { store.rescheduleSnapshots[booking.id]?.proposal }

    var pendingProposal: BookingRescheduleProposal? {
        guard let proposal, proposal.currentStatus(for: booking, now: now) == .pending else { return nil }
        return proposal
    }

    var phase: BookingFulfillmentPhase? { booking.fulfillment?.phase }

    var recovery: BookingFulfillmentOperation? { store.pendingFulfillmentOperation(for: booking.id) }

    var isRecovering: Bool { recovery != nil || store.pendingRescheduleOperation(for: booking.id) != nil }

    var unverified: Bool { booking.fulfillment == nil && booking.status == .confirmed }

    /// The actions that move the booking forward, plus every action while an outcome waits for this customer's answer.
    var decisionActions: [BookingFulfillmentAction] {
        let actions = store.fulfillmentActions(for: booking, now: now)
        if phase == .outcomeReported { return actions }
        return actions.filter { Self.forwardActions.contains($0) }
    }

    var showsOutcome: Bool { phase == .inService || phase == .outcomeReported || phase == .unfulfilled }

    /// The service block has something to say or do.
    var hasServiceBlock: Bool {
        showsOutcome || !decisionActions.isEmpty || recovery != nil || unverified || store.errorMessage != nil || store.noticeMessage != nil
    }

    /// A reported service, an operation to check, or an error: the owner has to do something. A service that is simply running, or
    /// not yet verified, is only something to read.
    var serviceNeedsAnswer: Bool {
        phase == .outcomeReported || recovery != nil || store.errorMessage != nil
    }

    var canPropose: Bool { pendingProposal == nil && store.rescheduleActions(for: booking, now: now).contains(.propose) }

    /// The actions that are left once the service block has taken the ones that move the booking on.
    var otherActions: [BookingFulfillmentAction] {
        let shown = decisionActions
        return store.fulfillmentActions(for: booking, now: now).filter { !shown.contains($0) }
    }

    func isDestructive(_ action: BookingFulfillmentAction) -> Bool { [.cancel, .confirmStop, .closeElapsed].contains(action) }
}


/// The cards under the hero that ask something of the owner. Nothing is drawn when nothing is pending.
struct GroomingNeedsYou: View {
    let booking: Booking
    let store: BookingsStore
    let now: Date
    @Binding var fulfillmentAction: BookingFulfillmentAction?
    @Binding var rescheduleReview: GroomingRescheduleSelection?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var state: GroomingBookingActionState {
        GroomingBookingActionState(booking: booking, store: store, now: now)
    }

    var body: some View {
        let state = state
        if let proposal = state.pendingProposal {
            GroomingNeedsCard(title: "New time proposed", systemImage: "calendar.badge.clock") {
                proposalBody(proposal, state: state)
            }
            .accessibilityIdentifier("customer.grooming.detail.proposal")
        } else if let error = store.rescheduleErrors[booking.id], !state.hasServiceBlock {
            BeckonErrorBanner(title: "Time change unavailable", message: error)
        }
        if state.hasServiceBlock {
            GroomingNeedsCard(title: booking.fulfillmentTitle, systemImage: phaseIcon(state.phase),
                tone: state.serviceNeedsAnswer ? .attention : .info) {
                serviceBody(state: state)
            }
            .accessibilityIdentifier("customer.grooming.detail.service")
        }
    }

    // MARK: A time change waiting for an answer

    private func proposalBody(_ proposal: BookingRescheduleProposal, state: GroomingBookingActionState) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomingRescheduleTimes(booking: booking, proposal: proposal)
            Text(proposal.initiatorID == booking.customerID ? "You proposed this time" : "The groomer proposed this time")
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            Text("Reply before " + GroomingRequestDateFormatting.displayString(from: proposal.expiresAt,
                serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier))
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            note("The original appointment stays confirmed. The proposed time is not reserved.")
            if let recovery = store.pendingRescheduleOperation(for: booking.id) {
                note("\(recovery.action.title): result not yet verified.")
                GroomingActionButton(title: "Check change status", systemImage: "arrow.clockwise",
                    identifier: "booking.reschedule.check") { Task { await store.recoverReschedule(for: booking.id) } }
                GroomingActionButton(title: "Retry original change", systemImage: "arrow.triangle.2.circlepath",
                    style: .secondary, identifier: "booking.reschedule.retry") {
                    Task { await store.recoverReschedule(for: booking.id, retryIfMissing: true) }
                }
            } else {
                ForEach(store.rescheduleActions(for: booking, now: now)) { action in
                    GroomingActionButton(title: action.title,
                        systemImage: action == .propose ? "calendar.badge.clock" : "checkmark.circle",
                        style: action == .accept ? .primary : .secondary, identifier: "booking.reschedule.\(action.rawValue)") {
                        rescheduleReview = GroomingRescheduleSelection(action: action, proposal: proposal)
                    }
                }
            }
            if let error = store.rescheduleErrors[booking.id] {
                BeckonErrorBanner(title: "Time change unavailable", message: error)
            }
        }
    }

    // MARK: The service

    @ViewBuilder
    private func serviceBody(state: GroomingBookingActionState) -> some View {
        if state.unverified {
            note("Service status has not been verified. Changes are unavailable until verification succeeds. Pull down to check again.")
        }
        if let service = booking.fulfillment {
            if service.phase == .inService || service.phase == .outcomeReported {
                timestamp("Service started", service.actualStartedAt)
            }
            if let report = service.reportNote { note(report) }
        }
        if let message = store.errorMessage {
            BeckonErrorBanner(title: "Operation not completed", message: message)
        }
        if let message = store.noticeMessage { note(message) }
        if let recovery = state.recovery {
            note("\(recovery.action.title): outcome not yet verified.")
            GroomingActionButton(title: "Check status", systemImage: "arrow.clockwise",
                identifier: "booking.fulfillment.check") { Task { await store.recoverFulfillment(for: booking.id) } }
            GroomingActionButton(title: "Retry original operation", systemImage: "arrow.triangle.2.circlepath",
                style: .secondary, identifier: "booking.fulfillment.retry") {
                Task { await store.recoverFulfillment(for: booking.id, retryIfMissing: true) }
            }
        } else {
            let primaryID = state.decisionActions.first(where: { !state.isDestructive($0) })?.id
            ForEach(state.decisionActions) { action in
                if state.isDestructive(action) {
                    Button { fulfillmentAction = action } label: {
                        DesignQuietAction(title: action.title, systemImage: action.systemImage, isDestructive: true)
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .accessibilityIdentifier("booking.fulfillment.\(action.rawValue)")
                } else {
                    GroomingActionButton(title: action.title, systemImage: action.systemImage,
                        style: action.id == primaryID ? .primary : .secondary,
                        identifier: "booking.fulfillment.\(action.rawValue)") { fulfillmentAction = action }
                }
            }
        }
    }

    private func phaseIcon(_ phase: BookingFulfillmentPhase?) -> String {
        switch phase {
        case .inService: "sparkles"
        case .outcomeReported: "hourglass"
        case .unfulfilled: "questionmark.circle"
        default: "checkmark.circle"
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).designSupportingText()
    }

    @ViewBuilder
    private func timestamp(_ title: String, _ raw: String?) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm))
        layout {
            Text(title)
            if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.sm) }
            if let raw {
                Text(GroomingRequestDateFormatting.displayString(from: raw, serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier))
                    .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
            } else {
                Text("Not recorded")
            }
        }
        .font(DesignTokens.Typography.Expressive.supporting)
        .foregroundStyle(DesignTokens.Colors.textSecondary)
        .accessibilityElement(children: .combine)
    }
}


/// The rows nobody needs often, for a booking: change the time, and the rest of the service actions (cancel, report a problem).
struct GroomingBookingManage: View {
    let booking: Booking
    let store: BookingsStore
    let now: Date
    @Binding var fulfillmentAction: BookingFulfillmentAction?
    @Binding var rescheduleReview: GroomingRescheduleSelection?

    var body: some View {
        let state = GroomingBookingActionState(booking: booking, store: store, now: now)
        if !state.isRecovering, state.canPropose || !state.otherActions.isEmpty {
            DesignSection(title: "Manage booking", systemImage: "slider.horizontal.3") {
                if state.canPropose {
                    DesignManageRow(title: "Propose new time", systemImage: "calendar.badge.clock") {
                        rescheduleReview = GroomingRescheduleSelection(action: .propose, proposal: state.proposal)
                    }
                    .accessibilityIdentifier("booking.reschedule.propose")
                    if !state.otherActions.isEmpty { DesignRowDivider() }
                }
                ForEach(Array(state.otherActions.enumerated()), id: \.element.id) { index, action in
                    DesignManageRow(title: action.title, systemImage: action.systemImage,
                        isDestructive: state.isDestructive(action)) { fulfillmentAction = action }
                        .accessibilityIdentifier("booking.fulfillment.\(action.rawValue)")
                    if index < state.otherActions.count - 1 { DesignRowDivider() }
                }
            }
        }
    }
}
