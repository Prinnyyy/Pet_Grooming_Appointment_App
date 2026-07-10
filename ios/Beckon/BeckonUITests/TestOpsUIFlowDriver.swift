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

struct TestOpsLifecycleContext {
    let runID: String

    static func fromEnvironment() throws -> Self {
        let environment = ProcessInfo.processInfo.environment
        guard environment.testOpsValue(for: "TESTOPS_UI_LIFECYCLE_APPROVED") == "1" else {
            throw XCTSkip(
                "Set TESTOPS_UI_LIFECYCLE_APPROVED=1 through the authorized lifecycle wrapper."
            )
        }
        guard let runID = environment.testOpsValue(for: "TESTOPS_RUN_ID"),
              runID.range(
                of: "^TESTOPS-[A-Z0-9-]{1,96}$",
                options: .regularExpression
              ) != nil else {
            throw XCTSkip("Set a safe TESTOPS_RUN_ID for the UI lifecycle run.")
        }
        return Self(runID: runID)
    }

    var requestNotes: String {
        "TESTOPS:\(runID) UI lifecycle request."
    }

    var offerMessage: String {
        "TESTOPS:\(runID) UI lifecycle offer."
    }

    var chatMessage: String {
        "TESTOPS:\(runID) UI lifecycle chat."
    }

    var reviewContent: String {
        "TESTOPS:\(runID) UI lifecycle review."
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
            "--beckon-testops-run-id",
            environment["TESTOPS_RUN_ID"] ?? "TESTOPS-UITEST-0001",
            "--beckon-testops-scenario",
            environment["TESTOPS_SCENARIO_ID"] ?? "marketplace_full_lifecycle",
            "--beckon-testops-clear-session",
            "--beckon-testops-disable-animations",
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
        assertTab("groomer.tab.home", destination: "groomer.home")
        assertTab("groomer.tab.requests", destination: "groomer.requests.list")
        XCTAssertTrue(element("groomer.requests.segment.matches").exists)
        XCTAssertTrue(element("groomer.requests.segment.offers").exists)
        assertTab("groomer.tab.bookings", destination: "groomer.schedule")
        assertTab("groomer.tab.messages", destination: "chat.conversations.list")
        assertTab("groomer.tab.account", destination: "groomer.account.home")
        XCTAssertTrue(
            app.buttons["groomer.account.edit-profile"].waitForExistence(timeout: 5),
            "Expected Groomer Account to expose the Edit Profile entry."
        )
        assertTab("groomer.tab.home", destination: "groomer.home")
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

    func publishTaggedRequest(_ context: TestOpsLifecycleContext) -> String {
        let startRequest = app.buttons["customer.home.start-request"]
        XCTAssertTrue(startRequest.waitForExistence(timeout: 12))
        startRequest.tap()

        XCTAssertTrue(element("customer.requests.wizard").waitForExistence(timeout: 8))
        tap(element("customer.requests.wizard.pet.dog"))
        tap(element("customer.requests.wizard.continue"))

        tap(element("customer.requests.wizard.service.full_groom"))
        tap(element("customer.requests.wizard.continue"))

        let useProfileAddress = element("customer.requests.use-profile-address")
        XCTAssertTrue(useProfileAddress.waitForExistence(timeout: 8))
        useProfileAddress.tap()
        let streetField = element("customer.requests.address.street")
        XCTAssertTrue(streetField.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForPopulatedValue(streetField, timeout: 15))
        tap(element("customer.requests.wizard.continue"))

        let notesField = element("customer.requests.wizard.notes")
        XCTAssertTrue(notesField.waitForExistence(timeout: 8))
        notesField.tap()
        notesField.typeText(context.requestNotes)
        dismissKeyboard()
        tap(element("customer.requests.wizard.continue"))

        let publishButton = element("customer.requests.publish")
        XCTAssertTrue(publishButton.waitForExistence(timeout: 8))
        tap(publishButton)
        XCTAssertTrue(element("customer.requests.wizard").waitForNonExistence(timeout: 30))

        tap(element("customer.tab.requests"))
        XCTAssertTrue(element("customer.requests.list").waitForExistence(timeout: 15))
        let requestDetail = element("customer.requests.row.\(context.runID)")
        XCTAssertTrue(
            requestDetail.waitForExistence(timeout: 20),
            "Available request selectors: \(identifiers(withPrefix: "customer.requests"))"
        )
        return supportReference(from: requestDetail)
    }

    func submitTaggedOffer(
        _ context: TestOpsLifecycleContext,
        expectedRequestReference: String
    ) {
        tap(element("groomer.tab.requests"))
        XCTAssertTrue(element("groomer.requests.list").waitForExistence(timeout: 15))
        tap(element("groomer.requests.segment.matches"))
        let requestRow = button("groomer.requests.row.\(context.runID)")
        XCTAssertTrue(requestRow.waitForExistence(timeout: 20))
        XCTAssertEqual(supportReference(from: requestRow), expectedRequestReference)
        tap(requestRow)
        XCTAssertTrue(element("groomer.requests.detail").waitForExistence(timeout: 10))

        let priceField = element("groomer.offers.price")
        scrollToHittable(priceField)
        priceField.tap()
        priceField.typeText("105")

        let messageField = element("groomer.offers.message")
        scrollToHittable(messageField)
        messageField.tap()
        messageField.typeText(context.offerMessage)
        dismissKeyboard()

        let submit = button("groomer.offers.submit")
        scrollToHittable(submit)
        submit.tap()
        XCTAssertTrue(element("groomer.offers.withdraw").waitForExistence(timeout: 30))
    }

    func acceptOfferAndSendChat(
        _ context: TestOpsLifecycleContext,
        requestReference: String
    ) {
        tap(element("customer.tab.requests"))
        XCTAssertTrue(element("customer.requests.list").waitForExistence(timeout: 15))

        let detail = app.buttons
            .matching(identifier: "customer.requests.row.\(context.runID)")
            .matching(NSPredicate(format: "label == 'Request Detail'"))
            .firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 20))
        tap(detail)
        XCTAssertTrue(element("customer.requests.detail").waitForExistence(timeout: 10))

        let offerRow = button("customer.offers.row.\(context.runID)")
        scrollToHittable(offerRow, maximumSwipes: 10)
        offerRow.tap()
        XCTAssertTrue(element("customer.offers.detail").waitForExistence(timeout: 10))

        let accept = button("customer.offers.accept")
        scrollToHittable(accept)
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 30))

        tap(element("customer.tab.bookings"))
        XCTAssertTrue(element("bookings.list").waitForExistence(timeout: 15))
        let bookingRow = button("bookings.row.request.\(requestReference)")
        XCTAssertTrue(bookingRow.waitForExistence(timeout: 20))
        tap(bookingRow)
        XCTAssertTrue(element("bookings.detail").waitForExistence(timeout: 10))
        XCTAssertTrue(
            button("customer.booking.cancel.request.\(requestReference)")
                .waitForExistence(timeout: 5)
        )

        let openChat = button("bookings.detail.open-chat")
        scrollToHittable(openChat)
        openChat.tap()
        XCTAssertTrue(element("chat.thread").waitForExistence(timeout: 15))
        sendChatMessage(context.chatMessage)
    }

    func verifyChatAndCompleteBooking(
        _ context: TestOpsLifecycleContext,
        requestReference: String
    ) {
        tap(element("groomer.tab.messages"))
        XCTAssertTrue(element("chat.conversations.list").waitForExistence(timeout: 15))
        let conversation = button("chat.conversation.request.\(requestReference)")
        XCTAssertTrue(conversation.waitForExistence(timeout: 20))
        tap(conversation)
        XCTAssertTrue(element("chat.thread").waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts[context.chatMessage].waitForExistence(timeout: 20))

        let back = app.buttons["Back"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()

        tap(element("groomer.tab.bookings"))
        XCTAssertTrue(element("groomer.schedule").waitForExistence(timeout: 15))
        let complete = button(
            "groomer.booking.complete.request.\(requestReference)"
        )
        scrollToHittable(complete, maximumSwipes: 10)
        complete.tap()
        XCTAssertTrue(complete.waitForNonExistence(timeout: 30))
    }

    func submitTaggedReview(
        _ context: TestOpsLifecycleContext,
        requestReference: String
    ) {
        tap(element("customer.tab.bookings"))
        XCTAssertTrue(element("bookings.list").waitForExistence(timeout: 15))
        tap(button("bookings.scope.past"))

        let bookingRow = button("bookings.row.request.\(requestReference)")
        XCTAssertTrue(bookingRow.waitForExistence(timeout: 20))
        tap(bookingRow)
        XCTAssertTrue(element("bookings.detail").waitForExistence(timeout: 10))

        let content = element("bookings.review.content")
        scrollToHittable(content, maximumSwipes: 10)
        content.tap()
        content.typeText(context.reviewContent)
        dismissKeyboard()

        let submit = button("bookings.review.submit")
        scrollToHittable(submit)
        submit.tap()
        XCTAssertTrue(element("bookings.review.display").waitForExistence(timeout: 30))
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

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func button(_ identifier: String) -> XCUIElement {
        app.buttons[identifier].firstMatch
    }

    private func tap(_ target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        if !target.isHittable {
            scrollToHittable(target)
        }
        XCTAssertTrue(target.isHittable)
        target.tap()
    }

    private func scrollToHittable(
        _ target: XCUIElement,
        maximumSwipes: Int = 10
    ) {
        var swipes = 0
        while (!target.exists || !target.isHittable), swipes < maximumSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(target.exists, "Expected element to exist after scrolling.")
        XCTAssertTrue(target.isHittable, "Element was not hittable after scrolling.")
    }

    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }
        app.swipeDown()
        if app.keyboards.firstMatch.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.2)).tap()
        }
    }

    private func waitForPopulatedValue(
        _ field: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement,
                  let value = element.value as? String else {
                return false
            }
            return !value.isEmpty && value != "Street Address"
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: field)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func supportReference(from element: XCUIElement) -> String {
        guard let value = element.value as? String,
              value.range(of: "^[A-F0-9]{8}$", options: .regularExpression) != nil else {
            XCTFail("Expected an 8-character request support reference.")
            return ""
        }
        return value
    }

    private func sendChatMessage(_ message: String) {
        let body = element("chat.message.body")
        XCTAssertTrue(body.waitForExistence(timeout: 12))
        body.tap()
        body.typeText(message)
        let send = element("chat.message.send")
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.tap()
        XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 20))
    }

    private func identifiers(withPrefix prefix: String) -> [String] {
        Array(
            Set(
                app.descendants(matching: .any).allElementsBoundByIndex
                    .map(\.identifier)
                    .filter { $0.hasPrefix(prefix) }
            )
        ).sorted()
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
