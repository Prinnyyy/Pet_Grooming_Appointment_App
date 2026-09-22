import XCTest

@MainActor
final class TestOpsMarketplaceAcceptanceTests: XCTestCase {
    private let app = XCUIApplication()
    private nonisolated var environment: [String: String] { ProcessInfo.processInfo.environment }

    private nonisolated func value(_ key: String) -> String? {
        environment["TEST_RUNNER_\(key)"] ?? environment[key]
    }

    private struct Publication: Decodable {
        let id: String
        let petName: String
        let petWeight: Double?
        let species: String
        let serviceType: String
        let locationMode: String
        let travelRadiusMiles: Int?
        let window: [String]
        let notes: String
    }

    private struct Quote: Decodable {
        let id: String
        let reference: String
        let start: String
        let durationMinutes: Int
        let price: String
        let message: String
        let confirmations: [String]
        let expectedError: String?
    }

    private struct Readback: Decodable {
        struct SortCheck: Decodable {
            let title: String
            let groups: [[String]]
        }
        struct Offer: Decodable {
            let id: String
            let groomerName: String
            let price: String
            let start: String
            let end: String
            let confirmationAddress: String
            let message: String
            let ratingCount: Int
            let ratingSum: Int
            let evidenceSummary: String
            let evidenceLines: [String]
        }
        let id: String
        let reference: String
        let petName: String
        let species: String
        let serviceType: String
        let locationMode: String
        let window: [String]
        let travelRadiusMiles: Int?
        let notes: String
        let streetAddress: String
        let quotes: [Offer]?
        let sortChecks: [SortCheck]?
        let notificationCreatedAt: String?
        let city: String?
    }

    private struct Acceptance: Decodable {
        let id: String
        let reference: String
        let groomerName: String
    }

    private struct RequestClosure: Decodable {
        let id: String
        let reference: String
    }

    private struct RankingBrowse: Decodable {
        struct Order: Decodable {
            let title: String
            let groups: [[String]]
            let select: Bool?
        }
        let id: String
        let reference: String?
        let orders: [Order]
        let backgroundAndRestart: Bool?
        let signOutAfter: Bool?
    }

    private struct Withdrawal: Decodable {
        let id: String
        let reference: String
        let petName: String
        let price: String
        let message: String
        let timeText: String?
    }

    private struct ScheduledBooking: Decodable {
        let id: String
        let reference: String
        let petName: String
        let serviceTitle: String
        let price: String
        let start: String
        let end: String
    }

    private struct BookingAction: Decodable {
        let id: String
        let reference: String
        let start: String
        let petName: String
        let kind: String
        let action: String?
        let expectedText: String
        let scope: String?
        let sameDetail: Bool?
        let expectedReviewForm: Bool?
        let waitForActionSeconds: Double?
        let proposedStart: String?
        let reviewContent: String?
        let reviewRating: Int?
        let reviewAnswers: [String: String]?
        let expectedReviewKeys: [String]?
        let reviewShouldSave: Bool?
        let backgroundAndRestart: Bool?
    }

    private struct PetUpdate: Decodable {
        let id: String
        let petName: String
        let originalWeight: String
        let newWeight: String
    }

    private struct ReviewFault: Decodable {
        let bookingID: String
        let phase: String
    }

    private struct PublicationFault: Decodable {
        let customerID: String
        let petID: String
        let marker: String
        let phase: String
        let retryAfterFailure: Bool
        let reopenAfterFailure: Bool?
        let restartAfterFailure: Bool?
    }

    private struct SessionSwitch: Decodable {
        let id: String
        let customerName: String
        let groomerName: String
    }

    private struct Input<Row: Decodable>: Decodable {
        let runID: String
        let actor: String
        let role: String
        let previewOnly: Bool
        let rows: [Row]
        let forbiddenReferences: [String]?
        let matchedReferences: [String]?
        let routeViaOffers: Bool?
        let reviewFault: ReviewFault?
        let publicationFault: PublicationFault?
        let publicationDoubleTap: Bool?
        let publicationSourceReference: String?
        let switchActor: String?
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard value("TESTOPS_REMOTE_WRITE_APPROVED") == "1", value("T392_UI_INPUT") != nil else {
            throw XCTSkip("Authorized data-driven acceptance input required.")
        }
    }

    nonisolated override func record(_ issue: XCTIssue) {
        // Xcode's in-process symbolicator stalls on this Simulator runtime.
        // Keep the failure, source location and attachments without resolving frames.
        var recorded = issue
        recorded.sourceCodeContext = XCTSourceCodeContext(callStack: [], location: issue.sourceCodeContext.location)
        super.record(recorded)
    }

    private func input<Row: Decodable>(_ row: Row.Type, role: TestOpsSeedRole) throws -> Input<Row> {
        guard value("TESTOPS_REMOTE_WRITE_APPROVED") == "1",
              let encoded = value("T392_UI_INPUT"), let data = Data(base64Encoded: encoded) else {
            throw XCTSkip("Authorized data-driven acceptance input required.")
        }
        let result = try JSONDecoder().decode(Input<Row>.self, from: data)
        XCTAssertEqual(result.runID, value("TESTOPS_RUN_ID"))
        XCTAssertTrue(result.runID.hasPrefix("TESTOPS-T392-"))
        XCTAssertEqual(result.role, role.rawValue)
        XCTAssertEqual(result.actor, value("TESTOPS_ACTOR_ALIAS"))
        XCTAssertFalse(result.rows.isEmpty)
        if let reference = result.publicationSourceReference {
            XCTAssertEqual(role, .customer)
            XCTAssertEqual(result.rows.count, 1)
            XCTAssertNotNil(reference.range(of: "^[A-F0-9]{8}$", options: .regularExpression))
        }
        let driver = TestOpsUIFlowDriver()
        var arguments: [String] = []
        if let fault = result.reviewFault {
            XCTAssertEqual(role, .customer)
            XCTAssertNotNil(UUID(uuidString: fault.bookingID))
            XCTAssertTrue(["beforeSubmit", "afterCommit"].contains(fault.phase))
            arguments = ["--beckon-testops-review-booking", fault.bookingID,
                         "--beckon-testops-review-fault", fault.phase]
        }
        if let fault = result.publicationFault {
            XCTAssertEqual(role, .customer)
            XCTAssertEqual(result.rows.count, 1)
            XCTAssertNotNil(UUID(uuidString: fault.customerID))
            XCTAssertNotNil(UUID(uuidString: fault.petID))
            XCTAssertTrue(["beforeSubmit", "afterCommit"].contains(fault.phase))
            XCTAssertNotNil(fault.marker.range(of: "^[A-Z0-9-]{1,60}$", options: .regularExpression))
            arguments += ["--beckon-testops-publish-customer", fault.customerID,
                          "--beckon-testops-publish-pet", fault.petID,
                          "--beckon-testops-publish-marker", fault.marker,
                          "--beckon-testops-publish-fault", fault.phase]
        }
        driver.launchSignedOut(additionalArguments: arguments)
        driver.signIn(try TestOpsSeedAccount.fromEnvironment(role: role), signedOutTimeout: 30)
        return result
    }

    private func element(_ id: String) -> XCUIElement {
        let button = app.buttons[id].firstMatch
        return button.exists ? button : app.descendants(matching: .any)[id].firstMatch
    }

    private func reveal(_ item: XCUIElement, requiresHitTarget: Bool = true, maximumScrolls: Int = 8) {
        let bounds = app.frame
        let navigation = app.navigationBars.allElementsBoundByIndex.last(where: { $0.isHittable })
            ?? app.navigationBars.firstMatch
        let tabs = app.tabBars.firstMatch
        let top = navigation.exists ? max(bounds.minY, navigation.frame.maxY) + 8 : bounds.minY + 8
        // A presented sheet covers the tab bar; its controls may use that screen area.
        var bottom = tabs.exists && tabs.isHittable ? min(bounds.maxY, tabs.frame.minY) - 8 : bounds.maxY - 8
        let footerIDs = ["customer.requests.wizard.continue", "customer.requests.publish", "customer.requests.wizard.back"]
        if !footerIDs.contains(item.identifier) {
            for id in footerIDs {
                let footer = app.buttons[id].firstMatch
                if footer.exists && footer.isHittable { bottom = min(bottom, footer.frame.minY - 8) }
            }
        }
        let usable = CGRect(x: bounds.minX, y: top, width: bounds.width, height: bottom - top)
        for _ in 0..<maximumScrolls {
            let frame = item.exists ? item.frame : .zero
            if !frame.isEmpty && usable.contains(frame)
                && (!requiresHitTarget || item.isHittable) { return }
            // Whole-screen swipes can oscillate past a compact field. Scroll
            // toward its AX frame in bounded steps, without using image matching.
            let horizontal = !frame.isEmpty && (frame.midX < usable.minX || frame.midX > usable.maxX)
            let delta = horizontal ? usable.midX - frame.midX
                : frame.isEmpty ? -220 : usable.midY - frame.midY
            let offset = frame.isEmpty ? -min(500, usable.height - 80) : max(-220, min(220, delta))
            let origin = CGPoint(x: usable.midX, y: horizontal
                ? max(usable.minY + 30, min(usable.maxY - 30, frame.midY))
                : frame.isEmpty ? usable.maxY - 40 : usable.midY)
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: origin.x - app.frame.minX, dy: origin.y - app.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(
                dx: horizontal ? offset : 0, dy: horizontal ? 0 : offset)))
        }
        let reachable = item.exists && usable.contains(item.frame) && (!requiresHitTarget || item.isHittable)
        if !reachable {
            evidence("unreachable control", screenshot: true)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Unreachable control hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(reachable, "Requested control is missing or unreachable")
    }

    private func tap(_ item: XCUIElement) {
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Requested control did not appear")
        if !app.frame.intersects(item.frame) || !item.isHittable { reveal(item) }
        XCTAssertTrue(item.isHittable, "Unreachable control: \(item.identifier)")
        item.tap()
    }

    private func finishInput() {
        let done = app.buttons["beckon.keyboard.done"].firstMatch
        let labeledDone = app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch
        if done.exists && done.isHittable { done.tap() }
        else if labeledDone.exists && labeledDone.isHittable { labeledDone.tap() }
        else if app.keyboards.firstMatch.exists {
            let keyboard = app.keyboards.firstMatch.frame
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: app.frame.width - 46, dy: keyboard.minY - app.frame.minY - 38
            )).tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 8))
    }

    private func fill(_ item: XCUIElement, with text: String) {
        reveal(item)
        item.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            evidence("input focus retry \(item.identifier)")
            item.tap()
        }
        let hasKeyboard = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        if !hasKeyboard {
            let hierarchy = XCTAttachment(string: "Target: \(item.debugDescription)\n\(app.debugDescription)")
            hierarchy.name = "Input focus failure hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(hasKeyboard,
            "Input tap did not focus \(item.identifier)")
        let old = item.value as? String ?? ""
        if !old.isEmpty {
            item.typeKey("a", modifierFlags: .command)
            item.typeText(text)
        } else {
            item.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count + 1) + text)
        }
        finishInput()
        XCTAssertEqual(item.value as? String, text)
    }

    private func localDate(_ stamp: String) throws -> Date {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return try XCTUnwrap(parser.date(from: stamp), "Frozen ISO timestamp required")
    }

    private func formatter(_ format: String) -> DateFormatter {
        let result = DateFormatter()
        result.locale = Locale(identifier: "en_US_POSIX")
        result.timeZone = TimeZone(identifier: "America/Los_Angeles")
        result.dateFormat = format
        return result
    }

    private func selectDay(_ date: Date, field: XCUIElement, dismissLabel: String) {
        if !field.exists { reveal(field, requiresHitTarget: false) }
        let combined = field.buttons["Date and Time Picker"].firstMatch
        let isCombined = combined.exists
        let control = isCombined ? combined : field.buttons["Date Picker"].firstMatch
        reveal(control)
        let dismissFrame = app.staticTexts[dismissLabel].firstMatch.frame
        let dismiss = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: dismissFrame.midX - app.frame.minX, dy: dismissFrame.midY - app.frame.minY))
        if isCombined {
            combined.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        } else {
            tap(control)
        }
        XCTAssertTrue(app.buttons["DatePicker.NextMonth"].firstMatch.waitForExistence(timeout: 5),
            "Date control did not open the calendar")
        let label = formatter("EEEE, MMMM d").string(from: date)
        let day = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", label, "Today, \(label)")).firstMatch
        for _ in 0..<3 {
            if day.exists { break }
            tap(app.buttons["DatePicker.NextMonth"].firstMatch)
        }
        tap(day)
        if isCombined {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        } else { dismiss.tap() }
        XCTAssertTrue(app.buttons["DatePicker.NextMonth"].firstMatch.waitForNonExistence(timeout: 5))
        print("T392 UI selected day \(label)")
    }

    private func selectTime(_ date: Date, field: XCUIElement, dismissLabel: String) {
        if !field.exists { reveal(field, requiresHitTarget: false) }
        let combined = field.buttons["Date and Time Picker"].firstMatch
        let isCombined = combined.exists
        let control = isCombined ? combined : field.buttons["Time Picker"].firstMatch
        reveal(control)
        let dismissFrame = app.staticTexts[dismissLabel].firstMatch.frame
        let dismiss = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: dismissFrame.midX - app.frame.minX, dy: dismissFrame.midY - app.frame.minY))
        if isCombined {
            combined.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        } else {
            tap(control)
        }
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.pickerWheels.count, 3)
        for (index, format) in ["h", "mm", "a"].enumerated() {
            app.pickerWheels.element(boundBy: index).adjust(toPickerWheelValue: formatter(format).string(from: date))
        }
        if isCombined {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        } else { dismiss.tap() }
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForNonExistence(timeout: 5))
    }

    private func evidence(_ name: String, screenshot: Bool = false) {
        if screenshot {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        print("T392 UI \(name) \(ISO8601DateFormatter().string(from: Date()))")
    }

    private func assertVisibleText(_ text: String, within container: XCUIElement? = nil) {
        let item = (container ?? app).staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch
        reveal(item, requiresHitTarget: false)
        XCTAssertTrue(item.exists, "Missing expected text: \(text)")
    }

    private func serviceTimeText(_ stamp: String) throws -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened,
            locale: Locale(identifier: "en_US"), calendar: calendar, timeZone: calendar.timeZone)
            .timeZone(.iso8601(.short))
        return try localDate(stamp).formatted(style) + " (America/Los_Angeles)"
    }

    private func assertRequestDetail(_ row: Readback, groomer: Bool = false) throws {
        let detail = element(groomer ? "groomer.requests.detail" : "customer.requests.detail")
        func assertText(_ text: String) { assertVisibleText(text, within: detail) }
        let services = ["full_groom": "Full Groom", "bath_and_brush": "Bath & Brush",
            "haircut_only": "Haircut Only", "nail_trim": "Nail Trim", "de_shedding": "De-shedding",
            "custom_request": "Custom Request"]
        assertText(try XCTUnwrap(services[row.serviceType]))
        assertText(row.notes)
        assertText(row.petName)
        assertText(row.species == "cat" ? "Cat" : "Dog")
        for stamp in row.window {
            assertText(try serviceTimeText(stamp))
        }
        assertText(row.locationMode == "groomer_comes_to_customer"
            ? (groomer ? "Customer's Home" : "My Home")
            : (groomer ? "My Place" : "Groomer's Place"))
        assertText(row.streetAddress)
        if let city = row.city { assertText(city) }
        if row.locationMode == "customer_comes_to_groomer", let radius = row.travelRadiusMiles {
            assertText("\(radius) miles")
        }
    }

    func testSessionSwitch() throws {
        let input = try input(SessionSwitch.self, role: .customer)
        XCTAssertEqual(input.rows.count, 1)
        XCTAssertNotNil(input.switchActor?.range(of: "^G[0-9]{2}$", options: .regularExpression))
        let row = try XCTUnwrap(input.rows.first)
        let driver = TestOpsUIFlowDriver()

        func openServiceStep() {
            tap(element("customer.tab.home"))
            tap(element("customer.home.start-request"))
            let pet = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH 'customer.requests.wizard.pet.'")).firstMatch
            reveal(pet)
            tap(pet)
            tap(element("customer.requests.wizard.continue"))
        }
        func closeServiceDraft() {
            tap(element("customer.requests.wizard.back"))
            tap(element("customer.requests.wizard.dismiss"))
            XCTAssertTrue(element("customer.requests.wizard").waitForNonExistence(timeout: 10))
        }
        func signOut(_ role: TestOpsSeedRole) {
            tap(element("\(role.rawValue).tab.account"))
            assertVisibleText(role == .customer ? row.customerName : row.groomerName)
            let button = element(role == .customer ? "auth.sign-out" : "groomer.account.sign-out")
            reveal(button)
            tap(button)
            driver.assertAuthenticationRoot()
            XCTAssertFalse(element("customer.requests.wizard").exists)
            evidence("\(row.id) \(role.rawValue) actual sign-out cleared protected surfaces")
        }

        openServiceStep()
        let service = element("customer.requests.wizard.service.nail_trim")
        reveal(service)
        tap(service)
        tap(element("customer.requests.wizard.continue"))
        XCTAssertTrue(element("customer.requests.use-profile-address").waitForExistence(timeout: 10))
        tap(element("customer.requests.wizard.back"))
        closeServiceDraft()
        signOut(.customer)
        driver.signIn(try TestOpsSeedAccount.fromEnvironment(role: .groomer), signedOutTimeout: 20)
        XCTAssertFalse(element("customer.tabs").exists)
        tap(element("groomer.tab.requests"))
        XCTAssertTrue(element("groomer.requests.segment.matches").waitForExistence(timeout: 10))
        XCTAssertFalse(element("customer.requests.publish").exists)
        signOut(.groomer)
        driver.signIn(try TestOpsSeedAccount.fromEnvironment(role: .customer), signedOutTimeout: 20)
        XCTAssertFalse(element("groomer.tabs").exists)
        openServiceStep()
        tap(element("customer.requests.wizard.continue"))
        XCTAssertTrue(element("customer.requests.form-error").waitForExistence(timeout: 10),
            "Returning to the customer must not reuse the prior selected service")
        XCTAssertTrue(element("customer.requests.wizard.service.nail_trim").exists)
        closeServiceDraft()
        tap(element("customer.tab.account"))
        assertVisibleText(row.customerName)
        evidence("\(row.id) original customer restored without groomer state or previous draft")
    }

    func testPublicationBatch() throws {
        let input = try input(Publication.self, role: .customer)
        for row in input.rows {
            XCTAssertTrue(row.notes.hasPrefix("TESTOPS:\(input.runID) \(row.id)"))
            if let reference = input.publicationSourceReference {
                tap(element("customer.tab.requests"))
                let detail = app.buttons.matching(NSPredicate(
                    format: "label == 'Request Detail' AND value == %@", reference)).firstMatch
                reveal(detail)
                tap(detail)
                let revise = element("customer.requests.revise")
                reveal(revise)
                tap(revise)
                evidence("\(row.id) revision opened from original \(reference)")
            } else {
                tap(element("customer.tab.home"))
                tap(element("customer.home.start-request"))
                let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                    "customer.requests.wizard.pet.\(row.species)."))
                let selected = candidates.matching(NSPredicate(format: "label BEGINSWITH %@", row.petName + ","))
                let exact = row.petWeight.map { selected.matching(NSPredicate(format: "label CONTAINS %@", String(format: "%g lbs", $0))) }
                    ?? selected.matching(NSPredicate(format: "NOT label CONTAINS ' lbs'"))
                XCTAssertEqual(exact.count, 1, "Pet identity must be unambiguous")
                let pet = exact.firstMatch
                reveal(pet, maximumScrolls: 24)
                tap(pet)
                tap(element("customer.requests.wizard.continue"))
                let service = element("customer.requests.wizard.service.\(row.serviceType)")
                reveal(service)
                tap(service)
                tap(element("customer.requests.wizard.continue"))
            }
            XCTAssertFalse(element("customer.requests.form-error").exists,
                "Selected service must advance before location controls are queried")
            let mode = row.locationMode == "groomer_comes_to_customer" ? "My Home," : "Groomer's Place,"
            tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", mode)).firstMatch)
            tap(element("customer.requests.use-profile-address"))
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value != 'Street address' AND value != ''"),
                object: element("beckon.address.line1"))], timeout: 15), .completed)
            if let radius = row.travelRadiusMiles {
                let stepper = app.steppers["customer.requests.travel-range"].firstMatch
                let slider = app.sliders.firstMatch
                reveal(slider)
                let initial = try XCTUnwrap(Int(slider.value as? String ?? ""))
                // SwiftUI exposes the native stepper as one adjustable AX
                // element, not two child buttons. Tap its visible +/- control.
                let adjustment = stepper.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                    .withOffset(CGVector(dx: radius < initial ? -70 : -23, dy: 0))
                for _ in 0..<abs(radius - initial) { adjustment.tap() }
                XCTAssertTrue(app.staticTexts["\(radius) mi"].firstMatch.exists,
                    "Expected \(radius) mi; native slider label=\(slider.label), value=\(String(describing: slider.value))")
                print("T392 UI exact travel radius \(radius) mi")
            }
            XCTAssertEqual(row.window.count, 2)
            let start = try localDate(row.window[0]), end = try localDate(row.window[1])
            selectDay(start, field: element("customer.requests.wizard.date-picker"), dismissLabel: "Choose Another Date")
            let detailedTime = app.buttons["Detailed Time"].firstMatch
            reveal(detailedTime)
            tap(detailedTime)
            XCTAssertTrue(element("customer.requests.start-time").waitForExistence(timeout: 5))
            selectTime(start, field: element("customer.requests.start-time"), dismissLabel: "Start Time")
            selectTime(end, field: element("customer.requests.end-time"), dismissLabel: "End Time")
            tap(element("customer.requests.wizard.continue"))
            XCTAssertFalse(element("customer.requests.form-error").exists,
                "Location/time validation rejected the frozen input")
            fill(element("customer.requests.wizard.notes"), with: row.notes)
            tap(element("customer.requests.wizard.continue"))
            let publish = element("customer.requests.publish")
            XCTAssertTrue(publish.waitForExistence(timeout: 10) && publish.isEnabled)
            evidence("\(row.id) publication ready")
            if input.previewOnly {
                app.terminate()
                continue
            }
            if input.publicationDoubleTap == true { publish.doubleTap() } else { tap(publish) }
            if let fault = input.publicationFault {
                XCTAssertEqual(row.id, fault.marker)
                XCTAssertTrue(app.staticTexts["We Could Not Publish Request"].firstMatch.waitForExistence(timeout: 20))
                XCTAssertTrue(element("customer.requests.wizard").exists)
                XCTAssertTrue(publish.isEnabled)
                evidence("\(row.id) \(fault.phase) publication failure visible")
                if !fault.retryAfterFailure { continue }
                if fault.reopenAfterFailure == true {
                    XCTAssertTrue(element("customer.requests.publication-recovery").exists)
                    XCTAssertFalse(element("customer.requests.wizard.back").exists)
                    tap(element("customer.requests.wizard.dismiss"))
                    XCTAssertTrue(element("customer.requests.wizard").waitForNonExistence(timeout: 10))
                    if fault.restartAfterFailure == true {
                        app.terminate()
                        if let faultIndex = app.launchArguments.firstIndex(of: "--beckon-testops-publish-fault") {
                            app.launchArguments.removeSubrange(faultIndex...faultIndex + 1)
                        }
                        app.launchArguments.removeAll { $0 == "--beckon-testops-clear-session" }
                        app.launch()
                    }
                    tap(element("customer.tab.home"))
                    tap(element("customer.home.start-request"))
                    XCTAssertTrue(element("customer.requests.publication-recovery").waitForExistence(timeout: 10))
                    assertVisibleText(row.notes)
                    XCTAssertFalse(element("customer.requests.wizard.notes").exists)
                    evidence("\(row.id) immutable publication restored after close/restart")
                }
                tap(publish)
            }
            XCTAssertTrue(element("customer.requests.wizard").waitForNonExistence(timeout: 35))
            if input.publicationSourceReference != nil { tap(app.navigationBars.buttons.firstMatch) }
            tap(element("customer.tab.requests"))
            XCTAssertTrue(element("customer.requests.list").waitForExistence(timeout: 15))
            evidence("\(row.id) publication returned")
        }
    }

    func testQuoteBatch() throws {
        let input = try input(Quote.self, role: .groomer)
        for row in input.rows {
            XCTAssertTrue(row.message.hasPrefix("TESTOPS:\(input.runID) \(row.id)"))
            tap(element("groomer.tab.requests"))
            tap(element("groomer.requests.segment.matches"))
            let request = app.buttons.matching(identifier: "groomer.requests.row.\(input.runID)")
                .matching(NSPredicate(format: "value == %@", row.reference)).firstMatch
            for _ in 0..<3 {
                if request.exists { break }
                let more = element("groomer.requests.load-more")
                if more.exists { tap(more) }
                else { app.swipeUp() }
            }
            tap(request)
            XCTAssertFalse(element("groomer.offers.withdraw").exists, "Never silently replace an already committed quote")
            let start = try localDate(row.start), field = element("groomer.offers.start-input")
            selectDay(start, field: field, dismissLabel: "Proposed Start")
            selectTime(start, field: field, dismissLabel: "Proposed Start")
            fill(element("groomer.offers.duration"), with: String(row.durationMinutes))
            fill(element("groomer.offers.price"), with: row.price)
            fill(element("groomer.offers.message"), with: row.message)
            for key in row.confirmations {
                XCTAssertFalse(element("groomer.offers.submit").isEnabled,
                    "Every required assessment must be confirmed before submission")
                let confirmation = element("groomer.offers.confirmation.\(key)")
                reveal(confirmation)
                XCTAssertEqual(confirmation.value as? String, "0")
                confirmation.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
                XCTAssertEqual(confirmation.value as? String, "1")
            }
            let submit = element("groomer.offers.submit")
            XCTAssertTrue(submit.isEnabled)
            evidence("\(row.id) quote ready")
            if input.previewOnly { app.terminate(); continue }
            tap(submit)
            if let expectedError = row.expectedError {
                XCTAssertTrue(app.staticTexts[expectedError].firstMatch.waitForExistence(timeout: 35),
                    "Invalid quote must show its specific time validation error")
                XCTAssertFalse(element("groomer.offers.withdraw").exists)
                evidence("\(row.id) quote rejected")
                app.terminate()
                continue
            }
            XCTAssertTrue(element("groomer.offers.withdraw").waitForExistence(timeout: 35))
            evidence("\(row.id) quote returned")
            tap(app.navigationBars.buttons.firstMatch)
        }
    }

    func testRankingBrowse() throws {
        let role = try XCTUnwrap(TestOpsSeedRole(rawValue: value("TESTOPS_INTERACTIVE_ROLE") ?? ""))
        let input = try input(RankingBrowse.self, role: role)
        let prefix = role == .groomer ? "groomer.requests" : "customer.offers"
        for row in input.rows {
            func openList() throws {
                tap(element("\(role.rawValue).tab.requests"))
                if role == .groomer {
                    tap(element("groomer.requests.segment.matches"))
                } else {
                    let reference = try XCTUnwrap(row.reference)
                    let offers = app.buttons.matching(NSPredicate(
                        format: "label == 'Request Offers' AND value == %@", reference)).firstMatch
                    reveal(offers)
                    tap(offers)
                }
            }
            try openList()
            for order in row.orders {
                if order.select != false {
                    tap(element("\(prefix).sort"))
                    tap(app.buttons[order.title].firstMatch)
                }
                let expected = order.groups.flatMap { $0 }
                XCTAssertEqual(Set(expected).count, expected.count)
                let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "\(prefix).row"))
                let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    let identities = rows.allElementsBoundByIndex.compactMap { item in
                        if role == .groomer { return item.value as? String }
                        let label = item.label
                        return expected.first { label.contains($0) }
                    }
                    guard !identities.isEmpty else { return false }
                    let indexes = identities.compactMap { id in order.groups.firstIndex { $0.contains(id) } }
                    return indexes.count == identities.count && indexes == indexes.sorted()
                        && indexes.first == 0 && self.app.buttons["Refresh"].firstMatch.isEnabled
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 20), .completed)
                var seen: [String] = []
                var appendedPage = false
                for _ in 0..<32 {
                    for item in rows.allElementsBoundByIndex {
                        let identity: String
                        if role == .groomer {
                            identity = try XCTUnwrap(item.value as? String)
                        } else {
                            let label = item.label
                            let names = expected.filter { label.contains($0) }
                            XCTAssertEqual(names.count, 1, "Unexpected or ambiguous authorized offer row")
                            identity = try XCTUnwrap(names.first)
                        }
                        XCTAssertTrue(expected.contains(identity), "Unexpected authorized list member: \(identity)")
                        if !seen.contains(identity) { seen.append(identity) }
                    }
                    if seen.count == expected.count { break }
                    let more = element("\(prefix).load-more")
                    if more.exists && more.isHittable {
                        XCTAssertEqual(seen.count, 25, "Native first page must contain 25 distinct items")
                        evidence("\(row.id) \(order.title) first 25 native rows")
                        tap(more)
                        appendedPage = true
                        XCTAssertTrue(more.waitForNonExistence(timeout: 20),
                            "The single remaining page must finish before another interaction")
                        XCTAssertFalse(element("\(prefix).load-more-error").exists)
                    } else {
                        app.swipeUp()
                    }
                }
                XCTAssertEqual(seen.count, expected.count)
                var offset = 0
                for group in order.groups {
                    XCTAssertEqual(Set(seen.dropFirst(offset).prefix(group.count)), Set(group),
                        "Explicit sort primary order differs from the independent expected groups")
                    offset += group.count
                }
                XCTAssertEqual(appendedPage, expected.count > 25)
                XCTAssertFalse(element("\(prefix).load-more-error").exists)
                evidence("\(row.id) \(order.title) whole native pool \(seen.joined(separator: ","))")
                if row.backgroundAndRestart == true {
                    XCUIDevice.shared.press(.home)
                    XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5)
                        || app.state == .runningBackgroundSuspended)
                    app.activate()
                    XCTAssertTrue(element("\(prefix).sort").waitForExistence(timeout: 10))
                    app.terminate()
                    app.launch()
                    try openList()
                    let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                        let identities = rows.allElementsBoundByIndex.compactMap { item in
                            if role == .groomer { return item.value as? String }
                            let label = item.label
                            return expected.first { label.contains($0) }
                        }
                        return !identities.isEmpty && identities == Array(seen.prefix(identities.count))
                            && self.app.buttons["Refresh"].firstMatch.isEnabled
                    }, object: nil)
                    XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 20), .completed,
                        "Restart must restore the observed order without selecting the mode again")
                    evidence("\(row.id) \(order.title) preference retained after background and restart")
                }
            }
            if row.signOutAfter == true {
                tap(element("\(role.rawValue).tab.account"))
                let signOut = element(role == .customer ? "auth.sign-out" : "groomer.account.sign-out")
                reveal(signOut)
                tap(signOut)
                TestOpsUIFlowDriver().assertAuthenticationRoot()
                evidence("\(row.id) actual sign-out after account-scoped sorting")
            }
        }
    }

    func testRequestClosure() throws {
        let input = try input(RequestClosure.self, role: .customer)
        tap(element("customer.tab.requests"))
        for row in input.rows {
            XCTAssertNotNil(row.reference.range(of: "^[A-F0-9]{8}$", options: .regularExpression))
            let cancel = app.buttons.matching(NSPredicate(
                format: "label == 'Cancel Request' AND value == %@", row.reference)).firstMatch
            for _ in 0..<4 {
                if cancel.exists && !cancel.frame.isEmpty && app.frame.contains(cancel.frame)
                    && cancel.isHittable { break }
                app.swipeLeft()
            }
            reveal(cancel)
            tap(cancel)
            let confirmation = app.alerts["Cancel this request?"]
            XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
            tap(confirmation.buttons["Cancel Request"])
            XCTAssertTrue(confirmation.waitForNonExistence(timeout: 10))
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !cancel.exists || !cancel.isEnabled
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 20), .completed)
            evidence("\(row.id) \(row.reference) customer UI cancelled request")
        }
    }

    func testCustomerRequestReadback() throws {
        let input = try input(Readback.self, role: .customer)
        app.launchArguments.removeAll { $0 == "--beckon-testops-clear-session" }
        app.terminate()
        app.launch()
        tap(element("customer.tab.requests"))
        for row in input.rows {
            let detail = app.buttons.matching(NSPredicate(
                format: "label == 'Request Detail' AND value == %@", row.reference)).firstMatch
            for _ in 0..<3 {
                if detail.exists { break }
                let more = element("customer.requests.load-more")
                if more.exists { tap(more) }
                else { app.swipeLeft() }
            }
            reveal(detail)
            evidence("\(row.id) customer request after restart")
            tap(detail)
            XCTAssertTrue(element("customer.requests.detail").waitForExistence(timeout: 15))
            try assertRequestDetail(row)
            evidence("\(row.id) customer authoritative detail")
            tap(app.navigationBars.buttons.firstMatch)
            let offers = app.buttons.matching(NSPredicate(
                format: "label == 'Request Offers' AND value == %@", row.reference)).firstMatch
            guard let quotes = row.quotes, !quotes.isEmpty else {
                reveal(offers, requiresHitTarget: false)
                XCTAssertFalse(offers.isEnabled, "An empty source pool must not expose an actionable offer")
                evidence("\(row.id) empty offer pool after restart")
                continue
            }
            reveal(offers)
            tap(offers)
            for quote in quotes {
                let offer = app.buttons.matching(identifier: "customer.offers.row.\(input.runID)")
                    .matching(NSPredicate(format: "label CONTAINS %@", quote.groomerName)).firstMatch
                reveal(offer)
                tap(offer)
                XCTAssertTrue(element("customer.offers.detail").waitForExistence(timeout: 15))
                let rating = quote.ratingCount == 0 ? "No reviews yet" : String(
                    format: "%.1f · %d reviews", Double(quote.ratingSum) / Double(quote.ratingCount), quote.ratingCount)
                let ratingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", rating)).firstMatch
                reveal(ratingText)
                XCTAssertTrue(ratingText.exists)
                let evidenceText = app.staticTexts.matching(NSPredicate(
                    format: "label CONTAINS %@", quote.evidenceSummary)).firstMatch
                reveal(evidenceText, requiresHitTarget: false)
                XCTAssertTrue(evidenceText.exists)
                for line in quote.evidenceLines {
                    XCTAssertTrue(evidenceText.label.contains(line), "Missing contextual evidence: \(line)")
                }
                let price = app.staticTexts[quote.price].firstMatch
                reveal(price)
                XCTAssertTrue(price.exists)
                assertVisibleText(try serviceTimeText(quote.start))
                assertVisibleText(try serviceTimeText(quote.end))
                let message = app.staticTexts.matching(NSPredicate(format: "label == %@", quote.message)).firstMatch
                reveal(message)
                XCTAssertTrue(message.exists)
                evidence("\(quote.id) customer quote after restart")
                if ["R03", "R04", "R05"].contains(row.id) {
                    let accept = element("customer.offers.accept")
                    reveal(accept)
                    tap(accept)
                    XCTAssertTrue(element("customer.offers.confirmation").waitForExistence(timeout: 10))
                    assertVisibleText(row.locationMode == "groomer_comes_to_customer" ? "My Home" : "Groomer's Place")
                    assertVisibleText(quote.confirmationAddress)
                    evidence("\(quote.id) confirmation location verified without booking")
                    tap(app.buttons["Not Yet"].firstMatch)
                    XCTAssertTrue(element("customer.offers.confirmation").waitForNonExistence(timeout: 10))
                }
                tap(app.navigationBars.buttons.firstMatch)
            }
            for check in row.sortChecks ?? [] {
                tap(element("customer.offers.sort"))
                tap(app.buttons[check.title].firstMatch)
                let rows = app.buttons.matching(identifier: "customer.offers.row.\(input.runID)")
                let names = check.groups.flatMap { $0 }
                let ordered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    let labels = rows.allElementsBoundByIndex.map(\.label)
                    guard labels.count == names.count else { return false }
                    var offset = 0
                    for group in check.groups {
                        let observed = labels[offset..<(offset + group.count)].compactMap { label in
                            names.first { label.contains($0) }
                        }
                        guard Set(observed) == Set(group), observed.count == group.count else { return false }
                        offset += group.count
                    }
                    return true
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [ordered], timeout: 20), .completed,
                    "Explicit \(check.title) must order the complete source pool by its primary field")
                XCTAssertFalse(element("customer.offers.load-more-error").exists)
                evidence("\(row.id) \(check.title) complete source order")
            }
            tap(app.navigationBars.buttons.firstMatch)
        }
    }

    func testGroomerRequestReadback() throws {
        let input = try input(Readback.self, role: .groomer)
        tap(element("groomer.tab.requests"))
        if let expected = input.matchedReferences {
            tap(element("groomer.requests.segment.matches"))
            let rows = app.buttons.matching(identifier: "groomer.requests.row.\(input.runID)")
            let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                rows.allElementsBoundByIndex.compactMap { $0.value as? String }.sorted() == expected.sorted()
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 20), .completed)
            XCTAssertFalse(element("groomer.requests.load-more").exists)
            for reference in input.forbiddenReferences ?? [] {
                XCTAssertFalse(rows.matching(NSPredicate(format: "value == %@", reference)).firstMatch.exists)
                XCTAssertFalse(expected.contains(reference))
            }
            evidence("\(input.actor) complete matched pool excludes illegal sources")
        } else {
            XCTAssertTrue((input.forbiddenReferences ?? []).isEmpty,
                "Negative UI checks require the complete authoritative matched pool")
        }
        if input.routeViaOffers != true {
            tap(element("groomer.tab.home"))
            tap(element("groomer.home.notifications"))
        }
        for row in input.rows {
            if input.routeViaOffers == true {
                tap(element("groomer.requests.segment.offers"))
                let quote = try XCTUnwrap(row.quotes?.first)
                let offer = app.buttons.matching(NSPredicate(
                    format: "label CONTAINS %@ AND label CONTAINS %@", row.petName, quote.price)).firstMatch
                reveal(offer)
                tap(offer)
                let detailOpened = element("groomer.offers.detail").waitForExistence(timeout: 10)
                if !detailOpened {
                    let hierarchy = XCTAttachment(string: app.debugDescription)
                    hierarchy.name = "Offer navigation hierarchy"
                    hierarchy.lifetime = .keepAlways
                    add(hierarchy)
                }
                XCTAssertTrue(detailOpened, "Selected offer did not open its detail")
                let manage = element("groomer.offers.view-request")
                XCTAssertTrue(manage.waitForExistence(timeout: 5),
                    "Pending Offers detail must expose its existing request management flow")
                tap(manage)
            } else {
                let stamp = try localDate(XCTUnwrap(row.notificationCreatedAt)).formatted(
                    Date.FormatStyle(date: .abbreviated, time: .shortened,
                        locale: Locale(identifier: "en_US"),
                        timeZone: XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))))
                let notification = app.buttons.matching(identifier: "groomer.notifications.open")
                    .matching(NSPredicate(format: "label CONTAINS 'New request match' AND label CONTAINS %@", stamp)).firstMatch
                reveal(notification)
                tap(notification)
            }
            XCTAssertTrue(element("groomer.requests.detail").waitForExistence(timeout: 15))
            try assertRequestDetail(row, groomer: true)
            for quote in row.quotes ?? [] {
                assertVisibleText(quote.price)
                assertVisibleText(quote.message)
            }
            if !(row.quotes ?? []).isEmpty {
                XCTAssertTrue(element("groomer.offers.withdraw").exists,
                    "Readback must retain the pending quote without replacement")
            }
            evidence("\(row.id) groomer source and quote readback")
            tap(app.navigationBars.buttons.firstMatch)
            if input.routeViaOffers == true { tap(app.navigationBars.buttons.firstMatch) }
        }
    }

    func testAcceptanceBatch() throws {
        let input = try input(Acceptance.self, role: .customer)
        for row in input.rows {
            tap(element("customer.tab.requests"))
            let offers = app.buttons.matching(NSPredicate(
                format: "label == 'Request Offers' AND value == %@", row.reference)).firstMatch
            XCTAssertTrue(element("customer.requests.list").waitForExistence(timeout: 20))
            for _ in 0..<6 {
                if offers.exists { break }
                // Lazy carousel cards do not enter the AX tree until approached.
                let carousel = app.scrollViews["customer.requests.progress-carousel"].firstMatch
                if carousel.exists {
                    carousel.swipeLeft()
                    if offers.waitForExistence(timeout: 2) { break }
                }
                let more = element("customer.requests.load-more")
                if more.exists && more.isEnabled {
                    reveal(more)
                    tap(more)
                    _ = offers.waitForExistence(timeout: 2)
                }
            }
            reveal(offers)
            tap(offers)
            let offer = app.buttons.matching(identifier: "customer.offers.row.\(input.runID)")
                .matching(NSPredicate(format: "label CONTAINS %@", row.groomerName)).firstMatch
            reveal(offer)
            tap(offer)
            let accept = app.buttons.matching(NSPredicate(
                format: "identifier == 'customer.offers.accept' OR label == 'Review & Accept'")).firstMatch
            reveal(accept)
            if !accept.isEnabled {
                let details = XCTAttachment(string: element("customer.offers.detail").debugDescription)
                details.name = "Offer confirmation unavailable"
                details.lifetime = .keepAlways
                add(details)
            }
            XCTAssertTrue(accept.isEnabled, "Offer is not currently confirmable; inspect its displayed reason")
            tap(accept)
            XCTAssertTrue(element("customer.offers.confirmation").waitForExistence(timeout: 15))
            let confirm = app.buttons.matching(NSPredicate(
                format: "identifier == 'customer.offers.confirm' OR label == 'Confirm & Book'")).firstMatch
            XCTAssertTrue(confirm.isEnabled)
            evidence("\(row.id) acceptance ready")
            if input.previewOnly { app.terminate(); continue }
            tap(confirm)
            XCTAssertTrue(element("customer.offers.confirmation").waitForNonExistence(timeout: 35))
            XCTAssertTrue(element("bookings.detail").waitForExistence(timeout: 20))
            evidence("\(row.id) acceptance returned")
            for _ in 0..<3 { tap(app.navigationBars.buttons.firstMatch) }
            tap(element("customer.tab.bookings"))
            XCTAssertTrue(element("bookings.row.request.\(row.reference)").waitForExistence(timeout: 5),
                "Committed booking must reach the already loaded list without a refresh")
            evidence("\(row.id) customer booking visible")
        }
    }

    func testScheduleReadback() throws {
        let input = try input(ScheduledBooking.self, role: .groomer)
        let first = try XCTUnwrap(input.rows.first)
        let day = try localDate(first.start)
        for row in input.rows {
            XCTAssertEqual(try formatter("yyyy-MM-dd").string(from: localDate(row.start)),
                formatter("yyyy-MM-dd").string(from: day))
        }
        app.launchArguments.removeAll { $0 == "--beckon-testops-clear-session" }
        app.terminate()
        app.launch()
        tap(element("groomer.tab.bookings"))
        XCTAssertTrue(element("groomer.schedule").waitForExistence(timeout: 20))
        selectDay(day, field: app, dismissLabel: "Appointment Date")
        XCTAssertTrue(element("groomer.schedule.timeline").waitForExistence(timeout: 20))
        for row in input.rows {
            let booking = element("groomer.booking.row.request.\(row.reference)")
            reveal(booking)
            tap(booking)
            let detail = element("bookings.detail")
            XCTAssertTrue(detail.waitForExistence(timeout: 10))
            assertVisibleText(row.petName, within: detail)
            try assertBookingDetails(row, within: detail)
            evidence("\(row.id) groomer confirmed schedule readback")
            tap(app.navigationBars.buttons.firstMatch)
        }
    }

    func testWithdrawalBatch() throws {
        let input = try input(Withdrawal.self, role: .groomer)
        tap(element("groomer.tab.requests"))
        tap(element("groomer.requests.segment.offers"))
        for row in input.rows {
            let offer = app.buttons.matching(NSPredicate(
                format: "label CONTAINS %@ AND label CONTAINS %@ AND label CONTAINS %@",
                row.petName, row.price, row.timeText ?? "")).firstMatch
            reveal(offer)
            tap(offer)
            XCTAssertTrue(element("groomer.offers.detail").waitForExistence(timeout: 10))
            tap(element("groomer.offers.view-request"))
            XCTAssertTrue(element("groomer.requests.detail").waitForExistence(timeout: 15))
            assertVisibleText(row.petName, within: element("groomer.requests.detail"))
            assertVisibleText(row.message, within: element("groomer.requests.detail"))
            let withdraw = element("groomer.offers.withdraw")
            reveal(withdraw)
            evidence("\(row.id) withdrawal ready")
            tap(withdraw)
            XCTAssertTrue(withdraw.waitForNonExistence(timeout: 35))
            evidence("\(row.id) withdrawal returned")
            tap(app.navigationBars.buttons.firstMatch)
            XCTAssertTrue(element("groomer.offers.detail").waitForExistence(timeout: 10))
            assertVisibleText("Withdrawn", within: element("groomer.offers.detail"))
            evidence("\(row.id) parent offer refreshed to withdrawn")
            tap(app.navigationBars.buttons.firstMatch)
        }
    }

    func testOfferExpiry() throws {
        let input = try input(Acceptance.self, role: .customer)
        XCTAssertEqual(input.rows.count, 2)
        tap(element("customer.tab.requests"))
        for (index, row) in input.rows.enumerated() {
            let offers = app.buttons.matching(NSPredicate(
                format: "label == 'Request Offers' AND value == %@", row.reference)).firstMatch
            reveal(offers)
            tap(offers)
            let offer = app.buttons.matching(identifier: "customer.offers.row.\(input.runID)")
                .matching(NSPredicate(format: "label CONTAINS %@", row.groomerName)).firstMatch
            reveal(offer)
            tap(offer)
            let accept = app.buttons.matching(NSPredicate(
                format: "identifier == 'customer.offers.accept' OR label == 'Review & Accept'")).firstMatch
            reveal(accept)
            tap(accept)
            XCTAssertTrue(element("customer.offers.confirmation").waitForExistence(timeout: 15))
            let confirm = app.buttons.matching(NSPredicate(
                format: "identifier == 'customer.offers.confirm' OR label == 'Confirm & Book' OR label == 'Offer Expired'")).firstMatch
            XCTAssertTrue(confirm.exists && confirm.isEnabled)
            evidence("\(row.id) live confirmation ready")
            if index == 0 {
                XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == true AND enabled == false"), object: confirm)],
                    timeout: 540), .completed)
                XCTAssertTrue(app.buttons["Offer Expired"].firstMatch.exists)
                XCTAssertFalse(element("bookings.detail").exists)
                evidence("\(row.id) confirmation naturally expired")
            } else {
                evidence("\(row.id) later offer remains selectable after A expiry")
            }
            tap(app.buttons["Not Yet"].firstMatch)
            tap(app.navigationBars.buttons.firstMatch)
            tap(app.navigationBars.buttons.firstMatch)
        }
    }

    func testCustomerBookingReadback() throws {
        let input = try input(ScheduledBooking.self, role: .customer)
        app.launchArguments.removeAll { $0 == "--beckon-testops-clear-session" }
        app.terminate()
        app.launch()
        tap(element("customer.tab.bookings"))
        for row in input.rows {
            let booking = element("bookings.row.request.\(row.reference)")
            reveal(booking)
            tap(booking)
            let detail = element("bookings.detail")
            XCTAssertTrue(detail.waitForExistence(timeout: 10))
            assertVisibleText("Booking Confirmed", within: detail)
            try assertBookingDetails(row, within: detail)
            evidence("\(row.id) customer confirmed booking after restart")
            tap(app.navigationBars.buttons.firstMatch)
        }
    }

    func testPetUpdate() throws {
        let input = try input(PetUpdate.self, role: .customer)
        XCTAssertFalse(input.previewOnly)
        tap(element("customer.tab.home"))
        let list = app.scrollViews["customer.pets.list"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 20))
        for row in input.rows {
            let pet = app.buttons.matching(NSPredicate(
                format: "label == %@ OR label BEGINSWITH %@", row.petName, row.petName + ",")).firstMatch
            for _ in 0..<40 {
                if pet.exists && pet.isHittable { break }
                if pet.exists && pet.frame.maxX < app.frame.minX { list.swipeRight(velocity: .fast) }
                else { list.swipeLeft(velocity: .fast) }
            }
            XCTAssertTrue(pet.exists && pet.isHittable, "Owned pet must be reachable in its normal carousel")
            tap(pet)
            let weight = element("customer.pets.weight-input")
            reveal(weight)
            XCTAssertEqual(Double(weight.value as? String ?? ""), Double(row.originalWeight))
            fill(weight, with: row.newWeight)
            let save = element("customer.pets.form-save")
            XCTAssertTrue(save.isEnabled)
            evidence("\(row.id) pet edit ready")
            tap(save)
            XCTAssertTrue(save.waitForNonExistence(timeout: 30))
            evidence("\(row.id) pet edit returned")
        }
    }

    func testBookingActions() throws {
        let role = try XCTUnwrap(TestOpsSeedRole(rawValue: value("TESTOPS_INTERACTIVE_ROLE") ?? ""))
        let input = try input(BookingAction.self, role: role)
        XCTAssertFalse(input.previewOnly, "Booking actions require explicit outcome assertions")
        for (index, row) in input.rows.enumerated() {
            func openDetail() throws {
                tap(element("\(role.rawValue).tab.bookings"))
                if role == .groomer {
                    XCTAssertTrue(element("groomer.schedule").waitForExistence(timeout: 20))
                    selectDay(try localDate(row.start), field: app, dismissLabel: "Appointment Date")
                } else if let scope = row.scope {
                    tap(element("bookings.scope.\(scope)"))
                }
                let prefix = role == .groomer ? "groomer.booking" : "bookings"
                let booking = element("\(prefix).row.request.\(row.reference)")
                reveal(booking)
                tap(booking)
            }
            if row.sameDetail != true { try openDetail() }
            XCTAssertTrue(element("bookings.detail").waitForExistence(timeout: 15))
            // Customer detail has a status heading; its exact request row binds identity.
            if role == .groomer { assertVisibleText(row.petName, within: element("bookings.detail")) }
            if let expected = row.expectedReviewForm {
                if expected { reveal(element("bookings.review.submit")) }
                XCTAssertEqual(element("bookings.review.submit").exists, expected)
            }
            if row.kind == "review" {
                XCTAssertEqual(role, .customer)
                let content = try XCTUnwrap(row.reviewContent)
                XCTAssertTrue(content.hasPrefix("TESTOPS:\(input.runID)"))
                fill(element("bookings.review.content"), with: content)
                let rating = try XCTUnwrap(row.reviewRating)
                XCTAssertTrue((1...5).contains(rating))
                tap(element("bookings.review.rating").buttons[String(rating)].firstMatch)
                let keys = try XCTUnwrap(row.expectedReviewKeys)
                let answers = row.reviewAnswers ?? [:]
                XCTAssertTrue(Set(answers.keys).isSubset(of: Set(keys)))
                for key in keys {
                    let picker = element("bookings.review.fit.\(key)")
                    reveal(picker)
                    let title: String
                    switch answers[key] {
                    case "positive": title = "Went Well"
                    case "negative": title = "Needs Care"
                    case nil: title = "Skip"
                    default: throw NSError(domain: "Invalid review outcome", code: 1)
                    }
                    tap(picker.buttons[title].firstMatch)
                }
                let actualKeys = app.segmentedControls.matching(NSPredicate(
                    format: "identifier BEGINSWITH 'bookings.review.fit.'")).allElementsBoundByIndex
                    .map { String($0.identifier.dropFirst("bookings.review.fit.".count)) }
                XCTAssertEqual(actualKeys.sorted(), keys.sorted())
                let submit = element("bookings.review.submit")
                reveal(submit)
                XCTAssertTrue(submit.isEnabled)
                evidence("\(row.id) review ready")
                tap(submit)
                if row.reviewShouldSave == false {
                    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", row.expectedText))
                        .firstMatch.waitForExistence(timeout: 20))
                    XCTAssertTrue(submit.exists)
                    XCTAssertEqual(element("bookings.review.content").value as? String, content)
                } else {
                    XCTAssertTrue(element("bookings.review.display").waitForExistence(timeout: 30))
                    XCTAssertFalse(submit.exists)
                }
            } else if row.kind != "read" {
                XCTAssertTrue(["fulfillment", "reschedule"].contains(row.kind))
                let action = element("booking.\(row.kind).\(try XCTUnwrap(row.action))")
                if let timeout = row.waitForActionSeconds {
                    XCTAssertLessThanOrEqual(timeout, 180)
                    // The actual service clock remains authoritative; never advance it for the test.
                    XCTAssertTrue(action.waitForExistence(timeout: timeout))
                }
                reveal(action)
                tap(action)
                if let stamp = row.proposedStart {
                    selectDay(try localDate(stamp), field: app, dismissLabel: "Proposed Start")
                    selectTime(try localDate(stamp), field: app, dismissLabel: "Proposed Start")
                }
                let confirm = element("booking.\(row.kind).confirm")
                reveal(confirm)
                XCTAssertTrue(confirm.isEnabled)
                evidence("\(row.id) \(row.kind) ready")
                tap(confirm)
                XCTAssertTrue(confirm.waitForNonExistence(timeout: 30))
            }
            assertVisibleText(row.expectedText, within: element("bookings.detail"))
            evidence("\(row.id) \(row.kind) result visible")
            if row.backgroundAndRestart == true {
                XCUIDevice.shared.press(.home)
                XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5)
                    || app.state == .runningBackgroundSuspended)
                app.activate()
                assertVisibleText(row.expectedText, within: element("bookings.detail"))
                app.terminate()
                app.launch()
                try openDetail()
                XCTAssertTrue(element("bookings.detail").waitForExistence(timeout: 15))
                assertVisibleText(row.expectedText, within: element("bookings.detail"))
                if let expected = row.expectedReviewForm {
                    XCTAssertEqual(element("bookings.review.submit").exists, expected)
                }
                evidence("\(row.id) authoritative detail after background and restart")
            }
            if index + 1 < input.rows.count && input.rows[index + 1].sameDetail != true {
                tap(app.navigationBars.buttons.firstMatch)
            }
        }
    }

    private func assertBookingDetails(_ row: ScheduledBooking, within detail: XCUIElement) throws {
        let start = try localDate(row.start), end = try localDate(row.end)
        for text in ["Confirmed", row.serviceTitle, row.price,
                     formatter("EEE, MMM d").string(from: start),
                     "\(formatter("h:mm a").string(from: start)) - \(formatter("h:mm a").string(from: end))"] {
            assertVisibleText(text, within: detail)
        }
    }
}
