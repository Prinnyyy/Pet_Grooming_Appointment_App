import XCTest

final class TestOpsLaunchSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchWithTestOpsArgumentsShowsAuthenticationRoot() {
        let driver = TestOpsUIFlowDriver()

        driver.launchSignedOut()
        driver.assertAuthenticationRoot()
    }

    @MainActor
    func testSeededCustomerCanNavigateTabsOpenRequestSheetAndResetSession() throws {
        let account = try TestOpsSeedAccount.fromEnvironment(role: .customer)
        let driver = TestOpsUIFlowDriver()

        driver.launchSignedOut()
        driver.signIn(account)
        driver.assertCustomerNavigation()
        driver.openAndDismissCustomerRequestSheet()
        driver.resetSession()
    }

    @MainActor
    func testSeededGroomerCanNavigateTabs() throws {
        let account = try TestOpsSeedAccount.fromEnvironment(role: .groomer)
        let driver = TestOpsUIFlowDriver()

        driver.launchSignedOut()
        driver.signIn(account)
        driver.assertGroomerNavigation()
    }

    @MainActor
    func testSeededGroomerCanOpenFocusedAccountWorkspaces() throws {
        let account = try TestOpsSeedAccount.fromEnvironment(role: .groomer)
        let driver = TestOpsUIFlowDriver()

        driver.launchSignedOut()
        driver.signIn(account)
        driver.assertGroomerFocusedAccountWorkspaces()
    }

    @MainActor
    func testSeededGroomerAvailabilityDraftCanBeKeptDiscardedAndReloaded() throws {
        let account = try TestOpsSeedAccount.fromEnvironment(role: .groomer)
        let driver = TestOpsUIFlowDriver()
        driver.launchSignedOut()
        driver.signIn(account)
        driver.assertAvailabilityDraftRecovery()
    }

    @MainActor
    func testSeededGroomerAvailabilitySavePersistsAfterReload() throws {
        let environment = ProcessInfo.processInfo.environment
        guard (environment["TESTOPS_AVAILABILITY_WRITE_APPROVED"]
            ?? environment["TEST_RUNNER_TESTOPS_AVAILABILITY_WRITE_APPROVED"]) == "1" else {
            throw XCTSkip("Run through the authorized T-371 fixture backup/restore wrapper.")
        }
        let account = try TestOpsSeedAccount.fromEnvironment(role: .groomer)
        let driver = TestOpsUIFlowDriver()
        driver.launchSignedOut()
        driver.signIn(account)
        driver.assertAvailabilitySavePersists()
    }
}
