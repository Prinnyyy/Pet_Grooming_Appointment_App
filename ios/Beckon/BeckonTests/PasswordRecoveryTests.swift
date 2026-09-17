import Foundation
import Testing
@testable import Beckon

@MainActor
struct PasswordRecoveryTests {
    @Test func failedRecoveryEntryCleanupHasAVisibleRetryPath() async {
        let repository = AuthSessionRepositoryFake()
        repository.recoveryEndError = .networkUnavailable
        let store = AuthenticationStore(repository: repository)
        await store.start()
        store.email = "reset@example.com"
        await store.beginPasswordRecovery()
        #expect(store.recoveryState == .request)
        #expect(store.recoveryError != nil)
        #expect(store.recoveryEmail == "reset@example.com")
        #expect(repository.recoveryRequestCount == 0)
        repository.recoveryEndError = nil
        await store.requestPasswordRecovery()
        #expect(store.recoveryState == .emailSent)
        #expect(store.rootState == .signedOut)
    }

    @Test func requestResendAndFailureStayIndependentOfNormalAuthentication() async {
        let current = AuthSessionSnapshot(userID: UUID(), email: "current@example.com")
        let repository = AuthSessionRepositoryFake(currentSession: current)
        let store = AuthenticationStore(repository: repository)
        await store.start()
        store.email = "  RESET@Example.com "
        await store.beginPasswordRecovery()
        await store.requestPasswordRecovery()
        #expect(store.recoveryState == .emailSent)
        #expect(repository.recoveryRequestedEmail == "reset@example.com")
        #expect(repository.recoveryRedirect == AuthCallbackConfiguration.recoveryURL)
        #expect(store.rootState == .signedIn(current))
        repository.recoveryRequestError = .networkUnavailable
        await store.requestPasswordRecovery()
        #expect(store.recoveryError?.contains("connection") == true)
        repository.recoveryRequestError = nil
        await store.requestPasswordRecovery()
        #expect(repository.recoveryRequestCount == 3)
        #expect(store.recoveryError == nil)
    }

    @Test func validRecoveryUpdatesOnlyRecoveryAccountAndDoesNotRepeatSuccessfulWrite() async {
        let current = AuthSessionSnapshot(userID: UUID(), email: "current@example.com")
        let recovered = AuthSessionSnapshot(userID: UUID(), email: "reset@example.com")
        let repository = AuthSessionRepositoryFake(currentSession: current)
        repository.recoveryCallbackResult = .success(recovered)
        let store = AuthenticationStore(repository: repository)
        await store.start()
        await store.handleAuthCallback(AuthCallbackConfiguration.recoveryURL.appending(queryItems: [.init(name: "code", value: "fixture")]))
        #expect(store.recoveryState == .newPassword(recovered))
        #expect(store.rootState == .signedIn(current))
        store.recoveryPassword = "Recovery-test-only-123"
        store.recoveryPasswordConfirmation = store.recoveryPassword
        repository.recoveryEndError = .networkUnavailable
        await store.saveRecoveredPassword()
        #expect(repository.recoveryUpdateUserID == recovered.userID)
        #expect(repository.recoveryUpdateCount == 1)
        #expect(store.recoveryPassword.isEmpty)
        repository.recoveryEndError = nil
        await store.saveRecoveredPassword()
        #expect(repository.recoveryUpdateCount == 1)
        #expect(store.recoveryState == .complete)
        await store.closePasswordRecovery()
        #expect(store.recoveryState == nil)
        #expect(store.rootState == .signedIn(current))
        #expect(repository.signInCallCount == 0)
        #expect(repository.signOutCallCount == 0)
    }

    @Test(arguments: [AuthSessionError.invalidCallback, .networkUnavailable])
    func invalidUsedOrInterruptedCallbackHasARecoveryPath(_ error: AuthSessionError) async {
        let repository = AuthSessionRepositoryFake()
        repository.recoveryCallbackResult = .failure(error)
        let store = AuthenticationStore(repository: repository)
        await store.start()
        let url = AuthCallbackConfiguration.recoveryURL.appending(queryItems: [.init(name: "code", value: "fixture")])
        await store.handleAuthCallback(url)
        #expect(store.rootState == .signedOut)
        #expect(store.recoveryState == .invalidLink)
        #expect(store.canRetryRecoveryLink == (error == .networkUnavailable))
        if error == .networkUnavailable {
            let valid = AuthSessionSnapshot(userID: UUID(), email: "reset@example.com")
            repository.recoveryCallbackResult = .success(valid)
            await store.retryRecoveryLink()
            #expect(store.recoveryState == .newPassword(valid))
        } else {
            store.recoveryEmail = "reset@example.com"
            await store.requestPasswordRecovery()
            #expect(store.recoveryState == .emailSent)
        }
    }

    @Test func errorFragmentAndExpiredRecoverySessionNeverEnterMarketplace() async {
        let repository = AuthSessionRepositoryFake()
        repository.currentRecovery = AuthSessionSnapshot(userID: UUID(), email: "reset@example.com", isExpired: true)
        let store = AuthenticationStore(repository: repository)
        await store.start()
        #expect(store.recoveryState == .invalidLink)
        await store.handleAuthCallback(URL(string: "com.hellobeckon.beckon://auth/recovery#error_code=otp_expired")!)
        #expect(repository.recoveryCallbackCount == 0)
        #expect(store.recoveryState == .invalidLink)
        #expect(store.rootState == .signedOut)
    }

    @Test func restoredRecoveryCanResumeWithoutRestoringNormalLogin() async {
        let recovered = AuthSessionSnapshot(userID: UUID(), email: "reset@example.com")
        let repository = AuthSessionRepositoryFake()
        repository.currentRecovery = recovered
        let store = AuthenticationStore(repository: repository)
        await store.start()
        #expect(store.rootState == .signedOut)
        #expect(store.recoveryState == .newPassword(recovered))
        store.recoveryPassword = "short"
        store.recoveryPasswordConfirmation = "other"
        await store.saveRecoveredPassword()
        #expect(repository.recoveryUpdateCount == 0)
        store.recoveryPassword = "Recovery-test-only-123"
        await store.saveRecoveredPassword()
        #expect(repository.recoveryUpdateCount == 0)
        await store.closePasswordRecovery()
        #expect(repository.currentRecovery == nil)
    }
}
