import Foundation

enum StorageImageURLError: Error, Equatable, Sendable {
    case unavailable
}

@MainActor
protocol StorageImageURLProvider: AnyObject {
    func signedURL(
        bucket: String,
        path: String,
        expiresIn seconds: Int
    ) async throws -> URL
}
