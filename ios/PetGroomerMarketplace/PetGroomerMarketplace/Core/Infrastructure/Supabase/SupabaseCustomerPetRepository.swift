import Foundation
import Supabase

@MainActor
final class SupabaseCustomerPetRepository: CustomerPetRepository {
    private static let petColumns = "id,customer_id,name,species,breed,size,weight_lbs,birthday,temperament,medical_notes,grooming_notes,is_active"
    private static let photoColumns = "id,pet_id,customer_id,storage_bucket,storage_path,caption,sort_order,is_primary"
    fileprivate static let bucketID = "pet-photos"

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        do {
            let rows: [PetRow] = try await client
                .from("pets")
                .select(Self.petColumns)
                .eq("customer_id", value: customerID.uuidString.lowercased())
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            return rows.map(\.pet)
        } catch {
            throw Self.map(error)
        }
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        do {
            let rows: [PetPhotoRow] = try await client
                .from("pet_photos")
                .select(Self.photoColumns)
                .eq("customer_id", value: customerID.uuidString.lowercased())
                .order("sort_order")
                .order("created_at")
                .execute()
                .value

            return rows.map(\.photo)
        } catch {
            throw Self.map(error)
        }
    }

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        do {
            let rows: [PetRow] = try await client
                .from("pets")
                .insert(PetInsertRow(customerID: customerID, draft: draft))
                .select(Self.petColumns)
                .execute()
                .value

            guard rows.count == 1, let pet = rows.first?.pet else {
                throw CustomerPetRepositoryError.unavailable
            }

            return pet
        } catch let error as CustomerPetRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func updatePet(
        pet: CustomerPet,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        do {
            let rows: [PetRow] = try await client
                .from("pets")
                .update(PetUpdateRow(draft: draft))
                .eq("id", value: pet.id.uuidString.lowercased())
                .eq("customer_id", value: pet.customerID.uuidString.lowercased())
                .select(Self.petColumns)
                .execute()
                .value

            guard rows.count == 1, let updatedPet = rows.first?.pet else {
                throw CustomerPetRepositoryError.unavailable
            }

            return updatedPet
        } catch let error as CustomerPetRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func softDeletePet(_ pet: CustomerPet) async throws {
        do {
            let rows: [PetRow] = try await client
                .from("pets")
                .update(PetSoftDeleteRow())
                .eq("id", value: pet.id.uuidString.lowercased())
                .eq("customer_id", value: pet.customerID.uuidString.lowercased())
                .select(Self.petColumns)
                .execute()
                .value

            guard rows.count == 1 else {
                throw CustomerPetRepositoryError.unavailable
            }
        } catch let error as CustomerPetRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        let storagePath = CustomerPetPhotoPath.make(
            customerID: customerID,
            petID: petID,
            contentType: contentType
        )

        do {
            try await client.storage
                .from(Self.bucketID)
                .upload(
                    storagePath,
                    data: data,
                    options: FileOptions(
                        contentType: contentType.mimeType,
                        upsert: false
                    )
                )

            let rows: [PetPhotoRow] = try await client
                .from("pet_photos")
                .insert(
                    PetPhotoInsertRow(
                        petID: petID,
                        customerID: customerID,
                        storagePath: storagePath,
                        caption: Self.normalized(caption)
                    )
                )
                .select(Self.photoColumns)
                .execute()
                .value

            guard rows.count == 1, let photo = rows.first?.photo else {
                try? await client.storage
                    .from(Self.bucketID)
                    .remove(paths: [storagePath])
                throw CustomerPetRepositoryError.unavailable
            }

            return photo
        } catch let error as CustomerPetRepositoryError {
            throw error
        } catch {
            try? await client.storage
                .from(Self.bucketID)
                .remove(paths: [storagePath])
            throw Self.map(error)
        }
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {
        do {
            try await client.storage
                .from(Self.bucketID)
                .remove(paths: [photo.storagePath])

            try await client
                .from("pet_photos")
                .delete()
                .eq("id", value: photo.id.uuidString.lowercased())
                .eq("customer_id", value: photo.customerID.uuidString.lowercased())
                .execute()
        } catch {
            throw Self.map(error)
        }
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func map(_ error: any Error) -> CustomerPetRepositoryError {
        if let repositoryError = error as? CustomerPetRepositoryError {
            return repositoryError
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501":
                return .notAllowed
            default:
                return .unavailable
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                return .networkUnavailable
            default:
                return .unavailable
            }
        }

        return .unavailable
    }
}

private struct PetRow: Decodable {
    let id: UUID
    let customerID: UUID
    let name: String
    let species: String
    let breed: String?
    let size: String?
    let weightLbs: Double?
    let birthday: String?
    let temperament: String?
    let medicalNotes: String?
    let groomingNotes: String?
    let isActive: Bool

    var pet: CustomerPet {
        CustomerPet(
            id: id,
            customerID: customerID,
            name: name,
            species: species,
            breed: breed,
            size: size,
            weightLbs: weightLbs,
            birthday: birthday,
            temperament: temperament,
            medicalNotes: medicalNotes,
            groomingNotes: groomingNotes,
            isActive: isActive
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case customerID = "customer_id"
        case name
        case species
        case breed
        case size
        case weightLbs = "weight_lbs"
        case birthday
        case temperament
        case medicalNotes = "medical_notes"
        case groomingNotes = "grooming_notes"
        case isActive = "is_active"
    }
}

private struct PetPhotoRow: Decodable {
    let id: UUID
    let petID: UUID
    let customerID: UUID
    let storageBucket: String
    let storagePath: String
    let caption: String?
    let sortOrder: Int
    let isPrimary: Bool

    var photo: CustomerPetPhoto {
        CustomerPetPhoto(
            id: id,
            petID: petID,
            customerID: customerID,
            storageBucket: storageBucket,
            storagePath: storagePath,
            caption: caption,
            sortOrder: sortOrder,
            isPrimary: isPrimary
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case petID = "pet_id"
        case customerID = "customer_id"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case caption
        case sortOrder = "sort_order"
        case isPrimary = "is_primary"
    }
}

private struct PetInsertRow: Encodable {
    let customerID: UUID
    let draft: CustomerPetDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(customerID.uuidString.lowercased(), forKey: .customerID)
        try container.encode(draft.name, forKey: .name)
        try container.encode(draft.species, forKey: .species)
        try container.encodeIfPresent(draft.breed, forKey: .breed)
        try container.encodeIfPresent(draft.size, forKey: .size)
        try container.encodeIfPresent(draft.weightLbs, forKey: .weightLbs)
        try container.encodeIfPresent(draft.birthday, forKey: .birthday)
        try container.encodeIfPresent(draft.temperament, forKey: .temperament)
        try container.encodeIfPresent(draft.medicalNotes, forKey: .medicalNotes)
        try container.encodeIfPresent(draft.groomingNotes, forKey: .groomingNotes)
    }

    private enum CodingKeys: String, CodingKey {
        case customerID = "customer_id"
        case name
        case species
        case breed
        case size
        case weightLbs = "weight_lbs"
        case birthday
        case temperament
        case medicalNotes = "medical_notes"
        case groomingNotes = "grooming_notes"
    }
}

private struct PetUpdateRow: Encodable {
    let draft: CustomerPetDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(draft.name, forKey: .name)
        try container.encode(draft.species, forKey: .species)
        try encodeNullable(draft.breed, forKey: .breed, in: &container)
        try encodeNullable(draft.size, forKey: .size, in: &container)
        try encodeNullable(draft.weightLbs, forKey: .weightLbs, in: &container)
        try encodeNullable(draft.birthday, forKey: .birthday, in: &container)
        try encodeNullable(draft.temperament, forKey: .temperament, in: &container)
        try encodeNullable(draft.medicalNotes, forKey: .medicalNotes, in: &container)
        try encodeNullable(draft.groomingNotes, forKey: .groomingNotes, in: &container)
    }

    private func encodeNullable<T: Encodable>(
        _ value: T?,
        forKey key: CodingKeys,
        in container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case species
        case breed
        case size
        case weightLbs = "weight_lbs"
        case birthday
        case temperament
        case medicalNotes = "medical_notes"
        case groomingNotes = "grooming_notes"
    }
}

private struct PetSoftDeleteRow: Encodable {
    let isActive = false
    let deletedAt: String

    init(date: Date = Date()) {
        deletedAt = ISO8601DateFormatter().string(from: date)
    }

    private enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case deletedAt = "deleted_at"
    }
}

private struct PetPhotoInsertRow: Encodable {
    let petID: UUID
    let customerID: UUID
    let storagePath: String
    let caption: String?

    private enum CodingKeys: String, CodingKey {
        case petID = "pet_id"
        case customerID = "customer_id"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case caption
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(petID.uuidString.lowercased(), forKey: .petID)
        try container.encode(customerID.uuidString.lowercased(), forKey: .customerID)
        try container.encode(SupabaseCustomerPetRepository.bucketID, forKey: .storageBucket)
        try container.encode(storagePath, forKey: .storagePath)
        try container.encodeIfPresent(caption, forKey: .caption)
    }
}
