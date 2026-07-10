import Foundation
import Testing
import UIKit
@testable import Beckon

struct GroomerPortfolioPhotoPathTests {
    @Test
    func storagePathMatchesBackendContractAndUsesLowercaseUUIDs() {
        let groomerID = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
        let fileID = UUID(uuidString: "99999999-AAAA-4BBB-8CCC-DDDDDDDDDDDD")!

        let path = GroomerPortfolioPhotoPath.make(
            groomerID: groomerID,
            fileID: fileID,
            contentType: .png
        )

        #expect(
            path ==
                "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/99999999-aaaa-4bbb-8ccc-dddddddddddd.png"
        )
    }
}

struct GroomerProfileStorageBucketTests {
    @Test
    func photoBucketsAreSeparateForCustomerAvatarGroomerAvatarPortfolioPetAndRequestPhotos() {
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

struct GroomerAvatarImageEncoderTests {
    @Test @MainActor
    func displayablePayloadKeepsDisplayablePNGWhenPreferred() throws {
        let sourceData = try Self.solidPNGData()

        let payload = try #require(
            GroomerAvatarImageEncoder.displayablePayload(
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
            GroomerAvatarImageEncoder.displayablePayload(
                from: sourceData,
                preferredContentType: .heic
            )
        )

        #expect(payload.contentType == .jpeg)
        #expect(UIImage(data: payload.data) != nil)
    }

    @Test @MainActor
    func displayablePayloadRejectsInvalidPhotoData() {
        #expect(
            GroomerAvatarImageEncoder.displayablePayload(
                from: Data([0x01, 0x02, 0x03]),
                preferredContentType: .jpeg
            ) == nil
        )
    }

    @MainActor
    private static func solidPNGData() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        return try #require(image.pngData())
    }
}

struct BeckonModuleImageLayoutTests {
    @Test
    func filledFrameCentersImagesAndPinsTheRequiredEdges() {
        let containerSize = CGSize(width: 120, height: 120)

        #expect(
            BeckonModuleImageLayout.filledFrame(
                imageSize: CGSize(width: 100, height: 400),
                in: containerSize
            ) == CGRect(x: 0, y: -180, width: 120, height: 480)
        )
        #expect(
            BeckonModuleImageLayout.filledFrame(
                imageSize: CGSize(width: 400, height: 100),
                in: containerSize
            ) == CGRect(x: -180, y: 0, width: 480, height: 120)
        )
        #expect(
            BeckonModuleImageLayout.filledFrame(
                imageSize: CGSize(width: 200, height: 200),
                in: containerSize
            ) == CGRect(x: 0, y: 0, width: 120, height: 120)
        )
        #expect(
            BeckonModuleImageLayout.filledFrame(
                imageSize: .zero,
                in: containerSize
            ) == .zero
        )
    }
}

struct GroomerProfileStoreTests {
    @Test @MainActor
    func loadPopulatesProfileServicesAndPortfolio() async {
        let groomerID = UUID()
        let profile = Self.profile(groomerID: groomerID)
        let service = Self.service(groomerID: groomerID)
        let photo = Self.photo(groomerID: groomerID)
        let availability = Self.availability(groomerID: groomerID)
        let preferences = Self.bookingPreferences(groomerID: groomerID)
        let timeOff = Self.timeOff(groomerID: groomerID)
        let fitClaim = Self.fitClaim(
            groomerID: groomerID,
            signal: .serviceFit(.gentleHandling),
            isActive: true
        )
        let portfolioTag = Self.portfolioFitTag(
            photoID: photo.id,
            groomerID: groomerID,
            signal: .serviceFit(.curlyCoat)
        )
        let evidenceSummary = Self.evidenceSummary(
            groomerID: groomerID,
            signal: .breedGroup(.poodle),
            completedBookingCount: 3,
            positiveReviewOutcomeCount: 2,
            negativeReviewOutcomeCount: 0,
            structuredReviewOutcomeCount: 2,
            confidenceTier: .medium
        )
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(profile),
            servicesResult: .success([service]),
            portfolioResult: .success([photo]),
            portfolioFitTagsResult: .success([portfolioTag]),
            availabilityResult: .success([availability]),
            bookingPreferencesResult: .success(preferences),
            timeOffResult: .success([timeOff]),
            fitClaimsResult: .success([fitClaim]),
            petFitEvidenceSummaryResult: .success([evidenceSummary])
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(store.profile == profile)
        #expect(store.services == [service])
        #expect(store.portfolioPhotos == [photo])
        #expect(store.availabilityWindows == [availability])
        #expect(store.bookingPreferences == preferences)
        #expect(store.timeOffWindows == [timeOff])
        #expect(store.fitClaims == [fitClaim])
        #expect(store.selectedFitClaimIDs == [fitClaim.signal.id])
        #expect(store.petFitEvidenceSummary == [evidenceSummary])
        #expect(store.portfolioFitTags == [portfolioTag])
        #expect(
            store.selectedPortfolioFitTagIDsByPhotoID[photo.id] == [
                portfolioTag.signal.id,
            ]
        )
        #expect(store.businessName == "Fresh Coat")
        #expect(store.isActive)
        #expect(store.maxAppointmentsPerDay == 4)
        #expect(store.minimumAdvanceNoticeDays == 1)
        #expect(store.autoAcceptBookings)
    }

    @Test @MainActor
    func loadDoesNotBlockProfileFormOnPortfolioImageDownloads() async {
        let groomerID = UUID()
        let profile = Self.profile(groomerID: groomerID)
        let photo = Self.photo(groomerID: groomerID)
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(profile),
            portfolioResult: .success([photo])
        )
        repository.shouldSuspendPortfolioPhotoData = true
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        let loadTask = Task {
            await store.load()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(store.businessName == "Fresh Coat")
        #expect(store.baseStreetAddress == "123 Pine Street")
        #expect(store.baseCity == "Seattle")
        #expect(store.baseStateCode == .washington)
        #expect(store.baseZipCode == "98101")
        #expect(store.isLoading == false)
        #expect(store.isBusy == false)

        loadTask.cancel()
        await loadTask.value
    }

    @Test @MainActor
    func loadRestoresAvatarBeforeSlowPortfolioPhotoHydrationCompletes() async {
        let groomerID = UUID()
        let avatarPath = "\(groomerID.uuidString.lowercased())/avatar.jpg"
        var profile = Self.profile(groomerID: groomerID)
        profile.avatarPath = avatarPath
        let photo = Self.photo(groomerID: groomerID)
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(profile),
            portfolioResult: .success([photo])
        )
        repository.shouldSuspendPortfolioPhotoData = true
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        let loadTask = Task {
            await store.load()
        }
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(store.profile?.avatarPath == avatarPath)
        #expect(store.avatarPhotoData == Data("avatar:\(avatarPath)".utf8))

        loadTask.cancel()
        await loadTask.value
    }

    @Test @MainActor
    func loadUsesLocalSnapshotWhileRemoteProfileDetailsAreStillLoading() async {
        let groomerID = UUID()
        let cachedAvatarData = Data("cached-avatar".utf8)
        let cache = GroomerProfileSnapshotCacheFake(
            snapshot: ProfileSnapshot(
                userID: groomerID,
                displayName: "Cached Groomer",
                detailText: "Cached profile",
                avatarData: cachedAvatarData
            )
        )
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(Self.profile(groomerID: groomerID))
        )
        repository.shouldSuspendAvailability = true
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository,
            profileSnapshotCache: cache
        )

        let loadTask = Task {
            await store.load()
        }
        await repository.waitForSuspendedAvailability()

        #expect(store.profileDisplayName == "Cached Groomer")
        #expect(store.avatarPhotoData == cachedAvatarData)
        #expect(store.isLoading)

        repository.resumeSuspendedAvailability()
        await loadTask.value
    }

    @Test @MainActor
    func loadKeepsLocalAvatarWhenCloudAvatarDownloadFails() async {
        let groomerID = UUID()
        let cachedAvatarData = Data("cached-avatar".utf8)
        let cache = GroomerProfileSnapshotCacheFake(
            snapshot: ProfileSnapshot(
                userID: groomerID,
                displayName: "Cached Groomer",
                detailText: "Cached profile",
                avatarData: cachedAvatarData
            )
        )
        var profile = Self.profile(groomerID: groomerID)
        profile.avatarPath = "\(groomerID.uuidString.lowercased())/avatar.jpg"
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(profile),
            avatarPhotoDataResult: .failure(.networkUnavailable)
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository,
            profileSnapshotCache: cache
        )

        await store.load()

        #expect(store.profileDisplayName == "Fresh Coat")
        #expect(store.avatarPhotoData == cachedAvatarData)
        #expect(cache.savedSnapshot?.displayName == "Fresh Coat")
        #expect(cache.savedSnapshot?.avatarData == cachedAvatarData)
    }

    @Test @MainActor
    func loadUsesLatestAvatarObjectWhenProfileAvatarPathIsMissing() async {
        let groomerID = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
        let fallbackPath =
            "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/latest-avatar.jpg"
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(Self.profile(groomerID: groomerID)),
            latestAvatarPathResult: .success(fallbackPath)
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(repository.latestAvatarPathCallCount == 1)
        #expect(repository.lastAvatarPhotoDataPath == fallbackPath)
        #expect(store.profile?.avatarPath == fallbackPath)
        #expect(store.avatarPhotoData == Data("avatar:\(fallbackPath)".utf8))
    }

    @Test @MainActor
    func loadPrefersLatestAvatarObjectWhenProfileAvatarPathIsStale() async {
        let groomerID = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
        let latestPath =
            "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/latest-avatar.jpg"
        var profile = Self.profile(groomerID: groomerID)
        profile.avatarPath =
            "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/old-avatar.jpg"
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(profile),
            latestAvatarPathResult: .success(latestPath)
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(repository.latestAvatarPathCallCount == 1)
        #expect(repository.lastAvatarPhotoDataPath == latestPath)
        #expect(store.profile?.avatarPath == latestPath)
        #expect(store.avatarPhotoData == Data("avatar:\(latestPath)".utf8))
    }

    @Test @MainActor
    func backgroundLoadDoesNotDisableLoadedProfileEditing() async {
        let groomerID = UUID()
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(Self.profile(groomerID: groomerID))
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        repository.shouldSuspendAvailability = true
        let loadTask = Task {
            await store.load()
        }
        await repository.waitForSuspendedAvailability()

        #expect(store.isLoading)
        #expect(store.isBusy == false)

        repository.resumeSuspendedAvailability()
        await loadTask.value
    }

    @Test @MainActor
    func inFlightLoadDoesNotOverwriteSavedProfileForm() async {
        let groomerID = UUID()
        let staleProfile = Self.profile(groomerID: groomerID)
        let savedProfile = GroomerProfile(
            userID: groomerID,
            businessName: "Updated Coat",
            bio: "Updated grooming",
            yearsExperience: 4,
            baseStreetAddress: "987 Cedar Avenue",
            baseCity: "Portland",
            baseState: "OR",
            baseZipCode: "97201",
            serviceRadiusMiles: 24,
            serviceLocationMode: .customerComesToGroomer,
            serviceLocationModes: [.customerComesToGroomer],
            ratingAverage: 0,
            ratingCount: 0,
            isActive: true,
            isVerified: false
        )
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(staleProfile),
            updateProfileResult: .success(savedProfile)
        )
        repository.shouldSuspendAvailability = true
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        let loadTask = Task {
            await store.load()
        }
        await repository.waitForSuspendedAvailability()

        store.businessName = "Updated Coat"
        store.bio = "Updated grooming"
        store.yearsExperience = 4
        store.baseStreetAddress = "987 Cedar Avenue"
        store.baseCity = "Portland"
        store.baseStateCode = .oregon
        store.baseZipCode = "97201"
        store.serviceRadiusMiles = 24
        store.serviceLocationModes = [.customerComesToGroomer]
        store.isActive = true
        await store.saveProfile()

        repository.resumeSuspendedAvailability()
        await loadTask.value

        #expect(store.profile == savedProfile)
        #expect(store.businessName == "Updated Coat")
        #expect(store.baseStreetAddress == "987 Cedar Avenue")
        #expect(store.baseCity == "Portland")
        #expect(store.baseStateCode == .oregon)
        #expect(store.baseZipCode == "97201")
        #expect(store.serviceRadiusMiles == 24)
        #expect(store.serviceLocationModes == [.customerComesToGroomer])
    }

    static func profile(groomerID: UUID) -> GroomerProfile {
        GroomerProfile(
            userID: groomerID,
            businessName: "Fresh Coat",
            bio: "Calm grooming",
            yearsExperience: 6,
            baseStreetAddress: "123 Pine Street",
            baseCity: "Seattle",
            baseState: "WA",
            baseZipCode: "98101",
            serviceRadiusMiles: 12,
            serviceLocationMode: .groomerComesToCustomer,
            serviceLocationModes: [.groomerComesToCustomer],
            ratingAverage: 0,
            ratingCount: 0,
            isActive: true,
            isVerified: false
        )
    }

    static func service(groomerID: UUID) -> GroomerService {
        GroomerService(
            id: UUID(),
            groomerID: groomerID,
            serviceType: .bathAndBrush,
            title: "Bath",
            description: nil,
            basePrice: 45,
            durationMinutes: 60,
            acceptedPetSizes: [.xs],
            isActive: true
        )
    }

    static func photo(groomerID: UUID) -> GroomerPortfolioPhoto {
        GroomerPortfolioPhoto(
            id: UUID(),
            groomerID: groomerID,
            storageBucket: "groomer-portfolio",
            storagePath: GroomerPortfolioPhotoPath.make(
                groomerID: groomerID,
                contentType: .jpeg
            ),
            caption: nil,
            sortOrder: 0
        )
    }

    static func availability(groomerID: UUID) -> GroomerAvailabilityWindow {
        GroomerAvailabilityWindow(
            id: UUID(),
            groomerID: groomerID,
            weekday: .monday,
            startMinutes: 9 * 60,
            endMinutes: 17 * 60,
            isEnabled: true,
            timezone: "America/Los_Angeles"
        )
    }

    static func bookingPreferences(groomerID: UUID) -> GroomerBookingPreferences {
        GroomerBookingPreferences(
            groomerID: groomerID,
            maxAppointmentsPerDay: 4,
            minimumAdvanceNoticeDays: 1,
            autoAcceptBookings: true
        )
    }

    static func timeOff(groomerID: UUID) -> GroomerTimeOffWindow {
        GroomerTimeOffWindow(
            id: UUID(),
            groomerID: groomerID,
            title: "Long weekend away",
            startDate: "2026-07-04",
            endDate: "2026-07-06"
        )
    }

    static func fitClaim(
        groomerID: UUID,
        signal: PetFitSignal,
        isActive: Bool
    ) -> GroomerFitClaim {
        GroomerFitClaim(
            id: UUID(),
            groomerID: groomerID,
            signal: signal,
            isActive: isActive
        )
    }

    static func portfolioFitTag(
        photoID: UUID,
        groomerID: UUID,
        signal: PetFitSignal
    ) -> GroomerPortfolioFitTag {
        GroomerPortfolioFitTag(
            id: UUID(),
            portfolioPhotoID: photoID,
            groomerID: groomerID,
            signal: signal
        )
    }

    static func evidenceSummary(
        groomerID: UUID,
        signal: PetFitSignal,
        completedBookingCount: Int,
        positiveReviewOutcomeCount: Int = 0,
        negativeReviewOutcomeCount: Int = 0,
        structuredReviewOutcomeCount: Int = 0,
        confidenceTier: GroomerPetFitEvidenceConfidenceTier
    ) -> GroomerPetFitEvidenceSummary {
        GroomerPetFitEvidenceSummary(
            groomerID: groomerID,
            signal: signal,
            completedBookingCount: completedBookingCount,
            positiveReviewOutcomeCount: positiveReviewOutcomeCount,
            negativeReviewOutcomeCount: negativeReviewOutcomeCount,
            structuredReviewOutcomeCount: structuredReviewOutcomeCount,
            lastCompletedAt: nil,
            lastReviewOutcomeAt: nil,
            evidenceUpdatedAt: nil,
            confidenceTier: confidenceTier
        )
    }

    static func date(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = .current
        components.year = year
        components.month = month
        components.day = day
        return components.date!
    }
}
