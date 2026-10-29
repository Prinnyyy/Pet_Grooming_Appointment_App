import Foundation
import Testing
@testable import Beckon

@MainActor struct CustomerGroomerProfileTests {
    private static let id = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private func row(photos: [[String: Any]] = []) throws -> CustomerGroomerProfileRow {
        let payload: [String: Any] = [
            "profile": ["id": Self.id.uuidString, "business_name": "Pine Street Grooming",
                        "rating_sum": 0, "rating_count": 0, "is_verified": false],
            "services": [], "photos": photos, "tags": [], "claims": [], "windows": [], "modes": []
        ]
        return try JSONDecoder().decode(CustomerGroomerProfileRow.self, from: JSONSerialization.data(withJSONObject: payload))
    }
    @Test func missingPublicContentStaysMissingRatherThanBecomingSampleData() throws {
        let value = try row().profile(expectedID: Self.id)
        #expect(value.content.services.isEmpty)
        #expect(value.content.works.isEmpty)
        #expect(value.content.windows.isEmpty)
        #expect(value.content.noticeDays == nil)
        #expect(value.content.radiusMiles == nil)
        #expect(value.content.workplace.value == "—")
        #expect(value.profile.ratingCount == 0)
    }
    @Test func rejectsAnotherGroomersProfileOrPortfolioPath() throws {
        #expect(throws: RequestDiscoveryError.self) { try row().profile(expectedID: UUID()) }
        let photo: [String: Any] = ["id": UUID().uuidString, "groomer_id": Self.id.uuidString,
            "storage_bucket": "groomer-portfolio", "storage_path": "another-account/work.jpg", "sort_order": 0]
        #expect(throws: RequestDiscoveryError.self) { try row(photos: [photo]).profile(expectedID: Self.id) }
    }
    @Test func aPublicPhotoStartsWithoutInventedImageBytes() throws {
        let photo: [String: Any] = ["id": UUID().uuidString, "groomer_id": Self.id.uuidString,
            "storage_bucket": "groomer-portfolio", "storage_path": Self.id.uuidString.lowercased() + "/work.jpg", "sort_order": 0]
        let value = try row(photos: [photo]).profile(expectedID: Self.id)
        #expect(value.content.works.count == 1)
        #expect(value.content.works[0].image == nil)
        #expect(value.content.works[0].tags.isEmpty)
    }
    // Shape sampled from the deployed customer projection; identities and text are synthetic.
    @Test func populatedPublicProjectionReusesExistingOwnerRowDecoders() throws {
        let payload = #"""
        {
          "profile": {
            "id": "11111111-1111-4111-8111-111111111111",
            "business_name": "Wire fixture",
            "rating_sum": 0,
            "rating_count": 0,
            "is_verified": false
          },
          "services": [
            {
              "accepted_pet_sizes": [],
              "accepted_species": null,
              "base_price": 68,
              "description": "Public service description",
              "duration_minutes": 80,
              "groomer_id": "11111111-1111-4111-8111-111111111111",
              "id": "22222222-2222-4222-8222-222222222222",
              "is_active": true,
              "service_type": "bath_and_brush",
              "title": "Full groom"
            }
          ],
          "photos": [],
          "tags": [],
          "claims": [
            {
              "groomer_id": "11111111-1111-4111-8111-111111111111",
              "id": "22222222-2222-4222-8222-222222222222",
              "is_active": true,
              "trait_type": "care_flag",
              "trait_value": "senior"
            }
          ],
          "windows": [
            {
              "end_time": "17:00:00",
              "groomer_id": "11111111-1111-4111-8111-111111111111",
              "id": "22222222-2222-4222-8222-222222222222",
              "is_enabled": true,
              "start_time": "09:00:00",
              "timezone": "America/Los_Angeles",
              "weekday": 1
            }
          ],
          "modes": [
            "groomer_comes_to_customer",
            "customer_comes_to_groomer"
          ],
          "radius_miles": 12,
          "notice_days": 1,
          "time_off": null
        }
        """#
        let wire = try JSONDecoder().decode(CustomerGroomerProfileRow.self, from: Data(payload.utf8))
        let result = try wire.profile(expectedID: Self.id)
        #expect(result.content.services.count == 1)
        #expect(result.content.windows.count == 1)
        #expect(result.content.specialties.count == 1)
        #expect(result.content.hoursText != nil)
        #expect(result.content.works.isEmpty)
    }

}
