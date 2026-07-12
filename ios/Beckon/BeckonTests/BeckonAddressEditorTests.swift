import Foundation
import Testing
@testable import Beckon

@Suite("Shared address editor")
struct BeckonAddressEditorTests {
    @Test @MainActor
    func completeSecondarySuffixMovesToLineTwoAndPublishesNotice() {
        let state = BeckonAddressEditorState(
            input: Self.input(line1: "770 S Harbor Blvd"),
            provider: AddressProviderFake()
        )

        state.updateLine1("770 S Harbor Blvd Unit 2410")

        #expect(state.input.line1 == "770 S Harbor Blvd")
        #expect(state.input.line2 == "Unit 2410")
        #expect(state.noticeMessage == "Unit 2410 was moved to Address Line 2.")
        #expect(state.secondaryConflict == nil)
    }

    @Test @MainActor
    func occupiedLineTwoCreatesInlineConflictWithoutOverwritingEitherField() {
        var input = Self.input(line1: "770 S Harbor Blvd")
        input.line2 = "Suite 300"
        let state = BeckonAddressEditorState(input: input, provider: AddressProviderFake())

        state.updateLine1("770 S Harbor Blvd Unit 2410")

        #expect(state.input.line1 == "770 S Harbor Blvd Unit 2410")
        #expect(state.input.line2 == "Suite 300")
        #expect(state.secondaryConflict == BeckonSecondaryAddressConflict(
            line1Secondary: "Unit 2410",
            existingLine2: "Suite 300"
        ))
        #expect(state.status == .needsReview)
    }

    @Test @MainActor
    func ordinaryTypingPreservesTrailingSpaceUntilACompleteSecondarySuffixExists() {
        let state = BeckonAddressEditorState(
            input: Self.input(line1: "770"),
            provider: AddressProviderFake()
        )

        state.updateLine1("770 ")
        #expect(state.input.line1 == "770 ")

        state.updateLine1("770 S ")
        #expect(state.input.line1 == "770 S ")
    }

    @Test @MainActor
    func selectingCandidatePrefillsAddressAndContinueConfirmsWithoutReview() async {
        let candidate = BeckonAddressCandidate(
            id: "candidate-1",
            primaryText: "770 S Harbor Blvd",
            secondaryText: "Fullerton, CA 92832"
        )
        let resolved = Self.resolved(line2: "Unit 2410")
        let provider = AddressProviderFake(
            suggestions: [candidate],
            resolvedByID: [candidate.id: resolved]
        )
        var input = Self.input(line1: "770")
        input.line2 = "Unit 2410"
        let state = BeckonAddressEditorState(input: input, provider: provider)

        await state.refreshSuggestions()
        await state.select(candidate)

        #expect(state.confirmation?.resolved == resolved)
        #expect(state.input == resolved.suggested)
        #expect(state.status == .needsReview)
        #expect(state.isReviewPresented == false)
        #expect(provider.resolvedCandidateIDs == [candidate.id])

        let result = await state.prepareConfirmation()

        #expect(result == .confirmed)
        #expect(!state.isReviewPresented)
        #expect(state.status == .confirmed)
        #expect(state.confirmedAddress?.accepted == resolved.suggested)
        #expect(state.input == resolved.suggested)
    }

    @Test @MainActor
    func uniqueEquivalentGeocodeConfirmsWithoutPresentingReview() async {
        let input = Self.input(line1: "770 S Harbor Blvd")
        let resolved = Self.resolved(line1: input.line1)
        let state = BeckonAddressEditorState(
            input: input,
            provider: AddressProviderFake(geocodeResults: [resolved])
        )

        let result = await state.prepareConfirmation()

        #expect(result == .confirmed)
        #expect(state.confirmedAddress?.accepted == resolved.suggested)
        #expect(!state.isReviewPresented)
    }

    @Test @MainActor
    func uniqueCorrectedGeocodePresentsReviewBeforeConfirmation() async {
        let state = BeckonAddressEditorState(
            input: Self.input(line1: "770 South Harbor Boulevard"),
            provider: AddressProviderFake(geocodeResults: [Self.resolved()])
        )

        let result = await state.prepareConfirmation()

        #expect(result == .needsReview)
        #expect(state.confirmation?.entered.line1 == "770 South Harbor Boulevard")
        #expect(state.isReviewPresented)
        #expect(state.confirmedAddress == nil)
    }

    @Test @MainActor
    func compatibleLineOneExtensionKeepsCurrentCandidatesUntilRefreshCompletes() async {
        let candidate = BeckonAddressCandidate(
            id: "candidate-1",
            primaryText: "770 S Harbor Blvd",
            secondaryText: "Fullerton, CA 92832"
        )
        let state = BeckonAddressEditorState(
            input: Self.input(line1: "770 S"),
            provider: AddressProviderFake(suggestions: [candidate])
        )
        await state.refreshSuggestions()
        #expect(state.candidates == [candidate])

        state.updateLine1("770 S H")

        #expect(state.candidates == [candidate])
    }

    @Test @MainActor
    func materialEditInvalidatesConfirmationButLineTwoEditPreservesResolution() {
        let state = BeckonAddressEditorState(
            input: Self.input(line1: "770 S Harbor Blvd"),
            provider: AddressProviderFake()
        )
        state.setConfirmedAddress(Self.confirmed())

        state.updateLine2("Unit 2410")
        #expect(state.confirmedAddress == nil)
        #expect(state.confirmation?.resolved.coordinate == Self.resolved().coordinate)
        #expect(state.status == .needsReview)

        state.setConfirmedAddress(Self.confirmed())
        state.updateCity("Anaheim")
        #expect(state.confirmedAddress == nil)
        #expect(state.confirmation == nil)
        #expect(state.status == .editing)
    }

    @Test @MainActor
    func manualGeocodeRequiresChoiceWhenAppleReturnsMultipleCompleteResults() async {
        let first = Self.resolved(line1: "770 S Harbor Blvd")
        let second = Self.resolved(line1: "780 S Harbor Blvd")
        let provider = AddressProviderFake(geocodeResults: [first, second])
        let state = BeckonAddressEditorState(
            input: Self.input(line1: "770 S Harbor Blvd"),
            provider: provider
        )

        await state.prepareConfirmation()

        #expect(state.manualChoices == [first, second])
        #expect(state.confirmation == nil)
        #expect(state.status == .needsReview)
        #expect(state.isReviewPresented)

        state.chooseManualResult(second)
        #expect(state.confirmation?.resolved == second)
        #expect(state.manualChoices.isEmpty)
    }

    @Test @MainActor
    func manualGeocodeFailureReturnsRecoverableMessage() async {
        let provider = AddressProviderFake(error: .noCompleteAddress)
        let state = BeckonAddressEditorState(
            input: Self.input(line1: "770 S Harbor Blvd"),
            provider: provider
        )

        await state.prepareConfirmation()

        #expect(state.status == .needsReview)
        #expect(state.inlineError == "We could not locate this service address. Check the street, city, state, and ZIP.")
    }

    @Test
    func sharedEditorSelectorsRemainStable() {
        #expect(BeckonAddressEditorSelectors.line1 == "beckon.address.line1")
        #expect(BeckonAddressEditorSelectors.line2 == "beckon.address.line2")
        #expect(BeckonAddressEditorSelectors.city == "beckon.address.city")
        #expect(BeckonAddressEditorSelectors.state == "beckon.address.state")
        #expect(BeckonAddressEditorSelectors.postalCode == "beckon.address.postal-code")
        #expect(BeckonAddressEditorSelectors.status == "beckon.address.status")
        #expect(BeckonAddressEditorSelectors.suggestions == "beckon.address.suggestions")
        #expect(BeckonAddressEditorSelectors.confirmation == "beckon.address.confirmation")
        #expect(BeckonAddressEditorSelectors.verify == "beckon.address.verify")
    }

    private static func input(line1: String) -> BeckonAddressInput {
        BeckonAddressInput(
            line1: line1,
            line2: "",
            city: "Fullerton",
            stateCode: .california,
            postalCode: "92832",
            countryCode: "US"
        )
    }

    private static func resolved(
        line1: String = "770 S Harbor Blvd",
        line2: String = ""
    ) -> BeckonResolvedAddress {
        BeckonResolvedAddress(
            provider: "apple_maps",
            placeID: nil,
            coordinate: BeckonAddressCoordinate(latitude: 33.8703, longitude: -117.9242),
            suggested: BeckonAddressInput(
                line1: line1,
                line2: line2,
                city: "Fullerton",
                stateCode: .california,
                postalCode: "92832",
                countryCode: "US"
            ),
            resolutionSource: "autocomplete_selection"
        )
    }

    private static func confirmed() -> BeckonConfirmedAddress {
        let input = input(line1: "770 S Harbor Blvd")
        return BeckonConfirmedAddress(
            entered: input,
            accepted: input,
            provider: "apple_maps",
            placeID: nil,
            coordinate: BeckonAddressCoordinate(latitude: 33.8703, longitude: -117.9242),
            resolutionSource: "autocomplete_selection",
            confirmedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

@MainActor
private final class AddressProviderFake: BeckonAddressProviding {
    let suggestions: [BeckonAddressCandidate]
    let resolvedByID: [String: BeckonResolvedAddress]
    let geocodeResults: [BeckonResolvedAddress]
    let error: BeckonAddressProviderError?
    private(set) var resolvedCandidateIDs: [String] = []

    init(
        suggestions: [BeckonAddressCandidate] = [],
        resolvedByID: [String: BeckonResolvedAddress] = [:],
        geocodeResults: [BeckonResolvedAddress] = [],
        error: BeckonAddressProviderError? = nil
    ) {
        self.suggestions = suggestions
        self.resolvedByID = resolvedByID
        self.geocodeResults = geocodeResults
        self.error = error
    }

    func updateSuggestions(for line1Query: String) async -> [BeckonAddressCandidate] {
        suggestions
    }

    func resolve(
        candidateID: String,
        preservingLine2: String
    ) async throws -> BeckonResolvedAddress {
        resolvedCandidateIDs.append(candidateID)
        if let error { throw error }
        guard let resolved = resolvedByID[candidateID] else {
            throw BeckonAddressProviderError.unknownCandidate
        }
        return resolved
    }

    func geocode(_ input: BeckonAddressInput) async throws -> [BeckonResolvedAddress] {
        if let error { throw error }
        return geocodeResults
    }

    func clear() {}
}
