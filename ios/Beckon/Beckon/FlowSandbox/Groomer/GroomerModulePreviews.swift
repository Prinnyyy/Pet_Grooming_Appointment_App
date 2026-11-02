#if DEBUG
// Adopted groomer views in the Canvas, with the existing isolated in-memory session.
// The protected prototype remains the design source; these hosts exercise production views.
import SwiftUI


/// The groomer shell on a session of local data. `releasesLoadingAfter` ends a `.loading` wait after that many seconds.
/// Plays the first load again and again: the data stays silent for a few seconds, then answers; Replay starts a new session.
private struct GroomerLoadingDemo: View {
    var startsOn: GroomerTab = .requests
    var route: GroomerRequestsRoute = .matches
    @State private var round = 0

    var body: some View {
        GroomerFlowSandbox(state: .loading, startsOn: startsOn, route: route, releasesLoadingAfter: 2.6)
            .id(round)
            .overlay(alignment: .bottom) {
                Button("Replay", systemImage: "arrow.counterclockwise") { round += 1 }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
                    .padding(.bottom, DesignTokens.Layout.stationaryActionContentClearance)
            }
    }
}


/// One page of the groomer prototype on its own, inside a navigation stack and the groomer's coral, on a session of local data.
struct GroomerPageHost<Page: View>: View {
    var state: GroomerSandboxState = .loaded
    @State private var session: GroomerSandboxSession
    @State private var isReady: Bool
    private let prepare: ((GroomerSandboxSession) async -> Void)?
    private let page: (GroomerSandboxSession) -> Page

    /// `bookings`, `matches` and `offers` replace the fixtures': a booking or a request in one particular moment. `prepare` runs
    /// before the page is shown (a request page needs its request in the store, as it is when a notification opens it).
    init(state: GroomerSandboxState = .loaded, bookings: [Booking]? = nil, matches: [GroomerMatchedRequest]? = nil,
         offers: [GroomerOfferListItem]? = nil, prepare: ((GroomerSandboxSession) async -> Void)? = nil,
         @ViewBuilder page: @escaping (GroomerSandboxSession) -> Page) {
        self.state = state
        self.page = page
        self.prepare = prepare
        _isReady = State(initialValue: prepare == nil)
        _session = State(initialValue: GroomerSandboxSession(state: state, bookings: bookings, matches: matches, offers: offers))
    }

    var body: some View {
        NavigationStack { if isReady { page(session) } else { Color.clear } }
            .task {
                guard !isReady else { return }
                await prepare?(session)
                isReady = true
            }
            .environment(\.beckonFeedbackCenter, BeckonFeedbackCenter())
            .environment(\.openBookingChat, { _ in })
            .environment(\.beckonRole, .groomer)
            .environment(\.beckonRevealsInPlace, true)
    }
}


/// Loads the Requests tab's two lists, so a still of the tab has its rows.
private func loadRequestLists(_ session: GroomerSandboxSession) async {
    await session.requests.load()
    await session.offers.load()
}


/// Loads what Home reads (the card, the counts, the bell, the unread chats and the bookings Coming up is made of), so a still of the
/// page has its cards.
private func loadHome(_ session: GroomerSandboxSession) async {
    await session.home.load()
    await session.notifications.load()
    await session.bookings.load()
    await session.chat.loadConversations()
}


/// A route that opens one request's page, as a notification does.
private func requestRoute(_ number: Int) -> GroomerRequestsRoute {
    GroomerRequestsRoute(segment: .matches, requestID: GroomerSandboxFixtures.id(200 + number), offerID: nil)
}

/// A route that opens one offer's page.
private func offerRoute(_ number: Int) -> GroomerRequestsRoute {
    GroomerRequestsRoute(segment: .offers, requestID: nil, offerID: GroomerSandboxFixtures.id(500 + number))
}


#Preview("Groomer Requests") { GroomerFlowSandbox(startsOn: .requests).id("requests") }
#Preview("Groomer Requests: Offers segment") { GroomerFlowSandbox(startsOn: .requests, route: .offers).id("offers") }
#Preview("Groomer Requests: nothing yet") { GroomerFlowSandbox(state: .empty, startsOn: .requests).id("empty") }
// The Requests tab as stills (design): the page alone, already dealt in and with its data (a snapshot is taken at the first frame).
#Preview("Groomer Requests: Matches, the whole page, a still", traits: .fixedLayout(width: 393, height: 820)) {
    GroomerPageHost(prepare: loadRequestLists) { session in
        GroomerRequestsView(route: .constant(.matches), requests: session.requests, offers: session.offers)
    }.id("listMatches")
}
#Preview("Groomer Requests: Offers, the whole page, a still", traits: .fixedLayout(width: 393, height: 820)) {
    GroomerPageHost(prepare: loadRequestLists) { session in
        GroomerRequestsView(route: .constant(.offers), requests: session.requests, offers: session.offers)
    }.id("listOffers")
}
#Preview("Groomer Requests: Offers, one to replace, a still", traits: .fixedLayout(width: 393, height: 520)) {
    GroomerRequestMoment.timingMissing.list(.offers).id("listReplace")
}
#Preview("Groomer Requests: Matches, nothing left to answer, a still", traits: .fixedLayout(width: 393, height: 520)) {
    GroomerRequestMoment.timingMissing.list(.matches).id("listAnswered")
}
#Preview("Groomer Requests: Matches, one still being checked, a still", traits: .fixedLayout(width: 393, height: 520)) {
    GroomerRequestMoment.checking.list(.matches).id("listChecking")
}
#Preview("Groomer Requests: Matches, long names and many marks, a still", traits: .fixedLayout(width: 393, height: 640)) {
    GroomerPageHost(matches: GroomerSandboxFixtures.stressMatches(), prepare: loadRequestLists) { session in
        GroomerRequestsView(route: .constant(.matches), requests: session.requests, offers: session.offers)
    }.id("listStress")
}
#Preview("Groomer request detail: Mochi, make an offer") { GroomerFlowSandbox(startsOn: .requests, route: requestRoute(1)).id("mochi") }
// The stills show a page's blocks already dealt in (a snapshot is taken at the first frame, before the entrance has played). The
// request page is one page for the request and its offer (design): opened from a match (Mochi, Rocky, Pepper) or from an offer (Bella,
// Milo), the whole page in one tall frame, since a snapshot does not scroll.
#Preview("Groomer request detail: Pepper, offer sent, the whole page, a still", traits: .fixedLayout(width: 393, height: 1900)) {
    GroomerFlowSandbox(startsOn: .requests, route: requestRoute(5)).environment(\.beckonRevealsInPlace, true).id("stillPepper")
}
#Preview("Groomer request detail: Bella, booked, opened from the offer, the whole page, a still",
         traits: .fixedLayout(width: 393, height: 1900)) {
    GroomerFlowSandbox(startsOn: .requests, route: offerRoute(2)).environment(\.beckonRevealsInPlace, true).id("stillBella")
}
#Preview("Groomer request detail: Milo, offer declined, opened from the offer, the whole page, a still",
         traits: .fixedLayout(width: 393, height: 1500)) {
    GroomerFlowSandbox(startsOn: .requests, route: offerRoute(3)).environment(\.beckonRevealsInPlace, true).id("stillMilo")
}
#Preview("Groomer request detail: checking, the whole page, a still", traits: .fixedLayout(width: 393, height: 1700)) {
    GroomerRequestMoment.checking.preview.id("momentChecking")
}
#Preview("Groomer request detail: an offer to replace, the whole page, a still", traits: .fixedLayout(width: 393, height: 1700)) {
    GroomerRequestMoment.timingMissing.preview.id("momentReplace")
}
#Preview("Groomer request detail: offer withdrawn, a new one, the whole page, a still", traits: .fixedLayout(width: 393, height: 2500)) {
    GroomerRequestMoment.withdrawn.preview.id("momentWithdrawn")
}
#Preview("Groomer request detail: match dismissed, the whole page, a still", traits: .fixedLayout(width: 393, height: 1500)) {
    GroomerRequestMoment.dismissed.preview.id("momentDismissed")
}
#Preview("Groomer Home") { GroomerFlowSandbox(startsOn: .home).id("home") }
#Preview("Groomer Home, the whole page, a still", traits: .fixedLayout(width: 393, height: 1180)) {
    GroomerHomePagePreview().id("homeWhole")
}
#Preview("Groomer Home: requests paused") { GroomerHomePagePreview(requestsPaused: true) }

struct GroomerHomePagePreview: View {
    var requestsPaused = false
    var body: some View {
        GroomerPageHost(prepare: { session in
            if requestsPaused {
                await session.account.load()
                session.account.isActive = false
                await session.account.saveProfile()
            }
            await loadHome(session)
        }) { session in
            GroomerHomeView(home: session.home, notifications: session.notifications, requests: session.requests,
                offers: session.offers, bookings: session.bookings, chat: session.chat, isActiveTab: true,
                unreadMessageCount: session.chat.unreadConversationCount, requestsAction: {}, offersAction: {}, bookingAction: { _ in },
                messagesAction: {}, availabilityAction: {}, scheduleAction: {}, accountAction: {})
        }
    }
}

#Preview("Loading: Groomer Requests as bars, a still") {
    GroomerFlowSandbox(state: .loading, startsOn: .requests).id("stillRequests")
}
#Preview("Loading: Groomer Offers as bars, a still") {
    GroomerFlowSandbox(state: .loading, startsOn: .requests, route: .offers).id("stillOffers")
}
#Preview("Loading: Groomer Requests, from empty to loaded") { GroomerLoadingDemo().id("loadingRequests") }
#Preview("Loading: Groomer Offers, from empty to loaded") { GroomerLoadingDemo(route: .offers).id("loadingOffers") }
// The whole page in one tall frame, to read the blocks below the first screen (a snapshot does not scroll).
#Preview("Groomer request detail: Mochi, the whole page, a still", traits: .fixedLayout(width: 393, height: 2500)) {
    GroomerFlowSandbox(startsOn: .requests, route: requestRoute(1)).environment(\.beckonRevealsInPlace, true).id("wholeMochi")
}
#Preview("Groomer request detail: Rocky, a size to confirm, the whole page, a still", traits: .fixedLayout(width: 393, height: 2500)) {
    GroomerFlowSandbox(startsOn: .requests, route: requestRoute(4)).environment(\.beckonRevealsInPlace, true).id("wholeRocky")
}

// Home, Schedule, Messages (design). The pages that need the shell's loading are hosted with it; the pushed pages stand alone.
#Preview("Groomer Home: nothing yet") { GroomerFlowSandbox(state: .empty, startsOn: .home).id("homeEmpty") }
#Preview("Groomer Home: a service under way") { GroomerFlowSandbox(state: .busyDay, startsOn: .home).id("homeBusy") }
#Preview("Loading: Groomer Home as bars, a still") {
    GroomerFlowSandbox(state: .loading, startsOn: .home).id("stillHome")
}
#Preview("Loading: Groomer Home, from empty to loaded") { GroomerLoadingDemo(startsOn: .home).id("loadingHome") }
#Preview("Groomer Schedule") { GroomerFlowSandbox(startsOn: .bookings).id("schedule") }
#Preview("Groomer Schedule: a busy day") { GroomerFlowSandbox(state: .busyDay, startsOn: .bookings).id("scheduleBusy") }
#Preview("Groomer Schedule: nothing booked") { GroomerFlowSandbox(state: .empty, startsOn: .bookings).id("scheduleEmpty") }
#Preview("Groomer Schedule: a busy day, the whole page, a still", traits: .fixedLayout(width: 393, height: 1250)) {
    GroomerPageHost(state: .busyDay) { session in
        GroomerScheduleView(store: session.bookings, focusedBooking: .constant(nil), isActiveTab: true, onOpenChat: { _ in },
            onSeeRequests: {})
    }
    .id("scheduleBusyWhole")
}
#Preview("Groomer Schedule: the now card and the rows, every state, a still", traits: .fixedLayout(width: 393, height: 1900)) {
    GroomerScheduleMoments().id("scheduleMoments")
}
#Preview("Loading: Groomer Schedule as bars, a still") {
    GroomerFlowSandbox(state: .loading, startsOn: .bookings).id("stillSchedule")
}
#Preview("Loading: Groomer Schedule, from empty to loaded") { GroomerLoadingDemo(startsOn: .bookings).id("loadingSchedule") }
#Preview("Groomer Messages") { GroomerFlowSandbox(startsOn: .messages).id("messages") }
#Preview("Groomer Messages: nothing yet") { GroomerFlowSandbox(state: .empty, startsOn: .messages).id("messagesEmpty") }
#Preview("Loading: Groomer Messages as bars, a still") {
    GroomerFlowSandbox(state: .loading, startsOn: .messages).id("stillMessages")
}
#Preview("Groomer notifications") {
    GroomerPageHost { session in
        GroomerNotificationsView(store: session.notifications, requestStore: session.requests, bookingStore: session.bookings,
            chatStore: session.chat)
    }.id("notifications")
}
#Preview("Groomer chat thread: Bella") {
    GroomerPageHost { session in
        GroomerThreadPreview(session: session)
    }.id("thread")
}
#Preview("Groomer booking detail: Bella, booked", traits: .fixedLayout(width: 393, height: 1600)) {
    GroomerPageHost { session in
        BookingDetailView(bookingID: GroomerSandboxFixtures.id(603), role: .groomer, store: session.bookings)
    }.id("bookingBella")
}
#Preview("Groomer booking detail: Rosie, service under way", traits: .fixedLayout(width: 393, height: 1600)) {
    GroomerPageHost(state: .busyDay) { session in
        BookingDetailView(bookingID: GroomerSandboxFixtures.id(607), role: .groomer, store: session.bookings)
    }.id("bookingRosie")
}
#Preview("Groomer booking detail: time to start", traits: .fixedLayout(width: 393, height: 1600)) { GroomerBookingMoment.due.preview.id("bookingDue") }
#Preview("Groomer booking detail: reported by the customer", traits: .fixedLayout(width: 393, height: 1600)) {
    GroomerBookingMoment.reportedByCustomer.preview.id("bookingReported")
}
#Preview("Groomer booking detail: ended, not closed", traits: .fixedLayout(width: 393, height: 1600)) {
    GroomerBookingMoment.needsClosing.preview.id("bookingNeedsClosing")
}
#Preview("Groomer booking detail: finished, waiting for a review", traits: .fixedLayout(width: 393, height: 1600)) {
    GroomerBookingMoment.finished.preview.id("bookingFinished")
}
#Preview("Groomer booking detail: reviewed", traits: .fixedLayout(width: 393, height: 1600)) { GroomerBookingMoment.reviewed.preview.id("bookingReviewed") }
#Preview("Groomer booking detail: cancelled by the customer", traits: .fixedLayout(width: 393, height: 1000)) {
    GroomerBookingMoment.cancelled.preview.id("bookingCancelled")
}


/// The thread of the first conversation, once the conversations are loaded.
struct GroomerThreadPreview: View {
    let session: GroomerSandboxSession
    @State private var conversation: ChatConversation?

    var body: some View {
        Group {
            if let conversation {
                ChatThreadView(participantID: session.groomerID, role: .groomer, conversation: conversation, store: session.chat)
            } else {
                Color.clear
            }
        }
        .task {
            await session.chat.loadConversations()
            conversation = session.chat.conversations.first
        }
    }
}

// Account (design). A pushed page stands alone in `GroomerAccountPageHost`, which loads the profile first, as the hub does.
#Preview("Groomer Account") { GroomerFlowSandbox(startsOn: .account).id("account") }
#Preview("Groomer Account: a new groomer") { GroomerFlowSandbox(state: .empty, startsOn: .account).id("accountNew") }
#Preview("Groomer Account, the whole page, a still", traits: .fixedLayout(width: 393, height: 1300)) {
    GroomerAccountPageHost { GroomerAccountView(store: $0, requestedRoute: .constant(nil), onSignOut: {}) }.id("accountWhole")
}
#Preview("Loading: Groomer Account as bars, a still") {
    GroomerFlowSandbox(state: .loading, startsOn: .account).id("stillAccount")
}
#Preview("Loading: Groomer Account, from empty to loaded") { GroomerLoadingDemo(startsOn: .account).id("loadingAccount") }
#Preview("Groomer profile settings", traits: .fixedLayout(width: 393, height: 2300)) {
    GroomerAccountPageHost { GroomerProfileEditorView(store: $0) }.id("profile")
}
#Preview("Groomer services") { GroomerAccountPageHost { GroomerServicesEditorView(store: $0) }.id("services") }
#Preview("Groomer services: none yet") {
    GroomerAccountPageHost(state: .empty) { GroomerServicesEditorView(store: $0) }.id("servicesEmpty")
}
#Preview("Groomer service form", traits: .fixedLayout(width: 393, height: 1700)) {
    GroomerAccountPageHost(opens: { if let first = $0.services.first { $0.startEditService(first) } }) { GroomerServiceFormView(store: $0) }.id("serviceForm")
}
#Preview("Groomer availability", traits: .fixedLayout(width: 393, height: 1400)) {
    GroomerAccountPageHost { GroomerAvailabilityEditorView(store: $0) }.id("availability")
}
// The pet-fit pages as stills (design): the page alone, loaded, with the photos drawn.
#Preview("Groomer portfolio, the whole page, a still", traits: .fixedLayout(width: 393, height: 900)) {
    GroomerAccountPageHost { GroomerPortfolioEditorView(store: $0) }.id("portfolio")
}
#Preview("Groomer portfolio: no photo yet", traits: .fixedLayout(width: 393, height: 480)) {
    GroomerAccountPageHost(state: .empty) { GroomerPortfolioEditorView(store: $0) }.id("portfolioEmpty")
}
#Preview("Groomer portfolio photo", traits: .fixedLayout(width: 393, height: 1500)) {
    GroomerAccountPageHost { store in
        if let photo = store.sortedPortfolioPhotos().first { GroomerPortfolioPhotoView(photo: photo, store: store) }
    }.id("portfolioPhoto")
}
#Preview("Groomer fit signals", traits: .fixedLayout(width: 393, height: 1900)) {
    GroomerAccountPageHost { GroomerFitSignalsEditorView(store: $0) }.id("fitSignals")
}
#Preview("Groomer fit signals: every slot used", traits: .fixedLayout(width: 393, height: 1900)) {
    GroomerAccountPageHost(state: .slotsFull) { GroomerFitSignalsEditorView(store: $0) }.id("fitSignalsFull")
}
#Preview("Groomer evidence, the whole page, a still", traits: .fixedLayout(width: 393, height: 860)) {
    GroomerAccountPageHost { GroomerEvidenceDashboardView(store: $0) }.id("evidence")
}
#Preview("Groomer evidence: nothing yet", traits: .fixedLayout(width: 393, height: 360)) {
    GroomerAccountPageHost(state: .empty) { GroomerEvidenceDashboardView(store: $0) }.id("evidenceEmpty")
}


/// A page of the Account on its own: it loads the profile as the hub does for the pages under it. `opens` runs after the load, for a
/// page that needs the store in a state (a service being edited).
struct GroomerAccountPageHost<Page: View>: View {
    var state: GroomerSandboxState = .loaded
    var opens: ((GroomerProfileStore) -> Void)?
    private let page: (GroomerProfileStore) -> Page
    @State private var session: GroomerSandboxSession

    init(state: GroomerSandboxState = .loaded, opens: ((GroomerProfileStore) -> Void)? = nil,
         @ViewBuilder page: @escaping (GroomerProfileStore) -> Page) {
        self.state = state
        self.opens = opens
        self.page = page
        let session = GroomerSandboxSession(state: state)
        // A still is a picture of the first frame: the fixture photos are in the store before the page is, not fetched after it.
        if state != .empty {
            for (index, id) in GroomerSandboxFixtures.portfolioPhotoIDs.enumerated() {
                session.account.portfolioPhotoDataByID[id] = GroomerSandboxFixtures.portfolioImage(sortOrder: index)
            }
        }
        // The week too: a page that gets its days after its first frame is photographed with the five open days still sliding in.
        if state != .loading { session.account.populateAvailabilityForm(with: GroomerSandboxFixtures.weekWindows) }
        _session = State(initialValue: session)
    }

    var body: some View {
        NavigationStack { page(session.account) }
            .environment(\.beckonFeedbackCenter, BeckonFeedbackCenter())
            .environment(\.beckonRole, .groomer)
            .environment(\.beckonRevealsInPlace, true)
            .task {
                await session.account.load()
                opens?(session.account)
            }
    }
}


/// The Schedule's big card in the three moments it has, and a row in each state that is not the ordinary one: built from the
/// fixtures with the phase said by hand, so every look is one preview away whatever the time of day is.
struct GroomerScheduleMoments: View {
    private let calendar = GroomerSandboxFixtures.calendar
    private let bookings = GroomerSandboxFixtures.bookings(busyDay: true)

    private func item(_ pet: String, _ phase: GroomerSlotPhase) -> GroomerSchedulePlan.Item? {
        guard let booking = bookings.first(where: { $0.requestPetSnapshot?.name == pet }),
              let slot = GroomerScheduleSlot(booking) else { return nil }
        return GroomerSchedulePlan.Item(slot: slot, phase: phase)
    }

    /// The day's strip of hours for tomorrow's two bookings: with the hours the groomer is open, and with now in the middle of them.
    @ViewBuilder
    private var shapes: some View {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let items = ["Cooper", "Daisy"].compactMap { item($0, .upcoming) }
        GroomerDayShapeBar(shape: GroomerDayShape(items: items, dayStart: tomorrow, open: 540...1020, now: nil))
        GroomerDayShapeBar(shape: GroomerDayShape(items: items, dayStart: tomorrow, open: 540...1020,
            now: calendar.date(bySettingHour: 10, minute: 15, second: 0, of: tomorrow)))
    }

    var body: some View {
        GroomerPageHost(state: .busyDay) { _ in
            ZStack {
                BeckonExpressiveBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        shapes
                        if let live = item("Rosie", .live) {
                            GroomerNowCard(item: live, calendar: calendar, now: Date(), onOpen: {}, onMessage: {}, onComplete: {})
                        }
                        if let due = item("Teddy", .due) {
                            GroomerNowCard(item: due, calendar: calendar, now: Date(), onOpen: {}, onMessage: {}, onStart: {})
                        }
                        if let next = item("Teddy", .upcoming) {
                            GroomerNowCard(item: next, calendar: calendar, now: Date(), onOpen: {}, onMessage: {})
                        }
                        if let row = item("Daisy", .upcoming) {
                            GroomerFreeTimeLine(freeTime: .free(minutes: 65))
                            GroomerAppointmentRow(item: row, calendar: calendar, onOpen: {}, onMessage: {})
                            GroomerFreeTimeLine(freeTime: .backToBack)
                        }
                        if let row = item("Cooper", .due) {
                            GroomerAppointmentRow(item: row, calendar: calendar, onOpen: {}, onMessage: {})
                        }
                        if let row = item("Oscar", .live) {
                            GroomerAppointmentRow(item: row, calendar: calendar, onOpen: {}, onMessage: {}, onComplete: {})
                        }
                        if let row = item("Bella", .needsClosing) {
                            GroomerFreeTimeLine(freeTime: .overlap)
                            GroomerAppointmentRow(item: row, calendar: calendar, onOpen: {}, onMessage: {})
                        }
                        if let row = item("Milo", .waiting("Outcome awaiting confirmation")) {
                            GroomerAppointmentRow(item: row, calendar: calendar, onOpen: {}, onMessage: {})
                        }
                        if let row = item("Nala", .done) {
                            GroomerAppointmentRow(item: row, calendar: calendar, onOpen: {}, onMessage: {})
                        }
                    }
                    .beckonPageInsets()
                }
            }
        }
    }
}


/// A booking of the groomer's in the moment a preview needs, whatever the time of day is: due now, reported, ended and not closed,
/// finished, reviewed, cancelled. Each is the fixtures' booking number 7, alone in its own session.
enum GroomerBookingMoment: CaseIterable {
    case due, reportedByCustomer, needsClosing, finished, reviewed, cancelled

    var booking: Booking {
        let now = Date()
        let pet = GroomerSandboxFixtures.pet(14, name: "Rosie", breed: "Cocker Spaniel", size: "M", weight: 28, temperament: "Calm",
            notes: "Sensitive around the ears; keep the dryer low.", medical: "Allergic to oatmeal shampoo.", coat: "Wavy coat",
            birthday: "2021-06-12")
        func make(from start: TimeInterval, to end: TimeInterval, status: BookingStatus = .confirmed,
                  phase: BookingFulfillmentPhase = .scheduled, reportedBy: GroomerSandboxFixtures.Reporter? = nil,
                  review: String? = nil) -> Booking {
            GroomerSandboxFixtures.booking(7, pet: pet, service: .fullGroom, start: now.addingTimeInterval(start),
                end: now.addingTimeInterval(end), price: 95, status: status, street: "88 Maple Court", zip: "98109", phase: phase,
                startedAt: phase == .scheduled ? nil : now.addingTimeInterval(start + 120), reportedBy: reportedBy, reviewText: review,
                serviceNotes: "Please ring twice; the bell is quiet.")
        }
        switch self {
        case .due: return make(from: -600, to: 6_600)
        case .reportedByCustomer: return make(from: -10_800, to: -3_600, phase: .outcomeReported, reportedBy: .customer)
        case .needsClosing: return make(from: -10_800, to: -3_600)
        case .finished: return make(from: -10_800, to: -3_600, status: .completed)
        case .reviewed: return make(from: -86_400, to: -79_200, status: .completed, review: "Rosie came home calm and smelling lovely. Thank you!")
        case .cancelled: return make(from: 86_400, to: 93_600, status: .cancelledByCustomer, phase: .cancelled)
        }
    }

    var preview: some View {
        GroomerPageHost(bookings: [booking]) { session in
            BookingDetailView(bookingID: GroomerSandboxFixtures.id(607), role: .groomer, store: session.bookings)
        }
    }
}


/// A request of the groomer's in the moment a preview needs, whatever the fixtures hold: still being checked, an offer that has to be
/// replaced, an offer that was withdrawn, a match that was dismissed. Each is alone in its own session, opened as a notification would.
enum GroomerRequestMoment: CaseIterable {
    case checking, timingMissing, withdrawn, dismissed

    var matched: GroomerMatchedRequest {
        let base = GroomerSandboxFixtures.matches()
        switch self {
        case .checking:
            let luna = base[2]
            var match = luna.match
            match.eligibilityEvaluation = MatchEligibilityEvaluation(state: "pending", reason: nil, serviceStart: nil, serviceEnd: nil)
            return GroomerMatchedRequest(match: match, request: luna.request, offer: nil)
        case .timingMissing:
            let pepper = base[4]
            var offer = pepper.offer
            offer?.timingSnapshotLoaded = true
            return GroomerMatchedRequest(match: pepper.match, request: pepper.request, offer: offer, matchingEvidence: pepper.matchingEvidence)
        case .withdrawn:
            let luna = base[2]
            let offer = GroomerSandboxFixtures.offer(9, for: luna.request, matchID: luna.match.id, price: 70, status: .withdrawnByGroomer,
                startHours: 52, message: "Teddy-bear cut, done gently.")
            return GroomerMatchedRequest(match: luna.match, request: luna.request, offer: offer)
        case .dismissed:
            let biscuit = base[1]
            return GroomerMatchedRequest(match: biscuit.match.replacing(status: .dismissed), request: biscuit.request, offer: nil)
        }
    }

    /// The Requests tab with this moment's request, and its offer, alone in it.
    func list(_ route: GroomerRequestsRoute) -> some View {
        let matched = matched
        let items = matched.offer.map { [GroomerOfferListItem(offer: $0, request: matched.request, booking: nil)] } ?? []
        return GroomerPageHost(matches: [matched], offers: items, prepare: loadRequestLists) { session in
            GroomerRequestsView(route: .constant(route), requests: session.requests, offers: session.offers)
        }
    }

    var preview: some View {
        let matched = matched
        let items = matched.offer.map { [GroomerOfferListItem(offer: $0, request: matched.request, booking: nil)] } ?? []
        return GroomerPageHost(matches: [matched], offers: items, prepare: { session in
            _ = try? await session.requests.resolveNotificationRequest(id: matched.request.id)
            await session.offers.load()
        }) { session in
            GroomerRequestDetailView(target: GroomerRequestTarget.match(matched.match.id), requests: session.requests,
                offers: session.offers)
        }
        .environment(\.beckonRevealsInPlace, true)
    }
}
#endif
