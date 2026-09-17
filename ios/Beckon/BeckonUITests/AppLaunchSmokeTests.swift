import XCTest

final class AppLaunchSmokeTests: XCTestCase {
    @MainActor
    func testPasswordRecoveryEntryAndReturnToSignIn() {
        let app = XCUIApplication()
        app.launchArguments.append("--beckon-ui-test-signed-out-auth")
        app.launch()
        let signIn = app.buttons["auth.already-have-account"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()
        let forgotPassword = app.buttons["auth.forgot-password"]
        XCTAssertTrue(forgotPassword.waitForExistence(timeout: 5))
        // The form slides in; do not tap an accessibility frame that is still moving.
        var previousFrame = CGRect.null
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = forgotPassword.frame
            defer { previousFrame = frame }
            return forgotPassword.isHittable && frame == previousFrame
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
        forgotPassword.tap()
        XCTAssertTrue(app.textFields["auth.recovery.email"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "password-recovery-request"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["auth.forgot-password"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["customer.tabs"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["groomer.tabs"].exists)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNormalLaunchShowsOnlyAuthenticationRoot() {
        let app = XCUIApplication()
        app.launchArguments.append("--beckon-ui-test-signed-out-auth")

        app.launch()

        let authenticationRoot = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier == 'auth.landing' OR identifier == 'auth.form' OR identifier == 'auth.bootstrap'"
                )
            )
            .firstMatch

        XCTAssertTrue(
            authenticationRoot.waitForExistence(timeout: 5),
            "Expected the authentication landing, form, or configuration bootstrap to appear."
        )
        XCTAssertFalse(app.descendants(matching: .any)["customer.tabs"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["groomer.tabs"].exists)
    }

    @MainActor
    func testDebugQuickLoginButtonsAppearOnSignInForm() {
        let app = XCUIApplication()
        app.launchArguments.append("--beckon-ui-test-signed-out-auth")

        app.launch()

        let signInEntry = app.buttons["auth.already-have-account"]
        XCTAssertTrue(
            signInEntry.waitForExistence(timeout: 5),
            "Expected the signed-out landing sign-in entry to appear."
        )

        signInEntry.tap()

        let customerQuickLogin = app.buttons["auth.debug-login.customer"]
        let groomerQuickLogin = app.buttons["auth.debug-login.groomer"]

        XCTAssertTrue(customerQuickLogin.waitForExistence(timeout: 5))
        XCTAssertTrue(groomerQuickLogin.exists)
    }
}
