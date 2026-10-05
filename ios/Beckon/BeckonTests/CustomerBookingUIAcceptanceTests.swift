import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class CustomerBookingUIAcceptanceTests: XCTestCase {
    func testLocalCustomerJourney() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["TEST_RUNNER_BECKON_CUSTOMER_AUDIT"] == "1"
                || environment["BECKON_CUSTOMER_AUDIT"] == "1" else {
            throw XCTSkip("Opt-in local Customer booking UI audit")
        }
        let marker = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("t403-audit.json")
        try Data(#"{"screen":"booking","largeText":false}"#.utf8).write(to: marker)
        defer { try? FileManager.default.removeItem(at: marker) }
        let session = Session()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let visibleWindows = scene.windows.filter { !$0.isHidden }
        visibleWindows.forEach { $0.isHidden = true }
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: AuditHost(session: session))
        host.view.accessibilityViewIsModal = true
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            visibleWindows.forEach { $0.isHidden = false }
            previous?.makeKey()
        }
        for _ in 0..<2400 where !session.finished {
            try await Task.sleep(for: .milliseconds(500))
            if let data = try? Data(contentsOf: marker),
               let config = try? JSONDecoder().decode(Configuration.self, from: data), config != session.config {
                session.config = config
            }
        }
        XCTAssertTrue(session.finished, "Finish local audit before timeout")
    }

    struct Configuration: Decodable, Equatable {
        var screen = "booking"
        var largeText = false
    }

    @Observable final class Session {
        var config = Configuration()
        var finished = false
    }

    struct AuditHost: View {
        let session: Session
        var body: some View {
            VStack(spacing: 0) {
                Button("Finish Local Audit") { session.finished = true }
                    .font(.caption).dynamicTypeSize(.large).frame(height: 28)
                    .accessibilityIdentifier("local.audit.finish")
                Journey(screen: session.config.screen).id(session.config.screen)
            }
            .environment(\.dynamicTypeSize, session.config.largeText ? .accessibility3 : .large)
        }
    }

    struct Journey: View {
        let screen: String
        @State private var fixture: CustomerBookingUIFixture?
        @State private var openedChat = false

        var body: some View {
            NavigationStack {
                if let fixture {
                    Group {
                        if screen.hasPrefix("offers") {
                            CustomerRequestOffersView(requestID: fixture.request.id, store: fixture.requests)
                        } else {
                            BookingDetailView(bookingID: fixture.booking.id, role: .customer, store: fixture.bookings)
                        }
                    }
                    .navigationDestination(isPresented: $openedChat) { Text("Local chat route reached") }
                } else { ProgressView() }
            }
            .environment(\.openBookingChat, { _ in openedChat = true })
            .task { fixture = try? await CustomerBookingUIFixture(screen: screen) }
        }
    }
}

@MainActor
final class CustomerBookingUIFixture {
    let booking: Booking
    let request: CustomerGroomingRequest
    let bookings: BookingsStore
    let requests: CustomerRequestsStore
    let bookingRepository: BookingRepositoryFake
    let requestRepository: CustomerRequestRepositoryFake
    let acceptanceRepository: CustomerRequestBookingRepositoryFake

    init(screen: String) async throws {
        let shift: TimeInterval = screen.hasPrefix("review") ? -86400 * 4 : screen == "report" ? -86400 * 3 - 600 : 0
        var value = try BookingRescheduleTests.booking(shift: shift)
        let base = value
        value = Booking(id: base.id, requestID: base.requestID, offerID: base.offerID,
            customerID: base.customerID, groomerID: base.groomerID,
            scheduledStart: base.scheduledStart, scheduledEnd: base.scheduledEnd,
            priceEstimate: base.priceEstimate, status: base.status, cancelledBy: nil, cancelledAt: nil,
            completedAt: nil, completedBy: nil, createdAt: base.createdAt, updatedAt: base.updatedAt,
            review: nil, serviceType: .fullGroom,
            groomerBusinessName: "Willow & Wash Gentle Mobile Grooming Studio",
            locationMode: .customerComesToGroomer, appliedTimingBuffers: base.appliedTimingBuffers,
            serviceTimeZoneIdentifier: base.serviceTimeZoneIdentifier,
            scheduleTimeZoneIdentifier: base.scheduleTimeZoneIdentifier,
            agreementSnapshot: base.agreementSnapshot, fulfillment: base.fulfillment)
        let savedReview = BookingReview(id: UUID(), bookingID: value.id, customerID: value.customerID,
            groomerID: value.groomerID, rating: 4, content: "Patient handling and a tidy trim.",
            createdAt: GroomingRequestDateFormatting.serverString(from: Date()),
            petFitOutcomes: [BookingReviewPetFitOutcomeRecord(id: UUID(),
                signal: ReviewEvidenceKey(dimension: "service", value: "full_groom").signal!, outcome: .positive)])
        if screen.hasPrefix("review") {
            value = value.replacing(status: .completed, cancelledBy: nil, cancelledAt: nil,
                completedAt: value.scheduledEnd, completedBy: value.groomerID)
            value.fulfillment = Self.fulfillment(.completed, booking: value)
            if screen == "review-submitted" { value = value.adding(review: savedReview) }
        } else if screen == "report" {
            value.fulfillment = Self.fulfillment(.inService, booking: value)
        } else if screen == "cancelled" {
            value = value.replacing(status: .cancelledByCustomer, cancelledBy: value.customerID, cancelledAt: value.createdAt)
            value.fulfillment = Self.fulfillment(.cancelled, booking: value)
        }
        booking = value
        let now = GroomingRequestDateFormatting.serverString(from: Date())
        let expiry = GroomingRequestDateFormatting.serverString(from: Date().addingTimeInterval(86400))
        let pet = GroomerRequestsStoreTests.matchedRequest(groomerID: value.groomerID,
            petName: "Sir Bartholomew Wellington the Third").request.petSnapshot
        request = CustomerGroomingRequest(id: value.requestID, customerID: value.customerID, petID: pet.id,
            petSnapshot: pet, photoSnapshot: [], serviceType: .fullGroom, serviceNotes: "Quiet introduction, please.",
            preferredStart: value.scheduledStart, preferredEnd: value.scheduledEnd, locationMode: .customerComesToGroomer,
            streetAddress: "123 Pine Street", addressLine2: "Building West, Apartment 1204",
            city: "Seattle", state: "WA", zipCode: "98101", travelRadiusMiles: 12, status: .open,
            expiresAt: expiry, createdAt: now, updatedAt: now, preferenceTimeZoneIdentifier: "America/Los_Angeles")
        let offers: [CustomerOfferReview] = (0..<3).map { index in
            let offer = GroomerOffer(id: index == 0 ? value.offerID : UUID(), requestID: value.requestID, matchID: UUID(),
                customerID: value.customerID, groomerID: value.groomerID, proposedStart: value.scheduledStart,
                proposedEnd: value.scheduledEnd, priceEstimate: Double(125 + index * 20), message: "Quiet, one-on-one care.",
                status: index == 2 ? .withdrawnByGroomer : .pending, expiresAt: expiry, withdrawnAt: nil, createdAt: now, updatedAt: now,
                appliedTimingBuffers: value.appliedTimingBuffers, serviceTimeZoneIdentifier: "America/Los_Angeles",
                scheduleTimeZoneIdentifier: "America/Los_Angeles", occupiedStart: value.scheduledStart,
                occupiedEnd: GroomingRequestDateFormatting.serverString(from:
                    GroomingRequestDateFormatting.parsedDate(from: value.scheduledEnd)!.addingTimeInterval(600)),
                timingSnapshotLoaded: true, agreementSnapshot: value.agreementSnapshot,
                quoteEvaluation: QuoteEvaluation(termsValid: index != 2, selectable: index != 2, reason: index == 2 ? "withdrawn" : "available"),
                agreementSnapshotLoaded: true)
            return CustomerOfferReview(offer: offer, groomerProfile: GroomerProfile(userID: value.groomerID,
                businessName: index == 0 ? "Willow & Wash Gentle Mobile Grooming Studio" : "Neighborhood Grooming",
                bio: "Patient appointments for sensitive coats.", yearsExperience: 8, baseCity: "Seattle",
                baseState: "WA", serviceRadiusMiles: 12, serviceLocationMode: .customerComesToGroomer,
                ratingAverage: 4.9, ratingCount: 32, isActive: true, isVerified: true))
        }
        bookingRepository = BookingRepositoryFake(bookingsResult: screen == "unavailable" ? .failure(.networkUnavailable) : .success([value]))
        bookingRepository.reviewResult = .success(CreateReviewResult(review: savedReview, groomerRatingAverage: 4.8, groomerRatingCount: 33))
        if screen != "unavailable" {
            let original = value
            let currentBooking: @MainActor () -> Booking = { [weak bookingRepository] in
                bookingRepository?.lastReviewedBookingID == original.id ? original.adding(review: savedReview) : original
            }
            bookingRepository.pageRead = { page in
                ListPage(items: [currentBooking()], request: page, hasMore: false)
            }
            bookingRepository.exactRead = { ids in [currentBooking()].filter { ids.contains($0.id) } }
        }
        let proposal = screen == "proposal" ? try BookingRescheduleTests.proposal(for: value) : nil
        bookingRepository.rescheduleResult = .success(BookingRescheduleResult(booking: value, proposal: proposal, receipt: nil))
        if screen != "review-error" {
            bookingRepository.reviewContextResult = .success(BookingReviewContext(bookingID: value.id, contextRevision: UUID(),
                evidenceContextVersion: 2, serviceAt: value.scheduledEnd,
                allowedKeys: [ReviewEvidenceKey(dimension: "service", value: "full_groom"), ReviewEvidenceKey(dimension: "care", value: "anxious")]))
        }
        bookings = BookingsStore(participantID: value.customerID, role: .customer, repository: bookingRepository,
            initialBookings: screen == "unavailable" ? [] : [value], appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        requestRepository = CustomerRequestRepositoryFake(requestsResult: .success([request]),
            offersResult: screen == "offers-error" ? .failure(.networkUnavailable) : .success(screen == "offers-empty" ? [] : offers))
        acceptanceRepository = CustomerRequestBookingRepositoryFake(bookingsResult: .success([value]),
            acceptResult: .success(AcceptGroomerOfferResult(bookingID: value.id, conversationID: UUID(),
                requestID: value.requestID, offerID: value.offerID, bookingStatus: .confirmed,
                offerStatus: .acceptedByCustomer, requestStatus: .booked)))
        requests = CustomerRequestsStore(customerID: value.customerID, petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: requestRepository, bookingRepository: acceptanceRepository,
            appointmentReminderScheduler: AppointmentReminderSchedulerFake(), bookingsStore: bookings)
        await requests.load()
    }

    private static func fulfillment(_ phase: BookingFulfillmentPhase, booking: Booking) -> BookingFulfillment {
        BookingFulfillment(revision: UUID(), phase: phase, basis: "live", actualStartedAt: booking.scheduledStart,
            actualEndedAt: phase == .completed ? booking.scheduledEnd : nil, petReleaseAt: nil, resourceReleaseAt: nil,
            reportedOutcome: nil, reportedBy: nil, reportedAt: nil, reportPreviousPhase: nil, reportNote: nil)
    }
}
