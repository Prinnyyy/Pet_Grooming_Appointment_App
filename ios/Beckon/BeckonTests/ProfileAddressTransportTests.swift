import Foundation
import Supabase
import Testing
@testable import Beckon

@Suite("Profile address transport", .serialized)
struct ProfileAddressTransportTests {
    @Test @MainActor
    func reminderSnapshotUsesSingleOwnedRPCWithoutImageHydration() async throws {
        AddressTransportStub.state.reset(mode: .denied)
        do { _ = try await SupabaseBookingRepository(client: Self.client()).reminderSnapshot(participantID: UUID(), role: .customer) }
        catch { #expect(error as? BookingRepositoryError == .notAllowed) }
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/get_my_reminder_snapshot"])
    }
    @Test @MainActor
    func notificationTargetsUseExactOwnedOfferAndMatchReads() async throws {
        let owner = UUID(), requestID = UUID(), offerID = UUID()
        AddressTransportStub.state.reset(mode: .denied)
        do { _ = try await SupabaseCustomerRequestRepository(client: Self.client())
            .offer(customerID: owner, requestID: requestID, offerID: offerID) }
        catch { #expect(error as? CustomerRequestRepositoryError == .notAllowed) }
        let url = try #require(AddressTransportStub.state.urls.first)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(query.contains(URLQueryItem(name: "customer_id", value: "eq.\(owner.uuidString.lowercased())")))
        #expect(query.contains(URLQueryItem(name: "request_id", value: "eq.\(requestID.uuidString.lowercased())")))
        #expect(query.contains(URLQueryItem(name: "id", value: "eq.\(offerID.uuidString.lowercased())")))
        #expect(query.contains(URLQueryItem(name: "limit", value: "1")))
        AddressTransportStub.state.reset(mode: .denied)
        do { _ = try await SupabaseGroomerRequestRepository(client: Self.client()).matchedRequest(groomerID: owner, requestID: requestID) }
        catch { #expect(error as? GroomerRequestRepositoryError == .notAllowed) }
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/get_my_matched_request"])
    }

    @Test @MainActor
    func chatSummariesUseOneBoundedRPCAndExactPairQuery() async throws {
        AddressTransportStub.state.reset(mode: .chatSummaries)
        let customer = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let groomer = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        let repository = SupabaseChatRepository(client: Self.client())
        let conversations = try await repository.conversations(participantID: customer, role: .customer)
        #expect(conversations.count == 2)
        #expect(conversations.last?.latestMessageBody == "Quiet latest")
        #expect(AddressTransportStub.state.paths.filter { $0.hasSuffix("/get_conversation_summaries") }.count == 1)
        #expect(!AddressTransportStub.state.paths.contains("/rest/v1/messages"))
        #expect(!AddressTransportStub.state.paths.contains("/rest/v1/bookings"))
        AddressTransportStub.state.reset(mode: .denied)
        do { _ = try await repository.conversation(customerID: customer, groomerID: groomer, role: .customer) }
        catch { #expect(error as? ChatRepositoryError == .notAllowed) }
        let url = try #require(AddressTransportStub.state.urls.first)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(query.contains(URLQueryItem(name: "customer_id", value: "eq.\(customer.uuidString.lowercased())")))
        #expect(query.contains(URLQueryItem(name: "groomer_id", value: "eq.\(groomer.uuidString.lowercased())")))
        #expect(query.contains(URLQueryItem(name: "limit", value: "1")))
    }

    @Test @MainActor
    func scopedBookingAndExactRequestQueriesKeepServerFiltersAndTieOrdering() async throws {
        let owner = UUID()
        let now = ISO8601DateFormatter().date(from: "2026-11-01T00:00:00Z")!
        let client = Self.client()
        let repository = SupabaseBookingRepository(client: client)
        AddressTransportStub.state.reset(mode: .denied)
        do { _ = try await repository.nearestBooking(participantID: owner, role: .groomer, now: now) }
        catch { #expect(error as? BookingRepositoryError == .notAllowed) }
        let nearestURL = try #require(AddressTransportStub.state.urls.first)
        let nearest = URLComponents(url: nearestURL, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(nearest.contains(URLQueryItem(name: "groomer_id", value: "eq.\(owner.uuidString.lowercased())")))
        #expect(nearest.contains(URLQueryItem(name: "status", value: "eq.confirmed")))
        #expect(nearest.contains(URLQueryItem(name: "order", value: "scheduled_start.asc.nullslast,id.asc.nullslast")))
        #expect(nearest.contains(URLQueryItem(name: "limit", value: "1")))
        #expect(nearest.contains { $0.name == "scheduled_end" && $0.value?.hasPrefix("gte.") == true })
        AddressTransportStub.state.reset(mode: .denied)
        do { _ = try await repository.bookings(participantID: owner, role: .customer,
            interval: DateInterval(start: now, duration: 86400), page: .first.next) }
        catch { #expect(error as? BookingRepositoryError == .notAllowed) }
        let dateURL = try #require(AddressTransportStub.state.urls.first)
        let dateQuery = URLComponents(url: dateURL, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(dateQuery.contains(URLQueryItem(name: "customer_id", value: "eq.\(owner.uuidString.lowercased())")))
        #expect(dateQuery.contains(URLQueryItem(name: "order", value: "scheduled_start.asc.nullslast,id.asc.nullslast")))
        #expect(dateQuery.contains { $0.name == "scheduled_start" && $0.value?.hasPrefix("lt.") == true })
        #expect(dateQuery.contains { $0.name == "scheduled_end" && $0.value?.hasPrefix("gt.") == true })
        #expect(dateQuery.contains(URLQueryItem(name: "offset", value: "50")))
        #expect(dateQuery.contains(URLQueryItem(name: "limit", value: "51")))
        AddressTransportStub.state.reset(mode: .denied)
        let requestID = UUID()
        do { _ = try await SupabaseCustomerRequestRepository(client: client).request(customerID: owner, requestID: requestID) }
        catch { #expect(error as? CustomerRequestRepositoryError == .notAllowed) }
        let exactURL = try #require(AddressTransportStub.state.urls.first)
        let exact = URLComponents(url: exactURL, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(exact.contains(URLQueryItem(name: "id", value: "eq.\(requestID.uuidString.lowercased())")))
        #expect(exact.contains(URLQueryItem(name: "customer_id", value: "eq.\(owner.uuidString.lowercased())")))
        #expect(AddressTransportStub.state.paths.count == 1)
    }

    @Test(arguments: [
        ("timing_buffers_confirmation_required", GroomerRequestRepositoryError.timingBuffersRequired),
        ("schedule_timezone_confirmation_required", .scheduleTimeZoneRequired),
        ("service_timezone_confirmation_required", .serviceTimeZoneRequired),
        ("occupied_outside_weekly_hours", .groomerUnavailable),
        ("occupied_time_off_conflict", .groomerUnavailable),
        ("match_constraints_changed", .matchNotFound),
        ("invalid_duration", .invalidInput)
    ])
    @MainActor
    func offerTimingFailuresAreNotGenericInvalidInput(message: String, expected: GroomerRequestRepositoryError) async {
        AddressTransportStub.state.reset(mode: .timingFailure(message))
        let repository = SupabaseGroomerRequestRepository(client: Self.client())
        do {
            _ = try await repository.createOffer(draft: GroomerOfferDraft(requestID: UUID(),
                proposedStart: Date(), proposedEnd: Date().addingTimeInterval(3600), priceEstimate: 100, message: nil))
            Issue.record("Expected timing rejection")
        } catch let error as GroomerRequestRepositoryError {
            #expect(error == expected)
        } catch { Issue.record("Unexpected error: \(error)") }
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/create_groomer_offer_v2"])
    }

    @Test(arguments: [false, true]) @MainActor
    func matchedRequestQueryPreservesReferenceZone(legacy: Bool) async throws {
        AddressTransportStub.state.reset(mode: legacy ? .legacyMatchedRow : .matchedRow)
        let repository = SupabaseGroomerRequestRepository(client: Self.client())
        let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        let matches = try await repository.matchedRequests(groomerID: owner)
        #expect(matches.count == 1)
        let request = try #require(matches.first?.request)
        #expect(request.preferenceTimeZoneIdentifier == (legacy ? nil : "America/New_York"))
        #expect(request.preferredStart == "2026-11-02T04:00:00Z")
        let url = try #require(AddressTransportStub.state.urls.first { $0.path == "/rest/v1/grooming_requests" })
        let selected = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "select" }?.value)
        #expect(selected.split(separator: ",").contains("preference_time_zone_identifier"))
    }

    @Test(arguments: ["pending", "estimated_fit", "assessment_required", "excluded", "future_state"]) @MainActor
    func matchingEvaluationControlsOfferAvailability(state: String) async throws {
        AddressTransportStub.state.reset(mode: .matchedEvaluation(state))
        let repository = SupabaseGroomerRequestRepository(client: Self.client())
        let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        let item = try #require(try await repository.matchedRequests(groomerID: owner).first)
        #expect(item.match.eligibilityEvaluation?.state == state)
        #expect(item.canCreateOffer == (state == "estimated_fit" || state == "assessment_required"))
        #expect(item.match.replacing(status: .viewed).eligibilityEvaluation == item.match.eligibilityEvaluation)
        if state == "pending" { #expect(item.matchSummary == "Checking service and availability") }
        let url = try #require(AddressTransportStub.state.urls.first)
        #expect(url.path == "/rest/v1/rpc/get_my_matched_requests")
        let selected = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "select" }?.value)
        #expect(selected.split(separator: ",").contains("eligibility_evaluation"))
    }

    @Test(arguments: [false, true]) @MainActor
    func preciseQuoteQueryRetainsTimingAndRestrictsOwnerAndIdentity(legacy: Bool) async throws {
        AddressTransportStub.state.reset(mode: legacy ? .legacyTimingRow : .timingRow)
        let repository = SupabaseGroomerRequestRepository(client: Self.client())
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        let offer = try #require(await repository.offer(groomerID: owner, offerID: id))
        #expect(offer.id == id)
        #expect(offer.groomerID == owner)
        #expect(offer.timingSnapshotLoaded)
        #expect(offer.hasTimingSnapshot == !legacy)
        #expect(offer.requiresTimingUpdate == legacy)
        #expect(offer.serviceTimeZoneIdentifier == (legacy ? nil : "America/Los_Angeles"))
        #expect(offer.scheduleTimeZoneIdentifier == (legacy ? nil : "America/New_York"))
        #expect(AddressTransportStub.state.paths == ["/rest/v1/groomer_offers", "/rest/v1/rpc/get_quote_evaluations"])
        let url = try #require(AddressTransportStub.state.urls.first)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "groomer_id", value: "eq.\(owner.uuidString)")))
        #expect(items.contains(URLQueryItem(name: "id", value: "eq.\(id.uuidString)")))
        #expect(items.contains(URLQueryItem(name: "limit", value: "1")))
        try Self.expectSnapshotSelection(in: url)
    }

    @Test(arguments: [false, true]) @MainActor
    func bookingQueryPreservesSnapshotThroughOptionalHydration(legacy: Bool) async throws {
        AddressTransportStub.state.reset(mode: legacy ? .legacyTimingRow : .timingRow)
        let repository = SupabaseBookingRepository(client: Self.client())
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let bookings = try await repository.bookings(bookingIDs: [id])
        let booking = try #require(bookings.first)
        #expect(bookings.count == 1)
        #expect(booking.id == id)
        #expect(booking.serviceTimeZoneIdentifier == (legacy ? nil : "America/Los_Angeles"))
        #expect(booking.scheduleTimeZoneIdentifier == (legacy ? nil : "America/New_York"))
        #expect(booking.occupiedStart == (legacy ? nil : "2026-11-02T03:45:00Z"))
        #expect(booking.occupiedEnd == (legacy ? nil : "2026-11-02T05:10:00Z"))
        let expected = try GroomingTimingBuffers(preparation: 15, cleanup: 10, inboundTravel: 0, outboundTravel: 0)
        #expect(booking.appliedTimingBuffers == (legacy ? nil : expected))
        let url = try #require(AddressTransportStub.state.urls.first { $0.path == "/rest/v1/bookings" })
        try Self.expectSnapshotSelection(in: url)
    }

    private static func expectSnapshotSelection(in url: URL) throws {
        let selected = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "select" }?.value)
        let columns = Set(selected.split(separator: ",").map(String.init))
        #expect(Set(["applied_timing_buffers", "service_time_zone_identifier", "schedule_time_zone_identifier",
            "occupied_start", "occupied_end"]).isSubset(of: columns))
    }

    @Test @MainActor
    func legacyQuoteRequiresAnUpdatedOfferInsteadOfNetworkRecovery() async {
        AddressTransportStub.state.reset(mode: .legacyQuote)
        let repository = SupabaseBookingRepository(client: Self.client())
        do {
            _ = try await repository.acceptOffer(offerID: UUID())
            Issue.record("Legacy quote accepted without a timing snapshot")
        } catch {
            #expect(error as? BookingRepositoryError == .updatedOfferRequired)
        }
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/accept_groomer_offer"])
    }

    @Test(arguments: [false, true]) @MainActor
    func acceptanceScheduleChangeIsARecoverableBookingConflict(weeklyHours: Bool) async {
        AddressTransportStub.state.reset(mode: weeklyHours ? .occupiedHours : .occupiedTimeOff)
        let repository = SupabaseBookingRepository(client: Self.client())
        do {
            _ = try await repository.acceptOffer(offerID: UUID())
            Issue.record("Changed schedule accepted the quote")
        } catch {
            #expect(error as? BookingRepositoryError == .bookingConflict)
        }
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/accept_groomer_offer"])
    }

    @Test @MainActor
    func acceptanceConstraintsChangedDoesNotAskForInputCorrection() async {
        AddressTransportStub.state.reset(mode: .timingFailure("match_constraints_changed"))
        let repository = SupabaseBookingRepository(client: Self.client())
        do {
            _ = try await repository.acceptOffer(offerID: UUID())
            Issue.record("Changed eligibility accepted the quote")
        } catch {
            #expect(error as? BookingRepositoryError == .matchConstraintsChanged)
        }
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/accept_groomer_offer"])
    }

    @Test(arguments: [false, true]) @MainActor
    func availabilityOccupancyRejectionIsNotAnUncertainNetworkFailure(weeklyHours: Bool) async {
        AddressTransportStub.state.reset(mode: weeklyHours ? .weeklyHoursConflict : .bookingConflict)
        let repository = SupabaseGroomerProfileRepository(client: Self.client())
        do {
            _ = try await repository.saveAvailability(groomerID: UUID(), expectedRevision: "test", windows: [],
                preferences: GroomerBookingPreferencesDraft(maxAppointmentsPerDay: 4,
                    minimumAdvanceNoticeDays: 0, autoAcceptBookings: false), timeOff: [])
            Issue.record("Rejected occupancy was saved")
        } catch {
            #expect(error as? GroomerProfileRepositoryError == .bookingOccupancyConflict)
        }
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/save_groomer_availability"])
    }

    @Test @MainActor
    func unsupportedTimingBackendDoesNotWriteGroomerProfile() async {
        AddressTransportStub.state.reset(mode: .missing)
        let repository = SupabaseGroomerProfileRepository(client: Self.client())
        let draft = GroomerProfileDraft(businessName: nil, bio: nil, yearsExperience: nil,
            baseCity: nil, baseStateCode: nil, serviceRadiusMiles: nil, serviceLocationMode: nil, isActive: false)
        do {
            _ = try await repository.updateProfile(groomerID: UUID(), draft: draft, confirmedAddress: Self.address())
            Issue.record("Unsupported server wrote groomer profile")
        } catch {}
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/get_my_profile_address_v3"])
    }

    @Test @MainActor
    func supportedBackendAcceptsVersionedReadAndSave() async throws {
        AddressTransportStub.state.reset(mode: .available)
        let client = Self.client()
        try await ProfileAddressRPC.validateSaveSupport(client: client, address: Self.address())
        try await ProfileAddressRPC.save(client: client, legacyRPC: "legacy_address", address: Self.address())
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/get_my_profile_address_v3", "/rest/v1/rpc/save_my_profile_address_v3"])
    }

    @Test @MainActor
    func unsupportedTimingBackendIsCheckedBeforeProfileWrites() async throws {
        AddressTransportStub.state.reset(mode: .missing)
        let repository = SupabaseCustomerProfileRepository(client: Self.client())
        let address = Self.address()
        let draft = CustomerProfileDraft(nickname: "Test", streetAddress: "123 Test Street",
            addressLine2: "", city: "Anaheim", stateCode: .california, zipCode: "92805",
            contactEmail: "test@example.com", phoneNumber: "")
        do {
            _ = try await repository.updateProfile(customerID: UUID(), draft: draft, confirmedAddress: address)
            Issue.record("Unsupported server accepted versioned address save")
        } catch {}
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/get_my_profile_address_v3"])
    }

    @Test @MainActor
    func missingReadRPCFallsBackButPermissionFailureDoesNot() async throws {
        AddressTransportStub.state.reset(mode: .missing)
        let address = try await ProfileAddressRPC.load(client: Self.client(), legacyRPC: "legacy_address")
        #expect(address == nil)
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/get_my_profile_address_v3", "/rest/v1/rpc/legacy_address"])
        AddressTransportStub.state.reset(mode: .denied)
        do {
            _ = try await ProfileAddressRPC.load(client: Self.client(), legacyRPC: "legacy_address")
            Issue.record("Denied address read succeeded")
        } catch {}
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/get_my_profile_address_v3"])
    }

    @Test @MainActor
    func knownZoneWriteNeverDowngradesToLegacyRPC() async {
        AddressTransportStub.state.reset(mode: .missing)
        do {
            try await ProfileAddressRPC.save(client: Self.client(), legacyRPC: "legacy_address", address: Self.address())
            Issue.record("Missing write RPC succeeded")
        } catch {}
        #expect(AddressTransportStub.state.paths == ["/rest/v1/rpc/save_my_profile_address_v3"])
    }

    @MainActor private static func client() -> SupabaseClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AddressTransportStub.self]
        return SupabaseClient(supabaseURL: URL(string: "https://address-test.invalid")!, supabaseKey: "test-key",
            options: .init(global: .init(session: URLSession(configuration: configuration))))
    }

    private static func address() -> BeckonConfirmedAddress {
        let input = BeckonAddressInput(line1: "123 Test Street", line2: "", city: "Anaheim",
            stateCode: .california, postalCode: "92805", countryCode: "US")
        return BeckonConfirmedAddress(entered: input, accepted: input, provider: "apple_maps", placeID: nil,
            coordinate: BeckonAddressCoordinate(latitude: 33.83, longitude: -117.92),
            resolutionSource: "manual_geocode", confirmedAt: Date(), timeZoneIdentifier: "America/Los_Angeles")
    }
}

nonisolated private final class AddressTransportStub: URLProtocol, @unchecked Sendable {
    static let state = State()
    enum Mode: Equatable {
        case chatSummaries
        case missing, denied, available, bookingConflict, weeklyHoursConflict, occupiedHours, occupiedTimeOff, legacyQuote, timingRow, legacyTimingRow, matchedRow, legacyMatchedRow
        case timingFailure(String)
        case matchedEvaluation(String)
    }
    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [String] = []
        private var recordedURLs: [URL] = []
        private var mode = Mode.missing
        var paths: [String] { lock.withLock { recorded } }
        var urls: [URL] { lock.withLock { recordedURLs } }
        func reset(mode: Mode) { lock.withLock { self.mode = mode; recorded = []; recordedURLs = [] } }
        func response(url: URL) -> (Int, String) {
            lock.withLock {
                let path = url.path
                recorded.append(path)
                recordedURLs.append(url)
                if mode == .chatSummaries {
                    let customer = "00000000-0000-0000-0000-000000000004"
                    let groomer = "00000000-0000-0000-0000-000000000005"
                    let ids = ["00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002"]
                    let time = "2026-09-08T00:00:00Z"
                    let rows: [[String: Any]]
                    if path.hasSuffix("/conversations") {
                        rows = ids.map { ["id": $0, "customer_id": customer, "groomer_id": groomer,
                            "created_at": time, "updated_at": time] }
                    } else if path.hasSuffix("/get_conversation_summaries") {
                        rows = ids.enumerated().map { index, id in ["conversation_id": id,
                            "booking_summary": NSNull(), "latest_message": ["id": id,
                            "conversation_id": id, "sender_id": groomer, "kind": "text",
                            "body": index == 0 ? "Busy latest" : "Quiet latest", "created_at": time]] }
                    } else { rows = [] }
                    return (200, String(data: try! JSONSerialization.data(withJSONObject: rows), encoding: .utf8)!)
                }
                if case let .timingFailure(message) = mode {
                    let body = ["code": "22023", "message": message]
                    return (400, String(data: try! JSONSerialization.data(withJSONObject: body), encoding: .utf8)!)
                }
                let evaluationState: String?
                if case let .matchedEvaluation(value) = mode { evaluationState = value } else { evaluationState = nil }
                if mode == .matchedRow || mode == .legacyMatchedRow || evaluationState != nil {
                    guard path.hasSuffix("/get_my_matched_requests") || path.hasSuffix("/grooming_requests") else { return (200, "[]") }
                    let isMatch = path.hasSuffix("/get_my_matched_requests")
                    var row: [String: Any] = [
                        "id": "00000000-0000-0000-0000-000000000002",
                        "request_id": "00000000-0000-0000-0000-000000000002",
                        "customer_id": "00000000-0000-0000-0000-000000000004",
                        "groomer_id": "00000000-0000-0000-0000-000000000005",
                        "status": isMatch ? "visible" : "open",
                        "created_at": "2026-11-01T00:00:00Z", "updated_at": "2026-11-01T00:00:00Z",
                        "expires_at": "2026-11-03T00:00:00Z",
                        "preferred_start": "2026-11-02T04:00:00Z", "preferred_end": "2026-11-02T05:00:00Z",
                        "service_type": "bath_and_brush", "location_mode": "groomer_comes_to_customer",
                        "street_address": "1 Test Street", "city": "New York", "state": "NY", "zip_code": "10001",
                        "pet_snapshot": ["id": "00000000-0000-0000-0000-000000000006", "name": "Test", "species": "dog"],
                        "photo_snapshot": []
                    ]
                    if mode == .matchedRow { row["preference_time_zone_identifier"] = "America/New_York" }
                    if isMatch, let evaluationState {
                        row["eligibility_evaluation"] = ["state": evaluationState, "reason": "test_evaluation"]
                    }
                    return (200, String(data: try! JSONSerialization.data(withJSONObject: [row]), encoding: .utf8)!)
                }
                if mode == .timingRow || mode == .legacyTimingRow {
                    guard path.hasSuffix("/groomer_offers") || path.hasSuffix("/bookings") else { return (200, "[]") }
                    var row: [String: Any] = [
                        "id": "00000000-0000-0000-0000-000000000001",
                        "request_id": "00000000-0000-0000-0000-000000000002",
                        "match_id": "00000000-0000-0000-0000-000000000003",
                        "offer_id": "00000000-0000-0000-0000-000000000003",
                        "customer_id": "00000000-0000-0000-0000-000000000004",
                        "groomer_id": "00000000-0000-0000-0000-000000000005",
                        "proposed_start": "2026-11-02T04:00:00Z", "proposed_end": "2026-11-02T05:00:00Z",
                        "scheduled_start": "2026-11-02T04:00:00Z", "scheduled_end": "2026-11-02T05:00:00Z",
                        "price_estimate": 100, "status": path.hasSuffix("/bookings") ? "confirmed" : "pending",
                        "created_at": "2026-11-01T00:00:00Z", "updated_at": "2026-11-01T00:00:00Z",
                        "expires_at": "2026-11-03T00:00:00Z"
                    ]
                    if mode == .timingRow {
                        row["applied_timing_buffers"] = ["preparation_minutes": 15, "cleanup_minutes": 10,
                            "inbound_travel_minutes": 0, "outbound_travel_minutes": 0]
                        row["service_time_zone_identifier"] = "America/Los_Angeles"
                        row["schedule_time_zone_identifier"] = "America/New_York"
                        row["occupied_start"] = "2026-11-02T03:45:00Z"
                        row["occupied_end"] = "2026-11-02T05:10:00Z"
                    }
                    return (200, String(data: try! JSONSerialization.data(withJSONObject: [row]), encoding: .utf8)!)
                }
                if mode == .legacyQuote {
                    return (400, #"{"code":"P0001","message":"updated_timing_offer_required","details":null,"hint":null}"#)
                }
                if mode == .occupiedHours {
                    return (400, #"{"code":"22023","message":"occupied_outside_weekly_hours","details":null,"hint":null}"#)
                }
                if mode == .occupiedTimeOff {
                    return (400, #"{"code":"22023","message":"occupied_time_off_conflict","details":null,"hint":null}"#)
                }
                if mode == .weeklyHoursConflict {
                    return (400, #"{"code":"22023","message":"weekly_hours_conflict_with_booking_occupancy","details":null,"hint":null}"#)
                }
                if mode == .bookingConflict {
                    return (400, #"{"code":"22023","message":"time_off_conflicts_with_booking_occupancy","details":null,"hint":null}"#)
                }
                if path.hasSuffix("/legacy_address") { return (200, "[]") }
                if mode == .available {
                    return path.hasSuffix("/save_my_profile_address_v3")
                        ? (200, #""00000000-0000-0000-0000-000000000001""#)
                        : (200, #"{"timing_version":1,"address":null}"#)
                }
                return mode == .missing
                    ? (404, #"{"code":"PGRST202","message":"Function missing","details":null,"hint":null}"#)
                    : (403, #"{"code":"42501","message":"Denied","details":null,"hint":null}"#)
            }
        }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, body) = Self.state.response(url: request.url!)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
