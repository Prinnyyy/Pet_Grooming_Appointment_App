#if DEBUG
// The groomer prototype's own local data (design). The customer prototype borrows the host's fixtures (`CustomerSandbox*`, Codex's);
// the groomer side has none, so this file holds a groomer, a few matched requests, a few offers and a profile, all built from the
// real model types and answered by in-memory repositories. The real stores (`GroomerRequestsStore`, `GroomerOffersStore`) run on
// them unchanged. Nothing here reaches a network or the keychain. Dates are relative to now, so the data is never in the past.
import SwiftUI


/// What a groomer screen starts from: data, nothing, or a wait that ends when the session is released (the loading replay).
enum GroomerSandboxState: String, CaseIterable, Identifiable {
    /// `busyDay` is `loaded` plus a service under way now and one later today; `slotsFull` is `loaded` with all eight core skill
    /// slots of the fit signals used.
    case loaded, empty, loading, busyDay, slotsFull
    var id: Self { self }
}


/// Holds every answer back while the state is `.loading`, until `release()`: the placeholders can be watched going to content.
@MainActor
final class GroomerSandboxBoundary {
    private(set) var isHeld: Bool

    init(isHeld: Bool) { self.isHeld = isHeld }

    func release() { isHeld = false }

    func check() async throws {
        while isHeld {
            try await Task.sleep(for: .milliseconds(80))
        }
    }
}


enum GroomerSandboxFixtures {
    static let groomerID = id(1)
    static let customerIDs = (2...9).map { id($0) }
    static let timeZone = "America/Los_Angeles"

    static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "%08d-0000-4000-8000-%012d", number, number)) ?? UUID()
    }

    /// An ISO timestamp `hours` from now (negative: ago).
    static func iso(hours: Double) -> String {
        GroomingRequestDateFormatting.serverString(from: Date().addingTimeInterval(hours * 3600))
    }

    static func pet(_ number: Int, name: String, species: String = "Dog", breed: String, size: String, weight: Double,
                            temperament: String?, notes: String? = nil, medical: String? = nil, coat: String? = nil,
                            birthday: String? = nil) -> GroomingRequestPetSnapshot {
        GroomingRequestPetSnapshot(id: id(100 + number), name: name, species: species, breed: breed, coatType: coat, size: size,
            weightLbs: weight, birthday: birthday, temperament: temperament, medicalNotes: medical, groomingNotes: notes,
            snapshotAt: iso(hours: -30))
    }

    private static func request(_ number: Int, pet: GroomingRequestPetSnapshot, service: GroomingServiceType, notes: String?,
                                startHours: Double, lengthHours: Double = 2, street: String, city: String, zip: String,
                                status: GroomingRequestStatus = .open, source: (pool: Bool, invitation: RequestInvitationState)? = nil)
        -> GroomerMatchedGroomingRequest {
        GroomerMatchedGroomingRequest(id: id(200 + number), customerID: customerIDs[number % customerIDs.count],
            petID: pet.id, petSnapshot: pet, photoSnapshot: [], serviceType: service, serviceNotes: notes,
            preferredStart: iso(hours: startHours), preferredEnd: iso(hours: startHours + lengthHours),
            locationMode: .groomerComesToCustomer, streetAddress: street, city: city, state: "WA", zipCode: zip,
            travelRadiusMiles: nil, status: status, expiresAt: iso(hours: startHours - 2), createdAt: iso(hours: -20 + Double(number)),
            updatedAt: iso(hours: -2), preferenceTimeZoneIdentifier: timeZone, termsRevision: id(300 + number),
            poolEnabled: source?.pool, invitationState: source?.invitation)
    }

    private static func match(_ number: Int, for request: GroomerMatchedGroomingRequest, status: RequestMatchStatus = .visible,
                              reason: String, score: Double, state: String = "estimated_fit",
                              confirmations: [String]? = nil) -> GroomerRequestMatch {
        GroomerRequestMatch(id: id(400 + number), requestID: request.id, groomerID: groomerID, customerID: request.customerID,
            matchScore: score, matchReason: reason, dismissReason: nil, status: status, viewedAt: nil, dismissedAt: nil,
            createdAt: iso(hours: -19), updatedAt: iso(hours: -3),
            eligibilityEvaluation: MatchEligibilityEvaluation(state: state, reason: nil, serviceStart: request.preferredStart,
                serviceEnd: request.preferredEnd, requiredConfirmations: confirmations))
    }

    static func offer(_ number: Int, for request: GroomerMatchedGroomingRequest, matchID: UUID, price: Double,
                      status: GroomerOfferStatus, startHours: Double, message: String?) -> GroomerOffer {
        GroomerOffer(id: id(500 + number), requestID: request.id, matchID: matchID, customerID: request.customerID,
            groomerID: groomerID, proposedStart: iso(hours: startHours), proposedEnd: iso(hours: startHours + 2),
            priceEstimate: price, message: message, status: status, expiresAt: iso(hours: startHours - 3), withdrawnAt: nil,
            createdAt: iso(hours: -6), updatedAt: iso(hours: -5), serviceTimeZoneIdentifier: timeZone)
    }

    private static func evidence(reviews: Int, customers: Int, completed: Int,
                                 coverage: [(dimension: String, value: String, completed: Int, positive: Int, negative: Int, unknown: Int)])
        -> MatchingEvidence {
        MatchingEvidence(state: "available", algorithmVersion: "matching-v1", scoreAsOf: iso(hours: -3), relatedReviewCount: reviews,
            independentCustomers: customers, completedCount: completed, latestServiceAt: iso(hours: -120),
            coverage: coverage.map {
                MatchingEvidenceCoverage(dimension: $0.dimension, value: $0.value, completedCount: $0.completed,
                    positiveCount: $0.positive, negativeCount: $0.negative, unknownCount: $0.unknown)
            })
    }

    /// Matches the groomer can answer, a pending offer among them.
    static func matches() -> [GroomerMatchedRequest] {
        let mochi = request(1, pet: pet(1, name: "Mochi", breed: "Corgi", size: "M", weight: 22, temperament: "Gentle",
            notes: "Sensitive paws."), service: .fullGroom, notes: "Please go slowly around the feet.",
            startHours: 9, street: "123 Pine Street", city: "Seattle", zip: "98101", source: (true, .awaitingResponse))
        let biscuit = request(2, pet: pet(2, name: "Biscuit", breed: "Pomeranian", size: "XS", weight: 6, temperament: "Nervous"),
            service: .bathAndBrush, notes: nil, startHours: 74, lengthHours: 1.5, street: "840 Bellevue Way", city: "Bellevue",
            zip: "98004", source: (true, .notSent))
        let luna = request(3, pet: pet(3, name: "Luna", breed: "Miniature Poodle", size: "S", weight: 12, temperament: "Playful",
            notes: "Teddy-bear cut."), service: .haircutOnly, notes: "About 2 cm all over, please.", startHours: 52,
            street: "55 Alder Ave", city: "Seattle", zip: "98103")
        let rocky = request(4, pet: pet(4, name: "Rocky", breed: "Labrador Retriever", size: "L", weight: 70, temperament: "Energetic",
            medical: "Hip dysplasia."), service: .fullGroom, notes: "Heavy shedding.", startHours: 98, lengthHours: 3,
            street: "9 Harbor Road", city: "Tacoma", zip: "98402")
        let pepper = request(5, pet: pet(5, name: "Pepper", breed: "Dachshund", size: "S", weight: 14, temperament: "Gentle"),
            service: .nailTrim, notes: nil, startHours: 30, lengthHours: 0.5, street: "210 Maple Court", city: "Seattle",
            zip: "98109", status: .hasOffers)
        let pepperMatch = match(5, for: pepper, status: .offered, reason: "Same city. Short appointment that fits your Tuesday.", score: 82)
        return [
            GroomerMatchedRequest(match: match(1, for: mochi, reason: "Same city and service location. Pet-fit evidence: corgi coats with positive reviews.",
                score: 96), request: mochi, offer: nil,
                matchingEvidence: evidence(reviews: 3, customers: 3, completed: 4, coverage: [
                    (dimension: "service", value: "full_groom", completed: 4, positive: 3, negative: 0, unknown: 1),
                    (dimension: "care", value: "anxious", completed: 2, positive: 2, negative: 0, unknown: 0),
                ])),
            GroomerMatchedRequest(match: match(2, for: biscuit, reason: "Inside your service radius. Small dogs are your most booked group.", score: 90),
                request: biscuit, offer: nil,
                matchingEvidence: evidence(reviews: 2, customers: 2, completed: 3, coverage: [
                    (dimension: "service", value: "bath_and_brush", completed: 3, positive: 2, negative: 0, unknown: 1),
                ])),
            GroomerMatchedRequest(match: match(3, for: luna, status: .viewed, reason: "Same city. You have a free morning that day.", score: 84),
                request: luna, offer: nil),
            GroomerMatchedRequest(match: match(4, for: rocky, reason: "Inside your radius. Large breeds need a size confirmation.", score: 70,
                state: "assessment_required", confirmations: ["pet_size"]), request: rocky, offer: nil),
            GroomerMatchedRequest(match: pepperMatch, request: pepper,
                offer: offer(1, for: pepper, matchID: pepperMatch.id, price: 25, status: .pending, startHours: 30,
                    message: "Quick and calm nail trim, treats included.")),
        ]
    }

    /// Matches that put the Requests list to the test (design): a name, a breed and a city too long for a line, several marks at once, and
    /// the notes (still being checked, closing soon, none).
    static func stressMatches() -> [GroomerMatchedRequest] {
        let princess = request(11, pet: pet(11, name: "Princess Buttercup the Third", breed: "Labrador Retriever mix", size: "L", weight: 70,
            temperament: "Energetic"), service: .fullGroom, notes: nil, startHours: 80, lengthHours: 3, street: "1 Embarcadero Center",
            city: "San Francisco Bay Area", zip: "94111", source: (true, .awaitingResponse))
        let reginald = request(12, pet: pet(12, name: "Sir Reginald von Fluffington", breed: "Miniature Schnauzer", size: "S", weight: 16,
            temperament: "Gentle"), service: .bathAndBrush, notes: nil, startHours: 7, street: "400 Lake Washington Blvd", city: "Bellevue",
            zip: "98004", source: (true, .notSent))
        let mo = request(13, pet: pet(13, name: "Mo", breed: "Pug", size: "S", weight: 18, temperament: "Playful"), service: .nailTrim,
            notes: nil, startHours: 55, lengthHours: 0.5, street: "12 Market St", city: "Kirkland", zip: "98033")
        let daisy = request(14, pet: pet(14, name: "Daisy", breed: "Cavalier King Charles Spaniel", size: "S", weight: 15, temperament: "Gentle"),
            service: .haircutOnly, notes: nil, startHours: 30, street: "9 Pine Ave", city: "Seattle", zip: "98122", source: (false, .awaitingResponse))
        return [
            GroomerMatchedRequest(match: match(11, for: princess, reason: "Inside your radius.", score: 88, state: "pending"), request: princess, offer: nil),
            GroomerMatchedRequest(match: match(12, for: reginald, status: .viewed, reason: "Same city.", score: 80), request: reginald, offer: nil),
            GroomerMatchedRequest(match: match(13, for: mo, reason: "Small dogs are your most booked group.", score: 76), request: mo, offer: nil),
            GroomerMatchedRequest(match: match(14, for: daisy, reason: "Invited by the customer.", score: 92), request: daisy, offer: nil),
        ]
    }

    /// The offers the groomer has made, in every state.
    static func offers() -> [GroomerOfferListItem] {
        let all = matches()
        let pepper = all[4]
        let bella = bookings().first { $0.requestPetSnapshot?.name == "Bella" }
        let bellaStart = bella.flatMap { GroomingRequestDateFormatting.parsedDate(from: $0.scheduledStart) } ?? Date().addingTimeInterval(48 * 3600)
        let bellaHours = bellaStart.timeIntervalSinceNow / 3600
        let accepted = request(6, pet: pet(6, name: "Bella", breed: "Golden Retriever", size: "L", weight: 62, temperament: "Friendly"),
            service: .fullGroom, notes: nil, startHours: bellaHours, lengthHours: 2, street: "77 Lakeview Drive", city: "Seattle",
            zip: "98115", status: .booked)
        let declined = request(7, pet: pet(7, name: "Milo", breed: "Shih Tzu", size: "S", weight: 11, temperament: "Gentle"),
            service: .bathAndBrush, notes: nil, startHours: -20, street: "3 Cedar Lane", city: "Seattle", zip: "98107", status: .booked)
        let expired = request(8, pet: pet(8, name: "Coco", breed: "Cavapoo", size: "S", weight: 15, temperament: "Playful"),
            service: .haircutOnly, notes: nil, startHours: -50, street: "18 Orchard Way", city: "Seattle", zip: "98105", status: .expired)
        return [
            GroomerOfferListItem(offer: pepper.offer!, request: pepper.request, booking: nil),
            GroomerOfferListItem(offer: offer(2, for: accepted, matchID: id(406), price: 110, status: .acceptedByCustomer,
                startHours: bellaHours, message: "I will bring the quiet dryer for Bella."), request: accepted, booking: bella),
            GroomerOfferListItem(offer: offer(3, for: declined, matchID: id(407), price: 55, status: .declinedByCustomer, startHours: -20,
                message: nil), request: declined, booking: nil),
            GroomerOfferListItem(offer: offer(4, for: expired, matchID: id(408), price: 70, status: .expired, startHours: -50,
                message: nil), request: expired, booking: nil),
        ]
    }
}


/// Answers the groomer's requests screens from memory.
@MainActor
final class GroomerSandboxRequestRepository: GroomerRequestRepository {
    private var matches: [GroomerMatchedRequest]
    private var offerItems: [GroomerOfferListItem]
    private let boundary: GroomerSandboxBoundary

    init(state: GroomerSandboxState, boundary: GroomerSandboxBoundary, matches matchOverride: [GroomerMatchedRequest]? = nil,
         offerItems itemOverride: [GroomerOfferListItem]? = nil) {
        self.boundary = boundary
        matches = matchOverride ?? (state == .empty ? [] : GroomerSandboxFixtures.matches())
        offerItems = itemOverride ?? (state == .empty ? [] : GroomerSandboxFixtures.offers())
    }

    func rankedMatches(groomerID: UUID, page: RankedPageRequest<GroomerMatchSort>) async throws -> RankedPage<GroomerMatchedRequest> {
        try await boundary.check()
        let now = Date()
        return RankedPage(items: sorted(by: page.mode), rankingRevision: "prototype", scoreAsOf: now,
            validUntil: now.addingTimeInterval(600), algorithmVersion: "matching-v1", requestedMode: page.mode.rawValue,
            effectiveMode: page.mode.rawValue, pendingCount: 0, assessmentCount: matches.filter {
                $0.match.eligibilityEvaluation?.state == "assessment_required" }.count, nextCursor: nil)
    }

    private func sorted(by mode: GroomerMatchSort) -> [GroomerMatchedRequest] {
        switch mode {
        case .fit: matches.sorted { ($0.match.matchScore ?? 0) > ($1.match.matchScore ?? 0) }
        case .distance: matches
        case .newest: matches.sorted { $0.request.createdAt > $1.request.createdAt }
        }
    }

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        try await boundary.check()
        return matches
    }

    func matchedRequest(groomerID: UUID, requestID: UUID) async throws -> GroomerMatchedRequest {
        try await boundary.check()
        guard let found = matches.first(where: { $0.request.id == requestID }) else { throw GroomerRequestRepositoryError.matchNotFound }
        return found
    }

    func offer(groomerID: UUID, offerID: UUID) async throws -> GroomerOffer? {
        try await boundary.check()
        return offerItems.first { $0.offer.id == offerID }?.offer ?? matches.first { $0.offer?.id == offerID }?.offer
    }

    func offers(groomerID: UUID) async throws -> [GroomerOfferListItem] {
        try await boundary.check()
        return offerItems
    }

    func dismiss(matchID: UUID, reason: String?) async throws -> DismissRequestMatchResult {
        try await boundary.check()
        matches.removeAll { $0.match.id == matchID }
        return DismissRequestMatchResult(matchID: matchID, status: .dismissed, dismissedAt: GroomerSandboxFixtures.iso(hours: 0))
    }

    func createOffer(draft: GroomerOfferDraft) async throws -> CreateGroomerOfferResult {
        try await boundary.check()
        guard let index = matches.firstIndex(where: { $0.request.id == draft.requestID }), matches[index].canCreateOffer else {
            throw GroomerRequestRepositoryError.matchNotFound
        }
        try await Task.sleep(for: .milliseconds(600))
        let matched = matches[index]
        let now = GroomingRequestDateFormatting.serverString(from: Date())
        let start = GroomingRequestDateFormatting.serverString(from: draft.proposedStart)
        let end = GroomingRequestDateFormatting.serverString(from: draft.proposedEnd)
        let offer = GroomerOffer(id: UUID(), requestID: draft.requestID, matchID: matched.match.id,
            customerID: matched.request.customerID, groomerID: matched.match.groomerID,
            proposedStart: start, proposedEnd: end, priceEstimate: draft.priceEstimate, message: draft.message,
            status: .pending, expiresAt: matched.request.expiresAt, withdrawnAt: nil, createdAt: now, updatedAt: now,
            appliedTimingBuffers: try GroomingTimingBuffers(preparation: 0, cleanup: 0,
                inboundTravel: 0, outboundTravel: 0),
            serviceTimeZoneIdentifier: matched.request.preferenceTimeZoneIdentifier ?? GroomerSandboxFixtures.timeZone,
            scheduleTimeZoneIdentifier: GroomerSandboxFixtures.timeZone, occupiedStart: start, occupiedEnd: end,
            timingSnapshotLoaded: true)
        matches[index] = matched.replacing(matchStatus: .offered, requestStatus: .hasOffers, offer: offer)
        offerItems.insert(GroomerOfferListItem(offer: offer, request: matches[index].request, booking: nil), at: 0)
        return CreateGroomerOfferResult(offerID: offer.id, offerStatus: .pending, requestStatus: .hasOffers)
    }

    func withdrawOffer(offerID: UUID) async throws -> WithdrawGroomerOfferResult {
        try await boundary.check()
        guard let offer = offerItems.first(where: { $0.id == offerID })?.offer
            ?? matches.first(where: { $0.offer?.id == offerID })?.offer, offer.status == .pending else {
            throw GroomerRequestRepositoryError.matchNotFound
        }
        let stamp = GroomingRequestDateFormatting.serverString(from: Date())
        let withdrawn = offer.replacing(status: .withdrawnByGroomer, withdrawnAt: stamp)
        matches = matches.map { matched in
            matched.offer?.id == offerID ? matched.replacing(matchStatus: .viewed, requestStatus: .open, offer: withdrawn) : matched
        }
        offerItems = offerItems.map { item in
            item.id == offerID ? GroomerOfferListItem(offer: withdrawn, request: item.request, booking: item.booking) : item
        }
        return WithdrawGroomerOfferResult(offerID: offerID, offerStatus: .withdrawnByGroomer,
            withdrawnTimestamp: stamp, requestStatus: .open)
    }

}


/// The groomer's profile, services and schedule, from memory (lifted from the real preview repository, with a fuller profile). In the
/// `empty` state the groomer is new: a profile and a week of hours, and nothing else.
@MainActor
final class GroomerSandboxProfileRepository: GroomerProfileRepository {
    private let groomerID = GroomerSandboxFixtures.groomerID
    private let boundary: GroomerSandboxBoundary
    private var storedProfile: GroomerProfile
    private var storedServices: [GroomerService]
    private var storedPhotos: [GroomerPortfolioPhoto] = []
    private var storedPortfolioFitTags: [GroomerPortfolioFitTag] = []
    private var storedAvailability: [GroomerAvailabilityWindow] = []
    private var storedBookingPreferences: GroomerBookingPreferences
    private var storedTimeOff: [GroomerTimeOffWindow] = []
    private var storedFitClaims: [GroomerFitClaim] = []
    private var storedPetFitEvidenceSummary: [GroomerPetFitEvidenceSummary] = []

    init(boundary: GroomerSandboxBoundary, state: GroomerSandboxState = .loaded) {
        self.boundary = boundary
        let isNew = state == .empty
        storedProfile = GroomerProfile(userID: GroomerSandboxFixtures.groomerID, businessName: "Fresh Coat Grooming",
            bio: "Calm, one-on-one grooming for small and medium dogs.", yearsExperience: 5, baseStreetAddress: "123 Pine Street",
            baseCity: "Seattle", baseState: "WA", baseZipCode: "98101", serviceRadiusMiles: 12,
            serviceLocationMode: .groomerComesToCustomer, serviceLocationModes: [.groomerComesToCustomer, .customerComesToGroomer],
            ratingAverage: isNew ? 0 : 4.9, ratingCount: isNew ? 0 : 38, isActive: !isNew, isVerified: !isNew, ratingSum: isNew ? 0 : 186)
        storedProfile.avatarPath = isNew ? nil : "sandbox/avatar"
        func service(_ type: GroomingServiceType, _ title: String, _ text: String, _ price: Double, _ minutes: Int,
                     sizes: [GroomerServicePetSize] = [.xs, .s, .m], isActive: Bool = true) -> GroomerService {
            var service = GroomerService(id: UUID(), groomerID: GroomerSandboxFixtures.groomerID, serviceType: type, title: title,
                description: text, basePrice: price, durationMinutes: minutes, acceptedPetSizes: sizes, isActive: isActive)
            service.acceptedSpecies = [.dog]
            return service
        }
        storedServices = isNew ? [] : [
            service(.fullGroom, "Full groom", "Bath, haircut, nails, and ear cleaning.", 95, 120, sizes: [.xs, .s, .m, .l]),
            service(.bathAndBrush, "Bath and brush", "Bath, blow-dry, brush-out and a tidy.", 55, 60),
            service(.haircutOnly, "Haircut", "Trim or a full cut, no bath.", 70, 90),
            service(.nailTrim, "Nail trim", "Quick nail trim and file.", 25, 30, sizes: []),
            service(.deShedding, "De-shedding", "Undercoat release and a blow-out.", 80, 75, isActive: false),
        ]
        storedBookingPreferences = GroomerBookingPreferences(groomerID: GroomerSandboxFixtures.groomerID, maxAppointmentsPerDay: 4,
            minimumAdvanceNoticeDays: 0, autoAcceptBookings: false, timingBuffers: .serviceOnly)
        storedAvailability = GroomerSandboxFixtures.weekWindows
        guard !isNew else { return }
        storedPhotos = [
            (1, "Corgi, full groom"), (2, "Teddy-bear cut"), (3, "Doodle, bath and brush"), (4, "Show trim"),
        ].enumerated().map { index, entry in
            GroomerPortfolioPhoto(id: GroomerSandboxFixtures.id(850 + entry.0), groomerID: GroomerSandboxFixtures.groomerID,
                storageBucket: "groomer-portfolio", storagePath: "sandbox/portfolio-\(entry.0).jpg", caption: entry.1, sortOrder: index)
        }
        let coat = PetFitSignal.coatTypeSignals
        let care = PetFitSignal.careFlagSignals
        let fit = PetFitSignal.serviceFitSignals.filter {
            $0.traitValue != PetFitTrait.curlyCoat.rawValue && $0.traitValue != PetFitTrait.terrierCoat.rawValue
        }
        let sizes = PetFitSignal.sizeBandSignals
        let isFull = state == .slotsFull
        let claimed = Array(coat.prefix(isFull ? 3 : 2)) + Array(care.prefix(isFull ? 3 : 2)) + Array(fit.prefix(2))
            + Array(sizes.dropFirst().prefix(3))
        storedFitClaims = claimed.map {
            GroomerFitClaim(id: UUID(), groomerID: GroomerSandboxFixtures.groomerID, signal: $0, isActive: true)
        }
        storedPortfolioFitTags = zip(storedPhotos, [Array(coat.prefix(1)), Array(coat.dropFirst().prefix(2)), Array(care.prefix(1))])
            .flatMap { photo, signals in
                signals.map { GroomerPortfolioFitTag(id: UUID(), portfolioPhotoID: photo.id, groomerID: GroomerSandboxFixtures.groomerID,
                    signal: $0) }
            }
        // Evidence is kept for what the bookings were (a service, a care need), not for what the groomer claims.
        // One coat is among them: a coat's name is the longest a row can carry.
        let evidenceRows: [(dimension: String, value: String, tier: GroomerPetFitEvidenceConfidenceTier,
            completed: Int, positive: Int, negative: Int, answered: Int)] = [
            ("service", "full_groom", .high, 12, 9, 0, 10),
            ("service", "bath_and_brush", .high, 9, 6, 0, 7),
            ("coat", "double_coat", .medium, 7, 4, 0, 5),
            ("care", "anxious", .medium, 6, 3, 0, 4),
            ("service", "nail_trim", .low, 3, 0, 1, 1),
        ]
        storedPetFitEvidenceSummary = evidenceRows.compactMap { row in
            guard let signal = ReviewEvidenceKey(dimension: row.dimension, value: row.value).signal else { return nil }
            return GroomerPetFitEvidenceSummary(groomerID: GroomerSandboxFixtures.groomerID, signal: signal,
                completedBookingCount: row.completed, positiveReviewOutcomeCount: row.positive, negativeReviewOutcomeCount: row.negative,
                structuredReviewOutcomeCount: row.answered, lastCompletedAt: GroomerSandboxFixtures.iso(hours: -120),
                lastReviewOutcomeAt: GroomerSandboxFixtures.iso(hours: -100), evidenceUpdatedAt: GroomerSandboxFixtures.iso(hours: -90),
                confidenceTier: row.tier)
        }
        let calendar = GroomerSandboxFixtures.calendar
        let day = { (offset: Int) -> String in
            let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) ?? Date()
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
        storedTimeOff = [GroomerTimeOffWindow(id: UUID(), groomerID: GroomerSandboxFixtures.groomerID, title: "Long weekend away",
            startDate: day(12), endDate: day(14))]
    }

    func profile(groomerID: UUID) async throws -> GroomerProfile { try await boundary.check(); return storedProfile }
    func services(groomerID: UUID) async throws -> [GroomerService] { try await boundary.check(); return storedServices }
    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto] { try await boundary.check(); return storedPhotos }
    func portfolioFitTags(groomerID: UUID) async throws -> [GroomerPortfolioFitTag] { storedPortfolioFitTags }
    func fitClaims(groomerID: UUID) async throws -> [GroomerFitClaim] { storedFitClaims }
    func petFitEvidenceSummary(groomerID: UUID) async throws -> [GroomerPetFitEvidenceSummary] { storedPetFitEvidenceSummary }
    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow] { storedAvailability }
    func bookingPreferences(groomerID: UUID) async throws -> GroomerBookingPreferences { storedBookingPreferences }
    func timeOffWindows(groomerID: UUID) async throws -> [GroomerTimeOffWindow] { storedTimeOff }

    func updateProfile(groomerID: UUID, draft: GroomerProfileDraft) async throws -> GroomerProfile {
        storedProfile = GroomerProfile(userID: groomerID, businessName: draft.businessName, bio: draft.bio,
            yearsExperience: draft.yearsExperience, baseStreetAddress: draft.baseStreetAddress, baseCity: draft.baseCity,
            baseState: draft.baseStateCode?.rawValue, baseZipCode: draft.baseZipCode, serviceRadiusMiles: draft.serviceRadiusMiles,
            serviceLocationMode: draft.serviceLocationMode, serviceLocationModes: draft.serviceLocationModes,
            ratingAverage: storedProfile.ratingAverage, ratingCount: storedProfile.ratingCount, isActive: draft.isActive,
            isVerified: storedProfile.isVerified, ratingSum: storedProfile.ratingSum)
        return storedProfile
    }

    func createService(groomerID: UUID, draft: GroomerServiceDraft) async throws -> GroomerService {
        var service = GroomerService(id: UUID(), groomerID: groomerID, serviceType: draft.serviceType, title: draft.title,
            description: draft.description, basePrice: draft.basePrice, durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes, isActive: draft.isActive)
        service.acceptedSpecies = draft.acceptedSpecies
        storedServices.insert(service, at: 0)
        return service
    }

    func updateService(service: GroomerService, draft: GroomerServiceDraft) async throws -> GroomerService {
        var updated = GroomerService(id: service.id, groomerID: service.groomerID, serviceType: draft.serviceType, title: draft.title,
            description: draft.description, basePrice: draft.basePrice, durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes, isActive: draft.isActive)
        updated.acceptedSpecies = draft.acceptedSpecies
        if let index = storedServices.firstIndex(where: { $0.id == service.id }) { storedServices[index] = updated }
        return updated
    }

    func deleteService(_ service: GroomerService) async throws { storedServices.removeAll { $0.id == service.id } }

    func uploadPortfolioPhoto(groomerID: UUID, data: Data, contentType: GroomerPortfolioPhotoContentType, caption: String?) async throws
        -> GroomerPortfolioPhoto {
        let photo = GroomerPortfolioPhoto(id: UUID(), groomerID: groomerID, storageBucket: "groomer-portfolio",
            storagePath: GroomerPortfolioPhotoPath.make(groomerID: groomerID, contentType: contentType), caption: caption, sortOrder: 0)
        storedPhotos.append(photo)
        return photo
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws {
        storedPhotos.removeAll { $0.id == photo.id }
        storedPortfolioFitTags.removeAll { $0.portfolioPhotoID == photo.id }
    }

    func replaceFitClaims(groomerID: UUID, drafts: [GroomerFitClaimDraft]) async throws -> [GroomerFitClaim] {
        try await Task.sleep(for: .milliseconds(400))
        storedFitClaims = drafts.map { GroomerFitClaim(id: UUID(), groomerID: groomerID, signal: $0.signal, isActive: $0.isActive) }
        return storedFitClaims
    }

    func replacePortfolioFitTags(groomerID: UUID, photoID: UUID, drafts: [GroomerPortfolioFitTagDraft]) async throws
        -> [GroomerPortfolioFitTag] {
        let tags = drafts.map { GroomerPortfolioFitTag(id: UUID(), portfolioPhotoID: photoID, groomerID: groomerID, signal: $0.signal) }
        storedPortfolioFitTags.removeAll { $0.portfolioPhotoID == photoID }
        storedPortfolioFitTags.append(contentsOf: tags)
        return tags
    }

    func uploadAvatarPhoto(groomerID: UUID, data: Data, contentType: GroomerAvatarPhotoContentType) async throws -> String {
        let path = GroomerAvatarPhotoPath.make(groomerID: groomerID, contentType: contentType)
        storedProfile.avatarPath = path
        return path
    }

    func avatarPhotoData(storagePath: String) async throws -> Data { GroomerSandboxFixtures.imageData(symbol: "scissors") }

    func portfolioPhotoData(_ photo: GroomerPortfolioPhoto) async throws -> Data {
        GroomerSandboxFixtures.portfolioImage(sortOrder: photo.sortOrder)
    }

    func replaceAvailability(groomerID: UUID, drafts: [GroomerAvailabilityDraft]) async throws -> [GroomerAvailabilityWindow] {
        storedAvailability = drafts.map {
            GroomerAvailabilityWindow(id: UUID(), groomerID: groomerID, weekday: $0.weekday, startMinutes: $0.startMinutes,
                endMinutes: $0.endMinutes, isEnabled: $0.isEnabled, timezone: $0.timezone)
        }
        return storedAvailability
    }

    func availabilitySnapshot(groomerID: UUID) async throws -> GroomerAvailabilitySnapshot {
        GroomerAvailabilitySnapshot(revision: "prototype", windows: storedAvailability, preferences: storedBookingPreferences,
            timeOff: storedTimeOff, timingVersion: 1)
    }

    func saveAvailability(groomerID: UUID, expectedRevision: String, windows: [GroomerAvailabilityDraft],
                          preferences: GroomerBookingPreferencesDraft, timeOff: [GroomerTimeOffWindow]) async throws
        -> GroomerAvailabilitySnapshot {
        _ = try await replaceAvailability(groomerID: groomerID, drafts: windows)
        _ = try await updateBookingPreferences(groomerID: groomerID, draft: preferences)
        storedTimeOff = timeOff
        return try await availabilitySnapshot(groomerID: groomerID)
    }

    func updateBookingPreferences(groomerID: UUID, draft: GroomerBookingPreferencesDraft) async throws -> GroomerBookingPreferences {
        storedBookingPreferences = GroomerBookingPreferences(groomerID: groomerID, maxAppointmentsPerDay: draft.maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: draft.minimumAdvanceNoticeDays, autoAcceptBookings: draft.autoAcceptBookings,
            timingBuffers: draft.timingBuffers)
        return storedBookingPreferences
    }

    func createTimeOff(groomerID: UUID, draft: GroomerTimeOffDraft) async throws -> GroomerTimeOffWindow {
        let window = GroomerTimeOffWindow(id: UUID(), groomerID: groomerID, title: draft.title, startDate: draft.startDate,
            endDate: draft.endDate)
        storedTimeOff.append(window)
        return window
    }

    func deleteTimeOff(_ window: GroomerTimeOffWindow) async throws { storedTimeOff.removeAll { $0.id == window.id } }
}


/// One groomer's local session: the repositories and the stores the screens run on.
@MainActor
final class GroomerSandboxSession {
    let state: GroomerSandboxState
    let boundary: GroomerSandboxBoundary
    let groomerID = GroomerSandboxFixtures.groomerID
    let groomerName = "Fresh Coat Grooming"
    let requestRepository: GroomerSandboxRequestRepository
    let profileRepository: GroomerSandboxProfileRepository
    let bookingRepository: GroomerSandboxBookingRepository
    let chatRepository: GroomerSandboxChatRepository
    let notificationRepository: GroomerSandboxNotificationRepository
    let requests: GroomerRequestsStore
    let offers: GroomerOffersStore
    let bookings: BookingsStore
    let chat: ChatStore
    let notifications: GroomerNotificationsStore
    let home: GroomerHomeStore
    let account: GroomerProfileStore

    /// `bookings`, `matches` and `offers` replace the fixtures' lists: a preview that needs a booking or a request in one particular
    /// moment (a service due, a review in, an offer with a problem).
    init(state: GroomerSandboxState, bookings override: [Booking]? = nil, matches: [GroomerMatchedRequest]? = nil,
         offers offerOverride: [GroomerOfferListItem]? = nil) {
        self.state = state
        let boundary = GroomerSandboxBoundary(isHeld: state == .loading)
        self.boundary = boundary
        let groomerID = GroomerSandboxFixtures.groomerID
        let isEmpty = state == .empty
        let bookingItems = override ?? (isEmpty ? [] : GroomerSandboxFixtures.bookings(busyDay: state == .busyDay))
        requestRepository = GroomerSandboxRequestRepository(state: state, boundary: boundary, matches: matches, offerItems: offerOverride)
        profileRepository = GroomerSandboxProfileRepository(boundary: boundary, state: state)
        bookingRepository = GroomerSandboxBookingRepository(bookings: bookingItems, boundary: boundary)
        chatRepository = GroomerSandboxChatRepository(conversations: GroomerSandboxFixtures.conversations(for: bookingItems),
            bookings: bookingItems, boundary: boundary)
        notificationRepository = GroomerSandboxNotificationRepository(
            notifications: isEmpty ? [] : GroomerSandboxFixtures.notifications(for: bookingItems,
                matches: GroomerSandboxFixtures.matches()), boundary: boundary)
        requests = GroomerRequestsStore(groomerID: groomerID, repository: requestRepository, profileRepository: profileRepository)
        offers = GroomerOffersStore(groomerID: groomerID, repository: requestRepository)
        let defaults = HomePreviewMemoryDefaults()
        let snapshotCache = GroomerSnapshotCache()
        bookings = BookingsStore(participantID: groomerID, role: .groomer, repository: bookingRepository,
            groomerProfileRepository: profileRepository, appointmentReminderScheduler: GroomerReminders(),
            fulfillmentDefaults: defaults)
        chat = ChatStore(participantID: groomerID, role: .groomer, repository: chatRepository, bookingRepository: bookingRepository,
            readStateCache: UserDefaultsChatReadStateCache(userDefaults: defaults))
        chat.sandboxBookingStore = bookings
        notifications = GroomerNotificationsStore(groomerID: groomerID, repository: notificationRepository)
        home = GroomerHomeStore(groomerID: groomerID, displayName: "Alex", profileRepository: profileRepository,
            requestRepository: requestRepository, bookingRepository: bookingRepository, profileSnapshotCache: snapshotCache)
        account = GroomerProfileStore(groomerID: groomerID, repository: profileRepository, profileSnapshotCache: snapshotCache,
            addressProvider: HomePreviewAddressProvider())
    }
}
#endif
