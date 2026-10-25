// Customer booking detail in the Home style (sandbox design S-002, reordered in S-017). One ticket holds everything
// that identifies the appointment (service, groomer with the message button, date and time, status, where, price); under it
// come only the things that need the customer, in the order they need them: the path, what to do next, the review, the
// rarely used options, and last the service record. Used by BookingDetailView for the customer role; the groomer role
// keeps the previous layout. Same data and actions as Features/Bookings/BookingsView.swift.
import Combine
import SwiftUI

struct CustomerBookingDetailContent: View {
    let booking: Booking
    let store: BookingsStore
    let onOpenChat: ((Booking) -> Void)?
    let onCreateNewRequest: ((Booking) -> Void)?
    var focusedReviewTarget: FocusState<BookingReviewFocusTarget?>.Binding
    @State private var fulfillmentAction: BookingFulfillmentAction?
    @State private var rescheduleReview: BookingRescheduleSelection?
    @State private var showsRecord = false
    @State private var now = Date()
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tick = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View { content }

    private func current(_ booking: Booking) -> Int? {
        switch booking.status {
        case .confirmed: 2
        case .completed: booking.review == nil ? 3 : 4
        default: nil
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            DesignPage {
                ticket(booking)

                progress

                if booking.status.isCancellation || booking.status == .unfulfilled, let onCreateNewRequest {
                    Button { onCreateNewRequest(booking) } label: {
                        DesignActionLabel(title: "Create a new request from this booking", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(BeckonLedgeButtonStyle(.pill))
                    .accessibilityIdentifier("customer.bookings.republish")
                }

                nextStep

                if let issue = store.appointmentReminderIssue {
                    BookingReminderNotice(issue: issue)
                        .accessibilityIdentifier("bookings.appointment-reminder-notice")
                }

                if booking.status == .completed { review(booking) }

                manage
                record
            }
            .refreshable { await refresh() }
            .beckonKeyboardAvoidance(focusedTarget: focusedReviewTarget.wrappedValue?.rawValue, using: proxy)
        }
        .onReceive(tick) { now = $0 }
        .task(id: booking.id) {
            if booking.fulfillment == nil { await store.refreshFulfillment(for: booking.id) }
            else { await store.loadFulfillmentHistory(for: booking.id) }
            await store.loadReschedule(for: booking.id)
        }
        .disabled(store.isMutatingFulfillment || store.isMutatingReschedule)
        .bookingFulfillmentDialog(action: $fulfillmentAction) { action, note in
            Task { await store.performFulfillment(action, for: booking, note: note) }
        }
        .bookingRescheduleDialog(selection: $rescheduleReview, booking: booking) { selection, newStart in
            Task { await store.performReschedule(selection.action, for: booking, reviewedProposal: selection.proposal, newStart: newStart) }
        }
    }

    /// Pull down to check the booking again; there is no refresh button on the page.
    private func refresh() async {
        await store.refreshFulfillment(for: booking.id)
        await store.loadReschedule(for: booking.id)
    }

    // MARK: Ticket

    /// Everything that identifies the appointment, once: the strip carries the countdown and the price, the body the service,
    /// the time, the status and where, the foot the groomer and the way to message them.
    private func ticket(_ booking: Booking) -> some View {
        VStack(spacing: 0) {
            BeckonCountdownStrip(
                title: booking.status == .confirmed
                    ? (BeckonBookingCountdown.label(for: booking) ?? "Upcoming") : booking.status.title,
                trailing: booking.priceSummary)
            ticketBody(booking)
            DesignRowDivider()
            DesignFactRow(systemImage: "location.fill", title: locationTitle(booking), value: booking.appointmentAddressSummary)
                .padding(DesignTokens.Spacing.lg)
            DesignRowDivider()
            groomerFoot(booking)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .beckonLedge(.card)
    }

    private func ticketBody(_ booking: Booking) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            if let parts = BeckonBookingCountdown.dateParts(for: booking) {
                BeckonDateTile(month: parts.month, day: parts.day)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(booking.appointmentServiceTitle)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(booking.scheduledTimeSummary)
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .accessibilityLabel(booking.scheduledTimePresentation.accessibilityLabel)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    BeckonStatusChip(booking.status.presentation)
                    Text("#\(booking.referenceCode)")
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private func locationTitle(_ booking: Booking) -> String {
        guard let mode = booking.locationMode else { return "Location not confirmed" }
        return BeckonGroomingLocationModePresentation(mode: mode, perspective: .customer).title
    }

    private func groomerFoot(_ booking: Booking) -> some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))) {
            BeckonProfileAvatar(data: booking.groomerAvatarPhotoData, tone: .groomer, size: 44,
                cornerRadius: DesignTokens.CornerRadius.pill)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your groomer")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Text(booking.partnerDisplayTitle(for: .customer))
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onOpenChat {
                Button { onOpenChat(booking) } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "bubble.left.fill")
                        Text("Message")
                    }
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.pill))
                .accessibilityLabel("Message your groomer")
                .accessibilityIdentifier("bookings.detail.open-chat")
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: Path

    @ViewBuilder
    private var progress: some View {
        if let current = current(booking) {
            DesignFactCard {
                DesignStepPath(labels: ["Booked", "Service day", "Review"],
                    systemImages: ["calendar.badge.checkmark", "scissors", "star.fill"], current: current)
            }
        } else {
            DesignFactCard {
                DesignInfoLine(systemImage: booking.status.presentation.systemImage, text: closedMessage(booking.status))
            }
        }
    }

    private func closedMessage(_ status: BookingStatus) -> String {
        switch status {
        case .unfulfilled: "This service was not confirmed. You can start a new request any time."
        case .cancelledByCustomer: "You cancelled this booking."
        case .cancelledByGroomer: "The groomer cancelled this booking. You can start a new request any time."
        default: "This booking is no longer active."
        }
    }

    // MARK: Next step

    private static let forwardActions: Set<BookingFulfillmentAction> = [.start, .complete, .reportCompletion, .confirmCompletion]

    private func isDestructive(_ action: BookingFulfillmentAction) -> Bool { [.cancel, .confirmStop, .closeElapsed].contains(action) }

    private var proposal: BookingRescheduleProposal? { store.rescheduleSnapshots[booking.id]?.proposal }

    private var pendingProposal: BookingRescheduleProposal? {
        guard let proposal, proposal.currentStatus(for: booking, now: now) == .pending else { return nil }
        return proposal
    }

    /// The actions that move the booking forward, plus every action while an outcome waits for this customer's answer.
    private var decisionActions: [BookingFulfillmentAction] {
        let actions = store.fulfillmentActions(for: booking, now: now)
        if booking.fulfillment?.phase == .outcomeReported { return actions }
        return actions.filter { Self.forwardActions.contains($0) }
    }

    private var phase: BookingFulfillmentPhase? { booking.fulfillment?.phase }

    private var showsOutcome: Bool {
        phase == .inService || phase == .outcomeReported || phase == .unfulfilled
    }

    /// Only here when the customer has something to do or to read: a time change to answer, a service that is running or waiting
    /// for confirmation, an action that moves the booking on, an unverified state, or an operation to recover.
    @ViewBuilder
    private var nextStep: some View {
        let recovering = store.pendingFulfillmentOperation(for: booking.id) != nil || store.pendingRescheduleOperation(for: booking.id) != nil
        let unverified = booking.fulfillment == nil && booking.status == .confirmed
        let problem = store.errorMessage ?? store.rescheduleErrors[booking.id]
        if pendingProposal != nil || recovering || unverified || showsOutcome || !decisionActions.isEmpty || problem != nil
            || store.noticeMessage != nil {
            DesignFactCard(spacing: DesignTokens.Spacing.lg) {
                if let pendingProposal { proposalBlock(pendingProposal) }
                if pendingProposal == nil, let recovery = store.pendingRescheduleOperation(for: booking.id) {
                    // A timed-out proposal may not exist in the last verified snapshot yet.
                    // Recovery must remain reachable even without a proposal to render.
                    note("\(recovery.action.title): result not yet verified.")
                    actionButton("Check change status", "arrow.clockwise", style: .primary, id: "booking.reschedule.check") {
                        Task { await store.recoverReschedule(for: booking.id) }
                    }
                    actionButton("Retry original change", "arrow.triangle.2.circlepath", style: .secondary, id: "booking.reschedule.retry") {
                        Task { await store.recoverReschedule(for: booking.id, retryIfMissing: true) }
                    }
                }
                if pendingProposal != nil && (showsOutcome || !decisionActions.isEmpty || recovering) { DesignRowDivider() }
                outcomeBlock(unverified: unverified)
            }
        }
    }

    // A time change waiting for an answer.
    private func proposalBlock(_ proposal: BookingRescheduleProposal) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            DesignBlockHeader(systemImage: "calendar.badge.clock", title: "New time proposed")
            BookingRescheduleTimes(booking: booking, proposal: proposal)
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
                actionButton("Check change status", "arrow.clockwise", style: .primary, id: "booking.reschedule.check") {
                    Task { await store.recoverReschedule(for: booking.id) }
                }
                actionButton("Retry original change", "arrow.triangle.2.circlepath", style: .secondary, id: "booking.reschedule.retry") {
                    Task { await store.recoverReschedule(for: booking.id, retryIfMissing: true) }
                }
            } else {
                ForEach(store.rescheduleActions(for: booking, now: now)) { action in
                    actionButton(action.title, action == .propose ? "calendar.badge.clock" : "checkmark.circle",
                        style: action == .accept ? .primary : .secondary, id: "booking.reschedule.\(action.rawValue)") {
                        rescheduleReview = BookingRescheduleSelection(action: action, proposal: proposal)
                    }
                }
            }
            if let error = store.rescheduleErrors[booking.id] {
                BeckonErrorBanner(title: "Time change unavailable", message: error)
            }
        }
    }

    // The service itself: where it stands, and the one thing to do about it.
    @ViewBuilder
    private func outcomeBlock(unverified: Bool) -> some View {
        let recovery = store.pendingFulfillmentOperation(for: booking.id)
        let hasOutcomeContent = showsOutcome || !decisionActions.isEmpty || recovery != nil || unverified
            || store.errorMessage != nil || store.noticeMessage != nil
        if hasOutcomeContent {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DesignBlockHeader(systemImage: phaseIcon, title: booking.fulfillmentTitle)
                if unverified {
                    note("Service status has not been verified. Changes are unavailable until verification succeeds. Pull down to check again.")
                }
                if let state = booking.fulfillment {
                    if state.phase == .inService || state.phase == .outcomeReported {
                        timestamp("Service started", state.actualStartedAt)
                    }
                    if let report = state.reportNote { note(report) }
                }
                if let message = store.errorMessage {
                    BeckonErrorBanner(title: "Operation not completed", message: message)
                }
                if let message = store.noticeMessage { note(message) }
                if let recovery {
                    note("\(recovery.action.title): outcome not yet verified.")
                    actionButton("Check status", "arrow.clockwise", style: .primary, id: "booking.fulfillment.check") {
                        Task { await store.recoverFulfillment(for: booking.id) }
                    }
                    actionButton("Retry original operation", "arrow.triangle.2.circlepath", style: .secondary, id: "booking.fulfillment.retry") {
                        Task { await store.recoverFulfillment(for: booking.id, retryIfMissing: true) }
                    }
                } else {
                    let primaryID = decisionActions.first(where: { !isDestructive($0) })?.id
                    ForEach(decisionActions) { action in
                        if isDestructive(action) {
                            Button { fulfillmentAction = action } label: {
                                DesignQuietAction(title: action.title, systemImage: action.systemImage, isDestructive: true)
                            }
                            .buttonStyle(BeckonGuardedPlainButtonStyle())
                            .accessibilityIdentifier("booking.fulfillment.\(action.rawValue)")
                        } else {
                            actionButton(action.title, action.systemImage, style: action.id == primaryID ? .primary : .secondary,
                                id: "booking.fulfillment.\(action.rawValue)") { fulfillmentAction = action }
                        }
                    }
                }
            }
        } else if pendingProposal == nil, let error = store.rescheduleErrors[booking.id] {
            BeckonErrorBanner(title: "Time change unavailable", message: error)
        }
    }

    private var phaseIcon: String {
        switch phase {
        case .inService: "scissors"
        case .outcomeReported: "hourglass"
        case .unfulfilled: "questionmark.circle"
        default: "checkmark.circle"
        }
    }

    // MARK: Manage

    /// What is left of the actions once the next step has taken the ones that move the booking on: changing the time, cancelling,
    /// reporting a problem. Rare, so they are quiet rows at the bottom.
    @ViewBuilder
    private var manage: some View {
        let recovering = store.pendingFulfillmentOperation(for: booking.id) != nil || store.pendingRescheduleOperation(for: booking.id) != nil
        let shown = decisionActions
        let others = store.fulfillmentActions(for: booking, now: now).filter { !shown.contains($0) }
        let canPropose = pendingProposal == nil && store.rescheduleActions(for: booking, now: now).contains(.propose)
        if !recovering, canPropose || !others.isEmpty {
            DesignSection(title: "Manage booking", systemImage: "slider.horizontal.3") {
                if canPropose {
                    DesignManageRow(title: "Propose new time", systemImage: "calendar.badge.clock") {
                        rescheduleReview = BookingRescheduleSelection(action: .propose, proposal: proposal)
                    }
                    .accessibilityIdentifier("booking.reschedule.propose")
                    if !others.isEmpty { DesignRowDivider() }
                }
                ForEach(Array(others.enumerated()), id: \.element.id) { index, action in
                    DesignManageRow(title: action.title, systemImage: action.systemImage,
                        isDestructive: isDestructive(action)) { fulfillmentAction = action }
                        .accessibilityIdentifier("booking.fulfillment.\(action.rawValue)")
                    if index < others.count - 1 { DesignRowDivider() }
                }
            }
        }
    }

    // MARK: Service record

    /// Who did what to this booking and when (started, completed, cancelled, reported a problem), kept for both sides. Closed by
    /// default: it is a record to look up, not something to act on.
    @ViewBuilder
    private var record: some View {
        let events = store.fulfillmentHistory[booking.id] ?? []
        let error = store.fulfillmentHistoryErrors[booking.id]
        let state = booking.fulfillment
        let pastChange = proposal.flatMap { $0.currentStatus(for: booking, now: now) == .pending ? nil : $0 }
        let hasTimes = state?.actualStartedAt != nil || state?.actualEndedAt != nil
        if !events.isEmpty || error != nil || hasTimes || pastChange != nil {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                Button {
                    withAnimation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap) {
                        showsRecord.toggle()
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        BeckonLedgeHeading(title: "Service record", systemImage: "clock.arrow.circlepath",
                            count: events.isEmpty ? nil : events.count)
                        Spacer(minLength: DesignTokens.Spacing.sm)
                        Image(systemName: "chevron.down")
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .rotationEffect(.degrees(showsRecord ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityValue(showsRecord ? "Expanded" : "Collapsed")
                .accessibilityHint("Shows who did what on this booking, and when.")
                .accessibilityIdentifier("booking.record.toggle")

                if showsRecord {
                    DesignFactCard(spacing: DesignTokens.Spacing.md) {
                        if let state {
                            timestamp("Service started", state.actualStartedAt, hidesWhenMissing: true)
                            timestamp("Service ended", state.actualEndedAt, hidesWhenMissing: true)
                            if let release = state.resourceReleaseAt { timestamp("Groomer reserved until", release) }
                            if state.basis == "bilateral_retrospective" {
                                note("Completion confirmed by both participants. Unrecorded service times remain unknown.")
                            }
                        }
                        if let pastChange {
                            Label(pastChange.currentStatus(for: booking, now: now).title, systemImage: "calendar.badge.clock")
                                .font(DesignTokens.Typography.Expressive.supporting)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        if let error {
                            note(error)
                            Button { Task { await store.loadFulfillmentHistory(for: booking.id) } } label: {
                                DesignQuietAction(title: "Retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(BeckonGuardedPlainButtonStyle())
                        }
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Label(event.action.title, systemImage: event.action.systemImage)
                                    .font(DesignTokens.Typography.Expressive.emphasis)
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                Text((event.actorID == booking.customerID ? "You" : "Groomer") + " · "
                                    + GroomingRequestDateFormatting.displayString(from: event.recordedAt,
                                        serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier))
                                    .font(DesignTokens.Typography.Expressive.chip)
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                                if let text = event.note { note(text) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    // MARK: Pieces

    private enum ActionStyle { case primary, secondary }

    private func actionButton(_ title: String, _ systemImage: String, style: ActionStyle, id: String,
                              action: @escaping () -> Void) -> some View {
        let isPrimary = style == .primary
        return Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: systemImage)
                Text(title).multilineTextAlignment(.center)
            }
            .font(isPrimary ? DesignTokens.Typography.Expressive.headline : DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(isPrimary ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: isPrimary ? DesignTokens.Metrics.ledgePrimaryButtonHeight
                : DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isPrimary ? .pill : .card))
        .accessibilityIdentifier(id)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .designSupportingText()
    }

    @ViewBuilder
    private func timestamp(_ title: String, _ raw: String?, hidesWhenMissing: Bool = false) -> some View {
        if raw != nil || !hidesWhenMissing {
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

    // MARK: Review

    @ViewBuilder
    private func review(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Review", systemImage: "star.fill")
            if let review = booking.review {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                .foregroundStyle(DesignTokens.Colors.ratingStar)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(review.ratingSummary)
                    Text(review.displayContent)
                        .designSupportingText()
                    if !review.petFitOutcomes.isEmpty {
                        Divider()
                        Text("Pet fit notes").font(DesignTokens.Typography.Expressive.emphasis)
                        ForEach(review.petFitOutcomes) { outcome in
                            BookingReviewFitOutcomeDisplay(outcome: outcome)
                        }
                    }
                }
                .designCardBody()
                .accessibilityIdentifier("bookings.review.display")
            } else if booking.canReview(for: .customer) {
                BookingReviewForm(booking: booking, store: store, accent: .customer, focusedTarget: focusedReviewTarget)
            } else {
                BeckonLedgeNote(systemImage: "star", text: "Reviews open once the appointment is completed.")
            }
        }
    }
}
