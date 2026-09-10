import Foundation
import Testing
import UIKit
@testable import Beckon

extension GroomerProfileStoreTests {
    @Test @MainActor
    func loadKeepsOnlySupportedPetFitEvidenceSignals() async {
        let groomerID = UUID()
        let poodle = Self.evidenceSummary(
            groomerID: groomerID,
            signal: .breedGroup(.poodle),
            completedBookingCount: 1,
            confidenceTier: .low
        )
        let repository = GroomerProfileRepositoryFake(
            profileResult: .success(Self.profile(groomerID: groomerID)),
            petFitEvidenceSummaryResult: .success([
                poodle,
                GroomerPetFitEvidenceSummary(
                    groomerID: groomerID,
                    signal: PetFitSignal(
                        group: .breedGroup,
                        traitValue: "unsupported",
                        title: "Unsupported"
                    ),
                    completedBookingCount: 9,
                    positiveReviewOutcomeCount: 9,
                    negativeReviewOutcomeCount: 0,
                    structuredReviewOutcomeCount: 9,
                    lastCompletedAt: nil,
                    lastReviewOutcomeAt: nil,
                    evidenceUpdatedAt: nil,
                    confidenceTier: .high
                ),
            ])
        )
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(store.petFitEvidenceSummary == [poodle])
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
        store.toggleFitClaim(.coatType(.curlyWavy))
        let successMessage = await store.saveFitClaims()

        #expect(repository.replaceFitClaimsCallCount == 1)
        #expect(successMessage == "Fit signals saved.")
        #expect(repository.lastFitClaimDrafts == [
            GroomerFitClaimDraft(
                signal: .coatType(.curlyWavy),
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
            PetFitSignal.coatType(.curlyWavy).id,
            PetFitSignal.careFlag(.senior).id
        ])
        #expect(store.noticeMessage == "Fit signals saved.")
    }

    @Test @MainActor
    func groomerAvailableFitClaimsIncludeSpecialtiesAndSizeExperience() {
        let availableIDs = GroomerFitClaim.availableSignals.map(\.id)

        #expect(GroomerFitClaim.maximumActiveClaims == 8)
        #expect(availableIDs.contains("coat_type:curly_wavy"))
        #expect(availableIDs.contains("coat_type:double_coat"))
        #expect(availableIDs.contains("size_band:S"))
        #expect(availableIDs.contains("size_band:Giant"))
        #expect(availableIDs.contains("service_fit:de_shedding_treatment"))
    }

    @Test @MainActor
    func fitClaimSelectionIsBoundedBeforeRepositoryCall() async {
        let repository = GroomerProfileRepositoryFake()
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: repository
        )
        let signals = Array(
            GroomerFitClaim.availableSignals
                .filter { $0.group != .sizeBand }
                .prefix(GroomerFitClaim.maximumActiveClaims + 1)
        )

        for signal in signals {
            store.toggleFitClaim(signal)
        }

        #expect(store.selectedFitClaimIDs.count == GroomerFitClaim.maximumActiveClaims)
        #expect(repository.replaceFitClaimsCallCount == 0)
        #expect(
            store.errorMessage ==
                "Choose up to \(GroomerFitClaim.maximumActiveClaims) core fit signals. Size experience does not use this limit."
        )
    }

    @Test @MainActor
    func sizeBandFitClaimsDoNotConsumeCoreSelectionLimit() {
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: GroomerProfileRepositoryFake()
        )
        let coreSignals = Array(
            GroomerFitClaim.availableSignals
                .filter { $0.group != .sizeBand }
                .prefix(GroomerFitClaim.maximumActiveClaims)
        )
        let sizeSignal = PetFitSignal.sizeBand(.giant)

        for signal in coreSignals {
            store.toggleFitClaim(signal)
        }
        store.toggleFitClaim(sizeSignal)

        #expect(store.selectedFitClaimIDs.count == GroomerFitClaim.maximumActiveClaims + 1)
        #expect(store.selectedFitClaimIDs.contains(sizeSignal.id))
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func saveFitClaimsAllowsSizeBandsAboveCoreSelectionLimit() async {
        let groomerID = UUID()
        let repository = GroomerProfileRepositoryFake(profileResult: .success(Self.profile(groomerID: groomerID)))
        let store = GroomerProfileStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()
        let coreSignals = Array(
            GroomerFitClaim.availableSignals
                .filter { $0.group != .sizeBand }
                .prefix(GroomerFitClaim.maximumActiveClaims)
        )
        let sizeSignal = PetFitSignal.sizeBand(.giant)

        for signal in coreSignals {
            store.toggleFitClaim(signal)
        }
        store.toggleFitClaim(sizeSignal)
        await store.saveFitClaims()

        #expect(repository.replaceFitClaimsCallCount == 1)
        #expect(repository.lastFitClaimDrafts.contains {
            $0.signal == sizeSignal && $0.isActive
        })
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func sizeBandRangeSelectionReplacesSizeBandsWithoutChangingCoreClaims() {
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: GroomerProfileRepositoryFake()
        )
        store.toggleFitClaim(.coatType(.curlyWavy))
        store.setSizeBandFitClaimRange(
            lowerIndex: 1,
            upperIndex: 4
        )

        #expect(store.selectedCoreFitClaimCount == 1)
        #expect(store.selectedSizeBandFitClaimCount == 4)
        #expect(store.selectedFitClaimIDs.contains(PetFitSignal.coatType(.curlyWavy).id))
        #expect(store.selectedFitClaimIDs.contains(PetFitSignal.sizeBand(.s).id))
        #expect(store.selectedFitClaimIDs.contains(PetFitSignal.sizeBand(.m).id))
        #expect(store.selectedFitClaimIDs.contains(PetFitSignal.sizeBand(.l).id))
        #expect(store.selectedFitClaimIDs.contains(PetFitSignal.sizeBand(.xl).id))
        #expect(!store.selectedFitClaimIDs.contains(PetFitSignal.sizeBand(.xs).id))
        #expect(!store.selectedFitClaimIDs.contains(PetFitSignal.sizeBand(.xxl).id))
        #expect(!store.selectedFitClaimIDs.contains(PetFitSignal.sizeBand(.giant).id))
    }

    @Test @MainActor
    func sizeBandRangeDefaultsToFullRangeWhenUnselected() {
        let store = GroomerProfileStore(
            groomerID: UUID(),
            repository: GroomerProfileRepositoryFake()
        )

        store.ensureSizeBandFitClaimRange()

        #expect(store.selectedSizeBandRange == 0...6)
        #expect(store.selectedSizeBandFitClaimCount == CustomerPetSizeCode.allCases.count)
        #expect(store.sizeBandFitClaimRangeTitle == "XS-Giant (<10lb-101+lb)")
    }

}
