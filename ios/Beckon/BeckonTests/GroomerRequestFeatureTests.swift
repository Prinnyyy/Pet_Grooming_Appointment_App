import Foundation
import Testing
import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class GroomerOfferTimingRenderingTests: XCTestCase {
    func testReturningWhileCancelledInitializationIsPendingStartsFreshRead() async throws {
        let owner = UUID()
        let base = GroomerRequestsStoreTests.matchedRequest(groomerID: owner)
        var request = base.request
        request.preferenceTimeZoneIdentifier = "America/New_York"
        let matched = GroomerMatchedRequest(match: base.match, request: request, offer: nil)
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .success([matched]))
        let profiles = GroomerProfileRepositoryFake()
        var pending: CheckedContinuation<Void, Never>?
        var firstReadWasCancelled = false
        profiles.onServicesRead = {
            if profiles.servicesReadCount == 1 {
                await withCheckedContinuation { pending = $0 }
                firstReadWasCancelled = Task.isCancelled
            }
        }
        defer { pending?.resume(); profiles.onServicesRead = nil }
        let store = GroomerRequestsStore(groomerID: owner, repository: repository, profileRepository: profiles)
        await store.load()
        let navigation = OfferInitializationNavigation()
        let host = UIHostingController(rootView: NavigationStack(path: Binding(
            get: { navigation.path }, set: { navigation.path = $0 }
        )) {
            GroomerRequestDetailView(matchID: matched.id, store: store)
                .navigationDestination(for: Int.self) { _ in Text("Temporary destination") }
        })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        for _ in 0..<30 where profiles.servicesReadCount == 0 {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(profiles.servicesReadCount, 1)
        navigation.path = [1]
        try await Task.sleep(for: .seconds(1))
        navigation.path = []
        for _ in 0..<30 where profiles.servicesReadCount < 2 {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(profiles.servicesReadCount, 2)
        func descendants<T: UIView>(_ view: UIView, of type: T.Type) -> [T] {
            (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, of: type) }
        }
        let scroll = try XCTUnwrap(descendants(host.view, of: UIScrollView.self)
            .first { $0.contentSize.height > $0.bounds.height })
        for _ in 0..<6 {
            scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height
                - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
            try await Task.sleep(for: .milliseconds(150))
        }
        let fields = descendants(host.view, of: UITextField.self)
        let duration = try XCTUnwrap(fields.first { $0.placeholder == "Duration (minutes)" })
        let price = try XCTUnwrap(fields.first { $0.placeholder == "Price Estimate" })
        duration.text = "45"
        duration.sendActions(for: .editingChanged)
        price.text = "127"
        price.sendActions(for: .editingChanged)
        let picker = try XCTUnwrap(descendants(host.view, of: UIDatePicker.self).first)
        let startBeforeLateRead = picker.date
        pending?.resume()
        pending = nil
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(firstReadWasCancelled)
        XCTAssertEqual(picker.date, startBeforeLateRead)
        XCTAssertEqual(duration.text, "45")
        XCTAssertEqual(price.text, "127")
        XCTAssertEqual(repository.createOfferCallCount, 0)
    }

    func testMobileOfferRendersConfirmedZone() async throws {
        try await renderMobileOffer(referenceZone: "America/New_York")
    }

    func testPendingMatchRendersWithoutOfferInputs() async throws {
        try await renderMobileOffer(referenceZone: "America/New_York", matchingState: "pending")
    }

    func testAssessmentMatchRetainsExplicitOfferInputs() async throws {
        try await renderMobileOffer(referenceZone: "America/New_York", matchingState: "assessment_required")
    }

    func testCompactOfferRetainsDraftAcrossDeviceEnvironmentChange() async throws {
        try await renderMobileOffer(referenceZone: "America/New_York", environmentChange: true)
    }

    func testMobileOfferWithoutConfirmedZoneDoesNotExposeDateInput() async throws {
        try await renderMobileOffer(referenceZone: nil)
    }

    func testDestinationLookupFailureRetainsDraftAndCanRetry() async throws {
        try await renderMobileOffer(referenceZone: "America/New_York", destinationFailure: true)
    }

    private func renderMobileOffer(referenceZone: String?, destinationFailure: Bool = false,
        environmentChange: Bool = false, matchingState: String? = nil) async throws {
        let owner = UUID()
        // Opt-in local simulator interaction; absent during unattended regression.
        let interactionFile = "/tmp/beckon-t374-offer-interaction.txt"
        let expectedInteractiveStart = try? String(contentsOfFile: interactionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let start = expectedInteractiveStart == nil ? Date().addingTimeInterval(86400)
            : try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T05:00:00Z"))
        let base = GroomerRequestsStoreTests.matchedRequest(groomerID: owner,
            locationMode: destinationFailure ? .customerComesToGroomer : .groomerComesToCustomer,
            preferredStart: GroomingRequestDateFormatting.serverString(from: start),
            preferredEnd: GroomingRequestDateFormatting.serverString(from: start.addingTimeInterval(10800)),
            matchReason: matchingState == nil ? "same_city" : (matchingState == "pending"
                ? "Service and availability are being checked." : "Service details need assessment."))
        var request = base.request
        request.preferenceTimeZoneIdentifier = referenceZone
        var match = base.match
        if let matchingState {
            match.eligibilityEvaluation = MatchEligibilityEvaluation(state: matchingState,
                reason: "runtime_fixture", serviceStart: nil, serviceEnd: nil)
        }
        let matched = GroomerMatchedRequest(match: match, request: request, offer: nil)
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .success([matched]))
        let profiles = GroomerProfileRepositoryFake()
        if destinationFailure { profiles.profileResult = .failure(.networkUnavailable) }
        let store = GroomerRequestsStore(groomerID: owner, repository: repository,
            profileRepository: profiles)
        await store.load()
        let environment = OfferDeviceEnvironment()
        let host = UIHostingController(rootView: OfferEnvironmentHost(matchID: matched.id,
            store: store, device: environment))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        if environmentChange { window.frame = CGRect(x: 0, y: 0, width: 375, height: 667) }
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        func scrollViews(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews($0) }
        }
        let scroll = try XCTUnwrap(scrollViews(host.view).first { $0.contentSize.height > $0.bounds.height })
        // Lazy content expands as it enters the viewport; settle at the actual bottom.
        for _ in 0..<6 {
            let bottom = max(0, scroll.contentSize.height - scroll.bounds.height
                + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
            try await Task.sleep(for: .milliseconds(150))
            if abs(scroll.contentOffset.y - max(0, scroll.contentSize.height - scroll.bounds.height
                + scroll.adjustedContentInset.bottom)) < 1 { break }
        }
        XCTAssertGreaterThan(scroll.contentOffset.y, 0)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = matchingState.map { "T-375 matching \($0)" } ?? (destinationFailure ? "T-374 destination lookup failure"
            : (referenceZone == nil ? "T-374 mobile offer unknown zone" : "T-374 mobile offer real form")
        )
        attachment.lifetime = .keepAlways
        add(attachment)
        let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data) as Data
        XCTAssertGreaterThan(Set(stride(from: 0, to: pixels.count, by: 4).map { pixels[$0] }).count, 8)
        func datePickers(_ view: UIView) -> [UIDatePicker] {
            (view as? UIDatePicker).map { [$0] } ?? view.subviews.flatMap { datePickers($0) }
        }
        func textFields(_ view: UIView) -> [UITextField] {
            (view as? UITextField).map { [$0] } ?? view.subviews.flatMap { textFields($0) }
        }
        if referenceZone == nil || matchingState == "pending" {
            XCTAssertTrue(datePickers(host.view).isEmpty)
            if matchingState == "pending" {
                XCTAssertFalse(textFields(host.view).contains { $0.placeholder == "Duration (minutes)" || $0.placeholder == "Price Estimate" })
            }
            XCTAssertEqual(repository.createOfferCallCount, 0)
            return
        }
        let duration = try XCTUnwrap(textFields(host.view).first { $0.placeholder == "Duration (minutes)" })
        duration.text = "60"
        duration.sendActions(for: .editingChanged)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(duration.text, "60")
        if destinationFailure {
            XCTAssertTrue(datePickers(host.view).isEmpty)
            if FileManager.default.fileExists(atPath: "/tmp/beckon-t374-destination-retry") {
                let price = try XCTUnwrap(textFields(host.view).first { $0.placeholder == "Price Estimate" })
                price.text = "127"
                price.sendActions(for: .editingChanged)
                let input = BeckonAddressInput(line1: "123 Test Street", line2: "", city: "Anaheim",
                    stateCode: nil, postalCode: "92805", countryCode: "US")
                let address = BeckonConfirmedAddress(entered: input, accepted: input, provider: "apple_maps",
                    placeID: nil, coordinate: BeckonAddressCoordinate(latitude: 33.83, longitude: -117.92),
                    resolutionSource: "manual_geocode", confirmedAt: Date(), timeZoneIdentifier: "America/Los_Angeles")
                profiles.profileResult = .success(GroomerProfile(userID: owner, businessName: nil, bio: nil,
                    yearsExperience: nil, baseCity: "Anaheim", baseState: "CA", serviceRadiusMiles: nil,
                    serviceLocationMode: nil, ratingAverage: 0, ratingCount: 0, isActive: true,
                    isVerified: true, confirmedAddress: address))
                for _ in 0..<180 where datePickers(host.view).isEmpty {
                    try await Task.sleep(for: .seconds(1))
                }
                let recovered = try XCTUnwrap(datePickers(host.view).first)
                XCTAssertEqual(recovered.date, try GroomingServiceTiming.wallInput(for: start,
                    timeZoneIdentifier: "America/Los_Angeles"))
                XCTAssertEqual(duration.text, "60")
                XCTAssertEqual(price.text, "127")
                let recoveredImage = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let recoveredAttachment = XCTAttachment(image: recoveredImage)
                recoveredAttachment.name = "T-374 destination retry recovered draft"
                recoveredAttachment.lifetime = .keepAlways
                add(recoveredAttachment)
            }
            XCTAssertEqual(repository.createOfferCallCount, 0)
            return
        }
        let edited = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let editedAttachment = XCTAttachment(image: edited)
        editedAttachment.name = "T-374 mobile offer duration edited"
        editedAttachment.lifetime = .keepAlways
        add(editedAttachment)
        let picker = try XCTUnwrap(datePickers(host.view).first)
        let repeatedWallTime = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-01T01:30:00Z"))
        picker.setDate(repeatedWallTime, animated: false)
        picker.sendActions(for: .valueChanged)
        try await Task.sleep(for: .milliseconds(300))
        if environmentChange {
            environment.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
            environment.calendar = Calendar(identifier: .buddhist)
            environment.textSize = .accessibility1
            try await Task.sleep(for: .milliseconds(500))
            let changedPicker = try XCTUnwrap(datePickers(host.view).first)
            XCTAssertEqual(changedPicker.calendar.identifier, .gregorian)
            XCTAssertEqual(changedPicker.timeZone?.secondsFromGMT(), 0)
            XCTAssertEqual(changedPicker.date, repeatedWallTime)
            XCTAssertEqual(duration.text, "60")
            duration.becomeFirstResponder()
            try await Task.sleep(for: .milliseconds(500))
            let keyboardImage = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let keyboardAttachment = XCTAttachment(image: keyboardImage)
            keyboardAttachment.name = "T-374 compact large-text keyboard after device environment change"
            keyboardAttachment.lifetime = .keepAlways
            add(keyboardAttachment)
            duration.resignFirstResponder()
        }
        let repeated = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let repeatedAttachment = XCTAttachment(image: repeated)
        repeatedAttachment.name = "T-374 mobile offer repeated hour unchosen"
        repeatedAttachment.lifetime = .keepAlways
        add(repeatedAttachment)
        if let expectedInteractiveStart {
            let price = try XCTUnwrap(textFields(host.view).first { $0.placeholder == "Price Estimate" })
            price.text = "100"
            price.sendActions(for: .editingChanged)
            for _ in 0..<180 where repository.createOfferCallCount == 0 {
                try await Task.sleep(for: .seconds(1))
            }
            XCTAssertEqual(repository.createOfferCallCount, 1)
            let draft = try XCTUnwrap(repository.lastOfferDraft)
            let expected = try XCTUnwrap(ISO8601DateFormatter().date(from: expectedInteractiveStart))
            XCTAssertEqual(draft.proposedStart, expected)
            XCTAssertEqual(draft.proposedEnd, expected.addingTimeInterval(3600))
            if FileManager.default.fileExists(atPath: "/tmp/beckon-t374-offer-invalidation") {
                picker.setDate(repeatedWallTime.addingTimeInterval(60), animated: false)
                picker.sendActions(for: .valueChanged)
                try await Task.sleep(for: .seconds(1))
                XCTAssertEqual(repository.createOfferCallCount, 1)
                let invalidated = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: invalidated)
                attachment.name = "T-374 edited start requires a new occurrence"
                attachment.lifetime = .keepAlways
                add(attachment)
                for _ in 0..<180 where repository.createOfferCallCount < 2 {
                    try await Task.sleep(for: .seconds(1))
                }
                XCTAssertEqual(repository.createOfferCallCount, 2)
                let revised = try XCTUnwrap(repository.lastOfferDraft)
                XCTAssertEqual(revised.proposedStart, expected.addingTimeInterval(60))
                XCTAssertEqual(revised.proposedEnd, expected.addingTimeInterval(3660))
            }
        } else {
            let missingWallTime = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-03-14T02:30:00Z"))
            picker.setDate(missingWallTime, animated: false)
            picker.sendActions(for: .valueChanged)
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertEqual(picker.date, missingWallTime)
            let missing = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let missingAttachment = XCTAttachment(image: missing)
            missingAttachment.name = "T-374 mobile offer nonexistent hour"
            missingAttachment.lifetime = .keepAlways
            add(missingAttachment)
            XCTAssertEqual(repository.createOfferCallCount, 0)
        }
    }
}

@MainActor @Observable
private final class OfferInitializationNavigation {
    var path: [Int] = []
}

@MainActor @Observable
private final class OfferDeviceEnvironment {
    var timeZone = TimeZone(identifier: "America/Los_Angeles")!
    var calendar = Calendar(identifier: .gregorian)
    var textSize: DynamicTypeSize = .large
}

private struct OfferEnvironmentHost: View {
    let matchID: UUID
    let store: GroomerRequestsStore
    let device: OfferDeviceEnvironment
    var body: some View {
        NavigationStack { GroomerRequestDetailView(matchID: matchID, store: store) }
            .environment(\.timeZone, device.timeZone)
            .environment(\.calendar, device.calendar)
            .environment(\.dynamicTypeSize, device.textSize)
    }
}

struct GroomerRequestsStoreTests {
    @Test(arguments: ["America/Los_Angeles", "", "Invalid/Zone"]) @MainActor
    func destinationOfferUsesOnlyConfirmedGroomerZone(identifier: String) async throws {
        let owner = UUID()
        var request = Self.matchedRequest(groomerID: owner, locationMode: .customerComesToGroomer).request
        request.preferenceTimeZoneIdentifier = "America/New_York"
        let input = BeckonAddressInput(line1: "123 Test Street", line2: "", city: "Anaheim",
            stateCode: nil, postalCode: "92805", countryCode: "US")
        let address = BeckonConfirmedAddress(entered: input, accepted: input, provider: "apple_maps",
            placeID: nil, coordinate: BeckonAddressCoordinate(latitude: 33.83, longitude: -117.92),
            resolutionSource: "manual_geocode", confirmedAt: Date(timeIntervalSince1970: 0),
            timeZoneIdentifier: identifier.isEmpty ? nil : identifier)
        let profile = GroomerProfile(userID: owner, businessName: nil, bio: nil, yearsExperience: nil,
            baseCity: "Anaheim", baseState: "CA", serviceRadiusMiles: nil, serviceLocationMode: nil,
            ratingAverage: 0, ratingCount: 0, isActive: true, isVerified: true, confirmedAddress: address)
        let profiles = GroomerProfileRepositoryFake(profileResult: .success(profile))
        let store = GroomerRequestsStore(groomerID: owner, repository: GroomerRequestRepositoryFake(),
            profileRepository: profiles)
        let result = try await store.serviceTimeZoneForOffer(for: request)
        #expect(result?.identifier == (identifier == "America/Los_Angeles" ? identifier : nil))
        #expect(request.preferenceTimeZoneIdentifier == "America/New_York")
    }

    @Test @MainActor
    func destinationOfferZoneDoesNotFallBackWhenProfileReadFails() async throws {
        let owner = UUID()
        var request = Self.matchedRequest(groomerID: owner, locationMode: .customerComesToGroomer).request
        request.preferenceTimeZoneIdentifier = "America/New_York"
        let profiles = GroomerProfileRepositoryFake()
        profiles.profileResult = .failure(.networkUnavailable)
        let store = GroomerRequestsStore(groomerID: owner, repository: GroomerRequestRepositoryFake(),
            profileRepository: profiles)
        do {
            _ = try await store.serviceTimeZoneForOffer(for: request)
            Issue.record("Address lookup failure must propagate")
        } catch let error as GroomerProfileRepositoryError {
            #expect(error == .networkUnavailable)
        }
        let unavailable = GroomerRequestsStore(groomerID: owner, repository: GroomerRequestRepositoryFake())
        #expect(try await unavailable.serviceTimeZoneForOffer(for: request) == nil)
    }

    @Test @MainActor
    func mobileOfferZoneUsesRequestEvidenceAndRejectsUnknownZone() async throws {
        let owner = UUID()
        var request = Self.matchedRequest(groomerID: owner).request
        let store = GroomerRequestsStore(groomerID: owner, repository: GroomerRequestRepositoryFake())
        #expect(try await store.serviceTimeZoneForOffer(for: request) == nil)
        request.preferenceTimeZoneIdentifier = "America/New_York"
        #expect(try await store.serviceTimeZoneForOffer(for: request)?.identifier == "America/New_York")
        request.preferenceTimeZoneIdentifier = "Invalid/Zone"
        #expect(try await store.serviceTimeZoneForOffer(for: request) == nil)
    }

    @Test @MainActor
    func matchedRequestStatusPreservesReferenceTimeZoneWithoutInventingLegacyZone() {
        var request = Self.matchedRequest(groomerID: UUID()).request
        #expect(request.replacing(status: .cancelled).preferenceTimeZoneIdentifier == nil)
        request.preferenceTimeZoneIdentifier = "America/New_York"
        let replaced = request.replacing(status: .cancelled)
        #expect(replaced.preferenceTimeZoneIdentifier == "America/New_York")
        #expect(replaced.preferredStart == request.preferredStart)
        #expect(replaced.preferredEnd == request.preferredEnd)
    }

    @Test(arguments: [0, 14, 15, 60, 120, 121, 720, 721]) @MainActor
    func offerDefaultsUseOnlyDeclaredDurationThatFits(minutes: Int) throws {
        let request = Self.matchedRequest(groomerID: UUID()).request
        let now = try #require(GroomingRequestDateFormatting.parsedDate(from: "2026-06-21T12:00:00Z"))
        let range = GroomerRequestsStore.defaultOfferRange(for: request, durationMinutes: minutes, now: now)
        if (15...120).contains(minutes) {
            let range = try #require(range)
            #expect(range.end.timeIntervalSince(range.start) == TimeInterval(minutes * 60))
            #expect(range.start == GroomingRequestDateFormatting.parsedDate(from: request.preferredStart))
        } else {
            #expect(range?.start == nil)
        }
    }

    @Test @MainActor
    func offerDefaultsClipElapsedStartWithoutMovingOutsideTheWindow() throws {
        let request = Self.matchedRequest(groomerID: UUID()).request
        let now = try #require(GroomingRequestDateFormatting.parsedDate(from: "2026-06-22T16:30:00Z"))
        let range = try #require(GroomerRequestsStore.defaultOfferRange(for: request, durationMinutes: 60, now: now))
        #expect(range.start == now.addingTimeInterval(300))
        #expect(range.end == now.addingTimeInterval(3900))
        let late = GroomerRequestsStore.defaultOfferRange(for: request, durationMinutes: 60,
            now: now.addingTimeInterval(3600))
        #expect(late?.start == nil)
    }

    @Test(arguments: ["", "0", "14", "721", "60.5", "abc"]) @MainActor
    func offerDurationRequiresAnExplicitValidMinuteCount(text: String) {
        #expect(GroomerRequestsStore.proposedEnd(start: Date(), durationText: text) == nil)
    }

    @Test @MainActor
    func offerDurationRecalculatesEndFromTheEditedStart() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(GroomerRequestsStore.proposedEnd(start: start, durationText: "60") == start.addingTimeInterval(3600))
        #expect(GroomerRequestsStore.proposedEnd(start: start.addingTimeInterval(900), durationText: "60")
            == start.addingTimeInterval(4500))
    }

    @Test @MainActor
    func offerServiceDefaultsRequireOneActiveOwnedMatchingService() async {
        let groomerID = UUID()
        let request = Self.matchedRequest(groomerID: groomerID).request
        let service = GroomerService(id: UUID(), groomerID: groomerID, serviceType: .fullGroom,
            title: "Full Groom", description: nil, basePrice: 85, durationMinutes: 60,
            acceptedPetSizes: [], isActive: true)
        let profiles = GroomerProfileRepositoryFake(servicesResult: .success([service]))
        let store = GroomerRequestsStore(groomerID: groomerID, repository: GroomerRequestRepositoryFake(),
            profileRepository: profiles)
        #expect(await store.serviceForOffer(for: request) == service)
        profiles.servicesResult = .success([service, service])
        #expect(await store.serviceForOffer(for: request) == nil)
        profiles.servicesResult = .failure(.networkUnavailable)
        #expect(await store.serviceForOffer(for: request) == nil)
    }

    @Test @MainActor
    func unknownServiceDurationDoesNotBecomeThePreferenceWindow() throws {
        let request = Self.matchedRequest(groomerID: UUID()).request
        let now = try #require(GroomingRequestDateFormatting.parsedDate(from: "2026-06-21T12:00:00Z"))
        let range: (start: Date, end: Date)? = GroomerRequestsStore.defaultOfferRange(for: request, now: now)
        #expect(range?.start == nil)
    }

    @Test(arguments: [359, 1439]) @MainActor
    func broadPreferenceWindowsDoNotBecomeServiceDefaults(windowMinutes: Int) throws {
        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: "2026-06-22T00:00:00Z"))
        let request = Self.matchedRequest(groomerID: UUID(),
            preferredStart: GroomingRequestDateFormatting.serverString(from: start),
            preferredEnd: GroomingRequestDateFormatting.serverString(
                from: start.addingTimeInterval(TimeInterval(windowMinutes * 60)))).request
        let now = start.addingTimeInterval(-86400)
        #expect(GroomerRequestsStore.defaultOfferRange(for: request, now: now) == nil)
        let declared = try #require(GroomerRequestsStore.defaultOfferRange(
            for: request, durationMinutes: 60, now: now))
        #expect(declared.start == start)
        #expect(declared.end == start.addingTimeInterval(3600))
        #expect(request.preferredEnd == GroomingRequestDateFormatting.serverString(
            from: start.addingTimeInterval(TimeInterval(windowMinutes * 60))))
    }

    @Test
    func offerEditorExposesStableNamespacedKeyboardTargets() {
        let targets = GroomerOfferFocusTarget.allCases.map(\.rawValue)

        #expect(targets == [
            "groomer.offers.duration.container",
            "groomer.offers.price.container",
            "groomer.offers.message.container",
        ])
        #expect(Set(targets).count == targets.count)
    }

    @Test
    func offerInputTapActivatesTheTappedField() {
        #expect(
            GroomerOfferInputFocusPolicy.target(
                afterTapping: .price,
                current: nil
            ) == .price
        )
        #expect(
            GroomerOfferInputFocusPolicy.target(
                afterTapping: .message,
                current: .price
            ) == .message
        )
    }

    @Test @MainActor
    func requestPaginationRetriesThenAppendsUniqueRowsAndStopsAtLastPage() async {
        let groomerID = UUID()
        let first = Self.matchedRequest(groomerID: groomerID)
        let second = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestPages: [
                .success(ListPage(items: [first], request: .first, hasMore: true)),
                .failure(.networkUnavailable),
                .success(
                    ListPage(
                        items: [first, second],
                        request: .first.next,
                        hasMore: false
                    )
                ),
            ]
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()
        await store.loadNextPage()

        #expect(store.matchedRequests.map(\.id) == [first.id])
        #expect(store.canLoadMore == true)
        #expect(store.errorMessage == "Check your connection and try again.")

        await store.loadNextPage()

        #expect(repository.receivedMatchedRequestPages == [.first, .first.next, .first.next])
        #expect(store.matchedRequests.map(\.id) == [first.id, second.id])
        #expect(store.canLoadMore == false)
    }

    @Test @MainActor
    func loadPopulatesMatchedRequests() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest])
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(repository.matchedRequestsCallCount == 1)
        #expect(repository.lastGroomerID == groomerID)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func loadRecordsStructuredDebugEventsForEmptyMatchedRequestResult() async throws {
        let groomerID = UUID()
        let recorder = AppDebugEventRecorder(
            writer: AppDebugEventWriterSpy(),
            emitsToOSLog: false
        )
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([])
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository,
            debugRecorder: recorder
        )

        await store.load()

        let start = try #require(
            recorder.events.first {
                $0.source == "GroomerRequestsStore.load"
                    && $0.message == "start"
            }
        )
        let success = try #require(
            recorder.events.first {
                $0.source == "GroomerRequestsStore.load"
                    && $0.message == "success"
            }
        )

        #expect(start.scope == "groomer.requests")
        #expect(start.metadata["operation"] == "load")
        #expect(start.metadata["groomerID"] == groomerID.uuidString.prefix(8).uppercased())
        #expect(success.scope == "groomer.requests")
        #expect(success.metadata["operation"] == "load")
        #expect(success.metadata["matchedRequestCount"] == "0")
        #expect(success.metadata["requestPhotoCount"] == "0")
        #expect(success.metadata["downloadedPhotoCount"] == "0")
    }

    @Test @MainActor
    func dismissCallsRepositoryAndRemovesMatch() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            dismissResult: .success(
                DismissRequestMatchResult(
                    matchID: matchedRequest.match.id,
                    status: .dismissed,
                    dismissedAt: "2026-06-20T13:00:00Z"
                )
            )
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.dismiss(matchedRequest)

        #expect(repository.dismissCallCount == 1)
        #expect(repository.lastDismissedMatchID == matchedRequest.match.id)
        #expect(repository.lastDismissReason == nil)
        #expect(store.matchedRequests.isEmpty)
        #expect(store.noticeMessage == "Match dismissed.")
    }

    @Test @MainActor
    func nonDismissibleMatchDoesNotCallRepository() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(
            groomerID: groomerID,
            status: .offered
        )
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest])
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.dismiss(matchedRequest)

        #expect(repository.dismissCallCount == 0)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == "This match can no longer be dismissed.")
    }

    @Test @MainActor
    func dismissFailurePreservesMatch() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            dismissResult: .failure(.noLongerDismissible)
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.dismiss(matchedRequest)

        #expect(repository.dismissCallCount == 1)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == "This match can no longer be dismissed.")
    }

    @Test(arguments: [(-60.0, 3600.0), (3600.0, 3660.0), (0.0, 840.0), (0.0, 901.0), (0.0, Double.infinity)])
    @MainActor
    func invalidOfferTimingNeverCallsRepository(offset: Double, duration: Double) async throws {
        let groomerID = UUID()
        let request = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .success([request]))
        let store = GroomerRequestsStore(groomerID: groomerID, repository: repository)
        await store.load()
        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: request.request.preferredStart))
        await store.submitOffer(for: request, proposedStart: start.addingTimeInterval(offset),
            proposedEnd: start.addingTimeInterval(offset + duration), priceEstimateText: "100", message: "",
            now: start.addingTimeInterval(-3600))
        #expect(repository.createOfferCallCount == 0)
        #expect(store.errorMessage != nil)
        #expect(store.matchedRequests.first?.match.status == .visible)
    }

    @Test @MainActor
    func submitOfferTrimsFormCallsRepositoryAndUpdatesState() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let offerID = UUID()
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            createOfferResult: .success(
                CreateGroomerOfferResult(
                    offerID: offerID,
                    offerStatus: .pending,
                    requestStatus: .hasOffers
                )
            )
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: matchedRequest.request.preferredStart))
        let end = start.addingTimeInterval(2 * 60 * 60)
        await store.submitOffer(
            for: matchedRequest,
            proposedStart: start,
            proposedEnd: end,
            priceEstimateText: " 125.50 ",
            message: "  I can handle sensitive paws. ",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 1)
        #expect(repository.lastOfferDraft?.requestID == matchedRequest.request.id)
        #expect(repository.lastOfferDraft?.priceEstimate == 125.50)
        #expect(repository.lastOfferDraft?.message == "I can handle sensitive paws.")
        #expect(repository.offerReadCallCount == 1)
        #expect(store.matchedRequests.first?.match.status == .offered)
        #expect(store.matchedRequests.first?.request.status == .hasOffers)
        #expect(store.matchedRequests.first?.offer?.id == offerID)
        #expect(store.matchedRequests.first?.offer?.status == .pending)
        #expect(store.noticeMessage == "Offer submitted.")
    }

    @Test @MainActor
    func invalidOfferPriceDoesNotCallRepository() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest])
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: matchedRequest.request.preferredStart))
        await store.submitOffer(
            for: matchedRequest,
            proposedStart: start,
            proposedEnd: start.addingTimeInterval(2 * 60 * 60),
            priceEstimateText: "12.345",
            message: "",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 0)
        #expect(store.errorMessage == "Price must be 0–100000 with at most 2 decimals.")
    }

    @Test(arguments: ["matching", "wrong_owner", "cancelled", "withdrawn"]) @MainActor
    func createdOfferReadbackUsesOnlyMatchingAuthoritativeSnapshot(scenario: String) async throws {
        let wrongOwner = scenario == "wrong_owner"
        let groomerID = UUID()
        let matched = Self.matchedRequest(groomerID: groomerID)
        let offerID = UUID()
        let buffers = try GroomingTimingBuffers(preparation: 15, cleanup: 10, inboundTravel: 0, outboundTravel: 0)
        let readback = GroomerOffer(id: offerID, requestID: matched.request.id, matchID: matched.match.id,
            customerID: matched.request.customerID, groomerID: wrongOwner ? UUID() : groomerID,
            proposedStart: matched.request.preferredStart, proposedEnd: matched.request.preferredEnd,
            priceEstimate: 125, message: nil, status: .pending, expiresAt: matched.request.expiresAt,
            withdrawnAt: nil, createdAt: "2026-06-20T12:00:00Z", updatedAt: "2026-06-20T12:00:00Z",
            appliedTimingBuffers: buffers, serviceTimeZoneIdentifier: "America/Los_Angeles",
            scheduleTimeZoneIdentifier: "America/New_York", occupiedStart: "2026-06-22T15:45:00Z",
            occupiedEnd: "2026-06-22T18:10:00Z", timingSnapshotLoaded: true)
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .success([matched]),
            createOfferResult: .success(CreateGroomerOfferResult(offerID: offerID, offerStatus: .pending,
                requestStatus: .hasOffers)))
        repository.offerReadResult = .success(readback)
        let store = GroomerRequestsStore(groomerID: groomerID, repository: repository)
        await store.load()
        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: matched.request.preferredStart))
        let end = try #require(GroomingRequestDateFormatting.parsedDate(from: matched.request.preferredEnd))
        var submission: Task<Void, Never>?
        defer { repository.onOfferRead = nil }
        repository.onOfferRead = {
            if scenario == "cancelled" { submission?.cancel() }
            if scenario == "withdrawn", let current = store.matchedRequests.first {
                repository.withdrawOfferResult = .success(WithdrawGroomerOfferResult(offerID: offerID,
                    offerStatus: .withdrawnByGroomer, withdrawnTimestamp: "2026-06-20T12:01:00Z", requestStatus: .open))
                await store.withdrawOffer(for: current)
            }
        }
        submission = Task {
            await store.submitOffer(for: matched, proposedStart: start, proposedEnd: end,
                priceEstimateText: "125", message: "", now: start.addingTimeInterval(-3600))
        }
        await submission?.value
        #expect(repository.createOfferCallCount == 1)
        #expect(repository.offerReadCallCount == 1)
        #expect(store.matchedRequests.first?.offer?.id == offerID)
        #expect(store.matchedRequests.first?.offer?.timingSnapshotLoaded == (scenario == "matching"))
        #expect(store.matchedRequests.first?.offer?.appliedTimingBuffers == (scenario == "matching" ? buffers : nil))
        #expect(store.matchedRequests.first?.offer?.status == (scenario == "withdrawn" ? .withdrawnByGroomer : .pending))
        #expect(!store.isSubmittingOffer)
        #expect(store.errorMessage == nil)
        #expect(store.noticeMessage == (scenario == "withdrawn" ? "Offer withdrawn." : "Offer submitted."))
    }

    @Test(arguments: [
        (GroomerRequestRepositoryError.groomerUnavailable, "Choose a time that fits your availability, time off, and existing bookings, including preparation, cleanup, and travel."),
        (.timingBuffersRequired, "Confirm preparation, cleanup, and travel times in your availability settings before sending an offer."),
        (.scheduleTimeZoneRequired, "Confirm the time zone in your availability settings before sending an offer."),
        (.serviceTimeZoneRequired, "The service address needs a confirmed time zone. For mobile service, the customer needs to publish a new request with a confirmed address. For service at your location, confirm your profile address.")
    ]) @MainActor
    func submitOfferUnavailableRangePreservesMatchAndShowsAvailabilityError(error: GroomerRequestRepositoryError, message: String) async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            createOfferResult: .failure(error)
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: matchedRequest.request.preferredStart))
        await store.submitOffer(
            for: matchedRequest,
            proposedStart: start,
            proposedEnd: start.addingTimeInterval(2 * 60 * 60),
            priceEstimateText: "125",
            message: "",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 1)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == message)
        #expect(!store.isSubmittingOffer)
        #expect(store.noticeMessage == nil)
    }

    @Test @MainActor
    func submitOfferRequestNoLongerOpenPreservesMatchAndShowsStaleRequestError() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            createOfferResult: .failure(.requestNoLongerOpen)
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: matchedRequest.request.preferredStart))
        await store.submitOffer(
            for: matchedRequest,
            proposedStart: start,
            proposedEnd: start.addingTimeInterval(2 * 60 * 60),
            priceEstimateText: "125",
            message: "",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 1)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == "This request can no longer receive offers.")
    }

    @Test @MainActor
    func submitOfferActiveOfferConflictPreservesMatchAndShowsConflictError() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            createOfferResult: .failure(.activeOfferExists)
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: matchedRequest.request.preferredStart))
        await store.submitOffer(
            for: matchedRequest,
            proposedStart: start,
            proposedEnd: start.addingTimeInterval(2 * 60 * 60),
            priceEstimateText: "125",
            message: "",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 1)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == "You already have an active offer for this request.")
    }

    @Test @MainActor
    func pendingOfferCanBeWithdrawnAndReturnsMatchToViewed() async throws {
        let groomerID = UUID()
        let offerID = UUID()
        let matchedRequest = Self.matchedRequest(
            groomerID: groomerID,
            status: .offered,
            offerID: offerID
        )
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            withdrawOfferResult: .success(
                WithdrawGroomerOfferResult(
                    offerID: offerID,
                    offerStatus: .withdrawnByGroomer,
                    withdrawnTimestamp: "2026-06-20T14:00:00Z",
                    requestStatus: .open
                )
            )
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.withdrawOffer(for: matchedRequest)

        #expect(repository.withdrawOfferCallCount == 1)
        #expect(repository.lastWithdrawnOfferID == offerID)
        #expect(store.matchedRequests.first?.match.status == .viewed)
        #expect(store.matchedRequests.first?.request.status == .open)
        #expect(store.matchedRequests.first?.offer?.status == .withdrawnByGroomer)
        #expect(store.noticeMessage == "Offer withdrawn.")
    }

    @Test @MainActor
    func acceptedOfferWithdrawalIsRejectedWithoutCallingRepositoryAndClearsStaleNotice() async throws {
        let groomerID = UUID()
        let offerID = UUID()
        let pendingRequest = Self.matchedRequest(
            groomerID: groomerID,
            status: .offered,
            offerID: offerID
        )
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([pendingRequest]),
            withdrawOfferResult: .success(
                WithdrawGroomerOfferResult(
                    offerID: offerID,
                    offerStatus: .withdrawnByGroomer,
                    withdrawnTimestamp: "2026-06-20T14:00:00Z",
                    requestStatus: .open
                )
            )
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()
        await store.withdrawOffer(for: pendingRequest)
        #expect(store.noticeMessage == "Offer withdrawn.")

        let acceptedRequest = Self.matchedRequest(
            groomerID: groomerID,
            status: .offered,
            offerID: UUID(),
            offerStatus: .acceptedByCustomer
        )
        await store.withdrawOffer(for: acceptedRequest)

        #expect(repository.withdrawOfferCallCount == 1)
        #expect(store.errorMessage == "This offer can no longer be withdrawn.")
        #expect(store.noticeMessage == nil)
    }

    @Test @MainActor
    func fitEvidencePresentationUsesExplanationFirstCopyWithoutRawScore() {
        let matchedRequest = Self.matchedRequest(
            groomerID: UUID(),
            matchScore: 94.6,
            matchReason: """
            Same city and service location. Pet-fit evidence: curly coats with positive reviews, poodles from completed bookings.
            """
        )

        let presentation = matchedRequest.fitEvidencePresentation

        #expect(presentation?.scoreText == nil)
        #expect(
            presentation?.reason
                == "Same city and service location. Pet-fit evidence: curly coats with positive reviews, poodles from completed bookings."
        )
        #expect(
            presentation?.listSummary
                == "Location And Service Fit: Same city and service location. Earned Evidence: curly coats with positive reviews, poodles from completed bookings."
        )
    }

    @Test @MainActor
    func fitEvidencePresentationLabelsStarterSignalsAsLowConfidence() {
        let matchedRequest = Self.matchedRequest(
            groomerID: UUID(),
            matchScore: 86,
            matchReason: """
            Same city and service location. Groomer fit signals: portfolio tag for poodles, claim for gentle handling.
            """
        )

        let presentation = matchedRequest.fitEvidencePresentation

        #expect(presentation?.scoreText == nil)
        #expect(
            presentation?.listSummary
                == "Location And Service Fit: Same city and service location. Starter Signals: portfolio tag for poodles, claim for gentle handling."
        )
    }

    @Test @MainActor
    func matchSummaryDoesNotExposeRawScoreAsMatchPercentage() {
        let matchedRequest = Self.matchedRequest(
            groomerID: UUID(),
            status: .viewed,
            matchScore: 88,
            matchReason: """
            Same city and service location. Pet-fit evidence: gentle handling.
            """
        )

        #expect(matchedRequest.matchSummary == "Viewed · Fit evidence available")
    }

    @Test @MainActor
    func fitEvidencePresentationIgnoresBlankReason() {
        let matchedRequest = Self.matchedRequest(
            groomerID: UUID(),
            matchScore: 91,
            matchReason: "   \n  "
        )

        #expect(matchedRequest.fitEvidencePresentation == nil)
    }

    static func matchedRequest(
        groomerID: UUID,
        locationMode: GroomingLocationMode = .groomerComesToCustomer,
        preferredStart: String = "2026-06-22T16:00:00Z",
        preferredEnd: String = "2026-06-22T18:00:00Z",
        status: RequestMatchStatus = .visible,
        matchScore: Double? = 100,
        matchReason: String? = "same_city",
        offerID: UUID? = nil,
        offerStatus: GroomerOfferStatus = .pending
    ) -> GroomerMatchedRequest {
        let requestID = UUID()
        let customerID = UUID()
        let petID = UUID()

        return GroomerMatchedRequest(
            match: GroomerRequestMatch(
                id: UUID(),
                requestID: requestID,
                groomerID: groomerID,
                customerID: customerID,
                matchScore: matchScore,
                matchReason: matchReason,
                dismissReason: nil,
                status: status,
                viewedAt: nil,
                dismissedAt: nil,
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
            request: GroomerMatchedGroomingRequest(
                id: requestID,
                customerID: customerID,
                petID: petID,
                petSnapshot: GroomingRequestPetSnapshot(
                    id: petID,
                    name: "Mochi",
                    species: "Dog",
                    breed: "Corgi",
                    coatType: nil,
                    size: "M",
                    weightLbs: 22,
                    birthday: nil,
                    temperament: "Gentle",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-20T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: .fullGroom,
                serviceNotes: nil,
                preferredStart: preferredStart,
                preferredEnd: preferredEnd,
                locationMode: locationMode,
                streetAddress: "123 Pine Street",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                travelRadiusMiles: nil,
                status: .open,
                expiresAt: "2026-06-22T12:00:00Z",
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
            offer: offerID.map {
                GroomerOffer(
                    id: $0,
                    requestID: requestID,
                    matchID: UUID(),
                    customerID: customerID,
                    groomerID: groomerID,
                    proposedStart: "2026-06-22T16:00:00Z",
                    proposedEnd: "2026-06-22T18:00:00Z",
                    priceEstimate: 125,
                    message: "I can help.",
                    status: offerStatus,
                    expiresAt: "2026-06-22T12:00:00Z",
                    withdrawnAt: offerStatus == .withdrawnByGroomer
                        ? "2026-06-21T13:00:00Z"
                        : nil,
                    createdAt: "2026-06-20T12:00:00Z",
                    updatedAt: "2026-06-20T12:00:00Z"
                )
            }
        )
    }
}

@MainActor
final class GroomerRequestRepositoryFake: GroomerRequestRepository {
    var exactMatchResult: Result<GroomerMatchedRequest, GroomerRequestRepositoryError> = .failure(.matchNotFound)
    func matchedRequest(groomerID: UUID, requestID: UUID) async throws -> GroomerMatchedRequest {
        try exactMatchResult.get()
    }
    var offerReadResult: Result<GroomerOffer?, GroomerRequestRepositoryError> = .failure(.networkUnavailable)
    var onOfferRead: (@MainActor () async -> Void)?
    private(set) var offerReadCallCount = 0

    func offer(groomerID: UUID, offerID: UUID) async throws -> GroomerOffer? {
        offerReadCallCount += 1
        await onOfferRead?()
        return try offerReadResult.get()
    }

    var matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError>
    var dismissResult: Result<DismissRequestMatchResult, GroomerRequestRepositoryError>
    var createOfferResult: Result<CreateGroomerOfferResult, GroomerRequestRepositoryError>
    var withdrawOfferResult: Result<WithdrawGroomerOfferResult, GroomerRequestRepositoryError>
    var matchedRequestPages: [Result<ListPage<GroomerMatchedRequest>, GroomerRequestRepositoryError>]

    private(set) var matchedRequestsCallCount = 0
    private(set) var dismissCallCount = 0
    private(set) var createOfferCallCount = 0
    private(set) var withdrawOfferCallCount = 0
    private(set) var lastGroomerID: UUID?
    private(set) var lastDismissedMatchID: UUID?
    private(set) var lastDismissReason: String?
    private(set) var lastOfferDraft: GroomerOfferDraft?
    private(set) var lastWithdrawnOfferID: UUID?
    private(set) var receivedMatchedRequestPages: [ListPageRequest] = []

    init(
        matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError> = .success([]),
        dismissResult: Result<DismissRequestMatchResult, GroomerRequestRepositoryError> =
            .failure(.unavailable),
        createOfferResult: Result<CreateGroomerOfferResult, GroomerRequestRepositoryError> =
            .failure(.unavailable),
        withdrawOfferResult: Result<WithdrawGroomerOfferResult, GroomerRequestRepositoryError> =
            .failure(.unavailable),
        matchedRequestPages: [Result<ListPage<GroomerMatchedRequest>, GroomerRequestRepositoryError>] = []
    ) {
        self.matchedRequestsResult = matchedRequestsResult
        self.dismissResult = dismissResult
        self.createOfferResult = createOfferResult
        self.withdrawOfferResult = withdrawOfferResult
        self.matchedRequestPages = matchedRequestPages
    }

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        matchedRequestsCallCount += 1
        lastGroomerID = groomerID
        return try matchedRequestsResult.get()
    }

    func matchedRequests(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerMatchedRequest> {
        matchedRequestsCallCount += 1
        lastGroomerID = groomerID
        receivedMatchedRequestPages.append(page)
        if !matchedRequestPages.isEmpty {
            return try matchedRequestPages.removeFirst().get()
        }

        return ListPage(
            items: try matchedRequestsResult.get(),
            request: page,
            hasMore: false
        )
    }

    func dismiss(
        matchID: UUID,
        reason: String?
    ) async throws -> DismissRequestMatchResult {
        dismissCallCount += 1
        lastDismissedMatchID = matchID
        lastDismissReason = reason
        return try dismissResult.get()
    }

    func createOffer(
        draft: GroomerOfferDraft
    ) async throws -> CreateGroomerOfferResult {
        createOfferCallCount += 1
        lastOfferDraft = draft
        return try createOfferResult.get()
    }

    func withdrawOffer(
        offerID: UUID
    ) async throws -> WithdrawGroomerOfferResult {
        withdrawOfferCallCount += 1
        lastWithdrawnOfferID = offerID
        return try withdrawOfferResult.get()
    }
}
