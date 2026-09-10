import Foundation
import Testing
import SwiftUI
import XCTest
@testable import Beckon

@MainActor
struct CoreFirstLoadingTests {
    @Test func fixedGroomerDatasetMeasuresCoreLatencyAndImagePayload() async {
        let id = UUID()
        let photos = (0..<6).map { _ in GroomerProfileStoreTests.photo(groomerID: id) }
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(GroomerProfileStoreTests.profile(groomerID: id)),
            portfolioResult: .success(photos),
            portfolioPhotoDataResultsByID: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, .success(Data(repeating: 1, count: 32768))) }))
        var activeImages = 0
        var peakImages = 0
        repository.onRead = { name in
            if name == "image" {
                activeImages += 1
                peakImages = max(peakImages, activeImages)
            }
            try? await Task.sleep(for: .milliseconds(20))
            if name == "image" { activeImages -= 1 }
        }
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        let start = ContinuousClock.now
        let load = Task { await store.load() }
        while repository.readNames.isEmpty { await Task.yield() }
        while store.isLoading { try? await Task.sleep(for: .milliseconds(1)) }
        let core = start.duration(to: .now)
        let coreReads = repository.readNames.count
        await load.value
        let bytes = store.portfolioPhotoDataByID.values.reduce(0) { $0 + $1.count }
        print("WP13_FIXED profile: core=\(core), total=\(start.duration(to: .now)), coreStartedReads=\(coreReads), totalRepositoryReads=\(repository.readNames.count), imageBytes=\(bytes)")
        #expect(bytes == 196608)
        #expect(repository.portfolioPhotoDataCallCount == 6)
        #expect(peakImages == 3)
    }

    @Test func optionalMetadataStartsOnlyAfterAuthoritativeCoreIsUsable() async {
        let id = UUID()
        let profile = GroomerProfileStoreTests.profile(groomerID: id)
        let repository = GroomerProfileRepositoryFake(profileResult: .success(profile))
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        repository.onRead = { name in
            if ["portfolio", "tags", "claims", "evidence"].contains(name) {
                #expect(store.profile == profile)
                #expect(store.savedAvailability != nil)
                #expect(!store.isLoading)
            }
        }
        await store.load()
    }

    @Test func refreshCannotStartInsideAProfileMutation() async {
        let id = UUID()
        let groomerRepository = GroomerProfileRepositoryFake()
        let groomer = GroomerProfileStore(groomerID: id, repository: groomerRepository)
        groomer.isSaving = true
        await groomer.load()
        groomer.isSaving = false
        groomer.isUploading = true
        await groomer.load()
        #expect(groomerRepository.readNames.isEmpty)
        let customerRepository = CustomerProfileRepositoryFake(profileResult: .success(customerProfile(id: id, name: "Old")))
        var reads = 0
        customerRepository.onProfileRead = { reads += 1 }
        let customer = CustomerProfileStore(customerID: id, initialDisplayName: "", sessionEmail: nil, repository: customerRepository)
        customer.nickname = "Saved"
        customerRepository.onProfileUpdate = { await customer.load() }
        await customer.saveProfile()
        #expect(customerRepository.updateCallCount == 1)
        #expect(reads == 0)
        customerRepository.onProfileUpdate = nil
    }

    @Test func optionalFailureDoesNotEraseOrBlockCoreProfile() async {
        let id = UUID()
        let profile = GroomerProfileStoreTests.profile(groomerID: id)
        let repository = GroomerProfileRepositoryFake(profileResult: .success(profile), portfolioResult: .failure(.unavailable))
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        await store.load()
        #expect(store.profile == profile)
        #expect(store.savedAvailability != nil)
        #expect(!store.isLoading)
    }

    @Test func refreshPreservesAlreadyDirtyAndNewlyEditedProfileFields() async {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake(profileResult: .success(GroomerProfileStoreTests.profile(groomerID: id)))
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        await store.load()
        store.businessName = "Unsaved business name"
        await store.load()
        #expect(store.businessName == "Unsaved business name")
        repository.onServicesRead = { store.bio = "Typed while refreshing" }
        await store.load()
        #expect(store.bio == "Typed while refreshing")
    }

    @Test func unavailableFitClaimsCannotBeSavedAsAnEmptyReplacement() async {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(GroomerProfileStoreTests.profile(groomerID: id)),
            fitClaimsResult: .failure(.unavailable))
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        await store.load()
        _ = await store.saveFitClaims()
        #expect(repository.replaceFitClaimsCallCount == 0)
    }

    @Test func customerRefreshPreservesDirtyFormAndNewerSavedProfile() async {
        let id = UUID()
        let original = customerProfile(id: id, name: "Original")
        let repository = CustomerProfileRepositoryFake(profileResult: .success(original))
        let store = CustomerProfileStore(customerID: id, initialDisplayName: "", sessionEmail: nil, repository: repository)
        await store.load()
        store.nickname = "Draft"
        await store.load()
        #expect(store.nickname == "Draft")
        repository.updateProfileResult = .success(customerProfile(id: id, name: "Saved"))
        repository.onProfileRead = {
            store.nickname = "Saved"
            await store.saveProfile()
        }
        await store.load()
        #expect(store.profile?.nickname == "Saved")
        #expect(store.nickname == "Saved")
        repository.onProfileRead = nil
    }

    @Test func customerOldAvatarCannotOverwriteAnUpload() async {
        let id = UUID()
        let profile = customerProfile(id: id, name: "Original", avatar: "\(id.uuidString.lowercased())/old.jpg")
        let repository = CustomerProfileRepositoryFake(profileResult: .success(profile))
        repository.avatarResult = Data("old".utf8)
        let store = CustomerProfileStore(customerID: id, initialDisplayName: "", sessionEmail: nil, repository: repository)
        await store.load()
        let replacement = Data("new".utf8)
        repository.onAvatarRead = { await store.uploadAvatarPhoto(data: replacement, contentType: .jpeg) }
        await store.load()
        #expect(store.avatarPhotoData == replacement)
        #expect(store.profile?.avatarPath == repository.uploadedAvatarPath)
        repository.onAvatarRead = nil
    }

    @Test func cancelledCustomerLoadDoesNotPublishLateAccountData() async {
        let id = UUID()
        let repository = CustomerProfileRepositoryFake(profileResult: .success(customerProfile(id: id, name: "Cancelled")))
        var continuation: CheckedContinuation<Void, Never>?
        repository.onProfileRead = { await withCheckedContinuation { continuation = $0 } }
        let store = CustomerProfileStore(customerID: id, initialDisplayName: "", sessionEmail: nil, repository: repository)
        let load = Task { await store.load() }
        while continuation == nil { await Task.yield() }
        load.cancel()
        continuation?.resume()
        await load.value
        #expect(store.profile == nil)
        #expect(!store.isLoading)
        repository.onProfileRead = nil
    }

    private func customerProfile(id: UUID, name: String, avatar: String? = nil) -> CustomerProfileDetails {
        CustomerProfileDetails(userID: id, nickname: name, avatarPath: avatar, streetAddress: nil,
            city: nil, stateCode: nil, zipCode: nil, contactEmail: "owner@example.com", phoneNumber: nil)
    }

    @Test func newerCustomerLoadWinsEvenIfOlderReadFinishesLast() async {
        let id = UUID()
        let repository = CustomerProfileRepositoryFake(profileResult: .success(customerProfile(id: id, name: "Old")))
        var continuation: CheckedContinuation<Void, Never>?
        repository.onProfileRead = { await withCheckedContinuation { continuation = $0 } }
        let store = CustomerProfileStore(customerID: id, initialDisplayName: "", sessionEmail: nil, repository: repository)
        let oldLoad = Task { await store.load() }
        while continuation == nil { await Task.yield() }
        repository.onProfileRead = nil
        repository.profileResult = .success(customerProfile(id: id, name: "New"))
        await store.load()
        continuation?.resume()
        await oldLoad.value
        #expect(store.profile?.nickname == "New")
        #expect(store.nickname == "New")
    }

    @Test func failedRequestListStillChecksPersistedAcceptance() async throws {
        let id = UUID()
        let suite = "WP13.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set([UUID().uuidString: UUID().uuidString],
            forKey: "beckon.customerRequests.unresolvedAcceptances.\(id.uuidString)")
        let store = CustomerRequestsStore(customerID: id,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .failure(.unavailable)),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake(),
            handoffAcknowledgementDefaults: defaults)
        await store.load()
        #expect(store.errorMessage == "Your previous booking is not confirmed. Retry the same offer to check again.")
    }

    @Test func requestAndBookingCoreIsAvailableBeforePetImageDownload() async {
        let id = UUID()
        let pet = CustomerRequestsStoreTests.pet(customerID: id)
        let request = CustomerRequestsStoreTests.request(customerID: id, petID: pet.id)
        let photo = CustomerRequestsStoreTests.petPhoto(customerID: id, petID: pet.id)
        let booking = CustomerRequestsStoreTests.booking(requestID: request.id, customerID: id)
        let pets = CustomerRequestPetRepositoryFake(petsResult: .success([pet]), photosResult: .success([photo]),
            photoDataResultsByPhotoID: [photo.id: .success(Data(repeating: 1, count: 32768))])
        let requests = CustomerRequestRepositoryFake(requestsResult: .success([request]))
        let bookings = CustomerRequestBookingRepositoryFake(bookingsResult: .success([booking]))
        let store = CustomerRequestsStore(customerID: id, petRepository: pets, requestRepository: requests, bookingRepository: bookings)
        var coreAvailableBeforeImage = false
        pets.onPhotoRead = {
            coreAvailableBeforeImage = store.requests == [request] && store.bookings == [booking] && !store.isLoading
            try? await Task.sleep(for: .milliseconds(100))
        }
        let start = ContinuousClock.now
        let load = Task { await store.load() }
        while pets.photoDataCallCount == 0 { await Task.yield() }
        let coreBeforeImage = !store.isLoading
        while store.isLoading { try? await Task.sleep(for: .milliseconds(1)) }
        let observedCore = start.duration(to: .now)
        await load.value
        print("WP13_FIXED requests: coreObserved=\(observedCore), total=\(start.duration(to: .now)), coreBeforeImage=\(coreBeforeImage), requestReads=\(requests.requestsCallCount), photoReads=\(pets.photosCallCount + pets.photoDataCallCount), imageBytes=\(store.petPhotoDataByID.values.reduce(0) { $0 + $1.count })")
        #expect(coreAvailableBeforeImage)
        pets.onPhotoRead = nil
    }

    @Test func cancelledRequestLoadCannotPublishItsDelayedPage() async {
        let id = UUID()
        let request = CustomerRequestsStoreTests.request(customerID: id, petID: UUID())
        let repository = CustomerRequestRepositoryFake(requestsResult: .success([request]))
        var continuation: CheckedContinuation<Void, Never>?
        repository.onRequestPageReadAsync = { await withCheckedContinuation { continuation = $0 } }
        let store = CustomerRequestsStore(customerID: id, petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository, bookingRepository: CustomerRequestBookingRepositoryFake())
        let load = Task { await store.load() }
        while continuation == nil { await Task.yield() }
        load.cancel()
        continuation?.resume()
        await load.value
        #expect(store.requests.isEmpty)
        repository.onRequestPageReadAsync = nil
    }

    @Test func profileRefreshCannotResurrectADeletedService() async {
        let id = UUID()
        let service = GroomerProfileStoreTests.service(groomerID: id)
        let repository = GroomerProfileRepositoryFake(profileResult: .success(GroomerProfileStoreTests.profile(groomerID: id)),
            servicesResult: .success([service]))
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        await store.load()
        repository.onServicesRead = { await store.deleteService(service) }
        await store.load()
        #expect(store.services.isEmpty)
        repository.onServicesRead = nil
    }

    @Test func dirtyOptionalSelectionsSurviveRefresh() async {
        let id = UUID()
        let photo = GroomerProfileStoreTests.photo(groomerID: id)
        let repository = GroomerProfileRepositoryFake(profileResult: .success(GroomerProfileStoreTests.profile(groomerID: id)),
            portfolioResult: .success([photo]))
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        await store.load()
        let signal = PetFitSignal.coatType(.curlyWavy)
        store.toggleFitClaim(signal)
        store.togglePortfolioFitTag(signal, for: photo)
        await store.load()
        #expect(store.isFitClaimSelected(signal))
        #expect(store.isPortfolioFitTagSelected(signal, for: photo))
    }
}

@MainActor
final class CoreFirstLoadingRenderingTests: XCTestCase {
    func testUnavailableOptionalDetailsLeaveCoreUsableAndFitEditingClosed() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(GroomerProfileStoreTests.profile(groomerID: id)),
            portfolioResult: .failure(.unavailable), fitClaimsResult: .failure(.unavailable))
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        await store.load()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        for (name, view) in [
            ("Core profile", AnyView(GroomerProfileEditorView(store: store))),
            ("Unavailable fit signals", AnyView(GroomerFitSignalsEditorView(store: store)))
        ] {
            let host = UIHostingController(rootView: NavigationStack { view })
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(400))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "T-384 \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertNotNil(store.profile)
        XCTAssertFalse(store.isLoading)
        XCTAssertFalse(store.canEditFitSignals)
        XCTAssertEqual(repository.replaceFitClaimsCallCount, 0)
    }
}
