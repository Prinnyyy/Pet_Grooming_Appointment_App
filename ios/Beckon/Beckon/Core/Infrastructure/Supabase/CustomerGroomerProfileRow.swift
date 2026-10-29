import Foundation

/// Reuses the groomer's existing row decoders; the RPC only returns the customer-safe columns.
struct CustomerGroomerProfileRow: Decodable {
    let profile: MarketplaceGroomerSummaryRow
    let services: [GroomerServiceWireRow]
    let photos: [GroomerPortfolioPhotoRow]
    let tags: [GroomerPortfolioFitTagRow]
    let claims: [GroomerFitClaimRow]
    let windows: [GroomerAvailabilityWindowRow]
    let modes: [GroomingLocationMode]?
    let radiusMiles: Int?
    let noticeDays: Int?
    let timeOff: GroomerTimeOffWindowRow?

    func profile(expectedID: UUID) throws -> CustomerGroomerProfile {
        guard profile.id == expectedID,
              services.allSatisfy({ $0.groomerID == expectedID && $0.isActive }),
              photos.allSatisfy({ $0.groomerID == expectedID && $0.storageBucket == "groomer-portfolio"
                  && $0.storagePath.hasPrefix(expectedID.uuidString.lowercased() + "/") }),
              tags.allSatisfy({ $0.groomerID == expectedID }),
              claims.allSatisfy({ $0.groomerID == expectedID && $0.isActive }),
              windows.allSatisfy({ $0.groomerID == expectedID }),
              timeOff.map({ $0.groomerID == expectedID }) ?? true else { throw RequestDiscoveryError.notAllowed }
        let mappedTags = tags.compactMap(\.tag)
        return CustomerGroomerProfile(profile: try profile.summary(), content: GroomerProfileContent(
            services: services.map(\.service),
            works: photos.map { photo in GroomerWork(photo: photo.photo,
                tags: mappedTags.filter { $0.portfolioPhotoID == photo.id }.map(\.signal), symbol: "pawprint.fill", look: 0) },
            specialties: claims.compactMap(\.claim).map(\.signal), modes: modes ?? [], radiusMiles: radiusMiles,
            windows: windows.compactMap(\.window), noticeDays: noticeDays, timeOff: timeOff?.window))
    }

    private enum CodingKeys: String, CodingKey {
        case profile, services, photos, tags, claims, windows, modes
        case radiusMiles = "radius_miles", noticeDays = "notice_days", timeOff = "time_off"
    }
}
