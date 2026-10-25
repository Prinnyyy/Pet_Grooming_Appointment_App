#if DEBUG
import SwiftUI

struct CustomerHomeFlowSandbox: View {
    @State private var session: CustomerHomeFlowSandboxSession
    @State private var path: [UUID] = []
    @State private var stage: GroomingRequestStatus
    @State private var replay = 0

    init(initialStage: GroomingRequestStatus = .open) {
        let session = CustomerHomeFlowSandboxSession()
        session.requestRepository.setPreviewStatus(initialStage)
        _session = State(initialValue: session)
        _stage = State(initialValue: initialStage)
    }

    var body: some View {
        NavigationStack(path: $path) {
            CustomerHomeView(previewSession: session) { path.append($0) }
                .navigationDestination(for: UUID.self) { requestID in
                    CustomerRequestDetailView(requestID: requestID, store: session.requests)
                }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Picker("Request stage", selection: $stage) {
                    Text("Posted").tag(GroomingRequestStatus.open)
                    Text("Offers").tag(GroomingRequestStatus.hasOffers)
                    Text("Booked").tag(GroomingRequestStatus.booked)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("sandbox.home.stage")
                .onChange(of: stage) { _, newStage in
                    session.requestRepository.setPreviewStatus(newStage)
                    Task { await session.reload() }
                }
                Button("Reload", systemImage: "arrow.clockwise") {
                    replay += 1
                    Task { await session.reload() }
                }
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .help("Reload Home and replay entrance")
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    session.pets.invalidate()
                    session = CustomerHomeFlowSandboxSession()
                    stage = .open
                    path = []
                }
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .help("Reset Home sandbox")
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surface)
        }
        .environment(\.beckonFeedbackCenter, session.pets.feedbackCenter)
        .environment(\.beckonCustomerDesign, true)
        .environment(\.sandboxRequestAdvance, session.advanceRequestPreview)
        .environment(\.beckonEntranceReplay, replay)
        .overlay(alignment: .bottom) {
            BeckonGlobalFeedbackOverlay(center: session.pets.feedbackCenter)
        }
        .tint(DesignTokens.Colors.customerDeep)
        .preferredColorScheme(.light)
        .id(session.pets.id)
        .task(id: session.pets.id) { await session.reload() }
    }
}

@MainActor
final class CustomerHomeFlowSandboxSession {
    let pets = CustomerPetsFlowSandboxSession()
    let defaults = HomePreviewMemoryDefaults()
    let requests: CustomerRequestsStore
    let bookings: BookingsStore
    let notifications: CustomerNotificationsStore
    let requestRepository: CustomerHomePreviewRequestRepository
    let bookingRepository: CustomerHomePreviewBookingRepository
    let notificationRepository: CustomerHomePreviewNotificationRepository

    init() {
        let pet = pets.repository.storedPets[0]
        let now = Date()
        requestRepository = CustomerHomePreviewRequestRepository(pet: pet, now: now)
        bookingRepository = CustomerHomePreviewBookingRepository(
            pet: pet, requestID: requestRepository.storedRequests[0].id, now: now)
        notificationRepository = CustomerHomePreviewNotificationRepository(
            request: requestRepository.storedRequests[0], booking: bookingRepository.sample)
        let petRepository = pets.repository
        bookings = BookingsStore(participantID: pet.customerID, role: .customer,
            repository: bookingRepository, appointmentReminderScheduler: HomePreviewReminders(),
            fulfillmentDefaults: defaults, sessionIsCurrent: { petRepository.isActive })
        requests = CustomerRequestsStore(customerID: pet.customerID, petRepository: petRepository,
            requestRepository: requestRepository, bookingRepository: bookingRepository,
            appointmentReminderScheduler: HomePreviewReminders(), handoffAcknowledgementDefaults: defaults,
            addressProvider: HomePreviewAddressProvider(), bookingsStore: bookings,
            sortPreferences: MatchSortPreferenceStore(defaults: defaults),
            publicationCoordinator: CustomerRequestPublicationCoordinator(customerID: pet.customerID,
                requestRepository: requestRepository,
                storageDirectory: pets.directory.appendingPathComponent("publications"),
                sessionIsCurrent: { petRepository.isActive }))
        requests.setAcceptanceSessionValidation { petRepository.isActive }
        notifications = CustomerNotificationsStore(customerID: pet.customerID, repository: notificationRepository)
    }

    func reload() async {
        await pets.store.load()
        await requests.load()
        for request in requests.activeRequests where request.status == .hasOffers {
            await requests.loadOffers(for: request)
        }
        await bookings.loadNearest()
        await notifications.load()
    }

    func advanceRequestPreview(_ flow: CustomerRequestWizardState) {
        guard pets.repository.isActive else { return }
        flow.invalidFields = []
        flow.isContinuingAfterAddressConfirmation = false
        requests.errorMessage = nil

        guard let next = flow.currentStep.next else {
            requests.cancelWizard()
            pets.feedbackCenter.showNotice("Preview complete. No request was published.")
            return
        }

        if requests.selectedPetID == nil { requests.selectedPetID = requests.pets.first?.id }
        if requests.serviceType == nil { requests.serviceType = .fullGroom }
        if next == .time || flow.currentStep == .time {
            var input = requests.addressEditorState.input
            if input.line1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { input.line1 = "123 Preview Street" }
            if input.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { input.city = "Los Angeles" }
            if input.stateCode == nil { input.stateCode = .california }
            if input.postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { input.postalCode = "90012" }
            // A local fixture unlocks time controls; it is not a geocoding result.
            let address = BeckonConfirmedAddress(entered: input, accepted: input,
                provider: "flow_sandbox", placeID: nil,
                coordinate: BeckonAddressCoordinate(latitude: 34.05, longitude: -118.24),
                resolutionSource: "ui_preview", confirmedAt: .now,
                timeZoneIdentifier: "America/Los_Angeles")
            requests.addressEditorState.replaceInput(input, confirmedAddress: address)
        }
        flow.currentStep = next
    }
}

private struct SandboxRequestAdvanceKey: EnvironmentKey {
    static let defaultValue: (@MainActor (CustomerRequestWizardState) -> Void)? = nil
}

extension EnvironmentValues {
    var sandboxRequestAdvance: (@MainActor (CustomerRequestWizardState) -> Void)? {
        get { self[SandboxRequestAdvanceKey.self] }
        set { self[SandboxRequestAdvanceKey.self] = newValue }
    }
}

// Override the accessors used by the injected Stores; no reads/writes reach persistent defaults.
nonisolated final class HomePreviewMemoryDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    init() { super.init(suiteName: "Beckon.HomePreview.\(UUID().uuidString)")! }
    override func object(forKey key: String) -> Any? { lock.withLock { values[key] } }
    override func set(_ value: Any?, forKey key: String) { lock.withLock { values[key] = value } }
    override func removeObject(forKey key: String) { lock.withLock { values[key] = nil } }
    override func string(forKey key: String) -> String? { object(forKey: key) as? String }
    override func stringArray(forKey key: String) -> [String]? { object(forKey: key) as? [String] }
    override func dictionary(forKey key: String) -> [String: Any]? { object(forKey: key) as? [String: Any] }
    override func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
}

struct HomePreviewReminders: AppointmentReminderScheduling {
    func syncReminders(for bookings: [Booking], role: UserRole) async -> AppointmentReminderSyncResult { .refused }
    func cancelReminder(for bookingID: UUID, role: UserRole) async {}
}

@MainActor
final class HomePreviewAddressProvider: BeckonAddressProviding {
    func updateSuggestions(for line1Query: String) async -> [BeckonAddressCandidate] { [] }
    func resolve(candidateID: String, preservingLine2: String) async throws -> BeckonResolvedAddress {
        throw BeckonAddressProviderError.unknownCandidate
    }
    func geocode(_ input: BeckonAddressInput) async throws -> [BeckonResolvedAddress] {
        var suggested = input
        if suggested.line1.isEmpty { suggested.line1 = "123 Preview Street" }
        if suggested.city.isEmpty { suggested.city = "Los Angeles" }
        if suggested.stateCode == nil { suggested.stateCode = .california }
        if suggested.postalCode.isEmpty { suggested.postalCode = "90012" }
        return [.init(provider: "flow_sandbox", placeID: nil,
            coordinate: .init(latitude: 34.05, longitude: -118.24), suggested: suggested,
            resolutionSource: "ui_preview", timeZoneIdentifier: "America/Los_Angeles")]
    }
    func clear() {}
}

#Preview("Customer Home - all modules") {
    CustomerHomeFlowSandbox()
}

#Preview("Customer Home - offers waiting") {
    CustomerHomeFlowSandbox(initialStage: .hasOffers)
}

#Preview("Customer Home - booked") {
    CustomerHomeFlowSandbox(initialStage: .booked)
}
#endif
