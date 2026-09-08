import Foundation
import PhotosUI
import SwiftUI
import UIKit

typealias CustomerRequestServiceOption = GroomingServiceType

enum CustomerRequestPhotoSelectionCopy {
    static let title = "Request Photos"
    static let supportingText =
        "Add photos specific to this grooming request. Your pet profile photo stays separate."
}

enum CustomerRequestTimeWindowOption: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case detailed

    var id: Self { self }

    var title: String {
        switch self {
        case .morning:
            "Morning"
        case .afternoon:
            "Afternoon"
        case .evening:
            "Evening"
        case .detailed:
            "Detailed Time"
        }
    }

    func range(
        on date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        switch self {
        case .morning:
            Self.range(
                on: date,
                startHour: 6,
                startMinute: 0,
                endHour: 11,
                endMinute: 59,
                calendar: calendar
            )
        case .afternoon:
            Self.range(
                on: date,
                startHour: 12,
                startMinute: 0,
                endHour: 16,
                endMinute: 59,
                calendar: calendar
            )
        case .evening:
            Self.range(
                on: date,
                startHour: 17,
                startMinute: 0,
                endHour: 21,
                endMinute: 0,
                calendar: calendar
            )
        case .detailed:
            nil
        }
    }

    static func flexibleRange(
        on date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        range(
            on: date,
            startHour: 0,
            startMinute: 0,
            endHour: 23,
            endMinute: 59,
            calendar: calendar
        )
    }

    private static func range(
        on date: Date,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let start = calendar.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: date
        ) ?? date
        let end = calendar.date(
            bySettingHour: endHour,
            minute: endMinute,
            second: 0,
            of: date
        ) ?? start.addingTimeInterval(60 * 60)
        return (start, end)
    }
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
            "Service Location"
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
            Row(title: "Preferred Time", value: preferredTime),
            Row(title: "Location", value: location),
            Row(title: "Notes", value: notes),
            Row(
                title: "Request Photos",
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
        case .coatType:
            "Coat"
        case .breedGroup:
            "Breed"
        case .sizeBand:
            "Pet Size"
        case .careFlag:
            "Care Need"
        case .serviceFit:
            "Service Fit"
        }
    }

    private static func systemImage(for group: PetFitSignal.Group) -> String {
        switch group {
        case .coatType:
            "comb"
        case .breedGroup:
            "pawprint"
        case .sizeBand:
            "ruler"
        case .careFlag:
            "heart"
        case .serviceFit:
            "sparkles"
        }
    }
}

struct CustomerRequestWizardView: View {
    @Environment(\.beckonFeedbackCenter) private var feedbackCenter
    @Bindable var store: CustomerRequestsStore

    private let onAddPet: (() -> Void)?
    private let customerProfileRepository: (any CustomerProfileRepository)?
    @State private var currentStep: CustomerRequestWizardStep
    @State private var selectedDate: Date
    @State private var selectedTimeWindow: CustomerRequestTimeWindowOption
    @State private var isFlexibleWithTime = false
    @State private var selectedRequestPhotoItems: [PhotosPickerItem] = []
    @State private var invalidFields: Set<CustomerRequestWizardValidationField> = []
    @State private var isApplyingProfileAddress = false
    @State private var isContinuingAfterAddressConfirmation = false
    @State private var globallyPresentedErrorMessage: String?
    @State private var bottomBarHeight: CGFloat = 0
    @State private var focusedInputTarget: String?
    @FocusState private var isNotesFocused: Bool

    private static let notesFocusTarget = "customer.requests.wizard.notes.container"
    private static let scrollTopAnchor = "customer.requests.wizard.scroll-top"

    init(
        store: CustomerRequestsStore,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        onAddPet: (() -> Void)? = nil
    ) {
        self.store = store
        self.customerProfileRepository = customerProfileRepository
        self.onAddPet = onAddPet
        _currentStep = State(initialValue: store.wizardInitialStep)
        _selectedDate = State(initialValue: store.preferredStart)
        _selectedTimeWindow = State(
            initialValue: store.wizardInitialStep == .review ? .detailed : .afternoon
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollViewReader { scrollProxy in
                    ZStack {
                        DesignTokens.Colors.background
                            .ignoresSafeArea()

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                                CustomerRequestWizardHeader(
                                    currentStep: currentStep
                                )
                                .id(Self.scrollTopAnchor)

                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                    Text(currentStep.headline)
                                        .font(DesignTokens.Typography.pageTitle)
                                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if let subtitle = currentStep.subtitle {
                                        Text(subtitle)
                                            .font(DesignTokens.Typography.body)
                                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                stepContent

                                if let errorMessage = store.errorMessage,
                                   errorMessage != globallyPresentedErrorMessage {
                                    BeckonErrorBanner(
                                        title: "Check Request Details",
                                        message: errorMessage
                                    )
                                    .accessibilityIdentifier("customer.requests.form-error")
                                }
                            }
                            .beckonPageInsets(bottom: DesignTokens.Layout.sectionSpacing)
                            .padding(.bottom, bottomBarHeight)
                        }
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .scrollIndicators(.hidden)
                        .beckonKeyboardAvoidance(
                            focusedTarget: focusedInputTarget,
                            using: scrollProxy,
                            additionallyPreventsPresentationDismissal: store.isSubmitting
                                || !store.addressEditorState.candidates.isEmpty
                        )
                        .onChange(of: currentStep) { previousStep, currentStep in
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
            }
            .beckonStationaryPageAction {
                CustomerRequestWizardBottomBar(
                    currentStep: currentStep,
                    isSubmitting: store.isSubmitting,
                    isPrimaryActionEnabled: primaryActionState.isEnabled,
                    needsAddressConfirmation: currentStep == .time && store.requestCalendar == nil,
                    backAction: back,
                    continueAction: continueForward
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
            .onPreferenceChange(CustomerRequestWizardBottomBarHeightKey.self) {
                bottomBarHeight = $0
            }
            .tint(DesignTokens.Colors.customerAccentStrong)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            applyInitialDefaults()
        }
        .onChange(of: selectedRequestPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await addPendingRequestPhotos(newItems)
            }
        }
        .onChange(of: store.addressEditorState.confirmedAddress) { oldAddress, confirmedAddress in
            if store.requestCalendar != nil,
               oldAddress?.timeZoneIdentifier != confirmedAddress?.timeZoneIdentifier {
                selectedDate = store.preferredStart
                selectedTimeWindow = .detailed
                isFlexibleWithTime = false
            }
            guard isContinuingAfterAddressConfirmation,
                  confirmedAddress != nil else { return }
            isContinuingAfterAddressConfirmation = false
            let validation = store.validateWizardStep(.time)
            guard validation.isValid else {
                invalidFields = validation.fields
                store.errorMessage = validation.message
                return
            }
            store.errorMessage = nil
        }
        .onChange(of: store.addressEditorState.isReviewPresented) { _, isPresented in
            guard !isPresented,
                  store.addressEditorState.confirmedAddress == nil else { return }
            isContinuingAfterAddressConfirmation = false
        }
        .overlay(alignment: .bottom) {
            if let feedbackCenter {
                BeckonGlobalFeedbackOverlay(
                    center: feedbackCenter,
                    bottomPadding: BeckonGlobalFeedbackOverlay.sheetBottomClearance
                )
            }
        }
        .accessibilityIdentifier("customer.requests.wizard")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
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
        VStack(spacing: DesignTokens.Spacing.lg) {
            ForEach(store.pets) { pet in
                CustomerRequestPetChoiceCard(
                    pet: pet,
                    petPhotoData: store.primaryPetPhotoData(for: pet),
                    isSelected: store.selectedPetID == pet.id,
                    isInvalid: invalidFields.contains(.pet)
                ) {
                    store.selectedPetID = pet.id
                    clearInvalidField(.pet)
                }
            }

            CustomerRequestAddPetButton {
                addPet()
            }
            .disabled(onAddPet == nil)

            if store.pets.isEmpty {
                BeckonStatusChip(
                    "Add a Pet Before Continuing",
                    systemImage: "pawprint",
                    tone: .warning
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var serviceStep: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(CustomerRequestServiceOption.allCases) { option in
                CustomerRequestServiceOptionCard(
                    option: option,
                    isSelected: store.serviceType == option,
                    isInvalid: invalidFields.contains(.service)
                ) {
                    store.serviceType = option
                    clearInvalidField(.service)
                }
            }
        }
    }

    private var timeStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
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
                selectedDate: selectedDate,
                calendar: calendar
            ) { date in
                selectedDate = date
                clearInvalidField(.timeWindow)
                applySelectedTimeWindow()
            }

            BeckonFieldGroup("Time Window") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    CustomerRequestTimeWindowGrid(
                        selectedTimeWindow: selectedTimeWindow,
                        isFlexibleWithTime: isFlexibleWithTime,
                        isInvalid: invalidFields.contains(.timeWindow)
                    ) { option in
                        selectedTimeWindow = option
                        isFlexibleWithTime = false
                        clearInvalidField(.timeWindow)
                        applySelectedTimeWindow()
                    }

                    if selectedTimeWindow == .detailed && !isFlexibleWithTime {
                        CustomerRequestDetailedTimeFields(
                            preferredStart: $store.preferredStart,
                            preferredEnd: $store.preferredEnd,
                            isInvalid: invalidFields.contains(.timeWindow)
                        )
                        .onChange(of: store.preferredStart) { _, _ in
                            clearInvalidField(.timeWindow)
                        }
                        .onChange(of: store.preferredEnd) { _, _ in
                            clearInvalidField(.timeWindow)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        occurrencePicker(isStart: true, calendar: calendar)
                        occurrencePicker(isStart: false, calendar: calendar)
                    }

                    CustomerRequestFlexibleTimeToggle(
                        isOn: Binding(
                            get: { isFlexibleWithTime },
                            set: { newValue in
                                isFlexibleWithTime = newValue
                                clearInvalidField(.timeWindow)
                                applySelectedTimeWindow()
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
                isStateInvalid: invalidFields.contains(.state),
                locationMode: store.locationMode,
                travelRangeMiles: $store.travelRadiusMiles,
                isApplyingProfileAddress: isApplyingProfileAddress,
                useProfileAddress: applyProfileAddress,
                clearInvalidField: clearInvalidField,
                onFieldFocused: { focusedInputTarget = $0 }
            )
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            BeckonFieldGroup(
                "Notes To Groomers",
                errorText: notesErrorText
            ) {
                TextField("Share coat goals, sensitivities, or handling notes.", text: $store.serviceNotes, axis: .vertical)
                    .lineLimit(5...8)
                    .focused($isNotesFocused)
                    .beckonFormField(isInvalid: invalidFields.contains(.notes))
                    .accessibilityIdentifier("customer.requests.wizard.notes")
                    .onTapGesture {
                        clearInvalidField(.notes)
                    }
                    .onChange(of: store.serviceNotes) { _, _ in
                        clearInvalidField(.notes)
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
                        Label("Add Request Photos", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer))
                    .accessibilityIdentifier("customer.requests.wizard.add-photos")
                }
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            BeckonCard(padding: DesignTokens.Spacing.xl) {
                VStack(spacing: 0) {
                    ForEach(reviewPresentation.rows) { row in
                        CustomerRequestWizardReviewRow(row: row)

                        if row.id != reviewPresentation.rows.last?.id {
                            Divider()
                                .overlay(DesignTokens.Colors.borderSoft)
                        }
                    }
                }
            }

            if !store.pendingRequestPhotos.isEmpty {
                BeckonFieldGroup(
                    "Selected Request Photos",
                    supportingText: "These photos will be included with this request."
                ) {
                    CustomerRequestPendingPhotoList(
                        photos: store.pendingRequestPhotos,
                        onRemove: nil
                    )
                }
            }

            CustomerRequestWizardFitInputCard(
                presentation: reviewFitInputPresentation
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Label("How Matching Works", systemImage: "info.circle")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.customerAccentStrong)

                Text(CustomerRequestMatchingCopy.customerReviewInfo)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.customerAccent.opacity(0.12))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )

            Label(
                "Your phone and email stay hidden until you accept an offer. Groomers see the request location details needed to decide whether to offer.",
                systemImage: "lock"
            )
            .font(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryActionState: CustomerRequestWizardPrimaryActionState {
        CustomerRequestWizardPrimaryActionState(
            isSubmitting: store.isSubmitting,
            isAwaitingAddressConfirmation: isContinuingAfterAddressConfirmation
        )
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
        return CustomerRequestWizardDateFormatting.compactRange(from: range.start, to: range.end,
            calendar: calendar) + " (\(calendar.timeZone.identifier))"
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
        guard invalidFields.contains(.notes) else { return nil }
        if store.serviceType == .customRequest {
            return CustomerRequestWizardStepValidation.customRequestNotesMessage
        }

        return "Service notes must be 2,000 characters or fewer."
    }

    private func back() {
        guard !store.isSubmitting else { return }

        if let previous = currentStep.previous {
            currentStep = previous
        } else {
            store.cancelWizard()
        }
    }

    private func continueForward() {
        let validation = store.validateWizardStep(currentStep)
        guard validation.isValid else {
            if currentStep == .time,
               validation.requiresOnlyAddressConfirmation {
                invalidFields = []
                store.errorMessage = nil
                globallyPresentedErrorMessage = nil
                isContinuingAfterAddressConfirmation = true
                Task {
                    let result = await store.addressEditorState.prepareConfirmation(requiringTimeZone: true)
                    guard isContinuingAfterAddressConfirmation else { return }
                    guard result != .needsReview else { return }
                    isContinuingAfterAddressConfirmation = false
                    guard result == .confirmed else { return }
                }
                return
            }

            globallyPresentedErrorMessage = nil
            invalidFields = validation.fields
            store.errorMessage = validation.message
            return
        }

        invalidFields = []
        store.errorMessage = nil

        if currentStep == .review {
            publish()
        } else if let next = currentStep.next {
            currentStep = next
        }
    }

    private func publish() {
        globallyPresentedErrorMessage = nil
        Task {
            await store.publish()
            guard store.isShowingWizard,
                  let errorMessage = store.errorMessage else { return }
            globallyPresentedErrorMessage = errorMessage
            feedbackCenter?.showError(
                BeckonGlobalFeedbackError(
                    scope: .operation("customer.requests.publish"),
                    sourceKey: "customer.requests.publish.failure",
                    title: "We Could Not Publish Request",
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
        guard !isApplyingProfileAddress else { return }
        isContinuingAfterAddressConfirmation = false
        guard let customerProfileRepository else {
            showNoProfileAddressPrompt()
            return
        }

        isApplyingProfileAddress = true
        Task { @MainActor in
            defer { isApplyingProfileAddress = false }

            do {
                let profile = try await customerProfileRepository.profile(
                    customerID: store.customerID
                )
                guard let autofill = CustomerProfileAddressAutofill.make(from: profile) else {
                    showNoProfileAddressPrompt()
                    return
                }

                store.applyProfileAddressAutofill(autofill)
                clearInvalidField(.streetAddress)
                clearInvalidField(.city)
                clearInvalidField(.state)
                clearInvalidField(.zipCode)
            } catch CustomerProfileRepositoryError.cancelled {
                return
            } catch {
                showProfileAddressUnavailablePrompt()
            }
        }
    }

    private func showNoProfileAddressPrompt() {
        showProfileAddressPrompt(
            BeckonGlobalFeedbackError(
                scope: .operation("customer.requests.profile-address"),
                sourceKey: "customer.requests.profile-address.missing",
                title: "No Profile Address",
                message: "Add an address in Account Profile Settings first."
            )
        )
    }

    private func showProfileAddressUnavailablePrompt() {
        showProfileAddressPrompt(
            BeckonGlobalFeedbackError(
                scope: .operation("customer.requests.profile-address"),
                sourceKey: "customer.requests.profile-address.unavailable",
                title: "Profile Address Unavailable",
                message: "We could not load your saved profile address. Please try again."
            )
        )
    }

    private func showProfileAddressPrompt(_ error: BeckonGlobalFeedbackError) {
        feedbackCenter?.clearError(matching: error)
        feedbackCenter?.showError(error)
    }

    private func applyInitialDefaults() {
        currentStep = store.wizardInitialStep
        selectedDate = store.preferredStart
        guard store.wizardInitialStep != .review else {
            selectedTimeWindow = .detailed
            isFlexibleWithTime = false
            return
        }

        selectedTimeWindow = .afternoon
        isFlexibleWithTime = false
        applySelectedTimeWindow()
    }

    private func applySelectedTimeWindow() {
        guard let calendar = store.requestCalendar else { return }
        if isFlexibleWithTime {
            let range = CustomerRequestTimeWindowOption.flexibleRange(on: selectedDate, calendar: calendar)
            store.preferredStart = range.start
            store.preferredEnd = range.end
            return
        }

        guard let range = selectedTimeWindow.range(on: selectedDate, calendar: calendar) else {
            if !store.applyDetailedDate(selectedDate) { selectedDate = store.preferredStart }
            return
        }

        store.preferredStart = range.start
        store.preferredEnd = range.end
    }

    private func clearInvalidField(_ field: CustomerRequestWizardValidationField) {
        guard invalidFields.remove(field) != nil else { return }

        if invalidFields.isEmpty,
           store.errorMessage == CustomerRequestWizardStepValidation.requiredFieldsMessage {
            store.errorMessage = nil
        }
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

    static func compactRange(from start: Date, to end: Date, calendar: Calendar) -> String {
        "\(compactDateTime(start, calendar: calendar)) - \(compactDateTime(end, calendar: calendar))"
    }

    static func compactDateTime(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

}

private struct CustomerRequestWizardHeader: View {
    let currentStep: CustomerRequestWizardStep

    var body: some View {
        progressContent
            .padding(
                .leading,
                CustomerRequestWizardHeaderLayout.progressTrackLeadingOffset
            )
    }

    private var progressContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Grooming Request")
                .font(DesignTokens.Typography.fieldLabel)
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignTokens.Colors.border.opacity(0.8))

                    Capsule()
                        .fill(DesignTokens.Colors.customerAccent)
                        .frame(width: proxy.size.width * currentStep.progress)
                }
            }
            // Progress is non-text geometry and remains a stable thin track.
            .frame(height: DesignTokens.Spacing.sm)

            currentStepLabel
                .padding(.top, DesignTokens.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var currentStepLabel: some View {
        Text("Step \(currentStep.rawValue + 1) of \(CustomerRequestWizardStep.allCases.count): \(currentStep.title)")
            .font(DesignTokens.Typography.supporting)
            .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
            .fixedSize(horizontal: false, vertical: true)
    }

}

nonisolated enum CustomerRequestWizardHeaderLayout {
    static let progressTrackLeadingOffset: CGFloat = 0
}

struct CustomerRequestWizardProgressLayout: Equatable {
    let usesSingleColumnChoices: Bool

    init(dynamicTypeSize: DynamicTypeSize) {
        usesSingleColumnChoices = dynamicTypeSize.isAccessibilitySize
    }

}

private struct CustomerRequestWizardBottomBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let currentStep: CustomerRequestWizardStep
    let isSubmitting: Bool
    let isPrimaryActionEnabled: Bool
    let needsAddressConfirmation: Bool
    let backAction: () -> Void
    let continueAction: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    actions
                }
            } else {
                HStack(spacing: DesignTokens.Spacing.md) {
                    actions
                }
            }
        }
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.actionAreaInset)
        .background(
            LinearGradient(
                colors: [
                    DesignTokens.Colors.background.opacity(0.2),
                    DesignTokens.Colors.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private var actions: some View {
        Button("Back", action: backAction)
            .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
            .disabled(isSubmitting)
            .accessibilityIdentifier(
                currentStep == .pet
                    ? "customer.requests.wizard.dismiss"
                    : "customer.requests.wizard.back"
            )

        Button(action: continueAction) {
            Text(primaryTitle)
        }
        .buttonStyle(
            BeckonPrimaryButtonStyle(
                isVisuallyEnabled: isPrimaryActionEnabled
            )
        )
        .disabled(!isPrimaryActionEnabled)
        .accessibilityIdentifier(
            currentStep == .review
                ? "customer.requests.publish"
                : "customer.requests.wizard.continue"
        )
    }

    private var primaryTitle: String {
        if isSubmitting {
            return "Publishing..."
        }

        if needsAddressConfirmation { return "Confirm Address" }
        return currentStep == .review ? "Publish Request" : "Continue"
    }
}

private struct CustomerRequestPetChoiceCard: View {
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
            HStack(spacing: DesignTokens.Spacing.lg) {
                CustomerRequestWizardPetAvatar(
                    pet: pet,
                    data: petPhotoData,
                    size: 84
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(pet.name)
                        .font(DesignTokens.Typography.cardTitle)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DesignTokens.Spacing.sm)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DesignTokens.Typography.action)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(DesignTokens.Colors.customerAccent.opacity(0.42))
                        .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        }
        .accessibilityIdentifier(
            "customer.requests.wizard.pet.\(pet.species.lowercased())"
        )
    }

    private var subtitle: String {
        let breed = pet.displayBreed?.trimmingCharacters(in: .whitespacesAndNewlines)
        let breedText = breed?.isEmpty == false ? breed ?? pet.displaySpecies : pet.displaySpecies
        if let weight = pet.weightLbs {
            return "\(breedText) · \(weight.formatted(.number.precision(.fractionLength(0...1)))) lbs"
        }

        return breedText
    }
}

private struct CustomerRequestAddPetButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "plus")
                    .font(DesignTokens.Typography.cardTitle)

                Text("Add A New Pet")
                    .font(DesignTokens.Typography.body.weight(.bold))
            }
            .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(DesignTokens.Colors.surface.opacity(0.5))
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
                .stroke(
                    DesignTokens.Colors.border,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
            }
        }
        .buttonStyle(.plain)
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
                    .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
                    .frame(width: 64, height: 64)
                    .background(DesignTokens.Colors.customerAccent.opacity(0.12))
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
                            .foregroundStyle(isSelected(date) ? DesignTokens.Colors.surface : DesignTokens.Colors.textPrimary)
                            .frame(width: 76, height: 92)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: DesignTokens.CornerRadius.button,
                                    style: .continuous
                                )
                                .fill(isSelected(date) ? DesignTokens.Colors.customerAccent : DesignTokens.Colors.surface)
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: DesignTokens.CornerRadius.button,
                                    style: .continuous
                                )
                                .stroke(
                                    isSelected(date) ? DesignTokens.Colors.customerAccent : DesignTokens.Colors.border,
                                    lineWidth: 1.2
                                )
                            }
                        }
                        .buttonStyle(.plain)
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
            .tint(DesignTokens.Colors.customerAccentStrong)
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
                                ? DesignTokens.Colors.surface
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
                                        ? DesignTokens.Colors.customerAccent
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
                .buttonStyle(.plain)
            }
        }
        .opacity(isFlexibleWithTime ? 0.56 : 1)
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
            return DesignTokens.Colors.error
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

            DatePicker(
                "End Time",
                selection: $preferredEnd,
                displayedComponents: [.hourAndMinute]
            )
            .font(DesignTokens.Typography.body.weight(.semibold))
            .beckonFormField(isInvalid: isInvalid)
        }
    }
}

private struct CustomerRequestFlexibleTimeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("I'm Flexible With Time")
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("Any time on this date")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .tint(DesignTokens.Colors.customerAccent)
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
                            .tint(DesignTokens.Colors.customerAccentStrong)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(DesignTokens.Typography.action)
                    }

                    Text(isApplyingProfileAddress ? "Loading Profile Address..." : "Use Profile Address")
                        .font(DesignTokens.Typography.action)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(DesignTokens.Colors.customerAccent.opacity(0.1))
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
                    .stroke(DesignTokens.Colors.customerAccent.opacity(0.2), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
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
                    HStack {
                        Text("Travel Range")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Spacer()

                        Text("\(CustomerRequestTravelRange.clampedMiles(Double(travelRangeMiles))) mi")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(travelRangeMiles) },
                            set: { travelRangeMiles = CustomerRequestTravelRange.clampedMiles($0) }
                        ),
                        in: Double(CustomerRequestTravelRange.minimumMiles)...Double(CustomerRequestTravelRange.maximumMiles),
                        step: 1
                    )
                    .tint(DesignTokens.Colors.customerAccent)

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
                        .foregroundStyle(DesignTokens.Colors.surface)
                        .frame(width: 30, height: 30)
                        .background(DesignTokens.Colors.error)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
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
            fallbackText: avatar,
            background: AnyShapeStyle(avatarBackground),
            width: size,
            height: size,
            cornerRadius: DesignTokens.CornerRadius.input
        )
    }

    private var avatar: String {
        let searchText = "\(pet.displayBreed ?? "") \(pet.displaySpecies)".lowercased()
        if searchText.contains("poodle") {
            return "🐩"
        } else if searchText.contains("cat") {
            return "🐱"
        } else if searchText.contains("bird") {
            return "🐦"
        } else if searchText.contains("rabbit") {
            return "🐰"
        } else if searchText.contains("dog") {
            return "🐶"
        }

        return "🐾"
    }

    private var avatarBackground: Color {
        let palette = [
            DesignTokens.Colors.groomerAccent.opacity(0.22),
            DesignTokens.Colors.customerAccent.opacity(0.22),
            DesignTokens.Colors.warning.opacity(0.18),
        ]
        return palette[abs(pet.name.hashValue) % palette.count]
    }
}

private struct CustomerRequestWizardReviewRow: View {
    let row: CustomerRequestWizardReviewPresentation.Row

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.lg) {
                title
                    .frame(maxWidth: 132, alignment: .leading)
                value
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                title
                value
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    private var title: some View {
        Text(row.title)
            .font(DesignTokens.Typography.supporting)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
    }

    private var value: some View {
        Text(row.value)
            .font(DesignTokens.Typography.action)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CustomerRequestWizardFitInputCard: View {
    let presentation: CustomerRequestWizardFitInputPresentation

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 132),
                spacing: DesignTokens.Spacing.sm,
                alignment: .leading
            ),
        ]
    }

    var body: some View {
        BeckonCard(padding: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Label("Fit Needs", systemImage: "sparkles")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.customerAccentStrong)

                Text("Based on the selected pet and service.")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if presentation.chips.isEmpty {
                    Label("No specific needs detected", systemImage: "checkmark.circle")
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVGrid(
                        columns: columns,
                        alignment: .leading,
                        spacing: DesignTokens.Spacing.sm
                    ) {
                        ForEach(presentation.chips) { chip in
                            CustomerRequestWizardFitInputChip(chip: chip)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CustomerRequestWizardFitInputChip: View {
    let chip: CustomerRequestWizardFitInputPresentation.Chip

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: chip.systemImage)
                .font(DesignTokens.Typography.status)
                .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(chip.label)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(chip.title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(DesignTokens.Colors.customerAccent.opacity(0.1))
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.button,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.button,
                style: .continuous
            )
            .stroke(DesignTokens.Colors.customerAccent.opacity(0.2), lineWidth: 1)
        )
    }
}
