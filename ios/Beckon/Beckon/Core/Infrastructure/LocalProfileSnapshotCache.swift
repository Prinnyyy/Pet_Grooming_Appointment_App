import Foundation

/// Display-only Account facts. These never hydrate editable models or establish current permissions.
struct GroomerAccountSummarySnapshot: Codable, Equatable, Sendable {
    var city: String? = nil
    var state: String? = nil
    var hasProfile: Bool? = nil
    var isProfileActive: Bool? = nil
    var serviceCount: Int? = nil
    var activeServiceCount: Int? = nil
    var portfolioPhotoCount: Int? = nil
    var enabledAvailabilityDayCount: Int? = nil
    var selectedFitSignalCount: Int? = nil
    var evidenceSignalCount: Int? = nil
}

struct ProfileSnapshot: Codable, Equatable, Sendable {
    let userID: UUID
    let displayName: String
    let detailText: String?
    let avatarData: Data?
    var groomerAccountSummary: GroomerAccountSummarySnapshot? = nil
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
            .appendingPathComponent("BeckonProfileSnapshots", isDirectory: true)
    }

    func snapshot(userID: UUID) -> ProfileSnapshot? {
        let url = snapshotURL(userID: userID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let snapshot = try? decoder.decode(ProfileSnapshot.self, from: data), snapshot.userID == userID else { return nil }
        return snapshot
    }

    func save(_ snapshot: ProfileSnapshot) {
        var merged = snapshot
        // Home and avatar refreshes write identity only; they must not erase Account's last known summaries.
        if merged.groomerAccountSummary == nil {
            merged.groomerAccountSummary = self.snapshot(userID: snapshot.userID)?.groomerAccountSummary
        }
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(merged)
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
