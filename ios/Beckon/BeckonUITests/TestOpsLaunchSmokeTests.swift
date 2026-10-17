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
    private nonisolated var runID: String { ProcessInfo.processInfo.environment["TESTOPS_RUN_ID"]
        ?? ProcessInfo.processInfo.environment["TEST_RUNNER_TESTOPS_RUN_ID"] ?? "" }
    private nonisolated var isMatchingRun: Bool {
        runID.hasPrefix("TESTOPS-T390-") || runID.hasPrefix("TESTOPS-T391-")
    }
    private var references: [String] { (ProcessInfo.processInfo.environment["TEST_RUNNER_T387_REQUEST_REFS"]
        ?? ProcessInfo.processInfo.environment["T387_REQUEST_REFS"] ?? "").split(separator: ",").map(String.init) }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard (runID.hasPrefix("TESTOPS-T387-") || isMatchingRun),
              (environment["TESTOPS_REMOTE_WRITE_APPROVED"]
                ?? environment["TEST_RUNNER_TESTOPS_REMOTE_WRITE_APPROVED"]) == "1" else {
            throw XCTSkip("Authorized scoped booking or matching runner required.")
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
            tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                "customer.requests.wizard.pet.dog.")).firstMatch)
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

    func testMatchingSortPreferenceAndPaging() throws {
        XCTAssertTrue(isMatchingRun)
        XCTAssertEqual(references.count, 4)
        try start(.groomer)
        tap(element("groomer.tab.requests"))

        func assertFirstReference(_ reference: String) {
            let first = app.buttons.matching(identifier: "groomer.requests.row.\(runID)").firstMatch
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true AND value == %@", reference),
                object: first)], timeout: 20), .completed)
        }

        func selectSort(_ title: String, reference: String) {
            tap(element("groomer.requests.sort"))
            tap(app.buttons[title].firstMatch)
            assertFirstReference(reference)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Matching sort: \(title)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        selectSort("Nearest", reference: references[0])
        selectSort("Newest", reference: references[1])
        selectSort("Relevant experience", reference: references[2])
        selectSort("Nearest", reference: references[0])
        app.terminate()
        app.launchArguments = ["--beckon-testops-run-id", runID, "--beckon-testops-disable-animations"]
        app.launch()
        tap(element("groomer.tab.requests"))
        assertFirstReference(references[0])
        selectSort("Relevant experience", reference: references[2])
        tap(element("groomer.requests.load-more"))
        XCTAssertTrue(referenceRow(prefix: "groomer.requests.row", reference: references[3]).waitForExistence(timeout: 20))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Matching second page"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testQuoteTwoRequests() throws {
        if isMatchingRun {
            XCTAssertTrue((1...2).contains(references.count))
        } else {
            XCTAssertEqual(references.count, 2)
        }
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
            if isMatchingRun {
                fillOfferField("groomer.offers.duration", text: "60")
                XCTAssertFalse(element("groomer.offers.submit").isEnabled)
                XCTAssertTrue(element("groomer.offers.confirmation.pet_size").exists)
                for key in ["pet_size", "pet_coat", "pet_matting"] {
                    let confirmation = element("groomer.offers.confirmation.\(key)")
                    if confirmation.exists {
                        let visibleArea = app.frame.inset(by: UIEdgeInsets(top: 140, left: 0, bottom: 180, right: 0))
                        for _ in 0..<10 {
                            if confirmation.isHittable && visibleArea.contains(confirmation.frame) { break }
                            let destinationY: CGFloat = confirmation.frame.minY < visibleArea.minY ? 0.6 : 0.4
                            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                                    withNormalizedOffset: CGVector(dx: 0.5, dy: destinationY)))
                        }
                        XCTAssertTrue(visibleArea.contains(confirmation.frame), "Confirmation must be clear of stationary bars: \(key)")
                        confirmation.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                        XCTAssertEqual(confirmation.value as? String, "1", key)
                    }
                }
                XCTAssertTrue(element("groomer.offers.submit").isEnabled)
            }
            tap(element("groomer.offers.submit"))
            XCTAssertTrue(element("groomer.offers.withdraw").waitForExistence(timeout: 35))
            tap(app.navigationBars.buttons.firstMatch)
        }
    }

    func testCustomerMatchingSortModes() throws {
        XCTAssertEqual(references.count, 1)
        let environment = ProcessInfo.processInfo.environment
        let expected = (environment["TEST_RUNNER_T390_SORT_PRICES"] ?? environment["T390_SORT_PRICES"] ?? "")
            .split(separator: ",").map(String.init)
        XCTAssertEqual(expected.count, 4)
        try start(.customer)
        tap(element("customer.tab.requests"))
        tap(app.buttons.matching(NSPredicate(format:
            "(identifier == 'customer.requests.offers' OR label == 'Request Offers') AND value == %@", references[0])).firstMatch)
        for (index, title) in ["Recommended", "Nearest", "Earliest appointment", "Lowest price"].enumerated() {
            tap(element("customer.offers.sort"))
            tap(app.buttons[title].firstMatch)
            let first = app.buttons.matching(identifier: "customer.offers.row.\(runID)").firstMatch
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true AND label CONTAINS %@", expected[index]),
                object: first)], timeout: 20), .completed)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Customer matching sort: \(title)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testMatchingDismissPersistsAfterRefresh() throws {
        XCTAssertEqual(references.count, 1)
        try start(.groomer)
        tap(element("groomer.tab.requests"))
        let row = referenceRow(prefix: "groomer.requests.row", reference: references[0])
        tap(row)
        tap(element("groomer.requests.dismiss"))
        tap(app.navigationBars.buttons.firstMatch)
        tap(app.buttons["Refresh"].firstMatch)
        XCTAssertTrue(row.waitForNonExistence(timeout: 20))
        app.terminate()
        app.launchArguments = ["--beckon-testops-run-id", runID, "--beckon-testops-disable-animations"]
        app.launch()
        tap(element("groomer.tab.requests"))
        XCTAssertFalse(row.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dismissal survives refresh and relaunch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMatchingLivePageChanges() async throws {
        let environment = ProcessInfo.processInfo.environment
        func setting(_ name: String) throws -> String {
            try XCTUnwrap(environment["TEST_RUNNER_" + name] ?? environment[name])
        }
        func mutate(_ operation: String) async throws {
            let route = operation == "REVIEW" ? "create_review_v2" : "create_groomer_offer_v3"
            var request = URLRequest(url: URL(string: "https://lqmasbuqzvcvtawonjlb.supabase.co/rest/v1/rpc/" + route)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(try setting("T390_API_KEY"), forHTTPHeaderField: "apikey")
            request.setValue("Bearer " + (try setting("T390_" + operation + "_TOKEN")), forHTTPHeaderField: "Authorization")
            request.httpBody = try setting("T390_" + operation + "_BODY").data(using: .utf8)
            let (_, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200, "Scoped role mutation must succeed")
        }
        try start(.groomer)
        tap(element("groomer.tab.requests"))
        tap(element("groomer.requests.sort"))
        tap(app.buttons["Relevant experience"].firstMatch)
        for operation in ["REVIEW", "QUOTE"] {
            let first = app.buttons.matching(identifier: "groomer.requests.row.\(runID)").firstMatch
            XCTAssertTrue(first.waitForExistence(timeout: 20))
            let originalReference = first.value as? String
            try await mutate(operation)
            tap(element("groomer.requests.load-more"))
            let changed = app.staticTexts["Matches changed. Refresh to continue."].firstMatch
            XCTAssertTrue(changed.waitForExistence(timeout: 20))
            XCTAssertEqual(first.value as? String, originalReference)
            XCTAssertFalse(element("groomer.requests.load-more").exists)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Live page invalidation: \(operation)"
            attachment.lifetime = .keepAlways
            add(attachment)
            tap(app.buttons["Refresh"].firstMatch)
            XCTAssertTrue(changed.waitForNonExistence(timeout: 20))
        }
    }

    func testMatchingOfferExpiresDuringConfirmation() throws {
        XCTAssertEqual(references.count, 1)
        try start(.customer)
        tap(element("customer.tab.requests"))
        tap(app.buttons.matching(NSPredicate(format:
            "(identifier == 'customer.requests.offers' OR label == 'Request Offers') AND value == %@", references[0])).firstMatch)
        tap(element("customer.offers.row.\(runID)"))
        tap(element("customer.offers.accept"))
        let confirm = app.buttons.matching(NSPredicate(format:
            "identifier == 'customer.offers.confirm' OR label == 'Confirm & Book' OR label == 'Offer Expired'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == false"), object: confirm)],
            timeout: 300), .completed)
        XCTAssertTrue(app.buttons["Offer Expired"].firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Offer naturally expired during confirmation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMatchingProposeTimeChange() throws {
        XCTAssertEqual(references.count, 1)
        try start(.customer)
        tap(element("customer.tab.bookings"))
        tap(element("bookings.row.request.\(references[0])"))
        tap(element("booking.reschedule.propose"))
        tap(element("booking.reschedule.confirm"))
        XCTAssertTrue(element("booking.reschedule.confirm").waitForNonExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Proposed by Customer"].firstMatch.waitForExistence(timeout: 20))
    }

    func testMatchingNetworkRefreshRecovery() throws {
        XCTAssertEqual(references.count, 1)
        let driver = TestOpsUIFlowDriver()
        driver.launchSignedOut(additionalArguments: ["--beckon-testops-fail-matching-refresh-once"])
        driver.signIn(try TestOpsSeedAccount.fromEnvironment(role: .groomer))
        tap(element("groomer.tab.requests"))
        let row = referenceRow(prefix: "groomer.requests.row", reference: references[0])
        XCTAssertTrue(row.waitForExistence(timeout: 25))
        let error = app.staticTexts["Check your connection and try again."].firstMatch
        if !error.exists { tap(app.buttons["Refresh"].firstMatch) }
        XCTAssertTrue(error.waitForExistence(timeout: 20))
        XCTAssertTrue(row.exists, "Failed refresh must retain the loaded candidate")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Retained candidate during injected network failure"
        attachment.lifetime = .keepAlways
        add(attachment)
        tap(app.buttons["Refresh"].firstMatch)
        XCTAssertTrue(error.waitForNonExistence(timeout: 20))
        XCTAssertTrue(row.exists)
        tap(row)
        XCTAssertTrue(app.staticTexts["Evidence unavailable"].firstMatch.waitForExistence(timeout: 15))
        fillOfferField("groomer.offers.price", text: "110")
        fillOfferField("groomer.offers.duration", text: "60")
        fillOfferField("groomer.offers.message", text: "TESTOPS:\(runID) fallback quote")
        tap(element("groomer.offers.submit"))
        XCTAssertTrue(element("groomer.offers.withdraw").waitForExistence(timeout: 30))
    }

    func testMatchingAcceptTimeChange() throws {
        XCTAssertEqual(references.count, 1)
        try start(.groomer)
        tap(element("groomer.tab.bookings"))
        tap(element("groomer.booking.row.request.\(references[0])"))
        tap(element("booking.reschedule.accept"))
        tap(element("booking.reschedule.confirm"))
        XCTAssertTrue(element("booking.reschedule.confirm").waitForNonExistence(timeout: 30))
        XCTAssertTrue(element("booking.reschedule.accept").waitForNonExistence(timeout: 20))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Accepted time change"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMatchingLiveStartAndComplete() throws {
        XCTAssertEqual(references.count, 1)
        try start(.groomer)
        tap(element("groomer.tab.bookings"))
        tap(element("groomer.booking.row.request.\(references[0])"))
        let startButton = element("booking.fulfillment.start")
        XCTAssertTrue(startButton.waitForExistence(timeout: 600), "The real scheduled start must arrive")
        tap(startButton)
        tap(element("booking.fulfillment.confirm"))
        XCTAssertTrue(element("booking.fulfillment.confirm").waitForNonExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["In Service"].firstMatch.waitForExistence(timeout: 20))
        let complete = element("booking.fulfillment.complete")
        XCTAssertTrue(complete.waitForExistence(timeout: 90), "Completion requires one real minute of service")
        tap(complete)
        tap(element("booking.fulfillment.confirm"))
        XCTAssertTrue(element("booking.fulfillment.confirm").waitForNonExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Completed"].firstMatch.waitForExistence(timeout: 20))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Real-time completed service"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMatchingSubmitVerifiedReview() throws {
        XCTAssertEqual(references.count, 1)
        try start(.customer)
        tap(element("customer.tab.bookings"))
        tap(element("bookings.scope.past"))
        tap(element("bookings.row.request.\(references[0])"))
        let content = element("bookings.review.content")
        tap(content)
        content.typeText("TESTOPS:\(runID) verified live service")
        finishInput()
        let fit = app.segmentedControls.matching(NSPredicate(format:
            "identifier BEGINSWITH 'bookings.review.fit.'")).firstMatch
        XCTAssertTrue(fit.waitForExistence(timeout: 20))
        XCTAssertTrue(element("bookings.review.fit.size:S").exists, "Review uses the confirmed service's original size")
        XCTAssertFalse(element("bookings.review.fit.size:Giant").exists, "Later pet edits must not change the review context")
        tap(fit.buttons.element(boundBy: 2))
        tap(element("bookings.review.submit"))
        XCTAssertTrue(element("bookings.review.display").waitForExistence(timeout: 30))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Verified service review"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testConfirmMatchingServiceSpecies() throws {
        guard isMatchingRun else { throw XCTSkip("Matching fixture only") }
        try start(.groomer)
        tap(element("groomer.tab.account"))
        tap(element("groomer.account.services"))
        tap(app.buttons["Actions for Matching test Full Groom"].firstMatch)
        tap(app.buttons["Edit"].firstMatch)
        let dog = element("groomer.services.species.dog")
        XCTAssertTrue(dog.waitForExistence(timeout: 10))
        XCTAssertEqual(dog.value as? String, "0")
        tap(dog)
        if dog.value as? String == "0" {
            dog.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertEqual(dog.value as? String, "1")
        let visible = app.switches["Visible to customers"].firstMatch
        tap(visible)
        if visible.value as? String == "0" {
            visible.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertEqual(visible.value as? String, "1")
        tap(element("groomer.services.save"))
        XCTAssertTrue(element("groomer.services.form").waitForNonExistence(timeout: 30))
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
            XCTAssertTrue(element("bookings.row.request.\(reference)").waitForExistence(timeout: 3),
                "A committed booking must reach the loaded list without a refresh or relaunch")
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

    func testOpenMessageNotification() throws {
        let environment = ProcessInfo.processInfo.environment
        let rawRole = environment["TEST_RUNNER_TESTOPS_INTERACTIVE_ROLE"] ?? environment["TESTOPS_INTERACTIVE_ROLE"] ?? ""
        let role = try XCTUnwrap(TestOpsSeedRole(rawValue: rawRole))
        let message = try XCTUnwrap(environment["TEST_RUNNER_T388_CHAT_MESSAGE"] ?? environment["T388_CHAT_MESSAGE"])
        XCTAssertTrue(message.hasPrefix("TESTOPS:\(runID) E17 "))
        try start(role)
        tap(element("\(rawRole).tab.home"))
        tap(element("\(rawRole).home.notifications"))
        let notice = app.buttons.matching(identifier: "\(rawRole).notifications.open")
            .matching(NSPredicate(format: "label CONTAINS %@", "New message")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 15))
        tap(notice)
        XCTAssertTrue(element("chat.thread").waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", message))
            .firstMatch.waitForExistence(timeout: 15),
            "The notification must open the conversation containing the exact newly sent message")
    }
}
