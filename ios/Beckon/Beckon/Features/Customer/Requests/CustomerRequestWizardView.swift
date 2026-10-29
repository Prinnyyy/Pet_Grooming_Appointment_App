import Foundation

import PhotosUI

import SwiftUI

import UIKit


typealias CustomerRequestServiceOption = GroomingServiceType


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
                title: "Photos",
                value: Self.requestPhotoSummary(count: requestPhotoCount)
            ),
        ]
    }

    private static func requestPhotoSummary(count: Int) -> String {
        switch count {
        case 0:
            "No photos"
        case 1:
            "1 photo"
        default:
            "\(count) photos"
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
    /// A change started from a row of the review: the next Continue that moves on goes straight back to the review.
    @State private var returnsToReview = false

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
                        back: { travel = .back; returnsToReview = false; flow.back() },
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
        BeckonCascade(start: CustomerRequestStepMotion.contentStart, spacing: DesignTokens.Spacing.md) {
            if store.pets.isEmpty {
                BeckonLedgeNote(systemImage: "pawprint.fill", text: "Add a pet profile before starting a grooming request.")
            }
            ForEach(store.pets) { pet in
                CustomerRequestPetChoiceCard(
                    pet: pet,
                    petPhotoData: store.primaryPetPhotoData(for: pet),
                    isSelected: store.selectedPetID == pet.id
                ) {
                    store.selectedPetID = pet.id
                    flow.clearInvalidField(.pet)
                }
            }

            CustomerRequestAddPetButton {
                addPet()
            }
            .disabled(onAddPet == nil)

            if flow.invalidFields.contains(.pet) {
                BeckonInlineError(store.pets.isEmpty ? "Add a pet before continuing." : "Choose a pet before continuing.")
            }
        }
    }

    private var serviceStep: some View {
        BeckonCascade(start: CustomerRequestStepMotion.contentStart, spacing: DesignTokens.Spacing.xl) {
            ForEach(CustomerRequestServiceGroup.allCases) { group in
                CustomerRequestServiceGroupBlock(group: group, selected: store.serviceType) { option in
                    store.serviceType = option
                    flow.clearInvalidField(.service)
                }
            }
            if store.serviceType == .customRequest {
                BeckonLedgeNote(systemImage: "text.badge.plus",
                    text: "Describe what you need in Details. A custom request needs a note of at least \(CustomerRequestsStore.minimumCustomRequestNotesLength) characters.")
            }
            if flow.invalidFields.contains(.service) {
                BeckonInlineError("Choose a grooming service before continuing.")
            }
        }
    }

    /// Step 3: When above Where (page map 12). The sections are in `CustomerRequestTimeAndPlace.swift`.
    private var timeStep: some View {
        BeckonCascade(start: CustomerRequestStepMotion.contentStart, spacing: DesignTokens.Spacing.xl) {
            CustomerRequestWhenSection(store: store, flow: flow)
            CustomerRequestWhereSection(
                store: store,
                flow: flow,
                useProfileAddress: applyProfileAddress,
                onFieldFocused: { focusedInputTarget = $0 }
            )
        }
    }

    private var detailsStep: some View {
        BeckonCascade(start: CustomerRequestStepMotion.contentStart, spacing: DesignTokens.Spacing.xl) {
            CustomerRequestNotesSection(
                store: store,
                flow: flow,
                isFocused: $isNotesFocused,
                errorText: notesErrorText
            ) {
                focusedInputTarget = Self.notesFocusTarget
            }
            .beckonKeyboardFocusTarget(Self.notesFocusTarget)

            CustomerRequestPhotosSection(
                photos: store.pendingRequestPhotos,
                selection: $selectedRequestPhotoItems
            ) { photoID in
                store.removePendingPhoto(id: photoID)
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
            entranceStart: CustomerRequestStepMotion.contentStart,
            onEdit: edit
        )
    }

    // Same wording the original bottom bar uses.
    private var designPrimaryTitle: String {
        if returnsToReview && flow.currentStep != .review && !(flow.currentStep == .time && store.requestCalendar == nil) {
            return "Back to review"
        }
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
        return notes.isEmpty ? "No notes" : notes
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
        let previous = flow.currentStep
        #if DEBUG
        if let sandboxRequestAdvance {
            sandboxRequestAdvance(flow)
            returnToReviewIfEditing(from: previous)
            return
        }
        #endif
        Task {
            if await flow.continueForward() { publish() }
            returnToReviewIfEditing(from: previous)
        }
    }

    /// A row of the review was tapped: go to its step, and come back to the review when that step has been left.
    private func edit(_ step: CustomerRequestWizardStep) {
        travel = .back
        returnsToReview = true
        flow.currentStep = step
    }

    private func returnToReviewIfEditing(from previous: CustomerRequestWizardStep) {
        guard returnsToReview else { return }
        if flow.currentStep == .review {
            returnsToReview = false
        } else if flow.currentStep != previous {
            // Left the step, so it validated; a step that held (a missing field, an address to confirm) stays where it is.
            flow.currentStep = .review
            returnsToReview = false
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


struct CustomerRequestWizardProgressLayout: Equatable {
    let usesSingleColumnChoices: Bool

    init(dynamicTypeSize: DynamicTypeSize) {
        usesSingleColumnChoices = dynamicTypeSize.isAccessibilitySize
    }

}
