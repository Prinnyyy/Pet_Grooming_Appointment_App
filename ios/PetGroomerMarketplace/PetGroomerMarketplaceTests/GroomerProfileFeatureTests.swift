import Foundation
import Testing
@testable import PetGroomerMarketplace

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
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(profile),
            servicesResult: .success([service]),
            portfolioResult: .success([photo]),
            portfolioFitTagsResult: .success([portfolioTag]),
            availabilityResult: .success([availability]),
            bookingPreferencesResult: .success(preferences),
            timeOffResult: .success([timeOff]),
            fitClaimsResult: .success([fitClaim])
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
    func saveFitClaimsPersistsActiveAndInactiveSupportedSignals() async {
        let groomerID = UUID()
        let gentleHandling = Self.fitClaim(
            groomerID: groomerID,
            signal: .serviceFit(.gentleHandling),
            isActive: true
        )
        let senior = Self.fitClaim(
            groomerID: groomerID,
            signal: .careFlag(.senior),
            isActive: true
        )
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(Self.profile(groomerID: groomerID)),
            fitClaimsResult: .success([gentleHandling, senior])
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        store.toggleFitClaim(.serviceFit(.gentleHandling))
        store.toggleFitClaim(.breedGroup(.poodle))
        await store.saveFitClaims()

        #expect(repository.replaceFitClaimsCallCount == 1)
        #expect(repository.lastFitClaimDrafts == [
            GroomerFitClaimDraft(
                signal: .breedGroup(.poodle),
                isActive: true
            ),
            GroomerFitClaimDraft(
                signal: .careFlag(.senior),
                isActive: true
            ),
            GroomerFitClaimDraft(
                signal: .serviceFit(.gentleHandling),
                isActive: false
            )
        ])
        #expect(store.selectedFitClaimIDs == [
            PetFitSignal.breedGroup(.poodle).id,
            PetFitSignal.careFlag(.senior).id
        ])
        #expect(store.noticeMessage == "Fit signals saved.")
    }

    @Test @MainActor
    func fitClaimSelectionIsBoundedBeforeRepositoryCall() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: repository
        )
        let signals = Array(
            GroomerFitClaim.availableSignals.prefix(
                GroomerFitClaim.maximumActiveClaims + 1
            )
        )

        for signal in signals {
            store.toggleFitClaim(signal)
        }

        #expect(store.selectedFitClaimIDs.count == GroomerFitClaim.maximumActiveClaims)
        #expect(repository.replaceFitClaimsCallCount == 0)
        #expect(
            store.errorMessage ==
                "Choose up to \(GroomerFitClaim.maximumActiveClaims) starter fit signals."
        )
    }

    @Test @MainActor
    func savePortfolioFitTagsPersistsOnePhotoSelection() async {
        let groomerID = UUID()
        let photo = Self.photo(groomerID: groomerID)
        let gentleHandling = Self.portfolioFitTag(
            photoID: photo.id,
            groomerID: groomerID,
            signal: .serviceFit(.gentleHandling)
        )
        let senior = Self.portfolioFitTag(
            photoID: photo.id,
            groomerID: groomerID,
            signal: .careFlag(.senior)
        )
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(Self.profile(groomerID: groomerID)),
            portfolioResult: .success([photo]),
            portfolioFitTagsResult: .success([gentleHandling, senior])
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        store.togglePortfolioFitTag(.serviceFit(.gentleHandling), for: photo)
        store.togglePortfolioFitTag(.breedGroup(.poodle), for: photo)
        await store.savePortfolioFitTags(for: photo)

        #expect(repository.replacePortfolioFitTagsCallCount == 1)
        #expect(repository.lastPortfolioFitTagPhotoID == photo.id)
        #expect(repository.lastPortfolioFitTagDrafts == [
            GroomerPortfolioFitTagDraft(signal: .breedGroup(.poodle)),
            GroomerPortfolioFitTagDraft(signal: .careFlag(.senior)),
        ])
        #expect(
            store.selectedPortfolioFitTagIDsByPhotoID[photo.id] == [
                PetFitSignal.breedGroup(.poodle).id,
                PetFitSignal.careFlag(.senior).id,
            ]
        )
        #expect(store.noticeMessage == "Portfolio tags saved.")
    }

    @Test @MainActor
    func portfolioFitTagSelectionIsBoundedBeforeRepositoryCall() async {
        let repository = GroomerProfileRepositoryFake()
        let photo = Self.photo(groomerID: UUID())
        let store = GroomerProfileStore(
            groomerID: photo.groomerID,
            repository: repository
        )
        let signals = Array(
            GroomerPortfolioFitTag.availableSignals.prefix(
                GroomerPortfolioFitTag.maximumTagsPerPhoto + 1
            )
        )

        for signal in signals {
            store.togglePortfolioFitTag(signal, for: photo)
        }

        #expect(
            store.selectedPortfolioFitTagIDsByPhotoID[photo.id]?.count ==
                GroomerPortfolioFitTag.maximumTagsPerPhoto
        )
        #expect(repository.replacePortfolioFitTagsCallCount == 0)
        #expect(
            store.errorMessage ==
                "Choose up to \(GroomerPortfolioFitTag.maximumTagsPerPhoto) tags for each portfolio photo."
        )
    }

    @Test @MainActor
    func deletePortfolioPhotoClearsLocalFitTagsAfterRepositoryDelete() async throws {
        let groomerID = UUID()
        let photo = Self.photo(groomerID: groomerID)
        let tag = Self.portfolioFitTag(
            photoID: photo.id,
            groomerID: groomerID,
            signal: .serviceFit(.curlyCoat)
        )
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(Self.profile(groomerID: groomerID)),
            portfolioResult: .success([photo]),
            portfolioFitTagsResult: .success([tag])
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.deletePortfolioPhoto(photo)

        #expect(repository.deletePhotoCallCount == 1)
        #expect(store.portfolioPhotos.isEmpty)
        #expect(store.portfolioFitTags.isEmpty)
        #expect(store.selectedPortfolioFitTagIDsByPhotoID[photo.id] == nil)
    }

    @Test @MainActor
    func saveAvailabilityPersistsProfileWeeklyHoursAndBookingPreferences() async {
        let groomerID = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        store.isActive = true
        store.businessName = "Fresh Coat"
        store.baseStreetAddress = "123 Pine Street"
        store.baseCity = "Seattle"
        store.baseStateCode = .washington
        store.baseZipCode = "98101"
        store.serviceRadiusMiles = 12
        store.serviceLocationModes = [.groomerComesToCustomer]
        store.maxAppointmentsPerDay = 6
        store.minimumAdvanceNoticeDays = 2
        store.autoAcceptBookings = true
        store.setAvailability(
            day: .friday,
            isEnabled: true,
            startMinutes: 13 * 60,
            endMinutes: 17 * 60
        )
        store.setAvailability(
            day: .monday,
            isEnabled: true,
            startMinutes: 9 * 60,
            endMinutes: 12 * 60
        )

        await store.saveAvailability()

        #expect(repository.updateProfileCallCount == 1)
        #expect(repository.replaceAvailabilityCallCount == 1)
        #expect(repository.updateBookingPreferencesCallCount == 1)
        #expect(repository.lastProfileDraft?.isActive == true)
        #expect(repository.lastAvailabilityDrafts.map(\.weekday) == GroomerAvailabilityWeekday.allCases)
        #expect(repository.lastBookingPreferencesDraft?.maxAppointmentsPerDay == 6)
        #expect(repository.lastBookingPreferencesDraft?.minimumAdvanceNoticeDays == 2)
        #expect(repository.lastBookingPreferencesDraft?.autoAcceptBookings == true)

        let enabledDrafts = repository.lastAvailabilityDrafts.filter(\.isEnabled)
        #expect(enabledDrafts.map(\.weekday) == [.monday, .friday])
        #expect(enabledDrafts.map(\.startMinutes) == [540, 780])
        #expect(enabledDrafts.map(\.endMinutes) == [720, 1020])
        #expect(store.noticeMessage == "Availability saved.")
    }

    @Test @MainActor
    func invalidAvailabilityWindowDoesNotCallRepository() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: repository
        )
        store.setAvailability(
            day: .tuesday,
            isEnabled: true,
            startMinutes: 14 * 60,
            endMinutes: 14 * 60
        )

        await store.saveAvailability()

        #expect(repository.updateProfileCallCount == 0)
        #expect(repository.replaceAvailabilityCallCount == 0)
        #expect(repository.updateBookingPreferencesCallCount == 0)
        #expect(store.errorMessage == "Tuesday availability needs an end time after the start time.")
    }

    @Test @MainActor
    func createAndDeleteTimeOffValidateAndUpdateLocalState() async throws {
        let groomerID = UUID()
        let timeOff = Self.timeOff(groomerID: groomerID)
        let repository = GroomerProfileRepositoryFake(
            createTimeOffResult: .success(timeOff)
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        store.timeOffTitle = " Long weekend away "
        store.timeOffStartDate = Self.date(year: 2026, month: 7, day: 4)
        store.timeOffEndDate = Self.date(year: 2026, month: 7, day: 6)

        await store.createTimeOff()

        #expect(repository.createTimeOffCallCount == 1)
        #expect(repository.lastTimeOffDraft?.title == "Long weekend away")
        #expect(repository.lastTimeOffDraft?.startDate == "2026-07-04")
        #expect(repository.lastTimeOffDraft?.endDate == "2026-07-06")
        #expect(store.timeOffWindows == [timeOff])

        let created = try #require(store.timeOffWindows.first)
        await store.deleteTimeOff(created)

        #expect(repository.deleteTimeOffCallCount == 1)
        #expect(store.timeOffWindows.isEmpty)
    }

    @Test @MainActor
    func activeProfileRequiresMarketplaceFieldsBeforeRepositoryCall() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: repository
        )
        store.isActive = true
        store.businessName = "Fresh Coat"
        store.baseCity = "Seattle"
        store.baseStateCode = .washington
        store.baseZipCode = "98101"
        store.serviceLocationModes = [.groomerComesToCustomer]

        await store.saveProfile()

        #expect(repository.updateProfileCallCount == 0)
        #expect(
            store.errorMessage ==
                "Complete business name, address, city, state, ZIP, and service radius before going active."
        )
    }

    @Test @MainActor
    func activeProfileRequiresServiceLocationModeBeforeRepositoryCall() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: repository
        )
        store.isActive = true
        store.businessName = "Fresh Coat"
        store.baseStreetAddress = "123 Pine Street"
        store.baseCity = "Seattle"
        store.baseStateCode = .washington
        store.baseZipCode = "98101"
        store.serviceRadiusMiles = 12

        await store.saveProfile()

        #expect(repository.updateProfileCallCount == 0)
        #expect(
            store.errorMessage ==
                "Choose whether you travel to customers or host appointments before going active."
        )
    }

    @Test @MainActor
    func saveProfileSendsFullAddressFixedExperienceRadiusAndMultipleLocationModes() async {
        let groomerID = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        store.businessName = " Fresh Coat "
        store.bio = " Calm grooming "
        store.yearsExperience = 5
        store.baseStreetAddress = " 123 Pine Street "
        store.baseCity = " Seattle "
        store.baseStateCode = .washington
        store.baseZipCode = " 98101 "
        store.serviceRadiusMiles = 50
        store.serviceLocationModes = [.customerComesToGroomer, .groomerComesToCustomer]
        store.isActive = true

        await store.saveProfile()

        #expect(repository.updateProfileCallCount == 1)
        #expect(repository.lastProfileDraft?.businessName == "Fresh Coat")
        #expect(repository.lastProfileDraft?.bio == "Calm grooming")
        #expect(repository.lastProfileDraft?.yearsExperience == 5)
        #expect(repository.lastProfileDraft?.baseStreetAddress == "123 Pine Street")
        #expect(repository.lastProfileDraft?.baseCity == "Seattle")
        #expect(repository.lastProfileDraft?.baseStateCode == .washington)
        #expect(repository.lastProfileDraft?.baseZipCode == "98101")
        #expect(repository.lastProfileDraft?.serviceRadiusMiles == 50)
        #expect(
            repository.lastProfileDraft?.serviceLocationModes ==
                [.customerComesToGroomer, .groomerComesToCustomer]
        )
        #expect(repository.lastProfileDraft?.serviceLocationMode == .groomerComesToCustomer)
        #expect(repository.lastProfileDraft?.isActive == true)
    }

    @Test @MainActor
    func oversizedAvatarUploadDoesNotCallRepository() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: repository
        )

        await store.uploadAvatarPhoto(
            data: Data(count: GroomerProfileStore.maximumPhotoBytes + 1),
            contentType: .jpeg
        )

        #expect(repository.uploadAvatarCallCount == 0)
        #expect(store.errorMessage == "Choose an avatar photo smaller than 10 MB.")
    }

    @Test @MainActor
    func successfulAvatarUploadUpdatesLocalProfilePath() async {
        let groomerID = UUID()
        let profile = Self.profile(groomerID: groomerID)
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(profile),
            uploadAvatarResult: .success("avatar-path.jpg")
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        let avatarData = Data([0x01, 0x02])
        await store.uploadAvatarPhoto(data: avatarData, contentType: .jpeg)

        #expect(repository.uploadAvatarCallCount == 1)
        #expect(store.profile?.avatarPath == "avatar-path.jpg")
        #expect(store.avatarPhotoData == avatarData)
        #expect(store.noticeMessage == "Profile photo was updated.")
    }

    @Test @MainActor
    func createServiceUsesFixedServiceTypeKeepsCanonicalPetSizeOrderAndUsesEmptyAsAllSizes() async {
        let groomerID = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        store.serviceType = .bathAndBrush
        store.serviceDescription = " Shampoo "
        store.serviceBasePrice = "45.50"
        store.serviceDurationMinutes = "60"
        store.selectedServiceSizes = [.giant, .small]

        await store.saveService()

        #expect(repository.createServiceCallCount == 1)
        #expect(repository.lastServiceDraft?.serviceType == .bathAndBrush)
        #expect(repository.lastServiceDraft?.title == "Bath & Brush")
        #expect(repository.lastServiceDraft?.description == "Shampoo")
        #expect(repository.lastServiceDraft?.basePrice == 45.50)
        #expect(repository.lastServiceDraft?.durationMinutes == 60)
        #expect(repository.lastServiceDraft?.acceptedPetSizes == [.small, .giant])

        store.startCreateService()
        store.serviceType = .nailTrim
        store.serviceBasePrice = "20"
        store.serviceDurationMinutes = "30"
        store.selectedServiceSizes = []

        await store.saveService()

        #expect(repository.lastServiceDraft?.acceptedPetSizes == [])
        #expect(
            store.services.first?.acceptedPetSizeSummary == "All pet sizes"
        )
    }

    @Test @MainActor
    func invalidServiceFormDoesNotCallRepository() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: repository
        )
        store.serviceTitle = "Bath"
        store.serviceBasePrice = "45.999"
        store.serviceDurationMinutes = "60"

        await store.saveService()

        #expect(repository.createServiceCallCount == 0)
        #expect(store.errorMessage == "Base price can use at most 2 decimal places.")
    }

    @Test @MainActor
    func oversizedPortfolioUploadDoesNotCallRepository() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: repository
        )

        await store.uploadPortfolioPhoto(
            data: Data(count: GroomerProfileStore.maximumPhotoBytes + 1),
            contentType: .jpeg
        )

        #expect(repository.uploadCallCount == 0)
        #expect(store.errorMessage == "Choose a portfolio photo smaller than 10 MB.")
    }

    @Test @MainActor
    func successfulPortfolioUploadAndDeleteUpdateLocalState() async throws {
        let groomerID = UUID()
        let repository = GroomerProfileRepositoryFake(
            uploadResult: .success(Self.photo(groomerID: groomerID))
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.uploadPortfolioPhoto(
            data: Data([0x01, 0x02]),
            contentType: .heic
        )

        #expect(repository.uploadCallCount == 1)
        #expect(store.portfolioPhotos.count == 1)

        let photo = try #require(store.portfolioPhotos.first)
        await store.deletePortfolioPhoto(photo)

        #expect(repository.deletePhotoCallCount == 1)
        #expect(store.portfolioPhotos.isEmpty)
    }

    private static func profile(groomerID: UUID) -> GroomerProfile {
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

    private static func service(groomerID: UUID) -> GroomerService {
        GroomerService(
            id: UUID(),
            groomerID: groomerID,
            serviceType: .bathAndBrush,
            title: "Bath",
            description: nil,
            basePrice: 45,
            durationMinutes: 60,
            acceptedPetSizes: [.small],
            isActive: true
        )
    }

    private static func photo(groomerID: UUID) -> GroomerPortfolioPhoto {
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

    private static func availability(groomerID: UUID) -> GroomerAvailabilityWindow {
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

    private static func bookingPreferences(groomerID: UUID) -> GroomerBookingPreferences {
        GroomerBookingPreferences(
            groomerID: groomerID,
            maxAppointmentsPerDay: 4,
            minimumAdvanceNoticeDays: 1,
            autoAcceptBookings: true
        )
    }

    private static func timeOff(groomerID: UUID) -> GroomerTimeOffWindow {
        GroomerTimeOffWindow(
            id: UUID(),
            groomerID: groomerID,
            title: "Long weekend away",
            startDate: "2026-07-04",
            endDate: "2026-07-06"
        )
    }

    private static func fitClaim(
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

    private static func portfolioFitTag(
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

    private static func date(year: Int, month: Int, day: Int) -> Date {
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

@MainActor
private final class GroomerProfileRepositoryFake: GroomerProfileRepository {
    var profileResult: Result<GroomerProfile, GroomerProfileRepositoryError>
    var servicesResult: Result<[GroomerService], GroomerProfileRepositoryError>
    var portfolioResult: Result<[GroomerPortfolioPhoto], GroomerProfileRepositoryError>
    var portfolioFitTagsResult: Result<[GroomerPortfolioFitTag], GroomerProfileRepositoryError>
    var availabilityResult: Result<[GroomerAvailabilityWindow], GroomerProfileRepositoryError>
    var bookingPreferencesResult: Result<GroomerBookingPreferences, GroomerProfileRepositoryError>
    var timeOffResult: Result<[GroomerTimeOffWindow], GroomerProfileRepositoryError>
    var fitClaimsResult: Result<[GroomerFitClaim], GroomerProfileRepositoryError>
    var updateProfileResult: Result<GroomerProfile, GroomerProfileRepositoryError>?
    var updateBookingPreferencesResult: Result<GroomerBookingPreferences, GroomerProfileRepositoryError>?
    var replaceFitClaimsResult: Result<[GroomerFitClaim], GroomerProfileRepositoryError>?
    var replacePortfolioFitTagsResult: Result<[GroomerPortfolioFitTag], GroomerProfileRepositoryError>?
    var createServiceResult: Result<GroomerService, GroomerProfileRepositoryError>?
    var updateServiceResult: Result<GroomerService, GroomerProfileRepositoryError>?
    var deleteServiceResult: Result<Void, GroomerProfileRepositoryError>
    var uploadResult: Result<GroomerPortfolioPhoto, GroomerProfileRepositoryError>
    var uploadAvatarResult: Result<String, GroomerProfileRepositoryError>
    var deletePhotoResult: Result<Void, GroomerProfileRepositoryError>
    var replaceAvailabilityResult: Result<[GroomerAvailabilityWindow], GroomerProfileRepositoryError>?
    var createTimeOffResult: Result<GroomerTimeOffWindow, GroomerProfileRepositoryError>?
    var deleteTimeOffResult: Result<Void, GroomerProfileRepositoryError>

    private(set) var updateProfileCallCount = 0
    private(set) var updateBookingPreferencesCallCount = 0
    private(set) var createServiceCallCount = 0
    private(set) var updateServiceCallCount = 0
    private(set) var deleteServiceCallCount = 0
    private(set) var uploadCallCount = 0
    private(set) var uploadAvatarCallCount = 0
    private(set) var deletePhotoCallCount = 0
    private(set) var replaceAvailabilityCallCount = 0
    private(set) var createTimeOffCallCount = 0
    private(set) var deleteTimeOffCallCount = 0
    private(set) var replaceFitClaimsCallCount = 0
    private(set) var replacePortfolioFitTagsCallCount = 0
    private(set) var lastProfileDraft: GroomerProfileDraft?
    private(set) var lastBookingPreferencesDraft: GroomerBookingPreferencesDraft?
    private(set) var lastServiceDraft: GroomerServiceDraft?
    private(set) var lastAvailabilityDrafts: [GroomerAvailabilityDraft] = []
    private(set) var lastTimeOffDraft: GroomerTimeOffDraft?
    private(set) var lastFitClaimDrafts: [GroomerFitClaimDraft] = []
    private(set) var lastPortfolioFitTagPhotoID: UUID?
    private(set) var lastPortfolioFitTagDrafts: [GroomerPortfolioFitTagDraft] = []

    init(
        profileResult: Result<GroomerProfile, GroomerProfileRepositoryError> =
            .failure(.unavailable),
        servicesResult: Result<[GroomerService], GroomerProfileRepositoryError> =
            .success([]),
        portfolioResult: Result<[GroomerPortfolioPhoto], GroomerProfileRepositoryError> =
            .success([]),
        portfolioFitTagsResult: Result<[GroomerPortfolioFitTag], GroomerProfileRepositoryError> =
            .success([]),
        availabilityResult: Result<[GroomerAvailabilityWindow], GroomerProfileRepositoryError> =
            .success([]),
        bookingPreferencesResult: Result<GroomerBookingPreferences, GroomerProfileRepositoryError> =
            .success(.default(groomerID: UUID())),
        timeOffResult: Result<[GroomerTimeOffWindow], GroomerProfileRepositoryError> =
            .success([]),
        fitClaimsResult: Result<[GroomerFitClaim], GroomerProfileRepositoryError> =
            .success([]),
        updateProfileResult: Result<GroomerProfile, GroomerProfileRepositoryError>? = nil,
        updateBookingPreferencesResult: Result<GroomerBookingPreferences, GroomerProfileRepositoryError>? = nil,
        replaceFitClaimsResult: Result<[GroomerFitClaim], GroomerProfileRepositoryError>? = nil,
        replacePortfolioFitTagsResult: Result<[GroomerPortfolioFitTag], GroomerProfileRepositoryError>? = nil,
        createServiceResult: Result<GroomerService, GroomerProfileRepositoryError>? = nil,
        updateServiceResult: Result<GroomerService, GroomerProfileRepositoryError>? = nil,
        deleteServiceResult: Result<Void, GroomerProfileRepositoryError> =
            .success(()),
        uploadResult: Result<GroomerPortfolioPhoto, GroomerProfileRepositoryError> =
            .failure(.unavailable),
        uploadAvatarResult: Result<String, GroomerProfileRepositoryError> =
            .failure(.unavailable),
        deletePhotoResult: Result<Void, GroomerProfileRepositoryError> =
            .success(()),
        replaceAvailabilityResult: Result<[GroomerAvailabilityWindow], GroomerProfileRepositoryError>? = nil,
        createTimeOffResult: Result<GroomerTimeOffWindow, GroomerProfileRepositoryError>? = nil,
        deleteTimeOffResult: Result<Void, GroomerProfileRepositoryError> = .success(())
    ) {
        self.profileResult = profileResult
        self.servicesResult = servicesResult
        self.portfolioResult = portfolioResult
        self.portfolioFitTagsResult = portfolioFitTagsResult
        self.availabilityResult = availabilityResult
        self.bookingPreferencesResult = bookingPreferencesResult
        self.timeOffResult = timeOffResult
        self.fitClaimsResult = fitClaimsResult
        self.updateProfileResult = updateProfileResult
        self.updateBookingPreferencesResult = updateBookingPreferencesResult
        self.replaceFitClaimsResult = replaceFitClaimsResult
        self.replacePortfolioFitTagsResult = replacePortfolioFitTagsResult
        self.createServiceResult = createServiceResult
        self.updateServiceResult = updateServiceResult
        self.deleteServiceResult = deleteServiceResult
        self.uploadResult = uploadResult
        self.uploadAvatarResult = uploadAvatarResult
        self.deletePhotoResult = deletePhotoResult
        self.replaceAvailabilityResult = replaceAvailabilityResult
        self.createTimeOffResult = createTimeOffResult
        self.deleteTimeOffResult = deleteTimeOffResult
    }

    func profile(groomerID: UUID) async throws -> GroomerProfile {
        try profileResult.get()
    }

    func services(groomerID: UUID) async throws -> [GroomerService] {
        try servicesResult.get()
    }

    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto] {
        try portfolioResult.get()
    }

    func portfolioFitTags(groomerID: UUID) async throws -> [GroomerPortfolioFitTag] {
        try portfolioFitTagsResult.get()
    }

    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow] {
        try availabilityResult.get()
    }

    func bookingPreferences(groomerID: UUID) async throws -> GroomerBookingPreferences {
        try bookingPreferencesResult.get()
    }

    func timeOffWindows(groomerID: UUID) async throws -> [GroomerTimeOffWindow] {
        try timeOffResult.get()
    }

    func fitClaims(groomerID: UUID) async throws -> [GroomerFitClaim] {
        try fitClaimsResult.get()
    }

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft
    ) async throws -> GroomerProfile {
        updateProfileCallCount += 1
        lastProfileDraft = draft

        if let updateProfileResult {
            return try updateProfileResult.get()
        }

        return GroomerProfile(
            userID: groomerID,
            businessName: draft.businessName,
            bio: draft.bio,
            yearsExperience: draft.yearsExperience,
            baseStreetAddress: draft.baseStreetAddress,
            baseCity: draft.baseCity,
            baseState: draft.baseStateCode?.rawValue,
            baseZipCode: draft.baseZipCode,
            serviceRadiusMiles: draft.serviceRadiusMiles,
            serviceLocationMode: draft.serviceLocationMode,
            serviceLocationModes: draft.serviceLocationModes,
            ratingAverage: 0,
            ratingCount: 0,
            isActive: draft.isActive,
            isVerified: false
        )
    }

    func createService(
        groomerID: UUID,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        createServiceCallCount += 1
        lastServiceDraft = draft

        if let createServiceResult {
            return try createServiceResult.get()
        }

        return GroomerService(
            id: UUID(),
            groomerID: groomerID,
            serviceType: draft.serviceType,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
    }

    func updateBookingPreferences(
        groomerID: UUID,
        draft: GroomerBookingPreferencesDraft
    ) async throws -> GroomerBookingPreferences {
        updateBookingPreferencesCallCount += 1
        lastBookingPreferencesDraft = draft

        if let updateBookingPreferencesResult {
            return try updateBookingPreferencesResult.get()
        }

        return GroomerBookingPreferences(
            groomerID: groomerID,
            maxAppointmentsPerDay: draft.maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: draft.minimumAdvanceNoticeDays,
            autoAcceptBookings: draft.autoAcceptBookings
        )
    }

    func replaceFitClaims(
        groomerID: UUID,
        drafts: [GroomerFitClaimDraft]
    ) async throws -> [GroomerFitClaim] {
        replaceFitClaimsCallCount += 1
        lastFitClaimDrafts = drafts

        if let replaceFitClaimsResult {
            return try replaceFitClaimsResult.get()
        }

        return drafts.map {
            GroomerFitClaim(
                id: UUID(),
                groomerID: groomerID,
                signal: $0.signal,
                isActive: $0.isActive
            )
        }
    }

    func replacePortfolioFitTags(
        groomerID: UUID,
        photoID: UUID,
        drafts: [GroomerPortfolioFitTagDraft]
    ) async throws -> [GroomerPortfolioFitTag] {
        replacePortfolioFitTagsCallCount += 1
        lastPortfolioFitTagPhotoID = photoID
        lastPortfolioFitTagDrafts = drafts

        if let replacePortfolioFitTagsResult {
            return try replacePortfolioFitTagsResult.get()
        }

        return drafts.map {
            GroomerPortfolioFitTag(
                id: UUID(),
                portfolioPhotoID: photoID,
                groomerID: groomerID,
                signal: $0.signal
            )
        }
    }

    func updateService(
        service: GroomerService,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        updateServiceCallCount += 1
        lastServiceDraft = draft

        if let updateServiceResult {
            return try updateServiceResult.get()
        }

        return GroomerService(
            id: service.id,
            groomerID: service.groomerID,
            serviceType: draft.serviceType,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
    }

    func deleteService(_ service: GroomerService) async throws {
        deleteServiceCallCount += 1
        try deleteServiceResult.get()
    }

    func uploadPortfolioPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerPortfolioPhotoContentType,
        caption: String?
    ) async throws -> GroomerPortfolioPhoto {
        uploadCallCount += 1
        return try uploadResult.get()
    }

    func uploadAvatarPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerAvatarPhotoContentType
    ) async throws -> String {
        uploadAvatarCallCount += 1
        return try uploadAvatarResult.get()
    }

    func avatarPhotoData(storagePath: String) async throws -> Data {
        Data("avatar".utf8)
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws {
        deletePhotoCallCount += 1
        try deletePhotoResult.get()
    }

    func replaceAvailability(
        groomerID: UUID,
        drafts: [GroomerAvailabilityDraft]
    ) async throws -> [GroomerAvailabilityWindow] {
        replaceAvailabilityCallCount += 1
        lastAvailabilityDrafts = drafts

        if let replaceAvailabilityResult {
            return try replaceAvailabilityResult.get()
        }

        return drafts.map {
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: $0.weekday,
                startMinutes: $0.startMinutes,
                endMinutes: $0.endMinutes,
                isEnabled: $0.isEnabled,
                timezone: $0.timezone
            )
        }
    }

    func createTimeOff(
        groomerID: UUID,
        draft: GroomerTimeOffDraft
    ) async throws -> GroomerTimeOffWindow {
        createTimeOffCallCount += 1
        lastTimeOffDraft = draft

        if let createTimeOffResult {
            return try createTimeOffResult.get()
        }

        return GroomerTimeOffWindow(
            id: UUID(),
            groomerID: groomerID,
            title: draft.title,
            startDate: draft.startDate,
            endDate: draft.endDate
        )
    }

    func deleteTimeOff(_ window: GroomerTimeOffWindow) async throws {
        deleteTimeOffCallCount += 1
        try deleteTimeOffResult.get()
    }
}
