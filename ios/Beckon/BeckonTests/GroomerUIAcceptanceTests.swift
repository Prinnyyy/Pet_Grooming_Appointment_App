import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class GroomerUIAcceptanceTests: XCTestCase {
    func testLocalWorkspaceWalkthrough() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["TEST_RUNNER_BECKON_GROOMER_AUDIT"] == "1"
                || environment["BECKON_GROOMER_AUDIT"] == "1" else {
            throw XCTSkip("Opt-in local Groomer UI audit")
        }
        let marker = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("t402-audit.json")
        try Data(#"{"largeText":false,"scenario":"populated"}"#.utf8).write(to: marker)
        defer { try? FileManager.default.removeItem(at: marker) }
        let session = AuditSession()
        let fixture = GroomerUIFixture()
        let host = UIHostingController(rootView: AuditHost(session: session, fixture: fixture))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let existingWindows = scene.windows.filter { !$0.isHidden }
        existingWindows.forEach { $0.isHidden = true }
        let window = UIWindow(windowScene: scene)
        host.view.accessibilityViewIsModal = true
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            existingWindows.forEach { $0.isHidden = false }
            previous?.makeKey()
        }
        for _ in 0..<1800 where !session.finished {
            try await Task.sleep(for: .milliseconds(500))
            if let data = try? Data(contentsOf: marker),
               let config = try? JSONDecoder().decode(AuditConfiguration.self, from: data), config != session.config {
                if config.scenario != session.config.scenario { fixture.configure(config.scenario) }
                session.config = config
            }
        }
        XCTAssertTrue(session.finished, "Finish local audit before timeout")
        XCTAssertEqual(fixture.requests.createOfferCallCount, 0)
        XCTAssertEqual(fixture.requests.dismissCallCount, 0)
        XCTAssertEqual(fixture.profile.updateProfileCallCount, 0)
        XCTAssertEqual(fixture.profile.saveAvailabilityCallCount, 0)
        XCTAssertEqual(fixture.chat.sendCallCount, 0)
    }

    struct AuditConfiguration: Decodable, Equatable {
        var largeText = false
        var scenario = "populated"
    }

    @Observable final class AuditSession {
        var config = AuditConfiguration()
        var finished = false
    }

    struct AuditHost: View {
        let session: AuditSession
        let fixture: GroomerUIFixture
        var body: some View {
            VStack(spacing: 0) {
                Button("Finish Local Audit") { session.finished = true }
                    .font(.caption).dynamicTypeSize(.large).frame(height: 28)
                    .accessibilityIdentifier("local.audit.finish")
                GroomerTabView(groomerID: fixture.owner, groomerDisplayName: "Alexandra Wellington",
                    profileRepository: fixture.profile, requestRepository: fixture.requests,
                    notificationRepository: fixture.notifications, bookingRepository: fixture.bookings,
                    chatRepository: fixture.chat, onSignOut: {})
                    .id(session.config.scenario)
            }
            .environment(\.dynamicTypeSize, session.config.largeText ? .accessibility3 : .large)
        }
    }
}

@MainActor
final class GroomerUIFixture {
    let owner = UUID()
    let profile: GroomerProfileRepositoryFake
    let requests: GroomerRequestRepositoryFake
    let bookings: BookingRepositoryFake
    let chat: ChatRepositoryFake
    let notifications = GroomerNotificationRepositoryFake()
    private let matches: [GroomerMatchedRequest]
    private let appointments: [Booking]
    private let offers: [GroomerOfferListItem]

    init() {
        let start = GroomingRequestDateFormatting.serverString(from: Date().addingTimeInterval(3600))
        let end = GroomingRequestDateFormatting.serverString(from: Date().addingTimeInterval(7200))
        let expiry = GroomingRequestDateFormatting.serverString(from: Date().addingTimeInterval(86400))
        var profileValue = GroomerProfile(userID: owner,
            businessName: "Willow & Wash Gentle Mobile Grooming Studio",
            bio: "Patient, one-on-one appointments for sensitive coats.", yearsExperience: 8,
            baseStreetAddress: "123 Pine Street", baseCity: "Seattle", baseState: "WA", baseZipCode: "98101",
            serviceRadiusMiles: 12, serviceLocationMode: .groomerComesToCustomer,
            serviceLocationModes: [.groomerComesToCustomer], ratingAverage: 4.9, ratingCount: 32,
            isActive: true, isVerified: true)
        profileValue.avatarPath = "local-audit-avatar.png"
        let image = UIImage(systemName: "scissors")!.pngData()!
        let availablePhoto = GroomerProfileStoreTests.photo(groomerID: owner)
        let failedPhoto = GroomerProfileStoreTests.photo(groomerID: owner)
        profile = GroomerProfileRepositoryFake(profileResult: .success(profileValue),
            servicesResult: .success([GroomerProfileStoreTests.service(groomerID: owner)]),
            portfolioResult: .success([availablePhoto, failedPhoto]),
            availabilityResult: .success(Self.weeklyHours(owner: owner)),
            petFitEvidenceSummaryResult: .success([GroomerProfileStoreTests.evidenceSummary(
                groomerID: owner, signal: .serviceFit(.gentleHandling), completedBookingCount: 8,
                positiveReviewOutcomeCount: 5, structuredReviewOutcomeCount: 6, confidenceTier: .medium)]),
            avatarPhotoDataResult: .success(image),
            portfolioPhotoDataResultsByID: [availablePhoto.id: .success(image), failedPhoto.id: .failure(.networkUnavailable)])
        matches = [GroomerRequestsStoreTests.matchedRequest(groomerID: owner,
            petName: "Sir Bartholomew Wellington the Third", expiresAt: expiry,
            preferredStart: start, preferredEnd: end, preferenceTimeZoneIdentifier: "America/Los_Angeles")]
        requests = GroomerRequestRepositoryFake(matchedRequestsResult: .success(matches))
        let offer = GroomerOffer(id: UUID(), requestID: matches[0].request.id, matchID: matches[0].id,
            customerID: matches[0].request.customerID, groomerID: owner, proposedStart: start, proposedEnd: end,
            priceEstimate: 125, message: "Quiet, one-on-one care with a gentle introduction.", status: .pending,
            expiresAt: expiry, withdrawnAt: nil, createdAt: start, updatedAt: start,
            serviceTimeZoneIdentifier: "America/Los_Angeles")
        offers = [GroomerOfferListItem(offer: offer, request: matches[0].request, booking: nil)]
        requests.offersResult = .success(offers)
        requests.exactMatchResult = .success(matches[0])
        requests.rankedPages = Array(repeating: .success(RankedPage(items: matches, rankingRevision: "local",
            scoreAsOf: Date(), validUntil: Date().addingTimeInterval(3600), algorithmVersion: "matching-v1",
            requestedMode: "fit", effectiveMode: "fit", pendingCount: 0, assessmentCount: 0, nextCursor: nil)), count: 30)
        appointments = [BookingsStoreTests.booking(groomerID: owner, serviceType: .fullGroom,
            locationMode: .groomerComesToCustomer, customerStreetAddress: "123 Pine Street",
            customerCity: "Seattle", customerState: "WA", customerZipCode: "98101",
            requestPetSnapshot: matches[0].request.petSnapshot, scheduledStart: start, scheduledEnd: end,
            serviceTimeZoneIdentifier: "America/Los_Angeles")]
        bookings = BookingRepositoryFake(bookingsResult: .success(appointments))
        let conversation = ChatConversation(id: UUID(), customerID: appointments[0].customerID, groomerID: owner,
            latestBookingID: appointments[0].id, scheduledStart: start, scheduledEnd: end,
            priceEstimate: 125, bookingStatus: .confirmed,
            latestMessageSenderID: appointments[0].customerID, latestMessageCreatedAt: start,
            latestMessageBody: "Please ring the side doorbell. Bartholomew needs a quiet introduction.",
            createdAt: start, updatedAt: start, serviceTimeZoneIdentifier: "America/Los_Angeles")
        chat = ChatRepositoryFake(conversationsResult: .success([conversation]))
        chat.exactConversationResult = .success(conversation)
    }

    func configure(_ scenario: String) {
        let failed = scenario == "error"
        let items = scenario == "empty" ? [] : matches
        requests.rankedPages = Array(repeating: failed ? .failure(.unavailable) : .success(RankedPage(
            items: items, rankingRevision: "local", scoreAsOf: Date(), validUntil: Date().addingTimeInterval(3600),
            algorithmVersion: "matching-v1", requestedMode: "fit", effectiveMode: "fit", pendingCount: 0,
            assessmentCount: 0, nextCursor: nil)), count: 30)
        requests.matchedRequestsResult = failed ? .failure(.networkUnavailable) : .success(scenario == "empty" ? [] : matches)
        requests.offersResult = failed ? .failure(.networkUnavailable) : .success(scenario == "empty" ? [] : offers)
        bookings.bookingsResult = failed ? .failure(.networkUnavailable) : .success(scenario == "empty" ? [] : appointments)
        if failed { profile.availabilityResult = .failure(.networkUnavailable) }
        else { profile.availabilityResult = .success(Self.weeklyHours(owner: owner)) }
    }

    private static func weeklyHours(owner: UUID) -> [GroomerAvailabilityWindow] {
        GroomerAvailabilityWeekday.allCases.map {
            GroomerAvailabilityWindow(id: UUID(), groomerID: owner, weekday: $0,
                startMinutes: 9 * 60, endMinutes: 17 * 60, isEnabled: true, timezone: "America/Los_Angeles")
        }
    }
}
