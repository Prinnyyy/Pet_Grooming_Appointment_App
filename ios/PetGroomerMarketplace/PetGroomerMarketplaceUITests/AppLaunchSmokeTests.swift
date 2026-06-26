import XCTest

final class AppLaunchSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNormalLaunchShowsOnlyAuthenticationRoot() {
        let app = XCUIApplication()
        app.launchArguments.append("--groomly-ui-test-signed-out-auth")

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
        app.launchArguments.append("--groomly-ui-test-signed-out-auth")

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
