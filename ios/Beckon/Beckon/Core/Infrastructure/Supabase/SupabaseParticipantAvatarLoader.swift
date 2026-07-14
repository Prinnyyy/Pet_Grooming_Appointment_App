import Foundation
import Supabase

@MainActor
final class SupabaseParticipantAvatarLoader {
    private static let profileColumns = "id,avatar_path"

    private let client: SupabaseClient
    private let privateImageLoader: any PrivateImageLoading

    init(
        client: SupabaseClient,
        privateImageLoader: (any PrivateImageLoading)? = nil
    ) {
        self.client = client
        self.privateImageLoader = privateImageLoader ?? PrivateImageLoader(
            dataSource: SupabasePrivateImageDataSource(client: client)
        )
    }

    func groomerAvatars(for groomerIDs: [UUID]) async -> [UUID: Data] {
        await avatars(for: groomerIDs, role: .groomer)
    }

    func avatars(
        for participantIDs: [UUID],
        role: UserRole
    ) async -> [UUID: Data] {
        let ids = Array(Set(participantIDs)).map { $0.uuidString.lowercased() }
        guard !ids.isEmpty else { return [:] }

        do {
            let rows: [ParticipantAvatarProfileRow] = try await client
                .from("profiles")
                .select(Self.profileColumns)
                .in("id", values: ids)
                .eq("role", value: role.rawValue)
                .execute()
                .value

            var avatars: [UUID: Data] = [:]
            for row in rows {
                guard let avatarPath = normalized(row.avatarPath) else { continue }
                if let data = try? await privateImageLoader.loadData(
                    bucketID: avatarBucketID(for: role),
                    storagePath: avatarPath
                ) {
                    avatars[row.id] = data
                }
            }
            return avatars
        } catch {
            return [:]
        }
    }

    private func avatarBucketID(for role: UserRole) -> String {
        switch role {
        case .customer:
            PhotoStorageBucketID.customerAvatar.rawValue
        case .groomer:
            PhotoStorageBucketID.groomerAvatar.rawValue
        }
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ParticipantAvatarProfileRow: Decodable {
    let id: UUID
    let avatarPath: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case avatarPath = "avatar_path"
    }
}
