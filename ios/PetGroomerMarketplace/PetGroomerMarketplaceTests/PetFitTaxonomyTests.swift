import Foundation
import Testing
@testable import PetGroomerMarketplace

struct PetFitTaxonomyTests {
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
        birthday: String? = nil,
        temperament: String? = nil
    ) throws -> GroomingRequestPetSnapshot {
        GroomingRequestPetSnapshot(
            id: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
            name: "Mochi",
            species: "Dog",
            breed: breed,
            size: "S",
            weightLbs: 16,
            birthday: birthday,
            temperament: temperament,
            medicalNotes: nil,
            groomingNotes: nil,
            snapshotAt: nil
        )
    }
}
