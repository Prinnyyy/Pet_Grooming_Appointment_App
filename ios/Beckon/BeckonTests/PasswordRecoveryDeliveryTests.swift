import Foundation
import Supabase
import XCTest
@testable import Beckon

final class PasswordRecoveryDeliveryTests: XCTestCase {
    @MainActor
    func testDeliveredEmailRecoversOnlyItsAccountAndRejectsReuse() async throws {
        let bridge = URL(string: "http://127.0.0.1:49383")!
        var request = URLRequest(url: bridge.appending(path: "fixture"))
        request.timeoutInterval = 2
        let fixtureData: Data
        do { fixtureData = try await URLSession.shared.data(for: request).0 }
        catch { throw XCTSkip("Requires the explicitly authorized T-383 email bridge.") }
        let fixture = try JSONDecoder().decode(RecoveryDeliveryFixture.self, from: fixtureData)
        XCTAssertTrue(fixture.url.host == "lqmasbuqzvcvtawonjlb.supabase.co")
        let normal = fixture.client(key: "normal")
        let recovery = fixture.client(key: "recovery")
        let verification = fixture.client(key: "verification")
        do {
            let normalSession = try await normal.auth.signIn(email: fixture.normal.email, password: fixture.normal.password)
            let repository = SupabaseAuthSessionRepository(client: normal, recoveryClient: recovery)
            let store = AuthenticationStore(repository: repository)
            let observation = Task { await store.start() }
            defer { observation.cancel() }
            for _ in 0..<100 where store.rootState == .loading {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertTrue(store.rootState == .signedIn(.init(userID: fixture.normal.id, email: fixture.normal.email)))
            store.email = fixture.recovery.email
            await store.beginPasswordRecovery()
            await store.requestPasswordRecovery()
            XCTAssertTrue(store.recoveryState == .emailSent, "Real SDK email request must succeed")
            var callback: URL?
            for _ in 0..<240 {
                let data = try await URLSession.shared.data(from: bridge.appending(path: "callback")).0
                callback = try JSONDecoder().decode(RecoveryDeliveryCallback.self, from: data).callback
                if callback != nil { break }
                try await Task.sleep(for: .seconds(1))
            }
            guard let callback else { throw RecoveryDeliveryFailure.callbackMissing }
            await store.handleAuthCallback(callback)
            guard case let .newPassword(recovered) = store.recoveryState else { throw RecoveryDeliveryFailure.callbackRejected }
            XCTAssertTrue(recovered.userID == fixture.recovery.id)
            XCTAssertTrue(normal.auth.currentUser?.id == normalSession.user.id)
            store.recoveryPassword = fixture.newPassword
            store.recoveryPasswordConfirmation = fixture.newPassword
            await store.saveRecoveredPassword()
            XCTAssertTrue(store.recoveryState == .complete)
            XCTAssertNil(repository.recoverySession())
            await store.closePasswordRecovery()
            XCTAssertTrue(store.rootState == .signedIn(.init(userID: fixture.normal.id, email: fixture.normal.email)))
            await store.handleAuthCallback(callback)
            XCTAssertTrue(store.recoveryState == .invalidLink)
            XCTAssertTrue(normal.auth.currentUser?.id == fixture.normal.id)
            await store.closePasswordRecovery()
            let newSession = try await verification.auth.signIn(email: fixture.recovery.email, password: fixture.newPassword)
            XCTAssertTrue(newSession.user.id == fixture.recovery.id)
            try await verification.auth.signOut()
            try await normal.auth.signOut()
        } catch {
            try? await verification.auth.signOut()
            try? await recovery.auth.signOut()
            try? await normal.auth.signOut()
            var finish = URLRequest(url: bridge.appending(path: "finish")); finish.httpMethod = "POST"
            _ = try? await URLSession.shared.data(for: finish)
            // SDK errors can contain sensitive payloads; report only the failed phase.
            XCTFail("Controlled recovery failed; inspect the boolean assertions and sanitized bridge evidence.")
            return
        }
        var finish = URLRequest(url: bridge.appending(path: "finish")); finish.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: finish)
        XCTAssertTrue((response as? HTTPURLResponse)?.statusCode == 200)
    }
}

private struct RecoveryDeliveryFixture: Decodable {
    struct Account: Decodable { let id: UUID; let email: String; let password: String }
    let url: URL
    let key: String
    let normal: Account
    let recovery: Account
    let newPassword: String

    @MainActor func client(key storageKey: String) -> SupabaseClient {
        SupabaseClient(supabaseURL: url, supabaseKey: key, options: .init(auth: .init(
            storage: RecoveryDeliveryMemory(), redirectToURL: AuthCallbackConfiguration.recoveryURL,
            storageKey: "t383-\(storageKey)", flowType: .pkce, autoRefreshToken: false,
            emitLocalSessionAsInitialSession: true)))
    }
}

private struct RecoveryDeliveryCallback: Decodable { let callback: URL? }
private enum RecoveryDeliveryFailure: Error { case callbackMissing, callbackRejected }

nonisolated private final class RecoveryDeliveryMemory: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { lock.withLock { _ = values.removeValue(forKey: key) } }
}
