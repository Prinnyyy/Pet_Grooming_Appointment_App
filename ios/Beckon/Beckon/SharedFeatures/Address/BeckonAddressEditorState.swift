import Observation
import Foundation

nonisolated enum BeckonAddressEditorStatus: Equatable, Sendable {
    case empty
    case editing
    case locating
    case confirmed
    case needsReview

    var title: String {
        switch self {
        case .empty, .editing:
            "Editing"
        case .locating:
            "Locating with Apple Maps"
        case .confirmed:
            "Confirmed with Apple Maps"
        case .needsReview:
            "Needs Review"
        }
    }
}

nonisolated enum BeckonAddressEditorSelectors {
    static let line1 = "beckon.address.line1"
    static let line1Container = "beckon.address.line1.container"
    static let line2 = "beckon.address.line2"
    static let line2Container = "beckon.address.line2.container"
    static let city = "beckon.address.city"
    static let cityContainer = "beckon.address.city.container"
    static let state = "beckon.address.state"
    static let postalCode = "beckon.address.postal-code"
    static let postalCodeContainer = "beckon.address.postal-code.container"
    static let status = "beckon.address.status"
    static let suggestions = "beckon.address.suggestions"
    static let confirmation = "beckon.address.confirmation"
    static let manualChoices = "beckon.address.manual-choices"
    static let verify = "beckon.address.verify"
}

nonisolated struct BeckonAddressConfirmationPresentation: Equatable, Identifiable, Sendable {
    let entered: BeckonAddressInput
    let resolved: BeckonResolvedAddress

    var id: String {
        [
            resolved.provider,
            resolved.placeID ?? "no-place-id",
            String(resolved.coordinate.latitude),
            String(resolved.coordinate.longitude),
            resolved.suggested.line2,
        ]
        .joined(separator: "|")
    }
}

nonisolated enum BeckonAddressPreparationResult: Equatable, Sendable {
    case confirmed
    case needsReview
    case unavailable
}

@MainActor
@Observable
final class BeckonAddressEditorState {
    var input: BeckonAddressInput
    private(set) var status: BeckonAddressEditorStatus
    private(set) var candidates: [BeckonAddressCandidate] = []
    private(set) var confirmation: BeckonAddressConfirmationPresentation?
    private(set) var confirmedAddress: BeckonConfirmedAddress?
    private(set) var manualChoices: [BeckonResolvedAddress] = []
    private(set) var isReviewPresented = false
    private(set) var secondaryConflict: BeckonSecondaryAddressConflict?
    private(set) var noticeMessage: String?
    private(set) var inlineError: String?
    private(set) var focusLine1Request = 0

    private let provider: any BeckonAddressProviding
    private var suggestionGeneration = 0

    init(input: BeckonAddressInput, provider: any BeckonAddressProviding) {
        self.input = input
        self.provider = provider
        status = input.line1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .empty
            : .editing
    }

    func updateLine1(_ value: String) {
        let previous = input
        let previousQuery = BeckonAddressQuery(street: previous.line1).searchStreet
        let result = BeckonSecondaryAddressParser.parse(line1: value, line2: input.line2)
        input.line1 = result.extractedSecondary == nil ? value : result.line1
        input.line2 = result.line2
        secondaryConflict = result.conflict
        noticeMessage = result.movedSecondary.map { "\($0) was moved to Address Line 2." }
        inlineError = result.conflict == nil
            ? nil
            : "Address Line 1 and Address Line 2 contain different unit details. Choose one before continuing."
        let nextQuery = BeckonAddressQuery(street: input.line1).searchStreet
        invalidateResolution(
            afterChangingFrom: previous,
            retainCandidates: BeckonAddressSuggestionRetention.shouldRetain(
                previousQuery: previousQuery,
                nextQuery: nextQuery
            )
        )
        if result.conflict != nil {
            status = .needsReview
        }
    }

    func updateLine2(_ value: String) {
        let previous = input
        input.line2 = String(value.prefix(60))
        secondaryConflict = nil
        inlineError = nil

        if let confirmedAddress,
           confirmedAddress.isBuildingResolutionValid(for: input) {
            let resolved = BeckonResolvedAddress(
                provider: confirmedAddress.provider,
                placeID: confirmedAddress.placeID,
                coordinate: confirmedAddress.coordinate,
                suggested: input,
                resolutionSource: confirmedAddress.resolutionSource
            )
            confirmation = BeckonAddressConfirmationPresentation(
                entered: input,
                resolved: resolved
            )
            self.confirmedAddress = nil
            status = .needsReview
            return
        }

        invalidateResolution(afterChangingFrom: previous)
    }

    func updateCity(_ value: String) {
        let previous = input
        input.city = value
        invalidateResolution(afterChangingFrom: previous)
    }

    func updateState(_ value: USStateCode?) {
        let previous = input
        input.stateCode = value
        invalidateResolution(afterChangingFrom: previous)
    }

    func updatePostalCode(_ value: String) {
        let previous = input
        input.postalCode = value
        invalidateResolution(afterChangingFrom: previous)
    }

    func refreshSuggestions() async {
        suggestionGeneration += 1
        let generation = suggestionGeneration
        let query = BeckonAddressQuery(street: input.line1).searchStreet
        guard query.count >= 3, secondaryConflict == nil else {
            candidates = []
            if query.count < 3 { provider.clear() }
            return
        }

        status = .locating
        let results = await provider.updateSuggestions(for: query)
        guard generation == suggestionGeneration else { return }
        candidates = Array(results.prefix(5))
        status = confirmedAddress == nil ? .editing : .confirmed
    }

    func select(_ candidate: BeckonAddressCandidate) async {
        status = .locating
        inlineError = nil
        do {
            let entered = input
            let resolved = try await provider.resolve(
                candidateID: candidate.id,
                preservingLine2: input.line2
            )
            candidates = []
            input = resolved.suggested
            confirmation = BeckonAddressConfirmationPresentation(
                entered: entered,
                resolved: resolved
            )
            manualChoices = []
            isReviewPresented = false
            status = .needsReview
        } catch is CancellationError {
            status = .editing
        } catch {
            recoverFromLookupFailure()
        }
    }

    func prepareConfirmation(requiringTimeZone: Bool = false) async -> BeckonAddressPreparationResult {
        if requiringTimeZone {
            if !hasResolvedTimeZone(confirmedAddress?.timeZoneIdentifier) { confirmedAddress = nil }
            if !hasResolvedTimeZone(confirmation?.resolved.timeZoneIdentifier) { confirmation = nil }
        }
        guard secondaryConflict == nil else {
            status = .needsReview
            return .unavailable
        }
        if confirmedAddress?.isBuildingResolutionValid(for: input) == true {
            status = .confirmed
            return .confirmed
        }
        if let confirmation {
            self.confirmation = BeckonAddressConfirmationPresentation(
                entered: input,
                resolved: confirmation.resolved
            )
            if addressesAreEquivalent(input, confirmation.resolved.suggested) {
                useSuggestedAddress()
                return .confirmed
            }
            isReviewPresented = true
            status = .needsReview
            return .needsReview
        }

        status = .locating
        inlineError = nil
        do {
            let results = try await provider.geocode(input)
            switch results.count {
            case 0:
                recoverFromLookupFailure()
                return .unavailable
            case 1:
                if requiringTimeZone, !hasResolvedTimeZone(results[0].timeZoneIdentifier) {
                    inlineError = "Apple Maps could not determine this address's time zone. Choose another address result."
                    status = .editing
                    return .unavailable
                }
                confirmation = BeckonAddressConfirmationPresentation(
                    entered: input,
                    resolved: results[0]
                )
                if addressesAreEquivalent(input, results[0].suggested) {
                    useSuggestedAddress()
                    return .confirmed
                }
                isReviewPresented = true
                status = .needsReview
                return .needsReview
            default:
                manualChoices = results
                isReviewPresented = true
                status = .needsReview
                return .needsReview
            }
        } catch is CancellationError {
            status = .editing
            return .unavailable
        } catch {
            recoverFromLookupFailure()
            return .unavailable
        }
    }

    private func hasResolvedTimeZone(_ identifier: String?) -> Bool {
        guard let identifier else { return false }
        return (try? GroomingServiceTiming.locationCalendar(identifier)) != nil
    }

    func chooseManualResult(_ resolved: BeckonResolvedAddress) {
        manualChoices = []
        confirmation = BeckonAddressConfirmationPresentation(
            entered: input,
            resolved: resolved
        )
        isReviewPresented = true
        status = .needsReview
    }

    func useSuggestedAddress(now: Date = .now) {
        guard let confirmation else { return }
        input = confirmation.resolved.suggested
        confirmedAddress = BeckonConfirmedAddress(
            entered: confirmation.entered,
            accepted: confirmation.resolved.suggested,
            provider: confirmation.resolved.provider,
            placeID: confirmation.resolved.placeID,
            coordinate: confirmation.resolved.coordinate,
            resolutionSource: confirmation.resolved.resolutionSource,
            confirmedAt: now,
            timeZoneIdentifier: confirmation.resolved.timeZoneIdentifier
        )
        self.confirmation = nil
        manualChoices = []
        isReviewPresented = false
        secondaryConflict = nil
        inlineError = nil
        status = .confirmed
    }

    func editAddress() {
        confirmation = nil
        manualChoices = []
        isReviewPresented = false
        confirmedAddress = nil
        status = .editing
        focusLine1Request += 1
    }

    func dismissSuggestions() {
        suggestionGeneration += 1
        candidates = []
    }

    func dismissPresentedReview() {
        confirmation = nil
        manualChoices = []
        isReviewPresented = false
        status = confirmedAddress == nil ? .editing : .confirmed
    }

    func consumeNotice() {
        noticeMessage = nil
    }

    func clear() {
        suggestionGeneration += 1
        provider.clear()
        candidates = []
        confirmation = nil
        manualChoices = []
        isReviewPresented = false
    }

    func setConfirmedAddress(_ address: BeckonConfirmedAddress?) {
        confirmedAddress = address
        confirmation = nil
        isReviewPresented = false
        status = address == nil ? .editing : .confirmed
    }

    func replaceInput(
        _ input: BeckonAddressInput,
        confirmedAddress: BeckonConfirmedAddress?
    ) {
        suggestionGeneration += 1
        provider.clear()
        self.input = input
        candidates = []
        confirmation = nil
        manualChoices = []
        isReviewPresented = false
        secondaryConflict = nil
        noticeMessage = nil
        inlineError = nil
        self.confirmedAddress = confirmedAddress
        status = confirmedAddress == nil
            ? (input.line1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing)
            : .confirmed
    }

    private func invalidateResolution(
        afterChangingFrom previous: BeckonAddressInput,
        retainCandidates: Bool = false
    ) {
        guard previous != input else { return }
        if !retainCandidates {
            candidates = []
        }
        manualChoices = []

        if let confirmedAddress,
           confirmedAddress.isBuildingResolutionValid(for: input) {
            if previous.line2 != input.line2 {
                let resolved = BeckonResolvedAddress(
                    provider: confirmedAddress.provider,
                    placeID: confirmedAddress.placeID,
                    coordinate: confirmedAddress.coordinate,
                    suggested: input,
                    resolutionSource: confirmedAddress.resolutionSource
                )
                confirmation = BeckonAddressConfirmationPresentation(
                    entered: input,
                    resolved: resolved
                )
                self.confirmedAddress = nil
                status = .needsReview
            } else {
                status = .confirmed
            }
            return
        }

        confirmedAddress = nil
        confirmation = nil
        status = input.line1.isEmpty ? .empty : .editing
    }

    private func recoverFromLookupFailure() {
        confirmation = nil
        manualChoices = []
        isReviewPresented = false
        status = .needsReview
        inlineError = "We could not locate this service address. Check the street, city, state, and ZIP."
    }

    private func addressesAreEquivalent(
        _ entered: BeckonAddressInput,
        _ suggested: BeckonAddressInput
    ) -> Bool {
        let enteredFields = [
            entered.line1,
            entered.line2,
            entered.city,
            entered.stateCode?.rawValue ?? "",
            entered.postalCode,
            entered.countryCode,
        ]
        let suggestedFields = [
            suggested.line1,
            suggested.line2,
            suggested.city,
            suggested.stateCode?.rawValue ?? "",
            suggested.postalCode,
            suggested.countryCode,
        ]
        return zip(enteredFields, suggestedFields).allSatisfy {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                == $1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }
}
