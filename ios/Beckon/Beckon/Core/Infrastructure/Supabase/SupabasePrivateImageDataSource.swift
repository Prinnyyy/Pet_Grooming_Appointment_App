import Foundation
import Supabase

@MainActor
final class SupabasePrivateImageDataSource: PrivateImageDataFetching {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func imageData(
        bucketID: String,
        storagePath: String
    ) async throws -> Data {
        try await client.storage
            .from(bucketID)
            .download(path: storagePath)
    }
}
