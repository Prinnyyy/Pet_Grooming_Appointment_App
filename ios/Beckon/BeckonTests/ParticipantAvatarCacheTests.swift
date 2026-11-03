import Foundation
import Observation
import XCTest
@testable import Beckon

@MainActor final class ParticipantAvatarCacheTests: XCTestCase {
    private let owner = UUID()
    private let peer = UUID()
    private let old = Data([1, 2])
    private let fresh = Data([3, 4])

    func testPersistedAvatarAppearsBeforeBlockedProfileReadAndUpdatesWithoutAnotherPageLoad() async throws {
        let (directory, images, cache) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }
        seed(cache, images: images)
        // Recreate the metadata cache as after an app restart; keep the same image files.
        let restored = ParticipantAvatarCache(images: FilePrivateImageCache(directoryURL: directory.appendingPathComponent("images")),
            directory: directory.appendingPathComponent("paths"))
        var release: CheckedContinuation<[ParticipantAvatarProfileRow], any Error>?
        var reads = 0
        let source = AvatarDataSource(data: fresh)
        let loader = SupabaseParticipantAvatarLoader(privateImageLoader: PrivateImageLoader(dataSource: source, cache: images),
            cache: restored, accountID: { self.owner }, profiles: { _, _ in
                reads += 1
                return try await withCheckedThrowingContinuation { release = $0 }
            })
        let result = await loader.avatars(for: [peer], role: .groomer)
        XCTAssertEqual(result[peer], old)
        await until { release != nil }
        _ = await loader.avatars(for: [peer, peer], role: .groomer)
        XCTAssertEqual(reads, 1, "Overlapping refreshes must coalesce")
        XCTAssertEqual(source.requests, 0, "No image download before metadata returns")
        let observed = expectation(description: "Visible avatar observes the background change")
        withObservationTracking {
            _ = restored.data(for: peer, role: .groomer)
        } onChange: { observed.fulfill() }
        release?.resume(returning: [.init(id: peer, avatarPath: "new/avatar.jpg")])
        await until { restored.data(for: self.peer, role: .groomer) == self.fresh }
        XCTAssertEqual(restored.data(for: peer, role: .groomer), fresh)
        await fulfillment(of: [observed], timeout: 2)
        _ = await loader.avatars(for: [peer], role: .groomer)
        XCTAssertEqual(reads, 1, "A recent verified avatar is reused")
    }

    func testColdAvatarDoesNotBlockThePage() async {
        let (directory, images, cache) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = AvatarDataSource(data: fresh)
        let loader = SupabaseParticipantAvatarLoader(privateImageLoader: PrivateImageLoader(dataSource: source, cache: images),
            cache: cache, accountID: { self.owner }, profiles: { _, _ in [.init(id: self.peer, avatarPath: "new/avatar.jpg")] })
        let initial = await loader.avatars(for: [peer], role: .groomer)
        XCTAssertTrue(initial.isEmpty)
        await until { cache.data(for: self.peer, role: .groomer) == self.fresh }
    }

    func testSuccessfulProfileRemovalOverridesOldModelFallback() async {
        let (directory, images, cache) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }
        seed(cache, images: images)
        let loader = SupabaseParticipantAvatarLoader(privateImageLoader: PrivateImageLoader(dataSource: AvatarDataSource(data: fresh), cache: images),
            cache: cache, accountID: { self.owner }, profiles: { _, _ in [] })
        _ = await loader.avatars(for: [peer], role: .groomer)
        await until { cache.data(for: self.peer, role: .groomer, fallback: self.old) == nil }
    }

    func testFailedRefreshKeepsLastImageAndAccountAndRoleNeverSharePaths() async {
        let (directory, images, cache) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }
        seed(cache, images: images)
        var attempted = false
        let loader = SupabaseParticipantAvatarLoader(privateImageLoader: PrivateImageLoader(dataSource: AvatarDataSource(data: fresh), cache: images),
            cache: cache, accountID: { self.owner }, profiles: { _, _ in
                attempted = true
                throw URLError(.notConnectedToInternet)
            })
        let result = await loader.avatars(for: [peer], role: .groomer)
        XCTAssertEqual(result[peer], old)
        await until { attempted }
        XCTAssertEqual(cache.data(for: peer, role: .groomer), old)
        XCTAssertNil(cache.data(for: peer, role: .customer))
        cache.activate(UUID())
        XCTAssertNil(cache.data(for: peer, role: .groomer))
        cache.remove(accountID: owner)
        cache.activate(owner)
        XCTAssertNil(cache.data(for: peer, role: .groomer))
    }

    func testLateProfileReplyCannotRepopulateAfterAccountCleanup() async {
        let (directory, images, cache) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }
        var release: CheckedContinuation<[ParticipantAvatarProfileRow], any Error>?
        let source = AvatarDataSource(data: fresh)
        let loader = SupabaseParticipantAvatarLoader(privateImageLoader: PrivateImageLoader(dataSource: source, cache: images),
            cache: cache, accountID: { self.owner }, profiles: { _, _ in
                try await withCheckedThrowingContinuation { release = $0 }
            })
        _ = await loader.avatars(for: [peer], role: .groomer)
        await until { release != nil }
        cache.remove(accountID: owner)
        release?.resume(returning: [.init(id: peer, avatarPath: "old/avatar.jpg")])
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(source.requests, 0)
        XCTAssertNil(cache.accountID)
        cache.activate(owner)
        XCTAssertNil(cache.data(for: peer, role: .groomer))
    }

    func testImageFinishingAfterCleanupDoesNotRecreateMemoryOrDiskCache() async throws {
        let (directory, images, _) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = AvatarDataSource(data: fresh)
        source.blocks = true
        let loader = PrivateImageLoader(dataSource: source, cache: images)
        let task = Task { try await loader.loadData(bucketID: "groomer-avatars", storagePath: "old/avatar.jpg") }
        await until { source.release != nil }
        images.removeAll()
        source.release?.resume(returning: fresh)
        _ = try await task.value
        let key = try XCTUnwrap(PrivateImageCacheKey(bucketID: "groomer-avatars", storagePath: "old/avatar.jpg"))
        XCTAssertNil(images.data(for: key))
        XCTAssertNil(FilePrivateImageCache(directoryURL: directory.appendingPathComponent("images")).data(for: key))
    }

    func testColdDownloadsRunConcurrentlyWithABoundedFanout() async {
        let (directory, images, cache) = makeCache()
        defer { try? FileManager.default.removeItem(at: directory) }
        let ids = (0..<8).map { _ in UUID() }
        let source = AvatarDataSource(data: fresh)
        source.delays = true
        let loader = SupabaseParticipantAvatarLoader(privateImageLoader: PrivateImageLoader(dataSource: source, cache: images),
            cache: cache, accountID: { self.owner }, profiles: { ids, _ in
                ids.map { .init(id: $0, avatarPath: "\($0)/avatar.jpg") }
            })
        _ = await loader.avatars(for: ids, role: .groomer)
        await until { ids.allSatisfy { cache.data(for: $0, role: .groomer) == self.fresh } }
        XCTAssertEqual(source.maximumActive, 4)
        XCTAssertEqual(source.requests, 8)
    }

    private func makeCache() -> (URL, FilePrivateImageCache, ParticipantAvatarCache) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let images = FilePrivateImageCache(directoryURL: directory.appendingPathComponent("images"))
        return (directory, images, ParticipantAvatarCache(images: images, directory: directory.appendingPathComponent("paths")))
    }

    private func seed(_ cache: ParticipantAvatarCache, images: FilePrivateImageCache) {
        cache.activate(owner)
        images.save(old, for: PrivateImageCacheKey(bucketID: cache.bucket(.groomer), storagePath: "old/avatar.jpg")!)
        cache.commit(id: peer, role: .groomer, path: "old/avatar.jpg", generation: cache.generation, now: Date().addingTimeInterval(-120))
        cache.finish([peer], role: .groomer, generation: cache.generation)
    }

    private func until(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(condition())
    }
}

@MainActor private final class AvatarDataSource: PrivateImageDataFetching {
    let data: Data
    var requests = 0
    var blocks = false
    var delays = false
    var active = 0
    var maximumActive = 0
    var release: CheckedContinuation<Data, any Error>?
    init(data: Data) { self.data = data }
    func imageData(bucketID: String, storagePath: String) async throws -> Data {
        requests += 1
        active += 1
        maximumActive = max(maximumActive, active)
        defer { active -= 1 }
        if delays { try await Task.sleep(for: .milliseconds(10)) }
        if blocks { return try await withCheckedThrowingContinuation { release = $0 } }
        return data
    }
}
