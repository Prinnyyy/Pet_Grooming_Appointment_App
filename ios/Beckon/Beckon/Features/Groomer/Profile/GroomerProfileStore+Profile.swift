import Foundation

extension GroomerProfileStore {
    func saveProfile() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        let draft: GroomerProfileDraft
        let confirmedAddress: BeckonConfirmedAddress?
        do {
            draft = try makeProfileDraft()
            confirmedAddress = try confirmedAddressForSave()
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
                draft: draft,
                confirmedAddress: confirmedAddress
            )
            if updatedProfile.avatarPath == nil {
                updatedProfile.avatarPath = currentAvatarPath
            }
            updatedProfile.confirmedAddress = confirmedAddress ?? updatedProfile.confirmedAddress
            profile = updatedProfile
            populateProfileForm(with: updatedProfile)
            saveProfileSnapshot(profile: updatedProfile, avatarData: avatarPhotoData)
            noticeMessage = "Groomer profile saved."
        } catch GroomerProfileRepositoryError.cancelled {
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "save")
        } catch {
            errorMessage = message(for: .unavailable, action: "save")
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
            saveProfileSnapshot(profile: profile, avatarData: data)
            noticeMessage = "Profile photo was updated."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "upload avatar")
        } catch {
            errorMessage = message(for: .unavailable, action: "upload avatar")
        }
    }

    func makeProfileDraft() throws -> GroomerProfileDraft {
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
            baseAddressLine2: try optional(
                baseAddressLine2,
                field: "Address Line 2",
                maximum: 60
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

    private func confirmedAddressForSave() throws -> BeckonConfirmedAddress? {
        let current = normalizedAddressInput(addressEditorState.input)
        let loaded = normalizedAddressInput(loadedAddressInput)
        if current == loaded, addressEditorState.confirmedAddress == nil {
            return nil
        }
        guard let confirmedAddress = addressEditorState.confirmedAddress,
              normalizedAddressInput(confirmedAddress.accepted) == current else {
            throw GroomerProfileFormError(
                message: "Confirm the changed address with Apple Maps before saving."
            )
        }
        return confirmedAddress
    }

}
