import Foundation

struct CustomerPetPhotoSnapshot: Codable, Equatable, Sendable {
    let customerID: UUID
    let petID: UUID
    let photoID: UUID
    let storagePath: String
    let data: Data
}

@MainActor
protocol CustomerPetPhotoCaching: AnyObject {
    func snapshot(
        customerID: UUID,
        petID: UUID
    ) -> CustomerPetPhotoSnapshot?
    func snapshot(photo: CustomerPetPhoto) -> CustomerPetPhotoSnapshot?
    func save(_ snapshot: CustomerPetPhotoSnapshot)
    func remove(photoID: UUID)
    func removeAll(customerID: UUID)
}

@MainActor
final class FileCustomerPetPhotoCache: CustomerPetPhotoCaching {
    static let shared = FileCustomerPetPhotoCache()

    private let directoryURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(
                "BeckonCustomerPetPhotoSnapshots",
                isDirectory: true
        )
    }

    func snapshot(
        customerID: UUID,
        petID: UUID
    ) -> CustomerPetPhotoSnapshot? {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls
            .compactMap { url -> (Date, CustomerPetPhotoSnapshot)? in
                guard url.pathExtension == "json",
                      let data = try? Data(contentsOf: url),
                      let snapshot = try? decoder.decode(
                        CustomerPetPhotoSnapshot.self,
                        from: data
                      ),
                      snapshot.customerID == customerID,
                      snapshot.petID == petID else {
                    return nil
                }

                let values = try? url.resourceValues(
                    forKeys: [.contentModificationDateKey]
                )
                return (
                    values?.contentModificationDate ?? .distantPast,
                    snapshot
                )
            }
            .max { lhs, rhs in
                lhs.0 < rhs.0
            }?
            .1
    }

    func snapshot(photo: CustomerPetPhoto) -> CustomerPetPhotoSnapshot? {
        let url = snapshotURL(photoID: photo.id)
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? decoder.decode(
                CustomerPetPhotoSnapshot.self,
                from: data
              ),
              snapshot.customerID == photo.customerID,
              snapshot.petID == photo.petID,
              snapshot.photoID == photo.id,
              snapshot.storagePath == photo.storagePath else {
            return nil
        }

        return snapshot
    }

    func save(_ snapshot: CustomerPetPhotoSnapshot) {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(snapshot)
            try data.write(
                to: snapshotURL(photoID: snapshot.photoID),
                options: .atomic
            )
        } catch {
            return
        }
    }

    func remove(photoID: UUID) {
        try? fileManager.removeItem(at: snapshotURL(photoID: photoID))
    }

    func removeAll(customerID: UUID) {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let snapshot = try? decoder.decode(
                    CustomerPetPhotoSnapshot.self,
                    from: data
                  ),
                  snapshot.customerID == customerID else {
                continue
            }

            try? fileManager.removeItem(at: url)
        }
    }

    private func snapshotURL(photoID: UUID) -> URL {
        directoryURL
            .appendingPathComponent(
                photoID.uuidString.lowercased(),
                isDirectory: false
            )
            .appendingPathExtension("json")
    }
}
