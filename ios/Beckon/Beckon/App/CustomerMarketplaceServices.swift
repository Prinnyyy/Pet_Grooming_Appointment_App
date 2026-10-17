import SwiftUI

@MainActor
struct CustomerMarketplaceServices {
    let discovery: any CustomerGroomerDiscoveryRepository
    let distribution: any RequestDistributionRepository
    let favorites: any GroomerFavoritesRepository
    let images: any PrivateImageLoading
}

private struct CustomerMarketplaceServicesKey: EnvironmentKey {
    static let defaultValue: CustomerMarketplaceServices? = nil
}

private struct CustomerMarketplaceSessionKey: EnvironmentKey {
    static let defaultValue: CustomerMarketplaceSession? = nil
}

extension EnvironmentValues {
    var customerMarketplaceServices: CustomerMarketplaceServices? {
        get { self[CustomerMarketplaceServicesKey.self] }
        set { self[CustomerMarketplaceServicesKey.self] = newValue }
    }
    var customerMarketplaceSession: CustomerMarketplaceSession? {
        get { self[CustomerMarketplaceSessionKey.self] }
        set { self[CustomerMarketplaceSessionKey.self] = newValue }
    }
}
