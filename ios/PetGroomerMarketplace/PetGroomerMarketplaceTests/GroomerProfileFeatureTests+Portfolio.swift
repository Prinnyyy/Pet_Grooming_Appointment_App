import Foundation
import Testing
import UIKit
@testable import PetGroomerMarketplace

extension GroomerProfileStoreTests {
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
        store.togglePortfolioFitTag(.coatType(.curlyWavy), for: photo)
        await store.savePortfolioFitTags(for: photo)

        #expect(repository.replacePortfolioFitTagsCallCount == 1)
        #expect(repository.lastPortfolioFitTagPhotoID == photo.id)
        #expect(repository.lastPortfolioFitTagDrafts == [
            GroomerPortfolioFitTagDraft(signal: .coatType(.curlyWavy)),
            GroomerPortfolioFitTagDraft(signal: .careFlag(.senior)),
        ])
        #expect(
            store.selectedPortfolioFitTagIDsByPhotoID[photo.id] == [
                PetFitSignal.coatType(.curlyWavy).id,
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
    func portfolioPresentationSummariesUseCustomerFacingCountsAndFitNotes() async {
        let groomerID = UUID()
        let firstPhoto = Self.photo(groomerID: groomerID)
        let secondPhoto = Self.photo(groomerID: groomerID)
        let coatTag = Self.portfolioFitTag(
            photoID: firstPhoto.id,
            groomerID: groomerID,
            signal: .coatType(.curlyWavy)
        )
        let careTag = Self.portfolioFitTag(
            photoID: firstPhoto.id,
            groomerID: groomerID,
            signal: .serviceFit(.seniorCare)
        )
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(Self.profile(groomerID: groomerID)),
            portfolioResult: .success([firstPhoto, secondPhoto]),
            portfolioFitTagsResult: .success([coatTag, careTag])
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(store.portfolioOverviewSummary == "2 work photos")
        #expect(store.portfolioFitTagSummary(for: firstPhoto) == "Curly / Wavy • Senior Care")
        #expect(store.portfolioFitTagSummary(for: secondPhoto) == "No fit notes")
    }

    @Test @MainActor
    func loadMarksPortfolioPhotoUnavailableWhenImageDataCannotBeRead() async {
        let groomerID = UUID()
        let photo = Self.photo(groomerID: groomerID)
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(Self.profile(groomerID: groomerID)),
            portfolioResult: .success([photo]),
            portfolioPhotoDataResultsByID: [
                photo.id: .failure(.unavailable),
            ]
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(repository.portfolioPhotoDataCallCount == 1)
        #expect(store.portfolioPhotos == [photo])
        #expect(store.portfolioPhotoData(for: photo) == nil)
        #expect(store.isPortfolioPhotoDataUnavailable(photo))
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func portfolioArtworkPresentationDistinguishesLoadingAndUnavailableStates() {
        let loading = GroomerPortfolioArtworkPresentation(
            hasImageData: false,
            isUnavailable: false
        )
        let unavailable = GroomerPortfolioArtworkPresentation(
            hasImageData: false,
            isUnavailable: true
        )
        let available = GroomerPortfolioArtworkPresentation(
            hasImageData: true,
            isUnavailable: false
        )

        #expect(loading.title == "Loading photo")
        #expect(loading.systemImage == "photo.on.rectangle")
        #expect(unavailable.title == "Photo unavailable")
        #expect(unavailable.systemImage == "exclamationmark.triangle.fill")
        #expect(available.title == nil)
    }

    @Test @MainActor
    func portfolioArtworkLayoutUsesSharedModuleImagePolicy() {
        let containerSize = CGSize(width: 120, height: 120)

        #expect(
            GroomlyModuleImageLayout.filledFrame(
                imageSize: CGSize(width: 400, height: 100),
                in: containerSize
            ) == CGRect(x: -180, y: 0, width: 480, height: 120)
        )
        #expect(
            GroomlyModuleImageLayout.filledFrame(
                imageSize: CGSize(width: 100, height: 400),
                in: containerSize
            ) == CGRect(x: 0, y: -180, width: 120, height: 480)
        )
        #expect(
            GroomlyModuleImageLayout.filledFrame(
                imageSize: CGSize(width: 200, height: 200),
                in: containerSize
            ) == CGRect(x: 0, y: 0, width: 120, height: 120)
        )
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

}
