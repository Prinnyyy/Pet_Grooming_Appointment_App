import Observation
import SwiftUI

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

    func prepareConfirmation() async -> BeckonAddressPreparationResult {
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
            confirmedAt: now
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

private struct BeckonAddressLineOneBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(
        value: inout Anchor<CGRect>?,
        nextValue: () -> Anchor<CGRect>?
    ) {
        value = nextValue() ?? value
    }
}

struct BeckonAddressEditor: View {
    @Bindable var state: BeckonAddressEditorState
    @Environment(\.beckonFeedbackCenter) private var feedbackCenter
    let isStateInvalid: Bool
    let showsVerificationAction: Bool
    let onFieldFocused: (String) -> Void

    init(
        state: BeckonAddressEditorState,
        isStateInvalid: Bool = false,
        showsVerificationAction: Bool = true,
        onFieldFocused: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.isStateInvalid = isStateInvalid
        self.showsVerificationAction = showsVerificationAction
        self.onFieldFocused = onFieldFocused
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            labeledField("Address Line 1") {
                BeckonLimitedTextField(
                    placeholder: "Street address",
                    text: Binding(
                        get: { state.input.line1 },
                        set: { state.updateLine1($0) }
                    ),
                    maximumLength: 160,
                    isInvalid: state.secondaryConflict != nil,
                    textContentType: .streetAddressLine1,
                    autocapitalizationType: .words,
                    addressInputRule: .street,
                    onEditingBegan: {
                        onFieldFocused(BeckonAddressEditorSelectors.line1Container)
                    },
                    onTextChange: { _ in
                        Task { await state.refreshSuggestions() }
                    }
                )
                .accessibilityLabel("Address Line 1")
                .accessibilityIdentifier(BeckonAddressEditorSelectors.line1)
                .anchorPreference(
                    key: BeckonAddressLineOneBoundsKey.self,
                    value: .bounds
                ) {
                    $0
                }
            }
            .beckonKeyboardFocusTarget(BeckonAddressEditorSelectors.line1Container)

            labeledField("Address Line 2", detail: "Optional") {
                BeckonLimitedTextField(
                    placeholder: "Apt, unit, suite, floor",
                    text: Binding(
                        get: { state.input.line2 },
                        set: { state.updateLine2($0) }
                    ),
                    maximumLength: 60,
                    textContentType: .streetAddressLine2,
                    autocapitalizationType: .words,
                    addressInputRule: .street,
                    onEditingBegan: {
                        state.dismissSuggestions()
                        onFieldFocused(BeckonAddressEditorSelectors.line2Container)
                    },
                    onTextChange: { _ in }
                )
                .accessibilityLabel("Address Line 2, optional")
                .accessibilityIdentifier(BeckonAddressEditorSelectors.line2)
            }
            .beckonKeyboardFocusTarget(BeckonAddressEditorSelectors.line2Container)

            if let error = state.inlineError {
                Text(error)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.error)
                    .accessibilityLabel("Address error: \(error)")
            }

            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                labeledField("City") {
                    BeckonLimitedTextField(
                        placeholder: "City",
                        text: Binding(
                            get: { state.input.city },
                            set: { state.updateCity($0) }
                        ),
                        maximumLength: 100,
                        textContentType: .addressCity,
                        autocapitalizationType: .words,
                        addressInputRule: .city,
                        onEditingBegan: {
                            state.dismissSuggestions()
                            onFieldFocused(BeckonAddressEditorSelectors.cityContainer)
                        },
                        onTextChange: { _ in }
                    )
                    .accessibilityIdentifier(BeckonAddressEditorSelectors.city)
                }
                .beckonKeyboardFocusTarget(BeckonAddressEditorSelectors.cityContainer)

                labeledField("State") {
                    Menu {
                        ForEach(USStateCode.allCases) { stateCode in
                            Button(stateCode.rawValue) {
                                state.updateState(stateCode)
                            }
                        }
                    } label: {
                        HStack {
                            Text(state.input.stateCode?.rawValue ?? "State")
                                .foregroundStyle(
                                    state.input.stateCode == nil
                                        ? DesignTokens.Colors.textSecondary
                                        : DesignTokens.Colors.textPrimary
                                )
                            Spacer(minLength: DesignTokens.Spacing.xs)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        .beckonFormField(isInvalid: isStateInvalid)
                    }
                    .accessibilityLabel("State")
                    .accessibilityValue(state.input.stateCode?.rawValue ?? "Not selected")
                    .accessibilityIdentifier(BeckonAddressEditorSelectors.state)
                }
                .frame(width: 100)
            }

            labeledField("ZIP Code") {
                BeckonLimitedTextField(
                    placeholder: "ZIP Code",
                    text: Binding(
                        get: { state.input.postalCode },
                        set: { state.updatePostalCode($0) }
                    ),
                    maximumLength: 5,
                    textContentType: .postalCode,
                    keyboardType: .numberPad,
                    autocapitalizationType: .none,
                    addressInputRule: .zipCode,
                    onEditingBegan: {
                        state.dismissSuggestions()
                        onFieldFocused(BeckonAddressEditorSelectors.postalCodeContainer)
                    },
                    onTextChange: { _ in }
                )
                .accessibilityIdentifier(BeckonAddressEditorSelectors.postalCode)
            }
            .beckonKeyboardFocusTarget(BeckonAddressEditorSelectors.postalCodeContainer)

            statusRow
        }
        .contentShape(Rectangle())
        .overlayPreferenceValue(BeckonAddressLineOneBoundsKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    let bounds = proxy[anchor]
                    suggestionOverlay
                        .frame(width: bounds.width)
                        .offset(
                            x: bounds.minX,
                            y: bounds.maxY + DesignTokens.Spacing.xs
                        )
                }
            }
        }
        .zIndex(state.candidates.isEmpty ? 0 : 100)
        .onTapGesture(perform: state.dismissSuggestions)
        .onChange(of: state.noticeMessage) { _, message in
            guard let message else { return }
            feedbackCenter?.showNotice(message)
            state.consumeNotice()
        }
        .sheet(item: reviewSheetBinding) { sheet in
            BeckonAddressReviewSheet(sheet: sheet, state: state)
        }
        .onDisappear(perform: state.clear)
    }

    @ViewBuilder
    private var suggestionOverlay: some View {
        if !state.candidates.isEmpty {
            VStack(spacing: 0) {
                ForEach(state.candidates) { candidate in
                    Button {
                        Task { await state.select(candidate) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.primaryText)
                                .font(DesignTokens.Typography.body.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .lineLimit(1)
                            if !candidate.secondaryText.isEmpty {
                                Text(candidate.secondaryText)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel([candidate.primaryText, candidate.secondaryText]
                        .filter { !$0.isEmpty }
                        .joined(separator: ", "))

                    if candidate.id != state.candidates.last?.id {
                        Divider().padding(.leading, DesignTokens.Spacing.md)
                    }
                }
            }
            .background(DesignTokens.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
            }
            .beckonShadow(DesignTokens.Shadows.softCard)
            .accessibilityIdentifier(BeckonAddressEditorSelectors.suggestions)
            .zIndex(30)
        }
    }

    private var statusRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if state.status == .locating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: statusSymbol)
                        .foregroundStyle(statusColor)
                        .accessibilityHidden(true)
                }
                Text(state.status.title)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(BeckonAddressEditorSelectors.status)

            Spacer(minLength: DesignTokens.Spacing.sm)

            if showsVerificationAction,
               state.status != .confirmed,
               isCompleteAddress {
                Button("Verify Address") {
                    Task { _ = await state.prepareConfirmation() }
                }
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.customerAccent)
                .buttonStyle(.plain)
                .accessibilityIdentifier(BeckonAddressEditorSelectors.verify)
            }
        }
    }

    private var isCompleteAddress: Bool {
        !state.input.line1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !state.input.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && state.input.stateCode != nil
            && !state.input.postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var statusSymbol: String {
        switch state.status {
        case .confirmed: "checkmark.circle.fill"
        case .needsReview: "exclamationmark.circle.fill"
        default: "pencil.circle"
        }
    }

    private var statusColor: Color {
        switch state.status {
        case .confirmed: DesignTokens.Colors.success
        case .needsReview: DesignTokens.Colors.warning
        default: DesignTokens.Colors.textSecondary
        }
    }

    private var reviewSheetBinding: Binding<BeckonAddressReviewSheetModel?> {
        Binding(
            get: {
                guard state.isReviewPresented else { return nil }
                if let confirmation = state.confirmation {
                    return .confirmation(confirmation)
                }
                if !state.manualChoices.isEmpty {
                    return .manualChoices(state.manualChoices)
                }
                return nil
            },
            set: { value in
                if value == nil { state.dismissPresentedReview() }
            }
        )
    }

    private func labeledField<Content: View>(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let detail {
                    Text(detail)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            content()
        }
    }
}

private enum BeckonAddressReviewSheetModel: Identifiable {
    case confirmation(BeckonAddressConfirmationPresentation)
    case manualChoices([BeckonResolvedAddress])

    var id: String {
        switch self {
        case let .confirmation(presentation): "confirmation-\(presentation.id)"
        case let .manualChoices(choices):
            "choices-" + choices.map { String($0.coordinate.latitude) + String($0.coordinate.longitude) }.joined()
        }
    }

    var presentationDetents: Set<PresentationDetent> {
        switch self {
        case .confirmation:
            [.height(330), .large]
        case .manualChoices:
            [.medium, .large]
        }
    }
}

private struct BeckonAddressReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sheet: BeckonAddressReviewSheetModel
    let state: BeckonAddressEditorState
    @State private var selectedManualResult: BeckonResolvedAddress?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    if let selectedManualResult {
                        confirmationContent(BeckonAddressConfirmationPresentation(
                            entered: state.input,
                            resolved: selectedManualResult
                        ))
                    } else {
                        switch sheet {
                        case let .confirmation(presentation):
                            confirmationContent(presentation)
                        case let .manualChoices(choices):
                            manualChoiceContent(choices)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.screenHorizontal)
            }
            .scrollIndicators(.hidden)
            .background(DesignTokens.Colors.background)
            .navigationTitle("Confirm Service Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit Address") {
                        state.editAddress()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents(sheet.presentationDetents)
        .accessibilityIdentifier(BeckonAddressEditorSelectors.confirmation)
    }

    @ViewBuilder
    private func confirmationContent(_ presentation: BeckonAddressConfirmationPresentation) -> some View {
        addressSection(title: "Entered Address", input: presentation.entered)
        addressSection(title: "Apple Maps Suggested Address", input: presentation.resolved.suggested)

        Button("Use Suggested Address") {
            state.useSuggestedAddress()
            dismiss()
        }
        .buttonStyle(BeckonPrimaryButtonStyle())
        .accessibilityHint("Confirms this location for distance matching")
    }

    @ViewBuilder
    private func manualChoiceContent(_ choices: [BeckonResolvedAddress]) -> some View {
        Text("Choose the Apple Maps address that matches your service location.")
            .font(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.Colors.textSecondary)

        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(Array(choices.enumerated()), id: \.offset) { _, choice in
                Button {
                    state.chooseManualResult(choice)
                    selectedManualResult = choice
                } label: {
                    HStack {
                        Text(formatted(choice.suggested))
                            .font(DesignTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: DesignTokens.Spacing.sm)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .background(DesignTokens.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier(BeckonAddressEditorSelectors.manualChoices)
    }

    private func addressSection(title: String, input: BeckonAddressInput) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Text(formatted(input))
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
    }

    private func formatted(_ input: BeckonAddressInput) -> String {
        [
            input.line1,
            input.line2,
            [input.city, input.stateCode?.rawValue ?? "", input.postalCode]
                .filter { !$0.isEmpty }
                .joined(separator: " "),
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}
