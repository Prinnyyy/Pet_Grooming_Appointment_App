import Foundation
import Testing
import UIKit
@testable import Beckon

extension GroomerProfileStoreTests {
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
        #expect(store.noticeMessage == "Groomer profile saved.")
    }

    @Test @MainActor
    func oversizedAvatarUploadDoesNotCallRepository() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: repository
        )

        await store.uploadAvatarPhoto(
            data: Data(count: GroomerProfileStore.maximumAvatarPhotoBytes + 1),
            contentType: .jpeg
        )

        #expect(repository.uploadAvatarCallCount == 0)
        #expect(store.errorMessage == "Choose an avatar photo smaller than 5 MB.")
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
    func saveProfilePreservesExistingAvatarPathWhenResponseOmitsAvatar() async {
        let groomerID = UUID()
        var currentProfile = Self.profile(groomerID: groomerID)
        currentProfile.avatarPath = "existing-avatar.jpg"
        let savedProfile = GroomerProfile(
            userID: groomerID,
            businessName: "Updated Coat",
            bio: "Calm grooming",
            yearsExperience: 5,
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
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(currentProfile),
            updateProfileResult: .success(savedProfile)
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        store.businessName = "Updated Coat"
        await store.saveProfile()

        #expect(store.profile?.businessName == "Updated Coat")
        #expect(store.profile?.avatarPath == "existing-avatar.jpg")
    }

    @Test @MainActor
    func createServiceUsesFixedServiceTypeKeepsCanonicalPetSizeOrderAndUsesEmptyAsFitSignalInheritance() async {
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
        store.setServiceUsesCustomSizeRange(true)
        store.setServiceAcceptedPetSizeRange(lowerIndex: 0, upperIndex: 6)

        await store.saveService()

        #expect(repository.createServiceCallCount == 1)
        #expect(repository.lastServiceDraft?.serviceType == .bathAndBrush)
        #expect(repository.lastServiceDraft?.title == "Bath & Brush")
        #expect(repository.lastServiceDraft?.description == "Shampoo")
        #expect(repository.lastServiceDraft?.basePrice == 45.50)
        #expect(repository.lastServiceDraft?.durationMinutes == 60)
        #expect(repository.lastServiceDraft?.acceptedPetSizes == [
            .xs,
            .s,
            .m,
            .l,
            .xl,
            .xxl,
            .giant,
        ])

        store.startCreateService()
        store.serviceType = .nailTrim
        store.serviceBasePrice = "20"
        store.serviceDurationMinutes = "30"

        await store.saveService()

        #expect(repository.lastServiceDraft?.acceptedPetSizes == [])
        #expect(
            store.serviceSizePolicySummary(for: store.services.first!) ==
                "Follows Fit Signals: XS-Giant (<10lb-101+lb)"
        )
    }

    @Test @MainActor
    func serviceSizeOverrideSeedsFromFitSignalRangeAndCanReturnToInheritance() {
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: GroomerProfileRepositoryFake()
        )

        store.setSizeBandFitClaimRange(lowerIndex: 1, upperIndex: 4)
        store.startCreateService()

        #expect(store.serviceUsesCustomSizeRange == false)
        #expect(store.selectedServiceSizes == [])
        #expect(store.selectedServiceSizeRange == 1...4)
        #expect(store.serviceSizeRangeTitle == "S-XL (10lb-79lb)")

        store.setServiceUsesCustomSizeRange(true)

        #expect(store.serviceUsesCustomSizeRange)
        #expect(store.selectedServiceSizes == [.s, .m, .l, .xl])

        store.setServiceAcceptedPetSizeRange(lowerIndex: 2, upperIndex: 5)

        #expect(store.selectedServiceSizes == [.m, .l, .xl, .xxl])
        #expect(store.serviceSizeRangeTitle == "M-XXL (20lb-100lb)")

        store.setServiceUsesCustomSizeRange(false)

        #expect(store.serviceUsesCustomSizeRange == false)
        #expect(store.selectedServiceSizes == [])
        #expect(store.serviceSizePolicySummary(for: Self.service(groomerID: UUID())) ==
            "Custom range: XS (<10lb)"
        )
    }

    @Test @MainActor
    func editingServiceWithAcceptedSizesUsesCustomRange() {
        let groomerID = UUID()
        let service = GroomerService(
            id: UUID(),
            groomerID: groomerID,
            serviceType: .bathAndBrush,
            title: "Bath & Brush",
            description: nil,
            basePrice: 45,
            durationMinutes: 60,
            acceptedPetSizes: [.m, .l, .xl],
            isActive: true
        )
        let repository = GroomerProfileRepositoryFake(servicesResult: .success([service]))
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        store.startEditService(service)

        #expect(store.serviceUsesCustomSizeRange)
        #expect(store.selectedServiceSizeRange == 2...4)
        #expect(store.serviceSizeRangeTitle == "M-XL (20lb-79lb)")
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

}
