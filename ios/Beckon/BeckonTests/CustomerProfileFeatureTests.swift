import Foundation
import Testing
import UIKit
@testable import Beckon

struct CustomerProfileKeyboardFocusContractTests {
    @Test
    func profileTargetsAreStableAndDistinct() {
        #expect(CustomerProfileFocusTarget.nickname.rawValue == "customer.profile.nickname.container")
        #expect(CustomerProfileFocusTarget.email.rawValue == "customer.profile.email.container")
        #expect(CustomerProfileFocusTarget.phone.rawValue == "customer.profile.phone.container")
        #expect(Set(CustomerProfileFocusTarget.allCases.map(\.rawValue)).count == 3)
    }
}

struct CustomerAvatarPhotoPathTests {
    @Test
    func storagePathMatchesBackendContractAndUsesLowercaseUUIDs() {
        let customerID = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
        let fileID = UUID(uuidString: "99999999-AAAA-4BBB-8CCC-DDDDDDDDDDDD")!

        let path = CustomerAvatarPhotoPath.make(
            customerID: customerID,
            fileID: fileID,
            contentType: .png
        )

        #expect(
            path ==
                "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/99999999-aaaa-4bbb-8ccc-dddddddddddd.png"
        )
    }
}

struct CustomerProfileStorageBucketTests {
    @Test
    func customerAvatarBucketIsSeparateFromOtherPhotoBuckets() {
        #expect(PhotoStorageBucketID.customerAvatar.rawValue == "customer-avatars")
        #expect(PhotoStorageBucketID.groomerAvatar.rawValue == "groomer-avatars")
        #expect(PhotoStorageBucketID.groomerPortfolio.rawValue == "groomer-portfolio")
        #expect(PhotoStorageBucketID.customerPet.rawValue == "pet-photos")
        #expect(PhotoStorageBucketID.groomingRequest.rawValue == "request-photos")

        #expect(
            Set(PhotoStorageBucketID.allCases.map(\.rawValue)).count
                == PhotoStorageBucketID.allCases.count
        )
    }
}

struct CustomerProfileAddressSearchTests {
    @Test @MainActor
    func customerProfileAddressSuggestionsUseSharedDeduplication() {
        let result = CustomerProfileAddressSuggestionBuilder.build(
            from: [
                CustomerProfileAddressCompletion(
                    title: "100 Main Street",
                    subtitle: "Los Angeles, CA",
                    completion: "first"
                ),
                CustomerProfileAddressCompletion(
                    title: "100 Main Street",
                    subtitle: "Los Angeles, CA",
                    completion: "duplicate"
                ),
                CustomerProfileAddressCompletion(
                    title: "200 Broadway",
                    subtitle: "Anaheim, CA",
                    completion: "second"
                ),
            ]
        )

        #expect(result.suggestions.map(\.title) == [
            "100 Main Street",
            "200 Broadway",
        ])
        #expect(result.completionsByID[result.suggestions[0].id] == "first")
        #expect(result.completionsByID[result.suggestions[1].id] == "second")
    }
}

struct CustomerProfileRepositoryPayloadTests {
    @Test @MainActor
    func existingCustomerProfileUpdatePayloadDoesNotEncodeUserID() throws {
        let draft = CustomerProfileDraft(
            nickname: "Prinny",
            streetAddress: "123 Pine Street",
            city: "Seattle",
            stateCode: .washington,
            zipCode: "98101",
            contactEmail: "owner@example.com",
            phoneNumber: "+1 555 222 3333"
        )

        let data = try JSONEncoder().encode(CustomerProfileDetailsUpdateRow(draft: draft))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(object["user_id"] == nil)
        #expect(object["street_address"] == "123 Pine Street")
        #expect(object["city"] == "Seattle")
        #expect(object["state"] == "WA")
        #expect(object["zip_code"] == "98101")
        #expect(object["contact_email"] == "owner@example.com")
        #expect(object["phone_number"] == "+1 555 222 3333")
    }
}

struct CustomerAvatarImageEncoderTests {
    @Test @MainActor
    func displayablePayloadKeepsDisplayablePNGWhenPreferred() throws {
        let sourceData = try Self.solidPNGData()

        let payload = try #require(
            CustomerAvatarImageEncoder.displayablePayload(
                from: sourceData,
                preferredContentType: .png
            )
        )

        #expect(payload.contentType == .png)
        #expect(UIImage(data: payload.data) != nil)
    }

    @Test @MainActor
    func displayablePayloadConvertsHEICPreferenceToDisplayableJPEG() throws {
        let sourceData = try Self.solidPNGData()

        let payload = try #require(
            CustomerAvatarImageEncoder.displayablePayload(
                from: sourceData,
                preferredContentType: .heic
            )
        )

        #expect(payload.contentType == .jpeg)
        #expect(UIImage(data: payload.data) != nil)
    }

    @MainActor
    private static func solidPNGData() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        return try #require(image.pngData())
    }
}

struct CustomerProfileStoreTests {
    @Test @MainActor
    func saveProfileNormalizesDraftAndUpdatesSnapshot() async {
        let customerID = UUID()
        let repository = CustomerProfileRepositoryFake(
            profileResult: .success(Self.profile(customerID: customerID))
        )
        let cache = ProfileSnapshotCacheFake()
        let store = CustomerProfileStore(
            customerID: customerID,
            initialDisplayName: "Old Name",
            sessionEmail: "owner@example.com",
            repository: repository,
            profileSnapshotCache: cache
        )

        store.nickname = "  Prinny  "
        store.streetAddress = "  123 Pine Street  "
        store.city = "  Seattle  "
        store.stateCode = .washington
        store.zipCode = "98101"
        store.contactEmail = "  owner@example.com  "
        store.phoneNumber = "  +1 555 222 3333  "
        let confirmedAddress = ProfileAddressIntegrationTests.confirmedAddress(
            line1: "123 Pine Street",
            line2: "",
            city: "Seattle",
            stateCode: .washington,
            postalCode: "98101",
            placeID: nil
        )
        store.addressEditorState.replaceInput(
            confirmedAddress.accepted,
            confirmedAddress: confirmedAddress
        )

        await store.saveProfile()

        #expect(repository.updateCallCount == 1)
        #expect(repository.lastDraft?.nickname == "Prinny")
        #expect(repository.lastDraft?.streetAddress == "123 Pine Street")
        #expect(repository.lastDraft?.city == "Seattle")
        #expect(repository.lastDraft?.stateCode == .washington)
        #expect(repository.lastDraft?.zipCode == "98101")
        #expect(repository.lastDraft?.contactEmail == "owner@example.com")
        #expect(repository.lastDraft?.phoneNumber == "+1 555 222 3333")
        #expect(store.profileDisplayName == "Prinny")
        #expect(cache.savedSnapshots.last?.displayName == "Prinny")
        #expect(store.noticeMessage == "Profile saved.")
    }

    @Test @MainActor
    func invalidEmailDoesNotCallRepository() async {
        let repository = CustomerProfileRepositoryFake()
        let store = CustomerProfileStore(
            customerID: UUID(),
            initialDisplayName: "Prinny",
            sessionEmail: nil,
            repository: repository
        )

        store.nickname = "Prinny"
        store.contactEmail = "not-an-email"

        await store.saveProfile()

        #expect(repository.updateCallCount == 0)
        #expect(store.errorMessage == "Enter a valid email address.")
    }

    @Test @MainActor
    func uploadAvatarRefreshesVisibleDataAndSnapshot() async {
        let customerID = UUID()
        let repository = CustomerProfileRepositoryFake(
            profileResult: .success(Self.profile(customerID: customerID))
        )
        let cache = ProfileSnapshotCacheFake()
        let store = CustomerProfileStore(
            customerID: customerID,
            initialDisplayName: "Prinny",
            sessionEmail: "owner@example.com",
            repository: repository,
            profileSnapshotCache: cache
        )
        await store.load()

        let data = Data([0x01, 0x02, 0x03])
        await store.uploadAvatarPhoto(data: data, contentType: .jpeg)

        #expect(repository.uploadAvatarCallCount == 1)
        #expect(store.profile?.avatarPath == repository.uploadedAvatarPath)
        #expect(store.avatarPhotoData == data)
        #expect(cache.savedSnapshots.last?.avatarData == data)
        #expect(store.noticeMessage == "Profile photo was updated.")
    }

    private static func profile(
        customerID: UUID,
        nickname: String = "Prinny",
        avatarPath: String? = nil
    ) -> CustomerProfileDetails {
        CustomerProfileDetails(
            userID: customerID,
            nickname: nickname,
            avatarPath: avatarPath,
            streetAddress: nil,
            city: nil,
            stateCode: nil,
            zipCode: nil,
            contactEmail: "owner@example.com",
            phoneNumber: nil
        )
    }
}

@MainActor
final class CustomerProfileRepositoryFake: CustomerProfileRepository {
    var profileResult: Result<CustomerProfileDetails, CustomerProfileRepositoryError>
    var updateProfileResult: Result<CustomerProfileDetails, CustomerProfileRepositoryError>?
    var updateCallCount = 0
    var uploadAvatarCallCount = 0
    var lastCustomerID: UUID?
    var lastDraft: CustomerProfileDraft?
    var lastConfirmedAddress: BeckonConfirmedAddress?
    var uploadedAvatarPath = ""

    init(
        profileResult: Result<CustomerProfileDetails, CustomerProfileRepositoryError> =
            .success(
                CustomerProfileDetails(
                    userID: UUID(),
                    nickname: "Prinny",
                    avatarPath: nil,
                    streetAddress: nil,
                    city: nil,
                    stateCode: nil,
                    zipCode: nil,
                    contactEmail: nil,
                    phoneNumber: nil
                )
            ),
        updateProfileResult: Result<CustomerProfileDetails, CustomerProfileRepositoryError>? = nil
    ) {
        self.profileResult = profileResult
        self.updateProfileResult = updateProfileResult
    }

    func profile(customerID: UUID) async throws -> CustomerProfileDetails {
        try profileResult.get()
    }

    func updateProfile(
        customerID: UUID,
        draft: CustomerProfileDraft
    ) async throws -> CustomerProfileDetails {
        updateCallCount += 1
        lastCustomerID = customerID
        lastDraft = draft

        if let updateProfileResult {
            return try updateProfileResult.get()
        }

        return CustomerProfileDetails(
            userID: customerID,
            nickname: draft.nickname,
            avatarPath: nil,
            streetAddress: draft.streetAddress,
            addressLine2: draft.addressLine2,
            city: draft.city,
            stateCode: draft.stateCode,
            zipCode: draft.zipCode,
            contactEmail: draft.contactEmail,
            phoneNumber: draft.phoneNumber
        )
    }

    func updateProfile(
        customerID: UUID,
        draft: CustomerProfileDraft,
        confirmedAddress: BeckonConfirmedAddress?
    ) async throws -> CustomerProfileDetails {
        lastConfirmedAddress = confirmedAddress
        var profile = try await updateProfile(customerID: customerID, draft: draft)
        profile.confirmedAddress = confirmedAddress
        return profile
    }

    func uploadAvatarPhoto(
        customerID: UUID,
        data: Data,
        contentType: CustomerAvatarPhotoContentType
    ) async throws -> String {
        uploadAvatarCallCount += 1
        uploadedAvatarPath = CustomerAvatarPhotoPath.make(
            customerID: customerID,
            fileID: UUID(uuidString: "99999999-AAAA-4BBB-8CCC-DDDDDDDDDDDD")!,
            contentType: contentType
        )
        return uploadedAvatarPath
    }

    func avatarPhotoData(storagePath: String) async throws -> Data {
        Data("avatar:\(storagePath)".utf8)
    }

    func latestAvatarPhotoPath(customerID: UUID) async throws -> String? {
        nil
    }
}

@MainActor
private final class ProfileSnapshotCacheFake: ProfileSnapshotCaching {
    var snapshot: ProfileSnapshot?
    private(set) var savedSnapshots: [ProfileSnapshot] = []
    private(set) var removedUserIDs: [UUID] = []

    init(snapshot: ProfileSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func snapshot(userID: UUID) -> ProfileSnapshot? {
        guard snapshot?.userID == userID else { return nil }
        return snapshot
    }

    func save(_ snapshot: ProfileSnapshot) {
        self.snapshot = snapshot
        savedSnapshots.append(snapshot)
    }

    func remove(userID: UUID) {
        if snapshot?.userID == userID {
            snapshot = nil
        }
        removedUserIDs.append(userID)
    }
}
