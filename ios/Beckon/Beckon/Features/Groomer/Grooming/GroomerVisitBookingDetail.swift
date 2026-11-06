import Combine
import SwiftUI


struct GroomerVisitBookingDetail: View {
    let bookingID: UUID
    let store: BookingsStore
    let chat: ChatStore
    let decision: (Booking, Date) -> String?
    @State private var conversation: ChatConversation?
    @State private var fallbackFeedback = BeckonFeedbackCenter()
    @Environment(\.beckonFeedbackCenter) private var hostFeedback
    @Environment(\.openBookingChat) private var shellOpenChat
    @State private var fulfillmentAction: BookingFulfillmentAction?
    @State private var newTime: GroomingRescheduleSelection?
    @State private var timeChangeSent = false
    @State private var rescheduleReview: GroomingRescheduleSelection?
    @State private var timeReply: GroomingRescheduleSelection?
    @State private var selectedPet: GroomingRequestPetSnapshot?
    @State private var activityExpanded = false
    @State private var showsReview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var now = Date()
    @Environment(\.scenePhase) private var scenePhase
    /// The service and time-change records are still being read: their slot under the hero is kept, as a slim placeholder.
    @State private var isResolving = true
    /// The page replaced a placeholder (the booking was being found), so its blocks are simply there instead of dealt in again.
    @State private var waitedForBooking = false
    private let tick = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var booking: Booking? { store.booking(withID: bookingID) }
    private var feedback: BeckonFeedbackCenter { hostFeedback ?? fallbackFeedback }

    var body: some View {
        Group {
            if let booking {
                page(booking).environment(\.beckonRevealsInPlace, waitedForBooking)
            } else {
                unavailable
            }
        }
        .animation(DesignTokens.Motion.reveal, value: booking != nil)
        .beckonNavigationDestination(item: $conversation) { thread in
            ChatThreadView(participantID: thread.groomerID, role: .groomer, conversation: thread, store: chat)
        }
        .beckonHidesTabBar()
        .groomerVisitDetailPresentation()
        .environment(\.groomerVisitAppearance, true)
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: bookingID) {
            isResolving = true
            await load()
            guard !Task.isCancelled else { return }
            withAnimation(DesignTokens.Motion.reveal) { isResolving = false }
        }
        .task(id: booking?.id) {
            if let booking { await store.loadPresentation(for: booking) }
        }
        .background {
            BookingsStatusView(store: store, role: .groomer,
                presentation: BookingsFeedbackPresentation(role: .groomer, bookings: store.bookings,
                    isLoading: store.isLoading, errorMessage: store.errorMessage))
        }
        .onReceive(tick) { if scenePhase == .active { now = $0 } }
    }

    private func page(_ booking: Booking) -> some View {
        let stage = GroomerBookingStage(booking, now: now)
        let state = GroomingBookingActionState(booking: booking, store: store, now: now)
        return ScrollViewReader { reader in
            DesignPage {
                hero(booking, stage: stage, state: state)
                appointment(booking, stage: stage)
                if !stage.isClosed {
                    manageBooking(state)
                }
                activity(booking, reader: reader)

            }
        }
        .overlay(alignment: .bottom) {
            if hostFeedback == nil {
                BeckonGlobalFeedbackOverlay(center: fallbackFeedback, bottomPadding: DesignTokens.Spacing.sm)
            }
        }
        .modifier(GroomerVisitRequestFooter(showsPrimary: stage.isFinished || (!stage.isClosed && (state.isRecovering || !availableActions(state).isEmpty || !changeActions(state).isEmpty)),
            busy: store.isMutatingFulfillment || store.isMutatingReschedule, error: store.rescheduleErrors[booking.id]) {
                let hasChange = store.pendingRescheduleOperation(for: booking.id) != nil || !changeActions(state).isEmpty
                if changeActions(state) == [.withdraw], availableActions(state).count == 1, !state.isRecovering, !stage.isClosed, !stage.isFinished {
                    actionLayout {
                        changeFooter(state, paired: true)
                        footer(state, stage: stage)
                    }
                } else if hasChange && !stage.isClosed && !stage.isFinished {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        if state.recovery != nil || !availableActions(state).isEmpty {
                            actionLayout { footer(state, stage: stage) }
                        }
                        actionLayout { changeFooter(state) }
                    }
                } else {
                    footer(state, stage: stage)
                }
            })
        .beckonSheet(isPresented: $showsReview) {
            ScrollView { GroomerBookingReview(booking: booking).padding() }
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .beckonNavigationDestination(item: $selectedPet) { pet in
            GroomerVisitRequestPetProfile(pet: pet, photos: store.petPhoto(for: booking).map { [.init(id: pet.id.uuidString, data: $0, label: pet.name)] } ?? [])
        }
        .refreshable {
            await load()
            await store.loadPresentation(for: booking)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bookings.detail")
        .disabled(store.isMutatingFulfillment || store.isMutatingReschedule)
        .groomerVisitGroomingFulfillmentModal(action: $fulfillmentAction) { action, note in
            Task { await store.performFulfillment(action, for: booking, note: note) }
        }
        .groomerVisitDesignModal(item: $timeReply) { reply in
            let accept = reply.action == .accept
            let start = accept ? reply.proposal?.proposedStart ?? booking.scheduledStart : booking.scheduledStart
            let end = accept ? reply.proposal?.proposedEnd ?? booking.scheduledEnd : booking.scheduledEnd
            let zone = booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier
            return DesignModal(systemImage: "calendar.badge.clock", title: accept ? "Accept new time?" : "Keep original time?",
                message: accept
                    ? "We’ll check availability before confirming. If the new time is available, it will replace the current appointment."
                    : "This will decline the customer’s time change. The appointment will stay booked for the time below.",
                actions: [
                    .primary(accept ? "Accept time" : "Keep original", systemImage: "checkmark", identifier: "booking.reschedule.confirm") {
                        Task { await store.performReschedule(reply.action, for: booking, reviewedProposal: reply.proposal, newStart: nil) }
                    },
                    .quiet("Cancel", identifier: "dialog.cancel")
                ]) {
                    replySchedule(title: accept ? "Proposed time" : "Current appointment", start: start, end: end, zone: zone)
                }
        }
        .beckonSheet(item: $newTime, onDismiss: {
            guard timeChangeSent else { return }
            timeChangeSent = false
            feedback.showNotice("Time change request sent")
        }) { selection in
            GroomerVisitProposeTime(booking: booking, bookings: { store.bookings }) { start in
                await store.performReschedule(.propose, for: booking, reviewedProposal: selection.proposal, newStart: start)
                if let error = store.rescheduleErrors[booking.id] { return error }
                guard let proposal = store.rescheduleSnapshots[booking.id]?.proposal,
                      proposal.currentStatus(for: booking) == .pending,
                      let submittedStart = GroomingRequestDateFormatting.parsedDate(from: proposal.proposedStart),
                      floor(submittedStart.timeIntervalSince1970 / 60) == floor(start.timeIntervalSince1970 / 60) else {
                    return "The time change was not sent. Please refresh and try again."
                }
                timeChangeSent = true
                return nil
            }
            .presentationDragIndicator(.visible)
        }
        .groomerVisitDesignModal(item: $rescheduleReview) { selection in
            DesignModal(systemImage: "arrow.uturn.backward", title: "Withdraw time change?",
                message: "Your proposed time will be withdrawn. The appointment below stays booked.",
                actions: [
                    .primary("Withdraw", identifier: "booking.reschedule.withdraw.confirm") {
                        Task { await store.performReschedule(selection.action, for: booking, reviewedProposal: selection.proposal, newStart: nil) }
                    },
                    .quiet("Cancel", identifier: "dialog.cancel")
                ]) {
                    replySchedule(title: "Current appointment", start: booking.scheduledStart, end: booking.scheduledEnd,
                        zone: booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier)
                }
        }
    }

    private func replySchedule(title: String, start: String, end: String, zone: String?) -> some View {
        GroomerVisitServiceChangeSummary(title: title) {
            if let from = GroomingRequestDateFormatting.parsedDate(from: start),
               let until = GroomingRequestDateFormatting.parsedDate(from: end) {
                var calendar: Calendar {
                    var value = Calendar.current
                    if let zone, let tz = TimeZone(identifier: zone) { value.timeZone = tz }
                    return value
                }
                let labels = GroomerVisitRequestTimeLabels(start: from, end: until, calendar: calendar)
                Text(labels.startDate).font(DesignTokens.Typography.Expressive.emphasis)
                if let endDate = labels.endDate {
                    Text("From " + labels.startTime)
                    Text(endDate).font(DesignTokens.Typography.Expressive.emphasis)
                        .padding(.top, DesignTokens.Spacing.xs)
                    Text("Until " + labels.endTime)
                } else {
                    Text(labels.startTime + " – " + labels.endTime)
                }
            } else {
                Text(BeckonDateTimeFormatter.interval(from: start, to: end, serviceTimeZoneIdentifier: zone).summary)
            }
        }

    }

    // MARK: Blocks

    private func hero(_ booking: Booking, stage: GroomerBookingStage, state: GroomingBookingActionState) -> some View {
        let pet = booking.agreementSnapshot?.petSnapshot ?? booking.requestPetSnapshot
        let status = GroomerVisitCardStatus.booking(booking, stage: stage, proposal: state.pendingProposal, now: now)
        return GroomerVisitVisitOverviewCard(decision: decision(booking, now), status: status,
            explanationTitle: decision(booking, now) == "Reply to time change" ? "Customer requested a time change" : nil,
            usesStructuredStatus: state.pendingProposal?.initiatorID == booking.groomerID && !stage.isClosed && !stage.isFinished) {
            VStack(alignment: .leading, spacing: GroomerVisitDetailRowLayout.rowSpacing) {
                GroomerVisitVisitIdentity(pet: pet, photo: store.petPhoto(for: booking), service: booking.agreementSnapshot?.serviceType ?? booking.serviceType,
                    fallbackTitle: "Booking", selectedPet: $selectedPet)
                GroomerVisitBookingJourney(booking: booking, stage: stage, status: status, decision: decision(booking, now), now: now)
            }
        } explanation: { reason in
            if let proposal = state.pendingProposal,
               reason == "Reply to time change" || proposal.initiatorID == booking.groomerID {
                GroomerVisitBookingTimeChange(booking: booking, proposal: proposal, showsTitle: false)
            } else {
                Text("Review the proposed time before deciding whether to keep the current appointment.").designSupportingText()
            }
        }
    }

    private func appointment(_ booking: Booking, stage: GroomerBookingStage) -> some View {
        let zone = booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier
        return VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Appointment", systemImage: "calendar")
            VStack(spacing: 0) {
                GroomerVisitOfferPriceHeader(caption: "Price estimate") { _ in
                    Text(GroomerVisitOfferInput.displayPrice(Decimal(booking.priceEstimate)))
                        .lineLimit(1).minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } accessory: { EmptyView() }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    GroomerVisitDetailRowGroup {
                        GroomerVisitRequestFactRow(systemImage: "number", title: "Booking number", value: "#" + booking.referenceCode)
                        GroomerVisitBookedTimeRow(start: booking.scheduledStart, end: booking.scheduledEnd,
                            timeZoneIdentifier: zone)
                        GroomerVisitRequestFactRow(systemImage: "scissors", title: "Service", value: booking.appointmentServiceTitle)
                        if let mode = booking.agreementSnapshot?.locationMode ?? booking.locationMode {
                            GroomerVisitRequestFactRow.serviceLocation(mode)
                        }
                        let address = GroomerVisitVisitAddress.confirmed(booking)
                        Button {
                            guard let address else { return }
                            UIPasteboard.general.string = address
                            feedback.showNotice("Address copied")
                        } label: {
                            GroomerVisitRequestFactRow(systemImage: "location.fill", title: "Address",
                                value: address ?? booking.appointmentAddressSummary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(address == nil)
                        .accessibilityHint(address == nil ? "" : "Copies the address.")
                        GroomerVisitRequestFactRow.customerNote(booking.agreementSnapshot?.serviceNotes)
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            GroomerVisitRequestFactRow(systemImage: "person.fill", title: "Your customer",
                                value: store.customerNamesByBookingID[booking.id] ?? "Customer")
                            GroomerVisitNavigationButton {
                                if let shellOpenChat { shellOpenChat(booking) }
                                else if let cached = chat.conversation(for: booking) { conversation = cached }
                                else {
                                    Task {
                                        if let resolved = await chat.resolveConversation(bookingID: booking.id) { conversation = resolved }
                                        else { feedback.showNotice("Conversation unavailable") }
                                    }
                                }
                            } label: { Label("Message", systemImage: "message.fill") }
                            .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer, isFullWidth: false))
                            .fixedSize(horizontal: true, vertical: true)
                        }

                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.top, GroomerVisitDetailRowLayout.separatorInset)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }.clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)).beckonLedge(.card)
        }
    }

    @ViewBuilder private func footer(_ state: GroomingBookingActionState, stage: GroomerBookingStage) -> some View {
        if stage.isFinished {
            Button("Review", systemImage: "star") { showsReview = true }.buttonStyle(GroomerVisitRequestFooterActionStyle())
        } else if state.recovery != nil {
            Button("Retry") { Task { await store.recoverFulfillment(for: bookingID, retryIfMissing: true) } }
                .buttonStyle(GroomerVisitRequestFooterActionStyle(tone: .secondary))
            Button("Check status") { Task { await store.recoverFulfillment(for: bookingID) } }.buttonStyle(GroomerVisitRequestFooterActionStyle())
        } else {
            let actions = availableActions(state)
            let primary = actions.first(where: { !state.isDestructive($0) }) ?? actions.first
            ForEach(actions.filter { $0 != primary }) { action in
                Button(action.title, systemImage: action.systemImage) { fulfillmentAction = action }
                    .buttonStyle(GroomerVisitRequestFooterActionStyle(tone: .secondary))
            }
            if let primary {
                Button(primary.title, systemImage: primary.systemImage) { fulfillmentAction = primary }
                    .buttonStyle(GroomerVisitRequestFooterActionStyle(tone: actions.count == 1 && state.isDestructive(primary) ? .management : .primary))
            }
        }
    }

    private func changeActions(_ state: GroomingBookingActionState) -> [BookingRescheduleAction] {
        guard state.pendingProposal != nil else { return [] }
        return store.rescheduleActions(for: state.booking, now: now).filter { $0 != .propose }
    }

    private func actionLayout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.sm))
            : AnyLayout(GroomerVisitFooterColumns(gap: DesignTokens.Spacing.md))
        return layout { content() }
    }

    @ViewBuilder private func changeFooter(_ state: GroomingBookingActionState, paired: Bool = false) -> some View {
        if store.pendingRescheduleOperation(for: bookingID) != nil {
            Button("Retry") { Task { await store.recoverReschedule(for: bookingID, retryIfMissing: true) } }
                .buttonStyle(GroomerVisitRequestFooterActionStyle(tone: .secondary))
            Button("Check status") { Task { await store.recoverReschedule(for: bookingID) } }
                .buttonStyle(GroomerVisitRequestFooterActionStyle())
        } else {
            let actions = changeActions(state)
            ForEach(actions.filter { $0 != .accept } + actions.filter { $0 == .accept }) { action in
                let title = switch action {
                case .accept: "Accept time"
                case .reject: "Keep original"
                case .withdraw: "Withdraw change"
                case .propose: "Propose time"
                }
                Button(title) {
                    let selection = GroomingRescheduleSelection(action: action, proposal: state.pendingProposal)
                    if action == .accept || action == .reject { timeReply = selection }
                    else { rescheduleReview = selection }
                }
                .buttonStyle(GroomerVisitRequestFooterActionStyle(tone: action == .accept ? .primary : (paired || actions.count > 1 ? .secondary : .management)))
                .accessibilityLabel(action.title)
            }
        }
    }

    private func availableActions(_ state: GroomingBookingActionState) -> [BookingFulfillmentAction] {
        state.decisionActions.filter { $0 == .complete }
    }

    @ViewBuilder private func manageBooking(_ state: GroomingBookingActionState) -> some View {
        let canCancel = state.otherActions.contains(.cancel)
        if !state.isRecovering && (state.canPropose || canCancel) {
            DesignSection(title: "Manage booking", systemImage: "slider.horizontal.3") {
                if state.canPropose {
                    DesignManageRow(title: "Propose new time", systemImage: "calendar.badge.clock") {
                        newTime = GroomingRescheduleSelection(action: .propose, proposal: state.proposal)
                    }
                    if canCancel { DesignRowDivider() }
                }
                if canCancel {
                    DesignManageRow(title: "Cancel appointment", systemImage: "xmark.circle", isDestructive: true) {
                        fulfillmentAction = .cancel
                    }
                }
            }
        }
    }

    /// What happened, from the booking to the review.
    @ViewBuilder
    private func activity(_ booking: Booking, reader: ScrollViewProxy) -> some View {
        let entries = GroomingTimelineEntry.groomerVisitBooking(booking, changes: store.rescheduleSnapshots[booking.id]?.history ?? [],
            proposal: store.rescheduleSnapshots[booking.id]?.proposal, now: now)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                Button {
                    activityExpanded.toggle()
                } label: {
                    HStack {
                        BeckonLedgeHeading(title: "Activity", systemImage: "clock.arrow.circlepath", count: entries.count)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(DesignTokens.Typography.Expressive.chip)
                            .rotationEffect(.degrees(activityExpanded ? 180 : 0))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: activityExpanded)
                    }
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityValue(activityExpanded ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("groomer.booking.activity.toggle")
                if activityExpanded {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(entries) { entry in
                            row(entry, isLast: entry.id == entries.last?.id)
                        }
                        Color.clear.frame(height: 1)
                            .id("bookingActivityEnd")
                            .task {
                                await Task.yield()
                                guard !Task.isCancelled, activityExpanded else { return }
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                                    reader.scrollTo("bookingActivityEnd", anchor: .bottom)
                                }
                            }
                    }
                    .designCardBody()
                }
            }
            .accessibilityIdentifier("groomer.booking.activity")
        }
    }

    private func row(_ entry: GroomingTimelineEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(spacing: 0) {
                Image(systemName: entry.systemImage)
                    .font(DesignTokens.Typography.Expressive.timelineGlyph) // glyph inside a fixed-size dot, fixed by design
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .frame(width: 28, height: 28)
                    .background(DesignTokens.Colors.customerFill, in: Circle())
                    .accessibilityHidden(true)
                if !isLast {
                    Rectangle()
                        .fill(DesignTokens.Colors.borderSoft)
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(entry.title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                if let detail = entry.detail {
                    Text(detail)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                if let note = entry.note {
                    Text(note).designSupportingText()
                }
            }
            .padding(.bottom, isLast ? DesignTokens.Spacing.none : DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Loading and refreshing

    private func load() async {
        await store.resolveBooking(id: bookingID)
        if let booking = store.booking(withID: bookingID) {
            if booking.fulfillment == nil { await store.refreshFulfillment(for: booking.id) }
            else { await store.loadFulfillmentHistory(for: booking.id) }
            await store.loadReschedule(for: booking.id)
        }
    }

    // MARK: Waiting and unavailable

    private var unavailable: some View {
        ZStack {
            BeckonExpressiveBackdrop()
            if store.bookingReadStates[bookingID] == nil || store.bookingReadStates[bookingID] == .loading {
                DesignPage(cascades: false) { GroomingDetailSkeleton() }
                    .accessibilityIdentifier("bookings.detail.loading")
                    .onAppear { waitedForBooking = true }
            } else {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    BeckonLedgeNote(systemImage: "calendar.badge.exclamationmark",
                        text: "Booking unavailable. This booking could not be verified.")
                    Button { Task { await store.resolveBooking(id: bookingID) } } label: {
                        DesignActionLabel(title: "Retry booking", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(BeckonLedgeButtonStyle(.pill))
                    .accessibilityIdentifier("bookings.detail.retry")
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
        }
    }
}
