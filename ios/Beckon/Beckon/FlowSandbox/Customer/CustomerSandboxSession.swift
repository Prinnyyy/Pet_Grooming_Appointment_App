#if DEBUG
import SwiftUI

@MainActor
final class CustomerSandboxSession {
    let id = UUID()
    let screen: CustomerSandboxScreen
    let state: CustomerSandboxState
    let boundary = CustomerSandboxBoundary()
    let defaults = HomePreviewMemoryDefaults()
    let pets: CustomerPetsFlowSandboxSession
    var feedback: BeckonFeedbackCenter { pets.feedbackCenter }
    var customerID: UUID { CustomerSandboxFixtures.customerID }
    var authSession: AuthSessionSnapshot { .init(userID: customerID, email: "lian@example.test") }
    var marketplaceProfile: MarketplaceProfile { .init(userID: customerID, role: .customer, displayName: accountRepository.details.nickname) }
    lazy var marketplaceRepository = CustomerSandboxMarketplace(state: state, boundary: boundary)
    lazy var bookingRepository = CustomerSandboxBookings(
        state: screen == .review && state != .reviewed ? .completed : state,
        boundary: boundary, marketplace: marketplaceRepository)
    lazy var notificationRepository = CustomerSandboxNotifications(state: state, boundary: boundary)
    lazy var accountRepository = CustomerSandboxAccount(state: state, boundary: boundary)
    lazy var chatRepository = CustomerSandboxChat(state: state, boundary: boundary,
        booking: bookingRepository.items.first ?? CustomerSandboxFixtures.booking())
    lazy var publication = CustomerRequestPublicationCoordinator(customerID: customerID,
        requestRepository: marketplaceRepository, distributionRepository: marketplaceRepository,
        storageDirectory: pets.directory.appendingPathComponent("publications"),
        sessionIsCurrent: { [weak self] in self?.boundary.isActive == true })
    lazy var marketplace = CustomerMarketplaceSession(sandboxCustomerID: customerID, requestRepository: marketplaceRepository,
        services: .init(discovery: marketplaceRepository, distribution: marketplaceRepository,
            favorites: marketplaceRepository, images: marketplaceRepository), publication: publication,
        sessionIsCurrent: { [weak self] in self?.boundary.isActive == true })
    lazy var bookings = BookingsStore(participantID: customerID, role: .customer, repository: bookingRepository,
        appointmentReminderScheduler: HomePreviewReminders(), fulfillmentDefaults: defaults,
        sessionIsCurrent: { [weak self] in self?.boundary.isActive == true })
    lazy var requests: CustomerRequestsStore = {
        let store = CustomerRequestsStore(customerID: customerID, petRepository: pets.repository,
            requestRepository: marketplaceRepository, bookingRepository: bookingRepository,
            appointmentReminderScheduler: HomePreviewReminders(), handoffAcknowledgementDefaults: defaults,
            addressProvider: HomePreviewAddressProvider(), bookingsStore: bookings,
            sortPreferences: MatchSortPreferenceStore(defaults: defaults), publicationCoordinator: publication, marketplace: marketplace)
        store.setAcceptanceSessionValidation { [weak self] in self?.boundary.isActive == true }
        return store
    }()
    lazy var notifications = CustomerNotificationsStore(customerID: customerID, repository: notificationRepository)
    lazy var authentication = AuthenticationStore(repository: accountRepository, reminderScheduler: HomePreviewReminders())
    lazy var onboarding = AuthenticatedEntryStore(repository: accountRepository)
    lazy var profile = CustomerProfileStore(customerID: customerID, initialDisplayName: accountRepository.details.nickname,
        sessionEmail: authSession.email, repository: accountRepository, profileSnapshotCache: accountRepository,
        addressProvider: HomePreviewAddressProvider())
    lazy var chat: ChatStore = {
        let store = ChatStore(participantID: customerID, role: .customer, repository: chatRepository,
            bookingRepository: bookingRepository, readStateCache: UserDefaultsChatReadStateCache(userDefaults: defaults))
        store.sandboxBookingStore = bookings
        return store
    }()
    lazy var discoveryFlow = state == .draft ? makeDraftDiscoveryFlow() : CustomerRequestDiscoveryFlow(store: .init(
        scope: .request(id: CustomerSandboxFixtures.requestID, termsRevision: CustomerSandboxFixtures.id(120)),
        repository: marketplaceRepository))

    init(screen: CustomerSandboxScreen = .tabs, state: CustomerSandboxState = .loaded) {
        self.screen = screen; self.state = state
        let repository = CustomerPetsPreviewRepository(customerID: CustomerSandboxFixtures.customerID)
        pets = CustomerPetsFlowSandboxSession(repository: repository)
        repository.configureSandbox(state: state, boundary: boundary)
    }

    func prepare() async throws {
        marketplaceRepository.pets = { [weak self] in self?.pets.repository.storedPets ?? [] }
        if screen == .offers && state == .empty {
            marketplaceRepository.items = [CustomerSandboxFixtures.request(state: .open)]
        }
        if screen == .publication || screen == .photoRetry {
            let draft = self.draft
            let prepared = marketplaceRepository.prepareLocal(draft: draft, id: CustomerSandboxFixtures.id(200))
            var intent = PendingRequestPublication(customerID: customerID, draft: draft,
                photos: screen == .photoRetry ? [.init(id: CustomerSandboxFixtures.id(92), data: CustomerSandboxFixtures.imageData,
                    contentType: .png)] : [],
                session: prepared,
                poolEnabled: true, groomerIDs: [CustomerSandboxFixtures.id(70)])
            if screen == .photoRetry { intent.acknowledgement = .discovery(marketplaceRepository.receipt()) }
            try publication.begin(intent)
        }
        let needsSeededRequest: Set<CustomerSandboxScreen> = [.requests, .dashboard, .requestDetail, .offers, .publication, .photoRetry,
            .groomerPicker, .groomerDetail, .candidateActions, .favorites]
        if needsSeededRequest.contains(screen) || screen.wizardStep != nil
            || ([.tabs, .home].contains(screen) && state != .loading && state != .error) {
            await requests.load()
            for request in requests.activeRequests where request.status == .hasOffers {
                await requests.loadOffers(for: request)
            }
            fillRequestDefaults()
        }
        if [.petCreate, .petEdit, .petRecovery].contains(screen) {
            await pets.store.load()
            if screen == .petEdit, let pet = pets.store.pets.first { pets.store.startEdit(pet) }
            else {
                pets.store.startCreate()
                pets.store.formName = state == .longNames ? CustomerSandboxFixtures.longName : "Mochi"
                if state == .photos {
                    pets.store.addPendingFormPhoto(data: CustomerSandboxFixtures.imageData, contentType: .png)
                }
            }
            if screen == .petRecovery { try pets.store.seedSandboxPendingCreation(operationID: CustomerSandboxFixtures.id(210)) }
            if state == .error { pets.repository.failsNextSave = true; pets.store.errorMessage = "The previous save could not be confirmed. Retry or reload." }
        }
        if let step = screen.wizardStep {
            requests.wizardInitialStep = step
            requests.isShowingWizard = true
            if state == .photos { requests.addPendingPhoto(data: CustomerSandboxFixtures.imageData, contentType: .png) }
            if state == .error { requests.errorMessage = "The request could not be checked. Your entries are preserved." }
        }
        authentication.rootState = [.landing, .signIn, .signUp].contains(screen) ? .signedOut : .signedIn(authSession)
        authentication.mode = screen == .signUp ? .signUp : .signIn
        authentication.email = state == .longNames
            ? "customer.with.a.long.preview.address@example.test" : "lian@example.test"
        authentication.password = "PreviewOnly123!"; authentication.passwordConfirmation = "PreviewOnly123!"
        authentication.recoveryEmail = "lian@example.test"
        authentication.recoveryPassword = "PreviewOnly123!"
        authentication.recoveryPasswordConfirmation = "PreviewOnly123!"
        authentication.recoveryState = switch state {
        case .emailSent: .emailSent
        case .newPassword: .newPassword(authSession)
        case .recoveryComplete: .complete
        case .invalidLink: .invalidLink
        default: .request
        }
        if screen != .passwordRecovery { authentication.recoveryState = nil }
        onboarding.displayName = accountRepository.details.nickname
        onboarding.selectedRole = .customer
        onboarding.state = .onboarding
        if state == .error {
            authentication.errorMessage = "Could not connect. Try again."
            authentication.recoveryError = "This reset link could not be verified."
            onboarding.errorMessage = "Could not save the profile. Your entries are preserved."
        }
        if state == .loading { authentication.isSubmitting = true; onboarding.isSubmitting = true }
        if state == .allRead {
            UserDefaultsChatReadStateCache(userDefaults: defaults).save(
                [CustomerSandboxFixtures.conversationID: Date().addingTimeInterval(86400).ISO8601Format()],
                participantID: customerID, role: .customer)
        }
        marketplace.requestOptions = { [weak self] in self?.requests.activeRequests ?? [] }
        marketplace.refreshRequestOptions = { [weak self] in await self?.requests.load(); return self?.requests.errorMessage }
        marketplace.createRequest = { [weak self] in self?.requests.startCreate() }
        boundary.state = state
    }

    func activate() async {
        switch screen {
        case .pets: await pets.store.load()
        case .profile: await profile.load()
        case .groomerDetail, .candidateActions: await discoveryFlow.store.load()
        case .fulfillment, .reschedule, .review: await bookings.resolveBooking(id: CustomerSandboxFixtures.bookingID)
        case .feedback:
            if state == .error { feedback.showError(.init(scope: .page("sandbox"), sourceKey: "sandbox.error",
                title: "Couldn't save", message: "Your changes are still here. Please try again.")) }
            else { feedback.showNotice("Changes saved.") }
        default: break
        }
    }

    var draft: GroomingRequestDraft {
        .init(petID: CustomerSandboxFixtures.id(10), serviceType: .fullGroom, serviceNotes: "Gentle grooming, please.",
            preferredStart: .now.addingTimeInterval(3 * 86400), preferredEnd: .now.addingTimeInterval(3 * 86400 + 7200),
            locationMode: .groomerComesToCustomer, streetAddress: "123 Preview Street", city: "Los Angeles",
            stateCode: .california, zipCode: "90012", travelRadiusMiles: nil)
    }

    func fillRequestDefaults() {
        if requests.selectedPetID == nil { requests.selectedPetID = requests.pets.first?.id }
        if requests.serviceType == nil { requests.serviceType = .fullGroom }
        var input = requests.addressEditorState.input
        if input.line1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { input.line1 = "123 Preview Street" }
        if input.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { input.city = "Los Angeles" }
        if input.stateCode == nil { input.stateCode = .california }
        if input.postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { input.postalCode = "90012" }
        let confirmed = BeckonConfirmedAddress(entered: input, accepted: input, provider: "flow_sandbox", placeID: nil,
            coordinate: .init(latitude: 34.05, longitude: -118.24), resolutionSource: "ui_preview",
            confirmedAt: .now, timeZoneIdentifier: CustomerSandboxFixtures.zone)
        requests.addressEditorState.replaceInput(input, confirmedAddress: confirmed)
    }

    func advanceRequest(_ flow: CustomerRequestWizardState) {
        guard boundary.isActive else { return }
        fillRequestDefaults()
        flow.invalidFields = []; flow.isContinuingAfterAddressConfirmation = false; requests.errorMessage = nil
        if let next = flow.currentStep.next { flow.currentStep = next }
        else {
            requests.discoveryFlow = makeDraftDiscoveryFlow()
        }
    }

    private func makeDraftDiscoveryFlow() -> CustomerRequestDiscoveryFlow {
        // The UI-only bypass fills missing values, but keeps what the person entered.
        let draft = GroomingRequestDraft(petID: requests.selectedPetID ?? CustomerSandboxFixtures.id(10),
            serviceType: requests.serviceType ?? .fullGroom, serviceNotes: requests.serviceNotes,
            preferredStart: requests.preferredStart, preferredEnd: requests.preferredEnd,
            locationMode: requests.locationMode, streetAddress: requests.streetAddress,
            addressLine2: requests.addressLine2, city: requests.city,
            stateCode: requests.stateCode ?? .california, zipCode: requests.zipCode,
            travelRadiusMiles: requests.locationMode == .customerComesToGroomer ? requests.travelRadiusMiles : nil,
            confirmedAddress: requests.addressEditorState.confirmedAddress)
        let session = marketplaceRepository.prepareLocal(draft: draft)
        return .init(store: .init(scope: session.scope, repository: marketplaceRepository),
            draft: draft, session: session, photos: requests.pendingRequestPhotos)
    }

    func invalidate() {
        boundary.isActive = false
        chatRepository.stop()
        marketplace.clearSession()
        pets.invalidate()
    }
}
#endif
