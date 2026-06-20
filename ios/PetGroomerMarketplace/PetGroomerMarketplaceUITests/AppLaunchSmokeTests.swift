import XCTest

final class AppLaunchSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNormalLaunchShowsOnlyAuthenticationRoot() {
        let app = XCUIApplication()

        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["auth.bootstrap"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.descendants(matching: .any)["customer.tabs"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["groomer.tabs"].exists)
    }
}
