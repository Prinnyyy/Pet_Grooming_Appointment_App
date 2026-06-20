import Foundation

struct AuthSessionSnapshot: Equatable, Sendable {
    let userID: UUID
}

@MainActor
protocol AuthSessionRepository: AnyObject {
    func currentSession() -> AuthSessionSnapshot?
    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?>
}
