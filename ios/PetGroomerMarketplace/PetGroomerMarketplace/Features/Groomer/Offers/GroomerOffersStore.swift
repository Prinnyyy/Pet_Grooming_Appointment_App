import Foundation
import Observation

@MainActor
@Observable
final class GroomerOffersStore {
    private let groomerID: UUID
    private let repository: any GroomerRequestRepository

    private(set) var offers: [GroomerOfferListItem] = []
    private(set) var isLoading = false

    var errorMessage: String?

    var sections: [GroomerOfferListSection] {
        GroomerOfferStatus.displayOrder.compactMap { status in
            let matchingOffers = offers.filter { $0.offer.status == status }
            guard !matchingOffers.isEmpty else {
                return nil
            }

            return GroomerOfferListSection(
                status: status,
                offers: matchingOffers
            )
        }
    }

    init(
        groomerID: UUID,
        repository: any GroomerRequestRepository
    ) {
        self.groomerID = groomerID
        self.repository = repository
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            offers = Self.displayOrdered(
                try await repository.offers(groomerID: groomerID)
            )
        } catch GroomerRequestRepositoryError.cancelled {
            return
        } catch let error as GroomerRequestRepositoryError {
            errorMessage = Self.message(for: error)
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            return
        } catch {
            errorMessage = Self.message(for: .unavailable)
        }
    }

    private static func displayOrdered(
        _ offers: [GroomerOfferListItem]
    ) -> [GroomerOfferListItem] {
        offers.sorted { lhs, rhs in
            if lhs.createdAtDate == rhs.createdAtDate {
                return lhs.offer.id.uuidString < rhs.offer.id.uuidString
            }

            return lhs.createdAtDate > rhs.createdAtDate
        }
    }

    private static func message(
        for error: GroomerRequestRepositoryError
    ) -> String {
        switch error {
        case .networkUnavailable:
            "Offers unavailable. Check your connection and try again."
        case .notAllowed:
            "Sign in with a groomer account to view offers."
        case .cancelled:
            ""
        case .matchNotFound,
             .noLongerDismissible,
             .requestNoLongerOpen,
             .noLongerOfferable,
             .activeOfferExists,
             .groomerUnavailable,
             .offerNotFound,
             .noLongerWithdrawable,
             .invalidInput,
             .unavailable:
            "Offers unavailable. Try again in a moment."
        }
    }
}

private extension GroomerOfferStatus {
    static let displayOrder: [GroomerOfferStatus] = [
        .pending,
        .acceptedByCustomer,
        .declinedByCustomer,
        .withdrawnByGroomer,
        .expired,
        .unknown,
    ]
}
