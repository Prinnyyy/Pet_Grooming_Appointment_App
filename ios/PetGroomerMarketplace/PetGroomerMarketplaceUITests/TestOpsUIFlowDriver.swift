import XCTest

enum TestOpsSeedRole: String {
    case customer
    case groomer

    var rootIdentifier: String {
        switch self {
        case .customer:
            "customer.tabs"
        case .groomer:
            "groomer.tabs"
        }
    }
}

struct TestOpsSeedAccount {
    let role: TestOpsSeedRole
    let email: String
    let password: String

    static func fromEnvironment(role: TestOpsSeedRole) throws -> Self {
        let environment = ProcessInfo.processInfo.environment
        let prefix = "TESTOPS_UI_\(role.rawValue.uppercased())"
        guard let email = environment.testOpsValue(for: "\(prefix)_EMAIL"),
              let password = environment.testOpsValue(for: "\(prefix)_PASSWORD") else {
            throw XCTSkip(
                "Set \(prefix)_EMAIL and \(prefix)_PASSWORD to run seeded UI navigation."
            )
        }

        return Self(role: role, email: email, password: password)
    }
}

private extension Dictionary where Key == String, Value == String {
    func testOpsValue(for key: String) -> String? {
        let value = self[key] ?? self["TEST_RUNNER_\(key)"]
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

@MainActor
final class TestOpsUIFlowDriver {
    private let app = XCUIApplication()
    private let environment = ProcessInfo.processInfo.environment

    func launchSignedOut() {
        app.launchArguments = [
            "--groomly-testops-run-id",
            environment["TESTOPS_RUN_ID"] ?? "TESTOPS-UITEST-0001",
            "--groomly-testops-scenario",
            environment["TESTOPS_SCENARIO_ID"] ?? "marketplace_full_lifecycle",
            "--groomly-testops-clear-session",
            "--groomly-testops-disable-animations",
        ]
        app.launch()
    }

    func assertAuthenticationRoot() {
        let authenticationRoot = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier == 'auth.landing' OR identifier == 'auth.form' OR identifier == 'auth.bootstrap'"
                )
            )
            .firstMatch

        XCTAssertTrue(
            authenticationRoot.waitForExistence(timeout: 8),
            "Expected TestOps clear-session launch to reach authentication root."
        )
        XCTAssertFalse(element("customer.tabs").exists)
        XCTAssertFalse(element("groomer.tabs").exists)
    }

    func signIn(_ account: TestOpsSeedAccount) {
        let signInEntry = app.buttons["auth.already-have-account"]
        XCTAssertTrue(signInEntry.waitForExistence(timeout: 8))
        signInEntry.tap()

        let emailField = app.textFields["auth.email"]
        let passwordField = app.secureTextFields["auth.password"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        XCTAssertTrue(passwordField.exists)

        emailField.tap()
        emailField.typeText(account.email)
        passwordField.tap()
        passwordField.typeText(account.password)
        app.buttons["auth.submit"].tap()

        XCTAssertTrue(
            element(account.role.rootIdentifier).waitForExistence(timeout: 20),
            "Expected seeded sign-in to reach the role tab root."
        )
    }

    func assertCustomerNavigation() {
        assertTab("customer.tab.home", destination: "customer.home")
        assertTab("customer.tab.requests", destination: "customer.requests.list")
        assertTab("customer.tab.bookings", destination: "bookings.list")
        assertTab("customer.tab.messages", destination: "chat.conversations.list")
        assertTab("customer.tab.account", destination: "customer.account")
        assertTab("customer.tab.home", destination: "customer.home")
    }

    func assertGroomerNavigation() {
        assertTab("groomer.tab.requests", destination: "groomer.requests.list")
        assertTab("groomer.tab.offers", destination: "groomer.offers")
        assertTab("groomer.tab.bookings", destination: "groomer.schedule")
        assertTab("groomer.tab.messages", destination: "chat.conversations.list")
        assertOverflowTab(
            "groomer.tab.notifications",
            fallbackLabel: "Alerts",
            destination: "groomer.notifications"
        )
        assertOverflowTab(
            "groomer.tab.account",
            fallbackLabel: "Account",
            destination: "groomer.account.home"
        )
    }

    func openAndDismissCustomerRequestSheet() {
        let startRequest = app.buttons["customer.home.start-request"]
        XCTAssertTrue(startRequest.waitForExistence(timeout: 8))
        XCTAssertTrue(startRequest.isEnabled)
        startRequest.tap()

        XCTAssertTrue(element("customer.requests.wizard").waitForExistence(timeout: 8))
        let dismissButton = app.buttons["customer.requests.wizard.dismiss"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 5))
        dismissButton.tap()
        XCTAssertTrue(element("customer.requests.wizard").waitForNonExistence(timeout: 8))
    }

    func resetSession() {
        app.terminate()
        app.launch()
        assertAuthenticationRoot()
    }

    private func assertTab(_ identifier: String, destination: String) {
        let tab = element(identifier)
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab selector \(identifier).")
        tab.tap()
        XCTAssertTrue(
            element(destination).waitForExistence(timeout: 12),
            "Expected \(identifier) to show \(destination)."
        )
    }

    private func assertOverflowTab(
        _ identifier: String,
        fallbackLabel: String,
        destination: String
    ) {
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 8), "Missing system More tab.")
        moreTab.tap()

        let identifiedTab = element(identifier)
        if identifiedTab.waitForExistence(timeout: 3) {
            identifiedTab.tap()
        } else {
            let fallback = app.staticTexts[fallbackLabel]
            XCTAssertTrue(
                fallback.waitForExistence(timeout: 5),
                "Missing overflow tab selector \(identifier)."
            )
            fallback.tap()
        }

        XCTAssertTrue(
            element(destination).waitForExistence(timeout: 12),
            "Expected \(identifier) to show \(destination)."
        )
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
