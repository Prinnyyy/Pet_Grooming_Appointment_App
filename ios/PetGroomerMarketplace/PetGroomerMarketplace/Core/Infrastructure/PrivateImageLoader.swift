import CryptoKit
import Foundation

nonisolated struct PrivateImageCacheKey: Hashable, Sendable {
    let bucketID: String
    let storagePath: String

    init?(bucketID: String, storagePath: String) {
        let normalizedBucketID = bucketID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStoragePath = storagePath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedBucketID.isEmpty,
              Self.isValidStoragePath(normalizedStoragePath) else {
            return nil
        }

        self.bucketID = normalizedBucketID
        self.storagePath = normalizedStoragePath
    }

    var cacheFileName: String {
        "\(Self.hexDigest(for: "\(bucketID)\n\(storagePath)")).img"
    }

    var cacheBucketDirectoryName: String {
        bucketID
            .unicodeScalars
            .map { scalar in
                CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
                    ? String(scalar)
                    : "_"
            }
            .joined()
    }

    private static func isValidStoragePath(_ storagePath: String) -> Bool {
        guard !storagePath.isEmpty,
              !storagePath.hasPrefix("/") else {
            return false
        }

        let lowercasedPath = storagePath.lowercased()
        guard !lowercasedPath.contains("://"),
              !lowercasedPath.contains("/storage/v1/object/") else {
            return false
        }

        return true
    }

    private static func hexDigest(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

nonisolated enum PrivateImageLoadingError: Error, Equatable {
    case invalidStoragePath
}

@MainActor
protocol PrivateImageCaching: AnyObject {
    func data(for key: PrivateImageCacheKey) -> Data?
    func save(_ data: Data, for key: PrivateImageCacheKey)
    func removeData(for key: PrivateImageCacheKey)
}

@MainActor
protocol PrivateImageDataFetching: AnyObject {
    func imageData(bucketID: String, storagePath: String) async throws -> Data
}

@MainActor
protocol PrivateImageLoading: AnyObject {
    func loadData(bucketID: String, storagePath: String) async throws -> Data
    func refreshData(bucketID: String, storagePath: String) async throws -> Data
    func saveData(_ data: Data, bucketID: String, storagePath: String)
    func removeData(bucketID: String, storagePath: String)
}

@MainActor
final class PrivateImageLoader: PrivateImageLoading {
    private let dataSource: any PrivateImageDataFetching
    private let cache: any PrivateImageCaching

    init(
        dataSource: any PrivateImageDataFetching,
        cache: any PrivateImageCaching = FilePrivateImageCache.shared
    ) {
        self.dataSource = dataSource
        self.cache = cache
    }

    func loadData(bucketID: String, storagePath: String) async throws -> Data {
        let key = try cacheKey(bucketID: bucketID, storagePath: storagePath)

        if let cachedData = cache.data(for: key) {
            return cachedData
        }

        let data = try await dataSource.imageData(
            bucketID: key.bucketID,
            storagePath: key.storagePath
        )
        cache.save(data, for: key)
        return data
    }

    func refreshData(bucketID: String, storagePath: String) async throws -> Data {
        let key = try cacheKey(bucketID: bucketID, storagePath: storagePath)

        do {
            let data = try await dataSource.imageData(
                bucketID: key.bucketID,
                storagePath: key.storagePath
            )
            cache.save(data, for: key)
            return data
        } catch {
            if let cachedData = cache.data(for: key) {
                return cachedData
            }

            throw error
        }
    }

    func saveData(_ data: Data, bucketID: String, storagePath: String) {
        guard let key = PrivateImageCacheKey(
            bucketID: bucketID,
            storagePath: storagePath
        ) else {
            return
        }

        cache.save(data, for: key)
    }

    func removeData(bucketID: String, storagePath: String) {
        guard let key = PrivateImageCacheKey(
            bucketID: bucketID,
            storagePath: storagePath
        ) else {
            return
        }

        cache.removeData(for: key)
    }

    private func cacheKey(
        bucketID: String,
        storagePath: String
    ) throws -> PrivateImageCacheKey {
        guard let key = PrivateImageCacheKey(
            bucketID: bucketID,
            storagePath: storagePath
        ) else {
            throw PrivateImageLoadingError.invalidStoragePath
        }

        return key
    }
}

@MainActor
final class FilePrivateImageCache: PrivateImageCaching {
    static let shared = FilePrivateImageCache()

    private static let maximumCachedImageBytes = 10 * 1024 * 1024
    private let directoryURL: URL
    private let fileManager: FileManager

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
    }

    func data(for key: PrivateImageCacheKey) -> Data? {
        let fileURL = cacheFileURL(for: key)
        guard let data = try? Data(contentsOf: fileURL),
              data.count <= Self.maximumCachedImageBytes else {
            return nil
        }

        return data
    }

    func save(_ data: Data, for key: PrivateImageCacheKey) {
        guard !data.isEmpty,
              data.count <= Self.maximumCachedImageBytes else {
            return
        }

        let fileURL = cacheFileURL(for: key)
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            return
        }
    }

    func removeData(for key: PrivateImageCacheKey) {
        try? fileManager.removeItem(at: cacheFileURL(for: key))
    }

    func removeAll() {
        try? fileManager.removeItem(at: directoryURL)
    }

    private func cacheFileURL(for key: PrivateImageCacheKey) -> URL {
        directoryURL
            .appendingPathComponent(key.cacheBucketDirectoryName, isDirectory: true)
            .appendingPathComponent(key.cacheFileName, isDirectory: false)
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory

        return baseURL.appendingPathComponent(
            "GroomlyPrivateImageCache",
            isDirectory: true
        )
    }
}
