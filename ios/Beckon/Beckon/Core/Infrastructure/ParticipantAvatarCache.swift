import Foundation
import Observation

/// Display-only account-scoped paths. Image bytes remain in the existing private image cache.
@MainActor @Observable
final class ParticipantAvatarCache {
    static let shared = ParticipantAvatarCache()
    private(set) var accountID: UUID?
    private(set) var generation = UUID()
    private var entries: [String: Entry] = [:]
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private let images: any PrivateImageCaching
    @ObservationIgnored private let directory: URL

    private struct Entry: Codable {
        let path: String?
        let verifiedAt: Date
    }
    private struct Snapshot: Codable {
        let accountID: UUID
        let entries: [String: Entry]
    }

    init(images: any PrivateImageCaching = FilePrivateImageCache.shared, directory: URL? = nil) {
        self.images = images
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory,
            in: .userDomainMask)[0].appendingPathComponent("BeckonParticipantAvatarIndex", isDirectory: true)
    }

    func activate(_ account: UUID?) {
        guard accountID != account else { return }
        accountID = account
        generation = UUID()
        inFlight = []
        entries = [:]
        guard let account, let data = try? Data(contentsOf: url(account)),
              data.count <= 512 * 1024,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.accountID == account else { return }
        entries = snapshot.entries.filter { Date().timeIntervalSince($0.value.verifiedAt) < 30 * 86400 }
    }

    func data(for id: UUID, role: UserRole, fallback: Data? = nil) -> Data? {
        guard accountID != nil, let entry = entries[key(id, role)] else { return fallback }
        guard let path = entry.path else { return nil } // Confirmed removal overrides old model data.
        guard let cacheKey = PrivateImageCacheKey(bucketID: bucket(role), storagePath: path) else { return nil }
        return images.data(for: cacheKey) ?? fallback
    }

    func beginRefresh(_ ids: [UUID], role: UserRole, now: Date = Date()) -> [UUID] {
        guard accountID != nil else { return [] }
        return Array(Set(ids)).filter { id in
            let key = key(id, role)
            guard !inFlight.contains(key) else { return false }
            if let entry = entries[key], now.timeIntervalSince(entry.verifiedAt) < 60,
               entry.path == nil || data(for: id, role: role) != nil { return false }
            inFlight.insert(key)
            return true
        }
    }

    func commit(id: UUID, role: UserRole, path: String?, generation token: UUID, now: Date = Date()) {
        guard generation == token, accountID != nil else { return }
        if path == nil, let old = entries[key(id, role)]?.path,
           let cacheKey = PrivateImageCacheKey(bucketID: bucket(role), storagePath: old) {
            images.removeData(for: cacheKey)
        }
        entries[key(id, role)] = Entry(path: path, verifiedAt: now)
    }

    func finish(_ ids: [UUID], role: UserRole, generation token: UUID) {
        guard generation == token, let accountID else { return }
        for id in ids { inFlight.remove(key(id, role)) }
        if entries.count > 256 {
            entries = Dictionary(uniqueKeysWithValues: entries.sorted { $0.value.verifiedAt > $1.value.verifiedAt }.prefix(256).map { ($0.key, $0.value) })
        }
        guard let data = try? JSONEncoder().encode(Snapshot(accountID: accountID, entries: entries)) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url(accountID), options: .atomic)
    }

    func remove(accountID: UUID) {
        if self.accountID == accountID { activate(nil) }
        try? FileManager.default.removeItem(at: url(accountID))
    }

    private func key(_ id: UUID, _ role: UserRole) -> String { "\(role.rawValue)/\(id.uuidString.lowercased())" }
    private func url(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString.lowercased()).appendingPathExtension("json") }
    func bucket(_ role: UserRole) -> String {
        role == .customer ? PhotoStorageBucketID.customerAvatar.rawValue : PhotoStorageBucketID.groomerAvatar.rawValue
    }
}
