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
        store.serviceType = .fullGroom
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
        var request = CustomerRequestsStoreTests.request(
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
        #expect(request.preferenceTimeZoneIdentifier == nil)
        request.preferenceTimeZoneIdentifier = "America/Los_Angeles"
        #expect(request.replacing(status: .cancelled).preferenceTimeZoneIdentifier == "America/Los_Angeles")
    }

    @Test
    func detailedDateChangeRejectsGapAndRequiresExplicitFoldOccurrence() async throws {
        let store = await makeStore()
        let address = Self.confirmedAddress()
        store.addressEditorState.replaceInput(address.accepted, confirmedAddress: address)
        let formatter = ISO8601DateFormatter()
        let gapStart = try #require(formatter.date(from: "2026-03-07T10:30:00Z"))
        store.preferredStart = gapStart
        store.preferredEnd = gapStart.addingTimeInterval(3600)
        #expect(!store.applyDetailedDate(try #require(formatter.date(from: "2026-03-08T19:00:00Z"))))
        #expect(store.preferredStart == gapStart)
        #expect(store.preferredEnd == gapStart.addingTimeInterval(3600))
        store.preferredStart = try #require(formatter.date(from: "2026-10-31T08:30:00Z"))
        store.preferredEnd = try #require(formatter.date(from: "2026-10-31T10:30:00Z"))
        #expect(store.applyDetailedDate(try #require(formatter.date(from: "2026-11-01T20:00:00Z"))))
        #expect(store.preferredStartOccurrences.count == 2)
        #expect(store.hasUnresolvedPreferredOccurrence)
        let later = try #require(store.preferredStartOccurrences.last)
        store.confirmPreferredOccurrence(later.addingTimeInterval(60), isStart: true)
        #expect(store.confirmedPreferredOccurrence(isStart: true) == nil)
        store.confirmPreferredOccurrence(later, isStart: true)
        #expect(store.preferredStart == later)
        #expect(!store.hasUnresolvedPreferredOccurrence)
        store.preferredEnd = later.addingTimeInterval(15 * 60)
        #expect(store.preferredEndOccurrences.count == 2)
        #expect(store.hasUnresolvedPreferredOccurrence)
        store.confirmPreferredOccurrence(store.preferredEnd, isStart: false)
        #expect(!store.hasUnresolvedPreferredOccurrence)
        store.preferredStart = later.addingTimeInterval(60)
        #expect(store.hasUnresolvedPreferredOccurrence)
    }

    @Test
    func requestCalendarUsesConfirmedLocationAndKeepsUnknownUnknown() async throws {
        let store = await makeStore()
        #expect(store.requestCalendar == nil)
        var address = Self.confirmedAddress()
        address.timeZoneIdentifier = "America/New_York"
        store.addressEditorState.replaceInput(address.accepted, confirmedAddress: address)
        let calendar = try #require(store.requestCalendar)
        #expect(calendar.timeZone.identifier == "America/New_York")
        let day = try #require(ISO8601DateFormatter().date(from: "2026-09-08T15:00:00Z"))
        let range = try #require(CustomerRequestTimeWindowOption.morning.range(on: day, calendar: calendar))
        #expect(ISO8601DateFormatter().string(from: range.start) == "2026-09-08T10:00:00Z")
        address.timeZoneIdentifier = nil
        store.addressEditorState.replaceInput(address.accepted, confirmedAddress: address)
        #expect(store.requestCalendar == nil)
    }

    @Test
    func missingReferenceZoneIsRejectedBeforePublishing() async {
        let repository = CustomerRequestRepositoryFake()
        let customerID = UUID()
        let pet = CustomerRequestsStoreTests.pet(customerID: customerID)
        let store = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
            requestRepository: repository, bookingRepository: CustomerRequestBookingRepositoryFake())
        await store.load()
        store.startCreate()
        store.serviceType = .fullGroom
        store.preferredStart = Date().addingTimeInterval(3600)
        store.preferredEnd = Date().addingTimeInterval(7200)
        var address = Self.confirmedAddress()
        address.timeZoneIdentifier = nil
        store.addressEditorState.replaceInput(address.accepted, confirmedAddress: address)
        #expect(store.validateWizardStep(.time).fields == [.addressConfirmation])
        await store.publish()
        #expect(repository.lastDraft == nil)
        #expect(store.errorMessage == "Confirm the service address time zone with Apple Maps before publishing.")
    }

    @Test
    func requestV3PayloadIncludesIdempotencyAndPrivateLocationContract() throws {
        var confirmed = Self.confirmedAddress(placeID: nil)
        confirmed.timeZoneIdentifier = "America/Los_Angeles"
        let publishOperationID = UUID()
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
            confirmedAddress: confirmed,
            publishOperationID: publishOperationID
        )
        let data = try JSONEncoder().encode(CreateGroomingRequestV3Parameters(draft: draft))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(
            object["p_publish_operation_id"] as? String ==
                publishOperationID.uuidString.lowercased()
        )
        #expect(object["p_address_line_2"] as? String == "Unit 2410")
        #expect(object["p_provider"] as? String == "apple_maps")
        #expect(object["p_place_id"] is NSNull)
        #expect(object["p_latitude"] as? Double == 33.8703)
        #expect(object["p_longitude"] as? Double == -117.9242)
        let versionedData = try JSONEncoder().encode(CreateGroomingRequestV4Parameters(draft: draft))
        let versioned = try #require(JSONSerialization.jsonObject(with: versionedData) as? [String: Any])
        #expect(versioned["p_publish_operation_id"] as? String == publishOperationID.uuidString.lowercased())
        #expect(versioned["p_preference_time_zone_identifier"] as? String == "America/Los_Angeles")
        let payload = try #require(versioned["p_request"] as? [String: Any])
        for (key, value) in object where key != "p_publish_operation_id" {
            let field = String(key.dropFirst(2))
            let actual = try #require(payload[field])
            #expect(NSDictionary(dictionary: [field: value]).isEqual(to: [field: actual]))
        }
        var missingZone = draft
        missingZone.confirmedAddress?.timeZoneIdentifier = nil
        #expect(throws: (any Error).self) {
            try JSONEncoder().encode(CreateGroomingRequestV4Parameters(draft: missingZone))
        }
    }

    private static var input: BeckonAddressInput {
        confirmedAddress().accepted
    }

    private static func confirmedAddress(
        placeID: String? = "apple-place"
    ) -> BeckonConfirmedAddress {
        var address = ProfileAddressIntegrationTests.confirmedAddress(placeID: placeID)
        address.timeZoneIdentifier = "America/Los_Angeles"
        return address
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
