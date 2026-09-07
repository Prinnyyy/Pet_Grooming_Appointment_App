import Foundation
import Observation

@MainActor
@Observable
final class GroomerProfileStore {
    static let maximumPhotoBytes = 10 * 1024 * 1024
    static let maximumAvatarPhotoBytes = 5 * 1024 * 1024

    let groomerID: UUID
    let repository: any GroomerProfileRepository
    let profileSnapshotCache: any ProfileSnapshotCaching
    let debugRecorder: AppDebugEventRecorder?
    let addressEditorState: BeckonAddressEditorState
    var loadedAddressInput: BeckonAddressInput
    var profileMutationRevision = 0

    var profile: GroomerProfile?
    private(set) var cachedProfileSnapshot: ProfileSnapshot?
    var services: [GroomerService] = []
    var portfolioPhotos: [GroomerPortfolioPhoto] = []
    var portfolioPhotoDataByID: [UUID: Data] = [:]
    var attemptedPortfolioPhotoDataIDs: Set<UUID> = []
    var portfolioFitTags: [GroomerPortfolioFitTag] = []
    var selectedPortfolioFitTagIDsByPhotoID: [UUID: Set<String>] = [:]
    var availabilityWindows: [GroomerAvailabilityWindow] = []
    var bookingPreferences: GroomerBookingPreferences?
    var timeOffWindows: [GroomerTimeOffWindow] = []
    var savedAvailability: GroomerAvailabilitySnapshot?
    var availabilitySaveNeedsReconciliation = false
    var isEditingAvailability = false
    var fitClaims: [GroomerFitClaim] = []
    private(set) var petFitEvidenceSummary: [GroomerPetFitEvidenceSummary] = []
    var selectedFitClaimIDs: Set<String> = []
    var avatarPhotoData: Data?
    private(set) var isLoading = false
    var isSaving = false
    var isUploading = false

    var errorMessage: String?
    var noticeMessage: String?

    var businessName = ""
    var bio = ""
    var yearsExperience = 0
    var baseStreetAddress: String {
        get { addressEditorState.input.line1 }
        set { addressEditorState.updateLine1(newValue) }
    }
    var baseAddressLine2: String {
        get { addressEditorState.input.line2 }
        set { addressEditorState.updateLine2(newValue) }
    }
    var baseCity: String {
        get { addressEditorState.input.city }
        set { addressEditorState.updateCity(newValue) }
    }
    var baseState = ""
    var baseStateCode: USStateCode? {
        get { addressEditorState.input.stateCode }
        set {
            addressEditorState.updateState(newValue)
            baseState = newValue?.rawValue ?? ""
        }
    }
    var baseZipCode: String {
        get { addressEditorState.input.postalCode }
        set { addressEditorState.updatePostalCode(newValue) }
    }
    var serviceRadiusMiles = 12
    var serviceLocationModes: Set<GroomingLocationMode> = []
    var isActive = false

    var isShowingServiceForm = false
    var editingServiceID: UUID?
    var serviceTitle = ""
    var serviceType: GroomingServiceType = .fullGroom
    var serviceDescription = ""
    var serviceBasePrice = ""
    var serviceDurationMinutes = ""
    var serviceUsesCustomSizeRange = false
    var selectedServiceSizes: Set<GroomerServicePetSize> = []
    var serviceIsActive = true
    var availabilityDayStates: [GroomerAvailabilityDayState] =
        GroomerAvailabilityDayState.defaultStates()
    var availabilityTimezone = TimeZone.current.identifier
    var maxAppointmentsPerDay = 4
    var minimumAdvanceNoticeDays = 0
    var autoAcceptBookings = false
    var isShowingTimeOffForm = false
    var timeOffTitle = ""
    var timeOffStartDate = Date()
    var timeOffEndDate = Date()

    var serviceFormTitle: String {
        editingServiceID == nil ? "Add Service" : "Edit Service"
    }

    var isBusy: Bool {
        (isLoading && profile == nil) || isSaving || isUploading
    }

    var shouldShowInitialLoading: Bool {
        isLoading && profile == nil && cachedProfileSnapshot == nil
    }

    var profileDisplayName: String {
        Self.normalized(profile?.businessName)
            ?? Self.normalized(cachedProfileSnapshot?.displayName)
            ?? "Groomer Profile"
    }

    var profileDetailText: String {
        if let profile {
            return Self.detailText(for: profile)
        }

        return Self.normalized(cachedProfileSnapshot?.detailText)
            ?? "★ New profile"
    }

    var selectedCoreFitClaimCount: Int {
        selectedFitClaimCount { $0.group != .sizeBand }
    }

    var selectedSizeBandFitClaimCount: Int {
        selectedFitClaimCount { $0.group == .sizeBand }
    }

    var selectedSizeBandRange: ClosedRange<Int> {
        let selectedIndices = Self.sizeBandSignals.enumerated().compactMap { index, signal in
            selectedFitClaimIDs.contains(signal.id) ? index : nil
        }
        guard let lowerBound = selectedIndices.min(),
              let upperBound = selectedIndices.max() else {
            return Self.fullSizeBandRange
        }
        return lowerBound...upperBound
    }

    var sizeBandFitClaimRangeTitle: String {
        Self.sizeBandRangeTitle(for: selectedSizeBandRange)
    }

    var selectedServiceSizeRange: ClosedRange<Int> {
        let selectedIndices = Self.serviceSizeOptions.enumerated().compactMap { index, size in
            selectedServiceSizes.contains(size) ? index : nil
        }
        guard let lowerBound = selectedIndices.min(),
              let upperBound = selectedIndices.max() else {
            return Self.normalizedServiceSizeRange(
                lowerIndex: selectedSizeBandRange.lowerBound,
                upperIndex: selectedSizeBandRange.upperBound
            )
        }
        return lowerBound...upperBound
    }

    var serviceSizeRangeTitle: String {
        Self.serviceSizeRangeTitle(for: selectedServiceSizeRange)
    }

    init(
        groomerID: UUID,
        repository: any GroomerProfileRepository,
        profileSnapshotCache: any ProfileSnapshotCaching = FileProfileSnapshotCache.shared,
        debugRecorder: AppDebugEventRecorder? = nil,
        addressProvider: (any BeckonAddressProviding)? = nil
    ) {
        let emptyAddress = BeckonAddressInput(
            line1: "",
            line2: "",
            city: "",
            stateCode: nil,
            postalCode: "",
            countryCode: "US"
        )
        self.groomerID = groomerID
        self.repository = repository
        self.profileSnapshotCache = profileSnapshotCache
        self.debugRecorder = debugRecorder
        self.addressEditorState = BeckonAddressEditorState(
            input: emptyAddress,
            provider: addressProvider ?? MapKitAddressProvider()
        )
        self.loadedAddressInput = emptyAddress
    }

    func load() async {
        let startedAt = Date()
        recordStoreStart("load")
        let loadRevision = profileMutationRevision
        isLoading = true
        errorMessage = nil
        populateCachedProfileSnapshot()

        do {
            let loadedProfile = try await repository.profile(groomerID: groomerID)
            let loadedServices = try await repository.services(groomerID: groomerID)
            let loadedPhotos = try await repository.portfolioPhotos(groomerID: groomerID)
            let loadedPortfolioFitTags = try await repository.portfolioFitTags(
                groomerID: groomerID
            )
            let loadedSchedule = try await repository.availabilitySnapshot(groomerID: groomerID)
            let loadedFitClaims = try await repository.fitClaims(groomerID: groomerID)
            let loadedPetFitEvidenceSummary = try await repository.petFitEvidenceSummary(
                groomerID: groomerID
            )

            guard loadRevision == profileMutationRevision else {
                isLoading = false
                return
            }

            profile = loadedProfile
            services = loadedServices
            portfolioPhotos = loadedPhotos
            portfolioPhotoDataByID = [:]
            attemptedPortfolioPhotoDataIDs = []
            populatePortfolioFitTags(
                with: loadedPortfolioFitTags,
                visiblePhotos: loadedPhotos
            )
            if !isEditingAvailability || savedAvailability == nil {
                applyAvailabilitySnapshot(loadedSchedule)
            }
            populateFitClaims(with: loadedFitClaims)
            populatePetFitEvidenceSummary(with: loadedPetFitEvidenceSummary)
            populateProfileForm(with: loadedProfile)
            resetTimeOffForm()
            isLoading = false
            saveProfileSnapshot(profile: loadedProfile, avatarData: avatarPhotoData)

            let loadedAvatarPhoto = await avatarPhotoPayload(
                from: loadedProfile.avatarPath
            )
            guard loadRevision == profileMutationRevision else {
                return
            }
            if let loadedAvatarPath = loadedAvatarPhoto.path,
               loadedAvatarPath != profile?.avatarPath,
               var profile {
                profile.avatarPath = loadedAvatarPath
                self.profile = profile
            }
            avatarPhotoData = loadedAvatarPhoto.data ?? cachedProfileSnapshot?.avatarData
            saveProfileSnapshot(profile: profile, avatarData: avatarPhotoData)

            let loadedPortfolioPhotoPayload = await portfolioPhotoDataMap(
                for: loadedPhotos
            )
            guard loadRevision == profileMutationRevision else {
                recordStoreCancelled(
                    "load",
                    startedAt: startedAt,
                    metadata: ["reason": "stale mutation revision"]
                )
                return
            }
            portfolioPhotoDataByID = loadedPortfolioPhotoPayload.dataByID
            attemptedPortfolioPhotoDataIDs = loadedPortfolioPhotoPayload.attemptedPhotoIDs
            recordStoreSuccess(
                "load",
                startedAt: startedAt,
                metadata: [
                    "serviceCount": "\(services.count)",
                    "portfolioPhotoCount": "\(portfolioPhotos.count)",
                    "fitClaimCount": "\(fitClaims.count)",
                ]
            )
        } catch GroomerProfileRepositoryError.cancelled {
            isLoading = false
            recordStoreCancelled("load", startedAt: startedAt)
        } catch let error as GroomerProfileRepositoryError {
            isLoading = false
            errorMessage = message(for: error, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            isLoading = false
            recordStoreCancelled("load", startedAt: startedAt)
        } catch {
            isLoading = false
            errorMessage = message(for: .unavailable, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func populateProfileForm(with profile: GroomerProfile) {
        businessName = profile.businessName ?? ""
        bio = profile.bio ?? ""
        yearsExperience = min(max(profile.yearsExperience ?? 0, 0), 5)
        let addressInput = BeckonAddressInput(
            line1: profile.baseStreetAddress ?? "",
            line2: profile.baseAddressLine2 ?? "",
            city: profile.baseCity ?? "",
            stateCode: profile.baseState.flatMap(USStateCode.init(rawValue:)),
            postalCode: profile.baseZipCode ?? "",
            countryCode: profile.confirmedAddress?.accepted.countryCode ?? "US"
        )
        addressEditorState.replaceInput(
            addressInput,
            confirmedAddress: profile.confirmedAddress
        )
        loadedAddressInput = normalizedAddressInput(addressInput)
        baseState = profile.baseState ?? ""
        serviceRadiusMiles = min(max(profile.serviceRadiusMiles ?? 12, 5), 50)
        serviceLocationModes = profile.effectiveServiceLocationModes
        isActive = profile.isActive
    }

    func normalizedAddressInput(_ input: BeckonAddressInput) -> BeckonAddressInput {
        BeckonAddressInput(
            line1: input.line1.trimmingCharacters(in: .whitespacesAndNewlines),
            line2: input.line2.trimmingCharacters(in: .whitespacesAndNewlines),
            city: input.city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode: input.stateCode,
            postalCode: input.postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            countryCode: input.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )
    }

    private func populateCachedProfileSnapshot() {
        guard let snapshot = profileSnapshotCache.snapshot(userID: groomerID) else {
            return
        }

        cachedProfileSnapshot = snapshot
        if avatarPhotoData == nil {
            avatarPhotoData = snapshot.avatarData
        }
    }

    func saveProfileSnapshot(
        profile: GroomerProfile?,
        avatarData: Data?
    ) {
        let displayName = Self.normalized(profile?.businessName)
            ?? Self.normalized(cachedProfileSnapshot?.displayName)
            ?? "Groomer Profile"
        let snapshot = ProfileSnapshot(
            userID: groomerID,
            displayName: displayName,
            detailText: profile.map(Self.detailText(for:))
                ?? Self.normalized(cachedProfileSnapshot?.detailText),
            avatarData: avatarData
        )
        cachedProfileSnapshot = snapshot
        profileSnapshotCache.save(snapshot)
    }

    private static func detailText(for profile: GroomerProfile) -> String {
        guard profile.ratingCount > 0 else {
            return "★ New profile"
        }

        return "★ \(profile.ratingAverage.formatted(.number.precision(.fractionLength(1)))) · \(profile.ratingCount) review\(profile.ratingCount == 1 ? "" : "s")"
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func avatarPhotoPayload(from storagePath: String?) async -> (
        path: String?,
        data: Data?
    ) {
        let preferredPath = normalizedStoragePath(storagePath)
        let latestPath: String?

        do {
            latestPath = normalizedStoragePath(
                try await repository.latestAvatarPhotoPath(
                    groomerID: groomerID
                )
            )
        } catch {
            latestPath = nil
        }

        var seenPaths: Set<String> = []
        for candidatePath in [latestPath, preferredPath].compactMap({ $0 })
            where seenPaths.insert(candidatePath).inserted {
            if let data = try? await repository.avatarPhotoData(
                storagePath: candidatePath
            ) {
                return (candidatePath, data)
            }
        }

        return (preferredPath, nil)
    }

    private func normalizedStoragePath(_ storagePath: String?) -> String? {
        let trimmed = storagePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func portfolioPhotoDataMap(
        for photos: [GroomerPortfolioPhoto]
    ) async -> (dataByID: [UUID: Data], attemptedPhotoIDs: Set<UUID>) {
        var dataByID: [UUID: Data] = [:]
        var attemptedPhotoIDs: Set<UUID> = []
        for photo in photos {
            attemptedPhotoIDs.insert(photo.id)
            guard let data = try? await repository.portfolioPhotoData(photo) else {
                continue
            }
            dataByID[photo.id] = data
        }
        return (dataByID, attemptedPhotoIDs)
    }

    func populateAvailabilityForm(with windows: [GroomerAvailabilityWindow]) {
        var states = GroomerAvailabilityDayState.defaultStates()
        for window in windows {
            guard let index = states.firstIndex(where: { $0.weekday == window.weekday }) else {
                continue
            }
            states[index] = GroomerAvailabilityDayState(
                weekday: window.weekday,
                isEnabled: window.isEnabled,
                startMinutes: window.startMinutes,
                endMinutes: window.endMinutes
            )
        }
        availabilityDayStates = states
        if let timezone = windows.first?.timezone {
            availabilityTimezone = timezone
        }
    }

    func populateBookingPreferencesForm(with preferences: GroomerBookingPreferences) {
        maxAppointmentsPerDay = min(max(preferences.maxAppointmentsPerDay, 1), 12)
        minimumAdvanceNoticeDays = min(max(preferences.minimumAdvanceNoticeDays, 0), 2)
        autoAcceptBookings = preferences.autoAcceptBookings
    }

    func populateFitClaims(with claims: [GroomerFitClaim]) {
        fitClaims = claims.sorted(by: Self.sortFitClaims)
        let supportedSignals = Set(GroomerFitClaim.availableSignals)
        selectedFitClaimIDs = Set(
            claims
                .filter { $0.isActive && supportedSignals.contains($0.signal) }
                .map { $0.signal.id }
        )
    }

    private func populatePetFitEvidenceSummary(with summaries: [GroomerPetFitEvidenceSummary]) {
        let supportedSignals = Set(PetFitSignal.allCases)
        petFitEvidenceSummary = summaries
            .filter { $0.groomerID == groomerID && supportedSignals.contains($0.signal) }
            .sorted(by: Self.sortPetFitEvidenceSummary)
    }

    private func populatePortfolioFitTags(
        with tags: [GroomerPortfolioFitTag],
        visiblePhotos: [GroomerPortfolioPhoto]
    ) {
        let visiblePhotoIDs = Set(visiblePhotos.map(\.id))
        let supportedSignals = Set(PetFitSignal.allCases)
        let visibleTags = tags.filter {
            visiblePhotoIDs.contains($0.portfolioPhotoID) &&
                supportedSignals.contains($0.signal)
        }

        portfolioFitTags = visibleTags.sorted(by: Self.sortPortfolioFitTags)
        selectedPortfolioFitTagIDsByPhotoID = Dictionary(
            grouping: visibleTags,
            by: \.portfolioPhotoID
        )
        .mapValues { tags in
            Set(tags.map { $0.signal.id })
        }
    }

}
