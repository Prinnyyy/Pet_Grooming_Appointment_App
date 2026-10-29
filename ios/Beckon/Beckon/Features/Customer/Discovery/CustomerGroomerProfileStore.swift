import Foundation
import Observation

@MainActor @Observable
final class CustomerGroomerProfileStore {
    private(set) var profile: CustomerGroomerProfile?
    private(set) var error: RequestDiscoveryError?
    private(set) var unavailablePhotoIDs: Set<UUID> = []
    private let groomerID: UUID
    private let repository: any CustomerGroomerDiscoveryRepository
    private let images: any PrivateImageLoading
    private let sessionIsCurrent: () -> Bool
    private var operation = UUID()

    init(groomerID: UUID, repository: any CustomerGroomerDiscoveryRepository, images: any PrivateImageLoading,
         sessionIsCurrent: @escaping () -> Bool) {
        self.groomerID = groomerID; self.repository = repository; self.images = images
        self.sessionIsCurrent = sessionIsCurrent
    }

    func load() async {
        let read = UUID(); operation = read
        profile = nil; error = nil; unavailablePhotoIDs = []
        guard sessionIsCurrent(), !Task.isCancelled else { return }
        do {
            let result = try await repository.publicProfile(groomerID: groomerID)
            guard operation == read, sessionIsCurrent(), !Task.isCancelled else { return }
            guard result.profile.id == groomerID else { throw RequestDiscoveryError.notAllowed }
            profile = result
            for work in result.content.works {
                let data: Data?
                do { data = try await images.loadData(bucketID: work.photo.storageBucket, storagePath: work.photo.storagePath) }
                catch { data = nil }
                guard operation == read, sessionIsCurrent(), !Task.isCancelled else { return }
                if let index = profile?.content.works.firstIndex(where: { $0.id == work.id }) {
                    profile?.content.works[index].image = data
                    if data == nil { unavailablePhotoIDs.insert(work.id) }
                }
            }
        } catch {
            guard operation == read, sessionIsCurrent(), !Task.isCancelled else { return }
            self.error = (error as? RequestDiscoveryError) ?? .unavailable
        }
    }
}
