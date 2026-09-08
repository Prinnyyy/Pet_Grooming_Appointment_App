import Foundation
import Supabase
import Testing
@testable import Beckon

struct AuthenticationKeyboardFocusContractTests {
    @Test
    func authenticationAndOnboardingTargetsAreStable() {
        #expect(AuthenticationFocusTarget.email.rawValue == "auth.email.container")
        #expect(AuthenticationFocusTarget.password.rawValue == "auth.password.container")
        #expect(
            AuthenticationFocusTarget.passwordConfirmation.rawValue
                == "auth.password-confirmation.container"
        )
        #expect(RoleOnboardingFocusTarget.displayName.rawValue == "profile.display-name.container")
    }
}

struct AppEntryModelsTests {
    @Test
    func userRolesHaveExactOrderAndRoutes() {
        #expect(UserRole.allCases == [.customer, .groomer])
        #expect(UserRole.customer.entryRoute == .customer)
        #expect(UserRole.groomer.entryRoute == .groomer)
        #expect(UserRole.customer.id == .customer)
        #expect(UserRole.groomer.id == .groomer)
    }

    @Test
    func appEntryRoutesHaveExactOrderAndProductionDefault() {
        #expect(
            AppEntryRoute.allCases == [
                .authentication,
                .roleOnboarding,
                .customer,
                .groomer,
            ]
        )
        #expect(AppEntryRoute.productionDefault == .authentication)
        #expect(AppEntryRoute.authentication.id == .authentication)
    }

    @Test @MainActor
    func uiTestsCanForceSignedOutAuthenticationAtLaunch() {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "BeckonUITests",
                "--beckon-ui-test-signed-out-auth",
            ]
        )

        #expect(configuration.usesSignedOutAuthSessionRepository)
    }

    @Test @MainActor
    func testOpsLaunchArgumentsParseRunScenarioAndSessionControls() {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "Beckon",
                "--beckon-testops-run-id",
                "TESTOPS-20260701-123456",
                "--beckon-testops-scenario",
                "marketplace_full_lifecycle",
                "--beckon-testops-clear-session",
                "--beckon-testops-disable-animations",
            ]
        )

        #expect(configuration.testOps.runID == "TESTOPS-20260701-123456")
        #expect(configuration.testOps.scenarioID == "marketplace_full_lifecycle")
        #expect(configuration.testOps.clearsSessionBeforeRestore)
        #expect(configuration.testOps.disablesAnimations)
        #expect(configuration.testOps.isEnabled)
        #expect(configuration.usesSignedOutAuthSessionRepository == false)
    }

    @Test @MainActor
    func testOpsLaunchArgumentsIgnoreMissingValuesSafely() {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "Beckon",
                "--beckon-testops-run-id",
                "--beckon-testops-scenario",
            ]
        )

        #expect(configuration.testOps.runID == nil)
        #expect(configuration.testOps.scenarioID == nil)
        #expect(configuration.testOps.isEnabled == false)
    }

    @Test
    func testOpsAccessibilityIdentifiersUseSafeRunTagsAndSupportReferences() throws {
        let requestID = try #require(
            UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")
        )

        #expect(
            AppTestOpsAccessibility.runID(
                fromServiceNotes: "TESTOPS:TESTOPS-UI-20260709 full lifecycle"
            ) == "TESTOPS-UI-20260709"
        )
        #expect(
            AppTestOpsAccessibility.identifier(
                prefix: "groomer.requests.row",
                serviceNotes: "TESTOPS:TESTOPS-UI-20260709 full lifecycle"
            ) == "groomer.requests.row.TESTOPS-UI-20260709"
        )
        #expect(AppTestOpsAccessibility.requestReference(requestID) == "123E4567")
        #expect(
            AppTestOpsAccessibility.requestIdentifier(
                prefix: "bookings.row.request",
                requestID: requestID
            ) == "bookings.row.request.123E4567"
        )
        #expect(AppTestOpsAccessibility.runID(fromServiceNotes: "ordinary notes") == nil)
        #expect(
            AppTestOpsAccessibility.runID(
                fromServiceNotes: "TESTOPS:unsafe/value request"
            ) == nil
        )
    }
}

struct TabModelsTests {
    @Test
    func customerTabsHaveExactOrderTitlesAndSymbols() {
        #expect(CustomerTab.allCases == [.home, .requests, .bookings, .messages, .account])
        #expect(CustomerTab.allCases.map(\.title) == ["Home", "Requests", "Bookings", "Messages", "Account"])
        #expect(CustomerTab.allCases.map(\.systemImage) == ["house", "list.bullet.clipboard", "calendar", "message", "person.crop.circle"])
        #expect(CustomerTab.allCases.allSatisfy { $0.id == $0 })
        #expect(CustomerTab.allCases.map(\.accessibilityIdentifier) == [
            "customer.tab.home",
            "customer.tab.requests",
            "customer.tab.bookings",
            "customer.tab.messages",
            "customer.tab.account",
        ])
    }

    @Test
    func groomerTabsHaveExactOrderTitlesAndSymbols() {
        #expect(GroomerTab.allCases == [.home, .requests, .bookings, .messages, .account])
        #expect(GroomerTab.allCases.map(\.title) == ["Home", "Requests", "Schedule", "Messages", "Account"])
        #expect(GroomerTab.allCases.map(\.systemImage) == ["house", "person.2", "calendar", "message", "person.crop.circle"])
        #expect(GroomerTab.allCases.allSatisfy { $0.id == $0 })
        #expect(GroomerTab.allCases.map(\.accessibilityIdentifier) == [
            "groomer.tab.home",
            "groomer.tab.requests",
            "groomer.tab.bookings",
            "groomer.tab.messages",
            "groomer.tab.account",
        ])
    }

    @Test
    func groomerRequestsSegmentsExposeStablePresentation() {
        #expect(GroomerRequestsSegment.allCases == [.matches, .offers])
        #expect(GroomerRequestsSegment.allCases.map(\.title) == ["Matches", "Offers"])
        #expect(GroomerRequestsSegment.matches.accessibilityIdentifier == "groomer.requests.segment.matches")
        #expect(GroomerRequestsSegment.offers.accessibilityIdentifier == "groomer.requests.segment.offers")
        #expect(GroomerRequestsSegment.matches.count(matches: 4, offers: 2) == 4)
        #expect(GroomerRequestsSegment.offers.count(matches: 4, offers: 2) == 2)
    }

    @Test
    func groomerRequestsRoutingSelectsTheRequestedWorkspaceSegment() {
        let requestID = UUID()
        let offerID = UUID()
        #expect(GroomerRequestsRoute.matches.segment == .matches)
        #expect(GroomerRequestsRoute.offers.segment == .offers)
        #expect(
            GroomerRequestsRoute(notificationRoute: .requests(requestID: requestID))
                == GroomerRequestsRoute(segment: .matches, requestID: requestID, offerID: nil)
        )
        #expect(
            GroomerRequestsRoute(notificationRoute: .offers(offerID: offerID))
                == GroomerRequestsRoute(segment: .offers, requestID: nil, offerID: offerID)
        )
        #expect(GroomerRequestsRoute(notificationRoute: .bookings(bookingID: nil)) == nil)
        #expect(GroomerRequestsRoute(notificationRoute: .messages(bookingID: UUID())) == nil)
    }

    @Test
    func groomerProfileDeepLinkWaitsForLoadedProfile() {
        #expect(
            GroomerProfileRoute.activatedRoute(
                requested: .availability,
                isProfileLoaded: false
            ) == nil
        )
        #expect(
            GroomerProfileRoute.activatedRoute(
                requested: .availability,
                isProfileLoaded: true
            ) == .availability
        )
    }
}

struct BeckonFeedbackCenterTests {
    @Test @MainActor
    func noticeCountdownUsesTwoSeconds() {
        #expect(BeckonFeedbackCenter.noticeDismissDelayNanoseconds == 2_000_000_000)
    }

    @Test @MainActor
    func globalNoticeOverlayKeepsClearanceAboveTabBar() {
        #expect(BeckonGlobalFeedbackOverlay.bottomTabBarClearance >= 72)
    }

    @Test @MainActor
    func sheetNoticeOverlayUsesSheetBottomClearance() {
        #expect(BeckonGlobalFeedbackOverlay.sheetBottomClearance < BeckonGlobalFeedbackOverlay.bottomTabBarClearance)
    }

    @Test @MainActor
    func newNoticeWaitsUntilVisibleNoticeDismissesBeforeShowing() async throws {
        let center = BeckonFeedbackCenter()

        let firstID = center.showNotice("Request Cancelled.")
        let secondID = center.showNotice("Message Sent.")

        #expect(firstID != secondID)
        #expect(center.notice?.id == firstID)
        #expect(center.notice?.message == "Request Cancelled.")

        center.clearNotice(id: firstID)
        #expect(center.notice == nil)

        try await waitForFeedbackQueueAdvance(in: center)

        #expect(center.notice?.id == secondID)
        #expect(center.notice?.message == "Message Sent.")

        center.clearNotice(id: secondID)
        #expect(center.notice == nil)
    }

    @Test @MainActor
    func globalFeedbackCenterQueuesMixedPromptTypesOneAtATime() async throws {
        let center = BeckonFeedbackCenter()
        let error = BeckonGlobalFeedbackError(
            title: "Booking Update Failed",
            message: "We could not load bookings. Please try again."
        )
        let progress = BeckonGlobalFeedbackProgress(
            title: "Completing…",
            tone: .groomer
        )

        let noticeID = center.showNotice("Request Cancelled.")
        center.showError(error)
        center.showProgress(progress)

        #expect(center.notice?.id == noticeID)
        #expect(center.error == nil)
        #expect(center.progress == nil)

        center.clearNotice(id: noticeID)
        #expect(center.hasVisiblePrompt == false)

        try await waitForFeedbackQueueAdvance(in: center)

        #expect(center.notice == nil)
        #expect(center.error?.title == error.title)
        #expect(center.error?.message == error.message)
        #expect(center.progress == nil)

        center.clearError(matching: error)
        #expect(center.hasVisiblePrompt == false)

        try await waitForFeedbackQueueAdvance(in: center)

        #expect(center.notice == nil)
        #expect(center.error == nil)
        #expect(center.progress?.title == progress.title)
        #expect(center.progress?.tone == progress.tone)

        center.clearProgress(matching: progress)

        #expect(center.error == nil)
        #expect(center.progress == nil)
    }

    @Test @MainActor
    func errorPromptAutoDismissesAndDoesNotReplayUntilSourceClears() async throws {
        let center = BeckonFeedbackCenter()
        let error = BeckonGlobalFeedbackError(
            title: "Booking Update Failed",
            message: "We could not load bookings. Please try again."
        )

        center.showError(error)
        #expect(center.error?.title == error.title)

        try await waitForFeedbackPromptAutoDismiss(in: center)

        #expect(center.error == nil)
        #expect(center.hasVisiblePrompt == false)

        center.showError(error)
        #expect(center.error == nil)

        center.clearError(matching: error)
        center.showError(error)
        #expect(center.error?.title == error.title)
    }

    @Test @MainActor
    func clearingPageScopeRemovesOnlyPageScopedToastPrompts() async throws {
        let center = BeckonFeedbackCenter()
        let pageScope = BeckonFeedbackScope.page("customer.bookings")
        let pageError = BeckonGlobalFeedbackError(
            scope: pageScope,
            sourceKey: "bookings.load",
            title: "Booking Update Failed",
            message: "We could not load bookings. Please try again."
        )
        let queuedPageError = BeckonGlobalFeedbackError(
            scope: pageScope,
            sourceKey: "bookings.refresh",
            title: "Booking Refresh Failed",
            message: "Pull to refresh and try again."
        )
        let operationError = BeckonGlobalFeedbackError(
            scope: .operation("bookings.cancel"),
            sourceKey: "bookings.cancel",
            title: "Cancellation Failed",
            message: "We could not cancel this booking."
        )

        center.showError(pageError)
        center.showError(queuedPageError)
        center.showError(operationError)

        #expect(center.error == pageError)

        center.clearTransientPrompts(in: pageScope)
        #expect(center.error == nil)

        try await waitForFeedbackQueueAdvance(in: center)

        #expect(center.error == operationError)
        #expect(center.error?.scope == .operation("bookings.cancel"))
    }

    @Test @MainActor
    func persistentErrorsKeepStableScopeAndSourceIdentity() {
        let error = BeckonPersistentFeedbackError(
            scope: .page("customer.bookings"),
            sourceKey: "bookings.load",
            title: "We Could Not Load Bookings",
            message: "Check your connection and try again.",
            actionTitle: "Try Again"
        )
        let sameSource = BeckonPersistentFeedbackError(
            scope: .page("customer.bookings"),
            sourceKey: "bookings.load",
            title: "We Could Not Load Bookings",
            message: "Check your connection and try again.",
            actionTitle: "Try Again"
        )
        let otherPage = BeckonPersistentFeedbackError(
            scope: .page("customer.requests"),
            sourceKey: "bookings.load",
            title: "We Could Not Load Bookings",
            message: "Check your connection and try again.",
            actionTitle: "Try Again"
        )

        #expect(error.identityKey == sameSource.identityKey)
        #expect(error.identityKey != otherPage.identityKey)
        #expect(error.actionTitle == "Try Again")
    }

    @MainActor
    private func waitForFeedbackQueueAdvance(in center: BeckonFeedbackCenter) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !center.hasVisiblePrompt, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(center.hasVisiblePrompt, "Feedback queue did not advance before the deadline")
    }

    @MainActor
    private func waitForFeedbackPromptAutoDismiss(
        in center: BeckonFeedbackCenter
    ) async throws {
        let deadline = Date().addingTimeInterval(
            Double(BeckonFeedbackCenter.errorDismissDelayNanoseconds) / 1_000_000_000 + 2
        )
        while center.error != nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

struct DebugDiagnosticsTests {
    @Test @MainActor
    func diagnosticsHideSecretsAndUseSupportReferences() throws {
        let userID = try #require(
            UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        )
        let configuration = try SupabaseConfiguration.parse(
            urlValue: "https://lqmasbuqzvcvtawonjlb.supabase.co",
            publishableKeyValue: "sb_publishable_full_key_value_must_not_render"
        )

        let diagnostics = DebugDiagnostics.make(
            session: AuthSessionSnapshot(
                userID: userID,
                email: "owner@example.com"
            ),
            profile: MarketplaceProfile(
                userID: userID,
                role: .customer,
                displayName: "Owner"
            ),
            configuration: configuration,
            bundleIdentifier: "com.hellobeckon.beckon",
            buildConfiguration: "Debug"
        )
        let renderedValues = [
            diagnostics.buildConfiguration,
            diagnostics.bundleIdentifier,
            diagnostics.role,
            diagnostics.userReference,
            diagnostics.emailDomain ?? "",
            diagnostics.supabaseScheme,
            diagnostics.supabaseHost,
            diagnostics.publishableKeyStatus,
            diagnostics.sensitiveDataNotice,
        ].joined(separator: "\n")

        #expect(diagnostics.userReference == "11111111")
        #expect(diagnostics.emailDomain == "example.com")
        #expect(renderedValues.contains("owner") == false)
        #expect(
            renderedValues.contains(
                "sb_publishable_full_key_value_must_not_render"
            ) == false
        )
        #expect(diagnostics.publishableKeyStatus == "Configured; value hidden")
    }
}

struct AuthenticationStoreTests {
    @Test @MainActor
    func supabaseClientEmitsStoredSessionBeforeRefresh() {
        #expect(
            SupabaseClientFactory.options.auth.emitLocalSessionAsInitialSession
        )
    }

    @Test @MainActor
    func signedOutLaunchAuthRepositoryDoesNotRestoreCachedSession() async {
        let store = AuthenticationStore(
            repository: SignedOutAuthSessionRepository()
        )

        await store.start()

        #expect(store.rootState == .signedOut)
    }

    @Test @MainActor
    func restoresExistingSession() async {
        let session = AuthSessionSnapshot(
            userID: UUID(),
            email: "user@example.com"
        )
        let repository = AuthSessionRepositoryFake(currentSession: session)
        let store = AuthenticationStore(repository: repository)

        await store.start()

        #expect(store.rootState == .signedIn(session))
    }

    @Test @MainActor
    func expiredStoredSessionRemainsLoadingUntilRefreshCompletes() async {
        let expiredSession = AuthSessionSnapshot(
            userID: UUID(),
            email: "user@example.com",
            isExpired: true
        )
        let repository = AuthSessionRepositoryFake(
            currentSession: expiredSession,
            stateChanges: [expiredSession]
        )
        let store = AuthenticationStore(repository: repository)

        await store.start()

        #expect(store.rootState == .loading)
    }

    @Test @MainActor
    func refreshedSessionSignsInAfterExpiredStoredSession() async {
        let userID = UUID()
        let expiredSession = AuthSessionSnapshot(
            userID: userID,
            email: "user@example.com",
            isExpired: true
        )
        let refreshedSession = AuthSessionSnapshot(
            userID: userID,
            email: "user@example.com"
        )
        let repository = AuthSessionRepositoryFake(
            currentSession: expiredSession,
            stateChanges: [expiredSession, refreshedSession]
        )
        let store = AuthenticationStore(repository: repository)

        await store.start()

        #expect(store.rootState == .signedIn(refreshedSession))
    }

    @Test @MainActor
    func failedExpiredSessionRefreshSignsOut() async {
        let expiredSession = AuthSessionSnapshot(
            userID: UUID(),
            email: "user@example.com",
            isExpired: true
        )
        let repository = AuthSessionRepositoryFake(
            currentSession: expiredSession,
            stateChanges: [expiredSession, nil]
        )
        let store = AuthenticationStore(repository: repository)

        await store.start()

        #expect(store.rootState == .signedOut)
    }

    @Test @MainActor
    func canClearLocalSessionBeforeRestoreForTestOps() async {
        let session = AuthSessionSnapshot(
            userID: UUID(),
            email: "user@example.com"
        )
        let repository = AuthSessionRepositoryFake(currentSession: session)
        let store = AuthenticationStore(
            repository: repository,
            clearsSessionBeforeRestore: true
        )

        await store.start()

        #expect(repository.signOutCallCount == 1)
        #expect(store.rootState == .signedOut)
    }

    @Test @MainActor
    func startsSignedOutWithoutSession() async {
        let store = AuthenticationStore(
            repository: AuthSessionRepositoryFake()
        )

        await store.start()

        #expect(store.rootState == .signedOut)
    }

    @Test @MainActor
    func signUpConfirmationRemainsSignedOut() async {
        let repository = AuthSessionRepositoryFake()
        repository.signUpResult = .success(
            .confirmationRequired(email: "new@example.com")
        )
        let store = AuthenticationStore(repository: repository)
        await store.start()
        store.mode = .signUp
        store.email = " NEW@EXAMPLE.COM "
        store.password = "password"
        store.passwordConfirmation = "password"

        await store.submit()

        #expect(store.rootState == .signedOut)
        #expect(
            store.noticeMessage
                == "Check your email to confirm your account, then sign in."
        )
        #expect(repository.lastEmail == "new@example.com")
        #expect(
            repository.lastRedirectURL?.absoluteString
                == "com.hellobeckon.beckon://auth/callback"
        )
        #expect(store.password.isEmpty)
        #expect(store.passwordConfirmation.isEmpty)
    }

    @Test @MainActor
    func successfulAuthCallbackSignsInWithoutExposingURLTokens() async {
        let session = AuthSessionSnapshot(
            userID: UUID(),
            email: "new@example.com"
        )
        let repository = AuthSessionRepositoryFake()
        repository.handleAuthCallbackResult = .success(session)
        let store = AuthenticationStore(repository: repository)
        await store.start()
        let callbackURL = URL(
            string:
                "com.hellobeckon.beckon://auth/callback?code=abc123&secret=must-not-display"
        )!

        await store.handleAuthCallback(callbackURL)

        #expect(repository.handleAuthCallbackCallCount == 1)
        #expect(repository.lastAuthCallbackURL == callbackURL)
        #expect(store.rootState == .signedIn(session))
        #expect(store.noticeMessage == "Email confirmed. You are signed in.")
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func authCallbackErrorFragmentShowsSafeRecoveryCopy() async {
        let repository = AuthSessionRepositoryFake()
        let store = AuthenticationStore(repository: repository)
        await store.start()
        let callbackURL = URL(
            string:
                "com.hellobeckon.beckon://auth/callback#error=access_denied&error_code=otp_expired&error_description=Email+link+expired"
        )!

        await store.handleAuthCallback(callbackURL)

        #expect(repository.handleAuthCallbackCallCount == 0)
        #expect(store.rootState == .signedOut)
        #expect(
            store.errorMessage
                == "This sign-in link is expired or invalid. Please request a new email link."
        )
    }

    @Test @MainActor
    func malformedAuthCallbackDoesNotCallRepository() async {
        let repository = AuthSessionRepositoryFake()
        let store = AuthenticationStore(repository: repository)
        await store.start()
        let callbackURL = URL(
            string: "com.hellobeckon.beckon://wrong/path?code=abc123"
        )!

        await store.handleAuthCallback(callbackURL)

        #expect(repository.handleAuthCallbackCallCount == 0)
        #expect(
            store.errorMessage
                == "This sign-in link is expired or invalid. Please request a new email link."
        )
    }

    @Test @MainActor
    func invalidCredentialsRemainRecoverable() async {
        let repository = AuthSessionRepositoryFake()
        repository.signInResult = .failure(.invalidCredentials)
        let store = AuthenticationStore(repository: repository)
        await store.start()
        store.email = "user@example.com"
        store.password = "password"

        await store.submit()

        #expect(store.rootState == .signedOut)
        #expect(store.email == "user@example.com")
        #expect(store.password == "password")
        #expect(store.errorMessage == "The email or password is incorrect.")
        #expect(store.isSubmitting == false)
    }

    @Test @MainActor
    func invalidEmailDoesNotCallRepository() async {
        let repository = AuthSessionRepositoryFake()
        let store = AuthenticationStore(repository: repository)
        await store.start()
        store.email = "not-an-email"
        store.password = "password"

        await store.submit()

        #expect(repository.signInCallCount == 0)
        #expect(store.errorMessage == "Enter a valid email address.")
    }

    #if DEBUG
    @Test @MainActor
    func debugQuickLoginSignsInWithEmbeddedAccounts() async {
        let cases: [(DebugQuickLoginAccount, String)] = [
            (.customer, "prinnyyyyy@gmail.com"),
            (.groomer, "liafenyua@gmail.com")
        ]

        for (account, expectedEmail) in cases {
            let expectedSession = AuthSessionSnapshot(
                userID: UUID(),
                email: expectedEmail
            )
            let repository = AuthSessionRepositoryFake()
            repository.signInResult = .success(expectedSession)
            let store = AuthenticationStore(repository: repository)
            await store.start()

            await store.signInWithDebugAccount(account)

            #expect(store.mode == .signIn)
            #expect(repository.signInCallCount == 1)
            #expect(repository.lastEmail == expectedEmail)
            #expect(repository.lastPassword == "Lian532911")
            #expect(store.rootState == .signedIn(expectedSession))
            #expect(store.password.isEmpty)
        }
    }
    #endif

    @Test @MainActor
    func signOutReturnsToSignedOutState() async {
        let session = AuthSessionSnapshot(
            userID: UUID(),
            email: "user@example.com"
        )
        let repository = AuthSessionRepositoryFake(currentSession: session)
        let store = AuthenticationStore(repository: repository)
        await store.start()

        await store.signOut()

        #expect(repository.signOutCallCount == 1)
        #expect(store.rootState == .signedOut)
    }

    @Test @MainActor
    func deleteAccountAnonymizesAuthUserClearsLocalStateAndSignsOut() async {
        let session = AuthSessionSnapshot(
            userID: UUID(),
            email: "user@example.com"
        )
        let repository = AuthSessionRepositoryFake(currentSession: session)
        var cleanedUserIDs: [UUID] = []
        let store = AuthenticationStore(
            repository: repository,
            localAccountCleanup: { userID in
                cleanedUserIDs.append(userID)
            }
        )
        await store.start()

        await store.deleteAccount()

        #expect(repository.deleteAccountCallCount == 1)
        #expect(repository.signOutCallCount == 1)
        #expect(cleanedUserIDs == [session.userID])
        #expect(store.rootState == .signedOut)
        #expect(store.mode == .signIn)
        #expect(store.email.isEmpty)
        #expect(store.password.isEmpty)
        #expect(store.passwordConfirmation.isEmpty)
    }

    @Test @MainActor
    func deleteAccountFailureKeepsSignedInSessionAndShowsRecoveryCopy() async {
        let session = AuthSessionSnapshot(
            userID: UUID(),
            email: "user@example.com"
        )
        let repository = AuthSessionRepositoryFake(currentSession: session)
        repository.deleteAccountResult = .failure(.accountDeletionFailed)
        let store = AuthenticationStore(repository: repository)
        await store.start()

        await store.deleteAccount()

        #expect(repository.deleteAccountCallCount == 1)
        #expect(repository.signOutCallCount == 0)
        #expect(store.rootState == .signedIn(session))
        #expect(
            store.errorMessage
                == "We could not delete your account. Please try again."
        )
        #expect(store.isSubmitting == false)
    }
}

struct AuthenticatedEntryStoreTests {
    @Test @MainActor
    func missingProfileEntersOnboarding() async {
        let repository = ProfileRepositoryFake(
            profileResults: [.success(nil)]
        )
        let store = AuthenticatedEntryStore(repository: repository)

        await store.load(userID: UUID())

        #expect(store.state == .onboarding)
        #expect(repository.profileCallCount == 1)
    }

    @Test @MainActor
    func existingProfilesEnterTheirAuthoritativeRoutes() async {
        let customer = MarketplaceProfile(
            userID: UUID(),
            role: .customer,
            displayName: "Customer"
        )
        let groomer = MarketplaceProfile(
            userID: UUID(),
            role: .groomer,
            displayName: "Groomer"
        )
        let customerStore = AuthenticatedEntryStore(
            repository: ProfileRepositoryFake(
                profileResults: [.success(customer)]
            )
        )
        let groomerStore = AuthenticatedEntryStore(
            repository: ProfileRepositoryFake(
                profileResults: [.success(groomer)]
            )
        )

        await customerStore.load(userID: customer.userID)
        await groomerStore.load(userID: groomer.userID)

        #expect(customerStore.state == .customer(customer))
        #expect(groomerStore.state == .groomer(groomer))
    }

    @Test @MainActor
    func lookupFailureIsRetryableAndNeverBecomesMissing() async {
        let repository = ProfileRepositoryFake(
            profileResults: [
                .failure(.networkUnavailable),
                .success(nil),
            ]
        )
        let store = AuthenticatedEntryStore(repository: repository)

        await store.load(userID: UUID())
        #expect(
            store.state
                == .failure(
                    message: "We could not load your profile. Please try again."
                )
        )

        await store.retry()

        #expect(store.state == .onboarding)
        #expect(repository.profileCallCount == 2)
    }

    @Test @MainActor
    func invalidOnboardingInputDoesNotCallRepository() async {
        let repository = ProfileRepositoryFake()
        let store = AuthenticatedEntryStore(repository: repository)

        store.displayName = "   "
        store.selectedRole = .customer
        await store.submit()
        #expect(
            store.errorMessage
                == "Enter a display name between 1 and 80 characters."
        )

        store.displayName = "Valid name"
        store.selectedRole = nil
        await store.submit()
        #expect(
            store.errorMessage == "Choose Customer or Groomer to continue."
        )

        store.displayName = String(repeating: "a", count: 81)
        store.selectedRole = .groomer
        await store.submit()

        #expect(repository.createCallCount == 0)
    }

    @Test @MainActor
    func successfulCreationRoutesFromReturnedProfile() async {
        let authoritativeProfile = MarketplaceProfile(
            userID: UUID(),
            role: .groomer,
            displayName: "Alex"
        )
        let repository = ProfileRepositoryFake(
            createResult: .success(authoritativeProfile)
        )
        let store = AuthenticatedEntryStore(repository: repository)
        store.displayName = " Alex "
        store.selectedRole = .customer

        await store.submit()

        #expect(store.state == .groomer(authoritativeProfile))
        #expect(repository.lastCreatedRole == .customer)
        #expect(repository.lastCreatedDisplayName == "Alex")
    }

    @Test @MainActor
    func failedCreationPreservesFormAndAllowsRetry() async {
        let profile = MarketplaceProfile(
            userID: UUID(),
            role: .customer,
            displayName: "Alex"
        )
        let repository = ProfileRepositoryFake(
            createResult: .failure(.networkUnavailable)
        )
        let store = AuthenticatedEntryStore(repository: repository)
        store.displayName = " Alex "
        store.selectedRole = .customer

        await store.submit()

        #expect(store.displayName == "Alex")
        #expect(store.selectedRole == .customer)
        #expect(store.isSubmitting == false)
        #expect(store.errorMessage == "Check your connection and try again.")

        repository.createResult = .success(profile)
        await store.submit()

        #expect(repository.createCallCount == 2)
        #expect(store.state == .customer(profile))
    }

    @Test @MainActor
    func duplicateSubmissionIsIgnored() async {
        let profile = MarketplaceProfile(
            userID: UUID(),
            role: .customer,
            displayName: "Alex"
        )
        let repository = ProfileRepositoryFake()
        repository.suspendCreate = true
        let store = AuthenticatedEntryStore(repository: repository)
        store.displayName = "Alex"
        store.selectedRole = .customer

        let firstSubmission = Task {
            await store.submit()
        }
        while repository.createCallCount == 0 {
            await Task.yield()
        }

        await store.submit()

        #expect(repository.createCallCount == 1)
        repository.resumeCreate(with: .success(profile))
        await firstSubmission.value
        #expect(store.state == .customer(profile))
    }
}

@MainActor
private final class ProfileRepositoryFake: ProfileRepository {
    var profileResults: [Result<MarketplaceProfile?, ProfileRepositoryError>]
    var createResult: Result<MarketplaceProfile, ProfileRepositoryError>
    var suspendCreate = false

    private(set) var profileCallCount = 0
    private(set) var createCallCount = 0
    private(set) var lastCreatedRole: UserRole?
    private(set) var lastCreatedDisplayName: String?

    private var createContinuation:
        CheckedContinuation<MarketplaceProfile, any Error>?

    init(
        profileResults: [Result<MarketplaceProfile?, ProfileRepositoryError>] = [],
        createResult: Result<MarketplaceProfile, ProfileRepositoryError> =
            .failure(.unavailable)
    ) {
        self.profileResults = profileResults
        self.createResult = createResult
    }

    func profile(userID: UUID) async throws -> MarketplaceProfile? {
        profileCallCount += 1
        guard !profileResults.isEmpty else { return nil }
        return try profileResults.removeFirst().get()
    }

    func createProfile(
        role: UserRole,
        displayName: String
    ) async throws -> MarketplaceProfile {
        createCallCount += 1
        lastCreatedRole = role
        lastCreatedDisplayName = displayName

        if suspendCreate {
            return try await withCheckedThrowingContinuation { continuation in
                createContinuation = continuation
            }
        }

        return try createResult.get()
    }

    func resumeCreate(
        with result: Result<MarketplaceProfile, ProfileRepositoryError>
    ) {
        createContinuation?.resume(with: result.mapError { $0 as any Error })
        createContinuation = nil
    }
}

@MainActor
private final class AuthSessionRepositoryFake: AuthSessionRepository {
    private let initialSession: AuthSessionSnapshot?
    private let stateStream: AsyncStream<AuthSessionSnapshot?>

    var signUpResult: Result<AuthSignUpOutcome, AuthSessionError> =
        .failure(.unavailable)
    var signInResult: Result<AuthSessionSnapshot, AuthSessionError> =
        .failure(.unavailable)
    var signOutResult: Result<Void, AuthSessionError> = .success(())
    var deleteAccountResult: Result<Void, AuthSessionError> = .success(())
    var handleAuthCallbackResult: Result<AuthSessionSnapshot, AuthSessionError> =
        .failure(.unavailable)

    private(set) var lastEmail: String?
    private(set) var lastPassword: String?
    private(set) var lastRedirectURL: URL?
    private(set) var lastAuthCallbackURL: URL?
    private(set) var signInCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var deleteAccountCallCount = 0
    private(set) var handleAuthCallbackCallCount = 0

    init(
        currentSession: AuthSessionSnapshot? = nil,
        stateChanges: [AuthSessionSnapshot?] = []
    ) {
        initialSession = currentSession
        stateStream = AsyncStream { continuation in
            for state in stateChanges {
                continuation.yield(state)
            }
            continuation.finish()
        }
    }

    func currentSession() -> AuthSessionSnapshot? {
        initialSession
    }

    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?> {
        stateStream
    }

    func signUp(
        email: String,
        password: String,
        redirectTo: URL?
    ) async throws -> AuthSignUpOutcome {
        lastEmail = email
        lastPassword = password
        lastRedirectURL = redirectTo
        return try signUpResult.get()
    }

    func handleAuthCallback(_ url: URL) async throws -> AuthSessionSnapshot {
        handleAuthCallbackCallCount += 1
        lastAuthCallbackURL = url
        return try handleAuthCallbackResult.get()
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> AuthSessionSnapshot {
        signInCallCount += 1
        lastEmail = email
        lastPassword = password
        return try signInResult.get()
    }

    func signOut() async throws {
        signOutCallCount += 1
        try signOutResult.get()
    }

    func deleteAccount() async throws {
        deleteAccountCallCount += 1
        try deleteAccountResult.get()
    }
}
