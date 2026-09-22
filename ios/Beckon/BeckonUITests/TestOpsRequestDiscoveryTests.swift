import XCTest

@MainActor
final class TestOpsRequestDiscoveryTests: XCTestCase {
    private let app = XCUIApplication()
    private struct Input: Decodable {
        let runID: String
        let petName: String
        let groomerID: String
        let poolGroomerID: String
        let marker: String
        let action: String?
        let role: String?
        let requestID: String?
        let expectedSource: String?
        let customerID: String?
        let bookingStart: String?
        let presentationGroomerID: String?
        let presentationName: String?
        let olderHistoryRequestID: String?
    }

    func testInvitationAndPoolLifecycle() throws {
        let fixture = try input()
        let driver = TestOpsUIFlowDriver()
        let role = try XCTUnwrap(TestOpsSeedRole(rawValue: fixture.role ?? "customer"))
        let recovery = fixture.action == "publishRecovery"
        var arguments = ["--beckon-testops-record-http"]
        if recovery { arguments += ["--beckon-testops-discovery-drop-receipt",
            "--beckon-testops-discovery-customer", try XCTUnwrap(fixture.customerID)] }
        if fixture.action == "browseEdgeCases" {
            arguments += ["--beckon-testops-discovery-fail-read", "--beckon-testops-discovery-customer",
                try XCTUnwrap(fixture.customerID), "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        if fixture.action == "browseLargeText" {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        driver.launchSignedOut(additionalArguments: arguments)
        driver.signIn(try TestOpsSeedAccount.fromEnvironment(role: role))
        switch fixture.action {
        case "browseLargeText":
            openCustomerRequest(try XCTUnwrap(fixture.requestID))
            tap(element("customer.requests.invite"))
            XCTAssertTrue(element("discovery.page-position").waitForExistence(timeout: 20))
            evidence("Compact maximum text candidate summary uses full-width stacking")
            tap(element("discovery.show-all"))
            let send = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.send.'")).firstMatch
            XCTAssertTrue(send.waitForExistence(timeout: 15))
            let groomerID = String(send.identifier.dropFirst("discovery.send.".count))
            tap(send)
            XCTAssertTrue(wait { !self.element("discovery.send.\(groomerID)").exists })
            tap(app.buttons["BackButton"].firstMatch)
            XCTAssertTrue(element("discovery.withdraw.\(groomerID)").waitForExistence(timeout: 15))
            evidence("Compact maximum text explicit list invitation reached the same request")
        case "resumePending":
            tap(element("customer.home.start-request"))
            XCTAssertTrue(element("customer.requests.publication-recovery").waitForExistence(timeout: 10))
            tap(element("customer.requests.publish"))
            XCTAssertTrue(wait(timeout: 30) { !self.element("customer.requests.wizard").exists })
            openCustomerRequest(try XCTUnwrap(fixture.requestID))
            XCTAssertTrue(element("discovery.pool").waitForExistence(timeout: 15))
            XCTAssertTrue(element("discovery.withdraw.\(fixture.groomerID)").exists)
            evidence("Restart recovered the original committed request and invitation without republishing")
        case "legacyRecovery":
            tap(element("customer.home.start-request"))
            XCTAssertTrue(element("customer.requests.publication-recovery").waitForExistence(timeout: 10))
            tap(element("customer.requests.publish"))
            XCTAssertTrue(wait(timeout: 30) { !self.element("customer.requests.wizard").exists })
            tap(element("customer.tab.requests"))
            tap(element("customer.requests.history"))
            tap(element("customer.requests.history.row.\(try XCTUnwrap(fixture.requestID).prefix(8).uppercased())"))
            XCTAssertTrue(element("customer.requests.republish").waitForExistence(timeout: 15))
            evidence("Unversioned legacy publication recovered its cancelled original without republishing")
        case "browseEdgeCases":
            preparePreview(fixture)
            let position = element("discovery.page-position")
            XCTAssertEqual(position.label, "1 of 8")
            tap(element("discovery.reload"))
            XCTAssertTrue(element("discovery.refresh").waitForExistence(timeout: 5))
            XCTAssertEqual(position.label, "1 of 8")
            XCTAssertFalse(app.staticTexts["No Groomers Available"].exists)
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.profile.'")).firstMatch.exists)
            evidence("Large text retains candidates beside a failed refresh")
            tap(element("discovery.refresh"))
            XCTAssertTrue(wait { !self.element("discovery.refresh").exists })
            for index in 2...8 {
                app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.profile.'")).firstMatch.swipeLeft()
                XCTAssertTrue(wait { position.label == "\(index) of 8" })
            }
            let lastID = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.profile.'")).firstMatch.identifier
            app.buttons.matching(NSPredicate(format: "identifier == %@", lastID)).firstMatch.swipeLeft()
            tap(app.buttons["Show All Groomers"].firstMatch)
            XCTAssertTrue(element("customer.discovery.list").waitForExistence(timeout: 10))
            tap(app.buttons["BackButton"].firstMatch)
            XCTAssertEqual(position.label, "8 of 8")
            XCTAssertTrue(element(lastID).exists)
            tap(element("discovery.favorites"))
            let target = try XCTUnwrap(fixture.presentationGroomerID)
            XCTAssertTrue(app.staticTexts[try XCTUnwrap(fixture.presentationName)].firstMatch.waitForExistence(timeout: 15))
            let send = element("favorites.send.\(target)")
            tap(send)
            XCTAssertTrue(app.alerts["Send this request?"].waitForExistence(timeout: 5))
            tap(app.buttons["Cancel"].firstMatch)
            XCTAssertTrue(element("favorites.remove.\(target)").exists)
            XCTAssertFalse(element("customer.request.progress").exists)
            evidence("Compact large-text explicit send and cancellation after network recovery")
        case "savedPausedAndSwitch":
            tap(element("customer.tab.account"))
            tap(element("account.saved-groomers"))
            let target = try XCTUnwrap(fixture.presentationGroomerID)
            XCTAssertTrue(element("favorites.remove.\(target)").waitForExistence(timeout: 15))
            XCTAssertTrue(app.staticTexts["Groomer temporarily unavailable"].exists)
            XCTAssertFalse(app.staticTexts[try XCTUnwrap(fixture.presentationName)].exists)
            XCTAssertTrue(wait(timeout: 20) { self.element("favorites.choose-request").isEnabled })
            tap(element("favorites.choose-request"))
            XCTAssertTrue(app.buttons["No Request Selected"].firstMatch.waitForExistence(timeout: 5))
            tap(element("favorites.request.\(try XCTUnwrap(fixture.requestID).uppercased())"))
            XCTAssertTrue(app.staticTexts["Unavailable for this request"].firstMatch.waitForExistence(timeout: 15))
            XCTAssertFalse(element("favorites.send.\(target)").exists)
            evidence("Paused favorite retained without identity or send permission")
            tap(app.buttons["BackButton"].firstMatch)
            tap(element("auth.sign-out"))
            driver.assertAuthenticationRoot()
            let env = ProcessInfo.processInfo.environment
            let email = try XCTUnwrap(env["TEST_RUNNER_T399_OTHER_EMAIL"] ?? env["T399_OTHER_EMAIL"])
            let password = try XCTUnwrap(env["TEST_RUNNER_T399_OTHER_PASSWORD"] ?? env["T399_OTHER_PASSWORD"])
            driver.signIn(.init(role: .customer, email: email, password: password))
            tap(element("customer.tab.account"))
            tap(element("account.saved-groomers"))
            XCTAssertTrue(app.staticTexts["No Saved Groomers"].waitForExistence(timeout: 15))
            XCTAssertFalse(element("favorites.remove.\(target)").exists)
            XCTAssertFalse(element("customer.discovery").exists)
            evidence("Account switch cleared previous favorites and discovery identity")
        case "publishMixed", "publishDirected", "publishPool", "publishRecovery":
            preparePreview(fixture)
            if fixture.action != "publishDirected" { tap(element("discovery.pool-consent")) }
            if fixture.action == "publishPool" {
                tap(element("discovery.publish-pool"))
            } else {
                tap(element("discovery.show-all"))
                tap(element("discovery.send.\(fixture.groomerID)"))
            }
            let confirm = app.buttons["Confirm Send"].firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@",
                fixture.action == "publishDirected" ? "Request pool: off" : "Request pool: on")).firstMatch.exists)
            confirm.tap()
            if recovery {
                XCTAssertTrue(wait { !confirm.exists })
                tap(app.buttons["BackButton"].firstMatch)
                XCTAssertTrue(element("discovery.retry-publication").waitForExistence(timeout: 15))
                app.terminate()
                app.launchArguments.removeAll { $0 == "--beckon-testops-clear-session" || $0 == "--beckon-testops-discovery-drop-receipt" }
                app.launch()
                XCTAssertTrue(element("customer.tabs").waitForExistence(timeout: 20))
                tap(element("customer.home.start-request"))
                XCTAssertTrue(element("customer.requests.publication-recovery").waitForExistence(timeout: 10))
                tap(element("customer.requests.publish"))
                XCTAssertTrue(wait(timeout: 30) { !self.element("customer.requests.wizard").exists })
                evidence("Committed request recovered after dropped receipt and process restart")
                return
            }
            if fixture.action != "publishPool" {
                XCTAssertTrue(wait { !confirm.exists })
                tap(app.buttons["BackButton"].firstMatch)
            }
            XCTAssertTrue(element("customer.request.progress").waitForExistence(timeout: 20))
            XCTAssertEqual(element("discovery.pool").value as? String, fixture.action == "publishDirected" ? "0" : "1")
            XCTAssertFalse(element("discovery.pool-consent").exists)
            evidence("Published \(fixture.action!) through client")
        case "verifyMixed":
            openCustomerRequest(try XCTUnwrap(fixture.requestID))
            XCTAssertTrue(element("discovery.pool").waitForExistence(timeout: 15))
            XCTAssertEqual(element("discovery.pool").value as? String, "1")
            XCTAssertTrue(element("discovery.withdraw.\(fixture.groomerID)").exists)
            evidence("Previously published mixed request restored with separate accessible controls")
        case "quote":
            let reference = String(try XCTUnwrap(fixture.requestID).prefix(8)).uppercased()
            tap(element("groomer.tab.requests"))
            tap(element("groomer.requests.segment.matches"))
            let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'groomer.requests.row' AND value == %@", reference))
            XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20))
            XCTAssertEqual(rows.count, 1)
            tap(rows.firstMatch)
            XCTAssertTrue(element("groomer.requests.source").waitForExistence(timeout: 15))
            XCTAssertEqual(element("groomer.requests.source").label, fixture.expectedSource)
            fill("groomer.offers.price", value: "105")
            fill("groomer.offers.message", value: fixture.marker)
            tap(element("groomer.offers.submit"))
            XCTAssertTrue(element("groomer.offers.withdraw").waitForExistence(timeout: 25))
            if fixture.expectedSource == "Invited + Request Pool" {
                tap(element("groomer.offers.withdraw"))
                XCTAssertTrue(wait { !self.element("groomer.offers.withdraw").exists })
                fill("groomer.offers.price", value: "100")
                fill("groomer.offers.message", value: fixture.marker)
                tap(element("groomer.offers.submit"))
                XCTAssertTrue(element("groomer.offers.withdraw").waitForExistence(timeout: 25))
            }
            evidence("Authorized \(fixture.expectedSource ?? "") quote")
        case "append":
            openCustomerRequest(try XCTUnwrap(fixture.requestID))
            tap(element("customer.requests.invite"))
            tap(element("discovery.show-all"))
            let send = element("discovery.send.\(fixture.poolGroomerID)")
            tap(send)
            XCTAssertTrue(wait { !send.exists })
            tap(app.buttons["BackButton"].firstMatch)
            let withdraw = element("discovery.withdraw.\(fixture.poolGroomerID)")
            tap(withdraw)
            XCTAssertTrue(wait { !withdraw.exists })
            evidence("Additional directed invitation sent and explicitly withdrawn")
        case "revise", "withdrawForPool":
            openCustomerRequest(try XCTUnwrap(fixture.requestID))
            let remainingInvitation = element("discovery.withdraw.\(fixture.groomerID)")
            tap(remainingInvitation)
            XCTAssertTrue(wait { !remainingInvitation.exists })
            if fixture.action == "withdrawForPool" {
                XCTAssertEqual(element("discovery.pool").value as? String, "1")
                evidence("Directed invitation withdrawn while explicit pool consent remains on")
                return
            }
            XCTAssertTrue(app.staticTexts["No Available Offers"].waitForExistence(timeout: 10))
            XCTAssertTrue(element("customer.requests.invite").exists)
            XCTAssertEqual(element("discovery.pool").value as? String, "0")
            evidence("All invitations ended while invite and optional pool recovery remain available")
            tap(element("customer.requests.revise"))
            completeTimeAndReview(fixture)
            XCTAssertEqual(element("discovery.pool-consent").value as? String, "0")
            tap(element("discovery.show-all"))
            tap(element("discovery.send.\(fixture.groomerID)"))
            tap(app.buttons["Confirm Send"].firstMatch)
            XCTAssertTrue(wait { !self.app.buttons["Confirm Send"].exists })
            tap(app.buttons["BackButton"].firstMatch)
            XCTAssertTrue(element("customer.request.progress").waitForExistence(timeout: 20))
            evidence("Atomic revision explicitly chose its new recipient with pool off")
        case "cancelDuringRollback", "verifyCancelledHistory":
            tap(element("customer.tab.requests"))
            let reference = String(try XCTUnwrap(fixture.requestID).prefix(8)).uppercased()
            if fixture.action == "cancelDuringRollback" {
            let cancel = app.buttons.matching(NSPredicate(
                format: "label == 'Cancel Request' AND value == %@", reference)).firstMatch
            for _ in 0..<4 {
                if cancel.exists && cancel.isHittable { break }
                app.swipeLeft()
            }
            tap(cancel)
            let confirmation = app.alerts["Cancel this request?"]
            XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
            tap(confirmation.buttons["Cancel Request"])
            XCTAssertTrue(confirmation.waitForNonExistence(timeout: 10))
            XCTAssertTrue(wait(timeout: 20) { !cancel.exists || !cancel.isEnabled })
            evidence("Customer cancellation completed with discovery disabled")
            }
            tap(element("customer.requests.history"))
            tap(element("customer.requests.history.row.\(reference)"))
            XCTAssertTrue(element("customer.requests.republish").waitForExistence(timeout: 15))
            XCTAssertFalse(element("customer.requests.invite").exists)
            evidence("Feature-disabled cancelled request remained navigable in history")
        case "refreshCadence", "refreshCadenceWithImage":
            openCustomerRequest(try XCTUnwrap(fixture.requestID))
            let checked = element("discovery.checked-at")
            XCTAssertTrue(checked.waitForExistence(timeout: 15))
            let first = try XCTUnwrap(checked.value as? String)
            print("T399 UI foreground-start \(Date().timeIntervalSince1970)")
            XCTAssertTrue(wait(timeout: 65) { checked.value as? String != first })
            print("T399 UI foreground-refreshed \(Date().timeIntervalSince1970)")
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(app.wait(for: .runningBackgroundSuspended, timeout: 10) || app.state == .runningBackground)
            print("T399 UI background-start \(Date().timeIntervalSince1970)")
            let background = Date()
            XCTAssertTrue(wait(timeout: 60) { Date().timeIntervalSince(background) >= 50 })
            print("T399 UI background-end \(Date().timeIntervalSince1970)")
            app.activate()
            XCTAssertTrue(checked.waitForExistence(timeout: 15))
            XCTAssertTrue(wait { (checked.value as? String).flatMap { try? Date.ISO8601FormatStyle().parse($0) }.map { $0 > background } == true })
            evidence("Foreground interval, background suspension and re-entry refresh")
        case "closePool":
            openCustomerRequest(try XCTUnwrap(fixture.requestID))
            XCTAssertTrue(element("discovery.pool").waitForExistence(timeout: 15))
            XCTAssertEqual(element("discovery.pool").value as? String, "1")
            let poolSwitch = app.switches.matching(NSPredicate(format: "identifier == 'discovery.pool'")).firstMatch
            XCTAssertTrue(poolSwitch.isHittable)
            poolSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            XCTAssertTrue(wait { self.element("discovery.pool").value as? String == "0" })
            XCTAssertEqual(element("discovery.valid-offer-count").label, "2 valid offers")
            evidence("Pool closed, both valid offers retained")
        case "accept":
            let reference = String(try XCTUnwrap(fixture.requestID).prefix(8)).uppercased()
            tap(element("customer.tab.requests"))
            tap(app.buttons.matching(NSPredicate(format: "identifier == 'customer.requests.offers' AND value == %@", reference)).firstMatch)
            tap(element("customer.offers.row.\(fixture.runID)"))
            tap(element("customer.offers.accept"))
            XCTAssertTrue(element("customer.offers.confirmation").waitForExistence(timeout: 15))
            tap(app.buttons.matching(NSPredicate(format:
                "identifier == 'customer.offers.confirm' OR label == 'Confirm & Book'")).firstMatch)
            XCTAssertTrue(element("bookings.detail").waitForExistence(timeout: 25))
            evidence("One booking accepted through client")
            app.terminate()
            app.launchArguments.removeAll { $0 == "--beckon-testops-clear-session" }
            app.launch()
            XCTAssertTrue(element("customer.tabs").waitForExistence(timeout: 20))
            tap(element("customer.tab.bookings"))
            tap(element("bookings.row.request.\(reference)"))
            XCTAssertTrue(element("bookings.detail").waitForExistence(timeout: 20))
            evidence("Customer restarted into the same accepted booking")
        case "verifyBooking":
            let reference = String(try XCTUnwrap(fixture.requestID).prefix(8)).uppercased()
            tap(element(role == .customer ? "customer.tab.bookings" : "groomer.tab.bookings"))
            if role == .groomer {
                let day = try Date.ISO8601FormatStyle().parse(try XCTUnwrap(fixture.bookingStart))
                let picker = app.buttons["Date Picker"].firstMatch
                tap(picker)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
                formatter.dateFormat = "EEEE, MMMM d"
                let label = formatter.string(from: day)
                tap(app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", label, "Today, \(label)")).firstMatch)
                tap(app.staticTexts["Appointment Date"].firstMatch)
            }
            tap(element("\(role == .customer ? "bookings" : "groomer.booking").row.request.\(reference)"))
            XCTAssertTrue(element("bookings.detail").waitForExistence(timeout: 20))
            evidence("\(role.rawValue) restarted into the same booking")
        default: XCTFail("Unsupported lifecycle action")
        }
    }

    func testRecoveryAndExpiredHistory() throws {
        let fixture = try input()
        let driver = TestOpsUIFlowDriver()
        driver.launchSignedOut()
        driver.signIn(try TestOpsSeedAccount.fromEnvironment(role: .customer))
        let requestID = try XCTUnwrap(fixture.requestID)
        openCustomerRequest(requestID)
        XCTAssertTrue(element("discovery.pool").waitForExistence(timeout: 15))
        XCTAssertTrue(wait(timeout: 150) { !self.element("discovery.pool").exists })
        XCTAssertFalse(element("customer.requests.invite").exists)
        tap(app.buttons["BackButton"].firstMatch)
        tap(element("customer.requests.history"))
        tap(element("customer.requests.history.row.\(requestID.prefix(8).uppercased())"))
        tap(element("customer.requests.republish"))
        completeTimeAndReview(fixture)
        XCTAssertEqual(element("discovery.pool-consent").value as? String, "0")
        tap(element("discovery.pool-consent"))
        tap(element("discovery.publish-pool"))
        tap(app.buttons["Confirm Send"].firstMatch)
        XCTAssertTrue(element("customer.request.progress").waitForExistence(timeout: 20))
        evidence("Natural expiry, history template and explicit pool-only republication")
        tap(app.buttons["Done"].firstMatch)
        tap(element("customer.tab.requests"))
        tap(element("customer.requests.history"))
        let older = try XCTUnwrap(fixture.olderHistoryRequestID)
        tap(element("customer.requests.history.row.\(older.prefix(8).uppercased())"))
        tap(element("customer.requests.republish"))
        XCTAssertTrue(element("customer.requests.wizard").waitForExistence(timeout: 10))
        evidence("Older closed request beyond the first three opened its reusable template")
    }

    private func openCustomerRequest(_ requestID: String) {
        tap(element("customer.tab.requests"))
        XCTAssertTrue(element("customer.requests.list").waitForExistence(timeout: 20))
        let reference = String(requestID.prefix(8)).uppercased()
        let detail = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'customer.requests.detail' AND value == %@", reference)).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 20))
        tap(detail)
        XCTAssertTrue(element("customer.requests.detail").waitForExistence(timeout: 15))
    }

    private func fill(_ identifier: String, value: String) {
        let field = app.textFields.matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
        tap(field)
        field.typeKey("a", modifierFlags: .command)
        field.typeText(value)
        if app.keyboards.firstMatch.exists {
            let done = app.buttons.matching(NSPredicate(format: "identifier == 'beckon.keyboard.done' OR label == 'Done'")).firstMatch
            XCTAssertTrue(done.waitForExistence(timeout: 3))
            done.tap()
            XCTAssertTrue(wait { !self.app.keyboards.firstMatch.exists })
        }
    }

    private func input() throws -> Input {
        let env = ProcessInfo.processInfo.environment
        guard (env["TESTOPS_REMOTE_WRITE_APPROVED"] ?? env["TEST_RUNNER_TESTOPS_REMOTE_WRITE_APPROVED"]) == "1",
              let encoded = env["T399_UI_INPUT"] ?? env["TEST_RUNNER_T399_UI_INPUT"], let data = Data(base64Encoded: encoded) else {
            throw XCTSkip("Authorized T-399 client fixture required")
        }
        let value = try JSONDecoder().decode(Input.self, from: data)
        XCTAssertTrue(value.runID.hasPrefix("TESTOPS-T399-"))
        XCTAssertEqual(value.marker, "TESTOPS:" + value.runID)
        continueAfterFailure = false
        return value
    }

    nonisolated override func record(_ issue: XCTIssue) {
        var recorded = issue
        recorded.sourceCodeContext = XCTSourceCodeContext(callStack: [], location: issue.sourceCodeContext.location)
        super.record(recorded)
    }

    func testPrivatePreviewAndFavorites() throws {
        let fixture = try input()
        let driver = TestOpsUIFlowDriver()
        driver.launchSignedOut()
        driver.signIn(try TestOpsSeedAccount.fromEnvironment(role: .customer))
        preparePreview(fixture)
        XCTAssertEqual(element("discovery.pool-consent").value as? String, "0")
        XCTAssertEqual(element("discovery.page-position").label, "1 of 8")
        let position = element("discovery.page-position")
        let profile = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.profile.'")).firstMatch
        profile.swipeLeft()
        XCTAssertTrue(wait { position.label == "2 of 8" })
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.profile.'")).firstMatch.swipeRight()
        XCTAssertTrue(wait { position.label == "1 of 8" })
        tap(element("discovery.show-all"))
        XCTAssertTrue(element("customer.discovery.list").waitForExistence(timeout: 5))
        let favorite = element("discovery.favorite.\(fixture.groomerID)")
        if !favorite.exists {
            tap(element("discovery.load-more"))
        }
        if favorite.label != "Remove favorite" { tap(favorite) }
        XCTAssertTrue(wait { favorite.label == "Remove favorite" })
        let send = element("discovery.send.\(fixture.groomerID)")
        tap(send)
        XCTAssertTrue(app.buttons["Confirm Send"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Request pool: off'" )).firstMatch.exists)
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertFalse(element("customer.request.progress").exists)
        evidence("Private preview, reversible cards, full list and cancelled send")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--beckon-testops-clear-session" }
        app.launch()
        XCTAssertTrue(element("customer.tabs").waitForExistence(timeout: 15))
        tap(element("customer.tab.account"))
        tap(element("account.saved-groomers"))
        let remove = element("favorites.remove.\(fixture.groomerID)")
        XCTAssertTrue(remove.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'favorites.send.'")).firstMatch.exists)
        evidence("Favorite restored after process restart without a request")
        tap(remove)
        XCTAssertTrue(wait { !remove.exists })
    }

    private func preparePreview(_ fixture: Input) {
        tap(element("customer.home.start-request"))
        let pet = app.buttons.matching(identifier: "customer.requests.wizard.pet.dog")
            .matching(NSPredicate(format: "label BEGINSWITH %@", fixture.petName + ",")).firstMatch
        tap(pet)
        tap(element("customer.requests.wizard.continue"))
        tap(element("customer.requests.wizard.service.full_groom"))
        tap(element("customer.requests.wizard.continue"))
        completeTimeAndReview(fixture)
    }

    private func completeTimeAndReview(_ fixture: Input) {
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'My Home,'")).firstMatch)
        tap(element("customer.requests.use-profile-address"))
        XCTAssertTrue(wait { self.element("beckon.address.line1").exists
            && self.element("beckon.address.line1").value as? String == "399 TestOps Synthetic Way" })
        tap(app.buttons[fixture.action == "revise" ? "Evening" : "Afternoon"].firstMatch)
        tap(element("customer.requests.wizard.continue"))
        let notes = element("customer.requests.wizard.notes")
        tap(notes)
        notes.typeKey("a", modifierFlags: .command)
        notes.typeText(fixture.marker)
        tap(app.buttons["beckon.keyboard.done"].firstMatch)
        tap(element("customer.requests.wizard.continue"))
        tap(element("customer.requests.publish"))
        XCTAssertTrue(element("customer.discovery").waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.profile.'")).firstMatch.waitForExistence(timeout: 20))
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }

    private func tap(_ item: XCUIElement) {
        _ = item.waitForExistence(timeout: 3)
        for _ in 0..<10 {
            if item.exists && item.isHittable { break }
            app.swipeUp()
        }
        if !item.exists || !item.isHittable {
            for _ in 0..<10 {
                if item.exists && item.isHittable { break }
                app.swipeDown()
            }
        }
        XCTAssertTrue(item.waitForExistence(timeout: 5) && item.isHittable, "Required control is not reachable: \(item)")
        item.tap()
    }

    private func wait(timeout: TimeInterval = 15, _ predicate: @escaping () -> Bool) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in predicate() }, object: nil)], timeout: timeout) == .completed
    }

    private func evidence(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
        print("T399 UI \(name)")
    }
}
