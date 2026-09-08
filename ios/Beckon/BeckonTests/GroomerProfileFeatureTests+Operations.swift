import Foundation
import Testing
import UIKit
@testable import Beckon

extension GroomerProfileStoreTests {
    @Test @MainActor
    func invalidTimingBuffersNeverReachRepository() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        store.applyAvailabilitySnapshot(try await repository.availabilitySnapshot(groomerID: id))
        for values in [["121", "0", "0", "0"], ["0", "-1", "0", "0"],
                       ["0", "0", "181", "0"], ["0", "0", "0", "181"],
                       ["1.5", "0", "0", "0"], ["", "0", "0", "0"]] {
            store.preparationMinutesText = values[0]
            store.cleanupMinutesText = values[1]
            store.inboundTravelMinutesText = values[2]
            store.outboundTravelMinutesText = values[3]
            await store.saveAvailability()
            #expect(repository.saveAvailabilityCallCount == 0)
            #expect(store.errorMessage != nil)
            #expect(store.hasAvailabilityEdits)
        }
    }

    @Test @MainActor
    func confirmedTimingBuffersCannotBeCleared() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        let initial = try await repository.availabilitySnapshot(groomerID: id)
        var preferences = initial.preferences
        preferences.timingBuffers = try GroomingTimingBuffers(
            preparation: 120, cleanup: 120, inboundTravel: 180, outboundTravel: 180)
        let snapshot = GroomerAvailabilitySnapshot(revision: initial.revision,
            windows: initial.windows, preferences: preferences, timeOff: initial.timeOff,
            timingVersion: initial.timingVersion)
        store.applyAvailabilitySnapshot(snapshot)
        store.preparationMinutesText = ""
        store.cleanupMinutesText = ""
        store.inboundTravelMinutesText = ""
        store.outboundTravelMinutesText = ""
        await store.saveAvailability()
        #expect(repository.saveAvailabilityCallCount == 0)
        #expect(store.savedAvailability == snapshot)
        #expect(store.errorMessage != nil)
        store.discardAvailabilityEdits()
        #expect(store.preparationMinutesText == "120")
        #expect(store.outboundTravelMinutesText == "180")
        #expect(!store.hasAvailabilityEdits)
    }

    @Test @MainActor
    func legacyBackendStillSavesOrdinaryScheduleWithoutInventingBuffers() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        repository.availabilityTimingVersion = nil
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        store.applyAvailabilitySnapshot(try await repository.availabilitySnapshot(groomerID: id))
        store.maxAppointmentsPerDay = 8
        await store.saveAvailability()
        #expect(repository.saveAvailabilityCallCount == 1)
        #expect(repository.lastBookingPreferencesDraft?.timingBuffers == nil)
        #expect(store.preparationMinutesText.isEmpty)
        #expect(store.errorMessage == nil)
        #expect(!store.hasAvailabilityEdits)
    }

    @Test @MainActor
    func timingBuffersAreExplicitAtomicAndDiscardable() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        store.applyAvailabilitySnapshot(try await repository.availabilitySnapshot(groomerID: id))
        #expect(store.preparationMinutesText.isEmpty)
        #expect(store.bookingPreferences?.timingBuffers == nil)
        store.preparationMinutesText = "15"
        #expect(store.hasAvailabilityEdits)
        await store.saveAvailability()
        #expect(repository.saveAvailabilityCallCount == 0)
        store.discardAvailabilityEdits()
        #expect(store.preparationMinutesText.isEmpty)
        store.preparationMinutesText = "0"
        store.cleanupMinutesText = "0"
        store.inboundTravelMinutesText = "0"
        store.outboundTravelMinutesText = "0"
        await store.saveAvailability()
        #expect(repository.saveAvailabilityCallCount == 1)
        #expect(repository.lastBookingPreferencesDraft?.timingBuffers ==
            (try GroomingTimingBuffers(preparation: 0, cleanup: 0, inboundTravel: 0, outboundTravel: 0)))
        #expect(!store.hasAvailabilityEdits)
        store.preparationMinutesText = "20"
        store.discardAvailabilityEdits()
        #expect(store.preparationMinutesText == "0")
    }

    @Test @MainActor
    func timingBuffersDoNotWriteToAnUnsupportedBackend() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        repository.availabilityTimingVersion = nil
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        store.applyAvailabilitySnapshot(try await repository.availabilitySnapshot(groomerID: id))
        store.preparationMinutesText = "15"
        store.cleanupMinutesText = "15"
        store.inboundTravelMinutesText = "30"
        store.outboundTravelMinutesText = "30"
        await store.saveAvailability()
        #expect(repository.saveAvailabilityCallCount == 0)
        #expect(store.hasAvailabilityEdits)
        #expect(store.errorMessage != nil)
    }

    @Test @MainActor
    func saveAvailabilityDoesNotPersistUnrelatedProfileEdits() async throws {
        let groomerID = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        store.applyAvailabilitySnapshot(try await repository.availabilitySnapshot(groomerID: groomerID))
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

        #expect(repository.updateProfileCallCount == 0)
        #expect(repository.saveAvailabilityCallCount == 1)
        #expect(repository.replaceAvailabilityCallCount == 0)
        #expect(repository.updateBookingPreferencesCallCount == 0)
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
    func bookingOccupancyRejectionPreservesEditsWithoutUnknownSaveState() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        repository.saveAvailabilityError = .bookingOccupancyConflict
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        let saved = try await repository.availabilitySnapshot(groomerID: id)
        store.applyAvailabilitySnapshot(saved)
        store.timeOffTitle = "Vacation"
        await store.createTimeOff()
        let pending = store.timeOffWindows
        await store.saveAvailability()
        #expect(store.savedAvailability == saved)
        #expect(store.timeOffWindows == pending)
        #expect(!store.availabilitySaveNeedsReconciliation)
        #expect(store.noticeMessage == nil)
        #expect(!store.isSaving)
        #expect(store.errorMessage == "Your availability must cover existing appointments, including preparation, travel, and cleanup. Adjust your hours or time off and try again.")
    }

    @Test @MainActor
    func availabilityFailuresPreserveDraftAndAuthoritativeSnapshot() async throws {
        for error: GroomerProfileRepositoryError in [.unavailable, .networkUnavailable, .availabilityConflict] {
            let id = UUID()
            let repository = GroomerProfileRepositoryFake()
            repository.saveAvailabilityError = error
            let store = GroomerProfileStore(groomerID: id, repository: repository)
            let saved = try await repository.availabilitySnapshot(groomerID: id)
            store.applyAvailabilitySnapshot(saved)
            store.maxAppointmentsPerDay = 9
            store.timeOffTitle = "Vacation"
            await store.createTimeOff()
            let pendingTimeOff = store.timeOffWindows

            await store.saveAvailability()

            #expect(store.savedAvailability == saved)
            #expect(store.maxAppointmentsPerDay == 9)
            #expect(store.timeOffWindows == pendingTimeOff)
            #expect(repository.lastSavedTimeOff == pendingTimeOff)
            #expect(repository.replaceAvailabilityCallCount == 0)
            #expect(store.errorMessage != nil)
            #expect(store.noticeMessage == nil)
            #expect(!store.isSaving)
        }
    }

    @Test @MainActor
    func availabilitySaveIgnoresInvalidProfileAndCommitsTimeOffTogether() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        store.applyAvailabilitySnapshot(try await repository.availabilitySnapshot(groomerID: id))
        store.isActive = true
        store.businessName = ""
        store.timeOffTitle = "Vacation"
        await store.createTimeOff()
        let pending = store.timeOffWindows

        await store.saveAvailability()

        #expect(repository.saveAvailabilityCallCount == 1)
        #expect(repository.updateProfileCallCount == 0)
        #expect(store.savedAvailability?.timeOff == pending)
        #expect(store.savedAvailability?.revision == "saved")
        #expect(store.businessName == "")
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func uncertainAvailabilitySaveRequiresReloadBeforeAnotherWrite() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        store.applyAvailabilitySnapshot(try await repository.availabilitySnapshot(groomerID: id))
        repository.saveAvailabilityError = .networkUnavailable
        store.maxAppointmentsPerDay = 9

        await store.saveAvailability()
        #expect(store.errorMessage?.contains("confirm") == true)
        await store.saveAvailability()
        #expect(repository.saveAvailabilityCallCount == 1)
        #expect(store.maxAppointmentsPerDay == 9)

        repository.saveAvailabilityError = nil
        await store.reloadAvailability()
        await store.saveAvailability()
        #expect(repository.saveAvailabilityCallCount == 2)
        #expect(store.noticeMessage == "Availability saved.")
    }

    @Test @MainActor
    func failedAvailabilityReloadPreservesDraftAndUnresolvedWrite() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        let saved = try await repository.availabilitySnapshot(groomerID: id)
        store.applyAvailabilitySnapshot(saved)
        repository.saveAvailabilityError = .networkUnavailable
        store.maxAppointmentsPerDay = 9
        await store.saveAvailability()
        repository.availabilityResult = .failure(.networkUnavailable)
        await store.reloadAvailability()
        await store.saveAvailability()
        #expect(repository.saveAvailabilityCallCount == 1)
        #expect(store.savedAvailability == saved)
        #expect(store.maxAppointmentsPerDay == 9)
    }

    @Test @MainActor
    func disabledUnpersistedDayEditsStillRequireDiscardConfirmation() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        store.applyAvailabilitySnapshot(try await repository.availabilitySnapshot(groomerID: id))
        #expect(!store.hasAvailabilityEdits)
        store.setAvailability(day: .monday, isEnabled: false, startMinutes: 600, endMinutes: 720)
        #expect(store.hasAvailabilityEdits)
        store.discardAvailabilityEdits()
        #expect(!store.hasAvailabilityEdits)
    }

    @Test @MainActor
    func unversionedAvailabilityNeverFallsBackToPartialWrites() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(groomerID: UUID(), repository: repository)
        await store.saveAvailability()
        #expect(repository.saveAvailabilityCallCount == 0)
        #expect(repository.replaceAvailabilityCallCount == 0)
        #expect(repository.updateBookingPreferencesCallCount == 0)
        #expect(store.errorMessage != nil)
    }

    @Test @MainActor
    func discardingAvailabilityEditsRestoresSavedTimeOffAndPreferences() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        let saved = try await repository.availabilitySnapshot(groomerID: id)
        store.applyAvailabilitySnapshot(saved)
        store.maxAppointmentsPerDay = 9
        store.timeOffTitle = "Vacation"
        await store.createTimeOff()
        store.discardAvailabilityEdits()
        #expect(store.timeOffWindows == saved.timeOff)
        #expect(store.maxAppointmentsPerDay == saved.preferences.maxAppointmentsPerDay)
        #expect(repository.saveAvailabilityCallCount == 0)
    }

    @Test @MainActor
    func profileRefreshDoesNotOverwriteAvailabilityEditorDraft() async throws {
        let id = UUID()
        let repository = GroomerProfileRepositoryFake(profileResult: .success(Self.profile(groomerID: id)))
        let store = GroomerProfileStore(groomerID: id, repository: repository)
        store.applyAvailabilitySnapshot(try await repository.availabilitySnapshot(groomerID: id))
        store.isEditingAvailability = true
        store.maxAppointmentsPerDay = 9
        store.timeOffTitle = "Vacation"
        await store.createTimeOff()
        let pending = store.timeOffWindows
        await store.load()
        #expect(store.maxAppointmentsPerDay == 9)
        #expect(store.timeOffWindows == pending)
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

        #expect(repository.createTimeOffCallCount == 0)
        #expect(store.timeOffWindows.first?.title == "Long weekend away")
        #expect(store.timeOffWindows.first?.startDate == "2026-07-04")
        #expect(store.timeOffWindows.first?.endDate == "2026-07-06")

        let created = try #require(store.timeOffWindows.first)
        await store.deleteTimeOff(created)

        #expect(repository.deleteTimeOffCallCount == 0)
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
    func createServicePreservesExplicitSizesAndLabelsEmptySizesAsAssessment() async {
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
                "Size assessment required"
        )
        #expect(store.services.first?.acceptedPetSizeSummary == "Size assessment required")
    }

    @Test @MainActor
    func serviceSizeRangeUsesFitSignalsOnlyAsAnExplicitlyEnabledStartingValue() {
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
