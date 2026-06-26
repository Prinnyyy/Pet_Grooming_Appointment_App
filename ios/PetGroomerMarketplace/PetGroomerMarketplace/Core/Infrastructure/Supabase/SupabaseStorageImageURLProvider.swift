import Foundation
import Supabase

@MainActor
final class SupabaseStorageImageURLProvider: StorageImageURLProvider {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signedURL(
        bucket: String,
        path: String,
        expiresIn seconds: Int
    ) async throws -> URL {
        do {
            return try await client.storage
                .from(bucket)
                .createSignedURL(path: path, expiresIn: seconds)
        } catch {
            throw StorageImageURLError.unavailable
        }
    }
}
