import Foundation
import Observation

@MainActor
@Observable
final class GroomerRequestsStore {
    private let groomerID: UUID
    private let repository: any GroomerRequestRepository

    private(set) var matchedRequests: [GroomerMatchedRequest] = []
    private(set) var isLoading = false
    private(set) var isDismissing = false

    var errorMessage: String?
    var noticeMessage: String?

    var isBusy: Bool {
        isLoading || isDismissing
    }

    init(
        groomerID: UUID,
        repository: any GroomerRequestRepository
    ) {
        self.groomerID = groomerID
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            matchedRequests = try await repository.matchedRequests(
                groomerID: groomerID
            )
        } catch let error as GroomerRequestRepositoryError {
            errorMessage = message(for: error, action: "load")
        } catch {
            errorMessage = message(for: .unavailable, action: "load")
        }
    }

    func dismiss(_ matchedRequest: GroomerMatchedRequest) async {
        guard !isDismissing else { return }
        guard matchedRequest.match.status.isDismissible else {
            errorMessage = "This match can no longer be dismissed."
            return
        }

        isDismissing = true
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
        } catch let error as GroomerRequestRepositoryError {
            errorMessage = message(for: error, action: "dismiss")
        } catch {
            errorMessage = message(for: .unavailable, action: "dismiss")
        }
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
        case .invalidInput:
            "Check the match and try again."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not \(action) matched requests. Please try again."
        }
    }
}
