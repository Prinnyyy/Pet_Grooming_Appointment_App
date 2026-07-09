import Foundation
import Testing
@testable import PetGroomerMarketplace

struct DecodeToleranceFeatureTests {
    @Test
    func unknownMarketplaceStatusesDecodeToSafeFallbacks() throws {
        let decoder = JSONDecoder()

        let requestStatus = try decoder.decode(
            GroomingRequestStatus.self,
            from: Data(#""paused_by_system""#.utf8)
        )
        let matchStatus = try decoder.decode(
            RequestMatchStatus.self,
            from: Data(#""snoozed""#.utf8)
        )
        let offerStatus = try decoder.decode(
            GroomerOfferStatus.self,
            from: Data(#""countered""#.utf8)
        )
        let bookingStatus = try decoder.decode(
            BookingStatus.self,
            from: Data(#""rescheduled""#.utf8)
        )

        #expect(requestStatus.rawValue == "unknown")
        #expect(requestStatus.title == "Unknown")
        #expect(requestStatus.isOpenForOffers == false)
        #expect(matchStatus.rawValue == "unknown")
        #expect(matchStatus.title == "Unknown")
        #expect(matchStatus.isDismissible == false)
        #expect(matchStatus.isOfferable == false)
        #expect(offerStatus.rawValue == "unknown")
        #expect(offerStatus.title == "Unknown")
        #expect(bookingStatus.rawValue == "unknown")
        #expect(bookingStatus.title == "Unknown")
        #expect(bookingStatus.isCancellation == false)
    }

    @Test
    func badServerDatesRemainDisplayableAsRawValues() {
        let malformedDate = "not-a-server-date"

        #expect(GroomingRequestDateFormatting.parsedDate(from: malformedDate) == nil)
        #expect(GroomingRequestDateFormatting.displayString(from: malformedDate) == malformedDate)
    }

    @Test
    @MainActor
    func petSnapshotDecodesNullOptionalFields() throws {
        let json = """
        {
          "id": "00000000-0000-4000-8000-000000000001",
          "name": "Mochi",
          "species": "dog",
          "breed": null,
          "coat_type": null,
          "size": null,
          "weight_lbs": null,
          "birthday": null,
          "temperament": null,
          "medical_notes": null,
          "grooming_notes": null,
          "snapshot_at": null
        }
        """

        let snapshot = try JSONDecoder().decode(
            GroomingRequestPetSnapshot.self,
            from: Data(json.utf8)
        )

        #expect(snapshot.name == "Mochi")
        #expect(snapshot.breed == nil)
        #expect(snapshot.coatType == nil)
        #expect(snapshot.weightLbs == nil)
        #expect(snapshot.snapshotAt == nil)
    }

    @Test
    @MainActor
    func fileImageCacheIgnoresOversizedCorruptData() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = FilePrivateImageCache(directoryURL: directoryURL)
        let key = try #require(
            PrivateImageCacheKey(
                bucketID: "request-photos",
                storagePath: "customer/request/corrupt.bin"
            )
        )
        let oversizedCorruptData = Data(repeating: 0x00, count: 10 * 1024 * 1024 + 1)

        cache.save(oversizedCorruptData, for: key)

        #expect(cache.data(for: key) == nil)
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
