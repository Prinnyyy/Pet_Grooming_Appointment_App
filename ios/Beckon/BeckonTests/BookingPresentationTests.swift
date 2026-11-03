import Foundation
import Testing
import Supabase
@testable import Beckon

@MainActor
struct BookingPresentationTests {
    @Test func photosAndNamesRefreshIndependentlyWithoutBlankingKnownContent() async {
        let booking = BookingsStoreTests.booking()
        let repository = BookingRepositoryFake()
        let oldPhoto = Data("cached pet".utf8), newPhoto = Data("updated pet".utf8)
        repository.cachedPetPhotoData = oldPhoto
        repository.petPhotoResult = .success(newPhoto)
        repository.customerDisplayNameResult = .success("  Alex Chen  ")
        let store = BookingsStore(participantID: booking.groomerID, role: .groomer, repository: repository,
            initialBookings: [booking])
        #expect(store.petPhoto(for: booking) == oldPhoto)
        await store.loadPresentation(for: booking)
        #expect(store.petPhoto(for: booking) == newPhoto)
        #expect(store.customerNamesByBookingID[booking.id] == "Alex Chen")
        repository.petPhotoResult = .failure(.networkUnavailable)
        repository.customerDisplayNameResult = .failure(.networkUnavailable)
        await store.loadPresentation(for: booking)
        #expect(store.petPhoto(for: booking) == newPhoto)
        #expect(store.customerNamesByBookingID[booking.id] == "Alex Chen")
        repository.cachedPetPhotoData = nil
        repository.petPhotoResult = .success(nil)
        repository.customerDisplayNameResult = .success(nil)
        await store.loadPresentation(for: booking)
        #expect(store.petPhoto(for: booking) == nil)
        #expect(store.customerNamesByBookingID[booking.id] == nil)
    }

    @Test func unrelatedGroomerDoesNotReadPresentation() async {
        let booking = BookingsStoreTests.booking()
        let repository = BookingRepositoryFake()
        repository.petPhotoResult = .success(Data("private".utf8))
        repository.customerDisplayNameResult = .success("Private name")
        let store = BookingsStore(participantID: UUID(), role: .groomer, repository: repository)
        await store.loadPresentation(for: booking)
        #expect(store.petPhotosByBookingID.isEmpty)
        #expect(store.customerNamesByBookingID.isEmpty)
    }
}


@Suite(.serialized) @MainActor
struct BookingPetPhotoTransportTests {
    @Test func requestSnapshotChoosesPetPrimaryInsteadOfAnAttachmentOrFirstPhoto() async throws {
        let pet = UUID()
        let booking = BookingsStoreTests.booking()
        let firstPath = "\(booking.customerID)/\(pet)/secondary.jpg"
        let primaryPath = "\(booking.customerID)/\(pet)/primary.jpg"
        func photo(_ path: String, primary: Bool, order: Int) -> [String: Any] {
            ["id": UUID().uuidString, "storage_bucket": "pet-photos", "storage_path": path,
             "sort_order": order, "is_primary": primary]
        }
        let payload: [String: Any] = ["id": booking.requestID.uuidString,
            "customer_id": booking.customerID.uuidString,
            "pet_snapshot": ["id": pet.uuidString, "name": "Mochi", "species": "Dog"],
            "photo_snapshot": [photo(firstPath, primary: false, order: 0), photo(primaryPath, primary: true, order: 5)]]
        BookingPhotoTransport.setPayload(try JSONSerialization.data(withJSONObject: payload))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BookingPhotoTransport.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = SupabaseClient(supabaseURL: URL(string: "https://booking-photo.invalid")!, supabaseKey: "test-key",
            options: .init(global: .init(session: session)))
        let images = BookingPhotoImageFake()
        let repository = SupabaseBookingRepository(client: client, privateImageLoader: images)
        let bytes = try await repository.petPhoto(for: booking)
        #expect(bytes == Data("pet image".utf8))
        #expect(images.bucket == "pet-photos")
        #expect(images.path == primaryPath)
    }
}

@MainActor private final class BookingPhotoImageFake: PrivateImageLoading {
    var bucket: String?, path: String?
    func loadData(bucketID: String, storagePath: String) async throws -> Data {
        bucket = bucketID; path = storagePath
        return Data("pet image".utf8)
    }
    func refreshData(bucketID: String, storagePath: String) async throws -> Data { try await loadData(bucketID: bucketID, storagePath: storagePath) }
    func saveData(_ data: Data, bucketID: String, storagePath: String) {}
    func removeData(bucketID: String, storagePath: String) {}
}

nonisolated private final class BookingPhotoTransport: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var payload = Data()
    static func setPayload(_ value: Data) { lock.withLock { payload = value } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "booking-photo.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let valid = url.path == "/rest/v1/rpc/get_groomer_request_detail_v1"
        let response = HTTPURLResponse(url: url, statusCode: valid ? 200 : 403, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.lock.withLock { Self.payload })
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
