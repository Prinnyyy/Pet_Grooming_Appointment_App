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
        price.tap()
        let done = app.buttons["beckon.keyboard.done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let note = app.buttons["groomerVisit.quick.note"].firstMatch
        for _ in 0..<3 where !note.isHittable { app.swipeUp() }
        XCTAssertTrue(note.isHittable); note.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        note.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        // The accessory's blank area left of Done must also dismiss, without needing a scroll.
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: done.frame.midY)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        note.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["groomer.offers.submit"].firstMatch.isHittable)
        note.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 5)); XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }
}
