import Foundation
import Supabase

@MainActor
final class SupabaseCustomerProfileRepository: CustomerProfileRepository {
    private static let profileColumns = "id,display_name,avatar_path"
    private static let customerProfileColumns =
        "user_id,street_address,city,state,zip_code,contact_email,phone_number"
    private static let avatarBucketID = PhotoStorageBucketID.customerAvatar.rawValue

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func profile(customerID: UUID) async throws -> CustomerProfileDetails {
        do {
            let profileRows: [CustomerProfileAccountRow] = try await client
                .from("profiles")
                .select(Self.profileColumns)
                .eq("id", value: customerID.uuidString.lowercased())
                .limit(1)
                .execute()
                .value

            let detailRows: [CustomerProfileDetailsRow] = try await client
                .from("customer_profiles")
                .select(Self.customerProfileColumns)
                .eq("user_id", value: customerID.uuidString.lowercased())
                .limit(1)
                .execute()
                .value

            guard let accountRow = profileRows.first, profileRows.count == 1 else {
                throw CustomerProfileRepositoryError.unavailable
            }

            guard detailRows.count <= 1 else {
                throw CustomerProfileRepositoryError.unavailable
            }

            return CustomerProfileDetails(
                userID: accountRow.id,
                nickname: accountRow.displayName,
                avatarPath: accountRow.avatarPath,
                streetAddress: detailRows.first?.streetAddress,
                city: detailRows.first?.city,
                stateCode: detailRows.first?.state.flatMap(USStateCode.init(rawValue:)),
                zipCode: detailRows.first?.zipCode,
                contactEmail: detailRows.first?.contactEmail,
                phoneNumber: detailRows.first?.phoneNumber
            )
        } catch let error as CustomerProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func updateProfile(
        customerID: UUID,
        draft: CustomerProfileDraft
    ) async throws -> CustomerProfileDetails {
        do {
            let currentAvatarPath = try? await avatarPath(customerID: customerID)

            let profileRows: [CustomerProfileAccountRow] = try await client
                .from("profiles")
                .update(CustomerAccountUpdateRow(draft: draft, avatarPath: currentAvatarPath))
                .eq("id", value: customerID.uuidString.lowercased())
                .select(Self.profileColumns)
                .execute()
                .value

            guard profileRows.count == 1, let accountRow = profileRows.first else {
                throw CustomerProfileRepositoryError.unavailable
            }

            let detailRows: [CustomerProfileDetailsRow] = try await client
                .from("customer_profiles")
                .upsert(
                    CustomerProfileDetailsUpsertRow(
                        customerID: customerID,
                        draft: draft
                    ),
                    onConflict: "user_id"
                )
                .select(Self.customerProfileColumns)
                .execute()
                .value

            guard detailRows.count == 1, let detailRow = detailRows.first else {
                throw CustomerProfileRepositoryError.unavailable
            }

            return CustomerProfileDetails(
                userID: accountRow.id,
                nickname: accountRow.displayName,
                avatarPath: accountRow.avatarPath,
                streetAddress: detailRow.streetAddress,
                city: detailRow.city,
                stateCode: detailRow.state.flatMap(USStateCode.init(rawValue:)),
                zipCode: detailRow.zipCode,
                contactEmail: detailRow.contactEmail,
                phoneNumber: detailRow.phoneNumber
            )
        } catch let error as CustomerProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func uploadAvatarPhoto(
        customerID: UUID,
        data: Data,
        contentType: CustomerAvatarPhotoContentType
    ) async throws -> String {
        let storagePath = CustomerAvatarPhotoPath.make(
            customerID: customerID,
            contentType: contentType
        )

        do {
            let oldAvatarPath = try? await avatarPath(customerID: customerID)

            try await client.storage
                .from(Self.avatarBucketID)
                .upload(
                    storagePath,
                    data: data,
                    options: FileOptions(
                        contentType: contentType.mimeType,
                        upsert: false
                    )
                )

            let rows: [CustomerProfileAccountRow] = try await client
                .from("profiles")
                .update(CustomerAvatarUpdateRow(avatarPath: storagePath))
                .eq("id", value: customerID.uuidString.lowercased())
                .select(Self.profileColumns)
                .execute()
                .value

            guard rows.count == 1, rows.first?.avatarPath == storagePath else {
                await removeAvatarPhoto(storagePath)
                throw CustomerProfileRepositoryError.unavailable
            }

            if let oldAvatarPath,
               oldAvatarPath != storagePath {
                await removeAvatarPhoto(oldAvatarPath)
            }

            return storagePath
        } catch let error as CustomerProfileRepositoryError {
            throw error
        } catch {
            await removeAvatarPhoto(storagePath)
            throw Self.map(error)
        }
    }

    func avatarPhotoData(storagePath: String) async throws -> Data {
        do {
            return try await client.storage
                .from(Self.avatarBucketID)
                .download(path: storagePath)
        } catch {
            throw Self.map(error)
        }
    }

    func latestAvatarPhotoPath(customerID: UUID) async throws -> String? {
        let folderPath = customerID.uuidString.lowercased()

        do {
            let files = try await client.storage
                .from(Self.avatarBucketID)
                .list(
                    path: folderPath,
                    options: SearchOptions(
                        limit: 50,
                        sortBy: SortBy(column: "created_at", order: "desc")
                    )
                )

            return Self.latestAvatarPhotoPath(
                folderPath: folderPath,
                files: files
            )
        } catch {
            throw Self.map(error)
        }
    }

    private func avatarPath(customerID: UUID) async throws -> String? {
        let rows: [CustomerProfileAccountRow] = try await client
            .from("profiles")
            .select(Self.profileColumns)
            .eq("id", value: customerID.uuidString.lowercased())
            .limit(1)
            .execute()
            .value

        guard rows.count <= 1 else {
            throw CustomerProfileRepositoryError.unavailable
        }

        return rows.first?.avatarPath
    }

    private func removeAvatarPhoto(_ storagePath: String) async {
        _ = try? await client.storage
            .from(Self.avatarBucketID)
            .remove(paths: [storagePath])
    }

    private static func latestAvatarPhotoPath(
        folderPath: String,
        files: [FileObject]
    ) -> String? {
        files
            .filter { isSupportedAvatarObjectName($0.name) }
            .sorted { lhs, rhs in
                let lhsDate = lhs.createdAt ?? lhs.updatedAt ?? .distantPast
                let rhsDate = rhs.createdAt ?? rhs.updatedAt ?? .distantPast

                if lhsDate == rhsDate {
                    return lhs.name > rhs.name
                }

                return lhsDate > rhsDate
            }
            .first
            .map { "\(folderPath)/\($0.name)" }
    }

    private static func isSupportedAvatarObjectName(_ name: String) -> Bool {
        switch (name as NSString).pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "heic", "heif":
            true
        default:
            false
        }
    }

    private static func map(_ error: any Error) -> CustomerProfileRepositoryError {
        if AppDebugErrorClassifier.isCancellation(error) {
            return .cancelled
        }

        if let repositoryError = error as? CustomerProfileRepositoryError {
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

private struct CustomerProfileAccountRow: Decodable {
    let id: UUID
    let displayName: String
    let avatarPath: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarPath = "avatar_path"
    }
}

private struct CustomerProfileDetailsRow: Decodable {
    let userID: UUID
    let streetAddress: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let contactEmail: String?
    let phoneNumber: String?

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case streetAddress = "street_address"
        case city
        case state
        case zipCode = "zip_code"
        case contactEmail = "contact_email"
        case phoneNumber = "phone_number"
    }
}

private struct CustomerAccountUpdateRow: Encodable {
    let draft: CustomerProfileDraft
    let avatarPath: String?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(draft.nickname, forKey: .displayName)
        try container.encodeIfPresent(avatarPath, forKey: .avatarPath)
    }

    private enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarPath = "avatar_path"
    }
}

private struct CustomerAvatarUpdateRow: Encodable {
    let avatarPath: String

    private enum CodingKeys: String, CodingKey {
        case avatarPath = "avatar_path"
    }
}

private struct CustomerProfileDetailsUpsertRow: Encodable {
    let customerID: UUID
    let draft: CustomerProfileDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(customerID.uuidString.lowercased(), forKey: .userID)
        try container.encode(draft.streetAddress, forKey: .streetAddress)
        try container.encode(draft.city, forKey: .city)
        try container.encode(draft.stateCode?.rawValue, forKey: .state)
        try container.encode(draft.zipCode, forKey: .zipCode)
        try container.encode(draft.contactEmail, forKey: .contactEmail)
        try container.encode(draft.phoneNumber, forKey: .phoneNumber)
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case streetAddress = "street_address"
        case city
        case state
        case zipCode = "zip_code"
        case contactEmail = "contact_email"
        case phoneNumber = "phone_number"
    }
}
