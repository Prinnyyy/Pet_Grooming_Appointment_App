import Foundation
@testable import Beckon

@MainActor
final class GroomerProfileRepositoryFake: GroomerProfileRepository {
    var onRead: (@MainActor (String) async -> Void)?
    private(set) var readNames: [String] = []
    private func recordRead(_ name: String) async {
        readNames.append(name)
        await onRead?(name)
    }
    var availabilityTimingVersion: Int? = 1
    var saveAvailabilityError: GroomerProfileRepositoryError?
    private(set) var saveAvailabilityCallCount = 0
    private(set) var lastSavedTimeOff: [GroomerTimeOffWindow] = []

    func availabilitySnapshot(groomerID: UUID) async throws -> GroomerAvailabilitySnapshot {
        await recordRead("availability")
        let windows = try await availabilityWindows(groomerID: groomerID)
        let preferences = try await bookingPreferences(groomerID: groomerID)
        let timeOff = try await timeOffWindows(groomerID: groomerID)
        return GroomerAvailabilitySnapshot(revision: "fixture", windows: windows, preferences: preferences,
            timeOff: timeOff, timingVersion: availabilityTimingVersion)
    }

    func saveAvailability(
        groomerID: UUID, expectedRevision: String, windows: [GroomerAvailabilityDraft],
        preferences: GroomerBookingPreferencesDraft, timeOff: [GroomerTimeOffWindow]
    ) async throws -> GroomerAvailabilitySnapshot {
        saveAvailabilityCallCount += 1
        lastAvailabilityDrafts = windows
        lastBookingPreferencesDraft = preferences
        lastSavedTimeOff = timeOff
        if let saveAvailabilityError { throw saveAvailabilityError }
        return GroomerAvailabilitySnapshot(revision: "saved", windows: windows.map {
            GroomerAvailabilityWindow(id: UUID(), groomerID: groomerID, weekday: $0.weekday,
                startMinutes: $0.startMinutes, endMinutes: $0.endMinutes, isEnabled: $0.isEnabled, timezone: $0.timezone)
        }, preferences: GroomerBookingPreferences(groomerID: groomerID,
            maxAppointmentsPerDay: preferences.maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: preferences.minimumAdvanceNoticeDays, autoAcceptBookings: preferences.autoAcceptBookings,
            timingBuffers: preferences.timingBuffers),
            timeOff: timeOff, timingVersion: availabilityTimingVersion)
    }

    var profileResult: Result<GroomerProfile, GroomerProfileRepositoryError>
    var servicesResult: Result<[GroomerService], GroomerProfileRepositoryError>
    var onServicesRead: (@MainActor () async -> Void)?
    private(set) var servicesReadCount = 0
    var portfolioResult: Result<[GroomerPortfolioPhoto], GroomerProfileRepositoryError>
    var portfolioFitTagsResult: Result<[GroomerPortfolioFitTag], GroomerProfileRepositoryError>
    var availabilityResult: Result<[GroomerAvailabilityWindow], GroomerProfileRepositoryError>
    var bookingPreferencesResult: Result<GroomerBookingPreferences, GroomerProfileRepositoryError>
    var timeOffResult: Result<[GroomerTimeOffWindow], GroomerProfileRepositoryError>
    var fitClaimsResult: Result<[GroomerFitClaim], GroomerProfileRepositoryError>
    var petFitEvidenceSummaryResult: Result<[GroomerPetFitEvidenceSummary], GroomerProfileRepositoryError>
    var updateProfileResult: Result<GroomerProfile, GroomerProfileRepositoryError>?
    var updateBookingPreferencesResult: Result<GroomerBookingPreferences, GroomerProfileRepositoryError>?
    var replaceFitClaimsResult: Result<[GroomerFitClaim], GroomerProfileRepositoryError>?
    var replacePortfolioFitTagsResult: Result<[GroomerPortfolioFitTag], GroomerProfileRepositoryError>?
    var createServiceResult: Result<GroomerService, GroomerProfileRepositoryError>?
    var updateServiceResult: Result<GroomerService, GroomerProfileRepositoryError>?
    var deleteServiceResult: Result<Void, GroomerProfileRepositoryError>
    var uploadResult: Result<GroomerPortfolioPhoto, GroomerProfileRepositoryError>
    var uploadAvatarResult: Result<String, GroomerProfileRepositoryError>
    var avatarPhotoDataResult: Result<Data, GroomerProfileRepositoryError>?
    var portfolioPhotoDataResultsByID: [UUID: Result<Data, GroomerProfileRepositoryError>]
    var deletePhotoResult: Result<Void, GroomerProfileRepositoryError>
    var replaceAvailabilityResult: Result<[GroomerAvailabilityWindow], GroomerProfileRepositoryError>?
    var createTimeOffResult: Result<GroomerTimeOffWindow, GroomerProfileRepositoryError>?
    var deleteTimeOffResult: Result<Void, GroomerProfileRepositoryError>
    var latestAvatarPathResult: Result<String?, GroomerProfileRepositoryError>

    private(set) var updateProfileCallCount = 0
    private(set) var updateBookingPreferencesCallCount = 0
    private(set) var createServiceCallCount = 0
    private(set) var updateServiceCallCount = 0
    private(set) var deleteServiceCallCount = 0
    private(set) var uploadCallCount = 0
    private(set) var uploadAvatarCallCount = 0
    private(set) var latestAvatarPathCallCount = 0
    private(set) var deletePhotoCallCount = 0
    private(set) var replaceAvailabilityCallCount = 0
    private(set) var createTimeOffCallCount = 0
    private(set) var deleteTimeOffCallCount = 0
    private(set) var replaceFitClaimsCallCount = 0
    private(set) var replacePortfolioFitTagsCallCount = 0
    private(set) var portfolioPhotoDataCallCount = 0
    private(set) var lastProfileDraft: GroomerProfileDraft?
    private(set) var lastConfirmedAddress: BeckonConfirmedAddress?
    private(set) var lastBookingPreferencesDraft: GroomerBookingPreferencesDraft?
    private(set) var lastServiceDraft: GroomerServiceDraft?
    private(set) var lastAvailabilityDrafts: [GroomerAvailabilityDraft] = []
    private(set) var lastTimeOffDraft: GroomerTimeOffDraft?
    private(set) var lastFitClaimDrafts: [GroomerFitClaimDraft] = []
    private(set) var lastPortfolioFitTagPhotoID: UUID?
    private(set) var lastPortfolioFitTagDrafts: [GroomerPortfolioFitTagDraft] = []
    private(set) var lastAvatarPhotoDataPath: String?
    var shouldSuspendPortfolioPhotoData = false
    var shouldSuspendAvailability = false
    private var suspendedAvailabilityContinuation: CheckedContinuation<Void, Never>?

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
        petFitEvidenceSummaryResult: Result<[GroomerPetFitEvidenceSummary], GroomerProfileRepositoryError> =
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
        avatarPhotoDataResult: Result<Data, GroomerProfileRepositoryError>? = nil,
        portfolioPhotoDataResultsByID: [UUID: Result<Data, GroomerProfileRepositoryError>] = [:],
        deletePhotoResult: Result<Void, GroomerProfileRepositoryError> =
            .success(()),
        replaceAvailabilityResult: Result<[GroomerAvailabilityWindow], GroomerProfileRepositoryError>? = nil,
        createTimeOffResult: Result<GroomerTimeOffWindow, GroomerProfileRepositoryError>? = nil,
        deleteTimeOffResult: Result<Void, GroomerProfileRepositoryError> = .success(()),
        latestAvatarPathResult: Result<String?, GroomerProfileRepositoryError> =
            .success(nil)
    ) {
        self.profileResult = profileResult
        self.servicesResult = servicesResult
        self.portfolioResult = portfolioResult
        self.portfolioFitTagsResult = portfolioFitTagsResult
        self.availabilityResult = availabilityResult
        self.bookingPreferencesResult = bookingPreferencesResult
        self.timeOffResult = timeOffResult
        self.fitClaimsResult = fitClaimsResult
        self.petFitEvidenceSummaryResult = petFitEvidenceSummaryResult
        self.updateProfileResult = updateProfileResult
        self.updateBookingPreferencesResult = updateBookingPreferencesResult
        self.replaceFitClaimsResult = replaceFitClaimsResult
        self.replacePortfolioFitTagsResult = replacePortfolioFitTagsResult
        self.createServiceResult = createServiceResult
        self.updateServiceResult = updateServiceResult
        self.deleteServiceResult = deleteServiceResult
        self.uploadResult = uploadResult
        self.uploadAvatarResult = uploadAvatarResult
        self.avatarPhotoDataResult = avatarPhotoDataResult
        self.portfolioPhotoDataResultsByID = portfolioPhotoDataResultsByID
        self.deletePhotoResult = deletePhotoResult
        self.replaceAvailabilityResult = replaceAvailabilityResult
        self.createTimeOffResult = createTimeOffResult
        self.deleteTimeOffResult = deleteTimeOffResult
        self.latestAvatarPathResult = latestAvatarPathResult
    }

    func profile(groomerID: UUID) async throws -> GroomerProfile {
        let result = profileResult
        await recordRead("profile")
        return try result.get()
    }

    func services(groomerID: UUID) async throws -> [GroomerService] {
        await recordRead("services")
        servicesReadCount += 1
        await onServicesRead?()
        return try servicesResult.get()
    }

    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto] {
        await recordRead("portfolio")
        return try portfolioResult.get()
    }

    func portfolioFitTags(groomerID: UUID) async throws -> [GroomerPortfolioFitTag] {
        await recordRead("tags")
        return try portfolioFitTagsResult.get()
    }

    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow] {
        if shouldSuspendAvailability {
            await withCheckedContinuation { continuation in
                suspendedAvailabilityContinuation = continuation
            }
        }
        return try availabilityResult.get()
    }

    func waitForSuspendedAvailability() async {
        while suspendedAvailabilityContinuation == nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func resumeSuspendedAvailability() {
        suspendedAvailabilityContinuation?.resume()
        suspendedAvailabilityContinuation = nil
        shouldSuspendAvailability = false
    }

    func bookingPreferences(groomerID: UUID) async throws -> GroomerBookingPreferences {
        try bookingPreferencesResult.get()
    }

    func timeOffWindows(groomerID: UUID) async throws -> [GroomerTimeOffWindow] {
        try timeOffResult.get()
    }

    func fitClaims(groomerID: UUID) async throws -> [GroomerFitClaim] {
        await recordRead("claims")
        return try fitClaimsResult.get()
    }

    func petFitEvidenceSummary(groomerID: UUID) async throws -> [GroomerPetFitEvidenceSummary] {
        await recordRead("evidence")
        return try petFitEvidenceSummaryResult.get()
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
            baseAddressLine2: draft.baseAddressLine2,
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

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft,
        confirmedAddress: BeckonConfirmedAddress?
    ) async throws -> GroomerProfile {
        lastConfirmedAddress = confirmedAddress
        var profile = try await updateProfile(groomerID: groomerID, draft: draft)
        profile.confirmedAddress = confirmedAddress
        return profile
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
        lastAvatarPhotoDataPath = storagePath
        if let avatarPhotoDataResult {
            return try avatarPhotoDataResult.get()
        }
        return Data("avatar:\(storagePath)".utf8)
    }

    func latestAvatarPhotoPath(groomerID: UUID) async throws -> String? {
        await recordRead("avatarPath")
        latestAvatarPathCallCount += 1
        return try latestAvatarPathResult.get()
    }

    func portfolioPhotoData(_ photo: GroomerPortfolioPhoto) async throws -> Data {
        await recordRead("image")
        portfolioPhotoDataCallCount += 1
        if shouldSuspendPortfolioPhotoData {
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            throw GroomerProfileRepositoryError.unavailable
        }
        if let result = portfolioPhotoDataResultsByID[photo.id] {
            return try result.get()
        }
        return Data("portfolio".utf8)
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

@MainActor
final class GroomerProfileSnapshotCacheFake: ProfileSnapshotCaching {
    var storedSnapshot: ProfileSnapshot?
    private(set) var savedSnapshot: ProfileSnapshot?
    private(set) var removedUserID: UUID?

    init(snapshot: ProfileSnapshot? = nil) {
        self.storedSnapshot = snapshot
    }

    func snapshot(userID: UUID) -> ProfileSnapshot? {
        guard storedSnapshot?.userID == userID else { return nil }
        return storedSnapshot
    }

    func save(_ snapshot: ProfileSnapshot) {
        savedSnapshot = snapshot
        storedSnapshot = snapshot
    }

    func remove(userID: UUID) {
        removedUserID = userID
        if storedSnapshot?.userID == userID {
            storedSnapshot = nil
        }
    }
}
