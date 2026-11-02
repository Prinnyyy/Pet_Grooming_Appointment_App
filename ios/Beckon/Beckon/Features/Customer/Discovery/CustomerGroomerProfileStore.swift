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
        guard sessionIsCurrent(), !Task.isCancelled else { return }
        let read = UUID(); operation = read
        error = nil
        do {
            var result = try await repository.publicProfile(groomerID: groomerID)
            guard isCurrent(read) else { return }
            guard result.profile.id == groomerID else { throw RequestDiscoveryError.notAllowed }
            // Only retain bytes for the same returned asset, never for an omitted or replaced photo.
            for index in result.content.works.indices {
                let work = result.content.works[index]
                result.content.works[index].image = work.image ?? profile?.content.works.first {
                    $0.id == work.id && $0.photo.storageBucket == work.photo.storageBucket
                        && $0.photo.storagePath == work.photo.storagePath
                }?.image
            }
            profile = result
            unavailablePhotoIDs.formIntersection(Set(result.content.works.map(\.id)))
            for work in result.content.works { await loadPhoto(work, read: read) }
        } catch {
            guard isCurrent(read) else { return }
            let failure = (error as? RequestDiscoveryError) ?? .unavailable
            if failure == .notAllowed || failure == .groomerUnavailable {
                profile = nil; unavailablePhotoIDs = []
            }
            self.error = failure
        }
    }

    func retryUnavailablePhotos() async {
        guard sessionIsCurrent(), let profile else { return }
        let read = operation
        for work in profile.content.works where unavailablePhotoIDs.contains(work.id) {
            await loadPhoto(work, read: read, refreshing: true)
        }
    }

    func invalidate() {
        operation = UUID()
        profile = nil; error = nil; unavailablePhotoIDs = []
    }

    private func isCurrent(_ read: UUID) -> Bool {
        operation == read && sessionIsCurrent() && !Task.isCancelled
    }

    private func loadPhoto(_ work: GroomerWork, read: UUID, refreshing: Bool = false) async {
        guard isCurrent(read) else { return }
        do {
            let data: Data
            if refreshing {
                data = try await images.refreshData(bucketID: work.photo.storageBucket, storagePath: work.photo.storagePath)
            } else {
                data = try await images.loadData(bucketID: work.photo.storageBucket, storagePath: work.photo.storagePath)
            }
            guard isCurrent(read), let index = profile?.content.works.firstIndex(where: { $0.id == work.id }) else { return }
            profile?.content.works[index].image = data
            unavailablePhotoIDs.remove(work.id)
        } catch {
            guard isCurrent(read) else { return }
            unavailablePhotoIDs.insert(work.id)
        }
    }
}
