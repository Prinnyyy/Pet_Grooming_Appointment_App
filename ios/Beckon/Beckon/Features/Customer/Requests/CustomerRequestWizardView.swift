import Foundation

import PhotosUI

import SwiftUI

import UIKit

typealias CustomerRequestServiceOption = GroomingServiceType

enum CustomerRequestPhotoSelectionCopy {
    static let title = "Request photos"
    static let supportingText =
        "Add photos specific to this grooming request. Your pet profile photo stays separate."
}

enum CustomerRequestTravelRange {
    static let minimumMiles = 5
    static let maximumMiles = 100

    static func clampedMiles(_ value: Double) -> Int {
        min(
            maximumMiles,
            max(minimumMiles, Int(value.rounded()))
        )
    }
}

struct CustomerRequestDateSelection {
    static let quickDateCount = 7

    let referenceDate: Date
    let calendar: Calendar

    init(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    var minimumDate: Date {
        calendar.startOfDay(for: referenceDate)
    }

    var quickDates: [Date] {
        (0..<Self.quickDateCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: minimumDate)
        }
    }

    func isQuickDate(_ date: Date) -> Bool {
        quickDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    func normalized(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}

struct CustomerRequestWizardPrimaryActionState: Equatable {
    let isSubmitting: Bool
    let isAwaitingAddressConfirmation: Bool

    var isEnabled: Bool {
        !isSubmitting && !isAwaitingAddressConfirmation
    }
}

enum CustomerRequestLocationSection: CaseIterable {
    case groomingSetup
    case location

    var title: String {
        switch self {
        case .groomingSetup:
            "Service location"
        case .location:
            "Address Details"
        }
    }

    var supportingText: String? { nil }
}

struct CustomerRequestWizardReviewPresentation: Equatable {
    struct Row: Equatable, Identifiable {
        let title: String
        let value: String

        var id: String { title }
    }

    let rows: [Row]

    init(
        pet: String,
        service: String,
        preferredTime: String,
        location: String,
        notes: String,
        requestPhotoCount: Int = 0
    ) {
        rows = [
            Row(title: "Pet", value: pet),
            Row(title: "Service", value: service),
            Row(title: "Preferred time", value: preferredTime),
            Row(title: "Location", value: location),
            Row(title: "Notes", value: notes),
            Row(
                title: "Request photos",
                value: Self.requestPhotoSummary(count: requestPhotoCount)
            ),
        ]
    }

    private static func requestPhotoSummary(count: Int) -> String {
        switch count {
        case 0:
            "None Selected"
        case 1:
            "1 Selected"
        default:
            "\(count) Selected"
        }
    }
}

private struct CustomerRequestWizardBottomBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CustomerRequestWizardFitInputPresentation: Equatable {
    struct Chip: Equatable, Identifiable {
        let id: String
        let label: String
        let title: String
        let systemImage: String
    }

    let chips: [Chip]

    init(signals: [PetFitSignal]) {
        chips = signals.map { signal in
            Chip(
                id: signal.id,
                label: Self.label(for: signal.group),
                title: signal.title,
                systemImage: Self.systemImage(for: signal.group)
            )
        }
    }

    private static func label(for group: PetFitSignal.Group) -> String {
        switch group {
        case .coatType, .verifiedCoat:
            "Coat"
        case .breedGroup:
            "Breed"
        case .sizeBand, .verifiedSize:
            "Pet size"
        case .careFlag, .verifiedCare:
            "Care Need"
        case .serviceFit, .verifiedService:
            "Service fit"
        }
    }

    private static func systemImage(for group: PetFitSignal.Group) -> String {
        switch group {
        case .coatType, .verifiedCoat:
            "comb"
        case .breedGroup:
            "pawprint"
        case .sizeBand, .verifiedSize:
            "ruler"
        case .careFlag, .verifiedCare:
            "heart"
        case .serviceFit, .verifiedService:
            "sparkles"
        }
    }
}

struct CustomerRequestWizardView: View {
    @Environment(\.beckonFeedbackCenter) private var feedbackCenter
    #if DEBUG
    @Environment(\.sandboxRequestAdvance) private var sandboxRequestAdvance
    #endif
    @Bindable var store: CustomerRequestsStore

    private let onAddPet: (() -> Void)?
    @State private var flow: CustomerRequestWizardState
    @State private var selectedRequestPhotoItems: [PhotosPickerItem] = []
    @State private var globallyPresentedErrorMessage: String?
    @State private var bottomBarHeight: CGFloat = 0
    @State private var focusedInputTarget: String?
    /// Which way the next step's blocks come from. Set the moment Continue or Back is tapped, before the step changes, so the
    /// new step is built already knowing it.
    @State private var travel = BeckonEntranceTravel.rise
    @FocusState private var isNotesFocused: Bool

    private static let notesFocusTarget = "customer.requests.wizard.notes.container"
    private static let scrollTopAnchor = "customer.requests.wizard.scroll-top"

    init(
        store: CustomerRequestsStore,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        onAddPet: (() -> Void)? = nil
    ) {
        self.store = store
        self.onAddPet = onAddPet
        _flow = State(initialValue: CustomerRequestWizardState(
            store: store, profileRepository: customerProfileRepository
        ))
    }

    /// Once the preview is ready the groomers step takes over the page below the same header, instead of pushing a new screen.
    private var groomersFlow: CustomerRequestDiscoveryFlow? { store.marketplace == nil ? nil : store.discoveryFlow }

    private var displayStep: CustomerRequestStep {
        groomersFlow == nil ? CustomerRequestStep(flow.currentStep) : .groomers
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CustomerRequestWizardHeader(step: displayStep, isSent: groomersFlow?.requestID != nil)
                Group {
                if let groomersFlow, let marketplace = store.marketplace {
                    CustomerGroomerDiscoveryView(flow: groomersFlow, requests: store, marketplace: marketplace,
                        embeddedInWizard: true, onBack: { travel = .back; store.discoveryFlow = nil })
                        .transition(.opacity)
                } else {
                ScrollViewReader { scrollProxy in
                    ZStack {
                        DesignTokens.Colors.appBackground
                            .ignoresSafeArea()

                        ScrollView {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                                CustomerRequestWizardTitleBlock(step: flow.currentStep)
                                .id(Self.scrollTopAnchor)
                                .beckonEntrance(CustomerRequestStepMotion.titleOrder)

                                stepContent

                                if let errorMessage = store.errorMessage,
                                   errorMessage != globallyPresentedErrorMessage {
                                    BeckonErrorBanner(
                                        title: "Check request details",
                                        message: errorMessage
                                    )
                                    .accessibilityIdentifier("customer.requests.form-error")
                                }
                            }
                            // A new identity per step, so every step plays its own arrival (the title block would otherwise
                            // keep its identity and only change its words).
                            .id(flow.currentStep)
                            .beckonPageInsets(bottom: DesignTokens.Layout.sectionSpacing)
                            .padding(.bottom, bottomBarHeight)
                        }
                            .beckonTracksScroll()
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .scrollIndicators(.hidden)
                        .beckonKeyboardAvoidance(
                            focusedTarget: focusedInputTarget,
                            using: scrollProxy,
                            additionallyPreventsPresentationDismissal: store.isSubmitting
                                || !store.addressEditorState.candidates.isEmpty
                        )
                        .onChange(of: flow.currentStep) { previousStep, currentStep in
                            let transition = CustomerRequestWizardStepTransition(
                                previousStep: previousStep,
                                currentStep: currentStep
                            )
                            guard transition.shouldResetScrollToTop else { return }

                            if transition.shouldClearFocusedInput {
                                focusedInputTarget = nil
                                isNotesFocused = false
                            }

                            Task { @MainActor in
                                await Task.yield()
                                var transaction = Transaction(animation: nil)
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    scrollProxy.scrollTo(
                                        Self.scrollTopAnchor,
                                        anchor: .top
                                    )
                                }
                            }
                        }
                    }
                }
                .transition(.opacity)
                }
                }
                // Between the form steps and the groomers step only the page fades; the blocks of each step bring the motion,
                // so the sixth step arrives in the same way as the first five.
                .beckonAnimation(DesignTokens.Motion.reduced, value: groomersFlow?.id)
            }
            .beckonStationaryPageAction {
                // The groomers step draws its own bar, so it can react to the selection.
                if groomersFlow == nil {
                    CustomerRequestWizardBottomBar(
                        step: flow.currentStep,
                        backTitle: store.isRecoveringPublication || flow.currentStep == .pet ? "Close" : "Back",
                        primaryTitle: designPrimaryTitle,
                        isPrimaryEnabled: primaryActionState.isEnabled,
                        isSubmitting: store.isSubmitting,
                        back: { travel = .back; flow.back() },
                        advance: continueForward
                    )
                    .background {
                        GeometryReader { barGeometry in
                            Color.clear.preference(
                                key: CustomerRequestWizardBottomBarHeightKey.self,
                                value: barGeometry.size.height
                            )
                        }
                    }
                }
            }
            // After the page action, so the bar shares the page's tempo, and above the steps so all six arrive the same way.
            .beckonEntranceRhythm(.step, travel: travel)
            .onPreferenceChange(CustomerRequestWizardBottomBarHeightKey.self) {
                bottomBarHeight = $0
            }
            .tint(DesignTokens.Colors.customerDeep)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .foregroundRefreshable(nextDeadline: store.marketplace?.distribution.nextDeadline(requestIDs: store.discoveryFlow?.requestID.map { [$0] } ?? [])) {
            if let id = store.discoveryFlow?.requestID { await store.refreshDistributionProgress(requestIDs: [id]) }
        }
        .presentationDragIndicator(.hidden)
        .onAppear {
            flow.applyInitialDefaults()
        }
        .onChange(of: selectedRequestPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await addPendingRequestPhotos(newItems)
            }
        }
        .onChange(of: store.addressEditorState.confirmedAddress) { oldAddress, confirmedAddress in
            flow.addressConfirmationChanged(from: oldAddress, to: confirmedAddress)
        }
        .onChange(of: store.addressEditorState.isReviewPresented) { _, isPresented in
            guard !isPresented,
                  store.addressEditorState.confirmedAddress == nil else { return }
            flow.isContinuingAfterAddressConfirmation = false
        }
        .overlay(alignment: .bottom) {
            if let feedbackCenter {
                // Every step ends in a fixed bar: toasts sit above it. The groomers step says each outcome itself ("Sent" in the
                // header, chips that change in place, banners for errors), so a toast there only repeats the page.
                BeckonGlobalFeedbackOverlay(
                    center: feedbackCenter,
                    bottomPadding: BeckonGlobalFeedbackOverlay.actionBarClearance,
                    isQuiet: groomersFlow != nil
                )
            }
        }
        .onDisappear { flow.cancelPendingLoads() }
        .accessibilityIdentifier("customer.requests.wizard")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch flow.currentStep {
        case .pet:
            petStep
        case .service:
            serviceStep
        case .time:
            timeStep
        case .details:
            detailsStep
        case .review:
            reviewStep
        }
    }

    private var petStep: some View {
        BeckonCascade(start: CustomerRequestStepMotion.contentStart, alignment: .center, spacing: DesignTokens.Spacing.lg) {
            ForEach(store.pets) { pet in
                CustomerRequestPetChoiceCard(
                    pet: pet,
                    petPhotoData: store.primaryPetPhotoData(for: pet),
                    isSelected: store.selectedPetID == pet.id,
                    isInvalid: flow.invalidFields.contains(.pet)
                ) {
                    store.selectedPetID = pet.id
                    flow.clearInvalidField(.pet)
                }
            }

            CustomerRequestAddPetButton {
                addPet()
            }
            .disabled(onAddPet == nil)

            if store.pets.isEmpty {
                BeckonStatusChip(.petRequired)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var serviceStep: some View {
        BeckonCascade(start: CustomerRequestStepMotion.contentStart, alignment: .center, spacing: DesignTokens.Spacing.md) {
            ForEach(CustomerRequestServiceOption.allCases) { option in
                CustomerRequestServiceOptionCard(
                    option: option,
                    isSelected: store.serviceType == option,
                    isInvalid: flow.invalidFields.contains(.service)
                ) {
                    store.serviceType = option
                    flow.clearInvalidField(.service)
                }
            }
        }
    }

    private var timeStep: some View {
        BeckonCascade(start: CustomerRequestStepMotion.contentStart, spacing: DesignTokens.Spacing.xl) {
            groomingSetupSection
            locationSection
            if let calendar = store.requestCalendar {
                timeSelection(calendar: calendar)
                    .environment(\.calendar, calendar)
                    .environment(\.timeZone, calendar.timeZone)
            }
        }
    }

    private func timeSelection(calendar: Calendar) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            CustomerRequestDateStrip(
                selectedDate: flow.selectedDate,
                calendar: calendar
            ) { date in
                flow.selectedDate = date
                flow.clearInvalidField(.timeWindow)
                flow.applySelectedTimeWindow()
            }

            BeckonFieldGroup("Time Window") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    CustomerRequestTimeWindowGrid(
                        selectedTimeWindow: flow.selectedTimeWindow,
                        isFlexibleWithTime: flow.isFlexibleWithTime,
                        isInvalid: flow.invalidFields.contains(.timeWindow)
                    ) { option in
                        flow.selectedTimeWindow = option
                        flow.isFlexibleWithTime = false
                        flow.clearInvalidField(.timeWindow)
                        flow.applySelectedTimeWindow()
                    }

                    if flow.selectedTimeWindow == .detailed && !flow.isFlexibleWithTime {
                        CustomerRequestDetailedTimeFields(
                            preferredStart: $store.preferredStart,
                            preferredEnd: $store.preferredEnd,
                            isInvalid: flow.invalidFields.contains(.timeWindow)
                        )
                        .onChange(of: store.preferredStart) { _, _ in
                            flow.clearInvalidField(.timeWindow)
                        }
                        .onChange(of: store.preferredEnd) { _, _ in
                            flow.clearInvalidField(.timeWindow)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        occurrencePicker(isStart: true, calendar: calendar)
                        occurrencePicker(isStart: false, calendar: calendar)
                    }

                    CustomerRequestFlexibleTimeToggle(
                        isOn: Binding(
                            get: { flow.isFlexibleWithTime },
                            set: { newValue in
                                flow.isFlexibleWithTime = newValue
                                flow.clearInvalidField(.timeWindow)
                                flow.applySelectedTimeWindow()
                            }
                        )
                    )
                }
            }

        }
    }

    private var groomingSetupSection: some View {
        BeckonFieldGroup(
            CustomerRequestLocationSection.groomingSetup.title,
            supportingText: CustomerRequestLocationSection.groomingSetup.supportingText
        ) {
            BeckonGroomingLocationModeSelector(
                selection: [store.locationMode],
                selectionPolicy: .single,
                perspective: .customer,
                accent: .customer
            ) { selection in
                if let mode = selection.first {
                    store.locationMode = mode
                }
            }
        }
    }

    @ViewBuilder
    private func occurrencePicker(isStart: Bool, calendar: Calendar) -> some View {
        let choices = isStart ? store.preferredStartOccurrences : store.preferredEndOccurrences
        if choices.count == 2 {
            Picker(isStart ? "Start Occurrence" : "End Occurrence", selection: Binding<Date?>(
                get: { store.confirmedPreferredOccurrence(isStart: isStart) },
                set: { if let date = $0 { store.confirmPreferredOccurrence(date, isStart: isStart) } }
            )) {
                Text("Choose occurrence").tag(Optional<Date>.none)
                ForEach(choices, id: \.self) { date in
                    Text(CustomerRequestWizardDateFormatting.occurrence(date, calendar: calendar))
                        .tag(Optional(date))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(isStart ? "customer.requests.start-occurrence" : "customer.requests.end-occurrence")
        }
    }

    private var locationSection: some View {
        BeckonFieldGroup(CustomerRequestLocationSection.location.title) {
            CustomerRequestAddressFields(
                addressEditorState: store.addressEditorState,
                isStateInvalid: flow.invalidFields.contains(.state),
                locationMode: store.locationMode,
                travelRangeMiles: $store.travelRadiusMiles,
                isApplyingProfileAddress: flow.isApplyingProfileAddress,
                useProfileAddress: applyProfileAddress,
                clearInvalidField: flow.clearInvalidField,
                onFieldFocused: { focusedInputTarget = $0 }
            )
        }
    }

    private var detailsStep: some View {
        BeckonCascade(start: CustomerRequestStepMotion.contentStart, spacing: DesignTokens.Spacing.xl) {
            BeckonFieldGroup(
                "Notes To Groomers",
                errorText: notesErrorText
            ) {
                TextField("Share coat goals, sensitivities, or handling notes.", text: $store.serviceNotes, axis: .vertical)
                    .lineLimit(5...8)
                    .focused($isNotesFocused)
                    .beckonFormField(isInvalid: flow.invalidFields.contains(.notes))
                    .accessibilityIdentifier("customer.requests.wizard.notes")
                    .onTapGesture {
                        flow.clearInvalidField(.notes)
                        isNotesFocused = true
                    }
                    .onChange(of: store.serviceNotes) { _, _ in
                        flow.clearInvalidField(.notes)
                    }
                    .onChange(of: isNotesFocused) { _, isFocused in
                        if isFocused {
                            focusedInputTarget = Self.notesFocusTarget
                        }
                    }
            }
            .beckonKeyboardFocusTarget(Self.notesFocusTarget)

            BeckonFieldGroup(
                CustomerRequestPhotoSelectionCopy.title,
                supportingText: CustomerRequestPhotoSelectionCopy.supportingText
            ) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    if !store.pendingRequestPhotos.isEmpty {
                        CustomerRequestPendingPhotoList(
                            photos: store.pendingRequestPhotos,
                            onRemove: { photoID in
                                store.removePendingPhoto(id: photoID)
                            }
                        )
                    }

                    PhotosPicker(
                        selection: $selectedRequestPhotoItems,
                        matching: .images
                    ) {
                        Label("Add request photos", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer))
                    .accessibilityIdentifier("customer.requests.wizard.add-photos")
                }
            }
        }
    }

    private var reviewStep: some View {
        CustomerRequestWizardReview(
            rows: reviewPresentation.rows,
            photos: store.pendingRequestPhotos,
            fitChips: reviewFitInputPresentation.chips,
            isRecoveringPublication: store.isRecoveringPublication,
            isRevisingRequest: store.isRevisingRequest,
            entranceStart: CustomerRequestStepMotion.contentStart
        )
    }

    // Same wording the original bottom bar uses.
    private var designPrimaryTitle: String {
        if let sandboxPrimaryActionTitle { return sandboxPrimaryActionTitle }
        if store.isSubmitting { return "Publishing..." }
        if store.isRecoveringPublication { return "Resume Request" }
        if flow.currentStep == .time && store.requestCalendar == nil { return "Confirm Address" }
        if flow.currentStep == .review && store.marketplace != nil { return "Find Groomers" }
        return flow.currentStep == .review ? (store.isRevisingRequest ? "Replace Request" : "Publish Request") : "Continue"
    }

    private var primaryActionState: CustomerRequestWizardPrimaryActionState {
        CustomerRequestWizardPrimaryActionState(
            isSubmitting: store.isSubmitting,
            isAwaitingAddressConfirmation: flow.isContinuingAfterAddressConfirmation
        )
    }

    private var sandboxPrimaryActionTitle: String? {
        #if DEBUG
        if sandboxRequestAdvance != nil {
            return flow.currentStep == .review ? "Choose groomers" : "Continue"
        }
        #endif
        return nil
    }

    private var reviewPresentation: CustomerRequestWizardReviewPresentation {
        CustomerRequestWizardReviewPresentation(
            pet: reviewPetSummary,
            service: store.serviceType?.title ?? "Choose A Service",
            preferredTime: reviewPreferredTimeSummary,
            location: reviewLocationSummary,
            notes: notesSummary,
            requestPhotoCount: store.pendingRequestPhotos.count
        )
    }

    private var reviewFitInputPresentation: CustomerRequestWizardFitInputPresentation {
        CustomerRequestWizardFitInputPresentation(
            signals: store.requestFitInputSignals()
        )
    }

    private var reviewPetSummary: String {
        guard let pet = store.selectedPet else {
            return "Choose A Pet"
        }

        let breed = pet.displayBreed?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let breed, !breed.isEmpty {
            return "\(pet.name) · \(breed)"
        }

        return "\(pet.name) · \(pet.displaySpecies)"
    }

    private var reviewPreferredTimeSummary: String {
        guard let calendar = store.requestCalendar,
              let range = store.remainingPreferredRange(now: Date()) else { return "Choose a valid time window" }
        return BeckonDateTimeFormatter.interval(from: range.start, to: range.end,
            serviceTimeZoneIdentifier: calendar.timeZone.identifier).summary
    }

    private var reviewLocationSummary: String {
        let location = [
            store.streetAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            store.addressLine2.trimmingCharacters(in: .whitespacesAndNewlines),
            store.city.trimmingCharacters(in: .whitespacesAndNewlines),
            store.stateCode?.rawValue ?? "",
            store.zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")

        let prefix = store.locationMode == .groomerComesToCustomer ? "Mobile" : "Visit"
        return location.isEmpty ? "\(prefix) · Required" : "\(prefix) · \(location)"
    }

    private var notesSummary: String {
        let notes = store.serviceNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.isEmpty ? "No Notes Added" : notes
    }

    private var notesErrorText: String? {
        guard flow.invalidFields.contains(.notes) else { return nil }
        if store.serviceType == .customRequest {
            return CustomerRequestWizardStepValidation.customRequestNotesMessage
        }

        return "Service notes must be 2,000 characters or fewer."
    }

    private func continueForward() {
        travel = .forward
        globallyPresentedErrorMessage = nil
        #if DEBUG
        if let sandboxRequestAdvance {
            sandboxRequestAdvance(flow)
            return
        }
        #endif
        Task {
            if await flow.continueForward() { publish() }
        }
    }

    private func publish() {
        globallyPresentedErrorMessage = nil
        Task {
            if store.marketplace != nil { await store.prepareDiscovery() }
            else { await store.publish() }
            guard store.isShowingWizard,
                  let errorMessage = store.errorMessage else { return }
            globallyPresentedErrorMessage = errorMessage
            feedbackCenter?.showError(
                BeckonGlobalFeedbackError(
                    scope: .operation("customer.requests.publish"),
                    sourceKey: "customer.requests.publish.failure",
                    title: "We could not publish request",
                    message: errorMessage
                )
            )
        }
    }

    private func addPet() {
        guard let onAddPet else { return }
        onAddPet()
    }

    private func addPendingRequestPhotos(_ items: [PhotosPickerItem]) async {
        defer { selectedRequestPhotoItems = [] }

        var hadFailure = false
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                hadFailure = true
                continue
            }

            let contentType = item.supportedContentTypes
                .lazy
                .compactMap(GroomingRequestPhotoContentType.init(uniformType:))
                .first ?? .jpeg

            if !store.addPendingPhoto(
                data: data,
                contentType: contentType
            ) {
                hadFailure = true
            }
        }

        if hadFailure {
            store.errorMessage =
                "Some photos could not be added. Choose images smaller than 10 MB and try again."
        }
    }

    private func applyProfileAddress() {
        Task {
            switch await flow.applyProfileAddress() {
            case .applied, .cancelled: break
            case .missing: showNoProfileAddressPrompt()
            case .unavailable: showProfileAddressUnavailablePrompt()
            }
        }
    }

    private func showNoProfileAddressPrompt() {
        showProfileAddressPrompt(
            BeckonGlobalFeedbackError(
                scope: .operation("customer.requests.profile-address"),
                sourceKey: "customer.requests.profile-address.missing",
                title: "No profile address",
                message: "Add an address in Account Profile Settings first."
            )
        )
    }

    private func showProfileAddressUnavailablePrompt() {
        showProfileAddressPrompt(
            BeckonGlobalFeedbackError(
                scope: .operation("customer.requests.profile-address"),
                sourceKey: "customer.requests.profile-address.unavailable",
                title: "Profile address unavailable",
                message: "We could not load your saved profile address. Please try again."
            )
        )
    }

    private func showProfileAddressPrompt(_ error: BeckonGlobalFeedbackError) {
        feedbackCenter?.clearError(matching: error)
        feedbackCenter?.showError(error)
    }

}

typealias CustomerRequestLocationMode = GroomingLocationMode

private enum CustomerRequestWizardDateFormatting {
    static func occurrence(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a XXX"
        return formatter.string(from: date)
    }

}

struct CustomerRequestWizardProgressLayout: Equatable {
    let usesSingleColumnChoices: Bool

    init(dynamicTypeSize: DynamicTypeSize) {
        usesSingleColumnChoices = dynamicTypeSize.isAccessibilitySize
    }

}

struct CustomerRequestPetChoiceCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let pet: CustomerPet
    let petPhotoData: Data?
    let isSelected: Bool
    let isInvalid: Bool
    let action: () -> Void

    var body: some View {
        BeckonSelectionCard(
            isSelected: isSelected,
            isInvalid: isInvalid,
            accent: .customer,
            action: action
        ) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        HStack { avatar; Spacer(minLength: 8); selectionIndicator }
                        petLabels
                    }
                } else {
                    HStack(spacing: DesignTokens.Spacing.lg) {
                        avatar
                        petLabels
                        selectionIndicator
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        }
        .accessibilityIdentifier(
            "customer.requests.wizard.pet.\(pet.species.lowercased()).\(pet.id.uuidString)"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var avatar: some View {
        CustomerRequestWizardPetAvatar(pet: pet, data: petPhotoData, size: 84)
    }

    private var selectionIndicator: some View {
        Image(systemName: "checkmark")
            .font(DesignTokens.Typography.action)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(width: 42, height: 42)
            .background(DesignTokens.Colors.customerTint)
            .clipShape(Circle())
            .opacity(isSelected ? 1 : 0)
            .accessibilityHidden(true)
    }

    private var petLabels: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(pet.name)
                .font(DesignTokens.Typography.cardTitle)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .accessibilityIdentifier("pet.\(pet.id.uuidString).name")
            Text(breedText)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .accessibilityIdentifier("pet.\(pet.id.uuidString).breed")
            if let weight = pet.weightLbs {
                Text("\(weight.formatted(.number.precision(.fractionLength(0...1)))) lbs")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .accessibilityIdentifier("pet.\(pet.id.uuidString).weight")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var breedText: String {
        let breed = pet.displayBreed?.trimmingCharacters(in: .whitespacesAndNewlines)
        return breed?.isEmpty == false ? breed ?? pet.displaySpecies : pet.displaySpecies
    }
}

/// "Add a new pet" at the end of the pet choice: the kit's dashed ledge surface, so it reads as an empty slot like the Home one.
private struct CustomerRequestAddPetButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "plus")
                    .font(DesignTokens.Typography.Expressive.glyph)
                Text("Add a new pet")
                    .font(DesignTokens.Typography.Expressive.emphasis)
            }
            .foregroundStyle(DesignTokens.Colors.customerDeep)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.dashed))
        .accessibilityIdentifier("customer.requests.wizard.add-pet")
    }
}

private struct CustomerRequestServiceOptionCard: View {
    let option: CustomerRequestServiceOption
    let isSelected: Bool
    let isInvalid: Bool
    let action: () -> Void

    var body: some View {
        BeckonSelectionCard(
            isSelected: isSelected,
            isInvalid: isInvalid,
            accent: .customer,
            action: action
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "scissors")
                    .font(DesignTokens.Typography.cardTitle)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .frame(width: 64, height: 64)
                    .background(DesignTokens.Colors.customerTint)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DesignTokens.CornerRadius.input,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(option.title)
                        .font(DesignTokens.Typography.cardTitle)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(option.subtitle)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        }
        .accessibilityIdentifier(
            "customer.requests.wizard.service.\(option.rawValue)"
        )
    }
}

private struct CustomerRequestDateStrip: View {
    let selectedDate: Date
    let calendar: Calendar
    let onSelect: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(configuration.quickDates, id: \.self) { date in
                        Button {
                            onSelect(date)
                        } label: {
                            VStack(spacing: DesignTokens.Spacing.xs) {
                                Text(dayName(date))
                                    .font(DesignTokens.Typography.caption.weight(.bold))

                                Text(dayNumber(date))
                                    .font(DesignTokens.Typography.sectionTitle)
                            }
                            .foregroundStyle(isSelected(date) ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
                            .frame(width: 76, height: 92)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: DesignTokens.CornerRadius.button,
                                    style: .continuous
                                )
                                .fill(isSelected(date) ? DesignTokens.Colors.customerFill : DesignTokens.Colors.surface)
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: DesignTokens.CornerRadius.button,
                                    style: .continuous
                                )
                                .stroke(
                                    isSelected(date) ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.border,
                                    lineWidth: 1.2
                                )
                            }
                        }
                        .buttonStyle(BeckonGuardedPlainButtonStyle())
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            .scrollIndicators(.hidden)

            DatePicker(
                "Choose Another Date",
                selection: Binding(
                    get: { selectedDate },
                    set: { onSelect(configuration.normalized($0)) }
                ),
                in: configuration.minimumDate...,
                displayedComponents: .date
            )
            .font(DesignTokens.Typography.body.weight(.semibold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .tint(DesignTokens.Colors.customerDeep)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(minHeight: 56)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.input,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.input,
                    style: .continuous
                )
                .stroke(DesignTokens.Colors.border, lineWidth: 1)
            }
            .accessibilityIdentifier("customer.requests.wizard.date-picker")
        }
    }

    private var configuration: CustomerRequestDateSelection {
        CustomerRequestDateSelection(calendar: calendar)
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

private struct CustomerRequestTimeWindowGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedTimeWindow: CustomerRequestTimeWindowOption
    let isFlexibleWithTime: Bool
    let isInvalid: Bool
    let action: (CustomerRequestTimeWindowOption) -> Void

    var body: some View {
        LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: DesignTokens.Spacing.md
        ) {
            ForEach(CustomerRequestTimeWindowOption.allCases) { option in
                Button {
                    action(option)
                } label: {
                    Text(option.title)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(
                            selectedTimeWindow == option && !isFlexibleWithTime
                                ? DesignTokens.Colors.customerInk
                                : DesignTokens.Colors.textSecondary
                        )
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(
                                    selectedTimeWindow == option && !isFlexibleWithTime
                                        ? DesignTokens.Colors.customerFill
                                        : DesignTokens.Colors.surface
                                )
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    borderColor(for: option),
                                    lineWidth: isInvalid ? 1.6 : 1
                                )
                        }
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
            }
        }
    }

    private var columns: [GridItem] {
        let layout = CustomerRequestWizardProgressLayout(
            dynamicTypeSize: dynamicTypeSize
        )
        let count = layout.usesSingleColumnChoices ? 1 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
            count: count
        )
    }

    private func borderColor(for option: CustomerRequestTimeWindowOption) -> Color {
        if isInvalid, selectedTimeWindow == option, !isFlexibleWithTime {
            return DesignTokens.Colors.statusErrorText
        }

        return DesignTokens.Colors.border
    }
}

private struct CustomerRequestDetailedTimeFields: View {
    @Binding var preferredStart: Date
    @Binding var preferredEnd: Date
    let isInvalid: Bool

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            DatePicker(
                "Start Time",
                selection: $preferredStart,
                displayedComponents: [.hourAndMinute]
            )
            .font(DesignTokens.Typography.body.weight(.semibold))
            .beckonFormField(isInvalid: isInvalid)
            .accessibilityIdentifier("customer.requests.start-time")

            DatePicker(
                "End Time",
                selection: $preferredEnd,
                displayedComponents: [.hourAndMinute]
            )
            .font(DesignTokens.Typography.body.weight(.semibold))
            .beckonFormField(isInvalid: isInvalid)
            .accessibilityIdentifier("customer.requests.end-time")
        }
    }
}

private struct CustomerRequestFlexibleTimeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("I'm flexible with time")
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("Any time on this date")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .tint(DesignTokens.Colors.customerDeep)
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
            .stroke(DesignTokens.Colors.border, lineWidth: 1)
        }
    }
}

private struct CustomerRequestAddressFields: View {
    @Bindable var addressEditorState: BeckonAddressEditorState
    let isStateInvalid: Bool
    let locationMode: CustomerRequestLocationMode
    @Binding var travelRangeMiles: Int
    let isApplyingProfileAddress: Bool
    let useProfileAddress: () -> Void
    let clearInvalidField: (CustomerRequestWizardValidationField) -> Void
    let onFieldFocused: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Button(action: useProfileAddress) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if isApplyingProfileAddress {
                        ProgressView()
                            .tint(DesignTokens.Colors.customerDeep)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(DesignTokens.Typography.action)
                    }

                    Text(isApplyingProfileAddress ? "Loading Profile Address..." : "Use Profile Address")
                        .font(DesignTokens.Typography.action)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(DesignTokens.Colors.customerTint)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.button,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.button,
                        style: .continuous
                    )
                    .stroke(DesignTokens.Colors.customerDeep, lineWidth: 1)
                }
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .disabled(isApplyingProfileAddress)
            .accessibilityIdentifier("customer.requests.use-profile-address")

            BeckonAddressEditor(
                state: addressEditorState,
                isStateInvalid: isStateInvalid,
                showsVerificationAction: false,
                onFieldFocused: onFieldFocused
            )
                .onChange(of: addressEditorState.status) { _, status in
                    guard status == .confirmed else { return }
                    clearInvalidField(.streetAddress)
                    clearInvalidField(.city)
                    clearInvalidField(.state)
                    clearInvalidField(.zipCode)
                    clearInvalidField(.addressConfirmation)
                }

            if locationMode == .customerComesToGroomer {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Stepper(
                        value: $travelRangeMiles,
                        in: CustomerRequestTravelRange.minimumMiles...CustomerRequestTravelRange.maximumMiles
                    ) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Travel range")
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                            Text("\(travelRangeMiles) mi")
                                .foregroundStyle(DesignTokens.Colors.customerDeep)
                        }
                        .font(DesignTokens.Typography.body.weight(.bold))
                    }
                    .accessibilityIdentifier("customer.requests.travel-range")
                    .accessibilityValue("\(travelRangeMiles) miles")

                    Slider(
                        value: Binding(
                            get: { Double(travelRangeMiles) },
                            set: { travelRangeMiles = CustomerRequestTravelRange.clampedMiles($0) }
                        ),
                        in: Double(CustomerRequestTravelRange.minimumMiles)...Double(CustomerRequestTravelRange.maximumMiles),
                        step: 1
                    )
                    .tint(DesignTokens.Colors.customerDeep)
                    .accessibilityLabel("Travel range")

                    Text("Choose how far you can travel to a groomer's location.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .padding(DesignTokens.Spacing.lg)
                .background(DesignTokens.Colors.surface)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

}

private struct CustomerRequestPendingPhotoList: View {
    let photos: [PendingGroomingRequestPhoto]
    let onRemove: ((UUID) -> Void)?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: DesignTokens.Spacing.md) {
                ForEach(photos) { photo in
                    CustomerRequestPendingPhotoThumbnail(
                        photo: photo,
                        onRemove: onRemove.map { remove in
                            { remove(photo.id) }
                        }
                    )
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .accessibilityIdentifier("customer.requests.wizard.photo-preview")
    }
}

private struct CustomerRequestPendingPhotoThumbnail: View {
    let photo: PendingGroomingRequestPhoto
    let onRemove: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            BeckonModuleImage(data: photo.data) {
                Image(systemName: "photo")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignTokens.Colors.surface)
            }
            .frame(width: 112, height: 112)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.input,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.input,
                    style: .continuous
                )
                .stroke(DesignTokens.Colors.border, lineWidth: 1)
            }

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.statusErrorText)
                        .frame(width: 30, height: 30)
                        .background(DesignTokens.Colors.surface)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(DesignTokens.Colors.statusErrorBorder, lineWidth: 1) }
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .padding(DesignTokens.Spacing.xs)
                .accessibilityLabel("Remove request photo")
                .accessibilityIdentifier(
                    "customer.requests.wizard.remove-photo.\(photo.id.uuidString)"
                )
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct CustomerRequestWizardPetAvatar: View {
    let pet: CustomerPet
    let data: Data?
    let size: CGFloat

    var body: some View {
        BeckonPetAvatar(
            data: data,
            systemImage: BeckonPetPresentation.symbol(for: pet.displaySpecies),
            width: size,
            height: size,
            cornerRadius: DesignTokens.CornerRadius.input
        )
    }

}
