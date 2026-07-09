import Foundation
import Observation

@MainActor
@Observable
final class GroomerRequestsStore {
    static let minimumProposedStartLeadTime: TimeInterval = 5 * 60

    private let groomerID: UUID
    private let repository: any GroomerRequestRepository
    private let debugRecorder: AppDebugEventRecorder?

    private(set) var matchedRequests: [GroomerMatchedRequest] = []
    private(set) var requestPhotosByRequestID: [UUID: [GroomingRequestPhoto]] = [:]
    private(set) var requestPhotoDataByID: [UUID: Data] = [:]
    private(set) var isLoading = false
    private(set) var isDismissing = false
    private(set) var isSubmittingOffer = false
    private(set) var isWithdrawingOffer = false

    var errorMessage: String?
    var noticeMessage: String?

    var isBusy: Bool {
        isLoading || isDismissing || isSubmittingOffer || isWithdrawingOffer
    }

    init(
        groomerID: UUID,
        repository: any GroomerRequestRepository,
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.groomerID = groomerID
        self.repository = repository
        self.debugRecorder = debugRecorder
    }

    func matchedRequest(withID id: UUID) -> GroomerMatchedRequest? {
        matchedRequests.first { $0.id == id }
    }

    func requestPhotos(
        for matchedRequest: GroomerMatchedRequest
    ) -> [GroomingRequestPhoto] {
        requestPhotosByRequestID[matchedRequest.request.id, default: []]
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    $0.fileName < $1.fileName
                } else {
                    $0.sortOrder < $1.sortOrder
                }
            }
    }

    func requestPhotoData(for photo: GroomingRequestPhoto) -> Data? {
        requestPhotoDataByID[photo.id]
    }

    func load() async {
        let startedAt = Date()
        recordStoreStart("load")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            matchedRequests = try await repository.matchedRequests(
                groomerID: groomerID
            )
            try await loadRequestPhotos(for: matchedRequests)
            recordStoreSuccess(
                "load",
                startedAt: startedAt,
                metadata: [
                    "matchedRequestCount": "\(matchedRequests.count)",
                    "requestPhotoCount": "\(requestPhotosByRequestID.values.flatMap { $0 }.count)",
                    "downloadedPhotoCount": "\(requestPhotoDataByID.count)",
                ]
            )
        } catch GroomerRequestRepositoryError.cancelled {
            recordStoreCancelled("load", startedAt: startedAt)
        } catch let error as GroomerRequestRepositoryError {
            errorMessage = message(for: error, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("load", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func dismiss(_ matchedRequest: GroomerMatchedRequest) async {
        guard !isDismissing else { return }
        guard matchedRequest.match.status.isDismissible else {
            errorMessage = "This match can no longer be dismissed."
            return
        }

        isDismissing = true
        let startedAt = Date()
        recordStoreStart(
            "dismiss",
            metadata: ["matchID": matchedRequest.match.id.uuidString]
        )
        errorMessage = nil
        noticeMessage = nil
        defer { isDismissing = false }

        do {
            let result = try await repository.dismiss(
                matchID: matchedRequest.match.id,
                reason: nil
            )
            matchedRequests.removeAll { $0.match.id == result.matchID }
            noticeMessage = "Match dismissed."
            recordStoreSuccess("dismiss", startedAt: startedAt)
        } catch GroomerRequestRepositoryError.cancelled {
            recordStoreCancelled("dismiss", startedAt: startedAt)
        } catch let error as GroomerRequestRepositoryError {
            errorMessage = message(for: error, action: "dismiss")
            recordStoreFailure(
                "dismiss",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("dismiss", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "dismiss")
            recordStoreFailure(
                "dismiss",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func submitOffer(
        for matchedRequest: GroomerMatchedRequest,
        proposedStart: Date,
        proposedEnd: Date,
        priceEstimateText: String,
        message offerMessage: String,
        now: Date = Date()
    ) async {
        guard !isSubmittingOffer else { return }

        let startedAt = Date()
        errorMessage = nil
        noticeMessage = nil

        let draft: GroomerOfferDraft
        do {
            draft = try makeOfferDraft(
                matchedRequest: matchedRequest,
                proposedStart: proposedStart,
                proposedEnd: proposedEnd,
                priceEstimateText: priceEstimateText,
                message: offerMessage,
                now: now
            )
        } catch let error as GroomerOfferFormError {
            errorMessage = error.message
            recordStoreFailure(
                "submitOffer",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                level: .warning,
                metadata: ["requestID": matchedRequest.request.id.uuidString]
            )
            return
        } catch {
            errorMessage = "Check the offer details and try again."
            recordStoreFailure(
                "submitOffer",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                level: .warning,
                metadata: ["requestID": matchedRequest.request.id.uuidString]
            )
            return
        }

        isSubmittingOffer = true
        recordStoreStart(
            "submitOffer",
            metadata: ["requestID": draft.requestID.uuidString]
        )
        defer { isSubmittingOffer = false }

        do {
            let result = try await repository.createOffer(draft: draft)
            let offer = GroomerOffer(
                id: result.offerID,
                requestID: matchedRequest.request.id,
                matchID: matchedRequest.match.id,
                customerID: matchedRequest.request.customerID,
                groomerID: groomerID,
                proposedStart: GroomingRequestDateFormatting.serverString(
                    from: draft.proposedStart
                ),
                proposedEnd: GroomingRequestDateFormatting.serverString(
                    from: draft.proposedEnd
                ),
                priceEstimate: draft.priceEstimate,
                message: draft.message,
                status: result.offerStatus,
                expiresAt: matchedRequest.request.expiresAt,
                withdrawnAt: nil,
                createdAt: nil,
                updatedAt: nil
            )

            replace(
                matchedRequest.replacing(
                    matchStatus: .offered,
                    requestStatus: result.requestStatus,
                    offer: offer
                )
            )
            noticeMessage = "Offer submitted."
            recordStoreSuccess("submitOffer", startedAt: startedAt)
        } catch GroomerRequestRepositoryError.cancelled {
            recordStoreCancelled("submitOffer", startedAt: startedAt)
        } catch let error as GroomerRequestRepositoryError {
            errorMessage = message(for: error, action: "submit offer")
            recordStoreFailure(
                "submitOffer",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                metadata: ["requestID": draft.requestID.uuidString]
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("submitOffer", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "submit offer")
            recordStoreFailure(
                "submitOffer",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                metadata: ["requestID": draft.requestID.uuidString]
            )
        }
    }

    func withdrawOffer(for matchedRequest: GroomerMatchedRequest) async {
        guard !isWithdrawingOffer else { return }
        errorMessage = nil
        noticeMessage = nil

        guard let offer = matchedRequest.offer else {
            errorMessage = "No offer is available to withdraw."
            return
        }
        guard offer.status == .pending else {
            errorMessage = "This offer can no longer be withdrawn."
            return
        }

        isWithdrawingOffer = true
        let startedAt = Date()
        recordStoreStart(
            "withdrawOffer",
            metadata: ["offerID": offer.id.uuidString]
        )
        defer { isWithdrawingOffer = false }

        do {
            let result = try await repository.withdrawOffer(offerID: offer.id)
            replace(
                matchedRequest.replacing(
                    matchStatus: .viewed,
                    requestStatus: result.requestStatus,
                    offer: offer.replacing(
                        status: result.offerStatus,
                        withdrawnAt: result.withdrawnTimestamp
                    )
                )
            )
            noticeMessage = "Offer withdrawn."
            recordStoreSuccess("withdrawOffer", startedAt: startedAt)
        } catch GroomerRequestRepositoryError.cancelled {
            recordStoreCancelled("withdrawOffer", startedAt: startedAt)
        } catch let error as GroomerRequestRepositoryError {
            errorMessage = message(for: error, action: "withdraw offer")
            recordStoreFailure(
                "withdrawOffer",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                metadata: ["offerID": offer.id.uuidString]
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("withdrawOffer", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "withdraw offer")
            recordStoreFailure(
                "withdrawOffer",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                metadata: ["offerID": offer.id.uuidString]
            )
        }
    }

    static func defaultOfferRange(
        for request: GroomerMatchedGroomingRequest,
        now: Date = Date()
    ) -> (start: Date, end: Date) {
        let minimumStart = now.addingTimeInterval(minimumProposedStartLeadTime)
        if let preferredStart = GroomingRequestDateFormatting.parsedDate(
            from: request.preferredStart
        ),
           let preferredEnd = GroomingRequestDateFormatting.parsedDate(
               from: request.preferredEnd
           ),
           preferredStart >= minimumStart,
           preferredEnd > preferredStart {
            return (preferredStart, preferredEnd)
        }

        let start = now.addingTimeInterval(24 * 60 * 60)
        let end = start.addingTimeInterval(2 * 60 * 60)
        return (start, end)
    }

    private func makeOfferDraft(
        matchedRequest: GroomerMatchedRequest,
        proposedStart: Date,
        proposedEnd: Date,
        priceEstimateText: String,
        message: String,
        now: Date
    ) throws -> GroomerOfferDraft {
        guard matchedRequest.canCreateOffer else {
            throw GroomerOfferFormError(
                message: "This request can no longer receive offers."
            )
        }

        let minimumStart = now.addingTimeInterval(
            Self.minimumProposedStartLeadTime
        )
        guard proposedStart >= minimumStart else {
            throw GroomerOfferFormError(
                message: "Proposed start must be at least 5 minutes from now."
            )
        }

        guard proposedEnd > proposedStart else {
            throw GroomerOfferFormError(
                message: "Proposed end must be after the start time."
            )
        }

        let priceEstimate = try price(from: priceEstimateText)
        let normalizedMessage = try optional(
            message,
            field: "Message",
            maximum: 2000
        )

        return GroomerOfferDraft(
            requestID: matchedRequest.request.id,
            proposedStart: proposedStart,
            proposedEnd: proposedEnd,
            priceEstimate: priceEstimate,
            message: normalizedMessage
        )
    }

    private func price(from value: String) throws -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(
            of: #"^\d+(\.\d{1,2})?$"#,
            options: .regularExpression
        ) != nil,
            let price = Double(trimmed),
            price >= 0,
            price <= 100_000
        else {
            throw GroomerOfferFormError(
                message: "Price must be 0–100000 with at most 2 decimals."
            )
        }

        return price
    }

    private func optional(
        _ value: String,
        field: String,
        maximum: Int
    ) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= maximum else {
            throw GroomerOfferFormError(
                message: "\(field) must be \(maximum) characters or fewer."
            )
        }
        return trimmed
    }

    private func replace(_ matchedRequest: GroomerMatchedRequest) {
        guard let index = matchedRequests.firstIndex(
            where: { $0.id == matchedRequest.id }
        ) else { return }

        matchedRequests[index] = matchedRequest
    }

    private func loadRequestPhotos(
        for matchedRequests: [GroomerMatchedRequest]
    ) async throws {
        let photos = try await repository.requestPhotos(
            groomerID: groomerID,
            requestIDs: matchedRequests.map(\.request.id)
        )
        requestPhotosByRequestID = Dictionary(grouping: photos, by: \.requestID)
        requestPhotoDataByID = await requestPhotoDataMap(for: photos)
    }

    private func requestPhotoDataMap(
        for photos: [GroomingRequestPhoto]
    ) async -> [UUID: Data] {
        var dataByID: [UUID: Data] = [:]
        for photo in photos {
            guard let data = try? await repository.requestPhotoData(photo) else {
                continue
            }
            dataByID[photo.id] = data
        }
        return dataByID
    }

    private func message(
        for error: GroomerRequestRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) matched requests."
        case .matchNotFound:
            "This match is no longer available."
        case .noLongerDismissible:
            "This match can no longer be dismissed."
        case .requestNoLongerOpen:
            action == "dismiss"
                ? "This match can no longer be dismissed."
                : "This request can no longer receive offers."
        case .noLongerOfferable:
            "This request can no longer receive offers."
        case .activeOfferExists:
            "You already have an active offer for this request."
        case .groomerUnavailable:
            "Choose a time within your availability and outside time off."
        case .offerNotFound:
            "This offer is no longer available."
        case .noLongerWithdrawable:
            "This offer can no longer be withdrawn."
        case .invalidInput:
            action == "submit offer"
                ? "Check the offer details and try again."
                : "Check the match and try again."
        case .networkUnavailable:
            "Check your connection and try again."
        case .cancelled:
            "The request action was cancelled."
        case .unavailable:
            action.contains("offer")
                ? "We could not \(action). Please try again."
                : "We could not \(action) matched requests. Please try again."
        }
    }

    private var debugScope: String {
        "groomer.requests"
    }

    private func recordStoreStart(
        _ operation: String,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        eventMetadata["groomerID"] = groomerID.uuidString
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "GroomerRequestsStore.\(operation)",
            scope: debugScope,
            message: "start",
            metadata: eventMetadata
        )
    }

    private func recordStoreSuccess(
        _ operation: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "GroomerRequestsStore.\(operation)",
            scope: debugScope,
            message: "success",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

    private func recordStoreFailure(
        _ operation: String,
        error: any Error,
        mappedMessage: String?,
        startedAt: Date,
        level: AppDebugEventLevel = .error,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: level,
            category: .store,
            source: "GroomerRequestsStore.\(operation)",
            scope: debugScope,
            message: mappedMessage ?? "failure",
            underlyingError: error,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

    private func recordStoreCancelled(
        _ operation: String,
        startedAt: Date
    ) {
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "GroomerRequestsStore.\(operation)",
            scope: debugScope,
            message: "cancelled ignored",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation]
        )
    }
}

private struct GroomerOfferFormError: Error {
    let message: String
}
