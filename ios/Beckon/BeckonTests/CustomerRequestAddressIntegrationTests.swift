import Foundation
import Testing
@testable import Beckon

@MainActor
struct CustomerRequestAddressIntegrationTests {
    @Test
    func completeUnconfirmedAddressCannotLeaveTimeAndLocation() async {
        let store = await makeStore()
        store.addressEditorState.replaceInput(Self.input, confirmedAddress: nil)

        let validation = store.validateWizardStep(
            .time,
            now: store.preferredStart.addingTimeInterval(-60 * 60)
        )

        #expect(!validation.isValid)
        #expect(validation.fields == [.addressConfirmation])
        #expect(validation.requiresOnlyAddressConfirmation)
        #expect(validation.message == "Confirm the service address with Apple Maps before continuing.")
    }

    @Test
    func currentProfileAutofillRetainsConfirmedMetadata() async throws {
        let confirmed = Self.confirmedAddress()
        let profile = CustomerProfileDetails(
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

        let autofill = try #require(CustomerProfileAddressAutofill.make(from: profile))
        let store = await makeStore()
        store.applyProfileAddressAutofill(autofill)

        #expect(store.addressEditorState.confirmedAddress == confirmed)
        #expect(store.addressLine2 == "Unit 2410")
    }

    @Test
    func staleProfileMetadataIsNotRetainedForAutofill() throws {
        let confirmed = Self.confirmedAddress()
        let profile = CustomerProfileDetails(
            userID: UUID(),
            nickname: "Prinny",
            avatarPath: nil,
            streetAddress: "780 S Harbor Blvd",
            addressLine2: "Unit 2410",
            city: "Fullerton",
            stateCode: .california,
            zipCode: "92832",
            contactEmail: nil,
            phoneNumber: nil,
            confirmedAddress: confirmed
        )

        let autofill = try #require(CustomerProfileAddressAutofill.make(from: profile))

        #expect(autofill.confirmedAddress == nil)
    }

    @Test
    func publishCarriesConfirmedLineTwoAndCoordinateMetadata() async {
        let customerID = UUID()
        let pet = CustomerRequestsStoreTests.pet(customerID: customerID)
        let requestID = UUID()
        let repository = CustomerRequestRepositoryFake(
            createResult: .success(
                GroomingRequestPublishResult(requestID: requestID, matchCount: 1)
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake(),
            addressProvider: RequestAddressProviderStub()
        )
        await store.load()
        store.startCreate()
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(2 * 60 * 60)
        let confirmed = Self.confirmedAddress(placeID: nil)
        store.addressEditorState.replaceInput(
            confirmed.accepted,
            confirmedAddress: confirmed
        )

        await store.publish()

        #expect(repository.lastDraft?.addressLine2 == "Unit 2410")
        #expect(repository.lastDraft?.confirmedAddress == confirmed)
        #expect(repository.lastDraft?.confirmedAddress?.placeID == nil)
    }

    @Test
    func republishRequiresAddressReviewBeforePublishing() async {
        let customerID = UUID()
        let pet = CustomerRequestsStoreTests.pet(customerID: customerID)
        let request = CustomerRequestsStoreTests.request(
            customerID: customerID,
            petID: pet.id,
            status: .cancelled,
            streetAddress: "770 S Harbor Blvd",
            addressLine2: "Unit 2410",
            city: "Fullerton",
            state: "CA",
            zipCode: "92832"
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
            requestRepository: CustomerRequestRepositoryFake(requestsResult: .success([request])),
            bookingRepository: CustomerRequestBookingRepositoryFake(),
            addressProvider: RequestAddressProviderStub()
        )
        await store.load()

        store.startRepublish(from: request)

        #expect(store.wizardInitialStep == .time)
        #expect(store.addressEditorState.confirmedAddress == nil)
        #expect(store.addressLine2 == "Unit 2410")
    }

    @Test
    func customerOwnedRequestLocationIncludesAddressLineTwo() {
        let request = CustomerRequestsStoreTests.request(
            customerID: UUID(),
            petID: UUID(),
            streetAddress: "770 S Harbor Blvd",
            addressLine2: "Unit 2410",
            city: "Fullerton",
            state: "CA",
            zipCode: "92832"
        )

        #expect(
            request.locationSummary ==
                "770 S Harbor Blvd, Unit 2410, Fullerton, CA 92832"
        )
    }

    @Test
    func requestV2PayloadIncludesPrivateLocationContract() throws {
        let confirmed = Self.confirmedAddress(placeID: nil)
        let draft = GroomingRequestDraft(
            petID: UUID(),
            serviceType: .fullGroom,
            serviceNotes: nil,
            preferredStart: Date(timeIntervalSince1970: 1_750_000_000),
            preferredEnd: Date(timeIntervalSince1970: 1_750_003_600),
            locationMode: .groomerComesToCustomer,
            streetAddress: confirmed.accepted.line1,
            addressLine2: confirmed.accepted.line2,
            city: confirmed.accepted.city,
            stateCode: .california,
            zipCode: confirmed.accepted.postalCode,
            travelRadiusMiles: nil,
            confirmedAddress: confirmed
        )
        let data = try JSONEncoder().encode(CreateGroomingRequestV2Parameters(draft: draft))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["p_address_line_2"] as? String == "Unit 2410")
        #expect(object["p_provider"] as? String == "apple_maps")
        #expect(object["p_place_id"] is NSNull)
        #expect(object["p_latitude"] as? Double == 33.8703)
        #expect(object["p_longitude"] as? Double == -117.9242)
    }

    private static var input: BeckonAddressInput {
        confirmedAddress().accepted
    }

    private static func confirmedAddress(
        placeID: String? = "apple-place"
    ) -> BeckonConfirmedAddress {
        ProfileAddressIntegrationTests.confirmedAddress(placeID: placeID)
    }

    private func makeStore() async -> CustomerRequestsStore {
        let customerID = UUID()
        let pet = CustomerRequestsStoreTests.pet(customerID: customerID)
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake(),
            addressProvider: RequestAddressProviderStub()
        )
        await store.load()
        store.startCreate()
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(2 * 60 * 60)
        return store
    }
}

@MainActor
private final class RequestAddressProviderStub: BeckonAddressProviding {
    func updateSuggestions(for line1Query: String) async -> [BeckonAddressCandidate] { [] }
    func resolve(candidateID: String, preservingLine2: String) async throws -> BeckonResolvedAddress {
        throw BeckonAddressProviderError.unknownCandidate
    }
    func geocode(_ input: BeckonAddressInput) async throws -> [BeckonResolvedAddress] { [] }
    func clear() {}
}
