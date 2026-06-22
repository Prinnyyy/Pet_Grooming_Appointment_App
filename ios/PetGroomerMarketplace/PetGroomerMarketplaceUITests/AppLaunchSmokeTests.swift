import XCTest

final class AppLaunchSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNormalLaunchShowsOnlyAuthenticationRoot() {
        let app = XCUIApplication()

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
}
