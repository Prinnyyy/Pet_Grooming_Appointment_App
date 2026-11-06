import SwiftUI

@MainActor
struct GroomerGroomingSession {
    let groomerID: UUID
    let requests: GroomerRequestsStore
    let offers: GroomerOffersStore
    let bookings: BookingsStore
    let chat: ChatStore
    let notifications: GroomerNotificationsStore?
    let requestRepository: any GroomerRequestRepository
    let chatRepository: any ChatRepository
    let bookingRepository: any BookingRepository
    let isCurrent: @MainActor () -> Bool

    func localReschedule(for bookingID: UUID) -> BookingRescheduleProposal? {
        bookings.rescheduleSnapshots[bookingID]?.proposal
    }
    func timeChangeHistory(for bookingID: UUID) -> [BookingTimeChangeActivity] {
        bookings.rescheduleSnapshots[bookingID]?.history ?? []
    }
}

extension EnvironmentValues {
    @Entry var groomerGroomingWorkspace: GroomerGroomingWorkspace? = nil
}

/// Coordinates the existing account-bound stores without creating a second mutation owner.
@MainActor @Observable
final class GroomerGroomingWorkspace {
    enum Section: String, CaseIterable { case matches = "Matches", offers = "Offers", bookings = "Bookings" }

    /// Only quote changes and time proposals need local receipts; notifications have their own.
    enum Update: Hashable {
        case notification(UUID)
        case offerIssue(UUID, GroomerRequestStage.Problem, requestVersion: String?)
        case closedOffer(UUID)
        case timeChange(UUID, BookingRescheduleStatus)
        var receiptKey: String {
            switch self {
            case .notification(let id): "notification/\(id)"
            case .offerIssue(let id, let problem, let revision): "offer/\(id)/\(problem)/\(revision ?? "")"
            case .closedOffer(let id): "closed/\(id)"
            case .timeChange(let id, let status): "time/\(id)/\(status.rawValue)"
            }
        }
    }

    enum MatchLocation: String, CaseIterable {
        case all = "All", studio = "Studio", home = "Home visits"

        func includes(_ mode: GroomingLocationMode) -> Bool {
            switch self {
            case .all: true
            case .studio: mode == .customerComesToGroomer
            case .home: mode == .groomerComesToCustomer
            }
        }
    }

    let session: GroomerGroomingSession
    private(set) var matches: [GroomerMatchedRequest] = []
    private(set) var offers: [GroomerOfferListItem] = []
    private(set) var bookings: [Booking] = []
    private(set) var loaded: Set<Section> = []
    private(set) var errors: [Section: String] = [:]
    private var reads: [String: Task<Void, Never>] = [:]
    private var matchLocation: GroomingLocationMode?
    private var offerGroup = "waiting"
    private var bookingsClosed = false
    private var matchPages: [String: RankedPage<GroomerMatchedRequest>] = [:]
    private var offerPages: [String: [GroomerOfferListItem]] = [:]
    private var bookingPages: [String: [Booking]] = [:]
    private var nextPages: [String: ListPageRequest] = [:]
    private var loadedKeys: Set<String> = []
    private var petPhotos: [UUID: Data] = [:]
    private var petPhotoReads: Set<UUID> = []
    private var photoReadAt: [UUID: Date] = [:]
    private var bookingCardReads: Set<UUID> = []
    private var bookingCardReadAt: [UUID: (revision: String, date: Date)] = [:]
    private let presentationReuseInterval: TimeInterval = 15
    private(set) var lastSentOfferID: UUID?
    private var seenChangeKeys: Set<String> = []

    init(session: GroomerGroomingSession) {
        self.session = session
        seenChangeKeys = GroomingReadStateCache.shared.keys(accountID: session.groomerID)
        matches = session.requests.matchedRequests
        offers = session.offers.offers
        bookings = session.bookings.bookings
    }

    /// Update the cached row in place while the detail is on screen. A back swipe then reveals the right dot immediately.
    func reflectOpenedMatch(_ row: GroomerMatchedRequest) {
        guard row.match.status == .viewed, let i = matches.firstIndex(where: { $0.id == row.id }),
              matches[i].match.status == .visible else { return }
        matches[i] = row
        for (key, page) in matchPages {
            matchPages[key] = page.mapping { $0.id == row.id ? row : $0 }
        }
    }

    func select(location: GroomingLocationMode?, offers group: String, bookingsClosed closed: Bool) {
        matchLocation = location; offerGroup = group; bookingsClosed = closed
        matches = matchPages[pageKey(.matches)]?.items ?? []
        offers = offerPages[pageKey(.offers)] ?? []
        bookings = bookingPages[pageKey(.bookings)] ?? []
        loaded = Set([Section.matches, .offers, .bookings].filter { loadedKeys.contains(pageKey($0)) })
    }

    private func pageKey(_ section: Section) -> String {
        switch section {
        case .matches: "matches/" + (matchLocation?.rawValue ?? "all")
        case .offers: "offers/" + offerGroup
        case .bookings: "bookings/" + (bookingsClosed ? "closed" : "active")
        }
    }

    // Pager neighbours read their own scope, never the currently selected page's rows.
    func cachedMatches(location: GroomingLocationMode?) -> [GroomerMatchedRequest] {
        matchPages["matches/" + (location?.rawValue ?? "all")]?.items
            ?? session.requests.matchedRequests.filter { location == nil || $0.request.locationMode == location }
    }
    func cachedOffers(group: String) -> [GroomerOfferListItem] { offerPages["offers/" + group] ?? session.offers.offers }
    func cachedBookings(closed: Bool) -> [Booking] { bookingPages["bookings/" + (closed ? "closed" : "active")] ?? session.bookings.bookings }
    func hasLoadedPage(_ key: String) -> Bool { loadedKeys.contains(key) }

    func refresh(_ section: Section) async { await readPage(section, append: false) }
    func loadMore(_ section: Section) async { await readPage(section, append: true) }

    func hasMore(_ section: Section) -> Bool {
        let key = pageKey(section)
        return section == .matches ? matchPages[key]?.nextCursor != nil : nextPages[key] != nil
    }

    private func readPage(_ section: Section, append: Bool) async {
        guard session.isCurrent() else { return }
        let key = pageKey(section)
        if let read = reads[key] { await read.value; return }
        if append && !hasMore(section) { return }
        let location = matchLocation, group = offerGroup, closed = bookingsClosed
        let read = Task { @MainActor in
            do {
                switch section {
                case .matches:
                    let previous = matchPages[key]
                    let page = try await session.requestRepository.groomingMatches(groomerID: session.groomerID,
                        location: location, page: .init(mode: session.requests.sort, cursor: append ? previous?.nextCursor : nil))
                    guard session.isCurrent(), !Task.isCancelled else { return }
                    session.requests.adoptGroomingMatches(page.items)
                    if append, let previous {
                        guard previous.canAppend(page) else { throw MatchRankingError.listChanged }
                        matchPages[key] = RankedPage(items: ListPageMerge.appendingUnique(page.items, to: previous.items),
                            rankingRevision: page.rankingRevision, scoreAsOf: page.scoreAsOf, validUntil: page.validUntil,
                            algorithmVersion: page.algorithmVersion, requestedMode: page.requestedMode, effectiveMode: page.effectiveMode,
                            pendingCount: page.pendingCount, assessmentCount: page.assessmentCount, nextCursor: page.nextCursor)
                    } else { matchPages[key] = page }
                case .offers:
                    let page = try await session.requestRepository.groomingOffers(groomerID: session.groomerID, group: group,
                        page: append ? nextPages[key] ?? .first : .first)
                    guard session.isCurrent(), !Task.isCancelled else { return }
                    offerPages[key] = append ? ListPageMerge.appendingUnique(page.items, to: offerPages[key] ?? []) : page.items
                    nextPages[key] = page.nextRequest
                case .bookings:
                    let page = try await session.bookingRepository.groomingBookings(participantID: session.groomerID, closed: closed,
                        page: append ? nextPages[key] ?? .first : .first)
                    guard session.isCurrent(), !Task.isCancelled else { return }
                    bookingPages[key] = append ? ListPageMerge.appendingUnique(page.items, to: bookingPages[key] ?? []) : page.items
                    nextPages[key] = page.nextRequest
                    for booking in page.items { session.bookings.synchronizeExternalBooking(booking) }
                }
                loadedKeys.insert(key)
                if pageKey(section) == key {
                    errors[section] = nil
                    select(location: matchLocation, offers: offerGroup, bookingsClosed: bookingsClosed)
                }
            } catch {
                guard session.isCurrent(), !Task.isCancelled else { return }
                if pageKey(section) == key {
                    errors[section] = error is MatchRankingError ? "The list changed. Refresh to continue." : "Could not refresh this list."
                }
            }
        }
        reads[key] = read
        await read.value
        reads[key] = nil
    }

    func offerItem(id: UUID, forceRefresh: Bool = false) async throws -> GroomerOfferListItem? {
        if !forceRefresh, let cached = offers.first(where: { $0.id == id }) { return cached }
        let item = try await session.requestRepository.offerDetail(groomerID: session.groomerID, offerID: id)
        guard session.isCurrent(), !Task.isCancelled else { throw CancellationError() }
        if let booking = item?.booking { session.bookings.synchronizeExternalBooking(booking) }
        return item
    }

    func offerDraft(for match: GroomerMatchedRequest, form: GroomerOfferFormState) throws -> GroomerOfferDraft {
        guard let start = form.resolvedProposedStart,
              start >= Date().addingTimeInterval(GroomingServiceTiming.minimumLeadTime) else { throw GroomerVisitOfferStartError() }
        guard let end = form.proposedEnd else { throw GroomerOfferFormError(message: "Choose a valid duration.") }
        return try session.requests.makeOfferDraft(matchedRequest: match, proposedStart: start, proposedEnd: end,
            priceEstimateText: form.priceEstimateText, message: form.message, confirmedAssessmentKeys: [], now: Date())
    }

    func sendOffer(_ draft: GroomerOfferDraft) async throws {
        guard session.isCurrent(), let match = session.requests.authorizedDetail,
              match.request.id == draft.requestID, match.request.termsRevision == draft.expectedRequestRevision else {
            throw GroomerOfferFormError(message: "This request changed. Refresh it before sending an offer.")
        }
        await session.requests.submitOffer(for: match, proposedStart: draft.proposedStart, proposedEnd: draft.proposedEnd,
            priceEstimateText: GroomerVisitOfferInput.displayPrice(Decimal(draft.priceEstimate)), message: draft.message ?? "")
        guard !Task.isCancelled, session.isCurrent() else { throw CancellationError() }
        if let error = session.requests.actionErrorMessage { throw GroomerOfferFormError(message: error) }
        guard let sent = session.requests.authorizedDetail?.offer, sent.status == .pending else {
            throw GroomerOfferFormError(message: "Please refresh to check whether your offer was sent.")
        }
        lastSentOfferID = sent.id
    }

    func booking(for item: GroomerOfferListItem) -> Booking? {
        booking(for: item.offer, listedBooking: item.booking)
    }

    func booking(for offer: GroomerOffer, listedBooking: Booking?) -> Booking? {
        func belongs(_ b: Booking) -> Bool {
            b.offerID == offer.id && b.requestID == offer.requestID &&
                b.customerID == offer.customerID && b.groomerID == offer.groomerID
        }
        return session.bookings.bookings.first(where: belongs) ?? bookings.first(where: belongs) ?? listedBooking.flatMap { belongs($0) ? $0 : nil }
    }

    func offerUpdates(_ entry: GroomerOfferGroups.Entry, now: Date) -> Set<Update> {
        return offerDetailUpdates(entry.item, stage: entry.stage)
    }

    func offerDetailUpdates(_ item: GroomerOfferListItem, stage: GroomerRequestStage) -> Set<Update> {
        var updates = notificationUpdates(offerID: item.id)
        if let problem = stage.problem, problem.needsAttention {
            updates.insert(.offerIssue(item.id, problem, requestVersion: item.request?.updatedAt))
        } else if stage.kind == .closed, item.offer.status != .withdrawnByGroomer {
            updates.insert(.closedOffer(item.id))
        }
        return updates.filter { !seenChangeKeys.contains($0.receiptKey) }
    }

    func bookingUpdates(_ booking: Booking, now: Date) -> Set<Update> {
        bookingUpdates(booking, proposal: session.localReschedule(for: booking.id), now: now)
    }

    func displayedBookingUpdates(_ id: UUID, now: Date) -> Set<Update> {
        guard let booking = session.bookings.booking(withID: id) else { return [] }
        // The detail may still be loading its proposal. Only acknowledge the version it can display.
        return bookingUpdates(booking, proposal: session.bookings.rescheduleSnapshots[id]?.proposal, now: now)
    }

    private func bookingUpdates(_ booking: Booking, proposal: BookingRescheduleProposal?, now: Date) -> Set<Update> {
        var updates = notificationUpdates(offerID: booking.offerID, booking: booking)
        if let proposal, proposal.bookingID == booking.id {
            let status = proposal.currentStatus(for: booking, now: now)
            switch (proposal.initiatorID, status) {
            case (booking.customerID, .pending), (booking.customerID, .withdrawn),
                 (booking.groomerID, .accepted), (booking.groomerID, .rejected):
                updates.insert(.timeChange(proposal.id, status))
            default: break
            }
        }
        return updates.filter { !seenChangeKeys.contains($0.receiptKey) }
    }

    private func notificationUpdates(offerID: UUID, booking: Booking? = nil) -> Set<Update> {
        Set((session.notifications?.notifications ?? []).compactMap { note in
            guard !note.isRead, note.groomerID == session.groomerID else { return nil }
            switch note.kind {
            case .offerAccepted:
                guard note.relatedOfferID == offerID || (booking != nil && note.relatedBookingID == booking?.id) else { return nil }
            case .bookingCancelledByCustomer:
                guard let booking, booking.status == .cancelledByCustomer, note.relatedBookingID == booking.id else { return nil }
            default: return nil // Chat messages are read in Messages.
            }
            return .notification(note.id)
        })
    }

    func didDisplay(_ updates: Set<Update>) {
        guard !updates.isEmpty else { return }
        var notices: [GroomerNotification] = []
        for update in updates {
            if case .notification(let id) = update {
                if let notice = (session.notifications?.notifications ?? []).first(where: { $0.id == id && !$0.isRead }) { notices.append(notice) }
            } else { seenChangeKeys.insert(update.receiptKey) }
        }
        GroomingReadStateCache.shared.record(updates.map(\.receiptKey), accountID: session.groomerID)
        if !notices.isEmpty {
            Task { for note in notices { await session.notifications?.markRead(note) } }
        }
    }

    func photo(for requestID: UUID) -> Data? { petPhotos[requestID] }

    func loadPetPhoto(requestID: UUID) async {
        guard session.isCurrent() else { return }
        if let read = photoReadAt[requestID], Date().timeIntervalSince(read) < presentationReuseInterval { return }
        guard petPhotoReads.insert(requestID).inserted else { return }
        defer { petPhotoReads.remove(requestID) }
        do {
            let data = try await session.requestRepository.petPhoto(requestID: requestID)
            try Task.checkCancellation()
            guard session.isCurrent() else { return }
            petPhotos[requestID] = data
            photoReadAt[requestID] = Date()
        } catch let error as GroomerRequestRepositoryError where error == .notAllowed || error == .matchNotFound {
            petPhotos[requestID] = nil
        } catch { /* Preserve cached portraits on transient failures. */ }
    }

    /// Recycled / neighbouring pager cards share short-lived display reads. Detail actions
    /// still use the stores directly and never rely on this presentation freshness window.
    func loadBookingCard(_ booking: Booking) async {
        guard session.isCurrent(), !bookingCardReads.contains(booking.id) else { return }
        if let read = bookingCardReadAt[booking.id], read.revision == booking.updatedAt,
           Date().timeIntervalSince(read.date) < presentationReuseInterval { return }
        bookingCardReads.insert(booking.id)
        defer { bookingCardReads.remove(booking.id) }
        async let presentation: Void = session.bookings.loadPresentation(for: booking)
        async let reschedule: Void = session.bookings.loadReschedule(for: booking.id)
        _ = await (presentation, reschedule)
        guard session.isCurrent(), !Task.isCancelled,
              session.bookings.rescheduleErrors[booking.id] == nil else { return }
        bookingCardReadAt[booking.id] = (booking.updatedAt, Date())
    }

    /// Explicit pull-to-refresh bypasses the recycled-card freshness window.
    func refreshCardPresentation(_ section: Section) async {
        guard session.isCurrent() else { return }
        if section == .bookings {
            let rows = bookings
            for row in rows { bookingCardReadAt[row.id] = nil }
            await withTaskGroup(of: Void.self) { group in
                for row in rows { group.addTask { [self, row] in await loadBookingCard(row) } }
            }
        } else {
            let ids = Array(Set(section == .matches ? matches.map(\.request.id) : offers.map(\.offer.requestID)))
            for id in ids { photoReadAt[id] = nil }
            await withTaskGroup(of: Void.self) { group in
                for id in ids { group.addTask { [self, id] in await loadPetPhoto(requestID: id) } }
            }
        }
    }

    func petProfilePhotos(for requestID: UUID, matched: GroomerMatchedRequest? = nil) -> [GroomerPetCard.Photo] {
        let store = session.requests
        let photos = matched.map { store.requestPhotos(for: $0) } ?? store.requestPhotosByRequestID[requestID, default: []]
        return photos.sorted { $0.sortOrder < $1.sortOrder }.map {
            .init(id: $0.id.uuidString, data: store.requestPhotoData(for: $0), label: $0.caption ?? $0.fileName)
        }
    }

    // A decision belongs to the current groomer. Reading an update never resolves one.
    func matchDecision(_ match: GroomerMatchedRequest, now: Date) -> String? {
        if match.canCreateOffer {
            return match.request.invitationState == .awaitingResponse ? "Reply to invitation" : nil
        }
        return GroomerRequestStage(.init(matched: match), now: now).hold == .species ? "Confirm accepted species" : nil
    }

    func offerDecision(_ entry: GroomerOfferGroups.Entry) -> String? {
        if let problem = entry.stage.problem, problem.needsAttention {
            return GroomerVisitOfferReplacement(problem)?.reason ?? "Review offer time"
        }
        return nil
    }

    func bookingDecision(_ booking: Booking, now: Date) -> String? {
        guard booking.groomerID == session.groomerID, booking.status == .confirmed else { return nil }
        if needsTimeReply(booking, now: now) { return "Reply to time change" }
        return nil
    }

    func bookingPriority(_ booking: Booking, now: Date) -> Int {
        if booking.status == .confirmed, let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart), start <= now { return 0 }
        if needsTimeReply(booking, now: now) { return 2 }
        return 3
    }

    private func needsTimeReply(_ booking: Booking, now: Date) -> Bool {
        session.localReschedule(for: booking.id)?.actions(for: booking, participantID: session.groomerID, now: now).contains(.accept) == true
    }

    static func closedAt(_ booking: Booking) -> String {
        booking.cancelledAt ?? booking.completedAt ?? booking.fulfillment?.actualEndedAt ?? booking.updatedAt
    }
}

struct GroomerGroomingCardContent {
    let row: GroomerRequestRowContent
    var archiveDay: ArchiveDay? = nil

    /// Completed history is read by calendar date, using the same service zone as the appointment.
    struct ArchiveDay {
        let year, month, day: String
        var spoken: String { "\(month) \(day), \(year)" }

        init?(start: String, zoneIdentifier: String?, now: Date) {
            guard let date = GroomingRequestDateFormatting.parsedDate(from: start),
                  let zoneIdentifier, let zone = TimeZone(identifier: zoneIdentifier) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "en_US")
            calendar.timeZone = zone
            guard let anniversary = calendar.date(byAdding: .year, value: 1, to: calendar.startOfDay(for: date)),
                  anniversary <= calendar.startOfDay(for: now) else { return nil }
            year = String(calendar.component(.year, from: date))
            month = calendar.shortMonthSymbols[calendar.component(.month, from: date) - 1]
            day = String(calendar.component(.day, from: date))
        }
    }

    typealias Note = GroomerRequestRowContent.Note

    /// Updates use the margin dot. An actionable invitation is explained by the decision footer.
    static func workspaceMatch(_ match: GroomerMatchedRequest, photo: Data?, now: Date,
                               location: GroomerGroomingWorkspace.MatchLocation) -> Self {
        let row = GroomerRequestRowContent.match(match, photo: photo, now: now)
        let place: String? = switch location {
        case .all: visitLabel(match.request.locationMode)
        case .studio: nil
        case .home: row.place
        }
        return .init(row: .init(species: row.species, photo: row.photo, name: row.name, when: row.when, breed: row.breed, weight: row.weight,
            service: row.service, place: place, price: row.price, marks: [], note: row.note))
    }

    static func workspaceOffer(_ entry: GroomerOfferGroups.Entry, photo: Data?, note: Note?, now: Date) -> Self {
        let item = entry.item
        let offer = item.offer
        let agreement = offer.agreementSnapshot
        return pricedVisit(pet: item.groomerVisitPet, service: agreement?.serviceType ?? item.request?.serviceType,
            location: agreement?.locationMode ?? item.request?.locationMode, start: offer.proposedStart, end: offer.proposedEnd,
            zone: agreement?.serviceTimeZoneIdentifier ?? offer.serviceTimeZoneIdentifier ?? item.request?.preferenceTimeZoneIdentifier,
            archived: entry.stage.kind == .closed, now: now,
            price: offer.priceSummary, photo: photo, note: note)
    }

    static func workspaceBooking(_ booking: Booking, closed: Bool = false, fallback: GroomerOfferListItem? = nil,
                                 photo: Data?, note: Note?, now: Date) -> Self {
        let agreement = booking.agreementSnapshot
        let quoted = fallback?.offer.agreementSnapshot
        let stage = GroomerBookingStage(booking, now: now)
        let zone = agreement?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier ?? quoted?.serviceTimeZoneIdentifier
            ?? fallback?.offer.serviceTimeZoneIdentifier ?? fallback?.request?.preferenceTimeZoneIdentifier
        return pricedVisit(pet: agreement?.petSnapshot ?? booking.requestPetSnapshot ?? fallback?.groomerVisitPet,
            service: agreement?.serviceType ?? booking.serviceType ?? quoted?.serviceType ?? fallback?.request?.serviceType,
            location: agreement?.locationMode ?? booking.locationMode ?? quoted?.locationMode ?? fallback?.request?.locationMode,
            start: closed ? GroomerGroomingWorkspace.closedAt(booking) : booking.scheduledStart, end: closed ? nil : booking.scheduledEnd,
            zone: zone, archived: stage.isClosed || stage.isFinished, now: now, price: booking.priceSummary, photo: photo, note: note)
    }

    private static func pricedVisit(pet: GroomingRequestPetSnapshot?, service: GroomingServiceType?, location: GroomingLocationMode?,
                                   start: String, end: String?, zone: String?, archived: Bool, now: Date,
                                   price: String, photo: Data?, note: Note?) -> Self {
        let archiveDay = archived ? ArchiveDay(start: start, zoneIdentifier: zone, now: now) : nil
        let when = archiveDay == nil ? BeckonWhen(start: start, end: end, zoneIdentifier: zone, now: now) : nil
        let name = pet?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let row = GroomerRequestRowContent(species: pet?.species ?? "", photo: photo, name: name.isEmpty ? "Grooming appointment" : name, when: when,
            breed: pet?.breed ?? pet?.species ?? "", weight: pet?.weightLbs.map { "\(Int($0.rounded())) lb" },
            service: service?.title ?? "", place: location.map(visitLabel), price: price, marks: [], note: note)
        return .init(row: row, archiveDay: archiveDay)
    }

    private static func visitLabel(_ location: GroomingLocationMode) -> String {
        location == .customerComesToGroomer ? "Studio" : "Home visit"
    }
}

extension GroomerOfferListItem {
    var groomerVisitPet: GroomingRequestPetSnapshot? {
        offer.agreementSnapshot?.petSnapshot ?? request?.petSnapshot ?? booking?.requestPetSnapshot
    }

}
