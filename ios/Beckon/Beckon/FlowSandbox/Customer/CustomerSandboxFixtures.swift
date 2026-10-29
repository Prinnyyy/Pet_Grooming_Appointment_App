#if DEBUG
import SwiftUI
import UIKit

enum CustomerSandboxState: String, CaseIterable, Identifiable {
    case loaded, empty, loading, error, longNames, photos, draft
    case open, hasOffers, booked, cancelled, expired
    case confirmed, inService, outcomeReported, completed, unfulfilled, reviewed
    case reschedulePending, rescheduleAccepted, rescheduleExpired
    case unread, allRead, publicationPending, photoRetry, pendingPet
    case emailSent, newPassword, recoveryComplete, invalidLink
    var id: String { rawValue }
}

enum CustomerSandboxScreen: String, CaseIterable, Identifiable {
    case tabs, landing, signIn, signUp, passwordRecovery, onboarding, authenticatedAccount
    case home, notifications, pets, petCreate, petEdit, petRecovery
    case requests, dashboard, wizardPet, wizardService, wizardTime, wizardDetails, wizardReview
    case requestDetail, offers, publication, photoRetry
    case groomerPicker, groomerDetail, candidateActions, favorites
    case bookings, bookingDetail, fulfillment, reschedule, review, reminder
    case messages, chat, account, profile, feedback
    var id: String { rawValue }

    var states: [CustomerSandboxState] {
        let reads: [CustomerSandboxState] = [.loaded, .empty, .loading, .error, .longNames, .photos]
        switch self {
        case .landing: return [.loaded]
        case .signIn, .signUp, .onboarding: return [.loaded, .loading, .error, .longNames]
        case .passwordRecovery: return [.loaded, .emailSent, .newPassword, .recoveryComplete, .invalidLink, .error]
        case .authenticatedAccount: return [.loaded, .error, .longNames]
        case .home, .requests, .dashboard, .requestDetail:
            return reads + [.open, .hasOffers, .booked, .cancelled, .expired]
        case .notifications: return [.loaded, .empty, .loading, .error, .longNames, .unread, .allRead]
        case .messages: return reads + [.unread, .allRead]
        case .chat: return reads
        case .candidateActions: return [.loaded, .draft, .longNames, .photos, .error]
        case .groomerPicker, .groomerDetail: return reads + [.draft]
        case .account, .profile: return [.loaded, .loading, .error, .longNames, .photos]
        case .petCreate, .petEdit: return [.loaded, .error, .longNames, .photos]
        case .petRecovery: return [.pendingPet]
        case .wizardPet, .wizardService, .wizardTime, .wizardDetails, .wizardReview:
            return [.loaded, .longNames, .photos, .error]
        case .publication: return [.publicationPending, .error]
        case .photoRetry: return [.photoRetry]
        case .bookings, .bookingDetail, .reminder:
            return reads + [.confirmed, .inService, .outcomeReported, .completed, .cancelled, .unfulfilled, .reviewed]
        case .fulfillment: return [.confirmed, .inService, .outcomeReported, .completed, .cancelled, .unfulfilled, .error]
        case .reschedule: return [.loaded, .reschedulePending, .rescheduleAccepted, .rescheduleExpired, .error]
        case .review: return [.completed, .reviewed, .loading, .error]
        case .feedback: return [.loaded, .error]
        default: return reads
        }
    }

    var wizardStep: CustomerRequestWizardStep? {
        switch self {
        case .wizardPet: .pet
        case .wizardService: .service
        case .wizardTime: .time
        case .wizardDetails: .details
        case .wizardReview: .review
        default: nil
        }
    }
}

@MainActor
final class CustomerSandboxBoundary {
    var isActive = true
    var state: CustomerSandboxState = .loaded
    func check() async throws {
        while isActive && state == .loading {
            try await Task.sleep(for: .milliseconds(200))
        }
        guard isActive, !Task.isCancelled else { throw CancellationError() }
        if state == .error { throw CustomerRequestRepositoryError.networkUnavailable }
    }
}

enum CustomerSandboxFixtures {
    // Stable fixture namespace. Session directories and new user-created objects remain unique.
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
    }
    static let customerID = id(1)
    static let requestID = id(20)
    static let bookingID = id(30)
    static let conversationID = id(40)
    static let zone = "America/Los_Angeles"
    static let longName = "Mochi Alexander of the Pacific Northwest"
    static let address = ServiceAgreementAddress(streetAddress: "123 Preview Street", addressLine2: "Unit 4",
        city: "Los Angeles", state: "CA", zipCode: "90012", countryCode: "US")
    static let buffers = try! GroomingTimingBuffers(preparation: 10, cleanup: 10, inboundTravel: 15, outboundTravel: 15)

    static func pet(_ index: Int = 0, longNames: Bool = false) -> CustomerPet {
        CustomerPet(id: id(10 + index), customerID: customerID,
            name: longNames ? longName : (index == 0 ? "Mochi" : "Biscuit"), species: "Dog",
            breed: index == 0 ? "Shiba Inu" : "Pomeranian", coatType: "double", size: "M", weightLbs: 22,
            birthday: "2022-03-10", temperament: "Friendly", medicalNotes: nil,
            groomingNotes: "Sensitive paws. Please take breaks.", isActive: true, revision: id(100 + index))
    }

    static func request(state: CustomerSandboxState = .loaded, now: Date = .now, id: UUID? = nil) -> CustomerGroomingRequest {
        let pet = pet(longNames: state == .longNames)
        let status: GroomingRequestStatus = switch state {
        case .open: .open
        case .booked: .booked
        case .cancelled: .cancelled
        case .expired: .expired
        default: .hasOffers
        }
        let base = CustomerHomePreviewRequestRepository(pet: pet, now: now).storedRequests[0]
        return CustomerGroomingRequest(id: id ?? requestID, customerID: customerID, petID: pet.id,
            petSnapshot: base.petSnapshot, photoSnapshot: [], serviceType: .fullGroom,
            serviceNotes: base.serviceNotes, preferredStart: base.preferredStart, preferredEnd: base.preferredEnd,
            locationMode: .groomerComesToCustomer, streetAddress: address.streetAddress,
            city: address.city, state: address.state, zipCode: address.zipCode, travelRadiusMiles: nil,
            status: status, expiresAt: now.addingTimeInterval(state == .expired ? -3600 : 86400).ISO8601Format(),
            createdAt: now.ISO8601Format(), updatedAt: now.ISO8601Format(),
            preferenceTimeZoneIdentifier: zone, termsRevision: Self.id(120))
    }

    static func agreement(request: CustomerGroomingRequest, quote: UUID, start: String, end: String,
        price: Double = 120) -> ServiceAgreement {
        ServiceAgreement(schemaVersion: 1, requestRevision: request.termsRevision!, quoteRevision: quote,
            petID: request.petID!, petSnapshot: request.petSnapshot, serviceType: request.serviceType,
            serviceNotes: request.serviceNotes, locationMode: request.locationMode, address: address,
            serviceTimeZoneIdentifier: zone, scheduledStart: start, scheduledEnd: end, priceEstimate: price,
            currency: "USD", capturedAt: request.createdAt)
    }

    static func offers(for request: CustomerGroomingRequest, photos: Bool = false) -> [CustomerOfferReview] {
        (0..<3).map { index in
            let groomer = candidate(index).profile
            var offer = GroomerOffer(id: id(50 + index), requestID: request.id, matchID: id(60 + index),
                customerID: request.customerID, groomerID: groomer.id, proposedStart: request.preferredStart,
                proposedEnd: request.preferredEnd, priceEstimate: Double(110 + index * 15),
                message: "A gentle full groom, including bath, trim and nail care. Happy to discuss your preferences.",
                status: .pending, expiresAt: request.expiresAt, withdrawnAt: nil,
                createdAt: request.createdAt, updatedAt: request.updatedAt)
            offer.appliedTimingBuffers = buffers
            offer.serviceTimeZoneIdentifier = zone; offer.scheduleTimeZoneIdentifier = zone
            let start = GroomingRequestDateFormatting.parsedDate(from: offer.proposedStart)!
            let end = GroomingRequestDateFormatting.parsedDate(from: offer.proposedEnd)!
            offer.occupiedStart = start.addingTimeInterval(-1500).ISO8601Format()
            offer.occupiedEnd = end.addingTimeInterval(1500).ISO8601Format()
            offer.timingSnapshotLoaded = true; offer.agreementSnapshotLoaded = true
            offer.agreementSnapshot = agreement(request: request, quote: id(150 + index),
                start: offer.proposedStart, end: offer.proposedEnd, price: offer.priceEstimate)
            offer.quoteEvaluation = .init(termsValid: true, selectable: true, reason: "available")
            return CustomerOfferReview(offer: offer, groomerProfile: GroomerProfile(userID: groomer.id,
                businessName: groomer.businessName, bio: groomer.bio, yearsExperience: groomer.yearsExperience,
                baseCity: address.city, baseState: address.state, serviceRadiusMiles: 20,
                serviceLocationMode: .groomerComesToCustomer, ratingAverage: 4.8, ratingCount: 25,
                isActive: true, isVerified: true, ratingSum: 120),
                groomerAvatarPhotoData: photos ? imageData : nil)
        }
    }

    static func booking(state: CustomerSandboxState = .loaded, now: Date = .now) -> Booking {
        let request = request(state: state, now: now)
        let past = [.completed, .reviewed, .unfulfilled].contains(state)
        let current = [.inService, .outcomeReported].contains(state)
        let start = now.addingTimeInterval(past ? -86400 : current ? -1800 : 86400)
        let end = start.addingTimeInterval(7200)
        let status: BookingStatus = state == .cancelled ? .cancelledByCustomer : state == .unfulfilled ? .unfulfilled : past ? .completed : .confirmed
        let phase: BookingFulfillmentPhase = switch state {
        case .inService: .inService
        case .outcomeReported: .outcomeReported
        case .completed, .reviewed: .completed
        case .cancelled: .cancelled
        case .unfulfilled: .unfulfilled
        default: .scheduled
        }
        return Booking(id: bookingID, requestID: [.booked, .cancelled, .unfulfilled].contains(state) ? requestID : id(21), offerID: id(59), customerID: customerID,
            groomerID: id(70), scheduledStart: start.ISO8601Format(), scheduledEnd: end.ISO8601Format(),
            priceEstimate: 120, status: status, cancelledBy: state == .cancelled ? customerID : nil,
            cancelledAt: state == .cancelled ? now.ISO8601Format() : nil,
            completedAt: past ? end.ISO8601Format() : nil, completedBy: past ? id(70) : nil,
            createdAt: now.addingTimeInterval(-172800).ISO8601Format(), updatedAt: now.ISO8601Format(),
            review: state == .reviewed ? review() : nil, serviceType: .fullGroom,
            requestPetSnapshot: request.petSnapshot, groomerBusinessName: state == .longNames
                ? "Pine Street Gentle Grooming and Companion Care Studio" : "Pine Street Grooming",
            groomerAvatarPhotoData: state == .photos ? imageData : nil, locationMode: .groomerComesToCustomer,
            customerStreetAddress: address.streetAddress, customerCity: address.city, customerState: address.state,
            customerZipCode: address.zipCode, appliedTimingBuffers: buffers, serviceTimeZoneIdentifier: zone,
            scheduleTimeZoneIdentifier: zone, occupiedStart: start.addingTimeInterval(-1500).ISO8601Format(),
            occupiedEnd: end.addingTimeInterval(1500).ISO8601Format(),
            agreementSnapshot: agreement(request: request, quote: id(150), start: start.ISO8601Format(), end: end.ISO8601Format()),
            fulfillment: .init(revision: id(130), phase: phase, basis: "participant_confirmed",
                actualStartedAt: current || past ? start.ISO8601Format() : nil,
                actualEndedAt: past ? end.ISO8601Format() : nil, petReleaseAt: nil, resourceReleaseAt: nil,
                reportedOutcome: state == .outcomeReported ? "completion" : nil,
                reportedBy: state == .outcomeReported ? id(70) : nil,
                reportedAt: state == .outcomeReported ? now.ISO8601Format() : nil,
                reportPreviousPhase: state == .outcomeReported ? "in_service" : nil,
                reportNote: state == .outcomeReported ? "Grooming finished; ready for collection." : nil))
    }

    static func review() -> BookingReview {
        BookingReview(id: id(80), bookingID: bookingID, customerID: customerID, groomerID: id(70),
            rating: 5, content: "Gentle and patient. Mochi came home comfortable and happy.", createdAt: Date().ISO8601Format())
    }

    static func candidate(_ index: Int = 0, state: CustomerSandboxState = .loaded) -> DiscoveredGroomer {
        let names = ["Pine Street Grooming", "Jules Mobile Grooming", "Coat & Care", "Little Paw Studio", "Alex's Grooming", "The Gentle Trim"]
        return DiscoveredGroomer(profile: MarketplaceGroomerSummary(id: id(70 + index),
            businessName: state == .longNames ? "Pine Street Gentle Grooming and Companion Care Studio" : names[index % names.count],
            bio: "Patient, one-to-one grooming with breaks for sensitive pets.", yearsExperience: 8,
            city: address.city, state: address.state, ratingSum: 120, ratingCount: 25, isVerified: true,
            avatarPath: state == .photos ? "sandbox/avatar" : nil),
            eligibility: .init(state: "estimated_fit", reason: nil, serviceStart: nil, serviceEnd: nil),
            matchingEvidence: nil, distanceMiles: Double(index + 1) * 1.2,
            referencePrice: .init(amount: Decimal(110 + index * 15), currency: "USD", serviceID: id(170 + index)),
            favoriteState: .init(isFavorite: index == 0, revision: id(270 + index)), invitationState: .notSent)
    }

    static var imageData: Data {
        // A bundled SF Symbol bitmap exercises the image paths without a download or photo-library access.
        let image = UIImage(systemName: "pawprint.fill")!
        return UIGraphicsImageRenderer(size: CGSize(width: 160, height: 160)).pngData { context in
            UIColor.systemTeal.withAlphaComponent(0.15).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
            image.withTintColor(.systemTeal).draw(in: CGRect(x: 30, y: 30, width: 100, height: 100))
        }
    }
}
#endif
