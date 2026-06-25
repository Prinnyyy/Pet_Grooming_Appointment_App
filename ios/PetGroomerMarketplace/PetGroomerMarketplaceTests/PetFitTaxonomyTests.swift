import Foundation
import Testing
@testable import PetGroomerMarketplace

struct PetFitTaxonomyTests {
    @Test @MainActor
    func petFitSignalsExposeCanonicalSqlTraitPairs() {
        #expect(
            PetFitSignal.Group.allCases.map(\.traitType) == [
                "breed_group",
                "size_band",
                "care_flag",
                "service_fit"
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
                "gentle_handling",
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
        #expect(PetFitSignal.Group.allCases.map(\.sortOrder) == [10, 20, 30, 40])
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
                "breed_group:poodle",
                "size_band:S",
                "care_flag:anxious",
                "care_flag:senior",
                "service_fit:curly_coat",
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
        size: String? = "S",
        weightLbs: Double? = 16,
        birthday: String? = nil,
        temperament: String? = nil
    ) throws -> GroomingRequestPetSnapshot {
        GroomingRequestPetSnapshot(
            id: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
            name: "Mochi",
            species: "Dog",
            breed: breed,
            size: size,
            weightLbs: weightLbs,
            birthday: birthday,
            temperament: temperament,
            medicalNotes: nil,
            groomingNotes: nil,
            snapshotAt: nil
        )
    }
}
