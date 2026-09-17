import Foundation
import Supabase
import Testing
@testable import Beckon

@Suite(.serialized)
struct AuthSessionSignOutRaceTests {
    @Test(arguments: [true, false]) @MainActor
    func inFlightRefreshCannotRestoreSessionAfterSignOut(expiredToken: Bool) async throws {
        let storage = SignOutRaceStorage()
        let user = User(id: UUID(), appMetadata: [:], userMetadata: [:], aud: "authenticated",
            email: "synthetic@example.invalid", createdAt: Date(), updatedAt: Date())
        let expired = Session(accessToken: "synthetic-expired", tokenType: "bearer", expiresIn: -120,
            expiresAt: Date().timeIntervalSince1970 + (expiredToken ? -120 : 80), refreshToken: "synthetic-refresh", user: user)
        try storage.store(key: "t392-race", value: JSONEncoder().encode(expired))
        var refreshed = expired
        refreshed.accessToken = "synthetic-refreshed"
        refreshed.expiresIn = 3600
        refreshed.expiresAt = Date().timeIntervalSince1970 + 3600
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        SignOutRaceTransport.state.reset(response: try encoder.encode(refreshed))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SignOutRaceTransport.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://signout-test.invalid")!, supabaseKey: "synthetic-key",
            options: .init(auth: .init(storage: storage, storageKey: "t392-race", autoRefreshToken: false,
                emitLocalSessionAsInitialSession: true), global: .init(session: URLSession(configuration: configuration))))
        let repository = SupabaseAuthSessionRepository(client: client)
        let refresh = Task { try await client.auth.refreshSession() }
        for _ in 0..<100 where !SignOutRaceTransport.state.refreshStarted {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(SignOutRaceTransport.state.refreshStarted)
        try await repository.signOut()
        _ = try await refresh.value
        #expect(repository.currentSession() == nil, "Late refresh must not resurrect a signed-out account")
        await client.auth.stopAutoRefresh()
    }

    @Test @MainActor
    func noStoredSessionDoesNotRefreshOrContactLogout() async throws {
        SignOutRaceTransport.state.reset(response: Data())
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SignOutRaceTransport.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://signout-test.invalid")!, supabaseKey: "synthetic-key",
            options: .init(auth: .init(storage: SignOutRaceStorage(), storageKey: "t392-empty", autoRefreshToken: false,
                emitLocalSessionAsInitialSession: true), global: .init(session: URLSession(configuration: configuration))))
        let repository = SupabaseAuthSessionRepository(client: client)
        try await repository.signOut()
        #expect(repository.currentSession() == nil)
        #expect(!SignOutRaceTransport.state.refreshStarted)
        #expect(SignOutRaceTransport.state.requestCount == 0)
        await client.auth.stopAutoRefresh()
    }

    @Test @MainActor
    func offlineLogoutStillRemovesLocalCredentials() async throws {
        let storage = SignOutRaceStorage()
        let user = User(id: UUID(), appMetadata: [:], userMetadata: [:], aud: "authenticated",
            email: "synthetic@example.invalid", createdAt: Date(), updatedAt: Date())
        let stored = Session(accessToken: "synthetic-offline", tokenType: "bearer", expiresIn: 3600,
            expiresAt: Date().timeIntervalSince1970 + 3600, refreshToken: "synthetic-refresh", user: user)
        try storage.store(key: "t392-offline", value: JSONEncoder().encode(stored))
        SignOutRaceTransport.state.reset(response: Data(), offline: true)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SignOutRaceTransport.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://signout-test.invalid")!, supabaseKey: "synthetic-key",
            options: .init(auth: .init(storage: storage, storageKey: "t392-offline", autoRefreshToken: false,
                emitLocalSessionAsInitialSession: true), global: .init(session: URLSession(configuration: configuration))))
        let repository = SupabaseAuthSessionRepository(client: client)
        do { try await repository.signOut() } catch {}
        #expect(repository.currentSession() == nil)
        #expect(try storage.retrieve(key: "t392-offline") == nil)
        await client.auth.stopAutoRefresh()
    }
}

nonisolated private final class SignOutRaceStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { lock.withLock { _ = values.removeValue(forKey: key) } }
}

nonisolated private final class SignOutRaceTransport: URLProtocol, @unchecked Sendable {
    static let state = State()
    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var started = false
        private var response = Data()
        private var count = 0
        private var failOffline = false
        var offline: Bool { lock.withLock { failOffline } }
        var refreshStarted: Bool { lock.withLock { started } }
        var requestCount: Int { lock.withLock { count } }
        func record() { lock.withLock { count += 1 } }
        func reset(response: Data, offline: Bool = false) {
            lock.withLock { self.response = response; started = false; count = 0; failOffline = offline }
        }
        func refreshResponse() -> Data { lock.withLock { started = true; return response } }
    }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "signout-test.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.state.record()
        if Self.state.offline {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let refresh = request.url!.path.hasSuffix("/token")
        let data = refresh ? Self.state.refreshResponse() : Data("{}".utf8)
        if refresh { Thread.sleep(forTimeInterval: 0.4) }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
            httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
