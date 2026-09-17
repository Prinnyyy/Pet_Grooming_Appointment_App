import Foundation
import Observation

enum AuthenticatedEntryState: Equatable {
    case loading
    case onboarding
    case customer(MarketplaceProfile)
    case groomer(MarketplaceProfile)
    case failure(message: String)
}

@MainActor
@Observable
final class AuthenticatedEntryStore {
    private let repository: any ProfileRepository

    private(set) var userID: UUID?
    var state: AuthenticatedEntryState = .loading
    var displayName = ""
    var selectedRole: UserRole?
    var isSubmitting = false
    var errorMessage: String?

    init(repository: any ProfileRepository) {
        self.repository = repository
    }

    func load(userID: UUID) async {
        self.userID = userID
        state = .loading
        errorMessage = nil

        do {
            if let profile = try await repository.profile(userID: userID) {
                route(to: profile)
            } else {
                state = .onboarding
            }
        } catch {
            state = .failure(
                message: "We could not load your profile. Please try again."
            )
        }
    }

    func retry() async {
        guard let userID else { return }
        await load(userID: userID)
    }

    func submit() async {
        guard !isSubmitting else { return }

        errorMessage = nil

        let normalizedName = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard (1...80).contains(normalizedName.count) else {
            errorMessage = "Enter a display name between 1 and 80 characters."
            return
        }

        guard let selectedRole else {
            errorMessage = "Choose Customer or Groomer to continue."
            return
        }

        displayName = normalizedName
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let profile = try await repository.createProfile(
                role: selectedRole,
                displayName: normalizedName
            )
            route(to: profile)
        } catch let error as ProfileRepositoryError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = message(for: .unavailable)
        }
    }

    private func route(to profile: MarketplaceProfile) {
        switch profile.role {
        case .customer:
            state = .customer(profile)
        case .groomer:
            state = .groomer(profile)
        }
    }

    private func message(for error: ProfileRepositoryError) -> String {
        switch error {
        case .roleImmutable:
            "Your account role is already set and cannot be changed here."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not create your profile. Please try again."
        }
    }
}
