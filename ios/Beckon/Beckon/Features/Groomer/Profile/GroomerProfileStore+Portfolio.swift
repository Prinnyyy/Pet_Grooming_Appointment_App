import Foundation

extension GroomerProfileStore {
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

    func isPortfolioPhotoDataUnavailable(_ photo: GroomerPortfolioPhoto) -> Bool {
        attemptedPortfolioPhotoDataIDs.contains(photo.id) &&
            portfolioPhotoDataByID[photo.id] == nil
    }

    var portfolioOverviewSummary: String {
        switch portfolioPhotos.count {
        case 0:
            "No work photos"
        case 1:
            "1 work photo"
        default:
            "\(portfolioPhotos.count) work photos"
        }
    }

    func portfolioFitTagSummary(for photo: GroomerPortfolioPhoto) -> String {
        let tags = portfolioFitTags(for: photo)
        guard !tags.isEmpty else {
            return "No fit notes"
        }

        let visibleTitles = tags.prefix(2).map(\.signal.title)
        let summary = visibleTitles.joined(separator: " • ")
        let remainingCount = tags.count - visibleTitles.count

        return remainingCount > 0
            ? "\(summary) +\(remainingCount)"
            : summary
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
        profileMutationRevision += 1
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
            attemptedPortfolioPhotoDataIDs.insert(photo.id)
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
        profileMutationRevision += 1
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            try await repository.deletePortfolioPhoto(photo)
            portfolioPhotos.removeAll { $0.id == photo.id }
            portfolioPhotoDataByID[photo.id] = nil
            attemptedPortfolioPhotoDataIDs.remove(photo.id)
            removePortfolioFitTags(for: photo.id)
            noticeMessage = "Portfolio photo was deleted."
        } catch let error as GroomerProfileRepositoryError {
            errorMessage = message(for: error, action: "delete photo")
        } catch {
            errorMessage = message(for: .unavailable, action: "delete photo")
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
        guard canEditPortfolioTags else {
            errorMessage = "Refresh portfolio details before saving tags."
            return
        }

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
        profileMutationRevision += 1
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

    private func removePortfolioFitTags(for photoID: UUID) {
        portfolioFitTags.removeAll { $0.portfolioPhotoID == photoID }
        selectedPortfolioFitTagIDsByPhotoID.removeValue(forKey: photoID)
    }

    private func replacePortfolioFitTags(
        for photoID: UUID,
        with tags: [GroomerPortfolioFitTag]
    ) {
        removePortfolioFitTags(for: photoID)

        let supportedSignals = Set(PetFitSignal.allCases)
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

    private func makePortfolioFitTagDrafts(
        for photo: GroomerPortfolioPhoto
    ) -> [GroomerPortfolioFitTagDraft] {
        let selectedIDs = selectedPortfolioFitTagIDsByPhotoID[photo.id] ?? []

        return GroomerPortfolioFitTag.availableSignals
            .filter { selectedIDs.contains($0.id) }
            .sorted(by: Self.sortFitSignals)
            .map { GroomerPortfolioFitTagDraft(signal: $0) }
    }

}
