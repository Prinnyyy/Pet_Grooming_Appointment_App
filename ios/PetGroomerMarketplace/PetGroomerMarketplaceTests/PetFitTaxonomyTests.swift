import Foundation
import Testing
@testable import PetGroomerMarketplace

struct PetFitTaxonomyTests {
    @Test @MainActor
    func petFitSignalsExposeCanonicalSqlTraitPairs() {
        #expect(
            PetFitSignal.Group.allCases.map(\.traitType) == [
                "coat_type",
                "breed_group",
                "size_band",
                "care_flag",
                "service_fit"
            ]
        )

        #expect(
            PetFitSignal.coatTypeSignals.map(\.traitValue) == [
                "curly_wavy",
                "wire",
                "double_coat",
                "drop_coat",
                "long_silky",
                "short_smooth",
                "hairless_low_coat"
            ]
        )
        #expect(
            PetFitSignal.breedGroupSignals.map(\.traitValue)
                == PetBreedGroup.allCases.map(\.rawValue)
        )
        #expect(
            PetFitSignal.sizeBandSignals.map(\.traitValue)
                == CustomerPetSizeCode.allCases.map(\.rawValue)
        )
        #expect(
            PetFitSignal.careFlagSignals.map(\.traitValue)
                == PetCareFlag.allCases.map(\.rawValue)
        )
        #expect(
            PetFitSignal.serviceFitSignals.map(\.traitValue) == [
                "curly_coat",
                "de_shedding_treatment",
                "full_haircut_styling",
                "gentle_handling",
                "hand_stripping_carding",
                "matted_coat_handling",
                "nail_paw_care",
                "puppy_first_groom",
                "reactive_low_tolerance",
                "senior_care",
                "terrier_coat"
            ]
        )

        let pairIDs = PetFitSignal.allCases.map(\.id)
        #expect(Set(pairIDs).count == pairIDs.count)
    }

    @Test @MainActor
    func petFitSignalGroupingMetadataIsStable() {
        let signal = PetFitSignal.serviceFit(.gentleHandling)

        #expect(signal.id == "service_fit:gentle_handling")
        #expect(signal.group == .serviceFit)
        #expect(signal.groupTitle == "Service Fit")
        #expect(signal.traitType == "service_fit")
        #expect(signal.traitValue == "gentle_handling")
        #expect(signal.title == "Gentle Handling")
        #expect(PetFitSignal.Group.allCases.map(\.sortOrder) == [10, 20, 30, 40, 50])
    }

    @Test @MainActor
    func petFitSignalsDeriveCanonicalPairsFromExistingRequestContext() throws {
        let snapshot = try Self.petSnapshot(
            breed: "Toy Poodle",
            birthday: "2013-06-24",
            temperament: "Anxious"
        )

        let signals = PetFitSignal.signals(
            for: snapshot,
            serviceType: .fullGroom,
            referenceDate: Self.referenceDate
        )

        #expect(
            signals.map(\.id) == [
                "coat_type:curly_wavy",
                "breed_group:poodle",
                "size_band:S",
                "care_flag:anxious",
                "care_flag:senior",
                "service_fit:curly_coat",
                "service_fit:full_haircut_styling",
                "service_fit:gentle_handling",
                "service_fit:senior_care"
            ]
        )
    }

    @Test @MainActor
    func petFitSignalsPreferWeightDerivedSizeBandLikeBackend() throws {
        let snapshot = try Self.petSnapshot(
            size: "Giant",
            weightLbs: 16
        )

        let signalIDs = PetFitSignal.signals(
            for: snapshot,
            serviceType: .nailTrim,
            referenceDate: Self.referenceDate
        )
        .map(\.id)

        #expect(signalIDs.contains("size_band:S"))
        #expect(!signalIDs.contains("size_band:Giant"))
    }

    @Test @MainActor
    func unknownBreedUsesSelectedCoatTypeForMatchingSignals() throws {
        let snapshot = try Self.petSnapshot(
            breed: "Unspecified",
            coatType: "double_coat",
            groomingNotes: "Heavy seasonal shedding"
        )

        let signalIDs = PetFitSignal.signals(
            for: snapshot,
            serviceType: .deShedding,
            referenceDate: Self.referenceDate
        )
        .map(\.id)

        #expect(signalIDs.contains("coat_type:double_coat"))
        #expect(signalIDs.contains("service_fit:de_shedding_treatment"))
        #expect(!signalIDs.contains("breed_group:poodle"))
        #expect(!signalIDs.contains("breed_group:terrier"))
    }

    @Test @MainActor
    func knownDogBreedsRecommendProfessionalCoatTypes() throws {
        #expect(CustomerPetBreed.poodle.recommendedCoatType == .curlyWavy)
        #expect(CustomerPetBreed.bichonFrise.recommendedCoatType == .curlyWavy)
        #expect(CustomerPetBreed.miniatureSchnauzer.recommendedCoatType == .wire)
        #expect(CustomerPetBreed.siberianHusky.recommendedCoatType == .doubleCoat)
        #expect(CustomerPetBreed.pomeranian.recommendedCoatType == .doubleCoat)
        #expect(CustomerPetBreed.shihTzu.recommendedCoatType == .dropCoat)
        #expect(CustomerPetBreed.cockerSpaniel.recommendedCoatType == .longSilky)
        #expect(CustomerPetBreed.greatDane.recommendedCoatType == .shortSmooth)
    }

    @Test @MainActor
    func knownBreedFallsBackToRecommendedCoatTypeWhenNoExplicitCoatTypeExists() throws {
        let snapshot = try Self.petSnapshot(
            breed: "Siberian Husky",
            coatType: nil
        )

        let signalIDs = PetFitSignal.signals(
            for: snapshot,
            serviceType: .bathAndBrush,
            referenceDate: Self.referenceDate
        )
        .map(\.id)

        #expect(signalIDs.contains("coat_type:double_coat"))
    }

    @Test @MainActor
    func wireCoatRequestsDeriveHandStrippingSkillSignal() throws {
        let snapshot = try Self.petSnapshot(
            breed: "Unspecified",
            coatType: "wire"
        )

        let signalIDs = PetFitSignal.signals(
            for: snapshot,
            serviceType: .fullGroom,
            referenceDate: Self.referenceDate
        )
        .map(\.id)

        #expect(signalIDs.contains("coat_type:wire"))
        #expect(signalIDs.contains("service_fit:hand_stripping_carding"))
    }

    @Test @MainActor
    func westieBreedMapsToTerrierGroupAndTrait() throws {
        let snapshot = try Self.petSnapshot(
            breed: "West Highland White Terrier"
        )

        #expect(PetBreedGroup.group(forBreed: snapshot.breed) == .terrier)
        #expect(
            PetFitTrait.serviceFit(
                for: snapshot,
                serviceType: .haircutOnly,
                referenceDate: Self.referenceDate
            )
            .contains(.terrierCoat)
        )
    }

    @Test @MainActor
    func poodleBreedAddsCurlyCoatTraitForFullGroom() throws {
        let snapshot = try Self.petSnapshot(breed: "Toy Poodle")

        #expect(PetBreedGroup.group(forBreed: snapshot.breed) == .poodle)
        #expect(
            PetFitTrait.serviceFit(
                for: snapshot,
                serviceType: .fullGroom,
                referenceDate: Self.referenceDate
            )
            .contains(.curlyCoat)
        )
    }

    @Test @MainActor
    func anxiousTemperamentAddsGentleHandlingCareFlagAndTrait() throws {
        let snapshot = try Self.petSnapshot(temperament: "Anxious")

        #expect(
            PetCareFlag.flags(
                for: snapshot,
                referenceDate: Self.referenceDate
            ) == [.anxious]
        )
        #expect(
            PetFitTrait.serviceFit(
                for: snapshot,
                serviceType: .bathAndBrush,
                referenceDate: Self.referenceDate
            )
            .contains(.gentleHandling)
        )
    }

    @Test @MainActor
    func seniorPetAddsSeniorCareFlagAndTraitFromBirthday() throws {
        let snapshot = try Self.petSnapshot(birthday: "2013-06-24")

        #expect(
            PetCareFlag.flags(
                for: snapshot,
                referenceDate: Self.referenceDate
            ) == [.senior]
        )
        #expect(
            PetFitTrait.serviceFit(
                for: snapshot,
                serviceType: .fullGroom,
                referenceDate: Self.referenceDate
            )
            .contains(.seniorCare)
        )
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_719_187_200)

    private static func petSnapshot(
        breed: String? = nil,
        coatType: String? = nil,
        size: String? = "S",
        weightLbs: Double? = 16,
        birthday: String? = nil,
        temperament: String? = nil,
        groomingNotes: String? = nil
    ) throws -> GroomingRequestPetSnapshot {
        GroomingRequestPetSnapshot(
            id: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
            name: "Mochi",
            species: "Dog",
            breed: breed,
            coatType: coatType,
            size: size,
            weightLbs: weightLbs,
            birthday: birthday,
            temperament: temperament,
            medicalNotes: nil,
            groomingNotes: groomingNotes,
            snapshotAt: nil
        )
    }
}
