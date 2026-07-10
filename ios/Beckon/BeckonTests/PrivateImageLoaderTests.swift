import Foundation
import Testing
@testable import Beckon

struct PrivateImageCacheKeyTests {
    @Test
    func normalizesBucketAndPathAndHashesPathForFileStorage() throws {
        let key = try #require(
            PrivateImageCacheKey(
                bucketID: " request-photos ",
                storagePath: " customer-id/request-id/photo.jpg "
            )
        )

        #expect(key.bucketID == "request-photos")
        #expect(key.storagePath == "customer-id/request-id/photo.jpg")
        #expect(!key.cacheFileName.contains("customer-id"))
        #expect(!key.cacheFileName.contains("request-id"))
        #expect(!key.cacheFileName.contains("photo.jpg"))
    }

    @Test
    func rejectsEmptyValuesAndUrlLikeStoragePaths() {
        #expect(PrivateImageCacheKey(bucketID: "", storagePath: "a/b.jpg") == nil)
        #expect(PrivateImageCacheKey(bucketID: "request-photos", storagePath: "") == nil)
        #expect(
            PrivateImageCacheKey(
                bucketID: "request-photos",
                storagePath: "https://example.supabase.co/storage/v1/object/sign/request-photos/a.jpg"
            ) == nil
        )
    }
}

@MainActor
struct PrivateImageLoaderTests {
    @Test
    func loadDataReturnsCachedDataWithoutDownloading() async throws {
        let key = Self.key()
        let cachedData = Data([0x01, 0x02])
        let cache = PrivateImageCacheFake(dataByKey: [key: cachedData])
        let dataSource = PrivateImageDataSourceFake()
        let loader = PrivateImageLoader(dataSource: dataSource, cache: cache)

        let data = try await loader.loadData(
            bucketID: key.bucketID,
            storagePath: key.storagePath
        )

        #expect(data == cachedData)
        #expect(dataSource.requests.isEmpty)
    }

    @Test
    func loadDataDownloadsAndCachesWhenMissingLocally() async throws {
        let key = Self.key()
        let remoteData = Data([0x03, 0x04])
        let cache = PrivateImageCacheFake()
        let dataSource = PrivateImageDataSourceFake(result: .success(remoteData))
        let loader = PrivateImageLoader(dataSource: dataSource, cache: cache)

        let data = try await loader.loadData(
            bucketID: key.bucketID,
            storagePath: key.storagePath
        )

        #expect(data == remoteData)
        #expect(dataSource.requests == [key])
        #expect(cache.data(for: key) == remoteData)
    }

    @Test
    func loadDataRetriesTransientNetworkFailureBeforeFailingOpen() async throws {
        let key = Self.key()
        let remoteData = Data([0x09, 0x0A])
        let cache = PrivateImageCacheFake()
        let dataSource = PrivateImageDataSourceFake(
            results: [
                .failure(URLError(.networkConnectionLost)),
                .success(remoteData),
            ]
        )
        let loader = PrivateImageLoader(dataSource: dataSource, cache: cache)

        let data = try await loader.loadData(
            bucketID: key.bucketID,
            storagePath: key.storagePath
        )

        #expect(data == remoteData)
        #expect(dataSource.requests == [key, key])
        #expect(cache.data(for: key) == remoteData)
    }

    @Test
    func refreshDataFallsBackToCachedDataWhenDownloadFails() async throws {
        let key = Self.key()
        let cachedData = Data([0x05, 0x06])
        let cache = PrivateImageCacheFake(dataByKey: [key: cachedData])
        let dataSource = PrivateImageDataSourceFake(result: .failure(PrivateImageDataSourceFakeError.failed))
        let loader = PrivateImageLoader(dataSource: dataSource, cache: cache)

        let data = try await loader.refreshData(
            bucketID: key.bucketID,
            storagePath: key.storagePath
        )

        #expect(data == cachedData)
        #expect(dataSource.requests == [key])
    }

    @Test
    func refreshDataDoesNotUseCachedFallbackWhenDownloadIsCancelled() async throws {
        let key = Self.key()
        let cachedData = Data([0x05, 0x06])
        let cache = PrivateImageCacheFake(dataByKey: [key: cachedData])
        let dataSource = PrivateImageDataSourceFake(result: .failure(URLError(.cancelled)))
        let loader = PrivateImageLoader(dataSource: dataSource, cache: cache)

        do {
            _ = try await loader.refreshData(
                bucketID: key.bucketID,
                storagePath: key.storagePath
            )
            Issue.record("Expected cancellation to be thrown.")
        } catch let error as URLError {
            #expect(error.code == .cancelled)
        }

        #expect(dataSource.requests == [key])
        #expect(cache.data(for: key) == cachedData)
    }

    @Test
    func refreshDataRetriesTransientNetworkFailureBeforeUsingCachedFallback() async throws {
        let key = Self.key()
        let cachedData = Data([0x05, 0x06])
        let remoteData = Data([0x0B, 0x0C])
        let cache = PrivateImageCacheFake(dataByKey: [key: cachedData])
        let dataSource = PrivateImageDataSourceFake(
            results: [
                .failure(URLError(.timedOut)),
                .success(remoteData),
            ]
        )
        let loader = PrivateImageLoader(dataSource: dataSource, cache: cache)

        let data = try await loader.refreshData(
            bucketID: key.bucketID,
            storagePath: key.storagePath
        )

        #expect(data == remoteData)
        #expect(dataSource.requests == [key, key])
        #expect(cache.data(for: key) == remoteData)
    }

    @Test
    func saveAndRemoveDataUseTheSharedCacheKey() throws {
        let key = Self.key()
        let cache = PrivateImageCacheFake()
        let loader = PrivateImageLoader(
            dataSource: PrivateImageDataSourceFake(),
            cache: cache
        )

        loader.saveData(Data([0x07]), bucketID: key.bucketID, storagePath: key.storagePath)
        #expect(cache.data(for: key) == Data([0x07]))

        loader.removeData(bucketID: key.bucketID, storagePath: key.storagePath)
        #expect(cache.data(for: key) == nil)
    }

    @Test
    func fileCacheDoesNotLeakStoragePathInFileNamesAndCanRemoveData() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = FilePrivateImageCache(directoryURL: directoryURL)
        let key = try #require(
            PrivateImageCacheKey(
                bucketID: "request-photos",
                storagePath: "customer-id/request-id/photo.jpg"
            )
        )

        cache.save(Data([0x08]), for: key)

        #expect(cache.data(for: key) == Data([0x08]))
        let cachedPaths = try FileManager.default.subpathsOfDirectory(
            atPath: directoryURL.path
        ).joined(separator: "/")
        #expect(!cachedPaths.contains("customer-id"))
        #expect(!cachedPaths.contains("request-id"))
        #expect(!cachedPaths.contains("photo.jpg"))

        cache.removeData(for: key)
        #expect(cache.data(for: key) == nil)
        try? FileManager.default.removeItem(at: directoryURL)
    }

    private static func key() -> PrivateImageCacheKey {
        PrivateImageCacheKey(
            bucketID: "request-photos",
            storagePath: "customer-id/request-id/photo.jpg"
        )!
    }
}

@MainActor
private final class PrivateImageCacheFake: PrivateImageCaching {
    private var dataByKey: [PrivateImageCacheKey: Data]

    init(dataByKey: [PrivateImageCacheKey: Data] = [:]) {
        self.dataByKey = dataByKey
    }

    func data(for key: PrivateImageCacheKey) -> Data? {
        dataByKey[key]
    }

    func save(_ data: Data, for key: PrivateImageCacheKey) {
        dataByKey[key] = data
    }

    func removeData(for key: PrivateImageCacheKey) {
        dataByKey[key] = nil
    }
}

@MainActor
private final class PrivateImageDataSourceFake: PrivateImageDataFetching {
    private(set) var requests: [PrivateImageCacheKey] = []
    private var results: [Result<Data, Error>]

    init(result: Result<Data, Error> = .failure(PrivateImageDataSourceFakeError.failed)) {
        self.results = [result]
    }

    init(results: [Result<Data, Error>]) {
        self.results = results
    }

    func imageData(
        bucketID: String,
        storagePath: String
    ) async throws -> Data {
        if let key = PrivateImageCacheKey(
            bucketID: bucketID,
            storagePath: storagePath
        ) {
            requests.append(key)
        }

        if results.count > 1 {
            return try results.removeFirst().get()
        }

        guard let result = results.first else {
            throw PrivateImageDataSourceFakeError.failed
        }
        return try result.get()
    }
}

private enum PrivateImageDataSourceFakeError: Error {
    case failed
}
