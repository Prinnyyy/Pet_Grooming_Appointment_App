import Foundation
import Supabase

@MainActor
final class SupabaseBookingRepository: BookingRepository {
    private static let bookingColumns = """
        id,request_id,offer_id,customer_id,groomer_id,scheduled_start,scheduled_end,\
        price_estimate,status,cancelled_by,cancelled_at,completed_at,completed_by,\
        created_at,updated_at
        """
    private static let reviewColumns = """
        id,booking_id,customer_id,groomer_id,rating,content,created_at
        """
    private static let reviewPetFitOutcomeColumns = """
        id,review_id,booking_id,customer_id,groomer_id,trait_type,trait_value,\
        outcome,created_at
        """
    private static let groomerSummaryColumns =
        "user_id,business_name,base_street_address,base_city,base_state,base_zip_code"
    private static let requestLocationColumns =
        "id,service_type,pet_snapshot,location_mode,street_address,city,state,zip_code"

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        do {
            let participantColumn = switch role {
            case .customer:
                "customer_id"
            case .groomer:
                "groomer_id"
            }

            let rows: [BookingRow] = try await client
                .from("bookings")
                .select(Self.bookingColumns)
                .eq(participantColumn, value: participantID.uuidString.lowercased())
                .order("scheduled_start", ascending: false)
                .execute()
                .value

            let reviewMap = try await reviewsByBookingID(
                bookingIDs: rows.map(\.id)
            )
            let groomerSummaries = await groomerSummaries(
                for: rows.map(\.groomerID)
            )
            let requestLocations = await requestLocations(
                for: rows.map(\.requestID)
            )

            return rows.map { row in
                row.booking(
                    review: reviewMap[row.id],
                    groomerSummary: groomerSummaries[row.groomerID],
                    requestLocation: requestLocations[row.requestID]
                )
            }
        } catch {
            throw Self.map(error)
        }
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        do {
            let rows: [AcceptGroomerOfferRow] = try await client
                .rpc(
                    "accept_groomer_offer",
                    params: AcceptGroomerOfferParameters(offerID: offerID)
                )
                .execute()
                .value

            guard rows.count == 1, let result = rows.first?.result else {
                throw BookingRepositoryError.unavailable
            }

            return result
        } catch let error as BookingRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        do {
            let rows: [CancelBookingRow] = try await client
                .rpc(
                    "cancel_booking",
                    params: CancelBookingParameters(bookingID: bookingID)
                )
                .execute()
                .value

            guard rows.count == 1, let result = rows.first?.result else {
                throw BookingRepositoryError.unavailable
            }

            return result
        } catch let error as BookingRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        do {
            let rows: [CompleteBookingRow] = try await client
                .rpc(
                    "complete_booking",
                    params: CompleteBookingParameters(bookingID: bookingID)
                )
                .execute()
                .value

            guard rows.count == 1, let result = rows.first?.result else {
                throw BookingRepositoryError.unavailable
            }

            return result
        } catch let error as BookingRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        do {
            let rows: [CreateReviewRow] = try await client
                .rpc(
                    "create_review",
                    params: CreateReviewParameters(
                        bookingID: bookingID,
                        draft: draft
                    )
                )
                .execute()
                .value

            guard rows.count == 1, let result = rows.first?.result else {
                throw BookingRepositoryError.unavailable
            }

            return result
        } catch let error as BookingRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: any Error) -> BookingRepositoryError {
        if let repositoryError = error as? BookingRepositoryError {
            return repositoryError
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501", "28000":
                return .notAllowed
            case "22023":
                switch postgrestError.message {
                case "invalid_rating",
                     "invalid_review_content",
                     "invalid_review_outcomes",
                     "too_many_review_outcomes",
                     "invalid_review_outcome_trait",
                     "invalid_review_outcome_value",
                     "duplicate_review_outcome":
                    return .invalidReview
                default:
                    return .invalidInput
                }
            case "P0001":
                switch postgrestError.message {
                case "customer_profile_required", "groomer_profile_required":
                    return .notAllowed
                case "offer_not_found", "invalid_offer":
                    return .offerNotFound
                case "offer_not_pending", "offer_expired":
                    return .offerNoLongerPending
                case "match_not_offerable", "request_not_open":
                    return .requestNoLongerOpen
                case "booking_already_exists":
                    return .bookingAlreadyExists
                case "booking_conflict":
                    return .bookingConflict
                case "booking_not_found", "invalid_booking":
                    return .bookingNotFound
                case "booking_not_cancellable":
                    return .bookingNotCancellable
                case "booking_not_completable":
                    return .bookingNotCompletable
                case "booking_not_completed":
                    return .bookingNotCompleted
                case "review_already_exists":
                    return .reviewAlreadyExists
                default:
                    return .unavailable
                }
            case "23514":
                return .invalidReview
            default:
                return .unavailable
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                return .networkUnavailable
            default:
                return .unavailable
            }
        }

        return .unavailable
    }

    private func reviewsByBookingID(
        bookingIDs: [UUID]
    ) async throws -> [UUID: BookingReview] {
        let ids = Array(Set(bookingIDs)).map { $0.uuidString.lowercased() }
        guard !ids.isEmpty else { return [:] }

        let rows: [BookingReviewRow] = try await client
            .from("reviews")
            .select(Self.reviewColumns)
            .in("booking_id", values: ids)
            .execute()
            .value

        let outcomesByReviewID = try await reviewPetFitOutcomesByReviewID(
            reviewIDs: rows.map(\.id)
        )

        return Dictionary(
            uniqueKeysWithValues: rows.map {
                (
                    $0.bookingID,
                    $0.review(
                        petFitOutcomes: outcomesByReviewID[$0.id, default: []]
                    )
                )
            }
        )
    }

    private func reviewPetFitOutcomesByReviewID(
        reviewIDs: [UUID]
    ) async throws -> [UUID: [BookingReviewPetFitOutcomeRecord]] {
        let ids = uniqueLowercaseStrings(from: reviewIDs)
        guard !ids.isEmpty else { return [:] }

        let rows: [BookingReviewPetFitOutcomeRow] = try await client
            .from("review_pet_fit_outcomes")
            .select(Self.reviewPetFitOutcomeColumns)
            .in("review_id", values: ids)
            .order("created_at")
            .execute()
            .value

        var recordsByReviewID: [UUID: [BookingReviewPetFitOutcomeRecord]] = [:]
        for row in rows {
            guard let record = row.record else { continue }
            recordsByReviewID[row.reviewID, default: []].append(record)
        }

        return recordsByReviewID.mapValues {
            $0.sorted {
                if $0.signal.sortOrder == $1.signal.sortOrder {
                    $0.title < $1.title
                } else {
                    $0.signal.sortOrder < $1.signal.sortOrder
                }
            }
        }
    }

    private func groomerSummaries(
        for groomerIDs: [UUID]
    ) async -> [UUID: BookingGroomerSummary] {
        let ids = uniqueLowercaseStrings(from: groomerIDs)
        guard !ids.isEmpty else { return [:] }

        do {
            let rows: [BookingGroomerSummaryRow] = try await client
                .from("groomer_profiles")
                .select(Self.groomerSummaryColumns)
                .in("user_id", values: ids)
                .execute()
                .value

            return Dictionary(
                uniqueKeysWithValues: rows.map { ($0.userID, $0.summary) }
            )
        } catch {
            return [:]
        }
    }

    private func requestLocations(
        for requestIDs: [UUID]
    ) async -> [UUID: BookingRequestLocation] {
        let ids = uniqueLowercaseStrings(from: requestIDs)
        guard !ids.isEmpty else { return [:] }

        do {
            let rows: [BookingRequestLocationRow] = try await client
                .from("grooming_requests")
                .select(Self.requestLocationColumns)
                .in("id", values: ids)
                .execute()
                .value

            return Dictionary(
                uniqueKeysWithValues: rows.map { ($0.id, $0.location) }
            )
        } catch {
            return [:]
        }
    }

    private func uniqueLowercaseStrings(from ids: [UUID]) -> [String] {
        Array(Set(ids)).map { $0.uuidString.lowercased() }
    }
}

private struct BookingRow: Decodable {
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

    func booking(
        review: BookingReview?,
        groomerSummary: BookingGroomerSummary?,
        requestLocation: BookingRequestLocation?
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
            serviceType: requestLocation?.serviceType,
            requestPetSnapshot: requestLocation?.petSnapshot,
            groomerBusinessName: groomerSummary?.businessName,
            groomerBaseStreetAddress: groomerSummary?.baseStreetAddress,
            groomerBaseCity: groomerSummary?.baseCity,
            groomerBaseState: groomerSummary?.baseState,
            groomerBaseZipCode: groomerSummary?.baseZipCode,
            locationMode: requestLocation?.locationMode,
            customerStreetAddress: requestLocation?.streetAddress,
            customerCity: requestLocation?.city,
            customerState: requestLocation?.state,
            customerZipCode: requestLocation?.zipCode
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requestID = "request_id"
        case offerID = "offer_id"
        case customerID = "customer_id"
        case groomerID = "groomer_id"
        case scheduledStart = "scheduled_start"
        case scheduledEnd = "scheduled_end"
        case priceEstimate = "price_estimate"
        case status
        case cancelledBy = "cancelled_by"
        case cancelledAt = "cancelled_at"
        case completedAt = "completed_at"
        case completedBy = "completed_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct BookingGroomerSummary: Sendable {
    let businessName: String?
    let baseStreetAddress: String?
    let baseCity: String?
    let baseState: String?
    let baseZipCode: String?
}

private struct BookingGroomerSummaryRow: Decodable {
    let userID: UUID
    let businessName: String?
    let baseStreetAddress: String?
    let baseCity: String?
    let baseState: String?
    let baseZipCode: String?

    var summary: BookingGroomerSummary {
        BookingGroomerSummary(
            businessName: businessName,
            baseStreetAddress: baseStreetAddress,
            baseCity: baseCity,
            baseState: baseState,
            baseZipCode: baseZipCode
        )
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case businessName = "business_name"
        case baseStreetAddress = "base_street_address"
        case baseCity = "base_city"
        case baseState = "base_state"
        case baseZipCode = "base_zip_code"
    }
}

private struct BookingRequestLocation: Sendable {
    let serviceType: GroomingServiceType
    let petSnapshot: GroomingRequestPetSnapshot
    let locationMode: GroomingLocationMode
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String
}

private struct BookingRequestLocationRow: Decodable {
    let id: UUID
    let serviceType: GroomingServiceType
    let petSnapshot: GroomingRequestPetSnapshot
    let locationMode: GroomingLocationMode
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String

    var location: BookingRequestLocation {
        BookingRequestLocation(
            serviceType: serviceType,
            petSnapshot: petSnapshot,
            locationMode: locationMode,
            streetAddress: streetAddress,
            city: city,
            state: state,
            zipCode: zipCode
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case serviceType = "service_type"
        case petSnapshot = "pet_snapshot"
        case locationMode = "location_mode"
        case streetAddress = "street_address"
        case city
        case state
        case zipCode = "zip_code"
    }
}

private struct BookingReviewRow: Decodable {
    let id: UUID
    let bookingID: UUID
    let customerID: UUID
    let groomerID: UUID
    let rating: Int
    let content: String?
    let createdAt: String

    func review(
        petFitOutcomes: [BookingReviewPetFitOutcomeRecord] = []
    ) -> BookingReview {
        BookingReview(
            id: id,
            bookingID: bookingID,
            customerID: customerID,
            groomerID: groomerID,
            rating: rating,
            content: content,
            createdAt: createdAt,
            petFitOutcomes: petFitOutcomes
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case bookingID = "booking_id"
        case customerID = "customer_id"
        case groomerID = "groomer_id"
        case rating
        case content
        case createdAt = "created_at"
    }
}

private struct BookingReviewPetFitOutcomeRow: Decodable {
    let id: UUID
    let reviewID: UUID
    let bookingID: UUID
    let customerID: UUID
    let groomerID: UUID
    let traitType: String
    let traitValue: String
    let outcomeRawValue: String
    let createdAt: String

    var record: BookingReviewPetFitOutcomeRecord? {
        guard let signal = PetFitSignal.stored(
            traitType: traitType,
            traitValue: traitValue
        ),
              let outcome = BookingReviewPetFitOutcome(rawValue: outcomeRawValue)
        else {
            return nil
        }

        return BookingReviewPetFitOutcomeRecord(
            id: id,
            signal: signal,
            outcome: outcome
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case reviewID = "review_id"
        case bookingID = "booking_id"
        case customerID = "customer_id"
        case groomerID = "groomer_id"
        case traitType = "trait_type"
        case traitValue = "trait_value"
        case outcomeRawValue = "outcome"
        case createdAt = "created_at"
    }
}

private struct AcceptGroomerOfferRow: Decodable {
    let bookingID: UUID
    let conversationID: UUID
    let requestID: UUID
    let offerID: UUID
    let bookingStatus: BookingStatus
    let offerStatus: GroomerOfferStatus
    let requestStatus: GroomingRequestStatus

    var result: AcceptGroomerOfferResult {
        AcceptGroomerOfferResult(
            bookingID: bookingID,
            conversationID: conversationID,
            requestID: requestID,
            offerID: offerID,
            bookingStatus: bookingStatus,
            offerStatus: offerStatus,
            requestStatus: requestStatus
        )
    }

    private enum CodingKeys: String, CodingKey {
        case bookingID = "booking_id"
        case conversationID = "conversation_id"
        case requestID = "request_id"
        case offerID = "offer_id"
        case bookingStatus = "booking_status"
        case offerStatus = "offer_status"
        case requestStatus = "request_status"
    }
}

private struct CancelBookingRow: Decodable {
    let bookingID: UUID
    let bookingStatus: BookingStatus
    let cancelledTimestamp: String?
    let cancelledBy: UUID?

    var result: CancelBookingResult {
        CancelBookingResult(
            bookingID: bookingID,
            bookingStatus: bookingStatus,
            cancelledTimestamp: cancelledTimestamp,
            cancelledBy: cancelledBy
        )
    }

    private enum CodingKeys: String, CodingKey {
        case bookingID = "booking_id"
        case bookingStatus = "booking_status"
        case cancelledTimestamp = "cancelled_timestamp"
        case cancelledBy = "cancelled_by"
    }
}

private struct CompleteBookingRow: Decodable {
    let bookingID: UUID
    let bookingStatus: BookingStatus
    let completedTimestamp: String?
    let completedBy: UUID?

    var result: CompleteBookingResult {
        CompleteBookingResult(
            bookingID: bookingID,
            bookingStatus: bookingStatus,
            completedTimestamp: completedTimestamp,
            completedBy: completedBy
        )
    }

    private enum CodingKeys: String, CodingKey {
        case bookingID = "booking_id"
        case bookingStatus = "booking_status"
        case completedTimestamp = "completed_timestamp"
        case completedBy = "completed_by"
    }
}

private struct CreateReviewRow: Decodable {
    let reviewID: UUID
    let bookingID: UUID
    let customerID: UUID
    let groomerID: UUID
    let rating: Int
    let content: String?
    let createdAt: String
    let groomerRatingAverage: Double
    let groomerRatingCount: Int

    var result: CreateReviewResult {
        CreateReviewResult(
            review: BookingReview(
                id: reviewID,
                bookingID: bookingID,
                customerID: customerID,
                groomerID: groomerID,
                rating: rating,
                content: content,
                createdAt: createdAt
            ),
            groomerRatingAverage: groomerRatingAverage,
            groomerRatingCount: groomerRatingCount
        )
    }

    private enum CodingKeys: String, CodingKey {
        case reviewID = "review_id"
        case bookingID = "booking_id"
        case customerID = "customer_id"
        case groomerID = "groomer_id"
        case rating
        case content
        case createdAt = "created_at"
        case groomerRatingAverage = "groomer_rating_avg"
        case groomerRatingCount = "groomer_rating_count"
    }
}

private struct AcceptGroomerOfferParameters: Encodable {
    let offerID: UUID

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(offerID.uuidString.lowercased(), forKey: .offerID)
    }

    private enum CodingKeys: String, CodingKey {
        case offerID = "p_offer_id"
    }
}

private struct CancelBookingParameters: Encodable {
    let bookingID: UUID

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookingID.uuidString.lowercased(), forKey: .bookingID)
    }

    private enum CodingKeys: String, CodingKey {
        case bookingID = "p_booking_id"
    }
}

private struct CompleteBookingParameters: Encodable {
    let bookingID: UUID

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookingID.uuidString.lowercased(), forKey: .bookingID)
    }

    private enum CodingKeys: String, CodingKey {
        case bookingID = "p_booking_id"
    }
}

nonisolated struct CreateReviewParameters: Encodable {
    let bookingID: UUID
    let draft: BookingReviewDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookingID.uuidString.lowercased(), forKey: .bookingID)
        try container.encode(draft.rating, forKey: .rating)

        if let content = draft.content {
            try container.encode(content, forKey: .content)
        } else {
            try container.encodeNil(forKey: .content)
        }

        try container.encode(draft.petFitOutcomes, forKey: .petFitOutcomes)
    }

    private enum CodingKeys: String, CodingKey {
        case bookingID = "p_booking_id"
        case rating = "p_rating"
        case content = "p_content"
        case petFitOutcomes = "p_pet_fit_outcomes"
    }
}
