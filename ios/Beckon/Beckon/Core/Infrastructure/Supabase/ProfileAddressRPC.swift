import Foundation

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
            confirmedAt: userConfirmedAt
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
        try container.encodeIfPresent(confirmedAddress.placeID, forKey: .placeID)
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
