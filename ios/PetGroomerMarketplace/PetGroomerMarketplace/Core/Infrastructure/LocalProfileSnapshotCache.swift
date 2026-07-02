import Foundation

struct ProfileSnapshot: Codable, Equatable, Sendable {
    let userID: UUID
    let displayName: String
    let detailText: String?
    let avatarData: Data?
}

@MainActor
protocol ProfileSnapshotCaching: AnyObject {
    func snapshot(userID: UUID) -> ProfileSnapshot?
    func save(_ snapshot: ProfileSnapshot)
    func remove(userID: UUID)
}

@MainActor
final class FileProfileSnapshotCache: ProfileSnapshotCaching {
    static let shared = FileProfileSnapshotCache()

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
            .appendingPathComponent("GroomlyProfileSnapshots", isDirectory: true)
    }

    func snapshot(userID: UUID) -> ProfileSnapshot? {
        let url = snapshotURL(userID: userID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ProfileSnapshot.self, from: data)
    }

    func save(_ snapshot: ProfileSnapshot) {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL(userID: snapshot.userID), options: .atomic)
        } catch {
            return
        }
    }

    func remove(userID: UUID) {
        try? fileManager.removeItem(at: snapshotURL(userID: userID))
    }

    private func snapshotURL(userID: UUID) -> URL {
        directoryURL
            .appendingPathComponent(userID.uuidString.lowercased(), isDirectory: false)
            .appendingPathExtension("json")
    }
}
