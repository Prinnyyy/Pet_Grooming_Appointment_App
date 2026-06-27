import Foundation
import Observation

@MainActor
@Observable
final class GroomerProfileStore {
    static let maximumPhotoBytes = 10 * 1024 * 1024
    static let maximumAvatarPhotoBytes = 5 * 1024 * 1024

    private let groomerID: UUID
    private let repository: any GroomerProfileRepository
    private var profileMutationRevision = 0

    private(set) var profile: GroomerProfile?
    private(set) var services: [GroomerService] = []
    private(set) var portfolioPhotos: [GroomerPortfolioPhoto] = []
    private(set) var portfolioPhotoDataByID: [UUID: Data] = [:]
    private(set) var portfolioFitTags: [GroomerPortfolioFitTag] = []
    private(set) var selectedPortfolioFitTagIDsByPhotoID: [UUID: Set<String>] = [:]
    private(set) var availabilityWindows: [GroomerAvailabilityWindow] = []
    private(set) var bookingPreferences: GroomerBookingPreferences?
    private(set) var timeOffWindows: [GroomerTimeOffWindow] = []
    private(set) var fitClaims: [GroomerFitClaim] = []
    private(set) var petFitEvidenceSummary: [GroomerPetFitEvidenceSummary] = []
    private(set) var selectedFitClaimIDs: Set<String> = []
    private(set) var avatarPhotoData: Data?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isUploading = false

    var errorMessage: String?
    var noticeMessage: String?

    var businessName = ""
    var bio = ""
    var yearsExperience = 0
    var baseStreetAddress = ""
    var baseCity = ""
    var baseState = ""
    var baseStateCode: USStateCode?
    var baseZipCode = ""
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

    init(
        groomerID: UUID,
        repository: any GroomerProfileRepository
    ) {
        self.groomerID = groomerID
        self.repository = repository
    }

    func load() async {
        let loadRevision = profileMutationRevision
        isLoading = true
        errorMessage = nil

        do {
            let loadedProfile = try await repository.profile(groomerID: groomerID)
            let loadedServices = try await repository.services(groomerID: groomerID)
            let loadedPhotos = try await repository.portfolioPhotos(groomerID: groomerID)
            let loadedPortfolioFitTags = try await repository.portfolioFitTags(
                groomerID: groomerID
            )
            let loadedAvailability = try await repository.availabilityWindows(groomerID: groomerID)
            let loadedBookingPreferences = try await repository.bookingPreferences(groomerID: groomerID)
            let loadedTimeOff = try await repository.timeOffWindows(groomerID: groomerID)
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
            populatePortfolioFitTags(
                with: loadedPortfolioFitTags,
                visiblePhotos: loadedPhotos
            )
            availabilityWindows = loadedAvailability
            bookingPreferences = loadedBookingPreferences
            timeOffWindows = loadedTimeOff
            populateFitClaims(with: loadedFitClaims)
            populatePetFitEvidenceSummary(with: loadedPetFitEvidenceSummary)
            populateProfileForm(with: loadedProfile)
            populateAvailabilityForm(with: loadedAvailability)
            populateBookingPreferencesForm(with: loadedBookingPreferences)
            resetTimeOffForm()
            isLoading = false

            let loadedPortfolioPhotoData = await portfolioPhotoDataMap(
                for: loadedPhotos
            )
            guard loadRevision == profileMutationRevision else {
                return
            }
            portfolioPhotoDataByID = loadedPortfolioPhotoData

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
            avatarPhotoData = loadedAvatarPhoto.data
        } catch let error as GroomerProfileRepositoryError {
            isLoading = false
            errorMessage = message(for: error, action: "load")
        } catch {
            isLoading = false
            errorMessage = message(for: .unavailable, action: "load")
        }
    }

    func sortedPortfolioPhotos() -> [GroomerPortfolioPhoto] {
        portfolioPhotos.sorted {
            if $0.sortOrder == $1.sortOrder {
                $0.fileName < $1.fileName
            } else {
                $0.sortOrder < $1.sortOrder
            }
        }
    }

    func portfolioPhotoData(for photo: GroomerPortfolioPhoto) -> Data? {
        portfolioPhotoDataByID[photo.id]
    }

    func sortedPetFitEvidenceSummary() -> [GroomerPetFitEvidenceSummary] {
        petFitEvidenceSummary.sorted(by: Self.sortPetFitEvidenceSummary)
    }

    func saveProfile() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        let draft: GroomerProfileDraft
        do {
            draft = try makeProfileDraft()
        } catch let error as GroomerProfileFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check your profile details and try again."
            return
        }

        isSaving = true
        profileMutationRevision += 1
        defer { isSaving = false }

        do {
            let currentAvatarPath = profile?.avatarPath
            var updatedProfile = try await repository.updateProfile(
                groomerID: groomerID,
                draft: draft
            )
            if updatedProfile.avatarPath == nil {
                updatedProfile.avatarPath = currentAvatarPath
            }
            profile = updatedProfile
            populateProfileForm(with: updatedProfile)
            noticeMessage = "Groomer profile saved."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save")
        } catch {
            errorMessage = message(for: .unavailable, action: "save")
        }
    }

    func startCreateService() {
        editingServiceID = nil
        resetServiceForm()
        errorMessage = nil
        noticeMessage = nil
        isShowingServiceForm = true
    }

    func startEditService(_ service: GroomerService) {
        editingServiceID = service.id
        serviceType = service.serviceType
        serviceTitle = service.title
        serviceDescription = service.description ?? ""
        serviceBasePrice = Self.displayPrice(service.basePrice)
        serviceDurationMinutes = String(service.durationMinutes)
        selectedServiceSizes = Set(service.acceptedPetSizes)
        serviceIsActive = service.isActive
        errorMessage = nil
        noticeMessage = nil
        isShowingServiceForm = true
    }

    func cancelServiceForm() {
        isShowingServiceForm = false
        editingServiceID = nil
        resetServiceForm()
    }

    func saveService() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        let draft: GroomerServiceDraft
        do {
            draft = try makeServiceDraft()
        } catch let error as GroomerProfileFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check your service details and try again."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            if let editingServiceID,
               let currentService = services.first(where: { $0.id == editingServiceID }) {
                let service = try await repository.updateService(
                    service: currentService,
                    draft: draft
                )
                replace(service)
                noticeMessage = "\(service.title) was updated."
            } else {
                let service = try await repository.createService(
                    groomerID: groomerID,
                    draft: draft
                )
                services.insert(service, at: 0)
                noticeMessage = "\(service.title) was added."
            }

            isShowingServiceForm = false
            editingServiceID = nil
            resetServiceForm()
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save")
        } catch {
            errorMessage = message(for: .unavailable, action: "save")
        }
    }

    func deleteService(_ service: GroomerService) async {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSaving = false }

        do {
            try await repository.deleteService(service)
            services.removeAll { $0.id == service.id }
            noticeMessage = "\(service.title) was deleted."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "delete")
        } catch {
            errorMessage = message(for: .unavailable, action: "delete")
        }
    }

    func uploadPortfolioPhoto(
        data: Data,
        contentType: GroomerPortfolioPhotoContentType
    ) async {
        guard !isUploading else { return }

        guard data.count <= Self.maximumPhotoBytes else {
            errorMessage = "Choose a portfolio photo smaller than 10 MB."
            return
        }

        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            let photo = try await repository.uploadPortfolioPhoto(
                groomerID: groomerID,
                data: data,
                contentType: contentType,
                caption: nil
            )
            portfolioPhotos.append(photo)
            portfolioPhotoDataByID[photo.id] = data
            noticeMessage = "Portfolio photo was uploaded."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "upload")
        } catch {
            errorMessage = message(for: .unavailable, action: "upload")
        }
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async {
        guard !isUploading else { return }

        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            try await repository.deletePortfolioPhoto(photo)
            portfolioPhotos.removeAll { $0.id == photo.id }
            portfolioPhotoDataByID[photo.id] = nil
            removePortfolioFitTags(for: photo.id)
            noticeMessage = "Portfolio photo was deleted."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "delete photo")
        } catch {
            errorMessage = message(for: .unavailable, action: "delete photo")
        }
    }

    func uploadAvatarPhoto(
        data: Data,
        contentType: GroomerAvatarPhotoContentType
    ) async {
        guard !isUploading else { return }

        guard data.count <= Self.maximumAvatarPhotoBytes else {
            errorMessage = "Choose an avatar photo smaller than 5 MB."
            return
        }

        isUploading = true
        profileMutationRevision += 1
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            let avatarPath = try await repository.uploadAvatarPhoto(
                groomerID: groomerID,
                data: data,
                contentType: contentType
            )
            if var profile {
                profile.avatarPath = avatarPath
                self.profile = profile
            }
            avatarPhotoData = data
            noticeMessage = "Profile photo was updated."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "upload avatar")
        } catch {
            errorMessage = message(for: .unavailable, action: "upload avatar")
        }
    }

    func setAvailability(
        day: GroomerAvailabilityWeekday,
        isEnabled: Bool,
        startMinutes: Int,
        endMinutes: Int
    ) {
        guard let index = availabilityDayStates.firstIndex(where: { $0.weekday == day }) else {
            return
        }

        availabilityDayStates[index].isEnabled = isEnabled
        availabilityDayStates[index].startMinutes = startMinutes
        availabilityDayStates[index].endMinutes = endMinutes
    }

    func saveAvailability() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        let profileDraft: GroomerProfileDraft
        let drafts: [GroomerAvailabilityDraft]
        let preferencesDraft: GroomerBookingPreferencesDraft
        do {
            profileDraft = try makeProfileDraft()
            drafts = try makeAvailabilityDrafts()
            preferencesDraft = try makeBookingPreferencesDraft()
        } catch let error as GroomerProfileFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check your availability and try again."
            return
        }

        isSaving = true
        profileMutationRevision += 1
        defer { isSaving = false }

        do {
            let currentAvatarPath = profile?.avatarPath
            var updatedProfile = try await repository.updateProfile(
                groomerID: groomerID,
                draft: profileDraft
            )
            if updatedProfile.avatarPath == nil {
                updatedProfile.avatarPath = currentAvatarPath
            }
            let updatedWindows = try await repository.replaceAvailability(
                groomerID: groomerID,
                drafts: drafts
            )
            let updatedPreferences = try await repository.updateBookingPreferences(
                groomerID: groomerID,
                draft: preferencesDraft
            )
            profile = updatedProfile
            availabilityWindows = updatedWindows
            bookingPreferences = updatedPreferences
            populateProfileForm(with: updatedProfile)
            populateAvailabilityForm(with: updatedWindows)
            populateBookingPreferencesForm(with: updatedPreferences)
            noticeMessage = "Availability saved."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save availability")
        } catch {
            errorMessage = message(for: .unavailable, action: "save availability")
        }
    }

    func startCreateTimeOff() {
        resetTimeOffForm()
        errorMessage = nil
        noticeMessage = nil
        isShowingTimeOffForm = true
    }

    func cancelTimeOffForm() {
        resetTimeOffForm()
        isShowingTimeOffForm = false
    }

    func createTimeOff() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        let draft: GroomerTimeOffDraft
        do {
            draft = try makeTimeOffDraft()
        } catch let error as GroomerProfileFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check your time off dates and try again."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let window = try await repository.createTimeOff(
                groomerID: groomerID,
                draft: draft
            )
            timeOffWindows.append(window)
            timeOffWindows.sort {
                if $0.startDate == $1.startDate {
                    $0.title < $1.title
                } else {
                    $0.startDate < $1.startDate
                }
            }
            isShowingTimeOffForm = false
            resetTimeOffForm()
            noticeMessage = "Time off added."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save time off")
        } catch {
            errorMessage = message(for: .unavailable, action: "save time off")
        }
    }

    func deleteTimeOff(_ window: GroomerTimeOffWindow) async {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSaving = false }

        do {
            try await repository.deleteTimeOff(window)
            timeOffWindows.removeAll { $0.id == window.id }
            noticeMessage = "Time off removed."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "delete time off")
        } catch {
            errorMessage = message(for: .unavailable, action: "delete time off")
        }
    }

    func isFitClaimSelected(_ signal: PetFitSignal) -> Bool {
        selectedFitClaimIDs.contains(signal.id)
    }

    func toggleFitClaim(_ signal: PetFitSignal) {
        errorMessage = nil
        noticeMessage = nil

        if selectedFitClaimIDs.contains(signal.id) {
            selectedFitClaimIDs.remove(signal.id)
            return
        }

        guard selectedFitClaimIDs.count < GroomerFitClaim.maximumActiveClaims else {
            errorMessage = "Choose up to \(GroomerFitClaim.maximumActiveClaims) starter fit signals."
            return
        }

        selectedFitClaimIDs.insert(signal.id)
    }

    func saveFitClaims() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        guard selectedFitClaimIDs.count <= GroomerFitClaim.maximumActiveClaims else {
            errorMessage = "Choose up to \(GroomerFitClaim.maximumActiveClaims) starter fit signals."
            return
        }

        let drafts = makeFitClaimDrafts()

        isSaving = true
        defer { isSaving = false }

        do {
            let updatedClaims = try await repository.replaceFitClaims(
                groomerID: groomerID,
                drafts: drafts
            )
            populateFitClaims(with: updatedClaims)
            noticeMessage = "Fit signals saved."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save fit signals")
        } catch {
            errorMessage = message(for: .unavailable, action: "save fit signals")
        }
    }

    func portfolioFitTags(for photo: GroomerPortfolioPhoto) -> [GroomerPortfolioFitTag] {
        portfolioFitTags.filter { $0.portfolioPhotoID == photo.id }
    }

    func isPortfolioFitTagSelected(
        _ signal: PetFitSignal,
        for photo: GroomerPortfolioPhoto
    ) -> Bool {
        selectedPortfolioFitTagIDsByPhotoID[photo.id]?.contains(signal.id) == true
    }

    func togglePortfolioFitTag(
        _ signal: PetFitSignal,
        for photo: GroomerPortfolioPhoto
    ) {
        errorMessage = nil
        noticeMessage = nil

        var selectedIDs = selectedPortfolioFitTagIDsByPhotoID[photo.id] ?? []
        if selectedIDs.contains(signal.id) {
            selectedIDs.remove(signal.id)
            if selectedIDs.isEmpty {
                selectedPortfolioFitTagIDsByPhotoID.removeValue(forKey: photo.id)
            } else {
                selectedPortfolioFitTagIDsByPhotoID[photo.id] = selectedIDs
            }
            return
        }

        guard selectedIDs.count < GroomerPortfolioFitTag.maximumTagsPerPhoto else {
            errorMessage = "Choose up to \(GroomerPortfolioFitTag.maximumTagsPerPhoto) tags for each portfolio photo."
            return
        }

        selectedIDs.insert(signal.id)
        selectedPortfolioFitTagIDsByPhotoID[photo.id] = selectedIDs
    }

    func savePortfolioFitTags(for photo: GroomerPortfolioPhoto) async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        guard portfolioPhotos.contains(where: { $0.id == photo.id }) else {
            errorMessage = "We could not save tags for that portfolio photo."
            return
        }

        let selectedIDs = selectedPortfolioFitTagIDsByPhotoID[photo.id] ?? []
        guard selectedIDs.count <= GroomerPortfolioFitTag.maximumTagsPerPhoto else {
            errorMessage = "Choose up to \(GroomerPortfolioFitTag.maximumTagsPerPhoto) tags for each portfolio photo."
            return
        }

        let drafts = makePortfolioFitTagDrafts(for: photo)

        isSaving = true
        defer { isSaving = false }

        do {
            let updatedTags = try await repository.replacePortfolioFitTags(
                groomerID: groomerID,
                photoID: photo.id,
                drafts: drafts
            )
            replacePortfolioFitTags(for: photo.id, with: updatedTags)
            noticeMessage = "Portfolio tags saved."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save portfolio tags")
        } catch {
            errorMessage = message(for: .unavailable, action: "save portfolio tags")
        }
    }

    private func populateProfileForm(with profile: GroomerProfile) {
        businessName = profile.businessName ?? ""
        bio = profile.bio ?? ""
        yearsExperience = min(max(profile.yearsExperience ?? 0, 0), 5)
        baseStreetAddress = profile.baseStreetAddress ?? ""
        baseCity = profile.baseCity ?? ""
        baseState = profile.baseState ?? ""
        baseStateCode = profile.baseState.flatMap(USStateCode.init(rawValue:))
        baseZipCode = profile.baseZipCode ?? ""
        serviceRadiusMiles = min(max(profile.serviceRadiusMiles ?? 12, 5), 50)
        serviceLocationModes = profile.effectiveServiceLocationModes
        isActive = profile.isActive
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
    ) async -> [UUID: Data] {
        var dataByID: [UUID: Data] = [:]
        for photo in photos {
            guard let data = try? await repository.portfolioPhotoData(photo) else {
                continue
            }
            dataByID[photo.id] = data
        }
        return dataByID
    }

    private func populateAvailabilityForm(with windows: [GroomerAvailabilityWindow]) {
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

    private func populateBookingPreferencesForm(with preferences: GroomerBookingPreferences) {
        maxAppointmentsPerDay = min(max(preferences.maxAppointmentsPerDay, 1), 12)
        minimumAdvanceNoticeDays = min(max(preferences.minimumAdvanceNoticeDays, 0), 2)
        autoAcceptBookings = preferences.autoAcceptBookings
    }

    private func populateFitClaims(with claims: [GroomerFitClaim]) {
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
        let supportedSignals = Set(GroomerPortfolioFitTag.availableSignals)
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

    private func resetTimeOffForm() {
        timeOffTitle = ""
        let today = Calendar.current.startOfDay(for: Date())
        timeOffStartDate = today
        timeOffEndDate = today
    }

    private func resetServiceForm() {
        serviceType = .fullGroom
        serviceTitle = GroomingServiceType.fullGroom.title
        serviceDescription = ""
        serviceBasePrice = ""
        serviceDurationMinutes = ""
        selectedServiceSizes = []
        serviceIsActive = true
    }

    private func replace(_ service: GroomerService) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else {
            services.insert(service, at: 0)
            return
        }
        services[index] = service
    }

    private func removePortfolioFitTags(for photoID: UUID) {
        portfolioFitTags.removeAll { $0.portfolioPhotoID == photoID }
        selectedPortfolioFitTagIDsByPhotoID.removeValue(forKey: photoID)
    }

    private func replacePortfolioFitTags(
        for photoID: UUID,
        with tags: [GroomerPortfolioFitTag]
    ) {
        removePortfolioFitTags(for: photoID)

        let supportedSignals = Set(GroomerPortfolioFitTag.availableSignals)
        let supportedTags = tags.filter {
            $0.portfolioPhotoID == photoID && supportedSignals.contains($0.signal)
        }

        portfolioFitTags.append(contentsOf: supportedTags)
        portfolioFitTags.sort(by: Self.sortPortfolioFitTags)

        let selectedIDs = Set(supportedTags.map { $0.signal.id })
        if !selectedIDs.isEmpty {
            selectedPortfolioFitTagIDsByPhotoID[photoID] = selectedIDs
        }
    }

    private func makeProfileDraft() throws -> GroomerProfileDraft {
        let draft = GroomerProfileDraft(
            businessName: try optional(
                businessName,
                field: "Business name",
                maximum: 120
            ),
            bio: try optional(bio, field: "Biography", maximum: 2000),
            yearsExperience: min(max(yearsExperience, 0), 5),
            baseStreetAddress: try optional(
                baseStreetAddress,
                field: "Street address",
                maximum: 160
            ),
            baseCity: try optional(baseCity, field: "City", maximum: 100),
            baseStateCode: baseStateCode,
            baseZipCode: try optionalZipCode(baseZipCode),
            serviceRadiusMiles: min(max(serviceRadiusMiles, 5), 50),
            serviceLocationMode: serviceLocationModes.primaryMode,
            serviceLocationModes: serviceLocationModes,
            isActive: isActive
        )

        if draft.isActive,
           (draft.businessName == nil
            || draft.baseStreetAddress == nil
            || draft.baseCity == nil
            || draft.baseStateCode == nil
            || draft.baseZipCode == nil
            || draft.serviceRadiusMiles == nil) {
            throw GroomerProfileFormError(
                message: "Complete business name, address, city, state, ZIP, and service radius before going active."
            )
        }

        if draft.isActive, draft.serviceLocationModes.isEmpty {
            throw GroomerProfileFormError(
                message: "Choose whether you travel to customers or host appointments before going active."
            )
        }

        return draft
    }

    private func makeServiceDraft() throws -> GroomerServiceDraft {
        let serviceTitle = serviceType.title
        return GroomerServiceDraft(
            serviceType: serviceType,
            title: serviceTitle,
            description: try optional(
                serviceDescription,
                field: "Description",
                maximum: 500
            ),
            basePrice: try price(from: serviceBasePrice),
            durationMinutes: try requiredInteger(
                serviceDurationMinutes,
                field: "Duration",
                range: 15...720
            ),
            acceptedPetSizes: GroomerServicePetSize.allCases.filter {
                selectedServiceSizes.contains($0)
            },
            isActive: serviceIsActive
        )
    }

    private func makeAvailabilityDrafts() throws -> [GroomerAvailabilityDraft] {
        try availabilityDayStates
            .sorted { $0.weekday.rawValue < $1.weekday.rawValue }
            .map { state in
                guard state.startMinutes >= 0,
                      state.endMinutes <= 23 * 60 + 59 else {
                    throw GroomerProfileFormError(
                        message: "\(state.weekday.title) availability must stay within one day."
                    )
                }

                if state.isEnabled, state.endMinutes <= state.startMinutes {
                    throw GroomerProfileFormError(
                        message: "\(state.weekday.title) availability needs an end time after the start time."
                    )
                }

                return GroomerAvailabilityDraft(
                    weekday: state.weekday,
                    startMinutes: state.startMinutes,
                    endMinutes: state.endMinutes,
                    isEnabled: state.isEnabled,
                    timezone: availabilityTimezone
                )
            }
    }

    private func makeBookingPreferencesDraft() throws -> GroomerBookingPreferencesDraft {
        guard (1...12).contains(maxAppointmentsPerDay) else {
            throw GroomerProfileFormError(
                message: "Max appointments per day must be 1–12."
            )
        }

        guard (0...2).contains(minimumAdvanceNoticeDays) else {
            throw GroomerProfileFormError(
                message: "Minimum advance notice must be Same day, 1 day, or 2 days."
            )
        }

        return GroomerBookingPreferencesDraft(
            maxAppointmentsPerDay: maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: minimumAdvanceNoticeDays,
            autoAcceptBookings: autoAcceptBookings
        )
    }

    private func makeTimeOffDraft() throws -> GroomerTimeOffDraft {
        let title = try required(
            timeOffTitle,
            field: "Time off title",
            range: 1...80
        )
        let startDate = Calendar.current.startOfDay(for: timeOffStartDate)
        let endDate = Calendar.current.startOfDay(for: timeOffEndDate)

        guard endDate >= startDate else {
            throw GroomerProfileFormError(
                message: "Time off end date must be on or after the start date."
            )
        }

        return GroomerTimeOffDraft(
            title: title,
            startDate: Self.dateString(from: startDate),
            endDate: Self.dateString(from: endDate)
        )
    }

    private func makeFitClaimDrafts() -> [GroomerFitClaimDraft] {
        let supportedSignals = Set(GroomerFitClaim.availableSignals)
        let knownSignals = Set(
            fitClaims
                .map(\.signal)
                .filter { supportedSignals.contains($0) }
        )
        let selectedSignals = Set(
            GroomerFitClaim.availableSignals.filter {
                selectedFitClaimIDs.contains($0.id)
            }
        )

        return knownSignals
            .union(selectedSignals)
            .sorted(by: Self.sortFitSignals)
            .map { signal in
                GroomerFitClaimDraft(
                    signal: signal,
                    isActive: selectedFitClaimIDs.contains(signal.id)
                )
            }
    }

    private func makePortfolioFitTagDrafts(
        for photo: GroomerPortfolioPhoto
    ) -> [GroomerPortfolioFitTagDraft] {
        let selectedIDs = selectedPortfolioFitTagIDsByPhotoID[photo.id] ?? []

        return GroomerPortfolioFitTag.availableSignals
            .filter { selectedIDs.contains($0.id) }
            .sorted(by: Self.sortFitSignals)
            .map { GroomerPortfolioFitTagDraft(signal: $0) }
    }

    private func required(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard range.contains(trimmed.count) else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound) characters."
            )
        }
        return trimmed
    }

    private func optional(
        _ value: String,
        field: String,
        maximum: Int
    ) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= maximum else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(maximum) characters or fewer."
            )
        }
        return trimmed
    }

    private func optionalInteger(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try integer(trimmed, field: field, range: range)
    }

    private func requiredInteger(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound)."
            )
        }
        return try integer(trimmed, field: field, range: range)
    }

    private func optionalZipCode(_ value: String) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let pattern = #"^[0-9]{5}(-[0-9]{4})?$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
            throw GroomerProfileFormError(
                message: "ZIP must be a valid 5-digit ZIP code."
            )
        }

        return trimmed
    }

    private func integer(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> Int {
        guard let integer = Int(value), range.contains(integer) else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound)."
            )
        }
        return integer
    }

    private func price(from value: String) throws -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let price = Double(trimmed),
              price >= 0,
              price <= 100000 else {
            throw GroomerProfileFormError(
                message: "Base price must be between 0 and 100000."
            )
        }

        if let decimals = trimmed.split(separator: ".").dropFirst().first,
           decimals.count > 2 {
            throw GroomerProfileFormError(
                message: "Base price can use at most 2 decimal places."
            )
        }

        return price
    }

    private static func displayPrice(_ price: Double) -> String {
        if price.rounded() == price {
            return String(Int(price))
        }
        return String(format: "%.2f", price)
    }

    private static func sortFitClaims(
        _ lhs: GroomerFitClaim,
        _ rhs: GroomerFitClaim
    ) -> Bool {
        sortFitSignals(lhs.signal, rhs.signal)
    }

    private static func sortPortfolioFitTags(
        _ lhs: GroomerPortfolioFitTag,
        _ rhs: GroomerPortfolioFitTag
    ) -> Bool {
        if lhs.portfolioPhotoID == rhs.portfolioPhotoID {
            return sortFitSignals(lhs.signal, rhs.signal)
        }
        return lhs.portfolioPhotoID.uuidString < rhs.portfolioPhotoID.uuidString
    }

    private static func sortPetFitEvidenceSummary(
        _ lhs: GroomerPetFitEvidenceSummary,
        _ rhs: GroomerPetFitEvidenceSummary
    ) -> Bool {
        if lhs.confidenceTier.sortOrder != rhs.confidenceTier.sortOrder {
            return lhs.confidenceTier.sortOrder < rhs.confidenceTier.sortOrder
        }
        if lhs.completedBookingCount != rhs.completedBookingCount {
            return lhs.completedBookingCount > rhs.completedBookingCount
        }
        if lhs.positiveReviewOutcomeCount != rhs.positiveReviewOutcomeCount {
            return lhs.positiveReviewOutcomeCount > rhs.positiveReviewOutcomeCount
        }
        if lhs.structuredReviewOutcomeCount != rhs.structuredReviewOutcomeCount {
            return lhs.structuredReviewOutcomeCount > rhs.structuredReviewOutcomeCount
        }
        return sortFitSignals(lhs.signal, rhs.signal)
    }

    private static func sortFitSignals(
        _ lhs: PetFitSignal,
        _ rhs: PetFitSignal
    ) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            if lhs.title == rhs.title {
                return lhs.id < rhs.id
            }
            return lhs.title < rhs.title
        }
        return lhs.sortOrder < rhs.sortOrder
    }

    static func dateString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 1,
            components.day ?? 1
        )
    }

    private func message(
        for error: GroomerProfileRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) groomer profile details."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not \(action) groomer profile details. Please try again."
        }
    }
}

private struct GroomerProfileFormError: Error {
    let message: String
}

struct GroomerAvailabilityDayState: Equatable, Identifiable {
    let weekday: GroomerAvailabilityWeekday
    var isEnabled: Bool
    var startMinutes: Int
    var endMinutes: Int

    var id: GroomerAvailabilityWeekday { weekday }

    var summary: String {
        isEnabled
            ? "\(GroomerAvailabilityWindow.displayTime(fromMinutes: startMinutes)) - \(GroomerAvailabilityWindow.displayTime(fromMinutes: endMinutes))"
            : "Unavailable"
    }

    static func defaultStates() -> [GroomerAvailabilityDayState] {
        GroomerAvailabilityWeekday.allCases.map {
            GroomerAvailabilityDayState(
                weekday: $0,
                isEnabled: false,
                startMinutes: 9 * 60,
                endMinutes: 17 * 60
            )
        }
    }
}
