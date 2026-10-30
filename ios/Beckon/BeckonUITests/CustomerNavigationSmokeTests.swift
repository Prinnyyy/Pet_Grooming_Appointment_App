import XCTest

@MainActor
final class CustomerNavigationSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--beckon-ui-test-customer-navigation"]
        app.launch()
        XCTAssertTrue(app.buttons["customer.home.start-request"].waitForExistence(timeout: 10))
        return app
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, scrolling: Bool = false) {
        if scrolling {
            for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 8))
        XCTAssertTrue(element.isEnabled)
        element.tap()
    }

    private func tab(_ title: String, in app: XCUIApplication) -> XCUIElement { app.tabBars.buttons[title] }
    private func screen(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testHomeGlanceSelectsGroomingCard() {
        let app = launch()
        let card = app.scrollViews["customer.home.next-up.carousel"].buttons.firstMatch
        tap(card, in: app, scrolling: true)
        XCTAssertTrue(tab("Grooming", in: app).isSelected)
        XCTAssertTrue(screen("customer.grooming.list", in: app).exists)
        XCTAssertFalse(screen("customer.requests.detail", in: app).exists)
        XCTAssertFalse(screen("bookings.detail", in: app).exists)
    }

    func testNotificationAndMessageUseOwningTabsAndClearHome() {
        let app = launch()
        tap(app.buttons["customer.home.notifications"], in: app)
        let confirmed = app.buttons.matching(NSPredicate(format: "identifier == 'customer.notifications.open' AND label CONTAINS 'appointment is confirmed'")).firstMatch
        tap(confirmed, in: app, scrolling: true)
        XCTAssertTrue(screen("bookings.detail", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(tab("Grooming", in: app).isSelected)
        tap(app.buttons["bookings.detail.open-chat"], in: app, scrolling: true)
        XCTAssertTrue(screen("chat.thread", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(tab("Messages", in: app).isSelected)
        tap(tab("Home", in: app), in: app)
        XCTAssertTrue(app.buttons["customer.home.start-request"].exists)
        XCTAssertFalse(screen("customer.notifications", in: app).exists)
        tap(tab("Grooming", in: app), in: app)
        XCTAssertTrue(screen("customer.grooming.list", in: app).exists)
        XCTAssertFalse(screen("bookings.detail", in: app).exists)
    }

    func testWizardPetRoundTripAndPublicationSelectNewCard() {
        let app = launch()
        tap(app.buttons["customer.home.start-request"], in: app)
        tap(app.buttons["customer.requests.wizard.add-pet"], in: app, scrolling: true)
        tap(app.buttons["Cancel"], in: app)
        XCTAssertTrue(app.buttons["customer.requests.wizard.add-pet"].waitForExistence(timeout: 8))
        tap(app.buttons["customer.requests.wizard.add-pet"], in: app, scrolling: true)
        let name = app.textFields["Pet name"]
        tap(name, in: app)
        name.typeText("T423 Pip")
        tap(app.buttons["beckon.keyboard.done"], in: app)
        tap(app.buttons["customer.pets.form-save"], in: app, scrolling: true)
        XCTAssertTrue(app.buttons["customer.requests.wizard.continue"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["T423 Pip"].exists)
        for _ in 0..<4 { tap(app.buttons["customer.requests.wizard.continue"], in: app) }
        tap(app.buttons["customer.requests.publish"], in: app)
        let candidate = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.select.'")).firstMatch
        tap(candidate, in: app, scrolling: true)
        tap(app.buttons["discovery.send"], in: app)
        tap(app.buttons["discovery.confirm-send"], in: app)
        XCTAssertTrue(screen("customer.grooming.list", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(tab("Grooming", in: app).isSelected)
        XCTAssertFalse(screen("customer.requests.wizard", in: app).exists)
        let selected = app.scrollViews["customer.grooming.carousel"].buttons
            .matching(NSPredicate(format: "label CONTAINS 'T423 Pip'")).firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 8))
        XCTAssertTrue(selected.isHittable, "The request for the newly selected pet should be the visible card")
    }
}
