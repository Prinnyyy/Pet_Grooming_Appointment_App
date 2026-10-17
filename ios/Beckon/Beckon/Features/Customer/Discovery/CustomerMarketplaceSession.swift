import Foundation
import Observation

@MainActor
@Observable
final class CustomerMarketplaceSession {
    let publication: CustomerRequestPublicationCoordinator
    let distribution: CustomerRequestDistributionStore
    let favorites: GroomerFavoritesStore
    let discoveryRepository: any CustomerGroomerDiscoveryRepository
    var createRequest: (() -> Void)?
    var requestOptions: () -> [CustomerGroomingRequest] = { [] }
    var refreshRequestOptions: (() async -> String?)?
    private(set) var avatarData: [UUID: Data] = [:]
    private var avatarPaths: [UUID: String] = [:]
    private var loadingAvatars: [UUID: UUID] = [:]
    private let images: any PrivateImageLoading
    private let sessionIsCurrent: () -> Bool
    private var generation = UUID()

    init(customerID: UUID, requestRepository: any CustomerRequestRepository,
         services: CustomerMarketplaceServices, sessionIsCurrent: @escaping () -> Bool) {
        self.sessionIsCurrent = sessionIsCurrent
        discoveryRepository = services.discovery
        images = services.images
        publication = .init(customerID: customerID, requestRepository: requestRepository,
            distributionRepository: services.distribution, sessionIsCurrent: sessionIsCurrent)
        distribution = .init(repository: services.distribution, publication: publication, sessionIsCurrent: sessionIsCurrent)
        favorites = .init(customerID: customerID, repository: services.favorites, sessionIsCurrent: sessionIsCurrent)
    }

    func loadAvatar(_ profile: MarketplaceGroomerSummary) async {
        guard sessionIsCurrent() else { return }
        guard let path = profile.avatarPath else { revokeAvatar(profile.id); return }
        if avatarPaths[profile.id] != path { revokeAvatar(profile.id); avatarPaths[profile.id] = path }
        guard avatarData[profile.id] == nil, loadingAvatars[profile.id] == nil else { return }
        let current = generation
        let operation = UUID()
        loadingAvatars[profile.id] = operation
        defer { if loadingAvatars[profile.id] == operation { loadingAvatars[profile.id] = nil } }
        do {
            let data = try await images.loadData(bucketID: "groomer-avatars", storagePath: path)
            guard current == generation, sessionIsCurrent(), !Task.isCancelled,
                  loadingAvatars[profile.id] == operation, avatarPaths[profile.id] == path else { return }
            avatarData[profile.id] = data
        } catch {
            guard current == generation, sessionIsCurrent(), loadingAvatars[profile.id] == operation,
                  avatarPaths[profile.id] == path else { return }
            avatarData[profile.id] = nil
        }
    }

    func revokeAvatar(_ id: UUID) {
        avatarData[id] = nil; avatarPaths[id] = nil; loadingAvatars[id] = nil
    }

    func clearSession() {
        generation = UUID()
        favorites.clearSession(); distribution.clearSession()
        avatarData = [:]; avatarPaths = [:]; loadingAvatars = [:]
    }
}

@MainActor
@Observable
final class CustomerRequestDiscoveryFlow: Identifiable {
    let id = UUID()
    let store: CustomerGroomerDiscoveryStore
    let draft: GroomingRequestDraft?
    let session: DiscoverySession?
    let photos: [PendingGroomingRequestPhoto]
    var poolEnabled = false

    init(store: CustomerGroomerDiscoveryStore, draft: GroomingRequestDraft? = nil,
         session: DiscoverySession? = nil, photos: [PendingGroomingRequestPhoto] = []) {
        self.store = store; self.draft = draft; self.session = session; self.photos = photos
    }

    var requestID: UUID? {
        if case let .request(id, _) = store.actionScope { return id }
        return nil
    }

    func publicationConfirmation(names: [String]) -> String? {
        guard requestID == nil else { return nil }
        let targets = names.isEmpty ? "No direct invitations." : "Send to: " + names.joined(separator: ", ") + "."
        return targets + (poolEnabled
            ? " Request pool: on. All eligible groomers can see this request."
            : " Request pool: off. Only invited groomers can respond.")
    }

}
