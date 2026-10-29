#if DEBUG
import Foundation

@MainActor
final class CustomerSandboxMarketplace: CustomerRequestRepository, CustomerGroomerDiscoveryRepository,
    RequestDistributionRepository, GroomerFavoritesRepository, PrivateImageLoading {
    let boundary: CustomerSandboxBoundary
    let fixtureState: CustomerSandboxState
    var items: [CustomerGroomingRequest]
    var offerItems: [CustomerOfferReview]
    var candidates: [DiscoveredGroomer]
    var savedIDs: Set<UUID> = [CustomerSandboxFixtures.id(70)]
    var pets: () -> [CustomerPet] = { [CustomerSandboxFixtures.pet(), CustomerSandboxFixtures.pet(1)] }
    private var invitedIDs: [UUID: Set<UUID>] = [:]
    private var poolEnabled: [UUID: Bool] = [:]
    private var preparedDrafts: [UUID: GroomingRequestDraft] = [:]
    private var createdRequestIDs: [UUID: UUID] = [:]
    var photoBytes: [UUID: Data] = [:]
    var photos: [GroomingRequestPhoto] = []
    private var receipts: [UUID: RequestDistributionReceipt] = [:]

    init(state: CustomerSandboxState, boundary: CustomerSandboxBoundary) {
        self.boundary = boundary; fixtureState = state
        let request = CustomerSandboxFixtures.request(state: state)
        items = state == .empty ? [] : [request]
        offerItems = state == .empty || state == .open ? [] : CustomerSandboxFixtures.offers(for: request, photos: state == .photos)
        candidates = state == .empty ? [] : (0..<6).map { CustomerSandboxFixtures.candidate($0, state: state) }
        if state == .empty { savedIDs = [] }
        if state == .photos {
            let photo = GroomingRequestPhoto(id: CustomerSandboxFixtures.id(90), requestID: request.id,
                customerID: request.customerID, storageBucket: "sandbox", storagePath: "fixture.png",
                caption: "Current coat", sortOrder: 0, createdAt: request.createdAt)
            photos = [photo]; photoBytes[photo.id] = CustomerSandboxFixtures.imageData
        }
    }

    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        try await boundary.check(); return items.filter { $0.customerID == customerID }
    }
    func request(customerID: UUID, requestID: UUID) async throws -> CustomerGroomingRequest {
        try await boundary.check()
        guard let value = items.first(where: { $0.id == requestID && $0.customerID == customerID }) else {
            throw CustomerRequestRepositoryError.requestNotFound
        }
        return value
    }
    func offers(customerID: UUID, requestID: UUID) async throws -> [CustomerOfferReview] {
        try await boundary.check(); return offerItems.filter { $0.offer.requestID == requestID }
    }
    func offer(customerID: UUID, requestID: UUID, offerID: UUID) async throws -> CustomerOfferReview {
        guard let offer = try await offers(customerID: customerID, requestID: requestID).first(where: { $0.id == offerID }) else {
            throw CustomerRequestRepositoryError.unavailable
        }
        return offer
    }
    func rankedOffers(customerID: UUID, requestID: UUID, page: RankedPageRequest<CustomerOfferSort>) async throws -> RankedPage<CustomerOfferReview> {
        var values = try await offers(customerID: customerID, requestID: requestID)
        if page.mode.rawValue.contains("price") { values.sort { $0.offer.priceEstimate < $1.offer.priceEstimate } }
        return ranked(values, mode: page.mode.rawValue)
    }
    func quoteEvaluations(offerIDs: [UUID]) async throws -> [UUID: QuoteEvaluation] {
        try await boundary.check()
        return Dictionary(uniqueKeysWithValues: offerIDs.map { ($0, .init(termsValid: true, selectable: true, reason: "available")) })
    }
    func requestPhotos(customerID: UUID, requestIDs: [UUID]) async throws -> [GroomingRequestPhoto] {
        try await boundary.check(); return photos.filter { requestIDs.contains($0.requestID) }
    }
    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data {
        try await boundary.check(); return photoBytes[photo.id] ?? CustomerSandboxFixtures.imageData
    }
    func createRequest(customerID: UUID, draft: GroomingRequestDraft) async throws -> GroomingRequestPublishResult {
        try await boundary.check()
        if let existing = createdRequestIDs[draft.publishOperationID] {
            return .init(requestID: existing, matchCount: candidates.count)
        }
        guard let pet = pets().first(where: { $0.id == draft.petID }) else {
            throw CustomerRequestRepositoryError.requestNotFound
        }
        let id = UUID(), now = Date().ISO8601Format()
        let snapshot = GroomingRequestPetSnapshot(id: pet.id, name: pet.name, species: pet.species,
            breed: pet.breed, coatType: pet.coatType, size: pet.size, weightLbs: pet.weightLbs,
            birthday: pet.birthday, temperament: pet.temperament, medicalNotes: pet.medicalNotes,
            groomingNotes: pet.groomingNotes, snapshotAt: now)
        items.insert(CustomerGroomingRequest(id: id, customerID: customerID, petID: pet.id,
            petSnapshot: snapshot, photoSnapshot: [], serviceType: draft.serviceType, serviceNotes: draft.serviceNotes,
            preferredStart: draft.preferredStart.ISO8601Format(), preferredEnd: draft.preferredEnd.ISO8601Format(),
            locationMode: draft.locationMode, streetAddress: draft.streetAddress, addressLine2: draft.addressLine2,
            city: draft.city, state: draft.stateCode.rawValue, zipCode: draft.zipCode, travelRadiusMiles: draft.travelRadiusMiles,
            status: .open, expiresAt: Date().addingTimeInterval(86400).ISO8601Format(), createdAt: now, updatedAt: now,
            preferenceTimeZoneIdentifier: CustomerSandboxFixtures.zone, termsRevision: UUID()), at: 0)
        createdRequestIDs[draft.publishOperationID] = id
        return .init(requestID: id, matchCount: candidates.count)
    }
    func uploadRequestPhoto(customerID: UUID, requestID: UUID, data: Data,
        contentType: GroomingRequestPhotoContentType, caption: String?) async throws -> GroomingRequestPhoto {
        try await boundary.check()
        let photo = GroomingRequestPhoto(id: UUID(), requestID: requestID, customerID: customerID,
            storageBucket: "sandbox", storagePath: "memory", caption: caption, sortOrder: photos.count, createdAt: Date().ISO8601Format())
        photos.append(photo); photoBytes[photo.id] = data; return photo
    }
    func cancelRequest(requestID: UUID) async throws -> CancelGroomingRequestResult {
        try await boundary.check()
        items = items.map { $0.id == requestID ? $0.replacing(status: .cancelled) : $0 }
        return .init(requestID: requestID, requestStatus: .cancelled, cancelledTimestamp: Date().ISO8601Format())
    }
    func prepare(draftID: UUID, draft: GroomingRequestDraft) async throws -> DiscoverySession {
        try await boundary.check()
        return prepareLocal(draft: draft)
    }
    func prepareLocal(draft: GroomingRequestDraft, id: UUID = UUID()) -> DiscoverySession {
        preparedDrafts[id] = draft
        return .init(id: id, inputDigest: "sandbox", expiresAt: .now.addingTimeInterval(3600))
    }
    func candidates(scope: GroomerDiscoveryScope, page: RankedPageRequest<GroomerDiscoverySort>) async throws -> RankedPage<DiscoveredGroomer> {
        try await boundary.check(); return ranked(candidates, mode: page.mode.rawValue)
    }
    func publicProfile(groomerID: UUID) async throws -> CustomerGroomerProfile {
        try await boundary.check()
        guard let candidate = candidates.first(where: { $0.id == groomerID }) else { throw RequestDiscoveryError.groomerUnavailable }
        let service = GroomerService(id: CustomerSandboxFixtures.id(140), groomerID: groomerID,
            serviceType: .fullGroom, title: "Full groom", description: "Bath, brush and a comfortable trim.",
            basePrice: 85, durationMinutes: 90, acceptedPetSizes: GroomerServicePetSize.allCases,
            isActive: true, acceptedSpecies: [.dog])
        let windows = GroomerAvailabilityWeekday.allCases.filter { $0.rawValue >= 1 && $0.rawValue <= 5 }.map {
            GroomerAvailabilityWindow(id: CustomerSandboxFixtures.id(150 + $0.rawValue), groomerID: groomerID,
                weekday: $0, startMinutes: 540, endMinutes: 1020, isEnabled: true, timezone: "America/Los_Angeles")
        }
        let works = (0..<2).map { index in
            GroomerWork(photo: GroomerPortfolioPhoto(id: CustomerSandboxFixtures.id(160 + index),
                groomerID: groomerID, storageBucket: "sandbox", storagePath: "memory/portfolio-\(index)",
                caption: "Local portfolio fixture \(index + 1)", sortOrder: index),
                tags: [], symbol: "pawprint.fill", look: index, image: CustomerSandboxFixtures.imageData)
        }
        return CustomerGroomerProfile(profile: candidate.profile, content: .init(services: [service], works: works,
            specialties: [], modes: [.groomerComesToCustomer], radiusMiles: 20, windows: windows, noticeDays: 1, timeOff: nil))
    }
    func profile(scope: GroomerDiscoveryScope, groomerID: UUID) async throws -> DiscoveredGroomer {
        try await boundary.check()
        guard let value = candidates.first(where: { $0.id == groomerID }) else { throw RequestDiscoveryError.groomerUnavailable }
        return value
    }
    func publish(operationID: UUID, session: DiscoverySession, poolEnabled: Bool, groomerIDs: [UUID]) async throws -> RequestDistributionReceipt {
        try await boundary.check()
        if let receipt = receipts[operationID] { return receipt }
        guard let draft = preparedDrafts[session.id] else { throw RequestDiscoveryError.listChanged }
        let created = try await createRequest(customerID: CustomerSandboxFixtures.customerID, draft: draft)
        self.poolEnabled[created.requestID] = poolEnabled
        invitedIDs[created.requestID, default: []].formUnion(groomerIDs)
        let receipt = receipt(requestID: created.requestID); receipts[operationID] = receipt; return receipt
    }
    func invite(operationID: UUID, requestID: UUID, expectedTermsRevision: UUID, groomerIDs: [UUID]) async throws -> RequestDistributionReceipt {
        try await boundary.check(); invitedIDs[requestID, default: []].formUnion(groomerIDs); return receipt(requestID: requestID)
    }
    func setPool(operationID: UUID, requestID: UUID, expectedRevision: UUID, enabled: Bool) async throws -> RequestDistributionReceipt {
        try await boundary.check(); poolEnabled[requestID] = enabled; return receipt(requestID: requestID)
    }
    func withdrawInvitation(operationID: UUID, requestID: UUID, groomerID: UUID) async throws -> RequestDistributionReceipt {
        try await boundary.check(); invitedIDs[requestID, default: []].remove(groomerID); return receipt(requestID: requestID)
    }
    func progress(requestIDs: [UUID]) async throws -> [CustomerRequestProgress] {
        try await boundary.check()
        return items.filter { requestIDs.contains($0.id) }.map { request in
            CustomerRequestProgress(requestID: request.id, termsRevision: request.termsRevision!,
                distributionRevision: CustomerSandboxFixtures.id(220), poolEnabled: poolEnabled[request.id] ?? true, status: request.status,
                expiresAt: GroomingRequestDateFormatting.parsedDate(from: request.expiresAt)!, checkedAt: .now,
                evaluationPending: false, validOfferCount: offerItems.filter { $0.offer.requestID == request.id }.count,
                invitations: (invitedIDs[request.id] ?? []).sorted { $0.uuidString < $1.uuidString }.map { id in
                    .init(groomerID: id, profile: candidates.first { $0.id == id }?.profile,
                        sentAt: .now, replyBy: .now.addingTimeInterval(3600), state: .awaitingResponse)
                }, poolCandidateCount: candidates.count)
        }
    }
    func receipt(requestID: UUID = CustomerSandboxFixtures.requestID) -> RequestDistributionReceipt {
        .init(requestID: requestID, termsRevision: items.first { $0.id == requestID }?.termsRevision ?? CustomerSandboxFixtures.id(120),
            distributionRevision: CustomerSandboxFixtures.id(220), poolEnabled: poolEnabled[requestID] ?? true,
            invitedGroomerIDs: (invitedIDs[requestID] ?? []).sorted { $0.uuidString < $1.uuidString })
    }
    func setFavorite(groomerID: UUID, isFavorite: Bool, expectedRevision: UUID?) async throws -> GroomerFavoriteState {
        try await boundary.check()
        if isFavorite { savedIDs.insert(groomerID) } else { savedIDs.remove(groomerID) }
        return .init(isFavorite: isFavorite, revision: UUID())
    }
    func favorites(scope: GroomerDiscoveryScope?, limit: Int, cursor: String?) async throws -> GroomerFavoritesPage {
        try await boundary.check()
        let invited: Set<UUID>
        if case let .request(id, _) = scope { invited = invitedIDs[id] ?? [] } else { invited = [] }
        return .init(items: candidates.filter { savedIDs.contains($0.id) }.map {
            .init(groomerID: $0.id, favoritedAt: .now, profile: $0.profile, availability: .available,
                eligibility: $0.eligibility, favoriteState: .init(isFavorite: true, revision: $0.favoriteState.revision),
                invitationState: invited.contains($0.id) ? .awaitingResponse : .notSent)
        }, nextCursor: nil, revision: "sandbox", asOf: .now)
    }
    func loadData(bucketID: String, storagePath: String) async throws -> Data {
        try await boundary.check(); return CustomerSandboxFixtures.imageData
    }
    func refreshData(bucketID: String, storagePath: String) async throws -> Data {
        try await loadData(bucketID: bucketID, storagePath: storagePath)
    }
    func saveData(_ data: Data, bucketID: String, storagePath: String) {}
    func removeData(bucketID: String, storagePath: String) {}
    private func ranked<T>(_ values: [T], mode: String) -> RankedPage<T> {
        .init(items: values, rankingRevision: "sandbox", scoreAsOf: .now,
            validUntil: .now.addingTimeInterval(3600), algorithmVersion: "sandbox-fixture",
            requestedMode: mode, effectiveMode: mode, pendingCount: 0, assessmentCount: values.count, nextCursor: nil)
    }
}
#endif
