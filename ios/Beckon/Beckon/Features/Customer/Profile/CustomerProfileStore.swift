import Foundation
import Observation

@MainActor
@Observable
final class CustomerProfileStore {
    static let maximumAvatarPhotoBytes = 5 * 1024 * 1024

    private let customerID: UUID
    private let repository: any CustomerProfileRepository
    private let profileSnapshotCache: any ProfileSnapshotCaching
    private let sessionEmail: String?
    private let debugRecorder: AppDebugEventRecorder?
    let addressEditorState: BeckonAddressEditorState
    private var loadedAddressInput: BeckonAddressInput

    private(set) var profile: CustomerProfileDetails?
    private(set) var cachedProfileSnapshot: ProfileSnapshot?
    private(set) var avatarPhotoData: Data?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isUploading = false

    var errorMessage: String?
    var noticeMessage: String?

    var nickname = ""
    var streetAddress: String {
        get { addressEditorState.input.line1 }
        set { addressEditorState.updateLine1(newValue) }
    }
    var addressLine2: String {
        get { addressEditorState.input.line2 }
        set { addressEditorState.updateLine2(newValue) }
    }
    var city: String {
        get { addressEditorState.input.city }
        set { addressEditorState.updateCity(newValue) }
    }
    var stateCode: USStateCode? {
        get { addressEditorState.input.stateCode }
        set { addressEditorState.updateState(newValue) }
    }
    var zipCode: String {
        get { addressEditorState.input.postalCode }
        set { addressEditorState.updatePostalCode(newValue) }
    }
    var contactEmail = ""
    var phoneNumber = ""

    var isBusy: Bool {
        (isLoading && profile == nil) || isSaving || isUploading
    }

    var shouldShowInitialLoading: Bool {
        isLoading && profile == nil && cachedProfileSnapshot == nil
    }

    var profileDisplayName: String {
        Self.normalized(profile?.nickname)
            ?? Self.normalized(cachedProfileSnapshot?.displayName)
            ?? Self.normalized(nickname)
            ?? "Pet Owner"
    }

    var profileDetailText: String {
        if let profile {
            return Self.detailText(for: profile, fallbackEmail: sessionEmail)
        }

        return Self.normalized(cachedProfileSnapshot?.detailText)
            ?? Self.normalized(sessionEmail)
            ?? "Profile settings"
    }

    init(
        customerID: UUID,
        initialDisplayName: String,
        sessionEmail: String?,
        repository: any CustomerProfileRepository,
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
        self.customerID = customerID
        self.nickname = initialDisplayName
        self.contactEmail = sessionEmail ?? ""
        self.sessionEmail = sessionEmail
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
        isLoading = true
        errorMessage = nil
        populateCachedProfileSnapshot()

        do {
            let loadedProfile = try await repository.profile(customerID: customerID)
            profile = loadedProfile
            populateForm(with: loadedProfile)
            isLoading = false
            saveProfileSnapshot(profile: loadedProfile, avatarData: avatarPhotoData)

            let loadedAvatarPhoto = await avatarPhotoPayload(from: loadedProfile.avatarPath)
            if let loadedAvatarPath = loadedAvatarPhoto.path,
               loadedAvatarPath != profile?.avatarPath,
               var profile {
                profile.avatarPath = loadedAvatarPath
                self.profile = profile
            }
            avatarPhotoData = loadedAvatarPhoto.data ?? cachedProfileSnapshot?.avatarData
            saveProfileSnapshot(profile: profile, avatarData: avatarPhotoData)
            recordStoreSuccess(
                "load",
                startedAt: startedAt,
                metadata: [
                    "hasAvatar": "\(avatarPhotoData != nil)",
                    "hasAddress": "\(hasAddress)",
                    "hasPhone": "\(Self.normalized(phoneNumber) != nil)",
                ]
            )
        } catch CustomerProfileRepositoryError.cancelled {
            isLoading = false
            recordStoreCancelled("load", startedAt: startedAt)
        } catch let error as CustomerProfileRepositoryError {
            isLoading = false
            errorMessage = message(for: error, action: "load")
            recordStoreFailure("load", startedAt: startedAt, error: error)
        } catch {
            isLoading = false
            let mappedError = CustomerProfileRepositoryError.unavailable
            errorMessage = message(for: mappedError, action: "load")
            recordStoreFailure("load", startedAt: startedAt, error: error)
        }
    }

    func saveProfile() async {
        guard !isSaving else { return }

        let draft: CustomerProfileDraft
        let confirmedAddress: BeckonConfirmedAddress?
        do {
            draft = try makeDraft()
            confirmedAddress = try confirmedAddressForSave()
        } catch let error as CustomerProfileFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check your profile details and try again."
            return
        }

        let startedAt = Date()
        recordStoreStart("save")
        isSaving = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSaving = false }

        do {
            var updatedProfile = try await repository.updateProfile(
                customerID: customerID,
                draft: draft,
                confirmedAddress: confirmedAddress
            )
            if updatedProfile.avatarPath == nil {
                updatedProfile.avatarPath = profile?.avatarPath
            }
            updatedProfile.confirmedAddress = confirmedAddress ?? updatedProfile.confirmedAddress
            profile = updatedProfile
            populateForm(with: updatedProfile)
            saveProfileSnapshot(profile: updatedProfile, avatarData: avatarPhotoData)
            noticeMessage = "Profile saved."
            recordStoreSuccess("save", startedAt: startedAt)
        } catch CustomerProfileRepositoryError.cancelled {
            recordStoreCancelled("save", startedAt: startedAt)
        } catch let error as CustomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save")
            recordStoreFailure("save", startedAt: startedAt, error: error)
        } catch {
            let mappedError = CustomerProfileRepositoryError.unavailable
            errorMessage = message(for: mappedError, action: "save")
            recordStoreFailure("save", startedAt: startedAt, error: error)
        }
    }

    func uploadAvatarPhoto(
        data: Data,
        contentType: CustomerAvatarPhotoContentType
    ) async {
        guard !isUploading else { return }

        guard data.count <= Self.maximumAvatarPhotoBytes else {
            errorMessage = "Choose an avatar photo smaller than 5 MB."
            return
        }

        let startedAt = Date()
        recordStoreStart("uploadAvatar")
        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            let avatarPath = try await repository.uploadAvatarPhoto(
                customerID: customerID,
                data: data,
                contentType: contentType
            )
            if var profile {
                profile.avatarPath = avatarPath
                self.profile = profile
                saveProfileSnapshot(profile: profile, avatarData: data)
            } else {
                saveProfileSnapshot(profile: nil, avatarData: data)
            }
            avatarPhotoData = data
            noticeMessage = "Profile photo was updated."
            recordStoreSuccess(
                "uploadAvatar",
                startedAt: startedAt,
                metadata: ["contentType": contentType.rawValue]
            )
        } catch CustomerProfileRepositoryError.cancelled {
            recordStoreCancelled("uploadAvatar", startedAt: startedAt)
        } catch let error as CustomerProfileRepositoryError {
            errorMessage = message(for: error, action: "upload avatar")
            recordStoreFailure("uploadAvatar", startedAt: startedAt, error: error)
        } catch {
            let mappedError = CustomerProfileRepositoryError.unavailable
            errorMessage = message(for: mappedError, action: "upload avatar")
            recordStoreFailure("uploadAvatar", startedAt: startedAt, error: error)
        }
    }

    private var hasAddress: Bool {
        Self.normalized(streetAddress) != nil
            || Self.normalized(city) != nil
            || stateCode != nil
            || Self.normalized(zipCode) != nil
    }

    private func populateForm(with profile: CustomerProfileDetails) {
        nickname = profile.nickname
        let addressInput = BeckonAddressInput(
            line1: profile.streetAddress ?? "",
            line2: profile.addressLine2 ?? "",
            city: profile.city ?? "",
            stateCode: profile.stateCode,
            postalCode: profile.zipCode ?? "",
            countryCode: profile.confirmedAddress?.accepted.countryCode ?? "US"
        )
        addressEditorState.replaceInput(
            addressInput,
            confirmedAddress: profile.confirmedAddress
        )
        loadedAddressInput = normalizedAddressInput(addressInput)
        contactEmail = profile.contactEmail ?? sessionEmail ?? ""
        phoneNumber = profile.phoneNumber ?? ""
    }

    private func populateCachedProfileSnapshot() {
        guard let snapshot = profileSnapshotCache.snapshot(userID: customerID) else {
            return
        }

        cachedProfileSnapshot = snapshot
        if avatarPhotoData == nil {
            avatarPhotoData = snapshot.avatarData
        }
        if profile == nil {
            nickname = snapshot.displayName
        }
    }

    private func saveProfileSnapshot(
        profile: CustomerProfileDetails?,
        avatarData: Data?
    ) {
        let displayName = Self.normalized(profile?.nickname)
            ?? Self.normalized(nickname)
            ?? Self.normalized(cachedProfileSnapshot?.displayName)
            ?? "Pet Owner"
        let detailText = profile.map {
            Self.detailText(for: $0, fallbackEmail: sessionEmail)
        } ?? Self.normalized(contactEmail)
            ?? Self.normalized(sessionEmail)
            ?? Self.normalized(cachedProfileSnapshot?.detailText)
        let snapshot = ProfileSnapshot(
            userID: customerID,
            displayName: displayName,
            detailText: detailText,
            avatarData: avatarData
        )
        cachedProfileSnapshot = snapshot
        profileSnapshotCache.save(snapshot)
    }

    private static func detailText(
        for profile: CustomerProfileDetails,
        fallbackEmail: String?
    ) -> String {
        let cityState = [profile.city, profile.stateCode?.rawValue]
            .compactMap { normalized($0) }
            .joined(separator: ", ")
        return normalized(cityState)
            ?? normalized(profile.contactEmail)
            ?? normalized(fallbackEmail)
            ?? "Profile settings"
    }

    private func avatarPhotoPayload(from storagePath: String?) async -> (
        path: String?,
        data: Data?
    ) {
        let preferredPath = normalizedStoragePath(storagePath)
        let latestPath: String?

        do {
            latestPath = normalizedStoragePath(
                try await repository.latestAvatarPhotoPath(customerID: customerID)
            )
        } catch {
            latestPath = nil
        }

        var seenPaths: Set<String> = []
        for candidatePath in [latestPath, preferredPath].compactMap({ $0 })
            where seenPaths.insert(candidatePath).inserted {
            if let data = try? await repository.avatarPhotoData(storagePath: candidatePath) {
                return (candidatePath, data)
            }
        }

        return (preferredPath, nil)
    }

    private func normalizedStoragePath(_ storagePath: String?) -> String? {
        Self.normalized(storagePath)
    }

    private func makeDraft() throws -> CustomerProfileDraft {
        guard let normalizedNickname = Self.normalized(nickname) else {
            throw CustomerProfileFormError("Nickname must be 1-80 characters.")
        }
        guard normalizedNickname.count <= 80 else {
            throw CustomerProfileFormError("Nickname must be 1-80 characters.")
        }

        let normalizedStreet = Self.normalized(streetAddress)
        let normalizedCity = Self.normalized(city)
        let normalizedZip = Self.normalized(zipCode)
        let normalizedEmail = Self.normalized(contactEmail)
        let normalizedPhone = Self.normalized(phoneNumber)

        if let normalizedStreet, normalizedStreet.count > 160 {
            throw CustomerProfileFormError("Street address must be 160 characters or fewer.")
        }
        if let normalizedCity, normalizedCity.count > 80 {
            throw CustomerProfileFormError("City must be 80 characters or fewer.")
        }
        if let normalizedZip,
           normalizedZip.range(
            of: #"^[0-9]{5}(-[0-9]{4})?$"#,
            options: .regularExpression
           ) == nil {
            throw CustomerProfileFormError("Enter a valid ZIP code.")
        }
        if let normalizedEmail,
           normalizedEmail.range(
            of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#,
            options: .regularExpression
           ) == nil {
            throw CustomerProfileFormError("Enter a valid email address.")
        }
        if let normalizedPhone {
            guard normalizedPhone.count <= 32,
                  normalizedPhone.count >= 7,
                  normalizedPhone.range(
                    of: #"^[0-9+(). -]+$"#,
                    options: .regularExpression
                  ) != nil else {
                throw CustomerProfileFormError("Enter a valid phone number.")
            }
        }

        return CustomerProfileDraft(
            nickname: normalizedNickname,
            streetAddress: normalizedStreet,
            addressLine2: Self.normalized(addressLine2),
            city: normalizedCity,
            stateCode: stateCode,
            zipCode: normalizedZip,
            contactEmail: normalizedEmail,
            phoneNumber: normalizedPhone
        )
    }

    private func confirmedAddressForSave() throws -> BeckonConfirmedAddress? {
        let current = normalizedAddressInput(addressEditorState.input)
        let loaded = normalizedAddressInput(loadedAddressInput)
        if current == loaded, addressEditorState.confirmedAddress == nil {
            return nil
        }
        guard let confirmedAddress = addressEditorState.confirmedAddress,
              normalizedAddressInput(confirmedAddress.accepted) == current else {
            throw CustomerProfileFormError(
                "Confirm the changed address with Apple Maps before saving."
            )
        }
        return confirmedAddress
    }

    private func normalizedAddressInput(_ input: BeckonAddressInput) -> BeckonAddressInput {
        BeckonAddressInput(
            line1: input.line1.trimmingCharacters(in: .whitespacesAndNewlines),
            line2: input.line2.trimmingCharacters(in: .whitespacesAndNewlines),
            city: input.city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode: input.stateCode,
            postalCode: input.postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            countryCode: input.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )
    }

    private func message(
        for error: CustomerProfileRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) customer profile details."
        case .networkUnavailable:
            "The network connection was lost. Please try again."
        case .cancelled:
            "The profile \(action) was cancelled."
        case .unavailable:
            "We could not \(action) your profile. Please try again."
        }
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func recordStoreStart(_ operation: String) {
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "CustomerProfileStore.\(operation)",
            scope: "customer.profile",
            message: "started",
            metadata: ["operation": operation, "customerID": customerID.uuidString]
        )
    }

    private func recordStoreSuccess(
        _ operation: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        eventMetadata["customerID"] = customerID.uuidString
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "CustomerProfileStore.\(operation)",
            scope: "customer.profile",
            message: "success",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

    private func recordStoreFailure(
        _ operation: String,
        startedAt: Date,
        error: any Error
    ) {
        debugRecorder?.record(
            level: .error,
            category: .store,
            source: "CustomerProfileStore.\(operation)",
            scope: "customer.profile",
            message: "failure",
            underlyingError: error,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation, "customerID": customerID.uuidString]
        )
    }

    private func recordStoreCancelled(
        _ operation: String,
        startedAt: Date
    ) {
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "CustomerProfileStore.\(operation)",
            scope: "customer.profile",
            message: "cancelled",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation, "customerID": customerID.uuidString]
        )
    }
}

private struct CustomerProfileFormError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
