import XCTest

final class TestOpsLaunchSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAuthorizedInteractiveSeedSignIn() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let value = environment["TESTOPS_INTERACTIVE_ROLE"]
            ?? environment["TEST_RUNNER_TESTOPS_INTERACTIVE_ROLE"],
            let role = TestOpsSeedRole(rawValue: value) else {
            throw XCTSkip("Only the explicitly scoped interactive TestOps runner selects a role.")
        }
        let account = try TestOpsSeedAccount.fromEnvironment(role: role)
        let driver = TestOpsUIFlowDriver()
        driver.launchSignedOut()
        driver.signIn(account)
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

@MainActor
final class TestOpsBookingAdversarialTests: XCTestCase {
    private let app = XCUIApplication()
    private var runID: String { ProcessInfo.processInfo.environment["TESTOPS_RUN_ID"]
        ?? ProcessInfo.processInfo.environment["TEST_RUNNER_TESTOPS_RUN_ID"] ?? "" }
    private var references: [String] { (ProcessInfo.processInfo.environment["TEST_RUNNER_T387_REQUEST_REFS"]
        ?? ProcessInfo.processInfo.environment["T387_REQUEST_REFS"] ?? "").split(separator: ",").map(String.init) }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard runID.hasPrefix("TESTOPS-T387-"),
              (environment["TESTOPS_REMOTE_WRITE_APPROVED"]
                ?? environment["TEST_RUNNER_TESTOPS_REMOTE_WRITE_APPROVED"]) == "1" else {
            throw XCTSkip("Authorized scoped T-387 runner required.")
        }
    }

    private func start(_ role: TestOpsSeedRole) throws {
        let driver = TestOpsUIFlowDriver()
        driver.launchSignedOut()
        driver.signIn(try TestOpsSeedAccount.fromEnvironment(role: role))
    }

    private func element(_ id: String) -> XCUIElement {
        let button = app.buttons[id].firstMatch
        return button.exists ? button : app.descendants(matching: .any)[id].firstMatch
    }
    private func tap(_ item: XCUIElement) {
        if item.exists { print("T387 target \(item.identifier) / \(item.label) / \(item.frame)") }
        for _ in 0..<10 {
            if item.exists {
                let frame = item.frame
                if app.frame.contains(frame) && item.isHittable { break }
                if frame.maxX > app.frame.maxX { app.swipeLeft() }
                else if frame.minX < app.frame.minX { app.swipeRight() }
                else if frame.minY < app.frame.minY + 100 { app.swipeDown() }
                else { app.swipeUp() }
            } else { app.swipeUp() }
        }
        XCTAssertTrue(item.waitForExistence(timeout: 15))
        XCTAssertTrue(item.isHittable, "Not hittable: \(item.identifier) / \(item.label) / \(item.frame)")
        item.tap()
    }

    private func referenceRow(prefix: String, reference: String) -> XCUIElement {
        app.buttons.matching(identifier: "\(prefix).\(runID)")
            .matching(NSPredicate(format: "value == %@", reference)).firstMatch
    }

    private func finishInput() {
        let candidates = app.buttons.matching(NSPredicate(format:
            "identifier == 'beckon.keyboard.done' OR label == 'Done'"))
        if let done = candidates.allElementsBoundByIndex.first(where: {
            $0.isHittable && app.frame.contains($0.frame)
        }) {
            done.tap()
        } else if app.keyboards.firstMatch.exists {
            // The visible accessory sometimes has no XCTest identifier. Its
            // geometry follows BeckonKeyboardDoneAccessoryPolicy (52/20/12).
            let keyboard = app.keyboards.firstMatch.frame
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: app.frame.width - 46,
                dy: keyboard.minY - app.frame.minY - 38
            )).tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard must close before submitting")
    }

    private func fillOfferField(_ id: String, text: String) {
        let field = app.textFields[id].firstMatch
        let inputArea = app.frame.inset(by: UIEdgeInsets(top: 120, left: 0, bottom: 150, right: 0))
        for _ in 0..<10 {
            if field.exists && field.isHittable && inputArea.contains(field.frame) { break }
            if field.exists && field.frame.minY < inputArea.minY { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(field.exists && field.isHittable && inputArea.contains(field.frame),
            "Input must be clear of the navigation and submission bars: \(id)")
        field.tap()
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + text)
        finishInput()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, text)
    }

    func testPublishTwoRequests() throws {
        try start(.customer)
        for index in 1...2 {
            tap(element("customer.tab.home"))
            tap(element("customer.home.start-request"))
            tap(element("customer.requests.wizard.pet.dog"))
            tap(element("customer.requests.wizard.continue"))
            tap(element("customer.requests.wizard.service.full_groom"))
            tap(element("customer.requests.wizard.continue"))
            tap(element("customer.requests.use-profile-address"))
            let populated = NSPredicate(format: "value != '' AND value != 'Street Address'")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: populated,
                object: element("customer.requests.address.street"))], timeout: 15), .completed)
            tap(element("customer.requests.wizard.continue"))
            let confirmation = app.buttons["Use Suggested Address"].firstMatch
            if confirmation.waitForExistence(timeout: 20) { confirmation.tap() }
            tap(app.buttons["Afternoon"].firstMatch)
            if index == 2 {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
                let date = calendar.date(byAdding: .day, value: 2, to: Date())!
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = calendar.timeZone
                formatter.dateFormat = "EEE"
                let day = formatter.string(from: date)
                tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", day)).firstMatch)
            }
            tap(element("customer.requests.wizard.continue"))
            let notes = element("customer.requests.wizard.notes")
            tap(notes)
            notes.typeText("TESTOPS:\(runID) B65 UI-\(index)")
            finishInput()
            tap(element("customer.requests.wizard.continue"))
            tap(element("customer.requests.publish"))
            XCTAssertTrue(element("customer.requests.wizard").waitForNonExistence(timeout: 35))
        }
        app.terminate()
        app.launchArguments = ["--beckon-testops-run-id", runID, "--beckon-testops-disable-animations"]
        app.launch()
        tap(element("customer.tab.requests"))
        XCTAssertTrue(element("customer.requests.list").waitForExistence(timeout: 15))
    }

    func testQuoteTwoRequests() throws {
        XCTAssertEqual(references.count, 2)
        try start(.groomer)
        for reference in references {
            tap(element("groomer.tab.requests"))
            tap(element("groomer.requests.segment.matches"))
            tap(referenceRow(prefix: "groomer.requests.row", reference: reference))
            let withdraw = element("groomer.offers.withdraw")
            if withdraw.exists {
                tap(withdraw)
                XCTAssertTrue(withdraw.waitForNonExistence(timeout: 20))
            }
            fillOfferField("groomer.offers.price", text: "105")
            fillOfferField("groomer.offers.message", text: "TESTOPS:\(runID) B66 UI offer")
            tap(element("groomer.offers.submit"))
            XCTAssertTrue(element("groomer.offers.withdraw").waitForExistence(timeout: 35))
            tap(app.navigationBars.buttons.firstMatch)
        }
    }

    func testAcceptTwoRequests() throws {
        XCTAssertEqual(references.count, 2)
        try start(.customer)
        for reference in references {
            tap(element("customer.tab.requests"))
            tap(app.buttons.matching(NSPredicate(format:
                "(identifier == 'customer.requests.offers' OR label == 'Request Offers') AND value == %@", reference)).firstMatch)
            tap(element("customer.offers.row.\(runID)"))
            let accept = app.buttons.matching(NSPredicate(format:
                "identifier == 'customer.offers.accept' OR label == 'Review & Accept'")).firstMatch
            tap(accept)
            XCTAssertTrue(element("customer.offers.confirmation").waitForExistence(timeout: 15))
            tap(app.buttons.matching(NSPredicate(format:
                "identifier == 'customer.offers.confirm' OR label == 'Confirm & Book'")).firstMatch)
            XCTAssertTrue(element("customer.offers.confirmation").waitForNonExistence(timeout: 35))
            XCTAssertTrue(element("bookings.detail").waitForExistence(timeout: 20))
            for _ in 0..<3 { tap(app.navigationBars.buttons.firstMatch) }
            tap(element("customer.tab.bookings"))
            XCTAssertTrue(element("bookings.row.request.\(reference)").waitForExistence(timeout: 20))
        }
    }

    func testCancelOneRequest() throws {
        XCTAssertEqual(references.count, 2)
        try start(.customer)
        tap(element("customer.tab.bookings"))
        for reference in references {
            XCTAssertTrue(element("bookings.row.request.\(reference)").waitForExistence(timeout: 20),
                "A fresh customer session must show both confirmed bookings without scrolling")
        }
        print("T387 fresh customer list contains both UI bookings before cancellation")
        tap(element("bookings.row.request.\(references[0])"))
        tap(app.buttons.matching(NSPredicate(format:
            "identifier == 'booking.fulfillment.cancel' OR label == 'Cancel Booking'")).firstMatch)
        tap(element("booking.fulfillment.confirm"))
        XCTAssertTrue(element("booking.fulfillment.confirm").waitForNonExistence(timeout: 35))
        tap(app.navigationBars.buttons.firstMatch)
        XCTAssertTrue(element("bookings.row.request.\(references[0])").waitForNonExistence(timeout: 20))
        XCTAssertTrue(element("bookings.row.request.\(references[1])").waitForExistence(timeout: 20))
    }
}
