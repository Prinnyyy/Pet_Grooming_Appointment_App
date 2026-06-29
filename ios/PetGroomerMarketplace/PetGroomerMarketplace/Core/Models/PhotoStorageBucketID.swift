import Foundation

nonisolated enum PhotoStorageBucketID: String, CaseIterable, Sendable {
    case groomerAvatar = "groomer-avatars"
    case groomerPortfolio = "groomer-portfolio"
    case customerPet = "pet-photos"
    case groomingRequest = "request-photos"
}
