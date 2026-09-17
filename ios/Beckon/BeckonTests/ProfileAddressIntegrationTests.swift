import Foundation
import Testing
@testable import Beckon

@MainActor
struct ProfileAddressIntegrationTests {
    @Test
    func profileAddressRPCPayloadKeepsCoordinatesAndEncodesMissingPlaceIDAsNull() throws {
        let confirmed = Self.confirmedAddress(placeID: nil)
        let data = try JSONEncoder().encode(
            SaveProfileAddressRPCParameters(confirmedAddress: confirmed)
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["p_line_1"] as? String == "770 S Harbor Blvd")
        #expect(object["p_line_2"] as? String == "Unit 2410")
        #expect(object["p_place_id"] is NSNull)
        #expect(object["p_latitude"] as? Double == 33.8703)
        #expect(object["p_longitude"] as? Double == -117.9242)
        #expect((object["p_user_confirmed_at"] as? String)?.contains("T") == true)
    }

    @Test
    func customerChangedAddressRequiresConfirmation() async {
        let repository = CustomerProfileRepositoryFake()
        let store = CustomerProfileStore(
            customerID: UUID(),
            initialDisplayName: "Prinny",
            sessionEmail: nil,
            repository: repository,
            addressProvider: ProfileAddressProviderStub()
        )
        await store.load()

        store.addressEditorState.updateLine1("770 S Harbor Blvd")
        store.addressEditorState.updateCity("Fullerton")
        store.addressEditorState.updateState(.california)
        store.addressEditorState.updatePostalCode("92832")
        await store.saveProfile()

        #expect(repository.updateCallCount == 0)
        #expect(store.errorMessage == "Confirm the changed address with Apple Maps before saving.")
    }

    @Test
    func customerConfirmedAddressWithoutPlaceIDSavesLineTwoAndCoordinates() async {
        let repository = CustomerProfileRepositoryFake()
        let store = CustomerProfileStore(
            customerID: UUID(),
            initialDisplayName: "Prinny",
            sessionEmail: nil,
            repository: repository,
            addressProvider: ProfileAddressProviderStub()
        )
        await store.load()
        let confirmed = Self.confirmedAddress(placeID: nil)
        store.addressEditorState.replaceInput(
            confirmed.accepted,
            confirmedAddress: confirmed
        )

        await store.saveProfile()

        #expect(repository.lastConfirmedAddress == confirmed)
        #expect(repository.lastDraft?.addressLine2 == "Unit 2410")
        #expect(store.addressEditorState.status == .confirmed)
    }

    @Test
    func customerReloadRestoresConfirmedMetadata() async {
        let confirmed = Self.confirmedAddress(placeID: "apple-place")
        let repository = CustomerProfileRepositoryFake(
            profileResult: .success(
                CustomerProfileDetails(
                    userID: UUID(),
                    nickname: "Prinny",
                    avatarPath: nil,
                    streetAddress: confirmed.accepted.line1,
                    addressLine2: confirmed.accepted.line2,
                    city: confirmed.accepted.city,
                    stateCode: confirmed.accepted.stateCode,
                    zipCode: confirmed.accepted.postalCode,
                    contactEmail: nil,
                    phoneNumber: nil,
                    confirmedAddress: confirmed
                )
            )
        )
        let store = CustomerProfileStore(
            customerID: UUID(),
            initialDisplayName: "Prinny",
            sessionEmail: nil,
            repository: repository,
            addressProvider: ProfileAddressProviderStub()
        )

        await store.load()

        #expect(store.addressEditorState.confirmedAddress == confirmed)
        #expect(store.addressEditorState.input.line2 == "Unit 2410")
        if let profile = store.profile {
            let autofill = CustomerProfileAddressAutofill.make(from: profile)
            #expect(autofill?.addressLine2 == "Unit 2410")
            #expect(autofill?.confirmedAddress == confirmed)
        } else {
            Issue.record("Expected the loaded customer profile")
        }
    }

    @Test
    func cancelledCustomerSaveDoesNotSurfaceAnError() async {
        let repository = CustomerProfileRepositoryFake(
            updateProfileResult: .failure(.cancelled)
        )
        let store = CustomerProfileStore(
            customerID: UUID(),
            initialDisplayName: "Prinny",
            sessionEmail: nil,
            repository: repository,
            addressProvider: ProfileAddressProviderStub()
        )
        await store.load()

        await store.saveProfile()

        #expect(store.errorMessage == nil)
        #expect(store.noticeMessage == nil)
    }

    @Test
    func groomerChangedAddressRequiresConfirmation() async {
        let groomerID = UUID()
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(GroomerProfileStoreTests.profile(groomerID: groomerID))
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository,
            addressProvider: ProfileAddressProviderStub()
        )
        await store.load()

        store.addressEditorState.updateLine1("800 N Harbor Blvd")
        store.addressEditorState.updateCity("La Habra")
        store.addressEditorState.updateState(.california)
        store.addressEditorState.updatePostalCode("90631")
        await store.saveProfile()

        #expect(repository.updateProfileCallCount == 0)
        #expect(store.errorMessage == "Confirm the changed address with Apple Maps before saving.")
    }

    @Test
    func cancelledGroomerSaveDoesNotSurfaceAnError() async {
        let groomerID = UUID()
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(GroomerProfileStoreTests.profile(groomerID: groomerID)),
            updateProfileResult: .failure(.cancelled)
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository,
            addressProvider: ProfileAddressProviderStub()
        )
        await store.load()

        await store.saveProfile()

        #expect(store.errorMessage == nil)
        #expect(store.noticeMessage == nil)
    }

    static func confirmedAddress(
        line1: String = "770 S Harbor Blvd",
        line2: String = "Unit 2410",
        city: String = "Fullerton",
        stateCode: USStateCode = .california,
        postalCode: String = "92832",
        placeID: String?
    ) -> BeckonConfirmedAddress {
        let input = BeckonAddressInput(
            line1: line1,
            line2: line2,
            city: city,
            stateCode: stateCode,
            postalCode: postalCode,
            countryCode: "US"
        )
        return BeckonConfirmedAddress(
            entered: input,
            accepted: input,
            provider: "apple_maps",
            placeID: placeID,
            coordinate: BeckonAddressCoordinate(latitude: 33.8703, longitude: -117.9242),
            resolutionSource: "autocomplete_selection",
            confirmedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
    }
}

@MainActor
private final class ProfileAddressProviderStub: BeckonAddressProviding {
    func updateSuggestions(for line1Query: String) async -> [BeckonAddressCandidate] { [] }
    func resolve(candidateID: String, preservingLine2: String) async throws -> BeckonResolvedAddress {
        throw BeckonAddressProviderError.unknownCandidate
    }
    func geocode(_ input: BeckonAddressInput) async throws -> [BeckonResolvedAddress] { [] }
    func clear() {}
}
