// One booking, opened from the Schedule, a chat or a notification (design; redesigned design as the owner's Grooming detail seen from the
// other side). Same job as the groomer branch of BookingDetailView in Features/Bookings/BookingsView.swift: who and what, when and
// where, the service (start, complete, report, cancel, and what happened), changes of the appointment's time, the customer and the way
// to the chat, and once the service is done the customer's review. The page has the owner's page's order and blocks: the hero is the
// booking opened up (the groomer's path: Booked, In service, Finished, Reviewed, with its bubble), under it the cards that say what
// needs the groomer, then the one thing for the stage (the review, once it is over), the appointment, what to know about the pet, the
// quiet manage rows, and what happened. The store, the actions, the dialogs and every id are the real ones.
import Combine
import SwiftUI


struct GroomerBookingDetailView: View {
    @Environment(\.groomerGroomingWorkspace) private var adoptedWorkspace
    let bookingID: UUID
    let store: BookingsStore
    var onOpenChat: ((Booking) -> Void)?
    @Environment(\.openBookingChat) private var shellOpenChat
    @State private var fulfillmentAction: BookingFulfillmentAction?
    @State private var rescheduleReview: GroomingRescheduleSelection?
    @State private var rescheduleDraftStart: Date?
    @State private var fallbackFeedback = BeckonFeedbackCenter()
    @Environment(\.beckonFeedbackCenter) private var hostFeedback
    @State private var now = Date()
    @Environment(\.scenePhase) private var scenePhase
    /// The service and time-change records are still being read: their slot under the hero is kept, as a slim placeholder.
    @State private var isResolving = true
    /// The page replaced a placeholder (the booking was being found), so its blocks are simply there instead of dealt in again.
    @State private var waitedForBooking = false
    private let tick = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var booking: Booking? { store.booking(withID: bookingID) }
    private var openChat: ((Booking) -> Void)? { onOpenChat ?? shellOpenChat }

    var body: some View {
        if let adoptedWorkspace {
            GroomerVisitBookingDetail(bookingID: bookingID, store: store, chat: adoptedWorkspace.session.chat,
                decision: adoptedWorkspace.bookingDecision)
        } else { legacyBody }
    }

    private var legacyBody: some View {
        Group {
            if let booking {
                page(booking).environment(\.beckonRevealsInPlace, waitedForBooking)
            } else {
                unavailable
            }
        }
        .animation(DesignTokens.Motion.reveal, value: booking != nil)
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
        .overlay(alignment: .bottom) {
            if hostFeedback == nil { BeckonGlobalFeedbackOverlay(center: fallbackFeedback) }
        }
    }

    private func page(_ booking: Booking) -> some View {
        let stage = GroomerBookingStage(booking, now: now)
        return DesignPage {
            hero(booking, stage: stage)
            if !stage.isClosed { needsYou(booking) }
            if stage.isFinished { GroomerBookingReview(booking: booking) }
            GroomerBookingAppointment(booking: booking, customerName: store.customerNamesByBookingID[booking.id], onOpenChat: openChat, isOver: stage.isFinished || stage.isClosed)
            if !stage.isClosed, let pet = booking.agreementSnapshot?.petSnapshot ?? booking.requestPetSnapshot {
                GroomerPetCard(pet: pet, visitNotes: booking.agreementSnapshot?.serviceNotes)
            }
            if !stage.isClosed {
                GroomingBookingManage(booking: booking, store: store, now: now, fulfillmentAction: $fulfillmentAction,
                    rescheduleReview: $rescheduleReview)
            }
            activity(booking)
        }
        .refreshable {
            await load()
            await store.loadPresentation(for: booking)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bookings.detail")
        .disabled(store.isMutatingFulfillment || store.isMutatingReschedule)
        .groomingFulfillmentDialog(action: $fulfillmentAction) { action, note in
            Task { await store.performFulfillment(action, for: booking, note: note) }
        }
        .groomingRescheduleDialog(selection: $rescheduleReview, booking: booking, initialStart: rescheduleDraftStart) { selection, newStart in
            if selection.action == .propose { rescheduleDraftStart = newStart }
            Task {
                await store.performReschedule(selection.action, for: booking, reviewedProposal: selection.proposal, newStart: newStart)
                if let error = store.rescheduleErrors[booking.id] {
                    if BookingRescheduleAvailabilityFeedback.isAvailabilityMessage(error) {
                        (hostFeedback ?? fallbackFeedback).showNotice(error)
                    }
                } else { rescheduleDraftStart = nil }
            }
        }
    }

    // MARK: Blocks

    private func hero(_ booking: Booking, stage: GroomerBookingStage) -> some View {
        GroomingDetailHero(
            species: booking.agreementSnapshot?.petSnapshot.species ?? booking.requestPetSnapshot?.species ?? "",
            avatarData: store.petPhoto(for: booking), title: GroomingCardContent.groomingTitle(booking), time: booking.scheduledTimeSummary,
            when: BeckonWhen(start: booking.scheduledStart, end: booking.scheduledEnd,
                zoneIdentifier: booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier, now: now),
            card: nil, closed: stage.closed, path: stage.path, identifier: "groomer.booking.hero")
    }

    /// What needs the groomer: a new time to answer, the service to start, complete or confirm. Nothing is drawn when nothing is pending.
    @ViewBuilder
    private func needsYou(_ booking: Booking) -> some View {
        if isResolving, booking.fulfillment == nil, booking.status == .confirmed {
            GroomingNeedsSkeleton().transition(.opacity)
        } else {
            GroomingNeedsYou(booking: booking, store: store, now: now, fulfillmentAction: $fulfillmentAction,
                rescheduleReview: $rescheduleReview, role: .groomer)
        }
    }

    /// What happened, from the booking to the review.
    @ViewBuilder
    private func activity(_ booking: Booking) -> some View {
        let entries = GroomingTimelineEntry.booking(booking, store: store, role: .groomer,
            zone: booking.serviceTimeZoneIdentifier, now: now)
        if entries.count > 1 { GroomingTimeline(entries: entries, identifier: "groomer.booking.activity",
            toggleIdentifier: "groomer.booking.activity.toggle") }
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
