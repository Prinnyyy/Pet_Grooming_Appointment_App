import XCTest

/// Opt-in on the existing signed-in groomer simulator. Does not submit an offer.
final class GroomerOfferKeyboardSmokeTests: XCTestCase {
    @MainActor func testDoneOutsideTapAndBackgroundReturn() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["BECKON_OFFER_KEYBOARD_SMOKE"] == "1" || env["TEST_RUNNER_BECKON_OFFER_KEYBOARD_SMOKE"] == "1")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let tab = app.descendants(matching: .any)["groomer.tab.requests"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15)); tab.tap()
        app.buttons["groomer.requests.segment.matches"].tap()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Full groom' OR label CONTAINS[c] 'Bath'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 12)); card.tap()
        let price = app.textFields["Price estimate in dollars"].firstMatch
        for _ in 0..<7 where !price.isHittable { app.swipeUp() }
        XCTAssertTrue(price.isHittable)
        let submit = app.buttons["groomer.offers.submit"].firstMatch
        let normalFooterY = submit.frame.minY
        // Put the price away from the content's end stop, where keyboard reveal is needed.
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 8, dy: 350))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: 8, dy: 430)), withVelocity: .slow, thenHoldForDuration: 0.5)
        Thread.sleep(forTimeInterval: 1) // Only settle the setup swipe; not a production delay.
        XCTAssertLessThan(price.frame.maxY, submit.frame.minY)
        let initialPriceY = price.frame.minY
        for cycle in 0..<4 {
            price.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["beckon.keyboard.done"].exists)
            app.buttons["Done editing price"].tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            XCTAssertEqual(submit.frame.minY, normalFooterY, accuracy: 2)
            XCTAssertEqual(price.frame.minY, initialPriceY, accuracy: 2, "Price position drifted after edit cycle \(cycle)")
        }
        let note = app.buttons["groomerVisit.quick.note"].firstMatch
        for _ in 0..<3 where !note.isHittable || note.frame.maxY > submit.frame.minY { app.swipeUp() }
        XCTAssertTrue(note.isHittable); note.tap()
        let message = app.textViews["Message"].firstMatch
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let visible = NSPredicate { _, _ in
            message.exists && message.frame.maxY <= app.keyboards.firstMatch.frame.minY + 1
        }
        expectation(for: visible, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(message.isHittable)
        // Tap the page margin beside the input: no accessory-sized dead strip.
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 6, dy: message.frame.midY)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(submit.frame.minY, normalFooterY, accuracy: 2)
        note.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        // Interactive downward dismissal must recover the same dock position too.
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 8, dy: message.frame.minY))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: 8, dy: app.frame.maxY - 20)))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(submit.frame.minY, normalFooterY, accuracy: 2)
        for _ in 0..<3 where note.frame.maxY > submit.frame.minY { app.swipeUp() }
        note.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(submit.isHittable)
        XCTAssertEqual(submit.frame.minY, normalFooterY, accuracy: 2)
    }
}
