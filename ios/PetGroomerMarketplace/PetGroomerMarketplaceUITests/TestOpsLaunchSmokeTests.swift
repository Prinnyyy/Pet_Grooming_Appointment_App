import XCTest

final class TestOpsLaunchSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchWithTestOpsArgumentsShowsAuthenticationRoot() {
        let app = XCUIApplication()
        let environment = ProcessInfo.processInfo.environment
        let runID = environment["TESTOPS_RUN_ID"] ?? "TESTOPS-UITEST-0001"
        let scenarioID = environment["TESTOPS_SCENARIO_ID"] ?? "marketplace_full_lifecycle"
        app.launchArguments.append(contentsOf: [
            "--groomly-testops-run-id",
            runID,
            "--groomly-testops-scenario",
            scenarioID,
            "--groomly-testops-clear-session",
            "--groomly-testops-disable-animations",
        ])

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
            "Expected TestOps clear-session launch to reach authentication root."
        )
        XCTAssertFalse(app.descendants(matching: .any)["customer.tabs"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["groomer.tabs"].exists)
    }
}
