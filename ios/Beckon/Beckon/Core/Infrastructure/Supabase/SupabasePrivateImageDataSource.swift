import Foundation
import Supabase

@MainActor
final class SupabasePrivateImageDataSource: PrivateImageDataFetching {
    private let client: SupabaseClient
    private let requiresFreshAuthorization: Bool

    init(client: SupabaseClient, requiresFreshAuthorization: Bool = false) {
        self.client = client
        self.requiresFreshAuthorization = requiresFreshAuthorization
    }

    func imageData(
        bucketID: String,
        storagePath: String
    ) async throws -> Data {
        try await client.storage
            .from(bucketID)
            .download(path: storagePath, cacheNonce: requiresFreshAuthorization ? UUID().uuidString : nil)
    }
}
