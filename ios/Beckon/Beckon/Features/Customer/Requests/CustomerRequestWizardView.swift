import Foundation
import PhotosUI
import SwiftUI

typealias CustomerRequestServiceOption = GroomingServiceType

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
        notes: String
    ) {
        rows = [
            Row(title: "Pet", value: pet),
            Row(title: "Service", value: service),
            Row(title: "Preferred Time", value: preferredTime),
            Row(title: "Location", value: location),
            Row(title: "Notes", value: notes),
        ]
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
    @State private var selectedServiceOption: CustomerRequestServiceOption?
    @State private var selectedDate: Date
    @State private var selectedTimeWindow: CustomerRequestTimeWindowOption
    @State private var isFlexibleWithTime = false
    @State private var selectedRequestPhotoItem: PhotosPickerItem?
    @State private var invalidFields: Set<CustomerRequestWizardValidationField> = []
    @State private var isApplyingProfileAddress = false
    @State private var isAddressStreetActive = false
    @StateObject private var addressSearch = CustomerRequestAddressSearch()

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
        _selectedServiceOption = State(
            initialValue: store.serviceType
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                        CustomerRequestWizardHeader(
                            currentStep: currentStep,
                            backAction: back
                        )

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            Text(currentStep.headline)
                                .font(DesignTokens.Typography.largeTitle)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                .fixedSize(horizontal: false, vertical: true)

                            if let subtitle = currentStep.subtitle {
                                Text(subtitle)
                                    .font(DesignTokens.Typography.body)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        stepContent

                        if let errorMessage = store.errorMessage {
                            BeckonErrorBanner(
                                title: "Check Request Details",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("customer.requests.form-error")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, 128)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .overlayPreferenceValue(CustomerRequestStreetFieldAnchorKey.self) { anchor in
                GeometryReader { proxy in
                    if let anchor,
                       CustomerRequestAddressOverlay.shouldPresent(
                           isStreetActive: isAddressStreetActive,
                           suggestionCount: addressSearch.suggestions.count
                       ) {
                        let frame = proxy[anchor]
                        CustomerRequestAddressSuggestionOverlay(
                            suggestions: Array(addressSearch.suggestions.prefix(4)),
                            fieldFrame: frame,
                            dismiss: dismissAddressSuggestions,
                            select: applyAddressSuggestion
                        )
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                CustomerRequestWizardBottomBar(
                    currentStep: currentStep,
                    isSubmitting: store.isSubmitting,
                    canContinue: canContinue,
                    backAction: back,
                    continueAction: continueForward
                )
            }
            .tint(DesignTokens.Colors.customerPrimaryDark)
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled(store.isSubmitting)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            applyInitialDefaults()
        }
        .onChange(of: selectedRequestPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await addPendingRequestPhoto(newItem)
            }
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
                    isSelected: selectedServiceOption == option
                ) {
                    selectedServiceOption = option
                    store.serviceType = option
                    clearInvalidField(.service)
                }
            }
        }
    }

    private var timeStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            CustomerRequestDateStrip(
                selectedDate: selectedDate
            ) { date in
                selectedDate = date
                clearInvalidField(.timeWindow)
                applySelectedTimeWindow()
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Time Window")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

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

            locationSection
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Location")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            ForEach(CustomerRequestLocationMode.allCases) { mode in
                CustomerRequestLocationModeCard(
                    mode: mode,
                    isSelected: store.locationMode == mode
                ) {
                    store.locationMode = mode
                }
            }

            CustomerRequestAddressFields(
                streetAddress: $store.streetAddress,
                city: $store.city,
                stateCode: $store.stateCode,
                zipCode: $store.zipCode,
                locationMode: store.locationMode,
                travelRangeMiles: $store.travelRadiusMiles,
                invalidFields: invalidFields,
                isApplyingProfileAddress: isApplyingProfileAddress,
                useProfileAddress: applyProfileAddress,
                clearInvalidField: clearInvalidField,
                addressSearch: addressSearch,
                isStreetActive: $isAddressStreetActive
            )
        }
    }

    private func dismissAddressSuggestions() {
        isAddressStreetActive = false
    }

    private func applyAddressSuggestion(_ suggestion: CustomerRequestAddressSuggestion) {
        Task {
            guard let address = await addressSearch.resolve(suggestion) else { return }
            store.streetAddress = address.streetAddress
            store.city = address.city
            store.stateCode = address.stateCode
            store.zipCode = address.zipCode
            clearInvalidField(.streetAddress)
            clearInvalidField(.city)
            clearInvalidField(.state)
            clearInvalidField(.zipCode)
            dismissAddressSuggestions()
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Notes To Groomers")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                TextField("Share coat goals, sensitivities, or handling notes.", text: $store.serviceNotes, axis: .vertical)
                    .lineLimit(5...8)
                    .beckonFormField(isInvalid: invalidFields.contains(.notes))
                    .accessibilityIdentifier("customer.requests.wizard.notes")
                    .onTapGesture {
                        clearInvalidField(.notes)
                    }
                    .onChange(of: store.serviceNotes) { _, _ in
                        clearInvalidField(.notes)
                    }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Photos")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                HStack(spacing: DesignTokens.Spacing.md) {
                    let pendingPhotoCount = store.pendingRequestPhotos.count

                    if let pet = store.selectedPet {
                        CustomerRequestPhotoPreviewTile(
                            pet: pet,
                            petPhotoData: store.primaryPetPhotoData(for: pet)
                        )
                    }

                    PhotosPicker(
                        selection: $selectedRequestPhotoItem,
                        matching: .images
                    ) {
                        CustomerRequestAddPhotoTile(
                            photoCount: pendingPhotoCount
                        )
                    }
                    .buttonStyle(.plain)
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

            CustomerRequestWizardFitInputCard(
                presentation: reviewFitInputPresentation
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Label("How Matching Works", systemImage: "info.circle")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)

                Text(CustomerRequestMatchingCopy.customerReviewInfo)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.customerPrimary.opacity(0.12))
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

    private var canContinue: Bool {
        !store.isSubmitting && store.validateWizardStep(currentStep).isValid
    }

    private var reviewPresentation: CustomerRequestWizardReviewPresentation {
        CustomerRequestWizardReviewPresentation(
            pet: reviewPetSummary,
            service: store.serviceType.title,
            preferredTime: reviewPreferredTimeSummary,
            location: reviewLocationSummary,
            notes: notesSummary
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
        let day = CustomerRequestWizardDateFormatting.daySummary(selectedDate)
        if isFlexibleWithTime {
            return "\(day) · Flexible"
        }

        if selectedTimeWindow == .detailed {
            return CustomerRequestWizardDateFormatting.compactRange(
                from: store.preferredStart,
                to: store.preferredEnd
            )
        }

        return "\(day) · \(selectedTimeWindow.title)"
    }

    private var reviewLocationSummary: String {
        let location = [
            store.streetAddress.trimmingCharacters(in: .whitespacesAndNewlines),
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
        Task {
            await store.publish()
        }
    }

    private func addPet() {
        guard let onAddPet else { return }
        onAddPet()
    }

    private func addPendingRequestPhoto(_ item: PhotosPickerItem) async {
        defer { selectedRequestPhotoItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        let contentType = item.supportedContentTypes
            .lazy
            .compactMap(GroomingRequestPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        store.addPendingPhoto(
            data: data,
            contentType: contentType
        )
    }

    private func applyProfileAddress() {
        guard !isApplyingProfileAddress else { return }
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

                store.streetAddress = autofill.streetAddress
                store.city = autofill.city
                store.stateCode = autofill.stateCode
                store.zipCode = autofill.zipCode
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
        selectedServiceOption = store.serviceType
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
        if isFlexibleWithTime {
            let range = CustomerRequestTimeWindowOption.flexibleRange(on: selectedDate)
            store.preferredStart = range.start
            store.preferredEnd = range.end
            return
        }

        guard let range = selectedTimeWindow.range(on: selectedDate) else {
            store.preferredStart = CustomerRequestWizardDateFormatting.date(
                matchingTimeOf: store.preferredStart,
                on: selectedDate
            )
            store.preferredEnd = CustomerRequestWizardDateFormatting.date(
                matchingTimeOf: store.preferredEnd,
                on: selectedDate
            )
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
    static func daySummary(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }

    static func compactRange(from start: Date, to end: Date) -> String {
        "\(compactDateTime(start)) - \(compactDateTime(end))"
    }

    static func compactDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    static func date(
        matchingTimeOf source: Date,
        on selectedDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        let time = calendar.dateComponents([.hour, .minute], from: source)
        return calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate
    }
}

private struct CustomerRequestWizardHeader: View {
    let currentStep: CustomerRequestWizardStep
    let backAction: () -> Void
    private let progressLayout = CustomerRequestWizardProgressLayout(
        backButtonWidth: 54,
        horizontalSpacing: DesignTokens.Spacing.md
    )

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: progressLayout.horizontalSpacing) {
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .frame(
                            width: progressLayout.backButtonWidth,
                            height: progressLayout.backButtonWidth
                        )
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
                            .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier(
                    currentStep == .pet
                        ? "customer.requests.wizard.dismiss"
                        : "customer.requests.wizard.header-back"
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Grooming Request")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DesignTokens.Colors.border.opacity(0.8))

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DesignTokens.Colors.customerPrimary,
                                            DesignTokens.Colors.customerPrimary.opacity(0.6),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: proxy.size.width * currentStep.progress)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        ForEach(CustomerRequestWizardStep.allCases) { step in
                            Text(step.title)
                                .font(DesignTokens.Typography.caption.weight(.bold))
                                .foregroundStyle(labelColor(for: step))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.xs)
                }
            }
        }
    }

    private func labelColor(for step: CustomerRequestWizardStep) -> Color {
        if step == currentStep {
            return DesignTokens.Colors.customerPrimaryDark
        }

        if step.rawValue < currentStep.rawValue {
            return DesignTokens.Colors.textPrimary
        }

        return DesignTokens.Colors.textSecondary
    }
}

struct CustomerRequestWizardProgressLayout: Equatable {
    let backButtonWidth: CGFloat
    let horizontalSpacing: CGFloat

    var progressTrackLeadingOffset: CGFloat {
        backButtonWidth + horizontalSpacing
    }

    var shouldLabelRowShareProgressTrackWidth: Bool {
        true
    }
}

private struct CustomerRequestWizardBottomBar: View {
    let currentStep: CustomerRequestWizardStep
    let isSubmitting: Bool
    let canContinue: Bool
    let backAction: () -> Void
    let continueAction: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button("Back", action: backAction)
                .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
                .frame(width: 132)
                .disabled(isSubmitting)

            Button(action: continueAction) {
                Text(primaryTitle)
            }
            .buttonStyle(
                CustomerRequestWizardPrimaryButtonStyle(
                    isVisuallyEnabled: canContinue && !isSubmitting
                )
            )
            .disabled(isSubmitting)
            .accessibilityIdentifier(
                currentStep == .review
                    ? "customer.requests.publish"
                    : "customer.requests.wizard.continue"
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.md)
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

    private var primaryTitle: String {
        if isSubmitting {
            return "Publishing..."
        }

        return currentStep == .review ? "Publish Request" : "Continue"
    }
}

private struct CustomerRequestWizardPrimaryButtonStyle: ButtonStyle {
    let isVisuallyEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.body.weight(.semibold))
            .foregroundStyle(
                isVisuallyEnabled
                    ? DesignTokens.Colors.surface
                    : DesignTokens.Colors.textTertiary
            )
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.button,
                    style: .continuous
                )
                .fill(backgroundGradient(isPressed: configuration.isPressed))
            }
            .beckonShadow(
                DesignTokens.Shadows.primaryAction,
                isVisible: isVisuallyEnabled
            )
            .scaleEffect(configuration.isPressed && isVisuallyEnabled ? 0.98 : 1)
            .opacity(isVisuallyEnabled ? 1 : 0.72)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isVisuallyEnabled)
    }

    private func backgroundGradient(isPressed: Bool) -> LinearGradient {
        let colors: [Color]

        if isVisuallyEnabled {
            colors = isPressed
                ? [
                    DesignTokens.Colors.customerPrimaryDark,
                    DesignTokens.Colors.customerPrimary,
                ]
                : [
                    DesignTokens.Colors.customerPrimary,
                    DesignTokens.Colors.customerPrimaryDark,
                ]
        } else {
            colors = [
                DesignTokens.Colors.borderSoft,
                DesignTokens.Colors.borderSoft,
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct CustomerRequestPetChoiceCard: View {
    let pet: CustomerPet
    let petPhotoData: Data?
    let isSelected: Bool
    let isInvalid: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.lg) {
                CustomerRequestWizardPetAvatar(
                    pet: pet,
                    data: petPhotoData,
                    size: 84
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(pet.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: DesignTokens.Spacing.sm)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.surface)
                        .frame(width: 42, height: 42)
                        .background(DesignTokens.Colors.customerPrimary)
                        .clipShape(Circle())
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
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
                .stroke(
                    borderColor,
                    lineWidth: isSelected || isInvalid ? 2 : 1
                )
            }
            .shadow(
                color: isInvalid ? DesignTokens.Colors.error.opacity(0.26) : .clear,
                radius: isInvalid ? 11 : 0,
                x: 0,
                y: 0
            )
            .beckonShadow(DesignTokens.Shadows.smallCard)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            "customer.requests.wizard.pet.\(pet.species.lowercased())"
        )
    }

    private var borderColor: Color {
        if isInvalid {
            return DesignTokens.Colors.error
        }

        return isSelected
            ? DesignTokens.Colors.customerPrimary
            : DesignTokens.Colors.border
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
                    .font(.title3.weight(.semibold))

                Text("Add A New Pet")
                    .font(DesignTokens.Typography.body.weight(.bold))
            }
            .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "scissors")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    .frame(width: 64, height: 64)
                    .background(DesignTokens.Colors.customerPrimary.opacity(0.12))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DesignTokens.CornerRadius.input,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(option.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(option.subtitle)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DesignTokens.Spacing.xs)
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
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
                .stroke(
                    isSelected ? DesignTokens.Colors.customerPrimary : DesignTokens.Colors.border,
                    lineWidth: isSelected ? 2 : 1
                )
            }
            .beckonShadow(DesignTokens.Shadows.smallCard)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            "customer.requests.wizard.service.\(option.rawValue)"
        )
    }
}

private struct CustomerRequestDateStrip: View {
    let selectedDate: Date
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: DesignTokens.Spacing.md) {
                ForEach(dateOptions, id: \.self) { date in
                    Button {
                        onSelect(date)
                    } label: {
                        VStack(spacing: DesignTokens.Spacing.xs) {
                            Text(dayName(date))
                                .font(DesignTokens.Typography.caption.weight(.bold))

                            Text(dayNumber(date))
                                .font(.title2.weight(.bold))
                        }
                        .foregroundStyle(isSelected(date) ? DesignTokens.Colors.surface : DesignTokens.Colors.textPrimary)
                        .frame(width: 76, height: 92)
                        .background(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.button,
                                style: .continuous
                            )
                            .fill(isSelected(date) ? DesignTokens.Colors.customerPrimary : DesignTokens.Colors.surface)
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.button,
                                style: .continuous
                            )
                            .stroke(
                                isSelected(date) ? DesignTokens.Colors.customerPrimary : DesignTokens.Colors.border,
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
        .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
        .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
    }

    private var dateOptions: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

private struct CustomerRequestTimeWindowGrid: View {
    let selectedTimeWindow: CustomerRequestTimeWindowOption
    let isFlexibleWithTime: Bool
    let isInvalid: Bool
    let action: (CustomerRequestTimeWindowOption) -> Void

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
                GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
            ],
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(
                                    selectedTimeWindow == option && !isFlexibleWithTime
                                        ? DesignTokens.Colors.customerPrimary
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
                        .shadow(
                            color: isInvalid && selectedTimeWindow == option
                                ? DesignTokens.Colors.error.opacity(0.22)
                                : .clear,
                            radius: isInvalid && selectedTimeWindow == option ? 8 : 0,
                            x: 0,
                            y: 0
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(isFlexibleWithTime ? 0.56 : 1)
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

                Text("Let groomers suggest nearby times")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .tint(DesignTokens.Colors.customerPrimary)
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

private struct CustomerRequestLocationModeCard: View {
    let mode: CustomerRequestLocationMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(mode.icon)
                    .font(.title2)
                    .frame(width: 44)

                Text(mode.customerTitle)
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.surface)
                        .frame(width: 34, height: 34)
                        .background(DesignTokens.Colors.customerPrimary)
                        .clipShape(Circle())
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 76)
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
                .stroke(
                    isSelected ? DesignTokens.Colors.customerPrimary : DesignTokens.Colors.border,
                    lineWidth: isSelected ? 2 : 1
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CustomerRequestAddressFields: View {
    @Binding var streetAddress: String
    @Binding var city: String
    @Binding var stateCode: USStateCode?
    @Binding var zipCode: String
    let locationMode: CustomerRequestLocationMode
    @Binding var travelRangeMiles: Int
    let invalidFields: Set<CustomerRequestWizardValidationField>
    let isApplyingProfileAddress: Bool
    let useProfileAddress: () -> Void
    let clearInvalidField: (CustomerRequestWizardValidationField) -> Void
    @ObservedObject var addressSearch: CustomerRequestAddressSearch
    @Binding var isStreetActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Button(action: useProfileAddress) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if isApplyingProfileAddress {
                        ProgressView()
                            .tint(DesignTokens.Colors.customerPrimaryDark)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.headline.weight(.semibold))
                    }

                    Text(isApplyingProfileAddress ? "Loading Profile Address..." : "Use Profile Address")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 0)
                }
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(DesignTokens.Colors.customerPrimary.opacity(0.1))
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
                    .stroke(DesignTokens.Colors.customerPrimary.opacity(0.2), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(isApplyingProfileAddress)
            .accessibilityIdentifier("customer.requests.use-profile-address")

            BeckonLimitedTextField(
                placeholder: "Street Address",
                text: $streetAddress,
                maximumLength: 160,
                isInvalid: invalidFields.contains(.streetAddress),
                textContentType: .streetAddressLine1,
                autocapitalizationType: .words,
                addressInputRule: .street,
                onEditingBegan: {
                    isStreetActive = true
                    clearInvalidField(.streetAddress)
                },
                onTextChange: { newValue in
                    isStreetActive = true
                    clearInvalidField(.streetAddress)
                    addressSearch.update(
                        street: newValue,
                        city: city,
                        stateCode: stateCode
                    )
                }
            )
                .anchorPreference(
                    key: CustomerRequestStreetFieldAnchorKey.self,
                    value: .bounds,
                    transform: { $0 }
                )
                .accessibilityIdentifier("customer.requests.address.street")

            HStack(spacing: DesignTokens.Spacing.md) {
                BeckonLimitedTextField(
                    placeholder: "City",
                    text: $city,
                    maximumLength: 100,
                    isInvalid: invalidFields.contains(.city),
                    textContentType: .addressCity,
                    autocapitalizationType: .words,
                    addressInputRule: .city,
                    onEditingBegan: {
                        isStreetActive = false
                        clearInvalidField(.city)
                    },
                    onTextChange: { _ in
                        clearInvalidField(.city)
                    }
                )

                Menu {
                    ForEach(USStateCode.allCases) { state in
                        Button(state.rawValue) {
                            stateCode = state
                            clearInvalidField(.state)
                        }
                    }
                } label: {
                    HStack {
                        Text(stateCode?.rawValue ?? "State")
                            .foregroundStyle(
                                stateCode == nil
                                    ? DesignTokens.Colors.textSecondary
                                    : DesignTokens.Colors.textPrimary
                            )

                        Spacer(minLength: DesignTokens.Spacing.xs)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .beckonFormField(isInvalid: invalidFields.contains(.state))
                }
                    .onTapGesture {
                        clearInvalidField(.state)
                    }
                    .frame(width: 92)
            }

            BeckonLimitedTextField(
                placeholder: "ZIP Code",
                text: $zipCode,
                maximumLength: 5,
                isInvalid: invalidFields.contains(.zipCode),
                textContentType: .postalCode,
                keyboardType: .numberPad,
                autocapitalizationType: .none,
                addressInputRule: .zipCode,
                onEditingBegan: {
                    isStreetActive = false
                    clearInvalidField(.zipCode)
                },
                onTextChange: { _ in
                    clearInvalidField(.zipCode)
                }
            )

            if locationMode == .customerComesToGroomer {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Travel Range")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Spacer()

                        Text("\(CustomerRequestTravelRange.clampedMiles(Double(travelRangeMiles))) mi")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(travelRangeMiles) },
                            set: { travelRangeMiles = CustomerRequestTravelRange.clampedMiles($0) }
                        ),
                        in: Double(CustomerRequestTravelRange.minimumMiles)...Double(CustomerRequestTravelRange.maximumMiles),
                        step: 1
                    )
                    .tint(DesignTokens.Colors.customerPrimary)

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

nonisolated enum CustomerRequestAddressOverlay {
    static func shouldPresent(isStreetActive: Bool, suggestionCount: Int) -> Bool {
        isStreetActive && suggestionCount > 0
    }
}

private struct CustomerRequestStreetFieldAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct CustomerRequestAddressSuggestionOverlay: View {
    let suggestions: [CustomerRequestAddressSuggestion]
    let fieldFrame: CGRect
    let dismiss: () -> Void
    let select: (CustomerRequestAddressSuggestion) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button {
                        select(suggestion)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(DesignTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .lineLimit(1)

                            Text(suggestion.subtitle)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                    }
                    .buttonStyle(.plain)

                    if suggestion.id != suggestions.last?.id {
                        Divider()
                            .padding(.horizontal, DesignTokens.Spacing.md)
                    }
                }
            }
            .frame(width: fieldFrame.width)
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
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            .offset(x: fieldFrame.minX, y: fieldFrame.maxY + DesignTokens.Spacing.xs)
        }
        .zIndex(20)
    }
}

private struct CustomerRequestPhotoPreviewTile: View {
    let pet: CustomerPet
    let petPhotoData: Data?

    var body: some View {
        CustomerRequestWizardPetAvatar(
            pet: pet,
            data: petPhotoData,
            size: 112
        )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.input,
                    style: .continuous
                )
            )
    }
}

private struct CustomerRequestAddPhotoTile: View {
    let photoCount: Int

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: photoCount > 0 ? "checkmark.circle.fill" : "camera")
                .font(.title2.weight(.semibold))
                .foregroundStyle(
                    photoCount > 0
                        ? DesignTokens.Colors.customerPrimaryDark
                        : DesignTokens.Colors.textTertiary
                )

            Text(photoCount > 0 ? "\(photoCount) Added" : "Add")
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 112, height: 112)
        .background(DesignTokens.Colors.surface.opacity(0.4))
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
            .stroke(
                DesignTokens.Colors.border,
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
        }
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
            DesignTokens.Colors.customerPrimary.opacity(0.22),
            DesignTokens.Colors.warning.opacity(0.18),
        ]
        return palette[abs(pet.name.hashValue) % palette.count]
    }
}

private struct CustomerRequestWizardReviewRow: View {
    let row: CustomerRequestWizardReviewPresentation.Row

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.lg) {
            Text(row.title)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(maxWidth: 132, alignment: .leading)

            Text(row.value)
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
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
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)

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
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(chip.label)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(chip.title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(DesignTokens.Colors.customerPrimary.opacity(0.1))
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
            .stroke(DesignTokens.Colors.customerPrimary.opacity(0.2), lineWidth: 1)
        )
    }
}
