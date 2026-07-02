import Foundation

struct Booking: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let requestID: UUID
    let offerID: UUID
    let customerID: UUID
    let groomerID: UUID
    let scheduledStart: String
    let scheduledEnd: String
    let priceEstimate: Double
    let status: BookingStatus
    let cancelledBy: UUID?
    let cancelledAt: String?
    let completedAt: String?
    let completedBy: UUID?
    let createdAt: String
    let updatedAt: String
    let review: BookingReview?
    let serviceType: GroomingServiceType?
    let requestPetSnapshot: GroomingRequestPetSnapshot?
    let groomerBusinessName: String?
    let groomerBaseStreetAddress: String?
    let groomerBaseCity: String?
    let groomerBaseState: String?
    let groomerBaseZipCode: String?
    let locationMode: GroomingLocationMode?
    let customerStreetAddress: String?
    let customerCity: String?
    let customerState: String?
    let customerZipCode: String?

    nonisolated init(
        id: UUID,
        requestID: UUID,
        offerID: UUID,
        customerID: UUID,
        groomerID: UUID,
        scheduledStart: String,
        scheduledEnd: String,
        priceEstimate: Double,
        status: BookingStatus,
        cancelledBy: UUID?,
        cancelledAt: String?,
        completedAt: String?,
        completedBy: UUID?,
        createdAt: String,
        updatedAt: String,
        review: BookingReview?,
        serviceType: GroomingServiceType? = nil,
        requestPetSnapshot: GroomingRequestPetSnapshot? = nil,
        groomerBusinessName: String? = nil,
        groomerBaseStreetAddress: String? = nil,
        groomerBaseCity: String? = nil,
        groomerBaseState: String? = nil,
        groomerBaseZipCode: String? = nil,
        locationMode: GroomingLocationMode? = nil,
        customerStreetAddress: String? = nil,
        customerCity: String? = nil,
        customerState: String? = nil,
        customerZipCode: String? = nil
    ) {
        self.id = id
        self.requestID = requestID
        self.offerID = offerID
        self.customerID = customerID
        self.groomerID = groomerID
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.priceEstimate = priceEstimate
        self.status = status
        self.cancelledBy = cancelledBy
        self.cancelledAt = cancelledAt
        self.completedAt = completedAt
        self.completedBy = completedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.review = review
        self.serviceType = serviceType
        self.requestPetSnapshot = requestPetSnapshot
        self.groomerBusinessName = groomerBusinessName
        self.groomerBaseStreetAddress = groomerBaseStreetAddress
        self.groomerBaseCity = groomerBaseCity
        self.groomerBaseState = groomerBaseState
        self.groomerBaseZipCode = groomerBaseZipCode
        self.locationMode = locationMode
        self.customerStreetAddress = customerStreetAddress
        self.customerCity = customerCity
        self.customerState = customerState
        self.customerZipCode = customerZipCode
    }

    nonisolated var priceSummary: String {
        priceEstimate.formatted(
            .currency(code: "USD").precision(.fractionLength(2))
        )
    }

    nonisolated var scheduledTimeSummary: String {
        "\(GroomingRequestDateFormatting.displayString(from: scheduledStart)) – \(GroomingRequestDateFormatting.displayString(from: scheduledEnd))"
    }

    nonisolated var referenceCode: String {
        Self.referenceCode(for: id)
    }

    nonisolated var requestReferenceCode: String {
        Self.referenceCode(for: requestID)
    }

    nonisolated var offerReferenceCode: String {
        Self.referenceCode(for: offerID)
    }

    nonisolated var canCancel: Bool {
        status == .confirmed
    }

    nonisolated func canComplete(for role: UserRole) -> Bool {
        role == .groomer && status == .confirmed
    }

    nonisolated func canReview(for role: UserRole) -> Bool {
        guard role == .customer, status == .completed else {
            return false
        }

        if case nil = review {
            return true
        }

        return false
    }

    nonisolated func participantReferenceCode(for role: UserRole) -> String {
        switch role {
        case .customer:
            Self.referenceCode(for: groomerID)
        case .groomer:
            Self.referenceCode(for: customerID)
        }
    }

    nonisolated func participantSummary(for role: UserRole) -> String {
        switch role {
        case .customer:
            "Groomer ref \(participantReferenceCode(for: role))"
        case .groomer:
            "Customer ref \(participantReferenceCode(for: role))"
        }
    }

    nonisolated func partnerDisplayTitle(for role: UserRole) -> String {
        switch role {
        case .customer:
            normalized(groomerBusinessName) ?? "Groomer Name"
        case .groomer:
            "Booking Customer"
        }
    }

    nonisolated var appointmentServiceTitle: String {
        serviceType?.title ?? "Service Details"
    }

    nonisolated var reviewableFitSignals: [PetFitSignal] {
        guard
            status == .completed,
            let serviceType,
            let requestPetSnapshot
        else {
            return []
        }

        return PetFitSignal.signals(
            for: requestPetSnapshot,
            serviceType: serviceType,
            referenceDate: reviewableFitReferenceDate
        )
    }

    nonisolated var appointmentLocationTitle: String {
        switch locationMode {
        case .groomerComesToCustomer:
            "Groomer Comes To Customer"
        case .customerComesToGroomer:
            "Customer Comes To Groomer"
        case nil:
            "Location Details"
        }
    }

    nonisolated var appointmentAddressSummary: String {
        switch locationMode {
        case .groomerComesToCustomer:
            customerAddressSummary ?? "Customer address unavailable"
        case .customerComesToGroomer:
            groomerLocationSummary ?? "Groomer address pending"
        case nil:
            customerAddressSummary ?? groomerLocationSummary ?? "Address unavailable"
        }
    }

    nonisolated func replacing(
        status: BookingStatus,
        cancelledBy: UUID?,
        cancelledAt: String?,
        completedAt: String? = nil,
        completedBy: UUID? = nil,
        review: BookingReview? = nil
    ) -> Booking {
        Booking(
            id: id,
            requestID: requestID,
            offerID: offerID,
            customerID: customerID,
            groomerID: groomerID,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            priceEstimate: priceEstimate,
            status: status,
            cancelledBy: cancelledBy,
            cancelledAt: cancelledAt,
            completedAt: completedAt,
            completedBy: completedBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            review: review,
            serviceType: serviceType,
            requestPetSnapshot: requestPetSnapshot,
            groomerBusinessName: groomerBusinessName,
            groomerBaseStreetAddress: groomerBaseStreetAddress,
            groomerBaseCity: groomerBaseCity,
            groomerBaseState: groomerBaseState,
            groomerBaseZipCode: groomerBaseZipCode,
            locationMode: locationMode,
            customerStreetAddress: customerStreetAddress,
            customerCity: customerCity,
            customerState: customerState,
            customerZipCode: customerZipCode
        )
    }

    nonisolated func adding(review: BookingReview) -> Booking {
        replacing(
            status: status,
            cancelledBy: cancelledBy,
            cancelledAt: cancelledAt,
            completedAt: completedAt,
            completedBy: completedBy,
            review: review
        )
    }

    nonisolated private static func referenceCode(for id: UUID) -> String {
        String(id.uuidString.prefix(8)).uppercased()
    }

    nonisolated private var customerAddressSummary: String? {
        let parts = [
            normalized(customerStreetAddress),
            normalized(customerCity),
            normalized(customerState),
            normalized(customerZipCode),
        ]
        guard parts.allSatisfy({ $0 != nil }) else { return nil }
        return "\(parts[0]!), \(parts[1]!), \(parts[2]!) \(parts[3]!)"
    }

    nonisolated private var reviewableFitReferenceDate: Date {
        if let completedAt,
           let completedDate = GroomingRequestDateFormatting.parsedDate(
                from: completedAt
           ) {
            return completedDate
        }

        if let scheduledEndDate = GroomingRequestDateFormatting.parsedDate(
            from: scheduledEnd
        ) {
            return scheduledEndDate
        }

        return Date()
    }

    nonisolated private var groomerLocationSummary: String? {
        let streetAddress = normalized(groomerBaseStreetAddress)
        let city = normalized(groomerBaseCity)
        let state = normalized(groomerBaseState)
        let zipCode = normalized(groomerBaseZipCode)

        if let streetAddress, let city, let state, let zipCode {
            return "\(streetAddress), \(city), \(state) \(zipCode)"
        }

        return switch (city, state) {
        case let (.some(city), .some(state)):
            if let zipCode {
                "\(city), \(state) \(zipCode)"
            } else {
                "\(city), \(state)"
            }
        case let (.some(city), nil):
            if let zipCode {
                "\(city) \(zipCode)"
            } else {
                city
            }
        case let (nil, .some(state)):
            if let zipCode {
                "\(state) \(zipCode)"
            } else {
                state
            }
        case (nil, nil):
            streetAddress ?? zipCode
        }
    }

    nonisolated private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct BookingReview: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let bookingID: UUID
    let customerID: UUID
    let groomerID: UUID
    let rating: Int
    let content: String?
    let createdAt: String
    let petFitOutcomes: [BookingReviewPetFitOutcomeRecord]

    nonisolated init(
        id: UUID,
        bookingID: UUID,
        customerID: UUID,
        groomerID: UUID,
        rating: Int,
        content: String?,
        createdAt: String,
        petFitOutcomes: [BookingReviewPetFitOutcomeRecord] = []
    ) {
        self.id = id
        self.bookingID = bookingID
        self.customerID = customerID
        self.groomerID = groomerID
        self.rating = rating
        self.content = content
        self.createdAt = createdAt
        self.petFitOutcomes = petFitOutcomes
    }

    nonisolated var ratingSummary: String {
        "\(rating)/5"
    }

    nonisolated var displayContent: String {
        guard let content, !content.isEmpty else {
            return "No written review."
        }
        return content
    }
}

nonisolated struct BookingReviewDraft: Equatable, Sendable {
    let rating: Int
    let content: String?
    let petFitOutcomes: [BookingReviewPetFitOutcomeDraft]

    init(
        rating: Int,
        content: String?,
        petFitOutcomes: [BookingReviewPetFitOutcomeDraft] = []
    ) {
        self.rating = rating
        self.content = content
        self.petFitOutcomes = petFitOutcomes
    }
}

nonisolated enum BookingReviewPetFitOutcome:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case positive
    case negative

    var id: Self { self }

    var title: String {
        switch self {
        case .positive:
            "Went Well"
        case .negative:
            "Needs Care"
        }
    }
}

nonisolated struct BookingReviewPetFitOutcomeRecord:
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    let signal: PetFitSignal
    let outcome: BookingReviewPetFitOutcome

    var title: String { signal.title }
    var groupTitle: String { signal.groupTitle }
}

nonisolated struct BookingReviewPetFitOutcomeDraft:
    Encodable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    let signal: PetFitSignal
    let outcome: BookingReviewPetFitOutcome

    var id: String { signal.id }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(signal.traitType, forKey: .traitType)
        try container.encode(signal.traitValue, forKey: .traitValue)
        try container.encode(outcome.rawValue, forKey: .outcome)
    }

    private enum CodingKeys: String, CodingKey {
        case traitType = "trait_type"
        case traitValue = "trait_value"
        case outcome
    }
}

nonisolated struct BookingReviewPetFitOutcomeSelection:
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    let signal: PetFitSignal
    var outcome: BookingReviewPetFitOutcome?

    var id: String { signal.id }
    var title: String { signal.title }
    var groupTitle: String { signal.groupTitle }

    var selectedOutcome: BookingReviewPetFitOutcomeDraft? {
        guard let outcome else { return nil }
        return BookingReviewPetFitOutcomeDraft(
            signal: signal,
            outcome: outcome
        )
    }

    static func defaults(
        for signals: [PetFitSignal]
    ) -> [BookingReviewPetFitOutcomeSelection] {
        signals.map { signal in
            BookingReviewPetFitOutcomeSelection(
                signal: signal,
                outcome: nil
            )
        }
    }
}

extension Array where Element == BookingReviewPetFitOutcomeSelection {
    var selectedOutcomes: [BookingReviewPetFitOutcomeDraft] {
        compactMap(\.selectedOutcome)
    }
}

nonisolated enum BookingStatus:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable
{
    case confirmed
    case completed
    case cancelledByCustomer = "cancelled_by_customer"
    case cancelledByGroomer = "cancelled_by_groomer"

    var title: String {
        switch self {
        case .confirmed:
            "Confirmed"
        case .completed:
            "Completed"
        case .cancelledByCustomer:
            "Cancelled by customer"
        case .cancelledByGroomer:
            "Cancelled by groomer"
        }
    }

    var isCancellation: Bool {
        switch self {
        case .cancelledByCustomer, .cancelledByGroomer:
            true
        case .confirmed, .completed:
            false
        }
    }
}

struct AcceptGroomerOfferResult: Equatable, Sendable {
    let bookingID: UUID
    let conversationID: UUID
    let requestID: UUID
    let offerID: UUID
    let bookingStatus: BookingStatus
    let offerStatus: GroomerOfferStatus
    let requestStatus: GroomingRequestStatus
}

struct CancelBookingResult: Equatable, Sendable {
    let bookingID: UUID
    let bookingStatus: BookingStatus
    let cancelledTimestamp: String?
    let cancelledBy: UUID?
}

struct CompleteBookingResult: Equatable, Sendable {
    let bookingID: UUID
    let bookingStatus: BookingStatus
    let completedTimestamp: String?
    let completedBy: UUID?
}

struct CreateReviewResult: Equatable, Sendable {
    let review: BookingReview
    let groomerRatingAverage: Double
    let groomerRatingCount: Int
}
