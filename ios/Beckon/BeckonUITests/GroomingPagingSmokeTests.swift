import XCTest

/// Opt-in, read-only interaction check using an already signed-in Groomer simulator.
final class GroomingPagingSmokeTests: XCTestCase {
    @MainActor func testTabsAndSwipesShareSelection() throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["BECKON_PAGING_SMOKE"] == "1" || env["TEST_RUNNER_BECKON_PAGING_SMOKE"] == "1")
        let app = XCUIApplication()
        app.launch()
        let grooming = app.descendants(matching: .any)["groomer.tab.requests"].firstMatch
        XCTAssertTrue(grooming.waitForExistence(timeout: 15))
        grooming.tap()
        func selected(_ title: String) {
            let button = app.buttons[title].firstMatch
            XCTAssertTrue(NSPredicate(format: "selected == true").evaluate(with: button)
                || XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: button)], timeout: 5) == .completed)
        }
        func swipe(_ left: Bool) {
            let page = app.descendants(matching: .any)["groomer.grooming.pages"].firstMatch
            XCTAssertTrue(page.waitForExistence(timeout: 5))
            let start = page.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.8 : 0.2, dy: 0.5))
            let end = page.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.2 : 0.8, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        for (section, first, second) in [("matches", "All", "Studio"), ("offers", "Waiting", "Accepted"), ("bookings", "Active", "Closed")] {
            app.buttons["groomer.requests.segment." + section].tap()
            selected(first)
            app.buttons[second].firstMatch.tap()
            selected(second)
            swipe(false)
            selected(first)
            swipe(true)
            selected(second)
        }
    }
}
