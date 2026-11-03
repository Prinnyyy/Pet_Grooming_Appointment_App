import Foundation
import Supabase

@MainActor
final class SupabaseParticipantAvatarLoader {
    private let privateImageLoader: any PrivateImageLoading
    private let cache: ParticipantAvatarCache
    private let accountID: () -> UUID?
    private let profiles: ([UUID], UserRole) async throws -> [ParticipantAvatarProfileRow]

    convenience init(client: SupabaseClient, privateImageLoader: (any PrivateImageLoading)? = nil) {
        self.init(privateImageLoader: privateImageLoader ?? PrivateImageLoader(
            dataSource: SupabasePrivateImageDataSource(client: client)), cache: .shared,
            accountID: { client.auth.currentUser?.id }, profiles: { ids, role in
                try await client.from("profiles").select("id,avatar_path")
                    .in("id", values: ids.map { $0.uuidString.lowercased() })
                    .eq("role", value: role.rawValue).execute().value
            })
    }

    init(privateImageLoader: any PrivateImageLoading, cache: ParticipantAvatarCache,
         accountID: @escaping () -> UUID?,
         profiles: @escaping ([UUID], UserRole) async throws -> [ParticipantAvatarProfileRow]) {
        self.privateImageLoader = privateImageLoader
        self.cache = cache
        self.accountID = accountID
        self.profiles = profiles
    }

    func groomerAvatars(for groomerIDs: [UUID]) async -> [UUID: Data] {
        await avatars(for: groomerIDs, role: .groomer)
    }

    func avatars(for participantIDs: [UUID], role: UserRole) async -> [UUID: Data] {
        let owner = accountID()
        cache.activate(owner)
        guard let owner else { return [:] }
        let cached = Dictionary(uniqueKeysWithValues: Set(participantIDs).compactMap { id in
            cache.data(for: id, role: role).map { (id, $0) }
        })
        let pending = cache.beginRefresh(participantIDs, role: role)
        if !pending.isEmpty {
            let token = cache.generation
            Task { await refresh(pending, role: role, owner: owner, token: token) }
        }
        return cached
    }

    private func refresh(_ ids: [UUID], role: UserRole, owner: UUID, token: UUID) async {
        defer { cache.finish(ids, role: role, generation: token) }
        do {
            let rows = try await profiles(ids, role)
            guard accountID() == owner, cache.generation == token, !Task.isCancelled else { return }
            let byID = Dictionary(rows.filter { ids.contains($0.id) }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            // Missing rows from a successful scoped read revoke the old display too.
            for start in stride(from: 0, to: ids.count, by: 4) {
                let batch = Array(ids[start..<min(start + 4, ids.count)])
                await withTaskGroup(of: Void.self) { group in
                    for id in batch {
                        let path = byID[id]?.avatarPath?.trimmingCharacters(in: .whitespacesAndNewlines)
                        group.addTask {
                            await self.refreshAvatar(id: id, role: role, path: path, owner: owner, token: token)
                        }
                    }
                }
            }
        } catch {
            // Keep the last display on a transient read failure; never empty an avatar while refreshing.
        }
    }
    private func refreshAvatar(id: UUID, role: UserRole, path: String?, owner: UUID, token: UUID) async {
        guard accountID() == owner, cache.generation == token else { return }
        if let path, !path.isEmpty {
            guard (try? await privateImageLoader.loadData(bucketID: cache.bucket(role), storagePath: path)) != nil,
                  accountID() == owner, cache.generation == token else { return }
            cache.commit(id: id, role: role, path: path, generation: token)
        } else {
            cache.commit(id: id, role: role, path: nil, generation: token)
        }
    }

}

nonisolated struct ParticipantAvatarProfileRow: Decodable, Sendable {
    let id: UUID
    let avatarPath: String?
    private enum CodingKeys: String, CodingKey {
        case id
        case avatarPath = "avatar_path"
    }
}
