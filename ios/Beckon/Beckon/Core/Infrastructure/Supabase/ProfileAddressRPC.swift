import Foundation
import Supabase

nonisolated enum ProfileAddressRPCError: Error {
    case invalidResponse
}

nonisolated struct ProfileAddressV3Response: Decodable, Sendable {
    let timingVersion: Int
    let address: ProfileAddressRPCRow?

    private enum CodingKeys: String, CodingKey {
        case timingVersion = "timing_version"
        case address
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timingVersion = try container.decode(Int.self, forKey: .timingVersion)
        guard timingVersion == 1 else {
            throw DecodingError.dataCorruptedError(forKey: .timingVersion, in: container,
                debugDescription: "Unsupported address timing version")
        }
        address = try container.decode(ProfileAddressRPCRow?.self, forKey: .address)
    }
}

nonisolated struct SaveProfileAddressV3Parameters: Encodable, Sendable {
    let confirmedAddress: BeckonConfirmedAddress

    private enum CodingKeys: String, CodingKey { case address = "p_address" }
    private enum AddressKeys: String, CodingKey {
        case line1 = "line_1", line2 = "line_2", city, state, zipCode = "zip_code"
        case provider, placeID = "place_id", countryCode = "country_code", latitude, longitude
        case resolutionSource = "resolution_source", confirmedAt = "user_confirmed_at"
        case timeZoneIdentifier = "time_zone_identifier"
    }

    func encode(to encoder: any Encoder) throws {
        guard let zone = confirmedAddress.timeZoneIdentifier else {
            throw GroomingTimingError.invalidTimeZone
        }
        _ = try GroomingServiceTiming.locationCalendar(zone)
        let address = confirmedAddress.accepted
        var outer = encoder.container(keyedBy: CodingKeys.self)
        var container = outer.nestedContainer(keyedBy: AddressKeys.self, forKey: .address)
        try container.encode(address.line1, forKey: .line1)
        try container.encode(address.line2, forKey: .line2)
        try container.encode(address.city, forKey: .city)
        try container.encode(address.stateCode?.rawValue, forKey: .state)
        try container.encode(address.postalCode, forKey: .zipCode)
        try container.encode(confirmedAddress.provider, forKey: .provider)
        try container.encode(confirmedAddress.placeID, forKey: .placeID)
        try container.encode(address.countryCode, forKey: .countryCode)
        try container.encode(confirmedAddress.coordinate.latitude, forKey: .latitude)
        try container.encode(confirmedAddress.coordinate.longitude, forKey: .longitude)
        try container.encode(confirmedAddress.resolutionSource, forKey: .resolutionSource)
        try container.encode(confirmedAddress.confirmedAt.ISO8601Format(), forKey: .confirmedAt)
        try container.encode(zone, forKey: .timeZoneIdentifier)
    }
}

@MainActor
enum ProfileAddressRPC {
    static func validateSaveSupport(client: SupabaseClient, address: BeckonConfirmedAddress?) async throws {
        guard let address, address.timeZoneIdentifier != nil else { return }
        _ = try JSONEncoder().encode(SaveProfileAddressV3Parameters(confirmedAddress: address))
        // Capability must be verified before the repositories begin their multi-write profile save.
        let _: ProfileAddressV3Response = try await client.rpc("get_my_profile_address_v3").execute().value
    }

    static func load(client: SupabaseClient, legacyRPC: String) async throws -> BeckonConfirmedAddress? {
        do {
            let response: ProfileAddressV3Response = try await client.rpc("get_my_profile_address_v3")
                .execute().value
            return response.address?.confirmedAddress
        } catch let error as PostgrestError where error.code == "PGRST202" {
            let rows: [ProfileAddressRPCRow] = try await client.rpc(legacyRPC).execute().value
            guard rows.count <= 1 else { throw ProfileAddressRPCError.invalidResponse }
            return rows.first?.confirmedAddress
        }
    }

    static func save(client: SupabaseClient, legacyRPC: String,
                     address: BeckonConfirmedAddress) async throws {
        if address.timeZoneIdentifier != nil {
            let _: UUID = try await client.rpc("save_my_profile_address_v3",
                params: SaveProfileAddressV3Parameters(confirmedAddress: address)).execute().value
        } else {
            let _: UUID = try await client.rpc(legacyRPC,
                params: SaveProfileAddressRPCParameters(confirmedAddress: address)).execute().value
        }
    }
}

nonisolated struct ProfileAddressRPCRow: Decodable, Sendable {
    let line1: String
    let line2: String?
    let city: String
    let state: String
    let zipCode: String
    let provider: String
    let placeID: String?
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let resolutionSource: String
    let userConfirmedAt: Date
    let timeZoneIdentifier: String?

    var confirmedAddress: BeckonConfirmedAddress? {
        guard let stateCode = USStateCode(rawValue: state) else { return nil }
        let input = BeckonAddressInput(
            line1: line1,
            line2: line2 ?? "",
            city: city,
            stateCode: stateCode,
            postalCode: zipCode,
            countryCode: countryCode
        )
        return BeckonConfirmedAddress(
            entered: input,
            accepted: input,
            provider: provider,
            placeID: placeID,
            coordinate: BeckonAddressCoordinate(
                latitude: latitude,
                longitude: longitude
            ),
            resolutionSource: resolutionSource,
            confirmedAt: userConfirmedAt,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    private enum CodingKeys: String, CodingKey {
        case line1 = "line_1"
        case line2 = "line_2"
        case city
        case state
        case zipCode = "zip_code"
        case provider
        case placeID = "place_id"
        case countryCode = "country_code"
        case latitude
        case longitude
        case resolutionSource = "resolution_source"
        case userConfirmedAt = "user_confirmed_at"
        case timeZoneIdentifier = "time_zone_identifier"
    }
}

nonisolated struct SaveProfileAddressRPCParameters: Encodable, Sendable {
    let confirmedAddress: BeckonConfirmedAddress

    func encode(to encoder: any Encoder) throws {
        let address = confirmedAddress.accepted
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address.line1, forKey: .line1)
        try container.encode(address.line2, forKey: .line2)
        try container.encode(address.city, forKey: .city)
        try container.encode(address.stateCode?.rawValue, forKey: .state)
        try container.encode(address.postalCode, forKey: .zipCode)
        try container.encode(confirmedAddress.provider, forKey: .provider)
        try container.encode(confirmedAddress.placeID, forKey: .placeID)
        try container.encode(address.countryCode, forKey: .countryCode)
        try container.encode(confirmedAddress.coordinate.latitude, forKey: .latitude)
        try container.encode(confirmedAddress.coordinate.longitude, forKey: .longitude)
        try container.encode(confirmedAddress.resolutionSource, forKey: .resolutionSource)
        try container.encode(
            confirmedAddress.confirmedAt.ISO8601Format(),
            forKey: .userConfirmedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case line1 = "p_line_1"
        case line2 = "p_line_2"
        case city = "p_city"
        case state = "p_state"
        case zipCode = "p_zip_code"
        case provider = "p_provider"
        case placeID = "p_place_id"
        case countryCode = "p_country_code"
        case latitude = "p_latitude"
        case longitude = "p_longitude"
        case resolutionSource = "p_resolution_source"
        case userConfirmedAt = "p_user_confirmed_at"
    }
}
